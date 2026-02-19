local addonName, addonTable = ...
local Vendor = {}
addonTable.Vendor = Vendor

-- Constants
local EQUIPMENT_SLOT_COUNT = 18
local UPDATE_DELAY_SHORT = 0.1
local UPDATE_DELAY_MEDIUM = 0.5
local UPDATE_DELAY_LONG = 1.0

-- Centralized Logging
local Log = function(msg, level)
    if addonTable.Core and addonTable.Core.Log then
        addonTable.Core.Log("Vendor", msg, level)
    else
        print("|cFF00FFFF[Vendor]|r " .. tostring(msg))
    end
end

--- Automatically repairs all items at vendor
-- Uses guild funds if available and configured, otherwise personal funds
local function AutoRepair()
    if not UIThingsDB.vendor.enabled then return end
    if not UIThingsDB.vendor.autoRepair then return end
    if not CanMerchantRepair() then return end

    local repairCost, canRepair = GetRepairAllCost()
    if not canRepair or repairCost <= 0 then return end

    local costStr = GetCoinTextureString(repairCost)

    -- Try Guild Repair
    if UIThingsDB.vendor.useGuildRepair and CanGuildBankRepair() then
        local guildMoney = GetGuildBankMoney()
        local withdrawLimit = GetGuildBankWithdrawMoney()
        if withdrawLimit == -1 then withdrawLimit = guildMoney end -- -1 means unlimited
        local available = math.min(guildMoney, withdrawLimit)

        if available >= repairCost then
            RepairAllItems(true) -- true = useGuildBank
            Log("Repaired using Guild Funds: " .. costStr)
            return
        end
    end

    -- Fallback to Personal Funds
    if GetMoney() >= repairCost then
        RepairAllItems(false)
        Log("Repaired using Personal Funds: " .. costStr)
    else
        Log("Insufficient funds to repair (" .. costStr .. ")")
    end
end

local function SellGreys()
    if not UIThingsDB.vendor.enabled then return end
    if not UIThingsDB.vendor.sellGreys then return end

    if C_MerchantFrame.SellAllJunkItems then
        C_MerchantFrame.SellAllJunkItems()
        Log("Sold all junk items.")
    end
end

local EventBus = addonTable.EventBus

-- Warning Frame
local warningFrame = CreateFrame("Frame", "UIThingsRepairWarning", UIParent, "BackdropTemplate")
warningFrame:SetSize(300, 50)
warningFrame:SetMovable(true)
warningFrame:SetClampedToScreen(true)
warningFrame:RegisterForDrag("LeftButton")
warningFrame:SetScript("OnDragStart", warningFrame.StartMoving)
warningFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    UIThingsDB.vendor.warningPos = { point = point, x = x, y = y }
end)
warningFrame:Hide()

local warningText = warningFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
warningText:SetPoint("CENTER")
warningText:SetText("Repair your gear")
warningText:SetTextColor(1, 0, 0) -- Red

-- Bag Warning Frame
local bagWarningFrame = CreateFrame("Frame", "UIThingsBagWarning", UIParent, "BackdropTemplate")
bagWarningFrame:SetSize(300, 50)
bagWarningFrame:SetMovable(true)
bagWarningFrame:SetClampedToScreen(true)
bagWarningFrame:RegisterForDrag("LeftButton")
bagWarningFrame:SetScript("OnDragStart", bagWarningFrame.StartMoving)
bagWarningFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    UIThingsDB.vendor.bagWarningPos = { point = point, x = x, y = y }
end)
bagWarningFrame:Hide()

local bagWarningText = bagWarningFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
bagWarningText:SetPoint("CENTER")
bagWarningText:SetText("Bag space low")
bagWarningText:SetTextColor(1, 0.5, 0) -- Orange





local function CheckBagSpace()
    if not UIThingsDB.vendor.enabled then return end
    if not UIThingsDB.vendor.bagWarningEnabled then
        bagWarningFrame:Hide()
        return
    end

    -- If unlocked, keep showing for positioning
    if not UIThingsDB.vendor.warningLocked then
        bagWarningFrame:Show()
        return
    end

    -- Check combat restriction (reuse durability setting)
    if UIThingsDB.vendor.onlyCheckDurabilityOOC and InCombatLockdown() then return end

    -- Hide at merchant (bags are visible there)
    if MerchantFrame:IsShown() then
        bagWarningFrame:Hide()
        return
    end

    local threshold = UIThingsDB.vendor.bagWarningThreshold or 5
    local totalFree = 0

    -- Count free slots across all bags (0-4, where 0 is backpack)
    for bagID = 0, 4 do
        local freeSlots = C_Container.GetContainerNumFreeSlots(bagID)
        if freeSlots then
            totalFree = totalFree + freeSlots
        end
    end

    if totalFree <= threshold then
        if totalFree == 0 then
            bagWarningText:SetText("Bags full!")
        elseif totalFree == 1 then
            bagWarningText:SetText("1 bag slot remaining")
        else
            bagWarningText:SetText(string.format("%d bag slots remaining", totalFree))
        end
        bagWarningFrame:Show()
    else
        bagWarningFrame:Hide()
    end
end

local function CheckDurability()
    if not UIThingsDB.vendor.enabled then return end

    -- If unlocked, keeps showing
    if not UIThingsDB.vendor.warningLocked then
        warningFrame:Show()
        return
    end

    -- Check combat restriction
    if UIThingsDB.vendor.onlyCheckDurabilityOOC and InCombatLockdown() then return end
    if MerchantFrame:IsShown() then
        warningFrame:Hide()
        return
    end

    local threshold = UIThingsDB.vendor.repairThreshold or 0
    if threshold == 0 then return end -- Feature disabled if 0

    local lowest = 100

    for i = 1, EQUIPMENT_SLOT_COUNT do
        local current, max = GetInventoryItemDurability(i)
        if current and max and max > 0 then
            local pct = (current / max) * 100
            if pct < lowest then
                lowest = pct
            end
        end
    end

    if lowest < threshold then
        warningText:SetText(string.format("Repair your gear (%d%%)", math.floor(lowest)))
        warningFrame:Show()
    else
        warningFrame:Hide()
    end
end

-- Debounce Timer
local durabilityTimer = nil

local function StartDurabilityCheck(delay)
    if durabilityTimer then
        durabilityTimer:Cancel()
    end
    durabilityTimer = C_Timer.NewTimer(delay, function()
        durabilityTimer = nil
        CheckDurability()
    end)
end

local SafeAfter = addonTable.Core.SafeAfter

-- Named event callbacks
local function OnMerchantShow()
    if not UIThingsDB.vendor.warningLocked then return end
    warningFrame:Hide()
    bagWarningFrame:Hide()
    SafeAfter(0.1, function()
        AutoRepair()
        SellGreys()
    end)
end

local function OnBagUpdateDelayed()
    CheckBagSpace()
end

local function OnVendorRegenOrMove()
    StartDurabilityCheck(1)
    CheckBagSpace()
end

local function OnRegenDisabled()
    if not UIThingsDB.vendor.warningLocked then return end
    warningFrame:Hide()
    bagWarningFrame:Hide()
end

local function ApplyVendorEvents()
    if UIThingsDB.vendor.enabled then
        EventBus.Register("MERCHANT_SHOW", OnMerchantShow)
        EventBus.Register("MERCHANT_CLOSED", OnVendorRegenOrMove)
        EventBus.Register("PLAYER_REGEN_ENABLED", OnVendorRegenOrMove)
        EventBus.Register("PLAYER_REGEN_DISABLED", OnRegenDisabled)
        EventBus.Register("PLAYER_UNGHOST", OnVendorRegenOrMove)
        EventBus.Register("UPDATE_INVENTORY_DURABILITY", OnVendorRegenOrMove)
        EventBus.Register("BAG_UPDATE_DELAYED", OnBagUpdateDelayed)
    else
        EventBus.Unregister("MERCHANT_SHOW", OnMerchantShow)
        EventBus.Unregister("MERCHANT_CLOSED", OnVendorRegenOrMove)
        EventBus.Unregister("PLAYER_REGEN_ENABLED", OnVendorRegenOrMove)
        EventBus.Unregister("PLAYER_REGEN_DISABLED", OnRegenDisabled)
        EventBus.Unregister("PLAYER_UNGHOST", OnVendorRegenOrMove)
        EventBus.Unregister("UPDATE_INVENTORY_DURABILITY", OnVendorRegenOrMove)
        EventBus.Unregister("BAG_UPDATE_DELAYED", OnBagUpdateDelayed)
    end
end

function addonTable.Vendor.UpdateSettings()
    local settings = UIThingsDB.vendor

    ApplyVendorEvents()

    -- Font (applies to both warnings)
    if settings.font and settings.fontSize then
        warningText:SetFont(settings.font, settings.fontSize, "OUTLINE")
        bagWarningText:SetFont(settings.font, settings.fontSize, "OUTLINE")
    end

    -- Durability Warning Position
    warningFrame:ClearAllPoints()
    if settings.warningPos then
        warningFrame:SetPoint(settings.warningPos.point, UIParent, settings.warningPos.point, settings.warningPos.x,
            settings.warningPos.y)
    else
        warningFrame:SetPoint("TOP", 0, -150)
    end

    -- Bag Warning Position
    bagWarningFrame:ClearAllPoints()
    if settings.bagWarningPos then
        bagWarningFrame:SetPoint(settings.bagWarningPos.point, UIParent, settings.bagWarningPos.point,
            settings.bagWarningPos.x, settings.bagWarningPos.y)
    else
        bagWarningFrame:SetPoint("TOP", 0, -200)
    end

    if not settings.enabled then
        warningFrame:Hide()
        bagWarningFrame:Hide()
        return
    end

    -- Lock/Unlock (applies to both warnings)
    if settings.warningLocked then
        warningFrame:EnableMouse(false)
        warningFrame:SetBackdrop(nil)
        bagWarningFrame:EnableMouse(false)
        bagWarningFrame:SetBackdrop(nil)

        -- If we were unlocking, hide the backdrop frames
        if warningFrame.isUnlocking then
            warningFrame:Hide()
            warningFrame.isUnlocking = false
        end
        if bagWarningFrame.isUnlocking then
            bagWarningFrame:Hide()
            bagWarningFrame.isUnlocking = false
        end

        -- Re-check both warnings to ensure correct visibility
        StartDurabilityCheck(0.5)
        CheckBagSpace()
    else
        -- Unlocked -> Show frames + Backdrop for positioning
        local backdrop = {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        }

        warningFrame:EnableMouse(true)
        warningFrame:SetBackdrop(backdrop)
        warningFrame:SetBackdropColor(0, 0, 0, 0.5)
        warningFrame:Show()
        warningFrame.isUnlocking = true

        bagWarningFrame:EnableMouse(true)
        bagWarningFrame:SetBackdrop(backdrop)
        bagWarningFrame:SetBackdropColor(0, 0, 0, 0.5)
        bagWarningFrame:Show()
        bagWarningFrame.isUnlocking = true
    end
end

local function OnPlayerLogin()
    addonTable.Vendor.UpdateSettings()
    StartDurabilityCheck(1)
    CheckBagSpace()
end

EventBus.Register("PLAYER_LOGIN", OnPlayerLogin)
