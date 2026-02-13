local addonName, addonTable = ...

addonTable.Widgets = {}
local Widgets = addonTable.Widgets

local frames = {}
local updateInterval = 1.0
local widgetTicker = nil
Widgets.moduleInits = {}

-- Estimate M+ score for a timed run at a given key level
-- Community-known formula: base score ≈ 37.5 + (level * 7.5)
function Widgets.EstimateTimedScore(keystoneLevel)
    if not keystoneLevel or keystoneLevel < 2 then return 0 end
    return math.floor(37.5 + (keystoneLevel * 7.5))
end

-- Estimate rating gain from timing a key at a given level for a specific dungeon
-- Returns: estimatedGain, estimatedScore, currentBest
function Widgets.EstimateRatingGain(mapID, keystoneLevel)
    if not mapID or not keystoneLevel then return 0, 0, 0 end
    local estimatedScore = Widgets.EstimateTimedScore(keystoneLevel)
    local currentBest = 0
    -- GetSeasonBestForMap returns (intimeInfo, overtimeInfo) as MapSeasonBestInfo tables
    -- Try to get overall dungeon score via GetMapScoreInfo first, fallback to season best
    local intimeInfo, overtimeInfo = C_MythicPlus.GetSeasonBestForMap(mapID)
    if intimeInfo and intimeInfo.dungeonScore then
        currentBest = intimeInfo.dungeonScore
    end
    if overtimeInfo and overtimeInfo.dungeonScore and overtimeInfo.dungeonScore > currentBest then
        currentBest = overtimeInfo.dungeonScore
    end
    local gain = math.max(0, estimatedScore - currentBest)
    return gain, estimatedScore, currentBest
end

-- Helper to create a widget frame
function Widgets.CreateWidgetFrame(name, configKey)
    local f = CreateFrame("Button", "LunaUITweaks_Widget_" .. name, UIParent)
    f:SetSize(100, 20)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not UIThingsDB.widgets.locked then
            self:StartMoving()
            self.isMoving = true
        end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.isMoving = false

        -- Calculate relative directly
        local cx, cy = self:GetCenter()
        local pcx, pcy = UIParent:GetCenter()
        if not cx or not pcx then return end

        local x = cx - pcx
        local y = cy - pcy

        -- Re-anchor to CENTER
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", x, y)

        UIThingsDB.widgets[configKey].point = "CENTER"
        UIThingsDB.widgets[configKey].relPoint = "CENTER"
        UIThingsDB.widgets[configKey].x = x
        UIThingsDB.widgets[configKey].y = y
        self.coords:SetText(string.format("(%.0f, %.0f)", x, y))
    end)

    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.text:SetPoint("CENTER")

    -- Background for dragging visibility
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 1, 0, 0.3)
    f.bg:Hide()

    -- Coordinates text (hidden by default)
    f.coords = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.coords:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 2)
    f.coords:Hide()

    f:SetScript("OnUpdate", function(self)
        if self.isMoving then
            local cx, cy = self:GetCenter()
            local pcx, pcy = UIParent:GetCenter()
            if cx and pcx then
                local x = cx - pcx
                local y = cy - pcy
                self.coords:SetText(string.format("(%.0f, %.0f)", x, y))
            end
        end
    end)

    frames[configKey] = f
    return f
end

function Widgets.SmartAnchorTooltip(owner)
    -- Ensure using correct tooltip, usually GameTooltip
    -- If owner provides GetCenter, use it.
    GameTooltip:SetOwner(owner, "ANCHOR_NONE")
    local _, cy = owner:GetCenter()
    local screenHeight = UIParent:GetHeight()

    if cy and cy < (screenHeight / 2) then
        GameTooltip:SetPoint("BOTTOM", owner, "TOP", 0, 5)
    else
        GameTooltip:SetPoint("TOP", owner, "BOTTOM", 0, -5)
    end
end

local function StartWidgetTicker()
    if widgetTicker then return end
    widgetTicker = C_Timer.NewTicker(updateInterval, function()
        Widgets.UpdateContent()
    end)
end

local function StopWidgetTicker()
    if widgetTicker then
        widgetTicker:Cancel()
        widgetTicker = nil
    end
end

function Widgets.Initialize()
    -- Always start locked
    if UIThingsDB.widgets then
        UIThingsDB.widgets.locked = true
    end

    -- Initialize all registered modules
    for _, initFunc in ipairs(Widgets.moduleInits) do
        initFunc()
    end

    Widgets.UpdateVisuals()
    Widgets.UpdateContent()

    -- Start ticker if widgets are enabled
    if UIThingsDB.widgets and UIThingsDB.widgets.enabled then
        StartWidgetTicker()
    end
end

local function UpdateAnchoredLayouts()
    local db = UIThingsDB.widgets
    if not db or not db.enabled then return end
    if InCombatLockdown() then return end

    local anchorLookup = {}
    local anchorData = {}
    if UIThingsDB.frames and UIThingsDB.frames.list then
        for i, data in ipairs(UIThingsDB.frames.list) do
            if data.isAnchor then
                local f = _G["UIThingsCustomFrame" .. i]
                if f then
                    anchorLookup[data.name] = f
                    anchorData[data.name] = data
                end
            end
        end
    end

    local anchoredWidgets = {}
    for key, frame in pairs(frames) do
        if frame:IsShown() and db[key] then
            local anchorName = db[key].anchor
            if anchorName and anchorLookup[anchorName] then
                if not anchoredWidgets[anchorName] then anchoredWidgets[anchorName] = {} end
                table.insert(anchoredWidgets[anchorName], { key = key, frame = frame })
            end
        end
    end

    for anchorName, items in pairs(anchoredWidgets) do
        local anchorFrame = anchorLookup[anchorName]

        table.sort(items, function(a, b)
            local orderA = db[a.key].order or 0
            local orderB = db[b.key].order or 0
            if orderA ~= orderB then
                return orderA < orderB
            end
            return a.key < b.key
        end)

        if anchorFrame then
            local count = #items
            if count > 0 then
                local direction = anchorData[anchorName] and anchorData[anchorName].dockDirection or "horizontal"
                local isVertical = (direction == "vertical")

                -- Measure content size along the dock axis
                local totalContentSize = 0
                for _, item in ipairs(items) do
                    local f = item.frame
                    local textWidth = f.text:GetStringWidth()
                    local w = textWidth + 10
                    f:SetWidth(w)
                    if isVertical then
                        totalContentSize = totalContentSize + f:GetHeight()
                    else
                        totalContentSize = totalContentSize + w
                    end
                end

                local axisLength = isVertical and anchorFrame:GetHeight() or anchorFrame:GetWidth()
                local gapSize = (axisLength - totalContentSize) / (count + 1)
                local currentOffset = gapSize

                for _, item in ipairs(items) do
                    local f = item.frame
                    f:ClearAllPoints()
                    if isVertical then
                        f:SetPoint("TOP", anchorFrame, "TOP", 0, -currentOffset)
                        currentOffset = currentOffset + f:GetHeight() + gapSize
                    else
                        f:SetPoint("LEFT", anchorFrame, "LEFT", currentOffset, 0)
                        currentOffset = currentOffset + f:GetWidth() + gapSize
                    end
                    f:SetFrameLevel(anchorFrame:GetFrameLevel() + 10)
                end
            end
        end
    end
end

function Widgets.UpdateVisuals()
    local db = UIThingsDB.widgets
    if not db then
        StopWidgetTicker()
        return
    end

    -- Manage ticker lifecycle based on enabled state
    if db.enabled then
        StartWidgetTicker()
    else
        StopWidgetTicker()
    end

    -- Build Anchor Lookup
    local anchorLookup = {}
    if UIThingsDB.frames and UIThingsDB.frames.list then
        for i, data in ipairs(UIThingsDB.frames.list) do
            if data.isAnchor then
                local f = _G["UIThingsCustomFrame" .. i]
                if f then anchorLookup[data.name] = f end
            end
        end
    end

    -- Group Widgets
    local anchoredWidgets = {} -- name -> { widgetFrame... }
    local unanchoredWidgets = {}

    for key, frame in pairs(frames) do
        if db.enabled and db[key] and db[key].enabled then
            frame:Show()
            if frame.ApplyEvents then frame.ApplyEvents(true) end

            -- Apply Common Styles
            local fontName = db.font
            local fontSize = db.fontSize
            local fontFlags = db.fontFlags or "OUTLINE"
            if frame.text then frame.text:SetFont(fontName, fontSize, fontFlags) end

            local c = db.fontColor
            if frame.text then frame.text:SetTextColor(c.r, c.g, c.b, c.a) end

            frame:SetFrameStrata(db.strata)

            -- Check Anchor
            local anchorName = db[key].anchor
            local anchorFrame = anchorLookup[anchorName]

            if anchorFrame then
                if not anchoredWidgets[anchorName] then anchoredWidgets[anchorName] = {} end
                table.insert(anchoredWidgets[anchorName], { key = key, frame = frame })
            else
                table.insert(unanchoredWidgets, { key = key, frame = frame })
            end
        else
            frame:Hide()
            if frame.ApplyEvents then frame.ApplyEvents(false) end
        end
    end

    -- Position Unanchored
    for _, item in ipairs(unanchoredWidgets) do
        local key = item.key
        local frame = item.frame

        frame:ClearAllPoints()

        -- Check if this is first time enabling (widget at default position)
        -- New widgets (keystone, weeklyReset) default to CENTER with negative Y offsets
        -- If position hasn't been customized yet, center them instead
        local isNewWidget = (key == "keystone" or key == "weeklyReset")
        local isDefaultPos = (db[key].point == "CENTER" and (db[key].x == 0) and
            (db[key].y == -200 or db[key].y == -220))

        if isNewWidget and isDefaultPos and not frame.hasBeenPositioned then
            -- First time showing this widget - center it
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            db[key].point = "CENTER"
            db[key].relPoint = "CENTER"
            db[key].x = 0
            db[key].y = 0
            frame.hasBeenPositioned = true
        elseif db[key].point then
            frame:SetPoint(db[key].point, UIParent, db[key].relPoint or db[key].point, db[key].x, db[key].y)
        else
            frame:SetPoint("CENTER", 0, 0)
        end

        -- Unlock highlighting
        if not db.locked then
            frame.bg:Show()
            frame:EnableMouse(true)
            frame.coords:Show()
            local x = db[key].x or 0
            local y = db[key].y or 0
            frame.coords:SetText(string.format("(%.0f, %.0f)", x, y))
            frame:SetMovable(true)
        else
            frame.bg:Hide()
            frame.coords:Hide()
            frame:SetMovable(false) -- Ensure not movable if locked (though Drag script checks db.locked)
        end
    end

    -- Force locked state on anchored widgets (layout handled by UpdateAnchoredLayouts)
    for _, items in pairs(anchoredWidgets) do
        for _, item in ipairs(items) do
            item.frame.bg:Hide()
            item.frame.coords:Hide()
            item.frame:SetMovable(false)
        end
    end

    -- Position anchored widgets
    UpdateAnchoredLayouts()
end

function Widgets.UpdateContent()
    if not UIThingsDB.widgets.enabled then return end

    local needsLayoutUpdate = false

    for key, frame in pairs(frames) do
        if frame:IsShown() and frame.UpdateContent then
            frame:UpdateContent()

            if UIThingsDB.widgets[key] and UIThingsDB.widgets[key].anchor then
                needsLayoutUpdate = true
            end
        end
    end

    if needsLayoutUpdate and not InCombatLockdown() then
        UpdateAnchoredLayouts()
    end
end
