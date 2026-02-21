# Widget Ideas & Improvements - LunaUITweaks

**Date:** 2026-02-21
**Previous Review:** 2026-02-20
**Current Widgets (27):** Time, FPS, Bags, Spec, Durability, Combat, Friends, Guild, Group, Teleports, Keystone, WeeklyReset, Coordinates, BattleRes, Speed, ItemLevel, Volume, Zone, PvP, MythicRating, Vault, DarkmoonFaire, Mail, PullCounter, Hearthstone, Currency, SessionStats

**New Standalone Modules (not widgets):** MplusTimer -- full M+ timer overlay. QuestAuto -- auto accept/turn-in quests. QuestReminder -- zone-based quest pickup reminders. TalentManager -- dedicated talent build management panel.

Ease ratings: **Easy** (few hours), **Medium** (1-2 days), **Hard** (3+ days)

---

## Changes Since Last Review (2026-02-21)

Git status shows modifications to 7 files (519 insertions, 179 deletions). Widget-relevant changes:

- **config/panels/WidgetsPanel.lua** -- Layout refinements: scrollChild width increased from 560 to 630, anchor dropdown width adjusted to 90, condition dropdown width adjusted to 85, spacing tightened. No new widget entries added.
- **TalentManager.lua** -- Major import string decoding additions (+288 lines). `DecodeImportString()` function, direct talent loading via `C_Traits.PurchaseRank`/`SetSelection`, `CleanupTempLoadouts()`. Strengthens the case for a Talent Loadout widget (#3) that surfaces the active loadout at a glance.
- **Combat.lua** -- `issecretvalue()` guard on aura names in `ScanConsumableBuffs()`. Relevant to Buff/Flask Reminder widget (#8) which would need the same pattern.
- **Loot.lua** -- `issecretvalue()` guard on `CHAT_MSG_LOOT`. Relevant to Personal Loot Tracker widget (#12) which would use the same event.
- No new widget files were added. Widget count remains at 27.

**None of the 20 numbered suggestions from the previous review have been implemented yet.**

---

## Previous Suggestions - Implementation Status

The following ideas from previous reviews have been implemented or superseded:

- **Loot Spec Widget** - DONE. The Spec widget shows both active spec and loot spec icons side by side.
- **Party Role Widget** - DONE. The Group widget displays tank/healer/DPS counts with role icons and total member count. Also includes ready check tracking and raid sorting.
- **Great Vault Progress Widget (Enhanced)** - DONE. The Vault widget shows per-row progress with slot-by-slot completion in the tooltip.
- **FPS Widget - Add Latency Display** - DONE. The FPS widget displays "XX ms / XX fps" with full addon memory breakdown in tooltip.
- **Durability Widget - Equipment Breakdown** - DONE. Tooltip shows per-slot durability with cached repair cost.
- **Mythic+ Death Counter Widget** - SUPERSEDED by MplusTimer module with per-player death breakdown tooltip.
- **Currency Widget Season Update** - DONE. Updated to TWW Season 3 currencies.
- **M+ Affix Widget** - SUPERSEDED by MplusTimer during runs. Standalone always-visible version carried forward.
- **Session Stats Widget** - DONE (NEW 2026-02-19). Implemented as `widgets/SessionStats.lua`. Tracks session duration, gold delta, items looted, and deaths. Persists across `/reload`. Right-click resets counters.
- **Widget Visibility Conditions** - DONE (NEW 2026-02-19). `EvaluateCondition()` supports 7 conditions: `always`, `combat`, `nocombat`, `group`, `solo`, `instance`, `world`. Per-widget condition dropdown in config panel. BattleRes and PullCounter default to `instance`.

---

## Won't Do

### DPS Meter Widget — Won't Do
**Attempted (2026-02-20):** Implemented three iterations using `COMBAT_LOG_EVENT` (blocked — event removed from addon API in 12.0), `UNIT_COMBAT` (abandoned for accuracy), and finally `C_DamageMeter.GetCombatSessionFromType(Current, Dps)`.

**Reason removed:** `C_DamageMeter.amountPerSecond` is a session average (total damage ÷ elapsed seconds since combat started), not a rolling-window DPS. The value increments slowly as a running average rather than reflecting burst DPS, and does not agree with other meters. WoW 12.0 removed all `COMBAT_LOG_EVENT_UNFILTERED` / `COMBAT_LOG_EVENT` access for third-party addons entirely. `C_DamageMeter` is the only addon-accessible damage API, and it only exposes session averages. Accurate per-second DPS tracking is not achievable in the addon API as of 12.0.

---

## New Widget Ideas

### 1. Profession Cooldowns Widget
Display active profession cooldowns (transmutes, daily crafts, weekly knowledge). Shows icon for primary profession and a countdown for the nearest cooldown. Tooltip lists all tracked profession cooldowns with time remaining. Could integrate with Reagents module for cross-character cooldown data.
- **Ease:** Medium
- **Rationale:** Requires scanning profession spell cooldowns via `C_TradeSkillUI` and `C_Spell.GetSpellCooldown`. The tricky part is building a reliable list of cooldown-gated recipes across all professions since there is no single API for "all profession cooldowns." Knowledge point weekly resets require tracking quest IDs. However, the core per-spell cooldown check is straightforward once the spell list is established.

### 2. Instance Lockout Widget
Show the number of active instance lockouts on the widget face (e.g., "Locks: 3"). Tooltip lists each saved instance with boss kill progress (e.g., "Nerub-ar Palace 6/8 Heroic"). Click to open the raid info panel. Includes `GetNumSavedWorldBosses()` for world boss kills.
- **Ease:** Easy-Medium
- **Rationale:** Uses `GetNumSavedInstances()` and `GetSavedInstanceInfo()` which are synchronous APIs requiring no async loading. Event-driven via `UPDATE_INSTANCE_INFO` and `PLAYER_ENTERING_WORLD`. Fills a clear gap -- no existing widget tracks lockout state. The `instance` visibility condition could auto-show it only when relevant.

### 3. Talent Loadout Widget
Display the name of the current active talent loadout on the widget face. Tooltip shows all saved loadouts with a checkmark on the active one. Left-click opens the talent frame. Right-click opens the TalentManager panel. Warning indicator when current talents do not match any saved loadout, leveraging TalentReminder's `CompareTalents()`.
- **Ease:** Easy-Medium
- **Rationale:** Uses `C_ClassTalents.GetActiveConfigProfile()`. Integration with TalentReminder for mismatch detection adds value. The TalentManager module already builds a full list of saved builds with match status. Leverages the investment in TalentManager and TalentReminder by surfacing loadout awareness at a glance.

### 4. M+ Affix Widget (Always-Visible)
Show the current week's Mythic+ affixes as compact text, visible at all times -- not just during M+ runs. Widget face shows the primary affix name. Tooltip shows all active affixes with full descriptions and icons.
- **Ease:** Easy
- **Rationale:** `C_MythicPlus.GetCurrentAffixes()` returns affix IDs, `C_ChallengeMode.GetAffixInfo()` provides name/description/icon. One of the simplest possible new widgets -- implementable in under 60 lines. Event-driven via `MYTHIC_PLUS_CURRENT_AFFIX_UPDATE`. The MplusTimer shows affixes during active runs, but this serves as a persistent quick reference for planning keys outside dungeons.

### 5. XP / Reputation Widget
For non-max-level characters, show current XP progress as a percentage with rested XP indicator. For max-level characters, show the currently watched reputation faction and standing progress. Right-click to cycle through tracked reputations.
- **Ease:** Medium
- **Rationale:** XP portion is simple (`UnitXP`, `UnitXPMax`, `GetXPExhaustion`). Reputation requires `C_Reputation.GetWatchedFactionData()` with handling for Renown, Paragon, Friendship, and standard standings. The War Within's multiple reputation systems add complexity. The `world` visibility condition is a natural fit.

### 6. World Boss / Weekly Event Widget
Show the current week's world bosses and whether they have been killed, plus the active weekly bonus event (Timewalking, PvP Brawl, etc.). Tooltip lists each world boss with killed/available status. Click opens the adventure guide.
- **Ease:** Medium
- **Rationale:** World boss completion tracked via rotating quest IDs. Weekly events from `C_Calendar` APIs. Complements WeeklyReset and DarkmoonFaire by covering other rotating content. Maintenance burden: boss-to-questID mapping needs updating each raid tier.

### 7. Calendar / Holiday Widget
Show the next upcoming WoW holiday or calendar event with a countdown. During active holidays, show the holiday name in themed color. Tooltip shows next 3-5 upcoming events with start dates. Click opens the calendar.
- **Ease:** Easy-Medium
- **Rationale:** Uses `C_Calendar` API. The DarkmoonFaire widget already demonstrates the entire countdown pattern. Could subsume DarkmoonFaire as a special case, reducing widget count. Requires `C_AddOns.LoadAddOn("Blizzard_Calendar")` on demand (WeeklyReset already does this on click).

### 8. Buff/Flask Reminder Widget
Show whether the player has well-fed buff, flask/phial, and augment rune active as compact colored indicators (green = active, red = missing, gray = N/A). Tooltip shows specific buff names and remaining durations.
- **Ease:** Medium
- **Rationale:** Requires `C_UnitAuras.GetAuraDataByIndex()` scanning and matching against known buff categories. The Combat module already has buff reminder functionality with category-based detection -- this widget borrows that logic for a compact always-visible version. The `combat` or `instance` visibility condition reduces clutter.

### 9. Warband Gold Tracker Widget
Show total gold across all characters plus Warband Bank balance. Widget face shows combined total in compact format (e.g., "123.4k g"). Tooltip breaks down per-character gold sorted by amount.
- **Ease:** Easy
- **Rationale:** The Bags widget already tracks cross-character gold in `UIThingsDB.widgets.bags.goldData` and fetches `C_Bank.FetchDepositedMoney(Enum.BankType.Account)` for Warband Bank. Zero new API work -- reuses existing data layer entirely. SessionStats' `FormatGoldDelta()` demonstrates gold formatting patterns. Estimated: under 80 lines.

### 10. Secondary Stats Widget
Display current haste percentage in real-time on the widget face. Tooltip shows all secondary stats (crit, mastery, versatility, haste) with percentages and ratings, plus primary stat value.
- **Ease:** Easy
- **Rationale:** `GetHaste()`, `GetCritChance()`, `GetMasteryEffect()`, `GetCombatRatingBonus()`, `GetVersatilityBonus()` are simple accessor APIs. Event-driven via `UNIT_STATS` or `COMBAT_RATING_UPDATE`. One of the simplest widgets -- comparable to the Combat widget (39 lines). Extends ItemLevel widget's gear-awareness into stat territory.

### 11. Delve Companion Widget
Show Brann companion level and weekly delve completion progress. Widget face displays "Delves: X/Y" for vault progress. Tooltip shows Brann's level, XP to next level, and completed delve tiers.
- **Ease:** Medium
- **Rationale:** Weekly progress partially available via `C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.World)` (Vault widget already uses this). Brann companion APIs less well-documented. High value for TWW seasonal content.

### 12. Personal Loot Tracker Widget
Track items looted during the current session with item level and quality. Widget face shows "Loot: X items". Tooltip lists last 10-15 items with quality color. Right-click clears session log.
- **Ease:** Medium
- **Rationale:** Builds on `CHAT_MSG_LOOT` that SessionStats already uses for counting. Adds item link parsing and storage. Loot module already parses item links via `C_Item.GetDetailedItemLevelInfo()`. Session data stored in capped array to bound memory.

### 13. Addon Communication Status Widget
Show how many group members have LunaUITweaks installed (e.g., "Luna: 3/5"). Tooltip shows each member's addon version, sync state, and keystone data availability. Click broadcasts a version check.
- **Ease:** Easy-Medium
- **Rationale:** AddonVersions module already maintains `playerData`. Keystone and MythicRating widgets already consume this data. This surfaces communication health itself. The `group` visibility condition is a natural fit.

### 14. Minimap Toggle Widget
Compact widget that toggles the minimap on/off with a click. Tooltip shows tracking type, zoom level. Right-click cycles minimap tracking options.
- **Ease:** Easy
- **Rationale:** `Minimap:Hide()`/`Show()` for toggling. `C_Minimap.GetTrackingInfo()` for tracking data. MinimapCustom module provides existing code to reference. One of the simplest possible widgets.

### 15. Class Resource Widget
Display the player's class-specific resource on the widget face: combo points, holy power, soul shards, runes, chi, arcane charges, etc. Real-time updates during combat.
- **Ease:** Medium
- **Rationale:** Uses `UnitPower("player", powerType)` and `UnitPowerMax("player", powerType)` with class-specific `Enum.PowerType` mapping. Multi-resource classes (Druids in different forms) add complexity. Needs fast updates via `UNIT_POWER_UPDATE` or OnUpdate handler (Speed widget's 0.5s `HookScript("OnUpdate", ...)` provides the pattern). The `combat` visibility condition is ideal.

---

## Improvements to Existing Widgets

### 16. Bags Widget - Reagent Bag & Low Space Warning
Add reagent bag and profession bag free slot counts to the tooltip. Add a color warning when total free space drops below a configurable threshold (red text on widget face when <5 free slots). Optionally show "Bags: 12 (R:8)" format.
- **Ease:** Easy
- **Rationale:** `C_Container.GetContainerNumFreeSlots()` already returns bag type as second value. Extending to reagent and profession bags is trivial. Vendor module already has `bagWarningThreshold` concept. The Bags tooltip already shows gold, currency, and character data -- bag-type breakdown fits naturally.

### 17. Keystone Widget - Weekly Best & Vault Integration
Add weekly best run (if different from season best) and vault progress summary ("Vault M+: 2/8") to the tooltip.
- **Ease:** Easy-Medium
- **Rationale:** `C_MythicPlus.GetWeeklyBestForMap()` for weekly best. `C_WeeklyRewards.GetActivities()` for vault progress (already used by Vault widget). Incremental addition to already rich tooltip. Turns Keystone into a complete M+ dashboard at a glance.

### 18. Hearthstone Widget - Multi-Hearth Selection Menu
Add right-click context menu to choose a specific hearthstone toy instead of random. Show owned toys in a list. Persist preference. Random stays as default left-click.
- **Ease:** Easy-Medium
- **Rationale:** `ownedHearthstones` list already built by `BuildOwnedList()`. `MenuUtil.CreateContextMenu` pattern proven in Spec widget. Needs `InCombatLockdown()` check for `SecureActionButtonTemplate` attribute changes. High user demand -- many players prefer specific hearthstone toys.

### 19. Group Widget - Instance Progress in Tooltip
Add instance progress section: bosses killed/total in dungeons/raids, M+ timer status and death count as compact summary.
- **Ease:** Medium
- **Rationale:** Instance progress via `GetInstanceInfo()` and `C_ScenarioInfo.GetCriteriaInfo()`. M+ data from `C_ChallengeMode` APIs. The Group tooltip is already the most complex (class-colored members, roles, ready check, raid sorting menu). Must avoid duplicating MplusTimer overlay info. Moderate complexity due to multiple data source aggregation.

### 20. Currency Widget - Configurable Currency List
Allow users to choose which currencies to track instead of the hardcoded `DEFAULT_CURRENCIES` list.
- **Ease:** Medium
- **Rationale:** **Simple approach:** Auto-detect currencies marked "show on backpack" via `info.isShowInBackpack`. The Bags widget tooltip already iterates this pattern. A few-line change. **Advanced approach:** Full config UI with search/selection. Either approach eliminates seasonal maintenance. The simple `isShowInBackpack` approach could be done in under 30 minutes as a first pass.

---

## Widget Framework Improvements

### A. Widget Groups / Snap-to-Grid
Allow grouping multiple widgets into a single bar that moves as one unit. Snap indicators when dragging near other widgets. Grouped widgets share a single drag handle.
- **Ease:** Hard
- **Impact:** Major UX improvement. The existing anchor system (`UpdateAnchoredLayouts`) handles docking to named frames, but widget-to-widget snapping requires collision detection and a new grouping data structure. The `OnDragStop` handler saves CENTER-relative positions, so snap logic intercepts that.

### B. Per-Widget Font Override
Allow individual widgets to override the global font family, size, and color. Each widget's config sub-table already exists. Adding optional `font`, `fontSize`, `fontColor` fields that fall back to global when nil. The `UpdateVisuals()` function already applies global styles per-widget.
- **Ease:** Easy-Medium
- **Impact:** Medium. Enables visual hierarchy. Implementation: modify `UpdateVisuals()` to check `db[key].font or db.font` per property. Per-widget font controls in WidgetsPanel -- perhaps a popup per widget to avoid expanding the panel too much.

### C. Widget Tooltip Anchor Override
Per-widget tooltip position instead of automatic `SmartAnchorTooltip` screen-half detection. Optional `tooltipAnchor` field per widget config.
- **Ease:** Easy
- **Impact:** Small but appreciated. Minimal code change -- override `SmartAnchorTooltip` with a fixed anchor point when the field is set.

### D. Widget Click-Through Mode
Per-widget option to make the widget click-through (non-interactive) when locked. Prevents accidental clicks near action bars. `EnableMouse(false)` when locked with this option. Trade-off: disables tooltip too. Alt+hover could show tooltip in click-through mode. Widgets using `SecureActionButtonTemplate` (Hearthstone, Keystone, Teleports) need special handling.
- **Ease:** Easy
- **Impact:** Medium for users who place widgets near action bars.

### E. Widget Update Interval Configuration
User-configurable ticker interval via a slider. Currently hardcoded as `local updateInterval = 1.0` in Widgets.lua. The Speed widget already runs its own 0.5s OnUpdate, showing per-widget rates are needed in practice.
- **Ease:** Easy
- **Impact:** Low-Medium. Lets users trade CPU for responsiveness.

---

## Prioritization Summary

**Quickest wins (Easy, highest return on effort):**
- #4 M+ Affix Widget -- under 60 lines, simplest new widget
- #9 Warband Gold Tracker -- reuses existing Bags data layer entirely
- #10 Secondary Stats -- simple accessor APIs, no state management
- #14 Minimap Toggle -- trivial click handler
- #16 Bags low-space warning -- single conditional added to existing code

**Highest strategic value:**
- #2 Instance Lockout -- fills a unique gap no other widget covers
- #3 Talent Loadout -- leverages TalentManager and TalentReminder investment
- #20 Currency configurable list -- eliminates recurring seasonal maintenance
- #18 Hearthstone selection menu -- addresses common user desire for toy selection
- #15 Class Resource -- fills a combat information gap, unique among widgets
