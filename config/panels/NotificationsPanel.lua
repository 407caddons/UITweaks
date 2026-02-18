local addonName, addonTable = ...

addonTable.ConfigSetup = addonTable.ConfigSetup or {}

local Helpers = addonTable.ConfigHelpers

function addonTable.ConfigSetup.Notifications(panel, navButton, configWindow)
    local function UpdateNavColor()
        local anyEnabled = UIThingsDB.misc.personalOrders or UIThingsDB.misc.mailNotification
        Helpers.UpdateModuleVisuals(panel, navButton, anyEnabled)
    end
    UpdateNavColor()

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Notifications")

    -- Create scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "UIThingsNotificationsScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(panel:GetWidth() - 30, 650)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:SetScript("OnShow", function()
        scrollChild:SetWidth(scrollFrame:GetWidth())
    end)

    panel = scrollChild

    local noteLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noteLabel:SetPoint("TOPLEFT", 20, -5)
    noteLabel:SetWidth(560)
    noteLabel:SetJustifyH("LEFT")
    noteLabel:SetTextColor(0.5, 0.5, 0.5)
    noteLabel:SetText("Notifications require the General UI module to be enabled.")

    -- == Personal Orders Section ==
    Helpers.CreateSectionHeader(panel, "Personal Orders", -25)

    local ordersBtn = CreateFrame("CheckButton", "UIThingsNotifOrdersCheck", panel,
        "ChatConfigCheckButtonTemplate")
    ordersBtn:SetPoint("TOPLEFT", 20, -55)
    _G[ordersBtn:GetName() .. "Text"]:SetText("Enable Personal Order Detection")
    ordersBtn:SetChecked(UIThingsDB.misc.personalOrders)
    ordersBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.personalOrders = self:GetChecked()
        UpdateNavColor()
    end)

    local logonCheckBtn = CreateFrame("CheckButton", "UIThingsNotifOrdersLogonCheck", panel,
        "ChatConfigCheckButtonTemplate")
    logonCheckBtn:SetPoint("TOPLEFT", 280, -55)
    _G[logonCheckBtn:GetName() .. "Text"]:SetText("Check at Logon")
    logonCheckBtn:SetChecked(UIThingsDB.misc.personalOrdersCheckAtLogon)
    logonCheckBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.personalOrdersCheckAtLogon = self:GetChecked()
    end)

    -- Alert Duration Slider
    local durSlider = CreateFrame("Slider", "UIThingsNotifAlertDur", panel, "OptionsSliderTemplate")
    durSlider:SetPoint("TOPLEFT", 40, -95)
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
    colorLabel:SetPoint("TOPLEFT", 40, -135)
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
                cancelFunc = function()
                    c.r, c.g, c.b, c.a = prevR, prevG, prevB, prevA
                    colorSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
                    UIThingsDB.misc.alertColor = c
                end
            })
        end
    end)

    -- TTS Enable Checkbox
    local ttsEnableBtn = CreateFrame("CheckButton", "UIThingsNotifTTSEnable", panel,
        "ChatConfigCheckButtonTemplate")
    ttsEnableBtn:SetPoint("TOPLEFT", 20, -175)
    _G[ttsEnableBtn:GetName() .. "Text"]:SetText("Enable Text-To-Speech")
    ttsEnableBtn:SetChecked(UIThingsDB.misc.ttsEnabled)
    ttsEnableBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.ttsEnabled = self:GetChecked()
    end)

    -- TTS Message
    local ttsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ttsLabel:SetPoint("TOPLEFT", 40, -215)
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

    -- Test Button
    local testTTSBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testTTSBtn:SetSize(60, 22)
    testTTSBtn:SetPoint("LEFT", ttsEdit, "RIGHT", 5, 0)
    testTTSBtn:SetText("Test")
    testTTSBtn:SetScript("OnClick", function()
        UIThingsDB.misc.ttsMessage = ttsEdit:GetText()
        if addonTable.Misc and addonTable.Misc.ShowAlert then
            addonTable.Misc.ShowAlert()
        end
    end)

    -- TTS Voice Dropdown
    local voiceLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    voiceLabel:SetPoint("TOPLEFT", 40, -255)
    voiceLabel:SetText("Voice Type:")

    local voiceDropdown = CreateFrame("Frame", "UIThingsNotifVoiceDropdown", panel, "UIDropDownMenuTemplate")
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

    -- == Mail Notification Section ==
    Helpers.CreateSectionHeader(panel, "Mail Notification", -300)

    local mailBtn = CreateFrame("CheckButton", "UIThingsNotifMailCheck", panel,
        "ChatConfigCheckButtonTemplate")
    mailBtn:SetPoint("TOPLEFT", 20, -330)
    _G[mailBtn:GetName() .. "Text"]:SetText("Enable Mail Notification")
    mailBtn:SetChecked(UIThingsDB.misc.mailNotification)
    mailBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.mailNotification = self:GetChecked()
        if addonTable.Misc and addonTable.Misc.ApplyEvents then
            addonTable.Misc.ApplyEvents()
        end
        UpdateNavColor()
    end)

    -- Mail Alert Duration Slider
    local mailDurSlider = CreateFrame("Slider", "UIThingsNotifMailAlertDur", panel, "OptionsSliderTemplate")
    mailDurSlider:SetPoint("TOPLEFT", 40, -370)
    mailDurSlider:SetMinMaxValues(1, 10)
    mailDurSlider:SetValueStep(1)
    mailDurSlider:SetObeyStepOnDrag(true)
    mailDurSlider:SetWidth(200)
    _G[mailDurSlider:GetName() .. 'Text']:SetText("Alert Duration: " .. UIThingsDB.misc.mailAlertDuration .. "s")
    _G[mailDurSlider:GetName() .. 'Low']:SetText("1s")
    _G[mailDurSlider:GetName() .. 'High']:SetText("10s")
    mailDurSlider:SetValue(UIThingsDB.misc.mailAlertDuration)
    mailDurSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.misc.mailAlertDuration = value
        _G[self:GetName() .. 'Text']:SetText("Alert Duration: " .. value .. "s")
    end)

    -- Mail Alert Color Picker
    local mailColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mailColorLabel:SetPoint("TOPLEFT", 40, -410)
    mailColorLabel:SetText("Alert Color:")

    local mailColorSwatch = CreateFrame("Button", nil, panel)
    mailColorSwatch:SetSize(20, 20)
    mailColorSwatch:SetPoint("LEFT", mailColorLabel, "RIGHT", 10, 0)

    mailColorSwatch.tex = mailColorSwatch:CreateTexture(nil, "OVERLAY")
    mailColorSwatch.tex:SetAllPoints()
    local mc = UIThingsDB.misc.mailAlertColor
    mailColorSwatch.tex:SetColorTexture(mc.r, mc.g, mc.b, mc.a or 1)

    Mixin(mailColorSwatch, BackdropTemplateMixin)
    mailColorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    mailColorSwatch:SetBackdropBorderColor(1, 1, 1)

    mailColorSwatch:SetScript("OnClick", function()
        local prevR, prevG, prevB, prevA = mc.r, mc.g, mc.b, mc.a
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = mc.r,
                g = mc.g,
                b = mc.b,
                opacity = mc.a,
                hasOpacity = true,
                swatchFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = ColorPickerFrame:GetColorAlpha()
                    mc.r, mc.g, mc.b, mc.a = r, g, b, a
                    mailColorSwatch.tex:SetColorTexture(r, g, b, a)
                    UIThingsDB.misc.mailAlertColor = mc
                end,
                cancelFunc = function()
                    mc.r, mc.g, mc.b, mc.a = prevR, prevG, prevB, prevA
                    mailColorSwatch.tex:SetColorTexture(mc.r, mc.g, mc.b, mc.a)
                    UIThingsDB.misc.mailAlertColor = mc
                end
            })
        end
    end)

    -- Mail TTS Enable Checkbox
    local mailTtsEnableBtn = CreateFrame("CheckButton", "UIThingsNotifMailTTSEnable", panel,
        "ChatConfigCheckButtonTemplate")
    mailTtsEnableBtn:SetPoint("TOPLEFT", 20, -450)
    _G[mailTtsEnableBtn:GetName() .. "Text"]:SetText("Enable Text-To-Speech")
    mailTtsEnableBtn:SetChecked(UIThingsDB.misc.mailTtsEnabled)
    mailTtsEnableBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.mailTtsEnabled = self:GetChecked()
    end)

    -- Mail TTS Message
    local mailTtsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mailTtsLabel:SetPoint("TOPLEFT", 40, -490)
    mailTtsLabel:SetText("TTS Message:")

    local mailTtsEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    mailTtsEdit:SetSize(250, 20)
    mailTtsEdit:SetPoint("LEFT", mailTtsLabel, "RIGHT", 10, 0)
    mailTtsEdit:SetAutoFocus(false)
    mailTtsEdit:SetText(UIThingsDB.misc.mailTtsMessage)
    mailTtsEdit:SetScript("OnEnterPressed", function(self)
        UIThingsDB.misc.mailTtsMessage = self:GetText()
        self:ClearFocus()
    end)

    -- Mail Test Button
    local testMailBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testMailBtn:SetSize(60, 22)
    testMailBtn:SetPoint("LEFT", mailTtsEdit, "RIGHT", 5, 0)
    testMailBtn:SetText("Test")
    testMailBtn:SetScript("OnClick", function()
        UIThingsDB.misc.mailTtsMessage = mailTtsEdit:GetText()
        if addonTable.Misc and addonTable.Misc.ShowMailAlert then
            addonTable.Misc.ShowMailAlert()
        end
    end)

    -- Mail TTS Voice Dropdown
    local mailVoiceLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mailVoiceLabel:SetPoint("TOPLEFT", 40, -530)
    mailVoiceLabel:SetText("Voice Type:")

    local mailVoiceDropdown = CreateFrame("Frame", "UIThingsNotifMailVoiceDropdown", panel, "UIDropDownMenuTemplate")
    mailVoiceDropdown:SetPoint("LEFT", mailVoiceLabel, "RIGHT", -15, -3)

    local mailVoiceOptions = {
        { text = "Standard",    value = 0 },
        { text = "Alternate 1", value = 1 }
    }

    UIDropDownMenu_SetWidth(mailVoiceDropdown, 120)
    UIDropDownMenu_Initialize(mailVoiceDropdown, function(self, level)
        for _, option in ipairs(mailVoiceOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function(btn)
                UIThingsDB.misc.mailTtsVoice = btn.value
                UIDropDownMenu_SetSelectedValue(mailVoiceDropdown, btn.value)
            end
            info.checked = (UIThingsDB.misc.mailTtsVoice == option.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetSelectedValue(mailVoiceDropdown, UIThingsDB.misc.mailTtsVoice or 0)
end
