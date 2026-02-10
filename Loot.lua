local addonName, addonTable = ...
local Loot = {}
addonTable.Loot = Loot

local PAGE_NAME = "UIThingsLootToast"
local activeToasts = {}
local itemPool = {} -- Recycled frames

-- Anchor Frame
local anchorFrame = CreateFrame("Frame", "UIThingsLootAnchor", UIParent, "BackdropTemplate")
anchorFrame:SetSize(200, 20)
anchorFrame:SetMovable(true)
anchorFrame:EnableMouse(true)
anchorFrame:SetClampedToScreen(true)
anchorFrame:RegisterForDrag("LeftButton")
anchorFrame:SetScript("OnDragStart", anchorFrame.StartMoving)
anchorFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    UIThingsDB.loot.anchor = { point = point, x = x, y = y }
end)

anchorFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
anchorFrame:SetBackdropColor(0, 0, 0, 0.8)
anchorFrame.text = anchorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
anchorFrame.text:SetPoint("CENTER")
anchorFrame.text:SetText("Loot Toasts Anchor")
anchorFrame:Hide()

function Loot.ToggleAnchor()
    if anchorFrame:IsShown() then
        anchorFrame:Hide()
        return false
    else
        anchorFrame:Show()
        return true
    end
end

function Loot.LockAnchor()
    if anchorFrame:IsShown() then
        anchorFrame:Hide()
    end
end

-- Toast Factory
local function AcquireToast()
    local toast = table.remove(itemPool)
    if not toast then
        toast = CreateFrame("Button", nil, UIParent) -- Button for tooltip support
        toast:SetFrameStrata("DIALOG")

        toast.icon = toast:CreateTexture(nil, "ARTWORK")
        toast.icon:SetPoint("LEFT", 0, 0)

        toast.text = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        toast.text:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 5, 0)
        toast.text:SetPoint("RIGHT", 0, 0)
        toast.text:SetJustifyH("LEFT")
        toast.text:SetWordWrap(false)

        toast.winner = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        toast.winner:SetPoint("BOTTOMLEFT", toast.icon, "BOTTOMRIGHT", 5, 0)
        toast.winner:SetPoint("RIGHT", 0, 0)
        toast.winner:SetJustifyH("LEFT")

        -- Tooltip Scripts
        toast:SetScript("OnEnter", function(self)
            if self.itemLink then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.itemLink)
                GameTooltip:Show()
            end
            self:SetAlpha(1) -- Pause fade if hovering? Or just keep it visible
        end)
        toast:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        -- OnUpdate for Timer
        toast:SetScript("OnUpdate", function(self, elapsed)
            self.timeParams.elapsed = self.timeParams.elapsed + elapsed
            local remaining = self.timeParams.duration - self.timeParams.elapsed

            if remaining <= 0 then
                Loot.RecycleToast(self)
            elseif remaining < 0.5 then
                self:SetAlpha(remaining * 2) -- Fade out over last 0.5s
            else
                self:SetAlpha(1)
            end
        end)
    end

    -- Apply Settings
    local settings = UIThingsDB.loot
    toast:SetSize(300, settings.iconSize)
    toast.icon:SetSize(settings.iconSize, settings.iconSize)
    toast.text:SetFont(settings.font, settings.fontSize, "OUTLINE")
    -- Adjust winner font size relative to main font
    toast.winner:SetFont(settings.font, settings.whoLootedFontSize or 12, "OUTLINE")

    return toast
end

function Loot.RecycleToast(toast)
    toast:Hide()
    toast:SetScript("OnEnter", nil) -- Clear specific tooltip closure
    toast:SetScript("OnLeave", nil)

    -- Remove from active list
    for i, t in ipairs(activeToasts) do
        if t == toast then
            table.remove(activeToasts, i)
            break
        end
    end

    table.insert(itemPool, toast)
    Loot.UpdateLayout()
end

function Loot.UpdateLayout()
    -- Re-stack toasts above anchor
    -- Growing UP
    local settings = UIThingsDB.loot
    local spacing = 5

    if not settings.anchor then return end

    local prev = anchorFrame

    for i, toast in ipairs(activeToasts) do
        toast:ClearAllPoints()

        if settings.growUp then
            -- Grow Upwards
            if i == 1 then
                toast:SetPoint("BOTTOMLEFT", prev, "TOPLEFT", 0, spacing)
            else
                toast:SetPoint("BOTTOMLEFT", prev, "TOPLEFT", 0, spacing)
            end
            prev = toast -- Next one stacks on top of this one
        else
            -- Grow Downwards
            if i == 1 then
                toast:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -spacing)
            else
                toast:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -spacing)
            end
            prev = toast -- Next one stacks below this one
        end
    end
end

local function SpawnToast(itemLink, text, count, looterName, looterClass)
    local toast = AcquireToast()

    -- Data
    toast.itemLink = itemLink
    local itemName, _, itemRarity, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink)

    if not itemName then
        itemName = text or "Unknown Item"
        itemTexture = 134400 -- ?
    end

    if itemTexture then toast.icon:SetTexture(itemTexture) end
    if itemName then
        local countText = (count and count > 1) and (" x" .. count) or ""
        toast.text:SetText(itemName .. countText)
        -- Color name by rarity?
        if itemRarity then
            local r, g, b = GetItemQualityColor(itemRarity)
            toast.text:SetTextColor(r, g, b)
        else
            toast.text:SetTextColor(1, 1, 1)
        end
    end

    -- Winner Name
    if looterName then
        local colorStr = "|cFFFFFFFF" -- Default white
        if looterClass then
            local color = C_ClassColor.GetClassColor(looterClass)
            if color then
                colorStr = color:GenerateHexColorMarkup()
            end
        end
        toast.winner:SetText("Won by: " .. colorStr .. looterName .. "|r")
        toast.winner:Show()
    else
        toast.winner:Hide()
    end

    -- Timer Setup
    toast.timeParams = {
        duration = UIThingsDB.loot.duration,
        elapsed = 0
    }

    -- Re-bind scripts (since we clear them on recycle)
    toast:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:Show()
        end
    end)

    toast:SetScript("OnLeave", function() GameTooltip:Hide() end)

    toast:Show()
    table.insert(activeToasts, toast)
    Loot.UpdateLayout()
end

function Loot.UpdateSettings()
    -- Apply anchor position
    local settings = UIThingsDB.loot
    if settings.anchor then
        anchorFrame:ClearAllPoints()
        anchorFrame:SetPoint(settings.anchor.point, UIParent, settings.anchor.point, settings.anchor.x, settings.anchor
            .y)
    end

    -- Update existing toasts visually
    for _, toast in ipairs(activeToasts) do
        toast:SetSize(300, settings.iconSize)
        toast.icon:SetSize(settings.iconSize, settings.iconSize)
        toast.text:SetFont(settings.font, settings.fontSize, "OUTLINE")
        toast.winner:SetFont(settings.font, settings.whoLootedFontSize or 12, "OUTLINE")
    end
    Loot.UpdateLayout()
    Loot.ToggleBlizzardToasts(not settings.enabled)
end

function Loot.ToggleBlizzardToasts(enable)
    if enable then
        AlertFrame:RegisterEvent("SHOW_LOOT_TOAST")
        AlertFrame:RegisterEvent("SHOW_LOOT_TOAST_UPGRADE")
        AlertFrame:RegisterEvent("SHOW_PVP_FACTION_LOOT_TOAST")

    else
        -- Use pcall to safely unregister events that may not be registered
        pcall(function() AlertFrame:UnregisterEvent("SHOW_LOOT_TOAST") end)
        pcall(function() AlertFrame:UnregisterEvent("SHOW_LOOT_TOAST_UPGRADE") end)
        pcall(function() AlertFrame:UnregisterEvent("SHOW_PVP_FACTION_LOOT_TOAST") end)

    end
end

-- Event Handler
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("LOOT_READY")

frame:SetScript("OnEvent", function(self, event, msg, ...)
    if event == "PLAYER_LOGIN" then
        addonTable.Loot.UpdateSettings()
        return
    end

    if not UIThingsDB.loot.enabled then return end

    if event == "LOOT_READY" then
        if UIThingsDB.loot.fasterLoot and GetCVar("autoLootDefault") == "1" then
            local numItems = GetNumLootItems()
            if numItems == 0 then return end

            local delay = UIThingsDB.loot.fasterLootDelay or 0.3

            for i = numItems, 1, -1 do
                if delay == 0 then
                    LootSlot(i)
                else
                    local timerDelay = (numItems - i) * delay
                    C_Timer.After(timerDelay, function()
                        LootSlot(i)
                    end)
                end
            end
        end
        return
    end

    if event == "CHAT_MSG_LOOT" then
        local itemLink = string.match(msg, "|Hitem:.-|h")
        if itemLink then
            -- Get Quality
            local _, _, quality = GetItemInfo(itemLink)
            if not quality then return end

            if quality >= UIThingsDB.loot.minQuality then
                -- Identify Looter
                local looterName = nil
                local looterClass = nil

                -- Check for "You receive..."
                if string.find(msg, "^You receive") then
                    looterName = UnitName("player")
                    _, looterClass = UnitClass("player")
                else
                    -- Check for "X receives..."
                    local otherName = string.match(msg, "^([^%s]+) receive")
                    if otherName then
                        looterName = otherName
                        -- Strip server name if present (e.g., "Player-ServerName" -> "Player")
                        local shortName = string.match(looterName, "^([^%-]+)")
                        if shortName then looterName = shortName end

                        -- Try to find class from raid/party roster
                        if IsInRaid() then
                            for i = 1, 40 do
                                local name, _, _, _, _, classFileName = GetRaidRosterInfo(i)
                                if name then
                                    local shortRaidName = string.match(name, "^([^%-]+)") or name
                                    if shortRaidName == looterName then
                                        looterClass = classFileName
                                        break
                                    end
                                end
                            end
                        elseif IsInGroup() then
                            -- Check party members using UnitName comparison
                            for i = 1, 4 do
                                local unitID = "party" .. i
                                local partyName = UnitName(unitID)
                                if partyName then
                                    local shortPartyName = string.match(partyName, "^([^%-]+)") or partyName
                                    if shortPartyName == looterName then
                                        _, looterClass = UnitClass(unitID)
                                        break
                                    end
                                end
                            end
                        end
                    end
                end

                -- Filtering
                if not UIThingsDB.loot.showAll then
                    if looterName ~= UnitName("player") then return end
                end

                -- Parse count
                local count = 1
                local matchCount = string.match(msg, "x(%d+)")
                if matchCount then count = tonumber(matchCount) end

                SpawnToast(itemLink, nil, count, looterName, looterClass)
            end
        end
    end
end)
