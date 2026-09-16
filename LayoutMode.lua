local _, addon = ...
local Layout = { active = false }
addon.LayoutMode = Layout
local targets, handles = {}, {}
local toolbar, ticker, pendingLock
local controls = {}
function Layout.RegisterControl(refresh) controls[#controls+1]=refresh end
local function SyncControls(locked)
    for _,name in ipairs({"UIThingsWidgetsLockCheck","UIThingsCombatLockCheck","UIThingsTTDLockCheck",
        "UIThingsReminderLockCheck","UIThingsCastBarLock","UIThingsTargetCastBarLock","UIThingsFocusCastBarLock","UIThingsMplusTimerLockCheck",
        "UIThingsCoordinatesLockCheck","UIThingsXpBarLockCheck","UIThingsVendorLockCheck","LunaEncounterBars_locked",
        "UIThingsMinimapLocked","UIThingsLockZone","UIThingsLockClock","UIThingsLockCoords","UIThingsMinimapDrawerLocked"}) do
        local control=_G[name]
        if control then control:SetChecked(locked) end
    end
    for _,refresh in ipairs(controls) do refresh() end
end
local function Call(module, method, ...)
    local m = addon[module]
    if m and m[method] then m[method](...) end
end
function Layout.IsActive() return Layout.active end

-- Targets retain their own save logic; the common overlay only handles interaction.
function Layout.RegisterTarget(key, getFrame, enabled, save)
    targets[key] = {getFrame=getFrame, enabled=enabled, save=save}
end
local function StopDrag(handle)
    if not handle.dragging then return end
    handle.dragging = false
    local target = handle.target
    target:StopMovingOrSizing()
    if handle.spec.save then handle.spec.save(target)
    else
        local stop = target:GetScript("OnDragStop")
        if stop then stop(target) end
    end
end
local function RefreshHandles()
    if not Layout.active or InCombatLockdown() then return end
    for key, spec in pairs(targets) do
        local target = spec.getFrame()
        local handle = handles[key]
        if target and spec.enabled() then
            if not handle then
                handle = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
                handle:SetFrameStrata("TOOLTIP"); handle:SetFrameLevel(100)
                handle:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
                handle:SetBackdropColor(.04,.12,.14,.8); handle:SetBackdropBorderColor(.3,.9,.75,1)
                handle.text=handle:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
                handle.text:SetPoint("CENTER"); handle.text:SetText(key)
                handle:EnableMouse(true); handle:RegisterForDrag("LeftButton")
                handle:SetScript("OnDragStart",function(self)
                    if not Layout.active or InCombatLockdown() then return end
                    self.dragging=true
                    self.target:SetMovable(true); self.target:StartMoving()
                end)
                handle:SetScript("OnDragStop",StopDrag)
                handles[key]=handle
            end
            handle.target,handle.spec=target,spec
            -- The overlay is the only drag surface during Layout Mode. This also
            -- keeps deferred combat locking from leaving native drag scripts active.
            target:EnableMouse(false)
            if not handle.dragging then
                handle:ClearAllPoints(); handle:SetAllPoints(target)
            end
            handle:Show()
        elseif handle then StopDrag(handle); handle:Hide() end
    end
end
local function SetFlags(locked)
    local db = UIThingsDB
    for _,key in ipairs({"widgets","combat","castBar","damageMeter","mplusTimer","coordinates","xpBar","encounterBars"}) do
        if db[key] then db[key].locked=locked end
    end
    if db.combat then
        db.combat.ttdLocked=locked
        if db.combat.reminders then db.combat.reminders.locked=locked end
    end
    if db.castBar and db.castBar.targetBar then db.castBar.targetBar.locked=locked end
    if db.castBar and db.castBar.focusBar then db.castBar.focusBar.locked=locked end
    if db.vendor then db.vendor.warningLocked=locked end
    if db.minimap then db.minimap.minimapDrawerLocked=locked end
    if db.frames then for _,frame in ipairs(db.frames.list or {}) do frame.locked=locked end end
end
local function Apply(locked)
    Call("Frames","UpdateFrames")
    Call("Widgets","UpdateVisuals")
    for _,name in ipairs({"Combat","CastBar","DamageMeter","MplusTimer","Coordinates","XpBar","Vendor","EncounterBars"}) do
        Call(name,"UpdateSettings")
    end
    Call("Combat","TtdApplySettings"); Call("Combat","UpdateReminders")
    for _,method in ipairs({"SetMinimapLocked","SetZoneLocked","SetClockLocked","SetCoordsLocked","SetDrawerLocked"}) do
        Call("MinimapCustom",method,locked)
    end
    Call("Loot","LockAnchor")
    if not locked and UIThingsDB.loot and UIThingsDB.loot.enabled then Call("Loot","ToggleAnchor") end
    Call("MplusTimer","CloseDemo")
    Call("EncounterBars","ClosePreview")
    if not locked then
        if UIThingsDB.mplusTimer and UIThingsDB.mplusTimer.enabled then Call("MplusTimer","ToggleDemo") end
        if UIThingsDB.encounterBars and UIThingsDB.encounterBars.enabled then Call("EncounterBars","TogglePreview") end
    end
    Call("TankDebuffs","UpdateSettings")
    SyncControls(locked)
    Call("Config","RefreshFrameControls")
end
function Layout.LockAll()
    Layout.active=false
    if ticker then ticker:Cancel(); ticker=nil end
    if toolbar then toolbar:Hide() end
    -- Do not mutate protected frames in combat; saved lock flags are safe to set.
    for _,handle in pairs(handles) do
        if not InCombatLockdown() then StopDrag(handle) end
        handle:Hide()
    end
    if not UIThingsDB then return end
    SetFlags(true)
    if InCombatLockdown() then
        pendingLock=true
        Call("TankDebuffs","RefreshUnits")
        return
    end
    pendingLock=false
    Apply(true)
end
function Layout.Start()
    if Layout.active then return end
    if InCombatLockdown() or IsEncounterInProgress() then
        print("LunaUITweaks: Layout Mode is only available outside combat and encounters."); return
    end
    Layout.active=true
    SetFlags(false); Apply(false)
    if not toolbar then
        toolbar=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
        toolbar:SetSize(440,64); toolbar:SetPoint("TOP",0,-40); toolbar:SetFrameStrata("TOOLTIP"); toolbar:SetFrameLevel(200)
        toolbar:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"}); toolbar:SetBackdropColor(.04,.08,.1,.97)
        local text=toolbar:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        text:SetPoint("TOP",0,-8); text:SetText("Layout Mode — drag handles; docked items follow their frame")
        local done=CreateFrame("Button",nil,toolbar,"UIPanelButtonTemplate")
        done:SetSize(150,26); done:SetPoint("BOTTOM",0,6); done:SetText("Done / Lock All")
        done:SetScript("OnClick",Layout.LockAll)
    end
    toolbar:Show(); RefreshHandles()
    ticker=C_Timer.NewTicker(.25,RefreshHandles)
end
function Layout.Toggle() if Layout.active then Layout.LockAll() else Layout.Start() end end
local function Enabled(key, extra)
    return function()
        local db=UIThingsDB[key]
        return db and db.enabled and (not extra or extra(db))
    end
end
for _,entry in ipairs({
    {"Combat timer","UIThingsCombatTimer","combat"},
    {"Time to die","UIThingsTTDTimer","combat",function(db) return db.ttdEnabled end},
    {"Consumable reminders","LunaCombatReminders","combat",function(db) return db.reminders~=nil end},
    {"Player cast bar","LunaCastBar","castBar"},
    {"Target cast bar","LunaTargetCastBar","castBar",function(db) return db.targetBar and db.targetBar.enabled end},
    {"M+ timer","LunaMplusTimer","mplusTimer"},
    {"Waypoints","LunaCoordinatesFrame","coordinates"},
    {"XP / reputation","LunaUITweaks_XpBar","xpBar"},
    {"Damage meter","LunaUITweaks_DamageMeterMain","damageMeter",function(db) return (db.dockToFrame or 0)==0 end},
    {"Repair warning","UIThingsRepairWarning","vendor"},
    {"Bag warning","UIThingsBagWarning","vendor"},
    {"Loot toasts","UIThingsLootAnchor","loot"},
}) do
    local name,global,key,extra=unpack(entry)
    Layout.RegisterTarget(name,function() return _G[global] end,Enabled(key,extra))
end
for _,entry in ipairs({
    {"Minimap","LunaMinimapFrame","minimapPos"},
    {"Minimap drawer","LunaMinimapDrawer","minimapDrawerPos"},
}) do
    local name,global,posKey=unpack(entry)
    Layout.RegisterTarget(name,function() return _G[global] end,function()
        local f=_G[global]
        return UIThingsDB.minimap and UIThingsDB.minimap.minimapEnabled and f and f:IsShown()
    end,function(frame)
        local point,_,relativePoint,x,y=frame:GetPoint()
        UIThingsDB.minimap[posKey]={point=point,relPoint=relativePoint,x=x,y=y}
    end)
end
for _,entry in ipairs({
    {"Minimap zone","LunaMinimapZoneFrame"},
    {"Minimap clock","LunaMinimapClockFrame"},
    {"Minimap coordinates","LunaMinimapCoordsFrame"},
}) do
    local name,global=unpack(entry)
    Layout.RegisterTarget(name,function() return _G[global] end,function()
        local frame=_G[global]
        return UIThingsDB.minimap and UIThingsDB.minimap.minimapEnabled and frame and frame:IsShown()
    end,function(frame)
        if frame.dragOverlay then
            local stop=frame.dragOverlay:GetScript("OnDragStop")
            if stop then stop(frame.dragOverlay) end
        end
    end)
end
addon.EventBus.Register("PLAYER_REGEN_DISABLED",function() if Layout.active then Layout.LockAll() end end,"LayoutMode")
addon.EventBus.Register("PLAYER_REGEN_ENABLED",function()
    if pendingLock then
        for _,handle in pairs(handles) do StopDrag(handle) end
        Layout.LockAll()
    end
end,"LayoutMode")
addon.EventBus.Register("PLAYER_LOGOUT",function() if UIThingsDB then SetFlags(true) end end,"LayoutMode")
addon.EventBus.Register("PLAYER_LOGIN",function() C_Timer.After(2,function() if not Layout.active then Layout.LockAll() end end) end,"LayoutMode")
SLASH_LUNALAYOUT1="/lunalayout"
SlashCmdList.LUNALAYOUT=Layout.Toggle
