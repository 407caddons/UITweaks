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
local eventsEnabled = false

-- Centralized Logging
local Log = function(msg, level)
    if addonTable.Core and addonTable.Core.Log then
        addonTable.Core.Log("Reagents", msg, level)
    end
end

local GetCharacterKey = function() return addonTable.Core.GetCharacterKey() end

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
    local getItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(getItemInfo) ~= "function" then return false end
    local _, _, _, _, _, _, _, _, _, _, _, classID2 = getItemInfo(itemID)
    return classID2 == ITEM_CLASS_TRADEGOODS
end

-- Account-bound items are useful across characters even when not trade goods.
local function IsAccountItem(itemID)
    if not itemID or not C_Item then return false end
    local function Check(fn)
        if type(fn) ~= "function" then return false end
        local ok, value = pcall(fn, itemID)
        return ok and not (issecretvalue and issecretvalue(value)) and value == true
    end
    return Check(C_Item.IsItemBindToAccount) or Check(C_Item.IsItemBindToAccountUntilEquip)
end

--- Check if an item should be tracked given current settings.
-- Always tracks reagents and account-bound items; optionally other non-soulbound items.
-- @param itemID number
-- @param isBound boolean The isBound field from GetContainerItemInfo (nil treated as false)
-- @return boolean
local function ShouldTrackItem(itemID, isBound)
    if IsReagent(itemID) or IsAccountItem(itemID) then return true end
    if UIThingsDB.reagents.trackAllItems and not isBound then return true end
    return false
end

local liveBagCounts, liveBagNames = {}, {}
local liveBagCacheValid = false
local function RefreshLiveBagCache()
    local counts, names = {}, {}
    for bag = 0, math.max(NUM_BAG_SLOTS, REAGENT_BAG_SLOT) do
        if bag <= NUM_BAG_SLOTS or bag == REAGENT_BAG_SLOT then
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID then
                    counts[info.itemID] = (counts[info.itemID] or 0) + info.stackCount
                    local name = info.hyperlink and info.hyperlink:match("%[(.-)%]")
                    if name then names[name] = (names[name] or 0) + info.stackCount end
                end
            end
        end
    end
    liveBagCounts, liveBagNames, liveBagCacheValid = counts, names, true
end

--- Scan bags (containerIDs 0 through NUM_BAG_SLOTS, plus reagent bag)
-- @return table itemID -> count mapping
local function ScanBags()
    local items = {}
    local bagList = {}
    for bag = 0, NUM_BAG_SLOTS do
        bagList[#bagList + 1] = bag
    end
    if REAGENT_BAG_SLOT > NUM_BAG_SLOTS then bagList[#bagList + 1] = REAGENT_BAG_SLOT end
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
    local containers = {}
    if Enum and Enum.BagIndex and Enum.BagIndex.CharacterBankTab_1 then
        if not C_Bank or not C_Bank.FetchPurchasedBankTabIDs then return nil end
        if C_Bank.CanViewBank and not C_Bank.CanViewBank(Enum.BankType.Character) then return nil end
        containers = C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Character)
        if not containers then return nil end
    else
        containers = {-1, -3}
        -- The reagent bag occupies its own carried slot; never count it as bank storage.
        local first = math.max(NUM_BAG_SLOTS, REAGENT_BAG_SLOT) + 1
        for bag = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do containers[#containers+1] = bag end
    end
    local items = {}
    for _, bag in ipairs(containers) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and ShouldTrackItem(info.itemID, info.isBound) then
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
        local containerID = tabIDs[i]
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
        charData.bagUpdatedAt = time()
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
    RefreshLiveBagCache()
    local bagItems = ScanBags()
    local bankItems = ScanCharacterBank()

    EnsureDB()
    local key = GetCharacterKey()
    local charData = LunaUITweaks_ReagentData.characters[key] or {}
    charData.class = GetCharacterClass()
    charData.lastSeen = time()
    charData.bagItems = bagItems
    charData.bagUpdatedAt = time()
    bankItems = bankItems or charData.bankItems or {}
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
    if not liveBagCacheValid then RefreshLiveBagCache() end
    local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    return (name and liveBagNames[name]) or liveBagCounts[itemID] or 0
end

-- Choose bag snapshots by their scan time, then add cached personal-bank stock.
-- A larger count does not imply a newer snapshot. Zero is a valid newer count.
local function GetAllCharCounts(itemID)
    local currentKey = GetCharacterKey()
    local counts = {}
    local reagentChars = LunaUITweaks_ReagentData and LunaUITweaks_ReagentData.characters or {}
    local whChars = LunaUITweaks_WarehousingData and LunaUITweaks_WarehousingData.characters or {}
    local tracked = LunaUITweaks_WarehousingData and LunaUITweaks_WarehousingData.items or {}
    local keys = {}
    for key in pairs(reagentChars) do keys[key] = true end
    for key in pairs(whChars) do keys[key] = true end
    keys[currentKey] = true
    for key in pairs(keys) do
        local rd, wh = reagentChars[key], whChars[key]
        local bank = rd and rd.bankItems and rd.bankItems[itemID] or 0
        local bag = rd and ((rd.bagItems and rd.bagItems[itemID]) or 0) or 0
        local stamp = rd and (rd.bagUpdatedAt or rd.lastSeen or 0) or -1
        if rd and not rd.bagItems then bag = math.max(0, ((rd.items or {})[itemID] or 0) - bank) end
        if wh and wh.bagCounts and (tracked[itemID] or wh.bagCounts[itemID] ~= nil)
            and (wh.bagUpdatedAt or wh.lastSeen or 0) > stamp then
            bag = wh.bagCounts[itemID] or 0
        end
        if key == currentKey then bag = GetLiveBagCount(itemID) end
        local total = bag + bank
        if total > 0 then counts[key] = total end
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
end

--- Hook the tooltip system using TooltipDataProcessor
local function HookTooltip()
    if tooltipHooked then return end

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            if tooltip ~= GameTooltip then return end
            if not data then return end

            -- Skip tooltips owned by map pin frames (world quest rewards, treasure pins, etc.)
            -- Adding lines to GameTooltip while it is anchored to a secure map pin taints
            -- Blizzard's subsequent tooltip reads on the map.
            if WorldMapFrame then
                local frame = tooltip:GetOwner()
                for _ = 1, 10 do
                    if not frame then break end
                    if frame == WorldMapFrame then return end
                    frame = frame:GetParent()
                end
            end

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
            if not IsReagent(itemID) and not IsAccountItem(itemID)
                and not UIThingsDB.reagents.trackAllItems and not isWHTooltip then return end
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
    RefreshLiveBagCache()
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
    RefreshLiveBagCache()
    if not initialScanDone then
        initialScanDone = true
        ScheduleBagScan()
    end
end

local function EnableEvents()
    if eventsEnabled then return end
    EventBus.Register("BAG_UPDATE_DELAYED", OnBagUpdateDelayed, "Reagents")
    EventBus.Register("BANKFRAME_OPENED", OnBankframeOpened, "Reagents")
    EventBus.Register("BANKFRAME_CLOSED", OnBankframeClosed, "Reagents")
    EventBus.Register("PLAYERBANKSLOTS_CHANGED", OnPlayerBankslotsChanged, "Reagents")
    EventBus.Register("PLAYER_ENTERING_WORLD", OnPlayerEnteringWorld, "Reagents")
    -- PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED may not exist on all clients
    pcall(EventBus.Register, "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", OnAccountBankSlotsChanged, "Reagents")
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

EventBus.Register("PLAYER_LOGIN", OnPlayerLogin, "Reagents")

--- Called by config panel when settings change
function Reagents.UpdateSettings()
    if UIThingsDB.reagents.enabled then
        EnableEvents()
        HookTooltip()
        -- Refresh the tooltip cache once when enabling/changing tracking settings.
        RefreshLiveBagCache()
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
