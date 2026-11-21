-- Spawn Watch (WoW Forever): wait for a creature whose name starts with the text
-- you enter. While the panel is open and watching, nameplates, mouseover and
-- target changes are compared against it. The first sighting stops the watch,
-- plays a sound, flashes the panel and enables a Target button. The addon never
-- targets by itself: the button is a secure macro ("/tar Name") that you click.
local addonName, addon = ...
local SpawnWatch = {}
addon.SpawnWatch = SpawnWatch

local frame, edit, toggle, status, targetBtn, flash
local state = "idle" -- idle | watching | seen
local query, seenName = "", nil
local pendingAttributes = false
local openedByLayout = false
local pendingHide = false -- closed in combat: invisible now, hidden when combat ends
local flashUntil = 0

local EVENTS = { "NAME_PLATE_UNIT_ADDED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED" }

local function DB() return UIThingsDB and UIThingsDB.spawnWatch end

local function Trim(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- ============================================================
-- Display
-- ============================================================
local function ApplyTargetButton()
    if not targetBtn then return end
    -- Secure attributes cannot change in combat; retry when it ends.
    if InCombatLockdown() then
        pendingAttributes = true
        return
    end
    pendingAttributes = false
    if state == "seen" and seenName then
        targetBtn:SetAttribute("type", "macro")
        targetBtn:SetAttribute("macrotext", "/tar " .. seenName)
        targetBtn:SetAlpha(1)
    else
        targetBtn:SetAttribute("type", nil)
        targetBtn:SetAttribute("macrotext", nil)
        targetBtn:SetAlpha(0.4)
    end
end

local function UpdateDisplay()
    if not frame then return end
    if state == "watching" then
        status:SetText("|cFFFFD100Watching for \"" .. Trim(edit:GetText()) .. "...\"|r")
        toggle:SetText("Stop")
    elseif state == "seen" then
        status:SetText("|cFF33FF33Seen: " .. tostring(seenName) .. "|r")
        toggle:SetText("Start")
    else
        status:SetText("|cFF999999Enter the start of a name|r")
        toggle:SetText("Start")
    end
    targetBtn:SetText(state == "seen" and ("Target " .. tostring(seenName)) or "Target")
    ApplyTargetButton()
end

local function StartFlash()
    flashUntil = GetTime() + 6
    flash:Show()
    frame:SetScript("OnUpdate", function()
        local remaining = flashUntil - GetTime()
        if remaining <= 0 then
            flash:Hide()
            frame:SetScript("OnUpdate", nil)
            return
        end
        flash:SetAlpha(0.15 + 0.35 * (0.5 + 0.5 * math.sin(GetTime() * 8)))
    end)
end

-- ============================================================
-- Detection
-- ============================================================
local function MatchedName(unit)
    if state ~= "watching" or query == "" or not unit then return nil end
    if not UnitExists(unit) or UnitIsPlayer(unit) then return nil end
    -- Corpses keep their name; only a living creature counts as a sighting.
    local dead = UnitIsDead(unit)
    if not addon.Secret.IsPublic(dead) or dead then return nil end
    local name = UnitName(unit)
    if type(name) ~= "string" or not addon.Secret.CanAccessValue(name) then return nil end
    if name:lower():sub(1, #query) == query then return name end
end

local Stop

local function Sighted(name)
    state, seenName = "seen", name
    for _, event in ipairs(EVENTS) do addon.EventBus.Unregister(event, SpawnWatch.OnEvent) end
    print("|cFF00FF96Spawn Watch|r: |cFF33FF33" .. name .. "|r is nearby!")
    pcall(PlaySound, (SOUNDKIT and SOUNDKIT.READY_CHECK) or 8960)
    UpdateDisplay()
    StartFlash()
end

function SpawnWatch.OnEvent(event, unit)
    if state ~= "watching" then return end
    local token = unit
    if event == "UPDATE_MOUSEOVER_UNIT" then token = "mouseover"
    elseif event == "PLAYER_TARGET_CHANGED" then token = "target" end
    local name = MatchedName(token)
    if name then Sighted(name) end
end

local function ScanCurrent()
    for _, token in ipairs({ "target", "mouseover" }) do
        local name = MatchedName(token)
        if name then Sighted(name) return end
    end
    for i = 1, 40 do
        local name = MatchedName("nameplate" .. i)
        if name then Sighted(name) return end
    end
end

local function Start()
    local raw = Trim(edit:GetText())
    if raw == "" then
        status:SetText("|cFFFF5555Enter a name first|r")
        return
    end
    query, seenName, state = raw:lower(), nil, "watching"
    flash:Hide()
    frame:SetScript("OnUpdate", nil)
    local db = DB()
    if db then db.lastName = raw end
    for _, event in ipairs(EVENTS) do addon.EventBus.Register(event, SpawnWatch.OnEvent, "SpawnWatch") end
    UpdateDisplay()
    ScanCurrent()
end

Stop = function()
    if state == "watching" then
        for _, event in ipairs(EVENTS) do addon.EventBus.Unregister(event, SpawnWatch.OnEvent) end
    end
    state = "idle"
    if frame then
        flash:Hide()
        frame:SetScript("OnUpdate", nil)
        UpdateDisplay()
    end
end

-- ============================================================
-- Frame
-- ============================================================
-- The panel holds a secure Target button, so it is protected: Hide()/Show() are
-- blocked in combat. Closing in combat stops watching and makes it invisible;
-- the real Hide happens on PLAYER_REGEN_ENABLED.
local function HidePanel()
    if not frame then return end
    if InCombatLockdown() then
        Stop()
        frame:SetAlpha(0)
        pendingHide = true
        return
    end
    pendingHide = false
    frame:SetAlpha(1)
    frame:Hide()
end
-- Returns false when the panel cannot be shown (closed, and in combat).
local function ShowPanel()
    if pendingHide then
        pendingHide = false
        frame:SetAlpha(1)
        return true
    end
    if frame:IsShown() then return true end
    if InCombatLockdown() then return false end
    frame:Show()
    return true
end
local function SavePosition()
    local db = DB()
    if not db or not frame then return end
    local point, _, _, x, y = frame:GetPoint()
    db.pos = { point = point, x = x, y = y }
end

local function Ensure()
    if frame then return frame end
    local db = DB()
    frame = CreateFrame("Frame", "LunaSpawnWatch", UIParent, "BackdropTemplate")
    frame:SetSize(250, 108)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    local pos = db and db.pos or { point = "CENTER", x = 0, y = 200 }
    frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    frame:Hide()
    frame:SetScript("OnMouseDown", function(self)
        if not InCombatLockdown() then self:StartMoving() end
    end)
    frame:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    -- Watching only runs while the panel is open.
    frame:SetScript("OnHide", Stop)

    flash = frame:CreateTexture(nil, "BACKGROUND")
    flash:SetAllPoints()
    flash:SetColorTexture(1, 0.8, 0.1, 1)
    flash:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("Spawn Watch")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", HidePanel)

    edit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    edit:SetSize(150, 20)
    edit:SetPoint("TOPLEFT", 16, -30)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(60)
    edit:SetText(db and db.lastName or "")
    edit:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if state ~= "watching" then Start() end
    end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEditFocusLost", function() UpdateDisplay() end)

    toggle = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    toggle:SetSize(64, 22)
    toggle:SetPoint("LEFT", edit, "RIGHT", 8, 0)
    toggle:SetScript("OnClick", function()
        if state == "watching" then Stop() else Start() end
    end)

    status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", -2, -6)
    status:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    status:SetJustifyH("LEFT")

    targetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    targetBtn:RegisterForClicks("AnyUp", "AnyDown")
    targetBtn:SetSize(228, 22)
    targetBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 8)

    UpdateDisplay()
    return frame
end

function SpawnWatch.Toggle()
    -- First open builds the secure Target button, which cannot happen in combat.
    if not frame and InCombatLockdown() then
        print("|cFF00FF96Spawn Watch|r: can't open during combat.")
        return
    end
    Ensure()
    if frame:IsShown() and not pendingHide then
        HidePanel()
    elseif not ShowPanel() then
        print("|cFF00FF96Spawn Watch|r: can't open during combat.")
    end
end

addon.EventBus.Register("PLAYER_REGEN_ENABLED", function()
    if pendingAttributes then ApplyTargetButton() end
    if pendingHide then HidePanel() end
end, "SpawnWatch")

SLASH_LUNASPAWNWATCH1 = "/spawnwatch"
SLASH_LUNASPAWNWATCH2 = "/sw"
SlashCmdList["LUNASPAWNWATCH"] = function(msg)
    if (msg or ""):lower():match("^%s*debug") then
        local names = {}
        for i = 1, 40 do
            local unit = "nameplate" .. i
            if UnitExists(unit) then
                local name = UnitName(unit)
                names[#names + 1] = (type(name) == "string" and addon.Secret.CanAccessValue(name)) and name or "?"
            end
        end
        print("|cFF00FF96Spawn Watch|r nameplates:", #names == 0 and "none visible (are enemy nameplates on? press V)" or table.concat(names, ", "))
        return
    end
    SpawnWatch.Toggle()
end

-- Layout Mode integration: show the panel while unlocked so it can be dragged.
addon.LayoutMode.RegisterModule("SpawnWatch", {
    apply = function(locked)
        if not DB() then return end
        Ensure()
        if not locked then
            if not frame:IsShown() or pendingHide then openedByLayout = ShowPanel() end
        elseif openedByLayout then
            openedByLayout = false
            HidePanel()
        end
    end,
})
addon.LayoutMode.RegisterTarget("Spawn watch", function() return frame end, function()
    return DB() ~= nil
end, SavePosition)
