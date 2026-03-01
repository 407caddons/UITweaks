local addonName, addonTable = ...
addonTable.QueueTimer = {}

local EventBus = addonTable.EventBus

local timerBar
local timerBg
local timerFill
local timerText

local totalTime   = 40
local timeRemaining = 0
local isRunning   = false

-- Try to read the actual proposal time from the LFG API.
-- In 12.0 the return order is: exists, id, dungeonID, state, name, expirationTime, role
-- expirationTime is a GetTime()-based absolute timestamp, not a duration.
local function GetProposalTimeLeft()
    if not GetLFGProposal then return 40 end
    local exists, _, _, _, _, expirationTime = GetLFGProposal()
    if exists and type(expirationTime) == "number" and expirationTime > 0 then
        local remaining = math.ceil(expirationTime - GetTime())
        if remaining > 0 and remaining <= 300 then
            return remaining
        end
    end
    return 40
end

local function StopTimer()
    isRunning = false
    if timerBar then timerBar:Hide() end
end

local function StartTimer()
    if not UIThingsDB.queueTimer or not UIThingsDB.queueTimer.enabled then return end

    totalTime     = GetProposalTimeLeft()
    timeRemaining = totalTime
    isRunning     = true

    local settings = UIThingsDB.queueTimer
    timerBar:SetSize(settings.width, settings.height)

    -- Attach below the LFG proposal dialog if it is visible; otherwise fall back
    timerBar:ClearAllPoints()
    local dialog = _G["LFGDungeonReadyDialog"]
    if dialog and dialog:IsShown() then
        timerBar:SetPoint("TOP", dialog, "BOTTOM", 0, -6)
    else
        local pos = settings.pos
        timerBar:SetPoint("CENTER", UIParent, "CENTER", pos.x, pos.y)
    end

    -- Reset fill to full width
    local barW = settings.width - 2
    timerFill:ClearAllPoints()
    timerFill:SetPoint("TOPLEFT",   timerBar, "TOPLEFT",   1, -1)
    timerFill:SetPoint("BOTTOMLEFT", timerBar, "BOTTOMLEFT", 1, 1)
    timerFill:SetWidth(math.max(1, barW))

    -- Apply initial colors
    local bg = settings.bgColor
    timerBg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
    if settings.dynamicColor then
        timerFill:SetColorTexture(0.2, 0.9, 0.2, 1)
    else
        local c = settings.barColor
        timerFill:SetColorTexture(c.r, c.g, c.b, c.a)
    end

    if settings.showText then
        timerText:SetText(string.format("%ds", totalTime))
        timerText:Show()
    else
        timerText:Hide()
    end

    timerBar:Show()
end

local function OnProposalShow()
    -- Small delay so the Blizzard dialog is visible before we anchor to it
    C_Timer.After(0.05, StartTimer)
end

local function OnUpdate(self, elapsed)
    if not isRunning then return end

    timeRemaining = timeRemaining - elapsed
    if timeRemaining <= 0 then
        StopTimer()
        return
    end

    local frac  = timeRemaining / totalTime
    local barW  = (UIThingsDB.queueTimer.width or 280) - 2
    timerFill:SetWidth(math.max(1, frac * barW))

    if UIThingsDB.queueTimer.dynamicColor then
        -- Green -> yellow -> red
        local r = math.min(1, 2 * (1 - frac))
        local g = math.min(1, 2 * frac)
        timerFill:SetColorTexture(r, g, 0, 1)
    end

    if UIThingsDB.queueTimer.showText then
        timerText:SetText(string.format("%ds", math.ceil(timeRemaining)))
    end
end

function addonTable.QueueTimer.UpdateSettings()
    if not timerBar then return end
    local settings = UIThingsDB.queueTimer
    if not settings.enabled then
        StopTimer()
        return
    end
    timerBar:SetSize(settings.width, settings.height)
end

local function Init()
    timerBar = CreateFrame("Frame", "LunaUITweaks_QueueTimer", UIParent)
    timerBar:SetFrameStrata("DIALOG")
    timerBar:SetClampedToScreen(true)
    timerBar:Hide()

    timerBg = timerBar:CreateTexture(nil, "BACKGROUND")
    timerBg:SetAllPoints()
    timerBg:SetColorTexture(0, 0, 0, 0.8)

    timerFill = timerBar:CreateTexture(nil, "ARTWORK")
    timerFill:SetPoint("TOPLEFT",    timerBar, "TOPLEFT",    1, -1)
    timerFill:SetPoint("BOTTOMLEFT", timerBar, "BOTTOMLEFT", 1,  1)
    timerFill:SetColorTexture(0.2, 0.9, 0.2, 1)

    timerText = timerBar:CreateFontString(nil, "OVERLAY")
    timerText:SetPoint("CENTER")
    timerText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    timerText:SetTextColor(1, 1, 1, 1)

    timerBar:SetScript("OnUpdate", OnUpdate)

    EventBus.Register("LFG_PROPOSAL_SHOW",      OnProposalShow)
    EventBus.Register("LFG_PROPOSAL_FAILED",    StopTimer)
    EventBus.Register("LFG_PROPOSAL_SUCCEEDED", StopTimer)
    EventBus.Register("PLAYER_ENTERING_WORLD", function()
        local inInstance = select(1, IsInInstance())
        if inInstance then StopTimer() end
    end)

    addonTable.QueueTimer.UpdateSettings()
end

EventBus.Register("PLAYER_LOGIN", function()
    addonTable.Core.SafeAfter(0.5, Init)
end)
