-- EventBus.lua
-- Single-frame centralized event dispatcher for LunaUITweaks.
-- Load order: after Core.lua, before all feature modules.

local addonName, addonTable = ...
addonTable.EventBus = {}
local EventBus = addonTable.EventBus

-- listeners[eventName] = { { original = func, cb = func }, ... }
local listeners = {}

-- Track dispatching state to avoid compacting arrays while iterating
local dispatching = {}
local needsCompaction = {}

local busFrame = CreateFrame("Frame", "LunaUITweaks_EventBus")

local function Compact(event)
    local subs = listeners[event]
    if not subs then return end

    local j = 0
    for i = 1, #subs do
        if subs[i] then
            j = j + 1
            subs[j] = subs[i]
        end
    end
    for i = j + 1, #subs do subs[i] = nil end

    if j == 0 then
        listeners[event] = nil
        busFrame:UnregisterEvent(event)
    end
end

busFrame:SetScript("OnEvent", function(_, event, ...)
    local subs = listeners[event]
    if not subs then return end

    dispatching[event] = (dispatching[event] or 0) + 1

    for i = 1, #subs do
        local sub = subs[i]
        if sub then
            -- One broken feature must not prevent later listeners from running or
            -- leave the dispatch depth permanently elevated. WoW's error handler
            -- reports the original callback failure without rethrowing it through
            -- the dispatcher.
            xpcall(sub.cb, geterrorhandler(), event, ...)
        end
    end

    local depth = dispatching[event] - 1
    dispatching[event] = depth ~= 0 and depth or nil

    if not dispatching[event] and needsCompaction[event] then
        needsCompaction[event] = nil
        Compact(event)
    end
end)

--- Subscribe to a WoW event.
-- @param event string   WoW event name e.g. "PLAYER_ENTERING_WORLD"
-- @param callback function  Called as callback(event, ...) when event fires
-- @param moduleName string  Optional module name for profiling
-- @param originalRef function Optional original function reference if wrapped externally
-- @return function  The callback that was actually registered
function EventBus.Register(event, callback, moduleName, originalRef)
    local original = originalRef or callback

    if moduleName and addonTable.Profiler then
        callback = addonTable.Profiler.WrapCallback(moduleName, callback)
    end

    if not listeners[event] then
        listeners[event] = {}
        busFrame:RegisterEvent(event)
    end

    local subs = listeners[event]
    for i = 1, #subs do
        local sub = subs[i]
        if sub and sub.original == original then
            return sub.cb
        end
    end

    subs[#subs + 1] = { original = original, cb = callback, moduleName = moduleName }
    return callback
end

-- Defined in the unit-filtered section below.
local RemoveFromUnitChannels

--- Unsubscribe a specific callback from an event.
-- @param event string
-- @param callback function  The original function reference passed to Register
function EventBus.Unregister(event, callback)
    -- Also drop unit-filtered registrations of this callback, so either
    -- unregister call removes it.
    RemoveFromUnitChannels(event, nil, callback)

    local subs = listeners[event]
    if not subs then return end

    local found = false
    for i = 1, #subs do
        local sub = subs[i]
        if sub and sub.original == callback then
            subs[i] = false
            found = true
        end
    end

    if found then
        if not dispatching[event] then
            Compact(event)
        else
            needsCompaction[event] = true
        end
    end
end

-- ============================================================
-- Unit-filtered events
-- Once any module subscribes on the shared bus frame, it receives that event
-- for every unit (all nameplates, all raid members). For unit events, each
-- (event, unit) pair gets its own frame using RegisterUnitEvent, so the client
-- only delivers the requested units. Dispatch matches the shared bus: xpcall
-- per subscriber, dedupe by original callback, removal safe during dispatch.
-- ============================================================

-- unitChannels[event][unit] = { frame, event, unit, subs, depth, registered, needsCompaction }
local unitChannels = {}

local function CompactUnitChannel(channel)
    local subs = channel.subs
    local j = 0
    for i = 1, #subs do
        if subs[i] then
            j = j + 1
            subs[j] = subs[i]
        end
    end
    for i = j + 1, #subs do subs[i] = nil end

    -- Frames cannot be destroyed; keep the channel and reuse it later.
    if j == 0 and channel.registered then
        channel.frame:UnregisterEvent(channel.event)
        channel.registered = false
    end
end

local function DispatchUnitChannel(channel, event, ...)
    local subs = channel.subs
    channel.depth = channel.depth + 1
    for i = 1, #subs do
        local sub = subs[i]
        if sub then
            xpcall(sub.cb, geterrorhandler(), event, ...)
        end
    end
    channel.depth = channel.depth - 1

    if channel.depth == 0 and channel.needsCompaction then
        channel.needsCompaction = false
        CompactUnitChannel(channel)
    end
end

local function GetUnitChannel(event, unit)
    local byUnit = unitChannels[event]
    if not byUnit then
        byUnit = {}
        unitChannels[event] = byUnit
    end
    local channel = byUnit[unit]
    if not channel then
        channel = { event = event, unit = unit, subs = {}, depth = 0, registered = false }
        channel.frame = CreateFrame("Frame")
        channel.frame:SetScript("OnEvent", function(_, ev, ...)
            DispatchUnitChannel(channel, ev, ...)
        end)
        byUnit[unit] = channel
    end
    return channel
end

local function RemoveFromChannel(channel, callback)
    local subs = channel.subs
    local found = false
    for i = 1, #subs do
        local sub = subs[i]
        if sub and sub.original == callback then
            subs[i] = false
            found = true
        end
    end
    if found then
        if channel.depth == 0 then
            CompactUnitChannel(channel)
        else
            channel.needsCompaction = true
        end
    end
end

-- units: a unit token, an array of tokens, or nil for every unit of the event.
RemoveFromUnitChannels = function(event, units, callback)
    local byUnit = unitChannels[event]
    if not byUnit then return end
    if units == nil then
        for _, channel in pairs(byUnit) do RemoveFromChannel(channel, callback) end
    elseif type(units) == "table" then
        for i = 1, #units do
            local channel = byUnit[units[i]]
            if channel then RemoveFromChannel(channel, callback) end
        end
    else
        local channel = byUnit[units]
        if channel then RemoveFromChannel(channel, callback) end
    end
end

--- Subscribe to a unit event for specific units only.
-- Use instead of Register for UNIT_* events that are only needed for a few
-- units (e.g. "player"); the shared bus would otherwise receive every unit.
-- @param event string   e.g. "UNIT_AURA"
-- @param units string|table  a unit token or an array of tokens
-- @param callback function  Called as callback(event, unit, ...)
-- @param moduleName string  Optional module name for profiling
function EventBus.RegisterUnitEvent(event, units, callback, moduleName)
    local cb = callback
    if moduleName and addonTable.Profiler then
        cb = addonTable.Profiler.WrapCallback(moduleName, callback)
    end

    local list = type(units) == "table" and units or { units }
    for i = 1, #list do
        local unit = list[i]
        assert(type(unit) == "string", "EventBus.RegisterUnitEvent: unit must be a string")
        local channel = GetUnitChannel(event, unit)
        local subs = channel.subs
        local exists = false
        for j = 1, #subs do
            local sub = subs[j]
            if sub and sub.original == callback then
                exists = true
                break
            end
        end
        if not exists then
            subs[#subs + 1] = { original = callback, cb = cb, moduleName = moduleName }
        end
        if not channel.registered then
            channel.frame:RegisterUnitEvent(event, unit)
            channel.registered = true
        end
    end
end

--- Unsubscribe from unit-filtered registrations.
-- @param units string|table|nil  tokens to remove; nil removes all units
function EventBus.UnregisterUnitEvent(event, units, callback)
    RemoveFromUnitChannels(event, units, callback)
end

--- Subscribe to a unit event for a single unit (compatibility wrapper).
-- Delegates to RegisterUnitEvent; unregister with UnregisterUnitEvent or
-- Unregister using the same callback.
-- @return function  The callback passed in
function EventBus.RegisterUnit(event, unit, callback, moduleName)
    EventBus.RegisterUnitEvent(event, unit, callback, moduleName)
    return callback
end
