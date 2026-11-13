local addonName, addonTable = ...
local Loot = {}
addonTable.Loot = Loot

-- Retail moved these item helpers to C_Item; older clients retain globals.
local function GetItemInfo(...)
    local fn = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
    if type(fn) == "function" then return fn(...) end
end
local function GetDetailedItemLevelInfo(...)
    local fn = C_Item and C_Item.GetDetailedItemLevelInfo or _G.GetDetailedItemLevelInfo
    if type(fn) == "function" then return fn(...) end
end
local function GetItemQualityColor(...)
    local fn = C_Item and C_Item.GetItemQualityColor or _G.GetItemQualityColor
    if type(fn) == "function" then return fn(...) end
    return 1, 1, 1
end

local PAGE_NAME = "UIThingsLootToast"
local activeToasts = {}
local itemPool = {} -- Recycled frames

-- Map itemEquipLoc to inventory slot IDs for upgrade comparison
local EQUIP_LOC_TO_SLOT = {
    INVTYPE_HEAD = { 1 },
    INVTYPE_NECK = { 2 },
    INVTYPE_SHOULDER = { 3 },
    INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 },
    INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_HOLDABLE = { 17 },
    INVTYPE_SHIELD = { 17 },
    INVTYPE_RANGED = { 16 },
    INVTYPE_RANGEDRIGHT = { 16 },
}

local function GetEquippedIlvlForSlots(slots)
    if not slots then return nil end
    local lowestIlvl = nil
    for _, slotID in ipairs(slots) do
        local link = GetInventoryItemLink("player", slotID)
        if link then
            local ilvl = GetDetailedItemLevelInfo(link)
            if ilvl then
                if not lowestIlvl or ilvl < lowestIlvl then
                    lowestIlvl = ilvl
                end
            end
        else
            -- Empty slot = 0 ilvl, definitely an upgrade
            return 0
        end
    end
    return lowestIlvl
end

-- Anchor Frame
local anchorFrame = CreateFrame("Frame", "UIThingsLootAnchor", UIParent, "BackdropTemplate")
anchorFrame:SetSize(200, 20)
anchorFrame:SetMovable(true)
anchorFrame:EnableMouse(false)
anchorFrame:SetClampedToScreen(true)
anchorFrame:RegisterForDrag("LeftButton")
anchorFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    UIThingsDB.loot.anchor = { point = point, x = x, y = y }
end)

anchorFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
anchorFrame:SetBackdropColor(0, 0, 0, 0.8)
anchorFrame.text = anchorFrame:CreateFontString(nil, "OVERLAY", "LunaFontNormal")
anchorFrame.text:SetPoint("CENTER")
anchorFrame.text:SetText("Loot Toasts Anchor")
anchorFrame:Hide()

function Loot.UpdateAnchor()
    local settings = UIThingsDB.loot
    local pos = settings.anchor
    if pos then
        anchorFrame:ClearAllPoints()
        anchorFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    end
    -- The common Layout Mode handle owns dragging; the anchor is only a preview.
    anchorFrame:EnableMouse(false)
    anchorFrame:SetShown(settings.enabled and addonTable.LayoutMode.IsActive())
end

-- Toast Factory
local function AcquireToast()
    local toast = table.remove(itemPool)
    if not toast then
        toast = CreateFrame("Button", nil, UIParent) -- Button for tooltip support
        toast:SetFrameStrata("DIALOG")

        toast.icon = toast:CreateTexture(nil, "ARTWORK")
        toast.icon:SetPoint("LEFT", 0, 0)

        toast.text = toast:CreateFontString(nil, "OVERLAY", "LunaFontNormal")
        toast.text:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 5, 0)
        toast.text:SetPoint("RIGHT", 0, 0)
        toast.text:SetJustifyH("LEFT")
        toast.text:SetWordWrap(false)

        toast.winner = toast:CreateFontString(nil, "OVERLAY", "LunaFontHighlightSmall")
        toast.winner:SetPoint("BOTTOMLEFT", toast.icon, "BOTTOMRIGHT", 5, 0)
        toast.winner:SetPoint("RIGHT", 0, 0)
        toast.winner:SetJustifyH("LEFT")

        -- Tooltip Scripts (type-aware)
        toast:SetScript("OnEnter", function(self)
            if self.toastType == "item" and self.itemLink then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.itemLink)
                GameTooltip:Show()
            elseif self.toastType == "currency" and self.currencyID then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetCurrencyByID(self.currencyID)
                GameTooltip:Show()
            end
        end)
        toast:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

    end

    -- Keep acquired frames inactive while their content is being prepared.
    -- New frames are shown by default, so an interrupted setup could otherwise
    -- leave OnUpdate running without a timer.
    toast:Hide()
    toast.timeParams = { duration = UIThingsDB.loot.duration or 3, elapsed = 0 }

    -- Reset type fields for reuse
    toast.toastType = nil
    toast.currencyID = nil
    toast.itemLink = nil

    -- Restore OnUpdate script (cleared by RecycleToast on pooled frames)
    toast:SetScript("OnUpdate", function(self, elapsed)
        local timer = self.timeParams
        if not timer then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            return
        end
        timer.elapsed = timer.elapsed + elapsed
        local remaining = timer.duration - timer.elapsed

        if remaining <= 0 then
            Loot.RecycleToast(self)
        elseif remaining < 0.5 then
            self:SetAlpha(remaining * 2) -- Fade out over last 0.5s
        else
            self:SetAlpha(1)
        end
    end)

    -- Apply Settings
    local settings = UIThingsDB.loot
    toast:SetSize(300, settings.iconSize)
    toast.icon:SetSize(settings.iconSize, settings.iconSize)
    toast.text:SetFont(LunaUITweaksAPI.Style.Font(), settings.fontSize, "OUTLINE")
    -- Adjust winner font size relative to main font
    toast.winner:SetFont(LunaUITweaksAPI.Style.Font(), settings.whoLootedFontSize or 12, "OUTLINE")

    return toast
end

function Loot.RecycleToast(toast)
    toast:Hide()
    toast:SetScript("OnUpdate", nil)
    toast.timeParams = nil

    -- Remove from active list
    for i, t in ipairs(activeToasts) do
        if t == toast then
            table.remove(activeToasts, i)
            break
        end
    end

    table.insert(itemPool, toast)
    Loot.UpdateLayout()
end

function Loot.UpdateLayout()
    -- Re-stack toasts above anchor
    -- Growing UP
    local settings = UIThingsDB.loot
    local spacing = 5

    if not settings.anchor then return end

    local prev = anchorFrame

    for i, toast in ipairs(activeToasts) do
        toast:ClearAllPoints()

        if settings.growUp then
            -- Grow Upwards
            if i == 1 then
                toast:SetPoint("BOTTOMLEFT", prev, "TOPLEFT", 0, spacing)
            else
                toast:SetPoint("BOTTOMLEFT", prev, "TOPLEFT", 0, spacing)
            end
            prev = toast -- Next one stacks on top of this one
        else
            -- Grow Downwards
            if i == 1 then
                toast:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -spacing)
            else
                toast:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -spacing)
            end
            prev = toast -- Next one stacks below this one
        end
    end
end

local function SpawnToast(itemLink, text, count, looterName, looterClass)
    local toast = AcquireToast()

    -- Data
    toast.toastType = "item"
    toast.itemLink = itemLink
    local itemName, _, itemRarity, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink)

    if not itemName then
        itemName = text or "Unknown Item"
        itemTexture = 134400 -- ?
    end

    if itemTexture then toast.icon:SetTexture(itemTexture) end
    if itemName then
        local countText = (count and count > 1) and (" x" .. count) or ""

        -- Item level and upgrade indicator
        local ilvlSuffix = ""
        if UIThingsDB.loot.showItemLevel and itemLink then
            local itemLevel = GetDetailedItemLevelInfo(itemLink)
            if itemLevel then
                local _, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemLink)
                local slots = itemEquipLoc and EQUIP_LOC_TO_SLOT[itemEquipLoc]
                if slots then
                    local equippedIlvl = GetEquippedIlvlForSlots(slots)
                    if equippedIlvl then
                        local diff = itemLevel - equippedIlvl
                        if diff > 0 then
                            ilvlSuffix = string.format(" |cFF00FF00[%d +%d]|r", itemLevel, diff)
                        elseif diff < 0 then
                            ilvlSuffix = string.format(" |cFF888888[%d]|r", itemLevel)
                        else
                            ilvlSuffix = string.format(" |cFFFFFF00[%d]|r", itemLevel)
                        end
                    else
                        ilvlSuffix = string.format(" |cFFFFFF00[%d]|r", itemLevel)
                    end
                else
                    -- Non-equippable item with ilvl (e.g., tokens)
                    if itemLevel > 1 then
                        ilvlSuffix = string.format(" |cFFFFFF00[%d]|r", itemLevel)
                    end
                end
            end
        end

        toast.text:SetText(itemName .. ilvlSuffix .. countText)
        if itemRarity then
            local r, g, b = GetItemQualityColor(itemRarity)
            toast.text:SetTextColor(r, g, b)
        else
            toast.text:SetTextColor(1, 1, 1)
        end
    end

    -- Winner Name
    if looterName then
        local colorStr = "|cFFFFFFFF" -- Default white
        if looterClass then
            local color = C_ClassColor.GetClassColor(looterClass)
            if color then
                colorStr = color:GenerateHexColorMarkup()
            end
        end
        toast.winner:SetText("Won by: " .. colorStr .. looterName .. "|r")
        toast.winner:Show()
    else
        toast.winner:Hide()
    end

    -- Timer Setup
    toast.timeParams = {
        duration = UIThingsDB.loot.duration,
        elapsed = 0
    }

    toast:Show()
    table.insert(activeToasts, toast)
    Loot.UpdateLayout()
end

local function SpawnCurrencyToast(currencyID, quantityChange)
    if not currencyID or not quantityChange or quantityChange <= 0 then return end

    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if not info or not info.discovered then return end
    if not info.name or info.name == "" then return end

    local toast = AcquireToast()

    toast.toastType = "currency"
    toast.currencyID = currencyID

    if info.iconFileID then
        toast.icon:SetTexture(info.iconFileID)
    else
        toast.icon:SetTexture(134400) -- Question mark fallback
    end

    toast.text:SetText("+" .. quantityChange .. " " .. info.name)
    toast.text:SetTextColor(1, 0.82, 0) -- Gold color

    toast.winner:Hide()

    toast.timeParams = {
        duration = UIThingsDB.loot.duration,
        elapsed = 0
    }

    toast:Show()
    table.insert(activeToasts, toast)
    Loot.UpdateLayout()
end

local function SpawnGoldToast(copperAmount)
    if not copperAmount or copperAmount <= 0 then return end
    local formatMoney = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString or GetCoinTextureString
    if type(formatMoney) ~= "function" then return end
    local moneyText = formatMoney(copperAmount)


    local toast = AcquireToast()

    toast.toastType = "gold"

    toast.icon:SetTexture(133784) -- Gold coin icon

    toast.text:SetText(moneyText)
    toast.text:SetTextColor(1, 1, 1)

    toast.winner:Hide()

    toast.timeParams = {
        duration = UIThingsDB.loot.duration,
        elapsed = 0
    }

    toast:Show()
    table.insert(activeToasts, toast)
    Loot.UpdateLayout()
end

function Loot.UpdateSettings()
    if Loot.ApplyEvents then Loot.ApplyEvents() end

    local settings = UIThingsDB.loot
    Loot.UpdateAnchor()

    -- Update existing toasts visually
    for _, toast in ipairs(activeToasts) do
        toast:SetSize(300, settings.iconSize)
        toast.icon:SetSize(settings.iconSize, settings.iconSize)
        toast.text:SetFont(LunaUITweaksAPI.Style.Font(), settings.fontSize, "OUTLINE")
        toast.winner:SetFont(LunaUITweaksAPI.Style.Font(), settings.whoLootedFontSize or 12, "OUTLINE")
    end
    Loot.UpdateLayout()
    Loot.ToggleBlizzardToasts(not settings.enabled)
    Loot.ApplyBagHighlightEvents(settings.enabled and settings.highlightBagUpgrades)
end

function Loot.ToggleBlizzardToasts(enable)
    if enable then
        AlertFrame:RegisterEvent("SHOW_LOOT_TOAST")
        AlertFrame:RegisterEvent("SHOW_LOOT_TOAST_UPGRADE")
        AlertFrame:RegisterEvent("SHOW_PVP_FACTION_LOOT_TOAST")
    else
        -- Unregister from specific alert systems
        if LootWonAlertSystem and LootWonAlertSystem.UnregisterEvent then
            LootWonAlertSystem:UnregisterEvent(
                "SHOW_LOOT_TOAST")
        end
        if LootUpgradeAlertSystem and LootUpgradeAlertSystem.UnregisterEvent then
            LootUpgradeAlertSystem:UnregisterEvent(
                "SHOW_LOOT_TOAST_UPGRADE")
        end

        -- Use pcall to safely unregister events that may not be registered
        pcall(function() AlertFrame:UnregisterEvent("SHOW_LOOT_TOAST") end)
        pcall(function() AlertFrame:UnregisterEvent("SHOW_LOOT_TOAST_UPGRADE") end)
        pcall(function() AlertFrame:UnregisterEvent("SHOW_PVP_FACTION_LOOT_TOAST") end)
    end
end

-- Roster Cache for optimized lookups
local rosterCache = {}
local Secret = addonTable.Secret

-- The player's name is compared and used as a key on every loot message.
-- Cache it once readable; nil until then.
local cachedPlayerName
local function PlayerName()
    if not cachedPlayerName then cachedPlayerName = Secret.SafeUnitName("player", nil) end
    return cachedPlayerName
end

-- Names and classes can be secret (e.g. roster changes in combat). Check
-- before using them as keys or calling match on them. Returns false when an
-- entry had to be skipped because it was secret.
local function AddRosterEntry(cache, name, classFileName)
    if not Secret.IsPublic(name) or not Secret.IsPublic(classFileName) then return false end
    if name and classFileName then
        cache[name] = classFileName
        -- Cache short name
        local shortName = name:match("^([^%-]+)")
        if shortName and shortName ~= name then
            cache[shortName] = classFileName
        end
    end
    return true
end

local function UpdateRosterCache()
    local fresh, complete = {}, true

    -- Always cache player
    local _, playerClass = UnitClass("player")
    if not AddRosterEntry(fresh, PlayerName(), playerClass) then complete = false end

    if IsInRaid() then
        for i = 1, 40 do
            local name, _, _, _, _, classFileName = GetRaidRosterInfo(i)
            if not AddRosterEntry(fresh, name, classFileName) then complete = false end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local unit = "party" .. i
            local _, classFileName = UnitClass(unit)
            if not AddRosterEntry(fresh, UnitName(unit), classFileName) then complete = false end
        end
    end

    if complete then
        rosterCache = fresh
    else
        -- Keep earlier readable entries for members whose data is secret now.
        for name, classFileName in pairs(fresh) do rosterCache[name] = classFileName end
    end
end

-- Event Handler
local EventBus = addonTable.EventBus
local lastMoney = 0 -- Tracks previous gold amount for locale-independent gold change detection
local recentToasts = {} -- Dedup: itemLink -> expiry time
local lastToastPrune = 0

-- Named callbacks for EventBus
local function OnGroupRosterUpdate()
    UpdateRosterCache()
end

local function OnCurrencyDisplayUpdate(event, currencyID, quantity, quantityChange)
    if not UIThingsDB.loot.enabled then return end
    if UIThingsDB.loot.showCurrency then
        if currencyID and quantityChange and quantityChange > 0 then
            SpawnCurrencyToast(currencyID, quantityChange)
        end
    end
end

local function OnPlayerMoney()
    if not UIThingsDB.loot.enabled then return end
    if UIThingsDB.loot.showGold then
        local currentMoney = GetMoney()
        local gained = currentMoney - lastMoney
        lastMoney = currentMoney
        if gained > 0 and gained >= (UIThingsDB.loot.minGoldAmount or 10000) then
            SpawnGoldToast(gained)
        end
    end
end

local function OnLootReady()
    if not UIThingsDB.loot.enabled then return end
    if UIThingsDB.loot.fasterLoot and GetCVar("autoLootDefault") == "1" then
        local numItems = GetNumLootItems()
        if numItems == 0 then return end
        local delay = UIThingsDB.loot.fasterLootDelay or 0.3
        for i = numItems, 1, -1 do
            if delay == 0 then
                LootSlot(i)
            else
                local timerDelay = (numItems - i) * delay
                C_Timer.After(timerDelay, function()
                    LootSlot(i)
                end)
            end
        end
    end
end

-- Match localized Blizzard loot formats, including numbered placeholders.
local lootFormats
local function BuildLootFormats()
    local result = {}
    for _, spec in ipairs({
        {"LOOT_ITEM_SELF",true}, {"LOOT_ITEM_SELF_MULTIPLE",true},
        {"LOOT_ITEM_PUSHED_SELF",true}, {"LOOT_ITEM_PUSHED_SELF_MULTIPLE",true},
        {"LOOT_ITEM_CREATED_SELF",true}, {"LOOT_ITEM_CREATED_SELF_MULTIPLE",true},
        {"LOOT_ITEM",false}, {"LOOT_ITEM_MULTIPLE",false},
        {"LOOT_ITEM_PUSHED",false}, {"LOOT_ITEM_PUSHED_MULTIPLE",false},
    }) do
        local format = _G[spec[1]]
        if type(format) == "string" then
            local pattern, captures, index, pos = {}, {}, 0, 1
            while pos <= #format do
                local tail = format:sub(pos)
                local token, number, kind = tail:match("^(%%(%d+)%$([sd]))")
                if not token then token, kind = tail:match("^(%%([sd]))") end
                if token then
                    index = index + 1
                    captures[#captures+1] = tonumber(number) or index
                    pattern[#pattern+1] = kind == "d" and "(%d+)" or "(.-)"
                    pos = pos + #token
                else
                    local char = format:sub(pos,pos)
                    pattern[#pattern+1] = char:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
                    pos = pos + 1
                end
            end
            result[#result+1] = {pattern="^"..table.concat(pattern).."$", captures=captures, self=spec[2]}
        end
    end
    table.sort(result, function(a,b) return #a.captures > #b.captures end)
    return result
end
local function ParseLootMessage(msg)
    lootFormats = lootFormats or BuildLootFormats()
    for _, format in ipairs(lootFormats) do
        -- find() tests the pattern without building a table; capture only on a hit.
        local values = msg:find(format.pattern) and {msg:match(format.pattern)}
        if values and #values > 0 then
            local args = {}
            for i, value in ipairs(values) do args[format.captures[i]] = value end
            local recipient
            if format.self then recipient = PlayerName() else recipient = args[1] end
            if recipient then
                recipient = recipient:match("|h%[(.-)%]|h") or recipient:match("|h(.-)|h") or recipient
            end
            local link = args[format.self and 1 or 2]
            -- Extract the hyperlink independently of its legacy/modern color prefix.
            link = link and link:match("(|Hitem:.-|h.-|h)")
            if link then return link, recipient, tonumber(args[format.self and 2 or 3]) or 1 end
        end
    end
end

-- Pair reports across event channels, never suppress successive drops from the
-- same channel. Each occurrence can consume one report from each channel.
local function IsDuplicate(itemLink, recipient, quantity, channel)
    local now = GetTime()
    local payload = itemLink:match("|H(item:.-)|h") or itemLink
    local key = payload .. "\031" .. (recipient or "") .. "\031" .. tostring(quantity or 1)
    -- Always expire this key's entries; sweep other keys at most once a second.
    local current = recentToasts[key]
    if current then
        for i = #current, 1, -1 do
            if current[i].expires <= now then table.remove(current, i) end
        end
    end
    if now - lastToastPrune >= 1 then
        lastToastPrune = now
        for k, occurrences in pairs(recentToasts) do
            for i = #occurrences, 1, -1 do
                if occurrences[i].expires <= now then table.remove(occurrences, i) end
            end
            if #occurrences == 0 then recentToasts[k] = nil end
        end
    end
    local occurrences = recentToasts[key] or {}
    recentToasts[key] = occurrences
    for _, occurrence in ipairs(occurrences) do
        if not occurrence.channels[channel] then
            occurrence.channels[channel] = true
            return true
        end
    end
    occurrences[#occurrences+1] = {expires=now+2, channels={[channel]=true}}
    return false
end

local function OnShowLootToast(event, typeIdentifier, itemLink, quantity)
    if not UIThingsDB.loot.enabled or typeIdentifier ~= "item" or not itemLink then return end
    local _, _, quality = GetItemInfo(itemLink)
    if not quality or quality < UIThingsDB.loot.minQuality then return end
    local recipient, count = PlayerName(), quantity or 1
    if IsDuplicate(itemLink, recipient, count, event) then return end
    SpawnToast(itemLink, nil, count, recipient, rosterCache[recipient])
end
local function OnShowLootToastUpgrade(event, itemLink, quantity)
    OnShowLootToast(event, "item", itemLink, quantity)
end
local function OnChatMsgLoot(event, msg)
    if not UIThingsDB.loot.enabled or (issecretvalue and issecretvalue(msg)) then return end
    local itemLink, recipient, count = ParseLootMessage(msg)
    if not itemLink then return end
    local _, _, quality = GetItemInfo(itemLink)
    if not quality or quality < UIThingsDB.loot.minQuality then return end
    if not UIThingsDB.loot.showAll and recipient ~= PlayerName() then return end
    if IsDuplicate(itemLink, recipient, count, event) then return end
    local shortName = recipient and recipient:match("^([^%-]+)")
    SpawnToast(itemLink, nil, count, recipient, rosterCache[shortName or recipient])
end

-- Armor types in ascending order (ITEMCLASS_ARMOR subclass IDs) and the best
-- one each class can wear. Lower types are wearable, so they are left alone.
local MAX_ARMOR_TYPE = {
    WARRIOR = 4, PALADIN = 4, DEATHKNIGHT = 4,
    HUNTER = 3, SHAMAN = 3, EVOKER = 3,
    ROGUE = 2, DRUID = 2, MONK = 2, DEMONHUNTER = 2,
    PRIEST = 1, MAGE = 1, WARLOCK = 1,
}
-- Shields: warrior, paladin, shaman.
local CAN_USE_SHIELD = { WARRIOR = true, PALADIN = true, SHAMAN = true }
-- Weapon subclass IDs each class can use. Classes missing here are never
-- treated as unable to use a weapon.
local W = function(...) local t = {} for _, id in ipairs({...}) do t[id] = true end return t end
local USABLE_WEAPONS = {
    WARRIOR = W(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18),
    PALADIN = W(0, 1, 4, 5, 6, 7, 8),
    HUNTER  = W(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 18),
    ROGUE   = W(2, 3, 4, 7, 13, 15, 16, 18),
    PRIEST  = W(4, 10, 15, 19),
    MAGE    = W(7, 10, 15, 19),
    WARLOCK = W(7, 10, 15, 19),
    SHAMAN  = W(0, 1, 4, 5, 10, 13, 15),
    DRUID   = W(4, 5, 6, 10, 13, 15),
}

-- True only when the item is armor or a weapon this class can never equip.
-- Anything uncertain (no item info, trinkets, rings, cloaks, relics, other
-- classes) returns false so the roll is left for the player.
local function IsUnequippableForPlayer(link)
    if not link then return false end
    local instant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
    if not instant then return false end
    local _, _, _, equipLoc, _, classID, subClassID = instant(link)
    if not classID then return false end
    local class = select(2, UnitClass("player"))
    if classID == 4 then
        if equipLoc == "INVTYPE_CLOAK" then return false end
        if subClassID == 6 then return not CAN_USE_SHIELD[class] end
        local maxType = MAX_ARMOR_TYPE[class]
        return maxType ~= nil and subClassID >= 1 and subClassID <= 4 and subClassID > maxType
    elseif classID == 2 then
        local usable = USABLE_WEAPONS[class]
        return usable ~= nil and not usable[subClassID] and subClassID ~= 14 and subClassID ~= 20
    end
    return false
end

-- Retail only rolls when Need is unavailable, so this mode is for other clients.
local GREED_UNEQUIPPABLE_SUPPORTED = WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE

-- TEMP DEBUG: /greeddebug toggles a printout for each roll
SLASH_LUNAGREEDDEBUG1 = "/greeddebug"
local greedDebug = false
SlashCmdList["LUNAGREEDDEBUG"] = function() greedDebug = not greedDebug; print("greeddebug", greedDebug) end
local function GreedDebugDump(rollID)
    local link = GetLootRollItemLink(rollID)
    local instant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
    print("greeddebug: projectID", tostring(WOW_PROJECT_ID), "mainline", tostring(WOW_PROJECT_MAINLINE), "supported", tostring(GREED_UNEQUIPPABLE_SUPPORTED))
    print("greeddebug: opt", tostring(UIThingsDB.loot.autoGreedUnequippable), "autoGreed", tostring(UIThingsDB.loot.autoGreed), "link", tostring(link))
    if instant and link then print("greeddebug: instant", instant(link)) end
    print("greeddebug: class", tostring(select(2, UnitClass("player"))), "unequippable", tostring(IsUnequippableForPlayer(link)))
    print("greeddebug: rollinfo", GetLootRollItemInfo(rollID))
end

local function OnStartLootRoll(event, rollID)
    if greedDebug then GreedDebugDump(rollID) end
    local loot = UIThingsDB.loot
    if GREED_UNEQUIPPABLE_SUPPORTED and loot.autoGreedUnequippable
        and IsUnequippableForPlayer(GetLootRollItemLink(rollID)) then
        -- Gear the player can never use: greed it, even when Need is offered.
        local _, _, _, _, _, _, canGreed, _, _, _, _, _, canTransmog = GetLootRollItemInfo(rollID)
        if canTransmog then RollOnLoot(rollID, 4) elseif canGreed then RollOnLoot(rollID, 2) end
        return
    end
    -- Without the old option, everything else stays manual.
    if not loot.autoGreed then return end
    local _, _, _, _, _, canNeed, canGreed, _, _, _, _, _, canTransmog = GetLootRollItemInfo(rollID)
    if canNeed then return end -- player can need -- let them decide
    -- Blizzard shows Transmog instead of Greed when it is available.
    if canTransmog then
        RollOnLoot(rollID, 4) -- transmog
    elseif canGreed then
        RollOnLoot(rollID, 2) -- greed
    end
    -- No eligible choice: leave the roll untouched.
end

local function OnPlayerLogin()
    lastMoney = GetMoney()
    addonTable.Loot.UpdateSettings()
    UpdateRosterCache()
end

function Loot.ApplyEvents()
    if UIThingsDB.loot.enabled then
        EventBus.Register("CHAT_MSG_LOOT", OnChatMsgLoot, "Loot")
        EventBus.Register("SHOW_LOOT_TOAST", OnShowLootToast, "Loot")
        EventBus.Register("SHOW_LOOT_TOAST_UPGRADE", OnShowLootToastUpgrade, "Loot")
        EventBus.Register("LOOT_READY", OnLootReady, "Loot")
        EventBus.Register("GROUP_ROSTER_UPDATE", OnGroupRosterUpdate, "Loot")

        if UIThingsDB.loot.autoGreed
            or (GREED_UNEQUIPPABLE_SUPPORTED and UIThingsDB.loot.autoGreedUnequippable) then
            EventBus.Register("START_LOOT_ROLL", OnStartLootRoll, "Loot")
        else
            EventBus.Unregister("START_LOOT_ROLL", OnStartLootRoll)
        end

        if UIThingsDB.loot.showCurrency then
            EventBus.Register("CURRENCY_DISPLAY_UPDATE", OnCurrencyDisplayUpdate, "Loot")
        else
            EventBus.Unregister("CURRENCY_DISPLAY_UPDATE", OnCurrencyDisplayUpdate)
        end

        if UIThingsDB.loot.showGold then
            lastMoney = GetMoney()
            EventBus.Register("PLAYER_MONEY", OnPlayerMoney, "Loot")
        else
            EventBus.Unregister("PLAYER_MONEY", OnPlayerMoney)
        end
    else
        EventBus.Unregister("CHAT_MSG_LOOT", OnChatMsgLoot)
        EventBus.Unregister("SHOW_LOOT_TOAST", OnShowLootToast)
        EventBus.Unregister("SHOW_LOOT_TOAST_UPGRADE", OnShowLootToastUpgrade)
        EventBus.Unregister("LOOT_READY", OnLootReady)
        EventBus.Unregister("GROUP_ROSTER_UPDATE", OnGroupRosterUpdate)
        EventBus.Unregister("CURRENCY_DISPLAY_UPDATE", OnCurrencyDisplayUpdate)
        EventBus.Unregister("PLAYER_MONEY", OnPlayerMoney)
        EventBus.Unregister("START_LOOT_ROLL", OnStartLootRoll)
    end
end

-- Bag Upgrade Highlight
-- Scans all open bag frames on BAG_UPDATE_DELAYED using GetBagName/GetContainerItemInfo.
-- Overlays are addon-created frames parented to each item button, looked up by button ref.
local bagHighlightOverlays = {} -- keyed by button reference

local function IsIlvlUpgrade(itemLink)
    if not itemLink then return false end
    local itemLevel = GetDetailedItemLevelInfo(itemLink)
    if not itemLevel then return false end
    local _, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemLink)
    if not itemEquipLoc or itemEquipLoc == "" or itemEquipLoc == "INVTYPE_NON_EQUIP"
        or itemEquipLoc == "INVTYPE_NON_EQUIP_IGNORE" then return false end
    local slots = EQUIP_LOC_TO_SLOT[itemEquipLoc]
    if not slots then return false end
    -- For rings/trinkets checks both slots; item is an upgrade if it beats the lowest equipped
    local equippedIlvl = GetEquippedIlvlForSlots(slots)
    if equippedIlvl == nil then return false end
    return itemLevel > equippedIlvl
end

local function GetOrCreateOverlay(button)
    local f = bagHighlightOverlays[button]
    if not f then
        f = CreateFrame("Frame", nil, button)
        f:SetAllPoints(button)
        f:SetFrameLevel(button:GetFrameLevel() + 5)
        local tex = f:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        tex:SetColorTexture(0, 1, 0, 0.3)
        f.tex = tex
        bagHighlightOverlays[button] = f
    end
    return f
end

local function UpdateButtonOverlay(button, bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if info and info.hyperlink and IsIlvlUpgrade(info.hyperlink) then
        GetOrCreateOverlay(button):Show()
    else
        local f = bagHighlightOverlays[button]
        if f then f:Hide() end
    end
end

local function ScanBagButtons()
    if not UIThingsDB.loot or not UIThingsDB.loot.highlightBagUpgrades then
        for _, f in pairs(bagHighlightOverlays) do f:Hide() end
        return
    end
    -- ContainerFrame1..NUM_BAG_SLOTS+1, each has item buttons named ContainerFrame<n>Item<m>
    -- Button index m=1 is the LAST slot in the bag; m=numSlots is slot 1.
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local buttonIndex = numSlots - slot + 1
            local button = _G[string.format("ContainerFrame%dItem%d", bag + 1, buttonIndex)]
            if button then
                UpdateButtonOverlay(button, bag, slot)
            end
        end
    end
end

local function OnBagUpdateDelayed()
    if UIThingsDB.loot and UIThingsDB.loot.highlightBagUpgrades then
        ScanBagButtons()
    end
end

function Loot.ApplyBagHighlightEvents(enabled)
    if enabled then
        EventBus.Register("BAG_UPDATE_DELAYED", OnBagUpdateDelayed, "Loot:BagHL")
        ScanBagButtons()
    else
        EventBus.Unregister("BAG_UPDATE_DELAYED", OnBagUpdateDelayed)
        for _, f in pairs(bagHighlightOverlays) do f:Hide() end
    end
end

EventBus.Register("PLAYER_LOGIN", OnPlayerLogin, "Loot")

-- Bonus-roll prompts are independent of custom loot toasts. Only intercept the
-- two known action buttons; other children may belong to unrelated addons.
local BONUS_ROLL_CONFIRM = "LUNA_LOOT_BONUS_ROLL_CONFIRM"
local BONUS_PASS_CONFIRM = "LUNA_LOOT_BONUS_PASS_CONFIRM"
local bonusGeneration = 0
local bonusHookedButtons = setmetatable({}, { __mode = "k" })
local bonusHookedFrames = setmetatable({}, { __mode = "k" })

local function LootSpecText()
    local specID = GetLootSpecialization and GetLootSpecialization()
    if specID and specID > 0 then
        local _, name = GetSpecializationInfoByID(specID)
        return name or "unknown"
    end
    local index = GetSpecialization and GetSpecialization()
    if index then
        local _, name = GetSpecializationInfo(index)
        if name then return name .. " (current spec)" end
    end
    return "unknown"
end

local function InvalidateBonusPrompt()
    bonusGeneration = bonusGeneration + 1
    StaticPopup_Hide(BONUS_ROLL_CONFIRM)
    StaticPopup_Hide(BONUS_PASS_CONFIRM)
end

local function AcceptBonusAction(_, data)
    if not data or data.generation ~= bonusGeneration then return end
    if not data.frame:IsShown() or not data.button:IsShown() or not data.button:IsEnabled() then return end
    -- Consume the pending action before invoking Blizzard's handler.
    InvalidateBonusPrompt()
    data.original(data.button, data.mouseButton, data.down)
end

StaticPopupDialogs[BONUS_ROLL_CONFIRM] = {
    text = "Are you sure you want to use a bonus roll?\n\nLoot spec: |cffffd100%s|r",
    button1 = "Confirm", button2 = "Cancel",
    OnAccept = AcceptBonusAction, timeout = 0, whileDead = false,
    hideOnEscape = true, preferredIndex = 3,
}
StaticPopupDialogs[BONUS_PASS_CONFIRM] = {
    text = "Are you sure you want to pass on this bonus roll?",
    button1 = "Confirm", button2 = "Cancel",
    OnAccept = AcceptBonusAction, timeout = 0, whileDead = false,
    hideOnEscape = true, preferredIndex = 3,
}

local function HookBonusButton(frame, button, isRoll)
    if not button or bonusHookedButtons[button] then return end
    local original = button:GetScript("OnClick")
    if not original then return end
    bonusHookedButtons[button] = true
    button:SetScript("OnClick", function(self, mouseButton, down)
        local settings = UIThingsDB and UIThingsDB.loot
        local key = isRoll and "confirmBonusRoll" or "confirmBonusPass"
        if not settings or settings[key] == false then
            original(self, mouseButton, down)
            return
        end
        InvalidateBonusPrompt()
        local data = { frame = frame, button = self, original = original,
            mouseButton = mouseButton, down = down, generation = bonusGeneration }
        StaticPopup_Show(isRoll and BONUS_ROLL_CONFIRM or BONUS_PASS_CONFIRM,
            isRoll and LootSpecText() or nil, nil, data)
    end)
end

local function HookBonusRollFrame()
    local frame = BonusRollFrame
    if not frame then return end
    if not bonusHookedFrames[frame] then
        bonusHookedFrames[frame] = true
        frame:HookScript("OnHide", InvalidateBonusPrompt)
    end
    local prompt = frame.PromptFrame
    HookBonusButton(frame, (prompt and prompt.RollButton) or frame.RollButton, true)
    HookBonusButton(frame, (prompt and prompt.PassButton) or frame.PassButton, false)
end

local bonusStartHooked = false
local function TryHookBonusRoll()
    if BonusRollFrame_StartBonusRoll and not bonusStartHooked then
        bonusStartHooked = true
        hooksecurefunc("BonusRollFrame_StartBonusRoll", function()
            InvalidateBonusPrompt()
            HookBonusRollFrame()
        end)
    end
    HookBonusRollFrame()
end
EventBus.Register("PLAYER_LOGIN", TryHookBonusRoll, "Loot:BonusRoll")
EventBus.Register("ADDON_LOADED", TryHookBonusRoll, "Loot:BonusRoll")
EventBus.Register("BONUS_ROLL_STARTED", function()
    InvalidateBonusPrompt()
    TryHookBonusRoll()
end, "Loot:BonusRoll")

-- Layout Mode integration (the toast anchor has no saved lock flag)
addonTable.LayoutMode.RegisterModule("Loot", {
    apply = function() Loot.UpdateSettings() end,
})
addonTable.LayoutMode.RegisterTarget("Loot toasts", function() return _G.UIThingsLootAnchor end, function()
    local db = UIThingsDB.loot
    return db and db.enabled
end)
