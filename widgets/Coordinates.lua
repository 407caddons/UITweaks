local addonName, addonTable = ...
local Widgets = addonTable.Widgets

table.insert(Widgets.moduleInits, function()
    local coordFrame = Widgets.CreateWidgetFrame("Coordinates", "coordinates")

    coordFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)

        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local pos = C_Map.GetPlayerMapPosition(mapID, "player")
            local mapInfo = C_Map.GetMapInfo(mapID)
            local zoneName = mapInfo and mapInfo.name or "Unknown"

            GameTooltip:SetText("Coordinates")
            GameTooltip:AddDoubleLine("Zone:", zoneName, 1, 1, 1, 1, 1, 1)
            if pos then
                local x, y = pos:GetXY()
                GameTooltip:AddDoubleLine("Position:", string.format("%.1f, %.1f", x * 100, y * 100), 1, 1, 1, 1, 1, 1)
            else
                GameTooltip:AddDoubleLine("Position:", "Unavailable", 1, 1, 1, 0.5, 0.5, 0.5)
            end

            -- Show parent zone if available
            local parentMapID = mapInfo and mapInfo.parentMapID
            if parentMapID and parentMapID > 0 then
                local parentInfo = C_Map.GetMapInfo(parentMapID)
                if parentInfo then
                    GameTooltip:AddDoubleLine("Region:", parentInfo.name, 1, 1, 1, 1, 1, 1)
                end
            end
        else
            GameTooltip:SetText("Coordinates")
            GameTooltip:AddLine("No map data available", 0.5, 0.5, 0.5)
        end

        GameTooltip:Show()
    end)
    coordFrame:SetScript("OnLeave", GameTooltip_Hide)

    coordFrame.UpdateContent = function(self)
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local pos = C_Map.GetPlayerMapPosition(mapID, "player")
            if pos then
                local x, y = pos:GetXY()
                self.text:SetFormattedText("%.1f, %.1f", x * 100, y * 100)
                return
            end
        end
        self.text:SetText("\226\128\148, \226\128\148")
    end
end)
