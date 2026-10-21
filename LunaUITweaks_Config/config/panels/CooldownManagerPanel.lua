local addon=_G.LunaUITweaks
addon.ConfigSetup=addon.ConfigSetup or {}
local Manager,Helpers=addon.CooldownManager,addon.ConfigHelpers
function addon.ConfigSetup.CooldownManager(panel,nav)
    Helpers.CreateResetButton(panel,"cooldownManager")
    local title=panel:CreateFontString(nil,"OVERLAY","GameFontNormalHuge")
    title:SetPoint("TOPLEFT",16,-16); title:SetText("Cooldown Manager")
    local scroll=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",0,-45); scroll:SetPoint("BOTTOMRIGHT",-30,10)
    local child=CreateFrame("Frame",nil,scroll); child:SetSize(620,1100); scroll:SetScrollChild(child)
    local function DB() return UIThingsDB.cooldownManager end
    local function Label(text,y)
        local f=child:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        f:SetPoint("TOPLEFT",24,y); f:SetWidth(565); f:SetJustifyH("LEFT"); f:SetText(text); return f
    end
    Label("Choose horizontal (right/left) or vertical (up/down) growth for each group. Hidden icons leave no gaps. Spell selection and timers still use Blizzard's Cooldown Manager settings.",-44)
    Label("Layout Mode shows a draggable frame for every enabled group, even when empty. The yellow corner marks its fixed growth origin. Buffs use Blizzard's Hide When Inactive setting.",-99)
    local status=Label("",-155)
    local controls={}
    local function Apply()
        Manager.UpdateSettings(); Helpers.UpdateModuleVisuals(panel,nav,DB().enabled)
        if Manager.GetConflict() then status:SetText("Paused: disable EllesmereUI Cooldown Manager, then /reload, to let Luna manage these icons.")
        elseif InCombatLockdown() then status:SetText("Protected frame changes wait until combat ends.")
        else status:SetText("Enable Blizzard's Cooldown Manager in Options to display your tracked spells.") end
    end
    local function Check(db,key,text,y)
        local c=CreateFrame("CheckButton",nil,child,"ChatConfigCheckButtonTemplate")
        c:SetPoint("TOPLEFT",20,y); c.Text:SetText(text)
        c:SetScript("OnClick",function(self) db()[key]=not not self:GetChecked(); Apply() end)
        controls[#controls+1]=function() c:SetChecked(db()[key]) end
    end
    Check(DB,"enabled","Enable cooldown groups",-5)
    local layout=CreateFrame("Button",nil,child,"UIPanelButtonTemplate")
    layout:SetPoint("TOPLEFT",360,-5); layout:SetSize(150,25); layout:SetText("Layout Mode")
    layout:SetScript("OnClick",function() addon.LayoutMode.Toggle() end)
    local growthLabels={RIGHT="Horizontal — right",LEFT="Horizontal — left",UP="Vertical — up",DOWN="Vertical — down"}
    local function Growth(key,y)
        local drop=CreateFrame("Frame",nil,child,"UIDropDownMenuTemplate")
        drop:SetPoint("TOPLEFT",14,y); UIDropDownMenu_SetWidth(drop,220)
        UIDropDownMenu_Initialize(drop,function()
            for _,direction in ipairs({"RIGHT","LEFT","UP","DOWN"}) do
                local value=direction
                local info=UIDropDownMenu_CreateInfo()
                info.text=growthLabels[value]; info.checked=(DB()[key].growthDirection or "RIGHT")==value
                info.func=function()
                    DB()[key].growthDirection=value
                    UIDropDownMenu_SetText(drop,growthLabels[value]); Apply()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        controls[#controls+1]=function() UIDropDownMenu_SetText(drop,growthLabels[DB()[key].growthDirection] or growthLabels.RIGHT) end
    end
    local function Slider(group,key,label,y,lo,hi)
        local name="LunaCooldown"..group..key
        local s=CreateFrame("Slider",name,child,"OptionsSliderTemplate")
        s:SetPoint("TOPLEFT",32,y); s:SetWidth(440); s:SetMinMaxValues(lo,hi); s:SetValueStep(1); s:SetObeyStepOnDrag(true)
        _G[name.."Low"]:SetText(tostring(lo)); _G[name.."High"]:SetText(tostring(hi))
        local refreshing=false
        local function Text(value) _G[name.."Text"]:SetText(label..": "..value) end
        s:SetScript("OnValueChanged",function(_,value)
            value=math.floor(value+.5); Text(value)
            if not refreshing then DB()[group][key]=value; Apply() end
        end)
        controls[#controls+1]=function()
            refreshing=true; s:SetValue(DB()[group][key]); Text(DB()[group][key]); refreshing=false
        end
    end
    for i,entry in ipairs({{"essential","Essential cooldowns"},{"utility","Utility cooldowns"},{"buffs","Buff icons"}}) do
        local key,name=entry[1],entry[2]
        local y=-215-(i-1)*280
        Helpers.CreateSectionHeader(child,name,y)
        Check(function() return DB()[key] end,"enabled","Manage this group",y-26)
        Growth(key,y-60)
        Slider(key,"columns","Icons per row / column",y-125,1,20)
        Slider(key,"iconSize","Icon size",y-185,16,80)
        Slider(key,"spacing","Spacing",y-245,0,20)
    end
    local function Refresh()
        for _,fn in ipairs(controls) do fn() end
        Apply()
    end
    panel:HookScript("OnShow",Refresh)
    Refresh()
end
