local addonName, addonTable = ...
local Widgets = addonTable.Widgets

table.insert(Widgets.moduleInits, function()
    local friendsFrame = Widgets.CreateWidgetFrame("Friends", "friends")
    friendsFrame:SetScript("OnClick", function() ToggleFriendsFrame() end)

    friendsFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Online Friends")

        -- WoW Friends
        local numFriends = C_FriendList.GetNumFriends()
        for i = 1, numFriends do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.connected then
                local classColor = C_ClassColor.GetClassColor(info.className)
                local nameText = info.name
                local rightText = ""
                if info.level then
                    rightText = "Lvl " .. info.level
                end

                if classColor then
                    GameTooltip:AddDoubleLine(nameText, rightText, classColor.r, classColor.g, classColor.b, 1, 1, 1)
                else
                    GameTooltip:AddDoubleLine(nameText, rightText, 1, 1, 1, 1, 1, 1)
                end
            end
        end

        -- Battle.Net Friends
        local numBNet = BNGetNumFriends()
        for i = 1, numBNet do
            local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
            if accountInfo and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.isOnline then
                local gameAccount = accountInfo.gameAccountInfo

                -- Filter if WoW Only is enabled
                local show = true
                if UIThingsDB.widgets.showWoWOnly and gameAccount.clientProgram ~= BNET_CLIENT_WOW then
                    show = false
                end

                if show then
                    local nameText = accountInfo.accountName
                    if gameAccount.characterName then
                        nameText = nameText .. " (" .. gameAccount.characterName .. ")"
                    end

                    local rightText = ""
                    if gameAccount.clientProgram == BNET_CLIENT_WOW and gameAccount.characterLevel then
                        rightText = "Lvl " .. gameAccount.characterLevel
                    elseif gameAccount.richPresence then
                        rightText = gameAccount.richPresence
                    end

                    local r, g, b = 0.51, 0.77, 1 -- BNet Blue
                    if gameAccount.className then
                        local classColor = C_ClassColor.GetClassColor(gameAccount.className)
                        if classColor then
                            r, g, b = classColor.r, classColor.g, classColor.b
                        end
                    end

                    GameTooltip:AddDoubleLine(nameText, rightText, r, g, b, 1, 1, 1)
                end
            end
        end
        GameTooltip:Show()
    end)
    friendsFrame:SetScript("OnLeave", GameTooltip_Hide)

    -- Cached friend count (updated on events, not every second)
    local cachedText = "Friends: 0"

    local function RefreshFriendsCache()
        local numOnline = C_FriendList.GetNumOnlineFriends() or 0
        local _, numBNetOnline = BNGetNumFriends()

        local bnetCount = 0
        if UIThingsDB.widgets.showWoWOnly then
            local numBNet = BNGetNumFriends()
            for i = 1, numBNet do
                local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
                if accountInfo and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.isOnline then
                    if accountInfo.gameAccountInfo.clientProgram == BNET_CLIENT_WOW then
                        bnetCount = bnetCount + 1
                    end
                end
            end
        else
            bnetCount = numBNetOnline or 0
        end

        cachedText = string.format("Friends: %d", numOnline + bnetCount)
    end

    local friendsEventFrame = CreateFrame("Frame")
    friendsEventFrame:RegisterEvent("BN_FRIEND_INFO_CHANGED")
    friendsEventFrame:RegisterEvent("FRIENDLIST_UPDATE")
    friendsEventFrame:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
    friendsEventFrame:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
    friendsEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    friendsEventFrame:SetScript("OnEvent", function()
        RefreshFriendsCache()
    end)

    friendsFrame.eventFrame = friendsEventFrame
    friendsFrame.ApplyEvents = function(enabled)
        if enabled then
            friendsEventFrame:RegisterEvent("BN_FRIEND_INFO_CHANGED")
            friendsEventFrame:RegisterEvent("FRIENDLIST_UPDATE")
            friendsEventFrame:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
            friendsEventFrame:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
            friendsEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        else
            friendsEventFrame:UnregisterAllEvents()
        end
    end

    friendsFrame.UpdateContent = function(self)
        self.text:SetText(cachedText)
    end
end)
