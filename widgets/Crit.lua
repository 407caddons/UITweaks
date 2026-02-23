local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

table.insert(Widgets.moduleInits, function()
    local critFrame = Widgets.CreateWidgetFrame("Crit", "crit")

    local cachedText = "Crit: -"

    local function Refresh()
        local crit = GetCritChance()
        if crit then
            cachedText = string.format("Crit: %.1f%%", crit)
        else
            cachedText = "Crit: -"
        end
    end

    critFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.ShowStatTooltip(self)
    end)
    critFrame:SetScript("OnLeave", GameTooltip_Hide)

    local function OnStatUpdate()
        if UIThingsDB.widgets.crit.enabled then
            Refresh()
        end
    end

    critFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("COMBAT_RATING_UPDATE", OnStatUpdate)
            EventBus.Register("PLAYER_ENTERING_WORLD", OnStatUpdate)
        else
            EventBus.Unregister("COMBAT_RATING_UPDATE", OnStatUpdate)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnStatUpdate)
        end
    end

    critFrame.UpdateContent = function(self)
        Refresh()
        self.text:SetText(cachedText)
    end
end)
