local addonName, addonTable = ...
local CastBar = {}
addonTable.CastBar = CastBar

-- == Local State ==

local castBarFrame
local statusBar
local spark
local iconTexture
local spellNameText
local castTimeText
local borderTextures = {}

local isCasting = false
local isChanneling = false
local castStartTime = 0
local castEndTime = 0
local castDuration = 0
local currentSpellName = ""
local currentNotInterruptible = false

local fadeOutDuration = 0
local fadeOutElapsed = 0

-- == Border Helper ==

local function ApplyBorders(size, color)
    if size <= 0 then
        for _, tex in pairs(borderTextures) do tex:Hide() end
        return
    end
    local c = color or { r = 0, g = 0, b = 0, a = 1 }

    borderTextures.top:ClearAllPoints()
    borderTextures.top:SetPoint("TOPLEFT", castBarFrame, "TOPLEFT", 0, 0)
    borderTextures.top:SetPoint("TOPRIGHT", castBarFrame, "TOPRIGHT", 0, 0)
    borderTextures.top:SetHeight(size)
    borderTextures.top:SetColorTexture(c.r, c.g, c.b, c.a or 1)
    borderTextures.top:Show()

    borderTextures.bottom:ClearAllPoints()
    borderTextures.bottom:SetPoint("BOTTOMLEFT", castBarFrame, "BOTTOMLEFT", 0, 0)
    borderTextures.bottom:SetPoint("BOTTOMRIGHT", castBarFrame, "BOTTOMRIGHT", 0, 0)
    borderTextures.bottom:SetHeight(size)
    borderTextures.bottom:SetColorTexture(c.r, c.g, c.b, c.a or 1)
    borderTextures.bottom:Show()

    borderTextures.left:ClearAllPoints()
    borderTextures.left:SetPoint("TOPLEFT", castBarFrame, "TOPLEFT", 0, 0)
    borderTextures.left:SetPoint("BOTTOMLEFT", castBarFrame, "BOTTOMLEFT", 0, 0)
    borderTextures.left:SetWidth(size)
    borderTextures.left:SetColorTexture(c.r, c.g, c.b, c.a or 1)
    borderTextures.left:Show()

    borderTextures.right:ClearAllPoints()
    borderTextures.right:SetPoint("TOPRIGHT", castBarFrame, "TOPRIGHT", 0, 0)
    borderTextures.right:SetPoint("BOTTOMRIGHT", castBarFrame, "BOTTOMRIGHT", 0, 0)
    borderTextures.right:SetWidth(size)
    borderTextures.right:SetColorTexture(c.r, c.g, c.b, c.a or 1)
    borderTextures.right:Show()
end

-- == Bar Color ==

local function ApplyBarColor()
    local settings = UIThingsDB.castBar
    local color

    if currentNotInterruptible then
        color = settings.nonInterruptibleColor
    elseif isChanneling then
        color = settings.channelColor
    elseif settings.useClassColor then
        local _, class = UnitClass("player")
        local cc = C_ClassColor.GetClassColor(class)
        if cc then
            color = { r = cc.r, g = cc.g, b = cc.b, a = 1 }
        else
            color = settings.barColor
        end
    else
        color = settings.barColor
    end

    statusBar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
end

-- == Fade Out ==

local function FadeOut(duration)
    fadeOutDuration = duration
    fadeOutElapsed = 0
    castBarFrame:SetScript("OnUpdate", function(self, elapsed)
        fadeOutElapsed = fadeOutElapsed + elapsed
        if fadeOutElapsed >= fadeOutDuration then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            self:SetAlpha(1)
            return
        end
        self:SetAlpha(1 - (fadeOutElapsed / fadeOutDuration))
    end)
end

-- == OnUpdate Handlers ==

local function OnUpdateCasting(self, elapsed)
    local now = GetTime()
    if now >= castEndTime then
        isCasting = false
        self:SetScript("OnUpdate", nil)
        statusBar:SetValue(1)
        FadeOut(0.3)
        return
    end

    local progress = (now - castStartTime) / castDuration
    statusBar:SetValue(progress)

    if UIThingsDB.castBar.showSpark then
        local barWidth = statusBar:GetWidth()
        spark:ClearAllPoints()
        spark:SetPoint("CENTER", statusBar, "LEFT", barWidth * progress, 0)
        spark:Show()
    end

    if UIThingsDB.castBar.showCastTime then
        castTimeText:SetText(string.format("%.1fs", castEndTime - now))
    end
end

local function OnUpdateChanneling(self, elapsed)
    local now = GetTime()
    if now >= castEndTime then
        isChanneling = false
        self:SetScript("OnUpdate", nil)
        statusBar:SetValue(0)
        FadeOut(0.3)
        return
    end

    local progress = (castEndTime - now) / castDuration
    statusBar:SetValue(progress)

    if UIThingsDB.castBar.showSpark then
        local barWidth = statusBar:GetWidth()
        spark:ClearAllPoints()
        spark:SetPoint("CENTER", statusBar, "LEFT", barWidth * progress, 0)
        spark:Show()
    end

    if UIThingsDB.castBar.showCastTime then
        castTimeText:SetText(string.format("%.1fs", castEndTime - now))
    end
end

-- == Cast Event Handlers ==

local function OnCastStart()
    local name, displayName, texture, startTimeMs, endTimeMs,
    isTradeSkill, castGUID, notInterruptible, spellID = UnitCastingInfo("player")
    if not name then return end

    isCasting = true
    isChanneling = false
    currentSpellName = displayName or name
    currentNotInterruptible = notInterruptible
    castStartTime = startTimeMs / 1000
    castEndTime = endTimeMs / 1000
    castDuration = castEndTime - castStartTime

    if UIThingsDB.castBar.showIcon and texture then
        iconTexture:SetTexture(texture)
    end

    spellNameText:SetText(currentSpellName)
    ApplyBarColor()

    statusBar:SetMinMaxValues(0, 1)
    statusBar:SetValue(0)

    castBarFrame:SetAlpha(1)
    castBarFrame:Show()
    castBarFrame:SetScript("OnUpdate", OnUpdateCasting)
end

local function OnChannelStart()
    local name, displayName, texture, startTimeMs, endTimeMs,
    isTradeSkill, notInterruptible, spellID = UnitChannelInfo("player")
    if not name then return end

    isCasting = false
    isChanneling = true
    currentSpellName = displayName or name
    currentNotInterruptible = notInterruptible
    castStartTime = startTimeMs / 1000
    castEndTime = endTimeMs / 1000
    castDuration = castEndTime - castStartTime

    if UIThingsDB.castBar.showIcon and texture then
        iconTexture:SetTexture(texture)
    end

    spellNameText:SetText(currentSpellName)
    ApplyBarColor()

    statusBar:SetMinMaxValues(0, 1)
    statusBar:SetValue(1)

    castBarFrame:SetAlpha(1)
    castBarFrame:Show()
    castBarFrame:SetScript("OnUpdate", OnUpdateChanneling)
end

local function OnCastComplete()
    isCasting = false
    castBarFrame:SetScript("OnUpdate", nil)
    statusBar:SetValue(1)
    FadeOut(0.3)
end

local function OnChannelStop()
    isChanneling = false
    castBarFrame:SetScript("OnUpdate", nil)
    statusBar:SetValue(0)
    FadeOut(0.3)
end

local function OnCastFailed()
    isCasting = false
    isChanneling = false
    castBarFrame:SetScript("OnUpdate", nil)

    local fc = UIThingsDB.castBar.failedColor
    statusBar:SetStatusBarColor(fc.r, fc.g, fc.b, fc.a or 1)
    spellNameText:SetText("Failed")
    castTimeText:SetText("")

    FadeOut(0.5)
end

local function OnCastDelayed()
    local name, _, _, startTimeMs, endTimeMs = UnitCastingInfo("player")
    if not name then return end
    castStartTime = startTimeMs / 1000
    castEndTime = endTimeMs / 1000
    castDuration = castEndTime - castStartTime
end

local function OnChannelUpdate()
    local name, _, _, startTimeMs, endTimeMs = UnitChannelInfo("player")
    if not name then return end
    castStartTime = startTimeMs / 1000
    castEndTime = endTimeMs / 1000
    castDuration = castEndTime - castStartTime
end

-- == Blizzard Cast Bar ==

-- Hide Blizzard's cast bar by pushing it off-screen with alpha 0.
-- We avoid UnregisterAllEvents/Hide which taints internal mixin state
-- and causes "secret string value" errors in Blizzard's CastingBarFrame code.
local blizzBarHidden = false
local blizzBarOrigPoints = nil

function CastBar.HideBlizzardCastBar()
    if not UIThingsDB.castBar.enabled then
        CastBar.RestoreBlizzardCastBar()
        return
    end
    if not PlayerCastingBarFrame then return end
    if blizzBarHidden then return end

    -- Save original position
    if not blizzBarOrigPoints then
        blizzBarOrigPoints = {}
        for i = 1, PlayerCastingBarFrame:GetNumPoints() do
            blizzBarOrigPoints[i] = { PlayerCastingBarFrame:GetPoint(i) }
        end
    end

    -- Move off-screen and make invisible without tainting internals
    PlayerCastingBarFrame:SetAlpha(0)
    PlayerCastingBarFrame:ClearAllPoints()
    PlayerCastingBarFrame:SetPoint("TOP", UIParent, "BOTTOM", 0, -500)
    blizzBarHidden = true
end

function CastBar.RestoreBlizzardCastBar()
    if not PlayerCastingBarFrame then return end
    if not blizzBarHidden then return end

    PlayerCastingBarFrame:SetAlpha(1)
    if blizzBarOrigPoints then
        PlayerCastingBarFrame:ClearAllPoints()
        for _, pt in ipairs(blizzBarOrigPoints) do
            PlayerCastingBarFrame:SetPoint(unpack(pt))
        end
    end
    blizzBarHidden = false
end

-- == Event Registration ==

local eventFrame = CreateFrame("Frame")

function CastBar.ApplyEvents()
    if not UIThingsDB.castBar.enabled then
        eventFrame:UnregisterAllEvents()
        return
    end

    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", "player")
end

eventFrame:SetScript("OnEvent", function(self, event, unit, ...)
    if not UIThingsDB.castBar.enabled then return end
    if not castBarFrame then return end
    if not UIThingsDB.castBar.locked then return end

    if event == "UNIT_SPELLCAST_START" then
        OnCastStart()
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_SUCCEEDED" then
        if isCasting then
            OnCastComplete()
        end
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        if isCasting or isChanneling then
            OnCastFailed()
        end
    elseif event == "UNIT_SPELLCAST_DELAYED" then
        OnCastDelayed()
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_EMPOWER_START" then
        OnChannelStart()
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
        if isChanneling then
            OnChannelStop()
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" or event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
        OnChannelUpdate()
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
        currentNotInterruptible = false
        ApplyBarColor()
    elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        currentNotInterruptible = true
        ApplyBarColor()
    end
end)

-- == UpdateSettings ==

function CastBar.UpdateSettings()
    if not castBarFrame then return end

    local settings = UIThingsDB.castBar
    if not settings.enabled then
        castBarFrame:Hide()
        CastBar.HideBlizzardCastBar()
        CastBar.ApplyEvents()
        return
    end

    CastBar.ApplyEvents()
    CastBar.HideBlizzardCastBar()

    local barHeight = settings.height
    local barWidth = settings.width
    local iconSize = settings.showIcon and barHeight or 0
    local totalWidth = barWidth + (settings.showIcon and (iconSize + 2) or 0)

    castBarFrame:SetSize(totalWidth, barHeight)
    castBarFrame:SetFrameStrata("MEDIUM")

    -- Position
    castBarFrame:ClearAllPoints()
    local pos = settings.pos
    castBarFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)

    -- Icon
    if settings.showIcon then
        iconTexture:SetSize(iconSize, iconSize)
        iconTexture:ClearAllPoints()
        iconTexture:SetPoint("LEFT", castBarFrame, "LEFT", 0, 0)
        iconTexture:Show()
    else
        iconTexture:Hide()
    end

    -- StatusBar
    statusBar:ClearAllPoints()
    if settings.showIcon then
        statusBar:SetPoint("LEFT", iconTexture, "RIGHT", 2, 0)
    else
        statusBar:SetPoint("LEFT", castBarFrame, "LEFT", 0, 0)
    end
    statusBar:SetPoint("RIGHT", castBarFrame, "RIGHT", 0, 0)
    statusBar:SetHeight(barHeight)

    -- Bar color
    ApplyBarColor()

    -- Background
    local bg = settings.bgColor
    statusBar.bg:SetVertexColor(bg.r, bg.g, bg.b, bg.a or 0.7)

    -- Borders
    ApplyBorders(settings.borderSize, settings.borderColor)

    -- Font
    spellNameText:SetFont(settings.font, settings.fontSize, "OUTLINE")
    castTimeText:SetFont(settings.font, settings.fontSize, "OUTLINE")

    -- Text visibility
    if settings.showSpellName then spellNameText:Show() else spellNameText:Hide() end
    if settings.showCastTime then castTimeText:Show() else castTimeText:Hide() end

    -- Spark size
    spark:SetSize(32, barHeight * 2.5)
    if not settings.showSpark then spark:Hide() end

    -- Lock/Unlock
    if settings.locked then
        castBarFrame:EnableMouse(false)
        castBarFrame:SetBackdrop(nil)
        -- Hide preview bar when locking — real casts will show it again
        if not isCasting and not isChanneling then
            castBarFrame:Hide()
        end
    else
        castBarFrame:EnableMouse(true)
        castBarFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        castBarFrame:SetBackdropColor(0, 0, 0, 0.5)
        -- Show preview so user can see and drag the bar
        castBarFrame:Show()
        statusBar:SetValue(0.5)
        spellNameText:SetText("Cast Bar Position")
        castTimeText:SetText("1.5s")
        if settings.showIcon then
            iconTexture:SetTexture("Interface\\Icons\\Spell_Holy_MagicalSentry")
        end
    end
end

-- == Initialization ==

local function Init()
    local settings = UIThingsDB.castBar
    if not settings then return end

    -- Main container
    castBarFrame = CreateFrame("Frame", "LunaCastBar", UIParent, "BackdropTemplate")
    castBarFrame:SetClampedToScreen(true)
    castBarFrame:SetMovable(true)
    castBarFrame:RegisterForDrag("LeftButton")
    castBarFrame:SetScript("OnDragStart", function(self)
        if not UIThingsDB.castBar.locked then
            self:StartMoving()
        end
    end)
    castBarFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        UIThingsDB.castBar.pos = { point = point, x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
        -- Update config panel edit boxes if open
        local xBox = _G["UIThingsCastBarPosX"]
        local yBox = _G["UIThingsCastBarPosY"]
        local anchorDD = _G["UIThingsCastBarAnchorDropdown"]
        if xBox then xBox:SetText(tostring(UIThingsDB.castBar.pos.x)) end
        if yBox then yBox:SetText(tostring(UIThingsDB.castBar.pos.y)) end
        if anchorDD then UIDropDownMenu_SetText(anchorDD, point) end
    end)

    -- Spell icon
    iconTexture = castBarFrame:CreateTexture(nil, "ARTWORK")

    -- StatusBar
    statusBar = CreateFrame("StatusBar", nil, castBarFrame)
    statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    statusBar:SetMinMaxValues(0, 1)
    statusBar:SetValue(0)

    -- Background
    statusBar.bg = statusBar:CreateTexture(nil, "BACKGROUND")
    statusBar.bg:SetAllPoints()
    statusBar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")

    -- Spark
    spark = statusBar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetSize(32, 50)
    spark:SetBlendMode("ADD")

    -- Spell name
    spellNameText = statusBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    spellNameText:SetPoint("LEFT", statusBar, "LEFT", 4, 0)
    spellNameText:SetJustifyH("LEFT")

    -- Cast time
    castTimeText = statusBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    castTimeText:SetPoint("RIGHT", statusBar, "RIGHT", -4, 0)
    castTimeText:SetJustifyH("RIGHT")

    -- Border textures
    borderTextures.top = castBarFrame:CreateTexture(nil, "BORDER")
    borderTextures.bottom = castBarFrame:CreateTexture(nil, "BORDER")
    borderTextures.left = castBarFrame:CreateTexture(nil, "BORDER")
    borderTextures.right = castBarFrame:CreateTexture(nil, "BORDER")

    castBarFrame:Hide()

    CastBar.UpdateSettings()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if addonTable.Core and addonTable.Core.SafeAfter then
        addonTable.Core.SafeAfter(1, Init)
    else
        C_Timer.After(1, Init)
    end
end)
