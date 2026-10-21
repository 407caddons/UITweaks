local addonName, Bags = ...
_G.LunaUITweaksBags=Bags
local originals, pending, bypass = {}, false, false
local nativeBankSession=false
local function Enabled() return LunaUITweaksBagsDB and LunaUITweaksBagsDB.enabled~=false end
local function Original(name,...)
    local previous=bypass; bypass=true
    local result=originals[name](...)
    bypass=previous; return result
end
function Bags.SetInventoryShown(shown)
    if InCombatLockdown() then Bags.pendingInventoryShown=shown; return end
    Bags.pendingInventoryShown=nil
    Bags.CreateInventory():SetShown(shown)
end
function Bags.Refresh()
    Bags.UpdateDepositButton()
    if not Enabled() then return end
    if Bags.inventory then
        if Bags.inventory.pendingDragStop and not InCombatLockdown() then Bags.inventory:finishDrag() end
        Bags.Render(Bags.inventory,Bags.InventoryIDs(),true)
    end
    if Bags.bank and Bags.bank:IsShown() then
        local ids,available=Bags.BankIDs(Bags.bank.bankTab)
        Bags.Render(Bags.bank,ids,available)
    end
end
function Bags.QueueRefresh()
    if pending then return end
    pending=true
    C_Timer.After(.08,function() pending=false; Bags.Refresh() end)
end
function Bags.SelectBank(bankType)
    if InCombatLockdown() then return end
    local view=Bags.bank
    Bags.CancelDeposit()
    view.depositMessage=nil
    view.bankTab=bankType
    -- Native right-click deposit handling reads the active type from BankFrame.
    local tabID=bankType==Enum.BankType.Account and BankFrame.accountBankTabID or BankFrame.characterBankTabID
    if BankFrame.GetTabIDForBankType then tabID=BankFrame:GetTabIDForBankType(bankType) end
    if tabID then BankFrame:SetTab(tabID) end
    view.scroll:SetVerticalScroll(0)
    view.accountTab:SetEnabled(bankType~=Enum.BankType.Account)
    view.characterTab:SetEnabled(bankType~=Enum.BankType.Character)
    -- Unavailable banks must not allow right-click deposits into a different bank.
    view.status:SetText(C_Bank.CanViewBank(bankType) and "" or "This bank is unavailable here.")
    Bags.CreateBank(); Bags.UpdateDepositButton(); Bags.QueueRefresh()
end
function Bags.ShowBlizzard(isBank)
    if InCombatLockdown() then return end
    if isBank then nativeBankSession=true; if Bags.bank then Bags.bank:Hide() end
    else
        Bags.inventory:Hide()
        -- Temporarily bypass replacement until all native bags close.
        Bags.nativeInventory=true; Original("OpenAllBags")
    end
end
function Bags.ApplySettings()
    Bags.CancelDeposit()
    if not Enabled() then
        if Bags.inventory then Bags.SetInventoryShown(false) end
        if Bags.bank then Bags.bank:Hide() end
    end
    Bags.RestorePosition(); Bags.QueueRefresh()
end
local function InstallBagHooks()
    local actions={OpenAllBags="open",OpenBackpack="open",OpenBag="open",ToggleAllBags="toggle",ToggleBackpack="toggle",ToggleBag="toggle",
        CloseAllBags="close",CloseBackpack="close",CloseBag="close"}
    for name,action in pairs(actions) do
        if type(_G[name])=="function" then
            originals[name]=_G[name]
            _G[name]=function(...)
                local bag=...
                local single=name=="OpenBag" or name=="ToggleBag" or name=="CloseBag"
                local last=Enum.BagIndex.ReagentBag or NUM_BAG_SLOTS or 4
                if bypass or not Enabled() or (single and (type(bag)~="number" or bag<0 or bag>last)) then
                    return Original(name,...)
                end
                if Bags.nativeInventory then
                    local result=Original(name,...)
                    if action=="close" or action=="toggle" then
                        -- Clearing on a toggle lets the following key press return to Luna.
                        Bags.nativeInventory=false
                    end
                    return result
                end
                local view=Bags.CreateInventory()
                local wasShown=view:IsShown()
                local shown=action~="close"
                if action=="toggle" then
                    local current=Bags.pendingInventoryShown
                    if current==nil then current=view:IsShown() end
                    shown=not current
                end
                Bags.SetInventoryShown(shown)
                -- CloseAllWindows uses this result to consume Escape before opening the menu.
                if action=="close" then return wasShown end
                return view:IsShown()
            end
        end
    end
end
local function AttachBank()
    if not BankFrame or Bags.bankHooked then return end
    Bags.bankHooked=true
    BankFrame:HookScript("OnShow",function()
        nativeBankSession=false
        -- OnShow's default-tab selection must complete before choosing Warband.
        C_Timer.After(0,function()
            if not Enabled() or nativeBankSession or not BankFrame:IsShown() then return end
            Bags.CreateBank():Show(); Bags.SelectBank(Enum.BankType.Account)
        end)
    end)
    BankFrame:HookScript("OnHide",function()
        Bags.CancelDeposit()
        if Bags.bank then Bags.bank:Hide() end
        nativeBankSession=false
    end)
end
local events=CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent",function(_,event,arg)
    if event=="ADDON_LOADED" then
        if arg==addonName then
            LunaUITweaksBagsDB=LunaUITweaksBagsDB or {enabled=true}
            Bags.CreateInventory(); InstallBagHooks(); AttachBank()
            if IsLoggedIn and IsLoggedIn() then Bags.TrackNewItems(true) end
            for _,name in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","BAG_UPDATE_DELAYED","BAG_UPDATE_COOLDOWN","ITEM_LOCK_CHANGED","GET_ITEM_INFO_RECEIVED",
                "PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","CURSOR_CHANGED","PLAYERBANKSLOTS_CHANGED","BANK_TABS_CHANGED","BANKFRAME_OPENED"}) do events:RegisterEvent(name) end
            if StackSplitFrame then StackSplitFrame:HookScript("OnHide",Bags.QueueRefresh) end
            Bags.RegisterConfig()
        else AttachBank() end
    elseif event=="PLAYER_LOGIN" then
        Bags.TrackNewItems(true); Bags.QueueRefresh()
    elseif event=="PLAYER_ENTERING_WORLD" then
        if not Bags.HasNewItemBaseline() then Bags.TrackNewItems(true) end
        Bags.QueueRefresh()
    elseif event=="BAG_UPDATE_DELAYED" then
        Bags.TrackNewItems(false); Bags.QueueRefresh()
    elseif event=="PLAYER_REGEN_DISABLED" then
        Bags.UpdateEscapeRegistration(); Bags.CancelDeposit(); Bags.UpdateDepositButton()
    elseif event=="PLAYER_REGEN_ENABLED" then
        Bags.UpdateEscapeRegistration()
        if Bags.pendingInventoryShown~=nil then Bags.SetInventoryShown(Bags.pendingInventoryShown) end
        Bags.QueueRefresh()
    elseif event=="GET_ITEM_INFO_RECEIVED" then Bags.ClearItemCache(); Bags.QueueRefresh()
    elseif event=="BAG_UPDATE_COOLDOWN" then Bags.UpdateCooldowns()
    else Bags.QueueRefresh() end
end)
SLASH_LUNAUITWEAKSBAGS1="/luitbags"
SlashCmdList.LUNAUITWEAKSBAGS=function(msg)
    msg=(msg or ""):lower():match("^%s*(.-)%s*$")
    if msg=="blizzard" then Bags.ShowBlizzard(false)
    elseif msg=="reset" then LunaUITweaksBagsDB.position=nil; Bags.RestorePosition()
    else ToggleAllBags() end
end
