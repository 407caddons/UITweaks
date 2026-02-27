local addonName, addonTable = ...
local QuestAuto = {}
addonTable.QuestAuto = QuestAuto

local Log = addonTable.Core.Log
local EventBus = addonTable.EventBus

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
    local settings  = UIThingsDB.questAuto
    local options   = C_GossipInfo.GetOptions()


    -- Turn in ALL completed quests
    if settings.autoTurnIn then
        for _, questInfo in pairs(C_GossipInfo.GetActiveQuests()) do
            if questInfo.isComplete then
                C_GossipInfo.SelectActiveQuest(questInfo.questID)
                return  -- GOSSIP_SHOW re-fires after each turn-in; loop continues next fire
            end
        end
    end

    -- Accept ALL available quests
    if settings.autoAcceptQuests then
        for _, questInfo in pairs(C_GossipInfo.GetAvailableQuests()) do
            if ShouldAcceptQuest(questInfo.questID) then
                C_GossipInfo.SelectAvailableQuest(questInfo.questID)
                return  -- GOSSIP_SHOW re-fires after each accept; loop continues next fire
            end
        end
    end

    -- Auto-select gossip option.
    -- Rules:
    --   • Exactly 1 (Quest) option among any number of non-quest options → select the quest option
    --   • Multiple (Quest) options → do nothing, let the user choose
    --   • No (Quest) options + exactly 1 total option → select it
    --   • No (Quest) options + multiple options → do nothing
    -- All quests via GetAvailableQuests/GetActiveQuests are handled above first.
    if settings.autoGossip then
        -- All quests must be resolved before auto-selecting gossip
        if C_GossipInfo.GetNumActiveQuests() + C_GossipInfo.GetNumAvailableQuests() > 0 then return end

        -- Separate quest-flagged options (flags ~= 0) from plain gossip options
        local questOption = nil
        local questOptionCount = 0
        local plainCount = 0
        for _, opt in ipairs(options) do
            if opt.flags and opt.flags ~= 0 then
                questOptionCount = questOptionCount + 1
                questOption = opt
            else
                plainCount = plainCount + 1
            end
        end

        local selected = nil
        if questOptionCount == 1 then
            -- Exactly one (Quest) option — select it regardless of plain options
            selected = questOption
        elseif questOptionCount == 0 and plainCount == 1 then
            -- No quest options, exactly one plain option — select it
            selected = options[1]
        end

        if selected and selected.gossipOptionID then
            if selected.gossipOptionID == lastGossipOptionID then return end
            lastGossipOptionID = selected.gossipOptionID
            C_GossipInfo.SelectOption(selected.gossipOptionID)
        end
    end
end

-- QUEST_GREETING: Quest NPC with multiple quests (non-gossip list)
local function HandleQuestGreeting()
    local settings = UIThingsDB.questAuto

    -- Turn in ALL completed quests (one per event fire; QUEST_GREETING re-fires after each)
    if settings.autoTurnIn then
        for index = 1, GetNumActiveQuests() do
            local _, isComplete = GetActiveTitle(index)
            if isComplete then
                SelectActiveQuest(index)
                return
            end
        end
    end

    -- Accept ALL available quests (one per event fire; QUEST_GREETING re-fires after each)
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

-- Named callbacks for EventBus registration/unregistration
local function OnGossipShow()
    if not UIThingsDB.questAuto or not UIThingsDB.questAuto.enabled then return end
    if UIThingsDB.questAuto.shiftToPause and IsShiftKeyDown() then return end
    HandleGossipShow()
end

local function OnGossipClosed()
    if not UIThingsDB.questAuto or not UIThingsDB.questAuto.enabled then return end
    lastGossipOptionID = nil
end

local function OnQuestGreeting()
    if not UIThingsDB.questAuto or not UIThingsDB.questAuto.enabled then return end
    if UIThingsDB.questAuto.shiftToPause and IsShiftKeyDown() then return end
    HandleQuestGreeting()
end

local function OnQuestDetail()
    if not UIThingsDB.questAuto or not UIThingsDB.questAuto.enabled then return end
    if UIThingsDB.questAuto.shiftToPause and IsShiftKeyDown() then return end
    HandleQuestDetail()
end

local function OnQuestProgress()
    if not UIThingsDB.questAuto or not UIThingsDB.questAuto.enabled then return end
    if UIThingsDB.questAuto.shiftToPause and IsShiftKeyDown() then return end
    HandleQuestProgress()
end

local function OnQuestComplete()
    if not UIThingsDB.questAuto or not UIThingsDB.questAuto.enabled then return end
    if UIThingsDB.questAuto.shiftToPause and IsShiftKeyDown() then return end
    HandleQuestComplete()
end

-- Apply event registration based on settings
local function ApplyEvents()
    if not UIThingsDB.questAuto or not UIThingsDB.questAuto.enabled then
        EventBus.Unregister("GOSSIP_SHOW", OnGossipShow)
        EventBus.Unregister("GOSSIP_CLOSED", OnGossipClosed)
        EventBus.Unregister("QUEST_GREETING", OnQuestGreeting)
        EventBus.Unregister("QUEST_DETAIL", OnQuestDetail)
        EventBus.Unregister("QUEST_PROGRESS", OnQuestProgress)
        EventBus.Unregister("QUEST_COMPLETE", OnQuestComplete)
        return
    end

    if UIThingsDB.questAuto.autoGossip or UIThingsDB.questAuto.autoAcceptQuests or UIThingsDB.questAuto.autoTurnIn then
        EventBus.Register("GOSSIP_SHOW", OnGossipShow, "QuestAuto")
        EventBus.Register("GOSSIP_CLOSED", OnGossipClosed, "QuestAuto")
    else
        EventBus.Unregister("GOSSIP_SHOW", OnGossipShow)
        EventBus.Unregister("GOSSIP_CLOSED", OnGossipClosed)
        lastGossipOptionID = nil
    end

    if UIThingsDB.questAuto.autoAcceptQuests or UIThingsDB.questAuto.autoTurnIn then
        EventBus.Register("QUEST_GREETING", OnQuestGreeting, "QuestAuto")
    else
        EventBus.Unregister("QUEST_GREETING", OnQuestGreeting)
    end

    if UIThingsDB.questAuto.autoAcceptQuests then
        EventBus.Register("QUEST_DETAIL", OnQuestDetail, "QuestAuto")
    else
        EventBus.Unregister("QUEST_DETAIL", OnQuestDetail)
    end

    if UIThingsDB.questAuto.autoTurnIn then
        EventBus.Register("QUEST_PROGRESS", OnQuestProgress, "QuestAuto")
        EventBus.Register("QUEST_COMPLETE", OnQuestComplete, "QuestAuto")
    else
        EventBus.Unregister("QUEST_PROGRESS", OnQuestProgress)
        EventBus.Unregister("QUEST_COMPLETE", OnQuestComplete)
    end
end

function QuestAuto.UpdateSettings()
    ApplyEvents()
end

-- Initialize on PLAYER_ENTERING_WORLD (one-shot)
local function OnInitEnteringWorld()
    EventBus.Unregister("PLAYER_ENTERING_WORLD", OnInitEnteringWorld)
    ApplyEvents()
end
EventBus.Register("PLAYER_ENTERING_WORLD", OnInitEnteringWorld, "QuestAuto")
