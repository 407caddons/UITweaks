# Events & Addon Communication APIs

APIs for WoW event registration, secure function hooks, and inter-addon messaging.

---

## Event Registration (Raw Frame Method)

```lua
frame:RegisterEvent("EVENT_NAME")
frame:UnregisterEvent("EVENT_NAME")
frame:UnregisterAllEvents()
frame:SetScript("OnEvent", function(self, event, ...) end)
```

**This addon does NOT use raw per-module event frames.** Instead it uses the centralized `EventBus` (see below). The raw form is only used in EventBus.lua itself.

---

## EventBus (Addon-Internal Pattern)

`EventBus.lua` provides a single-frame centralized event dispatcher. All modules subscribe via:

```lua
local EventBus = addonTable.EventBus

-- Subscribe
EventBus.Register("EVENT_NAME", function(event, ...) end)

-- Unsubscribe (requires exact function reference)
EventBus.Unregister("EVENT_NAME", myCallbackFn)

-- Subscribe with automatic unit filtering
local wrapper = EventBus.RegisterUnit("UNIT_HEALTH", "player", function(event, ...) end)
-- Must unregister using the wrapper reference, not the original function
EventBus.Unregister("UNIT_HEALTH", wrapper)
```

**Architecture:**
- Single `CreateFrame("Frame", "LunaUITweaks_EventBus")` handles all WoW events.
- `listeners[eventName] = { callback, ... }` registry.
- Dispatch uses a **snapshot copy** of the listener array so callbacks can safely unregister themselves mid-dispatch.
- WoW events are registered/unregistered on the frame automatically as listeners are added/removed.

---

## hooksecurefunc

```lua
-- SAFE form — global function hook, no taint
hooksecurefunc("GlobalFunctionName", function(...) end)

-- UNSAFE form — frame object hook, taints the frame
-- DO NOT USE:
hooksecurefunc(frame, "MethodName", function(...) end)
```

**Rules:**
- The **global form** `hooksecurefunc("FuncName", cb)` is safe and does not taint.
- The **object form** `hooksecurefunc(frame, "Method", cb)` taints the frame object — same effect as `frame:HookScript(...)`. Both are banned for Blizzard-owned frames.
- Hooks fire **after** the hooked function returns. The return value cannot be changed.
- To hook Blizzard layout callbacks, use the global form on named functions (e.g. `hooksecurefunc("ShowUIPanel", cb)`).

**Used in:** ActionBars.lua hooks `SetPointBase` via object form on addon-verified non-Blizzard frames. ChatSkin.lua hooks `ShowUIPanel`/`HideUIPanel` via global form.

---

## C_ChatInfo — Addon Messaging

### RegisterAddonMessagePrefix
```lua
local success = C_ChatInfo.RegisterAddonMessagePrefix(prefix)
```
Must be called before sending or receiving addon messages with that prefix. WoW limits the total number of registered prefixes per session.

**Used in:** AddonComm.lua registers `"LunaUI"` plus legacy prefixes `"LunaVer"` and `"LunaKick"`.

### SendAddonMessage
```lua
C_ChatInfo.SendAddonMessage(prefix, message, channel [, target])
```
- `channel` — `"RAID"`, `"PARTY"`, `"WHISPER"`, `"GUILD"`, `"BATTLEGROUND"`, `"SAY"`
- `target` — required for `"WHISPER"`, ignored for group channels
- Returns `false` if the message could not be sent (not in group, throttled, etc.)

**Rate limit:** WoW has internal throttling. The addon adds its own 1.0s minimum send interval per `module:action` key in AddonComm.lua.

**Message format used:** `"MODULE:ACTION:PAYLOAD"` with unified prefix `"LunaUI"`.

### Receiving Addon Messages
```lua
-- Event: CHAT_MSG_ADDON
-- Args: prefix, message, channel, senderFull, ...
```
AddonComm.lua listens for `CHAT_MSG_ADDON` via EventBus and routes to registered handlers.

### C_ChatInfo.InChatMessagingLockdown
```lua
local locked = C_ChatInfo.InChatMessagingLockdown()
```
Returns `true` if chat messaging is currently locked (rare; prevents sends). AddonComm.lua checks this before sending.

---

## AddonComm (Addon-Internal Pattern)

`AddonComm.lua` provides a message bus on top of `C_ChatInfo`:

```lua
-- Register a handler for incoming messages
-- callback(senderShort, payload, senderFull)
addonTable.Comm.Register(module, action, callback)

-- Send a message
addonTable.Comm.Send(module, action, payload [, legacyPrefix, legacyMessage])

-- Schedule a throttled broadcast (cancels pending for same key)
addonTable.Comm.ScheduleThrottled(key, delay, func)

-- Cancel a pending throttled broadcast
addonTable.Comm.CancelThrottle(key)

-- Check if sending is allowed
addonTable.Comm.IsAllowed()  -- in group AND not hidden from world

-- Get current channel
addonTable.Comm.GetChannel()  -- "RAID", "PARTY", or nil
```

**Built-in protections:**
- Rate limit: 1.0s minimum per `module:action` key
- Deduplication: 1.0s window ignores duplicate messages from same sender
- `UIThingsDB.addonComm.hideFromWorld` suppresses all sends
- Periodic cleanup of expired dedup/rate-limit entries every 20 messages

**Legacy prefixes** still handled for backward compatibility:
- `"LunaVer"` → routed as `VER:HELLO` or `VER:REQ`
- `"LunaKick"` → routed as `KICK:CD`

---

## Relevant Events

| Event | Description |
|---|---|
| `ADDON_LOADED` | A specific addon finished loading; args: `(addonName)` |
| `PLAYER_LOGIN` | All addons loaded, player data available |
| `CHAT_MSG_ADDON` | Received an addon message; args: `(prefix, message, channel, sender)` |
| `CHAT_MSG_SYSTEM` | System message in chat |
| `CHAT_MSG_COMBAT_*` | Various combat text messages |
