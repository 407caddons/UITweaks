local _, Bags = ...
-- Session-only inventory history: deliberately excluded from saved settings/export.
local previous, slotKeys, initialized = {}, {}, false
local startupLoot = {}
local warmTotals, warmGains, lastWarmScan = {}, {}, nil
-- Bank contents at the previous scan while the bank is open. Items moved from
-- the bank into the bags are transfers, not gains, so they are not "new".
local bankTotals
local function ScanBank()
    if not BankFrame or not BankFrame:IsShown() or not Bags.BankIDs then return nil end
    local totals = {}
    for _, bankType in ipairs({Enum.BankType.Character, Enum.BankType.Account}) do
        for _, bag in ipairs((Bags.BankIDs(bankType))) do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID then totals[info.itemID] = (totals[info.itemID] or 0) + (info.stackCount or 1) end
            end
        end
    end
    return totals
end
-- Called when the bank opens, before any withdrawal can happen.
function Bags.SnapshotBankForNewItems() bankTotals = ScanBank() end
local function Key(bag, slot)
    if ItemLocation and C_Item.GetItemGUID then
        local guid = C_Item.GetItemGUID(ItemLocation:CreateFromBagAndSlot(bag, slot))
        if guid then return guid end
    end
    return bag .. ":" .. slot
end
function Bags.TrackNewItems(reset)
    if not initialized and not reset then return end
    local current, keys, totals, oldTotals, pool = {}, {}, {}, {}, {}
    local order = {}
    for _, bag in ipairs(Bags.InventoryIDs()) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local key = Key(bag, slot)
                local record = {id = info.itemID, count = info.stackCount or 1, newCount = 0}
                current[key] = record
                order[#order + 1] = key
                keys[bag .. ":" .. slot] = key
                totals[record.id] = (totals[record.id] or 0) + record.count
            end
        end
    end
    if not reset or next(startupLoot) then
        if reset then
            -- Explicit self-loot messages distinguish gameplay gains from login
            -- hydration even before the short startup window has ended.
            for id, credit in pairs(startupLoot) do
                pool[id] = math.min(credit.count, math.max(0, (totals[id] or 0) - credit.base))
            end
        end
        for _, record in pairs(previous) do
            oldTotals[record.id] = (oldTotals[record.id] or 0) + record.count
            if not reset then pool[record.id] = (pool[record.id] or 0) + record.newCount end
        end
        if not reset then
            local bankNow = ScanBank()
            for id, count in pairs(totals) do
                local withdrawn = 0
                if bankNow and bankTotals then withdrawn = math.max(0, (bankTotals[id] or 0) - (bankNow[id] or 0)) end
                pool[id] = (pool[id] or 0) + math.max(0, count - (oldTotals[id] or 0) - withdrawn)
            end
        end
        -- Preserve existing new stacks by GUID when they move between bags.
        for _, key in ipairs(order) do
            local record, old = current[key], previous[key]
            if old and old.id == record.id then
                record.newCount = math.min(old.newCount, record.count, pool[record.id] or 0)
                pool[record.id] = (pool[record.id] or 0) - record.newCount
            end
        end
        -- Allocate newly gained units to new/increased stacks, then carry markers through merges.
        for pass = 1, 2 do
            for _, key in ipairs(order) do
                local record, old = current[key], previous[key]
                local room = record.count - record.newCount
                if pass == 1 then
                    local oldCount = old and old.id == record.id and old.count or 0
                    room = math.min(room, math.max(0, record.count - oldCount))
                end
                local added = math.min(room, pool[record.id] or 0)
                record.newCount = record.newCount + added
                pool[record.id] = (pool[record.id] or 0) - added
            end
        end
    end
    if reset then
        local before = {}
        for _, record in pairs(previous) do before[record.id] = (before[record.id] or 0) + record.count end
        warmTotals, warmGains, lastWarmScan = totals, {}, GetTime()
        for id, count in pairs(totals) do warmGains[id] = math.max(0, count - (before[id] or 0)) end
    end
    previous, slotKeys, initialized = current, keys, true
    bankTotals = ScanBank()
end
function Bags.IsNewItem(bag, slot, itemID)
    local record = previous[slotKeys[bag .. ":" .. slot]]
    return record and record.id == itemID and record.newCount > 0 or false
end
function Bags.HasNewItemBaseline() return initialized end

-- PLAYER_LOGIN can precede inventory hydration. The settling deadline starts
-- once per login, never sliding indefinitely with subsequent bag updates.
local warming, worldReady, generation = false, false, 0
function Bags.BeginNewItemSession()
    generation = generation + 1
    warming = true
    worldReady = false
    startupLoot = {}
    warmTotals, warmGains, lastWarmScan = {}, {}, nil
    Bags.TrackNewItems(true)
end
function Bags.OnNewItemWorldReady()
    if not warming or worldReady then return end
    worldReady = true
    local token = generation
    C_Timer.After(.75, function()
        if not warming or generation ~= token then return end
        Bags.TrackNewItems(true)
        warming = false
        startupLoot = {}
        warmTotals, warmGains, lastWarmScan = {}, {}, nil
        Bags.QueueRefresh()
    end)
end
function Bags.OnNewItemBagUpdate()
    Bags.TrackNewItems(warming)
end

local function EscapePattern(value)
    return (value:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end
function Bags.OnNewItemLoot(message)
    if not warming or not worldReady or (issecretvalue and issecretvalue(message)) or type(message) ~= "string" then return end
    for _, name in ipairs({"LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
        "LOOT_ITEM_CREATED_SELF", "LOOT_ITEM_CREATED_SELF_MULTIPLE"}) do
        local format = _G[name]
        if type(format) == "string" then
            local parts, fields, cursor = {}, {}, 1
            while true do
                local first, last = format:find("%%[%d%$]*[sd]", cursor)
                if not first then
                    parts[#parts + 1] = EscapePattern(format:sub(cursor))
                    break
                end
                parts[#parts + 1] = EscapePattern(format:sub(cursor, first - 1))
                local kind = format:sub(last, last)
                fields[#fields + 1] = kind
                parts[#parts + 1] = kind == "s" and "(.-)" or "(%d+)"
                cursor = last + 1
            end
            local captures = {message:match("^" .. table.concat(parts) .. "$")}
            if #captures > 0 then
                local itemID, count = nil, 1
                for i, kind in ipairs(fields) do
                    if kind == "s" then itemID = tonumber((captures[i] or ""):match("|Hitem:(%d+)"))
                    else count = tonumber(captures[i]) or 1 end
                end
                if itemID then
                    local credit = startupLoot[itemID]
                    if not credit then
                        local base = warmTotals[itemID] or 0
                        -- Chat can follow BAG_UPDATE_DELAYED in the same frame.
                        if lastWarmScan == GetTime() then base = math.max(0, base - (warmGains[itemID] or 0)) end
                        credit = {base = base, count = 0}
                        startupLoot[itemID] = credit
                    end
                    credit.count = credit.count + count
                    Bags.QueueRefresh()
                end
                return
            end
        end
    end
end
