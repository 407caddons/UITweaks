local addonName, addonTable = ...

addonTable.ConfigSetup = addonTable.ConfigSetup or {}
local Helpers = addonTable.ConfigHelpers

function addonTable.ConfigSetup.QueueTimer(panel, tab, configWindow)
    Helpers.CreateResetButton(panel, "queueTimer")

    local scrollFrame = CreateFrame("ScrollFrame", "UIThingsQueueTimerScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 0)

    local child = CreateFrame("Frame", nil, scrollFrame)
    child:SetSize(600, 480)
    scrollFrame:SetScrollChild(child)

    scrollFrame:SetScript("OnShow", function()
        child:SetWidth(scrollFrame:GetWidth())
    end)

    local function UpdateQueueTimer()
        if addonTable.QueueTimer and addonTable.QueueTimer.UpdateSettings then
            addonTable.QueueTimer.UpdateSettings()
        end
    end

    -- Title
    local title = child:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Queue Timer")

    local desc = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    desc:SetPoint("TOPLEFT", 16, -44)
    desc:SetText("|cFFAAAAAAAAShows a countdown bar when a dungeon or LFR queue pops, attached below the acceptance dialog.|r")

    -------------------------------------------------------------
    -- SECTION: General
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(child, "General", -68)

    local enableBtn = CreateFrame("CheckButton", "UIThingsQueueTimerEnableCheck", child, "ChatConfigCheckButtonTemplate")
    enableBtn:SetPoint("TOPLEFT", 20, -98)
    _G[enableBtn:GetName() .. "Text"]:SetText("Enable Queue Timer")
    enableBtn:SetChecked(UIThingsDB.queueTimer.enabled)
    enableBtn:SetScript("OnClick", function(self)
        local enabled = not not self:GetChecked()
        UIThingsDB.queueTimer.enabled = enabled
        UpdateQueueTimer()
        Helpers.UpdateModuleVisuals(panel, tab, enabled)
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.queueTimer.enabled)

    local showTextBtn = CreateFrame("CheckButton", "UIThingsQueueTimerTextCheck", child, "ChatConfigCheckButtonTemplate")
    showTextBtn:SetPoint("TOPLEFT", 250, -98)
    _G[showTextBtn:GetName() .. "Text"]:SetText("Show countdown text")
    showTextBtn:SetChecked(UIThingsDB.queueTimer.showText)
    showTextBtn:SetScript("OnClick", function(self)
        UIThingsDB.queueTimer.showText = not not self:GetChecked()
        UpdateQueueTimer()
    end)

    local dynamicBtn = CreateFrame("CheckButton", "UIThingsQueueTimerDynamicCheck", child, "ChatConfigCheckButtonTemplate")
    dynamicBtn:SetPoint("TOPLEFT", 20, -118)
    _G[dynamicBtn:GetName() .. "Text"]:SetText("Dynamic color (green -> yellow -> red as time runs out)")
    dynamicBtn:SetChecked(UIThingsDB.queueTimer.dynamicColor)
    dynamicBtn:SetScript("OnClick", function(self)
        UIThingsDB.queueTimer.dynamicColor = not not self:GetChecked()
        UpdateQueueTimer()
    end)

    -------------------------------------------------------------
    -- SECTION: Size
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(child, "Size", -152)

    local widthLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    widthLabel:SetPoint("TOPLEFT", 20, -182)
    widthLabel:SetText("Width:")

    local widthSlider = CreateFrame("Slider", "UIThingsQueueTimerWidthSlider", child, "OptionsSliderTemplate")
    widthSlider:SetPoint("TOPLEFT", 80, -177)
    widthSlider:SetWidth(200)
    widthSlider:SetMinMaxValues(100, 600)
    widthSlider:SetValueStep(10)
    widthSlider:SetObeyStepOnDrag(true)
    _G[widthSlider:GetName() .. "Low"]:SetText("100")
    _G[widthSlider:GetName() .. "High"]:SetText("600")
    _G[widthSlider:GetName() .. "Text"]:SetText("Width: " .. UIThingsDB.queueTimer.width)
    widthSlider:SetValue(UIThingsDB.queueTimer.width)
    widthSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / 10) * 10
        UIThingsDB.queueTimer.width = value
        _G[self:GetName() .. "Text"]:SetText("Width: " .. value)
        UpdateQueueTimer()
    end)

    local heightLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    heightLabel:SetPoint("TOPLEFT", 20, -222)
    heightLabel:SetText("Height:")

    local heightSlider = CreateFrame("Slider", "UIThingsQueueTimerHeightSlider", child, "OptionsSliderTemplate")
    heightSlider:SetPoint("TOPLEFT", 80, -217)
    heightSlider:SetWidth(200)
    heightSlider:SetMinMaxValues(6, 40)
    heightSlider:SetValueStep(1)
    heightSlider:SetObeyStepOnDrag(true)
    _G[heightSlider:GetName() .. "Low"]:SetText("6")
    _G[heightSlider:GetName() .. "High"]:SetText("40")
    _G[heightSlider:GetName() .. "Text"]:SetText("Height: " .. UIThingsDB.queueTimer.height)
    heightSlider:SetValue(UIThingsDB.queueTimer.height)
    heightSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.queueTimer.height = value
        _G[self:GetName() .. "Text"]:SetText("Height: " .. value)
        UpdateQueueTimer()
    end)

    -------------------------------------------------------------
    -- SECTION: Colors
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(child, "Colors", -258)

    Helpers.CreateColorPicker(child, "UIThingsQueueTimerBarColorBtn", "Bar Color",
        function()
            local c = UIThingsDB.queueTimer.barColor
            return c.r, c.g, c.b
        end,
        function(r, g, b)
            UIThingsDB.queueTimer.barColor.r = r
            UIThingsDB.queueTimer.barColor.g = g
            UIThingsDB.queueTimer.barColor.b = b
            UpdateQueueTimer()
        end,
        -288
    )

    Helpers.CreateColorPicker(child, "UIThingsQueueTimerBgColorBtn", "Background Color",
        function()
            local c = UIThingsDB.queueTimer.bgColor
            return c.r, c.g, c.b
        end,
        function(r, g, b)
            UIThingsDB.queueTimer.bgColor.r = r
            UIThingsDB.queueTimer.bgColor.g = g
            UIThingsDB.queueTimer.bgColor.b = b
            UpdateQueueTimer()
        end,
        -318
    )
end
