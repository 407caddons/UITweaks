local addonName, addonTable = ...
local QuestAuto = {}
addonTable.QuestAuto = QuestAuto

local Log = addonTable.Core.Log

local frame = CreateFrame("Frame")

-- Track gossip selections to prevent loops within the same NPC interaction
local lastGossipOptionID = nil

-- Helper: check if a quest should be automated based on trivial filter
local function ShouldAcceptQuest(questID)
    if not UIThingsDB.questAuto.autoAcceptQuests then return false end
    if C_QuestLog.IsQuestTrivial(questID) and not UIThingsDB.questAuto.acceptTrivial then
        return false
    end
    return true
end

-- GOSSIP_SHOW: NPC gossip window
local function HandleGossipShow()
    local settings = UIThingsDB.questAuto

    -- Handle quest lists on gossip NPCs (turn-in and accept)
    if settings.autoTurnIn then
        for _, questInfo in pairs(C_GossipInfo.GetActiveQuests()) do
            if questInfo.isComplete then
                C_GossipInfo.SelectActiveQuest(questInfo.questID)
                return
            end
        end
    end

    if settings.autoAcceptQuests then
        for _, questInfo in pairs(C_GossipInfo.GetAvailableQuests()) do
            if ShouldAcceptQuest(questInfo.questID) then
                C_GossipInfo.SelectAvailableQuest(questInfo.questID)
                return
            end
        end
    end

    -- Handle gossip options: auto-select if exactly one option
    if settings.autoGossip then
        -- Don't auto-select gossip if the NPC also has quests
        if (C_GossipInfo.GetNumActiveQuests() + C_GossipInfo.GetNumAvailableQuests()) > 0 then
            return
        end

        local options = C_GossipInfo.GetOptions()
        if #options == 1 and options[1].gossipOptionID then
            -- Skip if we already selected this option (prevents loop)
            if options[1].gossipOptionID == lastGossipOptionID then
                return
            end
            lastGossipOptionID = options[1].gossipOptionID
            C_GossipInfo.SelectOption(options[1].gossipOptionID)
        end
    end
end

-- QUEST_GREETING: Quest NPC with multiple quests (non-gossip list)
local function HandleQuestGreeting()
    local settings = UIThingsDB.questAuto

    -- Turn in completed quests first
    if settings.autoTurnIn then
        for index = 1, GetNumActiveQuests() do
            local _, isComplete = GetActiveTitle(index)
            if isComplete then
                SelectActiveQuest(index)
                return
            end
        end
    end

    -- Accept available quests
    if settings.autoAcceptQuests then
        for index = 1, GetNumAvailableQuests() do
            local _, _, _, _, questID = GetAvailableQuestInfo(index)
            if questID and ShouldAcceptQuest(questID) then
                SelectAvailableQuest(index)
                return
            end
        end
    end
end

-- QUEST_DETAIL: Quest detail screen (accept/decline)
local function HandleQuestDetail()
    if not UIThingsDB.questAuto.autoAcceptQuests then return end

    local questID = GetQuestID()
    if not questID or questID == 0 then return end

    -- Handle auto-accept popup quests
    if QuestGetAutoAccept and QuestGetAutoAccept() then
        if AcknowledgeAutoAcceptQuest then
            AcknowledgeAutoAcceptQuest()
        end
        if RemoveAutoQuestPopUp then
            RemoveAutoQuestPopUp(questID)
        end
        return
    end

    if ShouldAcceptQuest(questID) then
        AcceptQuest()
    end
end

-- QUEST_PROGRESS: Quest turn-in progress screen
local function HandleQuestProgress()
    if not UIThingsDB.questAuto.autoTurnIn then return end
    if IsQuestCompletable() then
        CompleteQuest()
    end
end

-- QUEST_COMPLETE: Quest completion/reward screen
local function HandleQuestComplete()
    if not UIThingsDB.questAuto.autoTurnIn then return end

    -- Only auto-complete if there is 0 or 1 reward choice
    if GetNumQuestChoices() <= 1 then
        GetQuestReward(1)
    end
end

-- Event handler
local function OnEvent(self, event, ...)
    if not UIThingsDB.questAuto or not UIThingsDB.questAuto.enabled then return end

    -- Hold Shift to pause all automation for this interaction
    if UIThingsDB.questAuto.shiftToPause and IsShiftKeyDown() then return end

    if event == "GOSSIP_SHOW" then
        HandleGossipShow()
    elseif event == "GOSSIP_CLOSED" then
        lastGossipOptionID = nil
    elseif event == "QUEST_GREETING" then
        HandleQuestGreeting()
    elseif event == "QUEST_DETAIL" then
        HandleQuestDetail()
    elseif event == "QUEST_PROGRESS" then
        HandleQuestProgress()
    elseif event == "QUEST_COMPLETE" then
        HandleQuestComplete()
    end
end

frame:SetScript("OnEvent", OnEvent)

-- Apply event registration based on settings
local function ApplyEvents()
    if not UIThingsDB.questAuto or not UIThingsDB.questAuto.enabled then
        frame:UnregisterEvent("GOSSIP_SHOW")
        frame:UnregisterEvent("QUEST_GREETING")
        frame:UnregisterEvent("QUEST_DETAIL")
        frame:UnregisterEvent("QUEST_PROGRESS")
        frame:UnregisterEvent("QUEST_COMPLETE")
        return
    end

    if UIThingsDB.questAuto.autoGossip or UIThingsDB.questAuto.autoAcceptQuests or UIThingsDB.questAuto.autoTurnIn then
        frame:RegisterEvent("GOSSIP_SHOW")
        frame:RegisterEvent("GOSSIP_CLOSED")
    else
        frame:UnregisterEvent("GOSSIP_SHOW")
        frame:UnregisterEvent("GOSSIP_CLOSED")
        lastGossipOptionID = nil
    end

    if UIThingsDB.questAuto.autoAcceptQuests or UIThingsDB.questAuto.autoTurnIn then
        frame:RegisterEvent("QUEST_GREETING")
    else
        frame:UnregisterEvent("QUEST_GREETING")
    end

    if UIThingsDB.questAuto.autoAcceptQuests then
        frame:RegisterEvent("QUEST_DETAIL")
    else
        frame:UnregisterEvent("QUEST_DETAIL")
    end

    if UIThingsDB.questAuto.autoTurnIn then
        frame:RegisterEvent("QUEST_PROGRESS")
        frame:RegisterEvent("QUEST_COMPLETE")
    else
        frame:UnregisterEvent("QUEST_PROGRESS")
        frame:UnregisterEvent("QUEST_COMPLETE")
    end
end

function QuestAuto.UpdateSettings()
    ApplyEvents()
end

-- Initialize on PLAYER_ENTERING_WORLD
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    ApplyEvents()
end)
