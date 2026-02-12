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
        end
    end
end)
