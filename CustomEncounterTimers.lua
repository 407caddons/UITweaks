local _, addon = ...
local Custom = {}
addon.CustomEncounterTimers = Custom
local enabled, inCombat, encounterStarted = false, false, false
local runs = {}
local function DB() return UIThingsDB.encounterBars end
local function Public(value) return not (issecretvalue and issecretvalue(value)) end
local function Trim(text) return text:match("^%s*(.-)%s*$") end

local function Seconds(text)
    text = Trim(text)
    local minutes, seconds = text:match("^(%d+):(%d%d?)$")
    local value
    if minutes then
        if tonumber(seconds) >= 60 then return end
        value = tonumber(minutes) * 60 + tonumber(seconds)
    elseif text:match("^%d+$") then value = tonumber(text) end
    if value and value >= 1 and value <= 3600 then return value end
end
Custom.ParseTime = Seconds
function Custom.FormatTime(seconds)
    if seconds < 60 then return tostring(seconds) end
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function Custom.Serialize(rules)
    local lines = {}
    for _, rule in ipairs(rules) do
        local spec = Custom.FormatTime(rule.first)
        if rule.interval then spec = spec .. "," .. Custom.FormatTime(rule.interval) end
        local tags = ""
        if rule.color then
            tags = string.format("[#%02X%02X%02X] ", math.floor(rule.color.r * 255 + 0.5),
                math.floor(rule.color.g * 255 + 0.5), math.floor(rule.color.b * 255 + 0.5))
        end
        if rule.countdown ~= nil then tags = tags .. "[countdown=" .. (rule.countdown and "on" or "off") .. "] " end
        lines[#lines + 1] = "{" .. spec .. "} " .. tags .. rule.name
    end
    return table.concat(lines, "\n")
end

function Custom.Parse(text)
    if type(text) ~= "string" or #text > 16000 then return nil, "Schedule must be at most 16,000 characters." end
    local result, lineNumber = {}, 0
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        lineNumber = lineNumber + 1
        if Trim(line) ~= "" then
            local spec, name = line:match("^%s*{([^}]+)}%s*(.-)%s*$")
            local first, repeatEvery
            if spec then
                local a, b = spec:match("^([^,]+),([^,]+)$")
                if a then first, repeatEvery = Seconds(a), Seconds(b)
                else first = Seconds(spec) end
                if spec:find(",", 1, true) and not repeatEvery then first = nil end
            end
            local color, countdown
            while name do
                local tag, rest = name:match("^%[([^%]]+)%]%s*(.*)$")
                if not tag then break end
                if tag:sub(1, 1) == "#" then
                    if not tag:match("^#%x%x%x%x%x%x$") or color then
                        return nil, "Line " .. lineNumber .. ": colour must be [#RRGGBB], once per timer."
                    end
                    color = { r = tonumber(tag:sub(2, 3), 16) / 255,
                        g = tonumber(tag:sub(4, 5), 16) / 255, b = tonumber(tag:sub(6, 7), 16) / 255 }
                elseif tag:sub(1, 10) == "countdown=" then
                    local mode = tag:sub(11)
                    if mode ~= "on" and mode ~= "off" and mode ~= "default" then
                        return nil, "Line " .. lineNumber .. ": countdown must be on, off or default."
                    end
                    countdown = nil
                    if mode ~= "default" then countdown = mode == "on" end
                else break end
                name = rest
            end
            if not first or not name or name == "" or #name > 200 then
                return nil, "Line " .. lineNumber .. ": use {20} Title or {2:20,20} Title; times must be 1–3600 seconds and titles 1–200 characters."
            end
            result[#result + 1] = { first = first, interval = repeatEvery, name = name, color = color, countdown = countdown }
            if #result > 100 then return nil, "Maximum 100 timers per set." end
        end
    end
    if #result == 0 then return nil, "Enter at least one timer." end
    return result
end

function Custom.CaptureLocation()
    local subzone, zone = GetSubZoneText(), GetRealZoneText()
    local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    if not Public(subzone) or not Public(zone) or not Public(instanceID)
        or type(subzone) ~= "string" or type(zone) ~= "string" or zone == ""
        or type(instanceID) ~= "number" then return nil, "Current location is unavailable. Try again outside combat." end
    -- Instance ID is the physical map, not a UI-map floor that changes on stairs.
    return { subzone = subzone, zone = zone, instanceID = instanceID }
end

function Custom.LocationLabel(location)
    return location.subzone ~= "" and (location.subzone .. " — " .. location.zone)
        or (location.zone .. " (no named subzone)")
end

local function Matches(a, b)
    return a and b and a.instanceID == b.instanceID and a.zone == b.zone and a.subzone == b.subzone
end

function Custom.GetSets() return DB().customSets or {} end
function Custom.AddSet()
    local location, err = Custom.CaptureLocation()
    if not location then return nil, err end
    local sets = Custom.GetSets()
    if #sets >= 32 then return nil, "Maximum 32 timer sets." end
    local id = #sets == 0 and 1 or (DB().nextCustomSetID or 1)
    DB().nextCustomSetID = id + 1
    local set = { id = id, name = location.subzone ~= "" and location.subzone or location.zone,
        location = location, trigger = "combat", enabled = false, text = "" }
    sets[#sets + 1] = set; DB().customSets = sets
    return set
end

function Custom.SaveSet(id, name, trigger, isEnabled, text)
    local parsed, err = Custom.Parse(text)
    if not parsed then return false, err end
    name = Trim(name)
    if name == "" or #name > 80 then return false, "Enter a set name (1–80 characters)." end
    if trigger ~= "combat" and trigger ~= "encounter" then return false, "Select a valid trigger." end
    for _, set in ipairs(Custom.GetSets()) do
        if set.id == id then
            set.name, set.trigger, set.enabled, set.text = name, trigger, isEnabled, text
            runs[id] = nil -- Edits take effect on the next trigger, not halfway through a pull.
            return true
        end
    end
    return false, "This timer set no longer exists."
end

function Custom.DeleteSet(id)
    for i, set in ipairs(Custom.GetSets()) do
        if set.id == id then table.remove(DB().customSets, i); runs[id] = nil; return end
    end
end

function Custom.Configure(active)
    if not active then
        enabled, inCombat, encounterStarted = false, false, false
        wipe(runs)
        return
    end
    if not enabled then
        -- Never infer a start time on reload or when enabling mid-fight.
        inCombat = not not InCombatLockdown()
        encounterStarted = not not IsEncounterInProgress()
    end
    enabled = true
    local valid = {}
    for _, set in ipairs(Custom.GetSets()) do if set.enabled then valid[set.id] = set end end
    for id, run in pairs(runs) do if valid[id] ~= run.source then runs[id] = nil end end
end

local function Start(trigger)
    local location = Custom.CaptureLocation()
    local now = GetTime()
    for _, set in ipairs(Custom.GetSets()) do
        if set.enabled and set.trigger == trigger and not runs[set.id] and Matches(set.location, location) then
            local parsed = Custom.Parse(set.text)
            if parsed then
                local entries = {}
                for i, rule in ipairs(parsed) do
                    entries[i] = { custom = true, customKey = set.id * 1000 + i, name = rule.name,
                        icon = 134376, duration = rule.first, ends = now + rule.first,
                        firstEnd = now + rule.first, interval = rule.interval, spoken = {} }
                    entries[i].color, entries[i].countdown = rule.color, rule.countdown
                end
                runs[set.id] = { source = set, entries = entries }
            end
        end
    end
end

function Custom.OnEvent(event)
    if not enabled then return end
    if event == "PLAYER_REGEN_DISABLED" then
        if not inCombat then inCombat = true; Start("combat") end
    elseif event == "ENCOUNTER_START" then
        if not encounterStarted then encounterStarted = true; Start("encounter") end
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false; wipe(runs)
        -- Keep the encounter latch until ENCOUNTER_END to avoid duplicate starts.
    elseif event == "ENCOUNTER_END" then
        encounterStarted = false; wipe(runs)
    elseif event == "PLAYER_ENTERING_WORLD" then
        wipe(runs)
        inCombat = not not InCombatLockdown()
        encounterStarted = not not IsEncounterInProgress()
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
        local location = Custom.CaptureLocation()
        for id, run in pairs(runs) do if not Matches(run.source.location, location) then runs[id] = nil end end
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
                if entry.interval then
                    -- Skip missed occurrences after a hitch; never replay a burst of alerts.
                    local occurrence = math.floor((now - entry.firstEnd) / entry.interval) + 1
                    entry = { custom = true, customKey = entry.customKey, name = entry.name, icon = entry.icon,
                        duration = entry.interval, firstEnd = entry.firstEnd, interval = entry.interval,
                        ends = entry.firstEnd + occurrence * entry.interval, spoken = {},
                        color = entry.color, countdown = entry.countdown }
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
