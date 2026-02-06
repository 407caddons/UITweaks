--[[
    Config.lua - Entry point for configuration UI

    This file now loads the modular configuration system from the /config folder.

    The original monolithic Config.lua has been backed up to Config.lua.backup
    and refactored into modular files:

    - config/Helpers.lua - Shared UI utilities
    - config/ConfigMain.lua - Main window and tab setup
    - config/panels/*.lua - Individual panel configurations

    See REFACTORING_GUIDE.md for details on the new structure.
]]

local addonName, addonTable = ...

-- The actual configuration code is now in config/ConfigMain.lua
-- This file exists only to maintain the expected Config.lua entry point

-- Note: The modular files are loaded via the TOC file before this file,
-- so addonTable.Config.Initialize() and addonTable.Config.ToggleWindow()
-- are already defined by config/ConfigMain.lua

-- Nothing else needed here - all functionality is in the config/ folder
