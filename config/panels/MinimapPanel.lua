local addonName, addonTable = ...

-- Create setup table if it doesn't exist
addonTable.ConfigSetup = addonTable.ConfigSetup or {}

-- Get helpers
local Helpers = addonTable.ConfigHelpers

-- Define the setup function for Minimap panel
function addonTable.ConfigSetup.Minimap(panel, navButton, configWindow)
    -- Visual compatibility with sidebar navigation
    Helpers.UpdateModuleVisuals(panel, navButton, UIThingsDB.misc.minimapEnabled)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Minimap Customization")

    -- Enable Checkbox
    local minimapBtn = CreateFrame("CheckButton", "UIThingsMinimapEnabled", panel, "ChatConfigCheckButtonTemplate")
    minimapBtn:SetPoint("TOPLEFT", 20, -50)
    _G[minimapBtn:GetName() .. "Text"]:SetText("Enable Minimap Customization (requires reload)")
    minimapBtn:SetChecked(UIThingsDB.misc.minimapEnabled)
    minimapBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.minimapEnabled = self:GetChecked()
        Helpers.UpdateModuleVisuals(panel, navButton, UIThingsDB.misc.minimapEnabled)
    end)

    -- Shape Dropdown
    local shapeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    shapeLabel:SetPoint("TOPLEFT", 40, -90)
    shapeLabel:SetText("Shape:")

    local shapeDropdown = CreateFrame("Frame", "UIThingsMinimapShape", panel, "UIDropDownMenuTemplate")
    shapeDropdown:SetPoint("LEFT", shapeLabel, "RIGHT", -5, -3)
    UIDropDownMenu_SetWidth(shapeDropdown, 100)
    UIDropDownMenu_SetText(shapeDropdown, UIThingsDB.misc.minimapShape == "SQUARE" and "Square" or "Round")

    UIDropDownMenu_Initialize(shapeDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()

        info.text = "Round"
        info.checked = UIThingsDB.misc.minimapShape == "ROUND"
        info.func = function()
            UIThingsDB.misc.minimapShape = "ROUND"
            UIDropDownMenu_SetText(shapeDropdown, "Round")
            if UIThingsDB.misc.minimapEnabled and addonTable.MinimapCustom and addonTable.MinimapCustom.ApplyMinimapShape then
                addonTable.MinimapCustom.ApplyMinimapShape("ROUND")
            end
        end
        UIDropDownMenu_AddButton(info)

        info.text = "Square"
        info.checked = UIThingsDB.misc.minimapShape == "SQUARE"
        info.func = function()
            UIThingsDB.misc.minimapShape = "SQUARE"
            UIDropDownMenu_SetText(shapeDropdown, "Square")
            if UIThingsDB.misc.minimapEnabled and addonTable.MinimapCustom and addonTable.MinimapCustom.ApplyMinimapShape then
                addonTable.MinimapCustom.ApplyMinimapShape("SQUARE")
            end
        end
        UIDropDownMenu_AddButton(info)
    end)

    -- Lock Checkbox
    local lockBtn = CreateFrame("CheckButton", "UIThingsMinimapLocked", panel, "ChatConfigCheckButtonTemplate")
    lockBtn:SetPoint("TOPLEFT", 20, -125)
    _G[lockBtn:GetName() .. "Text"]:SetText("Lock Minimap Position")
    lockBtn:SetChecked(true) -- Always defaults to locked
    lockBtn:SetScript("OnClick", function(self)
        if addonTable.MinimapCustom and addonTable.MinimapCustom.SetMinimapLocked then
            addonTable.MinimapCustom.SetMinimapLocked(self:GetChecked())
        end
    end)

    -- Border Color
    local borderColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    borderColorLabel:SetPoint("TOPLEFT", 300, -90)
    borderColorLabel:SetText("Border Color:")

    local borderSwatch = CreateFrame("Button", nil, panel)
    borderSwatch:SetSize(20, 20)
    borderSwatch:SetPoint("LEFT", borderColorLabel, "RIGHT", 10, 0)

    borderSwatch.tex = borderSwatch:CreateTexture(nil, "OVERLAY")
    borderSwatch.tex:SetAllPoints()
    local bCol = UIThingsDB.misc.minimapBorderColor or { r = 0, g = 0, b = 0, a = 1 }
    borderSwatch.tex:SetColorTexture(bCol.r, bCol.g, bCol.b, bCol.a or 1)

    Mixin(borderSwatch, BackdropTemplateMixin)
    borderSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    borderSwatch:SetBackdropBorderColor(1, 1, 1)

    borderSwatch:SetScript("OnClick", function()
        local c = UIThingsDB.misc.minimapBorderColor or { r = 0, g = 0, b = 0, a = 1 }
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
                    UIThingsDB.misc.minimapBorderColor = c
                    if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateMinimapBorder then addonTable
                            .MinimapCustom.UpdateMinimapBorder() end
                end,
                cancelFunc = function()
                    borderSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
                    UIThingsDB.misc.minimapBorderColor = c
                    if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateMinimapBorder then addonTable
                            .MinimapCustom.UpdateMinimapBorder() end
                end,
            })
        end
    end)

    -- Border Thickness Slider
    local borderSlider = CreateFrame("Slider", "UIThingsMinimapBorderSize", panel, "OptionsSliderTemplate")
    borderSlider:SetPoint("TOPLEFT", 320, -125)
    borderSlider:SetWidth(200)
    borderSlider:SetMinMaxValues(0, 10)
    borderSlider:SetValueStep(1)
    borderSlider:SetObeyStepOnDrag(true)
    borderSlider:SetValue(UIThingsDB.misc.minimapBorderSize or 3)
    _G[borderSlider:GetName() .. "Low"]:SetText("0")
    _G[borderSlider:GetName() .. "High"]:SetText("10")
    _G[borderSlider:GetName() .. "Text"]:SetText("Border Thickness: " .. (UIThingsDB.misc.minimapBorderSize or 3))
    borderSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        UIThingsDB.misc.minimapBorderSize = value
        _G[self:GetName() .. "Text"]:SetText("Border Thickness: " .. value)
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateMinimapBorder then addonTable.MinimapCustom
                .UpdateMinimapBorder() end
    end)

    -- == Minimap Icons ==
    Helpers.CreateSectionHeader(panel, "Minimap Icons", -160)

    -- Row 1: Mail + Tracking
    local showMailBtn = CreateFrame("CheckButton", "UIThingsShowMail", panel, "ChatConfigCheckButtonTemplate")
    showMailBtn:SetPoint("TOPLEFT", 20, -190)
    _G[showMailBtn:GetName() .. "Text"]:SetText("Show Mail Icon")
    showMailBtn:SetChecked(UIThingsDB.misc.minimapShowMail)
    showMailBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.minimapShowMail = self:GetChecked()
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateMinimapIcons then addonTable.MinimapCustom
                .UpdateMinimapIcons() end
    end)

    local showTrackingBtn = CreateFrame("CheckButton", "UIThingsShowTracking", panel, "ChatConfigCheckButtonTemplate")
    showTrackingBtn:SetPoint("TOPLEFT", 300, -190)
    _G[showTrackingBtn:GetName() .. "Text"]:SetText("Show Tracking Icon")
    showTrackingBtn:SetChecked(UIThingsDB.misc.minimapShowTracking)
    showTrackingBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.minimapShowTracking = self:GetChecked()
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateMinimapIcons then addonTable.MinimapCustom
                .UpdateMinimapIcons() end
    end)

    -- Row 2: App Drawer + Work Orders
    local showDrawerBtn = CreateFrame("CheckButton", "UIThingsShowAddonCompartment", panel,
        "ChatConfigCheckButtonTemplate")
    showDrawerBtn:SetPoint("TOPLEFT", 20, -215)
    _G[showDrawerBtn:GetName() .. "Text"]:SetText("Show App Drawer")
    showDrawerBtn:SetChecked(UIThingsDB.misc.minimapShowAddonCompartment)
    showDrawerBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.minimapShowAddonCompartment = self:GetChecked()
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateMinimapIcons then addonTable.MinimapCustom
                .UpdateMinimapIcons() end
    end)

    local showWorkOrderBtn = CreateFrame("CheckButton", "UIThingsShowCraftingOrder", panel,
        "ChatConfigCheckButtonTemplate")
    showWorkOrderBtn:SetPoint("TOPLEFT", 300, -215)
    _G[showWorkOrderBtn:GetName() .. "Text"]:SetText("Show Work Order Icon")
    showWorkOrderBtn:SetChecked(UIThingsDB.misc.minimapShowCraftingOrder)
    showWorkOrderBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.minimapShowCraftingOrder = self:GetChecked()
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateMinimapIcons then addonTable.MinimapCustom
                .UpdateMinimapIcons() end
    end)

    -- == Zone Text & Clock Settings (side by side) ==
    Helpers.CreateSectionHeader(panel, "Zone Text & Clock", -250)


    -- ===== LEFT COLUMN: Zone Text =====
    local showZoneBtn = CreateFrame("CheckButton", "UIThingsShowZone", panel, "ChatConfigCheckButtonTemplate")
    showZoneBtn:SetPoint("TOPLEFT", 20, -280)
    _G[showZoneBtn:GetName() .. "Text"]:SetText("Show Zone Name")
    showZoneBtn:SetChecked(UIThingsDB.misc.minimapShowZone)
    showZoneBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.minimapShowZone = self:GetChecked()
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateZoneText then addonTable.MinimapCustom
                .UpdateZoneText() end
    end)

    Helpers.CreateFontDropdown(panel, "UIThingsZoneFont", "Zone Font:", UIThingsDB.misc.minimapZoneFont,
        function(fontPath)
            UIThingsDB.misc.minimapZoneFont = fontPath
            if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateZoneText then addonTable.MinimapCustom
                    .UpdateZoneText() end
        end, 40, -310)

    local zoneSizeSlider = CreateFrame("Slider", "UIThingsZoneFontSize", panel, "OptionsSliderTemplate")
    zoneSizeSlider:SetPoint("TOPLEFT", 40, -380)
    zoneSizeSlider:SetWidth(200)
    zoneSizeSlider:SetMinMaxValues(8, 24)
    zoneSizeSlider:SetValueStep(1)
    zoneSizeSlider:SetObeyStepOnDrag(true)
    zoneSizeSlider:SetValue(UIThingsDB.misc.minimapZoneFontSize or 12)
    _G[zoneSizeSlider:GetName() .. "Low"]:SetText("8")
    _G[zoneSizeSlider:GetName() .. "High"]:SetText("24")
    _G[zoneSizeSlider:GetName() .. "Text"]:SetText("Zone Font Size: " .. (UIThingsDB.misc.minimapZoneFontSize or 12))
    zoneSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        UIThingsDB.misc.minimapZoneFontSize = value
        _G[self:GetName() .. "Text"]:SetText("Zone Font Size: " .. value)
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateZoneText then addonTable.MinimapCustom
                .UpdateZoneText() end
    end)

    -- Zone Font Color
    local zoneColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneColorLabel:SetPoint("TOPLEFT", 40, -408)
    zoneColorLabel:SetText("Font Color:")

    local zoneColorSwatch = CreateFrame("Button", nil, panel)
    zoneColorSwatch:SetPoint("LEFT", zoneColorLabel, "RIGHT", 8, 0)
    zoneColorSwatch:SetSize(20, 20)
    local zcCur = UIThingsDB.misc.minimapZoneFontColor or { r = 1, g = 1, b = 1 }
    zoneColorSwatch.tex = zoneColorSwatch:CreateTexture(nil, "BACKGROUND")
    zoneColorSwatch.tex:SetAllPoints()
    zoneColorSwatch.tex:SetColorTexture(zcCur.r, zcCur.g, zcCur.b)
    zoneColorSwatch:SetScript("OnClick", function()
        local c = UIThingsDB.misc.minimapZoneFontColor or { r = 1, g = 1, b = 1 }
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r,
            g = c.g,
            b = c.b,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                c.r, c.g, c.b = r, g, b
                zoneColorSwatch.tex:SetColorTexture(r, g, b)
                UIThingsDB.misc.minimapZoneFontColor = c
                if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateZoneText then addonTable.MinimapCustom
                        .UpdateZoneText() end
            end,
            cancelFunc = function()
                zoneColorSwatch.tex:SetColorTexture(c.r, c.g, c.b)
                UIThingsDB.misc.minimapZoneFontColor = c
                if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateZoneText then addonTable.MinimapCustom
                        .UpdateZoneText() end
            end,
        })
    end)

    local lockZoneBtn = CreateFrame("CheckButton", "UIThingsLockZone", panel, "ChatConfigCheckButtonTemplate")
    lockZoneBtn:SetPoint("TOPLEFT", 20, -435)
    _G[lockZoneBtn:GetName() .. "Text"]:SetText("Lock Zone Position")
    lockZoneBtn:SetChecked(true)
    lockZoneBtn:SetScript("OnClick", function(self)
        if addonTable.MinimapCustom and addonTable.MinimapCustom.SetZoneLocked then
            addonTable.MinimapCustom.SetZoneLocked(self:GetChecked())
        end
    end)

    local zoneOff = UIThingsDB.misc.minimapZoneOffset or { x = 0, y = 4 }

    local zonePosLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zonePosLabel:SetPoint("TOPLEFT", 40, -463)
    zonePosLabel:SetText("X:")

    local zoneXBox = CreateFrame("EditBox", "UIThingsZoneX", panel, "InputBoxTemplate")
    zoneXBox:SetPoint("LEFT", zonePosLabel, "RIGHT", 5, 0)
    zoneXBox:SetSize(45, 20)
    zoneXBox:SetAutoFocus(false)
    zoneXBox:SetText(tostring(math.floor(zoneOff.x + 0.5)))
    zoneXBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText()) or 0
        local curY = UIThingsDB.misc.minimapZoneOffset and UIThingsDB.misc.minimapZoneOffset.y or 4
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateZonePosition then
            addonTable.MinimapCustom.UpdateZonePosition(val, curY)
        end
        self:ClearFocus()
    end)

    local zoneYLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneYLabel:SetPoint("LEFT", zoneXBox, "RIGHT", 10, 0)
    zoneYLabel:SetText("Y:")

    local zoneYBox = CreateFrame("EditBox", "UIThingsZoneY", panel, "InputBoxTemplate")
    zoneYBox:SetPoint("LEFT", zoneYLabel, "RIGHT", 5, 0)
    zoneYBox:SetSize(45, 20)
    zoneYBox:SetAutoFocus(false)
    zoneYBox:SetText(tostring(math.floor(zoneOff.y + 0.5)))
    zoneYBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText()) or 0
        local curX = UIThingsDB.misc.minimapZoneOffset and UIThingsDB.misc.minimapZoneOffset.x or 0
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateZonePosition then
            addonTable.MinimapCustom.UpdateZonePosition(curX, val)
        end
        self:ClearFocus()
    end)

    -- ===== RIGHT COLUMN: Clock =====
    local rightCol = 300

    local showClockBtn = CreateFrame("CheckButton", "UIThingsShowClock", panel, "ChatConfigCheckButtonTemplate")
    showClockBtn:SetPoint("TOPLEFT", rightCol, -280)
    _G[showClockBtn:GetName() .. "Text"]:SetText("Show Clock")
    showClockBtn:SetChecked(UIThingsDB.misc.minimapShowClock)
    showClockBtn:SetScript("OnClick", function(self)
        UIThingsDB.misc.minimapShowClock = self:GetChecked()
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateClockText then addonTable.MinimapCustom
                .UpdateClockText() end
    end)

    Helpers.CreateFontDropdown(panel, "UIThingsClockFont", "Clock Font:", UIThingsDB.misc.minimapClockFont,
        function(fontPath)
            UIThingsDB.misc.minimapClockFont = fontPath
            if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateClockText then addonTable.MinimapCustom
                    .UpdateClockText() end
        end, rightCol + 20, -310)

    local clockSizeSlider = CreateFrame("Slider", "UIThingsClockFontSize", panel, "OptionsSliderTemplate")
    clockSizeSlider:SetPoint("TOPLEFT", rightCol + 20, -380)
    clockSizeSlider:SetWidth(200)
    clockSizeSlider:SetMinMaxValues(8, 24)
    clockSizeSlider:SetValueStep(1)
    clockSizeSlider:SetObeyStepOnDrag(true)
    clockSizeSlider:SetValue(UIThingsDB.misc.minimapClockFontSize or 11)
    _G[clockSizeSlider:GetName() .. "Low"]:SetText("8")
    _G[clockSizeSlider:GetName() .. "High"]:SetText("24")
    _G[clockSizeSlider:GetName() .. "Text"]:SetText("Clock Font Size: " .. (UIThingsDB.misc.minimapClockFontSize or 11))
    clockSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        UIThingsDB.misc.minimapClockFontSize = value
        _G[self:GetName() .. "Text"]:SetText("Clock Font Size: " .. value)
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateClockText then addonTable.MinimapCustom
                .UpdateClockText() end
    end)

    -- Clock Font Color
    local clockColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clockColorLabel:SetPoint("TOPLEFT", rightCol + 20, -408)
    clockColorLabel:SetText("Font Color:")

    local clockColorSwatch = CreateFrame("Button", nil, panel)
    clockColorSwatch:SetPoint("LEFT", clockColorLabel, "RIGHT", 8, 0)
    clockColorSwatch:SetSize(20, 20)
    local ccCur = UIThingsDB.misc.minimapClockFontColor or { r = 1, g = 1, b = 1 }
    clockColorSwatch.tex = clockColorSwatch:CreateTexture(nil, "BACKGROUND")
    clockColorSwatch.tex:SetAllPoints()
    clockColorSwatch.tex:SetColorTexture(ccCur.r, ccCur.g, ccCur.b)
    clockColorSwatch:SetScript("OnClick", function()
        local c = UIThingsDB.misc.minimapClockFontColor or { r = 1, g = 1, b = 1 }
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r,
            g = c.g,
            b = c.b,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                c.r, c.g, c.b = r, g, b
                clockColorSwatch.tex:SetColorTexture(r, g, b)
                UIThingsDB.misc.minimapClockFontColor = c
                if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateClockText then addonTable.MinimapCustom
                        .UpdateClockText() end
            end,
            cancelFunc = function()
                clockColorSwatch.tex:SetColorTexture(c.r, c.g, c.b)
                UIThingsDB.misc.minimapClockFontColor = c
                if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateClockText then addonTable.MinimapCustom
                        .UpdateClockText() end
            end,
        })
    end)

    -- Clock Format Dropdown (12H/24H)
    local clockFormatLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clockFormatLabel:SetPoint("TOPLEFT", rightCol + 20, -435)
    clockFormatLabel:SetText("Format:")

    local clockFormatDropdown = CreateFrame("Frame", "UIThingsClockFormat", panel, "UIDropDownMenuTemplate")
    clockFormatDropdown:SetPoint("LEFT", clockFormatLabel, "RIGHT", -5, -3)
    UIDropDownMenu_SetWidth(clockFormatDropdown, 50)
    UIDropDownMenu_SetText(clockFormatDropdown, UIThingsDB.misc.minimapClockFormat or "24H")

    UIDropDownMenu_Initialize(clockFormatDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "24H"
        info.checked = (UIThingsDB.misc.minimapClockFormat or "24H") == "24H"
        info.func = function()
            UIThingsDB.misc.minimapClockFormat = "24H"
            UIDropDownMenu_SetText(clockFormatDropdown, "24H")
        end
        UIDropDownMenu_AddButton(info)

        info.text = "12H"
        info.checked = UIThingsDB.misc.minimapClockFormat == "12H"
        info.func = function()
            UIThingsDB.misc.minimapClockFormat = "12H"
            UIDropDownMenu_SetText(clockFormatDropdown, "12H")
        end
        UIDropDownMenu_AddButton(info)
    end)

    -- Time Source Dropdown (Local/Server) - no label, placed right of format
    local clockSourceDropdown = CreateFrame("Frame", "UIThingsClockSource", panel, "UIDropDownMenuTemplate")
    clockSourceDropdown:SetPoint("LEFT", clockFormatDropdown, "RIGHT", -30, 0)
    UIDropDownMenu_SetWidth(clockSourceDropdown, 80)
    local srcText = (UIThingsDB.misc.minimapClockTimeSource or "local") == "local" and "Local" or "Server"
    UIDropDownMenu_SetText(clockSourceDropdown, srcText)

    UIDropDownMenu_Initialize(clockSourceDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Local"
        info.checked = (UIThingsDB.misc.minimapClockTimeSource or "local") == "local"
        info.func = function()
            UIThingsDB.misc.minimapClockTimeSource = "local"
            UIDropDownMenu_SetText(clockSourceDropdown, "Local")
        end
        UIDropDownMenu_AddButton(info)

        info.text = "Server"
        info.checked = UIThingsDB.misc.minimapClockTimeSource == "server"
        info.func = function()
            UIThingsDB.misc.minimapClockTimeSource = "server"
            UIDropDownMenu_SetText(clockSourceDropdown, "Server")
        end
        UIDropDownMenu_AddButton(info)
    end)

    local lockClockBtn = CreateFrame("CheckButton", "UIThingsLockClock", panel, "ChatConfigCheckButtonTemplate")
    lockClockBtn:SetPoint("TOPLEFT", rightCol, -470)
    _G[lockClockBtn:GetName() .. "Text"]:SetText("Lock Clock Position")
    lockClockBtn:SetChecked(true)
    lockClockBtn:SetScript("OnClick", function(self)
        if addonTable.MinimapCustom and addonTable.MinimapCustom.SetClockLocked then
            addonTable.MinimapCustom.SetClockLocked(self:GetChecked())
        end
    end)

    local clockOff = UIThingsDB.misc.minimapClockOffset or { x = 0, y = -4 }

    local clockPosLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clockPosLabel:SetPoint("TOPLEFT", rightCol + 20, -498)
    clockPosLabel:SetText("X:")

    local clockXBox = CreateFrame("EditBox", "UIThingsClockX", panel, "InputBoxTemplate")
    clockXBox:SetPoint("LEFT", clockPosLabel, "RIGHT", 5, 0)
    clockXBox:SetSize(45, 20)
    clockXBox:SetAutoFocus(false)
    clockXBox:SetText(tostring(math.floor(clockOff.x + 0.5)))
    clockXBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText()) or 0
        local curY = UIThingsDB.misc.minimapClockOffset and UIThingsDB.misc.minimapClockOffset.y or -4
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateClockPosition then
            addonTable.MinimapCustom.UpdateClockPosition(val, curY)
        end
        self:ClearFocus()
    end)

    local clockYLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clockYLabel:SetPoint("LEFT", clockXBox, "RIGHT", 10, 0)
    clockYLabel:SetText("Y:")

    local clockYBox = CreateFrame("EditBox", "UIThingsClockY", panel, "InputBoxTemplate")
    clockYBox:SetPoint("LEFT", clockYLabel, "RIGHT", 5, 0)
    clockYBox:SetSize(45, 20)
    clockYBox:SetAutoFocus(false)
    clockYBox:SetText(tostring(math.floor(clockOff.y + 0.5)))
    clockYBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText()) or 0
        local curX = UIThingsDB.misc.minimapClockOffset and UIThingsDB.misc.minimapClockOffset.x or 0
        if addonTable.MinimapCustom and addonTable.MinimapCustom.UpdateClockPosition then
            addonTable.MinimapCustom.UpdateClockPosition(curX, val)
        end
        self:ClearFocus()
    end)
end
