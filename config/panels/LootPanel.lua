local addonName, addonTable = ...

-- Create setup table if it doesn't exist
addonTable.ConfigSetup = addonTable.ConfigSetup or {}

-- Get helpers
local Helpers = addonTable.ConfigHelpers

local function LootUpdateSettings()
    if addonTable.Loot and addonTable.Loot.UpdateSettings then
        LootUpdateSettings()
    end
end

-- Define the setup function for Loot panel
function addonTable.ConfigSetup.Loot(panel, tab, configWindow)
    Helpers.CreateResetButton(panel, "loot")
    local fonts = Helpers.fonts

    -- Create ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "UIThingsLootScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 0)

    local child = CreateFrame("Frame", nil, scrollFrame)
    child:SetSize(650, 720)
    scrollFrame:SetScrollChild(child)

    scrollFrame:SetScript("OnShow", function()
        child:SetWidth(scrollFrame:GetWidth())
    end)

    local title = child:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Loot Toasts")

    -- Enable Checkbox
    local enableCheckbox = CreateFrame("CheckButton", "UIThingsLootEnable", child,
        "ChatConfigCheckButtonTemplate")
    enableCheckbox:SetPoint("TOPLEFT", 20, -50)
    _G[enableCheckbox:GetName() .. "Text"]:SetText("Enable Loot Toasts")
    enableCheckbox:SetChecked(UIThingsDB.loot.enabled)
    enableCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.loot.enabled = self:GetChecked()
        Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.loot.enabled)
        LootUpdateSettings()
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.loot.enabled)

    -- Show All Checkbox
    local showAllBtn = CreateFrame("CheckButton", "UIThingsLootShowAll", child, "ChatConfigCheckButtonTemplate")
    showAllBtn:SetPoint("TOPLEFT", 20, -75)
    _G[showAllBtn:GetName() .. "Text"]:SetText("Show All Loot (Party/Raid)")
    showAllBtn:SetChecked(UIThingsDB.loot.showAll)
    showAllBtn:SetScript("OnClick", function(self)
        UIThingsDB.loot.showAll = self:GetChecked()
    end)

    -- Unlock Anchor Button
    local unlockBtn = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    unlockBtn:SetSize(120, 24)
    unlockBtn:SetPoint("TOPLEFT", 200, -50)
    unlockBtn:SetText("Unlock Anchor")
    unlockBtn:SetScript("OnShow", function(self)
        self:SetText("Unlock Anchor")
    end)
    unlockBtn:SetScript("OnClick", function(self)
        if addonTable.Loot and addonTable.Loot.ToggleAnchor then
            local isUnlocked = addonTable.Loot.ToggleAnchor()
            if isUnlocked then
                self:SetText("Lock Anchor")
            else
                self:SetText("Unlock Anchor")
            end
        end
    end)

    -- Duration Slider
    local durationSlider = CreateFrame("Slider", "UIThingsLootDuration", child, "OptionsSliderTemplate")
    durationSlider:SetPoint("TOPLEFT", 20, -125)
    durationSlider:SetMinMaxValues(1, 10)
    durationSlider:SetValueStep(0.5)
    durationSlider:SetObeyStepOnDrag(true)
    durationSlider:SetWidth(200)
    _G[durationSlider:GetName() .. 'Text']:SetText("Duration: " .. UIThingsDB.loot.duration .. "s")
    _G[durationSlider:GetName() .. 'Low']:SetText("1s")
    _G[durationSlider:GetName() .. 'High']:SetText("10s")
    durationSlider:SetValue(UIThingsDB.loot.duration)
    durationSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 10 + 0.5) / 10
        UIThingsDB.loot.duration = value
        _G[self:GetName() .. 'Text']:SetText("Duration: " .. value .. "s")
    end)

    -- Min Quality Dropdown
    local qualityLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    qualityLabel:SetPoint("TOPLEFT", 20, -175)
    qualityLabel:SetText("Minimum Quality:")

    local qualityDropdown = CreateFrame("Frame", "UIThingsLootQualityDropdown", child, "UIDropDownMenuTemplate")
    qualityDropdown:SetPoint("TOPLEFT", 140, -165)
    UIDropDownMenu_SetWidth(qualityDropdown, 120)

    local qualities = {
        { text = "|cff9d9d9dPoor|r",      value = 0 },
        { text = "|cffffffffCommon|r",    value = 1 },
        { text = "|cff1eff00Uncommon|r",  value = 2 },
        { text = "|cff0070ddRare|r",      value = 3 },
        { text = "|cffa335eeEpic|r",      value = 4 },
        { text = "|cffff8000Legendary|r", value = 5 },
    }

    local function QualityOnClick(self)
        UIDropDownMenu_SetSelectedValue(qualityDropdown, self.value)
        UIThingsDB.loot.minQuality = self.value
    end

    UIDropDownMenu_Initialize(qualityDropdown, function()
        for _, info in ipairs(qualities) do
            local inf = UIDropDownMenu_CreateInfo()
            inf.text = info.text
            inf.value = info.value
            inf.func = QualityOnClick
            inf.checked = (info.value == UIThingsDB.loot.minQuality)
            UIDropDownMenu_AddButton(inf)
        end
    end)
    UIDropDownMenu_SetSelectedValue(qualityDropdown, UIThingsDB.loot.minQuality)
    for _, q in ipairs(qualities) do
        if q.value == UIThingsDB.loot.minQuality then
            UIDropDownMenu_SetText(qualityDropdown, q.text)
            break
        end
    end

    -- Font Dropdown
    Helpers.CreateFontDropdown(
        child,
        "UIThingsLootFontDropdown",
        "Font:",
        UIThingsDB.loot.font,
        function(fontPath, fontName)
            UIThingsDB.loot.font = fontPath
            LootUpdateSettings()
        end,
        20,
        -225
    )

    -- Font Size Slider
    local fontSizeSlider = CreateFrame("Slider", "UIThingsLootFontSize", child, "OptionsSliderTemplate")
    fontSizeSlider:SetPoint("TOPLEFT", 250, -225)
    fontSizeSlider:SetMinMaxValues(8, 32)
    fontSizeSlider:SetValueStep(1)
    fontSizeSlider:SetObeyStepOnDrag(true)
    fontSizeSlider:SetWidth(150)
    _G[fontSizeSlider:GetName() .. 'Text']:SetText("Font Size: " .. UIThingsDB.loot.fontSize)
    _G[fontSizeSlider:GetName() .. 'Low']:SetText("8")
    _G[fontSizeSlider:GetName() .. 'High']:SetText("32")
    fontSizeSlider:SetValue(UIThingsDB.loot.fontSize)
    fontSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.loot.fontSize = value
        _G[self:GetName() .. 'Text']:SetText("Font Size: " .. value)
        LootUpdateSettings()
    end)

    -- Who Looted Font Size Slider
    local whoLootedFontSizeSlider = CreateFrame("Slider", "UIThingsLootWhoLootedFontSize", child,
        "OptionsSliderTemplate")
    whoLootedFontSizeSlider:SetPoint("TOPLEFT", 250, -265)
    whoLootedFontSizeSlider:SetMinMaxValues(8, 32)
    whoLootedFontSizeSlider:SetValueStep(1)
    whoLootedFontSizeSlider:SetObeyStepOnDrag(true)
    whoLootedFontSizeSlider:SetWidth(150)
    _G[whoLootedFontSizeSlider:GetName() .. 'Text']:SetText("Who Looted Size: " ..
        (UIThingsDB.loot.whoLootedFontSize or 12))
    _G[whoLootedFontSizeSlider:GetName() .. 'Low']:SetText("8")
    _G[whoLootedFontSizeSlider:GetName() .. 'High']:SetText("32")
    whoLootedFontSizeSlider:SetValue(UIThingsDB.loot.whoLootedFontSize or 12)
    whoLootedFontSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.loot.whoLootedFontSize = value
        _G[self:GetName() .. 'Text']:SetText("Who Looted Size: " .. value)
        LootUpdateSettings()
    end)

    -- Icon Size Slider
    local iconSizeSlider = CreateFrame("Slider", "UIThingsLootIconSize", child, "OptionsSliderTemplate")
    iconSizeSlider:SetPoint("TOPLEFT", 20, -305)
    iconSizeSlider:SetMinMaxValues(16, 64)
    iconSizeSlider:SetValueStep(2)
    iconSizeSlider:SetObeyStepOnDrag(true)
    iconSizeSlider:SetWidth(200)
    _G[iconSizeSlider:GetName() .. 'Text']:SetText("Icon Size: " .. UIThingsDB.loot.iconSize)
    _G[iconSizeSlider:GetName() .. 'Low']:SetText("16")
    _G[iconSizeSlider:GetName() .. 'High']:SetText("64")
    iconSizeSlider:SetValue(UIThingsDB.loot.iconSize)
    iconSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.loot.iconSize = value
        _G[self:GetName() .. 'Text']:SetText("Icon Size: " .. value)
        LootUpdateSettings()
    end)

    -- Grow Up Checkbox
    local growBtn = CreateFrame("CheckButton", "UIThingsLootGrowCheck", child, "ChatConfigCheckButtonTemplate")
    growBtn:SetPoint("TOPLEFT", 20, -355)
    _G[growBtn:GetName() .. "Text"]:SetText("Grow Upwards")
    growBtn:SetChecked(UIThingsDB.loot.growUp)
    growBtn:SetScript("OnClick", function(self)
        UIThingsDB.loot.growUp = self:GetChecked()
        LootUpdateSettings()
    end)

    -- Faster Loot Checkbox
    local fasterLootBtn = CreateFrame("CheckButton", "UIThingsLootFasterCheck", child,
        "ChatConfigCheckButtonTemplate")
    fasterLootBtn:SetPoint("TOPLEFT", 20, -405)
    _G[fasterLootBtn:GetName() .. "Text"]:SetText("Faster Loot")
    fasterLootBtn:SetChecked(UIThingsDB.loot.fasterLoot)
    fasterLootBtn:SetScript("OnClick", function(self)
        UIThingsDB.loot.fasterLoot = self:GetChecked()
    end)

    -- Faster Loot Delay Slider
    local delaySlider = CreateFrame("Slider", "UIThingsLootDelaySlider", child, "OptionsSliderTemplate")
    delaySlider:SetPoint("TOPLEFT", 20, -455)
    delaySlider:SetMinMaxValues(0, 1)
    delaySlider:SetValueStep(0.1)
    delaySlider:SetObeyStepOnDrag(true)
    delaySlider:SetWidth(200)

    local currentDelay = UIThingsDB.loot.fasterLootDelay
    _G[delaySlider:GetName() .. 'Text']:SetText("Loot Delay: " .. currentDelay .. "s")
    _G[delaySlider:GetName() .. 'Low']:SetText("0s")
    _G[delaySlider:GetName() .. 'High']:SetText("1s")
    delaySlider:SetValue(currentDelay)

    -- EditBox for Delay
    local delayEdit = CreateFrame("EditBox", nil, child, "InputBoxTemplate")
    delayEdit:SetSize(40, 20)
    delayEdit:SetPoint("LEFT", delaySlider, "RIGHT", 10, 0)
    delayEdit:SetAutoFocus(false)
    delayEdit:SetText(tostring(currentDelay))

    delaySlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 10 + 0.5) / 10
        UIThingsDB.loot.fasterLootDelay = value
        _G[self:GetName() .. 'Text']:SetText("Loot Delay: " .. value .. "s")
        if not delayEdit:HasFocus() then
            delayEdit:SetText(tostring(value))
        end
    end)

    delayEdit:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            val = math.max(0, math.min(1, val))
            val = math.floor(val * 10 + 0.5) / 10

            UIThingsDB.loot.fasterLootDelay = val
            delaySlider:SetValue(val)
            self:SetText(tostring(val))
            self:ClearFocus()
        else
            self:SetText(tostring(UIThingsDB.loot.fasterLootDelay))
            self:ClearFocus()
        end
    end)

    -- == Currency & Gold Notifications ==
    Helpers.CreateSectionHeader(child, "Currency & Gold Notifications", -510)

    -- Show Currency Checkbox
    local currencyBtn = CreateFrame("CheckButton", "UIThingsLootCurrencyCheck", child,
        "ChatConfigCheckButtonTemplate")
    currencyBtn:SetPoint("TOPLEFT", 20, -535)
    _G[currencyBtn:GetName() .. "Text"]:SetText("Show Currency Gain Toasts")
    currencyBtn:SetChecked(UIThingsDB.loot.showCurrency)
    currencyBtn:SetScript("OnClick", function(self)
        UIThingsDB.loot.showCurrency = self:GetChecked()
        LootUpdateSettings()
    end)

    local currencyHelp = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    currencyHelp:SetPoint("TOPLEFT", 45, -558)
    currencyHelp:SetTextColor(0.5, 0.5, 0.5)
    currencyHelp:SetText("Shows a toast when you gain currency (Valorstones, Crests, Conquest, etc.)")

    -- Show Gold Checkbox
    local goldBtn = CreateFrame("CheckButton", "UIThingsLootGoldCheck", child,
        "ChatConfigCheckButtonTemplate")
    goldBtn:SetPoint("TOPLEFT", 20, -580)
    _G[goldBtn:GetName() .. "Text"]:SetText("Show Gold Loot Toasts")
    goldBtn:SetChecked(UIThingsDB.loot.showGold)
    goldBtn:SetScript("OnClick", function(self)
        UIThingsDB.loot.showGold = self:GetChecked()
        LootUpdateSettings()
    end)

    -- Min Gold Slider
    local minGoldValue = (UIThingsDB.loot.minGoldAmount or 10000) / 10000 -- Convert copper to gold
    local minGoldSlider = CreateFrame("Slider", "UIThingsLootMinGoldSlider", child, "OptionsSliderTemplate")
    minGoldSlider:SetPoint("TOPLEFT", 20, -625)
    minGoldSlider:SetMinMaxValues(0, 100)
    minGoldSlider:SetValueStep(1)
    minGoldSlider:SetObeyStepOnDrag(true)
    minGoldSlider:SetWidth(200)
    _G[minGoldSlider:GetName() .. 'Text']:SetText("Min Gold: " .. minGoldValue .. "g")
    _G[minGoldSlider:GetName() .. 'Low']:SetText("0g")
    _G[minGoldSlider:GetName() .. 'High']:SetText("100g")
    minGoldSlider:SetValue(minGoldValue)

    -- EditBox for Min Gold
    local minGoldEdit = CreateFrame("EditBox", nil, child, "InputBoxTemplate")
    minGoldEdit:SetSize(40, 20)
    minGoldEdit:SetPoint("LEFT", minGoldSlider, "RIGHT", 10, 0)
    minGoldEdit:SetAutoFocus(false)
    minGoldEdit:SetText(tostring(minGoldValue))

    minGoldSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.loot.minGoldAmount = value * 10000
        _G[self:GetName() .. 'Text']:SetText("Min Gold: " .. value .. "g")
        if not minGoldEdit:HasFocus() then
            minGoldEdit:SetText(tostring(value))
        end
    end)

    minGoldEdit:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            val = math.max(0, math.min(100, math.floor(val)))
            UIThingsDB.loot.minGoldAmount = val * 10000
            minGoldSlider:SetValue(val)
            self:SetText(tostring(val))
            self:ClearFocus()
        else
            local current = (UIThingsDB.loot.minGoldAmount or 10000) / 10000
            self:SetText(tostring(current))
            self:ClearFocus()
        end
    end)

    local goldHelp = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    goldHelp:SetPoint("TOPLEFT", 45, -602)
    goldHelp:SetTextColor(0.5, 0.5, 0.5)
    goldHelp:SetText("Shows a toast when you loot gold above the minimum threshold")

    -- Show Item Level Checkbox
    local ilvlBtn = CreateFrame("CheckButton", "UIThingsLootIlvlCheck", child,
        "ChatConfigCheckButtonTemplate")
    ilvlBtn:SetPoint("TOPLEFT", 20, -660)
    _G[ilvlBtn:GetName() .. "Text"]:SetText("Show Item Level & Upgrade Indicator")
    ilvlBtn:SetChecked(UIThingsDB.loot.showItemLevel)
    ilvlBtn:SetScript("OnClick", function(self)
        UIThingsDB.loot.showItemLevel = self:GetChecked()
    end)

    local ilvlHelp = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ilvlHelp:SetPoint("TOPLEFT", 45, -683)
    ilvlHelp:SetTextColor(0.5, 0.5, 0.5)
    ilvlHelp:SetText("Shows item level on gear toasts with green +X for upgrades")
end
