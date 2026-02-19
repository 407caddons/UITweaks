# EventBus Migration Plan
**Date:** 2026-02-18  
**Scope:** Addon-wide centralized event dispatch  
**Goal:** Replace 50+ individual event frames with a single dispatcher, eliminate 15 redundant event registrations, reduce event storm overhead on PLAYER_ENTERING_WORLD / PLAYER_REGEN_* / ZONE_CHANGED*

---

## Current State (Baseline)

| Metric | Count |
|--------|-------|
| Total event frames (CreateFrame("Frame") for events) | ~50 |
| Unique events registered across addon | 50+ |
| Events registered 3+ times | 15 |
| PLAYER_ENTERING_WORLD registrations | 15+ |
| PLAYER_REGEN_ENABLED registrations | 11+ |
| ZONE_CHANGED* registrations (all 3 variants) | 10+ |
| GROUP_ROSTER_UPDATE registrations | 8+ |
| CHALLENGE_MODE_* registrations | 6+ |
| Widget event frames alone | 28 |

Every zone change currently fires approximately 30 event handler calls (10 registrations × 3 zone events). Every combat exit fires 11+ handlers. Every world entry fires 15+ handlers. These are the primary targets.

---

## Design Decisions

### 1. New file: `EventBus.lua`
Loaded immediately after `Core.lua` in the TOC. Exposes `addonTable.EventBus` globally on the addon table. No external dependencies.

### 2. API surface — keep it minimal
Three functions only:
- `EventBus.Register(event, callback)` — subscribe
- `EventBus.Unregister(event, callback)` — unsubscribe by reference
- `EventBus.RegisterUnit(event, unit, callback)` — for unit events (CastBar, Kick)

No namespacing, no priority system, no wildcard matching. Those add complexity with no current benefit.

### 3. Do NOT replace everything
Some frames stay as-is:
- **CastBar.lua** — 13 UNIT_SPELLCAST_* events on "player". These are unit events registered with RegisterUnitEvent. The bus can handle them but migration is lower priority and higher risk.
- **ChatSkin.lua** — Uses ChatFrame_AddMessageEventFilter, not RegisterEvent. Not applicable.
- **AddonComm.lua** — Already its own message bus for CHAT_MSG_ADDON. Leave it alone.
- **Core.lua** — ADDON_LOADED fires once and the frame self-destructs. Not worth migrating.
- **Frames.lua** — PLAYER_LOGOUT only. Not worth migrating.
- **TalentManager.lua** — Uses hooks not events. Not applicable.
- **MinimapButton.lua** — No events. Not applicable.
- **MplusTimer.lua** and **ObjectiveTracker.lua** — Complex internal state machines. Migrate in Phase 4 only if comfortable; they work correctly now.

### 4. Widget event frames — full elimination
All 26 widget event frames (one per widget) are replaced by EventBus subscriptions. The `conditionEventFrame` in Widgets.lua is also replaced. This is the highest-value migration.

### 5. Backward compatibility
No compatibility shim needed. This is an internal refactor — no external API is exposed. Modules are migrated file by file. The old frames in unmigrated files continue to work alongside the bus during migration.

### 6. Enable/disable guard placement
Currently each module's OnEvent handler checks `UIThingsDB.module.enabled` at the top. After migration this guard moves into each callback. Same semantics, same location — just inside a function reference instead of an OnEvent script.

---

## EventBus.lua — Full Implementation

```lua
-- EventBus.lua
-- Single-frame centralized event dispatcher for LunaUITweaks.
-- Load order: after Core.lua, before all feature modules.

local addonName, addonTable = ...
addonTable.EventBus = {}
local EventBus = addonTable.EventBus

-- listeners[eventName] = { callback, callback, ... }
local listeners = {}

local busFrame = CreateFrame("Frame", "LunaUITweaks_EventBus")
busFrame:SetScript("OnEvent", function(_, event, ...)
    local subs = listeners[event]
    if not subs then return end
    -- iterate a copy length so mid-iteration Unregister is safe
    for i = 1, #subs do
        local cb = subs[i]
        if cb then
            local ok, err = pcall(cb, event, ...)
            if not ok then
                -- Use Core logger if available, otherwise print
                if addonTable.Core and addonTable.Core.Log then
                    addonTable.Core.Log("EventBus", "Error in handler for " .. event .. ": " .. tostring(err), addonTable.Core.LogLevel.ERROR)
                else
                    print("|cffff0000[LunaUITweaks EventBus]|r Error in " .. event .. ": " .. tostring(err))
                end
            end
        end
    end
end)

--- Subscribe to a WoW event.
-- @param event string   WoW event name e.g. "PLAYER_ENTERING_WORLD"
-- @param callback function  Called as callback(event, ...) when event fires
function EventBus.Register(event, callback)
    if not listeners[event] then
        listeners[event] = {}
        busFrame:RegisterEvent(event)
    end
    table.insert(listeners[event], callback)
end

--- Unsubscribe a specific callback from an event.
-- Uses reference equality. Removes at most one entry per call.
-- @param event string
-- @param callback function  Must be the same function reference passed to Register
function EventBus.Unregister(event, callback)
    local subs = listeners[event]
    if not subs then return end
    for i = #subs, 1, -1 do
        if subs[i] == callback then
            table.remove(subs, i)
            break
        end
    end
    if #subs == 0 then
        listeners[event] = nil
        busFrame:UnregisterEvent(event)
    end
end

--- Subscribe to a unit event (RegisterUnitEvent semantics).
-- Wraps the callback so it only fires when the event is for the given unit.
-- @param event string
-- @param unit string  e.g. "player", "party1"
-- @param callback function  Called as callback(event, unit, ...) 
-- @return function  The wrapped callback (use this reference to Unregister)
function EventBus.RegisterUnit(event, unit, callback)
    local function wrapper(ev, unitTarget, ...)
        if unitTarget == unit then
            callback(ev, unitTarget, ...)
        end
    end
    EventBus.Register(event, wrapper)
    return wrapper  -- caller must store this to Unregister later
end
```

**TOC insertion** — add `EventBus.lua` on the line immediately after `Core.lua`:
```
Core.lua
EventBus.lua
```

---

## Migration Phases

---

### Phase 1 — High-frequency global events (Highest impact, lowest risk)
**Target events:** `PLAYER_ENTERING_WORLD`, `PLAYER_REGEN_ENABLED`, `PLAYER_REGEN_DISABLED`, `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `ZONE_CHANGED_NEW_AREA`  
**Files:** Vendor, Loot, Combat, Misc, TalentReminder, MinimapCustom, ActionBars, Kick, ChatSkin, AddonVersions, QuestReminder, Reagents  
**Expected frame reduction:** ~12 frames  
**Expected duplicate registrations eliminated:** PLAYER_ENTERING_WORLD from 15→1, PLAYER_REGEN_* from 11→1, ZONE_CHANGED* from 10→1

**Pattern for each file:**

Before:
```lua
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        Initialize()
    elseif event == "PLAYER_REGEN_ENABLED" then
        OnCombatEnd()
    end
end)
```

After:
```lua
local EventBus = addonTable.EventBus
EventBus.Register("PLAYER_ENTERING_WORLD", function()
    Initialize()
end)
EventBus.Register("PLAYER_REGEN_ENABLED", function()
    OnCombatEnd()
end)
```

**File-by-file tasks:**

#### `Vendor.lua`
- Remove event frame that registers: `MERCHANT_SHOW`, `MERCHANT_CLOSED`, `PLAYER_REGEN_ENABLED`, `PLAYER_REGEN_DISABLED`, `PLAYER_UNGHOST`, `UPDATE_INVENTORY_DURABILITY`, `BAG_UPDATE_DELAYED`
- Replace with 7 `EventBus.Register` calls, each with the existing handler logic inlined
- Keep the warningFrame and bagWarningFrame (these are UI frames, not event frames)

#### `Loot.lua`
- Remove event frame that registers: `PLAYER_LOGIN`, `CHAT_MSG_LOOT`, `LOOT_READY`, `GROUP_ROSTER_UPDATE`, `CURRENCY_DISPLAY_UPDATE`, `PLAYER_MONEY`
- Replace with 6 `EventBus.Register` calls
- Keep anchorFrame (UI positioning frame)

#### `Combat.lua`
- Has 3 separate event-listening frames (timerFrame, logFrame, reminderFrame each registering their own events)
- **timerFrame** events: `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED` → 2 Register calls
- **logFrame** events: `PLAYER_ENTERING_WORLD`, `CHALLENGE_MODE_START` → 2 Register calls  
- **reminderFrame** events: `PLAYER_ENTERING_WORLD`, `UNIT_AURA`, `UNIT_PET`, `PLAYER_EQUIPMENT_CHANGED`, `PLAYER_REGEN_ENABLED`, `PLAYER_MOUNT_DISPLAY_CHANGED`, `UNIT_SPELLCAST_SUCCEEDED`, `BAG_UPDATE_DELAYED`, `GROUP_ROSTER_UPDATE` → 9 Register calls
- Keep timerFrame, logFrame, reminderFrame as display/layout frames — just remove their event registrations
- Keep the `C_Timer.NewTicker(10, ...)` weapon buff poller (no equivalent event)

#### `Misc.lua`
- Remove event frame registering: `PLAYER_ENTERING_WORLD`, `AUCTION_HOUSE_SHOW`, `CHAT_MSG_SYSTEM`, `UPDATE_PENDING_MAIL`, `PARTY_INVITE_REQUEST`, `CHAT_MSG_WHISPER`, `CHAT_MSG_BN_WHISPER`, `UNIT_COMBAT`
- Replace with 8 `EventBus.Register` calls
- Keep alertFrame and mailAlertFrame (display frames)

#### `MinimapCustom.lua`
- Remove event frame registering: `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `ZONE_CHANGED_NEW_AREA`, `CRAFTINGORDERS_UPDATE_PERSONAL_ORDER_COUNTS`
- Replace with 4 `EventBus.Register` calls
- Keep minimapFrame, zoneFrame, clockFrame (display frames)
- Keep `C_Timer.NewTicker(1, UpdateClock)` (no equivalent event for time passing)

#### `TalentReminder.lua`
- Remove event frame registering: `PLAYER_ENTERING_WORLD`, `PLAYER_SPECIALIZATION_CHANGED`, `TRAIT_CONFIG_UPDATED`, `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `ZONE_CHANGED_NEW_AREA`
- Replace with 6 `EventBus.Register` calls
- Keep alertFrame (display frame)

#### `Kick.lua`
- Remove updateFrame registering: `PLAYER_ENTERING_WORLD`, `GROUP_ROSTER_UPDATE`, `PLAYER_SPECIALIZATION_CHANGED`, `SPELLS_CHANGED`, `PLAYER_REGEN_ENABLED`
- Replace with 5 `EventBus.Register` calls
- Keep per-party-member unit event watchers for now (Phase 3)
- Keep partyContainer and party display frames

#### `ChatSkin.lua`
- Remove event frame registering: `UPDATE_CHAT_WINDOWS`, `UPDATE_FLOATING_CHAT_WINDOWS`
- Replace with 2 `EventBus.Register` calls
- Leave ChatFrame_AddMessageEventFilter calls untouched (different system)

#### `AddonVersions.lua`
- Remove event frame registering: `GROUP_ROSTER_UPDATE`
- Replace with 1 `EventBus.Register` call

#### `QuestReminder.lua`
- Remove event frame registering: `PLAYER_ENTERING_WORLD`, `QUEST_ACCEPTED`
- Replace with 2 `EventBus.Register` calls
- Keep popupFrame (display frame)

#### `QuestAuto.lua`
- Remove event frame registering: `GOSSIP_SHOW`, `GOSSIP_CLOSED`, `QUEST_GREETING`, `QUEST_DETAIL`, `QUEST_PROGRESS`, `QUEST_COMPLETE`
- Replace with 6 `EventBus.Register` calls

#### `Reagents.lua`
- Remove event frame registering: `BAG_UPDATE_DELAYED`, `BANKFRAME_OPENED`, `BANKFRAME_CLOSED`, `PLAYERBANKSLOTS_CHANGED`, `PLAYER_ENTERING_WORLD`, `PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED`
- Replace with 6 `EventBus.Register` calls
- Keep `C_Timer.NewTimer` debounce pattern (it's not event-based, it's a debounce on the callback side)

#### `ActionBars.lua`
- Already uses hooksecurefunc primarily — check for any RegisterEvent calls and migrate those
- Keep all secure frame infrastructure

---

### Phase 2 — Widget event frames (Highest frame count, fully self-contained)
**Target:** All 26 widget files + Widgets.lua framework  
**Expected frame reduction:** 28 frames → 0 event frames in widgets  
**Expected duplicate registrations eliminated:** PLAYER_ENTERING_WORLD 13 more instances, plus all per-widget duplicates

**Approach:** Modify `Widgets.lua` to expose a widget-specific registration helper that wraps EventBus and respects the `ApplyEvents` enable/disable lifecycle. Then migrate each widget.

#### `Widgets.lua` changes:
1. Remove `conditionEventFrame` entirely — replace its 8 event registrations with EventBus calls that invoke `Widgets.UpdateConditions()`
2. Add `Widgets.RegisterEvent(key, event, callback)` helper that:
   - Registers via EventBus
   - Stores the callback reference keyed by widget key + event for later unregistration
   - Is automatically called/uncalled by the existing `ApplyEvents(true/false)` pattern
3. Remove individual widget `eventFrame` creation from the framework docs/pattern

**Revised widget pattern:**

Before:
```lua
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function() RefreshGuildCache() end)

guildFrame.ApplyEvents = function(enabled)
    if enabled then
        eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    else
        eventFrame:UnregisterAllEvents()
    end
end
```

After:
```lua
local function OnGuildEvent() RefreshGuildCache() end

guildFrame.ApplyEvents = function(enabled)
    if enabled then
        EventBus.Register("GUILD_ROSTER_UPDATE", OnGuildEvent)
        EventBus.Register("PLAYER_ENTERING_WORLD", OnGuildEvent)
    else
        EventBus.Unregister("GUILD_ROSTER_UPDATE", OnGuildEvent)
        EventBus.Unregister("PLAYER_ENTERING_WORLD", OnGuildEvent)
    end
end
-- Initial registration (widget starts enabled or disabled per DB)
if UIThingsDB.widgets.guild.enabled then
    guildFrame.ApplyEvents(true)
end
```

**Widget migration order** (by event complexity, simplest first):
1. `Mail.lua` — 3 events, no special logic
2. `Zone.lua` — 4 events, no special logic
3. `Guild.lua` — 3 events, no special logic
4. `Friends.lua` — 5 events, no special logic
5. `ItemLevel.lua` — 3 events, no special logic
6. `MythicRating.lua` — 4 events, no special logic
7. `DarkmoonFaire.lua` — 2 events, no special logic
8. `PvP.lua` — 5 events, no special logic
9. `Vault.lua` — 4 events, deferred init timer (keep timer, just migrate events)
10. `Bags.lua` — 2 events (goldTracker frame)
11. `Durability.lua` — 3 events
12. `Currency.lua` — 3 events
13. `Combat.lua` (widget) — 3 events
14. `PullCounter.lua` — 3 events
15. `BattleRes.lua` — check actual event registrations
16. `Hearthstone.lua` — 3 events (keep secureBtn, only migrate eventFrame)
17. `SessionStats.lua` — 3 events
18. `Group.lua` — 6 events (most complex widget, do last in this group)
19. `Keystone.lua` — 2 event frames (eventFrame + teleportCacheFrame), 6+ events
20. `Teleports.lua` — 2 events (teleportCacheFrame)

**Widgets with no event frame** (no migration needed):
- Time, FPS, Coordinates, Speed, Volume, WeeklyReset, Spec

---

### Phase 3 — Unit events (Lower priority, higher care required)
**Target:** `Kick.lua` party watcher frames, `Combat.lua` UNIT_* events  
**Note:** Unit events pass a `unitTarget` argument. The EventBus `RegisterUnit` helper wraps these correctly.

#### `Kick.lua` party watchers
Currently creates up to 4 per-member frames with `RegisterUnitEvent`. Replace with:
```lua
for i = 1, 4 do
    local unit = "party" .. i
    local cb = EventBus.RegisterUnit("UNIT_SPELLCAST_SUCCEEDED", unit, HandleSpellCast)
    -- store cb reference for later Unregister on roster change
end
```
Risk: Unit events with RegisterUnitEvent are slightly more efficient than filtered global events because WoW only fires them for the specified unit. The `RegisterUnit` wrapper in the bus uses the global event but filters by unit in Lua. For Kick (fires on every party member spell cast) this is acceptable — the filtering is O(1). If performance testing shows regression, keep the per-unit frames for Kick only.

#### `Combat.lua` UNIT_AURA / UNIT_PET
Same pattern — use `EventBus.RegisterUnit` for "player" unit.

---

### Phase 4 — Complex modules (Optional, do only if comfortable)
**Target:** `MplusTimer.lua`, `ObjectiveTracker.lua`  
**Risk:** Both are complex internal state machines with interleaved event and display logic. They work correctly now. Only migrate if the codebase is already clean from Phases 1-3 and there's a clear benefit.

**Recommendation:** Skip Phase 4 unless a specific bug or performance issue motivates it.

---

### What is explicitly NOT migrated
| File | Reason |
|------|--------|
| `Core.lua` init frame | ADDON_LOADED fires once, frame is single-use |
| `Frames.lua` | PLAYER_LOGOUT only, trivial |
| `ChatSkin.lua` message filters | ChatFrame_AddMessageEventFilter is a different system |
| `AddonComm.lua` | Already its own bus for CHAT_MSG_ADDON; leave as-is |
| `TalentManager.lua` | Uses hooks not events |
| `MinimapButton.lua` | No events |
| `CastBar.lua` (optional) | 13 UNIT_SPELLCAST_* events work correctly; migrate only in Phase 4 if desired |

---

## Testing Approach

Since there is no test suite, validation is manual in-game. After each phase:

1. `/reload` — confirm no Lua errors on startup
2. Check `PLAYER_ENTERING_WORLD` behavior: zone in/out, confirm migrated modules initialize correctly
3. Check `PLAYER_REGEN_DISABLED/ENABLED`: enter and leave combat, confirm combat timer, reminder frames, widget conditions all respond
4. Check `ZONE_CHANGED*`: move between zones, confirm minimap zone text, TalentReminder, widget Zone all update
5. For widget phase: toggle each migrated widget on/off in config, confirm it stops/starts responding to events
6. Enable debug mode (`UIThingsDB.addonComm.debugMode = true`) — EventBus errors will be logged to chat

**Regression risks by phase:**
- Phase 1: If a callback function reference captures the wrong upvalue scope, the handler silently does nothing. Check each module's feature works end-to-end.
- Phase 2: `ApplyEvents(false)` must correctly Unregister using the same function reference. If references don't match, the old callback stays registered forever. Use named locals (not anonymous functions) for callbacks that need unregistering.
- Phase 3: Unit event filtering — verify Kick tracks correct party member spells.

---

## File Change Summary

| File | Action | Frames removed | Events migrated |
|------|--------|---------------|-----------------|
| `EventBus.lua` | **CREATE** | — | — |
| `LunaUITweaks.toc` | Add `EventBus.lua` after `Core.lua` | — | — |
| `Vendor.lua` | Remove event frame | 1 | 7 |
| `Loot.lua` | Remove event frame | 1 | 6 |
| `Combat.lua` | Remove 3 event frames | 3 | 13 |
| `Misc.lua` | Remove event frame | 1 | 8 |
| `MinimapCustom.lua` | Remove event frame | 1 | 4 |
| `TalentReminder.lua` | Remove event frame | 1 | 6 |
| `Kick.lua` | Remove updateFrame events | 1 | 5 |
| `ChatSkin.lua` | Remove event frame | 1 | 2 |
| `AddonVersions.lua` | Remove event frame | 1 | 1 |
| `QuestReminder.lua` | Remove event frame | 1 | 2 |
| `QuestAuto.lua` | Remove event frame | 1 | 6 |
| `Reagents.lua` | Remove event frame | 1 | 6 |
| `ActionBars.lua` | Remove any event registrations | 0–1 | 1–3 |
| `Widgets.lua` | Remove conditionEventFrame, add RegisterEvent helper | 1 | 8 |
| 20 widget files | Remove individual event frames | 20 | ~60 |
| **TOTAL Phase 1+2** | | **~35 frames** | **~100 registrations** |

---

## Expected Outcome

| Metric | Before | After |
|--------|--------|-------|
| Event frames | ~50 | ~15 (UI/display frames only) |
| PLAYER_ENTERING_WORLD registrations | 15+ | 1 |
| PLAYER_REGEN_* registrations | 11+ each | 1 each |
| ZONE_CHANGED* registrations | 10+ | 1 |
| GROUP_ROSTER_UPDATE registrations | 8+ | 1 |
| Handlers called per zone change | ~30 | ~10 (those that actually care) |
| Handlers called per combat exit | ~11 | ~6 |
| Memory from event frames | ~50KB | ~15KB |

The bus itself adds negligible overhead: one `pcall` per handler call vs the current direct invocation. For low-frequency events (PLAYER_ENTERING_WORLD fires maybe 5-10 times per session) this is completely irrelevant. For higher-frequency events (GROUP_ROSTER_UPDATE, BAG_UPDATE_DELAYED) the overhead is still sub-microsecond.

---

## Implementation Order Recommendation

1. Write and load `EventBus.lua` first — no behavior change, just adds the bus frame
2. Migrate Phase 1 files one at a time, testing after each
3. Migrate Phase 2 widgets in batches of 4-5, testing after each batch
4. Migrate Phase 3 unit events (Kick party watchers) if desired
5. Skip Phase 4 unless a specific need arises

Total estimated implementation time: 3-5 hours across the phases.
