# LunaUITweaks -- Comprehensive Code Review

**Review Date:** 2026-02-16
**Scope:** All 19 core source files, architecture, and cross-cutting concerns
**Focus:** Performance, memory leaks, code readability, nil checks, combat lockdown safety, unused variables, inconsistent patterns

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Per-File Analysis](#per-file-analysis)
3. [Cross-Cutting Concerns](#cross-cutting-concerns)
4. [Priority Recommendations](#priority-recommendations)

---

## Executive Summary

LunaUITweaks is a well-structured addon with consistent patterns, good combat lockdown awareness, and effective use of frame pooling. The codebase demonstrates a strong understanding of the WoW API and its restrictions. Key strengths include the three-layer combat-safe positioning in ActionBars, proper event-driven architecture, and shared utility patterns (logging, SafeAfter).

**Critical Issues:** 0
**High Priority:** 6
**Medium Priority:** 14
**Low Priority / Polish:** 12

The most impactful improvements would be:
1. Reducing table allocations in hot paths (ObjectiveTracker update cycle)
2. Adding missing nil guards in a few event handlers
3. Consolidating duplicated border-drawing code into a shared utility
4. Adding cleanup for stale data in long-running tables (prevObjectiveState, questLineCache)

---

## Per-File Analysis

### Core.lua (~290 lines)

**Performance Issues:**
- `Log()` creates the `colors` table on every call. This table is static and should be hoisted to module scope as an upvalue. With INFO-level filtering most calls are dropped early, but every call still allocates the table before the level check.

```lua
-- Current (allocates on every call)
function addonTable.Core.Log(module, msg, level)
    local colors = { [0] = "888888", [1] = "00FF00", ... }
```

- `string.format` in `Log()` runs even when the message will be dropped. The level check should come before the format call -- which it does, but the colors table is still allocated.

**Code Readability:**
- Clean and well-documented. Good use of LuaDoc-style comments.
- `ApplyDefaults` uses the `value.r` check to detect color tables, which is documented in CLAUDE.md. This is a pragmatic convention but relies on no non-color table having an `r` key at the top level.

**Missing Nil Checks:**
- `ApplyDefaults` does not guard against `db` being nil. If a module key is missing from `UIThingsDB`, the recursive call would error. In practice this is prevented because `db[key] = db[key] or {}` creates the subtable, but the initial `db` parameter itself has no guard.

**Recommendations:**
- Hoist the `colors` table to module scope as a constant.

---

### ObjectiveTracker.lua (~2116 lines)

**Performance Issues:**
- **Hot path string concatenation:** `GetQuestTypePrefix`, `GetWQRewardIcon`, `GetDistanceString`, `GetTimeLeftString`, and `GetQuestLineString` all return formatted strings that are concatenated in `RenderSingleWQ` and `RenderSingleQuest`. Each quest in the tracker triggers 3-5 string concatenations per update. For 25+ tracked quests this is 75-125 intermediate strings per update cycle.
- **`GetObjectiveProgress` regex matching** runs on every objective line, even when the quest is not super-tracked. The `btn.isSuperTrackedObjective` check happens after the match in `AddLine`.
- `table.sort` is called in `RenderWorldQuests` on every update for both `activeWQs` and `otherWQs`. The sort comparison functions are recreated as closures each time. These should be hoisted to module-level upvalues.
- `questLineCache` grows indefinitely. While entries expire after 30 seconds, old keys are never removed -- only overwritten. Over a long session with many zones visited, this table grows unbounded.

**Memory Leak Risks:**
- `prevObjectiveState` and `prevQuestComplete` accumulate entries for every quest ever tracked during the session. `QUEST_REMOVED` cleans up individual quests, but quests that simply become unwatched (not removed) leave stale entries. Consider periodic cleanup.
- `itemPool` frames are never truly released. The pool grows monotonically. This is intentional (frame pooling) but worth noting -- if a user has 50 quests visible at once and then collapses to 5, 45 frames remain allocated.

**Missing Nil Checks:**
- `OnQuestClick` checks `self.questID` and `type(self.questID) == "number"` which is good. However, `OnAchieveClick` does not check `type(self.achieID)` -- if it's somehow not a number, `GetAchievementInfo(achID)` could error.
- `AddLine` accesses `ucState.sectionHeaderColor` without nil guard; if settings are corrupted this would error.
- In `RenderScenarios`, `C_ScenarioInfo.GetScenarioStepInfo()` is called with a nil check on the return, but `stepInfo.numCriteria` is used without checking if `stepInfo` is nil first (it's guarded by `stepInfo and stepInfo.numCriteria`).

**Combat Lockdown:**
- Well-handled. `ReleaseItems` checks `InCombatLockdown()` before touching `ItemBtn` attributes. `OnQuestClick` blocks quest log opening in combat. `UpdateContent` uses `RegisterStateDriver` for combat visibility. Quest item button updates are deferred via `pendingQuestItemUpdate`.

**Unused Variables / Dead Code:**
- The `MINUTES_PER_DAY` and `MINUTES_PER_HOUR` constants are only used in `GetTimeLeftString` but are declared at module scope. Fine for readability but could be local to the function.
- The `trackerHiddenByKeybind` toggle mechanism is clean but `LunaUITweaks_ToggleTracker` is only callable via keybind, not from config.

**Inconsistent Patterns:**
- Sort comparison functions in `RenderWorldQuests` are created as anonymous closures inside the function. In `RenderQuests`, the same pattern is used with `filteredIndices`. Both should use pre-defined sort functions to avoid garbage.
- Two separate frames register `PLAYER_LOGIN` and `PLAYER_ENTERING_WORLD` at the bottom of the file (`f` and `hookFrame`). These could be consolidated.

**Recommendations:**
- Pre-define sort comparison functions as upvalues.
- Add periodic cleanup of `prevObjectiveState` / `prevQuestComplete` (e.g., on `ZONE_CHANGED_NEW_AREA`).
- Hoist string formatting out of the inner render loop where possible.

---

### Vendor.lua (~270 lines)

**Performance Issues:**
- `CheckDurability` iterates all 18 equipment slots on every call. This is lightweight and acceptable given the debounce timer.
- `CheckBagSpace` iterates bags 0-4 on every `BAG_UPDATE_DELAYED`. Also lightweight.

**Missing Nil Checks:**
- `AutoRepair` calls `GetRepairAllCost()` and destructures into `repairCost, canRepair`. Both are checked. Good.
- `SellGreys` checks for `C_MerchantFrame.SellAllJunkItems` existence. Good.

**Code Readability:**
- Clean and straightforward. Good separation of warning frames for durability and bag space.
- The `isUnlocking` flag pattern for managing unlock/lock visual transitions is clear.

**Recommendations:**
- None significant. This is one of the cleanest modules.

---

### Loot.lua (~380 lines)

**Performance Issues:**
- `UpdateRosterCache` wipes and rebuilds on every `GROUP_ROSTER_UPDATE`. For raids with 40 players, this creates 40+ table entries. Acceptable since roster changes are infrequent.
- `SpawnToast` calls `GetItemInfo` which can return nil for uncached items. There is no retry or fallback beyond the immediate nil check.
- `GetEquippedIlvlForSlots` is called per loot toast. For rings/trinkets it checks 2 slots. Negligible cost.

**Missing Nil Checks:**
- In `CHAT_MSG_LOOT` handler, `string.match(msg, "|Hitem:.-|h")` could return nil if the message format changes. The `if itemLink then` guard covers this.
- `GetItemInfo(itemLink)` can return nil for the 10th return value (`itemTexture`). The `if itemTexture then` guard is present. Good.

**Code Readability:**
- The `EQUIP_LOC_TO_SLOT` mapping is clear and well-structured.
- Toast factory pattern is clean with proper recycling.

**Inconsistent Patterns:**
- `Loot.UpdateLayout` has identical code in both the `if i == 1` and `else` branches for both grow-up and grow-down. The `if i == 1` check is redundant since `prev` is always `anchorFrame` on the first iteration.

**Recommendations:**
- Simplify `UpdateLayout` by removing the redundant `i == 1` branch.

---

### Combat.lua (~680 lines)

**Performance Issues:**
- `ScanConsumableBuffs` iterates all 40 buff slots but exits early when both flask and food are found. The `lastAuraScanTime` cache prevents redundant scans in the same frame. Good optimization.
- `ScanBagConsumables` iterates all bag slots (potentially 200+) but is cached and only invalidated on `BAG_UPDATE_DELAYED`. Good.
- The weapon buff ticker runs every 10 seconds. It compares a stringified state to avoid unnecessary full updates. Efficient.

**Missing Nil Checks:**
- `TrackConsumableUsage` calls `GetItemInfo(itemID)` twice -- once at the start for a nil check, and again for the full destructure. The second call could return nil if the item data became unavailable between calls (extremely unlikely but theoretically possible).
- `ShowConsumableIcons` accesses `mhBuffed` and `ohBuffed` from the `data` table passed by `UpdateReminderFrame`. These are always set when `type == "weapon"` so it's safe.

**Combat Lockdown:**
- `UpdateReminderFrame` guards with `if InCombatLockdown() then return end`. Good.
- `reminderFrame` is created as `SecureHandlerStateTemplate` for state driver compatibility. Correct.
- Pre-created `SecureActionButtonTemplate` buttons for consumables and pets are correctly created at init time, not during combat.
- Attribute updates (`SetAttribute`) are guarded with `if not InCombatLockdown()` in `ShowPetIcons` and `ShowConsumableIcons`. Good.

**Memory Leak Risks:**
- `consumableUsage` lists in saved variables are capped at 5 entries per category via `table.remove(usage, 1)`. Good.
- `bagScanCache` is properly invalidated on `BAG_UPDATE_DELAYED`.

**Code Readability:**
- Large file with multiple subsystems (timer, logging, reminders, consumable tracking). Consider splitting reminders into a separate file if the file grows further.
- The `CLASS_BUFFS` and `PET_SUMMON_SPELLS` tables are clear and well-commented.

**Recommendations:**
- Consolidate the two `GetItemInfo` calls in `TrackConsumableUsage` into one.
- The `hooksRegistered` guard pattern is good. No action needed.

---

### Misc.lua (~430 lines)

**Performance Issues:**
- `SCT_MAX_ACTIVE = 30` cap prevents frame explosion. Good.
- SCT `OnUpdate` runs per-frame for every active floating text. With 30 active texts, this is 30 OnUpdate calls per frame. Acceptable for floating combat text.
- `CheckForPersonalOrders` uses pcall for API calls that might not exist. Defensive but correct.

**Missing Nil Checks:**
- `UNIT_COMBAT` handler checks `issecretvalue(amount)` and `issecretvalue(flagText)`. Good defensive coding for tainted combat values.
- `PARTY_INVITE_REQUEST` handler accesses `inviterGUID` which could be nil. `C_FriendList.IsFriend(inviterGUID)` with nil GUID would error. Should add a nil guard.

**Combat Lockdown:**
- No protected frame operations in this module. SCT frames are addon-created and safe to position anytime.
- `StaticPopup_Show` hook for quick destroy uses `pcall` and `IsForbidden()` checks. Well-guarded.

**Code Readability:**
- Multiple unrelated features in one file (personal orders, AH filter, UI scale, SCT, auto-invite, quick destroy). Each subsystem is clearly separated with comments.
- The `Misc.ToggleQuickDestroy` function uses nested pcall and IsForbidden checks which is correct but dense.

**Inconsistent Patterns:**
- `ApplyMiscEvents` uses a forward declaration pattern, which is used elsewhere. Consistent.
- The `/rl` slash command bypasses `UIThingsDB.misc.enabled` check -- it checks `allowRL` directly.

**Recommendations:**
- Add nil guard for `inviterGUID` in `PARTY_INVITE_REQUEST` handler.
- The BN whisper auto-invite early return is documented with a comment explaining the limitation. Good.

---

### Frames.lua (~250 lines)

**Performance Issues:**
- `UpdateFrames` iterates all frames and recreates borders/nudge buttons each time. For typical use (1-5 frames) this is negligible.
- `SaveAllFramePositions` on `PLAYER_LOGOUT` iterates all frames and calls `GetCenter()`. Lightweight.

**Missing Nil Checks:**
- `SaveAllFramePositions` guards against nil `parentX` from `UIParent:GetCenter()`. Good.
- `UpdateButtonLayout` guards against nil `right` and `screenRight`. Good.

**Code Readability:**
- Clean implementation. The nudge button adaptive layout (detecting screen edge proximity) is well-implemented.
- Border visibility with backward-compatible nil defaults is clean: `(data.showTop == nil) and true or data.showTop`.

**Recommendations:**
- None. Clean module.

---

### TalentReminder.lua (~1510 lines)

**Performance Issues:**
- `CompareTalents` iterates all talent nodes in the active config. This can be 30-50 nodes per check. Called on zone change and encounter start. Acceptable.
- `CreateSnapshot` retrieves all talent data via `C_Traits` API calls. Multiple API calls per node but only triggered by user action (saving a reminder).

**Missing Nil Checks:**
- Multiple C_Traits API calls are wrapped in existence checks. Good.
- Zone detection falls back from `GetSubZoneText()` to `GetMinimapZoneText()`. Both can return empty strings, which are handled.

**Combat Lockdown:**
- `ApplyTalents` correctly checks `InCombatLockdown()` before attempting talent changes. Good.
- Alert frame is an addon-created frame and safe to show/hide anytime.

**Memory Leak Risks:**
- `LunaUITweaks_TalentReminders` saved variable stores talent snapshots per instance/difficulty/zone. Could grow large over time, but `CleanupSavedVariables` handles legacy data. No unbounded growth from normal use.

**Code Readability:**
- Well-structured with clear separation of snapshot creation, comparison, and alerting.
- Large file -- the config-related code within could potentially be split.

**Recommendations:**
- Consider adding a "purge old reminders" utility for users who have accumulated many entries.

---

### ActionBars.lua (~1552 lines)

**Performance Issues:**
- `ApplyButtonSpacing` uses `GetCenter()` on buttons to detect layout orientation. This requires the buttons to be positioned on screen, which they should be after initial layout.
- `SkinButton` iterates button regions with `GetRegions()` and checks region names with `string.find`. This runs once per button per `ApplySkin` call. With 108 buttons (9 bars * 12), this is significant but only runs on settings change or login.
- `MigrateBarOffsets` uses `FrameToUIParentPosition` which requires `GetCenter()` and `GetEffectiveScale()`. Called once at most.

**Missing Nil Checks:**
- `FrameToUIParentPosition` checks `cx`, `cy` for nil. Good.
- `ApplyBarPosition` checks for nil `absPos` before proceeding. Good.
- `SkinButton` checks `button.HasAction` with a fallback to icon visibility. Defensive.

**Combat Lockdown:**
- **Three-layer combat-safe positioning is well-implemented:**
  1. `SetPointBase`/`ClearAllPointsBase` bypass edit mode layer
  2. `hooksecurefunc` on `SetPointBase` with `suppressHook` flag prevents recursion
  3. `SecureHandlerStateTemplate` with state driver for combat transitions
- `ApplySkin` defers entirely if `InCombatLockdown()`. Correct.
- `SetupSecureAnchor` checks `InCombatLockdown()`. Correct.
- `RegisterStateDriver`/`UnregisterStateDriver` calls are guarded. Correct.
- `SkinButton` guards `SetSize` with `InCombatLockdown()` check. Correct.
- Micro button handling uses `SafeSetParent` to prevent `OnHide` crash. Well-documented.
- `PatchMicroMenuLayout` wraps `Layout` and `GetEdgeButton` in pcall. Defensive.

**Memory Leak Risks:**
- `dragOverlays` are created lazily and never destroyed. Acceptable since there are at most 9 bars.
- `secureAnchors` are properly cleaned up in `RemoveSecureAnchors`.
- `hookedBars` tracks which bars have been hooked. Hooks are permanent (cannot unhook `hooksecurefunc`), which is the intended WoW API behavior.

**Code Readability:**
- Most complex file in the addon. Well-commented with clear documentation of the three-layer strategy.
- `REPOSITION_SNIPPET` restricted Lua is clearly separated.
- `SuppressMicroLayout` is now a no-op wrapper -- consider removing it and calling functions directly to reduce indirection.

**Unused Variables / Dead Code:**
- `SuppressMicroLayout` is a no-op that wraps a function call. It was presumably used for something previously. Could be removed.
- Local `mt` is shadowed in `PatchMicroMenuLayout` (declared twice with `local mt = getmetatable(container)`).

**Recommendations:**
- Remove the `SuppressMicroLayout` wrapper -- it adds indirection for no benefit.
- Fix the `local mt` shadowing in `PatchMicroMenuLayout`.
- Consider splitting the file into `ActionBarsSkin.lua` and `ActionBarsDrawer.lua` for maintainability.

---

### CastBar.lua (~430 lines)

**Performance Issues:**
- `OnUpdateCasting` and `OnUpdateChanneling` run every frame during a cast. They perform minimal work (GetTime, division, SetValue). Efficient.
- `string.format` in cast time display is called every frame. Minor but could use a throttle to update only every 0.05s.

**Missing Nil Checks:**
- `UnitCastingInfo("player")` can return nil. The `if not name then return end` guard is present. Good.
- `UnitChannelInfo("player")` has the same guard. Good.

**Combat Lockdown:**
- `HideBlizzardCastBar` uses `RegisterStateDriver` for combat-safe hiding. Correct.
- Deferred operations via `waitFrame` pattern for `PLAYER_REGEN_ENABLED`. Correct.
- `ForceBlizzBarOffScreen` checks `InCombatLockdown()`. Correct.

**Code Readability:**
- Clean state machine: isCasting/isChanneling flags with clear transitions.
- `FadeOut` replaces the OnUpdate handler cleanly.

**Unused Variables / Dead Code:**
- `fadeOutDuration` and `fadeOutElapsed` are module-scoped but only used within `FadeOut` and its OnUpdate. Could be locals within `FadeOut`, but having them at module scope is fine for the closure.

**Recommendations:**
- Consider throttling the cast time text update to every 0.05s instead of every frame.

---

### ChatSkin.lua (~900+ lines)

**Performance Issues:**
- `FormatURLs` does a fast check (`string.find(msg, "http") or string.find(msg, "www")`) before heavy processing. Good optimization.
- URL and keyword filters run on every chat message via `ChatFrame_AddMessageEventFilter`. The fast-path checks keep overhead minimal for non-matching messages.
- `HighlightKeywords` creates a local `placeholders` table on every call. This is within a message filter that runs on every chat message. Consider reusing a module-level table with `wipe()`.

**Missing Nil Checks:**
- `GetChatContent` uses `issecretvalue(msg)` check on message content. Good.
- `SetupChatSkin` checks for `settings.chatWidth` and `settings.chatHeight` being nil before defaulting. Good.

**Combat Lockdown:**
- No protected frames used. All operations are on addon-created frames or chat frames (which are not combat-protected for text operations).

**Memory Leak Risks:**
- `skinnedFrames` and `skinnedTabs` track skinned elements. On `Disable()`, both are wiped. Good cleanup.
- `hooksInstalled` prevents duplicate hook registration. Important since hooks are permanent.
- `SetItemRef` override stores the original function. Only installed once. Correct.

**Code Readability:**
- Well-organized despite the complexity. Clear separation of URL detection, keyword highlighting, tab skinning, and container management.
- The `suppressSetPoint` pattern is documented and consistent with ActionBars usage.

**Inconsistent Patterns:**
- `HighlightKeywords` creates a local `placeholders` table while `FormatURLs` reuses a module-level `placeholders` table. Both should use the same pattern (module-level with wipe).

**Recommendations:**
- Reuse a module-level table for `HighlightKeywords` placeholders.
- The `Disable` function is thorough in restoration. No issues.

---

### Kick.lua (~1600 lines)

**Performance Issues:**
- `OnUpdateHandler` runs at 0.1s throttle. Iterates all `partyFrames` and updates each. For a 5-man party, this is 5 iterations. For raids, potentially 40. With the update loop only running when cooldowns are active, this is acceptable.
- `FindUnitFrame` tries 4 different methods (Grid2, PartyFrame, CompactPartyFrame, CompactRaidFrame) sequentially. For users without Grid2, the first check is wasted. Minor overhead.
- `GetUnitKickSpells` for non-addon users iterates `CLASS_INTERRUPTS` and checks spec data. Lightweight.

**Missing Nil Checks:**
- `FindSenderGUID` returns nil if the sender is not found. Callers check for nil. Good.
- `OnPartySpellCast` and `OnPartyPetSpellCast` both check `issecretvalue(spellID)`. Good.
- `CreatePartyFrame` has a shadowed `local guid = UnitGUID(unit)` that shadows the function parameter `guid`. The function parameter `guid` is passed from the caller and should be used instead. This is a **bug** -- the local shadows the parameter, and if `UnitGUID(unit)` returns a different value, the fallback logic below uses the wrong GUID.

**Combat Lockdown:**
- No protected frame operations. All frames are addon-created.
- `RebuildPartyFrames` is called on `PLAYER_REGEN_ENABLED` which is correct for deferred operations.
- `issecretvalue()` checks on spellID during combat are correct and well-documented.

**Memory Leak Risks:**
- `knownSpells` and `interruptCooldowns` are cleaned up in `RebuildPartyFrames` by checking `validGUIDs`. Good.
- `framePool` grows as frames are created but entries are reused via `table.remove`. Good pooling.
- `interruptCounts` is wiped on `PLAYER_ENTERING_WORLD`. Good.

**Code Readability:**
- Well-structured with clear separation of concerns.
- The variant spell matching (same class + specID) is well-documented with comments explaining why it exists.
- `UNIT_SPELLCAST_INTERRUPTED` handler has an excellent comment block explaining why successful interrupt tracking was removed.

**Bug:**
- `CreatePartyFrame` line `local guid = UnitGUID(unit)` shadows the function parameter. This should be removed; use the `guid` parameter directly.

**Recommendations:**
- Fix the shadowed `guid` variable in `CreatePartyFrame`.
- Consider adding a debug command to dump the current state of `knownSpells` for troubleshooting.

---

### AddonComm.lua (~200 lines)

**Performance Issues:**
- `CleanupRecentMessages` iterates both `recentMessages` and `lastSendTime`. Called every 20 messages. Lightweight.
- Rate limiting at 1.0s per module:action prevents message spam. Good.

**Missing Nil Checks:**
- `OnAddonMessage` checks `prefix` against known values. `sender` could theoretically be nil but the WoW API guarantees it. Fine.
- `message:match` pattern matching assumes message is a string. If `message` is nil (shouldn't happen from WoW API), it would error. Low risk.

**Code Readability:**
- Clean message bus pattern. Well-documented API with LuaDoc comments.
- Legacy prefix routing is clear and maintainable.
- `ScheduleThrottled` and `CancelThrottle` provide a clean cancellable timer API.

**Recommendations:**
- None. Clean, focused module.

---

### Reagents.lua (~330 lines)

**Performance Issues:**
- `ScanBags` iterates all bag slots. Debounced at 0.5s via `C_Timer.NewTimer`. Good.
- `TooltipDataProcessor` hook fires on every tooltip. The `IsReagent` check (`classID == 7`) is fast.
- `GetTrackedCharacters` builds a list from the saved variable on every call. If called frequently (e.g., from a tooltip), consider caching.

**Missing Nil Checks:**
- `C_Item.GetItemInfoInstant(itemID)` can return nil for invalid items. The `if not classID then return false end` guard is present. Good.
- `GetItemInfo(itemID)` can return nil for uncached items. The tooltip processor handles this.

**Code Readability:**
- Clean module with clear separation of scanning, storage, and tooltip display.
- Separate storage for bag and bank items allows accurate live bag counts.

**Recommendations:**
- Consider caching `GetTrackedCharacters` result with invalidation on character delete.

---

### AddonVersions.lua (~220 lines)

**Performance Issues:**
- Version message parsing runs on `CHAT_MSG_ADDON`. Lightweight string operations.
- Keystone detection scans all bag slots once on request. Acceptable.

**Missing Nil Checks:**
- `GetKeystoneInfo` iterates bags and calls `C_Container.GetContainerItemInfo`. The `if info and info.itemID` guard is present. Good.
- Backwards-compatible message parsing handles variable-length payloads gracefully.

**Code Readability:**
- Clean and focused. Good use of callback system for UI updates.

**Recommendations:**
- None. Clean module.

---

### MinimapCustom.lua (~750+ lines)

**Performance Issues:**
- Clock ticker updates every 1 second. Lightweight.
- `CollectDrawerButtons` iterates all Minimap children to find addon buttons. Called once at setup and on minimap changes. Acceptable.
- `DRAWER_BLACKLIST` pattern matching against child names. Uses `string.find` with plain flag. Efficient.

**Missing Nil Checks:**
- `GetMinimapShape` checks for Minimap existence. Good.
- `HybridMinimap` support checks via `ADDON_LOADED` event. Good deferred loading.

**Code Readability:**
- Well-organized with clear separation of shape, border, zone text, clock, and button drawer.
- Border mask technique is well-documented.

**Recommendations:**
- None significant.

---

### MinimapButton.lua

**Performance Issues / Code Quality:**
- Minimal file. Draggable minimap button with angle-based positioning. No issues.

---

### Bindings.xml (~10 lines)

- Defines two keybindings. No issues.

---

### LunaUITweaks.toc

- Load order is correct: Core first, then config infrastructure, then modules, then widgets.
- Three SavedVariables declared. Correct.
- Interface versions `120000, 120001` cover current retail.

---

## Cross-Cutting Concerns

### 1. Duplicated Border Drawing Code (Medium Priority)

At least 5 files implement nearly identical border texture creation and positioning logic:
- `Frames.lua` -- manual border textures
- `ActionBars.lua` -- `EnsureBorderTextures` + `ApplyThreeSidedBorder`
- `CastBar.lua` -- `ApplyBorders`
- `ChatSkin.lua` -- `EnsureBorders` + `UpdateBorders`
- `MinimapCustom.lua` -- border mask technique (different approach)

**Recommendation:** Extract a shared `CreateBorderTextures(frame)` and `ApplyBorder(frame, size, color, sides)` utility into `Core.lua` or a new `Shared.lua` file. This would reduce ~100 lines of duplicated code and ensure consistent border behavior.

### 2. String Concatenation in Hot Paths (Medium Priority)

The ObjectiveTracker update cycle builds display strings via repeated concatenation:
```lua
title = GetWQRewardIcon(questID) .. GetQuestTypePrefix(questID) .. title
title = title .. GetTimeLeftString(questID)
title = title .. GetDistanceString(questID)
```

Each `..` creates an intermediate string. With Lua's immutable strings, this generates garbage for the GC. For 30 quests with 3 concatenations each, that's ~90 temporary strings per update.

**Recommendation:** Use `table.concat` or `string.format` to reduce intermediate allocations.

### 3. Sort Function Closures (Low Priority)

Multiple files create sort comparison functions as anonymous closures inside functions that run repeatedly:
- `ObjectiveTracker.lua` -- `sortByDistance`, `sortByTimeLeft` in `RenderWorldQuests`
- `Kick.lua` -- sort in `UpdatePartyFrame`

**Recommendation:** Pre-define sort functions as module-level upvalues.

### 4. Inconsistent Module Registration Pattern (Low Priority)

Most modules register on the addon table as:
```lua
local Module = {}
addonTable.Module = Module
```

But some use the direct assignment pattern:
```lua
addonTable.Module = {}
```

And Core.lua uses:
```lua
addonTable.Core = {}
```

Both patterns work but the local variable pattern is preferred for performance (upvalue access is faster than table lookups).

### 5. Event Frame Proliferation (Low Priority)

Several modules create multiple separate event frames at the module level:
- `Combat.lua` -- `timerFrame`, `logFrame`, `reminderEventFrame`, plus the init frame `f`
- `ObjectiveTracker.lua` -- `trackerFrame`, `autoTrackFrame`, `f`, `hookFrame`
- `Kick.lua` -- `frame`, `updateFrame`, plus 8 pre-created watcher frames

While this is fine functionally (and sometimes necessary for `RegisterUnitEvent`), some modules could consolidate their generic event handling into fewer frames.

### 6. Consistent Combat Lockdown Handling (Strength)

The codebase is consistently defensive about combat lockdown. Patterns used include:
- `InCombatLockdown()` checks before `SetAttribute`, `SetPoint`, `Show`/`Hide` on protected frames
- `RegisterStateDriver` / `UnregisterStateDriver` for combat-safe visibility
- Deferred operations via `PLAYER_REGEN_ENABLED` event
- `SecureHandlerStateTemplate` for restricted Lua execution during combat
- `issecretvalue()` checks for tainted values

This is a significant strength of the codebase.

### 7. Frame Pooling (Strength)

Frame pooling is consistently used across modules:
- `ObjectiveTracker.lua` -- `itemPool` with `AcquireItem`/`ReleaseItems`
- `Loot.lua` -- `itemPool` with `AcquireToast`/`RecycleToast`
- `Kick.lua` -- `framePool` for party member frames
- `Misc.lua` -- `sctPool` for scrolling combat text
- `Frames.lua` -- `framePool` for custom rectangles

This prevents frame creation churn and is a best practice for WoW addon development.

---

## Priority Recommendations

### High Priority

1. **Fix shadowed `guid` variable in Kick.lua `CreatePartyFrame`** -- This is a bug where a local variable shadows the function parameter, potentially using the wrong GUID for frame creation.

2. **Add nil guard for `inviterGUID` in Misc.lua PARTY_INVITE_REQUEST** -- Could cause an error if the GUID is nil.

3. **Hoist `colors` table in Core.lua `Log()`** -- Allocates a new table on every log call. Move to module scope.

4. **Pre-define sort functions in ObjectiveTracker.lua** -- Reduces garbage creation on every tracker update.

5. **Add periodic cleanup for `prevObjectiveState` / `prevQuestComplete`** -- These tables grow unbounded across a session. Clean up entries for quests no longer tracked on zone change.

6. **Fix `local mt` shadowing in ActionBars.lua `PatchMicroMenuLayout`** -- Shadowed variable could mask bugs.

### Medium Priority

7. **Extract shared border utility** -- Reduce ~100 lines of duplicated code across 4+ files.

8. **Reuse `placeholders` table in ChatSkin.lua `HighlightKeywords`** -- Use module-level table with `wipe()` instead of creating per-call.

9. **Remove `SuppressMicroLayout` no-op wrapper in ActionBars.lua** -- Dead indirection.

10. **Consolidate event frames in ObjectiveTracker.lua** -- Two frames (`f` and `hookFrame`) both register `PLAYER_LOGIN`/`PLAYER_ENTERING_WORLD`.

11. **Throttle cast time text in CastBar.lua** -- Currently updates every frame; 0.05s throttle would reduce string format calls by ~75% with no visual difference.

12. **Simplify `Loot.UpdateLayout`** -- Remove redundant `if i == 1` branches.

### Low Priority / Polish

13. **Consistent module registration pattern** -- Prefer `local Module = {}; addonTable.Module = Module` everywhere.

14. **Add `questLineCache` cleanup** -- Prune entries older than 5 minutes on zone change.

15. **Consider splitting large files** -- ActionBars.lua (1552 lines) and ObjectiveTracker.lua (2116 lines) could benefit from splitting into sub-modules.

16. **Consolidate two `GetItemInfo` calls in Combat.lua `TrackConsumableUsage`** -- Minor but cleaner.

17. **Cache `GetTrackedCharacters` result in Reagents.lua** -- Avoid rebuilding the list on every tooltip.

18. **Document the `value.r` convention for color detection in ApplyDefaults** -- Add inline comment explaining the convention for future maintainers.
