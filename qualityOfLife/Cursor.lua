local _, addon = ...
local QoL=addon.QualityOfLife
local Cursor={}
QoL.Cursor=Cursor; QoL.AddModule(Cursor)
local frame, texture
local lastX,lastY,lastScale
local function Tick(self)
    local db=QoL.Settings()
    if not QoL.Enabled("cursor") then self:Hide(); return end
    local hidden=IsMouselooking and IsMouselooking()
    texture:SetShown(not hidden)
    if hidden then return end
    local x,y=GetCursorPosition()
    local scale=UIParent:GetEffectiveScale()
    if x~=lastX or y~=lastY or scale~=lastScale then
        self:ClearAllPoints(); self:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x/scale,y/scale)
        lastX,lastY,lastScale=x,y,scale
    end
end
function Cursor.UpdateSettings()
    if not QoL.Enabled("cursor") then
        if frame then frame:SetScript("OnUpdate",nil); frame:Hide() end
        return
    end
    if not frame then
        frame=CreateFrame("Frame","LunaCursorRing",UIParent)
        frame:SetFrameStrata("TOOLTIP"); frame:SetFrameLevel(200); frame:EnableMouse(false)
        texture=frame:CreateTexture(nil,"OVERLAY"); texture:SetAllPoints()
        texture:SetTexture("Interface\\AddOns\\LunaUITweaks\\media\\cursor-ring.tga")
    end
    local db=QoL.Settings()
    frame:SetSize(db.cursorSize or 28,db.cursorSize or 28)
    local color=db.cursorColor or {r=0,g=1,b=1}
    if db.cursorClassColor then
        local _,class=UnitClass("player")
        color=(RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]) or color
    end
    texture:SetVertexColor(color.r,color.g,color.b,db.cursorAlpha or 1)
    frame:SetScript("OnUpdate",Tick); Tick(frame); frame:Show()
end
