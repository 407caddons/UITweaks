local addonName, addonTable = ...
local Widgets = addonTable.Widgets

-- Teleport Data
local TELEPORT_DATA = {
    { category = "Classic", spells = {
        "Teleport: Stormwind", "Teleport: Orgrimmar", "Teleport: Ironforge",
        "Teleport: Undercity", "Teleport: Darnassus", "Teleport: Thunder Bluff",
        "Teleport: Exodar", "Teleport: Silvermoon",
        "Teleport: Theramore", "Teleport: Stonard",
    }},
    { category = "TBC", spells = { "Teleport: Shattrath" }},
    { category = "WotLK", spells = { "Teleport: Dalaran - Northrend", "Ancient Teleport: Dalaran" }},
    { category = "Cataclysm", spells = { "Teleport: Tol Barad" }},
    { category = "MoP", spells = { "Teleport: Vale of Eternal Blossoms" }},
    { category = "WoD", spells = { "Teleport: Stormshield", "Teleport: Warspear" }},
    { category = "Legion", spells = {
        "Teleport: Dalaran - Broken Isles",
        "Teleport: Hall of the Guardian",
    }},
    { category = "BfA", spells = { "Teleport: Boralus", "Teleport: Dazar'alor" }},
    { category = "Shadowlands", spells = { "Teleport: Oribos" }},
    { category = "Dragonflight", spells = { "Teleport: Valdrakken" }},
    { category = "TWW", spells = { "Teleport: Dornogal" }},
}

local PORTAL_DATA = {
    { category = "Classic", spells = {
        "Portal: Stormwind", "Portal: Orgrimmar", "Portal: Ironforge",
        "Portal: Undercity", "Portal: Darnassus", "Portal: Thunder Bluff",
        "Portal: Exodar", "Portal: Silvermoon",
        "Portal: Theramore", "Portal: Stonard",
    }},
    { category = "TBC", spells = { "Portal: Shattrath" }},
    { category = "WotLK", spells = { "Portal: Dalaran - Northrend" }},
    { category = "Cataclysm", spells = { "Portal: Tol Barad" }},
    { category = "MoP", spells = { "Portal: Vale of Eternal Blossoms" }},
    { category = "WoD", spells = { "Portal: Stormshield", "Portal: Warspear" }},
    { category = "Legion", spells = { "Portal: Dalaran - Broken Isles" }},
    { category = "BfA", spells = { "Portal: Boralus", "Portal: Dazar'alor" }},
    { category = "Shadowlands", spells = { "Portal: Oribos" }},
    { category = "Dragonflight", spells = { "Portal: Valdrakken" }},
    { category = "TWW", spells = { "Portal: Dornogal" }},
}

local CLASS_TELEPORTS = {
    { className = "DEATHKNIGHT", spells = { "Death Gate" }},
    { className = "DRUID", spells = { "Dreamwalk" }},
    { className = "MONK", spells = { "Zen Pilgrimage" }},
    { className = "SHAMAN", spells = { "Astral Recall" }},
    { className = "WARLOCK", spells = { "Demonic Gateway" }},
}

local function IsSpellKnownByName(spellName)
    local info = C_Spell.GetSpellInfo(spellName)
    if info and info.spellID then
        return IsPlayerSpell(info.spellID)
    end
    return false
end

-- Deduplication Sets
local hardcodedSpells = {}
for _, group in ipairs(TELEPORT_DATA) do
    for _, spellName in ipairs(group.spells) do hardcodedSpells[spellName] = true end
end
for _, group in ipairs(PORTAL_DATA) do
    for _, spellName in ipairs(group.spells) do hardcodedSpells[spellName] = true end
end
for _, classData in ipairs(CLASS_TELEPORTS) do
    for _, spellName in ipairs(classData.spells) do hardcodedSpells[spellName] = true end
end

-- Helper to get destination from tooltip
local function GetTeleportDestFromTooltip(spellName)
    local info = C_Spell.GetSpellInfo(spellName)
    if not info or not info.spellID then return nil end
    
    local tooltipData = C_TooltipInfo.GetSpellByID(info.spellID)
    if not tooltipData then return nil end
    
    for _, line in ipairs(tooltipData.lines) do
        if line.leftText then
            local dest = line.leftText:match("to (.+)%.?")
            if dest then
                dest = dest:gsub("%.$", "")
                if dest:find("^the entrance to ") then dest = dest:sub(17)
                elseif dest:find("^entrance to ") then dest = dest:sub(13)
                elseif dest:find("^the ") then dest = dest:sub(5)
                end
                return dest
            end
        end
    end
    return nil
end

-- Scan Spellbook
local function ScanSpellbookForTeleports()
    local groups = {} 
    local ungrouped = {}
    local seen = {}
    local numLines = C_SpellBook.GetNumSpellBookSkillLines()
    for skillLineIdx = 1, numLines do
        local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(skillLineIdx)
        if skillLineInfo then
            local offset = skillLineInfo.itemIndexOffset
            local numEntries = skillLineInfo.numSpellBookItems
            for i = offset + 1, offset + numEntries do
                local bookItemInfo = C_SpellBook.GetSpellBookItemInfo(i, Enum.SpellBookSpellBank.Player)
                if bookItemInfo then
                    if bookItemInfo.itemType == Enum.SpellBookItemType.Flyout and bookItemInfo.actionID then
                        local flyoutID = bookItemInfo.actionID
                        local flyoutName, flyoutDesc, numSlots, isKnownFlyout = GetFlyoutInfo(flyoutID)
                        if flyoutName and (flyoutName:find("Teleport") or flyoutName:find("Dungeon") or flyoutName:find("Path")) then
                            local groupSpells = {}
                            if numSlots and numSlots > 0 then
                                for slot = 1, numSlots do
                                    local spellID, overrideSpellID, isKnown, spellName = GetFlyoutSlotInfo(flyoutID, slot)
                                    if isKnown and spellName and not hardcodedSpells[spellName] and not seen[spellName] then
                                        seen[spellName] = true
                                        table.insert(groupSpells, spellName)
                                    end
                                end
                            end
                            if #groupSpells > 0 then
                                table.insert(groups, { name = flyoutName, spells = groupSpells })
                            end
                        end
                    elseif bookItemInfo.spellID then
                        local spellInfo = C_Spell.GetSpellInfo(bookItemInfo.spellID)
                        if spellInfo and spellInfo.name then
                            local name = spellInfo.name
                            if not hardcodedSpells[name] and not seen[name] then
                                if name:find("^Teleport:") or name:find("^Ancient Teleport:") or name:find("^Portal:") or name:find("^Path of ") or name:find("^Hero's Path:") then
                                    if IsPlayerSpell(bookItemInfo.spellID) then
                                        seen[name] = true
                                        table.insert(ungrouped, name)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return groups, ungrouped
end

-- Module Init
table.insert(Widgets.moduleInits, function()
    local teleportFrame = Widgets.CreateWidgetFrame("Teleports", "teleports")
    teleportFrame:RegisterForClicks("AnyUp")

    -- ==================== Main Panel ====================
    local teleportPanel = CreateFrame("Frame", "LunaUITweaksTeleportPanel", UIParent, "BackdropTemplate")
    teleportPanel:SetSize(220, 200)
    teleportPanel:SetPoint("BOTTOM", teleportFrame, "TOP", 0, 5)
    teleportPanel:SetFrameStrata("DIALOG")
    teleportPanel:SetFrameLevel(100)
    teleportPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    teleportPanel:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    teleportPanel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    teleportPanel:EnableMouse(true)
    teleportPanel:Hide()
    
    tinsert(UISpecialFrames, "LunaUITweaksTeleportPanel")

    -- Dismiss frame (click outside to close)
    local dismissFrame = CreateFrame("Button", nil, UIParent)
    dismissFrame:SetFrameStrata("DIALOG")
    dismissFrame:SetFrameLevel(90)
    dismissFrame:SetAllPoints(UIParent)
    dismissFrame:EnableMouse(true)
    dismissFrame:SetScript("OnClick", function()
        teleportPanel:Hide()
    end)
    dismissFrame:Hide()

    teleportPanel:SetScript("OnShow", function()
        dismissFrame:Show()
    end)
    teleportPanel:SetScript("OnHide", function()
        dismissFrame:Hide()
    end)

    local panelTitle = teleportPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panelTitle:SetPoint("TOP", 0, -8)
    panelTitle:SetText("Teleports")

    local closeBtn = CreateFrame("Button", nil, teleportPanel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetSize(20, 20)

    local contentFrame = CreateFrame("Frame", nil, teleportPanel)
    contentFrame:SetPoint("TOPLEFT", 8, -30)
    contentFrame:SetPoint("TOPRIGHT", -8, -30)

    -- ==================== Submenu Panel ====================
    local subPanel = CreateFrame("Frame", "LunaUITweaksTeleportSubPanel", UIParent, "BackdropTemplate")
    subPanel:SetSize(220, 200)
    subPanel:SetFrameStrata("DIALOG")
    subPanel:SetFrameLevel(110) -- Higher than main panel
    subPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    subPanel:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    subPanel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    subPanel:EnableMouse(true)
    subPanel:Hide()

    local subPanelTitle = subPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    subPanelTitle:SetPoint("TOP", 0, -8)

    local subCloseBtn = CreateFrame("Button", nil, subPanel, "UIPanelCloseButton")
    subCloseBtn:SetPoint("TOPRIGHT", -2, -2)
    subCloseBtn:SetSize(20, 20)

    local subContentFrame = CreateFrame("Frame", nil, subPanel)
    subContentFrame:SetPoint("TOPLEFT", 8, -30)
    subContentFrame:SetPoint("TOPRIGHT", -8, -30)

    -- Hide submenu when main panel hides
    teleportPanel:SetScript("OnHide", function()
        subPanel:Hide()
        dismissFrame:Hide()
    end)

    -- Button Pools
    local buttonPool = {}
    local function AcquireButton(parent)
        local btn = table.remove(buttonPool)
        if not btn then
            btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
            btn:SetSize(200, 20)
            btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            btn.label:SetPoint("LEFT", 6, 0)
            btn.arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            btn.arrow:SetPoint("RIGHT", -6, 0)
            btn:SetScript("OnEnter", function(self)
                self:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
                self:SetBackdropColor(0.3, 0.3, 0.6, 0.5)
            end)
            btn:SetScript("OnLeave", function(self)
                self:SetBackdrop(nil)
            end)
        end
        btn:SetParent(parent)
        btn:Show()
        return btn
    end

    local securePool = {}
    local function AcquireSecureButton(parent)
        local btn = table.remove(securePool)
        if not btn then
            btn = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate, BackdropTemplate")
            btn:SetSize(200, 20)
            btn:RegisterForClicks("AnyDown", "AnyUp")
            btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            btn.label:SetPoint("LEFT", 6, 0)
            btn:SetScript("OnEnter", function(self)
                self:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
                self:SetBackdropColor(0.3, 0.3, 0.6, 0.5)
            end)
            btn:SetScript("OnLeave", function(self)
                self:SetBackdrop(nil)
            end)
        end
        btn:SetParent(parent)
        btn:Show()
        return btn
    end

    local function ReleaseButton(btn, isSecure)
        btn:Hide()
        btn:SetParent(nil)
        btn:ClearAllPoints()
        if isSecure then
            btn:SetAttribute("type", nil)
            btn:SetAttribute("spell", nil)
            btn:SetScript("PostClick", nil)
            table.insert(securePool, btn)
        else
            btn:SetScript("OnClick", nil)
            btn.arrow:SetText("")
            table.insert(buttonPool, btn)
        end
    end

    local mainButtons = {}
    local subButtons = {}

    local function ClearMainPanel()
        for _, btn in ipairs(mainButtons) do ReleaseButton(btn, btn:IsProtected()) end
        wipe(mainButtons)
    end

    local function ClearSubPanel()
        for _, btn in ipairs(subButtons) do ReleaseButton(btn, btn:IsProtected()) end
        wipe(subButtons)
    end

    -- Show Submenu
    local function ShowSubMenu(categoryName, spells, anchorButton)
        if InCombatLockdown() then return end
        ClearSubPanel()

        subPanelTitle:SetText(categoryName)
        local yOffset = 0

        table.sort(spells)
        for _, spellName in ipairs(spells) do
            local displayName = spellName
            if spellName:find("Path of") or spellName:find("Hero's Path") or spellName:find("Ancient Teleport") then
                local tooltipDest = GetTeleportDestFromTooltip(spellName)
                if tooltipDest then
                    displayName = tooltipDest
                else
                    displayName = spellName:gsub("^Hero's Path: ", "")
                end
            else
                displayName = spellName:gsub("^Teleport: ", ""):gsub("^Portal: ", "")
            end
            
            local btn = AcquireSecureButton(subContentFrame)
            btn:SetSize(200, 20)
            btn:SetPoint("TOPLEFT", 0, yOffset)
            btn:SetAttribute("type", "spell")
            btn:SetAttribute("spell", spellName)
            btn.label:SetText(displayName)
            
            btn:SetScript("PostClick", function()
                subPanel:Hide()
                teleportPanel:Hide()
            end)

            table.insert(subButtons, btn)
            yOffset = yOffset - 21
        end

        local panelHeight = math.min(math.abs(yOffset) + 40, 500)
        subPanel:SetSize(220, panelHeight)
        subContentFrame:SetHeight(math.abs(yOffset) + 10)

        subPanel:ClearAllPoints()
        subPanel:SetPoint("TOPLEFT", teleportPanel, "TOPRIGHT", 2, 0)
        subPanel:Show()
    end

    local function AddMenuButton(text, yOffset, onClick)
        local btn = AcquireButton(contentFrame)
        btn:SetSize(200, 22)
        btn:SetPoint("TOPLEFT", 0, yOffset)
        btn.label:SetText(text)
        btn.arrow:SetText(">")
        btn:SetScript("OnClick", onClick)
        table.insert(mainButtons, btn)
        return btn
    end

    local function AddDirectSpellButton(spellName, displayName, yOffset)
        local btn = AcquireSecureButton(contentFrame)
        btn:SetSize(200, 22)
        btn:SetPoint("TOPLEFT", 0, yOffset)
        btn:SetAttribute("type", "spell")
        btn:SetAttribute("spell", spellName)
        btn.label:SetText(displayName)
        btn:SetScript("PostClick", function()
            subPanel:Hide()
            teleportPanel:Hide()
        end)
        table.insert(mainButtons, btn)
        return btn
    end

    -- Build Main Menu
    local function ShowMainMenu()
        if InCombatLockdown() then return end
        ClearMainPanel()
        ClearSubPanel()
        subPanel:Hide()

        local yOffset = 0
        local _, classFileName = UnitClass("player")
        local isMage = (classFileName == "MAGE")
        local hasAnything = false
        
        local dungeonGroups, ungrouped = ScanSpellbookForTeleports()
        
        -- Current Season
        local currentSeasonSpells = {}
        local seasonMaps = C_ChallengeMode.GetMapTable()
        if seasonMaps and #seasonMaps > 0 then
             local mapNames = {}
             for _, mapID in ipairs(seasonMaps) do
                 local name = C_ChallengeMode.GetMapUIInfo(mapID)
                 if name then
                     mapNames[name] = true
                     if name:find("^The ") then mapNames[name:sub(5)] = true else mapNames["The " .. name] = true end
                 end
             end
             
             local function IsCurrentSeason(spellName)
                 local dest = GetTeleportDestFromTooltip(spellName)
                 if not dest then
                     dest = spellName:gsub("^Teleport: ", ""):gsub("^Portal: ", ""):gsub("^Hero's Path: ", ""):gsub("^Ancient Teleport: ", "")
                 end
                 for mapName in pairs(mapNames) do
                     if dest == mapName or dest:find(mapName, 1, true) or mapName:find(dest, 1, true) then return true end
                 end
                 return false
             end
             
             local seenSeason = {}
             for _, group in ipairs(dungeonGroups) do
                 for _, spell in ipairs(group.spells) do
                     if not seenSeason[spell] and IsCurrentSeason(spell) then
                         seenSeason[spell] = true
                         table.insert(currentSeasonSpells, spell)
                     end
                 end
             end
             for _, spell in ipairs(ungrouped) do
                 if not seenSeason[spell] and IsCurrentSeason(spell) then
                     seenSeason[spell] = true
                     table.insert(currentSeasonSpells, spell)
                 end
             end
        end
        
        if #currentSeasonSpells > 0 then
            hasAnything = true
            AddMenuButton("Current Season (" .. #currentSeasonSpells .. ")", yOffset, function(self)
                if not InCombatLockdown() then ShowSubMenu("Current Season", currentSeasonSpells, self) end
            end)
            yOffset = yOffset - 23
        end

        -- Mage Teleports
        if isMage then
            local allTeleports = {}
            for _, group in ipairs(TELEPORT_DATA) do
                for _, spellName in ipairs(group.spells) do
                    if IsSpellKnownByName(spellName) then table.insert(allTeleports, spellName) end
                end
            end
            if #allTeleports > 0 then
                hasAnything = true
                AddMenuButton("Teleports (" .. #allTeleports .. ")", yOffset, function(self)
                    if not InCombatLockdown() then ShowSubMenu("Teleports", allTeleports, self) end
                end)
                yOffset = yOffset - 23
            end

            local allPortals = {}
            for _, group in ipairs(PORTAL_DATA) do
                for _, spellName in ipairs(group.spells) do
                    if IsSpellKnownByName(spellName) then table.insert(allPortals, spellName) end
                end
            end
            if #allPortals > 0 then
                hasAnything = true
                AddMenuButton("Portals (" .. #allPortals .. ")", yOffset, function(self)
                    if not InCombatLockdown() then ShowSubMenu("Portals", allPortals, self) end
                end)
                yOffset = yOffset - 23
            end
        end

        -- Class Teleports
        for _, classData in ipairs(CLASS_TELEPORTS) do
            for _, spellName in ipairs(classData.spells) do
                if IsSpellKnownByName(spellName) then
                    hasAnything = true
                    AddDirectSpellButton(spellName, spellName, yOffset)
                    yOffset = yOffset - 23
                end
            end
        end

        -- Dungeon Teleports
        for _, group in ipairs(dungeonGroups) do
            hasAnything = true
            local spells = group.spells
            local catName = group.name:gsub("^Hero's Path: ", "")
            AddMenuButton(catName .. " (" .. #spells .. ")", yOffset, function(self)
                if not InCombatLockdown() then ShowSubMenu(catName, spells, self) end
            end)
            yOffset = yOffset - 23
        end

        -- Ungrouped
        for _, spellName in ipairs(ungrouped) do
            hasAnything = true
            local displayName = spellName:gsub("^Teleport: ", ""):gsub("^Portal: ", ""):gsub("^Hero's Path: ", "")
            AddDirectSpellButton(spellName, displayName, yOffset)
            yOffset = yOffset - 23
        end

        if not hasAnything then
            local noSpells = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            noSpells:SetPoint("TOPLEFT", 6, yOffset)
            noSpells:SetText("No teleports available")
            table.insert(mainButtons, noSpells)
            yOffset = yOffset - 20
        end

        local panelHeight = math.min(math.abs(yOffset) + 42, 500)
        teleportPanel:SetSize(220, panelHeight)
        contentFrame:SetHeight(math.abs(yOffset) + 10)
    end

    teleportFrame:SetScript("OnClick", function(self, button)
        if InCombatLockdown() then
            print("|cffff0000Cannot open teleports in combat.|r")
            return
        end
        if teleportPanel:IsShown() then
            teleportPanel:Hide()
        else
            ShowMainMenu()
            teleportPanel:ClearAllPoints()
            teleportPanel:SetPoint("BOTTOM", self, "TOP", 0, 5)
            teleportPanel:Show()
        end
    end)
    
    teleportFrame.UpdateContent = function(self)
         self.text:SetText("Teleports")
    end
end)
