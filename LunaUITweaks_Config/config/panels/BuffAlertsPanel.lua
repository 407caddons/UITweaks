local addonName, addonTable = "LunaUITweaks", _G.LunaUITweaks
addonTable.ConfigSetup = addonTable.ConfigSetup or {}
local Helpers, BuffAlerts = addonTable.ConfigHelpers, addonTable.BuffAlerts

local function NewSound() return { preset = "none" } end
local function Sound(rule, key)
    if type(rule[key]) ~= "table" then rule[key] = NewSound() end
    rule[key].preset = rule[key].preset or "none"
    return rule[key]
end
local function Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = Copy(child) end
    return out
end

function addonTable.ConfigSetup.BuffAlerts(panel, navButton)
    Helpers.CreateResetButton(panel, "buffAlerts")
    local selectedRule, selectedCopy, selectedCustomID, selectedCategoryID
    local RefreshList, RefreshEditor, RefreshCategoryManager

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Buff Alerts")
    local enable = CreateFrame("CheckButton", "UIThingsBuffAlertsEnabled", panel, "ChatConfigCheckButtonTemplate")
    enable:SetPoint("TOPLEFT", 16, -50)
    _G[enable:GetName() .. "Text"]:SetText("Enable player buff/debuff sounds")
    local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPRIGHT", -18, -55)
    status:SetWidth(300)
    status:SetJustifyH("RIGHT")

    local function Nav() Helpers.UpdateModuleVisuals(panel, navButton, UIThingsDB.buffAlerts.enabled) end
    local function Status(message, isError)
        local state, current = BuffAlerts.GetStatus()
        message = message or current
        if isError or state == "error" then status:SetTextColor(1, .3, .3)
        elseif state == "pending" then status:SetTextColor(1, .82, 0)
        else status:SetTextColor(.35, 1, .45) end
        status:SetText(message or "")
    end
    local function Apply()
        BuffAlerts.Refresh()
        Status()
        Nav()
    end

    -- Register custom sounds once; ability events only choose from the list.
    local registryTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    registryTitle:SetPoint("TOPLEFT", 20, -82)
    registryTitle:SetText("Registered custom sounds")
    local soundName = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    soundName:SetSize(110, 22); soundName:SetPoint("TOPLEFT", 20, -105); soundName:SetAutoFocus(false)
    local soundFile = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    soundFile:SetSize(240, 22); soundFile:SetPoint("LEFT", soundName, "RIGHT", 8, 0); soundFile:SetAutoFocus(false)
    local register = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    register:SetSize(66, 22); register:SetPoint("LEFT", soundFile, "RIGHT", 8, 0); register:SetText("Register")
    local customDD = CreateFrame("Frame", nil, panel, "UIDropDownMenuTemplate")
    customDD:SetPoint("LEFT", register, "RIGHT", -8, 0); UIDropDownMenu_SetWidth(customDD, 120)
    local testCustom = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testCustom:SetSize(42, 22); testCustom:SetPoint("TOPLEFT", 20, -132); testCustom:SetText("Test")
    local removeCustom = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    removeCustom:SetSize(58, 22); removeCustom:SetPoint("LEFT", testCustom, "RIGHT", 6, 0); removeCustom:SetText("Remove")
    local soundHint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    soundHint:SetPoint("LEFT", removeCustom, "RIGHT", 10, 0); soundHint:SetTextColor(.6, .6, .6)
    soundHint:SetText("Name + .ogg/.mp3 path or file-data ID")

    local function RefreshCustom()
        local found
        for _, entry in ipairs(UIThingsDB.buffAlerts.customSounds or {}) do
            if tostring(entry.id) == tostring(selectedCustomID) then found = entry break end
        end
        if not found then selectedCustomID = nil end
        UIDropDownMenu_SetText(customDD, found and found.name or "Custom sounds")
    end
    UIDropDownMenu_Initialize(customDD, function(_, level)
        local sounds = UIThingsDB.buffAlerts.customSounds or {}
        if #sounds == 0 then
            local info = UIDropDownMenu_CreateInfo(); info.text = "No custom sounds"; info.disabled = true
            UIDropDownMenu_AddButton(info, level)
        end
        for _, entry in ipairs(sounds) do
            local id, name = entry.id, entry.name
            local info = UIDropDownMenu_CreateInfo(); info.text = name; info.checked = tostring(id) == tostring(selectedCustomID)
            info.func = function() selectedCustomID = id RefreshCustom() end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    local function RegisterSound()
        local ok, err = BuffAlerts.AddCustomSound(soundName:GetText(), soundFile:GetText())
        if not ok then Status(err, true) return end
        local sounds = UIThingsDB.buffAlerts.customSounds
        selectedCustomID = sounds[#sounds].id
        soundName:SetText(""); soundFile:SetText(""); soundName:ClearFocus(); soundFile:ClearFocus()
        RefreshCustom(); if RefreshEditor then RefreshEditor() end
        Status("Custom sound registered.")
    end
    register:SetScript("OnClick", RegisterSound); soundName:SetScript("OnEnterPressed", RegisterSound); soundFile:SetScript("OnEnterPressed", RegisterSound)
    testCustom:SetScript("OnClick", function()
        if not selectedCustomID then Status("Select a custom sound first.", true) return end
        local ok, err = BuffAlerts.TestSound({ preset = "custom:" .. selectedCustomID })
        Status(ok and "Sound played." or err, not ok)
    end)
    removeCustom:SetScript("OnClick", function()
        if not selectedCustomID then Status("Select a custom sound first.", true) return end
        BuffAlerts.RemoveCustomSound(selectedCustomID); selectedCustomID = nil; Apply(); RefreshCustom(); if RefreshEditor then RefreshEditor() end
    end)

    -- Custom categories control list grouping and retain their creation order.
    local categoryTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    categoryTitle:SetPoint("TOPLEFT", 20, -166); categoryTitle:SetText("Organize ability categories:")
    local categoryName = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    categoryName:SetSize(130, 22); categoryName:SetPoint("TOPLEFT", 20, -184); categoryName:SetAutoFocus(false)
    local addCategory = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    addCategory:SetSize(48, 22); addCategory:SetPoint("LEFT", categoryName, "RIGHT", 7, 0); addCategory:SetText("Add")
    local categoryManageDD = CreateFrame("Frame", nil, panel, "UIDropDownMenuTemplate")
    categoryManageDD:SetPoint("LEFT", addCategory, "RIGHT", -7, 0); UIDropDownMenu_SetWidth(categoryManageDD, 125)
    local removeCategory = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    removeCategory:SetSize(58, 22); removeCategory:SetPoint("LEFT", categoryManageDD, "RIGHT", -8, 0); removeCategory:SetText("Remove")
    local categoryUp = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    categoryUp:SetSize(28, 22); categoryUp:SetPoint("LEFT", removeCategory, "RIGHT", 5, 0); categoryUp:SetText("Up")
    local categoryDown = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    categoryDown:SetSize(38, 22); categoryDown:SetPoint("LEFT", categoryUp, "RIGHT", 5, 0); categoryDown:SetText("Down")

    local function FindCategory(id)
        for index, category in ipairs(UIThingsDB.buffAlerts.categories or {}) do
            if tostring(category.id) == tostring(id) then return category, index end
        end
    end
    RefreshCategoryManager = function()
        local category = FindCategory(selectedCategoryID)
        if not category then selectedCategoryID = nil end
        UIDropDownMenu_SetText(categoryManageDD, category and category.name or "Select category")
        removeCategory:SetEnabled(category ~= nil); categoryUp:SetEnabled(category ~= nil); categoryDown:SetEnabled(category ~= nil)
    end
    UIDropDownMenu_Initialize(categoryManageDD, function(_, level)
        local categories = UIThingsDB.buffAlerts.categories or {}
        if #categories == 0 then
            local info = UIDropDownMenu_CreateInfo(); info.text = "No categories"; info.disabled = true; UIDropDownMenu_AddButton(info, level)
        end
        for _, category in ipairs(categories) do
            local id, name = category.id, category.name
            local info = UIDropDownMenu_CreateInfo(); info.text = name; info.checked = tostring(id) == tostring(selectedCategoryID)
            info.func = function() selectedCategoryID = id RefreshCategoryManager() end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    local function CreateCategory()
        local name = categoryName:GetText():match("^%s*(.-)%s*$")
        if name == "" then Status("Enter a category name.", true) return end
        for _, category in ipairs(UIThingsDB.buffAlerts.categories or {}) do
            if category.name:lower() == name:lower() then Status("That category already exists.", true) return end
        end
        local db = UIThingsDB.buffAlerts; local id = db.nextCategoryID or 1; db.nextCategoryID = id + 1
        db.categories[#db.categories + 1] = { id = id, name = name }; selectedCategoryID = id
        categoryName:SetText(""); categoryName:ClearFocus(); RefreshCategoryManager(); RefreshList(); Status("Category added.")
    end
    addCategory:SetScript("OnClick", CreateCategory); categoryName:SetScript("OnEnterPressed", CreateCategory)
    removeCategory:SetScript("OnClick", function()
        local _, index = FindCategory(selectedCategoryID)
        if not index then return end
        for _, rule in ipairs(UIThingsDB.buffAlerts.rules or {}) do if tostring(rule.categoryID) == tostring(selectedCategoryID) then rule.categoryID = nil end end
        table.remove(UIThingsDB.buffAlerts.categories, index); selectedCategoryID = nil
        RefreshCategoryManager(); RefreshList(); Status("Category removed; its abilities are now uncategorized.")
    end)
    local function MoveCategory(offset)
        local _, index = FindCategory(selectedCategoryID); if not index then return end
        local target = index + offset; local categories = UIThingsDB.buffAlerts.categories
        if target < 1 or target > #categories then return end
        categories[index], categories[target] = categories[target], categories[index]; RefreshList()
    end
    categoryUp:SetScript("OnClick", function() MoveCategory(-1) end); categoryDown:SetScript("OnClick", function() MoveCategory(1) end)

    -- Name/ID search.
    local addLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    addLabel:SetPoint("TOPLEFT", 20, -216); addLabel:SetText("Add buff/debuff by name or Spell ID:")
    local addEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    addEdit:SetSize(220, 22); addEdit:SetPoint("TOPLEFT", 20, -234); addEdit:SetAutoFocus(false)
    local addButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    addButton:SetSize(80, 22); addButton:SetPoint("LEFT", addEdit, "RIGHT", 8, 0); addButton:SetText("Add")
    local popup = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    popup:SetSize(335, 8); popup:SetPoint("TOPLEFT", addEdit, "BOTTOMLEFT", 0, -2); popup:SetFrameStrata("DIALOG"); popup:SetFrameLevel(100)
    popup:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    popup:SetBackdropColor(.025, .025, .025, .98); popup:SetBackdropBorderColor(.3, .3, .3, 1); popup:Hide()
    local results, selectedSpellID, generation = {}, nil, 0
    for index = 1, 8 do
        local row = CreateFrame("Button", nil, popup); row:SetHeight(28); row:SetPoint("TOPLEFT", 2, -2 - ((index - 1) * 28)); row:SetPoint("RIGHT", -2, 0)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(22, 22); row.icon:SetPoint("LEFT", 4, 0)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.text:SetPoint("LEFT", row.icon, "RIGHT", 7, 0); row.text:SetPoint("RIGHT", -6, 0); row.text:SetJustifyH("LEFT")
        row:Hide(); results[index] = row
    end
    local function HideResults() popup:Hide(); for _, row in ipairs(results) do row:Hide() end end
    local function UpdateResults()
        selectedSpellID = nil
        local matches = BuffAlerts.FindSpellMatches(addEdit:GetText(), #results)
        if #matches == 0 then HideResults() return end
        for index, row in ipairs(results) do
            local match = matches[index]
            if match then
                local id, name, icon = match.spellID, match.name, match.iconID
                row.icon:SetTexture(icon or 134400); row.text:SetText(name .. "  |cff888888(" .. id .. ")|r")
                row:SetScript("OnClick", function() addEdit:SetText(tostring(id)); selectedSpellID = id; addEdit:ClearFocus(); HideResults() end)
                row:Show()
            else row:Hide() end
        end
        popup:SetHeight(#matches * 28 + 4); popup:Show()
    end
    local function QueueSearch()
        generation = generation + 1; local current = generation
        C_Timer.After(.3, function() if current == generation and panel:IsShown() then BuffAlerts.SearchEncounterJournal(addEdit:GetText()) end end)
    end
    BuffAlerts.SetSearchUpdateCallback(function(query)
        if panel:IsShown() and addEdit:GetText():match("^%s*(.-)%s*$") == query then UpdateResults() end
    end)

    -- Alphabetical ability list.
    local listBox = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    listBox:SetPoint("TOPLEFT", 12, -268); listBox:SetPoint("BOTTOMLEFT", 12, 12); listBox:SetWidth(225)
    listBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    listBox:SetBackdropColor(.025, .025, .025, .75); listBox:SetBackdropBorderColor(.2, .2, .2, 1)
    local scroll = CreateFrame("ScrollFrame", nil, listBox, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -4); scroll:SetPoint("BOTTOMRIGHT", -24, 4)
    local child = CreateFrame("Frame", nil, scroll); child:SetSize(195, 1); scroll:SetScrollChild(child)
    local rows = {}

    -- Selected ability editor.
    local editor = CreateFrame("Frame", nil, panel); editor:SetPoint("TOPLEFT", listBox, "TOPRIGHT", 14, 0); editor:SetPoint("BOTTOMRIGHT", -12, 12)
    local empty = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); empty:SetPoint("CENTER", 0, 40); empty:SetTextColor(.55, .55, .55); empty:SetText("Select an ability to configure it")
    local spellIcon = editor:CreateTexture(nil, "ARTWORK"); spellIcon:SetSize(34, 34); spellIcon:SetPoint("TOPLEFT", 4, -4)
    local spellName = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); spellName:SetPoint("LEFT", spellIcon, "RIGHT", 8, 0); spellName:SetWidth(285); spellName:SetJustifyH("LEFT")
    local abilityEnabled = CreateFrame("CheckButton", nil, editor, "UICheckButtonTemplate"); abilityEnabled:SetPoint("TOPLEFT", 0, -48)
    abilityEnabled.text = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); abilityEnabled.text:SetPoint("LEFT", abilityEnabled, "RIGHT", 2, 0); abilityEnabled.text:SetText("Enabled")
    local delete = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate"); delete:SetSize(62, 22); delete:SetPoint("TOPRIGHT", -2, -8); delete:SetText("Delete")
    local ruleCategoryLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ruleCategoryLabel:SetPoint("TOPLEFT", 130, -57); ruleCategoryLabel:SetText("Category:")
    local ruleCategoryDD = CreateFrame("Frame", nil, editor, "UIDropDownMenuTemplate")
    ruleCategoryDD:SetPoint("TOPLEFT", 178, -48); UIDropDownMenu_SetWidth(ruleCategoryDD, 135)
    UIDropDownMenu_Initialize(ruleCategoryDD, function(_, level)
        if not selectedRule then return end
        local info = UIDropDownMenu_CreateInfo(); info.text = "Uncategorized"; info.checked = selectedRule.categoryID == nil
        info.func = function() selectedRule.categoryID = nil; UIDropDownMenu_SetText(ruleCategoryDD, "Uncategorized"); RefreshList() end
        UIDropDownMenu_AddButton(info, level)
        for _, category in ipairs(UIThingsDB.buffAlerts.categories or {}) do
            local id, name = category.id, category.name; info = UIDropDownMenu_CreateInfo(); info.text = name; info.checked = tostring(selectedRule.categoryID) == tostring(id)
            info.func = function() selectedRule.categoryID = id; UIDropDownMenu_SetText(ruleCategoryDD, name); RefreshList() end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    local soundDDs = {}
    local definitions = { { "applied", "Applied" }, { "stacks", "Stacks increased" }, { "removed", "Removed" } }
    for index, definition in ipairs(definitions) do
        local key, labelText, x = definition[1], definition[2], (index - 1) * 125
        local label = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); label:SetPoint("TOPLEFT", x + 3, -86); label:SetText(labelText)
        local dropdown = CreateFrame("Frame", nil, editor, "UIDropDownMenuTemplate"); dropdown:SetPoint("TOPLEFT", x - 14, -98); UIDropDownMenu_SetWidth(dropdown, 105)
        UIDropDownMenu_Initialize(dropdown, function(_, level)
            if not selectedRule then return end
            local setting = Sound(selectedRule, key)
            for _, option in ipairs(BuffAlerts.GetSoundOptions()) do
                local value, text = option.value, option.label
                local info = UIDropDownMenu_CreateInfo(); info.text = text; info.checked = setting.preset == value
                info.func = function() setting.preset = value; UIDropDownMenu_SetText(dropdown, BuffAlerts.GetSoundLabel(setting)); Apply() end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        local test = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate"); test:SetSize(38, 20); test:SetPoint("TOPLEFT", x + 36, -133); test:SetText("Test")
        test:SetScript("OnClick", function() if selectedRule then local ok, err = BuffAlerts.TestSound(Sound(selectedRule, key)); Status(ok and "Sound played." or err, not ok) end end)
        soundDDs[key] = dropdown
    end

    local copyLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); copyLabel:SetPoint("TOPLEFT", 3, -178); copyLabel:SetText("Copy sound settings and enabled state from:")
    local copyDD = CreateFrame("Frame", nil, editor, "UIDropDownMenuTemplate"); copyDD:SetPoint("TOPLEFT", -13, -191); UIDropDownMenu_SetWidth(copyDD, 185)
    UIDropDownMenu_Initialize(copyDD, function(_, level)
        if not selectedRule then return end
        local choices = {}
        for _, rule in ipairs(UIThingsDB.buffAlerts.rules or {}) do if rule ~= selectedRule then local info = C_Spell.GetSpellInfo(rule.spellID); choices[#choices + 1] = { rule, info and info.name or tostring(rule.spellID) } end end
        table.sort(choices, function(a, b) return a[2]:lower() < b[2]:lower() end)
        for _, choice in ipairs(choices) do
            local source, name = choice[1], choice[2]; local info = UIDropDownMenu_CreateInfo(); info.text = name; info.checked = selectedCopy == source
            info.func = function() selectedCopy = source; UIDropDownMenu_SetText(copyDD, name) end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    local copyButton = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate"); copyButton:SetSize(55, 22); copyButton:SetPoint("LEFT", copyDD, "RIGHT", -8, 2); copyButton:SetText("Copy")

    RefreshEditor = function()
        local shown = selectedRule ~= nil
        for _, childFrame in ipairs({ editor:GetChildren() }) do childFrame:SetShown(shown) end
        for _, region in ipairs({ editor:GetRegions() }) do region:SetShown(shown) end
        empty:SetShown(not shown)
        if not shown then return end
        local info = C_Spell.GetSpellInfo(selectedRule.spellID); spellIcon:SetTexture(info and info.iconID or 134400); spellName:SetText((info and info.name or "Unknown") .. "  |cff888888(" .. selectedRule.spellID .. ")|r")
        abilityEnabled:SetChecked(selectedRule.enabled ~= false)
        local category = FindCategory(selectedRule.categoryID); UIDropDownMenu_SetText(ruleCategoryDD, category and category.name or "Uncategorized")
        for key, dropdown in pairs(soundDDs) do UIDropDownMenu_SetText(dropdown, BuffAlerts.GetSoundLabel(Sound(selectedRule, key))) end
        selectedCopy = nil; UIDropDownMenu_SetText(copyDD, "Select ability")
    end

    RefreshList = function()
        for _, row in ipairs(rows) do row:Hide() end
        local entries, categoryRules, validCategories = {}, {}, {}
        for _, category in ipairs(UIThingsDB.buffAlerts.categories or {}) do validCategories[tostring(category.id)] = true; categoryRules[tostring(category.id)] = {} end
        categoryRules.uncategorized = {}
        for _, rule in ipairs(UIThingsDB.buffAlerts.rules or {}) do
            local info = C_Spell.GetSpellInfo(rule.spellID); local entry = { rule = rule, name = info and info.name or tostring(rule.spellID), icon = info and info.iconID }
            local key = rule.categoryID and tostring(rule.categoryID); table.insert(key and validCategories[key] and categoryRules[key] or categoryRules.uncategorized, entry)
        end
        local function SortRules(group) table.sort(group, function(a, b) local an, bn = a.name:lower(), b.name:lower(); if an == bn then return tonumber(a.rule.spellID) < tonumber(b.rule.spellID) end return an < bn end) end
        for _, category in ipairs(UIThingsDB.buffAlerts.categories or {}) do
            local group = categoryRules[tostring(category.id)]; SortRules(group); entries[#entries + 1] = { header = category.name, category = category }
            if not category.collapsed then for _, entry in ipairs(group) do entries[#entries + 1] = entry end end
        end
        SortRules(categoryRules.uncategorized)
        if #categoryRules.uncategorized > 0 then
            entries[#entries + 1] = { header = "Uncategorized", uncategorized = true }
            if not UIThingsDB.buffAlerts.uncategorizedCollapsed then for _, entry in ipairs(categoryRules.uncategorized) do entries[#entries + 1] = entry end end
        end
        local yOffset = 0
        for index, entry in ipairs(entries) do
            local row = rows[index]
            if not row then
                row = CreateFrame("Button", nil, child); row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                row.headerBg = row:CreateTexture(nil, "BACKGROUND"); row.headerBg:SetAllPoints(); row.headerBg:SetColorTexture(.12, .12, .12, .9)
                row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(25, 25); row.icon:SetPoint("LEFT", 3, 0)
                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.text:SetPoint("RIGHT", -3, 0); row.text:SetJustifyH("LEFT"); rows[index] = row
            end
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -yOffset); row:SetPoint("RIGHT", 0, 0); row.text:ClearAllPoints(); row.text:SetPoint("RIGHT", -3, 0)
            if entry.header then
                local collapsed
                if entry.uncategorized then
                    collapsed = UIThingsDB.buffAlerts.uncategorizedCollapsed == true
                else
                    collapsed = entry.category and entry.category.collapsed == true
                end
                row:SetHeight(24); row.icon:Hide(); row.headerBg:Show(); row.text:SetPoint("LEFT", 6, 0); row.text:SetText((collapsed and "[+] " or "[-] ") .. entry.header); row.text:SetTextColor(1, .82, 0)
                row:SetScript("OnClick", function()
                    if entry.uncategorized then UIThingsDB.buffAlerts.uncategorizedCollapsed = not UIThingsDB.buffAlerts.uncategorizedCollapsed
                    else entry.category.collapsed = not entry.category.collapsed end
                    RefreshList()
                end); row:Enable(); yOffset = yOffset + 25
            else
                local rule = entry.rule; row:SetHeight(32); row.icon:Show(); row.headerBg:Hide(); row.text:SetPoint("LEFT", row.icon, "RIGHT", 7, 0); row.icon:SetTexture(entry.icon or 134400); row.text:SetText(entry.name); row.text:SetTextColor(rule.enabled ~= false and .35 or .55, rule.enabled ~= false and 1 or .55, rule.enabled ~= false and .45 or .55)
                row:SetScript("OnClick", function() selectedRule = rule RefreshEditor() end); row:Enable(); yOffset = yOffset + 33
            end
            row:Show()
        end
        child:SetHeight(math.max(1, yOffset))
        if selectedRule then local exists = false; for _, rule in ipairs(UIThingsDB.buffAlerts.rules) do if rule == selectedRule then exists = true break end end; if not exists then selectedRule = nil end end
        RefreshEditor()
    end

    abilityEnabled:SetScript("OnClick", function(self) if selectedRule then selectedRule.enabled = self:GetChecked(); Apply(); RefreshList() end end)
    delete:SetScript("OnClick", function() if selectedRule then for index, rule in ipairs(UIThingsDB.buffAlerts.rules) do if rule == selectedRule then table.remove(UIThingsDB.buffAlerts.rules, index) break end end; selectedRule = nil; Apply(); RefreshList() end end)
    copyButton:SetScript("OnClick", function()
        if not selectedRule or not selectedCopy then Status("Select an ability to copy from.", true) return end
        selectedRule.enabled = selectedCopy.enabled ~= false; selectedRule.applied = Copy(Sound(selectedCopy, "applied")); selectedRule.stacks = Copy(Sound(selectedCopy, "stacks")); selectedRule.removed = Copy(Sound(selectedCopy, "removed"))
        Apply(); RefreshList(); Status("Ability settings copied.")
    end)

    local function AddSpell()
        local value = addEdit:GetText():match("^%s*(.-)%s*$"); local spellID = selectedSpellID or tonumber(value)
        if not spellID and value ~= "" and C_Spell.GetSpellIDForSpellIdentifier then local ok, resolved = pcall(C_Spell.GetSpellIDForSpellIdentifier, value); if ok then spellID = resolved end end
        if not spellID or spellID <= 0 or spellID % 1 ~= 0 then Status("Choose a matching buff/debuff or enter a valid Spell ID.", true) return end
        for _, rule in ipairs(UIThingsDB.buffAlerts.rules) do if tonumber(rule.spellID) == spellID then selectedRule = rule; RefreshList(); Status("That ability is already in the list.", true); return end end
        local rule = { spellID = spellID, enabled = true, applied = NewSound(), stacks = NewSound(), removed = NewSound() }
        UIThingsDB.buffAlerts.rules[#UIThingsDB.buffAlerts.rules + 1] = rule; selectedRule = rule; selectedSpellID = nil; addEdit:SetText(""); HideResults(); Apply(); RefreshList()
    end
    addButton:SetScript("OnClick", AddSpell); addEdit:SetScript("OnTextChanged", function() UpdateResults(); QueueSearch() end); addEdit:SetScript("OnEnterPressed", function(self) AddSpell(); self:ClearFocus() end); addEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); HideResults() end)
    enable:SetScript("OnClick", function(self) UIThingsDB.buffAlerts.enabled = self:GetChecked(); Apply() end)
    panel:SetScript("OnShow", function() enable:SetChecked(UIThingsDB.buffAlerts.enabled); BuffAlerts.ScanPlayerAuras(); BuffAlerts.IndexEncounterJournal(); BuffAlerts.MigrateLegacySounds(); RefreshCustom(); RefreshCategoryManager(); RefreshList(); Status() end)
    panel:SetScript("OnHide", HideResults)
    enable:SetChecked(UIThingsDB.buffAlerts.enabled); Nav(); RefreshCustom(); RefreshCategoryManager(); RefreshList()
end
