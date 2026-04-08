---
name: mplus-counts
description: Read mob force counts from MythicDungeonTools and generate MplusData.lua for the M+ timer module.
---

Generate (or regenerate) `MplusData.lua` in the project root by reading dungeon data from the locally installed MythicDungeonTools addon.

## Source

Read every `.lua` file under **all subdirectories** of `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\MythicDungeonTools\` that contain dungeon data. Currently these are in `Midnight\` and `MistsOfPandaria\` but scan for any subdirectory that has dungeon `.lua` files.

Each MDT dungeon file defines:
- `MDT.mapInfo[dungeonIndex].mapID` — the **challengeMapID** (this is the key we use)
- `MDT.mapInfo[dungeonIndex].englishName` — the dungeon name
- `MDT.dungeonTotalCount[dungeonIndex].normal` — total forces required
- `MDT.dungeonEnemies[dungeonIndex]` — indexed array of enemy tables, each with:
  - `["id"]` — NPC ID
  - `["name"]` — mob name
  - `["count"]` — force count value (0 for bosses and non-counting mobs)
  - `["spells"]` — table of spell entries keyed by spellID, where interruptible spells have `["interruptible"] = true`

## Output

Write `MplusData.lua` in the project root with this exact structure:

```lua
-- MplusData.lua — M+ mob force counts
-- Auto-generated from MythicDungeonTools data. Do not edit by hand.
-- Regenerate with: /mplus-counts
local addonName, addonTable = ...

addonTable.MplusData = {
    -- Dungeon Name (challengeMapID = NNN)
    [challengeMapID] = {
        name = "Dungeon Name",
        totalForces = NNN,
        mobs = {
            [npcID] = { name = "Mob Name", count = N, interrupts = { spellID, ... } },
            ...
        },
    },

    ...
}
```

## Rules

1. **Key each dungeon by `mapID`** (the challengeMapID from `MDT.mapInfo`), NOT by MDT's internal `dungeonIndex`.
2. **Skip dungeons** where `mapID` is obviously placeholder (e.g. `12345`) or where `dungeonEnemies` is empty.
3. **Include ALL mobs** — even those with `count = 0` (bosses, totems, adds). Consumers will filter.
3a. **Include interruptible spells** — for each mob, collect spell IDs from `["spells"]` where `["interruptible"] = true`. Store as `interrupts = { spellID, ... }` sorted ascending. Omit the `interrupts` key entirely if the mob has no interruptible spells.
4. **Sort dungeons** by challengeMapID ascending within the file.
5. **Sort mobs** within each dungeon by npcID ascending.
6. **Add a comment** above each dungeon block with its name and challengeMapID.
7. **No external dependencies** — the file must be loadable as a standalone WoW addon Lua file using `local addonName, addonTable = ...`.
8. After writing the file, print a summary: how many dungeons and total mob entries were written.
9. If `MplusData.lua` already exists, overwrite it completely.
10. Do NOT add `MplusData.lua` to the `.toc` file — just generate the data file. The user will wire it up separately.
