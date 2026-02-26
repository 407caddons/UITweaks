local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

table.insert(Widgets.moduleInits, function()
    local sessionFrame = Widgets.CreateWidgetFrame("SessionStats", "sessionStats")
    sessionFrame:RegisterForClicks("AnyUp")

    -- Session data persisted across reloads in UIThingsDB.
    -- Reset if offline for more than 30 minutes or if switching characters.
    local db           = UIThingsDB.widgets.sessionStats
    local TIMEOUT      = 1800 -- 30 minutes in seconds
    local charKey      = UnitGUID("player") or (UnitName("player") or "unknown")

    local isStale = not db.sessionStart
        or not db.lastSeen
        or (time() - db.lastSeen > TIMEOUT)
        or (db.charKey ~= charKey)

    local sessionStart    = isStale and GetTime() or db.sessionStart
    local goldAtLogin     = isStale and 0 or (db.goldAtLogin or 0)
    local goldNeedsSnap   = isStale -- snapshot gold on first PLAYER_ENTERING_WORLD
    local deathCount      = isStale and 0 or (db.deathCount or 0)
    local itemsLooted     = isStale and 0 or (db.itemsLooted or 0)
    local xpAtLogin       = isStale and 0 or (db.xpAtLogin or 0)
    local xpNeedsSnap     = isStale -- snapshot XP on first PLAYER_ENTERING_WORLD

    -- Cached display text updated on events
    local cachedText   = "Session: 0:00"
    local tickCount    = 0
    local CYCLE_TICKS  = 5  -- seconds per display mode

    local function SaveSessionData()
        db.sessionStart = sessionStart
        db.goldAtLogin  = goldAtLogin
        db.deathCount   = deathCount
        db.itemsLooted  = itemsLooted
        db.xpAtLogin    = xpAtLogin
        db.charKey      = charKey
        -- lastSeen is only written on PLAYER_LOGOUT to avoid dirtying SavedVars every second
    end

    local function OnPlayerLogout()
        db.lastSeen = time()
    end

    -- Persist baseline immediately so a /reload right after login retains correct values
    SaveSessionData()

    local function FormatDuration(seconds)
        local h = math.floor(seconds / 3600)
        local m = math.floor((seconds % 3600) / 60)
        if h > 0 then
            return string.format("%d:%02d:%02d", h, m, math.floor(seconds % 60))
        else
            return string.format("%d:%02d", m, math.floor(seconds % 60))
        end
    end

    local function FormatGoldDelta(delta)
        local sign = delta >= 0 and "+" or "-"
        local abs = math.abs(delta)
        local g = math.floor(abs / 10000)
        local s = math.floor((abs % 10000) / 100)
        local c = abs % 100
        if g > 0 then
            return string.format("%s%d|cFFFFD700g|r %d|cFFC0C0C0s|r %d|cFFB87333c|r", sign, g, s, c)
        elseif s > 0 then
            return string.format("%s%d|cFFC0C0C0s|r %d|cFFB87333c|r", sign, s, c)
        else
            return string.format("%s%d|cFFB87333c|r", sign, c)
        end
    end

    -- Format a gold-per-hour rate (copper/hr)
    local function FormatGoldPerHour(copperPerHour)
        if copperPerHour == 0 then return "0|cFFFFD700g|r/hr" end
        local sign = copperPerHour >= 0 and "+" or "-"
        local abs = math.abs(copperPerHour)
        local g = math.floor(abs / 10000)
        local s = math.floor((abs % 10000) / 100)
        if g > 0 then
            return string.format("%s%d|cFFFFD700g|r %d|cFFC0C0C0s|r/hr", sign, g, s)
        else
            return string.format("%s%d|cFFC0C0C0s|r/hr", sign, s)
        end
    end

    local function UpdateCachedText()
        local elapsed = GetTime() - sessionStart

        -- Determine how many display modes are available
        local maxXP = UnitXPMax("player") or 0
        local isLeveling = maxXP > 0 and elapsed > 60
        local hasGoldRate = elapsed > 60
        local numModes = 1 + (hasGoldRate and 1 or 0) + (isLeveling and 1 or 0)

        local mode = math.floor(tickCount / CYCLE_TICKS) % numModes

        if mode == 0 then
            cachedText = "Session: " .. FormatDuration(elapsed)
        elseif mode == 1 then
            -- gold/hr
            local goldDelta = GetMoney() - goldAtLogin
            local goldPerHour = math.floor((goldDelta / elapsed) * 3600)
            cachedText = "Gold/hr: " .. FormatGoldPerHour(goldPerHour)
        else
            -- xp/hr (mode == 2, only reached when isLeveling)
            local currentXP = UnitXP("player") or 0
            local xpDelta = currentXP - xpAtLogin
            if xpDelta > 0 then
                local xpPerHour = math.floor((xpDelta / elapsed) * 3600)
                cachedText = "XP/hr: " .. BreakUpLargeNumbers(xpPerHour)
            else
                cachedText = "Session: " .. FormatDuration(elapsed)
            end
        end
    end

    local function OnPlayerDead()
        if not db.enabled then return end
        deathCount = deathCount + 1
        SaveSessionData()
    end

    local function OnChatMsgLoot(event, msg)
        if not db.enabled then return end
        if msg and not issecretvalue(msg) then
            itemsLooted = itemsLooted + 1
            SaveSessionData()
        end
    end

    -- PLAYER_ENTERING_WORLD fires after character data is loaded — snapshot gold and XP here.
    local function OnSessionEnteringWorld()
        if not db.enabled then return end
        if goldNeedsSnap then
            goldAtLogin = GetMoney()
            goldNeedsSnap = false
        end
        if xpNeedsSnap then
            xpAtLogin = UnitXP("player") or 0
            xpNeedsSnap = false
        end
        SaveSessionData()
        UpdateCachedText()
    end

    sessionFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("PLAYER_DEAD", OnPlayerDead, "W:SessionStats")
            EventBus.Register("CHAT_MSG_LOOT", OnChatMsgLoot, "W:SessionStats")
            EventBus.Register("PLAYER_ENTERING_WORLD", OnSessionEnteringWorld, "W:SessionStats")
            EventBus.Register("PLAYER_LOGOUT", OnPlayerLogout, "W:SessionStats")
            UpdateCachedText()
        else
            EventBus.Unregister("PLAYER_DEAD", OnPlayerDead)
            EventBus.Unregister("CHAT_MSG_LOOT", OnChatMsgLoot)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnSessionEnteringWorld)
            EventBus.Unregister("PLAYER_LOGOUT", OnPlayerLogout)
        end
    end

    -- Right-click resets session counters
    sessionFrame:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            sessionStart    = GetTime()
            goldAtLogin     = GetMoney()
            goldNeedsSnap   = false
            deathCount      = 0
            itemsLooted     = 0
            xpAtLogin       = UnitXP("player") or 0
            xpNeedsSnap     = false
            tickCount       = 0
            SaveSessionData()
            UpdateCachedText()
            self.text:SetText(cachedText)
            GameTooltip:Hide()
        end
    end)

    sessionFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end

        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Session Stats", 1, 0.82, 0)

        local elapsed = GetTime() - sessionStart

        GameTooltip:AddDoubleLine("Session Time:", FormatDuration(elapsed), 1, 1, 1, 1, 1, 1)

        -- Gold earned / spent
        local goldDelta = GetMoney() - goldAtLogin
        GameTooltip:AddDoubleLine("Gold " .. (goldDelta >= 0 and "Earned:" or "Spent:"),
            FormatGoldDelta(goldDelta), 1, 1, 1, 1, 1, 1)

        -- Gold per hour (only meaningful after 1 minute)
        if elapsed > 60 then
            local goldPerHour = math.floor((goldDelta / elapsed) * 3600)
            GameTooltip:AddDoubleLine("Gold/hr:", FormatGoldPerHour(goldPerHour), 1, 1, 1, 1, 1, 1)
        end

        -- XP per hour (only for non-max-level characters)
        local maxXP = UnitXPMax("player") or 0
        if maxXP > 0 and elapsed > 60 then
            local currentXP = UnitXP("player") or 0
            local xpDelta = currentXP - xpAtLogin
            if xpDelta > 0 then
                local xpPerHour = math.floor((xpDelta / elapsed) * 3600)
                GameTooltip:AddDoubleLine("XP/hr:",
                    string.format("%s XP", BreakUpLargeNumbers(xpPerHour)), 1, 1, 1, 0.6, 1, 0.6)
                -- Time to level estimate
                local xpToLevel = maxXP - currentXP
                if xpPerHour > 0 then
                    local hoursToLevel = xpToLevel / xpPerHour
                    GameTooltip:AddDoubleLine("  To level:",
                        FormatDuration(math.floor(hoursToLevel * 3600)), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
                end
            end
        end

        GameTooltip:AddDoubleLine("Items Looted:", tostring(itemsLooted), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Deaths:", tostring(deathCount),
            1, 1, 1,
            deathCount > 0 and 1 or 0.5, deathCount > 0 and 0.3 or 0.5, deathCount > 0 and 0.3 or 0.5)

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Right-click to reset", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)

    sessionFrame:SetScript("OnLeave", GameTooltip_Hide)

    -- UpdateContent is called by the widget ticker every second — update the clock and cycle display
    sessionFrame.UpdateContent = function(self)
        tickCount = tickCount + 1
        UpdateCachedText()
        self.text:SetText(cachedText)
    end
end)
