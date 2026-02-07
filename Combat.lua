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

-- Flask buff detection via aura scanning
-- Flasks in TWW apply "Flask" or "Phial" buffs. We detect by checking
-- for common flask/phial spell IDs or by the "flask" keyword in the aura name.
local function HasFlaskBuff()
    for i = 1, 40 do
        local auraData = C_UnitAuras.GetBuffDataByIndex("player", i)
        if not auraData then break end
        local name = auraData.name or ""
        local lowerName = name:lower()
        if lowerName:find("flask") or lowerName:find("phial") then
            return true
        end
    end
    return false
end

-- Food buff detection - "Well Fed" or food-related buff names
local function HasFoodBuff()
    for i = 1, 40 do
        local auraData = C_UnitAuras.GetBuffDataByIndex("player", i)
        if not auraData then break end
        local name = auraData.name or ""
        local lowerName = name:lower()
        if lowerName:find("well fed") or lowerName:find("food") then
            return true
        end
    end
    return false
end

-- Weapon enchant detection via GetWeaponEnchantInfo()
local function HasWeaponBuff()
    local hasMainHandEnchant, _, _, _, hasOffHandEnchant = GetWeaponEnchantInfo()
    return hasMainHandEnchant or false
end

-- Pet detection - checks if player has an active pet (combat pet, not battle pet)
local function HasPet()
    return UnitExists("pet")
end

-- Pet class summon spell IDs (classID -> list of summon spells)
-- Only classes with permanent combat pets are included
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
                btn:SetAttribute("spell", spell.spellID)
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

local function UpdateReminderFrame()
    if not reminderFrame then return end
    local settings = UIThingsDB.combat.reminders
    if not settings then
        reminderFrame:Hide()
        return
    end

    -- Guard: Never update content in combat to avoid taint
    if InCombatLockdown() then return end

    -- Hide while mounted check is now handled by StateDriver, but keep here just in case config changed
    -- Note: We rely on StateDriver for the actual hiding while mounted/in combat

    -- Build list of missing items only, packed from the top
    local missing = {}
    local petMissing = false

    if settings.flask and not HasFlaskBuff() then
        table.insert(missing, "|cFFFF6666No Flask|r")
    end
    if settings.food and not HasFoodBuff() then
        table.insert(missing, "|cFFFFAA00No Food Buff|r")
    end
    if settings.weaponBuff and not HasWeaponBuff() then
        table.insert(missing, "|cFF66AAFFNo Weapon Buff|r")
    end
    local _, _, classID = UnitClass("player")
    local isPetClass = PET_SUMMON_SPELLS[classID] ~= nil
    if settings.pet and isPetClass and not HasPet() then
        table.insert(missing, "|cFF88FF88No Pet|r")
        petMissing = true
    end

    if #missing == 0 then
        HidePetIcons()
        UnregisterStateDriver(reminderFrame, "visibility")
        reminderFrame:Hide()
        return
    end

    -- Stack missing items from top with no gaps
    local fontSize = settings.fontSize or 12
    local lineHeight = fontSize + 8
    local padding = 12

    for i, line in ipairs(reminderLines) do
        if missing[i] then
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", 12, -8 - (i * lineHeight))
            line:SetText(missing[i])
            line:Show()
        else
            line:Hide()
        end
    end

    ApplyReminderFont()

    -- Fixed height based on number of enabled checks, not current missing count
    local enabledCount = 0
    if settings.flask then enabledCount = enabledCount + 1 end
    if settings.food then enabledCount = enabledCount + 1 end
    if settings.weaponBuff then enabledCount = enabledCount + 1 end
    if settings.pet and isPetClass then enabledCount = enabledCount + 1 end

    local contentHeight = padding + (enabledCount * lineHeight)

    -- Show pet icons at a fixed position based on enabled count
    local petIconHeight = 0
    if settings.pet and isPetClass then
        if petMissing then
            local iconY = -(padding + (enabledCount * lineHeight) + 16)
            petIconHeight = ShowPetIcons(iconY)
        else
            HidePetIcons()
        end
        local iconSize = UIThingsDB.combat.reminders.iconSize or PET_ICON_SIZE
        petIconHeight = iconSize + 8 + 16
    else
        HidePetIcons()
    end

    reminderFrame:SetHeight(contentHeight + petIconHeight + padding)
    
    -- Use State Driver for Visibility
    -- Default behavior: [combat] hide; [mounted] hide; show
    -- If hideInCombat is false: [mounted] hide; show
    local driverStr = "[mounted] hide; show"
    -- Default to true if nil to match legacy behavior
    local doHideInCombat = settings.hideInCombat
    if doHideInCombat == nil then doHideInCombat = true end
    
    if doHideInCombat then
        driverStr = "[combat] hide; " .. driverStr
    end
    
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
    for i = 1, 4 do
        local line = reminderFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        line:SetPoint("TOPLEFT", 12, -8 - (i * 20))
        line:SetFont(initFont, initFontSize, "OUTLINE")
        reminderLines[i] = line
    end

    -- Pre-create secure pet icon buttons (must happen out of combat)
    CreatePetIconButtons()

    ApplyReminderLock()
    reminderFrame:Hide()

    -- Register events for ongoing checks
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("UNIT_PET")
    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    eventFrame:SetScript("OnEvent", function(self, event, arg1)
        if event == "UNIT_AURA" and arg1 ~= "player" then return end
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(3, UpdateReminderFrame)
        else
            UpdateReminderFrame()
        end
    end)

    -- Run initial check now (covers /reload where PLAYER_ENTERING_WORLD already fired)
    C_Timer.After(1, UpdateReminderFrame)
end

function addonTable.Combat.UpdateReminders()
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
