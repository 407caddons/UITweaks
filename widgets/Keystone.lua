local addonName, addonTable = ...
local Widgets = addonTable.Widgets

-- Keystone Item ID
local KEYSTONE_ITEM_ID = 158923 -- Mythic Keystone

table.insert(Widgets.moduleInits, function()
    local keystoneFrame = Widgets.CreateWidgetFrame("Keystone", "keystone")

    -- Helper function to get keystone info from item link
    local function GetKeystoneInfo(itemLink)
        if not itemLink then return nil end

        local mapID, level = itemLink:match("keystone:%d+:(%d+):(%d+)")
        if mapID and level then
            mapID = tonumber(mapID)
            level = tonumber(level)

            local name = C_ChallengeMode.GetMapUIInfo(mapID)
            if name then
                return name, level, mapID
            end
        end
        return nil
    end

    -- Get player's keystone
    local function GetPlayerKeystone()
        for bag = 0, NUM_BAG_SLOTS do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and (itemInfo.itemID == KEYSTONE_ITEM_ID or
                        (itemInfo.hyperlink and itemInfo.hyperlink:match("keystone:"))) then
                    local itemLink = itemInfo.hyperlink
                    if itemLink then
                        local name, level, mapID = GetKeystoneInfo(itemLink)
                        if name and level then
                            return name, level, mapID
                        end
                    end

                    if itemLink then
                        C_Item.RequestLoadItemDataByID(KEYSTONE_ITEM_ID)

                        local tooltipData = C_TooltipInfo.GetBagItem(bag, slot)
                        if tooltipData and tooltipData.lines then
                            for _, line in ipairs(tooltipData.lines) do
                                if line.leftText then
                                    local dungeonLevel = line.leftText:match("Level (%d+)")
                                    if dungeonLevel then
                                        level = tonumber(dungeonLevel)
                                    end

                                    local dungeonName = line.leftText:match("Keystone: (.+)")
                                    if dungeonName then
                                        return dungeonName, level or 0
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return nil, nil
    end

    keystoneFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.keystone.enabled then return end

        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Keystone Tracker", 1, 1, 1)

        local keyName, keyLevel, keyMapID = GetPlayerKeystone()
        if keyName and keyLevel then
            local keyLine = string.format("%s +%d", keyName, keyLevel)
            if keyMapID then
                local gain = Widgets.EstimateRatingGain(keyMapID, keyLevel)
                if gain > 0 then
                    GameTooltip:AddDoubleLine(keyLine, string.format("est. +%d rating", gain), 0, 1, 0, 0, 1, 0)
                else
                    GameTooltip:AddDoubleLine(keyLine, "no upgrade", 0, 1, 0, 0.5, 0.5, 0.5)
                end
            else
                GameTooltip:AddLine(keyLine, 0, 1, 0)
            end
        else
            GameTooltip:AddLine("No keystone found", 0.7, 0.7, 0.7)
        end

        -- Show party keystones from AddonVersions data
        if IsInGroup() and addonTable.AddonVersions then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Party Keystones (est. timed)", 1, 0.82, 0)

            local playerData = addonTable.AddonVersions.GetPlayerData()
            local playerName = UnitName("player")

            -- Sort names: player first, then alphabetical
            local names = {}
            for name in pairs(playerData) do
                if name ~= playerName then
                    table.insert(names, name)
                end
            end
            table.sort(names)

            for _, name in ipairs(names) do
                local data = playerData[name]
                if data and data.version then
                    -- Has the addon
                    if data.keystoneName then
                        local rightText = string.format("%s +%d", data.keystoneName, data.keystoneLevel)
                        if data.keystoneMapID then
                            local gain = Widgets.EstimateRatingGain(data.keystoneMapID, data.keystoneLevel)
                            if gain > 0 then
                                rightText = rightText .. string.format(" |cFF00FF00+%d|r", gain)
                            end
                        end
                        GameTooltip:AddDoubleLine(
                            name,
                            rightText,
                            1, 1, 1,
                            0, 1, 0.5)
                    else
                        GameTooltip:AddDoubleLine(name, "No Key", 1, 1, 1, 0.5, 0.5, 0.5)
                    end
                else
                    -- No addon
                    GameTooltip:AddDoubleLine(name, "No Addon", 0.5, 0.5, 0.5, 1, 0.3, 0.3)
                end
            end
        end

        GameTooltip:Show()
    end)

    keystoneFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    keystoneFrame.UpdateContent = function(self)
        local keyName, keyLevel = GetPlayerKeystone()

        if keyName and keyLevel then
            local shortName = keyName
            if #keyName > 20 then
                shortName = keyName:sub(1, 17) .. "..."
            end
            self.text:SetText(string.format("Key: %s +%d", shortName, keyLevel))
        else
            self.text:SetText("Key: None")
        end
    end

    -- Event handler for bag updates
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

    keystoneFrame.eventFrame = eventFrame
    keystoneFrame.ApplyEvents = function(enabled)
        if enabled then
            eventFrame:RegisterEvent("BAG_UPDATE")
            eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
            eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
            eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        else
            eventFrame:UnregisterAllEvents()
        end
    end

    local updatePending = false
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if not UIThingsDB.widgets.keystone.enabled then return end

        if event == "BAG_UPDATE" then
            keystoneFrame:UpdateContent()

            if not updatePending then
                updatePending = true
                C_Timer.After(0.5, function()
                    updatePending = false
                    if UIThingsDB.widgets.keystone.enabled then
                        keystoneFrame:UpdateContent()
                    end
                end)
            end
        elseif event == "GET_ITEM_INFO_RECEIVED" then
            local itemID = ...
            if itemID == KEYSTONE_ITEM_ID then
                keystoneFrame:UpdateContent()
            end
        else
            keystoneFrame:UpdateContent()
        end
    end)
end)
