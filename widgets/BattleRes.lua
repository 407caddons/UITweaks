local addonName, addonTable = ...
local Widgets = addonTable.Widgets

local REBIRTH_SPELL_ID = 20484

table.insert(Widgets.moduleInits, function()
    local bresFrame = Widgets.CreateWidgetFrame("BattleRes", "battleRes")

    bresFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)

        GameTooltip:SetText("Battle Res Pool")

        local _, instanceType, difficultyID = GetInstanceInfo()
        local isRelevant = (instanceType == "party" or instanceType == "raid") and difficultyID ~= 17

        if not isRelevant then
            GameTooltip:AddLine("Activates in M+ and raid encounters", 0.5, 0.5, 0.5)
            GameTooltip:Show()
            return
        end

        local chargeInfo = C_Spell.GetSpellCharges(REBIRTH_SPELL_ID)
        if chargeInfo then
            GameTooltip:AddDoubleLine("Charges:",
                string.format("%d / %d", chargeInfo.currentCharges, chargeInfo.maxCharges), 1, 1, 1, 1, 1, 1)

            if chargeInfo.currentCharges < chargeInfo.maxCharges and chargeInfo.cooldownStartTime > 0 and chargeInfo.cooldownDuration > 0 then
                local remaining = chargeInfo.cooldownDuration - (GetTime() - chargeInfo.cooldownStartTime)
                if remaining > 0 then
                    local m = math.floor(remaining / 60)
                    local s = math.floor(remaining % 60)
                    GameTooltip:AddDoubleLine("Next charge:", string.format("%d:%02d", m, s), 1, 1, 1, 1, 1, 1)
                end
            end

            GameTooltip:AddDoubleLine("Recharge rate:", string.format("%.1f min", chargeInfo.cooldownDuration / 60), 1, 1,
                1, 0.7, 0.7, 0.7)
        else
            GameTooltip:AddLine("No charge data available", 0.5, 0.5, 0.5)
        end

        -- Instance info
        local name, _, _, _, _, _, _, instanceID = GetInstanceInfo()
        local groupSize = GetNumGroupMembers()
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Instance:", name or "Unknown", 1, 1, 1, 0.7, 0.7, 0.7)
        GameTooltip:AddDoubleLine("Group size:", groupSize, 1, 1, 1, 0.7, 0.7, 0.7)

        GameTooltip:Show()
    end)
    bresFrame:SetScript("OnLeave", GameTooltip_Hide)

    bresFrame.UpdateContent = function(self)
        local _, instanceType, difficultyID = GetInstanceInfo()
        local isRelevant = (instanceType == "party" or instanceType == "raid") and difficultyID ~= 17

        if not isRelevant then
            self.text:SetText("BR")
            return
        end

        local chargeInfo = C_Spell.GetSpellCharges(REBIRTH_SPELL_ID)
        if not chargeInfo then
            self.text:SetText("BR")
            return
        end

        local charges = chargeInfo.currentCharges
        local maxCharges = chargeInfo.maxCharges
        local color = charges > 0 and "|cFF00FF00" or "|cFFFF0000"

        if charges < maxCharges and chargeInfo.cooldownStartTime > 0 and chargeInfo.cooldownDuration > 0 then
            local remaining = chargeInfo.cooldownDuration - (GetTime() - chargeInfo.cooldownStartTime)
            if remaining > 0 then
                local m = math.floor(remaining / 60)
                local s = math.floor(remaining % 60)
                self.text:SetFormattedText("%s%d|r BR (%d:%02d)", color, charges, m, s)
                return
            end
        end

        self.text:SetFormattedText("%s%d|r BR", color, charges)
    end
end)
