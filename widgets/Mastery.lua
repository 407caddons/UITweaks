local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

table.insert(Widgets.moduleInits, function()
    local masteryFrame = Widgets.CreateWidgetFrame("Mastery", "mastery")

    local cachedText = "Mastery: -"

    local function Refresh()
        local mastery = GetMasteryEffect()
        if mastery then
            cachedText = string.format("Mastery: %.1f%%", mastery)
        else
            cachedText = "Mastery: -"
        end
    end

    masteryFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.ShowStatTooltip(self)
    end)
    masteryFrame:SetScript("OnLeave", GameTooltip_Hide)

    local function OnStatUpdate()
        if UIThingsDB.widgets.mastery.enabled then
            Refresh()
        end
    end

    masteryFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("COMBAT_RATING_UPDATE", OnStatUpdate)
            EventBus.Register("PLAYER_ENTERING_WORLD", OnStatUpdate)
        else
            EventBus.Unregister("COMBAT_RATING_UPDATE", OnStatUpdate)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnStatUpdate)
        end
    end

    masteryFrame.UpdateContent = function(self)
        Refresh()
        self.text:SetText(cachedText)
    end
end)
