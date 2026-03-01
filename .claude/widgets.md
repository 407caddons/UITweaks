# Widget Ideas — LunaUITweaks
Date: 2026-02-26 (updated 2026-03-01)

## Update 2026-03-01

Since the original document, the following widget suggestions have been **implemented**:

| # | Suggestion | Status |
|---|-----------|--------|
| 1 | Spec Display | ✅ Implemented — `widgets/Spec.lua` (left-click spec swap, right-click loot spec) |
| 2 | Clock / Server Time | ✅ Implemented — `widgets/Time.lua` (12h/24h toggle, reset times in tooltip, calendar on click) |
| 3 | Weekly Reset Countdown | ✅ Implemented — `widgets/WeeklyReset.lua` (color-coded, daily reset in tooltip) |
| 4 | FPS / Latency | ✅ Implemented — `widgets/FPS.lua` (jitter tracking, per-addon memory breakdown in tooltip) |

Three additional widgets shipped that were not in the original suggestions:
- **Speed** (`widgets/Speed.lua`) — Movement speed as % of base (100% = 7 yds/s), skyriding-aware, 0.5s refresh.
- **Volume** (`widgets/Volume.lua`) — Sound toggle (left-click) and volume cycle 100→75→50→25% (right-click).
- **BattleRes** (`widgets/BattleRes.lua`) — Battle resurrection charge tracker using Rebirth spell ID for the shared pool.
- **Coordinates** (`widgets/Coordinates.lua`) — Simple coordinate widget complementing the full Coordinates.lua module.

Issues found in the new widgets are noted in the code review. Remaining suggestions below retain their original numbering.

---

## Introduction

This document reviews all existing widgets in LunaUITweaks (~35 as of 2026-03-01) and proposes ideas for new widgets and improvements to existing ones. Each idea is assessed for difficulty against the WoW 12.0 retail API constraints (no COMBAT_LOG_EVENT_UNFILTERED, no external libraries, combat lockdown rules apply).

The existing widget suite covers: secondary stats (Haste, Crit, Mastery, Versatility), social (Friends, Guild, Group), progression (MythicRating, Keystone, Vault, Lockouts, XPRep), utility (Bags, Currency, Hearthstone, Teleports, Durability, Mail, WaypointDistance, Zone, DarkmoonFaire, PullCounter, SessionStats, Combat, AddonComm, Speed, Volume, BattleRes, Coordinates), performance (FPS), time (Time, WeeklyReset), and PvP. Spec display widget added for spec/loot spec management.

---

## New Widget Ideas (12)

---

### 1. Spec Display ✅ IMPLEMENTED (`widgets/Spec.lua`)
**Type:** New Widget
**Difficulty:** Easy
**Description:** Shows current spec and loot spec icons side by side. Left-click opens a context menu to switch specialization; right-click opens a loot spec switcher. The actual implementation went beyond the original suggestion by including both spec swap and loot spec menus.
**Notes:** Two issues identified in code review (#34, #35 in codereview.md): no `InCombatLockdown()` guard on spec change, and no `ACTIVE_TALENT_GROUP_CHANGED` event subscription (relies on 1s ticker instead).

---

### 2. Clock / Server Time ✅ IMPLEMENTED (`widgets/Time.lua`)
**Type:** New Widget
**Difficulty:** Easy
**Description:** Shows local time (12h or 24h, reusing the minimap clock format setting). Tooltip shows local time, server time, and daily/weekly reset countdowns with color coding. Left-click opens the calendar. Bonus: reset time info in tooltip goes beyond the original suggestion.
**Notes:** Three issues identified (#38, #39, #40 in codereview.md): `ToggleCalendar()` called without checking if Blizzard_Calendar is loaded (should mirror WeeklyReset's `C_AddOns.LoadAddOn` guard), a dead `calendarTime` variable assignment in `OnEnter`, and a leading space in the `date(" %I:%M %p")` format string.

---

### 3. Weekly Reset Countdown ✅ IMPLEMENTED (`widgets/WeeklyReset.lua`)
**Type:** New Widget
**Difficulty:** Easy
**Description:** Uses `C_DateAndTime.GetSecondsUntilWeeklyReset()` (exact API, no hardcoded timezone math). Color-coded: green > 12h, yellow < 12h, red < 3h. Tooltip also shows daily reset. Left-click opens calendar (with proper addon-load guard). Clean implementation.
**Notes:** `FormatResetTime` and `FormatDailyTime` are separate but nearly identical functions — minor duplication that could be merged into one shared formatter. No functional issues.

---

### 4. FPS / Latency ✅ IMPLEMENTED (`widgets/FPS.lua`)
**Type:** New Widget
**Difficulty:** Easy *(actual implementation was Medium — went well beyond the original scope)*
**Description:** Shows home latency and FPS in main text. Tooltip includes home/world latency, jitter (standard deviation over 30 samples), bandwidth in/out, and optionally a full per-addon memory breakdown (throttled to once per 15s). The jitter calculation and per-addon memory panel are particularly well done.
**Notes:** One issue (#36 in codereview.md): `table.sort` is called twice on `addonMemList` in `OnEnter` — once inside `RefreshMemoryData()` and again immediately after. The second sort is redundant. Also note the jitter circular buffer is correct but slightly non-obvious (issue #37).

---

### 5. Equipped Set / Gear Set Switcher
**Type:** New Widget
**Difficulty:** Medium
**Description:** Shows the currently active equipment set name (if any) and allows clicking to open a popover panel listing all saved gear sets. Click on a set name in the panel to equip it. Useful for players who swap between specs with different gear (e.g. tank/heal sets). Displays "Set: None" if no set matches current gear.
**Notes:** `C_EquipmentSet.GetEquipmentSetIDs()`, `C_EquipmentSet.GetEquipmentSetInfo(setID)`, `C_EquipmentSet.UseEquipmentSet(setID)`. Cannot equip gear sets in combat (`InCombatLockdown()` check required). Equipping gear is fine out of combat. The popover pattern is already established in the Currency and Teleports widgets. Medium difficulty due to the popover UI and set matching logic.

---

### 6. Spell Cooldown Monitor
**Type:** New Widget
**Difficulty:** Medium
**Description:** Tracks one or more user-specified spell cooldowns and shows the largest remaining cooldown (or "Ready" if all are up). The user configures spell IDs or names via a config panel. Clicking the widget cycles through configured spells showing each cooldown. Tooltip lists all tracked spells and their individual cooldown states. Useful for tracking long-cooldown abilities like Heroism, battle resurrections, or defensive cooldowns.
**Notes:** `GetSpellCooldown(spellID)` or `C_Spell.GetSpellCooldown(spellID)` returns startTime, duration, isEnabled. `SPELL_UPDATE_COOLDOWN` event for reactive updates, supplemented by the 1-second ticker for countdown text. Config panel needs a text entry for spell IDs. Medium due to the config integration requirement and multiple-spell management.

---

### 7. Delve Companion Status
**Type:** New Widget
**Difficulty:** Medium
**Description:** Displays Brann Bronzebeard companion level, current curio slots, and equipment summary for players engaging in Delves content (TWW). Shows something like "Brann: Lv 40" with a tooltip listing active curios, special abilities, and whether the companion is at max level. Provides quick reference without opening the full companion pane.
**Notes:** `C_DelvesUI` namespace introduced in TWW, specifically `C_DelvesUI.GetCompanionInfo()` and related. Check the in-game docs for exact function signatures. May require loading the Blizzard_DelvesUI addon via `C_AddOns.LoadAddOn`. Events: `COMPANION_UPDATE` or Delves-specific. Medium difficulty — API is newer and may be sparsely documented.

---

### 8. Buff / Debuff Tracker
**Type:** New Widget
**Difficulty:** Medium
**Description:** Tracks up to 4 user-specified buffs or debuffs on the player and shows their remaining duration. Configured by spell ID in the options panel. Display shows the shortest remaining duration among tracked auras, or "Ready" if none are active. Tooltip shows all tracked auras individually. Useful for tracking Bloodlust duration, food buffs, flask timers, or important debuffs.
**Notes:** `C_UnitAuras.GetPlayerAuraBySpellID(spellID)` returns the aura table including expirationTime. Events: `UNIT_AURA` for "player" unit. The 1-second ticker handles countdown. Must not use COMBAT_LOG_EVENT_UNFILTERED. Config needs spell ID entry similar to the Currency widget's customIDs pattern. Medium due to config work and aura management.

---

### 9. Auction House / Economy Shortcut
**Type:** New Widget
**Difficulty:** Easy
**Description:** A simple widget button that opens the Auction House (if the player is in range of an AH NPC) or displays "AH: Far" otherwise. Tooltip shows the number of active auctions the player has up (from `C_AuctionHouse.GetNumOwnedAuctions()`) and whether any auctions have sold. Clicking opens the AH if available.
**Notes:** `C_AuctionHouse.GetNumOwnedAuctions()` requires the AH to be open. `AUCTION_HOUSE_SHOW` and `AUCTION_HOUSE_CLOSED` events for availability detection. For "how many active auctions" outside of the AH window, the data is only available when the AH is open, so the tooltip should note this limitation. The click action is just `ShowUIPanel(AuctionHouseFrame)` — only works near an AH NPC (WoW enforces proximity server-side). Easy widget with honest limitations noted in tooltip.

---

### 10. Instance / Content Timer
**Type:** New Widget
**Difficulty:** Easy
**Description:** When inside a Mythic+ dungeon, shows the elapsed challenge mode timer in real time (MM:SS format), color-coded relative to the par time: green = still within time, orange = depleting soon, red = over time. Outside of M+ instances, hides automatically or shows a dash. Complements the MplusTimer module at the full-screen level by providing a compact persistent widget slot.
**Notes:** `C_ChallengeMode.GetActiveChallengeMapID()`, `C_ChallengeMode.GetActiveKeystoneInfo()`, `C_ChallengeMode.GetDeathCount()`. For elapsed time, `C_ChallengeMode.GetActiveKeystoneInfo()` returns time limit. Events: `CHALLENGE_MODE_START`, `CHALLENGE_MODE_COMPLETED`, `CHALLENGE_MODE_RESET`. Use the 1-second widget ticker to refresh the counter. Show only when `instance` visibility condition is active. Easy since the data is well-exposed.

---

### 11. Profession Cooldown Tracker
**Type:** New Widget
**Difficulty:** Medium
**Description:** Displays the cooldown status of crafting profession daily/weekly cooldowns (e.g. Transmutation cooldowns for Alchemy, unique crafts in other professions). Shows something like "Profs: 2/3 ready" with a tooltip listing each profession cooldown by name and remaining time. Useful for players who use multiple crafting professions on one character.
**Notes:** Profession cooldowns are tracked via `GetSpellCooldown` on specific spell IDs tied to each profession's daily. The challenge is mapping profession IDs to their cooldown spells — this requires a static table of known cooldown spell IDs per profession. `C_TradeSkillUI.GetProfessionInfo(professionIdx)` provides the player's profession list. Events: `TRADE_SKILL_UPDATE`, `SPELL_UPDATE_COOLDOWN`. Medium due to the static mapping table maintenance requirement and potential seasonal changes to cooldown spell IDs.

---

### 12. Warband / Account Progress Summary
**Type:** New Widget
**Difficulty:** Medium
**Description:** Displays a summary of Warband (account-wide) progress: total warband reputation with key factions, Warband bank gold (already shown in Bags tooltip but not as a standalone widget), and number of Warband-unlocked achievements. Clicking opens the Warband bank or the Collections journal. Shows something like "WB: Rep 42 | 1.2k" where Rep is the number of major warband factions at max renown and the second figure is Warband bank gold in thousands.
**Notes:** `C_Bank.FetchDepositedMoney(Enum.BankType.Account)` for warband gold. `C_Reputation` for warband reputation — filter to warband-flagged factions using `C_Reputation.GetFactionData(factionID).isAccountWide`. `C_MajorFactions` for renown levels. Events: `CURRENCY_DISPLAY_UPDATE`, `UPDATE_FACTION`. Medium because identifying which factions are "warband" factions reliably requires either API filtering or a static list.

---

## Existing Widget Improvements (8)

---

### 13. Improvement to Mail
**Type:** Improvement of Mail
**Difficulty:** Easy
**Description:** The Mail widget currently only shows "Mail" (green) or "No Mail" (grey) with no count or detail. Improve it to show the number of unread messages (e.g. "Mail: 3") and color-code: green for mail with attachments or gold, white for ordinary mail, grey for no mail. The tooltip should show a count breakdown: "3 letters, 1 with gold, 2 with items."
**Notes:** `GetInboxNumItems()` returns the count only when the mailbox is open. `HasNewMail()` is always available. When the mailbox is open, iterate `GetInboxHeaderInfo(index)` for each mail to get subject, sender, money attached, and item count. Store this in a cached table on `MAIL_INBOX_UPDATE`. Between mailbox visits the count remains from cache. The display degrades gracefully to "Mail" / "No Mail" when the mailbox has never been opened this session.

---

### 14. Improvement to Bags
**Type:** Improvement of Bags
**Difficulty:** Easy
**Description:** The Bags widget currently only shows free slot count ("Bags: 12"). Improve the display to show both free and total slots ("Bags: 12/36") and optionally add a color gradient: green when plenty of space, yellow below 20% free, red below 10% free. The tooltip already has gold data — this is purely a display improvement.
**Notes:** `C_Container.GetContainerNumSlots(bag)` gives total slots, `C_Container.GetContainerNumFreeSlots(bag)` gives free slots. Already iterated in `UpdateContent` — just add a total counter alongside the free counter. No new events needed. The color threshold comparison is trivial. Very low risk change.

---

### 15. Improvement to Durability
**Type:** Improvement of Durability
**Difficulty:** Easy
**Description:** The Durability widget shows lowest durability as a percentage ("Durability: 72%") but gives no visual warning. Improve it to color the text: green above 80%, yellow 50–80%, red below 50%. Also add the estimated repair cost to the widget text itself when below 80% (e.g. "Dur: 45% 12g") so users do not need to hover for cost context. The repair cost is already cached via `MERCHANT_SHOW`.
**Notes:** The cached repair cost from `GetRepairAllCost()` at merchant visits is already in place. The color logic already exists in the tooltip code — move it to `UpdateContent`. When cachedRepairCost is nil (no merchant visited), omit cost from main text. No new events or API required.

---

### 16. Improvement to PvP
**Type:** Improvement of PvP
**Difficulty:** Easy
**Description:** The PvP widget shows "H: X C: Y" (honor and conquest) but provides no visual context about weekly caps. Improve the display to show percentage toward the weekly conquest cap rather than a raw number (e.g. "PvP: 75%") and color it red/yellow/green based on cap proximity. The tooltip already shows full honor and conquest detail. Additionally, show a small "WM" indicator when War Mode is active.
**Notes:** `C_WeeklyRewards.GetConquestWeeklyProgress()` returns progress and maxProgress for the weekly conquest cap. `C_PvP.IsWarModeDesired()` for War Mode status. All data is already fetched in the tooltip block — refactor into the cache refresh to drive the main display text too. No new events needed.

---

### 17. Improvement to SessionStats
**Type:** Improvement of SessionStats
**Difficulty:** Easy
**Description:** The SessionStats widget shows elapsed session time ("Session: 1:23:45") which is useful but the tooltip calculates gold/hr and XP/hr on demand. Improve the main widget text to cycle every few seconds between: session time, gold/hr rate, and (if leveling) XP/hr rate. This gives the user at-a-glance economic and leveling feedback without hovering. The cycle can be a simple modulo on a frame counter.
**Notes:** All the data is already computed in the tooltip handler. Move the gold/hr and XP/hr calculations into `UpdateContent` and use a local cycle counter incremented each tick. Three display modes cycle every 5 seconds: session time → gold/hr → XP/hr (skip XP at max level). The cycling counter requires no new state beyond a local variable.

---

### 18. Improvement to XPRep
**Type:** Improvement of XPRep
**Difficulty:** Medium
**Description:** The XPRep widget shows XP percentage or watched faction but has no progress bar visual. Improve it by adding an optional thin colored bar underneath the text — a texture that fills proportionally to XP or rep progress. This gives an at-a-glance visual indicator without requiring a separate XP bar module. The bar should be configurable (show/hide) via the config panel.
**Notes:** Create a texture child on the widget frame set to a fraction of the frame width using `bar:SetWidth(frame:GetWidth() * percent)`. The frame already has a `bg` texture used for drag highlighting — add a second `progressBar` texture at a different sub-layer. The config option needs a checkbox in the WidgetsPanel for this widget. The main challenge is keeping the bar width synchronized when the frame is resized during anchor layout recalculation. Medium due to the config panel integration and layout interaction.

---

### 19. Improvement to Keystone
**Type:** Improvement of Keystone
**Difficulty:** Medium
**Description:** The Keystone widget shows the current keystone dungeon and level, and the tooltip shows party keystones from AddonComm data. Improve the main widget text to show a color based on potential rating gain: green if timing this key gives a rating upgrade, grey if it does not. Also add the estimated score gain to the main text when it is positive (e.g. "Key: Ara +14 |cFF00FF00+45|r"). Currently the gain is only shown in the tooltip.
**Notes:** `Widgets.EstimateRatingGain(mapID, keystoneLevel)` is already available and called in `UpdateContent`. The return value `gain` drives the color. The `mapID` is returned from `GetPlayerKeystone()` but `UpdateContent` currently discards it — store it in a local `lastKeystoneMapID` alongside the existing `lastKeystoneName` to avoid re-scanning bags on every tick. Medium because the bag scan path needs to be refactored to cache mapID efficiently.

---

### 20. Improvement to Zone
**Type:** Improvement of Zone
**Difficulty:** Medium
**Description:** The Zone widget shows the current subzone or zone name. Improve it to also show a small PvP status indicator inline — appending "(PvP)" in red for contested/hostile zones or "(Sanc)" in green for sanctuary zones. Additionally, when inside an instance, show the difficulty abbreviation (e.g. "Ara | M" for Mythic) rather than the raw subzone name. This turns the zone widget into a true context display.
**Notes:** `C_PvP.GetZonePVPInfo()` returns pvpType ("contested", "hostile", "sanctuary", "friendly", "combat"). `GetInstanceInfo()` provides instanceType and difficultyName. Both are already used in the tooltip — lift them into `RefreshZoneCache`. The instance difficulty abbreviation table (M, H, N, LFR, etc.) needs a small static lookup or substring of the difficultyName. The risk is text overflow on narrow widget frames — test with a width cap or truncation. Medium due to text formatting edge cases.

---

## Review Notes — Unplanned New Widgets (2026-03-01)

These widgets shipped without being in the original suggestions list. Notes for completeness.

### Speed (`widgets/Speed.lua`) — ✅ Implemented, Clean
Uses `C_PlayerInfo.GetGlidingInfo()` for skyriding speed and `GetUnitSpeed("player")` for ground/swim/flight. Refreshes at 0.5s via an `elapsed` accumulator in `HookScript("OnUpdate")`. Uses `HookScript` on an addon-created frame where `SetScript` would be more appropriate (minor style issue, #42 in codereview.md). `BASE_SPEED = 7` yards/sec is correct. The skyriding speed is shown as a percentage of base run speed which may produce values >100% — intentional and accurate for skyriding.

### Volume (`widgets/Volume.lua`) — ✅ Implemented, Clean
Left-click toggles `Sound_EnableAllSound`. Right-click cycles master volume at 100→75→50→25→100%. Tooltip shows all channel volumes. `UpdateContent` reads CVars every second — CVars are cheap to read. Reads CVars with `GetCVar()` which is safe. No issues identified.

### BattleRes (`widgets/BattleRes.lua`) — ✅ Implemented, Minor Notes
Tracks the shared battle res pool via `C_Spell.GetSpellCharges(20484)` (Druid Rebirth spell ID). This correctly reflects the shared pool for all classes since WoW routes all combat res charges through this spell's charge data. The `difficultyID ~= 17` (LFR) check is correct. See issue #41 in codereview.md for context on non-druid players and tooltip clarity.

### Coordinates widget (`widgets/Coordinates.lua`) — ✅ Implemented, Clean
Simple widget complement to the full `Coordinates.lua` module. Calls `C_Map.GetBestMapForUnit("player")` and `C_Map.GetPlayerMapPosition()` every 1s — both are lightweight. Uses correct UTF-8 em dash decimal escapes for the "no data" fallback. No issues identified.

---
