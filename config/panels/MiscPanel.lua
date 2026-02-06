local addonName, addonTable = ...

-- Create setup table if it doesn't exist
addonTable.ConfigSetup = addonTable.ConfigSetup or {}

-- Get helpers
local Helpers = addonTable.ConfigHelpers

-- Define the setup function for Misc panel
function addonTable.ConfigSetup.Misc(panel, tab, configWindow)
    local fonts = Helpers.fonts

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Miscellaneous")

    -- Enable Checkbox
    local enableBtn = CreateFrame("CheckButton", "UIThingsMiscEnable", panel, "ChatConfigCheckButtonTemplate")
    enableBtn:SetPoint("TOPLEFT", 20, -50)
    _G[enableBtn:GetName() .. "Text"]:SetText("Enable Misc Module")
    enableBtn:SetChecked(UIThingsDB.misc.enabled)
    enableBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.enabled = self:GetChecked()
        Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.misc.enabled)
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.misc.enabled)

    -- AH Filter Checkbox
    local ahBtn = CreateFrame("CheckButton", "UIThingsMiscAHFilter", panel, "ChatConfigCheckButtonTemplate")
    ahBtn:SetPoint("TOPLEFT", 20, -100)
    _G[ahBtn:GetName() .. "Text"]:SetText("Auction Current Expansion Only")
    ahBtn:SetChecked(UIThingsDB.misc.ahFilter)
    ahBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.ahFilter = self:GetChecked()
    end)

    -- Personal Orders Header
    local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 20, -150)
    header:SetText("Personal Orders")

    -- Personal Orders Checkbox
    local ordersBtn = CreateFrame("CheckButton", "UIThingsMiscOrdersCheck", panel,
        "ChatConfigCheckButtonTemplate")
    ordersBtn:SetPoint("TOPLEFT", 20, -180)
    _G[ordersBtn:GetName() .. "Text"]:SetText("Enable Personal Order Detection")
    ordersBtn:SetChecked(UIThingsDB.misc.personalOrders)
    ordersBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.personalOrders = self:GetChecked()
    end)

    -- Alert Duration Slider
    local durSlider = CreateFrame("Slider", "UIThingsMiscAlertDur", panel, "OptionsSliderTemplate")
    durSlider:SetPoint("TOPLEFT", 40, -220)
    durSlider:SetMinMaxValues(1, 10)
    durSlider:SetValueStep(1)
    durSlider:SetObeyStepOnDrag(true)
    durSlider:SetWidth(200)
    _G[durSlider:GetName() .. 'Text']:SetText("Alert Duration: " .. UIThingsDB.misc.alertDuration .. "s")
    _G[durSlider:GetName() .. 'Low']:SetText("1s")
    _G[durSlider:GetName() .. 'High']:SetText("10s")
    durSlider:SetValue(UIThingsDB.misc.alertDuration)
    durSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.misc.alertDuration = value
        _G[self:GetName() .. 'Text']:SetText("Alert Duration: " .. value .. "s")
    end)

    -- Alert Color Picker
    local colorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    colorLabel:SetPoint("TOPLEFT", 40, -260)
    colorLabel:SetText("Alert Color:")

    local colorSwatch = CreateFrame("Button", nil, panel)
    colorSwatch:SetSize(20, 20)
    colorSwatch:SetPoint("LEFT", colorLabel, "RIGHT", 10, 0)

    colorSwatch.tex = colorSwatch:CreateTexture(nil, "OVERLAY")
    colorSwatch.tex:SetAllPoints()
    local c = UIThingsDB.misc.alertColor
    colorSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a or 1)

    Mixin(colorSwatch, BackdropTemplateMixin)
    colorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    colorSwatch:SetBackdropBorderColor(1, 1, 1)

    colorSwatch:SetScript("OnClick", function()
        local prevR, prevG, prevB, prevA = c.r, c.g, c.b, c.a

        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = c.r,
                g = c.g,
                b = c.b,
                opacity = c.a,
                hasOpacity = true,
                swatchFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = ColorPickerFrame:GetColorAlpha()
                    c.r, c.g, c.b, c.a = r, g, b, a
                    colorSwatch.tex:SetColorTexture(r, g, b, a)
                    UIThingsDB.misc.alertColor = c
                end,
                opacityFunc = function()
                    local a = ColorPickerFrame:GetColorAlpha()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    c.r, c.g, c.b, c.a = r, g, b, a
                    colorSwatch.tex:SetColorTexture(r, g, b, a)
                    UIThingsDB.misc.alertColor = c
                end,
                cancelFunc = function(restore)
                    c.r, c.g, c.b, c.a = prevR, prevG, prevB, prevA
                    colorSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
                    UIThingsDB.misc.alertColor = c
                end
            })
        else
            -- Fallback for older APIs
            ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
            ColorPickerFrame.hasOpacity = true
            ColorPickerFrame.opacity = c.a
            ColorPickerFrame.func = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetOpacity()
                c.r, c.g, c.b, c.a = r, g, b, a
                colorSwatch.tex:SetColorTexture(r, g, b, a)
                UIThingsDB.misc.alertColor = c
            end
            ColorPickerFrame:Show()
        end
    end)

    -- TTS Section Header
    local ttsHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ttsHeader:SetPoint("TOPLEFT", 20, -310)
    ttsHeader:SetText("Text-To-Speech")

    -- TTS Enable Checkbox
    local ttsEnableBtn = CreateFrame("CheckButton", "UIThingsMiscTTSEnable", panel,
        "ChatConfigCheckButtonTemplate")
    ttsEnableBtn:SetPoint("TOPLEFT", 20, -340)
    _G[ttsEnableBtn:GetName() .. "Text"]:SetText("Enable Text-To-Speech")
    ttsEnableBtn:SetChecked(UIThingsDB.misc.ttsEnabled)
    ttsEnableBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.ttsEnabled = self:GetChecked()
    end)

    -- TTS Message
    local ttsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ttsLabel:SetPoint("TOPLEFT", 40, -380)
    ttsLabel:SetText("TTS Message:")

    local ttsEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    ttsEdit:SetSize(250, 20)
    ttsEdit:SetPoint("LEFT", ttsLabel, "RIGHT", 10, 0)
    ttsEdit:SetAutoFocus(false)
    ttsEdit:SetText(UIThingsDB.misc.ttsMessage)
    ttsEdit:SetScript("OnEnterPressed", function(self)
        UIThingsDB.misc.ttsMessage = self:GetText()
        self:ClearFocus()
    end)

    -- Test Button (shows full alert)
    local testTTSBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testTTSBtn:SetSize(60, 22)
    testTTSBtn:SetPoint("LEFT", ttsEdit, "RIGHT", 5, 0)
    testTTSBtn:SetText("Test")
    testTTSBtn:SetScript("OnClick", function()
        -- Save current text first
        UIThingsDB.misc.ttsMessage = ttsEdit:GetText()
        -- Show full alert (banner + TTS)
        if addonTable.Misc and addonTable.Misc.ShowAlert then
            addonTable.Misc.ShowAlert()
        end
    end)

    -- TTS Voice Dropdown
    local voiceLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    voiceLabel:SetPoint("TOPLEFT", 40, -420)
    voiceLabel:SetText("Voice Type:")

    local voiceDropdown = CreateFrame("Frame", "UIThingsMiscVoiceDropdown", panel, "UIDropDownMenuTemplate")
    voiceDropdown:SetPoint("LEFT", voiceLabel, "RIGHT", -15, -3)

    local voiceOptions = {
        { text = "Standard",    value = 0 },
        { text = "Alternate 1", value = 1 }
    }

    UIDropDownMenu_SetWidth(voiceDropdown, 120)
    UIDropDownMenu_Initialize(voiceDropdown, function(self, level)
        for _, option in ipairs(voiceOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function(btn)
                UIThingsDB.misc.ttsVoice = btn.value
                UIDropDownMenu_SetSelectedValue(voiceDropdown, btn.value)
            end
            info.checked = (UIThingsDB.misc.ttsVoice == option.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetSelectedValue(voiceDropdown, UIThingsDB.misc.ttsVoice or 0)
end
