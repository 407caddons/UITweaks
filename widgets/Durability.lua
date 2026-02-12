local addonName, addonTable = ...
local Widgets = addonTable.Widgets

table.insert(Widgets.moduleInits, function()
    local durabilityFrame = Widgets.CreateWidgetFrame("Durability", "durability")
    durabilityFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Durability")

        local slots = {
            "Head", "Shoulder", "Chest", "Waist", "Legs", "Feet",
            "Wrist", "Hands", "MainHand", "SecondaryHand"
        }

        for _, slotName in ipairs(slots) do
            local slotId = GetInventorySlotInfo(slotName .. "Slot")
            local current, max = GetInventoryItemDurability(slotId)
            if current and max then
                local percent = (current / max) * 100
                local r, g, b = 0, 1, 0
                if percent < 50 then
                    r, g, b = 1, 0, 0
                elseif percent < 80 then
                    r, g, b = 1, 1, 0
                end

                local link = GetInventoryItemLink("player", slotId)
                if link then
                    GameTooltip:AddDoubleLine(link, string.format("%d%%", percent), 1, 1, 1, r, g, b)
                end
            end
        end
        GameTooltip:Show()
    end)
    durabilityFrame:SetScript("OnLeave", GameTooltip_Hide)

    durabilityFrame.UpdateContent = function(self)
        local minDurability = 100
        for i = 1, 18 do  -- Scan slots
            local current, max = GetInventoryItemDurability(i)
            if current and max then
                local pct = (current / max) * 100
                if pct < minDurability then minDurability = pct end
            end
        end
        self.text:SetFormattedText("Durability: %.0f%%", minDurability)
    end
end)
