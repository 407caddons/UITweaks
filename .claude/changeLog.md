# Changelog

## v1.11.0 (in progress)

- New M+ Timer module: full mythic+ dungeon timer with boss tracking, death counter, forces progress bar, affix display, and auto keystone slotting
- New Quest Auto module: automatic quest accept, turn-in, and gossip interaction with shift-to-pause override
- New Quest Reminders module: zone-based quest availability alerts with TTS, popup, sound, and chat message notifications
- New Talent Manager module: dedicated talent build management panel with collapsible sections and encounter journal integration
- New Currency widget showing tracked currencies updated for TWW Season 3 (Valorstones, Kej, Ethereal Crests)
- Keystone widget: improved dungeon teleport matching for mega dungeon wings and "Operation:" prefixed names
- Keystone widget: combat-safe teleport map building and secret value protection on tooltip data
- Group widget: fixed ready check state declaration order to prevent nil reference errors
- Group widget: uses cached atlas markup constants instead of re-creating them per tooltip line
- Objective Tracker: sort comparators moved to module scope to avoid closure allocation in hot paths
- Objective Tracker: stale sound-tracking and quest line cache pruned on zone change
- Core: log color table hoisted out of the Log function to avoid re-creation per call
- Kick: removed redundant local variable shadowing for unit GUID
- ActionBars: fixed local variable scoping in micro menu layout patch

## v1.10.0

- Added cross-character Reagent Tracking module with tooltip display, bag/bank/warband scanning, and config panel for managing characters
- Objective Tracker: quest line progress indicator (e.g. "3/7") shown next to quest names
- Objective Tracker: new campaign quest grouping mode in addition to zone grouping
- Objective Tracker: keybind to toggle tracker visibility
- ActionBars: reworked bar positioning to absolute UIParent-anchored coordinates with automatic migration from old offset format
- ActionBars: positions recaptured cleanly after exiting edit mode
- ActionBars: skin borders hidden on empty action button slots
- Keystone widget: click-to-teleport using dungeon teleport spells (Hero's Path, etc.)
- Keystone widget: tooltip shows your best run for the current dungeon
- FPS widget: tooltip now includes network jitter and bandwidth stats
- Friends widget: tooltip shows zone/area info for online friends
- Group widget: ready check tracking with live status display in tooltip
- Durability widget: tooltip shows repair cost estimate
- CastBar: added bar texture selection with visual preview dropdown
- CastBar: improved Blizzard cast bar hiding using combat-safe state driver
- Config: shared status bar texture picker with live preview
