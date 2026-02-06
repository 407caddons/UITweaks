--[[
    Panel Template

    Copy this file to create a new panel file.
    Replace "PanelName" with your panel's name (e.g., "Tracker", "Vendor", etc.)
]]

local addonName, addonTable = ...

-- Create setup table if it doesn't exist
addonTable.ConfigSetup = addonTable.ConfigSetup or {}

-- Get helpers
local Helpers = addonTable.ConfigHelpers

-- Define the setup function for this panel
-- @param panel frame The panel frame to populate
-- @param tab frame The tab button for this panel
-- @param configWindow frame The main config window
function addonTable.ConfigSetup.PanelName(panel, tab, configWindow)
    -- Helper functions for this panel
    local function UpdateModule()
        if addonTable.ModuleName and addonTable.ModuleName.UpdateSettings then
            addonTable.ModuleName.UpdateSettings()
        end
    end

    -- Panel Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Panel Title")

    -- Enable Checkbox
    local enableBtn = CreateFrame("CheckButton", "UIThingsPanelEnableCheck", panel, "ChatConfigCheckButtonTemplate")
    enableBtn:SetPoint("TOPLEFT", 20, -50)
    _G[enableBtn:GetName() .. "Text"]:SetText("Enable Panel Feature")
    enableBtn:SetChecked(UIThingsDB.moduleName.enabled)
    enableBtn:SetScript("OnClick", function(self)
        local enabled = not not self:GetChecked()
        UIThingsDB.moduleName.enabled = enabled
        UpdateModule()
        Helpers.UpdateModuleVisuals(panel, tab, enabled)
    end)

    -- Initialize visual state
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.moduleName.enabled)

    -- Add more UI elements here...
    -- Use Helpers.CreateSectionHeader(panel, "Section Name", yOffset)
    -- Use Helpers.CreateColorPicker(panel, name, label, getFunc, setFunc, yOffset)
    -- Use Helpers.fonts for font dropdowns
end
