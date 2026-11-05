local addonName, Bags = ...
_G.LunaUITweaksBags = Bags
local pending = false
local nativeBankSession = false
local function Enabled() return LunaUITweaksBagsDB and LunaUITweaksBagsDB.enabled ~= false end

-- Blizzard's bag frames stay fully functional but live under a hidden parent,
-- so Blizzard's own bag state (FRAME_THAT_OPENED_BAGS, bank tab selection in
-- BankFrame:OnShow -> OpenAllBags) is only ever written by Blizzard code.
-- Never replace or call OpenAllBags/CloseAllBags/... from addon code: doing so
-- taints that state and every later right-click item use is ADDON_ACTION_FORBIDDEN.
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()
local originalParents = {}
local function BlizzardBagFrames()
    local list = {}
    if ContainerFrameCombinedBags then list[1] = ContainerFrameCombinedBags end
    for i = 1, NUM_CONTAINER_FRAMES or 13 do
        local frame = _G["ContainerFrame" .. i]
        if frame then list[#list + 1] = frame end
    end
    return list
end
-- Clears Blizzard's invisible bags so they stay in step with a closed Luna
-- window (otherwise the next Escape is spent closing them). Inside the hidden
-- parent, Hide runs no Blizzard OnHide code, so nothing is tainted.
local function ClearHiddenBlizzardBags()
    if InCombatLockdown() then return end
    for _, frame in ipairs(BlizzardBagFrames()) do
        if frame:IsShown() and not frame:IsVisible() then frame:Hide() end
    end
end
function Bags.SetBlizzardBagsHidden(hide)
    if InCombatLockdown() then
        Bags.pendingBlizzardHidden = hide
        return
    end
    Bags.pendingBlizzardHidden = nil
    -- Close them while still hidden: becoming visible while shown would run
    -- Blizzard's OnShow from addon code. Blizzard then reopens them itself.
    if not hide then ClearHiddenBlizzardBags() end
    for _, frame in ipairs(BlizzardBagFrames()) do
        originalParents[frame] = originalParents[frame] or frame:GetParent()
        frame:SetParent(hide and hiddenParent or originalParents[frame])
    end
    if hide and not (Bags.inventory and Bags.inventory:IsShown()) then ClearHiddenBlizzardBags() end
end
local function AnyBlizzardBagOpen()
    for _, frame in ipairs(BlizzardBagFrames()) do
        if frame:IsShown() then return true end
    end
    return false
end
function Bags.SetInventoryShown(shown)
    if InCombatLockdown() then
        Bags.pendingInventoryShown = shown
        return
    end
    Bags.pendingInventoryShown = nil
    Bags.CreateInventory():SetShown(shown)
end
-- Toggle Luna's inventory from addon UI (slash command, widgets) without
-- calling Blizzard's bag functions. Never Show() Blizzard's bag frames here:
-- an ungenerated "open" frame breaks Blizzard's next refresh (e.g. a vendor
-- opening calls OpenAllBags -> ContainerFrame_UpdateAll on it). After opening
-- this way, the next bag-key press may need repeating once.
function Bags.ToggleInventory()
    if not Enabled() then return false end
    local current = Bags.pendingInventoryShown
    if current == nil then current = Bags.CreateInventory():IsShown() end
    Bags.SetInventoryShown(not current)
    return true
end
function Bags.Refresh()
    Bags.UpdateDepositButton()
    if not Enabled() then return end
    if Bags.inventory then
        if Bags.inventory.pendingDragStop and not InCombatLockdown() then Bags.inventory:finishDrag() end
        Bags.Render(Bags.inventory, Bags.InventoryIDs(), true)
    end
    if Bags.bank and Bags.bank:IsShown() then
        local ids, available = Bags.BankIDs(Bags.bank.bankTab)
        Bags.Render(Bags.bank, ids, available)
    end
end
function Bags.QueueRefresh()
    if pending then return end
    pending = true
    C_Timer.After(.08, function()
        pending = false
        Bags.Refresh()
    end)
end
function Bags.SelectBank(bankType)
    if InCombatLockdown() then return end
    local view = Bags.bank
    Bags.CancelDeposit()
    view.depositMessage = nil
    -- Shows a bank in Luna's view only. Never call BankFrame:SetTab here: native
    -- right-click withdraw/deposit reads the active bank from BankFrame, and an
    -- addon-set value makes that protected item move ADDON_ACTION_FORBIDDEN.
    -- Luna's tabs click Blizzard's own tab buttons (see ProxyButton in Views.lua).
    view.bankTab = bankType
    view.scroll:SetVerticalScroll(0)
    view.accountTab:SetEnabled(bankType ~= Enum.BankType.Account)
    view.characterTab:SetEnabled(bankType ~= Enum.BankType.Character)
    -- Unavailable banks must not allow right-click deposits into a different bank.
    view.status:SetText(C_Bank.CanViewBank(bankType) and "" or "This bank is unavailable here.")
    Bags.CreateBank()
    Bags.UpdateDepositButton()
    Bags.QueueRefresh()
end
function Bags.ShowBlizzard(isBank)
    if InCombatLockdown() then return end
    if isBank then
        nativeBankSession = true
        if Bags.bank then
            Bags.bank:Hide()
        end
    else
        -- Show Blizzard's bags until they are all closed. The next bag key
        -- opens them (Blizzard bag functions are never called from here).
        Bags.nativeInventory = true
        Bags.inventory:Hide()
        Bags.SetBlizzardBagsHidden(false)
    end
end
function Bags.ApplySettings()
    Bags.CancelDeposit()
    Bags.SetBlizzardBagsHidden(Enabled() and not Bags.nativeInventory)
    if not Enabled() then
        if Bags.inventory then Bags.SetInventoryShown(false) end
        if Bags.bank then Bags.bank:Hide() end
    end
    Bags.RestorePosition()
    Bags.QueueRefresh()
end
local function InstallBagHooks()
    local names = {"OpenAllBags", "OpenBackpack", "OpenBag", "ToggleAllBags", "ToggleBackpack", "ToggleBag",
        "CloseAllBags", "CloseBackpack", "CloseBag"}
    for _, name in ipairs(names) do
        if type(_G[name]) == "function" then
            -- Post-hook: Blizzard's function has already run untainted.
            hooksecurefunc(name, function(...)
                local bag = ...
                local single = name == "OpenBag" or name == "ToggleBag" or name == "CloseBag"
                local last = Enum.BagIndex.ReagentBag or NUM_BAG_SLOTS or 4
                if not Enabled() or (single and (type(bag) ~= "number" or bag < 0 or bag > last)) then return end
                if Bags.nativeInventory then
                    -- Back to Luna once Blizzard's bags are all closed.
                    if not AnyBlizzardBagOpen() then
                        Bags.nativeInventory = false
                        Bags.SetBlizzardBagsHidden(true)
                    end
                    return
                end
                -- Follow the state Blizzard ended in. Toggles call OpenBackpack/
                -- CloseBag internally, so acting per call would undo itself.
                Bags.SetInventoryShown(AnyBlizzardBagOpen())
            end)
        end
    end
end
local function AttachBank()
    if not BankFrame or Bags.bankHooked then return end
    Bags.bankHooked = true
    BankFrame:HookScript("OnShow", function()
        nativeBankSession = false
        Bags.SnapshotBankForNewItems()
        -- OnShow's default-tab selection must complete before choosing Warband.
        C_Timer.After(0, function()
            -- Bank tab data can arrive after OnShow; refresh the snapshot first.
            if BankFrame:IsShown() then Bags.SnapshotBankForNewItems() end
            if not Enabled() or nativeBankSession or not BankFrame:IsShown() then return end
            Bags.CreateBank():Show()
            Bags.BindBankButtons()
            -- Follow the bank Blizzard opened on; selecting one here would taint it.
            Bags.SelectBank(Bags.ActiveBankType())
        end)
    end)
    BankFrame:HookScript("OnHide", function()
        Bags.CancelDeposit()
        if Bags.bank then Bags.bank:Hide() end
        nativeBankSession = false
    end)
end
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" then
        if arg == addonName then
            LunaUITweaksBagsDB = LunaUITweaksBagsDB or {enabled = true}
            Bags.CreateInventory()
            InstallBagHooks()
            Bags.SetBlizzardBagsHidden(Enabled())
            -- Closing Luna (X, Escape, bag key) also clears Blizzard's invisible bags.
            Bags.inventory:HookScript("OnHide", function()
                if Bags.nativeInventory or not Enabled() then return end
                ClearHiddenBlizzardBags()
            end)
            AttachBank()
            Bags.BeginNewItemSession()
            if IsLoggedIn and IsLoggedIn() then Bags.OnNewItemWorldReady() end
            for _, name in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "ITEM_LOCK_CHANGED", "GET_ITEM_INFO_RECEIVED", "CHAT_MSG_LOOT",
                "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "CURSOR_CHANGED", "PLAYERBANKSLOTS_CHANGED", "BANK_TABS_CHANGED", "BANKFRAME_OPENED", "UPDATE_BINDINGS"}) do events:RegisterEvent(name) end
            if StackSplitFrame then StackSplitFrame:HookScript("OnHide", Bags.QueueRefresh) end
            Bags.RegisterConfig()
        else AttachBank() end
    elseif event == "PLAYER_LOGIN" then
        Bags.BeginNewItemSession()
        Bags.QueueRefresh()
    elseif event == "PLAYER_ENTERING_WORLD" then
        Bags.OnNewItemWorldReady()
        Bags.QueueRefresh()
    elseif event == "CHAT_MSG_LOOT" then
        Bags.OnNewItemLoot(arg)
    elseif event == "BAG_UPDATE_DELAYED" then
        Bags.OnNewItemBagUpdate()
        Bags.QueueRefresh()
    elseif event == "PLAYER_REGEN_DISABLED" then
        Bags.UpdateEscapeRegistration()
        Bags.CancelDeposit()
        Bags.UpdateDepositButton()
    elseif event == "PLAYER_REGEN_ENABLED" then
        Bags.UpdateEscapeRegistration()
        if Bags.pendingInventoryShown ~= nil then Bags.SetInventoryShown(Bags.pendingInventoryShown) end
        if Bags.pendingBlizzardHidden ~= nil then Bags.SetBlizzardBagsHidden(Bags.pendingBlizzardHidden) end
        -- Luna closed during combat: catch Blizzard's invisible bags up.
        if Enabled() and not Bags.nativeInventory and not Bags.inventory:IsShown() then ClearHiddenBlizzardBags() end
        -- A tab clicked in combat switched Blizzard's bank; catch the view up.
        if Bags.bank and Bags.bank:IsShown() and Bags.bank.bankTab ~= Bags.ActiveBankType() then
            Bags.SelectBank(Bags.ActiveBankType())
        end
        Bags.QueueRefresh()
    elseif event == "UPDATE_BINDINGS" then Bags.RefreshCloseBindings()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        Bags.ClearItemCache()
        Bags.UpdateSearch()
        Bags.QueueRefresh()
    elseif event == "BAG_UPDATE_COOLDOWN" then Bags.UpdateCooldowns()
    else Bags.QueueRefresh() end
end)
SLASH_LUNAUITWEAKSBAGS1 = "/luitbags"
SlashCmdList.LUNAUITWEAKSBAGS = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "blizzard" then Bags.ShowBlizzard(false)
    elseif msg == "reset" then
        LunaUITweaksBagsDB.position = nil
        Bags.RestorePosition()
    elseif not Bags.ToggleInventory() then ToggleAllBags() end
end
