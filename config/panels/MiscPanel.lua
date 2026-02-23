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
    scrollChild:SetSize(panel:GetWidth() - 30, 500)
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

    -- Class Color Tooltips
    local tooltipBtn = CreateFrame("CheckButton", "UIThingsMiscClassTooltips", panel, "ChatConfigCheckButtonTemplate")
    tooltipBtn:SetPoint("TOPLEFT", 20, -70)
    _G[tooltipBtn:GetName() .. "Text"]:SetText("Class-Color Unit Tooltip Names")
    tooltipBtn:SetChecked(UIThingsDB.misc.classColorTooltips)
    tooltipBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.classColorTooltips = self:GetChecked()
        if self:GetChecked() and addonTable.Misc then
            -- Hook is permanent once installed, but only activates when setting is true
            addonTable.Misc.ApplyEvents()
        end
    end)

    -- Show Spell/Item ID on Tooltips
    local spellIDBtn = CreateFrame("CheckButton", "UIThingsMiscSpellID", panel, "ChatConfigCheckButtonTemplate")
    spellIDBtn:SetPoint("TOPLEFT", 20, -90)
    _G[spellIDBtn:GetName() .. "Text"]:SetText("Show Spell/Item ID on Tooltips")
    spellIDBtn:SetChecked(UIThingsDB.misc.showSpellID)
    spellIDBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.showSpellID = self:GetChecked()
        if self:GetChecked() and addonTable.Misc then
            addonTable.Misc.ApplyEvents()
        end
    end)

    -- UI Scale Section
    Helpers.CreateSectionHeader(panel, "UI Scale", -140)

    -- UI Scale Enable Checkbox
    local uiScaleBtn = CreateFrame("CheckButton", "UIThingsMiscUIScaleEnable", panel,
        "ChatConfigCheckButtonTemplate")
    uiScaleBtn:SetPoint("TOPLEFT", 20, -170)
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

    scaleSlider:SetPoint("TOPLEFT", 40, -210)
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
    Helpers.CreateSectionHeader(panel, "Invite Automation", -220)

    local friendsBtn = CreateFrame("CheckButton", "UIThingsMiscAutoFriends", panel, "ChatConfigCheckButtonTemplate")
    friendsBtn:SetPoint("TOPLEFT", 20, -250)
    _G[friendsBtn:GetName() .. "Text"]:SetText("Auto-Accept: Friends")
    friendsBtn:SetChecked(UIThingsDB.misc.autoAcceptFriends)
    friendsBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.autoAcceptFriends = self:GetChecked()
    end)

    local guildBtn = CreateFrame("CheckButton", "UIThingsMiscAutoGuild", panel, "ChatConfigCheckButtonTemplate")
    guildBtn:SetPoint("TOPLEFT", 180, -250)
    _G[guildBtn:GetName() .. "Text"]:SetText("Auto-Accept: Guild")
    guildBtn:SetChecked(UIThingsDB.misc.autoAcceptGuild)
    guildBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.autoAcceptGuild = self:GetChecked()
    end)

    local everyoneBtn = CreateFrame("CheckButton", "UIThingsMiscAutoEveryone", panel, "ChatConfigCheckButtonTemplate")
    everyoneBtn:SetPoint("TOPLEFT", 340, -250)
    _G[everyoneBtn:GetName() .. "Text"]:SetText("Auto-Accept: Everyone")
    everyoneBtn:SetChecked(UIThingsDB.misc.autoAcceptEveryone)
    everyoneBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.autoAcceptEveryone = self:GetChecked()
    end)

    -- Invite by Whisper
    local whisperBtn = CreateFrame("CheckButton", "UIThingsMiscAutoInvite", panel, "ChatConfigCheckButtonTemplate")
    whisperBtn:SetPoint("TOPLEFT", 20, -285)
    _G[whisperBtn:GetName() .. "Text"]:SetText("Enable Invite by Whisper")
    whisperBtn:SetChecked(UIThingsDB.misc.autoInviteEnabled)
    whisperBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.autoInviteEnabled = self:GetChecked()
        if addonTable.Misc and addonTable.Misc.UpdateAutoInviteKeywords then addonTable.Misc.UpdateAutoInviteKeywords() end
    end)

    local kwLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    kwLabel:SetPoint("TOPLEFT", 40, -315)
    kwLabel:SetText("Keywords (comma separated):")

    local kwEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    kwEdit:SetSize(200, 20)
    kwEdit:SetPoint("TOPLEFT", 40, -330)
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
    Helpers.CreateSectionHeader(panel, "Convenience", -370)

    -- Reload UI Checkbox
    local rlBtn = CreateFrame("CheckButton", "UIThingsMiscAllowRL", panel, "ChatConfigCheckButtonTemplate")
    rlBtn:SetPoint("TOPLEFT", 20, -400)
    _G[rlBtn:GetName() .. "Text"]:SetText("Allow /rl to Reload UI")
    rlBtn:SetChecked(UIThingsDB.misc.allowRL)
    rlBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.allowRL = self:GetChecked()
    end)

    -- Quick Item Destroy Checkbox
    local qdBtn = CreateFrame("CheckButton", "UIThingsMiscQuickDestroy", panel, "ChatConfigCheckButtonTemplate")
    qdBtn:SetPoint("TOPLEFT", 20, -430)
    _G[qdBtn:GetName() .. "Text"]:SetText("Quick Item Destroy (Red Button)")
    qdBtn:SetChecked(UIThingsDB.misc.quickDestroy)
    qdBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.quickDestroy = self:GetChecked()
        if addonTable.Misc and addonTable.Misc.ToggleQuickDestroy then
            addonTable.Misc.ToggleQuickDestroy(UIThingsDB.misc.quickDestroy)
        end
    end)
end
