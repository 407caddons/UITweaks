local addonName, addonTable = ...
local Widgets = addonTable.Widgets

-- Common currencies (TWW Season 3)
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

    local scrollFrame = CreateFrame("ScrollFrame", nil, currencyPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(260, 1)
    scrollFrame:SetScrollChild(scrollChild)

    -- Frame pool for currency rows to avoid leaking frames
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
            row.nameText:SetWidth(200)
            row.qtyText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.qtyText:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 5, 2)
            row.qtyText:SetJustifyH("LEFT")
            row.weeklyText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.weeklyText:SetPoint("TOPRIGHT", -5, -2)
            row.weeklyText:SetTextColor(0.7, 0.7, 1)
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

    currencyPanel:SetScript("OnShow", function()
        dismissFrame:Show()
    end)
    currencyPanel:SetScript("OnHide", function()
        dismissFrame:Hide()
    end)

    -- Get currency info
    local function GetCurrencyData(currencyID)
        local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if not info then return nil end

        return {
            name = info.name,
            quantity = info.quantity,
            maxQuantity = info.maxQuantity,
            iconFileID = info.iconFileID,
            useTotalEarnedForMaxQty = info.useTotalEarnedForMaxQty,
            quantityEarnedThisWeek = info.quantityEarnedThisWeek,
            maxWeeklyQuantity = info.maxWeeklyQuantity,
            discovered = info.discovered,
        }
    end

    -- "No data" label (created once, reused)
    local noDataLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    noDataLabel:SetPoint("TOPLEFT", 10, -10)
    noDataLabel:SetText("No tracked currencies found")
    noDataLabel:Hide()

    -- Update detailed currency panel
    local function UpdateCurrencyPanel()
        ReleaseAllRows()
        noDataLabel:Hide()

        local yOffset = 0

        for _, currencyID in ipairs(DEFAULT_CURRENCIES) do
            local data = GetCurrencyData(currencyID)
            if data and data.discovered then
                local row = AcquireRow()
                row:SetPoint("TOPLEFT", 0, yOffset)

                row.icon:SetTexture(data.iconFileID)
                row.nameText:SetText(data.name)

                if data.maxQuantity and data.maxQuantity > 0 then
                    row.qtyText:SetText(string.format("%s / %s", BreakUpLargeNumbers(data.quantity),
                        BreakUpLargeNumbers(data.maxQuantity)))
                else
                    row.qtyText:SetText(BreakUpLargeNumbers(data.quantity))
                end

                if data.maxWeeklyQuantity and data.maxWeeklyQuantity > 0 then
                    row.weeklyText:SetText(string.format("Weekly: %d/%d", data.quantityEarnedThisWeek or 0,
                        data.maxWeeklyQuantity))
                end

                yOffset = yOffset - 42
            end
        end

        if yOffset == 0 then
            noDataLabel:Show()
        end

        scrollChild:SetHeight(math.abs(yOffset) + 20)
    end

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

        -- Show top 3 currencies
        local count = 0
        for _, currencyID in ipairs(DEFAULT_CURRENCIES) do
            local data = GetCurrencyData(currencyID)
            if data and data.discovered then
                local iconText = CreateTextureMarkup(data.iconFileID, 64, 64, 16, 16, 0, 1, 0, 1)
                local color = data.quantity > 0 and "|cffffffff" or "|cff888888"
                GameTooltip:AddLine(
                    string.format("%s %s%s: %s|r", iconText, color, data.name, BreakUpLargeNumbers(data.quantity)),
                    1, 1, 1)
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
        -- Display primary currency (first discovered one, even if 0)
        local primaryData = nil
        for _, currencyID in ipairs(DEFAULT_CURRENCIES) do
            local data = GetCurrencyData(currencyID)
            if data and data.discovered then
                primaryData = data
                break
            end
        end

        if primaryData then
            -- Abbreviate name if needed
            local shortName = primaryData.name
            if #shortName > 12 then
                shortName = shortName:sub(1, 9) .. "..."
            end

            local iconText = CreateTextureMarkup(primaryData.iconFileID, 64, 64, 16, 16, 0, 1, 0, 1)
            self.text:SetText(string.format("%s %s: %s", iconText, shortName, BreakUpLargeNumbers(primaryData.quantity)))
        else
            self.text:SetText("Currency: None")
        end
    end

    -- Event handler for currency updates
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    eventFrame:RegisterEvent("PLAYER_MONEY")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function(self, event)
        if UIThingsDB.widgets.currency.enabled then
            currencyFrame:UpdateContent()
        end
    end)

    currencyFrame.eventFrame = eventFrame
    currencyFrame.ApplyEvents = function(enabled)
        if enabled then
            eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
            eventFrame:RegisterEvent("PLAYER_MONEY")
            eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        else
            eventFrame:UnregisterAllEvents()
        end
    end
end)
