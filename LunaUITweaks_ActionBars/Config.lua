local _, Bars = ...
function Bars.RegisterConfig()
    LunaUITweaksAPI.RegisterConfigPanel("actionBars","Action Bars","Interface\\Icons\\Ability_DualWield",function(panel)
        local root=panel
        local scroll=CreateFrame("ScrollFrame",nil,root,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",root,"TOPLEFT",0,0)
        scroll:SetPoint("BOTTOMRIGHT",root,"BOTTOMRIGHT",-30,8)
        panel=CreateFrame("Frame",nil,scroll)
        panel:SetSize(math.max(1,root:GetWidth()-30),780)
        scroll:SetScrollChild(panel)
        local selected=1
        local controls={}
        local function Label(text,x,y,width)
            local label=panel:CreateFontString(nil,"OVERLAY","GameFontHighlight")
            label:SetPoint("TOPLEFT",x,y); label:SetWidth(width or 580); label:SetJustifyH("LEFT"); label:SetText(text)
            return label
        end
        local function Button(text,x,y,width,callback)
            local button=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
            button:SetPoint("TOPLEFT",x,y); button:SetSize(width,24); button:SetText(text); button:SetScript("OnClick",callback)
            return button
        end
        local function Check(text,y,key,global)
            local check=CreateFrame("CheckButton",nil,panel,"ChatConfigCheckButtonTemplate")
            check:SetPoint("TOPLEFT",16,y); check.Text:SetText(text)
            check:SetScript("OnClick",function(self)
                local db=Bars.Settings(); local s=global and db or db.bars[Bars.definitions[selected][1]]
                s[key]=not not self:GetChecked(); Bars.Apply("setting"); Bars.RefreshConfig()
            end)
            controls[#controls+1]={frame=check,key=key,global=global}
        end
        local function Number(text,y,key,lo,hi)
            local caption=Label(text,20,y,190)
            local edit=CreateFrame("EditBox",nil,panel,"InputBoxTemplate")
            edit:SetPoint("TOPLEFT",220,y+4); edit:SetSize(100,24); edit:SetAutoFocus(false); edit:SetMaxLetters(9)
            edit:SetScript("OnEnterPressed",function(self)
                local value=tonumber(self:GetText())
                if value and value==value then
                    local s=Bars.Settings().bars[Bars.definitions[selected][1]]
                    if key=="columns" or key=="rows" then Bars.SetGrid(s,key,value,Bars.definitions[selected].count)
                    else s[key]=math.max(lo,math.min(hi,value)) end
                    Bars.Apply("numeric setting")
                end
                self:ClearFocus(); Bars.RefreshConfig()
            end)
            edit:SetScript("OnEscapePressed",function(self) self:ClearFocus(); Bars.RefreshConfig() end)
            controls[#controls+1]={frame=edit,key=key,number=true,caption=caption}
        end
        Label("Action Bars — prototype",16,-16)
        Check("Enable Luna action bars",-48,"enabled",true)
        local selection=Label("",20,-92)
        Button("Previous",20,-118,100,function() selected=(selected-2)%#Bars.definitions+1; Bars.RefreshConfig() end)
        Button("Next",130,-118,100,function() selected=selected%#Bars.definitions+1; Bars.RefreshConfig() end)
        Check("Manage selected bar",-154,"enabled")
        Check("Hide this bar",-184,"hidden")
        Number("Icon size (16–80)",-228,"size",16,80)
        Number("Spacing (0–24)",-264,"spacing",0,24)
        Number("Columns (1–12)",-300,"columns",1,12)
        Number("Rows (1–12)",-336,"rows",1,12)
        Number("X from screen center",-372,"x",-10000,10000)
        Number("Y from screen center",-408,"y",-10000,10000)
        Button("X -",350,-368,36,function() local s=Bars.Settings().bars[Bars.definitions[selected][1]]; s.x=s.x-1; Bars.Apply("nudge"); Bars.RefreshConfig() end)
        Button("X +",392,-368,36,function() local s=Bars.Settings().bars[Bars.definitions[selected][1]]; s.x=s.x+1; Bars.Apply("nudge"); Bars.RefreshConfig() end)
        Button("Y +",350,-404,36,function() local s=Bars.Settings().bars[Bars.definitions[selected][1]]; s.y=s.y+1; Bars.Apply("nudge"); Bars.RefreshConfig() end)
        Button("Y -",392,-404,36,function() local s=Bars.Settings().bars[Bars.definitions[selected][1]]; s.y=s.y-1; Bars.Apply("nudge"); Bars.RefreshConfig() end)
        Check("Square icons / remove decorative button borders",-448,"square")
        Check("Hide binding text",-480,"hideBindings")
        Check("Hide macro names",-512,"hideMacros")
        Check("One-pixel border around the bar",-544,"border")
        Button("Reset selected bar",20,-588,175,function()
            Bars.Settings().bars[Bars.definitions[selected][1]]=nil; Bars.Apply("reset"); Bars.RefreshConfig()
        end)
        Button("Copy debug report",210,-588,175,function() Bars.ShowReport() end)
        local status=Label("",20,-628)
        local help=Label("Press Enter to apply numeric values. Positive Y moves up. Columns and rows are linked: normal bars have 12 buttons; the pet bar has 10. Micro Menu and Bag Bar preserve native layout; size changes their overall height.\n\nHide this bar suppresses it even when Blizzard tries to show it; keybindings remain assigned. Enable extra bars in WoW Options. Luna pauses during Blizzard Edit Mode; its saved positions return afterwards. Layout changes made in combat wait until combat ends.\n\nDisable Dominos and other action bar replacements, then reload. /luitbars report opens diagnostics; /luitbars debug toggles logging. Combat reload behavior needs testing in game.",20,-668)
        function Bars.RefreshConfig()
            local db=Bars.Settings(); local s=db.bars[Bars.definitions[selected][1]]
            local definition=Bars.definitions[selected]
            local group=definition.kind=="group"
            selection:SetText(definition[2])
            for _,control in ipairs(controls) do
                local editable=not group or control.global or control.key=="enabled" or control.key=="hidden" or control.key=="size" or control.key=="x" or control.key=="y" or control.key=="border"
                control.frame:SetEnabled(editable)
                if control.caption then
                    if control.key=="size" then control.caption:SetText(group and "Group height (16–80)" or "Icon size (16–80)") end
                    if control.key=="columns" or control.key=="rows" then
                        control.caption:SetText((control.key=="columns" and "Columns" or "Rows")..(group and " (native layout)" or (" (1–"..(definition.count or 12)..")")))
                    end
                end
                local value=(control.global and db or s)[control.key]
                if control.number then
                    if not control.frame:HasFocus() then control.frame:SetText(tostring(value)) end
                else control.frame:SetChecked(value) end
            end
            status:SetText(Bars.Conflict() and ("Paused: "..Bars.Conflict().." is loaded.") or (Bars.pending and "Layout update waiting for combat to end." or "Blizzard bindings, paging and visibility are preserved."))
        end
        local function ResizeContent()
            local width=math.max(1,scroll:GetWidth())
            panel:SetWidth(width)
            help:SetWidth(math.max(1,width-40))
            panel:SetHeight(math.max(780,688+help:GetStringHeight()))
        end
        scroll:HookScript("OnSizeChanged",ResizeContent)
        root:HookScript("OnShow",function() ResizeContent(); Bars.RefreshConfig() end)
        ResizeContent(); Bars.RefreshConfig()
    end)
end
