local addonName, addonTable = ...
addonTable.DamageMeter = {}

local EventBus = addonTable.EventBus
local SafeAfter = addonTable.Core.SafeAfter

-- ============================================================
-- Module State
-- ============================================================

local meterWindow   -- DamageMeter (the parent container frame)
local skinFrame     -- BackdropTemplate frame wrapping all session windows

local suppressSync   = false
local hooksInstalled = false
local dragInstalled  = false
local savedHeaderHeight = nil

-- Per-session state: sessions[i] = { window, overlayFrame, btnD, btnCO, btnS }
local sessions = {}

local TITLE_ROW_H = 20
local STRIP_W     = 24   -- width of the D/O/S button column per session

local SyncOverlay              -- forward declaration
local ApplyPositionAndSize     -- forward declaration
local SyncAllBlizzardButtons   -- forward declaration
local UpdateAllSessionLabels   -- forward declaration
local IsShowingCurrentSession  -- forward declaration

-- ============================================================
-- Session Window Discovery
-- ============================================================

local function GetMeterWindow()
    local s1 = _G["DamageMeterSessionWindow1"]
    if s1 then
        local par = s1:GetParent()
        if par and par:GetName() == "DamageMeter" then
            return par
        end
    end
    return s1
end

local function GetSessionWindows()
    local list = {}
    local i = 1
    while true do
        local w = _G["DamageMeterSessionWindow" .. i]
        if not w then break end
        -- Only include windows that are visible (Blizzard hides rather than destroys them)
        if w:IsShown() then
            list[#list + 1] = w
        end
        i = i + 1
    end
    return list
end

-- ============================================================
-- Drag / Lock
-- ============================================================

local function ApplyLock()
    if not skinFrame then return end
    if UIThingsDB.damageMeter.locked then
        skinFrame:EnableMouse(false)
        skinFrame:SetMovable(false)
    else
        skinFrame:EnableMouse(true)
        skinFrame:SetMovable(true)
        skinFrame:RegisterForDrag("LeftButton")
        if not dragInstalled then
            dragInstalled = true
            skinFrame:SetScript("OnDragStart", function(self)
                if not UIThingsDB.damageMeter.locked then
                    self:StartMoving()
                end
            end)
            skinFrame:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
                local cx, cy   = self:GetCenter()
                local pcx, pcy = UIParent:GetCenter()
                if cx and cy and pcx and pcy then
                    UIThingsDB.damageMeter.pos.x     = math.floor(cx - pcx + 0.5)
                    UIThingsDB.damageMeter.pos.y     = math.floor(cy - pcy + 0.5)
                    UIThingsDB.damageMeter.pos.point = "CENTER"
                end
                ApplyPositionAndSize()
                if addonTable.DamageMeter.RefreshPosSliders then
                    addonTable.DamageMeter.RefreshPosSliders()
                end
            end)
        end
    end
end

-- ============================================================
-- Reflect Chat
-- ============================================================

local function ReflectChat()
    if not meterWindow then return end
    if InCombatLockdown() then return end
    local chat = _G["LunaChatSkinContainer"]
    if not chat then return end
    local pcx, pcy = UIParent:GetCenter()
    if not pcx then return end
    local ccx, ccy = chat:GetCenter()
    if not ccx then return end
    local reflectedOffX = -(ccx - pcx)
    meterWindow:ClearAllPoints()
    meterWindow:SetPoint("CENTER", UIParent, "CENTER", reflectedOffX, ccy - pcy)
    local cx2, cy2 = meterWindow:GetCenter()
    if cx2 and cy2 then
        UIThingsDB.damageMeter.pos.x     = math.floor(cx2 - pcx + 0.5)
        UIThingsDB.damageMeter.pos.y     = math.floor(cy2 - pcy + 0.5)
        UIThingsDB.damageMeter.pos.point = "CENTER"
    end
    SafeAfter(0, SyncOverlay)
end

function addonTable.DamageMeter.SetLocked(locked)
    UIThingsDB.damageMeter.locked = locked
    ApplyLock()
end

function addonTable.DamageMeter.ReflectChat()
    ReflectChat()
end

-- ============================================================
-- Size / Position
-- ============================================================

-- Returns the width/height of a single session pane.
local function GetSessionSize()
    local s  = UIThingsDB.damageMeter
    local sw = s.width  or 0
    local sh = s.height or 0
    if sw > 0 and sh > 0 then return sw, sh end
    local cf = _G["LunaChatSkinContainer"]
    if cf and cf:GetWidth() ~= 0 then
        return cf:GetWidth(), cf:GetHeight()
    end
    -- Use the raw session window size (not meterWindow, which we resize dynamically)
    local sw1 = _G["DamageMeterSessionWindow1"]
    if sw1 then
        local ww, hh = sw1:GetWidth(), sw1:GetHeight()
        if ww > 0 and hh > 0 then return ww, hh end
    end
    return 200, 120
end

-- ============================================================
-- Skin Frame
-- ============================================================

local function ApplyBackdrop()
    if not skinFrame then return end
    local s  = UIThingsDB.damageMeter
    local bs = s.borderSize or 2
    skinFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = bs,
        insets = { left = bs, right = bs, top = bs, bottom = bs },
    })
    local bg = s.bgColor
    skinFrame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
    local bc = s.borderColor
    skinFrame:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
end

-- Returns a short display name for a session window's meter type + session type.
local METER_TYPE_NAMES = {
    [0] = "Dmg Out", [1] = "Dmg In", [2] = "Heal Out",
    [3] = "Heal In", [4] = "Deaths", [5] = "Eff Heal",
}
local function GetSessionLabel(win)
    if not win then return "" end
    local typeName = ""
    -- Try to read the TypeName fontstring Blizzard keeps on the dropdown
    if win.DamageMeterTypeDropdown and win.DamageMeterTypeDropdown.TypeName then
        typeName = win.DamageMeterTypeDropdown.TypeName:GetText() or ""
    end
    if typeName == "" then
        typeName = METER_TYPE_NAMES[win.damageMeterType] or ("Type " .. tostring(win.damageMeterType or "?"))
    end
    local sessLabel = (win.sessionType == 0) and "Current" or "Overall"
    return typeName .. " (" .. sessLabel .. ")"
end

local function ApplySessionTitleLabels()
    if not skinFrame then return end
    local s      = UIThingsDB.damageMeter
    local border = s.borderSize or 2
    local wins   = GetSessionWindows()
    local nSess  = math.max(1, #wins)
    local meterW = meterWindow and meterWindow:GetWidth() or 0
    if meterW == 0 then return end
    local slotW  = math.floor(meterW / nSess)

    for i = 1, nSess do
        local sess = sessions[i]
        if not sess then break end
        -- Create label fontstring on first use
        if not sess.titleLabel then
            sess.titleLabel = skinFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            sess.titleLabel:SetTextColor(1, 1, 1, 0.8)
            sess.titleLabel:SetJustifyH("CENTER")
            sess.titleLabel:SetHeight(TITLE_ROW_H)
        end
        local lbl = sess.titleLabel
        lbl:ClearAllPoints()
        local leftOff  = border + slotW * (i - 1)
        local rightOff = -(border + meterW - slotW * i)
        lbl:SetPoint("TOPLEFT",  skinFrame, "TOPLEFT",  leftOff,  -border)
        lbl:SetPoint("TOPRIGHT", skinFrame, "TOPRIGHT", rightOff, -border)
        lbl:SetText(GetSessionLabel(wins[i]))
        lbl:Show()
    end
    -- Hide labels for sessions that no longer exist
    for i = nSess + 1, #sessions do
        if sessions[i] and sessions[i].titleLabel then
            sessions[i].titleLabel:Hide()
        end
    end
end

local function CreateSkinFrame()
    if skinFrame then return end
    skinFrame = CreateFrame("Frame", "LunaUITweaks_MeterSkin", UIParent, "BackdropTemplate")
    skinFrame:SetFrameStrata("LOW")
    skinFrame:SetFrameLevel(1)
    skinFrame:Hide()
end

-- ============================================================
-- Overlay Buttons (per session)
-- ============================================================

local function MakeOverlayBtn(label, parent, yOffset)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(20, 20)
    btn:SetPoint("TOP", parent, "TOP", 0, yOffset)
    btn:SetText(label)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(10)
    local fs = btn:GetFontString()
    if fs then fs:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE") end
    btn._label = btn:GetFontString()
    return btn
end

local function CreateSessionOverlay(idx)
    if sessions[idx] and sessions[idx].overlayFrame then return end
    if not sessions[idx] then sessions[idx] = {} end

    local over = CreateFrame("Frame", "LunaUITweaks_MeterOverlay" .. idx, UIParent)
    over:SetFrameStrata("MEDIUM")
    over:SetFrameLevel(10)
    over:SetSize(20, 66)
    over:Hide()

    sessions[idx].overlayFrame = over
    sessions[idx].btnD  = MakeOverlayBtn("D", over, -2)
    sessions[idx].btnCO = MakeOverlayBtn("O", over, -24)
    sessions[idx].btnS  = MakeOverlayBtn("S", over, -46)
end

-- ============================================================
-- Sync: position skinFrame to wrap all session windows
-- ============================================================

SyncOverlay = function()
    if not skinFrame or not meterWindow then return end

    local wins = GetSessionWindows()
    if #wins == 0 or not wins[1]:IsShown() then
        skinFrame:Hide()
        for _, sess in ipairs(sessions) do
            if sess.overlayFrame then sess.overlayFrame:Hide() end
        end
        return
    end

    local s      = UIThingsDB.damageMeter
    local border = s.borderSize or 2
    local nSess  = #wins

    -- Ensure we have an overlay per session
    for i = 1, nSess do
        CreateSessionOverlay(i)
    end

    -- meterWindow keeps its natural width; divide its content area equally among sessions.
    local meterW = meterWindow:GetWidth()
    local meterH = meterWindow:GetHeight()
    local _, h   = GetSessionSize()   -- h from saved/chat fallback
    if meterW == 0 then return end
    if h == 0 then h = meterH end

    -- Width per session slot (content + strip), dividing the full meter width equally
    local slotW = math.floor(meterW / nSess)
    local sessW = slotW - STRIP_W     -- pure content width per session

    -- skinFrame wraps the meter at its actual position, plus border and title row
    local totalW = meterW + border * 2
    local totalH = meterH + border * 2 + TITLE_ROW_H

    local mx = meterWindow:GetLeft()
    local my = meterWindow:GetBottom()
    if not mx then return end

    local skinCX = mx - border + totalW / 2
    local skinCY = my - border + totalH / 2

    suppressSync = true
    skinFrame:ClearAllPoints()
    skinFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", skinCX, skinCY)
    skinFrame:SetSize(totalW, totalH)
    skinFrame:Show()
    suppressSync = false

    ApplySessionTitleLabels()

    -- Position each session window and its overlay strip inside meterWindow
    if not InCombatLockdown() then
        for i = 1, nSess do
            local win = wins[i]
            win:ClearAllPoints()
            win:SetPoint("TOPLEFT", meterWindow, "TOPLEFT", slotW * (i - 1), 0)
            win:SetSize(sessW, meterH)
        end
    end

    -- Position each overlay strip over the button area of its session slot
    for i = 1, nSess do
        local sess = sessions[i]
        local over = sess and sess.overlayFrame
        if over then
            over:ClearAllPoints()
            over:SetWidth(STRIP_W)
            local slotLeft = border + slotW * (i - 1) + sessW
            over:SetPoint("TOPLEFT",    skinFrame, "TOPLEFT",    slotLeft, -(border + TITLE_ROW_H))
            over:SetPoint("BOTTOMLEFT", skinFrame, "BOTTOMLEFT", slotLeft,   border)
            over:Show()
        end
    end
    -- Hide overlays for sessions that no longer exist
    for i = nSess + 1, #sessions do
        local sess = sessions[i]
        if sess and sess.overlayFrame then sess.overlayFrame:Hide() end
    end

    SyncAllBlizzardButtons()
    UpdateAllSessionLabels()
end

-- ============================================================
-- Blizzard button repositioning (per session)
-- ============================================================

SyncAllBlizzardButtons = function()
    local wins = GetSessionWindows()
    for i, win in ipairs(wins) do
        local sess = sessions[i]
        if sess and sess.overlayFrame and sess.overlayFrame:IsShown() then
            local function PlaceOver(blizzBtn, ourBtn)
                if not blizzBtn or not ourBtn then return end
                if blizzBtn:GetParent() ~= ourBtn:GetParent() then
                    blizzBtn:SetParent(ourBtn:GetParent())
                end
                blizzBtn:ClearAllPoints()
                blizzBtn:SetAllPoints(ourBtn)
                blizzBtn:SetFrameStrata("HIGH")
            end
            PlaceOver(win.DamageMeterTypeDropdown, sess.btnD)
            PlaceOver(win.SessionDropdown,         sess.btnCO)
            PlaceOver(win.SettingsDropdown,        sess.btnS)

            -- Hook session window to refresh button label and title after changes
            if not win._lunaSessionTypeLabelHooked then
                win._lunaSessionTypeLabelHooked = true
                local capturedWin = win
                local capturedIdx = i
                local function RefreshAll()
                    -- Look up sess dynamically so we always get the current titleLabel
                    local s = sessions[capturedIdx]
                    if not s then return end
                    if s.btnCO then
                        s.btnCO:SetText(IsShowingCurrentSession(capturedWin) and "C" or "O")
                    end
                    if s.titleLabel then
                        s.titleLabel:SetText(GetSessionLabel(capturedWin))
                    end
                end
                -- Hook SetSessionType if Blizzard exposes it
                if win.SetSessionType then
                    hooksecurefunc(win, "SetSessionType", function()
                        SafeAfter(0, RefreshAll)
                    end)
                end
                -- Hook DamageMeterTypeDropdown — poll after click since SetText isn't called
                if win.DamageMeterTypeDropdown then
                    win.DamageMeterTypeDropdown:HookScript("OnMouseDown", function()
                        local deadline = GetTime() + 2.0
                        local prev = capturedWin.damageMeterType
                        local watcher = CreateFrame("Frame")
                        watcher:SetScript("OnUpdate", function(self)
                            if GetTime() > deadline then
                                self:SetScript("OnUpdate", nil)
                                return
                            end
                            if capturedWin.damageMeterType ~= prev then
                                self:SetScript("OnUpdate", nil)
                                RefreshAll()
                            end
                        end)
                    end)
                end
                -- Hook SessionDropdown — watch for sessionType change after click
                if win.SessionDropdown then
                    win.SessionDropdown:HookScript("OnMouseDown", function()
                        local deadline = GetTime() + 2.0
                        local prev = capturedWin.sessionType
                        local watcher = CreateFrame("Frame")
                        watcher:SetScript("OnUpdate", function(self)
                            if GetTime() > deadline then
                                self:SetScript("OnUpdate", nil)
                                return
                            end
                            if capturedWin.sessionType ~= prev then
                                self:SetScript("OnUpdate", nil)
                                RefreshAll()
                            end
                        end)
                    end)
                end
            end
        end
    end
end

-- ============================================================
-- Hide original Blizzard chrome
-- ============================================================

local function HideSessionChrome(win)
    if not win then return end
    if win.Background then
        win.Background:SetAlpha(0)
        win.Background:EnableMouse(false)
    end
    if win.Header then
        if not savedHeaderHeight then
            savedHeaderHeight = win.Header:GetHeight()
        end
        win.Header:SetAlpha(0)
        win.Header:EnableMouse(false)
        win.Header:SetHeight(0.001)
    end
    if win.DamageMeterTypeDropdown then win.DamageMeterTypeDropdown:SetAlpha(0) end
    if win.SessionDropdown         then win.SessionDropdown:SetAlpha(0)         end
    if win.SettingsDropdown        then win.SettingsDropdown:SetAlpha(0)        end
end

local function RestoreSessionChrome(win)
    if not win then return end
    if win.Background then
        win.Background:SetAlpha(1)
        win.Background:EnableMouse(true)
    end
    if win.Header then
        win.Header:SetAlpha(1)
        win.Header:EnableMouse(true)
        if savedHeaderHeight then win.Header:SetHeight(savedHeaderHeight) end
    end
    if win.DamageMeterTypeDropdown then
        win.DamageMeterTypeDropdown:SetAlpha(1)
        win.DamageMeterTypeDropdown:EnableMouse(true)
    end
    if win.SessionDropdown then
        win.SessionDropdown:SetAlpha(1)
        win.SessionDropdown:EnableMouse(true)
    end
    if win.SettingsDropdown then
        win.SettingsDropdown:SetAlpha(1)
        win.SettingsDropdown:EnableMouse(true)
    end
end

local function HideAllChrome()
    local wins = GetSessionWindows()
    for _, win in ipairs(wins) do
        HideSessionChrome(win)
    end
end

-- ============================================================
-- Hook Setup
-- ============================================================

local function SetupHooks()
    if hooksInstalled then return end
    if not meterWindow then return end
    hooksInstalled = true

    hooksecurefunc(meterWindow, "SetPoint", function()
        if not suppressSync and UIThingsDB.damageMeter and UIThingsDB.damageMeter.enabled then
            SafeAfter(0, SyncOverlay)
        end
    end)

    hooksecurefunc(meterWindow, "Show", function()
        if UIThingsDB.damageMeter and UIThingsDB.damageMeter.enabled then
            SafeAfter(0, SyncOverlay)
        end
    end)

    meterWindow:HookScript("OnHide", function()
        if skinFrame then skinFrame:Hide() end
    end)

    meterWindow:HookScript("OnSizeChanged", function()
        if UIThingsDB.damageMeter and UIThingsDB.damageMeter.enabled then
            SafeAfter(0, SyncOverlay)
        end
    end)

    -- Hook each session window for show/hide/resize/move
    local function HookSession(win)
        if not win or win._lunaHooked then return end
        win._lunaHooked = true
        hooksecurefunc(win, "Show", function()
            if UIThingsDB.damageMeter and UIThingsDB.damageMeter.enabled then
                SafeAfter(0, SyncOverlay)
            end
        end)
        win:HookScript("OnHide", function()
            SafeAfter(0, SyncOverlay)
        end)
        win:HookScript("OnSizeChanged", function()
            if UIThingsDB.damageMeter and UIThingsDB.damageMeter.enabled then
                SafeAfter(0, SyncOverlay)
            end
        end)
    end

    local wins = GetSessionWindows()
    for _, win in ipairs(wins) do HookSession(win) end

    -- Scan for created/removed session windows and hook/skin/restore them
    local lastKnownCount = #wins
    local function ScanForNewSessions()
        if not (UIThingsDB.damageMeter and UIThingsDB.damageMeter.enabled) then return end
        local newWins = GetSessionWindows()
        local newCount = #newWins
        if newCount ~= lastKnownCount then
            -- Restore chrome on any numbered windows that are now hidden
            local i = 1
            while true do
                local w = _G["DamageMeterSessionWindow" .. i]
                if not w then break end
                if not w:IsShown() then RestoreSessionChrome(w) end
                i = i + 1
            end
            lastKnownCount = newCount
            for _, win in ipairs(newWins) do
                HookSession(win)
                HideSessionChrome(win)
            end
            SafeAfter(0,   SyncOverlay)
            -- Re-sync after Blizzard has fully initialised the new window's fields
            SafeAfter(0.3, SyncOverlay)
            SafeAfter(0.8, SyncOverlay)
        end
    end

    -- Also hook meterWindow:Show for the original polling path
    hooksecurefunc(meterWindow, "Show", function()
        ScanForNewSessions()
    end)

    -- Poll on OnSizeChanged too — meterWindow resizes when sessions are added/removed
    meterWindow:HookScript("OnSizeChanged", function()
        ScanForNewSessions()
    end)

    -- OnUpdate ticker: cheaply watch for new/removed session windows every 0.5s
    local ticker = 0
    meterWindow:HookScript("OnUpdate", function(_, elapsed)
        ticker = ticker + elapsed
        if ticker < 0.5 then return end
        ticker = 0
        ScanForNewSessions()
    end)

    local chatSkinFrame = _G["LunaChatSkinContainer"]
    if chatSkinFrame then
        chatSkinFrame:HookScript("OnSizeChanged", function()
            if UIThingsDB.damageMeter and UIThingsDB.damageMeter.enabled then
                SafeAfter(0, SyncOverlay)
            end
        end)
    end

    -- Re-skin when a floating chat frame is created or destroyed
    local function OnChatFrameChange()
        if UIThingsDB.damageMeter and UIThingsDB.damageMeter.enabled then
            SafeAfter(0.2, function()
                addonTable.DamageMeter.Initialize()
            end)
        end
    end
    if FCF_OpenNewWindow then
        hooksecurefunc("FCF_OpenNewWindow", OnChatFrameChange)
    end
    if FCF_Close then
        hooksecurefunc("FCF_Close", OnChatFrameChange)
    end
end

-- ============================================================
-- Apply / Initialize / Update
-- ============================================================

ApplyPositionAndSize = function()
    if not meterWindow then return end
    if InCombatLockdown() then return end
    local s = UIThingsDB.damageMeter
    local w = s.width  or 0
    local h = s.height or 0
    local x = s.pos and s.pos.x or 0
    local y = s.pos and s.pos.y or 0
    if w > 0 and h > 0 then meterWindow:SetSize(w, h) end
    meterWindow:ClearAllPoints()
    meterWindow:SetPoint("CENTER", UIParent, "CENTER", x, y)
    SafeAfter(0, SyncOverlay)
end

function addonTable.DamageMeter.ApplyPositionAndSize()
    ApplyPositionAndSize()
end

local function ApplySettings()
    if not skinFrame then return end
    skinFrame:SetFrameStrata(UIThingsDB.damageMeter.frameStrata or "LOW")
    ApplyBackdrop()
    ApplyLock()
    SafeAfter(0, SyncOverlay)
end

function addonTable.DamageMeter.Initialize()
    CreateSkinFrame()
    meterWindow = GetMeterWindow()

    -- Pre-create overlay for session 1
    CreateSessionOverlay(1)

    if not UIThingsDB.damageMeter.enabled then
        if skinFrame then skinFrame:Hide() end
        for _, sess in ipairs(sessions) do
            if sess.overlayFrame then sess.overlayFrame:Hide() end
        end
        return
    end

    if meterWindow then
        SetupHooks()
        HideAllChrome()
        ApplyPositionAndSize()
        ApplySettings()
    end
end

function addonTable.DamageMeter.UpdateSettings()
    if not skinFrame then return end

    if UIThingsDB.damageMeter.enabled then
        if not meterWindow then
            meterWindow = GetMeterWindow()
            if meterWindow then
                SetupHooks()
                HideAllChrome()
            end
        end
        ApplySettings()
    else
        skinFrame:Hide()
        for _, sess in ipairs(sessions) do
            if sess.overlayFrame then sess.overlayFrame:Hide() end
        end
        local wins = GetSessionWindows()
        for _, win in ipairs(wins) do RestoreSessionChrome(win) end
    end
end

function addonTable.DamageMeter.GetDetectedAddon()
    if C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable
            and C_DamageMeter.IsDamageMeterAvailable() then
        return "Blizzard (Built-in)"
    end
    return nil
end

function addonTable.DamageMeter.GetMeterFrame()
    return meterWindow
end

-- ============================================================
-- Events
-- ============================================================


EventBus.Register("PLAYER_ENTERING_WORLD", function()
    if not UIThingsDB or not UIThingsDB.damageMeter then return end
    SafeAfter(1, function()
        addonTable.DamageMeter.Initialize()
    end)
end, "DamageMeter")

-- sessionType=0 means current live session, sessionType=1 means a past/named session.
IsShowingCurrentSession = function(win)
    if not win then return true end
    return (win.sessionType or 0) ~= 0
end

UpdateAllSessionLabels = function()
    -- Ensure title label fontstrings exist and are positioned correctly
    ApplySessionTitleLabels()
    local wins = GetSessionWindows()
    for i, win in ipairs(wins) do
        local sess = sessions[i]
        if sess then
            if sess.btnCO then
                sess.btnCO:SetText(IsShowingCurrentSession(win) and "C" or "O")
            end
            if sess.titleLabel then
                sess.titleLabel:SetText(GetSessionLabel(win))
            end
        end
    end
end

EventBus.Register("DAMAGE_METER_CURRENT_SESSION_UPDATED", function()
    if UIThingsDB.damageMeter and UIThingsDB.damageMeter.enabled and skinFrame then
        -- New session windows may have been created; hook and skin any we haven't seen yet
        if meterWindow then
            local newWins = GetSessionWindows()
            for _, win in ipairs(newWins) do
                if not win._lunaHooked then
                    win._lunaHooked = true
                    win:HookScript("OnHide", function() SafeAfter(0, SyncOverlay) end)
                end
                HideSessionChrome(win)
            end
        end
        SafeAfter(0, SyncOverlay)
        SafeAfter(0.3, UpdateAllSessionLabels)
    end
end, "DamageMeter")

EventBus.Register("DAMAGE_METER_COMBAT_SESSION_UPDATED", function()
    if UIThingsDB.damageMeter and UIThingsDB.damageMeter.enabled and skinFrame then
        SafeAfter(0.3, UpdateAllSessionLabels)
    end
end, "DamageMeter")

EventBus.Register("PLAYER_REGEN_ENABLED", function()
    if UIThingsDB.damageMeter and UIThingsDB.damageMeter.enabled and meterWindow then
        SafeAfter(0, SyncOverlay)
    end
end, "DamageMeter")
