# LunaUITweaks Bags — initial version

Optional companion addon for Retail and the Forever test client. Requires LunaUITweaks. Disable other bag replacement addons before testing.

## Features

- Combined player inventory, including the reagent bag.
- New Items at the top of inventory for items gained since login/reload, including increases to existing stacks. Closing bags or hovering items does not clear this session category. Bank views keep their normal categories.
- Gear, Consumables, Quest Items, Junk, Crafting Reagents, and Other categories.
- Consumables include items with a Use spell. Quest items, gear and reagents take priority over this broad rule.
- **Deposit Warbound** uses Blizzard's native bulk deposit with Include Reagents enabled for the request. The previous reagent preference is restored afterward. Refundable items require confirmation; combat, a held cursor item, or an unavailable bank prevents starting a deposit.
- One bank window with Warband Bank (default) and Bank tabs. Each combines all purchased tabs of that bank and uses the same categories.
- One free-space tile with the total number of empty slots. Dropped items go into a compatible empty slot, preferring specialty bags.
- Blizzard item button interactions, tooltips, quantity labels, quality borders, quest markers and cooldowns.
- Drag the inventory window by its title. Position and enabled state are saved and included in Luna's settings export.

Normal bag keybinds and backpack buttons open Luna's inventory. `/luitbags` also toggles it; `/luitbags reset` resets its position. The Bags page in Luna's configuration enables/disables this companion's replacement UI.

Temporarily disable categorized bags in the Bags configuration page to use Blizzard's bag equipment and bank management controls.

## Installation and release layout

The source lives at `LunaUITweaks/LunaUITweaks_Bags`. WoW must also see it as a sibling addon: `Interface/AddOns/LunaUITweaks_Bags`. `.codex/link-addons.sh` creates the development link; `.pkgmeta` moves the folder to the top level in release archives. Restart WoW after adding the folder/link so the client discovers the addon.

## Initial-version limitations

No cached bank viewing away from a banker, category editor, search, bag equipment controls, automatic physical sorting, or custom gold-management controls yet. The native bank remains active behind an opaque custom panel so Blizzard retains its interaction and close lifecycle. Item layout changes wait until combat and stack splitting finish. Inventory open/close requests during combat apply after combat ends. Existing visible slots retain their locations and use Blizzard's secure item actions during combat; the game still decides which items can be used.

This implementation has syntax and mocked regression checks; real-client interaction and taint checks still need in-game testing on Retail and Forever.
