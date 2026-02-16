# Changelog

## v1.9.0

- Added action bar skinning module with custom button borders, bar backgrounds, button spacing/sizing, keybind/macro text toggles, and per-bar position offsets
- Added custom player cast bar replacing Blizzard's default, with configurable size, colors, spell icon, and cast time display
- Added scrolling combat text (SCT) with separate damage and healing anchors, configurable font size, crit scaling, and scroll distance
- Added Hearthstone widget that randomly selects from collected hearthstone toys, shows cooldown and bound location
- Added chat keyword highlighting with custom color and optional sound alerts
- Added Notifications config tab, splitting personal orders and mail alerts out of the General UI panel
- Loot toasts now show item level with color-coded upgrade comparison against equipped gear
- Loot toasts now show gold gains (switched to PLAYER_MONEY event for locale-independent detection)
- Objective tracker now supports configurable click interactions: left-click opens quest log, shift-click links in chat, ctrl-click untracks, middle-click shares with party
- Objective tracker restores super-tracking to your previous quest after a world quest takes over tracking
- Great Vault widget updated for Season 2 API categories (Mythic+, Raid, Delves)
- Kick tracker now automatically disables in raids (party-only)
- Kick tracker icon size is now configurable
- Custom layout frames now save positions on logout to prevent loss from disconnects
- Widget anchor cache is now invalidated only when frames change, improving performance
