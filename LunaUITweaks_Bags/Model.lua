local _, Bags = ...
Bags.categories = {
    {key = "favorites", name = "Favorites", dropKind = "favorite"},
    {key = "new", name = "New Items"},
    {key = "gear", name = "Gear"},
    {key = "consumables", name = "Consumables"},
    {key = "pets", name = "Pets"},
    {key = "mounts", name = "Mounts"},
    {key = "decor", name = "Housing Decor"},
    {key = "quest", name = "Quest Items"},
    {key = "questOther", name = "Quest Items (not in log)"},
    {key = "vendor", name = "Vendor", dropKind = "vendor"},
    {key = "junk", name = "Junk"},
    {key = "reagents", name = "Crafting Reagents"},
    {key = "other", name = "Other"},
}
local metadata = {}
function Bags.ClearItemCache() wipe(metadata) end
local function ItemData(id)
    if metadata[id] then return metadata[id] end
    local name, _, _, _, _, _, _, _, equipLoc, _, _, classID, subclassID, _, _, _, reagent = C_Item.GetItemInfo(id)
    local _, _, _, instantEquip, _, instantClass, instantSubclass = C_Item.GetItemInfoInstant(id)
    local spell = C_Item.GetItemSpell(id)
    local data = {name = name, classID = classID or instantClass, subclassID = subclassID or instantSubclass, equipLoc = equipLoc or instantEquip,
        reagent = reagent, usable = spell ~= nil}
    -- Uncached item data is provisional; GET_ITEM_INFO_RECEIVED triggers a rebuild.
    if name then metadata[id] = data end
    return data
end
function Bags.IsKeystone(info)
    return info.itemID == 158923 or (type(info.hyperlink) == "string" and info.hyperlink:find("|Hkeystone:", 1, true) ~= nil)
end
-- ============================================================
-- Quest items: in the log vs not
-- ============================================================
-- Objective text without counts, spaces or punctuation ("Wolf Pelt: 3/8" -> "wolfpelt").
local function Bare(text)
    return (text:gsub("%d+%s*/%s*%d+", ""):gsub("%d+%s*%%", ""):gsub("[%p%s]", ""):lower())
end
local function Readable(v) return not (issecretvalue and issecretvalue(v)) end
-- Item objectives (finished ones too: the items are still handed in) and usable
-- quest items of every quest in the log. nil when the log cannot be read.
local questCache
function Bags.ClearQuestCache() questCache = nil end
local function QuestLog()
    if questCache ~= nil then return questCache or nil end
    local cache = {objectives = {}, items = {}}
    local function AddText(text)
        if type(text) == "string" and Readable(text) and text ~= "" then cache.objectives[#cache.objectives + 1] = Bare(text) end
    end
    local function AddSpecial(logIndex)
        local link = GetQuestLogSpecialItemInfo and GetQuestLogSpecialItemInfo(logIndex)
        local id = type(link) == "string" and Readable(link) and tonumber(link:match("item:(%d+)"))
        if id then cache.items[id] = true end
    end
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo and C_QuestLog.GetQuestObjectives then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.questID then
                for _, objective in ipairs(C_QuestLog.GetQuestObjectives(info.questID) or {}) do
                    if objective.type == "item" then AddText(objective.text) end
                end
                AddSpecial(i)
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
        -- Forever / classic-style quest log.
        for i = 1, GetNumQuestLogEntries() do
            local _, _, _, isHeader = GetQuestLogTitle(i)
            if not isHeader then
                for j = 1, GetNumQuestLeaderBoards(i) or 0 do
                    local text, kind = GetQuestLogLeaderBoard(j, i)
                    if kind == "item" then AddText(text) end
                end
                AddSpecial(i)
            end
        end
    else
        questCache = false
        return nil
    end
    questCache = cache
    return cache
end
-- True when the quest item belongs to a quest you have: it starts a quest that is
-- in your log, it is a usable item of a logged quest, or its name is an item
-- objective of one. Unknown (log unreadable) counts as in the log.
function Bags.QuestItemInLog(info, quest, name)
    if quest and quest.questID then return quest.isActive == true end
    local log = QuestLog()
    if not log then return true end
    if log.items[info.itemID] then return true end
    if type(name) ~= "string" or name == "" then return false end
    local bare = Bare(name)
    if bare == "" then return false end
    -- Exact name, or its plural ("Wolf Pelts"); a plain substring would let short
    -- names ("Quest") match longer objectives ("Quest flags").
    for _, text in ipairs(log.objectives) do
        if text == bare or text == bare .. "s" or text == bare .. "es" then return true end
    end
    return false
end
function Bags.Classify(info, quest)
    local data = ItemData(info.itemID)
    if Bags.IsKeystone(info) then return "other", data.name end
    local classes = Enum.ItemClass
    if quest and (quest.isQuestItem or quest.questID) or data.classID == classes.Questitem then
        return Bags.QuestItemInLog(info, quest, data.name) and "quest" or "questOther", data.name
    end
    if info.quality == Enum.ItemQuality.Poor then return "junk", data.name end
    if data.classID == classes.Weapon or data.classID == classes.Armor then return "gear", data.name end
    local misc = Enum.ItemMiscellaneousSubclass or {}
    if (classes.Battlepet and data.classID == classes.Battlepet)
        or (type(info.hyperlink) == "string" and info.hyperlink:find("|Hbattlepet:", 1, true))
        or (data.classID == (classes.Miscellaneous or 15) and data.subclassID == (misc.CompanionPet or 2)) then
        return "pets", data.name
    end
    if data.classID == (classes.Miscellaneous or 15) and data.subclassID == (misc.Mount or 5) then
        return "mounts", data.name
    end
    local housing = Enum.ItemHousingSubclass or {}
    if classes.Housing and data.classID == classes.Housing and data.subclassID == (housing.Decor or 0) then
        return "decor", data.name
    end
    if data.reagent or data.classID == classes.Reagent or data.classID == classes.Tradegoods then return "reagents", data.name end
    if data.usable or data.classID == classes.Consumable then return "consumables", data.name end
    return "other", data.name
end
-- Use each full link rather than caching by item ID: upgrades and bonuses can
-- give two copies of the same item different effective levels.
function Bags.GearItemLevel(info)
    if not info then return end
    local data = ItemData(info.itemID)
    if data.classID ~= Enum.ItemClass.Weapon and data.classID ~= Enum.ItemClass.Armor then return end
    local getLevel = C_Item.GetDetailedItemLevelInfo or _G.GetDetailedItemLevelInfo
    if not getLevel or not info.hyperlink then return end
    local level = getLevel(info.hyperlink)
    if issecretvalue and issecretvalue(level) then return end
    if type(level) == "number" and level > 0 then return math.floor(level + .5) end
end
function Bags.InventoryIDs()
    local ids = {}
    for id = 0, (NUM_BAG_SLOTS or 4) do ids[#ids + 1] = id end
    local reagent = Enum.BagIndex.ReagentBag
    if reagent and reagent > (NUM_BAG_SLOTS or 4) then ids[#ids + 1] = reagent end
    return ids
end
function Bags.BankIDs(bankType)
    if not C_Bank or not C_Bank.CanViewBank(bankType) then return {}, false end
    local ids = {}
    if C_Bank.FetchPurchasedBankTabData then
        for _, tab in ipairs(C_Bank.FetchPurchasedBankTabData(bankType) or {}) do ids[#ids + 1] = tab.ID end
    elseif C_Bank.FetchPurchasedBankTabIDs then
        ids = C_Bank.FetchPurchasedBankTabIDs(bankType) or {}
    end
    return ids, true
end
-- Every slot appears exactly once, including empty slots (which remain valid drop targets).
function Bags.Scan(ids, groupNew)
    local result = {empty = {}, occupied = 0, capacity = 0}
    for _, category in ipairs(Bags.categories) do result[category.key] = {} end
    for _, bag in ipairs(ids) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            result.capacity = result.capacity + 1
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local entry = {bag = bag, slot = slot, info = info}
            if info and info.itemID then
                local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
                local category, name = Bags.Classify(info, quest)
                entry.isKeystone = Bags.IsKeystone(info)
                if groupNew and not entry.isKeystone and Bags.IsNewItem(bag, slot, info.itemID) then category = "new" end
                -- Player-assigned sections (bags only) win over automatic categories.
                local mark = groupNew and Bags.MarkOf and Bags.MarkOf(bag, slot)
                if mark then category = mark == "favorite" and "favorites" or "vendor" end
                entry.name = name or ""
                result[category][#result[category] + 1] = entry
                result.occupied = result.occupied + 1
            else
                result.empty[#result.empty + 1] = entry
            end
        end
    end
    -- Stable ordering: names, then physical location. No items are moved in-game.
    local function Less(a, b)
        if a.isKeystone ~= b.isKeystone then return a.isKeystone end
        if a.name ~= b.name then return a.name < b.name end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end
    for _, category in ipairs(Bags.categories) do table.sort(result[category.key], Less) end
    return result
end

-- Resolve at drop time: a previously empty slot may already have been filled.
-- Prefer a compatible specialty bag, keeping general-purpose space available.
function Bags.FindEmptySlot(ids, itemID)
    local itemFamily = C_Item.GetItemFamily(itemID) or 0
    local generic
    for _, bag in ipairs(ids) do
        local free, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
        bagFamily = bagFamily or 0
        if free and free > 0 and (bagFamily == 0 or bit.band(bagFamily, itemFamily) ~= 0) then
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                if not C_Container.GetContainerItemInfo(bag, slot) then
                    local entry = {bag = bag, slot = slot}
                    if bagFamily ~= 0 then return entry end
                    generic = generic or entry
                    break
                end
            end
        end
    end
    return generic
end
