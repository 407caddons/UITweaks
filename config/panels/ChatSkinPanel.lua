local addonName, addonTable = ...

addonTable.ConfigSetup = addonTable.ConfigSetup or {}

local Helpers = addonTable.ConfigHelpers

function addonTable.ConfigSetup.ChatSkin(panel, tab, configWindow)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Chat Skin")

    -- Enable Checkbox
    local enableCheckbox = CreateFrame("CheckButton", "UIThingsChatSkinEnable", panel, "ChatConfigCheckButtonTemplate")
    enableCheckbox:SetPoint("TOPLEFT", 20, -50)
    _G[enableCheckbox:GetName() .. "Text"]:SetText("Enable Chat Skin")
    enableCheckbox:SetChecked(UIThingsDB.chatSkin.enabled)
    enableCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.chatSkin.enabled = self:GetChecked()
        Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.chatSkin.enabled)
        if addonTable.ChatSkin and addonTable.ChatSkin.UpdateSettings then
            addonTable.ChatSkin.UpdateSettings()
        end
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.chatSkin.enabled)

    -- Create ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "UIThingsChatSkinScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -80)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 0)

    local child = CreateFrame("Frame", nil, scrollFrame)
    child:SetSize(600, 620)
    scrollFrame:SetScrollChild(child)

    scrollFrame:SetScript("OnShow", function()
        child:SetWidth(scrollFrame:GetWidth())
    end)

    -- Description
    local description = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    description:SetPoint("TOPLEFT", 20, -10)
    description:SetWidth(560)
    description:SetJustifyH("LEFT")
    description:SetText(
        "Skin the default chat window with a clean border, flat tab indicators, and remove clutter buttons.")

    -- Lock/Unlock Button
    local lockBtn = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    lockBtn:SetSize(120, 24)
    lockBtn:SetPoint("TOPLEFT", 20, -40)
    lockBtn:SetScript("OnShow", function(self)
        if UIThingsDB.chatSkin.locked then
            self:SetText("Unlock Chat")
        else
            self:SetText("Lock Chat")
        end
    end)
    lockBtn:SetScript("OnClick", function(self)
        UIThingsDB.chatSkin.locked = not UIThingsDB.chatSkin.locked
        if UIThingsDB.chatSkin.locked then
            self:SetText("Unlock Chat")
        else
            self:SetText("Lock Chat")
        end
        if addonTable.ChatSkin and addonTable.ChatSkin.UpdateSettings then
            addonTable.ChatSkin.UpdateSettings()
        end
    end)

    -- Colors Section
    Helpers.CreateSectionHeader(child, "Colors", -75)

    local function OnColorChange()
        if addonTable.ChatSkin and addonTable.ChatSkin.UpdateSettings then
            addonTable.ChatSkin.UpdateSettings()
        end
    end

    Helpers.CreateColorSwatch(child, "Background:", UIThingsDB.chatSkin.bgColor, OnColorChange, 20, -105, true)
    Helpers.CreateColorSwatch(child, "Border:", UIThingsDB.chatSkin.borderColor, OnColorChange, 20, -135, true)
    Helpers.CreateColorSwatch(child, "Active Tab:", UIThingsDB.chatSkin.activeTabColor, OnColorChange, 20, -165, true)
    Helpers.CreateColorSwatch(child, "Inactive Tab:", UIThingsDB.chatSkin.inactiveTabColor, OnColorChange, 20, -195, true)

    -- Border Size Slider
    Helpers.CreateSectionHeader(child, "Border", -235)

    local borderSlider = CreateFrame("Slider", "UIThingsChatSkinBorderSize", child, "OptionsSliderTemplate")
    borderSlider:SetPoint("TOPLEFT", 20, -275)
    borderSlider:SetWidth(200)
    borderSlider:SetMinMaxValues(0, 5)
    borderSlider:SetValueStep(1)
    borderSlider:SetObeyStepOnDrag(true)
    borderSlider:SetValue(UIThingsDB.chatSkin.borderSize or 2)
    _G[borderSlider:GetName() .. "Low"]:SetText("0")
    _G[borderSlider:GetName() .. "High"]:SetText("5")
    _G[borderSlider:GetName() .. "Text"]:SetText("Border Size: " .. (UIThingsDB.chatSkin.borderSize or 2))
    borderSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        UIThingsDB.chatSkin.borderSize = value
        _G[self:GetName() .. "Text"]:SetText("Border Size: " .. value)
        if addonTable.ChatSkin and addonTable.ChatSkin.UpdateSettings then
            addonTable.ChatSkin.UpdateSettings()
        end
    end)

    -- Timestamps Section
    Helpers.CreateSectionHeader(child, "Timestamps", -310)

    local timestampFormats = {
        { label = "Off",            value = "none" },
        { label = "HH:MM (24h)",    value = "%H:%M " },
        { label = "HH:MM:SS (24h)", value = "%H:%M:%S " },
        { label = "HH:MM AM/PM",    value = "%I:%M %p " },
        { label = "HH:MM:SS AM/PM", value = "%I:%M:%S %p " },
    }

    local tsLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tsLabel:SetPoint("TOPLEFT", 20, -340)
    tsLabel:SetText("Timestamp Format:")

    local tsDropdown = CreateFrame("Frame", "UIThingsChatSkinTimestamp", child, "UIDropDownMenuTemplate")
    tsDropdown:SetPoint("TOPLEFT", tsLabel, "BOTTOMLEFT", -15, -5)

    local function TSDropdown_OnClick(self)
        UIDropDownMenu_SetSelectedID(tsDropdown, self:GetID())
        UIThingsDB.chatSkin.timestamps = self.value
        if addonTable.ChatSkin and addonTable.ChatSkin.UpdateSettings then
            addonTable.ChatSkin.UpdateSettings()
        end
    end

    local function TSDropdown_Initialize(self, level)
        for i, fmt in ipairs(timestampFormats) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = fmt.label
            info.value = fmt.value
            info.func = TSDropdown_OnClick
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(tsDropdown, TSDropdown_Initialize)

    local currentTS = UIThingsDB.chatSkin.timestamps or "none"
    local selectedLabel = "Off"
    for _, fmt in ipairs(timestampFormats) do
        if fmt.value == currentTS then
            selectedLabel = fmt.label
            break
        end
    end
    UIDropDownMenu_SetText(tsDropdown, selectedLabel)

    -- Movement Info
    Helpers.CreateSectionHeader(child, "Movement", -400)

    local moveInfo = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    moveInfo:SetPoint("TOPLEFT", 20, -430)
    moveInfo:SetWidth(560)
    moveInfo:SetJustifyH("LEFT")
    moveInfo:SetText(
        "Unlock to drag the entire chat window as one unit. Drag the bottom-right corner to resize. Right-click the unlocked area to toggle individual tab dragging.")

    -- Button Info
    Helpers.CreateSectionHeader(child, "Buttons", -480)

    local buttonInfo = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    buttonInfo:SetPoint("TOPLEFT", 20, -510)
    buttonInfo:SetWidth(560)
    buttonInfo:SetJustifyH("LEFT")
    buttonInfo:SetText(
        "C: Copy chat content\nS: Open Social/Friends window\nH: Open Chat channels menu\nL: Open Language/Chat menu\n\nURLs in chat messages are automatically detected and highlighted. Click a URL to copy it.")
end
