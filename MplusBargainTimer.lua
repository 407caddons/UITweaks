-- Xal'atath's Bargain timer for Mythic+ (+5 to +11; Xal'atath's Guile replaces
-- it at +12, so the run's own affix list decides). The affix fires about every
-- minute of combat time: the clock pauses whenever nobody in the group is in
-- combat and resumes when anyone enters combat again. The bar is shown through
-- the encounter bars (EncounterBars.lua) next to the custom timers.
--
-- Interval and reset rules come from guides, not verified data, so every run
-- records a calibration log shown in a copyable window when the key ends.
local _, addon = ...
local Bargain = {}
addon.MplusBargainTimer = Bargain

local Public = addon.Secret.IsPublic
local INTERVAL = 60
local MAX_LOG = 400
-- Debuffs applied to every player when the affix fires; used to resync the
-- clock when the game exposes the spell ID (it may be secret during keys).
local AFFIXES = {
    [148] = {},                 -- Ascendant: orbs spawn
    [158] = {},                 -- Voidbound: Void Emissary spawns
    [162] = { aura = 1216858 }, -- Pulsar: Void Pulsar on each player
    [160] = { aura = 440313 },  -- Devour: Devouring Rift on each player
}
local GROUP = { "player", "party1", "party2", "party3", "party4" }

local run          -- saved in UIThingsDB.mplusTimer.bargainRun for /reload
local combatSince  -- GetTime() when group combat started; nil while paused
local entry        -- current encounter-bar entry; replaced every cycle
local lastAuraAt = 0
local ticker

local function DB() return UIThingsDB and UIThingsDB.mplusTimer end
local function Enabled() return DB() and DB().bargainEnabled end

local function KeyElapsed()
    local _, elapsed = GetWorldElapsedTime(1)
    return Public(elapsed) and type(elapsed) == "number" and elapsed or 0
end

local function Clock(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- Combat seconds accumulated so far, including the running stretch.
local function CombatTime(now)
    if not run then return 0 end
    return run.combat + (combatSince and (now - combatSince) or 0)
end

local function Log(text)
    if not run then return end
    local log = run.log
    if #log >= MAX_LOG then return end
    log[#log + 1] = string.format("[key %s | combat %s] %s", Clock(KeyElapsed()), Clock(CombatTime(GetTime())), text)
end

local function RequestRefresh()
    if addon.EncounterBars and addon.EncounterBars.RequestRefresh then addon.EncounterBars.RequestRefresh() end
end

local function NewEntry()
    entry = { custom = true, customKey = -1, name = "Bargain: " .. run.affixName, icon = run.icon,
        duration = INTERVAL, spoken = {}, countdown = DB().bargainCountdown and true or false,
        color = DB().bargainColor }
end

-- The group counts as in combat when anyone readable is; unreadable members
-- are logged once and otherwise ignored (falls back to readable units).
local function GroupInCombat()
    for _, unit in ipairs(GROUP) do
        local exists = UnitExists(unit)
        if Public(exists) and exists then
            local combat = UnitAffectingCombat(unit)
            if not Public(combat) then
                if not run.secretLogged then run.secretLogged = true; Log("NOTE combat state of " .. unit .. " unreadable") end
            elseif combat then
                return true
            end
        end
    end
    return false
end

local function Tick(reason)
    run.ticks = run.ticks + 1
    Log(string.format("TICK #%d (%s)", run.ticks, reason))
    if entry and addon.EncounterBars and addon.EncounterBars.FinishCustomCountdown then
        addon.EncounterBars.FinishCustomCountdown(entry, 0)
    end
    if DB().bargainSound then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
    NewEntry()
end

-- Fold elapsed combat into the total, follow group combat and fire ticks.
local function Update()
    if not run then return end
    local now = GetTime()
    if combatSince then
        run.combat = run.combat + (now - combatSince)
        combatSince = now
    end
    local inCombat = GroupInCombat()
    if inCombat and not combatSince then
        combatSince = now
        Log("COMBAT START")
        RequestRefresh()
    elseif not inCombat and combatSince then
        combatSince = nil
        Log("COMBAT END (paused)")
        RequestRefresh()
    end
    if run.combat >= run.nextTick then
        -- Never replay a burst after a hitch; skip to the next due tick.
        while run.combat >= run.nextTick do run.nextTick = run.nextTick + INTERVAL end
        Tick("predicted")
    end
end

local function ShowReport(lines)
    local f = Bargain.reportFrame
    if not f then
        f = CreateFrame("Frame", "LunaBargainReport", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(620, 420); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
        f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.title:SetPoint("TOP", 0, -5)
        f.title:SetText("Xal'atath's Bargain calibration — Ctrl+A, Ctrl+C to copy")
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -30); scroll:SetPoint("BOTTOMRIGHT", -32, 12)
        local box = CreateFrame("EditBox", nil, scroll)
        box:SetMultiLine(true); box:SetAutoFocus(false); box:SetFontObject(ChatFontNormal)
        box:SetWidth(570)
        box:SetScript("OnEscapePressed", function() f:Hide() end)
        scroll:SetScrollChild(box)
        f.box = box
        tinsert(UISpecialFrames, "LunaBargainReport")
        Bargain.reportFrame = f
    end
    f.box:SetText(table.concat(lines, "\n"))
    f:Show()
    f.box:SetFocus(); f.box:HighlightText()
end

local function BuildReport(reason)
    local lines = {
        "LunaUITweaks Bargain report v1",
        string.format("Map %s (%d) +%d, affix %s (%d), interval %ds, ended: %s",
            run.mapName or "?", run.mapID or 0, run.level or 0, run.affixName, run.affixID, INTERVAL, reason),
        string.format("Key time %s, combat time %s, predicted ticks %d, debuffs seen %d",
            Clock(KeyElapsed()), Clock(run.combat), run.ticks, run.seen),
    }
    for _, line in ipairs(run.log) do lines[#lines + 1] = line end
    if #run.log >= MAX_LOG then lines[#lines + 1] = "(log truncated)" end
    return lines
end

local function EndRun(reason)
    if not run then return end
    Update()
    combatSince = nil
    Log("END " .. reason)
    local report = DB().bargainReport and (run.ticks > 0 or run.combat > 0) and BuildReport(reason)
    Bargain.lastReport = report or Bargain.lastReport
    run, entry = nil, nil
    DB().bargainRun = nil
    if ticker then ticker:Cancel(); ticker = nil end
    addon.EventBus.UnregisterUnitEvent("UNIT_AURA", "player", Bargain.OnAura)
    addon.EventBus.UnregisterUnitEvent("UNIT_FLAGS", GROUP, Update)
    RequestRefresh()
    if report then ShowReport(report) end
end

-- Returns the Bargain affix active in this run, if any.
local function ActiveAffix()
    local _, affixes = C_ChallengeMode.GetActiveKeystoneInfo()
    if type(affixes) ~= "table" then return end
    for _, id in ipairs(affixes) do
        if Public(id) and AFFIXES[id] then return id end
    end
end

local function StartRun(fresh)
    local affixID = Enabled() and C_ChallengeMode.IsChallengeModeActive() and ActiveAffix()
    if not affixID then
        if run then EndRun("affix inactive") end
        return
    end
    local mapID = C_ChallengeMode.GetActiveChallengeMapID()
    local level = C_ChallengeMode.GetActiveKeystoneInfo()
    local key = tostring(mapID) .. ":" .. tostring(level) .. ":" .. tostring(affixID)
    local saved = DB().bargainRun
    -- Resume after /reload: same key, and the key timer has not gone backwards.
    if not fresh and saved and saved.key == key and KeyElapsed() >= (saved.keyElapsed or 0) then
        run = saved
        Log("RESUMED after reload")
    else
        local name, _, icon = C_ChallengeMode.GetAffixInfo(affixID)
        run = { key = key, affixID = affixID, affixName = name or ("Affix " .. affixID), icon = icon or 134400,
            aura = AFFIXES[affixID].aura, mapID = mapID, level = level,
            mapName = C_ChallengeMode.GetMapUIInfo(mapID), combat = 0, nextTick = INTERVAL, ticks = 0, seen = 0, log = {} }
        DB().bargainRun = run
        Log("START")
    end
    combatSince = nil
    NewEntry()
    addon.EventBus.RegisterUnitEvent("UNIT_FLAGS", GROUP, Update, "MplusBargainTimer")
    if run.aura then addon.EventBus.RegisterUnitEvent("UNIT_AURA", "player", Bargain.OnAura, "MplusBargainTimer") end
    if not ticker then ticker = C_Timer.NewTicker(0.5, Update) end
    Update()
    RequestRefresh()
end

-- Resync on the affix debuff when its spell ID is readable. Only applied when
-- within 20s of the prediction, so an unrelated early application is ignored.
function Bargain.OnAura(_, unit, info)
    if not run or not run.aura or type(info) ~= "table" or not info.addedAuras then return end
    local now = GetTime()
    for _, aura in ipairs(info.addedAuras) do
        local id = aura.spellId
        if Public(id) and id == run.aura and now - lastAuraAt > 10 then
            lastAuraAt = now
            run.seen = run.seen + 1
            Update()
            local combat = run.combat
            local offset = combat - (run.nextTick - INTERVAL) -- seconds since last predicted tick
            local untilNext = run.nextTick - combat
            if untilNext <= 20 then
                Log(string.format("DEBUFF seen %.1fs before predicted tick; resynced", untilNext))
                run.nextTick = combat + INTERVAL
                Tick("debuff")
            elseif offset <= 20 then
                Log(string.format("DEBUFF seen %.1fs after predicted tick; resynced", offset))
                run.nextTick = combat + INTERVAL
                NewEntry()
            else
                Log(string.format("DEBUFF seen %.1fs off prediction; not resynced", math.min(offset, untilNext)))
            end
            RequestRefresh()
        end
    end
end

-- Encounter bars interface (mirrors CustomEncounterTimers.Append/HasTimers).
function Bargain.HasTimers()
    return run ~= nil and entry ~= nil and (combatSince ~= nil or DB().bargainShowPaused)
end

function Bargain.Append(list, now)
    if not Bargain.HasTimers() then return end
    local paused = combatSince == nil
    entry.remaining = math.max(0, run.nextTick - CombatTime(now))
    entry.paused = paused
    local db = UIThingsDB.encounterBars
    if not db.limitHorizon or entry.remaining <= db.horizon or paused then list[#list + 1] = entry end
end

function Bargain.UpdateSettings()
    if not Enabled() then
        if run then EndRun("disabled") end
        return
    end
    if not run then StartRun(false)
    elseif entry then entry.countdown = DB().bargainCountdown and true or false end
    RequestRefresh()
end

function Bargain.ShowLastReport()
    if Bargain.lastReport then ShowReport(Bargain.lastReport)
    elseif run then ShowReport(BuildReport("in progress"))
    else print("|cff00ccffLuna M+:|r No Bargain report yet. One is shown when a key with Xal'atath's Bargain ends.") end
end
Bargain.GetStatus = function()
    if not Enabled() then return "Off." end
    if not (UIThingsDB.encounterBars and UIThingsDB.encounterBars.enabled) then
        return "Needs Encounter Bars & Timers enabled (Combat → Encounter Bars)."
    end
    if addon.EncounterBars and addon.EncounterBars.GetBlocker() then return addon.EncounterBars.GetBlocker() .. "; encounter bars are off." end
    if run then return "Active: " .. run.affixName .. "." end
    return "Waiting for a +5 to +11 key."
end

local events = addon.EventBus
events.Register("CHALLENGE_MODE_START", function() if Enabled() then StartRun(true) end end, "MplusBargainTimer")
events.Register("CHALLENGE_MODE_COMPLETED", function() EndRun("completed") end, "MplusBargainTimer")
events.Register("CHALLENGE_MODE_RESET", function() EndRun("reset") end, "MplusBargainTimer")
events.Register("PLAYER_ENTERING_WORLD", function()
    if C_ChallengeMode.IsChallengeModeActive() then
        if Enabled() and not run then StartRun(false) end
    elseif run then
        EndRun("left the dungeon")
    end
end, "MplusBargainTimer")
events.Register("PLAYER_REGEN_DISABLED", Update, "MplusBargainTimer")
events.Register("PLAYER_REGEN_ENABLED", Update, "MplusBargainTimer")
events.Register("ENCOUNTER_START", function(_, _, name)
    if run then Log("ENCOUNTER_START " .. (Public(name) and tostring(name) or "?")) end
end, "MplusBargainTimer")
events.Register("ENCOUNTER_END", function(_, _, name, _, _, success)
    if run then Log("ENCOUNTER_END " .. (Public(name) and tostring(name) or "?") .. (Public(success) and (success == 1 and " kill" or " wipe") or "")) end
end, "MplusBargainTimer")
events.Register("PLAYER_LOGOUT", function()
    -- Fold running combat so a /reload resumes from the right point.
    if run then Update(); run.keyElapsed = KeyElapsed(); combatSince = nil end
end, "MplusBargainTimer")

SLASH_LUNABARGAIN1 = "/lunabargain"
SlashCmdList.LUNABARGAIN = function() Bargain.ShowLastReport() end
