# LunaUITweaks -- Comprehensive Code Review

**Review Date:** 2026-02-17 (Second Pass -- Full Re-read)
**Scope:** All 60+ source files: 20 root .lua modules, 20 config panels, 27 widget files, config framework, TOC, and stub files
**Focus:** Bugs/crash risks, performance issues, memory leaks, race conditions/timing issues, code correctness, saved variable corruption risks, combat lockdown safety

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Per-File Analysis -- Core Modules](#per-file-analysis----core-modules)
3. [Per-File Analysis -- Config System](#per-file-analysis----config-system)
4. [Per-File Analysis -- Widget Files](#per-file-analysis----widget-files)
5. [Cross-Cutting Concerns](#cross-cutting-concerns)
6. [Priority Recommendations](#priority-recommendations)

---

## Executive Summary

LunaUITweaks is a well-structured addon with consistent patterns, good combat lockdown awareness, and effective use of frame pooling. The codebase demonstrates a strong understanding of the WoW API and its restrictions. Key strengths include the three-layer combat-safe positioning in ActionBars, proper event-driven architecture, shared utility patterns (logging, SafeAfter, SpeakTTS), and excellent widget framework design with anchor caching and smart tooltip positioning.

Since the last review, **two previously high-priority issues have been fixed** (MplusTimer nil guard and Misc.lua inviterGUID guard). Two new modules (**TalentManager** and **QuestReminder**) have been added and are well-integrated. The MplusTimer `ApplyLayout` concern has been downgraded after closer inspection. The widget system (26 files) is consistently patterned with event-driven caching, `ApplyEvents` for clean enable/disable, and proper frame pooling. The config panel system has grown to 20 modules with a sidebar navigation that is well-organized.

**Critical Issues:** 0
**High Priority:** 1
**Medium Priority:** 18
**Low Priority / Polish:** 16

### Previous Findings Status

#### Fixed Since Last Review (2026-02-17 earlier pass)

- **FIXED:** High #1 -- nil guard for `info.quantityString` in MplusTimer.lua `UpdateObjectives`. Line 570 now reads: `local currentCount = info.quantityString and tonumber(info.quantityString:match("%d+")) or 0`.
- **FIXED:** High #2 -- nil guard for `inviterGUID` in Misc.lua `PARTY_INVITE_REQUEST`. Line 546 now reads: `if inviterGUID and C_FriendList.IsFriend(inviterGUID) then`.
- **PARTIALLY FIXED:** Medium #5 -- ChatSkin.lua `FormatURLs` now reuses a module-level `placeholders` table (line 63). However, `HighlightKeywords` (line 139) still creates a local `placeholders` table per call. The `FormatURLs` fix is confirmed; `HighlightKeywords` remains open.

#### Fixed in Earlier Reviews (2026-02-16)

- **FIXED:** LOG_COLORS table in Core.lua hoisted to module scope.
- **FIXED:** Shadowed `guid` variable in Kick.lua removed.
- **FIXED:** Sort functions in ObjectiveTracker.lua pre-defined as upvalues.
- **FIXED:** Periodic cleanup for ObjectiveTracker caches on zone change.
- **FIXED:** `local mt` shadowing in ActionBars.lua resolved.
- **FIXED:** Keystone widget `BuildTeleportMap` combat guards added.

#### Still Open

- **STILL OPEN:** High #3 -- `readyCheckActive`/`readyCheckResponses` scoping bug in widgets/Group.lua.
- **DOWNGRADED:** Previous High #3 (MplusTimer ApplyLayout in RenderObjectives) -- On closer inspection, `RenderObjectives` does NOT call `ApplyLayout`. The `ApplyLayout` calls occur after `RenderBossObjectives` (line 519), after `LoadMapData` (line 558), at dungeon start (line 689), in demo mode (line 832), and in `UpdateSettings` (line 842). These are all event-driven, not per-tick. Downgraded to Low -- no longer a performance concern, though consolidating layout calls to a single post-update hook would simplify the code.
- **STILL OPEN:** Extract shared border utility (Medium).
- **STILL OPEN:** `HighlightKeywords` per-call placeholders table in ChatSkin.lua (Medium).
- **STILL OPEN:** `table.concat` in ObjectiveTracker string building (Medium).

---

## Per-File Analysis -- Core Modules

### Core.lua (~529 lines)

**Status:** Clean. No new issues.

- `ApplyDefaults` is recursive but only runs once at `ADDON_LOADED`. No hot-path concern.
- `SpeakTTS` utility provides centralized TTS with graceful fallbacks. Good.
- Default tables for `questAuto`, `questReminder`, `mplusTimer`, `talentManager`, and all widget subtables are properly initialized.

**Minor:** `ApplyDefaults` does not guard against `db` being nil at the top level. In practice this is safe because callers always pass `UIThingsDB`, but a defensive `if not db then return end` would be prudent.

---

### ObjectiveTracker.lua (~2131 lines)

**Status:** Previous fixes confirmed. Two medium-priority items remain.

- Sort comparison functions are now pre-defined as module-level upvalues. Good.
- Zone change cleanup runs properly. Good.
- **Medium:** Hot path string concatenation in `GetQuestTypePrefix`, `GetWQRewardIcon`, `GetDistanceString`, `GetTimeLeftString`, and `GetQuestLineString` generates ~90 temporary strings per 30-quest update cycle.
- **Medium:** Two separate frames register overlapping events (`f` and `hookFrame` both use `PLAYER_LOGIN`/`PLAYER_ENTERING_WORLD`).
- **Low:** `OnAchieveClick` does not type-check `self.achieID`.

---

### Vendor.lua (~347 lines)

**Status:** Clean. No issues.

---

### Loot.lua (~579 lines)

**Status:** One low-priority cleanup.

- **Low:** `UpdateLayout` has identical code in `if i == 1` and `else` branches. The first-iteration special case is redundant.

---

### Combat.lua (~1226 lines)

**Status:** One low-priority cleanup.

- `ScanConsumableBuffs` exits early when targets found. Good.
- `ScanBagConsumables` is properly debounced. Good.
- **Low:** `TrackConsumableUsage` calls `GetItemInfo(itemID)` twice. Could consolidate.

---

### Misc.lua (~700 lines)

**Status:** Clean. Previous issue fixed.

- **FIXED:** `PARTY_INVITE_REQUEST` handler now properly guards `inviterGUID` with `if inviterGUID and C_FriendList.IsFriend(inviterGUID)` at line 546.
- SCT `SCT_MAX_ACTIVE = 30` cap prevents frame explosion. Good.
- TTS calls use centralized `Core.SpeakTTS`. Good.

---

### Frames.lua (~250 lines)

**Status:** Clean. No issues.

---

### TalentReminder.lua (~1526 lines)

**Status:** Clean. No new issues.

- `CompareTalents` is acceptable performance for zone-change frequency.
- C_Traits API calls have proper existence checks.
- `ApplyTalents` correctly checks `InCombatLockdown()`.
- `GetCurrentLocation()` returns comprehensive location info for snapshot UI. Good.
- `ReleaseAlertFrame()` properly clears content references while preserving the frame for reuse. Good memory management.

---

### TalentManager.lua (~1509 lines) -- NEW

**Status:** Two medium-priority concerns, one low-priority note.

This is a new module that provides a side panel anchored to `PlayerSpellsFrame` for managing talent builds. It integrates with TalentReminder for talent comparison and build loading.

**Strengths:**
- Hooks `PlayerSpellsFrame` show/hide to auto-display the panel. Clean lifecycle management.
- EJ (Encounter Journal) cache is stored in saved variables with `addonVersion`/`gameBuild` versioning, so it only rebuilds when the game updates. Smart cache invalidation.
- Build list uses row recycling via `GetOrCreateRow(index)`. Good frame pooling.
- Collapsible tree view (Category > Instance > Difficulty > Builds) with persistent collapse state. Good UX.
- Import/export dialog with proper URL prefix stripping for wowhead import strings. Good.
- StaticPopupDialogs for delete and update confirmation. Correct pattern.
- `CopyBuild` uses a `DeepCopy` helper for talent data. Correct approach.
- `RefreshBuildList` filters by current class/spec and shows talent match status. Good integration.

**Issues:**

- **Medium:** `RefreshBuildList` creates temporary tables on every call: `raidBuilds`, `dungeonBuilds`, `uncategorizedBuilds`, and sorted name/diff arrays inside `RenderCategory`. For a user with many builds (50+), this creates significant garbage per refresh. Consider reusing module-level scratch tables with `wipe()`.
- **Medium:** `EnsureEJCache()` calls `EJ_SelectTier(tierIdx)` which changes the global Encounter Journal tier selection state. While the code saves and restores the original tier, if the EJ UI is open simultaneously, the tier switch could cause a visual flicker. Consider deferring the cache build to `PLAYER_ENTERING_WORLD` when the EJ is unlikely to be open.
- **Low:** `SetRowAsBuild` sets `OnClick` scripts on the edit/copy/update/delete/load buttons every time the row is reused. These closures capture `instanceID`, `diffID`, `zoneKey`, and `reminder` per refresh. While functionally correct, pre-allocating a single handler that reads from a stored data field on the row would reduce closure creation.

---

### QuestReminder.lua (~new) -- NEW

**Status:** Clean. Well-designed.

This module tracks repeatable (daily/weekly) quests and alerts the player on login if any are incomplete.

**Strengths:**
- Uses `LunaUITweaks_QuestReminders` saved variable (separate from UIThingsDB). Correct for data that should survive settings resets.
- Auto-tracks accepted repeatable quests via `QUEST_ACCEPTED` event. Smart.
- Popup alert with scroll frame, TTS, chat message, and sound notification. Comprehensive.
- `IsQuestRepeatable()` checks both `C_QuestLog.IsRepeatableQuest` and quest frequency. Good.
- Config panel integration with quest management (add/remove/edit). Good.

---

### QuestAuto.lua (~190 lines)

**Status:** Clean. Well-designed.

- `HandleQuestComplete` only auto-completes when `GetNumQuestChoices() <= 1`. Correct safety check.
- `HandleGossipShow` skips auto-gossip when quests are present. Smart.
- `lastGossipOptionID` prevents gossip interaction loops. Good defensive coding.
- Event registration via `ApplyEvents()` is properly segmented by feature flag. Good.

---

### MplusTimer.lua (~874 lines)

**Status:** Previous high-priority nil guard fixed. One medium-priority optimization downgraded to low.

- State management via `state` table with `ResetState()` is clean.
- `OnTimerTick` runs at 0.1s throttle. Good.
- `InitFrames()` guard prevents double-init. Good.
- `EnsureInit()` handles late enable. Good.
- Auto-slot keystone feature operates on an independent event frame. Clean separation.
- Demo mode for config preview properly creates and cleans up state. Good.

- **FIXED:** `UpdateObjectives` line 570 now reads: `local currentCount = info.quantityString and tonumber(info.quantityString:match("%d+")) or 0`. The nil guard is properly in place.
- **Low (downgraded from High):** `ApplyLayout()` calls are event-driven (dungeon start, data load, settings change), not per-tick. No performance concern. Consolidating to a single post-update hook would be a minor cleanup.

---

### ActionBars.lua (~1552 lines)

**Status:** Previous fixes confirmed. Two low-priority cleanups.

- Three-layer combat-safe positioning remains well-implemented.
- All `RegisterStateDriver`/`UnregisterStateDriver` calls are properly guarded.
- Bar position migration from old `barOffsets` format to new absolute `barPositions` is handled gracefully.
- Edit mode integration (release buttons on enter, reclaim on exit) is thorough.
- Conflict addon detection (Dominos/Bartender4/ElvUI) prevents conflicts. Good.
- **Low:** File is 1552 lines; consider splitting skin vs. drawer logic.
- **Low:** `SkinButton` calls `button.icon:GetMaskTextures()` and iterates results every time it skins a button. This is only called on skin apply (not per-frame), but could be cached.

---

### CastBar.lua (~430 lines)

**Status:** One medium-priority optimization.

- `HideBlizzardCastBar` uses `RegisterStateDriver`. Correct.
- Empower spell support with `UNIT_SPELLCAST_EMPOWER_*` events. Good coverage.
- **Medium:** `OnUpdateCasting`/`OnUpdateChanneling` call `string.format` every frame for cast time text. Throttle to 0.05s would reduce calls by ~75%.

---

### ChatSkin.lua (~1330 lines)

**Status:** One medium-priority optimization remains (partially fixed).

- `FormatURLs` now reuses a module-level `placeholders` table (line 63). **FIXED**.
- `hooksInstalled` prevents duplicate hooks. Good.
- URL detection with `lunaurl:` custom hyperlink type is well-implemented.
- Copy box with `GetMessageInfo` + fallback to visible `FontString` regions. Good defense-in-depth.
- Container frame with resize grip, drag overlay, and right-click tab unlock. Good UX.
- `issecretvalue()` check on `GetMessageInfo` results. Correct.
- **Medium:** `HighlightKeywords` (line 139) still creates a local `placeholders` table on every call. The module-level `placeholders` at line 63 is used by `FormatURLs` but not shared with `HighlightKeywords`. Should reuse a separate module-level table for keyword highlighting with `wipe()`.
- **Medium (NEW):** `SetItemRef` is replaced globally at line 1037 (`local origSetItemRef = SetItemRef; SetItemRef = function(...)`) instead of using `hooksecurefunc`. This means if another addon also replaces `SetItemRef` after ChatSkin loads, the ChatSkin replacement is lost. Conversely, if another addon replaced it before ChatSkin, that addon's replacement is kept as `origSetItemRef` but the call chain is fragile. Use `hooksecurefunc("SetItemRef", ...)` instead, or at minimum document the limitation.
- **Medium (NEW):** `Disable()` does not restore the original `SetItemRef`. Once `SetupChatSkin()` runs, the `SetItemRef` override is permanent for the session regardless of the enabled state. The `origSetItemRef` local is captured inside the `if not hooksInstalled then` block and is not accessible from `Disable()`. This means the URL hyperlink handler remains active even when the chat skin is disabled.

---

### Kick.lua (~1599 lines)

**Status:** Clean. Previous fixes confirmed.

- `OnUpdateHandler` runs at 0.1s throttle. Good.
- `issecretvalue(spellID)` checks are present. Good.
- Cleanup functions properly wipe state tables. Good.
- Two display modes (standalone container vs party frame attachment) are cleanly separated.
- `RegisterUnitEvent` for per-unit spell cast watching reduces event traffic. Good.

---

### AddonComm.lua (~200 lines)

**Status:** Clean. No issues.

- Rate limiting (MIN_SEND_INTERVAL = 1.0s) and dedup (DEDUP_WINDOW = 1.0s). Good.
- Legacy prefix support (LunaVer, LunaKick) for backwards compatibility. Good.
- Periodic cleanup of expired entries. Good.

---

### Reagents.lua (~330 lines)

**Status:** One low-priority optimization.

- `ScanBags` is debounced at 0.5s. Good.
- Live bag count for current character, cached bank data. Good.
- `TooltipDataProcessor` for tooltip integration. Correct modern API.
- **Low:** `GetTrackedCharacters` rebuilds list from saved variable on every call. Consider caching with invalidation.

---

### AddonVersions.lua (~220 lines)

**Status:** Clean. No issues.

- Uses centralized AddonComm for VER:HELLO and VER:REQ messages. Good.
- Backwards-compatible message parsing. Good.

---

### MinimapButton.lua (~96 lines)

**Status:** Clean. No issues.

- Angle-based positioning around minimap edge works correctly.
- Tooltip and click handler are straightforward.

---

### MinimapCustom.lua (~1067 lines)

**Status:** Two medium-priority issues.

- Complex minimap customization with shape, border, zone text, clock, icon repositioning, and drawer.
- HybridMinimap support for Blizzard's alternative minimap rendering.
- Drawer button collection with blacklist filtering, collapse/expand, and lock/unlock. Well-implemented.
- Three-sided borders on drawer and toggle button for seamless visual join. Good attention to detail.
- Clock update uses `C_Timer.NewTicker(1, UpdateClock)`. Good for real-time display.

- **Medium:** `CollectMinimapButtons` iterates all children of `Minimap` on every call (including a delayed re-collect 3 seconds after setup). For minimaps with many addon buttons (20+), iterating all children and checking names against the `DRAWER_BLACKLIST` exclusion table is moderately expensive. Consider using a `collectedSet` lookup (already used for dedup) to skip already-processed children.
- **Medium:** `SetDrawerCollapsed` calls `btn:Show()`/`btn:Hide()` on collected minimap buttons. If any addon creates secure minimap buttons, this could taint during combat. The module does not check `InCombatLockdown()` before showing/hiding collected buttons in the collapse toggle handler. Add a combat lockdown guard.
- **Low (NEW):** `ApplyMinimapShape` overwrites the global `GetMinimapShape` function (line ~110: `function GetMinimapShape() return "SQUARE" end` or `GetMinimapShape = nil`). This is intentional to communicate the minimap shape to other addons, but setting it to `nil` for round shape means any addon calling `GetMinimapShape()` after that point will get an error instead of the default "ROUND". Consider setting it to `function() return "ROUND" end` instead of nil.
- **Low (NEW):** In the zone text `OnDragStop` handler (line ~358), there is a redundant `select(2, ...)` call: `local mapCX, mapTop = Minimap:GetCenter(), select(2, Minimap:GetTop(), Minimap:GetTop())`. The `select(2, Minimap:GetTop(), Minimap:GetTop())` just returns `Minimap:GetTop()` again. The next line `mapTop = Minimap:GetTop()` overwrites it anyway, making the first assignment dead code. Clean up to just `local mapTop = Minimap:GetTop()`.

---

## Per-File Analysis -- Config System

### config/ConfigMain.lua (~310 lines)

**Status:** Clean. Well-structured.

- Sidebar navigation for 20 modules. Addon Versions correctly placed last (id=20).
- Panel creation and setup function wiring is consistent.
- Blizzard Settings integration via `Settings.RegisterAddOnCategory`. Good.
- `OnHide` auto-locks frames, loot anchor, SCT anchors, and widgets. Good cleanup.
- Closes M+ Timer demo on config window close. Good.
- `UISpecialFrames` registration for ESC-to-close. Good.

---

### config/Helpers.lua (~380 lines)

**Status:** One low-priority observation.

- `BuildFontList` discovers fonts from both hardcoded paths and dynamic `GetFonts()` API. Comprehensive.
- `CreateFontDropdown` caches font objects in `fontObjectCache` for preview rendering. Good.
- `CreateColorSwatch` with opacity support and proper cancel/restore. Good.
- `CreateTextureDropdown` with visual preview bar. Nice touch.
- `BuildTextureList` dynamically discovers textures from existing `StatusBar` frames. Smart approach.
- **Low:** Font list is built once at load time and never invalidated. If a user installs new fonts via a SharedMedia addon, they will not appear until `/reload`. This is acceptable behavior but could be documented.

---

### config/panels/TrackerPanel.lua (~1159 lines)

**Status:** One medium-priority concern.

- Very large panel file with comprehensive settings for the objective tracker.
- Color picker inline code is duplicated many times.
- **Medium:** The color picker pattern is repeated ~15 times in this file with near-identical code. Could be extracted to a `ConfigHelpers.OpenColorPicker()` utility, reducing ~200 lines.

---

### config/panels/TalentPanel.lua (~1154 lines)

**Status:** Clean. Well-structured for a complex feature.

- Static popup dialogs for delete confirmation are properly defined.
- Reminder list with zone-based grouping and difficulty filtering.
- `UpdateButtonStates` event listener correctly fires on `PLAYER_ENTERING_WORLD`.

---

### config/panels/TalentManagerPanel.lua -- NEW

**Status:** Clean. Follows established patterns.

- Settings for panel width, font, colors, background, border.
- Proper `UpdateSettings` callback wiring. Good.

---

### config/panels/QuestReminderPanel.lua -- NEW

**Status:** Clean. Follows established patterns.

- Quest list management with add/remove/edit.
- Proper integration with `QuestReminder` module's `UpdateSettings`. Good.

---

### config/panels/QuestAutoPanel.lua -- NEW

**Status:** Clean. Follows established patterns.

- Feature flags for auto-accept, auto-complete, auto-gossip with clear descriptions.
- Proper `ApplyEvents` callback. Good.

---

### config/panels/MplusTimerPanel.lua -- NEW

**Status:** Clean. Follows established patterns.

- Demo mode toggle for live preview. Good UX.
- Auto-slot keystone checkbox with tooltip explanation. Good.

---

### config/panels/ActionBarsPanel.lua (~570 lines)

**Status:** One low-priority observation.

- Conflicting addon detection auto-disables skin and shows warning. Smart.
- `CreateSliderEditBox` helper is well-implemented for synchronized slider+editbox.
- Per-bar position controls with drag-to-position integration. Good.
- **Low:** Per-bar X/Y position sliders create many frames, but only once. No leak concern.

---

### config/panels/FramesPanel.lua (~450 lines)

**Status:** Clean. Good use of dynamic panel rebuilding on frame selection change.

---

### config/panels/MinimapPanel.lua (~500 lines)

**Status:** Clean. Comprehensive minimap settings.

---

### config/panels/WidgetsPanel.lua (~350 lines)

**Status:** One medium-priority observation.

- 25+ individual widget checkboxes with anchor dropdown and order swap buttons.
- **Medium:** `RefreshWidgetCheckboxes()` rebuilds all widget rows from scratch on every call. Old frames are not explicitly hidden or recycled. Over many config window open/close cycles, this could accumulate orphaned frames. Consider pooling or reusing widget row frames.

---

### Other Config Panels

**VendorPanel.lua, CombatPanel.lua, LootPanel.lua, MiscPanel.lua, KickPanel.lua, ChatSkinPanel.lua, NotificationsPanel.lua, CastBarPanel.lua, ReagentsPanel.lua, AddonVersionsPanel.lua** -- All clean. Follow established patterns consistently. No issues found.

---

## Per-File Analysis -- Widget Files

### widgets/Widgets.lua (Framework, ~300 lines)

**Status:** Well-designed framework. One medium-priority note.

- `CreateWidgetFrame` provides consistent frame creation with drag, position save, and coord display.
- `SmartAnchorTooltip` adjusts tooltip anchor based on widget position relative to screen center. Smart.
- Anchor cache (`RebuildAnchorCache`/`InvalidateAnchorCache`) avoids repeated table scans. Good.
- `UpdateAnchoredLayouts` handles horizontal/vertical docking with even spacing. Good.
- `EstimateTimedScore`/`EstimateRatingGain` M+ rating helpers are useful shared utilities.
- Ticker lifecycle management via `StartWidgetTicker`/`StopWidgetTicker` tied to enabled state. Good.

- **Medium:** The widget ticker calls `UpdateContent` on every enabled widget at the configured interval (default 1s). For 25 enabled widgets, this is 25 function calls per second. Many widgets (Mail, Zone, Guild, Friends, Combat, ItemLevel) are purely event-driven. Their `UpdateContent` functions just set text to a cached value. An `eventDriven` flag could skip these from the ticker.

---

### widgets/FPS.lua

**Status:** One medium-priority concern.

- Jitter calculation from latency history with circular buffer. Well-implemented.
- Memory data throttled to `MEM_UPDATE_INTERVAL` (15s). Good.
- Addon memory pool (`addonMemPool`) recycles table entries. Good.

- **Medium:** `UpdateAddOnMemoryUsage()` is an expensive API call. The 15s throttle mitigates this, but the tooltip `OnEnter` handler triggers `RefreshMemoryData` if the interval has elapsed, meaning hovering could cause a frame rate hitch. Consider moving the scan to a background timer.

---

### widgets/Bags.lua

**Status:** One low-priority observation.

- Gold tracking across characters with sort and warband bank integration. Good.
- `ApplyEvents` for clean enable/disable. Good.
- **Low:** Verify Core.lua defaults include `goldData = {}` subtable for the bags widget.

---

### widgets/Group.lua

**Status:** One high-priority bug.

- Raid sorting logic (odds/evens, split half, healers to last) is comprehensive and well-implemented.
- Ready check tracking with color-coded status. Good design.
- `TANK_ICON`, `HEALER_ICON`, `DPS_ICON` are cached atlas markup strings. Good optimization.
- Cached group composition via `RefreshGroupCache()` updated on events, not every tick. Good.
- `ApplyEvents(enabled)` properly registers/unregisters all 6 events. Good.

- **FIXED (was HIGH Bug):** `readyCheckActive` and `readyCheckResponses` declarations moved before the `OnEnter` closure so both the tooltip overlay and `UpdateContent` properly capture them.
- **FIXED (was Low):** `OnEnter` tooltip handler now uses cached `TANK_ICON`/`HEALER_ICON`/`DPS_ICON` constants instead of calling `CreateAtlasMarkup` per member per hover.

---

### widgets/Teleports.lua

**Status:** Clean. Well-implemented.

- Spellbook scan cache with invalidation on `SPELLS_CHANGED` and `PLAYER_TALENT_UPDATE`. Good.
- Button pools for both regular and secure buttons with proper `AcquireButton`/`ReleaseButton`. Good.
- `InCombatLockdown()` guards on all secure button operations. Good.
- Current season detection via `C_ChallengeMode.GetMapTable()` and tooltip destination matching. Smart.
- `tinsert(UISpecialFrames, ...)` for ESC-to-close. Good.
- Dedup sets prevent hardcoded spells from appearing twice in scan results. Good.

---

### widgets/Keystone.lua

**Status:** Previous fixes confirmed. Clean.

- `BuildTeleportMap` checks `InCombatLockdown()`. Good.
- `pcall`/`issecretvalue()` for tooltip text access. Good.
- Teleport cache invalidated on `SPELLS_CHANGED` and `PLAYER_REGEN_ENABLED`. Good.
- Dungeon name variant matching handles mega dungeon wings and prefixes. Good.
- `SecureActionButtonTemplate` for click-to-teleport with proper drag passthrough. Good.

---

### widgets/WeeklyReset.lua

**Status:** Clean. No issues.

---

### widgets/Coordinates.lua

**Status:** Clean. No issues.

---

### widgets/BattleRes.lua

**Status:** Clean. No issues.

---

### widgets/Speed.lua

**Status:** One low-priority note.

- `C_PlayerInfo.GetGlidingInfo()` for skyriding speed. Good.
- OnUpdate throttled at 0.5s. Good for real-time speed.
- **Low:** The OnUpdate handler and the widget ticker's `UpdateContent` call are redundant. The OnUpdate is more responsive (correct for speed data); the ticker call is wasted. Consider making `UpdateContent` a no-op.

---

### widgets/ItemLevel.lua

**Status:** Clean. No issues.

---

### widgets/Volume.lua

**Status:** Clean. No issues.

---

### widgets/Zone.lua

**Status:** Clean. No issues.

---

### widgets/PvP.lua

**Status:** Clean. No issues.

---

### widgets/MythicRating.lua

**Status:** Clean. No issues.

---

### widgets/Vault.lua

**Status:** Clean. No issues.

---

### widgets/DarkmoonFaire.lua

**Status:** One low-priority edge case.

- **Low:** DMF date calculation uses `time()`/`date("*t")` (system time). Inherent limitation; not fixable.

---

### widgets/Mail.lua

**Status:** Clean. No issues.

---

### widgets/PullCounter.lua

**Status:** Clean. No issues.

---

### widgets/Hearthstone.lua

**Status:** Clean. Well-implemented.

---

### widgets/Time.lua

**Status:** Clean. No issues.

---

### widgets/Spec.lua

**Status:** Clean. No issues.

---

### widgets/Durability.lua

**Status:** Clean. No issues.

---

### widgets/Combat.lua (widget)

**Status:** Clean. Event-driven with no ticker overhead. Good.

---

### widgets/Friends.lua

**Status:** Clean. No issues.

---

### widgets/Guild.lua

**Status:** One low-priority note.

- **Low:** `GetGuildRosterInfo` iterates all guild members in the tooltip handler. For large guilds (500+), consider capping display to the first 50 online members.

---

### widgets/Currency.lua

**Status:** FIXED. Fully integrated.

- **FIXED:** Previously orphaned (not in TOC). Now integrated: added to TOC, Core.lua defaults (`currency` widget), and WidgetsPanel.lua. Currency IDs updated from TWW Season 1 (Harbinger Crests) to Season 3 (Ethereal Crests: 3285, 3287, 3289, 3290 + Valorstones 3008, Kej 3056). Frame pooling, scroll panel, and click-to-expand detail view are all functional.

---

### Config.lua (stub)

**Status:** Clean. Correctly documents the refactoring from monolithic to modular config.

---

## Cross-Cutting Concerns

### 1. Duplicated Border Drawing Code (Medium Priority)

At least 5 files implement nearly identical border texture creation and positioning logic:
- `Frames.lua` -- manual border textures
- `ActionBars.lua` -- `EnsureBorderTextures` + `ApplyThreeSidedBorder`
- `CastBar.lua` -- `ApplyBorders`
- `ChatSkin.lua` -- `EnsureBorders` + `UpdateBorders`
- `MinimapCustom.lua` -- border mask technique + drawer three-sided borders

**Recommendation:** Extract a shared `CreateBorderTextures(frame)` and `ApplyBorder(frame, size, color, sides)` utility into `Core.lua` or a new `Shared.lua`. This would reduce ~100 lines of duplicated code.

### 2. String Concatenation in Hot Paths (Medium Priority)

The ObjectiveTracker update cycle builds display strings via repeated concatenation. Each `..` creates an intermediate string. For 30 quests with 3 concatenations each, that is ~90 temporary strings per update.

**Recommendation:** Use `table.concat` or `string.format` to reduce intermediate allocations.

### 3. Color Picker Boilerplate in Config Panels (Medium Priority)

The `ColorPickerFrame:SetupColorPickerAndShow(info)` pattern with `swatchFunc`, `opacityFunc`, `cancelFunc` is repeated 15+ times in TrackerPanel.lua alone, and many more times across all 20 panels. Each instance is ~20 lines of nearly identical code.

**Recommendation:** Extract to `ConfigHelpers.OpenColorPicker(swatch, colorTable, dbPath, updateFunc)` that handles the three callbacks, previous value restore, and swatch texture update.

### 4. Widget Ticker Efficiency (Medium Priority)

The widget framework's shared ticker calls `UpdateContent` on all enabled widgets every second. Many widgets (Mail, Zone, Guild, Friends, Combat, ItemLevel) are purely event-driven and only need their text updated when an event fires.

**Recommendation:** Add an `eventDriven = true` flag to widget definitions. Event-driven widgets would update their text in their event handler and skip the ticker entirely.

### 5. TalentManager Temporary Table Allocation (Medium Priority)

`TalentManager.RefreshBuildList()` creates multiple temporary tables per call (`raidBuilds`, `dungeonBuilds`, `uncategorizedBuilds`, sorted name arrays). For users with many builds, this creates garbage on every panel refresh.

**Recommendation:** Use module-level scratch tables with `wipe()` at the start of each refresh.

### 6. Consistent Module Registration Pattern (Low Priority)

Most modules use `local Module = {}; addonTable.Module = Module`. Some widget files rely on closure state instead. The local-variable-then-assign pattern is preferred for performance (upvalue access is faster than table lookups).

### 7. Event Frame Proliferation (Low Priority)

Several modules create multiple separate event frames when a single frame with conditional event handling would suffice:
- `Combat.lua` -- 4 frames
- `ObjectiveTracker.lua` -- 4 frames
- `MplusTimer.lua` -- 3 frames
- `TalentManager.lua` -- 1 main + hooks
- Many widgets create a separate `eventFrame` alongside the widget frame itself

This is not a performance concern (frames are cheap in WoW) but adds code complexity.

### 8. Combat Lockdown Handling (Strength)

The codebase is consistently defensive about combat lockdown. Protected frame operations are guarded. Secure templates are used correctly. The three-layer ActionBars pattern is exemplary. `issecretvalue()` checks are properly used in Kick.lua and Keystone.lua.

### 9. Frame Pooling (Strength)

Frame pooling is consistently used in Loot.lua, Frames.lua, Teleports.lua, Currency.lua, TalentManager.lua (build rows), and the widget WidgetsPanel. No frame leak concerns in the core modules.

### 10. Centralized TTS (Strength)

`Core.SpeakTTS` centralizes text-to-speech with graceful API fallbacks. Used consistently by QuestReminder, Misc (personal orders), and Combat (consumable reminders).

### 11. Widget ApplyEvents Pattern (Strength)

Widgets consistently implement `ApplyEvents(enabled)` to register/unregister events when toggled. This prevents disabled widgets from processing events. Excellent pattern consistently applied across all 26 widget files.

### 12. Saved Variable Separation (Strength)

Data that should survive settings resets is stored in separate saved variables: `LunaUITweaks_TalentReminders`, `LunaUITweaks_ReagentData`, `LunaUITweaks_QuestReminders`. This is a smart architectural decision.

---

## Priority Recommendations

### High Priority

1. **FIXED: `readyCheckActive`/`readyCheckResponses` scoping in widgets/Group.lua** -- Moved the local declarations to before the `OnEnter` script assignment so the closures properly capture them. Ready check tooltip overlay now displays correctly.

### Medium Priority

2. **FIXED: Orphaned widgets/Currency.lua** -- Integrated into the addon: added to TOC, Core.lua defaults, and WidgetsPanel.lua. Currency IDs updated from TWW Season 1 (Harbinger Crests) to Season 3 (Ethereal Crests).

3. **Reuse `placeholders` table in ChatSkin.lua `HighlightKeywords`** -- `FormatURLs` was fixed to use a module-level table, but `HighlightKeywords` (line 139) still creates a local per call. Use a separate module-level table with `wipe()`.

4. **Add combat lockdown guard in MinimapCustom.lua `SetDrawerCollapsed`** -- Showing/hiding collected minimap buttons without checking `InCombatLockdown()` could taint secure buttons from other addons.

5. **TalentManager scratch tables** -- `RefreshBuildList` allocates temporary tables per call. Reuse module-level tables with `wipe()`.

6. **EJ cache timing in TalentManager** -- `EnsureEJCache()` changes global EJ tier selection. Defer cache build to a time when the EJ UI is unlikely to be open.

7. **Extract shared border utility** -- Reduce ~100 lines of duplicated border code across 5 files.

8. **Extract color picker helper in config system** -- Reduce ~300+ lines of duplicated `ColorPickerFrame` boilerplate across 20 config panels.

9. **Cache collected minimap buttons in MinimapCustom.lua** -- `CollectMinimapButtons` iterates all minimap children on every call. Use the existing `alreadyCollected` dedup set more aggressively to skip re-processing.

10. **Move FPS widget memory scan to background timer** -- `UpdateAddOnMemoryUsage()` is expensive. Triggering it on tooltip hover can cause frame hitches. Use a background timer instead.

11. **Widget ticker efficiency** -- Add `eventDriven` flag to skip per-second `UpdateContent` calls for purely event-driven widgets.

12. **Use `table.concat` in ObjectiveTracker string building** -- Reduce intermediate string allocations in hot render paths.

13. **Throttle cast time text in CastBar.lua** -- Currently updates every frame; 0.05s throttle would reduce `string.format` calls by ~75%.

14. **Widget panel frame recycling in WidgetsPanel.lua** -- `RefreshWidgetCheckboxes` orphans old frames on rebuild. Pool or reuse row frames.

15. **Consolidate event frames in ObjectiveTracker.lua** -- Two frames (`f` and `hookFrame`) register overlapping events.

16. **(NEW) ChatSkin.lua `SetItemRef` override fragility** -- `SetItemRef` is replaced globally instead of using `hooksecurefunc`. If another addon replaces `SetItemRef` after ChatSkin, the URL handler is lost. If another addon replaces it before, that addon's override is hidden behind LunaUI's wrapper. Use `hooksecurefunc("SetItemRef", ...)` for safe chaining.

17. **(NEW) ChatSkin.lua `Disable()` does not undo `SetItemRef` override** -- The URL hyperlink handler remains active even when chat skin is disabled. `origSetItemRef` is captured in the `hooksInstalled` block and inaccessible from `Disable()`. Either store `origSetItemRef` at module scope for restoration, or switch to `hooksecurefunc` (which does not need restoration).

18. **(NEW) MinimapCustom.lua `GetMinimapShape = nil` for round shape** -- Setting the global to nil means any addon calling `GetMinimapShape()` will error. Set to `function() return "ROUND" end` instead.

19. **(NEW) Group.lua tooltip uses `CreateAtlasMarkup` per member per hover** -- Cached constants `TANK_ICON`, `HEALER_ICON`, `DPS_ICON` already exist at module scope but are not used in the `OnEnter` handler. Creates unnecessary string garbage on every tooltip display.

### Low Priority / Polish

20. **Defensive `db` nil check in Core.lua `ApplyDefaults`** -- Add `if not db then return end`.

21. **Simplify `Loot.UpdateLayout`** -- Remove redundant `if i == 1` branch.

22. **Consolidate `GetItemInfo` calls in Combat.lua `TrackConsumableUsage`**.

23. **MplusTimer ApplyLayout consolidation** -- Layout calls are spread across 5 call sites. Consolidating to a single post-update hook would simplify the code.

24. **Cap guild member tooltip display** -- Large guilds (500+) could cause tooltip delay.

25. **Speed widget dual-update mechanism** -- OnUpdate handler makes ticker `UpdateContent` redundant.

26. **Bags widget goldData default** -- Verify Core.lua defaults include `goldData = {}` subtable.

27. **Consider splitting large files** -- ActionBars.lua (1552 lines), ObjectiveTracker.lua (2131 lines), ChatSkin.lua (1330 lines), TalentManager.lua (1509 lines).

28. **`OnAchieveClick` type guard** -- Add `type(self.achieID) == "number"` check.

29. **TalentManager row button closure optimization** -- `SetRowAsBuild` creates closures on every row reuse. Pre-allocate handlers that read stored data from the row.

30. **Reagents `GetTrackedCharacters` caching** -- Rebuilds list from saved variable on every call.

31. **Font list cache invalidation note** -- Document in dropdown tooltip that new fonts require `/reload`.

32. **Consistent module registration** -- Prefer `local M = {}; addonTable.M = M` pattern everywhere.

33. **(NEW) MinimapCustom.lua dead code in zone drag handler** -- Line ~358 has `select(2, Minimap:GetTop(), Minimap:GetTop())` which is immediately overwritten by `mapTop = Minimap:GetTop()`.

34. **(NEW) Frames.lua `SetBorder` local function** -- The `SetBorder(tex, r, g, b, a)` helper is defined inside the loop body of `UpdateFrames()`. It should be hoisted to module scope since it does not capture any loop variables.

35. **(NEW) QuestAuto.lua `GOSSIP_CLOSED` not unregistered** -- When `autoGossip`, `autoAcceptQuests`, and `autoTurnIn` are all false, `ApplyEvents` unregisters `GOSSIP_SHOW` and `GOSSIP_CLOSED`. But the `GOSSIP_CLOSED` handler only clears `lastGossipOptionID`, which is harmless. No functional issue, but the event registration logic for `GOSSIP_CLOSED` could be simplified to always mirror `GOSSIP_SHOW`.
