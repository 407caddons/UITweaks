local addonName, addonTable = ...
local Misc = {}
addonTable.Misc = Misc

-- == PERSONAL ORDER ALERT ==

local alertFrame = CreateFrame("Frame", "UIThingsPersonalAlert", UIParent, "BackdropTemplate")
alertFrame:SetSize(400, 50)
alertFrame:SetPoint("TOP", 0, -200)
alertFrame:SetFrameStrata("DIALOG")
alertFrame:Hide()

alertFrame.text = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
alertFrame.text:SetPoint("CENTER")
alertFrame.text:SetText("Personal Order Arrived")

local function ShowAlert()
    if not UIThingsDB.misc.personalOrders then return end

    local color = UIThingsDB.misc.alertColor
    alertFrame.text:SetTextColor(color.r, color.g, color.b, color.a or 1)

    alertFrame:Show()

    -- TTS (only if enabled)
    if UIThingsDB.misc.ttsEnabled then
        addonTable.Core.SpeakTTS(
            UIThingsDB.misc.ttsMessage or "Personal order arrived",
            UIThingsDB.misc.ttsVoice or 0
        )
    end

    -- Hide after duration
    local duration = UIThingsDB.misc.alertDuration or 5
    addonTable.Core.SafeAfter(duration, function()
        alertFrame:Hide()
    end)
end

-- Expose ShowAlert for test button
function Misc.ShowAlert()
    ShowAlert()
end

-- == MAIL NOTIFICATION ==
local mailAlertShown = false -- Track if we already alerted for current pending mail

local mailAlertFrame = CreateFrame("Frame", "UIThingsMailAlert", UIParent, "BackdropTemplate")
mailAlertFrame:SetSize(400, 50)
mailAlertFrame:SetPoint("TOP", 0, -260)
mailAlertFrame:SetFrameStrata("DIALOG")
mailAlertFrame:Hide()

mailAlertFrame.text = mailAlertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
mailAlertFrame.text:SetPoint("CENTER")
mailAlertFrame.text:SetText("New mail arrived")

local function PlayMailTTS()
    if not UIThingsDB.misc.mailTtsEnabled then return end
    addonTable.Core.SpeakTTS(
        UIThingsDB.misc.mailTtsMessage or "You've got mail",
        UIThingsDB.misc.mailTtsVoice or 0
    )
end

local function ShowMailAlert()
    if not UIThingsDB.misc.mailNotification then return end

    local color = UIThingsDB.misc.mailAlertColor
    mailAlertFrame.text:SetTextColor(color.r, color.g, color.b, color.a or 1)

    mailAlertFrame:Show()

    -- Delay TTS so it plays after personal order TTS
    addonTable.Core.SafeAfter(2, PlayMailTTS)

    -- Hide after duration
    local duration = UIThingsDB.misc.mailAlertDuration or 5
    addonTable.Core.SafeAfter(duration, function()
        mailAlertFrame:Hide()
    end)
end

function Misc.ShowMailAlert()
    ShowMailAlert()
end

function Misc.TestMailTTS()
    PlayMailTTS()
end

-- == BoE ITEM ALERT ==

local boeAlertFrame = CreateFrame("Frame", "UIThingsBoeAlert", UIParent, "BackdropTemplate")
boeAlertFrame:SetSize(400, 50)
boeAlertFrame:SetPoint("TOP", 0, -320)
boeAlertFrame:SetFrameStrata("DIALOG")
boeAlertFrame:Hide()

boeAlertFrame.text = boeAlertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
boeAlertFrame.text:SetPoint("CENTER")
boeAlertFrame.text:SetText("BoE Item Looted!")

local function ShowBoeAlert(itemName, quality)
    if not UIThingsDB.misc.boeAlert then return end

    local color = UIThingsDB.misc.boeAlertColor
    boeAlertFrame.text:SetTextColor(color.r, color.g, color.b, color.a or 1)

    if itemName then
        local r, g, b, hex = C_Item.GetItemQualityColor and C_Item.GetItemQualityColor(quality)
        if hex then
            boeAlertFrame.text:SetText(string.format("|c%sBoE: %s|r", hex, itemName))
        else
            boeAlertFrame.text:SetText("BoE: " .. itemName)
        end
    else
        boeAlertFrame.text:SetText("BoE Item Looted!")
    end

    boeAlertFrame:Show()

    local duration = UIThingsDB.misc.boeAlertDuration or 5
    addonTable.Core.SafeAfter(duration, function()
        boeAlertFrame:Hide()
    end)
end

function Misc.ShowBoeAlert()
    ShowBoeAlert()
end

-- Blizzard bind type constant for Bind on Equip
local BOE_BIND_ON_EQUIP = 2

local function OnChatMsgLootBoE(event, msg)
    if not UIThingsDB.misc or not UIThingsDB.misc.enabled then return end
    if not UIThingsDB.misc.boeAlert then return end

    -- CHAT_MSG_LOOT msg can be a secret/tainted string during combat; pcall to skip safely
    local ok, itemLink = pcall(string.match, msg, "|H(item:[^|]+)|h")
    if not ok or not itemLink then return end

    local _, itemID = pcall(string.match, itemLink, "item:(%d+)")
    itemID = tonumber(itemID)
    if not itemID then return end

    local itemName, _, quality, _, _, _, _, _, _, _, _, _, _, bindType = GetItemInfo(itemID)
    if not itemName then return end

    local minQuality = UIThingsDB.misc.boeMinQuality or 4
    if quality < minQuality then return end
    if bindType ~= BOE_BIND_ON_EQUIP then return end

    ShowBoeAlert(itemName, quality)
end

-- Check if player has pending personal orders
local function CheckForPersonalOrders()
    if not UIThingsDB.misc.personalOrders then return end
    if not UIThingsDB.misc.personalOrdersCheckAtLogon then return end

    -- Don't check if in an instance
    local inInstance = IsInInstance()
    if inInstance then return end

    -- Check if we have any personal crafting orders
    local hasOrders = false

    -- Try GetPersonalOrdersInfo - returns array of orders
    if C_CraftingOrders and C_CraftingOrders.GetPersonalOrdersInfo then
        local info = C_CraftingOrders.GetPersonalOrdersInfo()
        if info then
            -- Check if it's an array (has numeric indices)
            if type(info) == "table" and #info > 0 then
                hasOrders = true
                -- Check if it has named field
            elseif info.numPersonalOrders and info.numPersonalOrders > 0 then
                hasOrders = true
            end
        end
    end

    -- Fallback: Try GetMyOrders
    if not hasOrders and C_CraftingOrders and C_CraftingOrders.GetMyOrders then
        local orders = C_CraftingOrders.GetMyOrders()
        if orders and #orders > 0 then
            hasOrders = true
        end
    end

    if hasOrders then
        ShowAlert()
    end
end

-- Expose for testing
function Misc.TestTTS()
    addonTable.Core.SpeakTTS(
        UIThingsDB.misc.ttsMessage or "Personal order arrived",
        UIThingsDB.misc.ttsVoice or 0
    )
end

-- == DEATH NOTIFICATION ==

local deathAnnounced = {} -- [unitToken] = true while dead, cleared on resurrection

local function GetRoleLabel(unit)
    local role = UnitGroupRolesAssigned(unit)
    if role == "TANK" then
        return "Tank"
    elseif role == "HEALER" then
        return "Healer"
    elseif role == "DAMAGER" then
        return "DPS"
    else
        return ""
    end
end

-- UNIT_HEALTH passes non-secret unit tokens; handles both death detection and
-- resurrection reset in one handler so we only need one event registration.
local function OnUnitHealth(event, unitTarget)
    if not UIThingsDB.misc or not UIThingsDB.misc.enabled then return end
    if not UIThingsDB.misc.deathNotify then return end
    if not unitTarget or issecretvalue(unitTarget) then return end

    if UnitIsDead("player") then return end

    local isParty = unitTarget:match("^party%d+$")
    local isRaid  = unitTarget:match("^raid%d+$")
    if not isParty and not isRaid then return end

    local guid = UnitGUID(unitTarget)
    if not guid then return end

    if UnitIsDead(unitTarget) then
        if not deathAnnounced[guid] then
            deathAnnounced[guid] = true
            if UIThingsDB.misc.deathTtsEnabled then
                local deadCount = 0
                for _ in pairs(deathAnnounced) do deadCount = deadCount + 1 end
                local maxCount = UIThingsDB.misc.deathMaxCount or 3
                if deadCount <= maxCount then
                    local name = UnitName(unitTarget) or "Unknown"
                    local role = GetRoleLabel(unitTarget)
                    local msg = UIThingsDB.misc.deathTtsMessage or "{name} died"
                    msg = msg:gsub("{name}", name)
                    msg = msg:gsub("{role}", role)
                    addonTable.Core.SpeakTTS(msg, UIThingsDB.misc.deathTtsVoice or 0)
                end
            end
        end
    else
        -- Unit is alive again — reset so the next death fires TTS again
        deathAnnounced[guid] = nil
    end
end

-- Drop entries for GUIDs no longer in the group, so stale deaths don't inflate the count
local function OnGroupRosterUpdate()
    if not next(deathAnnounced) then return end
    if not IsInGroup() then
        wipe(deathAnnounced)
        return
    end
    local present = {}
    local prefix, count
    if IsInRaid() then
        prefix, count = "raid", GetNumGroupMembers()
    else
        prefix, count = "party", GetNumGroupMembers() - 1
    end
    for i = 1, count do
        local guid = UnitGUID(prefix .. i)
        if guid then present[guid] = true end
    end
    for guid in pairs(deathAnnounced) do
        if not present[guid] then
            deathAnnounced[guid] = nil
        end
    end
end

function Misc.TestDeathTTS()
    local msg = UIThingsDB.misc.deathTtsMessage or "{name} died"
    msg = msg:gsub("{name}", UnitName("player") or "Player")
    msg = msg:gsub("{role}", GetRoleLabel("player"))
    addonTable.Core.SpeakTTS(msg, UIThingsDB.misc.deathTtsVoice or 0)
end

-- == WHISPER ALERT ==

local whisperAlertFrame = CreateFrame("Frame", "UIThingsWhisperAlert", UIParent, "BackdropTemplate")
whisperAlertFrame:SetSize(400, 50)
whisperAlertFrame:SetPoint("TOP", 0, -440)
whisperAlertFrame:SetFrameStrata("DIALOG")
whisperAlertFrame:Hide()

whisperAlertFrame.text = whisperAlertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
whisperAlertFrame.text:SetPoint("CENTER")

local function ShowWhisperAlert(senderName)
    if not UIThingsDB.misc.whisperAlert then return end

    local color = UIThingsDB.misc.whisperAlertColor
    whisperAlertFrame.text:SetTextColor(color.r, color.g, color.b, color.a or 1)
    whisperAlertFrame.text:SetText("Whisper from " .. (senderName or "?"))
    whisperAlertFrame:Show()

    if UIThingsDB.misc.whisperTtsEnabled then
        local msg = UIThingsDB.misc.whisperTtsMessage or "Whisper from {name}"
        msg = msg:gsub("{name}", senderName or "unknown")
        addonTable.Core.SpeakTTS(msg, UIThingsDB.misc.whisperTtsVoice or 0)
    end

    local duration = UIThingsDB.misc.whisperAlertDuration or 5
    addonTable.Core.SafeAfter(duration, function()
        whisperAlertFrame:Hide()
    end)
end

function Misc.TestWhisperAlert()
    ShowWhisperAlert(UnitName("player") or "Player")
end

local function OnChatMsgWhisperAlert(event, msg, sender)
    if not UIThingsDB.misc or not UIThingsDB.misc.enabled then return end
    if not UIThingsDB.misc.whisperAlert then return end
    if InCombatLockdown() then return end
    if not sender or issecretvalue(sender) then return end

    local displayName = sender:match("^([^%-]+)") or sender
    ShowWhisperAlert(displayName)
end

-- == AH FILTER ==

local hookSet = false

local function ApplyAHFilter()
    if not UIThingsDB.misc.ahFilter then return end

    if not AuctionHouseFrame then return end

    -- Function to apply filter
    local function SetFilter()
        if not UIThingsDB.misc.ahFilter then return end
        local searchBar = AuctionHouseFrame.SearchBar
        if searchBar and searchBar.FilterButton then
            searchBar.FilterButton.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
            searchBar:UpdateClearFiltersButton()
        end
    end

    -- Apply immediately (with slight delay for ensuring frame is ready)
    addonTable.Core.SafeAfter(0, SetFilter)

    -- Re-apply on tab switches via global hook (safe — no frame-object tainting)
    if not hookSet and AuctionHouseFrame_SetDisplayMode then
        hooksecurefunc("AuctionHouseFrame_SetDisplayMode", function()
            addonTable.Core.SafeAfter(0, SetFilter)
        end)
        hookSet = true
    end
end

-- == WORK ORDER FILTER ==

local function ApplyWorkOrderFilter()
    if not UIThingsDB.misc.workOrderFilter then return end

    if not ProfessionsCustomerOrdersFrame then return end

    local function SetFilter()
        if not UIThingsDB.misc.workOrderFilter then return end
        local browseOrders = ProfessionsCustomerOrdersFrame.BrowseOrders
        if not browseOrders or not browseOrders.SearchBar then return end
        local filterDropdown = browseOrders.SearchBar.FilterDropdown
        if filterDropdown and filterDropdown.filters then
            filterDropdown.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
        end
    end

    -- Apply with slight delay for ensuring frame is ready
    addonTable.Core.SafeAfter(0, SetFilter)
end

-- == UI SCALING ==

local function ApplyUIScale()
    if not UIThingsDB.misc.uiScaleEnabled then return end

    local scale = UIThingsDB.misc.uiScale or 0.711
    scale = tonumber(string.format("%.3f", scale))

    -- Apply directly to UIParent — avoid SetCVar("uiScale") which triggers
    -- Blizzard's internal CVar scaling callback and overrides this call.
    if not InCombatLockdown() then
        UIParent:SetScale(scale)
    end
end

-- Expose ApplyUIScale
function Misc.ApplyUIScale()
    ApplyUIScale()
end

-- == EVENTS ==

-- Slash command for /rl
SLASH_LUNAUIRELOAD1 = "/rl"
SlashCmdList["LUNAUIRELOAD"] = function()
    if UIThingsDB.misc.enabled and UIThingsDB.misc.allowRL then
        ReloadUI()
    else
        -- If LunaUI isn't handling it, pass it to standard /reload or just do nothing
        -- This ensures we don't block other addons if our feature is disabled
        StaticPopup_Show("RELOAD_UI")
    end
end

local keywordCache = {}

function Misc.UpdateAutoInviteKeywords()
    table.wipe(keywordCache)
    local settings = UIThingsDB.misc
    -- Safety check for settings availability
    if not settings then return end

    if not settings.autoInviteEnabled or not settings.autoInviteKeywords or settings.autoInviteKeywords == "" then return end

    for kw in string.gmatch(settings.autoInviteKeywords, "([^,]+)") do
        table.insert(keywordCache, kw:trim():lower())
    end
end

-- == QUICK ITEM DESTROY ==
local quickDestroyHooked = false
local deleteButton = nil

function Misc.ToggleQuickDestroy(enabled)
    if not enabled then return end

    if not quickDestroyHooked then
        hooksecurefunc("StaticPopup_Show", function(which)
            if not UIThingsDB.misc.quickDestroy then return end

            if which == "DELETE_GOOD_ITEM" or which == "DELETE_GOOD_QUEST_ITEM" then
                -- StaticPopup_Visible returns a string name (e.g. "StaticPopup1"), not a frame
                local dialogName = StaticPopup_Visible(which)
                if not dialogName then return end
                local dialog = _G[dialogName]
                if not dialog then return end

                pcall(function()
                    if dialog.IsForbidden and dialog:IsForbidden() then return end

                    local editBox = dialog.editBox or _G[dialogName .. "EditBox"]
                    local button1 = dialog.button1 or _G[dialogName .. "Button1"]

                    if not editBox or not button1 then return end
                    if (editBox.IsForbidden and editBox:IsForbidden()) then return end
                    if (button1.IsForbidden and button1:IsForbidden()) then return end

                    -- Hide the edit box so the user doesn't need to type "DELETE"
                    editBox:SetAlpha(0)
                    editBox:EnableMouse(false)
                    editBox:ClearFocus()

                    -- Create or reuse the quick-delete button
                    if not deleteButton then
                        deleteButton = CreateFrame("Button", "LunaQuickDestroyButton", nil, "UIPanelButtonTemplate")
                        deleteButton:SetSize(120, 30)
                        deleteButton:SetText("DELETE")
                        deleteButton:SetNormalFontObject("GameFontNormalHuge")
                        deleteButton:SetHighlightFontObject("GameFontHighlightHuge")

                        local fontStr = deleteButton:GetFontString()
                        if fontStr then fontStr:SetTextColor(1, 0.1, 0.1) end
                    end

                    -- Wire up the click to fill the confirm text and accept
                    deleteButton:SetScript("OnClick", function()
                        pcall(function()
                            if editBox:IsForbidden() then return end
                            -- SetText fires OnTextChanged internally, enabling button1
                            editBox:SetText(DELETE_ITEM_CONFIRM_STRING)
                            if not button1:IsForbidden() then
                                button1:Enable()
                                button1:Click()
                            end
                        end)
                    end)

                    deleteButton:SetParent(dialog)
                    deleteButton:ClearAllPoints()
                    deleteButton:SetPoint("CENTER", editBox, "CENTER", 0, 0)
                    deleteButton:SetFrameLevel(editBox:GetFrameLevel() + 5)
                    deleteButton:Show()
                end)
            end
        end)
        quickDestroyHooked = true
    end
end

-- Initialize Hook if enabled at start
if UIThingsDB and UIThingsDB.misc and UIThingsDB.misc.quickDestroy then
    Misc.ToggleQuickDestroy(true)
end

local EventBus = addonTable.EventBus
local ApplyMiscEvents                          -- forward declaration
local HookTooltipClassColors                   -- forward declaration
local HookTooltipSpellID                       -- forward declaration
local RegisterMiscEvents, UnregisterMiscEvents -- forward declarations (defined below)
local miscEventsRegistered = false

-- Named event callbacks
-- == PLUME BUFF ALERT ==

local plumeAlertFrame = CreateFrame("Frame", "UIThingsPlumeAlert", UIParent, "BackdropTemplate")
plumeAlertFrame:SetSize(400, 50)
plumeAlertFrame:SetPoint("TOP", 0, -380)
plumeAlertFrame:SetFrameStrata("DIALOG")
plumeAlertFrame:Hide()

plumeAlertFrame.text = plumeAlertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
plumeAlertFrame.text:SetPoint("CENTER")
plumeAlertFrame.text:SetTextColor(1, 0.2, 0.2, 1)

local function CheckPlumeBuff()
    if InCombatLockdown() then return end
    if not UIThingsDB.misc.plumeAlert then return end
    if C_ChallengeMode.IsChallengeModeActive() then return end

    for i = 1, 40 do
        local auraData = C_UnitAuras.GetBuffDataByIndex("player", i)
        if not auraData then break end
        local name = auraData.name
        if name and (name == "Umbral Plume" or name == "Radiant Plume") then
            local data = C_TooltipInfo.GetUnitAura("player", i, "HELPFUL")
            if data and data.lines then
                for _, line in ipairs(data.lines) do
                    local text = line.leftText
                    if text and text:match("increased by") then
                        local value = tonumber(text:match("increased by (%d+)"))
                        if value and value < 100 then
                            plumeAlertFrame.text:SetText(string.format("%s: %d (below 100!)", name, value))
                            plumeAlertFrame:Show()
                            addonTable.Core.SafeAfter(10, function()
                                plumeAlertFrame:Hide()
                            end)
                        end
                        return
                    end
                end
            end
        end
    end
end

local function OnPlayerEnteringWorld()
    if not UIThingsDB.misc then return end
    ApplyMiscEvents()
    if UIThingsDB.misc.enabled then
        Misc.UpdateAutoInviteKeywords()
        if UIThingsDB.misc.quickDestroy then
            Misc.ToggleQuickDestroy(true)
        end
        if UIThingsDB.misc.classColorTooltips then
            HookTooltipClassColors()
        end
        if UIThingsDB.misc.showSpellID then
            HookTooltipSpellID()
        end
        addonTable.Core.SafeAfter(3, CheckForPersonalOrders)
        addonTable.Core.SafeAfter(2, CheckPlumeBuff)
    end
end

local function OnAuctionHouseShow()
    if not UIThingsDB.misc or not UIThingsDB.misc.enabled then return end
    addonTable.Core.SafeAfter(0.5, ApplyAHFilter)
end

local function OnWorkOrderShow()
    if not UIThingsDB.misc or not UIThingsDB.misc.enabled then return end
    addonTable.Core.SafeAfter(0.5, ApplyWorkOrderFilter)
end

local function OnChatMsgSystem(event, msg)
    if not UIThingsDB.misc or not UIThingsDB.misc.enabled then return end
    if not UIThingsDB.misc.personalOrders then return end
    if issecretvalue(msg) then return end
    if msg and (string.find(msg, "Personal Crafting Order") or string.find(msg, "Personal Order")) then
        ShowAlert()
    end
end

local function OnUpdatePendingMail()
    if not UIThingsDB.misc or not UIThingsDB.misc.enabled then return end
    if not UIThingsDB.misc.mailNotification then return end
    if HasNewMail() and not mailAlertShown then
        mailAlertShown = true
        ShowMailAlert()
    end
end

local function OnMailClosedMisc()
    -- Reset after visiting the mailbox so new mail arriving later fires the alert again
    mailAlertShown = false
end

local function OnPartyInviteRequest(event, name, isTank, isHealer, isDamage, isNativeRealm, allowMultipleRoles,
                                    inviterGUID)
    if not UIThingsDB.misc or not UIThingsDB.misc.enabled then return end
    local settings = UIThingsDB.misc

    if settings.autoAcceptEveryone then
        AcceptGroup()
        StaticPopup_Hide("PARTY_INVITE")
        return
    end

    local isFriend = false
    if settings.autoAcceptFriends then
        if inviterGUID and C_FriendList.IsFriend(inviterGUID) then
            isFriend = true
        end
        if not isFriend then
            local numBNet = BNGetNumFriends()
            for i = 1, numBNet do
                local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
                if accountInfo and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.playerGuid == inviterGUID then
                    isFriend = true
                    break
                end
            end
        end
    end

    local isGuildMember = false
    if settings.autoAcceptGuild and name then
        if C_GuildInfo.MemberExistsByName(name) then
            isGuildMember = true
        end
    end

    if isFriend or isGuildMember then
        AcceptGroup()
        StaticPopup_Hide("PARTY_INVITE")
    end
end

local function OnChatMsgWhisper(event, msg, sender)
    if not UIThingsDB.misc or not UIThingsDB.misc.enabled then return end
    local settings = UIThingsDB.misc
    if not settings.autoInviteEnabled or not keywordCache or #keywordCache == 0 then return end
    if issecretvalue(msg) then return end
    local lowerMsg = msg:trim():lower()
    local match = false
    for _, kw in ipairs(keywordCache) do
        if lowerMsg == kw then
            match = true; break
        end
    end
    if match then
        if not IsInGroup() or UnitIsGroupLeader("player") then
            C_PartyInfo.InviteUnit(sender)
        end
    end
end

-- Class-colored unit tooltip names
local tooltipHooked = false
HookTooltipClassColors = function()
    if tooltipHooked then return end
    tooltipHooked = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, tooltipData)
        if tooltip ~= GameTooltip then return end
        if not UIThingsDB.misc or not UIThingsDB.misc.enabled then return end
        if not UIThingsDB.misc.classColorTooltips then return end
        -- Bail out if guid is secret — tooltip:GetUnit() internally calls UnitName()
        -- on a unit token derived from the guid, which errors on secret values.
        if tooltipData and tooltipData.guid and issecretvalue(tooltipData.guid) then return end
        local _, unit = tooltip:GetUnit()
        if not unit or issecretvalue(unit) or not UnitIsPlayer(unit) then return end
        local _, classFile = UnitClass(unit)
        if not classFile then return end
        local color = C_ClassColor.GetClassColor(classFile)
        if not color then return end
        local name = GameTooltipTextLeft1
        if name then
            name:SetTextColor(color.r, color.g, color.b)
        end
    end)
end

-- Spell/Item ID on tooltips
local spellIDHooked = false
HookTooltipSpellID = function()
    if spellIDHooked then return end
    spellIDHooked = true

    local function AddIDLine(tooltip, id, label)
        if not UIThingsDB.misc or not UIThingsDB.misc.enabled then return end
        if not UIThingsDB.misc.showSpellID then return end
        tooltip:AddLine(string.format("|cFFAAAAAA%s %d|r", label, id))
    end

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)
        if tooltip ~= GameTooltip then return end
        if data and data.id and not issecretvalue(data.id) and data.id > 0 then
            AddIDLine(tooltip, data.id, "Spell ID:")
        end
    end)

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
        if data and data.id and not issecretvalue(data.id) and data.id > 0 then
            AddIDLine(tooltip, data.id, "Item ID:")
        end
    end)

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Action, function(tooltip, data)
        if tooltip ~= GameTooltip then return end
        if not data or not data.actionSlot or issecretvalue(data.actionSlot) then return end
        -- Actions backed by a spell
        local actionType, id = GetActionInfo(data.actionSlot)
        if actionType == "spell" and id and id > 0 then
            AddIDLine(tooltip, id, "Spell ID:")
        elseif actionType == "item" and id and id > 0 then
            AddIDLine(tooltip, id, "Item ID:")
        end
    end)
end

ApplyMiscEvents = function()
    if not UIThingsDB.misc or not UIThingsDB.misc.enabled then
        EventBus.Unregister("AUCTION_HOUSE_SHOW", OnAuctionHouseShow)
        EventBus.Unregister("CRAFTINGORDERS_SHOW_CUSTOMER", OnWorkOrderShow)
        EventBus.Unregister("CHAT_MSG_SYSTEM", OnChatMsgSystem)
        EventBus.Unregister("UPDATE_PENDING_MAIL", OnUpdatePendingMail)
        EventBus.Unregister("MAIL_CLOSED", OnMailClosedMisc)
        EventBus.Unregister("PARTY_INVITE_REQUEST", OnPartyInviteRequest)
        EventBus.Unregister("CHAT_MSG_WHISPER", OnChatMsgWhisper)
        EventBus.Unregister("CHAT_MSG_BN_WHISPER", OnChatMsgWhisper)
        EventBus.Unregister("CHAT_MSG_LOOT", OnChatMsgLootBoE)
        EventBus.Unregister("UNIT_HEALTH", OnUnitHealth)
        EventBus.Unregister("GROUP_ROSTER_UPDATE", OnGroupRosterUpdate)
        EventBus.Unregister("CHAT_MSG_WHISPER", OnChatMsgWhisperAlert)
        EventBus.Unregister("CHAT_MSG_BN_WHISPER", OnChatMsgWhisperAlert)
        wipe(deathAnnounced)
        return
    end

    if UIThingsDB.misc.ahFilter then
        EventBus.Register("AUCTION_HOUSE_SHOW", OnAuctionHouseShow, "Misc")
    else
        EventBus.Unregister("AUCTION_HOUSE_SHOW", OnAuctionHouseShow)
    end

    if UIThingsDB.misc.workOrderFilter then
        EventBus.Register("CRAFTINGORDERS_SHOW_CUSTOMER", OnWorkOrderShow, "Misc")
    else
        EventBus.Unregister("CRAFTINGORDERS_SHOW_CUSTOMER", OnWorkOrderShow)
    end

    if UIThingsDB.misc.personalOrders then
        EventBus.Register("CHAT_MSG_SYSTEM", OnChatMsgSystem, "Misc")
    else
        EventBus.Unregister("CHAT_MSG_SYSTEM", OnChatMsgSystem)
    end

    if UIThingsDB.misc.mailNotification then
        EventBus.Register("UPDATE_PENDING_MAIL", OnUpdatePendingMail, "Misc")
        EventBus.Register("MAIL_CLOSED", OnMailClosedMisc, "Misc")
        -- Check immediately in case UPDATE_PENDING_MAIL already fired before we registered
        OnUpdatePendingMail()
    else
        EventBus.Unregister("UPDATE_PENDING_MAIL", OnUpdatePendingMail)
        EventBus.Unregister("MAIL_CLOSED", OnMailClosedMisc)
    end

    if UIThingsDB.misc.autoAcceptFriends or UIThingsDB.misc.autoAcceptGuild or UIThingsDB.misc.autoAcceptEveryone then
        EventBus.Register("PARTY_INVITE_REQUEST", OnPartyInviteRequest, "Misc")
    else
        EventBus.Unregister("PARTY_INVITE_REQUEST", OnPartyInviteRequest)
    end

    if UIThingsDB.misc.autoInviteEnabled then
        EventBus.Register("CHAT_MSG_WHISPER", OnChatMsgWhisper, "Misc")
        -- BN whispers not supported for auto-invite; keep unregistered
        EventBus.Unregister("CHAT_MSG_BN_WHISPER", OnChatMsgWhisper)
    else
        EventBus.Unregister("CHAT_MSG_WHISPER", OnChatMsgWhisper)
        EventBus.Unregister("CHAT_MSG_BN_WHISPER", OnChatMsgWhisper)
        table.wipe(keywordCache)
    end

    if UIThingsDB.misc.boeAlert then
        EventBus.Register("CHAT_MSG_LOOT", OnChatMsgLootBoE, "Misc")
    else
        EventBus.Unregister("CHAT_MSG_LOOT", OnChatMsgLootBoE)
    end

    if UIThingsDB.misc.deathNotify then
        EventBus.Register("UNIT_HEALTH", OnUnitHealth, "Misc")
        EventBus.Register("GROUP_ROSTER_UPDATE", OnGroupRosterUpdate, "Misc")
    else
        EventBus.Unregister("UNIT_HEALTH", OnUnitHealth)
        EventBus.Unregister("GROUP_ROSTER_UPDATE", OnGroupRosterUpdate)
        wipe(deathAnnounced)
    end

    if UIThingsDB.misc.whisperAlert then
        EventBus.Register("CHAT_MSG_WHISPER", OnChatMsgWhisperAlert, "Misc")
        EventBus.Register("CHAT_MSG_BN_WHISPER", OnChatMsgWhisperAlert, "Misc")
    else
        EventBus.Unregister("CHAT_MSG_WHISPER", OnChatMsgWhisperAlert)
        EventBus.Unregister("CHAT_MSG_BN_WHISPER", OnChatMsgWhisperAlert)
    end

    if UIThingsDB.misc.classColorTooltips then
        HookTooltipClassColors()
    end
    if UIThingsDB.misc.showSpellID then
        HookTooltipSpellID()
    end
end

RegisterMiscEvents = function()
    if miscEventsRegistered then return end
    miscEventsRegistered = true
    EventBus.Register("PLAYER_ENTERING_WORLD", OnPlayerEnteringWorld, "Misc")
end

UnregisterMiscEvents = function()
    if not miscEventsRegistered then return end
    miscEventsRegistered = false
    EventBus.Unregister("PLAYER_ENTERING_WORLD", OnPlayerEnteringWorld)
    ApplyMiscEvents() -- unregisters all sub-feature events
end

-- PLAYER_LOGIN fires once per session; bootstrap registration if enabled
EventBus.Register("PLAYER_LOGIN", function()
    if UIThingsDB and UIThingsDB.misc then
        if UIThingsDB.misc.enabled then
            ApplyUIScale()
            RegisterMiscEvents()
        end
    end
end, "Misc")

function Misc.ApplyEvents()
    if UIThingsDB.misc and UIThingsDB.misc.enabled then
        RegisterMiscEvents()
        ApplyMiscEvents()
    else
        UnregisterMiscEvents()
    end
end
