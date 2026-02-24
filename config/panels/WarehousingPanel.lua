local addonName, addonTable = ...

addonTable.ConfigSetup = addonTable.ConfigSetup or {}

local Helpers = addonTable.ConfigHelpers

-- Signals to the Reagents tooltip hook that we're hovering a warehousing icon (allow non-reagent items)
addonTable.WarehousingTooltipItemID = nil

-- Warehousing-specific reset: wipes UIThingsDB.warehousing AND tracked item list
if not StaticPopupDialogs["LUNA_RESET_WAREHOUSING_CONFIRM"] then
    StaticPopupDialogs["LUNA_RESET_WAREHOUSING_CONFIRM"] = {
        text = "Reset Warehousing settings to defaults?\n\nThis will also clear all tracked items and reload the UI.",
        button1 = "Reset & Reload",
        button2 = "Cancel",
        OnAccept = function()
            local defaults = addonTable and addonTable.Core and addonTable.Core.DEFAULTS
            if defaults and defaults.warehousing and UIThingsDB and UIThingsDB.warehousing then
                wipe(UIThingsDB.warehousing)
                local function DeepCopyInto(target, source)
                    for k, v in pairs(source) do
                        if type(v) == "table" then
                            target[k] = {}
                            DeepCopyInto(target[k], v)
                        else
                            target[k] = v
                        end
                    end
                end
                DeepCopyInto(UIThingsDB.warehousing, defaults.warehousing)
            end
            -- Also wipe tracked items from the separate saved variable
            if LunaUITweaks_WarehousingData then
                wipe(LunaUITweaks_WarehousingData)
            end
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

function addonTable.ConfigSetup.Warehousing(panel, tab, configWindow)
    -- Custom reset button that also clears tracked items
    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 22)
    resetBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)
    resetBtn:SetText("Reset Defaults")
    resetBtn:SetScript("OnClick", function()
        StaticPopup_Show("LUNA_RESET_WAREHOUSING_CONFIRM")
    end)

    -- Panel Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Warehousing")

    -- Enable Checkbox
    local enableBtn = CreateFrame("CheckButton", "UIThingsWarehousingEnableCheck", panel,
        "ChatConfigCheckButtonTemplate")
    enableBtn:SetPoint("TOPLEFT", 20, -50)
    _G[enableBtn:GetName() .. "Text"]:SetText("Enable Warehousing")
    enableBtn:SetChecked(UIThingsDB.warehousing.enabled)
    enableBtn:SetScript("OnClick", function(self)
        local enabled = not not self:GetChecked()
        UIThingsDB.warehousing.enabled = enabled
        Helpers.UpdateModuleVisuals(panel, tab, enabled)
        if addonTable.Warehousing and addonTable.Warehousing.UpdateSettings then
            addonTable.Warehousing.UpdateSettings()
        end
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.warehousing.enabled)

    -- Description
    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", 40, -80)
    desc:SetWidth(560)
    desc:SetJustifyH("LEFT")
    desc:SetText(
        "Manages item distribution across your characters. Set minimum counts and overflow destinations per item.\n" ..
        "Overflow items are mailed at the mailbox or deposited at the bank. Deficit items are withdrawn from the bank.\n" ..
        "Drag items from your bags and drop them onto this panel to add them to the list.")
    desc:SetTextColor(0.7, 0.7, 0.7)

    -- Frame Appearance Section
    Helpers.CreateSectionHeader(panel, "Popup Frame Appearance", -130)

    Helpers.CreateColorSwatch(panel, "Border Color:", UIThingsDB.warehousing.frameBorderColor, function()
        if addonTable.Warehousing and addonTable.Warehousing.UpdateSettings then
            addonTable.Warehousing.UpdateSettings()
        end
    end, 20, -155)

    Helpers.CreateColorSwatch(panel, "Background Color:", UIThingsDB.warehousing.frameBgColor, function()
        if addonTable.Warehousing and addonTable.Warehousing.UpdateSettings then
            addonTable.Warehousing.UpdateSettings()
        end
    end, 220, -155)

    -- Auto-Buy Settings Section
    Helpers.CreateSectionHeader(panel, "Auto-Buy Settings", -190)

    -- autoBuyEnabled checkbox
    local autoBuyCheck = CreateFrame("CheckButton", "UIThingsWarehousingAutoBuyCheck", panel,
        "ChatConfigCheckButtonTemplate")
    autoBuyCheck:SetPoint("TOPLEFT", 20, -215)
    _G[autoBuyCheck:GetName() .. "Text"]:SetText("Enable auto-buy from vendors")
    autoBuyCheck:SetChecked(UIThingsDB.warehousing.autoBuyEnabled)
    autoBuyCheck:SetScript("OnClick", function(self)
        UIThingsDB.warehousing.autoBuyEnabled = not not self:GetChecked()
    end)

    -- Gold reserve editbox
    local goldReserveLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    goldReserveLabel:SetPoint("TOPLEFT", 20, -245)
    goldReserveLabel:SetText("Gold reserve (never spend below this amount):")
    goldReserveLabel:SetTextColor(0.7, 0.7, 0.7)

    local goldReserveEditBox = CreateFrame("EditBox", "UIThingsWH_GoldReserve", panel, "InputBoxTemplate")
    goldReserveEditBox:SetSize(60, 20)
    goldReserveEditBox:SetPoint("LEFT", goldReserveLabel, "RIGHT", 8, 0)
    goldReserveEditBox:SetAutoFocus(false)
    goldReserveEditBox:SetNumeric(true)
    goldReserveEditBox:SetMaxLetters(6)
    goldReserveEditBox:SetText(tostring(UIThingsDB.warehousing.goldReserve or 500))
    goldReserveEditBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText()) or 500
        if val < 0 then val = 0 end
        UIThingsDB.warehousing.goldReserve = val
        self:SetText(tostring(val))
        self:ClearFocus()
    end)
    goldReserveEditBox:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(UIThingsDB.warehousing.goldReserve or 500))
        self:ClearFocus()
    end)

    local goldReserveSuffix = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    goldReserveSuffix:SetPoint("LEFT", goldReserveEditBox, "RIGHT", 4, 0)
    goldReserveSuffix:SetText("gold")
    goldReserveSuffix:SetTextColor(0.7, 0.7, 0.7)

    -- Confirm above editbox
    local confirmLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    confirmLabel:SetPoint("TOPLEFT", 20, -273)
    confirmLabel:SetText("Show confirmation if total purchase exceeds:")
    confirmLabel:SetTextColor(0.7, 0.7, 0.7)

    local confirmEditBox = CreateFrame("EditBox", "UIThingsWH_ConfirmAbove", panel, "InputBoxTemplate")
    confirmEditBox:SetSize(60, 20)
    confirmEditBox:SetPoint("LEFT", confirmLabel, "RIGHT", 8, 0)
    confirmEditBox:SetAutoFocus(false)
    confirmEditBox:SetNumeric(true)
    confirmEditBox:SetMaxLetters(6)
    confirmEditBox:SetText(tostring(UIThingsDB.warehousing.confirmAbove or 100))
    confirmEditBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText()) or 100
        if val < 0 then val = 0 end
        UIThingsDB.warehousing.confirmAbove = val
        self:SetText(tostring(val))
        self:ClearFocus()
    end)
    confirmEditBox:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(UIThingsDB.warehousing.confirmAbove or 100))
        self:ClearFocus()
    end)

    local confirmSuffix = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    confirmSuffix:SetPoint("LEFT", confirmEditBox, "RIGHT", 4, 0)
    confirmSuffix:SetText("gold  (0 = always confirm)")
    confirmSuffix:SetTextColor(0.7, 0.7, 0.7)

    -- Item List Section
    Helpers.CreateSectionHeader(panel, "Tracked Items", -300)

    local instrText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    instrText:SetPoint("TOPLEFT", 20, -325)
    instrText:SetText("Drag an item from your bags and drop it here to add it to the list.")
    instrText:SetTextColor(0.5, 0.5, 0.5)

    -- Scroll frame for item list
    local scrollFrame = CreateFrame("ScrollFrame", "UIThingsWarehousingItemScroll", panel,
        "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -345)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 20)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() or 560)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    -- Row pool
    local itemRows = {}
    local headerRows = {}

    -- Category names from classID
    local CLASS_NAMES = {}
    local function GetClassName(classID)
        if CLASS_NAMES[classID] then return CLASS_NAMES[classID] end
        local name = GetItemClassInfo(classID)
        CLASS_NAMES[classID] = name or ("Class " .. classID)
        return CLASS_NAMES[classID]
    end

    -- Build destination dropdown for a row
    local function BuildDestinationDropdown(dropdownFrame, itemID)
        local destinations = addonTable.Warehousing and addonTable.Warehousing.GetDestinations(itemID) or { "Warband Bank" }
        UIDropDownMenu_Initialize(dropdownFrame, function(self, level)
            for _, dest in ipairs(destinations) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = dest
                info.value = dest
                info.func = function(btnSelf)
                    if LunaUITweaks_WarehousingData and LunaUITweaks_WarehousingData.items[itemID] then
                        LunaUITweaks_WarehousingData.items[itemID].destination = dest
                    end
                    UIDropDownMenu_SetText(dropdownFrame, dest)
                    CloseDropDownMenus()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
    end

    -- Shared character-picker popup (one instance, reused per row)
    local charPickerPopup = nil
    local charPickerCheckboxes = {}
    local charPickerItemID = nil
    local charPickerBtn = nil -- the button that opened it

    local function UpdateCharPickerButton(btn, itemID)
        local item = LunaUITweaks_WarehousingData and LunaUITweaks_WarehousingData.items
            and LunaUITweaks_WarehousingData.items[itemID]
        if not item then btn:SetText("All"); return end
        local chars = item.minKeepChars
        if not chars then btn:SetText("All"); return end
        local count = 0
        for _ in pairs(chars) do count = count + 1 end
        btn:SetText(count == 0 and "All" or (count .. " chr"))
    end

    local function GetOrCreateCharPickerPopup()
        if charPickerPopup then return charPickerPopup end
        charPickerPopup = CreateFrame("Frame", "UIThingsWH_CharPicker", UIParent, "BackdropTemplate")
        charPickerPopup:SetFrameStrata("TOOLTIP")
        charPickerPopup:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        charPickerPopup:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        charPickerPopup:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        charPickerPopup:EnableMouse(true)

        -- Close when clicking outside
        charPickerPopup:SetScript("OnHide", function()
            charPickerItemID = nil
            charPickerBtn = nil
        end)

        -- "All chars" clear button at top
        charPickerPopup.clearBtn = CreateFrame("Button", nil, charPickerPopup, "UIPanelButtonTemplate")
        charPickerPopup.clearBtn:SetSize(80, 20)
        charPickerPopup.clearBtn:SetPoint("TOPLEFT", 6, -6)
        charPickerPopup.clearBtn:SetText("All Chars")
        charPickerPopup.clearBtn:SetNormalFontObject("GameFontNormalSmall")
        charPickerPopup.clearBtn:SetScript("OnClick", function()
            if charPickerItemID and addonTable.Warehousing then
                addonTable.Warehousing.SetMinKeepChars(charPickerItemID, nil)
                if charPickerBtn then UpdateCharPickerButton(charPickerBtn, charPickerItemID) end
                -- Refresh checkboxes
                local item = LunaUITweaks_WarehousingData.items[charPickerItemID]
                for _, cb in ipairs(charPickerCheckboxes) do
                    if cb:IsShown() then cb:SetChecked(false) end
                end
            end
        end)

        return charPickerPopup
    end

    local function OpenCharPicker(anchorBtn, itemID)
        local popup = GetOrCreateCharPickerPopup()

        -- Hide all existing checkboxes
        for _, cb in ipairs(charPickerCheckboxes) do
            cb:Hide()
        end

        charPickerItemID = itemID
        charPickerBtn = anchorBtn

        local keys = addonTable.Warehousing and addonTable.Warehousing.GetAllCharacterKeys() or {}
        local item = LunaUITweaks_WarehousingData and LunaUITweaks_WarehousingData.items
            and LunaUITweaks_WarehousingData.items[itemID]
        local selected = (item and item.minKeepChars) or {}

        local cbY = -32
        local CB_HEIGHT = 22
        for i, key in ipairs(keys) do
            local cb = charPickerCheckboxes[i]
            if not cb then
                cb = CreateFrame("CheckButton", "UIThingsWH_CharCB_" .. i, popup, "ChatConfigCheckButtonTemplate")
                charPickerCheckboxes[i] = cb
            end
            cb:SetPoint("TOPLEFT", 6, cbY)
            local charName = key:match("^(.+) %- ") or key
            _G[cb:GetName() .. "Text"]:SetText(charName)
            cb:SetChecked(selected[key] == true)
            cb:SetScript("OnClick", function(self)
                if not charPickerItemID then return end
                local itm = LunaUITweaks_WarehousingData.items[charPickerItemID]
                if not itm then return end
                itm.minKeepChars = itm.minKeepChars or {}
                if self:GetChecked() then
                    itm.minKeepChars[key] = true
                else
                    itm.minKeepChars[key] = nil
                end
                -- If none selected, clear to nil
                local hasAny = false
                for _ in pairs(itm.minKeepChars) do hasAny = true; break end
                if not hasAny then itm.minKeepChars = nil end
                if charPickerBtn then UpdateCharPickerButton(charPickerBtn, charPickerItemID) end
            end)
            cb:Show()
            cbY = cbY - CB_HEIGHT
        end

        if #keys == 0 then
            -- No other characters known yet
            if not popup.noCharsText then
                popup.noCharsText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                popup.noCharsText:SetPoint("TOPLEFT", 10, -36)
                popup.noCharsText:SetTextColor(0.5, 0.5, 0.5)
                popup.noCharsText:SetText("No other characters found.\nLog in on each character first.")
            end
            popup.noCharsText:Show()
            popup:SetSize(200, 70)
        else
            if popup.noCharsText then popup.noCharsText:Hide() end
            local popupH = 32 + (#keys * CB_HEIGHT) + 8
            popup:SetSize(180, popupH)
        end

        popup:ClearAllPoints()
        popup:SetPoint("BOTTOMLEFT", anchorBtn, "TOPLEFT", 0, 2)
        -- Clamp to screen top
        local screenH = GetScreenHeight()
        local popupTop = select(5, popup:GetPoint()) + popup:GetHeight()
        if popupTop > screenH - 5 then
            popup:ClearAllPoints()
            popup:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -2)
        end

        if charPickerPopup:IsShown() and charPickerItemID == itemID then
            charPickerPopup:Hide()
        else
            charPickerPopup:Show()
        end
    end

    local function CreateItemRow(parent, index)
        local ROW_HEIGHT = 28
        local row = CreateFrame("Frame", nil, parent)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("LEFT", 0, 0)
        row:SetPoint("RIGHT", 0, 0)

        -- Background
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()

        -- Icon
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("LEFT", 4, 0)

        -- Invisible button over icon to capture mouse for tooltip
        row.iconBtn = CreateFrame("Button", nil, row)
        row.iconBtn:SetSize(20, 20)
        row.iconBtn:SetPoint("LEFT", 4, 0)
        row.iconBtn:SetScript("OnEnter", function(self)
            local parent = self:GetParent()
            local itemID = parent.tooltipItemID
            if not itemID then return end
            addonTable.WarehousingTooltipItemID = itemID
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if parent.tooltipItemLink then
                GameTooltip:SetHyperlink(parent.tooltipItemLink)
            else
                GameTooltip:SetItemByID(itemID)
            end
            GameTooltip:Show()
        end)
        row.iconBtn:SetScript("OnLeave", function()
            addonTable.WarehousingTooltipItemID = nil
            GameTooltip:Hide()
        end)

        -- Item name
        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
        row.nameText:SetWidth(120)
        row.nameText:SetJustifyH("LEFT")

        -- Min label + editbox
        row.minLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.minLabel:SetPoint("LEFT", row.icon, "RIGHT", 130, 0)
        row.minLabel:SetText("Min:")
        row.minLabel:SetTextColor(0.7, 0.7, 0.7)

        row.minEditBox = CreateFrame("EditBox", "UIThingsWH_Min_" .. index, row, "InputBoxTemplate")
        row.minEditBox:SetSize(40, 20)
        row.minEditBox:SetPoint("LEFT", row.minLabel, "RIGHT", 4, 0)
        row.minEditBox:SetAutoFocus(false)
        row.minEditBox:SetNumeric(true)
        row.minEditBox:SetMaxLetters(5)

        -- Character filter button (opens picker popup)
        row.charBtn = CreateFrame("Button", "UIThingsWH_CharBtn_" .. index, row, "UIPanelButtonTemplate")
        row.charBtn:SetSize(46, 20)
        row.charBtn:SetPoint("LEFT", row.minEditBox, "RIGHT", 4, 0)
        row.charBtn:SetNormalFontObject("GameFontNormalSmall")

        -- Destination dropdown
        row.destLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.destLabel:SetPoint("LEFT", row.charBtn, "RIGHT", 6, 0)
        row.destLabel:SetText("To:")
        row.destLabel:SetTextColor(0.7, 0.7, 0.7)

        row.destDropdown = CreateFrame("Frame", "UIThingsWH_Dest_" .. index, row, "UIDropDownMenuTemplate")
        row.destDropdown:SetPoint("LEFT", row.destLabel, "RIGHT", -12, -2)
        UIDropDownMenu_SetWidth(row.destDropdown, 100)

        -- Auto-buy toggle button
        row.buyBtn = CreateFrame("Button", "UIThingsWH_Buy_" .. index, row, "UIPanelButtonTemplate")
        row.buyBtn:SetSize(36, 20)
        row.buyBtn:SetPoint("RIGHT", -30, 0)
        row.buyBtn:SetNormalFontObject("GameFontNormalSmall")

        -- Remove button
        row.removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.removeBtn:SetSize(22, 22)
        row.removeBtn:SetPoint("RIGHT", -4, 0)
        row.removeBtn:SetText("X")
        row.removeBtn:SetNormalFontObject("GameFontNormalSmall")

        return row
    end

    local function CreateHeaderRow(parent)
        local row = CreateFrame("Frame", nil, parent)
        row:SetHeight(22)
        row:SetPoint("LEFT", 0, 0)
        row:SetPoint("RIGHT", 0, 0)

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(0.15, 0.15, 0.15, 0.6)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.text:SetPoint("LEFT", 4, 0)
        row.text:SetTextColor(1, 0.82, 0)

        return row
    end

    local function RefreshItemList()
        -- Hide all rows
        for _, row in ipairs(itemRows) do row:Hide() end
        for _, row in ipairs(headerRows) do row:Hide() end

        if not LunaUITweaks_WarehousingData or not LunaUITweaks_WarehousingData.items then
            scrollChild:SetHeight(30)
            return
        end

        local items = LunaUITweaks_WarehousingData.items

        -- Group by classID
        local categories = {}
        for itemID, data in pairs(items) do
            local cid = data.classID or 15
            categories[cid] = categories[cid] or {}
            table.insert(categories[cid], { itemID = itemID, data = data })
        end

        -- Sort categories
        local sortedCats = {}
        for cid in pairs(categories) do
            table.insert(sortedCats, cid)
        end
        table.sort(sortedCats)

        local yOffset = 0
        local ROW_HEIGHT = 28
        local HEADER_HEIGHT = 22
        local rowIdx = 0
        local headerIdx = 0
        local hasItems = false

        for _, cid in ipairs(sortedCats) do
            hasItems = true

            -- Category header
            headerIdx = headerIdx + 1
            local header = headerRows[headerIdx]
            if not header then
                header = CreateHeaderRow(scrollChild)
                headerRows[headerIdx] = header
            end
            header:SetPoint("TOPLEFT", 0, -yOffset)
            header:SetPoint("TOPRIGHT", 0, -yOffset)
            header.text:SetText(GetClassName(cid))
            header:Show()
            yOffset = yOffset + HEADER_HEIGHT

            -- Sort items in category by name
            local catItems = categories[cid]
            table.sort(catItems, function(a, b) return (a.data.name or "") < (b.data.name or "") end)

            for _, entry in ipairs(catItems) do
                rowIdx = rowIdx + 1
                local row = itemRows[rowIdx]
                if not row then
                    row = CreateItemRow(scrollChild, rowIdx)
                    itemRows[rowIdx] = row
                end

                row:SetPoint("TOPLEFT", 0, -yOffset)
                row:SetPoint("TOPRIGHT", 0, -yOffset)

                -- Alternating bg
                if rowIdx % 2 == 0 then
                    row.bg:SetColorTexture(0.12, 0.12, 0.12, 0.5)
                else
                    row.bg:SetColorTexture(0.08, 0.08, 0.08, 0.3)
                end

                local itemID = entry.itemID
                local data = entry.data

                row.tooltipItemID = itemID
                row.tooltipItemLink = data.itemLink
                row.icon:SetTexture(data.icon or 134400)
                row.nameText:SetText(data.name or ("Item " .. itemID))

                -- Color by quality if available
                local _, _, quality = GetItemInfo(itemID)
                if quality then
                    local r, g, b = C_Item.GetItemQualityColor(quality)
                    if r then row.nameText:SetTextColor(r, g, b) end
                else
                    row.nameText:SetTextColor(1, 1, 1)
                end

                -- Min editbox
                row.minEditBox:SetText(tostring(data.minKeep or 0))
                row.minEditBox:SetScript("OnEnterPressed", function(self)
                    local val = tonumber(self:GetText()) or 0
                    if val < 0 then val = 0 end
                    if LunaUITweaks_WarehousingData.items[itemID] then
                        LunaUITweaks_WarehousingData.items[itemID].minKeep = val
                    end
                    self:ClearFocus()
                end)
                row.minEditBox:SetScript("OnEscapePressed", function(self)
                    self:SetText(tostring(data.minKeep or 0))
                    self:ClearFocus()
                end)

                -- Character filter button
                UpdateCharPickerButton(row.charBtn, itemID)
                row.charBtn:SetScript("OnClick", function(self)
                    OpenCharPicker(self, itemID)
                end)

                -- Destination dropdown
                BuildDestinationDropdown(row.destDropdown, itemID)
                UIDropDownMenu_SetText(row.destDropdown, data.destination or "Warband Bank")

                -- Auto-buy button
                local function UpdateBuyBtn()
                    local item = LunaUITweaks_WarehousingData.items[itemID]
                    if item and item.autoBuy then
                        row.buyBtn:SetText("|cff66cc66Buy|r")
                    else
                        row.buyBtn:SetText("Buy")
                    end
                end
                UpdateBuyBtn()
                row.buyBtn:SetScript("OnClick", function()
                    local item = LunaUITweaks_WarehousingData.items[itemID]
                    if not item then return end
                    if item.autoBuy then
                        -- Toggle off
                        item.autoBuy = false
                        item.vendorPrice = nil
                        item.vendorStackSize = nil
                        item.vendorName = nil
                    else
                        -- Toggle on: try to register from open merchant, else just flag
                        if addonTable.Warehousing and addonTable.Warehousing.IsAtMerchant() then
                            local ok = addonTable.Warehousing.RegisterVendorItem(itemID)
                            if not ok then
                                item.autoBuy = true  -- flag anyway; will match by name at merchant
                            end
                        else
                            item.autoBuy = true
                            addonTable.Core.Log("Warehousing",
                                (item.name or itemID) .. " flagged for auto-buy. Open a vendor to register its price.", 1)
                        end
                    end
                    UpdateBuyBtn()
                end)
                row.buyBtn:SetScript("OnEnter", function(self)
                    local item = LunaUITweaks_WarehousingData.items[itemID]
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:ClearLines()
                    if item and item.autoBuy then
                        GameTooltip:AddLine("Auto-Buy: |cff66cc66ON|r", 1, 1, 1)
                        if item.vendorName then
                            GameTooltip:AddLine("Vendor: " .. item.vendorName, 0.7, 0.7, 0.7)
                        end
                        if item.vendorPrice then
                            GameTooltip:AddLine("Price: " .. GetCoinTextureString(item.vendorPrice), 0.7, 0.7, 0.7)
                        end
                        GameTooltip:AddLine("Click to disable.", 0.5, 0.5, 0.5)
                    else
                        GameTooltip:AddLine("Auto-Buy: |cffccccccOFF|r", 1, 1, 1)
                        GameTooltip:AddLine("Click to enable.", 0.5, 0.5, 0.5)
                        if addonTable.Warehousing and addonTable.Warehousing.IsAtMerchant() then
                            GameTooltip:AddLine("Vendor is open — will register price.", 0.4, 0.8, 0.4)
                        else
                            GameTooltip:AddLine("Open a vendor to register the price.", 0.7, 0.7, 0.7)
                        end
                    end
                    GameTooltip:Show()
                end)
                row.buyBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

                -- Remove button
                row.removeBtn:SetScript("OnClick", function()
                    if addonTable.Warehousing and addonTable.Warehousing.RemoveItem then
                        addonTable.Warehousing.RemoveItem(itemID)
                    end
                    RefreshItemList()
                end)

                row:Show()
                yOffset = yOffset + ROW_HEIGHT
            end
        end

        if not hasItems then
            -- Show empty message
            if not scrollChild.emptyText then
                scrollChild.emptyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                scrollChild.emptyText:SetPoint("TOPLEFT", 4, 0)
                scrollChild.emptyText:SetText("No items tracked. Drag items from your bags and drop them here.")
                scrollChild.emptyText:SetTextColor(0.5, 0.5, 0.5)
            end
            scrollChild.emptyText:Show()
            scrollChild:SetHeight(30)
        else
            if scrollChild.emptyText then scrollChild.emptyText:Hide() end
            scrollChild:SetHeight(math.max(yOffset, 1))
        end
    end

    -- Store refresh function for external access
    if addonTable.Warehousing then
        addonTable.Warehousing.RefreshConfigList = RefreshItemList
    end

    -- Set up drag-and-drop on the panel itself so items can be dropped anywhere on it
    if addonTable.Warehousing and addonTable.Warehousing.SetupDropTarget then
        addonTable.Warehousing.SetupDropTarget(panel)
    end

    -- Column headers above the scroll frame
    -- Positions derived from CreateItemRow:
    --   icon LEFT+4(20w), name LEFT+28(120w)
    --   minLabel LEFT+150, minEditBox LEFT+168(40w)
    --   charBtn LEFT+212(46w)
    --   destLabel LEFT+264("To:"), destDropdown LEFT+266 (UIDropDown adds ~16px internal pad → text ~LEFT+282)
    local function MakeColumnHeader(labelText, xOffset, anchorSide)
        local h = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        if anchorSide == "RIGHT" then
            h:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", xOffset, 14)
        else
            h:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", xOffset, 14)
        end
        h:SetText(labelText)
        h:SetTextColor(1, 0.82, 0)
        return h
    end

    MakeColumnHeader("Item",          4)          -- aligns with icon/name
    MakeColumnHeader("Min",         168)          -- aligns with min editbox (after "Min:" label)
    MakeColumnHeader("On Char",     212)          -- aligns with char picker button
    MakeColumnHeader("Destination", 282)          -- aligns with dest dropdown text area
    MakeColumnHeader("Buy",         -62, "RIGHT") -- aligns with buy button (RIGHT-30, width 36)

    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    refreshBtn:SetSize(80, 22)
    refreshBtn:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -20, 18)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", RefreshItemList)

    -- Initial refresh
    RefreshItemList()

    -- Store for external access
    addonTable.Config.RefreshWarehousingList = RefreshItemList
end
