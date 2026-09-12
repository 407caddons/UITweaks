local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus
local function Public(value) return not (issecretvalue and issecretvalue(value)) end
local function SortMessage(message) addonTable.Core.Log("Group", message, 1) end
local function CanSort()
    if InCombatLockdown() then return false, "Raid sorting is unavailable in combat." end
    if not IsInRaid() then return false, "Raid sorting requires a raid group." end
    if not UnitIsGroupLeader("player") and not UnitIsGroupAssistant("player") then
        return false, "Raid sorting requires leader or assistant."
    end
    return true
end

-- Raid Sorting Logic (Local helpers)
local function GetRaidRole(unit, role, class)
    if not Public(role) or not Public(class) then return "UNKNOWN" end
    if role == "TANK" then return "TANK" end
    if role == "HEALER" then return "HEALER" end
    if role == "DAMAGER" then
        if class == "WARRIOR" or class == "ROGUE" or class == "DEATHKNIGHT" or class == "MONK" or class == "PALADIN" then
            return "MELEE"
        end
        if unit and (class == "DRUID" or class == "SHAMAN" or class == "HUNTER" or class == "DEMONHUNTER") then
            local spec
            if UnitIsUnit(unit, "player") then
                local index = GetSpecialization()
                if index then spec = GetSpecializationInfo(index) end
            else
                local inspect = C_SpecializationInfo and C_SpecializationInfo.GetInspectSpecialization or GetInspectSpecialization
                if inspect then spec = inspect(unit) end
            end
            if not Public(spec) or not spec or spec == 0 then return "UNKNOWN" end
            if spec == 103 or spec == 263 or spec == 255 or spec == 577 then return "MELEE" end
            return "RANGED"
        end
        return "RANGED"
    end
    return "UNKNOWN"
end

local sortTicker = nil
local sortNeedsCheck = false
local function CancelSort(message)
    if sortTicker then sortTicker:Cancel(); sortTicker = nil end
    if message then SortMessage(message) end
end

local function CollectRoles(requireMelee)
    CancelSort()
    local allowed, reason = CanSort()
    if not allowed then SortMessage(reason); return end
    local roles = { TANK = {}, HEALER = {}, MELEE = {}, RANGED = {} }
    for i = 1, GetNumGroupMembers() do
        local name, _, _, _, _, class = GetRaidRosterInfo(i)
        if not Public(name) or not name then SortMessage("Roster unavailable; try sorting again shortly."); return end
        local role = GetRaidRole("raid" .. i, UnitGroupRolesAssigned("raid" .. i), class)
        if role == "UNKNOWN" then
            if requireMelee then
                SortMessage("Cannot determine melee/ranged for " .. name .. ". Inspect their specialization, then retry, or use Standard sorting.")
                return
            end
            role = "RANGED" -- Non-melee-specific layouts treat unknown DPS neutrally.
        end
        table.insert(roles[role], name)
    end
    for _, list in pairs(roles) do table.sort(list) end
    return roles
end

-- Precompute the full sequence of moves/swaps needed to reach `assignments`
-- against a simulated snapshot of the roster. Swap partners are only ever
-- picked from people who are still misplaced in the simulation, so a
-- correctly-placed person is never evicted just to make room for someone
-- else -- that was the source of the endless back-and-forth swapping.
local function PlanRaidMoves(assignments)
    local currentGroup = {}
    for j = 1, GetNumGroupMembers() do
        local name, _, sub = GetRaidRosterInfo(j)
        if name then currentGroup[name] = sub end
    end

    local groupSize = {}
    for g = 1, 8 do groupSize[g] = 0 end
    for _, sub in pairs(currentGroup) do
        groupSize[sub] = (groupSize[sub] or 0) + 1
    end

    local resolved = {}
    local function GetMisplaced()
        local list = {}
        for name, target in pairs(assignments) do
            if not resolved[name] and currentGroup[name] and currentGroup[name] ~= target then
                table.insert(list, name)
            end
        end
        table.sort(list)
        return list
    end

    local ops = {}

    -- Phase 1: direct moves into any group that already has room. Each move
    -- frees up a slot, which can open the door for the next misplaced person.
    local progress = true
    while progress do
        progress = false
        for _, name in ipairs(GetMisplaced()) do
            local target = assignments[name]
            if groupSize[target] < 5 then
                local from = currentGroup[name]
                table.insert(ops, { kind = "move", name = name, group = target })
                groupSize[from] = groupSize[from] - 1
                groupSize[target] = groupSize[target] + 1
                currentGroup[name] = target
                resolved[name] = true
                progress = true
            end
        end
    end

    -- Phase 2: everyone left needs a swap because every relevant group is
    -- full. Only swap with someone still in the misplaced list, and prefer a
    -- "perfect swap" partner (who wants our old group) so both people finish
    -- in a single move.
    local remaining = GetMisplaced()
    while #remaining > 0 do
        local name = remaining[1]
        local target = assignments[name]

        local partner = nil
        for _, n2 in ipairs(remaining) do
            if n2 ~= name and currentGroup[n2] == target and assignments[n2] == currentGroup[name] then
                partner = n2
                break
            end
        end
        if not partner then
            for _, n2 in ipairs(remaining) do
                if n2 ~= name and currentGroup[n2] == target then
                    partner = n2
                    break
                end
            end
        end

        if partner then
            table.insert(ops, { kind = "swap", name = name, partner = partner })
            currentGroup[name], currentGroup[partner] = currentGroup[partner], currentGroup[name]
            resolved[name] = true -- name always lands on its target by construction
            if currentGroup[partner] == assignments[partner] then
                resolved[partner] = true
            end
        else
            -- Target group has no misplaced occupant to trade with (assignment
            -- counts are inconsistent) -- give up on this entry instead of
            -- looping forever.
            resolved[name] = true
        end

        remaining = GetMisplaced()
    end

    return ops
end

local function ApplyRaidAssignments(assignments)
    local allowed, reason = CanSort()
    if not allowed then CancelSort(reason); return end
    CancelSort()
    local count, sizes = 0, {}
    for _, target in pairs(assignments) do
        if type(target) ~= "number" or target < 1 or target > 8 or target % 1 ~= 0 then SortMessage("Invalid raid assignment."); return end
        sizes[target] = (sizes[target] or 0) + 1; count = count + 1
        if sizes[target] > 5 then SortMessage("Cannot sort: an assigned group exceeds five players."); return end
    end
    if count ~= GetNumGroupMembers() then SortMessage("Roster changed; please sort again."); return end
    local pending, deadline = nil, GetTime() + 60
    sortNeedsCheck = true
    local function DoNextOp()
        local canSort, failure = CanSort()
        if not canSort then CancelSort(failure); return end
        local now = GetTime()
        if now > deadline then CancelSort("Raid sorting timed out; please retry."); return end
        if pending and now - pending.sent > 3 then CancelSort("Raid move was not confirmed. Sorting stopped; please retry."); return end
        if not sortNeedsCheck then return end
        sortNeedsCheck = false
        local roster = {}
        if GetNumGroupMembers() ~= count then CancelSort("Raid membership changed; please sort again."); return end
        for i = 1, count do
            local name, _, group = GetRaidRosterInfo(i)
            if not Public(name) or not name or not Public(group) or not assignments[name] then
                CancelSort("Raid roster changed or is unavailable; please sort again."); return
            end
            roster[name] = {index=i, group=group}
        end
        if pending then
            for name, target in pairs(pending.expected) do
                if not roster[name] or roster[name].group ~= target then return end
            end
            pending = nil
        end
        local complete = true
        for name, target in pairs(assignments) do if not roster[name] or roster[name].group ~= target then complete = false; break end end
        if complete then CancelSort("Raid sorting complete."); return end
        local op = PlanRaidMoves(assignments)[1]
        if not op then CancelSort("Cannot finish these assignments; sorting stopped."); return end
        pending = {sent=now, expected={}}
        local ok
        if op.kind == "move" then
            pending.expected[op.name] = op.group
            ok = pcall(SetRaidSubgroup, roster[op.name].index, op.group)
        else
            pending.expected[op.name], pending.expected[op.partner] = roster[op.partner].group, roster[op.name].group
            ok = pcall(SwapRaidSubgroup, roster[op.name].index, roster[op.partner].index)
        end
        if not ok then CancelSort("Raid move rejected; sorting stopped.") end
    end

    SortMessage("Arranging raid groups...")
    sortTicker = C_Timer.NewTicker(0.2, DoNextOp)
end

local function SortHealersToLast()
    local roles = CollectRoles(false)
    if not roles then return end
    local numMembers = GetNumGroupMembers()
    local lastGroup = math.max(math.ceil(numMembers / 5), 1)

    local assignments = {}
    local groupSizes = {}
    for i = 1, 8 do groupSizes[i] = 0 end

    for _, name in ipairs(roles.TANK) do
        for g = 1, lastGroup do
            if groupSizes[g] < 5 then assignments[name] = g; groupSizes[g] = groupSizes[g] + 1; break end
        end
    end

    for _, name in ipairs(roles.HEALER) do
        for g = lastGroup, 1, -1 do
            if groupSizes[g] < 5 then assignments[name] = g; groupSizes[g] = groupSizes[g] + 1; break end
        end
    end

    local function AssignNextAvailable(name, startGroup, preferGroup)
        if preferGroup and groupSizes[preferGroup] < 5 then
            assignments[name] = preferGroup
            groupSizes[preferGroup] = groupSizes[preferGroup] + 1
            return
        end

        for g = startGroup, 8 do
            if groupSizes[g] < 5 then
                assignments[name] = g
                groupSizes[g] = groupSizes[g] + 1
                return
            end
        end
    end

    for _, name in ipairs(roles.MELEE) do AssignNextAvailable(name, 1, 1) end
    for _, name in ipairs(roles.RANGED) do AssignNextAvailable(name, 1, nil) end

    ApplyRaidAssignments(assignments)
end

local function SortOddsEvens(meleeOddPriority)
    local roles = CollectRoles(meleeOddPriority)
    if not roles then return end

    local assignments = {}
    local groupSizes = {}
    for i = 1, 8 do groupSizes[i] = 0 end

    local function AddToBestSide(name, preferOdd)
        local sides = { { 1, 3, 5, 7 }, { 2, 4, 6, 8 } }
        local preferredSideIdx = preferOdd and 1 or 2

        local placed = false
        for _, g in ipairs(sides[preferredSideIdx]) do
            if groupSizes[g] < 5 then
                assignments[name] = g
                groupSizes[g] = groupSizes[g] + 1
                placed = true
                break
            end
        end

        if not placed then
            local otherSideIdx = (preferredSideIdx == 1) and 2 or 1
            for _, g in ipairs(sides[otherSideIdx]) do
                if groupSizes[g] < 5 then
                    assignments[name] = g
                    groupSizes[g] = groupSizes[g] + 1
                    break
                end
            end
        end
    end

    local function DistributeSpecific(list, groupsToUse)
        local gIdx = 1
        for _, name in ipairs(list) do
            local g = groupsToUse[gIdx]
            if groupSizes[g] < 5 then
                assignments[name] = g
                groupSizes[g] = groupSizes[g] + 1
            else
                for k = 1, #groupsToUse do
                    if groupSizes[groupsToUse[k]] < 5 then
                        assignments[name] = groupsToUse[k]
                        groupSizes[groupsToUse[k]] = groupSizes[groupsToUse[k]] + 1
                        break
                    end
                end
            end
            if not assignments[name] then AddToBestSide(name, gIdx == 1) end
            gIdx = (gIdx % #groupsToUse) + 1
        end
    end

    DistributeSpecific(roles.TANK, { 1, 2 })
    DistributeSpecific(roles.HEALER, { 1, 2 })

    if meleeOddPriority then
        for _, name in ipairs(roles.MELEE) do AddToBestSide(name, true) end
        for _, name in ipairs(roles.RANGED) do AddToBestSide(name, false) end
    else
        local combinedDPS = {}
        for _, v in ipairs(roles.MELEE) do table.insert(combinedDPS, v) end
        for _, v in ipairs(roles.RANGED) do table.insert(combinedDPS, v) end

        for i, name in ipairs(combinedDPS) do
            AddToBestSide(name, (i % 2 ~= 0))
        end
    end

    ApplyRaidAssignments(assignments)
end

local function SortSplitHalf()
    local roles = CollectRoles(false)
    if not roles then return end
    local numMembers = GetNumGroupMembers()

    local assignments = {}
    local groupSizes = {}
    for i = 1, 8 do groupSizes[i] = 0 end

    local limits = { math.ceil(numMembers / 2), math.floor(numMembers / 2) }
    local teamSize = { 0, 0 }
    local groupsPerTeam = math.ceil(limits[1] / 5)
    for _, role in ipairs({ "TANK", "HEALER", "MELEE", "RANGED" }) do
        local side = teamSize[1] <= teamSize[2] and 1 or 2
        for _, name in ipairs(roles[role]) do
            if teamSize[side] >= limits[side] then side = 3 - side end
            local firstGroup = side == 1 and 1 or groupsPerTeam + 1
            for g = firstGroup, firstGroup + groupsPerTeam - 1 do
                if groupSizes[g] < 5 then
                    assignments[name] = g; groupSizes[g] = groupSizes[g] + 1; break
                end
            end
            teamSize[side] = teamSize[side] + 1; side = 3 - side
        end
    end
    ApplyRaidAssignments(assignments)
end

-- Cached atlas markup strings (never change, avoid per-tick allocation)
local TANK_ICON = CreateAtlasMarkup("roleicon-tiny-tank")
local HEALER_ICON = CreateAtlasMarkup("roleicon-tiny-healer")
local DPS_ICON = CreateAtlasMarkup("roleicon-tiny-dps")

-- Module Init
table.insert(Widgets.moduleInits, function()
    local groupFrame = Widgets.CreateWidgetFrame("Group", "group")

    -- Ready check state (must be declared before OnEnter closure)
    local readyCheckActive = false
    local readyCheckResponses = {} -- name -> "ready" | "notready" | "waiting"

    -- Combat-safe name cache: UnitName() returns secret strings during combat,
    -- which cannot be used as table keys. Cache is refreshed on roster changes
    -- outside combat and on PLAYER_REGEN_ENABLED.
    local readyCheckNameCache = {} -- [unit] = name

    local function RefreshReadyCheckNames()
        if InCombatLockdown() then return end
        wipe(readyCheckNameCache)
        readyCheckNameCache["player"] = UnitName("player")
        local members = GetNumGroupMembers()
        if members > 0 then
            for i = 1, members do
                local unit = IsInRaid() and "raid" .. i or (i == members and "player" or "party" .. i)
                local name = UnitName(unit)
                if name then readyCheckNameCache[unit] = name end
            end
        end
    end

    groupFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        if not Widgets.SmartAnchorTooltip(self) then return end
        GameTooltip:SetText("Group Composition")

        local members = GetNumGroupMembers()
        if members > 0 then
            -- Collect members by group
            local groups = {}
            for i = 1, 8 do groups[i] = {} end

            for i = 1, members do
                local name, _, subgroup, level, _, class = GetRaidRosterInfo(i)
                local role = IsInRaid() and UnitGroupRolesAssigned("raid" .. i) or nil
                if not name then
                    -- Fallback for party
                    local unit = (i == members) and "player" or "party" .. i
                    name = GetUnitName(unit, true)
                    _, class = UnitClass(unit)
                    level = UnitLevel(unit)
                    subgroup = 1
                    role = UnitGroupRolesAssigned(unit)
                end

                if name then
                    local unit = IsInRaid() and "raid" .. i or
                        ((name == GetUnitName("player", true)) and "player" or "party" .. i)
                    if not IsInRaid() then
                        if i < members then unit = "party" .. i else unit = "player" end
                        name = GetUnitName(unit, true)
                        _, class = UnitClass(unit)
                        level = UnitLevel(unit)
                        subgroup = 1
                        role = UnitGroupRolesAssigned(unit)
                    end

                    local entry = {
                        unit = unit,
                        name = name,
                        class = class,
                        level = level,
                        role = role
                    }
                    table.insert(groups[subgroup], entry)
                end
            end

            -- Display by Group
            for g = 1, 8 do
                if #groups[g] > 0 then
                    if g > 1 or IsInRaid() then
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("Group " .. g, 1, 0.82, 0)
                    end

                    for _, data in ipairs(groups[g]) do
                        local classColor = C_ClassColor.GetClassColor(data.class)
                        local relationship = ""
                        if UnitIsFriend("player", data.unit) then
                            if C_FriendList.IsFriend(UnitGUID(data.unit)) then relationship = "(F)" end
                            local shortName = strsplit("-", data.name)
                            if IsInGuild() and C_GuildInfo.MemberExistsByName(shortName) then relationship = relationship .. "(G)" end
                        end

                        -- Role Icon (use cached constants)
                        local roleIcon = ""
                        if data.role == "TANK" then
                            roleIcon = TANK_ICON .. " "
                        elseif data.role == "HEALER" then
                            roleIcon = HEALER_ICON .. " "
                        elseif data.role == "DAMAGER" then
                            roleIcon = DPS_ICON .. " "
                        end

                        if classColor then
                            GameTooltip:AddDoubleLine(roleIcon .. data.name .. relationship, "Lvl " .. data.level,
                                classColor.r, classColor.g, classColor.b, 1, 1, 1)
                        else
                            GameTooltip:AddDoubleLine(roleIcon .. data.name .. relationship, "Lvl " .. data.level, 1, 1,
                                1, 1, 1, 1)
                        end
                    end
                end
            end
        else
            GameTooltip:AddLine("Not in a group")
        end

        -- Ready check overlay
        if readyCheckActive and next(readyCheckResponses) then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Ready Check", 1, 0.82, 0)
            -- Sort: waiting first, then not ready, then ready
            local sorted = {}
            for name, status in pairs(readyCheckResponses) do
                table.insert(sorted, { name = name, status = status })
            end
            table.sort(sorted, function(a, b)
                local order = { waiting = 1, notready = 2, ready = 3 }
                if order[a.status] ~= order[b.status] then
                    return order[a.status] < order[b.status]
                end
                return a.name < b.name
            end)
            for _, entry in ipairs(sorted) do
                local r, g, b = 1, 1, 0 -- waiting = yellow
                local label = "Waiting"
                if entry.status == "ready" then
                    r, g, b = 0, 1, 0
                    label = "Ready"
                elseif entry.status == "notready" then
                    r, g, b = 1, 0, 0
                    label = "Not Ready"
                end
                GameTooltip:AddDoubleLine(entry.name, label, 1, 1, 1, r, g, b)
            end
        end

        GameTooltip:Show()
    end)
    groupFrame:SetScript("OnLeave", GameTooltip_Hide)

    groupFrame:RegisterForClicks("AnyUp")
    groupFrame:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            local allowed, reason = CanSort()
            if not allowed then SortMessage(reason); return end
            GameTooltip:Hide()
            MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
                rootDescription:CreateTitle("Raid Management")
                rootDescription:CreateButton("Odds/Evens (Standard)", function() SortOddsEvens(false) end)
                rootDescription:CreateButton("Odds/Evens (Melee Odd)", function() SortOddsEvens(true) end)
                rootDescription:CreateButton("Split in Half (2 Teams)", SortSplitHalf)
                rootDescription:CreateButton("Healers to Last Group", SortHealersToLast)
                rootDescription:CreateButton("Stop sorting", function() CancelSort("Raid sorting cancelled.") end)
            end)
        end
    end)

    -- Cached group composition (updated on events, not every second)
    local cachedTanks, cachedHealers, cachedDps, cachedMembers = 0, 0, 0, 0
    local cachedText = "No Group"

    local function RefreshGroupCache()
        local tanks, healers, dps = 0, 0, 0
        local members = GetNumGroupMembers()
        if members > 0 then
            for i = 1, members do
                local unit = IsInRaid() and "raid" .. i or (i == members and "player" or "party" .. i)
                local role = UnitGroupRolesAssigned(unit)
                if role == "TANK" then
                    tanks = tanks + 1
                elseif role == "HEALER" then
                    healers = healers + 1
                elseif role == "DAMAGER" then
                    dps = dps + 1
                end
            end
            cachedTanks, cachedHealers, cachedDps, cachedMembers = tanks, healers, dps, members
            cachedText = string.format("%s %d %s %d %s %d (%d)", TANK_ICON, tanks, HEALER_ICON, healers, DPS_ICON, dps,
                members)
        else
            cachedTanks, cachedHealers, cachedDps, cachedMembers = 0, 0, 0, 0
            cachedText = "No Group"
        end
    end

    local function OnGroupRosterUpdate()
        sortNeedsCheck = true
        RefreshGroupCache()
        RefreshReadyCheckNames()
    end

    local function OnReadyCheck(event, initiatedBy)
        readyCheckActive = true
        wipe(readyCheckResponses)
        -- Refresh cache if possible (may be stale if roster changed mid-combat)
        if not InCombatLockdown() then
            RefreshReadyCheckNames()
        end
        -- Initialize all members as waiting using cached names
        local members = GetNumGroupMembers()
        if members > 0 then
            for i = 1, members do
                local unit = IsInRaid() and "raid" .. i or (i == members and "player" or "party" .. i)
                local name = readyCheckNameCache[unit] or unit
                readyCheckResponses[name] = "waiting"
            end
        end
        -- Initiator is auto-ready and never fires READY_CHECK_CONFIRM
        if initiatedBy then
            local initShort = initiatedBy:match("^([^%-]+)") or initiatedBy
            for name in pairs(readyCheckResponses) do
                local nameShort = name:match("^([^%-]+)") or name
                if nameShort == initShort then
                    readyCheckResponses[name] = "ready"
                    break
                end
            end
        end
    end

    local function OnReadyCheckConfirm(event, unit, isReady)
        local name = readyCheckNameCache[unit]
        if name then
            readyCheckResponses[name] = isReady and "ready" or "notready"
        end
    end

    local function OnReadyCheckFinished()
        -- Keep showing results for 5 seconds after finish
        C_Timer.After(5, function()
            readyCheckActive = false
            wipe(readyCheckResponses)
        end)
    end

    groupFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("GROUP_ROSTER_UPDATE", OnGroupRosterUpdate, "W:Group")
            EventBus.Register("PLAYER_ENTERING_WORLD", OnGroupRosterUpdate, "W:Group")
            EventBus.Register("ROLE_CHANGED_INFORM", OnGroupRosterUpdate, "W:Group")
            EventBus.Register("PLAYER_REGEN_ENABLED", RefreshReadyCheckNames, "W:Group")
            EventBus.Register("READY_CHECK", OnReadyCheck, "W:Group")
            EventBus.Register("READY_CHECK_CONFIRM", OnReadyCheckConfirm, "W:Group")
            EventBus.Register("READY_CHECK_FINISHED", OnReadyCheckFinished, "W:Group")
        else
            CancelSort()
            EventBus.Unregister("GROUP_ROSTER_UPDATE", OnGroupRosterUpdate)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnGroupRosterUpdate)
            EventBus.Unregister("ROLE_CHANGED_INFORM", OnGroupRosterUpdate)
            EventBus.Unregister("PLAYER_REGEN_ENABLED", RefreshReadyCheckNames)
            EventBus.Unregister("READY_CHECK", OnReadyCheck)
            EventBus.Unregister("READY_CHECK_CONFIRM", OnReadyCheckConfirm)
            EventBus.Unregister("READY_CHECK_FINISHED", OnReadyCheckFinished)
        end
    end

    groupFrame.UpdateContent = function(self)
        if readyCheckActive then
            local ready, notReady, waiting = 0, 0, 0
            for _, status in pairs(readyCheckResponses) do
                if status == "ready" then
                    ready = ready + 1
                elseif status == "notready" then
                    notReady = notReady + 1
                else
                    waiting = waiting + 1
                end
            end
            local total = ready + notReady + waiting
            if notReady > 0 then
                self.text:SetFormattedText("|cFFFF0000Ready: %d/%d|r", ready, total)
            elseif waiting > 0 then
                self.text:SetFormattedText("|cFFFFFF00Ready: %d/%d|r", ready, total)
            else
                self.text:SetFormattedText("|cFF00FF00Ready: %d/%d|r", ready, total)
            end
        else
            self.text:SetText(cachedText)
        end
    end
end)
