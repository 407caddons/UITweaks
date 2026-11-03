local _, addon = ...
local Colors = {}
addon.NameplateColors = Colors

local Public = addon.Secret.IsPublic
local function Enabled()
    return UIThingsDB and UIThingsDB.nameplateColors and UIThingsDB.nameplateColors.enabled
end

-- No target-of-target guesses: a mob can target someone temporarily while a
-- tank still holds threat. Status 2/3 means that unit is actually tanking.
local function HasThreat(unit, enemy)
    if not UnitThreatSituation then return nil end
    local status = UnitThreatSituation(unit, enemy)
    if not Public(status) then return nil end
    return type(status) == "number" and status >= 2
end

-- Returns holding (true/false), uncertain (true when role or threat is unreadable).
local function CheckTank(token, enemy)
    local role = UnitGroupRolesAssigned(token)
    if token == "player" and (not Public(role) or role == nil or role == "NONE") then
        -- Only infer our own role. Other group members retain assigned roles.
        -- Forever's talent trees do not expose Retail specialisations.
        if not (addon.Client and addon.Client.isForever) then
            local specAPI = C_SpecializationInfo
            local getSpec = specAPI and specAPI.GetSpecialization or GetSpecialization
            local getInfo = specAPI and specAPI.GetSpecializationInfo or GetSpecializationInfo
            if getSpec and getInfo then
                local index = getSpec()
                if Public(index) and type(index) == "number" and index > 0 then
                    local _, _, _, _, specRole = getInfo(index)
                    if not Public(specRole) or specRole == "TANK" or specRole == "HEALER" or specRole == "DAMAGER" then
                        role = specRole
                    end
                end
            end
        end
    end
    if not Public(role) then return false, true end
    if role ~= "TANK" then return false, false end
    local holding = HasThreat(token, enemy)
    if holding == nil then return false, true end
    return holding, false
end

-- Group members that could be "another tank": assigned tanks, plus members
-- whose role or identity is unreadable (they must still count as uncertain).
-- Members with a readable non-tank role can never change the result, so they
-- are skipped. Rebuilt on roster, role and spec changes.
local candidates = {}
local candidatesDirty = true
local function RebuildCandidates()
    candidatesDirty = false
    wipe(candidates)
    local prefix, count = "party", GetNumSubgroupMembers()
    if IsInRaid() then prefix, count = "raid", GetNumGroupMembers() end
    for i = 1, count do
        local token = prefix .. i
        local isSelf = UnitIsUnit(token, "player")
        if not Public(isSelf) then
            candidates[#candidates + 1] = token
        elseif not isSelf then
            local role = UnitGroupRolesAssigned(token)
            if not Public(role) or role == "TANK" then
                candidates[#candidates + 1] = token
            end
        end
    end
end

function Colors.State(unit)
    local attackable, player = UnitCanAttack("player", unit), UnitIsPlayer(unit)
    if not Public(attackable) or not Public(player) then return end
    if not attackable or player then return end
    local combat = UnitAffectingCombat(unit)
    if not Public(combat) then return end
    if not combat then return "idle" end

    local holding, uncertain = CheckTank("player", unit)
    if holding then return "selfTank" end
    if candidatesDirty then RebuildCandidates() end
    for i = 1, #candidates do
        local token = candidates[i]
        local isSelf = UnitIsUnit(token, "player")
        if not Public(isSelf) then
            uncertain = true
        elseif not isSelf then
            local held, unsure = CheckTank(token, unit)
            if held then return "otherTank" end
            if unsure then uncertain = true end
        end
    end
    -- Unknown threat must not be advertised as "no tank".
    if not uncertain then return "noTank" end
end

local hooked = false
-- Keep native colours in our own table. Values may be secret: store and pass
-- them directly to the status bar, never inspect or compare the components.
local nativeColors = setmetatable({}, {__mode = "k"})
local function NameplateUnit(frame)
    if frame:IsForbidden() then return end
    local unit = frame.unit
    -- The shared CompactUnitFrame hook also receives raid, party and arena
    -- frames. GetNamePlateForUnit rejects those tokens.
    if not Public(unit) or type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or plate:IsForbidden() or plate.UnitFrame ~= frame then return end
    return unit
end

local function Apply(frame, unit)
    local native = nativeColors[frame]
    if not native or native.unit ~= unit then return end
    local db = UIThingsDB and UIThingsDB.nameplateColors
    local key = db and db.enabled and Colors.State(unit)
    local color = key and db[key]
    if color then
        frame.healthBar:SetStatusBarColor(color.r, color.g, color.b)
        native.applied = true
    elseif native.applied then
        frame.healthBar:SetStatusBarColor(native.r, native.g, native.b)
        native.applied = false
    end
end

local function AfterNativeColor(frame)
    if not Enabled() or not C_NamePlate then return end
    local unit = NameplateUnit(frame)
    if not unit or not frame.healthBar then return end
    -- Blizzard caches its intended colour on healthBar.r/g/b and skips
    -- SetStatusBarColor when unchanged, so after an override GetStatusBarColor
    -- would return our colour. Prefer the cache; fall back if absent.
    local bar = frame.healthBar
    local r, g, b = bar.r, bar.g, bar.b
    if Public(r) and r == nil then r, g, b = bar:GetStatusBarColor() end
    local native = nativeColors[frame]
    if native then
        native.unit, native.r, native.g, native.b = unit, r, g, b
    else
        nativeColors[frame] = {unit=unit, r=r, g=g, b=b}
    end
    Apply(frame, unit)
end

function Colors.Refresh()
    if not Enabled() then
        -- Restore once on disable; subsequent events and native hooks do no
        -- plate lookups until the setting is enabled again.
        for frame,native in pairs(nativeColors) do
            if native.applied and C_NamePlate and NameplateUnit(frame)==native.unit then
                frame.healthBar:SetStatusBarColor(native.r,native.g,native.b)
            end
        end
        wipe(nativeColors)
        candidatesDirty=true
        return
    end
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    if not hooked and type(CompactUnitFrame_UpdateHealthColor) == "function" then
        hooksecurefunc("CompactUnitFrame_UpdateHealthColor", AfterNativeColor)
        hooked = true
    end
    if not hooked then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        if not plate:IsForbidden() then
            local frame = plate.UnitFrame
            if frame then
                local unit = NameplateUnit(frame)
                if unit then AfterNativeColor(frame) end
            end
        end
    end
    -- Never call Blizzard's colour updater here. An addon call executes it
    -- tainted, where its class-colour lookup cannot consume secret class keys.
    -- Native events supply fresh colours through the post-hook above.
end

-- Full refreshes are coalesced to at most one per frame; threat events can
-- fire many times per frame in group content.
local refreshFrame = CreateFrame("Frame")
refreshFrame:Hide()
refreshFrame:SetScript("OnUpdate", function(self)
    self:Hide()
    Colors.Refresh()
end)
local function QueueRefresh() if Enabled() then refreshFrame:Show() end end

-- Recolour only the plate showing this unit (unit events about an enemy).
local function RefreshUnit(unit)
    if not Enabled() or not hooked or not Public(unit) or type(unit) ~= "string" then return end
    -- These events also fire under the enemy's nameplate token, so aliases
    -- such as "target" and group tokens need no lookup.
    if not unit:match("^nameplate%d+$") then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or plate:IsForbidden() then return end
    local frame = plate.UnitFrame
    if not frame then return end
    local token = NameplateUnit(frame)
    if token then Apply(frame, token) end
end

local function OnGroupChanged()
    candidatesDirty = true
    QueueRefresh()
end

-- Events naming a group member (whose threat moved), or changing roles or
-- combat state, can change any plate's colour: refresh every plate.
addon.EventBus.Register("UNIT_THREAT_SITUATION_UPDATE", QueueRefresh, "NameplateColors")
-- Combat and restriction transitions can change which roles are readable, so
-- they also rebuild the candidate list.
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED",
    "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
    "ADDON_RESTRICTION_STATE_CHANGED",
}) do
    addon.EventBus.Register(event, OnGroupChanged, "NameplateColors")
end
-- Events naming the enemy: only its own plate can change.
for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "UNIT_THREAT_LIST_UPDATE", "UNIT_FLAGS" }) do
    addon.EventBus.Register(event, function(_, unit) RefreshUnit(unit) end, "NameplateColors")
end
-- Pooled nameplate frames must not carry a previous unit's native colour.
addon.EventBus.Register("NAME_PLATE_UNIT_REMOVED", function(_, unit)
    if not Enabled() or not Public(unit) then return end
    for frame, native in pairs(nativeColors) do
        if native.unit == unit then nativeColors[frame] = nil end
    end
end, "NameplateColors")
addon.EventBus.Register("ADDON_LOADED", function(_, name)
    if name == "Blizzard_NamePlates" or name == "Blizzard_UnitFrame" then Colors.Refresh() end
end, "NameplateColors")

-- Page built by the config addon (LunaUITweaks_Config/config/panels/NameplatesPanel.lua).
LunaUITweaksAPI.RegisterConfigPanel("nameplateColors", "Nameplates",
    "Interface\\Icons\\Ability_Warrior_DefensiveStance", function(...)
        addon.ConfigSetup.Nameplates(...)
    end)
