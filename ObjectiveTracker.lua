local addonName, addonTable = ...
addonTable.ObjectiveTracker = {}

local scrollContainer
local dragOverlay
local setupDone = false
local initAttempts = 0

-- Standard Logging
local function Log(msg)
    print("UIThings: " .. tostring(msg))
end

function addonTable.ObjectiveTracker.UpdateSettings()
    if not UIThingsDB.tracker.enabled then
        if scrollContainer then scrollContainer:Hide() end
        return
    end

    if not setupDone then
        SetupScrollingTracker()
        return
    end

    if scrollContainer then scrollContainer:Show() end
    if not scrollContainer then return end
    
    local settings = UIThingsDB.tracker
    local tracker = ObjectiveTrackerFrame
    
    scrollContainer:SetSize(settings.width, settings.height)
    
    if dragOverlay then
        if settings.locked then
            dragOverlay:Hide()
        else
            dragOverlay:Show()
        end
    end

    local scrollChild = _G["UIThingsScrollChild"]
    if tracker and scrollChild then
        if tracker:GetParent() ~= scrollChild then
            tracker:SetParent(scrollChild)
        end
        tracker:ClearAllPoints()
        -- Add 20px padding on left to prevent marker clipping
        tracker:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 20, 0)
        tracker:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, 0)
    end

    if scrollChild then
        -- Adjust width to account for the 20px padding + scrollbar
        scrollChild:SetWidth(math.max(1, settings.width - 50))
    end
end

local function SetupScrollingTracker()
    if not UIThingsDB.tracker.enabled then return end
    if setupDone then return end
    
    local tracker = ObjectiveTrackerFrame
    if not tracker then 
        initAttempts = initAttempts + 1
        if initAttempts < 10 then
            C_Timer.After(1, SetupScrollingTracker)
        end
        return 
    end

    local settings = UIThingsDB.tracker
    
    -- Safe Fallbacks
    local point = settings.point or "TOPRIGHT"
    local x = settings.x or -20
    local y = settings.y or -250
    local w = settings.width or 300
    local h = settings.height or 500

    -- Create Container for the ScrollFrame
    scrollContainer = CreateFrame("Frame", "UIThingsScrollContainer", UIParent)
    scrollContainer:SetSize(w, h)
    scrollContainer:SetPoint(point, UIParent, point, x, y)
    scrollContainer:SetMovable(true)
    scrollContainer:SetResizable(true)
    scrollContainer:SetResizeBounds(150, 150, 800, 1200)
    scrollContainer:SetClampedToScreen(true)

    -- Create DragOverlay
    dragOverlay = CreateFrame("Frame", "UIThingsDragOverlay", scrollContainer)
    dragOverlay:SetAllPoints()
    dragOverlay:SetFrameLevel(scrollContainer:GetFrameLevel() + 100)
    
    local bg = dragOverlay:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0.5, 1, 0.5)
    
    local label = dragOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    label:SetPoint("CENTER")
    label:SetText("LUNA'S UI TWEAKS UNLOCKED")

    dragOverlay:EnableMouse(true)
    dragOverlay:RegisterForDrag("LeftButton")
    
    dragOverlay:SetScript("OnDragStart", function(self) scrollContainer:StartMoving() end)
    dragOverlay:SetScript("OnDragStop", function(self) 
        scrollContainer:StopMovingOrSizing() 
        local point, _, relativePoint, xOfs, yOfs = scrollContainer:GetPoint()
        UIThingsDB.tracker.point = point
        UIThingsDB.tracker.x = xOfs
        UIThingsDB.tracker.y = yOfs
    end)

    -- Resize Handle
    local resizeHandle = CreateFrame("Frame", nil, dragOverlay)
    resizeHandle:SetSize(25, 25)
    resizeHandle:SetPoint("BOTTOMRIGHT")
    resizeHandle:EnableMouse(true)
    
    local tex = resizeHandle:CreateTexture(nil, "OVERLAY")
    tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    tex:SetAllPoints()
    
    resizeHandle:SetScript("OnMouseDown", function() scrollContainer:StartSizing("BOTTOMRIGHT") end)
    resizeHandle:SetScript("OnMouseUp", function()
        scrollContainer:StopMovingOrSizing()
        local w, h = scrollContainer:GetSize()
        UIThingsDB.tracker.width = w
        UIThingsDB.tracker.height = h
        
        UIThingsDB.tracker.point, _, _, UIThingsDB.tracker.x, UIThingsDB.tracker.y = scrollContainer:GetPoint()
        
        if _G["UIThingsWidthSlider"] then
            _G["UIThingsWidthSlider"]:SetValue(w)
            _G["UIThingsHeightSlider"]:SetValue(h)
        end
        addonTable.ObjectiveTracker.UpdateSettings()
    end)
    
    -- Scroll Frame
    local scrollFrame = CreateFrame("ScrollFrame", "UIThingsScrollFrame", scrollContainer, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 15, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)
    scrollFrame.scrollBarHideable = true

    local function UpdateScrollBarVisibility(scrollFrame)
        local yrange = scrollFrame:GetVerticalScrollRange()
        local scrollBar = _G["UIThingsScrollFrameScrollBar"]
        if scrollBar then
            -- Check count of tracked items
            local numQuests = (C_QuestLog and C_QuestLog.GetNumQuestWatches) and C_QuestLog.GetNumQuestWatches() or 0
            local numAchieves = GetNumTrackedAchievements and GetNumTrackedAchievements() or 0
            local totalTracked = numQuests + numAchieves

            -- Only show if we need to scroll AND we have at least 5 items tracked
            if yrange < 1 or totalTracked < 5 then
                scrollBar:Hide()
            else
                scrollBar:Show()
            end
        end
    end

    scrollFrame:HookScript("OnScrollRangeChanged", function(self, xrange, yrange)
        UpdateScrollBarVisibility(self)
    end)

    -- Register events for tracking changes
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
    eventFrame:RegisterEvent("TRACKED_ACHIEVEMENT_LIST_CHANGED")
    eventFrame:RegisterEvent("ACHIEVEMENT_EARNED")
    eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
    eventFrame:SetScript("OnEvent", function()
        UpdateScrollBarVisibility(scrollFrame)
    end)

    -- Scroll Child
    local scrollChild = CreateFrame("Frame", "UIThingsScrollChild", scrollFrame)
    scrollChild:SetSize(w - 50, 1) -- Start small so we don't show scrollbar if empty
    scrollFrame:SetScrollChild(scrollChild)

    -- Reparent Tracker
    tracker:SetParent(scrollChild)
    tracker:ClearAllPoints()
    -- Add 20px padding on left to prevent marker clipping
    tracker:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 20, 0)
    tracker:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, 0)

    -- Monitor
    C_Timer.NewTicker(2, function()
        if setupDone then
            if tracker:GetParent() ~= scrollChild then
                Log("Alert! Parent hijacked. Reclaiming.")
                addonTable.ObjectiveTracker.UpdateSettings()
            end
            local h = tracker:GetHeight() or 0
            -- Always update height, ensuring at least 1px
            scrollChild:SetHeight(math.max(1, h + 50))
        end
    end)

    setupDone = true
    addonTable.ObjectiveTracker.UpdateSettings()
    Log("Setup Complete.")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, SetupScrollingTracker)
    end
end)
