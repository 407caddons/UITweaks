local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

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
                    local charName = name:match("^([^-]+)") or name
                    local rightText = (zone or "") .. "  " .. level
                    local classColor = C_ClassColor.GetClassColor(classFileName)
                    if classColor then
                        GameTooltip:AddDoubleLine(charName, rightText, classColor.r, classColor.g, classColor.b, 0.7, 0.7,
                            0.7)
                    else
                        GameTooltip:AddDoubleLine(charName, rightText, 1, 1, 1, 0.7, 0.7, 0.7)
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

    local function OnGuildUpdate()
        RefreshGuildCache()
    end

    guildFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("GUILD_ROSTER_UPDATE", OnGuildUpdate, "W:Guild")
            EventBus.Register("PLAYER_GUILD_UPDATE", OnGuildUpdate, "W:Guild")
            EventBus.Register("PLAYER_ENTERING_WORLD", OnGuildUpdate, "W:Guild")
        else
            EventBus.Unregister("GUILD_ROSTER_UPDATE", OnGuildUpdate)
            EventBus.Unregister("PLAYER_GUILD_UPDATE", OnGuildUpdate)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnGuildUpdate)
        end
    end

    guildFrame.UpdateContent = function(self)
        self.text:SetText(cachedText)
    end
end)
