local addonName, addonTable = ...
addonTable.TalentReminder = {}

local TalentReminder = addonTable.TalentReminder
local alertFrame        -- Popup alert frame
local currentInstanceID, currentDifficultyID
local lastZone = nil    -- Track last zone mapID for zone change detection
local lastSubZone = nil -- Track last subzone text (fires on ZONE_CHANGED even when mapID stays the same)

-- Initialize saved variables
function TalentReminder.Initialize()
    LunaUITweaks_TalentReminders = LunaUITweaks_TalentReminders or {
        version = 1,
        reminders = {}
    }

    -- Set defaults for visual settings if missing
    if UIThingsDB.talentReminders then
        if UIThingsDB.talentReminders.showBorder == nil then UIThingsDB.talentReminders.showBorder = true end
        if UIThingsDB.talentReminders.showBackground == nil then UIThingsDB.talentReminders.showBackground = true end
        if not UIThingsDB.talentReminders.borderColor then UIThingsDB.talentReminders.borderColor = { r = 1, g = 1, b = 1, a = 1 } end
        if not UIThingsDB.talentReminders.backgroundColor then UIThingsDB.talentReminders.backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 } end
        if not UIThingsDB.talentReminders.frameWidth then UIThingsDB.talentReminders.frameWidth = 400 end
        if not UIThingsDB.talentReminders.frameHeight then UIThingsDB.talentReminders.frameHeight = 300 end
    end

    TalentReminder.CreateAlertFrame()

    TalentReminder.ApplyEvents()

    -- Clean up legacy data
    TalentReminder.CleanupSavedVariables()
end

function TalentReminder.ApplyEvents()
    local EventBus = addonTable.EventBus
    if UIThingsDB.talentReminders and UIThingsDB.talentReminders.enabled then
        EventBus.Register("PLAYER_ENTERING_WORLD", TalentReminder.OnEnteringWorldEvent)
        EventBus.Register("PLAYER_SPECIALIZATION_CHANGED", TalentReminder.OnTalentChangeEvent)
        EventBus.Register("TRAIT_CONFIG_UPDATED", TalentReminder.OnTalentChangeEvent)
        EventBus.Register("ZONE_CHANGED", TalentReminder.OnZoneChangedEvent)
        EventBus.Register("ZONE_CHANGED_INDOORS", TalentReminder.OnZoneChangedEvent)
        EventBus.Register("ZONE_CHANGED_NEW_AREA", TalentReminder.OnZoneChangedEvent)
    else
        EventBus.Unregister("PLAYER_ENTERING_WORLD", TalentReminder.OnEnteringWorldEvent)
        EventBus.Unregister("PLAYER_SPECIALIZATION_CHANGED", TalentReminder.OnTalentChangeEvent)
        EventBus.Unregister("TRAIT_CONFIG_UPDATED", TalentReminder.OnTalentChangeEvent)
        EventBus.Unregister("ZONE_CHANGED", TalentReminder.OnZoneChangedEvent)
        EventBus.Unregister("ZONE_CHANGED_INDOORS", TalentReminder.OnZoneChangedEvent)
        EventBus.Unregister("ZONE_CHANGED_NEW_AREA", TalentReminder.OnZoneChangedEvent)
        if alertFrame and alertFrame:IsShown() then
            TalentReminder.ReleaseAlertFrame()
        end
    end
end

-- Cleanup legacy data and convert to array format
function TalentReminder.CleanupSavedVariables()
    if not LunaUITweaks_TalentReminders or not LunaUITweaks_TalentReminders.reminders then return end

    local migrated = 0
    for instanceID, diffs in pairs(LunaUITweaks_TalentReminders.reminders) do
        for diffID, zones in pairs(diffs) do
            for zoneKey, value in pairs(zones) do
                if type(value) == "table" and value.talents then
                    -- Old format (single object, not array) — wrap in array
                    zones[zoneKey] = { value }
                    migrated = migrated + 1
                end
            end
        end
    end

    if migrated > 0 then
        addonTable.Core.Log("TalentReminder",
            "Migrated " .. migrated .. " talent builds to new format", 1)
    end
end

-- Named callbacks for EventBus
function TalentReminder.OnEnteringWorldEvent()
    TalentReminder.OnEnteringWorld()
end

function TalentReminder.OnTalentChangeEvent()
    addonTable.Core.SafeAfter(1.0, function()
        local _, _, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
        currentInstanceID = instanceID
        currentDifficultyID = difficultyID
        lastZone = nil
        lastSubZone = nil
        TalentReminder.CheckTalentsInInstance()
    end)
end

function TalentReminder.OnZoneChangedEvent()
    TalentReminder.OnZoneChanged()
end

-- On zone changed
function TalentReminder.OnZoneChanged()
    if not UIThingsDB.talentReminders or not UIThingsDB.talentReminders.enabled then
        return
    end

    if not currentInstanceID or currentInstanceID == 0 then
        return
    end

    local currentZone = TalentReminder.GetCurrentZone()
    local currentSubZone = GetSubZoneText() or ""

    -- Check if zone actually changed — use both mapID and subzone text,
    -- since ZONE_CHANGED fires on subzone text changes but mapID may stay the same
    local zoneChanged = (currentZone and currentZone ~= lastZone) or (currentSubZone ~= lastSubZone)
    if zoneChanged then
        addonTable.Core.Log("TalentReminder", string.format("Zone changed: mapID %s -> %s, subzone '%s' -> '%s'",
            tostring(lastZone or "nil"), tostring(currentZone),
            tostring(lastSubZone or ""), currentSubZone), 0)
        lastZone = currentZone
        lastSubZone = currentSubZone

        -- Check talents for new zone after a short delay
        addonTable.Core.SafeAfter(0.5, function()
            TalentReminder.CheckTalentsInInstance()
        end)

        -- Refresh config list highlighting for the new zone
        if addonTable.Config and addonTable.Config.RefreshTalentReminderList then
            addonTable.Config.RefreshTalentReminderList()
        end
    end
end

-- On entering world/instance
function TalentReminder.OnEnteringWorld()
    -- Update current instance info
    local name, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    currentInstanceID = instanceID
    currentDifficultyID = difficultyID

    -- Reset last zone when entering new world/instance
    lastZone = nil
    lastSubZone = nil

    -- Hide alert when not in a dungeon/raid instance
    if instanceType == "none" and alertFrame and alertFrame:IsShown() then
        TalentReminder.ReleaseAlertFrame()
        return
    end

    -- Check if this is M+ and alert on entry
    if TalentReminder.IsMythicPlus() then
        addonTable.Core.SafeAfter(3, function()
            TalentReminder.CheckTalentsOnMythicPlusEntry()
        end)
    else
        -- For non-M+ instances, check talents after a short delay
        addonTable.Core.SafeAfter(3, function()
            -- Re-fetch instance info in case difficulty changed
            local name, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
            currentInstanceID = instanceID
            currentDifficultyID = difficultyID
            TalentReminder.CheckTalentsInInstance()
        end)
    end

    -- Refresh config list highlighting after entering world
    addonTable.Core.SafeAfter(3.5, function()
        if addonTable.Config and addonTable.Config.RefreshTalentReminderList then
            addonTable.Config.RefreshTalentReminderList()
        end
    end)
end

-- On boss encounter start
-- On boss encounter start - REMOVED (Combat restriction)

-- Check talents in instance (for talent changes)
function TalentReminder.CheckTalentsInInstance()
    if not currentInstanceID or currentInstanceID == 0 then
        return
    end

    if not UIThingsDB.talentReminders or not UIThingsDB.talentReminders.enabled then
        return
    end

    -- Get current class and spec
    local _, _, classID = UnitClass("player")
    local specIndex = GetSpecialization()
    local specID = specIndex and select(1, GetSpecializationInfo(specIndex))

    -- Check if we should alert for current difficulty
    if not TalentReminder.ShouldAlertForDifficulty(currentDifficultyID) then
        return
    end

    -- Get all reminders for this instance/difficulty
    local reminders = LunaUITweaks_TalentReminders.reminders[currentInstanceID]
    if not reminders or not reminders[currentDifficultyID] then
        return
    end

    -- Detect current zone (both mapID and subzone text for matching)
    local currentZone = TalentReminder.GetCurrentZone()
    local currentSubZone = GetSubZoneText() or ""

    -- Debug logging
    addonTable.Core.Log("TalentReminder", string.format(
        "CheckTalentsInInstance: mapID=%s, subZone='%s'",
        tostring(currentZone), currentSubZone), 0)

    -- Build priority list from ALL builds for this instance/difficulty
    -- Priority 1: exact zone match, Priority 2: instance-wide (key 0)
    local priorityList = {}
    for zoneKey, builds in pairs(reminders[currentDifficultyID]) do
        if type(builds) == "table" then
            for buildIndex, reminder in ipairs(builds) do
                if reminder and not reminder.disabled then
                    local priority
                    if type(zoneKey) == "string" and zoneKey ~= "" then
                        if currentSubZone ~= "" and zoneKey == currentSubZone then
                            priority = 1
                        else
                            priority = nil
                        end
                    else
                        local numKey = tonumber(zoneKey) or 0
                        if numKey == 0 then
                            priority = 2
                        else
                            priority = nil
                        end
                    end
                    if priority then
                        addonTable.Core.Log("TalentReminder",
                            string.format("Adding build '%s' (zoneKey=%s, priority=%d)",
                                reminder.name or "Unnamed", tostring(zoneKey), priority), 0)
                        table.insert(priorityList, {
                            zoneKey = zoneKey,
                            buildIndex = buildIndex,
                            reminder = reminder,
                            priority = priority
                        })
                    end
                end
            end
        end
    end

    -- Sort by priority (lower number = higher priority)
    table.sort(priorityList, function(a, b) return a.priority < b.priority end)

    -- Check reminders in priority order.
    -- Zone-specific builds (priority 1) take precedence over instance-wide (priority 2).
    -- Within the same priority level, if ANY build matches perfectly → no alert for that level.
    -- A lower-priority perfect match does NOT suppress a higher-priority mismatch.
    local bestPriority = nil
    local bestMismatchEntry = nil
    local bestMismatches = nil
    local bestPriorityMatched = false -- true if any build at bestPriority had 0 mismatches

    for _, entry in ipairs(priorityList) do
        local reminder = entry.reminder

        -- Skip if reminder doesn't match current class/spec
        if reminder.classID and reminder.classID ~= classID then
            -- Different class, skip
        elseif reminder.specID and reminder.specID ~= specID then
            -- Different spec, skip
        else
            -- If we've moved to a lower priority level and already found results, stop
            if bestPriority and entry.priority > bestPriority then
                break
            end
            bestPriority = entry.priority

            local mismatches = TalentReminder.CompareTalents(reminder.talents)
            if #mismatches == 0 then
                -- Perfect match at this priority level — no alert needed
                bestPriorityMatched = true
                bestMismatchEntry = nil
                bestMismatches = nil
            elseif not bestPriorityMatched and not bestMismatchEntry then
                -- First mismatch at this priority level
                bestMismatchEntry = entry
                bestMismatches = mismatches
            end
        end
    end

    if bestMismatchEntry and not bestPriorityMatched then
        TalentReminder.ShowAlert(bestMismatchEntry.reminder, bestMismatches, bestMismatchEntry.zoneKey)
    elseif alertFrame and alertFrame:IsShown() then
        TalentReminder.ReleaseAlertFrame()
    end
end

-- Check talents on M+ entry
function TalentReminder.CheckTalentsOnMythicPlusEntry()
    if not UIThingsDB.talentReminders or not UIThingsDB.talentReminders.enabled then
        return
    end

    -- Get current class and spec
    local _, _, classID = UnitClass("player")
    local specIndex = GetSpecialization()
    local specID = specIndex and select(1, GetSpecializationInfo(specIndex))

    if not TalentReminder.ShouldAlertForDifficulty(currentDifficultyID) then
        return
    end

    -- Check all reminders for this instance
    local reminders = LunaUITweaks_TalentReminders.reminders[currentInstanceID]
    if not reminders or not reminders[currentDifficultyID] then
        return
    end

    -- Detect current zone (both mapID and subzone text)
    local currentZone = TalentReminder.GetCurrentZone()
    local currentSubZone = GetSubZoneText() or ""

    -- Build priority list from ALL builds for this instance/difficulty
    local priorityList = {}
    for zoneKey, builds in pairs(reminders[currentDifficultyID]) do
        if type(builds) == "table" then
            for buildIndex, reminder in ipairs(builds) do
                if reminder and not reminder.disabled then
                    local priority
                    if type(zoneKey) == "string" and zoneKey ~= "" then
                        if currentSubZone ~= "" and zoneKey == currentSubZone then
                            priority = 1
                        else
                            priority = nil
                        end
                    else
                        local numKey = tonumber(zoneKey) or 0
                        if numKey == 0 then
                            priority = 2
                        else
                            priority = nil
                        end
                    end
                    if priority then
                        table.insert(priorityList, {
                            zoneKey = zoneKey,
                            buildIndex = buildIndex,
                            reminder = reminder,
                            priority = priority
                        })
                    end
                end
            end
        end
    end

    -- Sort by priority (lower number = higher priority)
    table.sort(priorityList, function(a, b) return a.priority < b.priority end)

    -- Check all matching builds — if ANY has zero mismatches, no alert needed
    local allMismatches = {}
    local reminderName = nil
    local perfectMatch = false

    for _, entry in ipairs(priorityList) do
        local reminder = entry.reminder

        -- Skip if reminder doesn't match current class/spec
        if reminder.classID and reminder.classID ~= classID then
            -- Different class, skip
        elseif reminder.specID and reminder.specID ~= specID then
            -- Different spec, skip
        else
            local mismatches = TalentReminder.CompareTalents(reminder.talents)
            if #mismatches == 0 then
                -- Perfect match found — no alert needed
                perfectMatch = true
                break
            else
                reminderName = reminderName or reminder.name
                for _, mismatch in ipairs(mismatches) do
                    table.insert(allMismatches, mismatch)
                end
            end
        end
    end

    if not perfectMatch and #allMismatches > 0 then
        local cumulativeReminder = {
            name = reminderName or "Mythic+ Entry Check",
            note = "Multiple reminders detected for this instance",
        }
        TalentReminder.ShowAlert(cumulativeReminder, allMismatches, 0)
    end
end

-- Compare current talents vs saved
function TalentReminder.CompareTalents(savedTalents)
    local mismatches = {}

    if not C_ClassTalents or not C_Traits then
        return mismatches
    end

    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then
        return mismatches
    end

    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo or not configInfo.treeIDs or #configInfo.treeIDs == 0 then
        return mismatches
    end

    local treeID = configInfo.treeIDs[1]
    local nodes = C_Traits.GetTreeNodes(treeID)

    -- Build current talent map
    local currentTalents = {}
    for _, nodeID in ipairs(nodes) do
        local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
        if nodeInfo and nodeInfo.activeEntry then
            currentTalents[nodeID] = {
                entryID = nodeInfo.activeEntry.entryID,
                rank = nodeInfo.currentRank or 0
            }
        end
    end

    -- Compare saved vs current
    for nodeID, savedData in pairs(savedTalents) do
        local current = currentTalents[nodeID]

        -- Try to resolve name if it's unknown
        local talentName = savedData.name

        if (not talentName or talentName == "Unknown Talent") then
            -- Try spellID first (most reliable)
            if savedData.spellID then
                local spellName = TalentReminder.GetSpellNameFromID(savedData.spellID)
                if spellName then
                    talentName = spellName
                end
            end
            -- Fall back to entryID lookup
            if (not talentName or talentName == "Unknown Talent") and savedData.entryID then
                talentName = TalentReminder.GetTalentName(savedData.entryID, configID) or talentName
            end
            -- Final fallback
            if not talentName or talentName == "Unknown Talent" then
                talentName = "Unknown Talent"
            end
        end

        if not current or current.rank == 0 then
            -- Missing talent (either not in currentTalents map, or rank is 0)
            local currentInfo = "nil"
            if current then
                currentInfo = "entryID=" .. tostring(current.entryID) .. " rank=" .. tostring(current.rank)
            end
            table.insert(mismatches, {
                type = "missing",
                nodeID = nodeID,
                name = talentName,
                expected = savedData
            })
        elseif current.entryID ~= savedData.entryID then
            -- Different talent selected in this node - need to remove current and add expected
            -- Get info about the current (wrong) talent for "remove" section
            local currentTalentName = "Unknown Talent"
            local currentSpellID = nil
            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
            if nodeInfo and nodeInfo.activeEntry then
                local entryInfo = C_Traits.GetEntryInfo(configID, nodeInfo.activeEntry.entryID)
                if entryInfo and entryInfo.definitionID then
                    local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                    if definitionInfo then
                        currentSpellID = definitionInfo.spellID
                        if definitionInfo.overrideName and definitionInfo.overrideName ~= "" then
                            currentTalentName = definitionInfo.overrideName
                        elseif currentSpellID then
                            currentTalentName = TalentReminder.GetSpellNameFromID(currentSpellID) or currentTalentName
                        end
                    end
                end
            end

            -- Add to "wrong" (missing the correct talent)
            table.insert(mismatches, {
                type = "wrong",
                nodeID = nodeID,
                name = talentName,
                expected = savedData,
                current = current
            })
        elseif current.rank < savedData.rank then
            -- Same talent but insufficient rank
            table.insert(mismatches, {
                type = "wrong",
                nodeID = nodeID,
                name = talentName,
                expected = savedData,
                current = current
            })
        end
    end

    -- Find extra talents (talents you have but aren't in the saved build)
    local extraCount = 0
    for nodeID, current in pairs(currentTalents) do
        if not savedTalents[nodeID] then
            -- Only count as extra if rank > 0
            if current.rank > 0 then
                extraCount = extraCount + 1

                -- Get node info for the extra talent
                local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                local talentName = "Unknown Talent"
                local spellID = nil

                if nodeInfo and nodeInfo.activeEntry then
                    local entryInfo = C_Traits.GetEntryInfo(configID, nodeInfo.activeEntry.entryID)
                    if entryInfo and entryInfo.definitionID then
                        local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                        if definitionInfo then
                            spellID = definitionInfo.spellID
                            if definitionInfo.overrideName and definitionInfo.overrideName ~= "" then
                                talentName = definitionInfo.overrideName
                            elseif spellID then
                                talentName = TalentReminder.GetSpellNameFromID(spellID) or talentName
                            end
                        end
                    end
                end

                table.insert(mismatches, {
                    type = "extra",
                    nodeID = nodeID,
                    name = talentName,
                    current = {
                        entryID = current.entryID,
                        rank = current.rank,
                        spellID = spellID
                    }
                })
            end
        end
    end

    return mismatches
end

-- Validate that saved talents still exist in current talent tree
-- Returns: isValid (boolean), invalidTalents (table)
function TalentReminder.ValidateTalentBuild(savedTalents)
    if not C_ClassTalents or not C_Traits then
        return false, {}
    end

    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then
        return false, {}
    end

    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo or not configInfo.treeIDs or #configInfo.treeIDs == 0 then
        return false, {}
    end

    local treeID = configInfo.treeIDs[1]
    local nodes = C_Traits.GetTreeNodes(treeID)

    -- Build set of valid nodeIDs
    local validNodes = {}
    for _, nodeID in ipairs(nodes) do
        validNodes[nodeID] = true
    end

    -- Check each saved talent
    local invalidTalents = {}
    for nodeID, savedData in pairs(savedTalents) do
        -- Check if node still exists
        if not validNodes[nodeID] then
            table.insert(invalidTalents, {
                nodeID = nodeID,
                name = savedData.name,
                reason = "Node no longer exists"
            })
        else
            -- Check if entryID is still valid
            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
            if nodeInfo then
                local entryInfo = C_Traits.GetEntryInfo(configID, savedData.entryID)
                if not entryInfo then
                    table.insert(invalidTalents, {
                        nodeID = nodeID,
                        name = savedData.name,
                        reason = "Talent no longer available"
                    })
                end
            end
        end
    end

    local isValid = #invalidTalents == 0
    return isValid, invalidTalents
end

-- Get colored class/spec display string for reminder
function TalentReminder.GetClassSpecString(reminder)
    if not reminder.className or not reminder.specName then
        return "|cFFAAAAAA[Unknown Class/Spec]|r"
    end

    -- Get class color
    local classColor = "FFE6CC80" -- Default gold color
    if reminder.className then
        local classFile = reminder.className:upper():gsub(" ", "")
        local colors = RAID_CLASS_COLORS[classFile]
        if colors then
            classColor = string.format("FF%02X%02X%02X",
                colors.r * 255, colors.g * 255, colors.b * 255)
        end
    end

    return string.format("|c%s%s|r - %s", classColor, reminder.specName, reminder.className)
end

-- Get current zone as a numeric uiMapID (used for zone-based detection)
function TalentReminder.GetCurrentZone()
    local mapID = C_Map.GetBestMapForUnit("player")
    local result = mapID or 0

    -- Debug logging
    addonTable.Core.Log("TalentReminder", string.format("GetCurrentZone: mapID=%s", tostring(result)), 0)

    return result
end

-- No longer needed - we use zone text instead
function TalentReminder.GetBossListForInstance(instanceID)
    -- Boss areas are now entered manually or detected via zone text
    -- No dropdown needed
    return {}
end

-- Helper to resolve talent name from spellID
function TalentReminder.GetSpellNameFromID(spellID)
    if not spellID then return nil end

    local spellName
    if C_Spell and C_Spell.GetSpellName then
        spellName = C_Spell.GetSpellName(spellID)
    elseif GetSpellInfo then
        spellName = GetSpellInfo(spellID)
    end

    return spellName
end

-- Helper to resolve talent name
function TalentReminder.GetTalentName(entryID, configID)
    if not entryID then
        return "Unknown Talent"
    end

    -- If configID not provided, try to get active one
    if not configID and C_ClassTalents then
        configID = C_ClassTalents.GetActiveConfigID()
    end

    if not configID then
        return "Unknown Talent"
    end

    local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
    if not entryInfo then
        return "Unknown Talent"
    end

    if not entryInfo.definitionID then
        return "Unknown Talent"
    end

    local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
    if not definitionInfo then
        return "Unknown Talent"
    end

    -- Try overrideName first
    if definitionInfo.overrideName and definitionInfo.overrideName ~= "" then
        return definitionInfo.overrideName
    end

    -- Fall back to spell name from spellID
    if definitionInfo.spellID then
        local spellName = TalentReminder.GetSpellNameFromID(definitionInfo.spellID)
        if spellName then
            return spellName
        end
    end

    return "Unknown Talent"
end

-- Create talent snapshot
function TalentReminder.CreateSnapshot()
    if not C_ClassTalents or not C_Traits then
        return nil, "Talent API not available"
    end

    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then
        return nil, "No active talent config"
    end

    -- Capture current class and spec
    local _, className, classID = UnitClass("player")
    local specIndex = GetSpecialization()
    local specID, specName = nil, nil
    if specIndex then
        specID, specName = GetSpecializationInfo(specIndex)
    end

    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo or not configInfo.treeIDs or #configInfo.treeIDs == 0 then
        return nil, "No talent tree found"
    end

    local treeID = configInfo.treeIDs[1]
    local nodes = C_Traits.GetTreeNodes(treeID)

    local snapshot = {}
    local count = 0
    local skippedCount = 0

    for _, nodeID in ipairs(nodes) do
        local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
        if nodeInfo and nodeInfo.activeEntry then
            local rank = nodeInfo.currentRank or 0

            -- Only save talents that are actually selected (rank > 0)
            if rank > 0 then
                local entryInfo = C_Traits.GetEntryInfo(configID, nodeInfo.activeEntry.entryID)

                -- Get talent name using helper
                local talentName = TalentReminder.GetTalentName(nodeInfo.activeEntry.entryID, configID)

                -- Also get spellID for future lookup
                local spellID = nil
                if entryInfo and entryInfo.definitionID then
                    local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                    if definitionInfo then
                        spellID = definitionInfo.spellID
                    end
                end

                snapshot[nodeID] = {
                    name = talentName,
                    entryID = nodeInfo.activeEntry.entryID,
                    rank = rank,
                    spellID = spellID
                }
                count = count + 1
            else
                skippedCount = skippedCount + 1
            end
        end
    end

    return snapshot, nil, count, {
        classID = classID,
        className = className,
        specID = specID,
        specName = specName
    }
end

-- Get reminder for encounter
function TalentReminder.GetReminderForEncounter(instanceID, difficultyID, bossID)
    local reminders = LunaUITweaks_TalentReminders.reminders[instanceID]
    if not reminders then
        return nil
    end

    local diffReminders = reminders[difficultyID]
    if not diffReminders then
        return nil
    end

    return diffReminders[bossID]
end

-- Save reminder
function TalentReminder.SaveReminder(instanceID, difficultyID, bossID, name, instanceName, difficulty, note)
    local snapshot, err, count, classSpecInfo = TalentReminder.CreateSnapshot()
    if err then
        return false, err
    end

    LunaUITweaks_TalentReminders.reminders[instanceID] = LunaUITweaks_TalentReminders.reminders[instanceID] or {}
    LunaUITweaks_TalentReminders.reminders[instanceID][difficultyID] = LunaUITweaks_TalentReminders.reminders
        [instanceID][difficultyID] or {}
    LunaUITweaks_TalentReminders.reminders[instanceID][difficultyID][bossID] =
        LunaUITweaks_TalentReminders.reminders[instanceID][difficultyID][bossID] or {}

    table.insert(LunaUITweaks_TalentReminders.reminders[instanceID][difficultyID][bossID], {
        name = name,
        instanceName = instanceName,
        difficulty = difficulty,
        difficultyID = difficultyID,
        createdDate = date("%Y-%m-%d"),
        note = note or "",
        talents = snapshot,
        classID = classSpecInfo.classID,
        className = classSpecInfo.className,
        specID = classSpecInfo.specID,
        specName = classSpecInfo.specName
    })

    -- Auto-enable the difficulty filter for the saved difficulty
    if UIThingsDB.talentReminders and UIThingsDB.talentReminders.alertOnDifficulties then
        local filters = UIThingsDB.talentReminders.alertOnDifficulties
        local diffMap = {
            [1] = "dungeonNormal",
            [2] = "dungeonHeroic",
            [23] = "dungeonMythic",
            [8] = "mythicPlus",
            [17] = "raidLFR",
            [14] = "raidNormal",
            [15] = "raidHeroic",
            [16] = "raidMythic",
        }
        local filterKey = diffMap[difficultyID]
        if filterKey and not filters[filterKey] then
            filters[filterKey] = true
            -- Update the UI checkbox if the config panel is open
            local checkboxMap = {
                dungeonNormal = "UIThingsTalentDNormalCheck",
                dungeonHeroic = "UIThingsTalentDHeroicCheck",
                dungeonMythic = "UIThingsTalentDMythicCheck",
                mythicPlus = "UIThingsTalentMPlusCheck",
                raidLFR = "UIThingsTalentRLFRCheck",
                raidNormal = "UIThingsTalentRNormalCheck",
                raidHeroic = "UIThingsTalentRHeroicCheck",
                raidMythic = "UIThingsTalentRMythicCheck",
            }
            local checkboxName = checkboxMap[filterKey]
            if checkboxName and _G[checkboxName] then
                _G[checkboxName]:SetChecked(true)
            end
            addonTable.Core.Log("TalentReminder",
                "Auto-enabled difficulty filter: " .. filterKey, addonTable.Core.LogLevel.INFO)
        end
    end

    return true, nil, count
end

-- Delete reminder by build index within the zone key array
function TalentReminder.DeleteReminder(instanceID, difficultyID, zoneKey, buildIndex)
    if not LunaUITweaks_TalentReminders.reminders[instanceID] then return end
    if not LunaUITweaks_TalentReminders.reminders[instanceID][difficultyID] then return end

    local builds = LunaUITweaks_TalentReminders.reminders[instanceID][difficultyID][zoneKey]
    if not builds then return end

    if buildIndex and buildIndex >= 1 and buildIndex <= #builds then
        table.remove(builds, buildIndex)
    end

    -- Clean up empty tables
    if #builds == 0 then
        LunaUITweaks_TalentReminders.reminders[instanceID][difficultyID][zoneKey] = nil
    end
    if not next(LunaUITweaks_TalentReminders.reminders[instanceID][difficultyID]) then
        LunaUITweaks_TalentReminders.reminders[instanceID][difficultyID] = nil
    end
    if not next(LunaUITweaks_TalentReminders.reminders[instanceID]) then
        LunaUITweaks_TalentReminders.reminders[instanceID] = nil
    end
end

-- Check if current instance is M+
function TalentReminder.IsMythicPlus()
    local _, instanceType, difficultyID = GetInstanceInfo()
    -- Mythic Keystone is difficulty 8
    return instanceType == "party" and difficultyID == 8
end

-- Check if player is max level
function TalentReminder.IsMaxLevel()
    local maxLevel = GetMaxLevelForPlayerExpansion()
    local currentLevel = UnitLevel("player")
    return currentLevel >= maxLevel
end

-- Check if we should alert for this difficulty
function TalentReminder.ShouldAlertForDifficulty(difficultyID)
    -- Only alert at max level
    if not TalentReminder.IsMaxLevel() then
        return false
    end

    if not UIThingsDB.talentReminders or not UIThingsDB.talentReminders.alertOnDifficulties then
        return true -- Default to alert on all
    end

    local filters = UIThingsDB.talentReminders.alertOnDifficulties

    -- Dungeon difficulties
    if difficultyID == 1 and filters.dungeonNormal then return true end
    if difficultyID == 2 and filters.dungeonHeroic then return true end
    if difficultyID == 23 and filters.dungeonMythic then return true end
    if difficultyID == 8 and filters.mythicPlus then return true end

    -- Raid difficulties
    if difficultyID == 17 and filters.raidLFR then return true end
    if difficultyID == 14 and filters.raidNormal then return true end
    if difficultyID == 15 and filters.raidHeroic then return true end
    if difficultyID == 16 and filters.raidMythic then return true end

    return false
end

-- Show alert
function TalentReminder.ShowAlert(reminder, mismatches, zoneKey)
    if not alertFrame then
        return
    end

    -- Play sound
    if UIThingsDB.talentReminders and UIThingsDB.talentReminders.playSound then
        PlaySound(8959) -- SOUNDKIT.RAID_WARNING
    end

    -- TTS announcement removed per user request
    -- if UIThingsDB.talentReminders and UIThingsDB.talentReminders.useTTS then
    --     for _, mismatch in ipairs(mismatches) do
    --         if mismatch.type == "missing" then
    --             PlaySound(8959) -- SOUNDKIT.RAID_WARNING
    --             break
    --         end
    --     end
    -- end

    -- Chat message
    if UIThingsDB.talentReminders and UIThingsDB.talentReminders.showChatMessage then
        -- Separate mismatches by type
        local missing = {}
        local wrong = {}
        local extra = {}

        for _, m in ipairs(mismatches) do
            if m.type == "missing" then
                table.insert(missing, m)
            elseif m.type == "wrong" then
                table.insert(wrong, m)
            elseif m.type == "extra" then
                table.insert(extra, m)
            end
        end

        -- Header
        print(string.format("|cFFFF0000[LunaUITweaks]|r Talent mismatch for %s:", reminder.name))

        -- Missing talents
        if #missing > 0 then
            print("|cFFFF6B6B  Missing Talents:|r")
            for _, m in ipairs(missing) do
                print(string.format("    - %s", m.name))
            end
        end

        -- Wrong talents (need different selection)
        if #wrong > 0 then
            print("|cFFFFAA00  Wrong Selection:|r")
            for _, m in ipairs(wrong) do
                print(string.format("    - Need %s (rank %d)", m.name, m.expected.rank))
            end
        end

        -- Extra talents (to remove)
        if #extra > 0 then
            print("|cFFFF9900  Talents to Remove:|r")
            for _, m in ipairs(extra) do
                print(string.format("    - %s", m.name))
            end
        end
    end

    -- Show popup
    if UIThingsDB.talentReminders and UIThingsDB.talentReminders.showPopup then
        TalentReminder.UpdateAlertFrame(reminder, mismatches, zoneKey)
        alertFrame:Show()
    end
end

-- Apply talents from saved build
function TalentReminder.ApplyTalents(reminder)
    if not C_ClassTalents or not C_Traits then
        print("|cFFFF0000[LunaUITweaks]|r Talent API not available")
        return false
    end

    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then
        print("|cFFFF0000[LunaUITweaks]|r No active talent config")
        return false
    end

    -- Check if in combat
    if InCombatLockdown() then
        print("|cFFFF0000[LunaUITweaks]|r Cannot change talents while in combat")
        return false
    end

    local savedTalents = reminder.talents
    if not savedTalents then
        print("|cFFFF0000[LunaUITweaks]|r No saved talents found")
        return false
    end

    -- Get current talents for comparison
    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo or not configInfo.treeIDs or #configInfo.treeIDs == 0 then
        print("|cFFFF0000[LunaUITweaks]|r No talent tree found")
        return false
    end

    local treeID = configInfo.treeIDs[1]
    local nodes = C_Traits.GetTreeNodes(treeID)

    -- Build current talent map
    local currentTalents = {}
    for _, nodeID in ipairs(nodes) do
        local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
        if nodeInfo and nodeInfo.activeEntry then
            currentTalents[nodeID] = {
                entryID = nodeInfo.activeEntry.entryID,
                rank = nodeInfo.currentRank or 0
            }
        end
    end

    print("|cFF00FF00[LunaUITweaks]|r Applying talent build: " .. reminder.name)

    local changes = 0
    local errors = 0

    -- Step 1: Remove all talents that shouldn't be there
    for nodeID, current in pairs(currentTalents) do
        if not savedTalents[nodeID] and current.rank > 0 then
            -- This talent should not be selected - remove it
            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
            if nodeInfo then
                for i = 1, current.rank do
                    local success = C_Traits.RefundRank(configID, nodeID)
                    if success then
                        changes = changes + 1
                    else
                        errors = errors + 1
                        addonTable.Core.Log("TalentReminder", string.format("Failed to refund node %d", nodeID), 2)
                    end
                end
            end
        elseif savedTalents[nodeID] and current.entryID ~= savedTalents[nodeID].entryID then
            -- Wrong choice selected - need to refund before changing
            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
            if nodeInfo then
                for i = 1, current.rank do
                    local success = C_Traits.RefundRank(configID, nodeID)
                    if success then
                        changes = changes + 1
                    else
                        errors = errors + 1
                        addonTable.Core.Log("TalentReminder",
                            string.format("Failed to refund node %d for re-selection", nodeID), 2)
                    end
                end
            end
        end
    end

    -- Step 2: Apply all saved talents
    for nodeID, savedData in pairs(savedTalents) do
        local current = currentTalents[nodeID]
        local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)

        if not nodeInfo then
            addonTable.Core.Log("TalentReminder", string.format("Node %d no longer exists", nodeID), 2)
            errors = errors + 1
        else
            -- Check if this is a choice node (has multiple entries)
            if nodeInfo.type == 2 then -- TYPE_CHOICE
                -- Use SetSelection for choice nodes
                if not current or current.entryID ~= savedData.entryID or current.rank == 0 then
                    local success = C_Traits.SetSelection(configID, nodeID, savedData.entryID)
                    if success then
                        changes = changes + 1
                    else
                        errors = errors + 1
                        addonTable.Core.Log("TalentReminder",
                            string.format("Failed to set selection for node %d", nodeID), 2)
                    end
                end

                -- After setting selection, purchase ranks if needed
                local currentRank = current and current.rank or 0
                for i = currentRank + 1, savedData.rank do
                    local success = C_Traits.PurchaseRank(configID, nodeID)
                    if success then
                        changes = changes + 1
                    else
                        errors = errors + 1
                        addonTable.Core.Log("TalentReminder",
                            string.format("Failed to purchase rank %d for node %d", i, nodeID), 2)
                    end
                end
            else
                -- Regular node - just purchase ranks
                local currentRank = current and current.rank or 0
                for i = currentRank + 1, savedData.rank do
                    local success = C_Traits.PurchaseRank(configID, nodeID)
                    if success then
                        changes = changes + 1
                    else
                        errors = errors + 1
                        addonTable.Core.Log("TalentReminder",
                            string.format("Failed to purchase rank %d for node %d", i, nodeID), 2)
                    end
                end
            end
        end
    end

    -- Step 3: Commit the changes
    if changes > 0 then
        local result = C_Traits.CommitConfig(configID)
        -- C_Traits.CommitConfig returns a result code (0 = success, non-zero = error)
        -- or boolean in some game versions
        local success = (result == 0) or (result == true) or (type(result) == "number" and result >= 0)

        if success then
            print("|cFF00FF00[LunaUITweaks]|r Talents applied successfully (" .. changes .. " changes)")
            -- Hide the alert frame
            if alertFrame then
                TalentReminder.ReleaseAlertFrame()
            end
            return true
        else
            print("|cFFFF0000[LunaUITweaks]|r Unable to load talents (result: " .. tostring(result) .. ")")
            print("|cFFFFAA00[LunaUITweaks]|r You may need to manually apply the changes in the talent UI")
            return false
        end
    elseif errors > 0 then
        print("|cFFFF0000[LunaUITweaks]|r Encountered " .. errors .. " errors while applying talents")
        return false
    else
        print("|cFF00FF00[LunaUITweaks]|r Talents already match the saved build")
        if alertFrame then
            TalentReminder.ReleaseAlertFrame()
        end
        return true
    end
end

-- Refresh current alert content (if showing)
function TalentReminder.RefreshCurrentAlert()
    if not alertFrame or not alertFrame:IsShown() then return end
    if not alertFrame.currentReminder or not alertFrame.currentMismatches then return end

    -- Re-render the alert with current data
    TalentReminder.UpdateAlertFrame(alertFrame.currentReminder, alertFrame.currentMismatches, alertFrame.zoneKey)
end

-- Update visual appearance only
function TalentReminder.UpdateVisuals()
    if not alertFrame then return end

    -- Apply font settings
    local font = UIThingsDB.talentReminders.alertFont or "Fonts\\FRIZQT__.TTF"
    local fontSize = UIThingsDB.talentReminders.alertFontSize or 12
    alertFrame.content:SetFont(font, fontSize)

    -- Apply frame size
    local width = UIThingsDB.talentReminders.frameWidth or 400
    local height = UIThingsDB.talentReminders.frameHeight or 300
    alertFrame:SetSize(width, height)

    -- Adjust scroll frame size (width - 40 padding, height - 150 top/bottom space)
    if alertFrame.scrollFrame then
        alertFrame.scrollFrame:SetSize(width - 40, height - 150)
        if alertFrame.scrollChild then
            alertFrame.scrollChild:SetSize(width - 40, height - 150)
        end
        if alertFrame.content then
            alertFrame.content:SetWidth(width - 60)
        end
    end

    -- Apply visual settings (Backdrop)
    local Helpers = addonTable.ConfigHelpers
    Helpers.ApplyFrameBackdrop(alertFrame,
        UIThingsDB.talentReminders.showBorder, UIThingsDB.talentReminders.borderColor,
        UIThingsDB.talentReminders.showBackground, UIThingsDB.talentReminders.backgroundColor)

    -- Always show all three buttons
    if alertFrame.applyTalentsBtn then
        alertFrame.applyTalentsBtn:Show()
        alertFrame.applyTalentsBtn:ClearAllPoints()
        alertFrame.applyTalentsBtn:SetPoint("BOTTOM", -130, 20)
    end

    if alertFrame.openTalentsBtn then
        alertFrame.openTalentsBtn:Show()
        alertFrame.openTalentsBtn:ClearAllPoints()
        alertFrame.openTalentsBtn:SetPoint("BOTTOM", 0, 20)
    end

    if alertFrame.dismissBtn then
        alertFrame.dismissBtn:Show()
        alertFrame.dismissBtn:ClearAllPoints()
        alertFrame.dismissBtn:SetPoint("BOTTOM", 130, 20)
    end
end

-- Update alert frame content
function TalentReminder.UpdateAlertFrame(reminder, mismatches, zoneKey)
    if not alertFrame then return end

    TalentReminder.UpdateVisuals()

    alertFrame.title:SetText("TALENT REMINDER")
    alertFrame.bossName:SetText(reminder.name)
    alertFrame.zoneKey = zoneKey              -- Store zone key instead of bossID
    alertFrame.currentReminder = reminder     -- Store reminder for Apply button
    alertFrame.currentMismatches = mismatches -- Store mismatches for refresh

    -- Build mismatch text
    local text = ""
    local missing = {}
    local wrong = {}
    local extra = {}

    for _, m in ipairs(mismatches) do
        if m.type == "missing" then
            table.insert(missing, m)
        elseif m.type == "wrong" then
            table.insert(wrong, m)
        elseif m.type == "extra" then
            table.insert(extra, m)
        end
    end

    if #missing > 0 then
        text = text .. "|cFFFF6B6BMissing Talents:|r\n"
        for _, m in ipairs(missing) do
            -- Try to resolve name again if unknown
            local name = m.name
            local spellID = m.expected and m.expected.spellID
            if (not name or name == "Unknown Talent") and m.expected then
                -- Try spellID first (most reliable)
                if m.expected.spellID then
                    local spellName = TalentReminder.GetSpellNameFromID(m.expected.spellID)
                    if spellName then
                        name = spellName
                    end
                end
                -- Fall back to entryID lookup
                if (not name or name == "Unknown Talent") and m.expected.entryID then
                    name = TalentReminder.GetTalentName(m.expected.entryID) or name
                end
            end

            -- Get spell icon
            local icon = ""
            if spellID then
                local iconSize = UIThingsDB.talentReminders.alertIconSize or 16
                local spellTexture = C_Spell and C_Spell.GetSpellTexture(spellID) or GetSpellTexture(spellID)
                if spellTexture then
                    icon = string.format("|T%s:%d:%d:0:0|t ", spellTexture, iconSize, iconSize)
                end
            end

            text = text .. string.format("  • %s%s\n", icon, name)
        end
    end

    if #wrong > 0 then
        text = text .. "\n|cFFFFAA00Wrong Selection:|r\n"
        for _, m in ipairs(wrong) do
            -- Try to resolve name again if unknown
            local name = m.name
            local spellID = m.expected and m.expected.spellID

            if (not name or name == "Unknown Talent") and m.expected then
                -- Try spellID first (most reliable)
                if m.expected.spellID then
                    local spellName = TalentReminder.GetSpellNameFromID(m.expected.spellID)
                    if spellName then
                        name = spellName
                    end
                end
                -- Fall back to entryID lookup
                if (not name or name == "Unknown Talent") and m.expected.entryID then
                    name = TalentReminder.GetTalentName(m.expected.entryID) or name
                end
            end

            -- Get spell icon
            local icon = ""
            if spellID then
                local iconSize = UIThingsDB.talentReminders.alertIconSize or 16
                local spellTexture = C_Spell and C_Spell.GetSpellTexture(spellID) or GetSpellTexture(spellID)
                if spellTexture then
                    icon = string.format("|T%s:%d:%d:0:0|t ", spellTexture, iconSize, iconSize)
                end
            end

            local line = string.format("  • %sNeed %s (rank %d)\n", icon, name, m.expected.rank)
            text = text .. line
        end
    end

    if #extra > 0 then
        text = text .. "\n|cFFFF9900Talents to Remove:|r\n"
        for _, m in ipairs(extra) do
            local name = m.name
            local spellID = m.current and m.current.spellID

            -- Get spell icon
            local icon = ""
            if spellID then
                local iconSize = UIThingsDB.talentReminders.alertIconSize or 16
                local spellTexture = C_Spell and C_Spell.GetSpellTexture(spellID) or GetSpellTexture(spellID)
                if spellTexture then
                    icon = string.format("|T%s:%d:%d:0:0|t ", spellTexture, iconSize, iconSize)
                end
            end

            text = text .. string.format("  • %s%s\n", icon, name)
        end
    end

    if reminder.note and reminder.note ~= "" then
        text = text .. "\n|cFF00FF00Note:|r " .. reminder.note
    end

    alertFrame.content:SetText(text)
end

-- Create alert frame
function TalentReminder.CreateAlertFrame()
    if alertFrame then return end

    alertFrame = CreateFrame("Frame", "LunaTalentReminderAlert", UIParent, "BackdropTemplate")
    alertFrame:SetSize(400, 300)

    -- Restore saved position
    local pos = UIThingsDB.talentReminders.alertPos or { point = "CENTER", x = 0, y = 0 }
    alertFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)

    alertFrame:SetFrameStrata("DIALOG")

    -- Default Backdrop (will be updated by UpdateAlertFrame)
    alertFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    alertFrame:EnableMouse(true)
    alertFrame:SetMovable(true)
    alertFrame:RegisterForDrag("LeftButton")
    alertFrame:SetScript("OnDragStart", alertFrame.StartMoving)
    alertFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, relativePoint, x, y = self:GetPoint()
        UIThingsDB.talentReminders.alertPos = {
            point = point,
            x = x,
            y = y
        }
    end)
    alertFrame:Hide()

    -- Title
    alertFrame.title = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    alertFrame.title:SetPoint("TOP", 0, -20)
    alertFrame.title:SetTextColor(1, 0, 0)

    -- Boss name
    alertFrame.bossName = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    alertFrame.bossName:SetPoint("TOP", 0, -45)

    -- Content
    local scrollFrame = CreateFrame("ScrollFrame", nil, alertFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(360, 150)
    scrollFrame:SetPoint("TOP", 0, -70)
    alertFrame.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(360, 150)
    scrollFrame:SetScrollChild(scrollChild)
    alertFrame.scrollChild = scrollChild

    alertFrame.content = scrollChild:CreateFontString(nil, "OVERLAY")
    alertFrame.content:SetPoint("TOPLEFT", 5, -5)
    alertFrame.content:SetWidth(340)
    alertFrame.content:SetJustifyH("LEFT")
    alertFrame.content:SetJustifyV("TOP")

    -- Apply font settings
    local font = UIThingsDB.talentReminders.alertFont or "Fonts\\FRIZQT__.TTF"
    local fontSize = UIThingsDB.talentReminders.alertFontSize or 12
    alertFrame.content:SetFont(font, fontSize)

    -- Apply Talents button
    local applyTalentsBtn = CreateFrame("Button", nil, alertFrame, "GameMenuButtonTemplate")
    applyTalentsBtn:SetSize(120, 25)
    applyTalentsBtn:SetPoint("BOTTOM", -130, 20)
    applyTalentsBtn:SetText("Apply Talents")
    applyTalentsBtn:SetNormalFontObject("GameFontNormal")
    applyTalentsBtn:SetHighlightFontObject("GameFontHighlight")
    applyTalentsBtn:SetScript("OnClick", function(self)
        if alertFrame.currentReminder then
            TalentReminder.ApplyTalents(alertFrame.currentReminder)
        else
            print("|cFFFF0000[LunaUITweaks]|r No reminder data available")
        end
    end)
    alertFrame.applyTalentsBtn = applyTalentsBtn

    -- Open Talents button
    local openTalentsBtn = CreateFrame("Button", nil, alertFrame, "GameMenuButtonTemplate")
    openTalentsBtn:SetSize(120, 25)
    openTalentsBtn:SetPoint("BOTTOM", 0, 20)
    openTalentsBtn:SetText("Open Talents")
    openTalentsBtn:SetNormalFontObject("GameFontNormal")
    openTalentsBtn:SetHighlightFontObject("GameFontHighlight")
    openTalentsBtn:SetScript("OnClick", function(self)
        -- Open talent frame
        if PlayerSpellsUtil and PlayerSpellsUtil.ToggleTalentFrame then
            PlayerSpellsUtil.ToggleTalentFrame()
        elseif PlayerSpellsFrame then
            -- Fallback for older API
            if PlayerSpellsFrame:IsShown() then
                HideUIPanel(PlayerSpellsFrame)
            else
                ShowUIPanel(PlayerSpellsFrame)
            end
        end
    end)
    alertFrame.openTalentsBtn = openTalentsBtn

    -- Dismiss button
    local dismissBtn = CreateFrame("Button", nil, alertFrame, "GameMenuButtonTemplate")
    dismissBtn:SetSize(120, 25)
    dismissBtn:SetPoint("BOTTOM", 130, 20)
    dismissBtn:SetText("Dismiss")
    dismissBtn:SetNormalFontObject("GameFontNormal")
    dismissBtn:SetHighlightFontObject("GameFontHighlight")
    dismissBtn:SetScript("OnClick", function(self)
        TalentReminder.ReleaseAlertFrame()
    end)
    alertFrame.dismissBtn = dismissBtn

    -- Close button
    local closeBtn = CreateFrame("Button", nil, alertFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
end

-- Cleanup alert frame and release memory
function TalentReminder.ReleaseAlertFrame()
    if not alertFrame then return end

    -- Hide and clear all references
    alertFrame:Hide()
    alertFrame.currentReminder = nil

    -- Clear content to release string references
    if alertFrame.content then
        alertFrame.content:SetText("")
    end
    if alertFrame.title then
        alertFrame.title:SetText("")
    end
    if alertFrame.bossName then
        alertFrame.bossName:SetText("")
    end

    -- Note: We keep the frame structure intact for reuse
    -- The frame itself is not released, but all dynamic content is cleared
    addonTable.Core.Log("TalentReminder", "Alert frame content cleared", addonTable.Core.LogLevel.DEBUG)
end

-- Get current location info (for snapshot UI)
function TalentReminder.GetCurrentLocation()
    local name, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    local difficultyName = GetDifficultyInfo(difficultyID) or "Unknown"

    -- Get numeric uiMapID for zone identification
    local zoneMapID = TalentReminder.GetCurrentZone()

    -- Get subzone text for boss-area granularity (raids have multiple boss areas on the same mapID)
    local subZone = GetSubZoneText() or ""

    return {
        instanceID = instanceID,
        instanceName = name,
        instanceType = instanceType,
        difficultyID = difficultyID,
        difficultyName = difficultyName,
        zoneMapID = zoneMapID,
        subZone = subZone
    }
end
