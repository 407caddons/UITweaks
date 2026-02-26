-- Profiler.lua
-- Lightweight per-module CPU and memory profiler for LunaUITweaks.
-- Load order: after EventBus.lua, before all feature modules.
-- Toggle with /luit perf
--
-- Inspired by WeakAuras' profiling approach:
--   • Function-pointer swapping for zero overhead when off
--   • Spike tracking (worst single-call duration per module)
--   • wipe() for table reuse to reduce GC pressure

local addonName, addonTable = ...
addonTable.Profiler = {}
local Profiler = addonTable.Profiler

local enabled = false
local paused = false
local moduleTimings = {} -- ["Loot"] = { total = 0, calls = 0, spike = 0 }
local totalTimings = {}  -- ["Loot"] = { total = 0, calls = 0 }
local ticker = nil
local REPORT_INTERVAL = 5 -- seconds
local MAX_ROWS = 40
local ROW_HEIGHT = 18
local HEADER_HEIGHT = 20
local TITLE_HEIGHT = 28
local FRAME_WIDTH = 640
local COL_MODULE = 160
local COL_ICALLS = 65
local COL_ITIME = 75
local COL_TCALLS = 70
local COL_TTIME = 80
local COL_SPIKE = 80
local PAD = 10

-- ============================================================
-- Function-pointer swap strategy
-- ============================================================

local strategy = {}

local function passThroughExec(_, callback, ...)
    return callback(...)
end

local function timingExec(moduleName, callback, ...)
    local t = moduleTimings[moduleName]
    if not t then
        t = { total = 0, calls = 0, spike = 0 }
        moduleTimings[moduleName] = t
    end
    local start = debugprofilestop()
    callback(...)
    local elapsed = debugprofilestop() - start
    t.total = t.total + elapsed
    t.calls = t.calls + 1
    if elapsed > t.spike then
        t.spike = elapsed
    end
end

strategy.exec = passThroughExec

function Profiler.WrapCallback(moduleName, callback)
    return function(...)
        return strategy.exec(moduleName, callback, ...)
    end
end

Profiler.Wrap = Profiler.WrapCallback

-- ============================================================
-- Display frame (built lazily on first toggle)
-- ============================================================

local displayFrame, memoryText, pauseBtn, rowFrames, headerFrame

local function FormatTime(us)
    local ms = us / 1000
    if ms >= 1000 then
        return ("%.1fs"):format(ms / 1000)
    end
    return ("%.1fms"):format(ms)
end

local function SpikeColor(spike)
    local ms = spike / 1000
    if ms >= 5 then
        return 1, 0.27, 0.27     -- red
    elseif ms >= 1 then
        return 1, 0.67, 0        -- orange
    end
    return 0, 1, 0.59             -- green
end

local sortedRows = {} -- reusable scratch table

local function UpdateDisplay()
    if not displayFrame or not displayFrame:IsShown() then return end

    UpdateAddOnMemoryUsage()
    local kb = GetAddOnMemoryUsage("LunaUITweaks")
    memoryText:SetText(("Memory: %.0f KB (%.1f MB)"):format(kb, kb / 1024))

    -- Build sorted snapshot from interval data
    wipe(sortedRows)
    for name, t in pairs(moduleTimings) do
        -- Accumulate into totals
        local tot = totalTimings[name]
        if not tot then
            tot = { total = 0, calls = 0 }
            totalTimings[name] = tot
        end
        tot.total = tot.total + t.total
        tot.calls = tot.calls + t.calls

        if t.calls > 0 or tot.calls > 0 then
            sortedRows[#sortedRows + 1] = {
                name = name,
                iTotal = t.total,
                iCalls = t.calls,
                spike = t.spike,
                tTotal = tot.total,
                tCalls = tot.calls,
            }
        end

        -- Reset interval counters
        t.total = 0
        t.calls = 0
        t.spike = 0
    end

    -- Also add modules that only appear in totals (no interval activity)
    for name, tot in pairs(totalTimings) do
        if not moduleTimings[name] and tot.calls > 0 then
            sortedRows[#sortedRows + 1] = {
                name = name,
                iTotal = 0,
                iCalls = 0,
                spike = 0,
                tTotal = tot.total,
                tCalls = tot.calls,
            }
        end
    end

    table.sort(sortedRows, function(a, b) return a.iTotal > b.iTotal end)

    local visibleCount = math.min(#sortedRows, MAX_ROWS)
    for i = 1, MAX_ROWS do
        local row = rowFrames[i]
        if i <= visibleCount then
            local d = sortedRows[i]
            row.nameText:SetText(d.name)
            row.iCallsText:SetText(d.iCalls > 0 and d.iCalls or "")
            row.iTimeText:SetText(d.iCalls > 0 and FormatTime(d.iTotal) or "")
            row.tCallsText:SetText(d.tCalls)
            row.tTimeText:SetText(FormatTime(d.tTotal))
            if d.spike > 0 then
                local r, g, b = SpikeColor(d.spike)
                row.spikeText:SetText(FormatTime(d.spike))
                row.spikeText:SetTextColor(r, g, b)
            else
                row.spikeText:SetText("")
            end
            -- Alternate row background
            if i % 2 == 0 then
                row.bg:SetColorTexture(1, 1, 1, 0.03)
                row.bg:Show()
            else
                row.bg:Hide()
            end
            row:Show()
        else
            row:Hide()
        end
    end

    -- Resize frame to fit content
    local contentH = TITLE_HEIGHT + HEADER_HEIGHT + (visibleCount * ROW_HEIGHT) + 40 -- 40 for memory + padding
    displayFrame:SetHeight(math.max(contentH, TITLE_HEIGHT + HEADER_HEIGHT + 60))
end

local function BuildDisplayFrame()
    if displayFrame then return end

    -- Main frame
    displayFrame = CreateFrame("Frame", "LunaUITweaks_ProfilerFrame", UIParent)
    displayFrame:SetSize(FRAME_WIDTH, 300)
    displayFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    displayFrame:SetFrameStrata("DIALOG")
    displayFrame:SetMovable(true)
    displayFrame:SetClampedToScreen(true)
    displayFrame:RegisterForDrag("LeftButton")
    displayFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    displayFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Background
    local bg = displayFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.06, 0.08, 0.95)

    -- Border
    local border = displayFrame:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.3, 0.3, 0.35, 1)

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, displayFrame)
    titleBar:SetPoint("TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", -1, -1)
    titleBar:SetHeight(TITLE_HEIGHT)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() displayFrame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() displayFrame:StopMovingOrSizing() end)

    local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints()
    titleBg:SetColorTexture(0.12, 0.12, 0.16, 1)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", 8, 0)
    titleText:SetText("|cFF00FF96LunaUITweaks Profiler|r")

    -- Memory text (right side of title bar)
    memoryText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    memoryText:SetPoint("RIGHT", titleBar, "RIGHT", -80, 0)
    memoryText:SetTextColor(0.7, 0.7, 0.7)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, displayFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function()
        if enabled then
            Profiler.Toggle()
        else
            displayFrame:Hide()
        end
    end)

    -- Pause/Resume button
    pauseBtn = CreateFrame("Button", nil, titleBar, "UIPanelButtonTemplate")
    pauseBtn:SetSize(60, 20)
    pauseBtn:SetPoint("RIGHT", memoryText, "LEFT", -8, 0)
    pauseBtn:SetText("Pause")
    pauseBtn:SetScript("OnClick", function()
        if paused then
            -- Resume
            paused = false
            if enabled and not ticker then
                ticker = C_Timer.NewTicker(REPORT_INTERVAL, UpdateDisplay)
            end
            pauseBtn:SetText("Pause")
        else
            -- Pause
            paused = true
            if ticker then ticker:Cancel() ticker = nil end
            pauseBtn:SetText("Resume")
        end
    end)

    -- Column headers
    headerFrame = CreateFrame("Frame", nil, displayFrame)
    headerFrame:SetPoint("TOPLEFT", displayFrame, "TOPLEFT", PAD, -(TITLE_HEIGHT + 4))
    headerFrame:SetPoint("TOPRIGHT", displayFrame, "TOPRIGHT", -PAD, -(TITLE_HEIGHT + 4))
    headerFrame:SetHeight(HEADER_HEIGHT)

    local hdrSep = headerFrame:CreateTexture(nil, "ARTWORK")
    hdrSep:SetPoint("BOTTOMLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
    hdrSep:SetPoint("BOTTOMRIGHT", headerFrame, "BOTTOMRIGHT", 0, 0)
    hdrSep:SetHeight(1)
    hdrSep:SetColorTexture(0.4, 0.4, 0.4, 0.6)

    local xOff = 0
    local function MakeHeader(text, width)
        local fs = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", headerFrame, "LEFT", xOff, 0)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        fs:SetTextColor(1, 0.82, 0) -- gold
        xOff = xOff + width
        return fs
    end

    MakeHeader("Module", COL_MODULE)
    MakeHeader("Calls", COL_ICALLS)
    MakeHeader("Time", COL_ITIME)
    MakeHeader("Tot Calls", COL_TCALLS)
    MakeHeader("Tot Time", COL_TTIME)
    MakeHeader("Spike", COL_SPIKE)

    -- Row pool
    rowFrames = {}
    local rowAnchorY = -(TITLE_HEIGHT + 4 + HEADER_HEIGHT + 2)
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", nil, displayFrame)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", displayFrame, "TOPLEFT", PAD, rowAnchorY - ((i - 1) * ROW_HEIGHT))
        row:SetPoint("TOPRIGHT", displayFrame, "TOPRIGHT", -PAD, rowAnchorY - ((i - 1) * ROW_HEIGHT))

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:Hide()

        local cx = 0
        local function MakeCell(width)
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", row, "LEFT", cx, 0)
            fs:SetWidth(width)
            fs:SetJustifyH("LEFT")
            cx = cx + width
            return fs
        end

        row.nameText = MakeCell(COL_MODULE)
        row.iCallsText = MakeCell(COL_ICALLS)
        row.iTimeText = MakeCell(COL_ITIME)
        row.tCallsText = MakeCell(COL_TCALLS)
        row.tTimeText = MakeCell(COL_TTIME)
        row.spikeText = MakeCell(COL_SPIKE)

        row:Hide()
        rowFrames[i] = row
    end

    displayFrame:Hide()
end

-- ============================================================
-- Public API
-- ============================================================

function Profiler.Toggle()
    enabled = not enabled
    if enabled then
        -- Swap to timing mode
        strategy.exec = timingExec
        paused = false
        wipe(moduleTimings)
        wipe(totalTimings)
        BuildDisplayFrame()
        pauseBtn:SetText("Pause")
        displayFrame:Show()
        ticker = C_Timer.NewTicker(REPORT_INTERVAL, UpdateDisplay)
        print(("|cFF00FF96LunaUITweaks profiler ON|r — reporting every %ds"):format(REPORT_INTERVAL))
    else
        -- Swap to passthrough
        strategy.exec = passThroughExec
        paused = false
        if ticker then ticker:Cancel() ticker = nil end
        if displayFrame then displayFrame:Hide() end
        print("|cFF00FF96LunaUITweaks profiler OFF|r")
    end
end

function Profiler.IsEnabled()
    return enabled
end
