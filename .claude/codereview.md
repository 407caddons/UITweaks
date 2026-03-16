# WoW Lua Code Review — 2026-03-14

## Critical (would cause errors or taint in-game)

- **MinimapCustom.lua:50** — `QueueStatusButton:HookScript("OnShow", ...)` — `HookScript` is the frame-object form; it taints `QueueStatusButton`. CLAUDE.md and memory both list this frame as a confirmed Button-prototype taint source. Memory recorded this as FIXED (replaced with a ticker), but the hook is still present in the file. Fix: remove `HookScript` and use only the already-present `C_Timer.After` ticker approach.

- **MinimapCustom.lua:62** — `hooksecurefunc(QueueStatusButton, "SetPoint", ...)` — Frame-object form on a Blizzard Button frame. Taints the shared Button prototype → `ADDON_ACTION_BLOCKED: Button:SetPassThroughButtons()`. Memory marked this FIXED but it persists.

- **MinimapCustom.lua:75** — `hooksecurefunc(QueueStatusButton, "UpdatePosition", ...)` — Same Button-prototype taint issue. Memory marked FIXED but still present.

- **MinimapCustom.lua:146–168** — `MinimapCluster.InstanceDifficulty:ClearAllPoints()`, `:SetPoint()`, `:SetParent()` called in `ApplyMinimapShape` for both SQUARE and non-SQUARE paths. `InstanceDifficulty` is explicitly named in CLAUDE.md as a confirmed affected Blizzard Button frame. `ClearAllPoints`/`SetPoint`/`SetParent` on it taint the shared Button prototype. Fix: do not reposition InstanceDifficulty; instead anchor an addon-owned overlay frame relative to it.

- **ActionBars.lua:362** — `hooksecurefunc(QueueStatusButton, "SetPoint", ...)` — Another frame-object hook on the same Blizzard Button frame (QueueStatusButton appears in both ActionBars.lua and MinimapCustom.lua). Memory marked FIXED but still present.

- **ActionBars.lua:677** — `hooksecurefunc(MicroMenuContainer, "SetParent", ...)` — Frame-object form taints `MicroMenuContainer`. Fix: use `hooksecurefunc("SecureButton_SetParent", ...)` or poll via ticker if feasible.

- **ActionBars.lua:709** — `hooksecurefunc(EditModeManagerFrame, "Show", ...)` — Frame-object hook on a Blizzard frame. Fix: hook the global function `EditModeManager_EnterEditMode` if one exists, or use EventBus with `EDIT_MODE_LAYOUTS_UPDATED`.

- **ActionBars.lua:736** — `hooksecurefunc(EditModeManagerFrame, "Hide", ...)` — Same issue as above.

- **ActionBars.lua:1225** — `hooksecurefunc(barFrame, hookTarget, ...)` where `hookTarget` is `"SetPointBase"` or `"SetPoint"` on Blizzard action bar frames. Frame-object form taints the bar frame. For edit-mode system frames, CLAUDE.md allows `SetPointBase` repositioning, but hooking the method still taints the frame context.

- **ActionBars.lua:1406–1428** — `hooksecurefunc(btn, "UpdateHotkeys", ...)`, `hooksecurefunc(btn, "Update", ...)`, `hooksecurefunc(btn, "SetNormalTexture", ...)` on Blizzard action bar buttons. Frame-object hooks on Button frames taint the shared Button prototype → `ADDON_ACTION_BLOCKED`. Memory recorded these as FIXED (replaced with `hooksecurefunc("ActionButton_UpdateHotkeys", ...)` global form + ticker), but the frame-object hooks remain in the file.

- **ChatSkin.lua:681** — `hooksecurefunc(ChatFrame1, "SetPoint", ...)` — Frame-object hook on Blizzard's `ChatFrame1`. Memory recorded a fix applied using global-form `ShowUIPanel`/`HideUIPanel` hooks, but this frame-object hook is still in the file.

- **ChatSkin.lua:527** — `local text = region:GetText()` where `region` is a FontString from `selectedFrame:GetRegions()` and `selectedFrame` is a Blizzard chat frame. Calling `GetText()` on Blizzard FontStrings returns a tainted string. The subsequent `gsub` chain on `text` (line 529) operates on a tainted value and will produce garbage or silently fail. This is in the "copy chat content" fallback path, so it only fires when the primary `GetMessageInfo` path returns no lines — but the fallback will always fail silently. Fix: skip the `GetText()` fallback entirely since it cannot safely extract content from Blizzard FontStrings.

- **ObjectiveTracker.lua:883** — `hooksecurefunc(ObjectiveTrackerFrame, "Show", ...)` — Frame-object hook on a Blizzard frame. The callback then calls `SetAlpha(0)`, `SetScale(0.00001)`, and `EnableMouse(false)` on it. While those three calls are themselves safe (visual-only), the hook form taints the `ObjectiveTrackerFrame` context. Fix: use the global-form `hooksecurefunc("ObjectiveTracker_Update", ...)` or a polling ticker to suppress the tracker.

- **CastBar.lua:340–349** — `hooksecurefunc(PlayerCastingBarFrame, "Show", ...)`, `hooksecurefunc(PlayerCastingBarFrame, "SetShown", ...)`, `hooksecurefunc(PlayerCastingBarFrame, "SetAlpha", ...)` — Frame-object hooks on Blizzard's player cast bar. All three forms taint `PlayerCastingBarFrame`. The callbacks then call `ForceBlizzBarHide` which itself calls `frame:SetAlpha(0)` — a re-entrant write to a tainted frame. Fix: replace with a `C_Timer.NewTicker` that checks `PlayerCastingBarFrame:GetAlpha()` and forces it to 0 while `blizzBarHidden` is true.

- **Misc.lua:267** — `searchBar.FilterButton.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true` — Writing a field into `AuctionHouseFrame.SearchBar.FilterButton.filters`, a table that lives on a Blizzard frame. This taints the `FilterButton` table and all downstream reads of its `filters` field by Blizzard code. Fix: check if there is a public API (`C_AuctionHouseFilter.SetFilter`) or call Blizzard's own filter setter method.

## Warning (likely bugs or violations)

- **Vendor.lua:76,95** — Drag-stop handlers save position via raw `GetPoint()` → `{ point = point, x = x, y = y }`. The CLAUDE.md convention requires CENTER-relative offsets (`GetCenter()` minus `UIParent:GetCenter()`). Using raw anchor-relative values means the position is misapplied whenever the frame is next placed with a different anchor. Affected: `warningFrame` and `bagWarningFrame`. Same issue in **Combat.lua:84**, **CastBar.lua:587** (uses `GetPoint` and stores `point`), **XpBar.lua:405**, **SCT.lua:17,43**, **Loot.lua:65**, **QuestReminder.lua:264**, **MplusTimer.lua:126**, **Warehousing.lua:433**, **TalentReminder.lua:1427**.

- **Kick.lua:233,241** — `UnitName(unit) == senderShort` — `UnitName()` may return a secret value on certain unit tokens in restricted contexts. The `==` equality operator fails on secret strings (raises a Lua error or silently evaluates false). The comparison is used to match a sender name received via addon comm to a party unit — if this fires during combat it will silently miss matches. Fix: guard with `if not issecretvalue(name) then`.

- **DamageMeter.lua:141–161** — Inside `FetchEntries`, the `liveMode` branch (reached when `sessKey == "current"` and `InCombatLockdown()`) stores `src.totalAmount` (a secret value) into `byGuid[i].total` and `sessData.maxAmount` into `byGuid[i].maxTotal`. Line 281 then does `table.sort(list, function(a, b) return a.total > b.total end)` which uses the `>` comparison operator on secret values — this raises a Lua error. In practice the normal render path (line 421) bypasses `FetchEntries` during combat so this liveMode branch is currently unreachable from rendering, but the dead code would explode if anything else triggered it. Fix: remove the liveMode branch from `FetchEntries` entirely (it's already superseded by the direct render path at line 421).

- **Misc.lua:494** — `deleteButton:SetParent(dialog)` where `dialog` is a Blizzard `StaticPopup` frame. `SetParent` on a Blizzard-owned frame taints its layout context. The addon-created `deleteButton` inheriting Blizzard's frame as parent is the source. Fix: parent the button to UIParent and use `SetPoint` relative to `editBox` without reparenting.

- **MinimapCustom.lua:152–160** — Inside the SQUARE-shape path, `QueueStatusButton:ClearAllPoints()`, `SetPoint()`, and `SetParent()` are called directly (not just via hooksecurefunc). CLAUDE.md notes that `SetPoint/ClearAllPoints/SetParent` on QueueStatusButton taint layout context (though not the Button prototype per the ticker fix). This fires every time the shape is applied, including at login.

- **Misc.lua:507–509** — `Misc.ToggleQuickDestroy(true)` is called at file-load time with `if UIThingsDB and UIThingsDB.misc and UIThingsDB.misc.quickDestroy`. Saved variables are not available at file-load time (only after `ADDON_LOADED`); `UIThingsDB` will always be nil here. This initialization call is always a no-op. Fix: remove this block; the `PLAYER_ENTERING_WORLD` handler already calls `Misc.ToggleQuickDestroy`.

- **QueueTimer.lua:~142** — `OnUpdate` is installed at `Init()` and runs every frame for the addon's session lifetime even when `isRunning = false`. Each frame it enters and early-exits. Fix: set the script only in `StartTimer()`; clear it in `StopTimer()`.

- **Loot.lua:~497** — `issecretvalue(msg)` guard in `OnChatMsgLoot`. Chat strings from `CHAT_MSG_LOOT` are not secret values. This guard silently drops loot toasts during combat on affected builds. The BoE handler in `Misc.lua` correctly omits this guard. Fix: remove it.

- **MplusTimer.lua:893–904** — Death attribution off-by-one: when `i == members` (the 5th player), `unit = "player"` is substituted for `party5` which does not exist. The last iteration always tests the player token instead of a valid party unit and can mis-attribute deaths. Fix: iterate `party1`–`party4` then check `"player"` outside the loop.

## Minor (style, performance, clarity)

- **SCT.lua:89–104** — `ClearAllPoints()` + `SetPoint()` called inside `OnUpdate` every frame for up to 30 simultaneously active SCT text frames. At 60 fps with 30 active this is 3600 layout calls/sec. Pre-parent each text frame to its anchor and use a Y-offset-only `SetPoint("BOTTOM", anchor, "TOP", 0, yOffset)` — but since the frame's parent is already the anchor the `ClearAllPoints` call can be dropped; a single `SetPoint` is needed only when yOffset changes. Alternatively use `SetAlpha`-only fade and position the text at a fixed offset, scrolling via a dedicated scroll frame.

- **Widgets.lua (OnUpdate)** — Every widget frame created by `CreateWidgetFrame` has an `OnUpdate` that runs every rendered frame only to check `if self.isMoving`. When all widgets are locked (`isMoving` is always false), this is hundreds of no-op calls per second. Install `OnUpdate` only during a drag; clear it in `OnDragStop`.

- **Widgets.lua (UpdateAnchoredLayouts)** — Allocates `anchoredWidgets = {}` and per-entry `{ key = key, frame = frame }` tables on every tick (every second when widgets are enabled). Reuse module-level tables with `wipe()`.

- **Reagents.lua** — `GetLiveBagCount` scans all bag slots on every `TooltipDataType.Item` postCall. Cache the result keyed by itemID; invalidate on `BAG_UPDATE_DELAYED`.

- **Vendor.lua** — Bag-space check uses bags 0–4 only, missing the reagent bag (index 5 / `Enum.BagIndex.ReagentBag`). The low-space warning fires incorrectly when free slots are only in the reagent bag.

- **Core.lua:232–820** — The ~600-line `DEFAULTS` table is defined inside the `ADDON_LOADED` handler closure. Move it to module scope for readability and to avoid it being captured as an upvalue closure.

- **Misc.lua:7–127** — `alertFrame`, `mailAlertFrame`, and `boeAlertFrame` are created at module load unconditionally, even when `misc.enabled = false`. Create them lazily on first show.

- **Misc.lua** — `ApplyUIScale` silently drops the scale change when `InCombatLockdown()` with no retry. Register a one-shot `PLAYER_REGEN_ENABLED` handler on failure.

- **Misc.lua:476–484** — `OnPartyInviteRequest` performs an O(n BNet friends) linear scan on every invite. Cache a GUID→bool map, invalidated on `BN_FRIEND_LIST_UPDATE`.

- **SCT.lua:69–74** — `RecycleSCTFrame` iterates the full `sctActive` list to remove a frame by reference. Maintain a parallel set (`sctActiveSet[frame] = true`) for O(1) removal.

- **AddonVersions.lua** — `GetPlayerKeystone` scans all bag slots on every `GROUP_ROSTER_UPDATE`. Cache the result; invalidate on `BAG_UPDATE_DELAYED`.

- **FPS.lua** — `RefreshMemoryData` sorts `addonMemList` at line 44; `OnEnter` sorts it again at line 99. The second sort is redundant.

- **Profiler.lua** — `sortedRows` is wiped each interval but never trimmed if module count exceeds `MAX_ROWS = 40`. Add `for i = #sortedRows, MAX_ROWS + 1, -1 do sortedRows[i] = nil end` after `wipe`.

- **Multiple files** — Frame positions not yet migrated to CENTER anchor: `XpBar`, `CastBar`, `Combat`, `Kick`, `ObjectiveTracker`, `MinimapCustom`, `MplusTimer`, `SCT`, `Vendor`, `Loot`, `QuestReminder`, `Warehousing`, `TalentReminder`. All save raw `GetPoint()` anchor-relative coords instead of `GetCenter() - UIParent:GetCenter()`.

## Summary

The addon has a solid architecture — centralized EventBus, AddonComm rate limiting, frame pooling in Loot, and thorough secret-value handling in DamageMeter. However, several high-severity taint regressions are present in the current build. Memory notes from March 2026 recorded QueueStatusButton hooks, ActionBars frame-object hooks, and ChatSkin's ChatFrame1 hook as *fixed*, but all three remain in the live code (`MinimapCustom.lua:50,62,75`, `ActionBars.lua:362,1406–1428`, `ChatSkin.lua:681`). The `MinimapCluster.InstanceDifficulty` repositioning in `MinimapCustom.lua:146–168` is a confirmed Button-prototype taint source that should be removed entirely. CastBar's `hooksecurefunc` suppression of `PlayerCastingBarFrame` and ObjectiveTracker's `hooksecurefunc(ObjectiveTrackerFrame, "Show", ...)` are also active taint risks. Resolving these ~13 Critical items is the highest priority; the Warning-level `GetPoint()` position-save convention violations and the Minor performance items can follow.
