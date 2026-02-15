local addonName, addonTable = ...
local Widgets = addonTable.Widgets

table.insert(Widgets.moduleInits, function()
    local vaultFrame = Widgets.CreateWidgetFrame("Vault", "vault")
    vaultFrame:RegisterForClicks("AnyUp")

    -- Activities = M+ dungeons, Raid = raids, World = delves/world content
    local ACTIVITY_TYPES = {
        { type = Enum.WeeklyRewardChestThresholdType.Activities, label = "Mythic+" },
        { type = Enum.WeeklyRewardChestThresholdType.Raid,       label = "Raid" },
        { type = Enum.WeeklyRewardChestThresholdType.World,      label = "Delves" },
    }

    local cachedText = "Vault: ..."

    local function RefreshVaultCache()
        local totalUnlocked = 0
        for _, actType in ipairs(ACTIVITY_TYPES) do
            local activities = C_WeeklyRewards.GetActivities(actType.type)
            if activities and #activities > 0 then
                table.sort(activities, function(a, b) return a.index < b.index end)
                for i = 1, math.min(#activities, 3) do
                    local act = activities[i]
                    if act.progress >= act.threshold and act.threshold > 0 then
                        totalUnlocked = totalUnlocked + 1
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

                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(actType.label, 1, 0.82, 0)

                for i = 1, math.min(#activities, 3) do
                    local act = activities[i]
                    local label = tierLabels[i] or ("Slot " .. i)
                    local progress = math.min(act.progress, act.threshold)
                    local complete = act.progress >= act.threshold and act.threshold > 0
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
