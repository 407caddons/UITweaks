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
    child:SetSize(600, 500)
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
    _G[fontSizeSlider:GetName() .. 'Low']:SetText("8")
    _G[fontSizeSlider:GetName() .. 'High']:SetText("18")
    fontSizeSlider:SetValue(currentSize)
    fontSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.coordinates.fontSize = value
        _G[self:GetName() .. 'Text']:SetText("Font Size: " .. value)
        UpdateCoordinates()
    end)

    -- Commands section
    Helpers.CreateSectionHeader(child, "Commands", -320)

    local cmdNote = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cmdNote:SetPoint("TOPLEFT", 20, -345)
    cmdNote:SetText("/lway [zone] x, y [name] - always available")
    cmdNote:SetTextColor(0.7, 0.7, 0.7)

    -- Register /way checkbox
    local wayBtn = CreateFrame("CheckButton", "UIThingsCoordsWayCheck", child, "ChatConfigCheckButtonTemplate")
    wayBtn:SetPoint("TOPLEFT", 20, -370)
    _G[wayBtn:GetName() .. "Text"]:SetText("Also register /way command")
    wayBtn:SetChecked(UIThingsDB.coordinates.registerWayCommand)
    wayBtn:SetScript("OnClick", function(self)
        UIThingsDB.coordinates.registerWayCommand = not not self:GetChecked()
        if addonTable.Coordinates and addonTable.Coordinates.ApplyWayCommand then
            addonTable.Coordinates.ApplyWayCommand()
        end
    end)

    local wayNote = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    wayNote:SetPoint("TOPLEFT", 20, -395)
    wayNote:SetText("Note: /way may conflict with TomTom if installed")
    wayNote:SetTextColor(1, 0.5, 0.5)
end
