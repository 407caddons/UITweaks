local addonName, addonTable = ...

-- Create setup table if it doesn't exist
addonTable.ConfigSetup = addonTable.ConfigSetup or {}

-- Get helpers
local Helpers = addonTable.ConfigHelpers

function addonTable.ConfigSetup.Widgets(panel, tab, configWindow)
    local function UpdateWidgets()
        if addonTable.Widgets and addonTable.Widgets.UpdateVisuals then
            addonTable.Widgets.UpdateVisuals()
        end
    end

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Widgets")

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(560, 500)
    scrollFrame:SetScrollChild(scrollChild)
    panel = scrollChild

    -- SECTION: General
    Helpers.CreateSectionHeader(panel, "General", -10)

    -- Enable Master Checkbox
    local enableBtn = CreateFrame("CheckButton", "UIThingsWidgetsEnableCheck", panel, "ChatConfigCheckButtonTemplate")
    enableBtn:SetPoint("TOPLEFT", 20, -40)
    _G[enableBtn:GetName() .. "Text"]:SetText("Enable Widgets Module")
    enableBtn:SetChecked(UIThingsDB.widgets.enabled)
    enableBtn:SetScript("OnClick", function(self)
        UIThingsDB.widgets.enabled = self:GetChecked()
        UpdateWidgets()
        Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.widgets.enabled)
    end)
    
    -- Lock Widgets Checkbox
    local lockBtn = CreateFrame("CheckButton", "UIThingsWidgetsLockCheck", panel, "ChatConfigCheckButtonTemplate")
    lockBtn:SetPoint("TOPLEFT", 250, -40)
    _G[lockBtn:GetName() .. "Text"]:SetText("Lock Widgets")
    lockBtn:SetChecked(UIThingsDB.widgets.locked)
    lockBtn:SetScript("OnClick", function(self)
        UIThingsDB.widgets.locked = self:GetChecked()
        UpdateWidgets()
    end)
    
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.widgets.enabled)

    -- SECTION: Appearance
    Helpers.CreateSectionHeader(panel, "Appearance", -80)

    -- Font Dropdown
    Helpers.CreateFontDropdown(
        panel,
        "UIThingsWidgetsFontDropdown",
        "Font:",
        UIThingsDB.widgets.font,
        function(fontPath, fontName)
            UIThingsDB.widgets.font = fontPath
            UpdateWidgets()
        end,
        20,
        -105
    )

    -- Font Size Slider (Placed to the right of Font dropdown)
    local sizeSlider = CreateFrame("Slider", "UIThingsWidgetsSizeSlider", panel, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", 250, -115)
    sizeSlider:SetMinMaxValues(8, 32)
    sizeSlider:SetValueStep(1)
    sizeSlider:SetObeyStepOnDrag(true)
    sizeSlider:SetWidth(150)
    _G[sizeSlider:GetName() .. 'Text']:SetText(string.format("Size: %d", UIThingsDB.widgets.fontSize))
    _G[sizeSlider:GetName() .. 'Low']:SetText("8")
    _G[sizeSlider:GetName() .. 'High']:SetText("32")
    sizeSlider:SetValue(UIThingsDB.widgets.fontSize)
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.widgets.fontSize = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Size: %d", value))
        UpdateWidgets()
    end)

    -- Strata Dropdown
    local strataLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    strataLabel:SetPoint("TOPLEFT", 20, -170)
    strataLabel:SetText("Strata:")

    local strataDropdown = CreateFrame("Frame", "UIThingsWidgetsStrataDropdown", panel, "UIDropDownMenuTemplate")
    strataDropdown:SetPoint("TOPLEFT", strataLabel, "BOTTOMLEFT", -15, -5)

    local function StrataOnClick(self)
        UIDropDownMenu_SetSelectedID(strataDropdown, self:GetID())
        UIThingsDB.widgets.strata = self.value
        UpdateWidgets()
    end

    local function StrataInit(self, level)
        local stratas = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "TOOLTIP" }
        for _, s in ipairs(stratas) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = s
            info.value = s
            info.func = StrataOnClick
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(strataDropdown, StrataInit)
    UIDropDownMenu_SetText(strataDropdown, UIThingsDB.widgets.strata or "LOW")

    -- Font Color Picker
    local colorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    colorLabel:SetPoint("TOPLEFT", 250, -173)
    colorLabel:SetText("Font Color:")

    local colorSwatch = CreateFrame("Button", nil, panel)
    colorSwatch:SetSize(20, 20)
    colorSwatch:SetPoint("LEFT", colorLabel, "RIGHT", 5, 0)

    colorSwatch.tex = colorSwatch:CreateTexture(nil, "OVERLAY")
    colorSwatch.tex:SetAllPoints()
    local c = UIThingsDB.widgets.fontColor or { r = 1, g = 1, b = 1, a = 1 }
    colorSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)

    Mixin(colorSwatch, BackdropTemplateMixin)
    colorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    colorSwatch:SetBackdropBorderColor(1, 1, 1)

    colorSwatch:SetScript("OnClick", function(self)
        local info = UIDropDownMenu_CreateInfo()
        local prevR, prevG, prevB, prevA = c.r, c.g, c.b, c.a

        info.r, info.g, info.b, info.opacity = prevR, prevG, prevB, prevA
        info.hasOpacity = true
        info.opacityFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            c.r, c.g, c.b, c.a = r, g, b, a
            colorSwatch.tex:SetColorTexture(r, g, b, a)
            UIThingsDB.widgets.fontColor = c
            UpdateWidgets()
        end
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            c.r, c.g, c.b, c.a = r, g, b, a
            colorSwatch.tex:SetColorTexture(r, g, b, a)
            UIThingsDB.widgets.fontColor = c
            UpdateWidgets()
        end
        info.cancelFunc = function(previousValues)
            c.r, c.g, c.b, c.a = prevR, prevG, prevB, prevA
            colorSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
            UIThingsDB.widgets.fontColor = c
            UpdateWidgets()
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)


    -- SECTION: Individual Widgets
    Helpers.CreateSectionHeader(panel, "Individual Widgets", -220)

    local widgets = {
        { key = "time", label = "Local/Server Time" },
        { key = "fps", label = "System Stats (MS/FPS)" },
        { key = "bags", label = "Bag Slots Info" },
        { key = "spec", label = "Specialization/Loot Spec" },
        { key = "durability", label = "Durability" },
        { key = "combat", label = "Combat State" },
        { key = "friends", label = "Friends Online" },
        { key = "guild", label = "Guild Members" },
        { key = "group", label = "Group Composition" },
        { key = "teleports", label = "Teleports" },
    }

    local yOffset = -250
    for i, widget in ipairs(widgets) do
        local cb = CreateFrame("CheckButton", "UIThingsWidget" .. widget.key .. "Check", panel, "ChatConfigCheckButtonTemplate")
        
        -- Two columns
        if i % 2 ~= 0 then
            cb:SetPoint("TOPLEFT", 20, yOffset)
        else
            cb:SetPoint("TOPLEFT", 300, yOffset)
            yOffset = yOffset - 30 -- Move down after 2nd column
        end

        _G[cb:GetName() .. "Text"]:SetText(widget.label)
        cb:SetChecked(UIThingsDB.widgets[widget.key].enabled)
        cb:SetScript("OnClick", function(self)
            UIThingsDB.widgets[widget.key].enabled = self:GetChecked()
            UpdateWidgets()
        end)
    end

    -- Show WoW Only Checkbox (Placed near Friends/Guild/Group)
    local wowOnlyBtn = CreateFrame("CheckButton", "UIThingsWidgetsWoWOnlyCheck", panel, "ChatConfigCheckButtonTemplate")
    wowOnlyBtn:SetPoint("TOPLEFT", 20, yOffset - 40)
    _G[wowOnlyBtn:GetName() .. "Text"]:SetText("Show WoW Friends Only")
    wowOnlyBtn:SetChecked(UIThingsDB.widgets.showWoWOnly)
    wowOnlyBtn:SetScript("OnClick", function(self)
        UIThingsDB.widgets.showWoWOnly = self:GetChecked()
        UpdateWidgets()
    end)

    -- Show Addon Memory Checkbox
    local addonMemBtn = CreateFrame("CheckButton", "UIThingsWidgetsAddonMemCheck", panel, "ChatConfigCheckButtonTemplate")
    addonMemBtn:SetPoint("TOPLEFT", 20, yOffset - 70)
    _G[addonMemBtn:GetName() .. "Text"]:SetText("Show Addon Memory Usage")
    addonMemBtn:SetChecked(UIThingsDB.widgets.showAddonMemory)
    addonMemBtn:SetScript("OnClick", function(self)
        UIThingsDB.widgets.showAddonMemory = self:GetChecked()
        UpdateWidgets()
    end)
end
