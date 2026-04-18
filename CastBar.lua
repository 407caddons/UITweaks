local addonName, addonTable = ...
local CastBar = {}
addonTable.CastBar = CastBar

local EventBus = addonTable.EventBus

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

-- == Debug ==

local CASTBAR_DEBUG = false  -- set to true to enable debug logging

local function DBG(msg)
    if not CASTBAR_DEBUG then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff99[CastBar]|r " .. tostring(msg))
end

-- Periodic state ticker: prints once per second while casting
local debugTickElapsed = 0
local function OnUpdateDebugTick(self, elapsed)
    debugTickElapsed = debugTickElapsed + elapsed
    if debugTickElapsed >= 1 then
        debugTickElapsed = 0
        local now = GetTime()
        DBG(string.format("TICK isCasting=%s isChanneling=%s now=%.3f endTime=%.3f remaining=%.3fs alpha=%.2f shown=%s",
            tostring(isCasting), tostring(isChanneling),
            now, castEndTime, castEndTime - now,
            castBarFrame and castBarFrame:GetAlpha() or -1,
            tostring(castBarFrame and castBarFrame:IsShown() or false)
        ))
    end
end

local debugTickFrame = nil

local function StartDebugTick()
    if not CASTBAR_DEBUG then return end
    if not debugTickFrame then
        debugTickFrame = CreateFrame("Frame")
    end
    debugTickElapsed = 0
    debugTickFrame:SetScript("OnUpdate", OnUpdateDebugTick)
end

local function StopDebugTick()
    if debugTickFrame then
        debugTickFrame:SetScript("OnUpdate", nil)
    end
end

-- == Border Helper ==

local function ApplyBorders(frame, borders, size, color)
    if size <= 0 then
        for _, tex in pairs(borders) do tex:Hide() end
        return
    end
    local c = color or { r = 0, g = 0, b = 0, a = 1 }

    borders.top:ClearAllPoints()
    borders.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    borders.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    borders.top:SetHeight(size)
    borders.top:SetColorTexture(c.r, c.g, c.b, c.a or 1)
    borders.top:Show()

    borders.bottom:ClearAllPoints()
    borders.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    borders.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    borders.bottom:SetHeight(size)
    borders.bottom:SetColorTexture(c.r, c.g, c.b, c.a or 1)
    borders.bottom:Show()

    borders.left:ClearAllPoints()
    borders.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    borders.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    borders.left:SetWidth(size)
    borders.left:SetColorTexture(c.r, c.g, c.b, c.a or 1)
    borders.left:Show()

    borders.right:ClearAllPoints()
    borders.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    borders.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    borders.right:SetWidth(size)
    borders.right:SetColorTexture(c.r, c.g, c.b, c.a or 1)
    borders.right:Show()
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
    DBG(string.format("FadeOut called — duration=%.2fs isCasting=%s isChanneling=%s remaining=%.3fs",
        duration, tostring(isCasting), tostring(isChanneling), castEndTime - GetTime()))
    StopDebugTick()
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
        DBG(string.format("OnUpdate: castEndTime reached — now=%.3f endTime=%.3f", now, castEndTime))
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
    DBG(string.format("CAST START '%s' startTime=%.3f endTime=%.3f duration=%.3fs GetTime=%.3f",
        currentSpellName, castStartTime, castEndTime, castDuration, GetTime()))
    StartDebugTick()

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
    DBG(string.format("CHANNEL START '%s' startTime=%.3f endTime=%.3f duration=%.3fs GetTime=%.3f",
        currentSpellName, castStartTime, castEndTime, castDuration, GetTime()))
    StartDebugTick()

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
    DBG(string.format("OnCastComplete — remaining=%.3fs", castEndTime - GetTime()))
    isCasting = false
    castBarFrame:SetScript("OnUpdate", nil)
    statusBar:SetValue(1)
    FadeOut(0.3)
end

local function OnChannelStop()
    DBG(string.format("OnChannelStop — remaining=%.3fs", castEndTime - GetTime()))
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

-- == Target Cast Bar State ==

local targetCastBarFrame
local targetStatusBar
local targetSpark
local targetIconTexture
local targetSpellNameText
local targetCastTimeText
local targetBorderTextures = {}

local targetIsCasting = false
local targetIsChanneling = false
local targetCastStartSafe = 0   -- GetTime() at cast start, never tainted
local targetCurrentNotInterruptible = false

local targetFadeOutDuration = 0
local targetFadeOutElapsed = 0

-- == Target Bar Color ==

local function ApplyTargetBarColor()
    local settings = UIThingsDB.castBar
    local color
    if targetCurrentNotInterruptible then
        color = settings.nonInterruptibleColor
    elseif targetIsChanneling then
        color = settings.channelColor
    else
        color = settings.targetBar.barColor
    end
    targetStatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
end

-- == Target Fade Out ==

local function TargetFadeOut(duration)
    targetFadeOutDuration = duration
    targetFadeOutElapsed = 0
    targetCastBarFrame:SetScript("OnUpdate", function(self, elapsed)
        targetFadeOutElapsed = targetFadeOutElapsed + elapsed
        if targetFadeOutElapsed >= targetFadeOutDuration then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            self:SetAlpha(1)
            return
        end
        self:SetAlpha(1 - (targetFadeOutElapsed / targetFadeOutDuration))
    end)
end

-- == Target OnUpdate Handlers ==

-- All progress computed from targetCastStartSafe (safe GetTime() value) and a
-- fixed 3-second sweep. No tainted values involved anywhere.
local TARGET_SWEEP_DURATION = 3

local function OnUpdateTargetCasting(self, elapsed)
    local progress = (GetTime() - targetCastStartSafe) / TARGET_SWEEP_DURATION
    if progress > 1 then progress = 1 end
    targetStatusBar:SetValue(progress)
end

local function OnUpdateTargetChanneling(self, elapsed)
    local progress = (GetTime() - targetCastStartSafe) / TARGET_SWEEP_DURATION
    if progress > 1 then progress = 1 end
    targetStatusBar:SetValue(1 - progress)
end

-- == Target Cast Event Handlers ==

-- UnitCastingDuration/UnitChannelDuration return a timer object that can be passed
-- directly to SetTimerDuration — no arithmetic on tainted values needed.
-- name/displayName/texture are passed to SetText/SetTexture (safe with tainted values).
local function OnTargetCastStart(name, displayName, texture, timerObj)
    targetIsCasting = true
    targetIsChanneling = false
    targetCurrentNotInterruptible = false
    targetCastStartSafe = GetTime()
    if UIThingsDB.castBar.showIcon and texture then
        targetIconTexture:SetTexture(texture)
    end
    targetSpellNameText:SetText(displayName or name)
    targetCastTimeText:SetText("")
    ApplyTargetBarColor()
    targetStatusBar:SetMinMaxValues(0, 1)
    targetStatusBar:SetValue(0)
    targetCastBarFrame:SetAlpha(1)
    targetCastBarFrame:Show()
    if targetStatusBar.SetTimerDuration and timerObj then
        targetStatusBar:SetTimerDuration(timerObj, Enum.StatusBarInterpolation.None, 0)
        if UIThingsDB.castBar.showCastTime then
            targetCastBarFrame:SetScript("OnUpdate", function(self)
                local dur = targetStatusBar:GetTimerDuration()
                if dur then
                    targetCastTimeText:SetText(string.format("%.1fs", dur:GetRemainingDuration()))
                end
            end)
        end
    else
        targetCastBarFrame:SetScript("OnUpdate", OnUpdateTargetCasting)
    end
end

local function OnTargetChannelStart(name, displayName, texture, timerObj)
    targetIsCasting = false
    targetIsChanneling = true
    targetCurrentNotInterruptible = false
    targetCastStartSafe = GetTime()
    if UIThingsDB.castBar.showIcon and texture then
        targetIconTexture:SetTexture(texture)
    end
    targetSpellNameText:SetText(displayName or name)
    targetCastTimeText:SetText("")
    ApplyTargetBarColor()
    targetStatusBar:SetMinMaxValues(0, 1)
    targetStatusBar:SetValue(1)
    targetCastBarFrame:SetAlpha(1)
    targetCastBarFrame:Show()
    if targetStatusBar.SetTimerDuration and timerObj then
        targetStatusBar:SetTimerDuration(timerObj, Enum.StatusBarInterpolation.None, 1)
        if UIThingsDB.castBar.showCastTime then
            targetCastBarFrame:SetScript("OnUpdate", function(self)
                local dur = targetStatusBar:GetTimerDuration()
                if dur then
                    targetCastTimeText:SetText(string.format("%.1fs", dur:GetRemainingDuration()))
                end
            end)
        end
    else
        targetCastBarFrame:SetScript("OnUpdate", OnUpdateTargetChanneling)
    end
end

local function OnTargetCastComplete()
    targetIsCasting = false
    targetCastBarFrame:SetScript("OnUpdate", nil)
    targetStatusBar:SetValue(1)
    TargetFadeOut(0.3)
end

local function OnTargetChannelStop()
    targetIsChanneling = false
    targetCastBarFrame:SetScript("OnUpdate", nil)
    targetStatusBar:SetValue(0)
    TargetFadeOut(0.3)
end

local function OnTargetCastFailed()
    targetIsCasting = false
    targetIsChanneling = false
    targetCastBarFrame:SetScript("OnUpdate", nil)
    local fc = UIThingsDB.castBar.failedColor
    targetStatusBar:SetStatusBarColor(fc.r, fc.g, fc.b, fc.a or 1)
    targetSpellNameText:SetText("Failed")
    targetCastTimeText:SetText("")
    TargetFadeOut(0.5)
end


local function OnTargetChanged()
    if not targetCastBarFrame then return end
    local name, displayName, texture = UnitCastingInfo("target")
    if name then
        OnTargetCastStart(name, displayName, texture, UnitCastingDuration("target"))
        return
    end
    local cname, cdisplay, ctex = UnitChannelInfo("target")
    if cname then
        OnTargetChannelStart(cname, cdisplay, ctex, UnitChannelDuration("target"))
        return
    end
    targetIsCasting = false
    targetIsChanneling = false
    targetCastBarFrame:SetScript("OnUpdate", nil)
    targetCastBarFrame:Hide()
    targetCastBarFrame:SetAlpha(1)
end

-- == Blizzard Cast Bar ==

-- State-driver suppression: registers "visibility=hide" on PlayerCastingBarFrame
-- when enabled, unregisters when disabled. Blizzard's secure state machine keeps
-- the bar hidden even during combat once registered. Register/Unregister itself
-- must happen outside combat; combat-time toggles defer to PLAYER_REGEN_ENABLED.
local blizzBarHidden = false      -- desired state: true = keep hidden
local blizzBarApplied = false     -- tracks whether state driver is currently registered
local blizzBarPending = false     -- waiting for PLAYER_REGEN_ENABLED to re-apply

local function ApplyBlizzBarVisibility()
    if not PlayerCastingBarFrame then return end
    if InCombatLockdown() then
        blizzBarPending = true
        return
    end
    blizzBarPending = false

    if blizzBarHidden then
        if not blizzBarApplied then
            RegisterStateDriver(PlayerCastingBarFrame, "visibility", "hide")
            blizzBarApplied = true
        end
    else
        if blizzBarApplied then
            UnregisterStateDriver(PlayerCastingBarFrame, "visibility")
            blizzBarApplied = false
            -- Only restore if actively casting so we don't flash a stale bar.
            local isActive = UnitCastingInfo("player") or UnitChannelInfo("player")
            if isActive then
                PlayerCastingBarFrame:Show()
            end
        end
    end
end

EventBus.Register("PLAYER_REGEN_ENABLED", function()
    if blizzBarPending then ApplyBlizzBarVisibility() end
end, "CastBar:BlizzBarDefer")

function CastBar.HideBlizzardCastBar()
    if not UIThingsDB.castBar.enabled then
        CastBar.RestoreBlizzardCastBar()
        return
    end
    blizzBarHidden = true
    ApplyBlizzBarVisibility()
end

function CastBar.RestoreBlizzardCastBar()
    blizzBarHidden = false
    ApplyBlizzBarVisibility()
end

-- == Event Registration ==

local eventFrame = CreateFrame("Frame")

function CastBar.ApplyEvents()
    eventFrame:UnregisterAllEvents()
    if not UIThingsDB.castBar.enabled then return end

    local targetEnabled = UIThingsDB.castBar.targetBar and UIThingsDB.castBar.targetBar.enabled

    if targetEnabled then
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player", "target")
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player", "target")
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "target")
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player", "target")
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player", "target")
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player", "target")
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "target")
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "target")
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player", "target")
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "player", "target")
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "player", "target")
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    else
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
    end
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", "player")
end

eventFrame:SetScript("OnEvent", function(self, event, unit, ...)
    if not UIThingsDB.castBar.enabled then return end

    if event == "PLAYER_TARGET_CHANGED" then
        OnTargetChanged()
        return
    end

    if unit == "player" then
        if not castBarFrame then return end

        if CASTBAR_DEBUG and (isCasting or isChanneling or event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_EMPOWER_START") then
            DBG(string.format("EVENT %s isCasting=%s isChanneling=%s remaining=%.3fs",
                event, tostring(isCasting), tostring(isChanneling), castEndTime - GetTime()))
        end

        if event == "UNIT_SPELLCAST_START" then
            OnCastStart()
        elseif event == "UNIT_SPELLCAST_STOP" then
            if isCasting then
                DBG(string.format("STOP triggered complete — remaining=%.3fs", castEndTime - GetTime()))
                OnCastComplete()
            end
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            if isCasting then
                local remaining = castEndTime - GetTime()
                if remaining <= 0.5 then
                    DBG(string.format("SUCCEEDED triggered complete — remaining=%.3fs", remaining))
                    OnCastComplete()
                else
                    DBG(string.format("SUCCEEDED ignored (early) — remaining=%.3fs, letting OnUpdate finish", remaining))
                end
            end
        elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
            if isCasting or isChanneling then
                -- A new cast may have already started (old cast cancelled by casting something new).
                -- If so, restart the bar for the new cast rather than showing Failed.
                local newCast = UnitCastingInfo("player")
                local newChannel = not newCast and UnitChannelInfo("player")
                if newCast then
                    DBG("FAILED/INTERRUPTED ignored — new cast already active, restarting")
                    OnCastStart()
                elseif newChannel then
                    DBG("FAILED/INTERRUPTED ignored — new channel already active, restarting")
                    OnChannelStart()
                else
                    OnCastFailed()
                end
            end
        elseif event == "UNIT_SPELLCAST_DELAYED" then
            OnCastDelayed()
        elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_EMPOWER_START" then
            OnChannelStart()
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
            if isChanneling then OnChannelStop() end
        elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" or event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
            OnChannelUpdate()
        elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
            currentNotInterruptible = false
            ApplyBarColor()
        elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
            currentNotInterruptible = true
            ApplyBarColor()
        end

    elseif unit == "target" then
        if not targetCastBarFrame then return end
        if not (UIThingsDB.castBar.targetBar and UIThingsDB.castBar.targetBar.enabled) then return end

        -- Call UnitCastingInfo/UnitChannelInfo here and pass values directly to handlers.
        -- Handlers use SetMinMaxValues/SetValue/SetText/SetTexture with the tainted values —
        -- all safe. No arithmetic or comparison on tainted values anywhere.
        if event == "UNIT_SPELLCAST_START" then
            local n, dn, tx = UnitCastingInfo("target")
            if n then OnTargetCastStart(n, dn, tx, UnitCastingDuration("target")) end
        elseif event == "UNIT_SPELLCAST_STOP" then
            if targetIsCasting then OnTargetCastComplete() end
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            if targetIsCasting then OnTargetCastComplete() end
        elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
            if targetIsCasting or targetIsChanneling then
                local newName = UnitCastingInfo("target") or UnitChannelInfo("target")
                if not newName then OnTargetCastFailed() end
            end
        elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
            local n, dn, tx = UnitChannelInfo("target")
            if n then OnTargetChannelStart(n, dn, tx, UnitChannelDuration("target")) end
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            if targetIsChanneling then OnTargetChannelStop() end
        elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
            targetCurrentNotInterruptible = false
            ApplyTargetBarColor()
        elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
            targetCurrentNotInterruptible = true
            ApplyTargetBarColor()
        end
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

    -- Bar texture
    local texturePath = settings.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    statusBar:SetStatusBarTexture(texturePath)
    statusBar.bg:SetTexture(texturePath)

    -- Bar color
    ApplyBarColor()

    -- Background
    local bg = settings.bgColor
    statusBar.bg:SetVertexColor(bg.r, bg.g, bg.b, bg.a or 0.7)

    -- Borders
    ApplyBorders(castBarFrame, borderTextures, settings.borderSize, settings.borderColor)

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

    -- == Target Cast Bar ==
    CastBar.UpdateTargetSettings()
end

function CastBar.UpdateTargetSettings()
    if not targetCastBarFrame then return end
    local settings = UIThingsDB.castBar
    local tbSettings = settings.targetBar

    if not tbSettings or not tbSettings.enabled then
        targetIsCasting = false
        targetIsChanneling = false
        targetCastBarFrame:SetScript("OnUpdate", nil)
        targetCastBarFrame:Hide()
        return
    end

    local barHeight = settings.height
    local barWidth = settings.width
    local iconSize = settings.showIcon and barHeight or 0
    local totalWidth = barWidth + (settings.showIcon and (iconSize + 2) or 0)

    targetCastBarFrame:SetSize(totalWidth, barHeight)
    targetCastBarFrame:SetFrameStrata("MEDIUM")

    targetCastBarFrame:ClearAllPoints()
    local pos = tbSettings.pos
    targetCastBarFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)

    if settings.showIcon then
        targetIconTexture:SetSize(iconSize, iconSize)
        targetIconTexture:ClearAllPoints()
        targetIconTexture:SetPoint("LEFT", targetCastBarFrame, "LEFT", 0, 0)
        targetIconTexture:Show()
    else
        targetIconTexture:Hide()
    end

    targetStatusBar:ClearAllPoints()
    if settings.showIcon then
        targetStatusBar:SetPoint("LEFT", targetIconTexture, "RIGHT", 2, 0)
    else
        targetStatusBar:SetPoint("LEFT", targetCastBarFrame, "LEFT", 0, 0)
    end
    targetStatusBar:SetPoint("RIGHT", targetCastBarFrame, "RIGHT", 0, 0)
    targetStatusBar:SetHeight(barHeight)

    local texturePath = settings.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    targetStatusBar:SetStatusBarTexture(texturePath)
    targetStatusBar.bg:SetTexture(texturePath)

    ApplyTargetBarColor()

    local bg = settings.bgColor
    targetStatusBar.bg:SetVertexColor(bg.r, bg.g, bg.b, bg.a or 0.7)

    ApplyBorders(targetCastBarFrame, targetBorderTextures, settings.borderSize, settings.borderColor)

    targetSpellNameText:SetFont(settings.font, settings.fontSize, "OUTLINE")
    targetCastTimeText:SetFont(settings.font, settings.fontSize, "OUTLINE")

    if settings.showSpellName then targetSpellNameText:Show() else targetSpellNameText:Hide() end
    if settings.showCastTime then targetCastTimeText:Show() else targetCastTimeText:Hide() end

    targetSpark:SetSize(32, barHeight * 2.5)
    if not settings.showSpark then targetSpark:Hide() end

    if tbSettings.locked then
        targetCastBarFrame:EnableMouse(false)
        targetCastBarFrame:SetBackdrop(nil)
        if not targetIsCasting and not targetIsChanneling then
            targetCastBarFrame:Hide()
        end
    else
        targetCastBarFrame:EnableMouse(true)
        targetCastBarFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        targetCastBarFrame:SetBackdropColor(0, 0, 0, 0.5)
        targetCastBarFrame:Show()
        targetStatusBar:SetValue(0.5)
        targetSpellNameText:SetText("Target Cast Bar")
        targetCastTimeText:SetText("1.5s")
        if settings.showIcon then
            targetIconTexture:SetTexture("Interface\\Icons\\Spell_Holy_MagicalSentry")
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
        x = math.floor(x * 10 + 0.5) / 10
        y = math.floor(y * 10 + 0.5) / 10
        UIThingsDB.castBar.pos = { point = point, x = x, y = y }
        -- Update config panel edit boxes if open
        local xBox = _G["UIThingsCastBarPosX"]
        local yBox = _G["UIThingsCastBarPosY"]
        local anchorDD = _G["UIThingsCastBarAnchorDropdown"]
        if xBox then xBox:SetText(tostring(x)) end
        if yBox then yBox:SetText(tostring(y)) end
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

    -- == Target Cast Bar Frame ==
    targetCastBarFrame = CreateFrame("Frame", "LunaTargetCastBar", UIParent, "BackdropTemplate")
    targetCastBarFrame:SetClampedToScreen(true)
    targetCastBarFrame:SetMovable(true)
    targetCastBarFrame:RegisterForDrag("LeftButton")
    targetCastBarFrame:SetScript("OnDragStart", function(self)
        local tbSettings = UIThingsDB.castBar.targetBar
        if tbSettings and not tbSettings.locked then
            self:StartMoving()
        end
    end)
    targetCastBarFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        x = math.floor(x * 10 + 0.5) / 10
        y = math.floor(y * 10 + 0.5) / 10
        UIThingsDB.castBar.targetBar.pos = { point = point, x = x, y = y }
        local xBox = _G["UIThingsTargetCastBarPosX"]
        local yBox = _G["UIThingsTargetCastBarPosY"]
        if xBox then xBox:SetText(tostring(x)) end
        if yBox then yBox:SetText(tostring(y)) end
    end)

    targetIconTexture = targetCastBarFrame:CreateTexture(nil, "ARTWORK")

    targetStatusBar = CreateFrame("StatusBar", nil, targetCastBarFrame)
    targetStatusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    targetStatusBar:SetMinMaxValues(0, 1)
    targetStatusBar:SetValue(0)

    targetStatusBar.bg = targetStatusBar:CreateTexture(nil, "BACKGROUND")
    targetStatusBar.bg:SetAllPoints()
    targetStatusBar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")

    targetSpark = targetStatusBar:CreateTexture(nil, "OVERLAY")
    targetSpark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    targetSpark:SetSize(32, 50)
    targetSpark:SetBlendMode("ADD")

    targetSpellNameText = targetStatusBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    targetSpellNameText:SetPoint("LEFT", targetStatusBar, "LEFT", 4, 0)
    targetSpellNameText:SetJustifyH("LEFT")

    targetCastTimeText = targetStatusBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    targetCastTimeText:SetPoint("RIGHT", targetStatusBar, "RIGHT", -4, 0)
    targetCastTimeText:SetJustifyH("RIGHT")

    targetBorderTextures.top = targetCastBarFrame:CreateTexture(nil, "BORDER")
    targetBorderTextures.bottom = targetCastBarFrame:CreateTexture(nil, "BORDER")
    targetBorderTextures.left = targetCastBarFrame:CreateTexture(nil, "BORDER")
    targetBorderTextures.right = targetCastBarFrame:CreateTexture(nil, "BORDER")

    targetCastBarFrame:Hide()

    CastBar.UpdateSettings()
end

EventBus.Register("PLAYER_LOGIN", function()
    if addonTable.Core and addonTable.Core.SafeAfter then
        addonTable.Core.SafeAfter(1, Init)
    else
        C_Timer.After(1, Init)
    end
end)
