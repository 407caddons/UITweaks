local addon=_G.LunaUITweaks
addon.ConfigSetup=addon.ConfigSetup or {}
local QoL,Helpers=addon.QualityOfLife,addon.ConfigHelpers
function addon.ConfigSetup.QualityOfLife(panel,nav)
    Helpers.CreateResetButton(panel,"qualityOfLife")
    local title=panel:CreateFontString(nil,"OVERLAY","GameFontNormalHuge")
    title:SetPoint("TOPLEFT",16,-16); title:SetText("Quality of Life")
    local scroll=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",0,-45); scroll:SetPoint("BOTTOMRIGHT",-30,10)
    local child=CreateFrame("Frame",nil,scroll); child:SetSize(620,1140); scroll:SetScrollChild(child)
    local function DB() return QoL.Settings() end
    local function Label(text,y)
        local f=child:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        f:SetPoint("TOPLEFT",24,y); f:SetWidth(560); f:SetJustifyH("LEFT"); f:SetText(text); return f
    end
    local status=Label("",-40)
    local function Apply()
        QoL.UpdateSettings(); Helpers.UpdateModuleVisuals(panel,nav,DB().enabled)
        if QoL.AutoOpen.GetConflict() then
            status:SetText("Ellesmere auto-opening is active; Luna waits. Disable Ellesmere Quality of Life to switch over without duplicate displays.")
            status:SetTextColor(1,.7,.2)
        else status:SetText("Use Layout Mode to position gameplay alerts."); status:SetTextColor(.6,.8,.7) end
    end
    local controls={}
    local function Check(key,text,y)
        local check=CreateFrame("CheckButton",nil,child,"ChatConfigCheckButtonTemplate")
        check:SetPoint("TOPLEFT",20,y); check.Text:SetText(text); check:SetChecked(DB()[key])
        if addon.Client and not addon.Client.SupportsQoL(key) then check:SetEnabled(false); check:SetChecked(false) end
        check:SetScript("OnClick",function(self) DB()[key]=not not self:GetChecked(); Apply() end)
        controls[key]=check; return check
    end
    local function Slider(key,label,y,min,max,step)
        local slider=CreateFrame("Slider","LunaQoL"..key,child,"OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT",28,y); slider:SetWidth(240); slider:SetMinMaxValues(min,max)
        slider:SetValueStep(step); slider:SetObeyStepOnDrag(true)
        _G[slider:GetName().."Low"]:SetText(tostring(min)); _G[slider:GetName().."High"]:SetText(tostring(max))
        local function Text(value) _G[slider:GetName().."Text"]:SetText(label..": "..string.format(step<1 and "%.1f" or "%d",value)) end
        slider:SetValue(DB()[key]); Text(DB()[key])
        slider:SetScript("OnValueChanged",function(_,value) DB()[key]=value; Text(value); Apply() end)
    end
    local function Button(text,x,y,width,fn)
        local b=CreateFrame("Button",nil,child,"UIPanelButtonTemplate"); b:SetPoint("TOPLEFT",x,y)
        b:SetSize(width,25); b:SetText(text); b:SetScript("OnClick",fn); return b
    end
    Check("enabled","Enable Quality of Life",-5)
    Helpers.CreateSectionHeader(child,"Cursor ring",-93)
    Check("cursor","Show cursor ring (always visible; hidden during mouse-look)",-116)
    Check("cursorClassColor","Use class color",-145)
    Slider("cursorSize","Ring size",-205,12,80,1)
    Slider("cursorAlpha","Opacity",-270,.1,1,.1)
    Helpers.CreateColorSwatch(child,"Custom ring color",DB().cursorColor,Apply,320,-200,false)
    Helpers.CreateSectionHeader(child,"Containers and collections",-320)
    Check("autoOpen","Automatically open loot containers",-345)
    Check("excludeWarbound","Keep Warbound containers unopened",-374)
    Label("One container at a time, outside combat. Pauses at vendors, banks, mail, trade, while casting or looting. Hold Shift to pause.",-409)
    Button("Retry blocked containers",24,-448,210,function() QoL.AutoOpen.Retry() end)
    Check("unwrapCollections","Automatically unwrap new mounts, pets and toys",-482)
    Helpers.CreateSectionHeader(child,"Gameplay alerts",-533)
    Check("movement","Show mobility ability cooldowns (all classes)",-560)
    Check("movementTts","Speak when a movement ability becomes ready",-590)
    Button("Test voice",365,-590,130,function() addon.Core.SpeakTTS("Movement ability ready",DB().movementVoice) end)
    Check("timeSpiral","Show Time Spiral / free-movement proc alert",-620)
    Check("gateway","Show Gateway Control Shard readiness (Warlocks)",-650)
    Check("battleRes","Show battle resurrection icon and charges in M+ and raids",-680)
    Label("An already enabled Battle Res widget takes priority. Restricted combat values are passed to native display functions; unavailable cooldown data never triggers speech.",-715)
    Slider("alertFontSize","Alert text size",-780,12,40,1)
    Label("Additional mobility spell IDs (comma separated; only learned spells are tracked)",-822)
    local extra=CreateFrame("EditBox",nil,child,"InputBoxTemplate")
    extra:SetPoint("TOPLEFT",28,-847); extra:SetSize(530,24); extra:SetAutoFocus(false)
    extra:SetText(DB().movementExtraSpells or "")
    extra:SetScript("OnEnterPressed",function(self) DB().movementExtraSpells=self:GetText(); self:ClearFocus(); Apply() end)
    Helpers.CreateSectionHeader(child,"Interface convenience",-905)
    Check("skipCinematics","Skip cinematics and movies (scripted scenes may need a key press)",-933)
    Check("hideTutorials","Hide tutorial tips",-963)
    Check("hideTalkingHead","Hide talking-head dialogue frames",-993)
    panel:HookScript("OnShow",function()
        for key,check in pairs(controls) do check:SetChecked(DB()[key]) end
        Apply()
    end)
    panel:HookScript("OnHide",function() extra:ClearFocus() end)
    Apply()
end
