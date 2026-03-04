# Class Color APIs

APIs for retrieving and applying WoW class colours.

---

## C_ClassColor.GetClassColor

```lua
local colorMixin = C_ClassColor.GetClassColor(classFilename)
-- colorMixin.r, colorMixin.g, colorMixin.b  (0.0–1.0 floats)
-- colorMixin:GenerateHexColor()             → "RRGGBB" hex string
-- colorMixin:WrapTextInColorCode(text)      → "|cffRRGGBB" .. text .. "|r"
```

`classFilename` is the **uppercase English** class name:
`"WARRIOR"`, `"PALADIN"`, `"HUNTER"`, `"ROGUE"`, `"PRIEST"`, `"DEATHKNIGHT"`, `"SHAMAN"`, `"MAGE"`, `"WARLOCK"`, `"MONK"`, `"DRUID"`, `"DEMONHUNTER"`, `"EVOKER"`.

**Used in:** Loot.lua, CastBar.lua, Kick.lua, widgets/Guild.lua, widgets/Group.lua, widgets/AddonComm.lua, widgets/Friends.lua.

**Caveat:** Returns `nil` for invalid class names. Always use `classFilename` (from `UnitClass()` second return value), not the localized `className`.

---

## RAID_CLASS_COLORS (Legacy Global)

```lua
local color = RAID_CLASS_COLORS[classFilename]
-- color.r, color.g, color.b  (same values as C_ClassColor)
```

The legacy global table. `C_ClassColor.GetClassColor` is preferred in modern code as it returns a proper ColorMixin object with helper methods.

---

## Applying Class Colors

**To frame text:**
```lua
local color = C_ClassColor.GetClassColor(classFilename)
if color then
    fontString:SetTextColor(color.r, color.g, color.b)
end
```

**To a chat string:**
```lua
local color = C_ClassColor.GetClassColor(classFilename)
local colored = color and color:WrapTextInColorCode(playerName) or playerName
```

**Hex for SetVertexColor:**
```lua
local color = C_ClassColor.GetClassColor(classFilename)
if color then
    texture:SetVertexColor(color.r, color.g, color.b)
end
```
