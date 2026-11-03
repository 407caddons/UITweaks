# LunaUITweaks Code Review — 2026-10-28

Baseline: previous review of 2026-04-23. Tags: **[NEW]** found this pass, **[OPEN]** carried over and still present, **[FIXED]** resolved since last review.

Scope this pass: core infrastructure (Core, EventBus, Profiler, Loaders, LayoutMode, Secret), every module added since April (NameplateColors, CooldownManager, TankDebuffs, BuffAlerts, ProcAlerts, qualityOfLife/*), hot paths in large modules (Combat, CastBar, DamageMeter, MplusTimer, XpBar, Misc, Loot, Warehousing, MinimapCustom), and the uncommitted working-tree diff (Bags, AutoOpen, Barrels wiring). TalentManager/TalentReminder/Reagents/Coordinates/Games were only checked at the event-registration level.

Heuristic global-leak scan: **clean** (only intentional `GetMinimapShape`, `SLASH_*`, `LunaUITweaks*` globals).

---

## 1. Bugs

### High

- **[FIXED 2026-10-28] Profiler.lua:91–106 — all timings displayed 1000× too small.** `debugprofilestop()` returns **milliseconds**, but `FormatTime(us)` and `SpikeColor(spike)` treat the value as microseconds (`/1000`). A 4 ms spike shows as `0.0ms` and is colored green; red needs a 5-*second* spike. The `/luit perf` window has effectively been useless for spotting spikes. Fix: drop the `/1000` in both helpers (and treat `ms >= 1000` as seconds).

- **[FIXED 2026-10-28 — capture now prefers `healthBar.r/g/b`; verify in-game] NameplateColors.lua:99–106 — "native" colour capture can record Luna's own override.** `AfterNativeColor` reads `healthBar:GetStatusBarColor()` after `CompactUnitFrame_UpdateHealthColor`. Blizzard's updater only calls `SetStatusBarColor` when the desired colour differs from its cached `healthBar.r/g/b`; since Luna changes the bar colour without touching that cache, later updates skip the setter and `GetStatusBarColor()` returns *Luna's* colour, which is then saved as native. When `State()` later returns nil (threat uncertain, unit becomes friendly, or the feature is disabled), `Apply` "restores" the stale tank colour. Fix: capture from `frame.healthBar.r/g/b` (Blizzard's intended colour) or skip capture when `native.applied` is true. *(Verify against 12.0's CompactUnitFrame.lua; the cache check has been there for many expansions.)*

- **[FIXED 2026-10-28 — Hide/UnregisterStateDriver deferred to PLAYER_REGEN_ENABLED when in combat] Combat.lua:1418 — `UnregisterStateDriver(reminderFrame, "visibility")` with no combat guard** in `ApplyReminderEvents()`. Reachable from the config panel and from `Combat.UpdateSettings()`. Disabling reminders in combat → `ADDON_ACTION_BLOCKED`.

- **[FIXED 2026-10-28 — uses Secret.SafeUnitName with a GUID→name cache filled when names are readable, falling back to "Someone"; role lookup secret-guarded] Misc.lua:292–296 — death TTS uses raw `UnitName(unitTarget)` in `gsub`.** Deaths happen in combat, when party/raid names can be secret. Use `addonTable.Secret.SafeUnitName(unitTarget, "Someone")`.

### Medium

- **[FIXED 2026-10-28 — passive scans and the `UNIT_AURA` subscription now only run while enabled; existing entries are not pruned] BuffAlerts.lua:499–511 — aura catalogue grows forever, even with the module disabled.** `UNIT_AURA` is registered unconditionally at file scope, and `ScanPlayerAuras()` writes every aura the player ever has (open world) into `UIThingsDB.buffAlerts.knownAuras`. That is unbounded SavedVariables growth for every user. Gate it on `db.enabled` (or on the config panel being open), and cap or prune the catalogue.

- **[FIXED 2026-10-28 — uses Secret.SafeUnitName with "Unknown" fallback] TankDebuffs.lua:175 — raw `UnitName(coTank)` concatenated into a title.** `UpdateUnits` runs on `GROUP_ROSTER_UPDATE`/`PLAYER_REGEN_ENABLED`, including inside instances. Use `Secret.SafeUnitName`.

- **[WITHDRAWN] DamageMeter.lua:135–156** — `FetchEntries` stores `C_DamageMeter` fields (CLAUDE.md lists them as secret) as table *values*, which 12.0 allows. They are only passed to `SetValue`, `SetMinMaxValues` and `SetFormattedText`, which accept secrets. The one place that does arithmetic and sorting (`FetchEnemyContributors`) is skipped in combat and checks `Public()` first. Not a bug; CLAUDE.md's "never copy" rule is stricter than needed ("never compare, do arithmetic on, or use as keys" is the real constraint).

- **[FIXED 2026-10-28 — RegisterUnit now delegates to RegisterUnitEvent; Unregister also clears unit registrations] EventBus.lua:118–131 — `RegisterUnit` contract is wrong.** The doc (and CLAUDE.md) says to pass the returned wrapper to `Unregister`, but `Register` stores `original = callback`, so `Unregister(event, wrapper)` never matches; only `Unregister(event, callback)` works. Dedup is by the original callback, so registering the same callback for two units silently drops the second. Only XpBar uses it today, so the impact is latent.

- **[KEPT 2026-10-29 — 12.0 docs list only the namespaced APIs, so these hooks are likely the only working ones; hooksecurefunc on API tables is not the frame/prototype taint case. Verify globals in-game before removing] Combat.lua:1133, 1156 — object-form `hooksecurefunc(C_Container, "UseContainerItem")` and `hooksecurefunc(C_Item, "UseItemByName")`.** These are object-form hooks on Blizzard namespace tables. The global-form fallbacks already exist at 1137/1154.

- **[FIXED 2026-10-29 — deferred to PLAYER_REGEN_ENABLED when in combat] MinimapCustom.lua:210–290 — `PositionMinimapIcons()` reparents and re-anchors Blizzard frames** (`MailFrame`, `CraftingOrderFrame`, `MinimapCluster.Tracking`, `AddonCompartmentFrame`, `InstanceDifficulty` at 130/146) with no `InCombatLockdown()` guard. It is called from 405/588/601, and `SetupMinimap` re-runs on *every* `PLAYER_ENTERING_WORLD`.

- **[FIXED 2026-10-29 — Secret.IsPublic checks before keys/match; stale entries kept when data is secret; player name cached via SafeUnitName] Loot.lua:431–460 — roster cache uses `UnitName(unit)`/`GetRaidRosterInfo` names as table keys.** It runs on roster changes, which can happen in combat.

### Low

- **[FIXED 2026-10-29 — test-only command removed] Loaders.lua:206–209** — the `/luitbarrels` slash command duplicates the `Barrels` proxy that the `gameModules` loop already creates. Harmless, but it is the only game with its own slash command; either add one for all games or drop it.
- **[FIXED 2026-10-29 — global published only from ApplyMinimapShape, i.e. while the custom minimap is enabled] MinimapCustom.lua:28** — the global `GetMinimapShape` is defined even when the custom minimap is disabled, which overrides any other addon's (SexyMap, etc.) definition. Define it only while `minimapEnabled`.
- **[FIXED 2026-10-29] MplusTimer.lua:1050–1052** — `unit:match(...)` on the `UNIT_FLAGS` argument is not secret-guarded (NameplateColors and AutoOpen guard the same pattern).
- **[FIXED 2026-10-28 — colour-only helper] Combat.lua:100–113** — `PLAYER_REGEN_DISABLED`/`ENABLED` call the full `Combat.UpdateSettings()` just to change text colour. That re-registers events, re-anchors, re-fonts, and runs `ApplyReminderEvents` twice per combat. Set the colour directly.
- **[REMOVED 2026-10-28 — time-to-die feature deleted; target health is secret in combat] Combat.lua:290–302** — `TtdOnUpdate` pushes samples even when `ttdEnabled == false` (the check is only in the display path). Each sample allocates a table, and `table.remove(t, 1)` is O(n).

---

## 2. Performance

The common theme is **high-frequency unit events routed through the single EventBus frame**. The bus frame cannot use `RegisterUnitEvent`. Once *any* module subscribes to `UNIT_AURA`, `UNIT_HEALTH`, `UNIT_FLAGS`, `UNIT_SPELLCAST_*`, or `UNIT_THREAT_*`, the bus receives that event for **every unit** (all nameplates, all raid members). Each event then costs one Profiler closure plus one `xpcall` per subscriber before the handler throws away non-player units.

| Event (unfiltered on bus) | Subscriber(s) | Notes |
|---|---|---|
| `UNIT_AURA` | BuffAlerts.lua:511 (**always**, even disabled), XpBar.lua:587, GameplayAlerts, WheeCheck | Thousands/sec in raids |
| `UNIT_HEALTH` | Misc.lua:860 (death TTS) | Fires per HP tick for every nameplate; handler then runs two `match` calls |
| `UNIT_SPELLCAST_SUCCEEDED` | GameplayAlerts.lua:496 | Every cast by every unit |
| `UNIT_SPELLCAST_STOP` / `CHANNEL_STOP` | AutoOpen.lua:139 | Same |
| `UNIT_FLAGS` | NameplateColors.lua:132 (**default enabled**), MplusTimer.lua:920 | |
| `UNIT_THREAT_LIST_UPDATE` / `UNIT_THREAT_SITUATION_UPDATE` | NameplateColors.lua:131 | See below |

**[DONE 2026-10-28 — added; BuffAlerts, XpBar, WheeCheck, GameplayAlerts, AutoOpen, Misc, MplusTimer and Destroy migrated. NameplateColors stays on the bus: its enemy units are unbounded nameplate tokens] Recommendation (architectural, highest value):** add `EventBus.RegisterUnitEvent(event, units, cb, module)`, backed by one small frame per (event, unit-set) using `frame:RegisterUnitEvent`, and move the subscribers above to it. Combat.lua (reminders) and CastBar already use dedicated `RegisterUnitEvent` frames correctly; generalize that pattern.

### Specific hot spots

- **[FIXED 2026-10-28 — enemy events recolour one plate; group threat/role/combat events coalesce to one full refresh per frame; tank candidates cached; closure removed. Bus subscriptions remain until RegisterUnitEvent] NameplateColors.lua:108–136 — O(events × plates × groupSize).** Every threat/flags event for *any* unit calls `Refresh()`, which walks *all* nameplates, and `State()` walks the whole raid (`UnitGroupRolesAssigned`, `UnitIsUnit`, `UnitThreatSituation`, plus spec lookups for the player) for each plate. It also creates a fresh `CheckTank` closure per call. In a 20-player raid with 15 plates, that is roughly 300 API calls per threat event, and threat events fire many times a second. The feature defaults to `enabled = true`. Fixes:
  1. For unit events, refresh only `C_NamePlate.GetNamePlateForUnit(unit)`.
  2. Cache the tank unit list on `GROUP_ROSTER_UPDATE`/`PLAYER_ROLES_ASSIGNED`/spec change, so `State` checks 1–2 tanks instead of 40 units.
  3. Coalesce the full `Refresh()` to at most once per frame.
  4. `AfterNativeColor` (line 104) allocates a new table on every `CompactUnitFrame_UpdateHealthColor` call; reuse the existing `nativeColors[frame]` table.

- **[FIXED 2026-10-28 — pending XP cached; aura events only redraw when the boost set changes; bursts coalesced per frame] XpBar.lua:360–363, 584–587 — full quest-log scan on every player aura change.** `OnXPUpdate → UpdateDisplay → GetPendingQuestXP()` iterates the quest log (`C_QuestLog.GetInfo` allocates a table per entry) on every `UNIT_AURA` for the player and every `QUEST_LOG_UPDATE`. Cache pending XP and recompute only on `QUEST_LOG_UPDATE`; on `UNIT_AURA`, recompute only the boost percentage; debounce both to around 0.2 s.

- **[FIXED 2026-10-28 — in combat only the 0.75 s OnUpdate renders; pending update flushed at combat end] DamageMeter.lua:1135–1146 — the event path defeats the 0.75 s throttle.** `DAMAGE_METER_COMBAT_SESSION_UPDATED` schedules `RenderAllPanes()` on the next frame every time it fires, in addition to the throttled OnUpdate at 1043. In combat, mark the meter dirty and let the 0.75 s OnUpdate render. `FetchEntries` also allocates one table per source per refresh; reuse a per-pane entries pool.

- **[FIXED 2026-10-28 — UNIT_HEALTH now delivered only for party1-4/raid1-40] Misc.lua:270–305 — move death TTS to a dedicated frame.** Use `RegisterUnitEvent("UNIT_HEALTH", "party1".."party4")` in parties, or `UNIT_FLAGS`/`UNIT_HEALTH` per raid unit; better still, detect deaths with `UnitIsDeadOrGhost` on `UNIT_FLAGS` only. Also, `deadCount` re-counts `pairs(deathAnnounced)` on each death; keep a counter.

- **[FIXED 2026-10-28 — kept for immediacy but filtered to player/party1-4] MplusTimer.lua:920 — `UNIT_FLAGS` subscription is redundant.** `OnTimerTick` already calls `ScanDeaths()` every 0.1 s. Dropping the `UNIT_FLAGS` registration removes a high-frequency event in M+ with no behaviour change.

- **[FIXED 2026-10-28] qualityOfLife/AutoOpen.lua — allocations in hot paths.**
  - `Busy()` (33, 36) builds two literal tables per call. It runs every frame during a scan and again before each use.
  - `OnEvent` (130) builds the `closes` map on every event, including frequent `ITEM_LOCK_CHANGED`, `BAG_UPDATE_COOLDOWN`, and `MODIFIER_STATE_CHANGED`.
  - `Eligible` (49) packs `{C_Item.GetItemInfo(...)}` per slot.

  Hoist the constant tables to file scope, and use `select(14, C_Item.GetItemInfo(id))`.

- **[PARTLY FIXED 2026-10-28 — lines table reused; gateway polling kept, it tracks range/usability] qualityOfLife/GameplayAlerts.lua:406–466** — `Refresh()` allocates a `lines` table and sorts it on every `SPELL_UPDATE_COOLDOWN` (coalesced at 0.05 s). For warlocks holding a Gateway Control Shard, `polling = true` keeps a 5 Hz ticker running permanently. Consider `BAG_UPDATE_COOLDOWN` plus `ACTIONBAR_UPDATE_USABLE` instead of polling.

- **[FIXED 2026-10-28 — unused Settings() call removed; SetShown only on change] qualityOfLife/Cursor.lua:547–559** — `Tick` calls `QoL.Settings()` twice per frame (the `db` local is unused), and each call runs `Client.SupportsQoL`. Cache the enabled flag in `UpdateSettings`.

- **[FIXED 2026-10-28] Warehousing.lua:1565** — listens to `BAG_UPDATE` (per-bag, many per loot) and cancels and recreates a `C_Timer.NewTimer` each time. Use `BAG_UPDATE_DELAYED`, as Vendor and Reagents do.

- **[FIXED 2026-10-28 — SetFormattedText; DBG formats left, they are per-event not per-frame] CastBar.lua:177, 202** — `castTimeText:SetText(string.format(...))` runs every frame while casting. Use `SetFormattedText` (no Lua string garbage), or update only when the 0.1 s bucket changes. The `DBG(string.format(...))` calls (136, 220, 251, 271, 279, 600 — 600 is per cast event) format even with `CASTBAR_DEBUG = false` **[OPEN]**.

- **[FIXED 2026-10-28 — per-group dirty flags] CooldownManager.lua:345–351** — any `OnShow`/`OnHide`/`RefreshLayout` on any viewer item re-lays out **all four** groups, allocating `items` and an entry table per icon each time. Buff icons flicker constantly in combat. Track a dirty flag per group.

- **[FIXED 2026-10-28 — find() gate; IsDuplicate prunes its key always, full sweep ≤1/s] Loot.lua:551–566** — `ParseLootMessage` allocates `{msg:match(pattern)}` for each loot-format pattern on every `CHAT_MSG_LOOT`. Use `local a, b, c = msg:match(...)` and test `a`. `IsDuplicate` prunes the whole table on each call **[OPEN]**.

- **[WON'T FIX — only allocates while profiling is on] Profiler.lua:49–73** — when enabled, each wrapped call allocates two `pack` tables and a closure. This is acceptable for a profiler, but it inflates the GC numbers it reports. `UpdateDisplay` also calls `UpdateAddOnMemoryUsage()` every 5 s, which is a known frame hitch.

---

## 3. Architecture / reorganization

1. **[FIXED 2026-11-02 — 35 files reformatted (13 main addon on 2026-11-01; config panels, Bags, ActionBars, Barrels on 2026-11-02); whitespace/line breaks only, token-verified] Two code styles in one codebase.** Older modules (Combat, CastBar, DamageMeter) are formatted, commented Lua. Newer ones (CooldownManager, LayoutMode, TankDebuffs, ProcAlerts, GameplayAlerts, AutoOpen, Cursor, Bags/*) are dense, minified style with multiple statements per line (`a=1; b=2`), no spaces, and 150+ character lines. This is the largest readability cost in the repo. Pick one style (the older formatted style matches CLAUDE.md's "reads like surrounding code") and reformat the newer files in a dedicated whitespace-only commit.

2. **[FIXED 2026-10-28 — Secret.IsPublic added; 10 local copies and QoL.Public now reference it] Duplicate secret-value helpers.** `utils/Secret.lua` exists, yet `Public()` is redefined locally in CooldownManager, NameplateColors, ProcAlerts, and `QoL.Public`, while other files call `issecretvalue` directly. Add `Secret.IsPublic(v)` and use it everywhere so there is one place to adapt when Blizzard changes the API.

3. **[FIXED 2026-10-29 — modules register setLocked/apply/combatLocked and their own targets; login re-apply only after a session ended in Layout Mode; companion API unchanged] LayoutMode knows every module's internals** (LayoutMode.lua:185–221, 270–321). It hard-codes DB keys (`combat.ttdLocked`, `castBar.focusBar.locked`, ...), global frame names, and a list of module `UpdateSettings` calls. Every new movable frame needs edits here. Invert the dependency: each module calls `LayoutMode.RegisterTarget` (already supported, and used by TankDebuffs, CooldownManager, and GameplayAlerts) plus a `RegisterLockHandler(fn)`. LayoutMode then iterates registrations. The same applies to `Apply()` re-running ~15 modules' `UpdateSettings` **on every login** (line 332, `LockAll` after 2 s), which duplicates each module's own init.

4. **[NEW] Inconsistent module bootstrap.** Some modules are initialised from Core's `ADDON_LOADED` (Minimap, Frames, TalentReminder, Widgets, QuestReminder, DamageMeter). Others self-register `PLAYER_LOGIN` with `SafeAfter(0.5|1, Init)` (Combat schedules four separate 1 s timers, and XpBar uses 0.5 s). Others register at file scope (BuffAlerts, NameplateColors, ProcAlerts). Standardise on `addonTable.RegisterModule{ name, Init, UpdateSettings, defaults }`, called by Core in TOC order. That also lets LayoutMode, Profiler, and reset buttons discover modules.

5. **[NEW] DEFAULTS is a ~530-line literal inside the `ADDON_LOADED` handler** (Core.lua:289–820). Move it to `Defaults.lua`, or better, let each module contribute its own defaults via the registration above, so module, defaults, and panel live together.

6. **[FIXED 2026-10-30 — moved to LunaUITweaks_Config/config/panels/NameplatesPanel.lua with the new quest marks section] Config UI leaking into runtime files.** NameplateColors.lua:148–184 builds its whole config panel inline in the always-loaded addon. That defeats the `LunaUITweaks_Config` load-on-demand split, and the panel does not use `Theme.Card` or the shared layout. Move it to `LunaUITweaks_Config/config/panels/NameplateColorsPanel.lua`, as CooldownManager and ProcAlerts already do via `addon.ConfigSetup.*`.

7. **[NEW] Sound registry lives in BuffAlerts.** ProcAlerts calls `addon.BuffAlerts.ResolveSound` and shares the custom-sound list. Extract `Sounds.lua` (presets, custom sounds, resolve, test) as a shared service; both alert modules then depend on it, not on each other.

8. **[NEW] EventBus API gaps.** Beyond the `RegisterUnitEvent` recommendation in section 2:
   - **[FIXED 2026-10-28 — Profiler now loads before LayoutMode]** Callbacks registered before Profiler.lua loads (EventBus → LayoutMode → **Profiler** in the TOC) are never profiled; move Profiler above LayoutMode.
   - `Register(event, cb)` without a module name skips profiling silently (XpBar.lua:592). Make the module name required.

9. **[FIXED 2026-10-29] CLAUDE.md is out of date.** It lists Kick.lua (removed), `config/ConfigMain.lua` (now under `LunaUITweaks_Config/`), and "no test suite" (there is a `tests/` directory of regression scripts). The file-responsibility table is missing NameplateColors, CooldownManager, TankDebuffs, BuffAlerts, ProcAlerts, GearReview, EncounterBars, CustomEncounterTimers, FocusCastBar, CompactGroupFinder, LayoutMode, qualityOfLife/*, and the Bags/ActionBars/Games companions. Stale docs mislead future sessions.

---

## 4. Uncommitted working-tree diff

- **Bags/Views.lua**: binding native item buttons to physical `bag:slot` keys (`slotButtons`), and giving the free-space tile its own button, is a clear improvement. It removes the save/restore of native `OnClick` that caused stale handlers. Looks correct. Note that `view.slotButtons` holds one button per physical slot per view (bank and warband tabs accumulate). That is bounded, so it is fine.
- **Bags/Model.lua**: Pets, Mounts, and Decor classification is fine. The `Enum` fallbacks (`15`/`2`/`5`) match current values. `Scan` still allocates an entry table for every slot, including empty ones, on each render (minor).
- **AutoOpen.lua**: the `useContainers` allow-list and `IsVisible` change are sound. See the allocation notes in section 2.
- **Loaders.lua / Snek.lua**: see the duplicate `/luitbarrels` note. Only Snek closes Barrels on open; the other eight games don't. Centralise "close other games" in the Games framework rather than adding it to each `ShowGame`.

---

## 5. Resolved since 2026-04-23

- **[FIXED]** All Kick.lua findings: the module has been removed.
- **[FIXED]** MinimapCustom QueueStatusButton prototype taint: it now uses `EventRegistry` callbacks and keeps Blizzard's parent; `AnchorQueueEyeToMinimap` is combat-guarded.
- **[FIXED]** EventBus error isolation: dispatch now `xpcall`s each subscriber, so one failing module no longer stops later listeners.

## Suggested order of work

1. Profiler unit fix (one-line, restores a working perf tool to measure everything else).
2. NameplateColors hot path and native-colour capture (default-on, affects every user in group content).
3. `EventBus.RegisterUnitEvent`, then migrate BuffAlerts, Misc, XpBar, GameplayAlerts, AutoOpen, NameplateColors, and MplusTimer.
4. BuffAlerts `knownAuras` growth; Combat `UnregisterStateDriver` guard; secret-safe names in Misc and TankDebuffs.
5. Architecture items 1–3 (style unification, `Secret.IsPublic`, LayoutMode inversion), done as separate no-behaviour-change commits.
