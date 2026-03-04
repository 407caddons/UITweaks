# Encounter Journal APIs

APIs for reading Encounter Journal data (raid tiers, instances, encounters).

---

## Tier Navigation

```lua
local numTiers = EJ_GetNumTiers()
local currentTier = EJ_GetCurrentTier()  -- returns index (1-based)
EJ_SelectTier(tierIndex)
```

**Used in:** TalentManager.lua to enumerate available content tiers.

---

## Tier Info

```lua
local name, textureAtlas, overrideAtlas = EJ_GetTierInfo(tierIndex)
```
Returns display info for a content tier (e.g. "The War Within Season 1").

---

## Instance Info

```lua
local instanceID, name, description, bgImage, buttonImage, loreImage,
      dungeonAreaMapID, link, isRaid =
    EJ_GetInstanceByIndex(index, isRaid)
```
- `index` — 1-based index within the current tier
- `isRaid` — true to query raids, false for dungeons

Returns info for a specific instance (raid or dungeon) in the Encounter Journal.

**Used in:** TalentManager.lua to build lists of available raids and dungeons.

---

## Caveats

- These APIs reflect the **Encounter Journal's current tier selection** — call `EJ_SelectTier(n)` before `EJ_GetInstanceByIndex` to get data for a specific tier.
- The Journal data is loaded lazily; if the Encounter Journal has never been opened this session, some data may be unavailable.
- Tier indices are 1-based and the order matches the in-game UI ordering.

---

## Relevant Events

| Event | Description |
|---|---|
| `EJ_DIFFICULTY_UPDATE` | Encounter Journal difficulty filter changed |
