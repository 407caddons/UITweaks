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
                    local classColor = C_ClassColor.GetClassColor(classFileName)
                    if classColor then
                        GameTooltip:AddDoubleLine(name, "Lvl " .. level, classColor.r, classColor.g, classColor.b, 1, 1,
                            1)
                    else
                        GameTooltip:AddDoubleLine(name, "Lvl " .. level, 1, 1, 1, 1, 1, 1)
                    end
                end
            end
        else
            GameTooltip:AddLine("Not in a guild")
        end
        GameTooltip:Show()
    end)
    guildFrame:SetScript("OnLeave", GameTooltip_Hide)

    guildFrame.UpdateContent = function(self)
        if IsInGuild() then
            local _, numOnline = GetNumGuildMembers()
            self.text:SetFormattedText("Guild: %d", numOnline or 0)
        else
            self.text:SetText("Guild: -")
        end
    end
end)
