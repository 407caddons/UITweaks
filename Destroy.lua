-- Destroy.lua
-- Disenchant helper: while resting, lists bag gear that is unusable by your
-- class or lower ilvl than what you have equipped in every matching slot,
-- and provides a one-click Disenchant button (secure macro cast).

local addonName, addonTable = ...
local Destroy = {}
addonTable.Destroy = Destroy

local EventBus = addonTable.EventBus
local Helpers  -- resolved lazily; config/Helpers.lua loads before this file

local DISENCHANT_SPELL_ID = 13262

-- Enum.ItemArmorSubclass: 1=Cloth 2=Leather 3=Mail 4=Plate
local CLASS_ARMOR = {
    MAGE = 1, PRIEST = 1, WARLOCK = 1,
    ROGUE = 2, DRUID = 2, MONK = 2, DEMONHUNTER = 2,
    HUNTER = 3, SHAMAN = 3, EVOKER = 3,
    WARRIOR = 4, PALADIN = 4, DEATHKNIGHT = 4,
}

-- equipLoc -> inventory slot(s) the item competes with
local EQUIP_SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 16 }, INVTYPE_RANGEDRIGHT = { 16 },
}

local mainFrame = nil
local deButton  = nil
local rowPool   = {}
local items     = {}   -- { bag, slot, link, icon, ilvl, reason }
local closedByUser  = false
local pendingRefresh = false

-- ============================================================
-- Eligibility
-- ============================================================

local function IsEnchanter()
    return IsPlayerSpell(DISENCHANT_SPELL_ID) or IsSpellKnown(DISENCHANT_SPELL_ID)
end

-- Returns reason string if the item should be listed, nil otherwise
local function EvaluateItem(info)
    if not info or not info.hyperlink or info.isLocked then return nil end
    local quality = info.quality
    -- Only Uncommon..Epic gear can be disenchanted
    if not quality or quality < 2 or quality > 4 then return nil end

    local _, _, _, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(info.hyperlink)
    if classID ~= 2 and classID ~= 4 then return nil end -- weapon/armor only
    if not equipLoc or not EQUIP_SLOTS[equipLoc] then return nil end

    if C_Item.IsCosmeticItem and C_Item.IsCosmeticItem(info.hyperlink) then return nil end

    if not info.isBound and not UIThingsDB.destroy.includeBoE then return nil end

    -- Armor of a type the class can never wear (cloaks are usable by all)
    if classID == 4 and equipLoc ~= "INVTYPE_CLOAK"
        and subClassID and subClassID >= 1 and subClassID <= 4 then
        local _, classFile = UnitClass("player")
        local usable = CLASS_ARMOR[classFile]
        if usable and subClassID ~= usable then
            return "Unusable"
        end
    end

    -- Lower ilvl than what is equipped in every candidate slot.
    -- An empty candidate slot means the item could still be an upgrade -- skip.
    local itemLevel = C_Item.GetDetailedItemLevelInfo(info.hyperlink)
    if not itemLevel then return nil end
    for _, invSlot in ipairs(EQUIP_SLOTS[equipLoc]) do
        local equippedLink = GetInventoryItemLink("player", invSlot)
        if not equippedLink then return nil end
        local equippedIlvl = C_Item.GetDetailedItemLevelInfo(equippedLink)
        if not equippedIlvl or itemLevel >= equippedIlvl then return nil end
    end
    return "Low ilvl"
end

local function ScanBags()
    wipe(items)
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local reason = EvaluateItem(info)
            if reason then
                local ilvl = C_Item.GetDetailedItemLevelInfo(info.hyperlink)
                table.insert(items, {
                    bag = bag, slot = slot,
                    link = info.hyperlink,
                    icon = info.iconFileID,
                    ilvl = ilvl,
                    reason = reason,
                })
            end
        end
    end
end

-- ============================================================
-- Window
-- ============================================================

local function GetRow(index)
    if rowPool[index] then return rowPool[index] end
    -- Each row is itself a secure macro button so clicking it disenchants
    -- that specific item (macrotext is assigned per-item in RefreshList).
    local row = CreateFrame("Button", "LunaUITweaks_DestroyRow" .. index, mainFrame.scrollChild,
        "SecureActionButtonTemplate")
    row:SetHeight(22)
    row:SetPoint("LEFT", 0, 0)
    row:SetPoint("RIGHT", 0, 0)
    row:SetAttribute("type", "macro")
    local useKeyDown = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")
    row:RegisterForClicks(useKeyDown and "AnyDown" or "AnyUp")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 2, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.nameFS:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.nameFS:SetPoint("RIGHT", row, "RIGHT", -70, 0)
    row.nameFS:SetJustifyH("LEFT")
    row.nameFS:SetWordWrap(false)

    row.infoFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.infoFS:SetPoint("RIGHT", -4, 0)
    row.infoFS:SetJustifyH("RIGHT")

    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    row:SetScript("OnEnter", function(self)
        if not self.bagID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(self.bagID, self.slotID)
        GameTooltip:AddLine("|cff88ff88Click to disenchant this item|r")
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    rowPool[index] = row
    return row
end

local function BuildMacroText(bag, slot)
    return "/cast " .. (C_Spell.GetSpellName(DISENCHANT_SPELL_ID) or "Disenchant")
        .. "\n/use " .. bag .. " " .. slot
end

local function UpdateDisenchantButton()
    if InCombatLockdown() then return end
    local first = items[1]
    if first then
        deButton:SetAttribute("macrotext", BuildMacroText(first.bag, first.slot))
        deButton:SetText("Disenchant Next")
        deButton:Enable()
    else
        deButton:SetAttribute("macrotext", "")
        deButton:SetText("Nothing to Disenchant")
        deButton:Disable()
    end
end

local function RefreshList()
    if not mainFrame then return end
    ScanBags()

    for _, row in ipairs(rowPool) do row:Hide() end

    local yOff = 0
    for i, item in ipairs(items) do
        local row = GetRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", mainFrame.scrollChild, "TOPLEFT", 0, -yOff)
        row:SetPoint("RIGHT", mainFrame.scrollChild, "RIGHT", 0, 0)
        row.bagID, row.slotID = item.bag, item.slot
        row:SetAttribute("macrotext", BuildMacroText(item.bag, item.slot))
        row.icon:SetTexture(item.icon)
        row.nameFS:SetText(item.link)
        row.infoFS:SetText(item.ilvl .. " |cffaaaaaa" .. item.reason .. "|r")
        row:Show()
        yOff = yOff + 23
    end
    mainFrame.scrollChild:SetHeight(math.max(yOff, 1))
    mainFrame.countFS:SetFormattedText("%d item(s)", #items)

    UpdateDisenchantButton()
end

local function CreateWindow()
    if mainFrame then return end

    Helpers = addonTable.ConfigHelpers

    mainFrame = CreateFrame("Frame", "LunaUITweaks_DestroyFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(340, 300)
    mainFrame:SetFrameStrata("DIALOG")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:SetClampedToScreen(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        UIThingsDB.destroy.framePos = { point = point, relPoint = relPoint or point, x = x, y = y }
    end)

    local pos = UIThingsDB.destroy.framePos
    mainFrame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x, pos.y)

    mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mainFrame.title:SetPoint("TOPLEFT", 10, -10)
    mainFrame.title:SetText("Disenchant")

    mainFrame.countFS = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mainFrame.countFS:SetPoint("BOTTOMLEFT", 10, 14)
    mainFrame.countFS:SetTextColor(0.7, 0.7, 0.7)

    local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        closedByUser = true
        -- mainFrame parents a secure button; hiding it in combat is blocked
        if not InCombatLockdown() then mainFrame:Hide() end
    end)

    local scrollFrame = CreateFrame("ScrollFrame", "LunaUITweaks_DestroyScroll", mainFrame,
        "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -35)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 66)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(300)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    mainFrame.scrollChild = scrollChild

    -- Secure button: insecure code cannot cast Disenchant directly, so the
    -- click runs a macro that casts Disenchant and targets it at the first
    -- listed bag item. Attributes are only written out of combat.
    deButton = CreateFrame("Button", "LunaUITweaks_DestroyDEButton", mainFrame,
        "SecureActionButtonTemplate, UIPanelButtonTemplate")
    deButton:SetSize(180, 26)
    deButton:SetPoint("BOTTOM", 0, 34)
    deButton:SetAttribute("type", "macro")
    local useKeyDown = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")
    deButton:RegisterForClicks(useKeyDown and "AnyDown" or "AnyUp")

    mainFrame:Hide()
    Destroy.ApplyVisuals()
end

function Destroy.ApplyVisuals()
    if not mainFrame then return end
    local s = UIThingsDB.destroy
    Helpers = Helpers or addonTable.ConfigHelpers
    Helpers.ApplyFrameBackdrop(mainFrame, true, s.borderColor, true, s.bgColor)
end

-- ============================================================
-- Show / hide logic
-- ============================================================

local function ShouldOffer()
    return UIThingsDB.destroy.enabled and IsEnchanter() and IsResting()
end

function Destroy.ShowWindow(force)
    if InCombatLockdown() then return end
    CreateWindow()
    RefreshList()
    if force or #items > 0 then
        mainFrame:Show()
    end
end

local function Reevaluate()
    if InCombatLockdown() then
        pendingRefresh = true
        return
    end
    if not ShouldOffer() then
        if mainFrame then mainFrame:Hide() end
        return
    end
    CreateWindow()
    RefreshList()
    if #items == 0 then
        mainFrame:Hide()
    elseif UIThingsDB.destroy.autoShow and not closedByUser then
        mainFrame:Show()
    end
end

-- ============================================================
-- Events
-- ============================================================

local function OnRestingChanged()
    if not IsResting() then
        closedByUser = false -- re-arm auto popup for the next rest area
        if mainFrame then
            if InCombatLockdown() then
                pendingRefresh = true -- hide once combat ends
            else
                mainFrame:Hide()
            end
        end
        return
    end
    Reevaluate()
end

local function OnBagsChanged()
    -- Only rescan while the offer is relevant; avoids constant bag scans
    if ShouldOffer() and (not mainFrame or mainFrame:IsShown() or (UIThingsDB.destroy.autoShow and not closedByUser)) then
        Reevaluate()
    end
end

local function OnRegenEnabled()
    if pendingRefresh then
        pendingRefresh = false
        Reevaluate()
    end
end

local eventsRegistered = false

function Destroy.UpdateSettings()
    local enabled = UIThingsDB.destroy.enabled
    if enabled and not eventsRegistered then
        EventBus.Register("PLAYER_UPDATE_RESTING", OnRestingChanged, "Destroy")
        EventBus.Register("PLAYER_ENTERING_WORLD", OnRestingChanged, "Destroy")
        EventBus.Register("BAG_UPDATE_DELAYED", OnBagsChanged, "Destroy")
        EventBus.Register("PLAYER_EQUIPMENT_CHANGED", OnBagsChanged, "Destroy")
        EventBus.Register("PLAYER_REGEN_ENABLED", OnRegenEnabled, "Destroy")
        eventsRegistered = true
    elseif not enabled and eventsRegistered then
        EventBus.Unregister("PLAYER_UPDATE_RESTING", OnRestingChanged)
        EventBus.Unregister("PLAYER_ENTERING_WORLD", OnRestingChanged)
        EventBus.Unregister("BAG_UPDATE_DELAYED", OnBagsChanged)
        EventBus.Unregister("PLAYER_EQUIPMENT_CHANGED", OnBagsChanged)
        EventBus.Unregister("PLAYER_REGEN_ENABLED", OnRegenEnabled)
        eventsRegistered = false
    end

    if not enabled then
        if mainFrame and not InCombatLockdown() then mainFrame:Hide() end
    else
        Destroy.ApplyVisuals()
        Reevaluate()
    end
end

local function OnPlayerLogin()
    Destroy.UpdateSettings()
end

EventBus.Register("PLAYER_LOGIN", OnPlayerLogin, "Destroy")
