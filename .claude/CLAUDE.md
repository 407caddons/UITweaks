# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LunaUITweaks is a World of Warcraft 12.0 (retail) addon that provides UI enhancements: a custom objective tracker, talent change reminders, auto-repair/durability warnings, loot toast notifications, a combat timer, custom layout frames, personal order alerts, and AH filtering. Published to CurseForge (project ID 1450486).

## Build & Release

There is no build step or test suite. The addon is pure Lua loaded directly by the WoW client.

- **Release:** Push a git tag matching `v*` (e.g., `v0.15`) to trigger the GitHub Actions packager (`.github/workflows/release.yml`), which uses `BigWigsMods/packager@v2` to package and upload to CurseForge.
- **Local testing:** Copy or symlink the addon folder into `Interface/AddOns/` and reload the WoW client (`/reload`). Use `/luit` or `/luithings` in-game to open the config window.

## Architecture

### Module System

Each `.lua` file is a self-contained module that registers itself on the shared addon table:

```lua
local addonName, addonTable = ...
addonTable.ModuleName = {}
```

The TOC file (`LunaUITweaks.toc`) defines load order. **Core.lua loads first** and initializes everything on `ADDON_LOADED`:
1. Applies default settings to `UIThingsDB` (recursive merge that preserves existing user values)
2. Calls `Initialize()` on Config, Minimap, Frames, and TalentReminder modules
3. Registers slash commands and the Addon Compartment function

### Saved Variables

Two persistent tables declared in the TOC:
- **`UIThingsDB`** — All module settings, organized by module key (`tracker`, `vendor`, `loot`, `combat`, `frames`, `misc`, `minimap`, `talentReminders`)
- **`LunaUITweaks_TalentReminders`** — User-created talent reminder definitions (separate so they survive settings resets)

Settings are accessed directly (e.g., `UIThingsDB.vendor.autoRepair`). Defaults are defined in Core.lua's `DEFAULTS` table and merged via `ApplyDefaults()`, which skips keys that already exist and treats tables with an `r` field as color values (not recursed into).

### Event-Driven Pattern

Modules create frames, register WoW events, and respond in `OnEvent` handlers. Common pattern:

```lua
local frame = CreateFrame("Frame")
frame:RegisterEvent("EVENT_NAME")
frame:SetScript("OnEvent", function(self, event, ...) ... end)
```

### Settings Update Flow

Config.lua contains the full settings UI (~133KB). When a user changes a setting, Config writes to `UIThingsDB` and calls the module's `UpdateSettings()` function to apply changes immediately without reload.

### Frame Pooling

Loot.lua and Frames.lua use object pools — frames are hidden and recycled via `AcquireToast()`/`RecycleToast()` or equivalent instead of being destroyed/recreated.

### Core Utilities

- `addonTable.Core.SafeAfter(delay, func)` — pcall-wrapped `C_Timer.After`
- `addonTable.Core.Log(module, msg, level)` — Colored chat logging. Levels: `DEBUG=0`, `INFO=1`, `WARN=2`, `ERROR=3`. Current threshold is INFO.

## File Responsibilities

| File | Module Key | Purpose |
|---|---|---|
| Core.lua | `Core` | Initialization, defaults, logging, timer utility |
| Config.lua | `Config` | Full settings UI with tabs, color pickers, sliders |
| ObjectiveTracker.lua | `ObjectiveTracker` | Custom quest/WQ/achievement tracker |
| MinimapButton.lua | `Minimap` | Draggable minimap button |
| Vendor.lua | `Vendor` | Auto-repair, sell greys, durability warnings |
| Loot.lua | `Loot` | Loot toast notifications with quality filtering |
| CombatTimer.lua | `Combat` | In-combat duration display (MM:SS) |
| Misc.lua | `Misc` | Personal order alerts (with TTS), AH expansion filter |
| Frames.lua | `Frames` | User-created colored rectangles for UI layout |
| TalentReminder.lua | `TalentReminder` | Zone-based talent/spec change alerts |

## TalentReminder Module Details

The TalentReminder module uses **zone-based detection** (not boss selection) to alert players when their talents don't match saved builds.

### Zone-Based Detection
- Reminders are keyed by zone name (from `GetSubZoneText()` or `GetMinimapZoneText()`)
- Example keys: `"The Primal Bulwark"`, `"The Vault Approach"`, or `"general"` for instance-wide
- Data structure: `LunaUITweaks_TalentReminders.reminders[instanceID][difficultyID][zoneKey]`
- Zone changes are detected via `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `ZONE_CHANGED_NEW_AREA` events

### Alert Triggers
1. **Zone Change** - When player moves to a new subzone with a saved build
2. **Encounter Start** - When a boss encounter begins (`ENCOUNTER_START` event)
3. **Talent Change** - When player changes talents or spec
4. **M+ Entry** - Special check when entering Mythic+ dungeons
5. **Difficulty Toggle** - When difficulty filter is enabled/disabled in config

### Priority System
When checking talents, the system uses a priority list:
1. **Zone-specific reminders** (priority 1) - exact zone match
2. **General reminders** (priority 2) - instance-wide fallback

Only one alert is shown at a time (highest priority with mismatches wins).

### Alert Behavior
- **No snoozing** - Alerts always show when talents mismatch (snooze functionality removed)
- **Difficulty filtering** - Alerts respect `alertOnDifficulties` settings in `UIThingsDB.talentReminders`
- **Dismissible** - Single "Dismiss" button hides the alert
- **Auto-hide** - Alert hides when difficulty filter is disabled
- **Auto-check** - Talents re-checked when difficulty filter is re-enabled

### Talent Comparison
The `CompareTalents()` function returns mismatches categorized as:
- **`missing`** - Talents in saved build but not selected
- **`wrong`** - Different talent selected in same node, or insufficient rank
- **`extra`** - Talents selected but not in saved build

### UI Components
- **Alert Frame** - Global frame named `"LunaTalentReminderAlert"`, movable, customizable appearance
- **Config Tab** - Full settings in Config.lua's talent panel (7th tab)
- **Saved Builds List** - Shows reminders filtered by current class/spec, highlights current zone
- **Difficulty Filters** - Checkboxes for each dungeon/raid difficulty

### Important Variables
- `currentInstanceID`, `currentDifficultyID` - Track current instance context
- `lastZone` - Tracks previous zone to detect zone changes
- `alertFrame` - The popup alert frame (created once, reused)

## Key Conventions

- Color values are stored as tables with `r`, `g`, `b` (and optional `a`) fields — `ApplyDefaults` treats these as leaf values, not subtables to recurse into.
- Movable UI elements use a lock/unlock pattern: when unlocked, the frame is draggable and shows controls; when locked, mouse interaction is disabled.
- The addon targets WoW API for Interface version 120000 (The War Within, 12.0). All API calls are Blizzard's standard Lua API (C_Timer, C_TradeSkillUI, C_QuestLog, etc.).
- No external library dependencies (no Ace3, LibDBIcon, etc.) — everything is self-contained.
- `issecretvalue()` is a real WoW API function — it detects "secure" values that cannot be used in calculations during combat (due to Blizzard's combat lockdown restrictions). Not currently used in this addon but may appear in related projects.
- Showing and hiding frames in combat should be done with UnregisterStateDriver and RegisterStateDriver. RegisterStateDriver is used to show/hide frames in combat, while UnregisterStateDriver is used to unregister the driver when the frame is no longer needed.
- `COMBAT_LOG_EVENT_UNFILTERED` must not be used — it is restricted to Blizzard UI only and will produce a blocking error for third-party addons.
- `UNIT_SPELLCAST_INTERRUPTED` provides `(unitTarget, castGUID, spellID, interruptedBy, castBarID)` as of Patch 12.0.0. However, the `interruptedBy` GUID is a **secret value** during combat (`issecretvalue()` returns true), making it unreadable by addons. The event still fires and confirms an interrupt occurred, but the interrupter cannot be identified directly.

## API Documentation

The `docs/` folder contains WoW API documentation extracted directly from the in-game client. **Always consult `docs/index.md` and the linked files in the `docs/` folder first for all WoW API lookups and research.** This is the most accurate source of information as it was taken from in-game documentation and reflects the actual available API for the current client version.

## Daily prompts

Could you do an in depth code review of this entire addon? Look for performance issues, code readability, and potential improvements. Also, please check for any potential memory leaks and optimize the code to reduce memory usage. Write the results and replace .clause\codreview.md

Could you take a look at the addon and suggest possible features that could be added in future, give an estimation of ease of use. Write the results and replace .clause\features.md

Could you write a short bulleted change log, for the last release no need to get to detailed don't include any minor fixes. Write the results and replace .claude\changeLog.md
