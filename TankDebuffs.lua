-- Blizzard owns aura enumeration, filtering, duration and stack rendering.
-- Never inspect the aura data, protected child visibility, or displayed values.
local _, addon = ...
local Tanks = {}
addon.TankDebuffs = Tanks
local displays = {}
local pending, unavailable = false, nil
local settingsDirty = false
local function DB() return UIThingsDB and UIThingsDB.tankDebuffs end
local function Editing() return addon.LayoutMode and addon.LayoutMode.IsActive() end
function Tanks.GetStatus() return unavailable end
function Tanks.FindCoTank()
    if not IsInRaid() then return end
    for i=1,GetNumGroupMembers() do
        local unit="raid"..i
        if not UnitIsUnit(unit,"player") and UnitGroupRolesAssigned(unit)=="TANK" then return unit end
    end
end

-- Opt-in comparison view. Blizzard renders the unfiltered combat auras; the
-- diagnostic never reads protected children or uses them to infer aura identity.
local StyleAura, InitializeAura
local debugFrames, debugTicker, debugGeneration = {}, nil, 0
local function DebugText(value)
    if issecretvalue and issecretvalue(value) then return "<secret>" end
    return tostring(value)
end
local function DebugDump()
    print("Luna tank debug: boss/role filter="..DebugText(DB().bossOnly)..
        ", player limit="..DebugText(DB().player.maxIcons)..", co-tank limit="..DebugText(DB().other.maxIcons))
    local restricted = InCombatLockdown() or IsInInstance()
    if IsEncounterInProgress and IsEncounterInProgress() then restricted = true end
    if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive then
        for i=0,3 do if C_RestrictedActions.IsAddOnRestrictionActive(i) then restricted=true end end
    end
    if restricted then
        print("Luna tank debug: combat/instance restrictions — no aura scan attempted. Compare the unfiltered debug icons visually; private/hidden auras are not guaranteed to be exposed.")
        return
    end
    for _,unit in ipairs({"player", Tanks.FindCoTank()}) do
        print("Luna tank debug: unfiltered HARMFUL on "..unit)
        AuraUtil.ForEachAura(unit,"HARMFUL",nil,function(aura)
            print("  "..DebugText(aura.name).." ID="..DebugText(aura.spellId)..
                " stacks="..DebugText(aura.applications).." boss="..DebugText(aura.isBossAura)..
                " tankRole="..DebugText(aura.isTankRoleAura).." source="..DebugText(aura.sourceUnit))
        end,true)
    end
end
local function StopDebug()
    debugGeneration=debugGeneration+1
    if debugTicker then debugTicker:Cancel(); debugTicker=nil end
    for _,f in pairs(debugFrames) do f.container:SetEnabled(false); f:Hide() end
end
local function RefreshDebug()
    local coTank=Tanks.FindCoTank()
    for key,f in pairs(debugFrames) do
        local unit=key=="player" and "player" or coTank
        if f.unit~=unit then
            f.container:SetEnabled(false)
            if unit then f.container:SetUnit(unit) end
            f.unit=unit
        end
        f.container:SetEnabled(unit~=nil); f:SetShown(unit~=nil)
    end
end
SLASH_LUNATANKDEBUG1="/lunatankdebug"
SlashCmdList.LUNATANKDEBUG=function(input)
    input=(input or ""):lower():match("^%s*(.-)%s*$")
    if input=="off" then StopDebug(); print("Luna tank debug OFF."); return end
    if input=="dump" then DebugDump(); return end
    if InCombatLockdown() then print("Luna tank debug: enable outside combat, then reproduce the debuff."); return end
    StopDebug()
    for i,key in ipairs({"player","other"}) do
        if not debugFrames[key] then
            local f=CreateFrame("Frame",nil,UIParent)
            f:SetFrameStrata("HIGH")
            local size=math.max(12,math.min(28,math.floor((UIParent:GetWidth()-80)/40)-4))
            f:SetSize(40*(size+4),size)
            f:SetPoint("TOPLEFT",UIParent,"TOPLEFT",30,-120-(i-1)*(size+40))
            local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            title:SetPoint("BOTTOMLEFT",f,"TOPLEFT",0,4)
            title:SetText(key=="player" and "DEBUG: Your debuffs — unfiltered (up to 40)" or "DEBUG: Co-tank debuffs — unfiltered (up to 40)")
            local ok,container=pcall(CreateFrame,"AuraContainer",nil,f,"CustomAuraContainerTemplate")
            if not ok then f:Hide(); StopDebug(); print("Luna tank debug: AuraContainer unavailable."); return end
            container:SetEnabled(false); container:SetPoint("TOPLEFT",f,"TOPLEFT")
            container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
            container:SetFlowLayoutAnchorPoint("TOPLEFT")
            container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right,AnchorUtil.FlowDirection.Down)
            container:AddAuraGroup("all","HARMFUL",{
                maxFrameCount=40, candidateFilters={},
                sortMethod=Enum.UnitAuraSortRule.ExpirationOnly, sortDirection=Enum.UnitAuraSortDirection.Normal,
                initializeFrame=function(aura)
                    InitializeAura(aura,key)
                    StyleAura(aura,{iconSize=size,fontSize=12})
                end,
                layout={elementWidth=size,elementHeight=size,elementSpacing=4},
            })
            f.container=container; debugFrames[key]=f
        end
    end
    RefreshDebug(); debugTicker=C_Timer.NewTicker(.5,RefreshDebug)
    local generation=debugGeneration
    C_Timer.After(300,function() if generation==debugGeneration then StopDebug(); print("Luna tank debug OFF (timeout).") end end)
    print("Luna tank debug ON for 5 minutes. Screenshot debug rows and normal frames together. /lunatankdebug dump for a safe snapshot; /lunatankdebug off to stop.")
    DebugDump()
end
StyleAura = function(aura, settings)
    aura:SetSize(settings.iconSize,settings.iconSize)
    if aura.lunaCount then
        aura.lunaCount:SetFont("Fonts\\FRIZQT__.TTF",settings.fontSize,"OUTLINE")
        aura.lunaDuration:SetFont("Fonts\\FRIZQT__.TTF",settings.fontSize,"OUTLINE")
    end
end
InitializeAura = function(aura, key)
    local settings=DB()[key]
    aura:EnableMouse(true)
    local icon=aura:CreateTexture(nil,"BACKGROUND"); icon:SetAllPoints(); aura:SetIcon(icon)
    local cooldown=CreateFrame("Cooldown",nil,aura,"CooldownFrameTemplate")
    cooldown:SetAllPoints(); cooldown:SetReverse(true); cooldown:SetDrawEdge(false)
    cooldown:SetHideCountdownNumbers(true); aura:SetDurationCooldown(cooldown)
    local overlay=CreateFrame("Frame",nil,aura)
    overlay:SetAllPoints(); overlay:SetFrameLevel(cooldown:GetFrameLevel()+1)
    local count=overlay:CreateFontString(nil,"OVERLAY")
    -- Binding can immediately set text; initialize fonts before handing them to Blizzard.
    count:SetFont("Fonts\\FRIZQT__.TTF",settings.fontSize,"OUTLINE")
    count:SetPoint("BOTTOMRIGHT",-2,2); aura:SetApplicationCount(count)
    local duration=overlay:CreateFontString(nil,"OVERLAY")
    duration:SetFont("Fonts\\FRIZQT__.TTF",settings.fontSize,"OUTLINE")
    duration:SetPoint("CENTER"); aura:SetDurationText(duration)
    aura.lunaCount=count; aura.lunaDuration=duration
    StyleAura(aura,settings)
end
local function CreateDisplay(key)
    local frame=CreateFrame("Frame","LunaTankDebuffs_"..key,UIParent)
    frame:SetFrameStrata("MEDIUM"); frame:SetMovable(true); frame:SetClampedToScreen(true)
    frame.title=frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    frame.title:SetPoint("BOTTOMLEFT",frame,"TOPLEFT",0,4)
    local ok,container=pcall(CreateFrame,"AuraContainer",nil,frame,"CustomAuraContainerTemplate")
    if not ok then frame:Hide(); unavailable="Requires Blizzard's 12.1 AuraContainer API."; return end
    container:SetEnabled(false)
    container:SetPoint("TOPLEFT",frame,"TOPLEFT")
    container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    container:SetFlowLayoutAnchorPoint("TOPLEFT")
    container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right,AnchorUtil.FlowDirection.Down)
    container:AddAuraGroup("debuffs","HARMFUL",{
        maxFrameCount=DB()[key].maxIcons,
        initializeFrame=function(aura) InitializeAura(aura,key) end,
        sortMethod=Enum.UnitAuraSortRule.ExpirationOnly,
        sortDirection=Enum.UnitAuraSortDirection.Normal,
        candidateFilters=DB().bossOnly and {isBossOrRoleAura=true} or {},
        layout={elementWidth=DB()[key].iconSize,elementHeight=DB()[key].iconSize,elementSpacing=4},
    })
    frame.container=container
    displays[key]=frame
    return frame
end
local function UpdateUnits()
    if not DB() then return end
    local _, instanceType = IsInInstance()
    local enabled=DB().enabled and (IsInRaid() or instanceType == "party") and
        (not DB().onlyTanking or UnitGroupRolesAssigned("player")=="TANK")
    local coTank=enabled and Tanks.FindCoTank() or nil
    for key,frame in pairs(displays) do
        local unit=key=="player" and "player" or coTank
        local show=enabled and unit~=nil and DB()[key].enabled
        -- Unit and enabled setters are the supported inbound container interface.
        if frame.unit~=unit then
            frame.container:SetEnabled(false)
            if unit then frame.container:SetUnit(unit) end
            frame.unit=unit
        end
        frame.container:SetEnabled(not not show and not Editing())
        frame:SetShown(show or (Editing() and DB().enabled and DB()[key].enabled))
        frame.title:SetText(key=="player" and "Your tank debuffs" or
            (coTank and ("Co-tank: "..(UnitName(coTank) or "Unknown")) or "Co-tank raid debuffs"))
    end
end
Tanks.RefreshUnits=UpdateUnits
function Tanks.UpdateSettings()
    if not DB() then return end
    if InCombatLockdown() then pending=true; settingsDirty=true; return end
    pending=false
    if DB().enabled and not unavailable then
        for _,key in ipairs({"player","other"}) do if not displays[key] then CreateDisplay(key) end end
    end
    for key,frame in pairs(displays) do
        local s=DB()[key]
        frame:ClearAllPoints(); frame:SetPoint("TOPLEFT",UIParent,"CENTER",s.x,s.y)
        frame:SetSize(s.maxIcons*s.iconSize+(s.maxIcons-1)*4,s.iconSize)
        frame.container:SetAuraGroupMaxFrameCount("debuffs",s.maxIcons)
        frame.container:SetAuraGroupCandidateFilters("debuffs",DB().bossOnly and {isBossOrRoleAura=true} or {})
        frame.container:SetAuraGroupLayout("debuffs",{elementWidth=s.iconSize,elementHeight=s.iconSize,elementSpacing=4})
        for i=1,frame.container:GetAuraGroupFrameCount("debuffs") do
            local aura=frame.container:GetAuraGroupFrame("debuffs",i)
            if aura:CanBeAccessedInContext() then StyleAura(aura,s) else settingsDirty=true end
        end
    end
    UpdateUnits()
end
for _,key in ipairs({"player","other"}) do
    addon.LayoutMode.RegisterTarget(key=="player" and "Your tank debuffs" or "Co-tank raid debuffs",
        function() return displays[key] end,
        function() return DB() and DB().enabled and DB()[key].enabled end,
        function(frame)
            local x,y=frame:GetLeft(),frame:GetTop()
            local cx,cy=UIParent:GetCenter()
            DB()[key].x=math.floor(x-cx+.5); DB()[key].y=math.floor(y-cy+.5)
            Tanks.UpdateSettings()
        end)
end
addon.EventBus.Register("PLAYER_LOGIN",Tanks.UpdateSettings,"TankDebuffs")
addon.EventBus.Register("PLAYER_REGEN_ENABLED",function()
    if pending or settingsDirty then settingsDirty=false; Tanks.UpdateSettings() else UpdateUnits() end
end,"TankDebuffs")
for _,event in ipairs({"GROUP_ROSTER_UPDATE","PLAYER_ROLES_ASSIGNED","PLAYER_ENTERING_WORLD","PLAYER_SPECIALIZATION_CHANGED"}) do
    addon.EventBus.Register(event,function()
        if not InCombatLockdown() and DB() and DB().enabled and not displays.player then Tanks.UpdateSettings()
        else UpdateUnits() end
    end,"TankDebuffs")
end
