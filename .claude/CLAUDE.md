# CLAUDE.md

This file provides guidance to Claude Code when working with LunaUITweaks.

@../.claude/CLAUDE.md

## Project Overview

LunaUITweaks is a World of Warcraft 12.0 (retail) addon providing UI enhancements: custom objective tracker, quest reminders, quest auto-accept, talent change reminders, talent loadout manager, auto-repair/durability warnings, loot toast notifications, loot checklist, combat timer, scrolling combat text (SCT), custom layout frames, personal order alerts, AH filtering, action bar skinning, custom cast bar, chat skinning, interrupt cooldown tracker, M+ dungeon timer, map coordinates, info widgets, damage meter, XP/rep bar, queue timer, warehousing/bank management, addon version checking, performance profiler, and mini-games. Published to CurseForge (project ID 1450486).

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
2. Calls `Initialize()` on Minimap, Frames, TalentReminder, Widgets, ChatSkin, QuestReminder, DamageMeter
3. Registers slash commands (`/luit`, `/luithings`) and Addon Compartment function
4. **Does NOT call `Config.Initialize()`** — the config window is built lazily on first open so companion addons can register their panels first

### Saved Variables

- **`UIThingsDB`** — All module settings by module key
- **`LunaUITweaks_TalentReminders`** — User talent reminder definitions
- **`LunaUITweaks_ReagentData`** — Cross-character reagent inventory data
- **`LunaUITweaks_QuestReminders`** — User quest reminder definitions
- **`LunaUITweaks_WarehousingData`** — Bank/warehouse item tracking data
- **`LunaUITweaks_CharacterData`** — Central character registry
- **`LunaUITweaks_LootChecklist`** *(per-character)* — Loot checklist tracking

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
| config/ConfigMain.lua | `Config` | Config window shell, tab navigation, panel wiring |
| config/Helpers.lua | `ConfigHelpers` | Shared UI helpers (font dropdowns, section headers, color swatches) |
| config/panels/*.lua | `ConfigSetup.*` | Individual settings panels, one per module |
| Config.lua | — | Legacy stub entry point for config (delegates to ConfigMain) |
| ObjectiveTracker.lua | `ObjectiveTracker` | Custom quest/WQ/achievement tracker with super-track restore |
| QuestReminder.lua | `QuestReminder` | Quest reminder notifications |
| QuestAuto.lua | — | Quest auto-accept and auto-turn-in |
| MinimapButton.lua | `Minimap` | Draggable minimap button |
| MinimapCustom.lua | — | Custom minimap frame (shape, border, zone text, clock) |
| Vendor.lua | `Vendor` | Auto-repair, sell greys, durability warnings |
| Loot.lua | `Loot` | Loot toast notifications with quality filtering and item level |
| LootChecklist.lua | — | Per-character loot checklist tracking |
| Combat.lua | `Combat` | In-combat duration display (MM:SS) |
| SCT.lua | `SCT` | Scrolling combat text |
| Misc.lua | `Misc` | Personal order alerts (with TTS), AH expansion filter, auto-invite |
| Frames.lua | `Frames` | User-created colored rectangles for UI layout |
| TalentReminder.lua | `TalentReminder` | Zone-based talent/spec change alerts |
| TalentManager.lua | `TalentManager` | Talent loadout management and switching |
| ActionBars.lua | `ActionBars` | Action bar skinning, button spacing/sizing, bar offsets |
| CastBar.lua | `CastBar` | Custom player cast bar replacing Blizzard's |
| ChatSkin.lua | `ChatSkin` | Chat frame skinning, keyword highlighting, timestamps |
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

Addon Versions **must always be the last tab**. Built-in modules occupy IDs 1–26. Companion panels are inserted at 27, 28, … and Addon Versions shifts accordingly. When adding new built-in modules, insert before Addon Versions and increment its ID.

Current tab order: 1=Tracker, 2=QuestReminder, 3=QuestAuto, 4=XpBar, 5=Combat, 6=SCT, 7=CastBar, 8=Kick, 9=MplusTimer, 10=ActionBars, 11=Minimap, 12=Coordinates, 13=Frames, 14=ChatSkin, 15=DamageMeter, 16=Vendor, 17=Loot, 18=Notifications, 19=Reagents, 20=TalentManager, 21=Talent, 22=Misc, 23=Widgets, 24=Warehousing, 25=QueueTimer, 26=LootChecklist, then companions, then AddonVersions (last).

## ObjectiveTracker Taint — Confirmed Root Cause

**Never call `UpdateContent()` synchronously from `UpdateSettings()`.**

`UpdateSettings()` is called directly from the `PLAYER_LOGIN` event handler (not deferred). If it calls `UpdateContent()` synchronously, that runs `ClearAllPoints()`/`SetPoint()` on addon-created `SecureActionButtonTemplate` pool buttons (`btn.ItemBtn`) while the game is still in its login initialization phase. This taints the shared Button prototype, causing `ADDON_ACTION_BLOCKED: Button:SetPassThroughButtons()` / `Frame:SetPropagateMouseClicks()` when Blizzard's map pin code runs later.

**Why deferred is safe:** All other `UpdateContent()` calls go through `ScheduleUpdateContent()` → `SafeAfter()` → `C_Timer.After()`. Timer callbacks run in a fresh, clean execution context — login-phase taint does not carry into them.

**Rule:** `UpdateSettings()` must not call `UpdateContent()` at all. Content updates happen through the event/timer system only.

## LunaUITweaks-Specific Conventions

- Color values stored as `{ r, g, b, a }` — `ApplyDefaults` treats tables with an `r` field as leaf values
- Movable frames use lock/unlock pattern: unlocked = draggable; locked = mouse disabled
- No external library dependencies — everything self-contained
- `UNIT_SPELLCAST_INTERRUPTED` `interruptedBy` GUID is a secret value during combat — cannot be read by addons
- C_DamageMeter live combat fields (`sourceGUID`, `name`, `totalAmount`, `amountPerSecond`, `maxAmount`) are all secret — never copy to your own table

**Frame positioning migration status:**

Migrated to CENTER anchor ✓: `DamageMeter`, `ChatSkin`, `Frames`, `Widgets`

Not yet migrated (dynamic GetPoint): `XpBar`, `CastBar`, `Combat`, `Kick`, `ObjectiveTracker`, `MinimapCustom`

## API Documentation

- `docs/` — WoW API docs extracted from the in-game client. **Consult `docs/index.md` first** for any WoW API lookup.
- `.api/` — Addon-specific API reference with caveats, secret-value warnings, and taint patterns. **Consult `.api/index.md` first** before using any WoW API. Add new APIs here when introduced.

## Daily Prompts (3)

Each of these prompts may have been done already today — use existing files as a baseline and mark changes.

1. In-depth code review: performance, readability, memory leaks. Write to `.claude/codereview.md`.
2. Suggest possible future features with ease estimates. Write to `.claude/features.md`.
3. 20 widget ideas and improvements with ease estimates. Write to `.claude/widgets.md`.
