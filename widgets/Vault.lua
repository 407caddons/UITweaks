local addonName, addonTable = ...
local Widgets = addonTable.Widgets

table.insert(Widgets.moduleInits, function()
    local vaultFrame = Widgets.CreateWidgetFrame("Vault", "vault")
    vaultFrame:RegisterForClicks("AnyUp")

    local ACTIVITY_TYPES = {
        { type = Enum.WeeklyRewardChestThresholdType.MythicPlus, label = "Mythic+" },
        { type = Enum.WeeklyRewardChestThresholdType.Activities, label = "Raid / Delves" },
        { type = Enum.WeeklyRewardChestThresholdType.RankedPvP,  label = "PvP" },
    }

    -- Known raid instance IDs for TWW
    local RAID_INSTANCE_IDS = {
        [2657] = true, -- Nerub-ar Palace
        [2769] = true, -- Blackrock Depths (raid)
        [2822] = true, -- Liberation of Undermine
    }

    -- Minimum combined progress needed for each Activities slot
    -- The API reports threshold=1 internally, but the actual vault requires 2/4/6 (raid) or 2/4/8 (delves)
    local ACTIVITIES_THRESHOLDS = { 2, 4, 6 }

    local cachedText = "Vault: ..."

    local function RefreshVaultCache()
        local totalUnlocked = 0
        for _, actType in ipairs(ACTIVITY_TYPES) do
            local activities = C_WeeklyRewards.GetActivities(actType.type)
            if activities and #activities > 0 then
                table.sort(activities, function(a, b) return a.index < b.index end)

                if actType.type == Enum.WeeklyRewardChestThresholdType.Activities then
                    -- Use our own thresholds since the API's are wrong for the combined row
                    local progress = activities[1] and activities[1].progress or 0
                    for i = 1, 3 do
                        if progress >= ACTIVITIES_THRESHOLDS[i] then
                            totalUnlocked = totalUnlocked + 1
                        end
                    end
                else
                    for i = 1, math.min(#activities, 3) do
                        local act = activities[i]
                        if act.progress >= act.threshold and act.threshold > 0 then
                            totalUnlocked = totalUnlocked + 1
                        end
                    end
                end
            end
        end
        cachedText = string.format("Vault: %d/9", totalUnlocked)
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    eventFrame:RegisterEvent("ENCOUNTER_END")
    eventFrame:SetScript("OnEvent", function(self, event)
        if not UIThingsDB.widgets.vault.enabled then return end
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(2, function()
                if UIThingsDB.widgets.vault.enabled then
                    RefreshVaultCache()
                end
            end)
        else
            RefreshVaultCache()
        end
    end)

    vaultFrame.eventFrame = eventFrame
    vaultFrame.ApplyEvents = function(enabled)
        if enabled then
            eventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
            eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
            eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
            eventFrame:RegisterEvent("ENCOUNTER_END")
            RefreshVaultCache()
        else
            eventFrame:UnregisterAllEvents()
        end
    end

    vaultFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Great Vault Progress", 1, 1, 1)

        local tierLabels = { "1st Slot", "2nd Slot", "3rd Slot" }

        for _, actType in ipairs(ACTIVITY_TYPES) do
            local activities = C_WeeklyRewards.GetActivities(actType.type)
            if activities and #activities > 0 then
                table.sort(activities, function(a, b) return a.index < b.index end)

                if actType.type == Enum.WeeklyRewardChestThresholdType.Activities then
                    -- Collect encounters from all unlocked slots
                    local raidKills = {}
                    local delveRuns = {}

                    for i = 1, math.min(#activities, 3) do
                        local encounters = C_WeeklyRewards.GetActivityEncounterInfo(actType.type, activities[i].index)
                        if encounters then
                            for _, encounter in ipairs(encounters) do
                                if encounter.name then
                                    if encounter.instanceID and RAID_INSTANCE_IDS[encounter.instanceID] then
                                        raidKills[encounter.name] = true
                                    else
                                        delveRuns[encounter.name] = (delveRuns[encounter.name] or 0) + 1
                                    end
                                end
                            end
                        end
                    end

                    -- Use progress from the API for the combined count
                    local firstAct = activities[1]
                    local totalProgress = firstAct and firstAct.progress or 0

                    -- Raid section
                    GameTooltip:AddLine(" ")
                    local raidCount = 0
                    for _ in pairs(raidKills) do raidCount = raidCount + 1 end
                    GameTooltip:AddDoubleLine("Raid (2/4/6)", string.format("%d kills", raidCount), 1, 0.82, 0, 1, 1, 1)
                    for name in pairs(raidKills) do
                        GameTooltip:AddLine("  " .. name, 0.6, 0.6, 0.6)
                    end

                    -- Delve section
                    GameTooltip:AddLine(" ")
                    local delveCount = 0
                    for _, count in pairs(delveRuns) do delveCount = delveCount + count end
                    -- If no encounters returned but API shows progress, it's all pre-unlock progress
                    if delveCount == 0 and raidCount == 0 and totalProgress > 0 then
                        delveCount = totalProgress
                    end
                    GameTooltip:AddDoubleLine("Delves (2/4/8)", string.format("%d runs", delveCount), 1, 0.82, 0, 1, 1, 1)
                    for name, count in pairs(delveRuns) do
                        if count > 1 then
                            GameTooltip:AddLine("  " .. name .. " x" .. count, 0.6, 0.6, 0.6)
                        else
                            GameTooltip:AddLine("  " .. name, 0.6, 0.6, 0.6)
                        end
                    end
                else
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(actType.label, 1, 0.82, 0)

                    for i = 1, math.min(#activities, 3) do
                        local act = activities[i]
                        local label = tierLabels[i] or ("Slot " .. i)
                        local progress = math.min(act.progress, act.threshold)
                        local complete = act.progress >= act.threshold
                        local r, g, b = 1, 1, 1
                        if complete then
                            r, g, b = 0, 1, 0
                        end
                        GameTooltip:AddDoubleLine(
                            label,
                            string.format("%d / %d", progress, act.threshold),
                            1, 1, 1, r, g, b
                        )
                    end
                end
            end
        end

        if C_WeeklyRewards.CanClaimRewards() then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cFF00FF00Rewards available! Visit the Great Vault.|r")
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to open Great Vault", 0.5, 0.5, 1)
        GameTooltip:Show()
    end)
    vaultFrame:SetScript("OnLeave", GameTooltip_Hide)

    vaultFrame:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if not C_AddOns.IsAddOnLoaded("Blizzard_WeeklyRewards") then
                C_AddOns.LoadAddOn("Blizzard_WeeklyRewards")
            end
            if WeeklyRewardsFrame then
                if WeeklyRewardsFrame:IsShown() then
                    HideUIPanel(WeeklyRewardsFrame)
                else
                    ShowUIPanel(WeeklyRewardsFrame)
                end
            end
        end
    end)

    vaultFrame.UpdateContent = function(self)
        self.text:SetText(cachedText)
    end
end)
