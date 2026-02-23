local addonName, addonTable = ...

addonTable.ConfigSetup = addonTable.ConfigSetup or {}

local Helpers = addonTable.ConfigHelpers

function addonTable.ConfigSetup.Coordinates(panel, tab, configWindow)
    Helpers.CreateResetButton(panel, "coordinates")
    local fonts = Helpers.fonts

    -- Create ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "UIThingsCoordinatesScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 0)

    local child = CreateFrame("Frame", nil, scrollFrame)
    child:SetSize(600, 620)
    scrollFrame:SetScrollChild(child)

    scrollFrame:SetScript("OnShow", function()
        child:SetWidth(scrollFrame:GetWidth())
    end)

    local function UpdateCoordinates()
        if addonTable.Coordinates and addonTable.Coordinates.UpdateSettings then
            addonTable.Coordinates.UpdateSettings()
        end
    end

    -- Title
    local title = child:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Coordinates")

    -- Enable checkbox
    local enableBtn = CreateFrame("CheckButton", "UIThingsCoordinatesEnableCheck", child, "ChatConfigCheckButtonTemplate")
    enableBtn:SetPoint("TOPLEFT", 20, -50)
    _G[enableBtn:GetName() .. "Text"]:SetText("Enable Coordinates / Waypoints")
    enableBtn:SetChecked(UIThingsDB.coordinates.enabled)
    enableBtn:SetScript("OnClick", function(self)
        local enabled = not not self:GetChecked()
        UIThingsDB.coordinates.enabled = enabled
        UpdateCoordinates()
        Helpers.UpdateModuleVisuals(panel, tab, enabled)
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.coordinates.enabled)

    -- Lock checkbox
    local lockBtn = CreateFrame("CheckButton", "UIThingsCoordinatesLockCheck", child, "ChatConfigCheckButtonTemplate")
    lockBtn:SetPoint("TOPLEFT", 20, -70)
    _G[lockBtn:GetName() .. "Text"]:SetText("Lock Waypoint Frame")
    lockBtn:SetChecked(UIThingsDB.coordinates.locked)
    lockBtn:SetScript("OnClick", function(self)
        UIThingsDB.coordinates.locked = not not self:GetChecked()
        UpdateCoordinates()
    end)

    -- Appearance section
    Helpers.CreateSectionHeader(child, "Appearance", -110)

    -- Show Border checkbox
    local borderBtn = CreateFrame("CheckButton", "UIThingsCoordsBorderCheck", child, "ChatConfigCheckButtonTemplate")
    borderBtn:SetPoint("TOPLEFT", 20, -140)
    _G[borderBtn:GetName() .. "Text"]:SetText("Show Border")
    borderBtn:SetChecked(UIThingsDB.coordinates.showBorder)
    borderBtn:SetScript("OnClick", function(self)
        UIThingsDB.coordinates.showBorder = not not self:GetChecked()
        UpdateCoordinates()
    end)

    -- Border Color
    Helpers.CreateColorSwatch(child, "Border Color:", UIThingsDB.coordinates.borderColor, UpdateCoordinates, 250, -140, true)

    -- Show Background checkbox
    local bgBtn = CreateFrame("CheckButton", "UIThingsCoordsBgCheck", child, "ChatConfigCheckButtonTemplate")
    bgBtn:SetPoint("TOPLEFT", 20, -170)
    _G[bgBtn:GetName() .. "Text"]:SetText("Show Background")
    bgBtn:SetChecked(UIThingsDB.coordinates.showBackground)
    bgBtn:SetScript("OnClick", function(self)
        UIThingsDB.coordinates.showBackground = not not self:GetChecked()
        UpdateCoordinates()
    end)

    -- Background Color
    Helpers.CreateColorSwatch(child, "Background Color:", UIThingsDB.coordinates.backgroundColor, UpdateCoordinates, 250, -170, true)

    -- Font dropdown
    Helpers.CreateFontDropdown(
        child,
        "UIThingsCoordsFont",
        "Font:",
        UIThingsDB.coordinates.font,
        function(fontPath, fontName)
            UIThingsDB.coordinates.font = fontPath
            UpdateCoordinates()
        end,
        20,
        -210
    )

    -- Font Size slider
    local fontSizeSlider = CreateFrame("Slider", "UIThingsCoordsFontSize", child, "OptionsSliderTemplate")
    fontSizeSlider:SetPoint("TOPLEFT", 20, -280)
    fontSizeSlider:SetMinMaxValues(8, 18)
    fontSizeSlider:SetValueStep(1)
    fontSizeSlider:SetObeyStepOnDrag(true)
    fontSizeSlider:SetWidth(150)
    local currentSize = UIThingsDB.coordinates.fontSize or 12
    _G[fontSizeSlider:GetName() .. 'Text']:SetText("Font Size: " .. currentSize)
    _G[fontSizeSlider:GetName() .. 'Low']:SetText("")
    _G[fontSizeSlider:GetName() .. 'High']:SetText("")
    fontSizeSlider:SetValue(currentSize)
    fontSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.coordinates.fontSize = value
        _G[self:GetName() .. 'Text']:SetText("Font Size: " .. value)
        UpdateCoordinates()
    end)

    -- Width slider
    local widthSlider = CreateFrame("Slider", "UIThingsCoordsWidth", child, "OptionsSliderTemplate")
    widthSlider:SetPoint("TOPLEFT", 20, -330)
    widthSlider:SetMinMaxValues(100, 600)
    widthSlider:SetValueStep(10)
    widthSlider:SetObeyStepOnDrag(true)
    widthSlider:SetWidth(200)
    local currentWidth = UIThingsDB.coordinates.width or 220
    _G[widthSlider:GetName() .. 'Text']:SetText("Width: " .. currentWidth)
    _G[widthSlider:GetName() .. 'Low']:SetText("100")
    _G[widthSlider:GetName() .. 'High']:SetText("600")
    widthSlider:SetValue(currentWidth)
    widthSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.coordinates.width = value
        _G[self:GetName() .. 'Text']:SetText("Width: " .. value)
        UpdateCoordinates()
    end)

    -- Height slider
    local heightSlider = CreateFrame("Slider", "UIThingsCoordsHeight", child, "OptionsSliderTemplate")
    heightSlider:SetPoint("TOPLEFT", 20, -390)
    heightSlider:SetMinMaxValues(60, 600)
    heightSlider:SetValueStep(10)
    heightSlider:SetObeyStepOnDrag(true)
    heightSlider:SetWidth(200)
    local currentHeight = UIThingsDB.coordinates.height or 200
    _G[heightSlider:GetName() .. 'Text']:SetText("Height: " .. currentHeight)
    _G[heightSlider:GetName() .. 'Low']:SetText("60")
    _G[heightSlider:GetName() .. 'High']:SetText("600")
    heightSlider:SetValue(currentHeight)
    heightSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.coordinates.height = value
        _G[self:GetName() .. 'Text']:SetText("Height: " .. value)
        UpdateCoordinates()
    end)

    -- Commands section
    Helpers.CreateSectionHeader(child, "Commands", -440)

    local cmdNote = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cmdNote:SetPoint("TOPLEFT", 20, -465)
    cmdNote:SetText("/lway [zone] x, y [name] - always available")
    cmdNote:SetTextColor(0.7, 0.7, 0.7)

    -- Register /way checkbox
    local wayBtn = CreateFrame("CheckButton", "UIThingsCoordsWayCheck", child, "ChatConfigCheckButtonTemplate")
    wayBtn:SetPoint("TOPLEFT", 20, -490)
    _G[wayBtn:GetName() .. "Text"]:SetText("Also register /way command")
    wayBtn:SetChecked(UIThingsDB.coordinates.registerWayCommand)
    wayBtn:SetScript("OnClick", function(self)
        UIThingsDB.coordinates.registerWayCommand = not not self:GetChecked()
        if addonTable.Coordinates and addonTable.Coordinates.ApplyWayCommand then
            addonTable.Coordinates.ApplyWayCommand()
        end
    end)

    local wayNote = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    wayNote:SetPoint("TOPLEFT", 20, -515)
    wayNote:SetText("Note: /way may conflict with TomTom if installed")
    wayNote:SetTextColor(1, 0.5, 0.5)
end
