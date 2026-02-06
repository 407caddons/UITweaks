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

    -------------------------------------------------------------
    -- SECTION: General
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(panel, "General", -45)

    -- Enable Tracker Checkbox
    local enableTrackerBtn = CreateFrame("CheckButton", "UIThingsTrackerEnableCheck", panel,
        "ChatConfigCheckButtonTemplate")
    enableTrackerBtn:SetPoint("TOPLEFT", 20, -70)
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
    lockBtn:SetPoint("TOPLEFT", 250, -70)
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
    Helpers.CreateSectionHeader(panel, "Size & Position", -100)

    -- Width Slider
    local widthSlider = CreateFrame("Slider", "UIThingsWidthSlider", panel, "OptionsSliderTemplate")
    widthSlider:SetPoint("TOPLEFT", 20, -135)
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
    heightSlider:SetPoint("TOPLEFT", 230, -135)
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
    paddingSlider:SetPoint("TOPLEFT", 440, -135)
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
    trackerStrataLabel:SetPoint("TOPLEFT", 20, -170)
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
    Helpers.CreateSectionHeader(panel, "Fonts", -225)

    -- Helper for Font Dropdowns
    local function CreateFontDropdown(parent, variableKey, labelText, xOffset, yOffset)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("TOPLEFT", xOffset, yOffset)
        label:SetText(labelText)

        local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -15, -5)

        local function OnClick(self)
            UIDropDownMenu_SetSelectedID(dropdown, self:GetID())
            UIThingsDB.tracker[variableKey] = self.value
            UpdateTracker()
        end

        local function Init(self, level)
            for k, v in pairs(fonts) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = v.name
                info.value = v.path
                info.func = OnClick
                UIDropDownMenu_AddButton(info, level)
            end
        end

        UIDropDownMenu_Initialize(dropdown, Init)
        UIDropDownMenu_SetText(dropdown, "Select Font")
        local currentPath = UIThingsDB.tracker[variableKey]
        for _, f in ipairs(fonts) do
            if f.path == currentPath then
                UIDropDownMenu_SetText(dropdown, f.name)
                break
            end
        end

        return dropdown
    end

    -- Quest Name Font
    local headerFontDropdown = CreateFontDropdown(panel, "headerFont", "Quest Name Font:", 20, -250)

    -- Quest Name Size (under font dropdown)
    local headerSizeSlider = CreateFrame("Slider", "UIThingsTrackerHeaderSizeSlider", panel,
        "OptionsSliderTemplate")
    headerSizeSlider:SetPoint("TOPLEFT", 20, -315)
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
    local detailFontDropdown = CreateFontDropdown(panel, "detailFont", "Quest Detail Font:", 250, -250)

    -- Quest Detail Size (under font dropdown)
    local detailSizeSlider = CreateFrame("Slider", "UIThingsTrackerDetailSizeSlider", panel,
        "OptionsSliderTemplate")
    detailSizeSlider:SetPoint("TOPLEFT", 250, -315)
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
    Helpers.CreateSectionHeader(panel, "Content", -355)

    -- Section Order Dropdown
    local orderLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    orderLabel:SetPoint("TOPLEFT", 20, -380)
    orderLabel:SetText("Section Order:")

    local orderDropdown = CreateFrame("Frame", "UIThingsTrackerOrderDropdown", panel, "UIDropDownMenuTemplate")
    orderDropdown:SetPoint("TOPLEFT", orderLabel, "BOTTOMLEFT", -15, -5)

    local function OrderOnClick(self)
        UIDropDownMenu_SetSelectedID(orderDropdown, self:GetID())
        UIThingsDB.tracker.sectionOrder = self.value
        UpdateTracker()
    end

    local function OrderInit(self, level)
        local orders = {
            { text = "MWQ -> Quests -> Achv", value = 1 },
            { text = "MWQ -> Achv -> Quests", value = 2 },
            { text = "Quests -> MWQ -> Achv", value = 3 },
            { text = "Quests -> Achv -> MWQ", value = 4 },
            { text = "Achv -> MWQ -> Quests", value = 5 },
            { text = "Achv -> Quests -> MWQ", value = 6 },
        }
        for _, info in ipairs(orders) do
            local i = UIDropDownMenu_CreateInfo()
            i.text = info.text
            i.value = info.value
            i.func = OrderOnClick
            UIDropDownMenu_AddButton(i, level)
        end
    end

    UIDropDownMenu_Initialize(orderDropdown, OrderInit)
    UIDropDownMenu_SetWidth(orderDropdown, 180)
    UIDropDownMenu_SetSelectedValue(orderDropdown, UIThingsDB.tracker.sectionOrder or 1)
    UIDropDownMenu_SetText(orderDropdown, "World Quests -> Quests -> Achievements")

    -- Only Show Active World Quests Checkbox
    local wqActiveCheckbox = CreateFrame("CheckButton", "UIThingsTrackerWQActiveCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    wqActiveCheckbox:SetPoint("TOPLEFT", 250, -400)
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
    wqTimerCheckbox:SetPoint("TOPLEFT", 20, -425)
    wqTimerCheckbox:SetHitRectInsets(0, -130, 0, 0)
    _G[wqTimerCheckbox:GetName() .. "Text"]:SetText("Show World Quest Timer")
    wqTimerCheckbox:SetChecked(UIThingsDB.tracker.showWorldQuestTimer)
    wqTimerCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.showWorldQuestTimer = self:GetChecked()
        UpdateTracker()
    end)

    -------------------------------------------------------------
    -- SECTION: Behavior
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(panel, "Behavior", -450)

    -- Auto Track Quests Checkbox
    local autoTrackCheckbox = CreateFrame("CheckButton", "UIThingsTrackerAutoTrackCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    autoTrackCheckbox:SetPoint("TOPLEFT", 20, -475)
    autoTrackCheckbox:SetHitRectInsets(0, -110, 0, 0)
    _G[autoTrackCheckbox:GetName() .. "Text"]:SetText("Auto Track Quests")
    autoTrackCheckbox:SetChecked(UIThingsDB.tracker.autoTrackQuests)
    autoTrackCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.autoTrackQuests = self:GetChecked()
    end)

    -- Right-Click Active Quest Checkbox
    local rightClickCheckbox = CreateFrame("CheckButton", "UIThingsTrackerRightClickCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    rightClickCheckbox:SetPoint("TOPLEFT", 180, -475)
    rightClickCheckbox:SetHitRectInsets(0, -130, 0, 0)
    _G[rightClickCheckbox:GetName() .. "Text"]:SetText("Right-Click: Active Quest")
    rightClickCheckbox:SetChecked(UIThingsDB.tracker.rightClickSuperTrack)
    rightClickCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.rightClickSuperTrack = self:GetChecked()
    end)

    -- Shift-Click Untrack Checkbox
    local shiftClickCheckbox = CreateFrame("CheckButton", "UIThingsTrackerShiftClickCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    shiftClickCheckbox:SetPoint("TOPLEFT", 380, -475)
    shiftClickCheckbox:SetHitRectInsets(0, -110, 0, 0)
    _G[shiftClickCheckbox:GetName() .. "Text"]:SetText("Shift-Click: Untrack")
    shiftClickCheckbox:SetChecked(UIThingsDB.tracker.shiftClickUntrack)
    shiftClickCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.shiftClickUntrack = self:GetChecked()
    end)

    -- Hide In Combat Checkbox
    local combatHideCheckbox = CreateFrame("CheckButton", "UIThingsTrackerCombatHideCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    combatHideCheckbox:SetPoint("TOPLEFT", 20, -500)
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
    mplusHideCheckbox:SetPoint("TOPLEFT", 180, -500)
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
    Helpers.CreateSectionHeader(panel, "Appearance", -535)

    -- Row 1: Border
    local borderCheckbox = CreateFrame("CheckButton", "UIThingsTrackerBorderCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    borderCheckbox:SetPoint("TOPLEFT", 20, -560)
    borderCheckbox:SetHitRectInsets(0, -80, 0, 0)
    _G[borderCheckbox:GetName() .. "Text"]:SetText("Show Border")
    borderCheckbox:SetChecked(UIThingsDB.tracker.showBorder)
    borderCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.showBorder = self:GetChecked()
        UpdateTracker()
    end)

    local borderColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    borderColorLabel:SetPoint("TOPLEFT", 140, -563)
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
    bgCheckbox:SetPoint("TOPLEFT", 20, -585)
    bgCheckbox:SetHitRectInsets(0, -110, 0, 0)
    _G[bgCheckbox:GetName() .. "Text"]:SetText("Show Background")
    bgCheckbox:SetChecked(UIThingsDB.tracker.showBackground)
    bgCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.tracker.showBackground = self:GetChecked()
        UpdateTracker()
    end)

    local bgColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bgColorLabel:SetPoint("TOPLEFT", 165, -588)
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
    activeColorLabel:SetPoint("TOPLEFT", 20, -613)
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
