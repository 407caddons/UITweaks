# Future Feature Suggestions for LunaUITweaks

Based on a comprehensive review of the entire addon codebase (Core, ObjectiveTracker, Vendor, Loot, Combat, Misc, Frames, TalentReminder, Kick, ChatSkin, AddonComm, AddonVersions, MinimapCustom, Widgets, and all widget modules including the new Hearthstone widget), the following features are suggested for future development.

---

## 1. Profile System (Import/Export Settings)

**Description:** Allow users to save, load, and share their entire `UIThingsDB` configuration as named profiles. Include the ability to export settings as a serialized string that can be shared with other players (copy/paste in-game) and import them back. Profiles would let users quickly switch between raid, M+, and casual UI layouts.

**Integration:** Add a new "Profiles" tab in the Config UI. On export, serialize `UIThingsDB` into a compact string (Base64-encoded). On import, decode and merge into `UIThingsDB`, then call all module `UpdateSettings()` functions. Store profile names in a separate SavedVariable table to avoid polluting the main settings.

**Ease of Implementation:** Hard -- Requires building a reliable serializer/deserializer for nested Lua tables (including color values), a new Config panel with profile management (create, rename, delete, export, import), and careful handling of version migration when settings structure changes between addon versions.

---

## 2. Nameplate Enhancements Module

**Description:** Add customizable nameplate modifications: show class colors on enemy player nameplates, add a current health percentage text overlay, highlight nameplates of targets casting interruptible spells (colored glow), and optionally show debuff icons applied by the player on nameplates.

**Integration:** Create a new `Nameplates.lua` module that hooks into `NAME_PLATE_UNIT_ADDED` and `NAME_PLATE_UNIT_REMOVED` events. Use the existing module pattern (register on addon table, add settings to `DEFAULTS`, add a Config panel tab). The Kick module's interrupt spell database could be reused to identify interruptible casts.

**Ease of Implementation:** Hard -- Nameplate manipulation is one of the most complex areas of WoW addon development due to Blizzard's CompactUnitFrame system, taint issues, and performance concerns with many active nameplates. Debuff tracking requires aura scanning per nameplate on each `UNIT_AURA` event.

---

## 3. Cooldown Tracker Widget

**Description:** A new widget that displays the remaining cooldown of the player's important abilities (defensive cooldowns, major DPS cooldowns, trinkets) as small icon+timer bars. The user would configure which spells to track, and the display would show only abilities currently on cooldown.

**Integration:** Add a new widget file `widgets/Cooldowns.lua` following the established `Widgets.moduleInits` pattern. Settings would include a list of tracked spell IDs per spec, icon size, bar width, and grow direction. The widget would use `C_Spell.GetSpellCooldown()` and an `OnUpdate` handler (throttled to 0.1s like the Kick module's update loop) to refresh cooldown timers.

**Ease of Implementation:** Medium -- The widget infrastructure already exists and is well-designed. The main work is building a spell selection UI in Config and efficiently polling cooldowns. Needs careful handling of GCD vs. actual cooldowns, and `issecretvalue()` checks during combat.

---

## 4. Damage/Healing Meter Widget (Simple)

**Description:** A lightweight damage/healing meter widget showing a simple bar chart of party/raid members' DPS/HPS during the current encounter. Not intended to replace Details! or Recount, but to provide a quick glance without another addon. Session-based only (no persistent history).

**Integration:** New widget file `widgets/DamageMeter.lua`. Would use `ENCOUNTER_START`/`ENCOUNTER_END` events to scope encounters (similar to PullCounter widget). However, note that `COMBAT_LOG_EVENT_UNFILTERED` is restricted to Blizzard-only code per the CLAUDE.md conventions. This means the addon would need to parse `CHAT_MSG_ADDON` damage reports from other addon users, or use the `UNIT_SPELLCAST_SUCCEEDED` approach -- making this significantly limited.

**Ease of Implementation:** Hard -- The `COMBAT_LOG_EVENT_UNFILTERED` restriction is a severe limitation. Without it, accurate damage tracking is not feasible for a third-party addon in WoW 12.0. This feature would be blocked unless the restriction changes or an alternative API becomes available.

---

## 5. Auction House Favorites / Saved Searches

**Description:** Extend the existing AH filter feature to let users save commonly searched items or search terms as favorites. A small panel would appear alongside the AH showing saved searches that can be clicked to instantly fill the search bar and apply filters.

**Integration:** Extend `Misc.lua` or create a new `AuctionHouse.lua` module. Store favorites in `UIThingsDB.misc.ahFavorites` as an array of `{name, filters}` objects. Hook `AUCTION_HOUSE_SHOW` (already done for the current expansion filter) and create a side panel that attaches to `AuctionHouseFrame`. Clicking a favorite would set the search text and trigger a search.

**Ease of Implementation:** Medium -- The AH hook infrastructure is already partially built. The challenge is correctly interacting with the AH search bar API (`AuctionHouseFrame.SearchBar`), handling filter state, and building a favorites management UI. The AH frame's internal API is not fully documented and can change between patches.

---

## 6. Auto-Screenshot on Achievement/Kill

**Description:** Automatically take a screenshot when significant in-game events occur: earning an achievement, completing a Mythic+ key, killing a raid boss (first kill or personal best time), or reaching a new M+ rating milestone.

**Integration:** Create a small `Screenshots.lua` module. Listen for `ACHIEVEMENT_EARNED`, `CHALLENGE_MODE_COMPLETED`, `ENCOUNTER_END` (with success=1), and `MYTHIC_PLUS_NEW_WEEKLY_RECORD`. Call `Screenshot()` with a configurable delay (0.5-2 seconds) to allow the achievement popup to render. Settings in `UIThingsDB.misc` with toggles per trigger type.

**Ease of Implementation:** Easy -- Very straightforward event-driven implementation. The `Screenshot()` API is simple and the events are well-documented. The only nuance is adding a small delay so popups are visible in the screenshot.

---

## 7. Role/Ready Check Announcer

**Description:** When you are the party/raid leader, provide quick buttons or slash commands to initiate ready checks, role checks, and countdowns. Show a compact results panel for ready check responses. Optionally auto-announce ready check results to chat ("4/5 ready, waiting on PlayerX").

**Integration:** Add to `Misc.lua` or a new `GroupTools.lua` module. Use `READY_CHECK`, `READY_CHECK_CONFIRM`, `READY_CHECK_FINISHED` events for tracking. The ready check panel could be a simple frame with player name + status icons. For countdowns, use `C_PartyInfo.DoCountdown()`. Add a config section under the Misc panel.

**Ease of Implementation:** Easy -- The APIs are straightforward (`DoReadyCheck()`, `C_PartyInfo.DoCountdown()`). The ready check response tracking uses simple event handlers. The UI would be a compact results frame similar to the existing Kick tracker's layout.

---

## 8. Instance Lock / Saved ID Tracker Widget

**Description:** A new widget that shows the player's current raid/dungeon lockouts. On hover, display a tooltip listing all active instance locks with boss kill progress, time remaining until reset, and difficulty. Clicking could open the Blizzard Raid Info panel.

**Integration:** New widget `widgets/Lockouts.lua` using the `Widgets.moduleInits` pattern. Use `GetNumSavedInstances()`, `GetSavedInstanceInfo()`, and `GetSavedInstanceEncounterInfo()` APIs. Register `UPDATE_INSTANCE_INFO` and `PLAYER_ENTERING_WORLD` events. The tooltip would use the same `SmartAnchorTooltip` pattern as other widgets.

**Ease of Implementation:** Easy -- The saved instance APIs are stable and well-documented. The widget framework handles all positioning, font, and lock/unlock logic. The tooltip-based display is the same pattern used by Vault, Keystone, and MythicRating widgets.

---

## 9. Loot Spec Quick-Switch

**Description:** Add a small clickable indicator (or extend the existing Spec widget) that lets the user quickly change their loot specialization. Show the current loot spec icon, and on click, display a dropdown to switch between specs and "Current Spec" mode. Helpful for players farming specific items in raids.

**Integration:** Extend the existing `widgets/Spec.lua` widget or create `widgets/LootSpec.lua`. Use `GetLootSpecialization()`, `SetLootSpecialization()`, and `GetSpecializationInfo()`. The dropdown would use `MenuUtil.CreateContextMenu()` (already used in ChatSkin for language selection). Show an icon overlay or text suffix indicating when loot spec differs from active spec.

**Ease of Implementation:** Easy -- Simple API calls, minimal UI work. The Spec widget already exists as a model. `SetLootSpecialization()` is a straightforward call. The main work is creating an intuitive click/dropdown interaction.

---

## 10. Custom Sound Alerts for Events -- PARTIALLY DONE

**Description:** Allow users to configure custom sound alerts for various game events beyond what currently exists. For example: play a sound when a rare spawn appears, when a world boss is pulled nearby, when the player's health drops below a threshold, when a party member dies, or when specific buffs expire. Users would pick from a list of built-in WoW sounds or enter a sound file ID.

**Integration:** Create a new `SoundAlerts.lua` module. Use events like `VIGNETTE_MINIMAP_UPDATED` (rares), `UNIT_HEALTH` (health threshold), `UNIT_AURA` (buff expiry tracking), `PARTY_KILL` or `COMBAT_LOG_EVENT_UNFILTERED` (party death -- note: CLEU is restricted). Store alert configurations in `UIThingsDB.misc.soundAlerts`. Provide a Config panel with event selection, threshold sliders, and a sound picker using `PlaySound()` for preview.

**What has been done:** ChatSkin now supports keyword highlight sounds -- when a keyword match is found in chat, `PlaySound(3081)` is triggered (controlled by `UIThingsDB.chatSkin.highlightSound`). This covers the chat-based sound alert use case.

**What remains:** Non-chat sound alerts (rare spawns, health thresholds, buff expiry, party deaths) are not yet implemented. A dedicated SoundAlerts module with a flexible configuration UI for multiple event types would complete this feature.

**Ease of Implementation:** Medium -- The event handling is straightforward, but building a flexible alert configuration UI with sound preview is non-trivial. The `COMBAT_LOG_EVENT_UNFILTERED` restriction limits what combat events can be monitored. Health-based alerts need throttled `UNIT_HEALTH` polling.

---

## 11. Tooltip Enhancements

**Description:** Enhance the default game tooltip with additional information: show item level on player tooltips, display the target's M+ score (via the existing `C_ChallengeMode` API), add spec icons next to player names, show guild rank for guild members, and optionally move the tooltip to a fixed position on screen.

**Integration:** Create a `TooltipEnhance.lua` module that hooks `GameTooltip` via `TooltipDataProcessor.AddTooltipPostCall()` (WoW 12.0 tooltip data API). Use `C_PlayerInfo.GetPlayerMythicPlusRatingSummary()` for M+ scores on player tooltips. Settings in `UIThingsDB.misc.tooltip` with toggles per enhancement. Fixed positioning would override `GameTooltip`'s default anchor.

**Ease of Implementation:** Medium -- Tooltip hooking in modern WoW uses the `TooltipDataProcessor` system which is well-structured. The M+ score API is reliable. The complexity comes from handling all tooltip types correctly (unit, item, spell) without breaking other addons' tooltip modifications, and from the sheer number of edge cases in tooltip positioning.

---

## 12. Death Recap / Damage Taken Log

**Description:** When the player dies, show a compact window listing the last 5-10 sources of damage taken before death, including the ability name, source, damage amount, and timestamp. Similar to Blizzard's death recap but cleaner and always available (Blizzard's version can be unreliable).

**Integration:** New `DeathRecap.lua` module. However, this feature faces the same `COMBAT_LOG_EVENT_UNFILTERED` restriction noted in CLAUDE.md. Without access to the combat log, tracking incoming damage sources is not feasible for third-party addons. An alternative approach could use `UNIT_HEALTH` events with delta tracking, but this only shows net health changes, not individual damage sources.

**Ease of Implementation:** Hard -- Blocked by the `COMBAT_LOG_EVENT_UNFILTERED` restriction. Without combat log access, an accurate death recap is not possible. The `UNIT_HEALTH` delta approach would be a very rough approximation and likely not useful enough to implement.

---

## 13. Group Finder Enhancement / Auto-Decline

**Description:** When listing or searching in the Group Finder (Premade Groups), add filters to auto-decline applicants below a certain item level or M+ score, or auto-hide groups with certain keywords in their title. Show applicant M+ scores inline in the applicant list.

**Integration:** Create a `GroupFinder.lua` module that hooks into `LFGListFrame` when it loads. Use `C_LFGList` APIs for group/applicant data. The auto-decline feature would use `C_LFGList.DeclineApplicant()`. Settings stored in `UIThingsDB.misc.groupFinder`. Hook `LFG_LIST_APPLICANT_LIST_UPDATED` for real-time filtering.

**Ease of Implementation:** Medium -- The `C_LFGList` API is comprehensive but complex, with many edge cases around applicant state transitions. Auto-decline needs careful throttling to avoid API spam. The UI hooks on the Group Finder frame require knowledge of the internal frame structure, which can change between patches.

---

## 14. Profession Cooldown Tracker Widget

**Description:** A widget that tracks profession-related cooldowns (daily/weekly transmutes, crafting charges, etc.) across all characters. Show which professions have available cooldowns and when locked ones reset. Useful for alts management.

**Integration:** New widget `widgets/ProfessionCooldowns.lua`. Use `C_TradeSkillUI` APIs to query profession cooldowns. The cross-character aspect would require storing cooldown data per character name in `UIThingsDB.widgets.professionCooldowns.characters`. Events: `TRADE_SKILL_UPDATE`, `PLAYER_ENTERING_WORLD`. Display similar to the Weekly Reset widget with countdown timers.

**Ease of Implementation:** Medium -- Querying profession cooldowns requires the tradeskill UI to be loaded/available, which is not always the case. Cross-character tracking needs careful SavedVariable management. The profession API landscape in TWW is still evolving with the new profession system. Note: the new `Reagents.lua` module (cross-character reagent tracking via `LunaUITweaks_ReagentData` SavedVariable) provides related infrastructure for per-character profession data that could be leveraged.

---

## 15. Minimap Ping Tracker

**Description:** When a party member pings the minimap, show a small notification with the pinger's name (class-colored) and optionally the approximate direction. Useful in dungeons and raids where minimap pings can be missed.

**Integration:** Add to `Misc.lua` or `MinimapCustom.lua`. Listen for `MINIMAP_PING` event which provides `(unit, x, y)`. Create a small notification frame similar to the existing alert frames (personal orders, mail). Class-color the name using `RAID_CLASS_COLORS`. Auto-dismiss after a configurable duration.

**Ease of Implementation:** Easy -- The `MINIMAP_PING` event is simple and provides all needed data. The notification UI can follow the same pattern as `ShowAlert()` in Misc.lua. Minimal settings needed (enable/disable, duration).

---

## 16. Emote Wheel / Quick Emote Panel

**Description:** A radial or grid panel of frequently used emotes accessible via a keybind or widget click. Users can customize which emotes appear. Useful for RP and social interactions without typing `/wave`, `/bow`, etc.

**Integration:** New widget `widgets/Emotes.lua` or standalone module. Create a panel similar to the Teleports widget panel (using the same button pool pattern). Each button sends `DoEmote("WAVE")` etc. Store customized emote list in `UIThingsDB.widgets.emotes.list`. The panel uses `UISpecialFrames` for Escape-to-close behavior.

**Ease of Implementation:** Easy -- `DoEmote()` is a simple API. The panel UI can closely follow the Teleports widget's submenu pattern with button pools. The only design work is choosing a good default emote set and building the customization interface.

---

## 17. Quest Item Bar

**Description:** A horizontal or vertical bar that automatically displays clickable buttons for quest items in the player's bags. When you have quest items with "Use:" effects, they appear as actionable buttons (similar to the small quest item buttons in the default objective tracker, but larger and more prominent).

**Integration:** Create a `QuestItemBar.lua` module. Scan bags for quest items with `GetQuestLogSpecialItemInfo()` or check item types via `GetItemInfo()`. Create `SecureActionButtonTemplate` buttons (must be pre-created out of combat). Use `BAG_UPDATE_DELAYED` and `QUEST_LOG_UPDATE` to refresh. The ObjectiveTracker already has quest item button logic (`btn.ItemBtn`) that can serve as a reference.

**Ease of Implementation:** Medium -- The secure button requirements mean buttons must be pre-created and attributes can only be set out of combat (same pattern used by Combat Reminders' pet/consumable icons). Bag scanning for quest items is straightforward, but handling the combat lockdown edge cases requires careful coding.

---

## 18. Dungeon Timer Overlay (M+ Timer)

**Description:** A customizable M+ dungeon timer that shows elapsed time, time remaining for +2/+3 thresholds, current trash percentage, and death count with time penalty. More prominent and configurable than the default Blizzard timer.

**Integration:** New `DungeonTimer.lua` module. Use `C_ChallengeMode` APIs: `GetActiveKeystoneInfo()`, `GetCompletionInfo()`, `GetActiveChallengeMapID()`. Track deaths via addon communication (similar to how Kick uses `AddonComm`). Events: `CHALLENGE_MODE_START`, `CHALLENGE_MODE_COMPLETED`, `CHALLENGE_MODE_RESET`, `SCENARIO_CRITERIA_UPDATE` (for trash %). Use an `OnUpdate` handler for the running timer.

**Ease of Implementation:** Medium -- The `C_ChallengeMode` API provides good data for the timer itself. Trash percentage tracking via scenario criteria is reliable. Death counting is the hardest part since `COMBAT_LOG_EVENT_UNFILTERED` is restricted; would need to use `UNIT_HEALTH` checks or group death events. The UI work for a clean timer display is moderate.

---

## 19. Casting Bar Replacement -- DONE

**Description:** A customizable player casting bar with options for: repositioning, resizing, custom colors per spell school, cast time text, latency indicator, spell icon display, and interrupt immunity indicator. Could also show target's cast bar with similar customizations.

**Status:** Fully implemented in `CastBar.lua` with a comprehensive config panel in `config/panels/CastBarPanel.lua`. Features include:
- Repositioning (draggable + exact X/Y/anchor controls with sub-pixel precision)
- Resizing (width/height sliders)
- Custom bar texture selection (dropdown with preview, including dynamic texture discovery)
- Class color support with toggle
- Separate colors for: bar, background, border, channel, non-interruptible, and failed/interrupted states
- Spell icon display with configurable size
- Spell name and cast time text with font/size/outline customization
- Spark animation on cast completion
- Empower cast support (Evoker)
- Combat-safe Blizzard cast bar hiding via `RegisterStateDriver` + `SetPointBase` hook

**Remaining potential extensions:** Target cast bar, latency indicator overlay, spell school-specific colors (currently uses a single bar color or class color rather than per-school colors like Fire=orange, Frost=blue, etc.).

---

## 20. Anchor/Dock System for Layout Frames

**Description:** Extend the existing Frames module to allow custom layout frames to dock to each other, creating linked frame groups that move together. Currently, frames are independent rectangles. Docking would let users create complex UI panel arrangements (e.g., a bottom bar made of multiple segments) that stay aligned.

**Integration:** Extend `Frames.lua` to add a `dockTo` property per frame entry. When frame A docks to frame B, A's position is calculated relative to B (with configurable edge: top, bottom, left, right, and offset). When B moves, A follows. The existing `SaveAllFramePositions()` on logout would need to save relative positions for docked frames. The widget anchor system (`isAnchor`, `dockDirection`) already demonstrates a simplified version of this concept.

**Ease of Implementation:** Medium -- The core positioning math is simple (relative offsets). The challenge is in the Config UI for setting up dock relationships (dropdown to pick parent frame, edge selector) and handling edge cases like circular dock references, multi-level dock chains, and the interaction between docking and manual dragging.

---

## 21. Chat Filter / Spam Blocker -- PARTIALLY DONE

**Description:** Filter out common chat spam patterns: gold selling messages, boost advertisements, and repetitive messages. Users could define custom keyword/regex filters. Optionally highlight messages from friends or guild members with custom colors.

**Integration:** Extend `ChatSkin.lua` which already has the message filter infrastructure (`ChatFrame_AddMessageEventFilter`). Add new filters alongside the existing URL detection filter. Store filter rules in `UIThingsDB.chatSkin.filters`. Each rule would have a pattern, action (hide/highlight), and scope (which channels). The friend/guild highlighting would use `C_FriendList.IsFriend()` and `IsGuildMember()`.

**What has been done:** ChatSkin now includes a keyword highlighting system. Users can define keywords in `UIThingsDB.chatSkin.highlightKeywords`, and matching text in chat messages is wrapped in a configurable highlight color (`UIThingsDB.chatSkin.highlightColor`). The `KeywordMessageFilter` function handles case-insensitive matching across all standard chat channels, protecting existing hyperlinks and color codes from modification. An optional sound alert (`UIThingsDB.chatSkin.highlightSound`) plays when a keyword match is found.

**What remains:** Full spam blocking (hiding messages based on patterns), regex support for advanced filtering, friend/guild highlighting with distinct colors, and a rule management UI in the Config panel (add/edit/delete rules with per-rule actions). Currently keywords only highlight -- they cannot hide or mute messages.

**Ease of Implementation:** Easy -- The ChatSkin module already demonstrates the exact pattern needed (`URLMessageFilter` and `KeywordMessageFilter` using `ChatFrame_AddMessageEventFilter`). Adding hide-based filters and expanding the Config UI for rule management is the remaining work.

---

## 22. World Quest Timer / Notification

**Description:** Set alerts for specific world quests that are about to expire. When a tracked WQ has less than a configurable time remaining, show a prominent notification and optionally play a sound or TTS announcement. Useful for time-limited quests with valuable rewards.

**Integration:** Extend the ObjectiveTracker module which already tracks world quests and their time remaining (`C_TaskQuest.GetQuestTimeLeftMinutes()`). Add a check in the existing update loop that compares WQ time remaining against `UIThingsDB.tracker.wqExpiryWarningMinutes`. Show a notification using the same pattern as personal order alerts in `Misc.lua` (TTS + visual alert).

**Ease of Implementation:** Easy -- All the building blocks exist: the ObjectiveTracker already queries WQ time remaining, the alert/TTS system is proven in Misc.lua, and the timer check is a simple comparison. Just needs a settings toggle and threshold slider in the Tracker config panel.

---

## 23. Gold Tracker Widget (Cross-Character)

**Description:** Extend the existing Bags widget (which already tracks gold per character in `UIThingsDB.widgets.bags.goldData`) to show a dedicated gold tracker widget with: current character gold, total gold across all characters, session gold change (earned/spent since login), and gold-per-hour calculation.

**Integration:** New widget `widgets/GoldTracker.lua` or extend `widgets/Bags.lua`. The cross-character gold data infrastructure already exists in `goldData`. Track session start gold on `PLAYER_ENTERING_WORLD`, update on `PLAYER_MONEY`. Calculate gold/hour using `GetTime()` delta from session start. The tooltip would list all characters and their gold (similar to how Bags widget already shows alt gold on hover).

**Ease of Implementation:** Easy -- The hardest part (cross-character gold persistence) is already implemented in the Bags widget. The session tracking is trivial arithmetic. The widget framework handles all display concerns.

---

## 24. Addon Memory Monitor Widget

**Description:** A widget that shows total addon memory usage and, on hover, displays a sorted list of the top memory-consuming addons. Include a button to trigger garbage collection. The existing `showAddonMemory` setting in widgets config suggests this was already considered.

**Integration:** New widget `widgets/AddonMemory.lua`. Use `UpdateAddOnMemoryUsage()`, `GetAddOnMemoryUsage()`, and `GetNumAddOns()`. The `showWoWOnly` and `showAddonMemory` settings already exist in the widgets defaults. Tooltip lists addons sorted by memory (descending). Include a "Collect Garbage" click action calling `collectgarbage("collect")`. Update on a throttled ticker (every 10-30 seconds to avoid performance impact from `UpdateAddOnMemoryUsage()`).

**Ease of Implementation:** Easy -- The APIs are simple and well-documented. The widget framework provides all needed infrastructure. The main consideration is performance: `UpdateAddOnMemoryUsage()` is expensive and should not be called every second.

---

## 25. Talent Loadout Quick-Switch

**Description:** Extend the TalentReminder module to allow one-click switching between saved talent builds from a compact dropdown or bar. Currently the module only reminds about mismatches; this would add proactive switching. Show a small bar of saved build names, and clicking one applies that build.

**Integration:** The TalentReminder module already has `ApplyTalents()` which uses `C_Traits.PurchaseRank()`, `C_Traits.RefundRank()`, `C_Traits.SetSelection()`, and `C_Traits.CommitConfig()`. Create a small bar frame (similar to the widgets) that lists saved builds for the current spec/instance. Each button calls `TalentReminder.ApplyTalents(reminder)`. Filter the list to show only builds matching the current class/spec.

**Ease of Implementation:** Medium -- The talent application logic already exists and works. The challenge is building a reliable quick-switch UI that correctly handles the "cannot change talents in combat" restriction, the M+ lockout on talent changes, and the latency between committing changes and seeing them reflected. Edge cases around rest areas and talent-change-allowed zones need handling.

---

## 26. Objective Tracker Quest Sharing (Share All)

**Description:** The ObjectiveTracker already supports middle-click to share individual quests with the party (via `QuestLogPushQuest()`). This feature would add a "Share All" button in the tracker header that iterates all tracked quests and shares every shareable one with the party at once. Useful when joining a group and wanting to quickly share all available quests.

**Integration:** Add a small button to the tracker header (next to the existing collapse toggle) that, on click, loops through `C_QuestLog.GetNumQuestWatches()`, calls `C_QuestLog.IsPushableQuest()` on each, and pushes shareable quests with a brief delay between sends (to avoid throttling). Use `C_Timer.After` for staggered sharing. The tracker already has the infrastructure for quest iteration and the `OnQuestClick` middle-click share logic to reference.

**Ease of Implementation:** Easy -- All the quest-sharing APIs are already used in the middle-click handler. This is essentially wrapping the same logic in a loop with throttled sends. The only UI work is a small header button.

---

## 27. Widget Profiles

**Description:** Allow saving and loading different widget layouts (positions, enabled states, and per-widget settings) as named profiles. Players could switch between "Raid UI", "Solo Questing", "M+ Layout" etc. with a single click or slash command, instantly reconfiguring which widgets are visible and where they are positioned.

**Integration:** Add a profiles section to the Widgets config panel (or a new "Profiles" sub-tab). Each profile stores a snapshot of `UIThingsDB.widgets` keyed by profile name in a new `UIThingsDB.widgetProfiles` SavedVariable table. "Save Profile" captures the current widget state; "Load Profile" overwrites `UIThingsDB.widgets` and calls `Widgets.UpdateSettings()` on all widgets. Profiles could optionally auto-switch based on instance type (raid, dungeon, open world) using `PLAYER_ENTERING_WORLD` + `GetInstanceInfo()`.

**Ease of Implementation:** Medium -- The data capture/restore is straightforward (deep-copy of the widgets settings table). The complexity is in the Config UI for profile management (save, load, rename, delete, auto-switch rules) and ensuring all widgets correctly reinitialize when their settings are bulk-replaced.

---

## 28. Tracker Quest Notes

**Description:** Allow users to add personal notes to tracked quests via a right-click menu option on the ObjectiveTracker. Notes would appear in the quest's tooltip when hovering over it. Stored in SavedVariables keyed by quest ID, persisting across sessions.

**Integration:** Extend the `OnQuestClick` handler in ObjectiveTracker.lua to support a modifier+click (e.g., Alt+Right-Click) that opens a small input dialog for entering/editing a note. Store notes in `UIThingsDB.tracker.questNotes[questID]`. In the existing tooltip `OnEnter` handler, append the note text as an additional tooltip line. Notes for completed/abandoned quests could be auto-cleaned periodically.

**Ease of Implementation:** Medium -- The tooltip integration is simple (just add a `GameTooltip:AddLine()` call). The input dialog for entering notes requires a small popup frame with an EditBox, following the pattern of the ChatSkin copy frame. Quest note cleanup logic adds some maintenance complexity.

---

## 29. Combat Stats Widget

**Description:** A widget showing basic combat performance metrics using data already available in the addon. Display encounter duration (from the existing CombatTimer module), deaths during the encounter, and interrupt counts (leveraging the Kick module's tracking data). Provides a quick performance summary without needing a full damage meter.

**Integration:** New widget `widgets/CombatStats.lua` using the `Widgets.moduleInits` pattern. Pull encounter duration from `addonTable.Combat` data, death count from `PLAYER_DEAD`/`PLAYER_ALIVE` events, and interrupt data from `addonTable.Kick.interruptCounts`. Register for `ENCOUNTER_START`, `ENCOUNTER_END`, `PLAYER_DEAD`, and `PLAYER_ALIVE`. The tooltip would show a breakdown per encounter. Note: this avoids `COMBAT_LOG_EVENT_UNFILTERED` entirely by reusing data from existing modules.

**Ease of Implementation:** Easy-Medium -- Most data sources already exist in other modules. The main work is wiring up the cross-module data access and building the widget display. No restricted API calls needed.

---

## 30. Loot History Log

**Description:** Keep a scrollable history of recent loot toasts (last 50 items) accessible via a slash command (`/luit loot`) or by clicking the loot toast anchor frame. Session-only storage (resets on reload). Shows item name, quality color, looter name, and timestamp for each entry.

**Integration:** Add a `sessionHistory` table to the Loot module, populated in `SpawnToast()`, `SpawnCurrencyToast()`, and `SpawnGoldToast()` with each toast's data (item link, looter, timestamp, type). Create a scrollable list frame (similar to the ChatSkin copy frame's ScrollFrame pattern) that displays the history. Add an `OnClick` handler to `anchorFrame` to toggle the history panel, and register a slash sub-command in Core.lua. Cap at 50 entries with FIFO eviction.

**Ease of Implementation:** Easy -- The toast creation functions are centralized and already have all needed data. The scroll frame UI pattern exists in ChatSkin. Session-only storage means no SavedVariable complexity. The anchor frame already exists but has no click handler.

---

## Summary Table

| # | Feature | Ease | Status | Notes |
|---|---------|------|--------|-------|
| 1 | Profile Import/Export | Hard | Pending | Serialization complexity |
| 2 | Nameplate Enhancements | Hard | Pending | Taint-sensitive, performance-critical |
| 3 | Cooldown Tracker Widget | Medium | Pending | Widget infra exists, needs spell picker UI |
| 4 | Simple Damage Meter | Hard | Pending | Blocked by CLEU restriction |
| 5 | AH Favorites / Saved Searches | Medium | Pending | AH hook exists, internal API fragile |
| 6 | Auto-Screenshot | Easy | Pending | Simple event + Screenshot() API |
| 7 | Role/Ready Check Announcer | Easy | Pending | Simple events and API calls |
| 8 | Instance Lock Tracker Widget | Easy | Pending | Stable APIs, widget pattern proven |
| 9 | Loot Spec Quick-Switch | Easy | Pending | Simple API, Spec widget as model |
| 10 | Custom Sound Alerts | Medium | **Partial** | Chat keyword sounds done; non-chat alerts remain |
| 11 | Tooltip Enhancements | Medium | Pending | TooltipDataProcessor hooking |
| 12 | Death Recap Log | Hard | Pending | Blocked by CLEU restriction |
| 13 | Group Finder Enhancement | Medium | Pending | Complex C_LFGList API |
| 14 | Profession Cooldown Tracker | Medium | Pending | Cross-char tracking, profession API quirks |
| 15 | Minimap Ping Tracker | Easy | Pending | Simple event, proven notification pattern |
| 16 | Emote Wheel / Quick Panel | Easy | Pending | DoEmote API, Teleports panel as model |
| 17 | Quest Item Bar | Medium | Pending | Secure button combat restrictions |
| 18 | M+ Dungeon Timer Overlay | Medium | Pending | Good API support, death tracking limited |
| 19 | Casting Bar Replacement | Medium | **Done** | Fully implemented with texture picker, combat-safe hiding |
| 20 | Frame Dock System | Medium | Pending | Math is simple, UI/edge cases complex |
| 21 | Chat Filter / Spam Blocker | Easy | **Partial** | Keyword highlighting done; hide/regex/rule UI remain |
| 22 | World Quest Expiry Alerts | Easy | Pending | All building blocks already exist |
| 23 | Gold Tracker Widget | Easy | Pending | Cross-char gold already tracked |
| 24 | Addon Memory Monitor | Easy | Pending | Settings already exist, just needs the widget |
| 25 | Talent Loadout Quick-Switch | Medium | Pending | Apply logic exists, UI + edge cases |
| 26 | Quest Share All Button | Easy | **New** | APIs already used in middle-click handler |
| 27 | Widget Profiles | Medium | **New** | Deep-copy settings + auto-switch rules |
| 28 | Tracker Quest Notes | Medium | **New** | Tooltip integration + input dialog |
| 29 | Combat Stats Widget | Easy-Medium | **New** | Reuses CombatTimer + Kick module data |
| 30 | Loot History Log | Easy | **New** | Session-only, all data already captured |
| 31 | FPS: Network Jitter Display | Easy | **Done** | From widgets.md #11 |
| 32 | Group: Ready Check Display | Easy | **Done** | From widgets.md #13 |
| 33 | Keystone: Best Run Comparison | Easy | **Done** | From widgets.md #14 |
| 34 | Durability: Repair Cost Estimate | Medium | **Done** | From widgets.md #19 |
| 35 | Target Cast Bar | Medium | **New** | Extends CastBar.lua for target unit |
| 36 | Consumable Auto-Purchase | Easy-Medium | **New** | Extends Vendor.lua merchant hook |
| 37 | Notification Center | Medium | **New** | Unified notification panel for all modules |
| 38 | Equipment Set Quick-Switch Widget | Easy | **New** | C_EquipmentSet API, widget pattern |
| 39 | Warband Bank Search/Filter | Medium | **New** | Extends Reagents.lua warband data |
| 40 | Auto-Role Assignment | Easy | **New** | Extends Misc.lua auto-features |
| 41 | Action Bar Paging Indicator Widget | Easy | **New** | Simple event + text widget |
| 42 | Chat Timestamp Format Options | Easy | **New** | Extends ChatSkin message filters |
| 43 | Minimap Calendar / Event Display | Medium | **New** | C_Calendar API, widget or tooltip |
| 44 | Objective Tracker Zone Collapse | Medium | **New** | Extends ObjectiveTracker zone grouping |
| 45 | Interrupt Rotation Suggestions | Hard | **New** | Extends Kick module with AddonComm |
| 46 | Chat Copy Enhancement (Log Export) | Easy-Medium | **New** | Extends ChatSkin copy frame |
| 47 | Loot Toast Anchor Modes | Easy | **New** | Configurable stacking direction |
| 48 | Spec-Specific Widget Visibility | Easy-Medium | **New** | Widget framework visibility extension |
| 49 | AFK/Idle Screen Customization | Medium | **New** | Custom AFK overlay with info panels |
| 50 | Quick Keybind Mode | Medium | **New** | Hover-and-press keybind system |

## 35. Target Cast Bar

**Description:** Extend the existing CastBar module to also display a cast bar for the player's current target. Show the target's spell name, cast time, and whether the cast is interruptible (with a distinct color/glow). The target cast bar would use a separate frame with independent positioning, sizing, and color settings.

**Integration:** Extend `CastBar.lua` to create a second bar frame (`LunaTargetCastBar`). Register `UNIT_SPELLCAST_START`, `UNIT_SPELLCAST_CHANNEL_START`, etc. for `"target"` in addition to `"player"`. Reuse the same `OnUpdate` handler pattern (casting/channeling progress) with target-specific state variables. Add settings under `UIThingsDB.castBar.target` for enabled, width, height, position, colors, and interruptible highlight. The existing `ApplyBarColor()` and `FadeOut()` patterns transfer directly. Add a config sub-section in `CastBarPanel.lua`.

**Ease of Implementation:** Medium -- The casting logic is already proven in CastBar.lua and can be largely duplicated for a target unit. The main complexity is managing target switching (`PLAYER_TARGET_CHANGED` clearing the bar), handling nameplate interactions, and building a clean config panel that doesn't bloat the existing cast bar settings. The interruptible highlight ties nicely into the Kick module's interrupt database.

---

## 36. Consumable Auto-Purchase at Vendors

**Description:** When visiting a vendor, automatically purchase configured consumables (food, flasks, weapon enchantments, augment runes) up to a specified stack quantity. Useful for players who always want to keep a certain number of consumables on hand and currently have to manually buy them each time.

**Integration:** Extend `Vendor.lua` which already hooks `MERCHANT_SHOW`. Add a configurable list of item IDs in `UIThingsDB.vendor.autoBuy` (array of `{itemID, targetCount}`). On `MERCHANT_SHOW`, scan the merchant's inventory with `GetMerchantNumItems()` / `GetMerchantItemInfo()`, check bag counts with `GetItemCount()`, and call `BuyMerchantItem()` for needed quantities. Add a Config section with an "Add Item" input (item ID or shift-click link) and target count slider.

**Ease of Implementation:** Easy-Medium -- The vendor event hook and bag counting are straightforward. `BuyMerchantItem()` is a simple API. The main UI work is building the "add item to auto-buy list" interface with item link resolution and a scrollable list in the Vendor config panel.

---

## 37. Notification Center

**Description:** Consolidate all addon notifications (personal orders, mail alerts, bag space warnings, durability warnings, talent mismatches, WQ expiry alerts) into a unified notification panel. Notifications stack vertically in a small sidebar, each with an icon, message, and timestamp. Clicking a notification performs a relevant action (e.g., open mail, open talents). Old notifications auto-dismiss after a configurable time.

**Integration:** Create a new `NotificationCenter.lua` module with a public API: `addonTable.NotificationCenter.Push(icon, title, message, onClick, duration)`. Replace direct `print()` and `ShowAlert()` calls in Misc.lua, Vendor.lua, and TalentReminder.lua with calls to this centralized system. The notification panel would be a scrollable frame anchored to a screen edge (configurable). Store settings in `UIThingsDB.misc.notifications`.

**Ease of Implementation:** Medium -- The notification frame UI is moderate work (animated stacking, auto-dismiss timers, click handlers). The bigger challenge is retrofitting existing modules to use the central API without breaking their current standalone behavior. A gradual migration approach (modules can opt-in) would reduce risk.

---

## 38. Equipment Set Quick-Switch Widget

**Description:** A widget that shows clickable icons for the player's saved equipment sets (from the Blizzard equipment manager). One click equips the set. The tooltip shows set name and which items differ from current gear. Useful for tanks/DPS who frequently swap sets between pulls.

**Integration:** New widget `widgets/EquipmentSet.lua` using `Widgets.moduleInits`. Use `C_EquipmentSet.GetEquipmentSetIDs()`, `C_EquipmentSet.GetEquipmentSetInfo()` for listing sets, and `C_EquipmentSet.UseEquipmentSet()` for equipping. Cannot use `SecureActionButtonTemplate` since `UseEquipmentSet` is a protected function; must check `InCombatLockdown()` before calling. Show set icons in a horizontal row. Tooltip uses `C_EquipmentSet.GetItemLocations()` to diff current vs. set items.

**Ease of Implementation:** Easy -- The equipment set API is simple and well-documented. The widget framework handles positioning. The only restriction is the combat lockdown check (cannot equip during combat), which is a standard guard.

---

## 39. Warband Bank Search/Filter

**Description:** Add a search bar overlay to the Warband (account) bank that filters items by name as you type. Highlight matching items and dim non-matching ones. Optionally, show a count of how many of a searched item exist across all bank tabs without having to manually click through each one.

**Integration:** Create a new `WarbandBank.lua` module or extend `Reagents.lua` (which already scans warband bank contents). Hook `BANKFRAME_OPENED` / `PlayerInteractionManager` to detect bank opening. Create a search EditBox that overlays the bank frame. On text input, iterate visible bank slots using `C_Container` APIs, compare item names via `GetItemInfo()`, and adjust slot alpha for non-matches. Cross-tab counting leverages the existing `LunaUITweaks_ReagentData.warband.items` data.

**Ease of Implementation:** Medium -- The bank slot iteration and item name matching are straightforward. The challenge is correctly overlaying the search UI on Blizzard's bank frame (which has changed significantly in TWW with the warband bank redesign) and handling the alpha/highlight visuals without taint.

---

## 40. Auto-Role Assignment on Group Join

**Description:** Automatically set the player's role (Tank/Healer/DPS) when joining a group, based on their current specialization. Eliminates the need to manually click the role popup. Optionally auto-accept role checks from the leader.

**Integration:** Add to `Misc.lua`. Listen for `ROLE_POLL_BEGIN` and call `UnitSetRole("player", role)` where role is determined by `GetSpecializationRole(GetSpecialization())`. For auto-accepting role checks, use `ConfirmRolePoll()`. Add toggles in `UIThingsDB.misc` for `autoRole` and `autoAcceptRoleCheck`. The existing Misc module already handles auto-invite, so auto-role fits naturally alongside it.

**Ease of Implementation:** Easy -- `GetSpecializationRole()` and `UnitSetRole()` are simple one-line calls. The `ROLE_POLL_BEGIN` event handler is minimal. This is a very small feature that provides consistent quality-of-life improvement.

---

## 41. Action Bar Paging Indicator Widget

**Description:** A small widget that shows which action bar page is currently active (page 1-6), and optionally the stance/form that triggered the page change. Useful for classes with multiple stances or macros that switch action bar pages, where the player may lose track of which bar is active.

**Integration:** New widget `widgets/ActionBarPage.lua`. Use `GetActionBarPage()` to get current page. Listen for `ACTIONBAR_PAGE_CHANGED` and `UPDATE_BONUS_ACTIONBAR` events to detect page switches. Optionally show stance name via `GetShapeshiftForm()` / `GetShapeshiftFormInfo()`. Display as a simple text widget or icon+number using the standard widget framework.

**Ease of Implementation:** Easy -- Trivial event handling and API calls. The widget framework handles all display infrastructure. This is essentially a two-event widget with a single text display.

---

## 42. Chat Timestamp Format Options

**Description:** Extend the ChatSkin module to offer configurable timestamp formats beyond the default. Options would include: 12-hour vs. 24-hour, seconds precision, date inclusion, relative time ("5m ago"), and custom format strings. The existing chat skin infrastructure already modifies messages via filters.

**Integration:** Extend `ChatSkin.lua`'s message filter pipeline. Add `UIThingsDB.chatSkin.timestampFormat` with presets ("HH:MM", "HH:MM:SS", "h:MM AM/PM", "relative"). Use `date()` with the selected format string in the existing `ChatFrame_AddMessageEventFilter` callback. The Blizzard `CHAT_TIMESTAMP_FORMAT` cvar could be overridden, or timestamps can be prepended manually to each message in the filter.

**Ease of Implementation:** Easy -- ChatSkin already filters messages. Adding a timestamp prepend with a configurable format is a minor extension. The `date()` function supports all standard format specifiers. A dropdown in the ChatSkin config panel with format presets is minimal UI work.

---

## 43. Minimap Calendar / Event Display

**Description:** Show upcoming in-game calendar events (holidays, raid resets, guild events, custom events) as a compact list on minimap hover or as a small overlay near the minimap. Highlight today's events. Useful for players who forget to check the calendar for seasonal events or guild activities.

**Integration:** Extend `MinimapCustom.lua` or create `widgets/Calendar.lua`. Use `C_Calendar.GetNumDayEvents()`, `C_Calendar.GetDayEvent()`, and `C_Calendar.GetDate()` to query upcoming events. `C_Calendar.OpenCalendar()` must be called once to populate the data (already called by the Blizzard minimap button handler). Display as a tooltip on minimap hover (hooking the existing minimap tooltip) or as a standalone widget with event icons and countdown timers.

**Ease of Implementation:** Medium -- The Calendar API requires `C_Calendar.OpenCalendar()` to be called first, which has timing constraints. Event data parsing is straightforward but verbose (filtering holidays vs. raid resets vs. custom events). The tooltip display is simple; a full widget with event icons is more work.

---

## 44. Objective Tracker Zone Collapse

**Description:** Automatically collapse quest groups in the ObjectiveTracker when the player leaves the zone those quests belong to, and re-expand them when returning. The tracker already groups quests by zone; this adds smart visibility management so only relevant quests are expanded, reducing visual clutter.

**Integration:** Extend `ObjectiveTracker.lua` which already groups quests by `zoneOrSortKey`. In the existing `UpdateContent()` function, compare each group's zone against the player's current zone (from `C_Map.GetBestMapForUnit("player")` or `GetMinimapZoneText()`). Auto-collapse groups for non-current zones and auto-expand the current zone's group. Store manual collapse overrides in `UIThingsDB.tracker.manualCollapses` so user preferences are respected. Add a toggle in tracker settings.

**Ease of Implementation:** Medium -- The zone-to-group mapping already exists in the tracker. The logic for auto-collapse is a zone comparison + a `SetCollapsed()` call per group. The complexity is in respecting manual user overrides (if a player manually collapses their current zone's quests, don't auto-expand), and handling edge cases like quests with no zone or quests in the player's current zone that span subzones.

---

## 45. Interrupt Rotation Suggestions (Kick Module Extension)

**Description:** Extend the Kick module to suggest an interrupt rotation order for the party. Based on party members' interrupt cooldowns (already tracked), suggest which player should interrupt next, and optionally display a "next up" indicator on the Kick tracker. This could be a simple round-robin assignment or a smart ordering based on remaining cooldown times.

**Integration:** Extend `Kick.lua` which already tracks all party members' interrupt cooldowns and spell data. Add a rotation calculation function that sorts party members by remaining cooldown time (lowest first = next interrupter). Display a highlight or arrow icon on the player who should interrupt next. Optionally broadcast the suggested order via `AddonComm` so all party members with the addon see the same suggestion. Add settings for rotation mode (round-robin, cooldown-based, manual assignment) in the Kick config panel.

**Ease of Implementation:** Hard -- While the cooldown data exists, building a reliable rotation system requires consensus between party members (who all need to see the same order). Network latency in addon communication means suggestions may arrive out of sync. Edge cases include: players with multiple interrupt abilities, pets with interrupts, players who miss their turn, and the interaction with boss cast times. This is a substantial feature with significant coordination complexity.

---

## 46. Chat Copy Enhancement (Full Log Export)

**Description:** Extend the ChatSkin copy feature to support exporting the full chat session log (not just visible messages). Include options to filter by channel, time range, and sender. Export as plain text or with timestamps. Useful for reporting harassment, sharing raid strategy discussions, or reviewing missed messages.

**Integration:** Extend `ChatSkin.lua` which already has a copy frame with a ScrollFrame and EditBox. Add a `sessionLog` table that captures all messages passing through the `ChatFrame_AddMessageEventFilter` pipeline (already hooked for URL detection and keyword highlighting). Each entry stores: `{timestamp, sender, channel, message, rawMessage}`. The export UI adds filter checkboxes (channels, time range) and a "Copy Filtered" button that populates the EditBox with matching messages. Cap at ~500 messages with FIFO eviction to prevent memory growth.

**Ease of Implementation:** Easy-Medium -- The message capture is trivial (append to a table in the existing filter function). The export UI extends the existing copy frame. The filtering logic is simple string matching. Memory management with FIFO eviction is straightforward. The main consideration is ensuring the message filter doesn't slow down chat with the additional table insert.

---

## 47. Loot Toast Anchor Modes

**Description:** Add configurable anchor modes for loot toasts: stack from top-down vs. bottom-up, left-side vs. right-side growth, or attach to a custom layout frame (from the Frames module). Currently toasts grow upward from a fixed anchor. This would allow users to position toasts in any screen corner with appropriate stacking direction.

**Integration:** Extend `Loot.lua`'s `AcquireToast()` and positioning logic. Add `UIThingsDB.loot.growDirection` ("UP", "DOWN") and `UIThingsDB.loot.anchorFrame` (optional reference to a custom frame from `UIThingsDB.frames.list`). In the toast stacking code, reverse the offset direction when growing down. When anchored to a custom frame, use that frame as the anchor parent instead of `anchorFrame`. Add dropdown options in the Loot config panel.

**Ease of Implementation:** Easy -- The stacking logic is a sign change on the Y offset in `AcquireToast()`. Custom frame anchoring requires looking up the frame from the pool by index. The config UI is a simple dropdown with 2-4 options. All existing toast functionality remains unchanged.

---

## 48. Spec-Specific Widget Visibility

**Description:** Allow individual widgets to be configured as visible only for certain specializations. For example, show the PvP widget only when in PvP spec, show the Keystone widget only in DPS spec, or hide the Combat widget when in healing spec. Each widget would have a "Show for specs" multi-select in its settings.

**Integration:** Extend `widgets/Widgets.lua`'s visibility logic. Add `UIThingsDB.widgets.[widgetKey].showForSpecs` as an array of spec IDs (empty = show always). In the widget update ticker, check `GetSpecialization()` against the allowed list. Register `PLAYER_SPECIALIZATION_CHANGED` to immediately toggle widget visibility on spec change. Add a multi-checkbox section in each widget's config panel entry (reusing the spec listing from TalentReminder's class/spec logic).

**Ease of Implementation:** Easy-Medium -- The visibility check is a simple table lookup. The spec change event is already used by other modules (TalentReminder, Combat). The config UI requires adding a spec checkbox group to each widget's settings, which is repetitive but uses existing helper patterns from `config/Helpers.lua`. The framework change in `Widgets.lua` is minimal.

---

## 49. AFK/Idle Screen Customization

**Description:** When the player goes AFK, show a customizable overlay with useful information: current time, character name/level/ilvl, guild message of the day, pending mail count, current gold, and a "Back" button. Optionally dim the game view behind the overlay. Replaces Blizzard's default AFK camera spin with a more informative display.

**Integration:** Create a new `AFKScreen.lua` module. Listen for `PLAYER_FLAGS_CHANGED` and check `UnitIsAFK("player")`. When AFK starts, create/show a full-screen frame with the configured info widgets (reusing data from existing modules: gold from Bags widget, mail from Mail widget, ilvl from ItemLevel widget). When AFK ends (player moves or presses a key), hide the overlay. The overlay disables the default AFK camera via `SetView(1)` or `MoveViewLeftStop()`. Settings in `UIThingsDB.misc.afkScreen`.

**Ease of Implementation:** Medium -- The AFK detection is simple. The overlay frame is straightforward. The challenge is interacting with Blizzard's camera system (the AFK camera spin uses protected functions in some cases), pulling data from multiple widget modules cleanly, and ensuring the overlay doesn't interfere with combat or loading screens. The "Back" button needs to clear the AFK flag via `SendChatMessage("", "AFK")`.

---

## 50. Quick Keybind Mode

**Description:** Add a "Quick Keybind" mode accessible via `/luit keybind` that lets the player hover over action bar buttons and press a key to bind it, without opening the full Blizzard keybinding interface. Show a tooltip on hover indicating the current binding and the slot number. Press Escape to unbind, press any other key to set the new binding.

**Integration:** Create a new `QuickKeybind.lua` module or extend `ActionBars.lua`. Enter keybind mode by creating an overlay frame that captures all key presses via `SetPropagateKeyboardInput(false)`. On `OnKeyDown`, determine which action button is under the cursor using `GetMouseFocus()`, then call `SetBinding(key, "ACTIONBUTTON"..slot)` or `SetBindingClick(key, buttonName)`. Show current bindings as overlay text on each action button while in keybind mode. `SaveBindings(2)` persists changes. Exit mode on Escape double-press or right-click.

**Ease of Implementation:** Medium -- The keybinding API (`SetBinding`, `SaveBindings`) is simple. The key capture overlay is well-established pattern. The complexity is in handling modifier keys (Shift, Ctrl, Alt combinations), detecting which button is being hovered (different bar addons structure buttons differently), conflict detection (warning when overwriting existing binds), and ensuring combat safety (bindings cannot be changed during combat lockdown).

---

### Related Items Implemented Elsewhere

The following features from this list or the widgets list have been fully implemented:

- **Loot Item Level / Upgrade Indicator** (was #10 in this list) -- DONE in `Loot.lua`. Shows item level with color-coded upgrade comparison (`[ilvl +diff]` in green for upgrades, grey for downgrades, yellow for equal).
- **Hearthstone Widget** (was #3 in widgets.md) -- DONE in `widgets/Hearthstone.lua`. Clickable SecureActionButton that randomly selects from all owned hearthstone toys, shows cooldown, and provides a tooltip with destination and cooldown status.
- **Loot Spec / Spec Quick-Switch Widget** (was #5 in widgets.md) -- DONE in `widgets/Spec.lua`.
- **Casting Bar Replacement** (#19 in this list) -- DONE in `CastBar.lua`. Full custom player cast bar with repositioning, resizing, bar texture picker, class colors, spell icon, cast time text, empower support, and combat-safe Blizzard bar hiding via `RegisterStateDriver` + `SetPointBase` hook. Config panel in `config/panels/CastBarPanel.lua` with texture dropdown featuring live preview.
- **Cross-Character Reagent Tracking** (related to #14) -- DONE in `Reagents.lua`. Scans bags/character bank/warband bank, stores per-character data in `LunaUITweaks_ReagentData` SavedVariable, injects reagent counts into item tooltips via `TooltipDataProcessor`. Config panel in `config/panels/ReagentsPanel.lua`.

### Recommended Priority (Quick Wins)

The following features offer the highest value-to-effort ratio, leveraging existing infrastructure:

1. **Auto-Screenshot** (#6) -- Trivial to implement, universally appreciated
2. **Quest Share All Button** (#26) -- All APIs already in use, just a loop + button
3. **Auto-Role Assignment** (#40) -- Two API calls, fits naturally in Misc.lua
4. **Loot History Log** (#30) -- Data already captured, scroll frame pattern exists
5. **Loot Toast Anchor Modes** (#47) -- Sign change on Y offset, minimal config UI
6. **World Quest Expiry Alerts** (#22) -- All building blocks exist in ObjectiveTracker + Misc
7. **Gold Tracker Widget** (#23) -- Cross-character gold already persisted in Bags widget
8. **Equipment Set Quick-Switch Widget** (#38) -- Simple API, proven widget pattern
9. **Instance Lock Tracker Widget** (#8) -- Proven widget pattern, stable API
10. **Addon Memory Monitor** (#24) -- Settings already exist, just needs the widget
11. **Chat Timestamp Format Options** (#42) -- Minor ChatSkin extension, one dropdown
12. **Loot Spec Quick-Switch** (#9) -- Spec widget + simple API
13. **Action Bar Paging Indicator Widget** (#41) -- Two events, one text display
14. **Minimap Ping Tracker** (#15) -- Simple event, small feature
15. **Combat Stats Widget** (#29) -- Reuses data from CombatTimer and Kick modules
