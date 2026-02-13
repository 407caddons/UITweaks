local addonName, addonTable = ...
local AddonVersions = {}
addonTable.AddonVersions = AddonVersions

local ADDON_PREFIX = "LunaVer"
local VERSION = C_AddOns.GetAddOnMetadata(addonName, "Version") or "unknown"
local KEYSTONE_ITEM_ID = 158923

-- Tracked data: playerName -> { version, keystoneName, keystoneLevel, playerLevel, keystoneMapID }
-- Players without the addon get { version = nil }
local playerData = {}

-- Pending broadcast timer (cancellable)
local broadcastTimer = nil

-- Callback for when data changes (set by config panel)
AddonVersions.onVersionsUpdated = nil

-- Get the player's keystone info from bags
local function GetPlayerKeystone()
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            if itemInfo and (itemInfo.itemID == KEYSTONE_ITEM_ID or
                    (itemInfo.hyperlink and itemInfo.hyperlink:match("keystone:"))) then
                local itemLink = itemInfo.hyperlink
                if itemLink then
                    local mapID, level = itemLink:match("keystone:%d+:(%d+):(%d+)")
                    if mapID and level then
                        mapID = tonumber(mapID)
                        level = tonumber(level)
                        local name = C_ChallengeMode.GetMapUIInfo(mapID)
                        if name then
                            return name, level, mapID
                        end
                    end
                end
            end
        end
    end
    return nil, nil
end

-- Build the broadcast message: "version|keystoneName|keystoneLevel|playerLevel|keystoneMapID"
local function BuildMessage()
    local keyName, keyLevel, keyMapID = GetPlayerKeystone()
    local playerLevel = UnitLevel("player") or 0
    return string.format("%s|%s|%d|%d|%d",
        VERSION,
        keyName or "none",
        keyLevel or 0,
        playerLevel,
        keyMapID or 0)
end

-- Parse incoming message
local function ParseMessage(message)
    -- New format: version|keyName|keyLevel|playerLevel|keystoneMapID
    local version, keyName, keyLevel, playerLevel, keyMapID = message:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
    if version then
        local mapID = tonumber(keyMapID) or 0
        return {
            version = version,
            keystoneName = keyName ~= "none" and keyName or nil,
            keystoneLevel = tonumber(keyLevel) or 0,
            playerLevel = tonumber(playerLevel) or 0,
            keystoneMapID = mapID > 0 and mapID or nil,
        }
    end
    -- Backwards compatible: version|keyName|keyLevel|playerLevel (no mapID)
    version, keyName, keyLevel, playerLevel = message:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
    if version then
        return {
            version = version,
            keystoneName = keyName ~= "none" and keyName or nil,
            keystoneLevel = tonumber(keyLevel) or 0,
            playerLevel = tonumber(playerLevel) or 0,
            keystoneMapID = nil,
        }
    end
    -- Fallback: old format (just version string, no pipes)
    if not message:find("|") then
        return { version = message, keystoneName = nil, keystoneLevel = 0, playerLevel = 0, keystoneMapID = nil }
    end
    return nil
end

local function BroadcastVersion()
    if not IsInGroup() then return end
    -- Respect hideFromWorld setting
    if UIThingsDB and UIThingsDB.addonComm and UIThingsDB.addonComm.hideFromWorld then return end
    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, BuildMessage(), channel)
end

local function RequestVersions()
    if not IsInGroup() then return end
    -- Respect hideFromWorld setting
    if UIThingsDB and UIThingsDB.addonComm and UIThingsDB.addonComm.hideFromWorld then return end
    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "REQUEST", channel)
end

-- Build the full party/raid list, marking members without the addon
local function UpdatePartyList()
    -- Collect current group member names
    local groupNames = {}
    local playerName = UnitName("player")
    groupNames[playerName] = true

    if IsInGroup() then
        local numMembers = GetNumGroupMembers()
        for i = 1, numMembers do
            local unit = IsInRaid() and "raid" .. i or "party" .. i
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                local name = UnitName(unit)
                if name then
                    groupNames[name] = true
                end
            end
        end
    end

    -- Add missing group members as "no addon"
    for name in pairs(groupNames) do
        if not playerData[name] then
            playerData[name] = { version = nil }
        end
    end

    -- Remove players no longer in the group (except self)
    for name in pairs(playerData) do
        if not groupNames[name] then
            playerData[name] = nil
        end
    end
end

local function ScheduleBroadcast()
    -- Cancel any pending timer so new joins reset the delay
    if broadcastTimer then
        broadcastTimer:Cancel()
        broadcastTimer = nil
    end
    broadcastTimer = C_Timer.NewTimer(3, function()
        broadcastTimer = nil
        if IsInGroup() then
            BroadcastVersion()
        end
    end)
end

local function OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= ADDON_PREFIX then return end

    -- Strip realm name for display
    local shortName = sender:match("^([^-]+)") or sender

    if message == "REQUEST" then
        BroadcastVersion()
    else
        local data = ParseMessage(message)
        if data then
            playerData[shortName] = data
            if AddonVersions.onVersionsUpdated then
                AddonVersions.onVersionsUpdated()
            end
        end
    end
end

function AddonVersions.GetPlayerData()
    return playerData
end

function AddonVersions.GetOwnVersion()
    return VERSION
end

function AddonVersions.RefreshVersions()
    wipe(playerData)
    -- Add self
    local playerName = UnitName("player")
    local keyName, keyLevel, keyMapID = GetPlayerKeystone()
    playerData[playerName] = {
        version = VERSION,
        keystoneName = keyName,
        keystoneLevel = keyLevel or 0,
        playerLevel = UnitLevel("player") or 0,
        keystoneMapID = keyMapID,
    }

    UpdatePartyList()

    if IsInGroup() then
        RequestVersions()
    end

    if AddonVersions.onVersionsUpdated then
        AddonVersions.onVersionsUpdated()
    end
end

-- Event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "GROUP_ROSTER_UPDATE" then
        if IsInGroup() then
            UpdatePartyList()
            ScheduleBroadcast()
        else
            if broadcastTimer then
                broadcastTimer:Cancel()
                broadcastTimer = nil
            end
            wipe(playerData)
            local playerName = UnitName("player")
            local keyName, keyLevel, keyMapID = GetPlayerKeystone()
            playerData[playerName] = {
                version = VERSION,
                keystoneName = keyName,
                keystoneLevel = keyLevel or 0,
                playerLevel = UnitLevel("player") or 0,
                keystoneMapID = keyMapID,
            }
        end
        if AddonVersions.onVersionsUpdated then
            AddonVersions.onVersionsUpdated()
        end
    elseif event == "CHAT_MSG_ADDON" then
        OnAddonMessage(...)
    end
end)

C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
