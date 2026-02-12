local addonName, addonTable = ...
local Widgets = addonTable.Widgets

table.insert(Widgets.moduleInits, function()
    local fpsFrame = Widgets.CreateWidgetFrame("FPS", "fps")

    local addonMemList = {}
    local addonMemPool = {}
    local function GetMemEntry()
        local t = table.remove(addonMemPool)
        if not t then t = {} end
        return t
    end

    fpsFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        local bandwidthIn, bandwidthOut, latencyHome, latencyWorld = GetNetStats()
        local fps = GetFramerate()

        GameTooltip:SetText("Performance")
        GameTooltip:AddDoubleLine("Home MS:", latencyHome, 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("World MS:", latencyWorld, 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("FPS:", string.format("%.0f", fps), 1, 1, 1, 1, 1, 1)

        local totalMem = 0

        -- Recycle entries (always clean up previous list)
        for _, t in ipairs(addonMemList) do
            table.insert(addonMemPool, t)
        end
        wipe(addonMemList)

        if UIThingsDB.widgets.showAddonMemory then
            UpdateAddOnMemoryUsage()
            for i = 1, C_AddOns.GetNumAddOns() do
                local mem = GetAddOnMemoryUsage(i)
                totalMem = totalMem + mem
                local entry = GetMemEntry()
                local name, title = C_AddOns.GetAddOnInfo(i)
                entry.name = title or name
                entry.mem = mem
                table.insert(addonMemList, entry)
            end
        else
            totalMem = collectgarbage("count")
        end

        GameTooltip:AddDoubleLine("Memory:", string.format("%.2f MB", totalMem / 1024), 1, 1, 1, 1, 1, 1)

        if UIThingsDB.widgets.showAddonMemory then
            GameTooltip:AddLine(" ")

            table.sort(addonMemList, function(a, b) return a.mem > b.mem end)

            for i = 1, math.min(#addonMemList, 30) do
                local entry = addonMemList[i]
                if entry.mem > 0 then
                    local memMB = entry.mem / 1024
                    if memMB > 0.01 then
                        local r, g, b = 1, 1, 1
                        if memMB > 50 then
                            r, g, b = 1, 0, 0
                        elseif memMB > 10 then
                            r, g, b = 1, 1, 0
                        end
                        GameTooltip:AddDoubleLine(entry.name, string.format("%.2f MB", memMB), 1, 1, 1, r, g, b)
                    end
                end
            end
        end
        GameTooltip:Show()
    end)
    fpsFrame:SetScript("OnLeave", GameTooltip_Hide)

    fpsFrame.UpdateContent = function(self)
        local _, _, latencyHome, _ = GetNetStats()
        local fps = GetFramerate()
        self.text:SetFormattedText("%d ms / %.0f fps", latencyHome, fps)
    end
end)
