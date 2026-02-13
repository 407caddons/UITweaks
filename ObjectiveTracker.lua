local addonName, addonTable = ...
addonTable.ObjectiveTracker = {}

local trackerFrame
local scrollFrame
local scrollChild
local contentFrame
local headerFrame
local itemPool = {}
local autoTrackFrame

-- Constants
local MINUTES_PER_DAY = 1440
local MINUTES_PER_HOUR = 60
local UPDATE_THROTTLE_DELAY = 0.1
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
    -- Disable left-click in combat
    if InCombatLockdown() and button == "LeftButton" then return end

    -- Shift-Click to Untrack (if enabled)
    if IsShiftKeyDown() and self.questID and type(self.questID) == "number" and UIThingsDB.tracker.shiftClickUntrack then
        C_QuestLog.RemoveQuestWatch(self.questID)
        SafeAfter(0.1, addonTable.ObjectiveTracker.UpdateContent) -- Refresh list
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

    if self.questID and type(self.questID) == "number" then
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
        if not btn:IsShown() then
            return btn
        end
    end

    local btn = CreateFrame("Button", nil, scrollChild)
    btn:SetHeight(20)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

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
    local itemBtn = CreateFrame("Button", nil, btn, "SecureActionButtonTemplate")
    itemBtn:SetSize(20, 20)
    itemBtn:SetPoint("RIGHT", -2, 0)
    itemBtn:Hide()
    itemBtn:RegisterForClicks("AnyUp", "AnyDown")
    itemBtn:SetFrameLevel(btn:GetFrameLevel() + 2)
    itemBtn.iconTex = itemBtn:CreateTexture(nil, "ARTWORK")
    itemBtn.iconTex:SetAllPoints()
    itemBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    btn.ItemBtn = itemBtn

    table.insert(itemPool, btn)
    return btn
end

local function ReleaseItems()
    for _, btn in ipairs(itemPool) do
        btn:Hide()
        btn:SetScript("OnClick", nil)
        btn:SetScript("OnEnter", nil)
        btn:SetScript("OnLeave", nil)
        btn.Icon:Hide()
        btn.Text:ClearAllPoints() -- Reset points to ensure clean state
        if btn.ToggleBtn then btn.ToggleBtn:Hide() end
        if btn.ItemBtn then
            btn.ItemBtn:Hide()
            -- Only modify secure attributes out of combat to prevent taint
            if not InCombatLockdown() then
                btn.ItemBtn:SetAttribute("type", nil)
                btn.ItemBtn:SetAttribute("item", nil)
            end
        end
    end
end

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

local UpdateContent -- forward declaration for ScheduleUpdateContent

-- Helper to add lines (hoisted from UpdateContent)
local function AddLine(text, isHeader, questID, achieID, isObjective, overrideColor)
    local btn = AcquireItem()
    btn:Show()

    btn.questID = questID
    btn.achieID = achieID

    btn:SetScript("OnClick", questID and OnQuestClick or achieID and OnAchieveClick or nil)

    btn:SetWidth(ucState.width)
    btn:SetPoint("TOPLEFT", 0, ucState.yOffset)

    if isHeader then
        btn.Text:SetFont(ucState.baseFont, ucState.baseSize + 2, "OUTLINE")
        btn.Text:SetText(text)
        btn.Text:SetTextColor(1, 0.82, 0)
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

        ucState.yOffset = ucState.yOffset - (ucState.baseSize + 8)
    else
        if isObjective then
            local currentSize = ucState.detailSize

            btn.Text:SetFont(ucState.detailFont, currentSize, "OUTLINE")
            btn.Text:SetText(text)
            btn.Text:SetTextColor(0.8, 0.8, 0.8)
            btn.Icon:Hide()
            btn.Text:SetPoint("LEFT", 19, 0)
            btn:EnableMouse(false)
            ucState.yOffset = ucState.yOffset - (currentSize + ucState.questPadding)
        else
            local currentSize = ucState.questNameSize

            btn.Text:SetFont(ucState.questNameFont, currentSize, "OUTLINE")
            btn.Text:SetText(text)

            if overrideColor then
                btn.Text:SetTextColor(overrideColor.r, overrideColor.g, overrideColor.b, overrideColor.a or 1)
            else
                btn.Text:SetTextColor(1, 1, 1)
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
                        -- Only modify secure attributes out of combat to prevent taint
                        if not InCombatLockdown() then
                            btn.ItemBtn:SetAttribute("type", "item")
                            btn.ItemBtn:SetAttribute("item", questItemLink)
                        end
                        btn.ItemBtn:Show()
                    else
                        btn.ItemBtn:Hide()
                    end
                else
                    btn.ItemBtn:Hide()
                end
            else
                btn.Icon:Hide()
                btn.Text:SetPoint("LEFT", 19, 0)
                if achieID then btn:EnableMouse(true) else btn:EnableMouse(false) end
                if btn.ItemBtn then btn.ItemBtn:Hide() end
            end

            -- Tooltip preview on hover
            if UIThingsDB.tracker.showTooltipPreview and (questID or achieID) then
                btn:SetScript("OnEnter", function(self)
                    if self.questID then
                        GameTooltip:SetOwner(self, "ANCHOR_NONE")
                        GameTooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 5, 0)
                        GameTooltip:SetHyperlink("quest:" .. self.questID)
                        GameTooltip:Show()
                    elseif self.achieID then
                        GameTooltip:SetOwner(self, "ANCHOR_NONE")
                        GameTooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 5, 0)
                        GameTooltip:SetHyperlink("achievement:" .. self.achieID)
                        GameTooltip:Show()
                    end
                end)
                btn:SetScript("OnLeave", GameTooltip_Hide)
            else
                btn:SetScript("OnEnter", nil)
                btn:SetScript("OnLeave", nil)
            end

            ucState.yOffset = ucState.yOffset - (currentSize + 4)
        end
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

--- Renders a single World Quest entry
local function RenderSingleWQ(questID, superTrackedQuestID)
    if not displayedIDs[questID] then
        local title = C_QuestLog.GetTitleForQuestID(questID)
        if title then
            if UIThingsDB.tracker.showWorldQuestTimer then
                title = title .. GetTimeLeftString(questID)
            end

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
                            if obj.finished then objText = "|cFF00FF00" .. objText .. "|r" end
                            AddLine(objText, false, nil, nil, true)
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

    local hasWQs = (#activeWQs > 0) or (#otherWQs > 0)

    if hasWQs then
        AddLine("World Quests", true, "worldQuests")

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
                                    if obj.finished then objText = "|cFF00FF00" .. objText .. "|r" end
                                    AddLine(objText, false, nil, nil, true)
                                end
                            end
                        end
                    end
                    ucState.yOffset = ucState.yOffset - 5
                end
            end
            ucState.yOffset = ucState.yOffset - 10
        else
            ucState.yOffset = ucState.yOffset - 5
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
                local isTaskQuest = C_QuestLog.IsQuestTask(qID)
                local isWorldQuest = C_QuestLog.IsWorldQuest(qID)

                if not displayedIDs[qID] then
                    if qID == superTrackedQuestID then
                        superTrackedIndex = i
                    else
                        table.insert(filteredIndices, i)
                    end
                end
            end
        end

        if superTrackedIndex then
            table.insert(filteredIndices, 1, superTrackedIndex)
        end

        if #filteredIndices > 0 then
            AddLine("Quests", true, "quests")

            if UIThingsDB.tracker.collapsed["quests"] then
                ucState.yOffset = ucState.yOffset - 5
                return
            end
            for _, i in ipairs(filteredIndices) do
                local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
                local title = C_QuestLog.GetTitleForQuestID(questID)
                if title then
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
                                    if obj.finished then objText = "|cFF00FF00" .. objText .. "|r" end
                                    AddLine(objText, false, nil, nil, true)
                                end
                            end
                        end
                    end
                    ucState.yOffset = ucState.yOffset - 5
                end
            end
            ucState.yOffset = ucState.yOffset - 10
        end
    end
end

--- Renders Scenarios and Bonus Objectives
local function RenderScenarios()
    if not C_ScenarioInfo then return end

    local scenarioInfo = C_ScenarioInfo.GetScenarioInfo()

    if not scenarioInfo or not scenarioInfo.name or scenarioInfo.name == "" then return end

    AddLine("Scenario: " .. scenarioInfo.name, true, "scenario")

    if UIThingsDB.tracker.collapsed["scenario"] then
        ucState.yOffset = ucState.yOffset - ITEM_SPACING
        return
    end

    if C_ScenarioInfo.GetCriteriaInfo then
        local criteriaIndex = 1
        while true do
            local criteriaInfo = C_ScenarioInfo.GetCriteriaInfo(criteriaIndex)
            if not criteriaInfo then break end

            local text = criteriaInfo.description or ""
            if criteriaInfo.quantity and criteriaInfo.totalQuantity and criteriaInfo.totalQuantity > 1 then
                text = text .. " (" .. criteriaInfo.quantity .. "/" .. criteriaInfo.totalQuantity .. ")"
            end
            if criteriaInfo.completed then
                text = "|cFF00FF00" .. text .. "|r"
            end

            local isBonus = criteriaInfo.isWeightedProgress or false
            if isBonus then
                text = "|cFF00FFFF[Bonus] " .. text .. "|r"
            end

            AddLine(text, false, nil, nil, true)
            criteriaIndex = criteriaIndex + 1

            if criteriaIndex > 50 then break end
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
            ucState.yOffset = ucState.yOffset - 5
            return
        end

        for _, achID in ipairs(validAchievements) do
            local _, name = GetAchievementInfo(achID)
            AddLine(name, false, nil, achID)
            local numCriteria = GetAchievementNumCriteria(achID)
            for j = 1, numCriteria do
                local criteriaString, _, completed, quantity, reqQuantity = GetAchievementCriteriaInfo(achID, j)
                if criteriaString then
                    local text = criteriaString
                    if (type(quantity) == "number" and type(reqQuantity) == "number") and reqQuantity > 1 then
                        text = text .. " (" .. quantity .. "/" .. reqQuantity .. ")"
                    end
                    if completed then text = "|cFF00FF00" .. text .. "|r" end
                    AddLine(text, false, nil, nil, true)
                end
            end
            ucState.yOffset = ucState.yOffset - 5
        end
        ucState.yOffset = ucState.yOffset - 10
    end
end

-- Section renderer lookup (hoisted, reuses the static functions above)
local sectionRenderers = {
    scenarios = RenderScenarios,
    tempObjectives = function() end, -- handled within RenderQuests
    worldQuests = RenderWorldQuests,
    quests = RenderQuests,
    achievements = RenderAchievements,
}

-- Throttle wrapper to coalesce rapid-fire events into a single update
local updatePending = false
local function ScheduleUpdateContent()
    if updatePending then return end
    updatePending = true
    C_Timer.After(UPDATE_THROTTLE_DELAY, function()
        updatePending = false
        if trackerFrame then
            UpdateContent()
        end
    end)
end

UpdateContent = function()
    if not trackerFrame then return end

    -- Guard against combat execution (prevents taint on secure items)
    if InCombatLockdown() then return end

    -- Check if disabled or should forcefully hide (M+)
    local enabled = UIThingsDB.tracker.enabled
    local shouldHideMPlus = enabled and (UIThingsDB.tracker.hideInMPlus and C_ChallengeMode.IsChallengeModeActive())

    if not enabled or shouldHideMPlus then
        UnregisterStateDriver(trackerFrame, "visibility")
        trackerFrame:Hide()
        return
    end

    -- Handle Combat Visibility securely via State Driver
    if UIThingsDB.tracker.hideInCombat then
        RegisterStateDriver(trackerFrame, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(trackerFrame, "visibility")
        trackerFrame:Show()
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
    ucState.yOffset = -5
    ucState.width = scrollChild:GetWidth()
    ucState.cachedMapID = cachedMapID
    ucState.cachedTasks = cachedTasks

    UIThingsDB.tracker.collapsed = UIThingsDB.tracker.collapsed or {}

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
        UIThingsDB.tracker.sectionOrderList = orderList
    end

    for _, sectionKey in ipairs(orderList) do
        local renderer = sectionRenderers[sectionKey]
        if renderer then
            renderer()
        end
    end

    -- Auto-hide when empty and locked (deferred check avoids redundant pre-counting)
    if ucState.yOffset == -5 and UIThingsDB.tracker.locked then
        UnregisterStateDriver(trackerFrame, "visibility")
        trackerFrame:Hide()
        return
    end

    -- Resize Scroll Child
    local totalHeight = math.abs(ucState.yOffset)
    scrollChild:SetHeight(math.max(totalHeight, 50))
end

-- Aggressive Hide Hook for Blizzard tracker
local blizzardTrackerHooked = false
local function HookBlizzardTracker()
    if blizzardTrackerHooked or not ObjectiveTrackerFrame then return end
    blizzardTrackerHooked = true
    hooksecurefunc(ObjectiveTrackerFrame, "Show", function()
        if UIThingsDB and UIThingsDB.tracker and UIThingsDB.tracker.enabled then
            ObjectiveTrackerFrame:Hide()
        end
    end)
end

-- Try hooking immediately if already available
HookBlizzardTracker()

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

    -- Header ("OBJECTIVES") - Fixed at top
    headerFrame = CreateFrame("Frame", nil, trackerFrame)
    headerFrame:SetPoint("TOPLEFT")
    headerFrame:SetPoint("TOPRIGHT")
    headerFrame:SetHeight(30)

    local headerText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerText:SetPoint("CENTER")
    headerText:SetText("OBJECTIVES")

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
    trackerFrame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
    trackerFrame:RegisterEvent("TRACKED_ACHIEVEMENT_LIST_CHANGED") -- Legacy?
    trackerFrame:RegisterEvent("CONTENT_TRACKING_UPDATE")          -- Modern
    trackerFrame:RegisterEvent("CONTENT_TRACKING_LIST_UPDATE")     -- Modern
    trackerFrame:RegisterEvent("QUEST_LOG_UPDATE")
    trackerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    trackerFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    trackerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    trackerFrame:RegisterEvent("CHALLENGE_MODE_START")
    trackerFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    trackerFrame:RegisterEvent("CHALLENGE_MODE_RESET")
    trackerFrame:RegisterEvent("SUPER_TRACKING_CHANGED")
    trackerFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    trackerFrame:RegisterEvent("ZONE_CHANGED")
    trackerFrame:RegisterEvent("TASK_PROGRESS_UPDATE") -- For bonus objectives/task quests
    trackerFrame:RegisterEvent("QUEST_ACCEPTED")       -- When task quests are picked up
    trackerFrame:RegisterEvent("QUEST_REMOVED")        -- When task quests are removed

    trackerFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(2, UpdateContent)
        elseif event == "PLAYER_REGEN_DISABLED" then
            -- Handled by StateDriver
        else
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
            ObjectiveTrackerFrame:Hide()
            ObjectiveTrackerFrame:SetParent(UIThingsHiddenFrame or CreateFrame("Frame", "UIThingsHiddenFrame"))
            if ObjectiveTrackerFrame.UnregisterAllEvents then
                ObjectiveTrackerFrame:UnregisterAllEvents()
            end
        end
    else
        if ObjectiveTrackerFrame then
            ObjectiveTrackerFrame:SetParent(UIParent)
            ObjectiveTrackerFrame:Show()
            if ObjectiveTrackerFrame.RegisterEvent then
                -- We might need to re-register events if we unregistered them.
                -- Ideally, a /reload is best for restoring completely, but let's try basic restoration
                ObjectiveTrackerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
                ObjectiveTrackerFrame:RegisterEvent("QUEST_LOG_UPDATE")
                ObjectiveTrackerFrame:RegisterEvent("TRACKED_ACHIEVEMENT_UPDATE")
            end
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
        trackerFrame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
        trackerFrame:RegisterEvent("TRACKED_ACHIEVEMENT_LIST_CHANGED")
        trackerFrame:RegisterEvent("CONTENT_TRACKING_UPDATE")
        trackerFrame:RegisterEvent("CONTENT_TRACKING_LIST_UPDATE")
        trackerFrame:RegisterEvent("QUEST_LOG_UPDATE")
        trackerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        trackerFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        trackerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        trackerFrame:RegisterEvent("CHALLENGE_MODE_START")
        trackerFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
        trackerFrame:RegisterEvent("CHALLENGE_MODE_RESET")
        trackerFrame:RegisterEvent("SUPER_TRACKING_CHANGED")
        trackerFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        trackerFrame:RegisterEvent("ZONE_CHANGED")
        trackerFrame:RegisterEvent("TASK_PROGRESS_UPDATE")
        trackerFrame:RegisterEvent("QUEST_ACCEPTED")
        trackerFrame:RegisterEvent("QUEST_REMOVED")
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

    UpdateContent()
end

addonTable.ObjectiveTracker.UpdateContent = UpdateContent

-- Hook into startup
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        addonTable.ObjectiveTracker.UpdateSettings()
    else
        -- Force update shortly after entering world to override Blizzard's show logic
        C_Timer.After(1, function() addonTable.ObjectiveTracker.UpdateSettings() end)
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
            ObjectiveTrackerFrame:Hide()
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
                C_SuperTrack.SetSuperTrackedQuestID(questID)
                SafeAfter(0.2, UpdateContent)
            end
        end
    end
end)
