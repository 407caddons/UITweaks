local addonName, Bars = ...
local events=CreateFrame("Frame")
local initialized=false
local editing=false
local function Tick()
    if not initialized then return end
    local active=Bars.EditModeActive()
    if active~=editing then
        editing=active; Bars.Log("Blizzard Edit Mode="..tostring(active))
        if active and not InCombatLockdown() then
            for _,state in pairs(Bars.states) do Bars.Restore(state) end
        end
        Bars.RefreshHandles()
    end
    if active then return end
    if InCombatLockdown() then
        -- Native button and cooldown execution must stay untouched in combat.
        -- Only addon-owned decoration alpha is updated for native bar visibility.
        for _,state in pairs(Bars.states) do
            state.border:SetAlpha(state.bar:IsVisible() and 1 or 0)
        end
    else
        Bars.Apply("watch")
        for _,state in pairs(Bars.states) do state.border:SetAlpha(1) end
    end
end
local function Initialize()
    if initialized then return end
    initialized=true
    Bars.Settings()
    Bars.Log("initialize combat="..tostring(InCombatLockdown()))
    -- Eager setup: never wait for PLAYER_ENTERING_WORLD or a timer to establish the layout.
    Bars.Apply("ADDON_LOADED")
    Bars.RegisterConfig()
    LunaUITweaksAPI.RegisterLayoutParticipant("LunaUITweaks_ActionBars",Bars.RefreshHandles)
    C_Timer.NewTicker(1,Tick)
end
for _,event in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","ADDON_ACTION_BLOCKED","ADDON_ACTION_FORBIDDEN"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,arg1,arg2)
    if event=="ADDON_LOADED" and arg1==addonName then Initialize(); return end
    if not initialized then return end
    if event=="ADDON_ACTION_BLOCKED" or event=="ADDON_ACTION_FORBIDDEN" then
        if arg1==addonName then Bars.Log(event..": "..tostring(arg2)) end
    elseif event=="PLAYER_REGEN_DISABLED" then
        Bars.Log("combat began"); Bars.RefreshHandles()
    elseif event=="ADDON_LOADED" then
        -- Detect action bar replacements that load after this companion.
        if Bars.Conflict() then Bars.Apply("addon conflict") end
    else
        Bars.Log(event.." combat="..tostring(InCombatLockdown())); Bars.Apply(event)
    end
end)
SLASH_LUNAUITWEAKSACTIONBARS1="/luitbars"
SlashCmdList.LUNAUITWEAKSACTIONBARS=function(message)
    message=(message or ""):lower():match("^%s*(.-)%s*$")
    if message=="report" then Bars.ShowReport()
    elseif message=="debug" then local db=Bars.Settings(); db.debug=not db.debug; print("Luna Action Bars debug: "..tostring(db.debug))
    elseif message=="layout" then LunaUITweaksAPI.SetLayoutMode(not LunaUITweaksAPI.IsLayoutModeActive())
    elseif message=="reset" then LunaUITweaksActionBarsDB.bars={}; Bars.Apply("reset all"); if Bars.RefreshConfig then Bars.RefreshConfig() end
    else print("Luna Action Bars: /luitbars layout | report | debug | reset. Settings: /luit → Action Bars.") end
end
