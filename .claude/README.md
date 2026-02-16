# Config Module Structure

This directory contains the refactored configuration UI files split from the monolithic `Config.lua`.

## Architecture

```
config/
├── Helpers.lua          - Shared UI helper functions
├── ConfigMain.lua       - Main window setup and tab coordination
└── panels/             - Individual panel setup files (to be created)
    ├── TrackerPanel.lua
    ├── VendorPanel.lua
    ├── CombatPanel.lua
    ├── FramesPanel.lua
    ├── LootPanel.lua
    ├── MiscPanel.lua
    └── TalentPanel.lua
```

## Migration Status

**Phase 1: Foundation** ✓
- [x] Created Helpers.lua with shared utilities
- [x] Created ConfigMain.lua with main window structure

**Phase 2: Panel Migration** (In Progress)
- [ ] Migrate Tracker panel
- [ ] Migrate Vendor panel
- [ ] Migrate Combat panel
- [ ] Migrate Frames panel
- [ ] Migrate Loot panel
- [ ] Migrate Misc panel
- [ ] Migrate Talent panel

**Phase 3: Cleanup**
- [ ] Remove original Config.lua
- [ ] Update TOC file load order
- [ ] Test all functionality

## How to Add a Panel

Each panel file should:

1. Create the setup table if it doesn't exist:
```lua
addonTable.ConfigSetup = addonTable.ConfigSetup or {}
```

2. Define a setup function:
```lua
function addonTable.ConfigSetup.PanelName(panel, tab, configWindow)
    local Helpers = addonTable.ConfigHelpers
    
    -- Panel setup code here
    -- Use Helpers.UpdateModuleVisuals(panel, tab, enabled)
    -- Use Helpers.CreateSectionHeader(panel, "Title", yOffset)
    -- Use Helpers.CreateColorPicker(...)
    -- Use Helpers.fonts for font dropdowns
end
```

3. The setup function will be called by ConfigMain.lua after window creation

## Load Order

The TOC file must load in this order:
1. Core.lua (defines addonTable)
2. config/Helpers.lua (defines shared helpers)
3. config/panels/*.lua (defines setup functions)
4. config/ConfigMain.lua (creates window and calls setup functions)
5. Other addon files...

## Benefits

- **Maintainability**: Each panel is ~100-500 lines instead of one 3195-line file
- **Modularity**: Panels can be developed/tested independently  
- **No Name Conflicts**: All files in /config subfolder
- **Performance**: No runtime impact, just better code organization
- **Debugging**: Easier to find and fix issues in specific panels
