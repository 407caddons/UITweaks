local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

-- Raid Sorting Logic (Local helpers)
local function GetRaidRole(unit, role, class)
    if role == "TANK" then return "TANK" end
    if role == "HEALER" then return "HEALER" end
    if role == "DAMAGER" then
        if class == "WARRIOR" or class == "ROGUE" or class == "DEATHKNIGHT" or class == "DEMONHUNTER" or class == "MONK" or class == "PALADIN" then
            return "MELEE"
        end
        if unit and (class == "DRUID" or class == "SHAMAN" or class == "HUNTER") then
            if class == "DRUID" then return "RANGED" end
            if class == "SHAMAN" then return "RANGED" end
            return "RANGED"
        end
        return "RANGED"
    end
    return "RANGED"
end

local sortTicker = nil

local function ApplyRaidAssignments(assignments)
    if InCombatLockdown() then return end
    if sortTicker then
        sortTicker:Cancel()
        sortTicker = nil
    end

    local function DoNextMove()
        if InCombatLockdown() then
            if sortTicker then
                sortTicker:Cancel()
                sortTicker = nil
            end
            return
        end

        local function GetGroupSize(g)
            local count = 0
            for j = 1, GetNumGroupMembers() do
                local _, _, sub = GetRaidRosterInfo(j)
                if sub == g then count = count + 1 end
            end
            return count
        end

        local function FindPlayerByName(n)
            for j = 1, GetNumGroupMembers() do
                local name, _, _, _, _, _, _, _, _, _, _, role = GetRaidRosterInfo(j)
                if name == n then return j end
            end
            return nil
        end

        -- Scan for anyone in wrong group
        for name, targetGroup in pairs(assignments) do
            local index = FindPlayerByName(name)

            if index then
                local _, _, subgroup = GetRaidRosterInfo(index)
                if subgroup ~= targetGroup then
                    -- Needs moving
                    local destSize = GetGroupSize(targetGroup)

                    if destSize < 5 then
                        SetRaidSubgroup(index, targetGroup)
                        return -- Wait for next tick
                    else
                        -- Swap needed
                        local swapTargetIdx = nil

                        -- Priority scan in targetGroup: PERFECT SWAP
                        for j = 1, GetNumGroupMembers() do
                            local n, _, sub = GetRaidRosterInfo(j)
                            if sub == targetGroup then
                                if assignments[n] and assignments[n] == subgroup then
                                    swapTargetIdx = j
                                    break
                                end
                            end
                        end

                        -- Secondary scan
                        if not swapTargetIdx then
                            for j = 1, GetNumGroupMembers() do
                                local n, _, sub = GetRaidRosterInfo(j)
                                if sub == targetGroup then
                                    if assignments[n] and assignments[n] ~= targetGroup then
                                        swapTargetIdx = j
                                        break
                                    end
                                end
                            end
                        end

                        -- Fallback
                        if not swapTargetIdx then
                            for j = 1, GetNumGroupMembers() do
                                local _, _, sub = GetRaidRosterInfo(j)
                                if sub == targetGroup then
                                    swapTargetIdx = j
                                    break
                                end
                            end
                        end

                        if swapTargetIdx then
                            SwapRaidSubgroup(index, swapTargetIdx)
                            return -- Wait for next tick
                        end
                    end
                end
            end
        end

        -- Done
        if sortTicker then
            sortTicker:Cancel()
            sortTicker = nil
        end
        addonTable.Core.Log("Group", "Raid sorting complete.", addonTable.Core.LogLevel.DEBUG)
    end

    sortTicker = C_Timer.NewTicker(0.2, DoNextMove)
end

local function SortHealersToLast()
    if not IsInRaid() then return end
    local numMembers = GetNumGroupMembers()
    local lastGroup = math.max(math.ceil(numMembers / 5), 1)

    local roles = { TANK = {}, HEALER = {}, MELEE = {}, RANGED = {} }
    for i = 1, numMembers do
        local name, _, _, _, _, class, _, _, _, role = GetRaidRosterInfo(i)
        local unit = "raid" .. i
        local raidRole = GetRaidRole(unit, role, class)
        table.insert(roles[raidRole], name)
    end

    local assignments = {}
    local groupSizes = {}
    for i = 1, 8 do groupSizes[i] = 0 end

    for _, name in ipairs(roles.TANK) do
        assignments[name] = 1
        groupSizes[1] = groupSizes[1] + 1
    end

    for _, name in ipairs(roles.HEALER) do
        assignments[name] = lastGroup
        groupSizes[lastGroup] = groupSizes[lastGroup] + 1
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
    if not IsInRaid() then return end
    local numMembers = GetNumGroupMembers()
    local roles = { TANK = {}, HEALER = {}, MELEE = {}, RANGED = {} }

    for i = 1, numMembers do
        local name, _, _, _, _, class, _, _, _, role = GetRaidRosterInfo(i)
        local unit = "raid" .. i
        local raidRole = GetRaidRole(unit, role, class)
        table.insert(roles[raidRole], name)
    end

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
    if not IsInRaid() then return end
    local numMembers = GetNumGroupMembers()
    local roles = { TANK = {}, HEALER = {}, MELEE = {}, RANGED = {} }
    for i = 1, numMembers do
        local name, _, _, _, _, class, _, _, _, role = GetRaidRosterInfo(i)
        local unit = "raid" .. i
        local raidRole = GetRaidRole(unit, role, class)
        table.insert(roles[raidRole], name)
    end

    local assignments = {}
    local groupSizes = {}
    for i = 1, 8 do groupSizes[i] = 0 end

    local numGroups = math.ceil(numMembers / 5)
    local halfGroupStart = math.ceil(numGroups / 2) + 1
    if numGroups < 2 then halfGroupStart = 2 end

    for i, name in ipairs(roles.TANK) do
        if i == 1 then
            assignments[name] = 1
            groupSizes[1] = groupSizes[1] + 1
        else
            assignments[name] = halfGroupStart
            groupSizes[halfGroupStart] = groupSizes[halfGroupStart] + 1
        end
    end

    local numHealers = #roles.HEALER
    local firstHalfHealers = math.ceil(numHealers / 2)
    for i, name in ipairs(roles.HEALER) do
        local g = (i <= firstHalfHealers) and 1 or halfGroupStart
        assignments[name] = g
        groupSizes[g] = groupSizes[g] + 1
    end

    local dps = {}
    for _, v in ipairs(roles.MELEE) do table.insert(dps, v) end
    for _, v in ipairs(roles.RANGED) do table.insert(dps, v) end

    local gIter = 1
    for _, name in ipairs(dps) do
        local placed = false
        for attempt = 1, 8 do
            if groupSizes[gIter] < 5 then
                assignments[name] = gIter
                groupSizes[gIter] = groupSizes[gIter] + 1
                placed = true
                gIter = (gIter % numGroups) + 1
                break
            else
                gIter = (gIter % numGroups) + 1
            end
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
    local readyCheckResponses = {} -- unit -> "ready" | "notready" | "waiting"

    groupFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Group Composition")

        local members = GetNumGroupMembers()
        if members > 0 then
            -- Collect members by group
            local groups = {}
            for i = 1, 8 do groups[i] = {} end

            for i = 1, members do
                local name, _, subgroup, level, _, class, _, _, _, role = GetRaidRosterInfo(i)
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
        if button == "RightButton" and IsInRaid() and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
            GameTooltip:Hide()
            MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
                rootDescription:CreateTitle("Raid Management")
                rootDescription:CreateButton("Odds/Evens (Standard)", function() SortOddsEvens(false) end)
                rootDescription:CreateButton("Odds/Evens (Melee Odd)", function() SortOddsEvens(true) end)
                rootDescription:CreateButton("Split in Half (2 Teams)", SortSplitHalf)
                rootDescription:CreateButton("Healers to Last Group", SortHealersToLast)
                rootDescription:CreateButton("Cancel", function() end)
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
        RefreshGroupCache()
    end

    local function OnReadyCheck()
        readyCheckActive = true
        wipe(readyCheckResponses)
        -- Initialize all members as waiting
        local members = GetNumGroupMembers()
        if members > 0 then
            for i = 1, members do
                local unit = IsInRaid() and "raid" .. i or (i == members and "player" or "party" .. i)
                readyCheckResponses[UnitName(unit) or unit] = "waiting"
            end
        end
    end

    local function OnReadyCheckConfirm(event, unit, isReady)
        local name = UnitName(unit)
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
            EventBus.Register("READY_CHECK", OnReadyCheck, "W:Group")
            EventBus.Register("READY_CHECK_CONFIRM", OnReadyCheckConfirm, "W:Group")
            EventBus.Register("READY_CHECK_FINISHED", OnReadyCheckFinished, "W:Group")
        else
            EventBus.Unregister("GROUP_ROSTER_UPDATE", OnGroupRosterUpdate)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnGroupRosterUpdate)
            EventBus.Unregister("ROLE_CHANGED_INFORM", OnGroupRosterUpdate)
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
