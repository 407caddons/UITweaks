local addonName, addonTable = ...
local Comm = {}
addonTable.Comm = Comm

-- == CONSTANTS ==

local ADDON_PREFIX = "LunaUI"
local LEGACY_PREFIXES = {
    LunaVer = true,
    LunaKick = true,
}

local MIN_SEND_INTERVAL = 1.0 -- seconds between sends per module:action
local DEDUP_WINDOW = 1.0      -- seconds to ignore duplicate messages from same sender

-- Modules exempt from rate limiting (high-frequency game sync)
local RATE_LIMIT_EXEMPT = {
    GAME = true,
}

-- == STATE ==

-- Handler registry: handlers[module][action] = callback(senderShort, payload, senderFull)
local handlers = {}

-- Throttle timers: throttleTimers[key] = C_Timer handle
local throttleTimers = {}

-- Rate limiting: lastSendTime["module:action"] = GetTime()
local lastSendTime = {}

-- Dedup tracking: recentMessages["sender:module:action"] = GetTime()
local recentMessages = {}

-- == PUBLIC API ==

--- Register a handler for a module:action pair
-- @param module string  Module namespace (e.g., "VER", "KICK")
-- @param action string  Action name (e.g., "HELLO", "CD", "SPELLS")
-- @param callback function  function(senderShort, payload, senderFull)
function Comm.Register(module, action, callback)
    handlers[module] = handlers[module] or {}
    handlers[module][action] = callback
end

--- Check if communication is allowed (in group and not hidden)
-- @return boolean
function Comm.IsAllowed()
    if not IsInGroup() then return false end
    if UIThingsDB and UIThingsDB.addonComm and UIThingsDB.addonComm.hideFromWorld then return false end
    return true
end

--- Get the channel to use for group communication
-- @return string|nil  "RAID", "PARTY", or nil if not in group
function Comm.GetChannel()
    if not IsInGroup() then return nil end
    return IsInRaid() and "RAID" or "PARTY"
end

--- Send a message to the group
-- @param module string       Module namespace
-- @param action string       Action name
-- @param payload string      Message payload
-- @param legacyPrefix string Optional legacy prefix for backwards compat
-- @param legacyMessage string Optional legacy message body
-- @return boolean  true if sent, false if suppressed
function Comm.Send(module, action, payload, legacyPrefix, legacyMessage)
    if not Comm.IsAllowed() then return false end
    local channel = Comm.GetChannel()
    if not channel then return false end

    -- Rate limit per module:action (exempt modules bypass this check)
    local key = module .. ":" .. action
    local now = GetTime()
    if not RATE_LIMIT_EXEMPT[module] then
        if lastSendTime[key] and (now - lastSendTime[key]) < MIN_SEND_INTERVAL then
            return false
        end
        lastSendTime[key] = now
    end

    -- Build and send new format: "MODULE:ACTION:PAYLOAD"
    local message = module .. ":" .. action
    if payload and payload ~= "" then
        message = message .. ":" .. payload
    end

    local lockdown = C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
    addonTable.Core.Log("Comm",
        string.format("SEND [%s] on %s: %s (lockdown=%s)", ADDON_PREFIX, channel, message, tostring(lockdown)), 0)
    local ok = C_ChatInfo.SendAddonMessage(ADDON_PREFIX, message, channel)
    if not ok then
        addonTable.Core.Log("Comm", "  -> SendAddonMessage returned false!", 2)
    end

    -- Legacy compat send
    if legacyPrefix and legacyMessage then
        addonTable.Core.Log("Comm", string.format("SEND [%s] on %s: %s (legacy)", legacyPrefix, channel, legacyMessage),
            0)
        local okLegacy = C_ChatInfo.SendAddonMessage(legacyPrefix, legacyMessage, channel)
        if not okLegacy then
            addonTable.Core.Log("Comm", "  -> Legacy SendAddonMessage returned false!", 2)
        end
    end

    return true
end

--- Schedule a throttled broadcast (cancels any pending one for the same key)
-- @param key string    Unique key for this broadcast type
-- @param delay number  Delay in seconds
-- @param func function The function to call after delay
function Comm.ScheduleThrottled(key, delay, func)
    if throttleTimers[key] then
        throttleTimers[key]:Cancel()
        throttleTimers[key] = nil
    end
    throttleTimers[key] = C_Timer.NewTimer(delay, function()
        throttleTimers[key] = nil
        func()
    end)
end

--- Cancel a pending throttled broadcast
-- @param key string  Unique key for the broadcast type
function Comm.CancelThrottle(key)
    if throttleTimers[key] then
        throttleTimers[key]:Cancel()
        throttleTimers[key] = nil
    end
end

-- == INTERNAL ==

--- Purge expired entries from the dedup map
local function CleanupRecentMessages()
    local now = GetTime()
    for key, timestamp in pairs(recentMessages) do
        if (now - timestamp) >= DEDUP_WINDOW then
            recentMessages[key] = nil
        end
    end
    for key, timestamp in pairs(lastSendTime) do
        if (now - timestamp) >= MIN_SEND_INTERVAL then
            lastSendTime[key] = nil
        end
    end
end

--- Check if a message should be processed (dedup filter)
local cleanupCounter = 0
local function ShouldProcess(sender, module, action)
    local key = sender .. ":" .. module .. ":" .. action
    local now = GetTime()
    if recentMessages[key] and (now - recentMessages[key]) < DEDUP_WINDOW then
        return false
    end
    recentMessages[key] = now

    -- Periodically clean up expired entries (every 20 messages)
    cleanupCounter = cleanupCounter + 1
    if cleanupCounter >= 20 then
        cleanupCounter = 0
        CleanupRecentMessages()
    end

    return true
end

--- Dispatch to the registered handler for a module:action
local function Dispatch(senderShort, senderFull, module, action, payload)
    if not ShouldProcess(senderShort, module, action) then return end
    local h = handlers[module] and handlers[module][action]
    if h then
        h(senderShort, payload or "", senderFull)
    end
end

--- Central message router
local function OnAddonMessage(prefix, message, channel, sender)
    -- Only process our own prefixes
    if prefix ~= ADDON_PREFIX and not LEGACY_PREFIXES[prefix] then return end

    local senderShort = sender:match("^([^%-]+)") or sender

    addonTable.Core.Log("Comm",
        string.format("RECV [%s] from %s on %s: %s", prefix, sender or "?", channel or "?", message or "?"), 0)

    if prefix == ADDON_PREFIX then
        -- New format: "MODULE:ACTION:PAYLOAD" or "MODULE:ACTION"
        local module, rest = message:match("^(%u+):(.+)$")
        if module then
            local action, payload = rest:match("^(%u+):?(.*)")
            if action then
                addonTable.Core.Log("Comm",
                    string.format("  -> Dispatch %s:%s payload=%s", module, action, payload or ""), 0)
                Dispatch(senderShort, sender, module, action, payload)
            else
                addonTable.Core.Log("Comm", string.format("  -> No action parsed from rest: %s", rest), 2)
            end
        else
            addonTable.Core.Log("Comm", string.format("  -> No module parsed from message"), 2)
        end
    elseif LEGACY_PREFIXES[prefix] then
        -- Route legacy messages to the appropriate module:action
        if prefix == "LunaVer" then
            if message == "REQUEST" then
                addonTable.Core.Log("Comm", "  -> Legacy VER:REQ", 0)
                Dispatch(senderShort, sender, "VER", "REQ", "")
            else
                addonTable.Core.Log("Comm", "  -> Legacy VER:HELLO", 0)
                Dispatch(senderShort, sender, "VER", "HELLO", message)
            end
        elseif prefix == "LunaKick" then
            addonTable.Core.Log("Comm", "  -> Legacy KICK:CD", 0)
            Dispatch(senderShort, sender, "KICK", "CD", message)
        end
    end
end

-- == EVENT FRAME ==

addonTable.EventBus.Register("CHAT_MSG_ADDON", function(event, ...)
    OnAddonMessage(...)
end, "AddonComm")

-- Register all prefixes
C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
C_ChatInfo.RegisterAddonMessagePrefix("LunaVer")
C_ChatInfo.RegisterAddonMessagePrefix("LunaKick")
