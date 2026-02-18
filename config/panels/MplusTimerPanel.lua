local addonName, addonTable = ...

addonTable.ConfigSetup = addonTable.ConfigSetup or {}

local Helpers = addonTable.ConfigHelpers

function addonTable.ConfigSetup.MplusTimer(panel, tab, configWindow)
    -- Create ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "UIThingsMplusTimerScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 0)

    local child = CreateFrame("Frame", nil, scrollFrame)
    child:SetSize(620, 800)
    scrollFrame:SetScrollChild(child)

    scrollFrame:SetScript("OnShow", function()
        child:SetWidth(scrollFrame:GetWidth())
    end)

    -- Panel Title
    local title = child:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("M+ Timer")

    -- Enable Checkbox
    local enableBtn = CreateFrame("CheckButton", "UIThingsMplusTimerEnableCheck", child,
        "ChatConfigCheckButtonTemplate")
    enableBtn:SetPoint("TOPLEFT", 20, -50)
    _G[enableBtn:GetName() .. "Text"]:SetText("Enable M+ Timer")
    enableBtn:SetChecked(UIThingsDB.mplusTimer.enabled)
    enableBtn:SetScript("OnClick", function(self)
        local enabled = not not self:GetChecked()
        UIThingsDB.mplusTimer.enabled = enabled
        Helpers.UpdateModuleVisuals(panel, tab, enabled)
        if enabled and addonTable.MplusTimer and addonTable.MplusTimer.EnsureInit then
            addonTable.MplusTimer.EnsureInit()
        end
        if addonTable.MplusTimer and addonTable.MplusTimer.UpdateSettings then
            addonTable.MplusTimer.UpdateSettings()
        end
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.mplusTimer.enabled)

    -- ============================================================
    -- Appearance Section
    -- ============================================================
    Helpers.CreateSectionHeader(child, "Appearance", -90)

    -- Row 1: Font Dropdown (left) | Timer Font Size Slider (right)
    Helpers.CreateFontDropdown(child, "UIThingsMplusTimerFontDropdown", "Font",
        UIThingsDB.mplusTimer.font,
        function(fontPath)
            UIThingsDB.mplusTimer.font = fontPath
            if addonTable.MplusTimer and addonTable.MplusTimer.UpdateSettings then
                addonTable.MplusTimer.UpdateSettings()
            end
        end,
        20, -115)

    local timerFontLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    timerFontLabel:SetPoint("TOPLEFT", 300, -115)
    timerFontLabel:SetText("Timer Font Size")

    local timerFontSlider = CreateFrame("Slider", "UIThingsMplusTimerFontSizeSlider", child,
        "OptionsSliderTemplate")
    timerFontSlider:SetPoint("TOPLEFT", timerFontLabel, "BOTTOMLEFT", 0, -10)
    timerFontSlider:SetMinMaxValues(12, 32)
    timerFontSlider:SetValueStep(1)
    timerFontSlider:SetObeyStepOnDrag(true)
    timerFontSlider:SetWidth(180)
    timerFontSlider:SetValue(UIThingsDB.mplusTimer.timerFontSize or 20)
    _G[timerFontSlider:GetName() .. "Low"]:SetText("12")
    _G[timerFontSlider:GetName() .. "High"]:SetText("32")
    _G[timerFontSlider:GetName() .. "Text"]:SetText(UIThingsDB.mplusTimer.timerFontSize or 20)
    timerFontSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        UIThingsDB.mplusTimer.timerFontSize = value
        _G[self:GetName() .. "Text"]:SetText(value)
        if addonTable.MplusTimer and addonTable.MplusTimer.UpdateSettings then
            addonTable.MplusTimer.UpdateSettings()
        end
    end)

    -- Row 2: General Font Size (left) | Bar Height (right)
    local fontSizeLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fontSizeLabel:SetPoint("TOPLEFT", 20, -185)
    fontSizeLabel:SetText("General Font Size")

    local fontSizeSlider = CreateFrame("Slider", "UIThingsMplusTimerGenFontSlider", child,
        "OptionsSliderTemplate")
    fontSizeSlider:SetPoint("TOPLEFT", fontSizeLabel, "BOTTOMLEFT", 0, -10)
    fontSizeSlider:SetMinMaxValues(8, 18)
    fontSizeSlider:SetValueStep(1)
    fontSizeSlider:SetObeyStepOnDrag(true)
    fontSizeSlider:SetWidth(180)
    fontSizeSlider:SetValue(UIThingsDB.mplusTimer.fontSize or 12)
    _G[fontSizeSlider:GetName() .. "Low"]:SetText("8")
    _G[fontSizeSlider:GetName() .. "High"]:SetText("18")
    _G[fontSizeSlider:GetName() .. "Text"]:SetText(UIThingsDB.mplusTimer.fontSize or 12)
    fontSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        UIThingsDB.mplusTimer.fontSize = value
        _G[self:GetName() .. "Text"]:SetText(value)
        if addonTable.MplusTimer and addonTable.MplusTimer.UpdateSettings then
            addonTable.MplusTimer.UpdateSettings()
        end
    end)

    local barHeightLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    barHeightLabel:SetPoint("TOPLEFT", 300, -185)
    barHeightLabel:SetText("Bar Height")

    local barHeightSlider = CreateFrame("Slider", "UIThingsMplusTimerBarHeightSlider", child,
        "OptionsSliderTemplate")
    barHeightSlider:SetPoint("TOPLEFT", barHeightLabel, "BOTTOMLEFT", 0, -10)
    barHeightSlider:SetMinMaxValues(4, 20)
    barHeightSlider:SetValueStep(1)
    barHeightSlider:SetObeyStepOnDrag(true)
    barHeightSlider:SetWidth(180)
    barHeightSlider:SetValue(UIThingsDB.mplusTimer.barHeight or 8)
    _G[barHeightSlider:GetName() .. "Low"]:SetText("4")
    _G[barHeightSlider:GetName() .. "High"]:SetText("20")
    _G[barHeightSlider:GetName() .. "Text"]:SetText(UIThingsDB.mplusTimer.barHeight or 8)
    barHeightSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        UIThingsDB.mplusTimer.barHeight = value
        _G[self:GetName() .. "Text"]:SetText(value)
        if addonTable.MplusTimer and addonTable.MplusTimer.UpdateSettings then
            addonTable.MplusTimer.UpdateSettings()
        end
    end)

    -- Row 3: Bar Width (left) | Colors (right)
    local barWidthLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    barWidthLabel:SetPoint("TOPLEFT", 20, -245)
    barWidthLabel:SetText("Bar Width")

    local barWidthSlider = CreateFrame("Slider", "UIThingsMplusTimerBarWidthSlider", child,
        "OptionsSliderTemplate")
    barWidthSlider:SetPoint("TOPLEFT", barWidthLabel, "BOTTOMLEFT", 0, -10)
    barWidthSlider:SetMinMaxValues(150, 400)
    barWidthSlider:SetValueStep(10)
    barWidthSlider:SetObeyStepOnDrag(true)
    barWidthSlider:SetWidth(180)
    barWidthSlider:SetValue(UIThingsDB.mplusTimer.barWidth or 250)
    _G[barWidthSlider:GetName() .. "Low"]:SetText("150")
    _G[barWidthSlider:GetName() .. "High"]:SetText("400")
    _G[barWidthSlider:GetName() .. "Text"]:SetText(UIThingsDB.mplusTimer.barWidth or 250)
    barWidthSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / 10 + 0.5) * 10
        UIThingsDB.mplusTimer.barWidth = value
        _G[self:GetName() .. "Text"]:SetText(value)
        if addonTable.MplusTimer and addonTable.MplusTimer.UpdateSettings then
            addonTable.MplusTimer.UpdateSettings()
        end
    end)

    Helpers.CreateColorSwatch(child, "Background Color", UIThingsDB.mplusTimer.bgColor, function()
        if addonTable.MplusTimer and addonTable.MplusTimer.UpdateSettings then
            addonTable.MplusTimer.UpdateSettings()
        end
    end, 300, -250, true)

    Helpers.CreateColorSwatch(child, "Border Color", UIThingsDB.mplusTimer.borderColor, function()
        if addonTable.MplusTimer and addonTable.MplusTimer.UpdateSettings then
            addonTable.MplusTimer.UpdateSettings()
        end
    end, 300, -280, true)

    -- ============================================================
    -- Colors Section
    -- ============================================================
    Helpers.CreateSectionHeader(child, "Colors", -315)

    local updateColors = function()
        if addonTable.MplusTimer and addonTable.MplusTimer.UpdateSettings then
            addonTable.MplusTimer.UpdateSettings()
        end
    end

    -- Swatch-first layout: swatch at fixed column x, label to the right
    local COL1, COL2, COL3 = 20, 190, 360
    local function SwatchRow(labelText, colorTable, col, y)
        local swatch, label = Helpers.CreateColorSwatch(child, "", colorTable, updateColors, col, y)
        -- Re-anchor: put swatch at the column origin, label after it
        label:ClearAllPoints()
        swatch:ClearAllPoints()
        swatch:SetPoint("TOPLEFT", child, "TOPLEFT", col, y)
        label:SetPoint("LEFT", swatch, "RIGHT", 5, 0)
        label:SetText(labelText)
        return swatch, label
    end

    -- Row 1: Timer text colors
    SwatchRow("Timer", UIThingsDB.mplusTimer.timerColor, COL1, -345)
    SwatchRow("Warning", UIThingsDB.mplusTimer.timerWarningColor, COL2, -345)
    SwatchRow("Depleted", UIThingsDB.mplusTimer.timerDepletedColor, COL3, -345)

    -- Row 2: More text colors
    SwatchRow("Success", UIThingsDB.mplusTimer.timerSuccessColor, COL1, -375)
    SwatchRow("Deaths", UIThingsDB.mplusTimer.deathColor, COL2, -375)
    SwatchRow("Affixes", UIThingsDB.mplusTimer.affixColor, COL3, -375)

    -- Row 3: Bar colors
    SwatchRow("+3 Bar", UIThingsDB.mplusTimer.barPlusThreeColor, COL1, -405)
    SwatchRow("+2 Bar", UIThingsDB.mplusTimer.barPlusTwoColor, COL2, -405)
    SwatchRow("+1 Bar", UIThingsDB.mplusTimer.barPlusOneColor, COL3, -405)

    -- Row 4: Forces colors
    SwatchRow("Forces Bar", UIThingsDB.mplusTimer.forcesBarColor, COL1, -435)
    SwatchRow("Forces Text", UIThingsDB.mplusTimer.forcesTextColor, COL2, -435)
    SwatchRow("Forces Done", UIThingsDB.mplusTimer.forcesCompleteColor, COL3, -435)

    -- Row 5: Boss & key colors
    SwatchRow("Boss Done", UIThingsDB.mplusTimer.bossCompleteColor, COL1, -465)
    SwatchRow("Boss Pending", UIThingsDB.mplusTimer.bossIncompleteColor, COL2, -465)
    SwatchRow("Key Level", UIThingsDB.mplusTimer.keyColor, COL3, -465)

    -- ============================================================
    -- Display Section
    -- ============================================================
    Helpers.CreateSectionHeader(child, "Display", -500)

    local showDeathsBtn = CreateFrame("CheckButton", "UIThingsMplusTimerShowDeaths", child,
        "ChatConfigCheckButtonTemplate")
    showDeathsBtn:SetPoint("TOPLEFT", 20, -530)
    _G[showDeathsBtn:GetName() .. "Text"]:SetText("Show Deaths")
    showDeathsBtn:SetChecked(UIThingsDB.mplusTimer.showDeaths)
    showDeathsBtn:SetScript("OnClick", function(self)
        UIThingsDB.mplusTimer.showDeaths = not not self:GetChecked()
        if addonTable.MplusTimer and addonTable.MplusTimer.UpdateSettings then
            addonTable.MplusTimer.UpdateSettings()
        end
    end)

    local showAffixesBtn = CreateFrame("CheckButton", "UIThingsMplusTimerShowAffixes", child,
        "ChatConfigCheckButtonTemplate")
    showAffixesBtn:SetPoint("TOPLEFT", 20, -555)
    _G[showAffixesBtn:GetName() .. "Text"]:SetText("Show Affixes")
    showAffixesBtn:SetChecked(UIThingsDB.mplusTimer.showAffixes)
    showAffixesBtn:SetScript("OnClick", function(self)
        UIThingsDB.mplusTimer.showAffixes = not not self:GetChecked()
        if addonTable.MplusTimer and addonTable.MplusTimer.UpdateSettings then
            addonTable.MplusTimer.UpdateSettings()
        end
    end)

    local showForcesBtn = CreateFrame("CheckButton", "UIThingsMplusTimerShowForces", child,
        "ChatConfigCheckButtonTemplate")
    showForcesBtn:SetPoint("TOPLEFT", 20, -580)
    _G[showForcesBtn:GetName() .. "Text"]:SetText("Show Forces")
    showForcesBtn:SetChecked(UIThingsDB.mplusTimer.showForces)
    showForcesBtn:SetScript("OnClick", function(self)
        UIThingsDB.mplusTimer.showForces = not not self:GetChecked()
        if addonTable.MplusTimer and addonTable.MplusTimer.UpdateSettings then
            addonTable.MplusTimer.UpdateSettings()
        end
    end)

    local showBossesBtn = CreateFrame("CheckButton", "UIThingsMplusTimerShowBosses", child,
        "ChatConfigCheckButtonTemplate")
    showBossesBtn:SetPoint("TOPLEFT", 20, -605)
    _G[showBossesBtn:GetName() .. "Text"]:SetText("Show Boss Objectives")
    showBossesBtn:SetChecked(UIThingsDB.mplusTimer.showBosses)
    showBossesBtn:SetScript("OnClick", function(self)
        UIThingsDB.mplusTimer.showBosses = not not self:GetChecked()
        if addonTable.MplusTimer and addonTable.MplusTimer.UpdateSettings then
            addonTable.MplusTimer.UpdateSettings()
        end
    end)

    -- ============================================================
    -- Automation Section
    -- ============================================================
    Helpers.CreateSectionHeader(child, "Automation", -640)

    local autoSlotBtn = CreateFrame("CheckButton", "UIThingsMplusTimerAutoSlot", child,
        "ChatConfigCheckButtonTemplate")
    autoSlotBtn:SetPoint("TOPLEFT", 20, -670)
    _G[autoSlotBtn:GetName() .. "Text"]:SetText("Auto-Slot Keystone")
    autoSlotBtn:SetChecked(UIThingsDB.mplusTimer.autoSlotKeystone)
    autoSlotBtn:SetScript("OnClick", function(self)
        UIThingsDB.mplusTimer.autoSlotKeystone = not not self:GetChecked()
    end)

    local autoSlotHelp = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    autoSlotHelp:SetPoint("TOPLEFT", 60, -695)
    autoSlotHelp:SetWidth(500)
    autoSlotHelp:SetJustifyH("LEFT")
    autoSlotHelp:SetText("Automatically places your keystone into the Font of Power when you interact with it.")
    autoSlotHelp:SetTextColor(0.7, 0.7, 0.7)

    -- ============================================================
    -- Position Section
    -- ============================================================
    Helpers.CreateSectionHeader(child, "Position", -720)

    local lockBtn = CreateFrame("CheckButton", "UIThingsMplusTimerLockCheck", child,
        "ChatConfigCheckButtonTemplate")
    lockBtn:SetPoint("TOPLEFT", 20, -750)
    _G[lockBtn:GetName() .. "Text"]:SetText("Lock Position")
    lockBtn:SetChecked(UIThingsDB.mplusTimer.locked)
    lockBtn:SetScript("OnClick", function(self)
        UIThingsDB.mplusTimer.locked = not not self:GetChecked()
        if addonTable.MplusTimer and addonTable.MplusTimer.UpdateSettings then
            addonTable.MplusTimer.UpdateSettings()
        end
    end)

    -- Test / Demo Button
    local testBtn = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    testBtn:SetSize(120, 26)
    testBtn:SetPoint("TOPLEFT", 160, -750)
    testBtn:SetText("Toggle Demo")
    testBtn:SetScript("OnClick", function()
        if addonTable.MplusTimer and addonTable.MplusTimer.ToggleDemo then
            addonTable.MplusTimer.ToggleDemo()
        end
    end)

    local testHelp = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    testHelp:SetPoint("LEFT", testBtn, "RIGHT", 10, 0)
    testHelp:SetText("Show a demo timer with mock data for positioning")
    testHelp:SetTextColor(0.7, 0.7, 0.7)
end
