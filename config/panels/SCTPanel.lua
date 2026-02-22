local addonName, addonTable = ...

addonTable.ConfigSetup = addonTable.ConfigSetup or {}

local Helpers = addonTable.ConfigHelpers

function addonTable.ConfigSetup.SCT(panel, tab, configWindow)
    Helpers.CreateResetButton(panel, "sct")
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Scrolling Combat Text")

    local scrollFrame = CreateFrame("ScrollFrame", "UIThingsSCTScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(panel:GetWidth() - 30, 600)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:SetScript("OnShow", function()
        scrollChild:SetWidth(scrollFrame:GetWidth())
    end)

    panel = scrollChild

    -- Enable Checkbox
    local enableBtn = CreateFrame("CheckButton", "UIThingsSCTEnable", panel, "ChatConfigCheckButtonTemplate")
    enableBtn:SetPoint("TOPLEFT", 20, -10)
    _G[enableBtn:GetName() .. "Text"]:SetText("Enable Scrolling Combat Text")
    enableBtn:SetChecked(UIThingsDB.sct.enabled)
    enableBtn:SetScript("OnClick", function(self)
        UIThingsDB.sct.enabled = self:GetChecked()
        Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.sct.enabled)
        if addonTable.SCT and addonTable.SCT.ApplyEvents then
            addonTable.SCT.ApplyEvents()
        end
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.sct.enabled)

    -- Capture to Frames
    local captureBtn = CreateFrame("CheckButton", "UIThingsSCTCapture", panel, "ChatConfigCheckButtonTemplate")
    captureBtn:SetPoint("TOPLEFT", 280, -10)
    _G[captureBtn:GetName() .. "Text"]:SetText("Capture to Frames")
    captureBtn:SetChecked(UIThingsDB.sct.captureToFrames)
    captureBtn:SetScript("OnClick", function(self)
        UIThingsDB.sct.captureToFrames = self:GetChecked()
        if addonTable.SCT and addonTable.SCT.ApplyEvents then
            addonTable.SCT.ApplyEvents()
        end
    end)

    -- Show Damage
    local dmgBtn = CreateFrame("CheckButton", "UIThingsSCTDamage", panel, "ChatConfigCheckButtonTemplate")
    dmgBtn:SetPoint("TOPLEFT", 20, -40)
    _G[dmgBtn:GetName() .. "Text"]:SetText("Show Damage")
    dmgBtn:SetChecked(UIThingsDB.sct.showDamage)
    dmgBtn:SetScript("OnClick", function(self)
        UIThingsDB.sct.showDamage = self:GetChecked()
    end)

    -- Show Healing
    local healBtn = CreateFrame("CheckButton", "UIThingsSCTHealing", panel, "ChatConfigCheckButtonTemplate")
    healBtn:SetPoint("TOPLEFT", 200, -40)
    _G[healBtn:GetName() .. "Text"]:SetText("Show Healing")
    healBtn:SetChecked(UIThingsDB.sct.showHealing)
    healBtn:SetScript("OnClick", function(self)
        UIThingsDB.sct.showHealing = self:GetChecked()
    end)

    -- Show Target Name (Damage)
    local targetDmgBtn = CreateFrame("CheckButton", "UIThingsSCTTargetDmg", panel, "ChatConfigCheckButtonTemplate")
    targetDmgBtn:SetPoint("TOPLEFT", 20, -70)
    _G[targetDmgBtn:GetName() .. "Text"]:SetText("Show Target Name (Damage)")
    targetDmgBtn:SetChecked(UIThingsDB.sct.showTargetDamage)
    targetDmgBtn:SetScript("OnClick", function(self)
        UIThingsDB.sct.showTargetDamage = self:GetChecked()
    end)

    -- Show Target Name (Healing)
    local targetHealBtn = CreateFrame("CheckButton", "UIThingsSCTTargetHeal", panel, "ChatConfigCheckButtonTemplate")
    targetHealBtn:SetPoint("TOPLEFT", 280, -70)
    _G[targetHealBtn:GetName() .. "Text"]:SetText("Show Target Name (Healing)")
    targetHealBtn:SetChecked(UIThingsDB.sct.showTargetHealing)
    targetHealBtn:SetScript("OnClick", function(self)
        UIThingsDB.sct.showTargetHealing = self:GetChecked()
    end)

    -- Font Size Slider
    local fontSlider = CreateFrame("Slider", "UIThingsSCTFontSize", panel, "OptionsSliderTemplate")
    fontSlider:SetPoint("TOPLEFT", 40, -120)
    fontSlider:SetMinMaxValues(10, 48)
    fontSlider:SetValueStep(1)
    fontSlider:SetObeyStepOnDrag(true)
    fontSlider:SetWidth(200)
    _G[fontSlider:GetName() .. 'Text']:SetText("Font Size: " .. UIThingsDB.sct.fontSize)
    _G[fontSlider:GetName() .. 'Low']:SetText("10")
    _G[fontSlider:GetName() .. 'High']:SetText("48")
    fontSlider:SetValue(UIThingsDB.sct.fontSize)
    fontSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        UIThingsDB.sct.fontSize = value
        _G[self:GetName() .. 'Text']:SetText("Font Size: " .. value)
    end)

    -- Duration Slider
    local durSlider = CreateFrame("Slider", "UIThingsSCTDuration", panel, "OptionsSliderTemplate")
    durSlider:SetPoint("TOPLEFT", 40, -170)
    durSlider:SetMinMaxValues(0.5, 5.0)
    durSlider:SetValueStep(0.1)
    durSlider:SetObeyStepOnDrag(true)
    durSlider:SetWidth(200)
    _G[durSlider:GetName() .. 'Text']:SetText("Duration: " .. string.format("%.1f", UIThingsDB.sct.duration) .. "s")
    _G[durSlider:GetName() .. 'Low']:SetText("0.5")
    _G[durSlider:GetName() .. 'High']:SetText("5.0")
    durSlider:SetValue(UIThingsDB.sct.duration)
    durSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 10 + 0.5) / 10
        UIThingsDB.sct.duration = value
        _G[self:GetName() .. 'Text']:SetText("Duration: " .. string.format("%.1f", value) .. "s")
    end)

    -- Crit Scale Slider
    local critSlider = CreateFrame("Slider", "UIThingsSCTCritScale", panel, "OptionsSliderTemplate")
    critSlider:SetPoint("TOPLEFT", 40, -220)
    critSlider:SetMinMaxValues(1.0, 3.0)
    critSlider:SetValueStep(0.1)
    critSlider:SetObeyStepOnDrag(true)
    critSlider:SetWidth(200)
    _G[critSlider:GetName() .. 'Text']:SetText("Crit Scale: " ..
        string.format("%.1f", UIThingsDB.sct.critScale) .. "x")
    _G[critSlider:GetName() .. 'Low']:SetText("1.0")
    _G[critSlider:GetName() .. 'High']:SetText("3.0")
    critSlider:SetValue(UIThingsDB.sct.critScale)
    critSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 10 + 0.5) / 10
        UIThingsDB.sct.critScale = value
        _G[self:GetName() .. 'Text']:SetText("Crit Scale: " .. string.format("%.1f", value) .. "x")
    end)

    -- Scroll Distance Slider
    local distSlider = CreateFrame("Slider", "UIThingsSCTDistance", panel, "OptionsSliderTemplate")
    distSlider:SetPoint("TOPLEFT", 40, -270)
    distSlider:SetMinMaxValues(50, 300)
    distSlider:SetValueStep(10)
    distSlider:SetObeyStepOnDrag(true)
    distSlider:SetWidth(200)
    _G[distSlider:GetName() .. 'Text']:SetText("Scroll Distance: " .. UIThingsDB.sct.scrollDistance)
    _G[distSlider:GetName() .. 'Low']:SetText("50")
    _G[distSlider:GetName() .. 'High']:SetText("300")
    distSlider:SetValue(UIThingsDB.sct.scrollDistance)
    distSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / 10 + 0.5) * 10
        UIThingsDB.sct.scrollDistance = value
        _G[self:GetName() .. 'Text']:SetText("Scroll Distance: " .. value)
    end)

    -- Color Pickers
    Helpers.CreateColorSwatch(panel, "Damage Color", UIThingsDB.sct.damageColor, nil, 20, -310, false)
    Helpers.CreateColorSwatch(panel, "Healing Color", UIThingsDB.sct.healingColor, nil, 200, -310, false)

    -- Lock/Unlock Anchors Button
    local lockBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    lockBtn:SetSize(160, 24)
    lockBtn:SetPoint("TOPLEFT", 20, -350)
    lockBtn:SetText(UIThingsDB.sct.locked and "Unlock Anchors" or "Lock Anchors")
    lockBtn:SetScript("OnClick", function(self)
        UIThingsDB.sct.locked = not UIThingsDB.sct.locked
        self:SetText(UIThingsDB.sct.locked and "Unlock Anchors" or "Lock Anchors")
        if addonTable.SCT and addonTable.SCT.UpdateSCTSettings then
            addonTable.SCT.UpdateSCTSettings()
        end
    end)

    local note = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 20, -380)
    note:SetText("Unlock to drag the damage (right) and healing (left) anchor frames.")
    note:SetTextColor(0.7, 0.7, 0.7)
end
