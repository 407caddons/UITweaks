# Secure & Protected Frame APIs

The most dangerous territory in WoW addon development. These APIs govern what can and cannot be done during combat lockdown, and how to safely reposition Blizzard-owned frames.

---

## InCombatLockdown

See [combat-spell.md](combat-spell.md) for full documentation. Summary:

```lua
if InCombatLockdown() then return end
```

Guard every call to: `SetPoint`, `ClearAllPoints`, `SetSize`, `SetParent`, `Show`, `Hide`, `RegisterStateDriver`, `UnregisterStateDriver` on any Blizzard-owned frame.

---

## RegisterStateDriver / UnregisterStateDriver

```lua
RegisterStateDriver(frame, "attribute", "condition1 value1; condition2 value2; default")
UnregisterStateDriver(frame, "attribute")
```

Drives a frame attribute based on a macro-condition string evaluated continuously by the secure environment.

**Common use — combat-safe visibility:**
```lua
RegisterStateDriver(frame, "visibility", "[combat] hide; show")
RegisterStateDriver(frame, "visibility", "[combat] show; hide")
```

**Requirements:**
- The `frame` **must** inherit from `"SecureHandlerStateTemplate"` to use state drivers for arbitrary attributes.
- For `visibility` specifically, any frame can use it — but `RegisterStateDriver` itself must be called **outside combat**.
- `UnregisterStateDriver` must also be called outside combat.

**Caveat:** Plain Blizzard child frames (Background, Header, dropdown children) do **not** have `SetAttribute` and will error if you attempt to `RegisterStateDriver` on them. Only use on frames you created with `"SecureHandlerStateTemplate"`.

---

## SecureHandlerStateTemplate

```lua
local handler = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
handler:SetFrameRef("targetFrame", targetFrame)
handler:SetAttribute("_onstate-combat", [[
    -- This is Lua but runs in the restricted (secure) environment
    local frame = self:GetFrameRef("targetFrame")
    if newstate == "combat" then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", ...)
    end
]])
RegisterStateDriver(handler, "combat", "[combat] combat; nocombat")
```

**What the restricted environment CAN do:**
- Call `frame:ClearAllPoints()`, `frame:SetPoint(...)` on protected frames — this is the point of using it.
- Access frames via `self:GetFrameRef("name")`.
- Read attributes via `self:GetAttribute("name")`.

**What the restricted environment CANNOT do:**
- Call most Lua standard library functions.
- Access addon globals or upvalues.
- Call `C_Timer.After`, `print`, or any non-restricted API.

**ActionBars.lua pattern (three-layer positioning):**
1. Use `SetPointBase`/`ClearAllPointsBase` to bypass edit-mode overrides.
2. Hook `SetPointBase` to re-apply offsets when Blizzard re-layouts.
3. Use `SecureHandlerStateTemplate` + `RegisterStateDriver` for combat transitions.

```lua
-- Layer 1: direct positioning
local clearPoints = barFrame.ClearAllPointsBase or barFrame.ClearAllPoints
local setPoint = barFrame.SetPointBase or barFrame.SetPoint
clearPoints(barFrame)
setPoint(barFrame, "CENTER", UIParent, "CENTER", x, y)

-- Layer 2: hook to re-apply on Blizzard layout
local suppressHook = false
hooksecurefunc(barFrame, "SetPointBase", function(self, ...)
    if suppressHook then return end
    suppressHook = true
    clearPoints(barFrame)
    setPoint(barFrame, "CENTER", UIParent, "CENTER", x, y)
    suppressHook = false
end)

-- Layer 3: secure handler for combat transitions
local handler = CreateFrame("Frame", nil, nil, "SecureHandlerStateTemplate")
handler:SetFrameRef("bar", barFrame)
handler:SetAttribute("xOfs", x)
handler:SetAttribute("yOfs", y)
handler:SetAttribute("_onstate-combat", [[
    local bar = self:GetFrameRef("bar")
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", UIParent, "CENTER",
        self:GetAttribute("xOfs"), self:GetAttribute("yOfs"))
]])
RegisterStateDriver(handler, "combat", "[combat] combat; nocombat")
```

---

## SetAttribute / GetAttribute

```lua
frame:SetAttribute("name", value)
local value = frame:GetAttribute("name")
```

- Only frames inheriting `"SecureHandlerStateTemplate"` (or other secure templates) have `SetAttribute`.
- Attributes can be read by both normal and restricted Lua.
- **Setting attributes on protected frames during combat is blocked.** Pre-set all needed values before combat.

---

## issecretvalue

```lua
local isSecret = issecretvalue(value)
```

Tests whether a value is "secret" — returned by Blizzard's secure/restricted code path and subject to usage restrictions in addon Lua.

**Complete rules for secret values** (verified against DamageMeter development and Details addon source):

### What FAILS with secret values
| Operation | Error |
|---|---|
| `table[secretKey] = v` | `"table index is secret"` |
| `secretVal > 0`, `secretVal < x` | `"attempt to compare ... secret number value"` |
| `secretVal >= x`, `secretVal <= x` | Same comparison error |

### What WORKS with secret values
| Operation | Notes |
|---|---|
| `type(secretVal) == "number"` | Type check — safe, returns `"number"` |
| `secretVal + x`, `secretVal * x`, `secretVal / x` | Arithmetic — works **only if `secretVal` is still a direct Blizzard-tainted local** (not copied into your own table first) |
| `string.format("%d", secretVal)` | C-level — safe on tainted values |
| `AbbreviateNumbers(secretVal)` | WoW C-level function — safe on tainted values, no Lua comparison |
| `frame:SetText(secretString)` | Displays the actual string — works |
| `frame:SetWidth(secretNum)` | Sets visual property — works |
| `UnitName(secretString)` | Accepts a secret name and returns the real display name |
| `local t = { val = secretVal }` | Storing as table **value** — safe |
| Passing to function as argument | Safe as long as the function doesn't table-key it or compare it |

### What ALSO FAILS (confirmed in practice)
| Operation | Notes |
|---|---|
| `secretVal >= x`, `secretVal <= x` | Comparisons fail even when called via function arg — e.g. `AbbreviateNumber(src.totalAmount)` → `if value >= 1000000` fails |
| `frame:SetValue(secretNum)` on StatusBar inside ScrollFrame | Taints StatusBar frame geometry → `UpdateScrollChildRect` → "numeric conversion on secret value" |
| `frame:SetMinMaxValues(0, secretNum)` on StatusBar inside ScrollFrame | Same — taints bar layout, breaks scroll child rect calculation |

**Key distinction — Blizzard-tainted vs LunaUITweaks-tainted:**
- Values returned directly from WoW C APIs (`C_DamageMeter`, etc.) via `pcall` in addon Lua are tainted by the addon calling context — they become LunaUITweaks-tainted, not just Blizzard-tainted.
- LunaUITweaks-tainted: comparisons AND arithmetic both fail.
- Use WoW C-level functions (`AbbreviateNumbers`, `string.format`) to format tainted numbers for display.

### Pattern for C_DamageMeter live combat data
During combat all `combatSources` fields are secret: `sourceGUID`, `name`, `totalAmount`, `amountPerSecond`, `maxAmount`. Use numeric indices as table keys, avoid comparisons and StatusBar with secret values:

```lua
local ok, sessData = pcall(C_DamageMeter.GetCombatSessionFromType, 1, enumType)
if ok and sessData and sessData.combatSources then
    for i, src in ipairs(sessData.combatSources) do
        if type(src.totalAmount) == "number" then  -- type() is safe
            local displayName
            if src.isLocalPlayer then              -- isLocalPlayer is NOT secret
                displayName = UnitName("player")
            else
                displayName = UnitName(src.name)   -- UnitName accepts secret strings
                    or src.classFilename           -- classFilename is NOT secret
            end
            -- Bar: DO NOT pass secret values to StatusBar inside a ScrollFrame
            -- — taints frame geometry, breaks UpdateScrollChildRect
            row.bar:SetMinMaxValues(0, 1)
            row.bar:SetValue(1)  -- full-width; proportional bars require comparison
            -- Text: use WoW C-level AbbreviateNumbers — no Lua comparison
            row.valFS:SetText(AbbreviateNumbers(src.totalAmount))
            row.dpsFS:SetText(AbbreviateNumbers(src.amountPerSecond) .. "/s")
        end
    end
end
-- DON'T sort: table.sort comparator uses > which fails on secret numbers
-- DON'T filter: if total > 0 fails; use type() check instead
-- DON'T store totalAmount in your own table then do arithmetic — fails
-- DON'T call Abbrev/FormatVal (custom Lua) with secret numbers — Lua comparisons fail
-- DON'T pass secret values to SetMinMaxValues/SetValue on StatusBar in ScrollFrame — taints geometry
-- DO use AbbreviateNumbers() (WoW C-level) for formatting tainted numbers
-- DO use string.format("%d", secretVal) for count types
```

**Non-secret fields in combatSources during combat:** `isLocalPlayer`, `classFilename`, `specIconID`, `classification`, `deathRecapID`.

**When to check `issecretvalue`:**
- Use it to detect whether data is still live/locked (like `isServerSideSessionOpen` in Details).
- Known secret event params: `interruptedBy` in `UNIT_SPELLCAST_INTERRUPTED`.
- Do NOT gate entire entries on `issecretvalue(totalAmount)` — this causes "no data" during combat.

---

## Full Taint Rules Reference

### Operations that CAUSE taint
| Operation | Reason |
|---|---|
| `hooksecurefunc(frame, "Method", cb)` | Taints the frame's method table |
| `frame:HookScript("OnEvent", cb)` | Taints frame context |
| `frame.myField = value` | Writes into the Blizzard frame table |
| `local t = blizzardFS:GetText()` | The returned string is tainted |
| Reading `frame.secretField` | Value set by secure code propagates taint |
| `SetPoint` on protected frame in combat | Blocked entirely, raises error |

### Operations that are SAFE on Blizzard frames
| Operation | Notes |
|---|---|
| `frame:GetWidth()`, `frame:GetHeight()` | Numbers are not tainted |
| `frame:GetLeft()`, `frame:GetBottom()` | Screen coords, not tainted |
| `frame:IsShown()`, `frame:IsVisible()` | Booleans, not tainted |
| `frame:SetAlpha(n)` | Visual-only, no taint |
| `frame:EnableMouse(bool)` | Safe |
| `hooksecurefunc("GlobalFunc", cb)` | Global form only, safe |

### Frames confirmed as untouchable in this addon
| Frame | Issue |
|---|---|
| `DamageMeter` | All methods tainted; no-op stub required |
| `DamageMeterSessionWindow*` | Same as DamageMeter |
| `QueueStatusButton` | Button prototype taint from any hook/HookScript |
| `MinimapCluster.InstanceDifficulty` | Button prototype taint |
| `ObjectiveTrackerFrame` | Taint issues with suppression; left alone |

---

## Relevant Events

| Event | Description |
|---|---|
| `PLAYER_REGEN_DISABLED` | Combat started — lockdown begins |
| `PLAYER_REGEN_ENABLED` | Combat ended — safe to reposition |
