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
    child:SetSize(650, 700)
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
    -- Title Bar section
    -- --------------------------------------------------------
    Helpers.CreateSectionHeader(child, "Title Bar", -210)

    local titleBarCheck = CreateFrame("CheckButton", "UIThingsDamageMeterTitleBar", child,
        "ChatConfigCheckButtonTemplate")
    titleBarCheck:SetPoint("TOPLEFT", 20, -240)
    _G[titleBarCheck:GetName() .. "Text"]:SetText("Show Title Bar")
    titleBarCheck:SetChecked(UIThingsDB.damageMeter.titleBar)
    titleBarCheck:SetScript("OnClick", function(self)
        UIThingsDB.damageMeter.titleBar = self:GetChecked()
        DamageMeterUpdateSettings()
    end)

    -- Title text
    local titleTextLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleTextLabel:SetPoint("TOPLEFT", 20, -270)
    titleTextLabel:SetText("Title Text:")

    local titleTextInput = CreateFrame("EditBox", "UIThingsDamageMeterTitleText", child, "InputBoxTemplate")
    titleTextInput:SetSize(180, 20)
    titleTextInput:SetPoint("LEFT", titleTextLabel, "RIGHT", 8, 0)
    titleTextInput:SetAutoFocus(false)
    titleTextInput:SetText(UIThingsDB.damageMeter.titleText or "Damage Meter")
    titleTextInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        UIThingsDB.damageMeter.titleText = self:GetText()
        DamageMeterUpdateSettings()
    end)
    titleTextInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Title bar color
    Helpers.CreateColorSwatch(child, "Title Bar Color",
        UIThingsDB.damageMeter.titleBarColor,
        DamageMeterUpdateSettings,
        20, -300, true)

    -- Title bar height
    local titleHLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleHLabel:SetPoint("TOPLEFT", 20, -330)
    titleHLabel:SetText("Title Bar Height:")

    local titleHInput = CreateFrame("EditBox", "UIThingsDamageMeterTitleHeight", child, "InputBoxTemplate")
    titleHInput:SetSize(50, 20)
    titleHInput:SetPoint("LEFT", titleHLabel, "RIGHT", 8, 0)
    titleHInput:SetAutoFocus(false)
    titleHInput:SetNumeric(true)
    titleHInput:SetText(tostring(UIThingsDB.damageMeter.titleBarHeight or 20))
    titleHInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local v = tonumber(self:GetText()) or 20
        v = math.max(10, math.min(60, v))
        UIThingsDB.damageMeter.titleBarHeight = v
        self:SetText(tostring(v))
        DamageMeterUpdateSettings()
    end)
    titleHInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- --------------------------------------------------------
    -- Position
    -- --------------------------------------------------------
    Helpers.CreateSectionHeader(child, "Position", -365)

    -- Unlock / Lock toggle
    local lockBtn = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    lockBtn:SetSize(110, 24)
    lockBtn:SetPoint("TOPLEFT", 20, -395)

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
    reflectNote:SetPoint("TOPLEFT", 20, -428)
    reflectNote:SetText("|cff888888Reflect Chat mirrors the meter to the opposite side of the screen at the same height.|r")

    -- Resync button
    local resyncBtn = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    resyncBtn:SetSize(110, 24)
    resyncBtn:SetPoint("TOPLEFT", 20, -450)
    resyncBtn:SetText("Resync Skin")
    resyncBtn:SetScript("OnClick", function()
        DamageMeterUpdateSettings()
    end)
end
