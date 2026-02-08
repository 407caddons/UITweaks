local addonName, addonTable = ...

-- Create setup table if it doesn't exist
addonTable.ConfigSetup = addonTable.ConfigSetup or {}

-- Get helpers
local Helpers = addonTable.ConfigHelpers

-- Define the setup function for Vendor panel
function addonTable.ConfigSetup.Vendor(panel, tab, configWindow)
    local fonts = Helpers.fonts

    -- Panel Title
    local vendorTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    vendorTitle:SetPoint("TOPLEFT", 16, -16)
    vendorTitle:SetText("Vendor Automation")

    -- Enable Vendor Checkbox
    local enableVendorBtn = CreateFrame("CheckButton", "UIThingsVendorEnableCheck", panel,
        "ChatConfigCheckButtonTemplate")
    enableVendorBtn:SetPoint("TOPLEFT", 20, -50)
    _G[enableVendorBtn:GetName() .. "Text"]:SetText("Enable Vendor Automation")
    enableVendorBtn:SetChecked(UIThingsDB.vendor.enabled)
    enableVendorBtn:SetScript("OnClick", function(self)
        local enabled = not not self:GetChecked()
        UIThingsDB.vendor.enabled = enabled
        Helpers.UpdateModuleVisuals(panel, tab, enabled)
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.vendor.enabled)

    -- Auto Repair
    local repairBtn = CreateFrame("CheckButton", "UIThingsAutoRepairCheck", panel,
        "ChatConfigCheckButtonTemplate")
    repairBtn:SetPoint("TOPLEFT", 20, -70)
    _G[repairBtn:GetName() .. "Text"]:SetText("Auto Repair")
    repairBtn:SetChecked(UIThingsDB.vendor.autoRepair)
    repairBtn:SetScript("OnClick", function(self)
        local val = not not self:GetChecked()
        UIThingsDB.vendor.autoRepair = val
    end)

    -- Guild Repair
    local guildBtn = CreateFrame("CheckButton", "UIThingsGuildRepairCheck", panel,
        "ChatConfigCheckButtonTemplate")
    guildBtn:SetPoint("TOPLEFT", 40, -100) -- Indented
    _G[guildBtn:GetName() .. "Text"]:SetText("Use Guild Funds")
    guildBtn:SetChecked(UIThingsDB.vendor.useGuildRepair)
    guildBtn:SetScript("OnClick", function(self)
        local val = not not self:GetChecked()
        UIThingsDB.vendor.useGuildRepair = val
    end)

    -- Sell Greys
    local sellBtn = CreateFrame("CheckButton", "UIThingsSellGreysCheck", panel, "ChatConfigCheckButtonTemplate")
    sellBtn:SetPoint("TOPLEFT", 20, -130)
    _G[sellBtn:GetName() .. "Text"]:SetText("Auto Sell Greys")
    sellBtn:SetChecked(UIThingsDB.vendor.sellGreys)
    sellBtn:SetScript("OnClick", function(self)
        local val = not not self:GetChecked()
        UIThingsDB.vendor.sellGreys = val
    end)

    -- Durability Threshold Slider
    local thresholdSlider = CreateFrame("Slider", "UIThingsThresholdSlider", panel, "OptionsSliderTemplate")
    thresholdSlider:SetPoint("TOPLEFT", 20, -170)
    thresholdSlider:SetMinMaxValues(0, 100)
    thresholdSlider:SetValueStep(1)
    thresholdSlider:SetObeyStepOnDrag(true)
    thresholdSlider:SetWidth(200)
    _G[thresholdSlider:GetName() .. 'Text']:SetText(string.format("Repair Reminder: %d%%",
        UIThingsDB.vendor.repairThreshold or 20))
    _G[thresholdSlider:GetName() .. 'Low']:SetText("0%")
    _G[thresholdSlider:GetName() .. 'High']:SetText("100%")
    thresholdSlider:SetValue(UIThingsDB.vendor.repairThreshold or 20)
    thresholdSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.vendor.repairThreshold = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Repair Reminder: %d%%", value))
        if addonTable.Vendor.UpdateSettings then addonTable.Vendor.UpdateSettings() end
    end)

    -- Lock Alert Checkbox
    local vendorLockBtn = CreateFrame("CheckButton", "UIThingsVendorLockCheck", panel,
        "ChatConfigCheckButtonTemplate")
    vendorLockBtn:SetPoint("TOPLEFT", 20, -210)
    _G[vendorLockBtn:GetName() .. "Text"]:SetText("Lock Repair Alert")
    vendorLockBtn:SetChecked(UIThingsDB.vendor.warningLocked)
    vendorLockBtn:SetScript("OnClick", function(self)
        local locked = not not self:GetChecked()
        UIThingsDB.vendor.warningLocked = locked
        if addonTable.Vendor.UpdateSettings then addonTable.Vendor.UpdateSettings() end
    end)

    -- Vendor Font Selector
    Helpers.CreateFontDropdown(
        panel,
        "UIThingsVendorFontDropdown",
        "Alert Font:",
        UIThingsDB.vendor.font,
        function(fontPath, fontName)
            UIThingsDB.vendor.font = fontPath
            if addonTable.Vendor.UpdateSettings then addonTable.Vendor.UpdateSettings() end
        end,
        20,
        -250
    )

    -- Vendor Font Size Slider
    local vendorFontSizeSlider = CreateFrame("Slider", "UIThingsVendorFontSizeSlider", panel,
        "OptionsSliderTemplate")
    vendorFontSizeSlider:SetPoint("TOPLEFT", 20, -320)
    vendorFontSizeSlider:SetMinMaxValues(10, 64)
    vendorFontSizeSlider:SetValueStep(1)
    vendorFontSizeSlider:SetObeyStepOnDrag(true)
    vendorFontSizeSlider:SetWidth(200)
    _G[vendorFontSizeSlider:GetName() .. 'Text']:SetText(string.format("Alert Size: %d", UIThingsDB.vendor.fontSize))
    _G[vendorFontSizeSlider:GetName() .. 'Low']:SetText("10")
    _G[vendorFontSizeSlider:GetName() .. 'High']:SetText("64")
    vendorFontSizeSlider:SetValue(UIThingsDB.vendor.fontSize)
    vendorFontSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.vendor.fontSize = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Alert Size: %d", value))
        if addonTable.Vendor.UpdateSettings then addonTable.Vendor.UpdateSettings() end
    end)
end
