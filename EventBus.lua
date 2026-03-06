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
            sub.cb(event, ...)
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

    subs[#subs + 1] = { original = original, cb = callback }
    return callback
end

--- Unsubscribe a specific callback from an event.
-- @param event string
-- @param callback function  The original function reference passed to Register
function EventBus.Unregister(event, callback)
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

--- Subscribe to a unit event with automatic unit filtering.
-- @param event string
-- @param unit string  e.g. "player", "party1"
-- @param callback function  Called as callback(event, unit, ...)
-- @return function  The wrapper function
function EventBus.RegisterUnit(event, unit, callback, moduleName)
    local function wrapper(ev, unitTarget, ...)
        if unitTarget == unit then
            callback(ev, unitTarget, ...)
        end
    end
    EventBus.Register(event, wrapper, moduleName, callback)
    return wrapper
end
