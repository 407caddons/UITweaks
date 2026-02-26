local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

-- Keystone Item ID
local KEYSTONE_ITEM_ID = 158923 -- Mythic Keystone

table.insert(Widgets.moduleInits, function()
    local keystoneFrame = Widgets.CreateWidgetFrame("Keystone", "keystone")

    -- Dungeon teleport detection
    local cachedTeleportSpells = nil -- mapName -> spellName

    local function BuildTeleportMap()
        cachedTeleportSpells = {}
        if InCombatLockdown() then return end
        local numLines = C_SpellBook.GetNumSpellBookSkillLines()
        for skillLineIdx = 1, numLines do
            local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(skillLineIdx)
            if skillLineInfo then
                local offset = skillLineInfo.itemIndexOffset
                local numEntries = skillLineInfo.numSpellBookItems
                for i = offset + 1, offset + numEntries do
                    local bookItemInfo = C_SpellBook.GetSpellBookItemInfo(i, Enum.SpellBookSpellBank.Player)
                    if bookItemInfo and bookItemInfo.itemType == Enum.SpellBookItemType.Flyout and bookItemInfo.actionID then
                        local flyoutID = bookItemInfo.actionID
                        local flyoutName, _, numSlots = GetFlyoutInfo(flyoutID)
                        if flyoutName and numSlots and numSlots > 0 then
                            for slot = 1, numSlots do
                                local spellID, _, isKnown, spellName = GetFlyoutSlotInfo(flyoutID, slot)
                                if isKnown and spellName then
                                    -- Try to match spell destination to dungeon names
                                    local tooltipData = C_TooltipInfo.GetSpellByID(spellID)
                                    if tooltipData then
                                        for _, line in ipairs(tooltipData.lines) do
                                            local ok, text = pcall(function() return line.leftText end)
                                            if ok and text and not issecretvalue(text) then
                                                local dest = text:match("to (.+)%.?")
                                                if dest then
                                                    dest = dest:gsub("%.$", "")
                                                    dest = dest:gsub("^the entrance to ", "")
                                                    dest = dest:gsub("^entrance to ", "")
                                                    dest = dest:gsub("^the ", "")
                                                    cachedTeleportSpells[dest] = spellName
                                                    -- Also store without "The " prefix/with it
                                                    if dest:find("^The ") then
                                                        cachedTeleportSpells[dest:sub(5)] = spellName
                                                    else
                                                        cachedTeleportSpells["The " .. dest] = spellName
                                                    end
                                                end
                                            end
                                        end
                                    end
                                    -- Also key by spell name parts
                                    local cleanName = spellName:gsub("^Hero's Path: ", ""):gsub("^Teleport: ", ""):gsub(
                                        "^Path of ", "")
                                    cachedTeleportSpells[cleanName] = spellName
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Generate name variants for matching (handles mega dungeon wing names, prefixes, etc.)
    local function GetDungeonNameVariants(name)
        local variants = { name }
        -- Strip "The " prefix
        if name:find("^The ") then
            table.insert(variants, name:sub(5))
        end
        -- Strip "Operation: " prefix
        if name:find("^Operation: ") then
            table.insert(variants, name:sub(12))
        end
        -- Strip mega dungeon wing suffix
        -- Handles both " - Wing" (e.g. "Operation: Mechagon - Workshop")
        -- and ": Wing" (e.g. "Tazavesh: So'leah's Gambit")
        local base = name:match("^(.+)%s+%-%s+.+$") or name:match("^(.-):%s+.+$")
        if base and base ~= name then
            table.insert(variants, base)
            -- Also strip "Operation: " from the base
            if base:find("^Operation: ") then
                table.insert(variants, base:sub(12))
            end
        end
        return variants
    end

    local function FindTeleportForDungeon(dungeonName)
        if not dungeonName then return nil end
        if not cachedTeleportSpells then BuildTeleportMap() end

        local variants = GetDungeonNameVariants(dungeonName)

        -- Direct match with all variants
        for _, variant in ipairs(variants) do
            if cachedTeleportSpells[variant] then return cachedTeleportSpells[variant] end
        end

        -- Substring match with all variants
        for dest, spell in pairs(cachedTeleportSpells) do
            for _, variant in ipairs(variants) do
                if variant:find(dest, 1, true) or dest:find(variant, 1, true) then
                    return spell
                end
            end
        end
        return nil
    end

    -- Secure overlay button for click-to-teleport
    local secureBtn = CreateFrame("Button", "LunaUITweaks_KeystoneSecure", keystoneFrame, "SecureActionButtonTemplate")
    secureBtn:SetAllPoints(keystoneFrame)
    secureBtn:RegisterForClicks("AnyDown", "AnyUp")
    secureBtn:RegisterForDrag("LeftButton")
    secureBtn:SetAttribute("type", "spell")
    secureBtn:SetAttribute("spell", "")
    local currentTeleportSpell = nil

    -- Pass through drag to parent
    secureBtn:SetScript("OnDragStart", function()
        if not UIThingsDB.widgets.locked then
            keystoneFrame:StartMoving()
            keystoneFrame.isMoving = true
        end
    end)
    secureBtn:SetScript("OnDragStop", function()
        keystoneFrame:StopMovingOrSizing()
        keystoneFrame.isMoving = false
        local cx, cy = keystoneFrame:GetCenter()
        local pcx, pcy = UIParent:GetCenter()
        if cx and pcx then
            UIThingsDB.widgets.keystone.pos = { x = cx - pcx, y = cy - pcy }
        end
    end)

    -- Pass through tooltip
    secureBtn:SetScript("OnEnter", function(self)
        local onEnter = keystoneFrame:GetScript("OnEnter")
        if onEnter then onEnter(keystoneFrame) end
    end)
    secureBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local function UpdateTeleportButton(dungeonName)
        if InCombatLockdown() then return end
        local spell = FindTeleportForDungeon(dungeonName)
        currentTeleportSpell = spell
        if spell then
            secureBtn:SetAttribute("spell", spell)
            secureBtn:Show()
        else
            secureBtn:SetAttribute("spell", "")
            secureBtn:Hide()
        end
    end

    -- Invalidate teleport cache when spells change or leaving combat
    local function OnTeleportCacheInvalidate()
        cachedTeleportSpells = nil
    end
    EventBus.Register("SPELLS_CHANGED", OnTeleportCacheInvalidate, "W:Keystone")
    EventBus.Register("PLAYER_REGEN_ENABLED", OnTeleportCacheInvalidate, "W:Keystone")

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

                -- Best run comparison
                local intimeInfo, overtimeInfo = C_MythicPlus.GetSeasonBestForMap(keyMapID)
                local bestInfo = intimeInfo or overtimeInfo
                if bestInfo and bestInfo.level then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Your Best Run", 1, 0.82, 0)
                    local timed = (intimeInfo and intimeInfo.level) and true or false
                    local bestLevel = bestInfo.level
                    local bestDuration = bestInfo.durationSec
                    local timedText = timed and "|cFF00FF00Timed|r" or "|cFFFF0000Overtime|r"
                    if bestDuration then
                        local mins = math.floor(bestDuration / 60)
                        local secs = bestDuration % 60
                        GameTooltip:AddDoubleLine(
                            string.format("+%d (%s)", bestLevel, timedText),
                            string.format("%d:%02d", mins, secs),
                            1, 1, 1, 1, 1, 1)
                    else
                        GameTooltip:AddLine(string.format("+%d (%s)", bestLevel, timedText), 1, 1, 1)
                    end

                    -- Show the level difference
                    local diff = keyLevel - bestLevel
                    if diff > 0 then
                        GameTooltip:AddLine(string.format("+%d above your best", diff), 1, 0.5, 0)
                    elseif diff < 0 then
                        GameTooltip:AddLine(string.format("%d below your best", diff), 0.5, 0.5, 0.5)
                    else
                        GameTooltip:AddLine("Same level as your best", 1, 1, 0)
                    end
                else
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("No previous run for this dungeon", 0.5, 0.5, 0.5)
                end
            else
                GameTooltip:AddLine(keyLine, 0, 1, 0)
            end

            -- Teleport info
            if currentTeleportSpell then
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine("Click to teleport:", currentTeleportSpell, 1, 0.82, 0, 0.4, 0.78, 1)
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

    local lastKeystoneName = nil

    keystoneFrame.UpdateContent = function(self)
        local keyName, keyLevel = GetPlayerKeystone()

        if keyName and keyLevel then
            local shortName = keyName
            if #keyName > 20 then
                shortName = keyName:sub(1, 17) .. "..."
            end
            self.text:SetText(string.format("Key: %s +%d", shortName, keyLevel))

            -- Update teleport button when keystone changes
            if keyName ~= lastKeystoneName then
                lastKeystoneName = keyName
                UpdateTeleportButton(keyName)
            end
        else
            self.text:SetText("Key: None")
            if lastKeystoneName then
                lastKeystoneName = nil
                UpdateTeleportButton(nil)
            end
        end
    end

    -- Event handlers for bag updates
    local updatePending = false

    local function OnBagUpdate()
        if not UIThingsDB.widgets.keystone.enabled then return end
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
    end

    local function OnGetItemInfoReceived(event, itemID)
        if not UIThingsDB.widgets.keystone.enabled then return end
        if itemID == KEYSTONE_ITEM_ID then
            keystoneFrame:UpdateContent()
        end
    end

    local function OnKeystoneWorldUpdate()
        if not UIThingsDB.widgets.keystone.enabled then return end
        keystoneFrame:UpdateContent()
    end

    keystoneFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("BAG_UPDATE", OnBagUpdate, "W:Keystone")
            EventBus.Register("BAG_UPDATE_DELAYED", OnKeystoneWorldUpdate, "W:Keystone")
            EventBus.Register("PLAYER_ENTERING_WORLD", OnKeystoneWorldUpdate, "W:Keystone")
            EventBus.Register("GET_ITEM_INFO_RECEIVED", OnGetItemInfoReceived, "W:Keystone")
        else
            EventBus.Unregister("BAG_UPDATE", OnBagUpdate)
            EventBus.Unregister("BAG_UPDATE_DELAYED", OnKeystoneWorldUpdate)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnKeystoneWorldUpdate)
            EventBus.Unregister("GET_ITEM_INFO_RECEIVED", OnGetItemInfoReceived)
        end
    end
end)
