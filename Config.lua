local addonName, addonTable = ...
addonTable.Config = {}

local configWindow

local function UpdateTracker()
    if addonTable.ObjectiveTracker and addonTable.ObjectiveTracker.UpdateSettings then
        addonTable.ObjectiveTracker.UpdateSettings()
    end
end

function addonTable.Config.Initialize()
    -- Initialize the window if it doesn't exist
    if not configWindow then
        configWindow = CreateFrame("Frame", "UIThingsConfigWindow", UIParent, "BasicFrameTemplateWithInset")
        configWindow:SetSize(300, 250)
        configWindow:SetPoint("CENTER")
        configWindow:SetMovable(true)
        configWindow:EnableMouse(true)
        configWindow:RegisterForDrag("LeftButton")
        configWindow:SetScript("OnDragStart", configWindow.StartMoving)
        configWindow:SetScript("OnDragStop", configWindow.StopMovingOrSizing)
        configWindow:Hide()
        
        configWindow.TitleText:SetText("Luna's UI Tweaks Config")
        
        -- Lock Checkbox
        local lockBtn = CreateFrame("CheckButton", "UIThingsLockCheck", configWindow, "ChatConfigCheckButtonTemplate")
        lockBtn:SetPoint("TOPLEFT", 20, -50)
        _G[lockBtn:GetName() .. "Text"]:SetText("Lock Objective Tracker")
        lockBtn:SetChecked(UIThingsDB.tracker.locked)
        lockBtn:SetScript("OnClick", function(self)
            local locked = not not self:GetChecked()
            print("UIThings: Setting lock to", locked)
            UIThingsDB.tracker.locked = locked
            UpdateTracker()
        end)
        
        -- Width Slider
        local widthSlider = CreateFrame("Slider", "UIThingsWidthSlider", configWindow, "OptionsSliderTemplate")
        widthSlider:SetPoint("TOPLEFT", 20, -100)
        widthSlider:SetMinMaxValues(100, 600)
        widthSlider:SetValueStep(10)
        widthSlider:SetObeyStepOnDrag(true)
        widthSlider:SetWidth(200)
        _G[widthSlider:GetName() .. 'Text']:SetText("Width: " .. UIThingsDB.tracker.width)
        _G[widthSlider:GetName() .. 'Low']:SetText("100")
        _G[widthSlider:GetName() .. 'High']:SetText("600")
        widthSlider:SetValue(UIThingsDB.tracker.width)
        widthSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value / 10) * 10
            UIThingsDB.tracker.width = value
            _G[self:GetName() .. 'Text']:SetText("Width: " .. value)
            UpdateTracker()
        end)
        
        -- Height Slider
        local heightSlider = CreateFrame("Slider", "UIThingsHeightSlider", configWindow, "OptionsSliderTemplate")
        heightSlider:SetPoint("TOPLEFT", 20, -150)
        heightSlider:SetMinMaxValues(100, 1000)
        heightSlider:SetValueStep(10)
        heightSlider:SetObeyStepOnDrag(true)
        heightSlider:SetWidth(200)
        _G[heightSlider:GetName() .. 'Text']:SetText("Height: " .. UIThingsDB.tracker.height)
        _G[heightSlider:GetName() .. 'Low']:SetText("100")
        _G[heightSlider:GetName() .. 'High']:SetText("1000")
        heightSlider:SetValue(UIThingsDB.tracker.height)
        heightSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value / 10) * 10
            UIThingsDB.tracker.height = value
            _G[self:GetName() .. 'Text']:SetText("Height: " .. value)
            UpdateTracker()
        end)
    end
end

function addonTable.Config.ToggleWindow()
    if not configWindow then
        addonTable.Config.Initialize()
    end
    
    if configWindow:IsShown() then
        configWindow:Hide()
    else
        configWindow:Show()
    end
end
