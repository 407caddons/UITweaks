local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

local GetCharacterKey = function() return addonTable.Core.GetCharacterKey() end

local function SaveCurrentGold()
    local key = GetCharacterKey()
    local gold = GetMoney()
    if not UIThingsDB.widgets.bags.goldData then
        UIThingsDB.widgets.bags.goldData = {}
    end
    UIThingsDB.widgets.bags.goldData[key] = gold
end

table.insert(Widgets.moduleInits, function()
    local bagFrame = Widgets.CreateWidgetFrame("Bags", "bags")
    bagFrame:RegisterForClicks("AnyUp")

    -- Save gold on load and when it changes
    local function OnGoldUpdate()
        if UIThingsDB.widgets.bags.enabled then
            SaveCurrentGold()
        end
    end

    bagFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("PLAYER_MONEY", OnGoldUpdate)
            EventBus.Register("PLAYER_ENTERING_WORLD", OnGoldUpdate)
        else
            EventBus.Unregister("PLAYER_MONEY", OnGoldUpdate)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnGoldUpdate)
        end
    end

    bagFrame:SetScript("OnClick", function(self, button)
        if button == "RightButton" and IsShiftKeyDown() then
            UIThingsDB.widgets.bags.goldData = {}
            SaveCurrentGold()
            addonTable.Core.Log("Bags", "All character gold data cleared", addonTable.Core.LogLevel.INFO)
            GameTooltip:Hide()
            return
        end
        ToggleAllBags()
    end)

    bagFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.bags.enabled then return end

        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Bags & Currency", 1, 1, 1)

        -- Show current toon gold
        local currentGold = GetMoney()
        local goldText = GetCoinTextureString(currentGold)
        local currentKey = GetCharacterKey()
        GameTooltip:AddLine("Gold: " .. goldText, 1, 1, 1)

        -- Show other toons' gold (sorted descending)
        local goldData = UIThingsDB.widgets.bags.goldData or {}
        local otherToons = {}
        for name, gold in pairs(goldData) do
            if name ~= currentKey then
                table.insert(otherToons, { name = name, gold = gold })
            end
        end
        table.sort(otherToons, function(a, b) return a.gold > b.gold end)

        if #otherToons > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Other Characters:", 1, 0.82, 0)
            for _, toon in ipairs(otherToons) do
                GameTooltip:AddDoubleLine(toon.name, GetCoinTextureString(toon.gold), 1, 1, 1, 1, 1, 1)
            end
        end

        -- Warband bank
        local warbandGold = 0
        if C_Bank and C_Bank.FetchDepositedMoney then
            warbandGold = C_Bank.FetchDepositedMoney(Enum.BankType.Account) or 0
        end

        -- Total
        local total = currentGold + warbandGold
        for _, toon in ipairs(otherToons) do
            total = total + toon.gold
        end

        GameTooltip:AddLine(" ")
        if warbandGold > 0 then
            GameTooltip:AddDoubleLine("Warband Bank:", GetCoinTextureString(warbandGold), 0.4, 0.78, 1, 1, 1, 1)
        end
        GameTooltip:AddDoubleLine("Total:", GetCoinTextureString(total), 0, 1, 0, 1, 1, 1)

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
        GameTooltip:AddLine("Shift-Right-Click to clear data", 0.5, 0.5, 0.5)
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
