local _, addon = ...
local Layout = { active = false }
addon.LayoutMode = Layout
local targets, handles, participants = {}, {}, {}
local function NotifyParticipant(callback)
    xpcall(callback, geterrorhandler(), Layout.active)
end
local function NotifyParticipants()
    for _, callback in pairs(participants) do NotifyParticipant(callback) end
end
-- Companions keep ownership of their frames, previews and saved variables.
function Layout.RegisterParticipant(key, callback)
    participants[key] = callback
    C_Timer.After(0, function()
        if participants[key] == callback and not InCombatLockdown() then NotifyParticipant(callback) end
    end)
end
local toolbar, ticker, pendingLock
local function Call(module, method, ...)
    local m = addon[module]
    if m and m[method] then m[method](...) end
end

-- Built-in modules own their Layout Mode integration and register it here
-- (companions use RegisterParticipant instead). Called in registration order,
-- which is TOC load order, so frames a module docks to are refreshed first.
--   setLocked(locked)  flip the module's saved lock flags only; runs in combat
--                      and at logout, so it must not touch frames
--   apply(locked)      refresh the module's frames; only runs out of combat
--   combatLocked()     optional; live update when combat forces a lock
local modules, moduleIndex = {}, {}
function Layout.RegisterModule(key, spec)
    local index = moduleIndex[key]
    if not index then
        index = #modules + 1
        moduleIndex[key] = index
    end
    modules[index] = spec
end
local function EachModule(method, ...)
    for _, spec in ipairs(modules) do
        local fn = spec[method]
        if fn then xpcall(fn, geterrorhandler(), ...) end
    end
end
function Layout.IsActive() return Layout.active end

-- Targets retain their own save logic; the common overlay only handles interaction.
function Layout.RegisterTarget(key, getFrame, enabled, save)
    targets[key] = {getFrame = getFrame, enabled = enabled, save = save}
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
        if target and spec.enabled() and target:IsShown() then
            if not handle then
                handle = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
                handle:SetFrameStrata("TOOLTIP")
                handle:SetFrameLevel(100)
                handle:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
                handle:SetBackdropColor(.04, .12, .14, .8)
                handle:SetBackdropBorderColor(.3, .9, .75, 1)
                handle.text = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                handle.text:SetPoint("CENTER")
                handle.text:SetText(key)
                handle:EnableMouse(true)
                handle:RegisterForDrag("LeftButton")
                handle:SetScript("OnDragStart", function(self)
                    if not Layout.active or InCombatLockdown() then return end
                    self.dragging = true
                    self.target:SetMovable(true)
                    self.target:StartMoving()
                end)
                handle:SetScript("OnDragStop", StopDrag)
                handles[key] = handle
            end
            handle.target, handle.spec = target, spec
            -- The overlay is the only drag surface during Layout Mode. This also
            -- keeps deferred combat locking from leaving native drag scripts active.
            target:EnableMouse(false)
            if not handle.dragging then
                handle:ClearAllPoints()
                handle:SetAllPoints(target)
            end
            handle:Show()
        elseif handle then
            StopDrag(handle)
            handle:Hide()
        end
    end
end
local function SetFlags(locked)
    EachModule("setLocked", locked)
end
local function Apply(locked)
    EachModule("apply", locked)
    NotifyParticipants()
    Call("Config", "RefreshFrameControls")
end
function Layout.LockAll()
    Layout.active = false
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    if toolbar then toolbar:Hide() end
    -- Do not mutate protected frames in combat; saved lock flags are safe to set.
    for _, handle in pairs(handles) do
        if not InCombatLockdown() then StopDrag(handle) end
        handle:Hide()
    end
    if not UIThingsDB then return end
    SetFlags(true)
    UIThingsDB.layoutModeActive = nil
    if InCombatLockdown() then
        pendingLock = true
        EachModule("combatLocked")
        return
    end
    pendingLock = false
    Apply(true)
end
function Layout.Start()
    if Layout.active then return end
    if InCombatLockdown() or IsEncounterInProgress() then
        print("LunaUITweaks: Layout Mode is only available outside combat and encounters.")
        return
    end
    Layout.active = true
    UIThingsDB.layoutModeActive = true
    SetFlags(false)
    Apply(false)
    if not toolbar then
        toolbar = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        toolbar:SetSize(440, 64)
        toolbar:SetPoint("TOP", 0, -40)
        toolbar:SetFrameStrata("TOOLTIP")
        toolbar:SetFrameLevel(200)
        toolbar:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
        toolbar:SetBackdropColor(.04, .08, .1, .97)
        local text = toolbar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("TOP", 0, -8)
        text:SetText("Layout Mode — drag handles; docked items follow their frame")
        local done = CreateFrame("Button", nil, toolbar, "UIPanelButtonTemplate")
        done:SetSize(150, 26)
        done:SetPoint("BOTTOM", 0, 6)
        done:SetText("Done / Lock All")
        done:SetScript("OnClick", Layout.LockAll)
    end
    toolbar:Show()
    RefreshHandles()
    ticker = C_Timer.NewTicker(.25, RefreshHandles)
end
function Layout.Toggle() if Layout.active then Layout.LockAll() else Layout.Start() end end

-- Optional API: companions continue to work standalone when Luna is absent.
LunaUITweaksAPI.RegisterLayoutParticipant = Layout.RegisterParticipant
LunaUITweaksAPI.RegisterLayoutTarget = Layout.RegisterTarget
LunaUITweaksAPI.IsLayoutModeActive = Layout.IsActive
LunaUITweaksAPI.SetLayoutMode = function(active)
    if active then Layout.Start() else Layout.LockAll() end
end
addon.EventBus.Register("PLAYER_REGEN_DISABLED", function() if Layout.active then Layout.LockAll() end end, "LayoutMode")
addon.EventBus.Register("PLAYER_REGEN_ENABLED", function()
    if pendingLock then
        for _, handle in pairs(handles) do StopDrag(handle) end
        Layout.LockAll()
    else
        NotifyParticipants() -- includes companions loaded during combat
    end
end, "LayoutMode")
addon.EventBus.Register("PLAYER_LOGOUT", function()
    if UIThingsDB then
        SetFlags(true)
        UIThingsDB.layoutModeActive = nil
    end
end, "LayoutMode")
addon.EventBus.Register("PLAYER_LOGIN", function()
    if not UIThingsDB then return end
    if UIThingsDB.layoutModeActive then
        -- The last session ended with Layout Mode open (e.g. a crash): run a
        -- full lock once modules have initialised.
        C_Timer.After(2, function() if not Layout.active then Layout.LockAll() end end)
    else
        -- Normal login: saved flags only; modules initialise themselves locked.
        SetFlags(true)
    end
end, "LayoutMode")
SLASH_LUNALAYOUT1 = "/lunalayout"
SlashCmdList.LUNALAYOUT = Layout.Toggle
