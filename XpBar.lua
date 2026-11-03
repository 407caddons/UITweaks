local addonName, addonTable = ...
addonTable.XpBar = {}

local EventBus = addonTable.EventBus
local AbbreviateNumber = addonTable.Core.AbbreviateNumber
local Secret = addonTable.Secret

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

-- Session tracking. XP gained is accumulated from XP deltas, so loading
-- screens and level-ups do not restart the rate; the session starts at
-- login/reload.
local sessionStartTime = nil
local sessionGainedXP = 0
local lastXP, lastMaxXP

local function AccountXP()
    local current, max = UnitXP("player"), UnitXPMax("player")
    if lastXP then
        if current >= lastXP then
            sessionGainedXP = sessionGainedXP + (current - lastXP)
        elseif lastMaxXP then
            -- XP dropped: a level-up. Count the rest of the old level plus the new XP.
            sessionGainedXP = sessionGainedXP + math.max(0, lastMaxXP - lastXP) + current
        end
    end
    lastXP, lastMaxXP = current, max
end

local function SessionXPPerHour()
    if not sessionStartTime then return nil end
    local elapsed = GetTime() - sessionStartTime
    if sessionGainedXP <= 0 or elapsed <= 10 then return nil end
    return sessionGainedXP / elapsed * 3600
end

-- Average XP per kill and per quest turn-in at the current level (reset on
-- level-up), plus the last XP each mob name gave, for kills-to-level estimates.
local killStats = { xp = 0, count = 0 }
local questStats = { xp = 0, count = 0 }
local mobXP, mobXPCount = {}, 0 -- [mobName] = { xp = n, level = playerLevel }
local MOB_XP_LIMIT = 300
local killPattern

-- "%s dies, you gain %d experience." -> "^(.-) dies, you gain (%d+) experience%."
-- Matched as a prefix so rested/group bonus suffixes still match.
local function BuildKillPattern()
    local format = COMBATLOG_XPGAIN_FIRSTPERSON
    if type(format) ~= "string" or not format:find("%s", 1, true) or not format:find("%d", 1, true) then
        return false
    end
    if format:find("%s", 1, true) > format:find("%d", 1, true) then return false end
    local pattern = format:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    pattern = pattern:gsub("%%%%s", "(.-)"):gsub("%%%%d", "(%%d+)")
    return "^" .. pattern
end

local function OnCombatXPGain(_, text)
    if not Secret.IsPublic(text) or type(text) ~= "string" then return end
    if killPattern == nil then killPattern = BuildKillPattern() end
    if not killPattern then return end
    local name, xp = text:match(killPattern)
    xp = tonumber(xp)
    if not name or name == "" or not xp or xp <= 0 then return end
    killStats.xp, killStats.count = killStats.xp + xp, killStats.count + 1
    if not mobXP[name] then
        if mobXPCount >= MOB_XP_LIMIT then wipe(mobXP); mobXPCount = 0 end
        mobXPCount = mobXPCount + 1
    end
    mobXP[name] = { xp = xp, level = UnitLevel("player") }
end

local function OnQuestTurnedIn(_, _, xpReward)
    if not Secret.IsPublic(xpReward) or type(xpReward) ~= "number" or xpReward <= 0 then return end
    questStats.xp, questStats.count = questStats.xp + xpReward, questStats.count + 1
end

-- "~N" units of the average needed to cover `remaining`, or nil without data.
local function CountToLevel(stats, remaining)
    if stats.count == 0 or stats.xp <= 0 or remaining <= 0 then return nil end
    local average = stats.xp / stats.count
    return math.ceil(remaining / average), average
end

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
    if type(GetAchievementInfo) ~= "function" then return 0 end -- e.g. clients without achievements
    for _, ach in ipairs(MENTOR_ACHIEVEMENTS) do
        if select(4, GetAchievementInfo(ach.id)) then
            return ach.pct
        end
    end
    return 0
end

-- Player aura reads error while auras are secret (encounters, challenge modes).
-- Returns the aura, nil when absent, or false when it cannot be read.
local function ReadPlayerAura(spellID)
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
    if not ok or (issecretvalue and issecretvalue(aura)) then return false end
    return aura
end

-- Returns the total auto-detected XP bonus percentage from active buffs, plus any manual override.
local function GetXPBonusPct()
    local total = GetMentorBonus()
    for _, buff in ipairs(XP_BOOST_BUFFS) do
        if ReadPlayerAura(buff.id) then
            total = total + buff.pct
        end
    end
    -- Manual override stacks on top of auto-detected (use for buffs not yet in the table)
    local manual = UIThingsDB.xpBar and UIThingsDB.xpBar.xpBonusPct or 0
    return total + manual
end

-- Sum XP from all quests currently ready to turn in.
-- GetQuestLogRewardXP already returns XP with all active bonuses applied.
-- Cached: invalidated by every XP/quest event and when the boost set changes.
-- { xp = total, count = quests, zones = { { name, count, xp }, ... } by xp }
local pendingXPCache
local function GetPendingSummary()
    if pendingXPCache then return pendingXPCache end
    local summary = { xp = 0, count = 0, zones = {} }
    local byZone, header = {}, nil
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and info.isHeader then
            header = info.title
        elseif info and info.questID and C_QuestLog.IsComplete(info.questID) then
            local xp = (GetQuestLogRewardXP and GetQuestLogRewardXP(info.questID)) or 0
            summary.xp, summary.count = summary.xp + xp, summary.count + 1
            local zoneName = header or "Other"
            local zone = byZone[zoneName]
            if not zone then
                zone = { name = zoneName, count = 0, xp = 0 }
                byZone[zoneName] = zone
                summary.zones[#summary.zones + 1] = zone
            end
            zone.count, zone.xp = zone.count + 1, zone.xp + xp
        end
    end
    table.sort(summary.zones, function(a, b) return a.xp > b.xp end)
    pendingXPCache = summary
    return summary
end

local function GetPendingQuestXP()
    return GetPendingSummary().xp
end

-- Sum of active boost-buff percentages, or nil when aura data is restricted.
local function GetBoostSignature()
    local total = 0
    for _, buff in ipairs(XP_BOOST_BUFFS) do
        local aura = ReadPlayerAura(buff.id)
        if aura == false then return nil end
        if aura then total = total + buff.pct end
    end
    return total
end

local function UpdateDisplay()
    if not barFrame or not barFrame:IsShown() then return end

    local settings = UIThingsDB.xpBar
    local level = UnitLevel("player")
    local maxLevel = (addonTable.Client and addonTable.Client.GetMaxLevel() or GetMaxPlayerLevel())
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
                -- Turning in the completed quests would level you
                local nudge = pendingXP >= remaining and " (level up!)" or ""
                pendingQuestText:SetText(AbbreviateNumber(pendingXP) .. " quest xp" .. nudge)
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
            local xpPerHour = settings.showTimers and SessionXPPerHour()
            if xpPerHour and xpPerHour > 0 then
                local secondsToLevel = (maxXP - currentXP) / (xpPerHour / 3600)
                tllStr = " | TTL: " .. FormatTime(secondsToLevel)
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
    pendingXPCache = nil
    if not barFrame then return end

    local settings = UIThingsDB.xpBar
    local level = UnitLevel("player")
    local maxLevel = (addonTable.Client and addonTable.Client.GetMaxLevel() or GetMaxPlayerLevel())
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
    if not settings.enabled or (hideAtMaxLevel and not (addonTable.LayoutMode and addonTable.LayoutMode.IsActive())) then
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

-- XP and quest-log events often arrive in bursts; redraw once per frame.
local updateFrame = CreateFrame("Frame")
updateFrame:Hide()
updateFrame:SetScript("OnUpdate", function(self)
    self:Hide()
    if UIThingsDB.xpBar and UIThingsDB.xpBar.enabled then UpdateDisplay() end
end)

local function OnXPUpdate()
    if not UIThingsDB.xpBar or not UIThingsDB.xpBar.enabled then return end
    AccountXP()
    pendingXPCache = nil
    updateFrame:Show()
end

-- Player auras only matter when an XP boost is gained or lost.
local lastBoostSignature
local function OnAuraUpdate()
    if not UIThingsDB.xpBar or not UIThingsDB.xpBar.enabled then return end
    local signature = GetBoostSignature()
    if signature == nil or signature == lastBoostSignature then return end
    lastBoostSignature = signature
    pendingXPCache = nil
    updateFrame:Show()
end

local function OnFactionUpdate()
    if not UIThingsDB.xpBar or not UIThingsDB.xpBar.enabled then return end
    -- Use UpdateSettings so the bar can be shown/hidden based on whether
    -- a faction is now being watched (UpdateDisplay bails early when hidden)
    addonTable.XpBar.UpdateSettings()
end

local function OnLevelUp()
    if not UIThingsDB.xpBar or not UIThingsDB.xpBar.enabled then return end
    -- Session XP carries across levels; per-level kill/quest averages restart.
    AccountXP()
    killStats.xp, killStats.count = 0, 0
    questStats.xp, questStats.count = 0, 0
    pendingXPCache = nil
    UpdateDisplay()
end

local function OnEnteringWorld()
    if not UIThingsDB.xpBar or not UIThingsDB.xpBar.enabled then return end
    -- Loading screens keep the session; just resync the XP baseline.
    AccountXP()
    addonTable.XpBar.UpdateSettings()
end

-- Enemy tooltips: "~N kills to level" from the XP that mob name last gave at
-- this level. Covered by the "levelling estimates" (showTimers) option.
local function AddKillsToLevel(tooltip, tooltipData)
    if tooltip ~= GameTooltip then return end
    local settings = UIThingsDB.xpBar
    if not settings or not settings.enabled or not settings.showTimers then return end
    -- GetUnit resolves names from the guid; bail out if it is secret.
    if tooltipData and tooltipData.guid and not Secret.IsPublic(tooltipData.guid) then return end
    local _, unit = tooltip:GetUnit()
    if not unit or not Secret.IsPublic(unit) then return end
    local canAttack, isPlayer = UnitCanAttack("player", unit), UnitIsPlayer(unit)
    if not Secret.IsPublic(canAttack) or not Secret.IsPublic(isPlayer) or not canAttack or isPlayer then return end
    local name = Secret.SafeUnitName(unit, nil)
    local entry = name and mobXP[name]
    if not entry or entry.level ~= UnitLevel("player") then return end
    local remaining = UnitXPMax("player") - UnitXP("player")
    if remaining <= 0 then return end
    tooltip:AddLine(string.format("~%d kills to level (%s xp each)",
        math.ceil(remaining / entry.xp), AbbreviateNumber(entry.xp)), 0.6, 1, 0.6)
end

local enemyTooltipHooked = false
local function HookEnemyTooltip()
    if enemyTooltipHooked then return end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, AddKillsToLevel)
        enemyTooltipHooked = true
    elseif GameTooltip:HasScript("OnTooltipSetUnit") then
        -- Clients without the tooltip data processor
        GameTooltip:HookScript("OnTooltipSetUnit", function(self) AddKillsToLevel(self) end)
        enemyTooltipHooked = true
    end
end

local function Init()
    -- Seed session tracking now — PLAYER_ENTERING_WORLD already fired before we registered
    sessionStartTime = GetTime()
    sessionGainedXP = 0
    lastXP, lastMaxXP = UnitXP("player"), UnitXPMax("player")

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
        local maxLevel = (addonTable.Client and addonTable.Client.GetMaxLevel() or GetMaxPlayerLevel())
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
                if ReadPlayerAura(buff.id) then
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

        -- Ready-to-turn-in summary, grouped by quest log zone (largest first)
        local summary = GetPendingSummary()
        if summary.count > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Ready to turn in:", string.format("%d quest%s",
                summary.count, summary.count == 1 and "" or "s"), 1, 1, 1, 1, 0.85, 0)
            for i = 1, math.min(4, #summary.zones) do
                local zone = summary.zones[i]
                GameTooltip:AddDoubleLine("  " .. zone.name, string.format("%d (%s xp)",
                    zone.count, AbbreviateNumber(zone.xp)), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
            end
            if maxXP and maxXP > 0 and summary.xp >= maxXP - currentXP then
                GameTooltip:AddLine("Turning these in will level you up!", 0.4, 1, 0.4)
            end
        end

        -- Session stats (since login/reload; carries across zones and levels)
        local xpPerHour = SessionXPPerHour()
        local remaining = (maxXP or 0) - currentXP
        local kills, killAverage = CountToLevel(killStats, remaining)
        local quests, questAverage = CountToLevel(questStats, remaining)
        if xpPerHour or kills or quests then
            GameTooltip:AddLine(" ")
        end
        if xpPerHour then
            GameTooltip:AddDoubleLine("Session XP gained:", AbbreviateNumber(sessionGainedXP), 1, 1, 1, 0.6, 1, 0.6)
            GameTooltip:AddDoubleLine("XP/hour:", AbbreviateNumber(math.floor(xpPerHour)), 1, 1, 1, 0.6, 1, 0.6)
            if remaining > 0 then
                GameTooltip:AddDoubleLine("Est. time to level:", FormatTime(remaining / (xpPerHour / 3600)), 1, 1, 1, 1, 0.82, 0)
            end
        end
        if kills then
            GameTooltip:AddDoubleLine("Kills to level:", string.format("~%d (%s xp avg)",
                kills, AbbreviateNumber(math.floor(killAverage))), 1, 1, 1, 1, 0.82, 0)
        end
        if quests then
            GameTooltip:AddDoubleLine("Quests to level:", string.format("~%d (%s xp avg)",
                quests, AbbreviateNumber(math.floor(questAverage))), 1, 1, 1, 1, 0.82, 0)
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
    EventBus.RegisterUnit("UNIT_AURA", "player", OnAuraUpdate, "XpBar")
    -- Kill and quest XP for the kills/quests-to-level estimates
    EventBus.Register("CHAT_MSG_COMBAT_XP_GAIN", OnCombatXPGain, "XpBar")
    EventBus.Register("QUEST_TURNED_IN", OnQuestTurnedIn, "XpBar")
    HookEnemyTooltip()

    addonTable.XpBar.UpdateSettings()
end

EventBus.Register("PLAYER_LOGIN", function()
    addonTable.Core.SafeAfter(0.5, Init)
end)


-- Layout Mode integration
addonTable.LayoutMode.RegisterModule("XpBar", {
    setLocked = function(locked)
        if UIThingsDB.xpBar then UIThingsDB.xpBar.locked = locked end
    end,
    apply = function() addonTable.XpBar.UpdateSettings() end,
})
addonTable.LayoutMode.RegisterTarget("XP / reputation", function() return _G.LunaUITweaks_XpBar end, function()
    local db = UIThingsDB.xpBar
    return db and db.enabled
end)
