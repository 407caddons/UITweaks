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
    scrollChild:SetSize(560, 700) -- Fixed width and tall enough for all settings
    scrollFrame:SetScrollChild(scrollChild)

    -- Update panel reference to scrollChild for all child elements
    panel = scrollChild

    -------------------------------------------------------------
    -- SECTION: General
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(panel, "General", -10)

    -- Enable Tracker Checkbox
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

    -- Lock Checkbox
    local lockBtn = CreateFrame("CheckButton", "UIThingsLockCheck", panel, "ChatConfigCheckButtonTemplate")
    lockBtn:SetPoint("TOPLEFT", 250, -40)
    _G[lockBtn:GetName() .. "Text"]:SetText("Lock Position")
    lockBtn:SetChecked(UIThingsDB.tracker.locked)
    lockBtn:SetScript("OnClick", function(self)
        local locked = not not self:GetChecked()
        UIThingsDB.tracker.locked = locked
        UpdateTracker()
    end)

    -------------------------------------------------------------
    -- SECTION: Size & Position
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(panel, "Size & Position", -70)

    -- Width Slider
    local widthSlider = CreateFrame("Slider", "UIThingsWidthSlider", panel, "OptionsSliderTemplate")
    widthSlider:SetPoint("TOPLEFT", 20, -105)
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

    -- Height Slider
    local heightSlider = CreateFrame("Slider", "UIThingsHeightSlider", panel, "OptionsSliderTemplate")
    heightSlider:SetPoint("TOPLEFT", 230, -105)
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

    -- Quest Padding Slider
    local paddingSlider = CreateFrame("Slider", "UIThingsTrackerPaddingSlider", panel, "OptionsSliderTemplate")
    paddingSlider:SetPoint("TOPLEFT", 440, -105)
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

    -- Strata Dropdown
    local trackerStrataLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    trackerStrataLabel:SetPoint("TOPLEFT", 20, -140)
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
    -- SECTION: Fonts
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(panel, "Fonts", -195)

    -- Quest Name Font
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
        -220
    )

    -- Quest Name Size (under font dropdown)
    local headerSizeSlider = CreateFrame("Slider", "UIThingsTrackerHeaderSizeSlider", panel,
        "OptionsSliderTemplate")
    headerSizeSlider:SetPoint("TOPLEFT", 20, -285)
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

    -- Quest Detail Font
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
        -220
    )

    -- Quest Detail Size (under font dropdown)
    local detailSizeSlider = CreateFrame("Slider", "UIThingsTrackerDetailSizeSlider", panel,
        "OptionsSliderTemplate")
    detailSizeSlider:SetPoint("TOPLEFT", 250, -285)
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

    -------------------------------------------------------------
    -- SECTION: Content
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(panel, "Content", -325)

    -- Section Order - Reorderable List
    local orderLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    orderLabel:SetPoint("TOPLEFT", 20, -350)
    orderLabel:SetText("Section Order: (top to bottom)")

    -- Initialize default order if not exists
    if not UIThingsDB.tracker.sectionOrderList then
        UIThingsDB.tracker.sectionOrderList = {
            "scenarios",
            "tempObjectives",
            "worldQuests",
            "quests",
            "achievements"
        }
    end

    local sectionNames = {
        scenarios = "Scenarios",
        tempObjectives = "Temporary Objectives",
        worldQuests = "World Quests",
        quests = "Quests",
        achievements = "Achievements"
    }

    local orderItems = {}
    local yPos = -375

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

    for i = 1, 5 do
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

    -- Only Show Active World Quests Checkbox
    local wqActiveCheckbox = CreateFrame("CheckButton", "UIThingsTrackerWQActiveCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    wqActiveCheckbox:SetPoint("TOPLEFT", 300, -350)
    wqActiveCheckbox:SetHitRectInsets(0, -130, 0, 0)
    _G[wqActiveCheckbox:GetName() .. "Text"]:SetText("Only Active World Quests")
    wqActiveCheckbox:SetChecked(UIThingsDB.tracker.onlyActiveWorldQuests)
    wqActiveCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.onlyActiveWorldQuests = self:GetChecked()
        UpdateTracker()
    end)

    -- Show World Quest Timer Checkbox
    local wqTimerCheckbox = CreateFrame("CheckButton", "UIThingsTrackerWQTimerCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    wqTimerCheckbox:SetPoint("TOPLEFT", 300, -375)
    wqTimerCheckbox:SetHitRectInsets(0, -130, 0, 0)
    _G[wqTimerCheckbox:GetName() .. "Text"]:SetText("Show World Quest Timer")
    wqTimerCheckbox:SetChecked(UIThingsDB.tracker.showWorldQuestTimer)
    wqTimerCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.showWorldQuestTimer = self:GetChecked()
        UpdateTracker()
    end)

    -- Hide Completed Subtasks Checkbox
    local hideCompletedCheckbox = CreateFrame("CheckButton", "UIThingsTrackerHideCompletedCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    hideCompletedCheckbox:SetPoint("TOPLEFT", 300, -400)
    hideCompletedCheckbox:SetHitRectInsets(0, -130, 0, 0)
    _G[hideCompletedCheckbox:GetName() .. "Text"]:SetText("Hide Completed Subtasks")
    hideCompletedCheckbox:SetChecked(UIThingsDB.tracker.hideCompletedSubtasks)
    hideCompletedCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.hideCompletedSubtasks = self:GetChecked()
        UpdateTracker()
    end)

    -------------------------------------------------------------
    -- SECTION: Behavior
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(panel, "Behavior", -515)

    -- Auto Track Quests Checkbox
    local autoTrackCheckbox = CreateFrame("CheckButton", "UIThingsTrackerAutoTrackCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    autoTrackCheckbox:SetPoint("TOPLEFT", 20, -540)
    autoTrackCheckbox:SetHitRectInsets(0, -110, 0, 0)
    _G[autoTrackCheckbox:GetName() .. "Text"]:SetText("Auto Track Quests")
    autoTrackCheckbox:SetChecked(UIThingsDB.tracker.autoTrackQuests)
    autoTrackCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.autoTrackQuests = self:GetChecked()
    end)

    -- Right-Click Active Quest Checkbox
    local rightClickCheckbox = CreateFrame("CheckButton", "UIThingsTrackerRightClickCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    rightClickCheckbox:SetPoint("TOPLEFT", 180, -540)
    rightClickCheckbox:SetHitRectInsets(0, -130, 0, 0)
    _G[rightClickCheckbox:GetName() .. "Text"]:SetText("Right-Click: Active Quest")
    rightClickCheckbox:SetChecked(UIThingsDB.tracker.rightClickSuperTrack)
    rightClickCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.rightClickSuperTrack = self:GetChecked()
    end)

    -- Shift-Click Untrack Checkbox
    local shiftClickCheckbox = CreateFrame("CheckButton", "UIThingsTrackerShiftClickCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    shiftClickCheckbox:SetPoint("TOPLEFT", 380, -540)
    shiftClickCheckbox:SetHitRectInsets(0, -110, 0, 0)
    _G[shiftClickCheckbox:GetName() .. "Text"]:SetText("Shift-Click: Untrack")
    shiftClickCheckbox:SetChecked(UIThingsDB.tracker.shiftClickUntrack)
    shiftClickCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.shiftClickUntrack = self:GetChecked()
    end)

    -- Hide In Combat Checkbox
    local combatHideCheckbox = CreateFrame("CheckButton", "UIThingsTrackerCombatHideCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    combatHideCheckbox:SetPoint("TOPLEFT", 20, -565)
    combatHideCheckbox:SetHitRectInsets(0, -90, 0, 0)
    _G[combatHideCheckbox:GetName() .. "Text"]:SetText("Hide in Combat")
    combatHideCheckbox:SetChecked(UIThingsDB.tracker.hideInCombat)
    combatHideCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.hideInCombat = self:GetChecked()
        UpdateTracker()
    end)

    -- Hide In M+ Checkbox
    local mplusHideCheckbox = CreateFrame("CheckButton", "UIThingsTrackerMPlusHideCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    mplusHideCheckbox:SetPoint("TOPLEFT", 180, -565)
    mplusHideCheckbox:SetHitRectInsets(0, -70, 0, 0)
    _G[mplusHideCheckbox:GetName() .. "Text"]:SetText("Hide in M+")
    mplusHideCheckbox:SetChecked(UIThingsDB.tracker.hideInMPlus)
    mplusHideCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.hideInMPlus = self:GetChecked()
        UpdateTracker()
    end)

    -------------------------------------------------------------
    -- SECTION: Appearance
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(panel, "Appearance", -600)

    -- Row 1: Border
    local borderCheckbox = CreateFrame("CheckButton", "UIThingsTrackerBorderCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    borderCheckbox:SetPoint("TOPLEFT", 20, -625)
    borderCheckbox:SetHitRectInsets(0, -80, 0, 0)
    _G[borderCheckbox:GetName() .. "Text"]:SetText("Show Border")
    borderCheckbox:SetChecked(UIThingsDB.tracker.showBorder)
    borderCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.showBorder = self:GetChecked()
        UpdateTracker()
    end)

    local borderColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    borderColorLabel:SetPoint("TOPLEFT", 140, -628)
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

    -- Row 2: Background
    local bgCheckbox = CreateFrame("CheckButton", "UIThingsTrackerBgCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    bgCheckbox:SetPoint("TOPLEFT", 20, -650)
    bgCheckbox:SetHitRectInsets(0, -110, 0, 0)
    _G[bgCheckbox:GetName() .. "Text"]:SetText("Show Background")
    bgCheckbox:SetChecked(UIThingsDB.tracker.showBackground)
    bgCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.showBackground = self:GetChecked()
        UpdateTracker()
    end)

    local bgColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bgColorLabel:SetPoint("TOPLEFT", 165, -653)
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

    -- Row 3: Active Quest Color
    local activeColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    activeColorLabel:SetPoint("TOPLEFT", 20, -678)
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
end
