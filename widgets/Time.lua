local addonName, addonTable = ...
local Widgets = addonTable.Widgets

table.insert(Widgets.moduleInits, function()
    local timeFrame = Widgets.CreateWidgetFrame("Time", "time")
    
    timeFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        local calendarTime = C_DateAndTime.GetCurrentCalendarTime()
        local hour, minute = GetGameTime()
        GameTooltip:SetText("Time Info")
        GameTooltip:AddDoubleLine("Local Time:", date(" %I:%M %p"), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Server Time:", string.format("%02d:%02d", hour, minute), 1, 1, 1, 1, 1, 1)
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
