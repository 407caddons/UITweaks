local addonName, addonTable = ...

addonTable.ConfigSetup = addonTable.ConfigSetup or {}

local Helpers = addonTable.ConfigHelpers

-- Creates an edit box anchored to the right of a slider, synced bidirectionally
-- slider: the slider frame
-- minVal/maxVal: numeric bounds for clamping
-- isInteger: if true, rounds to whole numbers
-- formatFunc: optional function(value) -> display string for the slider text
local function CreateSliderEditBox(parent, slider, minVal, maxVal, isInteger, conflictAddon)
    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetSize(50, 20)
    editBox:SetPoint("LEFT", slider, "RIGHT", 15, 0)
    editBox:SetAutoFocus(false)
    editBox:SetJustifyH("CENTER")
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetText(tostring(isInteger and math.floor(slider:GetValue() + 0.5) or slider:GetValue()))

    if conflictAddon then
        editBox:Disable()
    end

    -- Slider updates edit box
    slider:HookScript("OnValueChanged", function(_, value)
        if isInteger then value = math.floor(value + 0.5) end
        if not editBox:HasFocus() then
            editBox:SetText(tostring(value))
        end
    end)

    -- Edit box updates slider
    editBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            val = math.max(minVal, math.min(maxVal, val))
            if isInteger then val = math.floor(val + 0.5) end
            slider:SetValue(val)
            self:SetText(tostring(val))
        else
            local cur = slider:GetValue()
            if isInteger then cur = math.floor(cur + 0.5) end
            self:SetText(tostring(cur))
        end
        self:ClearFocus()
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        local cur = slider:GetValue()
        if isInteger then cur = math.floor(cur + 0.5) end
        self:SetText(tostring(cur))
        self:ClearFocus()
    end)

    return editBox
end

-- Bars to show per-bar offset controls for (skip MainMenuBar as it shares buttons with MainActionBar)
local OFFSET_BARS = {
    "MainActionBar",
    "MultiBarBottomLeft",
    "MultiBarBottomRight",
    "MultiBarRight",
    "MultiBarLeft",
    "MultiBar5",
    "MultiBar6",
    "MultiBar7",
}

function addonTable.ConfigSetup.ActionBars(panel, navButton, configWindow)
    Helpers.CreateResetButton(panel, "actionBars")
    Helpers.UpdateModuleVisuals(panel, navButton, UIThingsDB.actionBars.enabled)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Action Bars")

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(560, 1400)
    scrollFrame:SetScrollChild(scrollChild)
    panel = scrollChild

    -- Check for conflicting action bar addons
    local conflictAddon = nil
    if C_AddOns.IsAddOnLoaded("Dominos") then
        conflictAddon = "Dominos"
    elseif C_AddOns.IsAddOnLoaded("Bartender4") then
        conflictAddon = "Bartender4"
    elseif C_AddOns.IsAddOnLoaded("ElvUI") then
        conflictAddon = "ElvUI"
    end

    local yPos = -10

    -- Enable Checkbox
    local enableBtn = CreateFrame("CheckButton", "UIThingsActionBarsEnabled", panel, "ChatConfigCheckButtonTemplate")
    enableBtn:SetPoint("TOPLEFT", 20, yPos)
    enableBtn:SetHitRectInsets(0, -250, 0, 0)
    _G[enableBtn:GetName() .. "Text"]:SetText("Enable MicroMenu Drawer (requires reload)")
    enableBtn:SetChecked(UIThingsDB.actionBars.enabled)

    if conflictAddon then
        enableBtn:Disable()
        enableBtn:SetChecked(false)
        UIThingsDB.actionBars.enabled = false
        Helpers.UpdateModuleVisuals(panel, navButton, false)
        local warnText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        warnText:SetPoint("TOPLEFT", 20, yPos - 22)
        warnText:SetTextColor(1, 0.4, 0.4)
        warnText:SetText(conflictAddon ..
            " is managing the micro menu. This feature is disabled while " .. conflictAddon .. " is loaded.")
    else
        enableBtn:SetScript("OnClick", function(self)
            UIThingsDB.actionBars.enabled = self:GetChecked()
            Helpers.UpdateModuleVisuals(panel, navButton, UIThingsDB.actionBars.enabled)
        end)
    end
    yPos = yPos - 30

    -- Lock Checkbox
    local lockBtn = CreateFrame("CheckButton", "UIThingsActionBarsLocked", panel, "ChatConfigCheckButtonTemplate")
    lockBtn:SetPoint("TOPLEFT", 20, yPos)
    lockBtn:SetHitRectInsets(0, -130, 0, 0)
    _G[lockBtn:GetName() .. "Text"]:SetText("Lock Drawer Position")
    lockBtn:SetChecked(UIThingsDB.actionBars.locked)
    lockBtn:SetScript("OnClick", function(self)
        if addonTable.ActionBars and addonTable.ActionBars.SetDrawerLocked then
            addonTable.ActionBars.SetDrawerLocked(self:GetChecked())
        end
    end)
    yPos = yPos - 30

    -- Description
    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", 20, yPos)
    desc:SetWidth(560)
    desc:SetJustifyH("LEFT")
    desc:SetTextColor(0.5, 0.5, 0.5)
    desc:SetText(
        "Collects the WoW micro menu buttons (Character, Spellbook, Talents, etc.) into a collapsible drawer. The drawer has a toggle button on the side to expand/collapse.")
    yPos = yPos - 30

    Helpers.CreateSectionHeader(panel, "Appearance", yPos)
    yPos = yPos - 30

    -- Background Color
    local bgLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bgLabel:SetPoint("TOPLEFT", 20, yPos)
    bgLabel:SetText("Background:")

    local bgSwatch = CreateFrame("Button", nil, panel)
    bgSwatch:SetSize(20, 20)
    bgSwatch:SetPoint("LEFT", bgLabel, "RIGHT", 10, 0)
    bgSwatch.tex = bgSwatch:CreateTexture(nil, "OVERLAY")
    bgSwatch.tex:SetAllPoints()
    local bgCol = UIThingsDB.actionBars.bgColor or { r = 0, g = 0, b = 0, a = 0.7 }
    bgSwatch.tex:SetColorTexture(bgCol.r, bgCol.g, bgCol.b, bgCol.a or 0.7)
    Mixin(bgSwatch, BackdropTemplateMixin)
    bgSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    bgSwatch:SetBackdropBorderColor(1, 1, 1)
    bgSwatch:SetScript("OnClick", function()
        local c = UIThingsDB.actionBars.bgColor or { r = 0, g = 0, b = 0, a = 0.7 }
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
                    bgSwatch.tex:SetColorTexture(r, g, b, a)
                    UIThingsDB.actionBars.bgColor = c
                    if addonTable.ActionBars and addonTable.ActionBars.UpdateDrawerBorder then
                        addonTable.ActionBars.UpdateDrawerBorder()
                    end
                end,
                cancelFunc = function()
                    bgSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
                    UIThingsDB.actionBars.bgColor = c
                    if addonTable.ActionBars and addonTable.ActionBars.UpdateDrawerBorder then
                        addonTable.ActionBars.UpdateDrawerBorder()
                    end
                end,
            })
        end
    end)

    -- Border Color
    local borderLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    borderLabel:SetPoint("TOPLEFT", 300, yPos)
    borderLabel:SetText("Border Color:")

    local borderSwatch = CreateFrame("Button", nil, panel)
    borderSwatch:SetSize(20, 20)
    borderSwatch:SetPoint("LEFT", borderLabel, "RIGHT", 10, 0)
    borderSwatch.tex = borderSwatch:CreateTexture(nil, "OVERLAY")
    borderSwatch.tex:SetAllPoints()
    local bCol = UIThingsDB.actionBars.borderColor or { r = 0.3, g = 0.3, b = 0.3, a = 1 }
    borderSwatch.tex:SetColorTexture(bCol.r, bCol.g, bCol.b, bCol.a or 1)
    Mixin(borderSwatch, BackdropTemplateMixin)
    borderSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    borderSwatch:SetBackdropBorderColor(1, 1, 1)
    borderSwatch:SetScript("OnClick", function()
        local c = UIThingsDB.actionBars.borderColor or { r = 0.3, g = 0.3, b = 0.3, a = 1 }
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
                    UIThingsDB.actionBars.borderColor = c
                    if addonTable.ActionBars and addonTable.ActionBars.UpdateDrawerBorder then
                        addonTable.ActionBars.UpdateDrawerBorder()
                    end
                end,
                cancelFunc = function()
                    borderSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
                    UIThingsDB.actionBars.borderColor = c
                    if addonTable.ActionBars and addonTable.ActionBars.UpdateDrawerBorder then
                        addonTable.ActionBars.UpdateDrawerBorder()
                    end
                end,
            })
        end
    end)
    yPos = yPos - 40

    -- Border Thickness Slider
    local borderSlider = CreateFrame("Slider", "UIThingsActionBarsBorderSize", panel, "OptionsSliderTemplate")
    borderSlider:SetPoint("TOPLEFT", 20, yPos)
    borderSlider:SetWidth(200)
    borderSlider:SetMinMaxValues(0, 5)
    borderSlider:SetValueStep(1)
    borderSlider:SetObeyStepOnDrag(true)
    borderSlider:SetValue(UIThingsDB.actionBars.borderSize or 2)
    _G[borderSlider:GetName() .. "Low"]:SetText("0")
    _G[borderSlider:GetName() .. "High"]:SetText("5")
    _G[borderSlider:GetName() .. "Text"]:SetText("Border Thickness: " .. (UIThingsDB.actionBars.borderSize or 2))
    borderSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        UIThingsDB.actionBars.borderSize = value
        _G[self:GetName() .. "Text"]:SetText("Border Thickness: " .. value)
        if addonTable.ActionBars and addonTable.ActionBars.UpdateDrawerBorder then
            addonTable.ActionBars.UpdateDrawerBorder()
        end
    end)
    yPos = yPos - 55

    -- Button Size Slider
    local sizeSlider = CreateFrame("Slider", "UIThingsActionBarsButtonSize", panel, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", 20, yPos)
    sizeSlider:SetWidth(200)
    sizeSlider:SetMinMaxValues(24, 48)
    sizeSlider:SetValueStep(2)
    sizeSlider:SetObeyStepOnDrag(true)
    sizeSlider:SetValue(UIThingsDB.actionBars.buttonSize or 32)
    _G[sizeSlider:GetName() .. "Low"]:SetText("24")
    _G[sizeSlider:GetName() .. "High"]:SetText("48")
    _G[sizeSlider:GetName() .. "Text"]:SetText("Button Size: " .. (UIThingsDB.actionBars.buttonSize or 32))
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        UIThingsDB.actionBars.buttonSize = value
        _G[self:GetName() .. "Text"]:SetText("Button Size: " .. value)
        if addonTable.ActionBars and addonTable.ActionBars.UpdateSettings then
            addonTable.ActionBars.UpdateSettings()
        end
    end)

    -- Button Padding Slider
    local paddingSlider = CreateFrame("Slider", "UIThingsActionBarsPadding", panel, "OptionsSliderTemplate")
    paddingSlider:SetPoint("TOPLEFT", 300, yPos)
    paddingSlider:SetWidth(200)
    paddingSlider:SetMinMaxValues(0, 10)
    paddingSlider:SetValueStep(1)
    paddingSlider:SetObeyStepOnDrag(true)
    paddingSlider:SetValue(UIThingsDB.actionBars.padding or 4)
    _G[paddingSlider:GetName() .. "Low"]:SetText("0")
    _G[paddingSlider:GetName() .. "High"]:SetText("10")
    _G[paddingSlider:GetName() .. "Text"]:SetText("Button Padding: " .. (UIThingsDB.actionBars.padding or 4))
    paddingSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        UIThingsDB.actionBars.padding = value
        _G[self:GetName() .. "Text"]:SetText("Button Padding: " .. value)
        if addonTable.ActionBars and addonTable.ActionBars.UpdateSettings then
            addonTable.ActionBars.UpdateSettings()
        end
    end)
    yPos = yPos - 55

    -- =============================================
    -- Skin Blizzard Bars Section
    -- =============================================
    Helpers.CreateSectionHeader(panel, "Skin Blizzard Bars", yPos)
    yPos = yPos - 30

    local skinEnable = CreateFrame("CheckButton", "UIThingsActionBarsSkinEnabled", panel, "ChatConfigCheckButtonTemplate")
    skinEnable:SetPoint("TOPLEFT", 20, yPos)
    skinEnable:SetHitRectInsets(0, -250, 0, 0)
    _G[skinEnable:GetName() .. "Text"]:SetText("Enable Bar Skinning (requires reload)")
    skinEnable:SetChecked(UIThingsDB.actionBars.skinEnabled)
    if conflictAddon then
        skinEnable:Disable()
        skinEnable:SetChecked(false)
    else
        skinEnable:SetScript("OnClick", function(self)
            UIThingsDB.actionBars.skinEnabled = self:GetChecked()
        end)
    end
    yPos = yPos - 30

    -- Hide checkboxes row 1
    local hideMacro = CreateFrame("CheckButton", "UIThingsActionBarsHideMacro", panel, "ChatConfigCheckButtonTemplate")
    hideMacro:SetPoint("TOPLEFT", 20, yPos)
    hideMacro:SetHitRectInsets(0, -130, 0, 0)
    _G[hideMacro:GetName() .. "Text"]:SetText("Hide Macro Text")
    hideMacro:SetChecked(UIThingsDB.actionBars.hideMacroText)
    if conflictAddon then
        hideMacro:Disable()
    else
        hideMacro:SetScript("OnClick", function(self)
            UIThingsDB.actionBars.hideMacroText = self:GetChecked()
            if addonTable.ActionBars and addonTable.ActionBars.UpdateSkin then
                addonTable.ActionBars.UpdateSkin()
            end
        end)
    end

    local hideKeybind = CreateFrame("CheckButton", "UIThingsActionBarsHideKeybind", panel,
        "ChatConfigCheckButtonTemplate")
    hideKeybind:SetPoint("TOPLEFT", 220, yPos)
    hideKeybind:SetHitRectInsets(0, -130, 0, 0)
    _G[hideKeybind:GetName() .. "Text"]:SetText("Hide Keybind Text")
    hideKeybind:SetChecked(UIThingsDB.actionBars.hideKeybindText)
    if conflictAddon then
        hideKeybind:Disable()
    else
        hideKeybind:SetScript("OnClick", function(self)
            UIThingsDB.actionBars.hideKeybindText = self:GetChecked()
            if addonTable.ActionBars and addonTable.ActionBars.UpdateSkin then
                addonTable.ActionBars.UpdateSkin()
            end
        end)
    end
    yPos = yPos - 30

    -- Hide checkboxes row 2
    local hideScroll = CreateFrame("CheckButton", "UIThingsActionBarsHideScroll", panel, "ChatConfigCheckButtonTemplate")
    hideScroll:SetPoint("TOPLEFT", 20, yPos)
    hideScroll:SetHitRectInsets(0, -180, 0, 0)
    _G[hideScroll:GetName() .. "Text"]:SetText("Hide Bar 1 Page Scroll")
    hideScroll:SetChecked(UIThingsDB.actionBars.hideBarScroll)
    if conflictAddon then
        hideScroll:Disable()
    else
        hideScroll:SetScript("OnClick", function(self)
            UIThingsDB.actionBars.hideBarScroll = self:GetChecked()
            if addonTable.ActionBars and addonTable.ActionBars.UpdateSkin then
                addonTable.ActionBars.UpdateSkin()
            end
        end)
    end

    local hideBags = CreateFrame("CheckButton", "UIThingsActionBarsHideBags", panel, "ChatConfigCheckButtonTemplate")
    hideBags:SetPoint("TOPLEFT", 280, yPos)
    hideBags:SetHitRectInsets(0, -130, 0, 0)
    _G[hideBags:GetName() .. "Text"]:SetText("Hide Bags Bar")
    hideBags:SetChecked(UIThingsDB.actionBars.hideBagsBar)
    if conflictAddon then
        hideBags:Disable()
    else
        hideBags:SetScript("OnClick", function(self)
            UIThingsDB.actionBars.hideBagsBar = self:GetChecked()
            if addonTable.ActionBars and addonTable.ActionBars.UpdateSkin then
                addonTable.ActionBars.UpdateSkin()
            end
        end)
    end
    yPos = yPos - 40

    -- Button Border Size Slider + Color
    local btnBorderSlider = CreateFrame("Slider", "UIThingsActionBarsSkinBtnBorder", panel, "OptionsSliderTemplate")
    btnBorderSlider:SetPoint("TOPLEFT", 20, yPos)
    btnBorderSlider:SetWidth(200)
    btnBorderSlider:SetMinMaxValues(0, 4)
    btnBorderSlider:SetValueStep(1)
    btnBorderSlider:SetObeyStepOnDrag(true)
    btnBorderSlider:SetValue(UIThingsDB.actionBars.skinButtonBorderSize or 1)
    _G[btnBorderSlider:GetName() .. "Low"]:SetText("0")
    _G[btnBorderSlider:GetName() .. "High"]:SetText("4")
    _G[btnBorderSlider:GetName() .. "Text"]:SetText("Button Border: " ..
        (UIThingsDB.actionBars.skinButtonBorderSize or 1))
    if conflictAddon then
        btnBorderSlider:Disable()
    else
        btnBorderSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            UIThingsDB.actionBars.skinButtonBorderSize = value
            _G[self:GetName() .. "Text"]:SetText("Button Border: " .. value)
            if addonTable.ActionBars and addonTable.ActionBars.UpdateSkin then
                addonTable.ActionBars.UpdateSkin()
            end
        end)
    end

    local btnBcLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btnBcLabel:SetPoint("TOPLEFT", 300, yPos + 5)
    btnBcLabel:SetText("Button Border:")
    local btnBcSwatch = CreateFrame("Button", nil, panel)
    btnBcSwatch:SetSize(20, 20)
    btnBcSwatch:SetPoint("LEFT", btnBcLabel, "RIGHT", 10, 0)
    btnBcSwatch.tex = btnBcSwatch:CreateTexture(nil, "OVERLAY")
    btnBcSwatch.tex:SetAllPoints()
    local btnBc = UIThingsDB.actionBars.skinButtonBorderColor or { r = 0.3, g = 0.3, b = 0.3, a = 1 }
    btnBcSwatch.tex:SetColorTexture(btnBc.r, btnBc.g, btnBc.b, btnBc.a or 1)
    Mixin(btnBcSwatch, BackdropTemplateMixin)
    btnBcSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    btnBcSwatch:SetBackdropBorderColor(1, 1, 1)
    if not conflictAddon then
        btnBcSwatch:SetScript("OnClick", function()
            local c = UIThingsDB.actionBars.skinButtonBorderColor
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
                        btnBcSwatch.tex:SetColorTexture(r, g, b, a)
                        if addonTable.ActionBars and addonTable.ActionBars.UpdateSkin then
                            addonTable.ActionBars.UpdateSkin()
                        end
                    end,
                    cancelFunc = function()
                        btnBcSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
                    end,
                })
            end
        end)
    end
    yPos = yPos - 50

    -- Bar Border Size Slider + Color
    local barBorderSlider = CreateFrame("Slider", "UIThingsActionBarsSkinBarBorder", panel, "OptionsSliderTemplate")
    barBorderSlider:SetPoint("TOPLEFT", 20, yPos)
    barBorderSlider:SetWidth(200)
    barBorderSlider:SetMinMaxValues(0, 4)
    barBorderSlider:SetValueStep(1)
    barBorderSlider:SetObeyStepOnDrag(true)
    barBorderSlider:SetValue(UIThingsDB.actionBars.skinBarBorderSize or 2)
    _G[barBorderSlider:GetName() .. "Low"]:SetText("0")
    _G[barBorderSlider:GetName() .. "High"]:SetText("4")
    _G[barBorderSlider:GetName() .. "Text"]:SetText("Bar Border: " .. (UIThingsDB.actionBars.skinBarBorderSize or 2))
    if conflictAddon then
        barBorderSlider:Disable()
    else
        barBorderSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            UIThingsDB.actionBars.skinBarBorderSize = value
            _G[self:GetName() .. "Text"]:SetText("Bar Border: " .. value)
            if addonTable.ActionBars and addonTable.ActionBars.UpdateSkin then
                addonTable.ActionBars.UpdateSkin()
            end
        end)
    end

    local barBcLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    barBcLabel:SetPoint("TOPLEFT", 300, yPos + 5)
    barBcLabel:SetText("Bar Border:")
    local barBcSwatch = CreateFrame("Button", nil, panel)
    barBcSwatch:SetSize(20, 20)
    barBcSwatch:SetPoint("LEFT", barBcLabel, "RIGHT", 10, 0)
    barBcSwatch.tex = barBcSwatch:CreateTexture(nil, "OVERLAY")
    barBcSwatch.tex:SetAllPoints()
    local barBc = UIThingsDB.actionBars.skinBarBorderColor or { r = 0.2, g = 0.2, b = 0.2, a = 1 }
    barBcSwatch.tex:SetColorTexture(barBc.r, barBc.g, barBc.b, barBc.a or 1)
    Mixin(barBcSwatch, BackdropTemplateMixin)
    barBcSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    barBcSwatch:SetBackdropBorderColor(1, 1, 1)
    if not conflictAddon then
        barBcSwatch:SetScript("OnClick", function()
            local c = UIThingsDB.actionBars.skinBarBorderColor
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
                        barBcSwatch.tex:SetColorTexture(r, g, b, a)
                        if addonTable.ActionBars and addonTable.ActionBars.UpdateSkin then
                            addonTable.ActionBars.UpdateSkin()
                        end
                    end,
                    cancelFunc = function()
                        barBcSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
                    end,
                })
            end
        end)
    end

    -- Bar Background Color
    local barBgLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    barBgLabel:SetPoint("TOPLEFT", 300, yPos - 25)
    barBgLabel:SetText("Bar Background:")
    local barBgSwatch = CreateFrame("Button", nil, panel)
    barBgSwatch:SetSize(20, 20)
    barBgSwatch:SetPoint("LEFT", barBgLabel, "RIGHT", 10, 0)
    barBgSwatch.tex = barBgSwatch:CreateTexture(nil, "OVERLAY")
    barBgSwatch.tex:SetAllPoints()
    local barBg = UIThingsDB.actionBars.skinBarBgColor or { r = 0, g = 0, b = 0, a = 0.5 }
    barBgSwatch.tex:SetColorTexture(barBg.r, barBg.g, barBg.b, barBg.a or 0.5)
    Mixin(barBgSwatch, BackdropTemplateMixin)
    barBgSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    barBgSwatch:SetBackdropBorderColor(1, 1, 1)
    if not conflictAddon then
        barBgSwatch:SetScript("OnClick", function()
            local c = UIThingsDB.actionBars.skinBarBgColor
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
                        barBgSwatch.tex:SetColorTexture(r, g, b, a)
                        if addonTable.ActionBars and addonTable.ActionBars.UpdateSkin then
                            addonTable.ActionBars.UpdateSkin()
                        end
                    end,
                    cancelFunc = function()
                        barBgSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
                    end,
                })
            end
        end)
    end
    yPos = yPos - 55

    -- =============================================
    -- Layout Overrides Section
    -- =============================================
    Helpers.CreateSectionHeader(panel, "Layout Overrides", yPos)
    yPos = yPos - 25

    local layoutDesc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    layoutDesc:SetPoint("TOPLEFT", 20, yPos)
    layoutDesc:SetWidth(540)
    layoutDesc:SetJustifyH("LEFT")
    layoutDesc:SetTextColor(0.5, 0.5, 0.5)
    layoutDesc:SetText(
        "Positions are relative offsets from the Blizzard default positions. Always /reload after making changes. Don't allow any of the bars to be docked in edit mode because moving them becomes unpredictable. Get them close and then tweak in these settings.")
    yPos = yPos - 35

    -- Button Spacing Slider
    local spacingSlider = CreateFrame("Slider", "UIThingsActionBarsSkinSpacing", panel, "OptionsSliderTemplate")
    spacingSlider:SetPoint("TOPLEFT", 20, yPos)
    spacingSlider:SetWidth(180)
    spacingSlider:SetMinMaxValues(0, 10)
    spacingSlider:SetValueStep(1)
    spacingSlider:SetObeyStepOnDrag(true)
    spacingSlider:SetValue(UIThingsDB.actionBars.skinButtonSpacing or 2)
    _G[spacingSlider:GetName() .. "Low"]:SetText("0")
    _G[spacingSlider:GetName() .. "High"]:SetText("10")
    _G[spacingSlider:GetName() .. "Text"]:SetText("Button Spacing: " .. (UIThingsDB.actionBars.skinButtonSpacing or 2))
    if conflictAddon then
        spacingSlider:Disable()
    else
        spacingSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            UIThingsDB.actionBars.skinButtonSpacing = value
            _G[self:GetName() .. "Text"]:SetText("Button Spacing: " .. value)
            if addonTable.ActionBars and addonTable.ActionBars.UpdateSkin then
                addonTable.ActionBars.UpdateSkin()
            end
        end)
    end
    CreateSliderEditBox(panel, spacingSlider, 0, 10, true, conflictAddon)

    -- Button Size Slider (0 = default)
    local btnSizeVal = UIThingsDB.actionBars.skinButtonSize or 0
    local btnSizeSlider = CreateFrame("Slider", "UIThingsActionBarsSkinBtnSize", panel, "OptionsSliderTemplate")
    btnSizeSlider:SetPoint("TOPLEFT", 300, yPos)
    btnSizeSlider:SetWidth(180)
    btnSizeSlider:SetMinMaxValues(0, 64)
    btnSizeSlider:SetValueStep(1)
    btnSizeSlider:SetObeyStepOnDrag(true)
    btnSizeSlider:SetValue(btnSizeVal)
    _G[btnSizeSlider:GetName() .. "Low"]:SetText("0")
    _G[btnSizeSlider:GetName() .. "High"]:SetText("64")
    _G[btnSizeSlider:GetName() .. "Text"]:SetText("Button Size: " .. (btnSizeVal == 0 and "Default" or btnSizeVal))
    if conflictAddon then
        btnSizeSlider:Disable()
    else
        btnSizeSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            UIThingsDB.actionBars.skinButtonSize = value
            _G[self:GetName() .. "Text"]:SetText("Button Size: " .. (value == 0 and "Default" or value))
            if addonTable.ActionBars and addonTable.ActionBars.UpdateSkin then
                addonTable.ActionBars.UpdateSkin()
            end
        end)
    end
    CreateSliderEditBox(panel, btnSizeSlider, 0, 64, true, conflictAddon)
    yPos = yPos - 55

    -- Per-bar position (absolute, relative to UIParent CENTER)
    if not UIThingsDB.actionBars.barPositions then
        UIThingsDB.actionBars.barPositions = {}
    end

    local AB = addonTable.ActionBars
    local displayNames = AB and AB.BAR_DISPLAY_NAMES or {}

    -- Track sliders per bar so drag callback can update them
    local barSliders = {}

    for _, barName in ipairs(OFFSET_BARS) do
        local displayName = displayNames[barName] or barName
        -- Show the bar's actual current position in the sliders:
        -- prefer live position from the frame, fall back to stored position
        local absPos = UIThingsDB.actionBars.barPositions[barName]
        local displayX = absPos and absPos.x or 0
        local displayY = absPos and absPos.y or 0
        if AB and AB.FrameToUIParentPosition then
            local barFrame = _G[barName]
            if barFrame then
                local curPos = AB.FrameToUIParentPosition(barFrame)
                if curPos then
                    displayX = curPos.x
                    displayY = curPos.y
                end
            end
        end

        -- Bar name label — highlights the bar on hover
        local barHeaderText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        barHeaderText:SetPoint("TOPLEFT", 20, yPos)
        barHeaderText:SetText(displayName)

        -- Invisible hover frame sized to the text
        local barHeader = CreateFrame("Frame", nil, panel)
        barHeader:SetPoint("TOPLEFT", barHeaderText, "TOPLEFT", -2, 2)
        barHeader:SetPoint("BOTTOMRIGHT", barHeaderText, "BOTTOMRIGHT", 2, -2)

        if not conflictAddon and AB then
            barHeader:EnableMouse(true)
            barHeader:SetScript("OnEnter", function()
                AB.HighlightBar(barName)
            end)
            barHeader:SetScript("OnLeave", function()
                if not AB.IsBarDragging(barName) then
                    AB.UnhighlightBar()
                end
            end)
        end

        -- Move button — anchored after text, not covered by hover frame
        if not conflictAddon and AB then
            local moveBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
            moveBtn:SetSize(50, 20)
            moveBtn:SetPoint("LEFT", barHeaderText, "RIGHT", 10, 0)
            moveBtn:SetText("Move")

            moveBtn:SetScript("OnEnter", function()
                AB.HighlightBar(barName)
            end)
            moveBtn:SetScript("OnLeave", function()
                if not AB.IsBarDragging(barName) then
                    AB.UnhighlightBar()
                end
            end)

            moveBtn:SetScript("OnClick", function(self)
                if AB.IsBarDragging(barName) then
                    AB.StopBarDrag(barName)
                    self:SetText("Move")
                else
                    AB.StartBarDrag(barName)
                    self:SetText("Stop")
                end
            end)
        end

        -- X Position
        local xSlider = CreateFrame("Slider", "UIThingsAB_" .. barName .. "_X", panel, "OptionsSliderTemplate")
        xSlider:SetPoint("TOPLEFT", 20, yPos - 25)
        xSlider:SetWidth(180)
        xSlider:SetMinMaxValues(-2000, 2000)
        xSlider:SetValueStep(1)
        xSlider:SetObeyStepOnDrag(true)
        xSlider:SetValue(displayX)
        _G[xSlider:GetName() .. "Low"]:SetText("")
        _G[xSlider:GetName() .. "High"]:SetText("")
        _G[xSlider:GetName() .. "Text"]:SetText("X: " .. displayX)
        if conflictAddon then
            xSlider:Disable()
        else
            xSlider:SetScript("OnValueChanged", function(self, value)
                value = math.floor(value + 0.5)
                if not UIThingsDB.actionBars.barPositions[barName] then
                    -- Seed from current position
                    local barFrame = _G[barName]
                    local cur = barFrame and AB and AB.FrameToUIParentPosition(barFrame)
                    UIThingsDB.actionBars.barPositions[barName] = cur or { point = "CENTER", x = 0, y = 0 }
                end
                UIThingsDB.actionBars.barPositions[barName].x = value
                _G[self:GetName() .. "Text"]:SetText("X: " .. value)
                if AB and AB.UpdateSkin then
                    AB.UpdateSkin()
                end
            end)
        end
        CreateSliderEditBox(panel, xSlider, -2000, 2000, true, conflictAddon)

        -- Y Position
        local ySlider = CreateFrame("Slider", "UIThingsAB_" .. barName .. "_Y", panel, "OptionsSliderTemplate")
        ySlider:SetPoint("TOPLEFT", 300, yPos - 25)
        ySlider:SetWidth(180)
        ySlider:SetMinMaxValues(-2000, 2000)
        ySlider:SetValueStep(1)
        ySlider:SetObeyStepOnDrag(true)
        ySlider:SetValue(displayY)
        _G[ySlider:GetName() .. "Low"]:SetText("")
        _G[ySlider:GetName() .. "High"]:SetText("")
        _G[ySlider:GetName() .. "Text"]:SetText("Y: " .. displayY)
        if conflictAddon then
            ySlider:Disable()
        else
            ySlider:SetScript("OnValueChanged", function(self, value)
                value = math.floor(value + 0.5)
                if not UIThingsDB.actionBars.barPositions[barName] then
                    local barFrame = _G[barName]
                    local cur = barFrame and AB and AB.FrameToUIParentPosition(barFrame)
                    UIThingsDB.actionBars.barPositions[barName] = cur or { point = "CENTER", x = 0, y = 0 }
                end
                UIThingsDB.actionBars.barPositions[barName].y = value
                _G[self:GetName() .. "Text"]:SetText("Y: " .. value)
                if AB and AB.UpdateSkin then
                    AB.UpdateSkin()
                end
            end)
        end
        CreateSliderEditBox(panel, ySlider, -2000, 2000, true, conflictAddon)

        barSliders[barName] = { x = xSlider, y = ySlider }

        yPos = yPos - 65
    end

    -- Register drag callback so dragging a bar updates the sliders in real time
    if AB then
        AB.onBarDragUpdate = function(barName, newPos)
            local sliders = barSliders[barName]
            if sliders and newPos then
                sliders.x:SetValue(newPos.x)
                sliders.y:SetValue(newPos.y)
            end
        end
    end

    -- Update scroll child height to fit content
    scrollChild:SetHeight(math.abs(yPos) + 20)
end
