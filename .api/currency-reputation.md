# Currency & Reputation APIs

APIs for reading currency balances, weekly caps, and PvP conquest progress.

---

## C_CurrencyInfo

### C_CurrencyInfo.GetCurrencyInfo
```lua
local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
-- info.name          (string)   display name
-- info.description   (string)
-- info.quantity      (number)   current amount held
-- info.maxQuantity   (number)   cap (0 = no cap)
-- info.iconFileID    (number)   texture ID for the currency icon
-- info.quality       (number)   item quality enum
-- info.isTradeable   (bool)
-- info.isAccountWide (bool)
-- info.useTotalEarnedForMaxQty (bool)
-- info.totalEarned   (number)
-- info.discovered    (bool)     whether the player has encountered this currency
```

Returns `nil` if the currency ID is invalid or not yet discovered.

**Used in:** Loot.lua (display currency in loot toasts), widgets/Bags.lua (currency summary), widgets/PvP.lua.

**Common currency IDs:**
- 6 — Gold (not really a currency; use `GetMoney()` instead)
- 1792 — Honor
- 1602 — Conquest
- 2009 — Valor (varies by expansion)
- 2032 — Resonance Crystals (TWW)

### C_CurrencyInfo.GetCurrencyListSize
```lua
local count = C_CurrencyInfo.GetCurrencyListSize()
```
Returns the number of currencies in the player's currency list.

### C_CurrencyInfo.GetCurrencyListInfo
```lua
local info = C_CurrencyInfo.GetCurrencyListInfo(index)
-- Same fields as GetCurrencyInfo plus:
-- info.isHeader      (bool)   this entry is a header, not a currency
-- info.isHeaderExpanded (bool)
-- info.isShowInBackpack (bool)
```
Used to iterate the full currency list (including uncollected currencies).

---

## C_WeeklyRewards

### C_WeeklyRewards.GetConquestWeeklyProgress
```lua
local info = C_WeeklyRewards.GetConquestWeeklyProgress()
-- info.progress   (number)  current conquest earned this week
-- info.maxProgress (number) conquest cap for the week
-- info.unlockedRewardCount (number)
```

Returns conquest progress toward the weekly cap. Returns `nil` outside of PvP seasons.

**Used in:** widgets/PvP.lua to display conquest progress.

---

## Relevant Events

| Event | Description |
|---|---|
| `CURRENCY_DISPLAY_UPDATE` | A currency amount changed |
| `HONOR_XP_UPDATE` | Honor or PvP XP updated |
| `PVP_REWARDS_UPDATE` | PvP weekly reward info updated |
