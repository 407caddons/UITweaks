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

--- Speak a TTS message using the best available API
-- @param message string Text to speak
-- @param voiceType number Voice index (0 = Standard, 1 = Alternate)
function addonTable.Core.SpeakTTS(message, voiceType)
    if not message then return end
    voiceType = voiceType or 0
    if TextToSpeech_Speak then
        local voiceID = TextToSpeech_GetSelectedVoice and TextToSpeech_GetSelectedVoice(voiceType) or nil
        pcall(TextToSpeech_Speak, message, voiceID)
    elseif C_VoiceChat and C_VoiceChat.SpeakText then
        pcall(C_VoiceChat.SpeakText, 0, message, voiceType, 1.0, false)
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

local LOG_COLORS = {
    [0] = "888888", -- DEBUG (gray)
    [1] = "00FF00", -- INFO (green)
    [2] = "FFFF00", -- WARN (yellow)
    [3] = "FF0000"  -- ERROR (red)
}

--- Centralized logging function
-- @param module string Module name (e.g., "Tracker", "Vendor")
-- @param msg string Message to log
-- @param level number Optional. Log level (default: INFO)
function addonTable.Core.Log(module, msg, level)
    level = level or addonTable.Core.LogLevel.INFO
    if level < addonTable.Core.currentLogLevel then return end

    local prefix = string.format("|cFF%s[Luna %s]|r", LOG_COLORS[level] or "FFFFFF", module or "Core")
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
                sectionHeaderFont = "Fonts\\FRIZQT__.TTF",
                sectionHeaderFontSize = 14,
                sectionHeaderColor = { r = 1, g = 0.82, b = 0, a = 1 },
                questPadding = 2,
                sectionSpacing = 10,
                itemSpacing = 5,
                sectionOrderList = {
                    "scenarios",
                    "tempObjectives",
                    "travelersLog",
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
                clickOpenQuest = true,
                shiftClickLink = true,
                middleClickShare = true,
                backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 },
                strata = "LOW",
                showWorldQuestTimer = true,
                hideCompletedSubtasks = false,
                groupQuestsByZone = false,
                groupQuestsByCampaign = false,
                worldQuestSortBy = "time",
                showQuestDistance = true,
                sortQuestsByDistance = false,
                showTooltipPreview = true,
                hideHeader = false,
                questNameColor = { r = 1, g = 1, b = 1, a = 1 },
                objectiveColor = { r = 0.8, g = 0.8, b = 0.8, a = 1 },
                completedObjectiveCheckmark = true,
                highlightCampaignQuests = true,
                campaignQuestColor = { r = 0.9, g = 0.7, b = 0.2, a = 1 },
                showQuestTypeIndicators = true,
                showQuestLineProgress = true,
                questCompletionSound = true,
                questCompletionSoundID = 6199,
                objectiveCompletionSound = false,
                objectiveCompletionSoundID = 6197,
                showWQRewardIcons = true,
                distanceUpdateInterval = 0,
                soundChannel = "Master",
                muteDefaultQuestSounds = false,
                restoreSuperTrack = true,
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
                warningPos = { point = "TOP", x = 0, y = -150 },
                -- Bag Space Warnings
                bagWarningEnabled = true,
                bagWarningThreshold = 5, -- Warn when 5 or fewer free slots
                bagWarningPos = { point = "TOP", x = 0, y = -200 }
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
                anchor = { point = "CENTER", x = 0, y = 200 },
                showCurrency = false,
                showGold = false,
                minGoldAmount = 10000, -- copper (1 gold = 10000 copper)
                showItemLevel = true,
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
                personalOrdersCheckAtLogon = false,
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
                mailNotification = false,
                mailTtsEnabled = true,
                mailTtsMessage = "You've got mail",
                mailTtsVoice = 0,
                mailAlertDuration = 5,
                mailAlertColor = { r = 1, g = 0.82, b = 0, a = 1 },
                autoInviteEnabled = false,
                autoInviteKeywords = "inv,invite",
                quickDestroy = false,
                sct = {
                    enabled = false,
                    captureToFrames = false,
                    showDamage = true,
                    showHealing = true,
                    showTargetDamage = false,
                    showTargetHealing = false,
                    fontSize = 24,
                    duration = 1.5,
                    critScale = 1.5,
                    scrollDistance = 100,
                    damageColor = { r = 1, g = 0.2, b = 0.2 },
                    healingColor = { r = 0.2, g = 1, b = 0.2 },
                    damageAnchor = { point = "CENTER", x = 150, y = 0 },
                    healingAnchor = { point = "CENTER", x = -150, y = 0 },
                    locked = true,
                },
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
                minimapDrawerEnabled = false,
                minimapDrawerLocked = true,
                minimapDrawerPos = { point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -200, y = -7 },
                minimapDrawerButtonSize = 32,
                minimapDrawerPadding = 4,
                minimapDrawerColumns = 6,
                minimapDrawerBorderColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 },
                minimapDrawerBorderSize = 2,
                minimapDrawerBgColor = { r = 0, g = 0, b = 0, a = 0.7 },
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
            talentManager = {
                enabled = true,
                panelWidth = 280,
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 11,
                showBorder = true,
                borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 },
                showBackground = true,
                backgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.9 },
                collapsedSections = {},
                ejCache = {},
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
                time = { enabled = false, point = "CENTER", x = 0, y = 0, condition = "always" },
                fps = { enabled = false, point = "CENTER", x = 0, y = -20, condition = "always" },
                bags = { enabled = false, point = "CENTER", x = 0, y = -40, goldData = {}, condition = "always" },
                spec = { enabled = false, point = "CENTER", x = 0, y = -60, condition = "always" },
                durability = { enabled = false, point = "CENTER", x = 0, y = -80, condition = "always" },
                combat = { enabled = false, point = "CENTER", x = 0, y = -100, condition = "always" },
                friends = { enabled = false, point = "CENTER", x = 0, y = -120, condition = "always" },
                guild = { enabled = false, point = "CENTER", x = 0, y = -140, condition = "always" },
                group = { enabled = false, point = "CENTER", x = 0, y = -160, condition = "always" },
                teleports = { enabled = false, point = "CENTER", x = 0, y = -180, condition = "always" },
                keystone = { enabled = false, point = "CENTER", x = 0, y = -200, condition = "always" },
                weeklyReset = { enabled = false, point = "CENTER", x = 0, y = -220, condition = "always" },
                coordinates = { enabled = false, point = "CENTER", x = 0, y = -240, condition = "always" },
                battleRes = { enabled = false, point = "CENTER", x = 0, y = -260, condition = "instance" },
                speed = { enabled = false, point = "CENTER", x = 0, y = -280, condition = "always" },
                itemLevel = { enabled = false, point = "CENTER", x = 0, y = -300, condition = "always" },
                volume = { enabled = false, point = "CENTER", x = 0, y = -320, condition = "always" },
                zone = { enabled = false, point = "CENTER", x = 0, y = -340, condition = "always" },
                pvp = { enabled = false, point = "CENTER", x = 0, y = -360, condition = "always" },
                mythicRating = { enabled = false, point = "CENTER", x = 0, y = -380, condition = "always" },
                vault = { enabled = false, point = "CENTER", x = 0, y = -400, condition = "always" },
                darkmoonFaire = { enabled = false, point = "CENTER", x = 0, y = -420, condition = "always" },
                mail = { enabled = false, point = "CENTER", x = 0, y = -440, condition = "always" },
                pullCounter = { enabled = false, point = "CENTER", x = 0, y = -460, condition = "instance" },
                hearthstone = { enabled = false, point = "CENTER", x = 0, y = -480, condition = "always" },
                currency = { enabled = false, point = "CENTER", x = 0, y = -500, condition = "always" },
                sessionStats = { enabled = false, point = "CENTER", x = 0, y = -520, condition = "always" }
            },
            kick = {
                enabled = false,
                locked = true,
                attachToPartyFrames = false,
                attachAnchorPoint = "BOTTOM", -- BOTTOM, TOP, LEFT, RIGHT
                attachIconSize = 28,
                trackNonAddonUsers = false,
                pos = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 },
                bgColor = { r = 0, g = 0, b = 0, a = 0.8 },
                borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 },
                barBgColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.9 },
                barBorderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
            },
            chatSkin = {
                enabled = false,
                borderColor = { r = 0, g = 0, b = 0, a = 1 },
                borderSize = 2,
                bgColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.7 },
                activeTabColor = { r = 0, g = 0.8, b = 0.4, a = 1 },
                inactiveTabColor = { r = 0.3, g = 0.3, b = 0.3, a = 0.8 },
                tabBgColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.8 },
                hideButtons = true,
                locked = true,
                chatWidth = 430,
                chatHeight = 200,
                timestamps = "none",
                pos = { point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = 20, y = 40 },
                highlightKeywords = {},
                highlightColor = { r = 1, g = 1, b = 0 },
                highlightSound = false,
            },
            castBar = {
                enabled = false,
                locked = true,
                width = 250,
                height = 20,
                pos = { point = "CENTER", x = 0, y = -200 },
                barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
                useClassColor = false,
                barColor = { r = 1, g = 0.7, b = 0, a = 1 },
                bgColor = { r = 0, g = 0, b = 0, a = 0.7 },
                borderColor = { r = 0, g = 0, b = 0, a = 1 },
                borderSize = 2,
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 12,
                showIcon = true,
                showSpellName = true,
                showCastTime = true,
                showSpark = true,
                nonInterruptibleColor = { r = 0.7, g = 0.7, b = 0.7, a = 1 },
                failedColor = { r = 1, g = 0, b = 0, a = 1 },
                channelColor = { r = 0, g = 0.6, b = 1, a = 1 },
            },
            actionBars = {
                enabled = false,
                locked = true,
                pos = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 30 },
                buttonSize = 32,
                padding = 4,
                borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 },
                borderSize = 2,
                bgColor = { r = 0, g = 0, b = 0, a = 0.7 },
                skinEnabled = false,
                skinButtonBorderColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 },
                skinButtonBorderSize = 1,
                skinBarBorderColor = { r = 0.2, g = 0.2, b = 0.2, a = 1 },
                skinBarBorderSize = 2,
                skinBarBgColor = { r = 0, g = 0, b = 0, a = 0.5 },
                hideMacroText = false,
                hideKeybindText = false,
                hideBarScroll = false,
                hideBagsBar = false,
                skinButtonSpacing = 2,
                skinButtonSize = 0,
                barOffsets = {},
                barPositions = {},
            },
            addonComm = {
                hideFromWorld = false,
                debugMode = false
            },
            reagents = {
                enabled = false
            },
            questAuto = {
                enabled = false,
                autoAcceptQuests = true,
                autoTurnIn = true,
                acceptTrivial = false,
                autoGossip = true,
                shiftToPause = true,
            },
            questReminder = {
                enabled = false,
                ttsEnabled = true,
                ttsMessage = "You've got quests",
                ttsVoice = 0,
                showPopup = true,
                showChatMessage = true,
                playSound = true,
                popupPos = { point = "CENTER", x = 0, y = 0 },
                frameWidth = 350,
                frameHeight = 250,
                showBorder = true,
                borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 },
                showBackground = true,
                backgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.92 },
            },
            mplusTimer = {
                enabled = false,
                locked = true,
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 12,
                timerFontSize = 20,
                pos = { point = "CENTER", x = 0, y = 0 },
                barWidth = 250,
                barHeight = 8,
                showDeaths = true,
                showAffixes = true,
                showForces = true,
                showBosses = true,
                bgColor = { r = 0, g = 0, b = 0, a = 0.5 },
                borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 },
                borderSize = 1,
                autoSlotKeystone = false,
                -- Text colors
                timerColor = { r = 1, g = 1, b = 1 },
                timerWarningColor = { r = 1, g = 1, b = 0.2 },
                timerDepletedColor = { r = 1, g = 0.2, b = 0.2 },
                timerSuccessColor = { r = 0.2, g = 1, b = 0.2 },
                deathColor = { r = 1, g = 0.2, b = 0.2 },
                keyColor = { r = 1, g = 0.82, b = 0 },
                affixColor = { r = 0.8, g = 0.8, b = 0.8 },
                bossCompleteColor = { r = 0, g = 1, b = 0 },
                bossIncompleteColor = { r = 1, g = 1, b = 1 },
                -- Bar colors
                barPlusThreeColor = { r = 0.2, g = 0.8, b = 0.2 },
                barPlusTwoColor = { r = 0.9, g = 0.9, b = 0.2 },
                barPlusOneColor = { r = 0.9, g = 0.3, b = 0.2 },
                forcesBarColor = { r = 0.4, g = 0.6, b = 1.0 },
                forcesTextColor = { r = 0.4, g = 0.8, b = 1.0 },
                forcesCompleteColor = { r = 0.2, g = 1, b = 0.2 },
            }
        }

        -- Expose defaults for config panels (used by reset buttons)
        addonTable.Core.DEFAULTS = DEFAULTS

        -- Apply all defaults
        ApplyDefaults(UIThingsDB, DEFAULTS)

        -- Apply debug mode from saved settings
        if UIThingsDB.addonComm and UIThingsDB.addonComm.debugMode then
            addonTable.Core.currentLogLevel = addonTable.Core.LogLevel.DEBUG
        end

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

        if addonTable.ChatSkin and addonTable.ChatSkin.Initialize then
            addonTable.ChatSkin.Initialize()
        end

        if addonTable.QuestReminder and addonTable.QuestReminder.Initialize then
            addonTable.QuestReminder.Initialize()
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
