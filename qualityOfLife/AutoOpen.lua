local _, addon = ...
local QoL = addon.QualityOfLife
local Open = {}
QoL.AutoOpen = Open
QoL.AddModule(Open)
local events = addon.EventBus
local frame = CreateFrame("Frame")
frame:Hide()
local timer, generation, pending, lootOpen = nil, 0, nil, false
local cache, blocked = {}, {}
-- Item IDs whose use was refused as protected (e.g. items that cast a spell
-- and need a real click). pcall cannot catch ADDON_ACTION_FORBIDDEN, so the
-- event is watched only around our own call and the item skipped afterwards.
local forbidden, refused = {}, false
-- Known reward containers whose tooltip may not expose an exact
-- ITEM_OPENABLE line. Keep exceptions specific to known IDs.
local useContainers = {
    [246585] = true, -- Artisan's Consortium Payout
}
local bag, slot = 0, 1
local interaction = {}
local Schedule
local function IsShown(name)
    local f = _G[name]
    -- Bank tabs can remain shown while their parent bank window is hidden.
    -- Only a genuinely visible interaction should pause container opening.
    return f and (f.IsVisible and f:IsVisible() or not f.IsVisible and f:IsShown())
end
function Open.GetConflict()
    return C_AddOns and C_AddOns.IsAddOnLoaded("EllesmereUIQoL")
        and EllesmereUIDB and EllesmereUIDB.autoOpenContainers == true
end
-- Busy() runs every frame while scanning; keep its lists out of the call.
local busyWindows = {"MerchantFrame", "BankFrame", "AccountBankPanel", "MailFrame", "TradeFrame", "AuctionHouseFrame"}
local function Casting(fn)
    local name = fn("player")
    return not QoL.Public(name) or name ~= nil
end
local function Busy()
    if not QoL.Enabled("autoOpen") or Open.GetConflict() or InCombatLockdown() then return true end
    if lootOpen or next(interaction) or (GetCursorInfo and GetCursorInfo()) then return true end
    if IsShiftKeyDown and IsShiftKeyDown() then return true end
    for _, name in ipairs(busyWindows) do
        if IsShown(name) then return true end
    end
    if Casting(UnitCastingInfo) or Casting(UnitChannelInfo) then return true end
    return false
end
local function Signature(info)
    if not QoL.Public(info.itemID) or not QoL.Public(info.stackCount) then return nil end
    return tostring(info.itemID) .. ":" .. tostring(info.stackCount)
end
local function Eligible(info, b, s)
    if not QoL.Public(info.isLocked) or info.isLocked or not QoL.Public(info.itemID) then return false end
    if QoL.Settings().excludeWarbound then
        local bind = select(14, C_Item.GetItemInfo(info.itemID))
        if not bind then
            if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(info.itemID) end
            return false
        end
        local types = Enum.ItemBind or {}
        if bind == types.ToWoWAccount or bind == types.ToBnetAccount or bind == types.ToBnetAccountUntilEquipped then return false end
        if C_Item.IsItemBindToAccount and C_Item.IsItemBindToAccount(info.itemID) then return false end
        if C_Item.IsItemBindToAccountUntilEquip and C_Item.IsItemBindToAccountUntilEquip(info.itemID) then return false end
    end
    local start, duration = C_Container.GetContainerItemCooldown(b, s)
    if not QoL.Public(start) or not QoL.Public(duration) or (start and duration and start > 0 and duration > 0) then return false end
    if useContainers[info.itemID] then return true end
    local known = cache[info.itemID]
    if known ~= nil then return known end
    local tip = C_TooltipInfo and C_TooltipInfo.GetBagItem(b, s)
    if tip and QoL.Public(tip.lines) then
        for _, line in ipairs(tip.lines or {}) do
            if QoL.Public(line.leftText) and line.leftText == ITEM_OPENABLE then
                cache[info.itemID] = true
                return true
            end
        end
    end
    if C_Item.IsItemDataCachedByID and C_Item.IsItemDataCachedByID(info.itemID) then cache[info.itemID] = false end
    return false
end
local function Step()
    if Busy() then
        frame:Hide()
        return
    end
    if pending then
        local info = C_Container.GetContainerItemInfo(pending.bag, pending.slot)
        if not info or Signature(info) ~= pending.signature then
            pending = nil
        elseif GetTime() >= pending.deadline then
            blocked[pending.bag .. ":" .. pending.slot] = pending.signature
            pending = nil
        else
            frame:Hide()
            Schedule(.5)
            return
        end
    end
    local maxBag = math.max(NUM_BAG_SLOTS or 4, Enum.BagIndex and Enum.BagIndex.ReagentBag or (addon.Client and addon.Client.isForever and (NUM_BAG_SLOTS or 4) or 5))
    for _ = 1, 12 do
        if bag > maxBag then
            frame:Hide()
            return
        end
        if slot > C_Container.GetContainerNumSlots(bag) then
            bag = bag + 1
            slot = 1
        else
            local b, s = bag, slot
            slot = slot + 1
            local info = C_Container.GetContainerItemInfo(b, s)
            local key = b .. ":" .. s
            if info and QoL.Public(info.itemID) and QoL.Public(info.stackCount)
                and not forbidden[info.itemID] and blocked[key] ~= Signature(info) and Eligible(info, b, s) then
                -- Revalidate the slot and pause conditions immediately before using it.
                local current = C_Container.GetContainerItemInfo(b, s)
                if not Busy() and current and not current.isLocked and Signature(current) == Signature(info) then
                    pending = {bag = b, slot = s, signature = Signature(info), deadline = GetTime() + 5}
                    frame:Hide()
                    refused = false
                    frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
                    local ok = pcall(C_Container.UseContainerItem, b, s)
                    frame:UnregisterEvent("ADDON_ACTION_FORBIDDEN")
                    if refused then
                        forbidden[info.itemID] = true
                        print("|cff00ccffLuna Auto-open:|r skipping " .. (C_Container.GetContainerItemLink(b, s) or ("item " .. info.itemID)) .. " - it must be opened by hand.")
                    end
                    if not ok or refused then
                        blocked[key] = pending.signature
                        pending = nil
                    end
                    Schedule(.8)
                    return
                end
            end
        end
    end
end
Schedule = function(delay)
    if not QoL.Enabled("autoOpen") then return end
    if timer then timer:Cancel() end
    frame:Hide()
    local token = generation
    timer = C_Timer.NewTimer(delay or .5, function()
        timer = nil
        if token ~= generation or Busy() then return end
        bag, slot = 0, 1
        frame:Show()
    end)
end
frame:SetScript("OnUpdate", Step)
frame:SetScript("OnEvent", function(_, _, name) if name == "LunaUITweaks" then refused = true end end)
local closes = {MERCHANT_CLOSED = "MERCHANT_SHOW", BANKFRAME_CLOSED = "BANKFRAME_OPENED", MAIL_CLOSED = "MAIL_SHOW", TRADE_CLOSED = "TRADE_SHOW"}
local function OnEvent(event, ...)
    if event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local unit = ...
        if not QoL.Public(unit) or unit ~= "player" then
            return
        end
    end
    if event == "LOOT_OPENED" then
        lootOpen = true
        frame:Hide()
        return
    end
    if event == "LOOT_CLOSED" then lootOpen = false end
    if event == "MERCHANT_SHOW" or event == "BANKFRAME_OPENED" or event == "MAIL_SHOW" or event == "TRADE_SHOW" then
        interaction[event] = true
        frame:Hide()
        return
    end
    if closes[event] then interaction[closes[event]] = nil end
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then wipe(interaction) end
    if event == "PLAYER_REGEN_DISABLED" then
        frame:Hide()
        return
    end
    if event == "GET_ITEM_INFO_RECEIVED" then
        local id = ...
        if QoL.Public(id) then
            cache[id] = nil
        end
    end
    Schedule(.5)
end
local watched = {"BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "ITEM_LOCK_CHANGED", "LOOT_OPENED", "LOOT_CLOSED", "MERCHANT_SHOW", "MERCHANT_CLOSED",
    "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "MAIL_SHOW", "MAIL_CLOSED", "TRADE_SHOW", "TRADE_CLOSED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "GET_ITEM_INFO_RECEIVED", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "MODIFIER_STATE_CHANGED"}
-- Player-only unit events, delivered for the player alone (not every unit).
local playerEvents = {"UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP"}
function Open.Retry()
    wipe(blocked)
    Schedule(.5)
end
function Open.UpdateSettings()
    generation = generation + 1
    if timer then
        timer:Cancel()
        timer = nil
    end
    frame:Hide()
    wipe(cache)
    wipe(interaction)
    for _, event in ipairs(watched) do
        if QoL.Enabled("autoOpen") then events.Register(event, OnEvent, "AutoOpen") else events.Unregister(event, OnEvent) end
    end
    for _, event in ipairs(playerEvents) do
        if QoL.Enabled("autoOpen") then events.RegisterUnitEvent(event, "player", OnEvent, "AutoOpen") else events.UnregisterUnitEvent(event, "player", OnEvent) end
    end
    if QoL.Enabled("autoOpen") then Schedule(1) end
end

-- Read-only diagnostics for containers skipped without an API error.
SLASH_LUITAUTOOPEN1 = "/luitautoopen"
SlashCmdList["LUITAUTOOPEN"] = function()
    local function Say(text) print("|cff00ccffLuna Auto-open:|r " .. text) end
    Say("Enabled=" .. tostring(not not QoL.Enabled("autoOpen")) .. " Conflict=" .. tostring(not not Open.GetConflict()) .. " Paused=" .. tostring(not not Busy()))
    Say("Combat=" .. tostring(not not InCombatLockdown()) .. " Loot=" .. tostring(lootOpen) .. " Interaction=" .. tostring(next(interaction)) .. " Shift=" .. tostring(not not (IsShiftKeyDown and IsShiftKeyDown())))
    for _, name in ipairs(busyWindows) do
        if IsShown(name) then Say("Visible window: " .. name) end
    end
    for b = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5) do
        for s = 1, C_Container.GetContainerNumSlots(b) do
            local info = C_Container.GetContainerItemInfo(b, s)
            if info and QoL.Public(info.itemID) and useContainers[info.itemID] then
                Say("Item " .. info.itemID .. " bag=" .. b .. " slot=" .. s .. " Eligible=" .. tostring(not not Eligible(info, b, s)) .. " Blocked=" .. tostring(blocked[b .. ":" .. s] == Signature(info)))
            end
        end
    end
end
