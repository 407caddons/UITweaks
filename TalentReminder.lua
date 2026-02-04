local addonName, addonTable = ...
addonTable.TalentReminder = {}

local TalentReminder = addonTable.TalentReminder
local snoozed = {} -- Session-only snooze tracking: [instanceID][bossID] = true
local alertFrame -- Popup alert frame
local currentInstanceID, currentDifficultyID

-- Initialize saved variables
function TalentReminder.Initialize()
    LunaUITweaks_TalentReminders = LunaUITweaks_TalentReminders or {
        version = 1,
        reminders = {}
    }
    
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
    -- Clear snooze list
    snoozed = {}
    
    -- Update current instance info
    local name, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    currentInstanceID = instanceID
    currentDifficultyID = difficultyID
    
    -- Check if this is M+ and alert on entry
    if TalentReminder.IsMythicPlus() then
        addonTable.Core.SafeAfter(1, function()
            TalentReminder.CheckTalentsOnMythicPlusEntry()
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
    if not currentInstanceID or currentInstanceID == 0 then
        return
    end
    
    if not UIThingsDB.talentReminders or not UIThingsDB.talentReminders.enabled then
        return
    end
    
    -- Check if we should alert for current difficulty
    if not TalentReminder.ShouldAlertForDifficulty(currentDifficultyID) then
        return
    end
    
    -- Get all reminders for this instance/difficulty
    local reminders = LunaUITweaks_TalentReminders.reminders[currentInstanceID]
    if not reminders or not reminders[currentDifficultyID] then
        return
    end
    
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
        if (not talentName or talentName == "Unknown Talent") and savedData.entryID then
            talentName = TalentReminder.GetTalentName(savedData.entryID, configID) or "Unknown Talent"
        end
        
        if not current then
            -- Missing talent
            table.insert(mismatches, {
                type = "missing",
                nodeID = nodeID,
                name = talentName,
                row = savedData.row,
                expected = savedData
            })
        elseif current.entryID ~= savedData.entryID or current.rank < savedData.rank then
            -- Wrong selection or insufficient rank
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
    
    return mismatches
end

-- Helper to resolve talent name
function TalentReminder.GetTalentName(entryID, configID)
    if not entryID then return "Unknown Talent" end
    
    -- If configID not provided, try to get active one
    if not configID and C_ClassTalents then
        configID = C_ClassTalents.GetActiveConfigID()
    end
    
    if not configID then 
        print("DEBUG: No ConfigID found")
        return "Unknown Talent" 
    end
    
    local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
    if not entryInfo then
        print("DEBUG: No entryInfo for entryID " .. tostring(entryID))
        return "Unknown Talent"
    end

    if not entryInfo.definitionID then
        print("DEBUG: No definitionID for entryID " .. tostring(entryID))
        return "Unknown Talent"
    end
    
    local definitionInfo = C_Traits.GetDefinitionInfo(configID, entryInfo.definitionID)
    if not definitionInfo then
        print("DEBUG: No definitionInfo for defID " .. tostring(entryInfo.definitionID))
        return "Unknown Talent"
    end
    
    -- Try overrideName first
    if definitionInfo.overrideName and definitionInfo.overrideName ~= "" then
        return definitionInfo.overrideName
    end
    
    -- Fall back to spell name from spellID
    if definitionInfo.spellID then
        local spellName
        if C_Spell and C_Spell.GetSpellName then
            spellName = C_Spell.GetSpellName(definitionInfo.spellID)
        elseif GetSpellInfo then
            spellName = GetSpellInfo(definitionInfo.spellID)
        end
        
        if spellName then
            return spellName
        else
            print("DEBUG: Name fetch failed for spellID " .. tostring(definitionInfo.spellID))
        end
    else
        print("DEBUG: No spellID for defID " .. tostring(entryInfo.definitionID))
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
    
    for _, nodeID in ipairs(nodes) do
        local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
        if nodeInfo and nodeInfo.activeEntry then
            local entryInfo = C_Traits.GetEntryInfo(configID, nodeInfo.activeEntry.entryID)
            
            -- Get talent name from the definition
            -- Get talent name using helper
            local talentName = TalentReminder.GetTalentName(nodeInfo.activeEntry.entryID, configID)
            
            snapshot[nodeID] = {
                name = talentName,
                entryID = nodeInfo.activeEntry.entryID,
                rank = nodeInfo.currentRank or 0,
                row = nodeInfo.posY or 0
            }
            count = count + 1
        end
    end
    
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
    LunaUITweaks_TalentReminders.reminders[instanceID][difficultyID] = LunaUITweaks_TalentReminders.reminders[instanceID][difficultyID] or {}
    
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
    if not alertFrame then
        return
    end
    
    -- Play sound
    if UIThingsDB.talentReminders and UIThingsDB.talentReminders.playSound then
        PlaySound(8959) -- SOUNDKIT.RAID_WARNING
    end
    
    -- TTS announcement (first missing talent)
    if UIThingsDB.talentReminders and UIThingsDB.talentReminders.useTTS then
        for _, mismatch in ipairs(mismatches) do
            if mismatch.type == "missing" then
                TalentReminder.SpeakMissingTalent(mismatch.name)
                break
            end
        end
    end
    
    -- Chat message
    if UIThingsDB.talentReminders and UIThingsDB.talentReminders.showChatMessage then
        local missingCount = 0
        local wrongCount = 0
        for _, m in ipairs(mismatches) do
            if m.type == "missing" then
                missingCount = missingCount + 1
            else
                wrongCount = wrongCount + 1
            end
        end
        print(string.format("|cFFFF0000[LunaUITweaks]|r ⚠️ Talent mismatch for %s: %d missing, %d incorrect.", 
            reminder.name, missingCount, wrongCount))
    end
    
    -- Show popup
    if UIThingsDB.talentReminders and UIThingsDB.talentReminders.showPopup then
        TalentReminder.UpdateAlertFrame(reminder, mismatches, bossID)
        alertFrame:Show()
    end
end

-- Update alert frame content
function TalentReminder.UpdateAlertFrame(reminder, mismatches, bossID)
    if not alertFrame then return end
    
    alertFrame.title:SetText("⚠️ TALENT REMINDER")
    alertFrame.bossName:SetText(reminder.name)
    
    -- Build mismatch text
    local text = ""
    local missing = {}
    local wrong = {}
    
    for _, m in ipairs(mismatches) do
        if m.type == "missing" then
            table.insert(missing, m)
        else
            table.insert(wrong, m)
        end
    end
    
    if #missing > 0 then
        text = text .. "|cFFFF6B6BMissing Talents:|r\n"
        for _, m in ipairs(missing) do
            -- Try to resolve name again if unknown
            local name = m.name
            if (not name or name == "Unknown Talent") and m.expected and m.expected.entryID then
                name = TalentReminder.GetTalentName(m.expected.entryID) or name
            end
            text = text .. string.format("  • %s (Row %d)\n", name, m.row)
        end
    end
    
    if #wrong > 0 then
        text = text .. "\n|cFFFFAA00Wrong Selection:|r\n"
        for _, m in ipairs(wrong) do
            -- Try to resolve name again if unknown
            local name = m.name
            if (not name or name == "Unknown Talent") and m.expected and m.expected.entryID then
                name = TalentReminder.GetTalentName(m.expected.entryID) or name
            end
            text = text .. string.format("  • Row %d: Need %s (rank %d)\n", m.row, name, m.expected.rank)
        end
    end
    
    if reminder.note and reminder.note ~= "" then
        text = text .. "\n|cFF00FF00Note:|r " .. reminder.note
    end
    
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
    alertFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
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
    
    alertFrame.content = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    alertFrame.content:SetPoint("TOPLEFT", 5, -5)
    alertFrame.content:SetWidth(340)
    alertFrame.content:SetJustifyH("LEFT")
    alertFrame.content:SetJustifyV("TOP")
    
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

-- TTS speak missing talent
function TalentReminder.SpeakMissingTalent(talentName)
    if not C_VoiceChat or not C_VoiceChat.SpeakText then
        return
    end
    
    local message = talentName .. " missing"
    local voice = (UIThingsDB.talentReminders and UIThingsDB.talentReminders.ttsVoice) or 
                  (UIThingsDB.misc and UIThingsDB.misc.ttsVoice) or 0
    local volume = (UIThingsDB.talentReminders and UIThingsDB.talentReminders.ttsVolume) or 1.0
    
    C_VoiceChat.SpeakText(
        voice,
        message,
        Enum.VoiceTtsDestination.LocalPlayback,
        volume,
        0
    )
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
