local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

table.insert(Widgets.moduleInits, function()
    local friendsFrame = Widgets.CreateWidgetFrame("Friends", "friends")
    friendsFrame:SetScript("OnClick", function() ToggleFriendsFrame() end)

    friendsFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Online Friends")

        -- WoW Friends
        local numFriends = C_FriendList.GetNumFriends()
        local hasWoWFriends = false
        for i = 1, numFriends do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.connected then
                hasWoWFriends = true
                local classColor = C_ClassColor.GetClassColor(info.classFilename)
                local nameText = info.name:match("^([^-]+)") or info.name
                local zone = (info.area and info.area ~= "") and info.area or ""
                local rightText = zone .. "  " .. (info.level or "")

                local r, g, b = 1, 1, 1
                if classColor then
                    r, g, b = classColor.r, classColor.g, classColor.b
                end
                GameTooltip:AddDoubleLine(nameText, rightText, r, g, b, 0.7, 0.7, 0.7)
            end
        end

        -- Battle.Net Friends
        local numBNet = BNGetNumFriends()
        local hasBNetFriends = false
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
                    if not hasBNetFriends and hasWoWFriends then
                        GameTooltip:AddLine(" ")
                    end
                    hasBNetFriends = true

                    local nameText = accountInfo.accountName
                    if gameAccount.characterName then
                        nameText = nameText .. " (" .. gameAccount.characterName .. ")"
                    end

                    local rightText = ""
                    if gameAccount.clientProgram == BNET_CLIENT_WOW then
                        local zone = (gameAccount.areaName and gameAccount.areaName ~= "") and gameAccount.areaName or ""
                        local level = gameAccount.characterLevel and tostring(gameAccount.characterLevel) or ""
                        rightText = zone .. "  " .. level
                    elseif gameAccount.richPresence and gameAccount.richPresence ~= "" then
                        rightText = gameAccount.richPresence
                    end

                    local r, g, b = 0.51, 0.77, 1 -- BNet Blue
                    if gameAccount.classFileName then
                        local classColor = C_ClassColor.GetClassColor(gameAccount.classFileName)
                        if classColor then
                            r, g, b = classColor.r, classColor.g, classColor.b
                        end
                    end

                    GameTooltip:AddDoubleLine(nameText, rightText, r, g, b, 0.7, 0.7, 0.7)
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

    local function OnFriendsUpdate()
        RefreshFriendsCache()
    end

    friendsFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("BN_FRIEND_INFO_CHANGED", OnFriendsUpdate, "W:Friends")
            EventBus.Register("FRIENDLIST_UPDATE", OnFriendsUpdate, "W:Friends")
            EventBus.Register("BN_FRIEND_ACCOUNT_ONLINE", OnFriendsUpdate, "W:Friends")
            EventBus.Register("BN_FRIEND_ACCOUNT_OFFLINE", OnFriendsUpdate, "W:Friends")
            EventBus.Register("PLAYER_ENTERING_WORLD", OnFriendsUpdate, "W:Friends")
        else
            EventBus.Unregister("BN_FRIEND_INFO_CHANGED", OnFriendsUpdate)
            EventBus.Unregister("FRIENDLIST_UPDATE", OnFriendsUpdate)
            EventBus.Unregister("BN_FRIEND_ACCOUNT_ONLINE", OnFriendsUpdate)
            EventBus.Unregister("BN_FRIEND_ACCOUNT_OFFLINE", OnFriendsUpdate)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnFriendsUpdate)
        end
    end

    friendsFrame.UpdateContent = function(self)
        self.text:SetText(cachedText)
    end
end)
