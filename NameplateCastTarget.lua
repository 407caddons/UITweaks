-- NameplateCastTarget.lua
-- Outlines the nameplate of an enemy while it is casting at you. Retail and
-- Forever. Settings in UIThingsDB.nameplateColors.castTarget.
--
-- UnitIsSpellTarget(unit, "player") says whether the unit's current cast is aimed
-- at the player; it may be a secret boolean in combat, so it drives the outline
-- through SetAlphaFromBoolean without ever being branched on. Ground-targeted and
-- area casts have no target and are never highlighted.
--
-- Taint safety: Blizzard nameplate frames are only read (to anchor). The outline
-- is an addon-owned, unprotected child frame of a non-forbidden plate. It sits
-- outside the quest-mark outline (NameplateQuestMarks.lua) so both can show.
local _, addon = ...
local Cast = {}
addon.NameplateCastTarget = Cast
local Public = addon.Secret.IsPublic

local OUTSET = 4 -- quest outline covers 1px outside the bar; ours starts 2px further out
local outlines = {} -- [plate] = frame (plates are pooled, never destroyed)

local function DB()
    local db = UIThingsDB and UIThingsDB.nameplateColors
    return db and db.castTarget
end
local function Enabled()
    local db = DB()
    return db and db.enabled and UnitIsSpellTarget ~= nil
end

local function PlateFor(unit)
    if not Public(unit) or type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end
    local forbidden = plate:IsForbidden()
    if not Public(forbidden) or forbidden then return end
    return plate
end

-- The plate's health bar, or the plate itself when it cannot be read.
local function BarOf(plate)
    local frame = plate.UnitFrame
    if type(frame) ~= "table" or not frame.IsForbidden then return plate end
    local forbidden = frame:IsForbidden()
    if not Public(forbidden) or forbidden then return plate end
    local bar = frame.HealthBarsContainer or frame.healthBar
    if type(bar) ~= "table" or not bar.GetObjectType then return plate end
    return bar
end

-- True while the unit has a cast or channel in progress. The spell name may be
-- secret in combat; a secret name still means a cast exists (nil is public).
local function IsCasting(unit)
    for _, info in ipairs({ UnitCastingInfo, UnitChannelInfo }) do
        local ok, name = pcall(info, unit)
        if ok and (not Public(name) or name ~= nil) then return true end
    end
    return false
end
Cast.IsCasting = IsCasting

-- UnitIsSpellTarget can still report the old target after a cast is kicked, so
-- a shown outline also hides itself as soon as its unit stops casting.
local function Watch(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < 0.2 then return end
    self.elapsed = 0
    if not self.unit or not IsCasting(self.unit) then self:Hide() end
end

local function GetOutline(plate)
    local outline = outlines[plate]
    if outline then return outline end
    outline = CreateFrame("Frame", nil, plate)
    outline.lines = {}
    for i = 1, 4 do outline.lines[i] = outline:CreateTexture(nil, "OVERLAY") end
    outline:SetScript("OnUpdate", Watch)
    outline:Hide()
    outlines[plate] = outline
    return outline
end

local function Place(outline, plate)
    local db = DB()
    local thickness = tonumber(db.thickness) or 3
    local top, bottom, left, right = unpack(outline.lines)
    for _, line in ipairs(outline.lines) do line:ClearAllPoints() end
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(thickness)
    bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(thickness)
    left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(thickness)
    right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(thickness)
    local c = db.color or {}
    for _, line in ipairs(outline.lines) do line:SetColorTexture(c.r or 1, c.g or 0.15, c.b or 0.15, 1) end
    local bar = BarOf(plate)
    local out = OUTSET + thickness - 1
    outline:ClearAllPoints()
    -- Anchoring to Blizzard's bar only reads it; fall back to the plate if refused.
    local placed = pcall(outline.SetPoint, outline, "TOPLEFT", bar, "TOPLEFT", -out, out)
    placed = placed and pcall(outline.SetPoint, outline, "BOTTOMRIGHT", bar, "BOTTOMRIGHT", out, -out)
    if not placed then
        outline:ClearAllPoints()
        outline:SetAllPoints(plate)
    end
    local ok, level = pcall(bar.GetFrameLevel, bar)
    if ok and Public(level) and type(level) == "number" then outline:SetFrameLevel(level + 4) end
end

local function Hide(unit)
    local plate = PlateFor(unit)
    if plate and outlines[plate] then outlines[plate]:Hide() end
end

-- Shows the outline when this unit's current cast targets the player.
local function Update(unit)
    local plate = PlateFor(unit)
    if not plate then return end
    if not Enabled() then
        if outlines[plate] then outlines[plate]:Hide() end
        return
    end
    -- Hostile casters only: friendly plates casting heals at you stay plain.
    local ok, hostile = pcall(UnitCanAttack, "player", unit)
    if ok and Public(hostile) and not hostile then
        if outlines[plate] then outlines[plate]:Hide() end
        return
    end
    local readOk, targeted = pcall(UnitIsSpellTarget, unit, "player")
    if not readOk or not IsCasting(unit) then
        if outlines[plate] then outlines[plate]:Hide() end
        return
    end
    local outline = GetOutline(plate)
    outline.unit = unit
    Place(outline, plate)
    if Public(targeted) then
        outline:SetAlpha(1)
        outline:SetShown(targeted == true)
    elseif outline.SetAlphaFromBoolean then
        outline:Show()
        outline:SetAlphaFromBoolean(targeted, 1, 0)
    else
        outline:Hide()
    end
end

local START = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_TARGET", "NAME_PLATE_UNIT_ADDED" }
local STOP = { "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_STOP",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED", "NAME_PLATE_UNIT_REMOVED" }
-- Empower events exist on Retail only; registering an unknown event errors.
local function Valid(event)
    return not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event)
end
local function OnStart(_, unit) Update(unit) end
local function OnStop(_, unit) Hide(unit) end

-- Spell-cast events fire for every unit token; nameplate tokens are filtered in
-- PlateFor (the same events also fire under each enemy's nameplate token).
local registered = false
local function SyncEvents()
    local want = Enabled() and true or false
    if want == registered then return end
    registered = want
    local bus = addon.EventBus
    for _, event in ipairs(START) do
        if not Valid(event) then
        elseif want then bus.Register(event, OnStart, "NameplateCastTarget") else bus.Unregister(event, OnStart) end
    end
    for _, event in ipairs(STOP) do
        if not Valid(event) then
        elseif want then bus.Register(event, OnStop, "NameplateCastTarget") else bus.Unregister(event, OnStop) end
    end
end

function Cast.UpdateSettings()
    SyncEvents()
    for _, outline in pairs(outlines) do outline:Hide() end
    if Enabled() and C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            local unit = plate.namePlateUnitToken
            if Public(unit) and unit then Update(unit) end
        end
    end
end

addon.EventBus.Register("PLAYER_LOGIN", Cast.UpdateSettings, "NameplateCastTarget")
