local addonName, addonTable = ...

-- Create setup table if it doesn't exist
addonTable.ConfigSetup = addonTable.ConfigSetup or {}

-- Get helpers
local Helpers = addonTable.ConfigHelpers

-- Define the setup function for Frames panel
function addonTable.ConfigSetup.Frames(panel, tab, configWindow)
    local fonts = Helpers.fonts

    local selectedFrameIndex = nil

    local function UpdateFrames()
        if addonTable.Frames and addonTable.Frames.UpdateFrames then
            addonTable.Frames.UpdateFrames()
        end
    end

    local framesTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    framesTitle:SetPoint("TOPLEFT", 16, -16)
    framesTitle:SetText("Custom Frames")

    local addFrameBtn, duplicateFrameBtn

    local framesEnableBtn = CreateFrame("CheckButton", "UIThingsFramesEnableCheck", panel,
        "ChatConfigCheckButtonTemplate")
    framesEnableBtn:SetPoint("TOPLEFT", 20, -50)
    _G[framesEnableBtn:GetName() .. "Text"]:SetText("Enable Custom Frames")
    framesEnableBtn:SetChecked(UIThingsDB.frames.enabled)
    framesEnableBtn:SetScript("OnClick", function(self)
        local enabled = self:GetChecked()
        UIThingsDB.frames.enabled = enabled
        UpdateFrames()
        Helpers.UpdateModuleVisuals(panel, tab, enabled)
        if addFrameBtn then addFrameBtn:SetEnabled(enabled) end
        if duplicateFrameBtn then duplicateFrameBtn:SetEnabled(enabled) end
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.frames.enabled)

    -- Frame Selector Dropdown
    local frameSelectLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frameSelectLabel:SetPoint("TOPLEFT", 20, -80)
    frameSelectLabel:SetText("Select Frame:")

    local frameDropdown = CreateFrame("Frame", "UIThingsFrameSelectDropdown", panel, "UIDropDownMenuTemplate")
    frameDropdown:SetPoint("TOPLEFT", frameSelectLabel, "BOTTOMLEFT", -15, -10)

    -- Controls Container (hidden if no frame selected)
    local frameControls = CreateFrame("Frame", nil, panel)
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
    addFrameBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
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
    duplicateFrameBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
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
    removeFrameBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -20, -80)
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

    -- Anchor Checkbox
    local anchorFrameBtn = CreateFrame("CheckButton", nil, frameControls, "ChatConfigCheckButtonTemplate")
    anchorFrameBtn:SetPoint("TOPLEFT", 140, -30) -- Next to Lock
    local anchorText = anchorFrameBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    anchorText:SetPoint("LEFT", anchorFrameBtn, "RIGHT", 5, 0)
    anchorText:SetText("Is Widget Anchor")
    anchorFrameBtn:SetScript("OnClick", function(self)
        if selectedFrameIndex then
            UIThingsDB.frames.list[selectedFrameIndex].isAnchor = self:GetChecked()
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
            _G[self:GetName() .. 'Text']:SetText("Width")
            widthEdit:SetText(tostring(value))
            UpdateFrames()
        end
    end)

    local heightSlider = CreateFrame("Slider", "UIThingsFrameHeightSlider", frameControls, "OptionsSliderTemplate")
    heightSlider:SetPoint("TOPLEFT", 195, -70)
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
    local borderTopBtn = CreateFrame("CheckButton", "UIThingsBorderTopCheck", frameControls,
        "ChatConfigCheckButtonTemplate")
    borderTopBtn:SetPoint("TOPLEFT", 140, -240)
    borderTopBtn.tooltip = "Show Top Border"
    borderTopBtn:SetScript("OnClick", function(self)
        if selectedFrameIndex then
            UIThingsDB.frames.list[selectedFrameIndex].showTop = self:GetChecked()
            UpdateFrames()
        end
    end)

    local borderBottomBtn = CreateFrame("CheckButton", "UIThingsBorderBottomCheck", frameControls,
        "ChatConfigCheckButtonTemplate")
    borderBottomBtn:SetPoint("TOP", borderTopBtn, "BOTTOM", 0, -24)
    borderBottomBtn.tooltip = "Show Bottom Border"
    borderBottomBtn:SetScript("OnClick", function(self)
        if selectedFrameIndex then
            UIThingsDB.frames.list[selectedFrameIndex].showBottom = self:GetChecked()
            UpdateFrames()
        end
    end)

    local borderLeftBtn = CreateFrame("CheckButton", "UIThingsBorderLeftCheck", frameControls,
        "ChatConfigCheckButtonTemplate")
    borderLeftBtn:SetPoint("TOPRIGHT", borderTopBtn, "BOTTOMLEFT", -2, -2)
    borderLeftBtn.tooltip = "Show Left Border"
    borderLeftBtn:SetScript("OnClick", function(self)
        if selectedFrameIndex then
            UIThingsDB.frames.list[selectedFrameIndex].showLeft = self:GetChecked()
            UpdateFrames()
        end
    end)

    local borderRightBtn = CreateFrame("CheckButton", "UIThingsBorderRightCheck", frameControls,
        "ChatConfigCheckButtonTemplate")
    borderRightBtn:SetPoint("TOPLEFT", borderTopBtn, "BOTTOMRIGHT", 2, -2)
    borderRightBtn:SetFrameLevel(borderTopBtn:GetFrameLevel() + 5)
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
            anchorFrameBtn:SetChecked(f.isAnchor)

            widthSlider:SetValue(f.width)
            _G[widthSlider:GetName() .. 'Text']:SetText("Width")
            widthEdit:SetText(tostring(f.width))

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

            -- Borders - defaults to true
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
end
