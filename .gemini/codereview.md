# `games/Blocks.lua` Code Review

After reviewing the `Blocks.lua` file, I have identified a few performance issues and bugs, primarily related to garbage collection overhead and potential memory leaks in the multiplayer functionality.

## 1. Frame / Memory Leak in Multiplayer
**Severity: High**
* **Issue:** In the `EndMPGame` function, `wipe(MP.opponents)` is called to clear the opponent data. However, the UI frames grouped under `opp.frames.container` (including mini-boards, textures, and fonts) are merely hidden, but are not tracked outside of `MP.opponents`.
* **Impact:** The next time a multiplayer game starts (`LayoutOpponentPanels`), new tables and blank frames are generated for the opponents without reusing the old ones. This causes a frame limit leak/memory leak over multiple multiplayer games.
* **Fix Target:** Cache/pool opponent frames in a separate table structure rather than keeping them tied to the transient `MP.opponents` lifecycle, allowing reuse when new opponents connect.

## 2. Heavy Table Allocation (Garbage Collection Overhead)
**Severity: Medium (Performance)**
* **Issue:** The `PieceBlocks(pieceIdx, rot, px, py)` function creates and returns a brand new table of block `{c = x, r = y}` coordinate dictionary entries on **every** call. 
* **Impact:** `PieceBlocks` is called continuously during the update loop. Most notably, it is called many times successively during `GhostY()` to calculate the ghost piece position on **every vertical line step**, which itself is called every time `RenderAll()` runs. Generating this many short-lived tables creates heavy overhead for the Lua Garbage Collector, leading to micro-stutters during gameplay.
* **Fix Target:** Rewrite `IsValid` and `GhostY()` so they iterate over the `PIECES[curPiece].rotations[curRot]` offsets logically instead of constructing intermediate tables. `PieceBlocks` should only be used where strictly necessary (e.g. for `LockPiece`), or refactored to populate and return a single reused table.

## 3. Potential Nil Errors with Saved Variables
**Severity: Medium (Bug)**
* **Issue:** In `AddScore()` and `GameOver()`, the script accesses `UIThingsDB.games.tetris.highScore` to save the player's best score.
* **Impact:** If `UIThingsDB.games` or `UIThingsDB.games.tetris` hasn't been initialized by the main addon's database loader yet (or if the user's DB has been wiped), assigning a value to `UIThingsDB.games.tetris.highScore` will throw an `"attempt to index field 'tetris' (a nil value)"` Lua error.
* **Fix Target:** Add a safety check/initialization step before assigning the high score.
```lua
UIThingsDB.games = UIThingsDB.games or {}
UIThingsDB.games.tetris = UIThingsDB.games.tetris or {}
UIThingsDB.games.tetris.highScore = highScore
```

## 4. Multiplayer Addon Hook
**Severity: Low**
* **Issue:** In `BuildUI()`, the addon overrides `addonTable.AddonVersions.onVersionsUpdated` to inject `UpdateMultiBtn()`.
* **Impact:** If `BuildUI()` somehow gets called more than once, it could create a recursive chain. Since `gameFrame` is set globally, it only gets called once right now, so it is safe.
* **Fix Target:** Ensure `AddonVersions` uses a generic event payload system rather than overriding functions, or rely exclusively on `GROUP_ROSTER_UPDATE`.

Would you like me to go ahead and implement fixes for these issues?
