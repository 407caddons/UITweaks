# Unit & Player APIs

APIs for reading information about the player, group members, and other units.

---

## Unit IDs

Unit IDs used in this addon:

| Unit ID | Description |
|---|---|
| `"player"` | The local player |
| `"target"` | Current target |
| `"focus"` | Focus target |
| `"party1"`–`"party4"` | Party members (not including player) |
| `"raid1"`–`"raid40"` | Raid members (includes player at some index) |
| `"boss1"`–`"boss5"` | Encounter boss units |
| `"pet"` | Player's pet |
| `"npc"` | Used in some gossip contexts |

---

## UnitName

```lua
local name, realm = UnitName(unitID)
```
Returns the name and realm of the unit. `realm` is `nil` or `""` if the unit is on the same realm as the player.

**Used in:** Core.lua, Loot.lua, ObjectiveTracker.lua, AddonVersions.lua, Kick.lua, ChatSkin.lua, CastBar.lua, Reagents.lua, TalentReminder.lua, widgets/Group.lua.

**Caveat:** For cross-realm players, `realm` is set. `name` alone is not unique across realms — use `name .. "-" .. (realm or GetRealmName())` for a unique key.

---

## UnitClass

```lua
local className, classFilename, classID = UnitClass(unitID)
```
- `className` — localized display name (e.g. `"Warrior"` in English)
- `classFilename` — uppercase English internal name (e.g. `"WARRIOR"`) — **use this for comparisons and table keys**, never `className`
- `classID` — numeric class ID (1–13)

**Used in:** Loot.lua (class colour lookup), Kick.lua (interrupt spell list), CastBar.lua, Reagents.lua, widgets/Group.lua.

---

## UnitGUID

```lua
local guid = UnitGUID(unitID)
```
Returns a GUID string in the format `"Player-realmID-playerUID"` for players, or `"Creature-..."` for NPCs.

**Used in:** Kick.lua (identifying interrupters), widgets/Group.lua (deduplication).

**Caveat:** `UnitGUID("player")` is always available after `PLAYER_LOGIN`. For other units, returns `nil` if the unit doesn't exist.

---

## UnitExists

```lua
local exists = UnitExists(unitID)
```
Returns `true` if the unit exists and is accessible. Always call this before reading other unit data for non-player units.

---

## UnitLevel

```lua
local level = UnitLevel(unitID)
```
Returns the unit's level. Returns `-1` if the unit's level is classified (e.g. raid bosses).

---

## UnitIsGroupLeader / UnitIsGroupAssistant

```lua
local isLeader = UnitIsGroupLeader(unitID [, partyCategory])
local isAssistant = UnitIsGroupAssistant(unitID)
```
Used in widgets/Group.lua to display role indicators.

---

## GetUnitName

```lua
local name = GetUnitName(unitID [, showServerName])
```
Like `UnitName` but returns a combined `"Name-Realm"` string when `showServerName` is true. Returns just the name when on the same realm.

---

## Player State

### IsInGuild
```lua
local inGuild = IsInGuild()
```

### GetRealmName
```lua
local realmName = GetRealmName()
```
Returns the player's current realm name. Useful for constructing full player names.

### GetBuildInfo
```lua
local version, build, date, tocVersion = GetBuildInfo()
```
- `version` — e.g. `"12.0.2"`
- `build` — e.g. `"56162"`
- `tocVersion` — e.g. `120002`

Used in TalentManager.lua for version-dependent behaviour.

---

## Relevant Events

| Event | Description |
|---|---|
| `PLAYER_LOGIN` | Player logged in; safe to read most player data |
| `PLAYER_ENTERING_WORLD` | Zone transition complete; safe to read map/instance data |
| `PLAYER_LEAVING_WORLD` | About to enter a loading screen |
| `PLAYER_LEVEL_UP` | Player levelled up |
| `PLAYER_SPECIALIZATION_CHANGED` | Spec changed (`unitID` arg) |
| `GROUP_ROSTER_UPDATE` | Party/raid composition changed |
| `PARTY_LEADER_CHANGED` | Party leadership transferred |
| `ZONE_CHANGED` | Minor zone change (subzone) |
| `ZONE_CHANGED_NEW_AREA` | Major zone change |
