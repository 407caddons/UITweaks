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

    -- TTS using correct API (only if enabled)
    if UIThingsDB.misc.ttsEnabled then
        local message = UIThingsDB.misc.ttsMessage or "Personal order arrived"
        local voiceType = UIThingsDB.misc.ttsVoice or 0

        if TextToSpeech_Speak then
            local voiceID = TextToSpeech_GetSelectedVoice and TextToSpeech_GetSelectedVoice(voiceType) or nil
            pcall(function()
                TextToSpeech_Speak(message, voiceID)
            end)
        elseif C_VoiceChat and C_VoiceChat.SpeakText then
            pcall(function()
                C_VoiceChat.SpeakText(0, message, voiceType, 1.0, false)
            end)
        end
    end

    -- Hide after duration
    local duration = UIThingsDB.misc.alertDuration or 5
    local SafeAfter = function(delay, func)
        if addonTable.Core and addonTable.Core.SafeAfter then
            addonTable.Core.SafeAfter(delay, func)
        elseif C_Timer and C_Timer.After then
            C_Timer.After(delay, func)
        end
    end
    SafeAfter(duration, function()
        alertFrame:Hide()
    end)
end

-- Expose ShowAlert for test button
function Misc.ShowAlert()
    ShowAlert()
end

-- Expose for testing
function Misc.TestTTS()
    local message = UIThingsDB.misc.ttsMessage or "Personal order arrived"
    local voiceType = UIThingsDB.misc.ttsVoice or 0

    -- Method 1: Try TextToSpeech_Speak (global function)
    if TextToSpeech_Speak then
        local voiceID = TextToSpeech_GetSelectedVoice and TextToSpeech_GetSelectedVoice(voiceType) or nil
        pcall(function()
            TextToSpeech_Speak(message, voiceID)
        end)
        return
    end

    -- Method 2: Try C_VoiceChat.SpeakText
    if C_VoiceChat and C_VoiceChat.SpeakText then
        pcall(function()
            C_VoiceChat.SpeakText(0, message, voiceType, 1.0, false)
        end)
    end
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
    local SafeAfter = function(delay, func)
        if addonTable.Core and addonTable.Core.SafeAfter then
            addonTable.Core.SafeAfter(delay, func)
        elseif C_Timer and C_Timer.After then
            C_Timer.After(delay, func)
        end
    end
    SafeAfter(0, SetFilter)

    -- Hook for persistence (Tab switching or re-showing)
    if not hookSet then
        if AuctionHouseFrame.SearchBar then
            AuctionHouseFrame.SearchBar:HookScript("OnShow", function()
                SafeAfter(0, SetFilter)
            end)
            hookSet = true
        end
    end
end

-- == UI SCALING ==

local function ApplyUIScale()
    if not UIThingsDB.misc.uiScaleEnabled then return end

    local scale = UIThingsDB.misc.uiScale or 0.711
    -- Round to 3 decimal places to avoid precision issues with CVars
    scale = tonumber(string.format("%.3f", scale))
    
    SetCVar("useUiScale", "1")
    SetCVar("uiScale", tostring(scale))
    
    -- Force UIParent scale to bypass internal 0.64 floor in TWW
    UIParent:SetScale(scale)
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

local function OnEvent(self, event, ...)
    if not UIThingsDB.misc or not UIThingsDB.misc.enabled then return end

    if event == "PLAYER_ENTERING_WORLD" then
        ApplyUIScale()
    elseif event == "AUCTION_HOUSE_SHOW" then
        -- Apply once initially
        local SafeAfter = function(delay, func)
            if addonTable.Core and addonTable.Core.SafeAfter then
                addonTable.Core.SafeAfter(delay, func)
            elseif C_Timer and C_Timer.After then
                C_Timer.After(delay, func)
            end
        end
        SafeAfter(0.5, ApplyAHFilter)
    elseif event == "CHAT_MSG_SYSTEM" then
        local msg = ...
        -- Parse for "Personal Work Order" or similar text
        if msg and (string.find(msg, "Personal Crafting Order") or string.find(msg, "Personal Order")) then
            ShowAlert()
        end
    elseif event == "PARTY_INVITE_REQUEST" then
        local name, guid = ...
        local settings = UIThingsDB.misc

        if settings.autoAcceptEveryone then
            AcceptGroup()
            StaticPopup_Hide("PARTY_INVITE")
            return
        end

        local isFriend = false
        if settings.autoAcceptFriends then
            if guid and C_FriendList.IsFriend(guid) then
                isFriend = true
            else
                -- Check BNet Friends
                local numBNet = BNGetNumFriends()
                for i = 1, numBNet do
                    local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
                    if accountInfo and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.playerGuid == guid then
                        isFriend = true
                        break
                    end
                end
            end
        end

        local isGuildMember = false
        if settings.autoAcceptGuild then
            if guid and IsGuildMember(guid) then
                isGuildMember = true
            end
        end

        if isFriend or isGuildMember then
            AcceptGroup()
            StaticPopup_Hide("PARTY_INVITE")
        end
    elseif event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
        local settings = UIThingsDB.misc
        if not settings.autoInviteEnabled or not settings.autoInviteKeywords or settings.autoInviteKeywords == "" then return end

        local msg, sender = ...
        if event == "CHAT_MSG_BN_WHISPER" then
            -- For BN whispers, sender is the presenceID, we need to get the character name/presence
            -- However, C_PartyInfo.InviteUnit usually wants a name-realm or UnitTag.
            -- BN whispers are tricky for auto-invites unless we resolve the character.
            -- For now, let's focus on character whispers first as they are more common for group formation.
            return 
        end

        -- Split keywords and check
        local keywords = {}
        for kw in string.gmatch(settings.autoInviteKeywords, "([^,]+)") do
            table.insert(keywords, kw:trim():lower())
        end

        local lowerMsg = msg:trim():lower()
        local match = false
        for _, kw in ipairs(keywords) do
            if lowerMsg == kw then
                match = true
                break
            end
        end

        if match then
            -- Can we invite? (Must be leader or not in group)
            if not IsInGroup() or UnitIsGroupLeader("player") then
                C_PartyInfo.InviteUnit(sender)
            end
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PARTY_INVITE_REQUEST")
frame:RegisterEvent("CHAT_MSG_WHISPER")
frame:RegisterEvent("CHAT_MSG_BN_WHISPER")
frame:SetScript("OnEvent", OnEvent)
