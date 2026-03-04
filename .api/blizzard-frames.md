# Blizzard Global Frames

Global Blizzard-owned frame references accessed by this addon, with safety notes.

---

## UIParent

The root parent frame for all UI elements. All addon frames should be parented here (or to a child of it) unless they need a different strata.

```lua
frame:SetPoint("CENTER", UIParent, "CENTER", xOffset, yOffset)
local screenWidth = UIParent:GetWidth()
local screenHeight = UIParent:GetHeight()
local cx, cy = UIParent:GetCenter()
```

**Safe operations:** `GetWidth()`, `GetHeight()`, `GetCenter()` — all return numbers, not tainted.

---

## GameTooltip

See [tooltip.md](tooltip.md).

---

## ChatFrame1 / FCF_GetCurrentChatFrame

```lua
local frame = ChatFrame1
local editBox = ChatFrame1EditBox
```

**Caveat:** `hooksecurefunc(ChatFrame1, "SetPoint", cb)` is **unsafe** (object-form hook taints the frame). ChatSkin.lua instead hooks `ShowUIPanel` and `HideUIPanel` globally to detect when the chat frame is repositioned.

```lua
-- Safe global hook form:
hooksecurefunc("ShowUIPanel", function(frame)
    if frame == ChatFrame1 then
        C_Timer.After(0.05, LayoutContainer)
    end
end)
```

---

## AlertFrame

```lua
AlertFrame:RegisterEvent("LOOT_ITEM_PUSHED")
AlertFrame:UnregisterEvent("LOOT_ITEM_PUSHED")
LootWonAlertSystem:UnregisterEvent("LOOT_WON")
LootUpgradeAlertSystem:UnregisterEvent("LOOT_UPGRADE")
```

Used by Loot.lua to suppress Blizzard's default loot toast alerts when the custom toast system is active.

**Caveat:** `LootWonAlertSystem` and `LootUpgradeAlertSystem` are child objects of `AlertFrame`. Calling `UnregisterEvent` on them suppresses those specific alert types without touching the full AlertFrame.

---

## MerchantFrame

```lua
-- Valid only during MERCHANT_SHOW / MERCHANT_CLOSED window
if MerchantFrame:IsShown() then
    -- merchant is open
end
```

Used by Vendor.lua to confirm merchant state before calling repair/sell APIs.

---

## PlayerSpellsFrame

```lua
-- Detect if the talent UI is open
if PlayerSpellsFrame and PlayerSpellsFrame:IsShown() then end
```

Used by TalentManager.lua. **Do not** `SetPoint`, `SetSize`, or write fields onto this frame.

---

## QuestMapFrame

```lua
QuestMapFrame:IsShown()
```

ObjectiveTracker.lua checks this to avoid interfering with the quest map display.

---

## AchievementFrame

```lua
AchievementFrame_LoadUI()           -- ensure UI is loaded before showing
AchievementFrame_ToggleAchievementFrame()
AchievementFrame_SelectAchievement(achievementID)
```

Used by ObjectiveTracker.lua to open and navigate to specific achievements.

---

## MicroMenuContainer

Used by ActionBars.lua to query the position of the micro menu bar for action bar layout.

**Caveat:** `MicroMenuContainer` is a Blizzard-owned frame. Do not `SetPoint` or write fields onto it.

---

## Minimap

```lua
Minimap:GetWidth()   -- safe read
Minimap:GetHeight()  -- safe read
-- DO NOT call SetPoint, ClearAllPoints on Minimap -- protected
```

The main minimap frame. MinimapCustom.lua parents custom border and clock frames to it but does not reposition the `Minimap` frame itself.

---

## DamageMeter (FORBIDDEN)

```lua
-- DO NOT touch DamageMeter or DamageMeterSessionWindow* frames
-- Any call to SetPoint, ClearAllPoints, SetSize, SetMovable,
-- RegisterForDrag, SetScript, or writing fields onto these frames
-- causes taint that corrupts Blizzard UI string/number comparisons.
```

The addon's DamageMeter module is a **no-op stub**. Users should use Blizzard's Edit Mode to reposition the damage meter. See [secure-protected.md](secure-protected.md) for full taint rules.

---

## QueueStatusButton (FORBIDDEN for hooks)

```lua
-- DO NOT:
-- hooksecurefunc(QueueStatusButton, "SetPoint", cb)  -- taints Button prototype
-- QueueStatusButton:HookScript(...)                  -- taints Button prototype
```

Any hook or HookScript on `QueueStatusButton` taints the **shared Button prototype**, breaking map pin interactions across the entire UI. MinimapCustom.lua uses a `C_Timer.NewTicker(2.0, ...)` polling approach instead.

---

## StaticPopupDialogs

```lua
StaticPopupDialogs["MY_DIALOG"] = {
    text = "Are you sure?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function() ... end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
StaticPopup_Show("MY_DIALOG")
```

Used by Warehousing.lua for confirmation dialogs. The key must be uppercase and globally unique across all addons to avoid conflicts.
