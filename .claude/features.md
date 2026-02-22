# Feature Suggestions - LunaUITweaks

**Date:** 2026-02-22
**Previous Review:** 2026-02-21
**Current Version:** v1.13.0

Ease ratings: **Easy** (1-2 days), **Medium** (3-5 days), **Hard** (1-2 weeks), **Very Hard** (2+ weeks)

---

## Previously Suggested - Now Implemented

The following features from previous reviews have been implemented:

- **M+ Dungeon Timer** -- Fully implemented as `MplusTimer.lua`. Includes +1/+2/+3 timer bars, forces tracking, boss objectives, death counter with per-player breakdown tooltip, affix display, Peril affix timer adjustments, auto-slot keystone, and demo mode.
- **Quest Automation** -- Fully implemented as `QuestAuto.lua`. Includes auto-accept, auto-turn-in, auto-gossip single option, shift-to-pause, trivial quest filtering, and gossip loop prevention.
- **Quest Reminders** -- Fully implemented as `QuestReminder.lua`. Automatically tracks daily/weekly quests on accept, shows a login popup for incomplete repeatable quests, includes TTS notifications, chat messages, per-character warband override, and a full config panel with quest management.
- **Talent Build Manager** -- Fully implemented as `TalentManager.lua`. Side panel anchored to the talent screen with Encounter Journal-based category/instance/difficulty tree view, import/export talent strings, build match detection (green tick), copy/update/delete/load per build. Array-based storage for multiple builds per zone key. **Updated 2026-02-21:** Import string decoding now uses `DecodeImportString()` with Blizzard's `ExportUtil.MakeImportDataStream` and `ReadLoadoutHeader`/`ReadLoadoutContent` to directly decode and apply talent builds from import strings without creating temporary loadouts. posY-sorted talent application ensures prerequisite ordering. `CleanupTempLoadouts()` removes leftover entries from the old import approach.
- **Notifications Panel** -- Separated personal orders and mail notification settings into a dedicated `NotificationsPanel.lua` config tab with per-notification TTS, voice selection, alert color, and duration controls.
- **Currency Widget** -- Fully implemented as `widgets/Currency.lua` with a detailed currency panel popup, weekly cap tracking, icon-rich display, and frame pooling. Currency list updated to TWW Season 3 values.
- **Loot Spec Quick-Switcher** -- Partially implemented via the existing Spec widget, which already offers left-click for spec switching and right-click for loot spec switching via context menus. The mismatch warning portion is not yet implemented.
- **Addon Memory/CPU Monitor Widget** -- Implemented within the FPS widget tooltip, which shows per-addon memory breakdown (top addons sorted by memory), total memory, jitter calculation, bandwidth stats, and a configurable `showAddonMemory` toggle.
- **Minimap Button Drawer** -- Implemented in `MinimapCustom.lua` with configurable button collection from minimap children, adjustable button size, padding, column count, border/background colors, lockable/draggable container frame, and toggle visibility.
- **Quick Item Destroy** -- Implemented in `Misc.lua` as `quickDestroy` option. Bypasses the "DELETE" typing requirement on rare/epic items with a single-click DELETE button overlay on the confirmation dialog.
- **Session Stats Widget** -- NEW (2026-02-19). Implemented as `widgets/SessionStats.lua`. Tracks session duration, gold delta, items looted, and deaths. Persists across `/reload` with true login vs reload detection. Right-click resets counters. **Updated 2026-02-22:** Added staleness detection (30-minute timeout), character switching detection via `UnitGUID`, persistent `SaveSessionData()` on every counter update.
- **Widget Visibility Conditions** -- NEW (2026-02-19). Implemented in `Widgets.lua` with `EvaluateCondition()` supporting 7 conditions: `always`, `combat`, `nocombat`, `group`, `solo`, `instance`, `world`. Each widget has a condition dropdown in the config panel. BattleRes and PullCounter default to `instance`.
- **Dungeon/Raid Lockout Widget** -- NEW (2026-02-22). Previously feature #27. Fully implemented as `widgets/Lockouts.lua` (164 lines). Shows locked instance count on widget face, tooltip separates raids and dungeons with per-boss kill status for raids, difficulty names, extended lockout indicator, time remaining. Click opens Raid Info panel. Proper `ApplyEvents(enabled)` pattern.
- **Coordinates/Waypoint Module** -- NEW (2026-02-22). Implemented as standalone `Coordinates.lua` (652 lines). Full waypoint management: `/lway` slash command with zone resolution, waypoint list UI with row pooling, paste dialog for bulk import, `C_Map.SetUserWaypoint` integration with super-tracking, configurable backdrop/border. Separate Coordinates widget (`widgets/Coordinates.lua`, 55 lines) shows live player coordinates.
- **SCT Module Extraction** -- NEW (2026-02-22). Previously SCT was embedded in `Misc.lua` (feature #41 prerequisite). Now extracted to standalone `SCT.lua` (249 lines) with dedicated `SCTPanel.lua` config panel. Separate damage/healing anchors, frame pooling, `issecretvalue()` guards, target name display, crit scaling, configurable font/colors/duration/scroll distance.
- **Minimap Coordinates Overlay** -- NEW (2026-02-22). Previously part of feature #36 (Minimap Enhancements). Coordinates text overlay implemented in `MinimapCustom.lua` with configurable font, size, position, and update rate. Shares clock format setting with Time widget.

---

## Changes Since Last Review (2026-02-22)

Commit `a094160 Updates for v1.13` -- 17 files changed, 2094 insertions, 675 deletions. Key changes:

1. **NEW: Coordinates.lua** (~652 lines) -- Full standalone waypoint management module:
   - `/lway` slash command with flexible parsing: `/lway x, y`, `/lway x y name`, `/lway zone x, y name`
   - Zone name resolution via `C_Map.GetMapChildrenInfo` across 10 cosmic map IDs with exact and partial matching
   - Waypoint list UI with row pooling (`AcquireRow`/`RecycleRow`), scroll frame, click to set waypoint, right-click to open map
   - Paste dialog for bulk waypoint import (strips `/lway` or `/way` prefixes)
   - `C_Map.SetUserWaypoint` + `C_SuperTrack.SetSuperTrackedUserWaypoint` integration
   - Optional `/way` command alias (configurable, deferred to `PLAYER_LOGIN`)
   - Config panel (`CoordinatesPanel.lua`, 144 lines) with backdrop, border, font, size, lock controls

2. **NEW: SCT.lua** (~249 lines) -- Scrolling Combat Text extracted from Misc.lua:
   - Separate damage and healing anchor frames with independent positioning
   - Frame pool with `SCT_MAX_ACTIVE = 30` cap, OnUpdate-driven scroll animation with alpha fade
   - `issecretvalue()` guards on `amount` and `flagText` from `UNIT_COMBAT`
   - Configurable font, colors, duration, scroll distance, crit scale, target name display
   - `captureToFrames` toggle controls whether to use custom frames or Blizzard's FCT
   - `ApplySCTEvents()` properly registers/unregisters `UNIT_COMBAT` via EventBus

3. **NEW: config/panels/CoordinatesPanel.lua** (~144 lines) -- Config panel for Coordinates module.

4. **NEW: config/panels/SCTPanel.lua** (~179 lines) -- Config panel for SCT module.

5. **MinimapCustom.lua** (+225 lines) -- Major additions:
   - Coordinates text overlay on minimap with configurable font, size, and position
   - QueueStatusButton (dungeon finder eye) persistent anchoring to minimap via hooks on OnShow, SetPoint, and UpdatePosition
   - Additional minimap customization options in MinimapPanel

6. **Misc.lua** (-247 lines) -- SCT code extracted to standalone `SCT.lua`. Misc.lua now contains only auto-invite, quick destroy, AH expansion filter, mail alerts, and tooltip class coloring.

7. **config/panels/MinimapPanel.lua** (+296 lines) -- Major expansion with minimap coordinates overlay settings, clock format, additional shape/border options.

8. **config/ConfigMain.lua** (+246 lines) -- Restructured config navigation with new tabs for Coordinates and SCT. Auto-lock logic updated to include SCT anchors (`addonTable.SCT.LockSCTAnchors`).

9. **Core.lua** (+63 lines) -- New default settings for `coordinates` (waypoints, pos, width, height, font, locked, backdrop settings, registerWayCommand) and `sct` (enabled, font, fontSize, colors, duration, scrollDistance, critScale, anchors, target name display, captureToFrames).

10. **TalentManager.lua** (+33 lines) -- Minor refinements to import/export functionality.

11. **widgets/Lockouts.lua** (+18 lines) -- Polished implementation with proper `ApplyEvents` pattern, raid/dungeon separation in tooltip, per-boss kill status for raids.

12. **widgets/SessionStats.lua** (+40 lines) -- Staleness detection, character key tracking, persistent `SaveSessionData()`.

13. **widgets/Time.lua** (+2 lines) -- Respects `UIThingsDB.minimap.minimapClockFormat` for 12H/24H display.

14. **config/panels/ActionBarsPanel.lua** (+12 lines) -- Minor layout adjustments.

15. **config/panels/MiscPanel.lua** (-189 lines) -- SCT settings removed (moved to SCTPanel).

16. **LunaUITweaks.toc** -- Version bump to 1.13.0, added `SCT.lua`, `Coordinates.lua`, `SCTPanel.lua`, `CoordinatesPanel.lua`.

**Previously suggested features implemented:** Feature #27 (Lockout Widget) is now fully done. Feature #36 (Minimap Enhancements) partially done (coordinates overlay). Feature #41 (SCT improvements) prerequisite met (standalone module extraction). New Coordinates module was not previously suggested -- it's a new capability.

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
- **Rationale:** Lua table serialization is well-understood. The main work is implementing a serializer/deserializer, compressing via `LibDeflate` or a simple RLE scheme, and Base64 encoding. The UI needs an export/import dialog with a scrollable text box. Per-module granularity adds some config routing logic but nothing conceptually hard. The TalentManager already demonstrates import/export for talent strings, and the Coordinates module demonstrates paste dialogs, so UI patterns are proven.
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
Add tooltip customization: item level on player/inspect tooltips, guild rank display, spec/role icons, target-of-target text, class-colored player names. The addon already hooks tooltip data via `TooltipDataProcessor` in Reagents.lua and Misc.lua (class color tooltips), so the pattern is established.
- **Ease:** Medium
- **Impact:** Medium-High
- **Rationale:** The TooltipDataProcessor hook pattern is already proven in Reagents.lua and Misc.lua's `HookTooltipClassColors`. Adding player tooltip enhancements requires `INSPECT_READY` for item level calculations and `GetInspectSpecialization()` for spec display. **Note (2026-02-22):** The Misc.lua `issecretvalue()` bug on `tooltip:GetUnit()` unit token highlights the need for combat-safety guards in tooltip hooks.
- **Files:** New Tooltip.lua module + config panel

### 7. Auto-Sell Lists
Extend the Vendor module with custom sell lists -- allow users to mark specific items for auto-selling beyond just grey quality. Support item name patterns, item level thresholds, specific item IDs, and a right-click "add to sell list" context menu.
- **Ease:** Easy
- **Impact:** Medium
- **Rationale:** The vendor hook (`MERCHANT_SHOW`) is already in place. Adding a saved list of item IDs/patterns and iterating bags on merchant open is straightforward. The right-click menu integration needs `hooksecurefunc` on item buttons. No combat safety concerns since this only runs at merchants.
- **Files:** Vendor.lua, config/panels/VendorPanel.lua, Core.lua (defaults)

### 8. M+ Timer History and Statistics
Extend MplusTimer to save run history (completion times, death counts, key levels, affixes, per-player death breakdowns) to a SavedVariable and display statistics: average completion time per dungeon, personal bests, upgrade/downgrade trends, and a filterable run log.
- **Ease:** Medium
- **Impact:** Medium-High for M+ players
- **Rationale:** MplusTimer already tracks all the data during a run. Saving it on completion is trivial. The complexity is in the statistics UI -- a scrollable run log with filtering, sorting, and potentially a small chart or comparison view. Saved variable size management (pruning old runs) adds minor complexity.
- **Files:** MplusTimer.lua, new SavedVariable or extend UIThingsDB, config panel additions

### 9. Chat Tabs/Channels Manager
Extend ChatSkin with custom chat tab presets (e.g., "M+ Group" tab that auto-joins instance chat + party), auto-join/leave channels on zone change, and per-tab color/font settings.
- **Ease:** Medium
- **Impact:** Medium
- **Rationale:** Chat frame manipulation via `ChatFrame_AddChannel`/`ChatFrame_RemoveChannel` and `FCF_OpenNewWindow` is documented. The complexity is in tracking state across zone changes reliably.
- **Files:** ChatSkin.lua, config/panels/ChatSkinPanel.lua

### 10. Encounter Notes
Allow users to save per-boss or per-dungeon text notes that automatically display as a small, dismissible overlay when entering the relevant zone. Integrate with TalentReminder's zone detection to reuse the instance/difficulty/zone mapping.
- **Ease:** Medium
- **Impact:** Medium
- **Rationale:** The zone detection infrastructure exists in TalentReminder. A new saved variable for notes with the same structure would allow seamless integration.
- **Files:** New EncounterNotes.lua or extend TalentReminder.lua

### 11. Quest Auto Enhancements
Extend QuestAuto with: a blacklist/whitelist for specific quest IDs or NPC names, auto-select best quest reward based on item level or sell price, party quest sharing on accept, and an optional confirmation dialog for important quests.
- **Ease:** Easy-Medium
- **Impact:** Medium
- **Rationale:** QuestAuto already handles all quest interaction events. Adding a blacklist is a simple table lookup. Best reward selection requires `GetQuestItemInfo` and `GetItemInfo` comparisons.
- **Files:** QuestAuto.lua, config/panels/QuestAutoPanel.lua, Core.lua (defaults)

### 12. Party Composition Analyzer
Show a summary widget or popup when joining a group: available interrupts (leveraging the Kick module's INTERRUPT_SPELLS database), battle rez coverage, bloodlust/heroism availability, and missing raid buffs. Highlight gaps in group composition.
- **Ease:** Medium
- **Impact:** Medium-High for M+ and raid leaders
- **Rationale:** The Kick module already has a comprehensive database of interrupt spells per class. The Group widget already shows role breakdown. Extending this with battle rez, lust, and buff coverage is a data expansion.
- **Files:** New module or extend Group widget/Kick.lua, possibly AddonComm.lua for spec sharing

### 13. M+ Timer Split Comparison
Extend MplusTimer to save "personal best splits" per dungeon per key level range and show real-time green/red delta comparisons during runs. Display boss kill deltas, forces completion delta, and overall pace indicator.
- **Ease:** Medium-Hard
- **Impact:** Medium-High for competitive M+ players
- **Rationale:** MplusTimer already tracks boss completion times and forces progress. The real-time comparison needs additional UI elements and logic to interpolate pace between checkpoints.
- **Files:** MplusTimer.lua, new SavedVariable for split data

### 14. Interrupt Assignment Helper
Extend the Kick module with a visual interrupt rotation assignment tool for M+ groups. Auto-assign interrupt order based on cooldown lengths, show the rotation visually, and broadcast assignments via addon comm.
- **Ease:** Medium-Hard
- **Impact:** High for organized M+ groups
- **Rationale:** The Kick module already has the full INTERRUPT_SPELLS database with cooldown durations and tracks who has interrupts available.
- **Files:** Kick.lua, AddonComm.lua, config/panels/KickPanel.lua

### 15. Currency Widget Improvements
The Currency widget now has TWW Season 3 currencies but the `DEFAULT_CURRENCIES` list remains hardcoded per season. Extend to: automatically detect the current season's relevant currencies using `C_CurrencyInfo.GetCurrencyListSize/Info` or `isShowInBackpack`, allow users to customize which currencies to track, and add cross-character currency comparison.
- **Ease:** Easy-Medium
- **Impact:** Medium
- **Rationale:** The currency tracking infrastructure is already built. The Bags widget already iterates `isShowInBackpack` currencies in its tooltip, proving the pattern works.
- **Files:** widgets/Currency.lua, Core.lua (defaults), config/panels/WidgetsPanel.lua

### 16. Raid Sorting Improvements
The Group widget already has raid sorting (odds/evens, split half, healers to last). Extend with: save custom sorting presets, class-based grouping, and sync sorting preferences across the raid via AddonComm.
- **Ease:** Medium
- **Impact:** Medium for raid leaders
- **Files:** widgets/Group.lua, AddonComm.lua, Core.lua (defaults)

---

## Quality-of-Life Improvements

### 17. Global Font/Scale Settings
Add a "Global" settings page that lets users set a default font family and base scale applied across all modules. Individual modules could still override.
- **Ease:** Easy-Medium
- **Impact:** Medium
- **Files:** Core.lua, config/ConfigMain.lua, all modules that use fonts

### 18. Settings Reset Per-Module
Add a "Reset to Defaults" button on each config panel that resets only that module's settings.
- **Ease:** Easy
- **Impact:** Low-Medium
- **Files:** config/ConfigMain.lua, Core.lua

### 19. Minimap Button Right-Click Menu
Add a right-click context menu to the minimap button with quick toggles and quick access to individual config panels.
- **Ease:** Easy
- **Impact:** Medium
- **Files:** MinimapButton.lua

### 20. Keybind Support for More Actions
Expand keybind support: toggle all widgets, toggle combat timer, open config window, lock/unlock all movable frames.
- **Ease:** Easy
- **Impact:** Low-Medium
- **Files:** Bindings.xml (new or extended), relevant modules

### 21. Search in Config Window
Add a search box at the top of the config window that filters visible tabs. With 22+ tabs now (after adding Coordinates and SCT), finding specific settings becomes harder.
- **Ease:** Medium-Hard
- **Impact:** Medium
- **Files:** config/ConfigMain.lua, all panel files (for metadata)

### 22. Snap to Grid for Movable Frames
When dragging widgets, custom frames, the cast bar, the M+ timer, or the Coordinates waypoint frame, add optional grid snapping. Could be toggled with a modifier key (Shift to snap).
- **Ease:** Easy
- **Impact:** Low-Medium
- **Rationale:** `Widgets.CreateWidgetFrame` centralizes the drag logic. A one-line rounding operation in `OnDragStop`. Coordinates.lua already has its own `OnDragStop` that could share this pattern.
- **Files:** widgets/Widgets.lua, CastBar.lua, Frames.lua, MplusTimer.lua, Kick.lua, Coordinates.lua

### 23. Talent Reminder Import/Export for Sharing
Allow exporting/importing talent reminder configurations as encoded strings. Raid leaders could share talent setups for specific encounters with their team.
- **Ease:** Medium
- **Impact:** Medium for organized groups
- **Files:** TalentReminder.lua, TalentManager.lua, config/panels/TalentPanel.lua

### 24. Cooldown Tracker Widget
Add a widget that shows remaining cooldowns on important player abilities: major defensives, DPS cooldowns, movement abilities. Display as a small icon bar with timers.
- **Ease:** Easy-Medium
- **Impact:** Medium-High -- Useful across all content types
- **Rationale:** The Kick module already tracks spell cooldowns via `C_Spell.GetSpellCooldown`. The Combat module tracks consumable buffs with clickable icons.
- **Files:** New widget in widgets/ or standalone module, config panel

### 25. Auto-Screenshot on Achievement/Kill
Automatically take a screenshot when earning an achievement, timing a M+ key, killing a raid boss for the first time, or obtaining a rare mount/pet.
- **Ease:** Easy
- **Impact:** Low-Medium
- **Files:** Extend Misc.lua or new small module

### 26. Reagent Shopping List
Extend Reagents.lua to let users define target quantities for specific reagents. Show a "shopping list" of items needed to reach the target, factoring in stock across all tracked characters.
- **Ease:** Medium
- **Impact:** Medium for crafters
- **Files:** Reagents.lua, config/panels/ReagentsPanel.lua

### 27. Chat Message Filter/Mute
Extend ChatSkin with message filtering: hide messages containing specific keywords or from specific players, auto-collapse spam, and optionally route filtered messages to a separate tab.
- **Ease:** Easy-Medium
- **Impact:** Medium
- **Files:** ChatSkin.lua, config/panels/ChatSkinPanel.lua, Core.lua (defaults)

### 28. World Quest Timer Overlay
Add countdown timers to world quests in the ObjectiveTracker showing time remaining before they expire. Sound alerts for expiring quests that are being tracked.
- **Ease:** Easy
- **Impact:** Medium
- **Files:** ObjectiveTracker.lua, config/panels/TrackerPanel.lua

---

## New Feature Ideas (Added 2026-02-19)

### 29. Talent Manager Enhancements
The TalentManager has array-based build storage making drag-and-drop reordering trivially implementable. Extend with: drag-and-drop reordering, keyboard shortcuts to load builds (1-9), auto-detect current content type and suggest matching builds, and a "quick switch" bar outside the talent frame.
- **Ease:** Medium
- **Impact:** Medium-High
- **Rationale:** The `buildIndex` tracking infrastructure is fully in place. Drag-and-drop requires `OnDragStart`/`OnDragStop` handlers on build rows.
- **Files:** TalentManager.lua, config/panels/TalentManagerPanel.lua

### 30. Quest Reminder Enhancements
Extend with: quest category grouping (dailies vs weeklies in separate sections), completion streak tracking, priority marking for important quests, and integration with the ObjectiveTracker.
- **Ease:** Easy-Medium
- **Impact:** Medium
- **Files:** QuestReminder.lua, config/panels/QuestReminderPanel.lua, ObjectiveTracker.lua

### 31. M+ Route/Pull Planner Integration
Add a simple in-game route display for M+ dungeons: show pull markers on the minimap, integrate with MplusTimer's forces tracking. Support importing routes from popular planning tools.
- **Ease:** Hard
- **Impact:** High for M+ players
- **Files:** New MplusRoute.lua module or extend MplusTimer.lua

### 32. Consumable Reminder Improvements
The Combat module's consumable reminder system already tracks flask, food, weapon buff, pet, and class buffs. Extend with: auto-detect content difficulty to only remind in relevant content, show remaining duration on existing buffs, add Augmentation rune tracking.
- **Ease:** Easy-Medium
- **Impact:** Medium
- **Files:** Combat.lua, config/panels/CombatPanel.lua

### 33. Hearthstone Widget Improvements
Add a hearthstone preference list (favorites weighted in random selection), show all available hearthstones in a click-menu (like the Teleport widget's panel), and track usage statistics.
- **Ease:** Easy
- **Impact:** Low-Medium
- **Files:** widgets/Hearthstone.lua, Core.lua (defaults)

### 34. Group Widget Ready Check Improvements
Extend with: ready check history, sound alerts for declined ready checks, auto-ready-check before pull timer.
- **Ease:** Easy-Medium
- **Impact:** Medium for group leaders
- **Files:** widgets/Group.lua

### 35. Minimap Enhancements (Remaining)
Remaining items from original suggestion: minimap scaling, node tracking toggles around the minimap border, and a ping tracker showing who pinged. **Note (2026-02-22):** Coordinates overlay portion is now implemented in MinimapCustom.lua.
- **Ease:** Medium
- **Impact:** Medium
- **Files:** MinimapCustom.lua, config/panels/MinimapPanel.lua

### 36. Death Recap Enhancement
Replace or supplement Blizzard's death recap with a more detailed breakdown: last N damage/healing events, killing blow highlight, timeline display. Must use `CombatLogGetCurrentEventInfo()` via sub-events (not `COMBAT_LOG_EVENT_UNFILTERED`).
- **Ease:** Medium-Hard
- **Impact:** Medium -- Very useful for learning encounters
- **Files:** New DeathRecap.lua module + config panel

### 37. Teleport Widget Favorites
Add a "favorites" row at the top of the Teleport panel and remember the last-used teleport for one-click quick-cast.
- **Ease:** Easy
- **Impact:** Low-Medium
- **Files:** widgets/Teleports.lua, Core.lua (defaults)

### 38. Loot Spec Mismatch Warning
Add a persistent warning indicator when loot spec differs from current spec via the Spec widget.
- **Ease:** Easy
- **Impact:** Medium -- Prevents loot going to wrong spec
- **Files:** widgets/Spec.lua, Core.lua (defaults)

### 39. M+ Affix Strategy Notes
Extend MplusTimer with configurable per-affix strategy notes that display during the run.
- **Ease:** Easy
- **Impact:** Low-Medium
- **Files:** MplusTimer.lua, config/panels/MplusTimerPanel.lua, Core.lua (defaults)

### 40. SCT Spell Icons and Filtering
Enhance the now-standalone SCT module with: spell icons next to damage numbers, damage school coloring (fire = orange, frost = blue, etc.), minimum threshold filter, per-spell blacklist. **Updated 2026-02-22:** SCT is now a standalone module (`SCT.lua`) with its own config panel (`SCTPanel.lua`), making these enhancements cleaner to implement.
- **Ease:** Medium
- **Impact:** Medium
- **Files:** SCT.lua, config/panels/SCTPanel.lua, Core.lua (defaults)

### 41. Objective Tracker Auto-Collapse in Combat
Add a middle-ground option: auto-collapse all sections to just headers during combat, then auto-expand when combat ends.
- **Ease:** Easy
- **Impact:** Low-Medium
- **Files:** ObjectiveTracker.lua, config/panels/TrackerPanel.lua, Core.lua (defaults)

### 42. Warband Bank Integration for Reagents
Better surface warband vs personal quantities in tooltips, add "total across warband" summary.
- **Ease:** Easy
- **Impact:** Medium for multi-character crafters
- **Files:** Reagents.lua, config/panels/ReagentsPanel.lua

### 43. Chat Skin Fade Timer
Add optional auto-fade: chat fades to configurable alpha after N seconds of inactivity, becomes visible on new messages or mouse hover.
- **Ease:** Easy-Medium
- **Impact:** Medium
- **Files:** ChatSkin.lua, config/panels/ChatSkinPanel.lua, Core.lua (defaults)

### 44. M+ Death Log Enhancements
Extend per-player death log with: death timestamps, death locations, cause of death tracking (from combat log sub-events), death timeline overlay on timer bar.
- **Ease:** Medium
- **Impact:** Medium for M+ groups
- **Files:** MplusTimer.lua, AddonComm.lua, config/panels/MplusTimerPanel.lua

### 45. Talent Build Comparison View
Side-by-side comparison view for two builds showing which talents differ and which are shared. Allow merging (taking specific nodes from one build into another).
- **Ease:** Medium
- **Impact:** Medium for raiders and M+ players
- **Files:** TalentManager.lua, TalentReminder.lua

### 46. Multi-Build Quick Apply Toolbar
Floating toolbar in instances showing all matching builds for the current zone/difficulty with one-click apply buttons.
- **Ease:** Easy-Medium
- **Impact:** Medium-High for raiders who swap talents between pulls
- **Files:** TalentReminder.lua or new TalentToolbar.lua, Core.lua (defaults)

---

## New Feature Ideas (Added 2026-02-22)

### 47. Waypoint Sharing via AddonComm
Share waypoints with group members via the AddonComm system. Leader sets a waypoint, all LunaUITweaks users in the group receive it automatically. Uses the existing `Comm.Send/Register` pattern with a new `WAYP` module namespace.
- **Ease:** Easy-Medium
- **Impact:** Medium-High for M+ and raid groups
- **Rationale:** The Coordinates module has `AddWaypoint(mapID, x, y, name, zone)` as a public API. AddonComm already supports structured `MODULE:ACTION:PAYLOAD` messages. Sending `WAYP:SET:mapID:x:y:name` is trivial. Rate limiting and dedup are built into AddonComm. The `group` context makes this highly practical.
- **Files:** Coordinates.lua, AddonComm.lua, Core.lua (defaults)

### 48. Waypoint Integration with TomTom Import Format
Support parsing TomTom-format `/way` commands from chat messages and addon guides. Auto-detect `/way zone x y description` patterns in chat and offer to add them as waypoints. The Coordinates module already has a flexible `ParseWaypointString` that handles similar formats.
- **Ease:** Easy
- **Impact:** Medium -- Interoperability with existing community content
- **Rationale:** The `/way` alias is already conditionally registered via `Coordinates.ApplyWayCommand()`. Chat link detection pattern exists in ChatSkin.lua. Hooking `CHAT_MSG_*` to detect waypoint patterns and showing an "Add waypoint?" button is straightforward.
- **Files:** Coordinates.lua, ChatSkin.lua or Misc.lua

### 49. Coordinates Distance Display
Add distance-to-waypoint display on the Coordinates frame and optionally as a widget. Show arrow direction indicator. The Coordinates module already tracks `activeWaypointIndex` and stores all waypoint coordinates.
- **Ease:** Easy-Medium
- **Impact:** Medium
- **Rationale:** Distance calculation using `C_Map.GetPlayerMapPosition` vs waypoint position is straightforward. Arrow direction uses `atan2`. Updates every tick via existing widget framework or a small OnUpdate.
- **Files:** Coordinates.lua, optionally widgets/WaypointDistance.lua

### 50. SCT Damage School Coloring
Add automatic damage school coloring to SCT. The `UNIT_COMBAT` event provides `schoolMask` which maps to damage types. Fire = orange, frost = blue, nature = green, shadow = purple, etc. With SCT now a standalone module, this is a clean addition.
- **Ease:** Easy
- **Impact:** Medium -- Visual clarity during combat
- **Rationale:** `schoolMask` is already passed to `OnUnitCombat` (line 200 in SCT.lua) but currently unused. Adding a color lookup table and using it in `SpawnSCTText` is ~15 lines of code.
- **Files:** SCT.lua, config/panels/SCTPanel.lua (toggle), Core.lua (defaults)

### 51. Lockout Widget Weekly M+ Best Display
Extend the Lockouts widget tooltip with weekly M+ best completion for each dungeon. Shows which dungeons have been timed this week for vault progress. Complements the existing raid/dungeon lockout display.
- **Ease:** Easy
- **Impact:** Medium for M+ players
- **Rationale:** `C_MythicPlus.GetWeeklyBestForMap()` provides the data. The Lockouts widget tooltip is already structured with raid/dungeon sections. Adding a "Mythic+" section is a natural extension.
- **Files:** widgets/Lockouts.lua

---

## Architecture Improvements

### 52. Module Enable/Disable Without Reload
Add proper teardown methods to modules that currently require `/reload` to fully enable/disable. Each module would implement a `Teardown()` function.
- **Ease:** Medium-Hard (varies by module)
- **Impact:** Medium

### 53. Internal Event Bus -- FULLY IMPLEMENTED
The centralized EventBus is now fully implemented across the addon with all modules migrated. The pcall memory regression has been resolved. **Note (2026-02-19):** A new HIGH priority issue was discovered -- duplicate registration vulnerability where modules that call `EventBus.Register` in `ApplyEvents` without first calling `Unregister` accumulate duplicate listeners. Only Reagents.lua correctly prevents this.
- **Status:** Fully implemented but needs duplicate registration fix.

### 54. Shared Border/Backdrop Utility
Extract duplicated border drawing code from 8+ modules into `Helpers.ApplyFrameBackdrop`. **Note (2026-02-22):** The Coordinates module already uses `Helpers.ApplyFrameBackdrop` (line 571-573), showing the pattern is being adopted. Continue migrating other modules.
- **Ease:** Easy-Medium
- **Impact:** Medium (code quality)

### 55. Lazy Module Loading
Defer initialization of disabled modules. Currently all modules load and initialize on `ADDON_LOADED` regardless of state.
- **Ease:** Medium
- **Impact:** Low-Medium (performance)

### 56. Localization Support
Add a localization framework for translating all UI strings. The TOC already includes localized Category strings in 10 languages.
- **Ease:** Medium
- **Impact:** Medium for non-English users

### 57. Config Panel Code Deduplication
Extract repeated TTS, appearance, and color swatch patterns into `Helpers.lua` composable building blocks. **Note (2026-02-19):** The code review found ~960 lines of duplicated color swatch code across 6 panels when `Helpers.CreateColorSwatch` already exists and is used correctly by 8 other panels.
- **Ease:** Easy-Medium
- **Impact:** Medium (code quality)
- **Files:** config/Helpers.lua, multiple panel files

### 58. Talent Data Migration Safety
The `CleanupSavedVariables()` function deletes old-format entries instead of migrating them. **Fix:** Wrap old single-object entries in arrays (`{ value }`) instead of deleting them.
- **Ease:** Easy
- **Impact:** Low-Medium (data safety for existing users)
- **Files:** TalentReminder.lua

### 59. EventBus Duplicate Registration Fix
Add deduplication to `EventBus.Register` or adopt the Reagents.lua `eventsEnabled` guard pattern across all modules. Currently, every module except Reagents.lua can accumulate duplicate listeners on repeated `ApplyEvents` calls.
- **Ease:** Easy (fix in EventBus.lua) or Medium (fix in each module)
- **Impact:** High (correctness -- event handlers fire multiple times)
- **Files:** EventBus.lua or all modules with ApplyEvents functions

### 60. Config Tab Count Scalability
With 22+ config tabs now (after adding Coordinates and SCT in v1.13), the sidebar is getting long. Consider: tab grouping/categories, collapsible sections, or the search feature (#21). The current linear list scales linearly with module count.
- **Ease:** Medium
- **Impact:** Medium (UX)
- **Files:** config/ConfigMain.lua

### 61. Standardize issecretvalue Guards
Audit all modules for missing `issecretvalue()` guards on WoW API return values used during combat. **Note (2026-02-22):** Bug found in Misc.lua line 417 -- `tooltip:GetUnit()` returns a secret value unit token during combat, passed unchecked to `UnitIsPlayer()`. Fixed by adding `issecretvalue(unit)` guard. Similar patterns should be audited across all tooltip hooks, `UNIT_COMBAT` handlers, and event callbacks that access unit data.
- **Ease:** Easy-Medium
- **Impact:** Medium (crash prevention)
- **Files:** All modules with tooltip hooks or combat event handlers
