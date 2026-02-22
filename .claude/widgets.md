# Widget Ideas & Improvements - LunaUITweaks

**Date:** 2026-02-22
**Previous Review:** 2026-02-21
**Current Widgets (29):** Time, FPS, Bags, Spec, Durability, Combat, Friends, Guild, Group, Teleports, Keystone, WeeklyReset, Coordinates, BattleRes, Speed, ItemLevel, Volume, Zone, PvP, MythicRating, Vault, DarkmoonFaire, Mail, PullCounter, Hearthstone, Currency, SessionStats, Lockouts, XPRep

**New Standalone Modules (not widgets):** MplusTimer -- full M+ timer overlay. QuestAuto -- auto accept/turn-in quests. QuestReminder -- zone-based quest pickup reminders. TalentManager -- dedicated talent build management panel. Coordinates -- waypoint management with `/lway` command. SCT -- scrolling combat text (extracted from Misc.lua).

Ease ratings: **Easy** (few hours), **Medium** (1-2 days), **Hard** (3+ days)

---

## Changes Since Last Review (2026-02-22)

Git commit `a094160 Updates for v1.13` -- 17 files changed, 2094 insertions, 675 deletions. Widget-relevant changes:

- **widgets/Lockouts.lua** (+18 lines) -- Polished implementation. Now has proper `ApplyEvents(enabled)` pattern with Register/Unregister on `UPDATE_INSTANCE_INFO` and `PLAYER_ENTERING_WORLD`. Tooltip shows raids and dungeons separately with per-boss kill status for raids, difficulty names, extended lockout indicator, and time remaining. OnClick properly toggles `RaidInfoFrame`.
- **widgets/SessionStats.lua** (+40 lines) -- Major reliability overhaul. Added staleness detection: sessions auto-reset if offline >30 minutes or if switching characters (tracked via `charKey = UnitGUID("player")`). Data persisted via `SaveSessionData()` called on every counter update. `lastSeen` timestamp updated every tick for accurate staleness checks. `goldNeedsSnap` flag ensures gold baseline captured on first `PLAYER_ENTERING_WORLD`.
- **widgets/Time.lua** (+2 lines) -- Now respects `UIThingsDB.minimap.minimapClockFormat` for 12H/24H display, sharing the setting with the minimap clock.
- **NEW: Coordinates.lua (standalone module, ~652 lines)** -- Full waypoint management system with `/lway` command, zone name resolution via `C_Map` hierarchy, waypoint list UI with row pooling, paste dialog for bulk import, map integration (`C_Map.SetUserWaypoint`), super-tracking, and a config panel. NOT a widget -- separate module with its own frame.
- **widgets/Coordinates.lua (widget, unchanged)** -- Existing simple coordinates widget (55 lines) still shows player position. The new standalone Coordinates.lua module is separate.
- **NEW: SCT.lua (~249 lines)** -- Scrolling Combat Text extracted from Misc.lua into standalone module. Separate damage/healing anchors, frame pooling (`SCT_MAX_ACTIVE = 30`), `issecretvalue()` guards, target name display, crit scaling.
- **MinimapCustom.lua** (+225 lines) -- Major additions to minimap customization.
- **config/panels/MinimapPanel.lua** (+296 lines) -- Major config panel expansion.
- **config/ConfigMain.lua** (+246 lines) -- Config restructure with new panels for Coordinates and SCT.
- **Core.lua** (+63 lines) -- New defaults for `coordinates` and `sct` settings namespaces.

**Widget count increased from 27 to 29** (Lockouts and XPRep confirmed as full widgets since last count update).

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
- **Session Stats Widget** - DONE (2026-02-19). Implemented as `widgets/SessionStats.lua`. Tracks session duration, gold delta, items looted, and deaths. Persists across `/reload`. Right-click resets counters. **Updated 2026-02-22:** Staleness detection, character switching detection, and persistent gold baseline added.
- **Widget Visibility Conditions** - DONE (2026-02-19). `EvaluateCondition()` supports 7 conditions: `always`, `combat`, `nocombat`, `group`, `solo`, `instance`, `world`. Per-widget condition dropdown in config panel. BattleRes and PullCounter default to `instance`.
- **Instance Lockout Widget** - DONE (2026-02-22). Previously suggestion #2. Implemented as `widgets/Lockouts.lua` (164 lines). Shows locked instance count on widget face, tooltip separates raids and dungeons with per-boss kill status, extended lockout indicator, time remaining. Click opens Raid Info panel. Proper `ApplyEvents` pattern.
- **XP / Reputation Widget** - DONE (2026-02-22). Previously suggestion #5. Implemented as `widgets/XPRep.lua` (245 lines). Shows XP percentage with rested indicator for leveling characters, watched reputation with renown level for max-level characters. Tooltip shows full XP breakdown or reputation standing/progress with paragon support.

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

### 2. Talent Loadout Widget
Display the name of the current active talent loadout on the widget face. Tooltip shows all saved loadouts with a checkmark on the active one. Left-click opens the talent frame. Right-click opens the TalentManager panel. Warning indicator when current talents do not match any saved loadout, leveraging TalentReminder's `CompareTalents()`.
- **Ease:** Easy-Medium
- **Rationale:** Uses `C_ClassTalents.GetActiveConfigProfile()`. Integration with TalentReminder for mismatch detection adds value. The TalentManager module already builds a full list of saved builds with match status. Leverages the investment in TalentManager and TalentReminder by surfacing loadout awareness at a glance.

### 3. M+ Affix Widget (Always-Visible)
Show the current week's Mythic+ affixes as compact text, visible at all times -- not just during M+ runs. Widget face shows the primary affix name. Tooltip shows all active affixes with full descriptions and icons.
- **Ease:** Easy
- **Rationale:** `C_MythicPlus.GetCurrentAffixes()` returns affix IDs, `C_ChallengeMode.GetAffixInfo()` provides name/description/icon. One of the simplest possible new widgets -- implementable in under 60 lines. Event-driven via `MYTHIC_PLUS_CURRENT_AFFIX_UPDATE`. The MplusTimer shows affixes during active runs, but this serves as a persistent quick reference for planning keys outside dungeons.

### 4. World Boss / Weekly Event Widget
Show the current week's world bosses and whether they have been killed, plus the active weekly bonus event (Timewalking, PvP Brawl, etc.). Tooltip lists each world boss with killed/available status. Click opens the adventure guide.
- **Ease:** Medium
- **Rationale:** World boss completion tracked via rotating quest IDs. Weekly events from `C_Calendar` APIs. Complements WeeklyReset and DarkmoonFaire by covering other rotating content. Maintenance burden: boss-to-questID mapping needs updating each raid tier.

### 5. Calendar / Holiday Widget
Show the next upcoming WoW holiday or calendar event with a countdown. During active holidays, show the holiday name in themed color. Tooltip shows next 3-5 upcoming events with start dates. Click opens the calendar.
- **Ease:** Easy-Medium
- **Rationale:** Uses `C_Calendar` API. The DarkmoonFaire widget already demonstrates the entire countdown pattern. Could subsume DarkmoonFaire as a special case, reducing widget count. Requires `C_AddOns.LoadAddOn("Blizzard_Calendar")` on demand (WeeklyReset already does this on click).

### 6. Buff/Flask Reminder Widget
Show whether the player has well-fed buff, flask/phial, and augment rune active as compact colored indicators (green = active, red = missing, gray = N/A). Tooltip shows specific buff names and remaining durations.
- **Ease:** Medium
- **Rationale:** Requires `C_UnitAuras.GetAuraDataByIndex()` scanning and matching against known buff categories. The Combat module already has buff reminder functionality with category-based detection and `issecretvalue()` guards -- this widget borrows that logic for a compact always-visible version. The `combat` or `instance` visibility condition reduces clutter.

### 7. Warband Gold Tracker Widget
Show total gold across all characters plus Warband Bank balance. Widget face shows combined total in compact format (e.g., "123.4k g"). Tooltip breaks down per-character gold sorted by amount.
- **Ease:** Easy
- **Rationale:** The Bags widget already tracks cross-character gold in `UIThingsDB.widgets.bags.goldData` and fetches `C_Bank.FetchDepositedMoney(Enum.BankType.Account)` for Warband Bank. Zero new API work -- reuses existing data layer entirely. SessionStats' `FormatGoldDelta()` demonstrates gold formatting patterns. Estimated: under 80 lines.

### 8. Secondary Stats Widget
Display current haste percentage in real-time on the widget face. Tooltip shows all secondary stats (crit, mastery, versatility, haste) with percentages and ratings, plus primary stat value.
- **Ease:** Easy
- **Rationale:** `GetHaste()`, `GetCritChance()`, `GetMasteryEffect()`, `GetCombatRatingBonus()`, `GetVersatilityBonus()` are simple accessor APIs. Event-driven via `UNIT_STATS` or `COMBAT_RATING_UPDATE`. One of the simplest widgets -- comparable to the Combat widget (39 lines). Extends ItemLevel widget's gear-awareness into stat territory.

### 9. Delve Companion Widget
Show Brann companion level and weekly delve completion progress. Widget face displays "Delves: X/Y" for vault progress. Tooltip shows Brann's level, XP to next level, and completed delve tiers.
- **Ease:** Medium
- **Rationale:** Weekly progress partially available via `C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.World)` (Vault widget already uses this). Brann companion APIs less well-documented. High value for TWW seasonal content.

### 10. Personal Loot Tracker Widget
Track items looted during the current session with item level and quality. Widget face shows "Loot: X items". Tooltip lists last 10-15 items with quality color. Right-click clears session log.
- **Ease:** Medium
- **Rationale:** Builds on `CHAT_MSG_LOOT` that SessionStats already uses for counting. Adds item link parsing and storage. Loot module already parses item links via `C_Item.GetDetailedItemLevelInfo()`. Session data stored in capped array to bound memory.

### 11. Addon Communication Status Widget
Show how many group members have LunaUITweaks installed (e.g., "Luna: 3/5"). Tooltip shows each member's addon version, sync state, and keystone data availability. Click broadcasts a version check.
- **Ease:** Easy-Medium
- **Rationale:** AddonVersions module already maintains `playerData`. Keystone and MythicRating widgets already consume this data. This surfaces communication health itself. The `group` visibility condition is a natural fit.

### 12. Waypoint Distance Widget
Display distance to the active waypoint set via the new Coordinates module. Widget face shows "WP: 123yd" or direction arrow. Tooltip shows waypoint name, zone, coordinates, and estimated travel time. Click to cycle between waypoints. Leverages the new `Coordinates.lua` module's waypoint data.
- **Ease:** Easy-Medium
- **Rationale:** The new Coordinates module (`a094160`) stores waypoints in `UIThingsDB.coordinates.waypoints` and tracks `activeWaypointIndex`. The widget simply reads this data and calculates distance using `C_Map.GetPlayerMapPosition` vs waypoint coordinates. Complements the standalone Coordinates frame with an always-visible compact indicator.

### 13. Class Resource Widget
Display the player's class-specific resource on the widget face: combo points, holy power, soul shards, runes, chi, arcane charges, etc. Real-time updates during combat.
- **Ease:** Medium
- **Rationale:** Uses `UnitPower("player", powerType)` and `UnitPowerMax("player", powerType)` with class-specific `Enum.PowerType` mapping. Multi-resource classes (Druids in different forms) add complexity. Needs fast updates via `UNIT_POWER_UPDATE` or OnUpdate handler (Speed widget's 0.5s `HookScript("OnUpdate", ...)` provides the pattern). The `combat` visibility condition is ideal.

---

## Improvements to Existing Widgets

### 14. Bags Widget - Reagent Bag & Low Space Warning
Add reagent bag and profession bag free slot counts to the tooltip. Add a color warning when total free space drops below a configurable threshold (red text on widget face when <5 free slots). Optionally show "Bags: 12 (R:8)" format.
- **Ease:** Easy
- **Rationale:** `C_Container.GetContainerNumFreeSlots()` already returns bag type as second value. Extending to reagent and profession bags is trivial. Vendor module already has `bagWarningThreshold` concept. The Bags tooltip already shows gold, currency, and character data -- bag-type breakdown fits naturally.

### 15. Keystone Widget - Weekly Best & Vault Integration
Add weekly best run (if different from season best) and vault progress summary ("Vault M+: 2/8") to the tooltip.
- **Ease:** Easy-Medium
- **Rationale:** `C_MythicPlus.GetWeeklyBestForMap()` for weekly best. `C_WeeklyRewards.GetActivities()` for vault progress (already used by Vault widget). Incremental addition to already rich tooltip. Turns Keystone into a complete M+ dashboard at a glance.

### 16. Hearthstone Widget - Multi-Hearth Selection Menu
Add right-click context menu to choose a specific hearthstone toy instead of random. Show owned toys in a list. Persist preference. Random stays as default left-click.
- **Ease:** Easy-Medium
- **Rationale:** `ownedHearthstones` list already built by `BuildOwnedList()`. `MenuUtil.CreateContextMenu` pattern proven in Spec widget. Needs `InCombatLockdown()` check for `SecureActionButtonTemplate` attribute changes. High user demand -- many players prefer specific hearthstone toys.

### 17. Group Widget - Instance Progress in Tooltip
Add instance progress section: bosses killed/total in dungeons/raids, M+ timer status and death count as compact summary.
- **Ease:** Medium
- **Rationale:** Instance progress via `GetInstanceInfo()` and `C_ScenarioInfo.GetCriteriaInfo()`. M+ data from `C_ChallengeMode` APIs. The Group tooltip is already the most complex (class-colored members, roles, ready check, raid sorting menu). Must avoid duplicating MplusTimer overlay info. Moderate complexity due to multiple data source aggregation.

### 18. Currency Widget - Configurable Currency List
Allow users to choose which currencies to track instead of the hardcoded `DEFAULT_CURRENCIES` list.
- **Ease:** Medium
- **Rationale:** **Simple approach:** Auto-detect currencies marked "show on backpack" via `info.isShowInBackpack`. The Bags widget tooltip already iterates this pattern. A few-line change. **Advanced approach:** Full config UI with search/selection. Either approach eliminates seasonal maintenance. The simple `isShowInBackpack` approach could be done in under 30 minutes as a first pass.

### 19. SessionStats Widget - Gold Per Hour & Extended Metrics
Add gold-per-hour calculation to the tooltip (leveraging the new `lastSeen` timestamp and improved persistence from v1.13). Add XP per hour for leveling characters (reuse XPRep widget's level detection). Show session peak gold balance.
- **Ease:** Easy
- **Rationale:** Advanced by v1.13 changes. SessionStats now has reliable session timing (`sessionStart`, `lastSeen`, staleness detection). Gold delta and elapsed time are already tracked -- dividing them yields gold/hour. XP per hour requires `UnitXP("player")` snapshot similar to `goldAtLogin`. Under 20 lines of tooltip additions.

### 20. Lockouts Widget - World Boss Tracking & Cross-Character View
Extend the newly implemented Lockouts widget with world boss kill status via `GetNumSavedWorldBosses()` / `GetSavedWorldBossInfo()`. Add cross-character lockout data by saving lockout info per character in `UIThingsDB` (similar to Bags' `goldData` pattern). Tooltip could show "Alt has 5/8 Heroic Nerub-ar Palace saved".
- **Ease:** Medium
- **Rationale:** Advanced by v1.13 improvements. The Lockouts widget now has a solid foundation with raid/dungeon separation, per-boss display, and extended lockout support. Adding world bosses is a few API calls. Cross-character tracking requires saving lockout data on `PLAYER_LOGOUT` and displaying it per-character in the tooltip, following the established Bags/Reagents cross-character pattern.

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
- #3 M+ Affix Widget -- under 60 lines, simplest new widget
- #7 Warband Gold Tracker -- reuses existing Bags data layer entirely
- #8 Secondary Stats -- simple accessor APIs, no state management
- #14 Bags low-space warning -- single conditional added to existing code
- #19 SessionStats gold-per-hour -- under 20 lines of tooltip additions

**Highest strategic value:**
- #2 Talent Loadout -- leverages TalentManager and TalentReminder investment
- #12 Waypoint Distance -- leverages new Coordinates module from v1.13
- #18 Currency configurable list -- eliminates recurring seasonal maintenance
- #16 Hearthstone selection menu -- addresses common user desire for toy selection
- #13 Class Resource -- fills a combat information gap, unique among widgets
