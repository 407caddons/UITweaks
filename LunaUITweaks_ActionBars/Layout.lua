local _, Bars = ...
Bars.states = {}
local function Points(frame)
    local points = {}
    for i = 1, frame:GetNumPoints() do points[i] = {frame:GetPoint(i)} end
    return points
end
local function RestorePoints(frame, points, nativeGroup)
    local clear = nativeGroup and frame.ClearAllPointsBase or frame.ClearAllPoints
    local set = nativeGroup and frame.SetPointBase or frame.SetPoint
    clear = clear or frame.ClearAllPoints
    set = set or frame.SetPoint
    clear(frame)
    for _, point in ipairs(points) do set(frame, unpack(point)) end
end
local function Anchor(frame, point, relative, relativePoint, x, y, nativeGroup)
    local p, r, rp, px, py = frame:GetPoint(1)
    if frame:GetNumPoints() == 1 and p == point and r == relative and rp == relativePoint and math.abs(px - x) < .01 and math.abs(py - y) < .01 then return false end
    local clear = nativeGroup and frame.ClearAllPointsBase or frame.ClearAllPoints
    local set = nativeGroup and frame.SetPointBase or frame.SetPoint
    clear = clear or frame.ClearAllPoints
    set = set or frame.SetPoint
    clear(frame)
    set(frame, point, relative, relativePoint, x, y)
    return true
end
-- Installed outside combat. The secure OnShow wrapper keeps native updates
-- from revealing a hidden bar without running protected operations in addon Lua.
function Bars.SetHidden(state, hidden)
    if InCombatLockdown() then return end
    if hidden and not state.hideController then
        local controller = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
        controller:SetFrameRef("bar", state.bar)
        controller:WrapScript(state.bar,"OnShow",[[
            if control:GetAttribute("hidden") then self:Hide();return false end
        ]])
        state.hideController = controller
    end
    local controller = state.hideController
    if not controller then return end
    if state.hidden == hidden then
        -- Login/Edit Mode can re-show a hidden bar (Micro Menu, Bag Bar) in a way
        -- the OnShow guard misses. Apply runs every second out of combat, so
        -- re-hide it here; nothing else changes.
        if hidden and state.bar:IsShown() then
            controller:Execute([[ self:GetFrameRef("bar"):Hide() ]])
            if not state.reHideLogged then
                state.reHideLogged = true
                Bars.Log("re-hide " .. tostring(state.bar:GetName()) .. " (shown again by the game)")
            end
        end
        return
    end
    if hidden then state.beforeHideShown = state.bar:IsShown() end
    state.hidden = hidden
    controller:SetAttribute("hidden", hidden)
    local show = not hidden and state.beforeHideShown
    if not hidden then
        local visibility = state.bar.visibility
        if visibility == "Hidden" or visibility == "InCombat" then show = false
        elseif visibility == "OutOfCombat" then show = true end
    end
    if not hidden and state.bar == PetActionBar and PetHasActionBar and not PetHasActionBar() then show = false end
    controller:SetAttribute("restore-shown", not not show)
    controller:Execute([[
        local bar=self:GetFrameRef("bar")
        if self:GetAttribute("hidden") then bar:Hide()
        elseif self:GetAttribute("restore-shown") then bar:Show() end
    ]])
    Bars.Log((hidden and "hide " or "unhide ") .. tostring(state.bar:GetName()))
end
function Bars.Discover(key)
    local bar = _G[key]
    local definition = Bars.Definition(key)
    local kind = definition and definition.kind
    if not bar or (kind ~= "group" and not bar.actionButtons) then return end
    if Bars.states[key] then return Bars.states[key] end
    if kind == "group" and (bar:GetWidth() <= 0 or bar:GetHeight() <= 0) then return end
    local state = {bar = bar, kind = kind, buttons = {}, originals = {}}
    local candidates = kind == "group" and {bar} or bar.actionButtons
    for _, button in ipairs(candidates) do
        if kind == "group" or button.container then
            state.buttons[#state.buttons + 1] = button
            state.originals[button] = {points = Points(button), scale = button:GetScale(), ignoreScale = button:IsIgnoringParentScale()}
        end
    end
    if #state.buttons == 0 then return end
    -- Keep the native parent chain for secure action paging and visibility. Only
    -- anchor geometry is independent of Blizzard's resizable container hierarchy.
    -- Blizzard's ResizeLayoutFrame traverses native bar children. Keep all addon
    -- frames outside that hierarchy so it never reads addon-owned Lua fields.
    state.anchor = CreateFrame("Frame", nil, UIParent)
    state.anchor:SetIgnoreParentScale(true)
    state.border = Bars.CreateBorder(state.anchor)
    state.border:Hide()
    Bars.states[key] = state
    Bars.Log("discovered " .. key .. " buttons=" .. #state.buttons)
    return state
end
function Bars.CaptureOriginals(state)
    if state.active or InCombatLockdown() then return end
    -- Native Edit Mode (or another owner while Luna is paused) may have changed
    -- this layout since discovery. Snapshot immediately before taking control.
    for _, button in ipairs(state.buttons) do
        state.originals[button] = {points = Points(button), scale = button:GetScale(), ignoreScale = button:IsIgnoringParentScale()}
    end
end
function Bars.Restore(state)
    if not state.active or InCombatLockdown() then return end
    for _, button in ipairs(state.buttons) do
        local saved = state.originals[button]
        RestorePoints(button, saved.points, state.kind == "group")
        button:SetIgnoreParentScale(saved.ignoreScale)
        local setScale = state.kind == "group" and button.SetScaleBase or button.SetScale
        setScale = setScale or button.SetScale
        setScale(button, saved.scale)
        if state.kind ~= "group" then Bars.RestoreButton(button) end
    end
    Bars.RestoreBarArt(state)
    state.border:Hide()
    state.anchor:Hide()
    state.active = false
    Bars.SetHidden(state, false)
end
function Bars.Apply(reason)
    local db = Bars.Settings()
    if InCombatLockdown() then
        if not Bars.pending then Bars.Log("layout deferred: " .. (reason or "update")) end
        Bars.pending = true
        return
    end
    Bars.pending = false
    if Bars.EditModeActive() then return end
    local conflict = Bars.Conflict()
    if conflict ~= Bars.conflict then
        Bars.conflict = conflict
        Bars.Log("bar addon conflict: " .. tostring(conflict))
    end
    local corrections = 0
    for _, definition in ipairs(Bars.definitions) do
        local key = definition[1]
        local state = Bars.states[key]
        local s = db.bars[key]
        if db.enabled and s.enabled and not conflict then
            state = state or Bars.Discover(key)
            if state then
                Bars.CaptureOriginals(state)
                local bar = state.bar
                -- Native bar/button parents, actions, visibility rules and event handlers remain intact.
                local visible = Bars.VisibleCount(state.buttons)
                local width, height = Bars.StateGeometry(s, state)
                local columns = math.min(s.columns, #state.buttons)
                local anchor = state.anchor
                local uiScale = UIParent:GetEffectiveScale()
                anchor:SetScale(uiScale)
                Anchor(anchor, "CENTER", UIParent, "CENTER", s.x, s.y)
                anchor:SetSize(width, height)
                anchor:Show()
                for i, button in ipairs(state.buttons) do
                    button:SetIgnoreParentScale(true)
                    local dimension = state.kind == "group" and button:GetHeight() or button:GetWidth()
                    local scale = s.size * uiScale / dimension
                    if button:GetScale() ~= scale then
                        local setScale = state.kind == "group" and button.SetScaleBase or button.SetScale
                        setScale = setScale or button.SetScale
                        setScale(button, scale)
                    end
                    local factor = uiScale / button:GetEffectiveScale()
                    local x = ((i - 1) % columns) * (s.size + s.spacing) * factor
                    local y = -math.floor((i - 1) / columns) * (s.size + s.spacing) * factor
                    if Anchor(button, "TOPLEFT", anchor, "TOPLEFT", x, y, state.kind == "group") then corrections = corrections + 1 end
                    if state.kind ~= "group" then Bars.Skin(button, s) end
                end
                if state.kind ~= "group" then Bars.SkinBarArt(state, s) end
                Bars.DrawBorder(state.border, width, height, s.border and visible > 0 and bar:IsVisible())
                state.active = true
            end
        elseif state then Bars.Restore(state) end
        local hidden = db.enabled and s.hidden and not conflict
        if hidden then state = state or Bars.Discover(key) end
        if state then
            Bars.SetHidden(state, not not hidden)
            if state.active then state.border:SetShown(s.border and Bars.VisibleCount(state.buttons) > 0 and state.bar:IsVisible()) end
        end
    end
    Bars.corrections = (Bars.corrections or 0) + corrections
    if corrections > 0 and reason ~= "watch" then Bars.Log((reason or "apply") .. ": corrected anchors=" .. corrections) end
    Bars.RefreshHandles()
end
local handles = {}
function Bars.RefreshHandles()
    local active = LunaUITweaksAPI.IsLayoutModeActive() and not InCombatLockdown() and not Bars.EditModeActive()
    for _, definition in ipairs(Bars.definitions) do
        local key, label = definition[1], definition[2]
        local state = Bars.states[key]
        local handle = handles[key]
        if active and state and state.active and (state.bar:IsShown() or key == "PetActionBar" or state.hidden) then
            if not handle then
                handle = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
                handle:SetFrameStrata("TOOLTIP")
                handle:SetMovable(true)
                handle:EnableMouse(true)
                handle:RegisterForDrag("LeftButton")
                handle:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
                handle:SetBackdropColor(.04, .12, .14, .8)
                handle:SetBackdropBorderColor(.35, .9, .76, 1)
                handle.text = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                handle.text:SetPoint("CENTER")
                handle.text:SetText(label)
                handle:SetScript("OnDragStart", function(self)
                    if InCombatLockdown() or Bars.EditModeActive() then return end
                    self.dragging = true
                    self:StartMoving()
                end)
                handle:SetScript("OnDragStop", function(self)
                    self:StopMovingOrSizing()
                    if not self.dragging then return end
                    self.dragging = false
                    local x, y = self:GetCenter()
                    local ux, uy = UIParent:GetCenter()
                    local s = Bars.Settings().bars[key]
                    s.x = math.floor(x - ux + .5)
                    s.y = math.floor(y - uy + .5)
                    Bars.Apply("drag")
                    if Bars.RefreshConfig then
                        Bars.RefreshConfig()
                    end
                end)
                handles[key] = handle
            end
            if not handle.dragging then
                local s = Bars.Settings().bars[key]
                local width, height = Bars.StateGeometry(s, state)
                if width == 0 or height == 0 then width, height = Bars.Geometry(s, #state.buttons) end
                handle:ClearAllPoints()
                handle:SetPoint("CENTER", UIParent, "CENTER", s.x, s.y)
                handle:SetSize(width, height)
            end
            handle:Show()
        elseif handle then
            if handle.dragging then handle:GetScript("OnDragStop")(handle) end
            handle:Hide()
        end
    end
end
