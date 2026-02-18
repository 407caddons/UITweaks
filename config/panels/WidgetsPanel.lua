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

    -- Anchor Helper
    local function GetAnchors()
        local anchors = { { text = "None", value = nil } }
        if UIThingsDB.frames and UIThingsDB.frames.list then
            for _, f in ipairs(UIThingsDB.frames.list) do
                if f.isAnchor then
                    table.insert(anchors, { text = f.name, value = f.name })
                end
            end
        end
        return anchors
    end

    local widgets = {
        { key = "time",          label = "Local/Server Time" },
        { key = "fps",           label = "System Stats (MS/FPS)" },
        { key = "bags",          label = "Bag Slots Info" },
        { key = "spec",          label = "Specialization/Loot Spec" },
        { key = "durability",    label = "Durability" },
        { key = "combat",        label = "Combat State" },
        { key = "friends",       label = "Friends Online" },
        { key = "guild",         label = "Guild Members" },
        { key = "group",         label = "Group Composition" },
        { key = "teleports",     label = "Teleports" },
        { key = "keystone",      label = "Mythic+ Keystone" },
        { key = "weeklyReset",   label = "Weekly Reset Timer" },
        { key = "coordinates",   label = "Player Coordinates" },
        { key = "battleRes",     label = "Battle Res Counter" },
        { key = "speed",         label = "Movement Speed" },
        { key = "itemLevel",     label = "Item Level" },
        { key = "volume",        label = "Volume Control" },
        { key = "zone",          label = "Zone / Subzone" },
        { key = "pvp",           label = "Honor / Conquest PvP" },
        { key = "mythicRating",  label = "Mythic+ Rating" },
        { key = "vault",         label = "Great Vault Progress" },
        { key = "darkmoonFaire", label = "Darkmoon Faire" },
        { key = "mail",          label = "Mail Indicator" },
        { key = "pullCounter",   label = "Pull Counter" },
        { key = "hearthstone",   label = "Hearthstone" },
        { key = "currency",      label = "Currency Tracker" },
    }

    local yOffset = -250
    for i, widget in ipairs(widgets) do
        local cb = CreateFrame("CheckButton", "UIThingsWidget" .. widget.key .. "Check", panel,
            "ChatConfigCheckButtonTemplate")

        -- Two columns logic adapted for having dropdowns
        -- If we add dropdowns, maybe single column is better?
        -- Or Keep two columns but make rows taller?
        -- User said "On the widget screen after each widget checkbox add an anchor frame"
        -- Let's do single column to avoid crowding.

        cb:SetPoint("TOPLEFT", 20, yOffset)

        _G[cb:GetName() .. "Text"]:SetText(widget.label)
        cb:SetChecked(UIThingsDB.widgets[widget.key].enabled)
        cb:SetScript("OnClick", function(self)
            UIThingsDB.widgets[widget.key].enabled = self:GetChecked()
            UpdateWidgets()
        end)

        -- Anchor Dropdown
        local anchorDropdown = CreateFrame("Frame", "UIThingsWidget" .. widget.key .. "AnchorDropdown", panel,
            "UIDropDownMenuTemplate")
        anchorDropdown:SetPoint("LEFT", cb, "RIGHT", 200, -2)
        UIDropDownMenu_SetWidth(anchorDropdown, 120)

        -- Swap Logic Helper
        local function SwapOrder(direction)
            local currentAnchor = UIThingsDB.widgets[widget.key].anchor
            if not currentAnchor then return end

            -- 1. Gather siblings
            local siblings = {}
            for _, wDef in ipairs(widgets) do
                local k = wDef.key
                local w = UIThingsDB.widgets[k]
                if w and w.anchor == currentAnchor and w.enabled then
                    table.insert(siblings, { key = k, data = w })
                end
            end

            -- 2. Sort by current order
            table.sort(siblings, function(a, b)
                local orderA = a.data.order or 0
                local orderB = b.data.order or 0
                if orderA ~= orderB then return orderA < orderB end
                return a.key < b.key
            end)

            -- 3. Normalize orders (1..N) and find self
            local myIndex = nil
            for i, sibling in ipairs(siblings) do
                sibling.data.order = i
                if sibling.key == widget.key then myIndex = i end
            end

            if not myIndex then return end

            -- 4. Identify Target
            local targetIndex = myIndex + direction
            if targetIndex >= 1 and targetIndex <= #siblings then
                -- 5. Swap
                local myData = siblings[myIndex].data
                local targetData = siblings[targetIndex].data

                local temp = myData.order
                myData.order = targetData.order
                targetData.order = temp

                UpdateWidgets()
            end
        end

        -- Left Button
        local leftBtn = CreateFrame("Button", "UIThingsWidget" .. widget.key .. "LeftBtn", panel, "UIPanelButtonTemplate")
        leftBtn:SetPoint("LEFT", anchorDropdown, "RIGHT", 130, 2)
        leftBtn:SetSize(22, 22)
        leftBtn:SetText("<")
        leftBtn:SetScript("OnClick", function() SwapOrder(-1) end)

        -- Right Button
        local rightBtn = CreateFrame("Button", "UIThingsWidget" .. widget.key .. "RightBtn", panel,
            "UIPanelButtonTemplate")
        rightBtn:SetPoint("LEFT", leftBtn, "RIGHT", 5, 0)
        rightBtn:SetSize(22, 22)
        rightBtn:SetText(">")
        rightBtn:SetScript("OnClick", function() SwapOrder(1) end)

        -- Visibility Helper
        local function UpdateButtonVisibility()
            local anchor = UIThingsDB.widgets[widget.key].anchor
            if anchor then
                leftBtn:Show()
                rightBtn:Show()
            else
                leftBtn:Hide()
                rightBtn:Hide()
            end
        end

        -- Redefine AnchorOnClick to include visibility update
        local function AnchorOnClick(self)
            UIDropDownMenu_SetSelectedID(anchorDropdown, self:GetID())
            UIThingsDB.widgets[widget.key].anchor = self.value
            UpdateWidgets()
            UpdateButtonVisibility()
        end

        -- Re-Initialize Dropdown with new handler
        local function AnchorInit(self, level)
            local anchors = GetAnchors()
            for _, anchor in ipairs(anchors) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = anchor.text
                info.value = anchor.value
                info.func = AnchorOnClick
                if anchor.value == UIThingsDB.widgets[widget.key].anchor then
                    info.checked = true
                else
                    info.checked = false
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end
        UIDropDownMenu_Initialize(anchorDropdown, AnchorInit)

        -- Set Text
        local currentAnchor = UIThingsDB.widgets[widget.key].anchor
        UIDropDownMenu_SetText(anchorDropdown, currentAnchor or "None")

        -- Initial State
        UpdateButtonVisibility()

        yOffset = yOffset - 40
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
