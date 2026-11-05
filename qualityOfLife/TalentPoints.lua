-- On-screen reminder while you have unspent talent points, out of combat.
-- Retail: C_ClassTalents.HasUnspentTalentPoints / HasUnspentHeroTalentPoints.
-- Forever (classic talents): UnitCharacterPoints("player") or GetUnspentTalentPoints().
-- Display only: never opens or touches the talent UI (opening it from addon
-- code would taint talent changes).
local _, addon = ...
local QoL = addon.QualityOfLife
local Points = {}
QoL.TalentPoints = Points
QoL.AddModule(Points)

local frame = CreateFrame("Frame", nil, UIParent)
frame:SetSize(360, 30)
frame:SetFrameStrata("HIGH")
frame:SetMovable(true)
frame:EnableMouse(false)
frame.text = frame:CreateFontString(nil, "OVERLAY")
frame.text:SetAllPoints()
frame.text:SetJustifyH("CENTER")
frame.text:SetTextColor(1, 0.82, 0)
frame:Hide()

local function Layout() return addon.LayoutMode and addon.LayoutMode.IsActive() end
addon.LayoutMode.RegisterTarget("Unspent talent points", function() return frame end,
    function() return QoL.Enabled("talentPoints") end,
    function(target)
        local point, _, _, x, y = target:GetPoint()
        QoL.Settings().talentPointsPos = { point = point, x = x, y = y }
    end)

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and QoL.Public(value) then return value end
end

-- Returns the reminder text, or nil when nothing is unspent.
local function ClassicCount()
    local count = Call(UnitCharacterPoints, "player")
    if type(count) ~= "number" then count = Call(GetUnspentTalentPoints) end
    if type(count) == "number" and count > 0 then
        return string.format("%d unspent talent point%s", count, count == 1 and "" or "s")
    end
end
function Points.Describe()
    -- Forever uses classic talent points even if the Retail API is present.
    if addon.Client and addon.Client.isForever then return ClassicCount() end
    local talents = C_ClassTalents
    if talents and talents.HasUnspentTalentPoints then
        local class = Call(talents.HasUnspentTalentPoints) == true
        local hero = Call(talents.HasUnspentHeroTalentPoints) == true
        if class and hero then return "Unspent talent and hero talent points" end
        if class then return "Unspent talent points" end
        if hero then return "Unspent hero talent points" end
        return nil
    end
    return ClassicCount()
end

local function Refresh()
    local text = QoL.Enabled("talentPoints") and not InCombatLockdown() and Points.Describe()
    if Layout() and QoL.Enabled("talentPoints") then text = text or "Unspent talent points" end
    frame.text:SetText(text or "")
    frame:SetShown(text and true or false)
end
Points.Refresh = Refresh

-- Talent/level events differ between clients; register only those this client has.
local watched = {}
for _, event in ipairs({ "PLAYER_LEVEL_UP", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "TRAIT_TREE_CURRENCY_INFO_UPDATED",
    "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "CHARACTER_POINTS_CHANGED", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    if not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event) then watched[#watched + 1] = event end
end
-- Talent data can update just after these events; check again a moment later.
local function OnEvent() Refresh(); C_Timer.After(1, Refresh) end

function Points.UpdateSettings()
    local db = QoL.Settings()
    local pos = db and db.talentPointsPos or { point = "TOP", x = 0, y = -160 }
    frame:ClearAllPoints()
    frame:SetPoint(pos.point or "TOP", UIParent, pos.point or "TOP", pos.x or 0, pos.y or -160)
    frame.text:SetFont("Fonts\\FRIZQT__.TTF", db and db.alertFontSize or 24, "OUTLINE")
    local enabled = QoL.Enabled("talentPoints")
    for _, event in ipairs(watched) do
        if enabled then addon.EventBus.Register(event, OnEvent, "TalentPoints") else addon.EventBus.Unregister(event, OnEvent) end
    end
    Refresh()
end
