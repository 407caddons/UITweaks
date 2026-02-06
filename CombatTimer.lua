local addonName, addonTable = ...
addonTable.Combat = {}

local timerFrame
local timerText
local startTime = 0
local inCombat = false
local timeElapsed = 0

local function FormatTime(seconds)
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d", m, s)
end

function addonTable.Combat.UpdateSettings()
    if not timerFrame then return end

    if not UIThingsDB.combat.enabled then
        timerFrame:Hide()
        return
    end
    timerFrame:Show()

    local settings = UIThingsDB.combat

    -- Position
    timerFrame:ClearAllPoints()
    if settings.pos then
        timerFrame:SetPoint(settings.pos.point, UIParent, settings.pos.point, settings.pos.x, settings.pos.y)
    else
        timerFrame:SetPoint("CENTER")
    end

    -- Font
    if settings.font and settings.fontSize then
        timerText:SetFont(settings.font, settings.fontSize, "OUTLINE")
    end

    -- Color
    local color = inCombat and settings.colorInCombat or settings.colorOutCombat
    if color then
        timerText:SetTextColor(color.r, color.g, color.b)
    end

    -- Lock
    if settings.locked then
        timerFrame:EnableMouse(false)
        timerFrame:SetBackdrop(nil)
    else
        timerFrame:EnableMouse(true)
        timerFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        timerFrame:SetBackdropColor(0, 0, 0, 0.5)
    end
end

local function Init()
    timerFrame = CreateFrame("Frame", "UIThingsCombatTimer", UIParent, "BackdropTemplate")
    timerFrame:SetSize(100, 40)
    timerFrame:SetMovable(true)
    timerFrame:SetClampedToScreen(true)
    timerFrame:RegisterForDrag("LeftButton")

    timerFrame:SetScript("OnDragStart", timerFrame.StartMoving)
    timerFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        UIThingsDB.combat.pos = { point = point, x = x, y = y }
    end)

    timerText = timerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    timerText:SetPoint("CENTER")
    timerText:SetText("00:00")

    addonTable.Combat.UpdateSettings()

    timerFrame:SetScript("OnEvent", function(self, event)
        if not UIThingsDB.combat.enabled then return end
        if event == "PLAYER_REGEN_DISABLED" then
            inCombat = true
            startTime = GetTime()
            timeElapsed = 0
            timerText:SetText("00:00")
            addonTable.Combat.UpdateSettings() -- Update color
        elseif event == "PLAYER_REGEN_ENABLED" then
            inCombat = false
            -- Final update
            if startTime > 0 then
                timeElapsed = GetTime() - startTime
                timerText:SetText(FormatTime(timeElapsed))
            end
            addonTable.Combat.UpdateSettings()  -- Update color
        end
    end)
    timerFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    timerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    -- Throttled OnUpdate (only update once per second)
    local updateTimer = 0
    timerFrame:SetScript("OnUpdate", function(self, elapsed)
        if inCombat then
            updateTimer = updateTimer + elapsed
            if updateTimer >= 1.0 then
                updateTimer = 0
                timeElapsed = GetTime() - startTime
                timerText:SetText(FormatTime(timeElapsed))
            end
        end
    end)
end

-- Combat Logging by Instance Difficulty
local combatLogActive = false

local difficultyMap = {
    [1]  = "dungeonNormal",
    [2]  = "dungeonHeroic",
    [23] = "dungeonMythic",
    [8]  = "mythicPlus",
    [17] = "raidLFR",
    [14] = "raidNormal",
    [15] = "raidHeroic",
    [16] = "raidMythic",
}

local function CheckCombatLogging()
    local settings = UIThingsDB.combat.combatLog
    if not settings then return end

    local _, instanceType, difficultyID = GetInstanceInfo()
    local shouldLog = false

    if instanceType == "party" or instanceType == "raid" then
        local key = difficultyMap[difficultyID]
        if key and settings[key] then
            shouldLog = true
        end
    end

    if shouldLog and not combatLogActive then
        LoggingCombat(true)
        combatLogActive = true
        addonTable.Core.Log("Combat", "Combat logging started", 1)
    elseif not shouldLog and combatLogActive then
        LoggingCombat(false)
        combatLogActive = false
        addonTable.Core.Log("Combat", "Combat logging stopped", 1)
    end
end

function addonTable.Combat.CheckCombatLogging()
    CheckCombatLogging()
end

-- Instance detection frame (separate from timer so it works even with timer disabled)
local logFrame = CreateFrame("Frame")
logFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
logFrame:RegisterEvent("CHALLENGE_MODE_START")
logFrame:SetScript("OnEvent", function(self, event)
    C_Timer.After(2, CheckCombatLogging)
end)

-- Initialize when Core loads
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if addonTable.Core and addonTable.Core.SafeAfter then
        addonTable.Core.SafeAfter(1, Init)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(1, Init)
    end
end)
