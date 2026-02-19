# LunaUITweaks -- Comprehensive Code Review

**Review Date:** 2026-02-19 (Sixth Pass -- Full Codebase Audit)
**Previous Review:** 2026-02-18 (Fifth Pass -- EventBus Optimization & MplusTimer Migration)
**Scope:** All 62 source files: 22 root .lua modules, 22 config files, 28 widget files, TOC
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

LunaUITweaks is a well-structured addon with consistent patterns, good combat lockdown awareness, and effective use of frame pooling. The codebase demonstrates strong understanding of the WoW API and its restrictions. Key strengths include the three-layer combat-safe positioning in ActionBars, proper event-driven architecture, shared utility patterns (logging, SafeAfter, SpeakTTS), excellent widget framework design with anchor caching, smart tooltip positioning, and the new widget visibility conditions system.

### What Changed Since Last Review (2026-02-18 to 2026-02-19)

Two new additions were identified since the previous review:

1. **SessionStats widget** (`widgets/SessionStats.lua`) -- NEW untracked file. Tracks session duration, gold delta, items looted, and deaths. Persists across `/reload` via `UIThingsDB.widgets.sessionStats` with `GetTime()` epoch comparison to detect true login vs reload. Right-click resets counters. Uses EventBus for `PLAYER_DEAD` and `CHAT_MSG_LOOT`.

2. **Widget Visibility Conditions** -- `Widgets.lua` now contains `EvaluateCondition()` supporting 7 conditions: `always`, `combat`, `nocombat`, `group`, `solo`, `instance`, `world`. Each widget has a condition dropdown in WidgetsPanel. Conditions re-evaluate on 8 EventBus events (combat transitions, group changes, zone changes). BattleRes and PullCounter default to `instance`; all others default to `always`.

### Issue Counts

**Critical Issues:** ~~1~~ All fixed (MplusTimer forward reference)
**High Priority:** ~~3~~ All fixed (EventBus dedup, Group.lua IsGuildMember, TalentManager instanceType, TalentReminder migration)
**Medium Priority:** 29 (2 resolved: SessionStats defaults verified, ChatSkin HighlightKeywords downgraded)
**Low Priority / Polish:** 26+

---

## Changes Since Last Review

### Previous Findings Status

#### All Previously Fixed Items (Confirmed Still Fixed)

- **FIXED:** MplusTimer.lua nil guard for `info.quantityString`
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

#### Previously Identified Issues Still Open

- **FIXED:** `CleanupSavedVariables()` in TalentReminder.lua now migrates old-format builds by wrapping them in arrays instead of deleting them.
- All medium and low priority items from the fifth pass remain unless explicitly noted as resolved below.

### New Findings Summary

| Severity | Count | Key Issues |
|----------|-------|-----------|
| Critical | ~~1~~ 0 | ~~MplusTimer forward reference to undefined local~~ (FIXED) |
| High | ~~4~~ 0 | ~~EventBus dedup~~ (FIXED), ~~TalentManager instanceType~~ (FIXED), ~~Group.lua IsGuildMember~~ (FIXED), ~~TalentReminder migration~~ (FIXED) |
| Medium | ~~31~~ 29 | Combat deferral frame leaks, missing combat guards, config panel issues, widget bugs |
| Low | 26+ | Performance optimizations, dead code, code quality |

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

**Status:** One medium issue. One low. Previous duplicate registration fixed.

- **FIXED:** Duplicate EventBus registration pattern resolved by EventBus deduplication.
- **Medium:** `string.find(msg, "^You receive")` is locale-dependent (line 499). On non-English clients, self-loot detection fails.
- **Low:** `UpdateLayout` has identical code in `if i == 1` and `else` branches. Redundant.
- Frame pool (`itemPool`) correctly recycles frames. Good pattern.
- Roster cache for class color lookups is a nice optimization.

---

### Combat.lua (~1227 lines)

**Status:** Two medium issues. Two low.

- **Medium (NEW):** `TrackConsumableUsage` (line 580) has infinite retry risk. If `GetItemInfo` never returns data for a given `itemID`, the function calls itself via `C_Timer.After(0.5, ...)` indefinitely. Should add a retry counter.
- **Medium:** `GetItemInfo(itemID)` called twice in `TrackConsumableUsage` (lines 577 and 584). Should consolidate.
- **Low:** `ApplyReminderLock()` is called twice -- once on line 1048 and again on line 1070.
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

### TalentManager.lua (~1521 lines)

**Status:** HIGH priority issue fixed. Three medium remain.

- **FIXED: Undefined `instanceType` variable (lines 1141 and 1156).** Moved the `GetInstanceInfo()` call above the `instanceType == "raid"` check so the zone-specific checkbox now correctly defaults to checked in raids.

- **Medium:** `RefreshBuildList` creates multiple temporary tables per call (`raidBuilds`, `dungeonBuilds`, `uncategorizedBuilds`, sorted arrays). Significant garbage for users with 50+ builds. Use module-level scratch tables with `wipe()`.
- **Medium:** `EnsureEJCache()` calls `EJ_SelectTier(tierIdx)` which mutates global EJ state, potentially disrupting the user's Encounter Journal view.
- **Medium:** EJ cache saved to SavedVariables (`settings.ejCache`). Grows with each expansion, bloating `UIThingsDB`.
- **Low:** Uses deprecated `UIDropDownMenuTemplate` API. Works currently but may break in future patches.
- **Low:** `SetRowAsBuild` sets `OnClick` scripts every time, creating closures.

---

### TalentReminder.lua (~1531 lines)

**Status:** HIGH priority issue fixed. One medium remains.

- **FIXED:** `CleanupSavedVariables()` now migrates old-format builds by wrapping them in arrays (`zones[zoneKey] = { value }`) instead of deleting them.

- **Medium:** `table.remove` index shifting in `DeleteReminder` is fragile for future maintainers. Currently handled correctly (reverse-sorted deletions in TalentPanel.lua), but poorly documented.
- `ApplyTalents` correctly checks `InCombatLockdown()`.
- `ReleaseAlertFrame()` properly clears content references while preserving the frame. Good memory management.

---

### ActionBars.lua (~1516 lines)

**Status:** One medium (new). Two low.

- **Medium (NEW):** Combat deferral frame leak (lines 1147-1154 and 1266-1273). Both `ApplySkin()` and `RemoveSkin()` create a new `CreateFrame("Frame")` when called during combat. Frames persist indefinitely (WoW has no `DestroyFrame`). If called repeatedly during combat, frames accumulate.
  **Fix:** Use a single module-level deferral frame with a flag.

- Three-layer combat-safe positioning remains exemplary.
- All `RegisterStateDriver`/`UnregisterStateDriver` calls properly guarded.
- **Low:** File is 1516 lines. Consider splitting skin vs. drawer logic.
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

### MinimapCustom.lua (~1058 lines)

**Status:** Two medium issues. Two low. Unchanged from previous review.

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

**Status:** One medium observation.

- **Medium:** Widget anchor dropdown won't show new frames added while config is open.
- **Medium:** 1 inline color swatch when `Helpers.CreateColorSwatch` is available.

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

### Clean Widget Files (No Issues)

**Combat.lua** (39 lines), **Mail.lua** (52 lines), **ItemLevel.lua** (96 lines), **Zone.lua** (95 lines), **PullCounter.lua** (155 lines), **Volume.lua** (72 lines), **PvP.lua** (121 lines), **BattleRes.lua** (87 lines), **Coordinates.lua** (55 lines), **Time.lua** (66 lines), **WeeklyReset.lua** (noted above for combat guard) -- All clean and follow established patterns.

---

## Cross-Cutting Concerns

### 1. Duplicate EventBus Registration (HIGH Priority -- FIXED)

**FIXED:** `EventBus.Register` now scans the existing subscriber array for the same function reference before inserting (deduplication at the infrastructure level). This prevents duplicate listeners from accumulating when `ApplyEvents()`/`UpdateSettings()` is called multiple times. All affected modules (Vendor, Loot, Misc, QuestAuto, QuestReminder, Durability, and any future modules) are protected without per-module changes.

### 2. Talent Build Data Migration (HIGH Priority -- FIXED)

**FIXED:** `CleanupSavedVariables()` now wraps old-format builds in arrays (`zones[zoneKey] = { value }`) instead of deleting them.

### 3. Combat Deferral Frame Accumulation (Medium Priority -- NEW)

ActionBars.lua and CastBar.lua create disposable `CreateFrame("Frame")` instances when called during combat lockdown. WoW frames are never garbage collected. **Fix:** Use a reusable module-level frame.

### 4. Config Panel Color Swatch Duplication (Medium Priority -- NEW)

~960 lines of duplicated color swatch code across 6 panels (TrackerPanel, ActionBarsPanel, MinimapPanel, NotificationsPanel, FramesPanel, WidgetsPanel) when `Helpers.CreateColorSwatch` already exists. 8 panels already use the helper correctly.

### 5. Config Panel Unguarded Module Access (Medium Priority -- NEW)

LootPanel.lua (8 occurrences) and VendorPanel.lua (6 occurrences) access module methods without nil-checking the module first. Will crash if the module fails to load.

### 6. Locale-Dependent String Matching (Medium Priority)

- Loot.lua `"^You receive"` pattern fails on non-English clients
- Friends.lua `C_ClassColor.GetClassColor` given localized class name

### 7. Missing Combat Lockdown Guards (Medium Priority)

- MinimapCustom.lua `SetDrawerCollapsed`
- Teleports.lua `ReleaseButton` on secure buttons
- Vault.lua / WeeklyReset.lua `ShowUIPanel`/`HideUIPanel`
- Spec.lua delayed menu click

### 8. Duplicated Border Drawing Code (Medium Priority)

At least 5 files implement nearly identical border texture creation.

### 9. Widget Ticker Efficiency (Medium Priority)

The widget framework's shared ticker calls `UpdateContent` on all enabled widgets every second. Many are purely event-driven.

### 10. Combat Lockdown Handling (Strength)

The codebase is consistently defensive about combat lockdown. The three-layer ActionBars pattern is exemplary. The exceptions noted above are localized and low-risk.

### 11. Frame Pooling (Strength)

Consistently used in Loot.lua, Frames.lua, Teleports.lua, Currency.lua, TalentManager.lua, and WidgetsPanel.

### 12. Centralized TTS (Strength)

`Core.SpeakTTS` centralizes text-to-speech with graceful API fallbacks.

### 13. Widget ApplyEvents Pattern (Strength)

Widgets consistently implement `ApplyEvents(enabled)`. Excellent pattern across all 27 widget files.

### 14. Widget Visibility Conditions (Strength -- NEW)

The new `EvaluateCondition()` system with 7 conditions and 8 EventBus trigger events is well-designed and reduces widget clutter effectively.

### 15. Saved Variable Separation (Strength)

`LunaUITweaks_TalentReminders`, `LunaUITweaks_ReagentData`, `LunaUITweaks_QuestReminders` survive settings resets.

---

## Priority Recommendations

### Critical (Fix Immediately)

1. **FIXED: MplusTimer.lua forward reference (line 701)** -- Added `local OnChallengeEvent` forward declaration at file top and changed definition to assignment. M+ event processing now works correctly.

### High Priority

2. **FIXED: EventBus duplicate registration** -- `EventBus.Register` now deduplicates by scanning for existing callback references before inserting.

3. **FIXED: Group.lua `IsGuildMember()` (line 391)** -- Replaced with `IsInGuild()` + `C_GuildInfo.MemberExistsByName()` which is the documented API.

4. **FIXED: TalentManager.lua `instanceType` undefined (line 1141)** -- Moved `GetInstanceInfo()` call before the `instanceType` reference.

5. **FIXED: TalentReminder.lua data migration** -- `CleanupSavedVariables()` now wraps old-format builds in arrays instead of deleting them.

### Medium Priority

6. **Teleports.lua FontString in button array (lines 549-554)** -- Track "no spells" FontString separately to avoid crash in `ClearMainPanel`.
7. **Teleports.lua SetAttribute during combat** -- Guard `ReleaseButton` secure operations with `InCombatLockdown()`.
8. **Keystone.lua position saved in wrong schema (line 137)** -- Use framework position keys.
9. **FIXED: SessionStats.lua defaults verification** -- Core.lua DEFAULTS and TOC entry confirmed present.
10. **MythicRating.lua nil `bestRunLevel`** -- Add nil guard before `string.format`.
11. **Combat deferral frame leak** -- ActionBars.lua + CastBar.lua: use reusable module-level frame.
12. **Combat.lua infinite retry in TrackConsumableUsage** -- Add retry counter.
13. **MinimapCustom.lua SetDrawerCollapsed combat guard** -- Add `InCombatLockdown()` check.
14. **ChatSkin.lua SetItemRef override** -- Use `hooksecurefunc` instead.
15. **Downgraded: ChatSkin.lua HighlightKeywords table allocation** -- Per-invocation table is correct design to avoid stale state. Moved to low priority.
16. **Vault.lua / WeeklyReset.lua ShowUIPanel combat guard** -- Add `InCombatLockdown()` check.
17. **Spec.lua menu click combat guard** -- Check `InCombatLockdown()` in menu callbacks.
18. **Friends.lua localized class name** -- Use `classFilename` (English token) instead of `className`.
19. **Durability.lua unconditional event registration** -- Move into `ApplyEvents`.
20. **EventBus snapshot allocation per dispatch** -- Consider scratch table reuse.
21. **Config panel color swatch duplication (~960 lines)** -- Migrate 22 inline swatches to `Helpers.CreateColorSwatch`.
22. **LootPanel.lua / VendorPanel.lua unguarded module access** -- Add nil checks.
23. **AddonVersionsPanel.lua frame leak** -- Create dialog frames once, show/hide.
24. **AddonVersionsPanel.lua loadstring length check** -- Add max input length guard.
25. **MinimapPanel.lua missing opacityFunc** -- Add opacity callback to border swatch.
26. **FramesPanel.lua duplicate functions** -- Use `Helpers.DeepCopy`, extract `NameExists`.
27. **TalentManager.lua scratch tables** -- Reuse module-level tables with `wipe()`.
28. **TalentManager.lua EJ cache timing** -- Save/restore current tier selection.
29. **Keystone.lua bag scan every tick** -- Cache and rescan on `BAG_UPDATE`.
30. **Spec.lua API calls every tick** -- Cache and update on spec change events.
31. **Extract shared border utility** -- Reduce duplicated border code across 5+ files.
32. **Extract color picker helper** -- Already exists as `Helpers.CreateColorSwatch`, just needs adoption.
33. **MinimapCustom.lua cache collected buttons** -- Don't iterate all children every call.
34. **FPS widget memory scan** -- Move to background timer.
35. **ObjectiveTracker string concatenation** -- Use `table.concat` in hot paths.
36. **CastBar.lua cast time throttle** -- 0.05s throttle on `string.format`.

### Low Priority / Polish

37. Core.lua DEFAULTS table placement (inside handler vs file scope)
38. Loot.lua redundant `if i == 1` branches
39. Combat.lua duplicate `ApplyReminderLock()` call
40. MplusTimer death tooltip temp table
41. Guild widget tooltip cap for large guilds
42. Speed widget dual-update mechanism
43. MinimapCustom.lua `GetMinimapShape` should return `"ROUND"`
44. MinimapCustom.lua dead code in zone drag handler
45. MinimapCustom.lua clock ticker never cancelled
46. Frames.lua `SetBorder` function hoisting
47. ObjectiveTracker `OnAchieveClick` type guard
48. TalentManager.lua deprecated UIDropDownMenu API
49. TalentManager.lua row button closure creation
50. Reagents.lua `GetTrackedCharacters` caching
51. DarkmoonFaire.lua tick rate for DMF info
52. Bags.lua currency list caching
53. Currency.lua table allocation per tick
54. Hearthstone.lua early attribute set
55. Widgets.lua OnUpdate on all frames (set only during drag)
56. Widgets.lua duplicate anchor lookup
57. TalentPanel.lua unreachable nil-checks (~40 lines)
58. ChatSkinPanel.lua dead SetPoint
59. ReagentsPanel.lua StaticPopupDialogs recreation
60. ConfigMain.lua boilerplate reduction
61. ~100 global frame names with generic "UIThings" prefix

---

## Line Count Summary

| Category | Files | Lines |
|----------|-------|-------|
| Core Modules | 12 | 5,309 |
| UI Modules | 10 | 12,340 |
| Config System | 22 | 9,299 |
| Widget Files | 28 | 4,715 |
| **Total** | **72** | **31,663** |
