local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

table.insert(Widgets.moduleInits, function()
    local dmfFrame = Widgets.CreateWidgetFrame("DarkmoonFaire", "darkmoonFaire")

    local DMF_PROFESSION_QUESTS = {
        { questID = 29506, name = "Alchemy" },
        { questID = 29508, name = "Blacksmithing" },
        { questID = 29507, name = "Cooking" },
        { questID = 29510, name = "Enchanting" },
        { questID = 29511, name = "Engineering" },
        { questID = 29514, name = "Fishing" },
        { questID = 29519, name = "Herbalism" },
        { questID = 29515, name = "Inscription" },
        { questID = 29516, name = "Jewelcrafting" },
        { questID = 29517, name = "Leatherworking" },
        { questID = 29518, name = "Mining" },
        { questID = 29513, name = "Skinning" },
        { questID = 29520, name = "Tailoring" },
    }

    -- DMF runs the first full week of each month (first Sunday through Saturday)
    local function GetDMFInfo()
        local now = time()
        local today = date("*t", now)

        -- Find first Sunday of this month
        local firstOfMonth = time({ year = today.year, month = today.month, day = 1, hour = 0, min = 0, sec = 0 })
        local firstDow = date("*t", firstOfMonth).wday -- 1=Sunday
        local firstSunday = 1 + (8 - firstDow) % 7
        if firstSunday > 7 then firstSunday = firstSunday - 7 end

        local dmfStart = time({ year = today.year, month = today.month, day = firstSunday, hour = 0, min = 0, sec = 0 })
        local dmfEnd = dmfStart + (7 * 86400) - 1 -- End of Saturday

        if now >= dmfStart and now <= dmfEnd then
            return true, dmfEnd - now
        elseif now < dmfStart then
            return false, dmfStart - now
        else
            -- Past this month's DMF, calculate next month
            local nextMonth = today.month + 1
            local nextYear = today.year
            if nextMonth > 12 then
                nextMonth = 1
                nextYear = nextYear + 1
            end
            local nextFirst = time({ year = nextYear, month = nextMonth, day = 1, hour = 0, min = 0, sec = 0 })
            local nextDow = date("*t", nextFirst).wday
            local nextSunday = 1 + (8 - nextDow) % 7
            if nextSunday > 7 then nextSunday = nextSunday - 7 end
            local nextDmfStart = time({ year = nextYear, month = nextMonth, day = nextSunday, hour = 0, min = 0, sec = 0 })
            return false, nextDmfStart - now
        end
    end

    local function FormatCountdown(seconds)
        if seconds <= 0 then return "Now" end
        local days = math.floor(seconds / 86400)
        local hours = math.floor((seconds % 86400) / 3600)
        if days > 0 then
            return string.format("%dd %dh", days, hours)
        else
            local mins = math.floor((seconds % 3600) / 60)
            return string.format("%dh %dm", hours, mins)
        end
    end

    local cachedText = "DMF: ..."

    local function RefreshDMFCache()
        local isActive, remaining = GetDMFInfo()
        if isActive then
            cachedText = "|cFF00FF00DMF: Active|r"
        else
            cachedText = "DMF: " .. FormatCountdown(remaining)
        end
    end

    local function OnDMFEvent()
        if not UIThingsDB.widgets.darkmoonFaire.enabled then return end
        RefreshDMFCache()
    end

    dmfFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("QUEST_TURNED_IN", OnDMFEvent)
            EventBus.Register("PLAYER_ENTERING_WORLD", OnDMFEvent)
            RefreshDMFCache()
        else
            EventBus.Unregister("QUEST_TURNED_IN", OnDMFEvent)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnDMFEvent)
        end
    end

    dmfFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Darkmoon Faire", 1, 1, 1)

        local isActive, remaining = GetDMFInfo()

        if isActive then
            GameTooltip:AddLine("|cFF00FF00Currently Active!|r")
            GameTooltip:AddLine(string.format("Ends in: %s", FormatCountdown(remaining)), 0.8, 0.8, 0.8)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Profession Quests", 1, 0.82, 0)

            for _, quest in ipairs(DMF_PROFESSION_QUESTS) do
                local done = C_QuestLog.IsQuestFlaggedCompleted(quest.questID)
                if done then
                    GameTooltip:AddDoubleLine(quest.name, "Done", 1, 1, 1, 0, 1, 0)
                else
                    GameTooltip:AddDoubleLine(quest.name, "Not Done", 1, 1, 1, 1, 0, 0)
                end
            end
        else
            GameTooltip:AddLine("Not currently active", 0.7, 0.7, 0.7)
            GameTooltip:AddLine(string.format("Starts in: %s", FormatCountdown(remaining)), 0, 1, 0)
        end

        GameTooltip:Show()
    end)
    dmfFrame:SetScript("OnLeave", GameTooltip_Hide)

    -- Ticker updates the countdown naturally
    dmfFrame.UpdateContent = function(self)
        RefreshDMFCache()
        self.text:SetText(cachedText)
    end
end)
