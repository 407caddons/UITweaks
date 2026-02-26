local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

table.insert(Widgets.moduleInits, function()
    local ratingFrame = Widgets.CreateWidgetFrame("MythicRating", "mythicRating")

    -- Cached rating (updated on events)
    local cachedText = "M+ —"
    local cachedScore = 0

    local function RefreshRatingCache()
        cachedScore = C_ChallengeMode.GetOverallDungeonScore() or 0
        if cachedScore > 0 then
            local color = C_ChallengeMode.GetDungeonScoreRarityColor(cachedScore)
            if color then
                cachedText = string.format("|cFF%02x%02x%02xM+ %d|r", color.r * 255, color.g * 255, color.b * 255,
                    cachedScore)
            else
                cachedText = string.format("M+ %d", cachedScore)
            end
        else
            cachedText = "M+ —"
        end
    end

    local function OnRatingUpdate()
        RefreshRatingCache()
    end

    local function OnRatingEnteringWorld()
        -- Request map data so CHALLENGE_MODE_MAPS_UPDATE fires with real scores
        C_MythicPlus.RequestMapInfo()
        RefreshRatingCache()
    end

    ratingFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("CHALLENGE_MODE_MAPS_UPDATE", OnRatingUpdate, "W:MythicRating")
            EventBus.Register("CHALLENGE_MODE_COMPLETED", OnRatingUpdate, "W:MythicRating")
            EventBus.Register("PLAYER_ENTERING_WORLD", OnRatingEnteringWorld, "W:MythicRating")
            EventBus.Register("MYTHIC_PLUS_NEW_WEEKLY_RECORD", OnRatingUpdate, "W:MythicRating")
        else
            EventBus.Unregister("CHALLENGE_MODE_MAPS_UPDATE", OnRatingUpdate)
            EventBus.Unregister("CHALLENGE_MODE_COMPLETED", OnRatingUpdate)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnRatingEnteringWorld)
            EventBus.Unregister("MYTHIC_PLUS_NEW_WEEKLY_RECORD", OnRatingUpdate)
        end
    end

    ratingFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Mythic+ Rating")

        -- Current rating
        local score = C_ChallengeMode.GetOverallDungeonScore() or 0
        local color = C_ChallengeMode.GetDungeonScoreRarityColor(score)
        if color then
            GameTooltip:AddDoubleLine("Current Rating:", tostring(score), 1, 1, 1, color.r, color.g, color.b)
        else
            GameTooltip:AddDoubleLine("Current Rating:", tostring(score), 1, 1, 1, 1, 1, 1)
        end

        -- Season best
        local seasonBest = C_MythicPlus.GetSeasonBestMythicRatingFromThisExpansion()
        if seasonBest and seasonBest > 0 then
            GameTooltip:AddDoubleLine("Season Best:", tostring(math.floor(seasonBest)), 1, 1, 1, 0.8, 0.8, 0.8)
        end

        -- Dungeon breakdown
        local mapTable = C_ChallengeMode.GetMapTable()
        if mapTable and #mapTable > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Dungeon Scores", 1, 0.82, 0)

            for _, mapID in ipairs(mapTable) do
                local name = C_ChallengeMode.GetMapUIInfo(mapID)
                if name then
                    -- GetSeasonBestForMap returns (intimeInfo, overtimeInfo)
                    local intimeInfo, overtimeInfo = C_MythicPlus.GetSeasonBestForMap(mapID)
                    local bestScore, bestLevel = 0, nil
                    if intimeInfo and intimeInfo.dungeonScore and intimeInfo.dungeonScore > bestScore then
                        bestScore = intimeInfo.dungeonScore
                        bestLevel = intimeInfo.level
                    end
                    if overtimeInfo and overtimeInfo.dungeonScore and overtimeInfo.dungeonScore > bestScore then
                        bestScore = overtimeInfo.dungeonScore
                        bestLevel = overtimeInfo.level
                    end

                    if bestScore > 0 then
                        local mapColor = C_ChallengeMode.GetSpecificDungeonScoreRarityColor(bestScore)
                        -- Build right-side string: highest timed level + score
                        local timedLevel = intimeInfo and intimeInfo.level
                        local rightStr
                        if timedLevel then
                            -- Show timed key level prominently; append score
                            rightStr = string.format("+%d timed (%d)", timedLevel, bestScore)
                        elseif bestLevel then
                            -- Overtime only — flag it
                            rightStr = string.format("+%d ot (%d)", bestLevel, bestScore)
                        else
                            rightStr = string.format("(%d)", bestScore)
                        end
                        if mapColor then
                            GameTooltip:AddDoubleLine(
                                name,
                                rightStr,
                                1, 1, 1,
                                mapColor.r, mapColor.g, mapColor.b)
                        else
                            GameTooltip:AddDoubleLine(name, rightStr, 1, 1, 1, 0.8, 0.8, 0.8)
                        end
                    else
                        GameTooltip:AddDoubleLine(name, "No runs", 1, 1, 1, 0.5, 0.5, 0.5)
                    end
                end
            end
        end

        -- Party key estimates
        if IsInGroup() and addonTable.AddonVersions then
            local playerData = addonTable.AddonVersions.GetPlayerData()
            local playerName = UnitName("player")
            local hasEstimates = false

            -- Check if anyone has a key with mapID
            for name, data in pairs(playerData) do
                if data and data.keystoneMapID and data.keystoneLevel and data.keystoneLevel > 0 then
                    hasEstimates = true
                    break
                end
            end

            if hasEstimates then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Party Key Estimates (est. timed)", 1, 0.82, 0)

                -- Player first
                local selfData = playerData[playerName]
                if selfData and selfData.keystoneMapID and selfData.keystoneLevel and selfData.keystoneLevel > 0 then
                    local gain, estScore, currentBest = Widgets.EstimateRatingGain(selfData.keystoneMapID,
                        selfData.keystoneLevel)
                    local keyText = string.format("+%d %s", selfData.keystoneLevel, selfData.keystoneName or "?")
                    if gain > 0 then
                        GameTooltip:AddDoubleLine(keyText, string.format("+%d rating", gain), 0, 1, 0.5, 0, 1, 0)
                    else
                        GameTooltip:AddDoubleLine(keyText, "no upgrade", 0.5, 0.5, 0.5, 0.5, 0.5, 0.5)
                    end
                end

                -- Other party members
                local names = {}
                for name in pairs(playerData) do
                    if name ~= playerName then
                        table.insert(names, name)
                    end
                end
                table.sort(names)

                for _, name in ipairs(names) do
                    local data = playerData[name]
                    if data and data.keystoneMapID and data.keystoneLevel and data.keystoneLevel > 0 then
                        local gain = Widgets.EstimateRatingGain(data.keystoneMapID, data.keystoneLevel)
                        local keyText = string.format("%s: +%d %s", name, data.keystoneLevel, data.keystoneName or "?")
                        if gain > 0 then
                            GameTooltip:AddDoubleLine(keyText, string.format("+%d rating", gain), 1, 1, 1, 0, 1, 0)
                        else
                            GameTooltip:AddDoubleLine(keyText, "no upgrade", 1, 1, 1, 0.5, 0.5, 0.5)
                        end
                    end
                end
            end
        end

        GameTooltip:Show()
    end)
    ratingFrame:SetScript("OnLeave", GameTooltip_Hide)

    ratingFrame.UpdateContent = function(self)
        self.text:SetText(cachedText)
    end
end)
