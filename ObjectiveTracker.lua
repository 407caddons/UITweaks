local addonName, addonTable = ...
addonTable.ObjectiveTracker = {}

local trackerFrame
local scrollFrame
local scrollChild
local contentFrame
local headerFrame
local itemPool = {}

-- Standard Logging
local function Log(msg)
    print("UIThings: " .. tostring(msg))
end

-- Use centralized SafeAfter from Core
local SafeAfter = function(delay, func)
    if addonTable.Core and addonTable.Core.SafeAfter then
        addonTable.Core.SafeAfter(delay, func)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(delay, func)
    end
end



local function OnQuestClick(self, button)
    -- Shift-Click to Untrack (if enabled)
    if IsShiftKeyDown() and self.questID and UIThingsDB.tracker.shiftClickUntrack then
        C_QuestLog.RemoveQuestWatch(self.questID)
        SafeAfter(0.1, addonTable.ObjectiveTracker.UpdateContent) -- Refresh list
        return
    end
    
    -- Right-Click to Super Track (if enabled)
    if button == "RightButton" and self.questID and UIThingsDB.tracker.rightClickSuperTrack then
        C_SuperTrack.SetSuperTrackedQuestID(self.questID)
        SafeAfter(0.1, addonTable.ObjectiveTracker.UpdateContent) -- Refresh list
        return
    end
    
    if self.questID then
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

local function OnAchieveClick(self)
    -- Shift-Click to Untrack (if enabled)
    if IsShiftKeyDown() and self.achieID and UIThingsDB.tracker.shiftClickUntrack then
        if C_ContentTracking and C_ContentTracking.StopTracking then
            C_ContentTracking.StopTracking(Enum.ContentTrackingType.Achievement, self.achieID, Enum.ContentTrackingStopType.Manual)
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
    
    table.insert(itemPool, btn)
    return btn
end

local function ReleaseItems()
    for _, btn in ipairs(itemPool) do
        btn:Hide()
        btn:SetScript("OnClick", nil)
        btn.Icon:Hide()
        btn.Text:ClearAllPoints() -- Reset points to ensure clean state
        if btn.ToggleBtn then btn.ToggleBtn:Hide() end
    end
end

local function UpdateContent()
    if not trackerFrame then return end
    
    -- Check Counts for Auto-Hide
    local numQuests = C_QuestLog.GetNumQuestWatches()
    local trackedAchievements = C_ContentTracking.GetTrackedIDs(Enum.ContentTrackingType.Achievement)
    local total = numQuests + #trackedAchievements
    
    if total == 0 and UIThingsDB.tracker.locked then
        trackerFrame:Hide()
        return
    end
    
    -- If we have items (or are unlocked), ensure shown (unless blocked)
    if not (UIThingsDB.tracker.hideInCombat and InCombatLockdown()) and not (UIThingsDB.tracker.hideInMPlus and C_ChallengeMode.IsChallengeModeActive()) then
        trackerFrame:Show()
    end
    
    ReleaseItems()
    
    -- Base font (for section headers like "Quests")
    local baseFont = UIThingsDB.tracker.font or "Fonts\\FRIZQT__.TTF"
    local baseSize = UIThingsDB.tracker.fontSize or 12
    
    -- Specific fonts (Quest Name and Detail)
    local questNameFont = UIThingsDB.tracker.headerFont or "Fonts\\FRIZQT__.TTF" 
    local questNameSize = UIThingsDB.tracker.headerFontSize or 14
    local detailFont = UIThingsDB.tracker.detailFont or "Fonts\\FRIZQT__.TTF"
    local detailSize = UIThingsDB.tracker.detailFontSize or 12
    local questPadding = UIThingsDB.tracker.questPadding or 2
    
    -- Ensure Collapsed State
    UIThingsDB.tracker.collapsed = UIThingsDB.tracker.collapsed or {}
    
    local yOffset = -5
    local width = scrollChild:GetWidth()
    
    -- Helper to add lines
    -- questID is repurposed as sectionKey if isHeader is true
    local function AddLine(text, isHeader, questID, achieID, isObjective, overrideColor)
        local btn = AcquireItem()
        btn:Show()
        
        -- Store IDs for Click Handlers
        btn.questID = questID
        btn.achieID = achieID
        
        btn:SetScript("OnClick", questID and OnQuestClick or achieID and OnAchieveClick or nil)
        
        btn:SetWidth(width)
        btn:SetPoint("TOPLEFT", 0, yOffset)
        
        if isHeader then
            -- Section Header (e.g. "Quests") - Use Base Font
            btn.Text:SetFont(baseFont, baseSize + 2, "OUTLINE") -- Slightly larger than base
            btn.Text:SetText(text)
            btn.Text:SetTextColor(1, 0.82, 0) -- Gold
            btn.Icon:Hide()
            btn.Text:SetPoint("LEFT", 0, 0)
            
            -- Toggle Button Logic
            if questID then -- sectionKey
                local section = questID
                local isCollapsed = UIThingsDB.tracker.collapsed[section]
                
                btn.ToggleBtn:Show()
                btn.ToggleBtn:SetScript("OnClick", function()
                    UIThingsDB.tracker.collapsed[section] = not isCollapsed
                    UpdateContent()
                end)
                
                if isCollapsed then
                    btn.ToggleBtn.Text:SetText("+")
                else
                    btn.ToggleBtn.Text:SetText("-")
                end
                
                -- Position to right of text
                local textWidth = btn.Text:GetStringWidth()
                btn.ToggleBtn:SetPoint("LEFT", btn.Text, "LEFT", textWidth + 5, 0)
            else
                 btn.ToggleBtn:Hide()
            end
            
            yOffset = yOffset - (baseSize + 8)
        else
            -- Content Line
            if isObjective then
                 -- Objective / Detail
                 local currentSize = detailSize
                 
                 btn.Text:SetFont(detailFont, currentSize, "OUTLINE")
                 btn.Text:SetText(text)
                 btn.Text:SetTextColor(0.8, 0.8, 0.8)
                 btn.Icon:Hide()
                 btn.Text:SetPoint("LEFT", 19, 0)
                 btn:EnableMouse(false)
                 yOffset = yOffset - (currentSize + questPadding)
            else
                 -- Quest Name / Achievement Title
                 -- Use "Quest Name" font settings (formerly headerFont)
                 local currentSize = questNameSize
                 
                 btn.Text:SetFont(questNameFont, currentSize, "OUTLINE")
                 btn.Text:SetText(text)
                 
                 if overrideColor then
                     btn.Text:SetTextColor(overrideColor.r, overrideColor.g, overrideColor.b, overrideColor.a or 1)
                 else
                     btn.Text:SetTextColor(1, 1, 1)
                 end
                 
                 if questID then
                    local isComplete = C_QuestLog.IsComplete(questID)
                    local iconPath = "Interface\\GossipFrame\\AvailableQuestIcon"
                    
                    local tagInfo = C_QuestLog.GetQuestTagInfo(questID)
                    local isDaily = false
                    local isCampaign = false
                    local isLegendary = false
                    
                    if tagInfo then
                        if tagInfo.isDaily or tagInfo.frequency == Enum.QuestFrequency.Daily or tagInfo.frequency == Enum.QuestFrequency.Weekly then
                            isDaily = true
                        elseif tagInfo.tagID == 102 then 
                            isDaily = true
                        elseif tagInfo.quality == Enum.QuestTagType.Campaign then
                            isCampaign = true
                        elseif tagInfo.quality == Enum.QuestTagType.Legendary then
                            isLegendary = true
                        end
                    end
                    
                    if isComplete then
                        if isDaily then iconPath = "Interface\\GossipFrame\\DailyActiveQuestIcon"
                        elseif isCampaign then iconPath = "Interface\\GossipFrame\\CampaignActiveQuestIcon"
                        elseif isLegendary then iconPath = "Interface\\GossipFrame\\ActiveLegendaryQuestIcon"
                        else iconPath = "Interface\\GossipFrame\\ActiveQuestIcon" end
                    else
                        if isDaily then iconPath = "Interface\\GossipFrame\\DailyAvailableQuestIcon"
                        elseif isCampaign then iconPath = "Interface\\GossipFrame\\CampaignAvailableQuestIcon"
                        elseif isLegendary then iconPath = "Interface\\GossipFrame\\AvailableLegendaryQuestIcon"
                        else iconPath = "Interface\\GossipFrame\\AvailableQuestIcon" end
                    end
                    
                    btn.Icon:SetTexture(iconPath)
                    btn.Icon:Show()
                    btn.Text:SetPoint("LEFT", btn.Icon, "RIGHT", 5, 0)
                    btn:EnableMouse(true)
                 else
                    -- Achievement
                    btn.Icon:Hide()
                    btn.Text:SetPoint("LEFT", 19, 0)
                    if achieID then btn:EnableMouse(true) else btn:EnableMouse(false) end
                 end
                 
                 yOffset = yOffset - (currentSize + 4)
            end
        end
    end
    
    -- Track displayed IDs to prevent duplicates
    local displayedIDs = {}
    
    local function RenderWorldQuests()
        local mapID = C_Map.GetBestMapForUnit("player")
        if not mapID then return end
        
        local tasks = C_TaskQuest.GetQuestsOnMap(mapID)
        local activeWQs = {}       -- Specifically the one(s) the player is doing now
        local otherWQs = {}        -- All other available ones
        local onlyActive = UIThingsDB.tracker.onlyActiveWorldQuests
        
        if tasks then
            for _, info in ipairs(tasks) do
                local questID = info.questID
                -- Check availability
                if questID and C_TaskQuest.IsActive(questID) and (C_QuestLog.IsWorldQuest(questID) or C_QuestLog.IsQuestTask(questID)) then
                    local isActive = C_QuestLog.IsOnQuest(questID)
                    
                    if onlyActive then
                        if isActive then
                            table.insert(activeWQs, questID)
                        end
                    else
                        -- Show All
                        if isActive then
                            table.insert(activeWQs, questID)
                        else
                            table.insert(otherWQs, questID)
                        end
                    end
                end
            end
        end
        
        local hasWQs = (#activeWQs > 0) or (#otherWQs > 0)
        
        if hasWQs then
            AddLine("World Quests", true, "worldQuests")
            
            if UIThingsDB.tracker.collapsed["worldQuests"] then
                 yOffset = yOffset - 5
                 return
            end
            
            -- Render Active Ones First (Highlighted)
            for _, questID in ipairs(activeWQs) do
                if not displayedIDs[questID] then
                    local title = C_QuestLog.GetTitleForQuestID(questID)
                    if title then
                        -- Apply Active Quest Color
                        AddLine(title, false, questID, nil, false, UIThingsDB.tracker.activeQuestColor)
                        displayedIDs[questID] = true
                        
                        local objectives = C_QuestLog.GetQuestObjectives(questID)
                        if objectives then
                            for _, obj in pairs(objectives) do
                                local objText = obj.text
                                if objText and objText ~= "" then
                                    if obj.finished then objText = "|cFF00FF00" .. objText .. "|r" end
                                    AddLine(objText, false, nil, nil, true)
                                end
                            end
                        end
                        yOffset = yOffset - 5
                    end
                end
            end
            
            -- Render Others (Normal)
            for _, questID in ipairs(otherWQs) do
                if not displayedIDs[questID] then
                    local title = C_QuestLog.GetTitleForQuestID(questID)
                    if title then
                        AddLine(title, false, questID, nil, false, nil)
                        displayedIDs[questID] = true
                        
                        local objectives = C_QuestLog.GetQuestObjectives(questID)
                        if objectives then
                            for _, obj in pairs(objectives) do
                                local objText = obj.text
                                if objText and objText ~= "" then
                                    if obj.finished then objText = "|cFF00FF00" .. objText .. "|r" end
                                    AddLine(objText, false, nil, nil, true)
                                end
                            end
                        end
                        yOffset = yOffset - 5
                    end
                end
            end
            
            yOffset = yOffset - 10
        end
    end
    
    local function RenderQuests()
        local numQuests = C_QuestLog.GetNumQuestWatches()
        if numQuests > 0 then
            
            -- Identify Super Tracked Quest
            local superTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID()
            local superTrackedIndex = nil
            
            -- Filter out ones already displayed (e.g. if a WQ was also watched)
            local filteredIndices = {}
            for i = 1, numQuests do
                local qID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
                if qID and not displayedIDs[qID] then
                    if qID == superTrackedQuestID then
                        superTrackedIndex = i
                    else
                        table.insert(filteredIndices, i)
                    end
                end
            end
            
            -- Insert Super Tracked at the TOP of the list
            if superTrackedIndex then
                table.insert(filteredIndices, 1, superTrackedIndex)
            end
            
            if #filteredIndices > 0 then
                AddLine("Quests", true, "quests")
                
                if UIThingsDB.tracker.collapsed["quests"] then
                     yOffset = yOffset - 5
                     return
                end
                    for _, i in ipairs(filteredIndices) do
                    local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
                    local title = C_QuestLog.GetTitleForQuestID(questID)
                    if title then
                        -- Check if this is the super tracked one to apply color
                        local color = nil
                        if questID == superTrackedQuestID then
                            color = UIThingsDB.tracker.activeQuestColor
                        end
                        
                        AddLine(title, false, questID, nil, false, color)
                        displayedIDs[questID] = true
                        
                        local objectives = C_QuestLog.GetQuestObjectives(questID)
                        if objectives then
                            for _, obj in pairs(objectives) do
                                local objText = obj.text
                                if objText and objText ~= "" then
                                    if obj.finished then objText = "|cFF00FF00" .. objText .. "|r" end
                                    AddLine(objText, false, nil, nil, true)
                                end
                            end
                        end
                        yOffset = yOffset - 5
                    end
                    end
                yOffset = yOffset - 10
            end
        end
    end
    
    local function RenderAchievements()
        local trackedAchievements = C_ContentTracking.GetTrackedIDs(Enum.ContentTrackingType.Achievement)
        if #trackedAchievements > 0 then
            AddLine("Achievements", true, "achievements")
            
            if UIThingsDB.tracker.collapsed["achievements"] then
                yOffset = yOffset - 5
                return
            end

            for _, achID in ipairs(trackedAchievements) do
                local _, name = GetAchievementInfo(achID)
                if name then
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
                    yOffset = yOffset - 5
                end
            end
            yOffset = yOffset - 10
        end
    end
    
    -- Order Logic
    local orderMap = {
        [1] = {RenderWorldQuests, RenderQuests, RenderAchievements},
        [2] = {RenderWorldQuests, RenderAchievements, RenderQuests},
        [3] = {RenderQuests, RenderWorldQuests, RenderAchievements},
        [4] = {RenderQuests, RenderAchievements, RenderWorldQuests},
        [5] = {RenderAchievements, RenderWorldQuests, RenderQuests},
        [6] = {RenderAchievements, RenderQuests, RenderWorldQuests},
    }
    
    local selectedOrder = UIThingsDB.tracker.sectionOrder or 1
    local pipeline = orderMap[selectedOrder] or orderMap[1]
    
    for _, renderer in ipairs(pipeline) do
        renderer()
    end
    
    -- Resize Scroll Child
    local totalHeight = math.abs(yOffset)
    scrollChild:SetHeight(math.max(totalHeight, 50))
end

local function SetupCustomTracker()
    if trackerFrame then return end
    local settings = UIThingsDB.tracker
    
    -- Main Container
    trackerFrame = CreateFrame("Frame", "UIThingsCustomTracker", UIParent, "BackdropTemplate")
    trackerFrame:SetPoint(settings.point or "TOPRIGHT", UIParent, settings.point or "TOPRIGHT", settings.x or -20, settings.y or -250)
    trackerFrame:SetSize(settings.width, settings.height)
    
    trackerFrame:SetMovable(true)
    trackerFrame:SetResizable(true)
    trackerFrame:SetClampedToScreen(true)
    trackerFrame:SetResizeBounds(150, 150, 600, 1000)
    
    -- Background for Unlocked state
    trackerFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
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
    trackerFrame:RegisterEvent("CONTENT_TRACKING_UPDATE") -- Modern
    trackerFrame:RegisterEvent("CONTENT_TRACKING_LIST_UPDATE") -- Modern
    trackerFrame:RegisterEvent("QUEST_LOG_UPDATE")
    trackerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    trackerFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    trackerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    trackerFrame:RegisterEvent("CHALLENGE_MODE_START")
    trackerFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    trackerFrame:RegisterEvent("CHALLENGE_MODE_RESET")
    
    trackerFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(2, UpdateContent)
        elseif event == "PLAYER_REGEN_DISABLED" then
            if UIThingsDB.tracker.hideInCombat then
                self:Hide()
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if UIThingsDB.tracker.enabled and not (UIThingsDB.tracker.hideInMPlus and C_ChallengeMode.IsChallengeModeActive()) then
                self:Show()
            end
        elseif event == "CHALLENGE_MODE_START" then
            if UIThingsDB.tracker.hideInMPlus then
                self:Hide()
            end
        elseif event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
            if UIThingsDB.tracker.enabled and not (UIThingsDB.tracker.hideInCombat and InCombatLockdown()) then
                self:Show()
            end
        else
            UpdateContent()
        end
    end)
end

function addonTable.ObjectiveTracker.UpdateSettings()
    local enabled = UIThingsDB.tracker.enabled
    
    -- Blizzard Tracker Logic
    if enabled then
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
        if trackerFrame then trackerFrame:Hide() end
        return
    end

    -- Custom Tracker Logic
    SetupCustomTracker()
    
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
                tile = false, tileSize = 0, edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            
            -- Background
            if showBackground then
                local c = UIThingsDB.tracker.backgroundColor or {r=0, g=0, b=0, a=0.5}
                trackerFrame:SetBackdropColor(c.r, c.g, c.b, c.a)
            else
                trackerFrame:SetBackdropColor(0, 0, 0, 0)
            end
            
            -- Border
            if showBorder then
                local bc = UIThingsDB.tracker.borderColor or {r=0, g=0, b=0, a=1}
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
            tile = true, tileSize = 16, edgeSize = 16,
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


-- Aggressive Hide Hook
if ObjectiveTrackerFrame then
    hooksecurefunc(ObjectiveTrackerFrame, "Show", function()
        if UIThingsDB.tracker.enabled then
            ObjectiveTrackerFrame:Hide()
        end
    end)
end

-- Auto Track Quests Feature
local autoTrackFrame = CreateFrame("Frame")
autoTrackFrame:RegisterEvent("QUEST_ACCEPTED")
autoTrackFrame:SetScript("OnEvent", function(self, event, questID)
    if event == "QUEST_ACCEPTED" and questID then
        if UIThingsDB.tracker and UIThingsDB.tracker.enabled and UIThingsDB.tracker.autoTrackQuests then
            -- Check if quest is not already tracked
            if not C_QuestLog.GetQuestWatchType(questID) then
                C_QuestLog.AddQuestWatch(questID, Enum.QuestWatchType.Automatic)
                SafeAfter(0.2, UpdateContent)
            end
        end
    end
end)
