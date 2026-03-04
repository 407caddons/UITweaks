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

Tests whether a value is "secret" — set by Blizzard's secure code and unreadable by addon Lua without tainting.

**When to check:**
- Before reading event parameters that may be GUIDs or unit references set during secure execution.
- Known secret values: `interruptedBy` in `UNIT_SPELLCAST_INTERRUPTED` (see [combat-spell.md](combat-spell.md)).
- DamageMeter frame fields: `sessionType`, `damageMeterType`, `nameText` result — all secret.

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
