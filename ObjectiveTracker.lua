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

local function GetFont()
    return UIThingsDB.tracker.font or "Fonts\\FRIZQT__.TTF"
end

local function GetFontSize()
    return UIThingsDB.tracker.fontSize or 12
end

local function OnQuestClick(self)
    -- Shift-Click to Untrack
    if IsShiftKeyDown() and self.questID then
        C_QuestLog.RemoveQuestWatch(self.questID)
        C_Timer.After(0.1, addonTable.ObjectiveTracker.UpdateContent) -- Refresh list
        return
    end

    -- Debug Message
    print("UIThings Debug: Quest Clicked! ID:", tostring(self.questID))
    
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
    else
        print("UIThings Debug: Error - No Quest ID on button")
    end
end

local function OnAchieveClick(self)
    -- Shift-Click to Untrack
    if IsShiftKeyDown() and self.achieID then
        if C_ContentTracking and C_ContentTracking.StopTracking then
            C_ContentTracking.StopTracking(Enum.ContentTrackingType.Achievement, self.achieID, Enum.ContentTrackingStopType.Manual)
        else
            RemoveTrackedAchievement(self.achieID)
        end
        C_Timer.After(0.1, addonTable.ObjectiveTracker.UpdateContent)
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

-- Item Factories
local function AcquireItem()
    for _, btn in ipairs(itemPool) do
        if not btn:IsShown() then
            return btn
        end
    end
    
    local btn = CreateFrame("Button", nil, scrollChild)
    btn:SetHeight(20)
    btn:RegisterForClicks("LeftButtonUp")
    
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14) -- Slightly smaller than text height
    icon:SetPoint("LEFT", 0, 0)
    btn.Icon = icon
    
    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", icon, "RIGHT", 5, 0) -- Indent text
    text:SetPoint("RIGHT", 0, 0)
    text:SetJustifyH("LEFT")
    btn.Text = text
    
    table.insert(itemPool, btn)
    return btn
end

local function ReleaseItems()
    for _, btn in ipairs(itemPool) do
        btn:Hide()
        btn:SetScript("OnClick", nil)
        btn.Icon:Hide()
        btn.Text:ClearAllPoints() -- Reset points to ensure clean state
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
    
    -- If we have items (or are unlocked), ensure shown (unless combat blocked)
    if not (UIThingsDB.tracker.hideInCombat and InCombatLockdown()) then
        trackerFrame:Show()
    end
    
    ReleaseItems()
    
    local font = GetFont()
    local size = GetFontSize()
    local yOffset = -5
    local width = scrollChild:GetWidth()
    
    -- Helper to add lines
    local function AddLine(text, isHeader, questID, achieID, isObjective)
        local btn = AcquireItem()
        btn:Show()
        
        -- Store IDs for Click Handlers
        btn.questID = questID
        btn.achieID = achieID
        
        btn:SetScript("OnClick", questID and OnQuestClick or achieID and OnAchieveClick or nil)
        
        btn:SetWidth(width)
        btn:SetPoint("TOPLEFT", 0, yOffset)
        
        -- Configurable Font/Size
        local fontSize = isObjective and (size - 2) or (isHeader and size + 2 or size)
        
        if isHeader then
            btn.Text:SetFont(font, fontSize, "OUTLINE")
            btn.Text:SetText(text)
            btn.Text:SetTextColor(1, 0.82, 0) -- Gold
            btn.Icon:Hide()
            btn.Text:SetPoint("LEFT", 0, 0)
            yOffset = yOffset - (fontSize + 6)
        else
            -- Normal Line (Quest or Objective or Achievement)
            btn.Text:SetFont(font, fontSize, "OUTLINE")
            btn.Text:SetText(text)
            
            if isObjective then
                 -- Objective Text (Grayish, Indented)
                 btn.Text:SetTextColor(0.8, 0.8, 0.8)
                 btn.Icon:Hide()
                 btn.Text:SetPoint("LEFT", 19, 0) -- Indent to match title text start
                 btn:EnableMouse(false)
                 yOffset = yOffset - (fontSize + 2)
            else
                 -- Main Entry
                 btn.Text:SetTextColor(1, 1, 1)
                 
                 if questID then
                    local isComplete = C_QuestLog.IsComplete(questID)
                    local iconPath = "Interface\\GossipFrame\\AvailableQuestIcon" -- Default Yellow !
                    
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
                        -- Question Marks
                        if isDaily then
                            iconPath = "Interface\\GossipFrame\\DailyActiveQuestIcon" -- Blue ?
                        elseif isCampaign then
                            iconPath = "Interface\\GossipFrame\\CampaignActiveQuestIcon"
                        elseif isLegendary then
                            iconPath = "Interface\\GossipFrame\\ActiveLegendaryQuestIcon"
                        else
                            iconPath = "Interface\\GossipFrame\\ActiveQuestIcon" -- Yellow ?
                        end
                    else
                        -- Exclamation Marks (In Progress)
                        if isDaily then
                            iconPath = "Interface\\GossipFrame\\DailyAvailableQuestIcon" -- Blue !
                        elseif isCampaign then
                            iconPath = "Interface\\GossipFrame\\CampaignAvailableQuestIcon"
                        elseif isLegendary then
                            iconPath = "Interface\\GossipFrame\\AvailableLegendaryQuestIcon"
                        else
                            iconPath = "Interface\\GossipFrame\\AvailableQuestIcon" -- Yellow !
                        end
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
                 
                 yOffset = yOffset - (fontSize + 4)
            end
        end
    end
    
    -- Quests
    local numQuests = C_QuestLog.GetNumQuestWatches()
    if numQuests > 0 then
        AddLine("Quests", true)
        
        for i = 1, numQuests do
            local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
            if questID then
                local title = C_QuestLog.GetTitleForQuestID(questID)
                if title then
                    AddLine(title, false, questID)
                    
                    -- Add Objectives
                    local objectives = C_QuestLog.GetQuestObjectives(questID)
                    if objectives then
                        for _, obj in pairs(objectives) do
                            local objText = obj.text
                            if objText and objText ~= "" then
                                if obj.finished then
                                    objText = "|cFF00FF00" .. objText .. "|r" -- Green if done
                                end
                                AddLine(objText, false, nil, nil, true)
                            end
                        end
                    end
                    yOffset = yOffset - 5 -- Spacing between quests
                end
            end
        end
        
        yOffset = yOffset - 10 -- Spacer
    end
    
    -- Achievements
    local trackedAchievements = C_ContentTracking.GetTrackedIDs(Enum.ContentTrackingType.Achievement)
    if #trackedAchievements > 0 then
        AddLine("Achievements", true)
        
        for _, achID in ipairs(trackedAchievements) do
            local _, name = GetAchievementInfo(achID)
            if name then
                AddLine(name, false, nil, achID)
                
                -- Add Criteria
                local numCriteria = GetAchievementNumCriteria(achID)
                for j = 1, numCriteria do
                    local criteriaString, _, completed, quantity, reqQuantity, _, _, _, quantityString = GetAchievementCriteriaInfo(achID, j)
                    if criteriaString then
                        local text = criteriaString
                        if (type(quantity) == "number" and type(reqQuantity) == "number") and reqQuantity > 1 then
                            text = text .. " (" .. quantity .. "/" .. reqQuantity .. ")"
                        end
                         
                        if completed then
                            text = "|cFF00FF00" .. text .. "|r"
                        end
                        AddLine(text, false, nil, nil, true)
                    end
                end
                
                yOffset = yOffset - 5 -- Spacing
            end
        end
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
    
    trackerFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(2, UpdateContent)
        elseif event == "PLAYER_REGEN_DISABLED" then
            if UIThingsDB.tracker.hideInCombat then
                self:Hide()
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if UIThingsDB.tracker.enabled then
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
    
    if UIThingsDB.tracker.hideInCombat and InCombatLockdown() then
        trackerFrame:Hide()
    else
        trackerFrame:Show()
    end
    
    -- Geometry
    trackerFrame:SetSize(UIThingsDB.tracker.width, UIThingsDB.tracker.height)
    scrollChild:SetWidth(UIThingsDB.tracker.width - 40)
    
    -- Lock/Unlock & Border State
    if UIThingsDB.tracker.locked then
        trackerFrame:EnableMouse(false)
        
        if UIThingsDB.tracker.showBorder then
            trackerFrame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false, tileSize = 0, edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            local c = UIThingsDB.tracker.backgroundColor or {r=0, g=0, b=0, a=0}
            trackerFrame:SetBackdropColor(c.r, c.g, c.b, c.a)
            trackerFrame:SetBackdropBorderColor(0, 0, 0, 1) -- 1px Black Border
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

