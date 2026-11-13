local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

-- Reverse lookup: localized class name -> class token ("Mage" -> "MAGE").
-- BNet game account info exposes gameAccount.className (localized) but not
-- classFileName, so we translate back to the token that C_ClassColor expects.
local CLASS_TOKEN_BY_NAME = {}
for token, localName in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do
    CLASS_TOKEN_BY_NAME[localName] = token
end
for token, localName in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do
    CLASS_TOKEN_BY_NAME[localName] = token
end

-- wowProjectID -> game version heading. Forever's own ID is taken from this
-- client when it is running Forever; unknown IDs show their number so they can be named.
local PROJECT_LABELS = {
    [1] = "Midnight (Retail)",
    [2] = "Classic Era",
    [5] = "TBC Classic",
    [11] = "Wrath Classic",
    [14] = "Cataclysm Classic",
    [19] = "MoP Classic",
}
local function VersionLabel(projectID)
    if addonTable.Client and addonTable.Client.isForever and projectID == WOW_PROJECT_ID then return "Forever" end
    if PROJECT_LABELS[projectID] then return PROJECT_LABELS[projectID] end
    return projectID and ("WoW (project " .. projectID .. ")") or "WoW"
end

table.insert(Widgets.moduleInits, function()
    local friendsFrame = Widgets.CreateWidgetFrame("Friends", "friends")
    friendsFrame:SetScript("OnClick", function() ToggleFriendsFrame() end)

    friendsFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        if not Widgets.SmartAnchorTooltip(self) then return end
        GameTooltip:SetText("Online Friends")

        -- Entries are grouped by game version, then printed under a heading each.
        local groups, order = {}, {}
        local function Add(label, left, right, r, g, b)
            if not groups[label] then
                groups[label] = {}
                order[#order + 1] = label
            end
            local list = groups[label]
            list[#list + 1] = { left, right, r, g, b }
        end
        local ownLabel = VersionLabel(WOW_PROJECT_ID)

        -- WoW Friends (always on this client's version)
        local numFriends = C_FriendList.GetNumFriends()
        for i = 1, numFriends do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.connected then
                local classColor = C_ClassColor.GetClassColor(info.classFilename)
                local nameText = info.name:match("^([^-]+)") or info.name
                local zone = (info.area and info.area ~= "") and info.area or ""
                local rightText = zone .. "  " .. (info.level or "")

                local r, g, b = 1, 1, 1
                if classColor then
                    r, g, b = classColor.r, classColor.g, classColor.b
                end
                Add(ownLabel, nameText, rightText, r, g, b)
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
                        local charName = gameAccount.characterName
                        local classToken = gameAccount.classFileName
                        if not classToken and gameAccount.className then
                            classToken = CLASS_TOKEN_BY_NAME[gameAccount.className]
                        end
                        if classToken then
                            local classColor = C_ClassColor.GetClassColor(classToken)
                            if classColor and classColor.WrapTextInColorCode then
                                charName = classColor:WrapTextInColorCode(charName)
                            end
                        end
                        nameText = nameText .. " (" .. charName .. ")"
                    end

                    local rightText = ""
                    local label = "Other games"
                    if gameAccount.clientProgram == BNET_CLIENT_WOW then
                        label = VersionLabel(gameAccount.wowProjectID)
                        local zone = (gameAccount.areaName and gameAccount.areaName ~= "") and gameAccount.areaName or ""
                        local level = gameAccount.characterLevel and tostring(gameAccount.characterLevel) or ""
                        rightText = zone .. "  " .. level
                    elseif gameAccount.richPresence and gameAccount.richPresence ~= "" then
                        rightText = gameAccount.richPresence
                    end

                    Add(label, nameText, rightText, 0.51, 0.77, 1)
                end
            end
        end

        -- This client's version first, then the rest in the order they appeared.
        table.sort(order, function(x, y)
            if (x == ownLabel) ~= (y == ownLabel) then return x == ownLabel end
            if (x == "Other games") ~= (y == "Other games") then return y == "Other games" end
            return false
        end)
        for n, label in ipairs(order) do
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(label .. " (" .. #groups[label] .. ")", 1, 0.82, 0)
            for _, e in ipairs(groups[label]) do
                GameTooltip:AddDoubleLine(e[1], e[2], e[3], e[4], e[5], 0.7, 0.7, 0.7)
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
