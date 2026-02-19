-- EventBus.lua
-- Single-frame centralized event dispatcher for LunaUITweaks.
-- Load order: after Core.lua, before all feature modules.

local addonName, addonTable = ...
addonTable.EventBus = {}
local EventBus = addonTable.EventBus

-- listeners[eventName] = { callback, callback, ... }
local listeners = {}

local busFrame = CreateFrame("Frame", "LunaUITweaks_EventBus")
busFrame:SetScript("OnEvent", function(_, event, ...)
    local subs = listeners[event]
    if not subs then return end
    -- Copy to a local array before iterating so that callbacks which
    -- unregister themselves mid-dispatch don't shift indices and skip entries.
    local n = #subs
    local snapshot = {}
    for i = 1, n do snapshot[i] = subs[i] end
    for i = 1, n do
        local cb = snapshot[i]
        if cb then cb(event, ...) end
    end
end)

--- Subscribe to a WoW event.
-- @param event string   WoW event name e.g. "PLAYER_ENTERING_WORLD"
-- @param callback function  Called as callback(event, ...) when event fires
function EventBus.Register(event, callback)
    if not listeners[event] then
        listeners[event] = {}
        busFrame:RegisterEvent(event)
    end
    local subs = listeners[event]
    for i = 1, #subs do
        if subs[i] == callback then return end
    end
    subs[#subs + 1] = callback
end

--- Unsubscribe a specific callback from an event.
-- Uses reference equality. Removes at most one entry per call.
-- @param event string
-- @param callback function  Must be the same function reference passed to Register
function EventBus.Unregister(event, callback)
    local subs = listeners[event]
    if not subs then return end
    for i = #subs, 1, -1 do
        if subs[i] == callback then
            table.remove(subs, i)
            break
        end
    end
    if #subs == 0 then
        listeners[event] = nil
        busFrame:UnregisterEvent(event)
    end
end

--- Subscribe to a unit event with automatic unit filtering.
-- Wraps the callback so it only fires when the event is for the given unit.
-- @param event string
-- @param unit string  e.g. "player", "party1"
-- @param callback function  Called as callback(event, unit, ...)
-- @return function  The wrapper function — store this reference to Unregister later
function EventBus.RegisterUnit(event, unit, callback)
    local function wrapper(ev, unitTarget, ...)
        if unitTarget == unit then
            callback(ev, unitTarget, ...)
        end
    end
    EventBus.Register(event, wrapper)
    return wrapper
end
