# WoW Lua Code Review — 2026-03-19

## Critical (would cause errors or taint in-game)

### Button Prototype Taint (ADDON_ACTION_BLOCKED)

- **MinimapCustom.lua:50** — `QueueStatusButton:HookScript("OnShow", ...)` — frame-object `HookScript` on a Blizzard Button taints the shared Button prototype → `ADDON_ACTION_BLOCKED: Button:SetPassThroughButtons()`. Fix: replace `HookQueueEye()` with `C_Timer.NewTicker(2.0, AnchorQueueEyeToMinimap)`.

- **MinimapCustom.lua:62** — `hooksecurefunc(QueueStatusButton, "SetPoint", ...)` — frame-object form on Blizzard Button; taints shared Button prototype.

- **MinimapCustom.lua:75** — `hooksecurefunc(QueueStatusButton, "UpdatePosition", ...)` — same Button-prototype taint.

- **MinimapCustom.lua:146–168** — `MinimapCluster.InstanceDifficulty:ClearAllPoints()`, `:SetPoint()`, `:SetParent()` in `ApplyMinimapShape`. `InstanceDifficulty` is a confirmed Blizzard Button frame. All three calls taint the shared Button prototype. No combat lockdown guard.

- **MinimapCustom.lua:152–160** — `QueueStatusButton:ClearAllPoints()`, `:SetPoint()`, `:SetParent()` in the SQUARE-shape path — taints `QueueStatusButton` layout context on every shape application.

- **ActionBars.lua:350** — `QueueStatusButton:HookScript("OnShow", ...)` — duplicate Button-prototype taint (hooked in both ActionBars and MinimapCustom).

- **ActionBars.lua:362** — `hooksecurefunc(QueueStatusButton, "SetPoint", ...)` — frame-object hook on Blizzard Button, taints prototype.

- **ActionBars.lua:1406, 1415, 1422** — `hooksecurefunc(btn, "UpdateHotkeys/Update/SetNormalTexture", ...)` per action button — frame-object hooks on Blizzard Button frames. Up to 96 buttons × 3 hooks = 288 hooks, all tainting the shared Button prototype. Fix: replace with global-form `hooksecurefunc("ActionButton_UpdateHotkeys", ...)` and a 2-second ticker.

- **Teleports.lua:324** — `btn:SetParent(nil)` in `ReleaseButton()` on `SecureActionButtonTemplate` buttons with no `InCombatLockdown()` guard. `SetParent` on secure Button frames during combat taints the Button prototype.

- **Teleports.lua:295** — `btn:SetParent(parent)` in `AcquireButton()` on pooled secure buttons — same concern as above when recycled during combat.

### Frame-Object Hooks on Blizzard Frames (Taint)

- **ActionBars.lua:677** — `hooksecurefunc(MicroMenuContainer, "SetParent", ...)` — taints `MicroMenuContainer`.

- **ActionBars.lua:709, 736** — `hooksecurefunc(EditModeManagerFrame, "Show/Hide", ...)` — taints `EditModeManagerFrame`.

- **CastBar.lua:340–349** — `hooksecurefunc(PlayerCastingBarFrame, "Show/SetShown/SetAlpha", ...)` — three frame-object hooks taint `PlayerCastingBarFrame`.

- **ChatSkin.lua:681** — `hooksecurefunc(ChatFrame1, "SetPoint", ...)` — taints `ChatFrame1`. Identified in MEMORY.md as needing replacement with global-form hooks.

- **ObjectiveTracker.lua:973** — `hooksecurefunc(ObjectiveTrackerFrame, "Show", ...)` — taints `ObjectiveTrackerFrame`.

- **TalentManager.lua:250–251** — `PlayerSpellsFrame:HookScript("OnShow/OnHide", ...)` — frame-object `HookScript` taints `PlayerSpellsFrame`.

### SetScript on Blizzard Frames (Taint)

- **ChatSkin.lua:360** — `bg:SetScript("OnShow", ...)` on `ChatFrameNBackground` — replaces Blizzard script, taints frame.

- **ChatSkin.lua:428** — `btn:SetScript("OnShow", ...)` on Blizzard chat buttons (`ChatFrameMenuButton`, `ChatFrameChannelButton`, `QuickJoinToastButton`) — taints all.

- **ChatSkin.lua:442** — `ChatFrame1ButtonFrame:SetScript("OnShow", ...)` — taints Blizzard frame.

- **MinimapCustom.lua:223, 227** — `Minimap.ZoomIn/ZoomOut:SetScript("OnShow", ...)` — replaces Blizzard handlers, taints child frames.

- **MinimapCustom.lua:251, 274** — `mailFrame:SetScript("OnHide", nil)` and `craftFrame:SetScript("OnHide", nil)` on Blizzard-owned `IndicatorFrame` children — taints permanently.

### HookScript on Blizzard Frames (Taint)

- **ChatSkin.lua:381** — `tex:HookScript("OnShow", ...)` on Blizzard ChatFrame border textures — taints each hooked object.

- **ChatSkin.lua:396** — `region:HookScript("OnShow", ...)` on Blizzard BORDER-layer texture children — same taint.

### SetParent / Repositioning Blizzard Frames Without Combat Guard

- **ChatSkin.lua:590–592** — `ChatFrame1:ClearAllPoints()`, `:SetPoint()`, `:SetSize()` in `LayoutContainer()` with no `InCombatLockdown()` guard.

- **ChatSkin.lua:651** — `ChatFrame1:SetParent(containerFrame)` — reparents Blizzard frame without combat guard.

- **ChatSkin.lua:655–657** — `ChatFrame1EditBox:SetParent(containerFrame)` — same.

- **ChatSkin.lua:659–661** — `GeneralDockManager:SetParent(containerFrame)` — same.

- **ChatSkin.lua:1291–1295** — `ChatFrame1/EditBox/GeneralDockManager:SetParent(UIParent)` in `Disable()` — no combat guard.

- **MinimapCustom.lua:243–295** — `mailFrame`, `craftFrame`, `MinimapCluster.Tracking`, `AddonCompartmentFrame` all get `ClearAllPoints()`, `SetPoint()`, `SetParent()` inside `PositionMinimapIcons()` with no `InCombatLockdown()` guard.

- **MinimapCustom.lua:1048–1053** — `btn:ClearAllPoints()`, `SetPoint()`, `SetParent()`, `SetSize()` in `LayoutDrawerButtons()` — repositions Blizzard minimap addon buttons without combat guard. If any are Buttons, this taints the prototype.

- **MinimapCustom.lua:1113–1119** — Same in `ReleaseDrawerButtons()`.

### Writing Fields onto Blizzard Frames

- **ChatSkin.lua:892** — `ChatFrame1EditBox.languageID = langID` — writes a field directly onto a Blizzard frame, tainting the entire frame table.

- **ActionBars.lua:115–151** — `container.GetEdgeButton = ...` and `mtIndex.GetEdgeButton = ...` — writes methods onto Blizzard frame tables and metatables.

### Secret Value Violations

- **SCT.lua:210–215** — `UnitName("target")` / `UnitName(unitTarget)` results used in string concatenation (`displayText .. " (" .. targetName .. ")"`) without `issecretvalue()` check. `UnitName()` returns secret strings during combat; concatenation will error.

- **MplusTimer.lua:895–902** — `GetUnitName(unit, false)` result stored as table key: `state.deathLog[name] = ...` inside `CHALLENGE_MODE_DEATH_COUNT_UPDATED`. Fires during combat; secret value as table key causes "table index is secret" error.

- **DamageMeter.lua:122–128** — `byGuid[guid]` uses `src.sourceGUID` (a secret value during live combat) as a table key in `AccumulateSources`. Causes "table index is secret" error if reached with tainted data.

### Combat Lockdown Violations

- **Lockouts.lua:148–155** — `RaidInfoFrame:Hide()` and `RaidInfoFrame:Show()` on Blizzard frames with no `InCombatLockdown()` guard. Would cause `ADDON_ACTION_BLOCKED` if widget tooltip is hovered during combat.

- **CastBar.lua:381–382** — `PlayerCastingBarFrame:SetAlpha(1)` and `PlayerCastingBarFrame:Show()` in `RestoreBlizzardCastBar` — `Show()` on Blizzard frame, guard only checks `isActive`, not `InCombatLockdown()`.

- **Misc.lua:315–325** — `UIWidgetPowerBarContainerFrame:ClearAllPoints()`, `SetPoint()` and calls on `container.FrontModelScene/BackModelScene` inside `ApplyPreyIconPosition()` — runs from a 0.5s ticker, can fire during combat.

### Global Variable Leaks

- **Boxes.lua:1599** — `function UpdateHUD()` — missing `local`, leaks to `_G`. Same for `BuildCellGrid` at line 1638.

### Other

- **Helpers.lua:331–336** — Legacy `ColorPickerFrame` fallback path writes fields (`func`, `hasOpacity`, `cancelFunc`) directly onto the Blizzard `ColorPickerFrame`. Taint-unsafe if reached.

- **Loot.lua:382–399** — `AlertFrame:RegisterEvent(...)` / `AlertFrame:UnregisterEvent(...)` directly on Blizzard `AlertFrame` — can taint the frame's event state.

## Warning (likely bugs or violations)

### Frame Positioning Convention Violations

- **Combat.lua:88–89** — Drag-stop saves raw `GetPoint()` instead of normalizing to CENTER offsets from `UIParent:GetCenter()`. Frame can drift after UI scale changes.

- **ObjectiveTracker.lua:1027–1036** — Same issue: drag-stop saves raw `GetPoint()` without CENTER normalization.

- **QuestReminder.lua:254** — Same: `popupFrame:SetPoint(pos.point, ...)` uses raw `GetPoint()` anchor.

- **TalentReminder.lua:1427–1433** — Same positioning convention violation on alert frame drag-stop.

- **MplusTimer.lua:134** — `pos.point` used as both anchor and relative point without CENTER normalization.

- **Coordinates.lua:755** — Same: `db.pos.point` used as both anchor and relative point.

### Fragile Load-Time Dependencies

- **QuestAuto.lua:6** — `local EventBus = addonTable.EventBus` captured at file-load time. If QuestAuto.lua loads before EventBus.lua in TOC, `EventBus` will be `nil`.

- **Loot.lua:447** — Same fragile capture of `addonTable.EventBus` at file-load time.

- **Widgets.lua:476–483** — EventBus registrations at module level outside any init guard — depends on TOC load order.

- **Helpers.lua:136** — `BuildFontList()` runs at file-load time calling `GetFonts()` and scanning `_G` before client fully initialized.

- **Helpers.lua:535** — `BuildTextureList()` runs at load time accessing `PlayerCastingBarFrame` status bar texture before Blizzard initializes it.

### Behavioral Bugs

- **AddonVersions.lua:183–205** — `RefreshVersions()` calls `wipe(playerData)` then `UpdatePartyList()` which early-returns in combat. If refresh button clicked in combat, all player data is wiped and not repopulated.

- **Teleports.lua:549–554** — When no teleports available, `contentFrame:CreateFontString(...)` is inserted into `mainButtons`. `ClearMainPanel` calls `ReleaseButton` on it expecting a Button — `FontString` lacks `SetScript`, `arrow` field, etc. → crash.

- **WheeCheck.lua:20** — `cachedDMFStatus` is set once and never invalidated. If DMF starts/ends while logged in, widget shows stale data for the entire session.

### Secret Value Risks

- **Group.lua:344** — `GetUnitName("player", true)` used in `==` comparison inside `OnEnter` tooltip during combat. Result may be secret; equality comparison behavior with secrets is undocumented.

- **AddonVersions.lua:121** — `UnitName(unit)` result used as table key (`groupNames[name]`, `playerData[name]`). Guard at line 109 returns early in combat, but `RefreshVersions()` at line 196 calls `UpdatePartyList()` without its own combat guard (see behavioral bug above).

- **Keystone.lua:215** — `line.leftText` accessed without `issecretvalue()` check, unlike the `pcall` pattern at line 37.

### Blizzard Frame Interactions

- **MinimapCustom.lua:287–311** — `MinimapCluster.Tracking` and `AddonCompartmentFrame` get `SetParent()`, `ClearAllPoints()`, `SetPoint()` — Blizzard frames, no combat guard.

- **ChatSkin.lua:527** — `region:GetText()` on Blizzard FontStrings in `GetChatContent()` — returns tainted strings per CLAUDE.md rules.

- **Vendor.lua:299, 303** — `warningFrame.isUnlocking = true` / `bagWarningFrame.isUnlocking = true` — writing fields onto addon frames (not Blizzard), but inconsistent with side-table convention.

- **Kick.lua:579–594** — `frame:SetParent(blizzFrame)` sets addon frame parent to Blizzard party/unit frames. Can interfere with Blizzard frame hierarchy during combat.

### Other Warnings

- **Core.lua:838–868** — `MigrateBottomLeftToCenter` uses `UIParent:GetWidth()/GetHeight()` at `ADDON_LOADED` time — UIParent may not have final dimensions yet.

- **Combat.lua:1111** — `hooksecurefunc(C_Container, "UseContainerItem", ...)` — table-object form hook, not global-string form.

- **TalentReminder.lua:629** — `RAID_CLASS_COLORS[classFile]` keyed by `reminder.className:upper():gsub(" ", "")` — class names saved in one locale may not match keys in another.

- **Misc.lua:507–509** — `UIThingsDB` accessed at file-load time before `PLAYER_LOGIN` — fragile if load order changes.

- **Reagents.lua:377** — `UnhookTooltip()` is a no-op (hooks can't be removed from `TooltipDataProcessor`). Function name is misleading.

- **ConfigMain.lua panels** — `UIDropDownMenu_CreateInfo()` used as a table constructor in color picker `OnClick` handlers (e.g. TrackerPanel.lua). Works incidentally but could break if Blizzard validates the returned table type. Use plain `local info = {}` instead.

- **Lockouts.lua:57** — `RequestRaidInfo()` called unconditionally during `Initialize()`, sending a network request on every addon load.

- **Friends.lua:89, 93** — `BNGetNumFriends()` called twice in the same function path unnecessarily.

- **Kick.lua:1068, 1111** — `local playerGUID` declared twice in the same function scope, second shadows the first.

## Minor (style, performance, clarity)

### Table Allocation in Hot Paths

- **ActionBars.lua:914** — `{ button:GetRegions() }` creates a new table on every `SkinButton()` call. Hoisted to a reusable pattern or iterated differently would reduce GC pressure on frequent `Update` hook fires.

- **ActionBars.lua:889** — `{ "Border", "IconBorder", ... }` table literal inside `SkinButton()` — should be a module-level constant.

- **ChatSkin.lua:142–143** — `kwPlaceholders` table created fresh in every `HighlightKeywords()` call (per chat message). Should reuse a module-level table with `wipe()`.

- **Reagents.lua:247–270** — `GetLiveBagCount()` builds a `bagList` table on every call including tooltip hover. Use a prebuilt constant.

- **Reagents.lua:350–353** — `local others = {}` allocated per tooltip display in `AddReagentLinesToTooltip()`.

- **Snek.lua:134–151** — `SpawnFood` builds `local empty = {}` on every food spawn (up to 400 entries). Use module-level reusable buffer.

- **Widgets.lua:204–213** — `UpdateAnchoredLayouts()` creates a new `anchoredWidgets` table every second.

- **Frames.lua:86–93** — New backdrop table `{}` created per frame per `UpdateFrames()` call. Should be a shared constant.

- **Frames.lua:111–113** — `SetBorder` closure defined inside `UpdateFrames` loop — creates new function object per iteration.

- **FPS.lua:99** — `table.sort(addonMemList, ...)` called redundantly in `OnEnter` — already sorted in `RefreshMemoryData()`.

### Performance Patterns

- **ObjectiveTracker.lua:167–172** — `AcquireItem()` iterates entire `itemPool` to find released items (O(n)). Stack-style pool would be O(1).

- **ObjectiveTracker.lua:946–948** — `select(i, frame:GetChildren())` in a loop inside a 2-second ticker creates garbage each tick. Capture once with `{ frame:GetChildren() }`.

- **Snek.lua:88–93** — `SetCell` builds color key string via concatenation on every cell (up to 400/tick).

- **QueueTimer.lua:87–110** — `OnUpdate` reads `UIThingsDB.queueTimer.*` on every frame. Cache in locals.

- **Speed.lua:51** — `OnUpdate` checks `UIThingsDB.widgets.speed.enabled` every frame even when disabled. Remove OnUpdate when hidden.

- **Volume.lua** — `GetCVar` called on every 1-second ticker in `UpdateContent`. Could be event-driven on `CVAR_UPDATE`.

### Dead Code

- **Cards.lua:574** — Unused local `scale` in `StartDrag` — computed but never used (shadowed by inner closure's own `scale`).

- **DarkmoonFaire.lua:33** — `if firstSunday > 7 then firstSunday = firstSunday - 7 end` — condition is never true given the modulo math. Dead guard.

- **Loot.lua:195–215** — `if i == 1` / `else` branches in `UpdateLayout` have identical bodies — the conditional is redundant.

- **MinimapCustom.lua:396** — `select(2, Minimap:GetTop(), Minimap:GetTop())` — `GetTop()` called twice, result immediately overwritten on line 397.

- **Config.lua** — File is empty except comments. Could be removed from TOC.

### Style

- **TalentReminder.lua:76** — Uses raw integer `1` for log level instead of `addonTable.Core.LogLevel.INFO`.

- **QuestReminder.lua:66** — `local frequency = nil` — redundant `= nil` initializer.

- **XpBar.lua:184–185** — `local remaining` shadows outer `remaining` in the same scope.

- **Misc.lua:411** — `SLASH_LUNAUIRELOAD1 = "/rl"` — global at file-load time; silently overwrites if another addon registered `/rl`.

- **Combat.lua:825** — Double `GetItemInfo(itemID)` call — first at line 816 (nil check only), second at 825 (full unpack). Single call suffices.

- **AddonComm.lua:49** — Hard-coded `40` as max raid size. `GetNumGroupMembers()` would avoid iterating beyond actual group size.

- **Boxes.lua:1599, 1638** — `UpdateHUD` and `BuildCellGrid` should be `local` (accidental global leak, repeated from Critical).

- **widgets/AddonComm.lua:73** — `UnitClass(name)` passes a player name instead of a unit ID — returns nil for most non-self entries, falls back to white text silently.

- **Boxes.lua:1704** — `SetPortraitTexture(portrait, "player")` called on all 130 cells per level load. Only the player cell needs a portrait — use a single repositioned texture.

- **ConfigMain.lua:257** — `navScrollChild:SetHeight(...)` set twice; first call at line 206 is immediately overridden.

## Summary

The codebase is large and feature-rich with generally clean module boundaries and good use of the EventBus pattern. The most pervasive issue remains **Button prototype taint** from frame-object `hooksecurefunc`/`HookScript` calls on Blizzard Button frames (especially `QueueStatusButton` in both MinimapCustom and ActionBars, and per-button hooks on all 96 action buttons). These cause `ADDON_ACTION_BLOCKED` errors that corrupt map pins and other secure UI. The fix pattern is documented in MEMORY.md (replace with global-form hooks and polling tickers) but not yet applied.

**ChatSkin.lua** is the second-largest taint surface, reparenting `ChatFrame1`, `EditBox`, and `GeneralDockManager` without combat guards and using `SetScript` on multiple Blizzard frames. **MinimapCustom.lua** touches many Blizzard child frames (`InstanceDifficulty`, mail/craft indicators, tracking, zoom buttons) with `SetParent`/`SetScript`/`ClearAllPoints` — all without combat lockdown guards.

**Secret value handling** has a few gaps: `SCT.lua` concatenates potentially-secret `UnitName()` results, `MplusTimer.lua` uses secret names as table keys in the death tracker, and `DamageMeter.lua` has a risky `byGuid[guid]` path with potentially-tainted GUIDs.

Frame positioning is inconsistent — about half the modules still save raw `GetPoint()` anchors instead of CENTER offsets from `UIParent:GetCenter()`, which can cause frames to drift after UI scale changes.

Performance is generally good, with a few recurring patterns of table allocation in hot paths (action bar skinning, widget anchoring, game board rendering) that could benefit from reusable buffers or module-level constants.
