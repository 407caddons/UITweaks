local addonName, addonTable = ...

addonTable.ConfigSetup = addonTable.ConfigSetup or {}

local Helpers = addonTable.ConfigHelpers

function addonTable.ConfigSetup.QuestReminder(panel, tab, configWindow)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Quest Reminders")

    -- Enable Checkbox
    local enableBtn = CreateFrame("CheckButton", "UIThingsQuestReminderEnableCheck", panel,
        "ChatConfigCheckButtonTemplate")
    enableBtn:SetPoint("TOPLEFT", 20, -50)
    _G[enableBtn:GetName() .. "Text"]:SetText("Enable Quest Reminders")
    enableBtn:SetChecked(UIThingsDB.questReminder.enabled)
    enableBtn:SetScript("OnClick", function(self)
        local enabled = not not self:GetChecked()
        UIThingsDB.questReminder.enabled = enabled
        Helpers.UpdateModuleVisuals(panel, tab, enabled)
        if addonTable.QuestReminder and addonTable.QuestReminder.UpdateSettings then
            addonTable.QuestReminder.UpdateSettings()
        end
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.questReminder.enabled)

    -- Help text
    local enableText = _G[enableBtn:GetName() .. "Text"]
    local helpText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    helpText:SetPoint("LEFT", enableText, "RIGHT", 10, 0)
    helpText:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
    helpText:SetJustifyH("LEFT")
    helpText:SetTextColor(0.6, 0.6, 0.6)
    helpText:SetText(
        "Automatically tracks daily/weekly quests you accept and reminds you on login if they are incomplete.")

    -- ============================================================
    -- Alert Settings Section
    -- ============================================================
    Helpers.CreateSectionHeader(panel, "Alert Settings", -80)

    local showPopupCheck = CreateFrame("CheckButton", "UIThingsQuestReminderPopupCheck", panel,
        "ChatConfigCheckButtonTemplate")
    showPopupCheck:SetPoint("TOPLEFT", 20, -105)
    showPopupCheck:SetHitRectInsets(0, -110, 0, 0)
    _G[showPopupCheck:GetName() .. "Text"]:SetText("Show Popup Alert")
    showPopupCheck:SetChecked(UIThingsDB.questReminder.showPopup)
    showPopupCheck:SetScript("OnClick", function(self)
        UIThingsDB.questReminder.showPopup = not not self:GetChecked()
    end)

    local showChatCheck = CreateFrame("CheckButton", "UIThingsQuestReminderChatCheck", panel,
        "ChatConfigCheckButtonTemplate")
    showChatCheck:SetPoint("TOPLEFT", 200, -105)
    showChatCheck:SetHitRectInsets(0, -120, 0, 0)
    _G[showChatCheck:GetName() .. "Text"]:SetText("Show Chat Message")
    showChatCheck:SetChecked(UIThingsDB.questReminder.showChatMessage)
    showChatCheck:SetScript("OnClick", function(self)
        UIThingsDB.questReminder.showChatMessage = not not self:GetChecked()
    end)

    local playSoundCheck = CreateFrame("CheckButton", "UIThingsQuestReminderSoundCheck", panel,
        "ChatConfigCheckButtonTemplate")
    playSoundCheck:SetPoint("TOPLEFT", 20, -130)
    playSoundCheck:SetHitRectInsets(0, -80, 0, 0)
    _G[playSoundCheck:GetName() .. "Text"]:SetText("Play Sound")
    playSoundCheck:SetChecked(UIThingsDB.questReminder.playSound)
    playSoundCheck:SetScript("OnClick", function(self)
        UIThingsDB.questReminder.playSound = not not self:GetChecked()
    end)

    -- ============================================================
    -- TTS Section
    -- ============================================================
    Helpers.CreateSectionHeader(panel, "Text-To-Speech", -155)

    local ttsEnableBtn = CreateFrame("CheckButton", "UIThingsQuestReminderTTSEnable", panel,
        "ChatConfigCheckButtonTemplate")
    ttsEnableBtn:SetPoint("TOPLEFT", 20, -180)
    _G[ttsEnableBtn:GetName() .. "Text"]:SetText("Enable Text-To-Speech")
    ttsEnableBtn:SetChecked(UIThingsDB.questReminder.ttsEnabled)
    ttsEnableBtn:SetScript("OnClick", function(self)
        UIThingsDB.questReminder.ttsEnabled = not not self:GetChecked()
    end)

    -- TTS Message
    local ttsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ttsLabel:SetPoint("TOPLEFT", 40, -215)
    ttsLabel:SetText("TTS Message:")

    local ttsEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    ttsEdit:SetSize(250, 20)
    ttsEdit:SetPoint("LEFT", ttsLabel, "RIGHT", 10, 0)
    ttsEdit:SetAutoFocus(false)
    ttsEdit:SetText(UIThingsDB.questReminder.ttsMessage or "You've got quests")
    ttsEdit:SetScript("OnEnterPressed", function(self)
        UIThingsDB.questReminder.ttsMessage = self:GetText()
        self:ClearFocus()
    end)
    ttsEdit:SetScript("OnEditFocusLost", function(self)
        UIThingsDB.questReminder.ttsMessage = self:GetText()
    end)

    -- Test Button
    local testTTSBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testTTSBtn:SetSize(60, 22)
    testTTSBtn:SetPoint("LEFT", ttsEdit, "RIGHT", 5, 0)
    testTTSBtn:SetText("Test")
    testTTSBtn:SetScript("OnClick", function()
        UIThingsDB.questReminder.ttsMessage = ttsEdit:GetText()
        if addonTable.QuestReminder and addonTable.QuestReminder.TestPopup then
            addonTable.QuestReminder.TestPopup()
        end
    end)

    -- TTS Voice Dropdown
    local voiceLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    voiceLabel:SetPoint("TOPLEFT", 40, -255)
    voiceLabel:SetText("Voice Type:")

    local voiceDropdown = CreateFrame("Frame", "UIThingsQuestReminderVoiceDropdown", panel, "UIDropDownMenuTemplate")
    voiceDropdown:SetPoint("LEFT", voiceLabel, "RIGHT", -10, -2)
    UIDropDownMenu_SetWidth(voiceDropdown, 150)

    local voiceOptions = {
        { text = "Standard",  value = 0 },
        { text = "Alternate", value = 1 },
    }

    UIDropDownMenu_Initialize(voiceDropdown, function(self, level)
        for _, option in ipairs(voiceOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function(btn)
                UIThingsDB.questReminder.ttsVoice = btn.value
                UIDropDownMenu_SetSelectedValue(voiceDropdown, btn.value)
            end
            info.checked = (UIThingsDB.questReminder.ttsVoice == option.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetSelectedValue(voiceDropdown, UIThingsDB.questReminder.ttsVoice or 0)

    -- ============================================================
    -- Popup Appearance Section
    -- ============================================================
    Helpers.CreateSectionHeader(panel, "Popup Appearance", -290)

    local function UpdatePopupVisuals()
        if addonTable.QuestReminder and addonTable.QuestReminder.UpdateVisuals then
            addonTable.QuestReminder.UpdateVisuals()
        end
    end

    -- Row 1: Border
    local borderCheckbox = CreateFrame("CheckButton", "UIThingsQuestReminderBorderCheck", panel,
        "ChatConfigCheckButtonTemplate")
    borderCheckbox:SetPoint("TOPLEFT", 20, -315)
    borderCheckbox:SetHitRectInsets(0, -80, 0, 0)
    _G[borderCheckbox:GetName() .. "Text"]:SetText("Show Border")
    borderCheckbox:SetChecked(UIThingsDB.questReminder.showBorder)
    borderCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.questReminder.showBorder = not not self:GetChecked()
        UpdatePopupVisuals()
    end)

    Helpers.CreateColorSwatch(panel, "Color:",
        UIThingsDB.questReminder.borderColor,
        UpdatePopupVisuals, 140, -318)

    -- Row 2: Background
    local bgCheckbox = CreateFrame("CheckButton", "UIThingsQuestReminderBgCheck", panel,
        "ChatConfigCheckButtonTemplate")
    bgCheckbox:SetPoint("TOPLEFT", 20, -340)
    bgCheckbox:SetHitRectInsets(0, -110, 0, 0)
    _G[bgCheckbox:GetName() .. "Text"]:SetText("Show Background")
    bgCheckbox:SetChecked(UIThingsDB.questReminder.showBackground)
    bgCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.questReminder.showBackground = not not self:GetChecked()
        UpdatePopupVisuals()
    end)

    Helpers.CreateColorSwatch(panel, "Color:",
        UIThingsDB.questReminder.backgroundColor,
        UpdatePopupVisuals, 165, -343)

    -- Width Slider
    local widthSlider = CreateFrame("Slider", "UIThingsQuestReminderWidthSlider", panel, "OptionsSliderTemplate")
    widthSlider:SetPoint("TOPLEFT", 20, -385)
    widthSlider:SetMinMaxValues(250, 600)
    widthSlider:SetValueStep(10)
    widthSlider:SetObeyStepOnDrag(true)
    widthSlider:SetWidth(150)
    _G[widthSlider:GetName() .. "Text"]:SetText(string.format("Width: %d",
        UIThingsDB.questReminder.frameWidth or 350))
    _G[widthSlider:GetName() .. "Low"]:SetText("250")
    _G[widthSlider:GetName() .. "High"]:SetText("600")
    widthSlider:SetValue(UIThingsDB.questReminder.frameWidth or 350)
    widthSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.questReminder.frameWidth = value
        _G[self:GetName() .. "Text"]:SetText(string.format("Width: %d", value))
        UpdatePopupVisuals()
    end)

    -- Height Slider
    local heightSlider = CreateFrame("Slider", "UIThingsQuestReminderHeightSlider", panel, "OptionsSliderTemplate")
    heightSlider:SetPoint("TOPLEFT", 200, -385)
    heightSlider:SetMinMaxValues(150, 500)
    heightSlider:SetValueStep(10)
    heightSlider:SetObeyStepOnDrag(true)
    heightSlider:SetWidth(150)
    _G[heightSlider:GetName() .. "Text"]:SetText(string.format("Height: %d",
        UIThingsDB.questReminder.frameHeight or 250))
    _G[heightSlider:GetName() .. "Low"]:SetText("150")
    _G[heightSlider:GetName() .. "High"]:SetText("500")
    heightSlider:SetValue(UIThingsDB.questReminder.frameHeight or 250)
    heightSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        UIThingsDB.questReminder.frameHeight = value
        _G[self:GetName() .. "Text"]:SetText(string.format("Height: %d", value))
        UpdatePopupVisuals()
    end)

    -- ============================================================
    -- Tracked Quests Section
    -- ============================================================
    Helpers.CreateSectionHeader(panel, "Tracked Quests", -410)

    -- Clear All Button
    local clearAllBtn = CreateFrame("Button", nil, panel, "GameMenuButtonTemplate")
    clearAllBtn:SetSize(120, 25)
    clearAllBtn:SetPoint("TOPLEFT", 20, -435)
    clearAllBtn:SetText("Clear All")
    clearAllBtn:SetNormalFontObject("GameFontNormal")
    clearAllBtn:SetHighlightFontObject("GameFontHighlight")
    clearAllBtn:SetScript("OnClick", function()
        StaticPopup_Show("LUNA_QUEST_REMINDER_CLEAR_ALL")
    end)

    StaticPopupDialogs["LUNA_QUEST_REMINDER_CLEAR_ALL"] = {
        text =
        "Remove ALL tracked repeatable quests?\n\n|cFFAAAAAAAAThis is useful at expansion boundaries when old quests are no longer relevant.|r",
        button1 = "Clear All",
        button2 = "Cancel",
        OnAccept = function()
            if addonTable.QuestReminder and addonTable.QuestReminder.ClearAll then
                addonTable.QuestReminder.ClearAll()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    -- Quest count label
    local questCountLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    questCountLabel:SetPoint("LEFT", clearAllBtn, "RIGHT", 10, 0)
    questCountLabel:SetTextColor(0.6, 0.6, 0.6)

    -- Scroll frame for tracked quests
    local questScrollFrame = CreateFrame("ScrollFrame", "UIThingsQuestReminderScroll", panel,
        "UIPanelScrollFrameTemplate")
    questScrollFrame:SetPoint("TOPLEFT", 20, -465)
    questScrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 10)

    local questContent = CreateFrame("Frame", nil, questScrollFrame)
    questContent:SetSize(500, 1)
    questScrollFrame:SetScrollChild(questContent)

    -- Row pool
    local questRows = {}

    local function RefreshQuestList()
        -- Hide all rows
        for _, row in ipairs(questRows) do
            row:Hide()
        end

        local tracked = LunaUITweaks_QuestReminders and LunaUITweaks_QuestReminders.quests
        if not tracked then
            questCountLabel:SetText("0 quests tracked")
            questContent:SetHeight(1)
            return
        end

        -- Collect and sort quests
        local sortedQuests = {}
        for questID, data in pairs(tracked) do
            table.insert(sortedQuests, { questID = questID, data = data })
        end

        questCountLabel:SetText(#sortedQuests .. " quest(s) tracked")

        table.sort(sortedQuests, function(a, b)
            if a.data.frequency ~= b.data.frequency then
                return a.data.frequency == "daily"
            end
            return (a.data.name or "") < (b.data.name or "")
        end)

        local yOffset = -5
        for i, entry in ipairs(sortedQuests) do
            local row = questRows[i]
            if not row then
                row = CreateFrame("Frame", nil, questContent)
                row:SetSize(480, 30)

                row.bg = row:CreateTexture(nil, "BACKGROUND")
                row.bg:SetAllPoints()
                row.bg:SetColorTexture(0, 0, 0, 0)

                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.text:SetPoint("LEFT", 5, 0)
                row.text:SetWidth(310)
                row.text:SetJustifyH("LEFT")

                row.perCharCheck = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                row.perCharCheck:SetPoint("RIGHT", -70, 0)
                row.perCharCheck:SetSize(20, 20)
                row.perCharCheck:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Per-Character", 1, 1, 1)
                    GameTooltip:AddLine(
                        "Ignore warband completion.\nRemind on this character even if\nanother character completed it.",
                        0.7, 0.7, 0.7, true)
                    GameTooltip:Show()
                end)
                row.perCharCheck:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)

                row.removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.removeBtn:SetSize(60, 22)
                row.removeBtn:SetPoint("RIGHT", -5, 0)
                row.removeBtn:SetText("Remove")
                row.removeBtn:SetNormalFontObject("GameFontNormalSmall")

                questRows[i] = row
            end

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, yOffset)

            -- Frequency prefix
            local prefix
            if entry.data.frequency == "daily" then
                prefix = "|cFF00CCFF[D]|r"
            else
                prefix = "|cFFCC00FF[W]|r"
            end

            -- Completion status (check both character and account/warband)
            local completed = C_QuestLog.IsQuestFlaggedCompleted(entry.questID)
                or (not entry.data.ignoreWarband
                    and C_QuestLog.IsQuestFlaggedCompletedOnAccount
                    and C_QuestLog.IsQuestFlaggedCompletedOnAccount(entry.questID))
            local nameColor = completed and "|cFF666666" or "|cFFFFAA00"

            row.text:SetText(string.format("%s %s%s|r |cFF888888- %s|r",
                prefix, nameColor, entry.data.name, entry.data.zoneName or "Unknown"))

            if completed then
                row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.2)
            else
                row.bg:SetColorTexture(0, 0, 0, 0)
            end

            -- Per-character checkbox
            row.perCharCheck:SetChecked(entry.data.ignoreWarband or false)
            row.perCharCheck:SetScript("OnClick", function(self)
                entry.data.ignoreWarband = not not self:GetChecked()
            end)
            row.perCharCheck:Show()

            -- Remove button
            row.removeBtn.questID = entry.questID
            row.removeBtn:SetScript("OnClick", function(self)
                if addonTable.QuestReminder and addonTable.QuestReminder.RemoveQuest then
                    addonTable.QuestReminder.RemoveQuest(self.questID)
                end
            end)

            row:Show()
            yOffset = yOffset - 32
        end

        -- Empty state
        if #sortedQuests == 0 then
            local row = questRows[1]
            if not row then
                row = CreateFrame("Frame", nil, questContent)
                row:SetSize(480, 30)

                row.bg = row:CreateTexture(nil, "BACKGROUND")
                row.bg:SetAllPoints()
                row.bg:SetColorTexture(0, 0, 0, 0)

                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.text:SetPoint("LEFT", 5, 0)
                row.text:SetWidth(310)
                row.text:SetJustifyH("LEFT")

                row.perCharCheck = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                row.perCharCheck:SetPoint("RIGHT", -70, 0)
                row.perCharCheck:SetSize(20, 20)

                row.removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.removeBtn:SetSize(60, 22)
                row.removeBtn:SetPoint("RIGHT", -5, 0)
                row.removeBtn:SetText("Remove")
                row.removeBtn:SetNormalFontObject("GameFontNormalSmall")

                questRows[1] = row
            end
            row:SetSize(480, 60)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -5)
            row.text:SetText(
                "|cFFAAAAAANo quests tracked yet.\n\nAccept a daily or weekly quest and it will automatically appear here.|r")
            row.perCharCheck:Hide()
            row.removeBtn:Hide()
            row.bg:SetColorTexture(0, 0, 0, 0)
            row:Show()
            yOffset = -65
        end

        questContent:SetHeight(math.max(1, math.abs(yOffset) + 5))
    end

    -- Store refresh function for external access
    addonTable.Config.RefreshQuestReminderList = RefreshQuestList

    -- Initial render
    RefreshQuestList()
end
