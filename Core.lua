local addonName, addonTable = ...
_G[addonName] = addonTable

addonTable.Core = {}

-- Centralized Safe Timer Wrapper
--- Safely executes a function after a delay using C_Timer
-- @param delay number Delay in seconds
-- @param func function Function to execute
function addonTable.Core.SafeAfter(delay, func)
    if not func then
        print("UIThings: SafeAfter called with nil function")
        return
    end
    if C_Timer and C_Timer.After then
        pcall(C_Timer.After, delay, func)
    end
end

--- Recursively applies default values to a settings table
-- Only sets values that are currently nil (preserves existing user settings)
-- @param db table The settings table to populate
-- @param defaults table The default values to apply
local function ApplyDefaults(db, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" and not value.r then -- Not a color table
            db[key] = db[key] or {}
            ApplyDefaults(db[key], value)
        elseif db[key] == nil then
            db[key] = value
        end
    end
end

-- Logging System
addonTable.Core.LogLevel = {
    DEBUG = 0,
    INFO = 1,
    WARN = 2,
    ERROR = 3
}

addonTable.Core.currentLogLevel = addonTable.Core.LogLevel.INFO

--- Centralized logging function
-- @param module string Module name (e.g., "Tracker", "Vendor")
-- @param msg string Message to log
-- @param level number Optional. Log level (default: INFO)
function addonTable.Core.Log(module, msg, level)
    level = level or addonTable.Core.LogLevel.INFO
    if level < addonTable.Core.currentLogLevel then return end
    
    local colors = {
        [0] = "888888", -- DEBUG (gray)
        [1] = "00FF00", -- INFO (green)
        [2] = "FFFF00", -- WARN (yellow)
        [3] = "FF0000"  -- ERROR (red)
    }
    
    local prefix = string.format("|cFF%s[Luna %s]|r", colors[level] or "FFFFFF", module or "Core")
    print(prefix .. " " .. tostring(msg))
end

--- Event handler for ADDON_LOADED
-- Initializes saved variables with defaults and modules
-- @param self frame The event frame
-- @param event string The event name
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        UIThingsDB = UIThingsDB or {}
        
        -- Default Settings Table
        local DEFAULTS = {
            tracker = {
                locked = true,
                enabled = false,
                width = 300,
                height = 500,
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 12,
                headerFont = "Fonts\\FRIZQT__.TTF",
                headerFontSize = 14,
                detailFont = "Fonts\\FRIZQT__.TTF",
                detailFontSize = 12,
                questPadding = 2,
                sectionOrder = 1, -- 1=WQ/Quests/Ach, 2=Quests/WQ/Ach, etc
                onlyActiveWorldQuests = false,
                activeQuestColor = {r=0, g=1, b=0, a=1},
                x = -20,
                y = -250,
                point = "TOPRIGHT",
                showBorder = false,
                borderColor = {r=0, g=0, b=0, a=1},
                showBackground = false,
                hideInCombat = false,
                hideInMPlus = false,
                autoTrackQuests = false,
                rightClickSuperTrack = true,
                shiftClickUntrack = true,
                backgroundColor = {r=0, g=0, b=0, a=0.5},
                strata = "LOW",
                showWorldQuestTimer = true,
                collapsed = {}
            },
            minimap = {
                angle = 45
            },
            vendor = {
                enabled = false,
                autoRepair = true,
                useGuildRepair = false,
                sellGreys = true,
                repairThreshold = 20,
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 24,
                warningLocked = true,
                warningPos = {point="TOP", x=0, y=-150}
            },
            loot = {
                enabled = false,
                growUp = true,
                fasterLoot = false,
                fasterLootDelay = 0.3,
                duration = 3,
                minQuality = 1,
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 14,
                iconSize = 32,
                anchor = {point="CENTER", x=0, y=200}
            },
            combat = {
                enabled = false,
                locked = true,
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 18,
                colorInCombat = {r=1, g=1, b=1},
                colorOutCombat = {r=0.5, g=0.5, b=0.5},
                pos = {point="CENTER", x=0, y=0}
            },
            frames = {
                enabled = false,
                list = {}
            },
            misc = {
                enabled = false,
                ahFilter = false,
                personalOrders = false,
                ttsMessage = "Personal order arrived",
                alertDuration = 5,
                alertColor = {r=1, g=0, b=0, a=1}
            }
        }
        
        -- Apply all defaults
        ApplyDefaults(UIThingsDB, DEFAULTS)
        
        addonTable.Core.Log("Core", "UI Tweaks Loaded!")
        self:UnregisterEvent("ADDON_LOADED")
        
        -- Initialize Modules
        if addonTable.Config and addonTable.Config.Initialize then
            addonTable.Config.Initialize()
        end
        
        if addonTable.Minimap and addonTable.Minimap.Initialize then
            addonTable.Minimap.Initialize()
        end

        if addonTable.Frames and addonTable.Frames.Initialize then
            addonTable.Frames.Initialize()
        end
        
        -- Slash Commands
        SLASH_UITHINGS1 = "/luit"
        SLASH_UITHINGS2 = "/luithings"
        
        -- Global function for Addon Compartment
        function LunaUITweaks_OpenConfig()
            if addonTable.Config and addonTable.Config.ToggleWindow then
                addonTable.Config.ToggleWindow()
            end
        end
        
        SlashCmdList["UITHINGS"] = function(msg)
            LunaUITweaks_OpenConfig()
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", OnEvent)
