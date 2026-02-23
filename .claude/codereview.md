# LunaUITweaks -- Comprehensive Code Review

**Review Date:** 2026-02-22 (Twelfth Pass -- Coordinates, Misc, Warehousing Fixes)
**Previous Review:** 2026-02-22 (Eleventh Pass -- New Widgets)
**Scope:** Full review of all changes since Eleventh Pass. Confirmed fixes for stat widget tooltip duplication, WaypointDistance OnUpdate hook, Core.lua duplicate minimap key. New features: Spell/Item ID tooltips (Misc.lua), Coordinates distance display, Sort by Distance, #mapID support, /way chat fix. Warehousing mail dialog self-filter bug fixed.
**Focus:** Bugs/crash risks, performance issues, memory leaks, race conditions/timing issues, code correctness, saved variable corruption risks, combat lockdown safety

---

## Changes Since Last Review (Twelfth Pass -- 2026-02-22)

### Confirmed Fixed Since Eleventh Pass

| Issue | Fix |
|-------|-----|
| Stat widget tooltip duplication (Haste/Crit/Mastery/Vers) | `Widgets.ShowStatTooltip(frame)` extracted to `Widgets.lua`. All four `OnEnter` handlers now call this single function. 120 redundant lines eliminated. |
| `WaypointDistance` `HookScript("OnUpdate")` never unregistered | Replaced with `C_Timer.NewTicker(0.5, ...)` managed inside `ApplyEvents(enabled)`. Ticker properly created/cancelled on enable/disable. |
| `Core.lua` duplicate `minimap` key in DEFAULTS | Second minimap block now includes `angle = 45`. First duplicate removed. |
| Warehousing mail dialog not showing for cross-character destinations | Fixed in three places (`OnMailShow`, `RefreshPopup`, `BuildMailQueue`): `destPlain = dest:match("^(.+) %(you%)$") or dest` strips the stored `" (you)"` suffix before comparing against current character name. |
| `/way` command not working from chat box | `hash_SlashCmdList["/WAY"] = "LUNAWAYALIAS"` now correctly stores the key string, not the handler function. |

### New Features Added Since Eleventh Pass

**`Misc.lua` -- Spell/Item ID on tooltips** (`HookTooltipSpellID`): Three `TooltipDataProcessor.AddTooltipPostCall` hooks for `Enum.TooltipDataType.Spell`, `.Item`, and `.Action`. Action slot type resolved via `GetActionInfo(data.actionSlot)`. Gated by `UIThingsDB.misc.showSpellID`. Wired into `OnPlayerEnteringWorld` and `ApplyMiscEvents`.

**`Coordinates.lua` -- Distance display per row**: `GetDistanceToWP(wp)` and `FormatDistanceShort(yards)` added as module-local helpers (duplicate of WaypointDistance widget logic). `RefreshList` prefixes each row with distance. `C_Timer.NewTicker(2, ...)` refreshes distances while frame is visible.

**`Coordinates.lua` -- Sort by Distance**: `Coordinates.SortByDistance()` computes distance for each waypoint once, sorts, preserves `activeWaypointIndex` after reorder, calls `RefreshList`. Sort button added to title bar.

**`Coordinates.lua` -- `#mapID` format support**: `ParseWaypointString` now detects `^#(%d+)%s+` prefix, extracts explicit mapID, and strips it before coordinate parsing.

**`config/panels/CoordinatesPanel.lua` -- Width/Height sliders**: Width (100-600, step 10) and Height (60-600, step 10) sliders added. Commands section shifted down accordingly.

### New Findings (Twelfth Pass -- 2026-02-22)

| Severity | Issue | File | Notes |
|----------|-------|------|-------|
| Medium | Distance helpers duplicated between `Coordinates.lua` and `widgets/WaypointDistance.lua` | Both files | `MapPosToWorld`, `GetDistanceToWP`/`GetDistanceToWaypoint`, and `FormatDistanceShort`/`FormatDistance` are near-identical in both files. Should be shared via `addonTable.Coordinates` or a utility table. |
| Medium | `Coordinates.lua` `C_Timer.NewTicker(2, ...)` never cancelled | Coordinates.lua:664 | The 2-second distance ticker is created once in `CreateMainFrame` and never cancelled, even when the coordinates module is disabled or the frame is hidden. The `if mainFrame:IsShown()` guard prevents wasted work but the ticker runs forever. |
| Medium | `Misc.lua` `HookTooltipSpellID` is not forward-declared before `OnPlayerEnteringWorld` references it | Misc.lua:317 | `HookTooltipSpellID` is called at line 318 but the function is defined at line 434. This works because Lua closures capture by name, but it relies on `OnPlayerEnteringWorld` only being called after the file fully loads. If the function were called at file-scope before line 434 it would error. Pattern is inconsistent: `HookTooltipClassColors` is forward-declared at line 302, but `HookTooltipSpellID` is not. |
| Low | `Coordinates.lua` `RefreshList` calls `GetDistanceToWP` for every row on every 2s tick | Coordinates.lua:375 | `GetDistanceToWP` calls `C_Map.GetWorldPosFromMapPos` twice per waypoint. For large waypoint lists this is repeated work. Acceptable for typical use (< 50 waypoints). |
| Low | `Coordinates.lua` `SortByDistance` builds a temporary `withDist` table then wipes `db.waypoints` | Coordinates.lua:522-553 | Clean implementation. Minor allocation: `withDist` table with N entries is created, used, then GC'd. Acceptable for a one-shot user action. |
| Low | `Coordinates.lua` `ResolveZoneName` partial match uses `pairs` iteration (unordered) | Coordinates.lua:54-58 | Multiple zones with names containing the search string will return whichever the hash table happens to yield first. For most zone names this is fine, but ambiguous partial matches (e.g., "Storm" matching both Stormwind and Stormsong Valley) may resolve to the wrong zone. |

---

## Status of Previously Identified Issues (Carry-Forward)

### Confirmed Fixed Since Eleventh Pass

- **Stat widget tooltip duplication** -- `Widgets.ShowStatTooltip(frame)` extracted. All four stat widgets now call it. **FIXED.**
- **WaypointDistance `HookScript("OnUpdate")`** -- Replaced with managed `C_Timer.NewTicker`. **FIXED.**
- **Core.lua duplicate `minimap` key** -- Merged. `angle = 45` now present in full minimap block. **FIXED.**
- **Warehousing mail dialog self-filter bug** -- `destPlain` stripping applied in all three filter sites. **FIXED.**
- **`/way` command not working from chat** -- `hash_SlashCmdList` value corrected. **FIXED.**

### Confirmed Still Open

The following items from earlier passes were re-verified as still open:

- **GetCharacterKey() duplication** -- Reagents.lua line 25 and Warehousing.lua line 38 each define a local `GetCharacterKey()`. Core.lua does not expose a shared version.
- **WaitForItemUnlock polling unreliable** -- Still uses `isLocked` polling. Retry logic present (3 retries, 0.5s) but root cause unchanged.
- **CalculateOverflowDeficit stale state** -- Still calls `ScanBags()` synchronously.
- **bagList rebuilt per ScanBags() call** -- Still present.
- **sortedChars table in tooltip** -- Still present in Reagents.lua `AddReagentLinesToTooltip`.
- **Reagents.lua ScanCharacterBank legacy IDs** -- Still uses `-1` (BANK_CONTAINER) and old bag slot enumeration. Not migrated to `C_Bank`/`CharacterBankTab_1`.

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

LunaUITweaks is a well-structured addon with consistent patterns, good combat lockdown awareness, and effective use of frame pooling. The codebase demonstrates strong understanding of the WoW API and its restrictions. Key strengths include the three-layer combat-safe positioning in ActionBars, proper event-driven architecture, shared utility patterns (logging, SafeAfter, SpeakTTS), excellent widget framework design with anchor caching, smart tooltip positioning, the widget visibility conditions system, and the hook-based consumable tracking architecture.

The Warehousing module is a substantial addition that is architecturally sound. The CharacterRegistry in Core.lua is a good centralization step. The four new secondary stat widgets are clean and event-driven but have a significant code duplication problem in their tooltip logic.

### Issue Counts (Twelfth Pass)

**Critical Issues:** 0 (all previously critical items fixed)
**High Priority:** 0 (all previously high items fixed)
**Medium Priority:** ~35 total (3 new: Coordinates distance duplication, Coordinates ticker leak, Misc.lua forward-declaration inconsistency; 5 closed from Eleventh Pass)
**Low Priority / Polish:** ~35 total (2 new: Coordinates partial-match unordered, Misc forward-declaration; several closed)

---

## Per-File Analysis -- Core Modules

### Core.lua (~721 lines)

**Status:** Clean. No new issues.

- `ApplyDefaults` is recursive but only runs once at `ADDON_LOADED`. No hot-path concern.
- `SpeakTTS` utility provides centralized TTS with graceful fallbacks.
- Default tables for all modules properly initialized including new `warehousing` key.
- `CharacterRegistry` is a clean centralization. `Delete()` correctly propagates to both `LunaUITweaks_ReagentData` and `LunaUITweaks_WarehousingData`.
- **FIXED:** Duplicate `minimap` key in DEFAULTS. `angle = 45` now correctly present in the full minimap block.
- **Low:** `DEFAULTS` table is constructed inside the `OnEvent` handler which runs for every addon's `ADDON_LOADED`. Moving to file scope avoids wasted allocations on non-matching calls.
- **Low:** `CharacterRegistry.GetAll()` allocates a new table and iterates all characters on every call. Called from `Reagents.GetTrackedCharacters()` on each config panel open.
- **Low:** `ApplyDefaults` does not guard against `db` being nil at the top level. Safe in practice.

---

### EventBus.lua (~76 lines)

**Status:** All critical issues fixed. One medium performance concern remains.

- **FIXED:** Duplicate registration vulnerability -- `EventBus.Register` scans for existing callback before inserting.
- **Medium (carried forward):** Snapshot table allocated on every event dispatch. For high-frequency events like `BAG_UPDATE`, `UNIT_AURA`, or `COMBAT_RATING_UPDATE` (fired by stat widgets), this creates GC pressure. Consider reusing a scratch table.
- `RegisterUnit` wrapper is a clean abstraction.
- Unregister properly cleans up empty listener arrays.

---

### Warehousing.lua (~1,362 lines)

**Status:** Functional. Two medium issues remain. Three low issues.

- **FIXED: Mail dialog self-filter bug.** `destPlain = dest:match("^(.+) %(you%)$") or dest` now correctly strips the stored `" (you)"` suffix in `OnMailShow`, `RefreshPopup`, and `BuildMailQueue` before comparing against current character name. Destinations like "Lunaleap (you)" on other characters are now correctly treated as valid mail targets.
- **Medium: `WaitForItemUnlock` polling unreliable for warband bank.** Polls `isLocked` at 0.1s intervals. Warband bank transfers via `C_Container.UseContainerItem(..., bankType)` may not set `isLocked` client-side, or clear the lock before first poll. Retry logic (3 retries x 0.5s) mitigates but root cause is unreliable detection. A more robust approach: detect item disappearance from the source slot, or listen to `ITEM_LOCK_CHANGED`.
- **Medium: `CalculateOverflowDeficit` calls `ScanBags()` synchronously on every call.** During auto-continuation, the follow-up pass calls `CalculateOverflowDeficit()` after `SCAN_DELAY + 0.1s`. If bags have not fully settled, intermediate state causes incorrect overflow calculations. Explicit `BAG_UPDATE_DELAYED` event wait before re-check would be more reliable.
- **Medium: `GetCharacterKey()` duplicated** -- defined locally in Warehousing.lua (line 38) and also in Reagents.lua (line 25). Core.lua exposes `CharacterRegistry` but no `GetCharacterKey()` helper. The CharacterRegistry centralizes storage but not the key-generation function itself.
- **Low: `bagList` rebuilt as new table on every `ScanBags()` call.** Both `ScanBags()` (line 156) and `FindItemSlots()` (line 359) and `FindEmptyBagSlot()` (line 401) all build their own `bagList` tables inline. Three separate allocation sites for identical logic. Module-level constant table would reduce GC pressure.
- **Low: Auto-continuation capped at 5 passes but "Sync complete!" shown regardless.** If 5 passes were needed and overflow remains, user sees success message.
- **Low: `GetCharacterNames()` uses `LunaUITweaks_WarehousingData.characters` only.** Does not use `CharacterRegistry`, so alts known only through Reagents module do not appear in the mail destination dropdown.
- **Low: Mail queue sends items one per `C_Mail.SendMail` call without rate limiting.** Could hit server throttles for large overflow lists.

---

### AddonComm.lua (~225 lines)

**Status:** Clean. No new issues.

- Rate limiting, deduplication, and legacy prefix mapping are well-implemented.
- `CleanupRecentMessages()` is properly amortized at 20-message intervals.

---

### Vendor.lua (~343 lines)

**Status:** Clean.

- Timer properly canceled on re-entry.
- `InCombatLockdown()` check correctly gates durability check when `onlyCheckDurabilityOOC` is set.

---

### Loot.lua (~556 lines)

**Status:** Both critical issues fixed. One medium. One low.

- **FIXED:** OnUpdate script cleared on recycled toast frames.
- **FIXED:** Truncated item link regex pattern updated to capture complete item links.
- **Medium:** `string.find(msg, "^You receive")` is locale-dependent (line 499). On non-English clients, self-loot detection fails.
- **Low:** `UpdateLayout` has identical code in `if i == 1` and `else` branches. Redundant.

---

### Combat.lua (~1217 lines)

**Status:** Previous HIGH issue fixed. Two medium. Three low.

- **FIXED:** `C_Item.GetItemInfoInstant(spellName)` broken path replaced by hook-based consumable tracking.
- **Medium:** `TrackConsumableUsage` (line 580) has infinite retry risk if `GetItemInfo` never returns data for a given `itemID`. Should add a retry counter (max 5 attempts).
- **Medium:** `GetItemInfo(itemID)` called twice in `TrackConsumableUsage`. Should consolidate.
- **Low:** `ApplyReminderLock()` called three times redundantly (lines 1048, 1070, 1135).
- **Low:** Line 1113 comment says "Create 4 text lines" but the loop creates 5.
- Hook-based consumable tracking (`HookConsumableUsage`) is a solid architectural choice.

---

### Misc.lua (~528 lines)

**Status:** Mostly clean. One medium issue (new). One low.

- `mailAlertShown` flag prevents repeated alerts.
- SCT `SCT_MAX_ACTIVE = 30` cap prevents frame explosion.
- **New feature -- `HookTooltipSpellID`:** Three `TooltipDataProcessor.AddTooltipPostCall` hooks for Spell, Item, and Action tooltip types. Action resolution via `GetActionInfo(data.actionSlot)` is correct. `spellIDHooked` guard prevents duplicate hook registration. Clean implementation.
- **Medium (new): `HookTooltipSpellID` not forward-declared.** `OnPlayerEnteringWorld` (line 318) calls `HookTooltipSpellID()` which is defined at line 434. This works because the callback only fires after the file fully loads, but `HookTooltipClassColors` is forward-declared at line 302 while `HookTooltipSpellID` is not — an inconsistency. Adding a forward declaration at line 303 would make the pattern consistent and safer.
- **Low:** SCT `OnUpdate` runs per-frame for each active text. `ClearAllPoints()` + `SetPoint()` every frame is expensive. Consider animation groups.

---

### Frames.lua (~325 lines)

**Status:** One low-priority observation. Otherwise clean.

- **Low:** `SetBorder` local function defined inside loop body -- should be hoisted.
- `SaveAllFramePositions` on `PLAYER_LOGOUT` ensures no position data lost.

---

### QuestAuto.lua (~214 lines)

**Status:** Clean.

- One-shot initialization pattern using `Unregister` inside callback is elegant.
- `lastGossipOptionID` anti-loop protection is a good safety measure.

---

### QuestReminder.lua (~381 lines)

**Status:** Clean.

- Well-organized with clear section comments.
- Test popup function is useful for config panel testing.

---

### Reagents.lua (~529 lines)

**Status:** Clean. Exemplary EventBus usage. One low issue carried forward.

- `eventsEnabled` guard prevents duplicate EventBus registration. Exemplary pattern.
- `TooltipDataProcessor` hook (line 340) is the correct modern WoW API.
- `IsReagent` optimization: tries `GetItemInfoInstant` first, falls back to `GetItemInfo`.
- `ScanBags()` properly debounced at 0.5s.
- `GetTrackedCharacters` uses `CharacterRegistry.GetAll()` as authoritative source.
- **Low:** `ScanCharacterBank()` still uses legacy container IDs (`-1` for BANK_CONTAINER, bag slots 5-11, `-3` for REAGENTBANK_CONTAINER). TWW restructured the bank to use `CharacterBankTab_1` enum. These legacy IDs may return 0 slots on TWW clients, causing the bank scan to silently return empty.
- **Low:** `sortedChars` table in `AddReagentLinesToTooltip` (line 284) builds a new table per tooltip hover.

---

### AddonVersions.lua (~215 lines)

**Status:** Clean. No issues.

---

## Per-File Analysis -- UI Modules

### MplusTimer.lua (~974 lines)

**Status:** Critical forward-reference issue fixed. One low remaining.

- **FIXED:** Forward reference to `OnChallengeEvent` added at file top.
- **Low:** Death tooltip `OnEnter` creates a temporary `sorted` table per hover.

---

### TalentManager.lua (~1782 lines)

**Status:** All HIGH issues fixed. Two medium remain. Two low.

- **FIXED:** Undefined `instanceType` variable.
- **FIXED:** EJ cache tier mutation -- saves/restores current tier.
- **FIXED:** Stale `buildIndex` in button closures -- `row.buildData` used instead.
- **Medium:** `RefreshBuildList` creates multiple temporary tables per call. Use module-level scratch tables with `wipe()`.
- **Medium:** `SetRowAsBuild` creates 6 closures per build row on every `RefreshBuildList` call. 120+ closures for 20 builds. Consider shared click handlers reading from frame data.
- **Medium:** EJ cache saved to SavedVariables (`settings.ejCache`). Grows with each expansion.
- **Low:** Uses deprecated `UIDropDownMenuTemplate` API.
- **Low:** `DecodeImportString` does not type-check `importStream` internals.

---

### TalentReminder.lua (~1552 lines)

**Status:** All HIGH issues fixed. One medium remains. One low.

- **FIXED:** `CleanupSavedVariables()` now wraps old-format builds in arrays.
- **FIXED:** `ApplyTalents` stale rank bug fixed -- `currentTalents` re-captured after refund.
- **Medium:** No prerequisite chain validation in `ApplyTalents`. Talents sorted by `posY` approximates prerequisite order but lateral dependencies can fail silently.
- **Low:** `ReleaseAlertFrame()` clears `currentReminder` but not `currentMismatches`. Memory reference persists.

---

### ActionBars.lua (~1527 lines)

**Status:** One medium. Two low.

- **Medium:** Combat deferral frame leak (lines 1147-1154 and 1266-1273). `ApplySkin()` and `RemoveSkin()` create a new `CreateFrame("Frame")` when called during combat. WoW frames persist indefinitely. Fix: use a single module-level deferral frame with a flag.
- Three-layer combat-safe positioning is exemplary.
- Micro-menu drawer `SetAlpha(0)`/`EnableMouse(false)` pattern avoids Blizzard crash. `PatchMicroMenuLayout()` crash guard is well-designed.
- **Low:** File is 1527 lines. Consider splitting skin vs. drawer logic.
- **Low:** `SkinButton` calls `button.icon:GetMaskTextures()` on every skin apply, not on hot path.

---

### CastBar.lua (~578 lines)

**Status:** Two medium issues.

- **Medium:** Same combat deferral frame leak as ActionBars.lua (lines 284-291 and 316-323).
- **Medium:** `OnUpdateCasting`/`OnUpdateChanneling` call `string.format("%.1fs", ...)` every frame. Throttle to 0.05s would reduce calls by ~75%.
- **Low:** `ApplyBarColor` allocates a new color table on every cast start when using class color.

---

### ChatSkin.lua (~1325 lines)

**Status:** One medium issue.

- **Medium:** `SetItemRef` is replaced globally instead of using `hooksecurefunc`. Breaks addon hook chain.
- URL detection with `lunaurl:` custom hyperlink is well-implemented.

---

### Kick.lua (~1607 lines)

**Status:** Clean.

- `OnUpdateHandler` runs at 0.1s throttle.
- `issecretvalue(spellID)` checks present.
- **Low:** `activeCDs` table churn at 0.1s interval. Negligible for small interrupt lists.

---

### MinimapCustom.lua (~1127 lines)

**Status:** Five medium issues (3 from ninth pass). Two low.

- **Medium:** `AnchorQueueEyeToMinimap()` calls `QueueStatusButton:SetParent(Minimap)` without `InCombatLockdown()` guard. Called from deferred `C_Timer.After(0)` which can fire during combat.
- **Medium:** Triple redundant `C_Timer.After(0)` scheduling from OnShow/SetPoint/UpdatePosition hooks. Coalescing flag would eliminate redundant calls.
- **Medium:** Potential hook conflict with ActionBars.lua over QueueStatusButton positioning.
- **Medium:** `SetDrawerCollapsed` shows/hides minimap buttons without `InCombatLockdown()` check.
- **Medium:** `CollectMinimapButtons` iterates all Minimap children on every call. Not cached.
- **Low:** `GetMinimapShape = nil` for round shape; should return `"ROUND"`.
- **Low:** Dead code in zone drag handler.
- **Low:** Clock ticker (`C_Timer.NewTicker(1, UpdateClock)`) never cancelled when feature disabled.

---

### ObjectiveTracker.lua (~2129 lines)

**Status:** Two medium items remain. One low.

- **Medium:** Hot path string concatenation generates ~90 temporary strings per 30-quest update cycle.
- **Medium:** Two separate frames (`f` and `hookFrame`) register overlapping events.
- **Low:** `OnAchieveClick` does not type-check `self.achieID`.

---

### MinimapButton.lua (~101 lines)

**Status:** Clean.

---

## Per-File Analysis -- Config System

### config/ConfigMain.lua (~559 lines)

**Status:** Warehousing tab added correctly. One low-priority structural concern.

- Warehousing is correctly placed as module ID 22, Addon Versions at 23 (last). Rule maintained.
- `OnHide` now auto-locks Warehousing in addition to all previous modules.
- `SelectModule` fires `RefreshWarehousingList` when module 22 is selected -- missing. For consistency with modules 2, 17, and 19 which call refresh functions, module 22 should also call `addonTable.Config.RefreshWarehousingList()` in `SelectModule`. Currently warehousing only refreshes on panel setup and explicit Refresh button click.
- **Low:** ~180 lines of mechanical boilerplate creating 23 panel frames. Could be data-driven.

---

### config/Helpers.lua (~619 lines)

**Status:** Clean.

- `BuildFontList` comprehensive. `CreateColorSwatch` canonical.
- **Low:** Font list built once at load time. New fonts require `/reload`.

---

### config/panels/TrackerPanel.lua (~1159 lines)

**Status:** One medium-priority concern.

- **Medium:** 7 inline color swatches (~315 lines) duplicate `Helpers.CreateColorSwatch`.

---

### config/panels/TalentPanel.lua (~1142 lines)

**Status:** Clean.

- `sortedReminders` properly handles array format.
- **Low:** ~40 lines of unreachable nil-checks.

---

### config/panels/ActionBarsPanel.lua (~792 lines)

**Status:** One medium concern.

- **FIXED:** Nav visuals now use `UpdateNavVisuals()` checking `enabled or skinEnabled`.
- **Medium:** 5 inline color swatches (~225 lines) duplicate `Helpers.CreateColorSwatch`.

---

### config/panels/MinimapPanel.lua (~658 lines)

**Status:** Two medium concerns.

- **Medium:** 5 inline color swatches (~225 lines) duplicate `Helpers.CreateColorSwatch`.
- **Medium:** Border color swatch missing `opacityFunc` handler. Opacity slider won't update in real-time.

---

### config/panels/FramesPanel.lua (~641 lines)

**Status:** Two medium concerns.

- **Medium:** 2 inline color swatches (~90 lines) duplicate `Helpers.CreateColorSwatch`.
- **Medium:** `CopyTable` duplicates `Helpers.DeepCopy`; `NameExists` defined twice identically.

---

### config/panels/AddonVersionsPanel.lua (~614 lines)

**Status:** Two medium concerns.

- **Medium:** Export/import dialog frames created per click (not show/hide).
- **Medium:** `DeserializeString` uses `loadstring` with no input length check.

---

### config/panels/LootPanel.lua (~360 lines)

**Status:** One medium concern.

- **Medium:** `addonTable.Loot.UpdateSettings()` called without nil-checking `addonTable.Loot` first (8 occurrences).

---

### config/panels/VendorPanel.lua (~185 lines)

**Status:** One medium concern.

- **Medium:** `addonTable.Vendor.UpdateSettings` accessed without nil-check (6 occurrences).

---

### config/panels/WarehousingPanel.lua (~531 lines)

**Status:** One medium concern. One low resolved.

- **RESOLVED:** `StaticPopupDialogs["LUNA_RESET_WAREHOUSING_CONFIRM"]` guarded with `if not` check at file load. Correctly defined once.
- **Medium:** `RefreshItemList` calls `GetItemInfo(itemID)` (line 446) on every row render to get quality color. `GetItemInfo` may return nil for uncached items. The nil-check on `quality` is present but the call itself happens synchronously for every tracked item on every panel open. For users with many tracked items, this could cause frame hitches or silently use white text for uncached items.
- **Low:** `BuildDestinationDropdown` is called once per item per `RefreshItemList`. For N items and K destinations, this creates N×K `UIDropDownMenu_CreateInfo()` tables per refresh.
- **Low:** `OpenCharPicker` recalculates `keys` via `GetAllCharacterKeys()` on every open. For large character registries this is a minor allocation.
- **Low (new):** `SelectModule` in `ConfigMain.lua` does not call `addonTable.Config.RefreshWarehousingList()` when module 22 is selected, unlike the pattern used by quest reminders (id=2), reagents (id=17), and talent reminders (id=19). The warehousing list may be stale when switching to the tab.

---

### config/panels/WidgetsPanel.lua (~413 lines)

**Status:** Two medium observations from 2026-02-20, still open.

- **Medium (2026-02-20):** `CONDITIONS` table (7 entries) defined inside the `for i, widget in ipairs(widgets)` loop body. Creates 182 table objects every time the panel is opened. Should be hoisted to file scope.
- **Medium (2026-02-20):** `GetConditionLabel` defined inside the same loop. Creates 26 closure allocations per panel open. Should be hoisted to file scope.

---

### Other Config Panels

**CombatPanel.lua, KickPanel.lua, MiscPanel.lua, CastBarPanel.lua, ChatSkinPanel.lua, QuestReminderPanel.lua, QuestAutoPanel.lua, MplusTimerPanel.lua, TalentManagerPanel.lua, ReagentsPanel.lua** -- All clean. Follow established patterns. `MplusTimerPanel.lua`'s `SwatchRow` helper is the best DRY example with 15 swatches using `CreateColorSwatch`.

---

## Per-File Analysis -- Widget Files

### widgets/Widgets.lua (Framework, ~460 lines)

**Status:** Three medium concerns. One low.

- **Medium:** `UpdateAnchoredLayouts` creates fresh temporary tables every 1-second tick. Should cache sorted layout and rebuild only when widgets change.
- **Medium:** `UpdateVisuals` builds its own anchor lookup, duplicating the cached `RebuildAnchorCache()` system.
- **Medium:** Widget ticker calls `UpdateContent` on all enabled widgets every second. Many are purely event-driven. An `eventDriven` flag could skip these.
- **Low:** `OnUpdate` script on every widget frame fires every render frame. Body only executes when `self.isMoving` is true. ~2000+ no-op calls/second across 20+ widgets. Set `OnUpdate` only in `OnDragStart`, clear in `OnDragStop`.

---

### widgets/Haste.lua, Crit.lua, Mastery.lua, Vers.lua (~45 lines each)

**Status:** Clean. All issues from Eleventh Pass fixed.

- **FIXED:** `Widgets.ShowStatTooltip(frame)` extracted to `Widgets.lua`. All four `OnEnter` handlers now call this single function. Each file is now ~45 lines of clean, non-duplicated code.
- All four correctly implement `ApplyEvents(enabled)` with `COMBAT_RATING_UPDATE` and `PLAYER_ENTERING_WORLD`.
- **Low:** All four update via the framework's `UpdateContent` ticker (1s interval). Since `COMBAT_RATING_UPDATE` already fires on stat change, the 1s ticker is redundant for these widgets.
- **Low:** `Vers.lua` widget text shows only the offensive versatility value. The tooltip correctly shows both offensive and mitigation. The asymmetry may be slightly confusing.

---

### widgets/WaypointDistance.lua (~204 lines)

**Status:** Clean. All medium issues from Eleventh Pass fixed. One low remains.

- **FIXED:** `HookScript("OnUpdate")` replaced with `C_Timer.NewTicker(0.5, ...)` managed inside `ApplyEvents(enabled)`. Ticker is properly created on enable and cancelled on disable.
- `GetActiveWaypoint()` iterates all saved waypoints on each 0.5s tick. For typical use (< 50 waypoints) this is negligible.
- **Low:** `FormatDistance` has redundant branches (lines 104-109). Both `yards >= 100` and the `else` branch produce `"%.0fy"`. The `>= 100` branch is unreachable dead code since the outer `>= 1000` check already handles large values.
- `GetDirectionArrow` is a clean and efficient compass-bearing implementation.
- World-coordinate distance calculation (`MapPosToWorld`) is the correct approach for cross-zone waypoints.

---

### Coordinates.lua (~776 lines)

**Status:** Functional. Two medium issues (new). Two low issues (new).

- `ParseWaypointString` supports five formats including `#mapID` prefix. Zone cache is lazily built and handles partial matches. Clean implementation overall.
- Row pool (`AcquireRow`/`RecycleRow`) correctly recycles frames.
- `SortByDistance` correctly preserves the active waypoint index after reordering.
- `/way` command dispatch fixed: `hash_SlashCmdList["/WAY"] = "LUNAWAYALIAS"` now stores key string as required by WoW dispatch mechanism.
- **Medium (new): Distance helpers duplicated from `widgets/WaypointDistance.lua`.** `MapPosToWorld`, `GetDistanceToWP`, and `FormatDistanceShort` in Coordinates.lua are near-identical copies of the same logic in WaypointDistance.lua. If the distance calculation algorithm is updated in one place, the other will drift. Should be exposed as `addonTable.Coordinates.GetDistance(wp)` or moved to a shared utility.
- **Medium (new): `C_Timer.NewTicker(2, ...)` created in `CreateMainFrame` is never cancelled.** When the coordinates module is disabled or the frame is hidden, the ticker still fires every 2s and checks `mainFrame:IsShown()`. For a disabled module this is a minor waste. The ticker should be stored and cancelled in `UpdateSettings` when `enabled = false`.
- **Low (new): `RefreshList` is called from `UpdateSettings` which is itself called from the 2s ticker path.** `UpdateSettings` calls `Coordinates.RefreshList()` at the end, and `RefreshList` is also called by the ticker. On the ticker path: ticker → `RefreshList()`. On settings change: `UpdateSettings()` → `RefreshList()`. No double-call issue since the ticker only calls `RefreshList` directly, not `UpdateSettings`. Pattern is fine.
- **Low (new): `ResolveZoneName` partial match is unordered.** `pairs` iteration on a hash table has no defined order. For zone names that are substrings of multiple zone names (e.g., "Storm"), the match is non-deterministic. Could be improved with sorted key iteration.

---

### widgets/AddonComm.lua (~124 lines)

**Status:** One low issue. Otherwise clean.

- **Low (NEW): `GetGroupSize()` over-counts in party mode** (lines 9-15). `GetNumGroupMembers()` returns count including the player in party (5-player groups return 5). Adding `+1` in the `IsInGroup()` branch makes a 5-person party show as 6. In raid mode `GetNumGroupMembers()` also includes self, so no correction needed. The correct logic: `GetNumGroupMembers()` alone for both party and raid, as WoW returns inclusive counts in all group types as of TWW.
- `UpdateCachedText` correctly checks `addonTable.AddonVersions` for nil.
- `ApplyEvents` pattern with `GROUP_ROSTER_UPDATE` and `PLAYER_ENTERING_WORLD` is correct.
- Tooltip correctly uses `C_ClassColor.GetClassColor(classToken)` with `classToken` (English token), not localized class name. Fixes the Friends.lua issue pattern.

---

### widgets/Group.lua (~569 lines)

**Status:** Clean. Previous HIGH issue fixed.

- **FIXED:** `IsGuildMember()` replaced with `IsInGuild()` + `C_GuildInfo.MemberExistsByName()`.

---

### widgets/Teleports.lua (~580 lines)

**Status:** Two medium issues.

- **Medium:** FontString inserted into `mainButtons` array causes crash in `ClearMainPanel()`. Track separately.
- **Medium:** `ReleaseButton` `SetAttribute` during combat taint risk.

---

### widgets/Keystone.lua (~411 lines)

**Status:** Two medium issues.

- **Medium:** Position saved in wrong schema (line 137). Framework never restores it.
- **Medium:** Full bag scan every tick in `GetPlayerKeystone()`. Should cache on `BAG_UPDATE`.

---

### widgets/SessionStats.lua (~143 lines)

**Status:** Clean.

- Correct `PLAYER_DEAD` and `CHAT_MSG_LOOT` event usage.
- Right-click reset is a good UX touch.

---

### widgets/MythicRating.lua (~174 lines)

**Status:** One medium issue.

- **Medium:** `bestRunLevel` may be nil (lines 85, 94). Add nil guard before `string.format`.

---

### widgets/Friends.lua (~132 lines)

**Status:** One medium issue.

- **Medium:** `C_ClassColor.GetClassColor` given localized class name from `C_FriendList.GetFriendInfoByIndex`. Should use `classFilename` (English token).

---

### widgets/Durability.lua (~99 lines)

**Status:** One medium observation.

- Event registrations happen unconditionally outside `ApplyEvents`. Events fire even when the widget is disabled. Should move into `ApplyEvents`.

---

### widgets/Vault.lua and widgets/WeeklyReset.lua

**Status:** One medium issue each.

- **Medium:** `ShowUIPanel`/`HideUIPanel` on Blizzard panels without `InCombatLockdown()` guard.

---

### widgets/Spec.lua (~74 lines)

**Status:** Two medium issues.

- **Medium:** `SetSpecialization` callable during combat via delayed menu click.
- **Medium:** `UpdateContent` calls 4 API functions every 1-second tick. Should cache and update on spec change events.

---

### widgets/FPS.lua (~130 lines)

**Status:** One medium. One low.

- **Medium:** `UpdateAddOnMemoryUsage()` in tooltip `OnEnter`. Expensive call.
- **Low:** Redundant sort of already-sorted addon memory list.

---

### widgets/Speed.lua (~64 lines)

**Status:** One low note.

- **Low:** Dual update mechanism: `HookScript("OnUpdate", ...)` at 0.5s + framework ticker at 1s. Redundant.

---

### widgets/Guild.lua (~69 lines)

**Status:** One low note.

- **Low:** No cap on tooltip members for large guilds.

---

### widgets/DarkmoonFaire.lua (~133 lines)

**Status:** One low note.

- **Low:** `GetDMFInfo()` recalculated every 1-second tick. Result changes once per minute. Could cache for 60 seconds.

---

### widgets/Bags.lua (~139 lines)

**Status:** One low note.

- **Low:** Full currency list iterated on every tooltip hover.

---

### widgets/Currency.lua (~258 lines)

**Status:** Clean. Well-implemented with frame pool and click-to-expand panel.

- Uses proper `CURRENCY_DISPLAY_UPDATE` event.
- Frame pool (`rowPool`/`activeRows`) correctly implemented.
- `GetCurrencyData` creates a new table per call -- minor allocation.

---

### widgets/Hearthstone.lua (~195 lines)

**Status:** One low note.

- **Low:** `GetRandomHearthstoneID` called at file load time before `PLAYER_LOGIN`. Correctly rebuilt later.

---

### widgets/Lockouts.lua (~163 lines)

**Status:** Clean.

- **FIXED (ninth pass):** OnClick uses `ToggleFriendsFrame(3)` + `RaidInfoFrame:Show()`.

---

### widgets/XPRep.lua (~245 lines)

**Status:** One low issue.

- **Low:** `ToggleCharacter("ReputationFrame")` in OnClick without `InCombatLockdown()` guard.

---

### Clean Widget Files (No Issues)

**Combat.lua** (39 lines), **Mail.lua** (52 lines), **ItemLevel.lua** (96 lines), **Zone.lua** (95 lines), **PullCounter.lua** (155 lines), **Volume.lua** (72 lines), **PvP.lua** (121 lines), **BattleRes.lua** (87 lines), **Coordinates.lua** (55 lines), **Time.lua** (66 lines), **Haste.lua** (60 lines, except tooltip duplication), **Crit.lua** (60 lines, except tooltip duplication), **Mastery.lua** (60 lines, except tooltip duplication), **Vers.lua** (60 lines, except tooltip duplication), **AddonComm.lua** (124 lines, except GetGroupSize minor bug) -- All clean and follow established patterns.

---

## Cross-Cutting Concerns

### 1. Duplicate EventBus Registration (HIGH Priority -- FIXED)

**FIXED:** `EventBus.Register` deduplicates by scanning for existing callback references before inserting.

### 2. Talent Build Data Migration (HIGH Priority -- FIXED)

**FIXED:** `CleanupSavedVariables()` wraps old-format builds in arrays.

### 3. Combat.lua Consumable Tracking Architecture (HIGH Priority -- FIXED)

**FIXED:** Hook-based tracking via `UseAction`/`C_Container.UseContainerItem`/`UseItemByName`.

### 4. Loot.lua Toast Pool (Critical -- FIXED)

**FIXED:** `RecycleToast()` clears OnUpdate script. `AcquireToast()` restores unconditionally. Item link regex updated.

### 5. TalentManager Stale Build Index (Critical -- FIXED)

**FIXED:** `row.buildData` used; all handlers read from `self:GetParent().buildData` at click time.

### 6. TalentReminder ApplyTalents Stale Ranks (High -- FIXED)

**FIXED:** `currentTalents` re-captured after refund step.

### 7. Secondary Stat Widget Tooltip Duplication (Medium Priority -- NEW)

~120 lines of identical tooltip code across `Haste.lua`, `Crit.lua`, `Mastery.lua`, and `Vers.lua`. Should be extracted into a shared `ShowStatTooltip(anchorFrame)` function.

### 8. Combat Deferral Frame Accumulation (Medium Priority)

ActionBars.lua and CastBar.lua create disposable `CreateFrame("Frame")` instances when called during combat lockdown. Fix: use a reusable module-level frame.

### 9. Config Panel Color Swatch Duplication (Medium Priority)

~960 lines of duplicated color swatch code across 6 panels when `Helpers.CreateColorSwatch` already exists.

### 10. Config Panel Unguarded Module Access (Medium Priority)

LootPanel.lua (8 occurrences) and VendorPanel.lua (6 occurrences) access module methods without nil-checking.

### 11. Locale-Dependent String Matching (Medium Priority)

- Loot.lua `"^You receive"` pattern fails on non-English clients
- Friends.lua `C_ClassColor.GetClassColor` given localized class name

### 12. Missing Combat Lockdown Guards (Medium Priority)

- MinimapCustom.lua `AnchorQueueEyeToMinimap` -- `SetParent` on protected QueueStatusButton
- MinimapCustom.lua `SetDrawerCollapsed`
- Teleports.lua `ReleaseButton` on secure buttons
- Vault.lua / WeeklyReset.lua `ShowUIPanel`/`HideUIPanel`
- Spec.lua delayed menu click
- XPRep.lua `ToggleCharacter` in OnClick

### 13. Duplicated Border Drawing Code (Medium Priority)

At least 5 files implement nearly identical border texture creation.

### 14. Widget Ticker Efficiency (Medium Priority)

The widget framework's shared ticker calls `UpdateContent` on all enabled widgets every second. The four stat widgets (Haste, Crit, Mastery, Vers) are purely event-driven via `COMBAT_RATING_UPDATE` and do not benefit from the 1s timer.

### 15. TalentManager Closure Churn (Medium Priority)

`SetRowAsBuild` creates 6 closures per build row on every `RefreshBuildList` call.

### 16. GetCharacterKey() Triplicated (Medium Priority)

Defined as a local function independently in `Core.lua` (implicit via CharacterRegistry), `Reagents.lua` (line 25), and `Warehousing.lua` (line 38). All produce `"Name - Realm"` string. Should be centralized as `addonTable.Core.GetCharacterKey()`.

### 17. Core.lua Duplicate `minimap` Key in DEFAULTS (Low -- Potential Bug)

The `DEFAULTS` table in Core.lua defines the `minimap` key twice (once at ~line 245 with `angle = 45` and once at ~line 355 with the full minimap config). In Lua table construction, the second definition overwrites the first, so `angle = 45` is silently lost. The `minimap` section at line 355 does not include an `angle` default.

### 18. WaypointDistance OnUpdate Leak (Medium Priority -- NEW)

`HookScript("OnUpdate")` accumulates additional hooks on re-initialization and never unregisters on disable.

### 19. Combat Lockdown Handling (Strength)

Consistently defensive about combat lockdown. The three-layer ActionBars pattern is exemplary.

### 20. Frame Pooling (Strength)

Consistently used in Loot.lua, Frames.lua, Teleports.lua, Currency.lua, TalentManager.lua, WidgetsPanel.lua.

### 21. Centralized TTS (Strength)

`Core.SpeakTTS` centralizes text-to-speech with graceful API fallbacks.

### 22. Widget ApplyEvents Pattern (Strength)

Widgets consistently implement `ApplyEvents(enabled)`. Excellent pattern across all 31 widget files.

### 23. Widget Visibility Conditions (Strength)

The `EvaluateCondition()` system with 7 conditions and 8 EventBus trigger events is well-designed.

### 24. Saved Variable Separation (Strength)

`LunaUITweaks_TalentReminders`, `LunaUITweaks_ReagentData`, `LunaUITweaks_WarehousingData`, `LunaUITweaks_CharacterData` all survive settings resets.

### 25. CharacterRegistry (Strength -- NEW)

`Core.lua` CharacterRegistry provides a clean centralized store for known alts. Used by both Reagents and Warehousing. `Delete()` cascades correctly. `GetAll()` and `GetAllKeys()` provide sorted access.

---

## Priority Recommendations

### Critical (All Previously Fixed)

1. **FIXED:** MplusTimer.lua forward reference.
2. **FIXED:** Loot.lua OnUpdate not cleared on recycled toast frames.
3. **FIXED:** Loot.lua truncated item link regex.
4. **FIXED:** TalentManager.lua stale `buildIndex` in button closures.

### High Priority (All Previously Fixed)

5. **FIXED:** TalentReminder.lua `ApplyTalents` stale rank values.
6. **FIXED:** Combat.lua `C_Item.GetItemInfoInstant(spellName)` broken path.
7. **FIXED:** EventBus duplicate registration.
8. **FIXED:** Group.lua `IsGuildMember()` nonexistent API.
9. **FIXED:** TalentManager.lua `instanceType` undefined.
10. **FIXED:** TalentReminder.lua data migration.

### Fixed Since Eleventh Pass

11a. **FIXED:** Stat widget tooltip duplication -- `Widgets.ShowStatTooltip(frame)` extracted.
11b. **FIXED:** WaypointDistance `HookScript("OnUpdate")` -- replaced with `C_Timer.NewTicker`.
11c. **FIXED:** Core.lua duplicate `minimap` key -- merged, `angle = 45` restored.
11d. **FIXED:** Warehousing mail dialog self-filter -- `destPlain` stripping applied in 3 places.
11e. **FIXED:** `/way` command from chat box -- `hash_SlashCmdList` value corrected.

### Medium Priority (New -- Twelfth Pass)

12a. **Coordinates.lua distance helpers duplicated from WaypointDistance widget** -- `MapPosToWorld`, `GetDistanceToWP`, `FormatDistanceShort` are near-identical copies in both files. Should be shared to avoid drift.
12b. **Coordinates.lua `C_Timer.NewTicker(2, ...)` never cancelled** -- Store ticker, cancel it in `UpdateSettings` when `enabled = false`.
12c. **Misc.lua `HookTooltipSpellID` not forward-declared** -- Add `local HookTooltipSpellID` forward declaration alongside `HookTooltipClassColors` at line 302.

### Medium Priority (Carried Forward)

13. **Warehousing.lua `WaitForItemUnlock` unreliable** -- Consider `ITEM_LOCK_CHANGED` or slot disappearance detection.
14. **Warehousing.lua `CalculateOverflowDeficit` stale state** -- Add explicit bag-update wait before auto-continuation re-check.
15. **`GetCharacterKey()` duplicated** -- Centralize in Core.lua as `addonTable.Core.GetCharacterKey()`.
16. **Teleports.lua FontString in button array** -- Track "no spells" FontString separately.
17. **Teleports.lua `SetAttribute` during combat** -- Guard `ReleaseButton` secure operations with `InCombatLockdown()`.
18. **Keystone.lua position saved in wrong schema** -- Use framework position keys.
19. **MythicRating.lua nil `bestRunLevel`** -- Add nil guard before `string.format`.
20. **Combat deferral frame leak** -- ActionBars.lua + CastBar.lua: use reusable module-level frame.
21. **Combat.lua infinite retry in `TrackConsumableUsage`** -- Add retry counter (max 5 attempts).
22. **MinimapCustom.lua `AnchorQueueEyeToMinimap` combat guard** -- Add `InCombatLockdown()` check.
23. **MinimapCustom.lua triple redundant `C_Timer.After(0)` scheduling** -- Add coalescing flag.
24. **MinimapCustom.lua `SetDrawerCollapsed` combat guard** -- Add `InCombatLockdown()` check.
25. **ChatSkin.lua `SetItemRef` override** -- Use `hooksecurefunc` instead.
26. **Vault.lua / WeeklyReset.lua `ShowUIPanel` combat guard** -- Add `InCombatLockdown()` check.
27. **Spec.lua menu click combat guard** -- Check `InCombatLockdown()` in menu callbacks.
28. **Friends.lua localized class name** -- Use `classFilename` instead of `className`.
29. **Durability.lua unconditional event registration** -- Move into `ApplyEvents`.
30. **EventBus snapshot allocation per dispatch** -- Consider scratch table reuse.
31. **WidgetsPanel.lua `CONDITIONS` table inside loop** -- Hoist to file-scope constant.
32. **WidgetsPanel.lua `GetConditionLabel` closure inside loop** -- Hoist to file scope.
33. **Config panel color swatch duplication (~960 lines)** -- Migrate 22 inline swatches to `Helpers.CreateColorSwatch`.
34. **LootPanel.lua / VendorPanel.lua unguarded module access** -- Add nil checks.
35. **AddonVersionsPanel.lua frame leak** -- Create dialog frames once, show/hide.
36. **AddonVersionsPanel.lua `loadstring` length check** -- Add max input length guard.
37. **MinimapPanel.lua missing `opacityFunc`** -- Add opacity callback to border swatch.
38. **FramesPanel.lua duplicate functions** -- Use `Helpers.DeepCopy`, deduplicate `NameExists`.
39. **TalentManager.lua scratch tables** -- Reuse module-level tables with `wipe()`.
40. **TalentManager.lua `SetRowAsBuild` closure churn** -- Shared click handlers.
41. **TalentManager.lua EJ cache bloat** -- Cache grows with each expansion.
42. **TalentReminder.lua `ApplyTalents` prerequisite chain validation** -- Chain-aware error handling.
43. **Keystone.lua bag scan every tick** -- Cache and rescan on `BAG_UPDATE`.
44. **Spec.lua API calls every tick** -- Cache and update on spec change events.
45. **MinimapCustom.lua `CollectMinimapButtons` not cached** -- Cache collected buttons.
46. **FPS widget `UpdateAddOnMemoryUsage` on hover** -- Move to background timer.
47. **ObjectiveTracker string concatenation** -- Use `table.concat` in hot paths.
48. **CastBar.lua cast time format throttle** -- Throttle `string.format` to 0.05s.
49. **Reagents.lua `ScanCharacterBank` legacy IDs** -- Migrate to `CharacterBankTab_1` enumeration.
50. **Loot.lua locale-dependent self-loot detection** -- Use a locale-agnostic approach.
51. **Warehousing.lua `GetCharacterNames` not using `CharacterRegistry`** -- Use `GetAllCharacterKeys()` consistently.

### Low Priority / Polish

52. Core.lua `DEFAULTS` table in `OnEvent` handler (should be file-scope)
53. Core.lua `CharacterRegistry.GetAll()` allocates per call (consider caching)
54. Loot.lua redundant `if i == 1` branches
55. Combat.lua triplicate `ApplyReminderLock()` calls (lines 1048, 1070, 1135)
56. Combat.lua stale comment "Create 4 text lines" (line 1113, loop creates 5)
57. MplusTimer death tooltip temp table
58. Guild widget tooltip cap for large guilds
59. Speed widget dual-update mechanism
60. MinimapCustom.lua `GetMinimapShape` should return `"ROUND"`
61. MinimapCustom.lua dead code in zone drag handler
62. MinimapCustom.lua clock ticker never cancelled
63. Frames.lua `SetBorder` function hoisting
64. ObjectiveTracker `OnAchieveClick` type guard
65. TalentManager.lua deprecated `UIDropDownMenuTemplate` API
66. TalentManager.lua `DecodeImportString` type safety
67. TalentReminder.lua `ReleaseAlertFrame` does not clear `currentMismatches`
68. Reagents.lua `sortedChars` tooltip table allocation per hover
69. DarkmoonFaire.lua tick rate for DMF info
70. Bags.lua currency list caching per hover
71. Currency.lua `GetCurrencyData` table allocation per tick
72. Hearthstone.lua early attribute set before login
73. Widgets.lua `OnUpdate` on all frames (set only during drag)
74. Widgets.lua duplicate anchor lookup in `UpdateVisuals`
75. TalentPanel.lua unreachable nil-checks (~40 lines)
76. ConfigMain.lua boilerplate reduction (data-driven panel creation)
77. ~100 global frame names with generic "UIThings" prefix
78. CastBar.lua color table allocation per cast start
79. XPRep.lua `ToggleCharacter` without `InCombatLockdown()` guard
80. Vers.lua text shows only offensive versatility, not combined
81. WaypointDistance.lua `FormatDistance` redundant branches (100+ and else identical)
82. AddonComm widget `GetGroupSize()` overcounts party by 1
83. Warehousing.lua `bagList` rebuilt per `ScanBags()` call (3 separate sites)
84. Warehousing.lua auto-continuation shows "Sync complete!" even if 5 passes hit limit with overflow remaining
85. Coordinates.lua `ResolveZoneName` partial match unordered (ambiguous zone names non-deterministic)
86. Misc.lua `HookTooltipSpellID` not forward-declared (inconsistent with `HookTooltipClassColors`)

---

## Line Count Summary

| Category | Files | Lines (approx) |
|----------|-------|-------|
| Core Modules | 12 | 5,900 |
| UI Modules | 10 | 12,669 |
| Config System | 24 | 9,842 |
| Widget Files | 34 | 6,215 |
| Warehousing | 2 | 1,890 |
| **Total** | **82** | **~36,516** |
