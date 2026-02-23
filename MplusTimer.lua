local addonName, addonTable = ...
local MplusTimer = {}
addonTable.MplusTimer = MplusTimer

local Log = addonTable.Core.Log
local OnChallengeEvent

-- ============================================================
-- Utility
-- ============================================================
local function FormatTime(seconds)
    if not seconds or seconds < 0 then seconds = 0 end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%d:%02d", m, s)
end

local function FormatTimeSigned(seconds)
    if not seconds then return "" end
    local sign = seconds >= 0 and "+" or "-"
    local abs = math.abs(seconds)
    local m = math.floor(abs / 60)
    local s = math.floor(abs % 60)
    return string.format("%s%d:%02d", sign, m, s)
end

-- ============================================================
-- State
-- ============================================================
local state = {
    inChallenge = false,
    challengeCompleted = false,
    timerStarted = false,
    timer = 0,
    timeLimit = 0,
    timeLimits = {}, -- { +1, +2, +3 }
    level = 0,
    affixes = {},
    affixIds = {},
    hasPeril = false,
    mapId = nil,
    deathCount = 0,
    deathTimeLost = 0, -- milliseconds
    deathLog = {},     -- { [playerName] = count }
    currentCount = 0,
    totalCount = 100,
    objectives = {}, -- { name, time, completed }
    forcesCompleted = false,
    forcesCompletionTime = nil,
    demoMode = false,
    completedOnTime = nil,
    completionTimeMs = nil,
}

local function ResetState()
    state.inChallenge = false
    state.challengeCompleted = false
    state.timerStarted = false
    state.timer = 0
    state.timeLimit = 0
    state.timeLimits = {}
    state.level = 0
    state.affixes = {}
    state.affixIds = {}
    state.hasPeril = false
    state.mapId = nil
    state.deathCount = 0
    state.deathTimeLost = 0
    wipe(state.deathLog)
    state.currentCount = 0
    state.totalCount = 100
    state.objectives = {}
    state.forcesCompleted = false
    state.forcesCompletionTime = nil
    state.completedOnTime = nil
    state.completionTimeMs = nil
end

-- ============================================================
-- Frame Creation
-- ============================================================
local mainFrame
local deathsFrame -- invisible hover frame for death tooltip
local deathsText, timerText, keyText, affixText
local bars = {}   -- bars[1]=+3, bars[2]=+2, bars[3]=+1
local barTexts = {}
local forcesBar, forcesText
local bossTexts = {}
local bossPctTexts = {}
local MAX_BOSSES = 8

local function CreateBar(parent, index)
    local frame = CreateFrame("StatusBar", nil, parent)
    frame:SetMinMaxValues(0, 1)
    frame:SetValue(0)
    frame:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    text:SetPoint("CENTER")

    bars[index] = frame
    barTexts[index] = text
    return frame
end

local function InitFrames()
    if mainFrame then return end

    local settings = UIThingsDB.mplusTimer
    local barWidth = settings.barWidth or 250

    mainFrame = CreateFrame("Frame", "LunaMplusTimer", UIParent, "BackdropTemplate")
    mainFrame:SetSize(barWidth + 20, 300)
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetMovable(true)
    mainFrame:SetClampedToScreen(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        UIThingsDB.mplusTimer.pos = { point = point, x = x, y = y }
    end)
    mainFrame:Hide()

    -- Position
    local pos = settings.pos
    if pos then
        mainFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    else
        mainFrame:SetPoint("CENTER")
    end

    local fontPath = settings.font or "Fonts\\FRIZQT__.TTF"
    local fontSize = settings.fontSize or 12
    local timerFontSize = settings.timerFontSize or 20

    -- Deaths text (top left)
    deathsText = mainFrame:CreateFontString(nil, "OVERLAY")
    deathsText:SetFont(fontPath, fontSize, "OUTLINE")
    deathsText:SetPoint("TOPLEFT", 10, -8)
    deathsText:SetJustifyH("LEFT")

    -- Invisible frame over deaths text for tooltip
    deathsFrame = CreateFrame("Frame", nil, mainFrame)
    deathsFrame:SetPoint("TOPLEFT", deathsText, "TOPLEFT", 0, 0)
    deathsFrame:SetPoint("BOTTOMRIGHT", deathsText, "BOTTOMRIGHT", 0, 0)
    deathsFrame:EnableMouse(true)
    deathsFrame:SetScript("OnEnter", function(self)
        if state.deathCount == 0 or not next(state.deathLog) then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText("Deaths", 1, 0.2, 0.2)
        local penaltySec = math.floor(state.deathTimeLost / 1000)
        GameTooltip:AddLine(string.format("Total: %d (%ds penalty)", state.deathCount, penaltySec), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        -- Sort by death count descending
        local sorted = {}
        for name, count in pairs(state.deathLog) do
            table.insert(sorted, { name = name, count = count })
        end
        table.sort(sorted, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return a.name < b.name
        end)
        for _, entry in ipairs(sorted) do
            local classColor
            -- Try to find class color from group
            for i = 1, GetNumGroupMembers() do
                local unit = IsInRaid() and "raid" .. i or (i == GetNumGroupMembers() and "player" or "party" .. i)
                local name = GetUnitName(unit, false)
                if name == entry.name then
                    local _, className = UnitClass(unit)
                    if className then
                        classColor = C_ClassColor.GetClassColor(className)
                    end
                    break
                end
            end
            if classColor then
                GameTooltip:AddDoubleLine(entry.name, entry.count .. "x", classColor.r, classColor.g, classColor.b, 1, 1,
                    1)
            else
                GameTooltip:AddDoubleLine(entry.name, entry.count .. "x", 1, 1, 1, 1, 1, 1)
            end
        end
        GameTooltip:Show()
    end)
    deathsFrame:SetScript("OnLeave", GameTooltip_Hide)

    -- Timer text (large, right)
    timerText = mainFrame:CreateFontString(nil, "OVERLAY")
    timerText:SetFont(fontPath, timerFontSize, "OUTLINE")
    timerText:SetPoint("TOPRIGHT", -10, -8)
    timerText:SetJustifyH("RIGHT")

    -- Key level text
    local kc = settings.keyColor or { r = 1, g = 0.82, b = 0 }
    keyText = mainFrame:CreateFontString(nil, "OVERLAY")
    keyText:SetFont(fontPath, fontSize, "OUTLINE")
    keyText:SetTextColor(kc.r, kc.g, kc.b)

    -- Affix text
    local ac = settings.affixColor or { r = 0.8, g = 0.8, b = 0.8 }
    affixText = mainFrame:CreateFontString(nil, "OVERLAY")
    affixText:SetFont(fontPath, fontSize - 1, "OUTLINE")
    affixText:SetTextColor(ac.r, ac.g, ac.b)

    -- Key + Affix positioned below timer
    keyText:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -32)
    affixText:SetPoint("LEFT", keyText, "RIGHT", 4, 0)

    -- Timer bars (+3, +2, +1) — positioned below key details
    local barHeight = settings.barHeight or 8
    local barY = -50
    local b3c = settings.barPlusThreeColor or { r = 0.2, g = 0.8, b = 0.2 }
    local b2c = settings.barPlusTwoColor or { r = 0.9, g = 0.9, b = 0.2 }
    local b1c = settings.barPlusOneColor or { r = 0.9, g = 0.3, b = 0.2 }

    -- +3 bar (60% width)
    local b3 = CreateBar(mainFrame, 1)
    b3:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, barY)
    b3:SetSize(barWidth * 0.6, barHeight)
    b3:SetStatusBarColor(b3c.r, b3c.g, b3c.b)

    -- +2 bar (20% width)
    local b2 = CreateBar(mainFrame, 2)
    b2:SetPoint("LEFT", b3, "RIGHT", 1, 0)
    b2:SetSize(barWidth * 0.2, barHeight)
    b2:SetStatusBarColor(b2c.r, b2c.g, b2c.b)

    -- +1 bar (20% width)
    local b1 = CreateBar(mainFrame, 3)
    b1:SetPoint("LEFT", b2, "RIGHT", 1, 0)
    b1:SetSize(barWidth * 0.2, barHeight)
    b1:SetStatusBarColor(b1c.r, b1c.g, b1c.b)

    -- Bar time labels (below bars)
    for i = 1, 3 do
        barTexts[i]:SetFont(fontPath, fontSize - 2, "OUTLINE")
        barTexts[i]:SetTextColor(1, 1, 1)
    end

    -- Forces bar
    local fc = settings.forcesBarColor or { r = 0.4, g = 0.6, b = 1.0 }
    forcesBar = CreateFrame("StatusBar", nil, mainFrame)
    forcesBar:SetMinMaxValues(0, 1)
    forcesBar:SetValue(0)
    forcesBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    forcesBar:SetStatusBarColor(fc.r, fc.g, fc.b)
    forcesBar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, barY - barHeight - 6)
    forcesBar:SetSize(barWidth, barHeight)

    local forcesBg = forcesBar:CreateTexture(nil, "BACKGROUND")
    forcesBg:SetAllPoints()
    forcesBg:SetColorTexture(0, 0, 0, 0.5)

    forcesText = forcesBar:CreateFontString(nil, "OVERLAY")
    forcesText:SetFont(fontPath, fontSize - 1, "OUTLINE")
    forcesText:SetPoint("CENTER")
    forcesText:SetTextColor(0.4, 0.8, 1.0)

    -- Boss objective texts
    for i = 1, MAX_BOSSES do
        local bt = mainFrame:CreateFontString(nil, "OVERLAY")
        bt:SetFont(fontPath, fontSize, "OUTLINE")
        bt:SetJustifyH("LEFT")
        bt:SetTextColor(1, 1, 1)
        bossTexts[i] = bt

        local bpt = mainFrame:CreateFontString(nil, "OVERLAY")
        bpt:SetFont(fontPath, fontSize, "OUTLINE")
        bpt:SetJustifyH("RIGHT")
        bpt:SetTextColor(1, 1, 1)
        bossPctTexts[i] = bpt
    end
end

-- ============================================================
-- Rendering
-- ============================================================
local function ApplyLayout()
    if not mainFrame then return end
    local settings = UIThingsDB.mplusTimer
    local fontPath = settings.font or "Fonts\\FRIZQT__.TTF"
    local fontSize = settings.fontSize or 12
    local timerFontSize = settings.timerFontSize or 20
    local barWidth = settings.barWidth or 250
    local barHeight = settings.barHeight or 8

    mainFrame:SetWidth(barWidth + 20)

    deathsText:SetFont(fontPath, fontSize, "OUTLINE")
    timerText:SetFont(fontPath, timerFontSize, "OUTLINE")
    keyText:SetFont(fontPath, fontSize, "OUTLINE")
    affixText:SetFont(fontPath, fontSize - 1, "OUTLINE")
    forcesText:SetFont(fontPath, fontSize - 1, "OUTLINE")

    -- Apply text colors from settings
    local kc = settings.keyColor or { r = 1, g = 0.82, b = 0 }
    keyText:SetTextColor(kc.r, kc.g, kc.b)
    local ac = settings.affixColor or { r = 0.8, g = 0.8, b = 0.8 }
    affixText:SetTextColor(ac.r, ac.g, ac.b)

    -- Apply bar colors from settings
    local b3c = settings.barPlusThreeColor or { r = 0.2, g = 0.8, b = 0.2 }
    local b2c = settings.barPlusTwoColor or { r = 0.9, g = 0.9, b = 0.2 }
    local b1c = settings.barPlusOneColor or { r = 0.9, g = 0.3, b = 0.2 }
    bars[1]:SetStatusBarColor(b3c.r, b3c.g, b3c.b)
    bars[2]:SetStatusBarColor(b2c.r, b2c.g, b2c.b)
    bars[3]:SetStatusBarColor(b1c.r, b1c.g, b1c.b)

    -- Apply forces bar color
    local fc = settings.forcesBarColor or { r = 0.4, g = 0.6, b = 1.0 }
    forcesBar:SetStatusBarColor(fc.r, fc.g, fc.b)

    -- Reposition bars
    local barY = -50
    local fractions = { 0.6, 0.2, 0.2 }

    -- Calculate bar fractions: bars[1]=+3 (left), bars[2]=+2, bars[3]=+1 (right)
    -- timeLimits[1]=+1 (full), timeLimits[2]=+2 (80%), timeLimits[3]=+3 (60%)
    if state.timeLimit > 0 and #state.timeLimits == 3 then
        fractions[1] = state.timeLimits[3] / state.timeLimit                         -- +3 segment
        fractions[2] = (state.timeLimits[2] - state.timeLimits[3]) / state.timeLimit -- +2 segment
        fractions[3] = (state.timeLimits[1] - state.timeLimits[2]) / state.timeLimit -- +1 segment
    end

    bars[1]:ClearAllPoints()
    bars[1]:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, barY)
    bars[1]:SetSize(barWidth * fractions[1], barHeight)

    bars[2]:ClearAllPoints()
    bars[2]:SetPoint("LEFT", bars[1], "RIGHT", 1, 0)
    bars[2]:SetSize(barWidth * fractions[2], barHeight)

    bars[3]:ClearAllPoints()
    bars[3]:SetPoint("LEFT", bars[2], "RIGHT", 1, 0)
    bars[3]:SetSize(barWidth * fractions[3], barHeight)

    for i = 1, 3 do
        barTexts[i]:SetFont(fontPath, fontSize - 2, "OUTLINE")
    end

    forcesBar:ClearAllPoints()
    forcesBar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, barY - barHeight - 6)
    forcesBar:SetSize(barWidth, barHeight)

    -- Boss texts positioning
    local bossY = barY - barHeight - 6 - barHeight - 8
    for i = 1, MAX_BOSSES do
        bossTexts[i]:ClearAllPoints()
        bossTexts[i]:SetFont(fontPath, fontSize, "OUTLINE")
        bossTexts[i]:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, bossY - ((i - 1) * (fontSize + 4)))

        bossPctTexts[i]:ClearAllPoints()
        bossPctTexts[i]:SetFont(fontPath, fontSize, "OUTLINE")
        bossPctTexts[i]:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -10, bossY - ((i - 1) * (fontSize + 4)))
    end

    -- Calculate total frame height
    local bossCount = #state.objectives
    if bossCount < 1 then bossCount = 1 end
    local totalHeight = math.abs(bossY) + (bossCount * (fontSize + 4)) + 10
    mainFrame:SetHeight(totalHeight)

    -- Lock/unlock
    local borderSize = settings.borderSize or 1
    if settings.locked then
        mainFrame:EnableMouse(false)
    else
        mainFrame:EnableMouse(true)
    end

    -- Apply backdrop with background and border
    if state.inChallenge or state.demoMode or not settings.locked then
        local backdrop = {
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        }
        if borderSize > 0 then
            backdrop.edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border"
            backdrop.tile = true
            backdrop.tileSize = 16
            backdrop.edgeSize = math.max(borderSize * 4, 8)
            backdrop.insets = { left = 2, right = 2, top = 2, bottom = 2 }
        end
        mainFrame:SetBackdrop(backdrop)
        local bg = settings.bgColor
        mainFrame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
        if borderSize > 0 then
            local bc = settings.borderColor
            mainFrame:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
        end
    else
        mainFrame:SetBackdrop(nil)
    end

    -- Position
    mainFrame:ClearAllPoints()
    local pos = settings.pos
    if pos then
        mainFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    else
        mainFrame:SetPoint("CENTER")
    end
end

local function RenderTimer()
    if not mainFrame then return end

    local settings = UIThingsDB.mplusTimer
    local elapsed = state.timer
    local limit = state.timeLimit
    local tc = settings.timerColor or { r = 1, g = 1, b = 1 }
    local twc = settings.timerWarningColor or { r = 1, g = 1, b = 0.2 }
    local tdc = settings.timerDepletedColor or { r = 1, g = 0.2, b = 0.2 }
    local tsc = settings.timerSuccessColor or { r = 0.2, g = 1, b = 0.2 }

    -- Timer text: countdown from limit, goes positive after depletion
    local timerStr
    if state.challengeCompleted then
        local completionSec = (state.completionTimeMs or 0) / 1000
        local remaining = limit - completionSec
        timerStr = FormatTimeSigned(remaining)
        if state.completedOnTime then
            timerText:SetTextColor(tsc.r, tsc.g, tsc.b)
        else
            timerText:SetTextColor(tdc.r, tdc.g, tdc.b)
        end
    else
        local remaining = limit - elapsed
        if remaining >= 0 then
            timerStr = "-" .. FormatTime(remaining)
        else
            timerStr = "+" .. FormatTime(math.abs(remaining))
        end
        if elapsed > limit then
            timerText:SetTextColor(tdc.r, tdc.g, tdc.b)
        elseif limit > 0 and remaining < 120 then
            timerText:SetTextColor(twc.r, twc.g, twc.b)
        else
            timerText:SetTextColor(tc.r, tc.g, tc.b)
        end
    end
    timerText:SetText(timerStr)

    -- Update progress bars
    -- bars[1]=+3 (left), bars[2]=+2 (middle), bars[3]=+1 (right)
    -- timeLimits[1]=+1 (full), timeLimits[2]=+2 (80%), timeLimits[3]=+3 (60%)
    -- Map: bar 1 -> timeLimits[3], bar 2 -> timeLimits[2], bar 3 -> timeLimits[1]
    local limitMap = { 3, 2, 1 }
    for i = 1, 3 do
        local li = limitMap[i]
        local barLimit = state.timeLimits[li] or 1
        local prevLimit = state.timeLimits[li + 1] or 0 -- lower tier boundary (0 for +3)
        if li == 3 then prevLimit = 0 end
        local timeRemaining = barLimit - elapsed
        local barMax = barLimit - prevLimit
        local barElapsed = elapsed - prevLimit
        local barValue = math.max(0, math.min(barElapsed / barMax, 1.0))

        bars[i]:SetValue(barValue)

        local absRemaining = math.abs(timeRemaining)
        local timeStr = FormatTime(absRemaining)

        if timeRemaining < 0 then
            if i == 3 then
                barTexts[i]:SetText("|cFFFF3333-" .. timeStr .. "|r")
            else
                barTexts[i]:SetText("")
            end
        else
            barTexts[i]:SetText(timeStr)
        end
    end
end

local function RenderDeaths()
    if not mainFrame then return end
    if not UIThingsDB.mplusTimer.showDeaths then
        deathsText:SetText("")
        return
    end

    if state.deathCount > 0 then
        local dc = UIThingsDB.mplusTimer.deathColor or { r = 1, g = 0.2, b = 0.2 }
        local penaltySec = math.floor(state.deathTimeLost / 1000)
        local hex = string.format("%02X%02X%02X", dc.r * 255, dc.g * 255, dc.b * 255)
        deathsText:SetText(string.format("|cFF%s%d Death%s (+%ds)|r",
            hex,
            state.deathCount,
            state.deathCount == 1 and "" or "s",
            penaltySec))
    else
        deathsText:SetText("")
    end
end

local function RenderKeyDetails()
    if not mainFrame then return end
    keyText:SetText(string.format("[%d]", state.level))

    if UIThingsDB.mplusTimer.showAffixes and #state.affixes > 0 then
        affixText:SetText(table.concat(state.affixes, " - "))
    else
        affixText:SetText("")
    end
end

local function RenderForces()
    if not mainFrame then return end
    if not UIThingsDB.mplusTimer.showForces then
        forcesBar:Hide()
        forcesText:SetText("")
        return
    end
    forcesBar:Show()

    local percent = state.totalCount > 0 and state.currentCount / state.totalCount or 0
    percent = math.min(percent, 1.0)
    forcesBar:SetValue(percent)

    local displayPercent = percent * 100
    local completionStr = ""
    if state.forcesCompletionTime then
        completionStr = string.format(" [%s]", FormatTime(state.forcesCompletionTime))
    end

    local ftc = UIThingsDB.mplusTimer.forcesTextColor or { r = 0.4, g = 0.8, b = 1.0 }
    local fcc = UIThingsDB.mplusTimer.forcesCompleteColor or { r = 0.2, g = 1, b = 0.2 }
    if state.forcesCompleted then
        local hex = string.format("%02X%02X%02X", fcc.r * 255, fcc.g * 255, fcc.b * 255)
        forcesText:SetText(string.format("|cFF%s%s %d/%d - %.2f%%|r",
            hex,
            FormatTime(state.forcesCompletionTime or state.timer),
            state.currentCount, state.totalCount, displayPercent))
        forcesText:SetTextColor(fcc.r, fcc.g, fcc.b)
    else
        forcesText:SetText(string.format("%s %d/%d - %.2f%%",
            FormatTime(state.timer), state.currentCount, state.totalCount, displayPercent))
        forcesText:SetTextColor(ftc.r, ftc.g, ftc.b)
    end
end

-- Returns par time (seconds) for boss index i out of n total bosses,
-- targeting the +2 chest time split evenly across all bosses.
local function GetParTime(i, n)
    if n <= 0 or state.timeLimit <= 0 then return nil end
    local target = #state.timeLimits >= 2 and state.timeLimits[2] or state.timeLimit * 0.8
    return (target / n) * i
end

local function RenderObjectives()
    if not mainFrame then return end

    -- Hide all first
    for i = 1, MAX_BOSSES do
        bossTexts[i]:SetText("")
        bossPctTexts[i]:SetText("")
    end

    if not UIThingsDB.mplusTimer.showBosses then return end

    local bcc = UIThingsDB.mplusTimer.bossCompleteColor or { r = 0, g = 1, b = 0 }
    local bic = UIThingsDB.mplusTimer.bossIncompleteColor or { r = 1, g = 1, b = 1 }
    local bccHex = string.format("%02X%02X%02X", bcc.r * 255, bcc.g * 255, bcc.b * 255)
    local bicHex = string.format("%02X%02X%02X", bic.r * 255, bic.g * 255, bic.b * 255)

    local n = #state.objectives
    local showSplits = UIThingsDB.mplusTimer.showSplits
    local showBossForcePct = UIThingsDB.mplusTimer.showBossForcePct

    local history = state.mapId and UIThingsDB.mplusTimer.runHistory
        and UIThingsDB.mplusTimer.runHistory[state.mapId]

    for i, boss in ipairs(state.objectives) do
        if i > MAX_BOSSES then break end
        local text

        if boss.time then
            -- Completed boss: show split delta vs par
            local timeStr = FormatTime(boss.time)
            local splitStr = ""
            if showSplits then
                local prevTime = history and history.bosses
                    and history.bosses[i] and history.bosses[i].time
                if prevTime then
                    local delta = boss.time - prevTime
                    local deltaHex = delta < 0 and "FFDD00" or (delta > 0 and "FF4444" or "00DD00")
                    splitStr = string.format(" |cFF%s%s|r", deltaHex, FormatTimeSigned(delta))
                end
            end
            text = string.format("|cFF%s[%s]|r |cFF%s%s|r%s",
                bccHex, timeStr, bccHex, boss.name, splitStr)

            -- Right-aligned forces % with run-to-run delta
            if showBossForcePct and boss.forcePct then
                if boss.forcePct >= 100 then
                    bossPctTexts[i]:SetText(string.format("|cFF00DD00%.1f%%|r", boss.forcePct))
                else
                    local prevRunPct = history and history.bosses
                        and history.bosses[i] and history.bosses[i].forcePct
                    if prevRunPct then
                        local delta = boss.forcePct - prevRunPct
                        local pctHex = delta > 0 and "FFDD00" or (delta < 0 and "FF4444" or "00DD00")
                        local deltaSign = delta > 0 and "+" or ""
                        bossPctTexts[i]:SetText(string.format("|cFF%s%.1f%% (%s%.1f%%)|r",
                            pctHex, boss.forcePct, deltaSign, delta))
                    else
                        bossPctTexts[i]:SetText(string.format("|cFFAAAAAA%.1f%%|r", boss.forcePct))
                    end
                end
            end
        else
            text = string.format("|cFF%s%s|r", bicHex, boss.name)
        end

        bossTexts[i]:SetText(text)
    end

    -- Resize frame based on boss count
    ApplyLayout()
end

-- ============================================================
-- Data Loading
-- ============================================================
local function LoadKeyDetails()
    local mapId = C_ChallengeMode.GetActiveChallengeMapID()
    if not mapId then return end
    state.mapId = mapId

    local level, affixes = C_ChallengeMode.GetActiveKeystoneInfo()
    if not level or level <= 0 then return end
    state.level = level

    state.hasPeril = false
    state.affixes = {}
    state.affixIds = {}
    for i, affixID in ipairs(affixes) do
        local name = C_ChallengeMode.GetAffixInfo(affixID)
        state.affixes[i] = name or ("Affix " .. affixID)
        state.affixIds[i] = affixID
        if affixID == 152 then
            state.hasPeril = true
        end
    end

    local timeLimit = select(3, C_ChallengeMode.GetMapUIInfo(mapId))
    if timeLimit and timeLimit > 0 then
        state.timeLimit = timeLimit
        if state.hasPeril then
            local base = timeLimit - 90
            state.timeLimits = { timeLimit, base * 0.8 + 90, base * 0.6 + 90 }
        else
            state.timeLimits = { timeLimit, timeLimit * 0.8, timeLimit * 0.6 }
        end
    end

    RenderKeyDetails()
    ApplyLayout()
end

local function UpdateObjectives()
    local stepCount = select(3, C_Scenario.GetStepInfo())
    if not stepCount or stepCount <= 0 then return end

    for i = 1, stepCount do
        local info = C_ScenarioInfo.GetCriteriaInfo(i)
        if info then
            if info.isWeightedProgress then
                -- Forces criteria
                local currentCount = info.quantityString and tonumber(info.quantityString:match("%d+")) or 0
                if currentCount > state.currentCount then
                    state.currentCount = currentCount
                end
                if info.totalQuantity and info.totalQuantity > 0 then
                    state.totalCount = info.totalQuantity
                end
                if currentCount >= (info.totalQuantity or 100) then
                    if not state.forcesCompleted then
                        state.forcesCompleted = true
                        state.forcesCompletionTime = select(2, GetWorldElapsedTime(1)) - (info.elapsed or 0)
                    end
                end
            else
                -- Boss objective
                local name = info.description or ("Boss " .. i)
                -- Clean up description to just the name
                name = name:gsub("%s*%- defeated.*", ""):gsub("%s*%- defeated", "")

                if not state.objectives[i] or state.objectives[i].name ~= name then
                    state.objectives[i] = { name = name, time = nil }
                end

                if info.completed and not state.objectives[i].time then
                    state.objectives[i].time = select(2, GetWorldElapsedTime(1)) - (info.elapsed or 0)
                    -- Snapshot forces % at the moment this boss was killed
                    local pct = state.totalCount > 0 and (state.currentCount / state.totalCount * 100) or 0
                    state.objectives[i].forcePct = pct
                end
            end
        end
    end

    -- Remove extra objectives if step count decreased
    for i = stepCount + 1, #state.objectives do
        state.objectives[i] = nil
    end

    RenderForces()
    RenderObjectives()
end

-- ============================================================
-- Timer Loop
-- ============================================================
local timerRunning = false
local sinceLastUpdate = 0

local function OnTimerTick(self, elapsed)
    sinceLastUpdate = sinceLastUpdate + elapsed
    if sinceLastUpdate < 0.1 then return end
    sinceLastUpdate = 0

    if state.challengeCompleted then return end

    state.timer = select(2, GetWorldElapsedTime(1))

    if state.timer > 0 and not state.timerStarted then
        state.timerStarted = true
        RenderForces()
        RenderObjectives()
    end

    RenderTimer()
end

local function StartTimerLoop()
    if timerRunning then return end
    timerRunning = true
    sinceLastUpdate = 0
    mainFrame:SetScript("OnUpdate", OnTimerTick)
end

local function StopTimerLoop()
    timerRunning = false
    sinceLastUpdate = 0
    if mainFrame then
        mainFrame:SetScript("OnUpdate", nil)
    end
end

-- ============================================================
-- Challenge Mode Management
-- ============================================================
-- Bridge: OnChallengeEvent uses (self, event, ...) but EventBus uses (event, ...)
local function OnChallengeEventBus(event, ...) OnChallengeEvent(nil, event, ...) end

local function RegisterChallengeEvents()
    addonTable.EventBus.Register("CHALLENGE_MODE_COMPLETED", OnChallengeEventBus)
    addonTable.EventBus.Register("CHALLENGE_MODE_DEATH_COUNT_UPDATED", OnChallengeEventBus)
    addonTable.EventBus.Register("WORLD_STATE_TIMER_START", OnChallengeEventBus)
    addonTable.EventBus.Register("SCENARIO_POI_UPDATE", OnChallengeEventBus)
    addonTable.EventBus.Register("SCENARIO_CRITERIA_UPDATE", OnChallengeEventBus)
    addonTable.EventBus.Register("ENCOUNTER_END", OnChallengeEventBus)
end

local function UnregisterChallengeEvents()
    addonTable.EventBus.Unregister("CHALLENGE_MODE_COMPLETED", OnChallengeEventBus)
    addonTable.EventBus.Unregister("CHALLENGE_MODE_DEATH_COUNT_UPDATED", OnChallengeEventBus)
    addonTable.EventBus.Unregister("WORLD_STATE_TIMER_START", OnChallengeEventBus)
    addonTable.EventBus.Unregister("SCENARIO_POI_UPDATE", OnChallengeEventBus)
    addonTable.EventBus.Unregister("SCENARIO_CRITERIA_UPDATE", OnChallengeEventBus)
    addonTable.EventBus.Unregister("ENCOUNTER_END", OnChallengeEventBus)
end

local function EnableChallengeMode()
    if state.demoMode then
        state.demoMode = false
    end

    ResetState()
    state.inChallenge = true

    LoadKeyDetails()

    local deathCount, timeLost = C_ChallengeMode.GetDeathCount()
    state.deathCount = deathCount or 0
    state.deathTimeLost = timeLost or 0

    UpdateObjectives()
    RenderDeaths()
    ApplyLayout()

    mainFrame:Show()
    RegisterChallengeEvents()
    StartTimerLoop()
end

local function DisableChallengeMode()
    StopTimerLoop()
    UnregisterChallengeEvents()
    ResetState()
    if mainFrame and not state.demoMode then
        mainFrame:Hide()
    end
end

local function CompleteChallenge()
    StopTimerLoop()
    state.challengeCompleted = true

    local info = C_ChallengeMode.GetChallengeCompletionInfo()
    if info then
        state.completedOnTime = info.onTime
        state.completionTimeMs = info.time
    end

    -- Complete any objectives that didn't get a time
    for _, objective in pairs(state.objectives) do
        if not objective.time then
            objective.time = state.timer
        end
    end

    if not state.forcesCompletionTime then
        state.forcesCompleted = true
        state.currentCount = state.totalCount
        state.forcesCompletionTime = state.timer
    end

    -- Save boss force % snapshots only when the run completed at 100% forces
    if state.forcesCompleted and state.mapId then
        local db = UIThingsDB.mplusTimer
        db.runHistory = db.runHistory or {}
        db.runHistory[state.mapId] = db.runHistory[state.mapId] or {}
        local entry = {
            level = state.level,
            time = state.completionTimeMs and math.floor(state.completionTimeMs / 1000) or state.timer,
            onTime = state.completedOnTime,
            bosses = {},
        }
        for i, obj in ipairs(state.objectives) do
            entry.bosses[i] = {
                name = obj.name,
                forcePct = obj.forcePct,
                time = obj.time,
            }
        end
        -- Keep only the most recent run per map
        db.runHistory[state.mapId] = entry
    end

    RenderTimer()
    RenderForces()
    RenderObjectives()
    RenderDeaths()
end

local function CheckForChallengeMode()
    if not UIThingsDB.mplusTimer or not UIThingsDB.mplusTimer.enabled then return end

    local _, instanceType, difficultyID = GetInstanceInfo()
    local inChallenge = (difficultyID == 8 and instanceType == "party")

    if inChallenge and not state.inChallenge then
        EnableChallengeMode()
    elseif not inChallenge and state.inChallenge and not state.demoMode then
        DisableChallengeMode()
    end
end

-- ============================================================
-- Event Handling
-- ============================================================
OnChallengeEvent = function(self, event, ...)
    if not state.inChallenge and not state.demoMode then return end

    if event == "CHALLENGE_MODE_COMPLETED" then
        CompleteChallenge()
    elseif event == "CHALLENGE_MODE_DEATH_COUNT_UPDATED" then
        local deathCount, timeLost = C_ChallengeMode.GetDeathCount()
        local prevCount = state.deathCount
        state.deathCount = deathCount or 0
        state.deathTimeLost = timeLost or 0
        -- If death count increased, scan for who is dead
        if state.deathCount > prevCount then
            local members = GetNumGroupMembers()
            for i = 1, members do
                local unit = "party" .. i
                if i == members then unit = "player" end
                local name = GetUnitName(unit, false)
                if name and UnitIsDeadOrGhost(unit) then
                    state.deathLog[name] = (state.deathLog[name] or 0) + 1
                end
            end
        end
        RenderDeaths()
    elseif event == "WORLD_STATE_TIMER_START" then
        state.timerStarted = true
        RenderTimer()
        RenderForces()
        RenderObjectives()
    elseif event == "SCENARIO_POI_UPDATE" or event == "SCENARIO_CRITERIA_UPDATE" then
        UpdateObjectives()
    elseif event == "ENCOUNTER_END" then
        -- Boss defeated, update objectives
        UpdateObjectives()
    end
end

local function OnGlobalEvent(event, ...)
    if not UIThingsDB.mplusTimer or not UIThingsDB.mplusTimer.enabled then return end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        CheckForChallengeMode()
    elseif event == "CHALLENGE_MODE_START" then
        EnableChallengeMode()
    end
end

-- ============================================================
-- Demo Mode
-- ============================================================
function MplusTimer.CloseDemo()
    if not state.demoMode then return end
    state.demoMode = false
    StopTimerLoop()
    -- Remove the seeded demo history so it doesn't persist in saved variables
    local db = UIThingsDB.mplusTimer
    if db and db.runHistory then db.runHistory["demo"] = nil end
    ResetState()
    if mainFrame then mainFrame:Hide() end
end

function MplusTimer.ToggleDemo()
    if not mainFrame then InitFrames() end

    if state.demoMode then
        MplusTimer.CloseDemo()
        return
    end

    -- Don't activate demo during an active M+ run
    if state.inChallenge then return end

    -- Enable demo
    ResetState()
    state.demoMode = true
    state.inChallenge = true
    state.timerStarted = true
    state.timer = 1200     -- 20:00 elapsed -> countdown shows -15:00
    state.timeLimit = 2100 -- 35:00
    state.timeLimits = { 2100, 1680, 1260 }
    state.level = 30
    state.affixes = { "Ascendance", "Tyrannical", "Fortified", "Peril" }
    state.deathCount = 3
    state.deathTimeLost = 45000 -- 45s in ms
    wipe(state.deathLog)
    state.deathLog["DemoTank"] = 1
    state.deathLog["DemoHealer"] = 2
    state.mapId = "demo"
    state.currentCount = 0
    state.totalCount = 100
    -- Seed a previous run to compare against (simulates a prior completed key on this map)
    local db = UIThingsDB.mplusTimer
    db.runHistory = db.runHistory or {}
    db.runHistory["demo"] = {
        level = 29,
        bosses = {
            { name = "Test Boss Name 1", forcePct = 16.7, time = 490  }, -- prev: 8:10
            { name = "Test Boss Name 2", forcePct = 44.3, time = 1080 }, -- prev: 18:00
            { name = "Test Boss Name 3", forcePct = 74.5, time = 1620 }, -- prev: 27:00
            { name = "Test Boss Name 4", forcePct = 100.0, time = 2100 },
        },
    }
    state.objectives = {
        { name = "Test Boss Name 1", time = 520,  forcePct = 14.2 }, -- split: +0:30 (red), forces: -2.5% (red)
        { name = "Test Boss Name 2", time = 1040, forcePct = 47.8 }, -- split: -0:40 (yellow), forces: +3.5% (yellow)
        { name = "Test Boss Name 3", time = 1560, forcePct = 74.0 }, -- split: -1:00 (yellow), forces: -0.5% (red)
        { name = "Test Boss Name 4", time = nil },
        { name = "Test Boss Name 5", time = nil },
    }

    RenderTimer()
    RenderDeaths()
    RenderKeyDetails()
    RenderForces()
    RenderObjectives()
    ApplyLayout()
    mainFrame:Show()
end

-- ============================================================
-- Settings / Public API
-- ============================================================
function MplusTimer.UpdateSettings()
    if not mainFrame then return end

    ApplyLayout()

    if not UIThingsDB.mplusTimer.enabled then
        StopTimerLoop()
        mainFrame:Hide()
        return
    end

    -- If currently in a challenge, re-render everything
    if state.inChallenge or state.demoMode then
        RenderTimer()
        RenderDeaths()
        RenderKeyDetails()
        RenderForces()
        RenderObjectives()
    end
end

-- ============================================================
-- Initialization
-- ============================================================
local globalEventsRegistered = false

local function RegisterGlobalEvents()
    if globalEventsRegistered then return end
    globalEventsRegistered = true
    addonTable.EventBus.Register("PLAYER_ENTERING_WORLD", OnGlobalEvent)
    addonTable.EventBus.Register("ZONE_CHANGED_NEW_AREA", OnGlobalEvent)
    addonTable.EventBus.Register("CHALLENGE_MODE_START", OnGlobalEvent)
end

local function OnPlayerLogin()
    addonTable.EventBus.Unregister("PLAYER_LOGIN", OnPlayerLogin)

    C_Timer.After(1, function()
        if not UIThingsDB.mplusTimer or not UIThingsDB.mplusTimer.enabled then return end
        InitFrames()
        RegisterGlobalEvents()
        CheckForChallengeMode()
    end)
end
addonTable.EventBus.Register("PLAYER_LOGIN", OnPlayerLogin)

-- Ensure frames are created even if enabled later via config
function MplusTimer.EnsureInit()
    InitFrames()
    RegisterGlobalEvents()
    CheckForChallengeMode()
end

-- ============================================================
-- Auto-Slot Keystone (always active, independent of timer)
-- ============================================================
addonTable.EventBus.Register("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN", function()
    if not UIThingsDB or not UIThingsDB.mplusTimer or not UIThingsDB.mplusTimer.autoSlotKeystone then return end

    local difficulty = select(3, GetInstanceInfo())
    if difficulty ~= 8 and difficulty ~= 23 then return end

    for bagIndex = 0, NUM_BAG_SLOTS do
        for slotIndex = 1, C_Container.GetContainerNumSlots(bagIndex) do
            local itemID = C_Container.GetContainerItemID(bagIndex, slotIndex)
            if itemID and C_Item.IsItemKeystoneByID(itemID) then
                C_Container.UseContainerItem(bagIndex, slotIndex)
                return
            end
        end
    end
end)
