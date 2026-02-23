# Widget Ideas & Improvements - LunaUITweaks

**Date:** 2026-02-22 (Updated: Session 4 — review pass, 7 new ideas added, no new widgets implemented this session)
**Previous Review:** 2026-02-22
**Current Widgets (35):** Time, FPS, Bags, Spec, Durability, Combat, Friends, Guild, Group, Teleports, Keystone, WeeklyReset, Coordinates, BattleRes, Speed, ItemLevel, Volume, Zone, PvP, MythicRating, Vault, DarkmoonFaire, Mail, PullCounter, Hearthstone, Currency, SessionStats, Lockouts, XPRep, Haste, Crit, Mastery, Vers, WaypointDistance, AddonComm

**New Standalone Modules (not widgets):** MplusTimer -- full M+ timer overlay. QuestAuto -- auto accept/turn-in quests. QuestReminder -- zone-based quest pickup reminders. TalentManager -- dedicated talent build management panel. Coordinates -- waypoint management with `/lway` command. SCT -- scrolling combat text (extracted from Misc.lua). **Warehousing** -- cross-character bag management with bank sync and mailbox routing (NEW 2026-02-22).

Ease ratings: **Easy** (few hours), **Medium** (1-2 days), **Hard** (3+ days)

---

## Changes Since Last Review (2026-02-22, Session 4)

No new widgets implemented this session. Review pass only — 7 new ideas added in sections 21–27 below based on gap analysis of 35 existing widgets. All Session 3 widgets confirmed present in the codebase (Haste, Crit, Mastery, Vers, WaypointDistance, AddonComm). Warehousing.lua and WarehousingPanel.lua confirmed present as untracked files in git status.

---

## Changes Since Last Review (2026-02-22, Session 3)

**6 new widgets added (+6), widget count 29 → 35.**

- **NEW: widgets/Haste.lua** — `GetHaste()`, shows `Haste: X.X%`. Tooltip shows all 4 secondary stats. Event: `COMBAT_RATING_UPDATE`.
- **NEW: widgets/Crit.lua** — `GetCritChance()`, shows `Crit: X.X%`. Same full-stats tooltip.
- **NEW: widgets/Mastery.lua** — `GetMasteryEffect()`, shows `Mastery: X.X%`. Same full-stats tooltip.
- **NEW: widgets/Vers.lua** — `GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE)`, shows `Vers: X.X%`. Tooltip also shows mitigation (vers/2). Same full-stats tooltip.
- **NEW: widgets/WaypointDistance.lua** — Distance to active waypoint. Uses `C_Map.GetUserWaypoint()` matched against `UIThingsDB.coordinates.waypoints`. Distance via coordinate math (YARDS_PER_UNIT=100). 8-directional arrow via `math.atan2`. 0.5s OnUpdate for real-time updates. Cross-map detection shows "other zone".
- **NEW: widgets/AddonComm.lua** — Shows `Luna: X/Y` group addon adoption. Tooltip shows per-member version with class colors (green=same, orange=different, gray=none). Left-click broadcasts presence. Uses `addonTable.AddonVersions.GetPlayerData()`.
- **UPDATED: widgets/Currency.lua** — Configurable currency list. Users add IDs via editbox in the panel popup; custom IDs stored in `UIThingsDB.widgets.currency.customIDs`. Reset button reverts to DEFAULT_CURRENCIES. Remove buttons per row for custom entries.
- **UPDATED: widgets/SessionStats.lua** — Added gold/hr (`goldDelta / elapsed * 3600`) and XP/hr (`UnitXP` snapshot at login). XP/hr only shown for non-max-level characters (`UnitXPMax > 0`). Includes "To level" time estimate. Both metrics only shown after 60s of session. Reset on right-click also snapshots XP.
- **FIXED: widgets/MythicRating.lua** — Dungeon breakdown tooltip now shows `+N timed (score)` or `+N ot (score)`. Was broken due to wrong field name (`bestRunLevel` → `level` per `C_MythicPlus.GetSeasonBestForMap` API). Overtime-only runs flagged with `ot`.
- **Core.lua** — Added defaults for all 6 new widgets. `currency` default gains `customIDs = {}`. `addonComm` defaults to `condition = "group"`.
- **LunaUITweaks.toc** — 6 new widget file entries after `XPRep.lua`.
- **config/panels/WidgetsPanel.lua** — 6 new rows in widget list table.

---

## Changes Since Last Review (2026-02-22, Session 2)

No new widgets this session. New standalone module added:

- **NEW: Warehousing.lua** (~950 lines) + **WarehousingPanel.lua** (~400 lines) -- Cross-character bag management module (not a widget). Tracks overflow/deficit across characters, deposits to Warband Bank/Personal Bank when at a banker, routes excess items to alts via mailbox. CharacterRegistry in Core.lua centralizes character tracking shared with Reagents. Bank sync retry logic and auto-continuation added (resolves multi-click sync issue with split stacks).

**Widget count unchanged: 29.** No widgets added or removed.

---

## Changes Since Last Review (2026-02-22, Session 1)

Git commit `a094160 Updates for v1.13` -- 17 files changed, 2094 insertions, 675 deletions. Widget-relevant changes:

- **widgets/Lockouts.lua** (+18 lines) -- Polished implementation. Now has proper `ApplyEvents(enabled)` pattern with Register/Unregister on `UPDATE_INSTANCE_INFO` and `PLAYER_ENTERING_WORLD`. Tooltip shows raids and dungeons separately with per-boss kill status for raids, difficulty names, extended lockout indicator, and time remaining. OnClick properly toggles `RaidInfoFrame`.
- **widgets/SessionStats.lua** (+40 lines) -- Major reliability overhaul. Added staleness detection: sessions auto-reset if offline >30 minutes or if switching characters (tracked via `charKey = UnitGUID("player")`). Data persisted via `SaveSessionData()` called on every counter update. `lastSeen` timestamp updated every tick for accurate staleness checks. `goldNeedsSnap` flag ensures gold baseline captured on first `PLAYER_ENTERING_WORLD`.
- **widgets/Time.lua** (+2 lines) -- Now respects `UIThingsDB.minimap.minimapClockFormat` for 12H/24H display, sharing the setting with the minimap clock.
- **NEW: Coordinates.lua (standalone module, ~652 lines)** -- Full waypoint management system with `/lway` command, zone name resolution via `C_Map` hierarchy, waypoint list UI with row pooling, paste dialog for bulk import, map integration (`C_Map.SetUserWaypoint`), super-tracking, and a config panel. NOT a widget -- separate module with its own frame.
- **widgets/Coordinates.lua (widget, unchanged)** -- Existing simple coordinates widget (55 lines) still shows player position. The new standalone Coordinates.lua module is separate.
- **NEW: SCT.lua (~249 lines)** -- Scrolling Combat Text extracted from Misc.lua into standalone module. Separate damage/healing anchors, frame pooling (`SCT_MAX_ACTIVE = 30`), `issecretvalue()` guards, target name display, crit scaling.
- **MinimapCustom.lua** (+225 lines) -- Major additions to minimap customization.
- **config/panels/MinimapPanel.lua** (+296 lines) -- Major config panel expansion.
- **config/ConfigMain.lua** (+246 lines) -- Config restructure with new panels for Coordinates and SCT.
- **Core.lua** (+63 lines) -- New defaults for `coordinates` and `sct` settings namespaces.

**Widget count increased from 27 to 29** (Lockouts and XPRep confirmed as full widgets since last count update).

---

## Previous Suggestions - Implementation Status

The following ideas from previous reviews have been implemented or superseded:

- **Loot Spec Widget** - DONE. The Spec widget shows both active spec and loot spec icons side by side.
- **Party Role Widget** - DONE. The Group widget displays tank/healer/DPS counts with role icons and total member count. Also includes ready check tracking and raid sorting.
- **Great Vault Progress Widget (Enhanced)** - DONE. The Vault widget shows per-row progress with slot-by-slot completion in the tooltip.
- **FPS Widget - Add Latency Display** - DONE. The FPS widget displays "XX ms / XX fps" with full addon memory breakdown in tooltip.
- **Durability Widget - Equipment Breakdown** - DONE. Tooltip shows per-slot durability with cached repair cost.
- **Mythic+ Death Counter Widget** - SUPERSEDED by MplusTimer module with per-player death breakdown tooltip.
- **Currency Widget Season Update** - DONE. Updated to TWW Season 3 currencies.
- **M+ Affix Widget** - SUPERSEDED by MplusTimer during runs. Standalone always-visible version carried forward as #3 below.
- **Session Stats Widget** - DONE (2026-02-19). Implemented as `widgets/SessionStats.lua`. Tracks session duration, gold delta, items looted, and deaths. Persists across `/reload`. Right-click resets counters. **Updated 2026-02-22:** Staleness detection, character switching detection, and persistent gold baseline added.
- **Widget Visibility Conditions** - DONE (2026-02-19). `EvaluateCondition()` supports 7 conditions: `always`, `combat`, `nocombat`, `group`, `solo`, `instance`, `world`. Per-widget condition dropdown in config panel. BattleRes and PullCounter default to `instance`.
- **Instance Lockout Widget** - DONE (2026-02-22). Previously suggestion #2. Implemented as `widgets/Lockouts.lua` (164 lines). Shows locked instance count on widget face, tooltip separates raids and dungeons with per-boss kill status, extended lockout indicator, time remaining. Click opens Raid Info panel. Proper `ApplyEvents` pattern.
- **XP / Reputation Widget** - DONE (2026-02-22). Previously suggestion #5. Implemented as `widgets/XPRep.lua` (245 lines). Shows XP percentage with rested indicator for leveling characters, watched reputation with renown level for max-level characters. Tooltip shows full XP breakdown or reputation standing/progress with paragon support.
- **Secondary Stats Widgets (#8)** - DONE (2026-02-22, Session 3). Split into four individual widgets: Haste, Crit, Mastery, Vers. Each shows its stat on the widget face and has a shared full-stats tooltip (all 4 stats + vers mitigation).
- **Addon Communication Status Widget (#11)** - DONE (2026-02-22, Session 3). Implemented as `widgets/AddonComm.lua`. Shows `Luna: X/Y` group adoption. Class-colored per-member version tooltip. Left-click broadcasts presence. Defaults to `condition = "group"`.
- **Waypoint Distance Widget (#12)** - DONE (2026-02-22, Session 3). Implemented as `widgets/WaypointDistance.lua`. Real-time distance with 8-directional arrow. Matches against `UIThingsDB.coordinates.waypoints`, handles cross-map waypoints. 0.5s OnUpdate refresh.
- **Currency Widget - Configurable List (#18)** - DONE (2026-02-22, Session 3). `UIThingsDB.widgets.currency.customIDs` stores user's list. Panel popup has Add/Reset buttons and per-row remove buttons. Falls back to hardcoded DEFAULT_CURRENCIES when empty.
- **SessionStats Gold/XP Per Hour (#19)** - DONE (2026-02-22, Session 3). Gold/hr and XP/hr added to tooltip. XP/hr includes "To level" estimate. Both require >60s session and non-zero data to display. `xpAtLogin` snapshot persisted via `SaveSessionData()`.
- **MythicRating dungeon level display** - FIXED (2026-02-22, Session 3). `bestRunLevel` → `level` (correct field name per API). Now shows `+N timed (score)` or `+N ot (score)` per dungeon.

---

## Won't Do

### DPS Meter Widget — Won't Do
**Attempted (2026-02-20):** Implemented three iterations using `COMBAT_LOG_EVENT` (blocked — event removed from addon API in 12.0), `UNIT_COMBAT` (abandoned for accuracy), and finally `C_DamageMeter.GetCombatSessionFromType(Current, Dps)`.

**Reason removed:** `C_DamageMeter.amountPerSecond` is a session average (total damage divided by elapsed seconds since combat started), not a rolling-window DPS. The value increments slowly as a running average rather than reflecting burst DPS, and does not agree with other meters. WoW 12.0 removed all `COMBAT_LOG_EVENT_UNFILTERED` / `COMBAT_LOG_EVENT` access for third-party addons entirely. `C_DamageMeter` is the only addon-accessible damage API, and it only exposes session averages. Accurate per-second DPS tracking is not achievable in the addon API as of 12.0.

---

## New Widget Ideas

### 1. Profession Cooldowns Widget
Display active profession cooldowns (transmutes, daily crafts, weekly knowledge). Shows icon for primary profession and a countdown for the nearest cooldown. Tooltip lists all tracked profession cooldowns with time remaining. Could integrate with Reagents module for cross-character cooldown data.
- **Ease:** Medium
- **Rationale:** Requires scanning profession spell cooldowns via `C_TradeSkillUI` and `C_Spell.GetSpellCooldown`. The tricky part is building a reliable list of cooldown-gated recipes across all professions since there is no single API for "all profession cooldowns." Knowledge point weekly resets require tracking quest IDs. However, the core per-spell cooldown check is straightforward once the spell list is established.

### 2. Talent Loadout Widget
Display the name of the current active talent loadout on the widget face. Tooltip shows all saved loadouts with a checkmark on the active one. Left-click opens the talent frame. Right-click opens the TalentManager panel. Warning indicator when current talents do not match any saved loadout, leveraging TalentReminder's `CompareTalents()`.
- **Ease:** Easy-Medium
- **Rationale:** Uses `C_ClassTalents.GetActiveConfigProfile()`. Integration with TalentReminder for mismatch detection adds value. The TalentManager module already builds a full list of saved builds with match status. Leverages the investment in TalentManager and TalentReminder by surfacing loadout awareness at a glance.

### 3. M+ Affix Widget (Always-Visible)
Show the current week's Mythic+ affixes as compact text, visible at all times -- not just during M+ runs. Widget face shows the primary affix name. Tooltip shows all active affixes with full descriptions and icons.
- **Ease:** Easy
- **Rationale:** `C_MythicPlus.GetCurrentAffixes()` returns affix IDs, `C_ChallengeMode.GetAffixInfo()` provides name/description/icon. One of the simplest possible new widgets -- implementable in under 60 lines. Event-driven via `MYTHIC_PLUS_CURRENT_AFFIX_UPDATE`. The MplusTimer shows affixes during active runs, but this serves as a persistent quick reference for planning keys outside dungeons.

### 4. World Boss / Weekly Event Widget
Show the current week's world bosses and whether they have been killed, plus the active weekly bonus event (Timewalking, PvP Brawl, etc.). Tooltip lists each world boss with killed/available status. Click opens the adventure guide.
- **Ease:** Medium
- **Rationale:** World boss completion tracked via rotating quest IDs. Weekly events from `C_Calendar` APIs. Complements WeeklyReset and DarkmoonFaire by covering other rotating content. Maintenance burden: boss-to-questID mapping needs updating each raid tier.

### 5. Calendar / Holiday Widget
Show the next upcoming WoW holiday or calendar event with a countdown. During active holidays, show the holiday name in themed color. Tooltip shows next 3-5 upcoming events with start dates. Click opens the calendar.
- **Ease:** Easy-Medium
- **Rationale:** Uses `C_Calendar` API. The DarkmoonFaire widget already demonstrates the entire countdown pattern. Could subsume DarkmoonFaire as a special case, reducing widget count. Requires `C_AddOns.LoadAddOn("Blizzard_Calendar")` on demand (WeeklyReset already does this on click).

### 6. Buff/Flask Reminder Widget
Show whether the player has well-fed buff, flask/phial, and augment rune active as compact colored indicators (green = active, red = missing, gray = N/A). Tooltip shows specific buff names and remaining durations.
- **Ease:** Medium
- **Rationale:** Requires `C_UnitAuras.GetAuraDataByIndex()` scanning and matching against known buff categories. The Combat module already has buff reminder functionality with category-based detection and `issecretvalue()` guards -- this widget borrows that logic for a compact always-visible version. The `combat` or `instance` visibility condition reduces clutter.

### 7. Warband Gold Tracker Widget
Show total gold across all characters plus Warband Bank balance. Widget face shows combined total in compact format (e.g., "123.4k g"). Tooltip breaks down per-character gold sorted by amount.
- **Ease:** Easy
- **Rationale:** The Bags widget already tracks cross-character gold in `UIThingsDB.widgets.bags.goldData` and fetches `C_Bank.FetchDepositedMoney(Enum.BankType.Account)` for Warband Bank. Zero new API work -- reuses existing data layer entirely. SessionStats' `FormatGoldDelta()` demonstrates gold formatting patterns. Estimated: under 80 lines.

### 8. Secondary Stats Widget — **DONE (2026-02-22, Session 3)**
Implemented as four separate widgets: Haste, Crit, Mastery, Vers. Each shows its individual stat on the face; all share an identical full-stats tooltip. See `widgets/Haste.lua`, `Crit.lua`, `Mastery.lua`, `Vers.lua`.

### 9. Delve Companion Widget
Show Brann companion level and weekly delve completion progress. Widget face displays "Delves: X/Y" for vault progress. Tooltip shows Brann's level, XP to next level, and completed delve tiers.
- **Ease:** Medium
- **Rationale:** Weekly progress partially available via `C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.World)` (Vault widget already uses this). Brann companion APIs less well-documented. High value for TWW seasonal content.

### 10. Personal Loot Tracker Widget
Track items looted during the current session with item level and quality. Widget face shows "Loot: X items". Tooltip lists last 10-15 items with quality color. Right-click clears session log.
- **Ease:** Medium
- **Rationale:** Builds on `CHAT_MSG_LOOT` that SessionStats already uses for counting. Adds item link parsing and storage. Loot module already parses item links via `C_Item.GetDetailedItemLevelInfo()`. Session data stored in capped array to bound memory.

### 11. Addon Communication Status Widget — **DONE (2026-02-22, Session 3)**
Implemented as `widgets/AddonComm.lua`. Shows `Luna: X/Y`. See "Previous Suggestions" above for details.

### 12. Waypoint Distance Widget — **DONE (2026-02-22, Session 3)**
Implemented as `widgets/WaypointDistance.lua`. See "Previous Suggestions" above for details.

### 13. Class Resource Widget
Display the player's class-specific resource on the widget face: combo points, holy power, soul shards, runes, chi, arcane charges, etc. Real-time updates during combat.
- **Ease:** Medium
- **Rationale:** Uses `UnitPower("player", powerType)` and `UnitPowerMax("player", powerType)` with class-specific `Enum.PowerType` mapping. Multi-resource classes (Druids in different forms) add complexity. Needs fast updates via `UNIT_POWER_UPDATE` or OnUpdate handler (Speed widget's 0.5s `HookScript("OnUpdate", ...)` provides the pattern). The `combat` visibility condition is ideal.

### 14. Bags Widget - Reagent Bag & Low Space Warning — **Improvement to existing widget**
Add reagent bag and profession bag free slot counts to the tooltip. Add a color warning when total free space drops below a configurable threshold (red text on widget face when <5 free slots). Optionally show "Bags: 12 (R:8)" format.
- **Ease:** Easy
- **Rationale:** `C_Container.GetContainerNumFreeSlots()` already returns bag type as second value. Extending to reagent and profession bags is trivial. Vendor module already has `bagWarningThreshold` concept. The Bags tooltip already shows gold, currency, and character data -- bag-type breakdown fits naturally.

### 15. Keystone Widget - Weekly Best & Vault Integration — **Improvement to existing widget**
Add weekly best run (if different from season best) and vault progress summary ("Vault M+: 2/8") to the tooltip.
- **Ease:** Easy-Medium
- **Rationale:** `C_MythicPlus.GetWeeklyBestForMap()` for weekly best. `C_WeeklyRewards.GetActivities()` for vault progress (already used by Vault widget). Incremental addition to already rich tooltip. Turns Keystone into a complete M+ dashboard at a glance.

### 16. Hearthstone Widget - Multi-Hearth Selection Menu — **Improvement to existing widget**
Add right-click context menu to choose a specific hearthstone toy instead of random. Show owned toys in a list. Persist preference. Random stays as default left-click.
- **Ease:** Easy-Medium
- **Rationale:** `ownedHearthstones` list already built by `BuildOwnedList()`. `MenuUtil.CreateContextMenu` pattern proven in Spec widget. Needs `InCombatLockdown()` check for `SecureActionButtonTemplate` attribute changes. High user demand -- many players prefer specific hearthstone toys.

### 17. Group Widget - Instance Progress in Tooltip — **Improvement to existing widget**
Add instance progress section: bosses killed/total in dungeons/raids, M+ timer status and death count as compact summary.
- **Ease:** Medium
- **Rationale:** Instance progress via `GetInstanceInfo()` and `C_ScenarioInfo.GetCriteriaInfo()`. M+ data from `C_ChallengeMode` APIs. The Group tooltip is already the most complex (class-colored members, roles, ready check, raid sorting menu). Must avoid duplicating MplusTimer overlay info. Moderate complexity due to multiple data source aggregation.

### 18. Currency Widget - Configurable Currency List — **DONE (2026-02-22, Session 3)**
`UIThingsDB.widgets.currency.customIDs` array. Panel popup has Add (by ID) / Reset buttons and per-row remove buttons. Falls back to DEFAULT_CURRENCIES when empty. See "Previous Suggestions" above for details.

### 19. SessionStats Widget - Gold Per Hour & Extended Metrics — **DONE (2026-02-22, Session 3)**
Gold/hr and XP/hr added to tooltip. XP/hr includes "To level" estimate. `xpAtLogin` snapshot persisted. See "Previous Suggestions" above for details.

### 20. Lockouts Widget - World Boss Tracking & Cross-Character View — **Improvement to existing widget**
Extend the newly implemented Lockouts widget with world boss kill status via `GetNumSavedWorldBosses()` / `GetSavedWorldBossInfo()`. Add cross-character lockout data by saving lockout info per character in `UIThingsDB` (similar to Bags' `goldData` pattern). Tooltip could show "Alt has 5/8 Heroic Nerub-ar Palace saved".
- **Ease:** Medium
- **Rationale:** Advanced by v1.13 improvements. The Lockouts widget now has a solid foundation with raid/dungeon separation, per-boss display, and extended lockout support. Adding world bosses is a few API calls. Cross-character tracking requires saving lockout data on `PLAYER_LOGOUT` and displaying it per-character in the tooltip, following the established Bags/Reagents cross-character pattern.

---

## New Widget Ideas (Session 4, 2026-02-22)

### 21. Interrupt Tracker Widget
Show a compact "Kick: X" count of how many times the player has successfully interrupted this session or in the current instance. Tooltip breaks down by target (mob name) and spell interrupted. Integrates with the existing Kick module which already handles `UNIT_SPELLCAST_INTERRUPTED`.
- **Ease:** Easy
- **Rationale:** The Kick module already listens for interrupt events and tracks cooldowns for party members. Adding a self-interrupt counter is a small extension -- increment a counter each time the player's own interrupt lands (filtered by `unitTarget == "player"` source side). Counter reset on zone change or right-click. Widget face shows "Kick: 5" with tooltip listing mob names and spell IDs. No new event registration needed. Under 70 lines.

### 22. Reagents Summary Widget
Show a quick summary of watched reagents on the widget face (e.g., "Reagents: 3 low"). Tooltip lists each tracked reagent with current vs. minimum threshold and a colored indicator (red = below min, green = above). Left-click opens the Reagents config panel.
- **Ease:** Easy
- **Rationale:** The Reagents module already has `LunaUITweaks_ReagentData` with per-character inventory and threshold data. The widget just reads from that data store -- no new scanning logic required. `REAGENT_BANK_UPDATE` and `BAG_UPDATE_DELAYED` events already used by Reagents module. This is purely a display layer over existing infrastructure. Similar pattern to the AddonComm widget (reads from another module's data without owning it).

### 23. Auction House Snipe Widget
Show the last item the AH filter flagged as a bargain (below configured gold threshold). Widget face shows item name (truncated) and price. Tooltip shows full item name, item level, quality, bid vs buyout, and how far below market value it is. Right-click clears last result.
- **Ease:** Medium
- **Rationale:** The Misc module already has AH expansion filtering. The AH scanning API (`C_AuctionHouse.SendSearchQuery`, `AUCTION_HOUSE_BROWSE_RESULTS_UPDATED`) can drive a price-threshold check when the player has the AH open. Storing the last qualifying result in `UIThingsDB.widgets.ahSnipe` is straightforward. The widget only updates when the AH frame is open -- negligible background cost. Market value comparison requires either a hardcoded threshold or TSM data (hardcoded is simpler). The `world` visibility condition (hide in instances) is appropriate.

### 24. Time Zone / Server Clocks Widget
Show both local time and server time on a single widget face, alternating or side-by-side. Tooltip shows the UTC offset, local timezone abbreviation, and server realm timezone (US/EU). Optionally show a third timezone (user-configurable UTC offset).
- **Ease:** Easy
- **Rationale:** The existing Time widget shows only one clock (local or server based on a toggle). This idea extends it to show both simultaneously. `GetGameTime()` for server time, `date("*t")` for local time. The Time widget already imports `UIThingsDB.minimap.minimapClockFormat` for 12H/24H -- the same setting applies here. Could be implemented as an enhancement to the existing Time widget rather than a new one by adding a "dual clock" display mode toggle.

### 25. Target Health Widget
Show the current target's health as percentage on the widget face ("Target: 45%"). Tooltip shows exact health values (current/max), target name, and level. Automatically hides when no target. Uses the `combat` or `always` visibility condition.
- **Ease:** Easy
- **Rationale:** `UnitHealth("target")` and `UnitHealthMax("target")` are zero-overhead calls. Event-driven via `UNIT_HEALTH` (for target) and `PLAYER_TARGET_CHANGED`. This is genuinely useful for classes that execute abilities at specific health thresholds (Execute, Kill Shot, etc.) without needing to glance at the Blizzard target frame. The `UNIT_HEALTH` event fires frequently in combat, so update logic should cache and only refresh on actual change. The `combat` visibility condition keeps it out of the way while questing.

### 26. Crafting Order Status Widget
Show the number of pending personal crafting orders awaiting fulfillment. Widget face shows "Orders: X pending". Tooltip lists order details: item name, requestor name, skill difficulty, and expiry time. Left-click opens the crafting order UI.
- **Ease:** Medium
- **Rationale:** Uses `C_CraftingOrders.GetPersonalOrders()` and `C_CraftingOrders.RequestOrders()`. The Misc module already handles personal order alerts via TTS/chat notification. This widget provides a persistent always-visible count rather than a one-time alert. The crafting order API requires the crafting UI to be loaded, so `LoadAddOn("Blizzard_Professions")` may be needed on demand. Event-driven via `CRAFTINGORDERS_UPDATED`. Complements the Misc module's one-shot notification.

### 27. Weather / Flight Point ETA Widget
Show the remaining flight time when on a flight path. Widget face shows "Flight: 1:23" counting down in real time. Automatically shows only while on a taxi flight and hides otherwise. No configuration needed -- appears on flight, disappears on landing.
- **Ease:** Easy-Medium
- **Rationale:** Taxi state detectable via `UnitOnTaxi("player")` or the `UNIT_ENTERED_VEHICLE` / `PLAYER_ENTERING_WORLD` with taxi flag. `PLAYER_CONTROL_LOST` fires when mounting the flight path gryphon/wyvern. The duration of a flight path is not exposed by the API directly (no `GetFlightDuration()` equivalent). Approximate countdown can be built by snapshotting start time on `PLAYER_CONTROL_LOST` when `UnitOnTaxi("player")` is true and counting up (showing elapsed rather than remaining). Alternatively, watch for `PLAYER_CONTROL_GAINED` to detect landing. Widget auto-hides when not on taxi via the standard show/hide pattern. Very low overhead (only active during flights). The `always` condition works since the widget self-manages visibility.

---

## Improvements to Existing Widgets (Session 4 Additions)

### 28. FPS Widget - Graph Mode (Improvement to FPS)
Add an optional mini graph mode: draw a sparkline of the last 60 FPS samples as a tiny texture strip on the widget face, showing FPS trend over the last minute. The plain text mode stays as the default.
- **Ease:** Hard
- **Rationale:** Requires drawing via `CreateTexture` pixels or `Line` objects (WoW 9.0+ supports `frame:CreateLine()`). Sampling FPS every second into a circular buffer (60 entries) is trivial. Drawing the sparkline as scaled line segments is the hard part -- each sample maps to a vertical pixel height on a 60-wide strip. Visually appealing but high implementation complexity for moderate information gain.

### 29. Hearthstone Widget - Cooldown Ring (Improvement to Hearthstone)
Add a cooldown ring/arc overlay on the hearthstone widget face showing the remaining hearthstone cooldown visually (like an action button cooldown sweep), in addition to the existing text countdown.
- **Ease:** Medium
- **Rationale:** `GetItemCooldown(itemID)` returns remaining cooldown. A cooldown sweep can be drawn with `SetCooldown` on a `Cooldown` frame object (`CreateFrame("Cooldown", ...)`). The hearthstone widget already has the item ID and updates on `SPELL_UPDATE_COOLDOWN`. Adding a `Cooldown` child frame that mirrors the remaining time would be a significant visual improvement with modest code changes.

### 30. XPRep Widget - Reputation Per Hour (Improvement to XPRep)
Add rep/hr to the XPRep tooltip at max level (similar to how SessionStats shows XP/hr for leveling characters). Track reputation delta since session start and divide by elapsed time.
- **Ease:** Easy
- **Rationale:** The XPRep widget already reads `C_Reputation.GetWatchedFactionData()` on every `UPDATE_FACTION` event. Snapshotting the initial `currentStanding` on session start (or on faction change) and computing the delta is a direct copy of the SessionStats XP/hr pattern. Adds "Rep/hr: 1,240" to the tooltip. Reset when watched faction changes (detect via `data.factionID` mismatch). Under 20 lines of new code.

---

## Widget Framework Improvements

### A. Widget Groups / Snap-to-Grid
Allow grouping multiple widgets into a single bar that moves as one unit. Snap indicators when dragging near other widgets. Grouped widgets share a single drag handle.
- **Ease:** Hard
- **Impact:** Major UX improvement. The existing anchor system (`UpdateAnchoredLayouts`) handles docking to named frames, but widget-to-widget snapping requires collision detection and a new grouping data structure. The `OnDragStop` handler saves CENTER-relative positions, so snap logic intercepts that.

### B. Per-Widget Font Override
Allow individual widgets to override the global font family, size, and color. Each widget's config sub-table already exists. Adding optional `font`, `fontSize`, `fontColor` fields that fall back to global when nil. The `UpdateVisuals()` function already applies global styles per-widget.
- **Ease:** Easy-Medium
- **Impact:** Medium. Enables visual hierarchy. Implementation: modify `UpdateVisuals()` to check `db[key].font or db.font` per property. Per-widget font controls in WidgetsPanel -- perhaps a popup per widget to avoid expanding the panel too much.

### C. Widget Tooltip Anchor Override
Per-widget tooltip position instead of automatic `SmartAnchorTooltip` screen-half detection. Optional `tooltipAnchor` field per widget config.
- **Ease:** Easy
- **Impact:** Small but appreciated. Minimal code change -- override `SmartAnchorTooltip` with a fixed anchor point when the field is set.

### D. Widget Click-Through Mode
Per-widget option to make the widget click-through (non-interactive) when locked. Prevents accidental clicks near action bars. `EnableMouse(false)` when locked with this option. Trade-off: disables tooltip too. Alt+hover could show tooltip in click-through mode. Widgets using `SecureActionButtonTemplate` (Hearthstone, Keystone, Teleports) need special handling.
- **Ease:** Easy
- **Impact:** Medium for users who place widgets near action bars.

### E. Widget Update Interval Configuration
User-configurable ticker interval via a slider. Currently hardcoded as `local updateInterval = 1.0` in Widgets.lua. The Speed widget already runs its own 0.5s OnUpdate, showing per-widget rates are needed in practice.
- **Ease:** Easy
- **Impact:** Low-Medium. Lets users trade CPU for responsiveness.

### F. Widget Background / Padding Option
Per-widget configurable background color and padding. Currently the green drag background is shown only when unlocked. A subtle always-on translucent background option would help widgets stand out against complex UI backgrounds (e.g., placing a widget over the minimap area).
- **Ease:** Easy
- **Rationale:** The `frame.bg` texture already exists on every widget -- it just defaults to hidden when locked. Adding `UIThingsDB.widgets[key].bgAlpha` (0 = off, >0 = always-on with that alpha) and reading it in `UpdateVisuals()` to keep `bg:Show()` with a configurable color/alpha is a trivial extension. The per-widget config sub-table already exists.

---

## Prioritization Summary

**Quickest wins (Easy, highest return on effort):**
- #3 M+ Affix Widget -- under 60 lines, simplest new widget
- #7 Warband Gold Tracker -- reuses existing Bags data layer entirely
- #14 Bags low-space warning -- single conditional added to existing code
- #21 Interrupt Tracker Widget -- reads from existing Kick module events, under 70 lines
- #22 Reagents Summary Widget -- reads from existing ReagentData, purely display layer
- #25 Target Health Widget -- two API calls + two events, trivially simple
- #30 XPRep Rep/hr -- direct copy of SessionStats XP/hr pattern, under 20 lines
- Framework improvement F (widget background) -- `bg` texture already exists, tiny change
- ~~#8 Secondary Stats~~ -- DONE
- ~~#19 SessionStats gold-per-hour~~ -- DONE

**Highest strategic value:**
- #2 Talent Loadout -- leverages TalentManager and TalentReminder investment
- #13 Class Resource -- fills a combat information gap, unique among widgets
- #16 Hearthstone selection menu -- addresses common user desire for toy selection
- #26 Crafting Order Status -- complements existing Misc module notifications
- ~~#12 Waypoint Distance~~ -- DONE
- ~~#18 Currency configurable list~~ -- DONE
