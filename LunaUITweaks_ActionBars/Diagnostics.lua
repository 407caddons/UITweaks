local _, Bars = ...
function Bars.Report()
    local _,build,_,interface=GetBuildInfo()
    local conflict=Bars.Conflict() or "none"
    local lines={"Luna Action Bars prototype", "Build="..tostring(build).." Interface="..tostring(interface),
        "Combat="..tostring(InCombatLockdown()).." EditMode="..tostring(Bars.EditModeActive()).." Conflict="..tostring(conflict),
        "Pending="..tostring(Bars.pending).." Anchor corrections="..tostring(Bars.corrections or 0)}
    local function Security(owner,key,label)
        if not issecurevariable or not owner then return end
        local secure,source=issecurevariable(owner,key)
        lines[#lines+1]=label.." secure="..tostring(secure).." taint="..tostring(source)
    end
    local db=Bars.Settings()
    for _,definition in ipairs(Bars.definitions) do
        local key=definition[1]; local state=Bars.states[key]; local s=db.bars[key]
        lines[#lines+1]=string.format("%s enabled=%s size=%g spacing=%g columns=%d x=%g y=%g discovered=%s active=%s",key,tostring(s.enabled),s.size,s.spacing,s.columns,s.x,s.y,tostring(state~=nil),tostring(state and state.active or false))
        lines[#lines+1]=" hidden="..tostring(s.hidden)
        if state then
            local first=state.buttons[1]
            Security(state.bar,"actionButtons",key..".actionButtons")
            Security(state.bar,"shownButtonContainers",key..".shownButtonContainers")
            for _,method in ipairs({"OnEvent","UpdateAction","SetShown"}) do Security(first,method,key.." button."..method) end
            Security(first.cooldown,"SetCooldown",key.." cooldown.SetCooldown")
        end
        -- Protected geometry is deliberately not queried during combat diagnostics.
        if state and not InCombatLockdown() then
            local p,r,rp,x,y=state.anchor:GetPoint(1)
            lines[#lines+1]=string.format(" actual=%s %s %s %s %s scale=%s shown=%s",tostring(p),tostring(r and r:GetName()),tostring(rp),tostring(x),tostring(y),tostring(state.anchor:GetScale()),tostring(state.bar:IsShown()))
            local first=state.buttons[1]
            lines[#lines+1]=string.format(" nativeBarScale=%s containerScale=%s buttonScale=%s ignoreParentScale=%s",tostring(state.bar:GetScale()),tostring(first.container and first.container:GetScale() or "n/a"),tostring(first:GetScale()),tostring(first:IsIgnoringParentScale()))
        end
    end
    lines[#lines+1]="Recent events:"
    for _,line in ipairs(db.log or {}) do lines[#lines+1]=line end
    return table.concat(lines,"\n")
end
local reportFrame
function Bars.ShowReport()
    if not reportFrame then
        reportFrame=CreateFrame("Frame","LunaUITweaksActionBarsReport",UIParent,"BackdropTemplate")
        reportFrame:SetSize(720,480); reportFrame:SetPoint("CENTER"); reportFrame:SetFrameStrata("DIALOG")
        reportFrame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"}); reportFrame:SetBackdropColor(.04,.06,.08,1)
        local title=reportFrame:CreateFontString(nil,"OVERLAY","GameFontNormal"); title:SetPoint("TOP",0,-12); title:SetText("Action Bars diagnostics — Ctrl+A, Ctrl+C to copy")
        local scroll=CreateFrame("ScrollFrame",nil,reportFrame,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",16,-40); scroll:SetPoint("BOTTOMRIGHT",-35,45)
        local edit=CreateFrame("EditBox",nil,scroll); edit:SetMultiLine(true); edit:SetFontObject(ChatFontNormal); edit:SetWidth(660); edit:SetAutoFocus(false)
        scroll:SetScrollChild(edit); reportFrame.edit=edit
        edit:SetScript("OnEscapePressed",function() reportFrame:Hide() end)
        local close=CreateFrame("Button",nil,reportFrame,"UIPanelButtonTemplate"); close:SetSize(100,24); close:SetPoint("BOTTOM",0,10); close:SetText("Close"); close:SetScript("OnClick",function() reportFrame:Hide() end)
        UISpecialFrames[#UISpecialFrames+1]="LunaUITweaksActionBarsReport"
    end
    reportFrame.edit:SetText(Bars.Report()); reportFrame:Show(); reportFrame.edit:SetFocus(); reportFrame.edit:HighlightText()
end
