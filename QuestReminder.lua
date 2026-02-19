local addonName, addonTable = ...
addonTable.QuestReminder = {}

local QuestReminder = addonTable.QuestReminder
local Log = addonTable.Core.Log
local LogLevel = addonTable.Core.LogLevel
local popupFrame -- alert popup

-- ============================================================
-- Initialization
-- ============================================================

function QuestReminder.Initialize()
    LunaUITweaks_QuestReminders = LunaUITweaks_QuestReminders or { quests = {} }

    QuestReminder.CreatePopupFrame()

    QuestReminder.ApplyEvents()
end

function QuestReminder.ApplyEvents()
    local EventBus = addonTable.EventBus
    if UIThingsDB.questReminder and UIThingsDB.questReminder.enabled then
        EventBus.Register("PLAYER_ENTERING_WORLD", QuestReminder.OnEnteringWorldEvent)
        EventBus.Register("QUEST_ACCEPTED", QuestReminder.OnQuestAcceptedEvent)
    else
        EventBus.Unregister("PLAYER_ENTERING_WORLD", QuestReminder.OnEnteringWorldEvent)
        EventBus.Unregister("QUEST_ACCEPTED", QuestReminder.OnQuestAcceptedEvent)
        if popupFrame and popupFrame:IsShown() then
            popupFrame:Hide()
        end
    end
end

-- ============================================================
-- Event Handler
-- ============================================================

function QuestReminder.OnEnteringWorldEvent(event, isLogin, isReload)
    if isLogin then
        addonTable.Core.SafeAfter(5, QuestReminder.CheckQuestsOnLogin)
    end
end

function QuestReminder.OnQuestAcceptedEvent(event, questID)
    QuestReminder.OnQuestAccepted(questID)
end

-- ============================================================
-- Quest Accepted — Auto-Track Repeatables
-- ============================================================

function QuestReminder.OnQuestAccepted(questID)
    if not questID then return end

    -- Already tracked
    if LunaUITweaks_QuestReminders.quests[questID] then return end

    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    if not logIndex then return end

    local info = C_QuestLog.GetInfo(logIndex)
    if not info then return end

    -- Determine frequency
    local frequency = nil
    if info.frequency == Enum.QuestFrequency.Daily then
        frequency = "daily"
    elseif info.frequency == Enum.QuestFrequency.Weekly then
        frequency = "weekly"
    elseif C_QuestLog.IsRepeatableQuest and C_QuestLog.IsRepeatableQuest(questID) then
        frequency = "weekly"
    end

    if not frequency then return end

    -- Get zone info
    local mapID = C_Map.GetBestMapForUnit("player") or 0
    local mapInfo = mapID ~= 0 and C_Map.GetMapInfo(mapID) or nil

    LunaUITweaks_QuestReminders.quests[questID] = {
        name = info.title or C_QuestLog.GetTitleForQuestID(questID) or "Unknown Quest",
        frequency = frequency,
        zoneID = mapID,
        zoneName = mapInfo and mapInfo.name or "Unknown",
        addedTime = time(),
    }

    Log("QuestReminder", "Tracking " .. frequency .. " quest: " .. (info.title or questID), LogLevel.INFO)

    -- Refresh config list if open
    if addonTable.Config and addonTable.Config.RefreshQuestReminderList then
        addonTable.Config.RefreshQuestReminderList()
    end
end

-- ============================================================
-- Login Check — Show Incomplete Quests
-- ============================================================

function QuestReminder.CheckQuestsOnLogin()
    if not UIThingsDB.questReminder or not UIThingsDB.questReminder.enabled then return end

    local tracked = LunaUITweaks_QuestReminders.quests
    if not tracked or not next(tracked) then return end

    local incomplete = {}
    for questID, data in pairs(tracked) do
        local completedOnChar = C_QuestLog.IsQuestFlaggedCompleted(questID)
        local completedOnAccount = not data.ignoreWarband
            and C_QuestLog.IsQuestFlaggedCompletedOnAccount
            and C_QuestLog.IsQuestFlaggedCompletedOnAccount(questID)
        if not completedOnChar and not completedOnAccount then
            local inLog = C_QuestLog.IsOnQuest(questID)
            table.insert(incomplete, {
                questID = questID,
                data = data,
                inLog = inLog,
            })
        end
    end

    if #incomplete == 0 then return end

    -- Sort: dailies first, then weeklies, then alphabetical
    table.sort(incomplete, function(a, b)
        if a.data.frequency ~= b.data.frequency then
            return a.data.frequency == "daily"
        end
        return (a.data.name or "") < (b.data.name or "")
    end)

    -- Chat message
    if UIThingsDB.questReminder.showChatMessage then
        print("|cFFFFD100[LunaUITweaks]|r You have " .. #incomplete .. " incomplete repeatable quest(s):")
        for _, q in ipairs(incomplete) do
            local prefix = q.data.frequency == "daily" and "|cFF00CCFF[D]|r" or "|cFFCC00FF[W]|r"
            local status = q.inLog and "|cFF00FF00(in log)|r" or "|cFFFF6B6B(not picked up)|r"
            print(string.format("  %s %s - %s %s", prefix, q.data.name, q.data.zoneName, status))
        end
    end

    -- Sound
    if UIThingsDB.questReminder.playSound then
        PlaySound(8959)
    end

    -- TTS
    if UIThingsDB.questReminder.ttsEnabled then
        addonTable.Core.SpeakTTS(
            UIThingsDB.questReminder.ttsMessage or "You've got quests",
            UIThingsDB.questReminder.ttsVoice or 0
        )
    end

    -- Popup
    if UIThingsDB.questReminder.showPopup then
        QuestReminder.ShowPopup(incomplete)
    end
end

-- ============================================================
-- Remove / Clear
-- ============================================================

function QuestReminder.RemoveQuest(questID)
    if LunaUITweaks_QuestReminders and LunaUITweaks_QuestReminders.quests then
        LunaUITweaks_QuestReminders.quests[questID] = nil
    end
    if addonTable.Config and addonTable.Config.RefreshQuestReminderList then
        addonTable.Config.RefreshQuestReminderList()
    end
end

function QuestReminder.ClearAll()
    if LunaUITweaks_QuestReminders then
        LunaUITweaks_QuestReminders.quests = {}
    end
    if addonTable.Config and addonTable.Config.RefreshQuestReminderList then
        addonTable.Config.RefreshQuestReminderList()
    end
end

-- ============================================================
-- Settings Update
-- ============================================================

function QuestReminder.UpdateSettings()
    QuestReminder.ApplyEvents()
    QuestReminder.UpdateVisuals()
end

function QuestReminder.UpdateVisuals()
    if not popupFrame then return end

    -- Apply frame size
    local width = UIThingsDB.questReminder.frameWidth or 350
    local height = UIThingsDB.questReminder.frameHeight or 250
    popupFrame:SetSize(width, height)

    -- Adjust scroll child width
    if popupFrame.scrollChild then
        popupFrame.scrollChild:SetWidth(width - 40)
    end
    if popupFrame.content then
        popupFrame.content:SetWidth(width - 60)
    end

    -- Apply backdrop
    local showBorder = UIThingsDB.questReminder.showBorder
    local showBackground = UIThingsDB.questReminder.showBackground

    if showBorder or showBackground then
        popupFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            tileSize = 0,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })

        if showBackground then
            local c = UIThingsDB.questReminder.backgroundColor or { r = 0.05, g = 0.05, b = 0.05, a = 0.92 }
            popupFrame:SetBackdropColor(c.r, c.g, c.b, c.a)
        else
            popupFrame:SetBackdropColor(0, 0, 0, 0)
        end

        if showBorder then
            local bc = UIThingsDB.questReminder.borderColor or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
            popupFrame:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
        else
            popupFrame:SetBackdropBorderColor(0, 0, 0, 0)
        end
    else
        popupFrame:SetBackdrop(nil)
    end
end

-- ============================================================
-- Popup Frame
-- ============================================================

function QuestReminder.CreatePopupFrame()
    if popupFrame then return end

    popupFrame = CreateFrame("Frame", "LunaQuestReminderPopup", UIParent, "BackdropTemplate")
    local width = UIThingsDB.questReminder.frameWidth or 350
    local height = UIThingsDB.questReminder.frameHeight or 250
    popupFrame:SetSize(width, height)

    local pos = UIThingsDB.questReminder.popupPos or { point = "CENTER", x = 0, y = 0 }
    popupFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)

    popupFrame:SetFrameStrata("DIALOG")
    popupFrame:SetClampedToScreen(true)
    popupFrame:EnableMouse(true)
    popupFrame:SetMovable(true)
    popupFrame:RegisterForDrag("LeftButton")
    popupFrame:SetScript("OnDragStart", popupFrame.StartMoving)
    popupFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        UIThingsDB.questReminder.popupPos = { point = point, x = x, y = y }
    end)
    popupFrame:Hide()

    -- Title
    popupFrame.title = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    popupFrame.title:SetPoint("TOP", 0, -12)
    popupFrame.title:SetText("Quest Reminders")
    popupFrame.title:SetTextColor(1, 0.82, 0)

    -- Scroll frame for quest list
    local scrollFrame = CreateFrame("ScrollFrame", nil, popupFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 50)
    popupFrame.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(width - 40)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    popupFrame.scrollChild = scrollChild

    -- Content font string
    popupFrame.content = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popupFrame.content:SetPoint("TOPLEFT", 5, -5)
    popupFrame.content:SetWidth(width - 60)
    popupFrame.content:SetJustifyH("LEFT")
    popupFrame.content:SetJustifyV("TOP")
    popupFrame.content:SetSpacing(4)

    -- Dismiss button
    local dismissBtn = CreateFrame("Button", nil, popupFrame, "GameMenuButtonTemplate")
    dismissBtn:SetSize(100, 25)
    dismissBtn:SetPoint("BOTTOM", 0, 15)
    dismissBtn:SetText("Dismiss")
    dismissBtn:SetNormalFontObject("GameFontNormal")
    dismissBtn:SetHighlightFontObject("GameFontHighlight")
    dismissBtn:SetScript("OnClick", function() popupFrame:Hide() end)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, popupFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    -- Apply visual settings
    QuestReminder.UpdateVisuals()
end

function QuestReminder.ShowPopup(incomplete)
    if not popupFrame then return end

    -- Build content text
    local lines = {}
    for _, q in ipairs(incomplete) do
        local prefix
        if q.data.frequency == "daily" then
            prefix = "|cFF00CCFF[D]|r"
        else
            prefix = "|cFFCC00FF[W]|r"
        end

        local questName
        if q.inLog then
            questName = string.format("|cFF00FF00%s|r", q.data.name)
        else
            questName = string.format("|cFFFFAA00%s|r", q.data.name)
        end

        local zoneLine = string.format("    |cFF888888%s|r", q.data.zoneName or "Unknown")

        table.insert(lines, string.format("%s %s", prefix, questName))
        table.insert(lines, zoneLine)
    end

    popupFrame.content:SetText(table.concat(lines, "\n"))

    -- Resize scroll child to fit content
    local textHeight = popupFrame.content:GetStringHeight()
    popupFrame.scrollChild:SetHeight(math.max(1, textHeight + 10))

    popupFrame:Show()
end

-- ============================================================
-- Test Function (for config panel)
-- ============================================================

function QuestReminder.TestPopup()
    local testData = {
        {
            questID = 0,
            data = {
                name = "Example Daily Quest",
                frequency = "daily",
                zoneName = "Dornogal",
            },
            inLog = true,
        },
        {
            questID = 1,
            data = {
                name = "Example Weekly Quest",
                frequency = "weekly",
                zoneName = "Isle of Dorn",
            },
            inLog = false,
        },
    }
    QuestReminder.ShowPopup(testData)

    if UIThingsDB.questReminder.ttsEnabled then
        addonTable.Core.SpeakTTS(
            UIThingsDB.questReminder.ttsMessage or "You've got quests",
            UIThingsDB.questReminder.ttsVoice or 0
        )
    end
end
