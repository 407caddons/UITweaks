# LunaUITweaks Code Review

This code review evaluates the `LunaUITweaks` project focusing on performance, memory management, and maintainability. Per the request, no files are recommended to be broken up, but the impact of their current design is discussed.

## 1. Executive Summary

`LunaUITweaks` is a large and feature-rich addon utilizing centralized settings (`UIThingsDB`) and a modular approach. While it is built with several optimizations (such as custom frame pooling and throttled updates), it also leverages extensive hooking of Blizzard's secure API and excessively large module files. These factors can introduce fragility, taint risks, and slight performance degradation during intense combat.

## 2. Performance Issues

### Heavy Use of `hooksecurefunc` in Hot Paths
- **`Combat.lua`**: Hooks `UseAction`, `UseContainerItem`, and `C_Container.UseContainerItem`. These functions are executed every time the player presses a button or uses an item in their bags. While checking consumables is fast, adding any overhead to these core interactions can lead to micro-stutters during heavy combat sequences, especially for classes with high APM.
- **`ActionBars.lua`**: Hooks functions like `UpdateMicroButtons` and `QueueStatusButton:SetPoint`. Since these UI elements can update dynamically, hooking them means your addon's logic will run often. 

### Event and Update Loops
- The addon features multiple `OnUpdate` scripts across different files (e.g., `Widgets.lua`, `CastBar.lua`, `Combat.lua`, `Speed.lua`). While some are accurately throttled (like `TimerOnUpdate` in `Combat.lua` which is set to 1.0s), multiple unthrottled or individually handled `OnUpdate` scripts cause unnecessary UI frame delays.
- **Recommendation**: Consider a centralized `OnUpdate` or `C_Timer.NewTicker` manager in `Core.lua` that dispatches to modules. This reduces the number of function closures executed uniquely every frame.

### Aura Scanning
- Inside `Combat.lua`, `ScanConsumableBuffs` uses a manual loop over 40 aura slots instead of specific targeted searches (e.g., using `AuraUtil.FindAura` with a predicate or `AuraUtil.AuraFilters.Helpful`). While mitigated by caching (`lastAuraScanTime`), standardizing this could increase combat efficiency slightly.

## 3. Memory & API Safety

### Frame Pooling vs. Garbage Collection
- **`ObjectiveTracker.lua`**: Has its own manual pooling implementation (`itemPool` array). While effective at preventing raw memory leaks, reinventing the wheel prevents taking advantage of Blizzard's `CreateFramePool` or `CreateFramePoolCollection`, which are highly optimized internally.
- By managing frames manually (looping over them to hide and set their content), `ReleaseItems` and `AcquireItem` introduce slight O(N) linear time scanning whenever objectives are updated.

### Taint and UI Fragility
- **`ActionBars.lua`**: Aggressively overrides Blizzard's layout engines to re-parent the micro-menu (`PatchMicroMenuLayout` overriding `MicroMenuContainer.GetEdgeButton` and patching its metatable). This is an extremely dangerous pattern in modern WoW Addon development. 
- Overwriting metatables of secure Blizzard UI elements often directly leads to `ADDON_ACTION_BLOCKED` errors in combat. It also means that any minor UI patch by Blizzard could silently break your whole ActionBars module. 

## 4. Maintainability

- **Monolithic Files**: Although you requested not to split files up, the file size must be reported as a serious maintainability drag:
  - `ObjectiveTracker.lua` (~2200 lines / 88 KB)
  - `TalentManager.lua` (~1800 lines / 73 KB)
  - `ActionBars.lua` (~1650 lines / 61 KB)
  - `Kick.lua` (~57 KB)
  - `Combat.lua` (~1200 lines / 42 KB)
- These monolithic structures result in vast scope complexities, deeply nested logic, and large amounts of local state variables acting essentially as file-wide globals. Finding a bug or feature in a 2000-line file requires intricate knowledge of the entire file's scope. 
- **Recommendation**: If splitting is forbidden, ensure robust and heavily standardized section headers, consistent local variable declarations strictly at the top, and well-documented forward declarations.

## 5. Summary Fixes and Actionable Items

1. **Remove / Reduce Hot Hooks**: Re-evaluate the necessity of `UseAction` hooks in `Combat.lua`. Consider if consumable tracking can be performed on an event like `UNIT_AURA` or `SPELL_UPDATE_USABLE` or even a soft `C_Timer` ticker.
2. **Refactor ActionBars Patching**: The overriding of `MicroMenuContainer` methods in `ActionBars.lua` is a ticking time-bomb for Taint errors. Try to achieve visual modifications via `ClearAllPoints()` and overlay frames rather than fundamentally hacking Blizzard's Layout engines.
3. **Consolidate OnUpdate**: Use a single update ticker for non-frame-perfect updates (like speed calculations, combat durations) to alleviate CPU burden.

---
*Review complete based on current directory state.*
