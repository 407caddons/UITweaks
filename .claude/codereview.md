# LunaUITweaks -- Comprehensive Code Review

**Review Date:** 2026-02-21 (Ninth Pass -- New Files + Modified Files Audit)
**Previous Review:** 2026-02-21 (Eighth Pass -- Modified Files Audit)
**Scope:** New files (`widgets/Lockouts.lua`, `widgets/XPRep.lua`), modified files (`MinimapCustom.lua`, `TalentManager.lua`, `config/panels/ActionBarsPanel.lua`, `LunaUITweaks.toc`) + full review of config system, ObjectiveTracker, Kick, CastBar, Vendor, AddonComm, AddonVersions, Reagents, QuestAuto, QuestReminder, MplusTimer, and Frames
**Focus:** Bugs/crash risks, performance issues, memory leaks, race conditions/timing issues, code correctness, saved variable corruption risks, combat lockdown safety

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Changes Since Last Review](#changes-since-last-review)
3. [Per-File Analysis -- Core Modules](#per-file-analysis----core-modules)
4. [Per-File Analysis -- UI Modules](#per-file-analysis----ui-modules)
5. [Per-File Analysis -- Config System](#per-file-analysis----config-system)
6. [Per-File Analysis -- Widget Files](#per-file-analysis----widget-files)
7. [Cross-Cutting Concerns](#cross-cutting-concerns)
8. [Priority Recommendations](#priority-recommendations)

---

## Executive Summary

LunaUITweaks is a well-structured addon with consistent patterns, good combat lockdown awareness, and effective use of frame pooling. The codebase demonstrates strong understanding of the WoW API and its restrictions. Key strengths include the three-layer combat-safe positioning in ActionBars, proper event-driven architecture, shared utility patterns (logging, SafeAfter, SpeakTTS), excellent widget framework design with anchor caching, smart tooltip positioning, the widget visibility conditions system, and the new hook-based consumable tracking architecture.

### What Changed Since Last Review (Eighth to Ninth Pass)

Five files modified, two new files added (per git diff). Key findings:

1. **MinimapCustom.lua** -- **NEW (3 MEDIUM):** QueueStatusButton persistent anchoring added (lines 16-79). Three hooks (OnShow, SetPoint, UpdatePosition) each schedule `C_Timer.After(0, ...)` for deferred repositioning. Issues: (a) `SetParent(Minimap)` on line 29 without `InCombatLockdown()` guard -- QueueStatusButton may be protected during combat. (b) Triple redundant `C_Timer.After(0)` scheduling -- when Blizzard repositions the eye, both SetPoint and UpdatePosition hooks fire, scheduling two deferred calls for the same frame. (c) Potential hook conflict with ActionBars.lua if both modules hook QueueStatusButton positioning methods.

2. **TalentManager.lua** -- Minor whitespace/formatting changes only. No new functional issues.

3. **config/panels/ActionBarsPanel.lua** -- **FIXED (MEDIUM):** Nav visuals now use `UpdateNavVisuals()` helper that checks `enabled or skinEnabled`, so the tab correctly shows gold when either feature is active rather than only when the main `enabled` flag is set.

4. **widgets/Lockouts.lua** -- **FIXED (MEDIUM):** OnClick handler rewritten from removed `ToggleRaidFrame()` to `ToggleFriendsFrame(3)` + `RaidInfoFrame:Show()`. Correct API for current WoW client. Widget otherwise clean.

5. **widgets/XPRep.lua** -- **NEW WIDGET.** XP/Reputation display widget (245 lines). Proper `ApplyEvents(enabled)` pattern with 5 events. Handles max-level (reputation) vs leveling (XP). Renown + paragon support with reward indicator. **NEW LOW:** OnClick calls `ToggleCharacter("ReputationFrame")` without `InCombatLockdown()` guard (line 232-239). `ToggleCharacter` opens a protected frame that may cause taint in combat.

6. **LunaUITweaks.toc** -- Version bump 1.12.0 -> 1.13.0. No issues.

7. **Previous findings all confirmed still present** -- All medium and low priority items from the eighth pass remain unless explicitly noted as resolved.

### Issue Counts

**Critical Issues:** 3 (2 new Loot.lua, 1 new TalentManager.lua); ~~1~~ fixed (MplusTimer forward reference)
**High Priority:** 1 new (TalentReminder ApplyTalents stale ranks); ~~5~~ All previous fixed (Combat.lua C_Item.GetItemInfoInstant, EventBus dedup, Group.lua IsGuildMember, TalentManager instanceType, TalentReminder data migration)
**Medium Priority:** 34 (3 MinimapCustom QueueStatusButton hooks, 1 TalentReminder prerequisite chains; 1 fixed: Lockouts OnClick, 1 fixed: ActionBarsPanel nav visuals)
**Low Priority / Polish:** 29+ (1 new: XPRep ToggleCharacter combat guard)

---

## Changes Since Last Review (Ninth Pass -- 2026-02-21)

### Status of Previously Identified Issues

#### Confirmed Still Fixed

- **FIXED:** MplusTimer.lua nil guard for `info.quantityString`
- **FIXED:** MplusTimer.lua forward reference `local OnChallengeEvent` at line 6
- **FIXED:** Misc.lua nil guard for `inviterGUID`
- **FIXED:** Group.lua `readyCheckActive`/`readyCheckResponses` scoping
- **FIXED:** Group.lua tooltip uses cached atlas constants
- **FIXED:** Currency.lua integrated into addon
- **FIXED:** ChatSkin.lua `FormatURLs` reuses module-level `placeholders` table
- **FIXED:** LOG_COLORS table in Core.lua hoisted to module scope
- **FIXED:** Shadowed `guid` variable in Kick.lua removed
- **FIXED:** Sort functions in ObjectiveTracker.lua pre-defined as upvalues
- **FIXED:** Periodic cleanup for ObjectiveTracker caches on zone change
- **FIXED:** `local mt` shadowing in ActionBars.lua resolved
- **FIXED:** Keystone widget `BuildTeleportMap` combat guards added
- **FIXED:** Core.lua defaults include `goldData = {}` subtable for bags widget
- **FIXED:** EventBus.lua pcall removed from dispatch loop
- **FIXED:** MplusTimer.lua raw event frames fully migrated to EventBus
- **FIXED:** `CleanupSavedVariables()` in TalentReminder.lua now migrates old-format builds by wrapping them in arrays instead of deleting them.
- **FIXED:** Combat.lua `C_Item.GetItemInfoInstant(spellName)` -- now uses hook-based consumable tracking
- **FIXED:** TalentManager.lua EJ cache tier mutation -- saves/restores current tier
- **FIXED (ninth pass):** Lockouts.lua OnClick -- rewritten from removed `ToggleRaidFrame()` to `ToggleFriendsFrame(3)` + `RaidInfoFrame:Show()`
- **FIXED (ninth pass):** ActionBarsPanel.lua nav visuals -- `UpdateNavVisuals()` checks `enabled or skinEnabled`

#### Previously Identified Issues Still Open

- All medium and low priority items from the eighth pass remain unless explicitly noted as resolved below.

#### NOT FIXED -- Still Open from Previous Reviews

- **Teleports.lua lines 549-553:** FontString inserted into `mainButtons` array -- crash risk in `ClearMainPanel()`.
- **Teleports.lua lines 322-336:** `SetAttribute` on secure buttons during potential combat lockdown.
- **Keystone.lua line 137:** Position saved as `{x, y}` instead of framework schema `{point, relPoint, x, y}`.
- **ActionBars.lua lines 1158 / 1277:** Combat deferral frame leak on repeated combat-blocked calls.
- **CastBar.lua:** Same combat deferral frame leak pattern.
- **Combat.lua line 580:** Infinite retry risk in `TrackConsumableUsage`. No retry counter.
- **Combat.lua lines 1048 / 1070 / 1135:** Triplicate `ApplyReminderLock()` calls (init + two in UpdateReminderFrame flow).
- **Combat.lua line 1113:** Stale comment says "Create 4 text lines" but loop on line 1114 creates 5.
- **Loot.lua lines 196-210:** Redundant `if i == 1`/`else` branches in `UpdateLayout`.
- **Loot.lua line 500:** Locale-dependent `"^You receive"` string pattern.

#### NEW Findings (Ninth Pass -- 2026-02-21)

| Severity | Issue | File | Line |
|----------|-------|------|------|
| FIXED (was MEDIUM) | Lockouts OnClick -- rewritten from removed `ToggleRaidFrame()` to correct API | widgets/Lockouts.lua | OnClick |
| FIXED (was MEDIUM) | ActionBarsPanel nav visuals now check `enabled or skinEnabled` | config/panels/ActionBarsPanel.lua | UpdateNavVisuals |
| Medium | `SetParent(Minimap)` on QueueStatusButton without `InCombatLockdown()` guard | MinimapCustom.lua | 29 |
| Medium | Triple redundant `C_Timer.After(0)` scheduling from OnShow/SetPoint/UpdatePosition hooks | MinimapCustom.lua | 41-75 |
| Medium | Potential hook conflict with ActionBars.lua -- both modules may hook QueueStatusButton | MinimapCustom.lua / ActionBars.lua | cross-module |
| Low | `ToggleCharacter("ReputationFrame")` without `InCombatLockdown()` guard in OnClick | widgets/XPRep.lua | 232-239 |

#### Previous Eighth Pass Findings (Still Present)

| Severity | Issue | File | Line |
|----------|-------|------|------|
| Medium | `SetRowAsBuild` creates 6 closures per build row on every `RefreshBuildList` call | TalentManager.lua | 410-443 |
| Low | `ReleaseAlertFrame()` clears `currentReminder` but not `currentMismatches` -- table reference persists | TalentReminder.lua | 1508-1529 |
| Low | `DecodeImportString` does not type-check `importStream` internals before use | TalentManager.lua | ~1480 |

---

## Per-File Analysis -- Core Modules

### Core.lua (~585 lines)

**Status:** Clean. No new issues.

- `ApplyDefaults` is recursive but only runs once at `ADDON_LOADED`. No hot-path concern.
- `SpeakTTS` utility provides centralized TTS with graceful fallbacks.
- Default tables for all modules properly initialized.
- **Low:** `DEFAULTS` table is constructed inside the `OnEvent` handler, which runs for every addon's `ADDON_LOADED`. Moving it to file scope would avoid wasted allocations on non-matching calls.
- **Low:** `ApplyDefaults` does not guard against `db` being nil at the top level. Safe in practice.

---

### EventBus.lua (~72 lines)

**Status:** All issues fixed except one medium performance concern.

- **FIXED: Duplicate registration vulnerability (lines 30-36).** `EventBus.Register` now scans the existing subscriber array for the same function reference before inserting, preventing duplicate listeners from accumulating when `ApplyEvents()`/`UpdateSettings()` is called multiple times. All affected modules (Vendor, Loot, Misc, QuestAuto, QuestReminder, Durability, etc.) are protected without per-module changes.

- **Medium (NEW): Snapshot allocation per event fire (lines 18-20).** A new `snapshot` table is allocated on every event dispatch. For high-frequency events like `BAG_UPDATE_DELAYED`, `UNIT_AURA`, or `UNIT_COMBAT`, this creates GC pressure. Consider reusing a scratch table.

- `RegisterUnit` (line 63) is a nice abstraction returning the wrapper for later unregistration.
- Unregister properly cleans up empty listener arrays and unregisters the WoW event.

---

### AddonComm.lua (~225 lines)

**Status:** Clean. No issues.

- Rate limiting, deduplication, and legacy prefix mapping are well-implemented.
- `CleanupRecentMessages()` is properly amortized at 20-message intervals.
- `C_ChatInfo.InChatMessagingLockdown` check is good defensive practice.

---

### Vendor.lua (~343 lines)

**Status:** Clean. Previous duplicate registration issue fixed.

- **FIXED:** `ApplyVendorEvents()` duplicate listener accumulation resolved by EventBus deduplication.
- Timer is properly canceled on re-entry (line 200).
- `InCombatLockdown()` check correctly gates durability check when `onlyCheckDurabilityOOC` is set.

---

### Loot.lua (~556 lines)

**Status:** Two critical issues. One medium. One low. Previous duplicate registration fixed.

- **FIXED:** Duplicate EventBus registration pattern resolved by EventBus deduplication.

- **CRITICAL (NEW): OnUpdate script not cleared on recycled toast frames (lines 137-148, 167-180).** The `OnUpdate` timer script is set once during initial frame creation in `AcquireToast()` (line 137), inside the `if not toast then` block. When `RecycleToast()` (line 167) hides the frame and returns it to `itemPool`, **the OnUpdate script is never cleared**. On next reacquisition, `toast.timeParams` is set to `nil` (line 153) before being reassigned, but the old OnUpdate continues firing during this window. More critically, if the pooled frame is never reacquired, its OnUpdate fires every render frame on a hidden frame, accessing `self.timeParams.elapsed` on nil -- causing repeated Lua errors. **Fix:** Add `toast:SetScript("OnUpdate", nil)` to `RecycleToast()`.

- **CRITICAL (NEW): Truncated item link regex pattern (line 494).** The pattern `|Hitem:.-|h` only captures up to the first `|h` delimiter, missing the item name and closing `|h|r`. A WoW item link has the form `|cFFFFFFFF|Hitem:12345:...|h[Item Name]|h|r`. The current pattern captures `|Hitem:12345:...|h` but omits `[Item Name]|h`. This produces malformed links that cannot be used for `GetItemInfo()` lookups or display. **Fix:** Use `|Hitem:.-|h.-|h` or `|c.-|Hitem:.-|h.-|h|r` to capture the complete link.

- **Medium:** `string.find(msg, "^You receive")` is locale-dependent (line 499). On non-English clients, self-loot detection fails.
- **Low:** `UpdateLayout` has identical code in `if i == 1` and `else` branches. Redundant.
- Frame pool (`itemPool`) correctly recycles frames (when OnUpdate is fixed). Good pattern.
- Roster cache for class color lookups is a nice optimization.

---

### Combat.lua (~1217 lines)

**Status:** Previous HIGH issue FIXED. Two medium. Three low.

- **FIXED (was HIGH):** `C_Item.GetItemInfoInstant(spellName)` (previously line 1151). The `UNIT_SPELLCAST_SUCCEEDED` handler (lines 1144-1148) now returns early with a comment explaining that consumable usage is tracked via `UseAction`/`UseContainerItem`/`UseItemByName` hooks. This is the correct architectural approach -- spell IDs from cast events cannot be reliably mapped back to item IDs, so hook-based tracking at the point of item use is proper.
- **Medium:** `TrackConsumableUsage` (line 580) has infinite retry risk. If `GetItemInfo` never returns data for a given `itemID`, the function recurses via `C_Timer.After(0.5, ...)` indefinitely. Should add a retry counter (max 5 attempts).
- **Medium:** `GetItemInfo(itemID)` called twice in `TrackConsumableUsage` (lines 577 and 584). Should consolidate.
- **Low:** `ApplyReminderLock()` is called three times -- line 1048, line 1070, and line 1135. At least one is redundant.
- **Low:** Line 1113 comment says "Create 4 text lines" but the loop on line 1114 creates 5 (`for i = 1, 5`).
- Bag scan caching (invalidated on `BAG_UPDATE_DELAYED`), quality star overlays, and MH/OH weapon slot targeting are well-implemented.
- Hook-based consumable tracking (`HookConsumableUsage`) is a solid architectural choice.
- Hybrid event approach (own frame for OnUpdate + timer events, EventBus elsewhere) is intentional and correct.
- `UpdateReminderFrame` correctly exits early if `InCombatLockdown()`. All SecureActionButtonTemplate operations properly guarded.

---

### Misc.lua (~680 lines)

**Status:** Clean. Previous duplicate registration issue fixed.

- **FIXED:** `ApplyMiscEvents()` duplicate EventBus registration resolved by EventBus deduplication.
- **FIXED (previous):** `PARTY_INVITE_REQUEST` handler properly guards `inviterGUID`.
- `mailAlertShown` flag prevents repeated alerts. Clean implementation.
- SCT `SCT_MAX_ACTIVE = 30` cap prevents frame explosion.
- `issecretvalue()` checks on `CHAT_MSG_SYSTEM` and `UNIT_COMBAT` data. Good defensive coding.
- **Low:** SCT `OnUpdate` runs per-frame for each active text (up to 30). `ClearAllPoints()` + `SetPoint()` every frame is expensive. Consider animation groups.

---

### Frames.lua (~325 lines)

**Status:** One low-priority observation. Otherwise clean.

- **Low:** `SetBorder` local function defined inside loop body -- should be hoisted.
- Frame pool correctly avoids creation/destruction overhead.
- `SaveAllFramePositions` on `PLAYER_LOGOUT` ensures no position data lost.

---

### QuestAuto.lua (~214 lines)

**Status:** Clean. Previous duplicate registration issue fixed.

- **FIXED:** `ApplyEvents()` duplicate EventBus registration resolved by EventBus deduplication.
- One-shot initialization pattern using `Unregister` inside callback is elegant.
- `lastGossipOptionID` anti-loop protection is a good safety measure.
- Shift-to-pause feature is thoughtful UX.

---

### QuestReminder.lua (~381 lines)

**Status:** Clean. Previous duplicate registration issue fixed.

- **FIXED:** `ApplyEvents()` duplicate EventBus registration resolved by EventBus deduplication.
- Well-organized with clear section comments.
- Test popup function is useful for config panel testing.

---

### Reagents.lua (~486 lines)

**Status:** Clean. Exemplary EventBus usage.

- `eventsEnabled` guard (line 400) is the **only module that correctly prevents duplicate EventBus registration**. This pattern should be adopted by all other modules.
- `TooltipDataProcessor` hook (line 322) is the correct modern WoW API.
- `IsReagent` optimization: tries `GetItemInfoInstant` first (no cache miss), falls back to `GetItemInfo`.
- `ScanBags()` properly debounced at 0.5s.
- **Low:** `GetTrackedCharacters` rebuilds list from saved variable on every call.

---

### AddonVersions.lua (~215 lines)

**Status:** Clean. No issues.

- `ScheduleBroadcast` throttle (3-second delay) prevents spam on rapid roster changes.
- Backwards-compatible message parsing with three format levels is well-handled.

---

## Per-File Analysis -- UI Modules

### MplusTimer.lua (~974 lines)

**Status:** Critical issue fixed. One low remaining.

- **FIXED: Forward reference to undefined local function (lines 701 and 798).** Added `local OnChallengeEvent` forward declaration at file top (line 6) and changed the definition at line 798 from `local function` to assignment. M+ event processing (deaths, boss times, forces, completion) now works correctly.

- **Low:** Death tooltip `OnEnter` creates a temporary `sorted` table per hover. Negligible for 5-player groups.
- EventBus migration is otherwise complete and clean.
- `globalEventsRegistered` flag ensures idempotent registration. Good.

---

### TalentManager.lua (~1782 lines)

**Status:** Previous HIGH and MEDIUM issues fixed. Two medium remain. Two low.

- **FIXED: Undefined `instanceType` variable (lines 1141 and 1156).** Moved the `GetInstanceInfo()` call above the `instanceType == "raid"` check so the zone-specific checkbox now correctly defaults to checked in raids.

- **FIXED: EJ cache tier mutation (lines 54-55, 92-95).** `EnsureEJCache()` now saves the current tier via `EJ_GetCurrentTier()` before iterating and restores it via `EJ_SelectTier(savedTier)` after. No longer disrupts the user's Encounter Journal view.

- **CRITICAL (NEW): Stale `buildIndex` in button closures (lines 410-438).** `SetRowAsBuild` captures `buildIndex` by value in click handlers for edit, copy, update, and delete buttons. When `RefreshBuildList()` re-sorts builds (line 639), the captured indices become stale. If user deletes build A at index 1, build B moves from index 2 to index 1, but B's delete button still holds `buildIndex = 2`. Clicking it deletes the wrong build or crashes on out-of-bounds access. **Fix:** Store build data on the row frame (e.g., `row.buildData = { instanceID, diffID, zoneKey, buildIndex, reminder }`) and re-set it each time `SetRowAsBuild` is called, or look up the build by a stable identifier (e.g., name + hash) instead of array index.

- **Medium:** `RefreshBuildList` creates multiple temporary tables per call (`raidBuilds`, `dungeonBuilds`, `uncategorizedBuilds`, sorted arrays). Significant garbage for users with 50+ builds. Use module-level scratch tables with `wipe()`.
- **Medium (NEW):** `SetRowAsBuild` (lines 410-443) creates 6 closures per build row on every `RefreshBuildList` call. For `editBtn`, `copyBtn`, `updateBtn`, `deleteBtn`, `loadBtn`, and `OnEnter`, each gets a new anonymous function capturing `instanceID`, `diffID`, `zoneKey`, `buildIndex`, and `reminder`. With 20+ builds, this generates 120+ closures per refresh. Consider storing the data on the row frame via attributes and using a shared click handler.
- **Medium:** EJ cache saved to SavedVariables (`settings.ejCache`). Grows with each expansion, bloating `UIThingsDB`.
- **Low:** Uses deprecated `UIDropDownMenuTemplate` API. Works currently but may break in future patches.
- **Low (NEW):** `DecodeImportString` does not type-check `importStream` internals. Malformed import strings could produce unexpected behavior rather than a clean error.

---

### TalentReminder.lua (~1552 lines)

**Status:** Previous HIGH issue fixed. One medium remains. One new low.

- **FIXED:** `CleanupSavedVariables()` now migrates old-format builds by wrapping them in arrays (`zones[zoneKey] = { value }`) instead of deleting them.

- **HIGH (NEW): `ApplyTalents` uses pre-refund rank values (lines 1044-1165).** The `currentTalents` map is built at lines 1044-1054, capturing `nodeInfo.currentRank` for all talent nodes. Then the refund step (lines 1085-1098) calls `C_Traits.RefundRank()` to reset nodes to rank 0. But the apply step (lines 1119-1165) reads `current.rank` from the stale `currentTalents` map. For a node that had rank 3 before refund: the actual rank is now 0, but `currentRank` reads 3 from the stale map. The apply loop `for i = currentRank + 1, savedData.rank` becomes `for i = 4, savedData.rank`, **skipping ranks 1-3 entirely**. Talents end up under-purchased or not applied. **Fix:** Re-capture `currentTalents` after the refund step completes, before the apply step begins.

- **Medium (NEW): No prerequisite chain validation in `ApplyTalents` (lines 1100-1165).** Talents are sorted by `posY` (top-to-bottom) to approximate prerequisite ordering, but if a prerequisite fails to apply, all dependent talents are still attempted and silently fail. The code logs individual errors but doesn't break the chain or inform the user which prerequisite failed. For complex talent trees with lateral dependencies, `posY` sorting is insufficient.

- **Medium:** `table.remove` index shifting in `DeleteReminder` is fragile for future maintainers. Currently handled correctly (reverse-sorted deletions in TalentPanel.lua), but poorly documented.
- **Low (NEW):** `ReleaseAlertFrame()` (lines 1508-1529) clears `alertFrame.currentReminder = nil` but does not clear `alertFrame.currentMismatches`. The `currentMismatches` table (set on line 1268 in `UpdateAlertFrame`) contains mismatch data that persists after the alert is released, preventing the table and its contents from being garbage collected. Add `alertFrame.currentMismatches = nil` to the release function.
- `ApplyTalents` correctly checks `InCombatLockdown()`.
- Priority-based talent matching (zone-specific=1, instance-wide=2) is solid.
- Subzone-based detection via `GetSubZoneText()` for raid boss areas.

---

### ActionBars.lua (~1527 lines)

**Status:** One medium. Two low.

- **Medium:** Combat deferral frame leak (lines 1147-1154 and 1266-1273). Both `ApplySkin()` and `RemoveSkin()` create a new `CreateFrame("Frame")` when called during combat. Frames persist indefinitely (WoW has no `DestroyFrame`). If called repeatedly during combat, frames accumulate.
  **Fix:** Use a single module-level deferral frame with a flag.

- Three-layer combat-safe positioning remains exemplary.
- All `RegisterStateDriver`/`UnregisterStateDriver` calls properly guarded.
- Micro-menu drawer uses `SetAlpha(0)`/`EnableMouse(false)` instead of `Show`/`Hide` to avoid triggering Blizzard's `MicroMenuContainer:Layout()` crash. `PatchMicroMenuLayout()` crash guard is well-designed.
- **Low:** File is 1527 lines. Consider splitting skin vs. drawer logic.
- **Low:** `SkinButton` calls `button.icon:GetMaskTextures()` every time. Only on skin apply, not hot path.

---

### CastBar.lua (~578 lines)

**Status:** Two medium issues.

- **Medium (NEW):** Same combat deferral frame leak as ActionBars.lua (lines 284-291 and 316-323). `HideBlizzardCastBar()` and `RestoreBlizzardCastBar()` each create a disposable frame during combat.
- **Medium:** `OnUpdateCasting`/`OnUpdateChanneling` call `string.format("%.1fs", ...)` every frame. Throttle to 0.05s would reduce calls by ~75%.
- **Low:** `ApplyBarColor` allocates a new color table on every cast start when using class color. Could use a reusable module-level table.

---

### ChatSkin.lua (~1325 lines)

**Status:** One medium issue. One low (downgraded).

- **Low (downgraded):** `HighlightKeywords` creates a local `placeholders` table on every call. Fresh per-invocation is correct design to avoid stale state; not a real performance concern.
- **Medium:** `SetItemRef` is replaced globally instead of using `hooksecurefunc`. Breaks the addon hook chain.
- URL detection with `lunaurl:` custom hyperlink type is well-implemented.
- Copy box with `GetMessageInfo` + fallback is good defense-in-depth.

---

### Kick.lua (~1607 lines)

**Status:** Clean. No new issues.

- `OnUpdateHandler` runs at 0.1s throttle. Good.
- `issecretvalue(spellID)` checks present.
- Two display modes (standalone vs party frame attachment) cleanly separated.
- `RegisterUnitEvent` for per-unit watching reduces event traffic.
- **Low:** `activeCDs` table churn at 0.1s interval. Negligible for small interrupt lists.

---

### MinimapCustom.lua (~1127 lines, +69 lines from QueueStatusButton hooks)

**Status:** Five medium issues (3 new). Two low. Updated ninth pass.

- **Medium (NEW):** `AnchorQueueEyeToMinimap()` (line 29) calls `QueueStatusButton:SetParent(Minimap)` without `InCombatLockdown()` guard. `QueueStatusButton` may be protected during combat, and `SetParent` on a protected frame during lockdown causes taint. This is called from all three hooks (OnShow, SetPoint, UpdatePosition) via `C_Timer.After(0)`, which can fire during combat.
- **Medium (NEW):** Triple redundant `C_Timer.After(0)` scheduling (lines 41-75). When Blizzard repositions the eye, the `SetPoint` hook fires, scheduling a deferred reposition. If `UpdatePosition` also exists and fires, it schedules a second deferred call. And if `OnShow` also fires, a third. All three schedule `AnchorQueueEyeToMinimap()` for the same next-frame. A single coalescing flag (e.g., `queueEyePending`) would eliminate redundant calls.
- **Medium (NEW):** Potential hook conflict with ActionBars.lua. If ActionBars.lua also hooks `QueueStatusButton` positioning methods (e.g., for micro-menu drawer layout), the two modules could fight over the button's position. Currently ActionBars.lua does not hook QueueStatusButton directly, but the pattern is fragile if either module changes.
- **Medium:** `SetDrawerCollapsed` shows/hides collected minimap buttons without `InCombatLockdown()` check. Could taint secure buttons from other addons.
- **Medium:** `CollectMinimapButtons` iterates all Minimap children on every call. Not cached.
- **Low:** `GetMinimapShape = nil` for round shape; should be `function() return "ROUND" end`.
- **Low:** Dead code in zone drag handler: `select(2, Minimap:GetTop(), Minimap:GetTop())`.
- **Low:** Clock ticker (`C_Timer.NewTicker(1, UpdateClock)`) never cancelled when feature disabled.

---

### ObjectiveTracker.lua (~2129 lines)

**Status:** Two medium items remain. One low. Unchanged.

- **Medium:** Hot path string concatenation generates ~90 temporary strings per 30-quest update cycle.
- **Medium:** Two separate frames (`f` and `hookFrame`) register overlapping events.
- **Low:** `OnAchieveClick` does not type-check `self.achieID`.

---

### MinimapButton.lua (~101 lines)

**Status:** Clean. No issues.

---

## Per-File Analysis -- Config System

### config/ConfigMain.lua (~433 lines)

**Status:** One low-priority structural concern. Otherwise clean.

- Sidebar navigation for 20+ modules. Addon Versions correctly placed last.
- `OnHide` auto-locks frames, loot anchor, SCT anchors, and widgets; closes M+ demo.
- **Low:** ~180 lines of mechanical boilerplate creating 20 panel frames with identical patterns. Could be replaced with a data-driven loop.

---

### config/Helpers.lua (~619 lines)

**Status:** Clean. Well-designed utility library.

- `BuildFontList` discovers fonts from both hardcoded paths and dynamic `GetFonts()` API. Comprehensive.
- `CreateColorSwatch` is the canonical color picker implementation. Used correctly by 8 panels.
- **Low:** Font list built once at load time. New fonts require `/reload`.

---

### config/panels/TrackerPanel.lua (~1159 lines)

**Status:** One medium-priority concern. Unchanged.

- **Medium:** 7 inline color swatches (~315 lines) duplicate `Helpers.CreateColorSwatch` functionality. Also uses `UIDropDownMenu_CreateInfo()` for color picker info tables (semantically incorrect).

---

### config/panels/TalentPanel.lua (~1142 lines)

**Status:** Clean. Updated for array format. Minor dead code.

- `sortedReminders` properly handles new array format with `ipairs(builds)`.
- Delete operations correctly iterate in reverse for safe `table.remove`.
- **Low:** ~40 lines of unreachable nil-checks for row elements that are always created in the initialization block above.

---

### config/panels/ActionBarsPanel.lua (~792 lines)

**Status:** One medium concern.

- **Medium:** 5 inline color swatches (~225 lines) duplicate `Helpers.CreateColorSwatch`.
- Conflicting addon detection and bar drag UX are well-implemented.

---

### config/panels/MinimapPanel.lua (~658 lines)

**Status:** Two medium concerns.

- **Medium:** 5 inline color swatches (~225 lines) duplicate `Helpers.CreateColorSwatch`.
- **Medium (NEW):** Border color swatch (lines 107-134) missing `opacityFunc` handler. Dragging the opacity slider won't update the border color in real-time.

---

### config/panels/FramesPanel.lua (~641 lines)

**Status:** Two medium concerns.

- **Medium:** 2 inline color swatches (~90 lines) duplicate `Helpers.CreateColorSwatch`.
- **Medium (NEW):** Duplicate functions: `CopyTable` (lines 141-151) duplicates `Helpers.DeepCopy`; `NameExists` is defined twice identically.

---

### config/panels/AddonVersionsPanel.lua (~614 lines)

**Status:** Two medium concerns.

- **Medium:** Export/import dialog frames created per click. WoW frames never garbage collected. Should create once and show/hide.
- **Medium:** `DeserializeString` uses `loadstring("return " .. str)` with `setfenv` sandboxing but no input length check.

---

### config/panels/LootPanel.lua (~360 lines)

**Status:** One medium concern (new).

- **Medium (NEW):** `addonTable.Loot.UpdateSettings()` called without nil-checking `addonTable.Loot` first (8 occurrences). If Loot module fails to load, any config change crashes.

---

### config/panels/VendorPanel.lua (~185 lines)

**Status:** One medium concern (new).

- **Medium (NEW):** `addonTable.Vendor.UpdateSettings` accessed without nil-checking `addonTable.Vendor` first (6 occurrences). Same crash risk as LootPanel.

---

### config/panels/WidgetsPanel.lua (~413 lines)

**Status:** Two medium observations. Two medium from 2026-02-20.

- **Medium:** Widget anchor dropdown won't show new frames added while config is open.
- **Medium:** 1 inline color swatch when `Helpers.CreateColorSwatch` is available.
- **Medium (2026-02-20):** `CONDITIONS` table (7 entries, each a table) is defined inside the `for i, widget in ipairs(widgets)` loop body (line 246). Creates 182 table objects every time the Widgets config panel is opened. Should be hoisted to file scope as a module-level constant.
- **Medium (2026-02-20):** `GetConditionLabel` local function (line 274) is defined inside the same loop. Creates 26 closure allocations per panel open. Should also be hoisted to file scope.

---

### config/panels/NotificationsPanel.lua (~331 lines)

**Status:** One medium concern.

- **Medium:** 2 inline color swatches (~76 lines) duplicate `Helpers.CreateColorSwatch`.

---

### Other Config Panels

**CombatPanel.lua, KickPanel.lua, MiscPanel.lua, CastBarPanel.lua, ChatSkinPanel.lua, QuestReminderPanel.lua, QuestAutoPanel.lua, MplusTimerPanel.lua, TalentManagerPanel.lua, ReagentsPanel.lua** -- All clean. Follow established patterns. MplusTimerPanel.lua's `SwatchRow` helper is the best DRY example with 15 swatches using `CreateColorSwatch`.

---

## Per-File Analysis -- Widget Files

### widgets/Widgets.lua (Framework, ~460 lines)

**Status:** Three medium concerns. One low.

- **Medium (NEW):** `UpdateAnchoredLayouts` creates fresh temporary tables every 1-second tick. Should cache sorted layout and rebuild only when widgets change.
- **Medium (NEW):** `UpdateVisuals` (lines 266-274) builds its own anchor lookup, duplicating the cached `RebuildAnchorCache()` system. Should reuse the cache.
- **Medium (previous):** Widget ticker calls `UpdateContent` on all enabled widgets every second. Many are purely event-driven. An `eventDriven` flag could skip these.
- **Low (NEW):** `OnUpdate` script on every widget frame fires every render frame (60-144 Hz). Body only executes when `self.isMoving` is true. ~2000+ no-op calls/second across 20+ widgets. Set `OnUpdate` only in `OnDragStart`, clear in `OnDragStop`.
- NEW: `EvaluateCondition()` with 7 conditions is well-implemented. `SmartAnchorTooltip` adjusts tooltip anchor based on screen position.

---

### widgets/Group.lua (~569 lines)

**Status:** HIGH severity issue fixed.

- **FIXED: `IsGuildMember()` does not exist (line 391).** Replaced with `IsInGuild()` guard + `C_GuildInfo.MemberExistsByName(shortName)` using the documented API. Name is split on `-` to strip server suffix.

- **FIXED (previous):** `readyCheckActive`/`readyCheckResponses` scoping correct.
- **FIXED (previous):** Cached atlas constants used in tooltip.

---

### widgets/Teleports.lua (~580 lines)

**Status:** Two medium issues (new).

- **Medium (NEW): FontString inserted into button array causes crash (lines 549-554).** When no teleports are available, a FontString is pushed into `mainButtons`. Later, `ClearMainPanel()` calls `ReleaseButton(btn, btn:IsProtected())` on it. FontStrings have no `IsProtected()` method, causing `attempt to call method 'IsProtected' (a nil value)`.
  **Fix:** Track the "no spells" FontString separately from the button array.

- **Medium (NEW): `ReleaseButton` SetAttribute during combat (lines 322-336).** When the panel is hidden (ESC, clicking outside), `ClearMainPanel`/`ClearSubPanel` call `ReleaseButton` on secure buttons. `SetAttribute` on a secure frame during `InCombatLockdown()` causes taint. The panel creation guards against opening in combat, but the panel can be hidden at any time.
  **Fix:** Guard secure operations in `ReleaseButton` with `if not InCombatLockdown() then`.

---

### widgets/Keystone.lua (~411 lines)

**Status:** Two medium issues. One new.

- **Medium (NEW): Position saved in wrong schema (line 137).** Secure overlay's `OnDragStop` saves to `UIThingsDB.widgets.keystone.pos = {x, y}`, but the framework reads from `UIThingsDB.widgets.keystone.point/relPoint/x/y`. Position is never restored -- widget snaps back after reload.
  **Fix:** Use the framework's position saving pattern.

- **Medium (previous):** Full bag scan every tick in `GetPlayerKeystone()`. Should cache and rescan on `BAG_UPDATE`.
- **FIXED (previous):** Combat guards on `BuildTeleportMap`.

---

### widgets/SessionStats.lua (~143 lines) -- NEW

**Status:** Clean. Integration verified.

- **FIXED: Defaults verified present.** `DEFAULTS.widgets.sessionStats` exists in Core.lua and `widgets/SessionStats.lua` is listed in the TOC.
- Uses EventBus for `PLAYER_DEAD` and `CHAT_MSG_LOOT`. Clean implementation.
- Right-click reset is a nice UX touch.
- `issecretvalue()` check on gold amount (line 73). Good defensive coding.

---

### widgets/MythicRating.lua (~174 lines)

**Status:** One medium issue (new).

- **Medium (NEW): `bestRunLevel` may be nil (lines 85, 94).** The `MapSeasonBestInfo` table may not have `bestRunLevel` field, causing `string.format("+%d", nil)` error in tooltip. Add nil guard.

---

### widgets/Friends.lua (~132 lines)

**Status:** One medium issue (new).

- **Medium (NEW): `C_ClassColor.GetClassColor` given localized class name (line 22).** `C_FriendList.GetFriendInfoByIndex` returns `className` as localized text. `C_ClassColor.GetClassColor` expects English token. All WoW friend names display white on non-English clients. Not a crash (nil check handles it) but functionally broken.

---

### widgets/Durability.lua (~99 lines)

**Status:** One medium issue (new).

- **FIXED (partial):** Duplicate EventBus registration is now prevented by EventBus deduplication. However, registrations (lines 35-37) still happen unconditionally outside `ApplyEvents` — events fire even when the widget is disabled. Should move into `ApplyEvents`.

---

### widgets/Vault.lua (~126 lines) and widgets/WeeklyReset.lua (~122 lines)

**Status:** One medium issue each (new).

- **Medium (NEW):** Both use `ShowUIPanel`/`HideUIPanel` on Blizzard panels (`WeeklyRewardsFrame`, `CalendarFrame`) without `InCombatLockdown()` guard. Will cause taint errors if clicked during combat.

---

### widgets/Spec.lua (~74 lines)

**Status:** Two medium issues.

- **Medium (NEW):** `SetSpecialization` callable during combat via delayed menu click. If combat begins after the menu opens but before the user clicks, taint error occurs.
- **Medium (previous):** `UpdateContent` calls `GetSpecialization()`, `GetSpecializationInfo()`, `GetLootSpecialization()`, and `GetSpecializationInfoByID()` every 1-second tick. Should cache and update on spec change events only.

---

### widgets/FPS.lua (~130 lines)

**Status:** One medium concern. One low. Unchanged.

- **Medium:** `UpdateAddOnMemoryUsage()` in tooltip `OnEnter`. Expensive call could cause frame hitch.
- **Low:** Redundant sort of already-sorted addon memory list.

---

### widgets/Speed.lua (~64 lines)

**Status:** One low note.

- **Low:** Dual update mechanism: `HookScript("OnUpdate", ...)` at 0.5s + framework ticker at 1s. One call is redundant.

---

### widgets/Guild.lua (~69 lines)

**Status:** One low note.

- **Low:** No cap on tooltip members for large guilds. 500+ member guilds could cause rendering issues.

---

### widgets/DarkmoonFaire.lua (~133 lines)

**Status:** One low note.

- **Low:** `GetDMFInfo()` recalculated every 1-second tick. Result changes once per minute. Could cache for 60 seconds.

---

### widgets/Bags.lua (~139 lines)

**Status:** One low note.

- **Low:** Full currency list iterated on every tooltip hover. Could cache filtered list.

---

### widgets/Currency.lua (~258 lines)

**Status:** One low note.

- **Low:** `GetCurrencyData` creates a new table per call on hot path. Called 6 times per tick.

---

### widgets/Hearthstone.lua (~195 lines)

**Status:** One low note.

- **Low:** `GetRandomHearthstoneID` called at file load time before `PLAYER_LOGIN`. `PlayerHasToy` may not return accurate data. Correctly rebuilt later in `OnHearthEnteringWorld`.

---

### widgets/Lockouts.lua (~163 lines) -- UPDATED

**Status:** Clean. Previous issue fixed.

- **FIXED (ninth pass):** OnClick handler rewritten from removed `ToggleRaidFrame()` API to `ToggleFriendsFrame(3)` + `RaidInfoFrame:Show()`. Correct API for current WoW client (12.0).
- Proper `ApplyEvents(enabled)` pattern with `UPDATE_INSTANCE_INFO` and `PLAYER_ENTERING_WORLD` events.
- `RequestRaidInfo()` called on world entry with 2-second delayed refresh. Good timing pattern.
- Tooltip displays instance name, difficulty, boss progress, and time remaining.

---

### widgets/XPRep.lua (~245 lines) -- NEW

**Status:** One low issue. Otherwise clean.

- **Low (NEW):** OnClick (lines 232-239) calls `ToggleCharacter("ReputationFrame")` at max level. `ToggleCharacter` opens a Blizzard-owned protected frame. If clicked during combat, this will cause taint. Add `if InCombatLockdown() then return end` guard.
- Proper `ApplyEvents(enabled)` pattern with 5 events (`PLAYER_XP_UPDATE`, `PLAYER_LEVEL_UP`, `UPDATE_FACTION`, `PLAYER_ENTERING_WORLD`, `MAJOR_FACTION_RENOWN_LEVEL_CHANGED`).
- Handles max-level (reputation display) vs leveling (XP display) correctly.
- Renown + paragon support with reward indicator (`!` suffix when paragon reward is pending).
- `AbbreviateNumber()` utility for large XP/rep values.
- Core.lua defaults and TOC entry verified present.

---

### Clean Widget Files (No Issues)

**Combat.lua** (39 lines), **Mail.lua** (52 lines), **ItemLevel.lua** (96 lines), **Zone.lua** (95 lines), **PullCounter.lua** (155 lines), **Volume.lua** (72 lines), **PvP.lua** (121 lines), **BattleRes.lua** (87 lines), **Coordinates.lua** (55 lines), **Time.lua** (66 lines), **WeeklyReset.lua** (noted above for combat guard) -- All clean and follow established patterns.

---

## Cross-Cutting Concerns

### 1. Duplicate EventBus Registration (HIGH Priority -- FIXED)

**FIXED:** `EventBus.Register` now scans the existing subscriber array for the same function reference before inserting (deduplication at the infrastructure level). This prevents duplicate listeners from accumulating when `ApplyEvents()`/`UpdateSettings()` is called multiple times. All affected modules (Vendor, Loot, Misc, QuestAuto, QuestReminder, Durability, and any future modules) are protected without per-module changes.

### 2. Talent Build Data Migration (HIGH Priority -- FIXED)

**FIXED:** `CleanupSavedVariables()` now wraps old-format builds in arrays (`zones[zoneKey] = { value }`) instead of deleting them.

### 3. Combat.lua Consumable Tracking Architecture (HIGH Priority -- FIXED)

**FIXED:** The broken `C_Item.GetItemInfoInstant(spellName)` path has been replaced by a return-early in `UNIT_SPELLCAST_SUCCEEDED` (lines 1144-1148). Consumable usage is now tracked correctly via hooks on `UseAction`, `C_Container.UseContainerItem`, and `UseItemByName`, which capture the actual item ID at the point of use. This is architecturally superior to the spell-cast-event approach.

### 4. Loot.lua Toast Pool Corruption (Critical -- NEW)

`RecycleToast()` does not clear the `OnUpdate` script set during frame creation. Pooled (hidden) frames continue firing `OnUpdate` every render frame, accessing `self.timeParams` which may be nil. Additionally, the item link pattern `|Hitem:.-|h` is truncated and misses the item name portion of links, producing malformed links that break `GetItemInfo()` lookups. Both issues affect core loot toast functionality.

### 5. TalentManager Stale Build Index (Critical -- NEW)

Button closures in `SetRowAsBuild` capture `buildIndex` by value. When builds are deleted or `RefreshBuildList` re-sorts the list, captured indices become stale. Delete/edit/update operations may target the wrong build or crash on out-of-bounds access.

### 6. TalentReminder ApplyTalents Stale Ranks (High -- NEW)

`ApplyTalents` captures all talent node ranks before the refund step, then uses those stale values in the apply step. After refund, actual ranks are 0 but the code reads pre-refund values, causing the apply loop to skip purchasing ranks for refunded nodes.

### 7. Combat Deferral Frame Accumulation (Medium Priority)

ActionBars.lua and CastBar.lua create disposable `CreateFrame("Frame")` instances when called during combat lockdown. WoW frames are never garbage collected. **Fix:** Use a reusable module-level frame.

### 8. Config Panel Color Swatch Duplication (Medium Priority)

~960 lines of duplicated color swatch code across 6 panels (TrackerPanel, ActionBarsPanel, MinimapPanel, NotificationsPanel, FramesPanel, WidgetsPanel) when `Helpers.CreateColorSwatch` already exists. 8 panels already use the helper correctly.

### 9. Config Panel Unguarded Module Access (Medium Priority)

LootPanel.lua (8 occurrences) and VendorPanel.lua (6 occurrences) access module methods without nil-checking the module first. Will crash if the module fails to load.

### 10. Locale-Dependent String Matching (Medium Priority)

- Loot.lua `"^You receive"` pattern fails on non-English clients
- Friends.lua `C_ClassColor.GetClassColor` given localized class name

### 11. Missing Combat Lockdown Guards (Medium Priority)

- MinimapCustom.lua `AnchorQueueEyeToMinimap` -- `SetParent(Minimap)` on protected QueueStatusButton (NEW)
- MinimapCustom.lua `SetDrawerCollapsed`
- Teleports.lua `ReleaseButton` on secure buttons
- Vault.lua / WeeklyReset.lua `ShowUIPanel`/`HideUIPanel`
- Spec.lua delayed menu click
- XPRep.lua `ToggleCharacter("ReputationFrame")` in OnClick (NEW)

### 12. Duplicated Border Drawing Code (Medium Priority)

At least 5 files implement nearly identical border texture creation.

### 13. Widget Ticker Efficiency (Medium Priority)

The widget framework's shared ticker calls `UpdateContent` on all enabled widgets every second. Many are purely event-driven.

### 14. TalentManager Closure Churn (Medium Priority -- NEW)

`SetRowAsBuild` creates 6 closures per build row on every `RefreshBuildList` call. For users with 20+ builds, this generates 120+ closure allocations per refresh. Consider storing build data as frame attributes and using shared click handlers that read from `self:GetParent()` data.

### 15. Combat Lockdown Handling (Strength)

The codebase is consistently defensive about combat lockdown. The three-layer ActionBars pattern is exemplary. The exceptions noted above are localized and low-risk.

### 16. Frame Pooling (Strength)

Consistently used in Loot.lua, Frames.lua, Teleports.lua, Currency.lua, TalentManager.lua, and WidgetsPanel.

### 17. Centralized TTS (Strength)

`Core.SpeakTTS` centralizes text-to-speech with graceful API fallbacks.

### 18. Widget ApplyEvents Pattern (Strength)

Widgets consistently implement `ApplyEvents(enabled)`. Excellent pattern across all 27 widget files.

### 19. Widget Visibility Conditions (Strength)

The `EvaluateCondition()` system with 7 conditions and 8 EventBus trigger events is well-designed and reduces widget clutter effectively.

### 20. Saved Variable Separation (Strength)

`LunaUITweaks_TalentReminders`, `LunaUITweaks_ReagentData`, `LunaUITweaks_QuestReminders` survive settings resets.

### 21. Consumable Tracking Architecture (Strength -- NEW)

The hook-based consumable tracking in Combat.lua (`UseAction`, `C_Container.UseContainerItem`, `UseItemByName`) is architecturally correct. It captures the actual item ID at the point of use rather than trying to reverse-map spell IDs from cast events, which is unreliable.

---

## Priority Recommendations

### Critical (Fix Immediately)

1. **FIXED: MplusTimer.lua forward reference (line 701)** -- Added `local OnChallengeEvent` forward declaration at file top and changed definition to assignment. M+ event processing now works correctly.

1b. **NEW: Loot.lua OnUpdate not cleared on recycled toast frames (lines 137-148, 167-180).** `RecycleToast()` hides the frame and returns it to the pool but never clears the `OnUpdate` script. The script continues firing on hidden pooled frames, accessing `self.timeParams.elapsed` on nil. Add `toast:SetScript("OnUpdate", nil)` to `RecycleToast()`.

1c. **NEW: Loot.lua truncated item link regex (line 494).** Pattern `|Hitem:.-|h` captures only up to the first `|h`, missing the item name and closing `|h|r`. Produces malformed links that fail `GetItemInfo()` lookups. Fix to `|Hitem:.-|h.-|h` or similar.

1d. **NEW: TalentManager.lua stale `buildIndex` in button closures (lines 410-438).** Delete/edit/update buttons capture `buildIndex` by value. After sorting or deleting other builds, the index points to wrong build. Use stable identifier instead of array index.

### High Priority

2a. **NEW: TalentReminder.lua `ApplyTalents` uses pre-refund rank values (lines 1044-1165).** `currentTalents` map built before refund step captures stale ranks. After refund, apply loop skips ranks 1-N for refunded nodes. Re-capture `currentTalents` after refund step.

2. **FIXED (2026-02-21): Combat.lua `C_Item.GetItemInfoInstant(spellName)` (was line 1151)** -- `UNIT_SPELLCAST_SUCCEEDED` handler now returns early (lines 1144-1148). Consumable tracking correctly uses `UseAction`/`UseContainerItem`/`UseItemByName` hooks.

3. **FIXED: EventBus duplicate registration** -- `EventBus.Register` now deduplicates by scanning for existing callback references before inserting.

4. **FIXED: Group.lua `IsGuildMember()` (line 391)** -- Replaced with `IsInGuild()` + `C_GuildInfo.MemberExistsByName()`.

5. **FIXED: TalentManager.lua `instanceType` undefined (line 1141)** -- Moved `GetInstanceInfo()` call before the `instanceType` reference.

6. **FIXED: TalentReminder.lua data migration** -- `CleanupSavedVariables()` now wraps old-format builds in arrays instead of deleting them.

### Medium Priority

7. **Teleports.lua FontString in button array (lines 549-554)** -- Track "no spells" FontString separately to avoid crash in `ClearMainPanel`.
8. **Teleports.lua SetAttribute during combat** -- Guard `ReleaseButton` secure operations with `InCombatLockdown()`.
9. **Keystone.lua position saved in wrong schema (line 137)** -- Use framework position keys.
10. **FIXED: SessionStats.lua defaults verification** -- Core.lua DEFAULTS and TOC entry confirmed present.
11. **MythicRating.lua nil `bestRunLevel`** -- Add nil guard before `string.format`.
12. **Combat deferral frame leak** -- ActionBars.lua + CastBar.lua: use reusable module-level frame.
13. **Combat.lua infinite retry in TrackConsumableUsage** -- Add retry counter (max 5 attempts).
14. **MinimapCustom.lua SetDrawerCollapsed combat guard** -- Add `InCombatLockdown()` check.
14b. **MinimapCustom.lua QueueStatusButton SetParent combat guard (NEW)** -- `AnchorQueueEyeToMinimap` calls `SetParent(Minimap)` on protected frame without combat check.
14c. **MinimapCustom.lua triple redundant C_Timer.After(0) scheduling (NEW)** -- Add coalescing flag to prevent 3 deferred calls for same reposition.
15. **ChatSkin.lua SetItemRef override** -- Use `hooksecurefunc` instead.
16. **Downgraded: ChatSkin.lua HighlightKeywords table allocation** -- Per-invocation table is correct design to avoid stale state. Moved to low priority.
17. **Vault.lua / WeeklyReset.lua ShowUIPanel combat guard** -- Add `InCombatLockdown()` check.
18. **Spec.lua menu click combat guard** -- Check `InCombatLockdown()` in menu callbacks.
19. **Friends.lua localized class name** -- Use `classFilename` (English token) instead of `className`.
20. **Durability.lua unconditional event registration** -- Move into `ApplyEvents`.
21. **EventBus snapshot allocation per dispatch** -- Consider scratch table reuse.
22. **WidgetsPanel.lua `CONDITIONS` table inside loop (line 246) (NEW 2026-02-20)** -- Hoist to file-scope constant; eliminates 182 table allocs per panel open.
23. **WidgetsPanel.lua `GetConditionLabel` closure inside loop (line 274) (NEW 2026-02-20)** -- Hoist to file scope; eliminates 26 closure allocs per panel open.
24. **Config panel color swatch duplication (~960 lines)** -- Migrate 22 inline swatches to `Helpers.CreateColorSwatch`.
25. **LootPanel.lua / VendorPanel.lua unguarded module access** -- Add nil checks.
26. **AddonVersionsPanel.lua frame leak** -- Create dialog frames once, show/hide.
27. **AddonVersionsPanel.lua loadstring length check** -- Add max input length guard.
28. **MinimapPanel.lua missing opacityFunc** -- Add opacity callback to border swatch.
29. **FramesPanel.lua duplicate functions** -- Use `Helpers.DeepCopy`, extract `NameExists`.
30. **TalentManager.lua scratch tables** -- Reuse module-level tables with `wipe()`.
31. **FIXED (2026-02-21): TalentManager.lua EJ cache tier mutation** -- Now saves/restores current tier selection.
32. **Keystone.lua bag scan every tick** -- Cache and rescan on `BAG_UPDATE`.
33. **Spec.lua API calls every tick** -- Cache and update on spec change events.
34. **Extract shared border utility** -- Reduce duplicated border code across 5+ files.
35. **Extract color picker helper** -- Already exists as `Helpers.CreateColorSwatch`, just needs adoption.
36. **MinimapCustom.lua cache collected buttons** -- Don't iterate all children every call.
37. **FPS widget memory scan** -- Move to background timer.
38. **ObjectiveTracker string concatenation** -- Use `table.concat` in hot paths.
39. **CastBar.lua cast time throttle** -- 0.05s throttle on `string.format`.
40. **TalentManager.lua SetRowAsBuild closure churn (NEW 2026-02-21)** -- Store data as frame attributes; use shared click handlers. Eliminates 120+ closures per refresh.
41. **TalentManager.lua EJ cache bloat** -- Cache grows with each expansion in SavedVariables.
42. **TalentReminder.lua ApplyTalents prerequisite chain validation (NEW 2026-02-21)** -- Failed prerequisites don't block dependent talents. Add chain-aware error handling.

### Low Priority / Polish

42. Core.lua DEFAULTS table placement (inside handler vs file scope)
43. Loot.lua redundant `if i == 1` branches
44. Combat.lua triplicate `ApplyReminderLock()` calls (lines 1048, 1070, 1135)
45. Combat.lua stale comment "Create 4 text lines" (line 1113, loop creates 5)
46. MplusTimer death tooltip temp table
47. Guild widget tooltip cap for large guilds
48. Speed widget dual-update mechanism
49. MinimapCustom.lua `GetMinimapShape` should return `"ROUND"`
50. MinimapCustom.lua dead code in zone drag handler
51. MinimapCustom.lua clock ticker never cancelled
52. Frames.lua `SetBorder` function hoisting
53. ObjectiveTracker `OnAchieveClick` type guard
54. TalentManager.lua deprecated UIDropDownMenu API
55. TalentManager.lua `DecodeImportString` type safety (NEW 2026-02-21)
56. TalentReminder.lua `ReleaseAlertFrame` does not clear `currentMismatches` (NEW 2026-02-21)
57. Reagents.lua `GetTrackedCharacters` caching
58. DarkmoonFaire.lua tick rate for DMF info
59. Bags.lua currency list caching
60. Currency.lua table allocation per tick
61. Hearthstone.lua early attribute set
62. Widgets.lua OnUpdate on all frames (set only during drag)
63. Widgets.lua duplicate anchor lookup
64. TalentPanel.lua unreachable nil-checks (~40 lines)
65. ChatSkinPanel.lua dead SetPoint
66. ReagentsPanel.lua StaticPopupDialogs recreation
67. ConfigMain.lua boilerplate reduction
68. ~100 global frame names with generic "UIThings" prefix
69. CastBar.lua color table allocation per cast start
70. XPRep.lua `ToggleCharacter` without `InCombatLockdown()` guard in OnClick (NEW)

---

## Line Count Summary

| Category | Files | Lines |
|----------|-------|-------|
| Core Modules | 12 | 5,309 |
| UI Modules | 10 | 12,669 |
| Config System | 22 | 9,311 |
| Widget Files | 30 | 5,123 |
| **Total** | **74** | **32,412** |
