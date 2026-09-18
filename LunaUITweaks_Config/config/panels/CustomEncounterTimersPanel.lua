local addon = _G.LunaUITweaks
local Custom, H = addon.CustomEncounterTimers, addon.ConfigHelpers

function Custom.CreateEditor(parent, y)
    local root = CreateFrame("Frame", nil, parent)
    root:SetPoint("TOPLEFT", 0, y); root:SetSize(550, 860)
    H.CreateSectionHeader(root, "Custom timers", 0)
    local function Label(owner, text, x, top, width)
        local f=owner:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        f:SetPoint("TOPLEFT",x,top); f:SetWidth(width); f:SetJustifyH("LEFT"); f:SetText(text)
        return f
    end
    local function Button(owner,text,x,top,width,callback)
        local f=CreateFrame("Button",nil,owner,"UIPanelButtonTemplate")
        f:SetPoint("TOPLEFT",x,top); f:SetSize(width,26); f:SetText(text); f:SetScript("OnClick",callback)
        return f
    end
    Label(root,"Independent timers, sorted A–Z. Green = enabled; grey = disabled. Timers run only in combat.",20,-32,510)
    local list=CreateFrame("ScrollFrame",nil,root,"UIPanelScrollFrameTemplate")
    list:SetPoint("TOPLEFT",20,-110); list:SetSize(175,620)
    local child=CreateFrame("Frame",nil,list); child:SetSize(175,1); list:SetScrollChild(child)
    local rows={}
    local empty=Label(root,"No custom timers. Click Add timer to create one.",20,-118,170)
    local editor=CreateFrame("Frame",nil,root); editor:SetPoint("TOPLEFT",235,-78); editor:SetSize(300,660)
    local selected, loading, confirmDelete, ownsPicker
    local drafts={}
    local message=Label(root,"Select a timer or click Add timer.",20,-752,510)
    local function Dirty()
        if loading or selected==nil then return end
        confirmDelete=nil
        message:SetText("Unsaved changes — Save to apply. Drafts are kept while switching timers.")
    end
    local function Edit(label,x,top,width,max)
        Label(editor,label,x,top,width)
        local f=CreateFrame("EditBox",nil,editor,"InputBoxTemplate")
        f:SetPoint("TOPLEFT",x+4,top-24); f:SetSize(width-4,24); f:SetAutoFocus(false)
        f:SetMaxLetters(max or 200)
        f:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
        f:SetScript("OnTextChanged",function(_,user) if user then Dirty() end end)
        return f
    end
    local name=Edit("Timer name",0,0,300)
    local enabled=CreateFrame("CheckButton",nil,editor,"ChatConfigCheckButtonTemplate")
    enabled:SetPoint("TOPLEFT",0,-58); enabled.Text:SetText("Enable this timer"); enabled:SetScript("OnClick",Dirty)
    local function Dropdown(label,top)
        Label(editor,label,0,top,300)
        local f=CreateFrame("Frame",nil,editor,"UIDropDownMenuTemplate")
        f:SetPoint("TOPLEFT",-16,top-20); UIDropDownMenu_SetWidth(f,275)
        return f
    end
    local triggerDD=Dropdown("Start on",-98)
    local trigger="combat"
    local triggerNames={combat="Combat start",encounter="Encounter start",cast="Your spell cast"}
    local spell=Edit("Your cast spell name or ID",0,-161,300,200)
    local popup=CreateFrame("Frame",nil,editor,"BackdropTemplate")
    popup:SetPoint("TOPLEFT",spell,"BOTTOMLEFT",0,-2); popup:SetSize(300,1)
    popup:SetFrameStrata("DIALOG"); popup:SetFrameLevel(100)
    popup:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    popup:SetBackdropColor(.025,.04,.05,.98); popup:SetBackdropBorderColor(.3,.5,.5,1); popup:Hide()
    local matches, resultRows, searchGeneration = {}, {}, 0
    local function HideSearch()
        searchGeneration=searchGeneration+1; popup:Hide()
    end
    local function PickSpell(id)
        spell:SetText(tostring(id)); spell:ClearFocus(); HideSearch(); Dirty()
    end
    local function UpdateSearch()
        if trigger~="cast" or not spell:HasFocus() or not editor:IsShown() then HideSearch(); return end
        matches=addon.BuffAlerts.FindSpellMatches(spell:GetText(),8)
        for i=1,8 do
            local row=resultRows[i]
            if not row then
                row=CreateFrame("Button",nil,popup); row:SetSize(296,28); row:SetPoint("TOPLEFT",2,-2-(i-1)*28)
                row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD")
                row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(22,22); row.icon:SetPoint("LEFT",3,0)
                row.text=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
                row.text:SetPoint("LEFT",row.icon,"RIGHT",6,0); row.text:SetWidth(262); row.text:SetJustifyH("LEFT")
                row.text:SetWordWrap(false)
                row:SetScript("OnClick",function(self) PickSpell(self.spellID) end)
                resultRows[i]=row
            end
            local match=matches[i]
            if match then
                row.spellID=match.spellID; row.icon:SetTexture(match.iconID or 134376)
                row.text:SetText(match.name.." ("..match.spellID..")"); row:Show()
            else row:Hide() end
        end
        popup:SetHeight(#matches*28+4); popup:SetShown(#matches>0)
    end
    if addon.BuffAlerts and addon.BuffAlerts.FindSpellMatches then
        spell:SetScript("OnTextChanged",function(_,user)
            if not user then return end
            Dirty(); UpdateSearch(); searchGeneration=searchGeneration+1
            local generation=searchGeneration
            C_Timer.After(.3,function()
                if generation==searchGeneration and spell:HasFocus() and editor:IsShown() and trigger=="cast" then
                    addon.BuffAlerts.SearchEncounterJournal(spell:GetText())
                end
            end)
        end)
        spell:SetScript("OnEditFocusGained",UpdateSearch)
        spell:SetScript("OnEnterPressed",function()
            if #matches==1 and popup:IsShown() then PickSpell(matches[1].spellID)
            else spell:ClearFocus(); HideSearch() end
        end)
        addon.BuffAlerts.SetSearchUpdateCallback(function(query)
            if spell:HasFocus() and editor:IsShown() and spell:GetText():match("^%s*(.-)%s*$")==query then UpdateSearch() end
        end,root)
    end
    spell:SetScript("OnEscapePressed",function() spell:ClearFocus(); HideSearch() end)
    local first=Edit("First delay (20 or 2:20)",0,-223,145,8)
    local repeatBox=Edit("Repeat (blank = once)",155,-223,145,8)
    local subzone=Edit("Subzone name",0,-288,300)
    local map=Edit("Instance/map ID",0,-350,125,10)
    Label(editor,"Clear both location fields for anywhere.",0,-402,300)
    local countdownDD=Dropdown("Countdown",-420)
    local countdown="default"
    local expiryDD=Dropdown("Expiry sound",-482)
    local expiry="none"
    local defaultColor=CreateFrame("CheckButton",nil,editor,"ChatConfigCheckButtonTemplate")
    defaultColor:SetPoint("TOPLEFT",0,-547); defaultColor.Text:SetText("Use default colour")
    defaultColor:SetScript("OnClick",Dirty)
    local color={r=1,g=1,b=1}
    local swatch=H.CreateColorSwatch(editor,"Override colour",color,function()
        defaultColor:SetChecked(false); Dirty()
    end,0,-584,false)
    if swatch then swatch:HookScript("OnClick",function() ownsPicker=true end) end
    local function ClosePicker()
        if ownsPicker and ColorPickerFrame then ColorPickerFrame:Hide() end
        ownsPicker=false
    end
    local function Read()
        return {name=name:GetText(),enabled=not not enabled:GetChecked(),trigger=trigger,
            spell=spell:GetText(),first=first:GetText(),repeatText=repeatBox:GetText(),
            subzone=subzone:GetText(),map=map:GetText(),countdown=countdown,expiry=expiry,
            defaultColor=not not defaultColor:GetChecked(),color={r=color.r,g=color.g,b=color.b}}
    end
    local function Values(timer)
        return {name=timer.name,enabled=timer.enabled,trigger=timer.trigger,
            spell=timer.spellID and tostring(timer.spellID) or "",first=Custom.FormatTime(timer.first),
            repeatText=timer.interval and Custom.FormatTime(timer.interval) or "",
            subzone=timer.location and timer.location.subzone or "",
            map=timer.location and tostring(timer.location.instanceID) or "",
            countdown=timer.countdown==nil and "default" or (timer.countdown and "on" or "off"),
            expiry=timer.expirySound or "none",defaultColor=not timer.color,
            color=timer.color or UIThingsDB.encounterBars.customColor}
    end
    local function Find(id)
        for _,timer in ipairs(Custom.GetTimers()) do if timer.id==id then return timer end end
    end
    local Refresh, Select
    Select=function(id, discard)
        HideSearch()
        ClosePicker()
        if selected~=nil and not discard then drafts[selected]=Read() end
        selected=id; confirmDelete=nil; loading=true
        local timer=id and Find(id)
        local v=id~=nil and (drafts[id] or (timer and Values(timer)))
        if not v then selected=nil; editor:Hide(); message:SetText("Select a timer or click Add timer.")
        else
            editor:Show()
            name:SetText(v.name); enabled:SetChecked(v.enabled)
            trigger=v.trigger; UIDropDownMenu_SetText(triggerDD,triggerNames[trigger])
            spell:SetText(v.spell); spell:SetEnabled(trigger=="cast")
            first:SetText(v.first); repeatBox:SetText(v.repeatText)
            subzone:SetText(v.subzone); map:SetText(v.map)
            countdown=v.countdown; UIDropDownMenu_SetText(countdownDD,countdown)
            expiry=v.expiry; UIDropDownMenu_SetText(expiryDD,addon.BuffAlerts and addon.BuffAlerts.GetSoundLabel({preset=expiry}) or expiry)
            defaultColor:SetChecked(v.defaultColor)
            color.r,color.g,color.b=v.color.r,v.color.g,v.color.b
            if swatch then swatch.tex:SetColorTexture(color.r,color.g,color.b,1) end
            message:SetText(drafts[id] and "Draft — click Save to apply." or "")
        end
        loading=false; Refresh()
    end
    Refresh=function()
        local timers=Custom.GetSortedTimers()
        empty:SetShown(#timers==0)
        for i,timer in ipairs(timers) do
            local row=rows[i]
            if not row then
                row=CreateFrame("Button",nil,child); row:SetSize(175,34)
                row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetPoint("LEFT",2,0); row.icon:SetSize(26,26)
                row.text=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
                row.text:SetPoint("LEFT",row.icon,"RIGHT",6,0); row.text:SetWidth(137)
                row.text:SetJustifyH("LEFT"); row.text:SetWordWrap(false)
                row.bg=row:CreateTexture(nil,"BACKGROUND"); row.bg:SetAllPoints(); row.bg:SetColorTexture(.12,.3,.3,.65)
                row:SetScript("OnClick",function(self) Select(self.timerID) end)
                rows[i]=row
            end
            row.timerID=timer.id; row:SetPoint("TOPLEFT",0,-(i-1)*34)
            row.icon:SetTexture(Custom.GetIcon(timer)); row.text:SetText(timer.name)
            if timer.enabled then row.text:SetTextColor(.35,.9,.65) else row.text:SetTextColor(.5,.5,.5) end
            row.bg:SetShown(selected==timer.id); row:Show()
        end
        for i=#timers+1,#rows do rows[i]:Hide() end
        child:SetHeight(math.max(1,#timers*34))
    end
    UIDropDownMenu_Initialize(triggerDD,function()
        for _,value in ipairs({"combat","encounter","cast"}) do
            local item=UIDropDownMenu_CreateInfo(); item.text=triggerNames[value]; item.checked=trigger==value
            item.func=function() trigger=value; UIDropDownMenu_SetText(triggerDD,item.text); spell:SetEnabled(value=="cast"); HideSearch(); Dirty() end
            UIDropDownMenu_AddButton(item)
        end
    end)
    UIDropDownMenu_Initialize(countdownDD,function()
        for _,value in ipairs({"default","on","off"}) do
            local item=UIDropDownMenu_CreateInfo(); item.text=value; item.checked=countdown==value
            item.func=function() countdown=value; UIDropDownMenu_SetText(countdownDD,value); Dirty() end
            UIDropDownMenu_AddButton(item)
        end
    end)
    UIDropDownMenu_Initialize(expiryDD,function()
        local options=addon.BuffAlerts and addon.BuffAlerts.GetSoundOptions() or {{value="none",label="None"}}
        for _,option in ipairs(options) do
            local item=UIDropDownMenu_CreateInfo(); item.text=option.label; item.checked=expiry==option.value
            item.func=function() expiry=option.value; UIDropDownMenu_SetText(expiryDD,option.label); Dirty() end
            UIDropDownMenu_AddButton(item)
        end
    end)
    Button(editor,"Use current subzone",140,-374,160,function()
        local location,err=Custom.CaptureLocation()
        if not location then message:SetText(err); return end
        subzone:SetText(location.subzone); map:SetText(tostring(location.instanceID)); Dirty()
    end)
    Button(root,"Add timer",20,-72,175,function()
        if selected==0 then name:SetFocus(); return end
        drafts[0]=drafts[0] or Values({name="New timer",first=20,trigger="combat",enabled=false})
        Select(0); name:SetFocus(); name:HighlightText()
    end)
    Button(editor,"Save",0,-626,90,function()
        local v=Read()
        local repeatText=v.repeatText:match("^%s*(.-)%s*$")
        local interval=repeatText~="" and Custom.ParseTime(repeatText) or nil
        if repeatText~="" and not interval then message:SetText("Invalid repeat interval."); return end
        local data={name=v.name,enabled=v.enabled,trigger=v.trigger,first=Custom.ParseTime(v.first),
            interval=interval,spellID=tonumber(v.spell),expirySound=v.expiry}
        if countdown~="default" then data.countdown=countdown=="on" end
        if not v.defaultColor then data.color=v.color end
        local sub=v.subzone:match("^%s*(.-)%s*$"); local id=v.map:match("^%s*(.-)%s*$")
        if sub~="" or id~="" then data.location={subzone=sub,instanceID=tonumber(id)} end
        local saved,err=Custom.SaveTimer(selected~=0 and selected or nil,data)
        if not saved then message:SetText(err); return end
        drafts[selected]=nil; Select(saved.id,true); addon.EncounterBars.UpdateSettings()
        message:SetText("Saved. Starts on the next matching trigger; an active timer is cancelled.")
    end)
    Button(editor,"Revert",100,-626,90,function()
        drafts[selected]=nil; Select(selected,true)
    end)
    Button(editor,"Delete",200,-626,90,function()
        if selected==nil then return end
        if confirmDelete~=selected then confirmDelete=selected; message:SetText("Click Delete again to remove this timer."); return end
        Custom.DeleteTimer(selected); drafts[selected]=nil; Select(nil,true); addon.EncounterBars.UpdateSettings()
    end)
    H.CreateColorSwatch(root,"Default custom timer colour",UIThingsDB.encounterBars.customColor,
        addon.EncounterBars.UpdateSettings,20,-820)
    root:SetScript("OnHide",function()
        HideSearch()
        for _,box in ipairs({name,spell,first,repeatBox,subzone,map}) do box:ClearFocus() end
        ClosePicker()
    end)
    root:SetScript("OnShow",function()
        if selected and selected~=0 and not Find(selected) then Select(nil,true) else Refresh() end
    end)
    Select(nil)
    return root
end
