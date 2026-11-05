-- Shared controls embedded in General UI, Loot and Notifications. The saved
-- qualityOfLife table is retained for existing profiles and import/export.
local addon = _G.LunaUITweaks
local Helpers = addon.ConfigHelpers
addon.ConfigSetup = addon.ConfigSetup or {}
local Setup = addon.ConfigSetup
local function Controls(panel, section)
    local QoL = addon.QualityOfLife
    local checks, sliders = {}, {}
    local function DB() return QoL.Settings() end
    local function Apply() QoL.UpdateSettings() end
    local function Label(text, y)
        local label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", 24, y)
        label:SetWidth(550)
        label:SetJustifyH("LEFT")
        label:SetText(text)
        return label
    end
    local function Check(key, text, y)
        local check = CreateFrame("CheckButton", nil, panel, "ChatConfigCheckButtonTemplate")
        check:SetPoint("TOPLEFT", 20, y)
        check.Text:SetText(text)
        check:SetScript("OnClick", function(self)
            DB()[key] = not not self:GetChecked()
            Apply()
        end)
        checks[key] = check
    end
    local function Slider(key, text, y, lo, hi, step)
        local name = "LunaConvenience" .. section .. key
        local slider = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", 28, y)
        slider:SetWidth(240)
        slider:SetMinMaxValues(lo, hi)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)
        _G[name .. "Low"]:SetText(tostring(lo))
        _G[name .. "High"]:SetText(tostring(hi))
        local refreshing = false
        local function Text(value) _G[name .. "Text"]:SetText(text .. ": " .. string.format(step < 1 and "%.1f" or "%d", value)) end
        slider:SetScript("OnValueChanged", function(_, value)
            Text(value)
            if not refreshing then
                DB()[key] = value
                Apply()
            end
        end)
        sliders[#sliders + 1] = function()
            refreshing = true
            slider:SetValue(DB()[key])
            Text(DB()[key])
            refreshing = false
        end
    end
    local function Button(text, x, y, width, callback)
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", x, y)
        button:SetSize(width, 25)
        button:SetText(text)
        button:SetScript("OnClick", callback)
    end
    local function Refresh()
        for key, check in pairs(checks) do
            local supported = not addon.Client or addon.Client.SupportsQoL(key)
            check:SetEnabled(supported)
            check:SetChecked(supported and DB()[key])
        end
        for _, refresh in ipairs(sliders) do refresh() end
    end
    panel:HookScript("OnShow", Refresh)
    return DB, Apply, Label, Check, Slider, Button, Refresh
end
function Setup.GeneralConvenience(panel, y)
    local DB, Apply, Label, Check, Slider, Button, Refresh = Controls(panel, "General")
    Helpers.CreateSectionHeader(panel, "Cursor ring", y)
    Check("cursor", "Show cursor ring (hidden during mouse-look)", y - 30)
    Check("cursorClassColor", "Use class color", y - 60)
    Slider("cursorSize", "Ring size", y - 120, 12, 80, 1)
    Slider("cursorAlpha", "Opacity", y - 185, .1, 1, .1)
    Helpers.CreateColorSwatch(panel, "Custom ring color", DB().cursorColor, Apply, 320, y - 115, false)
    Helpers.CreateSectionHeader(panel, "Interface convenience", y - 235)
    Check("skipCinematics", "Skip cinematics and movies (one keypress for scenes; bypass confirmation)", y - 265)
    Check("hideTutorials", "Hide tutorial tips", y - 295)
    Check("hideTalkingHead", "Hide talking-head dialogue frames", y - 325)
    if addon.Client and addon.Client.isForever then
        Check("spellRanks", "Outline bar spells below your highest known rank and list them in chat at login/reload", y - 355)
    end
    Refresh()
end
function Setup.LootConvenience(panel, y)
    local DB, Apply, Label, Check, Slider, Button, Refresh = Controls(panel, "Loot")
    Helpers.CreateSectionHeader(panel, "Containers and collections", y)
    Check("autoOpen", "Automatically open loot containers", y - 30)
    Check("excludeWarbound", "Keep Warbound containers unopened", y - 60)
    Label("One container at a time, outside combat. Pauses at vendors, banks, mail, trade, while casting or looting. Hold Shift to pause.", y - 95)
    Button("Retry blocked containers", 24, y - 140, 210, function() addon.QualityOfLife.AutoOpen.Retry() end)
    Check("unwrapCollections", "Automatically unwrap new mounts, pets and toys", y - 180)
    local status = Label("", y - 220)
    panel:HookScript("OnShow", function()
        status:SetText(addon.QualityOfLife.AutoOpen.GetConflict() and "Ellesmere auto-opening is active; Luna waits until it is disabled." or "")
    end)
    Refresh()
end
function Setup.GameplayAlerts(panel, y)
    local DB, Apply, Label, Check, Slider, Button, Refresh = Controls(panel, "Alerts")
    Helpers.CreateSectionHeader(panel, "Gameplay alerts", y)
    Check("movement", "Show mobility ability cooldowns (all classes)", y - 30)
    Check("movementTts", "Speak when a movement ability becomes ready", y - 60)
    Button("Test voice", 365, y - 60, 130, function() addon.Core.SpeakTTS("Movement ability ready", DB().movementVoice) end)
    Check("timeSpiral", "Show Time Spiral / free-movement proc alert", y - 90)
    Check("gateway", "Show Gateway Control Shard readiness (Warlocks)", y - 120)
    Check("battleRes", "Show battle resurrection icon and charges in M+ and raids", y - 150)
    Label("An enabled Battle Res widget takes priority. Use Layout Mode to position alerts. Restricted combat values are passed to native displays; unavailable cooldown data never triggers speech.", y - 185)
    Slider("alertFontSize", "Alert text size", y - 250, 12, 40, 1)
    Label("Additional mobility spell IDs (comma separated; only learned spells are tracked)", y - 295)
    local extra = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    extra:SetPoint("TOPLEFT", 28, y - 325)
    extra:SetSize(530, 24)
    extra:SetAutoFocus(false)
    extra:SetScript("OnEnterPressed", function(self)
        DB().movementExtraSpells = self:GetText()
        self:ClearFocus()
        Apply()
    end)
    panel:HookScript("OnShow", function() extra:SetText(DB().movementExtraSpells or "") end)
    panel:HookScript("OnHide", function() extra:ClearFocus() end)
    extra:SetText(DB().movementExtraSpells or "")
    Refresh()
end
