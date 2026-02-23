local addonName, addonTable = ...

addonTable.ConfigSetup = addonTable.ConfigSetup or {}

local Helpers = addonTable.ConfigHelpers

function addonTable.ConfigSetup.Reagents(panel, tab, configWindow)
    Helpers.CreateResetButton(panel, "reagents")
    -- Panel Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Reagent Tracker")

    -- Enable Checkbox
    local enableBtn = CreateFrame("CheckButton", "UIThingsReagentsEnableCheck", panel,
        "ChatConfigCheckButtonTemplate")
    enableBtn:SetPoint("TOPLEFT", 20, -50)
    _G[enableBtn:GetName() .. "Text"]:SetText("Enable Reagent Tracker")
    enableBtn:SetChecked(UIThingsDB.reagents.enabled)
    enableBtn:SetScript("OnClick", function(self)
        local enabled = not not self:GetChecked()
        UIThingsDB.reagents.enabled = enabled
        Helpers.UpdateModuleVisuals(panel, tab, enabled)
        if addonTable.Reagents and addonTable.Reagents.UpdateSettings then
            addonTable.Reagents.UpdateSettings()
        end
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.reagents.enabled)

    -- Description
    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", 40, -80)
    desc:SetWidth(560)
    desc:SetJustifyH("LEFT")
    desc:SetText(
        "Tracks profession reagents across all your characters. Hover over any reagent item to see counts from all alts.\n" ..
        "Bag counts update in real-time. Bank counts update when you visit a banker.")
    desc:SetTextColor(0.7, 0.7, 0.7)

    -- Character Data Section
    Helpers.CreateSectionHeader(panel, "Known Characters", -130)

    local sectionDesc = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sectionDesc:SetPoint("TOPLEFT", 20, -153)
    sectionDesc:SetWidth(560)
    sectionDesc:SetJustifyH("LEFT")
    sectionDesc:SetText("All characters seen by any Luna module. Deleting a character removes its data from Reagents and Warehousing.")
    sectionDesc:SetTextColor(0.5, 0.5, 0.5)

    -- Scroll frame for character list
    local scrollFrame = CreateFrame("ScrollFrame", "UIThingsReagentsCharScroll", panel,
        "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -185)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 20)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() or 560)
    scrollChild:SetHeight(1) -- Will be set dynamically
    scrollFrame:SetScrollChild(scrollChild)

    -- Store character row frames for reuse
    local charRows = {}

    local function FormatLastSeen(timestamp)
        if not timestamp or timestamp == 0 then return "Never" end
        local diff = time() - timestamp
        if diff < 60 then return "Just now" end
        if diff < 3600 then return string.format("%d min ago", math.floor(diff / 60)) end
        if diff < 86400 then return string.format("%d hours ago", math.floor(diff / 3600)) end
        return string.format("%d days ago", math.floor(diff / 86400))
    end

    local function GetClassRGB(classFile)
        if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
            local c = RAID_CLASS_COLORS[classFile]
            return c.r, c.g, c.b
        end
        return 1, 1, 1
    end

    local RefreshCharacterList
    RefreshCharacterList = function()
        -- Hide all existing rows
        for _, row in ipairs(charRows) do
            row:Hide()
        end

        local chars
        if addonTable.Reagents and addonTable.Reagents.GetTrackedCharacters then
            chars = addonTable.Reagents.GetTrackedCharacters()
        else
            chars = {}
        end

        local ROW_HEIGHT = 30
        local yOffset = 0

        if #chars == 0 then
            -- Show empty message
            if not scrollChild.emptyText then
                scrollChild.emptyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                scrollChild.emptyText:SetPoint("TOPLEFT", 0, 0)
                scrollChild.emptyText:SetText("No character data yet. Log in on each character to register them.")
                scrollChild.emptyText:SetTextColor(0.5, 0.5, 0.5)
            end
            scrollChild.emptyText:Show()
            scrollChild:SetHeight(30)
            return
        end

        if scrollChild.emptyText then
            scrollChild.emptyText:Hide()
        end

        for i, charInfo in ipairs(chars) do
            local row = charRows[i]
            if not row then
                row = CreateFrame("Frame", nil, scrollChild)
                row:SetHeight(ROW_HEIGHT)
                row:SetPoint("LEFT", 0, 0)
                row:SetPoint("RIGHT", 0, 0)

                -- Background (alternating)
                row.bg = row:CreateTexture(nil, "BACKGROUND")
                row.bg:SetAllPoints()

                -- Character name
                row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.nameText:SetPoint("LEFT", 5, 4)
                row.nameText:SetWidth(160)
                row.nameText:SetJustifyH("LEFT")

                -- Realm text (smaller, below name)
                row.realmText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.realmText:SetPoint("LEFT", 5, -8)
                row.realmText:SetWidth(160)
                row.realmText:SetJustifyH("LEFT")

                -- Last seen
                row.lastSeenText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.lastSeenText:SetPoint("LEFT", 175, 0)
                row.lastSeenText:SetWidth(110)
                row.lastSeenText:SetJustifyH("LEFT")

                -- Module badges (Reagents / Warehousing)
                row.reagentsBadge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.reagentsBadge:SetPoint("LEFT", 295, 0)
                row.reagentsBadge:SetWidth(75)
                row.reagentsBadge:SetJustifyH("LEFT")

                row.warehousingBadge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.warehousingBadge:SetPoint("LEFT", 375, 0)
                row.warehousingBadge:SetWidth(80)
                row.warehousingBadge:SetJustifyH("LEFT")

                -- Delete button
                row.deleteBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.deleteBtn:SetSize(60, 22)
                row.deleteBtn:SetPoint("RIGHT", -5, 0)
                row.deleteBtn:SetText("Delete")

                charRows[i] = row
            end

            row:SetPoint("TOPLEFT", 0, -yOffset)
            row:SetPoint("TOPRIGHT", 0, -yOffset)

            -- Alternating background
            if i % 2 == 0 then
                row.bg:SetColorTexture(0.15, 0.15, 0.15, 0.5)
            else
                row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.3)
            end

            -- Character name with class color
            local r, g, b = GetClassRGB(charInfo.class)
            local charName = charInfo.key:match("^(.+) %- (.+)$")
            local realm = charInfo.key:match("^.+ %- (.+)$")
            charName = charName or charInfo.key
            row.nameText:SetText(charName)
            row.nameText:SetTextColor(r, g, b)
            row.realmText:SetText(realm or "")
            row.realmText:SetTextColor(0.5, 0.5, 0.5)

            -- Last seen (most recent across all module timestamps)
            local mostRecentSeen = charInfo.lastSeen or 0
            if charInfo.modules then
                for _, ts in pairs(charInfo.modules) do
                    if ts > mostRecentSeen then mostRecentSeen = ts end
                end
            end
            row.lastSeenText:SetText(FormatLastSeen(mostRecentSeen))
            row.lastSeenText:SetTextColor(0.7, 0.7, 0.7)

            -- Reagents badge: show reagent item count if they have data
            local reagentData = LunaUITweaks_ReagentData and LunaUITweaks_ReagentData.characters
                and LunaUITweaks_ReagentData.characters[charInfo.key]
            if reagentData and reagentData.items then
                local count = 0
                for _ in pairs(reagentData.items) do count = count + 1 end
                row.reagentsBadge:SetText("|cff66cc66R:" .. count .. "|r")
            else
                row.reagentsBadge:SetText("|cff555555R:--|r")
            end

            -- Warehousing badge: show if character has warehousing data
            local whData = LunaUITweaks_WarehousingData and LunaUITweaks_WarehousingData.characters
                and LunaUITweaks_WarehousingData.characters[charInfo.key]
            if whData then
                row.warehousingBadge:SetText("|cff6699ccW:yes|r")
            else
                row.warehousingBadge:SetText("|cff555555W:--|r")
            end

            -- Delete button
            local capturedKey = charInfo.key
            row.deleteBtn:SetScript("OnClick", function()
                StaticPopupDialogs["LUNA_CHAR_REGISTRY_DELETE"] = {
                    text = "Delete all addon data for\n|cffffd700" .. capturedKey .. "|r?\n\nThis removes data from Reagents and Warehousing.",
                    button1 = "Delete",
                    button2 = "Cancel",
                    OnAccept = function()
                        if addonTable.Core and addonTable.Core.CharacterRegistry then
                            addonTable.Core.CharacterRegistry.Delete(capturedKey)
                        elseif addonTable.Reagents and addonTable.Reagents.DeleteCharacterData then
                            addonTable.Reagents.DeleteCharacterData(capturedKey)
                        end
                        RefreshCharacterList()
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                }
                StaticPopup_Show("LUNA_CHAR_REGISTRY_DELETE")
            end)

            row:Show()
            yOffset = yOffset + ROW_HEIGHT
        end

        -- Warband data row
        if LunaUITweaks_ReagentData and LunaUITweaks_ReagentData.warband
            and LunaUITweaks_ReagentData.warband.items then
            local warbandItemCount = 0
            for _ in pairs(LunaUITweaks_ReagentData.warband.items) do
                warbandItemCount = warbandItemCount + 1
            end
            if warbandItemCount > 0 then
                local idx = #chars + 1
                local row = charRows[idx]
                if not row then
                    row = CreateFrame("Frame", nil, scrollChild)
                    row:SetHeight(ROW_HEIGHT)
                    row:SetPoint("LEFT", 0, 0)
                    row:SetPoint("RIGHT", 0, 0)

                    row.bg = row:CreateTexture(nil, "BACKGROUND")
                    row.bg:SetAllPoints()

                    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    row.nameText:SetPoint("LEFT", 5, 4)
                    row.nameText:SetWidth(160)
                    row.nameText:SetJustifyH("LEFT")

                    row.realmText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    row.realmText:SetPoint("LEFT", 5, -8)
                    row.realmText:SetWidth(160)
                    row.realmText:SetJustifyH("LEFT")

                    row.lastSeenText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    row.lastSeenText:SetPoint("LEFT", 175, 0)
                    row.lastSeenText:SetWidth(110)
                    row.lastSeenText:SetJustifyH("LEFT")

                    row.realmText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    row.realmText:SetPoint("LEFT", 5, -8)
                    row.realmText:SetWidth(160)
                    row.realmText:SetJustifyH("LEFT")

                    row.reagentsBadge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    row.reagentsBadge:SetPoint("LEFT", 295, 0)
                    row.reagentsBadge:SetWidth(75)
                    row.reagentsBadge:SetJustifyH("LEFT")

                    row.warehousingBadge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    row.warehousingBadge:SetPoint("LEFT", 375, 0)
                    row.warehousingBadge:SetWidth(80)
                    row.warehousingBadge:SetJustifyH("LEFT")

                    charRows[idx] = row
                end

                row:SetPoint("TOPLEFT", 0, -yOffset)
                row:SetPoint("TOPRIGHT", 0, -yOffset)
                row.bg:SetColorTexture(0.1, 0.15, 0.2, 0.5)
                row.nameText:SetText("Warband Bank")
                row.nameText:SetTextColor(0.4, 0.78, 1)
                row.realmText:SetText("")

                local lastSeen = LunaUITweaks_ReagentData.warband.lastSeen or 0
                row.lastSeenText:SetText(FormatLastSeen(lastSeen))
                row.lastSeenText:SetTextColor(0.7, 0.7, 0.7)

                row.reagentsBadge:SetText("|cff6699ccR:" .. warbandItemCount .. "|r")

                -- Hide delete button for warband row
                if row.deleteBtn then row.deleteBtn:Hide() end
                if row.warehousingBadge then row.warehousingBadge:SetText("") end

                row:Show()
                yOffset = yOffset + ROW_HEIGHT
            end
        end

        scrollChild:SetHeight(math.max(yOffset, 1))
    end

    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    refreshBtn:SetSize(80, 22)
    refreshBtn:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -20, 18)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", RefreshCharacterList)

    -- Column headers
    local nameHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameHeader:SetPoint("TOPLEFT", 25, -173)
    nameHeader:SetText("Character")
    nameHeader:SetTextColor(1, 0.82, 0)

    local lastSeenHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lastSeenHeader:SetPoint("TOPLEFT", 200, -173)
    lastSeenHeader:SetText("Last Seen")
    lastSeenHeader:SetTextColor(1, 0.82, 0)

    local modulesHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    modulesHeader:SetPoint("TOPLEFT", 320, -173)
    modulesHeader:SetText("Modules")
    modulesHeader:SetTextColor(1, 0.82, 0)

    -- Initial refresh
    RefreshCharacterList()

    -- Store refresh function for external access
    addonTable.Config.RefreshReagentsList = RefreshCharacterList
end
