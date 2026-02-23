local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

table.insert(Widgets.moduleInits, function()
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

    -- Convert a map position to world coords using GetWorldPosFromMapPos.
    -- Returns continentID, worldX, worldY or nil on failure.
    local function MapPosToWorld(mapID, x, y)
        if not C_Map.GetWorldPosFromMapPos then return nil end
        local mapPos = CreateVector2D(x, y)
        local continentID, worldPos = C_Map.GetWorldPosFromMapPos(mapID, mapPos)
        if not continentID or not worldPos then return nil end
        return continentID, worldPos:GetXY()
    end

    local function GetDistanceToWaypoint(wp)
        if not wp then return nil end
        local playerMapID = C_Map.GetBestMapForUnit("player")
        if not playerMapID then return nil end
        local playerPos = C_Map.GetPlayerMapPosition(playerMapID, "player")
        if not playerPos then return nil end
        local px, py = playerPos:GetXY()

        -- Try world-coordinate distance (works cross-zone on same continent)
        local pCont, pwx, pwy = MapPosToWorld(playerMapID, px, py)
        local wCont, wwx, wwy = MapPosToWorld(wp.mapID, wp.x, wp.y)
        if pCont and wCont and pCont == wCont then
            local dx = pwx - wwx
            local dy = pwy - wwy
            return math.sqrt(dx * dx + dy * dy)
        end

        -- Same map fallback using map size (yards per unit varies by zone)
        if wp.mapID == playerMapID then
            local size = C_Map.GetMapWorldSize and C_Map.GetMapWorldSize(playerMapID)
            local yardsPerUnit = (size and size > 0) and size or 4224 -- ~typical zone width
            local dx = (wp.x - px) * yardsPerUnit
            local dy = (wp.y - py) * yardsPerUnit
            return math.sqrt(dx * dx + dy * dy)
        end

        return nil
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

    local function FormatDistance(yards)
        if not yards then return "?" end
        if yards >= 1000 then
            return string.format("%.1fky", yards / 1000)
        elseif yards >= 100 then
            return string.format("%.0fy", yards)
        else
            return string.format("%.0fy", yards)
        end
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

        local dist = GetDistanceToWaypoint(wp)
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
        local dist = GetDistanceToWaypoint(wp)
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
            EventBus.Register("WAYPOINT_UPDATE", OnWaypointChanged)
            EventBus.Register("PLAYER_ENTERING_WORLD", OnWaypointChanged)
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
