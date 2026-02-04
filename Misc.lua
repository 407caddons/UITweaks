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
    
    print("|cFF00FF00[Luna TTS]|r Testing TTS with message: " .. message)
    print("|cFF00FF00[Luna TTS]|r Voice type: " .. (voiceType == 0 and "Standard" or "Alternate 1"))
    
    local success = false
    
    -- Method 1: Try TextToSpeech_Speak (global function)
    if TextToSpeech_Speak then
        local voiceID = TextToSpeech_GetSelectedVoice and TextToSpeech_GetSelectedVoice(voiceType) or nil
        print("|cFF00FF00[Luna TTS]|r Using TextToSpeech_Speak with voice ID: " .. tostring(voiceID))
        local result = pcall(function()
            TextToSpeech_Speak(message, voiceID)
        end)
        if result then
            success = true
            print("|cFF00FF00[Luna TTS]|r TextToSpeech_Speak called successfully")
        else
            print("|cFFFF0000[Luna TTS]|r TextToSpeech_Speak failed")
        end
    else
        print("|cFFFFAA00[Luna TTS]|r TextToSpeech_Speak not available")
    end
    
    -- Method 2: Try C_VoiceChat.SpeakText
    if not success and C_VoiceChat and C_VoiceChat.SpeakText then
        print("|cFF00FF00[Luna TTS]|r Trying C_VoiceChat.SpeakText")
        local result = pcall(function()
            C_VoiceChat.SpeakText(0, message, voiceType, 1.0, false)
        end)
        if result then
            success = true
            print("|cFF00FF00[Luna TTS]|r C_VoiceChat.SpeakText called successfully")
        else
            print("|cFFFF0000[Luna TTS]|r C_VoiceChat.SpeakText failed")
        end
    end
    
    if not success then
        print("|cFFFF0000[Luna TTS]|r No TTS API available. Enable TTS in System > Accessibility > Text-To-Speech")
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

-- == EVENTS ==

local frame = CreateFrame("Frame")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")
frame:RegisterEvent("CHAT_MSG_SYSTEM")

frame:SetScript("OnEvent", function(self, event, msg, ...)
    if not UIThingsDB.misc or not UIThingsDB.misc.enabled then return end
    
    if event == "AUCTION_HOUSE_SHOW" then
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
         -- Parse for "Personal Work Order" or similar text
         -- "You have received a new Personal Crafting Order." or similar
         if msg and (string.find(msg, "Personal Crafting Order") or string.find(msg, "Personal Order")) then
             ShowAlert()
         end
         
    end
end)
