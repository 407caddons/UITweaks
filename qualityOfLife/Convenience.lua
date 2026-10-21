local _, addon = ...
local QoL=addon.QualityOfLife
local Module={}
QoL.AddModule(Module)
local bus=addon.EventBus
local collectionTimer, hooks={},{}
local keyFrame=CreateFrame("Frame",nil,UIParent)
keyFrame:Hide(); keyFrame:SetAllPoints(UIParent); keyFrame:SetFrameStrata("TOOLTIP")
keyFrame:EnableMouse(false); keyFrame:EnableKeyboard(true); keyFrame:SetPropagateKeyboardInput(true)
local sceneHint=keyFrame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
sceneHint:SetPoint("BOTTOM",0,100); sceneHint:SetText("Press any key to skip this scene")
local function HideTalkingHead()
    if QoL.Enabled("hideTalkingHead") and TalkingHeadFrame and not TalkingHeadFrame.isInEditMode then TalkingHeadFrame:Hide() end
end
local function HideTips()
    if QoL.Enabled("hideTutorials") and HelpTip and HelpTip.HideAll then HelpTip:HideAll() end
end
local function HookFrames()
    if TalkingHeadFrame and not hooks.talking then
        TalkingHeadFrame:HookScript("OnShow",HideTalkingHead); hooks.talking=true
    end
    if HelpTip and HelpTip.Show and not hooks.tips then
        hooksecurefunc(HelpTip,"Show",HideTips); hooks.tips=true
    end
    HideTalkingHead(); HideTips()
end
local function Unwrap(kind)
    if not QoL.Enabled("unwrapCollections") then return end
    if kind=="mount" and C_MountJournal and C_MountJournal.GetMountIDs and C_MountJournal.NeedsFanfare and C_MountJournal.ClearFanfare then
        for _,id in ipairs(C_MountJournal.GetMountIDs() or {}) do
            if C_MountJournal.NeedsFanfare(id) then C_MountJournal.ClearFanfare(id) end
        end
    elseif kind=="pet" and C_PetJournal and C_PetJournal.GetOwnedPetIDs and C_PetJournal.PetNeedsFanfare and C_PetJournal.ClearFanfare then
        for _,id in ipairs(C_PetJournal.GetOwnedPetIDs() or {}) do
            if C_PetJournal.PetNeedsFanfare(id) then C_PetJournal.ClearFanfare(id) end
        end
    elseif kind=="toy" and C_ToyBox and C_ToyBoxInfo and C_ToyBoxInfo.NeedsFanfare and C_ToyBoxInfo.ClearFanfare then
        for i=1,C_ToyBox.GetNumToys() do
            local id=C_ToyBox.GetToyFromIndex(i)
            if id and C_ToyBoxInfo.NeedsFanfare(id) then C_ToyBoxInfo.ClearFanfare(id) end
        end
    end
end
local function QueueUnwrap(kind)
    if collectionTimer[kind] then collectionTimer[kind]:Cancel() end
    collectionTimer[kind]=C_Timer.NewTimer(1,function() collectionTimer[kind]=nil; Unwrap(kind) end)
end
local function Skip()
    if not QoL.Enabled("skipCinematics") then keyFrame:Hide(); return end
    if CinematicFrame and CinematicFrame:IsShown() then
        if CinematicFrame.isRealCinematic then pcall(StopCinematic)
        elseif CanCancelScene and CanCancelScene() then keyFrame:Show() end -- CancelScene requires a hardware key event.
    end
end
keyFrame:SetScript("OnKeyDown",function()
    if QoL.Enabled("skipCinematics") and CanCancelScene and CanCancelScene() then CancelScene() end
    keyFrame:Hide()
end)
local function OnEvent(event)
    if event=="CINEMATIC_START" then C_Timer.After(0,Skip)
    elseif event=="CINEMATIC_STOP" then keyFrame:Hide()
    elseif event=="PLAY_MOVIE" then
        C_Timer.After(0,function()
            if QoL.Enabled("skipCinematics") and MovieFrame and MovieFrame:IsShown() then
                if MovieFrame.StopMovie then MovieFrame:StopMovie() end
                MovieFrame:Hide()
            end
        end)
    elseif event=="NEW_MOUNT_ADDED" then QueueUnwrap("mount")
    elseif event=="NEW_PET_ADDED" then QueueUnwrap("pet")
    elseif event=="NEW_TOY_ADDED" then QueueUnwrap("toy")
    else HookFrames() end
end
function Module.UpdateSettings()
    for _,event in ipairs({"CINEMATIC_START","CINEMATIC_STOP","PLAY_MOVIE","NEW_MOUNT_ADDED","NEW_PET_ADDED","NEW_TOY_ADDED","ADDON_LOADED"}) do
        if QoL.Settings().enabled then bus.Register(event,OnEvent,"Convenience") else bus.Unregister(event,OnEvent) end
    end
    for _,name in ipairs({"showTutorials","showNPETutorials"}) do
        local db=QoL.Settings()
        db.previousTutorialCVars=db.previousTutorialCVars or {}
        local get=C_CVar and C_CVar.GetCVar or GetCVar
        local set=C_CVar and C_CVar.SetCVar or SetCVar
        if get and set then
            local value=get(name)
            if value and QoL.Enabled("hideTutorials") then
                if db.previousTutorialCVars[name]==nil then db.previousTutorialCVars[name]=value end
                pcall(set,name,"0")
            elseif db.previousTutorialCVars[name]~=nil then
                pcall(set,name,db.previousTutorialCVars[name]); db.previousTutorialCVars[name]=nil
            end
        end
    end
    HookFrames()
    if not QoL.Enabled("skipCinematics") then keyFrame:Hide() end
    if QoL.Enabled("unwrapCollections") then
        for _,kind in ipairs({"mount","pet","toy"}) do QueueUnwrap(kind) end
    else
        for kind,timer in pairs(collectionTimer) do timer:Cancel(); collectionTimer[kind]=nil end
    end
end
