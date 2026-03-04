local addonName, addonTable = ...
addonTable.ConfigSetup = addonTable.ConfigSetup or {}

local Helpers = addonTable.ConfigHelpers

local function Refresh()
    if addonTable.DamageMeter and addonTable.DamageMeter.UpdateSettings then
        addonTable.DamageMeter.UpdateSettings()
    end
end

local function ResetData()
    if addonTable.DamageMeter and addonTable.DamageMeter.ResetData then
        addonTable.DamageMeter.ResetData()
    end
end

-- ============================================================
-- Slider factory (label + slider + editbox, returns refresh fn)
-- ============================================================
local sliderCounter = 0
local function MakeSlider(parent, label, yOff, minV, maxV, getVal, setVal, applyFn)
    sliderCounter = sliderCounter + 1

    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lbl:SetPoint("TOPLEFT", 20, yOff)
    lbl:SetText(label)

    local sName = "UIThingsDMSlider" .. sliderCounter
    local sl = CreateFrame("Slider", sName, parent, "OptionsSliderTemplate")
    sl:SetPoint("TOPLEFT", 20, yOff - 22)
    sl:SetWidth(200)
    sl:SetMinMaxValues(minV, maxV)
    sl:SetValueStep(1)
    sl:SetObeyStepOnDrag(true)
    sl:SetValue(math.max(minV, math.min(maxV, getVal())))
    _G[sName .. "Low"]:SetText(tostring(minV))
    _G[sName .. "High"]:SetText(tostring(maxV))
    _G[sName .. "Text"]:SetText("")

    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(55, 20)
    eb:SetPoint("LEFT", sl, "RIGHT", 8, 0)
    eb:SetAutoFocus(false)
    eb:SetText(tostring(math.floor(getVal() + 0.5)))

    local suppress = false
    local function SyncUI()
        suppress = true
        local v = math.floor(math.max(minV, math.min(maxV, getVal())) + 0.5)
        sl:SetValue(v)
        eb:SetText(tostring(v))
        suppress = false
    end

    sl:SetScript("OnValueChanged", function(_, val)
        val = math.floor(val + 0.5)
        setVal(val)
        if not suppress then
            suppress = true
            eb:SetText(tostring(val))
            suppress = false
        end
        applyFn()
    end)

    local function ApplyEB()
        local v = tonumber(eb:GetText())
        if v then
            v = math.floor(math.max(minV, math.min(maxV, v)) + 0.5)
            setVal(v)
            SyncUI()
            applyFn()
        end
        eb:ClearFocus()
    end
    eb:SetScript("OnEnterPressed", ApplyEB)
    eb:SetScript("OnEditFocusLost", ApplyEB)
    sl:SetScript("OnShow", SyncUI)

    return SyncUI
end

-- ============================================================
-- Dropdown factory (simple popup list)
-- ============================================================
local function MakeDropdown(parent, yOff, width, getItems, getCurrent, onSelect)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, 22)
    btn:SetPoint("TOPLEFT", 20, yOff)

    local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetFrameStrata("TOOLTIP")
    popup:Hide()
    popup:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    popup:SetBackdropColor(0.1, 0.1, 0.1, 0.97)
    popup:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local itemButtons = {}

    local function Rebuild()
        local items = getItems()
        -- Grow / shrink button pool
        while #itemButtons < #items do
            local b = CreateFrame("Button", nil, popup)
            b:SetHeight(20)
            b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            b.fs:SetPoint("LEFT", 6, 0)
            b.fs:SetJustifyH("LEFT")
            b:SetScript("OnEnter", function(self)
                self.fs:SetTextColor(1, 1, 0)
            end)
            b:SetScript("OnLeave", function(self)
                self.fs:SetTextColor(1, 1, 1)
            end)
            itemButtons[#itemButtons + 1] = b
        end
        for i, ib in ipairs(itemButtons) do
            if items[i] then ib:Show() else ib:Hide() end
        end
        for i, item in ipairs(items) do
            local ib = itemButtons[i]
            ib:ClearAllPoints()
            ib:SetPoint("TOPLEFT",  popup, "TOPLEFT",  2, -(i - 1) * 20 - 2)
            ib:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -2, -(i - 1) * 20 - 2)
            ib.fs:SetText(item.label)
            ib.fs:SetTextColor(1, 1, 1)
            local captVal = item.value
            ib:SetScript("OnClick", function()
                onSelect(captVal)
                popup:Hide()
                btn:SetText(getCurrent())
            end)
        end
        popup:SetHeight(#items * 20 + 4)
        popup:SetWidth(width)
    end

    btn:SetScript("OnClick", function(self)
        if popup:IsShown() then popup:Hide(); return end
        Rebuild()
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        popup:Show()
    end)

    popup:SetScript("OnHide", function() end)

    -- Close popup on click outside
    local closeFrame = CreateFrame("Frame", nil, UIParent)
    closeFrame:SetAllPoints()
    closeFrame:EnableMouse(true)
    closeFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    closeFrame:Hide()
    closeFrame:SetScript("OnMouseDown", function()
        popup:Hide()
        closeFrame:Hide()
    end)
    popup:SetScript("OnShow", function() closeFrame:Show() end)
    popup:SetScript("OnHide", function() closeFrame:Hide() end)

    btn:SetText(getCurrent())

    return function()
        btn:SetText(getCurrent())
    end
end

-- ============================================================
-- Panel Setup
-- ============================================================

function addonTable.ConfigSetup.DamageMeter(panel, tab, configWindow)
    Helpers.CreateResetButton(panel, "damageMeter")

    local sf = CreateFrame("ScrollFrame", "UIThingsDMPanelScroll", panel, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     0,   0)
    sf:SetPoint("BOTTOMRIGHT", -30, 0)

    local child = CreateFrame("Frame", nil, sf)
    sf:SetScript("OnShow", function()
        child:SetWidth(sf:GetWidth())
    end)
    child:SetSize(640, 1600)
    sf:SetScrollChild(child)

    -- ---- Title ----
    local title = child:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Damage Meter")

    local desc = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", 16, -44)
    desc:SetText("|cff888888A custom damage meter powered by Blizzard's C_DamageMeter API. Supports Damage, Healing, Interrupts, Deaths, Dispels, and Damage Taken.|r")

    local yBase = -70

    -- ============================================================
    -- Enable
    -- ============================================================
    local enableCB = CreateFrame("CheckButton", "UIThingsDMEnable", child, "ChatConfigCheckButtonTemplate")
    enableCB:SetPoint("TOPLEFT", 20, yBase)
    _G[enableCB:GetName() .. "Text"]:SetText("Enable Damage Meter")
    enableCB:SetChecked(UIThingsDB.damageMeter.enabled)
    enableCB:SetScript("OnClick", function(self)
        UIThingsDB.damageMeter.enabled = self:GetChecked()
        Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.damageMeter.enabled)
        Refresh()
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.damageMeter.enabled)

    -- Reset data + Lock/Unlock on their own line below the checkbox
    local resetBtn = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    resetBtn:SetSize(110, 22)
    resetBtn:SetPoint("TOPLEFT", 20, yBase - 30)
    resetBtn:SetText("Reset All Data")
    resetBtn:SetScript("OnClick", ResetData)

    -- Lock / Unlock
    local lockBtn = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    lockBtn:SetSize(110, 22)
    lockBtn:SetPoint("LEFT", resetBtn, "RIGHT", 6, 0)
    local function RefreshLock()
        lockBtn:SetText(UIThingsDB.damageMeter.locked and "Unlock Frame" or "Lock Frame")
    end
    RefreshLock()
    lockBtn:SetScript("OnClick", function()
        UIThingsDB.damageMeter.locked = not UIThingsDB.damageMeter.locked
        if addonTable.DamageMeter and addonTable.DamageMeter.SetLocked then
            addonTable.DamageMeter.SetLocked(UIThingsDB.damageMeter.locked)
        end
        RefreshLock()
    end)

    yBase = yBase - 64

    -- ============================================================
    -- Section: Meter Configuration
    -- ============================================================
    Helpers.CreateSectionHeader(child, "Meter Configuration", yBase)
    yBase = yBase - 28

    -- Number of meters
    local numLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    numLabel:SetPoint("TOPLEFT", 20, yBase)
    numLabel:SetText("Number of Meters:")

    local num1 = CreateFrame("CheckButton", "UIThingsDMNum1", child, "UICheckButtonTemplate")
    num1:SetSize(22, 22)
    num1:SetPoint("LEFT", numLabel, "RIGHT", 10, 0)
    _G[num1:GetName() .. "Text"]:SetText("1")
    local num2 = CreateFrame("CheckButton", "UIThingsDMNum2", child, "UICheckButtonTemplate")
    num2:SetSize(22, 22)
    num2:SetPoint("LEFT", num1, "RIGHT", 30, 0)
    _G[num2:GetName() .. "Text"]:SetText("2")

    local function RefreshNumBtns()
        local n = UIThingsDB.damageMeter.numMeters or 1
        num1:SetChecked(n == 1)
        num2:SetChecked(n == 2)
    end
    RefreshNumBtns()
    num1:SetScript("OnClick", function()
        UIThingsDB.damageMeter.numMeters = 1
        RefreshNumBtns()
        Refresh()
    end)
    num2:SetScript("OnClick", function()
        UIThingsDB.damageMeter.numMeters = 2
        RefreshNumBtns()
        Refresh()
    end)

    yBase = yBase - 30

    -- Meter type / session for each meter
    local METER_TYPES  = { "damage", "healing", "interrupts", "deaths", "dispels", "damageTaken" }
    local TYPE_LABELS  = { damage="Damage", healing="Healing", interrupts="Interrupts", deaths="Deaths",
                           dispels="Dispels", damageTaken="Dmg Taken" }

    for mIdx = 1, 2 do
        local captMIdx = mIdx

        -- Row 1: "Meter X:" header label
        local mLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        mLabel:SetPoint("TOPLEFT", 20, yBase)
        mLabel:SetText("Meter " .. mIdx .. ":")

        -- Row 2: type dropdown + session controls (22px below header)
        local controlY = yBase - 22

        -- Type dropdown
        local typeItems = {}
        for _, t in ipairs(METER_TYPES) do
            typeItems[#typeItems + 1] = { label = TYPE_LABELS[t] or t, value = t }
        end
        MakeDropdown(child, controlY, 130,
            function() return typeItems end,
            function()
                local cfg = (captMIdx == 1) and UIThingsDB.damageMeter.meter1 or UIThingsDB.damageMeter.meter2
                return TYPE_LABELS[cfg.type] or cfg.type
            end,
            function(val)
                local cfg = (captMIdx == 1) and UIThingsDB.damageMeter.meter1 or UIThingsDB.damageMeter.meter2
                cfg.type = val
                Refresh()
            end)

        -- Session radio (same row as dropdown)
        local sessLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        sessLabel:SetPoint("TOPLEFT", 170, controlY)
        sessLabel:SetText("Session:")

        local fightRB = CreateFrame("CheckButton", "UIThingsDMFight" .. mIdx, child, "UICheckButtonTemplate")
        fightRB:SetSize(20, 20)
        fightRB:SetPoint("LEFT", sessLabel, "RIGHT", 8, 0)
        _G[fightRB:GetName() .. "Text"]:SetText("Fight")

        local allRB = CreateFrame("CheckButton", "UIThingsDMAll" .. mIdx, child, "UICheckButtonTemplate")
        allRB:SetSize(20, 20)
        allRB:SetPoint("LEFT", fightRB, "RIGHT", 50, 0)
        _G[allRB:GetName() .. "Text"]:SetText("Overall")

        local function RefreshSess()
            local cfg = (captMIdx == 1) and UIThingsDB.damageMeter.meter1 or UIThingsDB.damageMeter.meter2
            fightRB:SetChecked(cfg.session == "fight")
            allRB:SetChecked(cfg.session ~= "fight")
        end
        RefreshSess()
        fightRB:SetScript("OnClick", function()
            local cfg = (captMIdx == 1) and UIThingsDB.damageMeter.meter1 or UIThingsDB.damageMeter.meter2
            cfg.session = "fight"
            RefreshSess()
            Refresh()
        end)
        allRB:SetScript("OnClick", function()
            local cfg = (captMIdx == 1) and UIThingsDB.damageMeter.meter1 or UIThingsDB.damageMeter.meter2
            cfg.session = "overall"
            RefreshSess()
            Refresh()
        end)

        yBase = yBase - 52
    end

    -- ============================================================
    -- Section: Behaviour
    -- ============================================================
    Helpers.CreateSectionHeader(child, "Behaviour", yBase)
    yBase = yBase - 28

    -- Clear on instance
    local clearCB = CreateFrame("CheckButton", "UIThingsDMClear", child, "ChatConfigCheckButtonTemplate")
    clearCB:SetPoint("TOPLEFT", 20, yBase)
    _G[clearCB:GetName() .. "Text"]:SetText("Clear data when entering an instance")
    clearCB:SetChecked(UIThingsDB.damageMeter.clearOnInstance)
    clearCB:SetScript("OnClick", function(self)
        UIThingsDB.damageMeter.clearOnInstance = self:GetChecked()
    end)
    yBase = yBase - 28

    -- Class colors
    local classCB = CreateFrame("CheckButton", "UIThingsDMClass", child, "ChatConfigCheckButtonTemplate")
    classCB:SetPoint("TOPLEFT", 20, yBase)
    _G[classCB:GetName() .. "Text"]:SetText("Use class colors for bars")
    classCB:SetChecked(UIThingsDB.damageMeter.useClassColors)
    classCB:SetScript("OnClick", function(self)
        UIThingsDB.damageMeter.useClassColors = self:GetChecked()
        Refresh()
    end)
    yBase = yBase - 28

    -- Show DPS
    local dpsCB = CreateFrame("CheckButton", "UIThingsDMShowDps", child, "ChatConfigCheckButtonTemplate")
    dpsCB:SetPoint("TOPLEFT", 20, yBase)
    _G[dpsCB:GetName() .. "Text"]:SetText("Show DPS (damage/healing types, requires bar height \226\137\165 28)")
    dpsCB:SetChecked(UIThingsDB.damageMeter.showDps)
    dpsCB:SetScript("OnClick", function(self)
        UIThingsDB.damageMeter.showDps = self:GetChecked()
        Refresh()
    end)
    yBase = yBase - 34

    -- ============================================================
    -- Section: Appearance
    -- ============================================================
    Helpers.CreateSectionHeader(child, "Appearance", yBase)
    yBase = yBase - 28

    -- Bar height slider
    local refreshBarH = MakeSlider(child, "Bar Height:", yBase, 12, 40,
        function() return UIThingsDB.damageMeter.barHeight or 18 end,
        function(v) UIThingsDB.damageMeter.barHeight = v end,
        Refresh)
    yBase = yBase - 56

    -- Border size
    local borderLbl = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    borderLbl:SetPoint("TOPLEFT", 20, yBase)
    borderLbl:SetText("Border Size:")
    local borderEB = CreateFrame("EditBox", nil, child, "InputBoxTemplate")
    borderEB:SetSize(50, 20)
    borderEB:SetPoint("LEFT", borderLbl, "RIGHT", 8, 0)
    borderEB:SetAutoFocus(false)
    borderEB:SetNumeric(true)
    borderEB:SetText(tostring(UIThingsDB.damageMeter.borderSize or 1))
    borderEB:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local v = math.max(0, math.min(8, tonumber(self:GetText()) or 1))
        UIThingsDB.damageMeter.borderSize = v
        self:SetText(tostring(v))
        Refresh()
    end)
    borderEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    yBase = yBase - 30

    -- Colors
    local colorDefs = {
        { label = "Background",   key = "bgColor",        withAlpha = true  },
        { label = "Border",       key = "borderColor",    withAlpha = false },
        { label = "Title Bar BG", key = "titleBgColor",   withAlpha = true  },
        { label = "Title Text",   key = "titleTextColor", withAlpha = false },
        { label = "Bar Fill",     key = "barColor",       withAlpha = true  },
        { label = "Bar BG",       key = "barBgColor",     withAlpha = true  },
        { label = "Bar Text",     key = "barTextColor",   withAlpha = false },
    }

    local colsPerRow = 2
    local colW       = 210
    for i, cd in ipairs(colorDefs) do
        local col = ((i - 1) % colsPerRow)
        local row = math.floor((i - 1) / colsPerRow)
        local xOff = 20 + col * colW
        local yOff = yBase - row * 32
        Helpers.CreateColorSwatch(child, cd.label,
            UIThingsDB.damageMeter[cd.key],
            Refresh,
            xOff, yOff, cd.withAlpha)
    end
    local colorRows = math.ceil(#colorDefs / colsPerRow)
    yBase = yBase - colorRows * 32 - 8

    -- ============================================================
    -- Section: Dock to Frame
    -- ============================================================
    Helpers.CreateSectionHeader(child, "Dock to Frame", yBase)
    yBase = yBase - 28

    local dockNote = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dockNote:SetPoint("TOPLEFT", 20, yBase)
    dockNote:SetWidth(580)
    dockNote:SetJustifyH("LEFT")
    dockNote:SetText("|cff888888Select a frame from the Frames module to use as the meter's container. "
        .. "Set to 'None' for a standalone window. The meter will synchronize its size and "
        .. "position to the selected frame every second.|r")
    yBase = yBase - 38

    local dockLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dockLabel:SetPoint("TOPLEFT", 20, yBase)
    dockLabel:SetText("Dock to Frame:")

    -- Build dock items dynamically from saved frames list
    local dockBtn = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    dockBtn:SetSize(200, 22)
    dockBtn:SetPoint("LEFT", dockLabel, "RIGHT", 10, 0)

    local dockPopup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    dockPopup:SetFrameStrata("TOOLTIP")
    dockPopup:Hide()
    dockPopup:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    dockPopup:SetBackdropColor(0.1, 0.1, 0.1, 0.97)
    dockPopup:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local dockItemBtns = {}

    local function GetDockLabel()
        local idx = UIThingsDB.damageMeter.dockToFrame or 0
        if idx == 0 then return "None (standalone)" end
        local frames = UIThingsDB.frames and UIThingsDB.frames.list or {}
        local fd = frames[idx]
        if fd then return (fd.name or ("Frame " .. idx)) .. " (#" .. idx .. ")" end
        return "Frame " .. idx
    end

    local function BuildDockPopup()
        local frames = UIThingsDB.frames and UIThingsDB.frames.list or {}
        local items  = { { label = "None (standalone)", value = 0 } }
        for i, fd in ipairs(frames) do
            items[#items + 1] = { label = (fd.name or ("Frame " .. i)) .. " (#" .. i .. ")", value = i }
        end
        while #dockItemBtns < #items do
            local b = CreateFrame("Button", nil, dockPopup)
            b:SetHeight(20)
            b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            b.fs:SetPoint("LEFT", 6, 0)
            b.fs:SetJustifyH("LEFT")
            b:SetScript("OnEnter", function(s) s.fs:SetTextColor(1, 1, 0) end)
            b:SetScript("OnLeave", function(s) s.fs:SetTextColor(1, 1, 1) end)
            dockItemBtns[#dockItemBtns + 1] = b
        end
        for i, ib in ipairs(dockItemBtns) do
            if items[i] then ib:Show() else ib:Hide() end
        end
        for i, item in ipairs(items) do
            local ib = dockItemBtns[i]
            ib:ClearAllPoints()
            ib:SetPoint("TOPLEFT",  dockPopup, "TOPLEFT",  2, -(i-1)*20-2)
            ib:SetPoint("TOPRIGHT", dockPopup, "TOPRIGHT", -2, -(i-1)*20-2)
            ib.fs:SetText(item.label)
            ib.fs:SetTextColor(1, 1, 1)
            local captVal = item.value
            ib:SetScript("OnClick", function()
                UIThingsDB.damageMeter.dockToFrame = captVal
                dockBtn:SetText(GetDockLabel())
                dockPopup:Hide()
                Refresh()
            end)
        end
        dockPopup:SetSize(200, #items * 20 + 4)
    end

    dockBtn:SetText(GetDockLabel())
    dockBtn:SetScript("OnClick", function(self)
        if dockPopup:IsShown() then dockPopup:Hide(); return end
        BuildDockPopup()
        dockPopup:ClearAllPoints()
        dockPopup:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        dockPopup:Show()
    end)

    local dockClose = CreateFrame("Frame", nil, UIParent)
    dockClose:SetAllPoints(); dockClose:EnableMouse(true)
    dockClose:SetFrameStrata("FULLSCREEN_DIALOG"); dockClose:Hide()
    dockClose:SetScript("OnMouseDown", function() dockPopup:Hide() end)
    dockPopup:SetScript("OnShow", function() dockClose:Show() end)
    dockPopup:SetScript("OnHide", function() dockClose:Hide() end)

    yBase = yBase - 30

    -- ============================================================
    -- Section: Position & Size
    -- ============================================================
    Helpers.CreateSectionHeader(child, "Position & Size", yBase)
    yBase = yBase - 16

    local dimNote = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dimNote:SetPoint("TOPLEFT", 20, yBase)
    dimNote:SetWidth(580)
    dimNote:SetJustifyH("LEFT")
    dimNote:SetText("|cff888888Position is relative to screen center. Ignored when docked to a frame.|r")
    yBase = yBase - 22

    local function GetMeterCX()
        local f = addonTable.DamageMeter and addonTable.DamageMeter.GetFrame and addonTable.DamageMeter.GetFrame()
        if f and f:IsShown() then
            local cx, _ = f:GetCenter(); local pcx, _ = UIParent:GetCenter()
            if cx and pcx then return math.floor(cx - pcx + 0.5) end
        end
        return UIThingsDB.damageMeter.pos and UIThingsDB.damageMeter.pos.x or 0
    end
    local function GetMeterCY()
        local f = addonTable.DamageMeter and addonTable.DamageMeter.GetFrame and addonTable.DamageMeter.GetFrame()
        if f and f:IsShown() then
            local _, cy = f:GetCenter(); local _, pcy = UIParent:GetCenter()
            if cy and pcy then return math.floor(cy - pcy + 0.5) end
        end
        return UIThingsDB.damageMeter.pos and UIThingsDB.damageMeter.pos.y or 0
    end

    local function ApplyPosSize()
        if addonTable.DamageMeter and addonTable.DamageMeter.UpdateSettings then
            addonTable.DamageMeter.UpdateSettings()
        end
    end

    local refreshWidth  = MakeSlider(child, "Width:",   yBase, 100, 1200,
        function() return UIThingsDB.damageMeter.width or 280 end,
        function(v) UIThingsDB.damageMeter.width = v end, ApplyPosSize)
    yBase = yBase - 56

    local refreshHeight = MakeSlider(child, "Height:", yBase, 80, 900,
        function() return UIThingsDB.damageMeter.height or 400 end,
        function(v) UIThingsDB.damageMeter.height = v end, ApplyPosSize)
    yBase = yBase - 56

    local refreshX = MakeSlider(child, "X Position:", yBase, -2000, 2000,
        GetMeterCX,
        function(v) UIThingsDB.damageMeter.pos.x = v end, ApplyPosSize)
    yBase = yBase - 56

    local refreshY = MakeSlider(child, "Y Position:", yBase, -1200, 1200,
        GetMeterCY,
        function(v) UIThingsDB.damageMeter.pos.y = v end, ApplyPosSize)
    yBase = yBase - 56

    -- Expose slider refresh for drag sync
    addonTable.DamageMeter.RefreshPosSliders = function()
        refreshX()
        refreshY()
    end

    child:SetHeight(math.abs(yBase) + 40)
end
