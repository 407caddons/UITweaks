local addonName, addonTable = ...
local LootChecklist = {}
addonTable.LootChecklist = LootChecklist

local EventBus = addonTable.EventBus
local Log      = addonTable.Core.Log
local LogLevel = addonTable.Core.LogLevel

-- ============================================================
-- Constants
-- ============================================================
local DUNGEON_DIFFS = {
    { id = 1,  label = "Normal"      },
    { id = 2,  label = "Heroic"      },
    { id = 8,  label = "Mythic"      },
    { id = 24, label = "Timewalking" },
}
local RAID_DIFFS = {
    { id = 17, label = "LFR"    },
    { id = 14, label = "Normal" },
    { id = 15, label = "Heroic" },
    { id = 16, label = "Mythic" },
}
local ROW_H = 22

-- ============================================================
-- Module state
-- ============================================================
local db               -- UIThingsDB.lootChecklist shortcut
local checklistFrame
local checklistScrollChild
local checklistRows    = {}
local checklistRowPool = {}

-- Browser state (not persisted)
local browserFrame
local bTierIdx      = nil
local bInstanceType = 1      -- 1=dungeon, 2=raid
local bInstanceID   = nil
local bDifficultyID = nil
local bEncounterID  = nil    -- nil = all bosses
local bItems        = {}     -- fetched EJ loot entries

-- Browser UI references
local tierDD, instanceDD, diffDD, encounterDD
local dungeonBtn, raidBtn
local ejScrollChild, bcScrollChild
local ejRows    = {}
local ejRowPool = {}
local bcRows    = {}
local bcRowPool = {}

-- Shared active popup reference (so only one dropdown is open at once)
local activeDropdown = nil

-- ============================================================
-- EJ helpers
-- ============================================================
local function EnsureEJLoaded()
    if not EJ_GetInstanceByIndex then
        C_AddOns.LoadAddOn("Blizzard_EncounterJournal")
    end
    return EJ_GetInstanceByIndex ~= nil
end

local function GetInstanceIDFromLink(link)
    if not link then return nil end
    return tonumber(link:match("|Hjournal:%d+:(%d+):"))
end

local function FetchInstances(tierIndex, instanceType)
    local list = {}
    if not EnsureEJLoaded() then return list end
    pcall(EJ_SelectTier, tierIndex)
    local isRaid = (instanceType == 2)
    local idx = 1
    while true do
        local journalInstID, name, _, _, _, _, _, _, _, _, instID = EJ_GetInstanceByIndex(idx, isRaid)
        if not journalInstID then break end
        if name and instID then
            table.insert(list, { name = name, instanceID = instID })
        end
        idx = idx + 1
    end
    return list
end

local function FetchEncounters(instanceID)
    local list = {}
    if not instanceID then return list end
    if not EnsureEJLoaded() then return list end
    local ok = pcall(EJ_SelectInstance, instanceID)
    if not ok then return list end
    local count = EJ_GetNumEncounters()
    for i = 1, count do
        local encID, name = EJ_GetEncounterInfo(i)
        if encID and name then
            table.insert(list, { encounterID = encID, name = name })
        end
    end
    return list
end

local function FetchLoot(instanceID, difficultyID, encounterID)
    local items = {}
    if not instanceID then return items end
    if not EnsureEJLoaded() then return items end

    pcall(EJ_SelectInstance, instanceID)
    if difficultyID then pcall(EJ_SetDifficulty, difficultyID) end

    local localClass = UnitClass("player") or ""
    local seen = {}

    local function fetchEnc(encID)
        if not pcall(EJ_SelectEncounter, encID) then return end
        local idx = 1
        while true do
            local info = C_EncounterJournal.GetLootInfoByIndex(idx)
            if not info or not info.itemID then break end
            if not seen[info.itemID] then
                seen[info.itemID] = true
                local pass = true
                if info.classNames and info.classNames ~= "" then
                    pass = info.classNames:lower():find(localClass:lower(), 1, true) ~= nil
                end
                if pass then
                    table.insert(items, {
                        itemID   = info.itemID,
                        name     = info.name or ("Item " .. info.itemID),
                        slot     = info.slot or "",
                        itemLink = info.itemLink,
                        texture  = info.texture,
                    })
                end
            end
            idx = idx + 1
        end
    end

    if encounterID then
        fetchEnc(encounterID)
    else
        local count = EJ_GetNumEncounters()
        for i = 1, count do
            local encID = EJ_GetEncounterInfo(i)
            if encID then fetchEnc(encID) end
        end
    end

    table.sort(items, function(a, b)
        if a.slot ~= b.slot then return a.slot < b.slot end
        return (a.name or "") < (b.name or "")
    end)
    return items
end

-- ============================================================
-- Checklist DB management
-- ============================================================
local function IsOnChecklist(itemID)
    for _, e in ipairs(db.checklist) do
        if e.itemID == itemID then return true end
    end
    return false
end

local function AddToChecklist(item)
    if IsOnChecklist(item.itemID) then return end
    table.insert(db.checklist, {
        itemID   = item.itemID,
        name     = item.name,
        slot     = item.slot,
        itemLink = item.itemLink,
        obtained = false,
    })
    LootChecklist.RefreshChecklist()
    if browserFrame and browserFrame:IsShown() then
        LootChecklist.RefreshBrowserChecklist()
    end
end

local function RemoveFromChecklist(itemID)
    for i, e in ipairs(db.checklist) do
        if e.itemID == itemID then
            table.remove(db.checklist, i)
            LootChecklist.RefreshChecklist()
            if browserFrame and browserFrame:IsShown() then
                LootChecklist.RefreshBrowserChecklist()
            end
            return
        end
    end
end

local function MarkObtained(itemID)
    for _, e in ipairs(db.checklist) do
        if e.itemID == itemID and not e.obtained then
            e.obtained = true
            LootChecklist.RefreshChecklist()
            Log("LootChecklist", "Obtained: " .. (e.name or tostring(itemID)), LogLevel.INFO)
            return true
        end
    end
    return false
end

-- ============================================================
-- Loot detection
-- ============================================================
local function CheckItemLinks(text)
    if not text then return end
    for link in text:gmatch("|H(item:[^|]+)|h") do
        local itemID = tonumber(link:match("item:(%d+)"))
        if itemID then MarkObtained(itemID) end
    end
end

local function OnChatMsgLoot(event, msg)
    if not db or not db.enabled then return end
    CheckItemLinks(msg)
end

local function ScanBagsForChecklist()
    if not db or not db.enabled or #db.checklist == 0 then return end
    for bag = 0, 4 do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then MarkObtained(info.itemID) end
        end
    end
end

-- ============================================================
-- On-screen Checklist Frame
-- ============================================================
local function NewChecklistRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    row.checkTex = row:CreateFontString(nil, "OVERLAY")
    row.checkTex:SetPoint("LEFT", 4, 0)
    row.checkTex:SetWidth(14)

    row.label = row:CreateFontString(nil, "OVERLAY")
    row.label:SetPoint("LEFT", 20, 0)
    row.label:SetPoint("RIGHT", -20, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)

    row.removeBtn = CreateFrame("Button", nil, row)
    row.removeBtn:SetSize(14, 14)
    row.removeBtn:SetPoint("RIGHT", -3, 0)
    row.removeBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    row.removeBtn:GetNormalTexture():SetVertexColor(0.7, 0.2, 0.2)
    row.removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
    row.removeBtn:GetHighlightTexture():SetVertexColor(1, 0.4, 0.4)

    row:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

function LootChecklist.RefreshChecklist()
    if not checklistFrame or not checklistScrollChild then return end

    for _, r in ipairs(checklistRows) do
        r:Hide()
        r:SetParent(nil)
        table.insert(checklistRowPool, r)
    end
    wipe(checklistRows)

    local font     = (db and db.font)     or "Fonts\\FRIZQT__.TTF"
    local fontSize = (db and db.fontSize) or 12
    local rh       = fontSize + 8

    for i, entry in ipairs(db.checklist) do
        local row = table.remove(checklistRowPool) or NewChecklistRow(checklistScrollChild)
        row:SetParent(checklistScrollChild)
        row:SetHeight(rh)
        row:SetPoint("TOPLEFT", 0, -((i - 1) * rh))
        row:SetPoint("RIGHT", 0, 0)
        row.itemID   = entry.itemID
        row.itemLink = entry.itemLink

        row.checkTex:SetFont(font, fontSize, "")
        row.label:SetFont(font, fontSize, "")

        if entry.obtained then
            row.checkTex:SetText("|cFF44FF44\226\156\147|r")
            row.label:SetText("|cFF888888" .. (entry.name or "") .. "|r")
        else
            row.checkTex:SetText("|cFFAAAAAA\226\150\161|r")
            row.label:SetText(entry.name or "")
        end
        row:Show()

        local iid = entry.itemID
        row.removeBtn:SetScript("OnClick", function() RemoveFromChecklist(iid) end)
        table.insert(checklistRows, row)
    end

    checklistScrollChild:SetHeight(math.max(1, #db.checklist * rh))

    if db.enabled then
        if #db.checklist == 0 and db.locked then
            checklistFrame:Hide()
        else
            checklistFrame:Show()
        end
    end
end

local function CreateChecklistFrame()
    if checklistFrame then return end

    local f = CreateFrame("Frame", "LunaLootChecklistFrame", UIParent, "BackdropTemplate")
    f:SetSize(db.width or 220, db.height or 280)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    checklistFrame = f

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 6, -6)
    title:SetText("Loot Checklist")
    title:SetTextColor(1, 0.82, 0)

    local clearBtn = CreateFrame("Button", nil, f)
    clearBtn:SetSize(14, 14)
    clearBtn:SetPoint("TOPRIGHT", -3, -3)
    clearBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    clearBtn:GetNormalTexture():SetVertexColor(0.6, 0.3, 0.1)
    clearBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
    clearBtn:GetHighlightTexture():SetVertexColor(1, 0.6, 0.2)
    clearBtn:SetScript("OnClick", function()
        wipe(db.checklist)
        LootChecklist.RefreshChecklist()
        if browserFrame and browserFrame:IsShown() then
            LootChecklist.RefreshBrowserChecklist()
            -- Re-enable all [+] buttons in the EJ list
            for _, r in ipairs(ejRows) do
                r.addBtn:SetEnabled(true)
                r.addBtn:SetText("+")
            end
        end
    end)
    clearBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Clear All Items")
        GameTooltip:Show()
    end)
    clearBtn:SetScript("OnLeave", GameTooltip_Hide)

    local div = f:CreateTexture(nil, "ARTWORK")
    div:SetPoint("TOPLEFT", 2, -22)
    div:SetPoint("TOPRIGHT", -2, -22)
    div:SetHeight(1)
    div:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    local sf = CreateFrame("ScrollFrame", "LunaLootChecklistScroll", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 4, -24)
    sf:SetPoint("BOTTOMRIGHT", -24, 4)

    checklistScrollChild = CreateFrame("Frame", nil, sf)
    checklistScrollChild:SetWidth(sf:GetWidth() or 190)
    checklistScrollChild:SetHeight(1)
    sf:SetScrollChild(checklistScrollChild)

    sf:HookScript("OnSizeChanged", function(self, w) checklistScrollChild:SetWidth(w) end)

    f:SetScript("OnDragStart", function(self)
        if not db.locked then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local cx, cy = self:GetCenter()
        local pcx, pcy = UIParent:GetCenter()
        if cx and pcx then
            db.pos = { point = "CENTER", x = cx - pcx, y = cy - pcy }
        end
    end)

    f:Hide()
end

-- ============================================================
-- Browser: reusable simple dropdown
-- ============================================================
local function CloseActiveDropdown()
    if activeDropdown then
        activeDropdown:Hide()
        activeDropdown = nil
    end
end

local function MakeDropdown(parent, width)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, 22)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    btn:SetBackdropColor(0.1, 0.1, 0.1, 1)
    btn:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)

    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.label:SetPoint("LEFT", 6, 0)
    btn.label:SetPoint("RIGHT", -16, 0)
    btn.label:SetJustifyH("LEFT")
    btn.label:SetTextColor(1, 0.82, 0)

    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", -4, 0)
    arrow:SetText("\226\150\188")
    arrow:SetTextColor(0.7, 0.7, 0.7)

    -- Popup
    local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetWidth(width)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    popup:SetBackdropColor(0.05, 0.05, 0.05, 0.98)
    popup:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
    popup:Hide()
    popup:EnableMouse(true)

    local sf = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 2, -2)
    sf:SetPoint("BOTTOMRIGHT", -18, 2)

    local child = CreateFrame("Frame", nil, sf)
    child:SetWidth(width - 20)
    sf:SetScrollChild(child)

    btn.popup   = popup
    btn.items   = {}
    btn.onSelect = nil

    btn:SetScript("OnClick", function(self)
        if popup:IsShown() then
            popup:Hide()
            activeDropdown = nil
        else
            CloseActiveDropdown()
            popup:ClearAllPoints()
            popup:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
            local maxH = math.min(#btn.items * 20, 200)
            popup:SetHeight(maxH + 4)
            child:SetHeight(#btn.items * 20)
            popup:Show()
            activeDropdown = popup
        end
    end)

    function btn:SetItems(items, onSel)
        self.items    = items
        self.onSelect = onSel
        -- Rebuild rows
        for _, c in ipairs({ child:GetChildren() }) do c:Hide() end
        for i, item in ipairs(items) do
            local row = CreateFrame("Button", nil, child)
            row:SetHeight(20)
            row:SetPoint("TOPLEFT", 0, -((i - 1) * 20))
            row:SetPoint("RIGHT",   0, 0)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("LEFT", 6, 0)
            lbl:SetText(item.label or item.name or tostring(i))
            lbl:SetTextColor(1, 0.82, 0)
            local it = item
            row:SetScript("OnClick", function()
                self.label:SetText(it.label or it.name or "")
                popup:Hide()
                activeDropdown = nil
                if self.onSelect then self.onSelect(it) end
            end)
        end
    end

    function btn:SetValue(text)
        self.label:SetText(text or "")
    end

    function btn:SelectByIndex(idx)
        if self.items[idx] then
            self.label:SetText(self.items[idx].label or self.items[idx].name or "")
            if self.onSelect then self.onSelect(self.items[idx]) end
        end
    end

    return btn
end

-- ============================================================
-- Browser: EJ item rows
-- ============================================================
local function NewEJRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 4, 0)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.label:SetPoint("LEFT", 24, 0)
    row.label:SetPoint("RIGHT", -32, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)

    row.addBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.addBtn:SetSize(28, 18)
    row.addBtn:SetPoint("RIGHT", -3, 0)
    row.addBtn:SetText("+")
    row.addBtn:SetNormalFontObject("GameFontNormalSmall")

    row:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

local function RefreshEJList()
    for _, r in ipairs(ejRows) do
        r:Hide()
        r:SetParent(nil)
        table.insert(ejRowPool, r)
    end
    wipe(ejRows)
    if not ejScrollChild then return end

    for i, item in ipairs(bItems) do
        local row = table.remove(ejRowPool) or NewEJRow(ejScrollChild)
        row:SetParent(ejScrollChild)
        row:SetPoint("TOPLEFT", 0, -((i - 1) * ROW_H))
        row:SetPoint("RIGHT",   0, 0)
        row.itemLink = item.itemLink
        row:Show()

        if item.texture then
            row.icon:SetTexture(item.texture)
            row.icon:Show()
        else
            row.icon:Hide()
        end

        local onList = IsOnChecklist(item.itemID)
        local slotPfx = item.slot ~= "" and ("|cFFAAAAAA" .. item.slot .. ":|r ") or ""
        row.label:SetText(slotPfx .. (item.name or ""))
        row.addBtn:SetEnabled(not onList)
        row.addBtn:SetText(onList and "\226\156\147" or "+")

        local itm = item
        row.addBtn:SetScript("OnClick", function()
            AddToChecklist(itm)
            row.addBtn:SetEnabled(false)
            row.addBtn:SetText("\226\156\147")
        end)
        table.insert(ejRows, row)
    end

    ejScrollChild:SetHeight(math.max(1, #bItems * ROW_H))
end

-- ============================================================
-- Browser: checklist right pane
-- ============================================================
local function NewBCRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.label:SetPoint("LEFT", 4, 0)
    row.label:SetPoint("RIGHT", -22, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)

    row.removeBtn = CreateFrame("Button", nil, row)
    row.removeBtn:SetSize(14, 14)
    row.removeBtn:SetPoint("RIGHT", -3, 0)
    row.removeBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    row.removeBtn:GetNormalTexture():SetVertexColor(0.8, 0.2, 0.2)
    row.removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
    row.removeBtn:GetHighlightTexture():SetVertexColor(1, 0.4, 0.4)

    row:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

function LootChecklist.RefreshBrowserChecklist()
    for _, r in ipairs(bcRows) do
        r:Hide()
        r:SetParent(nil)
        table.insert(bcRowPool, r)
    end
    wipe(bcRows)
    if not bcScrollChild then return end

    for i, entry in ipairs(db.checklist) do
        local row = table.remove(bcRowPool) or NewBCRow(bcScrollChild)
        row:SetParent(bcScrollChild)
        row:SetPoint("TOPLEFT", 0, -((i - 1) * ROW_H))
        row:SetPoint("RIGHT",   0, 0)
        row.itemLink = entry.itemLink
        row:Show()

        if entry.obtained then
            row.label:SetText("|cFF44FF44\226\156\147|r |cFF888888" .. (entry.name or "") .. "|r")
        else
            row.label:SetText("|cFFAAAAAA\226\150\161|r " .. (entry.name or ""))
        end

        local iid = entry.itemID
        row.removeBtn:SetScript("OnClick", function()
            RemoveFromChecklist(iid)
            RefreshEJList()
        end)
        table.insert(bcRows, row)
    end

    bcScrollChild:SetHeight(math.max(1, #db.checklist * ROW_H))
end

-- ============================================================
-- Browser: controls
-- ============================================================
local function ReloadEJItems()
    bItems = FetchLoot(bInstanceID, bDifficultyID, bEncounterID)
    RefreshEJList()
    LootChecklist.RefreshBrowserChecklist()
end

local function OnInstanceSelected(instanceInfo)
    bInstanceID  = instanceInfo.instanceID
    bEncounterID = nil

    local encs = FetchEncounters(bInstanceID)
    local encItems = { { label = "All Bosses", encounterID = nil } }
    for _, e in ipairs(encs) do
        table.insert(encItems, { label = e.name, encounterID = e.encounterID })
    end
    encounterDD:SetItems(encItems, function(item)
        bEncounterID = item.encounterID
        ReloadEJItems()
    end)
    encounterDD:SetValue("All Bosses")
    ReloadEJItems()
end

local function SetInstanceType(itype)
    bInstanceType = itype
    bInstanceID   = nil
    bEncounterID  = nil
    bItems        = {}
    RefreshEJList()
    LootChecklist.RefreshBrowserChecklist()

    if dungeonBtn and raidBtn then
        if itype == 1 then
            dungeonBtn:SetBackdropColor(0.28, 0.25, 0.05, 1)
            raidBtn:SetBackdropColor(0.1, 0.1, 0.1, 1)
        else
            dungeonBtn:SetBackdropColor(0.1, 0.1, 0.1, 1)
            raidBtn:SetBackdropColor(0.28, 0.25, 0.05, 1)
        end
    end

    local diffs = itype == 1 and DUNGEON_DIFFS or RAID_DIFFS
    bDifficultyID = diffs[1].id
    diffDD:SetItems(diffs, function(item)
        bDifficultyID = item.id
        if bInstanceID then ReloadEJItems() end
    end)
    diffDD:SetValue(diffs[1].label)

    if bTierIdx then
        local instances = FetchInstances(bTierIdx, itype)
        instanceDD:SetItems(instances, OnInstanceSelected)
        instanceDD:SetValue("Select Instance...")
    end

    -- Reset encounter dropdown
    encounterDD:SetItems({ { label = "All Bosses", encounterID = nil } }, function(item)
        bEncounterID = item.encounterID
        if bInstanceID then ReloadEJItems() end
    end)
    encounterDD:SetValue("All Bosses")
end

-- ============================================================
-- Browser frame creation
-- ============================================================
local function CreateBrowserFrame()
    if browserFrame then return end

    local f = CreateFrame("Frame", "LunaLootBrowserFrame", UIParent, "BackdropTemplate")
    f:SetSize(660, 540)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.08, 0.08, 0.08, 0.97)
    f:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
    f:EnableMouse(true)
    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
            CloseActiveDropdown()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    browserFrame = f

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Loot Checklist Browser")
    title:SetTextColor(1, 0.82, 0)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        f:Hide()
        CloseActiveDropdown()
    end)

    -- ---- Row 1: Type + Expansion ----
    local y = -36

    local typeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    typeLabel:SetPoint("TOPLEFT", 12, y)
    typeLabel:SetText("Type:")

    dungeonBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    dungeonBtn:SetSize(82, 22)
    dungeonBtn:SetPoint("LEFT", typeLabel, "RIGHT", 6, 0)
    dungeonBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1, insets = { left=1,right=1,top=1,bottom=1 } })
    dungeonBtn:SetBackdropColor(0.28, 0.25, 0.05, 1)
    dungeonBtn:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
    local dlbl = dungeonBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dlbl:SetAllPoints(); dlbl:SetText("Dungeons"); dlbl:SetTextColor(1, 0.82, 0)

    raidBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    raidBtn:SetSize(60, 22)
    raidBtn:SetPoint("LEFT", dungeonBtn, "RIGHT", 4, 0)
    raidBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1, insets = { left=1,right=1,top=1,bottom=1 } })
    raidBtn:SetBackdropColor(0.1, 0.1, 0.1, 1)
    raidBtn:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
    local rlbl = raidBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rlbl:SetAllPoints(); rlbl:SetText("Raids"); rlbl:SetTextColor(1, 0.82, 0)

    local expLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    expLabel:SetPoint("LEFT", raidBtn, "RIGHT", 16, 0)
    expLabel:SetText("Expansion:")

    tierDD = MakeDropdown(f, 180)
    tierDD:SetPoint("LEFT", expLabel, "RIGHT", 6, 0)

    -- ---- Row 2: Instance + Difficulty ----
    y = y - 30

    local instLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    instLabel:SetPoint("TOPLEFT", 12, y)
    instLabel:SetText("Instance:")

    instanceDD = MakeDropdown(f, 220)
    instanceDD:SetPoint("LEFT", instLabel, "RIGHT", 6, 0)
    instanceDD:SetValue("Select Instance...")

    local diffLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    diffLabel:SetPoint("LEFT", instanceDD, "RIGHT", 16, 0)
    diffLabel:SetText("Difficulty:")

    diffDD = MakeDropdown(f, 130)
    diffDD:SetPoint("LEFT", diffLabel, "RIGHT", 6, 0)

    -- ---- Row 3: Boss + class note ----
    y = y - 30

    local bossLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bossLabel:SetPoint("TOPLEFT", 12, y)
    bossLabel:SetText("Boss:")

    encounterDD = MakeDropdown(f, 220)
    encounterDD:SetPoint("LEFT", bossLabel, "RIGHT", 6, 0)
    encounterDD:SetValue("All Bosses")

    local classNote = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    classNote:SetPoint("LEFT", encounterDD, "RIGHT", 12, 0)
    classNote:SetText("|cFF888888Filtered by your class|r")

    -- ---- Divider ----
    y = y - 28
    local div = f:CreateTexture(nil, "ARTWORK")
    div:SetPoint("TOPLEFT", 6, y)
    div:SetPoint("TOPRIGHT", -6, y)
    div:SetHeight(1)
    div:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    y = y - 4

    -- ---- Column headers ----
    local leftHdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    leftHdr:SetPoint("TOPLEFT", 12, y)
    leftHdr:SetText("Available Items")
    leftHdr:SetTextColor(1, 0.82, 0)

    local rightHdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rightHdr:SetPoint("TOPRIGHT", -80, y)
    rightHdr:SetText("My Checklist")
    rightHdr:SetTextColor(1, 0.82, 0)

    y = y - 18

    -- ---- EJ items pane (left, ~400px) ----
    local ejBg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    ejBg:SetPoint("TOPLEFT", 8, y)
    ejBg:SetPoint("BOTTOMLEFT", 8, 8)
    ejBg:SetWidth(408)
    ejBg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1, insets = { left=1,right=1,top=1,bottom=1 } })
    ejBg:SetBackdropColor(0.04, 0.04, 0.04, 0.85)
    ejBg:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local ejSF = CreateFrame("ScrollFrame", nil, ejBg, "UIPanelScrollFrameTemplate")
    ejSF:SetPoint("TOPLEFT", 3, -3)
    ejSF:SetPoint("BOTTOMRIGHT", -18, 3)

    ejScrollChild = CreateFrame("Frame", nil, ejSF)
    ejScrollChild:SetWidth(ejSF:GetWidth() or 370)
    ejScrollChild:SetHeight(1)
    ejSF:SetScrollChild(ejScrollChild)
    ejSF:HookScript("OnSizeChanged", function(self, w) ejScrollChild:SetWidth(w) end)

    -- ---- Checklist pane (right, ~228px) ----
    local bcBg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    bcBg:SetPoint("TOPRIGHT", -8, y)
    bcBg:SetPoint("BOTTOMRIGHT", -8, 8)
    bcBg:SetWidth(228)
    bcBg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1, insets = { left=1,right=1,top=1,bottom=1 } })
    bcBg:SetBackdropColor(0.04, 0.04, 0.04, 0.85)
    bcBg:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local bcSF = CreateFrame("ScrollFrame", nil, bcBg, "UIPanelScrollFrameTemplate")
    bcSF:SetPoint("TOPLEFT", 3, -3)
    bcSF:SetPoint("BOTTOMRIGHT", -18, 3)

    bcScrollChild = CreateFrame("Frame", nil, bcSF)
    bcScrollChild:SetWidth(bcSF:GetWidth() or 200)
    bcScrollChild:SetHeight(1)
    bcSF:SetScrollChild(bcScrollChild)
    bcSF:HookScript("OnSizeChanged", function(self, w) bcScrollChild:SetWidth(w) end)

    -- ---- Wire type buttons ----
    dungeonBtn:SetScript("OnClick", function() SetInstanceType(1) end)
    raidBtn:SetScript("OnClick",    function() SetInstanceType(2) end)

    -- ---- Populate tier dropdown ----
    EnsureEJLoaded()
    local tiers  = {}
    local nTiers = (EJ_GetNumTiers and EJ_GetNumTiers()) or 0
    for i = 1, nTiers do
        local tname = (EJ_GetTierInfo and EJ_GetTierInfo(i)) or ("Tier " .. i)
        table.insert(tiers, { label = tname or ("Tier " .. i), tierIndex = i })
    end

    tierDD:SetItems(tiers, function(item)
        bTierIdx = item.tierIndex
        local instances = FetchInstances(bTierIdx, bInstanceType)
        instanceDD:SetItems(instances, OnInstanceSelected)
        instanceDD:SetValue("Select Instance...")
        bInstanceID  = nil
        bEncounterID = nil
        bItems       = {}
        RefreshEJList()
        LootChecklist.RefreshBrowserChecklist()
    end)

    -- Default to most recent tier
    if #tiers > 0 then
        bTierIdx = tiers[#tiers].tierIndex
        tierDD:SelectByIndex(#tiers)
        SetInstanceType(1)    -- sets dungeons + default difficulty, populates instanceDD
    end

    LootChecklist.RefreshBrowserChecklist()
end

function LootChecklist.ShowBrowser()
    if not browserFrame then
        CreateBrowserFrame()
    else
        if browserFrame:IsShown() then
            browserFrame:Hide()
            CloseActiveDropdown()
        else
            LootChecklist.RefreshBrowserChecklist()
            browserFrame:Show()
        end
    end
end

-- ============================================================
-- Settings application
-- ============================================================
function LootChecklist.UpdateSettings()
    if not checklistFrame then return end
    local Helpers = addonTable.ConfigHelpers

    checklistFrame:ClearAllPoints()
    if db.pos then
        checklistFrame:SetPoint(db.pos.point, UIParent, db.pos.point, db.pos.x, db.pos.y)
    else
        checklistFrame:SetPoint("CENTER")
    end

    checklistFrame:SetSize(db.width or 220, db.height or 280)

    if Helpers and Helpers.ApplyFrameBackdrop then
        Helpers.ApplyFrameBackdrop(checklistFrame, db.showBorder, db.borderColor, db.showBackground, db.backgroundColor)
    end

    if db.locked then
        checklistFrame:SetScript("OnDragStart", nil)
        checklistFrame:SetScript("OnDragStop",  nil)
    else
        checklistFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        checklistFrame:SetScript("OnDragStop",  function(self)
            self:StopMovingOrSizing()
            local cx, cy   = self:GetCenter()
            local pcx, pcy = UIParent:GetCenter()
            if cx and pcx then
                db.pos = { point = "CENTER", x = cx - pcx, y = cy - pcy }
            end
        end)
    end

    if db.enabled then
        if #db.checklist == 0 and db.locked then
            checklistFrame:Hide()
        else
            checklistFrame:Show()
        end
    else
        checklistFrame:Hide()
    end

    LootChecklist.RefreshChecklist()
end

-- ============================================================
-- Event handlers
-- ============================================================
local function OnEnteringWorld()
    EventBus.Unregister("PLAYER_ENTERING_WORLD", OnEnteringWorld)
    db = UIThingsDB.lootChecklist
    CreateChecklistFrame()
    LootChecklist.UpdateSettings()
    C_Timer.After(2, ScanBagsForChecklist)
end

local function OnTradeClosed()
    C_Timer.After(0.5, ScanBagsForChecklist)
end

-- ============================================================
-- Initialization
-- ============================================================
EventBus.Register("PLAYER_ENTERING_WORLD", OnEnteringWorld,   "LootChecklist")
EventBus.Register("CHAT_MSG_LOOT",         OnChatMsgLoot,     "LootChecklist")
EventBus.Register("TRADE_CLOSED",          OnTradeClosed,     "LootChecklist")

SLASH_LUITLOOT1 = "/luitloot"
SlashCmdList["LUITLOOT"] = function()
    if not db then return end
    if not db.enabled then
        Log("LootChecklist", "Loot Checklist is disabled. Enable it in /luit config.", LogLevel.WARN)
        return
    end
    LootChecklist.ShowBrowser()
end
