local addonName, addonTable = ...

addonTable.ConfigSetup = addonTable.ConfigSetup or {}

local Helpers = addonTable.ConfigHelpers

function addonTable.ConfigSetup.TalentManager(panel, tab, configWindow)
    Helpers.CreateResetButton(panel, "talentManager")
    local fonts = Helpers.fonts

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Talent Builds")

    -- Enable Checkbox
    local enableBtn = CreateFrame("CheckButton", "UIThingsTalentMgrEnableCheck", panel,
        "ChatConfigCheckButtonTemplate")
    enableBtn:SetPoint("TOPLEFT", 20, -50)
    _G[enableBtn:GetName() .. "Text"]:SetText("Enable Talent Build Panel")
    enableBtn:SetChecked(UIThingsDB.talentManager.enabled)
    enableBtn:SetScript("OnClick", function(self)
        local enabled = not not self:GetChecked()
        UIThingsDB.talentManager.enabled = enabled
        Helpers.UpdateModuleVisuals(panel, tab, enabled)
        if addonTable.TalentManager and addonTable.TalentManager.UpdateSettings then
            addonTable.TalentManager.UpdateSettings()
        end
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.talentManager.enabled)

    local helpText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    helpText:SetPoint("TOPLEFT", 20, -75)
    helpText:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
    helpText:SetJustifyH("LEFT")
    helpText:SetTextColor(0.6, 0.6, 0.6)
    helpText:SetText("Shows a talent build panel anchored to the right side of the talent screen. "
        .. "Builds are shared with the Talent Reminders module.")

    -- Panel Width Slider
    Helpers.CreateSectionHeader(panel, "Panel Settings", -100)

    local widthSlider = CreateFrame("Slider", "UIThingsTalentMgrWidthSlider", panel, "OptionsSliderTemplate")
    widthSlider:SetPoint("TOPLEFT", 20, -130)
    widthSlider:SetMinMaxValues(200, 400)
    widthSlider:SetValueStep(10)
    widthSlider:SetObeyStepOnDrag(true)
    widthSlider:SetWidth(200)
    _G[widthSlider:GetName() .. "Text"]:SetText(string.format("Panel Width: %d",
        UIThingsDB.talentManager.panelWidth or 280))
    _G[widthSlider:GetName() .. "Low"]:SetText("200")
    _G[widthSlider:GetName() .. "High"]:SetText("400")
    widthSlider:SetValue(UIThingsDB.talentManager.panelWidth or 280)
    widthSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.talentManager.panelWidth = value
        _G[self:GetName() .. "Text"]:SetText(string.format("Panel Width: %d", value))
        if addonTable.TalentManager and addonTable.TalentManager.UpdateSettings then
            addonTable.TalentManager.UpdateSettings()
        end
    end)

    -- Font Dropdown
    Helpers.CreateFontDropdown(
        panel,
        "UIThingsTalentMgrFontDropdown",
        "Font:",
        UIThingsDB.talentManager.font,
        function(fontPath, fontName)
            UIThingsDB.talentManager.font = fontPath
            if addonTable.TalentManager and addonTable.TalentManager.UpdateSettings then
                addonTable.TalentManager.UpdateSettings()
            end
        end,
        20, -175
    )

    -- Font Size Slider
    local fontSizeSlider = CreateFrame("Slider", "UIThingsTalentMgrFontSizeSlider", panel, "OptionsSliderTemplate")
    fontSizeSlider:SetPoint("TOPLEFT", 250, -175)
    fontSizeSlider:SetMinMaxValues(8, 16)
    fontSizeSlider:SetValueStep(1)
    fontSizeSlider:SetObeyStepOnDrag(true)
    fontSizeSlider:SetWidth(150)
    _G[fontSizeSlider:GetName() .. "Text"]:SetText(string.format("Font Size: %d",
        UIThingsDB.talentManager.fontSize or 11))
    _G[fontSizeSlider:GetName() .. "Low"]:SetText("8")
    _G[fontSizeSlider:GetName() .. "High"]:SetText("16")
    fontSizeSlider:SetValue(UIThingsDB.talentManager.fontSize or 11)
    fontSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.talentManager.fontSize = value
        _G[self:GetName() .. "Text"]:SetText(string.format("Font Size: %d", value))
        if addonTable.TalentManager and addonTable.TalentManager.UpdateSettings then
            addonTable.TalentManager.UpdateSettings()
        end
    end)

    -- Border Settings
    Helpers.CreateSectionHeader(panel, "Appearance", -215)

    local borderCheck = CreateFrame("CheckButton", "UIThingsTalentMgrBorderCheck", panel,
        "ChatConfigCheckButtonTemplate")
    borderCheck:SetPoint("TOPLEFT", 20, -245)
    borderCheck:SetHitRectInsets(0, -80, 0, 0)
    _G[borderCheck:GetName() .. "Text"]:SetText("Show Border")
    borderCheck:SetChecked(UIThingsDB.talentManager.showBorder)
    borderCheck:SetScript("OnClick", function(self)
        UIThingsDB.talentManager.showBorder = not not self:GetChecked()
        if addonTable.TalentManager and addonTable.TalentManager.UpdateSettings then
            addonTable.TalentManager.UpdateSettings()
        end
    end)

    Helpers.CreateColorSwatch(panel, "Color:",
        UIThingsDB.talentManager.borderColor,
        function() if addonTable.TalentManager then addonTable.TalentManager.UpdateSettings() end end,
        140, -248)

    -- Background Settings
    local bgCheck = CreateFrame("CheckButton", "UIThingsTalentMgrBgCheck", panel,
        "ChatConfigCheckButtonTemplate")
    bgCheck:SetPoint("TOPLEFT", 20, -270)
    bgCheck:SetHitRectInsets(0, -110, 0, 0)
    _G[bgCheck:GetName() .. "Text"]:SetText("Show Background")
    bgCheck:SetChecked(UIThingsDB.talentManager.showBackground)
    bgCheck:SetScript("OnClick", function(self)
        UIThingsDB.talentManager.showBackground = not not self:GetChecked()
        if addonTable.TalentManager and addonTable.TalentManager.UpdateSettings then
            addonTable.TalentManager.UpdateSettings()
        end
    end)

    Helpers.CreateColorSwatch(panel, "Color:",
        UIThingsDB.talentManager.backgroundColor,
        function() if addonTable.TalentManager then addonTable.TalentManager.UpdateSettings() end end,
        165, -273)
end
