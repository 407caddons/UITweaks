local addonName, addonTable = ...
local Widgets = addonTable.Widgets

table.insert(Widgets.moduleInits, function()
    local combatFrame = Widgets.CreateWidgetFrame("Combat", "combat")
    combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    
    local function UpdateText(self)
        if UnitAffectingCombat("player") then
            self.text:SetText("|cffff0000In Combat|r")
        else
            self.text:SetText("|cff00ff00Out of Combat|r")
        end
    end

    combatFrame:SetScript("OnEvent", function(self, event)
        UpdateText(self)
    end)
    
    combatFrame.UpdateContent = function(self)
        -- Also check in update loop just in case event missed/init
        UpdateText(self)
    end
end)
