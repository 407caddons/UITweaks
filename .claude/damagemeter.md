# Blizzard Damage Meter — API & Frame Reference (WoW 12.0 / The War Within)

This document captures all relevant frame names, child frames, fields, events, C_ APIs, and taint hazards discovered while working with the Blizzard built-in damage meter in LunaUITweaks. Intended as a reference for addon authors interacting with or skinning the built-in meter.

---

## Frame Hierarchy

### Root Frame
| Frame Name | Type | Notes |
|---|---|---|
| `DamageMeter` | Frame (parent container) | Always exists once the feature loads. Discovered via `DamageMeterSessionWindow1:GetParent()` — its `GetName()` returns `"DamageMeter"`. Use this as the authoritative parent reference. |
| `DamageMeterSessionWindow1` | Frame (session pane) | First (and usually only) session pane. Access via `_G["DamageMeterSessionWindow1"]`. |
| `DamageMeterSessionWindow2` | Frame (session pane) | Second session pane (shown when user opens a second session). Iterate with `i = 1, 2, …` until `_G["DamageMeterSessionWindow" .. i]` is nil. |

### Discovering session windows at runtime
```lua
-- Safe pattern: iterate until nil, filter by IsShown()
local function GetSessionWindows()
    local list = {}
    local i = 1
    while true do
        local w = _G["DamageMeterSessionWindow" .. i]
        if not w then break end
        if w:IsShown() then
            list[#list + 1] = w
        end
        i = i + 1
    end
    return list
end
```
Blizzard hides rather than destroys session windows, so check `IsShown()` rather than trusting existence alone.

---

## Child Frames on Each Session Window (`DamageMeterSessionWindowN`)

| Field Name | Type | Purpose | Safe Operations |
|---|---|---|---|
| `win.Background` | Frame | Dark background panel behind meter rows | `SetAlpha()`, `EnableMouse()` — safe. `SetPoint`, `SetSize`, `SetParent` — taint. |
| `win.Header` | Frame | Title/header strip above rows. Has a `GetHeight()` you can read. | `SetAlpha()`, `EnableMouse()`, `SetHeight()` — safe. `SetPoint`, `SetParent` — taint. |
| `win.DamageMeterTypeDropdown` | Button/Dropdown | Selects the meter type (damage out, healing, etc.) | `SetAlpha()` — safe. `SetParent`, `SetPoint`, `ClearAllPoints` — **taint**. `HookScript("OnMouseDown", ...)` — taint risk, see below. |
| `win.SessionDropdown` | Button/Dropdown | Selects current vs. overall session | `SetAlpha()` — safe. `SetParent`, `SetPoint`, `ClearAllPoints` — **taint**. |
| `win.SettingsDropdown` | Button/Dropdown | Opens meter settings | `SetAlpha()` — safe. `SetParent`, `SetPoint`, `ClearAllPoints` — **taint**. |
| `win.DamageMeterTypeDropdown.TypeName` | FontString | Holds a text label for the current meter type | `GetText()` — **⚠ tainted string returned** (secret value, see below). |

---

## Fields on Session Windows — SECRET VALUES

These fields exist on `DamageMeterSessionWindowN` and carry data set by Blizzard's secure code. They are **secret values** — readable by addon Lua but taint the addon context when accessed. Using them in string comparisons or number arithmetic may produce Blizzard UI errors (`nameText`, `durationSeconds` corruption observed).

| Field | Type | Values | Secret? |
|---|---|---|---|
| `win.damageMeterType` | number | `0`=Damage Out, `1`=Damage In, `2`=Heal Out, `3`=Heal In, `4`=Deaths, `5`=Effective Heal | **Yes — secret value** |
| `win.sessionType` | number | `0`=Current live session, `1`=Past/overall session | **Yes — secret value** |

**What "secret value" means in practice:**
- `issecretvalue(win.damageMeterType)` returns `true`.
- Assigning or comparing the value in addon code taints the calling function's Lua context.
- Polling the field with `OnUpdate` and comparing `prev ~= current` causes taint the moment the comparison is evaluated.
- **Safer workaround:** poll the field in a short-lived `OnUpdate` watcher (2-second deadline), read it just once when the value appears to have changed, discard the watcher immediately. Avoid storing the value in shared upvalues or using it in shared functions.

---

## Methods on Session Windows

| Method | Notes |
|---|---|
| `win:SetSessionType(...)` | Exposed by Blizzard when it exists. Hook with `hooksecurefunc(win, "SetSessionType", cb)` — **this is an object-form hook and causes taint on the session window frame**. |

---

## C_ Namespace APIs

| API | Returns | Notes |
|---|---|---|
| `C_DamageMeter.IsDamageMeterAvailable()` | `boolean` | Returns `true` if the built-in meter is available for the current character/realm. Not present on all builds — guard with `if C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable`. |

---

## WoW Events

| Event | When fires | Payload |
|---|---|---|
| `DAMAGE_METER_CURRENT_SESSION_UPDATED` | When the current live session data updates (new combat, new window opened) | None |
| `DAMAGE_METER_COMBAT_SESSION_UPDATED` | When a combat session record changes (fight ended, session renamed, etc.) | None |
| `PLAYER_ENTERING_WORLD` | On login and zone transitions | Use to (re-)initialize meter hooks after 1s delay |
| `PLAYER_REGEN_ENABLED` | On leaving combat | Use to apply positioning that was deferred during combat |

---

## Meter Type Name Mapping

The `damageMeterType` integer maps to these display names (as observed from `win.DamageMeterTypeDropdown.TypeName:GetText()` when not tainted, or from hard-coded fallback):

```lua
local METER_TYPE_NAMES = {
    [0] = "Dmg Out",
    [1] = "Dmg In",
    [2] = "Heal Out",
    [3] = "Heal In",
    [4] = "Deaths",
    [5] = "Eff Heal",
}
```

---

## Taint Hazards — Critical Rules

These are hard-won lessons. Violating them causes `ADDON_ACTION_BLOCKED` or corrupts Blizzard UI internal state.

### Things that WILL cause taint / blocking errors
| Action | Why |
|---|---|
| `win:SetPoint(...)` | Protected positioning method on Blizzard frame |
| `win:ClearAllPoints()` | Protected positioning method |
| `win:SetSize(...)` | Protected sizing method |
| `win:SetParent(...)` | Taints the frame table |
| `win:SetAllPoints(...)` | Protected positioning |
| `frame.myField = x` written onto any Blizzard session frame | Taints the entire frame table — corrupts internal string/number comparisons |
| `win.DamageMeterTypeDropdown.TypeName:GetText()` | Returned string is tainted — store in upvalue, use carefully |
| `hooksecurefunc(win, "SetSessionType", cb)` | Object-form hook — taints `win` frame table |
| `win:HookScript("OnEvent", cb)` | Taints frame context |
| `win.DamageMeterTypeDropdown:HookScript("OnMouseDown", cb)` | Taints the Button dropdown frame — causes prototype taint visible in map pins and other Blizzard UI |
| Reading `win.damageMeterType` or `win.sessionType` in shared functions | Taints calling Lua context via secret value propagation |
| `meterWindow:SetPoint(...)` on `DamageMeter` | Taints frame layout |
| `RegisterStateDriver` on child frames without `SecureHandlerStateTemplate` | Frames like `Background`, `Header`, dropdowns do NOT have `SetAttribute` — will error |

### Things that ARE safe on Blizzard frames
| Action | Notes |
|---|---|
| `win.Background:SetAlpha(0)` | Visual-only, no taint |
| `win.Background:EnableMouse(false)` | Input enable/disable — safe |
| `win.Header:SetAlpha(0)` | Safe |
| `win.Header:SetHeight(0.001)` | Safe (collapses the header row visually) |
| `win.Header:GetHeight()` | Safe read — returns number, not tainted |
| `meterWindow:GetWidth()` | Safe geometry read |
| `meterWindow:GetHeight()` | Safe geometry read |
| `meterWindow:GetLeft()` | Safe screen-coordinate read |
| `meterWindow:GetBottom()` | Safe screen-coordinate read |
| `win:IsShown()` | Safe boolean read |
| `win.DamageMeterTypeDropdown:SetAlpha(0)` | Safe — visual only |
| `hooksecurefunc("GlobalFunctionName", cb)` | Global-form hook — safe |
| `hooksecurefunc(meterWindow, "SetPoint", cb)` | Object-form hook on `DamageMeter` parent — causes taint on `meterWindow` but acceptable if you don't use meterWindow for Blizzard UI logic |
| `meterWindow:HookScript("OnHide", cb)` | Causes taint on `meterWindow` frame; avoid if possible |
| `skinFrame:SetBackdrop(...)` | Safe — skinFrame is an addon-created frame |

---

## Hook Patterns (with Taint Trade-offs)

### Watching for position changes (moderate taint risk)
```lua
-- Object-form — taints meterWindow, but meterWindow isn't used in Blizzard UI logic
hooksecurefunc(meterWindow, "SetPoint", function()
    SafeAfter(0, SyncOverlay)
end)
```

### Watching for session type changes (polling — avoids comparison taint)
```lua
-- Poll with a short-lived OnUpdate watcher, 2s deadline
win.SessionDropdown:HookScript("OnMouseDown", function()  -- WARNING: taints SessionDropdown
    local deadline = GetTime() + 2.0
    local prev = capturedWin.sessionType  -- reading secret value
    local watcher = CreateFrame("Frame")
    watcher:SetScript("OnUpdate", function(self)
        if GetTime() > deadline then self:SetScript("OnUpdate", nil) return end
        if capturedWin.sessionType ~= prev then  -- secret value comparison
            self:SetScript("OnUpdate", nil)
            RefreshAll()
        end
    end)
end)
```
> **Note:** Both `HookScript("OnMouseDown")` on a Blizzard Button frame AND reading `sessionType` in a comparison propagate taint. The LunaUITweaks DamageMeter module accepts this taint because the meter itself is isolated. For a cleaner implementation, avoid these entirely and rely solely on the `DAMAGE_METER_CURRENT_SESSION_UPDATED` and `DAMAGE_METER_COMBAT_SESSION_UPDATED` events.

### Safest approach: event-only, no hooks
```lua
EventBus.Register("DAMAGE_METER_CURRENT_SESSION_UPDATED", function()
    -- refresh labels/overlays here
end)
EventBus.Register("DAMAGE_METER_COMBAT_SESSION_UPDATED", function()
    -- refresh labels here
end)
```

---

## Session Window Sizing Pattern (Combat-Safe)

Direct `SetPoint`/`SetSize` on session windows requires out-of-combat. Always guard:

```lua
if not InCombatLockdown() then
    for i, win in ipairs(wins) do
        win:ClearAllPoints()
        win:SetPoint("TOPLEFT", meterWindow, "TOPLEFT", slotW * (i - 1), 0)
        win:SetSize(sessW, meterH)
    end
end
```

---

## Positioning the DamageMeter Parent

`DamageMeter` (the parent frame) IS repositionable with `ClearAllPoints` + `SetPoint` out of combat. Use CENTER-relative convention:

```lua
meterWindow:ClearAllPoints()
meterWindow:SetPoint("CENTER", UIParent, "CENTER", x, y)
```

Where `x, y` are offsets from `UIParent:GetCenter()`. Save position from drag:
```lua
local cx, cy   = self:GetCenter()
local pcx, pcy = UIParent:GetCenter()
savedX = math.floor(cx - pcx + 0.5)
savedY = math.floor(cy - pcy + 0.5)
```

---

## Overlay / Skin Frame Strategy (Safe Pattern)

Rather than modifying Blizzard frames, create an **addon-owned** frame that wraps the meter:

1. Create `CreateFrame("Frame", "MySkinFrame", UIParent, "BackdropTemplate")` — fully addon-owned, no taint.
2. Read `meterWindow:GetLeft()` + `meterWindow:GetBottom()` to get position (safe reads).
3. Size and position `skinFrame` to wrap the meter using `skinFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)`.
4. Use `SetAlpha(0)` on Blizzard child frames (`Background`, `Header`, dropdowns) to hide their chrome without taint.
5. On `meterWindow:HookScript("OnHide")` — hide your skinFrame too.

---

## Initialization Timing

The meter frames may not exist immediately on `ADDON_LOADED`. Safe pattern:

```lua
EventBus.Register("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(1, function()
        -- DamageMeter and session windows are ready by now
        local meterWindow = _G["DamageMeter"] or
            (_G["DamageMeterSessionWindow1"] and _G["DamageMeterSessionWindow1"]:GetParent())
    end)
end)
```

---

## Known Safe Global Functions to Hook

```lua
hooksecurefunc("FCF_OpenNewWindow", OnChatFrameChange)  -- floating chat opened
hooksecurefunc("FCF_Close", OnChatFrameChange)           -- floating chat closed
```

These are global-form hooks (not object-form) and do not cause taint.

---

## Summary of What You Can and Cannot Do

| Goal | Can Do | Cannot Do |
|---|---|---|
| Detect if meter is available | `C_DamageMeter.IsDamageMeterAvailable()` | — |
| Get meter position/size | `GetLeft()`, `GetBottom()`, `GetWidth()`, `GetHeight()` | — |
| Hide Blizzard chrome | `SetAlpha(0)`, `EnableMouse(false)` on children | `SetParent`, `SetPoint`, `SetSize` |
| Add custom backdrop/border | Create separate addon frame, wrap around meter | Modify Blizzard frame backdrop |
| Reposition meter | `SetPoint`/`ClearAllPoints` out of combat only | In combat, any positioning call |
| Know meter type | Read `win.damageMeterType` (secret, taints) or poll | GetText on TypeName FontString (also taints) |
| Know session type | Read `win.sessionType` (secret, taints) or poll | — |
| React to data updates | `DAMAGE_METER_CURRENT_SESSION_UPDATED`, `DAMAGE_METER_COMBAT_SESSION_UPDATED` events | — |
| Write state onto Blizzard frames | — (always taints) | `win.myField = x` |
| Reposition session windows | Out-of-combat `SetPoint`/`SetSize` only | In combat |
