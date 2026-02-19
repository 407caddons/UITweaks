local addonName, addonTable = ...

addonTable.ConfigSetup = addonTable.ConfigSetup or {}

local Helpers = addonTable.ConfigHelpers

function addonTable.ConfigSetup.QuestAuto(panel, tab, configWindow)
    Helpers.CreateResetButton(panel, "questAuto")
    -- Panel Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Quest Automation")

    -- Enable Checkbox
    local enableBtn = CreateFrame("CheckButton", "UIThingsQuestAutoEnableCheck", panel,
        "ChatConfigCheckButtonTemplate")
    enableBtn:SetPoint("TOPLEFT", 20, -50)
    _G[enableBtn:GetName() .. "Text"]:SetText("Enable Quest Automation")
    enableBtn:SetChecked(UIThingsDB.questAuto.enabled)
    enableBtn:SetScript("OnClick", function(self)
        local enabled = not not self:GetChecked()
        UIThingsDB.questAuto.enabled = enabled
        Helpers.UpdateModuleVisuals(panel, tab, enabled)
        if addonTable.QuestAuto and addonTable.QuestAuto.UpdateSettings then
            addonTable.QuestAuto.UpdateSettings()
        end
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.questAuto.enabled)

    -- Quest Handling Section
    Helpers.CreateSectionHeader(panel, "Quest Handling", -90)

    -- Auto-Accept Quests
    local acceptBtn = CreateFrame("CheckButton", "UIThingsQuestAutoAcceptCheck", panel,
        "ChatConfigCheckButtonTemplate")
    acceptBtn:SetPoint("TOPLEFT", 20, -120)
    _G[acceptBtn:GetName() .. "Text"]:SetText("Auto-Accept Quests")
    acceptBtn:SetChecked(UIThingsDB.questAuto.autoAcceptQuests)
    acceptBtn:SetScript("OnClick", function(self)
        UIThingsDB.questAuto.autoAcceptQuests = not not self:GetChecked()
        if addonTable.QuestAuto and addonTable.QuestAuto.UpdateSettings then
            addonTable.QuestAuto.UpdateSettings()
        end
    end)

    -- Accept Low-Level Quests (indented)
    local trivialBtn = CreateFrame("CheckButton", "UIThingsQuestAutoTrivialCheck", panel,
        "ChatConfigCheckButtonTemplate")
    trivialBtn:SetPoint("TOPLEFT", 40, -150)
    _G[trivialBtn:GetName() .. "Text"]:SetText("Include Low-Level Quests")
    trivialBtn:SetChecked(UIThingsDB.questAuto.acceptTrivial)
    trivialBtn:SetScript("OnClick", function(self)
        UIThingsDB.questAuto.acceptTrivial = not not self:GetChecked()
    end)

    -- Auto-Turn In Quests
    local turnInBtn = CreateFrame("CheckButton", "UIThingsQuestAutoTurnInCheck", panel,
        "ChatConfigCheckButtonTemplate")
    turnInBtn:SetPoint("TOPLEFT", 20, -180)
    _G[turnInBtn:GetName() .. "Text"]:SetText("Auto-Turn In Quests")
    turnInBtn:SetChecked(UIThingsDB.questAuto.autoTurnIn)
    turnInBtn:SetScript("OnClick", function(self)
        UIThingsDB.questAuto.autoTurnIn = not not self:GetChecked()
        if addonTable.QuestAuto and addonTable.QuestAuto.UpdateSettings then
            addonTable.QuestAuto.UpdateSettings()
        end
    end)

    -- Turn-in help text
    local turnInHelp = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    turnInHelp:SetPoint("TOPLEFT", 60, -210)
    turnInHelp:SetWidth(500)
    turnInHelp:SetJustifyH("LEFT")
    turnInHelp:SetText(
        "Automatically completes quests when there is no reward choice. If multiple rewards are offered, you will be prompted to choose.")
    turnInHelp:SetTextColor(0.7, 0.7, 0.7)

    -- Dialog Handling Section
    Helpers.CreateSectionHeader(panel, "Dialog Handling", -250)

    -- Auto-Select Single Dialog
    local gossipBtn = CreateFrame("CheckButton", "UIThingsQuestAutoGossipCheck", panel,
        "ChatConfigCheckButtonTemplate")
    gossipBtn:SetPoint("TOPLEFT", 20, -280)
    _G[gossipBtn:GetName() .. "Text"]:SetText("Auto-Select Single Dialog Options")
    gossipBtn:SetChecked(UIThingsDB.questAuto.autoGossip)
    gossipBtn:SetScript("OnClick", function(self)
        UIThingsDB.questAuto.autoGossip = not not self:GetChecked()
        if addonTable.QuestAuto and addonTable.QuestAuto.UpdateSettings then
            addonTable.QuestAuto.UpdateSettings()
        end
    end)

    -- Gossip help text
    local gossipHelp = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gossipHelp:SetPoint("TOPLEFT", 60, -310)
    gossipHelp:SetWidth(500)
    gossipHelp:SetJustifyH("LEFT")
    gossipHelp:SetText(
        "When an NPC has only one dialog option, it will be selected automatically. If there are multiple options, you will be prompted to choose.")
    gossipHelp:SetTextColor(0.7, 0.7, 0.7)

    -- Modifier Key Section
    Helpers.CreateSectionHeader(panel, "Modifier Keys", -350)

    local shiftBtn = CreateFrame("CheckButton", "UIThingsQuestAutoShiftPauseCheck", panel,
        "ChatConfigCheckButtonTemplate")
    shiftBtn:SetPoint("TOPLEFT", 20, -380)
    _G[shiftBtn:GetName() .. "Text"]:SetText("Hold Shift to pause automation")
    shiftBtn:SetChecked(UIThingsDB.questAuto.shiftToPause)
    shiftBtn:SetScript("OnClick", function(self)
        UIThingsDB.questAuto.shiftToPause = not not self:GetChecked()
    end)

    local shiftHelp = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    shiftHelp:SetPoint("TOPLEFT", 60, -410)
    shiftHelp:SetWidth(500)
    shiftHelp:SetJustifyH("LEFT")
    shiftHelp:SetText(
        "Hold Shift when interacting with an NPC to temporarily skip all quest automation for that interaction.")
    shiftHelp:SetTextColor(0.7, 0.7, 0.7)
end
