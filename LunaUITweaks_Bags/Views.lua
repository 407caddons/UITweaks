local _, Bags = ...
local SIZE, STEP, COLUMNS = 36, 40, 12
local searchText = ""
local function ApplySearch(button)
    if searchText == "" or not button.searchItemID then
        button.searchOverlay:Hide()
        return
    end
    local name = button.searchName or ""
    if name == "" and button.searchItemID then
        name = (C_Item.GetItemInfo(button.searchItemID) or ""):lower()
        button.searchName = name
    end
    local matches = searchText == "" or not button.searchItemID or name:find(searchText, 1, true) ~= nil
    button.searchOverlay:SetShown(not matches)
end
function Bags.UpdateSearch()
    for _, view in pairs({Bags.inventory, Bags.bank}) do
        if view:IsShown() then
            for _, button in ipairs(view.buttons) do if button:IsShown() then ApplySearch(button) end end
        end
    end
end
function Bags.SetSearchText(value)
    searchText = (value or ""):match("^%s*(.-)%s*$"):lower()
    Bags.UpdateSearch()
end
local function Text(parent, text, x, y, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(text)
    return label
end
local function Button(parent, text, x, y, width, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", x, y)
    button:SetSize(width, 24)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end
-- Secure proxy: a hardware click runs Blizzard's own button OnClick through
-- SecureActionButtonTemplate, so Blizzard's bank state is never written by
-- addon code (an addon-set bank tab taints right-click withdraw/deposit).
local function ProxyButton(parent, text, x, y, width, postClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    button:SetPoint("TOPLEFT", x, y)
    button:SetSize(width, 24)
    button:SetText(text)
    button:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
    button:SetAttribute("type", "click")
    button:SetScript("PostClick", postClick)
    return button
end
-- Equipped bag slots (bags 1-4 and the reagent bag): see, add, swap or remove
-- bags. Uses the same cursor actions as Blizzard's bag bar (PutItemInBag /
-- PickupBagFromSlot); the game decides whether a swap is allowed.
local BAG_SLOT_SIZE = 24
local function EquippedBagIDs()
    local ids = {}
    for bag = 1, NUM_BAG_SLOTS or 4 do ids[#ids + 1] = bag end
    if Enum.BagIndex and Enum.BagIndex.ReagentBag then ids[#ids + 1] = Enum.BagIndex.ReagentBag end
    return ids
end
local function BagInventorySlot(bag)
    local toInventory = C_Container.ContainerIDToInventoryID or ContainerIDToInventoryID
    return toInventory and toInventory(bag)
end
local function BagSlotPlace(self)
    local slot = BagInventorySlot(self.bagID)
    if not slot or InCombatLockdown() then return end
    if CursorHasItem() then
        PutItemInBag(slot)
    else
        PickupBagFromSlot(slot)
    end
end
local function BagSlotTooltip(self)
    local slot = BagInventorySlot(self.bagID)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if slot and GetInventoryItemTexture("player", slot) then
        GameTooltip:SetInventoryItem("player", slot)
        local free, size = C_Container.GetContainerNumFreeSlots(self.bagID), C_Container.GetContainerNumSlots(self.bagID)
        GameTooltip:AddLine(string.format("%d / %d slots free", free or 0, size or 0), 1, 1, 1)
        GameTooltip:AddLine("Drop a bag here to swap it; drag this bag away to remove it.", .6, .6, .6, true)
    else
        GameTooltip:SetText(self.bagID == (Enum.BagIndex and Enum.BagIndex.ReagentBag) and "Empty reagent bag slot" or "Empty bag slot")
        GameTooltip:AddLine("Drop a bag here to equip it.", .6, .6, .6, true)
    end
    GameTooltip:Show()
end
local function CreateBagSlots(view)
    view.bagSlots = {}
    for i, bag in ipairs(EquippedBagIDs()) do
        local button = CreateFrame("Button", nil, view)
        button:SetSize(BAG_SLOT_SIZE, BAG_SLOT_SIZE)
        button:SetPoint("BOTTOMRIGHT", -14 - (#EquippedBagIDs() - i) * (BAG_SLOT_SIZE + 4), 10)
        button.bagID = bag
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        button.count:SetPoint("BOTTOMRIGHT", -1, 1)
        button.border = button:CreateTexture(nil, "BACKGROUND")
        button.border:SetPoint("TOPLEFT", -1, 1)
        button.border:SetPoint("BOTTOMRIGHT", 1, -1)
        button.border:SetColorTexture(.19, .25, .29)
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        button:RegisterForClicks("LeftButtonUp")
        button:RegisterForDrag("LeftButton")
        button:SetScript("OnClick", BagSlotPlace)
        button:SetScript("OnReceiveDrag", BagSlotPlace)
        button:SetScript("OnDragStart", BagSlotPlace)
        button:SetScript("OnEnter", BagSlotTooltip)
        button:SetScript("OnLeave", GameTooltip_Hide)
        view.bagSlots[i] = button
    end
end
function Bags.UpdateBagSlots()
    local view = Bags.inventory
    if not view or not view.bagSlots then return end
    for _, button in ipairs(view.bagSlots) do
        local slot = BagInventorySlot(button.bagID)
        local texture = slot and GetInventoryItemTexture("player", slot)
        if texture then
            button.icon:SetTexture(texture)
            button.icon:SetDesaturated(false)
            button.count:SetText(C_Container.GetContainerNumSlots(button.bagID) or "")
        else
            button.icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
            button.icon:SetDesaturated(true)
            button.count:SetText("")
        end
        if GameTooltip:IsOwned(button) then BagSlotTooltip(button) end
    end
end
local function SavePosition(view)
    local point, _, relativePoint, x, y = view:GetPoint()
    LunaUITweaksBagsDB.position = {point = point, relativePoint = relativePoint, x = x, y = y}
end
function Bags.RestorePosition()
    local view = Bags.inventory
    if not view or InCombatLockdown() then return end
    local pos = LunaUITweaksBagsDB.position
    local valid = {TOP = true, BOTTOM = true, LEFT = true, RIGHT = true, CENTER = true, TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true}
    view:ClearAllPoints()
    if type(pos) == "table" and valid[pos.point] and valid[pos.relativePoint] and type(pos.x) == "number" and type(pos.y) == "number" then
        view:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    else view:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -30, 100) end
end
function Bags.UpdateEscapeRegistration()
    local name = "LunaUITweaks_BagsInventory"
    for i = #UISpecialFrames, 1, -1 do if UISpecialFrames[i] == name then table.remove(UISpecialFrames, i) end end
    -- Generic CloseSpecialWindows calls Hide from insecure Lua. This window
    -- instead owns secure bindings only while shown.
    Bags.RefreshCloseBindings()
end
function Bags.RefreshCloseBindings()
    local view = Bags.inventory
    if not view or InCombatLockdown() then return end
    local keys, seen = {"ESCAPE"}, {ESCAPE = true}
    if GetBindingKey then
        for _, action in ipairs({"TOGGLEBACKPACK", "OPENALLBAGS", "TOGGLEALLBAGS", "TOGGLEBAG1", "TOGGLEBAG2", "TOGGLEBAG3", "TOGGLEBAG4", "TOGGLEBAG5", "TOGGLEREAGENTBAG"}) do
            for _, key in ipairs({GetBindingKey(action)}) do
                if not seen[key] then
                    keys[#keys + 1] = key
                    seen[key] = true
                end
            end
        end
    end
    for i, key in ipairs(keys) do view:SetAttribute("close-key-" .. i, key) end
    view:SetAttribute("close-key-count", #keys)
    if view:IsShown() then view:Execute(view:GetAttribute("_onshow")) end
end
local function NewView(name, parent, isBank)
    local view = CreateFrame("Frame", name, parent, isBank and "BackdropTemplate" or "BackdropTemplate,SecureHandlerShowHideTemplate")
    view:SetSize(540, math.min(620, UIParent:GetHeight() - 100))
    view:SetFrameStrata("HIGH")
    view:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    view:SetBackdropColor(.035, .045, .06, 1)
    view:SetBackdropBorderColor(.25, .3, .35, 1)
    view:EnableMouse(true)
    view:SetClampedToScreen(true)
    view:Hide()
    view.title = Text(view, isBank and "Luna Bags — Bank" or "Luna Bags", 14, -12, "GameFontNormalLarge")
    local close = CreateFrame("Button", not isBank and "LunaUITweaks_BagsSecureClose" or nil, view,
        isBank and "UIPanelCloseButton,SecureActionButtonTemplate" or "UIPanelButtonTemplate,SecureHandlerClickTemplate")
    view.close = close
    close:SetPoint("TOPRIGHT", -2, -2)
    if isBank then
        -- Clicks Blizzard's own bank close button (bound in Bags.BindBankButtons).
        close:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
        close:SetAttribute("type", "click")
    else
        close:SetSize(24, 24)
        close:SetText("X")
        close:RegisterForClicks("AnyUp")
        close:SetFrameRef("inventory", view)
        close:SetAttribute("_onclick", [[self:GetFrameRef("inventory"):Hide()]])
        view:SetAttribute("_onshow",[[
            self:ClearBindings()
            for i=1,(self:GetAttribute("close-key-count") or 0) do
                self:SetBindingClick(true,self:GetAttribute("close-key-"..i),"LunaUITweaks_BagsSecureClose","LeftButton")
            end
        ]])
        view:SetAttribute("_onhide", [[self:ClearBindings()]])
        view:HookScript("OnHide", function() Bags.pendingInventoryShown = nil end)
    end
    view.status = Text(view, "", 14, isBank and -73 or -40, "GameFontHighlightSmall")
    view.scroll = CreateFrame("ScrollFrame", nil, view, "UIPanelScrollFrameTemplate")
    view.scroll:SetPoint("TOPLEFT", 14, isBank and -96 or -63)
    view.scroll:SetPoint("BOTTOMRIGHT", -32, 40)
    view.content = CreateFrame("Frame", nil, view.scroll)
    view.content:SetSize(COLUMNS * STEP, 1)
    view.scroll:SetScrollChild(view.content)
    view.content.IsCombinedBagContainer = function() return true end
    view.buttons = {}
    view.slotButtons = {}
    view.headings = {}
    view.footer = Text(view, "", 14, 0, "GameFontHighlightSmall")
    view.footer:ClearAllPoints()
    view.footer:SetPoint("BOTTOMLEFT", 14, 14)
    if not isBank then
        CreateBagSlots(view)
        local search = CreateFrame("EditBox", nil, view, "InputBoxTemplate")
        view.search = search
        search:SetSize(220, 23)
        search:SetPoint("TOPLEFT", 160, -9)
        search:SetAutoFocus(false)
        search:SetMaxLetters(120)
        local hint = Text(search, "Search items...", 4, -5, "GameFontDisableSmall")
        search:SetScript("OnTextChanged", function(self)
            hint:SetShown(self:GetText() == "")
            Bags.SetSearchText(self:GetText())
        end)
        search:SetScript("OnEditFocusGained", function() hint:Hide() end)
        search:SetScript("OnEditFocusLost", function(self) hint:SetShown(self:GetText() == "") end)
        search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        search:SetScript("OnEscapePressed", function(self)
            self:SetText("")
            self:ClearFocus()
        end)
        search:SetScript("OnHide", function(self) self:ClearFocus() end)
        view:SetMovable(true)
        view:RegisterForDrag("LeftButton")
        view:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
        view.finishDrag = function(self)
            if InCombatLockdown() then
                self.pendingDragStop = true
                return
            end
            self.pendingDragStop = nil
            self:StopMovingOrSizing()
            SavePosition(self)
        end
        view:SetScript("OnDragStop", view.finishDrag)
        Bags.UpdateEscapeRegistration()
    else
        view.bankTab = Enum.BankType.Account
        -- Tabs click Blizzard's own bank tabs; the view then follows Blizzard's active bank.
        local function FollowBlizzard() Bags.SelectBank(Bags.ActiveBankType()) end
        view.accountTab = ProxyButton(view, "Warband Bank", 14, -40, 135, FollowBlizzard)
        view.characterTab = ProxyButton(view, "Bank", 159, -40, 100, FollowBlizzard)
        view.deposit = Button(view, "Deposit Warbound", 269, -40, 160, function() Bags.DepositWarbound() end)
    end
    view:HookScript("OnShow", function(self)
        Bags.QueueRefresh()
    end)
    return view
end
function Bags.CreateInventory()
    if not Bags.inventory then
        Bags.inventory = NewView("LunaUITweaks_BagsInventory", UIParent, false)
        Bags.RestorePosition()
        Bags.UpdateEscapeRegistration()
    end
    return Bags.inventory
end
-- Blizzard creates its bank tab buttons late; bind proxies out of combat each open.
local function BlizzardTabButton(bankType)
    local tabID = bankType == Enum.BankType.Account and BankFrame.accountBankTabID or BankFrame.characterBankTabID
    if BankFrame.GetTabIDForBankType then tabID = BankFrame:GetTabIDForBankType(bankType) end
    local system = BankFrame.TabSystem
    return tabID and system and system.GetTabButton and system:GetTabButton(tabID)
end
function Bags.BindBankButtons()
    local view = Bags.bank
    if not view or InCombatLockdown() then return end
    for bankType, tab in pairs({[Enum.BankType.Account] = view.accountTab, [Enum.BankType.Character] = view.characterTab}) do
        local target = BlizzardTabButton(bankType)
        tab:SetAttribute("clickbutton", target)
        -- Missing Blizzard tab API: fall back to selecting directly (may taint).
        if not target then
            tab:SetScript("PostClick", function()
                local tabID = bankType == Enum.BankType.Account and BankFrame.accountBankTabID or BankFrame.characterBankTabID
                if tabID and BankFrame.SetTab then BankFrame:SetTab(tabID) end
                Bags.SelectBank(bankType)
            end)
        end
    end
    view.close:SetAttribute("clickbutton", BankFrame.CloseButton)
    if not BankFrame.CloseButton then view.close:SetScript("PostClick", function() HideUIPanel(BankFrame) end) end
end
-- Blizzard's active bank decides where right-click withdraw/deposit goes.
function Bags.ActiveBankType()
    if BankFrame.GetActiveBankType then
        local bankType = BankFrame:GetActiveBankType()
        if bankType ~= nil then return bankType end
    end
    return Bags.bank and Bags.bank.bankTab or Enum.BankType.Character
end
function Bags.CreateBank()
    if not Bags.bank then
        Bags.bank = NewView("LunaUITweaks_BagsBank", BankFrame, true)
        Bags.bank:SetClampedToScreen(false)
        -- Opaque cover retains Blizzard's bank interaction, tab state and close handling.
        Bags.bank:SetFrameLevel(BankFrame:GetFrameLevel() + 100)
        Bags.bank:SetPoint("TOPLEFT", BankFrame, "TOPLEFT", -4, 4)
    end
    local view = Bags.bank
    view:SetSize(math.max(540, BankFrame:GetWidth() + 90), math.max(580, BankFrame:GetHeight() + 40))
    return view
end
local function RetargetEmpty(button)
    if InCombatLockdown() then return false end
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" then return false end
    local entry = Bags.FindEmptySlot(button.freeSpaceIDs, itemID)
    if not entry then return false end
    button:SetBagID(entry.bag)
    button:SetID(entry.slot)
    return true
end
local function FreeSpaceClick(self, mouse)
    -- An aggregate tile must never use an item or act on a stale occupied slot.
    if mouse == "LeftButton" and RetargetEmpty(self) then
        C_Container.PickupContainerItem(self:GetBagID(), self:GetID())
    end
end
local function SlotButton(view, index, entry, aggregate)
    -- Bind native item buttons to physical slots, never category/display index.
    -- The aggregate free-space tile has its own lifetime and input handlers.
    local key = entry.bag .. ":" .. entry.slot
    local button
    if aggregate then button = view.freeButton else button = view.slotButtons[key] end
    if not button then
        local inventory = view == Bags.inventory
        -- Put the native container template last so its secure XML OnClick is
        -- the hardware entry point, including vendor/bank/refund handling.
        local template = (inventory and "SecureActionButtonTemplate," or "") .. "ContainerFrameItemButtonTemplate"
        button = CreateFrame("ItemButton", nil, view.content, template)
        button.secureInventory = inventory
        if not inventory then
            -- Bank contents are withdrawal targets, not candidates for the active deposit context.
            button.GetItemContextMatchResult = function()
                return ItemButtonUtil.ItemContextMatchResult.DoesNotApply
            end
        end
        button.searchOverlay = button:CreateTexture(nil, "OVERLAY", nil, 7)
        button.searchOverlay:SetAllPoints()
        button.searchOverlay:SetColorTexture(0, 0, 0, .75)
        button.searchOverlay:Hide()
        button:SetSize(SIZE, SIZE)
        button:SetFrameLevel(view.content:GetFrameLevel() + 1)
        -- The Blizzard template owns click, split-stack, drag, refund and tooltip behavior.
        button:HookScript("OnHide", function(self)
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
        if aggregate then
            button.aggregateSlot = true
            button:SetScript("OnClick", FreeSpaceClick)
            button:SetScript("OnReceiveDrag", function(self) FreeSpaceClick(self, "LeftButton") end)
            button:SetScript("OnDragStart", function() end)
            view.freeButton = button
        else
            -- Never replace, save/reinstall, or wrap the native input scripts.
            -- Set the physical bag/slot once and leave them unchanged thereafter.
            button:SetBagID(entry.bag)
            button:SetID(entry.slot)
            view.slotButtons[key] = button
        end
    end
    view.buttons[index] = button
    return button
end
local function SuppressItemGlow(button)
    for _, name in ipairs({"newitemglowAnim", "flashAnim"}) do
        local animation = button[name]
        if animation then animation:Stop() end
    end
    for _, name in ipairs({"NewItemTexture", "BattlepayItemTexture", "flash", "BagIndicator"}) do
        local texture = button[name]
        if texture then texture:Hide() end
    end
end
local function UpdateSlotCooldown(button)
    if button.secureInventory then
        button:UpdateCooldown(button:HasItem())
    else
        -- Bank storage availability is independent of whether this character can use the item.
        button.Cooldown:Hide()
        SetItemButtonTextureVertexColor(button, 1, 1, 1)
    end
end
local function Populate(button, entry)
    button.freeSpaceIDs = nil
    if button.freeCount then button.freeCount:Hide() end
    if button.aggregateSlot then
        button:SetBagID(entry.bag)
        button:SetID(entry.slot)
    end
    local info = entry.info
    local level = Bags.GearItemLevel(info)
    if level and not button.itemLevel then
        button.itemLevel = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        button.itemLevel:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
        button.itemLevel:SetPoint("BOTTOMRIGHT", -2, 2)
    end
    if button.itemLevel then
        button.itemLevel:SetText(level or "")
        button.itemLevel:SetShown(level ~= nil)
    end
    button.searchItemID = info and info.itemID
    button.searchName = (entry.name or ""):lower()
    SetItemButtonTexture(button, info and info.iconFileID)
    SetItemButtonCount(button, info and info.stackCount or 0)
    SetItemButtonDesaturated(button, info and info.isLocked or false)
    button:SetHasItem(info ~= nil)
    button:SetReadable(info and info.isReadable)
    SetItemButtonTextureVertexColor(button, 1, 1, 1)
    UpdateSlotCooldown(button)
    local quest = C_Container.GetContainerItemQuestInfo(entry.bag, entry.slot)
    button:UpdateQuestItem(quest and quest.isQuestItem, quest and quest.questID, quest and quest.isActive)
    button:UpdateJunkItem(info and info.quality, info and info.hasNoValue)
    SetItemButtonQuality(button, info and info.quality, info and info.hyperlink)
    if not button.ItemSlotBackground then
        -- The combined-bags slot template is Retail-only; Forever uses the classic slot art.
        local ok, background = pcall(button.CreateTexture, button, nil, "BACKGROUND", "ItemSlotBackgroundCombinedBagsTemplate", -6)
        if not ok then
            background = button:CreateTexture(nil, "BACKGROUND", nil, -6)
            background:SetTexture("Interface\\Buttons\\UI-Slot-Background")
            background:SetTexCoord(0, 0.640625, 0, 0.640625)
        end
        button.ItemSlotBackground = background
        button.ItemSlotBackground:SetAllPoints()
    end
    if not button.secureInventory then
        button:SetMatchesSearch(true)
        button:UpdateItemContextMatching()
    end
    SuppressItemGlow(button)
    button.ItemSlotBackground:Show()
    button:Show()
    ApplySearch(button)
end
function Bags.Render(view, ids, available)
    if not view or not view:IsShown() then return end
    if InCombatLockdown() then
        view.status:SetText("Layout updates resume after combat.")
        return
    end
    if StackSplitFrame and StackSplitFrame:IsShown() then
        view.status:SetText("Finish splitting this stack to refresh the layout.")
        return
    end
    local scan = Bags.Scan(ids, view == Bags.inventory)
    local index, heading, y = 0, 0, 0
    local used = {}
    view.buttons = {}
    local function Section(name, items, aggregate)
        if #items == 0 then return end
        heading = heading + 1
        local label = view.headings[heading]
        if not label then
            label = Text(view.content, "", 0, 0)
            view.headings[heading] = label
        end
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", 0, -y)
        label:SetText(name .. " (" .. #items .. ")")
        label:Show()
        y = y + 24
        for i, entry in ipairs(items) do
            index = index + 1
            local button = SlotButton(view, index, entry, aggregate)
            used[button] = true
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", ((i - 1) % COLUMNS) * STEP, -y - math.floor((i - 1) / COLUMNS) * STEP)
            Populate(button, entry)
        end
        y = y + math.ceil(#items / COLUMNS) * STEP + 12
    end
    for _, category in ipairs(Bags.categories) do Section(category.name, scan[category.key]) end
    if #scan.empty > 0 then
        Section("Free Space", {scan.empty[1]}, true)
        -- One tile represents every free slot, with a visible count even when only one remains.
        local button = view.buttons[index]
        button.freeSpaceIDs = ids
        if not button.freeCount then
            button.freeCount = Text(button, "", 0, 0, "GameFontHighlightSmall")
            button.freeCount:ClearAllPoints()
            button.freeCount:SetPoint("BOTTOMRIGHT", -2, 2)
        end
        button.freeCount:SetText(tostring(#scan.empty))
        button.freeCount:Show()
        view.headings[heading]:SetText("Free Space (" .. #scan.empty .. ")")
    end
    for _, button in pairs(view.slotButtons) do if not used[button] then button:Hide() end end
    if view.freeButton and not used[view.freeButton] then view.freeButton:Hide() end
    for i = heading + 1, #view.headings do view.headings[i]:Hide() end
    view.content:SetHeight(math.max(y, 1))
    view.scroll:SetVerticalScroll(math.min(view.scroll:GetVerticalScroll(), math.max(0, y - view.scroll:GetHeight())))
    view.status:SetText(view.depositMessage or (not available and "This bank is unavailable here." or (scan.capacity == 0 and "No purchased bank tabs." or "")))
    view.footer:SetText(("%d / %d slots used   •   %d free"):format(scan.occupied, scan.capacity, #scan.empty))
end
function Bags.UpdateCooldowns()
    for _, view in ipairs({Bags.inventory, Bags.bank}) do
        if view:IsShown() then
            for _, button in ipairs(view.buttons) do if button:IsShown() then UpdateSlotCooldown(button) end end
        end
    end
end
