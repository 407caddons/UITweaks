# Deep Code Review: LunaUITweaks

## Executive Summary
LunaUITweaks is a robust, feature-rich World of Warcraft addon that aggregates several useful quality-of-life improvements into a single package. The codebase demonstrates a good understanding of the WoW API and Lua programming patterns. It employs advanced techniques like object pooling and addon communication throttling, which indicates a concern for performance.

 However, the project suffers from "monolithic file syndrome," where single files (like `ObjectiveTracker.lua` and `Kick.lua`) handle too many distinct responsibilities (logic, UI, events, database). This makes maintenance difficult and increases the risk of regressions. There are also some performance bottlenecks related to UI updates and chat parsing that could be optimized.

Overall, it is a solid, working codebase that is ripe for refactoring to ensure long-term sustainability.

## Project Rating: 8/10
**Justification:**
-   **Functionality (9/10):** The features appear to be well-implemented and cover a wide range of needs.
-   **Performance (7/10):** Generally good, but `UpdateContent` loops and chat parsing need optimization to avoid frame drops in high-load scenarios.
-   **Code Quality (7/10):** Clean coding style, but lacks modularity in key areas. Good use of local variables and `pcall` for safety.
-   **Architecture (8/10):** limits global pollution well, but internal module separation could be better.

---

## Detailed Findings

### 1. High Severity: Performance Bottlenecks

#### A. Chat Parsing Overhead (`ChatSkin.lua`)
-   **Issue:** `GetChatContent` iterates through *all* messages in a chat frame to build a string for the copy box. In a long gaming session, a chat frame can hold thousands of lines.
-   **Impact:** This can cause a significant "hitch" or screen freeze when opening the copy UI.
-   **Recommendation:** Limit the number of lines processed (e.g., last 100-200 lines) or build the copy buffer incrementally as messages arrive.

#### B. Brute-Force UI Updates (`ObjectiveTracker.lua`)
-   **Issue:** The `UpdateContent` function completely clears and rebuilds the tracker list every time an event fires (quest update, super track change, etc.).
-   **Impact:** While object pooling helps memory, the CPU cost of re-layout and re-anchoring dozens of frames every time a quest progresses can cause micro-stutters.
-   **Recommendation:** Implement "dirty" flags to only update the specific lines that changed (e.g., just update the text of a progress bar rather than redrawing the whole row), or simple throttle the update more aggressively.

#### C. Kick Tracker Event Handling (`Kick.lua`)
-   **Issue:** The logic inside `UNIT_SPELLCAST_SUCCEEDED` iterates and checks cooldowns. While not immediately critical, doing this for every spellcast of every group member (and their pets) can add up in a 40-man raid.
-   **Recommendation:** Ensure strict role/class filtering so we only process relevant interrupt spells and ignore the spam of other abilities immediately.

---

### 2. Medium Severity: Memory & Maintainability

#### A. Monolithic Files
-   **Issue:** `ObjectiveTracker.lua` (1800+ lines) and `Kick.lua` (~1600 lines) are too large. They contain logic for:
    -   Database (spell data, quest logic)
    -   UI Construction (frames, textures)
    -   Event Handling
    -   Business Logic
-   **Recommendation:** Split these into sub-modules (e.g., `Kick/Data.lua`, `Kick/UI.lua`, `Kick/Logic.lua`). The `config` folder refactoring is a great example to follow for the rest of the addon.

#### B. Global Config Table (`Core.lua`)
-   **Issue:** The `DEFAULTS` table in `Core.lua` is massive. It makes it hard to see what settings belong to which module at a glance.
-   **Recommendation:** Move module-specific defaults to the modules themselves (e.g., `Kick.lua` defines its own defaults and merges them on load).

#### C. Memory Leaks in Kick Tracker
-   **Issue:** `Kick.lua` maintains tables `interruptCooldowns` and `knownSpells`. While there is logic to clean these up on `RebuildPartyFrames`, the attached frames for units (`LunaKickAttached_Unit`) are hidden but never stored in a pool to be formally reset or destroyed.
-   **Impact:** Over a very long session with many group changes, `attachedFrames` table could grow with stale keys if not managed carefully (though WoW's UI reload clears this).
-   **Recommendation:** Ensure `attachedFrames` are keyed by a reusable token or properly recycled.

#### D. Aggressive Hooking (`ChatSkin.lua`)
-   **Issue:** The addon uses `hooksecurefunc` on `SetAlpha` to force-hide textures.
-   **Risk:** This is a "fighting" hook. If another addon tries to show these textures or hook `SetAlpha`, it can lead to conflicts or taint issues.
-   **Recommendation:** Use `Hide()` and `SetParent(HiddenFrame)` which is cleaner than fighting opacity values.

---

### 3. Low Severity: Polish & Style

-   **Redundant Code:** `SafeAfter` is defined in `Core.lua`, but `AddonComm.lua` implements its own throttling logic. Consolidate these utilities into a `Utils.lua` file.
-   **Hardcoded Values:** There are magic numbers for pixel offsets and sizes scattered throughout the UI code (e.g., `yOffset = -30` in `Kick.lua`). These should be constants at the top of the file or in a constants file.
-   **Commented Out Code:** `Kick.lua` contains large blocks of commented-out code (old interrupt implementation). These should be deleted to keep the codebase clean; git history preserves the old versions if needed.

---

## Conclusion
LunaUITweaks is a high-quality addon. The "8/10" rating reflects a solid foundation that works well but has reached a scale where architectural refactoring is necessary to maintain velocity and performance. Prioritize breaking up the large files and optimizing the chat parsing logic.
