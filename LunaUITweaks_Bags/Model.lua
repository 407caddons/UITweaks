local _, Bags = ...
Bags.categories = {
    {key="new", name="New Items"},
    {key="gear", name="Gear"},
    {key="consumables", name="Consumables"},
    {key="quest", name="Quest Items"},
    {key="junk", name="Junk"},
    {key="reagents", name="Crafting Reagents"},
    {key="other", name="Other"},
}
local metadata = {}
function Bags.ClearItemCache() wipe(metadata) end
local function ItemData(id)
    if metadata[id] then return metadata[id] end
    local name, _, _, _, _, _, _, _, equipLoc, _, _, classID, _, _, _, _, reagent = C_Item.GetItemInfo(id)
    local _, _, _, instantEquip, _, instantClass = C_Item.GetItemInfoInstant(id)
    local spell = C_Item.GetItemSpell(id)
    local data = {name=name, classID=classID or instantClass, equipLoc=equipLoc or instantEquip,
        reagent=reagent, usable=spell~=nil}
    -- Uncached item data is provisional; GET_ITEM_INFO_RECEIVED triggers a rebuild.
    if name then metadata[id]=data end
    return data
end
function Bags.IsKeystone(info)
    return info.itemID==158923 or (type(info.hyperlink)=="string" and info.hyperlink:find("|Hkeystone:",1,true)~=nil)
end
function Bags.Classify(info, quest)
    local data = ItemData(info.itemID)
    if Bags.IsKeystone(info) then return "other",data.name end
    local classes = Enum.ItemClass
    if quest and (quest.isQuestItem or quest.questID) or data.classID==classes.Questitem then return "quest", data.name end
    if info.quality==Enum.ItemQuality.Poor then return "junk", data.name end
    if data.classID==classes.Weapon or data.classID==classes.Armor then return "gear", data.name end
    if data.reagent or data.classID==classes.Reagent or data.classID==classes.Tradegoods then return "reagents", data.name end
    if data.usable or data.classID==classes.Consumable then return "consumables", data.name end
    return "other", data.name
end
function Bags.InventoryIDs()
    local ids={}
    for id=0,(NUM_BAG_SLOTS or 4) do ids[#ids+1]=id end
    local reagent=Enum.BagIndex.ReagentBag
    if reagent and reagent>(NUM_BAG_SLOTS or 4) then ids[#ids+1]=reagent end
    return ids
end
function Bags.BankIDs(bankType)
    if not C_Bank or not C_Bank.CanViewBank(bankType) then return {}, false end
    local ids={}
    if C_Bank.FetchPurchasedBankTabData then
        for _,tab in ipairs(C_Bank.FetchPurchasedBankTabData(bankType) or {}) do ids[#ids+1]=tab.ID end
    elseif C_Bank.FetchPurchasedBankTabIDs then
        ids=C_Bank.FetchPurchasedBankTabIDs(bankType) or {}
    end
    return ids, true
end
-- Every slot appears exactly once, including empty slots (which remain valid drop targets).
function Bags.Scan(ids,groupNew)
    local result={empty={}, occupied=0, capacity=0}
    for _,category in ipairs(Bags.categories) do result[category.key]={} end
    for _,bag in ipairs(ids) do
        for slot=1,C_Container.GetContainerNumSlots(bag) do
            result.capacity=result.capacity+1
            local info=C_Container.GetContainerItemInfo(bag,slot)
            local entry={bag=bag, slot=slot, info=info}
            if info and info.itemID then
                local quest=C_Container.GetContainerItemQuestInfo(bag,slot)
                local category,name=Bags.Classify(info,quest)
                entry.isKeystone=Bags.IsKeystone(info)
                if groupNew and not entry.isKeystone and Bags.IsNewItem(bag,slot,info.itemID) then category="new" end
                entry.name=name or ""; result[category][#result[category]+1]=entry
                result.occupied=result.occupied+1
            else
                result.empty[#result.empty+1]=entry
            end
        end
    end
    -- Stable ordering: names, then physical location. No items are moved in-game.
    local function Less(a,b)
        if a.isKeystone~=b.isKeystone then return a.isKeystone end
        if a.name~=b.name then return a.name<b.name end
        if a.bag~=b.bag then return a.bag<b.bag end
        return a.slot<b.slot
    end
    for _,category in ipairs(Bags.categories) do table.sort(result[category.key],Less) end
    return result
end

-- Resolve at drop time: a previously empty slot may already have been filled.
-- Prefer a compatible specialty bag, keeping general-purpose space available.
function Bags.FindEmptySlot(ids,itemID)
    local itemFamily=C_Item.GetItemFamily(itemID) or 0
    local generic
    for _,bag in ipairs(ids) do
        local free,bagFamily=C_Container.GetContainerNumFreeSlots(bag)
        bagFamily=bagFamily or 0
        if free and free>0 and (bagFamily==0 or bit.band(bagFamily,itemFamily)~=0) then
            for slot=1,C_Container.GetContainerNumSlots(bag) do
                if not C_Container.GetContainerItemInfo(bag,slot) then
                    local entry={bag=bag,slot=slot}
                    if bagFamily~=0 then return entry end
                    generic=generic or entry
                    break
                end
            end
        end
    end
    return generic
end
