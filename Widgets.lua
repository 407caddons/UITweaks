local addonName, addonTable = ...

addonTable.Widgets = {}
local Widgets = addonTable.Widgets

local frames = {}
local updateInterval = 1.0
local timeSinceLastUpdate = 0

-- Helper to create a widget frame
local function CreateWidgetFrame(name, configKey)
    local f = CreateFrame("Button", "LunaUITweaks_Widget_" .. name, UIParent)
    f:SetSize(100, 20)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not UIThingsDB.widgets.locked then
            self:StartMoving()
            self.isMoving = true
        end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.isMoving = false
        
        -- Calculate relative directly
        local cx, cy = self:GetCenter()
        local pcx, pcy = UIParent:GetCenter()
        if not cx or not pcx then return end
        
        local x = cx - pcx
        local y = cy - pcy
        
        -- Re-anchor to CENTER
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", x, y)
        
        UIThingsDB.widgets[configKey].point = "CENTER"
        UIThingsDB.widgets[configKey].relPoint = "CENTER"
        UIThingsDB.widgets[configKey].x = x
        UIThingsDB.widgets[configKey].y = y
        self.coords:SetText(string.format("(%.0f, %.0f)", x, y))
    end)

    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.text:SetPoint("CENTER")
    
    -- Background for dragging visibility
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 1, 0, 0.3)
    f.bg:Hide()

    -- Coordinates text (hidden by default)
    f.coords = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.coords:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 2)
    f.coords:Hide()

    f:SetScript("OnUpdate", function(self)
        if self.isMoving then
            local cx, cy = self:GetCenter()
            local pcx, pcy = UIParent:GetCenter()
            if cx and pcx then
                local x = cx - pcx
                local y = cy - pcy
                self.coords:SetText(string.format("(%.0f, %.0f)", x, y))
            end
        end
    end)

    frames[configKey] = f
    return f
end

function Widgets.Initialize()
    -- Always start locked
    if UIThingsDB.widgets then
        UIThingsDB.widgets.locked = true
    end

    -- 1. Local Time
    local timeFrame = CreateWidgetFrame("Time", "time")
    timeFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        local calendarTime = C_DateAndTime.GetCurrentCalendarTime()
        local hour, minute = GetGameTime()
        GameTooltip:SetText("Time Info")
        GameTooltip:AddDoubleLine("Local Time:", date(" %I:%M %p"), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Server Time:", string.format("%02d:%02d", hour, minute), 1, 1, 1, 1, 1, 1)
        GameTooltip:Show()
    end)
    timeFrame:SetScript("OnLeave", GameTooltip_Hide)
    timeFrame:SetScript("OnClick", function() ToggleCalendar() end)

    -- 2. Home MS/FPS
    local fpsFrame = CreateWidgetFrame("FPS", "fps")
    
    local addonMemList = {}
    local addonMemPool = {}
    local function GetMemEntry()
         local t = table.remove(addonMemPool)
         if not t then t = {} end
         return t
    end

    fpsFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
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
            for i=1, C_AddOns.GetNumAddOns() do
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
            
            for i=1, math.min(#addonMemList, 30) do
                local entry = addonMemList[i]
                if entry.mem > 0 then
                    local memMB = entry.mem / 1024
                    if memMB > 0.01 then
                        local r, g, b = 1, 1, 1
                        if memMB > 50 then r, g, b = 1, 0, 0
                        elseif memMB > 10 then r, g, b = 1, 1, 0
                        end
                        GameTooltip:AddDoubleLine(entry.name, string.format("%.2f MB", memMB), 1, 1, 1, r, g, b)
                    end
                end
            end
        end
        GameTooltip:Show()
    end)
    fpsFrame:SetScript("OnLeave", GameTooltip_Hide)

    -- 3. Bag Slots
    local bagFrame = CreateWidgetFrame("Bags", "bags")
    bagFrame:SetScript("OnClick", function() ToggleAllBags() end)

    -- 4. Spec
    local specFrame = CreateWidgetFrame("Spec", "spec")
    specFrame:RegisterForClicks("AnyUp")
    -- No need for a separate frame for MenuUtil, it attaches to parent/owner
    
    specFrame:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            -- Change Spec
            MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
                rootDescription:CreateTitle("Switch Specialization")
                local currentSpecIndex = GetSpecialization()
                for i = 1, GetNumSpecializations() do
                    local id, name, _, icon = GetSpecializationInfo(i)
                    if id then
                        local btn = rootDescription:CreateButton(name, function() C_SpecializationInfo.SetSpecialization(i) end)
                        -- Add icon if possible (MenuUtil might not support SetIcon directly on button, but let's try or just text)
                        -- 10.2+ API: btn:AddInitializer(function(button, description, menu) ... end) to set texture?
                        -- For simplicity, let's just use text + checkmark
                        if currentSpecIndex == i then
                            btn:SetEnabled(false)
                        end
                    end
                end
                rootDescription:CreateButton("Cancel", function() end)
            end)

        elseif button == "RightButton" then
            -- Change Loot Spec
            MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
                rootDescription:CreateTitle("Loot Specialization")
                
                local currentLootSpec = GetLootSpecialization()
                
                -- Current Spec Option (0)
                local currentSpecIndex = GetSpecialization()
                local _, currentSpecName = GetSpecializationInfo(currentSpecIndex)
                local btn0 = rootDescription:CreateButton("Current Specialization (" .. (currentSpecName or "Unknown") .. ")", function() SetLootSpecialization(0) end)
                if currentLootSpec == 0 then
                    btn0:SetEnabled(false)
                end

                for i = 1, GetNumSpecializations() do
                    local id, name, _, icon = GetSpecializationInfo(i)
                    if id then
                        local btn = rootDescription:CreateButton(name, function() SetLootSpecialization(id) end)
                        if currentLootSpec == id then
                            btn:SetEnabled(false)
                        end
                    end
                end
                rootDescription:CreateButton("Cancel", function() end)
            end)
        end
    end)

    -- 5. Durability
    local durabilityFrame = CreateWidgetFrame("Durability", "durability")
    durabilityFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText("Durability")
        
        local slots = {
            "Head", "Shoulder", "Chest", "Waist", "Legs", "Feet", 
            "Wrist", "Hands", "MainHand", "SecondaryHand"
        }
        
        for _, slotName in ipairs(slots) do
            local slotId = GetInventorySlotInfo(slotName .. "Slot")
            local current, max = GetInventoryItemDurability(slotId)
            if current and max then
                local percent = (current / max) * 100
                local r, g, b = 0, 1, 0
                if percent < 50 then r, g, b = 1, 0, 0 
                elseif percent < 80 then r, g, b = 1, 1, 0 end
                
                local link = GetInventoryItemLink("player", slotId)
                if link then
                    GameTooltip:AddDoubleLine(link, string.format("%d%%", percent), 1, 1, 1, r, g, b)
                end
            end
        end
        GameTooltip:Show()
    end)
    durabilityFrame:SetScript("OnLeave", GameTooltip_Hide)

    -- 6. Combat
    local combatFrame = CreateWidgetFrame("Combat", "combat")
    combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    combatFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            self.text:SetText("|cffff0000In Combat|r")
        else
            self.text:SetText("|cff00ff00Out of Combat|r")
        end
    end)

    -- 7. Friends
    local friendsFrame = CreateWidgetFrame("Friends", "friends")
    friendsFrame:SetScript("OnClick", function() ToggleFriendsFrame() end)
    friendsFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText("Online Friends")
        
        -- WoW Friends
        local numFriends = C_FriendList.GetNumFriends()
        for i = 1, numFriends do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.connected then
                local classColor = C_ClassColor.GetClassColor(info.className)
                local nameText = info.name
                local rightText = ""
                if info.level then
                    rightText = "Lvl " .. info.level
                end
                
                if classColor then
                    GameTooltip:AddDoubleLine(nameText, rightText, classColor.r, classColor.g, classColor.b, 1, 1, 1)
                else
                    GameTooltip:AddDoubleLine(nameText, rightText, 1, 1, 1, 1, 1, 1)
                end
            end
        end

        -- Battle.Net Friends
        local numBNet = BNGetNumFriends()
        for i = 1, numBNet do
            local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
            if accountInfo and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.isOnline then
                local gameAccount = accountInfo.gameAccountInfo
                
                -- Filter if WoW Only is enabled
                local show = true
                if UIThingsDB.widgets.showWoWOnly and gameAccount.clientProgram ~= BNET_CLIENT_WOW then
                    show = false
                end

                if show then
                    local nameText = accountInfo.accountName
                    if gameAccount.characterName then
                        nameText = nameText .. " (" .. gameAccount.characterName .. ")"
                    end

                    local rightText = ""
                    if gameAccount.clientProgram == BNET_CLIENT_WOW and gameAccount.characterLevel then
                         rightText = "Lvl " .. gameAccount.characterLevel
                    elseif gameAccount.richPresence then
                         rightText = gameAccount.richPresence
                    end
                    
                    local r, g, b = 0.51, 0.77, 1 -- BNet Blue
                    if gameAccount.className then
                        local classColor = C_ClassColor.GetClassColor(gameAccount.className)
                        if classColor then
                            r, g, b = classColor.r, classColor.g, classColor.b
                        end
                    end

                    GameTooltip:AddDoubleLine(nameText, rightText, r, g, b, 1, 1, 1)
                end
            end
        end
        GameTooltip:Show()
    end)
    friendsFrame:SetScript("OnLeave", GameTooltip_Hide)

    -- 8. Guild
    local guildFrame = CreateWidgetFrame("Guild", "guild")
    guildFrame:SetScript("OnClick", function() ToggleGuildFrame() end)
    guildFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText("Online Guild Members")
        
        if IsInGuild() then
            local numMembers = GetNumGuildMembers()
            for i = 1, numMembers do
                local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName = GetGuildRosterInfo(i)
                if online then
                    local classColor = C_ClassColor.GetClassColor(classFileName)
                     if classColor then
                        GameTooltip:AddDoubleLine(name, "Lvl " .. level, classColor.r, classColor.g, classColor.b, 1, 1, 1)
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

    -- 9. Group Comp
    local groupFrame = CreateWidgetFrame("Group", "group")
    groupFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText("Group Composition")
        
        local members = GetNumGroupMembers()
        if members > 0 then
            for i = 1, members do
                local unit = IsInRaid() and "raid"..i or (i == members and "player" or "party"..i)
                local name, _, _, _, _, class, _, _, _, _, level = GetRaidRosterInfo(i) -- Raid only actually
                if not IsInRaid() then
                     -- Need to handle party logic separately if needed or just use consistent API
                     -- Just using GetUnitName/Class for simplicity across both
                end
                
                -- Let's just iterate units
                local name = GetUnitName(unit, true)
                local _, classFileName = UnitClass(unit)
                local level = UnitLevel(unit)
                
                if name then
                     local classColor = C_ClassColor.GetClassColor(classFileName)
                     local relationship = ""
                     if UnitIsFriend("player", unit) then
                        -- Check friend list / guild
                        -- This is expensive to do every frame, tooltip is fine
                        if C_FriendList.IsFriend(UnitGUID(unit)) then relationship = "(F)" end
                        if IsGuildMember(UnitGUID(unit)) then relationship = relationship .. "(G)" end
                     end
                     
                     -- Role Icon
                     local role = UnitGroupRolesAssigned(unit)
                     local roleIcon = ""
                     if role == "TANK" then
                         roleIcon = CreateAtlasMarkup("roleicon-tiny-tank") .. " "
                     elseif role == "HEALER" then
                         roleIcon = CreateAtlasMarkup("roleicon-tiny-healer") .. " "
                     elseif role == "DAMAGER" then
                         roleIcon = CreateAtlasMarkup("roleicon-tiny-dps") .. " "
                     end

                     if classColor then
                        GameTooltip:AddDoubleLine(roleIcon .. name .. relationship, "Lvl " .. level, classColor.r, classColor.g, classColor.b, 1, 1, 1)
                     else
                        GameTooltip:AddDoubleLine(roleIcon .. name .. relationship, "Lvl " .. level, 1, 1, 1, 1, 1, 1)
                     end
                end
            end
        else
             GameTooltip:AddLine("Not in a group")
        end
        GameTooltip:Show()
    end)
    groupFrame:SetScript("OnLeave", GameTooltip_Hide)

    -- 10. Teleports
    local teleportFrame = CreateWidgetFrame("Teleports", "teleports")
    teleportFrame:RegisterForClicks("AnyUp")

    -- Teleport spell data organized by expansion
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

    -- Build a set of all hardcoded spell names for dedup
    local hardcodedSpells = {}
    for _, group in ipairs(TELEPORT_DATA) do
        for _, spellName in ipairs(group.spells) do
            hardcodedSpells[spellName] = true
        end
    end
    for _, group in ipairs(PORTAL_DATA) do
        for _, spellName in ipairs(group.spells) do
            hardcodedSpells[spellName] = true
        end
    end
    for _, classData in ipairs(CLASS_TELEPORTS) do
        for _, spellName in ipairs(classData.spells) do
            hardcodedSpells[spellName] = true
        end
    end

    -- Scan the spellbook for teleport spells grouped by flyout name
    local function ScanSpellbookForTeleports()
        local groups = {} -- { {name="Dungeon Teleports: Legion", spells={"spell1", "spell2"}} }
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

    -- Hide submenu and dismiss frame when main panel hides
    teleportPanel:SetScript("OnHide", function()
        subPanel:Hide()
        dismissFrame:Hide()
    end)

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
        for _, btn in ipairs(mainButtons) do
            ReleaseButton(btn, btn:IsProtected())
        end
        wipe(mainButtons)
    end

    local function ClearSubPanel()
        for _, btn in ipairs(subButtons) do
            ReleaseButton(btn, btn:IsProtected())
        end
        wipe(subButtons)
    end

    -- Helper to get destination from tooltip (e.g. "Teleports the caster to X")
    local function GetTeleportDestFromTooltip(spellName)
        local info = C_Spell.GetSpellInfo(spellName)
        if not info or not info.spellID then return nil end
        
        local tooltipData = C_TooltipInfo.GetSpellByID(info.spellID)
        if not tooltipData then return nil end
        
        for _, line in ipairs(tooltipData.lines) do
            if line.leftText then
                -- Match "Teleports the caster to [Location]" or "Opens a portal to [Location]"
                local dest = line.leftText:match("to (.+)%.?")
                if dest then
                    -- Clean up trailing punctuation if any remains
                    dest = dest:gsub("%.$", "")
                    
                    -- Strip prefixes like "the entrance to ", "entrance to ", "the "
                    if dest:find("^the entrance to ") then
                        dest = dest:sub(17)
                    elseif dest:find("^entrance to ") then
                        dest = dest:sub(13)
                    elseif dest:find("^the ") then
                        dest = dest:sub(5)
                    end
                    return dest
                end
            end
        end
        return nil
    end

    -- Show a category's spells in the submenu panel
    local function ShowSubMenu(categoryName, spells, anchorButton)
        if InCombatLockdown() then return end
        ClearSubPanel()

        subPanelTitle:SetText(categoryName)
        local yOffset = 0

        table.sort(spells)
        for _, spellName in ipairs(spells) do
            local displayName = spellName
            -- For "Path of", "Hero's Path", or "Ancient Teleport", try to get the real destination from tooltip
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

        -- Size and position
        local panelHeight = math.min(math.abs(yOffset) + 40, 500)
        subPanel:SetSize(220, panelHeight)
        subContentFrame:SetHeight(math.abs(yOffset) + 10)

        subPanel:ClearAllPoints()
        subPanel:SetPoint("TOPLEFT", teleportPanel, "TOPRIGHT", 2, 0)
        subPanel:Show()
    end

    -- Add a category button to the main panel
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

    -- Add a direct spell button to the main panel (for class teleports)
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

    -- Build the main category panel
    local function ShowMainMenu()
        if InCombatLockdown() then return end
        ClearMainPanel()
        ClearSubPanel()
        subPanel:Hide()

        local yOffset = 0
        local _, classFileName = UnitClass("player")
        local isMage = (classFileName == "MAGE")
        local hasAnything = false
        
        -- Scan spellbook first so we can filter for Current Season
        local dungeonGroups, ungrouped = ScanSpellbookForTeleports()
        
        -- 1. Current Season
        local currentSeasonSpells = {}
        local seasonMaps = C_ChallengeMode.GetMapTable()
        if seasonMaps and #seasonMaps > 0 then
             local mapNames = {}
             for _, mapID in ipairs(seasonMaps) do
                 local name = C_ChallengeMode.GetMapUIInfo(mapID)
                 if name then
                     mapNames[name] = true
                     if name:find("^The ") then
                        mapNames[name:sub(5)] = true
                     else
                        mapNames["The " .. name] = true
                     end
                 end
             end
             
             local function IsCurrentSeason(spellName)
                 local dest = GetTeleportDestFromTooltip(spellName)
                 if not dest then
                     dest = spellName:gsub("^Teleport: ", ""):gsub("^Portal: ", ""):gsub("^Hero's Path: ", ""):gsub("^Ancient Teleport: ", "")
                 end
                 
                 for mapName in pairs(mapNames) do
                     if dest == mapName or dest:find(mapName, 1, true) or mapName:find(dest, 1, true) then
                         return true
                     end
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

        -- Mage teleports (all in one menu)
        if isMage then
            local allTeleports = {}
            for _, group in ipairs(TELEPORT_DATA) do
                for _, spellName in ipairs(group.spells) do
                    if IsSpellKnownByName(spellName) then
                        table.insert(allTeleports, spellName)
                    end
                end
            end
            if #allTeleports > 0 then
                hasAnything = true
                AddMenuButton("Teleports (" .. #allTeleports .. ")", yOffset, function(self)
                    if not InCombatLockdown() then ShowSubMenu("Teleports", allTeleports, self) end
                end)
                yOffset = yOffset - 23
            end

            -- Portals
            local allPortals = {}
            for _, group in ipairs(PORTAL_DATA) do
                for _, spellName in ipairs(group.spells) do
                    if IsSpellKnownByName(spellName) then
                        table.insert(allPortals, spellName)
                    end
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

        -- Class teleports (show directly as castable buttons)
        for _, classData in ipairs(CLASS_TELEPORTS) do
            for _, spellName in ipairs(classData.spells) do
                if IsSpellKnownByName(spellName) then
                    hasAnything = true
                    AddDirectSpellButton(spellName, spellName, yOffset)
                    yOffset = yOffset - 23
                end
            end
        end

        -- Dungeon teleports grouped by flyout

        for _, group in ipairs(dungeonGroups) do
            hasAnything = true
            local spells = group.spells
            local catName = group.name:gsub("^Hero's Path: ", "")
            AddMenuButton(catName .. " (" .. #spells .. ")", yOffset, function(self)
                if not InCombatLockdown() then ShowSubMenu(catName, spells, self) end
            end)
            yOffset = yOffset - 23
        end

        -- Ungrouped teleport spells (show directly on main panel)
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

        -- Resize main panel
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

    -- Start Update Loop
    local updateFrame = CreateFrame("Frame")
    updateFrame:SetScript("OnUpdate", function(self, elapsed)
        timeSinceLastUpdate = timeSinceLastUpdate + elapsed
        if timeSinceLastUpdate >= updateInterval then
            Widgets.UpdateContent()
            timeSinceLastUpdate = 0
        end
    end)

    Widgets.UpdateVisuals()
end

function Widgets.UpdateVisuals()
    local db = UIThingsDB.widgets
    if not db then return end

    for key, frame in pairs(frames) do
        if db.enabled and db[key].enabled then
            frame:Show()
            -- Apply Font
            local fontName = db.font
            local fontSize = db.fontSize
            local fontFlags = db.fontFlags or "OUTLINE"
            frame.text:SetFont(fontName, fontSize, fontFlags)
            
            -- Apply Coilor
            local c = db.fontColor
            frame.text:SetTextColor(c.r, c.g, c.b, c.a)

            -- Apply Strata
            frame:SetFrameStrata(db.strata)

            -- Apply Position
            frame:ClearAllPoints()
            if db[key].point then
                frame:SetPoint(db[key].point, UIParent, db[key].relPoint or db[key].point, db[key].x, db[key].y)
            else
                frame:SetPoint("CENTER", 0, 0)
            end

            -- Unlock highlighting
            if not db.locked then
                frame.bg:Show()
                frame:EnableMouse(true)
                frame.coords:Show()
                local x = db[key].x or 0
                local y = db[key].y or 0
                frame.coords:SetText(string.format("(%.0f, %.0f)", x, y))
            else
                frame.bg:Hide()
                frame.coords:Hide()
                -- If it's a click button (bag/time), keep mouse enabled, otherwise disable if just label?
                -- Requirement says "All of these widgets are just a label". But also "When you click on it..."
                -- So they must always be mouse enabled. Unlock just shows the bg.
                frame:EnableMouse(true) 
            end
        else
            frame:Hide()
        end
    end
    
    -- Force one update
    Widgets.UpdateContent()
end

function Widgets.UpdateContent()
    if not UIThingsDB.widgets.enabled then return end

    -- 1. Time
    if frames["time"] and frames["time"]:IsShown() then
        local format = "%I:%M %p"
        if UIThingsDB.misc and UIThingsDB.misc.minimapClockFormat == "24H" then
            format = "%H:%M"
        end
        frames["time"].text:SetText(date(format)) 
    end

    -- 2. FPS/MS
    if frames["fps"] and frames["fps"]:IsShown() then
        local _, _, latencyHome, _ = GetNetStats()
        local fps = GetFramerate()
        frames["fps"].text:SetText(string.format("%d ms / %.0f fps", latencyHome, fps))
    end

    -- 3. Bags
    if frames["bags"] and frames["bags"]:IsShown() then
        local free = 0
        for i = 0, NUM_BAG_SLOTS do
            free = free + C_Container.GetContainerNumFreeSlots(i)
        end
        frames["bags"].text:SetText("Bags: " .. free)
    end
    
    -- 4. Spec
    if frames["spec"] and frames["spec"]:IsShown() then
        local currentSpecIndex = GetSpecialization()
        if currentSpecIndex then
            local currentSpecId, _, _, currentSpecIcon = GetSpecializationInfo(currentSpecIndex)
            local lootSpecId = GetLootSpecialization()
            
            local lootSpecIcon = currentSpecIcon
            if lootSpecId ~= 0 then
                local _, _, _, icon = GetSpecializationInfoByID(lootSpecId)
                lootSpecIcon = icon
            end
            
            if currentSpecIcon and lootSpecIcon then
                 frames["spec"].text:SetText(string.format("|T%s:16:16|t |T%s:16:16|t", currentSpecIcon, lootSpecIcon))
            end
        end
    end

    -- 5. Durability
    if frames["durability"] and frames["durability"]:IsShown() then
         local minDurability = 100
         for i = 1, 18 do -- Scan slots
             local current, max = GetInventoryItemDurability(i)
             if current and max then
                 local pct = (current / max) * 100
                 if pct < minDurability then minDurability = pct end
             end
         end
         frames["durability"].text:SetText(string.format("Durability: %.0f%%", minDurability))
    end
    
    -- 6. Combat (handled by event, but init here if needed)
    if frames["combat"] and frames["combat"]:IsShown() then
        if UnitAffectingCombat("player") then
            frames["combat"].text:SetText("|cffff0000In Combat|r")
        else
            frames["combat"].text:SetText("|cff00ff00Out of Combat|r")
        end
    end

    -- 7. Friends
    if frames["friends"] and frames["friends"]:IsShown() then
        local numOnline = C_FriendList.GetNumOnlineFriends() or 0
        local _, numBNetOnline = BNGetNumFriends()
        
        -- Recalculate BNet if we are filtering
        local bnetCount = 0
        if UIThingsDB.widgets.showWoWOnly then
             local numBNet = BNGetNumFriends()
             for i = 1, numBNet do
                local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
                if accountInfo and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.isOnline then
                    if accountInfo.gameAccountInfo.clientProgram == BNET_CLIENT_WOW then
                        bnetCount = bnetCount + 1
                    end
                end
             end
        else
             bnetCount = numBNetOnline or 0
        end

        frames["friends"].text:SetText("Friends: " .. (numOnline + bnetCount))
    end

    -- 8. Guild
    if frames["guild"] and frames["guild"]:IsShown() then
         if IsInGuild() then
            local _, numOnline = GetNumGuildMembers()
            frames["guild"].text:SetText("Guild: " .. (numOnline or 0))
         else
            frames["guild"].text:SetText("Guild: -")
         end
    end

    -- 9. Group
    if frames["group"] and frames["group"]:IsShown() then
         local tanks, healers, dps = 0, 0, 0
         local members = GetNumGroupMembers()
         if members > 0 then
             for i = 1, members do
                 local unit = IsInRaid() and "raid"..i or (i == members and "player" or "party"..i)
                 local role = UnitGroupRolesAssigned(unit)
                 if role == "TANK" then tanks = tanks + 1
                 elseif role == "HEALER" then healers = healers + 1
                 elseif role == "DAMAGER" then dps = dps + 1 end
             end
             
             local tIcon = CreateAtlasMarkup("roleicon-tiny-tank")
             local hIcon = CreateAtlasMarkup("roleicon-tiny-healer")
             local dIcon = CreateAtlasMarkup("roleicon-tiny-dps")
             
             frames["group"].text:SetText(string.format("%s %d %s %d %s %d (%d)", tIcon, tanks, hIcon, healers, dIcon, dps, members))
         else
             frames["group"].text:SetText("No Group")
         end
    end

    -- 10. Teleports
    if frames["teleports"] and frames["teleports"]:IsShown() then
        frames["teleports"].text:SetText("Teleports")
    end
end
