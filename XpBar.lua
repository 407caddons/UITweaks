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

-- Known XP boost buffs, auto-detected from active player auras.
-- GetQuestLogRewardXP returns base XP before these multipliers, so we apply them manually.
-- To find an unknown buff's spell ID while it's active, run:
--   /run local a=C_UnitAuras.GetPlayerAuraBySpellID(ID); if a then print(a.name,a.spellId) end
-- or scan all buffs: /run for i=1,40 do local a=C_UnitAuras.GetAuraDataByIndex("player",i,"HELPFUL") if a then print(a.spellId,a.name) end end
local XP_BOOST_BUFFS = {
    { id = 46668, pct = 10, label = "DMF WHEE!" },         -- Darkmoon Faire Carousel (+10% XP, 1hr)
    { id = 136583, pct = 10, label = "DMF Top Hat" },       -- Darkmoon Top Hat (+10% XP, 1hr)
}

-- Warband Mentor: Midnight achievement tiers (highest completed wins)
local MENTOR_ACHIEVEMENTS = {
    { id = 42332, pct = 25 },
    { id = 42331, pct = 20 },
    { id = 42330, pct = 15 },
    { id = 42329, pct = 10 },
    { id = 42328, pct = 5 },
}

local function GetMentorBonus()
    for _, ach in ipairs(MENTOR_ACHIEVEMENTS) do
        if select(4, GetAchievementInfo(ach.id)) then
            return ach.pct
        end
    end
    return 0
end

-- Returns the total auto-detected XP bonus percentage from active buffs, plus any manual override.
local function GetXPBonusPct()
    local total = GetMentorBonus()
    for _, buff in ipairs(XP_BOOST_BUFFS) do
        if C_UnitAuras.GetPlayerAuraBySpellID(buff.id) then
            total = total + buff.pct
        end
    end
    -- Manual override stacks on top of auto-detected (use for buffs not yet in the table)
    local manual = UIThingsDB.xpBar and UIThingsDB.xpBar.xpBonusPct or 0
    return total + manual
end

-- Sum XP from all quests currently ready to turn in.
-- GetQuestLogRewardXP already returns XP with all active bonuses applied.
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
    return total
end

local function UpdateDisplay()
    if not barFrame or not barFrame:IsShown() then return end

    local settings = UIThingsDB.xpBar
    local level = UnitLevel("player")
    local maxLevel = GetMaxPlayerLevel()
    local isMaxLevel = level >= maxLevel

    if isMaxLevel then
        if settings.repBarEnabled then
            -- Only show if a faction is actually being watched
            local data = C_Reputation.GetWatchedFactionData()
            if not (data and data.name) then
                barFrame:Hide()
                return
            end
        elseif not settings.showAtMaxLevel then
            barFrame:Hide()
            return
        end
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
        -- Max level
        restedFill:Hide()
        pendingFill:Hide()
        if pendingQuestText then pendingQuestText:Hide() end

        if settings.repBarEnabled then
            local data = C_Reputation.GetWatchedFactionData()
            if data and data.name then
                local repColor = settings.repBarColor
                local barW = barFrame:GetWidth()
                local current, max

                if C_Reputation.IsMajorFaction(data.factionID) then
                    local mfData = C_MajorFactions.GetMajorFactionData(data.factionID)
                    if mfData and mfData.renownLevelThreshold and mfData.renownLevelThreshold > 0 then
                        current = mfData.renownReputationEarned or 0
                        max = mfData.renownLevelThreshold
                    else
                        current, max = 1, 1
                    end
                elseif C_Reputation.IsFactionParagon(data.factionID) then
                    local pVal, pThresh = C_Reputation.GetFactionParagonInfo(data.factionID)
                    if pVal and pThresh and pThresh > 0 then
                        current = pVal % pThresh
                        max = pThresh
                    else
                        current, max = 1, 1
                    end
                else
                    current = data.currentStanding - data.currentReactionThreshold
                    max = data.nextReactionThreshold - data.currentReactionThreshold
                    if max <= 0 then current, max = 1, 1 end
                end

                local fraction = math.min(1, max > 0 and (current / max) or 1)
                barFill:Show()
                barFill:SetColorTexture(repColor.r, repColor.g, repColor.b, repColor.a)
                barFill:SetWidth(math.max(1, fraction * barW))

                if settings.showLevel and levelText then
                    levelText:Show()
                    levelText:SetText(tostring(level))
                elseif levelText then
                    levelText:Hide()
                end

                if settings.showXPText and xpText then
                    xpText:Show()
                    local label
                    if C_Reputation.IsMajorFaction(data.factionID) then
                        local renownLevel = C_MajorFactions.GetCurrentRenownLevel(data.factionID)
                        label = string.format("%s  R%d  %s/%s",
                            data.name, renownLevel or 0, AbbreviateNumber(current), AbbreviateNumber(max))
                    else
                        label = string.format("%s  %s/%s",
                            data.name, AbbreviateNumber(current), AbbreviateNumber(max))
                    end
                    xpText:SetText(label)
                elseif xpText then
                    xpText:Hide()
                end

                if settings.showPercent and pctText then
                    pctText:Show()
                    pctText:SetText(string.format("%.1f%%", fraction * 100))
                elseif pctText then
                    pctText:Hide()
                end
            else
                -- No watched faction — hide the bar entirely
                barFrame:Hide()
                return
            end
        else
            barFill:SetWidth(1)
            if levelText then levelText:SetText(tostring(level)) end
            if xpText then xpText:SetText("Max Level") end
            if pctText then pctText:SetText("") end
        end
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

    local hideAtMaxLevel = false
    if isMaxLevel then
        if settings.repBarEnabled then
            local data = C_Reputation.GetWatchedFactionData()
            hideAtMaxLevel = not (data and data.name)
        else
            hideAtMaxLevel = not settings.showAtMaxLevel
        end
    end
    if not settings.enabled or hideAtMaxLevel then
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

    -- Lock/unlock (mouse stays enabled for tooltip; dragging is gated inside OnMouseDown)
    barFrame:EnableMouse(true)

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

local function OnFactionUpdate()
    if not UIThingsDB.xpBar or not UIThingsDB.xpBar.enabled then return end
    -- Use UpdateSettings so the bar can be shown/hidden based on whether
    -- a faction is now being watched (UpdateDisplay bails early when hidden)
    addonTable.XpBar.UpdateSettings()
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
        if level >= maxLevel then
            if not UIThingsDB.xpBar.repBarEnabled then return end
            -- Reputation tooltip at max level
            local data = C_Reputation.GetWatchedFactionData()
            if not data or not data.name then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText("|cFFFFD100Reputation|r")
                GameTooltip:AddLine("No faction watched. Watch one via the Reputation panel.", 0.7, 0.7, 0.7, true)
                GameTooltip:Show()
            else
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(data.name, 1, 1, 1)
                if C_Reputation.IsMajorFaction(data.factionID) then
                    local mfData = C_MajorFactions.GetMajorFactionData(data.factionID)
                    local renownLevel = mfData and mfData.renownLevel or 0
                    local isMaxRenown = C_MajorFactions.HasMaximumRenown(data.factionID)
                    local rLabel = isMaxRenown and string.format("%d (Max)", renownLevel) or tostring(renownLevel)
                    GameTooltip:AddDoubleLine("Renown:", rLabel, 1, 1, 1, 0, 1, 0)
                    if mfData and mfData.renownLevelThreshold and mfData.renownLevelThreshold > 0 then
                        local cur = mfData.renownReputationEarned or 0
                        local mx = mfData.renownLevelThreshold
                        GameTooltip:AddDoubleLine("Progress:",
                            string.format("%s / %s (%.1f%%)", AbbreviateNumber(cur), AbbreviateNumber(mx), cur/mx*100),
                            1, 1, 1, 0.8, 0.8, 0.8)
                    end
                elseif C_Reputation.IsFactionParagon(data.factionID) then
                    local pVal, pThresh, _, hasReward = C_Reputation.GetFactionParagonInfo(data.factionID)
                    if pVal and pThresh then
                        local STANDING_LABELS = { "Hated","Hostile","Unfriendly","Neutral","Friendly","Honored","Revered","Exalted" }
                        GameTooltip:AddDoubleLine("Standing:", STANDING_LABELS[data.reaction] or "Exalted", 1, 1, 1, 0, 0.8, 0)
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddDoubleLine("Paragon:",
                            string.format("%d / %d", pVal % pThresh, pThresh), 1, 0.82, 0, 0.8, 0.8, 0.8)
                        if hasReward then GameTooltip:AddLine("|cFF00FF00Reward available!|r") end
                    end
                else
                    local STANDING_LABELS = { "Hated","Hostile","Unfriendly","Neutral","Friendly","Honored","Revered","Exalted" }
                    GameTooltip:AddDoubleLine("Standing:", STANDING_LABELS[data.reaction] or "Unknown", 1, 1, 1, 0, 0.8, 0)
                    local cur = data.currentStanding - data.currentReactionThreshold
                    local mx = data.nextReactionThreshold - data.currentReactionThreshold
                    if mx > 0 then
                        GameTooltip:AddDoubleLine("Progress:",
                            string.format("%s / %s (%.1f%%)", AbbreviateNumber(cur), AbbreviateNumber(mx), cur/mx*100),
                            1, 1, 1, 0.8, 0.8, 0.8)
                    end
                end
                GameTooltip:Show()
            end
            return
        end

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
            local totalBonus = GetXPBonusPct()
            local bonusStr = totalBonus > 0 and string.format(" +%d%% bonus", totalBonus) or ""
            GameTooltip:AddDoubleLine("Pending quests:", string.format("%s (%.1f%%)%s",
                AbbreviateNumber(pendingXP), pendingPct, bonusStr), 1, 1, 1, 1, 0.85, 0)
            -- List active XP boost buffs
            for _, buff in ipairs(XP_BOOST_BUFFS) do
                if C_UnitAuras.GetPlayerAuraBySpellID(buff.id) then
                    GameTooltip:AddDoubleLine("  " .. buff.label, string.format("+%d%%", buff.pct), 0.8, 0.8, 0.8, 0.4, 1, 0.4)
                end
            end
            local mentorPct = GetMentorBonus()
            if mentorPct > 0 then
                GameTooltip:AddDoubleLine("  Warband Mentor: Midnight", string.format("+%d%%", mentorPct), 0.8, 0.8, 0.8, 0.4, 1, 0.4)
            end
            local manual = UIThingsDB.xpBar.xpBonusPct or 0
            if manual > 0 then
                GameTooltip:AddDoubleLine("  Manual bonus", string.format("+%d%%", manual), 0.8, 0.8, 0.8, 0.4, 1, 0.4)
            end
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
    EventBus.Register("UPDATE_FACTION", OnFactionUpdate, "XpBar")
    -- Refresh pending XP when XP boost buffs are gained or dropped
    EventBus.RegisterUnit("UNIT_AURA", "player", OnXPUpdate)

    addonTable.XpBar.UpdateSettings()
end

EventBus.Register("PLAYER_LOGIN", function()
    addonTable.Core.SafeAfter(0.5, Init)
end)

