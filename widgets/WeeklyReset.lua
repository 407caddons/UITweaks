local addonName, addonTable = ...
local Widgets = addonTable.Widgets

table.insert(Widgets.moduleInits, function()
    local resetFrame = Widgets.CreateWidgetFrame("WeeklyReset", "weeklyReset")
    resetFrame:RegisterForClicks("AnyUp")

    -- Get time until weekly reset
    local function GetTimeUntilReset()
        local secondsLeft = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if not secondsLeft or secondsLeft <= 0 then
            return 0, 0, 0, 0
        end

        local days = math.floor(secondsLeft / 86400)
        secondsLeft = secondsLeft - (days * 86400)
        local hours = math.floor(secondsLeft / 3600)
        secondsLeft = secondsLeft - (hours * 3600)
        local minutes = math.floor(secondsLeft / 60)
        local seconds = secondsLeft - (minutes * 60)

        return days, hours, minutes, seconds
    end

    -- Format time string
    local function FormatResetTime(days, hours, minutes, seconds)
        if days > 0 then
            return string.format("%dd %dh %dm", days, hours, minutes)
        elseif hours > 0 then
            return string.format("%dh %dm %ds", hours, minutes, seconds)
        elseif minutes > 0 then
            return string.format("%dm %ds", minutes, seconds)
        else
            return string.format("%ds", seconds)
        end
    end

    -- Get daily reset time
    local function GetTimeUntilDailyReset()
        local secondsLeft = C_DateAndTime.GetSecondsUntilDailyReset()
        if not secondsLeft or secondsLeft <= 0 then
            return 0, 0, 0
        end

        local hours = math.floor(secondsLeft / 3600)
        secondsLeft = secondsLeft - (hours * 3600)
        local minutes = math.floor(secondsLeft / 60)
        local seconds = secondsLeft - (minutes * 60)

        return hours, minutes, seconds
    end

    -- Format daily time
    local function FormatDailyTime(hours, minutes, seconds)
        if hours > 0 then
            return string.format("%dh %dm", hours, minutes)
        elseif minutes > 0 then
            return string.format("%dm %ds", minutes, seconds)
        else
            return string.format("%ds", seconds)
        end
    end

    resetFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.weeklyReset.enabled then return end

        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Reset Timers", 1, 1, 1)

        -- Weekly reset
        local days, hours, minutes, seconds = GetTimeUntilReset()
        local weeklyTime = FormatResetTime(days, hours, minutes, seconds)
        GameTooltip:AddLine("Weekly Reset: " .. weeklyTime, 0, 1, 0)

        -- Daily reset
        local dHours, dMinutes, dSeconds = GetTimeUntilDailyReset()
        local dailyTime = FormatDailyTime(dHours, dMinutes, dSeconds)
        GameTooltip:AddLine("Daily Reset: " .. dailyTime, 0.5, 0.8, 1)

        -- Great Vault info
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Great Vault unlocks at weekly reset", 0.7, 0.7, 0.7)

        GameTooltip:Show()
    end)

    resetFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    resetFrame:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            -- Open calendar to show reset day
            if not CalendarFrame then
                C_AddOns.LoadAddOn("Blizzard_Calendar")
            end
            if CalendarFrame then
                if CalendarFrame:IsShown() then
                    HideUIPanel(CalendarFrame)
                else
                    ShowUIPanel(CalendarFrame)
                end
            end
        end
    end)

    resetFrame.UpdateContent = function(self)
        local days, hours, minutes, seconds = GetTimeUntilReset()
        local timeStr = FormatResetTime(days, hours, minutes, seconds)

        -- Color code based on time remaining
        local color = "|cff00ff00" -- Green
        if days == 0 and hours < 12 then
            color = "|cffffff00"   -- Yellow
        end
        if days == 0 and hours < 3 then
            color = "|cffff0000" -- Red
        end

        self.text:SetText(string.format("Reset: %s%s|r", color, timeStr))
    end

    -- Update every second
    local elapsed = 0
    resetFrame:SetScript("OnUpdate", function(self, delta)
        if not UIThingsDB.widgets.weeklyReset.enabled then return end

        elapsed = elapsed + delta
        if elapsed >= 1 then
            elapsed = 0
            self:UpdateContent()
        end
    end)
end)
