# LunaUITweaks Bags — initial version

Optional companion addon for Retail and the Forever test client. Requires LunaUITweaks. Disable other bag replacement addons before testing.

## Features

- Combined player inventory, including the reagent bag.
- A search box beside the bags title performs a case-insensitive partial name search across inventory and both bank views. Non-matching items dim without changing their positions. Escape in the search box clears the search.
- New Items at the top of inventory for items gained since login/reload, including increases to existing stacks. Closing bags or hovering items does not clear this session category. Bank views keep their normal categories.
- Gear, Consumables, Quest Items, Junk, Crafting Reagents, and Other categories.
- Consumables include items with a Use spell. Quest items, gear and reagents take priority over this broad rule.
- **Deposit Warbound** uses Blizzard's native bulk deposit with Include Reagents enabled for the request. The previous reagent preference is restored afterward. Refundable items require confirmation; combat, a held cursor item, or an unavailable bank prevents starting a deposit.
- One bank window with Warband Bank and Bank tabs. Each combines all purchased tabs of that bank and uses the same categories. The tabs (and the close button) click Blizzard's own bank buttons through secure templates, and the window opens on whichever bank Blizzard opened: setting Blizzard's bank tab from addon code taints right-click withdraw/deposit (`ADDON_ACTION_FORBIDDEN` on `UseContainerItem`).
- Items moved from the bank into the bags are transfers and are not marked new.
- Equipped bag slots (bags 1-4 and the reagent bag) at the bottom-right of the inventory: hover for the bag and free slots, drop a bag on a slot to equip or swap it, drag a bag away to remove it (not in combat).
- One free-space tile with the total number of empty slots. Dropped items go into a compatible empty slot, preferring specialty bags.
- Blizzard item button interactions, tooltips, quantity labels, quality borders, quest markers and cooldowns.
- Drag the inventory window by its title. Position and enabled state are saved and included in Luna's settings export.

Normal bag keybinds and backpack buttons open Luna's inventory. Blizzard's bag functions are never replaced or called by addon code: Luna post-hooks them (`hooksecurefunc`) and keeps Blizzard's bag frames working inside a hidden parent. Replacing `OpenAllBags` tainted `BankFrame:OnShow` (which calls it) and with it the active bank type that every right-click item use reads. `/luitbags` also toggles it; `/luitbags reset` resets its position. The Bags page in Luna's configuration enables/disables this companion's replacement UI.

Temporarily disable categorized bags in the Bags configuration page to use Blizzard's bag equipment and bank management controls.

## Installation and release layout

The source lives at `LunaUITweaks/LunaUITweaks_Bags`. WoW must also see it as a sibling addon: `Interface/AddOns/LunaUITweaks_Bags`. `.codex/link-addons.sh` creates the development link; `.pkgmeta` moves the folder to the top level in release archives. Restart WoW after adding the folder/link so the client discovers the addon.

## Initial-version limitations

No cached bank viewing away from a banker, category editor, search, bag equipment controls, automatic physical sorting, or custom gold-management controls yet. The native bank remains active behind an opaque custom panel so Blizzard retains its interaction and close lifecycle. Item layout changes wait until combat and stack splitting finish. Inventory open/close requests during combat apply after combat ends. Existing visible slots retain their locations and use Blizzard's secure item actions during combat; the game still decides which items can be used.

This implementation has syntax and mocked regression checks; real-client interaction and taint checks still need in-game testing on Retail and Forever.

Gear icons show their effective item level in small text at the bottom-right, including upgraded variants. Labels refresh when item information arrives and are cleared when pooled buttons display other items.

Inventory closing uses a secure close button. While open, Escape and the configured bag keys temporarily click that button, so they can close the protected window during combat. These overrides are cleared on hide; other keys are unaffected. Programmatic show/hide requests still defer during combat.

Item slots retain Blizzard's native container OnClick as the hardware click handler, including item use, vendor sales, bank transfers and modified clicks. Addon PreClick/PostClick callbacks never invoke the protected item-use path. The combined free-space tile only picks up/drops a cursor item into a freshly checked empty slot.

The login inventory baseline uses a fixed startup deadline. Self-loot messages preserve confirmed acquisitions during that window, including stack quantities; later bag updates do not extend the deadline.

Item buttons are retained by physical bag/slot, so category changes only reposition them. The aggregate free-space tile has a separate button and never shares its click or drag handlers with a real item. Native item input scripts are never replaced or reinstalled.

Pets, Mounts and Housing Decor have separate categories in inventory and both banks. Pet items and caged battle pets are recognised separately from generic usable items; mount equipment and non-decor housing items keep their normal categories.
