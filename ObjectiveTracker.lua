local addonName, addonTable = ...
addonTable.ObjectiveTracker = {}

local trackerFrame
local scrollFrame
local scrollChild
local contentFrame
local headerFrame
local itemPool = {}
local autoTrackFrame
local distanceTicker

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

-- Binding display names are defined in Core.lua

-- Pending item update for when we leave combat
local pendingQuestItemUpdate = nil
local trackerHiddenByKeybind = false

local function UpdateQuestItemButton()
    if InCombatLockdown() then
        pendingQuestItemUpdate = true
        return
    end
    local questID = C_SuperTrack.GetSuperTrackedQuestID()
    if questID and questID ~= 0 then
        local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
        if logIndex then
            local questItemLink, questItemIcon = GetQuestLogSpecialItemInfo(logIndex)
            if questItemLink then
                questItemButton:SetAttribute("type", "item")
                questItemButton:SetAttribute("item", questItemLink)
                return
            end
        end
    end
    -- No item found, clear attributes
    questItemButton:SetAttribute("type", nil)
    questItemButton:SetAttribute("item", nil)
end

-- Constants
local MINUTES_PER_DAY = 1440
local MINUTES_PER_HOUR = 60
local UPDATE_THROTTLE_DELAY = 0.1
-- These are updated from settings in UpdateContent via ucState
local SECTION_SPACING = 10
local ITEM_SPACING = 5

-- Centralized Logging
local Log = function(msg, level)
    if addonTable.Core and addonTable.Core.Log then
        addonTable.Core.Log("Tracker", msg, level)
    else
        print("UIThings: " .. tostring(msg))
    end
end

local SafeAfter = addonTable.Core.SafeAfter



local function OnQuestClick(self, button)
    -- Shift-Left-Click to link quest in chat (WoW convention)
    if button == "LeftButton" and IsShiftKeyDown() and self.questID and type(self.questID) == "number" and UIThingsDB.tracker.shiftClickLink then
        local questLink = GetQuestLink(self.questID)
        if questLink and ChatFrame1EditBox:IsShown() then
            ChatFrame1EditBox:Insert(questLink)
        elseif questLink then
            ChatFrame_OpenChat(questLink)
        end
        return
    end

    -- Ctrl-Left-Click to Untrack (if enabled)
    if button == "LeftButton" and IsControlKeyDown() and self.questID and type(self.questID) == "number" and UIThingsDB.tracker.shiftClickUntrack then
        C_QuestLog.RemoveQuestWatch(self.questID)
        SafeAfter(0.1, addonTable.ObjectiveTracker.UpdateContent)
        return
    end

    -- Middle-Click to share quest with party
    if button == "MiddleButton" and self.questID and type(self.questID) == "number" and UIThingsDB.tracker.middleClickShare then
        if IsInGroup() and C_QuestLog.IsPushableQuest(self.questID) then
            C_QuestLog.SetSelectedQuest(self.questID)
            QuestLogPushQuest()
        end
        return
    end

    -- Right-Click to Super Track (if enabled) - Toggle behavior
    if button == "RightButton" and self.questID and type(self.questID) == "number" and UIThingsDB.tracker.rightClickSuperTrack then
        if C_SuperTrack.GetSuperTrackedQuestID() == self.questID then
            C_SuperTrack.ClearAllSuperTracked() -- Clear super tracking
        else
            C_SuperTrack.SetSuperTrackedQuestID(self.questID)
        end
        SafeAfter(0.1, addonTable.ObjectiveTracker.UpdateContent) -- Refresh list
        return
    end

    -- Left-Click: autocomplete quests that are ready → show completion UI (higher priority than quest log)
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

    -- Left-Click to open quest log (blocked in combat — UI panels are protected)
    if not InCombatLockdown() and self.questID and type(self.questID) == "number" and UIThingsDB.tracker.clickOpenQuest then
        -- Try modern Map/Quest Log
        if QuestMapFrame_OpenToQuestDetails then
            -- Make sure the frame is shown first
            if not QuestMapFrame:IsShown() then ToggleQuestLog() end
            QuestMapFrame_OpenToQuestDetails(self.questID)
        else
            -- Fallback
            QuestLog_OpenToQuest(self.questID)
        end
    end
end

local function OnAchieveClick(self, button)
    -- Disable left-click in combat
    if InCombatLockdown() and button == "LeftButton" then return end

    -- Shift-Click to Untrack (if enabled)
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

    -- Open Achievement UI
    if self.achieID then
        if not AchievementFrame then AchievementFrame_LoadUI() end
        if AchievementFrame then
            AchievementFrame_ToggleAchievementFrame()
            AchievementFrame_SelectAchievement(self.achieID)
        end
    end
end

local function OnPerksActivityClick(self, button)
    -- Shift-Click to Untrack (if enabled)
    if IsShiftKeyDown() and self.perksActivityID and UIThingsDB.tracker.shiftClickUntrack then
        if C_PerksActivities and C_PerksActivities.RemoveTrackedPerksActivity then
            C_PerksActivities.RemoveTrackedPerksActivity(self.perksActivityID)
            SafeAfter(0.1, addonTable.ObjectiveTracker.UpdateContent)
        end
        return
    end
end



-- Toggle Button Factory (Yellow +/-)
local function CreateToggleButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(30, 30)

    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 25, "OUTLINE")
    text:SetPoint("CENTER", 0, 0)
    text:SetShadowOffset(1, -1)
    text:SetTextColor(1, 0.82, 0) -- Yellow
    btn.Text = text

    return btn
end

-- Item Factories
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
    icon:SetSize(14, 14) -- Slightly smaller than text height
    icon:SetPoint("LEFT", 0, 0)
    btn.Icon = icon

    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", icon, "RIGHT", 5, 0) -- Indent text
    text:SetPoint("RIGHT", 0, 0)
    text:SetJustifyH("LEFT")
    btn.Text = text

    -- Toggle Button (Hidden by default)
    local toggleBtn = CreateToggleButton(btn)
    toggleBtn:SetPoint("LEFT", text, "RIGHT", 5, 0)
    toggleBtn:Hide()
    btn.ToggleBtn = toggleBtn

    -- Quest Item Button (Hidden by default)
    -- Parent to UIParent so no frame in the tracker hierarchy becomes tainted
    local itemBtn = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    itemBtn:SetSize(20, 20)
    itemBtn:Hide()
    itemBtn:RegisterForClicks("AnyUp", "AnyDown")
    itemBtn:SetFrameLevel(btn:GetFrameLevel() + 2)
    itemBtn.iconTex = itemBtn:CreateTexture(nil, "ARTWORK")
    itemBtn.iconTex:SetAllPoints()
    itemBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    btn.ItemBtn = itemBtn

    -- Progress Bar for Supertracked Quest (Hidden by default)
    local progressBar = CreateFrame("StatusBar", nil, btn)
    progressBar:SetSize(0, 3)
    progressBar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 19, -2)
    progressBar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -25, -2)
    progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    progressBar:SetStatusBarColor(1, 0.82, 0, 1) -- Gold color
    progressBar:SetMinMaxValues(0, 100)
    progressBar:SetValue(0)
    progressBar:Hide()

    -- Progress bar background
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

-- Set to true by UpdateContent when campaignQuests section is in the active order list,
-- so RenderQuests knows to exclude campaign quests from the regular Quests section.
local campaignQuestsSectionActive = false

-- Shared state for UpdateContent and its helper functions (avoids per-call closure/table allocation)
local ucState = {
    yOffset = 0,
    width = 0,
    baseFont = "",
    baseSize = 12,
    questNameFont = "",
    questNameSize = 14,
    detailFont = "",
    detailSize = 12,
    questPadding = 2,
    cachedMapID = nil,
    cachedTasks = nil,
}

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

-- Pre-defined sort comparators (avoid closure allocation in hot paths)
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

-- Quest/objective completion sound tracking
local prevObjectiveState = {} -- [questID] = { [objIndex] = { finished = bool, text = string } }
local prevQuestComplete = {}  -- [questID] = bool
local tooltipMembers = {}     -- Reusable table for tooltip party member list

-- Super-track restore: remember the user's manually tracked quest when a WQ takes over
local savedSuperTrackedQuestID = nil
local lastKnownSuperTrackedQuestID = nil

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

    -- Quest completion sound
    if playQuestSound and isComplete and wasComplete == false then
        PlaySound(UIThingsDB.tracker.questCompletionSoundID or 6199, channel)
    end

    -- Auto-supertrack nearest campaign quest when a campaign quest just completed in the field
    if isComplete and wasComplete == false
        and UIThingsDB.tracker.autoTrackQuests
        and C_CampaignInfo and C_CampaignInfo.IsCampaignQuest and C_CampaignInfo.IsCampaignQuest(questID) then
        SafeAfter(1.5, function()
            if InCombatLockdown() then return end
            local stNow = C_SuperTrack.GetSuperTrackedQuestID()
            -- Leave it if already super-tracking a different active campaign quest
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

    -- Objective completion sound
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

    -- Regular tracked quests
    local numWatches = C_QuestLog.GetNumQuestWatches()
    for i = 1, numWatches do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if questID and not checked[questID] then
            checked[questID] = true
            CheckQuestSounds(questID, playQuestSound, playObjSound)
        end
    end

    -- World quests and task quests on the current map
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

    -- Hidden task quests (bonus objectives)
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.isHidden and info.isTask and info.questID and not checked[info.questID] then
            checked[info.questID] = true
            CheckQuestSounds(info.questID, playQuestSound, playObjSound)
        end
    end
end

local UpdateContent -- forward declaration for ScheduleUpdateContent

-- Helper to extract progress from objective text
local function GetObjectiveProgress(objectiveText)
    if not objectiveText then return 0, false end

    -- Check for percentage in text (e.g., "50%" or "Progress: 27%")
    local percentMatch = objectiveText:match("(%d+)%%")
    if percentMatch then
        return tonumber(percentMatch), true
    end

    -- Check for count-based objectives (e.g., "10/20 items")
    local current, total = objectiveText:match("(%d+)/(%d+)")
    if current and total then
        current, total = tonumber(current), tonumber(total)
        if total > 0 then
            return (current / total) * 100, true
        end
    end

    return 0, false
end

-- Helper to add lines (hoisted from UpdateContent)
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

        ucState.yOffset = ucState.yOffset - (ucState.sectionHeaderSize + 6)
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

            -- Show progress bar only for supertracked quest objectives with progress
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
                            -- Position absolutely so no anchor dependency taints btn
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
                        if not InCombatLockdown() then
                            btn.ItemBtn:Hide()
                        end
                    end
                else
                    if not InCombatLockdown() then
                        btn.ItemBtn:Hide()
                    end
                end
            else
                btn.Icon:Hide()
                btn.Text:SetPoint("LEFT", 19, 0)
                if achieID then btn:EnableMouse(true) else btn:EnableMouse(false) end
                if btn.ItemBtn and not InCombatLockdown() then btn.ItemBtn:Hide() end
            end

            -- Tooltip preview on hover
            if UIThingsDB.tracker.showTooltipPreview and (questID or achieID or perksActivityID) then
                btn:SetScript("OnEnter", function(self)
                    if self.questID then
                        GameTooltip:SetOwner(self, "ANCHOR_NONE")
                        GameTooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 5, 0)
                        GameTooltip:SetHyperlink("quest:" .. self.questID)
                        -- Show party members on the same quest
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

                        -- Get activity data
                        local allActivities = C_PerksActivities.GetPerksActivitiesInfo()
                        if allActivities and allActivities.activities then
                            for _, activity in ipairs(allActivities.activities) do
                                if activity.ID == self.perksActivityID then
                                    -- Show activity name as title
                                    GameTooltip:AddLine(activity.activityName, 1, 1, 1)

                                    -- Show description if available
                                    if activity.description and activity.description ~= "" then
                                        GameTooltip:AddLine(activity.description, nil, nil, nil, true)
                                    end

                                    -- Show requirements
                                    if activity.requirementsList and #activity.requirementsList > 0 then
                                        GameTooltip:AddLine(" ")
                                        for _, req in ipairs(activity.requirementsList) do
                                            if req.requirementText then
                                                local r, g, b = 1, 1, 1
                                                if req.completed then
                                                    r, g, b = 0, 1, 0 -- Green for completed
                                                end
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

--- Returns campaign quest color override if quest is a campaign quest
local function GetCampaignColor(questID)
    if not UIThingsDB.tracker.highlightCampaignQuests then return nil end
    if C_CampaignInfo and C_CampaignInfo.IsCampaignQuest and C_CampaignInfo.IsCampaignQuest(questID) then
        return UIThingsDB.tracker.campaignQuestColor
    end
    return nil
end

--- Returns a prefix tag for daily/weekly quests
local function GetQuestTypePrefix(questID)
    if not UIThingsDB.tracker.showQuestTypeIndicators then return "" end
    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    if logIndex then
        local info = C_QuestLog.GetInfo(logIndex)
        if info and info.frequency then
            if info.frequency == Enum.QuestFrequency.Daily then
                return "|cFF00CCFF[D]|r "
            elseif info.frequency == Enum.QuestFrequency.Weekly then
                return "|cFFCC00FF[W]|r "
            end
        end
    end
    -- Fallback: check if repeatable (callings, etc.)
    if C_QuestLog.IsRepeatableQuest and C_QuestLog.IsRepeatableQuest(questID) then
        return "|cFF00CCFF[R]|r "
    end
    return ""
end

--- Returns a reward type icon string for world quests
local function GetWQRewardIcon(questID)
    if not UIThingsDB.tracker.showWQRewardIcons then return "" end

    -- Check reward type via quest reward APIs (pcall for safety since some may not be available for all WQs)
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

    if numRewards > 0 then
        return "|TInterface\\Minimap\\Tracking\\Banker:0|t "
    elseif #currencies > 0 then
        return "|TInterface\\Minimap\\Tracking\\Auctioneer:0|t "
    elseif goldReward > 0 then
        return "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t "
    end
    return ""
end

--- Formats a completed objective with optional checkmark prefix
local function FormatCompletedObjective(text)
    if UIThingsDB.tracker.completedObjectiveCheckmark then
        return "|cFF00FF00|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t " .. text .. "|r"
    else
        return "|cFF00FF00" .. text .. "|r"
    end
end

--- Formats time remaining for World Quests with urgency coloring
local function GetTimeLeftString(questID)
    local timeLeftMinutes = C_TaskQuest.GetQuestTimeLeftMinutes(questID)
    if timeLeftMinutes and timeLeftMinutes > 0 then
        local days = math.floor(timeLeftMinutes / MINUTES_PER_DAY)
        local hours = math.floor((timeLeftMinutes % MINUTES_PER_DAY) / MINUTES_PER_HOUR)
        local minutes = timeLeftMinutes % 60

        local timeStr
        if days > 0 then
            timeStr = string.format("(%dd %dh)", days, hours)
        elseif hours > 0 then
            timeStr = string.format("(%dh %dm)", hours, minutes)
        else
            timeStr = string.format("(%dm)", minutes)
        end

        -- Color by urgency: green >4h, yellow 1-4h, orange 15m-1h, red <15m
        local color
        if timeLeftMinutes > 240 then
            color = "00FF00" -- green
        elseif timeLeftMinutes > 60 then
            color = "FFFF00" -- yellow
        elseif timeLeftMinutes > 15 then
            color = "FF8800" -- orange
        else
            color = "FF0000" -- red
        end

        return string.format(" |cFF%s%s|r", color, timeStr)
    end
    return ""
end

--- Formats distance to quest with grey coloring, localized units
local useMetric = not (GetLocale() == "enUS" or GetLocale() == "enGB")
local function GetDistanceString(questID)
    if not UIThingsDB.tracker.showQuestDistance then return "" end
    local distSq = C_QuestLog.GetDistanceSqToQuest(questID)
    if not distSq then return "" end
    local dist = math.sqrt(distSq)
    local unit = "yds"
    if useMetric then
        dist = dist * 0.9144
        unit = "m"
    end
    if dist >= 1000 then
        return string.format(" |cFFAAAAAA(%.1fk %s)|r", dist / 1000, unit)
    else
        return string.format(" |cFFAAAAAA(%d %s)|r", dist, unit)
    end
end

--- Returns questline progress string e.g. " |cFF888888(3/7)|r" or ""
local questLineCache = {} -- [questID] = { str, expiry }
local function GetQuestLineString(questID)
    if not UIThingsDB.tracker.showQuestLineProgress then return "" end
    if not C_QuestLine or not C_QuestLine.GetQuestLineInfo then return "" end

    -- Cache to avoid repeated API calls per update cycle
    local cached = questLineCache[questID]
    if cached and cached.expiry > GetTime() then
        return cached.str
    end

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

    -- Find current quest's position and count completed
    local currentStep = 0
    local totalSteps = #quests
    for i, qID in ipairs(quests) do
        if qID == questID then
            currentStep = i
            break
        end
    end

    -- If we couldn't find the quest in the list, count completed + 1 as fallback
    if currentStep == 0 then
        local completed = 0
        for _, qID in ipairs(quests) do
            if C_QuestLog.IsQuestFlaggedCompleted(qID) then
                completed = completed + 1
            end
        end
        currentStep = completed + 1
    end

    local str = string.format(" |cFF888888(%d/%d)|r", currentStep, totalSteps)
    questLineCache[questID] = { str = str, expiry = GetTime() + 30 }
    return str
end

--- Renders a single World Quest entry
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

--- Renders all World Quests for the current map
local function RenderWorldQuests()
    if not ucState.cachedMapID then return end

    local tasks = ucState.cachedTasks
    local threatQuests = C_TaskQuest.GetThreatQuests()

    wipe(activeWQs)
    wipe(otherWQs)
    wipe(validWQs)
    local onlyActive = UIThingsDB.tracker.onlyActiveWorldQuests

    local superTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID()

    if tasks then
        for _, info in ipairs(tasks) do
            local questID = info.questID
            if questID and C_TaskQuest.IsActive(questID) then
                local isWorldQuest = C_QuestLog.IsWorldQuest(questID)
                local isTaskQuest = C_QuestLog.IsQuestTask(questID)

                if isWorldQuest or isTaskQuest then
                    validWQs[questID] = true

                    local isActive = C_QuestLog.IsOnQuest(questID)

                    if isTaskQuest and not isWorldQuest then
                        if isActive then
                            table.insert(activeWQs, questID)
                        end
                    elseif isWorldQuest then
                        if onlyActive then
                            if isActive then
                                table.insert(activeWQs, questID)
                            end
                        else
                            if isActive then
                                table.insert(activeWQs, questID)
                            else
                                table.insert(otherWQs, questID)
                            end
                        end
                    end
                end
            end
        end
    end

    -- Sort world quests by chosen method
    local wqSortBy = UIThingsDB.tracker.worldQuestSortBy or "time"
    if wqSortBy == "distance" then
        table.sort(activeWQs, sortByDistanceSq)
        table.sort(otherWQs, sortByDistanceSq)
    else
        table.sort(activeWQs, sortByTimeLeft)
        table.sort(otherWQs, sortByTimeLeft)
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

        for _, questID in ipairs(activeWQs) do
            RenderSingleWQ(questID, superTrackedQuestID)
        end

        for _, questID in ipairs(otherWQs) do
            RenderSingleWQ(questID, superTrackedQuestID)
        end

        ucState.yOffset = ucState.yOffset - SECTION_SPACING
    end
end

local function RenderQuests()
    local numQuestLogEntries = C_QuestLog.GetNumQuestLogEntries()
    wipe(hiddenTaskQuests)

    for i = 1, numQuestLogEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.isHidden and info.isTask and info.isOnMap and info.questID then
            if not displayedIDs[info.questID] then
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
                -- If campaignQuests section is active, exclude campaign quests from this section
                if campaignQuestsSectionActive and
                    C_CampaignInfo and C_CampaignInfo.IsCampaignQuest and C_CampaignInfo.IsCampaignQuest(qID) then
                    -- skip — will be rendered in campaignQuests section
                elseif not displayedIDs[qID] then
                    if qID == superTrackedQuestID then
                        superTrackedIndex = i
                    else
                        table.insert(filteredIndices, i)
                    end
                end
            end
        end

        -- Sort quests by distance if enabled
        if UIThingsDB.tracker.sortQuestsByDistance then
            table.sort(filteredIndices, sortWatchIndexByDistance)
        end

        if superTrackedIndex then
            table.insert(filteredIndices, 1, superTrackedIndex)
        end

        if #filteredIndices > 0 then
            AddLine("Quests (" .. #filteredIndices .. ")", true, "quests")

            if UIThingsDB.tracker.collapsed["quests"] then
                ucState.yOffset = ucState.yOffset - ITEM_SPACING
                return
            end

            -- Helper to render a single quest entry (title + objectives)
            local function RenderSingleQuest(questID, extraIndent)
                if extraIndent then ucState.indent = extraIndent end
                local title = C_QuestLog.GetTitleForQuestID(questID)
                if title then
                    title = GetQuestTypePrefix(questID) ..
                        title .. GetQuestLineString(questID) .. GetDistanceString(questID)

                    local color = nil
                    if questID == superTrackedQuestID then
                        color = UIThingsDB.tracker.activeQuestColor
                    else
                        color = GetCampaignColor(questID)
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

                    -- Autocomplete quests: show "Click to complete quest" when ready
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

            -- Helper to render a collapsible sub-header with quest list
            local function RenderGroupHeader(groupKey, label, quests, colorR, colorG, colorB)
                local isCollapsed = UIThingsDB.tracker.collapsed[groupKey]

                local btn = AcquireItem()
                btn:Show()
                btn.questID = nil
                btn.achieID = nil
                btn:SetScript("OnClick", nil)
                btn:SetWidth(ucState.width)
                btn:SetPoint("TOPLEFT", 0, ucState.yOffset)
                btn.Text:SetFont(ucState.questNameFont, ucState.questNameSize, "OUTLINE")
                btn.Text:SetText(label .. " (" .. #quests .. ")")
                btn.Text:SetTextColor(colorR, colorG, colorB)
                btn.Icon:Hide()
                btn.Text:SetPoint("LEFT", 10, 0)
                btn:EnableMouse(false)
                btn:SetScript("OnEnter", nil)
                btn:SetScript("OnLeave", nil)
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

                ucState.yOffset = ucState.yOffset - (ucState.questNameSize + 4)

                if not isCollapsed then
                    for _, questID in ipairs(quests) do
                        RenderSingleQuest(questID, 10)
                    end
                end
                ucState.yOffset = ucState.yOffset - ITEM_SPACING
            end

            -- Helper to render a flat list of quest watch indices
            local function RenderFlatQuests(indices)
                for _, i in ipairs(indices) do
                    local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
                    if questID then
                        RenderSingleQuest(questID)
                    end
                end
            end

            -- Helper to group quest IDs by zone and render with sub-headers
            local function RenderByZone(questIDs)
                wipe(zoneOrder)
                wipe(questsByZone)
                for _, questID in ipairs(questIDs) do
                    if not displayedIDs[questID] then
                        local zoneName = "Other"
                        local headerIndex = C_QuestLog.GetHeaderIndexForQuest(questID)
                        if headerIndex then
                            local headerInfo = C_QuestLog.GetInfo(headerIndex)
                            if headerInfo and headerInfo.title then
                                zoneName = headerInfo.title
                            end
                        end
                        if not questsByZone[zoneName] then
                            questsByZone[zoneName] = {}
                            table.insert(zoneOrder, zoneName)
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

            -- Render super-tracked quest first when using any grouping mode
            local useCampaignGroup = UIThingsDB.tracker.groupQuestsByCampaign
            local useZoneGroup = UIThingsDB.tracker.groupQuestsByZone

            if useCampaignGroup or useZoneGroup then
                if superTrackedIndex then
                    local stQuestID = C_QuestLog.GetQuestIDForQuestWatchIndex(superTrackedIndex)
                    if stQuestID then
                        RenderSingleQuest(stQuestID)
                    end
                end
            end

            if useCampaignGroup then
                -- Separate campaign quests from non-campaign quests
                wipe(campaignOrder)
                wipe(questsByCampaign)
                wipe(nonCampaignQuests)

                for _, i in ipairs(filteredIndices) do
                    local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
                    if questID and not displayedIDs[questID] then
                        local campaignID = C_CampaignInfo.GetCampaignID(questID)
                        if campaignID and campaignID > 0 then
                            local campaignInfo = C_CampaignInfo.GetCampaignInfo(campaignID)
                            local campaignName = campaignInfo and campaignInfo.name or ("Campaign " .. campaignID)
                            if not questsByCampaign[campaignName] then
                                questsByCampaign[campaignName] = {}
                                table.insert(campaignOrder, campaignName)
                            end
                            table.insert(questsByCampaign[campaignName], questID)
                        else
                            table.insert(nonCampaignQuests, questID)
                        end
                    end
                end

                -- Sort within each campaign by distance if enabled
                if UIThingsDB.tracker.sortQuestsByDistance then
                    for _, name in ipairs(campaignOrder) do
                        table.sort(questsByCampaign[name], sortByDistanceSq)
                    end
                end

                -- Render campaign groups (gold color to match campaign quest highlighting)
                for _, campaignName in ipairs(campaignOrder) do
                    RenderGroupHeader("campaign_" .. campaignName, campaignName, questsByCampaign[campaignName], 0.9, 0.7,
                        0.2)
                end

                -- Render non-campaign quests (by zone or flat)
                if #nonCampaignQuests > 0 then
                    if useZoneGroup then
                        RenderByZone(nonCampaignQuests)
                    else
                        for _, questID in ipairs(nonCampaignQuests) do
                            RenderSingleQuest(questID)
                        end
                    end
                end
            elseif useZoneGroup then
                -- Zone grouping only (collect quest IDs from indices)
                local questIDs = {}
                for _, i in ipairs(filteredIndices) do
                    local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
                    if questID and not displayedIDs[questID] then
                        table.insert(questIDs, questID)
                    end
                end
                RenderByZone(questIDs)
            else
                -- Flat rendering (original behavior)
                RenderFlatQuests(filteredIndices)
            end
            ucState.yOffset = ucState.yOffset - SECTION_SPACING
        end
    end
end

--- Renders Scenarios and Bonus Objectives
local function RenderScenarios()
    if not C_ScenarioInfo then return end

    local scenarioInfo = C_ScenarioInfo.GetScenarioInfo()
    if not scenarioInfo or not scenarioInfo.name or scenarioInfo.name == "" then return end

    -- Header with step progress
    local headerText = "Scenario: " .. scenarioInfo.name
    if scenarioInfo.numStages and scenarioInfo.numStages > 1 then
        headerText = headerText ..
            string.format(" |cFFAAAAAA(%d/%d)|r", scenarioInfo.currentStage or 1, scenarioInfo.numStages)
    end

    AddLine(headerText, true, "scenario")

    if UIThingsDB.tracker.collapsed["scenario"] then
        ucState.yOffset = ucState.yOffset - ITEM_SPACING
        return
    end

    -- Get step info for the current stage
    local stepInfo = C_ScenarioInfo.GetScenarioStepInfo and C_ScenarioInfo.GetScenarioStepInfo() or nil

    -- Show step title if it differs from the scenario name
    if stepInfo and stepInfo.title and stepInfo.title ~= "" and stepInfo.title ~= scenarioInfo.name then
        AddLine("|cFFFFD100" .. stepInfo.title .. "|r", false, nil, nil, true)
    end

    -- Show step description if available
    if stepInfo and stepInfo.description and stepInfo.description ~= "" then
        AddLine("|cFFBBBBBB" .. stepInfo.description .. "|r", false, nil, nil, true)
    end

    -- Weighted progress (overall step progress percentage)
    if stepInfo and stepInfo.weightedProgress and stepInfo.weightedProgress > 0 then
        local pct = math.floor(stepInfo.weightedProgress)
        local color = pct >= 100 and "00FF00" or "FFFF00"
        AddLine(string.format("|cFF%s%d%% Complete|r", color, pct), false, nil, nil, true)
    end

    -- Render criteria for the current step
    local numCriteria = stepInfo and stepInfo.numCriteria or 0
    if numCriteria > 0 then
        for i = 1, numCriteria do
            local criteriaInfo = C_ScenarioInfo.GetCriteriaInfo(i)
            if not criteriaInfo then break end

            local text = criteriaInfo.description or ""
            if criteriaInfo.quantity and criteriaInfo.totalQuantity and criteriaInfo.totalQuantity > 1 then
                text = text .. " (" .. criteriaInfo.quantity .. "/" .. criteriaInfo.totalQuantity .. ")"
            end

            if criteriaInfo.failed then
                text = "|cFFFF0000" .. text .. " (Failed)|r"
            elseif criteriaInfo.completed then
                text = FormatCompletedObjective(text)
            end

            if criteriaInfo.isWeightedProgress then
                text = "|cFF00FFFF[Bonus]|r " .. text
            end

            AddLine(text, false, nil, nil, true)
        end
    elseif C_ScenarioInfo.GetCriteriaInfo then
        -- Fallback: iterate criteria without a count (legacy path)
        local criteriaIndex = 1
        while criteriaIndex <= 50 do
            local criteriaInfo = C_ScenarioInfo.GetCriteriaInfo(criteriaIndex)
            if not criteriaInfo then break end

            local text = criteriaInfo.description or ""
            if criteriaInfo.quantity and criteriaInfo.totalQuantity and criteriaInfo.totalQuantity > 1 then
                text = text .. " (" .. criteriaInfo.quantity .. "/" .. criteriaInfo.totalQuantity .. ")"
            end
            if criteriaInfo.failed then
                text = "|cFFFF0000" .. text .. " (Failed)|r"
            elseif criteriaInfo.completed then
                text = FormatCompletedObjective(text)
            end
            if criteriaInfo.isWeightedProgress then
                text = "|cFF00FFFF[Bonus]|r " .. text
            end

            AddLine(text, false, nil, nil, true)
            criteriaIndex = criteriaIndex + 1
        end
    end

    -- Show bonus steps if present
    if stepInfo and stepInfo.shouldShowBonusObjective then
        -- Check for bonus criteria beyond the main step
        local bonusIndex = numCriteria + 1
        while bonusIndex <= numCriteria + 20 do
            local bonusCriteria = C_ScenarioInfo.GetCriteriaInfo(bonusIndex)
            if not bonusCriteria then break end

            local text = bonusCriteria.description or ""
            if bonusCriteria.quantity and bonusCriteria.totalQuantity and bonusCriteria.totalQuantity > 1 then
                text = text .. " (" .. bonusCriteria.quantity .. "/" .. bonusCriteria.totalQuantity .. ")"
            end
            if bonusCriteria.completed then
                text = FormatCompletedObjective(text)
            end
            text = "|cFF00FFFF[Bonus]|r " .. text

            AddLine(text, false, nil, nil, true)
            bonusIndex = bonusIndex + 1
        end
    end

    ucState.yOffset = ucState.yOffset - SECTION_SPACING
end

local function RenderAchievements()
    local trackedAchievements = C_ContentTracking.GetTrackedIDs(Enum.ContentTrackingType.Achievement)

    wipe(validAchievements)
    for _, achID in ipairs(trackedAchievements) do
        local _, name = GetAchievementInfo(achID)
        if name then
            table.insert(validAchievements, achID)
        end
    end

    if #validAchievements > 0 then
        AddLine("Achievements", true, "achievements")

        if UIThingsDB.tracker.collapsed["achievements"] then
            ucState.yOffset = ucState.yOffset - ITEM_SPACING
            return
        end

        for _, achID in ipairs(validAchievements) do
            local _, name = GetAchievementInfo(achID)

            -- Check if all criteria are completed
            local allCompleted = true
            local numCriteria = GetAchievementNumCriteria(achID)
            if numCriteria > 0 then
                for j = 1, numCriteria do
                    local _, _, completed = GetAchievementCriteriaInfo(achID, j)
                    if not completed then
                        allCompleted = false
                        break
                    end
                end
            end

            -- Skip fully completed achievements if hideCompletedSubtasks is enabled
            if numCriteria > 0 and allCompleted and UIThingsDB.tracker.hideCompletedSubtasks then
                -- Skip this achievement entirely
            else
                AddLine(name, false, nil, achID)
                for j = 1, numCriteria do
                    local criteriaString, _, completed, quantity, reqQuantity = GetAchievementCriteriaInfo(achID, j)
                    if criteriaString then
                        -- Skip completed criteria if hideCompletedSubtasks is enabled
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

    -- Build a lookup of all activity data so we can check completion
    local activityData = {}
    if C_PerksActivities.GetPerksActivitiesInfo then
        local info = C_PerksActivities.GetPerksActivitiesInfo()
        if info and info.activities then
            for _, activity in ipairs(info.activities) do
                if activity and activity.ID then
                    activityData[activity.ID] = activity
                end
            end
        end
    end

    for _, activityID in ipairs(tracked) do
        local activity = activityData[activityID]
        if activity then
            local hasRequirements = false
            local allDone = true
            if activity.requirementsList then
                for _, req in ipairs(activity.requirementsList) do
                    if req and req.requirementText and req.requirementText ~= "" then
                        hasRequirements = true
                        if not req.completed then
                            allDone = false
                            break
                        end
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

    -- Always fetch full activity info for data lookup
    local allActivities = nil
    if C_PerksActivities.GetPerksActivitiesInfo then
        allActivities = C_PerksActivities.GetPerksActivitiesInfo()
    end

    -- Build a lookup table of activities by ID
    local activityLookup = {}
    if allActivities and allActivities.activities then
        for _, activity in ipairs(allActivities.activities) do
            if activity and activity.ID then
                activityLookup[activity.ID] = activity
            end
        end
    end

    -- Get tracked activity IDs
    local trackedActivities = {}
    if C_PerksActivities.GetTrackedPerksActivities then
        local tracked = C_PerksActivities.GetTrackedPerksActivities()
        if tracked and #tracked > 0 then
            trackedActivities = tracked
        end
    end

    -- Fallback: find tracked ones from the full list
    if #trackedActivities == 0 and allActivities and allActivities.activities then
        for _, activity in ipairs(allActivities.activities) do
            if activity and activity.tracked and activity.ID then
                table.insert(trackedActivities, activity.ID)
            end
        end
    end

    if #trackedActivities == 0 then
        return
    end

    -- Count only activities that will actually render (not completed+hidden)
    local renderCount = 0
    for _, activityID in ipairs(trackedActivities) do
        local activity = activityLookup[activityID]
        if activity then
            local hasRequirements = false
            local allCompleted = true
            if activity.requirementsList then
                for _, req in ipairs(activity.requirementsList) do
                    if req and req.requirementText and req.requirementText ~= "" then
                        hasRequirements = true
                        if not req.completed then
                            allCompleted = false
                            break
                        end
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
            -- Check if all requirements are completed
            local allCompleted = true
            local hasRequirements = false
            if activity.requirementsList then
                for _, req in ipairs(activity.requirementsList) do
                    if req and req.requirementText and req.requirementText ~= "" then
                        hasRequirements = true
                        if not req.completed then
                            allCompleted = false
                            break
                        end
                    end
                end
            end

            -- Skip fully completed activities if hideCompletedSubtasks is enabled
            if hasRequirements and allCompleted and UIThingsDB.tracker.hideCompletedSubtasks then
                -- Skip this activity entirely
            else
                local title = activity.activityName or "Unknown Activity"

                AddLine(title, false, nil, nil, false, nil, activityID)

                -- Add progress info from requirementsList if available
                if activity.requirementsList and #activity.requirementsList > 0 then
                    for _, req in ipairs(activity.requirementsList) do
                        if req and req.requirementText and req.requirementText ~= "" then
                            -- Skip completed objectives if hideCompletedSubtasks is enabled
                            if not (req.completed and UIThingsDB.tracker.hideCompletedSubtasks) then
                                local objText = req.requirementText
                                if req.completed then
                                    objText = FormatCompletedObjective(objText)
                                end
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

--- Renders Campaign Quests as a dedicated top-level section.
-- When groupQuestsByCampaign is on, quests are sub-grouped by campaign name.
-- When off, a flat list is shown.
local function RenderCampaignQuests()
    local numQuests = C_QuestLog.GetNumQuestWatches()
    if numQuests == 0 then return end

    local superTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID()

    -- Collect all tracked campaign quest IDs (not yet rendered elsewhere)
    wipe(campaignOrder)
    wipe(questsByCampaign)
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
                    questsByCampaign[campaignName] = {}
                    table.insert(campaignOrder, campaignName)
                end
                table.insert(questsByCampaign[campaignName], questID)
            end
        end
    end

    if #flatCampaignQuests == 0 then return end

    -- Sort by distance if enabled
    if UIThingsDB.tracker.sortQuestsByDistance then
        table.sort(flatCampaignQuests, sortByDistanceSq)
        for _, name in ipairs(campaignOrder) do
            table.sort(questsByCampaign[name], sortByDistanceSq)
        end
    end

    -- Section header
    AddLine("Campaign Quests (" .. #flatCampaignQuests .. ")", true, "campaignQuests")

    if UIThingsDB.tracker.collapsed["campaignQuests"] then
        ucState.yOffset = ucState.yOffset - ITEM_SPACING
        return
    end

    -- Helper: render one campaign quest with title + objectives
    local function RenderOneCampaignQuest(questID, extraIndent)
        if displayedIDs[questID] then return end
        if extraIndent then ucState.indent = extraIndent end
        local title = C_QuestLog.GetTitleForQuestID(questID)
        if title then
            title = GetQuestTypePrefix(questID) .. title .. GetQuestLineString(questID) .. GetDistanceString(questID)
            local color
            if questID == superTrackedQuestID then
                color = UIThingsDB.tracker.activeQuestColor
            else
                color = UIThingsDB.tracker.campaignQuestColor
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

            -- Autocomplete quests: show "Click to complete quest" when ready
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

    -- Render super-tracked campaign quest first
    if superTrackedQuestID and not displayedIDs[superTrackedQuestID] then
        if C_CampaignInfo and C_CampaignInfo.IsCampaignQuest and C_CampaignInfo.IsCampaignQuest(superTrackedQuestID) then
            RenderOneCampaignQuest(superTrackedQuestID)
        end
    end

    if UIThingsDB.tracker.groupQuestsByCampaign then
        -- Sub-group by campaign name
        for _, campaignName in ipairs(campaignOrder) do
            local quests = questsByCampaign[campaignName]
            -- Filter out already-displayed (super-tracked) quest
            local remaining = {}
            for _, qID in ipairs(quests) do
                if not displayedIDs[qID] then
                    table.insert(remaining, qID)
                end
            end
            if #remaining > 0 then
                -- Sub-header
                local isCollapsed = UIThingsDB.tracker.collapsed["campaignGroup_" .. campaignName]
                local btn = AcquireItem()
                btn:Show()
                btn.questID = nil
                btn.achieID = nil
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
                btn:SetScript("OnEnter", nil)
                btn:SetScript("OnLeave", nil)
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
                    for _, qID in ipairs(remaining) do
                        RenderOneCampaignQuest(qID, 10)
                    end
                end
                ucState.yOffset = ucState.yOffset - ITEM_SPACING
            end
        end
    else
        -- Flat list
        for _, questID in ipairs(flatCampaignQuests) do
            RenderOneCampaignQuest(questID)
        end
    end

    ucState.yOffset = ucState.yOffset - SECTION_SPACING
end

-- Section renderer lookup (hoisted, reuses the static functions above)
local sectionRenderers = {
    scenarios = RenderScenarios,
    tempObjectives = function() end, -- handled within RenderQuests
    travelersLog = RenderTravelersLog,
    worldQuests = RenderWorldQuests,
    campaignQuests = RenderCampaignQuests,
    quests = RenderQuests,
    achievements = RenderAchievements,
}

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

UpdateContent = function()
    if not trackerFrame then return end
    if trackerHiddenByKeybind then return end

    local inCombat = InCombatLockdown()

    -- Check if disabled or should forcefully hide (M+)
    local enabled = UIThingsDB.tracker.enabled
    local shouldHideMPlus = enabled and (UIThingsDB.tracker.hideInMPlus and C_ChallengeMode.IsChallengeModeActive())

    if not enabled or shouldHideMPlus then
        if not inCombat then
            UnregisterStateDriver(trackerFrame, "visibility")
            trackerFrame:Hide()
        end
        return
    end

    -- Handle Combat Visibility securely via State Driver (only out of combat)
    if not inCombat then
        if UIThingsDB.tracker.hideInCombat then
            RegisterStateDriver(trackerFrame, "visibility", "[combat] hide; show")
        else
            UnregisterStateDriver(trackerFrame, "visibility")
            trackerFrame:Show()
        end
    end

    ReleaseItems()

    -- Cache map data once for RenderWorldQuests (avoids redundant API calls)
    local cachedMapID = C_Map.GetBestMapForUnit("player")
    local cachedTasks = cachedMapID and C_TaskQuest.GetQuestsOnMap(cachedMapID) or nil

    -- Populate shared state for hoisted helper functions
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

    -- Silently untrack any completed Traveler's Log activities
    AutoUntrackCompletedPerksActivities()

    -- Wipe reusable scratch tables
    wipe(displayedIDs)

    -- Use new list-based order if available, otherwise fall back to old dropdown
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
        -- Migration: Add travelersLog if it doesn't exist in user's list
        local hasTravelersLog = false
        for _, key in ipairs(orderList) do
            if key == "travelersLog" then hasTravelersLog = true break end
        end
        if not hasTravelersLog then
            local insertPos = 3
            for i, key in ipairs(orderList) do
                if key == "tempObjectives" then insertPos = i + 1 break end
            end
            table.insert(orderList, insertPos, "travelersLog")
        end

        -- Migration: Add campaignQuests if it doesn't exist in user's list
        local hasCampaignQuests = false
        for _, key in ipairs(orderList) do
            if key == "campaignQuests" then hasCampaignQuests = true break end
        end
        if not hasCampaignQuests then
            -- Insert before "quests" if found, otherwise at end
            local insertPos = #orderList + 1
            for i, key in ipairs(orderList) do
                if key == "quests" then insertPos = i break end
            end
            table.insert(orderList, insertPos, "campaignQuests")
        end
    end

    -- Deduplicate orderList (guard against any migration inserting a key twice)
    local seen = {}
    local deduped = {}
    for _, key in ipairs(orderList) do
        if not seen[key] then
            seen[key] = true
            table.insert(deduped, key)
        end
    end
    -- Replace in-place so the saved var stays clean
    for i = #orderList, 1, -1 do orderList[i] = nil end
    for i, key in ipairs(deduped) do orderList[i] = key end

    -- Determine if campaignQuests section is active in the order list so RenderQuests
    -- can exclude campaign quests from the regular Quests section.
    campaignQuestsSectionActive = false
    for _, key in ipairs(orderList) do
        if key == "campaignQuests" then campaignQuestsSectionActive = true break end
    end

    for _, sectionKey in ipairs(orderList) do
        local renderer = sectionRenderers[sectionKey]
        if renderer then
            renderer()
        end
    end

    -- Auto-hide when empty and locked (deferred check avoids redundant pre-counting)
    if ucState.yOffset == -5 and UIThingsDB.tracker.locked then
        if not inCombat then
            UnregisterStateDriver(trackerFrame, "visibility")
            trackerFrame:Hide()
        end
        return
    end

    -- Resize Scroll Child
    local totalHeight = math.abs(ucState.yOffset)
    scrollChild:SetHeight(math.max(totalHeight, 50))

    -- Update keybind quest item button
    UpdateQuestItemButton()
end

-- Super-track restore logic
local function HandleSuperTrackChanged()
    if not UIThingsDB.tracker.restoreSuperTrack then
        savedSuperTrackedQuestID = nil
        lastKnownSuperTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID()
        return
    end

    local currentST = C_SuperTrack.GetSuperTrackedQuestID()
    local isCurrentWQ = currentST and currentST ~= 0 and
        (C_QuestLog.IsWorldQuest(currentST) or (C_QuestLog.IsQuestTask(currentST) and not C_QuestLog.GetQuestWatchType(currentST)))

    -- If we just switched TO a world/task quest, save the previous non-WQ super-tracked quest
    if isCurrentWQ and lastKnownSuperTrackedQuestID and lastKnownSuperTrackedQuestID ~= 0 then
        local wasWQ = C_QuestLog.IsWorldQuest(lastKnownSuperTrackedQuestID) or
            (C_QuestLog.IsQuestTask(lastKnownSuperTrackedQuestID) and not C_QuestLog.GetQuestWatchType(lastKnownSuperTrackedQuestID))
        if not wasWQ then
            savedSuperTrackedQuestID = lastKnownSuperTrackedQuestID
        end
    end

    -- If super-track was cleared or moved to nothing, try to restore
    if (not currentST or currentST == 0) and savedSuperTrackedQuestID then
        -- Verify the saved quest is still valid and tracked
        if C_QuestLog.IsOnQuest(savedSuperTrackedQuestID) and C_QuestLog.GetQuestWatchType(savedSuperTrackedQuestID) then
            C_SuperTrack.SetSuperTrackedQuestID(savedSuperTrackedQuestID)
            savedSuperTrackedQuestID = nil
        else
            savedSuperTrackedQuestID = nil
        end
    end

    lastKnownSuperTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID()
end

-- Check if we should restore super-track after leaving a WQ area
local function CheckRestoreSuperTrack()
    if not UIThingsDB.tracker.restoreSuperTrack or not savedSuperTrackedQuestID then return end

    local currentST = C_SuperTrack.GetSuperTrackedQuestID()
    if not currentST or currentST == 0 then
        -- Super-track is empty, restore saved quest
        if C_QuestLog.IsOnQuest(savedSuperTrackedQuestID) and C_QuestLog.GetQuestWatchType(savedSuperTrackedQuestID) then
            C_SuperTrack.SetSuperTrackedQuestID(savedSuperTrackedQuestID)
        end
        savedSuperTrackedQuestID = nil
        return
    end

    -- If current super-track is a WQ that we're no longer on (left the area), restore
    local isCurrentWQ = C_QuestLog.IsWorldQuest(currentST) or
        (C_QuestLog.IsQuestTask(currentST) and not C_QuestLog.GetQuestWatchType(currentST))
    if isCurrentWQ and not C_QuestLog.IsOnQuest(currentST) then
        if C_QuestLog.IsOnQuest(savedSuperTrackedQuestID) and C_QuestLog.GetQuestWatchType(savedSuperTrackedQuestID) then
            C_SuperTrack.SetSuperTrackedQuestID(savedSuperTrackedQuestID)
        end
        savedSuperTrackedQuestID = nil
    end
end

-- Aggressive Hide Hook for Blizzard tracker
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

-- Try hooking immediately if already available
HookBlizzardTracker()

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

local function SetupCustomTracker()
    if trackerFrame then return end
    local settings = UIThingsDB.tracker

    -- Main Container
    trackerFrame = CreateFrame("Frame", "UIThingsCustomTracker", UIParent, "BackdropTemplate")
    trackerFrame:SetPoint(settings.point or "TOPRIGHT", UIParent, settings.point or "TOPRIGHT", settings.x or -20,
        settings.y or -250)
    trackerFrame:SetSize(settings.width, settings.height)

    trackerFrame:SetMovable(true)
    trackerFrame:SetResizable(true)
    trackerFrame:SetClampedToScreen(true)
    trackerFrame:SetResizeBounds(150, 150, 600, 1000)

    -- Background for Unlocked state
    trackerFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    trackerFrame:SetBackdropColor(0, 0, 0, 0.5)

    -- Header ("OBJECTIVES") - Fixed at top, can be hidden
    headerFrame = CreateFrame("Frame", nil, trackerFrame)
    headerFrame:SetPoint("TOPLEFT")
    headerFrame:SetPoint("TOPRIGHT")
    headerFrame:SetHeight(30)

    local headerText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerText:SetPoint("CENTER")
    headerText:SetText("OBJECTIVES")

    if UIThingsDB.tracker.hideHeader then
        headerFrame:SetHeight(1)
        headerFrame:Hide()
    end

    -- Drag Logic
    trackerFrame:EnableMouse(true)
    trackerFrame:RegisterForDrag("LeftButton")
    trackerFrame:SetScript("OnDragStart", function(self)
        if not UIThingsDB.tracker.locked then self:StartMoving() end
    end)
    trackerFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        -- Force integer coordinates to prevent blurry/missing 1px borders
        x = math.floor(x + 0.5)
        y = math.floor(y + 0.5)
        self:ClearAllPoints()
        self:SetPoint(point, UIParent, relativePoint, x, y)

        UIThingsDB.tracker.point = point
        UIThingsDB.tracker.x = x
        UIThingsDB.tracker.y = y
    end)

    -- Scroll Frame
    scrollFrame = CreateFrame("ScrollFrame", "UIThingsTrackerScroll", trackerFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 10, -5) -- Below header
    scrollFrame:SetPoint("BOTTOMRIGHT", -25, 10)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(settings.width - 40, 500)
    scrollFrame:SetScrollChild(scrollChild)

    -- Resize Handle
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
        UpdateContent() -- Re-layout items
    end)

    -- Event Registry
    RegisterTrackerEvents(trackerFrame)

    trackerFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            SafeAfter(2, UpdateContent)
        elseif event == "PLAYER_REGEN_DISABLED" then
            -- Handled by StateDriver
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pendingQuestItemUpdate then
                pendingQuestItemUpdate = nil
                UpdateQuestItemButton()
            end
            UpdateContent()
        elseif event == "SUPER_TRACKING_CHANGED" then
            HandleSuperTrackChanged()
            UpdateQuestItemButton()
            ScheduleUpdateContent()
        elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
            CheckRestoreSuperTrack()
            -- Prune stale sound-tracking and quest line cache entries on zone change
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
            local now = GetTime()
            for qid, cached in pairs(questLineCache) do
                if cached.expiry < now then
                    questLineCache[qid] = nil
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
            end
            ScheduleUpdateContent()
        else
            -- Check for completion sounds before updating display
            if event == "QUEST_LOG_UPDATE" or event == "TASK_PROGRESS_UPDATE" then
                CheckCompletionSounds()
            end
            ScheduleUpdateContent()
        end
    end)
end

function addonTable.ObjectiveTracker.UpdateSettings()
    local enabled = UIThingsDB.tracker.enabled

    -- Auto-track event management
    if autoTrackFrame then
        if enabled and UIThingsDB.tracker.autoTrackQuests then
            autoTrackFrame:RegisterEvent("QUEST_ACCEPTED")
        else
            autoTrackFrame:UnregisterAllEvents()
        end
    end

    -- Blizzard Tracker Logic
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
            trackerFrame:UnregisterAllEvents()
            trackerFrame:Hide()
        end
        return
    end

    -- Custom Tracker Logic
    SetupCustomTracker()

    -- Re-register events (SetupCustomTracker only registers once on creation,
    -- so we must re-register after a disable/enable cycle)
    if trackerFrame then
        RegisterTrackerEvents(trackerFrame)
    end

    -- Check visibility
    local shouldHide = (UIThingsDB.tracker.hideInCombat and InCombatLockdown()) or
        (UIThingsDB.tracker.hideInMPlus and C_ChallengeMode.IsChallengeModeActive())

    if shouldHide then
        trackerFrame:Hide()
    else
        trackerFrame:Show()
    end

    -- Geometry
    trackerFrame:SetSize(UIThingsDB.tracker.width, UIThingsDB.tracker.height)
    trackerFrame:SetFrameStrata(UIThingsDB.tracker.strata or "LOW")
    scrollChild:SetWidth(UIThingsDB.tracker.width - 40)

    -- Header visibility
    if headerFrame then
        if UIThingsDB.tracker.hideHeader then
            headerFrame:SetHeight(1)
            headerFrame:Hide()
        else
            headerFrame:SetHeight(30)
            headerFrame:Show()
        end
    end

    -- Lock/Unlock & Border State
    if UIThingsDB.tracker.locked then
        trackerFrame:EnableMouse(false)

        local showBorder = UIThingsDB.tracker.showBorder
        local showBackground = UIThingsDB.tracker.showBackground

        if showBorder or showBackground then
            trackerFrame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false,
                tileSize = 0,
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })

            -- Background
            if showBackground then
                local c = UIThingsDB.tracker.backgroundColor or { r = 0, g = 0, b = 0, a = 0.5 }
                trackerFrame:SetBackdropColor(c.r, c.g, c.b, c.a)
            else
                trackerFrame:SetBackdropColor(0, 0, 0, 0)
            end

            -- Border
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
        -- Unlocked: Always show "edit mode" visualization
        trackerFrame:EnableMouse(true)
        trackerFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
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

    UpdateContent()
end

addonTable.ObjectiveTracker.UpdateContent = UpdateContent

-- Keybind toggle: temporarily show/hide the tracker without changing the enabled setting
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

-- Hook into startup
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        lastKnownSuperTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID()
        -- Seed prevQuestComplete so quests already complete at login don't trigger sounds/supertrack
        local numWatches = C_QuestLog.GetNumQuestWatches()
        for i = 1, numWatches do
            local qID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
            if qID then
                prevQuestComplete[qID] = C_QuestLog.IsComplete(qID)
            end
        end
        addonTable.ObjectiveTracker.UpdateSettings()
    else
        -- Force update shortly after entering world to override Blizzard's show logic
        SafeAfter(1, function() addonTable.ObjectiveTracker.UpdateSettings() end)
    end
end)


-- Deferred hook setup — the hookFrame below handles login/world entry
local hookFrame = CreateFrame("Frame")
hookFrame:RegisterEvent("PLAYER_LOGIN")
hookFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
hookFrame:SetScript("OnEvent", function(self, event)
    HookBlizzardTracker()
    if blizzardTrackerHooked then
        -- Also force-hide the Blizzard tracker on world entry if our tracker is enabled
        if UIThingsDB and UIThingsDB.tracker and UIThingsDB.tracker.enabled and ObjectiveTrackerFrame then
            ObjectiveTrackerFrame:SetAlpha(0)
            ObjectiveTrackerFrame:SetScale(0.00001)
            ObjectiveTrackerFrame:EnableMouse(false)
        end
        self:UnregisterAllEvents()
    end
end)

-- Auto Track Quests Feature
autoTrackFrame = CreateFrame("Frame")
autoTrackFrame:SetScript("OnEvent", function(self, event, questID)
    if event == "QUEST_ACCEPTED" and questID then
        if UIThingsDB.tracker and UIThingsDB.tracker.enabled and UIThingsDB.tracker.autoTrackQuests then
            -- Check if quest is not already tracked
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
