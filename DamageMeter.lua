local addonName, addonTable = ...
addonTable.DamageMeter = {}

local EventBus = addonTable.EventBus
local SafeAfter = addonTable.Core.SafeAfter

-- ============================================================
-- Module State
-- ============================================================

local skinFrame     -- BackdropTemplate frame sitting behind the meter
local titleBar      -- title bar strip above the meter
local titleText     -- FontString in the title bar
local meterWindow   -- DamageMeter (parent of DamageMeterSessionWindow1)
local btnD          -- replacement D button (damage type)
local btnCO         -- replacement C/O button (current/overall session)
local btnS          -- replacement S button (settings)
local overlayFrame  -- parent for our replacement buttons (MEDIUM strata)

local suppressSync   = false
local hooksInstalled = false
local dragInstalled  = false

local SyncOverlay  -- forward declaration (defined after CreateOverlayButtons)

-- ============================================================
-- Core Logic
-- ============================================================

local function GetMeterWindow()
    -- DamageMeterSessionWindow1 is the session child; its parent "DamageMeter"
    -- is the actual visible container frame we want to skin.
    local session = _G["DamageMeterSessionWindow1"]
    if session then
        local par = session:GetParent()
        if par and par:GetName() == "DamageMeter" then
            return par
        end
    end
    return session
end

-- Enable or disable dragging of meterWindow.
local function ApplyLock()
    if not meterWindow then return end
    if UIThingsDB.damageMeter.locked then
        meterWindow:SetMovable(false)
        meterWindow:EnableMouse(false)
    else
        meterWindow:SetMovable(true)
        meterWindow:EnableMouse(true)
        if not dragInstalled then
            dragInstalled = true
            meterWindow:SetScript("OnMouseDown", function(self, btn)
                if btn == "LeftButton" and not UIThingsDB.damageMeter.locked then
                    self:StartMoving()
                end
            end)
            meterWindow:SetScript("OnMouseUp", function(self)
                self:StopMovingOrSizing()
                SafeAfter(0, SyncSkin)
            end)
        end
    end
end

-- Mirror the meter's position across the centre of UIParent (same Y, reflected X).
local function ReflectChat()
    if not meterWindow then return end
    if InCombatLockdown() then return end
    local chat = _G["LunaChatSkinContainer"]
    if not chat then return end

    -- Get chat position in UIParent coordinates
    local cx = chat:GetLeft()
    local cy = chat:GetBottom()
    if not cx then return end

    local screenW = UIParent:GetWidth()
    local mw = (_G["LunaChatSkinContainer"] and _G["LunaChatSkinContainer"]:GetWidth()) or meterWindow:GetWidth()

    -- Reflect: place so the meter's right edge mirrors the chat's left edge
    local reflectedX = screenW - cx - mw

    meterWindow:ClearAllPoints()
    meterWindow:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", reflectedX, cy)
    SafeAfter(0, SyncSkin)
end

function addonTable.DamageMeter.SetLocked(locked)
    UIThingsDB.damageMeter.locked = locked
    ApplyLock()
end

function addonTable.DamageMeter.ReflectChat()
    ReflectChat()
end

-- Attempt to resize the DamageMeter frame to match LunaChatSkinContainer (the drawn chat frame).
-- Guarded by InCombatLockdown since SetSize is blocked on protected frames.
local function ForceMeterSize()
    if not meterWindow then return end
    if InCombatLockdown() then return end
    local cf = _G["LunaChatSkinContainer"]
    if not cf then return end
    local cw = cf:GetWidth()
    local ch = cf:GetHeight()
    if not cw or cw == 0 then return end
    meterWindow:SetSize(cw, ch)
end

-- Snap skinFrame to sit behind the meter at LunaChatSkinContainer's size.
-- We use that frame's dimensions directly so the skin is correct even
-- if SetSize on the Blizzard frame is ignored.
local function SyncSkin()
    if suppressSync then return end
    if not skinFrame or not meterWindow then return end
    if not meterWindow:IsShown() then
        skinFrame:Hide()
        return
    end

    -- Try to resize the meter to match the chat skin container
    ForceMeterSize()

    local s      = UIThingsDB.damageMeter
    local titleH = (s.titleBar and (s.titleBarHeight or 20)) or 0
    local border = s.borderSize or 2

    -- Use LunaChatSkinContainer as the authoritative size source
    local cf = _G["LunaChatSkinContainer"]
    local w  = (cf and cf:GetWidth()  ~= 0 and cf:GetWidth())  or meterWindow:GetWidth()
    local h  = (cf and cf:GetHeight() ~= 0 and cf:GetHeight()) or meterWindow:GetHeight()
    -- Position comes from where the meter actually is
    local x  = meterWindow:GetLeft()
    local y  = meterWindow:GetBottom()

    if not x or w == 0 then return end

    suppressSync = true
    skinFrame:ClearAllPoints()
    skinFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x - border, y - border)
    skinFrame:SetSize(w + border * 2, h + titleH + border * 2)
    skinFrame:Show()
    suppressSync = false

    SyncOverlay()
end

-- ============================================================
-- Visual Helpers
-- ============================================================

local function ApplyBackdrop()
    local s = UIThingsDB.damageMeter
    skinFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile     = false,
        tileSize = 0,
        edgeSize = s.borderSize or 2,
        insets   = {
            left   = s.borderSize or 2,
            right  = s.borderSize or 2,
            top    = s.borderSize or 2,
            bottom = s.borderSize or 2,
        },
    })
    local bg = s.bgColor
    skinFrame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
    local bc = s.borderColor
    skinFrame:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
end

local function ApplyTitleBar()
    local s = UIThingsDB.damageMeter
    if s.titleBar then
        local h = s.titleBarHeight or 20
        local b = s.borderSize or 2
        titleBar:ClearAllPoints()
        titleBar:SetPoint("TOPLEFT",  skinFrame, "TOPLEFT",   b, -b)
        titleBar:SetPoint("TOPRIGHT", skinFrame, "TOPRIGHT", -b, -b)
        titleBar:SetHeight(h)
        local tc = s.titleBarColor
        titleBar:SetBackdropColor(tc.r, tc.g, tc.b, tc.a)
        titleText:SetText(s.titleText or "Damage Meter")
        titleBar:Show()
    else
        titleBar:Hide()
    end
end

local function CreateSkinFrame()
    if skinFrame then return end

    skinFrame = CreateFrame("Frame", "LunaUITweaks_MeterSkin", UIParent, "BackdropTemplate")
    skinFrame:SetFrameStrata("LOW")
    skinFrame:SetFrameLevel(1)
    skinFrame:Hide()

    titleBar = CreateFrame("Frame", nil, skinFrame, "BackdropTemplate")
    titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    titleBar:SetFrameLevel(2)
    titleBar:Hide()

    titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleText:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
    titleText:SetTextColor(1, 1, 1)
end

-- ============================================================
-- Overlay Buttons (D / C-O / S)
-- ============================================================

local function MakeOverlayBtn(label, parent, yOffset, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(18, 18)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, yOffset)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)

    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetAllPoints()
    fs:SetJustifyH("CENTER")
    fs:SetText(label)
    btn._label = fs

    btn:SetScript("OnClick", onClick)
    btn:SetScript("OnEnter", function(self)
        bg:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    end)
    btn:SetScript("OnLeave", function(self)
        bg:SetColorTexture(0, 0, 0, 0.6)
    end)
    return btn
end

local function CreateOverlayButtons()
    if overlayFrame then return end

    overlayFrame = CreateFrame("Frame", "LunaUITweaks_MeterOverlay", UIParent)
    overlayFrame:SetFrameStrata("MEDIUM")
    overlayFrame:SetFrameLevel(10)
    overlayFrame:SetSize(26, 62)
    overlayFrame:Hide()

    -- Helper: fire a frame's OnMouseDown/OnClick handler, trying Button:Click() first,
    -- then OnMouseDown script, to handle both Button and plain Frame cases.
    local function FireFrame(f)
        if not f then return end
        if f.Click then
            f:Click()
        else
            local fn = f:GetScript("OnMouseDown")
            if fn then fn(f, "LeftButton") end
        end
    end

    -- D button: opens the damage type dropdown via its Arrow child button
    btnD = MakeOverlayBtn("D", overlayFrame, -2, function()
        local session = _G["DamageMeterSessionWindow1"]
        if not session then return end
        local dd = session.DamageMeterTypeDropdown
        if dd then
            -- Arrow is the actual Button child that opens the dropdown
            local arrow = dd.Arrow
            if arrow then
                FireFrame(arrow)
            else
                FireFrame(dd)
            end
        end
    end)

    -- C/O button: fires the SessionDropdown's handler to open the session picker
    btnCO = MakeOverlayBtn("C", overlayFrame, -22, function(self)
        local session = _G["DamageMeterSessionWindow1"]
        if session then
            FireFrame(session.SessionDropdown)
        end
        -- Toggle label optimistically; actual state determined by which session is shown
        local cur = self._label:GetText()
        self._label:SetText(cur == "C" and "O" or "C")
    end)

    -- S button: fires the SettingsDropdown's handler to open settings
    btnS = MakeOverlayBtn("S", overlayFrame, -42, function()
        local session = _G["DamageMeterSessionWindow1"]
        if session then
            FireFrame(session.SettingsDropdown)
        end
    end)
end

-- Position the overlay frame flush with the left edge of the meter's header area.
SyncOverlay = function()
    if not overlayFrame or not meterWindow then return end
    if not meterWindow:IsShown() then
        overlayFrame:Hide()
        return
    end

    local session = _G["DamageMeterSessionWindow1"]
    local header  = session and session.Header
    if not header then return end

    local hLeft   = header:GetLeft()
    local hTop    = header:GetTop()
    if not hLeft then return end

    overlayFrame:ClearAllPoints()
    overlayFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", hLeft, hTop)
    overlayFrame:Show()
end

-- Hide the three original Blizzard buttons we are replacing.
local function HideOriginalButtons()
    local session = _G["DamageMeterSessionWindow1"]
    if not session then return end

    -- DamageMeterTypeDropdown (D)
    local dd = session.DamageMeterTypeDropdown
    if dd then
        dd:SetAlpha(0)
        dd:EnableMouse(false)
    end

    -- SessionDropdown (C/O)
    local sd2 = session.SessionDropdown
    if sd2 then
        sd2:SetAlpha(0)
        sd2:EnableMouse(false)
    end

    -- SettingsDropdown icon button (top-right of header, becomes S)
    local sd = session.SettingsDropdown
    if sd then
        sd:SetAlpha(0)
        sd:EnableMouse(false)
    end
end

-- ============================================================
-- Hook Setup
-- ============================================================

local function SetupHooks()
    if hooksInstalled then return end
    if not meterWindow then return end
    hooksInstalled = true

    -- Parent frame moves → re-sync skin
    hooksecurefunc(meterWindow, "SetPoint", function()
        if not suppressSync and UIThingsDB.damageMeter and UIThingsDB.damageMeter.enabled then
            SafeAfter(0, SyncSkin)
        end
    end)

    -- Parent frame shows → re-sync skin
    hooksecurefunc(meterWindow, "Show", function()
        if UIThingsDB.damageMeter and UIThingsDB.damageMeter.enabled then
            SafeAfter(0, SyncSkin)
        end
    end)

    -- Parent frame hides → hide skin
    meterWindow:HookScript("OnHide", function()
        if skinFrame then skinFrame:Hide() end
    end)

    -- Parent frame resized → re-sync skin
    meterWindow:HookScript("OnSizeChanged", function()
        if UIThingsDB.damageMeter and UIThingsDB.damageMeter.enabled then
            SafeAfter(0, SyncSkin)
        end
    end)

    -- Session window show/hide also controls visibility
    local session = _G["DamageMeterSessionWindow1"]
    if session and session ~= meterWindow then
        hooksecurefunc(session, "Show", function()
            if UIThingsDB.damageMeter and UIThingsDB.damageMeter.enabled then
                SafeAfter(0, SyncSkin)
            end
        end)
        session:HookScript("OnHide", function()
            if skinFrame then skinFrame:Hide() end
        end)
    end

    -- LunaChatSkinContainer resized → re-sync so skin stays at correct size
    local chatSkinFrame = _G["LunaChatSkinContainer"]
    if chatSkinFrame then
        chatSkinFrame:HookScript("OnSizeChanged", function()
            if UIThingsDB.damageMeter and UIThingsDB.damageMeter.enabled then
                SafeAfter(0, SyncSkin)
            end
        end)
    end
end

-- ============================================================
-- Apply / Initialize / Update
-- ============================================================

local function ApplySettings()
    if not skinFrame then return end
    skinFrame:SetFrameStrata(UIThingsDB.damageMeter.frameStrata or "LOW")
    ApplyBackdrop()
    ApplyTitleBar()
    ApplyLock()
    SyncSkin()
end

function addonTable.DamageMeter.Initialize()
    CreateSkinFrame()
    CreateOverlayButtons()
    meterWindow = GetMeterWindow()

    if not UIThingsDB.damageMeter.enabled then
        if skinFrame then skinFrame:Hide() end
        if overlayFrame then overlayFrame:Hide() end
        return
    end

    if meterWindow then
        SetupHooks()
        HideOriginalButtons()
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
                HideOriginalButtons()
            end
        end
        ApplySettings()
    else
        skinFrame:Hide()
        if overlayFrame then overlayFrame:Hide() end
        -- Restore original buttons
        local session = _G["DamageMeterSessionWindow1"]
        if session then
            if session.DamageMeterTypeDropdown then
                session.DamageMeterTypeDropdown:SetAlpha(1)
                session.DamageMeterTypeDropdown:EnableMouse(true)
            end
            if session.SessionDropdown then
                session.SessionDropdown:SetAlpha(1)
                session.SessionDropdown:EnableMouse(true)
            end
            if session.SettingsDropdown then
                session.SettingsDropdown:SetAlpha(1)
                session.SettingsDropdown:EnableMouse(true)
            end
        end
    end
end

function addonTable.DamageMeter.GetDetectedAddon()
    if C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable
            and C_DamageMeter.IsDamageMeterAvailable() then
        return "Blizzard (Built-in)"
    end
    return nil
end

-- ============================================================
-- Events
-- ============================================================

EventBus.Register("PLAYER_ENTERING_WORLD", function()
    if not UIThingsDB or not UIThingsDB.damageMeter then return end
    SafeAfter(1, function()
        addonTable.DamageMeter.Initialize()
    end)
end)

EventBus.Register("DAMAGE_METER_CURRENT_SESSION_UPDATED", function()
    if UIThingsDB.damageMeter and UIThingsDB.damageMeter.enabled and skinFrame then
        SafeAfter(0, SyncSkin)
    end
end)

-- After combat: re-apply size that was blocked by InCombatLockdown
EventBus.Register("PLAYER_REGEN_ENABLED", function()
    if UIThingsDB.damageMeter and UIThingsDB.damageMeter.enabled and meterWindow then
        SafeAfter(0, SyncSkin)
    end
end)
