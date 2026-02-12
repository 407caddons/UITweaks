local addonName, addonTable = ...
_G[addonName] = addonTable

addonTable.Core = {}

-- Centralized Safe Timer Wrapper
--- Safely executes a function after a delay using C_Timer
-- @param delay number Delay in seconds
-- @param func function Function to execute
function addonTable.Core.SafeAfter(delay, func)
    if not func then
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
                sectionOrderList = {
                    "scenarios",
                    "tempObjectives",
                    "worldQuests",
                    "quests",
                    "achievements"
                },
                onlyActiveWorldQuests = false,
                activeQuestColor = { r = 0, g = 1, b = 0, a = 1 },
                x = -20,
                y = -250,
                point = "TOPRIGHT",
                showBorder = false,
                borderColor = { r = 0, g = 0, b = 0, a = 1 },
                showBackground = false,
                hideInCombat = false,
                hideInMPlus = false,
                autoTrackQuests = false,
                rightClickSuperTrack = true,
                shiftClickUntrack = true,
                backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 },
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
                onlyCheckDurabilityOOC = true,
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 24,
                warningLocked = true,
                warningPos = { point = "TOP", x = 0, y = -150 }
            },
            loot = {
                enabled = false,
                showAll = false,
                growUp = true,
                fasterLoot = false,
                fasterLootDelay = 0.3,
                duration = 3,
                minQuality = 1,
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 14,
                iconSize = 32,
                whoLootedFontSize = 12,
                anchor = { point = "CENTER", x = 0, y = 200 }
            },
            combat = {
                enabled = false,
                locked = true,
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 18,
                colorInCombat = { r = 1, g = 1, b = 1 },
                colorOutCombat = { r = 0.5, g = 0.5, b = 0.5 },
                pos = { point = "CENTER", x = 0, y = 0 },
                combatLog = {
                    dungeonNormal = false,
                    dungeonHeroic = false,
                    dungeonMythic = false,
                    mythicPlus = false,
                    raidLFR = false,
                    raidNormal = false,
                    raidHeroic = false,
                    raidMythic = false,
                },
                reminders = {
                    locked = true,
                    flask = true,
                    food = true,
                    weaponBuff = true,
                    pet = true,
                    classBuff = true,
                    font = "Fonts\\FRIZQT__.TTF",
                    fontSize = 12,
                    iconSize = 24,
                    pos = { point = "TOP", x = 0, y = -100 },
                    onlyInGroup = true,
                    consumableUsage = {
                        flask = {},
                        food = {},
                        weapon = {}
                    }
                },
                consumableUsage = {
                    flask = {},
                    food = {},
                    weapon = {}
                }
            },
            frames = {
                enabled = false,
                list = {}
            },
            misc = {
                enabled = false,
                ahFilter = false,
                personalOrders = false,
                ttsEnabled = true,
                ttsMessage = "Personal order arrived",
                ttsVoice = 0, -- 0 = Standard, 1 = Alternate 1
                alertDuration = 5,
                alertColor = { r = 1, g = 0, b = 0, a = 1 },
                uiScaleEnabled = false,
                uiScale = 0.711,
                autoAcceptFriends = false,
                autoAcceptGuild = false,
                autoAcceptEveryone = false,
                allowRL = true,
                autoInviteEnabled = false,
                autoInviteKeywords = "inv,invite",
                quickDestroy = false,
                minimapEnabled = false,
                minimapShape = "ROUND",
                minimapPos = { point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -7, y = -7 },
                minimapShowZone = true,
                minimapZoneFont = "Fonts\\FRIZQT__.TTF",
                minimapZoneFontSize = 12,
                minimapZoneFontColor = { r = 1, g = 1, b = 1 },
                minimapZoneOffset = { x = 0, y = 4 },
                minimapShowClock = true,
                minimapClockFont = "Fonts\\FRIZQT__.TTF",
                minimapClockFontSize = 11,
                minimapClockFontColor = { r = 1, g = 1, b = 1 },
                minimapClockFormat = "24H",
                minimapClockTimeSource = "local",
                minimapClockOffset = { x = 0, y = -4 },
                minimapBorderColor = { r = 0, g = 0, b = 0, a = 1 },
                minimapBorderSize = 3,
                minimapShowMail = false,
                minimapShowTracking = false,
                minimapShowAddonCompartment = false,
                minimapShowCraftingOrder = false,
            },
            talentReminders = {
                enabled = false,
                alertOnDifficulties = {
                    dungeonNormal = false,
                    dungeonHeroic = false,
                    dungeonMythic = false,
                    mythicPlus = true,
                    raidLFR = false,
                    raidNormal = false,
                    raidHeroic = true,
                    raidMythic = true
                },
                playSound = true,
                useTTS = true,
                ttsVolume = 1.0,
                showPopup = true,
                showChatMessage = true,
                alertFont = "Fonts\\FRIZQT__.TTF",
                alertFontSize = 12,
                alertIconSize = 16,
                alertPos = { point = "CENTER", x = 0, y = 0 }
            },
            widgets = {
                enabled = false,
                locked = true,
                showWoWOnly = false,
                showAddonMemory = true,
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 12,
                strata = "LOW",
                fontColor = { r = 1, g = 1, b = 1, a = 1 },
                time = { enabled = false, point = "CENTER", x = 0, y = 0 },
                fps = { enabled = false, point = "CENTER", x = 0, y = -20 },
                bags = { enabled = false, point = "CENTER", x = 0, y = -40 },
                spec = { enabled = false, point = "CENTER", x = 0, y = -60 },
                durability = { enabled = false, point = "CENTER", x = 0, y = -80 },
                combat = { enabled = false, point = "CENTER", x = 0, y = -100 },
                friends = { enabled = false, point = "CENTER", x = 0, y = -120 },
                guild = { enabled = false, point = "CENTER", x = 0, y = -140 },
                group = { enabled = false, point = "CENTER", x = 0, y = -160 },
                teleports = { enabled = false, point = "CENTER", x = 0, y = -180 }
            }
        }

        -- Apply all defaults
        ApplyDefaults(UIThingsDB, DEFAULTS)

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

        if addonTable.TalentReminder and addonTable.TalentReminder.Initialize then
            addonTable.TalentReminder.Initialize()
        end

        if addonTable.Widgets and addonTable.Widgets.Initialize then
            addonTable.Widgets.Initialize()
        end

        -- Slash Commands
        SLASH_UITHINGS1 = "/luit"
        SLASH_UITHINGS2 = "/luithings"

        -- LunaUITweaks_OpenConfig is defined in ConfigMain.lua (used by Addon Compartment)
        SlashCmdList["UITHINGS"] = function(msg)
            LunaUITweaks_OpenConfig()
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", OnEvent)
