local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

table.insert(Widgets.moduleInits, function()
    local hasteFrame = Widgets.CreateWidgetFrame("Haste", "haste")

    local cachedText = "Haste: -"

    local function Refresh()
        local haste = GetHaste()
        if haste then
            cachedText = string.format("Haste: %.1f%%", haste)
        else
            cachedText = "Haste: -"
        end
    end

    hasteFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.ShowStatTooltip(self)
    end)
    hasteFrame:SetScript("OnLeave", GameTooltip_Hide)

    local function OnStatUpdate()
        if UIThingsDB.widgets.haste.enabled then
            Refresh()
        end
    end

    hasteFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("COMBAT_RATING_UPDATE", OnStatUpdate, "W:Haste")
            EventBus.Register("PLAYER_ENTERING_WORLD", OnStatUpdate, "W:Haste")
        else
            EventBus.Unregister("COMBAT_RATING_UPDATE", OnStatUpdate)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnStatUpdate)
        end
    end

    hasteFrame.UpdateContent = function(self)
        Refresh()
        self.text:SetText(cachedText)
    end
end)
