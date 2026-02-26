local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

table.insert(Widgets.moduleInits, function()
    local combatFrame = Widgets.CreateWidgetFrame("Combat", "combat")

    -- Cached text (updated on events, not every second)
    local cachedText = "|cff00ff00Out of Combat|r"

    local function RefreshCombatCache()
        if UnitAffectingCombat("player") then
            cachedText = "|cffff0000In Combat|r"
        else
            cachedText = "|cff00ff00Out of Combat|r"
        end
    end

    local function OnCombatUpdate()
        RefreshCombatCache()
        combatFrame.text:SetText(cachedText)
    end

    combatFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("PLAYER_REGEN_DISABLED", OnCombatUpdate, "W:Combat")
            EventBus.Register("PLAYER_REGEN_ENABLED", OnCombatUpdate, "W:Combat")
            EventBus.Register("PLAYER_ENTERING_WORLD", OnCombatUpdate, "W:Combat")
        else
            EventBus.Unregister("PLAYER_REGEN_DISABLED", OnCombatUpdate)
            EventBus.Unregister("PLAYER_REGEN_ENABLED", OnCombatUpdate)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnCombatUpdate)
        end
    end

    combatFrame.UpdateContent = function(self)
        self.text:SetText(cachedText)
    end
end)
