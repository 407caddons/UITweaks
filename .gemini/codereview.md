# LunaUITweaks Whole-Project Code Review

Below are the **Top 5** most critical issues currently affecting the addon's performance, stability, and maintainability.

## 1. ActionBars.lua - High Risk of "Action Blocked" / Taint
**Severity: Critical (Game-breaking bug)**
*   **Issue:** In `PatchMicroMenuLayout()`, the addon deliberately overwrites Blizzard UI functions (`MicroMenuContainer.GetEdgeButton`, `UpdateHelpTicketButtonAnchor`) as well as directly injecting into the frame's metatable (`__index`). 
*   **Impact:** Modifying Blizzard frame methods globally in this way is a massive vector for UI Taint in the modern UI. This will inevitably result in `"LunaUITweaks has been blocked from an action only available to the Blizzard UI"` errors in combat, potentially locking the player out of secure actions.
*   **Fix:** Never override native frame methods. The UI should rely on safe frame-hiding alpha shifts, reparenting strategies, or standard hooking, rather than rewriting Blizzard’s internal `Layout()` logic.

## 2. Combat.lua - Infinite Recursion Loop Memory Leak
**Severity: High (Memory/CPU Leak)**
*   **Issue:** In `TrackConsumableUsage()`, the code queries `GetItemInfo(itemID)`. If this returns `nil` (which happens if the item is not cached), it calls `C_Item.RequestLoadItemDataByID` and reschedules itself via `C_Timer.After(0.5, ...)`.
*   **Impact:** If an invalid, deprecated, or removed `itemID` is ever passed to this function (for example, from old saved variables), `GetItemInfo` will *never* return valid data. This creates an infinite, endless timer loop in the background firing every 0.5 seconds for the rest of the game session, bleeding CPU cycles and memory.
*   **Fix:** Add a maximum retry attempt counter parameter to `TrackConsumableUsage()`, terminating the loop if the item fails to resolve after ~5-10 attempts.

## 3. Warehousing.lua - Extreme Garbage Collection Overload
**Severity: High (Performance)**
*   **Issue:** The helper function `GetNameFromHyperlink()` is called via `SlotMatchesTracked()` across all bag indexes during `ScanBags()` and `FindItemSlots()`. This function executes extensive regex and string mutations (`name:gsub("|A.-|a", "")` and `name:match("^%s*(.-)%s*$")`).
*   **Impact:** This happens for **every single item in the player's bags** every time a bag update is processed. Generating and throwing away thousands of dynamically mutated strings creates a tremendous amount of garbage for the Lua garbage collector, leading directly to stuttering frames when opening the bank or looting items.
*   **Fix:** The addon should cache the resolved canonical name of the `itemID` in a persistent table lookup upon initial load, completely avoiding runtime regex during bag iterations.

## 4. ObjectiveTracker.lua - Expensive API Calls Inside Sorting Algorithms
**Severity: Medium (Performance)**
*   **Issue:** The sorting functions `sortByDistanceSq` and `sortWatchIndexByDistance` are passed directly into `table.sort`. Inside these comparisons, they cross the C API boundary by calling `C_QuestLog.GetDistanceSqToQuest()`.
*   **Impact:** `table.sort` evaluates frequently ($O(N \log N)$ complexity). Repeatedly jumping the lua-to-C boundary inside the deepest loop of the sorting algorithm incurs noticeable lag when dealing with a high number of active quests or world quests.
*   **Fix:** Create an intermediary `distances` caching table right before the sort executes. Loop through the quests exactly once ($O(N)$) to populate `distances[questID] = C_QuestLog.GetDistanceSqToQuest()`, and refer to this flat lookup table inside the `table.sort` comparator.

## 5. Combat.lua - Heavy Polling on Strings
**Severity: Medium (Performance)**
*   **Issue:** `ScanConsumableBuffs()` loops up to 40 aura slots via `C_UnitAuras.GetBuffDataByIndex`, executing string lowercases (`string.lower`) and substring pattern checks (`string.find`) against things like `"well%s-fed"`.
*   **Impact:** Even though there is a rudimentary `lastAuraScanTime` throttle cache, it gets polled repeatedly during combat. Doing deep string sweeps sequentially across all buffs creates unneeded baseline CPU pressure when in raids.
*   **Fix:** Rather than polling by time, register for the `UNIT_AURA` event for the `"player"`. Update the consumed state exactly only when buffs are added or removed, relying on specific aura IDs or direct name matches instead of regex fallbacks if possible.
