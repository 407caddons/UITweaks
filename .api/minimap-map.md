# Minimap & Map APIs

APIs for world map data, player coordinates, and Mythic+ keystone info.

---

## C_Map

### C_Map.GetBestMapForUnit
```lua
local mapID = C_Map.GetBestMapForUnit(unitID)
```
Returns the map ID for the zone the unit is currently in. Returns `nil` if the unit cannot be found or is in an unmapped area.

**Used in:** widgets/Coordinates.lua.

### C_Map.GetPlayerMapPosition
```lua
local mapPoint = C_Map.GetPlayerMapPosition(mapID, unitID)
-- mapPoint.x, mapPoint.y  (0.0 to 1.0, fraction of map dimensions)
```
Returns the unit's position on the given map as a normalized `{x, y}` point. Returns `nil` if the unit is not on that map or position is unavailable.

**Coordinate conversion:**
```lua
local mapID = C_Map.GetBestMapForUnit("player")
if mapID then
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if pos then
        local x = math.floor(pos.x * 100 * 10 + 0.5) / 10  -- 1 decimal place %
        local y = math.floor(pos.y * 100 * 10 + 0.5) / 10
    end
end
```

### C_Map.GetMapInfo
```lua
local info = C_Map.GetMapInfo(mapID)
-- info.mapID, info.name, info.mapType, info.parentMapID
```
Returns metadata about a map by ID. Used for getting zone names from map IDs.

**`info.mapType` values:** `Enum.UIMapType` — `World`, `Continent`, `Zone`, `Dungeon`, `Micro`, `Orphan`.

---

## C_ChallengeMode

### C_ChallengeMode.GetMapUIInfo
```lua
local name, id, timeLimit, texture, backgroundTexture = C_ChallengeMode.GetMapUIInfo(mapChallengeModeID)
```
Returns display info for a Mythic+ dungeon map.

**Used in:** AddonVersions.lua to display the player's current keystone dungeon.

### Related Keystone APIs
```lua
-- Get the player's current keystone
local keystoneLevel, affixIDs, wasCharged = C_MythicPlus.GetCurrentAffixes()
local itemLevel, affixIDs, dungeonID = C_MythicPlus.GetOwnedKeystoneLevel()
```

---

## Minimap Custom Frame (MinimapCustom.lua)

The addon creates a custom minimap frame skin. Key notes:

- **`Minimap`** is the Blizzard global minimap frame — do not call `SetPoint` or `ClearAllPoints` on it (protected).
- The custom border and clock are addon-created frames parented to `Minimap`.
- The `QueueStatusButton` (the LFG eye icon) is anchored via a polling ticker (`C_Timer.NewTicker(2.0, ...)`) rather than hooking the button — see [events-communication.md](events-communication.md) for why hooks on Button frames cause taint.

### GetSubZoneText / GetZoneText
```lua
local subzone = GetSubZoneText()  -- e.g. "Valley of Heroes"
local zone = GetZoneText()        -- e.g. "Stormwind City"
```
Used for zone display in minimap and TalentReminder zone matching.

---

## Relevant Events

| Event | Description |
|---|---|
| `ZONE_CHANGED` | Subzone changed |
| `ZONE_CHANGED_NEW_AREA` | Zone changed (major area transition) |
| `ZONE_CHANGED_INDOORS` | Went indoors or outdoors |
| `MINIMAP_UPDATE_ZOOM` | Minimap zoom level changed |
