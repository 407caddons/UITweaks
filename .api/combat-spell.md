# Combat & Spell APIs

APIs relating to combat state, spell information, instance detection, and the combat log.

---

## InCombatLockdown

```lua
local inCombat = InCombatLockdown()
```

Returns `true` if the player is in combat lockdown. **Must be called before any protected frame operation.**

**What is blocked during combat lockdown:**
- `SetPoint`, `ClearAllPoints`, `SetAllPoints` on Blizzard-owned frames
- `SetSize`, `SetWidth`, `SetHeight` on protected frames
- `SetParent` on any frame
- `RegisterStateDriver`, `UnregisterStateDriver`
- Showing/hiding protected frames via `Show()`/`Hide()`

**What is safe during combat:**
- Reading frame geometry: `GetWidth()`, `GetHeight()`, `GetLeft()`, `GetBottom()`, `GetCenter()`
- `SetAlpha`, `EnableMouse` on Blizzard frames
- All operations on addon-created (non-secure) frames
- Restricted Lua in `SecureHandlerStateTemplate` handlers

**Guard pattern:**
```lua
if InCombatLockdown() then
    -- queue the update for PLAYER_REGEN_ENABLED
    pendingUpdate = true
    return
end
-- safe to reposition
```

**Events:**
- `PLAYER_REGEN_DISABLED` — combat started (lockdown begins)
- `PLAYER_REGEN_ENABLED` — combat ended (lockdown lifted)

---

## GetTime

```lua
local t = GetTime()  -- float, seconds since WoW client start
```

See [timers.md](timers.md) for usage patterns.

---

## GetInstanceInfo

```lua
local name, instanceType, difficultyID, difficultyName, maxPlayers,
      dynamicDifficulty, isDynamic, instanceID, instanceGroupSize, LfgDungeonID =
    GetInstanceInfo()
```

- `instanceType` — `"none"`, `"party"`, `"raid"`, `"pvp"`, `"arena"`, `"scenario"`
- `difficultyID` — numeric difficulty (see below)
- `isDynamic` — true for flexible-size raids

**Used in:** Combat.lua (show timer in instances), TalentReminder.lua (zone-based reminders), widgets/BattleRes.lua.

**Common difficultyIDs:**
- 1 = Normal (5-man), 2 = Heroic (5-man), 8 = Mythic (5-man), 23 = Mythic+ (5-man)
- 14 = Normal Raid, 15 = Heroic Raid, 16 = Mythic Raid
- 17 = LFR

---

## GetDifficultyID / GetSubZoneText / GetZoneText

```lua
local id = GetDifficultyID()     -- current difficulty ID (same as GetInstanceInfo's difficultyID)
local subzone = GetSubZoneText() -- current subzone name (e.g. "The Stockades")
local zone = GetZoneText()       -- current zone name (e.g. "Stormwind City")
```

---

## Spell Info

### GetSpellInfo (Legacy)
```lua
local name, rank, icon, castTime, minRange, maxRange, spellID, originalIcon =
    GetSpellInfo(spellID or spellName)
```
**Deprecated in 11.x** — use `C_Spell.GetSpellInfo` where possible, but `GetSpellInfo` still works as of 12.0.

### C_Spell.GetSpellInfo
```lua
local info = C_Spell.GetSpellInfo(spellID)
-- info.name, info.iconID, info.castTime, info.minRange, info.maxRange, info.spellID
```

### IsPlayerSpell
```lua
local known = IsPlayerSpell(spellID)
```
Returns `true` if the player knows the spell (learned, not just talented). Used in Kick.lua to determine which interrupt spells the player has.

### C_SpellBook.IsSpellKnown
```lua
local known = C_SpellBook.IsSpellKnown(spellID [, isPet])
```
More precise version of `IsPlayerSpell`. Returns `true` if the spell is in the player's spellbook.

### C_Spell.GetSpellCharges
```lua
local currentCharges, maxCharges, chargeStartTime, chargeDuration, chargeModRate =
    C_Spell.GetSpellCharges(spellID)
```
Returns charge info for spells with charges (e.g. Battle Resurrection). Returns `nil` if the spell doesn't use charges.

**Used in:** widgets/BattleRes.lua to display battle resurrection charges.

---

## UNIT_SPELLCAST_INTERRUPTED — Secret Value Warning

```lua
-- Event signature as of Patch 12.0.0:
-- UNIT_SPELLCAST_INTERRUPTED(unitTarget, castGUID, spellID, interruptedBy, castBarID)
```

- **`interruptedBy`** is the GUID of the unit that performed the interrupt.
- **SECRET VALUE:** `issecretvalue(interruptedBy)` returns `true` during combat. This GUID **cannot be read** by addon Lua code during combat without tainting.
- The event still fires and confirms that an interrupt happened — but the identity of the interrupter is inaccessible.
- Kick.lua uses this event to confirm interrupts occurred but does **not** attempt to read the `interruptedBy` arg.

---

## COMBAT_LOG_EVENT_UNFILTERED — FORBIDDEN

```
COMBAT_LOG_EVENT_UNFILTERED is restricted to Blizzard UI only.
```

**Do NOT register for this event.** It will produce a blocking Lua error for third-party addons. This is a hard restriction in WoW 12.0.

The addon's custom DamageMeter uses `C_DamageMeter` API instead (see [blizzard-frames.md](blizzard-frames.md)).

---

## LoggingCombat

```lua
local isLogging = LoggingCombat()    -- returns bool
LoggingCombat(enable)               -- start/stop combat logging to file
```

Used in Combat.lua to detect whether combat logging is active (for display purposes).

---

## Relevant Events

| Event | Description |
|---|---|
| `PLAYER_REGEN_DISABLED` | Combat started |
| `PLAYER_REGEN_ENABLED` | Combat ended |
| `UNIT_SPELLCAST_INTERRUPTED` | A spellcast was interrupted (see secret value note above) |
| `UNIT_SPELLCAST_START` | A unit began casting |
| `UNIT_SPELLCAST_STOP` | A cast stopped (completed or cancelled) |
| `UNIT_SPELLCAST_FAILED` | A cast failed |
| `UNIT_SPELLCAST_CHANNEL_START` | A channelled spell began |
| `UNIT_SPELLCAST_CHANNEL_STOP` | Channelling stopped |
| `SPELL_UPDATE_COOLDOWN` | A spell's cooldown changed |
| `UNIT_SPELLCAST_SENT` | Cast was sent to server |
| `ZONE_CHANGED_NEW_AREA` | Zone changed (instance transitions) |
