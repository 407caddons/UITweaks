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

local frame = CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_CLOSED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_UNGHOST")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
frame:RegisterEvent("BAG_UPDATE_DELAYED") -- For bag space warnings

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

function addonTable.Vendor.UpdateSettings()
    local settings = UIThingsDB.vendor

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

frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        addonTable.Vendor.UpdateSettings()
        -- Check both durability and bag space on login
        StartDurabilityCheck(1)
        CheckBagSpace()
        return
    end

    if not UIThingsDB.vendor.enabled then
        warningFrame:Hide()
        bagWarningFrame:Hide()
        return
    end

    if event == "MERCHANT_SHOW" then
        if not UIThingsDB.vendor.warningLocked then return end -- Don't hide if moving
        warningFrame:Hide()                                    -- Hide when at vendor
        bagWarningFrame:Hide()                                 -- Hide bag warning too
        -- Run slightly delayed to ensure merchant interaction is fully ready
        SafeAfter(0.1, function()
            AutoRepair()
            SellGreys()
        end)
    elseif event == "BAG_UPDATE_DELAYED" then
        -- Bag space changed, check if we need to show warning
        CheckBagSpace()
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" or event == "MERCHANT_CLOSED" or event == "UPDATE_INVENTORY_DURABILITY" or event == "PLAYER_UNGHOST" then
        -- Run checks slightly delayed to ensure info is ready/state is consistent
        StartDurabilityCheck(1)
        CheckBagSpace()
    elseif event == "PLAYER_REGEN_DISABLED" then
        if not UIThingsDB.vendor.warningLocked then return end -- Don't hide if moving
        warningFrame:Hide()                                    -- Hide in combat
        bagWarningFrame:Hide()                                 -- Hide bag warning in combat
    end
end)
