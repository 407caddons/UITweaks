local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

table.insert(Widgets.moduleInits, function()
    local rcFrame = Widgets.CreateWidgetFrame("ReadyCheck", "readyCheck")

    -- Session-only history: list of { time, results = { {name, ready} } }
    local history = {}
    local MAX_HISTORY = 5

    -- State for the current in-progress ready check
    local pending = nil  -- { startTime, responses = { [name] = ready } }

    local cachedText = "|cFF888888Ready Check|r"

    local function UpdateCachedText()
        if not pending and #history == 0 then
            cachedText = "|cFF888888Ready Check|r"
            return
        end

        -- Use latest completed check, or pending state
        local latest = history[#history]
        if pending then
            -- Count responses so far
            local readyCount, totalCount = 0, 0
            for _, ready in pairs(pending.responses) do
                totalCount = totalCount + 1
                if ready then readyCount = readyCount + 1 end
            end
            local groupSize = GetNumGroupMembers()
            cachedText = string.format("RC: %d/%d", readyCount, groupSize > 0 and groupSize or totalCount)
        elseif latest then
            local readyCount, notReadyCount = 0, 0
            for _, r in ipairs(latest.results) do
                if r.ready then readyCount = readyCount + 1
                else notReadyCount = notReadyCount + 1 end
            end
            if notReadyCount == 0 then
                cachedText = "|cFF00FF00RC: All Ready|r"
            else
                cachedText = string.format("|cFFFF4444RC: %d not ready|r", notReadyCount)
            end
        end
    end

    local function OnReadyCheck(event, initiatedBy, text)
        -- New ready check started — reset pending state
        pending = { startTime = GetTime(), responses = {} }
        -- Record player's own response as unknown until they respond
        UpdateCachedText()
    end

    local function OnReadyCheckResponse(event, name, ready)
        if not pending then return end
        -- name is the shortened unit name
        pending.responses[name] = ready
        UpdateCachedText()
    end

    local function OnReadyCheckFinished()
        if not pending then return end

        -- Build result list from pending responses
        local results = {}
        for name, ready in pairs(pending.responses) do
            table.insert(results, { name = name, ready = ready })
        end

        -- Sort: not-ready first, then ready, alphabetically within each group
        table.sort(results, function(a, b)
            if a.ready ~= b.ready then return not a.ready end
            return a.name < b.name
        end)

        table.insert(history, { time = GetTime(), results = results })
        if #history > MAX_HISTORY then table.remove(history, 1) end

        pending = nil
        UpdateCachedText()
    end

    rcFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("READY_CHECK", OnReadyCheck, "W:ReadyCheck")
            EventBus.Register("READY_CHECK_RESPONSE", OnReadyCheckResponse, "W:ReadyCheck")
            EventBus.Register("READY_CHECK_FINISHED", OnReadyCheckFinished, "W:ReadyCheck")
            UpdateCachedText()
        else
            EventBus.Unregister("READY_CHECK", OnReadyCheck)
            EventBus.Unregister("READY_CHECK_RESPONSE", OnReadyCheckResponse)
            EventBus.Unregister("READY_CHECK_FINISHED", OnReadyCheckFinished)
            cachedText = "|cFF888888Ready Check|r"
        end
    end

    local function FormatAge(seconds)
        if seconds < 60 then return string.format("%ds ago", math.floor(seconds))
        elseif seconds < 3600 then return string.format("%dm ago", math.floor(seconds / 60))
        else return string.format("%dh ago", math.floor(seconds / 3600)) end
    end

    rcFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Ready Check History", 1, 0.82, 0)

        if pending then
            local readyCount, notReadyCount = 0, 0
            for _, ready in pairs(pending.responses) do
                if ready then readyCount = readyCount + 1
                else notReadyCount = notReadyCount + 1 end
            end
            local groupSize = GetNumGroupMembers()
            GameTooltip:AddLine(string.format("In progress: %d/%d responded",
                readyCount + notReadyCount, groupSize), 1, 1, 0)
            GameTooltip:AddLine(" ")
        end

        if #history == 0 then
            GameTooltip:AddLine("No ready checks this session.", 0.6, 0.6, 0.6)
        else
            for i = #history, 1, -1 do
                local check = history[i]
                local age = FormatAge(GetTime() - check.time)

                local readyCount, notReadyCount = 0, 0
                for _, r in ipairs(check.results) do
                    if r.ready then readyCount = readyCount + 1
                    else notReadyCount = notReadyCount + 1 end
                end

                local total = readyCount + notReadyCount
                if notReadyCount == 0 then
                    GameTooltip:AddDoubleLine(
                        string.format("Check #%d (%s)", #history - i + 1, age),
                        string.format("|cFF00FF00All Ready (%d/%d)|r", readyCount, total),
                        0.8, 0.8, 0.8, 1, 1, 1)
                else
                    GameTooltip:AddDoubleLine(
                        string.format("Check #%d (%s)", #history - i + 1, age),
                        string.format("|cFFFF4444%d not ready|r  |cFF00FF00%d ready|r", notReadyCount, readyCount),
                        0.8, 0.8, 0.8, 1, 1, 1)
                end

                -- Show not-ready players first
                for _, r in ipairs(check.results) do
                    if not r.ready then
                        GameTooltip:AddLine("  |cFFFF4444✗|r " .. r.name, 1, 0.4, 0.4)
                    end
                end
                -- Then ready players, but only if there aren't too many
                if readyCount <= 10 then
                    for _, r in ipairs(check.results) do
                        if r.ready then
                            GameTooltip:AddLine("  |cFF00FF00✓|r " .. r.name, 0.4, 1, 0.4)
                        end
                    end
                else
                    GameTooltip:AddLine(string.format("  |cFF00FF00✓|r %d others ready", readyCount), 0.4, 1, 0.4)
                end

                if i > 1 then GameTooltip:AddLine(" ") end
            end
        end

        GameTooltip:Show()
    end)

    rcFrame:SetScript("OnLeave", GameTooltip_Hide)

    rcFrame.UpdateContent = function(self)
        self.text:SetText(cachedText)
    end
end)
