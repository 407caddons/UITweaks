# Tooltip APIs

APIs for showing item, currency, and custom tooltips.

---

## GameTooltip

`GameTooltip` is the shared global tooltip frame. It is a Blizzard-owned frame — do **not** write fields onto it.

### SetOwner
```lua
GameTooltip:SetOwner(parentFrame, anchorPoint [, xOffset [, yOffset]])
```
Must be called before adding content. Clears any previous content.

- `anchorPoint` — `"ANCHOR_CURSOR"`, `"ANCHOR_RIGHT"`, `"ANCHOR_LEFT"`, `"ANCHOR_TOP"`, `"ANCHOR_BOTTOM"`, `"ANCHOR_NONE"`, `"ANCHOR_PRESERVE"`
- `"ANCHOR_PRESERVE"` keeps the tooltip's last position (useful for sticky tooltips).
- `"ANCHOR_NONE"` lets you manually `SetPoint` the tooltip after `SetOwner`.

### SetHyperlink
```lua
GameTooltip:SetHyperlink(link)
```
Loads full item tooltip for an item link (e.g. `|cff...item:...|r`). Fires `TOOLTIP_DATA_UPDATE` when loaded.

### SetCurrencyByID
```lua
GameTooltip:SetCurrencyByID(currencyID)
```
Shows the tooltip for a specific currency.

### AddLine / AddDoubleLine
```lua
GameTooltip:AddLine("text" [, r, g, b [, wrapText]])
GameTooltip:AddDoubleLine("leftText", "rightText" [, lr, lg, lb, rr, rg, rb])
```
Adds custom lines to the tooltip. Call `Show()` after adding all lines.

### Show / Hide
```lua
GameTooltip:Show()
GameTooltip:Hide()
```

**Used in:** Loot.lua (show item tooltip on hover), Reagents.lua (show reagent counts on item tooltips).

### Tooltip Hook Pattern (Reagents.lua)
```lua
GameTooltip:HookScript("OnTooltipSetItem", function(self)
    local _, link = self:GetItem()
    if not link then return end
    -- append custom lines
    self:AddLine("My custom info")
    self:Show()
end)
```

**Caveat:** `HookScript` on `GameTooltip` is a Blizzard-owned frame hook. While tooltips are generally lower-risk than action bar frames, be careful not to write fields onto the frame object.

---

## TooltipDataProcessor (Modern Pattern)

As of Dragonflight/TWW, the preferred pattern for augmenting tooltips is `TooltipDataProcessor.AddTooltipPostCall`:

```lua
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    -- tooltip is the tooltip frame, data.id is itemID
    tooltip:AddLine("Custom text")
end)
```

This is cleaner than `HookScript("OnTooltipSetItem")` and is the Blizzard-recommended approach for TWW. The addon currently uses `HookScript` — consider migrating.

---

## Relevant Events

| Event | Description |
|---|---|
| `TOOLTIP_DATA_UPDATE` | Tooltip data has been updated (async loads complete) |
| `UPDATE_MOUSEOVER_UNIT` | Mouse is over a new unit (update unit tooltip) |
