# WoW Lua Code Review — 2026-04-16

Scope: all `.lua` files under the project root (top-level, `widgets/`, `games/`, `config/`), excluding `libs/`. `ActionBars.lua`, `ChatSkin.lua`, and `LootChecklist.lua` plus their config panels were deleted earlier this session (they were not referenced from the TOC and had no runtime callers). Findings below reflect the post-deletion state and are verified by direct file reads.

## Critical (would cause errors or taint in-game)

### Button prototype taint — `ADDON_ACTION_BLOCKED` on map pins / secure buttons
- ~~**MinimapCustom.lua:36-40** — `QueueStatusButton:ClearAllPoints()`, `SetPoint()`, `SetParent(Minimap)`, `SetFrameLevel(100)` on the Blizzard Button.~~ **FIXED 2026-04-16.** Positioning calls kept but moved into a 2-second `C_Timer.NewTicker` with an early-return if already in place. Per MEMORY.md, these calls taint layout context but not the Button prototype — safe to keep.
- ~~**MinimapCustom.lua:50** — `QueueStatusButton:HookScript("OnShow", ...)`~~ **FIXED 2026-04-16.** Hook removed; polling replaces it.
- ~~**MinimapCustom.lua:62** — `hooksecurefunc(QueueStatusButton, "SetPoint", ...)` frame-object form.~~ **FIXED 2026-04-16.** Hook removed.
- ~~**MinimapCustom.lua:75** — `hooksecurefunc(QueueStatusButton, "UpdatePosition", ...)` frame-object form.~~ **FIXED 2026-04-16.** Hook removed.

### Frame-object `hooksecurefunc` / `HookScript` on Blizzard frames
- ~~**ObjectiveTracker.lua:985** — `hooksecurefunc(ObjectiveTrackerFrame, "Show", ...)` frame-object form on the Blizzard tracker.~~ **RESOLVED 2026-04-16.** Entire ObjectiveTracker module removed — functionality moved to a separate companion addon.
- ~~**CastBar.lua:518** — `hooksecurefunc(frame, "Show", ...)` where `frame == PlayerCastingBarFrame`.~~ **FIXED 2026-04-16.** Replaced with `RegisterStateDriver(PlayerCastingBarFrame, "visibility", "hide")`; combat-time toggles defer to `PLAYER_REGEN_ENABLED`.
- ~~**CastBar.lua:521** — `hooksecurefunc(frame, "SetShown", ...)` same frame.~~ **FIXED 2026-04-16.** Same state-driver replacement.
- ~~**CastBar.lua:525** — `hooksecurefunc(frame, "SetAlpha", ...)` same frame.~~ **FIXED 2026-04-16.** Same state-driver replacement.
- **TalentManager.lua:250** — `PlayerSpellsFrame:HookScript("OnShow", OnTalentFrameShow)` on a Blizzard frame. Taints the talent window. Replace with a global-form hook: `hooksecurefunc("ToggleTalentFrame", ...)` (or `EventRegistry:RegisterFrameEvent("PLAYER_TALENT_UPDATE")`), reading `PlayerSpellsFrame:IsShown()` to decide whether to show the addon panel.
- **TalentManager.lua:251** — `PlayerSpellsFrame:HookScript("OnHide", OnTalentFrameHide)` — same fix.

### Button parented to secure popup
- **Misc.lua:422** — `deleteButton:SetParent(dialog)` where `dialog` is a Blizzard `StaticPopup` resolved from `StaticPopup_Visible()` + `_G[dialogName]`. Addon-created Button writes itself into the StaticPopup's child list; subsequent `StaticPopup_Show` calls walk that list from protected code, pulling taint into Blizzard flow. Safer: parent `deleteButton` to `UIParent` and anchor to `editBox` via `SetPoint` without reparenting. `SetPoint` to a Blizzard frame is a read, not a write.

### Combat-lockdown guard missing
- **Combat.lua:1419** — `UnregisterStateDriver(reminderFrame, "visibility")` inside `ApplyReminderEvents()`, which has no `InCombatLockdown()` guard. In practice the function is reached from settings panels (out of combat) and from the enable/disable toggle, but there is no structural guarantee — if a settings change fires during combat the call will fail. Add `if InCombatLockdown() then return end` (or a deferral) at the top of `ApplyReminderEvents`.

## Warning (likely bugs or violations)

### Forward reference / missing local
- **games/Boxes.lua:1599** — `function UpdateHUD()` declared without `local`, leaking into `_G`. Calls at 1559, 1592, 1631 precede the definition lexically; the call works at runtime because Lua looks up the global, but it pollutes `_G` and is brittle. Fix: forward-declare `local UpdateHUD` at the top of the file, then define as `UpdateHUD = function() ... end` (or move the definition above the first use and prefix with `local`).

### Positioning coupling to Blizzard frames
- **TalentManager.lua:222-224** — `mainPanel:SetPoint("TOPLEFT", PlayerSpellsFrame, "TOPRIGHT", 2, 0)` anchors the addon panel to a Blizzard frame. This direction (reading the Blizzard frame as an anchor) does not taint, but the panel becomes unreachable if `PlayerSpellsFrame` is unloaded. Guard at line 221 (`if not mainPanel or not PlayerSpellsFrame then return end`) handles the unload case — acceptable.

### Frame positioning not migrated to CENTER convention
- **Coordinates.lua, MplusTimer.lua, QueueTimer.lua, XpBar.lua, CastBar.lua, Kick.lua, MinimapCustom.lua** — Per CLAUDE.md these modules are tracked as "not yet migrated (dynamic GetPoint)". Position is saved as whatever anchor the user dragged from rather than CENTER-from-UIParent, so positions drift on UI scale / resolution changes between sessions. Tracking item, not an immediate bug.

### Secret-value hygiene (currently correct — document for future edits)
- **DamageMeter.lua:474-562** — `StatusBar:SetValue(src.totalAmount)` and sibling calls pass secret values directly into C-level methods (correct — avoids any Lua arithmetic or comparison on secrets). The design works because `totalAmount` / `amountPerSecond` / `name` / `sourceGUID` are never assigned to a Lua local or table field. Any future edit that does so will break immediately — consider a top-of-file comment pinning this contract.
- **Core.lua:73** — `UnitName("player")` with concatenation is safe because it fires once at login out of combat and the result is cached in `characterKey`. If the caching contract is ever relaxed, the concat will break on the secret string. Low risk; noted.
- **AddonVersions.lua:121** — `UnitName(unit)` as table key inside a function combat-guarded at line 109. Safe as long as the guard stays.
- **Kick.lua:233, 288** — `UnitName(unit)` / `UnitName("player")` without explicit combat guard. Reached through group-comm handlers; `UnitName("player")` returns the player's own name which is not secret, but `UnitName(unit)` for arbitrary units may be during combat. Add an `issecretvalue` short-circuit or a combat guard.
- **TalentReminder.lua:227, 242** — Correctly uses `issecretvalue(unitTarget)` before `UnitName(unitTarget)` concatenation. Good pattern.

### `COMBAT_LOG_EVENT_UNFILTERED`
None found — the codebase correctly avoids this event across all remaining files.

### Lua 5.1 compatibility
None found — no `\xNN` hex escapes, no bitwise operators, no `//`, no `goto`, no `<const>`/`<close>`. `games/Cards.lua:20-24` suit glyphs correctly encoded as `\226\153\165` etc. per Lua 5.1 decimal-escape convention.

## Minor (style, performance, clarity)

### Hot-path allocations
- **games/Snek.lua:88** — `local colStr = r..","..g..","..b` creates a fresh string per tick for table-key use. Swap to a numeric key like `r*65536 + g*256 + b` to skip string interning.
- **games/Cards.lua:582-587** — Drag `OnUpdate` handler created fresh on each `dragFrame:SetScript("OnUpdate", function...)`. If `SetScript` is called once per drag-start (most likely), the allocation is per drag (fine). If it's being set per tick somewhere, hoist to an upvalue.
- **games/Bombs.lua:181-184** — `C_Timer.NewTicker` created per `RevealCell`. Verify `if timerTicker then timerTicker:Cancel() end` runs on every path before reassignment.
- **widgets/Widgets.lua:70, 94** — `string.format("(%.0f, %.0f)", x, y)` during drag `OnUpdate`. One alloc per frame while dragging; acceptable for transient UI.

### `HookScript` on addon-created frame (safe — not taint)
- **widgets/Speed.lua:51** — `speedFrame:HookScript("OnUpdate", ...)` on an addon-owned frame from the widget framework. Not taint. No action.

### Global leaks / style
- **Misc.lua:338** — `SLASH_LUNAUIRELOAD1` / `SlashCmdList["LUNAUIRELOAD"]`. Must be globals for the WoW slash-command API. Same for Core.lua:805-809. Not a leak.
- **games/Boxes.lua:1599** — (see Warning) missing `local`.
- **config/Helpers.lua:26-33** — `DeepCopy()` lacks cycle detection. Current callers pass leaf config tables, so no immediate risk. Add cycle guard before anyone ever deep-copies a frame reference.
- **config/Helpers.lua:447** — `CreateFont("LunaFontPreview_" .. i)` registers FontObjects globally by deterministic name. Low count; re-opens reuse existing fonts. Acceptable.
- **config/ConfigMain.lua** — Repeated `if addonTable.X and addonTable.X.UpdateSettings then addonTable.X.UpdateSettings() end` pattern (~20 copies). Factor to a `SafeCallUpdateSettings(moduleKey)` helper.

### Magic numbers
- **XpBar.lua:289** — `SetWidth(1)` as "collapsed" state. Name it `COLLAPSED_WIDTH`.
- **games/Tiles.lua:255-256** — Hardcoded 1000-value font-switch threshold. Name it.
- **games/Bombs.lua:177, 218** — `0.3` gravity delay. Name it.

### Correctly-flagged non-issues (spurious agent findings to ignore on future passes)
- **config/panels/TrackerPanel.lua:45** — `panel = scrollChild` reassignment is the intentional pattern so subsequent `panel:Create*` calls parent into the scroll child. Not a bug.
- **Warehousing.lua:422-425** — `popupFrame` is `CreateFrame("Frame", ..., UIParent)` — an addon-owned frame, not a Blizzard dialog. `SetPoint`/`ClearAllPoints`/`SetParent` are safe here.
- **games/Snek.lua:231** — `UIThingsDB.games.snek.highScore = highScore` fires only when a new high is achieved (after eating food), not every tick.
- **games/Boxes.lua:1559** — `UpdateHUD()` call: the function is defined globally at line 1599, so the call resolves at runtime. The real concern is the missing `local` (Warning above), not a missing function.

### Style
- **TalentReminder.lua:76** — Prefer `string.format` over `"Migrated " .. migrated .. " talent builds"` for consistency. Trivial.
- **TalentManager.lua:813** — `C_Traits.GenerateImportString(configID)` result used without `if exportString then` nil-check. Add it.
- **TalentReminder.lua:1343** — `GetTalentName` dereferences `C_Traits` without the guard present elsewhere in the file. Add consistent check.
- **Warehousing.lua:702, 1010** — Mismatched-looking `end -- classID ~= 7` comments cluttering scope closure. Cosmetic.

## Summary

Six critical findings from the previous review (in the deleted `ActionBars.lua` and `ChatSkin.lua`) are gone as of this session's cleanup, and the four `MinimapCustom.lua` QueueStatusButton items were fixed by replacing the frame-object hooks with a 2-second polling ticker — `SetPassThroughButtons` errors on map pins should now be gone.

The remaining Critical surface is two items in three files: `ObjectiveTracker.lua` (one frame-object hook on `ObjectiveTrackerFrame`), `CastBar.lua` (three frame-object hooks on `PlayerCastingBarFrame`), `TalentManager.lua` (two `HookScript` calls on `PlayerSpellsFrame`), and `Misc.lua` (`deleteButton:SetParent(dialog)` on a StaticPopup). All share the same fix pattern: replace frame-object hooks with global-form hooks or tickers, and keep any positioning calls gated on `InCombatLockdown()`.

The codebase otherwise remains in solid hygiene: no `COMBAT_LOG_EVENT_UNFILTERED`, no Lua 5.1 violations, no hex escapes, DamageMeter's secret-value handling is correct, and `issecretvalue` is used defensively in TalentReminder, Loot, Keystone, and SessionStats. The one combat-lockdown regression is `Combat.lua:1419` (`UnregisterStateDriver` reachable without a guard), which needs an `InCombatLockdown()` check at the top of `ApplyReminderEvents`.

Remaining Critical surface: `TalentManager.lua` (two `HookScript` calls on `PlayerSpellsFrame`) and `Misc.lua` (one `SetParent` on a StaticPopup). Both are low-frequency (only fire when the user opens the talent window or deletes a rare item), so they're lower impact than the items cleared this session.
