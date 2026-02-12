local addonName, addonTable = ...
local Widgets = addonTable.Widgets

table.insert(Widgets.moduleInits, function()
    local timeFrame = Widgets.CreateWidgetFrame("Time", "time")

    timeFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        local calendarTime = C_DateAndTime.GetCurrentCalendarTime()
        local hour, minute = GetGameTime()
        GameTooltip:SetText("Time Info", 1, 1, 1)
        GameTooltip:AddDoubleLine("Local Time:", date(" %I:%M %p"), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Server Time:", string.format("%02d:%02d", hour, minute), 1, 1, 1, 1, 1, 1)

        -- Add reset times
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Reset Timers:", 1, 0.82, 0)

        -- Daily reset
        local dailySeconds = C_DateAndTime.GetSecondsUntilDailyReset()
        if dailySeconds and dailySeconds > 0 then
            local dHours = math.floor(dailySeconds / 3600)
            local dMinutes = math.floor((dailySeconds - (dHours * 3600)) / 60)
            local dailyTime = string.format("%dh %dm", dHours, dMinutes)
            GameTooltip:AddDoubleLine("Daily Reset:", dailyTime, 1, 1, 1, 0.5, 0.8, 1)
        end

        -- Weekly reset
        local weeklySeconds = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if weeklySeconds and weeklySeconds > 0 then
            local days = math.floor(weeklySeconds / 86400)
            local hours = math.floor((weeklySeconds - (days * 86400)) / 3600)
            local minutes = math.floor((weeklySeconds - (days * 86400) - (hours * 3600)) / 60)
            local weeklyTime
            if days > 0 then
                weeklyTime = string.format("%dd %dh %dm", days, hours, minutes)
            else
                weeklyTime = string.format("%dh %dm", hours, minutes)
            end

            -- Color code based on time remaining
            local r, g, b = 0, 1, 0 -- Green
            if days == 0 and hours < 12 then
                r, g, b = 1, 1, 0   -- Yellow
            end
            if days == 0 and hours < 3 then
                r, g, b = 1, 0, 0 -- Red
            end

            GameTooltip:AddDoubleLine("Weekly Reset:", weeklyTime, 1, 1, 1, r, g, b)
        end

        GameTooltip:Show()
    end)
    timeFrame:SetScript("OnLeave", GameTooltip_Hide)
    timeFrame:SetScript("OnClick", function() ToggleCalendar() end)

    timeFrame.UpdateContent = function(self)
        local format = "%I:%M %p"
        if UIThingsDB.misc and UIThingsDB.misc.minimapClockFormat == "24H" then
            format = "%H:%M"
        end
        self.text:SetText(date(format))
    end
end)
