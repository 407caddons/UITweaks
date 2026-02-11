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
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(560, 1180) -- Matches content height with minimap icons + clock format
    scrollFrame:SetScrollChild(scrollChild)

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

    -- == Minimap Customization ==
    Helpers.CreateSectionHeader(panel, "Minimap", -660)

    local minimapBtn = CreateFrame("CheckButton", "UIThingsMiscMinimapEnabled", panel, "ChatConfigCheckButtonTemplate")
    minimapBtn:SetPoint("TOPLEFT", 20, -690)
    _G[minimapBtn:GetName() .. "Text"]:SetText("Enable Minimap Customization (requires reload)")
    minimapBtn:SetChecked(UIThingsDB.misc.minimapEnabled)
    minimapBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.minimapEnabled = self:GetChecked()
    end)

    -- Shape Dropdown
    local shapeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    shapeLabel:SetPoint("TOPLEFT", 40, -725)
    shapeLabel:SetText("Shape:")

    local shapeDropdown = CreateFrame("Frame", "UIThingsMiscMinimapShape", panel, "UIDropDownMenuTemplate")
    shapeDropdown:SetPoint("LEFT", shapeLabel, "RIGHT", -5, -3)
    UIDropDownMenu_SetWidth(shapeDropdown, 100)
    UIDropDownMenu_SetText(shapeDropdown, UIThingsDB.misc.minimapShape == "SQUARE" and "Square" or "Round")

    UIDropDownMenu_Initialize(shapeDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()

        info.text = "Round"
        info.checked = UIThingsDB.misc.minimapShape == "ROUND"
        info.func = function()
            UIThingsDB.misc.minimapShape = "ROUND"
            UIDropDownMenu_SetText(shapeDropdown, "Round")
            if UIThingsDB.misc.minimapEnabled and addonTable.Misc and addonTable.Misc.ApplyMinimapShape then
                addonTable.Misc.ApplyMinimapShape("ROUND")
            end
        end
        UIDropDownMenu_AddButton(info)

        info.text = "Square"
        info.checked = UIThingsDB.misc.minimapShape == "SQUARE"
        info.func = function()
            UIThingsDB.misc.minimapShape = "SQUARE"
            UIDropDownMenu_SetText(shapeDropdown, "Square")
            if UIThingsDB.misc.minimapEnabled and addonTable.Misc and addonTable.Misc.ApplyMinimapShape then
                addonTable.Misc.ApplyMinimapShape("SQUARE")
            end
        end
        UIDropDownMenu_AddButton(info)
    end)

    -- Lock Checkbox (left column)
    local lockBtn = CreateFrame("CheckButton", "UIThingsMiscMinimapLocked", panel, "ChatConfigCheckButtonTemplate")
    lockBtn:SetPoint("TOPLEFT", 20, -760)
    _G[lockBtn:GetName() .. "Text"]:SetText("Lock Minimap Position")
    lockBtn:SetChecked(true) -- Always defaults to locked
    lockBtn:SetScript("OnClick", function(self)
        if addonTable.Misc and addonTable.Misc.SetMinimapLocked then
            addonTable.Misc.SetMinimapLocked(self:GetChecked())
        end
    end)

    -- Border Color (right column)
    local borderColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    borderColorLabel:SetPoint("TOPLEFT", 300, -725)
    borderColorLabel:SetText("Border Color:")

    local borderSwatch = CreateFrame("Button", nil, panel)
    borderSwatch:SetSize(20, 20)
    borderSwatch:SetPoint("LEFT", borderColorLabel, "RIGHT", 10, 0)

    borderSwatch.tex = borderSwatch:CreateTexture(nil, "OVERLAY")
    borderSwatch.tex:SetAllPoints()
    local bCol = UIThingsDB.misc.minimapBorderColor
    borderSwatch.tex:SetColorTexture(bCol.r, bCol.g, bCol.b, bCol.a or 1)

    Mixin(borderSwatch, BackdropTemplateMixin)
    borderSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    borderSwatch:SetBackdropBorderColor(1, 1, 1)

    borderSwatch:SetScript("OnClick", function()
        local c = UIThingsDB.misc.minimapBorderColor
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = c.r, g = c.g, b = c.b, opacity = c.a,
                hasOpacity = true,
                swatchFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = ColorPickerFrame:GetColorAlpha()
                    c.r, c.g, c.b, c.a = r, g, b, a
                    borderSwatch.tex:SetColorTexture(r, g, b, a)
                    UIThingsDB.misc.minimapBorderColor = c
                    if addonTable.Misc and addonTable.Misc.UpdateMinimapBorder then addonTable.Misc.UpdateMinimapBorder() end
                end,
                cancelFunc = function()
                    borderSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
                    UIThingsDB.misc.minimapBorderColor = c
                    if addonTable.Misc and addonTable.Misc.UpdateMinimapBorder then addonTable.Misc.UpdateMinimapBorder() end
                end,
            })
        end
    end)

    -- Border Thickness Slider (right column)
    local borderSlider = CreateFrame("Slider", "UIThingsMiscMinimapBorderSize", panel, "OptionsSliderTemplate")
    borderSlider:SetPoint("TOPLEFT", 320, -760)
    borderSlider:SetWidth(200)
    borderSlider:SetMinMaxValues(0, 10)
    borderSlider:SetValueStep(1)
    borderSlider:SetObeyStepOnDrag(true)
    borderSlider:SetValue(UIThingsDB.misc.minimapBorderSize or 3)
    _G[borderSlider:GetName() .. "Low"]:SetText("0")
    _G[borderSlider:GetName() .. "High"]:SetText("10")
    _G[borderSlider:GetName() .. "Text"]:SetText("Border Thickness: " .. (UIThingsDB.misc.minimapBorderSize or 3))
    borderSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        UIThingsDB.misc.minimapBorderSize = value
        _G[self:GetName() .. "Text"]:SetText("Border Thickness: " .. value)
        if addonTable.Misc and addonTable.Misc.UpdateMinimapBorder then addonTable.Misc.UpdateMinimapBorder() end
    end)

    -- == Minimap Icons ==
    Helpers.CreateSectionHeader(panel, "Minimap Icons", -800)

    -- Row 1: Mail + Tracking
    local showMailBtn = CreateFrame("CheckButton", "UIThingsMiscShowMail", panel, "ChatConfigCheckButtonTemplate")
    showMailBtn:SetPoint("TOPLEFT", 20, -830)
    _G[showMailBtn:GetName() .. "Text"]:SetText("Show Mail Icon")
    showMailBtn:SetChecked(UIThingsDB.misc.minimapShowMail)
    showMailBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.minimapShowMail = self:GetChecked()
        if addonTable.Misc and addonTable.Misc.UpdateMinimapIcons then addonTable.Misc.UpdateMinimapIcons() end
    end)

    local showTrackingBtn = CreateFrame("CheckButton", "UIThingsMiscShowTracking", panel, "ChatConfigCheckButtonTemplate")
    showTrackingBtn:SetPoint("TOPLEFT", 300, -830)
    _G[showTrackingBtn:GetName() .. "Text"]:SetText("Show Tracking Icon")
    showTrackingBtn:SetChecked(UIThingsDB.misc.minimapShowTracking)
    showTrackingBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.minimapShowTracking = self:GetChecked()
        if addonTable.Misc and addonTable.Misc.UpdateMinimapIcons then addonTable.Misc.UpdateMinimapIcons() end
    end)

    -- Row 2: App Drawer + Work Orders
    local showDrawerBtn = CreateFrame("CheckButton", "UIThingsMiscShowAddonCompartment", panel, "ChatConfigCheckButtonTemplate")
    showDrawerBtn:SetPoint("TOPLEFT", 20, -855)
    _G[showDrawerBtn:GetName() .. "Text"]:SetText("Show App Drawer")
    showDrawerBtn:SetChecked(UIThingsDB.misc.minimapShowAddonCompartment)
    showDrawerBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.minimapShowAddonCompartment = self:GetChecked()
        if addonTable.Misc and addonTable.Misc.UpdateMinimapIcons then addonTable.Misc.UpdateMinimapIcons() end
    end)

    local showWorkOrderBtn = CreateFrame("CheckButton", "UIThingsMiscShowCraftingOrder", panel, "ChatConfigCheckButtonTemplate")
    showWorkOrderBtn:SetPoint("TOPLEFT", 300, -855)
    _G[showWorkOrderBtn:GetName() .. "Text"]:SetText("Show Work Order Icon")
    showWorkOrderBtn:SetChecked(UIThingsDB.misc.minimapShowCraftingOrder)
    showWorkOrderBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.minimapShowCraftingOrder = self:GetChecked()
        if addonTable.Misc and addonTable.Misc.UpdateMinimapIcons then addonTable.Misc.UpdateMinimapIcons() end
    end)

    -- == Zone Text & Clock Settings (side by side) ==
    Helpers.CreateSectionHeader(panel, "Zone Text & Clock", -890)


    -- ===== LEFT COLUMN: Zone Text =====
    local showZoneBtn = CreateFrame("CheckButton", "UIThingsMiscShowZone", panel, "ChatConfigCheckButtonTemplate")
    showZoneBtn:SetPoint("TOPLEFT", 20, -920)
    _G[showZoneBtn:GetName() .. "Text"]:SetText("Show Zone Name")
    showZoneBtn:SetChecked(UIThingsDB.misc.minimapShowZone)
    showZoneBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.minimapShowZone = self:GetChecked()
        if addonTable.Misc and addonTable.Misc.UpdateZoneText then addonTable.Misc.UpdateZoneText() end
    end)

    Helpers.CreateFontDropdown(panel, "UIThingsMiscZoneFont", "Zone Font:", UIThingsDB.misc.minimapZoneFont, function(fontPath)
        UIThingsDB.misc.minimapZoneFont = fontPath
        if addonTable.Misc and addonTable.Misc.UpdateZoneText then addonTable.Misc.UpdateZoneText() end
    end, 40, -950)

    local zoneSizeSlider = CreateFrame("Slider", "UIThingsMiscZoneFontSize", panel, "OptionsSliderTemplate")
    zoneSizeSlider:SetPoint("TOPLEFT", 40, -1020)
    zoneSizeSlider:SetWidth(200)
    zoneSizeSlider:SetMinMaxValues(8, 24)
    zoneSizeSlider:SetValueStep(1)
    zoneSizeSlider:SetObeyStepOnDrag(true)
    zoneSizeSlider:SetValue(UIThingsDB.misc.minimapZoneFontSize or 12)
    _G[zoneSizeSlider:GetName() .. "Low"]:SetText("8")
    _G[zoneSizeSlider:GetName() .. "High"]:SetText("24")
    _G[zoneSizeSlider:GetName() .. "Text"]:SetText("Zone Font Size: " .. (UIThingsDB.misc.minimapZoneFontSize or 12))
    zoneSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        UIThingsDB.misc.minimapZoneFontSize = value
        _G[self:GetName() .. "Text"]:SetText("Zone Font Size: " .. value)
        if addonTable.Misc and addonTable.Misc.UpdateZoneText then addonTable.Misc.UpdateZoneText() end
    end)

    -- Zone Font Color
    local zoneColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneColorLabel:SetPoint("TOPLEFT", 40, -1048)
    zoneColorLabel:SetText("Font Color:")

    local zoneColorSwatch = CreateFrame("Button", nil, panel)
    zoneColorSwatch:SetPoint("LEFT", zoneColorLabel, "RIGHT", 8, 0)
    zoneColorSwatch:SetSize(20, 20)
    local zcCur = UIThingsDB.misc.minimapZoneFontColor or { r = 1, g = 1, b = 1 }
    zoneColorSwatch.tex = zoneColorSwatch:CreateTexture(nil, "BACKGROUND")
    zoneColorSwatch.tex:SetAllPoints()
    zoneColorSwatch.tex:SetColorTexture(zcCur.r, zcCur.g, zcCur.b)
    zoneColorSwatch:SetScript("OnClick", function()
        local c = UIThingsDB.misc.minimapZoneFontColor or { r = 1, g = 1, b = 1 }
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r, g = c.g, b = c.b,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                c.r, c.g, c.b = r, g, b
                zoneColorSwatch.tex:SetColorTexture(r, g, b)
                UIThingsDB.misc.minimapZoneFontColor = c
                if addonTable.Misc and addonTable.Misc.UpdateZoneText then addonTable.Misc.UpdateZoneText() end
            end,
            cancelFunc = function()
                zoneColorSwatch.tex:SetColorTexture(c.r, c.g, c.b)
                UIThingsDB.misc.minimapZoneFontColor = c
                if addonTable.Misc and addonTable.Misc.UpdateZoneText then addonTable.Misc.UpdateZoneText() end
            end,
        })
    end)

    local lockZoneBtn = CreateFrame("CheckButton", "UIThingsMiscLockZone", panel, "ChatConfigCheckButtonTemplate")
    lockZoneBtn:SetPoint("TOPLEFT", 20, -1075)
    _G[lockZoneBtn:GetName() .. "Text"]:SetText("Lock Zone Position")
    lockZoneBtn:SetChecked(true)
    lockZoneBtn:SetScript("OnClick", function(self)
        if addonTable.Misc and addonTable.Misc.SetZoneLocked then
            addonTable.Misc.SetZoneLocked(self:GetChecked())
        end
    end)

    local zoneOff = UIThingsDB.misc.minimapZoneOffset or { x = 0, y = 4 }

    local zonePosLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zonePosLabel:SetPoint("TOPLEFT", 40, -1103)
    zonePosLabel:SetText("X:")

    local zoneXBox = CreateFrame("EditBox", "UIThingsMiscZoneX", panel, "InputBoxTemplate")
    zoneXBox:SetPoint("LEFT", zonePosLabel, "RIGHT", 5, 0)
    zoneXBox:SetSize(45, 20)
    zoneXBox:SetAutoFocus(false)
    zoneXBox:SetText(tostring(math.floor(zoneOff.x + 0.5)))
    zoneXBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText()) or 0
        local curY = UIThingsDB.misc.minimapZoneOffset and UIThingsDB.misc.minimapZoneOffset.y or 4
        if addonTable.Misc and addonTable.Misc.UpdateZonePosition then
            addonTable.Misc.UpdateZonePosition(val, curY)
        end
        self:ClearFocus()
    end)

    local zoneYLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneYLabel:SetPoint("LEFT", zoneXBox, "RIGHT", 10, 0)
    zoneYLabel:SetText("Y:")

    local zoneYBox = CreateFrame("EditBox", "UIThingsMiscZoneY", panel, "InputBoxTemplate")
    zoneYBox:SetPoint("LEFT", zoneYLabel, "RIGHT", 5, 0)
    zoneYBox:SetSize(45, 20)
    zoneYBox:SetAutoFocus(false)
    zoneYBox:SetText(tostring(math.floor(zoneOff.y + 0.5)))
    zoneYBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText()) or 0
        local curX = UIThingsDB.misc.minimapZoneOffset and UIThingsDB.misc.minimapZoneOffset.x or 0
        if addonTable.Misc and addonTable.Misc.UpdateZonePosition then
            addonTable.Misc.UpdateZonePosition(curX, val)
        end
        self:ClearFocus()
    end)

    -- ===== RIGHT COLUMN: Clock =====
    local rightCol = 300

    local showClockBtn = CreateFrame("CheckButton", "UIThingsMiscShowClock", panel, "ChatConfigCheckButtonTemplate")
    showClockBtn:SetPoint("TOPLEFT", rightCol, -920)
    _G[showClockBtn:GetName() .. "Text"]:SetText("Show Clock")
    showClockBtn:SetChecked(UIThingsDB.misc.minimapShowClock)
    showClockBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.minimapShowClock = self:GetChecked()
        if addonTable.Misc and addonTable.Misc.UpdateClockText then addonTable.Misc.UpdateClockText() end
    end)

    Helpers.CreateFontDropdown(panel, "UIThingsMiscClockFont", "Clock Font:", UIThingsDB.misc.minimapClockFont, function(fontPath)
        UIThingsDB.misc.minimapClockFont = fontPath
        if addonTable.Misc and addonTable.Misc.UpdateClockText then addonTable.Misc.UpdateClockText() end
    end, rightCol + 20, -950)

    local clockSizeSlider = CreateFrame("Slider", "UIThingsMiscClockFontSize", panel, "OptionsSliderTemplate")
    clockSizeSlider:SetPoint("TOPLEFT", rightCol + 20, -1020)
    clockSizeSlider:SetWidth(200)
    clockSizeSlider:SetMinMaxValues(8, 24)
    clockSizeSlider:SetValueStep(1)
    clockSizeSlider:SetObeyStepOnDrag(true)
    clockSizeSlider:SetValue(UIThingsDB.misc.minimapClockFontSize or 11)
    _G[clockSizeSlider:GetName() .. "Low"]:SetText("8")
    _G[clockSizeSlider:GetName() .. "High"]:SetText("24")
    _G[clockSizeSlider:GetName() .. "Text"]:SetText("Clock Font Size: " .. (UIThingsDB.misc.minimapClockFontSize or 11))
    clockSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        UIThingsDB.misc.minimapClockFontSize = value
        _G[self:GetName() .. "Text"]:SetText("Clock Font Size: " .. value)
        if addonTable.Misc and addonTable.Misc.UpdateClockText then addonTable.Misc.UpdateClockText() end
    end)

    -- Clock Font Color
    local clockColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clockColorLabel:SetPoint("TOPLEFT", rightCol + 20, -1048)
    clockColorLabel:SetText("Font Color:")

    local clockColorSwatch = CreateFrame("Button", nil, panel)
    clockColorSwatch:SetPoint("LEFT", clockColorLabel, "RIGHT", 8, 0)
    clockColorSwatch:SetSize(20, 20)
    local ccCur = UIThingsDB.misc.minimapClockFontColor or { r = 1, g = 1, b = 1 }
    clockColorSwatch.tex = clockColorSwatch:CreateTexture(nil, "BACKGROUND")
    clockColorSwatch.tex:SetAllPoints()
    clockColorSwatch.tex:SetColorTexture(ccCur.r, ccCur.g, ccCur.b)
    clockColorSwatch:SetScript("OnClick", function()
        local c = UIThingsDB.misc.minimapClockFontColor or { r = 1, g = 1, b = 1 }
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r, g = c.g, b = c.b,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                c.r, c.g, c.b = r, g, b
                clockColorSwatch.tex:SetColorTexture(r, g, b)
                UIThingsDB.misc.minimapClockFontColor = c
                if addonTable.Misc and addonTable.Misc.UpdateClockText then addonTable.Misc.UpdateClockText() end
            end,
            cancelFunc = function()
                clockColorSwatch.tex:SetColorTexture(c.r, c.g, c.b)
                UIThingsDB.misc.minimapClockFontColor = c
                if addonTable.Misc and addonTable.Misc.UpdateClockText then addonTable.Misc.UpdateClockText() end
            end,
        })
    end)

    -- Clock Format Dropdown (12H/24H)
    local clockFormatLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clockFormatLabel:SetPoint("TOPLEFT", rightCol + 20, -1075)
    clockFormatLabel:SetText("Format:")

    local clockFormatDropdown = CreateFrame("Frame", "UIThingsMiscClockFormat", panel, "UIDropDownMenuTemplate")
    clockFormatDropdown:SetPoint("LEFT", clockFormatLabel, "RIGHT", -5, -3)
    UIDropDownMenu_SetWidth(clockFormatDropdown, 50)
    UIDropDownMenu_SetText(clockFormatDropdown, UIThingsDB.misc.minimapClockFormat or "24H")

    UIDropDownMenu_Initialize(clockFormatDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "24H"
        info.checked = (UIThingsDB.misc.minimapClockFormat or "24H") == "24H"
        info.func = function()
            UIThingsDB.misc.minimapClockFormat = "24H"
            UIDropDownMenu_SetText(clockFormatDropdown, "24H")
        end
        UIDropDownMenu_AddButton(info)

        info.text = "12H"
        info.checked = UIThingsDB.misc.minimapClockFormat == "12H"
        info.func = function()
            UIThingsDB.misc.minimapClockFormat = "12H"
            UIDropDownMenu_SetText(clockFormatDropdown, "12H")
        end
        UIDropDownMenu_AddButton(info)
    end)

    -- Time Source Dropdown (Local/Server) - no label, placed right of format
    local clockSourceDropdown = CreateFrame("Frame", "UIThingsMiscClockSource", panel, "UIDropDownMenuTemplate")
    clockSourceDropdown:SetPoint("LEFT", clockFormatDropdown, "RIGHT", -30, 0)
    UIDropDownMenu_SetWidth(clockSourceDropdown, 80)
    local srcText = (UIThingsDB.misc.minimapClockTimeSource or "local") == "local" and "Local" or "Server"
    UIDropDownMenu_SetText(clockSourceDropdown, srcText)

    UIDropDownMenu_Initialize(clockSourceDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Local"
        info.checked = (UIThingsDB.misc.minimapClockTimeSource or "local") == "local"
        info.func = function()
            UIThingsDB.misc.minimapClockTimeSource = "local"
            UIDropDownMenu_SetText(clockSourceDropdown, "Local")
        end
        UIDropDownMenu_AddButton(info)

        info.text = "Server"
        info.checked = UIThingsDB.misc.minimapClockTimeSource == "server"
        info.func = function()
            UIThingsDB.misc.minimapClockTimeSource = "server"
            UIDropDownMenu_SetText(clockSourceDropdown, "Server")
        end
        UIDropDownMenu_AddButton(info)
    end)

    local lockClockBtn = CreateFrame("CheckButton", "UIThingsMiscLockClock", panel, "ChatConfigCheckButtonTemplate")
    lockClockBtn:SetPoint("TOPLEFT", rightCol, -1110)
    _G[lockClockBtn:GetName() .. "Text"]:SetText("Lock Clock Position")
    lockClockBtn:SetChecked(true)
    lockClockBtn:SetScript("OnClick", function(self)
        if addonTable.Misc and addonTable.Misc.SetClockLocked then
            addonTable.Misc.SetClockLocked(self:GetChecked())
        end
    end)

    local clockOff = UIThingsDB.misc.minimapClockOffset or { x = 0, y = -4 }

    local clockPosLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clockPosLabel:SetPoint("TOPLEFT", rightCol + 20, -1138)
    clockPosLabel:SetText("X:")

    local clockXBox = CreateFrame("EditBox", "UIThingsMiscClockX", panel, "InputBoxTemplate")
    clockXBox:SetPoint("LEFT", clockPosLabel, "RIGHT", 5, 0)
    clockXBox:SetSize(45, 20)
    clockXBox:SetAutoFocus(false)
    clockXBox:SetText(tostring(math.floor(clockOff.x + 0.5)))
    clockXBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText()) or 0
        local curY = UIThingsDB.misc.minimapClockOffset and UIThingsDB.misc.minimapClockOffset.y or -4
        if addonTable.Misc and addonTable.Misc.UpdateClockPosition then
            addonTable.Misc.UpdateClockPosition(val, curY)
        end
        self:ClearFocus()
    end)

    local clockYLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clockYLabel:SetPoint("LEFT", clockXBox, "RIGHT", 10, 0)
    clockYLabel:SetText("Y:")

    local clockYBox = CreateFrame("EditBox", "UIThingsMiscClockY", panel, "InputBoxTemplate")
    clockYBox:SetPoint("LEFT", clockYLabel, "RIGHT", 5, 0)
    clockYBox:SetSize(45, 20)
    clockYBox:SetAutoFocus(false)
    clockYBox:SetText(tostring(math.floor(clockOff.y + 0.5)))
    clockYBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText()) or 0
        local curX = UIThingsDB.misc.minimapClockOffset and UIThingsDB.misc.minimapClockOffset.x or 0
        if addonTable.Misc and addonTable.Misc.UpdateClockPosition then
            addonTable.Misc.UpdateClockPosition(curX, val)
        end
        self:ClearFocus()
    end)
end


