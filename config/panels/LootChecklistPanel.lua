local addonName, addonTable = ...

addonTable.ConfigSetup = addonTable.ConfigSetup or {}

local Helpers = addonTable.ConfigHelpers

function addonTable.ConfigSetup.LootChecklist(panel, tab, configWindow)

    local scrollFrame = CreateFrame("ScrollFrame", "UIThingsLCScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 0)

    local child = CreateFrame("Frame", nil, scrollFrame)
    child:SetSize(600, 600)
    scrollFrame:SetScrollChild(child)
    scrollFrame:SetScript("OnShow", function() child:SetWidth(scrollFrame:GetWidth()) end)

    local db = UIThingsDB.lootChecklist

    local function UpdateModule()
        if addonTable.LootChecklist and addonTable.LootChecklist.UpdateSettings then
            addonTable.LootChecklist.UpdateSettings()
        end
    end

    -- Title
    local titleText = child:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    titleText:SetPoint("TOPLEFT", 16, -16)
    titleText:SetText("Loot Checklist")

    -- Enable checkbox
    local enableCheck = CreateFrame("CheckButton", "UIThingsLCEnableCheck", child, "ChatConfigCheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", 20, -50)
    _G[enableCheck:GetName() .. "Text"]:SetText("Enable Loot Checklist")
    enableCheck:SetChecked(db.enabled)
    enableCheck:SetScript("OnClick", function(self)
        db.enabled = not not self:GetChecked()
        UpdateModule()
        Helpers.UpdateModuleVisuals(panel, tab, db.enabled)
    end)
    Helpers.UpdateModuleVisuals(panel, tab, db.enabled)

    -- Lock checkbox
    local lockCheck = CreateFrame("CheckButton", "UIThingsLCLockCheck", child, "ChatConfigCheckButtonTemplate")
    lockCheck:SetPoint("TOPLEFT", 20, -72)
    _G[lockCheck:GetName() .. "Text"]:SetText("Lock Checklist Frame")
    lockCheck:SetChecked(db.locked)
    lockCheck:SetScript("OnClick", function(self)
        db.locked = not not self:GetChecked()
        UpdateModule()
    end)

    -- Open Browser button
    local openBtn = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    openBtn:SetSize(150, 22)
    openBtn:SetPoint("TOPLEFT", 20, -100)
    openBtn:SetText("Open Loot Browser")
    openBtn:SetScript("OnClick", function()
        if addonTable.LootChecklist then
            addonTable.LootChecklist.ShowBrowser()
        end
    end)

    local slashNote = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slashNote:SetPoint("LEFT", openBtn, "RIGHT", 10, 0)
    slashNote:SetText("|cFFAAAAAA/luitloot|r")

    -- ---- Appearance section ----
    Helpers.CreateSectionHeader(child, "Checklist Frame Appearance", -136)

    -- Background
    local bgCheck = CreateFrame("CheckButton", "UIThingsLCBGCheck", child, "ChatConfigCheckButtonTemplate")
    bgCheck:SetPoint("TOPLEFT", 20, -160)
    _G[bgCheck:GetName() .. "Text"]:SetText("Show Background")
    bgCheck:SetChecked(db.showBackground)
    bgCheck:SetScript("OnClick", function(self)
        db.showBackground = not not self:GetChecked()
        UpdateModule()
    end)

    Helpers.CreateColorSwatch(child, "Color", db.backgroundColor, UpdateModule, 230, -160, true)

    -- Border
    local borderCheck = CreateFrame("CheckButton", "UIThingsLCBorderCheck", child, "ChatConfigCheckButtonTemplate")
    borderCheck:SetPoint("TOPLEFT", 20, -186)
    _G[borderCheck:GetName() .. "Text"]:SetText("Show Border")
    borderCheck:SetChecked(db.showBorder)
    borderCheck:SetScript("OnClick", function(self)
        db.showBorder = not not self:GetChecked()
        UpdateModule()
    end)

    Helpers.CreateColorSwatch(child, "Color", db.borderColor, UpdateModule, 230, -186, false)

    -- ---- Font section ----
    Helpers.CreateSectionHeader(child, "Font", -224)

    Helpers.CreateFontDropdown(child, "UIThingsLCFontDD", "Font:", db.font, function(fontPath)
        db.font = fontPath
        UpdateModule()
    end, 20, -248)

    -- Font size slider
    local fsLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fsLabel:SetPoint("TOPLEFT", 20, -310)
    fsLabel:SetText("Font Size:")

    local fsSlider = CreateFrame("Slider", "UIThingsLCFontSize", child, "OptionsSliderTemplate")
    fsSlider:SetPoint("TOPLEFT", 100, -316)
    fsSlider:SetWidth(140)
    fsSlider:SetMinMaxValues(8, 20)
    fsSlider:SetValueStep(1)
    fsSlider:SetValue(db.fontSize or 12)
    _G[fsSlider:GetName() .. "Low"]:SetText("8")
    _G[fsSlider:GetName() .. "High"]:SetText("20")
    _G[fsSlider:GetName() .. "Text"]:SetText(tostring(db.fontSize or 12))
    fsSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val + 0.5)
        db.fontSize = val
        _G[self:GetName() .. "Text"]:SetText(tostring(val))
        UpdateModule()
    end)

    -- ---- Size section ----
    Helpers.CreateSectionHeader(child, "Frame Size", -346)

    -- Width
    local wLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    wLabel:SetPoint("TOPLEFT", 20, -370)
    wLabel:SetText("Width:")

    local wSlider = CreateFrame("Slider", "UIThingsLCWidth", child, "OptionsSliderTemplate")
    wSlider:SetPoint("TOPLEFT", 80, -376)
    wSlider:SetWidth(160)
    wSlider:SetMinMaxValues(150, 420)
    wSlider:SetValueStep(5)
    wSlider:SetValue(db.width or 220)
    _G[wSlider:GetName() .. "Low"]:SetText("150")
    _G[wSlider:GetName() .. "High"]:SetText("420")
    _G[wSlider:GetName() .. "Text"]:SetText(tostring(db.width or 220))
    wSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val / 5 + 0.5) * 5
        db.width = val
        _G[self:GetName() .. "Text"]:SetText(tostring(val))
        UpdateModule()
    end)

    -- Height
    local hLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hLabel:SetPoint("TOPLEFT", 20, -406)
    hLabel:SetText("Height:")

    local hSlider = CreateFrame("Slider", "UIThingsLCHeight", child, "OptionsSliderTemplate")
    hSlider:SetPoint("TOPLEFT", 80, -412)
    hSlider:SetWidth(160)
    hSlider:SetMinMaxValues(100, 600)
    hSlider:SetValueStep(5)
    hSlider:SetValue(db.height or 280)
    _G[hSlider:GetName() .. "Low"]:SetText("100")
    _G[hSlider:GetName() .. "High"]:SetText("600")
    _G[hSlider:GetName() .. "Text"]:SetText(tostring(db.height or 280))
    hSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val / 5 + 0.5) * 5
        db.height = val
        _G[self:GetName() .. "Text"]:SetText(tostring(val))
        UpdateModule()
    end)

    -- Reset button
    Helpers.CreateResetButton(child, "lootChecklist")
end
