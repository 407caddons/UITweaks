local addonName, addonTable = ...
addonTable.TalentReminder = {}

local TalentReminder = addonTable.TalentReminder
local snoozed = {} -- Session-only snooze tracking: [instanceID][bossID] = true
local alertFrame   -- Popup alert frame
local currentInstanceID, currentDifficultyID

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
        if not UIThingsDB.talentReminders.borderColor then UIThingsDB.talentReminders.borderColor = {r=1, g=1, b=1, a=1} end
        if not UIThingsDB.talentReminders.backgroundColor then UIThingsDB.talentReminders.backgroundColor = {r=0, g=0, b=0, a=0.8} end
    end

    TalentReminder.CreateAlertFrame()

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ENCOUNTER_START")
    frame:RegisterEvent("ENCOUNTER_END")
    frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    frame:SetScript("OnEvent", TalentReminder.OnEvent)

    addonTable.Core.Log("TalentReminder", "Initialized")
end

-- Event handler
function TalentReminder.OnEvent(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        TalentReminder.OnEnteringWorld()
    elseif event == "ENCOUNTER_START" then
        local encounterID, encounterName, difficultyID, groupSize = ...
        TalentReminder.OnEncounterStart(encounterID, encounterName, difficultyID)
    elseif event == "ENCOUNTER_END" then
        -- Optional: future functionality
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED" then
        -- Re-check talents if in instance with reminders
        addonTable.Core.SafeAfter(0.5, function()
            TalentReminder.CheckTalentsInInstance()
        end)
    end
end

-- On entering world/instance
function TalentReminder.OnEnteringWorld()
    print("DEBUG OnEnteringWorld: Called")

    -- Clear snooze list
    snoozed = {}

    -- Update current instance info
    local name, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    currentInstanceID = instanceID
    currentDifficultyID = difficultyID

    print("DEBUG OnEnteringWorld: instanceID=" .. tostring(instanceID) ..
        " difficultyID=" .. tostring(difficultyID) ..
        " instanceType=" .. tostring(instanceType) ..
        " name=" .. tostring(name))

    -- Check if this is M+ and alert on entry
    if TalentReminder.IsMythicPlus() then
        print("DEBUG OnEnteringWorld: Is M+, scheduling check")
        addonTable.Core.SafeAfter(3, function()
            print("DEBUG: M+ check running after delay")
            TalentReminder.CheckTalentsOnMythicPlusEntry()
        end)
    else
        print("DEBUG OnEnteringWorld: Not M+, scheduling check")
        -- For non-M+ instances, check talents after a short delay
        addonTable.Core.SafeAfter(3, function()
            -- Re-fetch instance info in case difficulty changed
            local name, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
            currentInstanceID = instanceID
            currentDifficultyID = difficultyID
            print("DEBUG: Regular check running after delay, instanceID=" ..
                tostring(currentInstanceID) .. " difficultyID=" .. tostring(currentDifficultyID))
            TalentReminder.CheckTalentsInInstance()
        end)
    end
end

-- On boss encounter start
function TalentReminder.OnEncounterStart(encounterID, encounterName, difficultyID)
    if not UIThingsDB.talentReminders or not UIThingsDB.talentReminders.enabled then
        return
    end

    -- Check if we should alert for this difficulty
    if not TalentReminder.ShouldAlertForDifficulty(difficultyID) then
        return
    end

    -- Check if snoozed
    if snoozed[currentInstanceID] and snoozed[currentInstanceID][encounterID] then
        return
    end

    -- Get reminder for this boss/instance
    local reminder = TalentReminder.GetReminderForEncounter(currentInstanceID, difficultyID, encounterID)
    if not reminder then
        -- Try general instance reminder
        reminder = TalentReminder.GetReminderForEncounter(currentInstanceID, difficultyID, "general")
    end

    if reminder then
        local mismatches = TalentReminder.CompareTalents(reminder.talents)
        if #mismatches > 0 then
            TalentReminder.ShowAlert(reminder, mismatches, encounterID)
        end
    end
end

-- Check talents in instance (for talent changes)
function TalentReminder.CheckTalentsInInstance()
    print("DEBUG CheckTalentsInInstance: currentInstanceID=" ..
        tostring(currentInstanceID) .. " currentDifficultyID=" .. tostring(currentDifficultyID))

    if not currentInstanceID or currentInstanceID == 0 then
        print("DEBUG CheckTalentsInInstance: No instance or instanceID=0, returning")
        return
    end

    if not UIThingsDB.talentReminders or not UIThingsDB.talentReminders.enabled then
        print("DEBUG CheckTalentsInInstance: Feature disabled, returning")
        return
    end

    -- Check if we should alert for current difficulty
    if not TalentReminder.ShouldAlertForDifficulty(currentDifficultyID) then
        print("DEBUG CheckTalentsInInstance: Difficulty filter failed, returning")
        return
    end

    -- Get all reminders for this instance/difficulty
    local reminders = LunaUITweaks_TalentReminders.reminders[currentInstanceID]
    if not reminders or not reminders[currentDifficultyID] then
        print("DEBUG CheckTalentsInInstance: No reminders for this instance/difficulty, returning")
        return
    end

    print("DEBUG CheckTalentsInInstance: Found reminders, checking...")

    -- Check each reminder and show/hide alerts accordingly
    local foundMismatch = false
    for bossID, reminder in pairs(reminders[currentDifficultyID]) do
        -- Skip if snoozed
        if not (snoozed[currentInstanceID] and snoozed[currentInstanceID][bossID]) then
            local mismatches = TalentReminder.CompareTalents(reminder.talents)
            if #mismatches > 0 then
                -- Talents mismatch - show alert
                TalentReminder.ShowAlert(reminder, mismatches, bossID)
                foundMismatch = true
                break -- Only show one alert at a time
            end
        end
    end

    -- If no mismatches found, dismiss any open alert
    if not foundMismatch and alertFrame and alertFrame:IsShown() then
        alertFrame:Hide()
    end
end

-- Check talents on M+ entry
function TalentReminder.CheckTalentsOnMythicPlusEntry()
    if not UIThingsDB.talentReminders or not UIThingsDB.talentReminders.enabled then
        return
    end

    if not TalentReminder.ShouldAlertForDifficulty(currentDifficultyID) then
        return
    end

    -- Check all reminders for this instance
    local reminders = LunaUITweaks_TalentReminders.reminders[currentInstanceID]
    if not reminders or not reminders[currentDifficultyID] then
        return
    end

    -- Gather all mismatches across all bosses
    local allMismatches = {}
    local reminderName = nil

    for bossID, reminder in pairs(reminders[currentDifficultyID]) do
        if not snoozed[currentInstanceID] or not snoozed[currentInstanceID][bossID] then
            local mismatches = TalentReminder.CompareTalents(reminder.talents)
            if #mismatches > 0 then
                reminderName = reminder.name
                for _, mismatch in ipairs(mismatches) do
                    table.insert(allMismatches, mismatch)
                end
            end
        end
    end

    if #allMismatches > 0 then
        -- Create a cumulative reminder
        local cumulativeReminder = {
            name = reminderName or "Mythic+ Entry Check",
            note = "Multiple reminders detected for this instance",
        }
        TalentReminder.ShowAlert(cumulativeReminder, allMismatches, "general")
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
            print("DEBUG: Missing talent - " .. talentName .. " at nodeID=" .. tostring(nodeID) ..
                " (savedEntryID=" .. tostring(savedData.entryID) .. ", current=" .. currentInfo .. ")")
            table.insert(mismatches, {
                type = "missing",
                nodeID = nodeID,
                name = talentName,
                row = savedData.row,
                expected = savedData
            })
        elseif current.entryID ~= savedData.entryID then
            -- Different talent selected in this node - need to remove current and add expected
            print("DEBUG: Wrong talent choice at nodeID=" .. tostring(nodeID) ..
                " (expected entryID=" .. tostring(savedData.entryID) ..
                ", current entryID=" .. tostring(current.entryID) .. ")")

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
                row = savedData.row,
                expected = savedData,
                current = current
            })

            -- Add to "extra" (have wrong talent to remove)
            table.insert(mismatches, {
                type = "extra",
                nodeID = nodeID,
                name = currentTalentName,
                row = savedData.row,
                current = {
                    entryID = current.entryID,
                    rank = current.rank,
                    spellID = currentSpellID
                }
            })
        elseif current.rank < savedData.rank then
            -- Same talent but insufficient rank
            print("DEBUG: Insufficient rank - " .. talentName .. " at nodeID=" .. tostring(nodeID) ..
                " (expected rank=" .. tostring(savedData.rank) ..
                ", current rank=" .. tostring(current.rank) .. ")")
            table.insert(mismatches, {
                type = "wrong",
                nodeID = nodeID,
                name = talentName,
                row = savedData.row,
                expected = savedData,
                current = current
            })
        end
    end

    -- Find extra talents (talents you have but aren't in the saved build)
    print("DEBUG: Checking for extra talents")
    local extraCount = 0
    for nodeID, current in pairs(currentTalents) do
        if not savedTalents[nodeID] then
            -- Only count as extra if rank > 0
            if current.rank > 0 then
                extraCount = extraCount + 1
                print("DEBUG: Found extra talent at nodeID=" .. tostring(nodeID) .. " rank=" .. tostring(current.rank))

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

                print("DEBUG: Extra talent name=" .. tostring(talentName) .. " spellID=" .. tostring(spellID))

                table.insert(mismatches, {
                    type = "extra",
                    nodeID = nodeID,
                    name = talentName,
                    row = nodeInfo and nodeInfo.posY or 0,
                    current = {
                        entryID = current.entryID,
                        rank = current.rank,
                        spellID = spellID
                    }
                })
            end
        end
    end
    print("DEBUG: Found " .. extraCount .. " extra talents total")

    return mismatches
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
                    row = nodeInfo.posY or 0,
                    spellID = spellID
                }
                count = count + 1
            else
                skippedCount = skippedCount + 1
            end
        end
    end

    print("DEBUG CreateSnapshot: Saved " .. count .. " talents, skipped " .. skippedCount .. " with rank=0")
    return snapshot, nil, count
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
    local snapshot, err, count = TalentReminder.CreateSnapshot()
    if err then
        return false, err
    end

    LunaUITweaks_TalentReminders.reminders[instanceID] = LunaUITweaks_TalentReminders.reminders[instanceID] or {}
    LunaUITweaks_TalentReminders.reminders[instanceID][difficultyID] = LunaUITweaks_TalentReminders.reminders
        [instanceID][difficultyID] or {}

    LunaUITweaks_TalentReminders.reminders[instanceID][difficultyID][bossID] = {
        name = name,
        instanceName = instanceName,
        difficulty = difficulty,
        difficultyID = difficultyID,
        createdDate = date("%Y-%m-%d"),
        note = note or "",
        talents = snapshot
    }

    return true, nil, count
end

-- Delete reminder
function TalentReminder.DeleteReminder(instanceID, difficultyID, bossID)
    if LunaUITweaks_TalentReminders.reminders[instanceID] and
        LunaUITweaks_TalentReminders.reminders[instanceID][difficultyID] then
        LunaUITweaks_TalentReminders.reminders[instanceID][difficultyID][bossID] = nil
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
function TalentReminder.ShowAlert(reminder, mismatches, bossID)
    print("DEBUG ShowAlert: Called with " .. #mismatches .. " mismatches, alertFrame=" .. tostring(alertFrame))
    if not alertFrame then
        print("DEBUG ShowAlert: alertFrame is nil, returning")
        return
    end

    -- Play sound
    print("DEBUG ShowAlert: Checking sound...")
    if UIThingsDB.talentReminders and UIThingsDB.talentReminders.playSound then
        PlaySound(8959) -- SOUNDKIT.RAID_WARNING
    end
    print("DEBUG ShowAlert: Sound done")

    -- TTS announcement (first missing talent)
    print("DEBUG ShowAlert: Checking TTS...")
    if UIThingsDB.talentReminders and UIThingsDB.talentReminders.useTTS then
        for _, mismatch in ipairs(mismatches) do
            if mismatch.type == "missing" then
                PlaySound(8959) -- SOUNDKIT.RAID_WARNING
                break
            end
        end
    end
    print("DEBUG ShowAlert: TTS done")

    -- Chat message
    print("DEBUG ShowAlert: Checking chat message...")
    if UIThingsDB.talentReminders and UIThingsDB.talentReminders.showChatMessage then
        local missingCount = 0
        local wrongCount = 0
        local extraCount = 0
        for _, m in ipairs(mismatches) do
            if m.type == "missing" then
                missingCount = missingCount + 1
            elseif m.type == "wrong" then
                wrongCount = wrongCount + 1
            elseif m.type == "extra" then
                extraCount = extraCount + 1
            end
        end
        print(string.format("|cFFFF0000[LunaUITweaks]|r ⚠️ Talent mismatch for %s: %d missing, %d incorrect, %d extra.",
            reminder.name, missingCount, wrongCount, extraCount))
    end
    print("DEBUG ShowAlert: Chat message done")

    -- Show popup
    print("DEBUG ShowAlert: showPopup=" .. tostring(UIThingsDB.talentReminders and UIThingsDB.talentReminders.showPopup))
    if UIThingsDB.talentReminders and UIThingsDB.talentReminders.showPopup then
        print("DEBUG ShowAlert: Calling UpdateAlertFrame and showing window")
        TalentReminder.UpdateAlertFrame(reminder, mismatches, bossID)
        alertFrame:Show()
        print("DEBUG ShowAlert: Window shown, isShown=" .. tostring(alertFrame:IsShown()))
    end
end

-- Update visual appearance only
function TalentReminder.UpdateVisuals()
    if not alertFrame then return end

    -- Apply font settings
    local font = UIThingsDB.talentReminders.alertFont or "Fonts\\FRIZQT__.TTF"
    local fontSize = UIThingsDB.talentReminders.alertFontSize or 12
    alertFrame.content:SetFont(font, fontSize)

    -- Apply visual settings (Backdrop)
    local showBorder = UIThingsDB.talentReminders.showBorder
    local showBackground = UIThingsDB.talentReminders.showBackground
    
    if showBorder or showBackground then
        alertFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        
        -- Background
        if showBackground then
            local c = UIThingsDB.talentReminders.backgroundColor or {r=0, g=0, b=0, a=0.8}
            alertFrame:SetBackdropColor(c.r, c.g, c.b, c.a)
        else
            alertFrame:SetBackdropColor(0, 0, 0, 0)
        end
        
        -- Border
        if showBorder then
            local bc = UIThingsDB.talentReminders.borderColor or {r=1, g=1, b=1, a=1}
            alertFrame:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
        else
            alertFrame:SetBackdropBorderColor(0, 0, 0, 0)
        end
    else
        alertFrame:SetBackdrop(nil)
    end
end

-- Update alert frame content
function TalentReminder.UpdateAlertFrame(reminder, mismatches, bossID)
    if not alertFrame then return end

    TalentReminder.UpdateVisuals()

    alertFrame.title:SetText("⚠️ TALENT REMINDER")
    alertFrame.bossName:SetText(reminder.name)

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
        print("DEBUG: Building missing section with " .. #missing .. " talents")
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
        print("DEBUG: Displaying " .. #wrong .. " wrong talents")
        text = text .. "\n|cFFFFAA00Wrong Selection:|r\n"
        for _, m in ipairs(wrong) do
            -- Try to resolve name again if unknown
            local name = m.name
            local spellID = m.expected and m.expected.spellID
            print("DEBUG Wrong display: name=" ..
                tostring(name) .. " spellID=" .. tostring(spellID) .. " row=" .. tostring(m.row))

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

            print("DEBUG Wrong display after lookup: name=" .. tostring(name))

            -- Get spell icon
            local icon = ""
            if spellID then
                local iconSize = UIThingsDB.talentReminders.alertIconSize or 16
                local spellTexture = C_Spell and C_Spell.GetSpellTexture(spellID) or GetSpellTexture(spellID)
                if spellTexture then
                    icon = string.format("|T%s:%d:%d:0:0|t ", spellTexture, iconSize, iconSize)
                end
                print("DEBUG Wrong display icon: " .. tostring(icon))
            end

            local line = string.format("  • %sNeed %s (rank %d)\n", icon, name, m.expected.rank)
            print("DEBUG Wrong display line: " .. line)
            text = text .. line
        end
    end

    if #extra > 0 then
        print("DEBUG: Building extra section with " .. #extra .. " talents")
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

    print("DEBUG: Final text length: " .. string.len(text))
    print("DEBUG: Setting alert text...")
    alertFrame.content:SetText(text)
    alertFrame.bossID = bossID
end

-- Create alert frame
function TalentReminder.CreateAlertFrame()
    if alertFrame then return end

    alertFrame = CreateFrame("Frame", "LunaTalentReminderAlert", UIParent, "BackdropTemplate")
    alertFrame:SetSize(400, 300)
    alertFrame:SetPoint("CENTER")
    alertFrame:SetFrameStrata("DIALOG")
    
    -- Default Backdrop (will be updated by UpdateAlertFrame)
    alertFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    alertFrame:EnableMouse(true)
    alertFrame:SetMovable(true)
    alertFrame:RegisterForDrag("LeftButton")
    alertFrame:SetScript("OnDragStart", alertFrame.StartMoving)
    alertFrame:SetScript("OnDragStop", alertFrame.StopMovingOrSizing)
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

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(360, 150)
    scrollFrame:SetScrollChild(scrollChild)

    alertFrame.content = scrollChild:CreateFontString(nil, "OVERLAY")
    alertFrame.content:SetPoint("TOPLEFT", 5, -5)
    alertFrame.content:SetWidth(340)
    alertFrame.content:SetJustifyH("LEFT")
    alertFrame.content:SetJustifyV("TOP")

    -- Apply font settings
    local font = UIThingsDB.talentReminders.alertFont or "Fonts\\FRIZQT__.TTF"
    local fontSize = UIThingsDB.talentReminders.alertFontSize or 12
    alertFrame.content:SetFont(font, fontSize)

    -- Snooze button
    local snoozeBtn = CreateFrame("Button", nil, alertFrame, "GameMenuButtonTemplate")
    snoozeBtn:SetSize(120, 25)
    snoozeBtn:SetPoint("BOTTOMLEFT", 20, 20)
    snoozeBtn:SetText("Snooze")
    snoozeBtn:SetNormalFontObject("GameFontNormal")
    snoozeBtn:SetHighlightFontObject("GameFontHighlight")
    snoozeBtn:SetScript("OnClick", function(self)
        local bossID = alertFrame.bossID
        if bossID then
            snoozed[currentInstanceID] = snoozed[currentInstanceID] or {}
            snoozed[currentInstanceID][bossID] = true
            addonTable.Core.Log("TalentReminder", "Snoozed reminder for boss " .. tostring(bossID))
        end
        alertFrame:Hide()
    end)

    -- Dismiss button
    local dismissBtn = CreateFrame("Button", nil, alertFrame, "GameMenuButtonTemplate")
    dismissBtn:SetSize(120, 25)
    dismissBtn:SetPoint("BOTTOM", 0, 20)
    dismissBtn:SetText("Dismiss")
    dismissBtn:SetNormalFontObject("GameFontNormal")
    dismissBtn:SetHighlightFontObject("GameFontHighlight")
    dismissBtn:SetScript("OnClick", function(self)
        alertFrame:Hide()
    end)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, alertFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
end

-- Get current location info (for snapshot UI)
function TalentReminder.GetCurrentLocation()
    local name, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    local difficultyName = GetDifficultyInfo(difficultyID) or "Unknown"

    return {
        instanceID = instanceID,
        instanceName = name,
        instanceType = instanceType,
        difficultyID = difficultyID,
        difficultyName = difficultyName,
        -- Boss detection would go here if available
        bossID = nil,
        bossName = nil
    }
end
