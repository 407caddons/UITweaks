local _, Bags = ...
local active
local ACCOUNT=Enum.BankType.Account
local function Ready()
    return not InCombatLockdown() and Bags.bank and Bags.bank:IsShown() and Bags.bank.bankTab==ACCOUNT
        and LunaUITweaksBagsDB.enabled~=false and C_Bank and C_Bank.CanUseBank and C_Bank.CanUseBank(ACCOUNT)
        and type(C_Bank.AutoDepositItemsIntoBank)=="function"
end
function Bags.UpdateDepositButton()
    local view=Bags.bank
    if not view or not view.deposit then return end
    view.deposit:SetShown(view.bankTab==ACCOUNT)
    view.deposit:SetEnabled(not active and not GetCursorInfo() and not not Ready())
end
local function Finish(message)
    active=nil
    if Bags.bank then Bags.bank.depositMessage=message end
    Bags.UpdateDepositButton(); Bags.QueueRefresh()
end
function Bags.CancelDeposit()
    if StaticPopup_Hide then StaticPopup_Hide("LUNAUITWEAKS_BAGS_DEPOSIT_REFUND") end
    if active then Finish(nil) end
end
local function BulkDeposit()
    if active or not Ready() or GetCursorInfo() then return end
    local getCVar=C_CVar and C_CVar.GetCVar or GetCVar
    local setCVar=C_CVar and C_CVar.SetCVar or SetCVar
    if not getCVar or not setCVar then Finish("Bulk deposit settings unavailable."); return end
    local previous=getCVar("bankAutoDepositReagents")
    if previous==nil then Finish("Bulk reagent deposit unavailable on this client."); return end
    -- Use the native Warbound deposit with its Include Reagents option, restoring the user's preference.
    local changed=previous~="1"
    if changed then setCVar("bankAutoDepositReagents","1") end
    local operation={}
    active=operation
    Bags.UpdateDepositButton()
    local ok=pcall(C_Bank.AutoDepositItemsIntoBank,ACCOUNT)
    if changed then setCVar("bankAutoDepositReagents",previous) end
    if not ok then Finish("Bulk deposit failed."); return end
    Bags.bank.depositMessage="Deposit requested."
    Bags.QueueRefresh()
    C_Timer.After(.3,function()
        if active==operation then Finish("Deposit requested.") end
    end)
end
local function HasRefundableItems()
    if not ItemLocation or not C_Item.CanBeRefunded or not C_Bank.IsItemAllowedInBankType then return false end
    for _,bag in ipairs(Bags.InventoryIDs()) do
        for slot=1,C_Container.GetContainerNumSlots(bag) do
            if C_Container.GetContainerItemInfo(bag,slot) then
                local loc=ItemLocation:CreateFromBagAndSlot(bag,slot)
                if C_Bank.IsItemAllowedInBankType(ACCOUNT,loc) and C_Item.CanBeRefunded(loc) then return true end
            end
        end
    end
    return false
end
StaticPopupDialogs.LUNAUITWEAKS_BAGS_DEPOSIT_REFUND={
    text=ACCOUNT_BANK_DEPOSIT_ALL_NO_REFUND_CONFIRM or "Depositing refundable items ends their refund period. Continue?",
    button1=ACCEPT or "Accept",button2=CANCEL or "Cancel",
    OnAccept=BulkDeposit,timeout=0,whileDead=false,hideOnEscape=true,preferredIndex=3,
}
function Bags.DepositWarbound()
    if active or not Ready() or GetCursorInfo() then return end
    if HasRefundableItems() then StaticPopup_Show("LUNAUITWEAKS_BAGS_DEPOSIT_REFUND")
    else BulkDeposit() end
end
