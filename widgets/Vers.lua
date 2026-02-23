local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

table.insert(Widgets.moduleInits, function()
    local versFrame = Widgets.CreateWidgetFrame("Versatility", "vers")

    local cachedText = "Vers: -"

    local function Refresh()
        local vers = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) or 0
        if vers > 0 then
            cachedText = string.format("Vers: %.1f%%", vers)
        else
            cachedText = "Vers: -"
        end
    end

    versFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.ShowStatTooltip(self)
    end)
    versFrame:SetScript("OnLeave", GameTooltip_Hide)

    local function OnStatUpdate()
        if UIThingsDB.widgets.vers.enabled then
            Refresh()
        end
    end

    versFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("COMBAT_RATING_UPDATE", OnStatUpdate)
            EventBus.Register("PLAYER_ENTERING_WORLD", OnStatUpdate)
        else
            EventBus.Unregister("COMBAT_RATING_UPDATE", OnStatUpdate)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnStatUpdate)
        end
    end

    versFrame.UpdateContent = function(self)
        Refresh()
        self.text:SetText(cachedText)
    end
end)
