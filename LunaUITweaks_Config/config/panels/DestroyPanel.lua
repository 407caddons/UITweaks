--[[
    Destroy Panel
    Settings for the disenchant helper window.
]]

local addonName, addonTable = "LunaUITweaks", _G["LunaUITweaks"]

addonTable.ConfigSetup = addonTable.ConfigSetup or {}

local Helpers = addonTable.ConfigHelpers

function addonTable.ConfigSetup.Destroy(panel, tab, configWindow)
    local function UpdateModule()
        if addonTable.Destroy and addonTable.Destroy.UpdateSettings then
            addonTable.Destroy.UpdateSettings()
        end
    end

    -- Panel Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Destroy (Disenchant Helper)")

    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", 16, -44)
    desc:SetPoint("RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("While resting, lists bag gear your class can't wear or that is lower item level than what you have equipped. Right-click an item to persistently exclude it from disenchanting. Requires Enchanting.")

    -- Enable Checkbox
    local enableBtn = CreateFrame("CheckButton", "UIThingsDestroyEnableCheck", panel, "ChatConfigCheckButtonTemplate")
    enableBtn:SetPoint("TOPLEFT", 20, -84)
    _G[enableBtn:GetName() .. "Text"]:SetText("Enable Destroy")
    enableBtn:SetChecked(UIThingsDB.destroy.enabled)
    enableBtn:SetScript("OnClick", function(self)
        local enabled = not not self:GetChecked()
        UIThingsDB.destroy.enabled = enabled
        UpdateModule()
        Helpers.UpdateModuleVisuals(panel, tab, enabled)
    end)

    -- Auto popup
    local autoCB = CreateFrame("CheckButton", "UIThingsDestroyAutoShowCheck", panel, "ChatConfigCheckButtonTemplate")
    autoCB:SetPoint("TOPLEFT", 20, -112)
    _G[autoCB:GetName() .. "Text"]:SetText("Automatically open when entering a rest area")
    autoCB:SetChecked(UIThingsDB.destroy.autoShow)
    autoCB:SetScript("OnClick", function(self)
        UIThingsDB.destroy.autoShow = not not self:GetChecked()
        UpdateModule()
    end)

    -- Include BoE
    local boeCB = CreateFrame("CheckButton", "UIThingsDestroyBoECheck", panel, "ChatConfigCheckButtonTemplate")
    boeCB:SetPoint("TOPLEFT", 20, -140)
    _G[boeCB:GetName() .. "Text"]:SetText("Include unbound (BoE) items — careful, these can be sold or traded")
    boeCB:SetChecked(UIThingsDB.destroy.includeBoE)
    boeCB:SetScript("OnClick", function(self)
        UIThingsDB.destroy.includeBoE = not not self:GetChecked()
        UpdateModule()
    end)

    -- Appearance
    Helpers.CreateSectionHeader(panel, "Appearance", -176)

    local function ApplyVisuals()
        if addonTable.Destroy and addonTable.Destroy.ApplyVisuals then
            addonTable.Destroy.ApplyVisuals()
        end
    end

    Helpers.CreateColorSwatch(panel, "Background Color:", UIThingsDB.destroy.bgColor, ApplyVisuals, 20, -204, true)
    Helpers.CreateColorSwatch(panel, "Border Color:", UIThingsDB.destroy.borderColor, ApplyVisuals, 20, -234, true)

    local strataLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    strataLabel:SetPoint("TOPLEFT", 20, -268)
    strataLabel:SetText("Frame Strata:")

    local strataDropdown = CreateFrame("Frame", "LunaUITweaksDestroyStrataDropdown", panel,
        "UIDropDownMenuTemplate")
    strataDropdown:SetPoint("TOPLEFT", strataLabel, "BOTTOMLEFT", -15, -4)

    local strataValues = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "TOOLTIP" }
    local function StrataOnClick(self)
        UIThingsDB.destroy.frameStrata = self.value
        UIDropDownMenu_SetSelectedValue(strataDropdown, self.value)
        UIDropDownMenu_SetText(strataDropdown, self.value)
        ApplyVisuals()
    end

    UIDropDownMenu_Initialize(strataDropdown, function(_, level)
        for _, strata in ipairs(strataValues) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = strata
            info.value = strata
            info.func = StrataOnClick
            info.checked = UIThingsDB.destroy.frameStrata == strata
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetWidth(strataDropdown, 150)
    UIDropDownMenu_SetSelectedValue(strataDropdown, UIThingsDB.destroy.frameStrata or "BACKGROUND")
    UIDropDownMenu_SetText(strataDropdown, UIThingsDB.destroy.frameStrata or "BACKGROUND")

    -- Show window now (for testing / manual use)
    local showBtn = CreateFrame("Button", "UIThingsDestroyShowBtn", panel, "UIPanelButtonTemplate")
    showBtn:SetSize(160, 24)
    showBtn:SetPoint("TOPLEFT", 20, -336)
    showBtn:SetText("Show Window Now")
    showBtn:SetScript("OnClick", function()
        if addonTable.Destroy and addonTable.Destroy.ShowWindow then
            addonTable.Destroy.ShowWindow(true)
        end
    end)

    -- Initialize visual state
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.destroy.enabled)
end
