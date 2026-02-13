local addonName, addonTable = ...

addonTable.ConfigSetup = addonTable.ConfigSetup or {}

local Helpers = addonTable.ConfigHelpers

function addonTable.ConfigSetup.AddonVersions(panel, tab, configWindow)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Addon Versions")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    description:SetPoint("TOPLEFT", 20, -50)
    description:SetWidth(620)
    description:SetJustifyH("LEFT")
    description:SetText(
        "Shows which party/raid members have LunaUITweaks installed, their version, keystone, and level. Data is exchanged automatically when joining a group.")

    -- Hide from the world checkbox
    local hideFromWorldCheckbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    hideFromWorldCheckbox:SetPoint("TOPLEFT", 20, -90)
    hideFromWorldCheckbox.Text:SetText("Hide from the world")
    hideFromWorldCheckbox.Text:SetFontObject("GameFontHighlight")
    hideFromWorldCheckbox:SetChecked(UIThingsDB.addonComm.hideFromWorld)
    hideFromWorldCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.addonComm.hideFromWorld = self:GetChecked()
        -- Notify user
        if UIThingsDB.addonComm.hideFromWorld then
            print("|cFF00FF00[LunaUITweaks]|r Addon communication disabled - you are hidden from other addon users")
        else
            print("|cFF00FF00[LunaUITweaks]|r Addon communication enabled")
        end
    end)

    local hideTooltip = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hideTooltip:SetPoint("TOPLEFT", hideFromWorldCheckbox, "BOTTOMLEFT", 5, -2)
    hideTooltip:SetWidth(600)
    hideTooltip:SetJustifyH("LEFT")
    hideTooltip:SetTextColor(0.7, 0.7, 0.7)
    hideTooltip:SetText(
        "When enabled, this addon will not communicate with other players' addons (Kick tracker, Addon Versions)")

    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    refreshBtn:SetSize(120, 24)
    refreshBtn:SetPoint("TOPLEFT", 20, -145)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        if addonTable.AddonVersions then
            addonTable.AddonVersions.RefreshVersions()
        end
    end)

    -- Column headers
    local nameHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameHeader:SetPoint("TOPLEFT", 20, -185)
    nameHeader:SetText("Player")

    local versionHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    versionHeader:SetPoint("TOPLEFT", 150, -185)
    versionHeader:SetText("Version")

    local keystoneHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    keystoneHeader:SetPoint("TOPLEFT", 280, -185)
    keystoneHeader:SetText("Keystone")

    local levelHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    levelHeader:SetPoint("TOPLEFT", 480, -185)
    levelHeader:SetText("Level")

    -- Separator line
    local separator = panel:CreateTexture(nil, "ARTWORK")
    separator:SetPoint("TOPLEFT", 20, -200)
    separator:SetSize(550, 1)
    separator:SetColorTexture(0.4, 0.4, 0.4, 1)

    -- Container for rows
    local rowFrames = {}
    local MAX_ROWS = 40

    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", nil, panel)
        row:SetSize(550, 20)
        row:SetPoint("TOPLEFT", 20, -205 - ((i - 1) * 22))

        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.nameText:SetPoint("LEFT", 0, 0)
        row.nameText:SetWidth(125)
        row.nameText:SetJustifyH("LEFT")

        row.versionText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.versionText:SetPoint("LEFT", 130, 0)
        row.versionText:SetWidth(125)
        row.versionText:SetJustifyH("LEFT")

        row.keystoneText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.keystoneText:SetPoint("LEFT", 260, 0)
        row.keystoneText:SetWidth(195)
        row.keystoneText:SetJustifyH("LEFT")

        row.levelText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.levelText:SetPoint("LEFT", 460, 0)
        row.levelText:SetWidth(60)
        row.levelText:SetJustifyH("LEFT")

        row:Hide()
        rowFrames[i] = row
    end

    -- No data message
    local noDataText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noDataText:SetPoint("TOPLEFT", 20, -215)
    noDataText:SetText("Not in a group, or no responses received yet.")
    noDataText:SetTextColor(0.5, 0.5, 0.5)

    local function UpdateList()
        local playerData = {}
        if addonTable.AddonVersions then
            playerData = addonTable.AddonVersions.GetPlayerData()
        end

        -- Sort names: player first, then alphabetical
        local names = {}
        local playerName = UnitName("player")
        for name in pairs(playerData) do
            if name ~= playerName then
                table.insert(names, name)
            end
        end
        table.sort(names)
        if playerData[playerName] then
            table.insert(names, 1, playerName)
        end

        local count = #names
        for i = 1, MAX_ROWS do
            if i <= count then
                local name = names[i]
                local data = playerData[name]
                local isPlayer = name == playerName
                local hasAddon = data and data.version ~= nil

                -- Name
                rowFrames[i].nameText:SetText(name)

                -- Version
                if hasAddon then
                    rowFrames[i].versionText:SetText(data.version)
                else
                    rowFrames[i].versionText:SetText("No Addon")
                end

                -- Keystone
                if hasAddon and data.keystoneName then
                    rowFrames[i].keystoneText:SetText(string.format("%s +%d", data.keystoneName, data.keystoneLevel))
                elseif hasAddon then
                    rowFrames[i].keystoneText:SetText("No Key")
                else
                    rowFrames[i].keystoneText:SetText("-")
                end

                -- Level
                if hasAddon and data.playerLevel and data.playerLevel > 0 then
                    rowFrames[i].levelText:SetText(tostring(data.playerLevel))
                else
                    rowFrames[i].levelText:SetText("-")
                end

                -- Colors
                if isPlayer then
                    rowFrames[i].nameText:SetTextColor(0, 1, 0.5)
                    rowFrames[i].versionText:SetTextColor(0, 1, 0.5)
                    rowFrames[i].keystoneText:SetTextColor(0, 1, 0.5)
                    rowFrames[i].levelText:SetTextColor(0, 1, 0.5)
                elseif hasAddon then
                    rowFrames[i].nameText:SetTextColor(1, 1, 1)
                    rowFrames[i].versionText:SetTextColor(1, 0.82, 0)
                    rowFrames[i].keystoneText:SetTextColor(1, 0.82, 0)
                    rowFrames[i].levelText:SetTextColor(1, 0.82, 0)
                else
                    rowFrames[i].nameText:SetTextColor(0.5, 0.5, 0.5)
                    rowFrames[i].versionText:SetTextColor(1, 0.3, 0.3)
                    rowFrames[i].keystoneText:SetTextColor(0.5, 0.5, 0.5)
                    rowFrames[i].levelText:SetTextColor(0.5, 0.5, 0.5)
                end

                rowFrames[i]:Show()
            else
                rowFrames[i]:Hide()
            end
        end

        if count > 0 then
            noDataText:Hide()
        else
            noDataText:Show()
        end
    end

    -- Register callback
    if addonTable.AddonVersions then
        addonTable.AddonVersions.onVersionsUpdated = UpdateList
    end

    panel:SetScript("OnShow", function()
        UpdateList()
    end)

    UpdateList()
end
