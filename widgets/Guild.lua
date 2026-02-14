local addonName, addonTable = ...
local Widgets = addonTable.Widgets

table.insert(Widgets.moduleInits, function()
    local guildFrame = Widgets.CreateWidgetFrame("Guild", "guild")
    guildFrame:SetScript("OnClick", function() ToggleGuildFrame() end)

    guildFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Online Guild Members")

        if IsInGuild() then
            local numMembers = GetNumGuildMembers()
            for i = 1, numMembers do
                local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName =
                    GetGuildRosterInfo(i)
                if online then
                    -- Fix malformed names with repeated realm (e.g. "Name-Realm-Realm-Realm...")
                    local charName, realm = name:match("^([^-]+)-(.+)$")
                    local shortName = name
                    if charName and realm then
                        realm = realm:match("^([^-]+)") or realm
                        shortName = charName .. "-" .. realm
                    end
                    local rightText = zone or ""
                    local classColor = C_ClassColor.GetClassColor(classFileName)
                    if classColor then
                        GameTooltip:AddDoubleLine(shortName, rightText, classColor.r, classColor.g, classColor.b, 0.7,
                            0.7,
                            0.7)
                    else
                        GameTooltip:AddDoubleLine(shortName, rightText, 1, 1, 1, 0.7, 0.7, 0.7)
                    end
                end
            end
        else
            GameTooltip:AddLine("Not in a guild")
        end
        GameTooltip:Show()
    end)
    guildFrame:SetScript("OnLeave", GameTooltip_Hide)

    -- Cached guild count (updated on events, not every second)
    local cachedText = "Guild: -"

    local function RefreshGuildCache()
        if IsInGuild() then
            local _, numOnline = GetNumGuildMembers()
            cachedText = string.format("Guild: %d", numOnline or 0)
        else
            cachedText = "Guild: -"
        end
    end

    local guildEventFrame = CreateFrame("Frame")
    guildEventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
    guildEventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
    guildEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    guildEventFrame:SetScript("OnEvent", function()
        RefreshGuildCache()
    end)

    guildFrame.eventFrame = guildEventFrame
    guildFrame.ApplyEvents = function(enabled)
        if enabled then
            guildEventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
            guildEventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
            guildEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        else
            guildEventFrame:UnregisterAllEvents()
        end
    end

    guildFrame.UpdateContent = function(self)
        self.text:SetText(cachedText)
    end
end)
