local addonName, addonTable = ...
local Reagents = {}
addonTable.Reagents = Reagents

-- Constants
local ITEM_CLASS_TRADEGOODS = 7
local SCAN_DELAY = 0.5
local NUM_BAG_SLOTS = NUM_BAG_SLOTS or 4
-- Reagent bag is a separate slot beyond the normal bag range (Enum.BagIndex.ReagentBag = 5)
local REAGENT_BAG_SLOT = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag or 5

-- State
local scanTimer = nil
local tooltipHooked = false
local characterKey = nil
local eventsEnabled = false

-- Centralized Logging
local Log = function(msg, level)
    if addonTable.Core and addonTable.Core.Log then
        addonTable.Core.Log("Reagents", msg, level)
    end
end

local function GetCharacterKey()
    if not characterKey then
        local name = UnitName("player")
        local realm = GetRealmName()
        characterKey = name .. " - " .. realm
    end
    return characterKey
end

local function GetCharacterClass()
    local _, classFile = UnitClass("player")
    return classFile
end

local function EnsureDB()
    LunaUITweaks_ReagentData = LunaUITweaks_ReagentData or {}
    LunaUITweaks_ReagentData.characters = LunaUITweaks_ReagentData.characters or {}
    LunaUITweaks_ReagentData.warband = LunaUITweaks_ReagentData.warband or {}
    LunaUITweaks_ReagentData.warband.items = LunaUITweaks_ReagentData.warband.items or {}
end

--- Check if an item is a tradeskill reagent by its item class
-- @param itemID number The item ID to check
-- @return boolean True if the item is a tradegoods item
local function IsReagent(itemID)
    if not itemID then return false end
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
    if classID then
        return classID == ITEM_CLASS_TRADEGOODS
    end
    local _, _, _, _, _, _, _, _, _, _, _, classID2 = GetItemInfo(itemID)
    return classID2 == ITEM_CLASS_TRADEGOODS
end

--- Check if an item should be tracked given current settings.
-- Always tracks reagents. When trackAllItems is enabled, also tracks any non-soulbound item.
-- @param itemID number
-- @param isBound boolean The isBound field from GetContainerItemInfo (nil treated as false)
-- @return boolean
local function ShouldTrackItem(itemID, isBound)
    if IsReagent(itemID) then return true end
    if UIThingsDB.reagents.trackAllItems and not isBound then return true end
    return false
end

--- Scan bags (containerIDs 0 through NUM_BAG_SLOTS, plus reagent bag)
-- @return table itemID -> count mapping
local function ScanBags()
    local items = {}
    local bagList = {}
    for bag = 0, NUM_BAG_SLOTS do
        bagList[#bagList + 1] = bag
    end
    bagList[#bagList + 1] = REAGENT_BAG_SLOT
    for _, bag in ipairs(bagList) do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not info.isLocked then
                if ShouldTrackItem(info.itemID, info.isBound) then
                    items[info.itemID] = (items[info.itemID] or 0) + info.stackCount
                end
            end
        end
    end
    return items
end

--- Scan character bank slots
-- Bank is only accessible when the bank frame is open
-- @return table itemID -> count mapping
local function ScanCharacterBank()
    local items = {}
    -- Main bank container (BANK_CONTAINER = -1)
    local numSlots = C_Container.GetContainerNumSlots(-1)
    for slot = 1, numSlots do
        local info = C_Container.GetContainerItemInfo(-1, slot)
        if info and info.itemID and not info.isLocked then
            if ShouldTrackItem(info.itemID, info.isBound) then
                items[info.itemID] = (items[info.itemID] or 0) + info.stackCount
            end
        end
    end
    -- Bank bag slots (NUM_BAG_SLOTS+1 through NUM_BAG_SLOTS+NUM_BANKBAGSLOTS)
    local numBankBags = NUM_BANKBAGSLOTS or 7
    for bag = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + numBankBags do
        numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not info.isLocked then
                if ShouldTrackItem(info.itemID, info.isBound) then
                    items[info.itemID] = (items[info.itemID] or 0) + info.stackCount
                end
            end
        end
    end
    -- Reagent bank container (REAGENTBANK_CONTAINER = -3)
    numSlots = C_Container.GetContainerNumSlots(-3)
    for slot = 1, numSlots do
        local info = C_Container.GetContainerItemInfo(-3, slot)
        if info and info.itemID and not info.isLocked then
            if ShouldTrackItem(info.itemID, info.isBound) then
                items[info.itemID] = (items[info.itemID] or 0) + info.stackCount
            end
        end
    end
    return items
end

--- Scan warband (account) bank for reagents
-- Only accessible when the account bank frame is open
-- @return table itemID -> count mapping
local function ScanWarbandBank()
    local items = {}
    if not C_Bank or not C_Bank.FetchPurchasedBankTabIDs then return items end
    if not Enum or not Enum.BagIndex or not Enum.BagIndex.AccountBankTab_1 then return items end

    local tabIDs = C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Account)
    if not tabIDs then return items end

    -- Account bank container IDs start at Enum.BagIndex.AccountBankTab_1
    local baseContainerID = Enum.BagIndex.AccountBankTab_1
    for i = 1, #tabIDs do
        local containerID = baseContainerID + (i - 1)
        local numSlots = C_Container.GetContainerNumSlots(containerID)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(containerID, slot)
            if info and info.itemID and not info.isLocked then
                if ShouldTrackItem(info.itemID, info.isBound) then
                    items[info.itemID] = (items[info.itemID] or 0) + info.stackCount
                end
            end
        end
    end
    return items
end

--- Debounced scan of bags only (real-time updates)
local function ScheduleBagScan()
    if scanTimer then
        scanTimer:Cancel()
    end
    scanTimer = C_Timer.NewTimer(SCAN_DELAY, function()
        scanTimer = nil
        if not UIThingsDB.reagents.enabled then return end
        local bagItems = ScanBags()
        -- Preserve existing bank data, only update bag portion
        EnsureDB()
        local key = GetCharacterKey()
        local charData = LunaUITweaks_ReagentData.characters[key]
        local existingBankItems = {}
        if charData and charData.bankItems then
            existingBankItems = charData.bankItems
        end
        -- We store bags + bank combined, but we need to know what was in the bank
        -- Strategy: store bag and bank separately internally, merge for display
        -- Actually, simpler: just rescan bags and keep bank data from last bank visit
        local merged = {}
        for itemID, count in pairs(bagItems) do
            merged[itemID] = (merged[itemID] or 0) + count
        end
        for itemID, count in pairs(existingBankItems) do
            merged[itemID] = (merged[itemID] or 0) + count
        end
        charData = charData or {}
        charData.class = GetCharacterClass()
        charData.lastSeen = time()
        charData.items = merged
        charData.bagItems = bagItems
        -- bankItems preserved from last bank visit
        LunaUITweaks_ReagentData.characters[key] = charData

        -- Keep central registry up to date
        if addonTable.Core and addonTable.Core.CharacterRegistry then
            addonTable.Core.CharacterRegistry.Register(key, GetCharacterClass(), "reagents")
        end
    end)
end

--- Full scan when bank is opened (bags + character bank)
local function DoFullCharacterScan()
    if not UIThingsDB.reagents.enabled then return end
    local bagItems = ScanBags()
    local bankItems = ScanCharacterBank()

    EnsureDB()
    local key = GetCharacterKey()
    local charData = LunaUITweaks_ReagentData.characters[key] or {}
    charData.class = GetCharacterClass()
    charData.lastSeen = time()
    charData.bagItems = bagItems
    charData.bankItems = bankItems

    -- Merge for the combined items view
    local merged = {}
    for itemID, count in pairs(bagItems) do
        merged[itemID] = (merged[itemID] or 0) + count
    end
    for itemID, count in pairs(bankItems) do
        merged[itemID] = (merged[itemID] or 0) + count
    end
    charData.items = merged
    LunaUITweaks_ReagentData.characters[key] = charData
end

--- Scan warband bank when account bank is opened
local function DoWarbandScan()
    if not UIThingsDB.reagents.enabled then return end
    EnsureDB()
    local warbandItems = ScanWarbandBank()
    LunaUITweaks_ReagentData.warband.items = warbandItems
    LunaUITweaks_ReagentData.warband.lastSeen = time()
end

--- Get class color for a character
-- @param classFile string The class token (e.g. "PALADIN")
-- @return number, number, number RGB values
local function GetClassRGB(classFile)
    if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        local c = RAID_CLASS_COLORS[classFile]
        return c.r, c.g, c.b
    end
    return 1, 1, 1
end

--- Get live bag count of an item for the current character.
-- Matches by itemID first, then falls back to name matching for quality-tier variants.
-- @param itemID number The item ID to count
-- @return number Total count across all bags (including reagent bag)
local function GetLiveBagCount(itemID)
    local count = 0
    local targetName = C_Item.GetItemNameByID(itemID)
    local bagList = {}
    for bag = 0, NUM_BAG_SLOTS do
        bagList[#bagList + 1] = bag
    end
    bagList[#bagList + 1] = REAGENT_BAG_SLOT
    for _, bag in ipairs(bagList) do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not info.isLocked then
                if info.itemID == itemID then
                    count = count + info.stackCount
                elseif targetName and info.hyperlink then
                    local slotName = info.hyperlink:match("%[(.-)%]")
                    if slotName and slotName == targetName then
                        count = count + info.stackCount
                    end
                end
            end
        end
    end
    return count
end

--- Build a unified per-character count map for an itemID, merging reagent and warehousing data.
-- Returns { [charKey] = count }, pulling live bag data for the current character.
local function GetAllCharCounts(itemID)
    local currentKey = GetCharacterKey()
    local counts = {}
    local registry = LunaUITweaks_CharacterData and LunaUITweaks_CharacterData.characters or {}

    -- Reagent data: cached totals per character
    if LunaUITweaks_ReagentData and LunaUITweaks_ReagentData.characters then
        for charKey, charData in pairs(LunaUITweaks_ReagentData.characters) do
            local n = charData.items and charData.items[itemID] or 0
            if n > 0 then counts[charKey] = n end
        end
    end

    -- Warehousing bag counts: overwrite if higher (more recent scan)
    local whChars = LunaUITweaks_WarehousingData and LunaUITweaks_WarehousingData.characters
    if whChars then
        for charKey, charData in pairs(whChars) do
            local n = charData.bagCounts and charData.bagCounts[itemID] or 0
            if n > 0 and n > (counts[charKey] or 0) then
                counts[charKey] = n
            end
        end
    end

    -- Current character: always use live bag scan (most accurate)
    local liveBagCount = GetLiveBagCount(itemID)
    local cachedBankCount = 0
    if LunaUITweaks_ReagentData and LunaUITweaks_ReagentData.characters then
        local cur = LunaUITweaks_ReagentData.characters[currentKey]
        if cur and cur.bankItems then
            cachedBankCount = cur.bankItems[itemID] or 0
        end
    end
    local liveTotal = liveBagCount + cachedBankCount
    if liveTotal > 0 then
        counts[currentKey] = liveTotal
    elseif counts[currentKey] and liveTotal == 0 then
        counts[currentKey] = nil -- bags are empty right now
    end

    return counts
end

--- Add reagent count lines to a tooltip for a given itemID
-- @param tooltip frame The tooltip to modify
-- @param itemID number The item ID being displayed
local function AddReagentLinesToTooltip(tooltip, itemID)
    if not UIThingsDB.reagents.enabled then return end
    EnsureDB()

    local currentKey = GetCharacterKey()
    local registry = LunaUITweaks_CharacterData and LunaUITweaks_CharacterData.characters or {}
    local counts = GetAllCharCounts(itemID)

    -- Warband
    local warbandCount = 0
    if LunaUITweaks_ReagentData.warband and LunaUITweaks_ReagentData.warband.items then
        warbandCount = LunaUITweaks_ReagentData.warband.items[itemID] or 0
    end

    if not next(counts) and warbandCount == 0 then return end

    tooltip:AddLine(" ")

    -- Current character first
    local currentCount = counts[currentKey]
    if currentCount and currentCount > 0 then
        local r, g, b = GetClassRGB(GetCharacterClass())
        local charName = currentKey:match("^(.+) %- ") or currentKey
        tooltip:AddDoubleLine(charName, tostring(currentCount), r, g, b, 1, 1, 1)
    end

    -- Other characters sorted alphabetically
    local others = {}
    for charKey, count in pairs(counts) do
        if charKey ~= currentKey then
            table.insert(others, { key = charKey, count = count })
        end
    end
    table.sort(others, function(a, b) return a.key < b.key end)
    for _, entry in ipairs(others) do
        local classFile = registry[entry.key] and registry[entry.key].class
        -- Also check reagent data for class
        if not classFile and LunaUITweaks_ReagentData and LunaUITweaks_ReagentData.characters then
            local rd = LunaUITweaks_ReagentData.characters[entry.key]
            classFile = rd and rd.class
        end
        local r, g, b = GetClassRGB(classFile)
        local charName = entry.key:match("^(.+) %- ") or entry.key
        tooltip:AddDoubleLine(charName, tostring(entry.count), r, g, b, 1, 1, 1)
    end

    if warbandCount > 0 then
        tooltip:AddDoubleLine("Warband", tostring(warbandCount), 0.4, 0.78, 1, 1, 1, 1)
    end

    tooltip:Show()
end

--- Hook the tooltip system using TooltipDataProcessor
local function HookTooltip()
    if tooltipHooked then return end

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            if tooltip ~= GameTooltip then return end
            if not data then return end

            local itemID
            if data.id then
                itemID = data.id
            elseif tooltip.GetItem then
                local _, link = tooltip:GetItem()
                if link then
                    itemID = tonumber(link:match("item:(%d+)"))
                end
            end
            if not itemID then return end

            -- Allow non-reagent items when hovering a warehousing icon
            local isWHTooltip = addonTable.WarehousingTooltipItemID ~= nil
            if not UIThingsDB.reagents.enabled then return end
            if not IsReagent(itemID) and not UIThingsDB.reagents.trackAllItems and not isWHTooltip then return end
            AddReagentLinesToTooltip(tooltip, itemID)
        end)
        tooltipHooked = true
    end
end

--- Unhook tooltip - since TooltipDataProcessor hooks can't be removed,
--- we rely on the enabled check inside the callback
local function UnhookTooltip()
    -- No-op: the callback checks UIThingsDB.reagents.enabled
end

-- Track bank open state
local bankOpen = false
local initialScanDone = false

local EventBus = addonTable.EventBus

-- Named callbacks for EventBus
local function OnBagUpdateDelayed()
    if not UIThingsDB.reagents.enabled then return end
    ScheduleBagScan()
    if bankOpen then DoFullCharacterScan() end
end

local function OnBankframeOpened()
    if not UIThingsDB.reagents.enabled then return end
    bankOpen = true
    DoFullCharacterScan()
    if C_Bank and C_Bank.CanViewBank and C_Bank.CanViewBank(Enum.BankType.Account) then
        DoWarbandScan()
    end
end

local function OnBankframeClosed()
    bankOpen = false
end

local function OnPlayerBankslotsChanged()
    if not UIThingsDB.reagents.enabled then return end
    if bankOpen then DoFullCharacterScan() end
end

local function OnAccountBankSlotsChanged()
    if not UIThingsDB.reagents.enabled then return end
    if bankOpen then DoWarbandScan() end
end

local function OnPlayerEnteringWorld()
    if not UIThingsDB.reagents.enabled then return end
    if not initialScanDone then
        initialScanDone = true
        ScheduleBagScan()
    end
end

local function EnableEvents()
    if eventsEnabled then return end
    EventBus.Register("BAG_UPDATE_DELAYED", OnBagUpdateDelayed)
    EventBus.Register("BANKFRAME_OPENED", OnBankframeOpened)
    EventBus.Register("BANKFRAME_CLOSED", OnBankframeClosed)
    EventBus.Register("PLAYERBANKSLOTS_CHANGED", OnPlayerBankslotsChanged)
    EventBus.Register("PLAYER_ENTERING_WORLD", OnPlayerEnteringWorld)
    -- PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED may not exist on all clients
    pcall(EventBus.Register, "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", OnAccountBankSlotsChanged)
    eventsEnabled = true
    initialScanDone = false
    Log("Events enabled", addonTable.Core.LogLevel.DEBUG)
end

local function DisableEvents()
    if not eventsEnabled then return end
    EventBus.Unregister("BAG_UPDATE_DELAYED", OnBagUpdateDelayed)
    EventBus.Unregister("BANKFRAME_OPENED", OnBankframeOpened)
    EventBus.Unregister("BANKFRAME_CLOSED", OnBankframeClosed)
    EventBus.Unregister("PLAYERBANKSLOTS_CHANGED", OnPlayerBankslotsChanged)
    EventBus.Unregister("PLAYER_ENTERING_WORLD", OnPlayerEnteringWorld)
    EventBus.Unregister("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", OnAccountBankSlotsChanged)
    eventsEnabled = false
    if scanTimer then
        scanTimer:Cancel()
        scanTimer = nil
    end
    Log("Events disabled", addonTable.Core.LogLevel.DEBUG)
end

local function OnPlayerLogin()
    EnsureDB()
    -- Register current character in the central registry regardless of module state
    local key = GetCharacterKey()
    if addonTable.Core and addonTable.Core.CharacterRegistry then
        addonTable.Core.CharacterRegistry.Register(key, GetCharacterClass(), "reagents")
    end
    if UIThingsDB.reagents.enabled then
        EnableEvents()
        HookTooltip()
        initialScanDone = false
    end
end

EventBus.Register("PLAYER_LOGIN", OnPlayerLogin)

--- Called by config panel when settings change
function Reagents.UpdateSettings()
    if UIThingsDB.reagents.enabled then
        EnableEvents()
        HookTooltip()
        -- Trigger a bag scan immediately
        ScheduleBagScan()
    else
        DisableEvents()
    end
end

--- Delete a character's data from all modules via CharacterRegistry.
-- @param charKey string The character key to delete (e.g. "Name - Realm")
function Reagents.DeleteCharacterData(charKey)
    if addonTable.Core and addonTable.Core.CharacterRegistry then
        addonTable.Core.CharacterRegistry.Delete(charKey)
    else
        -- Fallback: remove only from reagents data
        EnsureDB()
        LunaUITweaks_ReagentData.characters[charKey] = nil
    end
    Log("Deleted all data for " .. charKey, addonTable.Core.LogLevel.INFO)
end

--- Get all tracked characters (for config panel).
-- Uses CharacterRegistry as the authoritative source so characters from all modules are shown.
-- @return table Array of {key, class, lastSeen, itemCount, modules} sorted alphabetically
function Reagents.GetTrackedCharacters()
    EnsureDB()

    -- Build a set of keys from the central registry plus any local-only reagent data
    local seen = {}
    local chars = {}

    local function AddChar(key, class, lastSeen, modules)
        if seen[key] then return end
        seen[key] = true
        local itemCount = 0
        local localData = LunaUITweaks_ReagentData.characters[key]
        if localData and localData.items then
            for _ in pairs(localData.items) do itemCount = itemCount + 1 end
        end
        table.insert(chars, {
            key = key,
            class = class,
            lastSeen = lastSeen or 0,
            itemCount = itemCount,
            modules = modules or {},
        })
    end

    -- Central registry first (authoritative, covers all modules)
    if addonTable.Core and addonTable.Core.CharacterRegistry then
        for _, entry in ipairs(addonTable.Core.CharacterRegistry.GetAll()) do
            AddChar(entry.key, entry.class, entry.lastSeen, entry.modules)
        end
    end

    -- Fallback: also include any reagent-local characters not yet in the registry
    for key, data in pairs(LunaUITweaks_ReagentData.characters) do
        AddChar(key, data.class, data.lastSeen, nil)
    end

    table.sort(chars, function(a, b) return a.key < b.key end)
    return chars
end
