# LunaUITweaks — WoW Lua API Reference

All WoW/Blizzard Lua APIs used across this addon, documented with caveats, secret-value warnings, and notes drawn from real debugging sessions. All information reflects WoW 12.0 (The War Within) retail client.

> **Rule of thumb:** If an API touches a Blizzard-owned frame or returns a value set by Blizzard's secure code, assume it may be tainted. Guard all protected frame operations with `InCombatLockdown()`.

---

## Categories

| File | Category | Key APIs |
|---|---|---|
| [frame-ui.md](frame-ui.md) | Frame & UI Creation | `CreateFrame`, `SetPoint`, `SetScript`, `RegisterEvent` |
| [timers.md](timers.md) | Timer System | `C_Timer.After`, `C_Timer.NewTimer`, `C_Timer.NewTicker` |
| [quest-objective.md](quest-objective.md) | Quest & Objective Tracking | `C_QuestLog.*`, `C_SuperTrack.*`, `C_GossipInfo.*` |
| [item-inventory.md](item-inventory.md) | Items & Inventory | `C_Container.*`, `C_Item.*`, `GetItemInfo`, `C_Bank.*` |
| [unit-player.md](unit-player.md) | Unit & Player | `UnitName`, `UnitClass`, `UnitGUID`, `UnitExists` |
| [combat-spell.md](combat-spell.md) | Combat & Spells | `InCombatLockdown`, `GetTime`, `IsPlayerSpell`, `C_Spell.*` |
| [events-communication.md](events-communication.md) | Events & Addon Comm | `RegisterEvent`, `hooksecurefunc`, `C_ChatInfo.*` |
| [tooltip.md](tooltip.md) | Tooltips | `GameTooltip`, `SetOwner`, `SetHyperlink` |
| [minimap-map.md](minimap-map.md) | Minimap & Maps | `C_Map.*`, `C_ChallengeMode.*` |
| [secure-protected.md](secure-protected.md) | Secure & Protected Frames | `RegisterStateDriver`, `SetAttribute`, `SecureHandlerStateTemplate` |
| [talent-spec.md](talent-spec.md) | Talents & Specs | `C_SpecializationInfo.*`, `GetSpecialization` |
| [vendor-merchant.md](vendor-merchant.md) | Vendor & Merchant | `CanMerchantRepair`, `RepairAllItems`, `C_MerchantFrame.*` |
| [group-social.md](group-social.md) | Group & Social | `IsInGroup`, `IsInRaid`, `GetNumGroupMembers`, `C_FriendList.*` |
| [currency-reputation.md](currency-reputation.md) | Currency & Reputation | `C_CurrencyInfo.*`, `C_WeeklyRewards.*` |
| [addon-version.md](addon-version.md) | Addon & Version | `C_AddOns.*`, `GetBuildInfo` |
| [class-color.md](class-color.md) | Class Colors | `C_ClassColor.GetClassColor` |
| [pvp.md](pvp.md) | PvP & War Mode | `C_PvP.IsWarModeDesired`, `C_PvP.GetWarModeRewardBonus` |
| [encounter-journal.md](encounter-journal.md) | Encounter Journal | `EJ_GetNumTiers`, `EJ_GetInstanceByIndex` |
| [blizzard-frames.md](blizzard-frames.md) | Blizzard Global Frames | `UIParent`, `GameTooltip`, `ChatFrame1`, `AlertFrame` |
| [globals-misc.md](globals-misc.md) | Miscellaneous Globals | `GetMoney`, `SetCVar`, `IsShiftKeyDown`, `StaticPopupDialogs` |

---

## Cross-Cutting Concerns

### Secret Values
Blizzard's secure code sets certain frame fields and event parameters as "secret" — they cannot be read by addon Lua without tainting the addon's execution context. Use `issecretvalue(val)` to test before reading.

Known secret values in this addon's context:
- `UNIT_SPELLCAST_INTERRUPTED` → `interruptedBy` parameter (4th arg) — always secret during combat
- Fields on Blizzard-owned frame tables (e.g. `DamageMeter` frame fields like `sessionType`, `damageMeterType`)
- Any value returned by `GetText()` on a Blizzard FontString that was set by secure code

### Taint Rules Summary
- **Never** write fields onto Blizzard frames (`frame.myField = x`)
- **Never** call `hooksecurefunc(frame, "Method", cb)` — use the global-function form only
- **Never** call positioning methods on Blizzard frames during combat
- **Safe reads**: `GetWidth()`, `GetHeight()`, `GetLeft()`, `GetBottom()`, `IsShown()` — numbers/booleans are not tainted
- See [secure-protected.md](secure-protected.md) for full taint rules

### Combat Lockdown Guard Pattern
```lua
if InCombatLockdown() then return end
-- safe to call SetPoint, ClearAllPoints, RegisterStateDriver, etc.
```

### EventBus Pattern
This addon uses a centralized `EventBus` (single frame) instead of per-module `CreateFrame`/`RegisterEvent`. See [events-communication.md](events-communication.md).
