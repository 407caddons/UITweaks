# Feature Suggestions - LunaUITweaks

**Date:** 2026-02-16
**Current Version:** v1.10.0

Ease ratings: **Easy** (1-2 days), **Medium** (3-5 days), **Hard** (1-2 weeks), **Very Hard** (2+ weeks)

---

## High-Value Features

### 1. Target/Focus Cast Bar
Extend the existing CastBar module to show cast bars for target and focus units. The infrastructure is already in place - the custom cast bar handles `UNIT_SPELLCAST_START/STOP/CHANNEL` events. Adding target/focus would mean creating additional bar instances with the same rendering logic but filtered to different unit IDs.
- **Ease:** Medium
- **Impact:** High - Replaces more Blizzard UI, reduces dependency on other addons
- **Files:** CastBar.lua, config/panels/CastBarPanel.lua, Core.lua (defaults)

### 2. Nameplate Enhancements
Add nameplate customization: cast bars on nameplates, health text formatting (percentage/absolute), class-colored health bars, and threat coloring. WoW 12.0 nameplates are highly customizable via `C_NamePlate` API.
- **Ease:** Hard
- **Impact:** High - Major UI area currently untouched
- **Files:** New Nameplates.lua module + config panel

### 3. Buff/Debuff Tracker (Aura Bars)
Create configurable aura tracking bars or icons for specific buffs/debuffs on player, target, or focus. Users could create "watchlists" of important auras (trinket procs, boss debuffs, cooldowns) with customizable display.
- **Ease:** Hard
- **Impact:** High - Core raiding/M+ feature
- **Files:** New AuraTracker.lua module + config panel

### 4. Profile Import/Export
Allow users to export their entire `UIThingsDB` configuration as a string (Base64-encoded serialized table) and import it on other characters or share with friends. Many popular addons offer this.
- **Ease:** Medium
- **Impact:** High - Quality of life for multi-character players
- **Files:** Core.lua or new Profiles.lua, config/ConfigMain.lua

### 5. Unit Frame Enhancements
Add simple player/target/focus frame customization: health bar text formatting, class colors, portrait style, buff/debuff display filtering. This is a large feature but very commonly requested.
- **Ease:** Very Hard
- **Impact:** Very High - Would significantly reduce addon dependency
- **Files:** New UnitFrames.lua module + config panel

---

## Medium-Value Features

### 6. Tooltip Enhancements
Add tooltip customization: item level on character tooltips, guild rank, spec/role display, mount/pet source info, recipe source tooltips. Hook into `GameTooltip` similar to how Reagents.lua already hooks tooltip data.
- **Ease:** Medium
- **Impact:** Medium-High
- **Files:** New Tooltip.lua module

### 7. Auto-Sell Lists
Extend the Vendor module with custom sell lists - allow users to mark specific items for auto-selling beyond just grey quality. Could include item name patterns, item level thresholds, or specific item IDs.
- **Ease:** Easy
- **Impact:** Medium
- **Files:** Vendor.lua, config/panels/VendorPanel.lua, Core.lua (defaults)

### 8. Quest Tracker Pin-to-Map Integration
When clicking a quest in the custom tracker, place a waypoint/pin on the world map at the quest objective location. Use `C_Map.SetUserWaypoint()` or `C_SuperTrack` APIs.
- **Ease:** Easy-Medium
- **Impact:** Medium
- **Files:** ObjectiveTracker.lua

### 9. Dungeon/Raid Timer
Track and display dungeon completion times, boss kill times, and death counts. Similar to the existing Combat timer but scoped to the entire dungeon run. Could integrate with M+ timing.
- **Ease:** Medium
- **Impact:** Medium-High for M+ players
- **Files:** New DungeonTimer.lua or extend Combat.lua

### 10. Chat Tabs/Channels Manager
Extend ChatSkin with the ability to create custom chat tab presets, auto-join/leave channels on zone change, and per-channel font/color settings.
- **Ease:** Medium
- **Impact:** Medium
- **Files:** ChatSkin.lua, config/panels/ChatSkinPanel.lua

### 11. Minimap Button Collector Improvements
The existing minimap drawer collects addon buttons. Enhance it with: search/filter for buttons, favorites that always show, tooltip showing which addon each button belongs to, and auto-hide after clicking.
- **Ease:** Easy-Medium
- **Impact:** Medium
- **Files:** MinimapCustom.lua, config/panels/MinimapPanel.lua

### 12. Encounter Notes
Allow users to save per-boss or per-dungeon notes that automatically display when entering the relevant zone. Could integrate with the TalentReminder zone detection system.
- **Ease:** Medium
- **Impact:** Medium
- **Files:** New EncounterNotes.lua or extend TalentReminder.lua

---

## Quality-of-Life Improvements

### 13. Global Font/Scale Settings
Add a "Global" settings page that lets users set a default font and scale applied across all modules, instead of configuring fonts per-module. Individual modules could still override.
- **Ease:** Easy-Medium
- **Impact:** Medium
- **Files:** Core.lua, config/ConfigMain.lua, all modules that use fonts

### 14. Settings Reset Per-Module
Add a "Reset to Defaults" button on each config panel that resets only that module's settings. Currently users can only reset everything.
- **Ease:** Easy
- **Impact:** Low-Medium
- **Files:** config/ConfigMain.lua, Core.lua

### 15. Minimap Button Right-Click Menu
Add a right-click context menu to the minimap button with quick toggles for common features (tracker on/off, widgets lock/unlock, combat timer toggle, etc.) instead of just opening the config window.
- **Ease:** Easy
- **Impact:** Medium
- **Files:** MinimapButton.lua

### 16. Keybind Support for More Actions
Currently only the quest item button and tracker toggle have keybind support. Add keybinds for: toggle widgets, toggle combat timer, open config, lock/unlock all movable frames.
- **Ease:** Easy
- **Impact:** Low-Medium
- **Files:** Bindings.xml, relevant modules

### 17. Search in Config Window
Add a search box at the top of the config window that filters tabs and highlights matching settings. Useful given the addon now has 16 config tabs.
- **Ease:** Medium-Hard
- **Impact:** Medium
- **Files:** config/ConfigMain.lua, all panel files

### 18. "Snap to Grid" for Movable Frames
When dragging widgets, custom frames, or the cast bar, add optional grid snapping (e.g., snap to nearest 5px). Could be toggled with a modifier key.
- **Ease:** Easy
- **Impact:** Low-Medium
- **Files:** widgets/Widgets.lua, CastBar.lua, Frames.lua

### 19. WeakAura-Style Import for Talent Reminders
Allow exporting/importing talent reminder configurations as strings, so raid leaders can share talent setups for specific encounters with their team.
- **Ease:** Medium
- **Impact:** Medium for organized groups
- **Files:** TalentReminder.lua, config/panels/TalentPanel.lua

---

## Niche Features

### 20. Auto-Screenshot on Achievement/Kill
Automatically take a screenshot when earning an achievement, killing a raid boss for the first time, or timing a M+ key. Use `Screenshot()` API.
- **Ease:** Easy
- **Impact:** Low
- **Files:** New small module or extend Misc.lua

### 21. Reagent Shopping List
Extend Reagents.lua to let users define crafting "recipes" or target quantities, then show what they need to buy/gather based on current stock across all characters.
- **Ease:** Medium
- **Impact:** Medium for crafters
- **Files:** Reagents.lua, config/panels/ReagentsPanel.lua

### 22. Party Composition Analyzer
Show a quick summary when entering a group: available interrupts, battle rez availability, bloodlust/heroism coverage, and missing buffs. Could integrate with the Kick tracker's class detection.
- **Ease:** Medium
- **Impact:** Medium for M+ players
- **Files:** New module or extend Kick.lua

### 23. Addon Memory/CPU Monitor
Extend the existing widget memory display into a full diagnostic panel showing per-addon memory and CPU usage, with alerts for addons consuming excessive resources.
- **Ease:** Easy-Medium
- **Impact:** Low-Medium
- **Files:** New module or extend widgets/FPS.lua

### 24. Chat Link Enhancement
Auto-expand item links on hover in chat to show relevant stats (item level, gem sockets, enchants) without requiring the user to click the link. Hook into chat frame hyperlink handling.
- **Ease:** Medium
- **Impact:** Low-Medium
- **Files:** ChatSkin.lua or new module

---

## Architecture Improvements

### 25. Module Enable/Disable Without Reload
Some modules currently require a `/reload` to fully enable/disable (mainly those that hook Blizzard frames at load time). Adding proper teardown/setup methods would improve the user experience.
- **Ease:** Medium-Hard (varies by module)
- **Impact:** Medium

### 26. Event Bus System
Create a centralized internal event bus so modules can communicate without direct references. For example, the combat module could fire "LUNA_COMBAT_START" that widgets and other modules subscribe to.
- **Ease:** Medium
- **Impact:** Low-Medium (architecture improvement)

### 27. Localization Support
Add a localization framework for translating UI strings. Currently all text is hardcoded in English.
- **Ease:** Medium
- **Impact:** Medium for non-English users
