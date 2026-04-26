# WoW Lua Code Review — 2026-04-23

Scope: every `.lua` file in `LunaUITweaks/` (excluding `libs/`). Focus on TWW 12.0 secret values, Button prototype taint, combat lockdown, Lua 5.1 portability, frame anchoring, memory/perf, and general quality.

## Critical (would cause errors or taint in-game)

### Blizzard Button prototype taint (`SetPoint` / `SetParent` / `ClearAllPoints` on Blizzard Buttons)

Per the project memory, *any* of these calls on a Blizzard Button frame taints the shared Button prototype, producing `ADDON_ACTION_BLOCKED: Button:SetPassThroughButtons()` and similar errors on map pins, party frames, and other secure UI.

- **MinimapCustom.lua:46–50** — `QueueStatusButton:ClearAllPoints/SetPoint/SetParent/SetFrameStrata/SetFrameLevel` inside `AnchorQueueEyeToMinimap()`. The combat guard at line 34 prevents the lockdown error but does not prevent prototype taint. Memory entry "QueueStatusButton fix (TODO)" already flags this.
- **MinimapCustom.lua:115–119, 122–128, 132–138, 141–145** — `QueueStatusButton`, `MinimapCluster.InstanceDifficulty`: `ClearAllPoints/SetPoint/SetParent`. Guarded by `InCombatLockdown` via `ApplyMinimapShape`, but still taints the Button prototype.
- **MinimapCustom.lua:212–218** — `mailFrame:SetParent/ClearAllPoints/SetPoint/SetScale/SetFrameStrata/SetFrameLevel`. `mailFrame` is `MinimapCluster.IndicatorFrame.MailFrame` (Blizzard-owned). **No `InCombatLockdown` guard on `PositionMinimapIcons()`**.
- **MinimapCustom.lua:236–243** — Same pattern on `MinimapCluster.IndicatorFrame.CraftingOrderFrame`. No combat guard.
- **MinimapCustom.lua:257–268** — Same pattern on `MinimapCluster.Tracking`. No combat guard.
- **MinimapCustom.lua:273–284** — Same pattern on `AddonCompartmentFrame`. No combat guard.
- **MinimapCustom.lua:220, 243** — `mailFrame:SetScript("OnHide", nil)` and `craftFrame:SetScript("OnHide", nil)` — clearing Blizzard frame handlers; taints the parent frame's script context.
- **MinimapCustom.lua:192, 196** — `Minimap.ZoomIn:SetScript("OnShow", ...)` / `Minimap.ZoomOut:SetScript("OnShow", ...)` — overriding script handlers on Blizzard Button frames.
- **MinimapCustom.lua:331–333** — `Minimap:SetParent/ClearAllPoints/SetPoint`. Runs at `PLAYER_ENTERING_WORLD` (typically OOC) but reparents the actual `Minimap` frame; this one is structurally hard to avoid given the wrapper-frame design.
- **MinimapCustom.lua:1016–1021** — `btn:ClearAllPoints/SetPoint/SetSize/SetParent/SetFrameStrata/SetFrameLevel` in `LayoutDrawerButtons()`, where `btn` is a collected LibDBIcon-style Blizzard Button. Called from `CollectMinimapButtons()` and a 3-second `C_Timer.After`. **No combat guard anywhere in the call chain**.
- **MinimapCustom.lua:1081–1086** — `btn:SetParent/ClearAllPoints/SetSize/SetPoint(unpack(pt))` in `ReleaseDrawerButtons()`. Same Blizzard-button risk.

Recommended fix: leave QueueStatusButton, InstanceDifficulty, Tracking, AddonCompartment, and the IndicatorFrame children at their default Blizzard positions; or anchor the addon's `minimapFrame` to them rather than the reverse. The drawer's button collection is the deepest offender — collected buttons belong to other addons and may still be Blizzard-derived; treat them all as untouchable.

### Secret-value `UnitName()` used as a table key, in `string.format`, or in `string.gsub`

`UnitName()` returns a secret string during combat in TWW. Using it as a table key throws *"table index is secret"*; using it in `string.format`, concat, or `string.gsub` replacement throws or silently fails.

- **Loot.lua:410** — `local playerName = UnitName("player")` then `rosterCache[playerName] = playerClass` at 413. Called from `UpdateRosterCache()`. Use `Secret.SafeUnitName("player", "Unknown")` and bail if name is the fallback.
- **Loot.lua:432** — `local name = UnitName(unit)` then `rosterCache[name] = classFileName` at 435. Same risk.
- **Loot.lua:519** — `local looterName = UnitName("player")` then `rosterCache[looterName]` at 520. Fires on `SHOW_LOOT_TOAST` which can fire mid-combat (boss kills, world-quest loot during combat).
- **Loot.lua:534** — Same pattern in `OnShowLootToastUpgrade`.
- **Loot.lua:550, 562** — `UnitName("player")` in `OnChatMsgLoot`. Line 562 directly compares with `~=` and line 551 uses the result as a key via `rosterCache[looterName]`. `CHAT_MSG_LOOT` fires constantly during combat.
- **Misc.lua:246–251** — `local name = UnitName(unitTarget)` then `msg:gsub("{name}", name)` then `Core.SpeakTTS(msg, ...)`. `OnUnitHealth` runs during combat (deaths happen in combat by definition). `string.gsub` with a secret replacement string is unsafe. Use `Secret.SafeUnitName(unitTarget, "Someone")`.
- **Kick.lua:1380, 1397, 1422, 1431, 1436, 1545, 1550** — `UnitName(unit)` inside `string.format(...)` for debug logging. The format call happens before the level filter inside `Log`, so the error fires whether the log is shown or not. Replace with `Secret.SafeUnitName`.
- **Kick.lua:1484** — `local ownerName = UnitName(ownerUnit)` then concatenated/formatted at 1487. Pet spell-cast handler runs in combat.
- **Kick.lua:233, 241** — `UnitName(unit) == senderShort` in `FindSenderGUID`. Equality on secret strings sometimes works but is unreliable in TWW; the comparison may silently fail.

### Combat-lockdown `UnregisterStateDriver` without guard

- **Combat.lua:1419** — `UnregisterStateDriver(reminderFrame, "visibility")` inside `ApplyReminderEvents()`. Reachable from `addonTable.Combat.ApplyReminderEvents()` → `addonTable.Combat.UpdateSettings()`, which the config panel calls on every checkbox toggle. If the user disables `combat.reminders` while in combat, this raises `ADDON_ACTION_BLOCKED`. Add `if InCombatLockdown() then ... defer until PLAYER_REGEN_ENABLED ... return end` at the top of the disable branch.

### Object-form `hooksecurefunc` on a Blizzard table

- **Combat.lua:1111** — `hooksecurefunc(C_Container, "UseContainerItem", TryTrackContainerItem)`. Object-form hook on a Blizzard global table taints that table's method dispatch. The legacy global-form fallback at line 1115 already covers this case correctly; drop the C_Container variant or replace it with a global-form hook on a wrapping function.

## Warning (likely bugs or violations)

### Combat-safety / taint surface area

- **MinimapCustom.lua:200–285** — `PositionMinimapIcons()` makes ~5 separate `ClearAllPoints/SetPoint/SetParent/SetScale` calls on Blizzard frames. Add `if InCombatLockdown() then return end` at function entry and re-call from a `PLAYER_REGEN_ENABLED` deferred handler if combat blocked the run.
- **MinimapCustom.lua:1091, 1152, 1155–1159** — `SetupDrawer()` and the `C_Timer.After(3, …)` re-collect path call `CollectMinimapButtons()` → `LayoutDrawerButtons()` without any combat check. The 3-second deferred re-collect can absolutely fire mid-combat.
- **Kick.lua:469–477, 498–503, 508–513** — Iterates `header:GetChildren()` / `CompactPartyFrame:GetChildren()` / `CompactRaidFrameContainer:GetChildren()` and reads `child.unit`. `child.unit` is set by Blizzard's secure code on these frames; reading it can return a secret string and taint the addon's call context. Prefer `SecureButton_GetUnit(child)` or build the lookup from unit tokens directly.
- **Kick.lua:593** — `frame:SetParent(blizzFrame)` where `blizzFrame` is a Blizzard `CompactPartyFrame`/`CompactRaidFrame`/`PartyFrame.MemberFrameN`. Reparenting an addon frame *into* a Blizzard secure frame can break that secure frame's child-traversal logic. Prefer SetPoint anchoring without SetParent.
- **Kick.lua:559–565** — `frame:SetPoint("…", blizzFrame, "…", …)` is safe in itself, but called from `RebuildPartyFrames()` which has no combat guard at the SetPoint sites (only inside `OnPartySpellCast` at 1460). A spec change in combat triggers this path.
- **CastBar.lua:523** — `PlayerCastingBarFrame:Show()` inside the `else` branch of `ApplyBlizzBarVisibility()`. Combat guarded at line 505 ✓ — flag is to verify regression in future edits.

### Secret-value handling (lower-risk paths)

- **Misc.lua:288** — `Misc.TestDeathTTS` uses `UnitName("player")` in `gsub`. User-triggered test button; runs in config UI (OOC), so low risk, but consistent fix recommended (`Secret.SafeUnitName`).
- **Misc.lua:325** — `Misc.TestWhisperAlert` calls `UnitName("player")`. Same; low risk.
- **Warehousing.lua:1242** — `item.vendorName = UnitName("target") or "Unknown"` runs while interacting with a vendor (OOC). Fine in practice; consider `Secret.SafeUnitName` for defense in depth.
- **widgets/AddonComm.lua:65, widgets/Keystone.lua:305, widgets/MythicRating.lua:125, widgets/SessionStats.lua:13** — `UnitName("player")` outside combat-sensitive paths (`PLAYER_LOGIN`/`PLAYER_ENTERING_WORLD`). Low risk but unguarded; switch to `addonTable.Secret.SafeUnitName` for consistency.
- **widgets/ReadyCheck.lua:28, 49** — `cachedPlayerShort = GetShortName(UnitName("player"))`. The cache pattern is correct (line 14 comment); the only concern is whether `GetShortName` uses `string.match`/`string.sub` on the secret string — verify in that helper.
- **widgets/Group.lua:340, 345** — Cached on `PLAYER_REGEN_ENABLED` + roster updates with explicit `InCombatLockdown` guard at 338. ✓ Good pattern; mirror this in Loot.lua and Kick.lua.

### Misc

- **MinimapCustom.lua:557** — Reads `minimapFrame:GetPoint()` and persists into `UIThingsDB.minimap.minimapPos`. `minimapFrame` is addon-owned, but if it has been tainted by reparenting to or from a Blizzard frame elsewhere, the saved position can become a secret value persisted into SavedVariables. Consider a `Secret.CanAccessValue` check before persisting.
- **MinimapCustom.lua:362–376, 425–441, 478–490** — Drag-stop handlers read `Minimap:GetCenter()`, `Minimap:GetBottom()`, `Minimap:GetTop()` (safe per project rules) and persist offsets. Fine.
- **Coordinates.lua:826** — `EventBus.Unregister("PLAYER_ENTERING_WORLD", OnPlayerEnteringWorld)` from inside the handler. EventBus tolerates this, but verify the dispatch loop iterates on a copy or the next subscriber is skipped.
- **DamageMeter.lua:807** — Stores `entry.guid = UnitGUID(...)` and uses it as a table key downstream. `UnitGUID` is generally non-secret; the existing memory entry about secret values in `C_DamageMeter` fields is unrelated. ✓
- **Combat.lua:1091** — `hooksecurefunc("UseAction", ...)` global form. Safe. ✓
- **TalentManager.lua:253, 256** — Already correctly migrated to global-form `hooksecurefunc("ShowUIPanel"/"HideUIPanel", ...)`. The earlier review note about `PlayerSpellsFrame:HookScript` is no longer present. ✓
- **AddonVersions.lua:109, 121** — `UnitName(unit)` reachable but exits early on `InCombatLockdown()` at line 109. ✓
- **CastBar.lua:505–527** — `RegisterStateDriver`/`UnregisterStateDriver`/`Show` on `PlayerCastingBarFrame` all gated by `InCombatLockdown()` with a `PLAYER_REGEN_ENABLED` deferral. ✓
- **XpBar.lua:301** — `RegisterStateDriver`/`UnregisterStateDriver` on `MainStatusTrackingBarContainer` correctly gated by `InCombatLockdown()`. ✓ (Earlier reviewer flagged as missing — verified present.)

## Minor (style, performance, clarity)

- **Core.lua:187** — `if type(value) == "table" and not value.r then` — uses truthiness of `value.r` to detect color tables. Works because `r=0` is still truthy, but `value.r == nil` is more explicit and survives a future color-table refactor that includes a sentinel `r = false`.
- **MinimapButton.lua:38** — Anchors the minimap button to `Minimap` rather than `UIParent`. Acceptable for a button that orbits the minimap, but inconsistent with the project's CENTER-of-UIParent positioning convention. Document the exception.
- **MinimapCustom.lua:11** — `local minimapLocked = true -- Runtime-only` is set but only read by `SetMinimapLocked`; the var is never read externally. Dead state — drop it or persist it.
- **MinimapCustom.lua:67–72** — `deferShapeCb` closure captures the `shape` arg of the original call. Multiple combat-time shape changes will only execute the last one (because the previous closure is unregistered at line 65). Acceptable but worth a comment.
- **MinimapCustom.lua:365–366** — `select(2, Minimap:GetTop(), Minimap:GetTop())` then immediately reassigns `mapTop = Minimap:GetTop()`. The `select` line is dead code; delete it.
- **MinimapCustom.lua:1053** — `local sources = { Minimap:GetChildren() }` allocates a new table per call. Cold path, not a real concern.
- **CastBar.lua:599–602** — `string.format` runs even when `CASTBAR_DEBUG` is false; only the `print` is skipped (inside `DBG`). Move the format inside `DBG` or guard the whole block on the flag.
- **widgets/Speed.lua:51** — `speedFrame:HookScript("OnUpdate", ...)` on an addon-owned frame. Safe but unnecessary — there is no prior `OnUpdate` to preserve. Use `SetScript`.
- **widgets/Coordinates.lua:53** — Hardcoded em-dash escape `"\226\128\148"`. Lift to a named local for readability: `local EM_DASH = "\226\128\148"`.
- **MinimapCustom.lua:513** — `coordsText:SetText("\226\128\148, \226\128\148")` — same em-dash literal. Use a shared constant.
- **MplusTimer.lua:187, 911, 920** — Uses `GetUnitName(unit, false)` (global form). Returns the same secret-string risk as `UnitName`. Audit which paths are combat-reachable.
- **Kick.lua:1085–1086** — `partyFrames` rebuild always runs from scratch; framePool reuse is a nice touch, but a 40-person raid means ~80 `ClearAllPoints` calls per `GROUP_ROSTER_UPDATE`. Already throttled at 0.5s — acceptable.
- **Loot.lua:497–507** — `IsDuplicate` iterates the entire `recentToasts` table on every check to clean expired entries. Cheap because the table is small, but consider a `lastCleanup = GetTime()` gate so the prune runs at most once per second.
- **Coordinates.lua:698** — `scrollFrame:HookScript("OnSizeChanged", ...)` on addon-owned scroll frame. Safe; could be `SetScript`.
- **games/Blocks.lua:1414, games/Snek.lua:514** — `gameFrame:HookScript("OnShow", RefreshBindings)` on addon-owned frames. Safe; no action.
- **Combat.lua:1402–1421** — `ApplyReminderEvents()` is defined as a file-local *and* exposed via `addonTable.Combat.ApplyReminderEvents` at 1424. The two-layer wrapper adds nothing — call the local directly from `UpdateSettings` and skip the public alias unless companion addons consume it.
- **DamageMeter.lua:830–836** — Comment correctly explains why `UpdateScrollChildRect` is omitted. Good documentation. ✓
- **TalentReminder.lua:12–13** — Forward declarations of update functions; clear. ✓
- **widgets/Hearthstone.lua:129–130, widgets/Keystone.lua:139–140** — `ClearAllPoints/SetPoint` on `hearthFrame`/`keystoneFrame` inside `OnDragStop` handlers. These frames are addon-created; safe.
- **MplusData.lua** — Static data file; not reviewed for runtime issues. ✓

## Summary

Overall the codebase is mature, defensive, and clearly aware of TWW's secure-execution rules. The Secret helper, EventBus, combat-deferral pattern in CastBar, and the global-form `hooksecurefunc` migration in TalentManager are all examples of solid engineering. Most modules are clean.

The two real exposure surfaces are concentrated in **MinimapCustom.lua** and **Loot.lua / Kick.lua / Misc.lua**:

1. **MinimapCustom.lua** writes to many Blizzard Button frames (`QueueStatusButton`, `MinimapCluster.*`, `AddonCompartmentFrame`, `Minimap.ZoomIn/Out`, the entire collected drawer button set) without `InCombatLockdown` guards on `PositionMinimapIcons` and the drawer code, and these calls taint the shared Button prototype regardless of combat state. The project memory already tracks this as a TODO; it remains unresolved and is the highest-priority cleanup.

2. **Loot/Kick/Misc** read `UnitName()` results into table keys, `string.format`, `string.gsub`, and ordered comparisons. These were safe pre-12.0 but now silently fail or error out during combat. The `Secret.SafeUnitName` helper exists and is used correctly in `DamageMeter.lua` and `Core.lua`; the same pattern should be propagated to every UnitName call reachable from `CHAT_MSG_LOOT`, `SHOW_LOOT_TOAST`, `UNIT_HEALTH`, `UNIT_SPELLCAST_*`, and addon-comm handlers.

3. **Combat.lua:1419** is a single missing `InCombatLockdown()` guard before `UnregisterStateDriver`; trivial to fix.

No Lua 5.1 portability issues, no `COMBAT_LOG_EVENT_UNFILTERED` use, no `\xNN` escapes, no integer division, no global leaks, and no `goto`/`<const>`/`<close>` were found. Frame-positioning conventions are followed consistently in the modules already migrated to CENTER-of-UIParent. Memory and performance are reasonable; ticker lifecycles correctly start/stop with feature toggles.
