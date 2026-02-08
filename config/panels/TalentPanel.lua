local addonName, addonTable = ...

-- Create setup table if it doesn't exist
addonTable.ConfigSetup = addonTable.ConfigSetup or {}

-- Get helpers
local Helpers = addonTable.ConfigHelpers

-- Define the setup function for Talent panel
function addonTable.ConfigSetup.Talent(panel, tab, configWindow)
    local fonts = Helpers.fonts

    local talentTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    talentTitle:SetPoint("TOPLEFT", 16, -16)
    talentTitle:SetText("Talent Reminders")

    -- Enable Checkbox
    local enableTalentBtn = CreateFrame("CheckButton", "UIThingsTalentEnableCheck", panel,
        "ChatConfigCheckButtonTemplate")
    enableTalentBtn:SetPoint("TOPLEFT", 20, -50)
    _G[enableTalentBtn:GetName() .. "Text"]:SetText("Enable Talent Reminders")
    enableTalentBtn:SetChecked(UIThingsDB.talentReminders.enabled)
    enableTalentBtn:SetScript("OnClick", function(self)
        local enabled = not not self:GetChecked()
        UIThingsDB.talentReminders.enabled = enabled
        Helpers.UpdateModuleVisuals(panel, tab, enabled)
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.talentReminders.enabled)

    -- Help text
    local enableText = _G[enableTalentBtn:GetName() .. "Text"]
    local helpText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    helpText:SetPoint("LEFT", enableText, "RIGHT", 10, 0)
    helpText:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
    helpText:SetJustifyH("LEFT")
    helpText:SetTextColor(0.6, 0.6, 0.6)
    helpText:SetText(
        "Whenever you are in an instance or boss area you can snapshot your exact talent build, and when you enter that instance on that difficulty again it will highlight differences between your current build as a reminder.")

    -- Alert Settings Section
    Helpers.CreateSectionHeader(panel, "Alert Settings", -80)

    local showPopupCheck = CreateFrame("CheckButton", "UIThingsTalentShowPopupCheck", panel,
        "ChatConfigCheckButtonTemplate")
    showPopupCheck:SetPoint("TOPLEFT", 20, -105)
    showPopupCheck:SetHitRectInsets(0, -110, 0, 0)
    _G[showPopupCheck:GetName() .. "Text"]:SetText("Show Popup Alert")
    showPopupCheck:SetChecked(UIThingsDB.talentReminders.showPopup)
    showPopupCheck:SetScript("OnClick", function(self)
        UIThingsDB.talentReminders.showPopup = not not self:GetChecked()
    end)

    local showChatCheck = CreateFrame("CheckButton", "UIThingsTalentShowChatCheck", panel,
        "ChatConfigCheckButtonTemplate")
    showChatCheck:SetPoint("TOPLEFT", 200, -105)
    showChatCheck:SetHitRectInsets(0, -120, 0, 0)
    _G[showChatCheck:GetName() .. "Text"]:SetText("Show Chat Message")
    showChatCheck:SetChecked(UIThingsDB.talentReminders.showChatMessage)
    showChatCheck:SetScript("OnClick", function(self)
        UIThingsDB.talentReminders.showChatMessage = not not self:GetChecked()
    end)

    local playSoundCheck = CreateFrame("CheckButton", "UIThingsTalentPlaySoundCheck", panel,
        "ChatConfigCheckButtonTemplate")
    playSoundCheck:SetPoint("TOPLEFT", 20, -130)
    playSoundCheck:SetHitRectInsets(0, -80, 0, 0)
    _G[playSoundCheck:GetName() .. "Text"]:SetText("Play Sound")
    playSoundCheck:SetChecked(UIThingsDB.talentReminders.playSound)
    playSoundCheck:SetScript("OnClick", function(self)
        UIThingsDB.talentReminders.playSound = not not self:GetChecked()
    end)

    -- Alert Frame Appearance Section
    Helpers.CreateSectionHeader(panel, "Alert Frame", -155)

    -- Width Slider
    local widthSlider = CreateFrame("Slider", "UIThingsTalentWidthSlider", panel,
        "OptionsSliderTemplate")
    widthSlider:SetPoint("TOPLEFT", 20, -180)
    widthSlider:SetMinMaxValues(300, 800)
    widthSlider:SetValueStep(10)
    widthSlider:SetObeyStepOnDrag(true)
    widthSlider:SetWidth(150)
    _G[widthSlider:GetName() .. 'Text']:SetText(string.format("Width: %d",
        UIThingsDB.talentReminders.frameWidth or 400))
    _G[widthSlider:GetName() .. 'Low']:SetText("300")
    _G[widthSlider:GetName() .. 'High']:SetText("800")
    widthSlider:SetValue(UIThingsDB.talentReminders.frameWidth or 400)
    widthSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.talentReminders.frameWidth = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Width: %d", value))
        if addonTable.TalentReminder and addonTable.TalentReminder.UpdateVisuals then
            addonTable.TalentReminder.UpdateVisuals()
        end
    end)

    -- Height Slider
    local heightSlider = CreateFrame("Slider", "UIThingsTalentHeightSlider", panel,
        "OptionsSliderTemplate")
    heightSlider:SetPoint("TOPLEFT", 200, -180)
    heightSlider:SetMinMaxValues(200, 600)
    heightSlider:SetValueStep(10)
    heightSlider:SetObeyStepOnDrag(true)
    heightSlider:SetWidth(150)
    _G[heightSlider:GetName() .. 'Text']:SetText(string.format("Height: %d",
        UIThingsDB.talentReminders.frameHeight or 300))
    _G[heightSlider:GetName() .. 'Low']:SetText("200")
    _G[heightSlider:GetName() .. 'High']:SetText("600")
    heightSlider:SetValue(UIThingsDB.talentReminders.frameHeight or 300)
    heightSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.talentReminders.frameHeight = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Height: %d", value))
        if addonTable.TalentReminder and addonTable.TalentReminder.UpdateVisuals then
            addonTable.TalentReminder.UpdateVisuals()
        end
    end)

    -- Font Dropdown
    Helpers.CreateFontDropdown(
        panel,
        "UIThingsTalentFontDropdown",
        "Font:",
        UIThingsDB.talentReminders.alertFont,
        function(fontPath, fontName)
            UIThingsDB.talentReminders.alertFont = fontPath
            if addonTable.TalentReminder and addonTable.TalentReminder.UpdateVisuals then
                addonTable.TalentReminder.UpdateVisuals()
            end
        end,
        380,
        -183
    )

    -- Font Size Slider
    local fontSizeSlider = CreateFrame("Slider", "UIThingsTalentAlertFontSizeSlider", panel,
        "OptionsSliderTemplate")
    fontSizeSlider:SetPoint("TOPLEFT", 20, -220)
    fontSizeSlider:SetMinMaxValues(8, 24)
    fontSizeSlider:SetValueStep(1)
    fontSizeSlider:SetObeyStepOnDrag(true)
    fontSizeSlider:SetWidth(150)
    local fontSizeText = _G[fontSizeSlider:GetName() .. 'Text']
    local fontSizeLow = _G[fontSizeSlider:GetName() .. 'Low']
    local fontSizeHigh = _G[fontSizeSlider:GetName() .. 'High']
    fontSizeText:SetText(string.format("Font Size: %d", UIThingsDB.talentReminders.alertFontSize))
    fontSizeLow:SetText("8")
    fontSizeHigh:SetText("24")
    fontSizeSlider:SetValue(UIThingsDB.talentReminders.alertFontSize)
    fontSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.talentReminders.alertFontSize = value
        fontSizeText:SetText(string.format("Font Size: %d", value))
        if addonTable.TalentReminder then
            if addonTable.TalentReminder.UpdateVisuals then
                addonTable.TalentReminder.UpdateVisuals()
            end
        end
    end)

    -- Icon Size Slider
    local iconSizeSlider = CreateFrame("Slider", "UIThingsTalentAlertIconSizeSlider", panel,
        "OptionsSliderTemplate")
    iconSizeSlider:SetPoint("TOPLEFT", 200, -220)
    iconSizeSlider:SetMinMaxValues(12, 32)
    iconSizeSlider:SetValueStep(2)
    iconSizeSlider:SetObeyStepOnDrag(true)
    iconSizeSlider:SetWidth(150)
    local iconSizeText = _G[iconSizeSlider:GetName() .. 'Text']
    local iconSizeLow = _G[iconSizeSlider:GetName() .. 'Low']
    local iconSizeHigh = _G[iconSizeSlider:GetName() .. 'High']
    iconSizeText:SetText(string.format("Icon Size: %d", UIThingsDB.talentReminders.alertIconSize))
    iconSizeLow:SetText("12")
    iconSizeHigh:SetText("32")
    iconSizeSlider:SetValue(UIThingsDB.talentReminders.alertIconSize)
    iconSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / 2) * 2 -- Round to nearest even number
        UIThingsDB.talentReminders.alertIconSize = value
        iconSizeText:SetText(string.format("Icon Size: %d", value))
        if addonTable.TalentReminder then
            if addonTable.TalentReminder.UpdateVisuals then
                addonTable.TalentReminder.UpdateVisuals()
            end
            -- Refresh alert content if currently showing
            if addonTable.TalentReminder.RefreshCurrentAlert then
                addonTable.TalentReminder.RefreshCurrentAlert()
            end
        end
    end)

    -- Border & Background Settings
    Helpers.CreateSectionHeader(panel, "Border & Background", -255)

    -- Row 1: Border
    local borderCheckbox = CreateFrame("CheckButton", "UIThingsTalentBorderCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    borderCheckbox:SetPoint("TOPLEFT", 20, -280)
    borderCheckbox:SetHitRectInsets(0, -80, 0, 0)
    _G[borderCheckbox:GetName() .. "Text"]:SetText("Show Border")
    borderCheckbox:SetChecked(UIThingsDB.talentReminders.showBorder)
    borderCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.talentReminders.showBorder = not not self:GetChecked()
        if addonTable.TalentReminder and addonTable.TalentReminder.UpdateVisuals then
            addonTable.TalentReminder.UpdateVisuals()
        end
    end)

    local borderColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    borderColorLabel:SetPoint("TOPLEFT", 140, -283)
    borderColorLabel:SetText("Color:")

    local borderColorSwatch = CreateFrame("Button", nil, panel)
    borderColorSwatch:SetSize(20, 20)
    borderColorSwatch:SetPoint("LEFT", borderColorLabel, "RIGHT", 5, 0)

    borderColorSwatch.tex = borderColorSwatch:CreateTexture(nil, "OVERLAY")
    borderColorSwatch.tex:SetAllPoints()
    local bc = UIThingsDB.talentReminders.borderColor or { r = 0, g = 0, b = 0, a = 1 }
    borderColorSwatch.tex:SetColorTexture(bc.r, bc.g, bc.b, bc.a)

    Mixin(borderColorSwatch, BackdropTemplateMixin)
    borderColorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    borderColorSwatch:SetBackdropBorderColor(1, 1, 1)

    borderColorSwatch:SetScript("OnClick", function(self)
        local info = UIDropDownMenu_CreateInfo()
        local prevR, prevG, prevB, prevA = bc.r, bc.g, bc.b, bc.a

        info.r, info.g, info.b, info.opacity = prevR, prevG, prevB, prevA
        info.hasOpacity = true
        info.opacityFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            bc.r, bc.g, bc.b, bc.a = r, g, b, a
            borderColorSwatch.tex:SetColorTexture(r, g, b, a)
            UIThingsDB.talentReminders.borderColor = bc
            if addonTable.TalentReminder and addonTable.TalentReminder.UpdateVisuals then
                addonTable.TalentReminder.UpdateVisuals()
            end
        end
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            bc.r, bc.g, bc.b, bc.a = r, g, b, a
            borderColorSwatch.tex:SetColorTexture(r, g, b, a)
            UIThingsDB.talentReminders.borderColor = bc
            if addonTable.TalentReminder and addonTable.TalentReminder.UpdateVisuals then
                addonTable.TalentReminder.UpdateVisuals()
            end
        end
        info.cancelFunc = function(previousValues)
            bc.r, bc.g, bc.b, bc.a = prevR, prevG, prevB, prevA
            borderColorSwatch.tex:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
            UIThingsDB.talentReminders.borderColor = bc
            if addonTable.TalentReminder and addonTable.TalentReminder.UpdateVisuals then
                addonTable.TalentReminder.UpdateVisuals()
            end
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    -- Row 2: Background
    local bgCheckbox = CreateFrame("CheckButton", "UIThingsTalentBgCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    bgCheckbox:SetPoint("TOPLEFT", 20, -305)
    bgCheckbox:SetHitRectInsets(0, -110, 0, 0)
    _G[bgCheckbox:GetName() .. "Text"]:SetText("Show Background")
    bgCheckbox:SetChecked(UIThingsDB.talentReminders.showBackground)
    bgCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.talentReminders.showBackground = not not self:GetChecked()
        if addonTable.TalentReminder and addonTable.TalentReminder.UpdateVisuals then
            addonTable.TalentReminder.UpdateVisuals()
        end
    end)

    local bgColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bgColorLabel:SetPoint("TOPLEFT", 165, -308)
    bgColorLabel:SetText("Color:")

    local bgColorSwatch = CreateFrame("Button", nil, panel)
    bgColorSwatch:SetSize(20, 20)
    bgColorSwatch:SetPoint("LEFT", bgColorLabel, "RIGHT", 5, 0)

    bgColorSwatch.tex = bgColorSwatch:CreateTexture(nil, "OVERLAY")
    bgColorSwatch.tex:SetAllPoints()
    local c = UIThingsDB.talentReminders.backgroundColor or { r = 0, g = 0, b = 0, a = 0.8 }
    bgColorSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)

    Mixin(bgColorSwatch, BackdropTemplateMixin)
    bgColorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    bgColorSwatch:SetBackdropBorderColor(1, 1, 1)

    bgColorSwatch:SetScript("OnClick", function(self)
        local info = UIDropDownMenu_CreateInfo()
        local prevR, prevG, prevB, prevA = c.r, c.g, c.b, c.a

        info.r, info.g, info.b, info.opacity = prevR, prevG, prevB, prevA
        info.hasOpacity = true
        info.opacityFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            c.r, c.g, c.b, c.a = r, g, b, a
            bgColorSwatch.tex:SetColorTexture(r, g, b, a)
            UIThingsDB.talentReminders.backgroundColor = c
            if addonTable.TalentReminder and addonTable.TalentReminder.UpdateVisuals then
                addonTable.TalentReminder.UpdateVisuals()
            end
        end
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            c.r, c.g, c.b, c.a = r, g, b, a
            bgColorSwatch.tex:SetColorTexture(r, g, b, a)
            UIThingsDB.talentReminders.backgroundColor = c
            if addonTable.TalentReminder and addonTable.TalentReminder.UpdateVisuals then
                addonTable.TalentReminder.UpdateVisuals()
            end
        end
        info.cancelFunc = function(previousValues)
            c.r, c.g, c.b, c.a = prevR, prevG, prevB, prevA
            bgColorSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
            UIThingsDB.talentReminders.backgroundColor = c
            if addonTable.TalentReminder and addonTable.TalentReminder.UpdateVisuals then
                addonTable.TalentReminder.UpdateVisuals()
            end
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    -- Difficulty Filter Section
    Helpers.CreateSectionHeader(panel, "Alert Only On These Difficulties", -335)

    -- Helper function to handle difficulty checkbox changes
    local function OnDifficultyCheckChanged(wasEnabled, isNowEnabled)
        if not addonTable.TalentReminder then return end

        local _, _, currentDifficultyID = GetInstanceInfo()

        if wasEnabled and not isNowEnabled then
            local alertFrame = _G["LunaTalentReminderAlert"]
            if alertFrame and alertFrame:IsShown() then
                alertFrame:Hide()
            end
        elseif not wasEnabled and isNowEnabled then
            addonTable.Core.SafeAfter(0.5, function()
                if addonTable.TalentReminder.CheckTalentsInInstance then
                    addonTable.TalentReminder.CheckTalentsInInstance()
                end
            end)
        end
    end

    -- Dungeons
    local dungeonLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dungeonLabel:SetPoint("TOPLEFT", 20, -363)
    dungeonLabel:SetText("Dungeons:")

    local dNormalCheck = CreateFrame("CheckButton", "UIThingsTalentDNormalCheck", panel,
        "ChatConfigCheckButtonTemplate")
    dNormalCheck:SetPoint("TOPLEFT", 100, -360)
    dNormalCheck:SetHitRectInsets(0, -60, 0, 0)
    _G[dNormalCheck:GetName() .. "Text"]:SetText("Normal")
    dNormalCheck:SetChecked(UIThingsDB.talentReminders.alertOnDifficulties.dungeonNormal)
    dNormalCheck:SetScript("OnClick", function(self)
        local wasEnabled = UIThingsDB.talentReminders.alertOnDifficulties.dungeonNormal
        local isNowEnabled = not not self:GetChecked()
        UIThingsDB.talentReminders.alertOnDifficulties.dungeonNormal = isNowEnabled
        OnDifficultyCheckChanged(wasEnabled, isNowEnabled)
    end)

    local dHeroicCheck = CreateFrame("CheckButton", "UIThingsTalentDHeroicCheck", panel,
        "ChatConfigCheckButtonTemplate")
    dHeroicCheck:SetPoint("LEFT", dNormalCheck, "RIGHT", 70, 0)
    dHeroicCheck:SetHitRectInsets(0, -60, 0, 0)
    _G[dHeroicCheck:GetName() .. "Text"]:SetText("Heroic")
    dHeroicCheck:SetChecked(UIThingsDB.talentReminders.alertOnDifficulties.dungeonHeroic)
    dHeroicCheck:SetScript("OnClick", function(self)
        local wasEnabled = UIThingsDB.talentReminders.alertOnDifficulties.dungeonHeroic
        local isNowEnabled = not not self:GetChecked()
        UIThingsDB.talentReminders.alertOnDifficulties.dungeonHeroic = isNowEnabled
        OnDifficultyCheckChanged(wasEnabled, isNowEnabled)
    end)

    local dMythicCheck = CreateFrame("CheckButton", "UIThingsTalentDMythicCheck", panel,
        "ChatConfigCheckButtonTemplate")
    dMythicCheck:SetPoint("LEFT", dHeroicCheck, "RIGHT", 70, 0)
    dMythicCheck:SetHitRectInsets(0, -60, 0, 0)
    _G[dMythicCheck:GetName() .. "Text"]:SetText("Mythic")
    dMythicCheck:SetChecked(UIThingsDB.talentReminders.alertOnDifficulties.dungeonMythic)
    dMythicCheck:SetScript("OnClick", function(self)
        local wasEnabled = UIThingsDB.talentReminders.alertOnDifficulties.dungeonMythic
        local isNowEnabled = not not self:GetChecked()
        UIThingsDB.talentReminders.alertOnDifficulties.dungeonMythic = isNowEnabled
        OnDifficultyCheckChanged(wasEnabled, isNowEnabled)
    end)

    -- Raids
    local raidLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    raidLabel:SetPoint("TOPLEFT", 20, -393)
    raidLabel:SetText("Raids:")

    local rLFRCheck = CreateFrame("CheckButton", "UIThingsTalentRLFRCheck", panel,
        "ChatConfigCheckButtonTemplate")
    rLFRCheck:SetPoint("TOPLEFT", 100, -390)
    rLFRCheck:SetHitRectInsets(0, -40, 0, 0)
    _G[rLFRCheck:GetName() .. "Text"]:SetText("LFR")
    rLFRCheck:SetChecked(UIThingsDB.talentReminders.alertOnDifficulties.raidLFR)
    rLFRCheck:SetScript("OnClick", function(self)
        local wasEnabled = UIThingsDB.talentReminders.alertOnDifficulties.raidLFR
        local isNowEnabled = not not self:GetChecked()
        UIThingsDB.talentReminders.alertOnDifficulties.raidLFR = isNowEnabled
        OnDifficultyCheckChanged(wasEnabled, isNowEnabled)
    end)

    local rNormalCheck = CreateFrame("CheckButton", "UIThingsTalentRNormalCheck", panel,
        "ChatConfigCheckButtonTemplate")
    rNormalCheck:SetPoint("LEFT", rLFRCheck, "RIGHT", 50, 0)
    rNormalCheck:SetHitRectInsets(0, -60, 0, 0)
    _G[rNormalCheck:GetName() .. "Text"]:SetText("Normal")
    rNormalCheck:SetChecked(UIThingsDB.talentReminders.alertOnDifficulties.raidNormal)
    rNormalCheck:SetScript("OnClick", function(self)
        local wasEnabled = UIThingsDB.talentReminders.alertOnDifficulties.raidNormal
        local isNowEnabled = not not self:GetChecked()
        UIThingsDB.talentReminders.alertOnDifficulties.raidNormal = isNowEnabled
        OnDifficultyCheckChanged(wasEnabled, isNowEnabled)
    end)

    local rHeroicCheck = CreateFrame("CheckButton", "UIThingsTalentRHeroicCheck", panel,
        "ChatConfigCheckButtonTemplate")
    rHeroicCheck:SetPoint("LEFT", rNormalCheck, "RIGHT", 70, 0)
    rHeroicCheck:SetHitRectInsets(0, -60, 0, 0)
    _G[rHeroicCheck:GetName() .. "Text"]:SetText("Heroic")
    rHeroicCheck:SetChecked(UIThingsDB.talentReminders.alertOnDifficulties.raidHeroic)
    rHeroicCheck:SetScript("OnClick", function(self)
        local wasEnabled = UIThingsDB.talentReminders.alertOnDifficulties.raidHeroic
        local isNowEnabled = not not self:GetChecked()
        UIThingsDB.talentReminders.alertOnDifficulties.raidHeroic = isNowEnabled
        OnDifficultyCheckChanged(wasEnabled, isNowEnabled)
    end)

    local rMythicCheck = CreateFrame("CheckButton", "UIThingsTalentRMythicCheck", panel,
        "ChatConfigCheckButtonTemplate")
    rMythicCheck:SetPoint("LEFT", rHeroicCheck, "RIGHT", 70, 0)
    rMythicCheck:SetHitRectInsets(0, -60, 0, 0)
    _G[rMythicCheck:GetName() .. "Text"]:SetText("Mythic")
    rMythicCheck:SetChecked(UIThingsDB.talentReminders.alertOnDifficulties.raidMythic)
    rMythicCheck:SetScript("OnClick", function(self)
        local wasEnabled = UIThingsDB.talentReminders.alertOnDifficulties.raidMythic
        local isNowEnabled = not not self:GetChecked()
        UIThingsDB.talentReminders.alertOnDifficulties.raidMythic = isNowEnabled
        OnDifficultyCheckChanged(wasEnabled, isNowEnabled)
    end)

    -- Reminders Section
    Helpers.CreateSectionHeader(panel, "Saved Builds", -420)

    -- Reminder List (Scroll Frame)
    local reminderScrollFrame = CreateFrame("ScrollFrame", "UIThingsTalentReminderScroll", panel,
        "UIPanelScrollFrameTemplate")
    reminderScrollFrame:SetSize(520, 180) -- 215
    reminderScrollFrame:SetPoint("TOPLEFT", 20, -445)

    local reminderContent = CreateFrame("Frame", nil, reminderScrollFrame)
    reminderContent:SetSize(500, 1)
    reminderScrollFrame:SetScrollChild(reminderContent)

    -- Track created rows for reuse
    local reminderRows = {}

    -- Refresh reminder list function (frame-based)
    local function RefreshReminderList()
        -- Get current class/spec for filtering
        local _, _, playerClassID = UnitClass("player")
        local specIndex = GetSpecialization()
        local playerSpecID = specIndex and select(1, GetSpecializationInfo(specIndex))

        -- Get current instance info
        local _, currentInstanceType, currentDifficultyID, _, _, _, _, currentInstanceID = GetInstanceInfo()

        -- Get current zone for zone-specific highlighting
        local currentZone = addonTable.TalentReminder and addonTable.TalentReminder.GetCurrentZone() or nil

        -- Hide all existing rows first
        for _, row in ipairs(reminderRows) do
            row:Hide()
        end

        local rowIndex = 0
        local yOffset = -5

        -- Helper function to compare talent builds for equality
        local function TalentBuildsEqual(talents1, talents2)
            if not talents1 or not talents2 then return false end

            local count1, count2 = 0, 0
            for _ in pairs(talents1) do count1 = count1 + 1 end
            for _ in pairs(talents2) do count2 = count2 + 1 end
            if count1 ~= count2 then return false end

            for nodeID, data1 in pairs(talents1) do
                local data2 = talents2[nodeID]
                if not data2 then return false end
                if data1.entryID ~= data2.entryID then return false end
                if data1.rank ~= data2.rank then return false end
            end

            return true
        end

        -- First pass: collect and group reminders by identical builds
        local sortedReminders = {}

        if LunaUITweaks_TalentReminders and LunaUITweaks_TalentReminders.reminders then
            for instanceID, reminders in pairs(LunaUITweaks_TalentReminders.reminders) do
                for diffID, diffReminders in pairs(reminders) do
                    for zoneKey, reminder in pairs(diffReminders) do
                        -- Filter: only show reminders for current class/spec OR unknown
                        local showReminder = true
                        if reminder.classID and reminder.classID ~= playerClassID then
                            showReminder = false
                        elseif reminder.specID and reminder.specID ~= playerSpecID then
                            showReminder = false
                        end

                        if showReminder then
                            -- Check if this reminder matches current instance/difficulty/zone
                            local isCurrentZone = false
                            if currentInstanceID and currentInstanceID ~= 0 and
                                currentDifficultyID and
                                currentZone and currentZone ~= "" then
                                isCurrentZone = (tonumber(instanceID) == tonumber(currentInstanceID) and
                                    tonumber(diffID) == tonumber(currentDifficultyID) and
                                    zoneKey == currentZone)
                            end

                            -- Try to find existing entry with same instance, zone, and talents
                            local foundMatch = false
                            for _, existing in ipairs(sortedReminders) do
                                if tonumber(existing.instanceID) == tonumber(instanceID) and
                                    existing.zoneKey == zoneKey and
                                    TalentBuildsEqual(existing.reminder.talents, reminder.talents) then
                                    -- Same build - add this difficulty to the list
                                    table.insert(existing.difficulties, {
                                        diffID = diffID,
                                        difficultyName = reminder.difficulty or "Unknown",
                                        isCurrentZone = isCurrentZone
                                    })
                                    -- Update overall isCurrentZone if any difficulty matches
                                    existing.isCurrentZone = existing.isCurrentZone or isCurrentZone
                                    foundMatch = true
                                    break
                                end
                            end

                            if not foundMatch then
                                -- New unique build
                                table.insert(sortedReminders, {
                                    instanceID = instanceID,
                                    zoneKey = zoneKey,
                                    reminder = reminder,
                                    isCurrentZone = isCurrentZone,
                                    difficulties = { {
                                        diffID = diffID,
                                        difficultyName = reminder.difficulty or "Unknown",
                                        isCurrentZone = isCurrentZone
                                    } }
                                })
                            end
                        end
                    end
                end
            end

            -- Sort: current zone first, then alphabetically by name
            table.sort(sortedReminders, function(a, b)
                if a.isCurrentZone ~= b.isCurrentZone then
                    return a.isCurrentZone
                end
                return (a.reminder.name or "") < (b.reminder.name or "")
            end)
        end

        -- Second pass: display sorted reminders
        for _, entry in ipairs(sortedReminders) do
            local instanceID = entry.instanceID
            local zoneKey = entry.zoneKey
            local reminder = entry.reminder
            local isCurrentZone = entry.isCurrentZone
            local difficulties = entry.difficulties

            rowIndex = rowIndex + 1

            -- Create or reuse row frame
            local row = reminderRows[rowIndex]
            if not row then
                row = CreateFrame("Frame", nil, reminderContent)
                row:SetSize(490, 58)

                -- Background for highlighting
                row.bg = row:CreateTexture(nil, "BACKGROUND")
                row.bg:SetAllPoints()
                row.bg:SetColorTexture(0, 0, 0, 0)

                -- Class/Spec label
                row.classSpecLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.classSpecLabel:SetPoint("TOPLEFT", 5, -2)
                row.classSpecLabel:SetWidth(350)
                row.classSpecLabel:SetJustifyH("LEFT")

                -- Reminder name
                row.nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.nameLabel:SetPoint("TOPLEFT", 5, -15)
                row.nameLabel:SetWidth(350)
                row.nameLabel:SetJustifyH("LEFT")

                -- Instance/Difficulty
                row.infoLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.infoLabel:SetPoint("TOPLEFT", 10, -30)
                row.infoLabel:SetWidth(350)
                row.infoLabel:SetJustifyH("LEFT")

                -- Validation status icon/text
                row.validationLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.validationLabel:SetPoint("TOPRIGHT", -85, -15)
                row.validationLabel:SetWidth(100)
                row.validationLabel:SetJustifyH("RIGHT")

                -- Enable/Disable button
                row.enableBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.enableBtn:SetSize(60, 22)
                row.enableBtn:SetPoint("TOPRIGHT", -10, -5)
                row.enableBtn:SetNormalFontObject("GameFontNormalSmall")

                -- Delete button (below enable button)
                row.deleteBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.deleteBtn:SetSize(60, 22)
                row.deleteBtn:SetPoint("TOP", row.enableBtn, "BOTTOM", 0, -4)
                row.deleteBtn:SetText("Delete")
                row.deleteBtn:SetNormalFontObject("GameFontNormalSmall")

                reminderRows[rowIndex] = row
            end

            -- Position row
            row:ClearAllPoints()
            row:SetSize(490, 58)
            row:SetPoint("TOPLEFT", 0, yOffset)
            yOffset = yOffset - 63

            -- Ensure all labels exist
            if not row.bg then
                row.bg = row:CreateTexture(nil, "BACKGROUND")
                row.bg:SetAllPoints()
            end

            if not row.nameLabel then
                row.nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.nameLabel:SetPoint("TOPLEFT", 5, -15)
                row.nameLabel:SetWidth(350)
                row.nameLabel:SetJustifyH("LEFT")
            else
                row.nameLabel:SetFontObject("GameFontNormal")
            end
            if not row.classSpecLabel then
                row.classSpecLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.classSpecLabel:SetPoint("TOPLEFT", 5, -2)
                row.classSpecLabel:SetWidth(350)
                row.classSpecLabel:SetJustifyH("LEFT")
            end
            if not row.infoLabel then
                row.infoLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.infoLabel:SetPoint("TOPLEFT", 10, -30)
                row.infoLabel:SetWidth(350)
                row.infoLabel:SetJustifyH("LEFT")
            end
            if not row.validationLabel then
                row.validationLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.validationLabel:SetPoint("TOPRIGHT", -85, -15)
                row.validationLabel:SetWidth(100)
                row.validationLabel:SetJustifyH("RIGHT")
            end
            if not row.enableBtn then
                row.enableBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.enableBtn:SetSize(60, 22)
                row.enableBtn:SetPoint("TOPRIGHT", -10, -5)
                row.enableBtn:SetNormalFontObject("GameFontNormalSmall")
            end
            if not row.deleteBtn then
                row.deleteBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.deleteBtn:SetSize(60, 22)
                row.deleteBtn:SetPoint("TOP", row.enableBtn, "BOTTOM", 0, -4)
                row.deleteBtn:SetText("Delete")
                row.deleteBtn:SetNormalFontObject("GameFontNormalSmall")
            end

            -- Show all reminder elements
            row.nameLabel:Show()
            row.classSpecLabel:Show()
            row.infoLabel:Show()
            row.validationLabel:Show()
            row.enableBtn:Show()
            row.deleteBtn:Show()

            -- Hide message label if it exists
            if row.messageLabel then
                row.messageLabel:Hide()
            end

            -- Check if build is disabled
            local isDisabled = reminder.disabled

            -- Highlight current zone with green background (only if enabled)
            if isDisabled then
                row.bg:SetColorTexture(0.2, 0.2, 0.2, 0.3)
                row.nameLabel:SetText(string.format("|cFF666666%s (Disabled)|r", reminder.name))
            elseif isCurrentZone then
                row.bg:SetColorTexture(0, 0.3, 0, 0.3)
                row.nameLabel:SetText(string.format("|cFF00FF00%s|r", reminder.name))
            else
                row.bg:SetColorTexture(0, 0, 0, 0)
                row.nameLabel:SetText(string.format("|cFFFFAA00%s|r", reminder.name))
            end

            -- Set data
            row.classSpecLabel:SetText(addonTable.TalentReminder.GetClassSpecString(reminder))

            -- Build difficulty list
            local difficultyText
            if #difficulties == 1 then
                difficultyText = difficulties[1].difficultyName
            else
                local diffNames = {}
                for _, diff in ipairs(difficulties) do
                    table.insert(diffNames, diff.difficultyName)
                end
                table.sort(diffNames)
                difficultyText = table.concat(diffNames, ", ")
            end

            -- Show zone and "CURRENT ZONE" indicator
            local infoText = string.format("Instance: %s | Diff: %s",
                reminder.instanceName or "Unknown",
                difficultyText)
            if isCurrentZone then
                infoText = infoText .. " |cFF00FF00- CURRENT ZONE|r"
            end
            row.infoLabel:SetText(infoText)

            -- Validate build
            local isValid, invalidTalents = addonTable.TalentReminder.ValidateTalentBuild(reminder.talents)
            if not isValid and #invalidTalents > 0 then
                row.validationLabel:SetText("|cFFFF0000Invalid Build|r")
                row.validationLabel:SetPoint("TOPRIGHT", -85, -15)
            else
                row.validationLabel:SetText("")
            end

            -- Set enable/disable button state and action
            row.enableBtn:SetText(isDisabled and "Enable" or "Disable")
            row.enableBtn.instanceID = instanceID
            row.enableBtn.zoneKey = zoneKey
            row.enableBtn.difficulties = difficulties
            row.enableBtn:SetScript("OnClick", function(self)
                local newState = not isDisabled
                for _, diff in ipairs(self.difficulties) do
                    local r = LunaUITweaks_TalentReminders.reminders[self.instanceID]
                        and LunaUITweaks_TalentReminders.reminders[self.instanceID][diff.diffID]
                        and LunaUITweaks_TalentReminders.reminders[self.instanceID][diff.diffID][self.zoneKey]
                    if r then
                        r.disabled = newState or nil
                    end
                end
                if newState then
                    -- Disabled: hide the alert if it's showing
                    local alertFrame = _G["LunaTalentReminderAlert"]
                    if alertFrame and alertFrame:IsShown() then
                        alertFrame:Hide()
                    end
                else
                    -- Enabled: re-check talents in case this reminder is relevant now
                    if addonTable.TalentReminder and addonTable.TalentReminder.CheckTalentsInInstance then
                        addonTable.Core.SafeAfter(0.3, function()
                            addonTable.TalentReminder.CheckTalentsInInstance()
                        end)
                    end
                end
                RefreshReminderList()
            end)

            -- Set delete button action
            row.deleteBtn.instanceID = instanceID
            row.deleteBtn.zoneKey = zoneKey
            row.deleteBtn.difficulties = difficulties
            row.deleteBtn:SetScript("OnClick", function(self)
                local confirmText = reminder.name
                if #self.difficulties > 1 then
                    confirmText = confirmText .. " (" .. #self.difficulties .. " difficulties)"
                end

                StaticPopup_Show("LUNA_TALENT_DELETE_GROUP_CONFIRM", confirmText, nil, {
                    instanceID = self.instanceID,
                    zoneKey = self.zoneKey,
                    difficulties = self.difficulties
                })
            end)

            row:Show()
        end

        -- Show "no reminders" message if empty
        if rowIndex == 0 then
            local row = reminderRows[1]
            if not row then
                row = CreateFrame("Frame", nil, reminderContent)
                row:SetSize(490, 100)
                reminderRows[1] = row
            end

            if not row.messageLabel then
                row.messageLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.messageLabel:SetPoint("TOPLEFT", 5, -5)
                row.messageLabel:SetWidth(480)
                row.messageLabel:SetJustifyH("LEFT")
            end

            -- Hide all reminder-specific elements if they exist
            if row.classSpecLabel then row.classSpecLabel:Hide() end
            if row.nameLabel then row.nameLabel:Hide() end
            if row.infoLabel then row.infoLabel:Hide() end
            if row.validationLabel then row.validationLabel:Hide() end
            if row.enableBtn then row.enableBtn:Hide() end
            if row.deleteBtn then row.deleteBtn:Hide() end
            if row.bg then row.bg:SetColorTexture(0, 0, 0, 0) end

            row:SetPoint("TOPLEFT", 0, -5)
            row.messageLabel:SetText(
                "|cFFAAAAAANo reminders saved for your current class/spec.\n\n" ..
                "Enter a dungeon or raid, configure your talents, then click " ..
                "'Snapshot Current Talents' below.|r")
            row.messageLabel:Show()
            row:Show()
        end

        -- Update scroll child height
        local contentHeight = math.max(215, math.abs(yOffset) + 5)
        reminderContent:SetHeight(contentHeight)
    end

    -- Store in addonTable.Config for access from ConfigMain tab click handler
    addonTable.Config.RefreshTalentReminderList = RefreshReminderList

    -- Function to check if player is in an instance
    local function IsInInstance()
        local _, instanceType = GetInstanceInfo()
        return instanceType ~= "none"
    end

    RefreshReminderList()

    -- Declare buttons upfront
    local snapshotBtn
    local testBtn

    -- Function to update button states based on instance status
    local function UpdateButtonStates()
        local inInstance = IsInInstance()
        if snapshotBtn then
            if inInstance then
                snapshotBtn:Enable()
                snapshotBtn:SetAlpha(1.0)
            else
                snapshotBtn:Disable()
                snapshotBtn:SetAlpha(0.5)
            end
        end
        if testBtn then
            if inInstance then
                testBtn:Enable()
                testBtn:SetAlpha(1.0)
            else
                testBtn:Disable()
                testBtn:SetAlpha(0.5)
            end
        end
    end

    -- Snapshot Button
    snapshotBtn = CreateFrame("Button", nil, panel, "GameMenuButtonTemplate")
    snapshotBtn:SetSize(200, 30)
    snapshotBtn:SetPoint("BOTTOMLEFT", 20, 10)
    snapshotBtn:SetText("Snapshot Current Talents")
    snapshotBtn:SetNormalFontObject("GameFontNormal")
    snapshotBtn:SetHighlightFontObject("GameFontHighlight")
    snapshotBtn:SetScript("OnClick", function(self)
        if not addonTable.TalentReminder then
            return
        end

        local location = addonTable.TalentReminder.GetCurrentLocation()
        if not location or location.instanceID == 0 then
            return
        end

        local zoneName = location.zoneName or "general"

        local name
        if zoneName == "general" or not zoneName then
            name = string.format("%s (%s)", location.instanceName, location.difficultyName)
        else
            name = string.format("%s - %s (%s)", location.instanceName, zoneName, location.difficultyName)
        end

        local success, err, count = addonTable.TalentReminder.SaveReminder(
            location.instanceID,
            location.difficultyID,
            zoneName,
            name,
            location.instanceName,
            location.difficultyName,
            ""
        )

        if success then
            RefreshReminderList()
        end
    end)

    -- Test Button
    testBtn = CreateFrame("Button", nil, panel, "GameMenuButtonTemplate")
    testBtn:SetSize(120, 30)
    testBtn:SetPoint("LEFT", snapshotBtn, "RIGHT", 10, 0)
    testBtn:SetText("Test")
    testBtn:SetNormalFontObject("GameFontNormal")
    testBtn:SetHighlightFontObject("GameFontHighlight")
    testBtn:SetScript("OnClick", function(self)
        if not addonTable.TalentReminder then
            return
        end

        if not LunaUITweaks_TalentReminders or not LunaUITweaks_TalentReminders.reminders then
            return
        end

        local currentZone = addonTable.TalentReminder.GetCurrentZone()
        local location = addonTable.TalentReminder.GetCurrentLocation()

        print("|cFF00FF00[Talent Reminder Test]|r")
        print(string.format("  Current Zone: |cFFFFFF00%s|r", currentZone or "nil"))
        print(string.format("  Instance: |cFFFFFF00%s|r (ID: %s)",
            location and location.instanceName or "Unknown",
            location and location.instanceID or "nil"))
        print(string.format("  Difficulty: |cFFFFFF00%s|r (ID: %s)",
            location and location.difficultyName or "Unknown",
            location and location.difficultyID or "nil"))

        local _, _, classID = UnitClass("player")
        local specIndex = GetSpecialization()
        local specID = specIndex and select(1, GetSpecializationInfo(specIndex))

        local currentInstanceID = location and location.instanceID or 0
        local currentDifficultyID = location and location.difficultyID or 0

        print("  Checking reminders for CURRENT instance/difficulty/class/spec only:")

        local foundMismatch = false
        local checkedCount = 0
        local skippedCount = 0

        if LunaUITweaks_TalentReminders.reminders[currentInstanceID] and
            LunaUITweaks_TalentReminders.reminders[currentInstanceID][currentDifficultyID] then
            local zoneReminders = LunaUITweaks_TalentReminders.reminders[currentInstanceID][currentDifficultyID]

            local priorityList = {}

            if currentZone and currentZone ~= "" and zoneReminders[currentZone] then
                table.insert(priorityList,
                    { zoneKey = currentZone, reminder = zoneReminders[currentZone], priority = 1 })
            end

            if zoneReminders["general"] then
                table.insert(priorityList, { zoneKey = "general", reminder = zoneReminders["general"], priority = 2 })
            end

            table.sort(priorityList, function(a, b) return a.priority < b.priority end)

            for _, entry in ipairs(priorityList) do
                local zoneKey = entry.zoneKey
                local reminder = entry.reminder

                if reminder.classID and reminder.classID ~= classID then
                    skippedCount = skippedCount + 1
                elseif reminder.specID and reminder.specID ~= specID then
                    skippedCount = skippedCount + 1
                else
                    checkedCount = checkedCount + 1

                    print(string.format("    - Reminder: |cFFFFAA00%s|r (Zone: |cFFFFFF00%s|r)",
                        reminder.name or "Unknown", zoneKey))

                    local mismatches = addonTable.TalentReminder.CompareTalents(reminder.talents)
                    if #mismatches > 0 then
                        print(string.format("      |cFF00FF00✓ Found %d talent mismatches - showing alert|r",
                            #mismatches))
                        addonTable.TalentReminder.ShowAlert(reminder, mismatches, zoneKey)
                        foundMismatch = true
                        break
                    else
                        print("      |cFFAAAA00○ Talents match - no alert needed|r")
                    end
                end
            end
        end

        print(string.format("  Checked: %d | Skipped (wrong class/spec/instance/diff): %d", checkedCount,
            skippedCount))

        if not foundMismatch and checkedCount > 0 then
            print("  |cFFFF6B6BNo talent mismatches found in matching reminders.|r")
        elseif checkedCount == 0 then
            print("  |cFFFF6B6BNo reminders found for current instance/difficulty/class/spec.|r")
        end
    end)

    -- Clear All Button
    local clearBtn = CreateFrame("Button", nil, panel, "GameMenuButtonTemplate")
    clearBtn:SetSize(120, 30)
    clearBtn:SetPoint("LEFT", testBtn, "RIGHT", 10, 0)
    clearBtn:SetText("Clear All")
    clearBtn:SetNormalFontObject("GameFontNormal")
    clearBtn:SetHighlightFontObject("GameFontHighlight")
    clearBtn:SetScript("OnClick", function(self)
        local isShiftHeld = IsShiftKeyDown()

        if isShiftHeld then
            -- Shift-click: clear ALL reminders for ALL classes/specs
            StaticPopup_Show("LUNA_TALENT_CLEAR_ALL_CONFIRM")
        else
            -- Normal click: clear only current class/spec
            local _, _, classID = UnitClass("player")
            local specIndex = GetSpecialization()
            local specID, specName
            if specIndex then
                specID, specName = GetSpecializationInfo(specIndex)
            end

            StaticPopup_Show("LUNA_TALENT_CLEAR_CONFIRM", specName or "Unknown Spec", nil, {
                classID = classID,
                specID = specID
            })
        end
    end)

    -- Confirmation dialog for clearing current spec
    StaticPopupDialogs["LUNA_TALENT_CLEAR_CONFIRM"] = {
        text = "Are you sure you want to delete ALL talent reminders for %s?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function(self, data)
            if LunaUITweaks_TalentReminders and LunaUITweaks_TalentReminders.reminders then
                local deleteCount = 0
                for instanceID, reminders in pairs(LunaUITweaks_TalentReminders.reminders) do
                    for diffID, diffReminders in pairs(reminders) do
                        for bossID, reminder in pairs(diffReminders) do
                            local shouldDelete = false
                            if not reminder.classID and not reminder.specID then
                                shouldDelete = false
                            elseif reminder.classID == data.classID and reminder.specID == data.specID then
                                shouldDelete = true
                            end

                            if shouldDelete then
                                diffReminders[bossID] = nil
                                deleteCount = deleteCount + 1
                            end
                        end
                    end
                end

                if addonTable.Config.RefreshTalentReminderList then
                    addonTable.Config.RefreshTalentReminderList()
                end
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    -- Confirmation dialog for clearing ALL reminders (shift-click)
    StaticPopupDialogs["LUNA_TALENT_CLEAR_ALL_CONFIRM"] = {
        text =
        "Are you sure you want to delete ALL talent reminders for ALL classes and specs?\n\n|cFFFF0000This cannot be undone!|r",
        button1 = "Delete All",
        button2 = "Cancel",
        OnAccept = function(self)
            if LunaUITweaks_TalentReminders then
                LunaUITweaks_TalentReminders.reminders = {}

                if addonTable.Config.RefreshTalentReminderList then
                    addonTable.Config.RefreshTalentReminderList()
                end

                print("|cFFFFD100LunaUITweaks:|r All talent reminders deleted.")
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    StaticPopupDialogs["LUNA_TALENT_DELETE_GROUP_CONFIRM"] = {
        text = "Delete talent reminder:\n\n%s",
        button1 = "Delete",
        button2 = "Cancel",
        OnAccept = function(self, data)
            if addonTable.TalentReminder then
                for _, diff in ipairs(data.difficulties) do
                    addonTable.TalentReminder.DeleteReminder(
                        data.instanceID,
                        diff.diffID,
                        data.zoneKey
                    )
                end
                if addonTable.Config.RefreshTalentReminderList then
                    addonTable.Config.RefreshTalentReminderList()
                end
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    -- Set up event listener to update button states
    local instanceCheckFrame = CreateFrame("Frame", nil, panel)
    instanceCheckFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    instanceCheckFrame:SetScript("OnEvent", function(self, event)
        UpdateButtonStates()
    end)

    -- Initial button state update
    UpdateButtonStates()
end
