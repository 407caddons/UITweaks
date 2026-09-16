local addonName, addonTable = "LunaUITweaks", _G["LunaUITweaks"]
addonTable.ConfigSetup = addonTable.ConfigSetup or {}
local Helpers = addonTable.ConfigHelpers

function addonTable.ConfigSetup.CastBar(panel, tab, configWindow)
    Helpers.CreateResetButton(panel, "castBar")
    -- Create ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "UIThingsCastBarScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 0)

    local child = CreateFrame("Frame", nil, scrollFrame)
    child:SetSize(650, 1120)
    scrollFrame:SetScrollChild(child)

    scrollFrame:SetScript("OnShow", function()
        child:SetWidth(scrollFrame:GetWidth())
    end)

    local function UpdateCastBar()
        if addonTable.CastBar and addonTable.CastBar.UpdateSettings then
            addonTable.CastBar.UpdateSettings()
        end
    end

    -- Title
    local title = child:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Cast Bar")

    -- Enable Checkbox
    local enableBtn = CreateFrame("CheckButton", "UIThingsCastBarEnable", child, "ChatConfigCheckButtonTemplate")
    enableBtn:SetPoint("TOPLEFT", 20, -50)
    _G[enableBtn:GetName() .. "Text"]:SetText("Enable Custom Cast Bar")
    enableBtn:SetChecked(UIThingsDB.castBar.enabled)
    enableBtn:SetScript("OnClick", function(self)
        UIThingsDB.castBar.enabled = not not self:GetChecked()
        Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.castBar.enabled)
        UpdateCastBar()
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.castBar.enabled)

    -- Lock Checkbox
    local lockBtn = CreateFrame("CheckButton", "UIThingsCastBarLock", child, "ChatConfigCheckButtonTemplate")
    lockBtn:SetPoint("TOPLEFT", 260, -50)
    _G[lockBtn:GetName() .. "Text"]:SetText("Lock Cast Bar")
    lockBtn:SetChecked(UIThingsDB.castBar.locked)
    lockBtn:SetScript("OnClick", function(self)
        UIThingsDB.castBar.locked = not not self:GetChecked()
        UpdateCastBar()
    end)

    -- == Appearance ==
    Helpers.CreateSectionHeader(child, "Appearance", -85)

    -- Width Slider
    local widthSlider = CreateFrame("Slider", "UIThingsCastBarWidth", child, "OptionsSliderTemplate")
    widthSlider:SetPoint("TOPLEFT", 20, -120)
    widthSlider:SetMinMaxValues(100, 500)
    widthSlider:SetValueStep(5)
    widthSlider:SetObeyStepOnDrag(true)
    widthSlider:SetWidth(200)
    _G[widthSlider:GetName() .. "Text"]:SetText("Width: " .. UIThingsDB.castBar.width)
    _G[widthSlider:GetName() .. "Low"]:SetText("100")
    _G[widthSlider:GetName() .. "High"]:SetText("500")
    widthSlider:SetValue(UIThingsDB.castBar.width)
    widthSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.castBar.width = value
        _G[self:GetName() .. "Text"]:SetText("Width: " .. value)
        UpdateCastBar()
    end)

    -- Height Slider
    local heightSlider = CreateFrame("Slider", "UIThingsCastBarHeight", child, "OptionsSliderTemplate")
    heightSlider:SetPoint("TOPLEFT", 260, -120)
    heightSlider:SetMinMaxValues(8, 40)
    heightSlider:SetValueStep(1)
    heightSlider:SetObeyStepOnDrag(true)
    heightSlider:SetWidth(200)
    _G[heightSlider:GetName() .. "Text"]:SetText("Height: " .. UIThingsDB.castBar.height)
    _G[heightSlider:GetName() .. "Low"]:SetText("8")
    _G[heightSlider:GetName() .. "High"]:SetText("40")
    heightSlider:SetValue(UIThingsDB.castBar.height)
    heightSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.castBar.height = value
        _G[self:GetName() .. "Text"]:SetText("Height: " .. value)
        UpdateCastBar()
    end)

    -- Border Size Slider
    local borderSlider = CreateFrame("Slider", "UIThingsCastBarBorderSize", child, "OptionsSliderTemplate")
    borderSlider:SetPoint("TOPLEFT", 20, -170)
    borderSlider:SetMinMaxValues(0, 5)
    borderSlider:SetValueStep(1)
    borderSlider:SetObeyStepOnDrag(true)
    borderSlider:SetWidth(200)
    _G[borderSlider:GetName() .. "Text"]:SetText("Border: " .. UIThingsDB.castBar.borderSize)
    _G[borderSlider:GetName() .. "Low"]:SetText("0")
    _G[borderSlider:GetName() .. "High"]:SetText("5")
    borderSlider:SetValue(UIThingsDB.castBar.borderSize)
    borderSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.castBar.borderSize = value
        _G[self:GetName() .. "Text"]:SetText("Border: " .. value)
        UpdateCastBar()
    end)

    -- Bar Texture Dropdown
    Helpers.CreateTextureDropdown(
        child,
        "UIThingsCastBarTextureDropdown",
        "Bar Texture:",
        UIThingsDB.castBar.barTexture,
        function(texturePath, textureName)
            UIThingsDB.castBar.barTexture = texturePath
            UpdateCastBar()
        end,
        260,
        -170
    )

    -- == Position ==
    -- X Position
    local xLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    xLabel:SetPoint("TOPLEFT", 20, -260)
    xLabel:SetText("X Position:")

    local function RoundCoord(val)
        return math.floor(val * 10 + 0.5) / 10
    end

    local xEditBox = CreateFrame("EditBox", "UIThingsCastBarPosX", child, "InputBoxTemplate")
    xEditBox:SetSize(60, 20)
    xEditBox:SetPoint("LEFT", xLabel, "RIGHT", 8, 0)
    xEditBox:SetAutoFocus(false)
    xEditBox:SetNumeric(false)
    xEditBox:SetText(tostring(RoundCoord(UIThingsDB.castBar.pos.x or 0)))
    xEditBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            UIThingsDB.castBar.pos.x = RoundCoord(val)
            self:SetText(tostring(UIThingsDB.castBar.pos.x))
            UpdateCastBar()
        end
        self:ClearFocus()
    end)
    xEditBox:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(RoundCoord(UIThingsDB.castBar.pos.x or 0)))
        self:ClearFocus()
    end)

    -- Y Position
    local yLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    yLabel:SetPoint("TOPLEFT", 200, -260)
    yLabel:SetText("Y Position:")

    local yEditBox = CreateFrame("EditBox", "UIThingsCastBarPosY", child, "InputBoxTemplate")
    yEditBox:SetSize(60, 20)
    yEditBox:SetPoint("LEFT", yLabel, "RIGHT", 8, 0)
    yEditBox:SetAutoFocus(false)
    yEditBox:SetNumeric(false)
    yEditBox:SetText(tostring(RoundCoord(UIThingsDB.castBar.pos.y or 0)))
    yEditBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            UIThingsDB.castBar.pos.y = RoundCoord(val)
            self:SetText(tostring(UIThingsDB.castBar.pos.y))
            UpdateCastBar()
        end
        self:ClearFocus()
    end)
    yEditBox:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(RoundCoord(UIThingsDB.castBar.pos.y or 0)))
        self:ClearFocus()
    end)

    -- Anchor Point Dropdown
    local anchorLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    anchorLabel:SetPoint("TOPLEFT", 380, -260)
    anchorLabel:SetText("Anchor:")

    local anchorDropdown = CreateFrame("Frame", "UIThingsCastBarAnchorDropdown", child, "UIDropDownMenuTemplate")
    anchorDropdown:SetPoint("LEFT", anchorLabel, "RIGHT", -15, -3)

    local anchorOptions = { "CENTER", "TOP", "BOTTOM", "LEFT", "RIGHT", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT",
        "BOTTOMRIGHT" }
    UIDropDownMenu_SetWidth(anchorDropdown, 90)
    UIDropDownMenu_Initialize(anchorDropdown, function(self, level)
        for _, point in ipairs(anchorOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = point
            info.value = point
            info.func = function()
                UIThingsDB.castBar.pos.point = point
                UIDropDownMenu_SetText(anchorDropdown, point)
                UpdateCastBar()
                -- Update edit boxes to reflect new position
                xEditBox:SetText(tostring(RoundCoord(UIThingsDB.castBar.pos.x or 0)))
                yEditBox:SetText(tostring(RoundCoord(UIThingsDB.castBar.pos.y or 0)))
            end
            info.checked = (UIThingsDB.castBar.pos.point == point)
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(anchorDropdown, UIThingsDB.castBar.pos.point or "CENTER")

    -- == Colors ==
    Helpers.CreateSectionHeader(child, "Colors", -295)

    -- Use Class Color
    local classColorBtn = CreateFrame("CheckButton", "UIThingsCastBarClassColor", child,
        "ChatConfigCheckButtonTemplate")
    classColorBtn:SetPoint("TOPLEFT", 20, -325)
    _G[classColorBtn:GetName() .. "Text"]:SetText("Use Class Color")
    classColorBtn:SetChecked(UIThingsDB.castBar.useClassColor)
    classColorBtn:SetScript("OnClick", function(self)
        UIThingsDB.castBar.useClassColor = not not self:GetChecked()
        UpdateCastBar()
    end)

    Helpers.CreateColorSwatch(child, "Bar Color", UIThingsDB.castBar.barColor, UpdateCastBar, 20, -355)
    Helpers.CreateColorSwatch(child, "Background", UIThingsDB.castBar.bgColor, UpdateCastBar, 250, -355, true)
    Helpers.CreateColorSwatch(child, "Border Color", UIThingsDB.castBar.borderColor, UpdateCastBar, 20, -385)
    Helpers.CreateColorSwatch(child, "Channel Color", UIThingsDB.castBar.channelColor, UpdateCastBar, 250, -385)
    Helpers.CreateColorSwatch(child, "Non-Interruptible", UIThingsDB.castBar.nonInterruptibleColor, UpdateCastBar, 20,
        -415)
    Helpers.CreateColorSwatch(child, "Failed/Interrupted", UIThingsDB.castBar.failedColor, UpdateCastBar, 250, -415)

    -- == Text & Icon ==
    Helpers.CreateSectionHeader(child, "Text & Icon", -450)

    -- Font Dropdown
    Helpers.CreateFontDropdown(
        child,
        "UIThingsCastBarFontDropdown",
        "Font:",
        UIThingsDB.castBar.font,
        function(fontPath, fontName)
            UIThingsDB.castBar.font = fontPath
            UpdateCastBar()
        end,
        20,
        -480
    )

    -- Font Size Slider
    local fontSizeSlider = CreateFrame("Slider", "UIThingsCastBarFontSize", child, "OptionsSliderTemplate")
    fontSizeSlider:SetPoint("TOPLEFT", 260, -480)
    fontSizeSlider:SetMinMaxValues(8, 24)
    fontSizeSlider:SetValueStep(1)
    fontSizeSlider:SetObeyStepOnDrag(true)
    fontSizeSlider:SetWidth(150)
    _G[fontSizeSlider:GetName() .. "Text"]:SetText("Font Size: " .. UIThingsDB.castBar.fontSize)
    _G[fontSizeSlider:GetName() .. "Low"]:SetText("8")
    _G[fontSizeSlider:GetName() .. "High"]:SetText("24")
    fontSizeSlider:SetValue(UIThingsDB.castBar.fontSize)
    fontSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.castBar.fontSize = value
        _G[self:GetName() .. "Text"]:SetText("Font Size: " .. value)
        UpdateCastBar()
    end)

    -- Show Icon
    local iconBtn = CreateFrame("CheckButton", "UIThingsCastBarIcon", child, "ChatConfigCheckButtonTemplate")
    iconBtn:SetPoint("TOPLEFT", 20, -530)
    _G[iconBtn:GetName() .. "Text"]:SetText("Show Spell Icon")
    iconBtn:SetChecked(UIThingsDB.castBar.showIcon)
    iconBtn:SetScript("OnClick", function(self)
        UIThingsDB.castBar.showIcon = not not self:GetChecked()
        UpdateCastBar()
    end)

    -- Show Spell Name
    local nameBtn = CreateFrame("CheckButton", "UIThingsCastBarName", child, "ChatConfigCheckButtonTemplate")
    nameBtn:SetPoint("TOPLEFT", 180, -530)
    _G[nameBtn:GetName() .. "Text"]:SetText("Show Spell Name")
    nameBtn:SetChecked(UIThingsDB.castBar.showSpellName)
    nameBtn:SetScript("OnClick", function(self)
        UIThingsDB.castBar.showSpellName = not not self:GetChecked()
        UpdateCastBar()
    end)

    -- Show Cast Time
    local timeBtn = CreateFrame("CheckButton", "UIThingsCastBarTime", child, "ChatConfigCheckButtonTemplate")
    timeBtn:SetPoint("TOPLEFT", 370, -530)
    _G[timeBtn:GetName() .. "Text"]:SetText("Show Cast Time")
    timeBtn:SetChecked(UIThingsDB.castBar.showCastTime)
    timeBtn:SetScript("OnClick", function(self)
        UIThingsDB.castBar.showCastTime = not not self:GetChecked()
        UpdateCastBar()
    end)

    -- Show Spark
    local sparkBtn = CreateFrame("CheckButton", "UIThingsCastBarSpark", child, "ChatConfigCheckButtonTemplate")
    sparkBtn:SetPoint("TOPLEFT", 20, -555)
    _G[sparkBtn:GetName() .. "Text"]:SetText("Show Spark")
    sparkBtn:SetChecked(UIThingsDB.castBar.showSpark)
    sparkBtn:SetScript("OnClick", function(self)
        UIThingsDB.castBar.showSpark = not not self:GetChecked()
        UpdateCastBar()
    end)

    -- == Target Cast Bar ==
    Helpers.CreateSectionHeader(child, "Target Cast Bar", -590)

    local targetEnableBtn = CreateFrame("CheckButton", "UIThingsTargetCastBarEnable", child, "ChatConfigCheckButtonTemplate")
    targetEnableBtn:SetPoint("TOPLEFT", 20, -620)
    _G[targetEnableBtn:GetName() .. "Text"]:SetText("Enable Target Cast Bar")
    targetEnableBtn:SetChecked(UIThingsDB.castBar.targetBar.enabled)
    targetEnableBtn:SetScript("OnClick", function(self)
        UIThingsDB.castBar.targetBar.enabled = not not self:GetChecked()
        UpdateCastBar()
    end)

    local targetLockBtn = CreateFrame("CheckButton", "UIThingsTargetCastBarLock", child, "ChatConfigCheckButtonTemplate")
    targetLockBtn:SetPoint("TOPLEFT", 260, -620)
    _G[targetLockBtn:GetName() .. "Text"]:SetText("Lock Target Cast Bar")
    targetLockBtn:SetChecked(UIThingsDB.castBar.targetBar.locked)
    targetLockBtn:SetScript("OnClick", function(self)
        UIThingsDB.castBar.targetBar.locked = not not self:GetChecked()
        UpdateCastBar()
    end)

    -- Target X Position
    local txLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txLabel:SetPoint("TOPLEFT", 20, -655)
    txLabel:SetText("X Position:")

    local txEditBox = CreateFrame("EditBox", "UIThingsTargetCastBarPosX", child, "InputBoxTemplate")
    txEditBox:SetSize(60, 20)
    txEditBox:SetPoint("LEFT", txLabel, "RIGHT", 8, 0)
    txEditBox:SetAutoFocus(false)
    txEditBox:SetNumeric(false)
    txEditBox:SetText(tostring(RoundCoord(UIThingsDB.castBar.targetBar.pos.x or 0)))
    txEditBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            UIThingsDB.castBar.targetBar.pos.x = RoundCoord(val)
            self:SetText(tostring(UIThingsDB.castBar.targetBar.pos.x))
            UpdateCastBar()
        end
        self:ClearFocus()
    end)
    txEditBox:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(RoundCoord(UIThingsDB.castBar.targetBar.pos.x or 0)))
        self:ClearFocus()
    end)

    -- Target Y Position
    local tyLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tyLabel:SetPoint("TOPLEFT", 200, -655)
    tyLabel:SetText("Y Position:")

    local tyEditBox = CreateFrame("EditBox", "UIThingsTargetCastBarPosY", child, "InputBoxTemplate")
    tyEditBox:SetSize(60, 20)
    tyEditBox:SetPoint("LEFT", tyLabel, "RIGHT", 8, 0)
    tyEditBox:SetAutoFocus(false)
    tyEditBox:SetNumeric(false)
    tyEditBox:SetText(tostring(RoundCoord(UIThingsDB.castBar.targetBar.pos.y or 0)))
    tyEditBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            UIThingsDB.castBar.targetBar.pos.y = RoundCoord(val)
            self:SetText(tostring(UIThingsDB.castBar.targetBar.pos.y))
            UpdateCastBar()
        end
        self:ClearFocus()
    end)
    tyEditBox:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(RoundCoord(UIThingsDB.castBar.targetBar.pos.y or 0)))
        self:ClearFocus()
    end)

    -- Target bar color
    Helpers.CreateColorSwatch(child, "Target Bar Color", UIThingsDB.castBar.targetBar.barColor, UpdateCastBar, 20, -685)

    Helpers.CreateSectionHeader(child, "Focus Cast Bar", -750)
    local function FocusCheck(label, suffix, key, x)
        local f = CreateFrame("CheckButton", "UIThingsFocusCastBar"..suffix, child, "ChatConfigCheckButtonTemplate")
        f:SetPoint("TOPLEFT", x, -785)
        _G[f:GetName().."Text"]:SetText(label)
        f:SetChecked(UIThingsDB.castBar.focusBar[key])
        f:SetScript("OnClick", function(self)
            UIThingsDB.castBar.focusBar[key] = not not self:GetChecked(); UpdateCastBar()
        end)
    end
    FocusCheck("Enable Focus Cast Bar", "Enable", "enabled", 20)
    FocusCheck("Lock Focus Cast Bar", "Lock", "locked", 260)
    local function FocusNumber(label, suffix, key, isPosition, x, y, min, max)
        local text = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("TOPLEFT", x, y); text:SetText(label)
        local box = CreateFrame("EditBox", "UIThingsFocusCastBar"..suffix, child, "InputBoxTemplate")
        box:SetSize(70, 24); box:SetPoint("LEFT", text, "RIGHT", 10, 0); box:SetAutoFocus(false)
        local function ValueTable() return isPosition and UIThingsDB.castBar.focusBar.pos or UIThingsDB.castBar.focusBar end
        box:SetText(tostring(RoundCoord(ValueTable()[key])))
        box:SetScript("OnEnterPressed", function(self)
            local value = tonumber(self:GetText())
            if value and value == value and value >= min and value <= max then
                ValueTable()[key] = RoundCoord(value); UpdateCastBar()
            end
            self:SetText(tostring(RoundCoord(ValueTable()[key]))); self:ClearFocus()
        end)
        box:SetScript("OnEscapePressed", function(self)
            self:SetText(tostring(RoundCoord(ValueTable()[key]))); self:ClearFocus()
        end)
    end
    FocusNumber("X Position:", "PosX", "x", true, 20, -832, -10000, 10000)
    FocusNumber("Y Position:", "PosY", "y", true, 260, -832, -10000, 10000)
    FocusNumber("Width:", "Width", "width", false, 20, -880, 80, 1000)
    FocusNumber("Height:", "Height", "height", false, 260, -880, 8, 100)
    Helpers.CreateColorSwatch(child, "Kickable colour", UIThingsDB.castBar.focusBar.barColor, UpdateCastBar, 20, -928)
    local help = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", 20, -975); help:SetWidth(480); help:SetJustifyH("LEFT")
    help:SetText("Independent of the player/target bars. Uses the shared font, texture, icon and non-interruptible colour. Unlock here or use Layout Mode to position it. Interruptibility does not check your interrupt cooldown or range.")
end
