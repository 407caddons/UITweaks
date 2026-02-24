local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus
local AbbreviateNumber = addonTable.Core.AbbreviateNumber

table.insert(Widgets.moduleInits, function()
    local xpRepFrame = Widgets.CreateWidgetFrame("XPRep", "xpRep")
    xpRepFrame:RegisterForClicks("AnyUp")

    local cachedText = "XP/Rep"
    local isMaxLevel = false

    local STANDING_LABELS = {
        [1] = "Hated",
        [2] = "Hostile",
        [3] = "Unfriendly",
        [4] = "Neutral",
        [5] = "Friendly",
        [6] = "Honored",
        [7] = "Revered",
        [8] = "Exalted",
    }

    local STANDING_COLORS = {
        [1] = { r = 0.8, g = 0.13, b = 0.13 },   -- Hated
        [2] = { r = 1.0, g = 0.0, b = 0.0 },      -- Hostile
        [3] = { r = 0.93, g = 0.4, b = 0.13 },     -- Unfriendly
        [4] = { r = 1.0, g = 1.0, b = 0.0 },       -- Neutral
        [5] = { r = 0.0, g = 0.6, b = 0.0 },       -- Friendly
        [6] = { r = 0.0, g = 0.6, b = 0.0 },       -- Honored
        [7] = { r = 0.0, g = 0.6, b = 0.0 },       -- Revered
        [8] = { r = 0.0, g = 0.6, b = 0.0 },       -- Exalted
    }

    local function RefreshCache()
        local level = UnitLevel("player")
        local maxLevel = GetMaxPlayerLevel()
        isMaxLevel = level >= maxLevel

        if not isMaxLevel then
            -- Show XP
            local currentXP = UnitXP("player")
            local maxXP = UnitXPMax("player")
            if maxXP and maxXP > 0 then
                local pct = math.floor((currentXP / maxXP) * 100)
                local rested = GetXPExhaustion()
                if rested and rested > 0 then
                    cachedText = string.format("XP: %d%% (R)", pct)
                else
                    cachedText = string.format("XP: %d%%", pct)
                end
            else
                cachedText = "XP: --"
            end
        else
            -- Show watched reputation
            local data = C_Reputation.GetWatchedFactionData()
            if data and data.name then
                local name = data.name
                if #name > 15 then
                    name = name:sub(1, 12) .. "..."
                end

                -- Check if this is a major/renown faction
                if C_Reputation.IsMajorFaction(data.factionID) then
                    local renownLevel = C_MajorFactions.GetCurrentRenownLevel(data.factionID)
                    cachedText = string.format("Rep: %s R%d", name, renownLevel or 0)
                else
                    local current = data.currentStanding - data.currentReactionThreshold
                    local max = data.nextReactionThreshold - data.currentReactionThreshold
                    if max > 0 then
                        cachedText = string.format("Rep: %s %s/%s", name, AbbreviateNumber(current), AbbreviateNumber(max))
                    else
                        cachedText = string.format("Rep: %s", name)
                    end
                end
            else
                cachedText = "Rep: None"
            end
        end
    end

    local function OnXPRepUpdate()
        if not UIThingsDB.widgets.xpRep.enabled then return end
        RefreshCache()
    end

    local function OnXPRepEnteringWorld()
        if not UIThingsDB.widgets.xpRep.enabled then return end
        C_Timer.After(1, function()
            if UIThingsDB.widgets.xpRep.enabled then
                RefreshCache()
            end
        end)
    end

    xpRepFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("PLAYER_XP_UPDATE", OnXPRepUpdate)
            EventBus.Register("PLAYER_LEVEL_UP", OnXPRepUpdate)
            EventBus.Register("UPDATE_FACTION", OnXPRepUpdate)
            EventBus.Register("UPDATE_EXPANSION_LEVEL", OnXPRepUpdate)
            EventBus.Register("PLAYER_ENTERING_WORLD", OnXPRepEnteringWorld)
            RefreshCache()
        else
            EventBus.Unregister("PLAYER_XP_UPDATE", OnXPRepUpdate)
            EventBus.Unregister("PLAYER_LEVEL_UP", OnXPRepUpdate)
            EventBus.Unregister("UPDATE_FACTION", OnXPRepUpdate)
            EventBus.Unregister("UPDATE_EXPANSION_LEVEL", OnXPRepUpdate)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnXPRepEnteringWorld)
        end
    end

    xpRepFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)

        if not isMaxLevel then
            -- XP tooltip
            GameTooltip:SetText("Experience", 1, 1, 1)

            local currentXP = UnitXP("player")
            local maxXP = UnitXPMax("player")
            local level = UnitLevel("player")
            local maxLevel = GetMaxPlayerLevel()

            if maxXP and maxXP > 0 then
                local pct = (currentXP / maxXP) * 100
                GameTooltip:AddDoubleLine("Current XP:",
                    string.format("%s / %s (%.1f%%)", AbbreviateNumber(currentXP), AbbreviateNumber(maxXP), pct),
                    1, 1, 1, 0.8, 0.8, 0.8)
            end

            local rested = GetXPExhaustion()
            if rested and rested > 0 then
                local restedPct = maxXP and maxXP > 0 and (rested / maxXP * 100) or 0
                GameTooltip:AddDoubleLine("Rested XP:",
                    string.format("%s (%.1f%%)", AbbreviateNumber(rested), restedPct),
                    1, 1, 1, 0.25, 0.5, 1)
            else
                GameTooltip:AddDoubleLine("Rested XP:", "None", 1, 1, 1, 0.5, 0.5, 0.5)
            end

            GameTooltip:AddDoubleLine("Level:", string.format("%d / %d", level, maxLevel), 1, 1, 1, 0.8, 0.8, 0.8)

            if maxXP and maxXP > 0 then
                local remaining = maxXP - currentXP
                GameTooltip:AddDoubleLine("Remaining:", AbbreviateNumber(remaining), 1, 1, 1, 1, 0.82, 0)
            end

            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click to open Character Info", 0.5, 0.5, 1)
        else
            -- Reputation tooltip
            local data = C_Reputation.GetWatchedFactionData()
            if data and data.name then
                GameTooltip:SetText(data.name, 1, 1, 1)

                -- Check if major/renown faction
                if C_Reputation.IsMajorFaction(data.factionID) then
                    local renownLevel = C_MajorFactions.GetCurrentRenownLevel(data.factionID)
                    local isMaxRenown = C_MajorFactions.HasMaximumRenown(data.factionID)

                    if isMaxRenown then
                        GameTooltip:AddDoubleLine("Renown:", string.format("%d (Max)", renownLevel), 1, 1, 1, 0, 1, 0)
                    else
                        GameTooltip:AddDoubleLine("Renown:", tostring(renownLevel), 1, 1, 1, 0.8, 0.8, 0.8)
                    end

                    local current = data.currentStanding - data.currentReactionThreshold
                    local max = data.nextReactionThreshold - data.currentReactionThreshold
                    if max > 0 then
                        local pct = (current / max) * 100
                        GameTooltip:AddDoubleLine("Progress:",
                            string.format("%s / %s (%.1f%%)", AbbreviateNumber(current), AbbreviateNumber(max), pct),
                            1, 1, 1, 0.8, 0.8, 0.8)
                    end
                else
                    -- Standard reputation
                    local standingLabel = STANDING_LABELS[data.reaction] or "Unknown"
                    local standingColor = STANDING_COLORS[data.reaction] or { r = 1, g = 1, b = 1 }
                    GameTooltip:AddDoubleLine("Standing:", standingLabel,
                        1, 1, 1, standingColor.r, standingColor.g, standingColor.b)

                    local current = data.currentStanding - data.currentReactionThreshold
                    local max = data.nextReactionThreshold - data.currentReactionThreshold
                    if max > 0 then
                        local pct = (current / max) * 100
                        GameTooltip:AddDoubleLine("Progress:",
                            string.format("%s / %s (%.1f%%)", AbbreviateNumber(current), AbbreviateNumber(max), pct),
                            1, 1, 1, 0.8, 0.8, 0.8)
                    end
                end

                -- Paragon info
                if C_Reputation.IsFactionParagon(data.factionID) then
                    local currentValue, threshold, _, hasReward = C_Reputation.GetFactionParagonInfo(data.factionID)
                    if currentValue and threshold then
                        local paragonProgress = currentValue % threshold
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddDoubleLine("Paragon:",
                            string.format("%d / %d", paragonProgress, threshold),
                            1, 0.82, 0, 0.8, 0.8, 0.8)
                        if hasReward then
                            GameTooltip:AddLine("|cFF00FF00Reward available!|r")
                        end
                    end
                end

                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Click to open Reputation", 0.5, 0.5, 1)
            else
                GameTooltip:SetText("Reputation", 1, 1, 1)
                GameTooltip:AddLine("No watched faction", 0.7, 0.7, 0.7)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Click to open Reputation", 0.5, 0.5, 1)
            end
        end

        GameTooltip:Show()
    end)
    xpRepFrame:SetScript("OnLeave", GameTooltip_Hide)

    xpRepFrame:SetScript("OnClick", function(self, button)
        if button == "LeftButton" and not InCombatLockdown() then
            if isMaxLevel then
                ToggleCharacter("ReputationFrame")
            else
                ToggleCharacter("PaperDollFrame")
            end
        end
    end)

    xpRepFrame.UpdateContent = function(self)
        self.text:SetText(cachedText)
    end
end)
