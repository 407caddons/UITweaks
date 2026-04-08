# WoW Lua Code Review — 2026-03-28

## Critical (would cause errors or taint in-game)

### Button Prototype Taint (ADDON_ACTION_BLOCKED)

- **MinimapCustom.lua:50** — `QueueStatusButton:HookScript("OnShow", ...)` — frame-object `HookScript` on a Blizzard Button taints the shared Button prototype → `ADDON_ACTION_BLOCKED: Button:SetPassThroughButtons()`. Fix: replace `HookQueueEye()` with `C_Timer.NewTicker(2.0, AnchorQueueEyeToMinimap)`.

- **MinimapCustom.lua:62** — `hooksecurefunc(QueueStatusButton, "SetPoint", ...)` — frame-object form on Blizzard Button; taints shared Button prototype.

- **MinimapCustom.lua:75** — `hooksecurefunc(QueueStatusButton, "UpdatePosition", ...)` — same Button-prototype taint.

- **MinimapCustom.lua:146–168** — `MinimapCluster.InstanceDifficulty:ClearAllPoints()`, `:SetPoint()`, `:SetParent()` in `ApplyMinimapShape`. `InstanceDifficulty` is a confirmed Blizzard Button frame. All three calls taint the shared Button prototype. No combat lockdown guard.

- **MinimapCustom.lua:152–160** — `QueueStatusButton:ClearAllPoints()`, `:SetPoint()`, `:SetParent()` in the SQUARE-shape path — taints `QueueStatusButton` layout context on every shape application.

- **ActionBars.lua:351** — `QueueStatusButton:HookScript("OnShow", ...)` — duplicate Button-prototype taint (hooked in both ActionBars and MinimapCustom).

- **ActionBars.lua:363** — `hooksecurefunc(QueueStatusButton, "SetPoint", ...)` — frame-object hook on Blizzard Button, taints prototype.

- **ActionBars.lua:329–331** — `QueueStatusButton:ClearAllPoints()`, `:SetPoint()`, `:SetParent(Minimap)` — direct positioning on a Blizzard Button frame taints layout context.

- **ActionBars.lua:1407–1429** — `hooksecurefunc(btn, "UpdateHotkeys", ...)`, `hooksecurefunc(btn, "Update", ...)`, `hooksecurefunc(btn, "SetNormalTexture", ...)` — frame-object hooks on Blizzard action bar buttons. Each hooks a Button-inheriting frame, tainting the shared Button prototype. Fix: replace with global-form `hooksecurefunc("ActionButton_UpdateHotkeys", ...)` and a `C_Timer.NewTicker(2.0, ...)` to re-apply skins.

### Other Taint Issues

- **ActionBars.lua:116–152** — `container.GetEdgeButton = PatchGetEdgeButton(...)` and writes to `mtIndex.GetEdgeButton`, `container[methodName]`, `mtIndex[methodName]` — directly overwriting methods on Blizzard's MicroMenuContainer frame and its metatable. Taints the entire frame table.

- **ActionBars.lua:678** — `hooksecurefunc(MicroMenuContainer, "SetParent", ...)` — frame-object hook on a Blizzard frame taints MicroMenuContainer.

- **ActionBars.lua:710–711** — `hooksecurefunc(EditModeManagerFrame, "Show", ...)` and `hooksecurefunc(EditModeManagerFrame, "Hide", ...)` — frame-object hooks on Blizzard frame.

- **ActionBars.lua:1226** — `hooksecurefunc(barFrame, hookTarget, ...)` — frame-object hook on Blizzard action bar frames for SetPoint/SetPointBase. Called for every bar with a saved position.

- **CastBar.lua:340–349** — `hooksecurefunc(frame, "Show", ...)`, `hooksecurefunc(frame, "SetShown", ...)`, `hooksecurefunc(frame, "SetAlpha", ...)` on `PlayerCastingBarFrame` — frame-object hooks on a Blizzard frame taint it.

- **ChatSkin.lua:651** — `ChatFrame1:SetParent(containerFrame)` — reparenting a Blizzard frame. Causes taint in the chat frame system.

- **ChatSkin.lua:590–592** — `ChatFrame1:ClearAllPoints()`, `:SetPoint(...)`, `:SetSize(...)` — positioning calls on a Blizzard-owned frame without `InCombatLockdown()` guard.

- **ChatSkin.lua:606–609** — `GeneralDockManager:ClearAllPoints()`, `:SetPoint(...)` — positioning on a Blizzard frame without combat lockdown guard.

- **ChatSkin.lua:681** — `hooksecurefunc(ChatFrame1, "SetPoint", ...)` — frame-object hook on a Blizzard chat frame. Fix: replace with global-form `hooksecurefunc("ShowUIPanel", ...)` and `hooksecurefunc("HideUIPanel", ...)`.

- **ChatSkin.lua:280–281** — `tab.lunaIndicator = tab:CreateTexture(...)` — writing a field directly onto Blizzard chat tab frames. Taints the tab's frame table.

- **ChatSkin.lua:341** — `editBox.lunaSeparator = editBox:CreateTexture(...)` — writing a field onto Blizzard's ChatFrame1EditBox. Taints the edit box table.

- **ChatSkin.lua:381–398** — `tex:HookScript("OnShow", ...)` on Blizzard border/texture objects — multiple HookScript calls on Blizzard-owned objects taint them.

- **ObjectiveTracker.lua:985** — `hooksecurefunc(ObjectiveTrackerFrame, "Show", ...)` — frame-object form on Blizzard frame taints it. Should use a polling ticker or global-form hook.

- **TalentManager.lua:250–251** — `PlayerSpellsFrame:HookScript("OnShow", ...)` and `PlayerSpellsFrame:HookScript("OnHide", ...)` — taint PlayerSpellsFrame. Replace with polling ticker or global-form hooks.

### Combat Lockdown Violations

- **Teleports.lua:322–325** — `ReleaseButton` calls `SetParent(nil)`, `ClearAllPoints()`, `SetAttribute("type", nil)` on `SecureActionButtonTemplate` buttons without an `InCombatLockdown()` guard. Will error if called during combat (e.g., teleport panel hidden by Escape during combat).

- **Teleports.lua:295** — `AcquireSecureButton` calls `btn:SetParent(parent)` on secure buttons from the pool without an `InCombatLockdown()` guard. `SetParent` on a secure frame in combat causes a Lua error.

- **Misc.lua:337–353** — `ApplyPreyIconPosition()` calls `ClearAllPoints()`/`SetPoint()` on `UIWidgetPowerBarContainerFrame`, `FrontModelScene`, `BackModelScene` — Blizzard widget frames — on a 0.5s ticker (line 414) with no `InCombatLockdown()` guard. Will cause taint/errors during combat.

- **MinimapCustom.lua:186–228** — `HideDefaultDecorations()` calls `Hide()` on many Blizzard frames (`MinimapBorder`, `GameTimeFrame`, `TimeManagerClockButton`, etc.) without checking `InCombatLockdown()`. Also replaces scripts on `Minimap.ZoomIn`/`ZoomOut` with `SetScript("OnShow", ...)`.

### Performance: Expensive Recursive Calls

- **ObjectiveTracker.lua:957–961** — `DisableTrackerMouse` calls `GetNumChildren()` and `select(i, frame:GetChildren())` recursively to depth 10. Runs via ticker every 2 seconds. `GetChildren()` creates a new table each call, significant GC pressure.

## Warning (likely bugs or violations)

### Taint Risk

- **ChatSkin.lua:597–601** — `editBox:ClearAllPoints()`, `:SetPoint(...)` on Blizzard's ChatFrame1EditBox without combat guard.

- **ChatSkin.lua:360** — `bg:SetScript("OnShow", ...)` — replaces (not hooks) the OnShow script on a Blizzard frame child.

- **MinimapCustom.lua:240–310** — `PositionMinimapIcons()` calls `SetParent`, `ClearAllPoints`, `SetPoint`, `SetScale` on multiple Blizzard frames (`MailFrame`, `CraftingOrderFrame`, `MinimapCluster.Tracking`, `AddonCompartmentFrame`) without combat lockdown guards.

- **MinimapCustom.lua:362–364** — `Minimap:SetParent(minimapFrame)` and `Minimap:ClearAllPoints()` / `:SetPoint(...)` — reparents and repositions the Blizzard Minimap frame.

- **ActionBars.lua:79–85** — `SafeSetParent` strips and restores `OnHide` script via `btn:SetScript("OnHide", nil)` then `btn:SetScript("OnHide", origOnHide)` on Blizzard micro buttons.

- **Helpers.lua:331–335** — Legacy ColorPickerFrame fallback writes `ColorPickerFrame.func`, `.hasOpacity`, `.cancelFunc` directly onto a Blizzard frame. Low risk since modern path exists, but the fallback taints.

### Secret Values

- **widgets/AddonComm.lua:65** — `UnitName("player")` in tooltip OnEnter. During combat, returns a secret value. Used in comparison `name == playerName` which would silently fail.

- **widgets/Group.lua:367–376** — `GetUnitName(unit, true)` in tooltip OnEnter may return secret values during combat. Comparison `name == GetUnitName("player", true)` could silently fail.

- **widgets/Keystone.lua:305** — `UnitName("player")` in tooltip OnEnter, used as a table key for filtering — would error if secret.

- **widgets/MythicRating.lua:125** — `UnitName("player")` in tooltip OnEnter, same secret-as-key risk.

- **ObjectiveTracker.lua:879** — `UnitName(unit)` in tooltip callback during combat. Used via `table.insert` and `WrapTextInColorCode(name)` — could be problematic with secret strings.

### Code Injection Risk

- **config/panels/AddonVersionsPanel.lua:169–176** — `DeserializeString` uses `loadstring("return " .. str)` with `setfenv(func, {})`. While sandboxed, this still executes arbitrary Lua. A crafted import string could cause infinite loops or memory exhaustion. The 64KB size limit mitigates but does not eliminate the risk.

### Fragile Patterns

- **config/panels/DamageMeterPanel.lua:607** — `addonTable.DamageMeter.RefreshPosSliders = function()` writes to DamageMeter module table without checking if it exists. Would error if the module hasn't loaded.

- **widgets/Teleports.lua:549–554** — `ShowMainMenu` creates a `FontString` via `contentFrame:CreateFontString` when no teleports are available and inserts it into `mainButtons`. When `ClearMainPanel` runs, it calls `ReleaseButton` which expects button methods (`Hide`, `SetParent`, `ClearAllPoints`) that FontStrings don't have — will error on the "no teleports" edge case.

- **widgets/SessionStats.lua:11–13** — `db = UIThingsDB.widgets.sessionStats` captured at init time. If the table is replaced by defaults merge, `db` points to a stale table. Also `UnitGUID("player")` at init may return nil, falling through to `charKey = "unknown"`.

- **MplusTimer.lua:870** — `difficultyID == 8` check for M+ detection. In TWW, M+ difficulty ID can be 23 for some content. Line 1063 already checks both 8 and 23, but line 870 only checks 8.

- **LootChecklist.lua:127** — `UnitClass("player")` returns the localized class name. Line 139 compares it against `info.classNames` which may use English names. Should use `select(2, UnitClass("player"))` for the non-localized class filename.

- **Misc.lua:533–535** — `UIThingsDB` accessed at file load time for quick-destroy feature. Saved variables may not be initialized yet depending on load order.

### Redundant / Misused APIs

- **config/panels/FramesPanel.lua:469** — `UIDropDownMenu_CreateInfo()` used to create the info table for `ColorPickerFrame:SetupColorPickerAndShow()`. Creates unnecessary dropdown fields. Use a plain `{}` table.

- **config/panels/WidgetsPanel.lua:137** — Same `UIDropDownMenu_CreateInfo()` misuse for color picker.

## Minor (style, performance, clarity)

### Position Convention (not CENTER-relative)

- **CastBar.lua:587–590** — `GetPoint()` saves raw anchor. Listed as "not yet migrated" to CENTER convention.
- **Combat.lua:88–89** — Same: saves raw GetPoint data. Not yet migrated.
- **Coordinates.lua:621** — Same: `GetPoint()` instead of CENTER-relative.
- **MplusTimer.lua:127** — Same: raw GetPoint positioning.
- **QuestReminder.lua:254** — `popupFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)` uses whatever anchor the user dragged to.
- **Vendor.lua:77** — Same pattern; stores anchor from GetPoint instead of CENTER.
- **Loot.lua:64–66** — Same: anchor position from GetPoint.

### Table Allocations in Frequent Paths

- **Kick.lua:831** — `table.insert(activeCDs, { ... })` creates a temporary table every tick during active cooldowns. Combined with `table.sort`, generates GC pressure.
- **CastBar.lua:122–123** — `color = { r = cc.r, g = cc.g, b = cc.b, a = 1 }` — new table every `ApplyBarColor` call with class color. Could be cached.
- **ActionBars.lua:915** — `for _, region in ipairs({ button:GetRegions() }) do` — creates a temporary table from `GetRegions()` every `SkinButton` call during periodic refresh.
- **widgets/Widgets.lua:204** — `UpdateAnchoredLayouts` creates a new `anchoredWidgets` table every call (1s ticker).
- **widgets/Widgets.lua:296–297** — `UpdateVisuals` creates `anchoredWidgets` and `unanchoredWidgets` tables every call.
- **widgets/Currency.lua:147** — `GetCurrencyData` creates a new table every call, runs in a 1s ticker loop.
- **Reagents.lua:64–70, 247–253** — `local bagList = {}` created on every `ScanBags` / `GetLiveBagCount` call. Should use a pre-built bag list.

### Table Allocations in Tooltip Handlers (minor)

- **widgets/Durability.lua:53** — `slots` table created every hover.
- **widgets/ItemLevel.lua:57** — `slots` table created every hover.
- **widgets/Lockouts.lua:77–78** — `raids` and `dungeons` tables created every hover.
- **widgets/Friends.lua:59–62** — `entries` table created every hover.
- **widgets/Guild.lua:21** — `online` table created every hover.
- **widgets/ReadyCheck.lua:179** — `sorted` table created every hover.
- **widgets/Group.lua:360, 445** — `groups` and `sorted` tables created in tooltip OnEnter.
- **widgets/FPS.lua:99** — Redundant `table.sort(addonMemList, ...)` in OnEnter; data was already sorted in `RefreshMemoryData()`.

### Other Minor Issues

- **Combat.lua:193** — `table.remove(ttdSamples, 1)` shifts all elements. O(n²) for small window, acceptable but noted.
- **CastBar.lua:141** — New closure created in `FadeOut` OnUpdate each time. Could be pre-allocated.
- **Frames.lua:111** — `SetBorder` function defined inside a loop, creating a new closure per frame per update. Should be hoisted.
- **QueueTimer.lua:148–149** — `select(1, IsInInstance())` is unnecessary; single assignment already returns the first value.
- **MinimapCustom.lua:29** — Global function `GetMinimapShape()` defined. Intentional for other addons but pollutes global namespace.
- **ObjectiveTracker.lua:2040** — `SECTION_SPACING` and `ITEM_SPACING` modified every `UpdateContent()` call despite uppercase naming suggesting constants.
- **Warehousing.lua:1176** — Unused variable `itemID` from `GetCursorInfo()`.
- **TalentReminder.lua:903** — Uses `GetMaxLevelForPlayerExpansion()` instead of `GetMaxPlayerLevel()`, inconsistent with XpBar.lua:99.
- **AddonComm.lua:208** — Pattern `^(%u+):(.+)$` only matches uppercase module names. Intentional but undocumented.
- **config/panels/AddonVersionsPanel.lua:410** — `StaticPopupDialogs["LUNA_IMPORT_CONFIRM"]` re-registered on every panel setup without guard.
- **Multiple config panels** — Global frame names like `UIThingsCastBarEnable` could collide with other addons. Using `nil` names for non-referenced frames would be cleaner.
- **SCT.lua** — Listed in CLAUDE.md file table but does not exist on disk. The SCT module lives in the companion addon `LunaUITweaks_SCT`. Documentation should be updated.

## Summary

The codebase is generally well-structured with proper use of the EventBus pattern, addon-created frames for custom UI, and combat lockdown guards in most critical paths. The most impactful issues are:

1. **Button prototype taint** from `QueueStatusButton` hooks in both MinimapCustom.lua and ActionBars.lua, plus frame-object hooks on action buttons (ActionBars.lua:1407–1429). These directly cause `ADDON_ACTION_BLOCKED` errors affecting map pins and other secure UI. Known TODO items exist for all of these.

2. **ChatSkin.lua taint accumulation** from writing fields onto Blizzard chat tabs/editbox, reparenting ChatFrame1, and using frame-object hooksecurefunc on ChatFrame1. The chat skinning module has the densest concentration of taint patterns.

3. **Combat lockdown gaps** in Teleports.lua (secure button pool operations), Misc.lua (prey icon ticker repositioning Blizzard widget frames), and MinimapCustom.lua (hiding decorations without combat guard).

4. **ObjectiveTracker.lua recursive GetChildren()** running every 2 seconds is the most notable performance concern.

No Lua 5.1 syntax violations found. No `COMBAT_LOG_EVENT_UNFILTERED` usage. Secret value handling is generally correct with combat guards in place, though several tooltip handlers use `UnitName("player")` without protection.
