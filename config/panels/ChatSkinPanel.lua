local addonName, addonTable = ...

addonTable.ConfigSetup = addonTable.ConfigSetup or {}

local Helpers = addonTable.ConfigHelpers

function addonTable.ConfigSetup.ChatSkin(panel, tab, configWindow)
    Helpers.CreateResetButton(panel, "chatSkin")
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
    child:SetSize(600, 1100)
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

    -- Dimensions & Position Section
    Helpers.CreateSectionHeader(child, "Dimensions & Position", -480)

    local function ApplyChatDimPos()
        if addonTable.ChatSkin and addonTable.ChatSkin.UpdateSettings then
            addonTable.ChatSkin.UpdateSettings()
        end
    end

    -- Helper: create a labeled slider + editbox pair
    local dimControlIdx = 0
    local function CreateDimControl(parent, label, yOff, minVal, maxVal, dbGet, dbSet, applyFn)
        dimControlIdx = dimControlIdx + 1
        local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("TOPLEFT", 20, yOff)
        lbl:SetText(label)

        local sliderName = "UIThingsChatDimCtrl" .. dimControlIdx
        local slider = CreateFrame("Slider", sliderName, parent, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", 20, yOff - 22)
        slider:SetWidth(180)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(1)
        slider:SetObeyStepOnDrag(true)
        slider:SetValue(dbGet())
        _G[sliderName .. "Low"]:SetText(tostring(minVal))
        _G[sliderName .. "High"]:SetText(tostring(maxVal))
        _G[sliderName .. "Text"]:SetText("")

        local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        editBox:SetSize(60, 20)
        editBox:SetPoint("LEFT", slider, "RIGHT", 8, 0)
        editBox:SetAutoFocus(false)
        editBox:SetNumeric(false)
        editBox:SetText(tostring(math.floor(dbGet() + 0.5)))

        local suppressSync = false

        slider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            dbSet(value)
            if not suppressSync then
                suppressSync = true
                editBox:SetText(tostring(value))
                suppressSync = false
            end
            applyFn()
        end)

        local function ApplyEditBox()
            local v = tonumber(editBox:GetText())
            if v then
                v = math.max(minVal, math.min(maxVal, math.floor(v + 0.5)))
                dbSet(v)
                suppressSync = true
                slider:SetValue(v)
                editBox:SetText(tostring(v))
                suppressSync = false
                applyFn()
            end
            editBox:ClearFocus()
        end

        editBox:SetScript("OnEnterPressed", ApplyEditBox)
        editBox:SetScript("OnEditFocusLost", ApplyEditBox)

        -- Refresh on panel open
        slider:SetScript("OnShow", function(self)
            suppressSync = true
            local v = math.floor(dbGet() + 0.5)
            self:SetValue(v)
            editBox:SetText(tostring(v))
            suppressSync = false
        end)
    end

    local function ApplyChatPos()
        local s = UIThingsDB.chatSkin
        if LunaChatSkinContainer and LunaChatSkinContainer:IsShown() then
            LunaChatSkinContainer:ClearAllPoints()
            LunaChatSkinContainer:SetPoint(s.pos.point or "BOTTOMLEFT", UIParent,
                s.pos.relPoint or s.pos.point or "BOTTOMLEFT", s.pos.x, s.pos.y)
        end
        ApplyChatDimPos()
    end

    -- Constants matching ChatSkin.lua layout
    local BTNFRAME_WIDTH = 29
    local INNER_PAD      = 4
    local EDITBOX_HEIGHT = 28

    local function GetContainerWidth()
        local container = LunaChatSkinContainer
        if container and container:IsShown() then
            return math.floor(container:GetWidth() + 0.5)
        end
        local s = UIThingsDB.chatSkin
        local b = s.borderSize or 2
        return (s.chatWidth or 430) + BTNFRAME_WIDTH + (b * 2) + (INNER_PAD * 2)
    end

    local function GetContainerHeight()
        local container = LunaChatSkinContainer
        if container and container:IsShown() then
            return math.floor(container:GetHeight() + 0.5)
        end
        local s = UIThingsDB.chatSkin
        local b = s.borderSize or 2
        -- Use 24 as a reasonable tab height estimate
        return (s.chatHeight or 200) + 24 + EDITBOX_HEIGHT + (b * 2) + INNER_PAD
    end

    local function SetContainerWidth(v)
        local s = UIThingsDB.chatSkin
        local b = s.borderSize or 2
        local chatW = v - BTNFRAME_WIDTH - (b * 2) - (INNER_PAD * 2)
        s.chatWidth = math.max(200, chatW)
    end

    local function SetContainerHeight(v)
        local s = UIThingsDB.chatSkin
        local b = s.borderSize or 2
        local tabH = 24
        local chatH = v - tabH - EDITBOX_HEIGHT - (b * 2) - INNER_PAD
        s.chatHeight = math.max(100, chatH)
    end

    -- Width (container total, ~265–1300)
    CreateDimControl(child, "Width:", -510,
        265, 1300,
        GetContainerWidth,
        SetContainerWidth,
        ApplyChatDimPos)

    -- Height (container total, ~165–900)
    CreateDimControl(child, "Height:", -565,
        165, 900,
        GetContainerHeight,
        SetContainerHeight,
        ApplyChatDimPos)

    local function GetContainerX()
        local container = LunaChatSkinContainer
        if container and container:IsShown() then
            local cx, _ = container:GetCenter()
            local pcx, _ = UIParent:GetCenter()
            if cx and pcx then return math.floor(cx - pcx + 0.5) end
        end
        return UIThingsDB.chatSkin.pos.x or 0
    end

    local function GetContainerY()
        local container = LunaChatSkinContainer
        if container and container:IsShown() then
            local _, cy = container:GetCenter()
            local _, pcy = UIParent:GetCenter()
            if cy and pcy then return math.floor(cy - pcy + 0.5) end
        end
        return UIThingsDB.chatSkin.pos.y or 0
    end

    local function SetContainerX(v)
        UIThingsDB.chatSkin.pos.x = v
        UIThingsDB.chatSkin.pos.point = "CENTER"
        UIThingsDB.chatSkin.pos.relPoint = nil
    end

    local function SetContainerY(v)
        UIThingsDB.chatSkin.pos.y = v
        UIThingsDB.chatSkin.pos.point = "CENTER"
        UIThingsDB.chatSkin.pos.relPoint = nil
    end

    -- X Position (CENTER-relative: negative = left of centre, positive = right)
    CreateDimControl(child, "X Position:", -620,
        -2000, 2000,
        GetContainerX,
        SetContainerX,
        ApplyChatPos)

    -- Y Position (CENTER-relative: negative = below centre, positive = above)
    CreateDimControl(child, "Y Position:", -675,
        -1200, 1200,
        GetContainerY,
        SetContainerY,
        ApplyChatPos)

    -- Button Info
    Helpers.CreateSectionHeader(child, "Buttons", -740)

    local buttonInfo = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    buttonInfo:SetPoint("TOPLEFT", 20, -770)
    buttonInfo:SetWidth(560)
    buttonInfo:SetJustifyH("LEFT")
    buttonInfo:SetText(
        "C: Copy chat content\nS: Open Social/Friends window\nH: Open Chat channels menu\nL: Open Language/Chat menu\n\nURLs in chat messages are automatically detected and highlighted. Click a URL to copy it.")

    -- Keyword Highlights Section
    Helpers.CreateSectionHeader(child, "Keyword Highlights", -830)

    local kwDesc = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    kwDesc:SetPoint("TOPLEFT", 20, -860)
    kwDesc:SetWidth(560)
    kwDesc:SetJustifyH("LEFT")
    kwDesc:SetText("Highlight messages containing specific keywords. Your character name is a good default.")

    -- Highlight color swatch
    Helpers.CreateColorSwatch(child, "Highlight Color:", UIThingsDB.chatSkin.highlightColor, function() end, 20, -885,
        false)

    -- Sound checkbox
    local soundBtn = CreateFrame("CheckButton", "UIThingsChatSkinHighlightSound", child,
        "ChatConfigCheckButtonTemplate")
    soundBtn:SetPoint("TOPLEFT", 200, -882)
    soundBtn:SetHitRectInsets(0, -100, 0, 0)
    _G[soundBtn:GetName() .. "Text"]:SetText("Play Sound on Match")
    soundBtn:SetChecked(UIThingsDB.chatSkin.highlightSound)
    soundBtn:SetScript("OnClick", function(self)
        UIThingsDB.chatSkin.highlightSound = self:GetChecked()
    end)

    -- Keyword list container
    local kwListFrame = CreateFrame("Frame", nil, child)
    kwListFrame:SetPoint("TOPLEFT", 20, -915)
    kwListFrame:SetSize(560, 200)

    local kwRows = {}

    local function RefreshKeywordList()
        -- Clear existing rows
        for _, row in ipairs(kwRows) do
            row:Hide()
        end

        local keywords = UIThingsDB.chatSkin.highlightKeywords
        local yOff = 0
        for i, keyword in ipairs(keywords) do
            local row = kwRows[i]
            if not row then
                row = CreateFrame("Frame", nil, kwListFrame)
                row:SetSize(400, 22)

                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.text:SetPoint("LEFT", 5, 0)
                row.text:SetJustifyH("LEFT")

                row.removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.removeBtn:SetSize(20, 20)
                row.removeBtn:SetPoint("RIGHT", -2, 0)
                row.removeBtn:SetText("X")
                row.removeBtn:SetScript("OnClick", function(self)
                    table.remove(UIThingsDB.chatSkin.highlightKeywords, self:GetParent().index)
                    RefreshKeywordList()
                end)

                kwRows[i] = row
            end

            row:SetPoint("TOPLEFT", kwListFrame, "TOPLEFT", 0, yOff)
            row.text:SetText(keyword)
            row.index = i
            row:Show()
            yOff = yOff - 24
        end
    end

    -- Add keyword input
    local addLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    addLabel:SetPoint("TOPLEFT", 20, -910)
    addLabel:SetText("Add Keyword:")

    local addEdit = CreateFrame("EditBox", nil, child, "InputBoxTemplate")
    addEdit:SetSize(200, 20)
    addEdit:SetPoint("LEFT", addLabel, "RIGHT", 10, 0)
    addEdit:SetAutoFocus(false)

    -- Default to character name if list is empty
    if #UIThingsDB.chatSkin.highlightKeywords == 0 then
        local playerName = UnitName("player")
        if playerName then
            addEdit:SetText(playerName)
        end
    end

    local addBtn = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    addBtn:SetSize(60, 22)
    addBtn:SetPoint("LEFT", addEdit, "RIGHT", 5, 0)
    addBtn:SetText("Add")
    addBtn:SetScript("OnClick", function()
        local text = addEdit:GetText():trim()
        if text ~= "" then
            table.insert(UIThingsDB.chatSkin.highlightKeywords, text)
            addEdit:SetText("")
            addEdit:ClearFocus()
            RefreshKeywordList()
        end
    end)

    addEdit:SetScript("OnEnterPressed", function(self)
        local text = self:GetText():trim()
        if text ~= "" then
            table.insert(UIThingsDB.chatSkin.highlightKeywords, text)
            self:SetText("")
            self:ClearFocus()
            RefreshKeywordList()
        end
    end)

    -- Move keyword list below the add row
    kwListFrame:SetPoint("TOPLEFT", 20, -940)

    RefreshKeywordList()
end
