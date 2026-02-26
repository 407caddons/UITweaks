local addonName, addonTable = ...
addonTable.SCT = {}
local SCT = addonTable.SCT
local EventBus = addonTable.EventBus

-- == ANCHOR FRAMES ==

local sctDamageAnchor = CreateFrame("Frame", "LunaSCTDamageAnchor", UIParent, "BackdropTemplate")
sctDamageAnchor:SetSize(150, 20)
sctDamageAnchor:SetMovable(true)
sctDamageAnchor:SetClampedToScreen(true)
sctDamageAnchor:EnableMouse(false)
sctDamageAnchor:RegisterForDrag("LeftButton")
sctDamageAnchor:SetScript("OnDragStart", sctDamageAnchor.StartMoving)
sctDamageAnchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    UIThingsDB.sct.damageAnchor = { point = point, relPoint = relPoint, x = x, y = y }
end)
sctDamageAnchor:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
sctDamageAnchor:SetBackdropColor(1, 0.2, 0.2, 0.6)
sctDamageAnchor.text = sctDamageAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
sctDamageAnchor.text:SetPoint("CENTER")
sctDamageAnchor.text:SetText("SCT Damage")
sctDamageAnchor:Hide()

local sctHealingAnchor = CreateFrame("Frame", "LunaSCTHealingAnchor", UIParent, "BackdropTemplate")
sctHealingAnchor:SetSize(150, 20)
sctHealingAnchor:SetMovable(true)
sctHealingAnchor:SetClampedToScreen(true)
sctHealingAnchor:EnableMouse(false)
sctHealingAnchor:RegisterForDrag("LeftButton")
sctHealingAnchor:SetScript("OnDragStart", sctHealingAnchor.StartMoving)
sctHealingAnchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    UIThingsDB.sct.healingAnchor = { point = point, relPoint = relPoint, x = x, y = y }
end)
sctHealingAnchor:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
sctHealingAnchor:SetBackdropColor(0.2, 1, 0.2, 0.6)
sctHealingAnchor.text = sctHealingAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
sctHealingAnchor.text:SetPoint("CENTER")
sctHealingAnchor.text:SetText("SCT Healing")
sctHealingAnchor:Hide()

-- == FRAME POOL ==

local sctPool = {}
local sctActive = {}
local SCT_MAX_ACTIVE = 30

local function RecycleSCTFrame(f)
    f:Hide()
    f:ClearAllPoints()
    for i, active in ipairs(sctActive) do
        if active == f then
            table.remove(sctActive, i)
            break
        end
    end
    table.insert(sctPool, f)
end

local function AcquireSCTFrame()
    if #sctActive >= SCT_MAX_ACTIVE then
        RecycleSCTFrame(sctActive[1])
    end

    local f = table.remove(sctPool)
    if not f then
        f = CreateFrame("Frame", nil, UIParent)
        f:SetFrameStrata("HIGH")
        f.text = f:CreateFontString(nil, "OVERLAY")
        f.text:SetPoint("CENTER")
        f:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            local progress = self.elapsed / self.duration
            if progress >= 1 then
                RecycleSCTFrame(self)
                return
            end
            local yOffset = self.scrollDistance * progress
            self:ClearAllPoints()
            self:SetPoint("BOTTOM", self.anchor, "TOP", 0, yOffset)
            if progress > 0.7 then
                self:SetAlpha(1 - ((progress - 0.7) / 0.3))
            else
                self:SetAlpha(1)
            end
        end)
    end
    return f
end

-- category: "damage" or "healing"
local function SpawnSCTText(amount, isCrit, category, targetName)
    local settings = UIThingsDB.sct
    if not settings or not settings.enabled then return end
    if category == "damage" and not settings.showDamage then return end
    if category == "healing" and not settings.showHealing then return end

    local color, anchor
    if category == "damage" then
        color = settings.damageColor
        anchor = sctDamageAnchor
    else
        color = settings.healingColor
        anchor = sctHealingAnchor
    end

    local f = AcquireSCTFrame()
    local fontSize = settings.fontSize
    if isCrit then
        fontSize = math.floor(fontSize * settings.critScale)
    end

    f.text:SetFont(settings.font or "Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
    f.text:SetTextColor(color.r, color.g, color.b)

    local displayText = tostring(amount)
    if isCrit then
        displayText = displayText .. "*"
    end
    local showName = (category == "damage" and settings.showTargetDamage) or
        (category == "healing" and settings.showTargetHealing)
    if showName and targetName and targetName ~= "" then
        displayText = displayText .. " (" .. targetName .. ")"
    end
    f.text:SetText(displayText)

    f:SetSize(f.text:GetStringWidth() + 10, f.text:GetStringHeight() + 4)
    f:ClearAllPoints()
    f:SetPoint("BOTTOM", anchor, "TOP", 0, 0)

    f.elapsed = 0
    f.duration = settings.duration
    f.scrollDistance = settings.scrollDistance
    f.anchor = anchor

    f:SetAlpha(1)
    f:Show()
    table.insert(sctActive, f)
end

local function InitSCTAnchors()
    local settings = UIThingsDB.sct
    if not settings then return end

    local da = settings.damageAnchor
    sctDamageAnchor:ClearAllPoints()
    sctDamageAnchor:SetPoint(da.point, UIParent, da.relPoint or da.point, da.x, da.y)

    local ha = settings.healingAnchor
    sctHealingAnchor:ClearAllPoints()
    sctHealingAnchor:SetPoint(ha.point, UIParent, ha.relPoint or ha.point, ha.x, ha.y)
end

function SCT.UpdateSCTSettings()
    InitSCTAnchors()

    local settings = UIThingsDB.sct
    if not settings then return end

    if settings.locked then
        sctDamageAnchor:EnableMouse(false)
        sctDamageAnchor:Hide()
        sctHealingAnchor:EnableMouse(false)
        sctHealingAnchor:Hide()
    else
        sctDamageAnchor:EnableMouse(true)
        sctDamageAnchor:Show()
        sctHealingAnchor:EnableMouse(true)
        sctHealingAnchor:Show()
    end
end

function SCT.LockSCTAnchors()
    if UIThingsDB.sct then
        UIThingsDB.sct.locked = true
        SCT.UpdateSCTSettings()
    end
end

-- == EVENT HANDLER ==

local function OnUnitCombat(event, unitTarget, combatEvent, flagText, amount, schoolMask)
    if not UIThingsDB.sct or not UIThingsDB.sct.enabled then return end
    local sctSettings = UIThingsDB.sct
    if not sctSettings.captureToFrames then return end
    if not amount or issecretvalue(amount) then return end
    if amount == 0 then return end
    local isCrit = (not issecretvalue(flagText) and flagText == "CRITICAL")

    if unitTarget == "player" then
        if combatEvent == "HEAL" then
            local targetName = sctSettings.showTargetHealing and UnitName("target") or nil
            SpawnSCTText(amount, isCrit, "healing", targetName)
        end
    elseif string.find(unitTarget, "nameplate") then
        if combatEvent == "WOUND" then
            local targetName = sctSettings.showTargetDamage and UnitName(unitTarget) or nil
            SpawnSCTText(amount, isCrit, "damage", targetName)
        end
    end
end

-- == EVENT REGISTRATION ==

local function ApplySCTEvents()
    if not UIThingsDB.sct or not UIThingsDB.sct.enabled then
        EventBus.Unregister("UNIT_COMBAT", OnUnitCombat)
        return
    end

    SetCVar("enableFloatingCombatText", UIThingsDB.sct.enabled and 1 or 0)
    if UIThingsDB.sct.captureToFrames then
        EventBus.Register("UNIT_COMBAT", OnUnitCombat, "SCT")
    else
        EventBus.Unregister("UNIT_COMBAT", OnUnitCombat)
    end
end

local function OnPlayerEnteringWorld()
    if not UIThingsDB.sct then return end
    if UIThingsDB.sct.enabled then
        InitSCTAnchors()
    end
    ApplySCTEvents()
end

EventBus.Register("PLAYER_ENTERING_WORLD", OnPlayerEnteringWorld, "SCT")

function SCT.ApplyEvents()
    ApplySCTEvents()
end
