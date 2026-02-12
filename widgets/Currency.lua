local addonName, addonTable = ...
local Widgets = addonTable.Widgets

-- Common currencies (TWW Season 1)
local DEFAULT_CURRENCIES = {
    3089, -- Resonance Crystals
    2917, -- Valorstones
    2914, -- Weathered Harbinger Crest
    2915, -- Carved Harbinger Crest
    2916, -- Runed Harbinger Crest
    2245, -- Flightstones (if still used)
    2806, -- Whelpling's Awakened Crest (example)
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

    -- Update detailed currency panel
    local function UpdateCurrencyPanel()
        -- Clear existing content
        for _, child in ipairs({ scrollChild:GetChildren() }) do
            child:Hide()
            child:SetParent(nil)
        end

        local yOffset = 0

        for _, currencyID in ipairs(DEFAULT_CURRENCIES) do
            local data = GetCurrencyData(currencyID)
            if data and data.discovered then
                local frame = CreateFrame("Frame", nil, scrollChild)
                frame:SetSize(260, 40)
                frame:SetPoint("TOPLEFT", 0, yOffset)

                -- Icon
                local icon = frame:CreateTexture(nil, "ARTWORK")
                icon:SetSize(32, 32)
                icon:SetPoint("LEFT", 5, 0)
                icon:SetTexture(data.iconFileID)

                -- Name and quantity
                local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 5, -2)
                nameText:SetText(data.name)
                nameText:SetJustifyH("LEFT")
                nameText:SetWidth(200)

                local qtyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                qtyText:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 5, 2)
                qtyText:SetJustifyH("LEFT")

                if data.maxQuantity and data.maxQuantity > 0 then
                    qtyText:SetText(string.format("%s / %s", BreakUpLargeNumbers(data.quantity),
                        BreakUpLargeNumbers(data.maxQuantity)))
                else
                    qtyText:SetText(BreakUpLargeNumbers(data.quantity))
                end

                -- Weekly cap if applicable
                if data.maxWeeklyQuantity and data.maxWeeklyQuantity > 0 then
                    local weeklyText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    weeklyText:SetPoint("TOPRIGHT", -5, -2)
                    weeklyText:SetTextColor(0.7, 0.7, 1)
                    weeklyText:SetText(string.format("Weekly: %d/%d", data.quantityEarnedThisWeek or 0,
                        data.maxWeeklyQuantity))
                end

                yOffset = yOffset - 42
            end
        end

        if yOffset == 0 then
            local noData = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            noData:SetPoint("TOPLEFT", 10, -10)
            noData:SetText("No tracked currencies found")
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
end)
