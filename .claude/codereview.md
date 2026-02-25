# LunaUITweaks -- Comprehensive Code Review

**Review Date:** 2026-02-25 (Twenty-First Pass -- Games rotation fix + Damage Meter tab shown)
**Previous Review:** 2026-02-24 (Twentieth Pass -- Trivial fixes batch)
**Scope:** J/L tetromino rotation data corrected in Blocks.lua. Damage Meter tab unhidden in ConfigMain.lua. Games combat/pause system reviewed (CloseGame mutual exclusivity, pause overlays, InCombatLockdown guards).
**Focus:** Bugs/crash risks, performance issues, memory leaks, race conditions/timing issues, code correctness, saved variable corruption risks, combat lockdown safety

---

## Changes Since Last Review (Twenty-First Pass -- 2026-02-25)

### Confirmed Fixed Since Twentieth Pass

| Issue | Fix |
|-------|-----|
| `games/Blocks.lua` J piece (blue) rotation corners reflected on wrong row axis | R0 corner changed `{-1,1}` → `{-1,-1}` (top-left), R2 changed `{1,-1}` → `{1,1}` (bottom-right). All four rotations now cycle correctly: top-left → top-right → bottom-right → bottom-left. |
| `games/Blocks.lua` L piece (orange) rotations 1 and 3 had corner on wrong side | R1 corner changed `{1,1}` → `{-1,1}` (bottom-left), R3 changed `{-1,-1}` → `{1,-1}` (top-right). L now mirrors J correctly through all four rotations. |
| `config/ConfigMain.lua` Damage Meter tab hidden with `navButtons[24]:Hide()` | Line removed. Damage Meter tab now visible in the config sidebar. |

### Verified Correct (Twenty-First Pass)

- **`games/Blocks.lua` PIECES[6] J rotations** (lines 80-85): After fix, R0=top-left `{-1,-1}`, R1=top-right `{1,-1}`, R2=bottom-right `{1,1}`, R3=bottom-left `{-1,1}`. Correct standard Tetris J clockwise rotation sequence.
- **`games/Blocks.lua` PIECES[7] L rotations** (lines 87-92): After fix, R0=bottom-right `{1,1}`, R1=bottom-left `{-1,1}`, R2=top-left `{-1,-1}`, R3=top-right `{1,-1}`. Correct standard Tetris L clockwise rotation sequence.
- **`games/Blocks.lua` CloseGame / ShowGame mutual exclusivity**: `CloseGame()` at line 1522 correctly cancels gravity/flash tickers and handles MP cleanup. `ShowGame()` closes Snek and Game2048 before opening. Pattern correct.
- **`games/Snek.lua` combat/pause handling**: `PLAYER_REGEN_DISABLED` pauses without keyboard disable (keybinds are global, not frame-captured). `TogglePause()` guarded with `InCombatLockdown()`. `PLAYER_REGEN_ENABLED` is a no-op (manual unpause). Pause overlay frame with dark bg is correct.
- **`games/Tiles.lua` combat/pause handling**: `combatPaused` flag blocks `OnKey` handler. `PLAYER_REGEN_ENABLED` auto-resumes (Tiles uses keybinds but auto-unpause is intentional). Global keybind wrappers at end of file chain to Snek's wrappers. Correct.
- **`games/Tiles.lua` CloseGame / ShowGame**: `CloseGame()` at line 575 hides frame. `ShowGame()` closes Blocks and Snek before opening. No timer to cancel (Tiles has no game tick). Correct.

### New Findings (Twenty-First Pass)

| Severity | Issue | File | Notes |
|----------|-------|------|-------|
| Low | `games/Blocks.lua` S piece (green) and Z piece (red) each have only 2 unique rotation states (R0==R2, R1==R3) — standard for S/Z tetrominoes. No bug, just confirming intentional design. | Blocks.lua:65-78 | Correct per standard Tetris S/Z behavior. |
| Low | `games/Snek.lua` `CloseGame()` sets `gameActive = false` but does not reset `gamePaused`. If the game was paused when closed and then re-opened via `ShowGame()`, `StartGame()` is called which resets `gamePaused = false` internally — so functionally fine, but the `CloseGame()` not resetting `gamePaused` is a minor inconsistency. | Snek.lua:579-585 | Harmless — `StartGame()` always resets game state including `gamePaused`. |
| Low | `games/Tiles.lua` global keybind wrappers at the end of the file wrap Snek's wrappers (`LunaUITweaks_Game_Left` etc.) which already wrap Core's originals. This creates a 3-deep wrapper chain (Core → Snek → Tiles). Adding more keybind-sharing games would deepen the chain further. | Tiles.lua | Functionally correct. Consider a dispatcher table in Core if more games are added. |
| Low | `games/Blocks.lua` keybind definitions (lines 1555-1561) define the globals from scratch without capturing any previous value. If a future game is added to the TOC before Blocks and also defines these globals, Blocks would silently overwrite them. Current TOC order `Blocks → Snek → Tiles` means Blocks always loads first and legitimately bootstraps the chain, but this fragility should be noted. | Blocks.lua:1555-1561 | Low risk with current game set. Blocks is the intended chain root. |

---

## Changes Since Last Review (Twentieth Pass -- 2026-02-24)

### Confirmed Fixed Since Nineteenth Pass

| Issue | Fix |
|-------|-----|
| `MinimapCustom.lua` `GetMinimapShape` returned nil for round minimap (issue 60) | Changed `GetMinimapShape = nil` to `function GetMinimapShape() return "ROUND" end`. |
| `MinimapCustom.lua` `AnchorQueueEyeToMinimap` called `SetParent` without combat guard (issue 22) | Added `if InCombatLockdown() then return end` as third guard after nil checks. |
| `Vault.lua` / `WeeklyReset.lua` `ShowUIPanel` called without combat guard (issue 26) | Both `OnClick` handlers changed to `if button == "LeftButton" and not InCombatLockdown() then`. |
| `config/panels/LootPanel.lua` bare `addonTable.Loot.UpdateSettings()` calls (issue 34) | Added `local LootUpdateSettings()` wrapper with nil guard at file scope; all 8 bare calls replaced. `VendorPanel.lua` was already guarded — no change needed. |
| `config/panels/AddonVersionsPanel.lua` `loadstring` with no input length check (issue 36) | Added `if #str > 65536 then return nil, "Input too large" end` before `loadstring` call. |
| `Combat.lua` `ApplyReminderLock()` called three times (issue 55) | Removed the redundant second call at end of `UpdateReminderFrame()`. First call (after `ApplyReminderFont`) and third call (in `InitReminders`) remain correct. |
| `MinimapCustom.lua` `clockTicker` / `coordsTicker` never cancelled on re-init (issue 62) | Both variables promoted to module-level. `SetupMinimap()` now cancels and nils both at entry before creating new ones. |
| `GetCharacterKey()` duplicated in 3 files (issue 15/16) | Added `addonTable.Core.GetCharacterKey()` to `Core.lua` (cached after first call). Removed local definitions from `Reagents.lua`, `Warehousing.lua`, and `widgets/Bags.lua`. Each now uses a thin alias. |
| `Warehousing.lua` `CalculateOverflowDeficit` stale bag state (issue 14) | Auto-continuation now waits for `BAG_UPDATE_DELAYED` event (with 3s `NewTicker` fallback) before re-calling `CalculateOverflowDeficit`, ensuring bag contents have settled. |

### Verified Correct (Twentieth Pass)

- **`Combat.lua` comment "Create 4 text lines"** (line 1113): Already reads "Create 5 text lines". No change needed.
- **`ObjectiveTracker.lua` `OnAchieveClick` type guard** (issue 64): `and self.achieID` guard already present on both click branches. No change needed.
- **`MythicRating.lua` nil `bestRunLevel`** (issue 19): `if timedLevel then` / `elseif bestLevel then` branches correctly guard all `string.format` calls. No change needed.
- **`VendorPanel.lua` module access** (issue 34): Already uses `if addonTable.Vendor.UpdateSettings then` guards throughout. No change needed.

---

## Changes Since Last Review (Nineteenth Pass -- 2026-02-24)

### Confirmed Fixed Since Eighteenth Pass

| Issue | Fix |
|-------|-----|
| `ObjectiveTracker.lua` lines 1597, 1924, 2162: Three `C_Timer.After` calls bypassed the module-level `local SafeAfter` alias | Changed all three to `SafeAfter(...)`. File already declared `local SafeAfter = addonTable.Core.SafeAfter` at line 70 and used it everywhere else — these were inconsistent outliers. |
| `Coordinates.lua` / `WaypointDistance.lua` distance helpers duplicated (`MapPosToWorld`, `GetDistanceToWP`, `FormatDistanceShort`) | `GetDistanceToWP` and `FormatDistanceShort` exposed on `addonTable.Coordinates`. `WaypointDistance.lua` drops its duplicate definitions and reads from `Coordinates.GetDistanceToWP` / `Coordinates.FormatDistanceShort`. `MapPosToWorld` stays private as an implementation detail. |
| `Coordinates.lua` `C_Timer.NewTicker(2, ...)` created unconditionally in `CreateMainFrame`, ran forever even when module disabled | Ticker removed from `CreateMainFrame`. Stored in module-level `distanceTicker`. Created in `UpdateSettings` when `enabled = true`, cancelled and nilled when `enabled = false`. |

### New Findings (Nineteenth Pass -- 2026-02-24)

No new bugs or crashes found this pass. One additional low-priority polish item noted:

| Severity | Issue | File | Notes |
|----------|-------|------|-------|
| Low | `Combat.lua` init block (lines 1214–1218): `elseif C_Timer and C_Timer.After then` branch is dead code. `addonTable.Core.SafeAfter` is always available because Core.lua loads first per TOC order. The `if addonTable.Core.SafeAfter` branch always wins. | Combat.lua:1214 | Harmless but dead. Could simplify to a single `addonTable.Core.SafeAfter` call without the elseif fallback. Same dead-code structure exists in `CastBar.lua:574–576`. |

### Verified Correct (Nineteenth Pass)

- **ObjectiveTracker.lua `ScheduleUpdateContent`** (line 1597): `SafeAfter(UPDATE_THROTTLE_DELAY, ...)` now uses the local alias. The throttle/guard logic (`if updatePending then return end`) is correct.
- **ObjectiveTracker.lua `PLAYER_ENTERING_WORLD`** (line 1924): `SafeAfter(2, UpdateContent)` now uses the local alias. The 2-second delay gives Blizzard time to finish its own tracker layout.
- **ObjectiveTracker.lua `PLAYER_ENTERING_WORLD` settings apply** (line 2162): `SafeAfter(1, function() addonTable.ObjectiveTracker.UpdateSettings() end)` now uses the local alias. Correct.

---

## Changes Since Last Review (Eighteenth Pass -- 2026-02-24)

### Confirmed Fixed Since Seventeenth Pass

| Issue | Fix |
|-------|-----|
| `Cards.lua` dragFrame `OnUpdate` always registered, firing every frame even when idle | `OnUpdate` now registered in `StartDrag` and unregistered (`nil`) in `CommitDrag` and `CancelDrag`. Zero per-frame cost when not dragging. |
| `Cards.lua` full board rebuild (`LayoutCards`) called on every click including selection-only changes | `RefreshHighlights()` added — only updates highlight textures on visible face-up cards. All selection-only paths in `HandleClick` now call `RefreshHighlights()` instead of `LayoutCards()`. |
| `Bombs.lua` flood-fill queue allocates a new `{r, c}` table per cell | Queue now uses flat interleaved pairs: `revealQueue[2k-1] = row`, `revealQueue[2k] = col`. `head`/`tail` advance by 2. Zero table allocation during flood-fill. |
| `Cards.lua` `HitTestZones` returns nil over face-down card regions (silent drop failures) | Now checks full column vertical extent. When cursor is over a face-down card, falls back to the last face-up card in that column. All-face-down column correctly returns nil. |
| `Bombs.lua` `cells` undeclared — implicit global `_G.cells` | `local cells` added to module-level state block alongside `cellState`, `cellMine`, `cellCount`. |

### New Findings (Eighteenth Pass -- 2026-02-24)

| Severity | Issue | File | Notes |
|----------|-------|------|-------|
| Low | `Gems.lua` `TickGravity` and `Cards.lua` `LayoutCards` / `HandleClick` / `MoveCards` / `IsValidMove` / `SwapGems` forward-declared as upvalues but lack `local` on their definition lines. In Lua 5.1 this is fine since the `local` was declared on the forward-declaration line, but the assignment lines have no `local` prefix, which is correct Lua — just slightly confusing to read. No functional issue. | Gems.lua:182, Cards.lua:53,263 | Correct Lua semantics. Style observation only. |
| Low | `Cards.lua` `RefreshHighlights` updates `movesText` on every call (line 153). This means the moves counter is refreshed on selection changes even though `moves` hasn't changed. Harmless but redundant work — `movesText` does not need updating unless `moves` changes. | Cards.lua:153 | Move `movesText:SetText(...)` out of `RefreshHighlights` and only call it where `moves` increments (`DrawCard`, `MoveCards`). |
| Low | `Cards.lua` `LayoutCards` inner function `GetFrame` (line 284) closes over and increments `fIdx` before reading it: `fIdx = fIdx + 1; f:SetFrameLevel(baseLevel + fIdx)`. This means the first frame gets level `baseLevel + 2`, not `baseLevel + 1`. Off-by-one in frame levels — functionally harmless since levels are only used for z-ordering within the card pool. | Cards.lua:284-287 | Minor. Move `fIdx = fIdx + 1` to after the `SetFrameLevel` call, or use `fIdx` before incrementing. |

### Verified Correct (Eighteenth Pass)

- **Flat flood-fill queue** (`Bombs.lua:199-229`): `head = 1, tail = 2` initialization is correct. First iteration reads `[1]` and `[2]`, increments head to 3. `tail` incremented by 2 before assignment so `[tail-1]` and `[tail]` are the new pair. Verified correct.
- **`local cells` declaration** (`Bombs.lua:28`): Properly in scope for `UpdateCell`, `ResizeBoard`, and `StartGame`. `cells = {}` inside `ResizeBoard` correctly assigns to the module-local. Verified correct.
- **`RefreshHighlights` loop** (`Cards.lua:142-154`): Correctly skips hidden frames and frames without `cardData.id` (placeholders). Selection comparison `selLoc.cardData == f.cardData` (identity check) is correct since card data tables are the same objects used in `waste`/`foundations`/`tableau`. Verified correct.
- **`HitTestZones` column bounds** (`Cards.lua:239-270`): `topOfColumn = startY`, `bottomOfColumn = startY - ((lastRow-1)*STACK_Y) - CARD_H` correctly spans the full visual extent including the last card's full height. Face-down fallback iterates `lastRow → 1` and returns the deepest face-up card. Verified correct.

---

## Changes Since Last Review (Seventeenth Pass -- 2026-02-23)

### Confirmed Fixed Since Sixteenth Pass

| Issue | Fix |
|-------|-----|
| Warehousing "Sync complete!" shown when 5-pass limit hit with overflow remaining | Changed the `continuationPass >= 5` branch message to `"Sync limit reached — overflow may remain."` |
| `Coordinates.lua` `ResolveZoneName` partial match non-deterministic | Replaced `pairs` first-match with shortest-name-wins: iterates all matches, returns the one with the shortest cached name (most specific). |
| `Friends.lua` BNet `gameAccount.className` (localized) passed to `GetClassColor` | Changed to `gameAccount.classFileName` (English token) to match the WoW Friends section which already used `classFilename`. |
| `MinimapCustom.lua` `SetDrawerCollapsed` no `InCombatLockdown()` guard | Added `if InCombatLockdown() then return end` at top of function to prevent hiding/showing potentially protected minimap buttons during combat. |

### Verified Already Safe (Seventeenth Pass)

- **`MythicRating.lua` nil `bestRunLevel`** — Code review referenced "lines 85, 94" but reading the actual code, `bestLevel` is a local variable set from `intimeInfo.level`/`overtimeInfo.level` with nil guards. The `string.format` calls at lines 99/102 only execute inside `if timedLevel then` / `elseif bestLevel then` branches. No nil crash path exists. No change needed.

---

## Changes Since Last Review (Sixteenth Pass -- 2026-02-23)

### Confirmed Fixed Since Fifteenth Pass

| Issue | Fix |
|-------|-----|
| `WaypointDistance.lua` `FormatDistance` dead `else` branch | Removed redundant `else` — `>= 1000` already handled above, `else` was identical to the fallthrough. |
| `Durability.lua` unconditional event registration | Added `ApplyEvents(enabled)` function with proper `EventBus.Register`/`Unregister` for `MERCHANT_SHOW`, `MERCHANT_CLOSED`, `UPDATE_INVENTORY_DURABILITY`. Events now only fire when widget is enabled. |
| `AddonComm` widget `GetGroupSize()` overcounts party by 1 | Collapsed duplicate `IsInRaid`/`IsInGroup` branches — both called `GetNumGroupMembers()` identically. Now a single `IsInGroup()` check. `GetNumGroupMembers()` returns inclusive count in all group types. |
| `TalentReminder.ReleaseAlertFrame()` not clearing `currentMismatches` | Added `alertFrame.currentMismatches = nil` alongside existing `alertFrame.currentReminder = nil`. |
| `Vers.lua` widget showing only offensive versatility | `Refresh()` now reads both `CR_VERSATILITY_DAMAGE_DONE` and `CR_VERSATILITY_DAMAGE_TAKEN`, displays as `"Vers: X.X% / Y.Y%"` — consistent with tooltip. |
| `StaticPopupDialogs["LUNA_WAREHOUSING_AUTOBUY_CONFIRM"]` redefined per `RunAutoBuy` call | Moved definition to file scope with `text = "%s"`. `RunAutoBuy` now only sets `OnAccept` and passes the formatted string as the format arg to `StaticPopup_Show`. |

### Verified Already Fixed (Sixteenth Pass)

- **`Misc.lua` `HookTooltipSpellID` forward declaration** — Confirmed `local HookTooltipSpellID -- forward declaration` already present at line 303 from a prior session. No change needed.
- **`Combat.lua` comment "Create 4 text lines"** — Confirmed already reads "Create 5 text lines" at line 1115 from a prior session. No change needed.

---

## Changes Since Last Review (Fifteenth Pass -- 2026-02-23)

### Confirmed Fixed Since Fourteenth Pass

| Issue | Fix |
|-------|-----|
| `GetMerchantItemInfo` nil error when opening vendor | Migrated to `C_MerchantFrame.GetItemInfo(i)` returning `info.name`, `info.price`, `info.stackCount` struct fields. `GetMerchantNumItems()` and `BuyMerchantItem()` remain as valid globals. |
| `goto continue` Lua 5.1 syntax error in `RunAutoBuy` | Replaced `goto`/label pattern with `if needed > 0 then` block — Lua 5.1 does not support `goto`. |
| Reagent tooltip counts not updating after selling items | Added `and not info.isLocked` guard to all four scan functions: `GetLiveBagCount`, `ScanBags`, `ScanCharacterBank`, `ScanWarbandBank`. Locked slots (items mid-transaction) are now excluded from counts. |

### New Features Added Since Fourteenth Pass

**Auto-Buy Vendor Mats (Warehousing.lua + WarehousingPanel.lua + Core.lua):**
- `FindOnMerchant(itemID)` — scans current vendor using `C_MerchantFrame.GetItemInfo` + name matching for quality-tier variants
- `Warehousing.RegisterVendorItem(itemID)` — registers vendor price/name when toggling autoBuy while merchant is open
- `RunAutoBuy()` — calculates deficit, subtracts warband bank cached stock, respects gold reserve, buys or shows confirm popup
- `Warehousing.MerchantHasAutoBuyItems()` / `Warehousing.IsAtMerchant()` — state queries
- `MERCHANT_SHOW` / `MERCHANT_CLOSED` event handlers
- New defaults in Core.lua: `autoBuyEnabled = true`, `goldReserve = 500`, `confirmAbove = 100`
- Auto-Buy Settings section in WarehousingPanel with enable checkbox, gold reserve editbox, confirm threshold editbox
- Buy toggle button column in tracked items list with per-button tooltip showing vendor name, price, status

### New Findings (Fifteenth Pass -- 2026-02-23)

| Severity | Issue | File | Notes |
|----------|-------|------|-------|
| Low | `RunAutoBuy` warband bank name-lookup calls `C_Item.GetItemNameByID(wbID)` for every warband bank item on every merchant open, even for the exact-ID hit case | Warehousing.lua:1286-1291 | The name fallback loop only runs when `warbandHas == 0` (exact ID miss), so it's not a hot path. However `C_Item.GetItemNameByID` may trigger async item data loads. Low impact in practice. |
| Low | `RunAutoBuy` uses `confirmAbove = 0` as "always confirm" but the logic is `totalCost > confirmAbove`, so setting confirmAbove to 0 means any purchase > 0 copper confirms — correct, but the UI label "0 = always confirm" is slightly misleading since a 0-copper purchase (impossible in practice) would not confirm | Warehousing.lua:1328 | Documentation/UX issue only. No code bug. |
| Low | `OnMerchantShow` fires `RunAutoBuy` after 0.3s delay. If the merchant is closed within 0.3s (rapid open/close), `RunAutoBuy` runs with `atMerchant = false` from `OnMerchantClosed`. The `if not atMerchant` guard in `RunAutoBuy` via `FindOnMerchant` (which checks `atMerchant`) would correctly abort. | Warehousing.lua | Correctly handled. Noted for clarity. |
| Low | `WarehousingPanel` Buy button `OnEnter` tooltip calls `GetCoinTextureString(item.vendorPrice)` — if `vendorPrice` is nil (autoBuy flagged but no merchant registered yet), this will error | WarehousingPanel.lua:556 | `item.vendorPrice` is only shown when `item.autoBuy` is true AND `item.vendorName` is set. The nil path is guarded by `if item.vendorPrice then` at line 555. Correctly handled. |
| ~~Low~~ | ~~`Misc.lua` `HookTooltipSpellID` not forward-declared~~ | Misc.lua | **FIXED (Sixteenth Pass)** — `local HookTooltipSpellID` forward declaration confirmed present at line 303. |
| ~~Low~~ | ~~`StaticPopupDialogs["LUNA_WAREHOUSING_AUTOBUY_CONFIRM"]` redefined inside `RunAutoBuy` on every call~~ | Warehousing.lua | **FIXED (Sixteenth Pass)** — Moved to file scope; `RunAutoBuy` only sets `OnAccept` and passes text as format arg. |

### Verified Correct (Fifteenth Pass)

- **`C_MerchantFrame.GetItemInfo` migration** (Warehousing.lua:1218): Returns a `MerchantItemInfo` struct. Fields `info.name`, `info.price`, `info.stackCount` are correct per API docs. `GetMerchantNumItems()` and `BuyMerchantItem()` remain valid globals not yet moved to `C_MerchantFrame`.
- **`isLocked` guard in all four scan functions** (Reagents.lua): `GetLiveBagCount` (line 267), `ScanBags` (line 83), `ScanCharacterBank` (lines 101, 113, 124), `ScanWarbandBank` (line 152) — all correctly exclude `info.isLocked == true` slots.
- **Warband bank deficit reduction** (Warehousing.lua:1270-1292): Reads `LunaUITweaks_ReagentData.warband.items` (keyed by itemID from last bank visit scan). Falls back to name matching for quality-tier ID variants. `math.max(0, data.count - warbandHas)` correctly floors at 0. `if needed > 0 then` correctly skips items fully covered by warband stock.
- **Auto-Buy Settings UI** (WarehousingPanel.lua:101-172): Three controls correctly wired — checkbox writes `autoBuyEnabled`, gold reserve editbox writes `goldReserve` (with `OnEnterPressed`/`OnEscapePressed`), confirm editbox writes `confirmAbove`. Layout at -190/-215/-245/-273 provides adequate spacing.
- **`WidgetsPanel.lua` `CONDITIONS` table** — Confirmed defined OUTSIDE the `for i, widget` loop (line 222). Previously flagged as inside the loop; **FIXED** in a prior session.
- **`WidgetsPanel.lua` `GetConditionLabel`** — Confirmed defined OUTSIDE the loop (line 232). **FIXED** in a prior session.
- **`ConfigMain.lua` module 22 `RefreshWarehousingList`** — Confirmed present at lines 407-409 in `SelectModule`. **FIXED** in a prior session.
- **`Friends.lua` `classFilename`** — Confirmed uses `info.classFilename` (line 22). **FIXED** in a prior session.
- **`XPRep.lua` `ToggleCharacter` combat guard** — Confirmed `not InCombatLockdown()` guard present (line 233). **FIXED** in a prior session.

---

## Changes Since Last Review (Fourteenth Pass -- 2026-02-23)

### Confirmed Fixed Since Thirteenth Pass

| Issue | Fix |
|-------|-----|
| `/way` command not working (TomTom override) | `HookChatEditBoxes()` hooks `OnKeyDown` on all chat editboxes. `SetPropagateKeyboardInput(false)` on Enter with `/way` text swallows the keypress before TomTom's `OnEnterPressed` fires. `wayHooked` flag and `PLAYER_LOGIN` deferral ensure single registration. |
| Duplicate waypoints via `/lway` or paste | `AddWaypoint` now checks all existing waypoints with `mapID` equality + `math.abs(x-x2) < 0.001` epsilon before inserting. |

### New Findings (Fourteenth Pass -- 2026-02-23)

| Severity | Issue | File | Notes |
|----------|-------|------|-------|
| Low | `HookChatEditBoxes` only hooks the 10 default chat frames (`ChatFrame1EditBox`–`ChatFrame10EditBox`). Addon-created chat frames are not hooked. | Coordinates.lua:775 | Acceptable limitation for most users. Would need `CHAT_FRAME_ADDED` event or frame enumeration to handle addon chat windows. |
| Low | `GetLiveBagCount` rebuilds its own `bagList` table on every tooltip hover | Reagents.lua:254 | Same allocation pattern as `ScanBags`. Minor GC pressure on frequent tooltip use. |
| Low | `StaticPopupDialogs["LUNA_CHAR_REGISTRY_DELETE"]` redefined inside `OnClick` on every click (to include dynamic character name in text) | ReagentsPanel.lua:220 | Works correctly but inconsistent with Warehousing's single-definition pattern. Could use a module-level dialog with a `text` callback function. |
| Low | `GetClassRGB` defined locally in both `ReagentsPanel.lua` (line ~74) and `Reagents.lua` (line 243) | Both files | Identical helper duplicated. Could be shared via `addonTable.Reagents.GetClassRGB` or `Helpers`. |
| Low | `Coordinates.lua` `RefreshList` creates new `OnClick`/`deleteBtn:SetScript` closures per row on every refresh | Coordinates.lua:389-401 | `row.wpIndex` is already stored at line 378 — handlers could read from `self.wpIndex`/`self:GetParent().wpData` instead of capturing `i`/`wp` via closure, saving N closure allocations per refresh. |

### Verified Correct (Fourteenth Pass)

- **`ShouldTrackItem(itemID, isBound)`** (Reagents.lua:64): Correctly calls `IsReagent(itemID)` first (always track), then `UIThingsDB.reagents.trackAllItems and not isBound` as fallback. All three scan functions updated.
- **Tooltip hook** (Reagents.lua:358): `if not IsReagent(itemID) and not UIThingsDB.reagents.trackAllItems then return end` correctly gates display for non-reagents when setting is off.
- **`trackAllItems` default** (Core.lua): `reagents = { enabled = false, trackAllItems = false }` — correct.
- **ReagentsPanel column headers**: x=25/195/315/395 match row column offsets (LEFT+5, LEFT+175, LEFT+295, LEFT+375 inside scroll at x=20). Correct.
- **`trackAllBtn` checkbox**: Correctly writes `UIThingsDB.reagents.trackAllItems` and calls `UpdateSettings()`. Correct.

---

## Changes Since Last Review (Thirteenth Pass -- 2026-02-22)

### Confirmed Fixed Since Twelfth Pass

None. No files were changed between the Twelfth and Thirteenth passes (no new commits touching the reviewed files). All Twelfth Pass fixes remain in place.

### Re-Verified Open Issues (Still Open)

The following issues from the Twelfth Pass were re-read and confirmed still present:

| Issue | File | Location | Status |
|-------|------|----------|--------|
| `HookTooltipSpellID` not forward-declared | Misc.lua | Line 318 calls it; defined at line 434 as bare assignment (no `local` declaration) | Still open. `local HookTooltipClassColors` is forward-declared at line 302; `HookTooltipSpellID` is not. |
| `C_Timer.NewTicker(2, ...)` never cancelled | Coordinates.lua | Line 664 | Still open. Ticker result not stored; runs forever even when module disabled. |
| Distance helpers duplicated | Coordinates.lua + widgets/WaypointDistance.lua | Lines 66-107 (Coordinates) | Still open. `MapPosToWorld`, `GetDistanceToWP`, `FormatDistanceShort` are near-identical in both files. |
| `ResolveZoneName` partial match unordered | Coordinates.lua | Lines 54-58 | Still open. `pairs` iteration is non-deterministic for ambiguous names. |
| `GetCharacterKey()` duplicated | Warehousing.lua:38, Reagents.lua:25 | Both files | Still open. Both define identical local functions. Core.lua does not expose a shared version. |
| `WaitForItemUnlock` polling unreliable | Warehousing.lua | Line 837 | Still open. |
| `CalculateOverflowDeficit` calls `ScanBags()` synchronously | Warehousing.lua | Line 306 | Still open. |
| `bagList` rebuilt per `ScanBags()` call | Warehousing.lua | Lines 156, 360, 401 | Still open. Three separate allocation sites. |
| `GetCharacterNames()` not using `CharacterRegistry` | Warehousing.lua | Lines 54-68 | Still open. Iterates `LunaUITweaks_WarehousingData.characters` directly; alts known only via Reagents do not appear in mail dropdown. |
| `SelectModule` id=22 missing refresh call | config/ConfigMain.lua | Lines 397-406 | Still open. Module 22 (Warehousing) has no `addonTable.Config.RefreshWarehousingList()` call in `SelectModule`, despite `RefreshWarehousingList` being stored at WarehousingPanel.lua line 529. Pattern used by ids 2, 17, 19 is not applied to 22. |
| EventBus snapshot table allocation per dispatch | EventBus.lua | Lines 18-20 | Still open. A new `snapshot` table is allocated on every event dispatch. |
| Reagents.lua `ScanCharacterBank` legacy IDs | Reagents.lua | Bank scan section | Still open. |

### New Findings (Thirteenth Pass -- 2026-02-22)

No new bugs or issues found in this pass. The codebase is stable with respect to the files reviewed.

One observation worth noting for clarity:

| Severity | Issue | File | Notes |
|----------|-------|------|-------|
| Low | `WarehousingPanel.lua` `OpenCharPicker` position clamping uses `select(5, popup:GetPoint())` after `ClearAllPoints()` | WarehousingPanel.lua:276 | `popup:ClearAllPoints()` is called at line 272, then immediately `popup:SetPoint(...)` at line 273, then `select(5, popup:GetPoint())` at line 276 to read back the Y. After a `SetPoint` call, `GetPoint()` on an anchored frame returns correct values in WoW's API only if the frame's position has been committed to the layout engine. In practice this works but is fragile — the read-back at line 276 occurs before any layout pass, so the screen Y is computed from the anchor parameters rather than the rendered position. On very large popup frames this may produce slightly incorrect screen-clamp behavior. |

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

### Issue Counts (Seventeenth Pass)

**Critical Issues:** 0 (unchanged)
**High Priority:** 0 (unchanged)
**Medium Priority:** ~31 total (2 fixed: Friends.lua class name, MinimapCustom SetDrawerCollapsed)
**Low Priority / Polish:** ~34 total (2 fixed: Warehousing sync limit message, Coordinates ResolveZoneName ordering)

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

### Warehousing.lua (~1,400 lines)

**Status:** Functional. Two medium issues remain. Five low issues.

- **FIXED: Mail dialog self-filter bug.** `destPlain = dest:match("^(.+) %(you%)$") or dest` now correctly strips the stored `" (you)"` suffix.
- **FIXED: `GetMerchantItemInfo` nil error.** Migrated to `C_MerchantFrame.GetItemInfo(i)` with struct field access.
- **FIXED: `goto continue` Lua 5.1 syntax error.** Replaced with `if needed > 0 then` block.
- **NEW: Auto-buy feature.** `FindOnMerchant`, `RegisterVendorItem`, `RunAutoBuy`, `MerchantHasAutoBuyItems`, `IsAtMerchant` added. `MERCHANT_SHOW`/`MERCHANT_CLOSED` events registered. Warband bank cached counts subtracted from deficit before calculating purchase quantity. Gold reserve and confirm threshold respected.
- **NEW: isLocked fix.** All scan functions now skip locked bag slots.
- **Medium: `WaitForItemUnlock` polling unreliable for warband bank.** Polls `isLocked` at 0.1s intervals. Retry logic (3 retries x 0.5s) mitigates but root cause is unreliable. A more robust approach: detect item disappearance from the source slot, or listen to `ITEM_LOCK_CHANGED`.
- ~~**Medium: `CalculateOverflowDeficit` calls `ScanBags()` synchronously on every call.**~~ **FIXED (Twentieth Pass)** — Auto-continuation now waits for `BAG_UPDATE_DELAYED` (with 3s fallback) before re-calling `CalculateOverflowDeficit`, ensuring bags have settled.
- ~~**Medium: `GetCharacterKey()` duplicated**~~ **FIXED (Twentieth Pass)** — Centralized in `Core.lua` as `addonTable.Core.GetCharacterKey()`. Removed local definitions from Warehousing.lua, Reagents.lua, and widgets/Bags.lua.
- **Low: `bagList` rebuilt as new table on every `ScanBags()` call.** Three separate allocation sites for identical logic. Module-level constant would reduce GC pressure.
- **FIXED: Auto-continuation capped at 5 passes now shows "Sync limit reached — overflow may remain." instead of "Sync complete!".** **(Seventeenth Pass)**
- **Low: `GetCharacterNames()` uses `LunaUITweaks_WarehousingData.characters` only.** Alts known only through Reagents do not appear in mail dropdown.
- **Low: Mail queue sends items one per `C_Mail.SendMail` call without rate limiting.**
- **FIXED: `StaticPopupDialogs["LUNA_WAREHOUSING_AUTOBUY_CONFIRM"]` redefined inside `RunAutoBuy` on every call.** Moved to file scope. **(Sixteenth Pass)**

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

**Status:** Clean. Exemplary EventBus usage. Two low issues carried forward.

- `eventsEnabled` guard prevents duplicate EventBus registration. Exemplary pattern.
- `TooltipDataProcessor` hook is the correct modern WoW API.
- `IsReagent` optimization: tries `GetItemInfoInstant` first, falls back to `GetItemInfo`.
- `ScanBags()` properly debounced at 0.5s.
- `GetTrackedCharacters` uses `CharacterRegistry.GetAll()` as authoritative source.
- **FIXED:** `isLocked` guard added to all four scan functions — `GetLiveBagCount`, `ScanBags`, `ScanCharacterBank`, `ScanWarbandBank`. Tooltip counts now correctly drop to 0 immediately after selling items, rather than showing the pre-sell count until the lock animation clears.
- **Low:** `ScanCharacterBank()` still uses legacy container IDs (`-1` for BANK_CONTAINER, bag slots 5-11, `-3` for REAGENTBANK_CONTAINER). TWW restructured the bank to use `CharacterBankTab_1` enum. These legacy IDs may return 0 slots on TWW clients, causing the bank scan to silently return empty.
- **Low:** `sortedChars` table in `AddReagentLinesToTooltip` builds a new table per tooltip hover.

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
- **FIXED:** `ReleaseAlertFrame()` now clears both `currentReminder` and `currentMismatches`. **(Sixteenth Pass)**

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

- ~~**Medium:** `AnchorQueueEyeToMinimap()` calls `QueueStatusButton:SetParent(Minimap)` without `InCombatLockdown()` guard.~~ **FIXED (Twentieth Pass)** — `if InCombatLockdown() then return end` added.
- **Medium:** Triple redundant `C_Timer.After(0)` scheduling from OnShow/SetPoint/UpdatePosition hooks. Coalescing flag would eliminate redundant calls.
- **Medium:** Potential hook conflict with ActionBars.lua over QueueStatusButton positioning.
- **FIXED:** `SetDrawerCollapsed` now guards with `if InCombatLockdown() then return end` at function entry. **(Seventeenth Pass)**
- **Medium:** `CollectMinimapButtons` iterates all Minimap children on every call. Not cached.
- ~~**Low:** `GetMinimapShape = nil` for round shape; should return `"ROUND"`.~~ **FIXED (Twentieth Pass)**
- **Low:** Dead code in zone drag handler.
- ~~**Low:** Clock ticker (`C_Timer.NewTicker(1, UpdateClock)`) never cancelled when feature disabled.~~ **FIXED (Twentieth Pass)** — `clockTicker` and `coordsTicker` promoted to module-level; cancelled at `SetupMinimap()` entry.

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

### config/panels/WarehousingPanel.lua (~647 lines)

**Status:** One medium concern. Several low concerns.

- **FIXED:** `StaticPopupDialogs["LUNA_RESET_WAREHOUSING_CONFIRM"]` guarded with `if not` check at file load.
- **FIXED:** `SelectModule` (ConfigMain.lua) confirmed to call `addonTable.Config.RefreshWarehousingList()` for module 22. Previously flagged as missing — confirmed present.
- **NEW:** Auto-Buy Settings section added (lines 101-172): enable checkbox, gold reserve editbox, confirm threshold editbox. All correctly wired to `UIThingsDB.warehousing.*`.
- **NEW:** Buy toggle button column in tracked items list. OnEnter tooltip shows status, vendor name, price.
- **NEW:** Column header `MakeColumnHeader` now supports `anchorSide = "RIGHT"` parameter for the Buy column header.
- **Medium:** `RefreshItemList` calls `GetItemInfo(itemID)` on every row render for quality color. May return nil for uncached items; nil-check present but synchronous call on panel open could hitch for many tracked items.
- **Low:** `BuildDestinationDropdown` called once per item per `RefreshItemList` — N×K `UIDropDownMenu_CreateInfo()` tables per refresh.
- **Low:** `OpenCharPicker` recalculates `keys` via `GetAllCharacterKeys()` on every open.
- **Low:** `UpdateBuyBtn` closure created inside `RefreshItemList` loop — one new closure per row per refresh. Minor allocation churn.

---

### config/panels/WidgetsPanel.lua (~413 lines)

**Status:** Both previously flagged medium issues confirmed FIXED.

- **FIXED:** `CONDITIONS` table confirmed defined at line 222 OUTSIDE the `for i, widget` loop. Previously flagged as inside the loop — was corrected in a prior session.
- **FIXED:** `GetConditionLabel` confirmed defined at line 232 OUTSIDE the loop. Also corrected in a prior session.

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
- **FIXED:** `Vers.lua` widget text now shows both offensive and mitigation values as `"Vers: X.X% / Y.Y%"`. Consistent with tooltip. **(Sixteenth Pass)**

---

### widgets/WaypointDistance.lua (~204 lines)

**Status:** Clean. All medium issues from Eleventh Pass fixed. One low remains.

- **FIXED:** `HookScript("OnUpdate")` replaced with `C_Timer.NewTicker(0.5, ...)` managed inside `ApplyEvents(enabled)`. Ticker is properly created on enable and cancelled on disable.
- `GetActiveWaypoint()` iterates all saved waypoints on each 0.5s tick. For typical use (< 50 waypoints) this is negligible.
- **FIXED:** `FormatDistance` dead branch removed. `>= 100` was unreachable dead code; simplified to early return for `>= 1000` and plain return otherwise. **(Sixteenth Pass)**
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
- **FIXED:** `ResolveZoneName` partial match now returns the shortest matching name (most specific). Replaces non-deterministic `pairs` first-match. **(Seventeenth Pass)**

---

### widgets/AddonComm.lua (~124 lines)

**Status:** One low issue. Otherwise clean.

- **FIXED:** `GetGroupSize()` overcount — collapsed duplicate `IsInRaid`/`IsInGroup` branches into a single `IsInGroup()` check. `GetNumGroupMembers()` returns inclusive count in all group types. **(Sixteenth Pass)**
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

- **FIXED:** BNet `gameAccount.className` (localized) changed to `gameAccount.classFileName` (English token) for `GetClassColor`. WoW Friends section already used `classFilename` correctly. **(Seventeenth Pass)**

---

### widgets/Durability.lua (~99 lines)

**Status:** One medium observation.

- **FIXED:** Event registrations moved into `ApplyEvents(enabled)`. `MERCHANT_SHOW`, `MERCHANT_CLOSED`, `UPDATE_INVENTORY_DURABILITY` now correctly register/unregister based on enabled state. **(Sixteenth Pass)**

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

### 16. ~~GetCharacterKey() Triplicated (Medium Priority)~~ FIXED (Twentieth Pass)

`addonTable.Core.GetCharacterKey()` added to `Core.lua`, cached after first call. Local definitions removed from `Reagents.lua`, `Warehousing.lua`, and `widgets/Bags.lua`.

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

### Fixed Since Fourteenth Pass (Fifteenth Pass)

15a. **FIXED:** `GetMerchantItemInfo` nil error -- migrated to `C_MerchantFrame.GetItemInfo`.
15b. **FIXED:** `goto continue` Lua 5.1 syntax error -- replaced with `if needed > 0 then`.
15c. **FIXED:** Reagent tooltip counts stale after selling -- `isLocked` guard added to all 4 scan functions.
15d. **FIXED:** `WidgetsPanel.lua` `CONDITIONS` inside loop -- confirmed fixed in prior session.
15e. **FIXED:** `WidgetsPanel.lua` `GetConditionLabel` inside loop -- confirmed fixed in prior session.
15f. **FIXED:** `ConfigMain.lua` module 22 missing `RefreshWarehousingList` -- confirmed present.
15g. **FIXED:** `Friends.lua` localized class name -- confirmed uses `classFilename`.
15h. **FIXED:** `XPRep.lua` `ToggleCharacter` no combat guard -- confirmed guard present.

### Medium Priority (New -- Twelfth Pass)

12a. ~~**Coordinates.lua distance helpers duplicated from WaypointDistance widget**~~ **FIXED (Nineteenth Pass)** — `GetDistanceToWP` and `FormatDistanceShort` now exposed on `addonTable.Coordinates`. `WaypointDistance.lua` removed its duplicate definitions and reads from `Coordinates.GetDistanceToWP` / `Coordinates.FormatDistanceShort` instead. `MapPosToWorld` remains private to `Coordinates.lua` as it's an implementation detail.
12b. ~~**Coordinates.lua `C_Timer.NewTicker(2, ...)` never cancelled**~~ **FIXED (Nineteenth Pass)** — Ticker moved from `CreateMainFrame` (unconditional, leaked forever) into `UpdateSettings`. Stored in module-level `distanceTicker`. Created when `enabled = true` and frame is shown, cancelled and nilled when `enabled = false`.
12c. ~~**Misc.lua `HookTooltipSpellID` not forward-declared**~~ **FIXED (Nineteenth Pass)** — `local HookTooltipSpellID -- forward declaration` is already on line 303 alongside `HookTooltipClassColors` on line 302. No change needed.

### Medium Priority (Carried Forward)

13. ~~**Warehousing.lua `WaitForItemUnlock` unreliable**~~ **FIXED (Nineteenth Pass)** — Replaced polling loop (20x `C_Timer.After` at 0.1s) with event-driven approach: registers `ITEM_LOCK_CHANGED` via EventBus, resolves immediately on event, with a `C_Timer.NewTicker` 2s fallback for warband bank latency. Cleans up both the listener and timeout handle on resolution. Stale `maxAttempts` argument removed from all three call sites.
14. ~~**Warehousing.lua `CalculateOverflowDeficit` stale state**~~ **FIXED (Twentieth Pass)** — Replaced fixed `C_Timer.After(SCAN_DELAY + 0.1, ...)` continuation wait with an event-driven approach: registers `BAG_UPDATE_DELAYED` via EventBus so the re-check only fires after the client confirms all bag contents have settled. A `C_Timer.NewTicker(3, ...)` fallback resolves after 3s if the event never fires (e.g. warband bank with no local bag changes). Both the listener and fallback ticker are cleaned up via a one-shot `bagSettled` guard.
15. ~~**`GetCharacterKey()` duplicated**~~ **FIXED (Twentieth Pass)** — Added `addonTable.Core.GetCharacterKey()` to `Core.lua` (cached after first call). Removed the local definitions and `characterKey` upvalues from `Reagents.lua`, `Warehousing.lua`, and `widgets/Bags.lua` (3 definitions, 16 call sites total). Each file now uses `local GetCharacterKey = function() return addonTable.Core.GetCharacterKey() end` as a thin alias, preserving the same call syntax throughout.
16. **Teleports.lua FontString in button array** -- Track "no spells" FontString separately.
17. **Teleports.lua `SetAttribute` during combat** -- Guard `ReleaseButton` secure operations with `InCombatLockdown()`.
18. **Keystone.lua position saved in wrong schema** -- Use framework position keys.
19. **MythicRating.lua nil `bestRunLevel`** -- Add nil guard before `string.format`.
20. **Combat deferral frame leak** -- ActionBars.lua + CastBar.lua: use reusable module-level frame.
21. **Combat.lua infinite retry in `TrackConsumableUsage`** -- Add retry counter (max 5 attempts).
22. ~~**MinimapCustom.lua `AnchorQueueEyeToMinimap` combat guard**~~ **FIXED (Twentieth Pass)** — `if InCombatLockdown() then return end` added as third guard after the nil checks.
23. **MinimapCustom.lua triple redundant `C_Timer.After(0)` scheduling** -- Add coalescing flag.
24. ~~**MinimapCustom.lua `SetDrawerCollapsed` combat guard**~~ **FIXED (Seventeenth Pass)** — `InCombatLockdown()` guard added.
25. **ChatSkin.lua `SetItemRef` override** -- Use `hooksecurefunc` instead.
26. ~~**Vault.lua / WeeklyReset.lua `ShowUIPanel` combat guard**~~ **FIXED (Twentieth Pass)** — `button == "LeftButton" and not InCombatLockdown()` guard added to `OnClick` in both files.
27. **Spec.lua menu click combat guard** -- Check `InCombatLockdown()` in menu callbacks.
28. ~~**Friends.lua localized class name**~~ **FIXED (Seventeenth Pass)** — BNet section now uses `classFileName`.
29. ~~**Durability.lua unconditional event registration**~~ **FIXED (Sixteenth Pass)** — `ApplyEvents(enabled)` added with proper register/unregister.
30. **EventBus snapshot allocation per dispatch** -- Consider scratch table reuse.
31. **WidgetsPanel.lua `CONDITIONS` table inside loop** -- Hoist to file-scope constant.
32. **WidgetsPanel.lua `GetConditionLabel` closure inside loop** -- Hoist to file scope.
33. **Config panel color swatch duplication (~960 lines)** -- Migrate 22 inline swatches to `Helpers.CreateColorSwatch`.
34. ~~**LootPanel.lua / VendorPanel.lua unguarded module access**~~ **FIXED (Twentieth Pass)** — `LootPanel.lua`: added `local LootUpdateSettings()` wrapper with nil guard at file scope; all 8 bare `addonTable.Loot.UpdateSettings()` calls replaced. `VendorPanel.lua` was already using `if addonTable.Vendor.UpdateSettings then` guards throughout — no change needed.
35. **AddonVersionsPanel.lua frame leak** -- Create dialog frames once, show/hide.
36. ~~**AddonVersionsPanel.lua `loadstring` length check**~~ **FIXED (Twentieth Pass)** — `if #str > 65536 then return nil, "Input too large" end` added before `loadstring` call.
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
55. ~~Combat.lua triplicate `ApplyReminderLock()` calls~~ **FIXED (Twentieth Pass)** — Removed the redundant second call at end of `UpdateReminderFrame()`. First call (after `ApplyReminderFont`) and third call (in `InitReminders`) remain correct.
56. Combat.lua stale comment "Create 4 text lines" (line 1113, loop creates 5)
57. MplusTimer death tooltip temp table
58. Guild widget tooltip cap for large guilds
59. Speed widget dual-update mechanism
60. ~~MinimapCustom.lua `GetMinimapShape` should return `"ROUND"`~~ **FIXED (Twentieth Pass)** — `GetMinimapShape = nil` replaced with `function GetMinimapShape() return "ROUND" end`.
61. MinimapCustom.lua dead code in zone drag handler
62. ~~MinimapCustom.lua clock ticker never cancelled~~ **FIXED (Twentieth Pass)** — `clockTicker` and `coordsTicker` promoted to module-level variables. `SetupMinimap()` now cancels and nils both at entry before potentially creating new ones.
63. Frames.lua `SetBorder` function hoisting
64. ObjectiveTracker `OnAchieveClick` type guard
65. TalentManager.lua deprecated `UIDropDownMenuTemplate` API
66. TalentManager.lua `DecodeImportString` type safety
67. ~~TalentReminder.lua `ReleaseAlertFrame` does not clear `currentMismatches`~~ **FIXED (Sixteenth Pass)**
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
79. ~~XPRep.lua `ToggleCharacter` without `InCombatLockdown()` guard~~ **FIXED (15g)**
80. ~~Vers.lua text shows only offensive versatility, not combined~~ **FIXED (Sixteenth Pass)**
81. ~~WaypointDistance.lua `FormatDistance` redundant branches (100+ and else identical)~~ **FIXED (Sixteenth Pass)**
82. ~~AddonComm widget `GetGroupSize()` overcounts party by 1~~ **FIXED (Sixteenth Pass)**
83. Warehousing.lua `bagList` rebuilt per `ScanBags()` call (3 separate sites)
84. ~~Warehousing.lua auto-continuation shows "Sync complete!" even if 5 passes hit limit with overflow remaining~~ **FIXED (Seventeenth Pass)**
85. ~~Coordinates.lua `ResolveZoneName` partial match unordered (ambiguous zone names non-deterministic)~~ **FIXED (Seventeenth Pass)**
86. Misc.lua `HookTooltipSpellID` not forward-declared (inconsistent with `HookTooltipClassColors`)
87. ~~Warehousing.lua `StaticPopupDialogs["LUNA_WAREHOUSING_AUTOBUY_CONFIRM"]` redefined inside `RunAutoBuy` per call~~ **FIXED (Sixteenth Pass)**
88. Warehousing.lua `RunAutoBuy` warband name-lookup calls `C_Item.GetItemNameByID` per warband item on merchant open (low frequency, acceptable)
89. WarehousingPanel.lua `UpdateBuyBtn` closure created per row per `RefreshItemList` call
90. Reagents.lua `ScanCharacterBank` legacy container IDs (`-1`, `-3`) may return 0 slots on TWW clients

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
