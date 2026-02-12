local addonName, addonTable = ...
local Widgets = addonTable.Widgets



table.insert(Widgets.moduleInits, function()
    local bagFrame = Widgets.CreateWidgetFrame("Bags", "bags")
    bagFrame:SetScript("OnClick", function() ToggleAllBags() end)

    bagFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.bags.enabled then return end

        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Bags & Currency", 1, 1, 1)

        -- Show gold
        local gold = GetMoney()
        local goldText = GetCoinTextureString(gold)
        GameTooltip:AddLine("Gold: " .. goldText, 1, 1, 1)

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Currencies:", 1, 0.82, 0)

        -- Show currencies that are set to "show on backpack"
        local currencyCount = 0
        local currencyList = C_CurrencyInfo.GetCurrencyListSize()

        for i = 1, currencyList do
            local info = C_CurrencyInfo.GetCurrencyListInfo(i)
            if info and info.isShowInBackpack then
                local iconText = CreateTextureMarkup(info.iconFileID, 64, 64, 16, 16, 0, 1, 0, 1)
                local color = info.quantity > 0 and "" or "|cff888888"
                GameTooltip:AddLine(
                    string.format("%s %s%s: %s", iconText, color, info.name, BreakUpLargeNumbers(info.quantity)), 1, 1, 1)
                currencyCount = currencyCount + 1
            end
        end

        if currencyCount == 0 then
            GameTooltip:AddLine("No currencies set to show in backpack", 0.7, 0.7, 0.7)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to open bags", 0.5, 0.5, 1)
        GameTooltip:Show()
    end)

    bagFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    bagFrame.UpdateContent = function(self)
        local free = 0
        for i = 0, NUM_BAG_SLOTS do
            free = free + C_Container.GetContainerNumFreeSlots(i)
        end
        self.text:SetFormattedText("Bags: %d", free)
    end
end)
