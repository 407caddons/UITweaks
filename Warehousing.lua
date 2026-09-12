local addonName, addonTable = ...
local Warehousing = {}
addonTable.Warehousing = Warehousing

local EventBus = addonTable.EventBus
local Helpers = addonTable.ConfigHelpers

-- Constants
local SCAN_DELAY = 0.5
local autoBuyConfirmText = ""
StaticPopupDialogs["LUNA_WAREHOUSING_AUTOBUY_CONFIRM"] = {
    text = "%s",
    button1 = "Buy",
    button2 = "Skip",
    timeout = 0,
    whileDead = false,
    hideOnEscape = true,
}
local NUM_BAG_SLOTS = NUM_BAG_SLOTS or 4
local REAGENT_BAG_SLOT = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag or 5
local MAX_ATTACHMENTS = ATTACHMENTS_MAX_SEND or 12
local MAIL_STEP_DELAY = 0.3

-- Prebuilt bag list (player bags 0..NUM_BAG_SLOTS + reagent bag) — used by all scan helpers
local BAG_LIST = (function()
    local t = {}
    for bag = 0, NUM_BAG_SLOTS do t[#t + 1] = bag end
    if REAGENT_BAG_SLOT > NUM_BAG_SLOTS then t[#t + 1] = REAGENT_BAG_SLOT end
    return t
end)()

-- State
local scanTimer = nil
local popupFrame = nil
local popupRows = {}
local popupMode = nil -- "mail" or "bank"
local mailQueue = {}  -- { { charName, items = { {bag, slot, itemID, count}, ... } }, ... }
local mailQueueIndex = 0
local mailSending = false
local bankSyncing = false
local eventsRegistered = false
local atMailbox = false
local atBank = false
local atWarbandBank = false
local atMerchant = false
local merchantSession = 0
local autoBuyAttempted = false
local pendingPurchases = {} -- reservations survive rapid merchant reopening
-- (drag-and-drop is set up via SetupDropTarget from WarehousingPanel.lua)

-- Centralized Logging
local Log = function(msg, level)
    if addonTable.Core and addonTable.Core.Log then
        addonTable.Core.Log("Warehousing", msg, level)
    end
end

local GetCharacterKey = function() return addonTable.Core.GetCharacterKey() end

local function EnsureDB()
    LunaUITweaks_WarehousingData = LunaUITweaks_WarehousingData or {}
    LunaUITweaks_WarehousingData.items = LunaUITweaks_WarehousingData.items or {}
    LunaUITweaks_WarehousingData.characters = LunaUITweaks_WarehousingData.characters or {}
end

--- Get all character keys from the warehousing DB (excluding current character)
function Warehousing.GetCharacterNames()
    EnsureDB()
    local names = {}
    local currentKey = GetCharacterKey()
    for key in pairs(LunaUITweaks_WarehousingData.characters) do
        if key ~= currentKey then
            local charName = key:match("^(.+) %- ")
            if charName then
                table.insert(names, charName)
            end
        end
    end
    table.sort(names)
    return names
end

--- Get all known character keys (including current) sorted alphabetically.
-- Uses CharacterRegistry as the authoritative source when available, falls back to local data.
function Warehousing.GetAllCharacterKeys()
    if addonTable.Core and addonTable.Core.CharacterRegistry then
        return addonTable.Core.CharacterRegistry.GetAllKeys()
    end
    EnsureDB()
    local keys = {}
    for key in pairs(LunaUITweaks_WarehousingData.characters) do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end

--- Set which characters the min-keep rule applies to for an item.
-- @param itemID number
-- @param chars table { ["Name - Realm"] = true, ... } or nil/empty for all characters
function Warehousing.SetMinKeepChars(itemID, chars)
    EnsureDB()
    local item = LunaUITweaks_WarehousingData.items[itemID]
    if not item then return end
    -- Store nil if empty (means "all characters")
    local hasAny = false
    if chars then
        for _ in pairs(chars) do hasAny = true; break end
    end
    item.minKeepChars = hasAny and chars or nil
end

--- Get destination options for a given item
function Warehousing.GetDestinations(itemID)
    EnsureDB()
    local itemData = LunaUITweaks_WarehousingData.items[itemID]
    -- Use stored warbandAllowed flag (set at add-time via C_Bank.IsItemAllowedInBankType).
    -- Falls back to true for old entries that predate this field so they don't lose options.
    local canWarband = itemData and (itemData.warbandAllowed == true or itemData.warbandAllowed == nil)
    local destinations
    if not canWarband then
        -- Not warband-eligible (truly soulbound): personal bank only, no mailing
        destinations = { "Personal Bank" }
    else
        destinations = { "Warband Bank", "Personal Bank" }
        -- Add current character first (so you can target this toon as a mail recipient too)
        local currentKey = GetCharacterKey()
        local currentName = currentKey:match("^(.+) %- ")
        if currentName then
            table.insert(destinations, currentName .. " (you)")
        end
        local charNames = Warehousing.GetCharacterNames()
        for _, name in ipairs(charNames) do
            table.insert(destinations, name)
        end
    end
    return destinations
end

--- Extract item name from a hyperlink string like "|cff...|Hitem:...|h[Item Name]|h|r"
-- TWW quality-tier items embed an atlas texture inside the brackets: [Item Name |A:...|a]
-- So we strip any |A:...|a atlas tags and trim whitespace after extraction.
local function GetNameFromHyperlink(hyperlink)
    if not hyperlink then return nil end
    local name = hyperlink:match("%[(.-)%]")
    if not name then return nil end
    -- Strip embedded atlas textures: |A:...|a
    name = name:gsub("|A.-|a", "")
    -- Trim whitespace
    name = name:match("^%s*(.-)%s*$")
    return name ~= "" and name or nil
end

--- Scan bags for tracked items only
-- Matches by name (via hyperlink) to handle TWW quality-tier itemID variants
local function ScanBags()
    EnsureDB()
    local trackedItems = LunaUITweaks_WarehousingData.items
    local counts = {}

    -- Build a name->key lookup from tracked items
    local trackedByName = {}
    for k, v in pairs(trackedItems) do
        if v.name then
            trackedByName[v.name:lower()] = k
        end
    end

    for _, bag in ipairs(BAG_LIST) do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                -- First try direct ID match
                local trackedKey = nil
                if trackedItems[info.itemID] then
                    trackedKey = info.itemID
                else
                    -- Fall back to name match via hyperlink (handles quality-tier ID variants)
                    local itemName = GetNameFromHyperlink(info.hyperlink)
                    if itemName then
                        trackedKey = trackedByName[itemName:lower()]
                    end
                end

                if trackedKey then
                    local tracked = trackedItems[trackedKey]
                    tracked.knownItemIDs = tracked.knownItemIDs or {}
                    tracked.knownItemIDs[info.itemID] = true
                    counts[trackedKey] = (counts[trackedKey] or 0) + info.stackCount
                end
            end
        end
    end

    return counts
end

--- Helper: scan a list of container IDs for tracked items
local function ScanContainers(containerIDs)
    EnsureDB()
    local trackedItems = LunaUITweaks_WarehousingData.items
    local counts = {}

    -- Build name lookup
    local trackedByName = {}
    for k, v in pairs(trackedItems) do
        if v.name then trackedByName[v.name:lower()] = k end
    end

    for _, containerID in ipairs(containerIDs) do
        local numSlots = C_Container.GetContainerNumSlots(containerID)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(containerID, slot)
            if info and info.itemID then
                local trackedKey = nil
                if trackedItems[info.itemID] then
                    trackedKey = info.itemID
                else
                    local itemName = GetNameFromHyperlink(info.hyperlink)
                    if itemName then
                        trackedKey = trackedByName[itemName:lower()]
                    end
                end
                if trackedKey then
                    local tracked = trackedItems[trackedKey]
                    tracked.knownItemIDs = tracked.knownItemIDs or {}
                    tracked.knownItemIDs[info.itemID] = true
                    counts[trackedKey] = (counts[trackedKey] or 0) + info.stackCount
                end
            end
        end
    end
    return counts
end

--- Get container IDs for warband (account) bank
-- TWW: AccountBankTab_1 starts at Enum.BagIndex value 13 (index 12 in some builds)
-- We use C_Bank.FetchPurchasedBankTabIDs to get the actual purchased tab count
local function GetWarbandBankContainers()
    local ids = {}
    if not C_Bank or not C_Bank.FetchPurchasedBankTabIDs then return ids end
    if not Enum or not Enum.BagIndex or not Enum.BagIndex.AccountBankTab_1 then return ids end
    local tabIDs = C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Account)
    if not tabIDs then return ids end
    local base = Enum.BagIndex.AccountBankTab_1
    for i = 1, #tabIDs do
        table.insert(ids, base + (i - 1))
    end
    return ids
end

--- Get container IDs for personal (character) bank
-- TWW restructured the bank: CharacterBankTab_1 through CharacterBankTab_6
-- Old BANK_CONTAINER (-1) and bank bag slots no longer work
local function GetPersonalBankContainers()
    local ids = {}
    if not C_Bank or not C_Bank.FetchPurchasedBankTabIDs then return ids end
    if not Enum or not Enum.BagIndex then return ids end

    -- Use CharacterBankTab_1 enum if available (TWW+)
    if Enum.BagIndex.CharacterBankTab_1 then
        local tabIDs = C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Character)
        if tabIDs then
            local base = Enum.BagIndex.CharacterBankTab_1
            for i = 1, #tabIDs do
                table.insert(ids, base + (i - 1))
            end
        end
    end

    return ids
end

--- Get container IDs for whichever bank is currently open
local function GetOpenBankContainers()
    local ids = {}
    if C_Bank and C_Bank.CanViewBank then
        if C_Bank.CanViewBank(Enum.BankType.Character) then
            for _, id in ipairs(GetPersonalBankContainers()) do
                table.insert(ids, id)
            end
        end
        if C_Bank.CanViewBank(Enum.BankType.Account) then
            for _, id in ipairs(GetWarbandBankContainers()) do
                table.insert(ids, id)
            end
        end
    end
    return ids
end

--- Scan whichever bank is currently open for tracked items
local function ScanOpenBank()
    return ScanContainers(GetOpenBankContainers())
end

local function ReconcilePurchases(bagCounts)
    for itemID, reservation in pairs(pendingPurchases) do
        if (bagCounts[itemID] or 0) >= reservation.expected then pendingPurchases[itemID] = nil end
    end
end

--- Debounced bag scan
local function ScheduleBagScan()
    if not UIThingsDB.warehousing.enabled then return end
    if scanTimer then scanTimer:Cancel() end
    scanTimer = C_Timer.NewTimer(SCAN_DELAY, function()
        scanTimer = nil
        if not UIThingsDB.warehousing.enabled then return end
        EnsureDB()
        local key = GetCharacterKey()
        local bagCounts = ScanBags()
        ReconcilePurchases(bagCounts)
        if atBank then ScanOpenBank() end
        LunaUITweaks_WarehousingData.characters[key] = LunaUITweaks_WarehousingData.characters[key] or {}
        LunaUITweaks_WarehousingData.characters[key].lastSeen = time()
        LunaUITweaks_WarehousingData.characters[key].bagCounts = bagCounts
        -- Refresh popup if visible
        if popupFrame and popupFrame:IsShown() then
            Warehousing.RefreshPopup()
        end
    end)
end

--- Calculate overflow and deficit for current character
local function IsMaterial(itemID, item)
    local classID = select(6, C_Item.GetItemInfoInstant(itemID)) or item.classID
    return classID == 7
end

local function GetAccessibleMaterialCount(itemID, item)
    -- Ask the client for current bags + personal/reagent + account bank stock.
    -- Remember discovered quality variants, but never reuse stale cached quantities.
    local ids = { [itemID] = true }
    for id in pairs(item.knownItemIDs or {}) do ids[id] = true end
    -- Migrate variant identities from the old cache (counts are deliberately ignored).
    local old = LunaUITweaks_ReagentData and LunaUITweaks_ReagentData.warband
    for id in pairs(old and old.items or {}) do
        local name = C_Item.GetItemNameByID(id)
        if name and item.name and name:lower() == item.name:lower() then ids[id] = true end
    end
    local total = 0
    for id in pairs(ids) do
        if id == itemID or not LunaUITweaks_WarehousingData.items[id] then
            local count = C_Item.GetItemCount(id, true, false, true, true)
            if issecretvalue(count) or type(count) ~= "number" then return nil end
            total = total + count
        end
    end
    return total
end

local function CalculateOverflowDeficit()
    EnsureDB()
    local bagCounts = ScanBags()
    local items = LunaUITweaks_WarehousingData.items
    local overflow = {} -- { [itemID] = { count, destination } }
    local deficit = {}  -- { [itemID] = { count } }
    local currentKey = GetCharacterKey()

    for itemID, itemData in pairs(items) do
        local bagCount = bagCounts[itemID] or 0
        local dest = itemData.destination or "Warband Bank"

        -- Determine effective minKeep for this character
        -- If minKeepChars is set, minKeep only applies to listed characters; others keep 0
        local minKeep = 0
        local chars = itemData.minKeepChars
        if chars then
            if chars[currentKey] then
                minKeep = itemData.minKeep or 0
            end
            -- Not in list: treat minKeep as 0 (deposit everything above 0)
        else
            minKeep = itemData.minKeep or 0
        end

        local material = IsMaterial(itemID, itemData)
        local available = bagCount
        if material then available = GetAccessibleMaterialCount(itemID, itemData) end
        if available then
            -- Materials remain accessible in either bank; consumables retain
            -- their minimum in bags. Mailing must preserve accessible stock.
            local excess = material and math.min(bagCount, math.max(0, available - minKeep))
                or math.max(0, bagCount - minKeep)
            if material and (dest == "Warband Bank" or dest == "Personal Bank") then excess = bagCount end
            if excess > 0 then overflow[itemID] = { count = excess, destination = dest } end
            if available < minKeep then deficit[itemID] = { count = minKeep - available } end
        end
    end

    return overflow, deficit
end

--- Check if a container item matches a tracked itemID (by ID or name)
local function SlotMatchesTracked(info, itemID)
    if not info or not info.itemID then return false end
    if info.itemID == itemID then return true end
    -- Fall back to name match for quality-tier variants
    EnsureDB()
    local trackedData = LunaUITweaks_WarehousingData.items[itemID]
    if trackedData and trackedData.name then
        local slotName = GetNameFromHyperlink(info.hyperlink)
        if slotName and slotName:lower() == trackedData.name:lower() then
            return true
        end
    end
    return false
end

--- Find bag slots containing a specific item (matches by name for quality variants)
local function FindItemSlots(itemID, maxCount)
    local slots = {}
    local remaining = maxCount
    for _, bag in ipairs(BAG_LIST) do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            if remaining <= 0 then return slots end
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if SlotMatchesTracked(info, itemID) then
                local take = math.min(info.stackCount, remaining)
                table.insert(slots, { bag = bag, slot = slot, count = take })
                remaining = remaining - take
            end
        end
    end
    return slots
end

--- Find slots in the currently open bank containing a specific item
local function FindOpenBankSlots(itemID, maxCount)
    local slots = {}
    local remaining = maxCount
    local containerIDs = GetOpenBankContainers()

    for _, containerID in ipairs(containerIDs) do
        local numSlots = C_Container.GetContainerNumSlots(containerID)
        for slot = 1, numSlots do
            if remaining <= 0 then return slots end
            local info = C_Container.GetContainerItemInfo(containerID, slot)
            if SlotMatchesTracked(info, itemID) then
                local take = math.min(info.stackCount, remaining)
                table.insert(slots, { bag = containerID, slot = slot, count = take })
                remaining = remaining - take
            end
        end
    end
    return slots
end

--- Find an empty slot in bags (including reagent bag)
local function FindEmptyBagSlot()
    for _, bag in ipairs(BAG_LIST) do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if not info then
                return bag, slot
            end
        end
    end
    return nil, nil
end


--------------------------------------------------------------
-- Popup Frame
--------------------------------------------------------------

local function CreatePopupFrame()
    if popupFrame then return popupFrame end

    popupFrame = CreateFrame("Frame", "LunaUITweaks_WarehousingPopup", UIParent, "BackdropTemplate")
    popupFrame:SetSize(320, 350)
    popupFrame:SetFrameStrata("DIALOG")
    popupFrame:SetMovable(true)
    popupFrame:EnableMouse(true)
    popupFrame:SetClampedToScreen(true)
    popupFrame:RegisterForDrag("LeftButton")
    popupFrame:SetScript("OnDragStart", popupFrame.StartMoving)
    popupFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        UIThingsDB.warehousing.framePos = { point = point, relPoint = relPoint or point, x = x, y = y }
    end)

    -- Apply position
    local pos = UIThingsDB.warehousing.framePos
    popupFrame:ClearAllPoints()
    popupFrame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x, pos.y)

    -- Apply backdrop
    Helpers.ApplyFrameBackdrop(popupFrame, true, UIThingsDB.warehousing.frameBorderColor,
        true, UIThingsDB.warehousing.frameBgColor)

    -- Title
    popupFrame.title = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    popupFrame.title:SetPoint("TOPLEFT", 10, -10)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, popupFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() popupFrame:Hide() end)

    -- Status text
    popupFrame.statusText = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    popupFrame.statusText:SetPoint("BOTTOMLEFT", 10, 40)
    popupFrame.statusText:SetTextColor(0.7, 0.7, 0.7)

    -- Scroll frame for items
    local scrollFrame = CreateFrame("ScrollFrame", "LunaUITweaks_WarehousingPopupScroll", popupFrame,
        "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -35)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 60)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() or 260)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    popupFrame.scrollChild = scrollChild
    popupFrame.scrollFrame = scrollFrame

    -- Action button
    popupFrame.actionBtn = CreateFrame("Button", nil, popupFrame, "UIPanelButtonTemplate")
    popupFrame.actionBtn:SetSize(120, 26)
    popupFrame.actionBtn:SetPoint("BOTTOM", -35, 8)

    -- Refresh button
    popupFrame.refreshBtn = CreateFrame("Button", nil, popupFrame, "UIPanelButtonTemplate")
    popupFrame.refreshBtn:SetSize(60, 26)
    popupFrame.refreshBtn:SetPoint("LEFT", popupFrame.actionBtn, "RIGHT", 4, 0)
    popupFrame.refreshBtn:SetText("Refresh")
    popupFrame.refreshBtn:SetScript("OnClick", function()
        Warehousing.RefreshPopup()
    end)

    popupFrame:Hide()
    return popupFrame
end

--- Create or reuse a popup row
local function GetPopupRow(index)
    if popupRows[index] then return popupRows[index] end

    local parent = popupFrame.scrollChild
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(22)
    row:SetPoint("LEFT", 0, 1)
    row:SetPoint("RIGHT", 0, 1)

    -- Background
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()

    -- Icon
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 2, 1)

    -- Item name
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 4, 1)
    row.nameText:SetWidth(140)
    row.nameText:SetJustifyH("LEFT")

    -- Count text
    row.countText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.countText:SetPoint("RIGHT", -5, 1)
    row.countText:SetJustifyH("RIGHT")

    -- Destination text
    row.destText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.destText:SetPoint("RIGHT", row.countText, "LEFT", -10, 1)
    row.destText:SetJustifyH("RIGHT")

    popupRows[index] = row
    return row
end

--- Create a category header row
local function GetHeaderRow(index)
    local row = GetPopupRow(index)
    row.icon:Hide()
    row.destText:SetText("")
    row.countText:SetText("")
    row.bg:SetColorTexture(0.2, 0.2, 0.2, 0.6)
    return row
end

--- Refresh the popup content.
-- Returns true if there are actionable items for the current mode (used by OnMailShow to decide visibility).
function Warehousing.RefreshPopup()
    if not popupFrame then return false end

    EnsureDB()
    local overflow, deficit = CalculateOverflowDeficit()
    local hasAction = false

    -- Hide all rows
    for _, row in ipairs(popupRows) do
        row:Hide()
    end

    local rowIndex = 0
    local yOffset = 0
    local ROW_HEIGHT = 22

    if popupMode == "mail" then
        popupFrame.title:SetText("Warehousing - Mailbox")
        popupFrame.actionBtn:SetText("Mail")

        -- Group overflow items by destination (only non-bank, non-self destinations)
        local currentName = GetCharacterKey():match("^(.+) %- ") or ""
        local byDest = {}
        for itemID, data in pairs(overflow) do
            local dest = data.destination
            -- Strip " (you)" suffix that may have been stored when this character was active
            local destPlain = dest:match("^(.+) %(you%)$") or dest
            if dest ~= "Warband Bank" and dest ~= "Personal Bank"
                and destPlain:lower() ~= currentName:lower() then
                byDest[dest] = byDest[dest] or {}
                byDest[dest][itemID] = data.count
            end
        end

        local hasItems = false
        for dest, items in pairs(byDest) do
            hasItems = true
            -- Header
            rowIndex = rowIndex + 1
            local header = GetHeaderRow(rowIndex)
            header:SetPoint("TOPLEFT", 0, -yOffset)
            header.nameText:SetText("|cff00ff96> " .. dest .. "|r")
            header.nameText:SetPoint("LEFT", 2, 1)
            header:Show()
            yOffset = yOffset + ROW_HEIGHT

            for itemID, count in pairs(items) do
                local itemData = LunaUITweaks_WarehousingData.items[itemID]
                rowIndex = rowIndex + 1
                local row = GetPopupRow(rowIndex)
                row:SetPoint("TOPLEFT", 0, -yOffset)

                row.icon:Show()
                row.icon:SetTexture(itemData and itemData.icon or 134400)
                row.nameText:SetText(itemData and itemData.name or ("Item " .. itemID))
                row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 4, 1)
                row.countText:SetText("|cffff9900x" .. count .. "|r")
                row.destText:SetText("")
                row.bg:SetColorTexture(0.1, 0.1, 0.1, (rowIndex % 2 == 0) and 0.4 or 0.2)
                row:Show()
                yOffset = yOffset + ROW_HEIGHT
            end
        end

        if not hasItems then
            popupFrame.statusText:SetText("No items to mail.")
            popupFrame.actionBtn:Disable()
        else
            popupFrame.statusText:SetText("")
            popupFrame.actionBtn:Enable()
            hasAction = true
        end

    elseif popupMode == "bank" then
        popupFrame.title:SetText("Warehousing - Bank")
        popupFrame.actionBtn:SetText("Sync")

        local bankCounts = ScanOpenBank()

        -- Helper to add a deposit section for a specific bank destination
        local hasAnyAction = false
        local function AddDepositSection(destName, destLabel)
            local hasItems = false
            for itemID, data in pairs(overflow) do
                if data.destination == destName then
                    -- Check the correct bank is actually viewable
                    local canDeposit = (destName == "Warband Bank" and C_Bank.CanViewBank(Enum.BankType.Account))
                        or (destName == "Personal Bank" and C_Bank.CanViewBank(Enum.BankType.Character))
                    if canDeposit then
                        if not hasItems then
                            hasItems = true
                            hasAnyAction = true
                            rowIndex = rowIndex + 1
                            local header = GetHeaderRow(rowIndex)
                            header:SetPoint("TOPLEFT", 0, -yOffset)
                            header.nameText:SetText("|cff00ff96> Deposit (" .. destLabel .. ")|r")
                            header.nameText:SetPoint("LEFT", 2, 1)
                            header:Show()
                            yOffset = yOffset + ROW_HEIGHT
                        end

                        local itemData = LunaUITweaks_WarehousingData.items[itemID]
                        rowIndex = rowIndex + 1
                        local row = GetPopupRow(rowIndex)
                        row:SetPoint("TOPLEFT", 0, -yOffset)
                        row.icon:Show()
                        row.icon:SetTexture(itemData and itemData.icon or 134400)
                        row.nameText:SetText(itemData and itemData.name or ("Item " .. itemID))
                        row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 4, 1)
                        row.countText:SetText("|cff66bb6ax" .. data.count .. "|r")
                        row.destText:SetText("")
                        row.bg:SetColorTexture(0.1, 0.1, 0.1, (rowIndex % 2 == 0) and 0.4 or 0.2)
                        row:Show()
                        yOffset = yOffset + ROW_HEIGHT
                    end
                end
            end
        end

        AddDepositSection("Warband Bank", "Warband")
        AddDepositSection("Personal Bank", "Personal")

        -- Section: Withdraw (deficit items from open bank)
        -- Skip tradeskill reagents (classID 7) — accessible from warband bank during crafting
        local hasWithdraw = false
        for itemID, data in pairs(deficit) do
            local defItemData = LunaUITweaks_WarehousingData.items[itemID]
            if defItemData and IsMaterial(itemID, defItemData) then
                -- skip reagents
            else
            local bankHas = bankCounts[itemID] or 0
            if bankHas > 0 then
                local withdrawCount = math.min(data.count, bankHas)
                if not hasWithdraw then
                    hasWithdraw = true
                    hasAnyAction = true
                    rowIndex = rowIndex + 1
                    local header = GetHeaderRow(rowIndex)
                    header:SetPoint("TOPLEFT", 0, -yOffset)
                    header.nameText:SetText("|cffff9900> Withdraw|r")
                    header.nameText:SetPoint("LEFT", 2, 1)
                    header:Show()
                    yOffset = yOffset + ROW_HEIGHT
                end

                local itemData = LunaUITweaks_WarehousingData.items[itemID]
                rowIndex = rowIndex + 1
                local row = GetPopupRow(rowIndex)
                row:SetPoint("TOPLEFT", 0, -yOffset)
                row.icon:Show()
                row.icon:SetTexture(itemData and itemData.icon or 134400)
                row.nameText:SetText(itemData and itemData.name or ("Item " .. itemID))
                row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 4, 1)
                row.countText:SetText("|cffff9900x" .. withdrawCount .. "|r")
                row.destText:SetText("(bank: " .. bankHas .. ")")
                row.destText:SetTextColor(0.5, 0.5, 0.5)
                row.bg:SetColorTexture(0.1, 0.1, 0.1, (rowIndex % 2 == 0) and 0.4 or 0.2)
                row:Show()
                yOffset = yOffset + ROW_HEIGHT
            end
            end -- classID ~= 7
        end

        if not hasAnyAction then
            popupFrame.statusText:SetText("Everything is in order.")
            popupFrame.actionBtn:Disable()
        else
            popupFrame.statusText:SetText("")
            popupFrame.actionBtn:Enable()
            hasAction = true
        end
    end

    popupFrame.scrollChild:SetHeight(math.max(yOffset, 1))
    return hasAction
end

--------------------------------------------------------------
-- State Machine Queue Processor
--------------------------------------------------------------

local queueProcessor = CreateFrame("Frame")
local workQueue = {}
local isProcessing = false
local queueOnComplete = nil

local function IsGameReady()
    if GetCursorInfo() then return false end

    local function CheckContainers(bags)
        for _, bag in ipairs(bags) do
            local numSlots = C_Container.GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.isLocked then return false end
            end
        end
        return true
    end

    if not CheckContainers(BAG_LIST) then return false end
    if not CheckContainers(GetOpenBankContainers()) then return false end

    return true
end

local QUEUE_STUCK_TIMEOUT = 5  -- seconds before declaring stuck
local queueLastProgress = 0
local queueLastCount = 0
local StopQueueProcessor

local function ProcessQueueStep()
    if #workQueue == 0 then
        queueProcessor:SetScript("OnUpdate", nil)
        isProcessing = false
        if queueOnComplete then
            local cb = queueOnComplete
            queueOnComplete = nil
            cb()
        end
        return
    end

    -- Peek at next task: place_in_empty EXPECTS the cursor to hold an item,
    -- so skip the IsGameReady() check (which blocks on GetCursorInfo).
    local nextTask = workQueue[1]
    if nextTask.action ~= "place_in_empty" then
        if not IsGameReady() then
            -- Stuck detection: if no progress for QUEUE_STUCK_TIMEOUT seconds, abort
            if queueLastCount == #workQueue then
                if GetTime() - queueLastProgress > QUEUE_STUCK_TIMEOUT then
                    Log("Queue stuck for " .. QUEUE_STUCK_TIMEOUT .. "s — clearing cursor and aborting.", 2)
                    ClearCursor()
                    StopQueueProcessor()
                    bankSyncing = false
                    if popupFrame and popupFrame.actionBtn then
                        popupFrame.actionBtn:SetText("Sync")
                        popupFrame.actionBtn:Enable()
                    end
                    if popupFrame and popupFrame.statusText then
                        popupFrame.statusText:SetText("Sync stalled — try again.")
                    end
                end
            else
                queueLastCount = #workQueue
                queueLastProgress = GetTime()
            end
            return
        end
    end

    -- Progress: we're about to execute a task
    queueLastCount = #workQueue
    queueLastProgress = GetTime()

    local task = table.remove(workQueue, 1)

    if task.action == "split" then
        C_Container.SplitContainerItem(task.bag, task.slot, task.count)
        table.insert(workQueue, 1, { action = "place_in_empty", bankType = task.bankType })

    elseif task.action == "place_in_empty" then
        local emptyBag, emptySlot = FindEmptyBagSlot()
        if emptyBag then
            C_Container.PickupContainerItem(emptyBag, emptySlot)
            if task.bankType then
                table.insert(workQueue, 1, { action = "use", bag = emptyBag, slot = emptySlot, bankType = task.bankType })
            end
        else
            Log("No empty bag slot for split — clearing cursor.", 2)
            ClearCursor()
        end

    elseif task.action == "use" then
        C_Container.UseContainerItem(task.bag, task.slot, nil, task.bankType)

    elseif task.action == "attach_mail" then
        C_Container.PickupContainerItem(task.bag, task.slot)
        ClickSendMailItemButton(task.attachIndex)

    elseif task.action == "send_mail" then
        SendMail(task.charName, "Warehousing", "")
        -- Pause queue, wait for MAIL_SEND_SUCCESS event to trigger next batch
        queueProcessor:SetScript("OnUpdate", nil)
        isProcessing = false
    end
end

local function StartQueueProcessor(onComplete)
    if isProcessing then return end
    isProcessing = true
    queueOnComplete = onComplete
    queueLastCount = #workQueue
    queueLastProgress = GetTime()
    queueProcessor:SetScript("OnUpdate", ProcessQueueStep)
end

StopQueueProcessor = function()
    workQueue = {}
    isProcessing = false
    queueOnComplete = nil
    queueProcessor:SetScript("OnUpdate", nil)
end

--------------------------------------------------------------
-- Mail Logic
--------------------------------------------------------------

local function BuildMailQueue()
    local overflow, _ = CalculateOverflowDeficit()
    mailQueue = {}

    -- Group by destination (exclude banks and current character)
    local currentName = GetCharacterKey():match("^(.+) %- ") or ""
    local byDest = {}
    for itemID, data in pairs(overflow) do
        local dest = data.destination
        local destPlain = dest:match("^(.+) %(you%)$") or dest
        if dest ~= "Warband Bank" and dest ~= "Personal Bank"
            and destPlain:lower() ~= currentName:lower() then
            byDest[dest] = byDest[dest] or {}
            byDest[dest][itemID] = data.count
        end
    end

    for dest, items in pairs(byDest) do
        local recipientName = dest:match("^(.+) %(you%)$") or dest
        local allSlots = {}
        for itemID, count in pairs(items) do
            local slots = FindItemSlots(itemID, count)
            for _, s in ipairs(slots) do
                table.insert(allSlots, s)
            end
        end

        local batch = {}
        for _, s in ipairs(allSlots) do
            table.insert(batch, s)
            if #batch >= MAX_ATTACHMENTS then
                table.insert(mailQueue, { charName = recipientName, slots = batch })
                batch = {}
            end
        end
        if #batch > 0 then
            table.insert(mailQueue, { charName = recipientName, slots = batch })
        end
    end
end

local function ProcessNextMail()
    mailQueueIndex = mailQueueIndex + 1
    if mailQueueIndex > #mailQueue then
        mailSending = false
        mailQueueIndex = 0
        if popupFrame and popupFrame.actionBtn then
            popupFrame.actionBtn:SetText("Mail")
            popupFrame.actionBtn:Enable()
        end
        if popupFrame and popupFrame.statusText then
            popupFrame.statusText:SetText("All mail sent!")
        end
        Log("Mail queue complete.", 0)
        C_Timer.After(0.5, function() ScheduleBagScan() end)
        return
    end

    local entry = mailQueue[mailQueueIndex]
    if popupFrame and popupFrame.actionBtn then
        popupFrame.actionBtn:SetText("Sending " .. mailQueueIndex .. "/" .. #mailQueue)
        popupFrame.actionBtn:Disable()
    end

    ClearSendMail()
    SendMailNameEditBox:SetText(entry.charName)
    SendMailSubjectEditBox:SetText("Warehousing")

    workQueue = {}
    for i, slotInfo in ipairs(entry.slots) do
        table.insert(workQueue, { action = "attach_mail", bag = slotInfo.bag, slot = slotInfo.slot, attachIndex = i })
    end
    table.insert(workQueue, { action = "send_mail", charName = entry.charName })

    StartQueueProcessor(nil)
end

local function StartMailSending()
    if mailSending then return end
    BuildMailQueue()
    if #mailQueue == 0 then
        if popupFrame and popupFrame.statusText then
            popupFrame.statusText:SetText("Nothing to mail.")
        end
        return
    end
    mailSending = true
    mailQueueIndex = 0
    ProcessNextMail()
end

--------------------------------------------------------------
-- Bank Logic
--------------------------------------------------------------

local function StartBankSync(continuationPass)
    if bankSyncing then return end
    continuationPass = continuationPass or 1
    bankSyncing = true

    local canViewCharacter = C_Bank and C_Bank.CanViewBank and C_Bank.CanViewBank(Enum.BankType.Character)
    local canViewAccount = C_Bank and C_Bank.CanViewBank and C_Bank.CanViewBank(Enum.BankType.Account)
    Log("=== SYNC START === canViewCharacter=" .. tostring(canViewCharacter) .. " canViewAccount=" .. tostring(canViewAccount), 0)

    local overflow, deficit = CalculateOverflowDeficit()

    if popupFrame and popupFrame.actionBtn then
        popupFrame.actionBtn:SetText("Syncing...")
        popupFrame.actionBtn:Disable()
    end

    workQueue = {}

    for itemID, data in pairs(overflow) do
        local dest = data.destination
        local bankType = nil

        if dest == "Warband Bank" and canViewAccount then
            bankType = Enum.BankType.Account
        elseif dest == "Personal Bank" and canViewCharacter then
            bankType = Enum.BankType.Character
        end

        if bankType then
            local slots = FindItemSlots(itemID, data.count)
            for _, s in ipairs(slots) do
                local info = C_Container.GetContainerItemInfo(s.bag, s.slot)
                if info then
                    if info.stackCount > s.count then
                        table.insert(workQueue, { action = "split", bag = s.bag, slot = s.slot, count = s.count, bankType = bankType })
                    else
                        table.insert(workQueue, { action = "use", bag = s.bag, slot = s.slot, bankType = bankType })
                    end
                end
            end
        end
    end

    local bankCounts = ScanOpenBank()
    for itemID, data in pairs(deficit) do
        -- Tradeskill reagents (classID 7) are accessible directly from the warband bank
        -- during crafting, so never pull them out to fill a bag deficit.
        local itemData = LunaUITweaks_WarehousingData.items[itemID]
        if itemData and IsMaterial(itemID, itemData) then
            -- skip: reagents stay in bank, auto-buy from vendor instead
        else
        local bankHas = bankCounts[itemID] or 0
        if bankHas > 0 then
            local withdrawCount = math.min(data.count, bankHas)
            local bankSlots = FindOpenBankSlots(itemID, withdrawCount)
            for _, s in ipairs(bankSlots) do
                local info = C_Container.GetContainerItemInfo(s.bag, s.slot)
                if info then
                    if info.stackCount > s.count then
                        table.insert(workQueue, { action = "split", bag = s.bag, slot = s.slot, count = s.count })
                    else
                        table.insert(workQueue, { action = "use", bag = s.bag, slot = s.slot })
                    end
                end
            end
        end
        end -- classID ~= 7
    end

    Log("Total work items: " .. #workQueue, 0)

    if #workQueue == 0 then
        bankSyncing = false
        if popupFrame and popupFrame.statusText then
            popupFrame.statusText:SetText("Everything is in order.")
        end
        if popupFrame and popupFrame.actionBtn then
            popupFrame.actionBtn:SetText("Sync")
            popupFrame.actionBtn:Enable()
        end
        return
    end

    StartQueueProcessor(function()
        bankSyncing = false
        Log("Bank sync complete (pass " .. continuationPass .. ").", 0)

        if continuationPass < 5 then
            local bagSettled = false
            local bagListener = nil
            local bagFallback = nil
            local function OnBagsSettled()
                if bagSettled then return end
                bagSettled = true
                if bagListener then EventBus.Unregister("BAG_UPDATE_DELAYED", bagListener) end
                if bagFallback then bagFallback:Cancel() end

                local followOverflow = CalculateOverflowDeficit()
                local hasMore = false
                local cvChar = C_Bank and C_Bank.CanViewBank and C_Bank.CanViewBank(Enum.BankType.Character)
                local cvAcct = C_Bank and C_Bank.CanViewBank and C_Bank.CanViewBank(Enum.BankType.Account)
                for _, data in pairs(followOverflow) do
                    local dest = data.destination
                    if (dest == "Warband Bank" and cvAcct) or (dest == "Personal Bank" and cvChar) then
                        hasMore = true
                        break
                    end
                end

                if hasMore then
                    Log("Overflow remains after pass " .. continuationPass .. ", running follow-up sync.", 0)
                    if popupFrame and popupFrame.statusText then
                        popupFrame.statusText:SetText("Following up...")
                    end
                    StartBankSync(continuationPass + 1)
                else
                    ScheduleBagScan()
                    if popupFrame and popupFrame.actionBtn then
                        popupFrame.actionBtn:SetText("Sync")
                        popupFrame.actionBtn:Enable()
                    end
                    if popupFrame and popupFrame.statusText then
                        popupFrame.statusText:SetText("Sync complete!")
                    end
                    Warehousing.RefreshPopup()
                end
            end

            bagListener = OnBagsSettled
            EventBus.Register("BAG_UPDATE_DELAYED", bagListener, "Warehousing")
            bagFallback = C_Timer.NewTicker(3, function()
                bagFallback:Cancel()
                bagFallback = nil
                OnBagsSettled()
            end, 1)
        else
            ScheduleBagScan()
            if popupFrame and popupFrame.actionBtn then
                popupFrame.actionBtn:SetText("Sync")
                popupFrame.actionBtn:Enable()
            end
            if popupFrame and popupFrame.statusText then
                popupFrame.statusText:SetText("Sync limit reached — overflow may remain.")
            end
            Warehousing.RefreshPopup()
        end
    end)
end

--------------------------------------------------------------
-- Item Addition (shift-click from bags)
--------------------------------------------------------------

function Warehousing.AddItem(itemLink)
    if not itemLink then return false end
    local itemID = tonumber(itemLink:match("item:(%d+)"))
    if not itemID then return false end

    EnsureDB()
    if LunaUITweaks_WarehousingData.items[itemID] then
        return false -- Already tracked
    end

    -- Get item info
    local _, _, _, _, icon, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    local name, _, _, _, _, _, _, _, _, _, _, _, _, bindType = GetItemInfo(itemID)

    if not name then
        -- Item not cached yet, try to get basic info
        name = C_Item.GetItemNameByID(itemID) or ("Item " .. itemID)
    end

    -- Determine if this item can go to the warband (account) bank.
    -- Try C_Bank.IsItemAllowedInBankType first (most reliable when bank is open),
    -- but it can error/return false when the bank is closed. Fall back to bindType:
    -- only BoP (bindType == 1) items are truly restricted from the warband bank.
    local warbandAllowed = false
    local bankChecked = false
    if C_Bank and C_Bank.IsItemAllowedInBankType and ItemLocation then
        for _, bag in ipairs(BAG_LIST) do
            local numSlots = C_Container.GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID == itemID then
                    local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
                    local ok, result = pcall(C_Bank.IsItemAllowedInBankType, Enum.BankType.Account, loc)
                    if ok then
                        bankChecked = true
                        warbandAllowed = result
                    end
                    break
                end
            end
            if bankChecked then break end
        end
    end
    -- Fallback: if C_Bank check failed (bank not open, item not in bags, API error),
    -- assume warband-allowed for anything that isn't Bind on Pickup.
    if not bankChecked then
        warbandAllowed = (bindType ~= 1)
    end

    LunaUITweaks_WarehousingData.items[itemID] = {
        name = name,
        icon = icon or 134400,
        classID = classID or 15,
        subclassID = subclassID or 0,
        minKeep = 0,
        destination = warbandAllowed and "Warband Bank" or "Personal Bank",
        bindType = bindType or 0,
        warbandAllowed = warbandAllowed,
        itemLink = itemLink,
    }

    Log("Added item: " .. tostring(name) .. " (ID: " .. tostring(itemID) .. ") warbandAllowed=" .. tostring(warbandAllowed), 0)
    return true
end

function Warehousing.RemoveItem(itemID)
    EnsureDB()
    LunaUITweaks_WarehousingData.items[itemID] = nil
end

function Warehousing.GetTrackedItems()
    EnsureDB()
    return LunaUITweaks_WarehousingData.items
end

--- Set up drag-and-drop receiving on the config panel's drop zone
--- Called from WarehousingPanel.lua after creating the drop target frame
function Warehousing.SetupDropTarget(dropFrame)
    dropFrame:SetScript("OnReceiveDrag", function()
        local infoType, itemID, itemLink = GetCursorInfo()
        if infoType == "item" and itemLink then
            ClearCursor()
            if Warehousing.AddItem(itemLink) then
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                if Warehousing.RefreshConfigList then
                    Warehousing.RefreshConfigList()
                end
            end
        end
    end)
    dropFrame:SetScript("OnMouseUp", function()
        local infoType, itemID, itemLink = GetCursorInfo()
        if infoType == "item" and itemLink then
            ClearCursor()
            if Warehousing.AddItem(itemLink) then
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                if Warehousing.RefreshConfigList then
                    Warehousing.RefreshConfigList()
                end
            end
        end
    end)
end

--------------------------------------------------------------
-- Auto-Buy (Vendor) Logic
--------------------------------------------------------------

--- Find a tracked item on the current merchant by name match.
-- Returns merchantIndex, unitPrice, stackSize or nil.
local function FindOnMerchant(itemID)
    local trackedData = LunaUITweaks_WarehousingData.items[itemID]
    if not trackedData or not trackedData.name then return nil end
    local targetName = trackedData.name:lower()
    local numItems = GetMerchantNumItems()
    for i = 1, numItems do
        local info = C_MerchantFrame.GetItemInfo(i)
        if info and info.name and info.name:lower() == targetName then
            return i, info.price, (info.stackCount or 1)
        end
    end
    return nil
end

--- Register the vendor source for a tracked item.
-- Scans the current merchant for an item matching itemID by name and stores the merchantIndex.
-- Called when the player toggles autoBuy on while a merchant is open.
function Warehousing.RegisterVendorItem(itemID)
    if not atMerchant then
        Log("RegisterVendorItem: no merchant open", 2)
        return false
    end
    EnsureDB()
    local item = LunaUITweaks_WarehousingData.items[itemID]
    if not item then return false end

    local mIndex, mPrice, mStackSize = FindOnMerchant(itemID)
    if not mIndex then
        Log("RegisterVendorItem: " .. (item.name or itemID) .. " not found on this vendor", 2)
        return false
    end

    item.autoBuy = true
    item.vendorPrice = mPrice
    item.vendorStackSize = mStackSize
    item.vendorName = UnitName("target") or "Unknown"
    Log("Registered vendor for " .. (item.name or itemID) .. " price=" .. mPrice, 1)
    return true
end

--- Execute auto-buy purchases for all autoBuy items with a deficit.
local function BuildAutoBuyPlan(approved)
    local _, deficit = CalculateOverflowDeficit()
    local bagCounts = ScanBags()
    local spendable = math.max(0, GetMoney() - (UIThingsDB.warehousing.goldReserve or 500) * 10000)
    ReconcilePurchases(bagCounts)
    local purchases, totalCost = {}, 0
    local sorted = {}
    for itemID in pairs(deficit) do sorted[#sorted + 1] = itemID end
    table.sort(sorted)
    for _, itemID in ipairs(sorted) do
        local item = LunaUITweaks_WarehousingData.items[itemID]
        local reservation = pendingPurchases[itemID]
        local pending = 0
        if reservation then
            pending = math.max(0, reservation.expected - (bagCounts[itemID] or 0))
            if pending == 0 then pendingPurchases[itemID] = nil end
        end
        if item and item.autoBuy and (not approved or approved[itemID]) then
            local index, price, bundle = FindOnMerchant(itemID)
            local info = index and C_MerchantFrame.GetItemInfo(index)
            local link = index and GetMerchantItemLink(index)
            local vendorID = link and tonumber(link:match("item:(%d+)"))
            local approval = approved and approved[itemID]
            if vendorID and info and not info.hasExtendedCost and info.isPurchasable ~= false
                and price and price > 0 and bundle and bundle > 0
                and (not approval or (approval.vendorID == vendorID and approval.price == price
                    and approval.bundle == bundle)) then
                local needed = math.max(0, deficit[itemID].count - pending)
                if approval then needed = math.min(needed, approval.quantity) end
                -- Vendor prices are per bundle, but BuyMerchantItem takes item units.
                -- Never round beyond the target merely to complete a vendor bundle.
                local bundles = math.min(math.floor(needed / bundle), math.floor(spendable / price))
                if info.numAvailable and info.numAvailable >= 0 then
                    bundles = math.min(bundles, math.floor(info.numAvailable / bundle))
                end
                if bundles > 0 then
                    local quantity, cost = bundles * bundle, bundles * price
                    purchases[#purchases + 1] = {itemID=itemID, name=item.name, index=index,
                        vendorID=vendorID, quantity=quantity, price=price, bundle=bundle, cost=cost}
                    spendable, totalCost = spendable - cost, totalCost + cost
                end
            end
        end
    end
    return purchases, totalCost
end

local function CanAutoBuy(session)
    return atMerchant and session == merchantSession and MerchantFrame and MerchantFrame:IsShown()
        and UIThingsDB.warehousing.enabled and UIThingsDB.warehousing.autoBuyEnabled
        and not InCombatLockdown()
end

local function RunAutoBuy()
    local session = merchantSession
    if autoBuyAttempted or not CanAutoBuy(session) then return end
    autoBuyAttempted = true
    EnsureDB()
    local purchases, totalCost = BuildAutoBuyPlan()
    if #purchases == 0 then return end
    local approved = {}
    for _, p in ipairs(purchases) do approved[p.itemID] = p end
    local consumed = false
    local function DoPurchases()
        if consumed or not CanAutoBuy(session) then return end
        consumed = true
        -- Recompute stock, enabled items, prices and the gold reserve on acceptance.
        local current = BuildAutoBuyPlan(approved)
        local bags = ScanBags()
        for _, p in ipairs(current) do
            pendingPurchases[p.itemID] = {expected=(bags[p.itemID] or 0) + p.quantity}
            local remaining = p.quantity
            local maxStack = GetMerchantItemMaxStack(p.index) or p.bundle
            local chunkSize = math.floor(maxStack / p.bundle) * p.bundle
            if chunkSize > 0 then
                while remaining > 0 do
                    local quantity = math.min(remaining, chunkSize)
                    BuyMerchantItem(p.index, quantity)
                    remaining = remaining - quantity
                end
                Log("AutoBuy: requested " .. p.quantity .. "x " .. (p.name or p.itemID)
                    .. " for " .. GetCoinTextureString(p.cost), 1)
            else
                pendingPurchases[p.itemID] = nil
            end
        end
        C_Timer.After(0.5, ScheduleBagScan)
    end

    if totalCost > (UIThingsDB.warehousing.confirmAbove or 100) * 10000 then
        StaticPopupDialogs["LUNA_WAREHOUSING_AUTOBUY_CONFIRM"].OnAccept = DoPurchases
        StaticPopup_Show("LUNA_WAREHOUSING_AUTOBUY_CONFIRM",
            "Auto-buy " .. #purchases .. " item type(s) for up to " .. GetCoinTextureString(totalCost) .. "?")
    else
        DoPurchases()
    end
end

--- Check if current merchant sells any tracked autoBuy items (used for button state).
function Warehousing.MerchantHasAutoBuyItems()
    if not atMerchant then return false end
    EnsureDB()
    for itemID, item in pairs(LunaUITweaks_WarehousingData.items) do
        if item.autoBuy and FindOnMerchant(itemID) then
            return true
        end
    end
    return false
end

function Warehousing.IsAtMerchant()
    return atMerchant
end

--------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------

local function OnBagUpdate()
    ScheduleBagScan()
end

local function OnMailShow()
    if not UIThingsDB.warehousing.enabled then return end
    atMailbox = true
    CreatePopupFrame()
    popupMode = "mail"
    popupFrame.actionBtn:SetScript("OnClick", function()
        StartMailSending()
    end)

    -- Refresh content first, then only show if there are items to mail to other characters
    local hasMailItems = Warehousing.RefreshPopup()
    if hasMailItems then
        popupFrame:Show()
    end
end

local function OnMailClosed()
    atMailbox = false
    mailSending = false
    mailQueueIndex = 0
    mailQueue = {}
    if popupFrame then popupFrame:Hide() end
    popupMode = nil
end

local function OnMailSendSuccess()
    if mailSending then
        ProcessNextMail()
    end
end

local function OnMailFailed()
    if not mailSending then return end
    Log("Mail failed to send! Aborting queue.", 3)
    StopQueueProcessor()
    mailSending = false
    mailQueueIndex = 0
    mailQueue = {}
    if popupFrame and popupFrame.actionBtn then
        popupFrame.actionBtn:SetText("Mail")
        popupFrame.actionBtn:Enable()
    end
    if popupFrame and popupFrame.statusText then
        popupFrame.statusText:SetText("|cFFFF4444Mail send failed.|r")
    end
end

-- Re-check warbandAllowed for all tracked items using C_Bank (reliable when bank is open).
local function RecheckWarbandFlags()
    EnsureDB()
    if not (C_Bank and C_Bank.IsItemAllowedInBankType and ItemLocation) then return end
    for itemID, itemData in pairs(LunaUITweaks_WarehousingData.items) do
        for _, bag in ipairs(BAG_LIST) do
            local numSlots = C_Container.GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID == itemID then
                    local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
                    local ok, result = pcall(C_Bank.IsItemAllowedInBankType, Enum.BankType.Account, loc)
                    if ok and result and not itemData.warbandAllowed then
                        itemData.warbandAllowed = true
                        if itemData.destination == "Personal Bank" then
                            itemData.destination = "Warband Bank"
                        end
                        Log("Updated " .. (itemData.name or itemID) .. " to warband-allowed.", 0)
                    end
                    break
                end
            end
        end
    end
end

local function OnBankShow()
    if not UIThingsDB.warehousing.enabled then return end
    atBank = true
    ScanOpenBank() -- discover material quality variants before calculating targets
    RecheckWarbandFlags()
    CreatePopupFrame()
    popupMode = "bank"
    popupFrame.actionBtn:SetScript("OnClick", function()
        StartBankSync()
    end)
    Warehousing.RefreshPopup()
    popupFrame:Show()
end

local function OnBankClosed()
    atBank = false
    atWarbandBank = false
    bankSyncing = false
    if popupFrame then popupFrame:Hide() end
    popupMode = nil
end

local function OnInteractionShow(event, interactionType)
    -- Type 8 = BankFrame (includes warband bank)
    if interactionType == 8 then
        atWarbandBank = true
        OnBankShow()
    end
end

local function OnInteractionHide(event, interactionType)
    if interactionType == 8 then
        -- Bank closed
        OnBankClosed()
    elseif interactionType == 17 then
        -- Mailbox closed (walk-away; MAIL_CLOSED also covers UI close)
        OnMailClosed()
    end
end

local function OnMerchantShow()
    if not UIThingsDB.warehousing.enabled then return end
    if atMerchant then return end
    atMerchant = true
    merchantSession = merchantSession + 1
    autoBuyAttempted = false
    local session = merchantSession
    -- Small delay to allow merchant inventory to fully load
    C_Timer.After(0.3, function() if CanAutoBuy(session) then RunAutoBuy() end end)
end

local function OnMerchantClosed()
    atMerchant = false
    merchantSession = merchantSession + 1
    StaticPopup_Hide("LUNA_WAREHOUSING_AUTOBUY_CONFIRM")
end

--------------------------------------------------------------
-- Module Lifecycle
--------------------------------------------------------------

local function RegisterEvents()
    if eventsRegistered then return end
    eventsRegistered = true
    EventBus.Register("BAG_UPDATE", OnBagUpdate, "Warehousing")
    EventBus.Register("MAIL_SHOW", OnMailShow, "Warehousing")
    EventBus.Register("MAIL_CLOSED", OnMailClosed, "Warehousing")
    EventBus.Register("MAIL_SEND_SUCCESS", OnMailSendSuccess, "Warehousing")
    EventBus.Register("MAIL_FAILED", OnMailFailed, "Warehousing")
    EventBus.Register("BANKFRAME_OPENED", OnBankShow, "Warehousing")
    EventBus.Register("BANKFRAME_CLOSED", OnBankClosed, "Warehousing")
    EventBus.Register("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", OnInteractionShow, "Warehousing")
    EventBus.Register("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", OnInteractionHide, "Warehousing")
    EventBus.Register("MERCHANT_SHOW", OnMerchantShow, "Warehousing")
    EventBus.Register("MERCHANT_CLOSED", OnMerchantClosed, "Warehousing")
end

local function UnregisterEvents()
    if not eventsRegistered then return end
    eventsRegistered = false
    EventBus.Unregister("BAG_UPDATE", OnBagUpdate)
    EventBus.Unregister("MAIL_SHOW", OnMailShow)
    EventBus.Unregister("MAIL_CLOSED", OnMailClosed)
    EventBus.Unregister("MAIL_SEND_SUCCESS", OnMailSendSuccess)
    EventBus.Unregister("MAIL_FAILED", OnMailFailed)
    EventBus.Unregister("BANKFRAME_OPENED", OnBankShow)
    EventBus.Unregister("BANKFRAME_CLOSED", OnBankClosed)
    EventBus.Unregister("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", OnInteractionShow)
    EventBus.Unregister("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", OnInteractionHide)
    EventBus.Unregister("MERCHANT_SHOW", OnMerchantShow)
    EventBus.Unregister("MERCHANT_CLOSED", OnMerchantClosed)
end

function Warehousing.UpdateSettings()
    if UIThingsDB.warehousing.enabled then
        EnsureDB()
        RegisterEvents()
        ScheduleBagScan()
    else
        UnregisterEvents()
        OnMerchantClosed()
        if popupFrame then popupFrame:Hide() end
    end

    -- Update popup frame appearance if it exists
    if popupFrame then
        Helpers.ApplyFrameBackdrop(popupFrame, true, UIThingsDB.warehousing.frameBorderColor,
            true, UIThingsDB.warehousing.frameBgColor)
        local pos = UIThingsDB.warehousing.framePos
        popupFrame:ClearAllPoints()
        popupFrame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x, pos.y)
    end
end

-- Initialize on login
EventBus.Register("PLAYER_LOGIN", function()
    EnsureDB()
    -- Register current character locally
    local key = GetCharacterKey()
    LunaUITweaks_WarehousingData.characters[key] = LunaUITweaks_WarehousingData.characters[key] or {}
    LunaUITweaks_WarehousingData.characters[key].lastSeen = time()

    -- Register in central character registry
    if addonTable.Core and addonTable.Core.CharacterRegistry then
        local _, classFile = UnitClass("player")
        addonTable.Core.CharacterRegistry.Register(key, classFile, "warehousing")
    end

    if UIThingsDB.warehousing.enabled then
        Warehousing.UpdateSettings()
    end
end)
