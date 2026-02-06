local addonName, addonTable = ...
addonTable.Config = {}

local configWindow

local function UpdateTracker()
    if addonTable.ObjectiveTracker and addonTable.ObjectiveTracker.UpdateSettings then
        addonTable.ObjectiveTracker.UpdateSettings()
    end
end

-- Helper: Create Color Picker
local function CreateColorPicker(parent, name, label, getFunc, setFunc, yOffset)
    local button = CreateFrame("Button", name, parent)
    button:SetSize(200, 24)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    button:EnableMouse(true)
    button:RegisterForClicks("AnyUp")

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetSize(24, 24)
    button.bg:SetPoint("LEFT")
    button.bg:SetColorTexture(1, 1, 1)

    button.color = button:CreateTexture(nil, "OVERLAY")
    button.color:SetPoint("LEFT", button.bg, "LEFT", 2, 0)
    button.color:SetSize(20, 20)

    local r, g, b = getFunc()
    button.color:SetColorTexture(r, g, b)

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.text:SetPoint("LEFT", button.bg, "RIGHT", 10, 0)
    button.text:SetText(label)

    button:SetScript("OnClick", function(self)
        local r, g, b = getFunc()

        local function SwatchFunc()
            local newR, newG, newB = ColorPickerFrame:GetColorRGB()
            setFunc(newR, newG, newB)
            button.color:SetColorTexture(newR, newG, newB)
        end

        local function CancelFunc(previousValues)
            local newR, newG, newB
            if previousValues then
                newR, newG, newB = previousValues.r, previousValues.g, previousValues.b
            else
                newR, newG, newB = r, g, b
            end
            setFunc(newR, newG, newB)
            button.color:SetColorTexture(newR, newG, newB)
        end

        if ColorPickerFrame.SetupColorPickerAndShow then
            local info = {
                swatchFunc = SwatchFunc,
                cancelFunc = CancelFunc,
                r = r,
                g = g,
                b = b,
                hasOpacity = false,
            }
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            ColorPickerFrame.func = SwatchFunc
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame.cancelFunc = CancelFunc
            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame:Show()
        end
    end)
end

function addonTable.Config.Initialize()
    -- Initialize the window if it doesn't exist
    if not configWindow then
        local fonts = {
            { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
            { name = "Arial Narrow",  path = "Fonts\\ARIALN.TTF" },
            { name = "Skurri",        path = "Fonts\\skurri.ttf" },
            { name = "Morpheus",      path = "Fonts\\MORPHEUS.TTF" }
        }

        configWindow = CreateFrame("Frame", "UIThingsConfigWindow", UIParent, "BasicFrameTemplateWithInset")
        configWindow:SetSize(600, 670) -- Resized for more tabs
        configWindow:SetPoint("CENTER")
        configWindow:SetMovable(true)
        configWindow:EnableMouse(true)
        tinsert(UISpecialFrames, "UIThingsConfigWindow")
        configWindow:RegisterForDrag("LeftButton")
        configWindow:SetScript("OnDragStart", configWindow.StartMoving)
        configWindow:SetScript("OnDragStop", configWindow.StopMovingOrSizing)

        configWindow:SetScript("OnHide", function()
            -- Auto-lock frames on close
            if UIThingsDB.frames and UIThingsDB.frames.list then
                for _, f in ipairs(UIThingsDB.frames.list) do
                    f.locked = true
                end
                -- If the frames module is loaded, update it
                if addonTable.Frames and addonTable.Frames.UpdateFrames then
                    addonTable.Frames.UpdateFrames()
                end
            end

            -- Auto-lock Loot Anchor
            if addonTable.Loot and addonTable.Loot.LockAnchor then
                addonTable.Loot.LockAnchor()
            end
        end)
        configWindow:Hide()

        configWindow.TitleText:SetText("Luna's UI Tweaks Config")

        -- Create Sub-Panels
        local trackerPanel = CreateFrame("Frame", nil, configWindow)
        trackerPanel:SetAllPoints()

        local vendorPanel = CreateFrame("Frame", nil, configWindow)
        vendorPanel:SetAllPoints()
        vendorPanel:Hide()

        local combatPanel = CreateFrame("Frame", nil, configWindow)
        combatPanel:SetAllPoints()
        combatPanel:Hide()

        local framesPanel = CreateFrame("Frame", nil, configWindow)
        framesPanel:SetAllPoints()
        framesPanel:Hide()

        local lootPanel = CreateFrame("Frame", nil, configWindow)
        lootPanel:SetAllPoints()
        lootPanel:Hide()

        local miscPanel = CreateFrame("Frame", nil, configWindow)
        miscPanel:SetAllPoints()
        miscPanel:Hide()

        local talentPanel = CreateFrame("Frame", nil, configWindow)
        talentPanel:SetAllPoints()
        talentPanel:Hide()

        -- Tab Buttons
        local tab1 = CreateFrame("Button", nil, configWindow, "PanelTabButtonTemplate")
        tab1:SetPoint("BOTTOMLEFT", configWindow, "BOTTOMLEFT", 10, -30)
        tab1:SetText("Tracker")
        tab1:SetID(1)

        local tab2 = CreateFrame("Button", nil, configWindow, "PanelTabButtonTemplate")
        tab2:SetPoint("LEFT", tab1, "RIGHT", 5, 0)
        tab2:SetText("Vendor")
        tab2:SetID(2)

        local tab3 = CreateFrame("Button", nil, configWindow, "PanelTabButtonTemplate")
        tab3:SetPoint("LEFT", tab2, "RIGHT", 5, 0)
        tab3:SetText("Combat")
        tab3:SetID(3)

        local tab4 = CreateFrame("Button", nil, configWindow, "PanelTabButtonTemplate")
        tab4:SetPoint("LEFT", tab3, "RIGHT", 5, 0)
        tab4:SetText("Frames")
        tab4:SetID(4)

        local tab5 = CreateFrame("Button", nil, configWindow, "PanelTabButtonTemplate")
        tab5:SetPoint("LEFT", tab4, "RIGHT", 5, 0)
        tab5:SetText("Loot")
        tab5:SetID(5)

        local tab6 = CreateFrame("Button", nil, configWindow, "PanelTabButtonTemplate")
        tab6:SetPoint("LEFT", tab5, "RIGHT", 5, 0)
        tab6:SetText("Misc")
        tab6:SetID(6)

        local tab7 = CreateFrame("Button", nil, configWindow, "PanelTabButtonTemplate")
        tab7:SetPoint("LEFT", tab6, "RIGHT", 5, 0)
        tab7:SetText("Talents")
        tab7:SetID(7)

        configWindow.Tabs = { tab1, tab2, tab3, tab4, tab5, tab6, tab7 }
        PanelTemplates_SetNumTabs(configWindow, 7)
        PanelTemplates_SetTab(configWindow, 1)

        -- Store reference to refresh function that will be defined later
        local refreshTalentReminderList = nil

        local function TabOnClick(self)
            PanelTemplates_SetTab(configWindow, self:GetID())
            trackerPanel:Hide()
            vendorPanel:Hide()
            combatPanel:Hide()
            framesPanel:Hide()
            lootPanel:Hide()
            miscPanel:Hide()
            talentPanel:Hide()

            local id = self:GetID()
            if id == 1 then
                trackerPanel:Show()
            elseif id == 2 then
                vendorPanel:Show()
            elseif id == 3 then
                combatPanel:Show()
            elseif id == 4 then
                framesPanel:Show()
            elseif id == 5 then
                lootPanel:Show()
            elseif id == 6 then
                miscPanel:Show()
            elseif id == 7 then
                talentPanel:Show()
                -- Refresh the reminder list when showing the talent tab
                if refreshTalentReminderList then
                    refreshTalentReminderList()
                end
            end
        end

        tab1:SetScript("OnClick", TabOnClick)
        tab2:SetScript("OnClick", TabOnClick)
        tab3:SetScript("OnClick", TabOnClick)
        tab4:SetScript("OnClick", TabOnClick)
        tab5:SetScript("OnClick", TabOnClick)
        tab6:SetScript("OnClick", TabOnClick)
        tab7:SetScript("OnClick", TabOnClick)

        -------------------------------------------------------------
        -- TRACKER PANEL CONTENT
        -------------------------------------------------------------

        -- Helper: Update Visuals based on enabled state
        local function UpdateModuleVisuals(panel, tab, enabled)
            if not enabled then
                -- Transparent Dark Red
                if not panel.bg then
                    panel.bg = panel:CreateTexture(nil, "BACKGROUND")
                    -- Inset to avoid covering the border
                    panel.bg:SetPoint("TOPLEFT", 4, -28)
                    panel.bg:SetPoint("BOTTOMRIGHT", -4, 4)
                    panel.bg:SetColorTexture(0.3, 0, 0, 0.5)
                else
                    panel.bg:Show()
                end

                -- Tint Tab Text Red
                if tab.Text then
                    tab.Text:SetTextColor(1, 0.2, 0.2)
                elseif tab:GetFontString() then
                    tab:GetFontString():SetTextColor(1, 0.2, 0.2)
                end
            else
                if panel.bg then panel.bg:Hide() end
                -- Reset Tab Text (Normal Color)
                if tab.Text then
                    tab.Text:SetTextColor(1, 0.82, 0) -- GameFontNormal Color approx
                elseif tab:GetFontString() then
                    tab:GetFontString():SetTextColor(1, 0.82, 0)
                end
            end
        end

        -- Helper: Create Section Header
        local function CreateSectionHeader(parent, text, yOffset)
            local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            header:SetPoint("TOPLEFT", 16, yOffset)
            header:SetText(text)
            header:SetTextColor(1, 0.82, 0) -- Gold

            local line = parent:CreateTexture(nil, "ARTWORK")
            line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
            line:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
            line:SetHeight(1)
            line:SetColorTexture(0.5, 0.5, 0.5, 0.5)

            return header
        end

        local trackerTitle = trackerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        trackerTitle:SetPoint("TOPLEFT", 16, -16)
        trackerTitle:SetText("Objective Tracker")

        -------------------------------------------------------------
        -- SECTION: General
        -------------------------------------------------------------
        CreateSectionHeader(trackerPanel, "General", -45)

        -- Enable Tracker Checkbox
        local enableTrackerBtn = CreateFrame("CheckButton", "UIThingsTrackerEnableCheck", trackerPanel,
            "ChatConfigCheckButtonTemplate")
        enableTrackerBtn:SetPoint("TOPLEFT", 20, -70)
        _G[enableTrackerBtn:GetName() .. "Text"]:SetText("Enable Objective Tracker Tweaks")
        enableTrackerBtn:SetChecked(UIThingsDB.tracker.enabled)
        enableTrackerBtn:SetScript("OnClick", function(self)
            local enabled = not not self:GetChecked()
            UIThingsDB.tracker.enabled = enabled
            UpdateTracker()
            UpdateModuleVisuals(trackerPanel, tab1, enabled)
        end)
        UpdateModuleVisuals(trackerPanel, tab1, UIThingsDB.tracker.enabled)

        -- Lock Checkbox
        local lockBtn = CreateFrame("CheckButton", "UIThingsLockCheck", trackerPanel, "ChatConfigCheckButtonTemplate")
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
        CreateSectionHeader(trackerPanel, "Size & Position", -100)

        -- Width Slider
        local widthSlider = CreateFrame("Slider", "UIThingsWidthSlider", trackerPanel, "OptionsSliderTemplate")
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
        local heightSlider = CreateFrame("Slider", "UIThingsHeightSlider", trackerPanel, "OptionsSliderTemplate")
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
        local paddingSlider = CreateFrame("Slider", "UIThingsTrackerPaddingSlider", trackerPanel, "OptionsSliderTemplate")
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
        local trackerStrataLabel = trackerPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        trackerStrataLabel:SetPoint("TOPLEFT", 20, -170)
        trackerStrataLabel:SetText("Strata:")

        local trackerStrataDropdown = CreateFrame("Frame", "UIThingsTrackerStrataDropdown", trackerPanel,
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
        CreateSectionHeader(trackerPanel, "Fonts", -225)

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
        local headerFontDropdown = CreateFontDropdown(trackerPanel, "headerFont", "Quest Name Font:", 20, -250)

        -- Quest Name Size (under font dropdown)
        local headerSizeSlider = CreateFrame("Slider", "UIThingsTrackerHeaderSizeSlider", trackerPanel,
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
        local detailFontDropdown = CreateFontDropdown(trackerPanel, "detailFont", "Quest Detail Font:", 250, -250)

        -- Quest Detail Size (under font dropdown)
        local detailSizeSlider = CreateFrame("Slider", "UIThingsTrackerDetailSizeSlider", trackerPanel,
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
        CreateSectionHeader(trackerPanel, "Content", -355)

        -- Section Order Dropdown
        local orderLabel = trackerPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        orderLabel:SetPoint("TOPLEFT", 20, -380)
        orderLabel:SetText("Section Order:")

        local orderDropdown = CreateFrame("Frame", "UIThingsTrackerOrderDropdown", trackerPanel, "UIDropDownMenuTemplate")
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
        local wqActiveCheckbox = CreateFrame("CheckButton", "UIThingsTrackerWQActiveCheckbox", trackerPanel,
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
        local wqTimerCheckbox = CreateFrame("CheckButton", "UIThingsTrackerWQTimerCheckbox", trackerPanel,
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
        CreateSectionHeader(trackerPanel, "Behavior", -450)

        -- Auto Track Quests Checkbox
        local autoTrackCheckbox = CreateFrame("CheckButton", "UIThingsTrackerAutoTrackCheckbox", trackerPanel,
            "ChatConfigCheckButtonTemplate")
        autoTrackCheckbox:SetPoint("TOPLEFT", 20, -475)
        autoTrackCheckbox:SetHitRectInsets(0, -110, 0, 0)
        _G[autoTrackCheckbox:GetName() .. "Text"]:SetText("Auto Track Quests")
        autoTrackCheckbox:SetChecked(UIThingsDB.tracker.autoTrackQuests)
        autoTrackCheckbox:SetScript("OnClick", function(self)
            UIThingsDB.tracker.autoTrackQuests = self:GetChecked()
        end)

        -- Right-Click Active Quest Checkbox
        local rightClickCheckbox = CreateFrame("CheckButton", "UIThingsTrackerRightClickCheckbox", trackerPanel,
            "ChatConfigCheckButtonTemplate")
        rightClickCheckbox:SetPoint("TOPLEFT", 180, -475)
        rightClickCheckbox:SetHitRectInsets(0, -130, 0, 0)
        _G[rightClickCheckbox:GetName() .. "Text"]:SetText("Right-Click: Active Quest")
        rightClickCheckbox:SetChecked(UIThingsDB.tracker.rightClickSuperTrack)
        rightClickCheckbox:SetScript("OnClick", function(self)
            UIThingsDB.tracker.rightClickSuperTrack = self:GetChecked()
        end)

        -- Shift-Click Untrack Checkbox
        local shiftClickCheckbox = CreateFrame("CheckButton", "UIThingsTrackerShiftClickCheckbox", trackerPanel,
            "ChatConfigCheckButtonTemplate")
        shiftClickCheckbox:SetPoint("TOPLEFT", 380, -475)
        shiftClickCheckbox:SetHitRectInsets(0, -110, 0, 0)
        _G[shiftClickCheckbox:GetName() .. "Text"]:SetText("Shift-Click: Untrack")
        shiftClickCheckbox:SetChecked(UIThingsDB.tracker.shiftClickUntrack)
        shiftClickCheckbox:SetScript("OnClick", function(self)
            UIThingsDB.tracker.shiftClickUntrack = self:GetChecked()
        end)

        -- Hide In Combat Checkbox
        local combatHideCheckbox = CreateFrame("CheckButton", "UIThingsTrackerCombatHideCheckbox", trackerPanel,
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
        local mplusHideCheckbox = CreateFrame("CheckButton", "UIThingsTrackerMPlusHideCheckbox", trackerPanel,
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
        CreateSectionHeader(trackerPanel, "Appearance", -535)

        -- Row 1: Border
        local borderCheckbox = CreateFrame("CheckButton", "UIThingsTrackerBorderCheckbox", trackerPanel,
            "ChatConfigCheckButtonTemplate")
        borderCheckbox:SetPoint("TOPLEFT", 20, -560)
        borderCheckbox:SetHitRectInsets(0, -80, 0, 0)
        _G[borderCheckbox:GetName() .. "Text"]:SetText("Show Border")
        borderCheckbox:SetChecked(UIThingsDB.tracker.showBorder)
        borderCheckbox:SetScript("OnClick", function(self)
            UIThingsDB.tracker.showBorder = self:GetChecked()
            UpdateTracker()
        end)

        local borderColorLabel = trackerPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        borderColorLabel:SetPoint("TOPLEFT", 140, -563)
        borderColorLabel:SetText("Color:")

        local borderColorSwatch = CreateFrame("Button", nil, trackerPanel)
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
        local bgCheckbox = CreateFrame("CheckButton", "UIThingsTrackerBgCheckbox", trackerPanel,
            "ChatConfigCheckButtonTemplate")
        bgCheckbox:SetPoint("TOPLEFT", 20, -585)
        bgCheckbox:SetHitRectInsets(0, -110, 0, 0)
        _G[bgCheckbox:GetName() .. "Text"]:SetText("Show Background")
        bgCheckbox:SetChecked(UIThingsDB.tracker.showBackground)
        bgCheckbox:SetScript("OnClick", function(self)
            UIThingsDB.tracker.showBackground = self:GetChecked()
            UpdateTracker()
        end)

        local bgColorLabel = trackerPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        bgColorLabel:SetPoint("TOPLEFT", 165, -588)
        bgColorLabel:SetText("Color:")

        local bgColorSwatch = CreateFrame("Button", nil, trackerPanel)
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
        local activeColorLabel = trackerPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        activeColorLabel:SetPoint("TOPLEFT", 20, -613)
        activeColorLabel:SetText("Active Quest:")

        local activeColorSwatch = CreateFrame("Button", nil, trackerPanel)
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

        -------------------------------------------------------------
        -- VENDOR PANEL CONTENT
        -------------------------------------------------------------

        local vendorTitle = vendorPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        vendorTitle:SetPoint("TOPLEFT", 16, -16)
        vendorTitle:SetText("Vendor Automation")

        -- Enable Vendor Checkbox
        local enableVendorBtn = CreateFrame("CheckButton", "UIThingsVendorEnableCheck", vendorPanel,
            "ChatConfigCheckButtonTemplate")
        enableVendorBtn:SetPoint("TOPLEFT", 20, -50)
        _G[enableVendorBtn:GetName() .. "Text"]:SetText("Enable Vendor Automation")
        enableVendorBtn:SetChecked(UIThingsDB.vendor.enabled)
        enableVendorBtn:SetScript("OnClick", function(self)
            local enabled = not not self:GetChecked()
            UIThingsDB.vendor.enabled = enabled
            UpdateModuleVisuals(vendorPanel, tab2, enabled)
        end)
        UpdateModuleVisuals(vendorPanel, tab2, UIThingsDB.vendor.enabled)

        -- Auto Repair
        local repairBtn = CreateFrame("CheckButton", "UIThingsAutoRepairCheck", vendorPanel,
            "ChatConfigCheckButtonTemplate")
        repairBtn:SetPoint("TOPLEFT", 20, -70)
        _G[repairBtn:GetName() .. "Text"]:SetText("Auto Repair")
        repairBtn:SetChecked(UIThingsDB.vendor.autoRepair)
        repairBtn:SetScript("OnClick", function(self)
            local val = not not self:GetChecked()
            UIThingsDB.vendor.autoRepair = val
        end)

        -- Guild Repair
        local guildBtn = CreateFrame("CheckButton", "UIThingsGuildRepairCheck", vendorPanel,
            "ChatConfigCheckButtonTemplate")
        guildBtn:SetPoint("TOPLEFT", 40, -100) -- Indented
        _G[guildBtn:GetName() .. "Text"]:SetText("Use Guild Funds")
        guildBtn:SetChecked(UIThingsDB.vendor.useGuildRepair)
        guildBtn:SetScript("OnClick", function(self)
            local val = not not self:GetChecked()
            UIThingsDB.vendor.useGuildRepair = val
        end)

        -- Sell Greys
        local sellBtn = CreateFrame("CheckButton", "UIThingsSellGreysCheck", vendorPanel, "ChatConfigCheckButtonTemplate")
        sellBtn:SetPoint("TOPLEFT", 20, -130)
        _G[sellBtn:GetName() .. "Text"]:SetText("Auto Sell Greys")
        sellBtn:SetChecked(UIThingsDB.vendor.sellGreys)
        sellBtn:SetScript("OnClick", function(self)
            local val = not not self:GetChecked()
            UIThingsDB.vendor.sellGreys = val
        end)

        -- Durability Threshold Slider
        local thresholdSlider = CreateFrame("Slider", "UIThingsThresholdSlider", vendorPanel, "OptionsSliderTemplate")
        thresholdSlider:SetPoint("TOPLEFT", 20, -170)
        thresholdSlider:SetMinMaxValues(0, 100)
        thresholdSlider:SetValueStep(1)
        thresholdSlider:SetObeyStepOnDrag(true)
        thresholdSlider:SetWidth(200)
        _G[thresholdSlider:GetName() .. 'Text']:SetText(string.format("Repair Reminder: %d%%",
            UIThingsDB.vendor.repairThreshold or 20))
        _G[thresholdSlider:GetName() .. 'Low']:SetText("0%")
        _G[thresholdSlider:GetName() .. 'High']:SetText("100%")
        thresholdSlider:SetValue(UIThingsDB.vendor.repairThreshold or 20)
        thresholdSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value)
            UIThingsDB.vendor.repairThreshold = value
            _G[self:GetName() .. 'Text']:SetText(string.format("Repair Reminder: %d%%", value))
            if addonTable.Vendor.UpdateSettings then addonTable.Vendor.UpdateSettings() end
        end)

        -- Lock Alert Checkbox
        local vendorLockBtn = CreateFrame("CheckButton", "UIThingsVendorLockCheck", vendorPanel,
            "ChatConfigCheckButtonTemplate")
        vendorLockBtn:SetPoint("TOPLEFT", 20, -210)
        _G[vendorLockBtn:GetName() .. "Text"]:SetText("Lock Repair Alert")
        vendorLockBtn:SetChecked(UIThingsDB.vendor.warningLocked)
        vendorLockBtn:SetScript("OnClick", function(self)
            local locked = not not self:GetChecked()
            UIThingsDB.vendor.warningLocked = locked
            if addonTable.Vendor.UpdateSettings then addonTable.Vendor.UpdateSettings() end
        end)

        -- Vendor Font Selector
        local vendorFontLabel = vendorPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        vendorFontLabel:SetPoint("TOPLEFT", 20, -250)
        vendorFontLabel:SetText("Alert Font:")

        local vendorFontDropdown = CreateFrame("Frame", "UIThingsVendorFontDropdown", vendorPanel,
            "UIDropDownMenuTemplate")
        vendorFontDropdown:SetPoint("TOPLEFT", vendorFontLabel, "BOTTOMLEFT", -15, -10)

        local function VendorFontOnClick(self)
            UIDropDownMenu_SetSelectedID(vendorFontDropdown, self:GetID())
            UIThingsDB.vendor.font = self.value
            if addonTable.Vendor.UpdateSettings then addonTable.Vendor.UpdateSettings() end
        end

        local function VendorFontInit(self, level)
            for k, v in pairs(fonts) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = v.name
                info.value = v.path
                info.func = VendorFontOnClick
                UIDropDownMenu_AddButton(info, level)
            end
        end

        UIDropDownMenu_Initialize(vendorFontDropdown, VendorFontInit)
        UIDropDownMenu_SetText(vendorFontDropdown, "Select Font")
        for i, f in ipairs(fonts) do
            if f.path == UIThingsDB.vendor.font then
                UIDropDownMenu_SetText(vendorFontDropdown, f.name)
            end
        end

        -- Vendor Font Size Slider
        local vendorFontSizeSlider = CreateFrame("Slider", "UIThingsVendorFontSizeSlider", vendorPanel,
            "OptionsSliderTemplate")
        vendorFontSizeSlider:SetPoint("TOPLEFT", 20, -320)
        vendorFontSizeSlider:SetMinMaxValues(10, 64)
        vendorFontSizeSlider:SetValueStep(1)
        vendorFontSizeSlider:SetObeyStepOnDrag(true)
        vendorFontSizeSlider:SetWidth(200)
        _G[vendorFontSizeSlider:GetName() .. 'Text']:SetText(string.format("Alert Size: %d", UIThingsDB.vendor.fontSize))
        _G[vendorFontSizeSlider:GetName() .. 'Low']:SetText("10")
        _G[vendorFontSizeSlider:GetName() .. 'High']:SetText("64")
        vendorFontSizeSlider:SetValue(UIThingsDB.vendor.fontSize)
        vendorFontSizeSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value)
            UIThingsDB.vendor.fontSize = value
            _G[self:GetName() .. 'Text']:SetText(string.format("Alert Size: %d", value))
            if addonTable.Vendor.UpdateSettings then addonTable.Vendor.UpdateSettings() end
        end)

        -------------------------------------------------------------
        -- COMBAT PANEL CONTENT
        -------------------------------------------------------------
        local function UpdateCombat()
            if addonTable.Combat and addonTable.Combat.UpdateSettings then
                addonTable.Combat.UpdateSettings()
            end
        end

        -- Enable Combat Timer Checkbox
        local combatTitle = combatPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        combatTitle:SetPoint("TOPLEFT", 16, -16)
        combatTitle:SetText("Combat Timer")

        local enableCombatBtn = CreateFrame("CheckButton", "UIThingsCombatEnableCheck", combatPanel,
            "ChatConfigCheckButtonTemplate")
        enableCombatBtn:SetPoint("TOPLEFT", 20, -50)
        _G[enableCombatBtn:GetName() .. "Text"]:SetText("Enable Combat Timer")
        enableCombatBtn:SetChecked(UIThingsDB.combat.enabled)
        enableCombatBtn:SetScript("OnClick", function(self)
            local enabled = not not self:GetChecked()
            UIThingsDB.combat.enabled = enabled
            UpdateCombat()
            UpdateModuleVisuals(combatPanel, tab3, enabled)
        end)
        UpdateModuleVisuals(combatPanel, tab3, UIThingsDB.combat.enabled)

        -- Lock Timer
        local combatLockBtn = CreateFrame("CheckButton", "UIThingsCombatLockCheck", combatPanel,
            "ChatConfigCheckButtonTemplate")
        combatLockBtn:SetPoint("TOPLEFT", 20, -70)
        _G[combatLockBtn:GetName() .. "Text"]:SetText("Lock Combat Timer")
        combatLockBtn:SetChecked(UIThingsDB.combat.locked)
        combatLockBtn:SetScript("OnClick", function(self)
            local locked = not not self:GetChecked()
            UIThingsDB.combat.locked = locked
            UpdateCombat()
        end)

        -- Font Selector (Simple Dropdown)
        local fontLabel = combatPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fontLabel:SetPoint("TOPLEFT", 20, -110)
        fontLabel:SetText("Font:")

        local fontDropdown = CreateFrame("Frame", "UIThingsFontDropdown", combatPanel, "UIDropDownMenuTemplate")
        fontDropdown:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", -15, -10)



        local function OnClick(self)
            UIDropDownMenu_SetSelectedID(fontDropdown, self:GetID())
            UIThingsDB.combat.font = self.value
            UpdateCombat()
        end

        local function Initialize(self, level)
            for k, v in pairs(fonts) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = v.name
                info.value = v.path
                info.func = OnClick
                UIDropDownMenu_AddButton(info, level)
            end
        end

        UIDropDownMenu_Initialize(fontDropdown, Initialize)
        -- Set initial selection logic (simplified)
        UIDropDownMenu_SetText(fontDropdown, "Select Font")
        for i, f in ipairs(fonts) do
            if f.path == UIThingsDB.combat.font then
                UIDropDownMenu_SetText(fontDropdown, f.name)
            end
        end

        -- Font Size Slider
        local fontSizeSlider = CreateFrame("Slider", "UIThingsFontSizeSlider", combatPanel, "OptionsSliderTemplate")
        fontSizeSlider:SetPoint("TOPLEFT", 20, -180)
        fontSizeSlider:SetMinMaxValues(10, 32)
        fontSizeSlider:SetValueStep(1)
        fontSizeSlider:SetObeyStepOnDrag(true)
        fontSizeSlider:SetWidth(150)
        _G[fontSizeSlider:GetName() .. 'Text']:SetText(string.format("Size: %d", UIThingsDB.combat.fontSize))
        _G[fontSizeSlider:GetName() .. 'Low']:SetText("10")
        _G[fontSizeSlider:GetName() .. 'High']:SetText("32")
        fontSizeSlider:SetValue(UIThingsDB.combat.fontSize)
        fontSizeSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value)
            UIThingsDB.combat.fontSize = value
            _G[self:GetName() .. 'Text']:SetText(string.format("Size: %d", value))
            UpdateCombat()
        end)

        -- Color Pickers
        CreateColorPicker(combatPanel, "UIThingsCombatColorIn", "In Combat Color",
            function()
                return UIThingsDB.combat.colorInCombat.r, UIThingsDB.combat.colorInCombat.g,
                    UIThingsDB.combat.colorInCombat.b
            end,
            function(r, g, b)
                UIThingsDB.combat.colorInCombat = { r = r, g = g, b = b }
                UpdateCombat()
            end,
            -230
        )

        CreateColorPicker(combatPanel, "UIThingsCombatColorOut", "Out Combat Color",
            function()
                return UIThingsDB.combat.colorOutCombat.r, UIThingsDB.combat.colorOutCombat.g,
                    UIThingsDB.combat.colorOutCombat.b
            end,
            function(r, g, b)
                UIThingsDB.combat.colorOutCombat = { r = r, g = g, b = b }
                UpdateCombat()
            end,
            -260
        )



        -- FRAMES PANEL CONTENT
        -------------------------------------------------------------
        local selectedFrameIndex = nil

        local function UpdateFrames()
            if addonTable.Frames and addonTable.Frames.UpdateFrames then
                addonTable.Frames.UpdateFrames()
            end
        end

        local framesTitle = framesPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        framesTitle:SetPoint("TOPLEFT", 16, -16)
        framesTitle:SetText("Custom Frames")

        local addFrameBtn, duplicateFrameBtn

        local framesEnableBtn = CreateFrame("CheckButton", "UIThingsFramesEnableCheck", framesPanel,
            "ChatConfigCheckButtonTemplate")
        framesEnableBtn:SetPoint("TOPLEFT", 20, -50)
        _G[framesEnableBtn:GetName() .. "Text"]:SetText("Enable Custom Frames")
        framesEnableBtn:SetChecked(UIThingsDB.frames.enabled)
        framesEnableBtn:SetScript("OnClick", function(self)
            local enabled = self:GetChecked()
            UIThingsDB.frames.enabled = enabled
            UpdateFrames()
            UpdateModuleVisuals(framesPanel, tab4, enabled)
            if addFrameBtn then addFrameBtn:SetEnabled(enabled) end
            if duplicateFrameBtn then duplicateFrameBtn:SetEnabled(enabled) end
        end)
        UpdateModuleVisuals(framesPanel, tab4, UIThingsDB.frames.enabled)

        -- Frame Selector Dropdown
        local frameSelectLabel = framesPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frameSelectLabel:SetPoint("TOPLEFT", 20, -80)
        frameSelectLabel:SetText("Select Frame:")

        local frameDropdown = CreateFrame("Frame", "UIThingsFrameSelectDropdown", framesPanel, "UIDropDownMenuTemplate")
        frameDropdown:SetPoint("TOPLEFT", frameSelectLabel, "BOTTOMLEFT", -15, -10)

        -- Controls Container (hidden if no frame selected)
        local frameControls = CreateFrame("Frame", nil, framesPanel)
        frameControls:SetPoint("TOPLEFT", frameDropdown, "BOTTOMLEFT", 15, -20)
        frameControls:SetSize(400, 300)
        frameControls:Hide()

        -- Refresh Function forward declaration
        local RefreshFrameControls

        local function FrameSelectOnClick(self)
            UIDropDownMenu_SetSelectedID(frameDropdown, self:GetID())
            selectedFrameIndex = self.value
            RefreshFrameControls()
        end

        local function FrameSelectInit(self, level)
            for i, f in ipairs(UIThingsDB.frames.list) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = f.name or ("Frame " .. i)
                info.value = i
                info.func = FrameSelectOnClick
                UIDropDownMenu_AddButton(info, level)
            end
        end

        local function UpdateDropdownText()
            if selectedFrameIndex and UIThingsDB.frames.list[selectedFrameIndex] then
                UIDropDownMenu_SetText(frameDropdown,
                    UIThingsDB.frames.list[selectedFrameIndex].name or ("Frame " .. selectedFrameIndex))
            else
                UIDropDownMenu_SetText(frameDropdown, "Select a Frame")
            end
        end

        UIDropDownMenu_Initialize(frameDropdown, FrameSelectInit)

        -- Add Button
        addFrameBtn = CreateFrame("Button", nil, framesPanel, "UIPanelButtonTemplate")
        addFrameBtn:SetPoint("LEFT", frameDropdown, "RIGHT", 130, 2)
        addFrameBtn:SetSize(80, 22)
        addFrameBtn:SetText("Add New")
        addFrameBtn:SetScript("OnClick", function()
            local baseName = "Frame"
            local name = baseName
            local count = 1

            -- Simple unique name generator
            local function NameExists(n)
                for _, f in ipairs(UIThingsDB.frames.list) do
                    if f.name == n then return true end
                end
                return false
            end

            while NameExists(name) do
                count = count + 1
                name = baseName .. " " .. count
            end

            table.insert(UIThingsDB.frames.list, {
                name = name,
                locked = false,
                width = 100,
                height = 100,
                x = 0,
                y = 0,
                borderSize = 1,
                strata = "LOW",
                color = { r = 0, g = 0, b = 0, a = 0.5 },
                borderColor = { r = 1, g = 1, b = 1, a = 1 }
            })
            selectedFrameIndex = #UIThingsDB.frames.list
            UIDropDownMenu_Initialize(frameDropdown, FrameSelectInit) -- Refresh list
            UpdateDropdownText()
            RefreshFrameControls()
            UpdateFrames()
        end)

        -- Duplicate Button
        duplicateFrameBtn = CreateFrame("Button", nil, framesPanel, "UIPanelButtonTemplate")
        duplicateFrameBtn:SetPoint("LEFT", addFrameBtn, "RIGHT", 10, 0)
        duplicateFrameBtn:SetSize(80, 22)
        duplicateFrameBtn:SetText("Duplicate")
        duplicateFrameBtn:SetScript("OnClick", function()
            if not selectedFrameIndex then return end

            local source = UIThingsDB.frames.list[selectedFrameIndex]
            if not source then return end

            -- Helper to deep copy table
            local function CopyTable(t)
                local copy = {}
                for k, v in pairs(t) do
                    if type(v) == "table" then
                        copy[k] = CopyTable(v)
                    else
                        copy[k] = v
                    end
                end
                return copy
            end

            local newFrameData = CopyTable(source)

            -- Generate new name (Increment number if present, else append count)
            local baseName, num = string.match(source.name, "^(.*%A)(%d+)$")
            if not baseName then
                baseName = source.name .. " "
                num = 1
            else
                num = tonumber(num) + 1
            end

            local function NameExists(n)
                for _, f in ipairs(UIThingsDB.frames.list) do
                    if f.name == n then return true end
                end
                return false
            end

            local newName = baseName .. num
            while NameExists(newName) do
                num = num + 1
                newName = baseName .. num
            end
            newFrameData.name = newName

            -- Move 10 pixels toward center (0,0)
            -- If x > 0, subtract 10. If x < 0, add 10.
            if newFrameData.x > 0 then
                newFrameData.x = newFrameData.x - 10
            else
                newFrameData.x = newFrameData.x + 10
            end

            if newFrameData.y > 0 then
                newFrameData.y = newFrameData.y - 10
            else
                newFrameData.y = newFrameData.y + 10
            end

            -- Ensure it's unlocked
            newFrameData.locked = false

            table.insert(UIThingsDB.frames.list, newFrameData)
            selectedFrameIndex = #UIThingsDB.frames.list

            UIDropDownMenu_Initialize(frameDropdown, FrameSelectInit)
            UpdateDropdownText()
            RefreshFrameControls()
            UpdateFrames()
        end)

        -- Initial Button State
        if addFrameBtn then addFrameBtn:SetEnabled(UIThingsDB.frames.enabled) end
        if duplicateFrameBtn then duplicateFrameBtn:SetEnabled(UIThingsDB.frames.enabled) end

        -- Remove Button
        local removeFrameBtn = CreateFrame("Button", nil, frameControls, "UIPanelButtonTemplate")
        removeFrameBtn:SetPoint("TOPRIGHT", framesPanel, "TOPRIGHT", -20, -80)
        removeFrameBtn:SetSize(80, 22)
        removeFrameBtn:SetText("Remove")
        removeFrameBtn:SetScript("OnClick", function()
            if selectedFrameIndex then
                table.remove(UIThingsDB.frames.list, selectedFrameIndex)
                selectedFrameIndex = nil
                UIDropDownMenu_Initialize(frameDropdown, FrameSelectInit)
                UpdateDropdownText()
                RefreshFrameControls()
                UpdateFrames()
            end
        end)

        -- Properties in frameControls
        -- Name EditBox
        local nameLabel = frameControls:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameLabel:SetPoint("TOPLEFT", 0, 0)
        nameLabel:SetText("Name:")
        local nameEdit = CreateFrame("EditBox", nil, frameControls, "InputBoxTemplate")
        nameEdit:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
        nameEdit:SetSize(150, 20)
        nameEdit:SetAutoFocus(false)
        nameEdit:SetScript("OnEnterPressed", function(self)
            if selectedFrameIndex then
                UIThingsDB.frames.list[selectedFrameIndex].name = self:GetText()
                self:ClearFocus()
                UpdateDropdownText()
                UpdateFrames()
            end
        end)

        -- Lock Checkbox
        local lockFrameBtn = CreateFrame("CheckButton", nil, frameControls, "ChatConfigCheckButtonTemplate")
        lockFrameBtn:SetPoint("TOPLEFT", 0, -30)
        local lockText = lockFrameBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lockText:SetPoint("LEFT", lockFrameBtn, "RIGHT", 5, 0)
        lockText:SetText("Lock Frame")
        lockFrameBtn:SetScript("OnClick", function(self)
            if selectedFrameIndex then
                UIThingsDB.frames.list[selectedFrameIndex].locked = self:GetChecked()
                UpdateFrames()
            end
        end)

        -- Helper to create input box
        local function CreateValueEditBox(slider, key)
            local edit = CreateFrame("EditBox", nil, slider:GetParent(), "InputBoxTemplate")
            edit:SetPoint("LEFT", slider, "RIGHT", 15, 0)
            edit:SetSize(50, 20)
            edit:SetAutoFocus(false)
            edit:SetScript("OnEnterPressed", function(self)
                local val = tonumber(self:GetText())
                if val and selectedFrameIndex then
                    UIThingsDB.frames.list[selectedFrameIndex][key] = val
                    slider:SetValue(val)
                    UpdateFrames()
                end
                self:ClearFocus()
            end)
            edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            return edit
        end

        -- Width/Height Sliders
        local widthSlider = CreateFrame("Slider", "UIThingsFrameWidthSlider", frameControls, "OptionsSliderTemplate")
        widthSlider:SetPoint("TOPLEFT", 0, -70)
        widthSlider:SetMinMaxValues(10, 1000)
        widthSlider:SetValueStep(1)
        widthSlider:SetObeyStepOnDrag(true)
        widthSlider:SetWidth(120)
        _G[widthSlider:GetName() .. 'Low']:SetText("")
        _G[widthSlider:GetName() .. 'High']:SetText("")

        local widthEdit = CreateValueEditBox(widthSlider, "width")

        widthSlider:SetScript("OnValueChanged", function(self, value)
            if selectedFrameIndex then
                value = math.floor(value)
                UIThingsDB.frames.list[selectedFrameIndex].width = value
                _G[self:GetName() .. 'Text']:SetText("Width") -- Static Label
                widthEdit:SetText(tostring(value))
                UpdateFrames()
            end
        end)

        local heightSlider = CreateFrame("Slider", "UIThingsFrameHeightSlider", frameControls, "OptionsSliderTemplate")
        heightSlider:SetPoint("TOPLEFT", 195, -70) -- Shifted right slightly to accommodate editbox
        heightSlider:SetMinMaxValues(10, 1000)
        heightSlider:SetValueStep(1)
        heightSlider:SetObeyStepOnDrag(true)
        heightSlider:SetWidth(120)
        _G[heightSlider:GetName() .. 'Low']:SetText("")
        _G[heightSlider:GetName() .. 'High']:SetText("")

        local heightEdit = CreateValueEditBox(heightSlider, "height")

        heightSlider:SetScript("OnValueChanged", function(self, value)
            if selectedFrameIndex then
                value = math.floor(value)
                UIThingsDB.frames.list[selectedFrameIndex].height = value
                _G[self:GetName() .. 'Text']:SetText("Height")
                heightEdit:SetText(tostring(value))
                UpdateFrames()
            end
        end)

        -- X/Y Sliders
        local xSlider = CreateFrame("Slider", "UIThingsFrameXSlider", frameControls, "OptionsSliderTemplate")
        xSlider:SetPoint("TOPLEFT", 0, -110)
        xSlider:SetMinMaxValues(-2000, 2000)
        xSlider:SetValueStep(1)
        xSlider:SetObeyStepOnDrag(true)
        xSlider:SetWidth(120)
        _G[xSlider:GetName() .. 'Low']:SetText("")
        _G[xSlider:GetName() .. 'High']:SetText("")

        local xEdit = CreateValueEditBox(xSlider, "x")

        xSlider:SetScript("OnValueChanged", function(self, value)
            if selectedFrameIndex then
                value = math.floor(value)
                UIThingsDB.frames.list[selectedFrameIndex].x = value
                _G[self:GetName() .. 'Text']:SetText("X Pos")
                xEdit:SetText(tostring(value))
                UpdateFrames()
            end
        end)

        local ySlider = CreateFrame("Slider", "UIThingsFrameYSlider", frameControls, "OptionsSliderTemplate")
        ySlider:SetPoint("TOPLEFT", 195, -110)
        ySlider:SetMinMaxValues(-1500, 1500)
        ySlider:SetValueStep(1)
        ySlider:SetObeyStepOnDrag(true)
        ySlider:SetWidth(120)
        _G[ySlider:GetName() .. 'Low']:SetText("")
        _G[ySlider:GetName() .. 'High']:SetText("")

        local yEdit = CreateValueEditBox(ySlider, "y")

        ySlider:SetScript("OnValueChanged", function(self, value)
            if selectedFrameIndex then
                value = math.floor(value)
                UIThingsDB.frames.list[selectedFrameIndex].y = value
                _G[self:GetName() .. 'Text']:SetText("Y Pos")
                yEdit:SetText(tostring(value))
                UpdateFrames()
            end
        end)

        -- Border Size Slider
        local borderSlider = CreateFrame("Slider", "UIThingsFrameBorderSlider", frameControls, "OptionsSliderTemplate")
        borderSlider:SetPoint("TOPLEFT", 0, -150)
        borderSlider:SetMinMaxValues(0, 10)
        borderSlider:SetValueStep(1)
        borderSlider:SetObeyStepOnDrag(true)
        borderSlider:SetWidth(150)
        borderSlider:SetScript("OnValueChanged", function(self, value)
            if selectedFrameIndex then
                value = math.floor(value)
                UIThingsDB.frames.list[selectedFrameIndex].borderSize = value
                _G[self:GetName() .. 'Text']:SetText(string.format("Border: %d", value))
                UpdateFrames()
            end
        end)

        -- Strata Dropdown
        local strataLabel = frameControls:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        strataLabel:SetPoint("TOPLEFT", 180, -150)
        strataLabel:SetText("Strata:")
        local strataDropdown = CreateFrame("Frame", "UIThingsFrameStrataDropdown", frameControls,
            "UIDropDownMenuTemplate")
        strataDropdown:SetPoint("TOPLEFT", strataLabel, "BOTTOMLEFT", -15, -10)
        local stratas = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "TOOLTIP" }
        local function StrataOnClick(self)
            UIDropDownMenu_SetSelectedID(strataDropdown, self:GetID())
            if selectedFrameIndex then
                UIThingsDB.frames.list[selectedFrameIndex].strata = self.value
                UpdateFrames()
            end
        end
        local function StrataInit(self, level)
            for _, s in ipairs(stratas) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = s
                info.value = s
                info.func = StrataOnClick
                UIDropDownMenu_AddButton(info, level)
            end
        end
        UIDropDownMenu_Initialize(strataDropdown, StrataInit)

        -- Colors
        local fillColorLabel = frameControls:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fillColorLabel:SetPoint("TOPLEFT", 0, -220)
        fillColorLabel:SetText("Fill Color:")
        local fillColorSwatch = CreateFrame("Button", nil, frameControls)
        fillColorSwatch:SetSize(20, 20)
        fillColorSwatch:SetPoint("LEFT", fillColorLabel, "RIGHT", 10, 0)
        fillColorSwatch.tex = fillColorSwatch:CreateTexture(nil, "OVERLAY")
        fillColorSwatch.tex:SetAllPoints()
        Mixin(fillColorSwatch, BackdropTemplateMixin)
        fillColorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        fillColorSwatch:SetBackdropBorderColor(1, 1, 1)
        fillColorSwatch:SetScript("OnClick", function(self)
            if not selectedFrameIndex then return end
            local c = UIThingsDB.frames.list[selectedFrameIndex].color
            local info = UIDropDownMenu_CreateInfo()
            local prevR, prevG, prevB, prevA = c.r, c.g, c.b, c.a
            info.r, info.g, info.b, info.opacity = prevR, prevG, prevB, prevA
            info.hasOpacity = true
            info.opacityFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                c.r, c.g, c.b, c.a = r, g, b, a
                fillColorSwatch.tex:SetColorTexture(r, g, b, a)
                UpdateFrames()
            end
            info.swatchFunc = info.opacityFunc
            info.cancelFunc = function()
                c.r, c.g, c.b, c.a = prevR, prevG, prevB, prevA
                fillColorSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
                UpdateFrames()
            end
            ColorPickerFrame:SetupColorPickerAndShow(info)
        end)

        -- Border Color
        local borderColorLabel = frameControls:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        borderColorLabel:SetPoint("TOPLEFT", 0, -190)
        borderColorLabel:SetText("Border Color:")
        local borderColorSwatch = CreateFrame("Button", nil, frameControls)
        borderColorSwatch:SetSize(20, 20)
        borderColorSwatch:SetPoint("LEFT", borderColorLabel, "RIGHT", 10, 0)
        borderColorSwatch.tex = borderColorSwatch:CreateTexture(nil, "OVERLAY")
        borderColorSwatch.tex:SetAllPoints()
        Mixin(borderColorSwatch, BackdropTemplateMixin)
        borderColorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        borderColorSwatch:SetBackdropBorderColor(1, 1, 1)
        borderColorSwatch:SetScript("OnClick", function(self)
            if not selectedFrameIndex then return end
            -- Ensure default exists if old data
            if not UIThingsDB.frames.list[selectedFrameIndex].borderColor then
                UIThingsDB.frames.list[selectedFrameIndex].borderColor = { r = 1, g = 1, b = 1, a = 1 }
            end
            local c = UIThingsDB.frames.list[selectedFrameIndex].borderColor
            local info = UIDropDownMenu_CreateInfo()
            local prevR, prevG, prevB, prevA = c.r, c.g, c.b, c.a
            info.r, info.g, info.b, info.opacity = prevR, prevG, prevB, prevA
            info.hasOpacity = true
            info.opacityFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                c.r, c.g, c.b, c.a = r, g, b, a
                borderColorSwatch.tex:SetColorTexture(r, g, b, a)
                UpdateFrames()
            end
            info.swatchFunc = info.opacityFunc
            info.cancelFunc = function()
                c.r, c.g, c.b, c.a = prevR, prevG, prevB, prevA
                borderColorSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
                UpdateFrames()
            end
            ColorPickerFrame:SetupColorPickerAndShow(info)
        end)

        -- Border Toggles (Cross Layout)
        -- Top: Center Top
        local borderTopBtn = CreateFrame("CheckButton", "UIThingsBorderTopCheck", frameControls,
            "ChatConfigCheckButtonTemplate")
        borderTopBtn:SetPoint("TOPLEFT", 140, -240) -- Moved down and right slightly
        borderTopBtn.tooltip = "Show Top Border"
        borderTopBtn:SetScript("OnClick", function(self)
            if selectedFrameIndex then
                UIThingsDB.frames.list[selectedFrameIndex].showTop = self:GetChecked()
                UpdateFrames()
            end
        end)

        -- Bottom: Below Top with a gap
        local borderBottomBtn = CreateFrame("CheckButton", "UIThingsBorderBottomCheck", frameControls,
            "ChatConfigCheckButtonTemplate")
        borderBottomBtn:SetPoint("TOP", borderTopBtn, "BOTTOM", 0, -24) -- Gap for the 'middle' row
        borderBottomBtn.tooltip = "Show Bottom Border"
        borderBottomBtn:SetScript("OnClick", function(self)
            if selectedFrameIndex then
                UIThingsDB.frames.list[selectedFrameIndex].showBottom = self:GetChecked()
                UpdateFrames()
            end
        end)

        -- Left: Left of the vertical gap center
        local borderLeftBtn = CreateFrame("CheckButton", "UIThingsBorderLeftCheck", frameControls,
            "ChatConfigCheckButtonTemplate")
        -- Align Y with the gap between Top and Bottom. Top is at Y, Bottom is at Y - Height - 24.
        -- Center of gap is approx Y - Height/2 - 12.
        -- Simpler: Anchor to Top Button's Bottom-Left corner, but offset Left and Down
        borderLeftBtn:SetPoint("TOPRIGHT", borderTopBtn, "BOTTOMLEFT", -2, -2)
        borderLeftBtn.tooltip = "Show Left Border"
        borderLeftBtn:SetScript("OnClick", function(self)
            if selectedFrameIndex then
                UIThingsDB.frames.list[selectedFrameIndex].showLeft = self:GetChecked()
                UpdateFrames()
            end
        end)

        -- Right: Right of the vertical gap center
        local borderRightBtn = CreateFrame("CheckButton", "UIThingsBorderRightCheck", frameControls,
            "ChatConfigCheckButtonTemplate")
        borderRightBtn:SetPoint("TOPLEFT", borderTopBtn, "BOTTOMRIGHT", 2, -2)
        borderRightBtn:SetFrameLevel(borderTopBtn:GetFrameLevel() + 5) -- Boost strata to fix "not clickable" issue
        borderRightBtn.tooltip = "Show Right Border"
        borderRightBtn:SetScript("OnClick", function(self)
            if selectedFrameIndex then
                UIThingsDB.frames.list[selectedFrameIndex].showRight = self:GetChecked()
                UpdateFrames()
            end
        end)

        local bordersLabel = frameControls:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        bordersLabel:SetPoint("RIGHT", borderLeftBtn, "LEFT", -10, 0)
        bordersLabel:SetText("Borders:")

        RefreshFrameControls = function()
            if selectedFrameIndex and UIThingsDB.frames.list[selectedFrameIndex] then
                frameControls:Show()
                local f = UIThingsDB.frames.list[selectedFrameIndex]

                nameEdit:SetText(f.name or "")
                lockFrameBtn:SetChecked(f.locked)

                widthSlider:SetValue(f.width)
                _G[widthSlider:GetName() .. 'Text']:SetText("Width") -- Reset text
                widthEdit:SetText(tostring(f.width))                 -- Sync EditBox

                heightSlider:SetValue(f.height)
                _G[heightSlider:GetName() .. 'Text']:SetText("Height")
                heightEdit:SetText(tostring(f.height))

                xSlider:SetValue(f.x)
                _G[xSlider:GetName() .. 'Text']:SetText("X Pos")
                xEdit:SetText(tostring(f.x))

                ySlider:SetValue(f.y)
                _G[ySlider:GetName() .. 'Text']:SetText("Y Pos")
                yEdit:SetText(tostring(f.y))

                borderSlider:SetValue(f.borderSize)
                _G[borderSlider:GetName() .. 'Text']:SetText(string.format("Border: %d", f.borderSize))

                UIDropDownMenu_SetText(strataDropdown, f.strata or "LOW")

                fillColorSwatch.tex:SetColorTexture(f.color.r, f.color.g, f.color.b, f.color.a)

                if f.borderColor then
                    borderColorSwatch.tex:SetColorTexture(f.borderColor.r, f.borderColor.g, f.borderColor.b,
                        f.borderColor.a)
                else
                    borderColorSwatch.tex:SetColorTexture(1, 1, 1, 1)
                end

                -- Borders
                -- Defaults to true (nil -> true)
                borderTopBtn:SetChecked((f.showTop == nil) and true or f.showTop)
                borderBottomBtn:SetChecked((f.showBottom == nil) and true or f.showBottom)
                borderLeftBtn:SetChecked((f.showLeft == nil) and true or f.showLeft)
                borderRightBtn:SetChecked((f.showRight == nil) and true or f.showRight)
            else
                frameControls:Hide()
            end
        end
        addonTable.Config.RefreshFrameControls = RefreshFrameControls

        -- Expose SelectFrame for external use
        function addonTable.Config.SelectFrame(index)
            if index and UIThingsDB.frames.list[index] then
                UIDropDownMenu_SetSelectedID(frameDropdown, index)
                selectedFrameIndex = index
                UpdateDropdownText()
                RefreshFrameControls()
            end
        end

        -- Helper: Create Loot Panel
        local function SetupLootPanel()
            local panel = lootPanel
            local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
            title:SetPoint("TOPLEFT", 16, -16)
            title:SetText("Loot Toasts")

            -- Enable Checkbox
            local enableCheckbox = CreateFrame("CheckButton", "UIThingsLootEnable", panel,
                "ChatConfigCheckButtonTemplate")
            enableCheckbox:SetPoint("TOPLEFT", 20, -50)
            _G[enableCheckbox:GetName() .. "Text"]:SetText("Enable Loot Toasts")
            enableCheckbox:SetChecked(UIThingsDB.loot.enabled)
            enableCheckbox:SetScript("OnClick", function(self)
                UIThingsDB.loot.enabled = self:GetChecked()
                UpdateModuleVisuals(lootPanel, tab5, UIThingsDB.loot.enabled)
                addonTable.Loot.UpdateSettings()
            end)
            UpdateModuleVisuals(lootPanel, tab5, UIThingsDB.loot.enabled)

            -- Show All Checkbox
            local showAllBtn = CreateFrame("CheckButton", "UIThingsLootShowAll", panel, "ChatConfigCheckButtonTemplate")
            showAllBtn:SetPoint("TOPLEFT", 20, -75)
            _G[showAllBtn:GetName() .. "Text"]:SetText("Show All Loot (Party/Raid)")
            showAllBtn:SetChecked(UIThingsDB.loot.showAll)
            showAllBtn:SetScript("OnClick", function(self)
                UIThingsDB.loot.showAll = self:GetChecked()
            end)



            -- Unlock Anchor Button
            local unlockBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
            unlockBtn:SetSize(120, 24)
            unlockBtn:SetPoint("TOPLEFT", 200, -50)
            unlockBtn:SetText("Unlock Anchor")
            unlockBtn:SetScript("OnShow", function(self)
                self:SetText("Unlock Anchor")
            end)
            unlockBtn:SetScript("OnClick", function(self)
                if addonTable.Loot and addonTable.Loot.ToggleAnchor then
                    local isUnlocked = addonTable.Loot.ToggleAnchor()
                    if isUnlocked then
                        self:SetText("Lock Anchor")
                    else
                        self:SetText("Unlock Anchor")
                    end
                end
            end)

            -- Duration Slider
            local durationSlider = CreateFrame("Slider", "UIThingsLootDuration", panel, "OptionsSliderTemplate")
            durationSlider:SetPoint("TOPLEFT", 20, -125)
            durationSlider:SetMinMaxValues(1, 10)
            durationSlider:SetValueStep(0.5)
            durationSlider:SetObeyStepOnDrag(true)
            durationSlider:SetWidth(200)
            _G[durationSlider:GetName() .. 'Text']:SetText("Duration: " .. UIThingsDB.loot.duration .. "s")
            _G[durationSlider:GetName() .. 'Low']:SetText("1s")
            _G[durationSlider:GetName() .. 'High']:SetText("10s")
            durationSlider:SetValue(UIThingsDB.loot.duration)
            durationSlider:SetScript("OnValueChanged", function(self, value)
                value = math.floor(value * 10 + 0.5) / 10
                UIThingsDB.loot.duration = value
                _G[self:GetName() .. 'Text']:SetText("Duration: " .. value .. "s")
            end)

            -- Min Quality Dropdown
            local qualityLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            qualityLabel:SetPoint("TOPLEFT", 20, -175)
            qualityLabel:SetText("Minimum Quality:")

            local qualityDropdown = CreateFrame("Frame", "UIThingsLootQualityDropdown", panel, "UIDropDownMenuTemplate")
            qualityDropdown:SetPoint("TOPLEFT", 140, -165)
            UIDropDownMenu_SetWidth(qualityDropdown, 120)

            local qualities = {
                { text = "|cff9d9d9dPoor|r",      value = 0 },
                { text = "|cffffffffCommon|r",    value = 1 },
                { text = "|cff1eff00Uncommon|r",  value = 2 },
                { text = "|cff0070ddRare|r",      value = 3 },
                { text = "|cffa335eeEpic|r",      value = 4 },
                { text = "|cffff8000Legendary|r", value = 5 },
            }

            local function QualityOnClick(self)
                UIDropDownMenu_SetSelectedValue(qualityDropdown, self.value)
                UIThingsDB.loot.minQuality = self.value
            end

            UIDropDownMenu_Initialize(qualityDropdown, function()
                for _, info in ipairs(qualities) do
                    local inf = UIDropDownMenu_CreateInfo()
                    inf.text = info.text
                    inf.value = info.value
                    inf.func = QualityOnClick
                    inf.checked = (info.value == UIThingsDB.loot.minQuality)
                    UIDropDownMenu_AddButton(inf)
                end
            end)
            UIDropDownMenu_SetSelectedValue(qualityDropdown, UIThingsDB.loot.minQuality)
            -- Initialize text
            for _, q in ipairs(qualities) do
                if q.value == UIThingsDB.loot.minQuality then
                    UIDropDownMenu_SetText(qualityDropdown, q.text)
                    break
                end
            end

            -- Font Dropdown


            local fontLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            fontLabel:SetPoint("TOPLEFT", 20, -225)
            fontLabel:SetText("Font:")

            local fontDropdown = CreateFrame("Frame", "UIThingsLootFontDropdown", panel, "UIDropDownMenuTemplate")
            fontDropdown:SetPoint("TOPLEFT", 60, -215)
            UIDropDownMenu_SetWidth(fontDropdown, 120)

            local function FontOnClick(self)
                UIDropDownMenu_SetSelectedValue(fontDropdown, self.value)
                UIThingsDB.loot.font = self.value
                addonTable.Loot.UpdateSettings()
            end

            UIDropDownMenu_Initialize(fontDropdown, function()
                for _, font in ipairs(fonts) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = font.name
                    info.value = font.path
                    info.func = FontOnClick
                    info.checked = (font.path == UIThingsDB.loot.font)
                    UIDropDownMenu_AddButton(info)
                end
            end)
            UIDropDownMenu_SetSelectedValue(fontDropdown, UIThingsDB.loot.font)
            for _, font in ipairs(fonts) do
                if font.path == UIThingsDB.loot.font then
                    UIDropDownMenu_SetText(fontDropdown, font.name)
                    break
                end
            end

            -- Font Size Slider
            local fontSizeSlider = CreateFrame("Slider", "UIThingsLootFontSize", panel, "OptionsSliderTemplate")
            fontSizeSlider:SetPoint("TOPLEFT", 250, -225)
            fontSizeSlider:SetMinMaxValues(8, 32)
            fontSizeSlider:SetValueStep(1)
            fontSizeSlider:SetObeyStepOnDrag(true)
            fontSizeSlider:SetWidth(150)
            _G[fontSizeSlider:GetName() .. 'Text']:SetText("Font Size: " .. UIThingsDB.loot.fontSize)
            _G[fontSizeSlider:GetName() .. 'Low']:SetText("8")
            _G[fontSizeSlider:GetName() .. 'High']:SetText("32")
            fontSizeSlider:SetValue(UIThingsDB.loot.fontSize)
            fontSizeSlider:SetScript("OnValueChanged", function(self, value)
                value = math.floor(value)
                UIThingsDB.loot.fontSize = value
                _G[self:GetName() .. 'Text']:SetText("Font Size: " .. value)
                addonTable.Loot.UpdateSettings()
            end)

            -- Who Looted Font Size Slider
            local whoLootedFontSizeSlider = CreateFrame("Slider", "UIThingsLootWhoLootedFontSize", panel,
                "OptionsSliderTemplate")
            whoLootedFontSizeSlider:SetPoint("TOPLEFT", 250, -265)
            whoLootedFontSizeSlider:SetMinMaxValues(8, 32)
            whoLootedFontSizeSlider:SetValueStep(1)
            whoLootedFontSizeSlider:SetObeyStepOnDrag(true)
            whoLootedFontSizeSlider:SetWidth(150)
            _G[whoLootedFontSizeSlider:GetName() .. 'Text']:SetText("Who Looted Size: " ..
                (UIThingsDB.loot.whoLootedFontSize or 12))
            _G[whoLootedFontSizeSlider:GetName() .. 'Low']:SetText("8")
            _G[whoLootedFontSizeSlider:GetName() .. 'High']:SetText("32")
            whoLootedFontSizeSlider:SetValue(UIThingsDB.loot.whoLootedFontSize or 12)
            whoLootedFontSizeSlider:SetScript("OnValueChanged", function(self, value)
                value = math.floor(value)
                UIThingsDB.loot.whoLootedFontSize = value
                _G[self:GetName() .. 'Text']:SetText("Who Looted Size: " .. value)
                addonTable.Loot.UpdateSettings()
            end)

            -- Icon Size Slider
            local iconSizeSlider = CreateFrame("Slider", "UIThingsLootIconSize", panel, "OptionsSliderTemplate")
            iconSizeSlider:SetPoint("TOPLEFT", 20, -305)
            iconSizeSlider:SetMinMaxValues(16, 64)
            iconSizeSlider:SetValueStep(2)
            iconSizeSlider:SetObeyStepOnDrag(true)
            iconSizeSlider:SetWidth(200)
            _G[iconSizeSlider:GetName() .. 'Text']:SetText("Icon Size: " .. UIThingsDB.loot.iconSize)
            _G[iconSizeSlider:GetName() .. 'Low']:SetText("16")
            _G[iconSizeSlider:GetName() .. 'High']:SetText("64")
            iconSizeSlider:SetValue(UIThingsDB.loot.iconSize)
            iconSizeSlider:SetScript("OnValueChanged", function(self, value)
                value = math.floor(value)
                UIThingsDB.loot.iconSize = value
                _G[self:GetName() .. 'Text']:SetText("Icon Size: " .. value)
                addonTable.Loot.UpdateSettings()
            end)

            -- Grow Up Checkbox (Moved to bottom)
            local growBtn = CreateFrame("CheckButton", "UIThingsLootGrowCheck", panel, "ChatConfigCheckButtonTemplate")
            growBtn:SetPoint("TOPLEFT", 20, -355)
            _G[growBtn:GetName() .. "Text"]:SetText("Grow Upwards")
            growBtn:SetChecked(UIThingsDB.loot.growUp)
            growBtn:SetScript("OnClick", function(self)
                UIThingsDB.loot.growUp = self:GetChecked()
                addonTable.Loot.UpdateSettings()
            end)

            -- Faster Loot Checkbox
            local fasterLootBtn = CreateFrame("CheckButton", "UIThingsLootFasterCheck", panel,
                "ChatConfigCheckButtonTemplate")
            fasterLootBtn:SetPoint("TOPLEFT", 20, -405)
            _G[fasterLootBtn:GetName() .. "Text"]:SetText("Faster Loot")
            fasterLootBtn:SetChecked(UIThingsDB.loot.fasterLoot)
            fasterLootBtn:SetScript("OnClick", function(self)
                UIThingsDB.loot.fasterLoot = self:GetChecked()
            end)

            -- Faster Loot Delay Slider
            local delaySlider = CreateFrame("Slider", "UIThingsLootDelaySlider", panel, "OptionsSliderTemplate")
            delaySlider:SetPoint("TOPLEFT", 20, -455)
            delaySlider:SetMinMaxValues(0, 1)
            delaySlider:SetValueStep(0.1)
            delaySlider:SetObeyStepOnDrag(true)
            delaySlider:SetWidth(200)

            local currentDelay = UIThingsDB.loot.fasterLootDelay
            _G[delaySlider:GetName() .. 'Text']:SetText("Loot Delay: " .. currentDelay .. "s")
            _G[delaySlider:GetName() .. 'Low']:SetText("0s")
            _G[delaySlider:GetName() .. 'High']:SetText("1s")
            delaySlider:SetValue(currentDelay)

            -- EditBox for Delay
            local delayEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
            delayEdit:SetSize(40, 20)
            delayEdit:SetPoint("LEFT", delaySlider, "RIGHT", 10, 0)
            delayEdit:SetAutoFocus(false)
            delayEdit:SetText(tostring(currentDelay))

            delaySlider:SetScript("OnValueChanged", function(self, value)
                -- Round to 1 decimal
                value = math.floor(value * 10 + 0.5) / 10
                UIThingsDB.loot.fasterLootDelay = value
                _G[self:GetName() .. 'Text']:SetText("Loot Delay: " .. value .. "s")
                if not delayEdit:HasFocus() then
                    delayEdit:SetText(tostring(value))
                end
            end)

            delayEdit:SetScript("OnEnterPressed", function(self)
                local val = tonumber(self:GetText())
                if val then
                    val = math.max(0, math.min(1, val))   -- Clamp 0-1
                    val = math.floor(val * 10 + 0.5) / 10 -- Round

                    UIThingsDB.loot.fasterLootDelay = val
                    delaySlider:SetValue(val)
                    self:SetText(tostring(val))
                    self:ClearFocus()
                else
                    self:SetText(tostring(UIThingsDB.loot.fasterLootDelay))
                    self:ClearFocus()
                end
            end)
        end
        SetupLootPanel()

        -- Helper: Create Misc Panel
        local function SetupMiscPanel()
            local panel = miscPanel
            local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
            title:SetPoint("TOPLEFT", 16, -16)
            title:SetText("Miscellaneous")

            -- Enable Checkbox
            local enableBtn = CreateFrame("CheckButton", "UIThingsMiscEnable", panel, "ChatConfigCheckButtonTemplate")
            enableBtn:SetPoint("TOPLEFT", 20, -50)
            _G[enableBtn:GetName() .. "Text"]:SetText("Enable Misc Module")
            enableBtn:SetChecked(UIThingsDB.misc.enabled)
            enableBtn:SetScript("OnClick", function(self)
                UIThingsDB.misc.enabled = self:GetChecked()
                UpdateModuleVisuals(miscPanel, tab6, UIThingsDB.misc.enabled)
            end)
            UpdateModuleVisuals(miscPanel, tab6, UIThingsDB.misc.enabled)

            -- AH Filter Checkbox
            local ahBtn = CreateFrame("CheckButton", "UIThingsMiscAHFilter", panel, "ChatConfigCheckButtonTemplate")
            ahBtn:SetPoint("TOPLEFT", 20, -100)
            _G[ahBtn:GetName() .. "Text"]:SetText("Auction Current Expansion Only")
            ahBtn:SetChecked(UIThingsDB.misc.ahFilter)
            ahBtn:SetScript("OnClick", function(self)
                UIThingsDB.misc.ahFilter = self:GetChecked()
            end)

            -- Personal Orders Header
            local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            header:SetPoint("TOPLEFT", 20, -150)
            header:SetText("Personal Orders")

            -- Personal Orders Checkbox
            local ordersBtn = CreateFrame("CheckButton", "UIThingsMiscOrdersCheck", panel,
                "ChatConfigCheckButtonTemplate")
            ordersBtn:SetPoint("TOPLEFT", 20, -180)
            _G[ordersBtn:GetName() .. "Text"]:SetText("Enable Personal Order Detection")
            ordersBtn:SetChecked(UIThingsDB.misc.personalOrders)
            ordersBtn:SetScript("OnClick", function(self)
                UIThingsDB.misc.personalOrders = self:GetChecked()
            end)

            -- Alert Duration Slider
            local durSlider = CreateFrame("Slider", "UIThingsMiscAlertDur", panel, "OptionsSliderTemplate")
            durSlider:SetPoint("TOPLEFT", 40, -220)
            durSlider:SetMinMaxValues(1, 10)
            durSlider:SetValueStep(1)
            durSlider:SetObeyStepOnDrag(true)
            durSlider:SetWidth(200)
            _G[durSlider:GetName() .. 'Text']:SetText("Alert Duration: " .. UIThingsDB.misc.alertDuration .. "s")
            _G[durSlider:GetName() .. 'Low']:SetText("1s")
            _G[durSlider:GetName() .. 'High']:SetText("10s")
            durSlider:SetValue(UIThingsDB.misc.alertDuration)
            durSlider:SetScript("OnValueChanged", function(self, value)
                value = math.floor(value)
                UIThingsDB.misc.alertDuration = value
                _G[self:GetName() .. 'Text']:SetText("Alert Duration: " .. value .. "s")
            end)

            -- Alert Color Picker
            local colorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            colorLabel:SetPoint("TOPLEFT", 40, -260)
            colorLabel:SetText("Alert Color:")

            local colorSwatch = CreateFrame("Button", nil, panel)
            colorSwatch:SetSize(20, 20)
            colorSwatch:SetPoint("LEFT", colorLabel, "RIGHT", 10, 0)

            colorSwatch.tex = colorSwatch:CreateTexture(nil, "OVERLAY")
            colorSwatch.tex:SetAllPoints()
            local c = UIThingsDB.misc.alertColor
            colorSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a or 1)

            Mixin(colorSwatch, BackdropTemplateMixin)
            colorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            colorSwatch:SetBackdropBorderColor(1, 1, 1)

            colorSwatch:SetScript("OnClick", function()
                local prevR, prevG, prevB, prevA = c.r, c.g, c.b, c.a

                if ColorPickerFrame.SetupColorPickerAndShow then
                    ColorPickerFrame:SetupColorPickerAndShow({
                        r = c.r,
                        g = c.g,
                        b = c.b,
                        opacity = c.a,
                        hasOpacity = true,
                        swatchFunc = function()
                            local r, g, b = ColorPickerFrame:GetColorRGB()
                            local a = ColorPickerFrame:GetColorAlpha()
                            c.r, c.g, c.b, c.a = r, g, b, a
                            colorSwatch.tex:SetColorTexture(r, g, b, a)
                            UIThingsDB.misc.alertColor = c
                        end,
                        opacityFunc = function()
                            local a = ColorPickerFrame:GetColorAlpha()
                            local r, g, b = ColorPickerFrame:GetColorRGB()
                            c.r, c.g, c.b, c.a = r, g, b, a
                            colorSwatch.tex:SetColorTexture(r, g, b, a)
                            UIThingsDB.misc.alertColor = c
                        end,
                        cancelFunc = function(restore)
                            c.r, c.g, c.b, c.a = prevR, prevG, prevB, prevA
                            colorSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
                            UIThingsDB.misc.alertColor = c
                        end
                    })
                else
                    -- Fallback for older APIs
                    ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
                    ColorPickerFrame.hasOpacity = true
                    ColorPickerFrame.opacity = c.a
                    ColorPickerFrame.func = function()
                        local r, g, b = ColorPickerFrame:GetColorRGB()
                        local a = ColorPickerFrame:GetOpacity()
                        c.r, c.g, c.b, c.a = r, g, b, a
                        colorSwatch.tex:SetColorTexture(r, g, b, a)
                        UIThingsDB.misc.alertColor = c
                    end
                    ColorPickerFrame:Show()
                end
            end)

            -- TTS Section Header
            local ttsHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            ttsHeader:SetPoint("TOPLEFT", 20, -310)
            ttsHeader:SetText("Text-To-Speech")

            -- TTS Enable Checkbox
            local ttsEnableBtn = CreateFrame("CheckButton", "UIThingsMiscTTSEnable", panel,
                "ChatConfigCheckButtonTemplate")
            ttsEnableBtn:SetPoint("TOPLEFT", 20, -340)
            _G[ttsEnableBtn:GetName() .. "Text"]:SetText("Enable Text-To-Speech")
            ttsEnableBtn:SetChecked(UIThingsDB.misc.ttsEnabled)
            ttsEnableBtn:SetScript("OnClick", function(self)
                UIThingsDB.misc.ttsEnabled = self:GetChecked()
            end)

            -- TTS Message
            local ttsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            ttsLabel:SetPoint("TOPLEFT", 40, -380)
            ttsLabel:SetText("TTS Message:")

            local ttsEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
            ttsEdit:SetSize(250, 20)
            ttsEdit:SetPoint("LEFT", ttsLabel, "RIGHT", 10, 0)
            ttsEdit:SetAutoFocus(false)
            ttsEdit:SetText(UIThingsDB.misc.ttsMessage)
            ttsEdit:SetScript("OnEnterPressed", function(self)
                UIThingsDB.misc.ttsMessage = self:GetText()
                self:ClearFocus()
            end)

            -- Test Button (shows full alert)
            local testTTSBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
            testTTSBtn:SetSize(60, 22)
            testTTSBtn:SetPoint("LEFT", ttsEdit, "RIGHT", 5, 0)
            testTTSBtn:SetText("Test")
            testTTSBtn:SetScript("OnClick", function()
                -- Save current text first
                UIThingsDB.misc.ttsMessage = ttsEdit:GetText()
                -- Show full alert (banner + TTS)
                if addonTable.Misc and addonTable.Misc.ShowAlert then
                    addonTable.Misc.ShowAlert()
                end
            end)

            -- TTS Voice Dropdown
            local voiceLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            voiceLabel:SetPoint("TOPLEFT", 40, -420)
            voiceLabel:SetText("Voice Type:")

            local voiceDropdown = CreateFrame("Frame", "UIThingsMiscVoiceDropdown", panel, "UIDropDownMenuTemplate")
            voiceDropdown:SetPoint("LEFT", voiceLabel, "RIGHT", -15, -3)

            local voiceOptions = {
                { text = "Standard",    value = 0 },
                { text = "Alternate 1", value = 1 }
            }

            UIDropDownMenu_SetWidth(voiceDropdown, 120)
            UIDropDownMenu_Initialize(voiceDropdown, function(self, level)
                for _, option in ipairs(voiceOptions) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = option.text
                    info.value = option.value
                    info.func = function(btn)
                        UIThingsDB.misc.ttsVoice = btn.value
                        UIDropDownMenu_SetSelectedValue(voiceDropdown, btn.value)
                    end
                    info.checked = (UIThingsDB.misc.ttsVoice == option.value)
                    UIDropDownMenu_AddButton(info, level)
                end
            end)
            UIDropDownMenu_SetSelectedValue(voiceDropdown, UIThingsDB.misc.ttsVoice or 0)
        end
        SetupMiscPanel()

        -------------------------------------------------------------
        -- TALENT REMINDERS PANEL CONTENT
        -------------------------------------------------------------

        local talentTitle = talentPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        talentTitle:SetPoint("TOPLEFT", 16, -16)
        talentTitle:SetText("Talent Reminders")

        -- Enable Checkbox
        local enableTalentBtn = CreateFrame("CheckButton", "UIThingsTalentEnableCheck", talentPanel,
            "ChatConfigCheckButtonTemplate")
        enableTalentBtn:SetPoint("TOPLEFT", 20, -50)
        _G[enableTalentBtn:GetName() .. "Text"]:SetText("Enable Talent Reminders")
        enableTalentBtn:SetChecked(UIThingsDB.talentReminders.enabled)
        enableTalentBtn:SetScript("OnClick", function(self)
            UIThingsDB.talentReminders.enabled = not not self:GetChecked()
        end)

        -- Alert Settings Section
        CreateSectionHeader(talentPanel, "Alert Settings", -80)

        local showPopupCheck = CreateFrame("CheckButton", "UIThingsTalentShowPopupCheck", talentPanel,
            "ChatConfigCheckButtonTemplate")
        showPopupCheck:SetPoint("TOPLEFT", 20, -105)
        showPopupCheck:SetHitRectInsets(0, -110, 0, 0)
        _G[showPopupCheck:GetName() .. "Text"]:SetText("Show Popup Alert")
        showPopupCheck:SetChecked(UIThingsDB.talentReminders.showPopup)
        showPopupCheck:SetScript("OnClick", function(self)
            UIThingsDB.talentReminders.showPopup = not not self:GetChecked()
        end)

        local showChatCheck = CreateFrame("CheckButton", "UIThingsTalentShowChatCheck", talentPanel,
            "ChatConfigCheckButtonTemplate")
        showChatCheck:SetPoint("TOPLEFT", 200, -105)
        showChatCheck:SetHitRectInsets(0, -120, 0, 0)
        _G[showChatCheck:GetName() .. "Text"]:SetText("Show Chat Message")
        showChatCheck:SetChecked(UIThingsDB.talentReminders.showChatMessage)
        showChatCheck:SetScript("OnClick", function(self)
            UIThingsDB.talentReminders.showChatMessage = not not self:GetChecked()
        end)

        local playSoundCheck = CreateFrame("CheckButton", "UIThingsTalentPlaySoundCheck", talentPanel,
            "ChatConfigCheckButtonTemplate")
        playSoundCheck:SetPoint("TOPLEFT", 20, -130)
        playSoundCheck:SetHitRectInsets(0, -80, 0, 0)
        _G[playSoundCheck:GetName() .. "Text"]:SetText("Play Sound")
        playSoundCheck:SetChecked(UIThingsDB.talentReminders.playSound)
        playSoundCheck:SetScript("OnClick", function(self)
            UIThingsDB.talentReminders.playSound = not not self:GetChecked()
        end)

        -- Alert Frame Appearance Section
        CreateSectionHeader(talentPanel, "Alert Frame", -155)

        -- Width Slider
        local widthSlider = CreateFrame("Slider", "UIThingsTalentWidthSlider", talentPanel,
            "OptionsSliderTemplate")
        widthSlider:SetPoint("TOPLEFT", 20, -180)
        widthSlider:SetMinMaxValues(300, 800)
        widthSlider:SetValueStep(10)
        widthSlider:SetObeyStepOnDrag(true)
        widthSlider:SetWidth(150)
        _G[widthSlider:GetName() .. 'Text']:SetText(string.format("Width: %d",
            UIThingsDB.talentReminders.frameWidth or 400))
        _G[widthSlider:GetName() .. 'Low']:SetText("300")
        _G[widthSlider:GetName() .. 'High']:SetText("800")
        widthSlider:SetValue(UIThingsDB.talentReminders.frameWidth or 400)
        widthSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value)
            UIThingsDB.talentReminders.frameWidth = value
            _G[self:GetName() .. 'Text']:SetText(string.format("Width: %d", value))
            if addonTable.TalentReminder and addonTable.TalentReminder.UpdateVisuals then
                addonTable.TalentReminder.UpdateVisuals()
            end
        end)

        -- Height Slider
        local heightSlider = CreateFrame("Slider", "UIThingsTalentHeightSlider", talentPanel,
            "OptionsSliderTemplate")
        heightSlider:SetPoint("TOPLEFT", 200, -180)
        heightSlider:SetMinMaxValues(200, 600)
        heightSlider:SetValueStep(10)
        heightSlider:SetObeyStepOnDrag(true)
        heightSlider:SetWidth(150)
        _G[heightSlider:GetName() .. 'Text']:SetText(string.format("Height: %d",
            UIThingsDB.talentReminders.frameHeight or 300))
        _G[heightSlider:GetName() .. 'Low']:SetText("200")
        _G[heightSlider:GetName() .. 'High']:SetText("600")
        heightSlider:SetValue(UIThingsDB.talentReminders.frameHeight or 300)
        heightSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value)
            UIThingsDB.talentReminders.frameHeight = value
            _G[self:GetName() .. 'Text']:SetText(string.format("Height: %d", value))
            if addonTable.TalentReminder and addonTable.TalentReminder.UpdateVisuals then
                addonTable.TalentReminder.UpdateVisuals()
            end
        end)

        -- Font Dropdown
        local fontLabel = talentPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fontLabel:SetPoint("TOPLEFT", 380, -183)
        fontLabel:SetText("Font:")

        local fontDropdown = CreateFrame("Frame", "UIThingsTalentFontDropdown", talentPanel, "UIDropDownMenuTemplate")
        fontDropdown:SetPoint("LEFT", fontLabel, "RIGHT", -15, -3)

        local fontOptions = {
            { text = "Friz Quadrata (Default)", value = "Fonts\\FRIZQT__.TTF" },
            { text = "Arial",                   value = "Fonts\\ARIALN.TTF" },
            { text = "Skurri",                  value = "Fonts\\skurri.ttf" },
            { text = "Morpheus",                value = "Fonts\\MORPHEUS.TTF" },
            { text = "Friends",                 value = "Interface\\AddOns\\LunaUITweaks\\Fonts\\Friends.ttf" }
        }

        UIDropDownMenu_SetWidth(fontDropdown, 130)
        UIDropDownMenu_Initialize(fontDropdown, function(self, level)
            for _, option in ipairs(fontOptions) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = option.text
                info.value = option.value
                info.func = function(btn)
                    UIThingsDB.talentReminders.alertFont = btn.value
                    UIDropDownMenu_SetText(fontDropdown, btn:GetText())
                end
                info.checked = (UIThingsDB.talentReminders.alertFont == option.value)
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        -- Set initial text
        for _, option in ipairs(fontOptions) do
            if UIThingsDB.talentReminders.alertFont == option.value then
                UIDropDownMenu_SetText(fontDropdown, option.text)
                break
            end
        end

        -- Font Size Slider
        local fontSizeSlider = CreateFrame("Slider", "UIThingsTalentAlertFontSizeSlider", talentPanel,
            "OptionsSliderTemplate")
        fontSizeSlider:SetPoint("TOPLEFT", 20, -220)
        fontSizeSlider:SetMinMaxValues(8, 24)
        fontSizeSlider:SetValueStep(1)
        fontSizeSlider:SetObeyStepOnDrag(true)
        fontSizeSlider:SetWidth(150)
        local fontSizeText = _G[fontSizeSlider:GetName() .. 'Text']
        local fontSizeLow = _G[fontSizeSlider:GetName() .. 'Low']
        local fontSizeHigh = _G[fontSizeSlider:GetName() .. 'High']
        fontSizeText:SetText(string.format("Font Size: %d", UIThingsDB.talentReminders.alertFontSize))
        fontSizeLow:SetText("8")
        fontSizeHigh:SetText("24")
        fontSizeSlider:SetValue(UIThingsDB.talentReminders.alertFontSize)
        fontSizeSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value)
            UIThingsDB.talentReminders.alertFontSize = value
            fontSizeText:SetText(string.format("Font Size: %d", value))
            print("Font size changed to:", value, "Icon size is:", UIThingsDB.talentReminders.alertIconSize)
            if addonTable.TalentReminder then
                if addonTable.TalentReminder.UpdateVisuals then
                    addonTable.TalentReminder.UpdateVisuals()
                end
                -- Refresh alert content if currently showing
                if addonTable.TalentReminder.RefreshCurrentAlert then
                    addonTable.TalentReminder.RefreshCurrentAlert()
                end
            end
        end)

        -- Icon Size Slider
        local iconSizeSlider = CreateFrame("Slider", "UIThingsTalentAlertIconSizeSlider", talentPanel,
            "OptionsSliderTemplate")
        iconSizeSlider:SetPoint("TOPLEFT", 200, -220)
        iconSizeSlider:SetMinMaxValues(12, 32)
        iconSizeSlider:SetValueStep(2)
        iconSizeSlider:SetObeyStepOnDrag(true)
        iconSizeSlider:SetWidth(150)
        local iconSizeText = _G[iconSizeSlider:GetName() .. 'Text']
        local iconSizeLow = _G[iconSizeSlider:GetName() .. 'Low']
        local iconSizeHigh = _G[iconSizeSlider:GetName() .. 'High']
        iconSizeText:SetText(string.format("Icon Size: %d", UIThingsDB.talentReminders.alertIconSize))
        iconSizeLow:SetText("12")
        iconSizeHigh:SetText("32")
        iconSizeSlider:SetValue(UIThingsDB.talentReminders.alertIconSize)
        iconSizeSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value / 2) * 2 -- Round to nearest even number
            UIThingsDB.talentReminders.alertIconSize = value
            iconSizeText:SetText(string.format("Icon Size: %d", value))
            print("Icon size changed to:", value, "Font size is:", UIThingsDB.talentReminders.alertFontSize)
            if addonTable.TalentReminder then
                if addonTable.TalentReminder.UpdateVisuals then
                    addonTable.TalentReminder.UpdateVisuals()
                end
                -- Refresh alert content if currently showing
                if addonTable.TalentReminder.RefreshCurrentAlert then
                    addonTable.TalentReminder.RefreshCurrentAlert()
                end
            end
        end)

        -- Border & Background Settings
        CreateSectionHeader(talentPanel, "Border & Background", -255)

        -- Row 1: Border
        local borderCheckbox = CreateFrame("CheckButton", "UIThingsTalentBorderCheckbox", talentPanel,
            "ChatConfigCheckButtonTemplate")
        borderCheckbox:SetPoint("TOPLEFT", 20, -280)
        borderCheckbox:SetHitRectInsets(0, -80, 0, 0)
        _G[borderCheckbox:GetName() .. "Text"]:SetText("Show Border")
        borderCheckbox:SetChecked(UIThingsDB.talentReminders.showBorder)
        borderCheckbox:SetScript("OnClick", function(self)
            UIThingsDB.talentReminders.showBorder = not not self:GetChecked()
            if addonTable.TalentReminder and addonTable.TalentReminder.UpdateVisuals then
                addonTable.TalentReminder.UpdateVisuals()
            end
        end)

        local borderColorLabel = talentPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        borderColorLabel:SetPoint("TOPLEFT", 140, -283)
        borderColorLabel:SetText("Color:")

        local borderColorSwatch = CreateFrame("Button", nil, talentPanel)
        borderColorSwatch:SetSize(20, 20)
        borderColorSwatch:SetPoint("LEFT", borderColorLabel, "RIGHT", 5, 0)

        borderColorSwatch.tex = borderColorSwatch:CreateTexture(nil, "OVERLAY")
        borderColorSwatch.tex:SetAllPoints()
        local bc = UIThingsDB.talentReminders.borderColor or { r = 0, g = 0, b = 0, a = 1 }
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
                UIThingsDB.talentReminders.borderColor = bc
                if addonTable.TalentReminder and addonTable.TalentReminder.UpdateVisuals then
                    addonTable.TalentReminder.UpdateVisuals()
                end
            end
            info.swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                bc.r, bc.g, bc.b, bc.a = r, g, b, a
                borderColorSwatch.tex:SetColorTexture(r, g, b, a)
                UIThingsDB.talentReminders.borderColor = bc
                if addonTable.TalentReminder and addonTable.TalentReminder.UpdateVisuals then
                    addonTable.TalentReminder.UpdateVisuals()
                end
            end
            info.cancelFunc = function(previousValues)
                bc.r, bc.g, bc.b, bc.a = prevR, prevG, prevB, prevA
                borderColorSwatch.tex:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
                UIThingsDB.talentReminders.borderColor = bc
                if addonTable.TalentReminder and addonTable.TalentReminder.UpdateVisuals then
                    addonTable.TalentReminder.UpdateVisuals()
                end
            end
            ColorPickerFrame:SetupColorPickerAndShow(info)
        end)

        -- Row 2: Background
        local bgCheckbox = CreateFrame("CheckButton", "UIThingsTalentBgCheckbox", talentPanel,
            "ChatConfigCheckButtonTemplate")
        bgCheckbox:SetPoint("TOPLEFT", 20, -305)
        bgCheckbox:SetHitRectInsets(0, -110, 0, 0)
        _G[bgCheckbox:GetName() .. "Text"]:SetText("Show Background")
        bgCheckbox:SetChecked(UIThingsDB.talentReminders.showBackground)
        bgCheckbox:SetScript("OnClick", function(self)
            UIThingsDB.talentReminders.showBackground = not not self:GetChecked()
            if addonTable.TalentReminder and addonTable.TalentReminder.UpdateVisuals then
                addonTable.TalentReminder.UpdateVisuals()
            end
        end)

        local bgColorLabel = talentPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        bgColorLabel:SetPoint("TOPLEFT", 165, -308)
        bgColorLabel:SetText("Color:")

        local bgColorSwatch = CreateFrame("Button", nil, talentPanel)
        bgColorSwatch:SetSize(20, 20)
        bgColorSwatch:SetPoint("LEFT", bgColorLabel, "RIGHT", 5, 0)

        bgColorSwatch.tex = bgColorSwatch:CreateTexture(nil, "OVERLAY")
        bgColorSwatch.tex:SetAllPoints()
        local c = UIThingsDB.talentReminders.backgroundColor or { r = 0, g = 0, b = 0, a = 0.8 }
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
                UIThingsDB.talentReminders.backgroundColor = c
                if addonTable.TalentReminder and addonTable.TalentReminder.UpdateVisuals then
                    addonTable.TalentReminder.UpdateVisuals()
                end
            end
            info.swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                c.r, c.g, c.b, c.a = r, g, b, a
                bgColorSwatch.tex:SetColorTexture(r, g, b, a)
                UIThingsDB.talentReminders.backgroundColor = c
                if addonTable.TalentReminder and addonTable.TalentReminder.UpdateVisuals then
                    addonTable.TalentReminder.UpdateVisuals()
                end
            end
            info.cancelFunc = function(previousValues)
                c.r, c.g, c.b, c.a = prevR, prevG, prevB, prevA
                bgColorSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
                UIThingsDB.talentReminders.backgroundColor = c
                if addonTable.TalentReminder and addonTable.TalentReminder.UpdateVisuals then
                    addonTable.TalentReminder.UpdateVisuals()
                end
            end
            ColorPickerFrame:SetupColorPickerAndShow(info)
        end)

        -- Difficulty Filter Section
        CreateSectionHeader(talentPanel, "Alert Only On These Difficulties", -335)

        -- Helper function to handle difficulty checkbox changes
        local function OnDifficultyCheckChanged(wasEnabled, isNowEnabled)
            if not addonTable.TalentReminder then return end

            -- Get current difficulty to see if it matches the one that changed
            local _, _, currentDifficultyID = GetInstanceInfo()

            if wasEnabled and not isNowEnabled then
                -- Difficulty was just disabled - hide alert if shown
                local alertFrame = _G["LunaTalentReminderAlert"]
                if alertFrame and alertFrame:IsShown() then
                    alertFrame:Hide()
                end
            elseif not wasEnabled and isNowEnabled then
                -- Difficulty was just enabled - check talents after a short delay
                addonTable.Core.SafeAfter(0.5, function()
                    if addonTable.TalentReminder.CheckTalentsInInstance then
                        addonTable.TalentReminder.CheckTalentsInInstance()
                    end
                end)
            end
        end

        -- Dungeons
        local dungeonLabel = talentPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        dungeonLabel:SetPoint("TOPLEFT", 20, -363)
        dungeonLabel:SetText("Dungeons:")

        local dNormalCheck = CreateFrame("CheckButton", "UIThingsTalentDNormalCheck", talentPanel,
            "ChatConfigCheckButtonTemplate")
        dNormalCheck:SetPoint("TOPLEFT", 100, -360)
        dNormalCheck:SetHitRectInsets(0, -60, 0, 0)
        _G[dNormalCheck:GetName() .. "Text"]:SetText("Normal")
        dNormalCheck:SetChecked(UIThingsDB.talentReminders.alertOnDifficulties.dungeonNormal)
        dNormalCheck:SetScript("OnClick", function(self)
            local wasEnabled = UIThingsDB.talentReminders.alertOnDifficulties.dungeonNormal
            local isNowEnabled = not not self:GetChecked()
            UIThingsDB.talentReminders.alertOnDifficulties.dungeonNormal = isNowEnabled
            OnDifficultyCheckChanged(wasEnabled, isNowEnabled)
        end)

        local dHeroicCheck = CreateFrame("CheckButton", "UIThingsTalentDHeroicCheck", talentPanel,
            "ChatConfigCheckButtonTemplate")
        dHeroicCheck:SetPoint("LEFT", dNormalCheck, "RIGHT", 70, 0)
        dHeroicCheck:SetHitRectInsets(0, -60, 0, 0)
        _G[dHeroicCheck:GetName() .. "Text"]:SetText("Heroic")
        dHeroicCheck:SetChecked(UIThingsDB.talentReminders.alertOnDifficulties.dungeonHeroic)
        dHeroicCheck:SetScript("OnClick", function(self)
            local wasEnabled = UIThingsDB.talentReminders.alertOnDifficulties.dungeonHeroic
            local isNowEnabled = not not self:GetChecked()
            UIThingsDB.talentReminders.alertOnDifficulties.dungeonHeroic = isNowEnabled
            OnDifficultyCheckChanged(wasEnabled, isNowEnabled)
        end)

        local dMythicCheck = CreateFrame("CheckButton", "UIThingsTalentDMythicCheck", talentPanel,
            "ChatConfigCheckButtonTemplate")
        dMythicCheck:SetPoint("LEFT", dHeroicCheck, "RIGHT", 70, 0)
        dMythicCheck:SetHitRectInsets(0, -60, 0, 0)
        _G[dMythicCheck:GetName() .. "Text"]:SetText("Mythic")
        dMythicCheck:SetChecked(UIThingsDB.talentReminders.alertOnDifficulties.dungeonMythic)
        dMythicCheck:SetScript("OnClick", function(self)
            local wasEnabled = UIThingsDB.talentReminders.alertOnDifficulties.dungeonMythic
            local isNowEnabled = not not self:GetChecked()
            UIThingsDB.talentReminders.alertOnDifficulties.dungeonMythic = isNowEnabled
            OnDifficultyCheckChanged(wasEnabled, isNowEnabled)
        end)

        -- Raids
        local raidLabel = talentPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        raidLabel:SetPoint("TOPLEFT", 20, -393)
        raidLabel:SetText("Raids:")

        local rLFRCheck = CreateFrame("CheckButton", "UIThingsTalentRLFRCheck", talentPanel,
            "ChatConfigCheckButtonTemplate")
        rLFRCheck:SetPoint("TOPLEFT", 100, -390)
        rLFRCheck:SetHitRectInsets(0, -40, 0, 0)
        _G[rLFRCheck:GetName() .. "Text"]:SetText("LFR")
        rLFRCheck:SetChecked(UIThingsDB.talentReminders.alertOnDifficulties.raidLFR)
        rLFRCheck:SetScript("OnClick", function(self)
            local wasEnabled = UIThingsDB.talentReminders.alertOnDifficulties.raidLFR
            local isNowEnabled = not not self:GetChecked()
            UIThingsDB.talentReminders.alertOnDifficulties.raidLFR = isNowEnabled
            OnDifficultyCheckChanged(wasEnabled, isNowEnabled)
        end)

        local rNormalCheck = CreateFrame("CheckButton", "UIThingsTalentRNormalCheck", talentPanel,
            "ChatConfigCheckButtonTemplate")
        rNormalCheck:SetPoint("LEFT", rLFRCheck, "RIGHT", 50, 0)
        rNormalCheck:SetHitRectInsets(0, -60, 0, 0)
        _G[rNormalCheck:GetName() .. "Text"]:SetText("Normal")
        rNormalCheck:SetChecked(UIThingsDB.talentReminders.alertOnDifficulties.raidNormal)
        rNormalCheck:SetScript("OnClick", function(self)
            local wasEnabled = UIThingsDB.talentReminders.alertOnDifficulties.raidNormal
            local isNowEnabled = not not self:GetChecked()
            UIThingsDB.talentReminders.alertOnDifficulties.raidNormal = isNowEnabled
            OnDifficultyCheckChanged(wasEnabled, isNowEnabled)
        end)

        local rHeroicCheck = CreateFrame("CheckButton", "UIThingsTalentRHeroicCheck", talentPanel,
            "ChatConfigCheckButtonTemplate")
        rHeroicCheck:SetPoint("LEFT", rNormalCheck, "RIGHT", 70, 0)
        rHeroicCheck:SetHitRectInsets(0, -60, 0, 0)
        _G[rHeroicCheck:GetName() .. "Text"]:SetText("Heroic")
        rHeroicCheck:SetChecked(UIThingsDB.talentReminders.alertOnDifficulties.raidHeroic)
        rHeroicCheck:SetScript("OnClick", function(self)
            local wasEnabled = UIThingsDB.talentReminders.alertOnDifficulties.raidHeroic
            local isNowEnabled = not not self:GetChecked()
            UIThingsDB.talentReminders.alertOnDifficulties.raidHeroic = isNowEnabled
            OnDifficultyCheckChanged(wasEnabled, isNowEnabled)
        end)

        local rMythicCheck = CreateFrame("CheckButton", "UIThingsTalentRMythicCheck", talentPanel,
            "ChatConfigCheckButtonTemplate")
        rMythicCheck:SetPoint("LEFT", rHeroicCheck, "RIGHT", 70, 0)
        rMythicCheck:SetHitRectInsets(0, -60, 0, 0)
        _G[rMythicCheck:GetName() .. "Text"]:SetText("Mythic")
        rMythicCheck:SetChecked(UIThingsDB.talentReminders.alertOnDifficulties.raidMythic)
        rMythicCheck:SetScript("OnClick", function(self)
            local wasEnabled = UIThingsDB.talentReminders.alertOnDifficulties.raidMythic
            local isNowEnabled = not not self:GetChecked()
            UIThingsDB.talentReminders.alertOnDifficulties.raidMythic = isNowEnabled
            OnDifficultyCheckChanged(wasEnabled, isNowEnabled)
        end)

        -- Reminders Section
        CreateSectionHeader(talentPanel, "Saved Builds", -420)

        -- Reminder List (Scroll Frame)
        local reminderScrollFrame = CreateFrame("ScrollFrame", "UIThingsTalentReminderScroll", talentPanel,
            "UIPanelScrollFrameTemplate")
        reminderScrollFrame:SetSize(520, 215)
        reminderScrollFrame:SetPoint("TOPLEFT", 20, -445)

        local reminderContent = CreateFrame("Frame", nil, reminderScrollFrame)
        reminderContent:SetSize(500, 1)
        reminderScrollFrame:SetScrollChild(reminderContent)

        -- Track created rows for reuse
        local reminderRows = {}

        -- Refresh reminder list function (frame-based)
        local function RefreshReminderList()
            -- Get current class/spec for filtering
            local _, _, playerClassID = UnitClass("player")
            local specIndex = GetSpecialization()
            local playerSpecID = specIndex and select(1, GetSpecializationInfo(specIndex))

            -- Get current instance info
            local _, currentInstanceType, currentDifficultyID, _, _, _, _, currentInstanceID = GetInstanceInfo()

            -- Get current zone for zone-specific highlighting
            local currentZone = addonTable.TalentReminder and addonTable.TalentReminder.GetCurrentZone() or nil

            -- Hide all existing rows first
            for _, row in ipairs(reminderRows) do
                row:Hide()
            end

            local rowIndex = 0
            local yOffset = -5

            -- Helper function to compare talent builds for equality
            local function TalentBuildsEqual(talents1, talents2)
                if not talents1 or not talents2 then return false end

                -- Check if same number of talents
                local count1, count2 = 0, 0
                for _ in pairs(talents1) do count1 = count1 + 1 end
                for _ in pairs(talents2) do count2 = count2 + 1 end
                if count1 ~= count2 then return false end

                -- Check each talent matches
                for nodeID, data1 in pairs(talents1) do
                    local data2 = talents2[nodeID]
                    if not data2 then return false end
                    if data1.entryID ~= data2.entryID then return false end
                    if data1.rank ~= data2.rank then return false end
                end

                return true
            end

            -- First pass: collect and group reminders by identical builds
            local sortedReminders = {}

            if LunaUITweaks_TalentReminders and LunaUITweaks_TalentReminders.reminders then
                for instanceID, reminders in pairs(LunaUITweaks_TalentReminders.reminders) do
                    for diffID, diffReminders in pairs(reminders) do
                        for zoneKey, reminder in pairs(diffReminders) do
                            -- Filter: only show reminders for current class/spec OR unknown
                            local showReminder = true
                            if reminder.classID and reminder.classID ~= playerClassID then
                                showReminder = false
                            elseif reminder.specID and reminder.specID ~= playerSpecID then
                                showReminder = false
                            end

                            if showReminder then
                                -- Check if this reminder matches current instance/difficulty/zone
                                local isCurrentZone = false
                                if currentInstanceID and currentInstanceID ~= 0 and
                                    currentDifficultyID and
                                    currentZone and currentZone ~= "" then
                                    isCurrentZone = (tonumber(instanceID) == tonumber(currentInstanceID) and
                                        tonumber(diffID) == tonumber(currentDifficultyID) and
                                        zoneKey == currentZone)
                                end

                                -- Try to find existing entry with same instance, zone, and talents
                                local foundMatch = false
                                for _, existing in ipairs(sortedReminders) do
                                    if tonumber(existing.instanceID) == tonumber(instanceID) and
                                        existing.zoneKey == zoneKey and
                                        TalentBuildsEqual(existing.reminder.talents, reminder.talents) then
                                        -- Same build - add this difficulty to the list
                                        table.insert(existing.difficulties, {
                                            diffID = diffID,
                                            difficultyName = reminder.difficulty or "Unknown",
                                            isCurrentZone = isCurrentZone
                                        })
                                        -- Update overall isCurrentZone if any difficulty matches
                                        existing.isCurrentZone = existing.isCurrentZone or isCurrentZone
                                        foundMatch = true
                                        break
                                    end
                                end

                                if not foundMatch then
                                    -- New unique build
                                    table.insert(sortedReminders, {
                                        instanceID = instanceID,
                                        zoneKey = zoneKey,
                                        reminder = reminder,
                                        isCurrentZone = isCurrentZone,
                                        difficulties = { {
                                            diffID = diffID,
                                            difficultyName = reminder.difficulty or "Unknown",
                                            isCurrentZone = isCurrentZone
                                        } }
                                    })
                                end
                            end
                        end
                    end
                end

                -- Sort: current zone first, then alphabetically by name
                table.sort(sortedReminders, function(a, b)
                    if a.isCurrentZone ~= b.isCurrentZone then
                        return a.isCurrentZone
                    end
                    return (a.reminder.name or "") < (b.reminder.name or "")
                end)
            end

            -- Second pass: display sorted reminders
            for _, entry in ipairs(sortedReminders) do
                local instanceID = entry.instanceID
                local zoneKey = entry.zoneKey
                local reminder = entry.reminder
                local isCurrentZone = entry.isCurrentZone
                local difficulties = entry.difficulties

                rowIndex = rowIndex + 1

                -- Create or reuse row frame
                local row = reminderRows[rowIndex]
                if not row then
                    row = CreateFrame("Frame", nil, reminderContent)
                    row:SetSize(490, 50)

                    -- Background for highlighting
                    row.bg = row:CreateTexture(nil, "BACKGROUND")
                    row.bg:SetAllPoints()
                    row.bg:SetColorTexture(0, 0, 0, 0)

                    -- Class/Spec label
                    row.classSpecLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    row.classSpecLabel:SetPoint("TOPLEFT", 5, -2)
                    row.classSpecLabel:SetWidth(350)
                    row.classSpecLabel:SetJustifyH("LEFT")

                    -- Reminder name
                    row.nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    row.nameLabel:SetPoint("TOPLEFT", 5, -15)
                    row.nameLabel:SetWidth(350)
                    row.nameLabel:SetJustifyH("LEFT")

                    -- Instance/Difficulty
                    row.infoLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    row.infoLabel:SetPoint("TOPLEFT", 10, -30)
                    row.infoLabel:SetWidth(350)
                    row.infoLabel:SetJustifyH("LEFT")

                    -- Validation status icon/text
                    row.validationLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    row.validationLabel:SetPoint("TOPRIGHT", -85, -15)
                    row.validationLabel:SetWidth(100)
                    row.validationLabel:SetJustifyH("RIGHT")

                    -- Delete button
                    row.deleteBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                    row.deleteBtn:SetSize(60, 22)
                    row.deleteBtn:SetPoint("RIGHT", -10, 0)
                    row.deleteBtn:SetText("Delete")
                    row.deleteBtn:SetNormalFontObject("GameFontNormalSmall")

                    reminderRows[rowIndex] = row
                end

                -- Position row
                row:ClearAllPoints()
                row:SetSize(490, 50) -- Ensure consistent size (may have been 100 if used for message)
                row:SetPoint("TOPLEFT", 0, yOffset)
                yOffset = yOffset - 55

                -- Create background if it doesn't exist (for rows created before this feature)
                if not row.bg then
                    row.bg = row:CreateTexture(nil, "BACKGROUND")
                    row.bg:SetAllPoints()
                end

                -- Ensure all labels exist (in case this was previously a message row)
                if not row.nameLabel then
                    row.nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    row.nameLabel:SetPoint("TOPLEFT", 5, -15)
                    row.nameLabel:SetWidth(350)
                    row.nameLabel:SetJustifyH("LEFT")
                else
                    -- Reset font in case this was previously a message row with different font
                    row.nameLabel:SetFontObject("GameFontNormal")
                end
                if not row.classSpecLabel then
                    row.classSpecLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    row.classSpecLabel:SetPoint("TOPLEFT", 5, -2)
                    row.classSpecLabel:SetWidth(350)
                    row.classSpecLabel:SetJustifyH("LEFT")
                end
                if not row.infoLabel then
                    row.infoLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    row.infoLabel:SetPoint("TOPLEFT", 10, -30)
                    row.infoLabel:SetWidth(350)
                    row.infoLabel:SetJustifyH("LEFT")
                end
                if not row.validationLabel then
                    row.validationLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    row.validationLabel:SetPoint("TOPRIGHT", -85, -15)
                    row.validationLabel:SetWidth(100)
                    row.validationLabel:SetJustifyH("RIGHT")
                end
                if not row.deleteBtn then
                    row.deleteBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                    row.deleteBtn:SetSize(60, 22)
                    row.deleteBtn:SetPoint("RIGHT", -10, 0)
                    row.deleteBtn:SetText("Delete")
                    row.deleteBtn:SetNormalFontObject("GameFontNormalSmall")
                end

                -- Show all reminder elements (in case they were hidden when used as message row)
                row.nameLabel:Show()
                row.classSpecLabel:Show()
                row.infoLabel:Show()
                row.validationLabel:Show()
                row.deleteBtn:Show()

                -- Hide message label if it exists
                if row.messageLabel then
                    row.messageLabel:Hide()
                end

                -- Highlight current zone with green background
                if isCurrentZone then
                    row.bg:SetColorTexture(0, 0.3, 0, 0.3)
                    row.nameLabel:SetText(string.format("|cFF00FF00%s|r", reminder.name))
                else
                    row.bg:SetColorTexture(0, 0, 0, 0)
                    row.nameLabel:SetText(string.format("|cFFFFAA00%s|r", reminder.name))
                end

                -- Set data
                row.classSpecLabel:SetText(addonTable.TalentReminder.GetClassSpecString(reminder))

                -- Build difficulty list
                local difficultyText
                if #difficulties == 1 then
                    difficultyText = difficulties[1].difficultyName
                else
                    -- Sort difficulties alphabetically
                    local diffNames = {}
                    for _, diff in ipairs(difficulties) do
                        table.insert(diffNames, diff.difficultyName)
                    end
                    table.sort(diffNames)
                    difficultyText = table.concat(diffNames, ", ")
                end

                -- Show zone and "CURRENT ZONE" indicator on a separate line
                local infoText = string.format("Instance: %s | Diff: %s",
                    reminder.instanceName or "Unknown",
                    difficultyText)
                if isCurrentZone then
                    infoText = infoText .. " |cFF00FF00- CURRENT ZONE|r"
                end
                row.infoLabel:SetText(infoText)

                -- Validate build
                local isValid, invalidTalents = addonTable.TalentReminder.ValidateTalentBuild(reminder.talents)
                if not isValid and #invalidTalents > 0 then
                    row.validationLabel:SetText("|cFFFF0000Invalid Build|r")
                    row.validationLabel:SetPoint("TOPRIGHT", -85, -15)
                else
                    row.validationLabel:SetText("")
                end

                -- Set delete button action (store all difficulties)
                row.deleteBtn.instanceID = instanceID
                row.deleteBtn.zoneKey = zoneKey
                row.deleteBtn.difficulties = difficulties
                row.deleteBtn:SetScript("OnClick", function(self)
                    -- If multiple difficulties, show count in confirmation
                    local confirmText = reminder.name
                    if #self.difficulties > 1 then
                        confirmText = confirmText .. " (" .. #self.difficulties .. " difficulties)"
                    end

                    StaticPopup_Show("LUNA_TALENT_DELETE_GROUP_CONFIRM", confirmText, nil, {
                        instanceID = self.instanceID,
                        zoneKey = self.zoneKey,
                        difficulties = self.difficulties
                    })
                end)

                row:Show()
            end

            -- Show "no reminders" message if empty
            if rowIndex == 0 then
                local row = reminderRows[1]
                if not row then
                    row = CreateFrame("Frame", nil, reminderContent)
                    row:SetSize(490, 100)
                    reminderRows[1] = row
                end

                -- Create or update message label
                if not row.messageLabel then
                    row.messageLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    row.messageLabel:SetPoint("TOPLEFT", 5, -5)
                    row.messageLabel:SetWidth(480)
                    row.messageLabel:SetJustifyH("LEFT")
                end

                -- Hide all reminder-specific elements if they exist
                if row.classSpecLabel then row.classSpecLabel:Hide() end
                if row.nameLabel then row.nameLabel:Hide() end
                if row.infoLabel then row.infoLabel:Hide() end
                if row.validationLabel then row.validationLabel:Hide() end
                if row.deleteBtn then row.deleteBtn:Hide() end
                if row.bg then row.bg:SetColorTexture(0, 0, 0, 0) end

                row:SetPoint("TOPLEFT", 0, -5)
                row.messageLabel:SetText(
                    "|cFFAAAAAANo reminders saved for your current class/spec.\n\n" ..
                    "Enter a dungeon or raid, configure your talents, then click " ..
                    "'Snapshot Current Talents' below.|r")
                row.messageLabel:Show()
                row:Show()
            end

            -- Update scroll child height
            local contentHeight = math.max(215, math.abs(yOffset) + 5)
            reminderContent:SetHeight(contentHeight)
        end

        -- Assign to upvalue so TabOnClick can access it
        refreshTalentReminderList = RefreshReminderList

        -- Function to check if player is in an instance
        local function IsInInstance()
            local _, instanceType = GetInstanceInfo()
            return instanceType ~= "none"
        end

        RefreshReminderList()

        -- Declare buttons upfront
        local snapshotBtn
        local testBtn

        -- Function to update button states based on instance status
        local function UpdateButtonStates()
            local inInstance = IsInInstance()
            if snapshotBtn then
                if inInstance then
                    snapshotBtn:Enable()
                    snapshotBtn:SetAlpha(1.0)
                else
                    snapshotBtn:Disable()
                    snapshotBtn:SetAlpha(0.5)
                end
            end
            if testBtn then
                if inInstance then
                    testBtn:Enable()
                    testBtn:SetAlpha(1.0)
                else
                    testBtn:Disable()
                    testBtn:SetAlpha(0.5)
                end
            end
        end

        -- Snapshot Button
        snapshotBtn = CreateFrame("Button", nil, talentPanel, "GameMenuButtonTemplate")
        snapshotBtn:SetSize(200, 30)
        snapshotBtn:SetPoint("BOTTOMLEFT", 20, 10)
        snapshotBtn:SetText("Snapshot Current Talents")
        snapshotBtn:SetNormalFontObject("GameFontNormal")
        snapshotBtn:SetHighlightFontObject("GameFontHighlight")
        snapshotBtn:SetScript("OnClick", function(self)
            if not addonTable.TalentReminder then
                return
            end

            local location = addonTable.TalentReminder.GetCurrentLocation()
            if not location or location.instanceID == 0 then
                return
            end

            -- Use zone name as the unique identifier for this boss area
            local zoneName = location.zoneName or "general"

            -- Create a descriptive name for the reminder
            local name
            if zoneName == "general" or not zoneName then
                name = string.format("%s (%s)", location.instanceName, location.difficultyName)
            else
                name = string.format("%s - %s (%s)", location.instanceName, zoneName, location.difficultyName)
            end

            local success, err, count = addonTable.TalentReminder.SaveReminder(
                location.instanceID,
                location.difficultyID,
                zoneName, -- Use zone name instead of boss/encounter ID
                name,
                location.instanceName,
                location.difficultyName,
                "" -- Note (could add edit box for this)
            )

            if success then
                RefreshReminderList()
            end
        end)

        -- Test Button
        testBtn = CreateFrame("Button", nil, talentPanel, "GameMenuButtonTemplate")
        testBtn:SetSize(120, 30)
        testBtn:SetPoint("LEFT", snapshotBtn, "RIGHT", 10, 0)
        testBtn:SetText("Test")
        testBtn:SetNormalFontObject("GameFontNormal")
        testBtn:SetHighlightFontObject("GameFontHighlight")
        testBtn:SetScript("OnClick", function(self)
            if not addonTable.TalentReminder then
                return
            end

            if not LunaUITweaks_TalentReminders or not LunaUITweaks_TalentReminders.reminders then
                return
            end

            -- Get current zone for debugging
            local currentZone = addonTable.TalentReminder.GetCurrentZone()
            local location = addonTable.TalentReminder.GetCurrentLocation()

            print("|cFF00FF00[Talent Reminder Test]|r")
            print(string.format("  Current Zone: |cFFFFFF00%s|r", currentZone or "nil"))
            print(string.format("  Instance: |cFFFFFF00%s|r (ID: %s)",
                location and location.instanceName or "Unknown",
                location and location.instanceID or "nil"))
            print(string.format("  Difficulty: |cFFFFFF00%s|r (ID: %s)",
                location and location.difficultyName or "Unknown",
                location and location.difficultyID or "nil"))

            -- Get current class/spec
            local _, _, classID = UnitClass("player")
            local specIndex = GetSpecialization()
            local specID = specIndex and select(1, GetSpecializationInfo(specIndex))

            local currentInstanceID = location and location.instanceID or 0
            local currentDifficultyID = location and location.difficultyID or 0

            print("  Checking reminders for CURRENT instance/difficulty/class/spec only:")

            local foundMismatch = false
            local checkedCount = 0
            local skippedCount = 0

            -- Only check reminders for current instance and difficulty
            if LunaUITweaks_TalentReminders.reminders[currentInstanceID] and
                LunaUITweaks_TalentReminders.reminders[currentInstanceID][currentDifficultyID] then
                local zoneReminders = LunaUITweaks_TalentReminders.reminders[currentInstanceID][currentDifficultyID]

                -- Build priority list: current zone first, then general
                local priorityList = {}

                if currentZone and currentZone ~= "" and zoneReminders[currentZone] then
                    table.insert(priorityList,
                        { zoneKey = currentZone, reminder = zoneReminders[currentZone], priority = 1 })
                end

                if zoneReminders["general"] then
                    table.insert(priorityList, { zoneKey = "general", reminder = zoneReminders["general"], priority = 2 })
                end

                table.sort(priorityList, function(a, b) return a.priority < b.priority end)

                for _, entry in ipairs(priorityList) do
                    local zoneKey = entry.zoneKey
                    local reminder = entry.reminder

                    -- Filter by class/spec - skip if doesn't match
                    if reminder.classID and reminder.classID ~= classID then
                        skippedCount = skippedCount + 1
                    elseif reminder.specID and reminder.specID ~= specID then
                        skippedCount = skippedCount + 1
                    else
                        checkedCount = checkedCount + 1

                        -- Show what we're checking
                        print(string.format("    - Reminder: |cFFFFAA00%s|r (Zone: |cFFFFFF00%s|r)",
                            reminder.name or "Unknown", zoneKey))

                        local mismatches = addonTable.TalentReminder.CompareTalents(reminder.talents)
                        if #mismatches > 0 then
                            print(string.format("      |cFF00FF00✓ Found %d talent mismatches - showing alert|r",
                                #mismatches))
                            addonTable.TalentReminder.ShowAlert(reminder, mismatches, zoneKey)
                            foundMismatch = true
                            break
                        else
                            print("      |cFFAAAA00○ Talents match - no alert needed|r")
                        end
                    end
                end
            end

            print(string.format("  Checked: %d | Skipped (wrong class/spec/instance/diff): %d", checkedCount,
                skippedCount))

            if not foundMismatch and checkedCount > 0 then
                print("  |cFFFF6B6BNo talent mismatches found in matching reminders.|r")
            elseif checkedCount == 0 then
                print("  |cFFFF6B6BNo reminders found for current instance/difficulty/class/spec.|r")
            end
        end)

        -- Clear All Button (clears current class/spec only)
        local clearBtn = CreateFrame("Button", nil, talentPanel, "GameMenuButtonTemplate")
        clearBtn:SetSize(120, 30)
        clearBtn:SetPoint("LEFT", testBtn, "RIGHT", 10, 0)
        clearBtn:SetText("Clear All")
        clearBtn:SetNormalFontObject("GameFontNormal")
        clearBtn:SetHighlightFontObject("GameFontHighlight")
        clearBtn:SetScript("OnClick", function(self)
            local _, _, classID = UnitClass("player")
            local specIndex = GetSpecialization()
            local specID = specIndex and select(1, GetSpecializationInfo(specIndex))
            local _, specName = specIndex and GetSpecializationInfo(specIndex) or nil, nil

            StaticPopup_Show("LUNA_TALENT_CLEAR_CONFIRM", specName or "Unknown Spec", nil, {
                classID = classID,
                specID = specID
            })
        end)

        -- Confirmation dialog for clear all (current class/spec)
        StaticPopupDialogs["LUNA_TALENT_CLEAR_CONFIRM"] = {
            text = "Are you sure you want to delete ALL talent reminders for %s?",
            button1 = "Yes",
            button2 = "No",
            OnAccept = function(self, data)
                if LunaUITweaks_TalentReminders and LunaUITweaks_TalentReminders.reminders then
                    -- Delete only reminders matching current class/spec
                    local deleteCount = 0
                    for instanceID, reminders in pairs(LunaUITweaks_TalentReminders.reminders) do
                        for diffID, diffReminders in pairs(reminders) do
                            for bossID, reminder in pairs(diffReminders) do
                                local shouldDelete = false
                                if not reminder.classID and not reminder.specID then
                                    -- Unknown class/spec - don't delete
                                    shouldDelete = false
                                elseif reminder.classID == data.classID and reminder.specID == data.specID then
                                    -- Matches current class and spec
                                    shouldDelete = true
                                end

                                if shouldDelete then
                                    diffReminders[bossID] = nil
                                    deleteCount = deleteCount + 1
                                end
                            end
                        end
                    end

                    if refreshTalentReminderList then
                        refreshTalentReminderList()
                    end
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }

        StaticPopupDialogs["LUNA_TALENT_DELETE_GROUP_CONFIRM"] = {
            text = "Delete talent reminder:\n\n%s",
            button1 = "Delete",
            button2 = "Cancel",
            OnAccept = function(self, data)
                if addonTable.TalentReminder then
                    -- Delete all difficulties for this build
                    for _, diff in ipairs(data.difficulties) do
                        addonTable.TalentReminder.DeleteReminder(
                            data.instanceID,
                            diff.diffID,
                            data.zoneKey
                        )
                    end
                    if refreshTalentReminderList then
                        refreshTalentReminderList()
                    end
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }

        -- Set up event listener to update button states when entering/leaving instances
        local instanceCheckFrame = CreateFrame("Frame", nil, talentPanel)
        instanceCheckFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        instanceCheckFrame:SetScript("OnEvent", function(self, event)
            UpdateButtonStates()
        end)

        -- Initial button state update
        UpdateButtonStates()
    end
end

function addonTable.Config.ToggleWindow()
    if not configWindow then
        addonTable.Config.Initialize()
    end

    if configWindow:IsShown() then
        configWindow:Hide()
    else
        configWindow:Show()
    end
end
