# LunaUITweaks Code Review
_Last updated: 2026-03-06_

## Overall Health: GOOD

The addon has a clean architecture — centralised EventBus, rate-limited AddonComm, good frame pooling in Loot.lua, and proper taint guards in DamageMeter and ActionBars. Main areas for improvement: a critical bug in profiler/EventBus interaction, several GC-pressure patterns from intermediate table allocations, and a few per-frame hot-path issues.

---

## CRITICAL

### ~~Profiler wrapping breaks EventBus.Unregister~~ ✅ FIXED (2026-03-06)

`callbackMap` now tracks original→stored for both profiler and unit wrappers. `Register` stores the mapping when wrapping occurs and returns the stored ref. `RegisterUnit` uses the returned stored ref to map the original callback directly. `Unregister` resolves via `callbackMap[callback]` and cleans up the entry.

---

## HIGH — Performance / Memory

### ~~EventBus snapshot table allocated on every event fire~~ ✅ FIXED (2026-03-06)

Replaced with tombstone + post-dispatch compaction. No per-event allocation. Mid-dispatch unregistrations set `false` as a tombstone; a single compaction pass after dispatch cleans them up in O(n).

Every event dispatch allocates and fills a new table. For high-frequency events (`UNIT_HEALTH`, `UNIT_COMBAT`, `BAG_UPDATE_DELAYED`, `GROUP_ROSTER_UPDATE`) this creates continuous GC pressure. Use a module-level scratch table, `wipe()` before use, and nil entries after iteration:

```lua
local dispatchSnapshot = {}
-- inside OnEvent:
for i = 1, n do dispatchSnapshot[i] = subs[i] end
for i = 1, n do
    local cb = dispatchSnapshot[i]
    if cb then cb(event, ...) end
    dispatchSnapshot[i] = nil
end
```

### SCT OnUpdate calls ClearAllPoints+SetPoint every frame per active text (SCT.lua:97-98)

With `SCT_MAX_ACTIVE = 30` and `captureToFrames` enabled during heavy combat, up to 30 frames each call `ClearAllPoints()` + `SetPoint()` every rendered frame — potentially 1800+ layout ops/sec at 60fps. Use alpha-only animation or pre-parent the text to the anchor so only the Y offset needs updating.

### Loot.AcquireToast creates a new closure per toast (Loot.lua:144-155)

```lua
toast:SetScript("OnUpdate", function(self, elapsed) ... end)
```

This is called for every toast including recycled frames. Each call allocates a new function object. Define the handler once at module scope and assign by reference.

### Widget OnUpdate fires every frame for all visible widgets even when idle (Widgets.lua:87-97)

Every frame created by `CreateWidgetFrame` has an `OnUpdate` that runs every rendered frame just to check `if self.isMoving`. When locked (normal operation), `isMoving` is always false. With 10+ enabled widgets at 60fps this is 600+ no-op calls per second. Only install the `OnUpdate` script during a drag; clear it in `OnDragStop`.

### Widgets.UpdateVisuals rebuilds anchor lookup redundantly (Widgets.lua:285-293)

`UpdateVisuals` builds a local `anchorLookup` table from scratch on every call (lines 285-293), ignoring the existing `cachedAnchorLookup` / `RebuildAnchorCache` system used by `UpdateAnchoredLayouts`. The two systems are independent and unsynchronized. Remove the local duplicate and use the cache.

### UpdateAnchoredLayouts allocates intermediate tables every second (Widgets.lua:204-213)

Called from `UpdateContent` (every second when widgets are enabled), this creates a fresh `anchoredWidgets = {}` and `{ key = key, frame = frame }` entry objects on every call. Reuse module-level tables with `wipe()` instead.

---

## HIGH — Bugs (pre-existing)

### CastBar.lua:30 — `CASTBAR_DEBUG = true` hardcoded
The flag is checked in all logging paths but never set to `false`. Every user sees debug messages in chat on every cast event. Set `CASTBAR_DEBUG = false` before release.

### Misc.lua:139 — `issecretvalue(msg)` on CHAT_MSG_LOOT message
Chat message strings from loot events are NOT secret values — only GUID/sourceGUID fields from the combat log are. This guard causes `ShowBoeAlert` to silently return early during any combat loot event, breaking BoE detection precisely when it matters most.
_Fix: Remove this check._

### Misc.lua:327 — `keywordCache` not cleared on disable
`UpdateAutoInviteKeywords()` inserts into `keywordCache` but disabling auto-invite in `ApplyMiscEvents()` only unregisters the whisper listener — it never wipes the cache. On re-enable, old and new keywords accumulate.
_Fix: `table.wipe(keywordCache)` in the auto-invite disable branch._

---

## MEDIUM

### Reagents.GetLiveBagCount scans all bags on every tooltip hover (Reagents.lua:246-271)

`GetAllCharCounts` is called on every `TooltipDataType.Item` postCall and calls `GetLiveBagCount` which iterates all bag slots (~250 slots with large bags), with hyperlink string matching as fallback. Cache the result keyed by itemID and invalidate on `BAG_UPDATE_DELAYED`.

### Vendor.lua:109 — Bag range hardcoded to 0–4
`C_Container.GetContainerNumFreeSlots` is called for bags 0–4 only. The reagent bag (index 5 / `Enum.BagIndex.ReagentBag`) is missed, so the low-bag-space warning fires incorrectly when free slots are only in the reagent bag. Extend loop to `NUM_BAG_SLOTS` and include the reagent bag index.

### Loot.UpdateLayout dead-code if/else (Loot.lua:196-215)

Both branches of `if i == 1` / `else` in both `growUp` and `growDown` paths call `SetPoint` with identical arguments. The `if i == 1` special-case is dead code and should be removed.

### FPS widget re-sorts addonMemList on every tooltip open (FPS.lua:99)

`RefreshMemoryData` already sorts the list (line 44). `OnEnter` sorts it again (line 99). The second sort is redundant.

### Misc.lua — Three alert frames created unconditionally at load time (Misc.lua:7-127)

`alertFrame`, `mailAlertFrame`, and `boeAlertFrame` are created at module load even when `misc.enabled` is false. Hidden frames still consume frame table memory and texture slots. Create them lazily on first show.

### Misc.OnPartyInviteRequest — O(n BNet friends) on every invite (Misc.lua:476-484)

Every party invite triggers a linear scan of all BNet friends via `C_BattleNet.GetFriendAccountInfo`. Cache a GUID→bool map, invalidated on `BN_FRIEND_LIST_UPDATE`.

### SCT RecycleSCTFrame — linear scan of sctActive (SCT.lua:69-74)

`RecycleSCTFrame` iterates the full `sctActive` list to find a frame by reference. With `SCT_MAX_ACTIVE = 30` this is O(30) inside an OnUpdate path. Use a hash set (`sctActiveSet = {}`) for O(1) removal.

### AddonVersions.GetPlayerKeystone — bag scan on every roster update (AddonVersions.lua:17-38)

`GetPlayerKeystone` scans all bag slots on every `GROUP_ROSTER_UPDATE` and every `RefreshVersions`. Cache the result and invalidate on `BAG_UPDATE_DELAYED` or `ITEM_PUSH` events.

---

## LOW

### SessionStats.SaveSessionData called on every loot event

`OnChatMsgLoot` writes multiple SavedVariable fields on every loot message. For high-item-drop situations this is a constant write. Consider deferring the write to `PLAYER_LOGOUT` for fields that don't need intra-session persistence.

### Widgets condition evaluation calls GetInstanceInfo redundantly (Widgets.lua:430-438)

If both "instance" and "world" condition widgets are enabled, `GetInstanceInfo()` is called twice per `UpdateConditions` pass. Cache the result at the top of the function.

### Core.lua — DEFAULTS table defined inside event handler (Core.lua:232-820)

The ~600-line DEFAULTS table is defined inside the `ADDON_LOADED` handler. While it only executes once (UnregisterEvent is called immediately after), it makes the function hard to navigate. Moving DEFAULTS to module scope is cleaner.

### Reagents.ScanBags and GetLiveBagCount rebuild bagList on every call (Reagents.lua:65-71)

`bagList` is constructed identically on every call to `ScanBags` and `GetLiveBagCount`. Define it once as a module-level constant.

### Misc.lua — ApplyUIScale silently fails in combat with no retry (Misc.lua:292-294)

If called while in combat, the scale is silently dropped. Register a one-shot `PLAYER_REGEN_ENABLED` handler to retry.

### Multiple files — Frame positions not yet migrated to CENTER anchor

Per CLAUDE.md — not yet migrated: `XpBar`, `CastBar`, `Combat`, `Kick`, `ObjectiveTracker`, `MinimapCustom`.

---

## Summary Table

| # | Severity | File | Issue |
|---|----------|------|-------|
| 1 | ~~Critical~~ | ~~EventBus.lua~~ | ~~Profiler wrapping breaks Unregister — events never removed~~ ✅ |
| 2 | ~~High~~ | ~~EventBus.lua~~ | ~~Snapshot table allocated per event fire — GC pressure~~ ✅ |
| 3 | High | SCT.lua | ClearAllPoints+SetPoint every frame per SCT text (up to 30) |
| 4 | High | Loot.lua | New closure created per AcquireToast call |
| 5 | High | Widgets.lua | OnUpdate fires every frame for all widgets even when idle |
| 6 | High | Widgets.lua | UpdateVisuals rebuilds anchor lookup ignoring cache |
| 7 | High | Widgets.lua | UpdateAnchoredLayouts allocates tables every second |
| 8 | High | CastBar.lua | CASTBAR_DEBUG = true hardcoded |
| 9 | High | Misc.lua | issecretvalue on CHAT_MSG_LOOT breaks BoE detection in combat |
| 10 | High | Misc.lua | keywordCache not wiped on auto-invite disable |
| 11 | Med | Reagents.lua | Live bag scan on every tooltip hover — no cache |
| 12 | Med | Vendor.lua | Bag range hardcoded 0-4, misses reagent bag |
| 13 | Med | Loot.lua | Dead-code if/else in UpdateLayout |
| 14 | Med | FPS.lua | Redundant sort of addonMemList on every tooltip open |
| 15 | Med | Misc.lua | Three alert frames created unconditionally at load |
| 16 | Med | Misc.lua | O(n BNet friends) scan on every party invite |
| 17 | Med | SCT.lua | Linear scan of sctActive in RecycleSCTFrame |
| 18 | Med | AddonVersions.lua | Bag scan for keystone on every roster update |
| 19 | Low | SessionStats.lua | SaveSessionData called on every loot event |
| 20 | Low | Widgets.lua | GetInstanceInfo called redundantly per UpdateConditions pass |
| 21 | Low | Core.lua | DEFAULTS defined inside event handler |
| 22 | Low | Reagents.lua | bagList rebuilt on every scan call |
| 23 | Low | Misc.lua | ApplyUIScale in-combat failure has no retry |
| 24 | Low | Multiple | Frame positions not yet migrated to CENTER anchor |

---

## Known-Good Modules

| Module | Status |
|--------|--------|
| DamageMeter.lua | ✅ Secret value handling thorough; no taint issues |
| AddonComm.lua | ✅ HasRealGroupMembers check; rate limiting correct |
| MinimapCustom.lua | ✅ QueueStatusButton taint fixed |
| Loot.lua | ✅ Frame pool well-implemented (aside from closure per-acquire) |
| Frames.lua | ✅ CENTER positioning correct |
| EventBus.lua | ✅ Dispatch snapshot prevents mid-dispatch mutation (closure GC aside) |
| Reagents.lua | ✅ Handles reagent bag slot correctly |
| ChatSkin.lua | ✅ Global-form hooks only; no frame taint |
