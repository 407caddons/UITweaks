-- Externals and group defensive cooldowns on you, for tanks. Blizzard's aura
-- containers select and render the auras; addon Lua never reads aura data.
-- Row 1 uses Blizzard's EXTERNAL_DEFENSIVE category, which Blizzard keeps up
-- to date each patch. Row 2 lists group cooldowns outside that category
-- (filtered with !EXTERNAL_DEFENSIVE so nothing appears twice), plus any
-- spell IDs the user adds.
local _, addon = ...
local Ext = {}
addon.TankExternals = Ext
local display, unavailable, pending = nil, nil, false

-- Buff IDs as they appear on the protected player (Midnight). Externals are
-- repeated here as a backstop in case Blizzard's category misses one; the
-- !EXTERNAL_DEFENSIVE filter keeps them out of this row when it does not.
Ext.GROUP_COOLDOWNS = {
    { 325174, "Spirit Link Totem" },
    { 207498, "Ancestral Protection Totem" },
    { 201633, "Earthen Wall Totem" },
    { 81782,  "Power Word: Barrier" },
    { 145629, "Anti-Magic Zone" },
    { 31821,  "Aura Mastery" },
    { 97463,  "Rallying Cry" },
    { 209426, "Darkness" },
    { 374227, "Zephyr" },
    { 33206,  "Pain Suppression" },
    { 47788,  "Guardian Spirit" },
    { 102342, "Ironbark" },
    { 116849, "Life Cocoon" },
    { 6940,   "Blessing of Sacrifice" },
    { 1022,   "Blessing of Protection" },
    { 204018, "Blessing of Spellwarding" },
    { 357170, "Time Dilation" },
    { 114030, "Vigilance" },
    { 147833, "Intervene" },
}

local ROWS = {
    { key = "externals", setting = "showExternals", filter = "HELPFUL|EXTERNAL_DEFENSIVE" },
    { key = "cooldowns", setting = "showCooldowns", filter = "HELPFUL|!EXTERNAL_DEFENSIVE" },
}

local function DB() return UIThingsDB and UIThingsDB.tankExternals end
local function Editing() return addon.LayoutMode and addon.LayoutMode.IsActive() end
function Ext.GetStatus() return unavailable end

-- Built-in group cooldowns plus the user's comma/space separated spell IDs.
function Ext.SpellSet()
    local set = {}
    for _, entry in ipairs(Ext.GROUP_COOLDOWNS) do set[entry[1]] = true end
    for id in tostring(DB() and DB().extraSpellIDs or ""):gmatch("%d+") do
        id = tonumber(id)
        if id and id > 0 then set[id] = true end
    end
    return set
end
local function Filters(row)
    if row.key == "cooldowns" then return { includeSpellIDs = Ext.SpellSet() } end
    return {}
end
local function Layout(s) return { elementWidth = s.iconSize, elementHeight = s.iconSize, elementSpacing = 4 } end

local function CreateDisplay()
    local s = DB()
    local frame = CreateFrame("Frame", "LunaTankExternals", UIParent)
    frame:SetFrameStrata("MEDIUM"); frame:SetMovable(true); frame:SetClampedToScreen(true)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "LunaFontNormalSmall")
    frame.title:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 4)
    frame.title:SetText("Externals on you")
    frame.rows = {}
    for _, row in ipairs(ROWS) do
        local ok, container = pcall(CreateFrame, "AuraContainer", nil, frame, "CustomAuraContainerTemplate")
        if not ok then frame:Hide(); unavailable = "Requires Blizzard's 12.1 AuraContainer API."; return end
        container:SetEnabled(false)
        container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
        container:SetFlowLayoutAnchorPoint("TOPLEFT")
        container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
        local added = pcall(container.AddAuraGroup, container, row.key, row.filter, {
            maxFrameCount = s.maxIcons,
            initializeFrame = function(aura) addon.TankDebuffs.InitializeAura(aura, DB()) end,
            sortMethod = Enum.UnitAuraSortRule.ExpirationOnly,
            sortDirection = Enum.UnitAuraSortDirection.Normal,
            candidateFilters = Filters(row),
            layout = Layout(s),
        })
        if not added then frame:Hide(); unavailable = "This client does not support the external defensive aura filter."; return end
        frame.rows[row.key] = container
    end
    display = frame
    return frame
end

local function Wanted()
    local s = DB()
    if not s or not s.enabled or not IsInGroup() then return false end
    return not s.onlyTanking or UnitGroupRolesAssigned("player") == "TANK"
end

-- Unit and enabled setters are the supported in-combat container interface.
local function UpdateUnits()
    if not display then return end
    local s, show = DB(), Wanted()
    for _, row in ipairs(ROWS) do
        local container = display.rows[row.key]
        if not display.unitSet then container:SetUnit("player") end
        container:SetEnabled(show and s[row.setting] and not Editing() or false)
    end
    display.unitSet = true
    display:SetShown(show or (Editing() and s.enabled) or false)
end
Ext.RefreshUnits = UpdateUnits

function Ext.UpdateSettings()
    local s = DB()
    if not s then return end
    if InCombatLockdown() then pending = true; return end
    pending = false
    if s.enabled and not display and not unavailable then CreateDisplay() end
    if not display then return end
    display:ClearAllPoints(); display:SetPoint("TOPLEFT", UIParent, "CENTER", s.x, s.y)
    local rowWidth = s.maxIcons * s.iconSize + (s.maxIcons - 1) * 4
    local y, shownRows = 0, 0
    for _, row in ipairs(ROWS) do
        local container = display.rows[row.key]
        container:ClearAllPoints(); container:SetPoint("TOPLEFT", display, "TOPLEFT", 0, y)
        container:SetAuraGroupMaxFrameCount(row.key, s.maxIcons)
        container:SetAuraGroupCandidateFilters(row.key, Filters(row))
        container:SetAuraGroupLayout(row.key, Layout(s))
        for i = 1, container:GetAuraGroupFrameCount(row.key) do
            local aura = container:GetAuraGroupFrame(row.key, i)
            if aura:CanBeAccessedInContext() then addon.TankDebuffs.StyleAura(aura, s) end
        end
        if s[row.setting] then
            y = y - s.iconSize - 4
            shownRows = shownRows + 1
        end
    end
    display:SetSize(rowWidth, math.max(1, shownRows) * (s.iconSize + 4) - 4)
    UpdateUnits()
end

addon.LayoutMode.RegisterTarget("Externals on you", function() return display end,
    function() return DB() and DB().enabled end,
    function(frame)
        local x, y = frame:GetLeft(), frame:GetTop()
        local cx, cy = UIParent:GetCenter()
        DB().x = math.floor(x - cx + .5); DB().y = math.floor(y - cy + .5)
        Ext.UpdateSettings()
    end)
addon.LayoutMode.RegisterModule("TankExternals", {
    apply = function() Ext.UpdateSettings() end,
    combatLocked = function() Ext.RefreshUnits() end,
})
addon.EventBus.Register("PLAYER_LOGIN", Ext.UpdateSettings, "TankExternals")
addon.EventBus.Register("PLAYER_REGEN_ENABLED", function()
    if pending then Ext.UpdateSettings() else UpdateUnits() end
end, "TankExternals")
for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED" }) do
    addon.EventBus.Register(event, UpdateUnits, "TankExternals")
end
