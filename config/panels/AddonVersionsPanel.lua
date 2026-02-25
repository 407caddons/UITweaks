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
            -- Immediately announce presence and request data from the group
            addonTable.AddonVersions.BroadcastPresence()
            if UIThingsDB.kick and UIThingsDB.kick.enabled then
                addonTable.Kick.BroadcastSpells()
                -- Request spell lists from others so we get fresh data
                addonTable.Comm.Send("KICK", "REQ", "")
            end
        end
    end)

    local hideTooltip = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hideTooltip:SetPoint("TOPLEFT", hideFromWorldCheckbox, "BOTTOMLEFT", 5, -2)
    hideTooltip:SetWidth(600)
    hideTooltip:SetJustifyH("LEFT")
    hideTooltip:SetTextColor(0.7, 0.7, 0.7)
    hideTooltip:SetText(
        "When enabled, this addon will not communicate with other players' addons (Kick tracker, Addon Versions)")

    -- Debug mode checkbox
    local debugCheckbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    debugCheckbox:SetPoint("TOPLEFT", hideTooltip, "BOTTOMLEFT", -5, -8)
    debugCheckbox.Text:SetText("Debug mode")
    debugCheckbox.Text:SetFontObject("GameFontHighlight")
    debugCheckbox:SetChecked(UIThingsDB.addonComm.debugMode)
    debugCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.addonComm.debugMode = self:GetChecked()
        if UIThingsDB.addonComm.debugMode then
            addonTable.Core.currentLogLevel = addonTable.Core.LogLevel.DEBUG
            addonTable.Core.Log("Core", "Debug mode enabled", addonTable.Core.LogLevel.INFO)
        else
            addonTable.Core.currentLogLevel = addonTable.Core.LogLevel.INFO
            addonTable.Core.Log("Core", "Debug mode disabled", addonTable.Core.LogLevel.INFO)
        end
    end)

    local debugTooltip = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    debugTooltip:SetPoint("TOPLEFT", debugCheckbox, "BOTTOMLEFT", 5, -2)
    debugTooltip:SetWidth(600)
    debugTooltip:SetJustifyH("LEFT")
    debugTooltip:SetTextColor(0.7, 0.7, 0.7)
    debugTooltip:SetText("Shows detailed debug messages in chat for addon communication and module activity")

    -- ============================================================
    -- Settings Serialization (Import / Export)
    -- ============================================================

    local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    local function Base64Encode(data)
        local out = {}
        local len = #data
        for i = 1, len, 3 do
            local b1 = data:byte(i)
            local b2 = (i + 1 <= len) and data:byte(i + 1) or 0
            local b3 = (i + 2 <= len) and data:byte(i + 2) or 0
            local n = b1 * 65536 + b2 * 256 + b3
            out[#out + 1] = B64_CHARS:sub(math.floor(n / 262144) + 1, math.floor(n / 262144) + 1)
            out[#out + 1] = B64_CHARS:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
            out[#out + 1] = (i + 1 <= len) and B64_CHARS:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1) or
                "="
            out[#out + 1] = (i + 2 <= len) and B64_CHARS:sub(n % 64 + 1, n % 64 + 1) or "="
        end
        return table.concat(out)
    end

    local function Base64Decode(data)
        data = data:gsub("[^A-Za-z0-9+/=]", "")
        local lookup = {}
        for i = 1, 64 do lookup[B64_CHARS:sub(i, i)] = i - 1 end
        local out = {}
        for i = 1, #data, 4 do
            local c1 = lookup[data:sub(i, i)] or 0
            local c2 = lookup[data:sub(i + 1, i + 1)] or 0
            local c3 = lookup[data:sub(i + 2, i + 2)] or 0
            local c4 = lookup[data:sub(i + 3, i + 3)] or 0
            local n = c1 * 262144 + c2 * 4096 + c3 * 64 + c4
            out[#out + 1] = string.char(math.floor(n / 65536) % 256)
            if data:sub(i + 2, i + 2) ~= "=" then
                out[#out + 1] = string.char(math.floor(n / 256) % 256)
            end
            if data:sub(i + 3, i + 3) ~= "=" then
                out[#out + 1] = string.char(n % 256)
            end
        end
        return table.concat(out)
    end

    local function SerializeValue(val, depth)
        depth = depth or 0
        if depth > 20 then return "nil" end
        local t = type(val)
        if t == "string" then
            return string.format("%q", val)
        elseif t == "number" then
            return tostring(val)
        elseif t == "boolean" then
            return val and "true" or "false"
        elseif t == "table" then
            local parts = {}
            -- Check for array portion
            local isArray = true
            local maxN = 0
            for k in pairs(val) do
                if type(k) == "number" and k == math.floor(k) and k > 0 then
                    if k > maxN then maxN = k end
                else
                    isArray = false
                end
            end
            if isArray and maxN > 0 and maxN == #val then
                for i = 1, maxN do
                    parts[#parts + 1] = SerializeValue(val[i], depth + 1)
                end
            else
                -- Sort keys for deterministic output
                local keys = {}
                for k in pairs(val) do keys[#keys + 1] = k end
                table.sort(keys, function(a, b)
                    if type(a) ~= type(b) then return type(a) < type(b) end
                    return a < b
                end)
                for _, k in ipairs(keys) do
                    local keyStr
                    if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                        keyStr = k
                    else
                        keyStr = "[" .. SerializeValue(k, depth + 1) .. "]"
                    end
                    parts[#parts + 1] = keyStr .. "=" .. SerializeValue(val[k], depth + 1)
                end
            end
            return "{" .. table.concat(parts, ",") .. "}"
        else
            return "nil"
        end
    end

    local function DeserializeString(str)
        -- Safely deserialize a Lua table string
        if not str or str == "" then return nil, "Empty string" end
        if #str > 65536 then return nil, "Input too large" end
        local func, err = loadstring("return " .. str)
        if not func then return nil, "Parse error: " .. (err or "unknown") end
        -- Sandbox: no access to globals
        setfenv(func, {})
        local ok, result = pcall(func)
        if not ok then return nil, "Execution error: " .. tostring(result) end
        if type(result) ~= "table" then return nil, "Expected table, got " .. type(result) end
        return result
    end

    local function BuildExportString(includeSettings, includeTalentBuilds)
        local exportData = {}
        if includeSettings and UIThingsDB then
            exportData.settings = UIThingsDB
        end
        if includeTalentBuilds and LunaUITweaks_TalentReminders then
            exportData.talentBuilds = LunaUITweaks_TalentReminders
        end
        exportData.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "unknown"
        exportData.exportDate = date("%Y-%m-%d %H:%M:%S")

        local serialized = SerializeValue(exportData)
        return "LUIT1:" .. Base64Encode(serialized)
    end

    local function ParseImportString(importStr)
        if not importStr or importStr == "" then
            return nil, "Empty import string"
        end
        importStr = importStr:gsub("%s+", "")

        -- Check prefix
        if not importStr:match("^LUIT1:") then
            return nil, "Invalid format - not a LunaUITweaks export string"
        end

        local b64Data = importStr:sub(7)
        local decoded = Base64Decode(b64Data)
        if not decoded or decoded == "" then
            return nil, "Failed to decode data"
        end

        local data, err = DeserializeString(decoded)
        if not data then
            return nil, err
        end

        return data
    end

    local function ApplyImportData(data)
        local count = 0
        if data.settings and type(data.settings) == "table" then
            -- Deep copy imported settings into UIThingsDB
            local function DeepMerge(target, source)
                for k, v in pairs(source) do
                    if type(v) == "table" and type(target[k]) == "table" then
                        -- Check if it's a color table (has 'r' field)
                        if v.r ~= nil then
                            target[k] = v
                        else
                            DeepMerge(target[k], v)
                        end
                    else
                        target[k] = v
                    end
                end
            end
            DeepMerge(UIThingsDB, data.settings)
            count = count + 1
        end
        if data.talentBuilds and type(data.talentBuilds) == "table" then
            LunaUITweaks_TalentReminders = data.talentBuilds
            count = count + 1
        end
        return count
    end

    -- Export dialog
    local function ShowExportDialog()
        local f = CreateFrame("Frame", "LunaSettingsExportFrame", UIParent, "BackdropTemplate")
        f:SetSize(500, 380)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)

        local titleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        titleText:SetPoint("TOP", 0, -12)
        titleText:SetText("Export Settings")

        -- Checkboxes
        local settingsCheck = CreateFrame("CheckButton", nil, f, "InterfaceOptionsCheckButtonTemplate")
        settingsCheck:SetPoint("TOPLEFT", 15, -45)
        settingsCheck.Text:SetText("Include Settings (UIThingsDB)")
        settingsCheck.Text:SetFontObject("GameFontHighlight")
        settingsCheck:SetChecked(true)

        local talentCheck = CreateFrame("CheckButton", nil, f, "InterfaceOptionsCheckButtonTemplate")
        talentCheck:SetPoint("TOPLEFT", 15, -70)
        talentCheck.Text:SetText("Include Talent Builds")
        talentCheck.Text:SetFontObject("GameFontHighlight")
        talentCheck:SetChecked(false)

        -- Generate button
        local generateBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        generateBtn:SetSize(100, 22)
        generateBtn:SetPoint("TOPLEFT", 15, -100)
        generateBtn:SetText("Generate")

        -- Scroll + EditBox
        local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 10, -130)
        scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)

        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetWidth(450)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scrollFrame:SetScrollChild(editBox)

        generateBtn:SetScript("OnClick", function()
            local includeSettings = settingsCheck:GetChecked()
            local includeTalents = talentCheck:GetChecked()
            if not includeSettings and not includeTalents then
                editBox:SetText("Please select at least one option to export.")
                return
            end
            local exportStr = BuildExportString(includeSettings, includeTalents)
            editBox:SetText(exportStr)
            editBox:HighlightText()
            editBox:SetFocus()
        end)

        -- Close button
        local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        closeBtn:SetSize(80, 22)
        closeBtn:SetPoint("BOTTOMRIGHT", -10, 10)
        closeBtn:SetText("Close")
        closeBtn:SetScript("OnClick", function()
            f:Hide(); f:SetParent(nil)
        end)

        f:Show()
    end

    -- Import dialog
    local function ShowImportDialog()
        local f = CreateFrame("Frame", "LunaSettingsImportFrame", UIParent, "BackdropTemplate")
        f:SetSize(500, 320)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)

        local titleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        titleText:SetPoint("TOP", 0, -12)
        titleText:SetText("Import Settings")

        local helpText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        helpText:SetPoint("TOPLEFT", 15, -40)
        helpText:SetWidth(470)
        helpText:SetJustifyH("LEFT")
        helpText:SetTextColor(0.7, 0.7, 0.7)
        helpText:SetText("Paste an export string below and click Import. A /reload will be performed to apply changes.")

        -- Scroll + EditBox
        local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 10, -65)
        scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)

        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(true)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetWidth(450)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scrollFrame:SetScrollChild(editBox)

        -- Import button
        local importBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        importBtn:SetSize(80, 22)
        importBtn:SetPoint("BOTTOMRIGHT", -100, 10)
        importBtn:SetText("Import")
        importBtn:SetScript("OnClick", function()
            local importStr = editBox:GetText()
            local data, err = ParseImportString(importStr)
            if not data then
                editBox:SetText("Error: " .. (err or "Unknown error"))
                return
            end

            local what = {}
            if data.settings then table.insert(what, "settings") end
            if data.talentBuilds then table.insert(what, "talent builds") end
            local desc = table.concat(what, " and ")
            if data.version then desc = desc .. " (from v" .. data.version .. ")" end

            StaticPopup_Show("LUNA_IMPORT_CONFIRM", desc, nil, { data = data, frame = f })
        end)

        -- Cancel button
        local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        cancelBtn:SetSize(80, 22)
        cancelBtn:SetPoint("BOTTOMRIGHT", -10, 10)
        cancelBtn:SetText("Cancel")
        cancelBtn:SetScript("OnClick", function()
            f:Hide(); f:SetParent(nil)
        end)

        f:Show()
    end

    StaticPopupDialogs["LUNA_IMPORT_CONFIRM"] = {
        text = "Import %s?\n\nThis will overwrite your current settings and /reload the UI.",
        button1 = "Import & Reload",
        button2 = "Cancel",
        OnAccept = function(self, popupData)
            ApplyImportData(popupData.data)
            if popupData.frame then
                popupData.frame:Hide(); popupData.frame:SetParent(nil)
            end
            ReloadUI()
        end,
        OnCancel = function(self, popupData)
            -- Do nothing
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    refreshBtn:SetSize(120, 24)
    refreshBtn:SetPoint("TOPLEFT", debugTooltip, "BOTTOMLEFT", -5, -8)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        if addonTable.AddonVersions then
            addonTable.AddonVersions.RefreshVersions()
        end
    end)

    -- Import button
    local importSettingsBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    importSettingsBtn:SetSize(120, 24)
    importSettingsBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 5, 0)
    importSettingsBtn:SetText("Import")
    importSettingsBtn:SetScript("OnClick", ShowImportDialog)

    -- Export button
    local exportSettingsBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    exportSettingsBtn:SetSize(120, 24)
    exportSettingsBtn:SetPoint("LEFT", importSettingsBtn, "RIGHT", 5, 0)
    exportSettingsBtn:SetText("Export")
    exportSettingsBtn:SetScript("OnClick", ShowExportDialog)

    -- Reset All button
    local resetAllBtn = Helpers.CreateResetAllButton(panel)
    resetAllBtn:SetPoint("LEFT", exportSettingsBtn, "RIGHT", 5, 0)

    -- Games dropdown button
    local gamesBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    gamesBtn:SetSize(80, 24)
    gamesBtn:SetPoint("LEFT", resetAllBtn, "RIGHT", 10, 0)
    gamesBtn:SetText("Games")
    gamesBtn:SetScript("OnClick", function(self)
        MenuUtil.CreateContextMenu(self, function(ownerRegion, rootDescription)
            rootDescription:CreateButton("Blocks", function()
                if addonTable.Tetris and addonTable.Tetris.ShowGame then
                    addonTable.Tetris.ShowGame()
                end
            end)
            rootDescription:CreateButton("Snek", function()
                if addonTable.Snek and addonTable.Snek.ShowGame then
                    addonTable.Snek.ShowGame()
                end
            end)
            rootDescription:CreateButton("Bombs", function()
                if addonTable.Bombs and addonTable.Bombs.ShowGame then
                    addonTable.Bombs.ShowGame()
                end
            end)
            rootDescription:CreateButton("Gems", function()
                if addonTable.Gems and addonTable.Gems.ShowGame then
                    addonTable.Gems.ShowGame()
                end
            end)
            rootDescription:CreateButton("Cards", function()
                if addonTable.Cards and addonTable.Cards.ShowGame then
                    addonTable.Cards.ShowGame()
                end
            end)
            rootDescription:CreateButton("Tiles", function()
                if addonTable.Game2048 and addonTable.Game2048.ShowGame then
                    addonTable.Game2048.ShowGame()
                end
            end)
        end)
    end)

    -- Column headers
    local nameHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameHeader:SetPoint("TOPLEFT", refreshBtn, "BOTTOMLEFT", 0, -10)
    nameHeader:SetText("Player")

    local versionHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    versionHeader:SetPoint("TOPLEFT", nameHeader, "TOPLEFT", 130, 0)
    versionHeader:SetText("Version")

    local keystoneHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    keystoneHeader:SetPoint("TOPLEFT", nameHeader, "TOPLEFT", 260, 0)
    keystoneHeader:SetText("Keystone")

    local levelHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    levelHeader:SetPoint("TOPLEFT", nameHeader, "TOPLEFT", 460, 0)
    levelHeader:SetText("Level")

    -- Separator line
    local separator = panel:CreateTexture(nil, "ARTWORK")
    separator:SetPoint("TOPLEFT", nameHeader, "BOTTOMLEFT", 0, -3)
    separator:SetSize(550, 1)
    separator:SetColorTexture(0.4, 0.4, 0.4, 1)

    -- Container for rows
    local rowFrames = {}
    local MAX_ROWS = 40

    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", nil, panel)
        row:SetSize(550, 20)
        row:SetPoint("TOPLEFT", separator, "BOTTOMLEFT", 0, -3 - ((i - 1) * 22))

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
    noDataText:SetPoint("TOPLEFT", separator, "BOTTOMLEFT", 0, -8)
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
