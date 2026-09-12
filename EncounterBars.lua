local _, addon = ...
local Bars = {}
addon.EncounterBars = Bars
local events = CreateFrame("Frame")
local active, preview = false, false
local anchors, rows, timeline, timers = {}, {}, {}, {}
local oldTimelineAlpha, mutedPullEvents
local lastBreakSender, lastBreakSeconds, lastBreakTime
local elapsedSinceUpdate = 0
local styleVersion = 0
local loopRunning = false
local countdownSoundWarning = false
local TIMER_KINDS = { "pull", "break" }
local Refresh, UpdateLoop
local UpdateAliases
local function DB() return UIThingsDB and UIThingsDB.encounterBars end
local function Public(v) return not (issecretvalue and issecretvalue(v)) end
local function Number(v) return Public(v) and type(v) == "number" and v == v end
local function Tell(message) addon.Core.Log("EncounterBars", message, 1) end
local function FullName(unit)
    local name, realm = UnitFullName(unit)
    if not Public(name) or not Public(realm) or not name then return end
    if not realm or realm == "" then realm = GetNormalizedRealmName() end
    return name .. "-" .. realm
end

function Bars.GetBlocker()
    if C_AddOns.IsAddOnLoaded("BigWigs") or C_AddOns.IsAddOnLoaded("BigWigs_Core") then return "BigWigs is loaded" end
    if C_AddOns.IsAddOnLoaded("DBM-Core") then return "DBM is loaded" end
end
function Bars.IsActive() return active and not Bars.GetBlocker() end

local function NewAnchor(key, title)
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetMovable(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
    f:SetFrameStrata("MEDIUM")
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    f:SetBackdropColor(0.04, 0.07, 0.09, 0.9)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("CENTER"); f.title:SetText(title)
    f:SetScript("OnDragStart", function(self) if not DB().locked then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        DB()[key] = { point = point, x = x, y = y }
    end)
    anchors[key] = f
    return f
end

local function GetRow(index)
    if rows[index] then return rows[index] end
    local f = CreateFrame("StatusBar", nil, UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints()
    f.bg:SetColorTexture(0.04, 0.06, 0.08, 0.9)
    f.icon = f:CreateTexture(nil, "OVERLAY")
    f.icon:SetPoint("RIGHT", f, "LEFT", -4, 0); f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetJustifyH("LEFT"); f.text:SetWordWrap(false)
    f.time = f:CreateFontString(nil, "OVERLAY"); f.time:SetPoint("RIGHT", -5, 0)
    -- Fixed slots outside the bar: never inspect the API's secret icon alpha/atlas.
    f.indicators = {}
    for i = 1, 4 do
        f.indicators[i] = f:CreateTexture(nil, "OVERLAY")
    end
    f.flash = f:CreateTexture(nil, "OVERLAY")
    f.flash:SetAllPoints(); f.flash:SetColorTexture(1, 1, 1, 0.35); f.flash:Hide()
    rows[index] = f
    return f
end

local function Speak(entry, remaining, enabled)
    local second = math.ceil(remaining)
    if enabled and second >= 1 and second <= 5 and not entry.spoken[second] then
        entry.spoken[second] = true
        if DB().recordedCountdown then
            -- Play the current number directly; never queue or catch up missed numbers.
            local played = PlaySoundFile("Interface\\AddOns\\LunaUITweaks\\Sounds\\" .. second .. ".ogg", "Master")
            if not played and not countdownSoundWarning then
                countdownSoundWarning = true
                Tell("Countdown sound could not play. Check Sounds/1.ogg through 5.ogg and restart WoW after adding files.")
            end
        else addon.Core.SpeakTTS(tostring(second)) end
    end
end

local function Draw(entry, remaining, index, anchorKey, position, paused, suppressTransitions)
    local db = DB()
    local emphasized = anchorKey == "emphasizePos"
    local width = emphasized and db.emphasizeWidth or db.width
    local height = emphasized and db.emphasizeHeight or db.height
    local fontSize = emphasized and db.emphasizeFontSize or db.fontSize
    local f = GetRow(index)
    local restyle = f.styleVersion ~= styleVersion or f.anchorKey ~= anchorKey or f.position ~= position
    if restyle then
        f.styleVersion, f.anchorKey, f.position = styleVersion, anchorKey, position
        -- Configured width includes the icon; the fill occupies only the text lane.
        f:SetSize(width - height - 4, height)
        f:ClearAllPoints()
        local offset = (position - 1) * (height + db.spacing)
        local growUp = (emphasized and db.emphasizeGrowUp) or (not emphasized and db.growUp)
        if growUp then f:SetPoint("BOTTOMLEFT", anchors[anchorKey], "TOPLEFT", height + 4, offset)
        else f:SetPoint("TOPLEFT", anchors[anchorKey], "BOTTOMLEFT", height + 4, -offset) end
        f.icon:SetSize(height, height)
        f.text:SetFont(db.font, fontSize, "OUTLINE")
        f.time:SetFont(db.font, fontSize, "OUTLINE")
        f.text:ClearAllPoints(); f.text:SetPoint("LEFT", 5, 0)
        f.text:SetPoint("RIGHT", f.time, "LEFT", -6, 0)
        f.time:SetWidth(math.max(65, fontSize * 5))
        for i, texture in ipairs(f.indicators) do
            local size = height / 2
            texture:SetSize(size, size); texture:ClearAllPoints()
            texture:SetPoint("TOPLEFT", f, "TOPRIGHT", 4 + ((i - 1) % 2) * size, -math.floor((i - 1) / 2) * size)
        end
    end
    if f.entry ~= entry or restyle then
        for _, texture in ipairs(f.indicators) do texture:Hide(); texture:SetTexture(nil) end
        if db.indicators and entry.id and C_EncounterTimeline and C_EncounterTimeline.SetEventIconTextures then
            C_EncounterTimeline.SetEventIconTextures(entry.id, 1023, f.indicators)
            for _, texture in ipairs(f.indicators) do texture:Show() end
        end
    end
    if f.entry ~= entry then
        f.entry = entry
        -- Compare our own entry identity, never the secret names/icons.
        f.icon:SetTexture(entry.icon); f.text:SetText(entry.name)
    end
    if emphasized then
        if not entry.wasEmphasized or not entry.emphasizeDuration then
            entry.emphasizeDuration = math.max(0.001, remaining)
        end
    else entry.emphasizeDuration = nil end
    local range = emphasized and entry.emphasizeDuration or math.max(1, entry.duration)
    if f.range ~= range then f.range = range; f:SetMinMaxValues(0, range) end
    local second = math.ceil(math.max(0, remaining))
    local due = db.dueNow and not entry.kind and not paused and remaining <= 0
    if f.second ~= second or f.paused ~= paused or f.due ~= due then
        f.second, f.paused, f.due = second, paused, due
        f.time:SetText(paused and "Paused" or (due and "Due now") or string.format("%d:%02d", math.floor(second / 60), second % 60))
    end
    f:SetValue(due and range or math.max(0, remaining))
    -- Animate only public timing data between the throttled timeline samples.
    f.smoothEnds = GetTime() + math.max(0, remaining)
    f.smoothFill = emphasized and not paused and not due and not preview
    local color = (entry.custom and (entry.color or db.customColor)) or (due and db.dueNowColor) or (entry.kind and db.timerColor) or (emphasized and db.emphasizeColor)
        or (remaining <= 5 and db.urgentColor or db.color)
    f:SetStatusBarColor(color.r, color.g, color.b)
    -- Latch on the event, not a pooled row. Reordering/settings cannot replay alerts.
    if emphasized and entry.wasEmphasized == false and not entry.emphasisNotified
        and not paused and not preview and not suppressTransitions then
        entry.emphasisNotified = true
        if db.emphasizeGlow then entry.flashUntil = GetTime() + 0.8 end
        if db.emphasizeSound then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
    end
    entry.wasEmphasized = emphasized
    local flashRemaining = (entry.flashUntil or 0) - GetTime()
    f.flash:SetShown(emphasized and db.emphasizeGlow and flashRemaining > 0 and not preview)
    f.flash:SetAlpha(math.max(0, math.min(1, flashRemaining / 0.8)))
    f:Show()
    local countdown = entry.kind and db.timerCountdown or (not entry.kind and db.countdown)
    if entry.custom and entry.countdown ~= nil then countdown = entry.countdown end
    if not paused then Speak(entry, remaining, not preview and countdown) end
end

local function StopTimer(kind)
    timers[kind] = nil
    if kind == "break" and DB() then DB().runningBreak = nil end
end

local function SetTimer(kind, seconds, duration, silentStart)
    if not Number(seconds) or seconds < 0 or seconds > 3600 then return end
    if seconds == 0 then StopTimer(kind); Refresh(); return end
    local existing = timers[kind]
    if existing and math.abs(existing.ends - (GetTime() + seconds)) < 0.5
        and existing.duration == (duration or seconds) then return end
    timers[kind] = { kind = kind, name = kind == "pull" and "Pull" or "Break",
        icon = kind == "pull" and 132337 or 134062, duration = duration or seconds,
        ends = GetTime() + seconds, spoken = {} }
    if kind == "break" then
        DB().runningBreak = { character = FullName("player"),
            ends = time() + seconds, duration = duration or seconds }
    end
    if DB().timerStartSound and not silentStart and not preview then
        PlaySound(SOUNDKIT.RAID_WARNING, "Master")
    end
    UpdateLoop(); Refresh()
end

local function CollectTimeline()
    local previous = timeline
    timeline = {}
    if not active or not DB().timeline or not C_EncounterTimeline then return end
    for _, id in ipairs(C_EncounterTimeline.GetEventList()) do
        local info = C_EncounterTimeline.GetEventInfo(id)
        if info and Public(info.source) and info.source ~= Enum.EncounterTimelineEventSource.Script
            and Number(info.duration) then
            timeline[id] = previous[id] or { id = id, name = info.spellName, icon = info.iconFileID,
                duration = info.duration, spoken = {} }
        end
    end
end

Refresh = function(suppressTransitions)
    if not active then return end
    local list = {}
    if preview then
        for i = 1, 3 do
            list[i] = { name = "Example ability " .. i, icon = 136116, duration = 30,
                remaining = DB().emphasize and (i == 1 and DB().emphasizeThreshold / 2 or DB().emphasizeThreshold + i * 6)
                    or 6 * i, spoken = {} }
        end
    else
        for id, entry in pairs(timeline) do
            local state = C_EncounterTimeline.GetEventState(id)
            local remaining = C_EncounterTimeline.GetEventTimeRemaining(id)
            if state == Enum.EncounterTimelineEventState.Active or state == Enum.EncounterTimelineEventState.Paused then
                if Number(remaining) then
                    entry.remaining = remaining
                    entry.paused = state == Enum.EncounterTimelineEventState.Paused
                    if not DB().limitHorizon or remaining <= DB().horizon then
                        list[#list + 1] = entry
                    end
                end
            else timeline[id] = nil end
        end
        if addon.CustomEncounterTimers then addon.CustomEncounterTimers.Append(list, GetTime()) end
        table.sort(list, function(a, b)
            if a.remaining == b.remaining then
                if not not a.custom ~= not not b.custom then return not a.custom end
                return (a.customKey or a.id) < (b.customKey or b.id)
            end
            return a.remaining < b.remaining
        end)
    end
    local count = math.min(#list, DB().maxBars)
    local normalPosition, emphasizedPosition = 0, 0
    for i = 1, count do
        local entry = list[i]
        -- Route the same entry (and its spoken-countdown history), never clone it.
        if DB().emphasize and entry.remaining <= DB().emphasizeThreshold then
            emphasizedPosition = emphasizedPosition + 1
            Draw(entry, entry.remaining, i, "emphasizePos", emphasizedPosition, entry.paused, suppressTransitions)
        else
            normalPosition = normalPosition + 1
            Draw(entry, entry.remaining, i, "encounterPos", normalPosition, entry.paused, suppressTransitions)
        end
    end
    local position = 0
    for _, kind in ipairs(TIMER_KINDS) do
        local entry = timers[kind]
        if entry then
            local remaining = entry.ends - GetTime()
            if remaining <= 0 then
                StopTimer(kind)
                if DB().timerCountdown and not preview then addon.Core.SpeakTTS(kind == "pull" and "Pull" or "Break finished") end
            else
                position = position + 1; count = count + 1
                Draw(entry, remaining, count, "timerPos", position)
            end
        end
    end
    for i = count + 1, #rows do rows[i]:Hide() end
    UpdateLoop()
end

UpdateLoop = function()
    local running = active and (next(timeline) ~= nil or next(timers) ~= nil
        or (addon.CustomEncounterTimers and addon.CustomEncounterTimers.HasTimers())) or false
    if running == loopRunning then return end
    loopRunning = running
    if running then
        events:SetScript("OnUpdate", function(_, elapsed)
            elapsedSinceUpdate = elapsedSinceUpdate + elapsed
            if elapsedSinceUpdate >= 0.1 then
                elapsedSinceUpdate = 0
                Refresh()
            end
            if preview then return end
            local now = GetTime()
            for _, row in ipairs(rows) do
                if row:IsShown() and row.anchorKey == "emphasizePos" then
                    if row.smoothFill then row:SetValue(math.max(0, row.smoothEnds - now)) end
                    if row.entry.flashUntil and DB().emphasizeGlow then
                        local remaining = row.entry.flashUntil - now
                        row.flash:SetShown(remaining > 0)
                        row.flash:SetAlpha(math.max(0, math.min(1, remaining / 0.8)))
                    end
                end
            end
        end)
    else events:SetScript("OnUpdate", nil) end
end

-- Only suppress the UI we replace; restore its state when disabled.
local function BlizzardDisplay()
    if EncounterTimeline then
        if active and DB().timeline and DB().hideTimeline then
            if oldTimelineAlpha == nil then oldTimelineAlpha = EncounterTimeline:GetAlpha() end
            EncounterTimeline:SetAlpha(0)
        elseif oldTimelineAlpha ~= nil then
            EncounterTimeline:SetAlpha(oldTimelineAlpha); oldTimelineAlpha = nil
        end
    end
    if TimerTracker then
        if active and DB().pulls then
            if not mutedPullEvents then
                mutedPullEvents = {}
                for _, event in ipairs({ "START_PLAYER_COUNTDOWN", "CANCEL_PLAYER_COUNTDOWN" }) do
                    mutedPullEvents[event] = TimerTracker:IsEventRegistered(event)
                    TimerTracker:UnregisterEvent(event)
                end
                -- Enabling mid-countdown must not leave the old visual/sounds running.
                if TimerTracker.timerList and FreeTimerTrackerTimer then
                    for _, timer in pairs(TimerTracker.timerList) do
                        if Public(timer.type) and timer.type == Enum.StartTimerType.PlayerCountdown and not timer.isFree then
                            FreeTimerTrackerTimer(timer); timer:Hide()
                        end
                    end
                end
            end
        elseif mutedPullEvents then
            for event, wasRegistered in pairs(mutedPullEvents) do
                if wasRegistered and not Bars.GetBlocker() then TimerTracker:RegisterEvent(event) end
            end
            mutedPullEvents = nil
        end
    end
end

function Bars.UpdateSettings()
    styleVersion = styleVersion + 1
    active = DB() and DB().enabled and not Bars.GetBlocker() or false
    if addon.CustomEncounterTimers then addon.CustomEncounterTimers.Configure(active) end
    UpdateAliases()
    events:UnregisterAllEvents()
    events:RegisterEvent("PLAYER_LOGIN"); events:RegisterEvent("ADDON_LOADED")
    if not active then
        preview = false; wipe(timeline); wipe(timers)
        if DB() then DB().runningBreak = nil end
        for _, f in pairs(anchors) do f:Hide() end
        for _, f in ipairs(rows) do f:Hide() end
        events:SetScript("OnUpdate", nil)
        loopRunning = false
        BlizzardDisplay()
        return
    end
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ENCOUNTER_START", "GROUP_ROSTER_UPDATE",
        "START_PLAYER_COUNTDOWN", "CANCEL_PLAYER_COUNTDOWN", "CHAT_MSG_ADDON", "ENCOUNTER_END",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
        "ZONE_CHANGED_NEW_AREA" }) do events:RegisterEvent(event) end
    if C_EncounterTimeline then
        for _, event in ipairs({ "ENCOUNTER_TIMELINE_EVENT_ADDED", "ENCOUNTER_TIMELINE_EVENT_REMOVED",
            "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", "ENCOUNTER_TIMELINE_VIEW_ACTIVATED",
            "ENCOUNTER_TIMELINE_VIEW_DEACTIVATED" }) do events:RegisterEvent(event) end
    end
    C_ChatInfo.RegisterAddonMessagePrefix("BigWigs")
    C_ChatInfo.RegisterAddonMessagePrefix("D5")
    for key, label in pairs({ encounterPos = "Encounter bars — drag to move", timerPos = "Pull / break timers — drag to move",
        emphasizePos = "Emphasized bars — drag to move" }) do
        local f = anchors[key] or NewAnchor(key, label)
        local pos = DB()[key]
        f:ClearAllPoints(); f:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
        f:SetSize(key == "emphasizePos" and DB().emphasizeWidth or DB().width, DB().locked and 1 or 24)
        f:EnableMouse(not DB().locked); f.title:SetShown(not DB().locked)
        f:SetBackdropColor(0.04, 0.07, 0.09, DB().locked and 0 or 0.9); f:Show()
        if key == "emphasizePos" and not DB().emphasize then f:Hide() end
    end
    if not DB().pulls then StopTimer("pull") end
    if not DB().breaks then StopTimer("break") end
    local saved = DB().runningBreak
    if DB().breaks and not timers["break"] and saved and saved.character == FullName("player")
        and Number(saved.ends) and Number(saved.duration) then
        local remaining = saved.ends - time()
        if remaining > 0 and remaining <= 3600 then SetTimer("break", remaining, saved.duration, true)
        else DB().runningBreak = nil end
    end
    BlizzardDisplay(); CollectTimeline(); Refresh(true)
end

function Bars.TogglePreview()
    if not Bars.IsActive() then Tell(Bars.GetBlocker() or "Enable Encounter Bars & Timers first."); return end
    if IsEncounterInProgress() or (InCombatLockdown and InCombatLockdown()) then Tell("Preview is unavailable during combat or an encounter."); return end
    preview = not preview; Refresh(true)
end
function Bars.ClosePreview() preview = false; if active then Refresh(true) end end

local function CanStart()
    return not IsInGroup() or UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end
function Bars.StartPull(seconds)
    if not Bars.IsActive() or not DB().pulls then return false end
    seconds = tonumber(seconds) or DB().pullSeconds
    if not Number(seconds) or seconds < 0 or seconds > 60 then Tell("Pull must be 0–60 seconds."); return false end
    if not CanStart() or IsEncounterInProgress() then Tell("Pull requires leader/assistant and no active encounter."); return false end
    if IsInGroup() then return C_PartyInfo.DoCountdown(seconds) end
    SetTimer("pull", seconds)
    return true
end
function Bars.GetPullRemaining()
    if Bars.IsActive() and timers.pull then return math.max(0, timers.pull.ends - GetTime()) end
end

local function ApplyBreak(seconds, sender)
    if not Number(seconds) or seconds < 0 or seconds > 3600 or (seconds > 0 and seconds < 60)
        or IsEncounterInProgress() then return end
    if sender == lastBreakSender and seconds == lastBreakSeconds and GetTime() - (lastBreakTime or 0) < 1 then return end
    lastBreakSender, lastBreakSeconds, lastBreakTime = sender, seconds, GetTime()
    SetTimer("break", seconds)
end
function Bars.StartBreak(minutes)
    if not Bars.IsActive() or not DB().breaks then return false end
    minutes = tonumber(minutes) or DB().breakMinutes
    if not Number(minutes) or minutes < 0 or minutes > 60 or (minutes > 0 and minutes < 1) then
        Tell("Break must be 1–60 minutes, or 0 to cancel."); return false
    end
    if not CanStart() or IsEncounterInProgress() then Tell("Break requires leader/assistant and no active encounter."); return false end
    local seconds = math.floor(minutes * 60)
    local name = FullName("player")
    if not name then return false end
    ApplyBreak(seconds, name)
    if IsInGroup() then
        local channel = IsInGroup(2) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY")
        local bw = C_ChatInfo.SendAddonMessage("BigWigs", "P^Break^" .. seconds, channel)
        local dbm = C_ChatInfo.SendAddonMessage("D5", name .. "\t1\tBT\t" .. seconds, channel)
        if (Number(bw) and bw ~= 0) or (Number(dbm) and dbm ~= 0) then
            Tell("Break timer updated locally, but a group broadcast failed.")
        end
    end
    return true
end

local function TrustedSender(sender)
    if not Public(sender) then return false end
    for i = 0, GetNumGroupMembers() do
        local unit = i == 0 and "player" or (IsInRaid() and "raid" .. i or "party" .. i)
        local name = FullName(unit)
        if name and name == sender then
            return UnitIsUnit(unit, "player") or UnitIsGroupLeader(unit) or UnitIsGroupAssistant(unit)
        end
    end
    return false
end

events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then Bars.UpdateSettings(); return end
    if event == "ADDON_LOADED" then
        local name = ...
        if DB() and (active or DB().enabled) and (Bars.GetBlocker()
            or name == "Blizzard_EncounterTimeline" or name == "Blizzard_TimerTracker") then Bars.UpdateSettings() end
        if active and DB().shortCommands then UpdateAliases() end
        return
    end
    if not Bars.IsActive() then Bars.UpdateSettings(); return end
    if addon.CustomEncounterTimers then addon.CustomEncounterTimers.OnEvent(event) end
    if event == "PLAYER_ENTERING_WORLD" then Bars.UpdateSettings()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or event == "ENCOUNTER_END"
        or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
        if event == "PLAYER_REGEN_DISABLED" then preview = false end
        Refresh()
    elseif event == "ENCOUNTER_START" then
        preview = false; StopTimer("pull"); StopTimer("break"); Refresh()
    elseif event == "GROUP_ROSTER_UPDATE" then
        if not IsInGroup() then StopTimer("pull"); StopTimer("break"); Refresh() end
    elseif event == "START_PLAYER_COUNTDOWN" and DB().pulls then
        local _, seconds, duration = ...
        if not IsEncounterInProgress() and Number(duration) then SetTimer("pull", seconds, duration) end
    elseif event == "CANCEL_PLAYER_COUNTDOWN" then StopTimer("pull"); Refresh()
    elseif event == "CHAT_MSG_ADDON" and DB().breaks then
        local prefix, message, channel, sender = ...
        if (channel ~= "PARTY" and channel ~= "RAID" and channel ~= "INSTANCE_CHAT")
            or not Public(message) or not TrustedSender(sender) then return end
        local seconds
        if prefix == "BigWigs" then seconds = tonumber(message:match("^P%^Break%^(%d+)$"))
        elseif prefix == "D5" then seconds = tonumber(message:match("^[^\t]+\t%d+\tBT\t(%d+)$")) end
        if seconds then ApplyBreak(seconds, sender) end
    elseif DB().timeline and C_EncounterTimeline then
        if event == "ENCOUNTER_TIMELINE_VIEW_DEACTIVATED" then wipe(timeline)
        elseif event == "ENCOUNTER_TIMELINE_VIEW_ACTIVATED" then CollectTimeline()
        elseif event == "ENCOUNTER_TIMELINE_EVENT_ADDED" then
            local info = ...
            if info and Public(info.source) and info.source ~= Enum.EncounterTimelineEventSource.Script and Number(info.duration) then
                timeline[info.id] = timeline[info.id] or { id = info.id, name = info.spellName, icon = info.iconFileID,
                    duration = info.duration, spoken = {} }
            end
        elseif event == "ENCOUNTER_TIMELINE_EVENT_REMOVED" then local id = ...; timeline[id] = nil end
        Refresh()
    end
end)
events:RegisterEvent("PLAYER_LOGIN"); events:RegisterEvent("ADDON_LOADED")
SLASH_LUNAENCOUNTERPULL1 = "/lunapull"
SlashCmdList.LUNAENCOUNTERPULL = function(input)
    if input ~= "" and input ~= "cancel" and not tonumber(input) then Tell("Usage: /lunapull [seconds|cancel]"); return end
    if not Bars.StartPull(input == "cancel" and 0 or tonumber(input)) then Tell(Bars.GetBlocker() or "Pull timers are disabled or the request was rejected.") end
end
SLASH_LUNAENCOUNTERBREAK1 = "/lunabreak"
SlashCmdList.LUNAENCOUNTERBREAK = function(input)
    if input ~= "" and input ~= "cancel" and not tonumber(input) then Tell("Usage: /lunabreak [minutes|cancel]"); return end
    if not Bars.StartBreak(input == "cancel" and 0 or tonumber(input)) then Tell(Bars.GetBlocker() or "Break timers are disabled or the request was rejected.") end
end

-- Separate registrations allow removing aliases without touching /luna commands.
-- WoW imports slash handlers into a cache/proxy; remove only entries we own.
local aliases = {
    { key = "LUNAENCOUNTERPULLSHORT", command = "/pull", setting = "pulls",
        handler = SlashCmdList.LUNAENCOUNTERPULL },
    { key = "LUNAENCOUNTERBREAKSHORT", command = "/break", setting = "breaks",
        handler = SlashCmdList.LUNAENCOUNTERBREAK },
}
UpdateAliases = function()
    for _, alias in ipairs(aliases) do
        local global = "SLASH_" .. alias.key .. "1"
        local upper = alias.command:upper()
        local wanted = active and DB().shortCommands and DB()[alias.setting]
        if wanted then
            -- Include pending and already-imported registrations, not just the cache.
            for key, value in pairs(_G) do
                if type(key) == "string" and key ~= global and key:match("^SLASH_.+%d+$")
                    and Public(value) and type(value) == "string" and value:upper() == upper then
                    wanted = false; break
                end
            end
            if hash_SlashCmdList and hash_SlashCmdList[upper] and hash_SlashCmdList[upper] ~= alias.handler then wanted = false end
        end
        if wanted then
            _G[global] = alias.command
            if SlashCmdList[alias.key] ~= alias.handler then SlashCmdList[alias.key] = alias.handler end
        else
            if _G[global] == alias.command then _G[global] = nil end
            if SlashCmdList[alias.key] == alias.handler then SlashCmdList[alias.key] = nil end
            local meta = getmetatable(SlashCmdList)
            local proxy = meta and meta.__index
            if type(proxy) == "table" and proxy[alias.key] == alias.handler then proxy[alias.key] = nil end
            if hash_SlashCmdList and hash_SlashCmdList[upper] == alias.handler then hash_SlashCmdList[upper] = nil end
            if hash_ChatTypeInfoList and hash_ChatTypeInfoList[upper] == alias.key then hash_ChatTypeInfoList[upper] = nil end
        end
    end
end
