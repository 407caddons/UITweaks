# v1.5.0

## New Features

### Chat Skin
- New module providing a clean, customizable chat frame skin
- Configurable background color, border color, and border size
- Custom tab styling with separate active/inactive tab colors
- Utility buttons replacing the default social/channel buttons:
  - **C** - Copy chat content to a separate frame for easy copying
  - **S** - Open the social/friends window
  - **H** - Open the channel frame
  - **L** - Language selection menu
- Movable and resizable with lock/unlock support
- Full config panel under the new "Chat" tab

### Bags Widget - Gold Tracking
- Per-character gold tracking saved across sessions
- Other characters displayed in tooltip sorted by gold (descending)
- Warband bank gold displayed in tooltip
- Total gold line summing all characters and warband bank
- Shift-Right-Click to clear all saved character gold data

## Bug Fixes

### Talent Reminder
- Fixed taint errors (`attempt to perform string conversion on a secret string value`) caused by boss detection reading secure unit values - removed the entire boss detection system since the module is zone-based
- Fixed alerts not appearing in raids on spec/talent change - removed `InCombatLockdown()` guard which returns true when anyone in the raid is in combat
- Fixed alerts not appearing due to difficulty filter being disabled - difficulty filters are now auto-enabled when saving a reminder
- Fixed UI checkbox not updating when a difficulty filter is auto-enabled
- Fixed "Instance: Unknown" and "Difficulty: Unknown" display - `SaveReminder` now stores `instanceName` and `difficulty` fields
- Fixed alert frame not dismissing when leaving an instance
- Increased spec change re-check delay to 1.0s for more reliable talent data
- Instance info now refreshes on spec change events

### Objective Tracker
- Fixed `SetSuperTrackedQuestID(0)` error when clearing super tracking - now uses `ClearAllSuperTracked()`
- Removed debug print statements for quest 86696

### Kick Module
- Fixed continuous `OnUpdate` handler running even when disabled - now uses start/stop pattern that only runs when party frames exist

### Currency Widget
- Fixed frame leak where new currency rows were created every panel refresh - now uses a frame pool with `AcquireRow()`/`ReleaseAllRows()`

### Minimap
- Fixed drawer button borders not updating after resize
