# Widget Ideas — LunaUITweaks
Date: 2026-02-26 (updated 2026-03-02, refreshed 2026-03-06)

---

## Complete Widget Inventory (as of 2026-03-06)

| File | Key | Summary |
|---|---|---|
| `Bags.lua` | `bags` | Free bag slots; tooltip shows per-toon gold, warband gold, currencies |
| `BattleRes.lua` | `battleRes` | Battle res pool charges via `C_Spell.GetSpellCharges(20484)` |
| `Combat.lua` | `combat` | Elapsed combat timer (MM:SS), combat-condition aware |
| `Coordinates.lua` | `coordinates` | Player map coordinates from `C_Map` |
| `Crit.lua` | `crit` | Player crit chance; tooltip shows full secondary stats |
| `Currency.lua` | `currency` | User-configured currencies with popover panel |
| `DarkmoonFaire.lua` | `darkmoonFaire` | DMF active/countdown; tooltip shows profession quest completion |
| `Durability.lua` | `durability` | Lowest gear durability %; tooltip shows per-slot, cached repair cost |
| `FPS.lua` | `fps` | Home latency + FPS; tooltip with jitter, bandwidth, per-addon memory |
| `Friends.lua` | `friends` | Online friend count; tooltip shows names/zones |
| `Group.lua` | `group` | Group member count and composition |
| `Guild.lua` | `guild` | Online guild member count |
| `Haste.lua` | `haste` | Player haste %; tooltip shows full secondary stats |
| `Hearthstone.lua` | `hearthstone` | Hearthstone bind location, left-click uses it |
| `ItemLevel.lua` | `itemLevel` | Equipped/overall average item level; tooltip shows per-slot |
| `Keystone.lua` | `keystone` | Current keystone with rating gain estimate; teleport button |
| `Lockouts.lua` | `lockouts` | Raid/dungeon lockout status |
| `Mail.lua` | `mail` | Mail count (green=gold/items attached); cached from last mailbox visit |
| `Mastery.lua` | `mastery` | Player mastery %; tooltip shows full secondary stats |
| `MythicRating.lua` | `mythicRating` | M+ season rating |
| `PullCounter.lua` | `pullCounter` | Session pull count |
| `PullTimer.lua` | `pullTimer` | Pull timer; integrates BigWigs/DBM or chat countdown fallback |
| `PvP.lua` | `pvp` | Honor + conquest raw values; tooltip shows weekly progress + rated |
| `ReadyCheck.lua` | `readyCheck` | Ready check status display; left-click initiates a ready check |
| `SessionStats.lua` | `sessionStats` | Cycles: session time → gold/hr → XP/hr; tooltip with deaths/looted |
| `Spec.lua` | `spec` | Spec + loot spec icons; left=spec switch, right=loot spec switch |
| `Speed.lua` | `speed` | Movement speed as % of base; skyriding-aware |
| `Teleports.lua` | `teleports` | Popover of known teleport spells |
| `Time.lua` | `time` | Local clock (12h/24h); tooltip shows server time + reset countdowns |
| `Vault.lua` | `vault` | Great Vault progress (M+/Raid/Delves); click opens vault UI |
| `Vers.lua` | `vers` | Player versatility %; tooltip shows full secondary stats |
| `Volume.lua` | `volume` | Sound on/off toggle (left), volume cycle (right) |
| `WaypointDistance.lua` | `waypointDistance` | Distance to active map waypoint |
| `WeeklyReset.lua` | `weeklyReset` | Weekly reset countdown; tooltip shows daily reset |
| `WheeCheck.lua` | `wheeCheck` | DMF WHEE!/Top Hat buff timer (hidden outside DMF week) |
| `XPRep.lua` | `xpRep` | XP% while leveling, watched rep at max level; paragon support |
| `Zone.lua` | `zone` | Current subzone/zone text |
| `AddonComm.lua` | `addonComm` | AddonComm latency/status for the group |

---

## Previously Suggested Improvements — Updated Status

| Suggestion | Status |
|---|---|
| Mail: count + color-coded (gold/items=green) | Implemented — `Mail.lua` uses `ScanInbox()`, color-coded |
| Bags: show free/total | Still pending — main text still `Bags: %d` (free only) |
| Durability: color text + cost | Still pending — plain text, no color gradient in `UpdateContent` |
| PvP: conquest cap % + War Mode indicator | Still pending — still raw `H:X C:Y` |
| SessionStats: cycling display modes | Implemented — cycles session time / gold/hr / XP/hr via `tickCount` |
| ReadyCheck widget | Implemented — `ReadyCheck.lua` |
| PullTimer widget | Implemented — `PullTimer.lua` |
| ItemLevel widget | Implemented — `ItemLevel.lua` |
| Per-widget clickthrough toggle | Implemented — framework-level CT in `Widgets.lua` |
| CT default=true for display-only widgets | Still pending — not yet set in `Core.lua` DEFAULTS |
| WheeCheck Top Hat spell ID fix (71968 → 136583) | Implemented |
| WheeCheck dead branch (firstSunday > 7) | Still present in both `WheeCheck.lua` and `DarkmoonFaire.lua` — cosmetic |
| WidgetsPanel condition dropdown missing checkmark | Still present — `info.notCheckable = true` |

---

## 20 Widget Ideas and Improvements (2026-03-06)

---

### 1. Improvement to Bags — Free/Total Slot Count + Color
**Type:** Improvement of `Bags.lua`
**Difficulty:** Easy
**Description:** Change main text from `Bags: 12` to `Bags: 12/36`. Color green when >20% free, yellow 10–20%, red <10%. The total-slot loop already iterates `C_Container.GetContainerNumSlots(bag)` — just accumulate a total alongside the free count.
**API notes:** `C_Container.GetContainerNumSlots(bag)` for totals. No new events. No secret-value risk.

---

### 2. Improvement to Durability — Color-Coded Text + Inline Repair Cost
**Type:** Improvement of `Durability.lua`
**Difficulty:** Easy
**Description:** Add color thresholds in `UpdateContent`: green >80%, yellow 50–80%, red <50%. When below 80%, append the cached repair cost from `cachedRepairCost` (e.g. `Dur: 45% 12g`). Omit when `cachedRepairCost` is nil. Use plain string formatting, not `GetCoinTextureString` (textures render oddly at small sizes).
**API notes:** Color logic and `cachedRepairCost` already exist in the tooltip block — move into `UpdateContent`.

---

### 3. Improvement to PvP — Conquest Cap % + War Mode Suffix
**Type:** Improvement of `PvP.lua`
**Difficulty:** Easy
**Description:** Replace `H:X C:Y` with conquest weekly progress as a percentage (e.g. `PvP: 75%`), plus a `WM` suffix when War Mode is active. Color: green >=100%, yellow >=50%, red <50%.
**API notes:** `C_WeeklyRewards.GetConquestWeeklyProgress()` and `C_PvP.IsWarModeDesired()` are both already in the tooltip. Refactor into `RefreshPvPCache`. No new events.

---

### 4. Improvement to Zone — PvP Tag + Instance Difficulty Inline
**Type:** Improvement of `Zone.lua`
**Difficulty:** Medium
**Description:** Append a color-coded PvP tag when relevant (e.g. `Stormwind [Sanc]` in green, `Ashenvale [PvP]` in red) and a difficulty abbreviation when inside an instance (e.g. `Ara [M]`). Guard text overflow with a 25-char `strsub` on the zone name.
**API notes:** `C_PvP.GetZonePVPInfo()` and `GetInstanceInfo()` already fetched in tooltip — lift into `RefreshZoneCache`. Difficulty abbreviation is a small static table.

---

### 5. Improvement to Keystone — Inline Rating Gain Annotation
**Type:** Improvement of `Keystone.lua`
**Difficulty:** Medium
**Description:** Store `mapID` from `GetPlayerKeystone()` (currently discarded as the third return value) and use it to call `Widgets.EstimateRatingGain` inside `UpdateContent`. Color main text green with a gain annotation when upgrade available (e.g. `Key: Ara +14 |cFF00FF00+45|r`), grey when no upgrade.
**API notes:** `mapID` is already returned but discarded. `EstimateRatingGain` is already used in the tooltip. No additional bag scan cost.

---

### 6. Improvement to ItemLevel — Per-Slot Color Coding in Tooltip
**Type:** Improvement of `ItemLevel.lua`
**Difficulty:** Easy
**Description:** Color each slot's item level relative to the character's equipped average: green if at or above average, yellow if 5+ ilvl below, red if 10+ below. Immediately highlights the weakest slot without arithmetic.
**API notes:** `GetAverageItemLevel()` and `C_Item.GetDetailedItemLevelInfo(itemLink)` are already called. Store `avgItemLevelEquipped` as a local and compare each slot against it.

---

### 7. New Widget — Challenge Mode (M+) Run Timer
**Type:** New widget
**Difficulty:** Easy
**Description:** When inside an active M+ run, shows elapsed time in MM:SS, color-coded green (on pace), orange (within 10% of time limit), red (over). Hides outside M+ instances. Complements Vault and Keystone without a full-screen timer addon.
**API notes:** `C_ChallengeMode.GetActiveChallengeMapID()`, `C_ChallengeMode.GetActiveKeystoneInfo()`. Capture start time on `CHALLENGE_MODE_START`. End on `CHALLENGE_MODE_COMPLETED` and `CHALLENGE_MODE_RESET`. 1s widget ticker. No secret-value risk.

---

### 8. New Widget — Rested XP Indicator
**Type:** New widget
**Difficulty:** Easy
**Description:** Shows rested XP as a percentage of the current level size (e.g. `Rest: 85%`). Green when rested, grey when none. Hides at max level.
**API notes:** `GetXPExhaustion()` for rested XP. `UnitXPMax("player")` for level size. `PLAYER_XP_UPDATE` and `PLAYER_ENTERING_WORLD` events. No taint risk.

---

### 9. New Widget — Buff/Aura Tracker
**Type:** New widget
**Difficulty:** Medium
**Description:** Tracks up to 4 user-configured buff/debuff spell IDs on the player. Main text shows the shortest remaining tracked aura duration (e.g. `Flask: 58m`), `All Up` if all active, `None` if none active. Tooltip lists each individually.
**API notes:** `C_UnitAuras.GetPlayerAuraBySpellID(spellID)`. `UNIT_AURA` on `"player"` for reactive updates plus 1s ticker. Config requires spell ID entry widget. `expirationTime - GetTime()` is plain arithmetic — no secret-value risk.

---

### 10. New Widget — Spell Cooldown Monitor
**Type:** New widget
**Difficulty:** Medium
**Description:** Tracks one or more user-configured spell IDs and shows the longest remaining cooldown (e.g. `CD: Hero 4m`) or `Ready` when all are off cooldown. Tooltip lists each spell individually.
**API notes:** `C_Spell.GetSpellCooldown(spellID)` returns `{startTime, duration, isEnabled, modRate}`. Skip GCDs with `duration > 1.5` guard. `SPELL_UPDATE_COOLDOWN` plus 1s ticker. Cooldown values are plain numbers — no secret-value risk.

---

### 11. New Widget — Equipped Gear Set Switcher
**Type:** New widget
**Difficulty:** Medium
**Description:** Shows the matching equipment set name (`Set: BiS`) or `Set: None`. Left-click opens a popover listing all saved gear sets; clicking a set equips it.
**API notes:** `C_EquipmentSet.GetEquipmentSetIDs()`, `GetEquipmentSetInfo(setID)`, `UseEquipmentSet(setID)`. Guard equip with `if InCombatLockdown() then return end`. Events: `EQUIPMENT_SETS_CHANGED`, `PLAYER_EQUIPMENT_CHANGED`. Popover pattern established in `Currency.lua` and `Teleports.lua`.

---

### 12. New Widget — World Quest Counter
**Type:** New widget
**Difficulty:** Medium
**Description:** Shows world quests completed today in the current zone (e.g. `WQ: 4/8`). Tooltip breaks down by zone. Left-click opens the world map.
**API notes:** `C_TaskQuest.GetQuestsForPlayerByMapID(mapID)` for available WQs. `C_QuestLog.IsQuestFlaggedCompleted(questID)` for each. `QUEST_TURNED_IN` and `QUEST_LOG_UPDATE` events.

---

### 13. New Widget — Major Faction Renown Summary
**Type:** New widget
**Difficulty:** Medium
**Description:** Shows the number of TWW major factions not yet at max renown (e.g. `Renown: 3 left`), green when all capped. Tooltip lists each faction with current renown level and max status.
**API notes:** `C_MajorFactions.GetMajorFactionIDs(expansionID)`, `GetCurrentRenownLevel(factionID)`, `HasMaximumRenown(factionID)`. `C_Expansion.GetCurrentExpansionLevel()` for expansion filter. Nil-guard for factions not yet unlocked. `UPDATE_FACTION` and `PLAYER_ENTERING_WORLD` events.

---

### 14. New Widget — Delve Companion Level
**Type:** New widget
**Difficulty:** Medium
**Description:** Shows Brann Bronzebeard's companion level (e.g. `Brann: 40`). Tooltip shows equipped curios. Hides or shows `N/A` for players who haven't engaged with Delves.
**API notes:** `C_DelvesUI` namespace. May require `C_AddOns.LoadAddOn("Blizzard_DelvesUI")`. `COMPANION_UPDATE` event or polling fallback. Consult `.api/index.md` before implementing — sparse documentation.

---

### 15. New Widget — Warband Bank Gold
**Type:** New widget
**Difficulty:** Easy
**Description:** Dedicated widget for Warband bank gold (e.g. `WB: 1.2k`). The Bags tooltip already shows this as a secondary line; a dedicated widget keeps it always visible.
**API notes:** `C_Bank.FetchDepositedMoney(Enum.BankType.Account)`. Accurate data may only be available when the bank frame is open — cache the last known value (same pattern as `cachedRepairCost`). `BANKFRAME_OPENED` and `PLAYER_MONEY` events.

---

### 16. New Widget — Reagent Stock Alert
**Type:** New widget
**Difficulty:** Medium
**Description:** Shows the stock count of one user-configured reagent (e.g. `Flask: 12`), red when below a user-set threshold. Integrates with `Reagents.lua`. Left-click opens bags.
**API notes:** Reads `LunaUITweaks_ReagentData` maintained by `Reagents.lua`. `BAG_UPDATE_DELAYED` for refresh. Config needs item ID entry and threshold slider. `C_Item.GetItemInfoInstant(itemID)` for validation.

---

### 17. New Widget — Simplified Threat Meter
**Type:** New widget
**Difficulty:** Medium
**Description:** Shows current threat on the player's target as a percentage (e.g. `Threat: 72%`), color-coded green/yellow/red. Hides when not in combat or when no target.
**API notes:** `UnitDetailedThreatSituation("player", "target")` returns `isTanking, status, scaledPercent, rawPercent, threatValue`. IMPORTANT: `scaledPercent` may be a secret value — use only arithmetic operations (`string.format`, `+`, `-`, `*`, `/`), never comparison operators directly on the return value. `UNIT_THREAT_SITUATION_UPDATE` event.

---

### 18. New Widget — Fishing / Profession Quick-Cast Button
**Type:** New widget
**Difficulty:** Easy
**Description:** A `SecureActionButtonTemplate` button widget that casts Fishing (or another user-configured spell) on left-click. Shows skill level in main text (e.g. `Fish: 320`).
**API notes:** Same `SecureActionButtonTemplate` pattern as `Keystone.lua`. `attribute "type" = "spell"`. Fishing skill via `C_TradeSkillUI.GetTradeSkillLine()`. Lure buff via `C_UnitAuras.GetPlayerAuraBySpellID`. Changing spell attribute requires out-of-combat — acceptable for fishing.

---

### 19. New Widget — Interrupt/CC Group Availability
**Type:** New widget
**Difficulty:** Hard
**Description:** Shows how many party members currently have their interrupt off cooldown (e.g. `CC: 3/4`), turning red when all interrupts are on cooldown. Uses AddonComm data from peers running LunaUITweaks.
**API notes:** Requires extending `Kick.lua` to broadcast personal interrupt CD state via `addonTable.Comm.Send`. The `interruptedBy` GUID from `UNIT_SPELLCAST_INTERRUPTED` is a secret value — do not use it. Track cooldown state from cast confirmation events only. Hard due to cross-client protocol design and secret-value constraints.

---

### 20. New Widget — Session Kill Counter
**Type:** New widget (or improvement to `SessionStats.lua`)
**Difficulty:** Medium
**Description:** Tracks enemy NPCs killed this session (e.g. `Kills: 47`). Can be standalone or an additional cycling mode in `SessionStats`. Tooltip shows kills/hour and total. Right-click resets.
**API notes:** `UNIT_DIED` fires when a unit dies — filter with `UnitIsPlayer(unit) == false`. Use `UnitGUID(unit)` to deduplicate. Check `issecretvalue(UnitGUID(unit))` before using as a table key. Do NOT use `COMBAT_LOG_EVENT_UNFILTERED` (restricted). Medium due to deduplication and secret-value verification on GUIDs.

---

## Framework Notes (2026-03-06)

### Clickthrough Default Candidates (still pending)
Widgets that could ship with `clickthrough = true` in `Core.lua` DEFAULTS — pure display, no click action: `Coordinates.lua`, `Speed.lua`, `Zone.lua`, `BattleRes.lua`, `Combat.lua (widget)`, `FPS.lua`.

### Condition Dropdown — Missing Checkmark (still pending)
The per-widget condition dropdown uses `info.notCheckable = true`. The active option appears in the dropdown header but has no in-dropdown checkmark. The anchor dropdown correctly uses `info.checked`. Minor UX inconsistency.

### Dead Branch in DMF Time Calculations (still present)
`firstSunday > 7` can never be true given the `1 + (8 - firstDow) % 7` formula. Present in both `WheeCheck.lua` and `DarkmoonFaire.lua`. Cosmetic only.

---

## Historical Notes

| # | Original Suggestion | Status |
|---|---|---|
| 1 | Spec Display | ✅ `widgets/Spec.lua` |
| 2 | Clock / Server Time | ✅ `widgets/Time.lua` |
| 3 | Weekly Reset Countdown | ✅ `widgets/WeeklyReset.lua` |
| 4 | FPS / Latency | ✅ `widgets/FPS.lua` |

Unplanned widgets that also shipped: `Speed.lua`, `Volume.lua`, `BattleRes.lua`, `Coordinates.lua`, `ReadyCheck.lua`, `PullTimer.lua`, `ItemLevel.lua`, `WheeCheck.lua`.
