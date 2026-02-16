# Deep Code Review: LunaUITweaks

## 1. Executive Summary

**Overall System Rating:** 6.5/10

**Summary:**
LunaUITweaks is a functional and modular addon that provides a wide range of utilities. Using a centralized `Core` and `Config` structure is a good design choice. However, the codebase suffers from **inconsistent architectural patterns**, particularly regarding module initialization and event handling.

**Brutally Honest Assessment:**
For a "performance-minded" player, the current implementation has several red flags.
1.  **Memory Waste:** Frames and heavy tables are often created immediately upon file load, regardless of whether the specific module is enabled.
2.  **CPU Spikes:** String manipulation in hot paths (ChatSkin) and iteration over group members (Loot) can cause micro-stutters.
3.  **Inconsistent "Context":** Some modules strictly check `enabled` flags, while others register `PLAYER_LOGIN` globally and always run initialization code.
4.  **Global Pollution:** While `UIThingsDB` is standard, `LunaUITweaks_TalentReminders` and inconsistent local vs. global tables (`addonTable.Loot` vs just `Loot` locals) make the code harder to debug.

If this addon is intended for high-end raiding/M+, these "death by a thousand cuts" inefficiencies must be resolved. The addon currently "leaks" performance even when features are turned off.

---

## 2. Load Conditions & Context Validity

**Critical Issue:** Modules are **not** truly disabled when unchecked. Usage of resources occurs simply by having the addon loaded.

*   **Loot.lua**:
    *   **Violation**: Creates `anchorFrame` and `activeToasts` table immediately at the file scope.
    *   **Violation**: Registers `PLAYER_LOGIN` via an anonymous frame at the bottom of the file **unconditionally**.
    *   **Impact**: Even if Loot is disabled, the frame exists, the event fires, and `UpdateRosterCache` is potentially primed.
*   **Misc.lua**:
    *   **Violation**: Creates `UIThingsPersonalAlert`, `UIThingsMailAlert`, `LunaSCTDamageAnchor`, `LunaSCTHealingAnchor` immediately at file scope.
    *   **Violation**: Registers `PLAYER_ENTERING_WORLD` unconditionally.
    *   **Impact**: Memory is allocated for these frames (pointers, textures, fontstrings) even if the user never uses SCT or Mail alerts.
*   **Combat.lua**:
    *   **Violation**: `PLAYER_LOGIN` is registered unconditionally at the bottom of the file.
    *   **Violation**: `CreateFrame("Frame", "UIThingsCombatTimer"...)` is called inside `Init`, but `logFrame` is created at file scope.

**Recommendation:**
*   Move all `CreateFrame` calls inside an `Initialize()` method.
*   Only register `PLAYER_LOGIN` in `Core.lua`.
*   Let `Core.lua` call `Module.Initialize()` **only if** `UIThingsDB.module.enabled` is true (or check internal enabled state before creating frames).

---

## 3. Memory Issues

*   **ChatSkin.lua (Critical)**:
    *   **Issue**: `GetChatContent` performs string concatenation `table.insert` loops on chat messages. While strictly user-triggered (Copy), iterating thousands of lines and performing multiple `gsub` calls on each is a massive memory churn (garbage collection pressure).
    *   **Fix**: Use `table.concat` efficiently, limit the copy depth (e.g., last 100 lines default), or optimize the regex patterns.
*   **TalentReminder.lua**:
    *   **Issue**: `snapshot` table in `CreateSnapshot` can become quite large.
    *   **Issue**: `LunaUITweaks_TalentReminders` is a global SavedVariable. If not cleaned up (which `CleanupSavedVariables` attempts to do, which is good), it bloats the SavedVariables file, increasing load times.
*   **Frame Bloat**:
    *   As mentioned in Load Conditions, creating frames like `sctDamageAnchor` (with backdrops, fontstrings) when SCT is disabled is pure waste. In Lua/WoW, created frames **cannot be destroyed**, only hidden. They sit in memory forever.
    *   **Fix**: Delay creation until the specific feature is enabled in Config.

---

## 4. Performance Issues

*   **ChatSkin.lua (Hot Path)**:
    *   **Issue**: `URLMessageFilter` and `KeywordMessageFilter` run on **every single chat message**.
    *   **Detail**: `FormatURLs` uses multiple `gsub` calls with complex patterns.
    *   **Impact**: In a spammy raid environment (or boosting channel spam), this will cause frame time spikes.
    *   **Fix**: Add a "throttle" or specific channel filter (e.g., don't scan Combat Log or heavy channels). Combine regex passes if possible.
*   **Combat.lua**:
    *   **Issue**: `ScanConsumableBuffs` iterates up to 40 buffs.
    *   **Issue**: `TimerOnUpdate` runs every frame (throttled check `if updateTimer >= 1.0`).
    *   **Optimization**: Event-based tracking (`UNIT_AURA`) is generally better than polling, though `UNIT_AURA` can be spammy. The current 10s ticker for weapon buffs (`StartWeaponBuffTicker`) is a reasonable compromise for that specific API.
*   **Loot.lua**:
    *   **Issue**: `UpdateRosterCache` iterates the entire raid (up to 40 loops) on `GROUP_ROSTER_UPDATE`.
    *   **Impact**: `GROUP_ROSTER_UPDATE` fires frequently during invite phases.
    *   **Fix**: Throttle this update (e.g., max once per 2 seconds) or only update when actually processing loot.

---

## 5. Maintainability Issues

*   **Inconsistent Initialization**:
    *   `Core.lua` explicitly initializes `Config`, `CheckSkin`, `TalentReminder`.
    *   `Loot.lua` and `Misc.lua` initialize themselves via internal event listeners.
    *   **Result**: Hard to trace execution flow. If `Core` changes load order, self-init modules might break or race.
*   **Magic Numbers & Hardcoding**:
    *   Fonts are often hardcoded as `"Fonts\\FRIZQT__.TTF"`.
    *   Colors are defined as tables `{ r=1, g=... }` in multiple places.
    *   **Fix**: Define a `Constants.lua` or `addonTable.Constants` for shared fonts, colors, and media.
*   **Global Variables**:
    *   `UIThingsDB` is a generic name. Consider names-pacing it to `LunaUITweaksDB` to avoid collisions.
    *   `LunaUITweaks_TalentReminders` is global.

---

## 6. Recommendations for "Demanding" Players

1.  **Lazy Loading**: Rewrite all modules to **not** do anything (no frame creation, no event registration) until `Initialize()` is called by Core.
2.  **Strict Event Management**: Verify that `UnregisterAllEvents()` is called immediately when a module is disabled via Config.
3.  **GC Optimization**: Review `ChatSkin` regex. Avoid creating temporary tables in `OnUpdate` or frequent event handlers (e.g., `ScanConsumableBuffs` is okay as it seemingly uses locals, but check for hidden table creations in `GetBuffDataByIndex`).
4.  **Profile Profiling**: Use a CPU profiler (like AddonUsage or internal profiler) to measure the impact of `URLMessageFilter` during a raid encounter.
