local addonName, addonTable = ...
addonTable.ConfigHelpers = {}

local Helpers = addonTable.ConfigHelpers

-- Shared font list
Helpers.fonts = {
    { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { name = "Arial Narrow",  path = "Fonts\\ARIALN.TTF" },
    { name = "Skurri",        path = "Fonts\\skurri.ttf" },
    { name = "Morpheus",      path = "Fonts\\MORPHEUS.TTF" }
}

--- Helper: Update Visuals based on enabled state
-- @param panel frame The panel frame
-- @param tab frame The tab button
-- @param enabled boolean Whether module is enabled
function Helpers.UpdateModuleVisuals(panel, tab, enabled)
    if not enabled then
        -- Transparent Dark Red
        if not panel.bg then
            panel.bg = panel:CreateTexture(nil, "BACKGROUND")
            -- Inset to avoid covering the border
            panel.bg:SetPoint("TOPLEFT", 4, -28)
            panel.bg:SetPoint("BOTTOMRIGHT", -4, 4)
            panel.bg:SetColorTexture(0.3, 0, 0, 0.5)
        else
            panel.bg:Show()
        end

        -- Tint Tab Text Red
        if tab.Text then
            tab.Text:SetTextColor(1, 0.2, 0.2)
        elseif tab:GetFontString() then
            tab:GetFontString():SetTextColor(1, 0.2, 0.2)
        end
    else
        if panel.bg then panel.bg:Hide() end
        -- Reset Tab Text (Normal Color)
        if tab.Text then
            tab.Text:SetTextColor(1, 0.82, 0) -- GameFontNormal Color approx
        elseif tab:GetFontString() then
            tab:GetFontString():SetTextColor(1, 0.82, 0)
        end
    end
end

--- Helper: Create Section Header
-- @param parent frame Parent frame
-- @param text string Header text
-- @param yOffset number Y offset from TOPLEFT
-- @return fontstring The created header
function Helpers.CreateSectionHeader(parent, text, yOffset)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 16, yOffset)
    header:SetText(text)
    header:SetTextColor(1, 0.82, 0) -- Gold

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    line:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    line:SetHeight(1)
    line:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    return header
end

--- Helper: Create Color Picker
-- @param parent frame Parent frame
-- @param name string Unique name for the button
-- @param label string Label text
-- @param getFunc function Function that returns r, g, b
-- @param setFunc function Function that sets r, g, b
-- @param yOffset number Y offset from TOPLEFT
-- @return frame The color picker button
function Helpers.CreateColorPicker(parent, name, label, getFunc, setFunc, yOffset)
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

    return button
end
