local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

-- Common currencies (TWW Season 3) — used when no custom list is configured
local DEFAULT_CURRENCIES = {
    3008, -- Valorstones
    3056, -- Kej
    3285, -- Weathered Ethereal Crest
    3287, -- Carved Ethereal Crest
    3289, -- Runed Ethereal Crest
    3290, -- Gilded Ethereal Crest
}

table.insert(Widgets.moduleInits, function()
    local currencyFrame = Widgets.CreateWidgetFrame("Currency", "currency")
    currencyFrame:RegisterForClicks("AnyUp")

    -- Returns the active currency ID list: custom list (if any) or defaults
    local function GetActiveCurrencyList()
        local db = UIThingsDB.widgets.currency
        if db.customIDs and #db.customIDs > 0 then
            return db.customIDs
        end
        return DEFAULT_CURRENCIES
    end

    -- Create detailed currency panel
    local currencyPanel = CreateFrame("Frame", "LunaUITweaksCurrencyPanel", UIParent, "BackdropTemplate")
    currencyPanel:SetSize(300, 400)
    currencyPanel:SetFrameStrata("DIALOG")
    currencyPanel:SetFrameLevel(100)
    currencyPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    currencyPanel:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    currencyPanel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    currencyPanel:EnableMouse(true)
    currencyPanel:Hide()

    tinsert(UISpecialFrames, "LunaUITweaksCurrencyPanel")

    local panelTitle = currencyPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panelTitle:SetPoint("TOP", 0, -8)
    panelTitle:SetText("Currencies")

    local closeBtn = CreateFrame("Button", nil, currencyPanel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetSize(20, 20)

    -- "Add currency ID" edit box
    local addLabel = currencyPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addLabel:SetPoint("BOTTOMLEFT", 10, 38)
    addLabel:SetText("Add ID:")
    addLabel:SetTextColor(0.7, 0.7, 0.7)

    local addBox = CreateFrame("EditBox", "LunaUITweaksCurrencyAddBox", currencyPanel, "InputBoxTemplate")
    addBox:SetSize(60, 20)
    addBox:SetPoint("LEFT", addLabel, "RIGHT", 5, 0)
    addBox:SetAutoFocus(false)
    addBox:SetNumeric(true)
    addBox:SetMaxLetters(8)

    local addBtn = CreateFrame("Button", nil, currencyPanel, "UIPanelButtonTemplate")
    addBtn:SetSize(50, 22)
    addBtn:SetPoint("LEFT", addBox, "RIGHT", 5, 0)
    addBtn:SetText("Add")

    local resetBtn = CreateFrame("Button", nil, currencyPanel, "UIPanelButtonTemplate")
    resetBtn:SetSize(55, 22)
    resetBtn:SetPoint("LEFT", addBtn, "RIGHT", 5, 0)
    resetBtn:SetText("Reset")

    local scrollFrame = CreateFrame("ScrollFrame", nil, currencyPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 60)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(260, 1)
    scrollFrame:SetScrollChild(scrollChild)

    -- Frame pool for currency rows
    local rowPool = {}
    local activeRows = {}

    local function AcquireRow()
        local row = table.remove(rowPool)
        if not row then
            row = CreateFrame("Frame", nil, scrollChild)
            row:SetSize(260, 40)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(32, 32)
            row.icon:SetPoint("LEFT", 5, 0)
            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameText:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 5, -2)
            row.nameText:SetJustifyH("LEFT")
            row.nameText:SetWidth(160)
            row.qtyText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.qtyText:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 5, 2)
            row.qtyText:SetJustifyH("LEFT")
            row.weeklyText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.weeklyText:SetPoint("TOPRIGHT", -5, -2)
            row.weeklyText:SetTextColor(0.7, 0.7, 1)
            -- Remove button (only shown for custom IDs)
            row.removeBtn = CreateFrame("Button", nil, row, "UIPanelCloseButton")
            row.removeBtn:SetSize(16, 16)
            row.removeBtn:SetPoint("RIGHT", -2, 0)
        end
        row:Show()
        table.insert(activeRows, row)
        return row
    end

    local function ReleaseAllRows()
        for _, row in ipairs(activeRows) do
            row:Hide()
            row:ClearAllPoints()
            row.weeklyText:SetText("")
            row.removeBtn:SetScript("OnClick", nil)
            row.removeBtn:Hide()
            table.insert(rowPool, row)
        end
        wipe(activeRows)
    end

    -- Dismiss frame
    local dismissFrame = CreateFrame("Button", nil, UIParent)
    dismissFrame:SetFrameStrata("DIALOG")
    dismissFrame:SetFrameLevel(90)
    dismissFrame:SetAllPoints(UIParent)
    dismissFrame:EnableMouse(true)
    dismissFrame:SetScript("OnClick", function()
        currencyPanel:Hide()
    end)
    dismissFrame:Hide()

    currencyPanel:SetScript("OnShow", function() dismissFrame:Show() end)
    currencyPanel:SetScript("OnHide", function() dismissFrame:Hide() end)

    -- Get currency info
    local function GetCurrencyData(currencyID)
        local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if not info then return nil end
        return {
            name = info.name,
            quantity = info.quantity,
            maxQuantity = info.maxQuantity,
            iconFileID = info.iconFileID,
            quantityEarnedThisWeek = info.quantityEarnedThisWeek,
            maxWeeklyQuantity = info.maxWeeklyQuantity,
            discovered = info.discovered,
        }
    end

    -- "No data" label
    local noDataLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    noDataLabel:SetPoint("TOPLEFT", 10, -10)
    noDataLabel:SetText("No tracked currencies found")
    noDataLabel:Hide()

    -- Update detailed currency panel
    local function UpdateCurrencyPanel()
        ReleaseAllRows()
        noDataLabel:Hide()

        local db = UIThingsDB.widgets.currency
        local list = GetActiveCurrencyList()
        local usingCustom = db.customIDs and #db.customIDs > 0
        local yOffset = 0

        for idx, currencyID in ipairs(list) do
            local data = GetCurrencyData(currencyID)
            if data and (data.discovered or usingCustom) then
                local row = AcquireRow()
                row:SetPoint("TOPLEFT", 0, yOffset)

                row.icon:SetTexture(data.iconFileID)
                row.nameText:SetText(data.name or ("ID: " .. currencyID))

                if data.maxQuantity and data.maxQuantity > 0 then
                    row.qtyText:SetText(string.format("%s / %s",
                        BreakUpLargeNumbers(data.quantity),
                        BreakUpLargeNumbers(data.maxQuantity)))
                else
                    row.qtyText:SetText(BreakUpLargeNumbers(data.quantity or 0))
                end

                if data.maxWeeklyQuantity and data.maxWeeklyQuantity > 0 then
                    row.weeklyText:SetText(string.format("Weekly: %d/%d",
                        data.quantityEarnedThisWeek or 0, data.maxWeeklyQuantity))
                end

                -- Show remove button only for custom IDs
                if usingCustom then
                    local capturedIdx = idx
                    row.removeBtn:Show()
                    row.removeBtn:SetScript("OnClick", function()
                        table.remove(db.customIDs, capturedIdx)
                        UpdateCurrencyPanel()
                    end)
                end

                yOffset = yOffset - 42
            end
        end

        if yOffset == 0 then
            noDataLabel:Show()
        end

        scrollChild:SetHeight(math.abs(yOffset) + 20)
    end

    -- Add button handler
    addBtn:SetScript("OnClick", function()
        local idStr = addBox:GetText()
        local id = tonumber(idStr)
        if not id or id <= 0 then return end
        local db = UIThingsDB.widgets.currency
        db.customIDs = db.customIDs or {}
        -- Avoid duplicates
        for _, existing in ipairs(db.customIDs) do
            if existing == id then
                addBox:SetText("")
                return
            end
        end
        table.insert(db.customIDs, id)
        addBox:SetText("")
        UpdateCurrencyPanel()
    end)

    -- Reset button: clear custom list and revert to defaults
    resetBtn:SetScript("OnClick", function()
        UIThingsDB.widgets.currency.customIDs = {}
        UpdateCurrencyPanel()
    end)

    addBox:SetScript("OnEnterPressed", function(self)
        addBtn:Click()
        self:ClearFocus()
    end)

    currencyFrame:SetScript("OnClick", function(self, button)
        if currencyPanel:IsShown() then
            currencyPanel:Hide()
        else
            UpdateCurrencyPanel()
            currencyPanel:ClearAllPoints()
            currencyPanel:SetPoint("BOTTOM", self, "TOP", 0, 5)
            currencyPanel:Show()
        end
    end)

    currencyFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.currency.enabled then return end

        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Currency Tracker", 1, 1, 1)

        local list = GetActiveCurrencyList()
        local count = 0
        for _, currencyID in ipairs(list) do
            local data = GetCurrencyData(currencyID)
            if data and data.discovered then
                local iconText = CreateTextureMarkup(data.iconFileID, 64, 64, 16, 16, 0, 1, 0, 1)
                local color = data.quantity > 0 and "|cffffffff" or "|cff888888"
                GameTooltip:AddLine(
                    string.format("%s %s%s: %s|r", iconText, color, data.name,
                        BreakUpLargeNumbers(data.quantity)), 1, 1, 1)
                count = count + 1
                if count >= 3 then break end
            end
        end

        if count == 0 then
            GameTooltip:AddLine("No currencies tracked", 0.7, 0.7, 0.7)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click for detailed view", 0.5, 0.5, 1)
        GameTooltip:Show()
    end)

    currencyFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    currencyFrame.UpdateContent = function(self)
        local list = GetActiveCurrencyList()
        local primaryData = nil
        for _, currencyID in ipairs(list) do
            local data = GetCurrencyData(currencyID)
            if data and data.discovered then
                primaryData = data
                break
            end
        end

        if primaryData then
            local shortName = primaryData.name
            if #shortName > 12 then
                shortName = shortName:sub(1, 9) .. "..."
            end
            local iconText = CreateTextureMarkup(primaryData.iconFileID, 64, 64, 16, 16, 0, 1, 0, 1)
            self.text:SetText(string.format("%s %s: %s", iconText, shortName,
                BreakUpLargeNumbers(primaryData.quantity)))
        else
            self.text:SetText("Currency: None")
        end
    end

    local function OnCurrencyUpdate()
        if UIThingsDB.widgets.currency.enabled then
            currencyFrame:UpdateContent()
        end
    end

    currencyFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("CURRENCY_DISPLAY_UPDATE", OnCurrencyUpdate)
            EventBus.Register("PLAYER_MONEY", OnCurrencyUpdate)
            EventBus.Register("PLAYER_ENTERING_WORLD", OnCurrencyUpdate)
        else
            EventBus.Unregister("CURRENCY_DISPLAY_UPDATE", OnCurrencyUpdate)
            EventBus.Unregister("PLAYER_MONEY", OnCurrencyUpdate)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnCurrencyUpdate)
        end
    end
end)
