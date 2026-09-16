local addon=_G.LunaUITweaks
local function Setup(panel,tab)
    local H=addon.ConfigHelpers
    local host=panel
    local scroll=CreateFrame("ScrollFrame",nil,host,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT"); scroll:SetPoint("BOTTOMRIGHT",-30,0)
    local child=CreateFrame("Frame",nil,scroll)
    child:SetSize(580,740); scroll:SetScrollChild(child)
    host:HookScript("OnShow",function() child:SetWidth(scroll:GetWidth()) end)
    panel=child
    local function Label(text,y)
        local f=panel:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        f:SetPoint("TOPLEFT",20,y); f:SetWidth(510); f:SetJustifyH("LEFT"); f:SetText(text)
        return f
    end
    Label("Tank Debuffs",-20):SetFontObject("GameFontNormalHuge")
    Label("Two independent displays, powered by Blizzard's combat-safe aura containers. No addon is needed on your co-tank.",-64)
    local status=Label("",-118)
    local function Update()
        addon.TankDebuffs.UpdateSettings()
        status:SetText(addon.TankDebuffs.GetStatus() or "Layout changes apply out of combat. Your display works in raids and dungeons; co-tank is raid-only.")
        H.UpdateModuleVisuals(host,tab,UIThingsDB.tankDebuffs.enabled)
    end
    local function Check(db,key,text,y)
        local f=CreateFrame("CheckButton",nil,panel,"ChatConfigCheckButtonTemplate")
        f:SetPoint("TOPLEFT",20,y); f.Text:SetText(text); f:SetChecked(db[key])
        f:SetScript("OnClick",function(self) db[key]=not not self:GetChecked(); Update() end)
    end
    local db=UIThingsDB.tankDebuffs
    Check(db,"enabled","Enable raid and dungeon tank debuffs",-152)
    Check(db,"onlyTanking","Only show while your assigned role is Tank",-188)
    Check(db,"bossOnly","Only boss / role debuffs (Blizzard classification)",-224)
    local function Slider(s,key,text,lo,hi,x,y)
        local f=CreateFrame("Slider",nil,panel,"OptionsSliderTemplate")
        f:SetPoint("TOPLEFT",x,y); f:SetWidth(150); f:SetMinMaxValues(lo,hi); f:SetValueStep(1); f:SetObeyStepOnDrag(true)
        if f.Low then f.Low:SetText(lo) end
        if f.High then f.High:SetText(hi) end
        local caption=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        caption:SetPoint("BOTTOM",f,"TOP",0,5)
        f:SetValue(s[key]); caption:SetText(text..": "..s[key])
        f:SetScript("OnValueChanged",function(_,value)
            s[key]=math.floor(value+.5); caption:SetText(text..": "..s[key]); Update()
        end)
    end
    for i,key in ipairs({"player","other"}) do
        local y=-288-(i-1)*150
        H.CreateSectionHeader(panel,key=="player" and "Your debuffs" or "Co-tank debuffs",y)
        Check(db[key],"enabled","Show this display",y-30)
        Slider(db[key],"iconSize","Icon size",24,96,20,y-95)
        Slider(db[key],"maxIcons","Icons",1,8,210,y-95)
        Slider(db[key],"fontSize","Text size",10,28,400,y-95)
    end
    local layout=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    layout:SetPoint("TOPLEFT",20,-605); layout:SetSize(190,28); layout:SetText("Position in Layout Mode")
    layout:SetScript("OnClick",addon.LayoutMode.Start)
    Label("Move each labelled handle independently. Width follows icon count and size; height follows icon size. The first other raid member assigned Tank is selected automatically.",-650)
    host:HookScript("OnShow",Update); Update()
end
LunaUITweaksAPI.RegisterConfigPanel("tankDebuffs","Tank Debuffs","Interface\\Icons\\Ability_Warrior_DefensiveStance",Setup)
