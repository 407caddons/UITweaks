local _, Bars = ...
local snapshots = {}
local function Capture(region, geometry)
    if not region then return end
    local state=snapshots[region]
    if not state then state={alpha=region:GetAlpha()}; snapshots[region]=state end
    if geometry and not state.points then
        state.points={}
        for i=1,region:GetNumPoints() do state.points[i]={region:GetPoint(i)} end
        if region:IsObjectType("Texture") then state.coords={region:GetTexCoord()} end
    end
end
local function Alpha(region, value)
    if not region then return end
    Capture(region)
    if region:GetAlpha() ~= value then region:SetAlpha(value) end
end
local function RestoreRegion(region)
    local state=snapshots[region]
    if not state then return end
    region:SetAlpha(state.alpha)
    if state.points then
        region:ClearAllPoints()
        for _,point in ipairs(state.points) do region:SetPoint(unpack(point)) end
    end
    if state.coords then region:SetTexCoord(unpack(state.coords)) end
    snapshots[region]=nil
end
local masked = {}
function Bars.Skin(button, s)
    if InCombatLockdown() then return end
    local overlay=button.TextOverlayContainer
    Alpha(button.HotKey or (overlay and overlay.HotKey), s.hideBindings and 0 or 1)
    Alpha(button.Name, s.hideMacros and 0 or 1)
    if s.square then
        for _,key in ipairs({"NormalTexture", "SlotArt", "SlotBackground", "Border"}) do Alpha(button[key], 0) end
        local icon=button.icon or button.Icon
        if icon then
            Capture(icon,true)
            icon:ClearAllPoints(); icon:SetAllPoints(button)
            icon:SetTexCoord(.07,.93,.07,.93)
            if button.IconMask and icon.RemoveMaskTexture and not masked[icon] then
                icon:RemoveMaskTexture(button.IconMask); masked[icon]=button.IconMask
            end
            -- Cooldowns keep their native anchors and handlers. Never enter
            -- their layout callbacks from addon execution.
        end
    else
        Bars.RestoreButton(button)
        Alpha(button.HotKey or (overlay and overlay.HotKey), s.hideBindings and 0 or 1)
        Alpha(button.Name, s.hideMacros and 0 or 1)
    end
end
function Bars.RestoreButton(button)
    if InCombatLockdown() then return end
    local overlay=button.TextOverlayContainer
    RestoreRegion(button.HotKey or (overlay and overlay.HotKey))
    for _,key in ipairs({"Name","NormalTexture","SlotArt","SlotBackground","Border"}) do RestoreRegion(button[key]) end
    local icon=button.icon or button.Icon
    if icon and masked[icon] then icon:AddMaskTexture(masked[icon]); masked[icon]=nil end
    RestoreRegion(icon)
end
function Bars.CreateBorder(bar)
    -- No scripts, secure attributes, or addon fields are installed on Blizzard frames.
    local frame=CreateFrame("Frame",nil,bar)
    frame:SetFrameLevel(bar:GetFrameLevel()+1)
    frame.lines={}
    for _,side in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
        local line=frame:CreateTexture(nil,"OVERLAY")
        line:SetColorTexture(.05,.05,.05,1); frame.lines[side]=line
    end
    return frame
end
function Bars.DrawBorder(frame, width, height, show)
    local pixel=PixelUtil.GetNearestPixelSize(1,frame:GetEffectiveScale(),1)
    frame:ClearAllPoints(); frame:SetPoint("TOPLEFT",frame:GetParent(),"TOPLEFT",-pixel,pixel)
    frame:SetSize(width+2*pixel,height+2*pixel)
    for side,line in pairs(frame.lines) do
        line:ClearAllPoints()
        if side=="TOP" or side=="BOTTOM" then
            line:SetPoint(side.."LEFT"); line:SetPoint(side.."RIGHT"); line:SetHeight(pixel)
        else
            line:SetPoint("TOP"..side); line:SetPoint("BOTTOM"..side); line:SetWidth(pixel)
        end
    end
    frame:SetShown(show)
end

function Bars.RestoreBarArt(state)
    for region in pairs(state.artRegions or {}) do RestoreRegion(region) end
    state.artRegions={}
end
function Bars.SkinBarArt(state, s)
    if not s.square then Bars.RestoreBarArt(state); return end
    state.artRegions=state.artRegions or {}
    local function Suppress(region)
        if region then state.artRegions[region]=true; Alpha(region,0) end
    end
    Suppress(state.bar.BorderArt)
    Suppress(state.bar.EndCaps)
    for _,texture in ipairs(state.bar.BackgroundArtTextures or {}) do Suppress(texture) end
    for _,key in ipairs({"HorizontalDividersPool","VerticalDividersPool"}) do
        local pool=state.bar[key]
        if pool and pool.EnumerateActive then
            for divider in pool:EnumerateActive() do Suppress(divider) end
        end
    end
end
