local addon = _G.LunaUITweaks
addon.ConfigSetup = addon.ConfigSetup or {}
local Proc, Sounds, Helpers = addon.ProcAlerts, addon.BuffAlerts, addon.ConfigHelpers
function addon.ConfigSetup.ProcAlerts(panel, navButton)
    Helpers.CreateResetButton(panel,"procAlerts")
    local selected, sound, refresh = nil, {preset="none"}, nil
    local function DB() return UIThingsDB.procAlerts end
    local function Label(parent,text,x,y,width)
        local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        f:SetPoint("TOPLEFT",x,y); f:SetWidth(width or 320); f:SetJustifyH("LEFT"); f:SetText(text)
        return f
    end
    local function Button(parent,text,x,y,width,fn)
        local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
        b:SetPoint("TOPLEFT",x,y); b:SetSize(width,25); b:SetText(text); b:SetScript("OnClick",fn); return b
    end
    local function Check(text,x,y,fn)
        local b=CreateFrame("CheckButton",nil,panel,"ChatConfigCheckButtonTemplate")
        b:SetPoint("TOPLEFT",x,y); b.Text:SetText(text); b:SetScript("OnClick",fn); return b
    end
    local function SpellName(id)
        return (C_Spell and C_Spell.GetSpellName(id)) or ("Spell "..id)
    end
    local title=Label(panel,"Proc Alerts",16,-16,500); title:SetFontObject("GameFontNormalHuge")
    Label(panel,"Play a sound when Blizzard makes an ability glow on your action bars.",20,-46,580)
    local enabled=Check("Enable proc sounds",16,-65,function(self)
        DB().enabled=not not self:GetChecked(); Proc.UpdateSettings(); refresh()
    end)
    local combatOnly=Check("Combat only",230,-65,function(self)
        DB().combatOnly=not not self:GetChecked(); Proc.UpdateSettings()
    end)
    Label(panel,"Sound channel",20,-107,110)
    local channel=CreateFrame("Frame",nil,panel,"UIDropDownMenuTemplate")
    channel:SetPoint("TOPLEFT",120,-95); UIDropDownMenu_SetWidth(channel,130)
    UIDropDownMenu_Initialize(channel,function()
        for _,value in ipairs({"Master","SFX","Dialog"}) do
            local info=UIDropDownMenu_CreateInfo(); info.text=value; info.checked=DB().outputChannel==value
            info.func=function() DB().outputChannel=value; UIDropDownMenu_SetText(channel,value) end
            UIDropDownMenu_AddButton(info)
        end
    end)
    local listen=Button(panel,"Listen for procs",20,-135,150,function()
        Proc.SetListening(not Proc.IsListening()); refresh()
    end)
    Proc.OnListeningChanged=function(value)
        listen:SetText(value and "Stop listening" or "Listen for procs")
    end
    Button(panel,"Refresh discoveries",180,-135,160,function() refresh() end)
    Label(panel,"Listening lasts two minutes and works while this window is closed. Refresh after combat to see new procs.",20,-169,590)

    local scroll=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",20,-207); scroll:SetPoint("BOTTOMLEFT",20,75); scroll:SetWidth(225)
    local list=CreateFrame("Frame",nil,scroll); list:SetSize(220,1); scroll:SetScrollChild(list)
    local rows={}
    local editor=CreateFrame("Frame",nil,panel)
    editor:SetPoint("TOPLEFT",280,-207); editor:SetPoint("BOTTOMRIGHT",-15,75)
    local selectedName=Label(editor,"New rule",0,0,320)
    Label(editor,"Ability spell ID",0,-32,200)
    local spell=CreateFrame("EditBox",nil,editor,"InputBoxTemplate")
    spell:SetPoint("TOPLEFT",5,-53); spell:SetSize(180,24); spell:SetAutoFocus(false); spell:SetMaxLetters(12)
    local ruleEnabled=CreateFrame("CheckButton",nil,editor,"ChatConfigCheckButtonTemplate")
    ruleEnabled:SetPoint("TOPLEFT",0,-85); ruleEnabled.Text:SetText("Enable this rule"); ruleEnabled:SetChecked(true)
    Label(editor,"Sound",0,-121,200)
    local soundDD=CreateFrame("Frame",nil,editor,"UIDropDownMenuTemplate")
    soundDD:SetPoint("TOPLEFT",-16,-138); UIDropDownMenu_SetWidth(soundDD,225)
    UIDropDownMenu_Initialize(soundDD,function()
        for _,option in ipairs(Sounds.GetSoundOptions()) do
            local value,label=option.value,option.label
            local info=UIDropDownMenu_CreateInfo(); info.text=label; info.checked=sound.preset==value
            info.func=function() sound={preset=value}; UIDropDownMenu_SetText(soundDD,label) end
            UIDropDownMenu_AddButton(info)
        end
    end)
    local status=Label(editor,"",0,-300,310)
    local function Status(message,ok)
        status:SetText(message or ""); status:SetTextColor(ok and .4 or 1,ok and 1 or .3,.4)
    end
    local function Edit(id)
        selected=id; sound={preset="none"}; ruleEnabled:SetChecked(true)
        for _,rule in ipairs(DB().rules) do
            if rule.spellID==id then sound={preset=rule.sound and rule.sound.preset or "none"}; ruleEnabled:SetChecked(rule.enabled~=false); break end
        end
        spell:SetText(id and tostring(id) or ""); spell:ClearFocus()
        selectedName:SetText(id and SpellName(id) or "New rule")
        UIDropDownMenu_SetText(soundDD,Sounds.GetSoundLabel(sound)); status:SetText("")
    end
    spell:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    spell:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    Button(editor,"Test sound",0,-180,110,function()
        local ok,err=Proc.TestSound(sound); Status(err or "Sound played.",ok)
    end)
    Button(editor,"Save",0,-217,90,function()
        local id=tonumber(spell:GetText())
        if selected and selected~=id then Status("Use New rule to add a different spell ID.",false); return end
        local ok,err=Proc.SaveRule(id,sound,ruleEnabled:GetChecked())
        if ok then selected=id; selectedName:SetText(SpellName(id)); refresh() end
        Status(err or "Rule saved.",ok)
    end)
    Button(editor,"Delete",100,-217,90,function()
        if selected then Proc.RemoveRule(selected); Edit(nil); refresh(); Status("Rule removed.",true) end
    end)
    Button(editor,"New rule",200,-217,100,function() Edit(nil) end)
    Label(editor,"Register custom sound files in Buff Alerts; they also appear in this sound list.",0,-256,310)
    local function Row(index,text,id)
        local row=rows[index]
        if not row then
            row=CreateFrame("Button",nil,list,"UIPanelButtonTemplate"); row:SetSize(220,27)
            row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(20,20); row.icon:SetPoint("LEFT",3,0)
            row:GetFontString():SetPoint("LEFT",row.icon,"RIGHT",5,0)
            row:GetFontString():SetPoint("RIGHT",-4,0); row:GetFontString():SetJustifyH("LEFT")
            row:SetScript("OnClick",function(self) Edit(self.spellID) end)
            row:SetScript("OnEnter",function(self)
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(SpellName(self.spellID))
                GameTooltip:AddLine("Spell ID: "..self.spellID); GameTooltip:Show()
            end)
            row:SetScript("OnLeave",GameTooltip_Hide)
            rows[index]=row
        end
        row.spellID=id; row:SetPoint("TOPLEFT",0,-(index-1)*29); row:SetText(text)
        row.icon:SetTexture(C_Spell and C_Spell.GetSpellTexture(id) or 134400); row:Show()
    end
    refresh=function()
        enabled:SetChecked(DB().enabled); combatOnly:SetChecked(DB().combatOnly)
        UIDropDownMenu_SetText(channel,DB().outputChannel or "Master")
        listen:SetText(Proc.IsListening() and "Stop listening" or "Listen for procs")
        Helpers.UpdateModuleVisuals(panel,navButton,DB().enabled)
        for _,row in ipairs(rows) do row:Hide() end
        local index,configured=0,{}
        for _,rule in ipairs(DB().rules) do
            index=index+1; configured[rule.spellID]=true
            Row(index,(rule.enabled==false and "[off] " or "")..SpellName(rule.spellID),rule.spellID)
        end
        for _,id in ipairs(Proc.GetDiscovered()) do
            if not configured[id] then index=index+1; Row(index,"[new] "..SpellName(id),id) end
        end
        list:SetHeight(math.max(1,index*29))
    end
    Label(panel,"Only Blizzard proc glows are detected. A proc refreshing an existing glow may not send a new event.",20,-195,590)
    panel:HookScript("OnShow",function() Proc.UpdateSettings(); refresh() end)
    panel:HookScript("OnHide",function() spell:ClearFocus(); GameTooltip:Hide() end)
    Edit(nil); refresh()
end
