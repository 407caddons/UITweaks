# WoW Lua Code Review — 2026-04-19

## Changes since 2026-04-16

Since the previous review there has been one commit (`cdcc567 "Updates"`) plus currently-pending working-tree changes:

- **`MinimapCustom.lua`** — QueueStatusButton frame-object hooks replaced by a 2s `C_Timer.NewTicker` polling the button position (`StartQueueEyeTicker`). Early-return added to `AnchorQueueEyeToMinimap` when already in place. `HookQueueEye` deleted.
- **`CastBar.lua`** — `hooksecurefunc(PlayerCastingBarFrame, ...)` / `HookScript` calls replaced by `RegisterStateDriver(PlayerCastingBarFrame, "visibility", "hide")` with a combat-deferral path (`blizzBarPending` flag + `PLAYER_REGEN_ENABLED` handler).
- **`ObjectiveTracker.lua`** — 2317-line file deleted; functionality moved to a companion addon. `TrackerPanel.lua` likewise deleted. Tracker DB defaults removed from `Core.lua`.
- **`Misc.lua`** — New features added (death notification TTS cap `deathMaxCount`, whisper alert frame + TTS). Pending change adds `MAIL_SHOW` handler so `mailAlertShown` flag self-heals on mailbox open (today's edit). Also adds `UNIT_HEALTH` / `GROUP_ROSTER_UPDATE` handlers for death notifications.
- **`DamageMeter.lua`** — Pending changes: added `showTooltip` and `showIcons` settings, `ApplyRowIcon` / `ApplyRowTooltip` helpers, a drilldown-during-combat render path, and icon texture on each row. Matching panel checkboxes in `config/panels/DamageMeterPanel.lua`. New defaults added in `Core.lua`.
- **`games/Blocks.lua`** — New 1561-line multiplayer block-drop game file.
- **`config/ConfigMain.lua`**, **`config/panels/NotificationsPanel.lua`**, **`config/panels/AddonVersionsPanel.lua`** — UI adjustments for the new notification features and companion-tab handling.

Scope: all `.lua` files under the project root (top-level, `widgets/`, `games/`, `config/`), excluding `libs/`. Findings below reflect the post-commit and post-pending-change state and are verified by direct file reads.

## Critical (would cause errors or taint in-game)

### Frame-object `hooksecurefunc` / `HookScript` on Blizzard frames
- **TalentManager.lua:250** [STILL APPLIES] — `PlayerSpellsFrame:HookScript("OnShow", OnTalentFrameShow)` on a Blizzard frame. Taints the talent window. Replace with a global-form hook: `hooksecurefunc("ToggleTalentFrame", ...)` (or `EventRegistry:RegisterFrameEvent("PLAYER_TALENT_UPDATE")`), reading `PlayerSpellsFrame:IsShown()` to decide whether to show the addon panel.
- **TalentManager.lua:251** [STILL APPLIES] — `PlayerSpellsFrame:HookScript("OnHide", OnTalentFrameHide)` — same fix.
- **Combat.lua:1111** [NEW] — `hooksecurefunc(C_Container, "UseContainerItem", TryTrackContainerItem)` — frame-object form on the `C_Container` namespace table. `C_Container` is not a Frame (no Button prototype), but hooking onto the namespace can still taint the wrapped function. Lower severity than hooking a Frame's method, but safer to use the global `UseContainerItem` path (already present at line 1115) exclusively and drop the `C_Container` variant if both resolve to the same underlying function in 12.0. Verify at runtime whether dropping it loses any usage tracking before removing.

### Button parented to secure popup
- **Misc.lua:497** [STILL APPLIES] — `deleteButton:SetParent(dialog)` where `dialog` is a Blizzard `StaticPopup` resolved from `StaticPopup_Visible()` + `_G[dialogName]`. Addon-created Button writes itself into the StaticPopup's child list; subsequent `StaticPopup_Show` calls walk that list from protected code, pulling taint into Blizzard flow. Safer: parent `deleteButton` to `UIParent` and anchor to `editBox` via `SetPoint` without reparenting (SetPoint reads from the Blizzard frame; reparenting writes onto it).
- **Misc.lua:492** [NEW] — `button1:Click()` calls a Blizzard StaticPopup button's `:Click()` method from inside an addon OnClick handler. Click invokes Blizzard's secure click path which may error when the addon execution context is tainted. The preceding `editBox:SetText(DELETE_ITEM_CONFIRM_STRING)` is enough to enable button1 — consider relying on the user's own confirmation click instead of programmatically clicking the Blizzard button, which would both remove the taint risk and avoid accidentally skipping Blizzard's own guards.

### Combat-lockdown guard missing
- **Combat.lua:1419** [STILL APPLIES] — `UnregisterStateDriver(reminderFrame, "visibility")` inside `ApplyReminderEvents()`, which has no `InCombatLockdown()` guard. `reminderFrame` is a `SecureHandlerStateTemplate` — the call requires the combat guard even on an addon-owned frame. In practice the function is reached from settings panels (out of combat) and from the enable/disable toggle, but there is no structural guarantee — if a settings change fires during combat the call will fail. Add `if InCombatLockdown() then return end` at the top of `ApplyReminderEvents`, or defer the else-branch to `PLAYER_REGEN_ENABLED`.

## Warning (likely bugs or violations)

### Forward reference / missing local
- **games/Boxes.lua:1599** [STILL APPLIES] — `function UpdateHUD()` declared without `local`, leaking into `_G`. Calls at 1559, 1592, 1631 precede the definition lexically. Fix: forward-declare `local UpdateHUD` at the top of the file, then define as `UpdateHUD = function() ... end`.

### High-frequency event handlers
- **Misc.lua:224 `OnUnitHealth`** [NEW] — Registered against the raw `UNIT_HEALTH` event (EventBus does not filter by unit for this registration). `UNIT_HEALTH` fires for every unit in the group on every health tick — this is one of the highest-frequency events in WoW. The handler is cheap (pattern match on `unitTarget` and early return for non-party/raid), but it still runs `:match("^party%d+$")` twice on every single tick of every group member. Consider:
  1. Cache the two patterns as precompiled regex-free checks (e.g. `if unitTarget:sub(1,5) == "party" or unitTarget:sub(1,4) == "raid" then ...`),
  2. Or (better) register per-unit filtered `UNIT_HEALTH` via `RegisterUnitEvent("UNIT_HEALTH", "party1", "party2", ...)` plus a re-register on `GROUP_ROSTER_UPDATE` — far less dispatch volume. EventBus currently only offers `RegisterUnit` for a single unit; adding a variadic `RegisterUnits` would help if this pattern recurs elsewhere.
- **Misc.lua:262 `OnGroupRosterUpdate`** [NEW] — Allocates a fresh `present` table per call and iterates group members each time. `GROUP_ROSTER_UPDATE` fires at moderate frequency (join/leave/role changes), so not a hot path — acceptable. Early return when `deathAnnounced` is empty (line 263) is a good short-circuit.
- **Misc.lua:603 `OnUpdatePendingMail`** [STILL APPLIES] — Trivial guard: checks settings + `HasNewMail()` + flag; no leaks or cost concerns.
- **Misc.lua:612 `OnMailShowMisc`** [NEW, today's edit] — Single-line reset of `mailAlertShown = false`. Logic is correct: opening a mailbox is a natural point to reset stale alert state, complementing the existing `MAIL_CLOSED` reset. No leak risk; one function reference reused across register/unregister.

### Positioning coupling to Blizzard frames
- **TalentManager.lua:222-224** [STILL APPLIES] — `mainPanel:SetPoint("TOPLEFT", PlayerSpellsFrame, "TOPRIGHT", 2, 0)` anchors the addon panel to a Blizzard frame. Reading the Blizzard frame as an anchor target does not taint. Guarded — acceptable.

### Frame positioning not migrated to CENTER convention
- **Coordinates.lua, MplusTimer.lua, QueueTimer.lua, XpBar.lua, CastBar.lua, Kick.lua, MinimapCustom.lua** [STILL APPLIES] — Per CLAUDE.md these modules are tracked as "not yet migrated (dynamic GetPoint)". Position is saved as whatever anchor the user dragged from. Tracking item, not an immediate bug.

### Secret-value hygiene
- **DamageMeter.lua:336-395 `ApplyRowIcon`** [NEW] — Handles class-filename secret correctly: `mode == "class"` branch gates `CLASS_ICON_TCOORDS[data]` indexing on `not (issecretvalue and issecretvalue(data))` and `type(data) == "string"`. Good pattern. The player-spec branch calls `GetSpecialization()` / `GetSpecializationInfo()` — these return non-secret values for the local player. The spell branch uses `GetSpellTexture(spellID)`; the spellID here comes from post-combat `entry.spellId` (non-secret) or from the new live combat drilldown path at line 550 (`sp.spellID` pulled from `C_DamageMeter.GetCombatSessionSourceFromType`, which returns secret values during live combat). `GetSpellTexture` with a secret spellID may fail — consider gating the spell branch on `not issecretvalue(data)` for symmetry with the class branch.
- **DamageMeter.lua:548-592** [NEW] — Live combat drilldown path. Comments document that `srcMax = srcData.totalAmount` is kept as a direct local (secret value) and never stored in a table; passed through `SetMinMaxValues` / `SetValue` which accept secret numbers via C. The `pcall` wrap around `GetCombatSessionSourceFromType` is defensive. One concern: `sp.totalAmount` is iterated from `srcData.combatSpells`, and each `amt` value is then passed to `row.bar:SetValue(amt)` and `string.format("%d", amt)`. Arithmetic on secret values is allowed, but `string.format("%d", secret)` is not documented as safe in MEMORY.md — verify this doesn't throw "numeric conversion on secret number value" in live-combat testing. If it fails, the count-type path needs to use `tostring(sp.casts)` only (sp.casts is a direct number, not secret) and skip `%d`.
- **DamageMeter.lua:788** [NEW] — `UnitName("player") == entry.name` comparison in the post-combat render path. `UnitName("player")` returns the player's own name (not secret); `entry.name` is also post-combat-snapshotted by upstream code, so both sides are plain strings. Safe as long as the render path stays post-combat-only. Hoist the `UnitName("player")` call out of the per-row loop for clarity.
- **Kick.lua:233, 288** [STILL APPLIES] — `UnitName(unit)` / `UnitName("player")` without explicit combat guard. Add an `issecretvalue` short-circuit on the `UnitName(unit)` case.
- **TalentReminder.lua:227, 242** [STILL APPLIES] — Correctly uses `issecretvalue(unitTarget)` before `UnitName(unitTarget)` concatenation. Good pattern.
- **Misc.lua:227** [NEW] — `if not unitTarget or issecretvalue(unitTarget) then return end` at the top of `OnUnitHealth`. Correct — `unitTarget` can theoretically be secret on some unit events. Good defensive pattern.

### `COMBAT_LOG_EVENT_UNFILTERED`
None found — the codebase correctly avoids this event across all remaining files.

### Lua 5.1 compatibility
None found — no `\xNN` hex escapes, no bitwise operators, no `//`, no `goto`, no `<const>`/`<close>`. `games/Cards.lua:20-24` suit glyphs correctly encoded as `\226\153\165` etc.

## Minor (style, performance, clarity)

### Hot-path allocations
- **DamageMeter.lua:399-419 `ApplyRowTooltip`** [NEW] — Creates two new closure instances per row per render (OnEnter + OnLeave). For 10 rows rendered at ~1Hz, that's ~20 closures/sec when hovered. The `HideAllRows` clears the scripts on row release, so no leak. Consider moving the OnEnter/OnLeave bodies to file-scope functions that look up per-row tooltip state in a side-table keyed by the row frame, so only one function reference is ever set per script slot.
- **DamageMeter.lua:788** [NEW] — `UnitName("player")` called per row in the render loop. Hoist to a local before the loop.
- **games/Snek.lua:88** [STILL APPLIES] — `local colStr = r..","..g..","..b` creates a fresh string per tick.
- **games/Cards.lua:582-587** [STILL APPLIES] — Drag `OnUpdate` handler created fresh on each `dragFrame:SetScript("OnUpdate", function...)`. If once per drag-start, fine.
- **games/Bombs.lua:181-184** [STILL APPLIES] — Verify `if timerTicker then timerTicker:Cancel() end` runs on every path before reassignment.
- **widgets/Widgets.lua:70, 94** [STILL APPLIES] — `string.format("(%.0f, %.0f)", x, y)` during drag `OnUpdate`. Transient UI, acceptable.
- **games/Blocks.lua** [NEW, reviewed] — Uses a `bufBlocks` reusable block buffer (line 174 comment), a `oppFramePool` for opponent panels (line 153), and careful `:Cancel()` + `nil` reset on all tickers (`gravityTicker`, `flashTicker`, `watchdogTicker`, `promptTimer`, `inviteTimer`). Memory hygiene looks good.

### `HookScript` on addon-created frames (safe — not taint)
- **widgets/Speed.lua:51** — `speedFrame:HookScript("OnUpdate", ...)` on an addon-owned frame. No action.
- **games/Blocks.lua:1414** [NEW] — `gameFrame:HookScript("OnShow", RefreshBindings)` on addon-owned frame. Safe.
- **games/Snek.lua:514** — Same pattern. Safe.
- **Coordinates.lua:698** — `scrollFrame:HookScript("OnSizeChanged", ...)` — check whether `scrollFrame` is addon-owned. It is (created at Coordinates.lua CreateFrame calls). Safe.

### Global leaks / style
- **Misc.lua:413** — `SLASH_LUNAUIRELOAD1` / `SlashCmdList["LUNAUIRELOAD"]`. Must be globals — not a leak.
- **Core.lua:741-742** — `SLASH_UITHINGS1` / `SLASH_UITHINGS2`. Same.
- **games/Boxes.lua:1599** — (see Warning above) missing `local`.
- **config/Helpers.lua:26-33** [STILL APPLIES] — `DeepCopy()` lacks cycle detection. Add cycle guard before anyone ever deep-copies a frame reference.
- **config/Helpers.lua:447** [STILL APPLIES] — `CreateFont("LunaFontPreview_" .. i)` registers FontObjects globally by deterministic name. Low count. Acceptable.
- **config/ConfigMain.lua** [STILL APPLIES] — Repeated `if addonTable.X and addonTable.X.UpdateSettings then addonTable.X.UpdateSettings() end` pattern (~20 copies). Factor to a `SafeCallUpdateSettings(moduleKey)` helper. Still not done.

### Magic numbers
- **XpBar.lua:289** [STILL APPLIES] — `SetWidth(1)` as collapsed state. Name it.
- **games/Tiles.lua:255-256** [STILL APPLIES] — Hardcoded 1000-value font-switch threshold.
- **games/Bombs.lua:177, 218** [STILL APPLIES] — `0.3` gravity delay.
- **games/Blocks.lua:147-149** [NEW] — `OPPONENT_TIMEOUT = 4.0`, `WATCHDOG_INTERVAL = 1.0` — already named. Good.

### Correctly-flagged non-issues
- **config/panels/TrackerPanel.lua** — file was deleted in this commit. No longer applies.
- **Warehousing.lua:422-425** — `popupFrame` is addon-owned.
- **games/Snek.lua:231** — High-score write gated on new-high, not per-tick.
- **games/Boxes.lua:1559** — Real concern is the missing `local`.

### Style
- **TalentReminder.lua:76** [STILL APPLIES] — Prefer `string.format` over `"Migrated " .. migrated .. " talent builds"`.
- **TalentManager.lua:813** [STILL APPLIES] — `C_Traits.GenerateImportString(configID)` result used without `if exportString then` nil-check.
- **TalentReminder.lua:1343** [STILL APPLIES] — `GetTalentName` dereferences `C_Traits` without the guard present elsewhere.
- **Warehousing.lua:702, 1010** [STILL APPLIES] — Mismatched-looking `end -- classID ~= 7` comments.

## Summary

**Fixed since 2026-04-16:**
- `MinimapCustom.lua` QueueStatusButton hooks → 2s polling ticker (previously fixed in the 04-16 pass; confirmed clean in current code).
- `CastBar.lua` `PlayerCastingBarFrame` frame-object hooks → `RegisterStateDriver` with combat-deferral (previously fixed; confirmed clean).
- `ObjectiveTracker.lua` — entire module removed from the addon (moved to a companion addon). All 2317 lines and its frame-object hook on `ObjectiveTrackerFrame:Show` are gone.

**New this review:**
- **Critical:** `Combat.lua:1111` hook on `C_Container` namespace — medium-severity, non-Frame hook; monitor.
- **Critical:** `Misc.lua:492` `button1:Click()` invoked from addon OnClick inside a Blizzard StaticPopup dialog — potential taint propagation path.
- **Warning:** `Misc.lua:224` `OnUnitHealth` registered against the unfiltered `UNIT_HEALTH` event — high-frequency handler; consider per-unit filtering via `RegisterUnitEvent` variadic or a pattern-free unit-token check.
- **Minor:** `DamageMeter.lua:788` hoist `UnitName("player")` out of per-row loop.
- **Minor:** `DamageMeter.lua:399-419` per-render closure allocation in `ApplyRowTooltip`.
- **Minor:** `DamageMeter.lua:375-384` spell branch of `ApplyRowIcon` should gate on `issecretvalue(data)` for symmetry with class branch.
- **Minor:** `DamageMeter.lua:548-592` verify `string.format("%d", amt)` works with secret numbers in live combat (if not, restrict to count-type with `tostring` only).

**Remaining from last review:**
- `TalentManager.lua:250-251` `PlayerSpellsFrame:HookScript` (critical).
- `Misc.lua:497` `deleteButton:SetParent(dialog)` (critical).
- `Combat.lua:1419` missing `InCombatLockdown()` guard on `UnregisterStateDriver`.
- `games/Boxes.lua:1599` `UpdateHUD` missing `local`.
- CENTER-anchor migration for `XpBar`, `CastBar`, `Combat`, `Kick`, `MinimapCustom`, `Coordinates`, `MplusTimer`, `QueueTimer`.
- `Kick.lua:233, 288` — add `issecretvalue` guards on `UnitName(unit)` calls.
- `config/ConfigMain.lua` — factor the repeated `UpdateSettings` pattern.
- Various magic-number constants and minor style items.

Today's `Misc.lua` edit (adding `MAIL_SHOW` to reset `mailAlertShown`) is correct and clean: single-line reset with symmetric register/unregister across both the feature-enabled branch and the master-disable branch. No leaks, no taint, no concerns.
