# LunaUITweaks Code Review

**Date:** 2026-02-16
**Reviewer:** Claude (Automated)
**Scope:** All 63 `.lua` files across root, `widgets/`, `config/`, and `config/panels/` directories

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Performance Issues](#performance-issues)
3. [Memory Leak Risks](#memory-leak-risks)
4. [Potential Bugs and Edge Cases](#potential-bugs-and-edge-cases)
5. [Code Readability Concerns](#code-readability-concerns)
6. [Optimization Suggestions](#optimization-suggestions)
7. [Per-File Findings](#per-file-findings)
8. [Summary of Priority Actions](#summary-of-priority-actions)

---

## Executive Summary

LunaUITweaks is a well-structured addon with a consistent module pattern, good use of event-driven architecture, and thoughtful combat-safe frame positioning. The codebase demonstrates strong WoW API knowledge, particularly in the ActionBars three-layer positioning system, the Kick module's party interrupt watcher, and the widget framework's event-caching pattern.

**Strengths:**
- Consistent module registration pattern across files
- Event-driven caching in widgets (update cached text on events, display cached text on tick) is the correct approach
- Frame pooling in Loot.lua, Frames.lua, Misc.lua (SCT), Currency.lua, and Teleports.lua
- Combat-safe frame positioning in ActionBars.lua is expertly implemented
- Proper enable/disable lifecycle for widgets via `ApplyEvents`
- Clean addon communication bus with rate limiting and dedup (AddonComm.lua)
- Kick.lua properly prunes departed group members' data via `validGUIDs` loop

**Areas for improvement:**
- Several modules create temporary tables on hot paths (tooltip OnEnter, per-tick handlers)
- Config panels are eagerly created and have heavy code duplication
- A few modules maintain lookup tables that could grow over long sessions
- Some event registrations are broader than necessary
- Core.lua `Log()` allocates a new table on every call

---

## Performance Issues

### 1. Core.lua: Log() Creates Table Every Call

**Severity:** Low-Medium
**Lines:** ~52-57

The `colors` table is created fresh on every `Log()` call. While Log is not called on hot paths currently, this is wasteful and would become a problem if logging were used more extensively.

```lua
function addonTable.Core.Log(module, msg, level)
    local colors = {  -- NEW TABLE EVERY CALL
        [0] = "888888",
        [1] = "00FF00",
        [2] = "FFFF00",
        [3] = "FF0000"
    }
```

**Recommendation:** Move `colors` to module-level scope (define it once outside the function).

### 2. Coordinates Widget: Per-Tick Map API Calls (widgets/Coordinates.lua)

**Severity:** Medium
**Lines:** UpdateContent function

The Coordinates widget calls `C_Map.GetBestMapForUnit("player")` and `C_Map.GetPlayerMapPosition()` every tick via `UpdateContent` (called by the 1-second widget ticker). `GetPlayerMapPosition` creates a new `Vector2DMixin` object each call, producing GC pressure.

**Recommendation:** This is inherent to the feature (coordinates must update as the player moves). Consider throttling to every 2 seconds or only updating when the player is moving.

### 3. Speed Widget: Dual Update Paths (widgets/Speed.lua)

**Severity:** Low
**Lines:** ~42-50

The Speed widget hooks `OnUpdate` with a 0.5s throttle in addition to the 1-second widget ticker. Both `HookScript("OnUpdate")` and the widget ticker call the same refresh function.

**Recommendation:** Consider using only one update path. If 0.5s is needed for skyriding, disable the standard 1-second ticker for this widget.

### 4. Keystone Widget: Bag Scanning Every Tick (widgets/Keystone.lua)

**Severity:** Medium
**Lines:** `GetPlayerKeystone()` function

`GetPlayerKeystone()` iterates all bag slots every time `UpdateContent` is called (every 1 second). The `BAG_UPDATE` handler also fires `UpdateContent` twice (once immediately, once after 0.5s delay).

**Recommendation:** Cache the keystone info and only refresh on `BAG_UPDATE_DELAYED`. Remove the scan from `UpdateContent` and rely solely on event-based refresh.

### 5. ObjectiveTracker: Frequent Table Creation (ObjectiveTracker.lua)

**Severity:** Medium
**Lines:** Multiple locations across `RenderQuests`, `RenderWorldQuests`, `RenderAchievements`

The tracker creates new tables for sorting data on each update cycle (`sortedQuests`, `zoneGroups`, `sortedZones`, etc.). With `UPDATE_THROTTLE_DELAY = 0.1s`, these allocations can happen rapidly during quest updates.

**Recommendation:** Pre-allocate and `wipe()` reusable scratch tables at the module level. This pattern already exists with `displayedIDs` and `activeWQs` but is not used consistently for sort tables.

### 6. DarkmoonFaire Widget: Date Arithmetic Every Tick (widgets/DarkmoonFaire.lua)

**Severity:** Low
**Lines:** `UpdateContent` calls `RefreshDMFCache()` which calls `GetDMFInfo()`

`GetDMFInfo()` calls `time()`, `date("*t", ...)` multiple times, creating temporary tables each tick. This happens every second when the widget is enabled.

**Recommendation:** Cache the DMF active state and next transition timestamp. Only recalculate when the transition time has passed.

### 7. FPS Widget: Double Sort (widgets/FPS.lua)

**Severity:** Low
**Lines:** OnEnter handler

`addonMemList` is sorted in `RefreshMemoryData()` and then sorted again in the `OnEnter` handler. The second sort is redundant if no data changed between the last refresh and the hover.

**Recommendation:** Remove the sort in `OnEnter` since `RefreshMemoryData()` already sorts.

### 8. ChatSkin.lua: HighlightKeywords Per-Call Table (ChatSkin.lua)

**Severity:** Low-Medium
**Lines:** ~131-140

`HighlightKeywords()` creates a new `placeholders` table on every call. This function is called via `ChatFrame_AddMessageEventFilter` for every incoming chat message when keyword highlighting is enabled. With active chat, this creates significant GC pressure.

```lua
local function HighlightKeywords(msg)
    local placeholders = {}  -- NEW TABLE EVERY CHAT MESSAGE
    local placeholderIdx = 0
```

Note: The `FormatURLs()` function in the same file correctly reuses a module-level table.

**Recommendation:** Move `placeholders` to module level and `wipe()` it at the start of each call, matching the pattern used by `FormatURLs()`.

### 9. Combat.lua: Weapon Buff Polling (Combat.lua)

**Severity:** Low
**Lines:** Weapon buff ticker (~10-second interval)

The 10-second weapon buff polling ticker runs continuously once started, even outside instances where weapon buffs are irrelevant.

**Recommendation:** Only start the weapon buff ticker when `reminders.weaponBuff` is enabled AND the player is in a group/instance. Stop it when conditions no longer apply.

### 10. Config Panels: Eager Initialization (config/panels/*.lua)

**Severity:** Low-Medium
**Lines:** All 16 panel files

All config panels create their full UI (dozens of frames, sliders, checkboxes, font strings) at initialization time, even if the user never opens that particular panel. This front-loads both memory and frame count.

**Recommendation:** Consider lazy-loading panels on first show. The current approach creates all 16 panels of UI elements when `/luit` is first invoked.

### 11. Teleports Widget: Full Spell Lookup on Panel Open (widgets/Teleports.lua)

**Severity:** Low
**Lines:** `ShowMainMenu()` function

When the panel opens, `ShowMainMenu()` calls `IsSpellKnownByName()` for every spell in `TELEPORT_DATA` and `PORTAL_DATA`, each calling `C_Spell.GetSpellInfo()` and `IsPlayerSpell()`.

**Recommendation:** Cache the known spell results alongside the spellbook scan cache and invalidate them together on `SPELLS_CHANGED`.

### 12. Loot.lua: GetItemInfo Retry Closures (Loot.lua)

**Severity:** Low
**Lines:** Toast creation logic

When `C_Item.GetItemInfo` returns nil for uncached items, the module schedules retry closures. During AoE loot with many items, this creates GC pressure from multiple closure allocations.

**Recommendation:** Use a shared retry mechanism or pool retry functions.

---

## Memory Leak Risks

### 1. ObjectiveTracker: questLineCache Grows Unbounded (ObjectiveTracker.lua)

**Severity:** Medium
**Lines:** ~768

`questLineCache` is keyed by questID with 30-second TTL entries, but expired entries are never removed. While individual entries are small, over a long session tracking many quests (especially world quests with high questID churn), this table grows without bound.

```lua
local questLineCache = {} -- [questID] = { str, expiry }
```

**Recommendation:** Add a periodic sweep to remove expired entries, or clear the entire cache on zone change.

### 2. ObjectiveTracker: prevObjectiveState / prevQuestComplete (ObjectiveTracker.lua)

**Severity:** Low-Medium
**Lines:** ~300-301

These tables are keyed by questID. Cleanup happens on `QUEST_REMOVED` (confirmed in code at line ~1880), which is correct. However, quests that remain in the quest log but are no longer actively tracked still accumulate entries. Over a long session, the number of unique questIDs seen can grow.

**Recommendation:** The existing `QUEST_REMOVED` cleanup is good. Consider also clearing these when the player's quest log is empty or on `/reload`.

### 3. AddonComm.lua: recentMessages Dedup Table (AddonComm.lua)

**Severity:** Low
**Lines:** recentMessages table

The `recentMessages` table is pruned when new messages arrive, but entries are only removed when a new message with the same key arrives. Entries for one-time messages persist indefinitely.

**Recommendation:** Add a periodic sweep (e.g., every 60 seconds) to clear stale entries older than `DEDUP_WINDOW`.

### 4. ChatSkin.lua: URL Link Storage (ChatSkin.lua)

**Severity:** Low
**Lines:** URL storage mechanism

The custom `lunaurl:` hyperlink system stores URLs. Over a very long session with URL-heavy chat, this data accumulates without bound.

**Recommendation:** Limit stored URLs to a reasonable cap (e.g., 200) and evict the oldest when exceeded.

### 5. Bags Widget: goldData Cross-Character (widgets/Bags.lua)

**Severity:** Low
**Lines:** `UIThingsDB.widgets.bags.goldData`

Gold data for all characters persists in saved variables indefinitely. If a character is deleted, its data remains.

**Recommendation:** This is a minor concern. The existing Shift-Right-Click to clear all data is sufficient. Could add per-character removal in the future.

### 6. Reagents.lua: Cross-Character Data Persistence (Reagents.lua)

**Severity:** Low
**Lines:** `LunaUITweaks_ReagentData`

Similar to goldData, reagent data for deleted characters persists. The config panel provides character deletion, which is the correct approach.

**No action needed** - already handled via config UI.

---

## Potential Bugs and Edge Cases

### 1. ObjectiveTracker: Super-Track Restore Race Condition (ObjectiveTracker.lua)

**Severity:** Medium
**Lines:** ~305-310

The super-track restore logic saves `savedSuperTrackedQuestID` when a world quest is super-tracked, then restores it when the WQ is removed. If the player manually changes super-track between these events, the restored quest may not be what the player expects.

**Recommendation:** Clear `savedSuperTrackedQuestID` when the player manually changes super-track via the tracker UI.

### 2. ActionBars: Edit Mode Interaction (ActionBars.lua)

**Severity:** Medium
**Lines:** Edit mode hooks (~line 800-900)

The edit mode release/reclaim pattern (`SafeSetParent`) strips `OnHide` to prevent crashes. If Blizzard changes the edit mode system, the stripped handler won't fire, potentially causing state desync.

**Recommendation:** Already well-documented in code. Add a comment noting this should be reviewed on major patches (12.1, etc.).

### 3. MinimapCustom.lua: Clock Ticker Runs Forever (MinimapCustom.lua)

**Severity:** Low
**Lines:** `C_Timer.NewTicker(1, UpdateClock)`

The clock ticker runs every second unconditionally once started, even if the custom minimap is disabled after loading.

**Recommendation:** Only start the ticker when `UIThingsDB.minimap.enabled` is true, and cancel it when disabled.

### 4. Hearthstone Widget: Cooldown Display Mismatch (widgets/Hearthstone.lua)

**Severity:** Low
**Lines:** `GetCooldownRemaining()` vs `PreClick`

The cooldown check uses `GetAnyHearthstoneID()` (first owned), but `PreClick` sets a random one. If the random hearthstone has a different cooldown than the first, the displayed cooldown may not match.

**Recommendation:** Track which hearthstone was last set on the secure button and check that specific one's cooldown, or show "Ready" only when any hearthstone is off cooldown.

### 5. CastBar.lua: Empower Spell Stage Calculation (CastBar.lua)

**Severity:** Low
**Lines:** Empower stage rendering

The empower stage calculation divides the cast bar into equal segments. If Blizzard introduces spells with unequal stage durations, this would be inaccurate.

**Recommendation:** Check if the API provides per-stage duration data and use it if available.

### 6. Vendor.lua: Guild Repair Fallback (Vendor.lua)

**Severity:** Low
**Lines:** Auto-repair logic

If guild repair has insufficient funds, the code falls back to personal repair. There's no user feedback about which was used.

**Recommendation:** Log when guild repair fails and personal funds are used instead.

### 7. TalentReminder: Localized Zone Keys (TalentReminder.lua)

**Severity:** Low
**Lines:** `GetCurrentZone()` function

Zone keys use `GetSubZoneText()` which returns localized strings. Reminders saved in one locale won't trigger in another. This is inherent to the zone-based approach.

**Recommendation:** Document this limitation. Consider mapID-based keys for future versions.

### 8. PullCounter Widget: Session-Only Data (widgets/PullCounter.lua)

**Severity:** Info
**Lines:** `sessionData` table

Pull counter data is session-only (not persisted). This is likely intentional but worth noting -- data is lost on reload/disconnect.

**Recommendation:** No action needed if intentional. Consider offering optional persistence in `UIThingsDB` for raid nights.

### 9. Currency Widget: Hardcoded Currency IDs (widgets/Currency.lua)

**Severity:** Medium
**Lines:** `DEFAULT_CURRENCIES` table (~line 5-13)

The currency IDs are hardcoded for TWW Season 1. When a new season releases, these will become stale (showing old currencies instead of current ones).

**Recommendation:** Add season-detection logic or make the currency list user-configurable via the config panel.

### 10. Group Widget: Fragile Party Unit Mapping (widgets/Group.lua)

**Severity:** Low
**Lines:** OnEnter tooltip handler

The party/raid unit mapping logic has a fallback that assumes the player is the last member in the unit enumeration. If `GetRaidRosterInfo` returns nil for some indices, the fallback may misidentify players.

**Recommendation:** Use `UnitName` with the constructed unit to verify before displaying.

---

## Code Readability Concerns

### 1. Config Panel Code Duplication

Every config panel follows the exact same pattern: create scroll frame, create checkboxes, create sliders, wire to `UIThingsDB`. The color picker pattern (with `prevR/prevG/prevB` and `swatchFunc/cancelFunc`) is copy-pasted many times.

**Recommendation:** The `Helpers.CreateColorSwatch()` function exists and is used in some panels, but many panels still manually create color pickers. Migrate all panels to use the helper consistently. Consider adding `Helpers.CreateCheckbox()` and `Helpers.CreateSlider()` to further reduce boilerplate.

### 2. Large Functions in ObjectiveTracker.lua

`RenderQuests()` and `UpdateContent()` are 200+ lines each. These are difficult to follow and maintain.

**Recommendation:** Extract sub-functions for zone grouping, sorting, and individual quest rendering.

### 3. Magic Numbers

Several files use magic numbers without explanation:
- `Combat.lua`: Flask aura spell IDs (e.g., `432021`), consumable spell IDs
- `ObjectiveTracker.lua`: Sound IDs (`6199`, `6197`)
- `Kick.lua`: Interrupt spell IDs -- well-structured with names, which is the right approach

**Recommendation:** Add descriptive comments for spell/sound IDs in Combat.lua and ObjectiveTracker.lua, matching the Kick.lua pattern.

### 4. Inconsistent Error Handling

Some modules use `addonTable.Core.Log()`, while others use `print()` with colored prefixes. The logging system exists but is not universally adopted.

**Recommendation:** Migrate all `print()` calls to use `Core.Log()` for consistent formatting and log-level filtering.

### 5. Global Name Pollution in Config Panels

Config panels create globally-named frames (e.g., `"UIThingsTrackerEnableCheck"`, `"UIThingsLootShowAll"`). The sheer number of global names is high.

**Recommendation:** Where possible, use `nil` for frame names (anonymous frames). Global names are only needed for frames referenced by name from templates or `_G`.

### 6. Inconsistent Module Registration

Most modules register on `addonTable` with uppercase names (`addonTable.ObjectiveTracker`). However, `MinimapCustom.lua` does not register a module table at all.

**Recommendation:** Document the convention and ensure all modules follow it.

### 7. Misc.lua Multi-Feature File

`Misc.lua` contains several unrelated features: personal order alerts, AH expansion filter, SCT, auto-invite, quick destroy, and more.

**Recommendation:** Consider splitting into separate files for clarity (e.g., `SCT.lua`, `PersonalOrders.lua`).

---

## Optimization Suggestions

### 1. Localize Frequently Used Globals

Several modules access global functions repeatedly without localizing:
- `string.format` (used extensively in tooltip builders)
- `math.floor` (used in many `OnValueChanged` handlers)
- `GetTime()` (used in update loops)
- `UnitName`, `UnitClass`, `UnitGUID` (used in group iteration)

**Recommendation:** Add `local format, floor = string.format, math.floor` at the top of files that use these heavily. This is a minor optimization but standard WoW addon practice.

### 2. Widget Ticker Optimization (widgets/Widgets.lua)

The 1-second widget ticker calls `UpdateContent()` on every enabled widget. For purely event-driven widgets (Combat, Friends, Guild, Zone, ItemLevel, Mail, PvP), the ticker just re-sets the same cached text.

**Recommendation:** Add an `isEventDriven` flag to event-cached widgets and skip them in the ticker. Only call `UpdateContent` on widgets that need periodic updates (Time, FPS, Speed, Coordinates, BattleRes, WeeklyReset, DarkmoonFaire, PullCounter, Keystone, Volume, Hearthstone).

### 3. Pre-format Static Strings

Some tooltip handlers recreate the same formatted strings on every hover:
- Currency widget calls `CreateTextureMarkup()` on every hover for each currency
- Multiple widgets format the same static label strings each time

**Recommendation:** Cache formatted icon/markup strings at module level. The Group widget already does this well with its cached atlas markup strings.

### 4. Consolidate Widget Event Frames

Each widget creates a separate event frame for its events. For widgets with simple needs (just `PLAYER_ENTERING_WORLD`), this adds to the frame count unnecessarily.

**Recommendation:** For simple event-driven widgets, use the widget frame itself for events (the Combat widget demonstrates this). This could reduce total frame count by ~15.

### 5. Reduce Config Panel Frame Count

Config panels create dozens of frames each. Consider:
- Lazy-loading panels on first tab click
- Using anonymous frames (nil name) where possible
- Sharing scroll frame infrastructure

**Recommendation:** Lazy-load is the highest-impact change here.

---

## Per-File Findings

### Core.lua
- **Good:** `ApplyDefaults()` correctly handles color tables as leaf values.
- **Good:** `SafeAfter()` wraps in pcall for safety.
- **Issue:** `Log()` creates a new `colors` table on every call (see Performance #1).
- **Minor:** The `DEFAULTS` table is ~300 lines. Consider splitting defaults by module for maintainability.

### ObjectiveTracker.lua (2116 lines)
- **Good:** Item pooling with `AcquireItem`/`ReleaseItems`.
- **Good:** Throttled updates with `ScheduleUpdateContent`.
- **Good:** `prevObjectiveState`/`prevQuestComplete` cleaned on `QUEST_REMOVED`.
- **Issue:** `questLineCache` grows unbounded (see Memory Leaks #1).
- **Issue:** Sort tables recreated each update cycle (see Performance #5).
- **Minor:** `SecureActionButtonTemplate` for quest items is well-implemented.

### ActionBars.lua (1538 lines)
- **Good:** Three-layer combat-safe positioning is expertly implemented.
- **Good:** `PatchMicroMenuLayout` and `SafeSetParent` handle edge cases well.
- **Good:** Conflict detection for Dominos/Bartender4/ElvUI.
- **Good:** `originalBarPositions`/`originalButtonPositions` cleared on reload-in-combat.

### Kick.lua (1595 lines)
- **Good:** `RegisterUnitEvent` for party watchers (efficient per-unit registration).
- **Good:** Addon communication for cross-client interrupt sync.
- **Good:** `RebuildPartyFrames()` correctly prunes `knownSpells` and `interruptCooldowns` for departed GUIDs via `validGUIDs` loop (lines 1056-1088).
- **Minor:** The `INTERRUPT_SPELLS` database is comprehensive and well-structured.

### TalentReminder.lua (1509 lines)
- **Good:** Priority system for zone-specific vs general reminders.
- **Good:** `CompareTalents()` categorization (missing/wrong/extra).
- **Good:** `ReleaseAlertFrame()` properly clears references.
- **Issue:** Zone keys are localized strings (see Bugs #7).

### Combat.lua
- **Good:** Consumable usage tracking with bag scan caching.
- **Good:** Pre-created `SecureActionButtonTemplate` buttons for reminders.
- **Issue:** Weapon buff ticker runs unconditionally (see Performance #9).

### Loot.lua
- **Good:** Frame pooling with `AcquireToast`/`RecycleToast`.
- **Good:** Roster cache with proper `wipe` on GROUP_ROSTER_UPDATE.
- **Good:** Item level comparison with upgrade indicator.
- **Minor:** Retry closures for uncached items create minor GC pressure during AoE loot.

### ChatSkin.lua
- **Good:** URL detection via `ChatFrame_AddMessageEventFilter` is well-implemented.
- **Good:** Custom `lunaurl:` hyperlink prefix avoids conflicts.
- **Good:** `FormatURLs()` correctly reuses module-level table.
- **Issue:** `HighlightKeywords()` creates new `placeholders` table per call (see Performance #8).
- **Minor:** URL storage could grow unbounded (see Memory Leaks #4).

### Misc.lua
- **Good:** SCT frame pooling with `SCT_MAX_ACTIVE=30` cap.
- **Good:** Quick destroy hook is cleanly implemented.
- **Minor:** Multiple unrelated features in one file (see Readability #7).

### Frames.lua
- **Good:** Frame pooling and per-side border visibility.
- **Good:** `SaveAllFramePositions` on `PLAYER_LOGOUT`.
- **Minor:** Nudge button positioning logic is complex but correct.

### CastBar.lua
- **Good:** Proper handling of cast/channel/empower/interrupt states.
- **Good:** FadeOut animation via OnUpdate is smooth.
- **Good:** Combat-safe Blizzard cast bar hiding via RegisterStateDriver.

### MinimapCustom.lua
- **Good:** Drawer system for collecting minimap buttons.
- **Issue:** Clock ticker runs unconditionally (see Bugs #3).
- **Minor:** `IsMinimapButton` heuristic may miss some addon buttons.

### MinimapButton.lua
- **Good:** Clean, simple draggable minimap button with proper save/restore.
- No issues found.

### AddonComm.lua
- **Good:** Rate limiting and dedup system.
- **Good:** Legacy prefix backwards compatibility.
- **Issue:** Stale dedup entries not swept (see Memory Leaks #3).

### AddonVersions.lua
- **Good:** Clean protocol with backwards-compatible message parsing.
- **Good:** Keystone info sharing between party members.
- **Good:** `playerData` wiped properly on GROUP_ROSTER_UPDATE when leaving group.

### Reagents.lua
- **Good:** Debounced bag scanning with `C_Timer.NewTimer` (SCAN_DELAY=0.5s).
- **Good:** Tooltip integration via `TooltipDataProcessor` with enabled check (since hooks can't be removed).
- **Good:** Separate bag/bank storage with merged view.
- **Minor:** Cross-character data persists for deleted characters (handled by config UI).

### config/ConfigMain.lua
- **Good:** Clean sidebar navigation with 16 tabs.
- **Good:** `SetAllPoints` for panel sizing.
- No issues found.

### config/Helpers.lua
- **Good:** `BuildFontList()` and `BuildTextureList()` called once on load and cached.
- **Good:** `fontObjectCache` for font preview objects.
- **Good:** `CreateColorSwatch()` helper available (though not universally used).
- No issues found.

### Config Panel Files (16 files)
- **Good:** Consistent `addonTable.ConfigSetup.ModuleName` pattern.
- **Good:** `Helpers.UpdateModuleVisuals` for enable/disable visual feedback.
- **Good:** ActionBarsPanel checks for conflicting addons (Dominos, Bartender4, ElvUI).
- **Issue:** Heavy code duplication across panels (see Readability #1).
- **Issue:** Global frame names (see Readability #5).
- **Issue:** Eager initialization (see Performance #10).

### widgets/Widgets.lua (Framework)
- **Good:** `CreateWidgetFrame` factory pattern.
- **Good:** Anchor system with dirty flag caching (`anchorCacheDirty`).
- **Good:** `SmartAnchorTooltip` for proper tooltip positioning relative to screen edges.
- **Good:** Start/stop ticker based on whether any widgets are enabled.
- **Suggestion:** Add `isEventDriven` optimization (see Optimization #2).

### widgets/FPS.lua
- **Good:** Throttles memory scan to 15-second intervals (`MEM_UPDATE_INTERVAL`).
- **Good:** Jitter calculation from latency history (30 samples).
- **Good:** Object pool for memory entries.
- **Issue:** Double sort (see Performance #7).

### widgets/Bags.lua
- **Good:** Event-driven gold tracking with PLAYER_MONEY/PLAYER_ENTERING_WORLD.
- **Good:** Cross-character gold display in tooltip.
- **Minor:** goldData persistence for deleted characters (see Memory Leaks #5).

### widgets/Spec.lua
- **Good:** Context menus via `MenuUtil.CreateContextMenu` for spec/loot spec switching.
- **Good:** Event-driven cache refresh.
- No issues found.

### widgets/Durability.lua
- **Good:** Cached repair cost from last vendor visit.
- **Good:** Event-driven (MERCHANT_SHOW, UPDATE_INVENTORY_DURABILITY).
- No issues found.

### widgets/Combat.lua (Widget)
- **Good:** Minimal, event-driven (PLAYER_REGEN_DISABLED/ENABLED).
- **Good:** Uses the widget frame itself for events (no extra event frame needed).
- No issues found.

### widgets/Friends.lua
- **Good:** Event-driven caching with proper ApplyEvents pattern.
- No issues found.

### widgets/Guild.lua
- **Good:** Event-driven caching.
- **Good:** Fix for malformed guild names with repeated realm names.
- No issues found.

### widgets/Group.lua
- **Good:** Cached atlas markup strings at module level.
- **Good:** Raid sorting functionality (Odds/Evens, Split Half, Healers to Last).
- **Good:** Ready check tracking.
- **Minor:** Fragile party unit mapping fallback (see Bugs #10).

### widgets/Teleports.lua
- **Good:** Spellbook scan cache invalidated on SPELLS_CHANGED.
- **Good:** Button pooling (AcquireButton/ReleaseButton).
- **Good:** SecureActionButtonTemplate for combat-safe spell casting.
- **Good:** Dismiss frame pattern for click-outside-to-close.
- **Minor:** Known spell lookup not cached alongside spellbook scan (see Performance #11).

### widgets/Keystone.lua
- **Good:** SecureActionButtonTemplate overlay for click-to-teleport.
- **Good:** Rating gain estimation.
- **Issue:** Bag scan every tick (see Performance #4).

### widgets/WeeklyReset.lua
- **Good:** Clean timer calculation for daily/weekly resets.
- No issues found.

### widgets/Time.lua
- **Good:** Simple, clean implementation.
- No issues found.

### widgets/Coordinates.lua
- **Issue:** Per-tick map API calls (see Performance #2). Inherent to the feature.
- No other issues.

### widgets/BattleRes.lua
- **Good:** Uses `C_Spell.GetSpellCharges` for battle res tracking.
- No issues found.

### widgets/Speed.lua
- **Issue:** Dual update paths (see Performance #3).
- No other issues.

### widgets/ItemLevel.lua
- **Good:** Event-driven caching (PLAYER_AVG_ITEM_LEVEL_UPDATE, PLAYER_EQUIPMENT_CHANGED).
- **Good:** Per-slot breakdown in tooltip.
- No issues found.

### widgets/Volume.lua
- **Good:** Clean click handlers for mute toggle and volume cycling.
- No issues found. CVar reads are cheap.

### widgets/Zone.lua
- **Good:** Event-driven caching on zone change events.
- **Good:** Rich tooltip with PvP type and instance info.
- No issues found.

### widgets/PvP.lua
- **Good:** Event-driven caching (HONOR_LEVEL_UPDATE, CURRENCY_DISPLAY_UPDATE, etc.).
- **Good:** Comprehensive PvP info tooltip (rated brackets, war mode, conquest).
- No issues found.

### widgets/MythicRating.lua
- **Good:** Event-driven with `C_MythicPlus.RequestMapInfo()` on PLAYER_ENTERING_WORLD.
- **Good:** Dungeon score color via `GetDungeonScoreRarityColor`.
- **Good:** Party key estimate display using shared AddonVersions data.
- No issues found.

### widgets/Vault.lua
- **Good:** Event-driven with delayed refresh on PLAYER_ENTERING_WORLD (2s timer for API readiness).
- **Good:** Click-to-open Great Vault UI.
- No issues found.

### widgets/DarkmoonFaire.lua
- **Good:** Profession quest completion tracking.
- **Issue:** Date arithmetic every tick (see Performance #6).

### widgets/Mail.lua
- **Good:** Minimal, event-driven (UPDATE_PENDING_MAIL, MAIL_INBOX_UPDATE).
- No issues found.

### widgets/PullCounter.lua
- **Good:** Session-only data with right-click reset.
- **Good:** Per-boss breakdown with kills/wipes/best time.
- **Info:** Data lost on reload (see Bugs #8).

### widgets/Hearthstone.lua
- **Good:** SecureActionButtonTemplate for combat-safe use.
- **Good:** Random hearthstone toy selection from owned list.
- **Good:** `ownedHearthstones` cache invalidated on PLAYER_ENTERING_WORLD.
- **Issue:** Cooldown display mismatch (see Bugs #4).

### widgets/Currency.lua
- **Good:** Frame pooling for currency rows (AcquireRow/ReleaseAllRows).
- **Good:** Dismiss frame for click-outside-to-close.
- **Good:** `noDataLabel` created once and reused.
- **Issue:** Hardcoded currency IDs for TWW S1 (see Bugs #9).

---

## Summary of Priority Actions

| Priority | Issue | File(s) | Impact |
|----------|-------|---------|--------|
| **High** | ObjectiveTracker sort table allocation on hot path | ObjectiveTracker.lua | GC pressure during quest updates |
| **High** | questLineCache grows unbounded | ObjectiveTracker.lua | Memory over long sessions |
| **Medium** | ChatSkin HighlightKeywords per-call table creation | ChatSkin.lua | GC pressure with active chat |
| **Medium** | Keystone widget bag scan every tick | widgets/Keystone.lua | Unnecessary CPU every second |
| **Medium** | Hardcoded currency IDs (will be stale next season) | widgets/Currency.lua | Feature breakage on patch |
| **Medium** | Config panels created eagerly | config/panels/*.lua | Higher memory baseline |
| **Low** | Core.lua Log() table allocation | Core.lua | Wasteful but low-frequency |
| **Low** | DarkmoonFaire date arithmetic every tick | widgets/DarkmoonFaire.lua | Minor CPU waste |
| **Low** | MinimapCustom clock ticker always running | MinimapCustom.lua | Wasted cycles when disabled |
| **Low** | Speed widget dual update paths | widgets/Speed.lua | Minor overhead |
| **Low** | AddonComm dedup table not swept | AddonComm.lua | Slow memory growth |
| **Low** | Inconsistent logging (print vs Core.Log) | Multiple | Code maintainability |
| **Low** | Config panel code duplication | config/panels/*.lua | Developer productivity |
| **Info** | Hearthstone cooldown display vs random toy | widgets/Hearthstone.lua | Minor UX inconsistency |
| **Info** | TalentReminder localized zone keys | TalentReminder.lua | Cross-locale limitation |
| **Info** | PullCounter session-only data | widgets/PullCounter.lua | By design |
