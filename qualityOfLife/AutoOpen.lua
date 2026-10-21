local _, addon = ...
local QoL=addon.QualityOfLife
local Open={}
QoL.AutoOpen=Open; QoL.AddModule(Open)
local events=addon.EventBus
local frame=CreateFrame("Frame")
frame:Hide()
local timer, generation, pending, lootOpen = nil,0,nil,false
local cache,blocked={},{}
local bag,slot=0,1
local interaction={}
local Schedule
local function IsShown(name) local f=_G[name]; return f and f:IsShown() end
function Open.GetConflict()
    return C_AddOns and C_AddOns.IsAddOnLoaded("EllesmereUIQoL")
        and EllesmereUIDB and EllesmereUIDB.autoOpenContainers == true
end
local function Busy()
    if not QoL.Enabled("autoOpen") or Open.GetConflict() or InCombatLockdown() then return true end
    if lootOpen or next(interaction) or (GetCursorInfo and GetCursorInfo()) then return true end
    if IsShiftKeyDown and IsShiftKeyDown() then return true end
    for _,name in ipairs({"MerchantFrame","BankFrame","AccountBankPanel","MailFrame","TradeFrame","AuctionHouseFrame"}) do
        if IsShown(name) then return true end
    end
    for _,fn in ipairs({UnitCastingInfo,UnitChannelInfo}) do
        local name=fn("player")
        if not QoL.Public(name) or name~=nil then return true end
    end
    return false
end
local function Signature(info)
    if not QoL.Public(info.itemID) or not QoL.Public(info.stackCount) then return nil end
    return tostring(info.itemID)..":"..tostring(info.stackCount)
end
local function Eligible(info,b,s)
    if not QoL.Public(info.isLocked) or info.isLocked or not QoL.Public(info.itemID) then return false end
    if QoL.Settings().excludeWarbound then
        local item={C_Item.GetItemInfo(info.itemID)}
        local bind=item[14]
        if not bind then
            if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(info.itemID) end
            return false
        end
        local types=Enum.ItemBind or {}
        if bind==types.ToWoWAccount or bind==types.ToBnetAccount or bind==types.ToBnetAccountUntilEquipped then return false end
        if C_Item.IsItemBindToAccount and C_Item.IsItemBindToAccount(info.itemID) then return false end
        if C_Item.IsItemBindToAccountUntilEquip and C_Item.IsItemBindToAccountUntilEquip(info.itemID) then return false end
    end
    local start,duration=C_Container.GetContainerItemCooldown(b,s)
    if not QoL.Public(start) or not QoL.Public(duration) or (start and duration and start>0 and duration>0) then return false end
    local known=cache[info.itemID]
    if known~=nil then return known end
    local tip=C_TooltipInfo and C_TooltipInfo.GetBagItem(b,s)
    if tip and QoL.Public(tip.lines) then
        for _,line in ipairs(tip.lines or {}) do
            if QoL.Public(line.leftText) and line.leftText==ITEM_OPENABLE then cache[info.itemID]=true; return true end
        end
    end
    if C_Item.IsItemDataCachedByID and C_Item.IsItemDataCachedByID(info.itemID) then cache[info.itemID]=false end
    return false
end
local function Step()
    if Busy() then frame:Hide(); return end
    if pending then
        local info=C_Container.GetContainerItemInfo(pending.bag,pending.slot)
        if not info or Signature(info)~=pending.signature then
            pending=nil
        elseif GetTime()>=pending.deadline then
            blocked[pending.bag..":"..pending.slot]=pending.signature
            pending=nil
        else frame:Hide(); Schedule(.5); return end
    end
    local maxBag=math.max(NUM_BAG_SLOTS or 4,Enum.BagIndex and Enum.BagIndex.ReagentBag or (addon.Client and addon.Client.isForever and (NUM_BAG_SLOTS or 4) or 5))
    for _=1,12 do
        if bag>maxBag then frame:Hide(); return end
        if slot>C_Container.GetContainerNumSlots(bag) then bag=bag+1; slot=1
        else
            local b,s=bag,slot; slot=slot+1
            local info=C_Container.GetContainerItemInfo(b,s)
            local key=b..":"..s
            if info and QoL.Public(info.itemID) and QoL.Public(info.stackCount)
                and blocked[key]~=Signature(info) and Eligible(info,b,s) then
                -- Revalidate the slot and pause conditions immediately before using it.
                local current=C_Container.GetContainerItemInfo(b,s)
                if not Busy() and current and not current.isLocked and Signature(current)==Signature(info) then
                    pending={bag=b,slot=s,signature=Signature(info),deadline=GetTime()+5}
                    frame:Hide()
                    local ok=pcall(C_Container.UseContainerItem,b,s)
                    if not ok then blocked[key]=pending.signature; pending=nil end
                    Schedule(.8)
                    return
                end
            end
        end
    end
end
Schedule=function(delay)
    if not QoL.Enabled("autoOpen") then return end
    if timer then timer:Cancel() end
    frame:Hide()
    local token=generation
    timer=C_Timer.NewTimer(delay or .5,function()
        timer=nil
        if token~=generation or Busy() then return end
        bag,slot=0,1; frame:Show()
    end)
end
frame:SetScript("OnUpdate",Step)
local function OnEvent(event,...)
    if event=="UNIT_SPELLCAST_STOP" or event=="UNIT_SPELLCAST_CHANNEL_STOP" then
        local unit=...; if not QoL.Public(unit) or unit~="player" then return end
    end
    if event=="LOOT_OPENED" then lootOpen=true; frame:Hide(); return end
    if event=="LOOT_CLOSED" then lootOpen=false end
    if event=="MERCHANT_SHOW" or event=="BANKFRAME_OPENED" or event=="MAIL_SHOW" or event=="TRADE_SHOW" then
        interaction[event]=true; frame:Hide(); return
    end
    local closes={MERCHANT_CLOSED="MERCHANT_SHOW",BANKFRAME_CLOSED="BANKFRAME_OPENED",MAIL_CLOSED="MAIL_SHOW",TRADE_CLOSED="TRADE_SHOW"}
    if closes[event] then interaction[closes[event]]=nil end
    if event=="PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then wipe(interaction) end
    if event=="PLAYER_REGEN_DISABLED" then frame:Hide(); return end
    if event=="GET_ITEM_INFO_RECEIVED" then local id=...; if QoL.Public(id) then cache[id]=nil end end
    Schedule(.5)
end
local watched={"BAG_UPDATE_DELAYED","BAG_UPDATE_COOLDOWN","ITEM_LOCK_CHANGED","LOOT_OPENED","LOOT_CLOSED","MERCHANT_SHOW","MERCHANT_CLOSED",
    "BANKFRAME_OPENED","BANKFRAME_CLOSED","MAIL_SHOW","MAIL_CLOSED","TRADE_SHOW","TRADE_CLOSED",
    "PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","UNIT_SPELLCAST_STOP","UNIT_SPELLCAST_CHANNEL_STOP",
    "GET_ITEM_INFO_RECEIVED","PLAYER_INTERACTION_MANAGER_FRAME_HIDE","MODIFIER_STATE_CHANGED"}
function Open.Retry() wipe(blocked); Schedule(.5) end
function Open.UpdateSettings()
    generation=generation+1
    if timer then timer:Cancel(); timer=nil end
    frame:Hide(); wipe(cache); wipe(interaction)
    for _,event in ipairs(watched) do
        if QoL.Enabled("autoOpen") then events.Register(event,OnEvent,"AutoOpen") else events.Unregister(event,OnEvent) end
    end
    if QoL.Enabled("autoOpen") then Schedule(1) end
end
