# Widget Ideas and Improvements

20 ideas for new widgets and improvements to existing ones in LunaUITweaks.

**Existing widgets (27 files):** FPS, Bags, Spec, Durability, Time, Coordinates, Speed, Volume, ItemLevel, Friends, Combat, Currency, PvP, Group, Keystone, MythicRating, Teleports, Zone, Mail, PullCounter, DarkmoonFaire, Guild, Hearthstone, Vault, BattleRes, WeeklyReset, Widgets (framework).

---

## New Widgets

### 1. Affix Display Widget

**Description:** Shows the current Mythic+ affixes for the week. The widget text displays abbreviated affix names (e.g., "Fort / Bursting / Xal") and the tooltip provides full affix names with descriptions and icons.

**How it would work:** Use `C_MythicPlus.GetCurrentAffixes()` to retrieve the active affixes each week. For each affix ID, call `C_ChallengeMode.GetAffixInfo(affixID)` to get the name, description, and texture. Update on `PLAYER_ENTERING_WORLD` and `CHALLENGE_MODE_MAPS_UPDATE`. The widget text truncates long names; the tooltip shows icons via `CreateTextureMarkup()` alongside full descriptions. Straightforward data-only widget with no state management.

**Ease of implementation:** Easy -- Two API calls, event-driven updates, simple text formatting. Follows the exact pattern of the MythicRating widget.

---

### 2. Death Counter Widget

**Description:** Tracks deaths during the current session with total time spent dead. Useful for raid progression and M+ to see how much time is lost. Shows "Deaths: 3 (1m 24s)" on the widget face.

**How it would work:** Listen for `PLAYER_DEAD` and `PLAYER_ALIVE`/`PLAYER_UNGHOST` events. Maintain session-only counters: `deathCount`, `deathStartTime`, `totalDeadTime`. When in an active encounter (detected via `ENCOUNTER_START`/`ENCOUNTER_END`), associate deaths with boss names for the tooltip breakdown. Right-click to reset, following the PullCounter pattern. No saved variables needed -- session data only.

**Ease of implementation:** Easy -- Identical architecture to PullCounter. Only requires a few event registrations, simple time arithmetic, and the established right-click-to-reset UX pattern.

---

### 3. Profession Cooldown Tracker Widget

**Description:** Shows remaining time on profession daily/weekly cooldowns (transmutes, concentration regeneration, soulbound craft lockouts). The tooltip lists all tracked profession cooldowns with individual countdowns.

**How it would work:** On `PLAYER_ENTERING_WORLD` and `TRADE_SKILL_COOLDOWN_UPDATE`, scan the player's known professions via `C_TradeSkillUI.GetAllProfessionTradeSkillLines()`. For each profession, enumerate recipes and check `C_TradeSkillUI.GetRecipeCooldown(recipeID)` for active cooldowns. Cache results and display the shortest remaining cooldown as the widget text (e.g., "Cooldowns: 2h 15m"). The tooltip lists each recipe name with its individual countdown. Could extend to cross-character tracking using the same `SavedVariables` pattern as the Bags gold data.

**Ease of implementation:** Medium -- The profession APIs require scanning recipe lists to find which ones have cooldowns. The scanning is not expensive but requires iterating through profession skill lines. Cross-character persistence adds optional complexity.

---

### 4. Rested XP / Experience Widget

**Description:** For characters not at max level, shows current XP progress as a percentage and rested bonus. At max level, auto-hides or shows rested status. Displays "Lv.72 58% (R)" on the widget face. The tooltip shows exact XP values, rested bonus amount, and estimated quests to level.

**How it would work:** Use `UnitXP("player")`, `UnitXPMax("player")`, and `GetXPExhaustion()` for core data. Register `PLAYER_XP_UPDATE`, `UPDATE_EXHAUSTION`, and `PLAYER_LEVEL_UP`. Auto-disable at max level via `IsPlayerAtEffectiveMaxLevel()`. The tooltip shows a progress bar representation using text, the rested XP percentage, and session XP gains (tracked by snapshotting XP on load and comparing).

**Ease of implementation:** Easy -- Simple, well-established API calls. The auto-hide at max level keeps it clean. Follows the same event-driven caching pattern as ItemLevel widget.

---

### 5. Reputation / Renown Tracker Widget

**Description:** Shows progress toward the currently watched faction reputation or Renown level. Displays "Severed Threads 14/25" for Renown factions, or "Honored 4500/12000" for legacy reputations. Tooltip lists recent reputation gains.

**How it would work:** Use `C_Reputation.GetWatchedFactionData()` for the primary tracked faction. For Renown factions, use `C_MajorFactions.GetMajorFactionData(factionID)` to get the current Renown level and progress. Track recent rep gains by hooking `UPDATE_FACTION` and comparing snapshots. Left-click could cycle through recently-interacted factions. The tooltip shows standing, progress fraction, and session rep gains. Register `UPDATE_FACTION`, `MAJOR_FACTION_RENOWN_LEVEL_CHANGED`, and `PLAYER_ENTERING_WORLD`.

**Ease of implementation:** Medium -- The dual reputation systems (legacy vs Renown) require branching display logic. The watched faction API is simple, but cycling through recent factions and tracking session gains adds state management.

---

### 6. Catalyst Charges Widget

**Description:** Shows the player's current Revival Catalyst charges and time until the next charge. The catalyst converts non-set gear into tier set pieces, and charges accumulate weekly -- easy to forget about.

**How it would work:** Use `C_CurrencyInfo.GetCurrencyInfo(catalystCurrencyID)` to get current and max charges. The catalyst currency ID is currently 2912 (may change per season). Time until next charge is derived from `C_DateAndTime.GetSecondsUntilWeeklyReset()`. Display "Catalyst: 2/6 (3d)" on the widget face. The tooltip shows charges, max, and weekly reset countdown. Register `CURRENCY_DISPLAY_UPDATE` and `PLAYER_ENTERING_WORLD`.

**Ease of implementation:** Easy -- Single currency API call plus the weekly reset timer. Follows the exact same pattern as the WeeklyReset widget with an added currency lookup. The only maintenance is updating the currency ID each season.

---

### 7. Profession Knowledge Widget

**Description:** Tracks weekly profession knowledge point sources and completion status. Shows how many knowledge points are still available this week from treasures, first crafts, weekly quests, and treatise turn-ins.

**How it would work:** Maintain a curated table of quest IDs for each knowledge source category per profession. Use `C_QuestLog.IsQuestFlaggedCompleted(questID)` for each source. Detect active professions via `C_TradeSkillUI.GetAllProfessionTradeSkillLines()`. Display a compact summary (e.g., "Knowledge: 4/7") with the tooltip breaking down each source category. Register `QUEST_TURNED_IN` and `PLAYER_ENTERING_WORLD`. The quest ID table would need updates each major content patch.

**Ease of implementation:** Medium -- The quest-based approach is reliable but requires building and maintaining a substantial quest ID table. The scanning and display logic is straightforward once the data table exists. Similar in concept to the DarkmoonFaire quest tracking.

---

### 8. M+ Timer / Dungeon Progress Widget

**Description:** During an active M+ run, shows the elapsed time vs. the time limit and the current enemy forces percentage. Outside M+, shows the last completed run summary. Displays "+12 Mists 18:42/33:00 (87%)" during a run.

**How it would work:** Use `C_ChallengeMode.IsChallengeModeActive()` to detect an active run. `C_ChallengeMode.GetActiveKeystoneInfo()` returns the dungeon and level. For timing, `GetWorldElapsedTime()` returns the elapsed and time limit. Enemy forces percentage comes from the Scenario API: `C_Scenario.GetCriteriaInfo()` for the enemy forces criteria. Register `CHALLENGE_MODE_START`, `CHALLENGE_MODE_COMPLETED`, `SCENARIO_CRITERIA_UPDATE`, and `WORLD_STATE_TIMER_START`. The widget auto-hides when not in M+ (unless showing last run summary). Uses a fast 1s OnUpdate during active runs.

**Ease of implementation:** Medium -- The M+ timer APIs are well-documented but require combining multiple API namespaces (ChallengeMode, Scenario, WorldElapsedTime). The conditional show/hide and fast update during runs adds complexity beyond a simple event-driven widget.

---

### 9. Delve Companion Widget

**Description:** Shows the player's current Brann Bronzebeard (delve companion) level and XP progress. Displays "Brann: Lv 15 (42%)" on the widget face. The tooltip shows XP to next level and available companion abilities.

**How it would work:** Use the `C_DelvesUI` namespace APIs to query companion level, XP progress, and available abilities. Register `PLAYER_ENTERING_WORLD` and relevant delve companion update events. The tooltip shows level, XP bar representation, and a summary of unlocked abilities. Left-click could open the delve companion UI panel.

**Ease of implementation:** Medium -- The `C_DelvesUI` API was introduced in TWW and may have limited documentation. Requires investigation of exact API calls for companion level/XP data. The display logic itself is simple once the correct APIs are identified.

---

### 10. World Boss / Event Timer Widget

**Description:** Tracks active world bosses and weekly world events (timewalking, PvP brawl, etc.) with their remaining durations. Displays the most relevant active event on the widget face (e.g., "Timewalking: 3d 4h"). The tooltip lists all active and upcoming events.

**How it would work:** Use `C_PerksActivities` or `C_Calendar` APIs to enumerate active in-game events. For world bosses specifically, check quest completion flags for the current rotation's world boss. `C_DateAndTime.GetSecondsUntilWeeklyReset()` provides the timer for weekly events. The tooltip lists each event with its type (Timewalking, PvP Brawl, etc.) and time remaining. Register `PLAYER_ENTERING_WORLD` and `CALENDAR_UPDATE_EVENT_LIST`.

**Ease of implementation:** Medium -- Calendar event enumeration requires loading the Blizzard_Calendar addon and iterating events. The world boss rotation detection requires maintaining a quest ID table. Multiple data sources need to be combined for a comprehensive view.

---

## Improvements to Existing Widgets

### 11. FPS Widget: Network Jitter and Packet Loss Display

**Description:** Extend the FPS widget's tooltip to show network jitter (latency variance) and estimated connection quality. Currently shows home/world latency and memory usage. Add a rolling latency history to detect unstable connections.

**How it would work:** Sample `GetNetStats()` latency values each update tick (already running at 1s intervals). Maintain a rolling buffer of the last 30 latency readings. Calculate the standard deviation to estimate jitter. Display in the tooltip as "Jitter: 12ms" with color coding (green < 20ms, yellow < 50ms, red > 50ms). Add bandwidth in/out from `GetNetStats()` to the tooltip as well. The buffer is a simple circular array with no memory allocation after initialization.

**Ease of implementation:** Easy -- No new API calls needed. `GetNetStats()` already returns bandwidth data. The jitter calculation is basic math on a fixed-size array. Adds a few lines to the existing OnEnter tooltip builder.

**Status:** **Done** -- FPS.lua implements `latencyHistory` (circular buffer of 30 samples), jitter standard deviation calculation, and color-coded jitter display in the tooltip. Bandwidth in/out is also shown.

---

### 12. Bags Widget: Bag Type Breakdown in Tooltip

**Description:** Extend the Bags tooltip to show free slots broken down by bag type (normal, mining, herbalism, enchanting, etc.) and total bag capacity. Players with specialty bags often want to see which bags have space.

**How it would work:** In the existing `OnEnter` handler, iterate bags 0 through `NUM_BAG_SLOTS`. For each bag, call `C_Container.GetContainerNumSlots(bag)` for total and `C_Container.GetContainerNumFreeSlots(bag)` for free. Use `C_Container.GetBagName(bag)` to get the bag item name. Group bags by type and display in the tooltip as "Bag 1 (Imbued Silken Bag): 12/32 free". Add a total capacity line at the bottom.

**Ease of implementation:** Easy -- All API calls are already used in the UpdateContent function. This just extends the OnEnter tooltip with per-bag detail. No new events or state management.

---

### 13. Group Widget: Role Check / Ready Check Display

**Description:** When a ready check is in progress, the Group widget should flash or change color to indicate status, and the tooltip should show which players have responded and their status (ready/not ready/away).

**How it would work:** Register `READY_CHECK`, `READY_CHECK_CONFIRM`, and `READY_CHECK_FINISHED` events in the Group widget. During a ready check, scan party/raid members with `GetReadyCheckStatus(unit)` which returns "ready", "notready", or "waiting". Change the widget text to show a ready check indicator (e.g., a green/yellow/red dot prefix). The tooltip during a ready check lists each player with their response status color-coded. After `READY_CHECK_FINISHED`, revert to normal group display.

**Ease of implementation:** Easy -- The ready check API is simple with only three events and one status function. The Group widget already iterates party members. This adds a temporary overlay state during the brief ready check window.

**Status:** **Done** -- Group.lua tracks `readyCheckActive` and `readyCheckResponses` (per-player status). The `UpdateContent` function shows color-coded "Ready: X/Y" during active checks. The tooltip displays a sorted breakdown of player statuses (waiting first, then not ready, then ready). Results persist for 5 seconds after the ready check finishes.

---

### 14. Keystone Widget: Best Run Comparison

**Description:** Extend the Keystone widget tooltip to show how the current key compares to the player's best timed run for that dungeon. Display the potential rating gain/loss and whether timing at this level would be an upgrade.

**How it would work:** The `EstimateRatingGain()` function already exists in `Widgets.lua` and is used in the Keystone tooltip. Extend it to also show the player's current best run level and time for the keystone's dungeon. Use `C_MythicPlus.GetSeasonBestForMap(mapID)` to get `intimeInfo` and `overtimeInfo`, which include `bestRunLevel` and `bestRunDurationMS`. Display in the tooltip as "Current best: +12 (Timed, 28:14) | This key: +14 (est. +18 rating)". This makes it immediately clear whether running the key is worthwhile.

**Ease of implementation:** Easy -- All the API infrastructure exists. `EstimateRatingGain()` already retrieves `currentBest` data. This is purely a tooltip formatting enhancement adding 5-10 lines to the OnEnter handler.

**Status:** **Done** -- Keystone.lua now shows a full "Your Best Run" section in the tooltip, including best level, timed/overtime status, duration formatted as MM:SS, and a level difference comparison ("+2 above your best" / "3 below your best" / "Same level as your best"). Also shows party keystones with estimated rating gains via AddonVersions integration.

---

### 15. Vault Widget: Item Level Rewards Preview

**Description:** Extend the Great Vault widget tooltip to show the expected item level reward for each unlocked slot. Currently shows progress (e.g., "2/8 heroic bosses") but not what item level the reward will be.

**How it would work:** The `C_WeeklyRewards.GetActivities()` data already includes `level` fields on each activity entry. For M+ activities, the `level` is the key level completed; for raid, it corresponds to difficulty. Use `C_WeeklyRewards.GetExampleRewardItemHyperlinks(activityID)` or the activity's `level` field to derive the reward item level. Display in the tooltip next to each slot: "1st Slot: 8/8 (639 ilvl)". Color the item level based on whether it is an upgrade over the player's current equipped ilvl from `GetAverageItemLevel()`.

**Ease of implementation:** Medium -- The `C_WeeklyRewards` API provides the data but mapping M+ level and raid difficulty to item level requires a lookup table that changes each season. The API may provide example hyperlinks that contain the ilvl directly.

---

### 16. Speed Widget: Mount Name and Skyriding Mode Display

**Description:** When mounted, show the name of the current mount alongside the speed percentage. When skyriding, indicate the active flight mode. The tooltip shows recent mounts used and the current flight style.

**How it would work:** Use `IsMounted()` and scan active buffs to identify the current mount spell ID, then cross-reference with `C_MountJournal.GetMountInfoByID()`. Display "Vicious War Riverbeast (142%)" on the widget face when mounted. Use `C_PlayerInfo.GetGlidingInfo()` to detect skyriding mode and show "Skyriding" vs "Steady Flight" in the tooltip. Track the last 5 mounts used in a session-local table. The Speed widget already has fast 0.5s OnUpdate polling for skyriding.

**Ease of implementation:** Medium -- Detecting the current mount requires scanning buffs for mount aura names or using `C_MountJournal` APIs to find which mount is active. The mount detection is not directly supported by a single API call and may require matching the active buff to mount spell IDs.

---

### 17. Currency Widget: User-Configurable Currency List

**Description:** Replace the hardcoded `DEFAULT_CURRENCIES` table in the Currency widget with a user-configurable list. Allow players to pick which currencies they want to track from a dropdown, so the widget remains useful across patches without code updates.

**How it would work:** Add a config panel section for the Currency widget with a multi-select dropdown built from `C_CurrencyInfo.GetCurrencyListSize()` and `C_CurrencyInfo.GetCurrencyListInfo()`. Store selected currency IDs in `UIThingsDB.widgets.currency.trackedCurrencies` (a simple array of currency IDs). Replace all references to `DEFAULT_CURRENCIES` with the user's saved list. Provide a "Reset to Defaults" button that restores the standard TWW currencies. The dropdown can be filtered to show only discovered currencies.

**Ease of implementation:** Medium -- The currency iteration API is straightforward. The main work is building the config UI: a scrollable checkbox list of all discovered currencies. The existing `ConfigHelpers` module provides dropdown and checkbox factory functions that can be adapted.

---

### 18. Friends Widget: Activity Status and Zone Info

**Description:** Extend the Friends tooltip to show what each online friend is currently doing (dungeon name, zone, battleground, etc.) and their character class/level. Currently shows names and levels but not zone/activity details.

**How it would work:** The `C_BattleNet.GetFriendAccountInfo()` API already returns `gameAccountInfo` which includes `areaName` (zone), `richPresence` (activity description), `characterName`, `characterLevel`, and `className`. For WoW friends, `C_FriendList.GetFriendInfoByIndex()` returns `area` (zone name). Add the zone/activity as a second line under each friend entry in the tooltip. Color-code activities (green for open world, orange for dungeons, red for PvP). The API data is already fetched in the current OnEnter handler but the zone/activity fields are not displayed.

**Ease of implementation:** Easy -- The data is already available in the API responses currently being queried. This is purely a tooltip formatting improvement, adding `areaName` or `area` to the existing entries. No new API calls or events.

**Status:** **Done** -- Friends.lua already displays zone/area info for both WoW friends (`info.area`) and BNet friends (`gameAccount.areaName` for WoW, `gameAccount.richPresence` for non-WoW) as indented grey text lines below each friend entry. Class colors are applied to friend names via `C_ClassColor.GetClassColor`.

---

### 19. Durability Widget: Repair Cost Estimate

**Description:** Add an estimated repair cost to the Durability tooltip. Players often want to know how expensive the next repair will be, especially during progression where deaths are frequent.

**How it would work:** Iterate equipment slots (already done in the existing OnEnter handler). For each slot with durability, use `C_TooltipInfo.GetInventoryItem("player", slotID)` and parse the tooltip data for repair cost information, or use the `GetRepairAllCost()` API when at a vendor. Since `GetRepairAllCost()` only works when a vendor window is open, an alternative is to estimate based on item level and durability loss percentage using known formulas. Display "Est. Repair: ~2g 45s" at the bottom of the tooltip. When at a vendor, show the exact cost from `GetRepairAllCost()`.

**Ease of implementation:** Medium -- Exact repair cost is only available at vendors via `GetRepairAllCost()`. Estimation without a vendor requires reverse-engineering Blizzard's repair cost formula (which depends on item level, slot, and quality). A simpler approach is to cache the last known repair cost from the Vendor module's `MERCHANT_SHOW` event.

**Status:** **Done** -- Durability.lua now has a dedicated `repairEventFrame` that listens for `MERCHANT_SHOW`, `MERCHANT_CLOSED`, and `UPDATE_INVENTORY_DURABILITY` events. It caches the exact repair cost from `GetRepairAllCost()` when a merchant is visited, and displays it in the tooltip as either the cached cost (with coin textures via `GetCoinTextureString`) or "Fully repaired" when cost is zero. Live cost is shown when a merchant window is open.

---

### 20. Mail Widget: AH Expired/Sold Notifications

**Description:** Extend the Mail widget to detect and display whether pending mail contains auction house sale proceeds or expired auctions. Shows "Mail: 3 (2 AH Sales)" instead of just "Mail" when auction-related mail is waiting.

**How it would work:** When `HasNewMail()` returns true and the mailbox is opened (`MAIL_INBOX_UPDATE`), scan mail subjects using `GetInboxHeaderInfo(index)` to detect AH-related patterns. Blizzard AH mail has standardized subject lines like "Auction successful:" and "Auction expired:". Count and categorize AH mail separately. Cache the results since `GetInboxHeaderInfo` only works when the mailbox is open. Display "Mail: AH Sales!" on the widget face when AH sales are detected. The tooltip shows the breakdown of mail types.

**Ease of implementation:** Medium -- Mail scanning only works while the mailbox frame is open, so the widget needs to cache results from the last mailbox visit. The subject line pattern matching is simple string operations. The main design decision is how to handle stale cache data (show "Mail" generically when cache is expired, or always show cached details until the next mailbox visit).

---

## Summary Table

| # | Idea | Type | Difficulty | Status |
|---|------|------|------------|--------|
| 1 | Affix Display Widget | New Widget | Easy | |
| 2 | Death Counter Widget | New Widget | Easy | |
| 3 | Profession Cooldown Tracker | New Widget | Medium | |
| 4 | Rested XP / Experience Widget | New Widget | Easy | |
| 5 | Reputation / Renown Tracker | New Widget | Medium | |
| 6 | Catalyst Charges Widget | New Widget | Easy | |
| 7 | Profession Knowledge Widget | New Widget | Medium | |
| 8 | M+ Timer / Dungeon Progress Widget | New Widget | Medium | |
| 9 | Delve Companion Widget | New Widget | Medium | |
| 10 | World Boss / Event Timer Widget | New Widget | Medium | |
| 11 | FPS: Network Jitter Display | Improvement | Easy | **Done** |
| 12 | Bags: Bag Type Breakdown | Improvement | Easy | |
| 13 | Group: Ready Check Display | Improvement | Easy | **Done** |
| 14 | Keystone: Best Run Comparison | Improvement | Easy | **Done** |
| 15 | Vault: Item Level Rewards Preview | Improvement | Medium | |
| 16 | Speed: Mount Name Display | Improvement | Medium | |
| 17 | Currency: User-Configurable List | Improvement | Medium | |
| 18 | Friends: Activity Status | Improvement | Easy | **Done** |
| 19 | Durability: Repair Cost Estimate | Improvement | Medium | **Done** |
| 20 | Mail: AH Expired/Sold Notifications | Improvement | Medium | |

### Changes from Previous Version

- **Item #9 (Warband Bank Balance Widget)** was replaced with **Delve Companion Widget**. The Warband Bank gold display was already implemented directly in the Bags widget tooltip (via `C_Bank.FetchDepositedMoney`), making a separate widget redundant.
- **Item #10 (Calling / World Quest Hub Widget)** was replaced with **World Boss / Event Timer Widget**. The Calling system was removed in TWW and replaced with different weekly/daily systems. A world boss and event timer provides broader utility.
- **Item #18 (Friends: Activity Status)** status updated to **Done**. Code review confirmed that `Friends.lua` already displays zone and activity info for both WoW and BNet friends as indented text below each friend entry.
- All **Done** items now include implementation details confirmed by reading the actual source code.
