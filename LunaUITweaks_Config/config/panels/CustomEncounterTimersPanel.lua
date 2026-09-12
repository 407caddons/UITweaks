local addon = _G.LunaUITweaks
local Custom, H = addon.CustomEncounterTimers, addon.ConfigHelpers

function Custom.CreateEditor(parent, y)
    local root = CreateFrame("Frame", nil, parent)
    root:SetPoint("TOPLEFT", 0, y); root:SetSize(550, 1290)
    H.CreateSectionHeader(root, "Custom timer sets", 0)
    local function Label(text, x, offset, width)
        local f = root:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f:SetPoint("TOPLEFT", x, offset); f:SetWidth(width or 490); f:SetJustifyH("LEFT"); f:SetText(text)
        return f
    end
    local function Button(text, x, offset, callback)
        local f = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
        f:SetPoint("TOPLEFT", x, offset); f:SetSize(145, 26); f:SetText(text); f:SetScript("OnClick", callback)
        return f
    end
    Label("Create a set here to capture your current subzone. Timers run locally, only in combat, and use the normal/emphasized bars.", 20, -32)
    local selected, dirty, loading, confirmDelete
    local drafts = {}
    local setDD = CreateFrame("Frame", nil, root, "UIDropDownMenuTemplate")
    setDD:SetPoint("TOPLEFT", 4, -86); UIDropDownMenu_SetWidth(setDD, 290)
    local location = Label("", 20, -130)
    Label("Set name", 20, -184, 100)
    local name = CreateFrame("EditBox", nil, root, "InputBoxTemplate")
    name:SetPoint("TOPLEFT", 120, -180); name:SetSize(380, 26); name:SetAutoFocus(false); name:SetMaxLetters(80)
    local enabled = CreateFrame("CheckButton", nil, root, "ChatConfigCheckButtonTemplate")
    enabled:SetPoint("TOPLEFT", 20, -220); enabled.Text:SetText("Enable this set")
    Label("Start on", 20, -272, 100)
    local triggerDD = CreateFrame("Frame", nil, root, "UIDropDownMenuTemplate")
    triggerDD:SetPoint("TOPLEFT", 104, -262); UIDropDownMenu_SetWidth(triggerDD, 230)
    local trigger = "combat"
    Label("Timers — select one to edit its timing, colour and countdown", 20, -305)
    local scroll = CreateFrame("ScrollFrame", nil, root, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 24, -945); scroll:SetSize(455, 220); scroll:Hide()
    local text = CreateFrame("EditBox", nil, scroll)
    text:SetMultiLine(true); text:SetAutoFocus(false); text:SetFontObject("ChatFontNormal")
    text:SetWidth(445); text:SetHeight(220); text:SetMaxLetters(16000)
    text:SetTextInsets(6, 6, 6, 6); scroll:SetScrollChild(text)
    local bg = scroll:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.025, 0.04, 0.05, 1)
    scroll:EnableMouse(true); scroll:SetScript("OnMouseDown", function() text:SetFocus() end)
    text:SetScript("OnCursorChanged", function(_, _, cursorY, _, height)
        local offset = scroll:GetVerticalScroll()
        local top = -cursorY
        if top < offset then scroll:SetVerticalScroll(math.max(0, top))
        elseif top + height > offset + scroll:GetHeight() then
            scroll:SetVerticalScroll(top + height - scroll:GetHeight())
        end
    end)
    local message = Label("", 20, -842)
    local rules, timerIndex, timerDirty, importDirty = {}, nil, false, false
    local list = CreateFrame("ScrollFrame", nil, root, "UIPanelScrollFrameTemplate")
    list:SetPoint("TOPLEFT", 20, -335); list:SetSize(455, 140)
    local listChild = CreateFrame("Frame", nil, list); listChild:SetSize(455, 1); list:SetScrollChild(listChild)
    local timerRows = {}
    local function Edit(label, x, offset, width)
        Label(label, x, offset, width)
        local f = CreateFrame("EditBox", nil, root, "InputBoxTemplate")
        f:SetPoint("TOPLEFT", x + 4, offset - 24); f:SetSize(width, 26); f:SetAutoFocus(false)
        f:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        f:SetScript("OnTextChanged", function(_, userInput) if userInput and timerIndex then timerDirty = true end end)
        return f
    end
    local timerTitle = Edit("Timer title", 20, -490, 470); timerTitle:SetMaxLetters(200)
    local firstDelay = Edit("First delay (20 or 2:20)", 20, -550, 210)
    local interval = Edit("Repeat every (blank = once)", 270, -550, 220)
    local countdownDD = CreateFrame("Frame", nil, root, "UIDropDownMenuTemplate")
    countdownDD:SetPoint("TOPLEFT", 4, -615); UIDropDownMenu_SetWidth(countdownDD, 270)
    local countdownMode = "default"
    local defaultColor = CreateFrame("CheckButton", nil, root, "ChatConfigCheckButtonTemplate")
    defaultColor:SetPoint("TOPLEFT", 20, -660); defaultColor.Text:SetText("Use default colour")
    defaultColor:SetScript("OnClick", function() if timerIndex then timerDirty = true end end)
    local editColor = {r=1,g=1,b=1}
    local colorSwatch = H.CreateColorSwatch(root, "Override colour", editColor, function()
        if timerIndex then defaultColor:SetChecked(false); timerDirty = true end
    end, 280, -665, false)
    local ownsPicker = false
    if colorSwatch then colorSwatch:HookScript("OnClick", function() ownsPicker = true end) end
    local RefreshTimers, LoadTimer, ApplyTimer
    local function MarkDirty()
        if selected and not loading then dirty = true; confirmDelete = nil; message:SetText("Unsaved changes — click Save to apply. Drafts are kept while switching sets.") end
    end
    local function OnTextChanged(_, userInput)
        if userInput then MarkDirty() end
    end
    name:SetScript("OnTextChanged", OnTextChanged)
    text:SetScript("OnTextChanged", function(_, userInput) if userInput then importDirty = true end end)
    name:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    text:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    enabled:SetScript("OnClick", MarkDirty)
    local function FindSelected()
        for _, set in ipairs(Custom.GetSets()) do if set.id == selected then return set end end
    end
    local function SyncText()
        text:SetText(Custom.Serialize(rules)); importDirty = false; MarkDirty()
    end
    LoadTimer = function(index)
        if ownsPicker and ColorPickerFrame then ColorPickerFrame:Hide() end
        ownsPicker = false
        timerIndex = index; local rule = rules[index]
        timerTitle:SetText(rule and rule.name or "")
        firstDelay:SetText(rule and Custom.FormatTime(rule.first) or "")
        interval:SetText(rule and rule.interval and Custom.FormatTime(rule.interval) or "")
        countdownMode = "default"
        if rule and rule.countdown ~= nil then countdownMode = rule.countdown and "on" or "off" end
        UIDropDownMenu_SetText(countdownDD, "Countdown: " .. countdownMode)
        defaultColor:SetChecked(not rule or not rule.color)
        local color = rule and rule.color or UIThingsDB.encounterBars.customColor
        editColor.r, editColor.g, editColor.b = color.r, color.g, color.b
        if colorSwatch then colorSwatch.tex:SetColorTexture(color.r,color.g,color.b,1); colorSwatch:SetEnabled(rule ~= nil) end
        timerTitle:SetEnabled(rule ~= nil); firstDelay:SetEnabled(rule ~= nil); interval:SetEnabled(rule ~= nil)
        timerDirty = false
    end
    ApplyTimer = function()
        if not timerDirty then return true end
        local first = Custom.ParseTime(firstDelay:GetText())
        local repeatText = interval:GetText():match("^%s*(.-)%s*$")
        local repeatEvery = repeatText ~= "" and Custom.ParseTime(repeatText) or nil
        local title = timerTitle:GetText():match("^%s*(.-)%s*$")
        if not first or (repeatText ~= "" and not repeatEvery) or title == "" or title:find("[\r\n]") then
            message:SetText("Enter a title and valid times (1–3600 seconds). Leave Repeat blank for a one-off timer."); return false
        end
        local rule = {name=title, first=first, interval=repeatEvery}
        if countdownMode ~= "default" then rule.countdown = countdownMode == "on" end
        if not defaultColor:GetChecked() then rule.color = {r=editColor.r,g=editColor.g,b=editColor.b} end
        rules[timerIndex] = rule; timerDirty = false; SyncText(); RefreshTimers()
        return true
    end
    RefreshTimers = function()
        for i, rule in ipairs(rules) do
            local row = timerRows[i]
            if not row then
                row = CreateFrame("Button", nil, listChild); row:SetSize(450, 30)
                row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.label:SetPoint("LEFT", 6, 0); row.label:SetWidth(438); row.label:SetJustifyH("LEFT"); row.label:SetWordWrap(false)
                row:SetScript("OnClick", function()
                    if importDirty then message:SetText("Import or discard the text edits first."); return end
                    if ApplyTimer() then LoadTimer(i); RefreshTimers() end
                end)
                timerRows[i] = row
            end
            local color = rule.color or UIThingsDB.encounterBars.customColor
            row.label:SetTextColor(color.r,color.g,color.b)
            row.label:SetText((timerIndex == i and "> " or "") .. rule.name .. " · " .. Custom.FormatTime(rule.first)
                .. (rule.interval and (" / repeat " .. Custom.FormatTime(rule.interval)) or ""))
            row:SetPoint("TOPLEFT", 0, -(i-1)*30); row:Show()
        end
        for i=#rules+1,#timerRows do timerRows[i]:Hide() end
        listChild:SetHeight(math.max(1,#rules*30))
    end
    UIDropDownMenu_Initialize(countdownDD, function(_, level)
        for _, mode in ipairs({"default","on","off"}) do
            local item=UIDropDownMenu_CreateInfo(); item.text="Countdown: "..mode; item.checked=countdownMode==mode
            item.func=function() if timerIndex then countdownMode=mode; timerDirty=true; UIDropDownMenu_SetText(countdownDD,item.text) end end
            UIDropDownMenu_AddButton(item,level)
        end
    end)
    local function Select(set)
        if importDirty then message:SetText("Import or discard the text edits first."); return false end
        if not ApplyTimer() then return false end
        if selected and dirty then
            drafts[selected] = { name = name:GetText(), text = text:GetText(),
                enabled = not not enabled:GetChecked(), trigger = trigger }
        end
        loading = true; selected = set and set.id; confirmDelete = nil
        local values = set and (drafts[set.id] or set)
        UIDropDownMenu_SetText(setDD, set and ((set.enabled and "|cff55ddaa" or "|cff888888") .. set.name .. " #" .. set.id .. "|r") or "Select a timer set")
        name:SetText(values and values.name or ""); text:SetText(values and values.text or "")
        enabled:SetChecked(values and values.enabled or false)
        trigger = values and values.trigger or "combat"
        UIDropDownMenu_SetText(triggerDD, trigger == "combat" and "Combat start" or "Encounter start")
        location:SetText(set and ("Location: " .. Custom.LocationLabel(set.location)) or "Click Add current subzone to create a timer set.")
        name:SetEnabled(set ~= nil); text:SetEnabled(set ~= nil); enabled:SetEnabled(set ~= nil)
        scroll:SetVerticalScroll(0); loading = false; dirty = selected and drafts[selected] ~= nil or false
        message:SetText(dirty and "Unsaved draft restored — click Save to apply." or "")
        local parsed, err = Custom.Parse(values and values.text or "")
        rules = parsed or {}; LoadTimer(#rules > 0 and 1 or nil); RefreshTimers()
        if values and values.text ~= "" and not parsed then scroll:Show(); importDirty=true; message:SetText(err) end
        return true
    end
    UIDropDownMenu_Initialize(setDD, function(_, level)
        for _, set in ipairs(Custom.GetSets()) do
            local item = UIDropDownMenu_CreateInfo()
            item.text = (set.enabled and "|cff55ddaa" or "|cff888888") .. set.name .. " #" .. set.id .. "|r"
            item.checked = selected == set.id; item.func = function() Select(set) end
            UIDropDownMenu_AddButton(item, level)
        end
    end)
    UIDropDownMenu_Initialize(triggerDD, function(_, level)
        for _, value in ipairs({ "combat", "encounter" }) do
            local item = UIDropDownMenu_CreateInfo()
            item.text = value == "combat" and "Combat start" or "Encounter start"
            item.checked = trigger == value
            item.func = function() trigger = value; UIDropDownMenu_SetText(triggerDD, item.text); MarkDirty() end
            UIDropDownMenu_AddButton(item, level)
        end
    end)
    Button("Add current subzone", 350, -86, function()
        if importDirty or not ApplyTimer() then message:SetText("Apply timer edits or import/discard text edits first."); return end
        local set, err = Custom.AddSet()
        if not set then message:SetText(err); return end
        Select(set); message:SetText("Enter your schedule, enable the set, then click Save.")
        name:SetFocus(); name:HighlightText()
    end)
    Button("Save", 20, -800, function()
        if not selected then message:SetText("Create or select a timer set first."); return end
        if importDirty then message:SetText("Click Import text first, or Discard text edits."); return end
        if not ApplyTimer() then return end
        local ok, err = Custom.SaveSet(selected, name:GetText(), trigger, not not enabled:GetChecked(), text:GetText())
        if not ok then message:SetText(err); return end
        drafts[selected] = nil; dirty = false; Select(FindSelected()); addon.EncounterBars.UpdateSettings()
        name:ClearFocus(); text:ClearFocus(); message:SetText("Saved. Changes apply on the next matching combat/encounter start.")
    end)
    Button("Revert", 180, -800, function()
        if selected then drafts[selected] = nil end
        dirty = false; timerDirty = false; importDirty = false; Select(FindSelected())
    end)
    Button("Delete set", 340, -800, function()
        if not selected then return end
        if confirmDelete ~= selected then
            confirmDelete = selected; message:SetText("Click Delete set again to permanently remove this set."); return
        end
        Custom.DeleteSet(selected); drafts[selected] = nil; dirty = false; timerDirty = false; importDirty = false; Select(nil); addon.EncounterBars.UpdateSettings()
    end)
    Button("Add timer",20,-705,function()
        if not selected or importDirty or not ApplyTimer() then return end
        if #rules>=100 then message:SetText("Maximum 100 timers per set."); return end
        rules[#rules+1]={name="New timer",first=20}; SyncText(); LoadTimer(#rules); RefreshTimers()
        timerTitle:SetFocus(); timerTitle:HighlightText()
    end)
    Button("Duplicate timer",180,-705,function()
        if not timerIndex or importDirty or not ApplyTimer() then return end
        if #rules>=100 then message:SetText("Maximum 100 timers per set."); return end
        local copy=Custom.Parse(Custom.Serialize({rules[timerIndex]}))
        rules[#rules+1]=copy[1]; SyncText(); LoadTimer(#rules); RefreshTimers()
    end)
    Button("Delete timer",340,-705,function()
        if not timerIndex or importDirty then return end
        table.remove(rules,timerIndex); timerDirty=false; SyncText(); LoadTimer(#rules>0 and math.min(timerIndex,#rules) or nil); RefreshTimers()
    end)
    Button("Apply timer edits",20,-750,function() if not importDirty then ApplyTimer() end end)
    Label("Countdown default follows Encounter / custom 5–1 audio. On overrides it; Off silences this timer.",180,-750,320)
    Button("Text import / export",20,-900,function()
        if importDirty or ApplyTimer() then scroll:SetShown(not scroll:IsShown()) end
    end)
    Button("Import text",180,-900,function()
        if not selected then return end
        local parsed,err=Custom.Parse(text:GetText())
        if not parsed then message:SetText(err); return end
        rules=parsed; timerDirty=false; importDirty=false; MarkDirty(); LoadTimer(1); RefreshTimers()
        message:SetText("Text imported into this draft. Click Save to keep it.")
    end)
    Button("Discard text edits",340,-900,function() text:SetText(Custom.Serialize(rules)); importDirty=false end)
    H.CreateColorSwatch(root, "Custom timer colour", UIThingsDB.encounterBars.customColor,
        addon.EncounterBars.UpdateSettings, 20, -1230)
    root:SetScript("OnHide", function()
        name:ClearFocus(); text:ClearFocus(); timerTitle:ClearFocus(); firstDelay:ClearFocus(); interval:ClearFocus()
        if ownsPicker and ColorPickerFrame then ColorPickerFrame:Hide() end
        ownsPicker = false
    end)
    root:SetScript("OnShow", function()
        if selected and not FindSelected() then dirty = false; timerDirty=false; importDirty=false; Select(nil) end
    end)
    Select(nil)
    return root
end
