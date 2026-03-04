# Frame & UI Creation APIs

APIs for creating and managing WoW UI frames, textures, and font strings.

---

## CreateFrame

```lua
frame = CreateFrame(frameType [, name [, parent [, template [, id]]]])
```

**Used in:** Core.lua, EventBus.lua, Loot.lua, Vendor.lua, Combat.lua, CastBar.lua, Frames.lua, Widgets.lua, and most modules.

**Frame types used in this addon:**
- `"Frame"` — base invisible frame, used for event listening, hit detection, containers
- `"Button"` — clickable frame with press/release states
- `"Texture"` — image/color fill element (usually via `frame:CreateTexture()` not CreateFrame directly)
- `"FontString"` — text element (usually via `frame:CreateFontString()`)
- `"EditBox"` — text input field (config panels)
- `"Slider"` — slider control (config panels)
- `"CheckButton"` — checkbox (config panels)
- `"ScrollFrame"` — scrollable container
- `"StatusBar"` — progress/cast bar

**Templates used:**
- `"SecureHandlerStateTemplate"` — required for `RegisterStateDriver`; allows restricted Lua in combat. Only frames inheriting this template have `SetAttribute`.
- `"BackdropTemplate"` — required as of Shadowlands to use `SetBackdrop`/`SetBackdropColor`. Must be explicitly passed as template string.

**Caveats:**
- Named frames (`name` arg) are stored in `_G[name]` globally — use unique names to avoid conflicts.
- `parent` defaults to `UIParent` if omitted. Always pass an explicit parent.
- Frames created with no template have no `SetAttribute` method — do not attempt to call it.

---

## Frame Positioning

### SetPoint
```lua
frame:SetPoint(point [, relativeTo [, relativePoint [, xOffset [, yOffset]]]])
```
- `point` and `relativePoint` are anchor strings: `"CENTER"`, `"TOPLEFT"`, `"BOTTOMRIGHT"`, etc.
- **Protected frames** (Blizzard-owned, e.g. action bars) expose `SetPointBase` — use that to bypass the edit-mode override layer.
- **Combat lockdown:** Calling `SetPoint` on a protected frame during combat raises a Lua error. Guard with `InCombatLockdown()`.

### ClearAllPoints
```lua
frame:ClearAllPoints()
```
- On edit-mode system frames, use `ClearAllPointsBase` if available.
- Also protected during combat on Blizzard-owned frames.

### GetPoint / GetCenter / GetLeft / GetBottom
```lua
point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint([n])
x, y = frame:GetCenter()
left = frame:GetLeft()
bottom = frame:GetBottom()
```
- `GetCenter()`, `GetLeft()`, `GetBottom()` return **screen coordinates** (not parent-relative).
- To compute CENTER-relative offset: `x = frame:GetCenter() - UIParent:GetCenter()` (read X and Y separately, both axes call `GetCenter()`).
- These are **safe reads** — numbers are not tainted.

**Addon convention:** All repositionable frames store position as `{ point = "CENTER", x = xOffset, y = yOffset }` relative to `UIParent` center. Applied via `frame:SetPoint("CENTER", UIParent, "CENTER", pos.x, pos.y)`.

---

## Frame Visual Properties

### SetSize / SetWidth / SetHeight
```lua
frame:SetSize(width, height)
frame:SetWidth(width)
frame:SetHeight(height)
```
- Protected on Blizzard-owned frames during combat.
- Safe on addon-created frames anytime.

### SetAlpha
```lua
frame:SetAlpha(alpha)  -- 0.0 to 1.0
```
- **Safe on Blizzard frames** — visual-only, does not cause taint.

### SetFrameStrata
```lua
frame:SetFrameStrata(strata)
```
Strata values (low to high): `"BACKGROUND"`, `"LOW"`, `"MEDIUM"`, `"HIGH"`, `"DIALOG"`, `"FULLSCREEN"`, `"FULLSCREEN_DIALOG"`, `"TOOLTIP"`.

### SetFrameLevel
```lua
frame:SetFrameLevel(level)  -- integer, relative within strata
```

### SetBackdrop / SetBackdropColor
```lua
frame:SetBackdrop({
    bgFile = "path/to/texture",
    edgeFile = "path/to/edge",
    tile = true, tileEdge = true,
    tileSize = 8, edgeSize = 8,
    insets = { left=2, right=2, top=2, bottom=2 }
})
frame:SetBackdropColor(r, g, b [, a])
frame:SetBackdropBorderColor(r, g, b [, a])
```
- **Requires `"BackdropTemplate"`** passed to `CreateFrame`. Added as mandatory in Shadowlands.
- `bgFile = ""` or `nil` hides the background; `edgeFile = ""` or `nil` hides the border.

### SetClampedToScreen
```lua
frame:SetClampedToScreen(bool)
```
- Prevents draggable frames from being dragged off-screen. Use on all draggable addon frames.

---

## Frame Scripting

### SetScript / HookScript
```lua
frame:SetScript("OnEvent", function(self, event, ...) end)
frame:SetScript("OnUpdate", function(self, elapsed) end)
frame:SetScript("OnEnter", function(self) end)
frame:SetScript("OnLeave", function(self) end)
frame:SetScript("OnDragStart", function(self) end)
frame:SetScript("OnDragStop", function(self) end)
frame:SetScript("OnMouseDown", function(self, button) end)
frame:SetScript("OnMouseUp", function(self, button) end)
frame:SetScript("OnValueChanged", function(self, value) end)  -- Slider
frame:SetScript("OnTextChanged", function(self, userInput) end)  -- EditBox
```

**HookScript warning:** `frame:HookScript(...)` on a **Blizzard-owned frame** taints the frame context — same risk as `hooksecurefunc(frame, "Method", cb)`. Avoid both forms on Blizzard frames.

### EnableMouse / SetMovable / RegisterForDrag
```lua
frame:EnableMouse(bool)
frame:SetMovable(bool)
frame:RegisterForDrag("LeftButton")  -- or "RightButton", etc.
```
- **Safe on Blizzard frames** — these do not cause taint.
- Call `SetMovable(true)` and `RegisterForDrag("LeftButton")` before allowing `StartMoving()`.

### StartMoving / StopMovingOrSizing
```lua
frame:StartMoving()      -- call from OnDragStart
frame:StopMovingOrSizing()  -- call from OnDragStop
```

---

## CreateTexture / CreateFontString

```lua
tex = frame:CreateTexture([name [, layer [, template [, subLayer]]]])
tex:SetTexture("Interface/path/to/texture")
tex:SetColorTexture(r, g, b [, a])
tex:SetAllPoints(frame)
tex:SetSize(w, h)
tex:SetPoint(...)

fs = frame:CreateFontString([name [, layer [, template]]])
fs:SetFont("Interface/path/to/font.ttf", size [, flags])
fs:SetText("string")
fs:SetTextColor(r, g, b [, a])
fs:SetJustifyH("LEFT" | "CENTER" | "RIGHT")
fs:GetStringWidth()
```

**Texture layers** (bottom to top): `"BACKGROUND"`, `"BORDER"`, `"ARTWORK"`, `"OVERLAY"`, `"HIGHLIGHT"`.

**Font flags:** `""` (none), `"OUTLINE"`, `"THICKOUTLINE"`, `"MONOCHROME"`.

**WoW font path constraints:**
- Fonts must be within the WoW directory — absolute system paths (e.g. `C:\Windows\Fonts`) are silently ignored.
- Bundled addon fonts: `fonts/NotoSans-Regular.ttf`, `fonts/NotoSansSymbols-Regular.ttf`, `fonts/NotoSansSymbols2-Regular.ttf`.
- NotoSansSymbols2-Regular is required for Unicode suit symbols (♥♦♣♠).

---

## Show / Hide / IsShown / IsVisible

```lua
frame:Show()
frame:Hide()
bool = frame:IsShown()    -- whether frame itself has show flag
bool = frame:IsVisible()  -- whether frame is actually rendered (parents also shown)
```

**Combat-safe show/hide for Blizzard frames:** Use `RegisterStateDriver` / `UnregisterStateDriver` instead of calling `Show()`/`Hide()` directly on protected frames during combat.

---

## Frame Pooling Pattern

Loot.lua and Frames.lua recycle frames via acquire/recycle helpers rather than creating/destroying:

```lua
-- Acquire: find a hidden frame in the pool, or create a new one
local function AcquireToast()
    for _, f in ipairs(pool) do
        if not f:IsShown() then return f end
    end
    local f = CreateFrame(...)
    table.insert(pool, f)
    return f
end

-- Recycle: hide and reset the frame
local function RecycleToast(f)
    f:Hide()
    -- reset any state fields
end
```
