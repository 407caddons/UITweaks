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
                r = r, g = g, b = b,
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
            {name="Friz Quadrata", path="Fonts\\FRIZQT__.TTF"},
            {name="Arial Narrow", path="Fonts\\ARIALN.TTF"},
            {name="Skurri", path="Fonts\\skurri.ttf"},
            {name="Morpheus", path="Fonts\\MORPHEUS.TTF"}
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

        configWindow.Tabs = {tab1, tab2, tab3, tab4, tab5, tab6}
        PanelTemplates_SetNumTabs(configWindow, 6)
        PanelTemplates_SetTab(configWindow, 1)

        local function TabOnClick(self)
             PanelTemplates_SetTab(configWindow, self:GetID())
             trackerPanel:Hide()
             vendorPanel:Hide()
             combatPanel:Hide()
             framesPanel:Hide()
             lootPanel:Hide()
             miscPanel:Hide()
             
             local id = self:GetID()
             if id == 1 then trackerPanel:Show()
             elseif id == 2 then vendorPanel:Show()
             elseif id == 3 then combatPanel:Show()
             elseif id == 4 then framesPanel:Show()
             elseif id == 5 then lootPanel:Show()
             elseif id == 6 then miscPanel:Show()
             end
        end

        tab1:SetScript("OnClick", TabOnClick)
        tab2:SetScript("OnClick", TabOnClick)
        tab3:SetScript("OnClick", TabOnClick)
        tab4:SetScript("OnClick", TabOnClick)
        tab5:SetScript("OnClick", TabOnClick)
        tab6:SetScript("OnClick", TabOnClick)

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
        local enableTrackerBtn = CreateFrame("CheckButton", "UIThingsTrackerEnableCheck", trackerPanel, "ChatConfigCheckButtonTemplate")
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
        
        local trackerStrataDropdown = CreateFrame("Frame", "UIThingsTrackerStrataDropdown", trackerPanel, "UIDropDownMenuTemplate")
        trackerStrataDropdown:SetPoint("TOPLEFT", trackerStrataLabel, "BOTTOMLEFT", -15, -5)
        
        local function TrackerStrataOnClick(self)
             UIDropDownMenu_SetSelectedID(trackerStrataDropdown, self:GetID())
             UIThingsDB.tracker.strata = self.value
             UpdateTracker()
        end
        
        local function TrackerStrataInit(self, level)
            local stratas = {"BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "TOOLTIP"}
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
        local headerSizeSlider = CreateFrame("Slider", "UIThingsTrackerHeaderSizeSlider", trackerPanel, "OptionsSliderTemplate")
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
        local detailSizeSlider = CreateFrame("Slider", "UIThingsTrackerDetailSizeSlider", trackerPanel, "OptionsSliderTemplate")
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
        local wqActiveCheckbox = CreateFrame("CheckButton", "UIThingsTrackerWQActiveCheckbox", trackerPanel, "ChatConfigCheckButtonTemplate")
        wqActiveCheckbox:SetPoint("TOPLEFT", 250, -400)
        wqActiveCheckbox:SetHitRectInsets(0, -130, 0, 0)
        _G[wqActiveCheckbox:GetName().."Text"]:SetText("Only Active World Quests")
        wqActiveCheckbox:SetChecked(UIThingsDB.tracker.onlyActiveWorldQuests)
        wqActiveCheckbox:SetScript("OnClick", function(self)
            UIThingsDB.tracker.onlyActiveWorldQuests = self:GetChecked()
            UpdateTracker()
        end)

        -------------------------------------------------------------
        -- SECTION: Behavior
        -------------------------------------------------------------
        CreateSectionHeader(trackerPanel, "Behavior", -450)
        
        -- Auto Track Quests Checkbox
        local autoTrackCheckbox = CreateFrame("CheckButton", "UIThingsTrackerAutoTrackCheckbox", trackerPanel, "ChatConfigCheckButtonTemplate")
        autoTrackCheckbox:SetPoint("TOPLEFT", 20, -475)
        autoTrackCheckbox:SetHitRectInsets(0, -110, 0, 0)
        _G[autoTrackCheckbox:GetName().."Text"]:SetText("Auto Track Quests")
        autoTrackCheckbox:SetChecked(UIThingsDB.tracker.autoTrackQuests)
        autoTrackCheckbox:SetScript("OnClick", function(self)
            UIThingsDB.tracker.autoTrackQuests = self:GetChecked()
        end)
        
        -- Right-Click Active Quest Checkbox
        local rightClickCheckbox = CreateFrame("CheckButton", "UIThingsTrackerRightClickCheckbox", trackerPanel, "ChatConfigCheckButtonTemplate")
        rightClickCheckbox:SetPoint("TOPLEFT", 180, -475)
        rightClickCheckbox:SetHitRectInsets(0, -130, 0, 0)
        _G[rightClickCheckbox:GetName().."Text"]:SetText("Right-Click: Active Quest")
        rightClickCheckbox:SetChecked(UIThingsDB.tracker.rightClickSuperTrack)
        rightClickCheckbox:SetScript("OnClick", function(self)
            UIThingsDB.tracker.rightClickSuperTrack = self:GetChecked()
        end)
        
        -- Shift-Click Untrack Checkbox
        local shiftClickCheckbox = CreateFrame("CheckButton", "UIThingsTrackerShiftClickCheckbox", trackerPanel, "ChatConfigCheckButtonTemplate")
        shiftClickCheckbox:SetPoint("TOPLEFT", 380, -475)
        shiftClickCheckbox:SetHitRectInsets(0, -110, 0, 0)
        _G[shiftClickCheckbox:GetName().."Text"]:SetText("Shift-Click: Untrack")
        shiftClickCheckbox:SetChecked(UIThingsDB.tracker.shiftClickUntrack)
        shiftClickCheckbox:SetScript("OnClick", function(self)
            UIThingsDB.tracker.shiftClickUntrack = self:GetChecked()
        end)
        
        -- Hide In Combat Checkbox
        local combatHideCheckbox = CreateFrame("CheckButton", "UIThingsTrackerCombatHideCheckbox", trackerPanel, "ChatConfigCheckButtonTemplate")
        combatHideCheckbox:SetPoint("TOPLEFT", 20, -500)
        combatHideCheckbox:SetHitRectInsets(0, -90, 0, 0)
        _G[combatHideCheckbox:GetName().."Text"]:SetText("Hide in Combat")
        combatHideCheckbox:SetChecked(UIThingsDB.tracker.hideInCombat)
        combatHideCheckbox:SetScript("OnClick", function(self)
            UIThingsDB.tracker.hideInCombat = self:GetChecked()
            UpdateTracker()
        end)
        
        -- Hide In M+ Checkbox
        local mplusHideCheckbox = CreateFrame("CheckButton", "UIThingsTrackerMPlusHideCheckbox", trackerPanel, "ChatConfigCheckButtonTemplate")
        mplusHideCheckbox:SetPoint("TOPLEFT", 180, -500)
        mplusHideCheckbox:SetHitRectInsets(0, -70, 0, 0)
        _G[mplusHideCheckbox:GetName().."Text"]:SetText("Hide in M+")
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
        local borderCheckbox = CreateFrame("CheckButton", "UIThingsTrackerBorderCheckbox", trackerPanel, "ChatConfigCheckButtonTemplate")
        borderCheckbox:SetPoint("TOPLEFT", 20, -560)
        borderCheckbox:SetHitRectInsets(0, -80, 0, 0)
        _G[borderCheckbox:GetName().."Text"]:SetText("Show Border")
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
        local bc = UIThingsDB.tracker.borderColor or {r=0, g=0, b=0, a=1}
        borderColorSwatch.tex:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
        
        Mixin(borderColorSwatch, BackdropTemplateMixin)
        borderColorSwatch:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
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
        local bgCheckbox = CreateFrame("CheckButton", "UIThingsTrackerBgCheckbox", trackerPanel, "ChatConfigCheckButtonTemplate")
        bgCheckbox:SetPoint("TOPLEFT", 20, -585)
        bgCheckbox:SetHitRectInsets(0, -110, 0, 0)
        _G[bgCheckbox:GetName().."Text"]:SetText("Show Background")
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
        local c = UIThingsDB.tracker.backgroundColor or {r=0, g=0, b=0, a=0.5}
        bgColorSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
        
        Mixin(bgColorSwatch, BackdropTemplateMixin)
        bgColorSwatch:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
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
        local ac = UIThingsDB.tracker.activeQuestColor or {r=0, g=1, b=0, a=1}
        activeColorSwatch.tex:SetColorTexture(ac.r, ac.g, ac.b, ac.a)
        
        Mixin(activeColorSwatch, BackdropTemplateMixin)
        activeColorSwatch:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
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
        local enableVendorBtn = CreateFrame("CheckButton", "UIThingsVendorEnableCheck", vendorPanel, "ChatConfigCheckButtonTemplate")
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
        local repairBtn = CreateFrame("CheckButton", "UIThingsAutoRepairCheck", vendorPanel, "ChatConfigCheckButtonTemplate")
        repairBtn:SetPoint("TOPLEFT", 20, -70)
        _G[repairBtn:GetName() .. "Text"]:SetText("Auto Repair")
        repairBtn:SetChecked(UIThingsDB.vendor.autoRepair)
        repairBtn:SetScript("OnClick", function(self)
            local val = not not self:GetChecked()
            UIThingsDB.vendor.autoRepair = val
        end)

        -- Guild Repair
        local guildBtn = CreateFrame("CheckButton", "UIThingsGuildRepairCheck", vendorPanel, "ChatConfigCheckButtonTemplate")
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
        _G[thresholdSlider:GetName() .. 'Text']:SetText(string.format("Repair Reminder: %d%%", UIThingsDB.vendor.repairThreshold or 20))
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
        local vendorLockBtn = CreateFrame("CheckButton", "UIThingsVendorLockCheck", vendorPanel, "ChatConfigCheckButtonTemplate")
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
        
        local vendorFontDropdown = CreateFrame("Frame", "UIThingsVendorFontDropdown", vendorPanel, "UIDropDownMenuTemplate")
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
        local vendorFontSizeSlider = CreateFrame("Slider", "UIThingsVendorFontSizeSlider", vendorPanel, "OptionsSliderTemplate")
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

        local enableCombatBtn = CreateFrame("CheckButton", "UIThingsCombatEnableCheck", combatPanel, "ChatConfigCheckButtonTemplate")
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
        local combatLockBtn = CreateFrame("CheckButton", "UIThingsCombatLockCheck", combatPanel, "ChatConfigCheckButtonTemplate")
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
            function() return UIThingsDB.combat.colorInCombat.r, UIThingsDB.combat.colorInCombat.g, UIThingsDB.combat.colorInCombat.b end,
            function(r, g, b) 
                UIThingsDB.combat.colorInCombat = {r=r, g=g, b=b}
                UpdateCombat()
            end,
            -230
        )
        
        CreateColorPicker(combatPanel, "UIThingsCombatColorOut", "Out Combat Color", 
            function() return UIThingsDB.combat.colorOutCombat.r, UIThingsDB.combat.colorOutCombat.g, UIThingsDB.combat.colorOutCombat.b end,
            function(r, g, b) 
                UIThingsDB.combat.colorOutCombat = {r=r, g=g, b=b}
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

        local framesEnableBtn = CreateFrame("CheckButton", "UIThingsFramesEnableCheck", framesPanel, "ChatConfigCheckButtonTemplate")
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
                UIDropDownMenu_SetText(frameDropdown, UIThingsDB.frames.list[selectedFrameIndex].name or ("Frame " .. selectedFrameIndex))
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
                width = 100, height = 100,
                x = 0, y = 0,
                borderSize = 1,
                strata = "LOW",
                color = {r=0, g=0, b=0, a=0.5},
                borderColor = {r=1, g=1, b=1, a=1}
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
             if newFrameData.x > 0 then newFrameData.x = newFrameData.x - 10
             else newFrameData.x = newFrameData.x + 10 end
             
             if newFrameData.y > 0 then newFrameData.y = newFrameData.y - 10
             else newFrameData.y = newFrameData.y + 10 end
             
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
        local strataDropdown = CreateFrame("Frame", "UIThingsFrameStrataDropdown", frameControls, "UIDropDownMenuTemplate")
        strataDropdown:SetPoint("TOPLEFT", strataLabel, "BOTTOMLEFT", -15, -10)
        local stratas = {"BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "TOOLTIP"}
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
        fillColorSwatch:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
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
        borderColorSwatch:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
        borderColorSwatch:SetBackdropBorderColor(1, 1, 1)
        borderColorSwatch:SetScript("OnClick", function(self)
            if not selectedFrameIndex then return end
            -- Ensure default exists if old data
            if not UIThingsDB.frames.list[selectedFrameIndex].borderColor then
                 UIThingsDB.frames.list[selectedFrameIndex].borderColor = {r=1, g=1, b=1, a=1}
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
        local borderTopBtn = CreateFrame("CheckButton", "UIThingsBorderTopCheck", frameControls, "ChatConfigCheckButtonTemplate")
        borderTopBtn:SetPoint("TOPLEFT", 140, -240) -- Moved down and right slightly
        borderTopBtn.tooltip = "Show Top Border"
        borderTopBtn:SetScript("OnClick", function(self)
             if selectedFrameIndex then
                 UIThingsDB.frames.list[selectedFrameIndex].showTop = self:GetChecked()
                 UpdateFrames()
             end
        end)
        
        -- Bottom: Below Top with a gap
        local borderBottomBtn = CreateFrame("CheckButton", "UIThingsBorderBottomCheck", frameControls, "ChatConfigCheckButtonTemplate")
        borderBottomBtn:SetPoint("TOP", borderTopBtn, "BOTTOM", 0, -24) -- Gap for the 'middle' row
        borderBottomBtn.tooltip = "Show Bottom Border"
        borderBottomBtn:SetScript("OnClick", function(self)
             if selectedFrameIndex then
                 UIThingsDB.frames.list[selectedFrameIndex].showBottom = self:GetChecked()
                 UpdateFrames()
             end
        end)
        
        -- Left: Left of the vertical gap center
        local borderLeftBtn = CreateFrame("CheckButton", "UIThingsBorderLeftCheck", frameControls, "ChatConfigCheckButtonTemplate")
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
        local borderRightBtn = CreateFrame("CheckButton", "UIThingsBorderRightCheck", frameControls, "ChatConfigCheckButtonTemplate")
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
                widthEdit:SetText(tostring(f.width)) -- Sync EditBox
                
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
                    borderColorSwatch.tex:SetColorTexture(f.borderColor.r, f.borderColor.g, f.borderColor.b, f.borderColor.a)
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
            local enableCheckbox = CreateFrame("CheckButton", "UIThingsLootEnable", panel, "ChatConfigCheckButtonTemplate")
            enableCheckbox:SetPoint("TOPLEFT", 20, -50)
            _G[enableCheckbox:GetName().."Text"]:SetText("Enable Loot Toasts")
            enableCheckbox:SetChecked(UIThingsDB.loot.enabled)
            enableCheckbox:SetScript("OnClick", function(self)
                UIThingsDB.loot.enabled = self:GetChecked()
                UpdateModuleVisuals(lootPanel, tab5, UIThingsDB.loot.enabled)
            end)
            UpdateModuleVisuals(lootPanel, tab5, UIThingsDB.loot.enabled)
            

            
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
            durationSlider:SetPoint("TOPLEFT", 20, -100)
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
            qualityLabel:SetPoint("TOPLEFT", 20, -150)
            qualityLabel:SetText("Minimum Quality:")
            
            local qualityDropdown = CreateFrame("Frame", "UIThingsLootQualityDropdown", panel, "UIDropDownMenuTemplate")
            qualityDropdown:SetPoint("TOPLEFT", 140, -140)
            UIDropDownMenu_SetWidth(qualityDropdown, 120)
            
            local qualities = {
                {text = "|cff9d9d9dPoor|r", value = 0},
                {text = "|cffffffffCommon|r", value = 1},
                {text = "|cff1eff00Uncommon|r", value = 2},
                {text = "|cff0070ddRare|r", value = 3},
                {text = "|cffa335eeEpic|r", value = 4},
                {text = "|cffff8000Legendary|r", value = 5},
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
            fontLabel:SetPoint("TOPLEFT", 20, -200)
            fontLabel:SetText("Font:")
            
            local fontDropdown = CreateFrame("Frame", "UIThingsLootFontDropdown", panel, "UIDropDownMenuTemplate")
            fontDropdown:SetPoint("TOPLEFT", 60, -190)
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
            fontSizeSlider:SetPoint("TOPLEFT", 250, -200)
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
            
            -- Icon Size Slider
            local iconSizeSlider = CreateFrame("Slider", "UIThingsLootIconSize", panel, "OptionsSliderTemplate")
            iconSizeSlider:SetPoint("TOPLEFT", 20, -250)
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
            growBtn:SetPoint("TOPLEFT", 20, -300)
            _G[growBtn:GetName().."Text"]:SetText("Grow Upwards")
            growBtn:SetChecked(UIThingsDB.loot.growUp)
            growBtn:SetScript("OnClick", function(self)
                UIThingsDB.loot.growUp = self:GetChecked()
                addonTable.Loot.UpdateSettings()
            end)
            
            -- Faster Loot Checkbox
            local fasterLootBtn = CreateFrame("CheckButton", "UIThingsLootFasterCheck", panel, "ChatConfigCheckButtonTemplate")
            fasterLootBtn:SetPoint("TOPLEFT", 20, -350)
            _G[fasterLootBtn:GetName().."Text"]:SetText("Faster Loot")
            fasterLootBtn:SetChecked(UIThingsDB.loot.fasterLoot)
            fasterLootBtn:SetScript("OnClick", function(self)
                UIThingsDB.loot.fasterLoot = self:GetChecked()
            end)
            
            -- Faster Loot Delay Slider
            local delaySlider = CreateFrame("Slider", "UIThingsLootDelaySlider", panel, "OptionsSliderTemplate")
            delaySlider:SetPoint("TOPLEFT", 20, -400)
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
                    val = math.max(0, math.min(1, val)) -- Clamp 0-1
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
            _G[enableBtn:GetName().."Text"]:SetText("Enable Misc Module")
            enableBtn:SetChecked(UIThingsDB.misc.enabled)
            enableBtn:SetScript("OnClick", function(self)
                UIThingsDB.misc.enabled = self:GetChecked()
                UpdateModuleVisuals(miscPanel, tab6, UIThingsDB.misc.enabled)
            end)
            UpdateModuleVisuals(miscPanel, tab6, UIThingsDB.misc.enabled)
            
            -- AH Filter Checkbox
            local ahBtn = CreateFrame("CheckButton", "UIThingsMiscAHFilter", panel, "ChatConfigCheckButtonTemplate")
            ahBtn:SetPoint("TOPLEFT", 20, -100)
            _G[ahBtn:GetName().."Text"]:SetText("Auction Current Expansion Only")
            ahBtn:SetChecked(UIThingsDB.misc.ahFilter)
            ahBtn:SetScript("OnClick", function(self)
                UIThingsDB.misc.ahFilter = self:GetChecked()
            end)
            
            -- Personal Orders Header
            local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            header:SetPoint("TOPLEFT", 20, -150)
            header:SetText("Personal Orders")

            -- Personal Orders Checkbox
            local ordersBtn = CreateFrame("CheckButton", "UIThingsMiscOrdersCheck", panel, "ChatConfigCheckButtonTemplate")
            ordersBtn:SetPoint("TOPLEFT", 20, -180)
            _G[ordersBtn:GetName().."Text"]:SetText("Enable Personal Order Detection")
            ordersBtn:SetChecked(UIThingsDB.misc.personalOrders)
            ordersBtn:SetScript("OnClick", function(self)
                UIThingsDB.misc.personalOrders = self:GetChecked()
            end)

            -- TTS Message
            local ttsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            ttsLabel:SetPoint("TOPLEFT", 40, -220)
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
            
            -- Alert Duration Slider
            local durSlider = CreateFrame("Slider", "UIThingsMiscAlertDur", panel, "OptionsSliderTemplate")
            durSlider:SetPoint("TOPLEFT", 40, -260)
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
            colorLabel:SetPoint("TOPLEFT", 40, -300)
            colorLabel:SetText("Alert Color:")
            
            local colorSwatch = CreateFrame("Button", nil, panel)
            colorSwatch:SetSize(20, 20)
            colorSwatch:SetPoint("LEFT", colorLabel, "RIGHT", 10, 0)
            
            colorSwatch.tex = colorSwatch:CreateTexture(nil, "OVERLAY")
            colorSwatch.tex:SetAllPoints()
            local c = UIThingsDB.misc.alertColor
            colorSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a or 1)
            
            Mixin(colorSwatch, BackdropTemplateMixin)
            colorSwatch:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
            colorSwatch:SetBackdropBorderColor(1, 1, 1)

            colorSwatch:SetScript("OnClick", function()
                local prevR, prevG, prevB, prevA = c.r, c.g, c.b, c.a
                
                if ColorPickerFrame.SetupColorPickerAndShow then
                    ColorPickerFrame:SetupColorPickerAndShow({
                        r = c.r, g = c.g, b = c.b, opacity = c.a,
                        hasOpacity = true,
                        swatchFunc = function()
                            local r,g,b = ColorPickerFrame:GetColorRGB()
                            local a = ColorPickerFrame:GetColorAlpha()
                            c.r, c.g, c.b, c.a = r, g, b, a
                            colorSwatch.tex:SetColorTexture(r, g, b, a)
                            UIThingsDB.misc.alertColor = c
                        end,
                        opacityFunc = function()
                             local a = ColorPickerFrame:GetColorAlpha()
                             local r,g,b = ColorPickerFrame:GetColorRGB()
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
                    -- Fallback for older APIs if needed
                    ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
                    ColorPickerFrame.hasOpacity = true
                    ColorPickerFrame.opacity = c.a
                    ColorPickerFrame.func = function()
                        local r,g,b = ColorPickerFrame:GetColorRGB()
                        local a = ColorPickerFrame:GetOpacity()
                        c.r, c.g, c.b, c.a = r, g, b, a
                        colorSwatch.tex:SetColorTexture(r, g, b, a)
                        UIThingsDB.misc.alertColor = c
                    end
                    ColorPickerFrame:Show()
                end
            end)
        end
        SetupMiscPanel()
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

