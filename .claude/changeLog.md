# Changelog

## v1.10.0

- Added cross-character reagent tracking module with tooltip display, bag/bank/warband scanning, and per-character management
- Added objective tracker keybind to toggle visibility without changing the enabled setting
- Added quest line progress display showing step position (e.g. 3/7) next to quest names
- Added campaign-based quest grouping with collapsible campaign sub-headers
- Added scenario step progress, step titles, descriptions, weighted progress, and bonus objective tracking to the objective tracker
- Overhauled action bar positioning from relative offsets to absolute UIParent-anchored coordinates with automatic migration from the old format
- Action bar skin now hides button borders on empty slots
- Action bar position sliders expanded from +/-500 to +/-2000 range
- Cast bar now supports configurable bar textures via a new texture dropdown with visual preview
- Cast bar Blizzard hiding reworked to use RegisterStateDriver for combat-safe visibility
- Cast bar position now saves with sub-pixel precision
- Improved weapon buff detection to distinguish actual weapons from shields/holdables
- Kick tracker fixed forward declaration issues for party watcher functions
- Custom layout frame renames now propagate to any widgets anchored by name
- Loot panel converted to scrollable layout
- Keystone widget added with dungeon info and key level display
- Widget framework improvements to FPS, Durability, Friends, Group, and Mythic Rating widgets
