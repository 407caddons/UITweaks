local addonName, addonTable = ...
local Widgets = addonTable.Widgets

table.insert(Widgets.moduleInits, function()
    local pullFrame = Widgets.CreateWidgetFrame("PullCounter", "pullCounter")
    pullFrame:RegisterForClicks("AnyUp")

    -- Session-only data (not saved to UIThingsDB)
    local sessionData = {
        totalPulls = 0,
        currentEncounter = nil, -- { id, name, startTime }
        bosses = {},            -- keyed by encounterID
    }

    local cachedText = "Pulls: 0"

    local function RefreshCache()
        if sessionData.currentEncounter then
            cachedText = string.format("|cFFFF0000%s|r", sessionData.currentEncounter.name)
        else
            cachedText = string.format("Pulls: %d", sessionData.totalPulls)
        end
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ENCOUNTER_START")
    eventFrame:RegisterEvent("ENCOUNTER_END")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if not UIThingsDB.widgets.pullCounter.enabled then return end

        if event == "ENCOUNTER_START" then
            local encounterID, encounterName, difficultyID, groupSize = ...
            sessionData.totalPulls = sessionData.totalPulls + 1

            if not sessionData.bosses[encounterID] then
                sessionData.bosses[encounterID] = {
                    name = encounterName,
                    pulls = 0,
                    kills = 0,
                    wipes = 0,
                    bestTime = nil,
                }
            end

            local boss = sessionData.bosses[encounterID]
            boss.pulls = boss.pulls + 1
            boss.lastPullStart = GetTime()

            sessionData.currentEncounter = {
                id = encounterID,
                name = encounterName,
                startTime = GetTime(),
            }
            RefreshCache()
        elseif event == "ENCOUNTER_END" then
            local encounterID, encounterName, difficultyID, groupSize, success = ...
            local boss = sessionData.bosses[encounterID]

            if boss and boss.lastPullStart then
                local duration = GetTime() - boss.lastPullStart
                if success == 1 then
                    boss.kills = boss.kills + 1
                    if not boss.bestTime or duration < boss.bestTime then
                        boss.bestTime = duration
                    end
                else
                    boss.wipes = boss.wipes + 1
                end
                boss.lastPullStart = nil
            end

            sessionData.currentEncounter = nil
            RefreshCache()
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Clear stale encounter on reload (GetTime epoch resets)
            sessionData.currentEncounter = nil
            RefreshCache()
        end
    end)

    pullFrame.eventFrame = eventFrame
    pullFrame.ApplyEvents = function(enabled)
        if enabled then
            eventFrame:RegisterEvent("ENCOUNTER_START")
            eventFrame:RegisterEvent("ENCOUNTER_END")
            eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        else
            eventFrame:UnregisterAllEvents()
        end
    end

    pullFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Pull Counter", 1, 1, 1)
        GameTooltip:AddDoubleLine("Total Pulls:", tostring(sessionData.totalPulls), 1, 1, 1, 1, 1, 1)

        local hasBosses = false
        for encounterID, boss in pairs(sessionData.bosses) do
            if not hasBosses then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Boss Breakdown", 1, 0.82, 0)
                hasBosses = true
            end

            local parts = { string.format("%d pull(s)", boss.pulls) }
            if boss.kills > 0 then
                table.insert(parts, string.format("|cFF00FF00%d kill(s)|r", boss.kills))
            end
            if boss.wipes > 0 then
                table.insert(parts, string.format("|cFFFF0000%d wipe(s)|r", boss.wipes))
            end

            GameTooltip:AddLine(boss.name, 1, 1, 1)
            GameTooltip:AddLine("  " .. table.concat(parts, ", "), 0.8, 0.8, 0.8)

            if boss.bestTime then
                local m = math.floor(boss.bestTime / 60)
                local s = math.floor(boss.bestTime % 60)
                GameTooltip:AddLine(string.format("  Best kill: %d:%02d", m, s), 0, 1, 0)
            end
        end

        if not hasBosses then
            GameTooltip:AddLine("No encounters this session", 0.7, 0.7, 0.7)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Right-Click to reset", 0.5, 0.5, 1)
        GameTooltip:Show()
    end)
    pullFrame:SetScript("OnLeave", GameTooltip_Hide)

    pullFrame:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            sessionData.totalPulls = 0
            sessionData.currentEncounter = nil
            wipe(sessionData.bosses)
            cachedText = "Pulls: 0"
            self.text:SetText(cachedText)
            GameTooltip:Hide()
        end
    end)

    pullFrame.UpdateContent = function(self)
        if sessionData.currentEncounter then
            local elapsed = GetTime() - sessionData.currentEncounter.startTime
            local m = math.floor(elapsed / 60)
            local s = math.floor(elapsed % 60)
            self.text:SetFormattedText("|cFFFF0000%s %d:%02d|r", sessionData.currentEncounter.name, m, s)
        else
            self.text:SetText(cachedText)
        end
    end
end)
