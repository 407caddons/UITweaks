local addonName, addonTable = ...
local Widgets = addonTable.Widgets

table.insert(Widgets.moduleInits, function()
    local durabilityFrame = Widgets.CreateWidgetFrame("Durability", "durability")

    -- Cached repair cost from last vendor visit
    local cachedRepairCost = nil
    local merchantOpen = false

    local repairEventFrame = CreateFrame("Frame")
    repairEventFrame:RegisterEvent("MERCHANT_SHOW")
    repairEventFrame:RegisterEvent("MERCHANT_CLOSED")
    repairEventFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    repairEventFrame:SetScript("OnEvent", function(self, event)
        if event == "MERCHANT_SHOW" then
            merchantOpen = true
            if CanMerchantRepair() then
                local cost, canRepair = GetRepairAllCost()
                if canRepair then
                    cachedRepairCost = cost
                end
            end
        elseif event == "MERCHANT_CLOSED" then
            merchantOpen = false
        elseif event == "UPDATE_INVENTORY_DURABILITY" then
            if merchantOpen and CanMerchantRepair() then
                local cost, canRepair = GetRepairAllCost()
                if canRepair then
                    cachedRepairCost = cost
                end
            end
        end
    end)

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

        -- Repair cost estimate
        local repairCost = cachedRepairCost
        -- If merchant is open, get live cost
        if merchantOpen and CanMerchantRepair() then
            local cost, canRepair = GetRepairAllCost()
            if canRepair then repairCost = cost end
        end

        if repairCost and repairCost > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Repair Cost:", GetCoinTextureString(repairCost), 1, 0.82, 0, 1, 1, 1)
        elseif repairCost == 0 or (cachedRepairCost and cachedRepairCost == 0) then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Repair Cost:", "Fully repaired", 1, 0.82, 0, 0, 1, 0)
        end

        GameTooltip:Show()
    end)
    durabilityFrame:SetScript("OnLeave", GameTooltip_Hide)

    durabilityFrame.UpdateContent = function(self)
        local minDurability = 100
        for i = 1, 18 do -- Scan slots
            local current, max = GetInventoryItemDurability(i)
            if current and max then
                local pct = (current / max) * 100
                if pct < minDurability then minDurability = pct end
            end
        end
        self.text:SetFormattedText("Durability: %.0f%%", minDurability)
    end
end)
