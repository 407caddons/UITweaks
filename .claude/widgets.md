# Widget Ideas & Improvements - LunaUITweaks

**Date:** 2026-02-17
**Current Widgets (27):** Time, FPS, Bags, Spec, Durability, Combat, Friends, Guild, Group, Teleports, Keystone, WeeklyReset, Coordinates, BattleRes, Speed, ItemLevel, Volume, Zone, PvP, MythicRating, Vault, DarkmoonFaire, Mail, PullCounter, Hearthstone, Currency

**New Standalone Module (not a widget):** MplusTimer -- full M+ timer overlay with +1/+2/+3 bars, death count, forces tracking, boss objectives, affix display, and auto-slot keystone

Ease ratings: **Easy** (few hours), **Medium** (1-2 days), **Hard** (3+ days)

---

## Previous Suggestions - Implementation Status

The following ideas from the previous review have been implemented or superseded:

- **Loot Spec Widget** - DONE. The Spec widget shows both active spec and loot spec icons side by side. Left-click opens spec switch menu, right-click opens loot spec menu.
- **Party Role Widget** - DONE. The Group widget displays tank/healer/DPS counts with role icons (atlas markup) and total member count. Also includes ready check tracking and raid sorting.
- **Great Vault Progress Widget (Enhanced)** - DONE. The Vault widget shows per-row progress (Mythic+, Raid, Delves) with slot-by-slot completion in the tooltip and a "Vault: X/9" summary on the widget face.
- **FPS Widget - Add Latency Display** - DONE. The FPS widget displays "XX ms / XX fps" on the face. The tooltip includes home/world latency, jitter calculation (30-sample rolling window), bandwidth in/out, and full addon memory breakdown (top 30 addons, color-coded by usage).
- **Durability Widget - Equipment Breakdown** - DONE. The Durability tooltip shows per-slot durability percentages with item links, color-coded (green/yellow/red), plus cached repair cost from last vendor visit.
- **Mythic+ Death Counter Widget** - SUPERSEDED. The new `MplusTimer.lua` module (standalone, not a widget) includes a full death counter with time penalty display (`C_ChallengeMode.GetDeathCount()`), making a separate death counter widget redundant during M+ runs. The PullCounter widget covers encounter tracking outside of M+.

Previously suggested ideas that remain unimplemented and are **carried forward** below where still relevant (some have been refreshed or merged with new ideas).

---

## New Widget Ideas

### 1. Profession Cooldowns Widget
Display active profession cooldowns (transmutes, daily crafts, weekly knowledge). Shows icon for primary profession and a countdown for the nearest cooldown. Tooltip lists all tracked profession cooldowns with time remaining. Could integrate with the Reagents module to show cross-character cooldown data if expanded.
- **Ease:** Medium
- **Rationale:** Requires scanning profession spell cooldowns via `C_TradeSkillUI` and `C_Spell.GetSpellCooldown`. The tricky part is building a reliable list of cooldown-gated recipes across all professions since there is no single API for "all profession cooldowns." Knowledge point weekly resets add another layer that requires tracking quest IDs.

### 2. Instance Lockout Widget
Show the number of active instance lockouts (raid saves, dungeon lockouts). The widget face displays "Locks: 3". The tooltip lists each saved instance with boss kill progress (e.g., "Nerub-ar Palace 6/8 Heroic"). Click to open the raid info panel.
- **Ease:** Easy-Medium
- **Rationale:** Uses `GetNumSavedInstances()` and `GetSavedInstanceInfo()` which are straightforward APIs. Main work is formatting the tooltip nicely and handling edge cases for legacy vs current tier lockouts. Also should include `GetNumSavedWorldBosses()` for completeness.

### 3. Talent Loadout Widget
Display the name of the current active talent loadout. Tooltip shows all saved loadouts with a checkmark on the active one. Click to open the talent frame. Could show a warning icon (colored text) when current talents do not match any saved loadout, tying into the existing TalentReminder module's `CompareTalents()` function.
- **Ease:** Easy-Medium
- **Rationale:** Uses `C_ClassTalents.GetActiveConfigProfile()` and related APIs. Integration with TalentReminder for mismatch detection is optional but adds value. The loadout name display itself is simple.

### 4. M+ Affix Widget
Show the current week's Mythic+ affixes as compact icon+text or just names. The widget face shows the primary affix name or a compact abbreviation. Tooltip shows all active affixes with their full descriptions. This is informational even when not inside a dungeon, useful for planning the week's keys. Note: the MplusTimer module now shows affixes during active M+ runs, but this widget would be visible all the time as a quick reference.
- **Ease:** Easy
- **Rationale:** `C_MythicPlus.GetCurrentAffixes()` returns the affix IDs, and `C_ChallengeMode.GetAffixInfo()` provides name, description, and icon. Very straightforward API with minimal state management.

### 5. XP / Reputation Widget
For non-max-level characters, show current XP progress as a percentage with rested XP indicator. For max-level characters, show the currently watched reputation faction name and standing progress. Right-click to cycle through tracked reputations. A compact alternative to the default bars.
- **Ease:** Medium
- **Rationale:** XP portion is simple (`UnitXP`, `UnitXPMax`, `GetXPExhaustion`). The reputation portion requires `C_Reputation.GetWatchedFactionData()` and handling the various standing types (Renown, Paragon, Friendship, standard). Multiple rep systems in The War Within add complexity.

### 6. World Boss / Weekly Event Widget
Show the current week's world bosses and whether they have been killed, plus the active weekly bonus event (Timewalking, PvP Brawl, Pet Battle week, etc.). Tooltip lists each world boss with killed/available status. Click could open the adventure guide.
- **Ease:** Medium
- **Rationale:** World boss completion is tracked via quest IDs that rotate weekly. The active weekly event can be determined via `C_DateAndTime` calendar APIs or holiday detection. Requires maintaining a mapping of boss names to quest IDs that must be updated each expansion tier.

### 7. Session Stats Widget
Track session-level statistics: time played this session, gold earned/spent delta, items looted count, deaths count. The widget face shows session duration. Tooltip expands to all tracked stats. Right-click to reset the session.
- **Ease:** Medium
- **Rationale:** Session time is trivial (track login `GetTime()`). Gold delta requires comparing `GetMoney()` at session start vs now (the Bags widget already saves gold data, so patterns can be borrowed). Deaths can be tracked via `PLAYER_DEAD`. No single complex API, but aggregating multiple data sources takes work.

### 8. Calendar / Holiday Widget
Show the next upcoming WoW holiday or calendar event with a countdown. During active holidays (Brewfest, Hallow's End, etc.), show the holiday name in themed color. Tooltip shows the next 3-5 upcoming events. Click to open the calendar. Complements the existing DarkmoonFaire widget but covers all holidays.
- **Ease:** Easy-Medium
- **Rationale:** Uses `C_Calendar` API to scan upcoming events. The main work is loading the calendar addon on demand and parsing event data. Holiday detection via `C_Calendar.GetNumDayEvents()` and iterating is well-documented. The DarkmoonFaire widget already calculates DMF timing, so this widget would generalize that pattern.

### 9. Buff/Flask Reminder Widget
Show whether the player currently has a well-fed buff, flask/phial, and augment rune active. Display as three small colored indicators (green = active, red = missing, gray = N/A). Tooltip shows the specific buff names and remaining durations. Useful for raid preparation at a glance.
- **Ease:** Medium
- **Rationale:** Requires scanning player buffs with `C_UnitAuras.GetAuraDataByIndex()` and matching against known buff categories (food, flask, augment rune). The challenge is maintaining accurate lists of current-tier buff spell IDs. Category-based detection via aura source type or tooltip scanning can help future-proof it, but no perfect heuristic exists.

### 10. Warband Bank / Gold Tracker Widget
Show total gold across all characters (from Bags widget's saved data) plus Warband Bank balance in a dedicated always-visible widget. The widget face shows the combined total in a compact gold format. Tooltip breaks down per-character gold sorted by amount. Click to toggle between showing combined total, current character only, or Warband Bank only.
- **Ease:** Easy
- **Rationale:** The Bags widget already tracks cross-character gold (`UIThingsDB.widgets.bags.goldData`) and fetches `C_Bank.FetchDepositedMoney` for Warband Bank. This widget would reuse that same data but present it as a standalone always-visible gold tracker separate from bag slot info. Minimal new API work needed.

### 11. Delve Tracker Widget
Show current Brann companion level and weekly delve completion progress. The widget face displays "Delves: X/Y" for weekly vault progress. Tooltip shows Brann's level, XP to next level, and which delve tiers have been completed this week. Relevant for The War Within seasonal content.
- **Ease:** Medium
- **Rationale:** Delve weekly progress is partially available via `C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.World)` (already used by the Vault widget). Brann's companion level may require specific currency or quest log lookups. The APIs are less well-documented than M+ or raid APIs, requiring some reverse-engineering.

### 12. Casting Speed / Secondary Stats Widget
Display current haste percentage in real-time. The widget face shows "Haste: XX.X%". Tooltip expands to show all secondary stats (crit, mastery, versatility, haste) with their percentages and ratings. Could also show primary stat (Intellect/Agility/Strength) value. Useful for players tracking stat breakpoints or proc effects.
- **Ease:** Easy
- **Rationale:** `GetHaste()`, `GetCritChance()`, `GetMasteryEffect()`, `GetCombatRatingBonus()`, `GetVersatilityBonus()` provide all needed data. These are simple accessor APIs with no state management. Updates on `UNIT_STATS` or `COMBAT_RATING_UPDATE` events.

### 13. Personal Loot Tracker Widget
Track items looted during the current session with item level and quality. The widget face shows "Loot: X items". Tooltip lists the last 10-15 items received with their item level and quality color. Right-click to clear the session log. Useful during farm sessions or M+ to see what dropped.
- **Ease:** Medium
- **Rationale:** Requires hooking into `CHAT_MSG_LOOT` events and parsing item links. Storing item data (link, ilvl, quality) in a session table. The existing Loot.lua module already handles similar toast logic with item link parsing, so patterns can be reused. Tooltip formatting with item links requires care for proper coloring.

### 14. Minimap Toggle Widget
A compact widget that toggles the minimap on and off with a click, and shows minimap-related info in the tooltip (tracking type, north-locked vs rotating, current zoom level). Right-click could cycle through minimap tracking options (herbs, ore, etc.). Useful for players who hide the minimap to save screen space but want quick access.
- **Ease:** Easy
- **Rationale:** `Minimap:Hide()`/`Minimap:Show()` are simple calls (need combat lockdown check if minimap uses secure frames). `C_Minimap.GetTrackingInfo()` provides tracking data. The MinimapCustom module already interacts with minimap properties, so there is existing code to reference.

### 15. Addon Communication Status Widget
Show the status of addon communication channels used by LunaUITweaks. The widget face shows how many group members have the addon installed (leveraging AddonVersions data). Tooltip shows each group member's addon version, latency of last comm message, and whether keystone data has been synced. Click to broadcast a version check.
- **Ease:** Easy-Medium
- **Rationale:** The AddonVersions module already maintains `playerData` with version info, keystone data, and online status. The Keystone and MythicRating widgets already display party keystone info from this data. This widget would surface the communication health itself -- useful for debugging sync issues and knowing who in the group is running the addon.

---

## Improvements to Existing Widgets

### 16. Bags Widget - Reagent Bag & Profession Bag Breakdown
Add reagent bag and profession bag free slot counts to the tooltip, showing a breakdown by bag type (regular, reagent, profession). Add a color warning when total free space drops below a configurable threshold (e.g., fewer than 5 free slots shows the count in red on the widget face). The face text could optionally show "Bags: 12 (R:8)" format.
- **Ease:** Easy
- **Rationale:** `C_Container.GetContainerNumFreeSlots()` already returns bag type as a second value. Iterating profession and reagent bags (bag IDs 5+ and the reagent bag) is straightforward. Minor enhancement to existing tooltip code. The Bags widget currently only shows total free slots across all regular bags.

### 17. Keystone Widget - Weekly Best & Vault Integration
In the tooltip, add the player's weekly best run (if different from season best) and a summary line showing total M+ runs completed this week for vault progress. Integrate the `C_WeeklyRewards.GetActivities()` data to show "Vault M+: 2/8" alongside the keystone info. This turns the Keystone widget into a complete M+ dashboard. Note: the Keystone widget already shows rating gain estimates and party keystones via AddonVersions; this adds the weekly progress layer.
- **Ease:** Easy-Medium
- **Rationale:** `C_MythicPlus.GetWeeklyBestForMap()` gives weekly best. Vault progress data from `C_WeeklyRewards.GetActivities()` is already used by the Vault widget and can be referenced here. The Keystone widget already has a rich tooltip with best run comparison and party keystones, so this is an incremental addition.

### 18. Hearthstone Widget - Multi-Hearth Selection Menu
Add a right-click context menu that lets the player choose a specific hearthstone toy to use (instead of random). Show owned hearthstone toys in a list with their names and icons. The current random behavior becomes the default left-click, while right-click gives manual selection. Persist the selected preference in `UIThingsDB.widgets.hearthstone.preferredToy`. The widget already builds `ownedHearthstones` list, so the data is available.
- **Ease:** Easy-Medium
- **Rationale:** The `ownedHearthstones` list is already built in the Hearthstone widget via `BuildOwnedList()`. Adding a `MenuUtil.CreateContextMenu` right-click handler (same pattern as the Spec widget) that sets the secure button attribute to a specific toy ID is straightforward. Needs combat lockdown check for attribute changes since the widget uses `SecureActionButtonTemplate`.

### 19. Group Widget - Instance Progress in Tooltip
In the Group widget tooltip, add a section showing the current dungeon or raid progress (bosses killed/total) when inside an instance. For M+ runs, show the current timer status (ahead/behind par) and death count. This turns the Group widget into a one-stop group information hub. Note: the MplusTimer module now provides a full overlay during M+ runs, but a compact summary in the Group tooltip is still useful for players who prefer minimal UI.
- **Ease:** Medium
- **Rationale:** Instance progress can be fetched via `GetInstanceInfo()` and `C_ScenarioInfo.GetCriteriaInfo()` for scenario bosses. M+ timer data from `C_ChallengeMode` APIs and `GetWorldElapsedTime()`. The complexity is aggregating different data sources (dungeon vs raid vs M+) into a coherent tooltip section without duplicating what MplusTimer already shows.

### 20. Currency Widget - Configurable Currency List
Allow users to choose which currencies to track instead of using the hardcoded `DEFAULT_CURRENCIES` list. Add a configuration option where users can search for and add/remove currencies by name. The widget then displays and tracks only selected currencies. Currently the Currency widget uses a static list of TWW Season 1 currencies that becomes outdated each season.
- **Ease:** Medium
- **Rationale:** Requires adding a config UI for currency selection, likely using `C_CurrencyInfo.GetCurrencyListSize()` and `C_CurrencyInfo.GetCurrencyListInfo()` to build a searchable list. The data storage is simple (array of currency IDs in `UIThingsDB.widgets.currency.trackedCurrencies`), but the search/selection UI adds implementation time. A simpler alternative: auto-detect currencies marked "show on backpack" via `info.isShowInBackpack` (the Bags widget tooltip already does this).

---

## Widget Framework Improvements

### A. Widget Groups / Snap-to-Grid
Allow grouping multiple widgets into a single horizontal or vertical bar that moves as one unit. When dragging widgets near each other while unlocked, show snap indicators. Grouped widgets share a single drag handle and maintain consistent spacing. The anchor system (docking widgets to custom Frames) partially addresses this, but a more intuitive drag-and-snap system between widgets themselves would be more user-friendly.
- **Ease:** Hard
- **Impact:** Major UX improvement for organizing many widgets. The existing anchor system in `Widgets.lua` (`UpdateAnchoredLayouts`) handles docking to named anchor frames, but widget-to-widget snapping is not supported.

### B. Widget Visibility Conditions
Allow widgets to auto-show/hide based on conditions: in combat, in instance, in group, in city, specific zone, or solo only. Uses the existing state driver pattern or event-based toggling. For example, BattleRes only shows in M+/raid, Group only shows when grouped, PullCounter only shows in instances. Several widgets already have context-dependent display (Combat shows "In Combat"/"Out of Combat", BattleRes shows "BR" when not in relevant content), but a generalized per-widget condition system would reduce clutter significantly.
- **Ease:** Medium
- **Impact:** Significant clutter reduction. A generalized system with per-widget condition dropdowns in the config panel would be powerful. Could use `RegisterStateDriver` for combat-based conditions and event handlers for group/instance conditions.

### C. Per-Widget Font Override
Allow individual widgets to override the global font family, size, and color. Each widget's config sub-table already exists in `UIThingsDB.widgets[key]`. Adding optional `font`, `fontSize`, `fontColor` fields that fall back to the global when nil would let users emphasize important widgets (e.g., larger keystone text, different color for combat state). The `Widgets.UpdateVisuals()` function already applies global font settings per-widget and would need a simple fallback check.
- **Ease:** Easy-Medium
- **Impact:** Medium. Enables visual hierarchy where important widgets stand out from informational ones. Implementation requires modifying `UpdateVisuals()` to check `db[key].font or db.font` for each style property.

### D. Widget Tooltip Anchor Override
Allow per-widget tooltip anchor position instead of always using the smart anchor (above/below based on screen half from `SmartAnchorTooltip`). Some users may want tooltips always to the right or always above, especially for widgets docked to screen edges where the auto-detection picks the wrong side.
- **Ease:** Easy
- **Impact:** Small but appreciated QOL for users with specific UI layouts. Would add an optional `tooltipAnchor` field to each widget's config that overrides `SmartAnchorTooltip` behavior.

### E. Widget Click-Through Mode
Add a per-widget option to make the widget click-through (non-interactive) when locked. This prevents accidental clicks on widgets placed near action areas. The widget still displays information but passes all mouse events through to whatever is beneath it. Currently locked widgets disable movability but still capture mouse events for tooltips and clicks.
- **Ease:** Easy
- **Impact:** Medium for users who place widgets near their action bars or unit frames. Implementation via `EnableMouse(false)` when locked with this option set. Trade-off: disables tooltip display too, so this needs a toggle between "show tooltip on hover" and "fully transparent to mouse." Could use a modifier key (e.g., Alt+hover shows tooltip even in click-through mode).
