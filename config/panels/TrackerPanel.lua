local addonName, addonTable = ...

-- Create setup table if it doesn't exist
addonTable.ConfigSetup = addonTable.ConfigSetup or {}

-- Get helpers
local Helpers = addonTable.ConfigHelpers

-- Define the setup function for Tracker panel
function addonTable.ConfigSetup.Tracker(panel, tab, configWindow)
    local fonts = Helpers.fonts

    local function UpdateTracker()
        if addonTable.ObjectiveTracker and addonTable.ObjectiveTracker.UpdateSettings then
            addonTable.ObjectiveTracker.UpdateSettings()
        end
    end

    local trackerTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    trackerTitle:SetPoint("TOPLEFT", 16, -16)
    trackerTitle:SetText("Objective Tracker")

    -- Create scroll frame for the settings
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(560, 1205)
    scrollFrame:SetScrollChild(scrollChild)

    -- Update panel reference to scrollChild for all child elements
    panel = scrollChild

    -------------------------------------------------------------
    -- SECTION: General (-10)
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(panel, "General", -10)

    local enableTrackerBtn = CreateFrame("CheckButton", "UIThingsTrackerEnableCheck", panel,
        "ChatConfigCheckButtonTemplate")
    enableTrackerBtn:SetPoint("TOPLEFT", 20, -40)
    _G[enableTrackerBtn:GetName() .. "Text"]:SetText("Enable Objective Tracker Tweaks")
    enableTrackerBtn:SetChecked(UIThingsDB.tracker.enabled)
    enableTrackerBtn:SetScript("OnClick", function(self)
        local enabled = not not self:GetChecked()
        UIThingsDB.tracker.enabled = enabled
        UpdateTracker()
        Helpers.UpdateModuleVisuals(panel, tab, enabled)
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.tracker.enabled)

    local lockBtn = CreateFrame("CheckButton", "UIThingsLockCheck", panel, "ChatConfigCheckButtonTemplate")
    lockBtn:SetPoint("TOPLEFT", 250, -40)
    _G[lockBtn:GetName() .. "Text"]:SetText("Lock Position")
    lockBtn:SetChecked(UIThingsDB.tracker.locked)
    lockBtn:SetScript("OnClick", function(self)
        local locked = not not self:GetChecked()
        UIThingsDB.tracker.locked = locked
        UpdateTracker()
    end)

    local hideHeaderBtn = CreateFrame("CheckButton", "UIThingsHideHeaderCheck", panel, "ChatConfigCheckButtonTemplate")
    hideHeaderBtn:SetPoint("TOPLEFT", 400, -40)
    _G[hideHeaderBtn:GetName() .. "Text"]:SetText("Hide Header")
    hideHeaderBtn:SetChecked(UIThingsDB.tracker.hideHeader)
    hideHeaderBtn:SetScript("OnClick", function(self)
        UIThingsDB.tracker.hideHeader = not not self:GetChecked()
        UpdateTracker()
    end)

    -------------------------------------------------------------
    -- SECTION: Sorting & Filtering (-70)
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(panel, "Sorting & Filtering", -70)

    local orderLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    orderLabel:SetPoint("TOPLEFT", 20, -95)
    orderLabel:SetText("Section Order: (top to bottom)")

    if not UIThingsDB.tracker.sectionOrderList then
        UIThingsDB.tracker.sectionOrderList = {
            "scenarios",
            "tempObjectives",
            "travelersLog",
            "worldQuests",
            "quests",
            "achievements"
        }
    else
        -- Migration: Add travelersLog if it doesn't exist
        local hasTravelersLog = false
        for _, key in ipairs(UIThingsDB.tracker.sectionOrderList) do
            if key == "travelersLog" then
                hasTravelersLog = true
                break
            end
        end
        if not hasTravelersLog then
            local insertPos = 3
            for i, key in ipairs(UIThingsDB.tracker.sectionOrderList) do
                if key == "tempObjectives" then
                    insertPos = i + 1
                    break
                end
            end
            table.insert(UIThingsDB.tracker.sectionOrderList, insertPos, "travelersLog")
        end
    end

    local sectionNames = {
        scenarios = "Scenarios",
        tempObjectives = "Temporary Objectives",
        travelersLog = "Traveler's Log",
        worldQuests = "World Quests",
        quests = "Quests",
        achievements = "Achievements"
    }

    local orderItems = {}
    local yPos = -120

    local function UpdateOrderDisplay()
        for i, sectionKey in ipairs(UIThingsDB.tracker.sectionOrderList) do
            if orderItems[i] then
                orderItems[i].text:SetText(string.format("%d. %s", i, sectionNames[sectionKey]))
                orderItems[i].upBtn:SetEnabled(i > 1)
                orderItems[i].downBtn:SetEnabled(i < #UIThingsDB.tracker.sectionOrderList)
            end
        end
        UpdateTracker()
    end

    for i = 1, 6 do
        local item = CreateFrame("Frame", nil, panel)
        item:SetPoint("TOPLEFT", 20, yPos)
        item:SetSize(250, 24)

        item.text = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        item.text:SetPoint("LEFT", 5, 0)

        item.upBtn = CreateFrame("Button", nil, item)
        item.upBtn:SetSize(24, 24)
        item.upBtn:SetPoint("RIGHT", -30, 0)
        item.upBtn:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
        item.upBtn:SetScript("OnClick", function()
            if i > 1 then
                local temp = UIThingsDB.tracker.sectionOrderList[i]
                UIThingsDB.tracker.sectionOrderList[i] = UIThingsDB.tracker.sectionOrderList[i - 1]
                UIThingsDB.tracker.sectionOrderList[i - 1] = temp
                UpdateOrderDisplay()
            end
        end)

        item.downBtn = CreateFrame("Button", nil, item)
        item.downBtn:SetSize(24, 24)
        item.downBtn:SetPoint("RIGHT", 0, 0)
        item.downBtn:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
        item.downBtn:SetScript("OnClick", function()
            if i < #UIThingsDB.tracker.sectionOrderList then
                local temp = UIThingsDB.tracker.sectionOrderList[i]
                UIThingsDB.tracker.sectionOrderList[i] = UIThingsDB.tracker.sectionOrderList[i + 1]
                UIThingsDB.tracker.sectionOrderList[i + 1] = temp
                UpdateOrderDisplay()
            end
        end)

        orderItems[i] = item
        yPos = yPos - 26
    end

    UpdateOrderDisplay()

    local zoneGroupCheckbox = CreateFrame("CheckButton", "UIThingsTrackerZoneGroupCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    zoneGroupCheckbox:SetPoint("TOPLEFT", 300, -95)
    zoneGroupCheckbox:SetHitRectInsets(0, -130, 0, 0)
    _G[zoneGroupCheckbox:GetName() .. "Text"]:SetText("Group Quests by Zone")
    zoneGroupCheckbox:SetChecked(UIThingsDB.tracker.groupQuestsByZone)
    zoneGroupCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.groupQuestsByZone = self:GetChecked()
        UpdateTracker()
    end)

    local showDistCheckbox = CreateFrame("CheckButton", "UIThingsTrackerShowDistCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    showDistCheckbox:SetPoint("TOPLEFT", 300, -120)
    showDistCheckbox:SetHitRectInsets(0, -130, 0, 0)
    _G[showDistCheckbox:GetName() .. "Text"]:SetText("Show Distance on Quests")
    showDistCheckbox:SetChecked(UIThingsDB.tracker.showQuestDistance)
    showDistCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.showQuestDistance = self:GetChecked()
        UpdateTracker()
    end)

    local questDistCheckbox = CreateFrame("CheckButton", "UIThingsTrackerQuestDistCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    questDistCheckbox:SetPoint("TOPLEFT", 300, -145)
    questDistCheckbox:SetHitRectInsets(0, -130, 0, 0)
    _G[questDistCheckbox:GetName() .. "Text"]:SetText("Sort Quests by Distance")
    questDistCheckbox:SetChecked(UIThingsDB.tracker.sortQuestsByDistance)
    questDistCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.sortQuestsByDistance = self:GetChecked()
        UpdateTracker()
    end)

    local distIntervalSlider = CreateFrame("Slider", "UIThingsTrackerDistIntervalSlider", panel,
        "OptionsSliderTemplate")
    distIntervalSlider:SetPoint("TOPLEFT", 300, -190)
    distIntervalSlider:SetMinMaxValues(0, 30)
    distIntervalSlider:SetValueStep(1)
    distIntervalSlider:SetObeyStepOnDrag(true)
    distIntervalSlider:SetWidth(180)
    local distVal = UIThingsDB.tracker.distanceUpdateInterval or 0
    _G[distIntervalSlider:GetName() .. 'Text']:SetText(
        distVal == 0 and "Distance Refresh: Off" or string.format("Distance Refresh: %ds", distVal))
    _G[distIntervalSlider:GetName() .. 'Low']:SetText("Off")
    _G[distIntervalSlider:GetName() .. 'High']:SetText("30s")
    distIntervalSlider:SetValue(distVal)
    distIntervalSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.tracker.distanceUpdateInterval = value
        _G[self:GetName() .. 'Text']:SetText(
            value == 0 and "Distance Refresh: Off" or string.format("Distance Refresh: %ds", value))
        UpdateTracker()
    end)

    local wqActiveCheckbox = CreateFrame("CheckButton", "UIThingsTrackerWQActiveCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    wqActiveCheckbox:SetPoint("TOPLEFT", 300, -225)
    wqActiveCheckbox:SetHitRectInsets(0, -130, 0, 0)
    _G[wqActiveCheckbox:GetName() .. "Text"]:SetText("Only Active World Quests")
    wqActiveCheckbox:SetChecked(UIThingsDB.tracker.onlyActiveWorldQuests)
    wqActiveCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.onlyActiveWorldQuests = self:GetChecked()
        UpdateTracker()
    end)

    local wqSortLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    wqSortLabel:SetPoint("TOPLEFT", 300, -255)
    wqSortLabel:SetText("Sort World Quests:")

    local wqSortDropdown = CreateFrame("Frame", "UIThingsTrackerWQSortDropdown", panel, "UIDropDownMenuTemplate")
    wqSortDropdown:SetPoint("TOPLEFT", wqSortLabel, "BOTTOMLEFT", -15, -2)

    local wqSortOptions = {
        { text = "By Time",     value = "time" },
        { text = "By Distance", value = "distance" },
    }

    local function WQSortOnClick(self)
        UIDropDownMenu_SetSelectedValue(wqSortDropdown, self.value)
        UIThingsDB.tracker.worldQuestSortBy = self.value
        UpdateTracker()
    end

    local function WQSortInit(self, level)
        for _, opt in ipairs(wqSortOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.text
            info.value = opt.value
            info.func = WQSortOnClick
            info.checked = (UIThingsDB.tracker.worldQuestSortBy == opt.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(wqSortDropdown, WQSortInit)
    local currentWQSort = UIThingsDB.tracker.worldQuestSortBy or "time"
    for _, opt in ipairs(wqSortOptions) do
        if opt.value == currentWQSort then
            UIDropDownMenu_SetText(wqSortDropdown, opt.text)
            break
        end
    end

    -------------------------------------------------------------
    -- SECTION: Display (-310)
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(panel, "Display", -310)

    local wqTimerCheckbox = CreateFrame("CheckButton", "UIThingsTrackerWQTimerCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    wqTimerCheckbox:SetPoint("TOPLEFT", 20, -335)
    wqTimerCheckbox:SetHitRectInsets(0, -130, 0, 0)
    _G[wqTimerCheckbox:GetName() .. "Text"]:SetText("Show World Quest Timer")
    wqTimerCheckbox:SetChecked(UIThingsDB.tracker.showWorldQuestTimer)
    wqTimerCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.showWorldQuestTimer = self:GetChecked()
        UpdateTracker()
    end)

    local wqRewardCheckbox = CreateFrame("CheckButton", "UIThingsTrackerWQRewardCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    wqRewardCheckbox:SetPoint("TOPLEFT", 300, -335)
    wqRewardCheckbox:SetHitRectInsets(0, -160, 0, 0)
    _G[wqRewardCheckbox:GetName() .. "Text"]:SetText("Show WQ Reward Icons")
    wqRewardCheckbox:SetChecked(UIThingsDB.tracker.showWQRewardIcons)
    wqRewardCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.showWQRewardIcons = self:GetChecked()
        UpdateTracker()
    end)

    local hideCompletedCheckbox = CreateFrame("CheckButton", "UIThingsTrackerHideCompletedCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    hideCompletedCheckbox:SetPoint("TOPLEFT", 20, -360)
    hideCompletedCheckbox:SetHitRectInsets(0, -130, 0, 0)
    _G[hideCompletedCheckbox:GetName() .. "Text"]:SetText("Hide Completed Objectives")
    hideCompletedCheckbox:SetChecked(UIThingsDB.tracker.hideCompletedSubtasks)
    hideCompletedCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.hideCompletedSubtasks = self:GetChecked()
        UpdateTracker()
    end)

    local checkmarkCheckbox = CreateFrame("CheckButton", "UIThingsTrackerCheckmarkCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    checkmarkCheckbox:SetPoint("TOPLEFT", 300, -360)
    checkmarkCheckbox:SetHitRectInsets(0, -180, 0, 0)
    _G[checkmarkCheckbox:GetName() .. "Text"]:SetText("Checkmark on Completed Objectives")
    checkmarkCheckbox:SetChecked(UIThingsDB.tracker.completedObjectiveCheckmark)
    checkmarkCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.completedObjectiveCheckmark = self:GetChecked()
        UpdateTracker()
    end)

    local campaignCheckbox = CreateFrame("CheckButton", "UIThingsTrackerCampaignCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    campaignCheckbox:SetPoint("TOPLEFT", 20, -385)
    campaignCheckbox:SetHitRectInsets(0, -160, 0, 0)
    _G[campaignCheckbox:GetName() .. "Text"]:SetText("Highlight Campaign Quests")
    campaignCheckbox:SetChecked(UIThingsDB.tracker.highlightCampaignQuests)
    campaignCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.highlightCampaignQuests = self:GetChecked()
        UpdateTracker()
    end)

    local questTypeCheckbox = CreateFrame("CheckButton", "UIThingsTrackerQuestTypeCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    questTypeCheckbox:SetPoint("TOPLEFT", 300, -385)
    questTypeCheckbox:SetHitRectInsets(0, -180, 0, 0)
    _G[questTypeCheckbox:GetName() .. "Text"]:SetText("Show Daily/Weekly Indicators")
    questTypeCheckbox:SetChecked(UIThingsDB.tracker.showQuestTypeIndicators)
    questTypeCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.showQuestTypeIndicators = self:GetChecked()
        UpdateTracker()
    end)

    local tooltipCheckbox = CreateFrame("CheckButton", "UIThingsTrackerTooltipCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    tooltipCheckbox:SetPoint("TOPLEFT", 20, -410)
    tooltipCheckbox:SetHitRectInsets(0, -130, 0, 0)
    _G[tooltipCheckbox:GetName() .. "Text"]:SetText("Show Tooltip Preview")
    tooltipCheckbox:SetChecked(UIThingsDB.tracker.showTooltipPreview)
    tooltipCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.showTooltipPreview = self:GetChecked()
        UpdateTracker()
    end)

    -------------------------------------------------------------
    -- SECTION: Behavior (-435)
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(panel, "Behavior", -435)

    local autoTrackCheckbox = CreateFrame("CheckButton", "UIThingsTrackerAutoTrackCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    autoTrackCheckbox:SetPoint("TOPLEFT", 20, -460)
    autoTrackCheckbox:SetHitRectInsets(0, -110, 0, 0)
    _G[autoTrackCheckbox:GetName() .. "Text"]:SetText("Auto Track Quests")
    autoTrackCheckbox:SetChecked(UIThingsDB.tracker.autoTrackQuests)
    autoTrackCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.autoTrackQuests = self:GetChecked()
    end)

    local rightClickCheckbox = CreateFrame("CheckButton", "UIThingsTrackerRightClickCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    rightClickCheckbox:SetPoint("TOPLEFT", 180, -460)
    rightClickCheckbox:SetHitRectInsets(0, -130, 0, 0)
    _G[rightClickCheckbox:GetName() .. "Text"]:SetText("Right-Click: Active Quest")
    rightClickCheckbox:SetChecked(UIThingsDB.tracker.rightClickSuperTrack)
    rightClickCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.rightClickSuperTrack = self:GetChecked()
    end)

    local shiftClickCheckbox = CreateFrame("CheckButton", "UIThingsTrackerShiftClickCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    shiftClickCheckbox:SetPoint("TOPLEFT", 380, -460)
    shiftClickCheckbox:SetHitRectInsets(0, -110, 0, 0)
    _G[shiftClickCheckbox:GetName() .. "Text"]:SetText("Shift-Click: Untrack")
    shiftClickCheckbox:SetChecked(UIThingsDB.tracker.shiftClickUntrack)
    shiftClickCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.shiftClickUntrack = self:GetChecked()
    end)

    local combatHideCheckbox = CreateFrame("CheckButton", "UIThingsTrackerCombatHideCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    combatHideCheckbox:SetPoint("TOPLEFT", 20, -485)
    combatHideCheckbox:SetHitRectInsets(0, -90, 0, 0)
    _G[combatHideCheckbox:GetName() .. "Text"]:SetText("Hide in Combat")
    combatHideCheckbox:SetChecked(UIThingsDB.tracker.hideInCombat)
    combatHideCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.hideInCombat = self:GetChecked()
        UpdateTracker()
    end)

    local mplusHideCheckbox = CreateFrame("CheckButton", "UIThingsTrackerMPlusHideCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    mplusHideCheckbox:SetPoint("TOPLEFT", 180, -485)
    mplusHideCheckbox:SetHitRectInsets(0, -70, 0, 0)
    _G[mplusHideCheckbox:GetName() .. "Text"]:SetText("Hide in M+")
    mplusHideCheckbox:SetChecked(UIThingsDB.tracker.hideInMPlus)
    mplusHideCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.hideInMPlus = self:GetChecked()
        UpdateTracker()
    end)

    -------------------------------------------------------------
    -- SECTION: Sounds (-515)
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(panel, "Sounds", -515)

    local questSoundCheckbox = CreateFrame("CheckButton", "UIThingsTrackerQuestSoundCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    questSoundCheckbox:SetPoint("TOPLEFT", 20, -540)
    questSoundCheckbox:SetHitRectInsets(0, -160, 0, 0)
    _G[questSoundCheckbox:GetName() .. "Text"]:SetText("Sound on Quest Complete")
    questSoundCheckbox:SetChecked(UIThingsDB.tracker.questCompletionSound)
    questSoundCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.questCompletionSound = self:GetChecked()
    end)

    local questSoundIDLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    questSoundIDLabel:SetPoint("TOPLEFT", 20, -565)
    questSoundIDLabel:SetText("Sound ID:")

    local questSoundIDBox = CreateFrame("EditBox", "UIThingsTrackerQuestSoundIDBox", panel, "InputBoxTemplate")
    questSoundIDBox:SetSize(60, 20)
    questSoundIDBox:SetPoint("LEFT", questSoundIDLabel, "RIGHT", 8, 0)
    questSoundIDBox:SetAutoFocus(false)
    questSoundIDBox:SetNumeric(true)
    questSoundIDBox:SetMaxLetters(6)
    questSoundIDBox:SetText(tostring(UIThingsDB.tracker.questCompletionSoundID or 6199))
    questSoundIDBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val > 0 then
            UIThingsDB.tracker.questCompletionSoundID = val
        end
        self:ClearFocus()
    end)
    questSoundIDBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local questSoundTestBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    questSoundTestBtn:SetSize(40, 20)
    questSoundTestBtn:SetPoint("LEFT", questSoundIDBox, "RIGHT", 5, 0)
    questSoundTestBtn:SetText("Test")
    questSoundTestBtn:SetScript("OnClick", function()
        local val = tonumber(questSoundIDBox:GetText())
        if val and val > 0 then PlaySound(val, UIThingsDB.tracker.soundChannel or "Master") end
    end)

    local objSoundCheckbox = CreateFrame("CheckButton", "UIThingsTrackerObjSoundCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    objSoundCheckbox:SetPoint("TOPLEFT", 300, -540)
    objSoundCheckbox:SetHitRectInsets(0, -180, 0, 0)
    _G[objSoundCheckbox:GetName() .. "Text"]:SetText("Sound on Objective Complete")
    objSoundCheckbox:SetChecked(UIThingsDB.tracker.objectiveCompletionSound)
    objSoundCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.objectiveCompletionSound = self:GetChecked()
    end)

    local objSoundIDLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    objSoundIDLabel:SetPoint("TOPLEFT", 300, -565)
    objSoundIDLabel:SetText("Sound ID:")

    local objSoundIDBox = CreateFrame("EditBox", "UIThingsTrackerObjSoundIDBox", panel, "InputBoxTemplate")
    objSoundIDBox:SetSize(60, 20)
    objSoundIDBox:SetPoint("LEFT", objSoundIDLabel, "RIGHT", 8, 0)
    objSoundIDBox:SetAutoFocus(false)
    objSoundIDBox:SetNumeric(true)
    objSoundIDBox:SetMaxLetters(6)
    objSoundIDBox:SetText(tostring(UIThingsDB.tracker.objectiveCompletionSoundID or 6197))
    objSoundIDBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val > 0 then
            UIThingsDB.tracker.objectiveCompletionSoundID = val
        end
        self:ClearFocus()
    end)
    objSoundIDBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local objSoundTestBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    objSoundTestBtn:SetSize(40, 20)
    objSoundTestBtn:SetPoint("LEFT", objSoundIDBox, "RIGHT", 5, 0)
    objSoundTestBtn:SetText("Test")
    objSoundTestBtn:SetScript("OnClick", function()
        local val = tonumber(objSoundIDBox:GetText())
        if val and val > 0 then PlaySound(val, UIThingsDB.tracker.soundChannel or "Master") end
    end)

    local channelLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    channelLabel:SetPoint("TOPLEFT", 20, -590)
    channelLabel:SetText("Sound Channel:")

    local channelDropdown = CreateFrame("Frame", "UIThingsTrackerSoundChannelDropdown", panel, "UIDropDownMenuTemplate")
    channelDropdown:SetPoint("LEFT", channelLabel, "RIGHT", -5, -2)

    local channelOptions = { "Master", "SFX", "Music", "Ambience", "Dialog" }

    local function ChannelOnClick(self)
        UIDropDownMenu_SetSelectedValue(channelDropdown, self.value)
        UIThingsDB.tracker.soundChannel = self.value
    end

    local function ChannelInit(self, level)
        for _, ch in ipairs(channelOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = ch
            info.value = ch
            info.func = ChannelOnClick
            info.checked = (UIThingsDB.tracker.soundChannel == ch)
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(channelDropdown, ChannelInit)
    UIDropDownMenu_SetText(channelDropdown, UIThingsDB.tracker.soundChannel or "Master")
    UIDropDownMenu_SetWidth(channelDropdown, 90)

    local muteDefaultCheckbox = CreateFrame("CheckButton", "UIThingsTrackerMuteDefaultCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    muteDefaultCheckbox:SetPoint("TOPLEFT", 300, -590)
    muteDefaultCheckbox:SetHitRectInsets(0, -180, 0, 0)
    _G[muteDefaultCheckbox:GetName() .. "Text"]:SetText("Mute Default Quest Sounds")
    muteDefaultCheckbox:SetChecked(UIThingsDB.tracker.muteDefaultQuestSounds)
    muteDefaultCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.muteDefaultQuestSounds = self:GetChecked()
        UpdateTracker()
    end)

    -------------------------------------------------------------
    -- SECTION: Size & Position (-620)
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(panel, "Size & Position", -620)

    local widthSlider = CreateFrame("Slider", "UIThingsWidthSlider", panel, "OptionsSliderTemplate")
    widthSlider:SetPoint("TOPLEFT", 20, -655)
    widthSlider:SetMinMaxValues(100, 600)
    widthSlider:SetValueStep(10)
    widthSlider:SetObeyStepOnDrag(true)
    widthSlider:SetWidth(180)
    _G[widthSlider:GetName() .. 'Text']:SetText(string.format("Width: %d", UIThingsDB.tracker.width))
    _G[widthSlider:GetName() .. 'Low']:SetText("100")
    _G[widthSlider:GetName() .. 'High']:SetText("600")
    widthSlider:SetValue(UIThingsDB.tracker.width)
    widthSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / 10) * 10
        UIThingsDB.tracker.width = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Width: %d", value))
        UpdateTracker()
    end)

    local heightSlider = CreateFrame("Slider", "UIThingsHeightSlider", panel, "OptionsSliderTemplate")
    heightSlider:SetPoint("TOPLEFT", 230, -655)
    heightSlider:SetMinMaxValues(100, 1000)
    heightSlider:SetValueStep(10)
    heightSlider:SetObeyStepOnDrag(true)
    heightSlider:SetWidth(180)
    _G[heightSlider:GetName() .. 'Text']:SetText(string.format("Height: %d", UIThingsDB.tracker.height))
    _G[heightSlider:GetName() .. 'Low']:SetText("100")
    _G[heightSlider:GetName() .. 'High']:SetText("1000")
    heightSlider:SetValue(UIThingsDB.tracker.height)
    heightSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / 10) * 10
        UIThingsDB.tracker.height = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Height: %d", value))
        UpdateTracker()
    end)

    local paddingSlider = CreateFrame("Slider", "UIThingsTrackerPaddingSlider", panel, "OptionsSliderTemplate")
    paddingSlider:SetPoint("TOPLEFT", 440, -655)
    paddingSlider:SetMinMaxValues(0, 20)
    paddingSlider:SetValueStep(1)
    paddingSlider:SetObeyStepOnDrag(true)
    paddingSlider:SetWidth(120)
    _G[paddingSlider:GetName() .. 'Text']:SetText(string.format("Padding: %d", UIThingsDB.tracker.questPadding))
    _G[paddingSlider:GetName() .. 'Low']:SetText("0")
    _G[paddingSlider:GetName() .. 'High']:SetText("20")
    paddingSlider:SetValue(UIThingsDB.tracker.questPadding)
    paddingSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.tracker.questPadding = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Padding: %d", value))
        UpdateTracker()
    end)

    local trackerStrataLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    trackerStrataLabel:SetPoint("TOPLEFT", 20, -690)
    trackerStrataLabel:SetText("Strata:")

    local trackerStrataDropdown = CreateFrame("Frame", "UIThingsTrackerStrataDropdown", panel,
        "UIDropDownMenuTemplate")
    trackerStrataDropdown:SetPoint("TOPLEFT", trackerStrataLabel, "BOTTOMLEFT", -15, -5)

    local function TrackerStrataOnClick(self)
        UIDropDownMenu_SetSelectedID(trackerStrataDropdown, self:GetID())
        UIThingsDB.tracker.strata = self.value
        UpdateTracker()
    end

    local function TrackerStrataInit(self, level)
        local stratas = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "TOOLTIP" }
        for _, s in ipairs(stratas) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = s
            info.value = s
            info.func = TrackerStrataOnClick
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(trackerStrataDropdown, TrackerStrataInit)
    UIDropDownMenu_SetText(trackerStrataDropdown, UIThingsDB.tracker.strata or "LOW")

    -------------------------------------------------------------
    -- SECTION: Fonts (-745)
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(panel, "Fonts", -745)

    Helpers.CreateFontDropdown(
        panel,
        "UIThingsTrackerHeaderFontDropdown",
        "Quest Name Font:",
        UIThingsDB.tracker.headerFont,
        function(fontPath, fontName)
            UIThingsDB.tracker.headerFont = fontPath
            UpdateTracker()
        end,
        20,
        -770
    )

    local headerSizeSlider = CreateFrame("Slider", "UIThingsTrackerHeaderSizeSlider", panel,
        "OptionsSliderTemplate")
    headerSizeSlider:SetPoint("TOPLEFT", 20, -835)
    headerSizeSlider:SetMinMaxValues(8, 32)
    headerSizeSlider:SetValueStep(1)
    headerSizeSlider:SetObeyStepOnDrag(true)
    headerSizeSlider:SetWidth(150)
    _G[headerSizeSlider:GetName() .. 'Text']:SetText(string.format("Size: %d", UIThingsDB.tracker.headerFontSize))
    _G[headerSizeSlider:GetName() .. 'Low']:SetText("8")
    _G[headerSizeSlider:GetName() .. 'High']:SetText("32")
    headerSizeSlider:SetValue(UIThingsDB.tracker.headerFontSize)
    headerSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.tracker.headerFontSize = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Size: %d", value))
        UpdateTracker()
    end)

    Helpers.CreateFontDropdown(
        panel,
        "UIThingsTrackerDetailFontDropdown",
        "Quest Detail Font:",
        UIThingsDB.tracker.detailFont,
        function(fontPath, fontName)
            UIThingsDB.tracker.detailFont = fontPath
            UpdateTracker()
        end,
        250,
        -770
    )

    local detailSizeSlider = CreateFrame("Slider", "UIThingsTrackerDetailSizeSlider", panel,
        "OptionsSliderTemplate")
    detailSizeSlider:SetPoint("TOPLEFT", 250, -835)
    detailSizeSlider:SetMinMaxValues(8, 32)
    detailSizeSlider:SetValueStep(1)
    detailSizeSlider:SetObeyStepOnDrag(true)
    detailSizeSlider:SetWidth(150)
    _G[detailSizeSlider:GetName() .. 'Text']:SetText(string.format("Size: %d", UIThingsDB.tracker.detailFontSize))
    _G[detailSizeSlider:GetName() .. 'Low']:SetText("8")
    _G[detailSizeSlider:GetName() .. 'High']:SetText("32")
    detailSizeSlider:SetValue(UIThingsDB.tracker.detailFontSize)
    detailSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.tracker.detailFontSize = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Size: %d", value))
        UpdateTracker()
    end)

    Helpers.CreateFontDropdown(
        panel,
        "UIThingsTrackerSectionFontDropdown",
        "Section Header Font:",
        UIThingsDB.tracker.sectionHeaderFont,
        function(fontPath, fontName)
            UIThingsDB.tracker.sectionHeaderFont = fontPath
            UpdateTracker()
        end,
        20,
        -870
    )

    local sectionSizeSlider = CreateFrame("Slider", "UIThingsTrackerSectionSizeSlider", panel,
        "OptionsSliderTemplate")
    sectionSizeSlider:SetPoint("TOPLEFT", 20, -935)
    sectionSizeSlider:SetMinMaxValues(8, 32)
    sectionSizeSlider:SetValueStep(1)
    sectionSizeSlider:SetObeyStepOnDrag(true)
    sectionSizeSlider:SetWidth(150)
    _G[sectionSizeSlider:GetName() .. 'Text']:SetText(string.format("Size: %d", UIThingsDB.tracker.sectionHeaderFontSize))
    _G[sectionSizeSlider:GetName() .. 'Low']:SetText("8")
    _G[sectionSizeSlider:GetName() .. 'High']:SetText("32")
    sectionSizeSlider:SetValue(UIThingsDB.tracker.sectionHeaderFontSize)
    sectionSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.tracker.sectionHeaderFontSize = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Size: %d", value))
        UpdateTracker()
    end)

    -------------------------------------------------------------
    -- SECTION: Colors (-965)
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(panel, "Colors", -965)

    -- Row 1: Section Header, Active Quest, Campaign
    local sectionColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sectionColorLabel:SetPoint("TOPLEFT", 20, -993)
    sectionColorLabel:SetText("Section Header:")

    local sectionColorSwatch = CreateFrame("Button", nil, panel)
    sectionColorSwatch:SetSize(20, 20)
    sectionColorSwatch:SetPoint("LEFT", sectionColorLabel, "RIGHT", 5, 0)

    sectionColorSwatch.tex = sectionColorSwatch:CreateTexture(nil, "OVERLAY")
    sectionColorSwatch.tex:SetAllPoints()
    local shc = UIThingsDB.tracker.sectionHeaderColor or { r = 1, g = 0.82, b = 0, a = 1 }
    sectionColorSwatch.tex:SetColorTexture(shc.r, shc.g, shc.b, shc.a)

    Mixin(sectionColorSwatch, BackdropTemplateMixin)
    sectionColorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    sectionColorSwatch:SetBackdropBorderColor(1, 1, 1)

    sectionColorSwatch:SetScript("OnClick", function(self)
        local info = UIDropDownMenu_CreateInfo()
        local prevR, prevG, prevB, prevA = shc.r, shc.g, shc.b, shc.a
        info.r, info.g, info.b, info.opacity = prevR, prevG, prevB, prevA
        info.hasOpacity = true
        info.opacityFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            shc.r, shc.g, shc.b, shc.a = r, g, b, a
            sectionColorSwatch.tex:SetColorTexture(r, g, b, a)
            UIThingsDB.tracker.sectionHeaderColor = shc
            UpdateTracker()
        end
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            shc.r, shc.g, shc.b, shc.a = r, g, b, a
            sectionColorSwatch.tex:SetColorTexture(r, g, b, a)
            UIThingsDB.tracker.sectionHeaderColor = shc
            UpdateTracker()
        end
        info.cancelFunc = function(previousValues)
            shc.r, shc.g, shc.b, shc.a = prevR, prevG, prevB, prevA
            sectionColorSwatch.tex:SetColorTexture(shc.r, shc.g, shc.b, shc.a)
            UIThingsDB.tracker.sectionHeaderColor = shc
            UpdateTracker()
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    local activeColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    activeColorLabel:SetPoint("TOPLEFT", 200, -993)
    activeColorLabel:SetText("Active Quest:")

    local activeColorSwatch = CreateFrame("Button", nil, panel)
    activeColorSwatch:SetSize(20, 20)
    activeColorSwatch:SetPoint("LEFT", activeColorLabel, "RIGHT", 10, 0)

    activeColorSwatch.tex = activeColorSwatch:CreateTexture(nil, "OVERLAY")
    activeColorSwatch.tex:SetAllPoints()
    local ac = UIThingsDB.tracker.activeQuestColor or { r = 0, g = 1, b = 0, a = 1 }
    activeColorSwatch.tex:SetColorTexture(ac.r, ac.g, ac.b, ac.a)

    Mixin(activeColorSwatch, BackdropTemplateMixin)
    activeColorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    activeColorSwatch:SetBackdropBorderColor(1, 1, 1)

    activeColorSwatch:SetScript("OnClick", function(self)
        local info = UIDropDownMenu_CreateInfo()
        local prevR, prevG, prevB, prevA = ac.r, ac.g, ac.b, ac.a
        info.r, info.g, info.b, info.opacity = prevR, prevG, prevB, prevA
        info.hasOpacity = true
        info.opacityFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            ac.r, ac.g, ac.b, ac.a = r, g, b, a
            activeColorSwatch.tex:SetColorTexture(r, g, b, a)
            UIThingsDB.tracker.activeQuestColor = ac
            UpdateTracker()
        end
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            ac.r, ac.g, ac.b, ac.a = r, g, b, a
            activeColorSwatch.tex:SetColorTexture(r, g, b, a)
            UIThingsDB.tracker.activeQuestColor = ac
            UpdateTracker()
        end
        info.cancelFunc = function(previousValues)
            ac.r, ac.g, ac.b, ac.a = prevR, prevG, prevB, prevA
            activeColorSwatch.tex:SetColorTexture(ac.r, ac.g, ac.b, ac.a)
            UIThingsDB.tracker.activeQuestColor = ac
            UpdateTracker()
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    local campaignColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    campaignColorLabel:SetPoint("TOPLEFT", 380, -993)
    campaignColorLabel:SetText("Campaign:")

    local cqc = UIThingsDB.tracker.campaignQuestColor or { r = 0.9, g = 0.7, b = 0.2, a = 1 }
    local campaignColorSwatch = CreateFrame("Button", nil, panel)
    campaignColorSwatch:SetSize(20, 20)
    campaignColorSwatch:SetPoint("LEFT", campaignColorLabel, "RIGHT", 10, 0)
    campaignColorSwatch.tex = campaignColorSwatch:CreateTexture(nil, "OVERLAY")
    campaignColorSwatch.tex:SetAllPoints()
    campaignColorSwatch.tex:SetColorTexture(cqc.r, cqc.g, cqc.b, cqc.a)
    Mixin(campaignColorSwatch, BackdropTemplateMixin)
    campaignColorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    campaignColorSwatch:SetBackdropBorderColor(1, 1, 1)
    campaignColorSwatch:SetScript("OnClick", function(self)
        local info = UIDropDownMenu_CreateInfo()
        local prevR, prevG, prevB, prevA = cqc.r, cqc.g, cqc.b, cqc.a
        info.r, info.g, info.b, info.opacity = prevR, prevG, prevB, prevA
        info.hasOpacity = true
        local function applyColor()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            cqc.r, cqc.g, cqc.b, cqc.a = r, g, b, a
            campaignColorSwatch.tex:SetColorTexture(r, g, b, a)
            UIThingsDB.tracker.campaignQuestColor = cqc
            UpdateTracker()
        end
        info.opacityFunc = applyColor
        info.swatchFunc = applyColor
        info.cancelFunc = function()
            cqc.r, cqc.g, cqc.b, cqc.a = prevR, prevG, prevB, prevA
            campaignColorSwatch.tex:SetColorTexture(cqc.r, cqc.g, cqc.b, cqc.a)
            UIThingsDB.tracker.campaignQuestColor = cqc
            UpdateTracker()
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    -- Row 2: Quest Name, Objective
    local questNameColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    questNameColorLabel:SetPoint("TOPLEFT", 20, -1018)
    questNameColorLabel:SetText("Quest Name:")

    local qnc = UIThingsDB.tracker.questNameColor or { r = 1, g = 1, b = 1, a = 1 }
    local questNameColorSwatch = CreateFrame("Button", nil, panel)
    questNameColorSwatch:SetSize(20, 20)
    questNameColorSwatch:SetPoint("LEFT", questNameColorLabel, "RIGHT", 10, 0)
    questNameColorSwatch.tex = questNameColorSwatch:CreateTexture(nil, "OVERLAY")
    questNameColorSwatch.tex:SetAllPoints()
    questNameColorSwatch.tex:SetColorTexture(qnc.r, qnc.g, qnc.b, qnc.a)
    Mixin(questNameColorSwatch, BackdropTemplateMixin)
    questNameColorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    questNameColorSwatch:SetBackdropBorderColor(1, 1, 1)
    questNameColorSwatch:SetScript("OnClick", function(self)
        local info = UIDropDownMenu_CreateInfo()
        local prevR, prevG, prevB, prevA = qnc.r, qnc.g, qnc.b, qnc.a
        info.r, info.g, info.b, info.opacity = prevR, prevG, prevB, prevA
        info.hasOpacity = true
        local function applyColor()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            qnc.r, qnc.g, qnc.b, qnc.a = r, g, b, a
            questNameColorSwatch.tex:SetColorTexture(r, g, b, a)
            UIThingsDB.tracker.questNameColor = qnc
            UpdateTracker()
        end
        info.opacityFunc = applyColor
        info.swatchFunc = applyColor
        info.cancelFunc = function()
            qnc.r, qnc.g, qnc.b, qnc.a = prevR, prevG, prevB, prevA
            questNameColorSwatch.tex:SetColorTexture(qnc.r, qnc.g, qnc.b, qnc.a)
            UIThingsDB.tracker.questNameColor = qnc
            UpdateTracker()
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    local objColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    objColorLabel:SetPoint("TOPLEFT", 200, -1018)
    objColorLabel:SetText("Objective:")

    local occ = UIThingsDB.tracker.objectiveColor or { r = 0.8, g = 0.8, b = 0.8, a = 1 }
    local objColorSwatch = CreateFrame("Button", nil, panel)
    objColorSwatch:SetSize(20, 20)
    objColorSwatch:SetPoint("LEFT", objColorLabel, "RIGHT", 10, 0)
    objColorSwatch.tex = objColorSwatch:CreateTexture(nil, "OVERLAY")
    objColorSwatch.tex:SetAllPoints()
    objColorSwatch.tex:SetColorTexture(occ.r, occ.g, occ.b, occ.a)
    Mixin(objColorSwatch, BackdropTemplateMixin)
    objColorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    objColorSwatch:SetBackdropBorderColor(1, 1, 1)
    objColorSwatch:SetScript("OnClick", function(self)
        local info = UIDropDownMenu_CreateInfo()
        local prevR, prevG, prevB, prevA = occ.r, occ.g, occ.b, occ.a
        info.r, info.g, info.b, info.opacity = prevR, prevG, prevB, prevA
        info.hasOpacity = true
        local function applyColor()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            occ.r, occ.g, occ.b, occ.a = r, g, b, a
            objColorSwatch.tex:SetColorTexture(r, g, b, a)
            UIThingsDB.tracker.objectiveColor = occ
            UpdateTracker()
        end
        info.opacityFunc = applyColor
        info.swatchFunc = applyColor
        info.cancelFunc = function()
            occ.r, occ.g, occ.b, occ.a = prevR, prevG, prevB, prevA
            objColorSwatch.tex:SetColorTexture(occ.r, occ.g, occ.b, occ.a)
            UIThingsDB.tracker.objectiveColor = occ
            UpdateTracker()
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    -- Row 3: Border + color, Background + color
    local borderCheckbox = CreateFrame("CheckButton", "UIThingsTrackerBorderCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    borderCheckbox:SetPoint("TOPLEFT", 20, -1045)
    borderCheckbox:SetHitRectInsets(0, -80, 0, 0)
    _G[borderCheckbox:GetName() .. "Text"]:SetText("Show Border")
    borderCheckbox:SetChecked(UIThingsDB.tracker.showBorder)
    borderCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.showBorder = self:GetChecked()
        UpdateTracker()
    end)

    local borderColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    borderColorLabel:SetPoint("TOPLEFT", 140, -1048)
    borderColorLabel:SetText("Color:")

    local borderColorSwatch = CreateFrame("Button", nil, panel)
    borderColorSwatch:SetSize(20, 20)
    borderColorSwatch:SetPoint("LEFT", borderColorLabel, "RIGHT", 5, 0)

    borderColorSwatch.tex = borderColorSwatch:CreateTexture(nil, "OVERLAY")
    borderColorSwatch.tex:SetAllPoints()
    local bc = UIThingsDB.tracker.borderColor or { r = 0, g = 0, b = 0, a = 1 }
    borderColorSwatch.tex:SetColorTexture(bc.r, bc.g, bc.b, bc.a)

    Mixin(borderColorSwatch, BackdropTemplateMixin)
    borderColorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    borderColorSwatch:SetBackdropBorderColor(1, 1, 1)

    borderColorSwatch:SetScript("OnClick", function(self)
        local info = UIDropDownMenu_CreateInfo()
        local prevR, prevG, prevB, prevA = bc.r, bc.g, bc.b, bc.a
        info.r, info.g, info.b, info.opacity = prevR, prevG, prevB, prevA
        info.hasOpacity = true
        info.opacityFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            bc.r, bc.g, bc.b, bc.a = r, g, b, a
            borderColorSwatch.tex:SetColorTexture(r, g, b, a)
            UIThingsDB.tracker.borderColor = bc
            UpdateTracker()
        end
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            bc.r, bc.g, bc.b, bc.a = r, g, b, a
            borderColorSwatch.tex:SetColorTexture(r, g, b, a)
            UIThingsDB.tracker.borderColor = bc
            UpdateTracker()
        end
        info.cancelFunc = function(previousValues)
            bc.r, bc.g, bc.b, bc.a = prevR, prevG, prevB, prevA
            borderColorSwatch.tex:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
            UIThingsDB.tracker.borderColor = bc
            UpdateTracker()
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    local bgCheckbox = CreateFrame("CheckButton", "UIThingsTrackerBgCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    bgCheckbox:SetPoint("TOPLEFT", 300, -1045)
    bgCheckbox:SetHitRectInsets(0, -110, 0, 0)
    _G[bgCheckbox:GetName() .. "Text"]:SetText("Show Background")
    bgCheckbox:SetChecked(UIThingsDB.tracker.showBackground)
    bgCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.showBackground = self:GetChecked()
        UpdateTracker()
    end)

    local bgColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bgColorLabel:SetPoint("TOPLEFT", 440, -1048)
    bgColorLabel:SetText("Color:")

    local bgColorSwatch = CreateFrame("Button", nil, panel)
    bgColorSwatch:SetSize(20, 20)
    bgColorSwatch:SetPoint("LEFT", bgColorLabel, "RIGHT", 5, 0)

    bgColorSwatch.tex = bgColorSwatch:CreateTexture(nil, "OVERLAY")
    bgColorSwatch.tex:SetAllPoints()
    local c = UIThingsDB.tracker.backgroundColor or { r = 0, g = 0, b = 0, a = 0.5 }
    bgColorSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)

    Mixin(bgColorSwatch, BackdropTemplateMixin)
    bgColorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    bgColorSwatch:SetBackdropBorderColor(1, 1, 1)

    bgColorSwatch:SetScript("OnClick", function(self)
        local info = UIDropDownMenu_CreateInfo()
        local prevR, prevG, prevB, prevA = c.r, c.g, c.b, c.a
        info.r, info.g, info.b, info.opacity = prevR, prevG, prevB, prevA
        info.hasOpacity = true
        info.opacityFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            c.r, c.g, c.b, c.a = r, g, b, a
            bgColorSwatch.tex:SetColorTexture(r, g, b, a)
            UIThingsDB.tracker.backgroundColor = c
            UpdateTracker()
        end
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            c.r, c.g, c.b, c.a = r, g, b, a
            bgColorSwatch.tex:SetColorTexture(r, g, b, a)
            UIThingsDB.tracker.backgroundColor = c
            UpdateTracker()
        end
        info.cancelFunc = function(previousValues)
            c.r, c.g, c.b, c.a = prevR, prevG, prevB, prevA
            bgColorSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
            UIThingsDB.tracker.backgroundColor = c
            UpdateTracker()
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)
end
