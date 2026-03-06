# LunaUITweaks Code Review
_Last updated: 2026-03-05 (v1.22.0)_

## Overall Health: GOOD

The addon has a clean architecture — centralised EventBus, rate-limited AddonComm, good frame pooling in Loot.lua, and proper taint guards in DamageMeter and ActionBars. The main areas needing attention are a hardcoded debug flag left on in CastBar, inconsistent frame positioning (several modules not yet migrated to CENTER), and a few logic/edge-case bugs.

---

## Top 5 Issues

| # | Severity | File | Description |
|---|----------|------|-------------|
| 1 | **High** | CastBar.lua:30 | `CASTBAR_DEBUG = true` hardcoded — spams chat for all users |
| 2 | **High** | Misc.lua:139 | `issecretvalue(msg)` check on full loot message incorrectly suppresses BoE detection in combat |
| 3 | **High** | Misc.lua:327 | `keywordCache` never wiped when auto-invite is disabled — stale keywords persist |
| 4 | **Medium** | Vendor.lua:109 | Bag iteration hardcoded to bags 0–4 — misses reagent bag (slot 5) |
| 5 | **Medium** | Multiple | Frame position stored via dynamic `GetPoint` in XpBar, CastBar, Combat, Kick, ObjectiveTracker — inconsistent with CENTER convention |

---

## Module-by-Module Findings

### CastBar.lua
- **[High] Line 30 — `CASTBAR_DEBUG = true` hardcoded.**
  The flag is checked in all logging paths (`DBG`, `StartDebugTick`, the event handler), but it is never set to `false`. Every user sees `[CastBar]` debug messages in chat on every cast event.
  _Fix: Set `CASTBAR_DEBUG = false` before release, or gate on a saved variable._

- **[Low] ~Line 405 — Dynamic GetPoint position storage.**
  Drag-stop handler saves `point, x, y` from `GetPoint()`. Per convention all repositionable frames should store CENTER-relative offsets. Not yet migrated.

### Misc.lua
- **[High] Line 139 — `issecretvalue(msg)` on CHAT_MSG_LOOT message.**
  Chat message strings from loot events are NOT secret values — only certain GUID/sourceGUID fields are. This guard causes `ShowBoeAlert` to silently return early during any combat loot event, breaking BoE detection precisely when it matters most (boss kills, dungeon loot).
  _Fix: Remove this check. The `itemLink` extraction and `GetItemInfo` call below it are already safe._

- **[High] Line 327 — `keywordCache` not cleared on disable.**
  `UpdateAutoInviteKeywords()` inserts into `keywordCache` but `ApplyMiscEvents()` only unregisters the `CHAT_MSG_WHISPER` listener when auto-invite is disabled — it never wipes the cache. On re-enable, old and new keywords accumulate.
  _Fix: Call `table.wipe(keywordCache)` in the `else` branch of the auto-invite disable path in `ApplyMiscEvents()`._

- **[Low] Lines 403–408 — `ToggleQuickDestroy` initialised at module scope.**
  The hook is set at load time if `quickDestroy` is enabled, but `hooksecurefunc` cannot be unhooked so there is no cleanup if disabled later. The `quickDestroyHooked` flag prevents double-registration so this is safe as-is.

### Vendor.lua
- **[Medium] Line 109 — Hardcoded bag range `0, 4`.**
  `C_Container.GetContainerNumFreeSlots` is called for bags 0–4 only. The reagent bag occupies `Enum.BagIndex.ReagentBag` (index 5 in TWW). Free slots in the reagent bag are not counted, so the low-bag-space warning fires incorrectly when the player's only free slots are there.
  _Fix: Extend loop to `NUM_BAG_SLOTS` or include `Enum.BagIndex.ReagentBag` explicitly._

### XpBar.lua
- **[Low] ~Line 405 — Dynamic GetPoint storage.**
  Not yet migrated to CENTER-based positioning. Listed as pending in CLAUDE.md.

### Combat.lua
- **[Low] ~Line 85 — Dynamic GetPoint storage.**
  Not yet migrated to CENTER-based positioning.

### Kick.lua
- **[Low] Position storage — Dynamic GetPoint.**
  Not yet migrated to CENTER-based positioning.

### ObjectiveTracker.lua
- **[Low] Position storage — Dynamic GetPoint.**
  Not yet migrated to CENTER-based positioning (separate `point`/`x`/`y` fields).

### AddonComm.lua
- **[Low] Lines 90–91, 99–100 — Debug logging at level 0 (DEBUG) always active.**
  Every send and receive logs at `DEBUG` level. The default log threshold is `INFO (1)`, so these are suppressed in normal use. No action needed unless the threshold is lowered during debugging.

- **[Low] Lines 153–166 — Dedup cleanup every 20 messages.**
  Under heavy raid traffic this could accumulate a few hundred entries before cleanup. Acceptable in practice; a time-based ticker would be cleaner.

### ChatSkin.lua
- **[Medium] Lines 113–119 — Placeholder restoration is O(n²).**
  Each placeholder key is searched via `safeMsg:find()` inside a `pairs` loop. For a message with many links (rare) this is slow. For typical chat messages with 1–3 links the impact is negligible.

- **[Low] Lines 83–95 — Greedy link regex.**
  The pattern `|H.-|h.-|h` could mismatch on malformed or nested link sequences. Robust in practice for WoW's well-formed link format.

### ActionBars.lua
- **[Low] Lines 91–125 — MicroMenu layout patch.**
  The `collectedButtons` table is populated at hook time. If a button is reparented before the hook fires it may not be in the collection and `GetEdgeButton` falls back to the original (potential crash in unusual init order). Edge case only.

### TalentReminder.lua
- **[Low] Lines 38–50 — Event re-registration on every `ApplyEvents()` call.**
  Unregisters and re-registers all events on every settings save. Safe but wasteful. A dirty-flag pattern would avoid redundant churn.

### AddonVersions.lua
- **[Low] Lines 84–91 — Version string regex.**
  Works for standard semver strings but would break if a version string contained a pipe (`|`). WoW version strings don't use pipes so this is theoretical.

### config/ConfigMain.lua
- **[Low] OnHide auto-lock chain.**
  The module auto-lock logic is a long if-chain of per-module checks. Functionally correct but will require maintenance as modules are added. A registration-based callback pattern would scale better long-term.

### config/Helpers.lua
- **[Low] ~Line 26 — `DeepCopy` has no cycle detection.**
  If a table ever had circular references `DeepCopy` would loop infinitely. Not currently a risk in this codebase.

### MinimapCustom.lua
- ✅ Previously identified QueueStatusButton `hooksecurefunc` taint has been removed. No button prototype taint issues found.

### EventBus.lua
- ✅ Listener management is clean. Snapshot-copy dispatch prevents mid-dispatch mutation issues. No issues found.

### Loot.lua
- ✅ Frame pooling pattern is well-implemented. OnUpdate scripts are cleared on recycle. No memory leaks.

### Frames.lua
- ✅ Already uses CENTER-based positioning correctly.

### Reagents.lua
- ✅ Bag scan uses `C_Container` correctly and handles the reagent bag slot.

### DamageMeter.lua
- ✅ Secret value handling is thorough. Live combat path keeps tainted values as direct locals and uses only C-level API calls (SetMinMaxValues, SetValue, AbbreviateNumbers, UnitName). Post-combat path uses session IDs. No issues found.

### AddonComm.lua
- ✅ NPC-party check added — `HasRealGroupMembers()` prevents send attempts to follower-dungeon parties.

---

## Memory Management Summary

| Item | Status |
|------|--------|
| Loot.lua frame pool | ✅ Properly recycled |
| EventBus listener tables | ✅ Properly cleaned up on Unregister |
| ObjectiveTracker item pool | ✅ ReleaseItems() hides and reuses correctly |
| AddonComm dedup/rate-limit tables | ⚠️ Periodic cleanup (every 20 msgs) — acceptable |
| Misc.lua keywordCache | ❌ Not cleared on disable — fix needed |

## WoW-Specific Issues Summary

| Item | Status |
|------|--------|
| QueueStatusButton taint | ✅ Fixed |
| DamageMeter secret values | ✅ Handled correctly |
| Combat lockdown guards | ✅ Present throughout |
| COMBAT_LOG_EVENT_UNFILTERED | ✅ Not used |
| SetCVar uiScale override | ✅ Fixed (PLAYER_LOGIN + UIParent:SetScale only) |
| NPC party addon message error | ✅ Fixed (HasRealGroupMembers check) |
| Objective tracker header overlap | ✅ Fixed (GetStringHeight for all header types) |
