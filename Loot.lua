local addonName, addonTable = ...
local Loot = {}
addonTable.Loot = Loot

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
anchorFrame:EnableMouse(true)
anchorFrame:SetClampedToScreen(true)
anchorFrame:RegisterForDrag("LeftButton")
anchorFrame:SetScript("OnDragStart", anchorFrame.StartMoving)
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
anchorFrame.text = anchorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
anchorFrame.text:SetPoint("CENTER")
anchorFrame.text:SetText("Loot Toasts Anchor")
anchorFrame:Hide()

function Loot.ToggleAnchor()
    if anchorFrame:IsShown() then
        anchorFrame:Hide()
        return false
    else
        anchorFrame:Show()
        return true
    end
end

function Loot.LockAnchor()
    if anchorFrame:IsShown() then
        anchorFrame:Hide()
    end
end

-- Toast Factory
local function AcquireToast()
    local toast = table.remove(itemPool)
    if not toast then
        toast = CreateFrame("Button", nil, UIParent) -- Button for tooltip support
        toast:SetFrameStrata("DIALOG")

        toast.icon = toast:CreateTexture(nil, "ARTWORK")
        toast.icon:SetPoint("LEFT", 0, 0)

        toast.text = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        toast.text:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 5, 0)
        toast.text:SetPoint("RIGHT", 0, 0)
        toast.text:SetJustifyH("LEFT")
        toast.text:SetWordWrap(false)

        toast.winner = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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

    -- Reset type fields for reuse
    toast.toastType = nil
    toast.currencyID = nil
    toast.itemLink = nil

    -- Restore OnUpdate script (cleared by RecycleToast on pooled frames)
    toast:SetScript("OnUpdate", function(self, elapsed)
        self.timeParams.elapsed = self.timeParams.elapsed + elapsed
        local remaining = self.timeParams.duration - self.timeParams.elapsed

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
    toast.text:SetFont(settings.font, settings.fontSize, "OUTLINE")
    -- Adjust winner font size relative to main font
    toast.winner:SetFont(settings.font, settings.whoLootedFontSize or 12, "OUTLINE")

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

    local toast = AcquireToast()

    toast.toastType = "gold"

    toast.icon:SetTexture(133784) -- Gold coin icon

    toast.text:SetText(GetCoinTextureString(copperAmount))
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

    -- Apply anchor position
    local settings = UIThingsDB.loot
    if settings.anchor then
        anchorFrame:ClearAllPoints()
        anchorFrame:SetPoint(settings.anchor.point, UIParent, settings.anchor.point, settings.anchor.x, settings.anchor
            .y)
    end

    -- Update existing toasts visually
    for _, toast in ipairs(activeToasts) do
        toast:SetSize(300, settings.iconSize)
        toast.icon:SetSize(settings.iconSize, settings.iconSize)
        toast.text:SetFont(settings.font, settings.fontSize, "OUTLINE")
        toast.winner:SetFont(settings.font, settings.whoLootedFontSize or 12, "OUTLINE")
    end
    Loot.UpdateLayout()
    Loot.ToggleBlizzardToasts(not settings.enabled)
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

local function UpdateRosterCache()
    table.wipe(rosterCache)

    -- Always cache player
    local playerName = UnitName("player")
    local _, playerClass = UnitClass("player")
    if playerName and playerClass then
        rosterCache[playerName] = playerClass
    end

    if IsInRaid() then
        for i = 1, 40 do
            local name, _, _, _, _, classFileName = GetRaidRosterInfo(i)
            if name and classFileName then
                -- Cache full name
                rosterCache[name] = classFileName
                -- Cache short name
                local shortName = name:match("^([^%-]+)")
                if shortName and shortName ~= name then
                    rosterCache[shortName] = classFileName
                end
            end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local unit = "party" .. i
            local name = UnitName(unit)
            local _, classFileName = UnitClass(unit)
            if name and classFileName then
                rosterCache[name] = classFileName
                -- UnitName usually returns what's expected, but just in case
                local shortName = name:match("^([^%-]+)")
                if shortName and shortName ~= name then
                    rosterCache[shortName] = classFileName
                end
            end
        end
    end
end

-- Event Handler
local EventBus = addonTable.EventBus
local lastMoney = 0 -- Tracks previous gold amount for locale-independent gold change detection

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

local function OnChatMsgLoot(event, msg)
    if not UIThingsDB.loot.enabled then return end
    if issecretvalue(msg) then return end
    local itemLink = string.match(msg, "|c%x+|Hitem:.-|h.-|h|r")
    if itemLink then
        local _, _, quality = GetItemInfo(itemLink)
        if not quality then return end
        if quality >= UIThingsDB.loot.minQuality then
            local looterName, looterClass = nil, nil
            if string.find(msg, "^You receive") then
                looterName = UnitName("player")
                looterClass = rosterCache[looterName]
            else
                local otherName = string.match(msg, "^([^%s]+) receive")
                if otherName then
                    looterName = otherName
                    local shortName = string.match(looterName, "^([^%-]+)")
                    if shortName then looterName = shortName end
                    looterClass = rosterCache[looterName]
                end
            end
            if not UIThingsDB.loot.showAll then
                if looterName ~= UnitName("player") then return end
            end
            local count = 1
            local matchCount = string.match(msg, "x(%d+)")
            if matchCount then count = tonumber(matchCount) end
            SpawnToast(itemLink, nil, count, looterName, looterClass)
        end
    end
end

local function OnPlayerLogin()
    lastMoney = GetMoney()
    addonTable.Loot.UpdateSettings()
    UpdateRosterCache()
end

function Loot.ApplyEvents()
    if UIThingsDB.loot.enabled then
        EventBus.Register("CHAT_MSG_LOOT", OnChatMsgLoot, "Loot")
        EventBus.Register("LOOT_READY", OnLootReady, "Loot")
        EventBus.Register("GROUP_ROSTER_UPDATE", OnGroupRosterUpdate, "Loot")

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
        EventBus.Unregister("LOOT_READY", OnLootReady)
        EventBus.Unregister("GROUP_ROSTER_UPDATE", OnGroupRosterUpdate)
        EventBus.Unregister("CURRENCY_DISPLAY_UPDATE", OnCurrencyDisplayUpdate)
        EventBus.Unregister("PLAYER_MONEY", OnPlayerMoney)
    end
end

EventBus.Register("PLAYER_LOGIN", OnPlayerLogin, "Loot")
