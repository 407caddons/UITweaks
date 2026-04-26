local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

table.insert(Widgets.moduleInits, function()
    local guildFrame = Widgets.CreateWidgetFrame("Guild", "guild")
    guildFrame:SetScript("OnClick", function() ToggleGuildFrame() end)

    guildFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        if not Widgets.SmartAnchorTooltip(self) then return end
        GameTooltip:SetText("Online Guild Members")

        if IsInGuild() then
            local numMembers = GetNumGuildMembers()
            local online = {}
            for i = 1, numMembers do
                local name, rank, rankIndex, level, class, zone, note, officernote, isOnline, status, classFileName =
                    GetGuildRosterInfo(i)
                if isOnline then
                    online[#online + 1] = {
                        name          = name:match("^([^-]+)") or name,
                        level         = level,
                        zone          = zone or "",
                        classFileName = classFileName,
                    }
                end
            end
            table.sort(online, function(a, b) return a.name < b.name end)
            for _, m in ipairs(online) do
                local rightText = m.zone .. "  " .. m.level
                local classColor = C_ClassColor.GetClassColor(m.classFileName)
                if classColor then
                    GameTooltip:AddDoubleLine(m.name, rightText, classColor.r, classColor.g, classColor.b, 0.7, 0.7, 0.7)
                else
                    GameTooltip:AddDoubleLine(m.name, rightText, 1, 1, 1, 0.7, 0.7, 0.7)
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
