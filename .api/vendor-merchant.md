# Vendor & Merchant APIs

APIs for auto-repair, durability tracking, and selling items at vendors.

---

## Repair APIs

### CanMerchantRepair
```lua
local canRepair = CanMerchantRepair()
```
Returns `true` if the current open merchant can repair items. Only valid while a merchant window is open (after `MERCHANT_SHOW`).

### CanGuildBankRepair
```lua
local canGuildRepair = CanGuildBankRepair()
```
Returns `true` if the player's guild bank can cover repair costs (guild has the perk and the player has withdrawal access).

### GetRepairAllCost
```lua
local cost, canRepair = GetRepairAllCost()
```
Returns the total repair cost in copper for all damaged items. `canRepair` mirrors `CanMerchantRepair()`. Returns `0, false` if no merchant is open or nothing needs repair.

### GetGuildBankMoney / GetGuildBankWithdrawMoney
```lua
local guildMoney = GetGuildBankMoney()
local withdrawLimit = GetGuildBankWithdrawMoney()
```
Returns guild bank balance and the player's daily withdrawal allowance in copper. Used to check if guild repair is affordable.

### RepairAllItems
```lua
RepairAllItems([guildBankRepair])
```
Repairs all items. Pass `true` to use guild bank funds; `false` or omit to use personal gold.

**Vendor.lua logic:**
1. Check `CanMerchantRepair()` — bail if no vendor.
2. If `CanGuildBankRepair()` and guild has enough money, call `RepairAllItems(true)`.
3. Otherwise check player's gold vs `GetRepairAllCost()`, call `RepairAllItems(false)` if affordable.
4. Show a chat notification with the cost.

---

## Junk Selling

### C_MerchantFrame.SellAllJunkItems
```lua
C_MerchantFrame.SellAllJunkItems()
```
Sells all grey-quality (junk) items in the player's bags. Only works while a merchant window is open.

---

## Durability Warnings

### GetInventoryItemDurability
```lua
local current, maximum = GetInventoryItemDurability(slotID)
```
Returns current and maximum durability for the item in the given equipment slot. Returns `nil, nil` for unequipped slots or items without durability.

**Durability scan pattern (Vendor.lua):**
```lua
local lowestPercent = 1.0
for slot = 1, 18 do
    local cur, max = GetInventoryItemDurability(slot)
    if cur and max and max > 0 then
        local pct = cur / max
        if pct < lowestPercent then lowestPercent = pct end
    end
end
```

**Relevant event:** `UPDATE_INVENTORY_DURABILITY` — fires when any item's durability changes.

---

## Coin Display

```lua
local text = GetCoinTextureString(copperAmount [, fontSize])
```
Formats copper into a gold/silver/copper string with coloured icons. Used for displaying repair costs and item sell prices.

**Example:** `GetCoinTextureString(150000)` → `"15 [gold icon]"`

---

## Relevant Events

| Event | Description |
|---|---|
| `MERCHANT_SHOW` | Merchant window opened — safe to call repair/sell APIs |
| `MERCHANT_CLOSED` | Merchant window closed |
| `UPDATE_INVENTORY_DURABILITY` | Item durability changed |
| `PLAYER_MONEY` | Player's gold changed (after repair/sell) |
