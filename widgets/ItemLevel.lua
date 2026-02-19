local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

table.insert(Widgets.moduleInits, function()
    local ilvlFrame = Widgets.CreateWidgetFrame("ItemLevel", "itemLevel")

    -- Cached item level (updated on events, not every second)
    local cachedText = "iLvl: -"

    local function RefreshItemLevelCache()
        local avgItemLevel, avgItemLevelEquipped = GetAverageItemLevel()
        if avgItemLevel and avgItemLevel > 0 then
            local equipped = math.floor(avgItemLevelEquipped)
            local overall = math.floor(avgItemLevel)
            if equipped == overall then
                cachedText = string.format("iLvl: %d", equipped)
            else
                cachedText = string.format("iLvl: %d/%d", equipped, overall)
            end
        else
            cachedText = "iLvl: -"
        end
    end

    local function OnItemLevelUpdate()
        RefreshItemLevelCache()
    end

    ilvlFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("PLAYER_AVG_ITEM_LEVEL_UPDATE", OnItemLevelUpdate)
            EventBus.Register("PLAYER_EQUIPMENT_CHANGED", OnItemLevelUpdate)
            EventBus.Register("PLAYER_ENTERING_WORLD", OnItemLevelUpdate)
        else
            EventBus.Unregister("PLAYER_AVG_ITEM_LEVEL_UPDATE", OnItemLevelUpdate)
            EventBus.Unregister("PLAYER_EQUIPMENT_CHANGED", OnItemLevelUpdate)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnItemLevelUpdate)
        end
    end

    ilvlFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Item Level")

        local avgItemLevel, avgItemLevelEquipped = GetAverageItemLevel()
        if avgItemLevel then
            GameTooltip:AddDoubleLine("Equipped:", string.format("%.1f", avgItemLevelEquipped), 1, 1, 1, 1, 1, 1)
            GameTooltip:AddDoubleLine("Overall:", string.format("%.1f", avgItemLevel), 1, 1, 1, 0.8, 0.8, 0.8)
        end

        -- Show per-slot breakdown
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Equipment", 1, 0.82, 0)

        local slots = {
            { slot = 1,  name = "Head" },
            { slot = 2,  name = "Neck" },
            { slot = 3,  name = "Shoulder" },
            { slot = 5,  name = "Chest" },
            { slot = 6,  name = "Waist" },
            { slot = 7,  name = "Legs" },
            { slot = 8,  name = "Feet" },
            { slot = 9,  name = "Wrist" },
            { slot = 10, name = "Hands" },
            { slot = 11, name = "Ring 1" },
            { slot = 12, name = "Ring 2" },
            { slot = 13, name = "Trinket 1" },
            { slot = 14, name = "Trinket 2" },
            { slot = 15, name = "Back" },
            { slot = 16, name = "Main Hand" },
            { slot = 17, name = "Off Hand" },
        }

        for _, info in ipairs(slots) do
            local itemLink = GetInventoryItemLink("player", info.slot)
            if itemLink then
                local effectiveILvl = C_Item.GetDetailedItemLevelInfo(itemLink)
                if effectiveILvl then
                    local r, g, b = 1, 1, 1
                    GameTooltip:AddDoubleLine(info.name, effectiveILvl, 1, 1, 1, r, g, b)
                end
            else
                GameTooltip:AddDoubleLine(info.name, "Empty", 1, 1, 1, 0.5, 0.5, 0.5)
            end
        end

        GameTooltip:Show()
    end)
    ilvlFrame:SetScript("OnLeave", GameTooltip_Hide)

    ilvlFrame.UpdateContent = function(self)
        self.text:SetText(cachedText)
    end
end)
