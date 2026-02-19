local addonName, addonTable = ...

-- Create setup table if it doesn't exist
addonTable.ConfigSetup = addonTable.ConfigSetup or {}

-- Get helpers
local Helpers = addonTable.ConfigHelpers

-- Define the setup function for General UI panel (formerly Misc)
function addonTable.ConfigSetup.Misc(panel, tab, configWindow)
    Helpers.CreateResetButton(panel, "misc")
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("General UI")

    -- Create scroll frame for the settings
    local scrollFrame = CreateFrame("ScrollFrame", "UIThingsMiscScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(panel:GetWidth() - 30, 920)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:SetScript("OnShow", function()
        scrollChild:SetWidth(scrollFrame:GetWidth())
    end)

    -- Update panel reference to scrollChild for all child elements
    panel = scrollChild

    -- Enable Checkbox
    local enableBtn = CreateFrame("CheckButton", "UIThingsMiscEnable", panel, "ChatConfigCheckButtonTemplate")
    enableBtn:SetPoint("TOPLEFT", 20, -10)
    _G[enableBtn:GetName() .. "Text"]:SetText("Enable General UI Module")
    enableBtn:SetChecked(UIThingsDB.misc.enabled)
    enableBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.enabled = self:GetChecked()
        Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.misc.enabled)
        if addonTable.Misc and addonTable.Misc.ApplyEvents then
            addonTable.Misc.ApplyEvents()
        end
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

    -- UI Scale Section
    Helpers.CreateSectionHeader(panel, "UI Scale", -80)

    -- UI Scale Enable Checkbox
    local uiScaleBtn = CreateFrame("CheckButton", "UIThingsMiscUIScaleEnable", panel,
        "ChatConfigCheckButtonTemplate")
    uiScaleBtn:SetPoint("TOPLEFT", 20, -110)
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

    scaleSlider:SetPoint("TOPLEFT", 40, -150)
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

    -- Invite Automation Section
    Helpers.CreateSectionHeader(panel, "Invite Automation", -190)

    local friendsBtn = CreateFrame("CheckButton", "UIThingsMiscAutoFriends", panel, "ChatConfigCheckButtonTemplate")
    friendsBtn:SetPoint("TOPLEFT", 20, -220)
    _G[friendsBtn:GetName() .. "Text"]:SetText("Auto-Accept: Friends")
    friendsBtn:SetChecked(UIThingsDB.misc.autoAcceptFriends)
    friendsBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.autoAcceptFriends = self:GetChecked()
    end)

    local guildBtn = CreateFrame("CheckButton", "UIThingsMiscAutoGuild", panel, "ChatConfigCheckButtonTemplate")
    guildBtn:SetPoint("TOPLEFT", 180, -220)
    _G[guildBtn:GetName() .. "Text"]:SetText("Auto-Accept: Guild")
    guildBtn:SetChecked(UIThingsDB.misc.autoAcceptGuild)
    guildBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.autoAcceptGuild = self:GetChecked()
    end)

    local everyoneBtn = CreateFrame("CheckButton", "UIThingsMiscAutoEveryone", panel, "ChatConfigCheckButtonTemplate")
    everyoneBtn:SetPoint("TOPLEFT", 340, -220)
    _G[everyoneBtn:GetName() .. "Text"]:SetText("Auto-Accept: Everyone")
    everyoneBtn:SetChecked(UIThingsDB.misc.autoAcceptEveryone)
    everyoneBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.autoAcceptEveryone = self:GetChecked()
    end)

    -- Invite by Whisper
    local whisperBtn = CreateFrame("CheckButton", "UIThingsMiscAutoInvite", panel, "ChatConfigCheckButtonTemplate")
    whisperBtn:SetPoint("TOPLEFT", 20, -255)
    _G[whisperBtn:GetName() .. "Text"]:SetText("Enable Invite by Whisper")
    whisperBtn:SetChecked(UIThingsDB.misc.autoInviteEnabled)
    whisperBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.autoInviteEnabled = self:GetChecked()
        if addonTable.Misc and addonTable.Misc.UpdateAutoInviteKeywords then addonTable.Misc.UpdateAutoInviteKeywords() end
    end)

    local kwLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    kwLabel:SetPoint("TOPLEFT", 40, -285)
    kwLabel:SetText("Keywords (comma separated):")

    local kwEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    kwEdit:SetSize(200, 20)
    kwEdit:SetPoint("TOPLEFT", 40, -300)
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

    -- Convenience Section
    Helpers.CreateSectionHeader(panel, "Convenience", -340)

    -- Reload UI Checkbox
    local rlBtn = CreateFrame("CheckButton", "UIThingsMiscAllowRL", panel, "ChatConfigCheckButtonTemplate")
    rlBtn:SetPoint("TOPLEFT", 20, -370)
    _G[rlBtn:GetName() .. "Text"]:SetText("Allow /rl to Reload UI")
    rlBtn:SetChecked(UIThingsDB.misc.allowRL)
    rlBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.allowRL = self:GetChecked()
    end)

    -- Quick Item Destroy Checkbox
    local qdBtn = CreateFrame("CheckButton", "UIThingsMiscQuickDestroy", panel, "ChatConfigCheckButtonTemplate")
    qdBtn:SetPoint("TOPLEFT", 20, -400)
    _G[qdBtn:GetName() .. "Text"]:SetText("Quick Item Destroy (Red Button)")
    qdBtn:SetChecked(UIThingsDB.misc.quickDestroy)
    qdBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.quickDestroy = self:GetChecked()
        if addonTable.Misc and addonTable.Misc.ToggleQuickDestroy then
            addonTable.Misc.ToggleQuickDestroy(UIThingsDB.misc.quickDestroy)
        end
    end)

    -- Scrolling Combat Text Section
    Helpers.CreateSectionHeader(panel, "Scrolling Combat Text", -440)

    local sctEnable = CreateFrame("CheckButton", "UIThingsMiscSCTEnable", panel, "ChatConfigCheckButtonTemplate")
    sctEnable:SetPoint("TOPLEFT", 20, -470)
    _G[sctEnable:GetName() .. "Text"]:SetText("Enable Floating Combat Text")
    sctEnable:SetChecked(UIThingsDB.misc.sct.enabled)
    sctEnable:SetScript("OnClick", function(self)
        UIThingsDB.misc.sct.enabled = self:GetChecked()
        if addonTable.Misc and addonTable.Misc.ApplyEvents then
            addonTable.Misc.ApplyEvents()
        end
    end)

    local sctCapture = CreateFrame("CheckButton", "UIThingsMiscSCTCapture", panel, "ChatConfigCheckButtonTemplate")
    sctCapture:SetPoint("TOPLEFT", 280, -470)
    _G[sctCapture:GetName() .. "Text"]:SetText("Capture to Frames")
    sctCapture:SetChecked(UIThingsDB.misc.sct.captureToFrames)
    sctCapture:SetScript("OnClick", function(self)
        UIThingsDB.misc.sct.captureToFrames = self:GetChecked()
        if addonTable.Misc and addonTable.Misc.ApplyEvents then
            addonTable.Misc.ApplyEvents()
        end
    end)

    local sctDmg = CreateFrame("CheckButton", "UIThingsMiscSCTDamage", panel, "ChatConfigCheckButtonTemplate")
    sctDmg:SetPoint("TOPLEFT", 20, -500)
    _G[sctDmg:GetName() .. "Text"]:SetText("Show Damage")
    sctDmg:SetChecked(UIThingsDB.misc.sct.showDamage)
    sctDmg:SetScript("OnClick", function(self)
        UIThingsDB.misc.sct.showDamage = self:GetChecked()
    end)

    local sctHeal = CreateFrame("CheckButton", "UIThingsMiscSCTHealing", panel, "ChatConfigCheckButtonTemplate")
    sctHeal:SetPoint("TOPLEFT", 200, -500)
    _G[sctHeal:GetName() .. "Text"]:SetText("Show Healing")
    sctHeal:SetChecked(UIThingsDB.misc.sct.showHealing)
    sctHeal:SetScript("OnClick", function(self)
        UIThingsDB.misc.sct.showHealing = self:GetChecked()
    end)

    local sctTargetDmg = CreateFrame("CheckButton", "UIThingsMiscSCTTargetDmg", panel, "ChatConfigCheckButtonTemplate")
    sctTargetDmg:SetPoint("TOPLEFT", 20, -530)
    _G[sctTargetDmg:GetName() .. "Text"]:SetText("Show Target Name (Damage)")
    sctTargetDmg:SetChecked(UIThingsDB.misc.sct.showTargetDamage)
    sctTargetDmg:SetScript("OnClick", function(self)
        UIThingsDB.misc.sct.showTargetDamage = self:GetChecked()
    end)

    local sctTargetHeal = CreateFrame("CheckButton", "UIThingsMiscSCTTargetHeal", panel, "ChatConfigCheckButtonTemplate")
    sctTargetHeal:SetPoint("TOPLEFT", 280, -530)
    _G[sctTargetHeal:GetName() .. "Text"]:SetText("Show Target Name (Healing)")
    sctTargetHeal:SetChecked(UIThingsDB.misc.sct.showTargetHealing)
    sctTargetHeal:SetScript("OnClick", function(self)
        UIThingsDB.misc.sct.showTargetHealing = self:GetChecked()
    end)

    -- Font Size Slider
    local fontSlider = CreateFrame("Slider", "UIThingsMiscSCTFontSize", panel, "OptionsSliderTemplate")
    fontSlider:SetPoint("TOPLEFT", 40, -570)
    fontSlider:SetMinMaxValues(10, 48)
    fontSlider:SetValueStep(1)
    fontSlider:SetObeyStepOnDrag(true)
    fontSlider:SetWidth(200)
    _G[fontSlider:GetName() .. 'Text']:SetText("Font Size: " .. UIThingsDB.misc.sct.fontSize)
    _G[fontSlider:GetName() .. 'Low']:SetText("10")
    _G[fontSlider:GetName() .. 'High']:SetText("48")
    fontSlider:SetValue(UIThingsDB.misc.sct.fontSize)
    fontSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        UIThingsDB.misc.sct.fontSize = value
        _G[self:GetName() .. 'Text']:SetText("Font Size: " .. value)
    end)

    -- Duration Slider
    local durSlider = CreateFrame("Slider", "UIThingsMiscSCTDuration", panel, "OptionsSliderTemplate")
    durSlider:SetPoint("TOPLEFT", 40, -620)
    durSlider:SetMinMaxValues(0.5, 5.0)
    durSlider:SetValueStep(0.1)
    durSlider:SetObeyStepOnDrag(true)
    durSlider:SetWidth(200)
    _G[durSlider:GetName() .. 'Text']:SetText("Duration: " .. string.format("%.1f", UIThingsDB.misc.sct.duration) .. "s")
    _G[durSlider:GetName() .. 'Low']:SetText("0.5")
    _G[durSlider:GetName() .. 'High']:SetText("5.0")
    durSlider:SetValue(UIThingsDB.misc.sct.duration)
    durSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 10 + 0.5) / 10
        UIThingsDB.misc.sct.duration = value
        _G[self:GetName() .. 'Text']:SetText("Duration: " .. string.format("%.1f", value) .. "s")
    end)

    -- Crit Scale Slider
    local critSlider = CreateFrame("Slider", "UIThingsMiscSCTCritScale", panel, "OptionsSliderTemplate")
    critSlider:SetPoint("TOPLEFT", 40, -670)
    critSlider:SetMinMaxValues(1.0, 3.0)
    critSlider:SetValueStep(0.1)
    critSlider:SetObeyStepOnDrag(true)
    critSlider:SetWidth(200)
    _G[critSlider:GetName() .. 'Text']:SetText("Crit Scale: " ..
        string.format("%.1f", UIThingsDB.misc.sct.critScale) .. "x")
    _G[critSlider:GetName() .. 'Low']:SetText("1.0")
    _G[critSlider:GetName() .. 'High']:SetText("3.0")
    critSlider:SetValue(UIThingsDB.misc.sct.critScale)
    critSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 10 + 0.5) / 10
        UIThingsDB.misc.sct.critScale = value
        _G[self:GetName() .. 'Text']:SetText("Crit Scale: " .. string.format("%.1f", value) .. "x")
    end)

    -- Scroll Distance Slider
    local distSlider = CreateFrame("Slider", "UIThingsMiscSCTDistance", panel, "OptionsSliderTemplate")
    distSlider:SetPoint("TOPLEFT", 40, -720)
    distSlider:SetMinMaxValues(50, 300)
    distSlider:SetValueStep(10)
    distSlider:SetObeyStepOnDrag(true)
    distSlider:SetWidth(200)
    _G[distSlider:GetName() .. 'Text']:SetText("Scroll Distance: " .. UIThingsDB.misc.sct.scrollDistance)
    _G[distSlider:GetName() .. 'Low']:SetText("50")
    _G[distSlider:GetName() .. 'High']:SetText("300")
    distSlider:SetValue(UIThingsDB.misc.sct.scrollDistance)
    distSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / 10 + 0.5) * 10
        UIThingsDB.misc.sct.scrollDistance = value
        _G[self:GetName() .. 'Text']:SetText("Scroll Distance: " .. value)
    end)

    -- Color Pickers
    Helpers.CreateColorSwatch(panel, "Damage Color", UIThingsDB.misc.sct.damageColor, nil, 20, -760, false)
    Helpers.CreateColorSwatch(panel, "Healing Color", UIThingsDB.misc.sct.healingColor, nil, 200, -760, false)

    -- Lock/Unlock Anchors Button
    local sctLockBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    sctLockBtn:SetSize(160, 24)
    sctLockBtn:SetPoint("TOPLEFT", 20, -800)
    sctLockBtn:SetText(UIThingsDB.misc.sct.locked and "Unlock Anchors" or "Lock Anchors")
    sctLockBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.sct.locked = not UIThingsDB.misc.sct.locked
        self:SetText(UIThingsDB.misc.sct.locked and "Unlock Anchors" or "Lock Anchors")
        if addonTable.Misc and addonTable.Misc.UpdateSCTSettings then
            addonTable.Misc.UpdateSCTSettings()
        end
    end)

    local sctNote = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sctNote:SetPoint("TOPLEFT", 20, -830)
    sctNote:SetText("Unlock to drag the damage (right) and healing (left) anchor frames.")
    sctNote:SetTextColor(0.7, 0.7, 0.7)
end
