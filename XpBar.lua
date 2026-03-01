local addonName, addonTable = ...
addonTable.XpBar = {}

local EventBus = addonTable.EventBus
local AbbreviateNumber = addonTable.Core.AbbreviateNumber

-- Frame references
local barFrame
local barBg
local barFill
local restedFill
local pendingFill
local levelText
local xpText
local pctText
local pendingQuestText

-- Session tracking
local sessionStartTime = nil
local sessionStartXP = nil

local function FormatTime(seconds)
    if not seconds or seconds <= 0 then return "?" end
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds % 86400) / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if d > 0 then
        return string.format("%dd %dh", d, h)
    elseif h > 0 then
        return string.format("%dh %dm", h, m)
    elseif m > 0 then
        return string.format("%dm", m)
    else
        return "<1m"
    end
end

-- Sum XP from all quests currently ready to turn in.
-- GetQuestLogRewardXP(questID) returns the actual XP the player will receive (includes level scaling).
-- An optional xpBonusPct setting lets users add a manual percentage for Warband Mentor /
-- Midnight achievement bonuses that the client may not reflect in the quest log value.
local function GetPendingQuestXP()
    local total = 0
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID and C_QuestLog.IsComplete(info.questID) then
            local xp = (GetQuestLogRewardXP and GetQuestLogRewardXP(info.questID)) or 0
            total = total + xp
        end
    end
    local bonusPct = UIThingsDB.xpBar and UIThingsDB.xpBar.xpBonusPct or 0
    if bonusPct ~= 0 then
        total = math.floor(total * (1 + bonusPct / 100))
    end
    return total
end

local function UpdateDisplay()
    if not barFrame or not barFrame:IsShown() then return end

    local settings = UIThingsDB.xpBar
    local level = UnitLevel("player")
    local maxLevel = GetMaxPlayerLevel()
    local isMaxLevel = level >= maxLevel

    if isMaxLevel and not settings.showAtMaxLevel then
        barFrame:Hide()
        return
    end

    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local restedXP = GetXPExhaustion() or 0

    local barColor    = settings.barColor
    local restedColor = settings.restedColor
    local pendingColor = settings.pendingColor
    local bgColor     = settings.bgColor

    -- Background
    barBg:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, bgColor.a)

    local barW = barFrame:GetWidth()

    if not isMaxLevel and maxXP and maxXP > 0 then
        local xpFrac = currentXP / maxXP
        local xpWidth = math.max(1, xpFrac * barW)
        barFill:Show()
        barFill:SetColorTexture(barColor.r, barColor.g, barColor.b, barColor.a)
        barFill:SetWidth(xpWidth)

        local remaining = maxXP - currentXP

        -- Pending quest XP fill (OVERLAY — renders above rested fill).
        -- Shows XP you'll gain from turning in all completed quests.
        local pendingXP = GetPendingQuestXP()
        if pendingXP > 0 and remaining > 0 then
            local pendingFrac = math.min(pendingXP, remaining) / maxXP
            local pendingWidth = math.max(1, pendingFrac * barW)
            pendingFill:ClearAllPoints()
            pendingFill:SetPoint("TOPLEFT",    barFrame, "TOPLEFT",    xpWidth, 0)
            pendingFill:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", xpWidth, 0)
            pendingFill:SetWidth(pendingWidth)
            pendingFill:SetColorTexture(pendingColor.r, pendingColor.g, pendingColor.b, pendingColor.a)
            pendingFill:Show()
            if pendingQuestText then
                pendingQuestText:SetText(AbbreviateNumber(pendingXP) .. " quest xp")
                pendingQuestText:Show()
            end
        else
            pendingFill:Hide()
            if pendingQuestText then pendingQuestText:Hide() end
        end

        -- Rested XP fill (ARTWORK — sits below pending fill in the same region).
        if restedXP > 0 and remaining > 0 then
            local restedFrac = math.min(restedXP, remaining) / maxXP
            local restedWidth = math.max(1, restedFrac * barW)
            restedFill:ClearAllPoints()
            restedFill:SetPoint("TOPLEFT",    barFrame, "TOPLEFT",    xpWidth, 0)
            restedFill:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", xpWidth, 0)
            restedFill:SetWidth(restedWidth)
            restedFill:SetColorTexture(restedColor.r, restedColor.g, restedColor.b, restedColor.a)
            restedFill:Show()
        else
            restedFill:Hide()
        end

        -- Level text
        if settings.showLevel and levelText then
            levelText:Show()
            levelText:SetText(tostring(level))
        elseif levelText then
            levelText:Hide()
        end

        -- XP text
        if settings.showXPText and xpText then
            xpText:Show()
            local remaining = maxXP - currentXP
            xpText:SetText(string.format("%s / %s (%s rem)",
                AbbreviateNumber(currentXP), AbbreviateNumber(maxXP), AbbreviateNumber(remaining)))
        elseif xpText then
            xpText:Hide()
        end

        -- Percent text
        if settings.showPercent and pctText then
            pctText:Show()
            local pct = (currentXP / maxXP) * 100
            -- Time-to-level estimate from session data
            local tllStr = ""
            if settings.showTimers and sessionStartXP and sessionStartTime then
                local gainedXP = currentXP - sessionStartXP
                local elapsed = GetTime() - sessionStartTime
                if gainedXP > 0 and elapsed > 10 then
                    local xpPerHour = math.floor(gainedXP / elapsed * 3600)
                    if xpPerHour > 0 then
                        local remaining2 = maxXP - currentXP
                        local secondsToLevel = remaining2 / (xpPerHour / 3600)
                        tllStr = " | TTL: " .. FormatTime(secondsToLevel)
                    end
                end
            end
            pctText:SetText(string.format("%.1f%%%s", pct, tllStr))
        elseif pctText then
            pctText:Hide()
        end
    else
        -- Max level: hide the bar fill, show level
        barFill:SetWidth(1)
        restedFill:Hide()
        pendingFill:Hide()
        if pendingQuestText then pendingQuestText:Hide() end
        if levelText then levelText:SetText(tostring(level)) end
        if xpText then xpText:SetText("Max Level") end
        if pctText then pctText:SetText("") end
    end
end

local function ApplyBlizzardBarVisibility()
    local hide = UIThingsDB.xpBar.hideBlizzardBar
    local container = MainStatusTrackingBarContainer
    if not container then return end
    if InCombatLockdown() then return end
    if hide then
        RegisterStateDriver(container, "visibility", "hide")
    else
        UnregisterStateDriver(container, "visibility")
        container:Show()
    end
end

function addonTable.XpBar.UpdateSettings()
    if not barFrame then return end

    local settings = UIThingsDB.xpBar
    local level = UnitLevel("player")
    local maxLevel = GetMaxPlayerLevel()
    local isMaxLevel = level and maxLevel and level >= maxLevel

    ApplyBlizzardBarVisibility()

    if not settings.enabled or (isMaxLevel and not settings.showAtMaxLevel) then
        barFrame:Hide()
        return
    end

    -- Size
    local w = settings.width or 600
    local h = settings.height or 20
    barFrame:SetSize(w, h)

    -- Position
    local pos = settings.pos
    if pos then
        barFrame:ClearAllPoints()
        barFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    end

    -- Lock/unlock
    if settings.locked then
        barFrame:EnableMouse(false)
    else
        barFrame:EnableMouse(true)
    end

    -- Font
    local font = settings.font or "Fonts\\FRIZQT__.TTF"
    local fontSize = settings.fontSize or 11
    if levelText then levelText:SetFont(font, fontSize, "OUTLINE") end
    if xpText then xpText:SetFont(font, fontSize, "OUTLINE") end
    if pctText then pctText:SetFont(font, fontSize, "OUTLINE") end

    barFrame:Show()
    UpdateDisplay()
end

local function OnXPUpdate()
    if not UIThingsDB.xpBar or not UIThingsDB.xpBar.enabled then return end
    UpdateDisplay()
end

local function OnLevelUp()
    if not UIThingsDB.xpBar or not UIThingsDB.xpBar.enabled then return end
    -- Reset session tracking on level up
    sessionStartXP = UnitXP("player")
    sessionStartTime = GetTime()
    UpdateDisplay()
end

local function OnEnteringWorld()
    if not UIThingsDB.xpBar or not UIThingsDB.xpBar.enabled then return end
    sessionStartXP = UnitXP("player")
    sessionStartTime = GetTime()
    addonTable.XpBar.UpdateSettings()
end

local function Init()
    -- Seed session tracking now — PLAYER_ENTERING_WORLD already fired before we registered
    sessionStartXP = UnitXP("player")
    sessionStartTime = GetTime()

    barFrame = CreateFrame("Frame", "LunaUITweaks_XpBar", UIParent, "BackdropTemplate")
    barFrame:SetFrameStrata("LOW")
    barFrame:SetMovable(true)
    barFrame:SetClampedToScreen(true)
    barFrame:RegisterForDrag("LeftButton")

    barFrame:SetScript("OnDragStart", function(self)
        if not UIThingsDB.xpBar.locked then
            self:StartMoving()
        end
    end)
    barFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        UIThingsDB.xpBar.pos = { point = point, x = x, y = y }
    end)

    -- Background texture
    barBg = barFrame:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()

    -- XP fill
    barFill = barFrame:CreateTexture(nil, "ARTWORK")
    barFill:SetPoint("TOPLEFT")
    barFill:SetPoint("BOTTOMLEFT")

    -- Rested XP fill (ARTWORK — sits behind pending fill; positioned in UpdateDisplay)
    restedFill = barFrame:CreateTexture(nil, "ARTWORK")
    restedFill:SetPoint("TOPLEFT")
    restedFill:SetPoint("BOTTOMLEFT")

    -- Pending quest XP fill (OVERLAY — renders above rested; positioned in UpdateDisplay)
    -- Shows XP from completed quests not yet turned in.
    pendingFill = barFrame:CreateTexture(nil, "OVERLAY")
    pendingFill:SetPoint("TOPLEFT")
    pendingFill:SetPoint("BOTTOMLEFT")

    -- Level text (left)
    levelText = barFrame:CreateFontString(nil, "OVERLAY")
    levelText:SetPoint("LEFT", barFrame, "LEFT", 6, 0)
    levelText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    levelText:SetTextColor(1, 1, 1, 1)

    -- XP text (center)
    xpText = barFrame:CreateFontString(nil, "OVERLAY")
    xpText:SetPoint("CENTER", barFrame, "CENTER", 0, 0)
    xpText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    xpText:SetTextColor(1, 1, 1, 1)

    -- Percent text (right)
    pctText = barFrame:CreateFontString(nil, "OVERLAY")
    pctText:SetPoint("RIGHT", barFrame, "RIGHT", -6, 0)
    pctText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    pctText:SetTextColor(1, 1, 1, 1)

    -- Pending quest XP label (small, just below the bottom-right of the bar)
    pendingQuestText = barFrame:CreateFontString(nil, "OVERLAY")
    pendingQuestText:SetPoint("TOPRIGHT", barFrame, "BOTTOMRIGHT", 0, -2)
    pendingQuestText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    pendingQuestText:SetTextColor(1, 0.82, 0, 1)
    pendingQuestText:Hide()

    barFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.xpBar.locked then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("|cFFFFD100XP Bar|r")
            GameTooltip:AddLine("Drag to reposition", 0.8, 0.8, 0.8)
            GameTooltip:Show()
            return
        end

        local level = UnitLevel("player")
        local maxLevel = GetMaxPlayerLevel()
        if level >= maxLevel then return end

        local currentXP = UnitXP("player")
        local maxXP = UnitXPMax("player")
        local restedXP = GetXPExhaustion() or 0

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(string.format("|cFFFFD100Level %d|r", level))
        if maxXP and maxXP > 0 then
            local pct = (currentXP / maxXP) * 100
            GameTooltip:AddDoubleLine("XP:", string.format("%s / %s (%.1f%%)",
                AbbreviateNumber(currentXP), AbbreviateNumber(maxXP), pct), 1, 1, 1, 0.8, 0.8, 0.8)
            GameTooltip:AddDoubleLine("Remaining:", AbbreviateNumber(maxXP - currentXP), 1, 1, 1, 1, 0.82, 0)
        end
        if restedXP > 0 then
            local restedPct = maxXP and maxXP > 0 and (restedXP / maxXP * 100) or 0
            GameTooltip:AddDoubleLine("Rested:", string.format("%s (%.1f%%)",
                AbbreviateNumber(restedXP), restedPct), 1, 1, 1, 0.25, 0.5, 1)
        end
        local pendingXP = GetPendingQuestXP()
        if pendingXP > 0 then
            local pendingPct = maxXP and maxXP > 0 and (pendingXP / maxXP * 100) or 0
            local bonusPct = UIThingsDB.xpBar.xpBonusPct or 0
            local bonusStr = bonusPct > 0 and string.format(" +%d%% bonus", bonusPct) or ""
            GameTooltip:AddDoubleLine("Pending quests:", string.format("%s (%.1f%%)%s",
                AbbreviateNumber(pendingXP), pendingPct, bonusStr), 1, 1, 1, 1, 0.85, 0)
        end

        -- Session stats
        if sessionStartXP and sessionStartTime then
            local gainedXP = currentXP - sessionStartXP
            local elapsed = GetTime() - sessionStartTime
            if gainedXP > 0 and elapsed > 10 then
                local xpPerHour = math.floor(gainedXP / elapsed * 3600)
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine("Session XP gained:", AbbreviateNumber(gainedXP), 1, 1, 1, 0.6, 1, 0.6)
                GameTooltip:AddDoubleLine("XP/hour:", AbbreviateNumber(xpPerHour), 1, 1, 1, 0.6, 1, 0.6)
                if xpPerHour > 0 and maxXP and maxXP > 0 then
                    local remaining = maxXP - currentXP
                    local secondsToLevel = remaining / (xpPerHour / 3600)
                    GameTooltip:AddDoubleLine("Est. time to level:", FormatTime(secondsToLevel), 1, 1, 1, 1, 0.82, 0)
                end
            end
        end

        GameTooltip:Show()
    end)
    barFrame:SetScript("OnLeave", GameTooltip_Hide)

    -- Register events
    EventBus.Register("PLAYER_XP_UPDATE", OnXPUpdate, "XpBar")
    EventBus.Register("PLAYER_LEVEL_UP", OnLevelUp, "XpBar")
    EventBus.Register("UPDATE_EXHAUSTION", OnXPUpdate, "XpBar")
    EventBus.Register("ENABLE_XP_GAIN", OnXPUpdate, "XpBar")
    EventBus.Register("DISABLE_XP_GAIN", OnXPUpdate, "XpBar")
    EventBus.Register("PLAYER_ENTERING_WORLD", OnEnteringWorld, "XpBar")
    EventBus.Register("QUEST_LOG_UPDATE", OnXPUpdate, "XpBar")

    addonTable.XpBar.UpdateSettings()
end

EventBus.Register("PLAYER_LOGIN", function()
    addonTable.Core.SafeAfter(0.5, Init)
end)

