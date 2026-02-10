local addonName, addonTable = ...
addonTable.Combat = {}

local timerFrame
local timerText
local startTime = 0
local inCombat = false
local timeElapsed = 0

local function FormatTime(seconds)
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d", m, s)
end

function addonTable.Combat.UpdateSettings()
    if not timerFrame then return end

    if not UIThingsDB.combat.enabled then
        timerFrame:Hide()
        return
    end
    timerFrame:Show()

    local settings = UIThingsDB.combat

    -- Position
    timerFrame:ClearAllPoints()
    if settings.pos then
        timerFrame:SetPoint(settings.pos.point, UIParent, settings.pos.point, settings.pos.x, settings.pos.y)
    else
        timerFrame:SetPoint("CENTER")
    end

    -- Font
    if settings.font and settings.fontSize then
        timerText:SetFont(settings.font, settings.fontSize, "OUTLINE")
    end

    -- Color
    local color = inCombat and settings.colorInCombat or settings.colorOutCombat
    if color then
        timerText:SetTextColor(color.r, color.g, color.b)
    end

    -- Lock
    if settings.locked then
        timerFrame:EnableMouse(false)
        timerFrame:SetBackdrop(nil)
    else
        timerFrame:EnableMouse(true)
        timerFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        timerFrame:SetBackdropColor(0, 0, 0, 0.5)
    end
end

local function Init()
    timerFrame = CreateFrame("Frame", "UIThingsCombatTimer", UIParent, "BackdropTemplate")
    timerFrame:SetSize(100, 40)
    timerFrame:SetMovable(true)
    timerFrame:SetClampedToScreen(true)
    timerFrame:RegisterForDrag("LeftButton")

    timerFrame:SetScript("OnDragStart", timerFrame.StartMoving)
    timerFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        UIThingsDB.combat.pos = { point = point, x = x, y = y }
    end)

    timerText = timerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    timerText:SetPoint("CENTER")
    timerText:SetText("00:00")

    addonTable.Combat.UpdateSettings()

    timerFrame:SetScript("OnEvent", function(self, event)
        if not UIThingsDB.combat.enabled then return end
        if event == "PLAYER_REGEN_DISABLED" then
            inCombat = true
            startTime = GetTime()
            timeElapsed = 0
            timerText:SetText("00:00")
            addonTable.Combat.UpdateSettings() -- Update color
        elseif event == "PLAYER_REGEN_ENABLED" then
            inCombat = false
            -- Final update
            if startTime > 0 then
                timeElapsed = GetTime() - startTime
                timerText:SetText(FormatTime(timeElapsed))
            end
            addonTable.Combat.UpdateSettings() -- Update color
        end
    end)
    timerFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    timerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    -- Throttled OnUpdate (only update once per second)
    local updateTimer = 0
    timerFrame:SetScript("OnUpdate", function(self, elapsed)
        if inCombat then
            updateTimer = updateTimer + elapsed
            if updateTimer >= 1.0 then
                updateTimer = 0
                timeElapsed = GetTime() - startTime
                timerText:SetText(FormatTime(timeElapsed))
            end
        end
    end)
end

-- Combat Logging by Instance Difficulty
local combatLogActive = false

local difficultyMap = {
    [1]  = "dungeonNormal",
    [2]  = "dungeonHeroic",
    [23] = "dungeonMythic",
    [8]  = "mythicPlus",
    [17] = "raidLFR",
    [14] = "raidNormal",
    [15] = "raidHeroic",
    [16] = "raidMythic",
}

local function CheckCombatLogging()
    local settings = UIThingsDB.combat.combatLog
    if not settings then return end

    local _, instanceType, difficultyID = GetInstanceInfo()
    local shouldLog = false

    if instanceType == "party" or instanceType == "raid" then
        local key = difficultyMap[difficultyID]
        if key and settings[key] then
            shouldLog = true
        end
    end

    if shouldLog and not combatLogActive then
        LoggingCombat(true)
        combatLogActive = true
        addonTable.Core.Log("Combat", "Combat logging started", 1)
    elseif not shouldLog and combatLogActive then
        LoggingCombat(false)
        combatLogActive = false
        addonTable.Core.Log("Combat", "Combat logging stopped", 1)
    end
end

function addonTable.Combat.CheckCombatLogging()
    CheckCombatLogging()
end

-- Instance detection frame (separate from timer so it works even with timer disabled)
local logFrame = CreateFrame("Frame")
logFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
logFrame:RegisterEvent("CHALLENGE_MODE_START")
logFrame:SetScript("OnEvent", function(self, event)
    C_Timer.After(2, CheckCombatLogging)
end)

-- ============================================================
-- Combat Reminders
-- Shows a transparent frame with missing flask/food/weapon/pet
-- ============================================================

local reminderFrame
local reminderTitle
local reminderTitleLine
local reminderLines = {}
local UpdateReminderFrame -- Forward declaration

-- Combined flask + food buff detection in a single aura scan
local hasFlaskCache, hasFoodCache = false, false
local lastAuraScanTime = 0

local function ScanConsumableBuffs()
    -- Cache results within the same frame to avoid redundant scans
    local now = GetTime()
    if now == lastAuraScanTime then return end
    lastAuraScanTime = now

    hasFlaskCache = false
    hasFoodCache = false

    for i = 1, 40 do
        local auraData = C_UnitAuras.GetBuffDataByIndex("player", i)
        if not auraData then break end
        local lowerName = (auraData.name or ""):lower()
        if not hasFlaskCache and (lowerName:find("flask") or lowerName:find("phial")) then
            hasFlaskCache = true
        end
        if not hasFoodCache and lowerName:find("well fed") then
            -- Exclude "Food" (regen) and "Drink" (mana) but allow "Well Fed"
            hasFoodCache = true
        end
        if hasFlaskCache and hasFoodCache then break end
    end
end

local function HasFlaskBuff()
    ScanConsumableBuffs()
    return hasFlaskCache
end

local function HasFoodBuff()
    ScanConsumableBuffs()
    return hasFoodCache
end

-- Weapon enchant detection via GetWeaponEnchantInfo()
local function HasWeaponBuff()
    local hasMainHandEnchant, _, _, _, hasOffHandEnchant = GetWeaponEnchantInfo()
    local hasOffHandWeapon = GetInventoryItemLink("player", 17) ~= nil

    if hasOffHandWeapon then
        return hasMainHandEnchant and hasOffHandEnchant, hasMainHandEnchant, hasOffHandEnchant
    else
        return hasMainHandEnchant, hasMainHandEnchant, true -- Treat OH as true if not equipped
    end
end

-- Pet detection - checks if player has an active pet (combat pet, not battle pet)
local function HasPet()
    return UnitExists("pet")
end

-- Pet class summon spell IDs (classID -> list of summon spells)
-- Only classes with permanent combat pets are included
local CLASS_BUFFS = {
    [1]  = 6673,   -- Warrior: Battle Shout
    [5]  = 21562,  -- Priest: Power Word: Fortitude
    [8]  = 1459,   -- Mage: Arcane Intellect
    [11] = 1126,   -- Druid: Mark of the Wild
    [13] = 364342, -- Evoker: Blessing of the Bronze
}
local classBuffID = nil
local classBuffName = nil
local classBuffIconFrame = nil

local PET_SUMMON_SPELLS = {
    [1]  = nil, -- Warrior
    [2]  = nil, -- Paladin
    [3]  = {    -- Hunter
        883,    -- Call Pet 1
        83242,  -- Call Pet 2
        83243,  -- Call Pet 3
        83244,  -- Call Pet 4
        83245,  -- Call Pet 5
    },
    [4]  = nil, -- Rogue
    [5]  = nil, -- Priest
    [6]  = {    -- Death Knight
        46584,  -- Raise Dead
    },
    [7]  = nil, -- Shaman
    [8]  = {    -- Mage
        31687,  -- Summon Water Elemental
    },
    [9]  = {    -- Warlock
        688,    -- Summon Imp
        697,    -- Summon Voidwalker
        712,    -- Summon Succubus
        691,    -- Summon Felhunter
        30146,  -- Summon Felguard
    },
    [10] = nil, -- Monk
    [11] = nil, -- Druid
    [12] = nil, -- Demon Hunter
    [13] = nil, -- Evoker
}

local petIconFrames = {}

-- Get the list of known summon pet spells for the current player
-- For Hunters, only include Call Pet slots that have an assigned pet
local function GetKnownPetSpells()
    local _, _, classID = UnitClass("player")
    local spells = PET_SUMMON_SPELLS[classID]
    if not spells then return nil end

    -- For Hunters, check how many active pet slots are filled
    local activePetCount = nil
    if classID == 3 then -- Hunter
        local ok, count = pcall(C_StableInfo.GetNumActivePets)
        if ok and count then
            activePetCount = count
        end
    end

    local known = {}
    for idx, spellID in ipairs(spells) do
        -- For Hunters, skip Call Pet slots beyond the number of active pets
        if classID == 3 and activePetCount and idx > activePetCount then
            -- Skip - no pet assigned to this slot
        else
            local ok, exists = pcall(C_Spell.DoesSpellExist, spellID)
            if ok and exists then
                local ok2, isKnown = pcall(C_SpellBook.IsSpellKnown, spellID)
                if ok2 and isKnown then
                    local name = C_Spell.GetSpellName(spellID)
                    local icon = C_Spell.GetSpellTexture(spellID)
                    if name and icon then
                        table.insert(known, { spellID = spellID, name = name, icon = icon })
                    end
                end
            end
        end
    end

    if #known == 0 then return nil end
    return known
end

local function ApplyReminderLock()
    if not reminderFrame then return end
    local settings = UIThingsDB.combat.reminders

    if settings.locked then
        reminderFrame:EnableMouse(false)
        reminderFrame:SetBackdrop(nil)
    else
        reminderFrame:EnableMouse(true)
        reminderFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        reminderFrame:SetBackdropColor(0, 0, 0, 0.4)
        reminderFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
    end
end

local function HidePetIcons()
    for _, btn in ipairs(petIconFrames) do
        btn:Hide()
    end
end

local PET_ICON_SIZE = 24
local PET_ICON_PADDING = 4
local MAX_PET_ICONS = 5

local function CreateClassBuffButton()
    if not classBuffID then return end

    local btn = CreateFrame("Button", "LunaCombatClassBuffIcon", reminderFrame, "SecureActionButtonTemplate")
    btn:SetSize(PET_ICON_SIZE, PET_ICON_SIZE)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    btn.icon:SetTexture(C_Spell.GetSpellTexture(classBuffID))
    btn.icon:SetVertexColor(1, 1, 1, 1)

    btn:SetAttribute("type", "spell")
    btn:SetAttribute("spell", classBuffID)
    btn:RegisterForClicks("AnyUp", "AnyDown")

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(classBuffID)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)

    btn:Hide()
    classBuffIconFrame = btn
end

local function ShowClassBuffIcon(yOffset)
    if not classBuffIconFrame then return 0 end

    local iconSize = UIThingsDB.combat.reminders.iconSize or PET_ICON_SIZE
    classBuffIconFrame:SetSize(iconSize, iconSize)
    classBuffIconFrame:ClearAllPoints()
    classBuffIconFrame:SetPoint("TOPLEFT", reminderFrame, "TOPLEFT", 14, yOffset)

    if not InCombatLockdown() then
        classBuffIconFrame:SetAttribute("spell", classBuffID)
    end

    classBuffIconFrame:Show()
    return iconSize + 8
end

local function HideClassBuffIcon()
    if classBuffIconFrame then
        classBuffIconFrame:Hide()
    end
end

-- Pre-create pet icon buttons during init (must be done out of combat for SecureActionButtonTemplate)
local function CreatePetIconButtons()
    for i = 1, MAX_PET_ICONS do
        local btn = CreateFrame("Button", "LunaCombatPetIcon" .. i, reminderFrame, "SecureActionButtonTemplate")
        btn:SetSize(PET_ICON_SIZE, PET_ICON_SIZE)

        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetAllPoints()
        btn.icon:SetVertexColor(1, 1, 1, 1)
        btn.icon:SetDesaturated(false)

        btn:SetAttribute("type", "spell")
        btn:RegisterForClicks("AnyUp", "AnyDown")

        btn:SetScript("OnEnter", function(self)
            if self.spellID then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(self.spellID)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", GameTooltip_Hide)

        btn:Hide()
        petIconFrames[i] = btn
    end
end

local function ShowPetIcons(yOffset)
    local knownSpells = GetKnownPetSpells()
    if not knownSpells then
        HidePetIcons()
        return 0
    end

    local iconSize = UIThingsDB.combat.reminders.iconSize or PET_ICON_SIZE
    local startX = 12 -- left-aligned with text

    for i, spell in ipairs(knownSpells) do
        local btn = petIconFrames[i]
        if btn then
            btn:SetSize(iconSize, iconSize)
            btn.icon:SetTexture(spell.icon)
            btn.spellID = spell.spellID
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", reminderFrame, "TOPLEFT", startX + (i - 1) * (iconSize + PET_ICON_PADDING),
                yOffset)

            -- Update secure attribute (only works out of combat)
            if not InCombatLockdown() then
                btn:SetAttribute("type", "macro")
                btn:SetAttribute("macrotext", "/cast " .. spell.name)
            end

            btn:Show()
        end
    end

    -- Hide extra icons
    for i = #knownSpells + 1, MAX_PET_ICONS do
        if petIconFrames[i] then
            petIconFrames[i]:Hide()
        end
    end

    return iconSize + 8 -- extra height used by icon row
end

local function TrackConsumableUsage(itemID)
    if not itemID then return end

    -- Exclude toys
    if C_ToyBox and C_ToyBox.GetToyInfo(itemID) then return end

    local itemName = GetItemInfo(itemID)
    if not itemName then
        C_Item.RequestLoadItemDataByID(itemID)
        C_Timer.After(0.5, function() TrackConsumableUsage(itemID) end)
        return
    end

    local itemName, _, _, _, _, _, _, _, _, itemIcon, _, classID, subclassID = GetItemInfo(itemID)
    if not itemName then return end

    local category = nil

    local category = nil
    local category = nil
    local lowerName = itemName:lower()

    -- Ignore known non-stat items and engineering utilities
    local ignoreList = {
        "conjured mana bun",
        "jeeves",
        "auto-hammer",
        "thermal anvil",
        "moll-e"
    }
    for _, ignore in ipairs(ignoreList) do
        if lowerName:find(ignore) then return end
    end

    -- Categorize based on item info and name
    -- Class 0 is Consumable
    if classID == 0 then
        if subclassID == 5 then                                                                              -- Food & Drink
            category = "food"
        elseif subclassID == 3 or subclassID == 2 or lowerName:find("flask") or lowerName:find("phial") then -- Flasks (3) or Elixirs (2) which phials are
            category = "flask"
        elseif subclassID == 0 or subclassID == 7 or lowerName:find("oil") or lowerName:find("stone") or lowerName:find("rune") then
            category = "weapon"
        end
    end

    if category then
        local usage = UIThingsDB.combat.reminders.consumableUsage[category]
        local foundIndex = nil

        -- Check if item is already tracked
        for i, item in ipairs(usage) do
            if item.name == itemName then
                foundIndex = i
                break
            end
        end

        -- If found, remove it so we can re-add it at the end (most recent)
        if foundIndex then
            table.remove(usage, foundIndex)
        end

        -- Add to end of list
        table.insert(usage, { id = itemID, name = itemName, icon = itemIcon })

        -- Trim older items if list is too long
        if #usage > 5 then
            table.remove(usage, 1)
        end
        
        UpdateReminderFrame()

        -- Only announce if it's a new item
        if not foundIndex then
            if addonTable.Core and addonTable.Core.Log then
                addonTable.Core.Log("Combat", "Added consumable to tracker: " .. itemName, 1)
            end
        end
    end
end

local consumableIconFrames = {
    flask = {},
    food = {},
    weapon = {}
}

local function CreateConsumableIconButtons()
    local categories = { "flask", "food", "weapon" }
    for _, cat in ipairs(categories) do
        for i = 1, 10 do
            local btn = CreateFrame("Button", "LunaCombatIcon" .. cat .. i, reminderFrame, "SecureActionButtonTemplate")
            btn:SetSize(PET_ICON_SIZE, PET_ICON_SIZE)

            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetAllPoints()

            btn:SetAttribute("type", "item")
            btn:RegisterForClicks("AnyUp", "AnyDown")

            btn:SetScript("OnEnter", function(self)
                if self.itemID then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetItemByID(self.itemID)
                    GameTooltip:Show()
                end
            end)
            btn:SetScript("OnLeave", GameTooltip_Hide)

            -- Quality/Tier overlay
            btn.quality = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn.quality:SetPoint("TOPLEFT", 2, -2)
            btn.quality:SetTextColor(1, 1, 1, 1) -- White color
            btn.quality:SetJustifyH("LEFT")

            btn:Hide()
            consumableIconFrames[cat][i] = btn
        end
    end
end

-- Helper to scan bags and group items by name
local function ScanBagConsumables(category)
    local usage = UIThingsDB.combat.reminders.consumableUsage[category]
    if not usage or #usage == 0 then return {} end

    -- Build lookup set of names we care about
    local watchedNames = {}
    for _, item in ipairs(usage) do
        watchedNames[item.name] = true
    end

    local bagCache = {} -- [Name] = { {id, icon, quality, count} }

    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local name = GetItemInfo(info.itemID)
                if name and watchedNames[name] then
                    -- Filter out legacy non-stat foods
                    if name:lower():find("conjured mana bun") then
                        -- skip
                    else
                        if not bagCache[name] then bagCache[name] = {} end

                        -- Check if we already have this ID in the list (avoid duplicates from multiple stacks)
                        local alreadyHave = false
                        for _, v in ipairs(bagCache[name]) do
                            if v.id == info.itemID then
                                v.count = v.count + info.stackCount
                                alreadyHave = true
                                break
                            end
                        end

                        if not alreadyHave then
                            local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(info.itemID) or 0
                            table.insert(bagCache[name], {
                                id = info.itemID,
                                icon = info.iconFileID,
                                quality = quality,
                                count = info.stackCount,
                                name = name
                            })
                        end
                    end
                end
            end
        end
    end

    -- Sort variants by quality (descending)
    for name, variants in pairs(bagCache) do
        table.sort(variants, function(a, b) return a.quality > b.quality end)
    end

    return bagCache
end

local function ShowConsumableIcons(category, yOffset, mhBuffed, ohBuffed)
    local usage = UIThingsDB.combat.reminders.consumableUsage[category]
    if not usage or #usage == 0 then
        for _, btn in ipairs(consumableIconFrames[category]) do btn:Hide() end
        return 0
    end

    local iconSize = UIThingsDB.combat.reminders.iconSize or PET_ICON_SIZE
    local startX = 14 -- Slightly indented from text
    local bagCache = ScanBagConsumables(category)
    local btnIndex = 1
    local anyShown = false
    local processedNames = {}

    for _, historyItem in ipairs(usage) do
        -- Prevent duplicates if usage list has multiple entries for same name (legacy data)
        if not processedNames[historyItem.name] then
            processedNames[historyItem.name] = true

            local variants = bagCache[historyItem.name]

            if variants then
                for _, item in ipairs(variants) do
                    local btn = consumableIconFrames[category][btnIndex]
                    if btn then
                        anyShown = true
                        btn:SetSize(iconSize, iconSize)
                        btn.icon:SetTexture(item.icon)
                        btn.itemID = item.id
                        btn:ClearAllPoints()
                        btn:SetPoint("TOPLEFT", reminderFrame, "TOPLEFT", startX, yOffset)

                        if not InCombatLockdown() then
                            if category == "weapon" then
                                btn:SetAttribute("type", "macro")
                                local targetSlot = (mhBuffed and not ohBuffed) and 17 or 16
                                btn:SetAttribute("macrotext", "/use item:" .. item.id .. "\n/use " .. targetSlot)
                            else
                                btn:SetAttribute("type", "item")
                                btn:SetAttribute("item", item.name)
                            end
                        end

                        -- Display Quality Stars
                        if item.quality and item.quality > 0 then
                            local stars = ""
                            for q = 1, item.quality do stars = stars .. "*" end

                            local fontPath = UIThingsDB.combat.reminders.font or "Fonts\\FRIZQT__.TTF"
                            local starSize = math.max(10, iconSize * 0.45)
                            btn.quality:SetFont(fontPath, starSize, "OUTLINE")
                            btn.quality:SetText(stars)
                            btn.quality:Show()
                        else
                            btn.quality:Hide()
                        end

                        btn:Show()
                        startX = startX + iconSize + PET_ICON_PADDING
                        btnIndex = btnIndex + 1
                    end
                end
            end
        end
    end

    -- Hide remaining
    for i = btnIndex, 10 do
        if consumableIconFrames[category][i] then
            consumableIconFrames[category][i]:Hide()
        end
    end

    if anyShown then
        return iconSize + 6
    else
        return 0
    end
end

local hooksRegistered = false
local function HookConsumableUsage()
    if hooksRegistered then return end
    hooksRegistered = true

    -- Hook Action Buttons
    hooksecurefunc("UseAction", function(slot)
        local type, id = GetActionInfo(slot)
        if type == "item" then
            TrackConsumableUsage(id)
        elseif type == "macro" then
            local _, link = GetMacroItem(id)
            if link then
                local itemID = link:match("item:(%d+)")
                if itemID then TrackConsumableUsage(tonumber(itemID)) end
            end
        end
    end)

    -- Hook Container Items (Bag handling)
    local function TryTrackContainerItem(bag, slot)
        local itemID = C_Container.GetContainerItemID(bag, slot)
        if itemID then TrackConsumableUsage(itemID) end
    end

    if C_Container and C_Container.UseContainerItem then
        hooksecurefunc(C_Container, "UseContainerItem", TryTrackContainerItem)
    end
    -- Fallback for older APIs or if C_Container isn't used by some addons
    if UseContainerItem then
        hooksecurefunc("UseContainerItem", TryTrackContainerItem)
    end

    -- Hook Direct Item Usage (Macros, etc)
    hooksecurefunc("UseItemByName", function(name)
        if name then
            local _, link = GetItemInfo(name)
            if link then
                local itemID = link:match("item:(%d+)")
                if itemID then TrackConsumableUsage(tonumber(itemID)) end
            end
        end
    end)
end

local function ApplyReminderFont()
    if not reminderFrame then return end
    local settings = UIThingsDB.combat.reminders
    local fontPath = settings.font or "Fonts\\FRIZQT__.TTF"
    local fontSize = settings.fontSize or 12
    if reminderTitle then
        reminderTitle:SetFont(fontPath, fontSize, "OUTLINE")
    end
    for _, line in ipairs(reminderLines) do
        line:SetFont(fontPath, fontSize, "OUTLINE")
    end
end

UpdateReminderFrame = function()
    if not reminderFrame then return end
    local settings = UIThingsDB.combat.reminders
    if not settings then
        reminderFrame:Hide()
        return
    end

    -- Guard: Never update content in combat to avoid taint
    if InCombatLockdown() then return end

    -- Guard: Disable in Mythic+ (difficultyID 8)
    local _, _, difficultyID = GetInstanceInfo()
    if difficultyID == 8 then
        reminderFrame:Hide()
        UnregisterStateDriver(reminderFrame, "visibility")
        return
    end

    -- Guard: Only in Group check (allow if unlocked for positioning)
    if settings.onlyInGroup and not IsInGroup() and settings.locked then
        reminderFrame:Hide()
        UnregisterStateDriver(reminderFrame, "visibility")
        return
    end

    -- Build list of missing items only, packed from the top
    local missing = {}
    local petMissing = false
    local flaskMissing, foodMissing, weaponMissing = false, false, false
    local classBuffMissing = false

    if settings.classBuff and classBuffID then
        local name = C_Spell.GetSpellName(classBuffID)
        if name then
            local hasBuff = AuraUtil.FindAuraByName(name, "player", "HELPFUL")
            if not hasBuff then
                table.insert(missing, { text = "|cFFCCCCFFClass Buff|r", type = "classBuff" })
                classBuffMissing = true
            end
        end
    end

    if settings.flask and not HasFlaskBuff() then
        table.insert(missing, { text = "|cFFFF6666No Flask|r", type = "flask" })
        flaskMissing = true
    end
    if settings.food and not HasFoodBuff() then
        table.insert(missing, { text = "|cFFFFAA00No Food Buff|r", type = "food" })
        foodMissing = true
    end
    if settings.weaponBuff then
        local fullyBuffed, mhBuffed, ohBuffed = HasWeaponBuff()
        if not fullyBuffed then
            table.insert(missing, { text = "|cFF66AAFFNo Weapon Buff|r", type = "weapon", mh = mhBuffed, oh = ohBuffed })
            weaponMissing = true
        end
    end

    local _, _, classID = UnitClass("player")
    local isPetClass = PET_SUMMON_SPELLS[classID] ~= nil

    -- Special case: Death Knights only have a permanent pet in Unholy spec (3)
    if classID == 6 then
        local spec = GetSpecialization()
        if spec ~= 3 then
            isPetClass = false
        end
    end

    if settings.pet and isPetClass and not HasPet() then
        table.insert(missing, { text = "|cFF88FF88No Pet|r", type = "pet" })
        petMissing = true
    end

    -- Stack missing items from top
    local fontSize = settings.fontSize or 12
    local lineHeight = fontSize + 8
    local padding = 12
    local currentY = -8

    -- Hide all icons first
    for cat, btns in pairs(consumableIconFrames) do
        for _, b in ipairs(btns) do b:Hide() end
    end
    HidePetIcons()
    HideClassBuffIcon()

    if #missing == 0 and settings.locked then
        reminderFrame:Hide()
        UnregisterStateDriver(reminderFrame, "visibility")
        return
    end

    if #missing == 0 then
        -- Anchor Mode (unlocked with no missing items)
        reminderTitle:SetText("|cFF00FF00Consumable Tracker Anchor|r")
        reminderTitleLine:Show()
        for i = 1, 5 do
            if reminderLines[i] then reminderLines[i]:Hide() end
        end
        currentY = -lineHeight - 12
    else
        reminderTitle:SetText("|cFFFFD100Missing Buffs|r")
        reminderTitleLine:Show()
        for i, data in ipairs(missing) do
            local line = reminderLines[i]
            if line then
                currentY = currentY - lineHeight
                line:ClearAllPoints()
                line:SetPoint("TOPLEFT", 12, currentY)
                line:SetText(data.type and data.text or data)
                line:Show()

                -- Show icons for this category if missing
                if data.type == "classBuff" and classBuffMissing then
                    local added = ShowClassBuffIcon(currentY - lineHeight + 4)
                    if added > 0 then currentY = currentY - added end
                elseif data.type == "flask" and flaskMissing then
                    local added = ShowConsumableIcons("flask", currentY - lineHeight + 4)
                    if added > 0 then currentY = currentY - added end
                elseif data.type == "food" and foodMissing then
                    local added = ShowConsumableIcons("food", currentY - lineHeight + 4)
                    if added > 0 then currentY = currentY - added end
                elseif data.type == "weapon" and weaponMissing then
                    -- Pass MH/OH status to icon display
                    local added = ShowConsumableIcons("weapon", currentY - lineHeight + 4, data.mh, data.oh)
                    if added > 0 then currentY = currentY - added end
                elseif data.type == "pet" and petMissing then
                    local added = ShowPetIcons(currentY - lineHeight + 4)
                    if added > 0 then currentY = currentY - added end
                end
            end
        end

        -- Hide extra lines
        for i = #missing + 1, 5 do
            if reminderLines[i] then reminderLines[i]:Hide() end
        end
    end

    ApplyReminderFont()
    ApplyReminderLock()

    reminderFrame:SetHeight(math.abs(currentY) + padding + 4)

    -- Use State Driver for Visibility
    local driverStr = "[mounted] hide; show"
    local doHideInCombat = settings.hideInCombat
    if doHideInCombat == nil then doHideInCombat = true end
    if doHideInCombat then
        driverStr = "[combat] hide; " .. driverStr
    end

        reminderFrame:Show()
        RegisterStateDriver(reminderFrame, "visibility", driverStr)
    ApplyReminderLock()
end

local function InitReminders()
    -- Must be SecureFrame for StateDriver
    reminderFrame = CreateFrame("Frame", "LunaCombatReminders", UIParent, "SecureHandlerStateTemplate, BackdropTemplate")
    reminderFrame:SetSize(160, 100)
    reminderFrame:SetFrameStrata("MEDIUM")
    reminderFrame:SetMovable(true)
    reminderFrame:SetClampedToScreen(true)
    reminderFrame:RegisterForDrag("LeftButton")

    -- Position from saved settings
    local pos = UIThingsDB.combat.reminders.pos
    if pos then
        reminderFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    else
        reminderFrame:SetPoint("TOP", UIParent, "TOP", 0, -100)
    end

    reminderFrame:SetScript("OnDragStart", reminderFrame.StartMoving)
    reminderFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        UIThingsDB.combat.reminders.pos = { point = point, x = x, y = y }
    end)

    -- Title
    local initFont = UIThingsDB.combat.reminders.font or "Fonts\\FRIZQT__.TTF"
    local initFontSize = UIThingsDB.combat.reminders.fontSize or 12
    reminderTitle = reminderFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reminderTitle:SetPoint("TOPLEFT", 12, -6)
    reminderTitle:SetFont(initFont, initFontSize, "OUTLINE")
    reminderTitle:SetText("|cFFFFD100Missing Buffs|r")

    -- Underline below title (same gold color as title text)
    reminderTitleLine = reminderFrame:CreateTexture(nil, "OVERLAY")
    reminderTitleLine:SetColorTexture(1, 0.82, 0, 0.8) -- FFD100 gold
    reminderTitleLine:SetHeight(1)
    reminderTitleLine:SetPoint("LEFT", reminderFrame, "LEFT", 12, 0)
    reminderTitleLine:SetPoint("RIGHT", reminderFrame, "RIGHT", -12, 0)
    reminderTitleLine:SetPoint("TOP", reminderTitle, "BOTTOM", 0, -2)

    -- Create 4 text lines (one per possible reminder)
    for i = 1, 5 do
        local line = reminderFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        line:SetPoint("TOPLEFT", 12, -8 - (i * 20))
        line:SetFont(initFont, initFontSize, "OUTLINE")
        reminderLines[i] = line
    end

    -- Check for Class Buff
    local _, _, classID = UnitClass("player")
    local buffID = CLASS_BUFFS[classID]
    if buffID then
        -- Ideally check IsSpellKnown, but simple check is okay for now as most are baseline or talent
        classBuffID = buffID
    end

    -- Pre-create secure pet icon buttons (must happen out of combat)
    CreatePetIconButtons()
    CreateClassBuffButton()
    CreateConsumableIconButtons()
    HookConsumableUsage()

    ApplyReminderLock()
    reminderFrame:Hide()

    -- Register events for ongoing checks
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("UNIT_PET")
    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:SetScript("OnEvent", function(self, event, unit, castGUID, spellID)
        if event == "UNIT_AURA" and unit ~= "player" then return end
        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
            if spellID then
                local spellName = C_Spell.GetSpellName(spellID)
                if spellName then
                    -- Ignore generic spells that trigger from food/drink
                    if spellName == "Refreshment" or spellName == "Food" or spellName == "Drink" then return end

                    local itemID = select(1, C_Item.GetItemInfoInstant(spellName))
                    if itemID then
                        TrackConsumableUsage(itemID)
                    end
                end
            end
            return
        end

        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(1, UpdateReminderFrame)
        else
            UpdateReminderFrame()
        end
    end)

    -- Run initial check now (covers /reload where PLAYER_ENTERING_WORLD already fired)
    C_Timer.After(0.1, UpdateReminderFrame)

    -- Poll every 2 seconds to catch weapon buff expiration (no event fired)
    C_Timer.NewTicker(2, UpdateReminderFrame)
end

function addonTable.Combat.UpdateReminders()
    UpdateReminderFrame()
end

function addonTable.Combat.ClearConsumableUsage()
    UIThingsDB.combat.reminders.consumableUsage = {
        flask = {},
        food = {},
        weapon = {}
    }
    UpdateReminderFrame()
end

-- Initialize when Core loads
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if addonTable.Core and addonTable.Core.SafeAfter then
        addonTable.Core.SafeAfter(1, Init)
        addonTable.Core.SafeAfter(1, InitReminders)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(1, Init)
        C_Timer.After(1, InitReminders)
    end
end)
