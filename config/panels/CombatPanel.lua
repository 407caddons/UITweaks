local addonName, addonTable = ...

-- Create setup table if it doesn't exist
addonTable.ConfigSetup = addonTable.ConfigSetup or {}

-- Get helpers
local Helpers = addonTable.ConfigHelpers

-- Define the setup function for Combat panel
function addonTable.ConfigSetup.Combat(panel, tab, configWindow)
    Helpers.CreateResetButton(panel, "combat")
    local fonts = Helpers.fonts

    -- Create ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "UIThingsCombatScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 0)

    local child = CreateFrame("Frame", nil, scrollFrame)
    child:SetSize(600, 700) -- Width will be adjusted, Height enough for content
    scrollFrame:SetScrollChild(child)

    -- Auto-adjust width
    scrollFrame:SetScript("OnShow", function()
        child:SetWidth(scrollFrame:GetWidth())
    end)

    local function UpdateCombat()
        if addonTable.Combat and addonTable.Combat.UpdateSettings then
            addonTable.Combat.UpdateSettings()
        end
    end

    -- Enable Combat Timer Checkbox
    local combatTitle = child:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    combatTitle:SetPoint("TOPLEFT", 16, -16)
    combatTitle:SetText("Combat")

    local enableCombatBtn = CreateFrame("CheckButton", "UIThingsCombatEnableCheck", child,
        "ChatConfigCheckButtonTemplate")
    enableCombatBtn:SetPoint("TOPLEFT", 20, -50)
    _G[enableCombatBtn:GetName() .. "Text"]:SetText("Enable Combat Timer")
    enableCombatBtn:SetChecked(UIThingsDB.combat.enabled)
    enableCombatBtn:SetScript("OnClick", function(self)
        local enabled = not not self:GetChecked()
        UIThingsDB.combat.enabled = enabled
        UpdateCombat()
        Helpers.UpdateModuleVisuals(panel, tab, enabled)
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.combat.enabled)

    -- Lock Timer
    local combatLockBtn = CreateFrame("CheckButton", "UIThingsCombatLockCheck", child,
        "ChatConfigCheckButtonTemplate")
    combatLockBtn:SetPoint("TOPLEFT", 20, -70)
    _G[combatLockBtn:GetName() .. "Text"]:SetText("Lock Combat Timer")
    combatLockBtn:SetChecked(UIThingsDB.combat.locked)
    combatLockBtn:SetScript("OnClick", function(self)
        local locked = not not self:GetChecked()
        UIThingsDB.combat.locked = locked
        UpdateCombat()
    end)

    -- Font Selector (Simple Dropdown)
    Helpers.CreateFontDropdown(
        child,
        "UIThingsFontDropdown",
        "Font:",
        UIThingsDB.combat.font,
        function(fontPath, fontName)
            UIThingsDB.combat.font = fontPath
            UpdateCombat()
        end,
        20,
        -110
    )

    -- Font Size Slider
    local fontSizeSlider = CreateFrame("Slider", "UIThingsFontSizeSlider", child, "OptionsSliderTemplate")
    fontSizeSlider:SetPoint("TOPLEFT", 20, -180)
    fontSizeSlider:SetMinMaxValues(10, 32)
    fontSizeSlider:SetValueStep(1)
    fontSizeSlider:SetObeyStepOnDrag(true)
    fontSizeSlider:SetWidth(150)
    _G[fontSizeSlider:GetName() .. 'Text']:SetText(string.format("Size: %d", UIThingsDB.combat.fontSize))
    _G[fontSizeSlider:GetName() .. 'Low']:SetText("10")
    _G[fontSizeSlider:GetName() .. 'High']:SetText("32")
    fontSizeSlider:SetValue(UIThingsDB.combat.fontSize)
    fontSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.combat.fontSize = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Size: %d", value))
        UpdateCombat()
    end)

    -- Color Pickers
    Helpers.CreateColorPicker(child, "UIThingsCombatColorIn", "In Combat Color",
        function()
            return UIThingsDB.combat.colorInCombat.r, UIThingsDB.combat.colorInCombat.g,
                UIThingsDB.combat.colorInCombat.b
        end,
        function(r, g, b)
            UIThingsDB.combat.colorInCombat = { r = r, g = g, b = b }
            UpdateCombat()
        end,
        -230
    )

    Helpers.CreateColorPicker(child, "UIThingsCombatColorOut", "Out Combat Color",
        function()
            return UIThingsDB.combat.colorOutCombat.r, UIThingsDB.combat.colorOutCombat.g,
                UIThingsDB.combat.colorOutCombat.b
        end,
        function(r, g, b)
            UIThingsDB.combat.colorOutCombat = { r = r, g = g, b = b }
            UpdateCombat()
        end,
        -260
    )

    -- Auto Combat Logging Section
    Helpers.CreateSectionHeader(child, "Auto Combat Logging", -295)

    -- Dungeons
    local clDungeonLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    clDungeonLabel:SetPoint("TOPLEFT", 20, -323)
    clDungeonLabel:SetText("Dungeons:")

    local clDNormalCheck = CreateFrame("CheckButton", "UIThingsCLDNormalCheck", child,
        "ChatConfigCheckButtonTemplate")
    clDNormalCheck:SetPoint("TOPLEFT", 100, -320)
    clDNormalCheck:SetHitRectInsets(0, -60, 0, 0)
    _G[clDNormalCheck:GetName() .. "Text"]:SetText("Normal")
    clDNormalCheck:SetChecked(UIThingsDB.combat.combatLog.dungeonNormal)
    clDNormalCheck:SetScript("OnClick", function(self)
        UIThingsDB.combat.combatLog.dungeonNormal = not not self:GetChecked()
        if addonTable.Combat and addonTable.Combat.CheckCombatLogging then
            addonTable.Combat.CheckCombatLogging()
        end
    end)

    local clDHeroicCheck = CreateFrame("CheckButton", "UIThingsCLDHeroicCheck", child,
        "ChatConfigCheckButtonTemplate")
    clDHeroicCheck:SetPoint("LEFT", clDNormalCheck, "RIGHT", 70, 0)
    clDHeroicCheck:SetHitRectInsets(0, -60, 0, 0)
    _G[clDHeroicCheck:GetName() .. "Text"]:SetText("Heroic")
    clDHeroicCheck:SetChecked(UIThingsDB.combat.combatLog.dungeonHeroic)
    clDHeroicCheck:SetScript("OnClick", function(self)
        UIThingsDB.combat.combatLog.dungeonHeroic = not not self:GetChecked()
        if addonTable.Combat and addonTable.Combat.CheckCombatLogging then
            addonTable.Combat.CheckCombatLogging()
        end
    end)

    local clDMythicCheck = CreateFrame("CheckButton", "UIThingsCLDMythicCheck", child,
        "ChatConfigCheckButtonTemplate")
    clDMythicCheck:SetPoint("LEFT", clDHeroicCheck, "RIGHT", 70, 0)
    clDMythicCheck:SetHitRectInsets(0, -60, 0, 0)
    _G[clDMythicCheck:GetName() .. "Text"]:SetText("Mythic")
    clDMythicCheck:SetChecked(UIThingsDB.combat.combatLog.dungeonMythic)
    clDMythicCheck:SetScript("OnClick", function(self)
        UIThingsDB.combat.combatLog.dungeonMythic = not not self:GetChecked()
        if addonTable.Combat and addonTable.Combat.CheckCombatLogging then
            addonTable.Combat.CheckCombatLogging()
        end
    end)

    local clDMPlusCheck = CreateFrame("CheckButton", "UIThingsCLDMPlusCheck", child,
        "ChatConfigCheckButtonTemplate")
    clDMPlusCheck:SetPoint("LEFT", clDMythicCheck, "RIGHT", 70, 0)
    clDMPlusCheck:SetHitRectInsets(0, -60, 0, 0)
    _G[clDMPlusCheck:GetName() .. "Text"]:SetText("Mythic+")
    clDMPlusCheck:SetChecked(UIThingsDB.combat.combatLog.mythicPlus)
    clDMPlusCheck:SetScript("OnClick", function(self)
        UIThingsDB.combat.combatLog.mythicPlus = not not self:GetChecked()
        if addonTable.Combat and addonTable.Combat.CheckCombatLogging then
            addonTable.Combat.CheckCombatLogging()
        end
    end)

    -- Raids
    local clRaidLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    clRaidLabel:SetPoint("TOPLEFT", 20, -353)
    clRaidLabel:SetText("Raids:")

    local clRLFRCheck = CreateFrame("CheckButton", "UIThingsCLRLFRCheck", child,
        "ChatConfigCheckButtonTemplate")
    clRLFRCheck:SetPoint("TOPLEFT", 100, -350)
    clRLFRCheck:SetHitRectInsets(0, -40, 0, 0)
    _G[clRLFRCheck:GetName() .. "Text"]:SetText("LFR")
    clRLFRCheck:SetChecked(UIThingsDB.combat.combatLog.raidLFR)
    clRLFRCheck:SetScript("OnClick", function(self)
        UIThingsDB.combat.combatLog.raidLFR = not not self:GetChecked()
        if addonTable.Combat and addonTable.Combat.CheckCombatLogging then
            addonTable.Combat.CheckCombatLogging()
        end
    end)

    local clRNormalCheck = CreateFrame("CheckButton", "UIThingsCLRNormalCheck", child,
        "ChatConfigCheckButtonTemplate")
    clRNormalCheck:SetPoint("LEFT", clRLFRCheck, "RIGHT", 50, 0)
    clRNormalCheck:SetHitRectInsets(0, -60, 0, 0)
    _G[clRNormalCheck:GetName() .. "Text"]:SetText("Normal")
    clRNormalCheck:SetChecked(UIThingsDB.combat.combatLog.raidNormal)
    clRNormalCheck:SetScript("OnClick", function(self)
        UIThingsDB.combat.combatLog.raidNormal = not not self:GetChecked()
        if addonTable.Combat and addonTable.Combat.CheckCombatLogging then
            addonTable.Combat.CheckCombatLogging()
        end
    end)

    local clRHeroicCheck = CreateFrame("CheckButton", "UIThingsCLRHeroicCheck", child,
        "ChatConfigCheckButtonTemplate")
    clRHeroicCheck:SetPoint("LEFT", clRNormalCheck, "RIGHT", 70, 0)
    clRHeroicCheck:SetHitRectInsets(0, -60, 0, 0)
    _G[clRHeroicCheck:GetName() .. "Text"]:SetText("Heroic")
    clRHeroicCheck:SetChecked(UIThingsDB.combat.combatLog.raidHeroic)
    clRHeroicCheck:SetScript("OnClick", function(self)
        UIThingsDB.combat.combatLog.raidHeroic = not not self:GetChecked()
        if addonTable.Combat and addonTable.Combat.CheckCombatLogging then
            addonTable.Combat.CheckCombatLogging()
        end
    end)

    local clRMythicCheck = CreateFrame("CheckButton", "UIThingsCLRMythicCheck", child,
        "ChatConfigCheckButtonTemplate")
    clRMythicCheck:SetPoint("LEFT", clRHeroicCheck, "RIGHT", 70, 0)
    clRMythicCheck:SetHitRectInsets(0, -60, 0, 0)
    _G[clRMythicCheck:GetName() .. "Text"]:SetText("Mythic")
    clRMythicCheck:SetChecked(UIThingsDB.combat.combatLog.raidMythic)
    clRMythicCheck:SetScript("OnClick", function(self)
        UIThingsDB.combat.combatLog.raidMythic = not not self:GetChecked()
        if addonTable.Combat and addonTable.Combat.CheckCombatLogging then
            addonTable.Combat.CheckCombatLogging()
        end
    end)

    -- Combat Reminders Section
    Helpers.CreateSectionHeader(child, "Combat Reminders", -395)

    local reminderDesc = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    reminderDesc:SetPoint("TOPLEFT", 20, -418)
    reminderDesc:SetText("Show a reminder frame when loading in without these buffs:")

    local function UpdateReminders()
        if addonTable.Combat and addonTable.Combat.UpdateReminders then
            addonTable.Combat.UpdateReminders()
        end
    end

    local reminderLockBtn = CreateFrame("CheckButton", "UIThingsReminderLockCheck", child,
        "ChatConfigCheckButtonTemplate")
    reminderLockBtn:SetPoint("TOPLEFT", 20, -438)
    _G[reminderLockBtn:GetName() .. "Text"]:SetText("Lock Reminder Frame")
    reminderLockBtn:SetChecked(UIThingsDB.combat.reminders.locked)
    reminderLockBtn:SetScript("OnClick", function(self)
        UIThingsDB.combat.reminders.locked = not not self:GetChecked()
        UpdateReminders()
    end)

    local reminderGroupCheck = CreateFrame("CheckButton", "UIThingsReminderGroupCheck", child,
        "ChatConfigCheckButtonTemplate")
    reminderGroupCheck:SetPoint("TOPLEFT", 180, -438) -- Right of Lock
    _G[reminderGroupCheck:GetName() .. "Text"]:SetText("Only in Group")
    reminderGroupCheck:SetChecked(UIThingsDB.combat.reminders.onlyInGroup)
    reminderGroupCheck:SetScript("OnClick", function(self)
        UIThingsDB.combat.reminders.onlyInGroup = not not self:GetChecked()
        UpdateReminders()
    end)

    -- Hide in Combat Check (Moved)
    local combatHideCheck = CreateFrame("CheckButton", "UIThingsReminderHideCombatCheck", child,
        "ChatConfigCheckButtonTemplate")
    combatHideCheck:SetPoint("LEFT", reminderGroupCheck, "RIGHT", 110, 0)
    combatHideCheck:SetHitRectInsets(0, -100, 0, 0)
    _G[combatHideCheck:GetName() .. "Text"]:SetText("Hide in Combat")
    -- Default to true if nil
    local currentHide = UIThingsDB.combat.reminders.hideInCombat
    if currentHide == nil then currentHide = true end
    combatHideCheck:SetChecked(currentHide)

    combatHideCheck:SetScript("OnClick", function(self)
        UIThingsDB.combat.reminders.hideInCombat = not not self:GetChecked()
        UpdateReminders()
    end)

    -- Reminder Font Selector
    Helpers.CreateFontDropdown(
        child,
        "UIThingsReminderFontDropdown",
        "Reminder Font:",
        UIThingsDB.combat.reminders.font,
        function(fontPath, fontName)
            UIThingsDB.combat.reminders.font = fontPath
            UpdateReminders()
        end,
        20,
        -468
    )

    -- Reminder Font Size Slider
    local reminderFontSizeSlider = CreateFrame("Slider", "UIThingsReminderFontSizeSlider", child, "OptionsSliderTemplate")
    reminderFontSizeSlider:SetPoint("TOPLEFT", 20, -530)
    reminderFontSizeSlider:SetMinMaxValues(8, 24)
    reminderFontSizeSlider:SetValueStep(1)
    reminderFontSizeSlider:SetObeyStepOnDrag(true)
    reminderFontSizeSlider:SetWidth(150)
    _G[reminderFontSizeSlider:GetName() .. 'Text']:SetText(string.format("Size: %d", UIThingsDB.combat.reminders
        .fontSize))
    _G[reminderFontSizeSlider:GetName() .. 'Low']:SetText("8")
    _G[reminderFontSizeSlider:GetName() .. 'High']:SetText("24")
    reminderFontSizeSlider:SetValue(UIThingsDB.combat.reminders.fontSize)
    reminderFontSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.combat.reminders.fontSize = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Size: %d", value))
        UpdateReminders()
    end)

    -- Reminder Icon Size Slider
    local reminderIconSizeSlider = CreateFrame("Slider", "UIThingsReminderIconSizeSlider", child, "OptionsSliderTemplate")
    reminderIconSizeSlider:SetPoint("TOPLEFT", 20, -565)
    reminderIconSizeSlider:SetMinMaxValues(16, 48)
    reminderIconSizeSlider:SetValueStep(1)
    reminderIconSizeSlider:SetObeyStepOnDrag(true)
    reminderIconSizeSlider:SetWidth(150)
    _G[reminderIconSizeSlider:GetName() .. 'Text']:SetText(string.format("Icon Size: %d",
        UIThingsDB.combat.reminders.iconSize))
    _G[reminderIconSizeSlider:GetName() .. 'Low']:SetText("16")
    _G[reminderIconSizeSlider:GetName() .. 'High']:SetText("48")
    reminderIconSizeSlider:SetValue(UIThingsDB.combat.reminders.iconSize)
    reminderIconSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.combat.reminders.iconSize = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Icon Size: %d", value))
        UpdateReminders()
    end)

    local flaskCheck = CreateFrame("CheckButton", "UIThingsReminderFlaskCheck", child,
        "ChatConfigCheckButtonTemplate")
    flaskCheck:SetPoint("TOPLEFT", 20, -595)
    flaskCheck:SetHitRectInsets(0, -60, 0, 0)
    _G[flaskCheck:GetName() .. "Text"]:SetText("Flask")
    flaskCheck:SetChecked(UIThingsDB.combat.reminders.flask)
    flaskCheck:SetScript("OnClick", function(self)
        UIThingsDB.combat.reminders.flask = not not self:GetChecked()
        UpdateReminders()
    end)

    local foodCheck = CreateFrame("CheckButton", "UIThingsReminderFoodCheck", child,
        "ChatConfigCheckButtonTemplate")
    foodCheck:SetPoint("LEFT", flaskCheck, "RIGHT", 70, 0)
    foodCheck:SetHitRectInsets(0, -60, 0, 0)
    _G[foodCheck:GetName() .. "Text"]:SetText("Food")
    foodCheck:SetChecked(UIThingsDB.combat.reminders.food)
    foodCheck:SetScript("OnClick", function(self)
        UIThingsDB.combat.reminders.food = not not self:GetChecked()
        UpdateReminders()
    end)

    local weaponCheck = CreateFrame("CheckButton", "UIThingsReminderWeaponCheck", child,
        "ChatConfigCheckButtonTemplate")
    weaponCheck:SetPoint("LEFT", foodCheck, "RIGHT", 70, 0)
    weaponCheck:SetHitRectInsets(0, -100, 0, 0)
    _G[weaponCheck:GetName() .. "Text"]:SetText("Weapon Buff")
    weaponCheck:SetChecked(UIThingsDB.combat.reminders.weaponBuff)
    weaponCheck:SetScript("OnClick", function(self)
        UIThingsDB.combat.reminders.weaponBuff = not not self:GetChecked()
        UpdateReminders()
    end)

    local petCheck = CreateFrame("CheckButton", "UIThingsReminderPetCheck", child,
        "ChatConfigCheckButtonTemplate")
    petCheck:SetPoint("LEFT", weaponCheck, "RIGHT", 100, 0)
    petCheck:SetHitRectInsets(0, -40, 0, 0)
    _G[petCheck:GetName() .. "Text"]:SetText("Pet")
    petCheck:SetChecked(UIThingsDB.combat.reminders.pet)
    petCheck:SetScript("OnClick", function(self)
        UIThingsDB.combat.reminders.pet = not not self:GetChecked()
        UpdateReminders()
    end)

    local classBuffCheck = CreateFrame("CheckButton", "UIThingsReminderClassBuffCheck", child,
        "ChatConfigCheckButtonTemplate")
    classBuffCheck:SetPoint("LEFT", petCheck, "RIGHT", 70, 0)
    classBuffCheck:SetHitRectInsets(0, -100, 0, 0)
    _G[classBuffCheck:GetName() .. "Text"]:SetText("Class Buff")
    classBuffCheck:SetChecked(UIThingsDB.combat.reminders.classBuff)
    classBuffCheck:SetScript("OnClick", function(self)
        UIThingsDB.combat.reminders.classBuff = not not self:GetChecked()
        UpdateReminders()
    end)

    -- Clear Consumable Usage Button
    local clearUsageBtn = CreateFrame("Button", "UIThingsClearUsageBtn", child, "UIPanelButtonTemplate")
    clearUsageBtn:SetSize(180, 24)
    clearUsageBtn:SetPoint("TOPLEFT", 20, -625)
    clearUsageBtn:SetText("Clear Consumable Usage")
    clearUsageBtn:SetScript("OnClick", function()
        if addonTable.Combat and addonTable.Combat.ClearConsumableUsage then
            addonTable.Combat.ClearConsumableUsage()
            addonTable.Core.Log("Combat", "Consumable usage history cleared", 1)
        end
    end)
end
