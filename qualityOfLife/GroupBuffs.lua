-- Out of combat: lists group members missing one of YOUR buffs. Each class has an
-- editable list (UIThingsDB.qualityOfLife.groupBuffsList[CLASS], shared by every
-- character of that class) seeded with its class buff. Each entry is for "self"
-- (Mage Armor), "group" (Thorns, Arcane Intellect) or "tanks" (assigned tank role;
-- everyone when no tank is assigned). Pets are never checked. A buff counts by
-- name, so any rank matches; casts go by name, so the highest known rank is used.
-- A buff with less than groupBuffsRefresh minutes left counts as missing.
-- One row per member: an icon per missing buff (click to cast it on them) and the
-- name (click to cast their first missing buff). Rows are secure buttons, so the
-- list is made invisible in combat and refreshed when combat ends.
local _, addon = ...
local QoL = addon.QualityOfLife
local Buffs = {}
QoL.GroupBuffs = Buffs
QoL.AddModule(Buffs)

-- Starting list per class: first ID is the buff, the rest also count as it
-- (group versions such as Arcane Brilliance).
local CLASS_BUFFS = {
    MAGE = { 1459, 23028 },
    PRIEST = { 21562, 21564 },
    WARRIOR = { 6673 },
    DRUID = { 1126, 21849 },
    EVOKER = { 381748 },
    SHAMAN = { 462854 },
}
local ALSO = {}
for _, ids in pairs(CLASS_BUFFS) do
    for i = 2, #ids do
        ALSO[ids[1]] = ALSO[ids[1]] or {}
        table.insert(ALSO[ids[1]], ids[i])
    end
end
local MAX_ROWS = 10
local ROW_H = 24
local WHO = { "self", "solo", "group", "tanks" }

local frame = CreateFrame("Frame", nil, UIParent)
frame:SetSize(240, ROW_H)
frame:SetFrameStrata("HIGH")
frame:SetMovable(true)
frame:EnableMouse(false)
frame:Hide()
local rows = {}
-- Buffs just cast from the list, so they drop off at once instead of waiting
-- for the next poll (which let a quick second click cast them again).
local CAST_GRACE = 5
local clicked -- { unit, spell, at } from the last list click
local recent = {} -- [unit .. "\0" .. spell] = time the cast succeeded

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
-- Spell ID for a typed name or ID (nil when the client has no such spell).
local function LookupSpell(text)
    text = strtrim(tostring(text or ""))
    local id = tonumber(text)
    if id then return SpellName(id) and id or nil end
    if text == "" then return nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(text)
        return info and info.spellID
    end
    return select(7, GetSpellInfo(text))
end
-- Known by the player (any rank): spellbook lookups by name only find learned spells.
local function Known(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    local name = SpellName(id)
    if not name then return false end
    if C_Spell and C_Spell.GetSpellInfo then return C_Spell.GetSpellInfo(name) ~= nil end
    return GetSpellInfo(name) ~= nil
end

local function PlayerClass()
    local _, class = UnitClass("player")
    return class or "UNKNOWN"
end

-- This class's editable list ({ id, who, on }), seeded on first use.
function Buffs.List()
    local db = QoL.Settings()
    db.groupBuffsList = db.groupBuffsList or {}
    local class = PlayerClass()
    if not db.groupBuffsList[class] then
        local ids = CLASS_BUFFS[class]
        db.groupBuffsList[class] = ids and { { id = ids[1], who = "group", on = true } } or {}
    end
    return db.groupBuffsList[class]
end

function Buffs.RestoreDefaults()
    Buffs.List()
    QoL.Settings().groupBuffsList[PlayerClass()] = nil
    Buffs.List()
    Buffs.Refresh()
end

-- Adds a spell by name or ID. Returns true, or nil and a reason.
function Buffs.Add(text)
    local id = LookupSpell(text)
    if not id then return nil, "Unknown spell: " .. tostring(text) end
    local name = SpellName(id)
    for _, entry in ipairs(Buffs.List()) do
        if SpellName(entry.id) == name then return nil, name .. " is already on the list." end
    end
    -- Spells without range are self-only (armors, seals); others start as group buffs.
    local hasRange = C_Spell and C_Spell.SpellHasRange and C_Spell.SpellHasRange(id)
    if hasRange == nil and SpellHasRange then hasRange = SpellHasRange(name) end
    table.insert(Buffs.List(), { id = id, who = hasRange == false and "self" or "group", on = true })
    Buffs.Refresh()
    return true
end

function Buffs.Remove(index)
    table.remove(Buffs.List(), index)
    Buffs.Refresh()
end

-- Cycles self -> solo -> group -> tanks.
function Buffs.CycleWho(index)
    local entry = Buffs.List()[index]
    if not entry then return end
    for i, who in ipairs(WHO) do
        if entry.who == who then
            entry.who = WHO[i % #WHO + 1]
            break
        end
    end
    Buffs.Refresh()
end

function Buffs.SetOn(index, on)
    local entry = Buffs.List()[index]
    if entry then entry.on = on and true or false end
    Buffs.Refresh()
end

Buffs.SpellName = SpellName
Buffs.SpellIcon = SpellIcon

-- Enabled, known entries with resolved names: { names = set, cast, icon, who }.
local function ActiveBuffs()
    local active = {}
    for _, entry in ipairs(Buffs.List()) do
        local name = entry.on ~= false and SpellName(entry.id)
        if name and Known(entry.id) then
            local names = { [name] = true }
            for _, alt in ipairs(ALSO[entry.id] or {}) do
                local altName = SpellName(alt)
                if altName then names[altName] = true end
            end
            active[#active + 1] = { names = names, cast = name, icon = SpellIcon(entry.id), who = entry.who or "group" }
        end
    end
    return active
end

-- Helpful aura name -> { remaining seconds (math.huge if permanent), duration }.
local function UnitBuffs(unit)
    local found, now = {}, GetTime()
    for i = 1, 40 do
        local name, duration, expires
        local data = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if data then
            name, duration, expires = data.name, data.duration, data.expirationTime
        elseif UnitBuff then
            local _
            name, _, _, _, duration, expires = UnitBuff(unit, i)
        end
        if not name then break end
        if QoL.Public(name) then
            local left = math.huge
            if QoL.Public(expires) and type(expires) == "number" and expires > 0 then left = expires - now end
            local dur = QoL.Public(duration) and type(duration) == "number" and duration or 0
            local old = found[name]
            if not old or left > old.left then found[name] = { left = left, duration = dur } end
        end
    end
    return found
end

-- One buff by name (any rank): { left, duration } or nil. Asks the client
-- directly when it can (one lookup instead of scanning every buff on everyone in
-- a raid); otherwise falls back to a single scan of the unit, cached in scan[1].
local function FindBuff(unit, name, scan)
    local byName = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
    if not byName then
        scan[1] = scan[1] or UnitBuffs(unit)
        return scan[1][name]
    end
    local data = byName(unit, name, "HELPFUL")
    if not data then return nil end
    local duration, expires = data.duration, data.expirationTime
    local left = math.huge
    if QoL.Public(expires) and type(expires) == "number" and expires > 0 then left = expires - GetTime() end
    return { left = left, duration = QoL.Public(duration) and type(duration) == "number" and duration or 0 }
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

local function IsTank(unit)
    return UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) == "TANK"
end

-- Members missing at least one buff: { text, unit, buffs = { active entries } }.
-- Skips dead, offline and out-of-sight units.
function Buffs.MissingUnits()
    local active = ActiveBuffs()
    if #active == 0 then return {} end
    local units = {}
    for _, unit in ipairs(Units()) do
        if UnitExists(unit) and (unit == "player" or not UnitIsUnit(unit, "player")) and UnitIsConnected(unit)
            and not UnitIsDeadOrGhost(unit) and UnitIsVisible(unit) then
            units[#units + 1] = unit
        end
    end
    local anyTank = false
    for _, unit in ipairs(units) do
        if IsTank(unit) then anyTank = true end
    end
    local refresh = (QoL.Settings().groupBuffsRefresh or 0) * 60
    local missing = {}
    for _, unit in ipairs(units) do
        local scan = {}
        local lacking = {}
        for _, buff in ipairs(active) do
            -- "solo": only you, and only while not in a party or raid (e.g. Dampen Magic).
            local applies = buff.who == "group" or (buff.who == "self" and unit == "player")
                or (buff.who == "solo" and unit == "player" and not IsInGroup())
                or (buff.who == "tanks" and (not anyTank or IsTank(unit)))
            local cast = recent[unit .. "\0" .. buff.cast]
            if cast and GetTime() - cast < CAST_GRACE then applies = false end
            if applies then
                local best
                for name in pairs(buff.names) do
                    local aura = FindBuff(unit, name, scan)
                    if aura and (not best or aura.left > best.left) then best = aura end
                end
                -- Expiring soon counts as missing, unless the buff is shorter than the threshold.
                if not best or (refresh > 0 and best.duration > refresh and best.left < refresh) then
                    lacking[#lacking + 1] = buff
                end
            end
        end
        if #lacking > 0 then
            local name = addon.Secret.SafeUnitName(unit, "?")
            local _, class = UnitClass(unit)
            local color = class and C_ClassColor.GetClassColor(class)
            missing[#missing + 1] = { text = color and color:WrapTextInColorCode(name) or name, unit = unit, buffs = lacking }
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

local function SetCast(button, spell, unit)
    spell = spell or nil
    button:SetAttribute("type", spell and "spell" or nil)
    button:SetAttribute("spell", spell)
    button:SetAttribute("unit", spell and unit or nil)
end

-- Remembers which buff a list click is casting on whom; see OnCastSucceeded.
local function NoteClick(self)
    local spell, unit = self:GetAttribute("spell"), self:GetAttribute("unit")
    if spell and unit then clicked = { unit = unit, spell = spell, at = GetTime() } end
end
Buffs.NoteClick = NoteClick

local function IconTooltip(self)
    if not self.spell then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.spell)
    if self.who then GameTooltip:AddLine("Click to cast on " .. self.who, 1, 1, 1) end
    GameTooltip:Show()
end

local function Icon(row, j)
    if row.icons[j] then return row.icons[j] end
    local icon = CreateFrame("Button", nil, row, "SecureActionButtonTemplate")
    icon:RegisterForClicks("AnyUp", "AnyDown")
    icon:SetSize(ROW_H - 2, ROW_H - 2)
    icon:SetPoint("LEFT", (j - 1) * ROW_H, 0)
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    icon:HookScript("PostClick", NoteClick)
    icon:SetScript("OnEnter", IconTooltip)
    icon:SetScript("OnLeave", GameTooltip_Hide)
    row.icons[j] = icon
    return icon
end

local function Row(i)
    if rows[i] then return rows[i] end
    local row = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate")
    row:RegisterForClicks("AnyUp", "AnyDown")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:SetSize(240, ROW_H)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    row:HookScript("PostClick", NoteClick)
    row.icons = {}
    row.text = row:CreateFontString(nil, "OVERLAY")
    rows[i] = row
    return row
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
        local first = ActiveBuffs()[1]
        missing = { { text = "Missing members", buffs = { first or { icon = 134400 } } } }
    end
    local shown = math.min(#missing, MAX_ROWS)
    local size = db and db.alertFontSize or 24
    local width = 240
    for i = 1, shown do
        local row = Row(i)
        local entry = missing[i]
        local overflow = i == MAX_ROWS and #missing > MAX_ROWS
        local buffs = overflow and {} or entry.buffs
        for j, buff in ipairs(buffs) do
            local icon = Icon(row, j)
            icon.texture:SetTexture(buff.icon)
            icon.spell, icon.who = buff.cast, entry.unit and entry.text
            SetCast(icon, entry.unit and buff.cast, entry.unit)
            icon:Show()
        end
        for j = #buffs + 1, #row.icons do row.icons[j]:Hide() end
        row.text:SetFont(LunaUITweaksAPI.Style.Font(), math.max(12, size - 8), "OUTLINE")
        row.text:ClearAllPoints()
        row.text:SetPoint("LEFT", math.max(1, #buffs) * ROW_H + 4, 0)
        row.text:SetText(overflow and ("+" .. (#missing - MAX_ROWS + 1) .. " more") or entry.text)
        width = math.max(width, math.max(1, #buffs) * ROW_H + 8 + row.text:GetStringWidth())
        SetCast(row, entry.unit and not overflow and buffs[1] and buffs[1].cast, entry.unit)
        row:Show()
    end
    for i = shown + 1, #rows do rows[i]:Hide() end
    for i = 1, shown do rows[i]:SetWidth(width) end
    frame:SetSize(width, math.max(1, shown * ROW_H))
    frame:SetShown(shown > 0)
end
Buffs.Refresh = Refresh

local function OnCastSucceeded(_, _, _, spellID)
    if not clicked or GetTime() - clicked.at > CAST_GRACE then return end
    if not QoL.Public(spellID) or SpellName(spellID) ~= clicked.spell then return end
    recent[clicked.unit .. "\0" .. clicked.spell] = GetTime()
    clicked = nil
    Refresh()
end
Buffs.OnCastSucceeded = OnCastSucceeded

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
        addon.EventBus.RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", OnCastSucceeded, "GroupBuffs")
        if not ticker then ticker = C_Timer.NewTicker(2, Refresh) end
    else
        for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }) do
            addon.EventBus.Unregister(event, Refresh)
        end
        addon.EventBus.Unregister("UNIT_SPELLCAST_SUCCEEDED", OnCastSucceeded)
        if ticker then
            ticker:Cancel()
            ticker = nil
        end
    end
    Refresh()
end
