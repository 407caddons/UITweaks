local addonName, addonTable = ...

-- Create setup table if it doesn't exist
addonTable.ConfigSetup = addonTable.ConfigSetup or {}

-- Get helpers
local Helpers = addonTable.ConfigHelpers

-- Helper: Create Color Picker
local function CreateColorPicker(parent, name, label, getFunc, setFunc, yOffset)
    local button = CreateFrame("Button", name, parent)
    button:SetSize(200, 24)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    button:EnableMouse(true)
    button:RegisterForClicks("AnyUp")

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetSize(24, 24)
    button.bg:SetPoint("LEFT")
    button.bg:SetColorTexture(1, 1, 1)

    button.color = button:CreateTexture(nil, "OVERLAY")
    button.color:SetPoint("LEFT", button.bg, "LEFT", 2, 0)
    button.color:SetSize(20, 20)

    local r, g, b = getFunc()
    button.color:SetColorTexture(r, g, b)

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.text:SetPoint("LEFT", button.bg, "RIGHT", 10, 0)
    button.text:SetText(label)

    button:SetScript("OnClick", function(self)
        local r, g, b = getFunc()

        local function SwatchFunc()
            local newR, newG, newB = ColorPickerFrame:GetColorRGB()
            setFunc(newR, newG, newB)
            button.color:SetColorTexture(newR, newG, newB)
        end

        local function CancelFunc(previousValues)
            local newR, newG, newB
            if previousValues then
                newR, newG, newB = previousValues.r, previousValues.g, previousValues.b
            else
                newR, newG, newB = r, g, b
            end
            setFunc(newR, newG, newB)
            button.color:SetColorTexture(newR, newG, newB)
        end

        if ColorPickerFrame.SetupColorPickerAndShow then
            local info = {
                swatchFunc = SwatchFunc,
                cancelFunc = CancelFunc,
                r = r,
                g = g,
                b = b,
                hasOpacity = false,
            }
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            ColorPickerFrame.func = SwatchFunc
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame.cancelFunc = CancelFunc
            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame:Show()
        end
    end)
end

-- Define the setup function for Combat panel
function addonTable.ConfigSetup.Combat(panel, tab, configWindow)
    local fonts = Helpers.fonts

    local function UpdateCombat()
        if addonTable.Combat and addonTable.Combat.UpdateSettings then
            addonTable.Combat.UpdateSettings()
        end
    end

    -- Enable Combat Timer Checkbox
    local combatTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    combatTitle:SetPoint("TOPLEFT", 16, -16)
    combatTitle:SetText("Combat Timer")

    local enableCombatBtn = CreateFrame("CheckButton", "UIThingsCombatEnableCheck", panel,
        "ChatConfigCheckButtonTemplate")
    enableCombatBtn:SetPoint("TOPLEFT", 20, -50)
    _G[enableCombatBtn:GetName() .. "Text"]:SetText("Enable Combat Timer")
    enableCombatBtn:SetChecked(UIThingsDB.combat.enabled)
    enableCombatBtn:SetScript("OnClick", function(self)
        local enabled = not not self:GetChecked()
        UIThingsDB.combat.enabled = enabled
        UpdateCombat()
        Helpers.UpdateModuleVisuals(panel, tab, enabled)
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.combat.enabled)

    -- Lock Timer
    local combatLockBtn = CreateFrame("CheckButton", "UIThingsCombatLockCheck", panel,
        "ChatConfigCheckButtonTemplate")
    combatLockBtn:SetPoint("TOPLEFT", 20, -70)
    _G[combatLockBtn:GetName() .. "Text"]:SetText("Lock Combat Timer")
    combatLockBtn:SetChecked(UIThingsDB.combat.locked)
    combatLockBtn:SetScript("OnClick", function(self)
        local locked = not not self:GetChecked()
        UIThingsDB.combat.locked = locked
        UpdateCombat()
    end)

    -- Font Selector (Simple Dropdown)
    local fontLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fontLabel:SetPoint("TOPLEFT", 20, -110)
    fontLabel:SetText("Font:")

    local fontDropdown = CreateFrame("Frame", "UIThingsFontDropdown", panel, "UIDropDownMenuTemplate")
    fontDropdown:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", -15, -10)

    local function OnClick(self)
        UIDropDownMenu_SetSelectedID(fontDropdown, self:GetID())
        UIThingsDB.combat.font = self.value
        UpdateCombat()
    end

    local function Initialize(self, level)
        for k, v in pairs(fonts) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = v.name
            info.value = v.path
            info.func = OnClick
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(fontDropdown, Initialize)
    UIDropDownMenu_SetText(fontDropdown, "Select Font")
    for i, f in ipairs(fonts) do
        if f.path == UIThingsDB.combat.font then
            UIDropDownMenu_SetText(fontDropdown, f.name)
        end
    end

    -- Font Size Slider
    local fontSizeSlider = CreateFrame("Slider", "UIThingsFontSizeSlider", panel, "OptionsSliderTemplate")
    fontSizeSlider:SetPoint("TOPLEFT", 20, -180)
    fontSizeSlider:SetMinMaxValues(10, 32)
    fontSizeSlider:SetValueStep(1)
    fontSizeSlider:SetObeyStepOnDrag(true)
    fontSizeSlider:SetWidth(150)
    _G[fontSizeSlider:GetName() .. 'Text']:SetText(string.format("Size: %d", UIThingsDB.combat.fontSize))
    _G[fontSizeSlider:GetName() .. 'Low']:SetText("10")
    _G[fontSizeSlider:GetName() .. 'High']:SetText("32")
    fontSizeSlider:SetValue(UIThingsDB.combat.fontSize)
    fontSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.combat.fontSize = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Size: %d", value))
        UpdateCombat()
    end)

    -- Color Pickers
    CreateColorPicker(panel, "UIThingsCombatColorIn", "In Combat Color",
        function()
            return UIThingsDB.combat.colorInCombat.r, UIThingsDB.combat.colorInCombat.g,
                UIThingsDB.combat.colorInCombat.b
        end,
        function(r, g, b)
            UIThingsDB.combat.colorInCombat = { r = r, g = g, b = b }
            UpdateCombat()
        end,
        -230
    )

    CreateColorPicker(panel, "UIThingsCombatColorOut", "Out Combat Color",
        function()
            return UIThingsDB.combat.colorOutCombat.r, UIThingsDB.combat.colorOutCombat.g,
                UIThingsDB.combat.colorOutCombat.b
        end,
        function(r, g, b)
            UIThingsDB.combat.colorOutCombat = { r = r, g = g, b = b }
            UpdateCombat()
        end,
        -260
    )
end
