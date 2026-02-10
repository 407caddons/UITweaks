local addonName, addonTable = ...
local Misc = {}
addonTable.Misc = Misc

-- == PERSONAL ORDER ALERT ==

local alertFrame = CreateFrame("Frame", "UIThingsPersonalAlert", UIParent, "BackdropTemplate")
alertFrame:SetSize(400, 50)
alertFrame:SetPoint("TOP", 0, -200)
alertFrame:SetFrameStrata("DIALOG")
alertFrame:Hide()

alertFrame.text = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
alertFrame.text:SetPoint("CENTER")
alertFrame.text:SetText("Personal Order Arrived")

local function ShowAlert()
    if not UIThingsDB.misc.personalOrders then return end

    local color = UIThingsDB.misc.alertColor
    alertFrame.text:SetTextColor(color.r, color.g, color.b, color.a or 1)

    alertFrame:Show()

    -- TTS using correct API (only if enabled)
    if UIThingsDB.misc.ttsEnabled then
        local message = UIThingsDB.misc.ttsMessage or "Personal order arrived"
        local voiceType = UIThingsDB.misc.ttsVoice or 0

        if TextToSpeech_Speak then
            local voiceID = TextToSpeech_GetSelectedVoice and TextToSpeech_GetSelectedVoice(voiceType) or nil
            pcall(function()
                TextToSpeech_Speak(message, voiceID)
            end)
        elseif C_VoiceChat and C_VoiceChat.SpeakText then
            pcall(function()
                C_VoiceChat.SpeakText(0, message, voiceType, 1.0, false)
            end)
        end
    end

    -- Hide after duration
    local duration = UIThingsDB.misc.alertDuration or 5
    local SafeAfter = function(delay, func)
        if addonTable.Core and addonTable.Core.SafeAfter then
            addonTable.Core.SafeAfter(delay, func)
        elseif C_Timer and C_Timer.After then
            C_Timer.After(delay, func)
        end
    end
    SafeAfter(duration, function()
        alertFrame:Hide()
    end)
end

-- Expose ShowAlert for test button
function Misc.ShowAlert()
    ShowAlert()
end

-- Expose for testing
function Misc.TestTTS()
    local message = UIThingsDB.misc.ttsMessage or "Personal order arrived"
    local voiceType = UIThingsDB.misc.ttsVoice or 0

    -- Method 1: Try TextToSpeech_Speak (global function)
    if TextToSpeech_Speak then
        local voiceID = TextToSpeech_GetSelectedVoice and TextToSpeech_GetSelectedVoice(voiceType) or nil
        pcall(function()
            TextToSpeech_Speak(message, voiceID)
        end)
        return
    end

    -- Method 2: Try C_VoiceChat.SpeakText
    if C_VoiceChat and C_VoiceChat.SpeakText then
        pcall(function()
            C_VoiceChat.SpeakText(0, message, voiceType, 1.0, false)
        end)
    end
end

-- == AH FILTER ==

local hookSet = false

local function ApplyAHFilter()
    if not UIThingsDB.misc.ahFilter then return end

    if not AuctionHouseFrame then return end

    -- Function to apply filter
    local function SetFilter()
        if not UIThingsDB.misc.ahFilter then return end
        local searchBar = AuctionHouseFrame.SearchBar
        if searchBar and searchBar.FilterButton then
            searchBar.FilterButton.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
            searchBar:UpdateClearFiltersButton()
        end
    end

    -- Apply immediately (with slight delay for ensuring frame is ready)
    local SafeAfter = function(delay, func)
        if addonTable.Core and addonTable.Core.SafeAfter then
            addonTable.Core.SafeAfter(delay, func)
        elseif C_Timer and C_Timer.After then
            C_Timer.After(delay, func)
        end
    end
    SafeAfter(0, SetFilter)

    -- Hook for persistence (Tab switching or re-showing)
    if not hookSet then
        if AuctionHouseFrame.SearchBar then
            AuctionHouseFrame.SearchBar:HookScript("OnShow", function()
                SafeAfter(0, SetFilter)
            end)
            hookSet = true
        end
    end
end

-- == UI SCALING ==

local function ApplyUIScale()
    if not UIThingsDB.misc.uiScaleEnabled then return end

    local scale = UIThingsDB.misc.uiScale or 0.711
    -- Round to 3 decimal places to avoid precision issues with CVars
    scale = tonumber(string.format("%.3f", scale))
    
    SetCVar("useUiScale", "1")
    SetCVar("uiScale", tostring(scale))
    
    -- Force UIParent scale to bypass internal 0.64 floor in TWW
    UIParent:SetScale(scale)
end

-- Expose ApplyUIScale
function Misc.ApplyUIScale()
    ApplyUIScale()
end
-- == MINIMAP CUSTOMIZATION ==

local minimapFrame = nil
local borderBackdrop = nil
local borderMask = nil
local BORDER_SIZE = 4
local minimapLocked = true -- Runtime-only, always defaults to locked

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

local zoneText = nil
local clockText = nil

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
        clockText:SetFont(settings.minimapClockFont or "Fonts\\FRIZQT__.TTF", settings.minimapClockFontSize or 11, "OUTLINE")
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


-- Expose functions
function Misc.ApplyMinimapShape(shape)
    ApplyMinimapShape(shape)
end

function Misc.UpdateMinimapIcons()
    PositionMinimapIcons()
end

function Misc.SetMinimapLocked(locked)
    minimapLocked = locked
    if minimapFrame and minimapFrame.dragOverlay then
        if locked then
            minimapFrame.dragOverlay:Hide()
        else
            minimapFrame.dragOverlay:Show()
        end
    end
end

function Misc.SetZoneLocked(locked)
    if minimapFrame and minimapFrame.zoneFrame and minimapFrame.zoneFrame.dragOverlay then
        if locked then
            minimapFrame.zoneFrame.dragOverlay:Hide()
        else
            minimapFrame.zoneFrame.dragOverlay:Show()
        end
    end
end

function Misc.SetClockLocked(locked)
    if minimapFrame and minimapFrame.clockFrame and minimapFrame.clockFrame.dragOverlay then
        if locked then
            minimapFrame.clockFrame.dragOverlay:Hide()
        else
            minimapFrame.clockFrame.dragOverlay:Show()
        end
    end
end

function Misc.UpdateMinimapBorder()
    if not borderBackdrop or not minimapFrame then return end
    local settings = UIThingsDB.misc
    local bc = settings.minimapBorderColor or { r = 0, g = 0, b = 0, a = 1 }
    borderBackdrop:SetColorTexture(bc.r, bc.g, bc.b, bc.a or 1)

    local borderSize = settings.minimapBorderSize or 3
    local mapSize = Minimap:GetWidth()
    minimapFrame:SetSize(mapSize + (borderSize * 2), mapSize + (borderSize * 2))
end

function Misc.UpdateZoneText()
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

function Misc.UpdateZonePosition(x, y)
    if minimapFrame and minimapFrame.zoneFrame then
        UIThingsDB.misc.minimapZoneOffset = { x = x, y = y }
        minimapFrame.zoneFrame:ClearAllPoints()
        minimapFrame.zoneFrame:SetPoint("BOTTOM", Minimap, "TOP", x, y)
    end
end

function Misc.UpdateClockText()
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

function Misc.UpdateClockPosition(x, y)
    if minimapFrame and minimapFrame.clockFrame then
        UIThingsDB.misc.minimapClockOffset = { x = x, y = y }
        minimapFrame.clockFrame:ClearAllPoints()
        minimapFrame.clockFrame:SetPoint("TOP", Minimap, "BOTTOM", x, y)
    end
end



function Misc.SetupMinimap()
    SetupMinimap()
end

-- == EVENTS ==

-- Slash command for /rl
SLASH_LUNAUIRELOAD1 = "/rl"
SlashCmdList["LUNAUIRELOAD"] = function()
    if UIThingsDB.misc.enabled and UIThingsDB.misc.allowRL then
        ReloadUI()
    else
        -- If LunaUI isn't handling it, pass it to standard /reload or just do nothing
        -- This ensures we don't block other addons if our feature is disabled
        StaticPopup_Show("RELOAD_UI")
    end
end

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == "Blizzard_HybridMinimap" then
            -- Apply mask to HybridMinimap when it loads
            if UIThingsDB.misc and UIThingsDB.misc.enabled and UIThingsDB.misc.minimapEnabled then
                ApplyMinimapShape(UIThingsDB.misc.minimapShape)
            end
        end
        return
    end

    if not UIThingsDB.misc or not UIThingsDB.misc.enabled then return end

    if event == "PLAYER_ENTERING_WORLD" then
        ApplyUIScale()
        SetupMinimap()
    elseif event == "AUCTION_HOUSE_SHOW" then
        -- Apply once initially
        local SafeAfter = function(delay, func)
            if addonTable.Core and addonTable.Core.SafeAfter then
                addonTable.Core.SafeAfter(delay, func)
            elseif C_Timer and C_Timer.After then
                C_Timer.After(delay, func)
            end
        end
        SafeAfter(0.5, ApplyAHFilter)
    elseif event == "CHAT_MSG_SYSTEM" then
        local msg = ...
        -- Parse for "Personal Work Order" or similar text
        if msg and (string.find(msg, "Personal Crafting Order") or string.find(msg, "Personal Order")) then
            ShowAlert()
        end
    elseif event == "PARTY_INVITE_REQUEST" then
        local name, guid = ...
        local settings = UIThingsDB.misc

        if settings.autoAcceptEveryone then
            AcceptGroup()
            StaticPopup_Hide("PARTY_INVITE")
            return
        end

        local isFriend = false
        if settings.autoAcceptFriends then
            if guid and C_FriendList.IsFriend(guid) then
                isFriend = true
            else
                -- Check BNet Friends
                local numBNet = BNGetNumFriends()
                for i = 1, numBNet do
                    local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
                    if accountInfo and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.playerGuid == guid then
                        isFriend = true
                        break
                    end
                end
            end
        end

        local isGuildMember = false
        if settings.autoAcceptGuild then
            if guid and IsGuildMember(guid) then
                isGuildMember = true
            end
        end

        if isFriend or isGuildMember then
            AcceptGroup()
            StaticPopup_Hide("PARTY_INVITE")
        end
    elseif event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
        local settings = UIThingsDB.misc
        if not settings.autoInviteEnabled or not settings.autoInviteKeywords or settings.autoInviteKeywords == "" then return end

        local msg, sender = ...
        if event == "CHAT_MSG_BN_WHISPER" then
            -- For BN whispers, sender is the presenceID, we need to get the character name/presence
            -- However, C_PartyInfo.InviteUnit usually wants a name-realm or UnitTag.
            -- BN whispers are tricky for auto-invites unless we resolve the character.
            -- For now, let's focus on character whispers first as they are more common for group formation.
            return 
        end

        -- Split keywords and check
        local keywords = {}
        for kw in string.gmatch(settings.autoInviteKeywords, "([^,]+)") do
            table.insert(keywords, kw:trim():lower())
        end

        local lowerMsg = msg:trim():lower()
        local match = false
        for _, kw in ipairs(keywords) do
            if lowerMsg == kw then
                match = true
                break
            end
        end

        if match then
            -- Can we invite? (Must be leader or not in group)
            if not IsInGroup() or UnitIsGroupLeader("player") then
                C_PartyInfo.InviteUnit(sender)
            end
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PARTY_INVITE_REQUEST")
frame:RegisterEvent("CHAT_MSG_WHISPER")
frame:RegisterEvent("CHAT_MSG_BN_WHISPER")
frame:SetScript("OnEvent", OnEvent)
