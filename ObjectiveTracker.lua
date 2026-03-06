local addonName, addonTable = ...
addonTable.ObjectiveTracker = {}

local SafeAfter = addonTable.Core and addonTable.Core.SafeAfter or function(delay, func)
    C_Timer.After(delay, function() local ok, err = pcall(func) if not ok then print("|cffff0000LunaUITweaks error:|r " .. tostring(err)) end end)
end

local trackerFrame
local scrollFrame
local scrollChild
local headerFrame
local SetupTrackerEvents
local UpdateContent
local autoTrackFrame
local distanceTicker
local trackerHiddenByKeybind = false

-- Blizzard quest sound file IDs to mute when custom sounds are active
local QUEST_SOUND_FILES = {
    567439, -- Sound/Interface/iQuestComplete.ogg
    567400, -- Sound/Interface/iQuestUpdate.ogg
}
local questSoundsMuted = false

-- Global secure button for keybind: use super-tracked quest item
local questItemButton = CreateFrame("Button", "LunaQuestItemButton", UIParent, "SecureActionButtonTemplate")
questItemButton:Hide()
questItemButton:RegisterForClicks("AnyUp", "AnyDown")

local pendingQuestItemUpdate = false
local function UpdateQuestItemButton()
    if InCombatLockdown() then
        pendingQuestItemUpdate = true
        return
    end
    local questID = C_SuperTrack.GetSuperTrackedQuestID()
    if questID and questID ~= 0 then
        local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
        if logIndex then
            local questItemLink = GetQuestLogSpecialItemInfo(logIndex)
            if questItemLink then
                questItemButton:SetAttribute("type", "item")
                questItemButton:SetAttribute("item", questItemLink)
                return
            end
        end
    end
    questItemButton:SetAttribute("type", nil)
    questItemButton:SetAttribute("item", nil)
end

-- Toggle Button Factory (Yellow +/-)
local function CreateToggleButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(30, 30)
    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 25, "OUTLINE")
    text:SetPoint("CENTER", 0, 0)
    text:SetShadowOffset(1, -1)
    text:SetTextColor(1, 0.82, 0)
    btn.Text = text
    return btn
end

local function OnQuestClick(self, button)
    if button == "LeftButton" and IsShiftKeyDown() and self.questID and type(self.questID) == "number" and UIThingsDB.tracker.shiftClickLink then
        local questLink = GetQuestLink(self.questID)
        if questLink and ChatFrame1EditBox:IsShown() then
            ChatFrame1EditBox:Insert(questLink)
        elseif questLink then
            ChatFrame_OpenChat(questLink)
        end
        return
    end

    if button == "LeftButton" and IsControlKeyDown() and self.questID and type(self.questID) == "number" and UIThingsDB.tracker.shiftClickUntrack then
        C_QuestLog.RemoveQuestWatch(self.questID)
        SafeAfter(0.1, addonTable.ObjectiveTracker.UpdateContent)
        return
    end

    if button == "MiddleButton" and self.questID and type(self.questID) == "number" and UIThingsDB.tracker.middleClickShare then
        if IsInGroup() and C_QuestLog.IsPushableQuest(self.questID) then
            C_QuestLog.SetSelectedQuest(self.questID)
            QuestLogPushQuest()
        end
        return
    end

    if button == "RightButton" and self.questID and type(self.questID) == "number" and UIThingsDB.tracker.rightClickSuperTrack then
        if C_SuperTrack.GetSuperTrackedQuestID() == self.questID then
            C_SuperTrack.ClearAllSuperTracked()
        else
            C_SuperTrack.SetSuperTrackedQuestID(self.questID)
        end
        SafeAfter(0.1, addonTable.ObjectiveTracker.UpdateContent)
        return
    end

    if button == "LeftButton" and not InCombatLockdown() and self.questID and type(self.questID) == "number" then
        local questID = self.questID
        if C_QuestLog.IsComplete(questID) then
            local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
            local isAutoComplete = false
            if logIndex then
                local info = C_QuestLog.GetInfo(logIndex)
                if info then isAutoComplete = info.isAutoComplete or false end
                if not isAutoComplete and GetQuestLogIsAutoComplete then
                    isAutoComplete = GetQuestLogIsAutoComplete(logIndex) == 1
                end
            end
            if isAutoComplete then
                ShowQuestComplete(questID)
                return
            end
        end
    end

    if not InCombatLockdown() and self.questID and type(self.questID) == "number" and UIThingsDB.tracker.clickOpenQuest then
        if QuestMapFrame_OpenToQuestDetails then
            if not QuestMapFrame:IsShown() then ToggleQuestLog() end
            QuestMapFrame_OpenToQuestDetails(self.questID)
        else
            QuestLog_OpenToQuest(self.questID)
        end
    end
end

local function OnAchieveClick(self, button)
    if InCombatLockdown() and button == "LeftButton" then return end

    if IsShiftKeyDown() and self.achieID and UIThingsDB.tracker.shiftClickUntrack then
        if C_ContentTracking and C_ContentTracking.StopTracking then
            C_ContentTracking.StopTracking(Enum.ContentTrackingType.Achievement, self.achieID,
                Enum.ContentTrackingStopType.Manual)
        else
            RemoveTrackedAchievement(self.achieID)
        end
        SafeAfter(0.1, addonTable.ObjectiveTracker.UpdateContent)
        return
    end

    if self.achieID then
        if not AchievementFrame then AchievementFrame_LoadUI() end
        if AchievementFrame then
            AchievementFrame_ToggleAchievementFrame()
            AchievementFrame_SelectAchievement(self.achieID)
        end
    end
end

local function OnPerksActivityClick(self, button)
    if IsShiftKeyDown() and self.perksActivityID and UIThingsDB.tracker.shiftClickUntrack then
        if C_PerksActivities and C_PerksActivities.RemoveTrackedPerksActivity then
            C_PerksActivities.RemoveTrackedPerksActivity(self.perksActivityID)
            SafeAfter(0.1, addonTable.ObjectiveTracker.UpdateContent)
        end
        return
    end
end

local itemPool = {}

local function AcquireItem()
    for _, btn in ipairs(itemPool) do
        if btn.released then
            btn.released = false
            return btn
        end
    end

    local btn = CreateFrame("Button", nil, scrollChild)
    btn:SetHeight(20)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", 0, 0)
    btn.Icon = icon

    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    text:SetPoint("RIGHT", 0, 0)
    text:SetJustifyH("LEFT")
    btn.Text = text

    local toggleBtn = CreateToggleButton(btn)
    toggleBtn:SetPoint("LEFT", text, "RIGHT", 5, 0)
    toggleBtn:Hide()
    btn.ToggleBtn = toggleBtn

    local itemBtn = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    itemBtn:SetSize(20, 20)
    itemBtn:Hide()
    itemBtn:RegisterForClicks("AnyUp", "AnyDown")
    itemBtn:SetFrameLevel(btn:GetFrameLevel() + 2)
    itemBtn.iconTex = itemBtn:CreateTexture(nil, "ARTWORK")
    itemBtn.iconTex:SetAllPoints()
    itemBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    btn.ItemBtn = itemBtn

    local progressBar = CreateFrame("StatusBar", nil, btn)
    progressBar:SetSize(0, 3)
    progressBar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 19, -2)
    progressBar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -25, -2)
    progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    progressBar:SetStatusBarColor(1, 0.82, 0, 1)
    progressBar:SetMinMaxValues(0, 100)
    progressBar:SetValue(0)
    progressBar:Hide()
    local progressBg = progressBar:CreateTexture(nil, "BACKGROUND")
    progressBg:SetAllPoints(progressBar)
    progressBg:SetColorTexture(0, 0, 0, 0.5)
    progressBar.bg = progressBg
    btn.ProgressBar = progressBar

    table.insert(itemPool, btn)
    return btn
end

local function ReleaseItems()
    local inCombat = InCombatLockdown()
    for _, btn in ipairs(itemPool) do
        btn.released = true
        btn:Hide()
        btn:SetScript("OnClick", nil)
        btn:SetScript("OnEnter", nil)
        btn:SetScript("OnLeave", nil)
        btn.Icon:Hide()
        btn.Text:SetText("")
        if btn.ToggleBtn then btn.ToggleBtn:Hide() end
        if btn.ItemBtn and not inCombat then
            btn.ItemBtn:ClearAllPoints()
            btn.ItemBtn:Hide()
            btn.ItemBtn:SetAttribute("type", nil)
            btn.ItemBtn:SetAttribute("item", nil)
        end
        if btn.ProgressBar then btn.ProgressBar:Hide() end
    end
end

local ucState = {}

local MINUTES_PER_DAY = 1440
local MINUTES_PER_HOUR = 60
local UPDATE_THROTTLE_DELAY = 0.1
local SECTION_SPACING = 10
local ITEM_SPACING = 5

local function GetObjectiveProgress(objectiveText)
    if not objectiveText then return 0, false end
    local percentMatch = objectiveText:match("(%d+)%%")
    if percentMatch then return tonumber(percentMatch), true end
    local current, total = objectiveText:match("(%d+)/(%d+)")
    if current and total then
        current, total = tonumber(current), tonumber(total)
        if total > 0 then return (current / total) * 100, true end
    end
    return 0, false
end

local function FormatCompletedObjective(text)
    if UIThingsDB.tracker.completedObjectiveCheckmark then
        return "|cFF00FF00|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t " .. text .. "|r"
    else
        return "|cFF00FF00" .. text .. "|r"
    end
end

local function GetCampaignColor(questID)
    if not UIThingsDB.tracker.highlightCampaignQuests then return nil end
    if C_CampaignInfo and C_CampaignInfo.IsCampaignQuest and C_CampaignInfo.IsCampaignQuest(questID) then
        return UIThingsDB.tracker.campaignQuestColor
    end
    return nil
end

local function GetQuestTypePrefix(questID)
    if not UIThingsDB.tracker.showQuestTypeIndicators then return "" end
    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    if logIndex then
        local info = C_QuestLog.GetInfo(logIndex)
        if info and info.frequency then
            if info.frequency == Enum.QuestFrequency.Daily then return "|cFF00CCFF[D]|r " end
            if info.frequency == Enum.QuestFrequency.Weekly then return "|cFFCC00FF[W]|r " end
        end
    end
    if C_QuestLog.IsRepeatableQuest and C_QuestLog.IsRepeatableQuest(questID) then
        return "|cFF00CCFF[R]|r "
    end
    return ""
end

local function GetWQRewardIcon(questID)
    if not UIThingsDB.tracker.showWQRewardIcons then return "" end
    local ok, numRewards = pcall(function() return GetNumQuestLogRewards(questID) end)
    numRewards = ok and numRewards or 0
    local currencies = {}
    if C_QuestLog.GetQuestRewardCurrencies then
        local cOk, result = pcall(C_QuestLog.GetQuestRewardCurrencies, questID)
        if cOk and result then currencies = result end
    end
    local goldReward = 0
    if GetQuestLogRewardMoney then
        local gOk, result = pcall(GetQuestLogRewardMoney, questID)
        if gOk and result then goldReward = result end
    end
    if numRewards > 0 then return "|TInterface\\Minimap\\Tracking\\Banker:0|t " end
    if #currencies > 0 then return "|TInterface\\Minimap\\Tracking\\Auctioneer:0|t " end
    if goldReward > 0 then return "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t " end
    return ""
end

local function GetTimeLeftString(questID)
    local timeLeftMinutes = C_TaskQuest.GetQuestTimeLeftMinutes(questID)
    if timeLeftMinutes and timeLeftMinutes > 0 then
        local days = math.floor(timeLeftMinutes / MINUTES_PER_DAY)
        local hours = math.floor((timeLeftMinutes % MINUTES_PER_DAY) / MINUTES_PER_HOUR)
        local minutes = timeLeftMinutes % 60
        local timeStr
        if days > 0 then timeStr = string.format("(%dd %dh)", days, hours)
        elseif hours > 0 then timeStr = string.format("(%dh %dm)", hours, minutes)
        else timeStr = string.format("(%dm)", minutes) end
        local color
        if timeLeftMinutes > 240 then color = "00FF00"
        elseif timeLeftMinutes > 60 then color = "FFFF00"
        elseif timeLeftMinutes > 15 then color = "FF8800"
        else color = "FF0000" end
        return string.format(" |cFF%s%s|r", color, timeStr)
    end
    return ""
end

local useMetric = not (GetLocale() == "enUS" or GetLocale() == "enGB")
local function GetDistanceString(questID)
    if not UIThingsDB.tracker.showQuestDistance then return "" end
    local distSq = C_QuestLog.GetDistanceSqToQuest(questID)
    if not distSq then return "" end
    local dist = math.sqrt(distSq)
    local unit = "yds"
    if useMetric then dist = dist * 0.9144; unit = "m" end
    if dist >= 1000 then
        return string.format(" |cFFAAAAAA(%.1fk %s)|r", dist / 1000, unit)
    else
        return string.format(" |cFFAAAAAA(%d %s)|r", dist, unit)
    end
end

local questLineCache = {}
local function GetQuestLineString(questID)
    if not UIThingsDB.tracker.showQuestLineProgress then return "" end
    if not C_QuestLine or not C_QuestLine.GetQuestLineInfo then return "" end
    local cached = questLineCache[questID]
    if cached and cached.expiry > GetTime() then return cached.str end
    local mapID = C_Map.GetBestMapForUnit("player")
    local lineInfo = C_QuestLine.GetQuestLineInfo(questID, mapID)
    if not lineInfo or not lineInfo.questLineID then
        questLineCache[questID] = { str = "", expiry = GetTime() + 30 }
        return ""
    end
    local quests = C_QuestLine.GetQuestLineQuests(lineInfo.questLineID)
    if not quests or #quests == 0 then
        questLineCache[questID] = { str = "", expiry = GetTime() + 30 }
        return ""
    end
    local currentStep = 0
    local totalSteps = #quests
    for i, qID in ipairs(quests) do
        if qID == questID then currentStep = i; break end
    end
    if currentStep == 0 then
        local completed = 0
        for _, qID in ipairs(quests) do
            if C_QuestLog.IsQuestFlaggedCompleted(qID) then completed = completed + 1 end
        end
        currentStep = completed + 1
    end
    local str = string.format(" |cFF888888(%d/%d)|r", currentStep, totalSteps)
    questLineCache[questID] = { str = str, expiry = GetTime() + 30 }
    return str
end

-- Quest/objective completion sound tracking
local prevObjectiveState = {}
local prevQuestComplete = {}
local tooltipMembers = {}

-- Super-track restore
local savedSuperTrackedQuestID = nil
local lastKnownSuperTrackedQuestID = nil
local proximityTrackedWQ = nil -- WQ questID we manually set due to area entry

-- Set by UpdateContent so RenderQuests knows to exclude campaign quests
local campaignQuestsSectionActive = false

-- Reusable scratch tables (wiped each UpdateContent call)
local displayedIDs = {}
local activeWQs = {}
local otherWQs = {}
local validWQs = {}
local hiddenTaskQuests = {}
local filteredIndices = {}
local validAchievements = {}
local zoneOrder = {}
local questsByZone = {}
local campaignOrder = {}
local questsByCampaign = {}
local nonCampaignQuests = {}

local function sortByDistanceSq(a, b)
    local distA = C_QuestLog.GetDistanceSqToQuest(a) or 99999999
    local distB = C_QuestLog.GetDistanceSqToQuest(b) or 99999999
    return distA < distB
end

local function sortByTimeLeft(a, b)
    local timeA = C_TaskQuest.GetQuestTimeLeftMinutes(a) or 99999
    local timeB = C_TaskQuest.GetQuestTimeLeftMinutes(b) or 99999
    return timeA < timeB
end

local function sortWatchIndexByDistance(a, b)
    local qA = C_QuestLog.GetQuestIDForQuestWatchIndex(a)
    local qB = C_QuestLog.GetQuestIDForQuestWatchIndex(b)
    local distA = qA and C_QuestLog.GetDistanceSqToQuest(qA) or 99999999
    local distB = qB and C_QuestLog.GetDistanceSqToQuest(qB) or 99999999
    return distA < distB
end

-- Returns the nearest tracked, unfinished campaign quest ID, or nil.
local function FindNearestTrackedCampaignQuest()
    local best, bestDistSq = nil, math.huge
    local numWatches = C_QuestLog.GetNumQuestWatches()
    for i = 1, numWatches do
        local qID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if qID then
            local isCampaign = C_CampaignInfo and C_CampaignInfo.IsCampaignQuest and C_CampaignInfo.IsCampaignQuest(qID)
            local isComplete = C_QuestLog.IsComplete(qID)
            if isCampaign and not isComplete then
                local d = C_QuestLog.GetDistanceSqToQuest(qID) or math.huge
                if d < bestDistSq then
                    bestDistSq = d
                    best = qID
                end
            end
        end
    end
    return best
end

local function CheckQuestSounds(questID, playQuestSound, playObjSound)
    local isComplete = C_QuestLog.IsComplete(questID)
    local wasComplete = prevQuestComplete[questID]
    local channel = UIThingsDB.tracker.soundChannel or "Master"

    if playQuestSound and isComplete and wasComplete == false then
        PlaySound(UIThingsDB.tracker.questCompletionSoundID or 6199, channel)
    end

    if isComplete and wasComplete == false
        and UIThingsDB.tracker.autoTrackQuests
        and C_CampaignInfo and C_CampaignInfo.IsCampaignQuest and C_CampaignInfo.IsCampaignQuest(questID) then
        SafeAfter(1.5, function()
            if InCombatLockdown() then return end
            local stNow = C_SuperTrack.GetSuperTrackedQuestID()
            if stNow and stNow ~= 0
                and stNow ~= questID
                and C_CampaignInfo.IsCampaignQuest(stNow)
                and C_QuestLog.IsOnQuest(stNow) then
                return
            end
            local nearest = FindNearestTrackedCampaignQuest()
            if nearest then
                C_SuperTrack.SetSuperTrackedQuestID(nearest)
            end
        end)
    end

    prevQuestComplete[questID] = isComplete

    if playObjSound and not isComplete then
        local objectives = C_QuestLog.GetQuestObjectives(questID)
        if objectives then
            if not prevObjectiveState[questID] then
                prevObjectiveState[questID] = {}
            end
            for j, obj in ipairs(objectives) do
                local prev = prevObjectiveState[questID][j]
                if prev and not prev.finished and obj.finished then
                    PlaySound(UIThingsDB.tracker.objectiveCompletionSoundID or 6197, channel)
                end
                prevObjectiveState[questID][j] = { finished = obj.finished }
            end
        end
    end
end

local function CheckCompletionSounds()
    if not UIThingsDB.tracker.enabled then return end
    local playQuestSound = UIThingsDB.tracker.questCompletionSound
    local playObjSound = UIThingsDB.tracker.objectiveCompletionSound
    local doAutoTrack = UIThingsDB.tracker.autoTrackQuests
    if not playQuestSound and not playObjSound and not doAutoTrack then return end

    local checked = {}

    local numWatches = C_QuestLog.GetNumQuestWatches()
    for i = 1, numWatches do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if questID and not checked[questID] then
            checked[questID] = true
            CheckQuestSounds(questID, playQuestSound, playObjSound)
        end
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID then
        local tasks = C_TaskQuest.GetQuestsOnMap(mapID)
        if tasks then
            for _, info in ipairs(tasks) do
                local questID = info.questID
                if questID and not checked[questID] and C_QuestLog.IsOnQuest(questID) then
                    checked[questID] = true
                    CheckQuestSounds(questID, playQuestSound, playObjSound)
                end
            end
        end
    end

    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.isHidden and info.isTask and info.questID and not checked[info.questID] then
            checked[info.questID] = true
            CheckQuestSounds(info.questID, playQuestSound, playObjSound)
        end
    end
end

local function HandleSuperTrackChanged()
    if not UIThingsDB.tracker.restoreSuperTrack then
        savedSuperTrackedQuestID = nil
        lastKnownSuperTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID()
        return
    end

    local currentST = C_SuperTrack.GetSuperTrackedQuestID()
    local isCurrentWQ = currentST and currentST ~= 0 and
        (C_QuestLog.IsWorldQuest(currentST) or (C_QuestLog.IsQuestTask(currentST) and not C_QuestLog.GetQuestWatchType(currentST)))

    if isCurrentWQ and lastKnownSuperTrackedQuestID and lastKnownSuperTrackedQuestID ~= 0 then
        local wasWQ = C_QuestLog.IsWorldQuest(lastKnownSuperTrackedQuestID) or
            (C_QuestLog.IsQuestTask(lastKnownSuperTrackedQuestID) and not C_QuestLog.GetQuestWatchType(lastKnownSuperTrackedQuestID))
        if not wasWQ then
            savedSuperTrackedQuestID = lastKnownSuperTrackedQuestID
        end
    end

    if (not currentST or currentST == 0) and savedSuperTrackedQuestID then
        if C_QuestLog.IsOnQuest(savedSuperTrackedQuestID) and C_QuestLog.GetQuestWatchType(savedSuperTrackedQuestID) then
            C_SuperTrack.SetSuperTrackedQuestID(savedSuperTrackedQuestID)
            savedSuperTrackedQuestID = nil
        else
            savedSuperTrackedQuestID = nil
        end
    end

    lastKnownSuperTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID()
end

local function CheckRestoreSuperTrack()
    if not UIThingsDB.tracker.restoreSuperTrack then
        proximityTrackedWQ = nil
        return
    end
    -- Defer 0.3s so C_TaskQuest.IsActive reflects the new zone position.
    SafeAfter(0.3, function()
        if not UIThingsDB.tracker.restoreSuperTrack then
            proximityTrackedWQ = nil
            return
        end
        local currentST = C_SuperTrack.GetSuperTrackedQuestID()

        -- If we manually set a WQ for proximity, the ticker handles restoration.
        if proximityTrackedWQ then return end

        -- Nothing tracked — restore saved quest if we have one.
        if not currentST or currentST == 0 then
            if savedSuperTrackedQuestID
                and C_QuestLog.IsOnQuest(savedSuperTrackedQuestID)
                and C_QuestLog.GetQuestWatchType(savedSuperTrackedQuestID) then
                C_SuperTrack.SetSuperTrackedQuestID(savedSuperTrackedQuestID)
            end
            savedSuperTrackedQuestID = nil
            return
        end

        -- A WQ is already super-tracked (engine fired SUPER_TRACKING_CHANGED).
        local isCurrentWQ = C_QuestLog.IsWorldQuest(currentST) or
            (C_QuestLog.IsQuestTask(currentST) and not C_QuestLog.GetQuestWatchType(currentST))
        if isCurrentWQ then return end

        -- Current is a non-WQ quest. Check if there is an active WQ in the area
        -- that the engine did not auto-track (because something was already tracked).
        local mapID = C_Map.GetBestMapForUnit("player")
        if not mapID then return end
        local tasks = C_TaskQuest.GetQuestsOnMap(mapID)
        if not tasks then return end

        -- Pick the nearest active WQ (smallest GetDistanceSqToQuest).
        -- Ignores quests that return nil distance — those are in an adjacent
        -- zone returned by the broad region GetQuestsOnMap call.
        local wqToTrack, nearestDist = nil, math.huge
        for _, info in ipairs(tasks) do
            local questID = info.questID
            if questID and C_TaskQuest.IsActive(questID) then
                if C_QuestLog.IsWorldQuest(questID) or
                    (C_QuestLog.IsQuestTask(questID) and not C_QuestLog.GetQuestWatchType(questID)) then
                    local distSq = C_QuestLog.GetDistanceSqToQuest(questID)
                    if distSq and distSq < nearestDist then
                        nearestDist = distSq
                        wqToTrack = questID
                    end
                end
            end
        end
        if not wqToTrack then return end

        -- Save the campaign quest and manually set the WQ.
        -- Preset lastKnownSuperTrackedQuestID to wqToTrack so that the
        -- SUPER_TRACKING_CHANGED fired by SetSuperTrackedQuestID below
        -- sees wasWQ=true and does not overwrite savedSuperTrackedQuestID.
        if C_QuestLog.IsOnQuest(currentST) and C_QuestLog.GetQuestWatchType(currentST) then
            savedSuperTrackedQuestID = currentST
        end
        lastKnownSuperTrackedQuestID = wqToTrack
        C_SuperTrack.SetSuperTrackedQuestID(wqToTrack)
        proximityTrackedWQ = wqToTrack
    end)
end

-- Throttle wrapper to coalesce rapid-fire events into a single update
local updatePending = false
local function ScheduleUpdateContent()
    if updatePending then return end
    updatePending = true
    SafeAfter(UPDATE_THROTTLE_DELAY, function()
        updatePending = false
        if trackerFrame then
            UpdateContent()
        end
    end)
end

local function AddLine(text, isHeader, questID, achieID, isObjective, overrideColor, perksActivityID)
    local btn = AcquireItem()
    btn:Show()

    btn.questID = questID
    btn.achieID = achieID
    btn.perksActivityID = perksActivityID
    btn.isSuperTrackedObjective = isObjective and questID and C_SuperTrack.GetSuperTrackedQuestID() == questID

    btn:SetScript("OnClick",
        questID and OnQuestClick or achieID and OnAchieveClick or perksActivityID and OnPerksActivityClick or nil)

    local indent = ucState.indent or 0
    btn:SetWidth(ucState.width - indent)
    btn:SetPoint("TOPLEFT", indent, ucState.yOffset)

    if isHeader then
        btn.Text:SetFont(ucState.sectionHeaderFont, ucState.sectionHeaderSize, "OUTLINE")
        btn.Text:SetText(text)
        local shc = ucState.sectionHeaderColor
        btn.Text:SetTextColor(shc.r, shc.g, shc.b, shc.a or 1)
        btn.Icon:Hide()
        btn.Text:SetPoint("LEFT", 0, 0)

        if questID then
            local section = questID
            local isCollapsed = UIThingsDB.tracker.collapsed[section]

            btn.ToggleBtn:Show()
            btn.ToggleBtn:SetScript("OnClick", function(self, button)
                if InCombatLockdown() and button == "LeftButton" then return end
                UIThingsDB.tracker.collapsed[section] = not isCollapsed
                UpdateContent()
            end)

            if isCollapsed then
                btn.ToggleBtn.Text:SetText("+")
            else
                btn.ToggleBtn.Text:SetText("-")
            end

            local textWidth = btn.Text:GetStringWidth()
            btn.ToggleBtn:SetPoint("LEFT", btn.Text, "LEFT", textWidth + 5, 0)
        else
            btn.ToggleBtn:Hide()
        end

        btn:EnableMouse(false)
        local sh = btn.Text:GetStringHeight()
        local sLineH = (sh and sh > 0) and sh or ucState.sectionHeaderSize
        btn:SetHeight(sLineH + 4)
        ucState.yOffset = ucState.yOffset - (sLineH + 6)
    else
        if isObjective then
            local currentSize = ucState.detailSize
            btn.Text:SetFont(ucState.detailFont, currentSize, "OUTLINE")
            btn.Text:SetText(text)
            local oc = ucState.objectiveColor
            btn.Text:SetTextColor(oc.r, oc.g, oc.b, oc.a or 1)
            btn.Icon:Hide()
            btn.Text:SetPoint("LEFT", 19, 0)
            btn:EnableMouse(false)

            if btn.isSuperTrackedObjective then
                local progress, hasProgress = GetObjectiveProgress(text)
                if hasProgress and progress < 100 then
                    btn.ProgressBar:SetValue(progress)
                    btn.ProgressBar:Show()
                end
            end

            local textHeight = btn.Text:GetStringHeight() or currentSize
            local lineHeight = math.max(textHeight, currentSize)
            btn:SetHeight(lineHeight + 2)
            ucState.yOffset = ucState.yOffset - (lineHeight + ucState.questPadding)
        else
            local currentSize = ucState.questNameSize
            btn.Text:SetFont(ucState.questNameFont, currentSize, "OUTLINE")
            btn.Text:SetText(text)

            if overrideColor then
                btn.Text:SetTextColor(overrideColor.r, overrideColor.g, overrideColor.b, overrideColor.a or 1)
            else
                local qnc = ucState.questNameColor
                btn.Text:SetTextColor(qnc.r, qnc.g, qnc.b, qnc.a or 1)
            end

            if questID then
                local iconAsset, isAtlas
                if QuestUtil and QuestUtil.GetQuestIconActiveForQuestID then
                    iconAsset, isAtlas = QuestUtil.GetQuestIconActiveForQuestID(questID)
                end

                btn.Icon:SetTexture(nil)
                if iconAsset and isAtlas then
                    btn.Icon:SetAtlas(iconAsset, true)
                elseif iconAsset then
                    btn.Icon:SetTexture(iconAsset)
                else
                    local isComplete = C_QuestLog.IsComplete(questID)
                    if isComplete then
                        btn.Icon:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
                    else
                        btn.Icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
                    end
                end
                btn.Icon:Show()
                btn.Text:SetPoint("LEFT", btn.Icon, "RIGHT", 5, 0)
                btn:EnableMouse(true)

                local questLogIndex = C_QuestLog.GetLogIndexForQuestID(questID)
                if questLogIndex then
                    local questItemLink, questItemIcon = GetQuestLogSpecialItemInfo(questLogIndex)
                    if questItemLink and questItemIcon then
                        btn.ItemBtn.iconTex:SetTexture(questItemIcon)
                        if not InCombatLockdown() then
                            local right = btn:GetRight()
                            local cy = select(2, btn:GetCenter())
                            if right and cy then
                                btn.ItemBtn:ClearAllPoints()
                                btn.ItemBtn:SetPoint("RIGHT", UIParent, "BOTTOMLEFT", right - 2, cy)
                            end
                            btn.ItemBtn:SetAttribute("type", "item")
                            btn.ItemBtn:SetAttribute("item", questItemLink)
                            btn.ItemBtn:Show()
                        end
                    else
                        if not InCombatLockdown() then btn.ItemBtn:Hide() end
                    end
                else
                    if not InCombatLockdown() then btn.ItemBtn:Hide() end
                end
            else
                btn.Icon:Hide()
                btn.Text:SetPoint("LEFT", 19, 0)
                if achieID then btn:EnableMouse(true) else btn:EnableMouse(false) end
                if btn.ItemBtn and not InCombatLockdown() then btn.ItemBtn:Hide() end
            end

            if UIThingsDB.tracker.showTooltipPreview and (questID or achieID or perksActivityID) then
                btn:SetScript("OnEnter", function(self)
                    if self.questID then
                        GameTooltip:SetOwner(self, "ANCHOR_NONE")
                        GameTooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 5, 0)
                        GameTooltip:SetHyperlink("quest:" .. self.questID)
                        if IsInGroup() then
                            wipe(tooltipMembers)
                            local maxUnit = IsInRaid() and 40 or 4
                            local prefix = IsInRaid() and "raid" or "party"
                            for i = 1, maxUnit do
                                local unit = prefix .. i
                                if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                                    if C_QuestLog.IsUnitOnQuest(unit, self.questID) then
                                        local name = UnitName(unit)
                                        local _, class = UnitClass(unit)
                                        local color = RAID_CLASS_COLORS[class]
                                        if color and name then
                                            table.insert(tooltipMembers, color:WrapTextInColorCode(name))
                                        elseif name then
                                            table.insert(tooltipMembers, name)
                                        end
                                    end
                                end
                            end
                            if #tooltipMembers > 0 then
                                GameTooltip:AddLine(" ")
                                GameTooltip:AddLine("Party Members on Quest:")
                                for _, name in ipairs(tooltipMembers) do
                                    GameTooltip:AddLine("  " .. name)
                                end
                            end
                        end
                        GameTooltip:Show()
                    elseif self.achieID then
                        GameTooltip:SetOwner(self, "ANCHOR_NONE")
                        GameTooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 5, 0)
                        GameTooltip:SetHyperlink("achievement:" .. self.achieID)
                        GameTooltip:Show()
                    elseif self.perksActivityID then
                        GameTooltip:SetOwner(self, "ANCHOR_NONE")
                        GameTooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 5, 0)
                        local allActivities = C_PerksActivities.GetPerksActivitiesInfo()
                        if allActivities and allActivities.activities then
                            for _, activity in ipairs(allActivities.activities) do
                                if activity.ID == self.perksActivityID then
                                    GameTooltip:AddLine(activity.activityName, 1, 1, 1)
                                    if activity.description and activity.description ~= "" then
                                        GameTooltip:AddLine(activity.description, nil, nil, nil, true)
                                    end
                                    if activity.requirementsList and #activity.requirementsList > 0 then
                                        GameTooltip:AddLine(" ")
                                        for _, req in ipairs(activity.requirementsList) do
                                            if req.requirementText then
                                                local r, g, b = 1, 1, 1
                                                if req.completed then r, g, b = 0, 1, 0 end
                                                GameTooltip:AddLine(req.requirementText, r, g, b)
                                            end
                                        end
                                    end
                                    break
                                end
                            end
                        end
                        GameTooltip:Show()
                    end
                end)
                btn:SetScript("OnLeave", GameTooltip_Hide)
            else
                btn:SetScript("OnEnter", nil)
                btn:SetScript("OnLeave", nil)
            end

            local textHeight = btn.Text:GetStringHeight() or currentSize
            local lineHeight = math.max(textHeight, currentSize)
            btn:SetHeight(lineHeight + 2)
            ucState.yOffset = ucState.yOffset - (lineHeight + 4)
        end
    end
    return btn
end

-- ============================================================
-- Blizzard tracker suppression
-- ============================================================
local blizzardTrackerHooked = false
local function HookBlizzardTracker()
    if blizzardTrackerHooked or not ObjectiveTrackerFrame then return end
    blizzardTrackerHooked = true
    hooksecurefunc(ObjectiveTrackerFrame, "Show", function()
        if UIThingsDB and UIThingsDB.tracker and UIThingsDB.tracker.enabled then
            ObjectiveTrackerFrame:SetAlpha(0)
            ObjectiveTrackerFrame:SetScale(0.00001)
            ObjectiveTrackerFrame:EnableMouse(false)
        end
    end)
end

HookBlizzardTracker()

-- ============================================================
-- Tracker frame setup
-- ============================================================
local function SetupCustomTracker()
    if trackerFrame then return end
    local settings = UIThingsDB.tracker

    trackerFrame = CreateFrame("Frame", "UIThingsTrackerFrame", UIParent, "BackdropTemplate")
    trackerFrame:SetMovable(true)
    trackerFrame:SetResizable(true)
    trackerFrame:SetClampedToScreen(true)
    trackerFrame:SetFrameStrata(settings.strata or "LOW")
    trackerFrame:SetSize(settings.width, settings.height)

    local pos = settings
    if pos.point then
        trackerFrame:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
    else
        trackerFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -200)
    end

    local headerFrame_ = CreateFrame("Frame", nil, trackerFrame)
    headerFrame_:SetPoint("TOPLEFT")
    headerFrame_:SetPoint("TOPRIGHT")
    headerFrame_:SetHeight(30)
    headerFrame = headerFrame_

    local headerText = headerFrame_:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerText:SetPoint("CENTER")
    headerText:SetText("OBJECTIVES")

    if settings.hideHeader then
        headerFrame_:SetHeight(1)
        headerFrame_:Hide()
    end

    -- Drag
    trackerFrame:EnableMouse(true)
    trackerFrame:RegisterForDrag("LeftButton")
    trackerFrame:SetScript("OnDragStart", function(self)
        if not UIThingsDB.tracker.locked then self:StartMoving() end
    end)
    trackerFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        x = math.floor(x + 0.5)
        y = math.floor(y + 0.5)
        self:ClearAllPoints()
        self:SetPoint(point, UIParent, relativePoint, x, y)
        UIThingsDB.tracker.point = point
        UIThingsDB.tracker.x = x
        UIThingsDB.tracker.y = y
    end)

    -- Scroll frame
    scrollFrame = CreateFrame("ScrollFrame", "UIThingsTrackerScroll", trackerFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", headerFrame_, "BOTTOMLEFT", 10, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", -25, 10)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(settings.width - 40, 500)
    scrollFrame:SetScrollChild(scrollChild)

    -- Resize handle
    local resizeHandle = CreateFrame("Frame", nil, trackerFrame)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", -5, 5)
    local rTex = resizeHandle:CreateTexture(nil, "OVERLAY")
    rTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    rTex:SetAllPoints()
    resizeHandle:EnableMouse(true)
    resizeHandle:SetScript("OnMouseDown", function()
        if not UIThingsDB.tracker.locked then trackerFrame:StartSizing("BOTTOMRIGHT") end
    end)
    resizeHandle:SetScript("OnMouseUp", function()
        trackerFrame:StopMovingOrSizing()
        local w, h = trackerFrame:GetSize()
        UIThingsDB.tracker.width = w
        UIThingsDB.tracker.height = h
    end)
end

-- ============================================================
-- UpdateSettings
-- ============================================================
function addonTable.ObjectiveTracker.UpdateSettings()
    local enabled = UIThingsDB.tracker.enabled

    if enabled then
        HookBlizzardTracker()
        if ObjectiveTrackerFrame then
            ObjectiveTrackerFrame:SetAlpha(0)
            ObjectiveTrackerFrame:SetScale(0.00001)
            ObjectiveTrackerFrame:EnableMouse(false)
        end
    else
        if ObjectiveTrackerFrame then
            ObjectiveTrackerFrame:SetAlpha(1)
            ObjectiveTrackerFrame:SetScale(1)
            ObjectiveTrackerFrame:EnableMouse(true)
        end
        if trackerFrame then
            trackerFrame:Hide()
        end
        autoTrackFrame:UnregisterAllEvents()
        return
    end

    if enabled and UIThingsDB.tracker.autoTrackQuests then
        autoTrackFrame:RegisterEvent("QUEST_ACCEPTED")
    else
        autoTrackFrame:UnregisterAllEvents()
    end

    SetupCustomTracker()
    SetupTrackerEvents()

    local inCombat = InCombatLockdown()
    if not inCombat then
        if UIThingsDB.tracker.hideInCombat then
            RegisterStateDriver(trackerFrame, "visibility", "[combat] hide; show")
        else
            UnregisterStateDriver(trackerFrame, "visibility")
            trackerFrame:Show()
        end
        if UIThingsDB.tracker.hideInMPlus and C_ChallengeMode.IsChallengeModeActive() then
            trackerFrame:Hide()
        end
    end

    trackerFrame:SetSize(UIThingsDB.tracker.width, UIThingsDB.tracker.height)
    trackerFrame:SetFrameStrata(UIThingsDB.tracker.strata or "LOW")
    scrollChild:SetWidth(UIThingsDB.tracker.width - 40)

    if headerFrame then
        if UIThingsDB.tracker.hideHeader then
            headerFrame:SetHeight(1)
            headerFrame:Hide()
        else
            headerFrame:SetHeight(30)
            headerFrame:Show()
        end
    end

    if UIThingsDB.tracker.locked then
        trackerFrame:EnableMouse(false)
        local showBorder = UIThingsDB.tracker.showBorder
        local showBackground = UIThingsDB.tracker.showBackground
        if showBorder or showBackground then
            trackerFrame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false, tileSize = 0, edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            if showBackground then
                local c = UIThingsDB.tracker.backgroundColor or { r = 0, g = 0, b = 0, a = 0.5 }
                trackerFrame:SetBackdropColor(c.r, c.g, c.b, c.a)
            else
                trackerFrame:SetBackdropColor(0, 0, 0, 0)
            end
            if showBorder then
                local bc = UIThingsDB.tracker.borderColor or { r = 0, g = 0, b = 0, a = 1 }
                trackerFrame:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
            else
                trackerFrame:SetBackdropBorderColor(0, 0, 0, 0)
            end
        else
            trackerFrame:SetBackdrop(nil)
        end
    else
        trackerFrame:EnableMouse(true)
        trackerFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        trackerFrame:SetBackdropColor(0, 0, 0, 0.5)
        trackerFrame:SetBackdropBorderColor(1, 1, 1, 1)
    end

    -- Distance update ticker
    if distanceTicker then
        distanceTicker:Cancel()
        distanceTicker = nil
    end
    local interval = UIThingsDB.tracker.distanceUpdateInterval or 0
    if interval > 0 then
        distanceTicker = C_Timer.NewTicker(interval, function()
            if trackerFrame and trackerFrame:IsShown() and not InCombatLockdown() then
                UpdateContent()
            end
        end)
    end

    -- Mute/unmute default Blizzard quest sounds
    local shouldMute = UIThingsDB.tracker.enabled and UIThingsDB.tracker.muteDefaultQuestSounds
    if shouldMute and not questSoundsMuted then
        for _, fileID in ipairs(QUEST_SOUND_FILES) do
            MuteSoundFile(fileID)
        end
        questSoundsMuted = true
    elseif not shouldMute and questSoundsMuted then
        for _, fileID in ipairs(QUEST_SOUND_FILES) do
            UnmuteSoundFile(fileID)
        end
        questSoundsMuted = false
    end
end

local function RenderSingleWQ(questID, superTrackedQuestID)
    if not displayedIDs[questID] then
        local title = C_QuestLog.GetTitleForQuestID(questID)
        if title then
            title = GetWQRewardIcon(questID) .. GetQuestTypePrefix(questID) .. title
            if UIThingsDB.tracker.showWorldQuestTimer then
                title = title .. GetTimeLeftString(questID)
            end
            title = title .. GetDistanceString(questID)
            local color = nil
            if questID == superTrackedQuestID then
                color = UIThingsDB.tracker.activeQuestColor
            end
            AddLine(title, false, questID, nil, false, color)
            displayedIDs[questID] = true
            local objectives = C_QuestLog.GetQuestObjectives(questID)
            if objectives then
                for _, obj in pairs(objectives) do
                    if not (obj.finished and UIThingsDB.tracker.hideCompletedSubtasks) then
                        local objText = obj.text
                        if objText and objText ~= "" then
                            if obj.finished then objText = FormatCompletedObjective(objText) end
                            AddLine(objText, false, questID, nil, true)
                        end
                    end
                end
            end
            ucState.yOffset = ucState.yOffset - ITEM_SPACING
        end
    end
end

local function RenderWorldQuests()
    if not ucState.cachedMapID then return end
    local tasks = ucState.cachedTasks
    wipe(activeWQs); wipe(otherWQs); wipe(validWQs)
    local onlyActive = UIThingsDB.tracker.onlyActiveWorldQuests
    local superTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID()
    if tasks then
        for _, info in ipairs(tasks) do
            local questID = info.questID
            if questID and C_TaskQuest.IsActive(questID) then
                local isWorldQuest = C_QuestLog.IsWorldQuest(questID)
                local isTaskQuest = C_QuestLog.IsQuestTask(questID)
                if (isWorldQuest or isTaskQuest) and not validWQs[questID] then
                    -- Skip world quests that have no distance data — they are in an
                    -- adjacent zone returned by GetQuestsOnMap for the broad region map.
                    if isWorldQuest and not C_QuestLog.GetDistanceSqToQuest(questID) then
                        -- skip
                    else
                        validWQs[questID] = true
                        local isActive = C_QuestLog.IsOnQuest(questID)
                        if isTaskQuest and not isWorldQuest then
                            if isActive then table.insert(activeWQs, questID) end
                        elseif isWorldQuest then
                            if onlyActive then
                                local hasProgress = false
                                local objectives = C_QuestLog.GetQuestObjectives(questID)
                                if objectives then
                                    for _, obj in ipairs(objectives) do
                                        if obj.numFulfilled and obj.numFulfilled > 0 then hasProgress = true; break end
                                    end
                                end
                                if hasProgress or isActive then table.insert(activeWQs, questID) end
                            else
                                if isActive then table.insert(activeWQs, questID)
                                else table.insert(otherWQs, questID) end
                            end
                        end
                    end -- distance filter
                end
            end
        end
    end
    local wqSortBy = UIThingsDB.tracker.worldQuestSortBy or "time"
    if wqSortBy == "distance" then
        table.sort(activeWQs, sortByDistanceSq); table.sort(otherWQs, sortByDistanceSq)
    else
        table.sort(activeWQs, sortByTimeLeft); table.sort(otherWQs, sortByTimeLeft)
    end
    local hasWQs = (#activeWQs > 0) or (#otherWQs > 0)
    if hasWQs then
        local wqCount = #activeWQs + #otherWQs
        AddLine("World Quests (" .. wqCount .. ")", true, "worldQuests")
        if UIThingsDB.tracker.collapsed["worldQuests"] then
            ucState.yOffset = ucState.yOffset - ITEM_SPACING
            return
        end
        if superTrackedQuestID and validWQs[superTrackedQuestID] then
            RenderSingleWQ(superTrackedQuestID, superTrackedQuestID)
        end
        for _, questID in ipairs(activeWQs) do RenderSingleWQ(questID, superTrackedQuestID) end
        for _, questID in ipairs(otherWQs) do RenderSingleWQ(questID, superTrackedQuestID) end
        ucState.yOffset = ucState.yOffset - SECTION_SPACING
    end
end

local function RenderQuests()
    local numQuestLogEntries = C_QuestLog.GetNumQuestLogEntries()
    wipe(hiddenTaskQuests)
    for i = 1, numQuestLogEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.isHidden and info.isTask and info.isOnMap and info.questID then
            if not displayedIDs[info.questID] and not C_QuestLog.IsWorldQuest(info.questID) then
                table.insert(hiddenTaskQuests, info.questID)
            end
        end
    end
    if #hiddenTaskQuests > 0 then
        AddLine("Temporary Objectives", true, "tempObjectives")
        if not UIThingsDB.tracker.collapsed["tempObjectives"] then
            for _, questID in ipairs(hiddenTaskQuests) do
                local title = C_QuestLog.GetTitleForQuestID(questID)
                if title then
                    AddLine(title, false, questID, nil, false)
                    displayedIDs[questID] = true
                    local objectives = C_QuestLog.GetQuestObjectives(questID)
                    if objectives then
                        for _, obj in pairs(objectives) do
                            if not (obj.finished and UIThingsDB.tracker.hideCompletedSubtasks) then
                                local objText = obj.text
                                if objText and objText ~= "" then
                                    if obj.finished then objText = FormatCompletedObjective(objText) end
                                    AddLine(objText, false, questID, nil, true)
                                end
                            end
                        end
                    end
                    ucState.yOffset = ucState.yOffset - ITEM_SPACING
                end
            end
            ucState.yOffset = ucState.yOffset - SECTION_SPACING
        else
            ucState.yOffset = ucState.yOffset - ITEM_SPACING
        end
    end

    local numQuests = C_QuestLog.GetNumQuestWatches()
    if numQuests > 0 then
        local superTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID()
        local superTrackedIndex = nil
        wipe(filteredIndices)
        for i = 1, numQuests do
            local qID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
            if qID then
                if campaignQuestsSectionActive and
                    C_CampaignInfo and C_CampaignInfo.IsCampaignQuest and C_CampaignInfo.IsCampaignQuest(qID) then
                    -- skip — rendered in campaignQuests section
                elseif not displayedIDs[qID] then
                    if qID == superTrackedQuestID then superTrackedIndex = i
                    else table.insert(filteredIndices, i) end
                end
            end
        end
        if UIThingsDB.tracker.sortQuestsByDistance then
            table.sort(filteredIndices, sortWatchIndexByDistance)
        end
        if superTrackedIndex then table.insert(filteredIndices, 1, superTrackedIndex) end

        if #filteredIndices > 0 then
            AddLine("Quests (" .. #filteredIndices .. ")", true, "quests")
            if UIThingsDB.tracker.collapsed["quests"] then
                ucState.yOffset = ucState.yOffset - ITEM_SPACING
                return
            end

            local function RenderSingleQuest(questID, extraIndent)
                if extraIndent then ucState.indent = extraIndent end
                local title = C_QuestLog.GetTitleForQuestID(questID)
                if title then
                    title = GetQuestTypePrefix(questID) .. title .. GetQuestLineString(questID) .. GetDistanceString(questID)
                    local color = nil
                    if questID == superTrackedQuestID then color = UIThingsDB.tracker.activeQuestColor
                    else color = GetCampaignColor(questID) end
                    AddLine(title, false, questID, nil, false, color)
                    displayedIDs[questID] = true
                    local objectives = C_QuestLog.GetQuestObjectives(questID)
                    if objectives then
                        for _, obj in pairs(objectives) do
                            if not (obj.finished and UIThingsDB.tracker.hideCompletedSubtasks) then
                                local objText = obj.text
                                if objText and objText ~= "" then
                                    if obj.finished then objText = FormatCompletedObjective(objText) end
                                    AddLine(objText, false, questID, nil, true)
                                end
                            end
                        end
                    end
                    if C_QuestLog.IsComplete(questID) then
                        local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
                        local isAutoComplete = false
                        if logIndex then
                            local info = C_QuestLog.GetInfo(logIndex)
                            if info then isAutoComplete = info.isAutoComplete or false end
                            if not isAutoComplete and GetQuestLogIsAutoComplete then
                                isAutoComplete = GetQuestLogIsAutoComplete(logIndex) == 1
                            end
                        end
                        if isAutoComplete then
                            local completeBtn = AddLine("|cFFFFD100Click to complete quest|r", false, questID, nil, true)
                            if completeBtn then
                                completeBtn:EnableMouse(true)
                                local qid = questID
                                completeBtn:SetScript("OnClick", function(self, button)
                                    if button == "LeftButton" and not InCombatLockdown() then
                                        ShowQuestComplete(qid)
                                    end
                                end)
                            end
                        end
                    end
                    ucState.yOffset = ucState.yOffset - ITEM_SPACING
                end
                if extraIndent then ucState.indent = 0 end
            end

            local function RenderGroupHeader(groupKey, label, quests, colorR, colorG, colorB)
                local isCollapsed = UIThingsDB.tracker.collapsed[groupKey]
                local btn = AcquireItem()
                btn:Show()
                btn.questID = nil; btn.achieID = nil
                btn:SetScript("OnClick", nil)
                btn:SetWidth(ucState.width)
                btn:SetPoint("TOPLEFT", 0, ucState.yOffset)
                btn.Text:SetFont(ucState.questNameFont, ucState.questNameSize, "OUTLINE")
                btn.Text:SetText(label .. " (" .. #quests .. ")")
                btn.Text:SetTextColor(colorR, colorG, colorB)
                btn.Icon:Hide()
                btn.Text:SetPoint("LEFT", 10, 0)
                btn:EnableMouse(false)
                btn:SetScript("OnEnter", nil); btn:SetScript("OnLeave", nil)
                if btn.ItemBtn and not InCombatLockdown() then btn.ItemBtn:Hide() end
                btn.ToggleBtn:Show()
                btn.ToggleBtn:SetScript("OnClick", function(self, button)
                    if InCombatLockdown() and button == "LeftButton" then return end
                    UIThingsDB.tracker.collapsed[groupKey] = not isCollapsed
                    UpdateContent()
                end)
                btn.ToggleBtn.Text:SetText(isCollapsed and "+" or "-")
                local textWidth = btn.Text:GetStringWidth()
                btn.ToggleBtn:SetPoint("LEFT", btn.Text, "LEFT", textWidth + 5, 0)
                local gh = btn.Text:GetStringHeight()
                local gLineH = (gh and gh > 0) and gh or ucState.questNameSize
                btn:SetHeight(gLineH + 4)
                ucState.yOffset = ucState.yOffset - (gLineH + 4)
                if not isCollapsed then
                    for _, questID in ipairs(quests) do RenderSingleQuest(questID, 10) end
                end
                ucState.yOffset = ucState.yOffset - ITEM_SPACING
            end

            local function RenderFlatQuests(indices)
                for _, i in ipairs(indices) do
                    local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
                    if questID then RenderSingleQuest(questID) end
                end
            end

            local function RenderByZone(questIDs)
                wipe(zoneOrder); wipe(questsByZone)
                for _, questID in ipairs(questIDs) do
                    if not displayedIDs[questID] then
                        local zoneName = "Other"
                        local headerIndex = C_QuestLog.GetHeaderIndexForQuest(questID)
                        if headerIndex then
                            local headerInfo = C_QuestLog.GetInfo(headerIndex)
                            if headerInfo and headerInfo.title then zoneName = headerInfo.title end
                        end
                        if not questsByZone[zoneName] then
                            questsByZone[zoneName] = {}; table.insert(zoneOrder, zoneName)
                        end
                        table.insert(questsByZone[zoneName], questID)
                    end
                end
                if UIThingsDB.tracker.sortQuestsByDistance then
                    for _, zoneName in ipairs(zoneOrder) do
                        table.sort(questsByZone[zoneName], sortByDistanceSq)
                    end
                end
                for _, zoneName in ipairs(zoneOrder) do
                    RenderGroupHeader("zone_" .. zoneName, zoneName, questsByZone[zoneName], 0.7, 0.85, 1.0)
                end
            end

            local useCampaignGroup = UIThingsDB.tracker.groupQuestsByCampaign
            local useZoneGroup = UIThingsDB.tracker.groupQuestsByZone

            if useCampaignGroup or useZoneGroup then
                if superTrackedIndex then
                    local stQuestID = C_QuestLog.GetQuestIDForQuestWatchIndex(superTrackedIndex)
                    if stQuestID then RenderSingleQuest(stQuestID) end
                end
            end

            if useCampaignGroup then
                wipe(campaignOrder); wipe(questsByCampaign); wipe(nonCampaignQuests)
                for _, i in ipairs(filteredIndices) do
                    local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
                    if questID and not displayedIDs[questID] then
                        local campaignID = C_CampaignInfo.GetCampaignID(questID)
                        if campaignID and campaignID > 0 then
                            local campaignInfo = C_CampaignInfo.GetCampaignInfo(campaignID)
                            local campaignName = campaignInfo and campaignInfo.name or ("Campaign " .. campaignID)
                            if not questsByCampaign[campaignName] then
                                questsByCampaign[campaignName] = {}; table.insert(campaignOrder, campaignName)
                            end
                            table.insert(questsByCampaign[campaignName], questID)
                        else
                            table.insert(nonCampaignQuests, questID)
                        end
                    end
                end
                if UIThingsDB.tracker.sortQuestsByDistance then
                    for _, name in ipairs(campaignOrder) do
                        table.sort(questsByCampaign[name], sortByDistanceSq)
                    end
                end
                for _, campaignName in ipairs(campaignOrder) do
                    RenderGroupHeader("campaign_" .. campaignName, campaignName, questsByCampaign[campaignName], 0.9, 0.7, 0.2)
                end
                if #nonCampaignQuests > 0 then
                    if useZoneGroup then RenderByZone(nonCampaignQuests)
                    else for _, questID in ipairs(nonCampaignQuests) do RenderSingleQuest(questID) end end
                end
            elseif useZoneGroup then
                local questIDs = {}
                for _, i in ipairs(filteredIndices) do
                    local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
                    if questID and not displayedIDs[questID] then table.insert(questIDs, questID) end
                end
                RenderByZone(questIDs)
            else
                RenderFlatQuests(filteredIndices)
            end
            ucState.yOffset = ucState.yOffset - SECTION_SPACING
        end
    end
end

local function RenderScenarios()
    if not C_ScenarioInfo then return end
    local scenarioInfo = C_ScenarioInfo.GetScenarioInfo()
    if not scenarioInfo or not scenarioInfo.name or scenarioInfo.name == "" then return end
    local headerText = "Scenario: " .. scenarioInfo.name
    if scenarioInfo.numStages and scenarioInfo.numStages > 1 then
        headerText = headerText .. string.format(" |cFFAAAAAA(%d/%d)|r", scenarioInfo.currentStage or 1, scenarioInfo.numStages)
    end
    AddLine(headerText, true, "scenario")
    if UIThingsDB.tracker.collapsed["scenario"] then
        ucState.yOffset = ucState.yOffset - ITEM_SPACING
        return
    end
    local stepInfo = C_ScenarioInfo.GetScenarioStepInfo and C_ScenarioInfo.GetScenarioStepInfo() or nil
    if stepInfo and stepInfo.title and stepInfo.title ~= "" and stepInfo.title ~= scenarioInfo.name then
        AddLine("|cFFFFD100" .. stepInfo.title .. "|r", false, nil, nil, true)
    end
    if stepInfo and stepInfo.description and stepInfo.description ~= "" then
        AddLine("|cFFBBBBBB" .. stepInfo.description .. "|r", false, nil, nil, true)
    end
    if stepInfo and stepInfo.weightedProgress and stepInfo.weightedProgress > 0 then
        local pct = math.floor(stepInfo.weightedProgress)
        local color = pct >= 100 and "00FF00" or "FFFF00"
        AddLine(string.format("|cFF%s%d%% Complete|r", color, pct), false, nil, nil, true)
    end
    local numCriteria = stepInfo and stepInfo.numCriteria or 0
    if numCriteria > 0 then
        for i = 1, numCriteria do
            local criteriaInfo = C_ScenarioInfo.GetCriteriaInfo(i)
            if not criteriaInfo then break end
            local text = criteriaInfo.description or ""
            if criteriaInfo.isWeightedProgress then
                if criteriaInfo.quantity then text = text .. " " .. criteriaInfo.quantity .. "%" end
            elseif criteriaInfo.quantity and criteriaInfo.totalQuantity and criteriaInfo.totalQuantity > 1 then
                text = text .. " (" .. criteriaInfo.quantity .. "/" .. criteriaInfo.totalQuantity .. ")"
            end
            if criteriaInfo.failed then text = "|cFFFF0000" .. text .. " (Failed)|r"
            elseif criteriaInfo.completed then text = FormatCompletedObjective(text) end
            if criteriaInfo.isWeightedProgress then text = "|cFF00FFFF[Bonus]|r " .. text end
            AddLine(text, false, nil, nil, true)
        end
    elseif C_ScenarioInfo.GetCriteriaInfo then
        local criteriaIndex = 1
        while criteriaIndex <= 50 do
            local criteriaInfo = C_ScenarioInfo.GetCriteriaInfo(criteriaIndex)
            if not criteriaInfo then break end
            local text = criteriaInfo.description or ""
            if criteriaInfo.isWeightedProgress then
                if criteriaInfo.quantity then text = text .. " " .. criteriaInfo.quantity .. "%" end
            elseif criteriaInfo.quantity and criteriaInfo.totalQuantity and criteriaInfo.totalQuantity > 1 then
                text = text .. " (" .. criteriaInfo.quantity .. "/" .. criteriaInfo.totalQuantity .. ")"
            end
            if criteriaInfo.failed then text = "|cFFFF0000" .. text .. " (Failed)|r"
            elseif criteriaInfo.completed then text = FormatCompletedObjective(text) end
            if criteriaInfo.isWeightedProgress then text = "|cFF00FFFF[Bonus]|r " .. text end
            AddLine(text, false, nil, nil, true)
            criteriaIndex = criteriaIndex + 1
        end
    end
    ucState.yOffset = ucState.yOffset - SECTION_SPACING
end

local function RenderAchievements()
    local trackedAchievements = C_ContentTracking.GetTrackedIDs(Enum.ContentTrackingType.Achievement)
    wipe(validAchievements)
    for _, achID in ipairs(trackedAchievements) do
        local _, name = GetAchievementInfo(achID)
        if name then table.insert(validAchievements, achID) end
    end
    if #validAchievements > 0 then
        AddLine("Achievements", true, "achievements")
        if UIThingsDB.tracker.collapsed["achievements"] then
            ucState.yOffset = ucState.yOffset - ITEM_SPACING
            return
        end
        for _, achID in ipairs(validAchievements) do
            local _, name = GetAchievementInfo(achID)
            local allCompleted = true
            local numCriteria = GetAchievementNumCriteria(achID)
            if numCriteria > 0 then
                for j = 1, numCriteria do
                    local _, _, completed = GetAchievementCriteriaInfo(achID, j)
                    if not completed then allCompleted = false; break end
                end
            end
            if numCriteria > 0 and allCompleted and UIThingsDB.tracker.hideCompletedSubtasks then
                -- skip
            else
                AddLine(name, false, nil, achID)
                for j = 1, numCriteria do
                    local criteriaString, _, completed, quantity, reqQuantity = GetAchievementCriteriaInfo(achID, j)
                    if criteriaString then
                        if not (completed and UIThingsDB.tracker.hideCompletedSubtasks) then
                            local text = criteriaString
                            if (type(quantity) == "number" and type(reqQuantity) == "number") and reqQuantity > 1 then
                                text = text .. " (" .. quantity .. "/" .. reqQuantity .. ")"
                            end
                            if completed then text = "|cFF00FF00" .. text .. "|r" end
                            AddLine(text, false, nil, nil, true)
                        end
                    end
                end
                ucState.yOffset = ucState.yOffset - ITEM_SPACING
            end
        end
        ucState.yOffset = ucState.yOffset - SECTION_SPACING
    end
end

local function AutoUntrackCompletedPerksActivities()
    if not C_PerksActivities then return end
    if not C_PerksActivities.GetTrackedPerksActivities then return end
    if not C_PerksActivities.RemoveTrackedPerksActivity then return end
    local tracked = C_PerksActivities.GetTrackedPerksActivities()
    if not tracked or #tracked == 0 then return end
    local activityData = {}
    if C_PerksActivities.GetPerksActivitiesInfo then
        local info = C_PerksActivities.GetPerksActivitiesInfo()
        if info and info.activities then
            for _, activity in ipairs(info.activities) do
                if activity and activity.ID then activityData[activity.ID] = activity end
            end
        end
    end
    for _, activityID in ipairs(tracked) do
        local activity = activityData[activityID]
        if activity then
            local hasRequirements, allDone = false, true
            if activity.requirementsList then
                for _, req in ipairs(activity.requirementsList) do
                    if req and req.requirementText and req.requirementText ~= "" then
                        hasRequirements = true
                        if not req.completed then allDone = false; break end
                    end
                end
            end
            if hasRequirements and allDone then
                C_PerksActivities.RemoveTrackedPerksActivity(activityID)
            end
        end
    end
end

local function RenderTravelersLog()
    if not C_PerksActivities then return end
    local allActivities = nil
    if C_PerksActivities.GetPerksActivitiesInfo then
        allActivities = C_PerksActivities.GetPerksActivitiesInfo()
    end
    local activityLookup = {}
    if allActivities and allActivities.activities then
        for _, activity in ipairs(allActivities.activities) do
            if activity and activity.ID then activityLookup[activity.ID] = activity end
        end
    end
    local trackedActivities = {}
    if C_PerksActivities.GetTrackedPerksActivities then
        local tracked = C_PerksActivities.GetTrackedPerksActivities()
        if tracked and #tracked > 0 then trackedActivities = tracked end
    end
    if #trackedActivities == 0 and allActivities and allActivities.activities then
        for _, activity in ipairs(allActivities.activities) do
            if activity and activity.tracked and activity.ID then
                table.insert(trackedActivities, activity.ID)
            end
        end
    end
    if #trackedActivities == 0 then return end
    local renderCount = 0
    for _, activityID in ipairs(trackedActivities) do
        local activity = activityLookup[activityID]
        if activity then
            local hasRequirements, allCompleted = false, true
            if activity.requirementsList then
                for _, req in ipairs(activity.requirementsList) do
                    if req and req.requirementText and req.requirementText ~= "" then
                        hasRequirements = true
                        if not req.completed then allCompleted = false; break end
                    end
                end
            end
            if not (hasRequirements and allCompleted and UIThingsDB.tracker.hideCompletedSubtasks) then
                renderCount = renderCount + 1
            end
        end
    end
    if renderCount == 0 then return end
    AddLine("Traveler's Log (" .. renderCount .. ")", true, "travelersLog")
    if UIThingsDB.tracker.collapsed["travelersLog"] then
        ucState.yOffset = ucState.yOffset - ITEM_SPACING
        return
    end
    for _, activityID in ipairs(trackedActivities) do
        local activity = activityLookup[activityID]
        if activity then
            local allCompleted, hasRequirements = true, false
            if activity.requirementsList then
                for _, req in ipairs(activity.requirementsList) do
                    if req and req.requirementText and req.requirementText ~= "" then
                        hasRequirements = true
                        if not req.completed then allCompleted = false; break end
                    end
                end
            end
            if hasRequirements and allCompleted and UIThingsDB.tracker.hideCompletedSubtasks then
                -- skip
            else
                AddLine(activity.activityName or "Unknown Activity", false, nil, nil, false, nil, activityID)
                if activity.requirementsList and #activity.requirementsList > 0 then
                    for _, req in ipairs(activity.requirementsList) do
                        if req and req.requirementText and req.requirementText ~= "" then
                            if not (req.completed and UIThingsDB.tracker.hideCompletedSubtasks) then
                                local objText = req.requirementText
                                if req.completed then objText = FormatCompletedObjective(objText) end
                                AddLine(objText, false, nil, nil, true, nil, activityID)
                            end
                        end
                    end
                end
                ucState.yOffset = ucState.yOffset - ITEM_SPACING
            end
        end
    end
    ucState.yOffset = ucState.yOffset - SECTION_SPACING
end

local function RenderCampaignQuests()
    local numQuests = C_QuestLog.GetNumQuestWatches()
    if numQuests == 0 then return end
    local superTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID()
    wipe(campaignOrder); wipe(questsByCampaign)
    local flatCampaignQuests = {}
    for i = 1, numQuests do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if questID and not displayedIDs[questID] then
            if C_CampaignInfo and C_CampaignInfo.IsCampaignQuest and C_CampaignInfo.IsCampaignQuest(questID) then
                local campaignID = C_CampaignInfo.GetCampaignID(questID)
                local campaignName = "Campaign"
                if campaignID and campaignID > 0 then
                    local info = C_CampaignInfo.GetCampaignInfo(campaignID)
                    campaignName = (info and info.name) or ("Campaign " .. campaignID)
                end
                table.insert(flatCampaignQuests, questID)
                if not questsByCampaign[campaignName] then
                    questsByCampaign[campaignName] = {}; table.insert(campaignOrder, campaignName)
                end
                table.insert(questsByCampaign[campaignName], questID)
            end
        end
    end
    if #flatCampaignQuests == 0 then return end
    if UIThingsDB.tracker.sortQuestsByDistance then
        table.sort(flatCampaignQuests, sortByDistanceSq)
        for _, name in ipairs(campaignOrder) do table.sort(questsByCampaign[name], sortByDistanceSq) end
    end
    AddLine("Campaign Quests (" .. #flatCampaignQuests .. ")", true, "campaignQuests")
    if UIThingsDB.tracker.collapsed["campaignQuests"] then
        ucState.yOffset = ucState.yOffset - ITEM_SPACING
        return
    end

    local function RenderOneCampaignQuest(questID, extraIndent)
        if displayedIDs[questID] then return end
        if extraIndent then ucState.indent = extraIndent end
        local title = C_QuestLog.GetTitleForQuestID(questID)
        if title then
            title = GetQuestTypePrefix(questID) .. title .. GetQuestLineString(questID) .. GetDistanceString(questID)
            local color
            if questID == superTrackedQuestID then color = UIThingsDB.tracker.activeQuestColor
            else color = UIThingsDB.tracker.campaignQuestColor end
            AddLine(title, false, questID, nil, false, color)
            displayedIDs[questID] = true
            local objectives = C_QuestLog.GetQuestObjectives(questID)
            if objectives then
                for _, obj in pairs(objectives) do
                    if not (obj.finished and UIThingsDB.tracker.hideCompletedSubtasks) then
                        local objText = obj.text
                        if objText and objText ~= "" then
                            if obj.finished then objText = FormatCompletedObjective(objText) end
                            AddLine(objText, false, questID, nil, true)
                        end
                    end
                end
            end
            if C_QuestLog.IsComplete(questID) then
                local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
                local isAutoComplete = false
                if logIndex then
                    local info = C_QuestLog.GetInfo(logIndex)
                    if info then isAutoComplete = info.isAutoComplete or false end
                    if not isAutoComplete and GetQuestLogIsAutoComplete then
                        isAutoComplete = GetQuestLogIsAutoComplete(logIndex) == 1
                    end
                end
                if isAutoComplete then
                    AddLine("|cFFFFD100Click to complete quest|r", false, questID, nil, true)
                end
            end
            ucState.yOffset = ucState.yOffset - ITEM_SPACING
        end
        if extraIndent then ucState.indent = 0 end
    end

    if superTrackedQuestID and not displayedIDs[superTrackedQuestID] then
        if C_CampaignInfo and C_CampaignInfo.IsCampaignQuest and C_CampaignInfo.IsCampaignQuest(superTrackedQuestID) then
            RenderOneCampaignQuest(superTrackedQuestID)
        end
    end

    if UIThingsDB.tracker.groupQuestsByCampaign then
        for _, campaignName in ipairs(campaignOrder) do
            local quests = questsByCampaign[campaignName]
            local remaining = {}
            for _, qID in ipairs(quests) do
                if not displayedIDs[qID] then table.insert(remaining, qID) end
            end
            if #remaining > 0 then
                local isCollapsed = UIThingsDB.tracker.collapsed["campaignGroup_" .. campaignName]
                local btn = AcquireItem()
                btn:Show(); btn.questID = nil; btn.achieID = nil
                btn:SetScript("OnClick", nil)
                btn:SetWidth(ucState.width)
                btn:SetPoint("TOPLEFT", 0, ucState.yOffset)
                btn.Text:SetFont(ucState.questNameFont, ucState.questNameSize, "OUTLINE")
                btn.Text:SetText(campaignName .. " (" .. #remaining .. ")")
                local cqc = UIThingsDB.tracker.campaignQuestColor or { r = 0.9, g = 0.7, b = 0.2 }
                btn.Text:SetTextColor(cqc.r, cqc.g, cqc.b)
                btn.Icon:Hide()
                btn.Text:SetPoint("LEFT", 10, 0)
                btn:EnableMouse(false)
                btn:SetScript("OnEnter", nil); btn:SetScript("OnLeave", nil)
                if btn.ItemBtn and not InCombatLockdown() then btn.ItemBtn:Hide() end
                btn.ToggleBtn:Show()
                btn.ToggleBtn:SetScript("OnClick", function(self, button)
                    if InCombatLockdown() and button == "LeftButton" then return end
                    UIThingsDB.tracker.collapsed["campaignGroup_" .. campaignName] = not isCollapsed
                    UpdateContent()
                end)
                btn.ToggleBtn.Text:SetText(isCollapsed and "+" or "-")
                local textWidth = btn.Text:GetStringWidth()
                btn.ToggleBtn:SetPoint("LEFT", btn.Text, "LEFT", textWidth + 5, 0)
                ucState.yOffset = ucState.yOffset - (ucState.questNameSize + 4)
                if not isCollapsed then
                    for _, qID in ipairs(remaining) do RenderOneCampaignQuest(qID, 10) end
                end
                ucState.yOffset = ucState.yOffset - ITEM_SPACING
            end
        end
    else
        for _, questID in ipairs(flatCampaignQuests) do RenderOneCampaignQuest(questID) end
    end
    ucState.yOffset = ucState.yOffset - SECTION_SPACING
end

local sectionRenderers = {
    scenarios = RenderScenarios,
    tempObjectives = function() end,
    travelersLog = RenderTravelersLog,
    worldQuests = RenderWorldQuests,
    campaignQuests = RenderCampaignQuests,
    quests = RenderQuests,
    achievements = RenderAchievements,
}

UpdateContent = function()
    if not trackerFrame then return end
    if trackerHiddenByKeybind then return end

    local inCombat = InCombatLockdown()
    local enabled = UIThingsDB.tracker.enabled
    local shouldHideMPlus = enabled and (UIThingsDB.tracker.hideInMPlus and C_ChallengeMode.IsChallengeModeActive())

    if not enabled or shouldHideMPlus then
        if not inCombat then
            UnregisterStateDriver(trackerFrame, "visibility")
            trackerFrame:Hide()
        end
        return
    end

    if not inCombat then
        if UIThingsDB.tracker.hideInCombat then
            RegisterStateDriver(trackerFrame, "visibility", "[combat] hide; show")
        else
            UnregisterStateDriver(trackerFrame, "visibility")
            trackerFrame:Show()
        end
    end

    ReleaseItems()

    local cachedMapID = C_Map.GetBestMapForUnit("player")
    local cachedTasks = cachedMapID and C_TaskQuest.GetQuestsOnMap(cachedMapID) or nil

    ucState.baseFont = UIThingsDB.tracker.font or "Fonts\\FRIZQT__.TTF"
    ucState.baseSize = UIThingsDB.tracker.fontSize or 12
    ucState.questNameFont = UIThingsDB.tracker.headerFont or "Fonts\\FRIZQT__.TTF"
    ucState.questNameSize = UIThingsDB.tracker.headerFontSize or 14
    ucState.detailFont = UIThingsDB.tracker.detailFont or "Fonts\\FRIZQT__.TTF"
    ucState.detailSize = UIThingsDB.tracker.detailFontSize or 12
    ucState.questPadding = UIThingsDB.tracker.questPadding or 2
    SECTION_SPACING = UIThingsDB.tracker.sectionSpacing or 10
    ITEM_SPACING = UIThingsDB.tracker.itemSpacing or 5
    ucState.sectionHeaderFont = UIThingsDB.tracker.sectionHeaderFont or "Fonts\\FRIZQT__.TTF"
    ucState.sectionHeaderSize = UIThingsDB.tracker.sectionHeaderFontSize or 14
    ucState.sectionHeaderColor = UIThingsDB.tracker.sectionHeaderColor or { r = 1, g = 0.82, b = 0, a = 1 }
    ucState.questNameColor = UIThingsDB.tracker.questNameColor or { r = 1, g = 1, b = 1, a = 1 }
    ucState.objectiveColor = UIThingsDB.tracker.objectiveColor or { r = 0.8, g = 0.8, b = 0.8, a = 1 }
    ucState.yOffset = -5
    ucState.indent = 0
    ucState.width = scrollChild:GetWidth()
    ucState.cachedMapID = cachedMapID
    ucState.cachedTasks = cachedTasks

    UIThingsDB.tracker.collapsed = UIThingsDB.tracker.collapsed or {}
    AutoUntrackCompletedPerksActivities()
    wipe(displayedIDs)

    local orderList = UIThingsDB.tracker.sectionOrderList
    if not orderList then
        local oldOrder = UIThingsDB.tracker.sectionOrder or 1
        local oldOrderMap = {
            [1] = { "scenarios", "worldQuests", "quests", "achievements" },
            [2] = { "scenarios", "worldQuests", "achievements", "quests" },
            [3] = { "scenarios", "quests", "worldQuests", "achievements" },
            [4] = { "scenarios", "quests", "achievements", "worldQuests" },
            [5] = { "scenarios", "achievements", "worldQuests", "quests" },
            [6] = { "scenarios", "achievements", "quests", "worldQuests" },
        }
        orderList = oldOrderMap[oldOrder] or oldOrderMap[1]
        table.insert(orderList, 2, "tempObjectives")
        table.insert(orderList, 3, "travelersLog")
        UIThingsDB.tracker.sectionOrderList = orderList
    else
        local hasTravelersLog = false
        for _, key in ipairs(orderList) do
            if key == "travelersLog" then hasTravelersLog = true; break end
        end
        if not hasTravelersLog then
            local insertPos = 3
            for i, key in ipairs(orderList) do
                if key == "tempObjectives" then insertPos = i + 1; break end
            end
            table.insert(orderList, insertPos, "travelersLog")
        end
        local hasCampaignQuests = false
        for _, key in ipairs(orderList) do
            if key == "campaignQuests" then hasCampaignQuests = true; break end
        end
        if not hasCampaignQuests then
            local insertPos = #orderList + 1
            for i, key in ipairs(orderList) do
                if key == "quests" then insertPos = i; break end
            end
            table.insert(orderList, insertPos, "campaignQuests")
        end
    end

    local seen = {}; local deduped = {}
    for _, key in ipairs(orderList) do
        if not seen[key] then seen[key] = true; table.insert(deduped, key) end
    end
    for i = #orderList, 1, -1 do orderList[i] = nil end
    for i, key in ipairs(deduped) do orderList[i] = key end

    campaignQuestsSectionActive = false
    for _, key in ipairs(orderList) do
        if key == "campaignQuests" then campaignQuestsSectionActive = true; break end
    end

    for _, sectionKey in ipairs(orderList) do
        local renderer = sectionRenderers[sectionKey]
        if renderer then renderer() end
    end

    -- If we proximity-tracked a WQ and it's no longer in the display, restore the
    -- saved campaign quest. validWQs is repopulated by RenderWorldQuests each frame.
    if proximityTrackedWQ and cachedMapID and not validWQs[proximityTrackedWQ] then
        local currentST = C_SuperTrack.GetSuperTrackedQuestID()
        if currentST == proximityTrackedWQ then
            if savedSuperTrackedQuestID
                and C_QuestLog.IsOnQuest(savedSuperTrackedQuestID)
                and C_QuestLog.GetQuestWatchType(savedSuperTrackedQuestID) then
                C_SuperTrack.SetSuperTrackedQuestID(savedSuperTrackedQuestID)
            end
            savedSuperTrackedQuestID = nil
        end
        proximityTrackedWQ = nil
    end

    if ucState.yOffset == -5 and UIThingsDB.tracker.locked then
        if not inCombat then
            UnregisterStateDriver(trackerFrame, "visibility")
            trackerFrame:Hide()
        end
        return
    end

    local totalHeight = math.abs(ucState.yOffset)
    scrollChild:SetHeight(math.max(totalHeight, 50))
    UpdateQuestItemButton()
end

addonTable.ObjectiveTracker.UpdateContent = UpdateContent

-- Keybind toggle
function LunaUITweaks_ToggleTracker()
    if not trackerFrame or not UIThingsDB.tracker.enabled then return end
    if InCombatLockdown() then return end
    if trackerHiddenByKeybind then
        trackerHiddenByKeybind = false
        UpdateContent()
    else
        trackerHiddenByKeybind = true
        UnregisterStateDriver(trackerFrame, "visibility")
        trackerFrame:Hide()
    end
end

-- Auto-track new quests
autoTrackFrame = CreateFrame("Frame")
autoTrackFrame:SetScript("OnEvent", function(self, event, questID)
    if event == "QUEST_ACCEPTED" and questID then
        if UIThingsDB.tracker and UIThingsDB.tracker.enabled and UIThingsDB.tracker.autoTrackQuests then
            if not C_QuestLog.GetQuestWatchType(questID) then
                C_QuestLog.AddQuestWatch(questID, Enum.QuestWatchType.Automatic)
                if (C_SuperTrack.GetSuperTrackedQuestID() or 0) == 0 then
                    C_SuperTrack.SetSuperTrackedQuestID(questID)
                end
                SafeAfter(0.2, UpdateContent)
            end
        end
    end
end)

-- ============================================================
-- Events
-- ============================================================
local function RegisterTrackerEvents(frame)
    frame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
    frame:RegisterEvent("TRACKED_ACHIEVEMENT_LIST_CHANGED")
    frame:RegisterEvent("CONTENT_TRACKING_UPDATE")
    frame:RegisterEvent("CONTENT_TRACKING_LIST_UPDATE")
    frame:RegisterEvent("QUEST_LOG_UPDATE")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("CHALLENGE_MODE_START")
    frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    frame:RegisterEvent("CHALLENGE_MODE_RESET")
    frame:RegisterEvent("SUPER_TRACKING_CHANGED")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:RegisterEvent("ZONE_CHANGED")
    frame:RegisterEvent("TASK_PROGRESS_UPDATE")
    frame:RegisterEvent("QUEST_ACCEPTED")
    frame:RegisterEvent("QUEST_REMOVED")
    frame:RegisterEvent("PERKS_ACTIVITIES_TRACKED_LIST_CHANGED")
    frame:RegisterEvent("PERKS_ACTIVITIES_TRACKED_UPDATED")
    frame:RegisterEvent("SCENARIO_UPDATE")
    frame:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
    frame:RegisterEvent("SCENARIO_COMPLETED")
end

SetupTrackerEvents = function()
    if not trackerFrame then return end
    RegisterTrackerEvents(trackerFrame)
    trackerFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            SafeAfter(2, UpdateContent)
        elseif event == "PLAYER_REGEN_DISABLED" then
            -- handled by StateDriver
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pendingQuestItemUpdate then
                pendingQuestItemUpdate = nil
                UpdateQuestItemButton()
            end
            UpdateContent()
        elseif event == "CHALLENGE_MODE_START" then
            if UIThingsDB.tracker.hideInMPlus then trackerFrame:Hide() end
        elseif event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
            if UIThingsDB.tracker.hideInMPlus then trackerFrame:Show() end
            ScheduleUpdateContent()
        elseif event == "SUPER_TRACKING_CHANGED" then
            HandleSuperTrackChanged()
            UpdateQuestItemButton()
            ScheduleUpdateContent()
        elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
            CheckRestoreSuperTrack()
            local trackedQuestIDs = {}
            for i = 1, C_QuestLog.GetNumQuestWatches() do
                local qid = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
                if qid then trackedQuestIDs[qid] = true end
            end
            for qid in pairs(prevObjectiveState) do
                if not trackedQuestIDs[qid] then
                    prevObjectiveState[qid] = nil
                    prevQuestComplete[qid] = nil
                end
            end
            ScheduleUpdateContent()
        elseif event == "QUEST_REMOVED" then
            local questID = ...
            if questID then
                prevObjectiveState[questID] = nil
                prevQuestComplete[questID] = nil
                if savedSuperTrackedQuestID == questID then
                    savedSuperTrackedQuestID = nil
                end
                if proximityTrackedWQ == questID then
                    proximityTrackedWQ = nil
                    -- WQ auto-removed on area exit — restore the saved campaign quest.
                    local currentST = C_SuperTrack.GetSuperTrackedQuestID()
                    if currentST == questID then
                        if savedSuperTrackedQuestID
                            and C_QuestLog.IsOnQuest(savedSuperTrackedQuestID)
                            and C_QuestLog.GetQuestWatchType(savedSuperTrackedQuestID) then
                            C_SuperTrack.SetSuperTrackedQuestID(savedSuperTrackedQuestID)
                        end
                        savedSuperTrackedQuestID = nil
                    end
                end
            end
            ScheduleUpdateContent()
        else
            if event == "QUEST_LOG_UPDATE" or event == "TASK_PROGRESS_UPDATE" then
                CheckCompletionSounds()
            end
            ScheduleUpdateContent()
        end
    end)
end

-- ============================================================
-- Startup
-- ============================================================
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        lastKnownSuperTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID()
        -- Seed prevQuestComplete so quests already complete at login don't trigger sounds
        local numWatches = C_QuestLog.GetNumQuestWatches()
        for i = 1, numWatches do
            local qID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
            if qID then
                prevQuestComplete[qID] = C_QuestLog.IsComplete(qID)
            end
        end
        addonTable.ObjectiveTracker.UpdateSettings()
    else
        SafeAfter(1, function() addonTable.ObjectiveTracker.UpdateSettings() end)
    end
end)

local hookFrame = CreateFrame("Frame")
hookFrame:RegisterEvent("PLAYER_LOGIN")
hookFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
hookFrame:SetScript("OnEvent", function(self, event)
    HookBlizzardTracker()
    if blizzardTrackerHooked then
        if UIThingsDB and UIThingsDB.tracker and UIThingsDB.tracker.enabled and ObjectiveTrackerFrame then
            ObjectiveTrackerFrame:SetAlpha(0)
            ObjectiveTrackerFrame:SetScale(0.00001)
            ObjectiveTrackerFrame:EnableMouse(false)
        end
        self:UnregisterAllEvents()
    end
end)
