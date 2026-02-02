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
    
    -- TTS
    if C_TextToSpeech and C_TextToSpeech.Speak then
         C_TextToSpeech.Speak(UIThingsDB.misc.ttsMessage or "Personal order arrived")
    end
    
    -- Hide after duration
    local duration = UIThingsDB.misc.alertDuration or 5
    C_Timer.After(duration, function()
        alertFrame:Hide()
    end)
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
    C_Timer.After(0, SetFilter)
    
    -- Hook for persistence (Tab switching or re-showing)
    if not hookSet then
        if AuctionHouseFrame.SearchBar then
             AuctionHouseFrame.SearchBar:HookScript("OnShow", function()
                 C_Timer.After(0, SetFilter)
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
         C_Timer.After(0.5, ApplyAHFilter)
         
    elseif event == "CHAT_MSG_SYSTEM" then
         -- Parse for "Personal Work Order" or similar text
         -- "You have received a new Personal Crafting Order." or similar
         if msg and (string.find(msg, "Personal Crafting Order") or string.find(msg, "Personal Order")) then
             ShowAlert()
         end
         
    end
end)
