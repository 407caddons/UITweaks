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

-- State
local scanTimer = nil
local characterKey = nil
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
-- (drag-and-drop is set up via SetupDropTarget from WarehousingPanel.lua)

-- Centralized Logging
local Log = function(msg, level)
    if addonTable.Core and addonTable.Core.Log then
        addonTable.Core.Log("Warehousing", msg, level)
    end
end

local function GetCharacterKey()
    if not characterKey then
        local name = UnitName("player")
        local realm = GetRealmName()
        characterKey = name .. " - " .. realm
    end
    return characterKey
end

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

    local bagList = {}
    for bag = 0, NUM_BAG_SLOTS do bagList[#bagList + 1] = bag end
    bagList[#bagList + 1] = REAGENT_BAG_SLOT

    for _, bag in ipairs(bagList) do
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

        if bagCount > minKeep then
            overflow[itemID] = { count = bagCount - minKeep, destination = dest }
        elseif bagCount < minKeep then
            deficit[itemID] = { count = minKeep - bagCount }
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
    local bagList = {}
    for bag = 0, NUM_BAG_SLOTS do bagList[#bagList + 1] = bag end
    bagList[#bagList + 1] = REAGENT_BAG_SLOT
    for _, bag in ipairs(bagList) do
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
    local bagList = {}
    for bag = 0, NUM_BAG_SLOTS do bagList[#bagList + 1] = bag end
    bagList[#bagList + 1] = REAGENT_BAG_SLOT
    for _, bag in ipairs(bagList) do
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

--- Refresh the popup content
function Warehousing.RefreshPopup()
    if not popupFrame then return end

    EnsureDB()
    local overflow, deficit = CalculateOverflowDeficit()

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
        local hasWithdraw = false
        for itemID, data in pairs(deficit) do
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
        end

        if not hasAnyAction then
            popupFrame.statusText:SetText("Everything is in order.")
            popupFrame.actionBtn:Disable()
        else
            popupFrame.statusText:SetText("")
            popupFrame.actionBtn:Enable()
        end
    end

    popupFrame.scrollChild:SetHeight(math.max(yOffset, 1))
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
        -- Strip " (you)" suffix that may have been stored when this character was active
        local destPlain = dest:match("^(.+) %(you%)$") or dest
        if dest ~= "Warband Bank" and dest ~= "Personal Bank"
            and destPlain:lower() ~= currentName:lower() then
            byDest[dest] = byDest[dest] or {}
            byDest[dest][itemID] = data.count
        end
    end

    for dest, items in pairs(byDest) do
        -- Strip the " (you)" suffix added to the current character's display name
        local recipientName = dest:match("^(.+) %(you%)$") or dest

        -- Build slot list for all items going to this destination
        local allSlots = {}
        for itemID, count in pairs(items) do
            local slots = FindItemSlots(itemID, count)
            for _, s in ipairs(slots) do
                table.insert(allSlots, s)
            end
        end

        -- Chunk into batches of MAX_ATTACHMENTS
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
        -- Done
        mailSending = false
        mailQueueIndex = 0
        if popupFrame and popupFrame.actionBtn then
            popupFrame.actionBtn:SetText("Mail")
            popupFrame.actionBtn:Enable()
        end
        if popupFrame and popupFrame.statusText then
            popupFrame.statusText:SetText("All mail sent!")
        end
        Log("Mail queue complete.", 1)
        -- Refresh after a brief delay to let bag update
        C_Timer.After(0.5, function()
            ScheduleBagScan()
        end)
        return
    end

    local entry = mailQueue[mailQueueIndex]
    if popupFrame and popupFrame.actionBtn then
        popupFrame.actionBtn:SetText("Sending " .. mailQueueIndex .. "/" .. #mailQueue)
        popupFrame.actionBtn:Disable()
    end

    -- Clear mail UI
    ClearSendMail()

    -- Set recipient
    SendMailNameEditBox:SetText(entry.charName)
    SendMailSubjectEditBox:SetText("Warehousing")

    -- Attach items with small delays between each
    local attachIndex = 0
    local function AttachNext()
        attachIndex = attachIndex + 1
        if attachIndex > #entry.slots then
            -- All attached, send
            C_Timer.After(MAIL_STEP_DELAY, function()
                SendMail(entry.charName, "Warehousing", "")
                -- Will wait for MAIL_SEND_SUCCESS to process next
            end)
            return
        end

        local slotInfo = entry.slots[attachIndex]
        ClearCursor()
        C_Container.PickupContainerItem(slotInfo.bag, slotInfo.slot)
        ClickSendMailItemButton(attachIndex)

        C_Timer.After(MAIL_STEP_DELAY, AttachNext)
    end

    C_Timer.After(MAIL_STEP_DELAY, AttachNext)
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


--- Wait for an item to finish transferring (unlock), then call callback
--- Polls up to maxAttempts times with pollInterval delay
local function WaitForItemUnlock(bag, slot, callback, maxAttempts, attempt)
    attempt = attempt or 1
    maxAttempts = maxAttempts or 10
    local info = C_Container.GetContainerItemInfo(bag, slot)
    -- Item gone (moved successfully) or unlocked — proceed
    if not info or not info.isLocked then
        callback(not info) -- true if item moved, false if still there but unlocked
        return
    end
    -- Still locked — wait and retry
    if attempt >= maxAttempts then
        Log("  unlock timeout after " .. attempt .. " attempts", 2)
        callback(false)
        return
    end
    C_Timer.After(0.1, function()
        WaitForItemUnlock(bag, slot, callback, maxAttempts, attempt + 1)
    end)
end

local function StartBankSync(continuationPass)
    if bankSyncing then return end
    continuationPass = continuationPass or 1
    bankSyncing = true

    -- Use C_Bank.CanViewBank to check actual bank accessibility
    local canViewCharacter = C_Bank and C_Bank.CanViewBank and C_Bank.CanViewBank(Enum.BankType.Character)
    local canViewAccount = C_Bank and C_Bank.CanViewBank and C_Bank.CanViewBank(Enum.BankType.Account)
    Log("=== SYNC START === canViewCharacter=" .. tostring(canViewCharacter) .. " canViewAccount=" .. tostring(canViewAccount), 1)

    local overflow, deficit = CalculateOverflowDeficit()

    if popupFrame and popupFrame.actionBtn then
        popupFrame.actionBtn:SetText("Syncing...")
        popupFrame.actionBtn:Disable()
    end

    -- Build work list: deposits first, then withdrawals
    local work = {}

    -- Deposits: overflow items destined for a bank type
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
                table.insert(work, {
                    action = "deposit",
                    bag = s.bag,
                    slot = s.slot,
                    count = s.count,
                    bankType = bankType,
                })
            end
        end
    end

    -- Withdrawals: deficit items available in any open bank
    local bankCounts = ScanOpenBank()
    for itemID, data in pairs(deficit) do
        local bankHas = bankCounts[itemID] or 0
        if bankHas > 0 then
            local withdrawCount = math.min(data.count, bankHas)
            local bankSlots = FindOpenBankSlots(itemID, withdrawCount)
            for _, s in ipairs(bankSlots) do
                table.insert(work, {
                    action = "withdraw",
                    bag = s.bag,
                    slot = s.slot,
                    count = s.count,
                })
            end
        end
    end

    Log("Total work items: " .. #work, 1)

    if #work == 0 then
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

    local workIndex = 0
    local workRetries = 0
    local MAX_WORK_RETRIES = 3
    local function ProcessNextWork(retry)
        if retry then
            workRetries = workRetries + 1
            if workRetries > MAX_WORK_RETRIES then
                Log("  giving up on item after " .. MAX_WORK_RETRIES .. " retries, skipping", 2)
                workRetries = 0
                workIndex = workIndex + 1
            end
        else
            workRetries = 0
            workIndex = workIndex + 1
        end
        if workIndex > #work then
            bankSyncing = false
            Log("Bank sync complete (pass " .. continuationPass .. ").", 1)
            -- After a short delay, re-scan bags and check if splits left behind
            -- additional overflow that needs a follow-up pass (max 5 passes total).
            C_Timer.After(0.5, function()
                ScheduleBagScan()
                if continuationPass < 5 then
                    C_Timer.After(SCAN_DELAY + 0.1, function()
                        local followOverflow, followDeficit = CalculateOverflowDeficit()
                        local hasMore = false
                        local canViewCharacter = C_Bank and C_Bank.CanViewBank and C_Bank.CanViewBank(Enum.BankType.Character)
                        local canViewAccount = C_Bank and C_Bank.CanViewBank and C_Bank.CanViewBank(Enum.BankType.Account)
                        for _, data in pairs(followOverflow) do
                            local dest = data.destination
                            if (dest == "Warband Bank" and canViewAccount)
                                or (dest == "Personal Bank" and canViewCharacter) then
                                hasMore = true
                                break
                            end
                        end
                        if hasMore then
                            Log("Overflow remains after pass " .. continuationPass .. ", running follow-up sync.", 1)
                            if popupFrame and popupFrame.statusText then
                                popupFrame.statusText:SetText("Following up...")
                            end
                            StartBankSync(continuationPass + 1)
                        else
                            if popupFrame and popupFrame.actionBtn then
                                popupFrame.actionBtn:SetText("Sync")
                                popupFrame.actionBtn:Enable()
                            end
                            if popupFrame and popupFrame.statusText then
                                popupFrame.statusText:SetText("Sync complete!")
                            end
                            Warehousing.RefreshPopup()
                        end
                    end)
                else
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
            return
        end

        local item = work[workIndex]
        Log("Processing " .. workIndex .. "/" .. #work .. ": " .. item.action .. " bag=" .. item.bag .. " slot=" .. item.slot .. " count=" .. item.count, 1)

        if popupFrame and popupFrame.statusText then
            popupFrame.statusText:SetText("Syncing " .. workIndex .. "/" .. #work .. "...")
        end

        ClearCursor()

        if item.action == "deposit" then
            local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
            if not info then
                C_Timer.After(0.05, ProcessNextWork)
                return
            end

            if info.stackCount > item.count then
                -- Split: put overflow on cursor, place into empty bag slot, then deposit that
                C_Container.SplitContainerItem(item.bag, item.slot, item.count)
                C_Timer.After(MAIL_STEP_DELAY, function()
                    local emptyBag, emptySlot = FindEmptyBagSlot()
                    if emptyBag then
                        C_Container.PickupContainerItem(emptyBag, emptySlot)
                        C_Timer.After(MAIL_STEP_DELAY, function()
                            C_Container.UseContainerItem(emptyBag, emptySlot, nil, item.bankType)
                            -- Wait for the transfer to complete (item unlocks or disappears).
                            -- Use 20 attempts (2s total) for slow warband bank responses.
                            WaitForItemUnlock(emptyBag, emptySlot, function(moved)
                                Log("  split deposit " .. (moved and "OK" or "stayed"), moved and 1 or 2)
                                ClearCursor()
                                if not moved then
                                    C_Timer.After(0.5, function() ProcessNextWork(true) end)
                                else
                                    C_Timer.After(0.05, ProcessNextWork)
                                end
                            end, 20)
                        end)
                    else
                        ClearCursor()
                        C_Timer.After(0.05, ProcessNextWork)
                    end
                end)
                return
            else
                -- Full stack: UseContainerItem with bankType
                C_Container.UseContainerItem(item.bag, item.slot, nil, item.bankType)
                -- Wait for the item to unlock/disappear before processing next.
                -- Use 20 attempts (2s total) — warband bank API can be slow to respond.
                WaitForItemUnlock(item.bag, item.slot, function(moved)
                    Log("  deposit " .. (moved and "OK" or "stayed"), moved and 1 or 2)
                    ClearCursor()
                    if not moved then
                        -- Item didn't move — the bank transfer may be delayed server-side.
                        -- Wait longer then retry the same work item.
                        C_Timer.After(0.5, function() ProcessNextWork(true) end)
                    else
                        C_Timer.After(0.05, ProcessNextWork)
                    end
                end, 20)
                return
            end

        elseif item.action == "withdraw" then
            local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
            if not info then
                C_Timer.After(0.05, ProcessNextWork)
                return
            end

            if info.stackCount > item.count then
                -- Split partial amount from bank slot
                C_Container.SplitContainerItem(item.bag, item.slot, item.count)
                C_Timer.After(MAIL_STEP_DELAY, function()
                    local emptyBag, emptySlot = FindEmptyBagSlot()
                    if emptyBag then
                        C_Container.PickupContainerItem(emptyBag, emptySlot)
                    end
                    ClearCursor()
                    C_Timer.After(MAIL_STEP_DELAY, ProcessNextWork)
                end)
                return
            else
                -- Full stack withdraw
                C_Container.UseContainerItem(item.bag, item.slot)
                WaitForItemUnlock(item.bag, item.slot, function(moved)
                    Log("  withdraw " .. (moved and "OK" or "stayed"), moved and 1 or 2)
                    ClearCursor()
                    C_Timer.After(0.05, ProcessNextWork)
                end)
                return
            end
        end

        ClearCursor()
        C_Timer.After(0.05, ProcessNextWork)
    end

    ProcessNextWork()
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
    -- bindType == 1 is Soulbound; however Warbound items may also return bindType == 1
    -- via GetItemInfo (Blizzard's Enum.ItemBind.Warbound is not reliably returned yet).
    -- Instead, find the item in bags and ask C_Bank directly.
    local warbandAllowed = false
    if C_Bank and C_Bank.IsItemAllowedInBankType and ItemLocation then
        local bagList = {}
        for bag = 0, NUM_BAG_SLOTS do bagList[#bagList + 1] = bag end
        bagList[#bagList + 1] = REAGENT_BAG_SLOT
        for _, bag in ipairs(bagList) do
            local numSlots = C_Container.GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID == itemID then
                    local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
                    local ok, result = pcall(C_Bank.IsItemAllowedInBankType, Enum.BankType.Account, loc)
                    if ok and result then
                        warbandAllowed = true
                    end
                    break
                end
            end
            if warbandAllowed then break end
        end
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

    Log("Added item: " .. tostring(name) .. " (ID: " .. tostring(itemID) .. ") warbandAllowed=" .. tostring(warbandAllowed), 1)
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
local function RunAutoBuy()
    if not UIThingsDB.warehousing.enabled then return end
    if not UIThingsDB.warehousing.autoBuyEnabled then return end
    if InCombatLockdown() then return end
    EnsureDB()

    local _, deficit = CalculateOverflowDeficit()
    local goldReserve = (UIThingsDB.warehousing.goldReserve or 500) * 10000  -- convert to copper
    local confirmAbove = (UIThingsDB.warehousing.confirmAbove or 100) * 10000
    local currentMoney = GetMoney()
    local spendable = math.max(0, currentMoney - goldReserve)

    if spendable <= 0 then
        Log("AutoBuy: not enough gold (reserve=" .. (UIThingsDB.warehousing.goldReserve or 500) .. "g)", 1)
        return
    end

    -- Cache warband bank counts (by itemID) for deficit reduction
    local warbandCounts = (LunaUITweaks_ReagentData and LunaUITweaks_ReagentData.warband
        and LunaUITweaks_ReagentData.warband.items) or {}

    -- Build purchase list
    local purchases = {}
    local totalCost = 0
    for itemID, data in pairs(deficit) do
        local item = LunaUITweaks_WarehousingData.items[itemID]
        if item and item.autoBuy then
            local mIndex, mPrice, mStackSize = FindOnMerchant(itemID)
            if mIndex and mPrice and mPrice > 0 then
                -- Subtract warband bank stock: check by exact ID, then by name for quality variants
                local warbandHas = warbandCounts[itemID] or 0
                if warbandHas == 0 and item.name then
                    local targetName = item.name:lower()
                    for wbID, wbCount in pairs(warbandCounts) do
                        local wbName = C_Item.GetItemNameByID(wbID)
                        if wbName and wbName:lower() == targetName then
                            warbandHas = warbandHas + wbCount
                        end
                    end
                end
                local needed = math.max(0, data.count - warbandHas)
                if needed > 0 then
                    -- Round up to full stacks
                    local stacks = math.ceil(needed / mStackSize)
                    local totalItems = stacks * mStackSize
                    local cost = stacks * mPrice
                    if cost <= spendable then
                        table.insert(purchases, {
                            itemID = itemID,
                            name = item.name,
                            mIndex = mIndex,
                            stacks = stacks,
                            totalItems = totalItems,
                            cost = cost,
                        })
                        totalCost = totalCost + cost
                        spendable = spendable - cost
                    else
                        -- Buy as many stacks as we can afford
                        local affordableStacks = math.floor(spendable / mPrice)
                        if affordableStacks > 0 then
                            local cost2 = affordableStacks * mPrice
                            table.insert(purchases, {
                                itemID = itemID,
                                name = item.name,
                                mIndex = mIndex,
                                stacks = affordableStacks,
                                totalItems = affordableStacks * mStackSize,
                                cost = cost2,
                            })
                            totalCost = totalCost + cost2
                            spendable = spendable - cost2
                        end
                    end
                end
            end
        end
    end

    if #purchases == 0 then return end

    local function DoPurchases()
        for _, p in ipairs(purchases) do
            BuyMerchantItem(p.mIndex, p.stacks)
            Log("AutoBuy: bought " .. p.stacks .. "x stack(s) of " .. (p.name or p.itemID)
                .. " for " .. GetCoinTextureString(p.cost), 1)
        end
        -- Rescan bags after purchase
        C_Timer.After(0.5, ScheduleBagScan)
    end

    -- Confirm if total cost exceeds threshold
    if totalCost > confirmAbove then
        local gold = math.floor(totalCost / 10000)
        local silver = math.floor((totalCost % 10000) / 100)
        local copper = totalCost % 100
        local costStr = gold > 0 and (gold .. "g " .. silver .. "s") or (silver .. "s " .. copper .. "c")
        local confirmMsg = "Auto-buy " .. #purchases .. " item type(s) from vendor for " .. costStr .. "?"
        StaticPopupDialogs["LUNA_WAREHOUSING_AUTOBUY_CONFIRM"].OnAccept = DoPurchases
        StaticPopup_Show("LUNA_WAREHOUSING_AUTOBUY_CONFIRM", confirmMsg)
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
    Warehousing.RefreshPopup()
    local overflow = CalculateOverflowDeficit()
    local currentKey = GetCharacterKey()
    local currentName = currentKey:match("^(.+) %- ") or ""
    local hasMailItems = false
    for _, data in pairs(overflow) do
        local dest = data.destination
        -- Strip " (you)" suffix that may have been stored when this character was active
        local destPlain = dest:match("^(.+) %(you%)$") or dest
        if dest ~= "Warband Bank" and dest ~= "Personal Bank"
            and destPlain:lower() ~= currentName:lower() then
            hasMailItems = true
            break
        end
    end
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

local function OnBankShow()
    if not UIThingsDB.warehousing.enabled then return end
    atBank = true
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
    atMerchant = true
    -- Small delay to allow merchant inventory to fully load
    C_Timer.After(0.3, RunAutoBuy)
end

local function OnMerchantClosed()
    atMerchant = false
end

--------------------------------------------------------------
-- Module Lifecycle
--------------------------------------------------------------

local function RegisterEvents()
    if eventsRegistered then return end
    eventsRegistered = true
    EventBus.Register("BAG_UPDATE", OnBagUpdate)
    EventBus.Register("MAIL_SHOW", OnMailShow)
    EventBus.Register("MAIL_CLOSED", OnMailClosed)
    EventBus.Register("MAIL_SEND_SUCCESS", OnMailSendSuccess)
    EventBus.Register("BANKFRAME_OPENED", OnBankShow)
    EventBus.Register("BANKFRAME_CLOSED", OnBankClosed)
    EventBus.Register("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", OnInteractionShow)
    EventBus.Register("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", OnInteractionHide)
    EventBus.Register("MERCHANT_SHOW", OnMerchantShow)
    EventBus.Register("MERCHANT_CLOSED", OnMerchantClosed)
end

local function UnregisterEvents()
    if not eventsRegistered then return end
    eventsRegistered = false
    EventBus.Unregister("BAG_UPDATE", OnBagUpdate)
    EventBus.Unregister("MAIL_SHOW", OnMailShow)
    EventBus.Unregister("MAIL_CLOSED", OnMailClosed)
    EventBus.Unregister("MAIL_SEND_SUCCESS", OnMailSendSuccess)
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
