local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

table.insert(Widgets.moduleInits, function()
    local commFrame = Widgets.CreateWidgetFrame("AddonComm", "addonComm")
    commFrame:RegisterForClicks("AnyUp")

    local function GetGroupSize()
        if IsInGroup() then
            return GetNumGroupMembers()
        end
        return 0
    end

    local function UpdateCachedText(self)
        if not IsInGroup() then
            self.text:SetText("Luna: -")
            return
        end
        local playerData = addonTable.AddonVersions and addonTable.AddonVersions.GetPlayerData()
        if not playerData then
            self.text:SetText("Luna: -")
            return
        end
        local total = GetGroupSize()
        local withAddon = 0
        for _, data in pairs(playerData) do
            if data.version then
                withAddon = withAddon + 1
            end
        end
        self.text:SetFormattedText("Luna: %d/%d", withAddon, total)
    end

    commFrame:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            -- Broadcast presence / request versions from group
            if addonTable.AddonVersions then
                addonTable.AddonVersions.BroadcastPresence()
            end
        end
    end)

    commFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        if not IsInGroup() then return end
        Widgets.SmartAnchorTooltip(self)

        local playerData = addonTable.AddonVersions and addonTable.AddonVersions.GetPlayerData()
        local ownVersion = addonTable.AddonVersions and addonTable.AddonVersions.GetOwnVersion() or "?"

        GameTooltip:SetText("LunaUITweaks Group", 1, 0.82, 0)
        GameTooltip:AddDoubleLine("Your version:", ownVersion, 1, 1, 1, 0.5, 1, 0.5)
        GameTooltip:AddLine(" ")

        if playerData then
            -- Collect and sort by name
            local entries = {}
            for name, data in pairs(playerData) do
                table.insert(entries, { name = name, data = data })
            end
            table.sort(entries, function(a, b) return a.name < b.name end)

            local playerName = UnitName("player")
            for _, entry in ipairs(entries) do
                local name = entry.name
                local data = entry.data
                local isSelf = (name == playerName)
                local nr, ng, nb = 1, 1, 1
                -- Try to color by class
                if IsInRaid() or IsInGroup() then
                    local _, classToken = UnitClass(isSelf and "player" or name)
                    if classToken then
                        local cc = C_ClassColor.GetClassColor(classToken)
                        if cc then nr, ng, nb = cc.r, cc.g, cc.b end
                    end
                end
                if data.version then
                    local vr, vg, vb = 0.5, 1, 0.5  -- green: has addon
                    if data.version ~= ownVersion then
                        vr, vg, vb = 1, 0.8, 0  -- orange: different version
                    end
                    GameTooltip:AddDoubleLine(
                        (isSelf and "|cFFFFD700[You]|r " or "") .. name,
                        data.version,
                        nr, ng, nb, vr, vg, vb)
                else
                    GameTooltip:AddDoubleLine(name, "No addon", nr, ng, nb, 0.5, 0.5, 0.5)
                end
            end
        else
            GameTooltip:AddLine("No data yet", 0.5, 0.5, 0.5)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click to broadcast version", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    commFrame:SetScript("OnLeave", GameTooltip_Hide)

    local function OnGroupUpdate()
        if UIThingsDB.widgets.addonComm.enabled then
            UpdateCachedText(commFrame)
        end
    end

    commFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("GROUP_ROSTER_UPDATE", OnGroupUpdate)
            EventBus.Register("PLAYER_ENTERING_WORLD", OnGroupUpdate)
        else
            EventBus.Unregister("GROUP_ROSTER_UPDATE", OnGroupUpdate)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnGroupUpdate)
        end
    end

    commFrame.UpdateContent = function(self)
        UpdateCachedText(self)
    end
end)
