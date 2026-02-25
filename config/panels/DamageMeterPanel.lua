local addonName, addonTable = ...

addonTable.ConfigSetup = addonTable.ConfigSetup or {}

local Helpers = addonTable.ConfigHelpers

local function DamageMeterUpdateSettings()
    if addonTable.DamageMeter and addonTable.DamageMeter.UpdateSettings then
        addonTable.DamageMeter.UpdateSettings()
    end
end

function addonTable.ConfigSetup.DamageMeter(panel, tab, configWindow)
    Helpers.CreateResetButton(panel, "damageMeter")

    local scrollFrame = CreateFrame("ScrollFrame", "UIThingsDamageMeterScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 0)

    local child = CreateFrame("Frame", nil, scrollFrame)
    child:SetSize(650, 900)
    scrollFrame:SetScrollChild(child)

    local title = child:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Damage Meter")

    local desc = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", 16, -44)
    desc:SetText("|cff888888Adds a styled border and title bar to the built-in Blizzard damage meter.|r")

    -- --------------------------------------------------------
    -- Enable
    -- --------------------------------------------------------
    local enableCheckbox = CreateFrame("CheckButton", "UIThingsDamageMeterEnable", child,
        "ChatConfigCheckButtonTemplate")
    enableCheckbox:SetPoint("TOPLEFT", 20, -70)
    _G[enableCheckbox:GetName() .. "Text"]:SetText("Enable Damage Meter Skin")
    enableCheckbox:SetChecked(UIThingsDB.damageMeter.enabled)
    enableCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.damageMeter.enabled = self:GetChecked()
        Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.damageMeter.enabled)
        DamageMeterUpdateSettings()
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.damageMeter.enabled)

    -- --------------------------------------------------------
    -- Status label
    -- --------------------------------------------------------
    local detectedLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detectedLabel:SetPoint("TOPLEFT", 20, -98)

    local function RefreshDetectedLabel()
        local name = addonTable.DamageMeter and addonTable.DamageMeter.GetDetectedAddon and
            addonTable.DamageMeter.GetDetectedAddon()
        if name then
            detectedLabel:SetText("|cff00ff00Meter: " .. name .. "|r")
        else
            detectedLabel:SetText("|cffff8800Blizzard damage meter not available on this character|r")
        end
    end
    RefreshDetectedLabel()

    scrollFrame:SetScript("OnShow", function()
        child:SetWidth(scrollFrame:GetWidth())
        RefreshDetectedLabel()
    end)

    -- --------------------------------------------------------
    -- Appearance section
    -- --------------------------------------------------------
    Helpers.CreateSectionHeader(child, "Appearance", -120)

    -- Background color
    Helpers.CreateColorSwatch(child, "Background Color",
        UIThingsDB.damageMeter.bgColor,
        DamageMeterUpdateSettings,
        20, -150, true)

    -- Border color
    Helpers.CreateColorSwatch(child, "Border Color",
        UIThingsDB.damageMeter.borderColor,
        DamageMeterUpdateSettings,
        200, -150, false)

    -- Border size
    local borderLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    borderLabel:SetPoint("TOPLEFT", 20, -180)
    borderLabel:SetText("Border Size:")

    local borderInput = CreateFrame("EditBox", "UIThingsDamageMeterBorder", child, "InputBoxTemplate")
    borderInput:SetSize(50, 20)
    borderInput:SetPoint("LEFT", borderLabel, "RIGHT", 8, 0)
    borderInput:SetAutoFocus(false)
    borderInput:SetNumeric(true)
    borderInput:SetText(tostring(UIThingsDB.damageMeter.borderSize or 2))
    borderInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local v = tonumber(self:GetText()) or 2
        v = math.max(0, math.min(10, v))
        UIThingsDB.damageMeter.borderSize = v
        self:SetText(tostring(v))
        DamageMeterUpdateSettings()
    end)
    borderInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- --------------------------------------------------------
    -- Button Strip
    -- --------------------------------------------------------
    Helpers.CreateSectionHeader(child, "Button Strip", -210)

    -- Strip width
    local stripWLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    stripWLabel:SetPoint("TOPLEFT", 20, -240)
    stripWLabel:SetText("Strip Width:")

    local stripWInput = CreateFrame("EditBox", "UIThingsDamageMeterStripWidth", child, "InputBoxTemplate")
    stripWInput:SetSize(50, 20)
    stripWInput:SetPoint("LEFT", stripWLabel, "RIGHT", 8, 0)
    stripWInput:SetAutoFocus(false)
    stripWInput:SetNumeric(true)
    stripWInput:SetText(tostring(UIThingsDB.damageMeter.titleBarHeight or 20))
    stripWInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local v = tonumber(self:GetText()) or 20
        v = math.max(10, math.min(60, v))
        UIThingsDB.damageMeter.titleBarHeight = v
        self:SetText(tostring(v))
        DamageMeterUpdateSettings()
    end)
    stripWInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- --------------------------------------------------------
    -- Position
    -- --------------------------------------------------------
    Helpers.CreateSectionHeader(child, "Position", -275)

    -- Unlock / Lock toggle
    local lockBtn = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    lockBtn:SetSize(110, 24)
    lockBtn:SetPoint("TOPLEFT", 20, -305)

    local function RefreshLockBtn()
        if UIThingsDB.damageMeter.locked then
            lockBtn:SetText("Unlock Frame")
        else
            lockBtn:SetText("Lock Frame")
        end
    end
    RefreshLockBtn()

    lockBtn:SetScript("OnClick", function()
        local newLocked = not UIThingsDB.damageMeter.locked
        if addonTable.DamageMeter and addonTable.DamageMeter.SetLocked then
            addonTable.DamageMeter.SetLocked(newLocked)
        else
            UIThingsDB.damageMeter.locked = newLocked
        end
        RefreshLockBtn()
    end)

    -- Reflect Chat button
    local reflectBtn = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    reflectBtn:SetSize(130, 24)
    reflectBtn:SetPoint("LEFT", lockBtn, "RIGHT", 8, 0)
    reflectBtn:SetText("Reflect Chat")
    reflectBtn:SetScript("OnClick", function()
        if addonTable.DamageMeter and addonTable.DamageMeter.ReflectChat then
            addonTable.DamageMeter.ReflectChat()
        end
    end)

    local reflectNote = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    reflectNote:SetPoint("TOPLEFT", 20, -338)
    reflectNote:SetText("|cff888888Reflect Chat mirrors the meter to the opposite side of the screen at the same height.|r")

    -- Resync button
    local resyncBtn = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    resyncBtn:SetSize(110, 24)
    resyncBtn:SetPoint("TOPLEFT", 20, -360)
    resyncBtn:SetText("Resync Skin")
    resyncBtn:SetScript("OnClick", function()
        DamageMeterUpdateSettings()
    end)

    -- --------------------------------------------------------
    -- Dimensions & Position
    -- --------------------------------------------------------
    Helpers.CreateSectionHeader(child, "Dimensions & Position", -400)

    local dimNote = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dimNote:SetPoint("TOPLEFT", 20, -428)
    dimNote:SetWidth(560)
    dimNote:SetJustifyH("LEFT")
    dimNote:SetText("|cff888888Width/Height of 0 uses the chat frame size as fallback. Position is from the centre of the screen.|r")

    local function ApplyMeterDimPos()
        if addonTable.DamageMeter and addonTable.DamageMeter.ApplyPositionAndSize then
            addonTable.DamageMeter.ApplyPositionAndSize()
        end
    end

    local dimControlIdx = 0
    local function CreateDimControl(parent, label, yOff, minVal, maxVal, dbGet, dbSet, applyFn)
        dimControlIdx = dimControlIdx + 1
        local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("TOPLEFT", 20, yOff)
        lbl:SetText(label)

        local sliderName = "UIThingsDMDimCtrl" .. dimControlIdx
        local slider = CreateFrame("Slider", sliderName, parent, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", 20, yOff - 22)
        slider:SetWidth(180)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(1)
        slider:SetObeyStepOnDrag(true)
        slider:SetValue(dbGet())
        _G[sliderName .. "Low"]:SetText(tostring(minVal))
        _G[sliderName .. "High"]:SetText(tostring(maxVal))
        _G[sliderName .. "Text"]:SetText("")

        local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        editBox:SetSize(60, 20)
        editBox:SetPoint("LEFT", slider, "RIGHT", 8, 0)
        editBox:SetAutoFocus(false)
        editBox:SetNumeric(false)
        editBox:SetText(tostring(math.floor(dbGet() + 0.5)))

        local suppressSync = false

        local function Refresh()
            suppressSync = true
            local v = math.floor(dbGet() + 0.5)
            v = math.max(minVal, math.min(maxVal, v))
            slider:SetValue(v)
            editBox:SetText(tostring(v))
            suppressSync = false
        end

        slider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            dbSet(value)
            if not suppressSync then
                suppressSync = true
                editBox:SetText(tostring(value))
                suppressSync = false
            end
            applyFn()
        end)

        local function ApplyEditBox()
            local v = tonumber(editBox:GetText())
            if v then
                v = math.max(minVal, math.min(maxVal, math.floor(v + 0.5)))
                dbSet(v)
                suppressSync = true
                slider:SetValue(v)
                editBox:SetText(tostring(v))
                suppressSync = false
                applyFn()
            end
            editBox:ClearFocus()
        end

        editBox:SetScript("OnEnterPressed", ApplyEditBox)
        editBox:SetScript("OnEditFocusLost", ApplyEditBox)

        slider:SetScript("OnShow", Refresh)

        return Refresh
    end

    -- Width (0 = auto)
    CreateDimControl(child, "Width: (0 = auto)", -450,
        0, 1200,
        function() return UIThingsDB.damageMeter.width or 0 end,
        function(v) UIThingsDB.damageMeter.width = v end,
        ApplyMeterDimPos)

    -- Height (0 = auto)
    CreateDimControl(child, "Height: (0 = auto)", -505,
        0, 800,
        function() return UIThingsDB.damageMeter.height or 0 end,
        function(v) UIThingsDB.damageMeter.height = v end,
        ApplyMeterDimPos)

    local function GetMeterX()
        local f = addonTable.DamageMeter and addonTable.DamageMeter.GetMeterFrame and addonTable.DamageMeter.GetMeterFrame()
        if f and f:IsShown() then
            local cx, _ = f:GetCenter()
            local pcx, _ = UIParent:GetCenter()
            if cx and pcx then return math.floor(cx - pcx + 0.5) end
        end
        return UIThingsDB.damageMeter.pos and UIThingsDB.damageMeter.pos.x or 0
    end

    local function GetMeterY()
        local f = addonTable.DamageMeter and addonTable.DamageMeter.GetMeterFrame and addonTable.DamageMeter.GetMeterFrame()
        if f and f:IsShown() then
            local _, cy = f:GetCenter()
            local _, pcy = UIParent:GetCenter()
            if cy and pcy then return math.floor(cy - pcy + 0.5) end
        end
        return UIThingsDB.damageMeter.pos and UIThingsDB.damageMeter.pos.y or 0
    end

    -- X Position (CENTER-relative: negative = left of centre, positive = right)
    local refreshX = CreateDimControl(child, "X Position:", -560,
        -2000, 2000,
        GetMeterX,
        function(v) UIThingsDB.damageMeter.pos.x = v end,
        ApplyMeterDimPos)

    -- Y Position (CENTER-relative: negative = below centre, positive = above)
    local refreshY = CreateDimControl(child, "Y Position:", -615,
        -1200, 1200,
        GetMeterY,
        function(v) UIThingsDB.damageMeter.pos.y = v end,
        ApplyMeterDimPos)

    -- Expose refresh callbacks so DamageMeter.lua can update sliders after drag
    addonTable.DamageMeter.RefreshPosSliders = function()
        refreshX()
        refreshY()
    end

    -- Update reflect button to also refresh position sliders
    reflectBtn:SetScript("OnClick", function()
        if addonTable.DamageMeter and addonTable.DamageMeter.ReflectChat then
            addonTable.DamageMeter.ReflectChat()
            refreshX()
            refreshY()
        end
    end)
end
