# Widget Ideas & Improvements - LunaUITweaks

**Date:** 2026-02-16
**Current Widgets:** Time, FPS, Bags, Spec, Durability, Combat, Friends, Guild, Group, Teleports, Keystone, WeeklyReset, Coordinates, BattleRes, Speed, ItemLevel, Volume, Zone, PvP, MythicRating, Vault, DarkmoonFaire, Mail, PullCounter, Hearthstone, Currency

Ease ratings: **Easy** (few hours), **Medium** (1-2 days), **Hard** (3+ days)

---

## New Widget Ideas

### 1. Profession Cooldowns Widget
Display active profession cooldowns (transmutes, daily crafts, weekly resets). Uses `C_TradeSkillUI` and `C_Spell.GetSpellCooldown` APIs. Show profession icon, cooldown remaining, and tooltip with all tracked cooldowns.
- **Ease:** Medium
- **Hover tooltip:** List of all profession CDs with time remaining

### 2. World Boss / Weekly Event Widget
Show available world bosses and weekly events (Timewalking, PvP Brawl, etc.) with completion status. Uses `C_QuestLog.IsWorldQuestActive` and `C_DateAndTime` APIs.
- **Ease:** Medium
- **Hover tooltip:** List of world bosses with killed/available status

### 3. Loot Spec Widget
Show current loot specialization with icon. Click to cycle through specs, right-click for dropdown. Different from the existing Spec widget - this specifically shows what loot spec is active (which can differ from active spec).
- **Ease:** Easy
- **Uses:** `C_Loot.GetLootSpecialization()`, `SetLootSpecialization()`

### 4. Talent Loadout Widget
Display current talent loadout name. Click to open talent frame, hover to show loadout list. Could show a warning icon when talents don't match any saved loadout.
- **Ease:** Easy-Medium
- **Uses:** `C_ClassTalents.GetActiveConfigProfile()`

### 5. XP/Reputation Bar Widget
Show current XP progress (or reputation if max level) as a mini progress bar with percentage. Click to cycle through tracked reputations. Compact alternative to the default XP bar.
- **Ease:** Medium
- **Includes:** XP remaining, rested XP indicator, rep standing color

### 6. Currency Tracker Widget (Beyond Gold)
Track specific currencies like Valor, Conquest, Crests, Flightstones, etc. User selects which currencies to track. Show icon + count, tooltip shows all tracked currencies with weekly caps.
- **Ease:** Medium
- **Uses:** `C_CurrencyInfo.GetCurrencyInfo()`
- **Note:** A Currency widget file exists (261 lines) - check if this overlaps

### 7. Instance Lockout Widget
Show current instance lockouts (raid saves, dungeon lockouts). Icon shows number of active lockouts, tooltip lists each instance with boss progress.
- **Ease:** Medium
- **Uses:** `GetNumSavedInstances()`, `GetSavedInstanceInfo()`

### 8. Transmog Collection Widget
Show transmog collection progress as a percentage. Hover to see breakdown by armor type, weapon type. Click to open appearance collection.
- **Ease:** Easy-Medium
- **Uses:** `C_TransmogCollection` API

### 9. Auction House Summary Widget
Show number of active auctions, total value, and number of expired/sold items waiting for pickup. Useful for crafters/goblins.
- **Ease:** Medium
- **Uses:** `C_AuctionHouse` API (limited to when AH data is available)

### 10. Movement Speed Widget (Enhanced)
The existing Speed widget shows current speed. Enhance with: mount speed bonus display, swim speed, ghost wolf/travel form indicators, and buff-based speed increases.
- **Ease:** Easy (enhancement of existing)

### 11. Calendar/Event Widget
Show next upcoming calendar event (raid night, holiday, etc.) with countdown. Click to open the calendar. Show holiday icon during active WoW holidays.
- **Ease:** Easy-Medium
- **Uses:** `C_Calendar` API

### 12. Addon Compartment Widget
Mirror the addon compartment buttons as a widget bar. This would let users position addon buttons anywhere, not just near the minimap.
- **Ease:** Medium
- **Challenge:** Intercepting addon compartment registrations

### 13. Party Role Widget
Show current group composition at a glance: tank/healer/DPS count with role icons. Click to open group finder. Useful for quickly seeing if the group is complete.
- **Ease:** Easy
- **Uses:** `GetNumGroupMembers()`, `UnitGroupRolesAssigned()`

### 14. Fishing Tracker Widget
Track fishing skill, catches per session, and rare catch notifications. Show current fishing zone's notable catches from the journal.
- **Ease:** Medium
- **Niche:** Fishing enthusiasts

---

## Improvements to Existing Widgets

### 15. FPS Widget - Add Latency Display
Show world and home latency alongside FPS. Toggle between FPS-only, latency-only, or combined display. Add color coding (green/yellow/red) based on latency thresholds.
- **Ease:** Easy
- **Uses:** `GetNetStats()`

### 16. Bags Widget - Free Space by Bag Type
Show breakdown of free space by bag type (normal, reagent, profession). Add color warning when space is critically low (< 5 slots). Right-click to open specific bags.
- **Ease:** Easy (enhancement)

### 17. Durability Widget - Equipment Breakdown
Show per-slot durability in the tooltip instead of just overall percentage. Highlight the lowest durability piece. Add repair cost estimate.
- **Ease:** Easy (enhancement)

### 18. Friends Widget - Favorite Friends
Allow marking "favorite" friends that always show at the top of the tooltip. Add last-seen time for offline friends. Show what content friends are doing (M+ level, raid boss, etc.).
- **Ease:** Medium (enhancement)

### 19. Group Widget - M+ Key Display
In the Group widget tooltip, show each party member's M+ keystone (dungeon + level) if available. This would complement the existing Keystone widget which only shows the player's own key.
- **Ease:** Medium (requires addon communication or inspect)

### 20. Hearthstone Widget - Cooldown Bar
Add a small visual cooldown bar/sweep under the hearthstone icon showing remaining cooldown time visually. Currently shows text only.
- **Ease:** Easy (enhancement)
- **Visual:** Mini progress bar or radial cooldown sweep overlay

---

## Widget Framework Improvements

### A. Widget Groups
Allow grouping multiple widgets into a single horizontal or vertical bar. Dragging one moves the whole group. Settings for padding between widgets in a group.
- **Ease:** Medium-Hard
- **Impact:** Major UX improvement for organizing many widgets

### B. Per-Widget Font Override
Currently all widgets share a global font. Allow individual widgets to override font family, size, and color. The infrastructure exists in the settings (each widget has its own sub-table).
- **Ease:** Easy-Medium
- **Impact:** Medium

### C. Widget Background/Border Options
Allow individual widgets to have background panels or borders, not just text on transparent background. Could use the same backdrop system as custom layout frames.
- **Ease:** Easy-Medium
- **Impact:** Medium - Better visual integration

### D. Widget Visibility Conditions
Allow widgets to show/hide based on conditions: in combat, in instance, in group, in city, specific zone. Uses the existing state driver pattern.
- **Ease:** Medium
- **Impact:** Medium - Reduces clutter

### E. Widget Click Actions
Currently most widgets have limited click behavior. Add a configurable click action system: left-click opens one thing, right-click another, middle-click a third. Actions could be: open Blizzard frame, run macro, toggle another widget.
- **Ease:** Medium
- **Impact:** Medium
