local addonName, addonTable = ...
local Widgets = addonTable.Widgets

-- Keystone Item ID
local KEYSTONE_ITEM_ID = 158923 -- Mythic Keystone

table.insert(Widgets.moduleInits, function()
    local keystoneFrame = Widgets.CreateWidgetFrame("Keystone", "keystone")
    keystoneFrame:RegisterForClicks("AnyUp")

    -- Create tooltip panel for party keystones
    local tooltipPanel = CreateFrame("Frame", "LunaUITweaksKeystoneTooltip", UIParent, "BackdropTemplate")
    tooltipPanel:SetSize(250, 150)
    tooltipPanel:SetFrameStrata("DIALOG")
    tooltipPanel:SetFrameLevel(100)
    tooltipPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    tooltipPanel:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    tooltipPanel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    tooltipPanel:EnableMouse(true)
    tooltipPanel:Hide()

    tinsert(UISpecialFrames, "LunaUITweaksKeystoneTooltip")

    local panelTitle = tooltipPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panelTitle:SetPoint("TOP", 0, -8)
    panelTitle:SetText("Party Keystones")

    local closeBtn = CreateFrame("Button", nil, tooltipPanel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetSize(20, 20)

    local contentFrame = CreateFrame("Frame", nil, tooltipPanel)
    contentFrame:SetPoint("TOPLEFT", 8, -30)
    contentFrame:SetPoint("BOTTOMRIGHT", -8, 8)

    local contentText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    contentText:SetPoint("TOPLEFT")
    contentText:SetJustifyH("LEFT")
    contentText:SetJustifyV("TOP")
    contentText:SetWidth(234)

    -- Dismiss frame (click outside to close)
    local dismissFrame = CreateFrame("Button", nil, UIParent)
    dismissFrame:SetFrameStrata("DIALOG")
    dismissFrame:SetFrameLevel(90)
    dismissFrame:SetAllPoints(UIParent)
    dismissFrame:EnableMouse(true)
    dismissFrame:SetScript("OnClick", function()
        tooltipPanel:Hide()
    end)
    dismissFrame:Hide()

    tooltipPanel:SetScript("OnShow", function()
        dismissFrame:Show()
    end)
    tooltipPanel:SetScript("OnHide", function()
        dismissFrame:Hide()
    end)

    -- Helper function to get keystone info from item link
    local function GetKeystoneInfo(itemLink)
        if not itemLink then return nil end

        -- Parse keystone link for map ID and level
        -- Format: |cffa335ee|Hkeystone:158923:mapID:level:...|h[Keystone: DungeonName]|h|r
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
        -- Check bags for keystone
        for bag = 0, NUM_BAG_SLOTS do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                -- Check both by item ID and by item name (in case ID changed)
                if itemInfo and (itemInfo.itemID == KEYSTONE_ITEM_ID or
                        (itemInfo.hyperlink and itemInfo.hyperlink:match("keystone:"))) then
                    local itemLink = itemInfo.hyperlink
                    if itemLink then
                        local name, level, mapID = GetKeystoneInfo(itemLink)
                        if name and level then
                            return name, level
                        end
                    end

                    -- If hyperlink exists but parsing failed, request item data and try tooltip
                    if itemLink then
                        C_Item.RequestLoadItemDataByID(KEYSTONE_ITEM_ID)

                        -- Try using tooltip as fallback
                        local tooltipData = C_TooltipInfo.GetBagItem(bag, slot)
                        if tooltipData and tooltipData.lines then
                            -- Look for dungeon name and level in tooltip
                            for _, line in ipairs(tooltipData.lines) do
                                if line.leftText then
                                    local dungeonLevel = line.leftText:match("Level (%d+)")
                                    if dungeonLevel then
                                        level = tonumber(dungeonLevel)
                                    end

                                    -- Try to extract dungeon name from the keystone title
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

    -- Update party keystones display
    local function UpdatePartyKeystones()
        if not IsInGroup() then
            contentText:SetText("|cffaaaaaa(Not in group)|r")
            return
        end

        local lines = {}
        local hasAnyKey = false

        -- Add player's keystone
        local playerName = UnitName("player")
        local keyName, keyLevel = GetPlayerKeystone()
        if keyName and keyLevel then
            table.insert(lines, string.format("|cff00ff00%s:|r %s +%d", playerName, keyName, keyLevel))
            hasAnyKey = true
        else
            table.insert(lines, string.format("|cffaaaaaa%s:|r No Key", playerName))
        end

        -- Add party members (can't actually see their keystones without addon communication)
        local numMembers = IsInRaid() and GetNumGroupMembers() or GetNumSubgroupMembers()
        for i = 1, numMembers do
            local unit = IsInRaid() and "raid" .. i or "party" .. i
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                local name = UnitName(unit)
                if name then
                    -- Note: Without addon communication, we can't see other players' keystones
                    table.insert(lines, string.format("|cffaaaaaa%s:|r Unknown", name))
                end
            end
        end

        if not hasAnyKey then
            table.insert(lines, "")
            table.insert(lines, "|cffaaaaaa(Party keystones require|r")
            table.insert(lines, "|cffaaaaaaaaddon communication)|r")
        end

        contentText:SetText(table.concat(lines, "\n"))
    end

    keystoneFrame:SetScript("OnClick", function(self, button)
        if tooltipPanel:IsShown() then
            tooltipPanel:Hide()
        else
            UpdatePartyKeystones()
            tooltipPanel:ClearAllPoints()
            tooltipPanel:SetPoint("BOTTOM", self, "TOP", 0, 5)
            tooltipPanel:Show()
        end
    end)

    keystoneFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.keystone.enabled then return end

        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Keystone Tracker", 1, 1, 1)

        local keyName, keyLevel = GetPlayerKeystone()
        if keyName and keyLevel then
            GameTooltip:AddLine(string.format("%s +%d", keyName, keyLevel), 0, 1, 0)
        else
            GameTooltip:AddLine("No keystone found", 0.7, 0.7, 0.7)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to view party keystones", 0.5, 0.5, 1)
        GameTooltip:Show()
    end)

    keystoneFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    keystoneFrame.UpdateContent = function(self)
        local keyName, keyLevel = GetPlayerKeystone()

        if keyName and keyLevel then
            -- Abbreviate dungeon name if too long
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

    local updatePending = false
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if not UIThingsDB.widgets.keystone.enabled then return end

        if event == "BAG_UPDATE" then
            -- Immediate update attempt
            keystoneFrame:UpdateContent()

            -- Also schedule a delayed update in case item data wasn't loaded yet
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
