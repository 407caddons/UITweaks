local addonName, addonTable = ...
local Widgets = addonTable.Widgets

table.insert(Widgets.moduleInits, function()
    local volumeFrame = Widgets.CreateWidgetFrame("Volume", "volume")
    volumeFrame:RegisterForClicks("AnyUp")

    volumeFrame:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            -- Toggle master sound
            local enabled = GetCVar("Sound_EnableAllSound")
            if enabled == "1" then
                SetCVar("Sound_EnableAllSound", "0")
            else
                SetCVar("Sound_EnableAllSound", "1")
            end
        elseif button == "RightButton" then
            -- Cycle master volume: 100 -> 75 -> 50 -> 25 -> 100
            local vol = math.floor((tonumber(GetCVar("Sound_MasterVolume")) or 1) * 100 + 0.5)
            if vol > 75 then
                SetCVar("Sound_MasterVolume", "0.75")
            elseif vol > 50 then
                SetCVar("Sound_MasterVolume", "0.50")
            elseif vol > 25 then
                SetCVar("Sound_MasterVolume", "0.25")
            else
                SetCVar("Sound_MasterVolume", "1.0")
            end
        end
    end)

    volumeFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Volume Control")

        local enabled = GetCVar("Sound_EnableAllSound") == "1"
        local masterVol = tonumber(GetCVar("Sound_MasterVolume")) or 1
        local musicVol = tonumber(GetCVar("Sound_MusicVolume")) or 1
        local sfxVol = tonumber(GetCVar("Sound_SFXVolume")) or 1
        local ambienceVol = tonumber(GetCVar("Sound_AmbienceVolume")) or 1
        local dialogVol = tonumber(GetCVar("Sound_DialogVolume")) or 1

        local statusColor = enabled and { 0, 1, 0 } or { 1, 0, 0 }
        GameTooltip:AddDoubleLine("Sound:", enabled and "Enabled" or "Muted", 1, 1, 1, statusColor[1], statusColor[2],
            statusColor[3])
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Master:", string.format("%.0f%%", masterVol * 100), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Music:", string.format("%.0f%%", musicVol * 100), 1, 1, 1, 0.8, 0.8, 0.8)
        GameTooltip:AddDoubleLine("Effects:", string.format("%.0f%%", sfxVol * 100), 1, 1, 1, 0.8, 0.8, 0.8)
        GameTooltip:AddDoubleLine("Ambience:", string.format("%.0f%%", ambienceVol * 100), 1, 1, 1, 0.8, 0.8, 0.8)
        GameTooltip:AddDoubleLine("Dialog:", string.format("%.0f%%", dialogVol * 100), 1, 1, 1, 0.8, 0.8, 0.8)

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-Click: Toggle Sound", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Right-Click: Cycle Volume", 0.7, 0.7, 0.7)

        GameTooltip:Show()
    end)
    volumeFrame:SetScript("OnLeave", GameTooltip_Hide)

    volumeFrame.UpdateContent = function(self)
        local enabled = GetCVar("Sound_EnableAllSound") == "1"
        local vol = tonumber(GetCVar("Sound_MasterVolume")) or 1

        if not enabled then
            self.text:SetText("|cFFFF0000Muted|r")
        else
            self.text:SetFormattedText("Vol: %.0f%%", vol * 100)
        end
    end
end)
