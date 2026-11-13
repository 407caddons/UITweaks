local addon = _G.LunaUITweaks
addon.ConfigSetup = addon.ConfigSetup or {}

-- Nameplates page: threat colours (NameplateColors) and quest marks
-- (NameplateQuestMarks). Both store settings under UIThingsDB.nameplateColors,
-- so the page's Reset button covers both.
function addon.ConfigSetup.Nameplates(panel)
    local Helpers = addon.ConfigHelpers
    local Colors, Marks = addon.NameplateColors, addon.NameplateQuestMarks
    local db = UIThingsDB.nameplateColors
    Helpers.CreateResetButton(panel, "nameplateColors")

    local title = panel:CreateFontString(nil, "ARTWORK", "LunaFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Nameplates")

    local function Check(text, y, get, set)
        local check = CreateFrame("CheckButton", nil, panel, "ChatConfigCheckButtonTemplate")
        check:SetPoint("TOPLEFT", 20, y)
        check.Text:SetText(text)
        check:SetChecked(get())
        check:SetScript("OnClick", function(self) set(not not self:GetChecked()) end)
        return check
    end

    local function Note(text, y)
        local note = panel:CreateFontString(nil, "ARTWORK", "LunaFontHighlightSmall")
        note:SetPoint("TOPLEFT", 20, y)
        note:SetWidth(540)
        note:SetJustifyH("LEFT")
        note:SetText(text)
        return note
    end

    -- Threat colours ------------------------------------------------------------
    Helpers.CreateSectionHeader(panel, "Threat Colours", -50)
    Check("Colour Blizzard enemy nameplates by tank threat", -75,
        function() return db.enabled end,
        function(value) db.enabled = value; Colors.Refresh() end)
    local entries = {
        { "idle", "Out of combat" },
        { "noTank", "In combat: no tank has threat" },
        { "otherTank", "In combat: another tank has threat" },
        { "selfTank", "In combat: you have threat as a tank" },
    }
    for i, entry in ipairs(entries) do
        local key = entry[1]
        Helpers.CreateColorPicker(panel, nil, entry[2], function()
            local c = db[key]
            return c.r, c.g, c.b
        end, function(r, g, b)
            db[key] = { r = r, g = g, b = b }
            Colors.Refresh()
        end, -105 - (i - 1) * 32)
    end
    Note("Uses Blizzard's existing nameplates. Tank roles come from the group role assignment. If you pull threat "
        .. "as DPS or healer, the no-tank colour applies. When threat information is restricted or unavailable, "
        .. "Blizzard's normal colours are used.", -240)

    -- Quest marks ---------------------------------------------------------------
    local marks = db.questMarks
    local function Apply() Marks.UpdateSettings() end
    Helpers.CreateSectionHeader(panel, "Quest Marks", -295)
    Note("A kill or loot icon and objective progress (e.g. 3/8) beside nameplates of units your active quests need. "
        .. "Inside dungeons and raids quest details are hidden from addons, so only a yes/no mark is shown there.", -320)
    Check("Show quest marks on nameplates", -355,
        function() return marks.enabled end,
        function(value) marks.enabled = value; Apply() end)
    Check("Show kill/loot icon", -378,
        function() return marks.icon ~= false end,
        function(value) marks.icon = value; Apply() end)
    Check("Show objective progress beside the icon", -401,
        function() return marks.progress end,
        function(value) marks.progress = value; Apply() end)
    Check("Outline quest mobs' health bars (bar colour still shows threat)", -424,
        function() return marks.border ~= false end,
        function(value) marks.border = value; Apply() end)
    Helpers.CreateColorPicker(panel, nil, "Quest outline colour", function()
        local c = marks.borderColor or { r = 1, g = 0.82, b = 0 }
        return c.r, c.g, c.b
    end, function(r, g, b)
        marks.borderColor = { r = r, g = g, b = b, a = 1 }
        Apply()
    end, -450)
    Check("Hide quest marks inside instances", -478,
        function() return marks.hideInInstances end,
        function(value) marks.hideInInstances = value; Apply() end)

    local sizeLabel = panel:CreateFontString(nil, "ARTWORK", "LunaFontNormal")
    sizeLabel:SetPoint("TOPLEFT", 20, -518)
    sizeLabel:SetText("Icon size:")
    local slider = CreateFrame("Slider", "LunaNameplateQuestMarkSize", panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 110, -518)
    slider:SetWidth(180)
    slider:SetMinMaxValues(12, 40)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    _G[slider:GetName() .. "Low"]:SetText("12")
    _G[slider:GetName() .. "High"]:SetText("40")
    local function SizeText(value) _G[slider:GetName() .. "Text"]:SetText(string.format("%d px", value)) end
    slider:SetValue(marks.size or 20)
    SizeText(marks.size or 20)
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        marks.size = value
        SizeText(value)
        Apply()
    end)

    local positionLabel = panel:CreateFontString(nil, "ARTWORK", "LunaFontNormal")
    positionLabel:SetPoint("TOPLEFT", 20, -560)
    positionLabel:SetText("Position:")
    local positions = { { "RIGHT", "Right of health bar" }, { "LEFT", "Left of health bar" }, { "TOP", "Above health bar" } }
    local dropdown = CreateFrame("Frame", "LunaNameplateQuestMarkPosition", panel, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 90, -552)
    UIDropDownMenu_SetWidth(dropdown, 180)
    local function PositionText(value)
        for _, option in ipairs(positions) do
            if option[1] == value then return option[2] end
        end
        return positions[1][2]
    end
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        for _, option in ipairs(positions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option[2]
            info.checked = (marks.anchor or "RIGHT") == option[1]
            info.func = function()
                marks.anchor = option[1]
                UIDropDownMenu_SetText(dropdown, option[2])
                Apply()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetText(dropdown, PositionText(marks.anchor))
end
