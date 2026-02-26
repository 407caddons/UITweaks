local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

table.insert(Widgets.moduleInits, function()
    local Coordinates     = addonTable.Coordinates
    local GetDistanceToWP = Coordinates.GetDistanceToWP
    local FormatDistance  = Coordinates.FormatDistanceShort

    local wpFrame = Widgets.CreateWidgetFrame("WaypointDistance", "waypointDistance")

    local function GetActiveWaypoint()
        local uiWP = C_Map.GetUserWaypoint()
        if not uiWP then return nil end
        local db = UIThingsDB.coordinates
        if db and db.waypoints then
            -- Match against saved waypoints by mapID + coordinates
            for i, wp in ipairs(db.waypoints) do
                if wp.mapID == uiWP.uiMapID then
                    local dx = (wp.x - uiWP.position.x)
                    local dy = (wp.y - uiWP.position.y)
                    if (dx * dx + dy * dy) < 0.0001 then
                        return wp, i
                    end
                end
            end
        end
        -- Waypoint set externally (not in our list) — still show distance
        return { mapID = uiWP.uiMapID, x = uiWP.position.x, y = uiWP.position.y, name = "Waypoint" }, nil
    end

    local function GetDirectionArrow(wp)
        local playerMapID = C_Map.GetBestMapForUnit("player")
        if not playerMapID then return "" end

        -- Get player position on their current map
        local playerPos = C_Map.GetPlayerMapPosition(playerMapID, "player")
        if not playerPos then return "" end
        local px, py = playerPos:GetXY()

        -- Get waypoint position projected onto the player's map
        -- GetUserWaypointPositionForMap returns the waypoint remapped to any map
        local wpPos
        if wp.mapID == playerMapID then
            wpPos = CreateVector2D(wp.x, wp.y)
        elseif C_Map.GetUserWaypointPositionForMap then
            wpPos = C_Map.GetUserWaypointPositionForMap(playerMapID)
        end
        if not wpPos then return "" end

        local wx, wy = wpPos:GetXY()
        local dx = wx - px  -- positive = east
        local dy = wy - py  -- positive = south

        if math.abs(dx) < 0.001 and math.abs(dy) < 0.001 then return "|cFF00FF00*|r" end

        -- Map coords: X=east, Y=south. Bearing clockwise from north = atan2(east, -south→north)
        local angle = math.atan2(dx, -dy)
        local deg = math.deg(angle)
        if deg < 0 then deg = deg + 360 end
        local dirs = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
        local idx = math.floor((deg + 22.5) / 45) % 8 + 1
        return dirs[idx] or ""
    end

    wpFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)

        local wp, idx = GetActiveWaypoint()
        if not wp then
            GameTooltip:SetText("Waypoint Distance")
            GameTooltip:AddLine("No active waypoint", 0.5, 0.5, 0.5)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Set a waypoint via /lway", 0.5, 0.5, 1)
            GameTooltip:Show()
            return
        end

        GameTooltip:SetText(wp.name or "Waypoint", 1, 0.82, 0)

        local dist = GetDistanceToWP(wp)
        if dist then
            GameTooltip:AddDoubleLine("Distance:", FormatDistance(dist), 1, 1, 1, 1, 1, 1)
            local arrow = GetDirectionArrow(wp)
            if arrow ~= "" then
                GameTooltip:AddDoubleLine("Direction:", arrow, 1, 1, 1, 1, 1, 1)
            end
        else
            GameTooltip:AddDoubleLine("Distance:", "different continent", 1, 1, 1, 0.5, 0.5, 0.5)
        end

        local playerMapID = C_Map.GetBestMapForUnit("player")
        if wp.mapID and playerMapID and wp.mapID ~= playerMapID then
            local mapInfo = C_Map.GetMapInfo(wp.mapID)
            if mapInfo then
                GameTooltip:AddDoubleLine("Zone:", mapInfo.name, 1, 1, 1, 0.8, 0.8, 0.8)
            end
        end
        if wp.x and wp.y then
            GameTooltip:AddDoubleLine("Coords:",
                string.format("%.1f, %.1f", wp.x * 100, wp.y * 100), 1, 1, 1, 0.7, 0.7, 0.7)
        end
        if idx then
            local total = #(UIThingsDB.coordinates.waypoints or {})
            if total > 1 then
                GameTooltip:AddDoubleLine("Waypoint:", string.format("%d / %d", idx, total), 1, 1, 1, 0.7, 0.7, 0.7)
            end
        end

        GameTooltip:Show()
    end)
    wpFrame:SetScript("OnLeave", GameTooltip_Hide)

    wpFrame.UpdateContent = function(self)
        local wp = GetActiveWaypoint()
        if not wp then
            self.text:SetText("WP: --")
            return
        end
        local dist = GetDistanceToWP(wp)
        if dist then
            local arrow = GetDirectionArrow(wp)
            self.text:SetText(arrow .. " " .. FormatDistance(dist))
        else
            self.text:SetText("WP: --")
        end
    end

    local function OnWaypointChanged()
        if UIThingsDB.widgets.waypointDistance.enabled then
            wpFrame:UpdateContent()
        end
    end

    local moveTicker = nil

    wpFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("WAYPOINT_UPDATE", OnWaypointChanged, "W:WaypointDistance")
            EventBus.Register("PLAYER_ENTERING_WORLD", OnWaypointChanged, "W:WaypointDistance")
            if not moveTicker then
                moveTicker = C_Timer.NewTicker(0.5, function()
                    if UIThingsDB.widgets.waypointDistance.enabled and wpFrame:IsShown() then
                        wpFrame:UpdateContent()
                    end
                end)
            end
        else
            EventBus.Unregister("WAYPOINT_UPDATE", OnWaypointChanged)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnWaypointChanged)
            if moveTicker then
                moveTicker:Cancel()
                moveTicker = nil
            end
        end
    end
end)
