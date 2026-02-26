# LunaUITweaks — Code Review

**Date:** 2026-02-26
**Scope:** Full addon review — all Lua modules and widget files (~55 files, ~18,000+ lines)
**Reviewer:** Claude Sonnet 4.6

**Update 2026-02-26:** Comprehensive second pass covering all remaining files: XpBar, SCT, MplusTimer, Coordinates, QuestAuto, QuestReminder, Warehousing, the Widgets framework, and all widget files (Bags, Keystone, SessionStats, etc.). New findings merged with previous review. DamageMeter is confirmed as correctly implemented as a no-op stub per CLAUDE.md/MEMORY.md — the DamageMeter taint issues noted in earlier draft sessions are resolved/moot.

---

## Executive Summary

LunaUITweaks is a large, feature-rich WoW retail addon with generally good architecture. The EventBus centralized dispatcher, frame pooling, AddonComm message bus, and timer debouncing patterns are well-implemented. The DamageMeter module is correctly a no-op stub as required. However, several **critical taint violations** exist in ChatSkin.lua that exactly match the unsafe patterns documented in CLAUDE.md. There are performance concerns with EventBus snapshot allocation, per-widget OnUpdate overhead, and several modules making expensive API calls more often than needed. Warehousing.lua is the most complex and fragile module. Overall quality is high for a solo/small-team addon but the critical issues need addressing before a future Blizzard patch triggers them.

---

## Critical Issues

### 1. ChatSkin.lua — Unsafe Hook Forms (Taint Risk)

Per CLAUDE.md: *"Unsafe hooks: `hooksecurefunc(frame, 'Method', cb)` — frame-object form taints the frame"* and *"Never write fields onto Blizzard frames"*.

ChatSkin.lua violates both rules:

**Frame-object hook forms on Blizzard chat frames:**
```lua
-- Hooks on Blizzard chat background frame:
hooksecurefunc(bg, "SetAlpha", function(self, alpha) ... end)
bg.lunaHooked = true  -- writes field onto Blizzard frame

-- Hooks on Blizzard border textures:
hooksecurefunc(tex, "SetAlpha", function(self, alpha) ... end)
tex.lunaHooked = true  -- writes field onto Blizzard frame

-- Writes to Blizzard frame:
ChatFrame1ButtonFrame.lunaHooked = true
```

These `hooksecurefunc(frame, method, cb)` calls on Blizzard-owned frames use the unsafe object form which taints the frame table. Writing `.lunaHooked` onto Blizzard frame tables compounds the issue. The correct approach is to use a side table: `local hookedFrames = {}` and `hookedFrames[frame] = true`.

**Direct global function replacement:**
```lua
SetItemRef = function(...)  -- directly replaces the global
```
This should be `hooksecurefunc("SetItemRef", cb)` (global form, not frame-object form). Direct assignment silently replaces the function for all other code that depended on the original.

**Recommended fix:** Use `local hookedFrames = {}` for tracking hooked state. Replace `SetItemRef =` with `hooksecurefunc("SetItemRef", ...)`. Review whether the `SetAlpha` hook approach can be replaced with a non-hook alternative.

---

### 2. MinimapCustom.lua — Repeated Global Function Redefinition

```lua
-- Inside ApplyMinimapShape(), called multiple times:
function GetMinimapShape() return "SQUARE" end
```

This redefines a global WoW API function inside a function body. Each call to `ApplyMinimapShape()` creates a new function object and replaces the global. Blizzard internal code and other addons that call `GetMinimapShape()` may get unexpected results. The definition should be at file scope, set once after load.

---

### 3. ActionBars.lua — Writing Fields onto Blizzard Action Buttons

```lua
-- In SkinButton:
button.lunaSkinOverlay = CreateFrame(...)
```

Writing custom fields onto Blizzard action button frame tables is a taint risk per CLAUDE.md: *"Never write fields onto Blizzard frames"*. Use a module-level side table instead:

```lua
local skinOverlays = {}
skinOverlays[button] = CreateFrame(...)
```

---

### 4. Coordinates.lua — `HookScript` on Chat Edit Boxes

```lua
box:HookScript("OnKeyDown", function(self, key) ... end)
```

CLAUDE.md documents: *"Unsafe hooks: `frame:HookScript('OnEvent', cb)` — taints frame context"*. The chat edit boxes are Blizzard-owned frames. While `OnKeyDown` is less dangerous than `OnEvent`, this still taints the edit box frame context. Consider an alternative approach for `/way` command interception.

---

## Performance Issues

### 5. EventBus.lua — Table Allocation on Every Event Dispatch

```lua
local snapshot = {}
for i = 1, n do snapshot[i] = subs[i] end
```

A new table is created on every event dispatch to allow safe mid-dispatch unregistration. For high-frequency events like `UPDATE_INVENTORY_DURABILITY`, `UNIT_AURA`, `BAG_UPDATE`, `PLAYER_REGEN_DISABLED/ENABLED`, and `PLAYER_ENTERING_WORLD`, this generates constant GC pressure. A pre-allocated reuse buffer with a `snapshotDepth` reentrancy guard would eliminate this allocation.

### 6. Combat.lua — `ScanConsumableBuffs` on `UNIT_AURA`

`UNIT_AURA` fires extremely frequently. `ScanConsumableBuffs` scans up to 40 aura slots per call. The existing `lastAuraScanTime` same-frame guard helps but the function still runs on every unique tick. Consider a 0.5s debounce `C_Timer.NewTimer` pattern instead of the frame-tick cache.

### 7. ActionBars.lua — `SkinButton` Hooked on `Update` Iterates Regions

`SkinButton` iterates `button:GetRegions()` in a hook on `btn.Update`, which fires every frame for action buttons that need updating. Iterating all regions on every update call is expensive when many buttons are skinned. Cache the region references on first skin application; re-iterate only when the button's action changes (hook `OnAttributeChanged` for the `"action"` attribute).

### 8. Widgets.lua — `UpdateAnchoredLayouts` Calls `GetStringWidth` Every Tick

The widget ticker fires every second, calls `UpdateContent` → `UpdateAnchoredLayouts`. For anchored widgets, `GetStringWidth()` and `SetWidth()` are called on every update even when text content has not changed. Cache the last text value per widget and skip layout recalculation when content is unchanged.

### 9. Warehousing.lua — `CalculateOverflowDeficit` Called Twice in `OnMailShow`

In `OnMailShow`, `CalculateOverflowDeficit()` is called once inside `RefreshPopup()` and again inline. `ScanBags()` (which it calls) iterates all bag slots. Compute once and pass the result to `RefreshPopup`.

### 10. Coordinates.lua — `distanceTicker` Calls Full API on Every Refresh

`Coordinates.RefreshList()` calls `GetDistanceToWP()` for every waypoint, which calls `C_Map.GetWorldPosFromMapPos` and `C_Map.GetBestMapForUnit`. With many waypoints on a 2s ticker, this is a non-trivial API cost. Cache the player map position within the refresh cycle and only call `GetBestMapForUnit` once per 2s interval.

### 11. widgets/Keystone.lua — `GetPlayerKeystone` Scans Bags Every Second

`GetPlayerKeystone()` fully scans all bag slots on every `UpdateContent` call (every 1s via the widget ticker). The keystone rarely changes. Cache the result and only re-scan on `BAG_UPDATE_DELAYED`.

### 12. Widgets.lua — Per-Widget `OnUpdate` Registered Permanently

```lua
f:SetScript("OnUpdate", function(self)
    if self.isMoving then ... end
end)
```

Every widget frame has a permanent `OnUpdate` that fires every frame. When not dragging (`isMoving = false`), it returns immediately but still has the overhead of being invoked. With 20+ widget frames, this accumulates. Register `OnUpdate` only while dragging; unregister in `OnDragStop`.

### 13. AddonVersions.lua — `GetPlayerKeystone` Scans Bags on `GROUP_ROSTER_UPDATE`

Same bag-scan pattern as issue #11, called on group changes. Add a `BAG_UPDATE_DELAYED`-invalidated cache.

### 14. SCT.lua — `SetCVar` Called on Every `ApplySCTEvents`

```lua
SetCVar("enableFloatingCombatText", UIThingsDB.sct.enabled and 1 or 0)
```

This writes a global CVar on every settings apply, which could interfere with other addons that manage this CVar and causes an unnecessary CVar write on every settings refresh. Guard with a check of the current CVar value first.

---

## Memory Concerns

### 15. ChatSkin.lua — Per-Frame Closure Accumulation

`SkinChatFrame` creates closures with captured upvalues for every chat frame's background and border textures. These hooks are permanent. With 10+ chat frames each having multiple regions hooked, this produces a significant set of permanent closures. The count could be reduced by using shared functions with frame as parameter rather than unique closures per region.

### 16. ChatSkin.lua — `kwPlaceholders` Table Created Per Message

```lua
local kwPlaceholders = {}  -- Inside HighlightKeywords, created on every message
```

With keyword highlighting active on 18 chat event types, this creates a new table for every single chat message received. Change to a module-level table with `wipe()` between uses, matching the pattern used by `FormatURLs`'s shared `placeholders` table.

### 17. Kick.lua — 8 Pre-Created Watcher Frames Regardless of Enabled State

8 frames (`partyWatcherFrames` + `partyPetWatcherFrames`) are created at file load time unconditionally. If a player never uses the Kick module, these frames persist in memory permanently. Consider lazy initialization on first `Kick.Enable()`.

### 18. TalentReminder.lua — `CompareTalents` Allocates on Every Zone Change

`CompareTalents()` is called on zone changes and talent changes. It allocates `mismatches` tables with sub-tables per mismatch node. When iterating many reminder entries, this generates significant temporary allocation. Results could be partially cached between calls when the talent loadout hasn't changed.

### 19. SessionStats.lua — SavedVariables Dirtied Every Second

```lua
-- In UpdateContent (called every 1s by widget ticker):
db.lastSeen = time()
```

Writing to `UIThingsDB` every second marks the saved variable as dirty, causing a full write to disk on every logout or `/reload`. Move the `lastSeen` update to `PLAYER_LOGOUT` only, which is its actual purpose (staleness detection on next login).

### 20. Warehousing.lua — `StartBankSync` Complex Closure Chain

`StartBankSync` defines `ProcessNextWork` as a local closure with `OnBagsSettled`, `bagListener`, and `bagFallback` as upvalues referencing each other. After sync completes all should be GC-collectible, but the multi-level closure chain makes lifetime reasoning complex. Add explicit nil-assignments at completion to break potential cycles.

---

## Code Quality & Readability

### 21. TalentReminder.lua — Major Code Duplication

`CheckTalentsInInstance` and `CheckTalentsOnMythicPlusEntry` share approximately 60 lines of identical `priorityList` building logic. Extract to a shared `BuildPriorityList(zoneKey, instanceType)` helper. TalentReminder.lua is already the largest file at ~1568 lines.

### 22. Misc.lua — Dead Code at File Load Time

```lua
-- Line ~293, executes at file load before saved variables are available:
if UIThingsDB and UIThingsDB.misc and UIThingsDB.misc.quickDestroy then
    Misc.ToggleQuickDestroy(true)
end
```

`UIThingsDB` is nil at file load — saved variables are only available after `ADDON_LOADED`. This block never executes. If `ToggleQuickDestroy` needs to run on startup, move it to `PLAYER_LOGIN`.

### 23. Loot.lua — Dead Code in `UpdateLayout`

In the grow-up branch of `UpdateLayout`, both the `if i == 1` and `else` branches produce identical anchor calls. The conditional is unnecessary — one branch is dead code.

### 24. Warehousing.lua — `SetupDropTarget` Duplicate Logic

Both `OnReceiveDrag` and `OnMouseUp` scripts contain identical item-drop handling logic. Extract to a shared local function.

### 25. MplusTimer.lua — Death Detection Logic Edge Cases

```lua
for i = 1, members do
    local unit = "party" .. i
    if i == members then unit = "player" end
```

For a 5-man group `GetNumGroupMembers()` returns 5 (includes player). The loop sets `unit = "player"` when `i == 5`, mapping the last iteration to player. This works for 5-man but for 2-player groups (party1 + player), `i == 2` maps to player — correctly. However if `GetNumGroupMembers()` returns different values in edge cases (raid vs party), the mapping may produce duplicate checks or miss the player. Prefer an explicit `UnitIsDeadOrGhost("player")` check outside the party loop.

### 26. Widgets.lua — Hard-Coded Widget Key Names

```lua
local isNewWidget = (key == "keystone" or key == "weeklyReset")
```

Hard-coding widget key names inside the framework creates a maintenance hazard. New widgets requiring the same behavior need a code change in the framework. Replace with a flag in the widget's config table: `db[key].defaultCentered = true`.

### 27. SCT.lua — O(n) Frame Removal in `RecycleSCTFrame`

```lua
for i, active in ipairs(sctActive) do
    if active == f then
        table.remove(sctActive, i)  -- shifts all subsequent elements
        break
    end
end
```

`table.remove` on a mid-array element is O(n). With `SCT_MAX_ACTIVE = 30` frames and frequent recycling in heavy combat, an indexed lookup table (`local activeIndex = {}`) would make removal O(1).

### 28. XpBar.lua and Others — Not on CENTER Anchor Convention

Per CLAUDE.md: *"All repositionable addon frames must anchor from CENTER of UIParent."* XpBar saves position using `GetPoint()` which returns the current dynamic anchor, not a CENTER-relative offset. The following modules are not yet migrated:
- `XpBar.lua` — dynamic GetPoint
- `CastBar.lua` — dynamic GetPoint
- `Combat.lua` (timer) — dynamic GetPoint
- `Kick.lua` — dynamic GetPoint
- `ObjectiveTracker.lua` — separate point/x/y fields
- `MinimapCustom.lua` — dynamic GetPoint
- `SCT.lua` — point + relPoint dynamic
- `MplusTimer.lua` — dynamic GetPoint
- `Coordinates.lua` — dynamic GetPoint
- `QuestReminder.lua` — dynamic GetPoint

### 29. Warehousing.lua — DEBUG Log Verbosity in Production Sync Path

```lua
Log("=== SYNC START === canViewCharacter=" .. ..., 0)  -- level 0 = DEBUG
Log("Processing " .. workIndex .. "/" .. #work ..., 0)
```

DEBUG-level log calls with string concatenation allocate even when the log threshold is INFO. Guard with a level check or elevate to a verbose toggle.

### 30. QuestAuto.lua — `HandleGossipShow` Calls Getter Functions Twice

```lua
local numActive    = C_GossipInfo.GetNumActiveQuests()
-- Later:
for _, questInfo in pairs(C_GossipInfo.GetActiveQuests()) do
```

`GetNumActiveQuests()` is called at the top but the actual `GetActiveQuests()` call within the handler also returns the count implicitly. The `numActive` and `numAvailable` locals are only used in the `autoGossip` block check. This is a minor inefficiency but `GetNumActiveQuests` can be removed in favour of checking `#C_GossipInfo.GetActiveQuests()` directly.

---

## Module-by-Module Notes

### Core.lua
- Clean single-init pattern. `ApplyDefaults` correctly identifies color tables by `.r` field.
- `CharacterRegistry` is a well-designed cross-module character data store.
- `MigrateBottomLeftToCenter` is a correct one-shot migration.

### EventBus.lua
- Solid centralized dispatch. The `RegisterUnit` wrapper closure approach works but the caller must retain the wrapper reference for `Unregister` — easy to misuse, creating a permanent listener if the reference is lost.
- Snapshot allocation concern (issue #5).

### AddonComm.lua
- Rate limiting and deduplication are well-implemented with correct cleanup.
- Legacy prefix routing correctly maps old message formats.
- Anonymous `addonTable.EventBus.Register("CHAT_MSG_ADDON", function(...) ... end)` at bottom cannot be unregistered if needed.

### ActionBars.lua
- Three-layer combat-safe positioning is the correct approach per CLAUDE.md.
- `PatchMicroMenuLayout` correctly handles the `GetEdgeButton` nil-crash.
- Writing `button.lunaSkinOverlay` (issue #3) and `SkinButton` on `Update` frequency (issue #7).

### ChatSkin.lua
- Critical taint issues (issues #1 and #16).
- `savedTimestampCVar` edge case: if ChatSkin is disabled before ever being enabled, the CVar is never saved and cannot be restored on disable.
- URL and keyword filters add overhead to 18 chat event types.

### Combat.lua
- `ScanConsumableBuffs` on `UNIT_AURA` (issue #6).
- `GetItemInfo` called twice for the same item in `TrackConsumableUsage`.
- `btn.spellID = spell.spellID` written onto `SecureActionButtonTemplate` button — taint risk (field write on Blizzard frame).

### Coordinates.lua
- `HookScript` on chat edit boxes (issue #4).
- `BuildZoneCache` called lazily and cached — correct pattern.
- `distanceTicker` API cost (issue #10).
- Position uses dynamic `GetPoint()` anchor (issue #28).

### DamageMeter.lua
- **Correctly implemented as a no-op stub** per CLAUDE.md and MEMORY.md. Blizzard DamageMeter frames are completely untouchable. No changes needed.

### EventBus.lua
- See issue #5. The `RegisterUnit` API is documented but the wrapper-reference requirement is easy to misuse.

### Frames.lua
- Frame pool correctly indexed by frame number. `SetBorder` helper closure created inside loop body — minor, only called on settings change.
- Already follows CENTER positioning convention.

### Kick.lua
- `OnUpdateHandler` self-stops when no active CDs — correct.
- 8 pre-created watcher frames (issue #17).
- `RebuildPartyFrames` on `PLAYER_REGEN_ENABLED` rebuilds entire frame set after every combat unnecessarily.

### Loot.lua
- Toast pool is well-implemented.
- Dead code in `UpdateLayout` (issue #23).
- `UpdateRosterCache` correctly capped at `GROUP_ROSTER_UPDATE`.

### MinimapCustom.lua
- Global `GetMinimapShape` redefinition (issue #2).
- `coordsTicker` and `clockTicker` at 1s intervals — acceptable overhead.
- `QueueStatusButton:HookScript("OnShow", ...)` — lower-risk than the `OnEvent` form but still technically an unsafe hook on a Blizzard frame.

### Misc.lua
- Dead code at file load (issue #22).
- `/rl` slash command could conflict with other addons.
- Personal order alert and TTS integration is clean.

### MplusTimer.lua
- `OnTimerTick` throttled to 10Hz via `sinceLastUpdate` — correct.
- Death detection edge cases (issue #25).
- Run history and split comparison feature is well-implemented.
- Position uses dynamic anchor (issue #28).

### QuestAuto.lua
- Clean event registration/unregistration.
- `lastGossipOptionID` guard correctly prevents gossip option loops.
- `HandleQuestComplete` correctly gates on `GetNumQuestChoices() <= 1`.

### QuestReminder.lua
- 5-second startup delay is appropriate.
- `IsQuestFlaggedCompletedOnAccount` correctly guarded.
- No stale quest cleanup — tracked quests grow indefinitely.
- Position uses dynamic anchor (issue #28).

### Reagents.lua
- Bag scan on every tooltip hover is expensive without caching.
- `tooltipHooked` flag correctly prevents re-hooking (TooltipDataProcessor hooks are permanent).
- `ScheduleBagScan` debounce is correct.

### SCT.lua
- O(n) frame removal (issue #27).
- `UNIT_COMBAT` handler correctly guards `issecretvalue(amount)`.
- `SetCVar` on every `ApplySCTEvents` (issue #14).

### TalentReminder.lua
- Code duplication (issue #21). Largest file at ~1568 lines — consider splitting.
- `CompareTalents` allocation on zone change (issue #18).

### Vendor.lua
- Clean and minimal. Durability debounce timer is correct.
- `isUnlocking` state flag is safe (these are addon-created frames, not Blizzard frames).

### Warehousing.lua
- Most complex module. `StartBankSync` recursive continuation (up to 5 passes) handles warband bank latency correctly.
- `WaitForItemUnlock` with `ITEM_LOCK_CHANGED` + 2s fallback ticker is a solid pattern.
- Double `CalculateOverflowDeficit` call (issue #9).
- DEBUG log verbosity (issue #29).
- `SetupDropTarget` duplicate logic (issue #24).
- Anonymous `EventBus.Register("PLAYER_LOGIN", function() ... end)` at line 1591 cannot be unregistered.

### XpBar.lua
- `ApplyBlizzardBarVisibility` correctly uses `RegisterStateDriver`/`UnregisterStateDriver`.
- Position uses dynamic anchor (issue #28).
- `sessionStartXP`/`sessionStartTime` reset on level up is correct.

### widgets/Widgets.lua
- `UpdateContent` with `needsLayoutUpdate` flag is a good optimization.
- `EvaluateCondition` is clean and readable.
- Per-widget `OnUpdate` overhead (issue #12).
- Hard-coded widget key names in framework (issue #26).

### widgets/Bags.lua
- `UpdateContent` iterates all bag slots every second — acceptable at 1s interval.
- Tooltip currency list iteration on hover — only on hover so acceptable.

### widgets/Keystone.lua
- `GetPlayerKeystone` bags scan every second (issue #11).
- `BuildTeleportMap` correctly lazy-built and cached.
- Secure overlay button for click-to-teleport is correctly implemented.
- `cachedTeleportSpells` invalidated on `SPELLS_CHANGED` and `PLAYER_REGEN_ENABLED` — correct.

### widgets/SessionStats.lua
- Session persistence across `/reload` with staleness check is well thought out.
- `db.lastSeen = time()` every second (issue #19).
- `issecretvalue(msg)` check in loot counting is correct.

---

## Recommendations (Priority Order)

### High Priority

1. **Fix ChatSkin.lua taint risks** — Replace `hooksecurefunc(bg, method, cb)` with side-table tracking (`local hookedFrames = {}; hookedFrames[frame] = true`). Replace `SetItemRef =` with `hooksecurefunc("SetItemRef", cb)`.

2. **Fix MinimapCustom.lua global redefinition** — Move `function GetMinimapShape() return "SQUARE" end` to file scope. Never redefine globals inside a function body.

3. **Fix ActionBars.lua button field writing** — Replace `button.lunaSkinOverlay = ...` with `local skinOverlays = {}; skinOverlays[button] = ...`.

4. **Fix Coordinates.lua `HookScript`** — Replace `box:HookScript("OnKeyDown", ...)` with a safer interception mechanism for the `/way` command.

### Medium Priority

5. **Fix ChatSkin.lua `kwPlaceholders`** — Change to a module-level table with `wipe()` reuse.

6. **Fix Misc.lua dead code** — Remove or move the `UIThingsDB.misc.quickDestroy` check to `PLAYER_LOGIN`.

7. **Debounce `SkinButton` region iteration** — Cache region references on first skin; re-iterate only on action attribute change.

8. **Fix Warehousing.lua double scan** — Call `CalculateOverflowDeficit` once in `OnMailShow`; pass result to `RefreshPopup`.

9. **Cache `GetPlayerKeystone` result** — Re-scan only on `BAG_UPDATE_DELAYED`, not every second.

10. **Extract shared `BuildPriorityList` in TalentReminder.lua** — Eliminate ~60 lines of duplicated logic.

11. **Fix SessionStats `lastSeen` write frequency** — Update only on `PLAYER_LOGOUT`, not every widget tick.

12. **Reduce SCT frame removal cost** — Replace the O(n) `ipairs` + `table.remove` with an indexed lookup table.

### Low Priority

13. **Migrate remaining frames to CENTER convention** — XpBar, CastBar, Combat timer, Kick, ObjectiveTracker, MinimapCustom, SCT, MplusTimer, Coordinates, QuestReminder. See CLAUDE.md for exact pattern.

14. **Register EventBus snapshot buffer once** — Pre-allocate a reuse buffer with reentrancy depth tracking to eliminate per-dispatch table allocation.

15. **Remove per-widget permanent `OnUpdate`** — Register/unregister during drag only.

16. **Replace `Widgets.lua` hard-coded key names** — Use a `defaultCentered` flag in widget config tables.

17. **Fix MplusTimer death detection** — Add explicit `UnitIsDeadOrGhost("player")` check outside party loop for clarity.

18. **Add caching to `AddonVersions.GetPlayerKeystone`** — Invalidate on `BAG_UPDATE_DELAYED`.

19. **Add stale quest cleanup to QuestReminder** — Quests that no longer exist or are permanently completed should be removable automatically.

20. **Reduce Warehousing DEBUG log verbosity** — Guard with level check or move to a verbose toggle.

---

## Summary Table

| Severity | Count | Key Examples |
|----------|-------|-------------|
| Critical (taint/correctness) | 4 | ChatSkin hook forms, MinimapCustom global, ActionBars field write, Coordinates HookScript |
| Performance | 10 | EventBus allocation, Combat UNIT_AURA, SkinButton OnUpdate, Widgets anchor recalc, Warehousing double scan, Keystone bag scan, Coordinates distance ticker, SCT SetCVar, AddonVersions bag scan, per-widget OnUpdate |
| Memory | 6 | ChatSkin closures, kwPlaceholders per message, Kick frames, TalentReminder allocation, SessionStats lastSeen write, Warehousing closure chain |
| Code Quality | 10 | TalentReminder duplication, Misc dead code, Loot dead branch, SCT O(n) recycle, CENTER convention (10 modules), Widgets hard-coded keys, MplusTimer death logic, Warehousing duplicate logic, QuestReminder stale data, Warehousing debug log |
