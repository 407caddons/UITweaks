# Item & Inventory APIs

APIs for reading bag contents, item info, item level, and bank data.

---

## C_Container

Modern replacement for legacy `GetContainerItem*` globals.

### C_Container.GetContainerNumSlots
```lua
local numSlots = C_Container.GetContainerNumSlots(bagID)
```
Returns the number of slots in a bag. Returns 0 for bags that don't exist.

**Bag IDs:**
- `0` — Backpack
- `1`–`4` — Bag slots 1–4
- `5`–`11` — Bank bag slots (5 = built-in bank slots, 6–11 = purchased bank bags)
- `-1` — Keyring (legacy, empty in modern WoW)

### C_Container.GetContainerItemInfo
```lua
local info = C_Container.GetContainerItemInfo(bagID, slotID)
-- info.iconFileID      (number)  item icon texture ID
-- info.stackCount      (number)  how many items in stack
-- info.isLocked        (bool)    item is locked (being moved)
-- info.quality         (number)  item quality (0=grey, 1=white, ... 5=epic)
-- info.isReadable      (bool)
-- info.hasLoot         (bool)
-- info.hyperlink       (string)  full item hyperlink
-- info.isFiltered      (bool)    filtered by bag search
-- info.hasNoValue      (bool)    cannot be sold
-- info.itemID          (number)  item ID
-- info.isBound         (bool)    bound to player
```
Returns `nil` if the slot is empty.

### C_Container.GetContainerNumFreeSlots
```lua
local freeSlots, bagType = C_Container.GetContainerNumFreeSlots(bagID)
```
Returns free slots and the bag type bitmask (0 = generic, specialised bags have flags).

### Iterating All Bags
```lua
for bag = 0, 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then
            -- process info.itemID, info.stackCount, etc.
        end
    end
end
```

---

## C_Item

### C_Item.GetItemInfoInstant
```lua
local itemID, itemType, itemSubType, itemEquipLoc, iconFileID, itemClassID, itemSubClassID =
    C_Item.GetItemInfoInstant(itemID or itemLink or itemName)
```
Returns cached item data **without** triggering a server request. Returns `nil` if the item is not in the client cache.

**Caveat:** Unlike `GetItemInfo`, this never returns `nil` for the `itemName` — but it may return `nil` for the whole result if uncached.

### C_Item.GetDetailedItemLevelInfo
```lua
local effectiveItemLevel, previewLevel, sparseItemLevel =
    C_Item.GetDetailedItemLevelInfo(itemLocation or itemLink)
```
Returns the effective item level (with upgrades applied), the base item level, and the sparse item level.

Used in widgets/ItemLevel.lua to display the player's average equipped item level.

---

## GetItemInfo (Legacy Global)

```lua
local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType,
      itemSubType, itemStackCount, itemEquipLoc, itemIcon, itemSellPrice,
      itemClassID, itemSubClassID, bindType, expacID, setID, isCraftingReagent =
    GetItemInfo(itemID or itemLink or itemName)
```

**Caveat:** May return `nil` for all values if the item is not in the client cache. When this happens, the data will be available after the `GET_ITEM_INFO_RECEIVED` event fires. Pattern:

```lua
local name = GetItemInfo(itemID)
if not name then
    -- register for GET_ITEM_INFO_RECEIVED and retry
end
```

**Quality values:** 0=Poor (grey), 1=Common (white), 2=Uncommon (green), 3=Rare (blue), 4=Epic (purple), 5=Legendary (orange), 6=Artifact, 7=Heirloom, 8=WoW Token.

### GetItemQualityColor
```lua
local r, g, b, hex = GetItemQualityColor(quality)
```
Returns the colour associated with an item quality level. `hex` is a string like `"ff0070dd"`.

---

## GetDetailedItemLevelInfo (Legacy Global)

```lua
local effectiveItemLevel, previewLevel, sparseItemLevel = GetDetailedItemLevelInfo(itemLink)
```
Same as `C_Item.GetDetailedItemLevelInfo` but takes an item link string.

---

## Equipped Item APIs

```lua
local link = GetInventoryItemLink("player", slotID)
local current, maximum = GetInventoryItemDurability(slotID)
```

**Equipment slot IDs:**
- 1=Head, 2=Neck, 3=Shoulder, 4=Shirt, 5=Chest, 6=Waist, 7=Legs, 8=Feet
- 9=Wrist, 10=Hands, 11=Finger1, 12=Finger2, 13=Trinket1, 14=Trinket2
- 15=Back, 16=MainHand, 17=OffHand, 18=Ranged, 19=Tabard

`GetInventoryItemDurability` returns `nil, nil` for items without durability (trinkets, rings, etc.).

---

## C_Bank

### C_Bank.FetchPurchasedBankTabIDs
```lua
local tabIDs = C_Bank.FetchPurchasedBankTabIDs()
```
Returns an array of purchased bank tab IDs. Used in Reagents.lua to scan the Reagent Bank.

**Caveat:** Only returns data when the player has opened their bank at least once this session. Returns an empty table otherwise.

### C_Bank.FetchDepositedMoney
```lua
local money = C_Bank.FetchDepositedMoney(bankType)
```
Returns deposited gold in the bank. `bankType` is a `Enum.BankType` value.

---

## Coin Display

```lua
local text = GetCoinTextureString(copperAmount [, fontSize])
```
Formats a copper amount into a coloured gold/silver/copper string with coin icons. Used by Vendor.lua and Loot.lua for repair costs and item values.

---

## Relevant Events

| Event | Description |
|---|---|
| `BAG_UPDATE` | A bag's contents changed |
| `BAG_UPDATE_DELAYED` | Fired after a batch of `BAG_UPDATE` events (better for full rescans) |
| `PLAYER_MONEY` | Player's money changed |
| `BANKFRAME_OPENED` | Bank window opened |
| `BANKFRAME_CLOSED` | Bank window closed |
| `GET_ITEM_INFO_RECEIVED` | Item data now available in client cache |
| `ITEM_DURABILITY_CHANGED` | Item durability changed |
