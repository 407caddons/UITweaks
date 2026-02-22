local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

table.insert(Widgets.moduleInits, function()
    local lockoutFrame = Widgets.CreateWidgetFrame("Lockouts", "lockouts")
    lockoutFrame:RegisterForClicks("AnyUp")

    local cachedText = "Locks: 0"

    local function FormatTimeShort(seconds)
        if not seconds or seconds <= 0 then return "Expired" end
        local days = math.floor(seconds / 86400)
        local hours = math.floor((seconds % 86400) / 3600)
        if days > 0 then
            return string.format("%dd %dh", days, hours)
        elseif hours > 0 then
            local mins = math.floor((seconds % 3600) / 60)
            return string.format("%dh %dm", hours, mins)
        else
            local mins = math.floor(seconds / 60)
            return string.format("%dm", mins)
        end
    end

    local function RefreshLockoutCache()
        local numInstances = GetNumSavedInstances()
        local lockedCount = 0
        for i = 1, numInstances do
            local _, _, _, _, locked, extended = GetSavedInstanceInfo(i)
            if locked or extended then
                lockedCount = lockedCount + 1
            end
        end
        cachedText = string.format("Locks: %d", lockedCount)
    end

    local function OnLockoutUpdate()
        if not UIThingsDB.widgets.lockouts.enabled then return end
        RefreshLockoutCache()
    end

    local function OnLockoutEnteringWorld()
        if not UIThingsDB.widgets.lockouts.enabled then return end
        RequestRaidInfo()
        C_Timer.After(2, function()
            if UIThingsDB.widgets.lockouts.enabled then
                RefreshLockoutCache()
            end
        end)
    end

    lockoutFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("UPDATE_INSTANCE_INFO", OnLockoutUpdate)
            EventBus.Register("PLAYER_ENTERING_WORLD", OnLockoutEnteringWorld)
            RequestRaidInfo()
            RefreshLockoutCache()
        else
            EventBus.Unregister("UPDATE_INSTANCE_INFO", OnLockoutUpdate)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnLockoutEnteringWorld)
        end
    end

    lockoutFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Instance Lockouts", 1, 1, 1)

        local numInstances = GetNumSavedInstances()
        if numInstances == 0 then
            GameTooltip:AddLine("No saved instances", 0.7, 0.7, 0.7)
            GameTooltip:Show()
            return
        end

        local raids = {}
        local dungeons = {}

        for i = 1, numInstances do
            local name, _, reset, _, locked, extended, _, isRaid, _, difficultyName, numEncounters, encounterProgress =
            GetSavedInstanceInfo(i)
            if locked or extended then
                local entry = {
                    index = i,
                    name = name,
                    reset = reset,
                    difficultyName = difficultyName,
                    numEncounters = numEncounters,
                    encounterProgress = encounterProgress,
                    extended = extended,
                }
                if isRaid then
                    table.insert(raids, entry)
                else
                    table.insert(dungeons, entry)
                end
            end
        end

        if #raids > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Raids", 1, 0.82, 0)
            for _, entry in ipairs(raids) do
                local resetText = FormatTimeShort(entry.reset)
                if entry.extended then resetText = resetText .. " (ext)" end
                GameTooltip:AddDoubleLine(
                    string.format("%s (%s)", entry.name, entry.difficultyName),
                    string.format("%d/%d - %s", entry.encounterProgress, entry.numEncounters, resetText),
                    1, 1, 1, 0.8, 0.8, 0.8
                )
                -- Show individual boss status
                for j = 1, entry.numEncounters do
                    local bossName, _, isKilled = GetSavedInstanceEncounterInfo(entry.index, j)
                    if bossName then
                        if isKilled then
                            GameTooltip:AddDoubleLine("  " .. bossName, "Defeated", 0.5, 0.5, 0.5, 0, 1, 0)
                        else
                            GameTooltip:AddDoubleLine("  " .. bossName, "Alive", 0.8, 0.8, 0.8, 1, 0.3, 0.3)
                        end
                    end
                end
            end
        end

        if #dungeons > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Dungeons", 1, 0.82, 0)
            for _, entry in ipairs(dungeons) do
                local resetText = FormatTimeShort(entry.reset)
                if entry.extended then resetText = resetText .. " (ext)" end
                GameTooltip:AddDoubleLine(
                    string.format("%s (%s)", entry.name, entry.difficultyName),
                    string.format("%d/%d - %s", entry.encounterProgress, entry.numEncounters, resetText),
                    1, 1, 1, 0.8, 0.8, 0.8
                )
            end
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to open Raid Info", 0.5, 0.5, 1)
        GameTooltip:Show()
    end)
    lockoutFrame:SetScript("OnLeave", GameTooltip_Hide)

    lockoutFrame:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if RaidInfoFrame and RaidInfoFrame:IsShown() then
                RaidInfoFrame:Hide()
            else
                ToggleFriendsFrame(3)
                if RaidInfoFrame and not RaidInfoFrame:IsShown() then
                    RaidInfoFrame:Show()
                    RequestRaidInfo()
                end
            end
        end
    end)

    lockoutFrame.UpdateContent = function(self)
        self.text:SetText(cachedText)
    end
end)
