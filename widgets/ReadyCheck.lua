local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

table.insert(Widgets.moduleInits, function()
    local rcFrame = Widgets.CreateWidgetFrame("ReadyCheck", "readyCheck")
    rcFrame:RegisterForClicks("AnyUp")

    local checkActive = false
    local memberStatus = {}  -- [shortName] = "ready" | "notready" | "unknown"
    local groupSize = 0
    local cachedText = "|cFF888888Ready Check|r"

    -- Combat-safe name cache: UnitName() returns secret strings during combat,
    -- which cannot be used as table keys. Cache is refreshed on roster changes
    -- outside combat and on PLAYER_REGEN_ENABLED.
    local nameCache = {} -- [unit] = shortName
    local cachedPlayerShort = nil

    local function GetShortName(name)
        if not name then return nil end
        return name:match("^([^%-]+)") or name
    end

    local function RefreshNameCache()
        if InCombatLockdown() then return end
        wipe(nameCache)
        cachedPlayerShort = GetShortName(UnitName("player"))
        nameCache["player"] = cachedPlayerShort
        local members = GetNumGroupMembers()
        if IsInRaid() then
            for i = 1, members do
                local raidName = GetRaidRosterInfo(i)
                if raidName then
                    nameCache["raid" .. i] = GetShortName(raidName)
                end
            end
        elseif IsInGroup() then
            for i = 1, members - 1 do
                local name = UnitName("party" .. i)
                if name then
                    nameCache["party" .. i] = GetShortName(name)
                end
            end
        end
    end

    local function GetPlayerShortName()
        return cachedPlayerShort or GetShortName(UnitName("player"))
    end

    local function UpdateCachedText()
        if not checkActive and not next(memberStatus) then
            cachedText = "|cFF888888Ready Check|r"
            return
        end

        local ready, notReady, unknown = 0, 0, 0
        for _, status in pairs(memberStatus) do
            if status == "ready" then
                ready = ready + 1
            elseif status == "notready" then
                notReady = notReady + 1
            else
                unknown = unknown + 1
            end
        end

        local total = groupSize > 0 and groupSize or (ready + notReady + unknown)
        local prefix = total > 0 and (total .. "m ") or ""

        if notReady == 0 and unknown == 0 then
            cachedText = string.format("|cFF00FF00RC: %s%d/0/0|r", prefix, ready)
        else
            cachedText = string.format("RC: %s|cFF00FF00%d|r/|cFFFF4444%d|r/|cFF888888%d|r",
                prefix, ready, notReady, unknown)
        end
    end

    local function PopulateGroupMembers()
        wipe(memberStatus)
        groupSize = GetNumGroupMembers()
        local playerName = GetPlayerShortName()
        -- Refresh cache if possible (may be stale if roster changed mid-combat)
        if not InCombatLockdown() then
            RefreshNameCache()
        end

        if IsInRaid() then
            for i = 1, groupSize do
                -- GetRaidRosterInfo returns non-secret names from the roster cache
                local name = GetRaidRosterInfo(i)
                if name then
                    local short = GetShortName(name)
                    memberStatus[short] = (short == playerName) and "ready" or "unknown"
                end
            end
        elseif IsInGroup() then
            -- Player is always ready
            memberStatus[playerName] = "ready"
            -- Use cached names for party members (UnitName returns secrets in combat)
            for i = 1, groupSize - 1 do
                local short = nameCache["party" .. i]
                if short then
                    memberStatus[short] = "unknown"
                end
            end
        end
    end

    local function OnReadyCheck(event, initiatedBy, waitTime)
        checkActive = true
        PopulateGroupMembers()
        -- Initiator is auto-ready and never fires READY_CHECK_CONFIRM
        if initiatedBy then
            local initShort = GetShortName(initiatedBy)
            if initShort and memberStatus[initShort] then
                memberStatus[initShort] = "ready"
            end
        end
        UpdateCachedText()
    end

    local function OnReadyCheckResponse(event, unit, isReady)
        if not checkActive then return end
        -- Use cached name to avoid secret-value-as-table-key errors during combat
        local short = nameCache[unit]
        if not short then return end
        -- Never override player's own "ready" status
        if short == GetPlayerShortName() then return end
        memberStatus[short] = isReady and "ready" or "notready"
        UpdateCachedText()
    end

    local function OnReadyCheckFinished()
        checkActive = false
        UpdateCachedText()
    end

    rcFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("GROUP_ROSTER_UPDATE", RefreshNameCache, "W:ReadyCheck")
            EventBus.Register("PLAYER_ENTERING_WORLD", RefreshNameCache, "W:ReadyCheck")
            EventBus.Register("PLAYER_REGEN_ENABLED", RefreshNameCache, "W:ReadyCheck")
            EventBus.Register("READY_CHECK", OnReadyCheck, "W:ReadyCheck")
            EventBus.Register("READY_CHECK_CONFIRM", OnReadyCheckResponse, "W:ReadyCheck")
            EventBus.Register("READY_CHECK_FINISHED", OnReadyCheckFinished, "W:ReadyCheck")
        else
            EventBus.Unregister("GROUP_ROSTER_UPDATE", RefreshNameCache)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", RefreshNameCache)
            EventBus.Unregister("PLAYER_REGEN_ENABLED", RefreshNameCache)
            EventBus.Unregister("READY_CHECK", OnReadyCheck)
            EventBus.Unregister("READY_CHECK_CONFIRM", OnReadyCheckResponse)
            EventBus.Unregister("READY_CHECK_FINISHED", OnReadyCheckFinished)
            checkActive = false
            wipe(memberStatus)
            wipe(nameCache)
            groupSize = 0
            cachedText = "|cFF888888Ready Check|r"
        end
    end

    rcFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        if not Widgets.SmartAnchorTooltip(self) then return end
        GameTooltip:SetText("Ready Check", 1, 0.82, 0)

        if not next(memberStatus) then
            GameTooltip:AddLine("No ready check data this session.", 0.6, 0.6, 0.6)
        else
            -- Count summary header
            local ready, notReady, unknown = 0, 0, 0
            for _, status in pairs(memberStatus) do
                if status == "ready" then ready = ready + 1
                elseif status == "notready" then notReady = notReady + 1
                else unknown = unknown + 1 end
            end
            GameTooltip:AddDoubleLine(
                string.format("|cFF00FF00Ready: %d|r", ready),
                string.format("|cFFFF4444Not Ready: %d|r  |cFF888888Unknown: %d|r", notReady, unknown),
                1, 1, 1, 1, 1, 1)
            GameTooltip:AddLine(" ")

            -- Sort: ready first, then not ready, then unknown; alphabetically within each
            local sorted = {}
            for name, status in pairs(memberStatus) do
                table.insert(sorted, { name = name, status = status })
            end
            table.sort(sorted, function(a, b)
                local order = { ready = 1, notready = 2, unknown = 3 }
                local oa = order[a.status] or 4
                local ob = order[b.status] or 4
                if oa ~= ob then return oa < ob end
                return a.name < b.name
            end)

            for _, entry in ipairs(sorted) do
                local statusStr
                if entry.status == "ready" then
                    statusStr = "|cFF00FF00Ready|r"
                elseif entry.status == "notready" then
                    statusStr = "|cFFFF4444Not ready|r"
                else
                    statusStr = "|cFF888888Unknown|r"
                end
                GameTooltip:AddDoubleLine(entry.name, statusStr, 0.9, 0.9, 0.9, 1, 1, 1)
            end
        end

        GameTooltip:AddLine(" ")
        if checkActive then
            GameTooltip:AddLine("Ready check in progress...", 1, 1, 0)
        elseif IsInGroup() then
            GameTooltip:AddLine("Click to start a ready check", 0.5, 0.5, 1)
        end

        GameTooltip:Show()
    end)

    rcFrame:SetScript("OnLeave", GameTooltip_Hide)

    rcFrame:SetScript("OnClick", function(self, button)
        if button == "LeftButton" and UIThingsDB.widgets.locked then
            if IsInGroup() and not checkActive then
                DoReadyCheck()
            end
        end
    end)

    rcFrame.UpdateContent = function(self)
        self.text:SetText(cachedText)
    end
end)
