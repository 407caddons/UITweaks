# PvP & War Mode APIs

APIs for reading PvP and War Mode state.

---

## C_PvP

### C_PvP.IsWarModeDesired
```lua
local desired = C_PvP.IsWarModeDesired()
```
Returns `true` if the player has War Mode enabled (or wants it enabled — takes effect on next rested area visit). Note: this reflects the player's **preference**, not whether War Mode is currently **active** in the current zone.

### C_PvP.GetWarModeRewardBonus
```lua
local bonus = C_PvP.GetWarModeRewardBonus()
```
Returns the War Mode bonus percentage as an integer (e.g. `10` for 10% bonus XP/resources). Returns `0` if War Mode is not desired or no bonus is active.

**Used in:** widgets/PvP.lua to display War Mode status and bonus.

---

## Conquest & Honor

See [currency-reputation.md](currency-reputation.md) for `C_WeeklyRewards.GetConquestWeeklyProgress()` and `C_CurrencyInfo.GetCurrencyInfo()` for Honor/Conquest currency balances.

---

## Relevant Events

| Event | Description |
|---|---|
| `WAR_MODE_STATUS_UPDATE` | War Mode status changed |
| `HONOR_XP_UPDATE` | Honor amount changed |
| `PVP_REWARDS_UPDATE` | PvP weekly reward info updated |
| `ZONE_CHANGED_NEW_AREA` | Zone changed — War Mode can activate/deactivate on zone transitions |
