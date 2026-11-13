-- Dungeon boss progress panel (WoW Forever). Lists the bosses of the current
-- dungeon/raid, ticks them off as they die, and remembers your fastest kill
-- of each boss. Modelled on the M+ timer frame but has no overall timer and is
-- not tied to Mythic+. Boss names come from the Encounter Journal; kills come
-- from ENCOUNTER_END / BOSS_KILL.
local addonName, addonTable = ...
local DungeonProgress = {}
addonTable.DungeonProgress = DungeonProgress

local WIDTH, ROW_H, HEAD_H = 250, 18, 26
local RESTORE_WINDOW = 1800 -- seconds a run survives a reload / relog

local frame, title, rows = nil, nil, {}
local toast, driver
local run, active = nil, false
local bosses, loadedFor = {}, nil
local fightStart = {}
local demo = false

local DEMO_BOSSES = { { id = 1, name = "First Boss" }, { id = 2, name = "Second Boss" }, { id = 3, name = "Final Boss" } }
local DEMO_KILLS = { ["1"] = { elapsed = 312, fight = 48 } }
local DEMO_BEST = { ["1"] = { run = 290, fight = 45 }, ["2"] = { run = 600, fight = 70 } }

local function DB() return UIThingsDB and UIThingsDB.dungeonProgress end

local function Fmt(seconds)
    if not seconds or seconds < 0 then seconds = 0 end
    return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

local function After(delay, func)
    if addonTable.Core and addonTable.Core.SafeAfter then addonTable.Core.SafeAfter(delay, func)
    else C_Timer.After(delay, func) end
end

-- ============================================================
-- Frames
-- ============================================================
local function SavePosition()
    local db = DB()
    if not db or not frame then return end
    local point, _, _, x, y = frame:GetPoint()
    db.pos = { point = point, x = x, y = y }
end

local function BeginMove()
    local db = DB()
    if db and not db.locked and frame then frame:StartMoving() end
end

local function EndMove()
    if frame then frame:StopMovingOrSizing(); SavePosition() end
end

local function InitFrame()
    if frame then return end
    local db = DB()
    frame = CreateFrame("Frame", "LunaDungeonProgress", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, 60)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    local pos = db and db.pos or { point = "CENTER", x = -400, y = 100 }
    frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    frame:SetScript("OnMouseDown", BeginMove)
    frame:SetScript("OnMouseUp", EndMove)
    frame:Hide()

    title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont(LunaUITweaksAPI.Style.Font(), 13, "OUTLINE")
    title:SetPoint("TOPLEFT", 8, -7)
    title:SetPoint("TOPRIGHT", -8, -7)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)

    local line = frame:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.15)
    line:SetPoint("TOPLEFT", 6, -(HEAD_H - 3))
    line:SetPoint("TOPRIGHT", -6, -(HEAD_H - 3))
    line:SetHeight(1)
end

local function AcquireRow(index)
    local row = rows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, frame)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -(HEAD_H + (index - 1) * ROW_H))
    row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -(HEAD_H + (index - 1) * ROW_H))
    row:EnableMouse(true)
    row.flash = row:CreateTexture(nil, "BACKGROUND")
    row.flash:SetAllPoints()
    row.flash:SetColorTexture(0.2, 1, 0.2, 1)
    row.flash:SetAlpha(0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(14, 14)
    row.icon:SetPoint("LEFT", 2, 0)
    row.time = row:CreateFontString(nil, "OVERLAY")
    row.time:SetFont(LunaUITweaksAPI.Style.Font(), 11, "OUTLINE")
    row.time:SetPoint("RIGHT", -2, 0)
    row.time:SetJustifyH("RIGHT")
    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFont(LunaUITweaksAPI.Style.Font(), 12, "OUTLINE")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.name:SetPoint("RIGHT", row.time, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:SetScript("OnMouseDown", BeginMove)
    row:SetScript("OnMouseUp", EndMove)
    row:SetScript("OnEnter", function(self)
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tip[1])
        for i = 2, #self.tip do GameTooltip:AddLine(self.tip[i], 1, 1, 1) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[index] = row
    return row
end

-- ============================================================
-- Toast + row flash driver (only runs while something is animating)
-- ============================================================
local function InitToast()
    if toast then return end
    toast = CreateFrame("Frame", nil, UIParent)
    toast:SetSize(500, 60)
    toast:SetPoint("TOP", UIParent, "TOP", 0, -170)
    toast:SetFrameStrata("HIGH")
    toast.title = toast:CreateFontString(nil, "OVERLAY")
    toast.title:SetFont(LunaUITweaksAPI.Style.Font(), 26, "OUTLINE")
    toast.title:SetPoint("TOP", 0, 0)
    toast.sub = toast:CreateFontString(nil, "OVERLAY")
    toast.sub:SetFont(LunaUITweaksAPI.Style.Font(), 15, "OUTLINE")
    toast.sub:SetPoint("TOP", toast.title, "BOTTOM", 0, -4)
    toast:Hide()

    driver = CreateFrame("Frame")
    driver:Hide()
    driver:SetScript("OnUpdate", function(self)
        local now, busy = GetTime(), false
        if toast.expire and now < toast.expire then
            toast:SetAlpha(math.min(1, toast.expire - now))
            busy = true
        else
            toast:Hide()
        end
        for _, row in ipairs(rows) do
            if row.flashUntil and now < row.flashUntil then
                row.flash:SetAlpha(0.35 * (row.flashUntil - now) / 2.5)
                busy = true
            elseif row.flashUntil then
                row.flash:SetAlpha(0)
                row.flashUntil = nil
            end
        end
        if not busy then self:Hide() end
    end)
end

local function ShowKillToast(bossName, elapsed, fight, improved)
    local db = DB()
    InitToast()
    toast.title:SetText("|cFF33FF33" .. bossName .. " defeated|r")
    local sub = Fmt(elapsed)
    if fight then sub = sub .. "  |cFFAAAAAA(fight " .. Fmt(fight) .. ")|r" end
    if improved then sub = sub .. "  |cFFFFD100New best!|r" end
    toast.sub:SetText(sub)
    if not db or db.showToast ~= false then
        toast.expire = GetTime() + 4
        toast:SetAlpha(1)
        toast:Show()
    end
    driver:Show()
end

-- ============================================================
-- Rendering
-- ============================================================
local function BestTable()
    local db = DB()
    if demo then return DEMO_BEST end
    if not db or not run then return {} end
    return db.best[run.instanceID .. ":" .. run.difficultyID] or {}
end

local function Update()
    local db = DB()
    if not db or not db.enabled then
        if frame then frame:Hide() end
        return
    end
    local list, kills, name
    if demo then
        list, kills, name = DEMO_BOSSES, DEMO_KILLS, "Demo Dungeon"
    elseif active and run then
        list, kills, name = bosses, run.kills, run.name or "Dungeon"
    else
        if frame then frame:Hide() end
        return
    end
    InitFrame()
    frame:EnableMouse(true) -- Layout Mode turns this off while it owns dragging
    local best = BestTable()
    local dead = 0
    for index, boss in ipairs(list) do
        local key = tostring(boss.id)
        local kill, record = kills[key], best[key]
        local row = AcquireRow(index)
        row.name:SetText(boss.name)
        if kill then
            dead = dead + 1
            row.icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
            row.name:SetTextColor(0.3, 1, 0.3)
            local text = kill.elapsed and Fmt(kill.elapsed) or "dead"
            if record then text = text .. " |cFF888888best " .. Fmt(record.run) .. "|r" end
            row.time:SetText(text)
            row.time:SetTextColor(1, 1, 1)
        else
            row.icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
            row.name:SetTextColor(1, 1, 1)
            row.time:SetText(record and ("best " .. Fmt(record.run)) or "")
            row.time:SetTextColor(0.55, 0.55, 0.55)
        end
        local tip = { boss.name }
        if kill and kill.elapsed then tip[#tip + 1] = "Killed at " .. Fmt(kill.elapsed) .. " into the run" end
        if kill and kill.fight then tip[#tip + 1] = "Fight length " .. Fmt(kill.fight) end
        if record then
            tip[#tip + 1] = "Best: " .. Fmt(record.run) .. " into the run"
            if record.fight then tip[#tip + 1] = "Best fight: " .. Fmt(record.fight) end
        end
        row.tip = tip
        row:Show()
    end
    for index = #list + 1, #rows do rows[index]:Hide() end
    title:SetText(string.format("%s |cFF%s%d/%d|r", name, dead == #list and #list > 0 and "33FF33" or "FFD100", dead, #list))
    frame:SetHeight(HEAD_H + #list * ROW_H + 6)
    frame:Show()
end

-- ============================================================
-- Boss list + kill tracking
-- ============================================================
local function ReadJournalBosses(ejID, list)
    pcall(EJ_SelectInstance, ejID)
    for i = 1, 30 do
        local good, bossName, _, journalID, _, _, _, dungeonEncounterID = pcall(EJ_GetEncounterInfoByIndex, i, ejID)
        if not good or not bossName then break end
        list[#list + 1] = { id = dungeonEncounterID or journalID, name = bossName }
    end
end

-- Journal instance for the current map, trying parent maps, then a name/ID
-- search through every tier's instance list.
local function FindJournalInstance(instanceName, instanceID)
    if EJ_GetInstanceForMap and C_Map and C_Map.GetBestMapForUnit then
        local mapID = C_Map.GetBestMapForUnit("player")
        for _ = 1, 6 do
            if not mapID or mapID == 0 then break end
            local ok, ejID = pcall(EJ_GetInstanceForMap, mapID)
            if ok and ejID and ejID ~= 0 then return ejID end
            local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
            mapID = info and info.parentMapID
        end
    end
    if EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex then
        local currentTier = EJ_GetCurrentTier and EJ_GetCurrentTier()
        local found
        for tier = 1, (EJ_GetNumTiers() or 0) do
            pcall(EJ_SelectTier, tier)
            for _, isRaid in ipairs({ false, true }) do
                for i = 1, 100 do
                    local ok, ejID, ejName = pcall(EJ_GetInstanceByIndex, i, isRaid)
                    if not ok or not ejID then break end
                    local matchesID = false
                    if EJ_GetInstanceInfo then
                        local _, _, _, _, _, _, _, _, _, ejMapID = EJ_GetInstanceInfo(ejID)
                        matchesID = ejMapID ~= nil and ejMapID == instanceID
                    end
                    if matchesID or (ejName and ejName == instanceName) then found = ejID break end
                end
                if found then break end
            end
            if found then break end
        end
        if currentTier then pcall(EJ_SelectTier, currentTier) end
        return found
    end
end

local function ReadLFGBosses(list)
    local lfgID = select(10, GetInstanceInfo())
    if not (lfgID and lfgID ~= 0 and GetLFGDungeonNumEncounters and GetLFGDungeonEncounterInfo) then return end
    for i = 1, (GetLFGDungeonNumEncounters(lfgID) or 0) do
        local bossName = GetLFGDungeonEncounterInfo(lfgID, i)
        if bossName then list[#list + 1] = { id = "lfg:" .. bossName, name = bossName } end
    end
end

-- The ForeverDungeonJournal addon carries boss lists (with name aliases) for the
-- Forever dungeons, including custom ones the client journal doesn't know.
local function ReadDungeonJournalBosses(instanceName, list)
    local ns = _G.ForeverDungeonJournal_NS
    local dungeon = ns and type(ns.DB) == "table" and ns.DB[instanceName]
    if type(dungeon) ~= "table" or type(dungeon.bosses) ~= "table" then return end
    for _, boss in ipairs(dungeon.bosses) do
        if boss.name then
            list[#list + 1] = { id = "fdj:" .. boss.name, name = boss.name, aliases = boss.aliases }
        end
    end
end

local function LoadBosses()
    local list = {}
    local instanceName, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    local ejID = FindJournalInstance(instanceName, instanceID)
    if ejID then ReadJournalBosses(ejID, list) end
    if #list == 0 then ReadLFGBosses(list) end
    if #list == 0 then ReadDungeonJournalBosses(instanceName, list) end
    -- Keep anything already learned from kills this run.
    if run then
        for _, boss in ipairs(bosses) do
            local found = false
            for _, other in ipairs(list) do
                if tostring(other.id) == tostring(boss.id) or other.name == boss.name then found = true end
            end
            if not found then list[#list + 1] = boss end
        end
    end
    bosses = list
end

-- Bosses the game already reports dead (killed before the addon saw it).
local function SyncLFGKills()
    if not run then return end
    local lfgID = select(10, GetInstanceInfo())
    if not (lfgID and lfgID ~= 0 and GetLFGDungeonNumEncounters and GetLFGDungeonEncounterInfo) then return end
    for i = 1, (GetLFGDungeonNumEncounters(lfgID) or 0) do
        local bossName, _, isKilled = GetLFGDungeonEncounterInfo(lfgID, i)
        if bossName and isKilled then
            for _, boss in ipairs(bosses) do
                local key = tostring(boss.id)
                if boss.name == bossName and not run.kills[key] then run.kills[key] = { known = true } end
            end
        end
    end
end

local function FindBoss(encounterID, encounterName)
    for _, boss in ipairs(bosses) do
        if tostring(boss.id) == tostring(encounterID) or (encounterName and boss.name == encounterName) then
            return boss
        end
        if encounterName and boss.aliases then
            for _, alias in ipairs(boss.aliases) do
                if alias == encounterName then return boss end
            end
        end
    end
    local boss = { id = encounterID, name = encounterName or ("Boss " .. tostring(encounterID)) }
    bosses[#bosses + 1] = boss
    return boss
end

local function RecordKill(encounterID, encounterName)
    local db = DB()
    if not db or not db.enabled or not active or not run then return end
    local boss = FindBoss(encounterID, encounterName)
    local key = tostring(boss.id)
    if run.kills[key] and run.kills[key].elapsed then return end
    local now = GetServerTime()
    local elapsed = now - run.startedAt
    local fight = fightStart[encounterID] and (GetTime() - fightStart[encounterID]) or nil
    fightStart[encounterID] = nil
    run.kills[key] = { elapsed = elapsed, fight = fight }
    run.lastSeen = now

    local bestKey = run.instanceID .. ":" .. run.difficultyID
    db.best[bestKey] = db.best[bestKey] or {}
    local record = db.best[bestKey][key]
    local improved = false
    if not record then
        db.best[bestKey][key] = { run = elapsed, fight = fight }
    else
        if elapsed < record.run then record.run = elapsed; improved = true end
        if fight and (not record.fight or fight < record.fight) then record.fight = fight; improved = true end
    end

    Update()
    for index, other in ipairs(bosses) do
        if other == boss and rows[index] then rows[index].flashUntil = GetTime() + 2.5 end
    end
    ShowKillToast(boss.name, elapsed, fight, improved)
end

local function Refresh()
    local db = DB()
    if not db or not db.enabled then Update(); return end
    local instanceName, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    if instanceType ~= "party" and instanceType ~= "raid" then
        active, run, loadedFor = false, nil, nil
        Update()
        return
    end
    difficultyID = difficultyID or 0
    local saved = db.run
    if saved and saved.instanceID == instanceID and saved.difficultyID == difficultyID
        and GetServerTime() - (saved.lastSeen or 0) < RESTORE_WINDOW then
        run = saved
    else
        run = { instanceID = instanceID, difficultyID = difficultyID, name = instanceName,
            startedAt = GetServerTime(), lastSeen = GetServerTime(), kills = {} }
        db.run = run
    end
    run.name = instanceName
    active = true
    local token = instanceID .. ":" .. difficultyID
    if loadedFor ~= token or #bosses == 0 then
        loadedFor = token
        bosses = {}
        LoadBosses()
    end
    SyncLFGKills()
    Update()
end

local function DelayedRefresh()
    After(1, Refresh)
    -- Encounter Journal data can arrive late; retry once if no bosses were found.
    After(4, function() if active and #bosses == 0 then LoadBosses(); SyncLFGKills(); Update() end end)
end

-- ============================================================
-- Events
-- ============================================================
local function OnEvent(event, ...)
    if event == "ENCOUNTER_START" then
        fightStart[(...)] = GetTime()
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName, _, _, success = ...
        if success == 1 then RecordKill(encounterID, encounterName) else fightStart[encounterID] = nil end
    elseif event == "BOSS_KILL" then
        local encounterID, encounterName = ...
        RecordKill(encounterID, encounterName)
    elseif event == "UPDATE_INSTANCE_INFO" then
        if active then SyncLFGKills(); Update() end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        DelayedRefresh()
    end
end

local function OnLogin()
    addonTable.EventBus.Unregister("PLAYER_LOGIN", OnLogin)
    if not DB() then return end
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ENCOUNTER_START", "ENCOUNTER_END", "BOSS_KILL", "UPDATE_INSTANCE_INFO" }) do
        addonTable.EventBus.Register(event, OnEvent, "DungeonProgress")
    end
    C_Timer.NewTicker(60, function()
        if active and run then run.lastSeen = GetServerTime() end
    end)
    DelayedRefresh()
end
addonTable.EventBus.Register("PLAYER_LOGIN", OnLogin, "DungeonProgress")

-- ============================================================
-- Slash command
-- ============================================================
function DungeonProgress.SetDemo(on)
    demo = on and true or false
    Update()
end

SLASH_LUNADUNGEONPROGRESS1 = "/lunabosses"
SlashCmdList["LUNADUNGEONPROGRESS"] = function(msg)
    local db = DB()
    if not db then return end
    local cmd = (msg or ""):lower():match("^%s*(%S*)")
    if cmd == "unlock" then
        db.locked = false; demo = true; Update()
        print("|cFF00FF96LunaBosses|r: unlocked - drag the demo panel, then /lunabosses lock")
    elseif cmd == "lock" then
        db.locked = true; demo = false; Update()
        print("|cFF00FF96LunaBosses|r: locked")
    elseif cmd == "demo" then
        demo = not demo; Update()
    elseif cmd == "toggle" then
        db.enabled = not db.enabled; Refresh()
        print("|cFF00FF96LunaBosses|r: " .. (db.enabled and "enabled" or "disabled"))
    elseif cmd == "debug" then
        local p = function(...) print("|cFF00FF96LunaBosses|r", ...) end
        p("GetInstanceInfo", GetInstanceInfo())
        local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        p("mapID", tostring(mapID), "EJ_GetInstanceForMap", EJ_GetInstanceForMap and tostring((select(2, pcall(EJ_GetInstanceForMap, mapID or 0)))) or "missing")
        local name, _, _, _, _, _, _, instanceID = GetInstanceInfo()
        local ejID = FindJournalInstance(name, instanceID)
        p("journal instance", tostring(ejID))
        if ejID then
            local list = {}
            ReadJournalBosses(ejID, list)
            for _, b in ipairs(list) do p("EJ boss", tostring(b.id), b.name) end
        end
        local lfgID = select(10, GetInstanceInfo())
        p("lfgDungeonID", tostring(lfgID), "NumEncounters", GetLFGDungeonNumEncounters and tostring((GetLFGDungeonNumEncounters(lfgID or 0))) or "missing")
        local fdj = {}
        ReadDungeonJournalBosses(name, fdj)
        for _, b in ipairs(fdj) do p("DungeonJournal boss", b.name) end
        if lfgID and GetLFGDungeonEncounterInfo then
            for i = 1, (GetLFGDungeonNumEncounters(lfgID) or 0) do p("LFG boss", GetLFGDungeonEncounterInfo(lfgID, i)) end
        end
        p("panel bosses", #bosses, "active", tostring(active))
    elseif cmd == "reset" then
        db.run = nil; run, loadedFor = nil, nil; bosses = {}; Refresh()
        print("|cFF00FF96LunaBosses|r: current run reset")
    elseif cmd == "resetbest" then
        db.best = {}; Update()
        print("|cFF00FF96LunaBosses|r: best times cleared")
    else
        print("|cFF00FF96LunaBosses|r: /lunabosses unlock | lock | demo | toggle | debug | reset | resetbest")
    end
end

-- Layout Mode integration: show the demo panel while unlocked so it can be dragged.
addonTable.LayoutMode.RegisterModule("DungeonProgress", {
    setLocked = function(locked)
        local db = DB()
        if db then db.locked = locked end
    end,
    apply = function(locked)
        demo = not locked and DB() ~= nil and DB().enabled == true
        Update()
    end,
})
addonTable.LayoutMode.RegisterTarget("Dungeon progress", function() return _G.LunaDungeonProgress end, function()
    local db = DB()
    return db and db.enabled
end, SavePosition)
