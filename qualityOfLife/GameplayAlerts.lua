local _,addon=...
local QoL=addon.QualityOfLife
local Module={}; QoL.GameplayAlerts=Module; QoL.AddModule(Module)
local Public=QoL.Public
local class=select(2,UnitClass("player"))
local spells={
    DEATHKNIGHT={48265,212552,444010,444347}, DEMONHUNTER={195072,189110,1234796},
    DRUID={102401,252216,1850,102417,106898}, EVOKER={358267}, HUNTER={186257,781},
    MAGE={212653,1953}, MONK={115008,109132,119085,361138,101545}, PALADIN={190784},
    PRIEST={121536,73325}, ROGUE={36554,2983,195457}, SHAMAN={79206,90328,192063,58875},
    WARLOCK={48020,111400}, WARRIOR={6544},
}
local known,previous,glowing={}, {},{}
local ticker,queued,spiralEnd
local glowSuppressedUntil=0
local frames={}
local function Layout() return addon.LayoutMode and addon.LayoutMode.IsActive() end
local function Known(id)
    return (C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id))
        or (IsPlayerSpell and IsPlayerSpell(id))
end
local function MakeFrame(key,label,posKey,width)
    local f=CreateFrame("Frame",nil,UIParent); f:SetSize(width or 300,40); f:SetFrameStrata("HIGH")
    f:SetMovable(true); f:EnableMouse(false)
    f.text=f:CreateFontString(nil,"OVERLAY"); f.text:SetAllPoints(); f.text:SetJustifyH("CENTER")
    frames[key]=f; f:Hide()
    addon.LayoutMode.RegisterTarget(label,function() return f end,function() return QoL.Enabled(key) end,function(target)
        local point,_,_,x,y=target:GetPoint(); QoL.Settings()[posKey]={point=point,x=x,y=y}
    end)
    return f
end
local move=MakeFrame("movement","Movement alerts","movementPos",420)
local spiral=MakeFrame("timeSpiral","Time Spiral alert","spiralPos")
local gateway=MakeFrame("gateway","Gateway alert","gatewayPos")
local bres=MakeFrame("battleRes","Battle resurrection","battleResPos",180)
bres.icon=bres:CreateTexture(nil,"ARTWORK"); bres.icon:SetPoint("LEFT"); bres.icon:SetSize(40,40)
bres.icon:SetTexture(C_Spell.GetSpellTexture(20484))
bres.text:ClearAllPoints(); bres.text:SetPoint("LEFT",bres.icon,"RIGHT",5,0); bres.text:SetPoint("RIGHT")
local function GetInfo(fn,id)
    if not fn then return end
    local ok,value=pcall(fn,id)
    if not ok or not Public(value) then return nil,true end
    if type(value)=="table" then return value end
end
local function MovementState(id)
    if id==111400 then
        local aura=C_UnitAuras and GetInfo(C_UnitAuras.GetPlayerAuraBySpellID,id)
        return Public(aura) and aura and "active" or "ready",0
    end
    local charges,restricted=GetInfo(C_Spell.GetSpellCharges,id)
    if restricted then return "restricted" end
    if charges then
        for _,key in ipairs({"currentCharges","maxCharges","cooldownStartTime","cooldownDuration"}) do
            if not Public(charges[key]) or type(charges[key])~="number" then return "restricted" end
        end
        local ready=charges.currentCharges>0
        local rate=charges.chargeModRate
        if not Public(rate) or type(rate)~="number" or rate<=0 then rate=1 end
        local remaining=math.max(0,charges.cooldownStartTime+charges.cooldownDuration/rate-GetTime())
        return ready and "ready" or "cooldown",remaining,charges.currentCharges,charges.currentCharges<charges.maxCharges
    end
    local cd=GetInfo(C_Spell.GetSpellCooldown,id)
    if not cd then return "unknown" end
    if not Public(cd.startTime) or not Public(cd.duration) or not Public(cd.isOnGCD) then return "restricted" end
    if type(cd.startTime)~="number" or type(cd.duration)~="number" then return "unknown" end
    if cd.isOnGCD or cd.duration<=1.5 then return "ready",0 end
    local rate=cd.modRate
    if not Public(rate) or type(rate)~="number" or rate<=0 then rate=1 end
    local remaining=math.max(0,cd.startTime+cd.duration/rate-GetTime())
    return remaining>0 and "cooldown" or "ready",remaining
end
local function Refresh()
    local db=QoL.Settings()
    if not db or not db.enabled then return end
    local polling=false
    if QoL.Enabled("movement") then
        local lines={}
        for id,name in pairs(known) do
            local state,remaining,charges,recharging=MovementState(id)
            if state=="cooldown" or state=="active" or recharging then
                lines[#lines+1]=state=="active" and (name.." active") or string.format("%s %.1f",name,remaining)
                polling=polling or state=="cooldown" or recharging
            end
            local old=previous[id]
            if db.movementTts and old and ((old.state=="cooldown" and state=="ready")
                or (charges and old.charges and charges>old.charges)) then
                addon.Core.SpeakTTS(name.." ready",db.movementVoice or 0)
            end
            if state~="restricted" and state~="unknown" then previous[id]={state=state,charges=charges} end
        end
        table.sort(lines)
        move.text:SetText(#lines>0 and table.concat(lines,"\n") or "Movement alerts")
        move:SetHeight(math.max(40,#lines*(db.alertFontSize+4)))
        move:SetShown(#lines>0 or Layout())
    else move:Hide() end
    local remaining=spiralEnd and math.max(0,spiralEnd-GetTime()) or 0
    if QoL.Enabled("timeSpiral") then
        spiral.text:SetFormattedText("FREE MOVEMENT\n%.1f",remaining)
        spiral:SetShown(remaining>0 or Layout()); polling=polling or remaining>0
    else spiral:Hide() end
    if QoL.Enabled("gateway") and class=="WARLOCK" then
        local count=C_Item.GetItemCount(188152)
        if Public(count) and count>0 then
            local usable=C_Item.IsUsableItem(188152)
            gateway.text:SetText("GATEWAY READY"); gateway:SetShown((Public(usable) and usable==true) or Layout())
            polling=true -- Range/usable state can change without a cooldown event.
        else gateway:SetShown(Layout()) end
    else gateway:SetShown(QoL.Enabled("gateway") and Layout()) end
    local _,instanceType,difficulty=GetInstanceInfo()
    local inKey=C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()
    local relevant=(instanceType=="raid" and difficulty~=17) or (instanceType=="party" and inKey)
    local widget=UIThingsDB.widgets
    local duplicate=widget and widget.enabled and widget.battleRes and widget.battleRes.enabled
    if QoL.Enabled("battleRes") and not duplicate and (relevant or Layout()) then
        local info=GetInfo(C_Spell.GetSpellCharges,20484)
        if info then
            bres.text:SetFormattedText("%d BR",info.currentCharges)
            -- Secret values are passed directly to native formatting, never compared.
            if C_Spell.GetSpellChargeDuration then
                local ok,duration=pcall(C_Spell.GetSpellChargeDuration,20484)
                if ok and duration then
                    bres.text:SetFormattedText("%d BR\n%.0fs",info.currentCharges,duration:GetRemainingDuration())
                    polling=true
                end
            end
            if Public(info.currentCharges) then bres.icon:SetDesaturated(info.currentCharges==0) end
        else bres.text:SetText("BR"); bres.icon:SetDesaturated(false) end
        bres:Show()
    else bres:Hide() end
    if polling and not ticker then ticker=C_Timer.NewTicker(.2,Refresh)
    elseif not polling and ticker then ticker:Cancel(); ticker=nil end
end
local function Queue()
    if queued then return end
    queued=C_Timer.NewTimer(.05,function() queued=nil; Refresh() end)
end
local function OnEvent(event,...)
    if event=="SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event=="SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local id=...
        if not Public(id) or type(id)~="number" or not known[id] or id==111400 then return end
        -- Some talents glow mobility buttons for other reasons. Ignore their own
        -- cast window instead of calling every action-bar highlight Time Spiral.
        if event=="SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
            if GetTime()<glowSuppressedUntil then return end
            glowing[id]=true; spiralEnd=GetTime()+10
        else glowing[id]=nil; if not next(glowing) then spiralEnd=nil end end
    elseif event=="UNIT_AURA" then
        local unit=...; if not Public(unit) or unit~="player" then return end
    elseif event=="UNIT_SPELLCAST_SUCCEEDED" then
        local unit,_,id=...
        if not Public(unit) or unit~="player" or not Public(id) then return end
        if (class=="WARLOCK" and Known(385899) and id==385899)
            or (class=="DEMONHUNTER" and ((Known(427640) and (id==198793 or id==370965 or id==195072))
                or (Known(427794) and id==195072))) then glowSuppressedUntil=GetTime()+1.5 end
    elseif event=="PLAYER_SPECIALIZATION_CHANGED" or event=="SPELLS_CHANGED" then
        Module.UpdateSettings(); return
    elseif event=="PLAYER_ENTERING_WORLD" then wipe(previous); wipe(glowing); spiralEnd=nil end
    Queue()
end
local watched={"SPELL_UPDATE_COOLDOWN","SPELL_UPDATE_CHARGES","SPELL_ACTIVATION_OVERLAY_GLOW_SHOW","SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
    "PLAYER_SPECIALIZATION_CHANGED","SPELLS_CHANGED","PLAYER_ENTERING_WORLD","BAG_UPDATE_DELAYED","UNIT_AURA",
    "CHALLENGE_MODE_START","CHALLENGE_MODE_COMPLETED","ENCOUNTER_START","ENCOUNTER_END","PLAYER_REGEN_ENABLED","UNIT_SPELLCAST_SUCCEEDED"}
function Module.UpdateSettings()
    if ticker then ticker:Cancel(); ticker=nil end
    if queued then queued:Cancel(); queued=nil end
    wipe(known); wipe(previous)
    for _,id in ipairs(spells[class] or {}) do if Known(id) then known[id]=C_Spell.GetSpellName(id) or ("Spell "..id) end end
    for text in (QoL.Settings().movementExtraSpells or ""):gmatch("%d+") do
        local id=tonumber(text); if Known(id) then known[id]=C_Spell.GetSpellName(id) or ("Spell "..id) end
    end
    for key,frame in pairs(frames) do
        local pos=QoL.Settings()[({movement="movementPos",timeSpiral="spiralPos",gateway="gatewayPos",battleRes="battleResPos"})[key]]
        frame:ClearAllPoints(); frame:SetPoint(pos.point,UIParent,pos.point,pos.x,pos.y)
        frame.text:SetFont("Fonts\\FRIZQT__.TTF",key=="battleRes" and 14 or QoL.Settings().alertFontSize,"OUTLINE")
        if key=="timeSpiral" then frame.text:SetTextColor(.53,1,0) elseif key=="gateway" then frame.text:SetTextColor(.7,0,1) end
        if not QoL.Settings().enabled then frame:Hide() end
    end
    local enabled=QoL.Enabled("movement") or QoL.Enabled("timeSpiral") or QoL.Enabled("gateway") or QoL.Enabled("battleRes")
    for _,event in ipairs(watched) do
        if enabled then addon.EventBus.Register(event,OnEvent,"GameplayAlerts") else addon.EventBus.Unregister(event,OnEvent) end
    end
    Refresh()
end
