local _, Bags = ...
-- Favorites / Vendor: items the player drags onto a section's "+" tile.
-- Marks are per character and per exact item (item GUID), so another copy of
-- the same item is not affected. Vendor-marked items are sold with the greys
-- (Vendor.lua calls LunaUITweaksAPI.BagsSellVendorItems when auto-selling junk).

local function CharacterKey()
    local name, realm = UnitFullName("player")
    realm = realm or (GetNormalizedRealmName and GetNormalizedRealmName()) or ""
    return (name or "?") .. "-" .. realm
end

local function Store(kind)
    LunaUITweaksBagsDB = LunaUITweaksBagsDB or { enabled = true }
    LunaUITweaksBagsDB.marks = LunaUITweaksBagsDB.marks or {}
    local key = CharacterKey()
    local char = LunaUITweaksBagsDB.marks[key] or {}
    LunaUITweaksBagsDB.marks[key] = char
    char[kind] = char[kind] or {}
    return char[kind]
end

-- Exact-item identity; nil when this client cannot identify the item.
function Bags.ItemKey(bag, slot)
    if not (ItemLocation and C_Item.GetItemGUID) then return nil end
    local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if not location or (location.IsValid and not location:IsValid()) then return nil end
    local ok, guid = pcall(C_Item.GetItemGUID, location)
    if ok and type(guid) == "string" and guid ~= "" then return guid end
end

-- "favorite", "vendor" or nil.
function Bags.MarkOf(bag, slot)
    local key = Bags.ItemKey(bag, slot)
    if not key then return nil end
    if Store("favorite")[key] then return "favorite" end
    if Store("vendor")[key] then return "vendor" end
end

-- Assign to kind (nil removes the item from both).
function Bags.SetMark(bag, slot, kind)
    local key = Bags.ItemKey(bag, slot)
    if not key then return false end
    Store("favorite")[key] = nil
    Store("vendor")[key] = nil
    if kind then Store(kind)[key] = true end
    return true
end

-- Inventory bag/slot of the item on the cursor (it stays locked in its slot while held).
function Bags.CursorSlot()
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" then return nil end
    if C_Cursor and C_Cursor.GetCursorItem then
        local location = C_Cursor.GetCursorItem()
        if location and location.IsBagAndSlot and location:IsBagAndSlot() then
            local bag, slot = location:GetBagAndSlot()
            for _, id in ipairs(Bags.InventoryIDs()) do
                if id == bag then return bag, slot end
            end
            return nil
        end
    end
    for _, bag in ipairs(Bags.InventoryIDs()) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.isLocked and info.itemID == itemID then return bag, slot end
        end
    end
end

-- Drop handler for a section's "+" tile.
function Bags.AssignCursorItem(kind)
    if InCombatLockdown() then return end
    local bag, slot = Bags.CursorSlot()
    if not bag then
        if GetCursorInfo() == "item" then
            print("|cff00ccffLuna Bags:|r only items from your bags can be added here.")
        end
        return
    end
    ClearCursor()
    if not Bags.SetMark(bag, slot, kind) then
        print("|cff00ccffLuna Bags:|r this item cannot be tracked on this client.")
        return
    end
    Bags.QueueRefresh()
end

-- Sells vendor-marked items (one per 0.2s while the merchant stays open).
-- Items with no sell price are skipped and stay marked.
local selling = false
local function SellPrice(link)
    local price = select(11, C_Item.GetItemInfo(link))
    return type(price) == "number" and price or 0
end
local function SellVendorItems()
    if selling or not (LunaUITweaksBagsDB and LunaUITweaksBagsDB.enabled ~= false) then return end
    local queue = {}
    for _, bag in ipairs(Bags.InventoryIDs()) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.hyperlink and not info.isLocked and not info.hasNoValue and Bags.MarkOf(bag, slot) == "vendor"
                and SellPrice(info.hyperlink) > 0 then
                queue[#queue + 1] = { bag = bag, slot = slot, key = Bags.ItemKey(bag, slot), link = info.hyperlink,
                    value = SellPrice(info.hyperlink) * (info.stackCount or 1) }
            end
        end
    end
    if #queue == 0 then return end
    selling = true
    local sold, total, index = {}, 0, 0
    local function Finish()
        selling = false
        if #sold > 0 then
            local money = GetMoneyString and GetMoneyString(total, true) or tostring(total)
            print("|cff00ccffLuna Bags:|r sold " .. table.concat(sold, ", ") .. " (" .. money .. ").")
        end
        Bags.QueueRefresh()
    end
    local function Next()
        index = index + 1
        local item = queue[index]
        if not item or not (MerchantFrame and MerchantFrame:IsShown()) or InCombatLockdown() then
            Finish()
            return
        end
        -- Revalidate: the slot must still hold the same exact item.
        if Bags.ItemKey(item.bag, item.slot) == item.key then
            C_Container.UseContainerItem(item.bag, item.slot)
            Store("vendor")[item.key] = nil
            sold[#sold + 1] = item.link
            total = total + item.value
        end
        C_Timer.After(0.2, Next)
    end
    Next()
end
LunaUITweaksAPI.BagsSellVendorItems = SellVendorItems
