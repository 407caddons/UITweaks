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
    UIThingsDB.loot.anchor = {point=point, x=x, y=y}
end)

anchorFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", 
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", 
    tile = true, tileSize = 16, edgeSize = 16, 
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
        toast.text:SetPoint("LEFT", toast.icon, "RIGHT", 5, 0)
        toast.text:SetPoint("RIGHT", 0, 0)
        toast.text:SetJustifyH("LEFT")
        
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
    local baseY = 0
    local spacing = 5
    
    if not settings.anchor then return end
    
    -- Anchor point relative to UIParent usually, but here relevant to the anchorFrame's position
    -- We'll attach the first one to the anchor frame, then stack.
    -- Actually, safer to rely on anchorFrame's position if it's movable.
    
    -- If anchorFrame is hidden, we usually want it to stay in place.
    -- We can set points relative to anchorFrame even if it is hidden.
    
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

local function SpawnToast(itemLink, text, count)
    local toast = AcquireToast()
    
    -- Data
    toast.itemLink = itemLink
    local itemName, _, itemRarity, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink)
    
    if not itemName then 
        -- Fallback if info not ready? 
        -- Usually CHAT_MSG_LOOT comes after info is ready, but not always.
        -- We can retry or just use name from chat msg if parsed?
        -- Let's assume parsed text or basic info.
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
        anchorFrame:SetPoint(settings.anchor.point, UIParent, settings.anchor.point, settings.anchor.x, settings.anchor.y)
    end
    
    -- Update existing toasts visually
    for _, toast in ipairs(activeToasts) do
        toast:SetSize(300, settings.iconSize)
        toast.icon:SetSize(settings.iconSize, settings.iconSize)
        toast.text:SetFont(settings.font, settings.fontSize, "OUTLINE")
    end
    Loot.UpdateLayout()
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
            
            -- Iterate backwards to avoid index shifting when items are removed
            for i = numItems, 1, -1 do
                if delay == 0 then
                    LootSlot(i)
                else
                    -- Schedule looting: First item (index numItems) starts at 0 delay
                    -- Last item (index 1) starts at (numItems - 1) * delay
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
        -- Patterns: 
        -- LOOT_ITEM = "You receive loot: %s."
        -- LOOT_ITEM_MULTIPLE = "You receive loot: %sx%d."
        -- LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
        -- LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
        
        -- We can just scan for item links.
        local itemLink = string.match(msg, "|Hitem:.-|h")
        if itemLink then
            -- Get Quality
            local _, _, quality = GetItemInfo(itemLink)
            if not quality then return end -- wait for sync? 
            
            if quality >= UIThingsDB.loot.minQuality then
                -- Parse count
                local count = 1
                local matchCount = string.match(msg, "x(%d+)")
                if matchCount then count = tonumber(matchCount) end
                
                SpawnToast(itemLink, nil, count)
            end
        end
    end
end)
