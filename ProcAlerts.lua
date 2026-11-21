local _, addon = ...
local Proc = {}
addon.ProcAlerts = Proc
local bus = addon.EventBus
local rules, active, lastPlayed, observed = {}, {}, {}, {}
-- Screen-edge proc art (SpellActivationOverlay), e.g. Heating Up at 3 stacks on
-- Forever. Tracked apart from button glows: its spell ID is usually the aura,
-- and a HIDE without an ID clears every overlay.
local overlays = {}
local EVENTS = { "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
    "SPELL_ACTIVATION_OVERLAY_SHOW", "SPELL_ACTIVATION_OVERLAY_HIDE" }
local function Valid(event)
    return not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event)
end
local registered, listening, learnTimer = false, false, nil
local function DB() return UIThingsDB and UIThingsDB.procAlerts end
local Public = addon.Secret.IsPublic
local function ValidID(value) return Public(value) and type(value) == "number" and value > 0 and value <= 2147483647 and value == math.floor(value) end
local function PersistObserved()
    local db = DB()
    if not db or InCombatLockdown() then return end
    db.discovered = db.discovered or {}
    for id in pairs(observed) do db.discovered[id] = true end
end
function Proc.GetDiscovered()
    local found, result = {}, {}
    for id in pairs((DB() and DB().discovered) or {}) do if ValidID(id) then found[id] = true end end
    for id in pairs(observed) do found[id] = true end
    for id in pairs(found) do result[#result + 1] = id end
    table.sort(result)
    return result
end
function Proc.IsListening() return listening end
local SyncEvents
local function OnGlow(event, spellID)
    if event == "SPELL_ACTIVATION_OVERLAY_HIDE" and Public(spellID) and spellID == nil then
        wipe(overlays)
        return
    end
    -- Check accessibility before comparing, formatting, or using an ID as a key.
    if not ValidID(spellID) then return end
    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        active[spellID] = nil
        return
    end
    if event == "SPELL_ACTIVATION_OVERLAY_HIDE" then
        overlays[spellID] = nil
        return
    end
    if listening then
        observed[spellID] = true
        PersistObserved()
    end
    local db, rule = DB(), rules[spellID]
    if not db or not db.enabled or not rule then return end
    local up = event == "SPELL_ACTIVATION_OVERLAY_SHOW" and overlays or active
    if up[spellID] then return end
    up[spellID] = true
    if db.combatOnly and not InCombatLockdown() then return end
    local now = GetTime()
    if lastPlayed[spellID] and now - lastPlayed[spellID] < 0.15 then return end
    local sound = addon.BuffAlerts.ResolveSound(rule.sound)
    if sound then
        local ok, played = pcall(PlaySoundFile, sound, db.outputChannel or "Master")
        if ok and played then lastPlayed[spellID] = now end
    end
end
SyncEvents = function()
    local needed = listening or (DB() and DB().enabled and next(rules) ~= nil)
    if needed and not registered then
        for _, event in ipairs(EVENTS) do
            if Valid(event) then bus.Register(event, OnGlow, "ProcAlerts") end
        end
        registered = true
    elseif not needed and registered then
        for _, event in ipairs(EVENTS) do
            if Valid(event) then bus.Unregister(event, OnGlow) end
        end
        registered = false
        wipe(active)
        wipe(overlays)
        wipe(lastPlayed)
    end
end
function Proc.UpdateSettings()
    rules = {}
    for _, rule in ipairs((DB() and DB().rules) or {}) do
        if rule.enabled ~= false and ValidID(rule.spellID) then rules[rule.spellID] = rule end
    end
    PersistObserved()
    SyncEvents()
end
function Proc.SetListening(value)
    listening = not not value
    if learnTimer then
        learnTimer:Cancel()
        learnTimer = nil
    end
    if listening then
        learnTimer = C_Timer.NewTimer(600, function()
            learnTimer = nil
            Proc.SetListening(false)
        end)
    else PersistObserved() end
    SyncEvents()
    if Proc.OnListeningChanged then Proc.OnListeningChanged(listening) end
end
function Proc.SaveRule(spellID, sound, enabled)
    if not ValidID(spellID) then return false, "Enter a valid spell ID." end
    if not addon.BuffAlerts.ResolveSound(sound) then return false, "Choose a sound first." end
    local db = DB()
    if not db then return false, "Proc Alerts settings are unavailable." end
    db.rules = db.rules or {}
    for _, rule in ipairs(db.rules) do
        if rule.spellID == spellID then
            rule.sound = {preset = sound.preset}
            rule.enabled = not not enabled
            Proc.UpdateSettings()
            return true
        end
    end
    db.rules[#db.rules + 1] = {spellID = spellID, sound = {preset = sound.preset}, enabled = not not enabled}
    Proc.UpdateSettings()
    return true
end
function Proc.RemoveRule(spellID)
    for i, rule in ipairs((DB() and DB().rules) or {}) do
        if rule.spellID == spellID then
            table.remove(DB().rules, i)
            break
        end
    end
    active[spellID] = nil
    overlays[spellID] = nil
    lastPlayed[spellID] = nil
    Proc.UpdateSettings()
end
function Proc.TestSound(sound)
    local file = addon.BuffAlerts.ResolveSound(sound)
    if not file then return false, "Choose a valid sound first." end
    local ok, played = pcall(PlaySoundFile, file, (DB() and DB().outputChannel) or "Master")
    return ok and not not played, (not ok or not played) and "Sound could not be played. New files require a client restart." or nil
end
bus.Register("PLAYER_LOGIN", Proc.UpdateSettings, "ProcAlerts")
bus.Register("PLAYER_REGEN_ENABLED", PersistObserved, "ProcAlerts")
bus.Register("PLAYER_LOGOUT", PersistObserved, "ProcAlerts")
bus.Register("PLAYER_ENTERING_WORLD", function()
    wipe(active)
    wipe(overlays)
    wipe(lastPlayed)
end, "ProcAlerts")
bus.Register("PLAYER_SPECIALIZATION_CHANGED", function(_, unit)
    if Public(unit) and unit == "player" then
        wipe(active)
        wipe(overlays)
        wipe(lastPlayed)
        Proc.UpdateSettings()
    end
end, "ProcAlerts")
-- Use the existing panel registration API so no fixed navigation IDs need shifting.
LunaUITweaksAPI.RegisterConfigPanel("procAlerts", "Proc Alerts", "Interface\\Icons\\Spell_Nature_Lightning", function(...)
    addon.ConfigSetup.ProcAlerts(...)
end)
