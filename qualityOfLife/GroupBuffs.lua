-- Out of combat: lists group members missing YOUR class buff (Arcane Intellect,
-- Power Word: Fortitude, Battle Shout, ...). Clicking a name casts the buff on that
-- member through a secure button; the list is made invisible in combat (secure
-- frames cannot be shown or hidden then) and refreshed when combat ends.
local _, addon = ...
local QoL = addon.QualityOfLife
local Buffs = {}
QoL.GroupBuffs = Buffs
QoL.AddModule(Buffs)

-- Spell IDs per class; every ID's name counts as the buff (single-target and group versions).
local CLASS_BUFFS = {
    MAGE = { 1459, 23028 },
    PRIEST = { 21562, 21564 },
    WARRIOR = { 6673 },
    DRUID = { 1126, 21849 },
    EVOKER = { 381748 },
    SHAMAN = { 462854 },
}
local MAX_ROWS = 10
local ROW_H = 24

local frame = CreateFrame("Frame", nil, UIParent)
frame:SetSize(240, ROW_H)
frame:SetFrameStrata("HIGH")
frame:SetMovable(true)
frame:EnableMouse(false)
frame:Hide()
local rows = {}

addon.LayoutMode.RegisterTarget("Missing class buffs", function() return frame end,
    function() return QoL.Enabled("groupBuffs") end,
    function(target)
        local point, _, _, x, y = target:GetPoint()
        QoL.Settings().groupBuffsPos = { point = point, x = x, y = y }
    end)

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return (GetSpellInfo(id))
end
local function SpellIcon(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    return select(3, GetSpellInfo(id))
end

local names, icon, castName
local function Resolve()
    local _, class = UnitClass("player")
    local ids = CLASS_BUFFS[class]
    if not ids then return nil end
    if not names then
        names = {}
        for _, id in ipairs(ids) do
            local name = SpellName(id)
            if name then names[name] = true end
        end
        icon = SpellIcon(ids[1])
        castName = SpellName(ids[1]) -- by name, so the highest known rank is cast
    end
    return names
end

local function HasBuff(unit, wanted)
    for i = 1, 40 do
        local data = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        local name
        if data then
            name = data.name
        elseif UnitBuff then
            name = UnitBuff(unit, i)
        end
        if not name then return false end
        if QoL.Public(name) and wanted[name] then return true end
    end
    return false
end

local function Row(i)
    if rows[i] then return rows[i] end
    local row = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate")
    row:RegisterForClicks("AnyUp", "AnyDown")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:SetSize(240, ROW_H)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_H - 2, ROW_H - 2)
    row.icon:SetPoint("LEFT")
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.text = row:CreateFontString(nil, "OVERLAY")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    rows[i] = row
    return row
end

local function Units()
    local list = { "player" }
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do list[#list + 1] = "raid" .. i end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do list[#list + 1] = "party" .. i end
    end
    return list
end

-- Members lacking the buff as { text = class-coloured name, unit = unit token };
-- skips dead, offline and out-of-sight units.
function Buffs.MissingUnits()
    local wanted = Resolve()
    if not wanted then return {} end
    local missing = {}
    for _, unit in ipairs(Units()) do
        if UnitExists(unit) and (unit == "player" or not UnitIsUnit(unit, "player")) and UnitIsConnected(unit)
            and not UnitIsDeadOrGhost(unit) and UnitIsVisible(unit) and not HasBuff(unit, wanted) then
            local name = addon.Secret.SafeUnitName(unit, "?")
            local _, class = UnitClass(unit)
            local color = class and C_ClassColor.GetClassColor(class)
            missing[#missing + 1] = { text = color and color:WrapTextInColorCode(name) or name, unit = unit }
        end
    end
    return missing
end

-- Class-coloured names only.
function Buffs.Missing()
    local names = {}
    for i, entry in ipairs(Buffs.MissingUnits()) do names[i] = entry.text end
    return names
end

-- Aura reads are blocked while auras are secret (combat, encounters, M+ keys);
-- check first so the blocked call is never made.
local function AurasReadable()
    if InCombatLockdown() then return false end
    local secrets = C_Secrets
    if secrets and secrets.ShouldAurasBeSecret and secrets.ShouldAurasBeSecret() then return false end
    return true
end

local function Refresh()
    -- Secure rows cannot be shown/hidden in combat (Hide() is blocked); make the
    -- list invisible instead and reconcile when combat ends.
    if InCombatLockdown() then
        frame:SetAlpha(0)
        return
    end
    frame:SetAlpha(1)
    local db = QoL.Settings()
    local missing = QoL.Enabled("groupBuffs") and AurasReadable() and Buffs.MissingUnits() or {}
    if QoL.Enabled("groupBuffs") and addon.LayoutMode.IsActive() and #missing == 0 then
        Resolve()
        missing = { { text = "Missing members" } }
    end
    local shown = math.min(#missing, MAX_ROWS)
    local size = db and db.alertFontSize or 24
    for i = 1, shown do
        local row = Row(i)
        local entry = missing[i]
        local overflow = i == MAX_ROWS and #missing > MAX_ROWS
        row.icon:SetTexture(icon)
        row.text:SetFont(LunaUITweaksAPI.Style.Font(), math.max(12, size - 8), "OUTLINE")
        row.text:SetText(overflow and ("+" .. (#missing - MAX_ROWS + 1) .. " more") or entry.text)
        if entry.unit and castName and not overflow then
            row:SetAttribute("type", "spell")
            row:SetAttribute("spell", castName)
            row:SetAttribute("unit", entry.unit)
        else
            row:SetAttribute("type", nil)
            row:SetAttribute("spell", nil)
            row:SetAttribute("unit", nil)
        end
        row:Show()
    end
    for i = shown + 1, #rows do rows[i]:Hide() end
    frame:SetHeight(math.max(1, shown * ROW_H))
    frame:SetShown(shown > 0)
end
Buffs.Refresh = Refresh

local ticker
function Buffs.UpdateSettings()
    local db = QoL.Settings()
    local pos = db and db.groupBuffsPos or { point = "CENTER", x = -300, y = 150 }
    -- Rows are secure, so the list cannot be re-anchored during combat.
    if not InCombatLockdown() then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or -300, pos.y or 150)
    end
    if QoL.Enabled("groupBuffs") then
        for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }) do
            addon.EventBus.Register(event, Refresh, "GroupBuffs")
        end
        -- Aura changes on other members: a light poll beats listening to every UNIT_AURA.
        if not ticker then ticker = C_Timer.NewTicker(2, Refresh) end
    else
        for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }) do
            addon.EventBus.Unregister(event, Refresh)
        end
        if ticker then
            ticker:Cancel()
            ticker = nil
        end
    end
    Refresh()
end
