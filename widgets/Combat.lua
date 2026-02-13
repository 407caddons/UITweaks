local addonName, addonTable = ...
local Widgets = addonTable.Widgets

table.insert(Widgets.moduleInits, function()
    local combatFrame = Widgets.CreateWidgetFrame("Combat", "combat")
    combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    combatFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- Cached text (updated on events, not every second)
    local cachedText = "|cff00ff00Out of Combat|r"

    local function RefreshCombatCache()
        if UnitAffectingCombat("player") then
            cachedText = "|cffff0000In Combat|r"
        else
            cachedText = "|cff00ff00Out of Combat|r"
        end
    end

    combatFrame:SetScript("OnEvent", function(self, event)
        RefreshCombatCache()
        self.text:SetText(cachedText)
    end)

    combatFrame.eventFrame = combatFrame
    combatFrame.ApplyEvents = function(enabled)
        if enabled then
            combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
            combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            combatFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        else
            combatFrame:UnregisterAllEvents()
        end
    end

    combatFrame.UpdateContent = function(self)
        self.text:SetText(cachedText)
    end
end)
