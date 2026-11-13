-- NameplateQuestMarks.lua
-- A kill/loot icon and "3/8" progress beside nameplates of units that belong to
-- an unfinished objective of an active quest. Retail and Forever.
--
-- Taint safety:
--   * Blizzard nameplate frames are only read (to anchor), never modified. The
--     marker is an addon-owned, unprotected child frame of a non-forbidden plate.
--   * Tooltip quest lines are secret inside instances. Every value is checked
--     with Secret.IsPublic before it is compared or used, and the read is wrapped
--     in pcall as a backstop. When the lines cannot be read, the yes/no
--     C_QuestLog.UnitIsRelatedToActiveQuest result drives the marker through
--     SetAlphaFromBoolean, which accepts a secret boolean without branching on it.
local _, addon = ...
local Marks = {}
addon.NameplateQuestMarks = Marks
local Public = addon.Secret.IsPublic

local KILL_ATLAS, LOOT_ATLAS = "Crosshair_Attack_32", "Crosshair_pickup_32"
-- point on the marker, point on the bar, x direction, text side
local ANCHORS = {
    RIGHT = { "LEFT", "RIGHT", 1, "RIGHT" },
    LEFT  = { "RIGHT", "LEFT", -1, "LEFT" },
    TOP   = { "BOTTOM", "TOP", 0, "RIGHT" },
}
local markers = {} -- [plate] = marker frame (plates are pooled, never destroyed)

local function DB()
    local db = UIThingsDB and UIThingsDB.nameplateColors
    return db and db.questMarks
end

-- "3/8 Boar slain" (count first) or "Sanglier tués : 3/8" (count last).
local function CountOf(text)
    local have, need = text:match("^%s*(%d+)%s*/%s*(%d+)")
    if not have then have, need = text:match("(%d+)%s*/%s*(%d+)%s*$") end
    return tonumber(have), tonumber(need)
end
Marks.CountOf = CountOf

-- Returns unfinished, progress text. Counted objectives give "3/8"; progress-bar
-- objectives (world quests, bonus objectives: "Creatures slain (35%)") give "35%".
local function ProgressOf(text)
    local have, need = CountOf(text)
    if have and need then return have < need, have .. "/" .. need end
    local percent = tonumber(text:match("(%d+)%s*%%"))
    if percent then return percent < 100, percent .. "%" end
    return true, ""
end
Marks.ProgressOf = ProgressOf

-- Objective text without the count or percentage, spaces or punctuation, so the
-- tooltip line and the quest objective compare equal whatever their formatting.
local function Bare(text)
    return (text:gsub("%d+%s*/%s*%d+", ""):gsub("%d+%s*%%", ""):gsub("[%p%s]", ""):lower())
end

-- Unfinished objectives of the quest log, cached until the log changes:
-- bare text -> "monster" / "item" / ..., plus counts per kind on this map.
local objectives, kindCounts
local function AddObjectives(questID, onMap)
    for _, objective in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
        local text, kind = objective.text, objective.type
        if not objective.finished and Public(text) and Public(kind) and type(text) == "string" then
            objectives[Bare(text)] = kind
            if onMap and kindCounts[kind] then kindCounts[kind] = kindCounts[kind] + 1 end
        end
    end
end

local function BuildObjectives()
    objectives, kindCounts = {}, { monster = 0, item = 0 }
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetQuestObjectives) then return end
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then
            AddObjectives(info.questID, info.isOnMap)
        end
    end
    -- Active world quests and bonus objectives are task quests, not quest log
    -- entries: add the ones on the current map so their kill/loot type is known.
    if C_TaskQuest and C_TaskQuest.GetQuestsOnMap and C_Map and C_Map.GetBestMapForUnit then
        local mapID = C_Map.GetBestMapForUnit("player")
        local ok, tasks = pcall(C_TaskQuest.GetQuestsOnMap, mapID)
        if mapID and ok and type(tasks) == "table" then
            for _, task in ipairs(tasks) do
                local questID = type(task) == "table" and (task.questID or task.questId)
                if Public(questID) and type(questID) == "number"
                    and (not C_TaskQuest.IsActive or C_TaskQuest.IsActive(questID)) then
                    AddObjectives(questID, true)
                end
            end
        end
    end
end

local function AtlasForKind(kind)
    return kind == "monster" and KILL_ATLAS or LOOT_ATLAS
end

-- When the objective cannot be read (instances): kill if every unfinished
-- objective on this map is a kill objective, else loot.
local function GuessAtlas()
    if not objectives then BuildObjectives() end
    if kindCounts.monster > 0 and kindCounts.item == 0 then return KILL_ATLAS end
    return LOOT_ATLAS
end

-- Returns readable, atlas, progress. readable=false when the tooltip lines are
-- secret or unavailable; atlas=nil when the unit has no unfinished objective.
local function ReadObjective(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return false end
    local objectiveType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective
    if not objectiveType then return false end
    local data = C_TooltipInfo.GetUnit(unit)
    if not Public(data) or type(data) ~= "table" then return false end
    local lines = data.lines
    if not Public(lines) or type(lines) ~= "table" then return false end
    if not objectives then BuildObjectives() end
    for _, line in ipairs(lines) do
        if not Public(line) or type(line) ~= "table" then return false end
        if TooltipUtil and TooltipUtil.SurfaceArgs then TooltipUtil.SurfaceArgs(line) end
        local lineType, text = line.type, line.leftText
        if not Public(lineType) or not Public(text) then return false end
        if lineType == objectiveType and type(text) == "string" then
            local unfinished, progress = ProgressOf(text)
            if unfinished then
                return true, AtlasForKind(objectives[Bare(text)]), progress
            end
        end
    end
    return true
end

-- The plate's health bar (falls back to the plate) and, on Forever, the level
-- badge Blizzard places right of the bar when it is shown.
local function AnchorsOf(plate)
    local frame = plate.UnitFrame
    if type(frame) ~= "table" or not frame.IsForbidden then return plate end
    local forbidden = frame:IsForbidden()
    if not Public(forbidden) or forbidden then return plate end
    local bar = frame.HealthBarsContainer or frame.healthBar
    if type(bar) ~= "table" or not bar.GetObjectType then bar = plate end
    local badge = frame.PlayerLevelDiffFrame
    if type(badge) == "table" and badge.IsShown then
        local ok, shown = pcall(badge.IsShown, badge)
        if not (ok and Public(shown) and shown == true) then badge = nil end
    else
        badge = nil
    end
    return bar, badge
end

-- Quest-mob outline: Luna's own textures drawn over the health bar's border.
-- Blizzard's border is never recoloured, so non-quest plates keep the default
-- and the bar fill keeps its threat colour.
local BORDER_THICKNESS, BORDER_OUTSET = 2, 1
-- Blizzard's nameplate border (NamePlateFullBorderTemplate on Forever/classic
-- plates): a frame on the health bar with Top/Bottom/Left/Right edge textures,
-- which can sit a few pixels outside the bar. Returns them in our line order.
local function BlizzardBorderEdges(bar)
    local border = bar and bar.border
    if type(border) ~= "table" or (border.IsForbidden and border:IsForbidden()) then return end
    local edges = { border.Top, border.Bottom, border.Left, border.Right }
    for i = 1, 4 do
        if type(edges[i]) ~= "table" or not edges[i].GetObjectType then return end
    end
    return edges
end
-- Default lines: a frame-relative outline. With Blizzard edges: each line
-- covers its matching edge exactly, so only one (quest-coloured) border shows.
local function LayoutLines(border, edges)
    local lines = border.lines
    local top, bottom, left, right = lines[1], lines[2], lines[3], lines[4]
    for i, line in ipairs(border.lines) do
        line:ClearAllPoints()
        if edges and pcall(line.SetAllPoints, line, edges[i]) then
            border.onBlizzardEdges = true
        else
            edges = nil
        end
    end
    if edges then return true end
    border.onBlizzardEdges = false
    for _, line in ipairs(border.lines) do line:ClearAllPoints() end
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(BORDER_THICKNESS)
    bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(BORDER_THICKNESS)
    left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(BORDER_THICKNESS)
    right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(BORDER_THICKNESS)
    return false
end
local function PlaceBorder(border, bar, plate, db)
    border:ClearAllPoints()
    LayoutLines(border, BlizzardBorderEdges(bar))
    local placed = pcall(border.SetPoint, border, "TOPLEFT", bar, "TOPLEFT", -BORDER_OUTSET, BORDER_OUTSET)
    placed = placed and pcall(border.SetPoint, border, "BOTTOMRIGHT", bar, "BOTTOMRIGHT", BORDER_OUTSET, -BORDER_OUTSET)
    if not placed then
        border:ClearAllPoints()
        border:SetAllPoints(plate)
    end
    -- Draw above the bar so the outline covers its edge.
    local ok, level = pcall(bar.GetFrameLevel, bar)
    if ok and Public(level) and type(level) == "number" then border:SetFrameLevel(level + 3) end
    local c = db.borderColor or {}
    for _, line in ipairs(border.lines) do
        line:SetColorTexture(c.r or 1, c.g or 0.82, c.b or 0, c.a or 1)
    end
end

local function Place(marker, plate, db)
    local spec = ANCHORS[db.anchor] or ANCHORS.RIGHT
    local bar, badge = AnchorsOf(plate)
    -- The marker frame is the shown/hidden quest state; icon and outline are optional parts.
    local showIcon = db.icon ~= false
    marker.tex:SetShown(showIcon)
    marker.text:SetShown(showIcon)
    marker.border:SetShown(db.border ~= false)
    if db.border ~= false then PlaceBorder(marker.border, bar, plate, db) end
    local relative = (spec[1] == "LEFT" and badge) or bar
    local size = tonumber(db.size) or 20
    marker:SetSize(size, size)
    marker:ClearAllPoints()
    -- Anchoring to Blizzard's bar only reads it; fall back to the plate if refused.
    if not pcall(marker.SetPoint, marker, spec[1], relative, spec[2], spec[3] * 4, 0) then
        marker:ClearAllPoints()
        marker:SetPoint(spec[1], plate, spec[2], spec[3] * 4, 0)
    end
    marker.text:ClearAllPoints()
    if spec[4] == "LEFT" then
        marker.text:SetPoint("RIGHT", marker, "LEFT", -2, 0)
    else
        marker.text:SetPoint("LEFT", marker, "RIGHT", 2, 0)
    end
end

local function GetMarker(plate)
    local marker = markers[plate]
    if marker then return marker end
    marker = CreateFrame("Frame", nil, plate)
    marker.tex = marker:CreateTexture(nil, "OVERLAY")
    marker.tex:SetAllPoints()
    marker.text = marker:CreateFontString(nil, "OVERLAY", "LunaFontNormalSmall")
    -- Outline: a child of the marker so it shares the marker's quest visibility.
    local border = CreateFrame("Frame", nil, marker)
    local top, bottom = border:CreateTexture(nil, "OVERLAY"), border:CreateTexture(nil, "OVERLAY")
    local left, right = border:CreateTexture(nil, "OVERLAY"), border:CreateTexture(nil, "OVERLAY")
    border.lines = { top, bottom, left, right }
    LayoutLines(border)
    marker.border = border
    marker:Hide()
    markers[plate] = marker
    return marker
end

local function Suppressed(db)
    if not db or not db.enabled then return true end
    if db.hideInInstances then
        local inInstance, instanceType = IsInInstance()
        if inInstance and instanceType ~= "none" then return true end
    end
    return false
end

local function PlateFor(unit)
    if not Public(unit) or type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end
    local forbidden = plate:IsForbidden()
    if not Public(forbidden) or forbidden then return end
    return plate
end

local function Update(unit)
    local plate = PlateFor(unit)
    if not plate then return end
    local db = DB()
    if Suppressed(db) then
        if markers[plate] then markers[plate]:Hide() end
        return
    end
    local isPlayer = UnitIsPlayer(unit)
    if not Public(isPlayer) or isPlayer then
        if markers[plate] then markers[plate]:Hide() end
        return
    end

    local marker = GetMarker(plate)
    Place(marker, plate, db)
    local ok, readable, atlas, progress = pcall(ReadObjective, unit)
    if ok and readable then
        marker:SetAlpha(1)
        if atlas then
            marker.tex:SetAtlas(atlas)
            marker.text:SetText(db.progress and progress or "")
            marker:Show()
        else
            marker:Hide()
        end
        return
    end

    -- Tooltip lines unreadable (instances): yes/no from the quest log, no progress.
    local related
    if C_QuestLog.UnitIsRelatedToActiveQuest then
        local relatedOk, value = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
        if relatedOk then related = value end
    end
    marker.tex:SetAtlas(GuessAtlas())
    marker.text:SetText("")
    if Public(related) then
        marker:SetAlpha(1)
        marker:SetShown(related == true)
    elseif marker.SetAlphaFromBoolean then
        marker:Show()
        marker:SetAlphaFromBoolean(related, 1, 0)
    else
        marker:Hide()
    end
end

local function UpdateAll()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.namePlateUnitToken
        if Public(unit) and unit then Update(unit) end
    end
end

-- Quest log updates arrive in bursts; refresh all plates once per frame.
local refreshFrame = CreateFrame("Frame")
refreshFrame:Hide()
refreshFrame:SetScript("OnUpdate", function(self)
    self:Hide()
    UpdateAll()
end)
local function QueueRefresh() refreshFrame:Show() end

local function OnQuestLogChanged()
    objectives = nil
    QueueRefresh()
end

local function OnPlateAdded(_, unit) Update(unit) end

local function OnPlateRemoved(_, unit)
    if not Public(unit) or type(unit) ~= "string" then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if plate and markers[plate] then markers[plate]:Hide() end
end

local registered = false
local function SyncEvents()
    local want = DB() and DB().enabled and true or false
    if want == registered then return end
    registered = want
    local bus = addon.EventBus
    if want then
        bus.Register("NAME_PLATE_UNIT_ADDED", OnPlateAdded, "NameplateQuestMarks")
        bus.Register("NAME_PLATE_UNIT_REMOVED", OnPlateRemoved, "NameplateQuestMarks")
        bus.Register("QUEST_LOG_UPDATE", OnQuestLogChanged, "NameplateQuestMarks")
        bus.Register("PLAYER_ENTERING_WORLD", OnQuestLogChanged, "NameplateQuestMarks")
        -- World quests on the new map join the objective lookup
        bus.Register("ZONE_CHANGED_NEW_AREA", OnQuestLogChanged, "NameplateQuestMarks")
        bus.RegisterUnitEvent("UNIT_QUEST_LOG_CHANGED", "player", OnQuestLogChanged, "NameplateQuestMarks")
    else
        bus.Unregister("NAME_PLATE_UNIT_ADDED", OnPlateAdded)
        bus.Unregister("NAME_PLATE_UNIT_REMOVED", OnPlateRemoved)
        bus.Unregister("QUEST_LOG_UPDATE", OnQuestLogChanged)
        bus.Unregister("PLAYER_ENTERING_WORLD", OnQuestLogChanged)
        bus.Unregister("ZONE_CHANGED_NEW_AREA", OnQuestLogChanged)
        bus.UnregisterUnitEvent("UNIT_QUEST_LOG_CHANGED", "player", OnQuestLogChanged)
    end
end

function Marks.UpdateSettings()
    SyncEvents()
    objectives = nil
    if DB() and DB().enabled then
        UpdateAll()
    else
        for _, marker in pairs(markers) do marker:Hide() end
    end
end

addon.EventBus.Register("PLAYER_LOGIN", Marks.UpdateSettings, "NameplateQuestMarks")
