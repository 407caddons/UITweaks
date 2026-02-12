local addonName, addonTable = ...
local MinimapCustom = {}
addonTable.MinimapCustom = MinimapCustom

-- == MINIMAP CUSTOMIZATION ==

local minimapFrame = nil
local borderBackdrop = nil
local borderMask = nil
local BORDER_SIZE = 4
local minimapLocked = true -- Runtime-only, always defaults to locked

local zoneText = nil
local clockText = nil

local function ApplyMinimapShape(shape)
    if not shape then shape = UIThingsDB.misc.minimapShape or "ROUND" end

    if shape == "SQUARE" then
        Minimap:SetMaskTexture("Interface\\BUTTONS\\WHITE8X8")
        -- Remove the circular blob rings that look wrong on a square map
        Minimap:SetArchBlobRingScalar(0)
        Minimap:SetArchBlobRingAlpha(0)
        Minimap:SetQuestBlobRingScalar(0)
        Minimap:SetQuestBlobRingAlpha(0)
    else
        Minimap:SetMaskTexture("Interface\\AddOns\\LunaUITweaks\\round")
        -- Restore blob rings for round shape
        Minimap:SetArchBlobRingScalar(1)
        Minimap:SetArchBlobRingAlpha(1)
        Minimap:SetQuestBlobRingScalar(1)
        Minimap:SetQuestBlobRingAlpha(1)
    end

    -- Also apply to HybridMinimap if it's loaded
    if HybridMinimap then
        HybridMinimap.MapCanvas:SetUseMaskTexture(false)
        if shape == "SQUARE" then
            HybridMinimap.CircleMask:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        else
            HybridMinimap.CircleMask:SetTexture("Interface\\AddOns\\LunaUITweaks\\round")
        end
        HybridMinimap.MapCanvas:SetUseMaskTexture(true)
    end

    -- Update the border mask to match the shape
    if borderMask then
        if shape == "SQUARE" then
            borderMask:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        else
            borderMask:SetTexture("Interface\\AddOns\\LunaUITweaks\\round")
        end
    end

    -- Relocate Icons for Square Map
    if shape == "SQUARE" then
        if MinimapCluster and MinimapCluster.InstanceDifficulty then
            MinimapCluster.InstanceDifficulty:ClearAllPoints()
            MinimapCluster.InstanceDifficulty:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -2, 2)
            MinimapCluster.InstanceDifficulty:SetParent(Minimap)
            MinimapCluster.InstanceDifficulty:SetFrameStrata("HIGH")
            MinimapCluster.InstanceDifficulty:SetFrameLevel(100)
        end
        if QueueStatusButton then
            QueueStatusButton:ClearAllPoints()
            QueueStatusButton:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 2, 4)
            -- Parent to Minimap to ensure correct visibility logic from Blizzard
            QueueStatusButton:SetParent(Minimap)
            -- Force high strata to be clickable above map/border
            QueueStatusButton:SetFrameStrata("HIGH")
            QueueStatusButton:SetFrameLevel(100)
        end
    else
        -- Restore defaults (approximate)
        if MinimapCluster and MinimapCluster.InstanceDifficulty then
            MinimapCluster.InstanceDifficulty:ClearAllPoints()
            MinimapCluster.InstanceDifficulty:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
            MinimapCluster.InstanceDifficulty:SetParent(Minimap)
            MinimapCluster.InstanceDifficulty:SetFrameStrata("HIGH")
            MinimapCluster.InstanceDifficulty:SetFrameLevel(100)
        end

        -- Improve interaction for Round map as well
        if QueueStatusButton then
            QueueStatusButton:SetParent(Minimap)
            QueueStatusButton:SetFrameStrata("HIGH")
            QueueStatusButton:SetFrameLevel(100)
        end
    end


    -- Expose shape for other addons that call GetMinimapShape()
    if shape == "SQUARE" then
        function GetMinimapShape() return "SQUARE" end
    else
        GetMinimapShape = nil -- Let it fall back to default (round)
    end
end

local function HideDefaultDecorations()
    -- Hide the default Blizzard circular border and decorations
    if MinimapBorder then MinimapBorder:Hide() end
    if MinimapBorderTop then MinimapBorderTop:Hide() end
    if MinimapNorthTag then MinimapNorthTag:Hide() end
    if MinimapBackdrop then MinimapBackdrop:Hide() end

    -- Hide the modern cluster decorations
    if MinimapCluster then
        MinimapCluster:EnableMouse(false)
        if MinimapCluster.BorderTop then MinimapCluster.BorderTop:Hide() end

        -- Zone text (always hide, we have our own)
        if MinimapCluster.ZoneTextButton then MinimapCluster.ZoneTextButton:Hide() end

        -- Tracking button (conditionally hidden)
        if MinimapCluster.Tracking then MinimapCluster.Tracking:Hide() end

        -- Mail and crafting order icons (conditionally hidden)
        if MinimapCluster.IndicatorFrame then
            MinimapCluster.IndicatorFrame:Hide()
        end
    end

    -- Calendar button
    if GameTimeFrame then GameTimeFrame:Hide() end

    -- Clock (always hide, we have our own)
    if TimeManagerClockButton then TimeManagerClockButton:Hide() end

    -- Addon compartment (conditionally hidden)
    if AddonCompartmentFrame then AddonCompartmentFrame:Hide() end

    -- Expansion landing page button (missions)
    if ExpansionLandingPageMinimapButton then ExpansionLandingPageMinimapButton:Hide() end

    -- Zoom buttons (hook Show to prevent Blizz OnEnter from re-showing them)
    if Minimap.ZoomIn then
        Minimap.ZoomIn:Hide()
        Minimap.ZoomIn:SetScript("OnShow", function(self) self:Hide() end)
    end
    if Minimap.ZoomOut then
        Minimap.ZoomOut:Hide()
        Minimap.ZoomOut:SetScript("OnShow", function(self) self:Hide() end)
    end
end

local function PositionMinimapIcons()
    if not minimapFrame then return end
    local settings = UIThingsDB.misc
    local yOffset = -5
    local iconSpacing = 28
    local xPos = Minimap:GetWidth() / 2 + 8

    -- Mail icon
    if MinimapCluster and MinimapCluster.IndicatorFrame then
        local mailFrame = MinimapCluster.IndicatorFrame.MailFrame
        if mailFrame then
            if settings.minimapShowMail then
                mailFrame:SetParent(minimapFrame)
                mailFrame:ClearAllPoints()
                mailFrame:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -2, yOffset)
                mailFrame:SetScale(0.8)
                mailFrame:SetFrameStrata("MEDIUM")
                mailFrame:SetFrameLevel(20)
                mailFrame:Show()
                -- Hook OnShow in case Blizz tries to re-hide
                mailFrame:SetScript("OnHide", nil)
                yOffset = yOffset - iconSpacing
            else
                mailFrame:Hide()
            end
        end

        -- Personal Work Order icon
        local craftFrame = MinimapCluster.IndicatorFrame.CraftingOrderFrame
        if craftFrame then
            if settings.minimapShowCraftingOrder then
                -- Check for pending personal orders
                local orders = C_CraftingOrders and C_CraftingOrders.GetPersonalOrdersInfo()
                local hasOrders = orders and #orders > 0

                if hasOrders then
                    craftFrame:SetParent(minimapFrame)
                    craftFrame:ClearAllPoints()
                    craftFrame:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -2, yOffset)
                    craftFrame:SetScale(0.8)
                    craftFrame:SetFrameStrata("MEDIUM")
                    craftFrame:SetFrameLevel(20)
                    craftFrame:Show()
                    craftFrame:SetScript("OnHide", nil)
                    yOffset = yOffset - iconSpacing
                else
                    craftFrame:Hide()
                end
            else
                craftFrame:Hide()
            end
        end
    end

    -- Tracking button
    if MinimapCluster and MinimapCluster.Tracking then
        if settings.minimapShowTracking then
            MinimapCluster.Tracking:SetParent(minimapFrame)
            MinimapCluster.Tracking:ClearAllPoints()
            MinimapCluster.Tracking:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -2, yOffset)
            MinimapCluster.Tracking:SetScale(0.8)
            MinimapCluster.Tracking:SetFrameStrata("MEDIUM")
            MinimapCluster.Tracking:SetFrameLevel(20)
            MinimapCluster.Tracking:Show()
            yOffset = yOffset - iconSpacing
        else
            MinimapCluster.Tracking:Hide()
        end
    end

    -- Addon compartment (drawer)
    if AddonCompartmentFrame then
        if settings.minimapShowAddonCompartment then
            AddonCompartmentFrame:SetParent(minimapFrame)
            AddonCompartmentFrame:ClearAllPoints()
            AddonCompartmentFrame:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -2, yOffset)
            AddonCompartmentFrame:SetScale(0.8)
            AddonCompartmentFrame:SetFrameStrata("MEDIUM")
            AddonCompartmentFrame:SetFrameLevel(20)
            AddonCompartmentFrame:Show()
            yOffset = yOffset - iconSpacing
        else
            AddonCompartmentFrame:Hide()
        end
    end
end

local function SetupMinimap()
    local settings = UIThingsDB.misc
    if not settings.minimapEnabled then return end

    -- Create a wrapper frame for positioning
    if not minimapFrame then
        local borderSize = settings.minimapBorderSize or 3
        minimapFrame = CreateFrame("Frame", "LunaMinimapFrame", UIParent)
        local mapSize = Minimap:GetWidth()
        local frameSize = mapSize + (borderSize * 2)
        minimapFrame:SetSize(frameSize, frameSize)
        minimapFrame:SetClampedToScreen(true)
        -- Add dummy Layout method to satisfy Blizzard code (Minimap.lua calls it on parent)
        minimapFrame.Layout = function() end

        -- Position from saved settings
        local pos = settings.minimapPos
        minimapFrame:ClearAllPoints()
        minimapFrame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)

        -- Create the border backdrop (a larger colored texture behind the minimap, masked to shape)
        local borderFrame = CreateFrame("Frame", nil, minimapFrame)
        borderFrame:SetFrameStrata("BACKGROUND")
        borderFrame:SetFrameLevel(1)
        borderFrame:SetAllPoints(minimapFrame)
        borderFrame:Show()

        borderBackdrop = borderFrame:CreateTexture(nil, "BACKGROUND")
        borderBackdrop:SetAllPoints(borderFrame)
        local bc = settings.minimapBorderColor or { r = 0, g = 0, b = 0, a = 1 }
        borderBackdrop:SetColorTexture(bc.r, bc.g, bc.b, bc.a or 1)

        borderMask = borderFrame:CreateMaskTexture()
        borderMask:SetAllPoints(borderBackdrop)
        borderBackdrop:AddMaskTexture(borderMask)

        -- Hide default Blizzard decorations
        HideDefaultDecorations()

        -- Reparent the Minimap into our frame
        Minimap:SetParent(minimapFrame)
        Minimap:ClearAllPoints()
        Minimap:SetPoint("CENTER", minimapFrame, "CENTER")

        -- == Zone Text (movable, anchored to minimap) ==
        local zoneOffset = settings.minimapZoneOffset or { x = 0, y = 4 }
        local zoneFrame = CreateFrame("Frame", "LunaMinimapZoneFrame", minimapFrame)
        zoneFrame:SetSize(150, 20)
        zoneFrame:SetPoint("BOTTOM", Minimap, "TOP", zoneOffset.x, zoneOffset.y)
        zoneFrame:SetMovable(true)
        zoneFrame:SetClampedToScreen(true)

        zoneText = zoneFrame:CreateFontString(nil, "OVERLAY")
        zoneText:SetFont(settings.minimapZoneFont or "Fonts\\FRIZQT__.TTF", settings.minimapZoneFontSize or 12, "OUTLINE")
        local zc = settings.minimapZoneFontColor or { r = 1, g = 1, b = 1 }
        zoneText:SetTextColor(zc.r, zc.g, zc.b)
        zoneText:SetShadowOffset(1, -1)
        zoneText:SetShadowColor(0, 0, 0, 1)
        zoneText:SetPoint("CENTER", zoneFrame, "CENTER")
        zoneText:SetText(GetMinimapZoneText())

        -- Drag overlay for zone text
        local zoneDragOverlay = CreateFrame("Frame", nil, zoneFrame)
        zoneDragOverlay:SetAllPoints(zoneFrame)
        zoneDragOverlay:SetFrameStrata("TOOLTIP")
        zoneDragOverlay:EnableMouse(true)
        zoneDragOverlay:RegisterForDrag("LeftButton")
        zoneDragOverlay:SetScript("OnDragStart", function()
            zoneFrame:StartMoving()
        end)
        zoneDragOverlay:SetScript("OnDragStop", function()
            zoneFrame:StopMovingOrSizing()
            -- Recalculate position relative to minimap TOP center
            local zoneCX, zoneCY = zoneFrame:GetCenter()
            local mapCX, mapTop = Minimap:GetCenter(), select(2, Minimap:GetTop(), Minimap:GetTop())
            mapTop = Minimap:GetTop()
            local offX = zoneCX - mapCX
            local offY = zoneCY - mapTop
            -- Re-anchor to minimap so it stays correct on reload
            zoneFrame:ClearAllPoints()
            zoneFrame:SetPoint("BOTTOM", Minimap, "TOP", offX, offY)
            UIThingsDB.misc.minimapZoneOffset = { x = offX, y = offY }
            -- Sync config edit boxes if open
            if _G["UIThingsMiscZoneX"] then _G["UIThingsMiscZoneX"]:SetText(tostring(math.floor(offX + 0.5))) end
            if _G["UIThingsMiscZoneY"] then _G["UIThingsMiscZoneY"]:SetText(tostring(math.floor(offY + 0.5))) end
        end)
        zoneDragOverlay:Hide() -- Start locked
        zoneFrame.dragOverlay = zoneDragOverlay

        if not settings.minimapShowZone then
            zoneFrame:Hide()
        end

        -- Store reference
        minimapFrame.zoneFrame = zoneFrame

        -- Update zone text on zone changes
        minimapFrame:RegisterEvent("ZONE_CHANGED")
        minimapFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
        minimapFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

        -- Register for crafting order updates to refresh icon visibility
        minimapFrame:RegisterEvent("CRAFTINGORDERS_UPDATE_PERSONAL_ORDER_COUNTS")

        -- == Clock Text (movable, anchored to minimap) ==
        local clockOffset = settings.minimapClockOffset or { x = 0, y = -4 }
        local clockFrame = CreateFrame("Frame", "LunaMinimapClockFrame", minimapFrame)
        clockFrame:SetSize(80, 20)
        clockFrame:SetPoint("TOP", Minimap, "BOTTOM", clockOffset.x, clockOffset.y)
        clockFrame:SetMovable(true)
        clockFrame:SetClampedToScreen(true)

        clockText = clockFrame:CreateFontString(nil, "OVERLAY")
        clockText:SetFont(settings.minimapClockFont or "Fonts\\FRIZQT__.TTF", settings.minimapClockFontSize or 11,
            "OUTLINE")
        local cc = settings.minimapClockFontColor or { r = 1, g = 1, b = 1 }
        clockText:SetTextColor(cc.r, cc.g, cc.b)
        clockText:SetShadowOffset(1, -1)
        clockText:SetShadowColor(0, 0, 0, 1)
        clockText:SetPoint("CENTER", clockFrame, "CENTER")

        -- Drag overlay for clock
        local clockDragOverlay = CreateFrame("Frame", nil, clockFrame)
        clockDragOverlay:SetAllPoints(clockFrame)
        clockDragOverlay:SetFrameStrata("TOOLTIP")
        clockDragOverlay:EnableMouse(true)
        clockDragOverlay:RegisterForDrag("LeftButton")
        clockDragOverlay:SetScript("OnDragStart", function()
            clockFrame:StartMoving()
        end)
        clockDragOverlay:SetScript("OnDragStop", function()
            clockFrame:StopMovingOrSizing()
            -- Recalculate position relative to minimap BOTTOM center
            local clockCX, clockCY = clockFrame:GetCenter()
            local mapCX = Minimap:GetCenter()
            local mapBottom = Minimap:GetBottom()
            local offX = clockCX - mapCX
            local offY = clockCY - mapBottom
            -- Re-anchor to minimap so it stays correct on reload
            clockFrame:ClearAllPoints()
            clockFrame:SetPoint("TOP", Minimap, "BOTTOM", offX, offY)
            UIThingsDB.misc.minimapClockOffset = { x = offX, y = offY }
            -- Sync config edit boxes if open
            if _G["UIThingsMiscClockX"] then _G["UIThingsMiscClockX"]:SetText(tostring(math.floor(offX + 0.5))) end
            if _G["UIThingsMiscClockY"] then _G["UIThingsMiscClockY"]:SetText(tostring(math.floor(offY + 0.5))) end
        end)
        clockDragOverlay:Hide() -- Start locked
        clockFrame.dragOverlay = clockDragOverlay

        if not settings.minimapShowClock then
            clockFrame:Hide()
        end

        -- Store reference
        minimapFrame.clockFrame = clockFrame

        -- Clock update timer
        local function UpdateClock()
            local hour, minute
            local timeSource = UIThingsDB.misc.minimapClockTimeSource or "local"
            if timeSource == "local" then
                hour, minute = tonumber(date("%H")), tonumber(date("%M"))
            else
                hour, minute = GetGameTime()
            end
            local clockFormat = UIThingsDB.misc.minimapClockFormat or "24H"
            if clockFormat == "24H" then
                clockText:SetFormattedText("%02d:%02d", hour, minute)
            else
                local ampm = "AM"
                if hour >= 12 then ampm = "PM" end
                if hour == 0 then hour = 12 elseif hour > 12 then hour = hour - 12 end
                clockText:SetFormattedText("%d:%02d %s", hour, minute, ampm)
            end
        end
        UpdateClock()

        -- Update clock every second for responsiveness
        local clockTicker = C_Timer.NewTicker(1, UpdateClock)

        -- Zone event handler
        minimapFrame:SetScript("OnEvent", function(self, event, ...)
            if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
                if zoneText then
                    zoneText:SetText(GetMinimapZoneText())
                end
            elseif event == "CRAFTINGORDERS_UPDATE_PERSONAL_ORDER_COUNTS" then
                -- Refresh icons when orders update
                PositionMinimapIcons()
            end
        end)

        -- Make it movable via a drag overlay
        minimapFrame:SetMovable(true)

        -- Create an overlay that intercepts all mouse input when unlocked
        local dragOverlay = CreateFrame("Frame", nil, minimapFrame)
        dragOverlay:SetAllPoints(minimapFrame)
        dragOverlay:SetFrameStrata("TOOLTIP") -- Above everything on the minimap
        dragOverlay:EnableMouse(true)
        dragOverlay:RegisterForDrag("LeftButton")
        dragOverlay:SetScript("OnDragStart", function()
            minimapFrame:StartMoving()
        end)
        dragOverlay:SetScript("OnDragStop", function()
            minimapFrame:StopMovingOrSizing()
            local point, _, relPoint, x, y = minimapFrame:GetPoint()
            UIThingsDB.misc.minimapPos.point = point
            UIThingsDB.misc.minimapPos.relPoint = relPoint
            UIThingsDB.misc.minimapPos.x = x
            UIThingsDB.misc.minimapPos.y = y
        end)

        -- Store reference for lock toggling
        minimapFrame.dragOverlay = dragOverlay

        -- Always start locked
        dragOverlay:Hide()
    end

    -- Apply the shape
    ApplyMinimapShape(settings.minimapShape)

    -- Position any enabled minimap icons on the right side
    PositionMinimapIcons()
end

-- == Exported Functions ==

function MinimapCustom.ApplyMinimapShape(shape)
    ApplyMinimapShape(shape)
end

function MinimapCustom.UpdateMinimapIcons()
    PositionMinimapIcons()
end

function MinimapCustom.SetMinimapLocked(locked)
    minimapLocked = locked
    if minimapFrame and minimapFrame.dragOverlay then
        if locked then
            minimapFrame.dragOverlay:Hide()
        else
            minimapFrame.dragOverlay:Show()
        end
    end
end

function MinimapCustom.SetZoneLocked(locked)
    if minimapFrame and minimapFrame.zoneFrame and minimapFrame.zoneFrame.dragOverlay then
        if locked then
            minimapFrame.zoneFrame.dragOverlay:Hide()
        else
            minimapFrame.zoneFrame.dragOverlay:Show()
        end
    end
end

function MinimapCustom.SetClockLocked(locked)
    if minimapFrame and minimapFrame.clockFrame and minimapFrame.clockFrame.dragOverlay then
        if locked then
            minimapFrame.clockFrame.dragOverlay:Hide()
        else
            minimapFrame.clockFrame.dragOverlay:Show()
        end
    end
end

function MinimapCustom.UpdateMinimapBorder()
    if not borderBackdrop or not minimapFrame then return end
    local settings = UIThingsDB.misc
    local bc = settings.minimapBorderColor or { r = 0, g = 0, b = 0, a = 1 }
    borderBackdrop:SetColorTexture(bc.r, bc.g, bc.b, bc.a or 1)

    local borderSize = settings.minimapBorderSize or 3
    local mapSize = Minimap:GetWidth()
    minimapFrame:SetSize(mapSize + (borderSize * 2), mapSize + (borderSize * 2))
end

function MinimapCustom.UpdateZoneText()
    if not zoneText then return end
    local settings = UIThingsDB.misc
    zoneText:SetFont(settings.minimapZoneFont or "Fonts\\FRIZQT__.TTF", settings.minimapZoneFontSize or 12, "OUTLINE")
    local zc = settings.minimapZoneFontColor or { r = 1, g = 1, b = 1 }
    zoneText:SetTextColor(zc.r, zc.g, zc.b)
    if minimapFrame and minimapFrame.zoneFrame then
        if settings.minimapShowZone then
            minimapFrame.zoneFrame:Show()
        else
            minimapFrame.zoneFrame:Hide()
        end
    end
end

function MinimapCustom.UpdateZonePosition(x, y)
    if minimapFrame and minimapFrame.zoneFrame then
        UIThingsDB.misc.minimapZoneOffset = { x = x, y = y }
        minimapFrame.zoneFrame:ClearAllPoints()
        minimapFrame.zoneFrame:SetPoint("BOTTOM", Minimap, "TOP", x, y)
    end
end

function MinimapCustom.UpdateClockText()
    if not clockText then return end
    local settings = UIThingsDB.misc
    clockText:SetFont(settings.minimapClockFont or "Fonts\\FRIZQT__.TTF", settings.minimapClockFontSize or 11, "OUTLINE")
    local cc = settings.minimapClockFontColor or { r = 1, g = 1, b = 1 }
    clockText:SetTextColor(cc.r, cc.g, cc.b)
    if minimapFrame and minimapFrame.clockFrame then
        if settings.minimapShowClock then
            minimapFrame.clockFrame:Show()
        else
            minimapFrame.clockFrame:Hide()
        end
    end
end

function MinimapCustom.UpdateClockPosition(x, y)
    if minimapFrame and minimapFrame.clockFrame then
        UIThingsDB.misc.minimapClockOffset = { x = x, y = y }
        minimapFrame.clockFrame:ClearAllPoints()
        minimapFrame.clockFrame:SetPoint("TOP", Minimap, "BOTTOM", x, y)
    end
end

function MinimapCustom.SetupMinimap()
    SetupMinimap()
end

-- == Minimap Drawer ==

local drawerFrame = nil
local drawerToggleBtn = nil
local drawerCollapsed = false
local collectedButtons = {}

local DRAWER_BLACKLIST = {
    ["MinimapZoomIn"] = true,
    ["MinimapZoomOut"] = true,
    ["MiniMapTrackingButton"] = true,
    ["MinimapBackdrop"] = true,
    ["GameTimeFrame"] = true,
    ["TimeManagerClockButton"] = true,
    ["QueueStatusButton"] = true,
    ["AddonCompartmentFrame"] = true,
    ["ExpansionLandingPageMinimapButton"] = true,
    ["LunaMinimapFrame"] = true,
    ["LunaMinimapZoneFrame"] = true,
    ["LunaMinimapClockFrame"] = true,
    ["LunaMinimapDrawer"] = true,
}

local function IsMinimapButton(child)
    local name = child:GetName()
    if name and DRAWER_BLACKLIST[name] then return false end

    -- Skip non-interactive frame types (mask textures, etc.)
    if not (child:IsObjectType("Button") or child:IsObjectType("Frame")) then return false end

    -- Skip tiny frames (mask textures, helper frames)
    local w, h = child:GetSize()
    if w < 16 or h < 16 then return false end

    -- Skip frames that are clearly not buttons (very large frames like the minimap itself)
    if w > 60 or h > 60 then return false end

    -- Must have been shown at some point (skip purely hidden helper frames)
    if not child:IsShown() then return false end

    -- Check for icon textures (LibDBIcon pattern: .icon or .Icon)
    if child.icon or child.Icon or child.texture or child.Texture then return true end

    -- Check if it has a visible texture region as a child
    local regions = { child:GetRegions() }
    for _, region in ipairs(regions) do
        if region:IsObjectType("Texture") and region:IsShown() then
            local tex = region:GetTexture()
            if tex then return true end
        end
    end

    -- Check name patterns for known addon button conventions
    if name then
        if name:find("LibDBIcon") or name:find("MinimapButton") or name:find("Minimap.*Button") then
            return true
        end
    end

    return false
end

local function IsDrawerOnRightSide()
    if not drawerFrame then return true end
    local cx = drawerFrame:GetCenter()
    if not cx then return true end
    local screenW = UIParent:GetWidth()
    return cx > (screenW / 2)
end

-- Creates or retrieves 3-sided border textures on a frame
-- skipSide: "LEFT" or "RIGHT" — the side adjacent to the toggle button
local function EnsureBorderTextures(frame)
    if not frame.borderLines then
        frame.borderLines = {
            top = frame:CreateTexture(nil, "OVERLAY"),
            bottom = frame:CreateTexture(nil, "OVERLAY"),
            left = frame:CreateTexture(nil, "OVERLAY"),
            right = frame:CreateTexture(nil, "OVERLAY"),
        }
        for _, tex in pairs(frame.borderLines) do
            tex:SetColorTexture(1, 1, 1, 1)
        end
    end
    return frame.borderLines
end

local function ApplyThreeSidedBorder(frame, borderSize, bc, skipSide)
    local lines = EnsureBorderTextures(frame)

    if borderSize <= 0 then
        for _, tex in pairs(lines) do tex:Hide() end
        return
    end

    -- Top border
    lines.top:ClearAllPoints()
    lines.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    lines.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    lines.top:SetHeight(borderSize)
    lines.top:SetColorTexture(bc.r, bc.g, bc.b, bc.a or 1)
    lines.top:Show()

    -- Bottom border
    lines.bottom:ClearAllPoints()
    lines.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    lines.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    lines.bottom:SetHeight(borderSize)
    lines.bottom:SetColorTexture(bc.r, bc.g, bc.b, bc.a or 1)
    lines.bottom:Show()

    -- Left border
    if skipSide == "LEFT" then
        lines.left:Hide()
    else
        lines.left:ClearAllPoints()
        lines.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        lines.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        lines.left:SetWidth(borderSize)
        lines.left:SetColorTexture(bc.r, bc.g, bc.b, bc.a or 1)
        lines.left:Show()
    end

    -- Right border
    if skipSide == "RIGHT" then
        lines.right:Hide()
    else
        lines.right:ClearAllPoints()
        lines.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        lines.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        lines.right:SetWidth(borderSize)
        lines.right:SetColorTexture(bc.r, bc.g, bc.b, bc.a or 1)
        lines.right:Show()
    end
end

local function UpdateToggleBtnColor()
    if not drawerToggleBtn then return end
    local settings = UIThingsDB.misc
    local bg = settings.minimapDrawerBgColor or { r = 0, g = 0, b = 0, a = 0.7 }
    local bc = settings.minimapDrawerBorderColor or { r = 0.3, g = 0.3, b = 0.3, a = 1 }
    local borderSize = settings.minimapDrawerBorderSize or 2

    -- Background only via backdrop (no edge)
    drawerToggleBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    drawerToggleBtn:SetBackdropColor(bg.r, bg.g, bg.b, bg.a or 0.7)

    -- 3-sided border: skip the side touching the drawer
    local onRight = IsDrawerOnRightSide()
    local skipSide = onRight and "RIGHT" or "LEFT"
    ApplyThreeSidedBorder(drawerToggleBtn, borderSize, bc, skipSide)
end

local function ApplyDrawerLockVisuals()
    if not drawerFrame then return end
    local settings = UIThingsDB.misc
    local borderSize = settings.minimapDrawerBorderSize or 2
    local bc = settings.minimapDrawerBorderColor or { r = 0.3, g = 0.3, b = 0.3, a = 1 }
    local bg = settings.minimapDrawerBgColor or { r = 0, g = 0, b = 0, a = 0.7 }

    if settings.minimapDrawerLocked then
        -- Locked: bg only via backdrop, manual 3-sided border
        drawerFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
        })
        drawerFrame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a or 0.7)

        -- 3-sided border: skip the side where the toggle button sits
        local onRight = IsDrawerOnRightSide()
        local skipSide = onRight and "LEFT" or "RIGHT"
        ApplyThreeSidedBorder(drawerFrame, borderSize, bc, skipSide)
    else
        -- Unlocked: full drag backdrop, hide manual borders
        drawerFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        drawerFrame:SetBackdropColor(0, 0, 0, 0.7)
        drawerFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

        -- Hide manual border lines when unlocked
        if drawerFrame.borderLines then
            for _, tex in pairs(drawerFrame.borderLines) do tex:Hide() end
        end
    end

    UpdateToggleBtnColor()
end

local TOGGLE_BTN_WIDTH = 16

local function UpdateToggleButton()
    if not drawerToggleBtn or not drawerFrame then return end
    local onRight = IsDrawerOnRightSide()
    local frameH = drawerFrame:GetHeight()

    drawerToggleBtn:SetSize(TOGGLE_BTN_WIDTH, frameH)
    drawerToggleBtn:ClearAllPoints()

    if onRight then
        -- Toggle on the left side of the drawer
        drawerToggleBtn:SetPoint("TOPRIGHT", drawerFrame, "TOPLEFT", 0, 0)
        if drawerCollapsed then
            drawerToggleBtn.text:SetText("<")
        else
            drawerToggleBtn.text:SetText(">")
        end
    else
        -- Toggle on the right side of the drawer
        drawerToggleBtn:SetPoint("TOPLEFT", drawerFrame, "TOPRIGHT", 0, 0)
        if drawerCollapsed then
            drawerToggleBtn.text:SetText(">")
        else
            drawerToggleBtn.text:SetText("<")
        end
    end
end

local function SetDrawerCollapsed(collapsed)
    drawerCollapsed = collapsed

    for _, entry in ipairs(collectedButtons) do
        if collapsed then
            entry.button:Hide()
        else
            entry.button:Show()
        end
    end

    if drawerFrame then
        if collapsed then
            drawerFrame:SetSize(1, drawerFrame:GetHeight())
            drawerFrame:SetBackdrop(nil)
        else
            -- Re-layout to restore proper size
            local settings = UIThingsDB.misc
            local btnSize = settings.minimapDrawerButtonSize or 32
            local padding = settings.minimapDrawerPadding or 4
            local count = #collectedButtons
            if count > 0 then
                local numCols = math.ceil(count / 2)
                local numRows = math.min(count, 2)
                local frameW = (numCols * btnSize) + ((numCols + 1) * padding)
                local frameH = (numRows * btnSize) + ((numRows + 1) * padding)
                drawerFrame:SetSize(frameW, frameH)
            end
            ApplyDrawerLockVisuals()
        end
    end

    UpdateToggleButton()
end

local function LayoutDrawerButtons()
    if not drawerFrame then return end
    local settings = UIThingsDB.misc
    local btnSize = settings.minimapDrawerButtonSize or 32
    local padding = settings.minimapDrawerPadding or 4

    local count = #collectedButtons
    if count == 0 then
        drawerFrame:SetSize(1, 1)
        drawerFrame:Hide()
        if drawerToggleBtn then drawerToggleBtn:Hide() end
        return
    end

    -- Layout in pairs: 2 rows, columns expand as needed
    local numCols = math.ceil(count / 2)
    local numRows = math.min(count, 2)
    local frameW = (numCols * btnSize) + ((numCols + 1) * padding)
    local frameH = (numRows * btnSize) + ((numRows + 1) * padding)

    drawerFrame:SetSize(frameW, frameH)

    for i, entry in ipairs(collectedButtons) do
        local btn = entry.button
        -- Fill top row first, then bottom row
        local col = (i - 1) % numCols
        local row = math.floor((i - 1) / numCols)
        local x = padding + (col * (btnSize + padding))
        local y = -(padding + (row * (btnSize + padding)))

        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", drawerFrame, "TOPLEFT", x, y)
        btn:SetSize(btnSize, btnSize)
        btn:SetParent(drawerFrame)
        btn:SetFrameStrata("MEDIUM")
        btn:SetFrameLevel(drawerFrame:GetFrameLevel() + 5)

        if drawerCollapsed then
            btn:Hide()
        else
            btn:Show()
        end
    end

    drawerFrame:Show()

    if drawerCollapsed then
        drawerFrame:SetSize(1, frameH)
        drawerFrame:SetBackdrop(nil)
    end

    UpdateToggleButton()
    if drawerToggleBtn then drawerToggleBtn:Show() end
end

local function CollectMinimapButtons()
    -- Track already-collected buttons for dedup
    local alreadyCollected = {}
    for _, entry in ipairs(collectedButtons) do
        alreadyCollected[entry.button] = true
    end

    local sources = { Minimap:GetChildren() }

    for _, child in ipairs(sources) do
        if not alreadyCollected[child] and IsMinimapButton(child) then
            -- Save original state for restoration
            local origParent = child:GetParent()
            local origPoints = {}
            for p = 1, child:GetNumPoints() do
                origPoints[p] = { child:GetPoint(p) }
            end
            local origW, origH = child:GetSize()

            table.insert(collectedButtons, {
                button = child,
                origParent = origParent,
                origPoints = origPoints,
                origWidth = origW,
                origHeight = origH,
            })
        end
    end

    LayoutDrawerButtons()
end

local function ReleaseDrawerButtons()
    for _, entry in ipairs(collectedButtons) do
        local btn = entry.button
        btn:SetParent(entry.origParent)
        btn:ClearAllPoints()
        btn:SetSize(entry.origWidth, entry.origHeight)
        for _, pt in ipairs(entry.origPoints) do
            btn:SetPoint(unpack(pt))
        end
    end
    wipe(collectedButtons)
end

local function SetupDrawer()
    local settings = UIThingsDB.misc
    if not settings.minimapDrawerEnabled then return end

    if not drawerFrame then
        drawerFrame = CreateFrame("Frame", "LunaMinimapDrawer", UIParent, "BackdropTemplate")
        drawerFrame:SetClampedToScreen(true)
        drawerFrame:SetMovable(true)

        local pos = settings.minimapDrawerPos
        drawerFrame:ClearAllPoints()
        drawerFrame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)

        -- Apply lock-dependent visuals
        ApplyDrawerLockVisuals()

        -- Drag overlay for lock/unlock
        local dragOverlay = CreateFrame("Frame", nil, drawerFrame)
        dragOverlay:SetAllPoints(drawerFrame)
        dragOverlay:SetFrameStrata("TOOLTIP")
        dragOverlay:EnableMouse(true)
        dragOverlay:RegisterForDrag("LeftButton")
        dragOverlay:SetScript("OnDragStart", function()
            drawerFrame:StartMoving()
        end)
        dragOverlay:SetScript("OnDragStop", function()
            drawerFrame:StopMovingOrSizing()
            local point, _, relPoint, x, y = drawerFrame:GetPoint()
            UIThingsDB.misc.minimapDrawerPos = { point = point, relPoint = relPoint, x = x, y = y }
            -- Update toggle side after moving
            UpdateToggleButton()
        end)

        drawerFrame.dragOverlay = dragOverlay

        -- Collapse/expand toggle button
        drawerToggleBtn = CreateFrame("Button", nil, drawerFrame, "BackdropTemplate")
        drawerToggleBtn:SetSize(TOGGLE_BTN_WIDTH, 40)
        local tbg = settings.minimapDrawerBgColor or { r = 0, g = 0, b = 0, a = 0.7 }
        drawerToggleBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
        })
        drawerToggleBtn:SetBackdropColor(tbg.r, tbg.g, tbg.b, tbg.a or 0.7)

        local toggleText = drawerToggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        toggleText:SetPoint("CENTER")
        toggleText:SetText(">")
        drawerToggleBtn.text = toggleText

        drawerToggleBtn:SetScript("OnClick", function()
            SetDrawerCollapsed(not drawerCollapsed)
        end)

        -- Apply lock state
        if settings.minimapDrawerLocked then
            dragOverlay:Hide()
        else
            dragOverlay:Show()
        end
    end

    CollectMinimapButtons()

    -- Delayed re-collect for addons that create buttons lazily
    C_Timer.After(3, function()
        if drawerFrame and UIThingsDB.misc.minimapDrawerEnabled then
            CollectMinimapButtons()
        end
    end)
end

function MinimapCustom.SetupDrawer()
    SetupDrawer()
end

function MinimapCustom.DestroyDrawer()
    ReleaseDrawerButtons()
    if drawerFrame then
        drawerFrame:Hide()
    end
    if drawerToggleBtn then
        drawerToggleBtn:Hide()
    end
end

function MinimapCustom.SetDrawerLocked(locked)
    UIThingsDB.misc.minimapDrawerLocked = locked
    if drawerFrame and drawerFrame.dragOverlay then
        if locked then
            drawerFrame.dragOverlay:Hide()
        else
            drawerFrame.dragOverlay:Show()
        end
    end
    ApplyDrawerLockVisuals()
end

function MinimapCustom.UpdateDrawerBorder()
    if not drawerCollapsed then
        ApplyDrawerLockVisuals()
    end
end

function MinimapCustom.RefreshDrawer()
    if drawerFrame and UIThingsDB.misc.minimapDrawerEnabled then
        CollectMinimapButtons()
    end
end

-- == Events ==

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == "Blizzard_HybridMinimap" then
            -- Apply mask to HybridMinimap when it loads
            if UIThingsDB.misc and UIThingsDB.misc.minimapEnabled then
                ApplyMinimapShape(UIThingsDB.misc.minimapShape)
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if UIThingsDB.misc then
            SetupMinimap()
            SetupDrawer()
        end
    end
end)
