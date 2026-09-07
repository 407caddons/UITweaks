local addonName, addonTable = "LunaUITweaks", _G["LunaUITweaks"]

addonTable.ConfigSetup = addonTable.ConfigSetup or {}
local Helpers = addonTable.ConfigHelpers

function addonTable.ConfigSetup.CompactGroupFinder(panel, tab)
    Helpers.CreateResetButton(panel, "compactGroupFinder")
    addonTable.ConfigTheme.Card(panel, "LAYOUT", 12, -120, 640, 85)
    addonTable.ConfigTheme.Card(panel, "GROUP DETAILS", 12, -218, 314, 145)
    addonTable.ConfigTheme.Card(panel, "LEADER & MEMBERS", 338, -218, 314, 145)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Compact Group Finder")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", 16, -45)
    description:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    description:SetJustifyH("LEFT")
    description:SetText("Shows premade-group search results on one line so more groups fit in the list. This only changes the appearance of Blizzard's search-result rows.")

    local function Apply()
        if addonTable.CompactGroupFinder then
            addonTable.CompactGroupFinder.UpdateSettings()
        end
        Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.compactGroupFinder.enabled)
    end

    local function Checkbox(name, label, y, key, x)
        local checkbox = CreateFrame("CheckButton", name, panel, "ChatConfigCheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", x or 20, y)
        _G[name .. "Text"]:SetText(label)
        checkbox:SetChecked(UIThingsDB.compactGroupFinder[key])
        checkbox:SetScript("OnClick", function(self)
            UIThingsDB.compactGroupFinder[key] = not not self:GetChecked()
            Apply()
        end)
        return checkbox
    end

    Checkbox("LunaUITweaksCompactLFGEnabled", "Enable compact, single-line results", -88, "enabled")

    local heightLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    heightLabel:SetPoint("TOPLEFT", 28, -152)
    heightLabel:SetText("Row height: " .. tostring(UIThingsDB.compactGroupFinder.rowHeight) .. " px")

    local heightSlider = CreateFrame("Slider", "LunaUITweaksCompactLFGHeight", panel, "OptionsSliderTemplate")
    heightSlider:SetPoint("TOPLEFT", 280, -156)
    heightSlider:SetMinMaxValues(24, 54)
    heightSlider:SetValueStep(1)
    heightSlider:SetObeyStepOnDrag(true)
    heightSlider:SetWidth(240)
    heightSlider:SetValue(UIThingsDB.compactGroupFinder.rowHeight)
    _G[heightSlider:GetName() .. "Low"]:SetText("24")
    _G[heightSlider:GetName() .. "High"]:SetText("54")
    _G[heightSlider:GetName() .. "Text"]:SetText("")
    heightSlider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        UIThingsDB.compactGroupFinder.rowHeight = value
        heightLabel:SetText("Row height: " .. value .. " px")
        Apply()
    end)

    Checkbox("LunaUITweaksCompactLFGActivity", "Dungeon / activity name", -250, "showActivity")
    Checkbox("LunaUITweaksCompactLFGPlaystyle", "Playstyle", -282, "showPlaystyle")
    Checkbox("LunaUITweaksCompactLFGVoice", "Voice-chat indicator", -314, "showVoiceChat")
    Checkbox("LunaUITweaksCompactLFGRating", "Leader Mythic+ rating", -250, "showRating", 350)
    Checkbox("LunaUITweaksCompactLFGMembers", "Member count", -282, "showMemberCount", 350)
    Checkbox("LunaUITweaksCompactLFGRoles", "Role data", -314, "showRoleData", 350)

    local note = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 20, -384)
    note:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
    note:SetJustifyH("LEFT")
    note:SetText("The group title is always shown. Enabling more text fields gives each one less horizontal space. Premade Groups Filter may add text to Blizzard's existing fields and remains compatible.")

    panel:SetScript("OnShow", function()
        heightSlider:SetValue(UIThingsDB.compactGroupFinder.rowHeight)
    end)

    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.compactGroupFinder.enabled)
end
