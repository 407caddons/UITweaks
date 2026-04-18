# CLAUDE.md

This file provides guidance to Claude Code when working with LunaUITweaks.

@../.claude/CLAUDE.md

## Project Overview

LunaUITweaks is a World of Warcraft 12.0 (retail) addon providing UI enhancements: quest reminders, quest auto-accept, talent change reminders, talent loadout manager, auto-repair/durability warnings, loot toast notifications, combat timer, custom layout frames, personal order alerts, AH filtering, custom cast bar, interrupt cooldown tracker, M+ dungeon timer, map coordinates, info widgets, damage meter, XP/rep bar, queue timer, warehousing/bank management, addon version checking, performance profiler, and mini-games. Published to CurseForge (project ID 1450486).

## Build & Release

No build step or test suite. Pure Lua loaded directly by the WoW client.

- **Release:** Push a git tag matching `v*` (e.g. `v0.15`) to trigger the GitHub Actions packager (`.github/workflows/release.yml`), which uses `BigWigsMods/packager@v2` to package and upload to CurseForge.
- **Local testing:** Reload the WoW client (`/reload`). Use `/luit` or `/luithings` in-game to open the config window.

## Architecture

### Module System

Each `.lua` file registers itself on the shared addon table:

```lua
local addonName, addonTable = ...
addonTable.ModuleName = {}
```

The TOC file (`LunaUITweaks.toc`) defines load order. **Core.lua loads first** and on `ADDON_LOADED`:
1. Applies default settings to `UIThingsDB` (recursive merge preserving existing user values)
2. Calls `Initialize()` on Minimap, Frames, TalentReminder, Widgets, QuestReminder, DamageMeter
3. Registers slash commands (`/luit`, `/luithings`) and Addon Compartment function
4. **Does NOT call `Config.Initialize()`** — the config window is built lazily on first open so companion addons can register their panels first

### Saved Variables

- **`UIThingsDB`** — All module settings by module key
- **`LunaUITweaks_TalentReminders`** — User talent reminder definitions
- **`LunaUITweaks_ReagentData`** — Cross-character reagent inventory data
- **`LunaUITweaks_QuestReminders`** — User quest reminder definitions
- **`LunaUITweaks_WarehousingData`** — Bank/warehouse item tracking data
- **`LunaUITweaks_CharacterData`** — Central character registry

Defaults in Core.lua's `DEFAULTS` table, merged via `ApplyDefaults()`. Tables with an `r` field are treated as color values (leaf, not recursed into).

### Settings Update Flow

Config: `config/ConfigMain.lua` (window + nav), `config/Helpers.lua` (shared factories), `config/panels/*.lua` (one panel per tab). Panel setup registered as `addonTable.ConfigSetup.ModuleName(panel, tab, configWindow)`. Changes write to `UIThingsDB` and call the module's `UpdateSettings()` immediately.

### Core Utilities

- `addonTable.Core.SafeAfter(delay, func)` — pcall-wrapped `C_Timer.After`
- `addonTable.Core.Log(module, msg, level)` — Colored chat logging. Levels: `DEBUG=0`, `INFO=1`, `WARN=2`, `ERROR=3`
- `addonTable.Core.AbbreviateNumber(value)` — e.g. 1500000 → "1.5M"

## File Responsibilities

| File | Module Key | Purpose |
|---|---|---|
| Core.lua | `Core` | Initialization, defaults, logging, timer utility |
| EventBus.lua | `EventBus` | Single-frame centralized event dispatcher for all modules |
| Profiler.lua | `Profiler` | Performance profiling and CPU usage tracking |
| MplusData.lua | — | Static M+ dungeon data (mob force counts) for the M+ timer |
| config/ConfigMain.lua | `Config` | Config window shell, tab navigation, panel wiring |
| config/Helpers.lua | `ConfigHelpers` | Shared UI helpers (font dropdowns, section headers, color swatches) |
| config/panels/*.lua | `ConfigSetup.*` | Individual settings panels, one per module |
| Config.lua | — | Legacy stub entry point for config (delegates to ConfigMain) |
| QuestReminder.lua | `QuestReminder` | Quest reminder notifications |
| QuestAuto.lua | — | Quest auto-accept and auto-turn-in |
| MinimapButton.lua | `Minimap` | Draggable minimap button |
| MinimapCustom.lua | — | Custom minimap frame (shape, border, zone text, clock) |
| Vendor.lua | `Vendor` | Auto-repair, sell greys, durability warnings |
| Loot.lua | `Loot` | Loot toast notifications with quality filtering and item level |
| Combat.lua | `Combat` | In-combat duration display (MM:SS) |
| Misc.lua | `Misc` | Personal order alerts (with TTS), AH expansion filter, auto-invite |
| Frames.lua | `Frames` | User-created colored rectangles for UI layout |
| TalentReminder.lua | `TalentReminder` | Zone-based talent/spec change alerts |
| TalentManager.lua | `TalentManager` | Talent loadout management and switching |
| CastBar.lua | `CastBar` | Custom player cast bar replacing Blizzard's |
| Kick.lua | `Kick` | Party interrupt cooldown tracker with group frame attachment |
| MplusTimer.lua | — | Mythic+ dungeon timer display |
| Coordinates.lua | — | Map coordinates display |
| XpBar.lua | `XpBar` | Custom XP bar with rested/pending fills and rep bar at max level |
| DamageMeter.lua | `DamageMeter` | Session damage/healing meter using C_DamageMeter API |
| AddonComm.lua | `Comm` | Centralized addon communication message bus |
| Reagents.lua | `Reagents` | Cross-character reagent tracking with tooltip display |
| Warehousing.lua | — | Bank/warehouse item management |
| QueueTimer.lua | `QueueTimer` | Queue wait timer display |
| AddonVersions.lua | `AddonVersions` | Group addon version checking and display |
| widgets/Widgets.lua | `Widgets` | Widget framework: creation, positioning, lock/unlock |
| widgets/*.lua | — | Individual widgets (FPS, bags, spec, durability, hearthstone, etc.) |
| games/Games.lua | `Games` | Mini-game framework and launcher |
| games/*.lua | — | Individual games (Snek, Bombs, Gems, Cards, Tiles, Boxes, Slide, Lights) |

## EventBus

Single-frame centralized event dispatcher. Modules use this instead of creating their own event frames.

```lua
local EventBus = addonTable.EventBus
EventBus.Register(event, callback)           -- subscribe
EventBus.Unregister(event, callback)         -- unsubscribe (reference equality)
local w = EventBus.RegisterUnit(event, unit, callback)  -- unit-filtered; returns wrapper for Unregister
```

## AddonComm

Centralized addon messaging over `C_ChatInfo.SendAddonMessage`. Prefix `"LunaUI"`, format `MODULE:ACTION:PAYLOAD`.

```lua
addonTable.Comm.Register(module, action, callback)            -- receive
addonTable.Comm.Send(module, action, payload, legacyPrefix, legacyMessage)  -- send
addonTable.Comm.IsAllowed()    -- in group + not hidden
addonTable.Comm.GetChannel()   -- "RAID", "PARTY", or nil
```

Legacy prefixes `"LunaVer"` and `"LunaKick"` still supported for older clients.

## Companion Addon API

`LunaUITweaksAPI` is a global table defined in Core.lua that companion addons (e.g. `LunaUITweaks_UnitFrames`) can use to inject tabs into the config window.

```lua
-- Call from companion ADDON_LOADED handler:
LunaUITweaksAPI.RegisterConfigPanel(key, name, icon, setupFunc)
-- setupFunc signature: function(panel, navBtn, configWindow)

-- Shared UI helpers (available after Helpers.lua loads):
LunaUITweaksAPI.Helpers  -- same as addonTable.ConfigHelpers
```

Because the config window is built lazily on first open, companion registrations made at ADDON_LOADED time are always processed before the window is created.

## Config Navigation Order

Addon Versions **must always be the last tab**. Built-in modules occupy IDs 1–22. Companion panels are inserted at 23, 24, … and Addon Versions shifts accordingly. When adding new built-in modules, insert before Addon Versions and increment its ID.

Current tab order: 1=QuestReminder, 2=QuestAuto, 3=XpBar, 4=Combat, 5=CastBar, 6=Kick, 7=MplusTimer, 8=Minimap, 9=Coordinates, 10=Frames, 11=DamageMeter, 12=Vendor, 13=Loot, 14=Notifications, 15=Reagents, 16=TalentManager, 17=Talent, 18=Misc, 19=Widgets, 20=Warehousing, 21=QueueTimer, then companions, then AddonVersions (last=22+companions).

## LunaUITweaks-Specific Conventions

- Color values stored as `{ r, g, b, a }` — `ApplyDefaults` treats tables with an `r` field as leaf values
- Movable frames use lock/unlock pattern: unlocked = draggable; locked = mouse disabled
- No external library dependencies — everything self-contained
- `UNIT_SPELLCAST_INTERRUPTED` `interruptedBy` GUID is a secret value during combat — cannot be read by addons
- C_DamageMeter live combat fields (`sourceGUID`, `name`, `totalAmount`, `amountPerSecond`, `maxAmount`) are all secret — never copy to your own table

**Frame positioning migration status:**

Migrated to CENTER anchor ✓: `DamageMeter`, `Frames`, `Widgets`

Not yet migrated (dynamic GetPoint): `XpBar`, `CastBar`, `Combat`, `Kick`, `MinimapCustom`

## API Documentation

- `docs/` — WoW API docs extracted from the in-game client. **Consult `docs/index.md` first** for any WoW API lookup.
- `.api/` — Addon-specific API reference with caveats, secret-value warnings, and taint patterns. **Consult `.api/index.md` first** before using any WoW API. Add new APIs here when introduced.

## Daily Prompts (3)

Each of these prompts may have been done already today — use existing files as a baseline and mark changes.

1. In-depth code review: performance, readability, memory leaks. Write to `.claude/codereview.md`.
2. Suggest possible future features with ease estimates. Write to `.claude/features.md`.
3. 20 widget ideas and improvements with ease estimates. Write to `.claude/widgets.md`.
