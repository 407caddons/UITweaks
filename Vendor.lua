local addonName, addonTable = ...
local Vendor = {}
addonTable.Vendor = Vendor

local function Log(msg)
    print("|cFF00FFFF[Vendor]|r " .. msg)
end

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
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_UNGHOST")
frame:RegisterEvent("PLAYER_LOGIN")

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
    UIThingsDB.vendor.warningPos = {point=point, x=x, y=y}
end)
warningFrame:Hide()

local warningText = warningFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
warningText:SetPoint("CENTER")
warningText:SetText("Repair your gear")
warningText:SetTextColor(1, 0, 0) -- Red





local function CheckDurability()
    if not UIThingsDB.vendor.enabled then return end
    
    -- If unlocked, keeps showing
    if not UIThingsDB.vendor.warningLocked then 
        warningFrame:Show()
        return 
    end

    if InCombatLockdown() then return end -- Don't show/update in combat
    if MerchantFrame:IsShown() then 
        warningFrame:Hide()
        return 
    end 
    
    local threshold = UIThingsDB.vendor.repairThreshold or 0
    if threshold == 0 then return end -- Feature disabled if 0
    
    local lowest = 100
    
    for i = 1, 18 do
        local current, max = GetInventoryItemDurability(i)
        if current and max and max > 0 then
            local pct = (current / max) * 100
            if pct < lowest then
                lowest = pct
            end
        end
    end
    
    if lowest < threshold then
        warningFrame:Show()
    else
        warningFrame:Hide()
    end
end

-- Safe Timer Wrapper to prevent errors from other addons hooking C_Timer
local function SafeAfter(delay, func)
    if not func then
        Log("Error: SafeAfter called with nil function")
        return
    end
    
    if C_Timer and C_Timer.After then
        -- Wrap in pcall for safety against bad hooks
        pcall(C_Timer.After, delay, func)
    end
end

function addonTable.Vendor.UpdateSettings()
    local settings = UIThingsDB.vendor
    
    -- Font
    if settings.font and settings.fontSize then
        warningText:SetFont(settings.font, settings.fontSize, "OUTLINE")
    end
    
    -- Position
    warningFrame:ClearAllPoints()
    if settings.warningPos then
        warningFrame:SetPoint(settings.warningPos.point, UIParent, settings.warningPos.point, settings.warningPos.x, settings.warningPos.y)
    else
        warningFrame:SetPoint("TOP", 0, -150)
    end
    
    if not settings.enabled then
        warningFrame:Hide()
        return
    end

    -- Lock/Unlock
    if settings.warningLocked then
        warningFrame:EnableMouse(false)
        warningFrame:SetBackdrop(nil)
        
        -- If we were unlocking, hide the backdrop frame
        if warningFrame.isUnlocking then
             warningFrame:Hide()
             warningFrame.isUnlocking = false
        end
        
        -- ALWAYS re-check durability logic to ensure correct visibility
        SafeAfter(0.5, CheckDurability)
    else
        -- Unlocked -> Show frame + Backdrop
        warningFrame:EnableMouse(true)
        warningFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        warningFrame:SetBackdropColor(0, 0, 0, 0.5)
        warningFrame:Show()
        warningFrame.isUnlocking = true
    end
end

frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        addonTable.Vendor.UpdateSettings()
        -- Also check durability on login after a slight delay
        SafeAfter(1, CheckDurability)
        return
    end

    if not UIThingsDB.vendor.enabled then 
        warningFrame:Hide()
        return 
    end
    
    if event == "MERCHANT_SHOW" then
        if not UIThingsDB.vendor.warningLocked then return end -- Don't hide if moving
        warningFrame:Hide() -- Hide when at vendor
        -- Run slightly delayed to ensure merchant interaction is fully ready
        SafeAfter(0.1, function()
            AutoRepair()
            SellGreys()
        end)
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" or event == "MERCHANT_CLOSED" or event == "UPDATE_INVENTORY_DURABILITY" or event == "PLAYER_UNGHOST" then
        -- Run check slightly delayed to ensure info is ready/state is consistent
        SafeAfter(1, CheckDurability)
    elseif event == "PLAYER_REGEN_DISABLED" then
        if not UIThingsDB.vendor.warningLocked then return end -- Don't hide if moving
        warningFrame:Hide() -- Hide in combat
    end
end)
