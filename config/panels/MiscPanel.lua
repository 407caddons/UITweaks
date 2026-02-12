local addonName, addonTable = ...

-- Create setup table if it doesn't exist
addonTable.ConfigSetup = addonTable.ConfigSetup or {}

-- Get helpers
local Helpers = addonTable.ConfigHelpers

-- Define the setup function for Misc panel
function addonTable.ConfigSetup.Misc(panel, tab, configWindow)
    local fonts = Helpers.fonts

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Miscellaneous")

    -- Create scroll frame for the settings
    local scrollFrame = CreateFrame("ScrollFrame", "UIThingsMiscScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(panel:GetWidth()-30, 680) -- Matches content height
    scrollFrame:SetScrollChild(scrollChild)



    -- Auto-adjust width
    scrollFrame:SetScript("OnShow", function()
        scrollChild:SetWidth(scrollFrame:GetWidth())
    end)

    -- Update panel reference to scrollChild for all child elements
    panel = scrollChild



    -- Enable Checkbox
    local enableBtn = CreateFrame("CheckButton", "UIThingsMiscEnable", panel, "ChatConfigCheckButtonTemplate")
    enableBtn:SetPoint("TOPLEFT", 20, -10)
    _G[enableBtn:GetName() .. "Text"]:SetText("Enable Misc Module")
    enableBtn:SetChecked(UIThingsDB.misc.enabled)
    enableBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.enabled = self:GetChecked()
        Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.misc.enabled)
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.misc.enabled)

    -- AH Filter Checkbox
    local ahBtn = CreateFrame("CheckButton", "UIThingsMiscAHFilter", panel, "ChatConfigCheckButtonTemplate")
    ahBtn:SetPoint("TOPLEFT", 20, -40)
    _G[ahBtn:GetName() .. "Text"]:SetText("Auction Current Expansion Only")
    ahBtn:SetChecked(UIThingsDB.misc.ahFilter)
    ahBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.ahFilter = self:GetChecked()
    end)

    -- Personal Orders Header
    Helpers.CreateSectionHeader(panel, "Personal Orders", -80)

    -- Personal Orders Checkbox
    local ordersBtn = CreateFrame("CheckButton", "UIThingsMiscOrdersCheck", panel,
        "ChatConfigCheckButtonTemplate")
    ordersBtn:SetPoint("TOPLEFT", 20, -110)
    _G[ordersBtn:GetName() .. "Text"]:SetText("Enable Personal Order Detection")
    ordersBtn:SetChecked(UIThingsDB.misc.personalOrders)
    ordersBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.personalOrders = self:GetChecked()
    end)

    -- Alert Duration Slider
    local durSlider = CreateFrame("Slider", "UIThingsMiscAlertDur", panel, "OptionsSliderTemplate")
    durSlider:SetPoint("TOPLEFT", 40, -150)
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
    colorLabel:SetPoint("TOPLEFT", 40, -190)
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

    -- TTS Enable Checkbox
    local ttsEnableBtn = CreateFrame("CheckButton", "UIThingsMiscTTSEnable", panel,
        "ChatConfigCheckButtonTemplate")
    ttsEnableBtn:SetPoint("TOPLEFT", 20, -230)
    _G[ttsEnableBtn:GetName() .. "Text"]:SetText("Enable Text-To-Speech")
    ttsEnableBtn:SetChecked(UIThingsDB.misc.ttsEnabled)
    ttsEnableBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.ttsEnabled = self:GetChecked()
    end)

    -- TTS Message
    local ttsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ttsLabel:SetPoint("TOPLEFT", 40, -270)
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
    voiceLabel:SetPoint("TOPLEFT", 40, -310)
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

    -- General UI Section Header
    Helpers.CreateSectionHeader(panel, "General UI", -360)

    -- UI Scale Enable Checkbox
    local uiScaleBtn = CreateFrame("CheckButton", "UIThingsMiscUIScaleEnable", panel,
        "ChatConfigCheckButtonTemplate")
    uiScaleBtn:SetPoint("TOPLEFT", 20, -390)
    _G[uiScaleBtn:GetName() .. "Text"]:SetText("Enable UI Scaling")
    uiScaleBtn:SetChecked(UIThingsDB.misc.uiScaleEnabled)
    uiScaleBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.uiScaleEnabled = self:GetChecked()
        if UIThingsDB.misc.uiScaleEnabled and addonTable.Misc and addonTable.Misc.ApplyUIScale then
            addonTable.Misc.ApplyUIScale()
        end
    end)

    -- UI Scale Slider
    local scaleSlider = CreateFrame("Slider", "UIThingsMiscUIScaleSlider", panel, "OptionsSliderTemplate")
    local scaleEdit = CreateFrame("EditBox", "UIThingsMiscUIScaleEdit", panel, "InputBoxTemplate")
    
    scaleSlider:SetPoint("TOPLEFT", 40, -430)
    scaleSlider:SetMinMaxValues(0.4, 1.25)
    scaleSlider:SetValueStep(0.001)
    scaleSlider:SetObeyStepOnDrag(true)
    scaleSlider:SetWidth(200)
    _G[scaleSlider:GetName() .. 'Text']:SetText("UI Scale: " .. string.format("%.3f", UIThingsDB.misc.uiScale))
    _G[scaleSlider:GetName() .. 'Low']:SetText("0.4")
    _G[scaleSlider:GetName() .. 'High']:SetText("1.25")
    scaleSlider:SetValue(UIThingsDB.misc.uiScale)
    
    -- UI Scale EditBox
    scaleEdit:SetSize(60, 20)
    scaleEdit:SetPoint("LEFT", scaleSlider, "RIGHT", 15, 0)
    scaleEdit:SetAutoFocus(false)
    scaleEdit:SetText(string.format("%.3f", UIThingsDB.misc.uiScale))
    
    local function UpdateScaleUI(value, skipSlider)
        value = tonumber(string.format("%.3f", value))
        UIThingsDB.misc.uiScale = value
        _G[scaleSlider:GetName() .. 'Text']:SetText("UI Scale: " .. string.format("%.3f", value))
        scaleEdit:SetText(string.format("%.3f", value))
        if not skipSlider then
            scaleSlider:SetValue(value)
        end
        if UIThingsDB.misc.uiScaleEnabled and addonTable.Misc and addonTable.Misc.ApplyUIScale then
            addonTable.Misc.ApplyUIScale()
        end
    end

    scaleSlider:SetScript("OnValueChanged", function(self, value)
        -- Only update if the value actually changed (to prevent potential loops)
        local rounded = tonumber(string.format("%.3f", value))
        if UIThingsDB.misc.uiScale ~= rounded then
            UpdateScaleUI(value, true)
        end
    end)

    scaleEdit:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            val = math.min(1.25, math.max(0.4, val))
            UpdateScaleUI(val)
        else
            self:SetText(string.format("%.3f", UIThingsDB.misc.uiScale))
        end
        self:ClearFocus()
    end)

    -- Resolution Presets
    local btn1440 = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn1440:SetSize(60, 22)
    btn1440:SetPoint("LEFT", scaleEdit, "RIGHT", 10, 0)
    btn1440:SetText("1440p")
    btn1440:SetScript("OnClick", function()
        UpdateScaleUI(0.533)
    end)

    local btn1080 = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn1080:SetSize(60, 22)
    btn1080:SetPoint("LEFT", btn1440, "RIGHT", 5, 0)
    btn1080:SetText("1080p")
    btn1080:SetScript("OnClick", function()
        UpdateScaleUI(0.711)
    end)

    -- Invite Automation
    local inviteHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    inviteHeader:SetPoint("TOPLEFT", 20, -480)
    inviteHeader:SetText("Invite Automation:")

    local friendsBtn = CreateFrame("CheckButton", "UIThingsMiscAutoFriends", panel, "ChatConfigCheckButtonTemplate")
    friendsBtn:SetPoint("TOPLEFT", 20, -505)
    _G[friendsBtn:GetName() .. "Text"]:SetText("Auto-Accept: Friends")
    friendsBtn:SetChecked(UIThingsDB.misc.autoAcceptFriends)
    friendsBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.autoAcceptFriends = self:GetChecked()
    end)

    local guildBtn = CreateFrame("CheckButton", "UIThingsMiscAutoGuild", panel, "ChatConfigCheckButtonTemplate")
    guildBtn:SetPoint("TOPLEFT", 180, -505)
    _G[guildBtn:GetName() .. "Text"]:SetText("Auto-Accept: Guild")
    guildBtn:SetChecked(UIThingsDB.misc.autoAcceptGuild)
    guildBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.autoAcceptGuild = self:GetChecked()
    end)

    local everyoneBtn = CreateFrame("CheckButton", "UIThingsMiscAutoEveryone", panel, "ChatConfigCheckButtonTemplate")
    everyoneBtn:SetPoint("TOPLEFT", 340, -505)
    _G[everyoneBtn:GetName() .. "Text"]:SetText("Auto-Accept: Everyone")
    everyoneBtn:SetChecked(UIThingsDB.misc.autoAcceptEveryone)
    everyoneBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.autoAcceptEveryone = self:GetChecked()
    end)

    -- Invite by Whisper
    local whisperBtn = CreateFrame("CheckButton", "UIThingsMiscAutoInvite", panel, "ChatConfigCheckButtonTemplate")
    whisperBtn:SetPoint("TOPLEFT", 20, -540)
    _G[whisperBtn:GetName() .. "Text"]:SetText("Enable Invite by Whisper")
    whisperBtn:SetChecked(UIThingsDB.misc.autoInviteEnabled)
    whisperBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.autoInviteEnabled = self:GetChecked()
        if addonTable.Misc and addonTable.Misc.UpdateAutoInviteKeywords then addonTable.Misc.UpdateAutoInviteKeywords() end
    end)

    local kwLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    kwLabel:SetPoint("TOPLEFT", 40, -570)
    kwLabel:SetText("Keywords (comma separated):")

    local kwEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    kwEdit:SetSize(200, 20)
    kwEdit:SetPoint("TOPLEFT", 40, -585)
    kwEdit:SetText(UIThingsDB.misc.autoInviteKeywords or "inv,invite")
    kwEdit:SetAutoFocus(false)
    kwEdit:SetScript("OnEnterPressed", function(self)
        UIThingsDB.misc.autoInviteKeywords = self:GetText()
        if addonTable.Misc and addonTable.Misc.UpdateAutoInviteKeywords then addonTable.Misc.UpdateAutoInviteKeywords() end
        self:ClearFocus()
    end)
    kwEdit:SetScript("OnEditFocusLost", function(self)
        UIThingsDB.misc.autoInviteKeywords = self:GetText()
        if addonTable.Misc and addonTable.Misc.UpdateAutoInviteKeywords then addonTable.Misc.UpdateAutoInviteKeywords() end
    end)

    -- Reload UI Checkbox
    local rlBtn = CreateFrame("CheckButton", "UIThingsMiscAllowRL", panel, "ChatConfigCheckButtonTemplate")
    rlBtn:SetPoint("TOPLEFT", 20, -620)
    _G[rlBtn:GetName() .. "Text"]:SetText("Allow /rl to Reload UI")
    rlBtn:SetChecked(UIThingsDB.misc.allowRL)
    rlBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.allowRL = self:GetChecked()
    end)
    
    -- Quick Item Destroy Checkbox
    local qdBtn = CreateFrame("CheckButton", "UIThingsMiscQuickDestroy", panel, "ChatConfigCheckButtonTemplate")
    qdBtn:SetPoint("TOPLEFT", 20, -650)
    _G[qdBtn:GetName() .. "Text"]:SetText("Quick Item Destroy (Red Button)")
    qdBtn:SetChecked(UIThingsDB.misc.quickDestroy)
    qdBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.quickDestroy = self:GetChecked()
        if addonTable.Misc and addonTable.Misc.ToggleQuickDestroy then
            addonTable.Misc.ToggleQuickDestroy(UIThingsDB.misc.quickDestroy)
        end
    end)




end