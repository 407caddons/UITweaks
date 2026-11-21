# CLAUDE.md

Be surgical with updates and only change the specific section of code required and no other.

## Project Overview

LunaUITweaks is a World of Warcraft 12.0 (retail) addon providing UI enhancements: quest reminders, quest auto-accept, talent change reminders, talent loadout manager, auto-repair/durability warnings, loot toast notifications, combat timer, custom layout frames, personal order alerts, AH filtering, custom cast bar, M+ dungeon timer, map coordinates, info widgets, damage meter, XP/rep bar, queue timer, warehousing/bank management, addon version checking, performance profiler, and mini-games. Published to CurseForge (project ID 1450486).

## Build & Release

No build step. Pure Lua loaded directly by the WoW client.

- **Regression tests:** `tests/*.lua` are standalone Lua scripts with WoW API stubs. Run each from the repository root, e.g. `lua tests/event_bus_regressions.lua`. They need Lua 5.2+ or LuaJIT (`xpcall` with arguments). Many tests load a module with a hand-built `addon` table, so a module that starts using a new shared helper (e.g. `addon.Secret`) needs that helper added to its test.

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
- **`LunaUITweaks_TalentReminders`** — User talent builds, shared by Talent Reminders and the Talent Builds panel: `reminders[instanceID][difficultyID][zoneKey] = { build, ... }`. Uncategorized builds live at `[0][0][0]`; one per class/spec can carry `defaultFor = "dungeon"` or `"raid"`, checked in instances with no saved build for that spec at that difficulty (`TalentReminder.SetDefaultBuild` / `GetDefaultBuild`)
- **`LunaUITweaks_ReagentData`** — Cross-character reagent inventory data
- **`LunaUITweaks_QuestReminders`** — User quest reminder definitions
- **`LunaUITweaks_WarehousingData`** — Bank/warehouse item tracking data
- **`LunaUITweaks_CharacterData`** — Central character registry

Defaults in Core.lua's `DEFAULTS` table, merged via `ApplyDefaults()`. Tables with an `r` field are treated as color values (leaf, not recursed into).

### Settings Update Flow

Config is the load-on-demand `LunaUITweaks_Config` addon: `config/ConfigMain.lua` (window + nav), `config/panels/*.lua` (one panel per tab); shared factories are in the main addon's `ConfigHelpers.lua`. Panel setup registered as `addonTable.ConfigSetup.ModuleName(panel, tab, configWindow)`. Changes write to `UIThingsDB` and call the module's `UpdateSettings()` immediately.

### Config Visual Style

The configuration UI uses a flat charcoal-and-mint style. Keep future panels consistent with this style instead of introducing a separate skin. The current implementation lives in `LunaUITweaks_Config/config/Theme.lua`, exposed as `addonTable.ConfigTheme`; it loads before panel files in the config addon's TOC. Shared control factories live in root-level `ConfigHelpers.lua`.

#### Palette and typography

All colors below are WoW RGB values in the range 0–1; surfaces are opaque unless otherwise specified.

| Element | RGB / alpha |
|---|---|
| Window background | `.055, .075, .095` |
| Section card | `.09, .115, .14` |
| Input background | `.045, .065, .085` |
| Text button background | `.11, .16, .19` |
| Surface border (1 px) | `.19, .25, .29` |
| Section heading / slider thumb / selection marker | `.35, .9, .76` |
| Window title | `.45, .95, .8` |
| Selected navigation text | `.55, 1, .85` |
| Normal navigation text | `.8, .85, .9` |
| Disabled navigation text | `.48, .53, .59` |
| Input text | `.9, .94, .97` |
| Button hover | `.35, .9, .76`, alpha `.17` |

Use Luna's font objects (`LunaFontNormalHuge` etc., see `utils/Style.lua`; same sizes as the Blizzard `GameFont*` objects but in the global font): `LunaFontNormalHuge` for page titles, `LunaFontNormalLarge` for the window title and shared section headers, `LunaFontNormal` for card headings, and highlight/disabled small fonts for descriptions and hints. Prefer mint section headings and muted disabled navigation over the old gold/red navigation colors. Preserve semantic colors in content such as item quality, errors, and enabled/disabled ability rows.

#### Window, navigation, and spacing

- The shell is a plain frame styled by `Theme.Window`, currently 920 × 710, centered, draggable, clamped to screen, and on `DIALOG` strata. Its title is `LUNA  /  SETTINGS`; Escape closes it through `UISpecialFrames`.
- The sidebar is 220 px wide with 30 px navigation rows. Search filters page names, keeps original page IDs, and resets sidebar scrolling. Selected pages have a 3 × 22 px mint marker and a tinted highlight; disabled pages use muted text.
- Content begins at sidebar width + 10 px, 50 px below the window top. Use roughly 12–20 px outer padding and 12 px inner card padding.
- **Reserve the scrollbar gutter.** Standard panel scroll frames end 30 px inside the right edge. Reset Defaults buttons are 120 × 22 and must anchor at `TOPRIGHT, -36, -6`, not `-6, -6`. Use `Helpers.CreateResetButton`; Warehousing currently has a separate reset button using the same inset.
- Group related settings into labeled sections/cards. Use two columns when labels and controls fit comfortably; retain vertical scrolling for long pages. Do not compress text to force a two-column layout.
- `CompactGroupFinderPanel.lua` is the current grouped-layout example: a full-width Layout card, then Group Details and Leader & Members cards side by side. Most other panels retain their existing layouts with shared styling; do not assume all pages have been redesigned.

#### Applying the theme

- `Theme.Card(panel, title, x, y, width, height)` draws a background and heading; it is decorative, not a child container or automatic layout system. Position controls separately and leave space below the heading.
- `Theme.Navigation(button)` installs selection styling and `button.RefreshTheme`. Set `button.selected` and use `Helpers.UpdateModuleVisuals` for enabled state so theme colors remain consistent.
- `Theme.SkinTree(root)` styles checkboxes, edit boxes, text buttons, and slider thumbs within the config window. It tracks styled frames and revisits descendants on show to handle controls created dynamically. Explicitly call it after creating controls inside an already-visible panel if those controls otherwise miss the show traversal.
- Existing Blizzard control templates can still supply behavior; the theme replaces their visual treatment. Preserve control scripts, checked/disabled states, tooltips, icon buttons, color swatches, and meaningful list-row colors. Avoid global hooks or reskinning unrelated game UI.
- Solid slider thumbs must not retain the padded dimensions of Blizzard's original artwork: horizontal setting sliders use an 8 × 14 px thumb; vertical scrollbar thumbs use an 8 px width while retaining their existing height.
- Keep reusable visual changes in `Theme.lua` or shared helpers rather than duplicating styling in each panel. No generated image assets or external UI libraries are required; surfaces use `WHITE8X8` textures and 1 px borders.
- Verify changes in-game with `/reload`: check scrolling, reset-button clearance, long labels, selected/disabled navigation, search, and dynamically added controls. Lua syntax checks cannot verify visual placement.

### Core Utilities

- `addonTable.Core.SafeAfter(delay, func)` — pcall-wrapped `C_Timer.After`
- `addonTable.Core.Log(module, msg, level)` — Colored chat logging. Levels: `DEBUG=0`, `INFO=1`, `WARN=2`, `ERROR=3`
- `addonTable.Core.AbbreviateNumber(value)` — e.g. 1500000 → "1.5M"

## File Responsibilities

| File | Module Key | Purpose |
|---|---|---|
| **Main addon — core** | | |
| compat/Client.lua | `Client` | Retail vs Forever (Camelot) detection; `Supports`/`SupportsWidget`/`SupportsQoL` feature gates |
| Core.lua | `Core` | Initialization, defaults, logging, timer utility, character registry, `LunaUITweaksAPI` |
| EventBus.lua | `EventBus` | Single-frame centralized event dispatcher for all modules |
| LayoutMode.lua | `LayoutMode` | Shared unlock/drag mode (`/lunalayout`). Built-in modules call `LayoutMode.RegisterModule(key, {setLocked, apply, combatLocked})` and `RegisterTarget` from their own files; companions use `LunaUITweaksAPI.RegisterLayoutParticipant` / `RegisterLayoutTarget` (signatures must stay stable — used by addons outside this repo) |
| Profiler.lua | `Profiler` | Performance profiling and CPU usage tracking (`/luit perf`) |
| Loaders.lua | `Config` (proxy) | Load-on-demand stubs for the Config and Games companions, game key-binding globals |
| SharedHelpers.lua | `ConfigHelpers` | Runtime-safe helpers shared by feature modules and the config addon |
| ConfigHelpers.lua | `ConfigHelpers` | Shared config UI factories (section headers, reset buttons, color pickers, font dropdowns) |
| utils/Style.lua | `Style` (also `LunaUITweaksAPI.Style`) | Global font (`UIThingsDB.general.font`, picker on General UI) and flat buttons. Use `LunaFont*` objects (copies of `GameFont*` with the global face) for Luna labels, `Style.Font()` as the face in `SetFont`, and wrap text buttons as `LunaUITweaksAPI.Style.Button(CreateFrame("Button", ..., "UIPanelButtonTemplate"))`. Per-module font pickers were removed; sizes stay per module |
| utils/Secret.lua | `Secret` | Secret-value helpers (`IsPublic`, `SafeUnitName`, `SafeUnitGUID`, `CanAccessValue`, …); use these instead of local copies |
| MplusData.lua | — | Static M+ dungeon data (mob force counts) for the M+ timer |
| **Main addon — features** | | |
| MinimapButton.lua | `Minimap` | Draggable minimap button |
| MinimapCustom.lua | — | Custom minimap frame (shape, border, zone text, clock, button drawer) |
| Vendor.lua | `Vendor` | Auto-repair, sell greys, durability and bag-space warnings |
| VendorBulkBuy.lua | `VendorBulkBuy` | Quantity dialog for merchant items (Shift-click unstackables, Alt-click any); paced `BuyMerchantItem` with currency/stock/bag-space limits (`vendor.bulkBuy`) |
| Loot.lua | `Loot` | Loot toast notifications with quality filtering and item level |
| Combat.lua | `Combat` | Combat timer, consumable reminders, auto combat logging |
| Misc.lua | `Misc` | Personal order alerts, AH filter, auto-invite, death/whisper/BoE alerts with TTS, tooltip tweaks |
| Frames.lua | `Frames` | User-created colored rectangles for UI layout |
| TalentReminder.lua | `TalentReminder` | Zone-based talent/spec change alerts |
| TalentManager.lua | `TalentManager` | Talent loadout management and switching |
| AddonComm.lua | `Comm` | Centralized addon communication message bus |
| DamageMeter.lua | `DamageMeter` | Session damage/healing meter using C_DamageMeter API |
| CastBar.lua | `CastBar` | Custom player and target cast bars replacing Blizzard's |
| FocusCastBar.lua | `FocusCastBar` | Focus target cast bar |
| AddonVersions.lua | `AddonVersions` | Group addon version checking and display |
| Reagents.lua | `Reagents` | Cross-character reagent tracking with tooltip display |
| QuestAuto.lua | — | Quest auto-accept and auto-turn-in |
| QuestReminder.lua | `QuestReminder` | Quest reminder notifications |
| XpBar.lua | `XpBar` | Custom XP bar with rested/pending fills and rep bar at max level |
| MplusTimer.lua | — | Mythic+ dungeon timer display |
| CustomEncounterTimers.lua | `CustomEncounterTimers` | User-defined encounter timers (first/interval, countdown, expiry sound) |
| EncounterBars.lua | `EncounterBars` | Encounter timeline, pull and break timer bars |
| Coordinates.lua | — | Map coordinates and waypoint list |
| Warehousing.lua | — | Bank/warehouse item management |
| QueueTimer.lua | `QueueTimer` | Queue wait timer display |
| Destroy.lua | `Destroy` | Disenchant helper: lists unusable/low-ilvl bag gear while resting with one-click disenchant |
| GearReview.lua | `GearReview` | Bag gear review against equipped item level (review hint, not an upgrade score) |
| TankDebuffs.lua | `TankDebuffs` | Player and co-tank debuff displays via Blizzard's AuraContainer |
| TankExternals.lua | `TankExternals` | Externals on you (Blizzard `EXTERNAL_DEFENSIVE` filter) and a group-cooldown spell list row, via AuraContainer; settings in `tankExternals`, page shared with Tank Debuffs |
| BuffAlerts.lua | `BuffAlerts` | Aura sound alerts via `C_UnitAuras.AddAuraSound`; owns the shared sound list |
| ProcAlerts.lua | `ProcAlerts` | Sound alerts on spell activation overlay (proc) glows |
| NameplateColors.lua | `NameplateColors` | Tank-threat coloring of Blizzard enemy nameplates |
| NameplateQuestMarks.lua | `NameplateQuestMarks` | Kill/loot icon, objective progress and a coloured outline (Luna's own textures; Blizzard's border and threat-coloured bar untouched) on nameplates of active-quest units, including world quests (settings in `nameplateColors.questMarks`) |
| NameplateCastTarget.lua | `NameplateCastTarget` | Red outline (outside the quest outline) on enemy nameplates while their cast targets you, via `UnitIsSpellTarget(unit, "player")` through `SetAlphaFromBoolean` (secret-safe); Retail and Forever (settings in `nameplateColors.castTarget`) |
| CooldownManager.lua | `CooldownManager` | Repositions Blizzard Cooldown Manager viewer icons/bars into custom grids |
| CompactGroupFinder.lua | `CompactGroupFinder` | Compact row layout for the Group Finder list |
| qualityOfLife/QualityOfLife.lua | `QualityOfLife` | QoL framework: settings, `Enabled()`, submodule registry |
| qualityOfLife/Cursor.lua | `QualityOfLife.Cursor` | Cursor ring |
| qualityOfLife/AutoOpen.lua | `QualityOfLife.AutoOpen` | Auto-open containers in bags (`/luitautoopen` diagnostics) |
| qualityOfLife/Convenience.lua | — | Skip cinematics, hide tutorials and talking head, unwrap collections |
| qualityOfLife/GameplayAlerts.lua | `QualityOfLife.GameplayAlerts` | Movement cooldown, Time Spiral, Gateway and battle-res alerts |
| qualityOfLife/SpellRanks.lua | `QualityOfLife.SpellRanks` | **Forever only** (Camelot TOC): orange outline + rank on action-bar spells below the highest known rank; chat list after login/reload (`qualityOfLife.spellRanks`) |
| qualityOfLife/TalentPoints.lua | `QualityOfLife.TalentPoints` | On-screen unspent talent points reminder out of combat; Retail `C_ClassTalents.HasUnspent*`, Forever `UnitCharacterPoints`/`GetUnspentTalentPoints` (`qualityOfLife.talentPoints`) |
| qualityOfLife/GroupBuffs.lua | `QualityOfLife.GroupBuffs` | Out-of-combat list of group members missing your buffs; per-class editable list (`qualityOfLife.groupBuffsList[CLASS]`, entries `{id, who=self/solo/group/tanks, on}`), rank-agnostic name match, reapply under `groupBuffsRefresh` minutes, pets ignored; secure click-to-cast icons. Editor in ConvenienceSections (General UI) |
| widgets/Widgets.lua | `Widgets` | Widget framework: creation, positioning, lock/unlock |
| widgets/*.lua | — | Individual widgets (FPS, bags, spec, durability, hearthstone, keystone, etc.) |
| **LunaUITweaks_Config** (load-on-demand) | | |
| Config.lua | — | Entry point for the config UI |
| config/ConfigMain.lua | `Config` | Config window shell, tab navigation, panel wiring |
| config/Theme.lua | `ConfigTheme` | Charcoal-and-mint config visual style |
| config/SettingsData.lua | `SettingsData` | Safe parser/validator for settings import strings (no code execution) |
| config/ForeverPanels.lua | — | Placeholder panels for features unavailable on Forever |
| config/panels/*.lua | `ConfigSetup.*` | Individual settings panels, one per module (`NameplatesPanel.lua` covers threat colours and quest marks) |
| **LunaUITweaks_Games** (load-on-demand) | | |
| games/Games.lua | `Games` | Mini-game framework and launcher |
| games/BarrelsModel.lua | `BarrelsModel` | Board/round logic for Barrels |
| games/*.lua | — | Individual games (Snek, Bombs, Gems, Cards, Tiles, Boxes, Slide, Lights, Blocks, Barrels) |
| **LunaUITweaks_Bags** | | |
| Bags.lua, Model.lua, Views.lua | — | Categorized combined bags and banks (`/luitbags`) |
| NewItems.lua, Deposit.lua, Config.lua | — | Session new-item tracking, Warband deposit, config panel |
| Marks.lua | — | Favorites / Vendor sections: per-character, per-exact-item (GUID) marks set by dropping on a section's "+" tile (Alt+right-click removes); Vendor items sold with greys via `LunaUITweaksAPI.BagsSellVendorItems` (called from Vendor.lua) |
| **LunaUITweaks_ActionBars** | | |
| ActionBars.lua, Layout.lua, Appearance.lua, Settings.lua | — | Prototype square action bars with precise layout (`/luitbars`) |
| Config.lua, Diagnostics.lua | — | Config panel and taint/state diagnostics report |

## EventBus

Single-frame centralized event dispatcher. Modules use this instead of creating their own event frames.

```lua
local EventBus = addonTable.EventBus
EventBus.Register(event, callback)           -- subscribe
EventBus.Unregister(event, callback)         -- unsubscribe (reference equality)
-- Unit events (UNIT_*): deliver only the listed units via RegisterUnitEvent frames.
-- Use these instead of Register for UNIT_* events; the shared bus frame would
-- otherwise receive the event for every unit (all nameplates and raid members).
EventBus.RegisterUnitEvent(event, unitOrUnits, callback, moduleName)  -- "player" or {"party1", ...}
EventBus.UnregisterUnitEvent(event, unitOrUnits, callback)           -- nil units = all
EventBus.RegisterUnit(event, unit, callback, moduleName)             -- legacy single-unit form
```

`EventBus.Unregister(event, callback)` also removes that callback's unit-filtered registrations.

## AddonComm

Centralized addon messaging over `C_ChatInfo.SendAddonMessage`. Prefix `"LunaUI"`, format `MODULE:ACTION:PAYLOAD`.

```lua
addonTable.Comm.Register(module, action, callback)            -- receive
addonTable.Comm.Send(module, action, payload, legacyPrefix, legacyMessage)  -- send
addonTable.Comm.IsAllowed()    -- in group + not hidden
addonTable.Comm.GetChannel()   -- "RAID", "PARTY", or nil
```

Legacy prefix `"LunaVer"` (addon version checks) is still supported for older clients.

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

Addon Versions **must always be the last tab**. Built-in modules occupy IDs 1–24 (ID 6 is unused since Kick was removed). Companion panels are inserted at 25, 26, … and Addon Versions shifts accordingly. When adding new built-in modules, insert before Addon Versions and increment its ID, plus the `24 + i` / `25 + #companionPanels` offsets in `ConfigMain.lua`.

Current tab order: 1=QuestReminder, 2=QuestAuto, 3=XpBar, 4=Combat, 5=CastBar, 7=MplusTimer, 8=Minimap, 9=Coordinates, 10=Frames, 11=DamageMeter, 12=Vendor, 13=Loot, 14=Notifications, 15=Reagents, 16=TalentManager, 17=Talent, 18=Misc, 19=Widgets, 20=Warehousing, 21=QueueTimer, 22=Destroy, 23=BuffAlerts, 24=CompactGroupFinder, then companions (including panels registered via `RegisterConfigPanel`, e.g. Cooldown Manager, Proc Alerts, Nameplate Colours), then AddonVersions (last=25+companions).

## LunaUITweaks-Specific Conventions

- Color values stored as `{ r, g, b, a }` — `ApplyDefaults` treats tables with an `r` field as leaf values
- Movable frames use lock/unlock pattern: unlocked = draggable; locked = mouse disabled
- No external library dependencies — everything self-contained
- `UNIT_SPELLCAST_INTERRUPTED` `interruptedBy` GUID is a secret value during combat — cannot be read by addons
- C_DamageMeter live combat fields (`sourceGUID`, `name`, `totalAmount`, `amountPerSecond`, `maxAmount`) are all secret — never copy to your own table

**Frame positioning migration status:**

Migrated to CENTER anchor ✓: `DamageMeter`, `Frames`, `Widgets`

Not yet migrated (dynamic GetPoint): `XpBar`, `CastBar`, `Combat`, `MinimapCustom`

## API Documentation

- `docs/` — WoW API docs extracted from the in-game client. **Consult `docs/index.md` first** for any WoW API lookup.
- `.api/` — Addon-specific API reference with caveats, secret-value warnings, and taint patterns. **Consult `.api/index.md` first** before using any WoW API. Add new APIs here when introduced.

## Daily Prompts (3)

Each of these prompts may have been done already today — use existing files as a baseline and mark changes.

1. In-depth code review: performance, readability, memory leaks. Write to `.claude/codereview.md`.
2. Suggest possible future features with ease estimates. Write to `.claude/features.md`.
3. 20 widget ideas and improvements with ease estimates. Write to `.claude/widgets.md`.
