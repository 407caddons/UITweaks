local _, Bags = ...
-- Session-only inventory history: deliberately excluded from saved settings/export.
local previous, slotKeys, initialized = {}, {}, false
local function Key(bag,slot)
    if ItemLocation and C_Item.GetItemGUID then
        local guid=C_Item.GetItemGUID(ItemLocation:CreateFromBagAndSlot(bag,slot))
        if guid then return guid end
    end
    return bag..":"..slot
end
function Bags.TrackNewItems(reset)
    if not initialized and not reset then return end
    local current,keys,totals,oldTotals,pool={},{},{},{},{}
    local order={}
    for _,bag in ipairs(Bags.InventoryIDs()) do
        for slot=1,C_Container.GetContainerNumSlots(bag) do
            local info=C_Container.GetContainerItemInfo(bag,slot)
            if info and info.itemID then
                local key=Key(bag,slot)
                local record={id=info.itemID,count=info.stackCount or 1,newCount=0}
                current[key]=record; order[#order+1]=key; keys[bag..":"..slot]=key
                totals[record.id]=(totals[record.id] or 0)+record.count
            end
        end
    end
    if not reset then
        for _,record in pairs(previous) do
            oldTotals[record.id]=(oldTotals[record.id] or 0)+record.count
            pool[record.id]=(pool[record.id] or 0)+record.newCount
        end
        for id,count in pairs(totals) do pool[id]=(pool[id] or 0)+math.max(0,count-(oldTotals[id] or 0)) end
        -- Preserve existing new stacks by GUID when they move between bags.
        for _,key in ipairs(order) do
            local record,old=current[key],previous[key]
            if old and old.id==record.id then
                record.newCount=math.min(old.newCount,record.count)
                pool[record.id]=pool[record.id]-record.newCount
            end
        end
        -- Allocate newly gained units to new/increased stacks, then carry markers through merges.
        for pass=1,2 do
            for _,key in ipairs(order) do
                local record,old=current[key],previous[key]
                local room=record.count-record.newCount
                if pass==1 then
                    local oldCount=old and old.id==record.id and old.count or 0
                    room=math.min(room,math.max(0,record.count-oldCount))
                end
                local added=math.min(room,pool[record.id] or 0)
                record.newCount=record.newCount+added; pool[record.id]=(pool[record.id] or 0)-added
            end
        end
    end
    previous,slotKeys,initialized=current,keys,true
end
function Bags.IsNewItem(bag,slot,itemID)
    local record=previous[slotKeys[bag..":"..slot]]
    return record and record.id==itemID and record.newCount>0 or false
end
function Bags.HasNewItemBaseline() return initialized end
