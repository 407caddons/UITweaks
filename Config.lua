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
        configWindow:SetSize(300, 400)
        configWindow:SetPoint("CENTER")
        configWindow:SetMovable(true)
        configWindow:EnableMouse(true)
        configWindow:RegisterForDrag("LeftButton")
        configWindow:SetScript("OnDragStart", configWindow.StartMoving)
        configWindow:SetScript("OnDragStop", configWindow.StopMovingOrSizing)
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

        PanelTemplates_SetNumTabs(configWindow, 3)
        PanelTemplates_SetTab(configWindow, 1)

        tab1:SetScript("OnClick", function()
             PanelTemplates_SetTab(configWindow, 1)
             trackerPanel:Show()
             vendorPanel:Hide()
             combatPanel:Hide()
        end)

        tab2:SetScript("OnClick", function()
             PanelTemplates_SetTab(configWindow, 2)
             trackerPanel:Hide()
             vendorPanel:Show()
             combatPanel:Hide()
        end)

        tab3:SetScript("OnClick", function()
             PanelTemplates_SetTab(configWindow, 3)
             trackerPanel:Hide()
             vendorPanel:Hide()
             combatPanel:Show()
        end)

        -------------------------------------------------------------
        -- TRACKER PANEL CONTENT
        -------------------------------------------------------------
        
        -- Enable Tracker Checkbox
        local enableTrackerBtn = CreateFrame("CheckButton", "UIThingsTrackerEnableCheck", trackerPanel, "ChatConfigCheckButtonTemplate")
        enableTrackerBtn:SetPoint("TOPLEFT", 20, -40)
        _G[enableTrackerBtn:GetName() .. "Text"]:SetText("Enable Objective Tracker Tweaks")
        enableTrackerBtn:SetChecked(UIThingsDB.tracker.enabled)
        enableTrackerBtn:SetScript("OnClick", function(self)
            local enabled = not not self:GetChecked()
            UIThingsDB.tracker.enabled = enabled
            UpdateTracker()
        end)

        -- Lock Checkbox
        local lockBtn = CreateFrame("CheckButton", "UIThingsLockCheck", trackerPanel, "ChatConfigCheckButtonTemplate")
        lockBtn:SetPoint("TOPLEFT", 20, -70)
        _G[lockBtn:GetName() .. "Text"]:SetText("Lock Objective Tracker")
        lockBtn:SetChecked(UIThingsDB.tracker.locked)
        lockBtn:SetScript("OnClick", function(self)
            local locked = not not self:GetChecked()
            print("UIThings: Setting lock to", locked)
            UIThingsDB.tracker.locked = locked
            UpdateTracker()
        end)
        
        -- Width Slider
        local widthSlider = CreateFrame("Slider", "UIThingsWidthSlider", trackerPanel, "OptionsSliderTemplate")
        widthSlider:SetPoint("TOPLEFT", 20, -120)
        widthSlider:SetMinMaxValues(100, 600)
        widthSlider:SetValueStep(10)
        widthSlider:SetObeyStepOnDrag(true)
        widthSlider:SetWidth(200)
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
        heightSlider:SetPoint("TOPLEFT", 20, -170)
        heightSlider:SetMinMaxValues(100, 1000)
        heightSlider:SetValueStep(10)
        heightSlider:SetObeyStepOnDrag(true)
        heightSlider:SetWidth(200)
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
        
        -- Tracker Font Selector
        local trackerFontLabel = trackerPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        trackerFontLabel:SetPoint("TOPLEFT", 20, -210)
        trackerFontLabel:SetText("Font:")
        
        local trackerFontDropdown = CreateFrame("Frame", "UIThingsTrackerFontDropdown", trackerPanel, "UIDropDownMenuTemplate")
        trackerFontDropdown:SetPoint("TOPLEFT", trackerFontLabel, "BOTTOMLEFT", -15, -10)
        
        local function TrackerFontOnClick(self)
             UIDropDownMenu_SetSelectedID(trackerFontDropdown, self:GetID())
             UIThingsDB.tracker.font = self.value
             UpdateTracker()
        end
        
        local function TrackerFontInit(self, level)
            local info = UIDropDownMenu_CreateInfo()
            for k, v in pairs(fonts) do
                info = UIDropDownMenu_CreateInfo()
                info.text = v.name
                info.value = v.path
                info.func = TrackerFontOnClick
                UIDropDownMenu_AddButton(info, level)
            end
        end
        
        UIDropDownMenu_Initialize(trackerFontDropdown, TrackerFontInit)
        UIDropDownMenu_SetText(trackerFontDropdown, "Select Font")
        for i, f in ipairs(fonts) do
            if f.path == UIThingsDB.tracker.font then
                UIDropDownMenu_SetText(trackerFontDropdown, f.name)
            end
        end

        -- Tracker Font Size Slider
        local trackerFontSizeSlider = CreateFrame("Slider", "UIThingsTrackerFontSizeSlider", trackerPanel, "OptionsSliderTemplate")
        trackerFontSizeSlider:SetPoint("TOPLEFT", 20, -280)
        trackerFontSizeSlider:SetMinMaxValues(8, 24)
        trackerFontSizeSlider:SetValueStep(1)
        trackerFontSizeSlider:SetObeyStepOnDrag(true)
        trackerFontSizeSlider:SetWidth(200)
        _G[trackerFontSizeSlider:GetName() .. 'Text']:SetText(string.format("Font Size: %d", UIThingsDB.tracker.fontSize))
        _G[trackerFontSizeSlider:GetName() .. 'Low']:SetText("8")
        _G[trackerFontSizeSlider:GetName() .. 'High']:SetText("24")
        trackerFontSizeSlider:SetValue(UIThingsDB.tracker.fontSize)
        trackerFontSizeSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value)
            UIThingsDB.tracker.fontSize = value
            _G[self:GetName() .. 'Text']:SetText(string.format("Font Size: %d", value))
            UpdateTracker()
        end)
        
        -- Show Border Checkbox
        local borderCheckbox = CreateFrame("CheckButton", "UIThingsTrackerBorderCheckbox", trackerPanel, "ChatConfigCheckButtonTemplate")
        borderCheckbox:SetPoint("TOPLEFT", 20, -320)
        _G[borderCheckbox:GetName().."Text"]:SetText("Show Border")
        borderCheckbox:SetChecked(UIThingsDB.tracker.showBorder)
        borderCheckbox:SetScript("OnClick", function(self)
            UIThingsDB.tracker.showBorder = self:GetChecked()
            UpdateTracker()
        end)
        
        -- Hide In Combat Checkbox
        local combatHideCheckbox = CreateFrame("CheckButton", "UIThingsTrackerCombatHideCheckbox", trackerPanel, "ChatConfigCheckButtonTemplate")
        combatHideCheckbox:SetPoint("TOPLEFT", 150, -320)
        _G[combatHideCheckbox:GetName().."Text"]:SetText("Hide in Combat")
        combatHideCheckbox:SetChecked(UIThingsDB.tracker.hideInCombat)
        combatHideCheckbox:SetScript("OnClick", function(self)
            UIThingsDB.tracker.hideInCombat = self:GetChecked()
            UpdateTracker()
        end)
        
        -- Background Color Picker
        local bgColorLabel = trackerPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        bgColorLabel:SetPoint("TOPLEFT", 20, -350)
        bgColorLabel:SetText("Background Color:")
        
        local bgColorSwatch = CreateFrame("Button", nil, trackerPanel)
        bgColorSwatch:SetSize(20, 20)
        bgColorSwatch:SetPoint("LEFT", bgColorLabel, "RIGHT", 10, 0)
        
        -- Create a texture for the swatch to show current color
        bgColorSwatch.tex = bgColorSwatch:CreateTexture(nil, "OVERLAY")
        bgColorSwatch.tex:SetAllPoints()
        local c = UIThingsDB.tracker.backgroundColor or {r=0, g=0, b=0, a=0.5}
        bgColorSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
        
        -- Border using BackdropTemplate? Button already has borders usually if standard template not used.
        -- Let's just add a simple border texture or use standard template.
        -- Using "BackdropTemplate" for custom border
        Mixin(bgColorSwatch, BackdropTemplateMixin)
        bgColorSwatch:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
        bgColorSwatch:SetBackdropBorderColor(1, 1, 1)

        bgColorSwatch:SetScript("OnClick", function(self)
            local info = UIDropDownMenu_CreateInfo()
            info.r, info.g, info.b, info.opacity = c.r, c.g, c.b, c.a
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
                c.r, c.g, c.b, c.a = previousValues.r, previousValues.g, previousValues.b, previousValues.opacity
                bgColorSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
                UIThingsDB.tracker.backgroundColor = c
                UpdateTracker()
            end
            
            ColorPickerFrame:SetupColorPickerAndShow(info)
        end)

        -------------------------------------------------------------
        -- VENDOR PANEL CONTENT
        -------------------------------------------------------------

        -- Enable Vendor Checkbox
        local enableVendorBtn = CreateFrame("CheckButton", "UIThingsVendorEnableCheck", vendorPanel, "ChatConfigCheckButtonTemplate")
        enableVendorBtn:SetPoint("TOPLEFT", 20, -40)
        _G[enableVendorBtn:GetName() .. "Text"]:SetText("Enable Vendor Automation")
        enableVendorBtn:SetChecked(UIThingsDB.vendor.enabled)
        enableVendorBtn:SetScript("OnClick", function(self)
            local enabled = not not self:GetChecked()
            UIThingsDB.vendor.enabled = enabled
        end)

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
            local info = UIDropDownMenu_CreateInfo()
            for k, v in pairs(fonts) do
                info = UIDropDownMenu_CreateInfo()
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
        local enableCombatBtn = CreateFrame("CheckButton", "UIThingsCombatEnableCheck", combatPanel, "ChatConfigCheckButtonTemplate")
        enableCombatBtn:SetPoint("TOPLEFT", 20, -40)
        _G[enableCombatBtn:GetName() .. "Text"]:SetText("Enable Combat Timer")
        enableCombatBtn:SetChecked(UIThingsDB.combat.enabled)
        enableCombatBtn:SetScript("OnClick", function(self)
            local enabled = not not self:GetChecked()
            UIThingsDB.combat.enabled = enabled
            UpdateCombat()
        end)

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
            local info = UIDropDownMenu_CreateInfo()
            for k, v in pairs(fonts) do
                info = UIDropDownMenu_CreateInfo()
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

