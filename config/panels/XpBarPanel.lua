local addonName, addonTable = ...

addonTable.ConfigSetup = addonTable.ConfigSetup or {}
local Helpers = addonTable.ConfigHelpers

function addonTable.ConfigSetup.XpBar(panel, tab, configWindow)
    Helpers.CreateResetButton(panel, "xpBar")

    local scrollFrame = CreateFrame("ScrollFrame", "UIThingsXpBarScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 0)

    local child = CreateFrame("Frame", nil, scrollFrame)
    child:SetSize(600, 680)
    scrollFrame:SetScrollChild(child)

    scrollFrame:SetScript("OnShow", function()
        child:SetWidth(scrollFrame:GetWidth())
    end)

    local function UpdateXpBar()
        if addonTable.XpBar and addonTable.XpBar.UpdateSettings then
            addonTable.XpBar.UpdateSettings()
        end
    end

    -- Title
    local title = child:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("XP Bar")

    -------------------------------------------------------------
    -- SECTION: General
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(child, "General", -50)

    local enableBtn = CreateFrame("CheckButton", "UIThingsXpBarEnableCheck", child, "ChatConfigCheckButtonTemplate")
    enableBtn:SetPoint("TOPLEFT", 20, -80)
    _G[enableBtn:GetName() .. "Text"]:SetText("Enable XP Bar")
    enableBtn:SetChecked(UIThingsDB.xpBar.enabled)
    enableBtn:SetScript("OnClick", function(self)
        local enabled = not not self:GetChecked()
        UIThingsDB.xpBar.enabled = enabled
        UpdateXpBar()
        Helpers.UpdateModuleVisuals(panel, tab, enabled)
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.xpBar.enabled)

    local lockBtn = CreateFrame("CheckButton", "UIThingsXpBarLockCheck", child, "ChatConfigCheckButtonTemplate")
    lockBtn:SetPoint("TOPLEFT", 250, -80)
    _G[lockBtn:GetName() .. "Text"]:SetText("Lock Position")
    lockBtn:SetChecked(UIThingsDB.xpBar.locked)
    lockBtn:SetScript("OnClick", function(self)
        UIThingsDB.xpBar.locked = not not self:GetChecked()
        UpdateXpBar()
    end)

    local maxLevelBtn = CreateFrame("CheckButton", "UIThingsXpBarMaxLevelCheck", child, "ChatConfigCheckButtonTemplate")
    maxLevelBtn:SetPoint("TOPLEFT", 20, -105)
    _G[maxLevelBtn:GetName() .. "Text"]:SetText("Show at max level (hides bar fill, still shows level)")
    maxLevelBtn:SetChecked(UIThingsDB.xpBar.showAtMaxLevel)
    maxLevelBtn:SetScript("OnClick", function(self)
        UIThingsDB.xpBar.showAtMaxLevel = not not self:GetChecked()
        UpdateXpBar()
    end)

    local hideBlizzBtn = CreateFrame("CheckButton", "UIThingsXpBarHideBlizzCheck", child, "ChatConfigCheckButtonTemplate")
    hideBlizzBtn:SetPoint("TOPLEFT", 20, -125)
    _G[hideBlizzBtn:GetName() .. "Text"]:SetText("Hide Blizzard XP bar")
    hideBlizzBtn:SetChecked(UIThingsDB.xpBar.hideBlizzardBar)
    hideBlizzBtn:SetScript("OnClick", function(self)
        UIThingsDB.xpBar.hideBlizzardBar = not not self:GetChecked()
        UpdateXpBar()
    end)

    -------------------------------------------------------------
    -- SECTION: Size
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(child, "Size", -158)

    local widthLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    widthLabel:SetPoint("TOPLEFT", 20, -188)
    widthLabel:SetText("Width:")

    local widthSlider = CreateFrame("Slider", "UIThingsXpBarWidthSlider", child, "OptionsSliderTemplate")
    widthSlider:SetPoint("TOPLEFT", 80, -183)
    widthSlider:SetWidth(200)
    widthSlider:SetMinMaxValues(100, 1200)
    widthSlider:SetValueStep(10)
    widthSlider:SetObeyStepOnDrag(true)
    _G[widthSlider:GetName() .. "Low"]:SetText("100")
    _G[widthSlider:GetName() .. "High"]:SetText("1200")
    _G[widthSlider:GetName() .. "Text"]:SetText("Width: " .. UIThingsDB.xpBar.width)
    widthSlider:SetValue(UIThingsDB.xpBar.width)
    widthSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / 10) * 10
        UIThingsDB.xpBar.width = value
        _G[self:GetName() .. "Text"]:SetText("Width: " .. value)
        UpdateXpBar()
    end)

    local heightLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    heightLabel:SetPoint("TOPLEFT", 20, -228)
    heightLabel:SetText("Height:")

    local heightSlider = CreateFrame("Slider", "UIThingsXpBarHeightSlider", child, "OptionsSliderTemplate")
    heightSlider:SetPoint("TOPLEFT", 80, -223)
    heightSlider:SetWidth(200)
    heightSlider:SetMinMaxValues(4, 60)
    heightSlider:SetValueStep(1)
    heightSlider:SetObeyStepOnDrag(true)
    _G[heightSlider:GetName() .. "Low"]:SetText("4")
    _G[heightSlider:GetName() .. "High"]:SetText("60")
    _G[heightSlider:GetName() .. "Text"]:SetText("Height: " .. UIThingsDB.xpBar.height)
    heightSlider:SetValue(UIThingsDB.xpBar.height)
    heightSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.xpBar.height = value
        _G[self:GetName() .. "Text"]:SetText("Height: " .. value)
        UpdateXpBar()
    end)

    -------------------------------------------------------------
    -- SECTION: Text
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(child, "Text", -266)

    local showLevelBtn = CreateFrame("CheckButton", "UIThingsXpBarShowLevelCheck", child,
        "ChatConfigCheckButtonTemplate")
    showLevelBtn:SetPoint("TOPLEFT", 20, -296)
    _G[showLevelBtn:GetName() .. "Text"]:SetText("Show level (left)")
    showLevelBtn:SetChecked(UIThingsDB.xpBar.showLevel)
    showLevelBtn:SetScript("OnClick", function(self)
        UIThingsDB.xpBar.showLevel = not not self:GetChecked()
        UpdateXpBar()
    end)

    local showXPTextBtn = CreateFrame("CheckButton", "UIThingsXpBarShowXPTextCheck", child,
        "ChatConfigCheckButtonTemplate")
    showXPTextBtn:SetPoint("TOPLEFT", 20, -316)
    _G[showXPTextBtn:GetName() .. "Text"]:SetText("Show XP values (center)")
    showXPTextBtn:SetChecked(UIThingsDB.xpBar.showXPText)
    showXPTextBtn:SetScript("OnClick", function(self)
        UIThingsDB.xpBar.showXPText = not not self:GetChecked()
        UpdateXpBar()
    end)

    local showPctBtn = CreateFrame("CheckButton", "UIThingsXpBarShowPctCheck", child, "ChatConfigCheckButtonTemplate")
    showPctBtn:SetPoint("TOPLEFT", 20, -336)
    _G[showPctBtn:GetName() .. "Text"]:SetText("Show percentage (right)")
    showPctBtn:SetChecked(UIThingsDB.xpBar.showPercent)
    showPctBtn:SetScript("OnClick", function(self)
        UIThingsDB.xpBar.showPercent = not not self:GetChecked()
        UpdateXpBar()
    end)

    local showTimersBtn = CreateFrame("CheckButton", "UIThingsXpBarShowTimersCheck", child,
        "ChatConfigCheckButtonTemplate")
    showTimersBtn:SetPoint("TOPLEFT", 20, -356)
    _G[showTimersBtn:GetName() .. "Text"]:SetText("Show est. time-to-level in percent text")
    showTimersBtn:SetChecked(UIThingsDB.xpBar.showTimers)
    showTimersBtn:SetScript("OnClick", function(self)
        UIThingsDB.xpBar.showTimers = not not self:GetChecked()
        UpdateXpBar()
    end)

    Helpers.CreateFontDropdown(
        child, "UIThingsXpBarFontDropdown", "Font:",
        UIThingsDB.xpBar.font,
        function(fontPath)
            UIThingsDB.xpBar.font = fontPath
            UpdateXpBar()
        end,
        20, -393
    )

    local fontSizeSlider = CreateFrame("Slider", "UIThingsXpBarFontSizeSlider", child, "OptionsSliderTemplate")
    fontSizeSlider:SetPoint("TOPLEFT", 20, -463)
    fontSizeSlider:SetWidth(200)
    fontSizeSlider:SetMinMaxValues(6, 24)
    fontSizeSlider:SetValueStep(1)
    fontSizeSlider:SetObeyStepOnDrag(true)
    _G[fontSizeSlider:GetName() .. "Low"]:SetText("6")
    _G[fontSizeSlider:GetName() .. "High"]:SetText("24")
    _G[fontSizeSlider:GetName() .. "Text"]:SetText("Font Size: " .. UIThingsDB.xpBar.fontSize)
    fontSizeSlider:SetValue(UIThingsDB.xpBar.fontSize)
    fontSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.xpBar.fontSize = value
        _G[self:GetName() .. "Text"]:SetText("Font Size: " .. value)
        UpdateXpBar()
    end)

    -------------------------------------------------------------
    -- SECTION: Colors
    -------------------------------------------------------------
    Helpers.CreateSectionHeader(child, "Colors", -508)

    Helpers.CreateColorPicker(child, "UIThingsXpBarColorBtn", "XP Bar Color",
        function()
            local c = UIThingsDB.xpBar.barColor
            return c.r, c.g, c.b
        end,
        function(r, g, b)
            UIThingsDB.xpBar.barColor.r = r
            UIThingsDB.xpBar.barColor.g = g
            UIThingsDB.xpBar.barColor.b = b
            UpdateXpBar()
        end,
        -538
    )

    Helpers.CreateColorPicker(child, "UIThingsXpBarRestedColorBtn", "Rested XP Color",
        function()
            local c = UIThingsDB.xpBar.restedColor
            return c.r, c.g, c.b
        end,
        function(r, g, b)
            UIThingsDB.xpBar.restedColor.r = r
            UIThingsDB.xpBar.restedColor.g = g
            UIThingsDB.xpBar.restedColor.b = b
            UpdateXpBar()
        end,
        -568
    )

    Helpers.CreateColorPicker(child, "UIThingsXpBarBgColorBtn", "Background Color",
        function()
            local c = UIThingsDB.xpBar.bgColor
            return c.r, c.g, c.b
        end,
        function(r, g, b)
            UIThingsDB.xpBar.bgColor.r = r
            UIThingsDB.xpBar.bgColor.g = g
            UIThingsDB.xpBar.bgColor.b = b
            UpdateXpBar()
        end,
        -598
    )
end
