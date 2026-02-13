local addonName, addonTable = ...
local Widgets = addonTable.Widgets

table.insert(Widgets.moduleInits, function()
    local zoneFrame = Widgets.CreateWidgetFrame("Zone", "zone")

    -- Cached zone text (updated on events, not every second)
    local cachedText = ""

    local function RefreshZoneCache()
        local subZone = GetSubZoneText()
        local zone = GetZoneText()
        if subZone and subZone ~= "" then
            cachedText = subZone
        elseif zone and zone ~= "" then
            cachedText = zone
        else
            cachedText = "Unknown"
        end
    end

    local zoneEventFrame = CreateFrame("Frame")
    zoneEventFrame:RegisterEvent("ZONE_CHANGED")
    zoneEventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    zoneEventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    zoneEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    zoneEventFrame:SetScript("OnEvent", function()
        RefreshZoneCache()
    end)

    zoneFrame.eventFrame = zoneEventFrame
    zoneFrame.ApplyEvents = function(enabled)
        if enabled then
            zoneEventFrame:RegisterEvent("ZONE_CHANGED")
            zoneEventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
            zoneEventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
            zoneEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        else
            zoneEventFrame:UnregisterAllEvents()
        end
    end

    zoneFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Zone Info")

        local zone = GetZoneText()
        local subZone = GetSubZoneText()
        local realZone = GetRealZoneText()
        local minimapZone = GetMinimapZoneText()

        GameTooltip:AddDoubleLine("Zone:", zone or "—", 1, 1, 1, 1, 1, 1)
        if subZone and subZone ~= "" then
            GameTooltip:AddDoubleLine("Subzone:", subZone, 1, 1, 1, 0.8, 0.8, 0.8)
        end
        if realZone and realZone ~= zone then
            GameTooltip:AddDoubleLine("Real Zone:", realZone, 1, 1, 1, 0.8, 0.8, 0.8)
        end

        -- PvP zone info
        local pvpType, isFFA, faction = C_PvP.GetZonePVPInfo()
        if pvpType then
            local pvpText = pvpType
            if pvpType == "sanctuary" then
                pvpText = "|cFF00FF00Sanctuary|r"
            elseif pvpType == "friendly" then
                pvpText = "|cFF00FF00Friendly|r"
            elseif pvpType == "hostile" then
                pvpText = "|cFFFF0000Hostile|r"
            elseif pvpType == "contested" then
                pvpText = "|cFFFFFF00Contested|r"
            elseif pvpType == "combat" then
                pvpText = "|cFFFF0000Combat Zone|r"
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("PvP:", pvpText, 1, 1, 1)
        end

        -- Instance info
        local instanceName, instanceType, difficultyID, difficultyName = GetInstanceInfo()
        if instanceType ~= "none" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Instance:", instanceName, 1, 1, 1, 1, 1, 1)
            if difficultyName and difficultyName ~= "" then
                GameTooltip:AddDoubleLine("Difficulty:", difficultyName, 1, 1, 1, 0.8, 0.8, 0.8)
            end
        end

        GameTooltip:Show()
    end)
    zoneFrame:SetScript("OnLeave", GameTooltip_Hide)

    zoneFrame.UpdateContent = function(self)
        self.text:SetText(cachedText)
    end
end)
