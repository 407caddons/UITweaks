# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LunaUITweaks is a World of Warcraft 12.0 (retail) addon that provides UI enhancements: a custom objective tracker, talent change reminders, auto-repair/durability warnings, loot toast notifications, a combat timer, custom layout frames, personal order alerts, AH filtering, action bar skinning, a custom cast bar, chat skinning, an interrupt cooldown tracker, info widgets, and addon version checking. Published to CurseForge (project ID 1450486).

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

Three persistent tables declared in the TOC:
- **`UIThingsDB`** — All module settings, organized by module key (`tracker`, `vendor`, `loot`, `combat`, `frames`, `misc`, `minimap`, `talentReminders`, `widgets`, `kick`, `chatSkin`, `castBar`, `actionBars`, `addonComm`, `reagents`)
- **`LunaUITweaks_TalentReminders`** — User-created talent reminder definitions (separate so they survive settings resets)
- **`LunaUITweaks_ReagentData`** — Cross-character reagent inventory data (separate so accumulated scan data survives settings resets)

Settings are accessed directly (e.g., `UIThingsDB.vendor.autoRepair`). Defaults are defined in Core.lua's `DEFAULTS` table and merged via `ApplyDefaults()`, which skips keys that already exist and treats tables with an `r` field as color values (not recursed into).

### Event-Driven Pattern

Modules create frames, register WoW events, and respond in `OnEvent` handlers. Common pattern:

```lua
local frame = CreateFrame("Frame")
frame:RegisterEvent("EVENT_NAME")
frame:SetScript("OnEvent", function(self, event, ...) ... end)
```

### Settings Update Flow

The config system is split across multiple files: `config/ConfigMain.lua` creates the window and tab navigation, `config/Helpers.lua` provides shared UI factories, and `config/panels/*.lua` contain individual module settings panels (one file per tab). Each panel's setup function is registered as `addonTable.ConfigSetup.ModuleName(panel, tab, configWindow)`. When a user changes a setting, the panel writes to `UIThingsDB` and calls the module's `UpdateSettings()` function to apply changes immediately without reload.

### Frame Pooling

Loot.lua and Frames.lua use object pools — frames are hidden and recycled via `AcquireToast()`/`RecycleToast()` or equivalent instead of being destroyed/recreated.

### Core Utilities

- `addonTable.Core.SafeAfter(delay, func)` — pcall-wrapped `C_Timer.After`
- `addonTable.Core.Log(module, msg, level)` — Colored chat logging. Levels: `DEBUG=0`, `INFO=1`, `WARN=2`, `ERROR=3`. Current threshold is INFO.

## File Responsibilities

| File | Module Key | Purpose |
|---|---|---|
| Core.lua | `Core` | Initialization, defaults, logging, timer utility |
| config/ConfigMain.lua | `Config` | Config window shell, tab navigation, panel wiring |
| config/Helpers.lua | `ConfigHelpers` | Shared UI helpers (font dropdowns, section headers, color swatches) |
| config/panels/*.lua | `ConfigSetup.*` | Individual settings panels, one per module |
| ObjectiveTracker.lua | `ObjectiveTracker` | Custom quest/WQ/achievement tracker with super-track restore |
| MinimapButton.lua | `Minimap` | Draggable minimap button |
| MinimapCustom.lua | — | Custom minimap frame (shape, border, zone text, clock) |
| Vendor.lua | `Vendor` | Auto-repair, sell greys, durability warnings |
| Loot.lua | `Loot` | Loot toast notifications with quality filtering and item level |
| Combat.lua | `Combat` | In-combat duration display (MM:SS) |
| Misc.lua | `Misc` | Personal order alerts (with TTS), AH expansion filter, SCT, auto-invite |
| Frames.lua | `Frames` | User-created colored rectangles for UI layout |
| TalentReminder.lua | `TalentReminder` | Zone-based talent/spec change alerts |
| ActionBars.lua | `ActionBars` | Action bar skinning, button spacing/sizing, bar offsets |
| CastBar.lua | `CastBar` | Custom player cast bar replacing Blizzard's |
| ChatSkin.lua | `ChatSkin` | Chat frame skinning, keyword highlighting, timestamps |
| Kick.lua | `Kick` | Party interrupt cooldown tracker with group frame attachment |
| EventBus.lua | `EventBus` | Single-frame centralized event dispatcher for all modules |
| AddonComm.lua | `AddonComm` | Centralized addon communication message bus |
| Reagents.lua | `Reagents` | Cross-character reagent tracking with tooltip display |
| AddonVersions.lua | `AddonVersions` | Group addon version checking and display |
| widgets/Widgets.lua | `Widgets` | Widget framework: creation, positioning, lock/unlock |
| widgets/*.lua | — | Individual widgets (FPS, bags, spec, durability, hearthstone, etc.) |

## EventBus (Centralized Event Dispatcher)

`EventBus.lua` provides a single-frame centralized event dispatcher that replaces the per-module pattern of creating individual frames and registering events. It loads after Core.lua and before all feature modules.

### Architecture
- Uses a single `CreateFrame("Frame", "LunaUITweaks_EventBus")` frame to handle all WoW events
- Maintains a `listeners[eventName] = { callback, ... }` registry
- Automatically registers/unregisters WoW events on the frame as listeners are added/removed
- Dispatch uses a snapshot copy of the listener array so callbacks can safely unregister themselves mid-dispatch

### API

```lua
-- Subscribe to a WoW event
-- callback receives: callback(event, ...)
addonTable.EventBus.Register(event, callback)

-- Unsubscribe a specific callback (reference equality)
addonTable.EventBus.Unregister(event, callback)

-- Subscribe to a unit event with automatic unit filtering
-- Returns the wrapper function (needed to Unregister later)
local wrapper = addonTable.EventBus.RegisterUnit(event, unit, callback)
```

### Usage Pattern
Modules should use EventBus instead of creating their own event frames:

```lua
local EventBus = addonTable.EventBus

local function OnPlayerLogin(event, ...)
    -- initialize module
end
EventBus.Register("PLAYER_LOGIN", OnPlayerLogin)
```

### Current Consumers
Most modules use EventBus for event handling, including Loot, QuestAuto, Kick, AddonComm, Combat, Vendor, Misc, ChatSkin, ActionBars, TalentReminder, Reagents, AddonVersions, widgets, and others.

## AddonComm (Inter-Addon Communication)

`AddonComm.lua` provides a centralized message bus for addon-to-addon communication over WoW's `C_ChatInfo.SendAddonMessage` system. It handles message routing, rate limiting, deduplication, and legacy prefix compatibility.

### Message Format
Messages use the unified prefix `"LunaUI"` with a structured format: `MODULE:ACTION:PAYLOAD`

- **MODULE** — uppercase namespace (e.g., `"VER"`, `"KICK"`)
- **ACTION** — uppercase action name (e.g., `"HELLO"`, `"CD"`, `"REQ"`, `"SPELLS"`)
- **PAYLOAD** — optional data string

### Legacy Compatibility
Two legacy prefixes are still supported for backwards compatibility with older addon versions:
- `"LunaVer"` — mapped to `VER:HELLO` or `VER:REQ`
- `"LunaKick"` — mapped to `KICK:CD`

`Comm.Send()` accepts optional `legacyPrefix` and `legacyMessage` parameters to dual-send in both new and legacy formats.

### Built-in Protections
- **Rate limiting** — `MIN_SEND_INTERVAL` (1.0s) per `module:action` key prevents message flooding
- **Deduplication** — `DEDUP_WINDOW` (1.0s) ignores duplicate messages from the same sender
- **Hide from world** — `UIThingsDB.addonComm.hideFromWorld` suppresses all sends
- **Periodic cleanup** — Expired dedup/rate-limit entries are purged every 20 messages

### API

```lua
-- Register a handler for incoming messages
-- callback receives: callback(senderShort, payload, senderFull)
addonTable.Comm.Register(module, action, callback)

-- Send a message to the group (returns false if suppressed)
addonTable.Comm.Send(module, action, payload, legacyPrefix, legacyMessage)

-- Check if communication is allowed (in group + not hidden)
addonTable.Comm.IsAllowed()

-- Get current channel ("RAID", "PARTY", or nil)
addonTable.Comm.GetChannel()

-- Schedule a throttled broadcast (cancels pending for same key)
addonTable.Comm.ScheduleThrottled(key, delay, func)

-- Cancel a pending throttled broadcast
addonTable.Comm.CancelThrottle(key)
```

### Current Message Types

| Module | Action | Direction | Purpose |
|--------|--------|-----------|---------|
| `VER` | `HELLO` | Send/Receive | Broadcast addon version to group |
| `VER` | `REQ` | Send/Receive | Request version info from group members |
| `KICK` | `CD` | Send/Receive | Broadcast interrupt cooldown status |
| `KICK` | `SPELLS` | Send/Receive | Share available interrupt spell list |
| `KICK` | `REQ` | Send/Receive | Request interrupt data from group |

### Integration with EventBus
AddonComm listens for `CHAT_MSG_ADDON` via EventBus (not its own frame), keeping event registration centralized:

```lua
addonTable.EventBus.Register("CHAT_MSG_ADDON", function(event, ...)
    OnAddonMessage(...)
end)
```

## Combat-Safe Frame Positioning (ActionBars Pattern)

Blizzard's edit mode system frames (action bars, chat frames, etc.) have fully protected positioning methods during `InCombatLockdown()`. The addon uses a three-layer strategy developed in ActionBars.lua:

### Layer 1: SetPointBase / ClearAllPointsBase
Edit mode system frames override `SetPoint`/`ClearAllPoints` with secure versions. Use the `Base` variants (`SetPointBase`/`ClearAllPointsBase`) to bypass the edit mode layer and directly position the frame. Fall back to standard methods if Base doesn't exist:
```lua
local clearPoints = barFrame.ClearAllPointsBase or barFrame.ClearAllPoints
local setPoint = barFrame.SetPointBase or barFrame.SetPoint
```

### Layer 2: hooksecurefunc on SetPointBase
Hook the bar's `SetPointBase` method so that whenever Blizzard re-layouts the frame (edit mode, zone changes, etc.), the hook fires and re-applies our offset on top. Use a `suppressHook` flag to prevent infinite recursion from our own positioning calls.

### Layer 3: SecureHandlerStateTemplate
Create a `SecureHandlerStateTemplate` frame per bar with `SetFrameRef` pointing to the protected frame. Store original position + offsets as attributes. Register a state driver (`[combat] combat; nocombat`) that fires a restricted Lua snippet on combat transitions. The restricted environment can call `SetPoint`/`ClearAllPoints` on protected frame handles even during combat.

### Initialization Timing
Run `ApplySkin()` immediately on `PLAYER_ENTERING_WORLD` (not delayed) to beat combat start. Then run again after 1.5s as a followup to catch bars Blizzard laid out late. If reloading in combat, defer everything to `PLAYER_REGEN_ENABLED` and wipe stale `originalBarPositions`/`originalButtonPositions` so fresh positions are captured.

### General Rules for Protected Frames
- Always check `InCombatLockdown()` before calling `SetPoint`, `ClearAllPoints`, `SetParent`, `SetSize`, `Show`, `Hide`, `RegisterStateDriver`, or `UnregisterStateDriver` on Blizzard-owned frames.
- Addon-created frames (not inheriting from secure templates) are safe to position anytime.
- Use `RegisterStateDriver(frame, "visibility", "hide"/"show")` for combat-safe show/hide — but the `RegisterStateDriver` call itself must happen out of combat.

### Config Navigation Order

The config window tabs in `ConfigMain.lua` are ordered by module ID. **Addon Versions must always remain the last tab** in the navigation list. When adding new modules, insert them before Addon Versions and increment its ID accordingly.

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

## Daily prompts (3)

Each of these prompts may have been done already today, if so could you not remove them and use them as a baseline for your review. If anything has fixed or been changed mark it as such in the file.

1. Could you do an in depth code review of this entire addon? Look for performance issues, code readability, and potential improvements. Also, please check for any potential memory leaks and optimize the code to reduce memory usage. Write the results to .clause\codereview.md.

2. Could you take a look at the addon and suggest possible features that could be added in future, give an estimation of ease of use. Write the results to .clause\features.md

3. Can you give me 20 ideas for widgets and improvements to existing ones, give an estimation of ease of use. Write the results to .clause\widgets.md
