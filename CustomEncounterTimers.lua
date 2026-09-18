local _, addon = ...
local Custom = {}
addon.CustomEncounterTimers = Custom
local enabled, inCombat, encounterStarted = false, false, false
local runs = {}
local function DB() return UIThingsDB.encounterBars end
local function Public(v) return not (issecretvalue and issecretvalue(v)) end
local function Trim(v) return type(v) == "string" and v:match("^%s*(.-)%s*$") or "" end
function Custom.ParseTime(text)
    text = Trim(text)
    local m, s = text:match("^(%d+):(%d%d?)$")
    local value
    if m then
        if tonumber(s) >= 60 then return end
        value = tonumber(m) * 60 + tonumber(s)
    elseif text:match("^%d+$") then value = tonumber(text) end
    if value and value >= 1 and value <= 3600 then return value end
end
function Custom.FormatTime(seconds)
    return seconds < 60 and tostring(seconds) or string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end
function Custom.GetTimers()
    local db = DB()
    -- User-requested reset of legacy sets; other encounter settings are untouched.
    db.customSets, db.nextCustomSetID = nil, nil
    db.customTimers = db.customTimers or {}
    return db.customTimers
end
function Custom.GetSortedTimers()
    local list = {}
    for _, timer in ipairs(Custom.GetTimers()) do list[#list+1] = timer end
    table.sort(list, function(a, b)
        local x, y = a.name:lower(), b.name:lower()
        if x == y then return a.id < b.id end
        return x < y
    end)
    return list
end
function Custom.GetIcon(timer)
    if timer.trigger == "cast" and timer.spellID and C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(timer.spellID) or 134376
    end
    return 134376
end
function Custom.CaptureLocation()
    local subzone, zone = GetSubZoneText(), GetRealZoneText()
    local _, _, _, _, _, _, _, id = GetInstanceInfo()
    if not Public(subzone) or not Public(zone) or not Public(id)
        or type(subzone) ~= "string" or type(zone) ~= "string" or type(id) ~= "number" then
        return nil, "Current location unavailable. Try outside combat."
    end
    return {subzone=subzone, zone=zone, instanceID=id}
end
local function Matches(timer, location)
    return not timer.location or (location and timer.location.instanceID == location.instanceID
        and timer.location.subzone == location.subzone)
end
local function ValidNumber(v, low, high)
    return type(v) == "number" and v >= low and v <= high and v == math.floor(v)
end
function Custom.SaveTimer(id, values)
    local name = Trim(values.name)
    if name == "" or #name > 200 or name:find("[\r\n]") then return nil, "Enter a timer name (1–200 characters)." end
    if values.trigger ~= "combat" and values.trigger ~= "encounter" and values.trigger ~= "cast" then
        return nil, "Choose a start trigger."
    end
    if not ValidNumber(values.first, 1, 3600)
        or (values.interval ~= nil and not ValidNumber(values.interval, 1, 3600)) then
        return nil, "Times must be 1–3600 seconds; leave Repeat blank for a one-off timer."
    end
    if values.trigger == "cast" and not ValidNumber(values.spellID, 1, 2147483647) then
        return nil, "Enter the spell ID of your successful cast."
    end
    local timer = {id=id, name=name, enabled=not not values.enabled, trigger=values.trigger,
        first=values.first, interval=values.interval}
    if values.trigger == "cast" then timer.spellID=values.spellID end
    if values.countdown ~= nil then timer.countdown=not not values.countdown end
    if values.expirySound and values.expirySound ~= "none" then
        if type(values.expirySound) ~= "string" or not values.expirySound:match("^[%w_:%-]+$") then
            return nil, "Invalid expiry sound."
        end
        timer.expirySound=values.expirySound
    end
    if values.color then
        timer.color={}
        for _, key in ipairs({"r","g","b"}) do
            local v=values.color[key]
            if type(v) ~= "number" or not (v >= 0 and v <= 1) then return nil, "Invalid colour." end
            timer.color[key]=v
        end
    end
    if values.location then
        local loc=values.location
        if not ValidNumber(loc.instanceID,0,2147483647) or type(loc.subzone) ~= "string" or #loc.subzone>200 then
            return nil, "Enter an instance/map ID and subzone name, or clear both for anywhere."
        end
        timer.location={instanceID=loc.instanceID, subzone=Trim(loc.subzone), zone=Trim(loc.zone)}
    end
    local list=Custom.GetTimers()
    if id then
        for i, old in ipairs(list) do
            if old.id==id then list[i]=timer; runs[id]=nil; return timer end
        end
        return nil, "This timer no longer exists."
    end
    if #list>=500 then return nil, "Maximum 500 custom timers." end
    local nextID=DB().nextCustomTimerID or 1
    for _, old in ipairs(list) do nextID=math.max(nextID,old.id+1) end
    timer.id=nextID; DB().nextCustomTimerID=nextID+1
    list[#list+1]=timer
    return timer
end
function Custom.DeleteTimer(id)
    for i, timer in ipairs(Custom.GetTimers()) do
        if timer.id==id then table.remove(DB().customTimers,i); runs[id]=nil; return end
    end
end
function Custom.Configure(active)
    local list=Custom.GetTimers()
    if not active then enabled,inCombat,encounterStarted=false,false,false; wipe(runs); return end
    if not enabled then
        inCombat=not not InCombatLockdown()
        encounterStarted=IsEncounterInProgress and not not IsEncounterInProgress() or false
    end
    enabled=true
    local valid={}
    for _, timer in ipairs(list) do if timer.enabled then valid[timer.id]=timer end end
    for id, run in pairs(runs) do if valid[id]~=run.source then runs[id]=nil end end
end
local function Start(trigger, spellID)
    local location=Custom.CaptureLocation()
    local now=GetTime()
    for _, timer in ipairs(Custom.GetTimers()) do
        if timer.enabled and timer.trigger==trigger and Matches(timer,location)
            and (trigger~="cast" or timer.spellID==spellID) then
            local entry={custom=true,customKey=timer.id,name=timer.name,icon=Custom.GetIcon(timer),
                duration=timer.first,ends=now+timer.first,firstEnd=now+timer.first,interval=timer.interval,
                color=timer.color,countdown=timer.countdown,expirySound=timer.expirySound,spoken={}}
            runs[timer.id]={source=timer,entries={entry}}
        end
    end
end
function Custom.OnEvent(event, unit, castGUID, spellID)
    if not enabled then return end
    if event=="UNIT_SPELLCAST_SUCCEEDED" then
        if not InCombatLockdown() or not Public(unit) or unit~="player"
            or not Public(spellID) or type(spellID)~="number" then return end
        inCombat=true
        Start("cast",spellID)
    elseif event=="PLAYER_REGEN_DISABLED" then
        if not inCombat then inCombat=true; Start("combat") end
    elseif event=="ENCOUNTER_START" then
        if not encounterStarted then encounterStarted=true; Start("encounter") end
    elseif event=="PLAYER_REGEN_ENABLED" then inCombat=false; wipe(runs)
    elseif event=="ENCOUNTER_END" then encounterStarted=false; wipe(runs)
    elseif event=="PLAYER_ENTERING_WORLD" then
        wipe(runs); inCombat=not not InCombatLockdown()
        encounterStarted=IsEncounterInProgress and not not IsEncounterInProgress() or false
    elseif event=="ZONE_CHANGED" or event=="ZONE_CHANGED_INDOORS" or event=="ZONE_CHANGED_NEW_AREA" then
        local location=Custom.CaptureLocation()
        for id, run in pairs(runs) do if not Matches(run.source,location) then runs[id]=nil end end
    end
end
function Custom.HasTimers()
    if not enabled or not inCombat then return false end
    for _, run in pairs(runs) do if next(run.entries) then return true end end
    return false
end
function Custom.Append(list, now)
    if not enabled or not inCombat then return end
    for _, run in pairs(runs) do
        for key, entry in pairs(run.entries) do
            if now >= entry.ends then
                -- Expiry is consumed before removing/advancing the entry. Never replay
                -- missed repeats after a hitch, or sound on cancellation/recast.
                if entry.expirySound and addon.BuffAlerts then
                    local sound = addon.BuffAlerts.ResolveSound({preset = entry.expirySound})
                    if sound then PlaySoundFile(sound, "Master") end
                end
                if addon.EncounterBars and addon.EncounterBars.FinishCustomCountdown then
                    addon.EncounterBars.FinishCustomCountdown(entry, entry.ends - now)
                end
                if entry.interval then
                    -- Skip missed occurrences after a hitch; never replay a burst of alerts.
                    local occurrence = math.floor((now - entry.firstEnd) / entry.interval) + 1
                    entry = { custom = true, customKey = entry.customKey, name = entry.name, icon = entry.icon,
                        duration = entry.interval, firstEnd = entry.firstEnd, interval = entry.interval,
                        ends = entry.firstEnd + occurrence * entry.interval, spoken = {},
                        color = entry.color, countdown = entry.countdown, expirySound = entry.expirySound }
                    run.entries[key] = entry
                else run.entries[key] = nil; entry = nil end
            end
            if entry then
                entry.remaining = entry.ends - now
                if not DB().limitHorizon or entry.remaining <= DB().horizon then list[#list + 1] = entry end
            end
        end
    end
end
