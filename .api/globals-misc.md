# Miscellaneous Globals

Miscellaneous WoW Lua globals and utilities that don't fit a single category.

---

## Money

### GetMoney
```lua
local copper = GetMoney()
```
Returns the player's current gold in copper (e.g. 10000 = 1 gold). Used by Vendor.lua and widgets/Bags.lua.

**Conversion:**
```lua
local gold   = math.floor(copper / 10000)
local silver = math.floor((copper % 10000) / 100)
local cop    = copper % 100
```

---

## CVar System

### SetCVar / GetCVar
```lua
SetCVar("cvarName", value)
local value = GetCVar("cvarName")
```

**Used in:** ChatSkin.lua to manage chat timestamp display.

**Common CVars used:**
- `"chatStyle"` — `"classic"` or `"im"` (chat bubble style)
- `"chatTimestamps"` — timestamp format string, e.g. `"%H:%M "` or `""` to disable

**Caveat:** CVar changes are persistent across sessions. Only change CVars the user has explicitly opted into.

---

## Key State

```lua
local held = IsKeyDown(keyName)          -- any key by name
local shift = IsShiftKeyDown()           -- either Shift key
local ctrl  = IsControlKeyDown()         -- either Ctrl key
local alt   = IsAltKeyDown()             -- either Alt key
```

Used in ObjectiveTracker.lua (modifier key checks for quest actions), widgets/Bags.lua, widgets/Group.lua.

---

## Slash Commands

```lua
SLASH_MYCOMMAND1 = "/mycommand"
SlashCmdList["MYCOMMAND"] = function(msg)
    -- handle /mycommand msg
end
```

**This addon's commands:** `/luit` and `/luithings` both open the config window, registered in Core.lua.

---

## Global Table Access

```lua
_G["FrameName"] = frame   -- register a named frame globally
local frame = _G["FrameName"]
```

Used by Core.lua for dynamic global registration of named frames.

---

## Addon Compartment

The Addon Compartment (the puzzle-piece icon in the minimap area) is registered in Core.lua:

```lua
AddonCompartmentFrame:RegisterAddon({
    text = "LunaUITweaks",
    icon = "Interface/...",
    registerForAnyClick = true,
    func = function(btn, ...) addonTable.Config.Toggle() end,
})
```

---

## pcall (Error Protection)

```lua
local ok, err = pcall(function()
    -- potentially erroring code
end)
if not ok then
    Core.Log("Module", err, 3)  -- ERROR level
end
```

**Used in:** Core.lua's `SafeAfter()` wrapper around all `C_Timer.After` callbacks, Loot.lua's unregister cleanup.

---

## table.wipe

```lua
table.wipe(t)   -- or wipe(t) — empties the table, retaining the same table reference
```

More efficient than `t = {}` when the table reference is shared. Used in ChatSkin.lua and other modules.

**Note:** `wipe` is a Blizzard Lua extension — it is not standard Lua 5.1 but is available in WoW's environment.

---

## String Utilities

```lua
-- Standard Lua (all available in WoW)
string.format(fmt, ...)
string.match(s, pattern)
string.find(s, pattern [, init [, plain]])
string.sub(s, i [, j])
string.lower(s) / string.upper(s)
string.len(s)   -- or #s
string.rep(s, n)
string.byte(s [, i [, j]])
string.char(...)

-- WoW Lua decimal escape for multi-byte UTF-8:
-- Lua 5.1 does NOT support \xNN hex escapes
-- Use decimal escapes: \226\153\165 = ♥  (U+2665)
```

**Font/Unicode note:** NotoSansSymbols2-Regular is required for ♥♦♣♠. See [frame-ui.md](frame-ui.md) for font paths.

---

## Loot APIs

```lua
local numItems = GetNumLootItems()
LootSlot(slotIndex)
local texture, item, quantity, currencyID, quality, locked, isQuestItem, questID, isActive =
    GetLootSlotInfo(slotIndex)
local link = GetLootSlotLink(slotIndex)
local lootType = GetLootSlotType(slotIndex)   -- LOOT_SLOT_ITEM or LOOT_SLOT_CURRENCY
```

Used by Loot.lua to read loot window contents. Only valid while a loot window is open.

---

## Relevant Events

| Event | Description |
|---|---|
| `LOOT_OPENED` | Loot window opened |
| `LOOT_CLOSED` | Loot window closed |
| `LOOT_READY` | Loot is available to be looted |
| `LOOT_ITEM_PUSHED` | Item was pushed into bags from loot |
| `PLAYER_MONEY` | Player's gold changed |
| `CVAR_UPDATE` | A CVar value was changed; args: `(cvarName, value)` |
| `VARIABLES_LOADED` | CVars are loaded from disk and ready to read |
