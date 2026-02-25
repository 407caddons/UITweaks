local addonName, addonTable = ...

-- ============================================================
-- Games.lua — Shared game infrastructure
-- Loaded first in the games section (see TOC).
-- Provides:
--   • Keybind global stubs that individual games wrap via the
--     chain pattern: Games.lua defines → Snek wraps → Tiles wraps
--   • addonTable.Games shared table for future cross-game utilities
-- ============================================================

addonTable.Games = {}

-- Keybind stubs — no-ops until a game wraps them at load time.
-- Each game file captures the current value of these globals as
-- upvalues and redefines them to dispatch to its own handlers
-- when the game frame is open, falling back to the captured value.
function LunaUITweaks_Game_Left()    end
function LunaUITweaks_Game_Right()   end
function LunaUITweaks_Game_RotateCW()  end
function LunaUITweaks_Game_RotateCCW() end
function LunaUITweaks_Game_Pause()   end
