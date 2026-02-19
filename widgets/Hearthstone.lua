local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

-- Hearthstone toy IDs (fallback if player has no item 6948)
local HEARTHSTONE_TOYS = {
    64488,  -- The Innkeeper's Daughter
    54452,  -- Ethereal Portal
    93672,  -- Dark Portal
    142542, -- Tome of Town Portal
    162973, -- Greatfather Winter's Hearthstone
    163045, -- Headless Horseman's Hearthstone
    165669, -- Lunar Elder's Hearthstone
    165670, -- Peddlefeet's Lovely Hearthstone
    165802, -- Noble Gardener's Hearthstone
    166746, -- Fire Eater's Hearthstone
    166747, -- Brewfest Reveler's Hearthstone
    168907, -- Holographic Digitalization Hearthstone
    172179, -- Eternal Traveler's Hearthstone
    180290, -- Night Fae Hearthstone
    182773, -- Necrolord Hearthstone
    183716, -- Venthyr Sinstone
    184353, -- Kyrian Hearthstone
    188952, -- Dominated Hearthstone
    190196, -- Enlightened Hearthstone
    190237, -- Broker Translocation Matrix
    193588, -- Timewalker's Hearthstone
    200630, -- Ohn'ir Windsage's Hearthstone
    206195, -- Path of the Naaru
    208704, -- Deepdweller's Earthen Hearthstone
    209035, -- Hearthstone of the Flame
    212337, -- Stone of the Hearth
    228940, -- Notorious Thread's Hearthstone
    235016, -- Redeployment Module
    236687, -- Explosive Hearthstone
    245970, -- P.O.S.T. Master's Express Hearthstone
    246565, -- Cosmic Hearthstone
}

local ownedHearthstones = nil

local function BuildOwnedList()
    local owned = {}
    -- Always include standard hearthstone if in bags
    if C_Container.PlayerHasHearthstone() then
        table.insert(owned, 6948)
    end
    -- Add all owned hearthstone toys
    for _, toyID in ipairs(HEARTHSTONE_TOYS) do
        if PlayerHasToy(toyID) then
            table.insert(owned, toyID)
        end
    end
    ownedHearthstones = owned
    return owned
end

local function GetRandomHearthstoneID()
    local owned = ownedHearthstones or BuildOwnedList()
    if #owned == 0 then return 6948 end
    return owned[math.random(#owned)]
end

local function GetAnyHearthstoneID()
    local owned = ownedHearthstones or BuildOwnedList()
    if #owned > 0 then return owned[1] end
    return 6948
end

local function FormatCooldown(seconds)
    if seconds >= 60 then
        local m = math.floor(seconds / 60)
        local s = math.floor(seconds % 60)
        if s > 0 then
            return string.format("%dm %ds", m, s)
        end
        return string.format("%dm", m)
    end
    return string.format("%ds", math.floor(seconds))
end

local function GetCooldownRemaining()
    local itemID = GetAnyHearthstoneID()

    local startTime, duration, enable = GetItemCooldown(itemID)
    if startTime and duration and duration > 0 and enable == 1 then
        local remaining = (startTime + duration) - GetTime()
        if remaining > 0 then
            return remaining
        end
    end
    return 0
end

table.insert(Widgets.moduleInits, function()
    local hearthFrame = Widgets.CreateWidgetFrame("Hearthstone", "hearthstone")

    -- Secure overlay button for combat-safe clicking
    local secureBtn = CreateFrame("Button", "LunaUITweaks_HearthSecure", hearthFrame, "SecureActionButtonTemplate")
    secureBtn:SetAllPoints(hearthFrame)
    secureBtn:RegisterForClicks("AnyDown", "AnyUp")
    secureBtn:RegisterForDrag("LeftButton")

    -- Set initial secure attributes
    secureBtn:SetAttribute("type", "item")
    secureBtn:SetAttribute("item", "item:" .. GetRandomHearthstoneID())

    -- Pick a random hearthstone before each click (only out of combat)
    secureBtn:SetScript("PreClick", function(self)
        if InCombatLockdown() then return end
        self:SetAttribute("item", "item:" .. GetRandomHearthstoneID())
    end)

    -- Pass drag through to widget frame
    secureBtn:SetScript("OnDragStart", function()
        if not UIThingsDB.widgets.locked then
            hearthFrame:StartMoving()
            hearthFrame.isMoving = true
        end
    end)
    secureBtn:SetScript("OnDragStop", function()
        hearthFrame:StopMovingOrSizing()
        hearthFrame.isMoving = false
        local cx, cy = hearthFrame:GetCenter()
        local pcx, pcy = UIParent:GetCenter()
        if not cx or not pcx then return end
        local x = cx - pcx
        local y = cy - pcy
        hearthFrame:ClearAllPoints()
        hearthFrame:SetPoint("CENTER", UIParent, "CENTER", x, y)
        UIThingsDB.widgets.hearthstone.point = "CENTER"
        UIThingsDB.widgets.hearthstone.relPoint = "CENTER"
        UIThingsDB.widgets.hearthstone.x = x
        UIThingsDB.widgets.hearthstone.y = y
        hearthFrame.coords:SetText(string.format("(%.0f, %.0f)", x, y))
    end)

    -- Tooltip on the secure overlay
    secureBtn:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(hearthFrame)
        GameTooltip:SetText("Hearth")

        local dest = GetBindLocation()
        if dest then
            GameTooltip:AddDoubleLine("Destination:", dest, 0.7, 0.7, 0.7, 1, 1, 1)
        end

        local remaining = GetCooldownRemaining()
        if remaining > 0 then
            GameTooltip:AddDoubleLine("Cooldown:", FormatCooldown(remaining), 0.7, 0.7, 0.7, 1, 0.3, 0.3)
        else
            GameTooltip:AddDoubleLine("Cooldown:", "Ready", 0.7, 0.7, 0.7, 0.3, 1, 0.3)
        end

        GameTooltip:Show()
    end)
    secureBtn:SetScript("OnLeave", GameTooltip_Hide)

    local function OnHearthEnteringWorld()
        if not UIThingsDB.widgets.hearthstone.enabled then return end
        ownedHearthstones = nil
        BuildOwnedList()
        if not InCombatLockdown() then
            secureBtn:SetAttribute("item", "item:" .. GetRandomHearthstoneID())
        end
        hearthFrame:UpdateContent(hearthFrame)
    end

    local function OnHearthUpdate()
        if not UIThingsDB.widgets.hearthstone.enabled then return end
        hearthFrame:UpdateContent(hearthFrame)
    end

    hearthFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("PLAYER_ENTERING_WORLD", OnHearthEnteringWorld)
            EventBus.Register("HEARTHSTONE_BOUND", OnHearthUpdate)
            EventBus.Register("SPELL_UPDATE_COOLDOWN", OnHearthUpdate)
        else
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnHearthEnteringWorld)
            EventBus.Unregister("HEARTHSTONE_BOUND", OnHearthUpdate)
            EventBus.Unregister("SPELL_UPDATE_COOLDOWN", OnHearthUpdate)
        end
    end

    hearthFrame.UpdateContent = function(self)
        local remaining = GetCooldownRemaining()
        if remaining > 0 then
            self.text:SetText("Hearth: " .. FormatCooldown(remaining))
        else
            self.text:SetText("Hearth")
        end
    end
end)
