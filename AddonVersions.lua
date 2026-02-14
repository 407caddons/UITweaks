local addonName, addonTable = ...
local AddonVersions = {}
addonTable.AddonVersions = AddonVersions

local VERSION = C_AddOns.GetAddOnMetadata(addonName, "Version") or "unknown"
local KEYSTONE_ITEM_ID = 158923

-- Tracked data: playerName -> { version, keystoneName, keystoneLevel, playerLevel, keystoneMapID }
-- Players without the addon get { version = nil }
local playerData = {}

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
    local message = BuildMessage()
    addonTable.Comm.Send("VER", "HELLO", message, "LunaVer", message)
end

local function RequestVersions()
    addonTable.Comm.Send("VER", "REQ", "", "LunaVer", "REQUEST")
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
    addonTable.Comm.ScheduleThrottled("VER_HELLO", 3, function()
        if IsInGroup() then
            BroadcastVersion()
        end
    end)
end

-- Register handlers with central comm
addonTable.Comm.Register("VER", "HELLO", function(senderShort, payload, senderFull)
    local data = ParseMessage(payload)
    if data then
        playerData[senderShort] = data
        if AddonVersions.onVersionsUpdated then
            AddonVersions.onVersionsUpdated()
        end
    end
end)

addonTable.Comm.Register("VER", "REQ", function(senderShort, payload, senderFull)
    BroadcastVersion()
end)

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

-- Event handling (only GROUP_ROSTER_UPDATE — CHAT_MSG_ADDON handled by AddonComm)
local frame = CreateFrame("Frame")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "GROUP_ROSTER_UPDATE" then
        if IsInGroup() then
            UpdatePartyList()
            ScheduleBroadcast()
        else
            addonTable.Comm.CancelThrottle("VER_HELLO")
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
    end
end)
