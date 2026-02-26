# Widget Ideas — LunaUITweaks
Date: 2026-02-26

## Introduction

This document reviews all 27 existing widgets in LunaUITweaks and proposes 20 ideas: 12 new widgets and 8 improvements to existing ones. Each idea is assessed for difficulty against the WoW 12.0 retail API constraints (no COMBAT_LOG_EVENT_UNFILTERED, no external libraries, combat lockdown rules apply).

The existing widget suite covers: secondary stats (Haste, Crit, Mastery, Versatility), social (Friends, Guild, Group), progression (MythicRating, Keystone, Vault, Lockouts, XPRep), utility (Bags, Currency, Hearthstone, Teleports, Durability, Mail, WaypointDistance, Zone, DarkmoonFaire, PullCounter, SessionStats, Combat, AddonComm), and PvP.

---

## New Widget Ideas (12)

---

### 1. Spec Display
**Type:** New Widget
**Difficulty:** Easy
**Description:** Displays the player's current specialization name and role icon (tank/heal/dps). Clicking opens the Specialization tab of the character window (`ToggleCharacter("PaperDollFrame")` with spec tab). Tooltip shows the active spec name, role, and whether a second spec exists. This fills a visible gap — there is a Group widget showing group role composition but nothing showing your own current spec at a glance.
**Notes:** Use `GetSpecializationInfo(GetSpecialization())` which returns id, name, description, icon, role. Events: `ACTIVE_TALENT_GROUP_CHANGED`, `PLAYER_ENTERING_WORLD`. Straightforward — no combat lockdown concerns for display only.

---

### 2. Clock / Server Time
**Type:** New Widget
**Difficulty:** Easy
**Description:** Shows either local time or server (realm) time, with a toggle between the two on click. Useful for knowing when resets happen, when the Darkmoon Faire starts (currently shown separately in the DMF widget), and when daily/weekly events tick over. The ticker already runs every second via the global widget ticker, so updating the text each tick is free.
**Notes:** `GetGameTime()` returns server hour and minute. For local time use `date("%H:%M")`. A config option for 12h/24h format is a natural addition. The widget ticker updates every second so precision is adequate. No API concerns.

---

### 3. Weekly Reset Countdown
**Type:** New Widget
**Difficulty:** Easy
**Description:** Shows time until the weekly reset (Wednesday 15:00 UTC for EU, Tuesday 15:00 UTC for US). Displays in the format "Reset: 2d 14h" and turns green on reset day. Tooltip shows exact reset time in local time zone. Complements the Vault and Lockouts widgets.
**Notes:** Weekly reset is a known fixed cadence. Use `time()` and `date()` to compute. No special API needed. Similar to the existing DMF countdown logic in DarkmoonFaire.lua — reuse the `FormatCountdown` pattern. Easy adaptation.

---

### 4. FPS / Latency
**Type:** New Widget
**Difficulty:** Easy
**Description:** Displays current FPS and home/world latency in a compact form (e.g. "FPS: 120 | 42ms"). Colors FPS red below 30, yellow below 60. Colors latency red above 200ms, yellow above 100ms. Tooltip breaks out home latency, world latency separately. A classic addon widget that provides at-a-glance performance info.
**Notes:** `GetFramerate()` for FPS, `GetNetStats()` for latency (returns bandwidthIn, bandwidthOut, latencyHome, latencyWorld). Both are available at any time including combat. Updates well from the 1-second ticker. No combat concerns.

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
