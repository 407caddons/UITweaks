# Feature Suggestions — LunaUITweaks
Date: 2026-02-26 (updated 2026-03-01, 2026-03-02, 2026-03-02 pass 2)

**Update 2026-03-01:** Several widget suggestions from the companion widgets.md have been implemented: Clock/Server Time (→ `widgets/Time.lua` ✓), FPS/Latency (→ `widgets/FPS.lua` ✓), Weekly Reset Countdown (→ `widgets/WeeklyReset.lua` ✓), Spec Display (→ `widgets/Spec.lua` ✓). A new module not previously suggested has also shipped: `QueueTimer.lua` — a progress bar that counts down the LFG proposal acceptance window. Three more widgets also shipped that were not in the original suggestions: `Speed` (movement speed %), `Volume` (sound toggle/cycle), `BattleRes` (battle resurrection charge tracker). Feature suggestions below are updated with implemented/pending status.

**Update 2026-03-02 (pass 2):** BoE Item Alert (**feature #19**) and Death Notification shipped in Misc.lua with full config panel support (NotificationsPanel.lua). BoE alert detects Bind-on-Equip loot via `CHAT_MSG_LOOT`, filters by item quality (Uncommon/Rare/Epic/Legendary), and shows a coloured overlay with TTS. Death Notification announces party/raid member deaths via TTS with configurable message (`{name}`, `{role}` placeholders) and voice type. Two new code review issues (#46 UNIT_HEALTH too broad, #48 GetItemInfo nil race) found in the new code.

**Update 2026-03-02:** Per-widget clickthrough toggle shipped in Widgets config panel. XP bar tooltip fix (mouse always enabled, drag gated by lock). Warband Mentor XP bonus is now auto-detected via `GetAchievementInfo` (achievements 42328–42332). DMF WHEE widget spell ID corrected (71968 → 136583).

## Introduction

LunaUITweaks is already a mature, self-contained addon covering a wide range of quality-of-life improvements for WoW 12.0. The suggestions below build naturally on the existing EventBus, AddonComm, and widget framework and are grouped by category with honest difficulty ratings and notes on WoW API or taint constraints.

---

## Combat Features

### 1. Boss Ability Timers (Clock-Based)
**Difficulty:** Medium
**Description:** Clock-based countdown timers that arm on `ENCOUNTER_START` for manually configured boss abilities. No combat log access required. Fits the existing module pattern.
**Notes:** Fully feasible without COMBAT_LOG_EVENT_UNFILTERED. User configures spell IDs and durations manually.

### 2. Interrupt Assignment / Rotation
**Difficulty:** Medium
**Description:** Extend the Kick module via AddonComm to assign and cycle interrupt responsibilities in a group. The existing Kick frame, AddonComm bus, and roster cache are already in place.
**Notes:** Cannot confirm actual interrupter due to `issecretvalue()` on the GUID from `UNIT_SPELLCAST_INTERRUPTED`. Assignment/cycling is fully feasible; confirmation is not.

### 3. Wipe Recovery Checklist
**Difficulty:** Easy
**Description:** After a group wipe (`PLAYER_DEAD` + group context), show a brief checklist of pre-pull tasks (flask, food, pet, class buff) reusing existing consumable detection from Combat.lua. Dismisses on next `ENCOUNTER_START`.
**Notes:** All needed events and APIs are available. Simple UI overlay.

### 4. Encounter Pull Log
**Difficulty:** Easy
**Description:** Record start time, duration, and outcome (wipe/kill) per boss using `ENCOUNTER_START`/`ENCOUNTER_END` — both fully available to third-party addons. Integrates with SessionStats as a tooltip section.
**Notes:** No API restrictions. Natural extension of SessionStats widget.

### 5. Defensive Cooldown Tracker
**Difficulty:** Hard
**Description:** Track major party/raid defensive cooldowns (Darkness, AMZ, Barrier, etc.) using `UNIT_SPELLCAST_SUCCEEDED` on group units plus duration timers. AddonComm sharing (as Kick already does) extends coverage.
**Notes:** Requires managing many unit event registrations and a large spell ID database. High value but high maintenance as spells change each patch.

---

## UI/UX Features

### 6. Nameplate Aura Tracker
**Difficulty:** Hard
**Description:** Icons for a user-defined spell ID list displayed on enemy nameplates. Uses `NAME_PLATE_UNIT_ADDED`/`REMOVED` and `C_UnitAuras`. High player demand feature.
**Notes:** Performance care needed with many nameplates active. No taint concerns for addon-created frames anchored to nameplate frames.

### 7. GCD Bar
**Difficulty:** Medium
**Description:** A thin bar showing the current Global Cooldown fill, driven by `SPELL_UPDATE_COOLDOWN` and `C_Spell.GetSpellCooldown`. Fits alongside the existing CastBar module.
**Notes:** Straightforward API usage. Main challenge is detecting GCD vs. spell-specific cooldowns.

### 8. Screen Edge Alerts
**Difficulty:** Medium
**Description:** Coloured screen-edge vignette overlay for configurable triggers: low health, low mana, missing flask, or a specific debuff. Uses existing `C_UnitAuras` detection.
**Notes:** Overlay textures anchored to UIParent edges. No taint. OnUpdate polling or event-driven, depending on trigger type.

### 9. Personal Cooldown Tracking Bar
**Difficulty:** Medium
**Description:** A row of user-defined spell/item icons showing cooldown state. Drives off `SPELL_UPDATE_COOLDOWN`/`BAG_UPDATE_COOLDOWN`. Reuses the icon button pool pattern from Combat.lua.
**Notes:** Configuration UI (adding/removing spells) is the most complex part. Core display is straightforward.

### 10. Font Profile System
**Difficulty:** Easy
**Description:** Named presets storing global or per-module font/size/colour. A dropdown in config applies the profile to all modules via their `UpdateSettings()` functions.
**Notes:** Pure saved-variable work. No WoW API constraints. Very user-friendly improvement.

### 11. Minimap Drawer Auto-Hide in Combat
**Difficulty:** Easy
**Description:** Use `RegisterStateDriver` on the existing minimap drawer frame to hide it during combat automatically.
**Notes:** Requires `SecureHandlerStateTemplate` on the frame. The minimap module already manages this frame, so it's a small addition.

---

## Social & Group Features

### 12. Group Role Composition Widget
**Difficulty:** Easy
**Description:** Display tank/healer/DPS counts using `UnitGroupRolesAssigned`. Natural extension of the existing Group widget and Kick roster tracking.
**Notes:** All APIs freely available. Low complexity, high utility for group leaders.

### 13. Ready Check History
**Difficulty:** Easy
**Description:** Record results of recent ready checks using `READY_CHECK`, `READY_CHECK_RESPONSE`, `READY_CHECK_FINISHED`. Session-only table, tooltip or list display.
**Notes:** No taint. Who wasn't ready is always useful information after a wipe.

### 14. Raid Announcement Templates
**Difficulty:** Easy
**Description:** User-configurable chat template messages with `{name}`, `{spec}`, `{ilvl}`, `{dungeon}` variables, sent via `SendChatMessage`. Simple string replacement + list UI in config.
**Notes:** No API constraints. Useful for raid leaders who send the same messages repeatedly.

---

## Quality of Life Features

### 15. Smart Vendor Price Tooltip
**Difficulty:** Easy
**Description:** Add vendor sell price to item tooltips using `TooltipDataProcessor.AddTooltipPostCall` (hook already used in Misc.lua). `C_Item.GetItemInfo` provides the sell value.
**Notes:** Very small addition to existing tooltip infrastructure.

### 16. Alt Character Summary Panel
**Difficulty:** Medium
**Description:** A panel reading `LunaUITweaks_CharacterData`, `LunaUITweaks_ReagentData`, and `LunaUITweaks_WarehousingData` to display a cross-character overview of alts, their reagents, and currency totals.
**Notes:** Pure display layer on existing saved variables. Main work is the UI layout for multiple characters.

### 17. Auto Group Loot Threshold Setter
**Difficulty:** Easy
**Description:** On becoming group leader (`PARTY_LEADER_CHANGED`), automatically call `SetLootThreshold(quality)` to a configured value.
**Notes:** Two-function feature for the Misc module. Zero API restrictions.

### 18. Crafting Order Expiry Timer
**Difficulty:** Medium
**Description:** Extend the personal order notification with expiry countdown display using data from `C_CraftingOrders.GetPersonalOrdersInfo()` (already called in Misc.lua).
**Notes:** Needs a ticker since no expiry events fire. The data is already being fetched, so it's an extension of existing work.

### 19. BoE Item Alert ✅ Implemented (Misc.lua)
**Difficulty:** Easy
**Description:** When a looted item is BoE (`CHAT_MSG_LOOT` + `GetItemInfo` bind type check), shows a coloured alert overlay with the item name and quality colour. Configurable minimum quality (Uncommon → Legendary), alert duration, and alert colour. No TTS for BoE (silent alert only). Quality filtering uses `boeMinQuality` (default: Epic+).
**Notes:** One minor issue (#48 in codereview.md): `GetItemInfo` may return nil for items not yet in the client cache when the loot event fires. Silent drop — no retry. Consider queuing a `SafeAfter(0.3, ...)` retry.

---

## Integration Features

### 20. Lightweight Aura Display
**Difficulty:** Hard
**Description:** Persistent, positioned icons for a user-defined watch list of spell IDs on "player" or "target". Uses `C_UnitAuras.GetAuraDataBySpellID` and `UNIT_AURA`. Supports cooldown spiral and duration text.
**Notes:** Main complexity is icon layout, cooldown spiral rendering, and configuration UI. No taint for addon-created frames. High demand feature that many players currently use WeakAuras for simple cases.

### 21. Death Recap Overlay
**Difficulty:** Very Hard (API-blocked)
**Description:** Display last few damage sources on death. Fully blocked by the `COMBAT_LOG_EVENT_UNFILTERED` restriction for third-party addons.
**Notes:** A partial implementation (debuffs active at death from `C_UnitAuras` snapshot on `PLAYER_DEAD`) is possible but not a true damage recap. Not recommended without a future Blizzard API addition.

---

---

## Features Added/Fixed Since Last Review (2026-03-02 pass 2)

### 24. Death Notification ✅ Implemented (Misc.lua + NotificationsPanel.lua)
**Difficulty:** Easy *(shipped)*
**Description:** Announces party and raid member deaths via TTS. Triggers on `UNIT_HEALTH` events, checks `UnitIsDead(unitTarget)` for party/raid unit tokens, and speaks a configurable message with `{name}` and `{role}` placeholder substitution. Deduplicated via a `deathAnnounced` table — each death fires TTS once and resets when the unit is resurrected. Voice type (Standard / Alternate 1) is configurable. Full config panel UI in Notifications tab.
**Notes:** Performance concern (#46 in codereview.md): uses `UNIT_HEALTH` (extremely frequent) rather than `UNIT_DIED` (fires once on death). Recommend switching to `UNIT_DIED` for detection and a lighter event for resurrection reset.

### BoE Item Alert — see feature #19 above ✅ Implemented

---

## Features Added Since Last Review (2026-03-01)

### 22. LFG Queue Pop Timer ✅ Implemented (`QueueTimer.lua`)
**Difficulty:** Easy *(was not previously suggested — shipped)*
**Description:** A progress bar that counts down the LFG dungeon-finder proposal window. Anchors below the Blizzard `LFGDungeonReadyDialog` when visible; falls back to a configurable CENTER position. Reads the actual expiration timestamp from `GetLFGProposal()` and supports dynamic green→yellow→red color, optional text countdown, and configurable size. Starts on `LFG_PROPOSAL_SHOW`, stops on `LFG_PROPOSAL_FAILED`/`LFG_PROPOSAL_SUCCEEDED` or when entering an instance.
**Notes:** Minor code issues (#31, #32, #33 in codereview.md). Overall a clean, well-scoped module.

---

## Features Added/Fixed Since Last Review (2026-03-02)

### 23. Per-Widget Clickthrough Toggle ✅ Implemented (Widgets config panel)
**Difficulty:** Easy *(new micro-feature)*
**Description:** A "CT" (clickthrough) checkbox added per widget in the Widgets config panel. When enabled and widgets are locked, `EnableMouse(false)` is set on that widget so clicks pass through to the UI underneath. Useful for widgets positioned over the game world or other interactive frames where mouse input should not be intercepted.
**Notes:** Small, clean addition to the widget framework. No taint concerns — `EnableMouse` on addon-created frames is always safe.

### XP Bar Tooltip Fix ✅ Fixed
**Description:** The XP bar tooltip was invisible when the bar was locked because locking previously called `EnableMouse(false)`. Mouse is now always enabled; drag eligibility is gated separately by the lock state. Tooltip is visible regardless of lock status.

### XP Bar Warband Mentor Auto-Detection ✅ Improved
**Description:** The Warband Mentor: Midnight XP bonus (5%–25% based on tier, driven by achievements 42328–42332) is now auto-detected via `GetAchievementInfo` instead of requiring manual user configuration. The detected bonus tier is shown in the XP bar tooltip automatically.

### DMF WHEE Widget Spell ID Fix ✅ Fixed
**Description:** The Darkmoon Faire WHEE! buff was using the wrong spell ID (71968). Corrected to 136583 so the widget now accurately detects when the buff is active.

---

## Difficulty Summary

| # | Feature | Difficulty | Status |
|---|---------|-----------|--------|
| 1 | Boss Ability Timers | Medium | Pending |
| 2 | Interrupt Assignment / Rotation | Medium | Pending |
| 3 | Wipe Recovery Checklist | Easy | Pending |
| 4 | Encounter Pull Log | Easy | Pending |
| 5 | Defensive Cooldown Tracker | Hard | Pending |
| 6 | Nameplate Aura Tracker | Hard | Pending |
| 7 | GCD Bar | Medium | Pending |
| 8 | Screen Edge Alerts | Medium | Pending |
| 9 | Personal Cooldown Tracking Bar | Medium | Pending |
| 10 | Font Profile System | Easy | Pending |
| 11 | Minimap Drawer Auto-Hide in Combat | Easy | Pending |
| 12 | Group Role Composition Widget | Easy | Pending |
| 13 | Ready Check History | Easy | Pending |
| 14 | Raid Announcement Templates | Easy | Pending |
| 15 | Smart Vendor Price Tooltip | Easy | Pending |
| 16 | Alt Character Summary Panel | Medium | Pending |
| 17 | Auto Group Loot Threshold Setter | Easy | Pending |
| 18 | Crafting Order Expiry Timer | Medium | Pending |
| 19 | BoE Item Alert | Easy | ✅ Implemented |
| 20 | Lightweight Aura Display | Hard | Pending |
| 21 | Death Recap Overlay | Very Hard (API-blocked) | Pending |
| 22 | LFG Queue Pop Timer | Easy | ✅ Implemented |
| 23 | Per-Widget Clickthrough Toggle | Easy | ✅ Implemented |
| 24 | Death Notification (TTS) | Easy | ✅ Implemented |
