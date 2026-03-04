# Timer APIs

WoW provides `C_Timer` for deferred and repeating callbacks. No built-in `setTimeout`/`setInterval` — use these instead.

---

## C_Timer.After

```lua
C_Timer.After(delay, callback)
```

Calls `callback` once after `delay` seconds. Returns nothing (no cancel handle).

**Used in:** Core.lua (via `SafeAfter`), Loot.lua, Vendor.lua, Combat.lua, TalentReminder.lua, Kick.lua, AddonComm.lua, multiple widgets.

**Caveats:**
- There is **no way to cancel** a `C_Timer.After` callback once scheduled. Design code to be idempotent or guard with a flag.
- If the callback errors, WoW will print the error but continue. The addon wraps all `C_Timer.After` calls in `addonTable.Core.SafeAfter` to pcall-protect them:
  ```lua
  function Core.SafeAfter(delay, func)
      C_Timer.After(delay, function()
          local ok, err = pcall(func)
          if not ok then Core.Log("Core", err, 3) end
      end)
  end
  ```
- `delay = 0` defers to the next frame — useful for "run after current event handlers complete".
- Do **not** use `C_Timer.After` in a tight loop to simulate polling — use `C_Timer.NewTicker` instead.

---

## C_Timer.NewTimer

```lua
local timer = C_Timer.NewTimer(delay, callback)
timer:Cancel()
```

Like `C_Timer.After` but returns a cancelable handle.

**Used in:** AddonComm.lua (throttled broadcast scheduling).

**Caveats:**
- Call `timer:Cancel()` before the timer fires to prevent the callback. Calling `:Cancel()` on an already-fired timer is a no-op (safe).
- Store the handle in a variable or table so you can cancel it. If the reference is lost, the timer cannot be cancelled.
- Replaces the `C_Timer.After` + flag pattern when you need genuine cancellation.

---

## C_Timer.NewTicker

```lua
local ticker = C_Timer.NewTicker(interval, callback [, iterations])
ticker:Cancel()
```

Calls `callback` every `interval` seconds. If `iterations` is provided, fires that many times then stops automatically.

**Used in:** widgets/Group.lua (group roster polling), Kick.lua (cooldown polling), MinimapCustom.lua (clock update).

**Caveats:**
- Returns a handle — store it to cancel later (e.g. when the frame is hidden or the module is disabled).
- If `iterations` is omitted, the ticker runs **forever** until explicitly cancelled — a common source of memory leaks if the handle is discarded.
- The `interval` is wall-clock seconds, not game ticks. Minimum practical interval is ~0.05s (one frame at 20fps).
- `ticker:Cancel()` after automatic completion is safe (no-op).

---

## GetTime

```lua
local t = GetTime()  -- returns seconds since WoW client started (float)
```

Used for elapsed-time calculations. **Not** wall-clock time — use `date()` or `time()` for real-world timestamps.

**Used in:** Combat.lua (timer duration), CastBar.lua, Loot.lua, AddonComm.lua (rate-limit/dedup windows), Kick.lua, widgets/BattleRes.lua, widgets/PullTimer.lua.

**Pattern for elapsed timing:**
```lua
local startTime = GetTime()
-- ... later ...
local elapsed = GetTime() - startTime
```

**Pattern for rate-limiting:**
```lua
local lastSend = 0
local MIN_INTERVAL = 1.0
if GetTime() - lastSend < MIN_INTERVAL then return end
lastSend = GetTime()
-- do the thing
```
