local addonName, addonTable = ...

-- Create setup table if it doesn't exist
addonTable.ConfigSetup = addonTable.ConfigSetup or {}

-- Get helpers
local Helpers = addonTable.ConfigHelpers

-- Define the setup function for Minimap panel
function addonTable.ConfigSetup.Minimap(panel, navButton, configWindow)
    Helpers.CreateResetButton(panel, "minimap")
    -- Visual compatibility with sidebar navigation
    Helpers.UpdateModuleVisuals(panel, navButton, UIThingsDB.minimap.minimapEnabled)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Minimap Customization")

    -- Enable Checkbox (stays on panel, above scroll area)
    local minimapBtn = CreateFrame("CheckButton", "UIThingsMinimapEnabled", panel, "ChatConfigCheckButtonTemplate")
    minimapBtn:SetPoint("TOPLEFT", 20, -50)
    _G[minimapBtn:GetName() .. "Text"]:SetText("Enable Minimap Customization (requires reload)")
    minimapBtn:SetChecked(UIThingsDB.minimap.minimapEnabled)
    minimapBtn:SetScript("OnClick", function(self)
        UIThingsDB.minimap.minimapEnabled = self:GetChecked()
        Helpers.UpdateModuleVisuals(panel, navButton, UIThingsDB.minimap.minimapEnabled)
    end)

    -- Create ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "UIThingsMinimapScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -80)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 0)

    local child = CreateFrame("Frame", nil, scrollFrame)
    child:SetSize(600, 870)
    scrollFrame:SetScrollChild(child)

    scrollFrame:SetScript("OnShow", function()
        child:SetWidth(scrollFrame:GetWidth())
    end)

    -- Shape Dropdown
    local shapeLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    shapeLabel:SetPoint("TOPLEFT", 40, -10)
    shapeLabel:SetText("Shape:")

    local shapeDropdown = CreateFrame("Frame", "UIThingsMinimapShape", child, "UIDropDownMenuTemplate")
    shapeDropdown:SetPoint("LEFT", shapeLabel, "RIGHT", -5, -3)
    UIDropDownMenu_SetWidth(shapeDropdown, 100)
    UIDropDownMenu_SetText(shapeDropdown, UIThingsDB.minimap.minimapShape == "SQUARE" and "Square" or "Round")

    UIDropDownMenu_Initialize(shapeDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()

        info.text = "Round"
        info.checked = UIThingsDB.minimap.minimapShape == "ROUND"
        info.func = function()
            UIThingsDB.minimap.minimapShape = "ROUND"
            UIDropDownMenu_SetText(shapeDropdown, "Round")
            if UIThingsDB.minimap.minimapEnabled and addonTable.MinimapCustom and addonTable.MinimapCustom.ApplyMinimapShape then
                addonTable.MinimapCustom.ApplyMinimapShape("ROUND")
            end
        end
        UIDropDownMenu_AddButton(info)

        info.text = "Square"
        info.checked = UIThingsDB.minimap.minimapShape == "SQUARE"
        info.func = function()
            UIThingsDB.minimap.minimapShape = "SQUARE"
            UIDropDownMenu_SetText(shapeDropdown, "Square")
            if UIThingsDB.minimap.minimapEnabled and addonTable.MinimapCustom and addonTable.MinimapCustom.ApplyMinimapShape then
                addonTable.MinimapCustom.ApplyMinimapShape("SQUARE")
            end
        end
        UIDropDownMenu_AddButton(info)
    end)

    -- Lock Checkbox
    local lockBtn = CreateFrame("CheckButton", "UIThingsMinimapLocked", child, "ChatConfigCheckButtonTemplate")
    lockBtn:SetPoint("TOPLEFT", 20, -45)
    _G[lockBtn:GetName() .. "Text"]:SetText("Lock Minimap Position")
    lockBtn:SetChecked(true) -- Always defaults to locked
    lockBtn:SetScript("OnClick", function(self)
        if addonTable.MinimapCustom and addonTable.MinimapCustom.SetMinimapLocked then
            addonTable.MinimapCustom.SetMinimapLocked(self:GetChecked())
        end
    end)

    -- Border Color
    local borderColorLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    borderColorLabel:SetPoint("TOPLEFT", 300, -10)
    borderColorLabel:SetText("Border Color:")

    local borderSwatch = CreateFrame("Button", nil, child)
    borderSwatch:SetSize(20, 20)
    borderSwatch:SetPoint("LEFT", borderColorLabel, "RIGHT", 10, 0)

    borderSwatch.tex = borderSwatch:CreateTexture(nil, "OVERLAY")
    borderSwatch.tex:SetAllPoints()
    local bCol = UIThingsDB.minimap.minimapBorderColor or { r = 0, g = 0, b = 0, a = 1 }
    borderSwatch.tex:SetColorTexture(bCol.r, bCol.g, bCol.b, bCol.a or 1)

    Mixin(borderSwatch, BackdropTemplateMixin)
    borderSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    borderSwatch:SetBackdropBorderColor(1, 1, 1)

    borderSwatch:SetScript("OnClick", function()
        local c = UIThingsDB.minimap.minimapBorderColor or { r = 0, g = 0, b = 0, a = 1 }
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
                    borderSwatch.tex:SetColorTexture(r, g, b, a)
                    UIThingsDB.minimap.minimapBorderColor = c
                    if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateMinimapBorder then
                        addonTable.MinimapCustom.UpdateMinimapBorder()
                    end
                end,
                cancelFunc = function()
                    borderSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
                    UIThingsDB.minimap.minimapBorderColor = c
                    if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateMinimapBorder then
                        addonTable.MinimapCustom.UpdateMinimapBorder()
                    end
                end,
            })
        end
    end)

    -- Border Thickness Slider
    local borderSlider = CreateFrame("Slider", "UIThingsMinimapBorderSize", child, "OptionsSliderTemplate")
    borderSlider:SetPoint("TOPLEFT", 320, -45)
    borderSlider:SetWidth(200)
    borderSlider:SetMinMaxValues(0, 10)
    borderSlider:SetValueStep(1)
    borderSlider:SetObeyStepOnDrag(true)
    borderSlider:SetValue(UIThingsDB.minimap.minimapBorderSize or 3)
    _G[borderSlider:GetName() .. "Low"]:SetText("0")
    _G[borderSlider:GetName() .. "High"]:SetText("10")
    _G[borderSlider:GetName() .. "Text"]:SetText("Border Thickness: " .. (UIThingsDB.minimap.minimapBorderSize or 3))
    borderSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        UIThingsDB.minimap.minimapBorderSize = value
        _G[self:GetName() .. "Text"]:SetText("Border Thickness: " .. value)
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateMinimapBorder then
            addonTable.MinimapCustom.UpdateMinimapBorder()
        end
    end)

    -- == Minimap Icons ==
    Helpers.CreateSectionHeader(child, "Minimap Icons", -80)

    -- Row 1: Mail + Tracking
    local showMailBtn = CreateFrame("CheckButton", "UIThingsShowMail", child, "ChatConfigCheckButtonTemplate")
    showMailBtn:SetPoint("TOPLEFT", 20, -110)
    _G[showMailBtn:GetName() .. "Text"]:SetText("Show Mail Icon")
    showMailBtn:SetChecked(UIThingsDB.minimap.minimapShowMail)
    showMailBtn:SetScript("OnClick", function(self)
        UIThingsDB.minimap.minimapShowMail = self:GetChecked()
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateMinimapIcons then
            addonTable.MinimapCustom.UpdateMinimapIcons()
        end
    end)

    local showTrackingBtn = CreateFrame("CheckButton", "UIThingsShowTracking", child, "ChatConfigCheckButtonTemplate")
    showTrackingBtn:SetPoint("TOPLEFT", 300, -110)
    _G[showTrackingBtn:GetName() .. "Text"]:SetText("Show Tracking Icon")
    showTrackingBtn:SetChecked(UIThingsDB.minimap.minimapShowTracking)
    showTrackingBtn:SetScript("OnClick", function(self)
        UIThingsDB.minimap.minimapShowTracking = self:GetChecked()
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateMinimapIcons then
            addonTable.MinimapCustom.UpdateMinimapIcons()
        end
    end)

    -- Row 2: App Drawer + Work Orders
    local showDrawerBtn = CreateFrame("CheckButton", "UIThingsShowAddonCompartment", child,
        "ChatConfigCheckButtonTemplate")
    showDrawerBtn:SetPoint("TOPLEFT", 20, -135)
    _G[showDrawerBtn:GetName() .. "Text"]:SetText("Show App Drawer")
    showDrawerBtn:SetChecked(UIThingsDB.minimap.minimapShowAddonCompartment)
    showDrawerBtn:SetScript("OnClick", function(self)
        UIThingsDB.minimap.minimapShowAddonCompartment = self:GetChecked()
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateMinimapIcons then
            addonTable.MinimapCustom.UpdateMinimapIcons()
        end
    end)

    local showWorkOrderBtn = CreateFrame("CheckButton", "UIThingsShowCraftingOrder", child,
        "ChatConfigCheckButtonTemplate")
    showWorkOrderBtn:SetPoint("TOPLEFT", 300, -135)
    _G[showWorkOrderBtn:GetName() .. "Text"]:SetText("Show Work Order Icon")
    showWorkOrderBtn:SetChecked(UIThingsDB.minimap.minimapShowCraftingOrder)
    showWorkOrderBtn:SetScript("OnClick", function(self)
        UIThingsDB.minimap.minimapShowCraftingOrder = self:GetChecked()
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateMinimapIcons then
            addonTable.MinimapCustom.UpdateMinimapIcons()
        end
    end)

    -- == Zone Text & Clock Settings (side by side) ==
    Helpers.CreateSectionHeader(child, "Zone Text & Clock", -170)

    -- ===== LEFT COLUMN: Zone Text =====
    local showZoneBtn = CreateFrame("CheckButton", "UIThingsShowZone", child, "ChatConfigCheckButtonTemplate")
    showZoneBtn:SetPoint("TOPLEFT", 20, -200)
    _G[showZoneBtn:GetName() .. "Text"]:SetText("Show Zone Name")
    showZoneBtn:SetChecked(UIThingsDB.minimap.minimapShowZone)
    showZoneBtn:SetScript("OnClick", function(self)
        UIThingsDB.minimap.minimapShowZone = self:GetChecked()
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateZoneText then
            addonTable.MinimapCustom.UpdateZoneText()
        end
    end)

    Helpers.CreateFontDropdown(child, "UIThingsZoneFont", "Zone Font:", UIThingsDB.minimap.minimapZoneFont,
        function(fontPath)
            UIThingsDB.minimap.minimapZoneFont = fontPath
            if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateZoneText then
                addonTable.MinimapCustom.UpdateZoneText()
            end
        end, 40, -230)

    local zoneSizeSlider = CreateFrame("Slider", "UIThingsZoneFontSize", child, "OptionsSliderTemplate")
    zoneSizeSlider:SetPoint("TOPLEFT", 40, -300)
    zoneSizeSlider:SetWidth(200)
    zoneSizeSlider:SetMinMaxValues(8, 24)
    zoneSizeSlider:SetValueStep(1)
    zoneSizeSlider:SetObeyStepOnDrag(true)
    zoneSizeSlider:SetValue(UIThingsDB.minimap.minimapZoneFontSize or 12)
    _G[zoneSizeSlider:GetName() .. "Low"]:SetText("8")
    _G[zoneSizeSlider:GetName() .. "High"]:SetText("24")
    _G[zoneSizeSlider:GetName() .. "Text"]:SetText("Zone Font Size: " .. (UIThingsDB.minimap.minimapZoneFontSize or 12))
    zoneSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        UIThingsDB.minimap.minimapZoneFontSize = value
        _G[self:GetName() .. "Text"]:SetText("Zone Font Size: " .. value)
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateZoneText then
            addonTable.MinimapCustom.UpdateZoneText()
        end
    end)

    -- Zone Font Color
    local zoneColorLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneColorLabel:SetPoint("TOPLEFT", 40, -328)
    zoneColorLabel:SetText("Font Color:")

    local zoneColorSwatch = CreateFrame("Button", nil, child)
    zoneColorSwatch:SetPoint("LEFT", zoneColorLabel, "RIGHT", 8, 0)
    zoneColorSwatch:SetSize(20, 20)
    local zcCur = UIThingsDB.minimap.minimapZoneFontColor or { r = 1, g = 1, b = 1 }
    zoneColorSwatch.tex = zoneColorSwatch:CreateTexture(nil, "BACKGROUND")
    zoneColorSwatch.tex:SetAllPoints()
    zoneColorSwatch.tex:SetColorTexture(zcCur.r, zcCur.g, zcCur.b)
    zoneColorSwatch:SetScript("OnClick", function()
        local c = UIThingsDB.minimap.minimapZoneFontColor or { r = 1, g = 1, b = 1 }
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r,
            g = c.g,
            b = c.b,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                c.r, c.g, c.b = r, g, b
                zoneColorSwatch.tex:SetColorTexture(r, g, b)
                UIThingsDB.minimap.minimapZoneFontColor = c
                if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateZoneText then
                    addonTable.MinimapCustom.UpdateZoneText()
                end
            end,
            cancelFunc = function()
                zoneColorSwatch.tex:SetColorTexture(c.r, c.g, c.b)
                UIThingsDB.minimap.minimapZoneFontColor = c
                if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateZoneText then
                    addonTable.MinimapCustom.UpdateZoneText()
                end
            end,
        })
    end)

    local lockZoneBtn = CreateFrame("CheckButton", "UIThingsLockZone", child, "ChatConfigCheckButtonTemplate")
    lockZoneBtn:SetPoint("TOPLEFT", 20, -355)
    _G[lockZoneBtn:GetName() .. "Text"]:SetText("Lock Zone Position")
    lockZoneBtn:SetChecked(true)
    lockZoneBtn:SetScript("OnClick", function(self)
        if addonTable.MinimapCustom and addonTable.MinimapCustom.SetZoneLocked then
            addonTable.MinimapCustom.SetZoneLocked(self:GetChecked())
        end
    end)

    local zoneOff = UIThingsDB.minimap.minimapZoneOffset or { x = 0, y = 4 }

    local zonePosLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zonePosLabel:SetPoint("TOPLEFT", 40, -383)
    zonePosLabel:SetText("X:")

    local zoneXBox = CreateFrame("EditBox", "UIThingsZoneX", child, "InputBoxTemplate")
    zoneXBox:SetPoint("LEFT", zonePosLabel, "RIGHT", 5, 0)
    zoneXBox:SetSize(45, 20)
    zoneXBox:SetAutoFocus(false)
    zoneXBox:SetText(tostring(math.floor(zoneOff.x + 0.5)))
    zoneXBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText()) or 0
        local curY = UIThingsDB.minimap.minimapZoneOffset and UIThingsDB.minimap.minimapZoneOffset.y or 4
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateZonePosition then
            addonTable.MinimapCustom.UpdateZonePosition(val, curY)
        end
        self:ClearFocus()
    end)

    local zoneYLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneYLabel:SetPoint("LEFT", zoneXBox, "RIGHT", 10, 0)
    zoneYLabel:SetText("Y:")

    local zoneYBox = CreateFrame("EditBox", "UIThingsZoneY", child, "InputBoxTemplate")
    zoneYBox:SetPoint("LEFT", zoneYLabel, "RIGHT", 5, 0)
    zoneYBox:SetSize(45, 20)
    zoneYBox:SetAutoFocus(false)
    zoneYBox:SetText(tostring(math.floor(zoneOff.y + 0.5)))
    zoneYBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText()) or 0
        local curX = UIThingsDB.minimap.minimapZoneOffset and UIThingsDB.minimap.minimapZoneOffset.x or 0
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateZonePosition then
            addonTable.MinimapCustom.UpdateZonePosition(curX, val)
        end
        self:ClearFocus()
    end)

    -- ===== RIGHT COLUMN: Clock =====
    local rightCol = 300

    local showClockBtn = CreateFrame("CheckButton", "UIThingsShowClock", child, "ChatConfigCheckButtonTemplate")
    showClockBtn:SetPoint("TOPLEFT", rightCol, -200)
    _G[showClockBtn:GetName() .. "Text"]:SetText("Show Clock")
    showClockBtn:SetChecked(UIThingsDB.minimap.minimapShowClock)
    showClockBtn:SetScript("OnClick", function(self)
        UIThingsDB.minimap.minimapShowClock = self:GetChecked()
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateClockText then
            addonTable.MinimapCustom.UpdateClockText()
        end
    end)

    Helpers.CreateFontDropdown(child, "UIThingsClockFont", "Clock Font:", UIThingsDB.minimap.minimapClockFont,
        function(fontPath)
            UIThingsDB.minimap.minimapClockFont = fontPath
            if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateClockText then
                addonTable.MinimapCustom.UpdateClockText()
            end
        end, rightCol + 20, -230)

    local clockSizeSlider = CreateFrame("Slider", "UIThingsClockFontSize", child, "OptionsSliderTemplate")
    clockSizeSlider:SetPoint("TOPLEFT", rightCol + 20, -300)
    clockSizeSlider:SetWidth(200)
    clockSizeSlider:SetMinMaxValues(8, 24)
    clockSizeSlider:SetValueStep(1)
    clockSizeSlider:SetObeyStepOnDrag(true)
    clockSizeSlider:SetValue(UIThingsDB.minimap.minimapClockFontSize or 11)
    _G[clockSizeSlider:GetName() .. "Low"]:SetText("8")
    _G[clockSizeSlider:GetName() .. "High"]:SetText("24")
    _G[clockSizeSlider:GetName() .. "Text"]:SetText("Clock Font Size: " .. (UIThingsDB.minimap.minimapClockFontSize or 11))
    clockSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        UIThingsDB.minimap.minimapClockFontSize = value
        _G[self:GetName() .. "Text"]:SetText("Clock Font Size: " .. value)
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateClockText then
            addonTable.MinimapCustom.UpdateClockText()
        end
    end)

    -- Clock Font Color
    local clockColorLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clockColorLabel:SetPoint("TOPLEFT", rightCol + 20, -328)
    clockColorLabel:SetText("Font Color:")

    local clockColorSwatch = CreateFrame("Button", nil, child)
    clockColorSwatch:SetPoint("LEFT", clockColorLabel, "RIGHT", 8, 0)
    clockColorSwatch:SetSize(20, 20)
    local ccCur = UIThingsDB.minimap.minimapClockFontColor or { r = 1, g = 1, b = 1 }
    clockColorSwatch.tex = clockColorSwatch:CreateTexture(nil, "BACKGROUND")
    clockColorSwatch.tex:SetAllPoints()
    clockColorSwatch.tex:SetColorTexture(ccCur.r, ccCur.g, ccCur.b)
    clockColorSwatch:SetScript("OnClick", function()
        local c = UIThingsDB.minimap.minimapClockFontColor or { r = 1, g = 1, b = 1 }
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r,
            g = c.g,
            b = c.b,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                c.r, c.g, c.b = r, g, b
                clockColorSwatch.tex:SetColorTexture(r, g, b)
                UIThingsDB.minimap.minimapClockFontColor = c
                if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateClockText then
                    addonTable.MinimapCustom.UpdateClockText()
                end
            end,
            cancelFunc = function()
                clockColorSwatch.tex:SetColorTexture(c.r, c.g, c.b)
                UIThingsDB.minimap.minimapClockFontColor = c
                if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateClockText then
                    addonTable.MinimapCustom.UpdateClockText()
                end
            end,
        })
    end)

    -- Clock Format Dropdown (12H/24H)
    local clockFormatLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clockFormatLabel:SetPoint("TOPLEFT", rightCol + 20, -355)
    clockFormatLabel:SetText("Format:")

    local clockFormatDropdown = CreateFrame("Frame", "UIThingsClockFormat", child, "UIDropDownMenuTemplate")
    clockFormatDropdown:SetPoint("LEFT", clockFormatLabel, "RIGHT", -5, -3)
    UIDropDownMenu_SetWidth(clockFormatDropdown, 50)
    UIDropDownMenu_SetText(clockFormatDropdown, UIThingsDB.minimap.minimapClockFormat or "24H")

    UIDropDownMenu_Initialize(clockFormatDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "24H"
        info.checked = (UIThingsDB.minimap.minimapClockFormat or "24H") == "24H"
        info.func = function()
            UIThingsDB.minimap.minimapClockFormat = "24H"
            UIDropDownMenu_SetText(clockFormatDropdown, "24H")
        end
        UIDropDownMenu_AddButton(info)

        info.text = "12H"
        info.checked = UIThingsDB.minimap.minimapClockFormat == "12H"
        info.func = function()
            UIThingsDB.minimap.minimapClockFormat = "12H"
            UIDropDownMenu_SetText(clockFormatDropdown, "12H")
        end
        UIDropDownMenu_AddButton(info)
    end)

    -- Time Source Dropdown (Local/Server) - no label, placed right of format
    local clockSourceDropdown = CreateFrame("Frame", "UIThingsClockSource", child, "UIDropDownMenuTemplate")
    clockSourceDropdown:SetPoint("LEFT", clockFormatDropdown, "RIGHT", -30, 0)
    UIDropDownMenu_SetWidth(clockSourceDropdown, 80)
    local srcText = (UIThingsDB.minimap.minimapClockTimeSource or "local") == "local" and "Local" or "Server"
    UIDropDownMenu_SetText(clockSourceDropdown, srcText)

    UIDropDownMenu_Initialize(clockSourceDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Local"
        info.checked = (UIThingsDB.minimap.minimapClockTimeSource or "local") == "local"
        info.func = function()
            UIThingsDB.minimap.minimapClockTimeSource = "local"
            UIDropDownMenu_SetText(clockSourceDropdown, "Local")
        end
        UIDropDownMenu_AddButton(info)

        info.text = "Server"
        info.checked = UIThingsDB.minimap.minimapClockTimeSource == "server"
        info.func = function()
            UIThingsDB.minimap.minimapClockTimeSource = "server"
            UIDropDownMenu_SetText(clockSourceDropdown, "Server")
        end
        UIDropDownMenu_AddButton(info)
    end)

    local lockClockBtn = CreateFrame("CheckButton", "UIThingsLockClock", child, "ChatConfigCheckButtonTemplate")
    lockClockBtn:SetPoint("TOPLEFT", rightCol, -390)
    _G[lockClockBtn:GetName() .. "Text"]:SetText("Lock Clock Position")
    lockClockBtn:SetChecked(true)
    lockClockBtn:SetScript("OnClick", function(self)
        if addonTable.MinimapCustom and addonTable.MinimapCustom.SetClockLocked then
            addonTable.MinimapCustom.SetClockLocked(self:GetChecked())
        end
    end)

    local clockOff = UIThingsDB.minimap.minimapClockOffset or { x = 0, y = -4 }

    local clockPosLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clockPosLabel:SetPoint("TOPLEFT", rightCol + 20, -418)
    clockPosLabel:SetText("X:")

    local clockXBox = CreateFrame("EditBox", "UIThingsClockX", child, "InputBoxTemplate")
    clockXBox:SetPoint("LEFT", clockPosLabel, "RIGHT", 5, 0)
    clockXBox:SetSize(45, 20)
    clockXBox:SetAutoFocus(false)
    clockXBox:SetText(tostring(math.floor(clockOff.x + 0.5)))
    clockXBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText()) or 0
        local curY = UIThingsDB.minimap.minimapClockOffset and UIThingsDB.minimap.minimapClockOffset.y or -4
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateClockPosition then
            addonTable.MinimapCustom.UpdateClockPosition(val, curY)
        end
        self:ClearFocus()
    end)

    local clockYLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clockYLabel:SetPoint("LEFT", clockXBox, "RIGHT", 10, 0)
    clockYLabel:SetText("Y:")

    local clockYBox = CreateFrame("EditBox", "UIThingsClockY", child, "InputBoxTemplate")
    clockYBox:SetPoint("LEFT", clockYLabel, "RIGHT", 5, 0)
    clockYBox:SetSize(45, 20)
    clockYBox:SetAutoFocus(false)
    clockYBox:SetText(tostring(math.floor(clockOff.y + 0.5)))
    clockYBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText()) or 0
        local curX = UIThingsDB.minimap.minimapClockOffset and UIThingsDB.minimap.minimapClockOffset.x or 0
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateClockPosition then
            addonTable.MinimapCustom.UpdateClockPosition(curX, val)
        end
        self:ClearFocus()
    end)

    -- == Coordinates ==
    Helpers.CreateSectionHeader(child, "Coordinates", -450)

    local showCoordsBtn = CreateFrame("CheckButton", "UIThingsShowCoords", child, "ChatConfigCheckButtonTemplate")
    showCoordsBtn:SetPoint("TOPLEFT", 20, -480)
    _G[showCoordsBtn:GetName() .. "Text"]:SetText("Show Coordinates")
    showCoordsBtn:SetChecked(UIThingsDB.minimap.minimapShowCoords)
    showCoordsBtn:SetScript("OnClick", function(self)
        UIThingsDB.minimap.minimapShowCoords = self:GetChecked()
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateCoordsText then
            addonTable.MinimapCustom.UpdateCoordsText()
        end
    end)

    Helpers.CreateFontDropdown(child, "UIThingsCoordsFont", "Font:", UIThingsDB.minimap.minimapCoordsFont,
        function(fontPath)
            UIThingsDB.minimap.minimapCoordsFont = fontPath
            if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateCoordsText then
                addonTable.MinimapCustom.UpdateCoordsText()
            end
        end, 40, -510)

    local coordsSizeSlider = CreateFrame("Slider", "UIThingsCoordsFontSize", child, "OptionsSliderTemplate")
    coordsSizeSlider:SetPoint("TOPLEFT", 40, -580)
    coordsSizeSlider:SetWidth(200)
    coordsSizeSlider:SetMinMaxValues(8, 24)
    coordsSizeSlider:SetValueStep(1)
    coordsSizeSlider:SetObeyStepOnDrag(true)
    coordsSizeSlider:SetValue(UIThingsDB.minimap.minimapCoordsFontSize or 11)
    _G[coordsSizeSlider:GetName() .. "Low"]:SetText("8")
    _G[coordsSizeSlider:GetName() .. "High"]:SetText("24")
    _G[coordsSizeSlider:GetName() .. "Text"]:SetText("Font Size: " .. (UIThingsDB.minimap.minimapCoordsFontSize or 11))
    coordsSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        UIThingsDB.minimap.minimapCoordsFontSize = value
        _G[self:GetName() .. "Text"]:SetText("Font Size: " .. value)
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateCoordsText then
            addonTable.MinimapCustom.UpdateCoordsText()
        end
    end)

    -- Coords Font Color
    local coordsColorLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    coordsColorLabel:SetPoint("TOPLEFT", 40, -608)
    coordsColorLabel:SetText("Font Color:")

    local coordsColorSwatch = CreateFrame("Button", nil, child)
    coordsColorSwatch:SetPoint("LEFT", coordsColorLabel, "RIGHT", 8, 0)
    coordsColorSwatch:SetSize(20, 20)
    local coordsCur = UIThingsDB.minimap.minimapCoordsFontColor or { r = 1, g = 1, b = 1 }
    coordsColorSwatch.tex = coordsColorSwatch:CreateTexture(nil, "BACKGROUND")
    coordsColorSwatch.tex:SetAllPoints()
    coordsColorSwatch.tex:SetColorTexture(coordsCur.r, coordsCur.g, coordsCur.b)
    coordsColorSwatch:SetScript("OnClick", function()
        local c = UIThingsDB.minimap.minimapCoordsFontColor or { r = 1, g = 1, b = 1 }
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r,
            g = c.g,
            b = c.b,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                c = { r = r, g = g, b = b }
                coordsColorSwatch.tex:SetColorTexture(r, g, b)
                UIThingsDB.minimap.minimapCoordsFontColor = c
                if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateCoordsText then
                    addonTable.MinimapCustom.UpdateCoordsText()
                end
            end,
            cancelFunc = function()
                coordsColorSwatch.tex:SetColorTexture(c.r, c.g, c.b)
                UIThingsDB.minimap.minimapCoordsFontColor = c
                if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateCoordsText then
                    addonTable.MinimapCustom.UpdateCoordsText()
                end
            end,
        })
    end)

    local lockCoordsBtn = CreateFrame("CheckButton", "UIThingsLockCoords", child, "ChatConfigCheckButtonTemplate")
    lockCoordsBtn:SetPoint("TOPLEFT", 20, -635)
    _G[lockCoordsBtn:GetName() .. "Text"]:SetText("Lock Coords Position")
    lockCoordsBtn:SetChecked(true)
    lockCoordsBtn:SetScript("OnClick", function(self)
        if addonTable.MinimapCustom and addonTable.MinimapCustom.SetCoordsLocked then
            addonTable.MinimapCustom.SetCoordsLocked(self:GetChecked())
        end
    end)

    local coordsOff = UIThingsDB.minimap.minimapCoordsOffset or { x = 0, y = -20 }

    local coordsPosLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    coordsPosLabel:SetPoint("TOPLEFT", 40, -663)
    coordsPosLabel:SetText("X:")

    local coordsXBox = CreateFrame("EditBox", "UIThingsMinimapCoordsX", child, "InputBoxTemplate")
    coordsXBox:SetPoint("LEFT", coordsPosLabel, "RIGHT", 5, 0)
    coordsXBox:SetSize(45, 20)
    coordsXBox:SetAutoFocus(false)
    coordsXBox:SetText(tostring(math.floor(coordsOff.x + 0.5)))
    coordsXBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText()) or 0
        local curY = UIThingsDB.minimap.minimapCoordsOffset and UIThingsDB.minimap.minimapCoordsOffset.y or -20
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateCoordsPosition then
            addonTable.MinimapCustom.UpdateCoordsPosition(val, curY)
        end
        self:ClearFocus()
    end)

    local coordsYLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    coordsYLabel:SetPoint("LEFT", coordsXBox, "RIGHT", 10, 0)
    coordsYLabel:SetText("Y:")

    local coordsYBox = CreateFrame("EditBox", "UIThingsMinimapCoordsY", child, "InputBoxTemplate")
    coordsYBox:SetPoint("LEFT", coordsYLabel, "RIGHT", 5, 0)
    coordsYBox:SetSize(45, 20)
    coordsYBox:SetAutoFocus(false)
    coordsYBox:SetText(tostring(math.floor(coordsOff.y + 0.5)))
    coordsYBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText()) or 0
        local curX = UIThingsDB.minimap.minimapCoordsOffset and UIThingsDB.minimap.minimapCoordsOffset.x or 0
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateCoordsPosition then
            addonTable.MinimapCustom.UpdateCoordsPosition(curX, val)
        end
        self:ClearFocus()
    end)

    -- == Minimap Drawer ==
    Helpers.CreateSectionHeader(child, "Minimap Drawer", -700)

    local drawerEnableBtn = CreateFrame("CheckButton", "UIThingsMinimapDrawerEnabled", child,
        "ChatConfigCheckButtonTemplate")
    drawerEnableBtn:SetPoint("TOPLEFT", 20, -730)
    drawerEnableBtn:SetHitRectInsets(0, -200, 0, 0)
    _G[drawerEnableBtn:GetName() .. "Text"]:SetText("Enable Minimap Drawer (requires reload)")
    drawerEnableBtn:SetChecked(UIThingsDB.minimap.minimapDrawerEnabled)
    drawerEnableBtn:SetScript("OnClick", function(self)
        UIThingsDB.minimap.minimapDrawerEnabled = self:GetChecked()
    end)

    local drawerLockBtn = CreateFrame("CheckButton", "UIThingsMinimapDrawerLocked", child,
        "ChatConfigCheckButtonTemplate")
    drawerLockBtn:SetPoint("TOPLEFT", 20, -755)
    drawerLockBtn:SetHitRectInsets(0, -130, 0, 0)
    _G[drawerLockBtn:GetName() .. "Text"]:SetText("Lock Drawer Position")
    drawerLockBtn:SetChecked(UIThingsDB.minimap.minimapDrawerLocked)
    drawerLockBtn:SetScript("OnClick", function(self)
        if addonTable.MinimapCustom and addonTable.MinimapCustom.SetDrawerLocked then
            addonTable.MinimapCustom.SetDrawerLocked(self:GetChecked())
        end
    end)

    -- Background Color
    local drawerBgLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    drawerBgLabel:SetPoint("TOPLEFT", 300, -730)
    drawerBgLabel:SetText("Background:")

    local drawerBgSwatch = CreateFrame("Button", nil, child)
    drawerBgSwatch:SetSize(20, 20)
    drawerBgSwatch:SetPoint("LEFT", drawerBgLabel, "RIGHT", 10, 0)

    drawerBgSwatch.tex = drawerBgSwatch:CreateTexture(nil, "OVERLAY")
    drawerBgSwatch.tex:SetAllPoints()
    local bgCol = UIThingsDB.minimap.minimapDrawerBgColor or { r = 0, g = 0, b = 0, a = 0.7 }
    drawerBgSwatch.tex:SetColorTexture(bgCol.r, bgCol.g, bgCol.b, bgCol.a or 0.7)

    Mixin(drawerBgSwatch, BackdropTemplateMixin)
    drawerBgSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    drawerBgSwatch:SetBackdropBorderColor(1, 1, 1)

    drawerBgSwatch:SetScript("OnClick", function()
        local c = UIThingsDB.minimap.minimapDrawerBgColor or { r = 0, g = 0, b = 0, a = 0.7 }
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
                    drawerBgSwatch.tex:SetColorTexture(r, g, b, a)
                    UIThingsDB.minimap.minimapDrawerBgColor = c
                    if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateDrawerBorder then
                        addonTable.MinimapCustom.UpdateDrawerBorder()
                    end
                end,
                cancelFunc = function()
                    drawerBgSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
                    UIThingsDB.minimap.minimapDrawerBgColor = c
                    if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateDrawerBorder then
                        addonTable.MinimapCustom.UpdateDrawerBorder()
                    end
                end,
            })
        end
    end)

    -- Border Color
    local drawerBorderLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    drawerBorderLabel:SetPoint("TOPLEFT", 300, -755)
    drawerBorderLabel:SetText("Border Color:")

    local drawerBorderSwatch = CreateFrame("Button", nil, child)
    drawerBorderSwatch:SetSize(20, 20)
    drawerBorderSwatch:SetPoint("LEFT", drawerBorderLabel, "RIGHT", 10, 0)

    drawerBorderSwatch.tex = drawerBorderSwatch:CreateTexture(nil, "OVERLAY")
    drawerBorderSwatch.tex:SetAllPoints()
    local dbCol = UIThingsDB.minimap.minimapDrawerBorderColor or { r = 0.3, g = 0.3, b = 0.3, a = 1 }
    drawerBorderSwatch.tex:SetColorTexture(dbCol.r, dbCol.g, dbCol.b, dbCol.a or 1)

    Mixin(drawerBorderSwatch, BackdropTemplateMixin)
    drawerBorderSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    drawerBorderSwatch:SetBackdropBorderColor(1, 1, 1)

    drawerBorderSwatch:SetScript("OnClick", function()
        local c = UIThingsDB.minimap.minimapDrawerBorderColor or { r = 0.3, g = 0.3, b = 0.3, a = 1 }
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
                    drawerBorderSwatch.tex:SetColorTexture(r, g, b, a)
                    UIThingsDB.minimap.minimapDrawerBorderColor = c
                    if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateDrawerBorder then
                        addonTable.MinimapCustom.UpdateDrawerBorder()
                    end
                end,
                cancelFunc = function()
                    drawerBorderSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
                    UIThingsDB.minimap.minimapDrawerBorderColor = c
                    if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateDrawerBorder then
                        addonTable.MinimapCustom.UpdateDrawerBorder()
                    end
                end,
            })
        end
    end)

    -- Border Thickness Slider
    local drawerBorderSlider = CreateFrame("Slider", "UIThingsDrawerBorderSize", child, "OptionsSliderTemplate")
    drawerBorderSlider:SetPoint("TOPLEFT", 300, -780)
    drawerBorderSlider:SetWidth(200)
    drawerBorderSlider:SetMinMaxValues(0, 5)
    drawerBorderSlider:SetValueStep(1)
    drawerBorderSlider:SetObeyStepOnDrag(true)
    drawerBorderSlider:SetValue(UIThingsDB.minimap.minimapDrawerBorderSize or 2)
    _G[drawerBorderSlider:GetName() .. "Low"]:SetText("0")
    _G[drawerBorderSlider:GetName() .. "High"]:SetText("5")
    _G[drawerBorderSlider:GetName() .. "Text"]:SetText("Border Thickness: " ..
        (UIThingsDB.minimap.minimapDrawerBorderSize or 2))
    drawerBorderSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        UIThingsDB.minimap.minimapDrawerBorderSize = value
        _G[self:GetName() .. "Text"]:SetText("Border Thickness: " .. value)
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateDrawerBorder then
            addonTable.MinimapCustom.UpdateDrawerBorder()
        end
    end)
end
