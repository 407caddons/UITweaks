# Feature Suggestions - LunaUITweaks

**Date:** 2026-02-17
**Current Version:** v1.11.0

Ease ratings: **Easy** (1-2 days), **Medium** (3-5 days), **Hard** (1-2 weeks), **Very Hard** (2+ weeks)

---

## Previously Suggested - Now Implemented

The following features from the previous review have been implemented:

- **M+ Dungeon Timer** -- Fully implemented as `MplusTimer.lua`. Includes +1/+2/+3 timer bars, forces tracking, boss objectives, death counter, affix display, Peril affix timer adjustments, auto-slot keystone, and demo mode.
- **Quest Automation** -- Fully implemented as `QuestAuto.lua`. Includes auto-accept, auto-turn-in, auto-gossip single option, shift-to-pause, trivial quest filtering, and gossip loop prevention.
- **Quest Reminders** -- New module `QuestReminder.lua` (not previously suggested). Automatically tracks daily/weekly quests on accept, shows a login popup for incomplete repeatable quests, includes TTS notifications, chat messages, per-character warband override, and a full config panel with quest management.
- **Talent Build Manager** -- New module `TalentManager.lua` (not previously suggested). Side panel anchored to the talent screen with Encounter Journal-based category/instance/difficulty tree view, import/export talent strings, build match detection (green tick), copy/update/delete/load per build. Shares data with TalentReminder via `LunaUITweaks_TalentReminders`.
- **Notifications Panel** -- Separated personal orders and mail notification settings into a dedicated `NotificationsPanel.lua` config tab with per-notification TTS, voice selection, alert color, and duration controls.
- **Currency Widget** -- New widget `widgets/Currency.lua` with a detailed currency panel popup, weekly cap tracking, and icon-rich display. (Note: not yet listed in the TOC widget loading section.)
- **Loot Spec Quick-Switcher (Suggestion #23)** -- Partially implemented via the existing Spec widget, which already offers left-click for spec switching and right-click for loot spec switching via context menus. The mismatch warning portion is not yet implemented.
- **Addon Memory/CPU Monitor Widget (Suggestion #28)** -- Implemented within the FPS widget tooltip, which now shows per-addon memory breakdown (top 30 addons sorted by memory), total memory, jitter calculation, bandwidth stats, and a configurable `showAddonMemory` toggle. Separate garbage collection button not yet added.

---

## High-Value Features

### 1. Target/Focus Cast Bar
Extend the existing CastBar module to show cast bars for target and focus units. The infrastructure is already in place -- the custom cast bar handles `UNIT_SPELLCAST_START/STOP/CHANNEL` events. Adding target/focus would mean creating additional bar instances with the same rendering logic but filtered to different unit IDs.
- **Ease:** Medium
- **Impact:** High -- Replaces more Blizzard UI, reduces dependency on other addons
- **Rationale:** The rendering pipeline (spark, icon, text, fade animation) is already built. The main work is creating additional frame instances, adding unit filtering to the event handler, and extending the config panel with per-unit settings (position, size, colors). The empower channel handling adds some complexity.
- **Files:** CastBar.lua, config/panels/CastBarPanel.lua, Core.lua (defaults)

### 2. Nameplate Enhancements
Add nameplate customization: cast bars on nameplates, health text formatting (percentage/absolute), class-colored health bars, threat coloring, and target highlight. WoW 12.0 nameplates are highly customizable via `C_NamePlate` and `NamePlateDriverFrame`.
- **Ease:** Hard
- **Impact:** High -- Major UI area currently untouched by the addon
- **Rationale:** Nameplates involve hooking `NAME_PLATE_UNIT_ADDED`/`REMOVED` events and modifying CompactUnitFrame children. The challenge is handling the large number of nameplates efficiently (dozens visible at once), dealing with Blizzard's protected nameplate code, and ensuring compatibility with other nameplate addons. Threat coloring requires polling or `UNIT_THREAT_LIST_UPDATE` tracking.
- **Files:** New Nameplates.lua module + config panel

### 3. Buff/Debuff Tracker (Aura Bars)
Create configurable aura tracking bars or icons for specific buffs/debuffs on player, target, or focus. Users could create "watchlists" of important auras (trinket procs, boss debuffs, cooldowns) with customizable display -- as bars with timers, icon grids, or text-only.
- **Ease:** Hard
- **Impact:** High -- Core raiding/M+ feature, partially overlaps WeakAuras territory
- **Rationale:** The aura tracking itself is straightforward via `UNIT_AURA` and `C_UnitAuras.GetAuraDataBySlot/Index`. The complexity lies in the configuration UI (letting users search and add spells to watch lists), efficient filtering of potentially hundreds of auras per tick, and the variety of display formats users would expect.
- **Files:** New AuraTracker.lua module + config panel

### 4. Profile Import/Export
Allow users to export their entire `UIThingsDB` configuration as a string (compressed and Base64-encoded) and import it on other characters or share with friends. Include per-module export for sharing just specific module configs.
- **Ease:** Medium
- **Impact:** High -- Quality of life for multi-character players
- **Rationale:** Lua table serialization is well-understood. The main work is implementing a serializer/deserializer, compressing via `LibDeflate` or a simple RLE scheme, and Base64 encoding. The UI needs an export/import dialog with a scrollable text box. Per-module granularity adds some config routing logic but nothing conceptually hard. The TalentManager already demonstrates import/export for talent strings, so the pattern is proven.
- **Files:** Core.lua or new Profiles.lua, config/ConfigMain.lua

### 5. Unit Frame Enhancements
Add simple player/target/focus frame customization: health bar text formatting, class colors, portrait style, buff/debuff display filtering, and power bar theming. This is the largest untouched Blizzard UI area.
- **Ease:** Very Hard
- **Impact:** Very High -- Would significantly reduce addon dependency for many players
- **Rationale:** Unit frames are deeply protected by Blizzard's secure frame system. Many properties cannot be changed in combat. The scope is enormous: health bars, power bars, portraits, cast bars (if combined with feature 1), buff/debuff icons, threat borders, and raid frames. Even a "lite" version (player + target only) would be substantial.
- **Files:** New UnitFrames.lua module + config panel

---

## Medium-Value Features

### 6. Tooltip Enhancements
Add tooltip customization: item level on player/inspect tooltips, guild rank display, spec/role icons, target-of-target text, class-colored player names. The addon already hooks tooltip data via `TooltipDataProcessor` in Reagents.lua, so the pattern is established.
- **Ease:** Medium
- **Impact:** Medium-High
- **Rationale:** The TooltipDataProcessor hook pattern is already proven in Reagents.lua. Adding player tooltip enhancements requires `INSPECT_READY` for item level calculations and `GetInspectSpecialization()` for spec display. The challenge is handling the asynchronous nature of inspect data and avoiding excessive inspect requests.
- **Files:** New Tooltip.lua module + config panel

### 7. Auto-Sell Lists
Extend the Vendor module with custom sell lists -- allow users to mark specific items for auto-selling beyond just grey quality. Support item name patterns, item level thresholds, specific item IDs, and a right-click "add to sell list" context menu.
- **Ease:** Easy
- **Impact:** Medium
- **Rationale:** The vendor hook (`MERCHANT_SHOW`) is already in place. Adding a saved list of item IDs/patterns and iterating bags on merchant open is straightforward. The right-click menu integration needs `hooksecurefunc` on item buttons. No combat safety concerns since this only runs at merchants.
- **Files:** Vendor.lua, config/panels/VendorPanel.lua, Core.lua (defaults)

### 8. M+ Timer History and Statistics
Extend MplusTimer to save run history (completion times, death counts, key levels, affixes) to a SavedVariable and display statistics: average completion time per dungeon, personal bests, upgrade/downgrade trends, and a filterable run log.
- **Ease:** Medium
- **Impact:** Medium-High for M+ players
- **Rationale:** MplusTimer already tracks all the data during a run (elapsed time, deaths, boss times, forces, Peril timer adjustments). Saving it on completion is trivial. The complexity is in the statistics UI -- a scrollable run log with filtering, sorting, and potentially a small chart or comparison view. Saved variable size management (pruning old runs) adds minor complexity.
- **Files:** MplusTimer.lua, new SavedVariable or extend UIThingsDB, config panel additions

### 9. Chat Tabs/Channels Manager
Extend ChatSkin with custom chat tab presets (e.g., "M+ Group" tab that auto-joins instance chat + party), auto-join/leave channels on zone change, and per-tab color/font settings. Add a quick-switch dropdown for tab layouts.
- **Ease:** Medium
- **Impact:** Medium
- **Rationale:** Chat frame manipulation via `ChatFrame_AddChannel`/`ChatFrame_RemoveChannel` and `FCF_OpenNewWindow` is documented. The complexity is in tracking state across zone changes reliably and providing a clean config UI for defining channel presets.
- **Files:** ChatSkin.lua, config/panels/ChatSkinPanel.lua

### 10. Encounter Notes
Allow users to save per-boss or per-dungeon text notes that automatically display as a small, dismissible overlay when entering the relevant zone. Integrate with TalentReminder's zone detection to reuse the instance/difficulty/zone mapping. Support class/role-specific note variants.
- **Ease:** Medium
- **Impact:** Medium
- **Rationale:** The zone detection infrastructure exists in TalentReminder. A new saved variable for notes with the same `instanceID/difficultyID/zoneKey` structure would allow seamless integration. The display UI is a simple text frame. The editing UI needs a multi-line EditBox with save/load. The TalentManager's Encounter Journal cache could be reused for instance/difficulty lookups.
- **Files:** New EncounterNotes.lua or extend TalentReminder.lua

### 11. Quest Auto Enhancements
Extend QuestAuto with: a blacklist/whitelist for specific quest IDs or NPC names, auto-select best quest reward based on item level or sell price, party quest sharing on accept, and an optional confirmation dialog for important quests (e.g., weekly/bi-weekly quests).
- **Ease:** Easy-Medium
- **Impact:** Medium
- **Rationale:** QuestAuto already handles all the quest interaction events. Adding a blacklist is a simple table lookup before each auto-action. Best reward selection requires `GetQuestItemInfo` and `GetItemInfo` comparisons. Quest sharing uses `QuestLogPushQuest()`. The main design challenge is making the config UI intuitive for managing blacklists.
- **Files:** QuestAuto.lua, config/panels/QuestAutoPanel.lua, Core.lua (defaults)

### 12. Party Composition Analyzer
Show a summary widget or popup when joining a group: available interrupts (leveraging the Kick module's INTERRUPT_SPELLS database), battle rez coverage, bloodlust/heroism availability, and missing raid buffs. Highlight gaps in group composition.
- **Ease:** Medium
- **Impact:** Medium-High for M+ and raid leaders
- **Rationale:** The Kick module already has a comprehensive database of interrupt spells per class. The Group widget already shows role breakdown with tank/healer/DPS counts. Extending this with battle rez, lust, and buff coverage is a data expansion. The display could be a tooltip enhancement on the Group widget. The challenge is accurately detecting which abilities each group member has (spec-dependent abilities require inspect or addon comm data).
- **Files:** New module or extend Group widget/Kick.lua, possibly AddonComm.lua for spec sharing

### 13. M+ Timer Split Comparison
Extend MplusTimer to save "personal best splits" per dungeon per key level range and show real-time green/red delta comparisons during runs. Display boss kill deltas, forces completion delta, and overall pace indicator.
- **Ease:** Medium-Hard
- **Impact:** Medium-High for competitive M+ players
- **Rationale:** MplusTimer already tracks boss completion times and forces progress. Saving these as "best splits" is a SavedVariable addition. The real-time comparison needs additional UI elements (delta text per boss/forces bar) and logic to interpolate pace between checkpoints. The UI design for showing deltas without cluttering the timer is the main challenge.
- **Files:** MplusTimer.lua, new SavedVariable for split data

### 14. Interrupt Assignment Helper
Extend the Kick module with a visual interrupt rotation assignment tool for M+ groups. Auto-assign interrupt order based on cooldown lengths (shorter CDs more frequent in rotation), show the rotation visually, and broadcast assignments via addon comm.
- **Ease:** Medium-Hard
- **Impact:** High for organized M+ groups
- **Rationale:** The Kick module already has the full INTERRUPT_SPELLS database with cooldown durations and tracks who has interrupts available. The algorithm for optimal rotation assignment is moderately complex (sort by CD length, distribute evenly). The broadcast needs AddonComm integration for sharing the assignment. The UI needs a visual rotation display.
- **Files:** Kick.lua, AddonComm.lua, config/panels/KickPanel.lua

### 15. Currency Widget Improvements
The Currency widget currently has a hardcoded `DEFAULT_CURRENCIES` list for TWW Season 1. Extend it to: automatically detect the current season's relevant currencies, allow users to customize which currencies to track, add cross-character currency comparison (similar to Bags widget's gold tracking), and fix the missing TOC entry.
- **Ease:** Easy-Medium
- **Impact:** Medium
- **Rationale:** The currency tracking infrastructure is already built with a detailed popup panel. The main work is replacing the hardcoded list with a user-configurable one (using `C_CurrencyInfo.GetCurrencyListSize/Info` to enumerate available currencies) and adding a character-keyed SavedVariable for cross-character totals. The TOC fix is a one-line addition.
- **Files:** widgets/Currency.lua, LunaUITweaks.toc, Core.lua (defaults), config/panels/WidgetsPanel.lua

### 16. Raid Sorting Improvements
The Group widget already has raid sorting (odds/evens, split half, healers to last). Extend with: save custom sorting presets, class-based grouping (all mages in group 3, etc.), and sync sorting preferences across the raid via AddonComm.
- **Ease:** Medium
- **Impact:** Medium for raid leaders
- **Rationale:** The sorting infrastructure in `widgets/Group.lua` is well-built with `ApplyRaidAssignments()` handling the actual group swaps via a ticker. Adding presets is a SavedVariable addition. Class-based grouping extends the existing role categorization. AddonComm broadcast for sharing preferences uses the established pattern.
- **Files:** widgets/Group.lua, AddonComm.lua, Core.lua (defaults)

---

## Quality-of-Life Improvements

### 17. Global Font/Scale Settings
Add a "Global" settings page that lets users set a default font family and base scale applied across all modules. Individual modules could still override with their own font/scale setting.
- **Ease:** Easy-Medium
- **Impact:** Medium
- **Rationale:** Most modules already read font settings from `UIThingsDB.moduleName.font` or similar. Adding a global default that modules fall back to when their own font is unset is a small change to each module's initialization.
- **Files:** Core.lua, config/ConfigMain.lua, all modules that use fonts

### 18. Settings Reset Per-Module
Add a "Reset to Defaults" button on each config panel that resets only that module's settings in `UIThingsDB` back to the values from the `DEFAULTS` table.
- **Ease:** Easy
- **Impact:** Low-Medium
- **Rationale:** The `DEFAULTS` table in Core.lua already defines defaults per module key. A reset function just needs to copy the relevant subtable from `DEFAULTS` over the current `UIThingsDB[moduleKey]`, then call `UpdateSettings()`.
- **Files:** config/ConfigMain.lua, Core.lua

### 19. Minimap Button Right-Click Menu
Add a right-click context menu to the minimap button with quick toggles: objective tracker on/off, widgets lock/unlock, combat timer toggle, M+ timer toggle, and quick access to individual config panels.
- **Ease:** Easy
- **Impact:** Medium
- **Rationale:** WoW's `MenuUtil.CreateContextMenu` pattern is already used extensively (Spec widget, Group widget). The minimap button already has click handling; adding right-click detection and a menu is minimal work.
- **Files:** MinimapButton.lua

### 20. Keybind Support for More Actions
Expand keybind support beyond the existing quest item button and tracker toggle. Add bindable actions for: toggle all widgets, toggle combat timer, open config window, lock/unlock all movable frames, toggle M+ timer demo mode, and cycle through specs.
- **Ease:** Easy
- **Impact:** Low-Medium
- **Rationale:** WoW keybinds are declared in `Bindings.xml` with corresponding global functions. Each binding is one XML entry and one Lua function.
- **Files:** Bindings.xml (new or extended), relevant modules

### 21. Search in Config Window
Add a search box at the top of the config window that filters visible tabs and/or highlights matching settings within panels. As the addon grows beyond 20 tabs, finding specific settings becomes harder.
- **Ease:** Medium-Hard
- **Impact:** Medium
- **Rationale:** Tab filtering is straightforward (match tab name against query, hide non-matching tabs). Highlighting settings within panels is much harder. A simpler tab-level-only approach would still be valuable.
- **Files:** config/ConfigMain.lua, all panel files (for metadata)

### 22. Snap to Grid for Movable Frames
When dragging widgets, custom frames, the cast bar, or the M+ timer, add optional grid snapping (e.g., snap to nearest 5/10/25px). Could be toggled with a modifier key (Shift to snap) or a global setting.
- **Ease:** Easy
- **Impact:** Low-Medium
- **Rationale:** The `OnDragStop` handler in each movable frame already captures position via `GetCenter()`. Adding snap is a one-line rounding operation: `x = math.floor(x / gridSize + 0.5) * gridSize`. Applying this consistently across all draggable frames is straightforward since `Widgets.CreateWidgetFrame` centralizes the drag logic.
- **Files:** widgets/Widgets.lua, CastBar.lua, Frames.lua, MplusTimer.lua, Kick.lua

### 23. Talent Reminder Import/Export for Sharing
Allow exporting/importing talent reminder configurations as encoded strings. Raid leaders could share talent setups for specific encounters with their team. The TalentManager already implements import/export for talent strings -- this would extend that to share the zone-based reminder mappings.
- **Ease:** Medium
- **Impact:** Medium for organized groups
- **Rationale:** The talent reminder data structure (`instanceID/difficultyID/zoneKey -> snapshot`) is well-defined. The TalentManager's existing import/export dialog code could be reused. The challenge is handling conflicts (existing reminder for same zone) and validating that imported talent nodes exist for the player's class/spec.
- **Files:** TalentReminder.lua, TalentManager.lua, config/panels/TalentPanel.lua

### 24. Cooldown Tracker Widget
Add a widget (or set of widgets) that shows remaining cooldowns on important player abilities: major defensives, DPS cooldowns, movement abilities, and utility spells. Display as a small icon bar with timers, similar to the interrupt tracker but for personal cooldowns.
- **Ease:** Easy-Medium
- **Impact:** Medium-High -- Useful across all content types
- **Rationale:** The Kick module already tracks spell cooldowns via `GetSpellCooldown`. The Combat module already tracks consumable buffs with clickable icons. Reusing these patterns for a configurable list of player spells is straightforward.
- **Files:** New widget in widgets/ or standalone module, config panel

### 25. Auto-Screenshot on Achievement/Kill
Automatically take a screenshot when earning an achievement, timing a M+ key, killing a raid boss for the first time, or obtaining a rare mount/pet. Configurable triggers with optional delay.
- **Ease:** Easy
- **Impact:** Low-Medium
- **Rationale:** The `Screenshot()` API is one function call. Trigger events are `ACHIEVEMENT_EARNED`, `CHALLENGE_MODE_COMPLETED`, `ENCOUNTER_END`, `NEW_MOUNT_ADDED`, `NEW_PET_ADDED`. A small event handler with configurable toggle per trigger type.
- **Files:** Extend Misc.lua or new small module

### 26. Reagent Shopping List
Extend Reagents.lua to let users define target quantities for specific reagents. Show a "shopping list" of items needed to reach the target, factoring in stock across all tracked characters. Integrate with the AH filter to highlight needed items.
- **Ease:** Medium
- **Impact:** Medium for crafters
- **Rationale:** The reagent scanning infrastructure exists with full bag/bank/warband scanning and cross-character tracking. Adding target quantities is a saved variable addition. AH integration requires working with `AuctionHouseFrame` which has limited addon support.
- **Files:** Reagents.lua, config/panels/ReagentsPanel.lua

### 27. Dungeon/Raid Lockout Widget
Add a widget showing current instance lockouts: raid lockouts with boss completion progress, M+ weekly best, and saved instance count. Click to open the Raid Info panel.
- **Ease:** Easy-Medium
- **Impact:** Medium for raiders
- **Rationale:** `GetNumSavedInstances()`, `GetSavedInstanceInfo()`, and `RequestRaidInfo()` provide lockout data. The tooltip format is similar to existing widgets (Vault, Keystone). The Vault widget already shows M+ and raid progress -- this would complement it with explicit lockout tracking.
- **Files:** New widget in widgets/Lockouts.lua

### 28. Chat Message Filter/Mute
Extend ChatSkin with message filtering: hide messages containing specific keywords or from specific players, auto-collapse spam (repeated messages), and optionally route filtered messages to a separate "Filtered" tab.
- **Ease:** Easy-Medium
- **Impact:** Medium
- **Rationale:** ChatSkin already hooks chat messages for URL detection and keyword highlighting via `ChatFrame_AddMessageEventFilter`. Adding a filter layer that checks against a blocklist before displaying is a small addition to the existing hooks.
- **Files:** ChatSkin.lua, config/panels/ChatSkinPanel.lua, Core.lua (defaults)

### 29. World Quest Timer Overlay
Add countdown timers to world quests in the ObjectiveTracker showing time remaining before they expire. Color-code quests that expire soon (red for <1h, orange for <4h). Optionally add sound alerts for expiring quests that are being tracked.
- **Ease:** Easy
- **Impact:** Medium
- **Rationale:** `C_TaskQuest.GetQuestTimeLeftSeconds()` returns the remaining time. The ObjectiveTracker already displays world quests with timer coloring. This would extend the coloring to the main quest text and add optional audio alerts.
- **Files:** ObjectiveTracker.lua

---

## New Feature Ideas (Added This Review)

### 30. Talent Manager Enhancements
The TalentManager is new and functional but could be extended with: drag-and-drop reordering of builds, keyboard shortcuts to load builds (1-9), auto-detect current content type and suggest matching builds, and a "quick switch" bar that shows outside the talent frame.
- **Ease:** Medium
- **Impact:** Medium-High
- **Rationale:** The TalentManager already has a comprehensive tree view with categories, instances, and difficulties. The EJ cache is built. Adding drag-and-drop requires `OnDragStart`/`OnDragStop` handlers on build rows. The quick switch bar would be a small floating frame with build buttons, similar to a toolbar.
- **Files:** TalentManager.lua, config/panels/TalentManagerPanel.lua

### 31. Quest Reminder Enhancements
The QuestReminder module could be extended with: quest category grouping (dailies vs weeklies in separate sections), completion streak tracking (how many days/weeks in a row you've completed a quest), priority marking for important quests, and integration with the ObjectiveTracker to highlight reminder quests.
- **Ease:** Easy-Medium
- **Impact:** Medium
- **Rationale:** The QuestReminder already tracks frequency (daily/weekly) and zone. Adding grouping is a UI sort change. Streak tracking requires a history table in the SavedVariable. Priority marking is a per-quest flag. ObjectiveTracker integration would use the quest ID list to add visual indicators.
- **Files:** QuestReminder.lua, config/panels/QuestReminderPanel.lua, ObjectiveTracker.lua

### 32. M+ Route/Pull Planner Integration
Add a simple in-game route display for M+ dungeons: show pull markers or waypoints on the minimap, integrate with the MplusTimer's forces tracking to estimate if the planned pulls will meet the requirement. Support importing routes from popular planning tools.
- **Ease:** Hard
- **Impact:** High for M+ players
- **Rationale:** The MplusTimer already tracks forces and has per-dungeon data. Minimap pin placement uses `C_Map.SetUserWaypoint()` or addon-drawn minimap icons. The Hard part is the route data format and import parsing. This would be a significant differentiator from other timer addons.
- **Files:** New MplusRoute.lua module or extend MplusTimer.lua

### 33. Consumable Reminder Improvements
The Combat module's consumable reminder system already tracks flask, food, weapon buff, pet, and class buffs with clickable icons. Extend with: auto-detect content difficulty to only remind in relevant content (e.g., M+ and raid only), show remaining duration on existing buffs, add Augmentation rune tracking, and provide a "restock" shopping list after a raid session.
- **Ease:** Easy-Medium
- **Impact:** Medium
- **Rationale:** The consumable reminder system is already well-built with quality star icons, `SecureActionButtonTemplate` buttons, and bag scanning. Adding difficulty filtering requires checking `select(3, GetInstanceInfo())`. Duration display needs `C_UnitAuras` checking. Rune tracking is another item category to scan for.
- **Files:** Combat.lua, config/panels/CombatPanel.lua

### 34. Hearthstone Widget Improvements
The Hearthstone widget supports 30+ toy hearthstones with random selection. Extend with: a hearthstone preference list (favorites weighted higher in random selection), show all available hearthstones in a click-menu (like the Teleport widget's panel), and track hearthstone usage statistics for fun.
- **Ease:** Easy
- **Impact:** Low-Medium
- **Rationale:** The Hearthstone widget already builds an owned list and supports `SecureActionButtonTemplate` for combat-safe usage. Adding a preference list is a SavedVariable addition. A panel popup can reuse the Teleport widget's panel pattern (button pool, dismiss frame, secure buttons).
- **Files:** widgets/Hearthstone.lua, Core.lua (defaults)

### 35. Group Widget Ready Check Improvements
The Group widget already shows ready check status with color-coded progress. Extend with: ready check history (who was slow/declined), sound alerts for declined ready checks, auto-ready-check before pull timer, and a visual countdown ring during the check.
- **Ease:** Easy-Medium
- **Impact:** Medium for group leaders
- **Rationale:** The `READY_CHECK`, `READY_CHECK_CONFIRM`, and `READY_CHECK_FINISHED` events are already handled. Adding history is a session table. Sound alerts use `PlaySound()`. Auto-ready-check requires detecting DBM/BigWigs pull timers or the built-in `C_PartyInfo.DoCountdown()`.
- **Files:** widgets/Group.lua

### 36. Minimap Enhancements
The MinimapCustom module already handles shape (round/square), border, zone text, and clock. Extend with: minimap scaling, node tracking toggles (herbs, ores, etc.) as buttons around the minimap border, a coordinates overlay directly on the minimap, and a ping tracker showing who pinged.
- **Ease:** Medium
- **Impact:** Medium
- **Rationale:** Minimap scaling uses `Minimap:SetScale()`. Node tracking toggles use `C_Minimap.SetTracking()`. The ping tracker hooks `MINIMAP_PING` events with `Minimap:GetPingPosition()`. The coordinates overlay reuses the Coordinates widget logic.
- **Files:** MinimapCustom.lua, config/panels/MinimapPanel.lua

### 37. Death Recap Enhancement
Replace or supplement Blizzard's death recap with a more detailed breakdown: show the last N damage/healing events before death, highlight the killing blow, and show a timeline. Use sub-events from `CombatLogGetCurrentEventInfo()`.
- **Ease:** Medium-Hard
- **Impact:** Medium -- Very useful for learning encounters
- **Rationale:** Tracking damage events requires maintaining a rolling buffer of recent combat log entries filtered to the player. The display is a scrollable frame showing spell icons, damage amounts, and timestamps. Must use `CombatLogGetCurrentEventInfo()` and specific sub-events, not `COMBAT_LOG_EVENT_UNFILTERED` directly (restricted to Blizzard UI only).
- **Files:** New DeathRecap.lua module + config panel

### 38. Teleport Widget Favorites
The Teleport widget already has an excellent panel with categories, current season dungeons, and secure spell buttons. Add a "favorites" row at the top of the panel for frequently used teleports, and remember the last-used teleport for a one-click quick-cast without opening the full panel.
- **Ease:** Easy
- **Impact:** Low-Medium
- **Rationale:** The panel infrastructure with button pools and secure buttons is already built. Favorites would be a small SavedVariable list. The "last used" quick-cast changes the widget's click behavior to cast the saved spell directly (left-click = last used, right-click = open panel).
- **Files:** widgets/Teleports.lua, Core.lua (defaults)

---

## Architecture Improvements

### 39. Module Enable/Disable Without Reload
Add proper teardown methods to modules that currently require `/reload` to fully enable/disable (mainly those hooking Blizzard frames: ActionBars, CastBar, ChatSkin, ObjectiveTracker). Each module would implement a `Teardown()` function that unhooks, hides, and restores Blizzard defaults.
- **Ease:** Medium-Hard (varies significantly by module)
- **Impact:** Medium
- **Rationale:** Some modules like ActionBars deeply modify Blizzard frames with `hooksecurefunc` which cannot be un-hooked. A full teardown for such modules would require wrapping hooks in conditional checks (`if not enabled then return end`). CastBar and ChatSkin are more feasible since they primarily show/hide addon-created frames.

### 40. Internal Event Bus
Create a centralized internal event bus so modules can communicate without direct table references. Modules publish events and other modules subscribe with callbacks, replacing the current pattern of direct `addonTable.ModuleName` function calls across the codebase.
- **Ease:** Medium
- **Impact:** Low-Medium (architecture improvement, reduces coupling)
- **Rationale:** The bus itself is simple (a table of event -> callback lists). The migration effort is moderate -- every cross-module call needs to be replaced with a publish/subscribe pattern. The benefit is cleaner module boundaries and easier testing. The AddonComm module already demonstrates a handler registry pattern that could be generalized.

#### Proposed Events

Based on the current cross-module communication patterns in the codebase, the event bus would expose approximately 40 events across 7 categories:

**Lifecycle Events**
| Event | Publisher | Replaces |
|---|---|---|
| `LUNA_ADDON_LOADED` | Core.lua | Direct `Initialize()` calls in Core.lua |
| `LUNA_MODULE_READY` | Each module after init | Implicit load-order dependencies |
| `LUNA_SETTINGS_RESET` | Config panels | Would support per-module reset (Feature 18) |

**Config Events**
| Event | Publisher | Replaces |
|---|---|---|
| `LUNA_CONFIG_OPENED` | ConfigMain.lua | Implicit (panels check on render) |
| `LUNA_CONFIG_CLOSED` | ConfigMain.lua | Direct calls to `Frames.UpdateFrames()`, `Loot.LockAnchor()`, `Misc.LockSCTAnchors()`, `Widgets.UpdateVisuals()`, `MplusTimer.CloseDemo()` |
| `LUNA_SETTING_CHANGED` | Config panels | Direct `UpdateSettings()` calls from 20+ config panels |

**Frame & Layout Events**
| Event | Publisher | Replaces |
|---|---|---|
| `LUNA_FRAMES_UPDATED` | Frames.lua | `Widgets.InvalidateAnchorCache()` |
| `LUNA_FRAME_CREATED/DELETED` | Frames.lua | `Config.RefreshFrameControls()` |
| `LUNA_WIDGETS_LOCKED/UNLOCKED` | Widgets.lua | Implicit state check |

**Module-Specific Events**
| Event | Publisher | Replaces |
|---|---|---|
| `LUNA_REMINDER_LIST_CHANGED` | TalentReminder.lua | `Config.RefreshTalentReminderList()` |
| `LUNA_REAGENTS_SCANNED` | Reagents.lua | `Config.RefreshReagentsList()` |
| `LUNA_MPLUS_STARTED/COMPLETED` | MplusTimer.lua | Currently internal only, would enable future modules |
| `LUNA_QUEST_REMINDER_CHANGED` | QuestReminder.lua | `Config.RefreshQuestReminderList()` |

#### Implementation Sketch

```lua
-- Core.lua: Event Bus Implementation
local EventBus = {}
local listeners = {}

function EventBus:Subscribe(event, callback, owner)
    listeners[event] = listeners[event] or {}
    table.insert(listeners[event], { fn = callback, owner = owner })
end

function EventBus:Unsubscribe(event, owner)
    if not listeners[event] then return end
    for i = #listeners[event], 1, -1 do
        if listeners[event][i].owner == owner then
            table.remove(listeners[event], i)
        end
    end
end

function EventBus:Publish(event, payload)
    if not listeners[event] then return end
    for _, listener in ipairs(listeners[event]) do
        local ok, err = pcall(listener.fn, payload)
        if not ok then
            addonTable.Core.Log("EventBus", "Error in " .. event .. ": " .. err, 3)
        end
    end
end

addonTable.EventBus = EventBus
```

### 41. Shared Border/Backdrop Utility
Extract the duplicated border drawing code from ActionBars, CastBar, ChatSkin, Frames, MplusTimer, Kick, TalentManager, and QuestReminder into a shared utility function. A single `CreateStyledBorder(frame, settings)` call would replace the repeated backdrop/border setup code found across 8+ modules.
- **Ease:** Easy-Medium
- **Impact:** Medium (code quality + faster development of new modules)
- **Rationale:** At least 8 modules independently create borders with nearly identical code (BackdropTemplate, edge size, inset calculations). The QuestReminder and TalentManager config panels both duplicate the border/background color picker pattern. Centralizing this reduces bugs and ensures visual consistency.
- **Files:** New utility in Core.lua or a dedicated Shared.lua

### 42. Lazy Module Loading
Defer initialization of modules that are disabled in settings. Currently all modules load and initialize on `ADDON_LOADED` regardless of whether they are enabled. Modules like MplusTimer, Reagents, TalentManager, and QuestReminder could skip initialization entirely when disabled.
- **Ease:** Medium
- **Impact:** Low-Medium (performance, mainly noticeable on low-end systems)
- **Rationale:** Requires restructuring each module to check its enabled state before initialization and adding a mechanism to initialize on-demand when the user enables the module in config. The new modules (TalentManager, QuestReminder) are good candidates since they have clean Initialize/UpdateSettings patterns.

### 43. Localization Support
Add a localization framework for translating all UI strings. Create a `Locales/` folder with per-language string tables. Fall back to English for missing translations.
- **Ease:** Medium
- **Impact:** Medium for non-English users
- **Rationale:** The framework itself is simple (lookup table with fallback). The migration effort is high -- every user-visible string in 25+ files needs to be wrapped in a `L["key"]` call. The TOC already includes localized Category strings, suggesting international users exist.

### 44. Config Panel Code Deduplication
The config panels for QuestReminder, TalentManager, and Notifications all follow the same pattern: enable checkbox, section headers, border/background color pickers, TTS settings (enable, message, voice dropdown, test button). Extract these repeated patterns into `Helpers.lua` as composable building blocks (e.g., `Helpers.CreateTTSSection()`, `Helpers.CreateAppearanceSection()`).
- **Ease:** Easy-Medium
- **Impact:** Medium (code quality, faster development of new config panels)
- **Rationale:** The Helpers.lua module already provides `CreateSectionHeader`, `CreateFontDropdown`, `CreateColorSwatch`, and `UpdateModuleVisuals`. Adding TTS and appearance section builders would eliminate 100+ lines of duplicated code across 3+ panels, and every future module panel would benefit.
- **Files:** config/Helpers.lua, config/panels/NotificationsPanel.lua, config/panels/QuestReminderPanel.lua, config/panels/TalentManagerPanel.lua
