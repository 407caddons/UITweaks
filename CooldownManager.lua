local _, addon = ...
local Manager = {}
addon.CooldownManager = Manager
local groups = {
    {key="essential", name="Essential cooldowns", viewer="EssentialCooldownViewer"},
    {key="utility", name="Utility cooldowns", viewer="UtilityCooldownViewer"},
    {key="buffs", name="Buff cooldowns", viewer="BuffIconCooldownViewer"},
}
local dirty, applying = false, false
local worker = CreateFrame("Frame")
worker:Hide()
local function Public(value) return not (issecretvalue and issecretvalue(value)) end
local function DB() return UIThingsDB and UIThingsDB.cooldownManager end
function Manager.GetConflict()
    return C_AddOns and C_AddOns.IsAddOnLoaded("EllesmereUICooldownManager")
end
local function Configured(group)
    local db=DB()
    return db and db.enabled and db[group.key] and db[group.key].enabled
end
local function Direction(db)
    local value=db.growthDirection
    if value=="LEFT" or value=="UP" or value=="DOWN" then return value end
    return "RIGHT" -- preserves existing layouts and imports without this setting
end
local function Origin(db)
    local direction=Direction(db)
    return direction=="LEFT" and "BOTTOMRIGHT" or direction=="DOWN" and "TOPLEFT" or "BOTTOMLEFT"
end
local function Queue()
    if applying then return end
    dirty=true; worker:Show()
end
local function Editable(frame)
    local forbidden=frame:IsForbidden()
    if not Public(forbidden) or forbidden then return false end
    if InCombatLockdown() then
        local protected=frame:IsProtected()
        if not Public(protected) or protected then return false end
    end
    return true
end
local function Restore(group)
    if not group.managed then return end
    -- Releasing/reacquiring the native pool restores current Edit Mode scale,
    -- positions and order, including icons which disappeared while managed.
    if InCombatLockdown() then return end
    group.managed=false
    group.viewerFrame:RefreshLayout()
end
local function CreateAnchor(group)
    local frame=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    frame.origin=frame:CreateTexture(nil,"OVERLAY")
    frame.origin:SetColorTexture(1,.8,.2,1); frame.origin:SetSize(8,8)
    frame:SetMovable(true); frame:SetClampedToScreen(true); frame:EnableMouse(false)
    group.anchor=frame
    hooksecurefunc(frame,"StartMoving",function() group.dragging=true end)
    hooksecurefunc(frame,"StopMovingOrSizing",function() group.dragging=false; Queue() end)
    addon.LayoutMode.RegisterTarget(group.name,function() return frame end,function() return Configured(group) end,function(f)
        -- Keep the growth origin fixed when rows/columns appear or disappear.
        local db=DB()[group.key]
        local scale=f:GetEffectiveScale()/UIParent:GetEffectiveScale()
        local left,bottom=f:GetLeft(),f:GetBottom()
        if left and bottom then
            local direction=Direction(db)
            if direction=="LEFT" then left=left+f:GetWidth() end
            if direction=="DOWN" then bottom=bottom+f:GetHeight() end
            db.pos={point="BOTTOMLEFT",x=left*scale,y=bottom*scale}
        end
    end)
end
local function WatchItem(group,item)
    local forbidden=item:IsForbidden()
    if not Public(forbidden) or forbidden or group.watched[item] then return end
    group.watched[item]=true
    item:HookScript("OnShow",Queue); item:HookScript("OnHide",Queue)
end
local function Attach(group)
    local viewer=_G[group.viewer]
    if not viewer or not viewer.itemFramePool or not viewer.GetItemContainerFrame then return end
    if group.viewerFrame~=viewer then
        group.viewerFrame=viewer; group.watched=setmetatable({},{__mode="k"})
        hooksecurefunc(viewer,"RefreshLayout",Queue)
        hooksecurefunc(viewer,"OnAcquireItemFrame",function(_,item) WatchItem(group,item); Queue() end)
        local container=viewer:GetItemContainerFrame()
        if container and container.Layout then hooksecurefunc(container,"Layout",Queue) end
        viewer:HookScript("OnShow",Queue); viewer:HookScript("OnHide",Queue)
    end
    return viewer
end
local function PositionAnchor(group,count,preview)
    local db=DB()[group.key]
    local direction=Direction(db)
    local horizontal=direction=="RIGHT" or direction=="LEFT"
    local stride=db.columns
    local lines=math.max(preview and 2 or 1,math.ceil(count/stride))
    local cols,rows=horizontal and stride or lines,horizontal and lines or stride
    local size,gap=db.iconSize,db.spacing
    local anchor=group.anchor
    anchor:SetSize(cols*size+(cols-1)*gap,rows*size+(rows-1)*gap)
    anchor:ClearAllPoints(); anchor:SetPoint(Origin(db),UIParent,db.pos.point,db.pos.x,db.pos.y)
    anchor:SetBackdropColor(.04,.12,.14,preview and .45 or 0)
    anchor:SetBackdropBorderColor(.3,.9,.75,preview and 1 or 0)
    anchor.origin:ClearAllPoints(); anchor.origin:SetPoint(Origin(db),anchor,Origin(db),0,0)
    anchor.origin:SetShown(preview)
    anchor:SetShown(preview or count>0)
end
local function Layout(group)
    -- Anchors must also exist with no active buffs or before Blizzard loads its
    -- viewers, so every configured group can be positioned in Layout Mode.
    if not group.anchor then CreateAnchor(group) end
    local viewer=Attach(group)
    local preview=addon.LayoutMode.IsActive()
    if not Configured(group) then Restore(group); group.anchor:Hide(); return end
    if group.dragging then return end
    if not viewer or Manager.GetConflict() then
        Restore(group)
        PositionAnchor(group,0,preview)
        if not preview then group.anchor:Hide() end
        return
    end
    -- Leave both native viewers and their items parented to Blizzard. Native
    -- visibility, cooldown rendering, tooltips and proc effects remain intact.
    local items={}
    for item in viewer.itemFramePool:EnumerateActive() do
        WatchItem(group,item)
        if not Editable(item) then return end
        local shown=item:IsShown()
        local index=item.layoutIndex
        if not Public(shown) or not Public(index) then return end
        if shown and type(index)=="number" then items[#items+1]={frame=item,index=index} end
    end
    table.sort(items,function(a,b) return a.index<b.index end)
    local db=DB()[group.key]
    local size, gap, columns=db.iconSize,db.spacing,db.columns
    local count=#items
    local direction=Direction(db)
    local horizontal=direction=="RIGHT" or direction=="LEFT"
    local anchor=group.anchor
    -- Validate geometry for every icon before moving any of them. A secret
    -- visibility/geometry value leaves the last valid layout in place.
    for _,entry in ipairs(items) do
        local item=entry.frame
        local w=item:GetWidth()
        local parentScale=item:GetParent():GetEffectiveScale()
        if not Public(w) or not Public(parentScale) or type(w)~="number" or w<=0 or type(parentScale)~="number" or parentScale<=0 then return end
        entry.scale=size/w*UIParent:GetEffectiveScale()/parentScale
    end
    PositionAnchor(group,count,preview)
    for i,entry in ipairs(items) do
        local item=entry.frame
        item:SetScale(entry.scale)
        local ratio=item:GetEffectiveScale()/anchor:GetEffectiveScale()
        item:ClearAllPoints()
        local primary,secondary=(i-1)%columns,math.floor((i-1)/columns)
        local x,y=horizontal and primary or secondary,horizontal and secondary or primary
        if direction=="LEFT" then x=-x end
        if direction=="DOWN" then y=-y end
        item:SetPoint(Origin(db),anchor,Origin(db),x*(size+gap)/ratio,y*(size+gap)/ratio)
    end
    group.managed=true
end
local function Run()
    worker:Hide()
    if not dirty then return end
    dirty=false; applying=true
    for _,group in ipairs(groups) do xpcall(Layout,geterrorhandler(),group) end
    applying=false
end
worker:SetScript("OnUpdate",Run)
function Manager.UpdateSettings() Queue() end
addon.EventBus.Register("PLAYER_LOGIN",Queue,"CooldownManager")
addon.EventBus.Register("ADDON_LOADED",function(_,name)
    if name=="Blizzard_CooldownViewer" or name=="EllesmereUICooldownManager" then Queue() end
end,"CooldownManager")
addon.EventBus.Register("PLAYER_REGEN_ENABLED",Queue,"CooldownManager")
addon.EventBus.Register("PLAYER_REGEN_DISABLED",function()
    -- Hide only addon-owned layout decorations; native icons keep updating.
    for _,group in ipairs(groups) do
        local anchor=group.anchor
        if anchor then
            anchor:SetBackdropColor(0,0,0,0); anchor:SetBackdropBorderColor(0,0,0,0)
            anchor.origin:Hide()
        end
    end
end,"CooldownManager")
LunaUITweaksAPI.RegisterConfigPanel("cooldownManager","Cooldown Manager","Interface\\Icons\\Spell_Nature_TimeStop",function(...)
    addon.ConfigSetup.CooldownManager(...)
end)
