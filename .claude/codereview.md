# WoW Lua Code Review — 2026-03-17

## Critical (would cause errors or taint in-game)

- **MinimapCustom.lua:50** — `QueueStatusButton:HookScript("OnShow", ...)` — `HookScript` is the frame-object form; taints `QueueStatusButton` and the shared Button prototype → `ADDON_ACTION_BLOCKED: Button:SetPassThroughButtons()`. Fix: delete `HookQueueEye()` entirely and replace with `C_Timer.NewTicker(2.0, AnchorQueueEyeToMinimap)`.

- **MinimapCustom.lua:62** — `hooksecurefunc(QueueStatusButton, "SetPoint", ...)` — Frame-object form on a Blizzard Button frame; taints the shared Button prototype. Fix: same as above — ticker replaces all three hooks.

- **MinimapCustom.lua:75** — `hooksecurefunc(QueueStatusButton, "UpdatePosition", ...)` — Same Button-prototype taint. Fix: same ticker approach.

- **MinimapCustom.lua:146–168** — `MinimapCluster.InstanceDifficulty:ClearAllPoints()`, `:SetPoint()`, `:SetParent()` called in `ApplyMinimapShape` for both SQUARE and non-SQUARE paths. `InstanceDifficulty` is a confirmed Blizzard Button frame (listed in CLAUDE.md). `ClearAllPoints/SetPoint/SetParent` on it taint the shared Button prototype. No combat lockdown guard either. Fix: do not reposition `InstanceDifficulty`; anchor an addon-owned overlay frame relative to it without touching the frame itself.

- **MinimapCustom.lua:152–160** — Inside the SQUARE-shape path, `QueueStatusButton:ClearAllPoints()`, `:SetPoint()`, `:SetParent()` are called directly (outside the hook). These taint `QueueStatusButton`'s layout context at every shape application including login.

- **MinimapCustom.lua:223, 227** — `Minimap.ZoomIn:SetScript("OnShow", ...)` and `Minimap.ZoomOut:SetScript("OnShow", ...)` — `SetScript` replaces a script handler on Blizzard child frames. This taints those child frames. Fix: use `RegisterStateDriver` to keep them hidden, or a polling ticker.

- **MinimapCustom.lua:251, 274** — `mailFrame:SetScript("OnHide", nil)` and `craftFrame:SetScript("OnHide", nil)` inside `PositionMinimapIcons`. `mailFrame` is `MinimapCluster.IndicatorFrame.MailFrame` and `craftFrame` is `MinimapCluster.IndicatorFrame.CraftingOrderFrame` — both Blizzard-owned. `SetScript` on them taints those frame tables permanently. Fix: do not clear `OnHide`; rely on a periodic ticker to re-show them.

- **ActionBars.lua:350** — `QueueStatusButton:HookScript("OnShow", ...)` — Same Button-prototype taint issue as MinimapCustom.lua:50. QueueStatusButton is hooked in both files, doubling the taint surface.

- **ActionBars.lua:362** — `hooksecurefunc(QueueStatusButton, "SetPoint", ...)` — Frame-object form on Blizzard Button; taints the shared Button prototype (duplicate of MinimapCustom.lua:62).

- **ActionBars.lua:77–83** — `SafeSetParent`: `btn:SetScript("OnHide", nil)` temporarily on Blizzard micro buttons (CharacterMicroButton, etc.), then restores the original. Even a transient `SetScript(nil)` on a Blizzard Button frame taints that frame's table. Fix: suppress Layout by patching `MicroMenuContainer:Layout` (already done at line 91) and remove the `SafeSetParent` workaround.

- **ActionBars.lua:677** — `hooksecurefunc(MicroMenuContainer, "SetParent", ...)` — Frame-object hook taints `MicroMenuContainer`. Fix: use `hooksecurefunc("FrameXML_SetParent", ...)` if available, or poll via a ticker.

- **ActionBars.lua:709, 736** — `hooksecurefunc(EditModeManagerFrame, "Show", ...)` and `hooksecurefunc(EditModeManagerFrame, "Hide", ...)` — Frame-object hooks on a Blizzard frame. Fix: respond to the `EDIT_MODE_LAYOUTS_UPDATED` event via EventBus instead.

- **ActionBars.lua:1225** — `hooksecurefunc(barFrame, hookTarget, ...)` where `hookTarget` is `"SetPointBase"` or `"SetPoint"` on Blizzard action bar frames. Frame-object form taints the bar frame context. Fix: use a secure state driver on a `SecureHandlerStateTemplate` frame to re-apply positions after Blizzard re-layouts.

- **ActionBars.lua:1406–1428** — `hooksecurefunc(btn, "UpdateHotkeys", ...)`, `hooksecurefunc(btn, "Update", ...)`, `hooksecurefunc(btn, "SetNormalTexture", ...)` on Blizzard action buttons. Frame-object hooks on Button frames taint the shared Button prototype → `ADDON_ACTION_BLOCKED`. Fix: remove these three `hooksecurefunc` calls; add `hooksecurefunc("ActionButton_UpdateHotkeys", function(btn) ... end)` for the hotkey alpha, and a `C_Timer.NewTicker(2.0, ...)` for `SkinButton`.

- **ChatSkin.lua:681** — `hooksecurefunc(ChatFrame1, "SetPoint", ...)` — Frame-object hook on `ChatFrame1`; taints its layout context. Fix: replace with `hooksecurefunc("ShowUIPanel", ...)` and `hooksecurefunc("HideUIPanel", ...)` that call `C_Timer.After(0.05, LayoutContainer)`.

- **ChatSkin.lua:527** — `local text = region:GetText()` in the `GetChatContent` fallback, where `region` is a FontString obtained from `selectedFrame:GetRegions()` and `selectedFrame` is a Blizzard chat frame. Calling `GetText()` on a Blizzard FontString returns a tainted string; the subsequent `gsub` chain (line 529) on a tainted value either silently fails or produces garbage. Fix: remove the fallback entirely (the `GetMessageInfo` path covers content correctly).

- **ObjectiveTracker.lua:942** — `hooksecurefunc(ObjectiveTrackerFrame, "Show", ...)` — Frame-object hook on a Blizzard frame; taints `ObjectiveTrackerFrame`. Fix: poll via a ticker or respond to `OBJECTIVES_UPDATED` in global-form.

- **CastBar.lua:340–349** — `hooksecurefunc(PlayerCastingBarFrame, "Show", ...)`, `hooksecurefunc(PlayerCastingBarFrame, "SetShown", ...)`, `hooksecurefunc(PlayerCastingBarFrame, "SetAlpha", ...)` — Frame-object hooks on Blizzard's player cast bar; taint `PlayerCastingBarFrame`. Fix: replace all three hooks with a `C_Timer.NewTicker(0.05, ...)` that forces alpha to 0 while `blizzBarHidden` is true.

- **Misc.lua:267** — `searchBar.FilterButton.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true` — Writing a field into a table on a Blizzard frame (`AuctionHouseFrame.SearchBar.FilterButton.filters`). Taints `FilterButton` and all downstream Blizzard reads of its `filters` table. Fix: use `C_AuctionHouseFilter.SetFilter` if available, or call Blizzard's own `FilterButton:SetFilter(...)` method.

- **Misc.lua:311–326** — `ApplyPreyIconPosition()` calls `ClearAllPoints()` and `SetPoint()` on `UIWidgetPowerBarContainerFrame` (a Blizzard frame) without an `InCombatLockdown()` guard. The 0.5s ticker at line 388 calls this repeatedly, including during combat. Fix: add `if InCombatLockdown() then return end` at the top of `ApplyPreyIconPosition()`.

- **TalentManager.lua:250–251** — `PlayerSpellsFrame:HookScript("OnShow", ...)` and `PlayerSpellsFrame:HookScript("OnHide", ...)` — `HookScript` on a Blizzard frame taints the frame context. Fix: replace with `hooksecurefunc("ShowUIPanel", ...)` / `hooksecurefunc("HideUIPanel", ...)` or poll via ticker.

- ~~**AddonVersions.lua:97–108** — `UnitName("player")` and `UnitName(unit)` return potentially secret values during combat. These are used as table keys (`groupNames[playerName] = true`, `playerData[playerName]`). Using a secret value as a table key causes "table index is secret" error. `GROUP_ROSTER_UPDATE` can fire during combat.~~ **FIXED:** Player name cached once via `GetPlayerName()`. `UpdatePartyList()` now returns early during `InCombatLockdown()`. `PLAYER_REGEN_ENABLED` handler re-runs roster scan after combat ends.

- **Teleports.lua:324–327** — `ReleaseButton` calls `btn:SetAttribute("type", nil)`, `btn:SetAttribute("spell", nil)`, `btn:SetParent(nil)`, and `btn:ClearAllPoints()` on secure buttons. If the teleport panel is hidden during combat (e.g., ESC or dismiss frame), `ReleaseButton` runs without an `InCombatLockdown()` guard, causing `ADDON_ACTION_BLOCKED`. Fix: guard `ReleaseButton` — if `InCombatLockdown()` and the button is secure, skip `SetAttribute`/`SetParent` calls (or defer them).

- **Teleports.lua:550–554** — When no teleports are available, a `FontString` (not a Button) is inserted into `mainButtons`. Later, `ClearMainPanel()` calls `ReleaseButton(btn, btn:IsProtected())` on it. FontStrings lack `:IsProtected()`, `:Hide()`, and `:SetParent()`, causing a Lua error. Fix: track the "no spells" label separately, or guard `ReleaseButton` to check `btn.IsProtected`.

- ~~**Group.lua:508, 514–516** — `readyCheckResponses[UnitName(unit) or unit] = "waiting"` during `READY_CHECK` event. `UnitName()` can return a secret string during combat. Using it as a table key causes "table index is secret" error.~~ **FIXED:** Added `readyCheckNameCache` populated on `GROUP_ROSTER_UPDATE`, `PLAYER_ENTERING_WORLD`, and `PLAYER_REGEN_ENABLED`. `OnReadyCheck` and `OnReadyCheckConfirm` now use cached names instead of `UnitName()`.

- ~~**ReadyCheck.lua:85–86** — `OnReadyCheckResponse` uses `UnitName(unit)` as a key into `memberStatus` table during combat. Same secret-value-as-table-key error risk.~~ **FIXED:** Added `nameCache` populated on `GROUP_ROSTER_UPDATE`, `PLAYER_ENTERING_WORLD`, and `PLAYER_REGEN_ENABLED`. `PopulateGroupMembers` uses cache for party members, `OnReadyCheckResponse` uses `nameCache[unit]`.

## Warning (likely bugs or violations)

- **ChatSkin.lua:280–281** — `tab.lunaIndicator = tab:CreateTexture(...)` writes a custom field onto Blizzard chat tab frames (`ChatFrame1Tab`, etc.). This taints the tab's frame table. Fix: use a side-table `local tabIndicators = {} -- [tab] = texture`.

- **ChatSkin.lua:341–342** — `editBox.lunaSeparator = editBox:CreateTexture(...)` writes a custom field onto Blizzard edit box frames (`ChatFrame1EditBox`, etc.). Fix: use a side-table.

- **ChatSkin.lua:893** — `ChatFrame1EditBox.languageID = langID` writes a field onto a Blizzard frame. Fix: store in a side-table keyed by the edit box.

- **ChatSkin.lua:590–609** — `ChatFrame1:ClearAllPoints()`, `ChatFrame1:SetPoint(...)`, `ChatFrame1:SetSize(...)`, `GeneralDockManager:ClearAllPoints()`, `GeneralDockManager:SetPoint(...)`, `GeneralDockManager:SetHeight(...)` in `LayoutContainer()` without a combat lockdown guard. If called during combat (e.g., from `UpdateSettings()`), this will cause `ADDON_ACTION_BLOCKED`. Fix: add `if InCombatLockdown() then return end` at the top of `LayoutContainer()`.

- **ChatSkin.lua:651** — `ChatFrame1:SetParent(containerFrame)` reparents a Blizzard frame. Inherently taint-risky. Currently runs during deferred setup, but if ever called during combat it will error. Fix: ensure this path is guarded.

- **ActionBars.lua:116** — `container.GetEdgeButton = PatchGetEdgeButton(container.GetEdgeButton)` writes a field onto `MicroMenuContainer` (a Blizzard frame). Taints the frame table. The metatable patching at lines 122–125 and 144–150 has the same issue.

- **ActionBars.lua:1441** — `ActionBars.RemoveSkin` creates a new anonymous frame (`CreateFrame("Frame")`) every time it's called during combat. If called repeatedly, this leaks frames. Fix: use a single persistent defer frame.

- **Kick.lua:459–514** — `frame.unit == unit` reads `.unit` from Blizzard frames (Grid2 frames, `PartyFrame.MemberFrame*`, `CompactPartyFrame` children, `CompactRaidFrameContainer` children). Reading `.unit` from Blizzard secure frames reads a value set by Blizzard's protected code, which taints the addon's execution context. Fix: use `UnitIsUnit()` with `pcall`, or iterate group units and match by GUID.

- **Kick.lua:233, 241** — `UnitName(unit) == senderShort` — `UnitName()` may return a secret value during combat. The `==` on a secret string silently evaluates false, losing kick attribution. Fix: `local n = UnitName(unit); if n and not issecretvalue(n) and n == senderShort then`.

- **Kick.lua:831** — `table.insert(activeCDs, {...})` creates a new table inside `UpdatePartyFrame` which is called every 0.1 seconds. Creates garbage every tick. Fix: pre-allocate and reuse.

- **DamageMeter.lua:116–117** — Misleading comment claims secret GUIDs are "safe as table keys" — they are NOT. The code itself is safe (live path uses integer keys), but the comment should be corrected.

- **DamageMeter.lua:141–161** — Inside `FetchEntries`, the `liveMode` branch stores `src.totalAmount` (a secret value) directly into `byGuid[i].total`. The rendering path must use `SetMinMaxValues`/`SetValue` for bar widths and must not apply arithmetic or comparisons to `d.total`. Verify the render path does not pass `d.total` to `FormatVal` (which calls `string.format`).

- **DamageMeter.lua:487** — `drilldown[captIdx]` stores `captSrc.sourceGUID` (secret during combat) as a table value; this value is later passed to `C_DamageMeter.GetCombatSessionSourceFromType`. If that API doesn't accept secret GUIDs, drilldown during live combat fails silently. Fix: disable drilldown clicks during combat.

- **Combat.lua:925, 932–935, 1001–1003** — `UnregisterStateDriver(reminderFrame, "visibility")` is called on several paths. Line 919 has a combat guard, but lines 932–935 and 1001–1003 bypass it via early-return paths. If reached during combat, `UnregisterStateDriver` will error. Fix: add `InCombatLockdown()` guards before those calls.

- **MinimapCustom.lua:243–310** — `mailFrame:SetParent(minimapFrame)`, `CraftingOrderFrame:SetParent(...)`, `MinimapCluster.Tracking:SetParent(...)`, `AddonCompartmentFrame:SetParent(...)` — all `SetParent`/`ClearAllPoints`/`SetPoint` on Blizzard frames without `InCombatLockdown()` guards. Fix: add combat guards.

- **MinimapCustom.lua:362–364** — `Minimap:SetParent(minimapFrame)`, `Minimap:ClearAllPoints()`, `Minimap:SetPoint(...)` on the Blizzard Minimap without combat lockdown guard. Fix: guard or ensure the path only runs outside combat.

- **Misc.lua:507–509** — `Misc.ToggleQuickDestroy(true)` is called with `if UIThingsDB and UIThingsDB.misc ...` at file-load time. Saved variables are unavailable at file load; `UIThingsDB` is always nil here, making this a permanent no-op. Fix: remove this dead block.

- **LootChecklist.lua:125** — `UnitClass("player")` returns the localized class name. The filter at line 138 compares against `info.classNames` which may contain English names. On non-English clients, the filter incorrectly excludes valid items. Fix: use `select(2, UnitClass("player"))` for the non-localized class token.

- **LootChecklist.lua:655** — `for _, c in ipairs({ child:GetChildren() }) do c:Hide() end` in `btn:SetItems()` creates a new table each call. Dropdown rows are rebuilt without recycling, creating new frames every call. Fix: pool dropdown row frames.

- **AddonComm.lua:152–163** — `CleanupRecentMessages` iterates `pairs()` and deletes keys during iteration. In Lua 5.1, modifying a table during `pairs()` iteration is technically undefined behavior. Fix: collect keys to delete first, then delete.

- **Loot.lua:616** — `_G[string.format("ContainerFrame%dItem%d", bag + 1, buttonIndex)]` relies on legacy container frame naming. In TWW 12.0, Blizzard may use the new combined bag frame. If names don't exist, overlays silently do nothing. Fix: verify naming or use new API.

- **QueueTimer.lua:~142** — The `OnUpdate` script runs every frame for the addon's lifetime even when `isRunning = false`. Fix: install in `StartTimer()` and clear in `StopTimer()`.

- **Vendor.lua:76, 95**, **Combat.lua:84**, **CastBar.lua:587**, **XpBar.lua:405**, **SCT.lua:17,43**, **Loot.lua:65**, **QuestReminder.lua:264**, **MplusTimer.lua:126**, **Warehousing.lua:433**, **TalentReminder.lua:1427**, **Coordinates.lua:621** — Drag-stop handlers save position via raw `GetPoint()` → `{ point, x, y }`. CLAUDE.md convention requires CENTER-relative offsets (`GetCenter() - UIParent:GetCenter()`). Storing raw anchor-relative values causes position drift after resolution changes.

- **MplusTimer.lua:688, 702** — `select(2, GetWorldElapsedTime(1))` could return nil if not in a timed instance, causing arithmetic error. Fix: add nil guard.

- **MplusTimer.lua:893–904** — Death attribution: when `i == #members` for a 5-player group, `unit = "player"` is substituted for `party5`. The last iteration always tests the player token, potentially mis-attributing deaths. Fix: iterate `party1`–`party4` then check `"player"` separately.

- **Lockouts.lua:148–153** — `RaidInfoFrame:Show()` at line 153 is called after `ToggleFriendsFrame(3)` without rechecking that `RaidInfoFrame` exists. If the friends frame hasn't been loaded yet, this errors. Fix: add nil guard.

- **WheeCheck.lua:68–73** — `OnCombatStart` unregisters `UNIT_AURA`; `OnCombatEnd` re-registers it. If the widget is disabled while in combat, `ApplyEvents(false)` unregisters `PLAYER_REGEN_ENABLED`, so `UNIT_AURA` never gets re-registered. Fix: re-register in `ApplyEvents(true)` unconditionally.

- **WaypointDistance.lua:6–8** — `local Coordinates = addonTable.Coordinates` captured at file load time. If `Coordinates.lua` loads after `WaypointDistance.lua` in the TOC, this is nil and `.GetDistanceToWP` errors. Currently safe by TOC order, but fragile.

## Minor (style, performance, clarity)

- **SCT.lua:89–104** — `ClearAllPoints()` + `SetPoint()` called inside `OnUpdate` every frame for up to 30 simultaneous SCT text frames. At 60 fps × 30 frames = 1800 layout calls/sec. Fix: only call `SetPoint` when the Y offset changes.

- **Widgets.lua:204, 296** — `anchoredWidgets = {}` and per-entry tables allocated every tick in `UpdateAnchoredLayouts()` (runs every 1 second). Fix: reuse module-level tables with `wipe()`.

- **Widgets.lua:218** — `table.sort(items, function(a, b) ...)` creates a new closure each tick. Fix: cache the sort comparator function.

- **Widgets.lua:394** — `Widgets.UpdateContent()` accesses `UIThingsDB.widgets.enabled` without nil-checking `UIThingsDB.widgets` first. If called before `ADDON_LOADED`, this errors.

- **Reagents.lua:246–270** — `GetLiveBagCount()` creates a temporary `bagList` table every call, and scans all bag slots on every tooltip hover. Fix: cache keyed by itemID; invalidate on `BAG_UPDATE_DELAYED`.

- **Keystone.lua:196–232** — `GetPlayerKeystone()` iterates all bag slots every 1 second via the widget ticker. Fix: cache result and only invalidate on `BAG_UPDATE`.

- **Vendor.lua** — Bag-space check iterates bags 0–4 only, missing the reagent bag (`Enum.BagIndex.ReagentBag` = 5). Low-space warning fires incorrectly when free slots are in the reagent bag only.

- **Core.lua:232–820** — The ~600-line `DEFAULTS` table is defined inside the `ADDON_LOADED` handler closure. Fix: move to module scope for readability.

- **Core.lua:832** — `MigrateBottomLeftToCenter` has unused parameters `defaultX, defaultY`. Fix: remove them.

- **Misc.lua:7–127** — `alertFrame`, `mailAlertFrame`, and `boeAlertFrame` are created unconditionally at module load even when `misc.enabled = false`. Fix: create lazily on first show.

- **Misc.lua:476–484** — `OnPartyInviteRequest` performs a linear scan over all BNet friends on every party invite. Fix: cache a GUID→bool lookup; invalidate on `BN_FRIEND_LIST_UPDATE`.

- **SCT.lua:69–74** — `RecycleSCTFrame` iterates the full `sctActive` list for O(n) removal. Fix: maintain a parallel set for O(1) removal.

- **SCT.lua:17–18** — `OnDragStop` saves position as `{ point, relPoint, x, y }` — not CENTER-relative. Same convention issue as the multi-file warning above.

- **AddonVersions.lua** — `GetPlayerKeystone` scans all bag slots on every `GROUP_ROSTER_UPDATE`. Fix: cache result; invalidate on `BAG_UPDATE_DELAYED`.

- **FPS.lua:99** — `addonMemList` is already sorted after `RefreshMemoryData()`; the re-sort in `OnEnter` is redundant. Fix: remove the second sort.

- **XpBar.lua:493, 501** — `STANDING_LABELS = {...}` is defined inside the OnEnter tooltip handler, allocating a new table every hover. Fix: move to module scope.

- **CastBar.lua:122** — `ApplyBarColor()` creates a temporary `{ r, g, b, a }` table each call for class-colored casts. Fix: pre-compute and cache the class color table.

- **CastBar.lua:141** — `FadeOut` creates a new closure each call via `SetScript("OnUpdate", function(...) end)`. Fix: pre-define the function as a local.

- **Combat.lua:278–294** — `ScanConsumableBuffs` iterates up to 40 buffs with `string.lower()` + `string.find()` on each name, running on every `UNIT_AURA` for the player. Fix: throttle or only scan on `PLAYER_REGEN_ENABLED`.

- **Snek.lua:88** — `local colStr = r..","..g..","..b` creates a new string every call to `SetCell` for delta rendering. Fix: use a numeric hash for color comparison.

- **DarkmoonFaire.lua:27–57** — DMF schedule calculation uses `time()` (local OS time) but DMF resets are based on server/region time. Can show incorrect status for players in different time zones.

- **Profiler.lua:44–58** — `timingExec` calls `callback(...)` without `pcall`. If a profiled callback errors, timing data is left inconsistent. Fix: wrap in `pcall` and still record timing on error.

- **Kick.lua:844** — `table.sort(activeCDs, ...)` creates a closure each tick. The sorted `activeCDs` table appears unused by subsequent rendering code. Fix: remove if dead code.

- **Kick.lua:1100** — `local playerGUID = UnitGUID("player")` declared twice in `RebuildPartyFrames` (first at line 1057, again at 1100). Fix: remove redundant declaration.

- **Multiple files** — Frame positions not yet migrated to CENTER anchor (documented in CLAUDE.md as pending): `XpBar`, `CastBar`, `Combat`, `Kick`, `ObjectiveTracker`, `MinimapCustom`, `MplusTimer`, `SCT`, `Vendor`, `Loot`, `QuestReminder`, `Warehousing`, `TalentReminder`, `Coordinates`.

## Summary

The addon has a solid architecture — centralized EventBus with compaction, AddonComm rate limiting, cache-TTL in DamageMeter, frame pooling in Loot, and thorough secret-value guards in the damage meter's live path. Config panels, games, and helper code are clean with no taint or Lua 5.1 issues.

**Critical issues (27 findings, 3 fixed):** The highest-priority items are the Button prototype taint vectors: `MinimapCustom.lua` QueueStatusButton hooks (lines 50, 62, 75) and InstanceDifficulty positioning (146–168), `ActionBars.lua` QueueStatusButton hooks (350, 362), micro button SetScript (77–83), action button frame-object hooks (1406–1428), and several other frame-object `hooksecurefunc` calls on Blizzard frames. New since last review: `TalentManager.lua:250` HookScript on PlayerSpellsFrame, `Misc.lua:311` positioning Blizzard widget frames without combat guard, `Teleports.lua:324` SetAttribute on secure buttons without combat guard. ~~`UnitName()` secret-value-as-table-key bugs in `AddonVersions.lua`, `Group.lua`, and `ReadyCheck.lua`~~ — **FIXED** via name caching outside combat.

**Warning issues (26 findings):** Writing custom fields onto Blizzard frames in ChatSkin (tabs, edit boxes), reading `.unit` from Blizzard frames in Kick, missing combat lockdown guards on ChatFrame1/GeneralDockManager layout calls, and various secret-value edge cases.

**Minor issues (25+ findings):** Per-frame table allocations (Widgets tick, SCT OnUpdate, Kick tick), per-hover allocations, redundant bag scans, and the ongoing CENTER anchor migration for 14 modules.

Resolving the taint vectors — particularly the QueueStatusButton hooks, action button hooks, and the new TalentManager/Misc/Teleports/secret-value issues — is the highest priority.
