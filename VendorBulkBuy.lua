-- Bulk buy from vendors: Shift-click an item that Blizzard cannot split (one
-- per purchase, e.g. currency-bought chests), or Alt-click any item, to choose
-- a quantity. Purchases are paced and stop on any error, a closed vendor or
-- when the item stops arriving. Uses Luna's own dialog (no StaticPopup taint).
local _, addon = ...
local Bulk = {}
addon.VendorBulkBuy = Bulk

local Public = addon.Secret.IsPublic
local STEP_DELAY = 0.3   -- seconds between purchases
local MAX_QUANTITY = 1000

local function Enabled()
    local db = UIThingsDB and UIThingsDB.vendor
    return db and db.enabled and db.bulkBuy ~= false
end

-- Cost per purchase (one bundle of info.stackCount units): gold plus each
-- currency/item cost. Returns a list of {name, icon, amount, owned}.
local function Costs(index, info)
    local costs = {}
    if info.price and info.price > 0 then
        costs[#costs + 1] = { gold = true, amount = info.price, owned = GetMoney() }
    end
    if info.hasExtendedCost then
        for i = 1, GetMerchantItemCostInfo(index) do
            local icon, amount, link, currencyName = GetMerchantItemCostItem(index, i)
            if amount and amount > 0 then
                local owned, name = 0, currencyName
                local currency = link and C_CurrencyInfo.GetCurrencyInfoFromLink(link)
                if currency then
                    owned, name = currency.quantity or 0, currency.name or name
                elseif link then
                    owned = C_Item.GetItemCount(link) or 0
                    name = name or C_Item.GetItemNameByID(link:match("item:(%d+)") or 0) or link
                end
                costs[#costs + 1] = { name = name or "?", icon = icon, amount = amount, owned = owned }
            end
        end
    end
    return costs
end

local function FreeSlots()
    local free = 0
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local n = C_Container.GetContainerNumFreeSlots(bag)
        if n then free = free + n end
    end
    return free
end

-- Largest number of purchases allowed by money/currency, stock and bag space.
local function MaxPurchases(index, info, costs, itemID)
    local max = MAX_QUANTITY
    for _, cost in ipairs(costs) do max = math.min(max, math.floor(cost.owned / cost.amount)) end
    if info.numAvailable and info.numAvailable >= 0 then max = math.min(max, info.numAvailable) end
    local stack = itemID and C_Item.GetItemMaxStackSizeByID(itemID) or 1
    local perPurchase = math.max(1, info.stackCount or 1)
    max = math.min(max, math.floor(FreeSlots() * math.max(1, stack) / perPurchase))
    return math.max(0, max)
end

local function CostText(costs, count)
    local parts = {}
    for _, cost in ipairs(costs) do
        local total = cost.amount * count
        if cost.gold then
            parts[#parts + 1] = GetMoneyString(total, true)
        else
            local icon = cost.icon and ("|T" .. cost.icon .. ":0|t ") or ""
            parts[#parts + 1] = string.format("%s%s %s (have %s)", icon, BreakUpLargeNumbers(total), cost.name,
                BreakUpLargeNumbers(cost.owned))
        end
    end
    return #parts > 0 and table.concat(parts, " + ") or "Free"
end

local dialog, job

local function StopJob(message)
    if not job then return end
    if job.ticker then job.ticker:Cancel() end
    addon.EventBus.Unregister("UI_ERROR_MESSAGE", Bulk.OnError)
    job = nil
    if dialog then dialog.buy:Enable(); dialog.box:Enable(); dialog.stop:Hide() end
    if message then print("|cff00ccffLuna Vendor:|r " .. message) end
end

function Bulk.OnError(_, _, message)
    if job then StopJob("Stopped: " .. (Public(message) and tostring(message) or "purchase failed") .. ".") end
end

local function Step()
    if not job then return end
    if not MerchantFrame or not MerchantFrame:IsShown() then StopJob("Stopped: vendor closed."); return end
    -- The vendor list can change (e.g. stock); never buy a different item.
    local link = GetMerchantItemLink(job.index)
    if link ~= job.link then StopJob("Stopped: vendor list changed."); return end
    if job.bought > 0 then
        local count = C_Item.GetItemCount(job.itemID, true)
        if count <= job.lastCount then
            job.stalls = job.stalls + 1
            if job.stalls >= 10 then StopJob("Stopped: purchases are not arriving.") end
            return
        end
        job.lastCount, job.stalls = count, 0
    end
    if job.bought >= job.total then
        StopJob(string.format("Bought %d x %s.", job.total, job.link))
        if dialog then dialog:Hide() end
        return
    end
    BuyMerchantItem(job.index, job.perPurchase)
    job.bought = job.bought + 1
    if dialog then dialog.status:SetFormattedText("Buying %d / %d...", job.bought, job.total) end
end

local function StartJob(index, itemID, link, count, perPurchase)
    job = { index = index, itemID = itemID, link = link, total = count, perPurchase = perPurchase, bought = 0,
        lastCount = C_Item.GetItemCount(itemID, true), stalls = 0 }
    addon.EventBus.Register("UI_ERROR_MESSAGE", Bulk.OnError, "VendorBulkBuy")
    dialog.buy:Disable(); dialog.box:Disable(); dialog.stop:Show()
    job.ticker = C_Timer.NewTicker(STEP_DELAY, Step)
    Step()
end

local function CreateDialog()
    local f = CreateFrame("Frame", "LunaVendorBulkBuy", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(340, 190); f:SetFrameStrata("DIALOG"); f:SetToplevel(true)
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", 0, -5); f.title:SetText("Buy multiple")
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(36, 36); f.icon:SetPoint("TOPLEFT", 16, -34)
    f.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.name:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 8, -2); f.name:SetPoint("RIGHT", -16, 0); f.name:SetJustifyH("LEFT")
    f.maxText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.maxText:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -4); f.maxText:SetPoint("RIGHT", -16, 0)
    f.maxText:SetJustifyH("LEFT")
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 16, -86); label:SetText("Quantity:")
    f.box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.box:SetSize(70, 20); f.box:SetPoint("LEFT", label, "RIGHT", 12, 0)
    f.box:SetNumeric(true); f.box:SetMaxLetters(4); f.box:SetAutoFocus(true)
    f.maxButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.maxButton:SetSize(60, 22); f.maxButton:SetPoint("LEFT", f.box, "RIGHT", 8, 0); f.maxButton:SetText("Max")
    f.cost = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.cost:SetPoint("TOPLEFT", 16, -114); f.cost:SetPoint("RIGHT", -16, 0); f.cost:SetJustifyH("LEFT")
    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.status:SetPoint("BOTTOMLEFT", 16, 44)
    f.buy = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.buy:SetSize(90, 24); f.buy:SetPoint("BOTTOMRIGHT", -112, 14); f.buy:SetText("Buy")
    f.cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.cancel:SetSize(90, 24); f.cancel:SetPoint("BOTTOMRIGHT", -16, 14); f.cancel:SetText(CANCEL or "Cancel")
    f.stop = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.stop:SetSize(90, 24); f.stop:SetPoint("BOTTOMLEFT", 16, 14); f.stop:SetText("Stop"); f.stop:Hide()
    f.cancel:SetScript("OnClick", function() f:Hide() end)
    f.stop:SetScript("OnClick", function() StopJob("Stopped.") end)
    f:SetScript("OnHide", function() StopJob() end)
    f.box:SetScript("OnEscapePressed", function() f:Hide() end)
    tinsert(UISpecialFrames, "LunaVendorBulkBuy")
    return f
end

function Bulk.Open(index)
    if job then return end
    local info = C_MerchantFrame.GetItemInfo(index)
    local link = GetMerchantItemLink(index)
    if not info or not link or info.isPurchasable == false then return end
    local itemID = tonumber(link:match("item:(%d+)"))
    if not itemID then return end
    dialog = dialog or CreateDialog()
    local costs = Costs(index, info)
    local max = MaxPurchases(index, info, costs, itemID)
    local perPurchase = math.max(1, info.stackCount or 1)
    dialog.icon:SetTexture(info.texture)
    dialog.name:SetText(link .. (perPurchase > 1 and (" x" .. perPurchase) or ""))
    dialog.maxText:SetFormattedText("You can buy up to %d (money, stock and %d free bag slots).", max, FreeSlots())
    dialog.status:SetText("")
    local function Count() return math.min(tonumber(dialog.box:GetText()) or 0, max) end
    local function Preview()
        local count = Count()
        dialog.cost:SetText(count > 0 and ("Cost: " .. CostText(costs, count)) or "Enter a quantity.")
        if count > 0 then dialog.buy:Enable() else dialog.buy:Disable() end
    end
    local function Buy()
        local count = Count()
        if count > 0 then StartJob(index, itemID, link, count, perPurchase) end
    end
    dialog.box:SetScript("OnTextChanged", Preview)
    dialog.box:SetScript("OnEnterPressed", Buy)
    dialog.buy:SetScript("OnClick", Buy)
    dialog.maxButton:SetScript("OnClick", function() dialog.box:SetNumber(max) end)
    dialog.box:Enable(); dialog.stop:Hide()
    dialog.box:SetNumber(math.min(1, max))
    Preview()
    dialog:ClearAllPoints()
    dialog:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 10, 0)
    dialog:Show()
    dialog.box:SetFocus(); dialog.box:HighlightText()
end

-- Post-hook on the item buttons: Blizzard already handled linking (Shift with
-- chat open), dressing up (Ctrl) and stack splitting (Shift on stackables).
-- Alt-click has no Blizzard action on merchant items.
local function OnModifiedClick(button, mouseButton)
    if not Enabled() or mouseButton ~= "LeftButton" or not MerchantFrame or MerchantFrame.selectedTab ~= 1 then return end
    local index = button:GetID()
    if not index or index < 1 then return end
    if IsAltKeyDown() and not IsShiftKeyDown() and not IsControlKeyDown() then
        Bulk.Open(index)
    elseif IsModifiedClick("SPLITSTACK") and not (ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow())
        and not (ChatFrameUtil and ChatFrameUtil.GetActiveWindow and ChatFrameUtil.GetActiveWindow())
        and (GetMerchantItemMaxStack(index) or 1) <= 1 then
        Bulk.Open(index)
    end
end

local hooked = {}
local function HookButtons()
    for i = 1, 24 do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if button and not hooked[button] then
            hooked[button] = true
            button:HookScript("OnClick", OnModifiedClick)
        end
    end
end
addon.EventBus.Register("PLAYER_LOGIN", HookButtons, "VendorBulkBuy")
addon.EventBus.Register("MERCHANT_SHOW", HookButtons, "VendorBulkBuy")
addon.EventBus.Register("MERCHANT_CLOSED", function()
    if dialog and dialog:IsShown() then dialog:Hide() end
end, "VendorBulkBuy")
