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
    addonTable.Core.SafeAfter(duration, function()
        alertFrame:Hide()
    end)
end

-- Expose ShowAlert for test button
function Misc.ShowAlert()
    ShowAlert()
end

-- == MAIL NOTIFICATION ==

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
    local message = UIThingsDB.misc.mailTtsMessage or "You've got mail"
    local voiceType = UIThingsDB.misc.mailTtsVoice or 0

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
    addonTable.Core.SafeAfter(0, SetFilter)

    -- Hook for persistence (Tab switching or re-showing)
    if not hookSet then
        if AuctionHouseFrame.SearchBar then
            AuctionHouseFrame.SearchBar:HookScript("OnShow", function()
                addonTable.Core.SafeAfter(0, SetFilter)
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

-- == SCROLLING COMBAT TEXT ==

local sctDamageAnchor = CreateFrame("Frame", "LunaSCTDamageAnchor", UIParent, "BackdropTemplate")
sctDamageAnchor:SetSize(150, 20)
sctDamageAnchor:SetMovable(true)
sctDamageAnchor:SetClampedToScreen(true)
sctDamageAnchor:EnableMouse(false)
sctDamageAnchor:RegisterForDrag("LeftButton")
sctDamageAnchor:SetScript("OnDragStart", sctDamageAnchor.StartMoving)
sctDamageAnchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    UIThingsDB.misc.sct.damageAnchor = { point = point, relPoint = relPoint, x = x, y = y }
end)
sctDamageAnchor:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
sctDamageAnchor:SetBackdropColor(1, 0.2, 0.2, 0.6)
sctDamageAnchor.text = sctDamageAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
sctDamageAnchor.text:SetPoint("CENTER")
sctDamageAnchor.text:SetText("SCT Damage")
sctDamageAnchor:Hide()

local sctHealingAnchor = CreateFrame("Frame", "LunaSCTHealingAnchor", UIParent, "BackdropTemplate")
sctHealingAnchor:SetSize(150, 20)
sctHealingAnchor:SetMovable(true)
sctHealingAnchor:SetClampedToScreen(true)
sctHealingAnchor:EnableMouse(false)
sctHealingAnchor:RegisterForDrag("LeftButton")
sctHealingAnchor:SetScript("OnDragStart", sctHealingAnchor.StartMoving)
sctHealingAnchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    UIThingsDB.misc.sct.healingAnchor = { point = point, relPoint = relPoint, x = x, y = y }
end)
sctHealingAnchor:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
sctHealingAnchor:SetBackdropColor(0.2, 1, 0.2, 0.6)
sctHealingAnchor.text = sctHealingAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
sctHealingAnchor.text:SetPoint("CENTER")
sctHealingAnchor.text:SetText("SCT Healing")
sctHealingAnchor:Hide()

-- SCT Frame Pool
local sctPool = {}
local sctActive = {}
local SCT_MAX_ACTIVE = 30

local function RecycleSCTFrame(f)
    f:Hide()
    f:ClearAllPoints()
    for i, active in ipairs(sctActive) do
        if active == f then
            table.remove(sctActive, i)
            break
        end
    end
    table.insert(sctPool, f)
end

local function AcquireSCTFrame()
    -- Cap active frames
    if #sctActive >= SCT_MAX_ACTIVE then
        RecycleSCTFrame(sctActive[1])
    end

    local f = table.remove(sctPool)
    if not f then
        f = CreateFrame("Frame", nil, UIParent)
        f:SetFrameStrata("HIGH")
        f.text = f:CreateFontString(nil, "OVERLAY")
        f.text:SetPoint("CENTER")
        f:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            local progress = self.elapsed / self.duration
            if progress >= 1 then
                RecycleSCTFrame(self)
                return
            end
            -- Move upward
            local yOffset = self.scrollDistance * progress
            self:ClearAllPoints()
            self:SetPoint("BOTTOM", self.anchor, "TOP", 0, yOffset)
            -- Fade out in last 30%
            if progress > 0.7 then
                self:SetAlpha(1 - ((progress - 0.7) / 0.3))
            else
                self:SetAlpha(1)
            end
        end)
    end
    return f
end

-- category: "damage" or "healing"
local function SpawnSCTText(amount, isCrit, category, targetName)
    local settings = UIThingsDB.misc.sct
    if not settings or not settings.enabled then return end
    if category == "damage" and not settings.showDamage then return end
    if category == "healing" and not settings.showHealing then return end

    local color, anchor
    if category == "damage" then
        color = settings.damageColor
        anchor = sctDamageAnchor
    else
        color = settings.healingColor
        anchor = sctHealingAnchor
    end

    local f = AcquireSCTFrame()
    local fontSize = settings.fontSize
    if isCrit then
        fontSize = math.floor(fontSize * settings.critScale)
    end

    f.text:SetFont(settings.font or "Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
    f.text:SetTextColor(color.r, color.g, color.b)

    -- Build display text
    local displayText = tostring(amount)
    if isCrit then
        displayText = displayText .. "*"
    end
    local showName = (category == "damage" and settings.showTargetDamage) or
        (category == "healing" and settings.showTargetHealing)
    if showName and targetName and targetName ~= "" then
        displayText = displayText .. " (" .. targetName .. ")"
    end
    f.text:SetText(displayText)

    f:SetSize(f.text:GetStringWidth() + 10, f.text:GetStringHeight() + 4)
    f:ClearAllPoints()
    f:SetPoint("BOTTOM", anchor, "TOP", 0, 0)

    f.elapsed = 0
    f.duration = settings.duration
    f.scrollDistance = settings.scrollDistance
    f.anchor = anchor

    f:SetAlpha(1)
    f:Show()
    table.insert(sctActive, f)
end

local function InitSCTAnchors()
    local settings = UIThingsDB.misc.sct
    if not settings then return end

    local da = settings.damageAnchor
    sctDamageAnchor:ClearAllPoints()
    sctDamageAnchor:SetPoint(da.point, UIParent, da.relPoint or da.point, da.x, da.y)

    local ha = settings.healingAnchor
    sctHealingAnchor:ClearAllPoints()
    sctHealingAnchor:SetPoint(ha.point, UIParent, ha.relPoint or ha.point, ha.x, ha.y)
end

function Misc.UpdateSCTSettings()
    InitSCTAnchors()

    local settings = UIThingsDB.misc.sct
    if not settings then return end

    if settings.locked then
        sctDamageAnchor:EnableMouse(false)
        sctDamageAnchor:Hide()
        sctHealingAnchor:EnableMouse(false)
        sctHealingAnchor:Hide()
    else
        sctDamageAnchor:EnableMouse(true)
        sctDamageAnchor:Show()
        sctHealingAnchor:EnableMouse(true)
        sctHealingAnchor:Show()
    end
end

function Misc.LockSCTAnchors()
    if UIThingsDB.misc.sct then
        UIThingsDB.misc.sct.locked = true
        Misc.UpdateSCTSettings()
    end
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
                            editBox:SetText(DELETE_ITEM_CONFIRM_STRING)
                            local onTextChanged = editBox:GetScript("OnTextChanged")
                            if onTextChanged then
                                onTextChanged(editBox)
                            end
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

local ApplyMiscEvents -- forward declaration

local function OnEvent(self, event, ...)
    if not UIThingsDB.misc then return end

    if event == "PLAYER_ENTERING_WORLD" then
        ApplyMiscEvents()
        if UIThingsDB.misc.enabled then
            ApplyUIScale()
            Misc.UpdateAutoInviteKeywords()
            InitSCTAnchors()

            -- Init Quick Destroy Hook
            if UIThingsDB.misc.quickDestroy then
                Misc.ToggleQuickDestroy(true)
            end

            -- Check for personal orders after a delay (to ensure API is ready)
            addonTable.Core.SafeAfter(3, CheckForPersonalOrders)
        end
    elseif event == "AUCTION_HOUSE_SHOW" then
        if not UIThingsDB.misc.enabled then return end
        -- Apply once initially
        addonTable.Core.SafeAfter(0.5, ApplyAHFilter)
    elseif event == "CHAT_MSG_SYSTEM" then
        if not UIThingsDB.misc.enabled then return end
        if not UIThingsDB.misc.personalOrders then return end
        local msg = ...
        if issecretvalue(msg) then return end
        -- Parse for "Personal Work Order" or similar text
        if msg and (string.find(msg, "Personal Crafting Order") or string.find(msg, "Personal Order")) then
            ShowAlert()
        end
    elseif event == "UPDATE_PENDING_MAIL" then
        if not UIThingsDB.misc.enabled then return end
        if not UIThingsDB.misc.mailNotification then return end
        if HasNewMail() then
            ShowMailAlert()
        end
    elseif event == "PARTY_INVITE_REQUEST" then
        if not UIThingsDB.misc.enabled then return end
        local name, isTank, isHealer, isDamage, isNativeRealm, allowMultipleRoles, inviterGUID = ...
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
                -- Check BNet Friends
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
    elseif event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
        if not UIThingsDB.misc.enabled then return end
        local settings = UIThingsDB.misc
        if not settings.autoInviteEnabled or not keywordCache or #keywordCache == 0 then return end

        local msg, sender = ...
        if event == "CHAT_MSG_BN_WHISPER" then
            -- For BN whispers, sender is the presenceID, we need to get the character name/presence
            -- However, C_PartyInfo.InviteUnit usually wants a name-realm or UnitTag.
            -- BN whispers are tricky for auto-invites unless we resolve the character.
            -- For now, let's focus on character whispers first as they are more common for group formation.
            return
        end

        local lowerMsg = msg:trim():lower()
        local match = false
        for _, kw in ipairs(keywordCache) do
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
    elseif event == "UNIT_COMBAT" then
        if not UIThingsDB.misc.enabled then return end
        local sctSettings = UIThingsDB.misc.sct
        if not sctSettings or not sctSettings.captureToFrames then return end
        local unitTarget, combatEvent, flagText, amount, schoolMask = ...
        if not amount or issecretvalue(amount) then return end
        if amount == 0 then return end
        local isCrit = (not issecretvalue(flagText) and flagText == "CRITICAL")

        if unitTarget == "player" then
            -- Incoming healing to the player
            if combatEvent == "HEAL" then
                local targetName = nil
                if sctSettings.showTargetHealing then
                    targetName = UnitName("target")
                end
                SpawnSCTText(amount, isCrit, "healing", targetName)
            end
        elseif string.find(unitTarget, "nameplate") then
            -- Use nameplates only for outgoing to avoid duplicates (target/softfriend fire too)
            if combatEvent == "WOUND" then
                local targetName = nil
                if sctSettings.showTargetDamage then
                    targetName = UnitName(unitTarget)
                end
                SpawnSCTText(amount, isCrit, "damage", targetName)
            end
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD") -- Always needed for initialization
frame:SetScript("OnEvent", OnEvent)

ApplyMiscEvents = function()
    if not UIThingsDB.misc or not UIThingsDB.misc.enabled then
        frame:UnregisterEvent("AUCTION_HOUSE_SHOW")
        frame:UnregisterEvent("CHAT_MSG_SYSTEM")
        frame:UnregisterEvent("PARTY_INVITE_REQUEST")
        frame:UnregisterEvent("CHAT_MSG_WHISPER")
        frame:UnregisterEvent("CHAT_MSG_BN_WHISPER")
        frame:UnregisterEvent("UNIT_COMBAT")
        return
    end

    -- AH filter
    if UIThingsDB.misc.ahFilter then
        frame:RegisterEvent("AUCTION_HOUSE_SHOW")
    else
        frame:UnregisterEvent("AUCTION_HOUSE_SHOW")
    end

    -- Personal orders
    if UIThingsDB.misc.personalOrders then
        frame:RegisterEvent("CHAT_MSG_SYSTEM")
    else
        frame:UnregisterEvent("CHAT_MSG_SYSTEM")
    end

    -- Mail notification
    if UIThingsDB.misc.mailNotification then
        frame:RegisterEvent("UPDATE_PENDING_MAIL")
    else
        frame:UnregisterEvent("UPDATE_PENDING_MAIL")
    end

    -- Auto-accept invites
    if UIThingsDB.misc.autoAcceptFriends or UIThingsDB.misc.autoAcceptGuild or UIThingsDB.misc.autoAcceptEveryone then
        frame:RegisterEvent("PARTY_INVITE_REQUEST")
    else
        frame:UnregisterEvent("PARTY_INVITE_REQUEST")
    end

    -- Auto-invite on whisper
    if UIThingsDB.misc.autoInviteEnabled then
        frame:RegisterEvent("CHAT_MSG_WHISPER")
        frame:RegisterEvent("CHAT_MSG_BN_WHISPER")
    else
        frame:UnregisterEvent("CHAT_MSG_WHISPER")
        frame:UnregisterEvent("CHAT_MSG_BN_WHISPER")
    end

    -- Scrolling Combat Text
    if UIThingsDB.misc.sct then
        -- Enable/disable Blizzard's floating combat text via CVar
        SetCVar("enableFloatingCombatText", UIThingsDB.misc.sct.enabled and 1 or 0)
        -- Capture to our custom frames
        if UIThingsDB.misc.sct.captureToFrames then
            frame:RegisterEvent("UNIT_COMBAT")
        else
            frame:UnregisterEvent("UNIT_COMBAT")
        end
    end
end

function Misc.ApplyEvents()
    ApplyMiscEvents()
end
