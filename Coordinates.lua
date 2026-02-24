local addonName, addonTable = ...
local Coordinates = {}
addonTable.Coordinates = Coordinates

local EventBus = addonTable.EventBus
local Log = addonTable.Core.Log
local LogLevel = addonTable.Core.LogLevel

-- ============================================================
-- State
-- ============================================================
local mainFrame
local scrollChild
local waypointRows = {}
local activeWaypointIndex = nil
local pasteDialog
local zoneCache           -- lazily built: lowerName -> mapID

-- ============================================================
-- Zone name -> mapID resolution
-- ============================================================
local COSMIC_MAP_IDS = { 946, 947, 948, 572, 113, 101, 1355, 1550, 2274, 2601 }
-- 946=Azeroth, 947=Azeroth(alt), 948=The Maelstrom, 572=Draenor, 113=Outland(Northrend),
-- 101=Outland, 1355=Nazjatar parent, 1550=Shadowlands, 2274=Khaz Algar, 2601=Midnight

local function BuildZoneCache()
    zoneCache = {}
    for _, cosmicID in ipairs(COSMIC_MAP_IDS) do
        local children = C_Map.GetMapChildrenInfo(cosmicID, nil, true)
        if children then
            for _, info in ipairs(children) do
                if info.name and info.name ~= "" then
                    local lower = info.name:lower()
                    -- Prefer zone-level maps over continent-level
                    if not zoneCache[lower] or info.mapType == 3 then -- 3 = Zone
                        zoneCache[lower] = info.mapID
                    end
                end
            end
        end
    end
end

local function ResolveZoneName(name)
    if not name or name == "" then return nil end
    if not zoneCache then BuildZoneCache() end

    local lower = name:lower()

    -- Exact match
    if zoneCache[lower] then return zoneCache[lower] end

    -- Partial match (shortest name wins to prefer more specific matches)
    local bestName, bestID = nil, nil
    for cachedName, mapID in pairs(zoneCache) do
        if cachedName:find(lower, 1, true) then
            if not bestName or #cachedName < #bestName then
                bestName, bestID = cachedName, mapID
            end
        end
    end
    if bestID then return bestID end

    return nil
end

-- ============================================================
-- Distance helpers (shared with RefreshList row display)
-- ============================================================
local function MapPosToWorld(mapID, x, y)
    if not C_Map.GetWorldPosFromMapPos then return nil end
    local mapPos = CreateVector2D(x, y)
    local continentID, worldPos = C_Map.GetWorldPosFromMapPos(mapID, mapPos)
    if not continentID or not worldPos then return nil end
    return continentID, worldPos:GetXY()
end

local function GetDistanceToWP(wp)
    local playerMapID = C_Map.GetBestMapForUnit("player")
    if not playerMapID then return nil end
    local playerPos = C_Map.GetPlayerMapPosition(playerMapID, "player")
    if not playerPos then return nil end
    local px, py = playerPos:GetXY()

    local pCont, pwx, pwy = MapPosToWorld(playerMapID, px, py)
    local wCont, wwx, wwy = MapPosToWorld(wp.mapID, wp.x, wp.y)
    if pCont and wCont and pCont == wCont then
        local dx = pwx - wwx
        local dy = pwy - wwy
        return math.sqrt(dx * dx + dy * dy)
    end

    if wp.mapID == playerMapID then
        local size = C_Map.GetMapWorldSize and C_Map.GetMapWorldSize(playerMapID)
        local yardsPerUnit = (size and size > 0) and size or 4224
        local dx = (wp.x - px) * yardsPerUnit
        local dy = (wp.y - py) * yardsPerUnit
        return math.sqrt(dx * dx + dy * dy)
    end

    return nil
end

local function FormatDistanceShort(yards)
    if not yards then return "" end
    if yards >= 1000 then
        return string.format("%.1fky", yards / 1000)
    else
        return string.format("%.0fy", yards)
    end
end

-- ============================================================
-- Slash command parsing
-- ============================================================
-- Formats supported:
--   /lway x, y
--   /lway x, y name
--   /lway x y name
--   /lway zone x, y name
--   /lway zone x y name
--   /lway #mapID x, y name   (e.g. /way #2371 60.9 38.7 Castigaar)
local function ParseWaypointString(msg)
    if not msg or msg:match("^%s*$") then return nil end

    msg = msg:match("^%s*(.-)%s*$") -- trim

    -- Check for #mapID prefix (e.g. "#2371 60.9 38.7 Name")
    local explicitMapID
    local mapIDStr = msg:match("^#(%d+)%s+")
    if mapIDStr then
        explicitMapID = tonumber(mapIDStr)
        msg = msg:match("^#%d+%s+(.*)$") or msg
    end

    -- Try to match coordinates: look for two numbers (with optional decimals)
    -- Pattern: find the first pair of numbers that could be coordinates
    local before, x, y, after

    -- Pattern 1: x, y (comma or slash separated)
    before, x, y, after = msg:match("^(.-)(%d+%.?%d*)%s*[,/]%s*(%d+%.?%d*)(.*)$")
    if not x then
        -- Pattern 2: x y (space separated)
        before, x, y, after = msg:match("^(.-)(%d+%.?%d*)%s+(%d+%.?%d*)(.*)")
    end

    if not x or not y then return nil end

    x = tonumber(x)
    y = tonumber(y)
    if not x or not y then return nil end

    -- Normalize to 0-1 range if given as 0-100
    if x > 1 or y > 1 then
        x = x / 100
        y = y / 100
    end

    -- Clamp
    x = math.max(0, math.min(1, x))
    y = math.max(0, math.min(1, y))

    -- Parse name from after-text (when using #mapID, before-text is always empty)
    local name = after and after:match("^%s*(.-)%s*$") or ""
    if name == "" then name = nil end

    -- Resolve mapID
    local mapID, zone
    if explicitMapID then
        mapID = explicitMapID
        local mapInfo = C_Map.GetMapInfo(mapID)
        zone = mapInfo and mapInfo.name or ("Map " .. mapID)
    else
        -- Parse zone from before-text
        zone = before and before:match("^%s*(.-)%s*$") or ""
        if zone == "" then zone = nil end

        if zone then
            mapID = ResolveZoneName(zone)
            if not mapID then
                -- Maybe the "zone" text is actually part of the name and coords were first
                -- Try current zone instead
                Log("Coordinates", "Unknown zone: " .. zone .. ", using current zone", LogLevel.WARN)
                mapID = C_Map.GetBestMapForUnit("player")
                -- Prepend the unresolved zone text to the name
                if name then
                    name = zone .. " " .. name
                else
                    name = zone
                end
                zone = nil
            end
        else
            mapID = C_Map.GetBestMapForUnit("player")
        end

        if not mapID then
            Log("Coordinates", "Cannot determine current zone", LogLevel.WARN)
            return nil
        end

        -- Get zone name for display
        if not zone then
            local mapInfo = C_Map.GetMapInfo(mapID)
            zone = mapInfo and mapInfo.name or "Unknown"
        end
    end

    -- Auto-generate name if not provided
    if not name then
        name = string.format("%s %.1f, %.1f", zone, x * 100, y * 100)
    end

    return mapID, x, y, name, zone
end

-- ============================================================
-- Waypoint management
-- ============================================================
local function SetActiveWaypoint(index)
    local db = UIThingsDB.coordinates
    local wp = db.waypoints[index]
    if not wp then return end

    local mapPoint = UiMapPoint.CreateFromCoordinates(wp.mapID, wp.x, wp.y)
    C_Map.SetUserWaypoint(mapPoint)
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)

    activeWaypointIndex = index
    Coordinates.RefreshList()
end

local function ClearActiveWaypoint()
    if C_Map.HasUserWaypoint() then
        C_Map.ClearUserWaypoint()
    end
    activeWaypointIndex = nil
end

function Coordinates.AddWaypoint(mapID, x, y, name, zone)
    local db = UIThingsDB.coordinates
    for _, wp in ipairs(db.waypoints) do
        if wp.mapID == mapID and math.abs(wp.x - x) < 0.001 and math.abs(wp.y - y) < 0.001 then
            Log("Coordinates", "Duplicate waypoint, skipping.", LogLevel.WARN)
            return
        end
    end
    table.insert(db.waypoints, {
        mapID = mapID,
        x = x,
        y = y,
        name = name or string.format("%.1f, %.1f", x * 100, y * 100),
        zone = zone or "Unknown",
    })

    Coordinates.RefreshList()

    if db.enabled and mainFrame then
        mainFrame:Show()
    end

    Log("Coordinates", "Waypoint added: " .. (name or "unnamed"), LogLevel.INFO)
end

function Coordinates.RemoveWaypoint(index)
    local db = UIThingsDB.coordinates
    if not db.waypoints[index] then return end

    if activeWaypointIndex == index then
        ClearActiveWaypoint()
    elseif activeWaypointIndex and activeWaypointIndex > index then
        activeWaypointIndex = activeWaypointIndex - 1
    end

    table.remove(db.waypoints, index)
    Coordinates.RefreshList()
end

function Coordinates.ClearAllWaypoints()
    local db = UIThingsDB.coordinates
    wipe(db.waypoints)
    ClearActiveWaypoint()
    Coordinates.RefreshList()
end

-- ============================================================
-- Slash command handler
-- ============================================================
local function SlashHandler(msg)
    local db = UIThingsDB.coordinates
    if not db.enabled then
        Log("Coordinates", "Coordinates module is disabled. Enable it in /luit config.", LogLevel.WARN)
        return
    end

    local mapID, x, y, name, zone = ParseWaypointString(msg)
    if not mapID then
        Log("Coordinates", "Usage: /lway [zone] x, y [name]", LogLevel.WARN)
        return
    end

    Coordinates.AddWaypoint(mapID, x, y, name, zone)
end

-- ============================================================
-- UI: Waypoint row pool
-- ============================================================
local ROW_HEIGHT = 22
local rowPool = {}

local function AcquireRow(parent)
    local row = table.remove(rowPool)
    if not row then
        row = CreateFrame("Button", nil, parent, "BackdropTemplate")
        row:SetHeight(ROW_HEIGHT)

        row.text = row:CreateFontString(nil, "OVERLAY")
        row.text:SetPoint("LEFT", 4, 0)
        row.text:SetPoint("RIGHT", -22, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)

        row.deleteBtn = CreateFrame("Button", nil, row)
        row.deleteBtn:SetSize(16, 16)
        row.deleteBtn:SetPoint("RIGHT", -3, 0)
        row.deleteBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
        row.deleteBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
        row.deleteBtn:GetHighlightTexture():SetVertexColor(1, 0.3, 0.3)

        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

        row:SetScript("OnEnter", function(self)
            if not self.wpData then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.wpData.name, 1, 1, 1)
            GameTooltip:AddDoubleLine("Zone:", self.wpData.zone, 0.7, 0.7, 0.7, 1, 1, 1)
            GameTooltip:AddDoubleLine("Coords:", string.format("%.1f, %.1f", self.wpData.x * 100, self.wpData.y * 100), 0.7, 0.7, 0.7, 1, 1, 1)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click to set waypoint", 0.5, 0.5, 0.5)
            GameTooltip:AddLine("Right-click to open map", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
    end

    row:SetParent(parent)
    row:Show()
    return row
end

local function RecycleRow(row)
    row:Hide()
    row:SetParent(nil)
    row.wpData = nil
    table.insert(rowPool, row)
end

-- ============================================================
-- UI: Refresh the waypoint list
-- ============================================================
function Coordinates.RefreshList()
    if not mainFrame or not scrollChild then return end

    local db = UIThingsDB.coordinates
    local settings = db

    -- Recycle existing rows
    for _, row in ipairs(waypointRows) do
        RecycleRow(row)
    end
    wipe(waypointRows)

    local font = settings.font or "Fonts\\FRIZQT__.TTF"
    local fontSize = settings.fontSize or 12

    for i, wp in ipairs(db.waypoints) do
        local row = AcquireRow(scrollChild)
        row:SetPoint("TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
        row:SetPoint("RIGHT", 0, 0)
        row.wpData = wp
        row.wpIndex = i

        row.text:SetFont(font, fontSize, "")
        local dist = GetDistanceToWP(wp)
        local distStr = dist and ("|cFFAAAAAA" .. FormatDistanceShort(dist) .. "|r  ") or ""
        row.text:SetText(string.format("%s|cFFFFD700%.1f, %.1f|r  %s", distStr, wp.x * 100, wp.y * 100, wp.name or ""))

        -- Highlight active waypoint
        if i == activeWaypointIndex then
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
            })
            row:SetBackdropColor(0.2, 0.6, 0.2, 0.3)
        else
            row:SetBackdrop(nil)
        end

        row:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                if wp.mapID then
                    OpenWorldMap(wp.mapID)
                end
            else
                SetActiveWaypoint(i)
            end
        end)

        row.deleteBtn:SetScript("OnClick", function()
            Coordinates.RemoveWaypoint(i)
        end)

        table.insert(waypointRows, row)
    end

    -- Update scroll child height
    scrollChild:SetHeight(math.max(1, #db.waypoints * ROW_HEIGHT))

    -- Show/hide frame based on content and lock state
    if db.enabled then
        if #db.waypoints == 0 and settings.locked then
            mainFrame:Hide()
        else
            mainFrame:Show()
        end
    end
end

-- ============================================================
-- UI: Paste dialog
-- ============================================================
local function GetOrCreatePasteDialog()
    if pasteDialog then return pasteDialog end

    local f = CreateFrame("Frame", "LunaCoordinatesPasteDialog", UIParent, "BackdropTemplate")
    f:SetSize(450, 300)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Paste Waypoints")

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", 10, -28)
    hint:SetText("One waypoint per line: [zone] x, y [name]")
    hint:SetTextColor(0.5, 0.5, 0.5)

    local editBox = CreateFrame("EditBox", nil, f, "BackdropTemplate")
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetMaxLetters(0)
    editBox:SetPoint("TOPLEFT", 10, -45)
    editBox:SetPoint("BOTTOMRIGHT", -10, 40)
    editBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    editBox:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    editBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    editBox:SetTextInsets(6, 6, 4, 4)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        f:Hide()
    end)
    editBox:SetScript("OnMouseDown", function(self) self:SetFocus() end)
    f.editBox = editBox

    -- Add button
    local addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    addBtn:SetSize(80, 22)
    addBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    addBtn:SetText("Add")
    addBtn:SetScript("OnClick", function()
        local text = editBox:GetText()
        if not text or text == "" then return end

        local count = 0
        for line in text:gmatch("[^\r\n]+") do
            line = line:match("^%s*(.-)%s*$")
            -- Strip leading /lway or /way command prefix if present
            line = line:gsub("^/[lL]?[wW]ay%s+", "")
            if line ~= "" then
                local mapID, x, y, name, zone = ParseWaypointString(line)
                if mapID then
                    Coordinates.AddWaypoint(mapID, x, y, name, zone)
                    count = count + 1
                end
            end
        end

        Log("Coordinates", "Added " .. count .. " waypoint(s)", LogLevel.INFO)
        f:Hide()
    end)

    -- Cancel button
    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(80, 22)
    cancelBtn:SetPoint("RIGHT", addBtn, "LEFT", -5, 0)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function() f:Hide() end)

    pasteDialog = f
    return f
end

function Coordinates.SortByDistance()
    local db = UIThingsDB.coordinates
    if not db.waypoints or #db.waypoints == 0 then return end

    -- Compute distance for each waypoint once, then sort
    local withDist = {}
    for _, wp in ipairs(db.waypoints) do
        table.insert(withDist, { wp = wp, dist = GetDistanceToWP(wp) or math.huge })
    end

    table.sort(withDist, function(a, b) return a.dist < b.dist end)

    wipe(db.waypoints)
    for _, entry in ipairs(withDist) do
        table.insert(db.waypoints, entry.wp)
    end

    -- Preserve active index after sort
    if activeWaypointIndex then
        local activeWP = withDist[activeWaypointIndex] and withDist[activeWaypointIndex].wp
        activeWaypointIndex = nil
        if activeWP then
            for i, entry in ipairs(withDist) do
                if entry.wp == activeWP then
                    activeWaypointIndex = i
                    break
                end
            end
        end
    end

    Coordinates.RefreshList()
end

function Coordinates.ShowPasteDialog()
    local f = GetOrCreatePasteDialog()
    f.editBox:SetText("")
    f.editBox:SetFocus()
    f:Show()
end

-- ============================================================
-- UI: Main frame
-- ============================================================
local function CreateMainFrame()
    if mainFrame then return end

    local db = UIThingsDB.coordinates

    mainFrame = CreateFrame("Frame", "LunaCoordinatesFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(db.width or 220, db.height or 200)
    mainFrame:SetMovable(true)
    mainFrame:SetClampedToScreen(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        UIThingsDB.coordinates.pos = { point = point, x = x, y = y }
    end)
    mainFrame:Hide()

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, mainFrame)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetHeight(24)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleText:SetPoint("LEFT", 6, 0)
    titleText:SetText("Waypoints")
    titleText:SetTextColor(1, 0.82, 0)
    mainFrame.titleText = titleText

    -- Clear All button
    local clearBtn = CreateFrame("Button", nil, titleBar)
    clearBtn:SetSize(16, 16)
    clearBtn:SetPoint("RIGHT", -3, 0)
    clearBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    clearBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
    clearBtn:GetHighlightTexture():SetVertexColor(1, 0.3, 0.3)
    clearBtn:SetScript("OnClick", function()
        Coordinates.ClearAllWaypoints()
    end)
    clearBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Clear All Waypoints")
        GameTooltip:Show()
    end)
    clearBtn:SetScript("OnLeave", GameTooltip_Hide)

    -- Paste button
    local pasteBtn = CreateFrame("Button", nil, titleBar, "UIPanelButtonTemplate")
    pasteBtn:SetSize(50, 18)
    pasteBtn:SetPoint("RIGHT", clearBtn, "LEFT", -4, 0)
    pasteBtn:SetText("Paste")
    pasteBtn:SetNormalFontObject("GameFontNormalSmall")
    pasteBtn:SetScript("OnClick", function()
        Coordinates.ShowPasteDialog()
    end)

    -- Sort button
    local sortBtn = CreateFrame("Button", nil, titleBar, "UIPanelButtonTemplate")
    sortBtn:SetSize(40, 18)
    sortBtn:SetPoint("RIGHT", pasteBtn, "LEFT", -4, 0)
    sortBtn:SetText("Sort")
    sortBtn:SetNormalFontObject("GameFontNormalSmall")
    sortBtn:SetScript("OnClick", function()
        Coordinates.SortByDistance()
    end)
    sortBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sort by Distance")
        GameTooltip:AddLine("Sorts all waypoints by distance\nfrom your current location.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    sortBtn:SetScript("OnLeave", GameTooltip_Hide)

    -- Divider line under title
    local divider = mainFrame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 2, -24)
    divider:SetPoint("TOPRIGHT", -2, -24)
    divider:SetHeight(1)
    divider:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    -- Scroll frame for waypoint list
    local scrollFrame = CreateFrame("ScrollFrame", "LunaCoordinatesScroll", mainFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 4, -26)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 4)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() or 190)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:HookScript("OnSizeChanged", function(sf, w, h)
        scrollChild:SetWidth(w)
    end)

    mainFrame.scrollFrame = scrollFrame

    -- Refresh distances every 2s while frame is visible
    C_Timer.NewTicker(2, function()
        if mainFrame:IsShown() then
            Coordinates.RefreshList()
        end
    end)
end

-- ============================================================
-- Settings application
-- ============================================================
function Coordinates.UpdateSettings()
    if not mainFrame then return end

    local db = UIThingsDB.coordinates
    local Helpers = addonTable.ConfigHelpers

    -- Position
    mainFrame:ClearAllPoints()
    if db.pos then
        mainFrame:SetPoint(db.pos.point, UIParent, db.pos.point, db.pos.x, db.pos.y)
    else
        mainFrame:SetPoint("CENTER")
    end

    -- Size
    mainFrame:SetSize(db.width or 220, db.height or 200)

    -- Backdrop
    if Helpers and Helpers.ApplyFrameBackdrop then
        Helpers.ApplyFrameBackdrop(mainFrame, db.showBorder, db.borderColor, db.showBackground, db.backgroundColor)
    end

    -- Lock state: when locked, disable dragging but keep mouse for row clicks
    mainFrame:EnableMouse(true)
    if db.locked then
        mainFrame:SetScript("OnDragStart", nil)
        mainFrame:SetScript("OnDragStop", nil)
    else
        mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
        mainFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local point, _, _, x, y = self:GetPoint()
            UIThingsDB.coordinates.pos = { point = point, x = x, y = y }
        end)
    end

    -- Show/hide
    if db.enabled then
        if #db.waypoints == 0 and db.locked then
            mainFrame:Hide()
        else
            mainFrame:Show()
        end
    else
        mainFrame:Hide()
    end

    -- Refresh list (updates fonts etc.)
    Coordinates.RefreshList()
end

-- ============================================================
-- Event handlers
-- ============================================================
local function OnPlayerEnteringWorld()
    EventBus.Unregister("PLAYER_ENTERING_WORLD", OnPlayerEnteringWorld)

    CreateMainFrame()
    Coordinates.UpdateSettings()
    Coordinates.RefreshList()
end

local function OnUserWaypointUpdated()
    -- If the user cleared the waypoint via the map, unhighlight our active row
    if not C_Map.HasUserWaypoint() and activeWaypointIndex then
        activeWaypointIndex = nil
        Coordinates.RefreshList()
    end
end

-- ============================================================
-- Initialization
-- ============================================================
EventBus.Register("PLAYER_ENTERING_WORLD", OnPlayerEnteringWorld)
EventBus.Register("USER_WAYPOINT_UPDATED", OnUserWaypointUpdated)

-- Slash commands: /lway always registered
SLASH_LUNAWAY1 = "/lway"
SlashCmdList["LUNAWAY"] = SlashHandler

-- /way alias: intercept via editbox hook so TomTom cannot override us
local wayHooked = false

local function HookChatEditBoxes()
    local function HookBox(box)
        box:HookScript("OnKeyDown", function(self, key)
            if not UIThingsDB.coordinates.registerWayCommand then return end
            if key ~= "ENTER" and key ~= "NUMPADENTER" then return end
            local text = self:GetText()
            if not text then return end
            local args = text:match("^%s*/[Ww][Aa][Yy]%s+(.+)$")
            if not args then return end
            -- Swallow the keypress so OnEnterPressed (and TomTom) never fire
            self:SetPropagateKeyboardInput(false)
            self:SetText("")
            self:ClearFocus()
            self:Hide()
            SlashHandler(args)
        end)
    end

    for i = 1, NUM_CHAT_WINDOWS do
        local box = _G["ChatFrame" .. i .. "EditBox"]
        if box then HookBox(box) end
    end
end

function Coordinates.ApplyWayCommand()
    if UIThingsDB.coordinates.registerWayCommand and not wayHooked then
        HookChatEditBoxes()
        wayHooked = true
    end
end

-- Defer hook to after all addons load
local function OnPlayerLogin()
    EventBus.Unregister("PLAYER_LOGIN", OnPlayerLogin)
    Coordinates.ApplyWayCommand()
end
EventBus.Register("PLAYER_LOGIN", OnPlayerLogin)
