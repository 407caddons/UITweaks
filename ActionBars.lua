local addonName, addonTable = ...

local ActionBars = {}
addonTable.ActionBars = ActionBars

-- Check for conflicting action bar addons — cached after first call
local conflictAddonChecked = false
local conflictAddonFound = false
local function HasConflictAddon()
    if not conflictAddonChecked then
        conflictAddonChecked = true
        if C_AddOns.IsAddOnLoaded("Dominos")
            or C_AddOns.IsAddOnLoaded("Bartender4")
            or C_AddOns.IsAddOnLoaded("ElvUI") then
            conflictAddonFound = true
        end
    end
    return conflictAddonFound
end

-- Known micro menu button names (WoW 12.0)
-- Filter at runtime to only those that exist
local MICRO_BUTTON_NAMES = {
    "CharacterMicroButton",
    "ProfessionMicroButton",
    "PlayerSpellsMicroButton",
    "AchievementMicroButton",
    "QuestLogMicroButton",
    "LFDMicroButton",
    "CollectionsMicroButton",
    "EJMicroButton",
    "StoreMicroButton",
    "MainMenuMicroButton",
    "GuildMicroButton",
    "HousingMicroButton",
    "HomeMicroButton",
    "HousingDashboardMicroButton",
}

-- Friendly display names for action bars
local BAR_DISPLAY_NAMES = {
    MainActionBar = "Action Bar 1",
    MultiBarBottomLeft = "Bar: Bottom Left",
    MultiBarBottomRight = "Bar: Bottom Right",
    MultiBarRight = "Bar: Right",
    MultiBarLeft = "Bar: Left 2",
    MultiBar5 = "Bar 5",
    MultiBar6 = "Bar 6",
    MultiBar7 = "Bar 7",
}
ActionBars.BAR_DISPLAY_NAMES = BAR_DISPLAY_NAMES

local drawerFrame = nil
local drawerToggleBtn = nil
local drawerCollapsed = false
local collectedButtons = {} -- { button, origParent, origPoints, origWidth, origHeight }
local collectedSet = {}     -- [button] = true, for fast lookup
local drawerHooked = false
local inEditMode = false

-- Forward declarations for functions/tables defined later but referenced from hooks
local RestoreBarPositions
local RestoreButtonSpacing
local blizzardDefaultPositions = {}                            -- [barName] = { point, relTo, relPoint, x, y } captured before our overrides
local originalButtonPositions = {}                             -- saved original button positions for restore
ActionBars.blizzardDefaultPositions = blizzardDefaultPositions -- exposed for config panel

local TOGGLE_BTN_WIDTH = 16

-- Safely re-parent a micro button without triggering MicroMenuContainer:Layout() crash.
-- The crash happens because SetParent fires OnHide on the button, which triggers
-- Blizzard's handler at MainMenuBarMicroButtons.lua:476 that calls Layout().
-- We temporarily strip the OnHide script during SetParent to prevent this.
local function SafeSetParent(btn, newParent)
    local origOnHide = btn:GetScript("OnHide")
    btn:SetScript("OnHide", nil)
    btn:SetParent(newParent)
    if origOnHide then
        btn:SetScript("OnHide", origOnHide)
    end
end

-- Permanently make MicroMenuContainer safe when buttons are reparented to our drawer.
-- Blizzard's Layout() calls GetEdgeButton() which crashes with "compare two nil values"
-- when buttons aren't children of the container. We patch both:
-- 1. GetEdgeButton — return the container itself as a safe fallback (has GetPoint/GetWidth)
-- 2. Layout — wrap in pcall as a safety net for any other internal errors
local microMenuPatched = false
local function PatchMicroMenuLayout()
    if microMenuPatched then return end
    local container = MicroMenuContainer
    if not container then return end

    -- Patch GetEdgeButton to return the container as a safe fallback instead of nil.
    -- This prevents the "compare two nil values" crash in Layout/UpdateHelpTicketButtonAnchor.
    -- We patch on the instance AND the metatable __index to ensure all call paths are covered.
    local function SafeGetEdgeButton(origFunc)
        return function(self, ...)
            local ok, result = pcall(origFunc, self, ...)
            if ok and result then return result end
            return self -- safe fallback: container has GetPoint/GetWidth methods
        end
    end

    -- Patch on instance
    local instanceGetEdge = rawget(container, "GetEdgeButton")
    if instanceGetEdge then
        rawset(container, "GetEdgeButton", SafeGetEdgeButton(instanceGetEdge))
    end

    -- Patch on metatable __index
    local mt = getmetatable(container)
    local idx = mt and rawget(mt, "__index")
    if type(idx) == "table" then
        local mtGetEdge = rawget(idx, "GetEdgeButton")
        if mtGetEdge and mtGetEdge ~= instanceGetEdge then
            rawset(idx, "GetEdgeButton", SafeGetEdgeButton(mtGetEdge))
        end
    end

    -- Final fallback: if resolved but not found on either, patch the instance
    if not instanceGetEdge and container.GetEdgeButton then
        local resolved = container.GetEdgeButton
        container.GetEdgeButton = SafeGetEdgeButton(resolved)
    end

    -- Wrap Layout in pcall as a safety net for any remaining errors
    local orig = rawget(container, "Layout")
    if orig then
        rawset(container, "Layout", function(self, ...)
            local ok, err = pcall(orig, self, ...)
        end)
        microMenuPatched = true
        return
    end

    mt = getmetatable(container)
    idx = mt and rawget(mt, "__index")
    if type(idx) == "table" then
        orig = rawget(idx, "Layout")
        if orig then
            rawset(idx, "Layout", function(self, ...)
                local ok, err = pcall(orig, self, ...)
            end)
            microMenuPatched = true
            return
        end
    end

    if container.Layout then
        local resolved = container.Layout
        container.Layout = function(self, ...)
            local ok, err = pcall(resolved, self, ...)
        end
        microMenuPatched = true
    end
end

-- No-op wrapper kept for compatibility with existing call sites
local function SuppressMicroLayout(func)
    func()
end

-- == Border Helpers (same pattern as MinimapCustom) ==

local function EnsureBorderTextures(frame)
    if not frame.borderLines then
        frame.borderLines = {
            top = frame:CreateTexture(nil, "OVERLAY"),
            bottom = frame:CreateTexture(nil, "OVERLAY"),
            left = frame:CreateTexture(nil, "OVERLAY"),
            right = frame:CreateTexture(nil, "OVERLAY"),
        }
        for _, tex in pairs(frame.borderLines) do
            tex:SetColorTexture(1, 1, 1, 1)
        end
    end
    return frame.borderLines
end

local function ApplyThreeSidedBorder(frame, borderSize, bc, skipSide)
    local lines = EnsureBorderTextures(frame)

    if borderSize <= 0 then
        for _, tex in pairs(lines) do tex:Hide() end
        return
    end

    lines.top:ClearAllPoints()
    lines.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    lines.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    lines.top:SetHeight(borderSize)
    lines.top:SetColorTexture(bc.r, bc.g, bc.b, bc.a or 1)
    lines.top:Show()

    lines.bottom:ClearAllPoints()
    lines.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    lines.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    lines.bottom:SetHeight(borderSize)
    lines.bottom:SetColorTexture(bc.r, bc.g, bc.b, bc.a or 1)
    lines.bottom:Show()

    if skipSide == "LEFT" then
        lines.left:Hide()
    else
        lines.left:ClearAllPoints()
        lines.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        lines.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        lines.left:SetWidth(borderSize)
        lines.left:SetColorTexture(bc.r, bc.g, bc.b, bc.a or 1)
        lines.left:Show()
    end

    if skipSide == "RIGHT" then
        lines.right:Hide()
    else
        lines.right:ClearAllPoints()
        lines.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        lines.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        lines.right:SetWidth(borderSize)
        lines.right:SetColorTexture(bc.r, bc.g, bc.b, bc.a or 1)
        lines.right:Show()
    end
end

-- == Position Helpers ==

local function IsDrawerOnRightSide()
    if not drawerFrame then return true end
    local cx = drawerFrame:GetCenter()
    if not cx then return true end
    return cx > (UIParent:GetWidth() / 2)
end

-- == Visual Updates ==

local function UpdateToggleBtnColor()
    if not drawerToggleBtn then return end
    local settings = UIThingsDB.actionBars
    local bg = settings.bgColor or { r = 0, g = 0, b = 0, a = 0.7 }
    local bc = settings.borderColor or { r = 0.3, g = 0.3, b = 0.3, a = 1 }
    local borderSize = settings.borderSize or 2

    drawerToggleBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    drawerToggleBtn:SetBackdropColor(bg.r, bg.g, bg.b, bg.a or 0.7)

    local onRight = IsDrawerOnRightSide()
    local skipSide = onRight and "RIGHT" or "LEFT"
    ApplyThreeSidedBorder(drawerToggleBtn, borderSize, bc, skipSide)
end

local function ApplyDrawerLockVisuals()
    if not drawerFrame then return end
    local settings = UIThingsDB.actionBars
    local borderSize = settings.borderSize or 2
    local bc = settings.borderColor or { r = 0.3, g = 0.3, b = 0.3, a = 1 }
    local bg = settings.bgColor or { r = 0, g = 0, b = 0, a = 0.7 }

    if settings.locked then
        drawerFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        drawerFrame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a or 0.7)

        local onRight = IsDrawerOnRightSide()
        local skipSide = onRight and "LEFT" or "RIGHT"
        ApplyThreeSidedBorder(drawerFrame, borderSize, bc, skipSide)
    else
        drawerFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        drawerFrame:SetBackdropColor(0, 0, 0, 0.7)
        drawerFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

        if drawerFrame.borderLines then
            for _, tex in pairs(drawerFrame.borderLines) do tex:Hide() end
        end
    end

    UpdateToggleBtnColor()
end

-- == Toggle Button ==

local function UpdateToggleButton()
    if not drawerToggleBtn or not drawerFrame then return end
    local onRight = IsDrawerOnRightSide()
    local frameH = drawerFrame:GetHeight()

    drawerToggleBtn:SetSize(TOGGLE_BTN_WIDTH, frameH)
    drawerToggleBtn:ClearAllPoints()

    if onRight then
        drawerToggleBtn:SetPoint("TOPRIGHT", drawerFrame, "TOPLEFT", 0, 0)
        drawerToggleBtn.text:SetText(drawerCollapsed and "<" or ">")
    else
        drawerToggleBtn:SetPoint("TOPLEFT", drawerFrame, "TOPRIGHT", 0, 0)
        drawerToggleBtn.text:SetText(drawerCollapsed and ">" or "<")
    end
end

-- == Layout ==

local function CalculateFrameSize(count)
    local settings = UIThingsDB.actionBars
    local btnSize = settings.buttonSize or 32
    local padding = settings.padding or 4

    local numCols = math.ceil(count / 2)
    local numRows = math.min(count, 2)
    local frameW = (numCols * btnSize) + ((numCols + 1) * padding)
    local frameH = (numRows * btnSize) + ((numRows + 1) * padding)
    return frameW, frameH, numCols
end

local function LayoutButtons()
    if not drawerFrame then return end
    local settings = UIThingsDB.actionBars
    local btnSize = settings.buttonSize or 32
    local padding = settings.padding or 4

    local count = #collectedButtons
    if count == 0 then
        drawerFrame:SetSize(1, 1)
        drawerFrame:Hide()
        if drawerToggleBtn then drawerToggleBtn:Hide() end
        return
    end

    local frameW, frameH, numCols = CalculateFrameSize(count)
    drawerFrame:SetSize(frameW, frameH)

    for i, entry in ipairs(collectedButtons) do
        local btn = entry.button
        local col = (i - 1) % numCols
        local row = math.floor((i - 1) / numCols)
        local x = padding + (col * (btnSize + padding))
        local y = -(padding + (row * (btnSize + padding)))

        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", drawerFrame, "TOPLEFT", x, y)
        btn:SetSize(btnSize, btnSize)
        SafeSetParent(btn, drawerFrame)
        btn:SetFrameStrata("MEDIUM")
        btn:SetFrameLevel(drawerFrame:GetFrameLevel() + 5)

        -- Use alpha instead of Hide/Show to avoid triggering Blizzard MicroMenuContainer:Layout()
        if drawerCollapsed then
            btn:SetAlpha(0)
            btn:EnableMouse(false)
        else
            btn:SetAlpha(1)
            btn:EnableMouse(true)
        end
    end

    drawerFrame:Show()

    if drawerCollapsed then
        drawerFrame:SetSize(1, frameH)
        drawerFrame:SetBackdrop(nil)
    end

    UpdateToggleButton()
    if drawerToggleBtn then drawerToggleBtn:Show() end

    if not drawerCollapsed then
        ApplyDrawerLockVisuals()
    end
end

-- == Collapse / Expand ==

local function SetDrawerCollapsed(collapsed)
    if inEditMode then return end
    drawerCollapsed = collapsed

    for _, entry in ipairs(collectedButtons) do
        if collapsed then
            entry.button:SetAlpha(0)
            entry.button:EnableMouse(false)
        else
            entry.button:SetAlpha(1)
            entry.button:EnableMouse(true)
        end
    end

    if drawerFrame then
        if collapsed then
            drawerFrame:SetSize(1, drawerFrame:GetHeight())
            drawerFrame:SetBackdrop(nil)
        else
            local count = #collectedButtons
            if count > 0 then
                local frameW, frameH = CalculateFrameSize(count)
                drawerFrame:SetSize(frameW, frameH)
            end
            ApplyDrawerLockVisuals()
        end
    end

    UpdateToggleButton()
end

-- == Button Collection ==

local function CollectMicroButtons()
    wipe(collectedButtons)
    wipe(collectedSet)

    for _, name in ipairs(MICRO_BUTTON_NAMES) do
        local btn = _G[name]
        if btn and btn.GetParent then
            local origParent = btn:GetParent()
            local origPoints = {}
            for p = 1, btn:GetNumPoints() do
                origPoints[p] = { btn:GetPoint(p) }
            end
            local origW, origH = btn:GetSize()

            table.insert(collectedButtons, {
                button = btn,
                origParent = origParent,
                origPoints = origPoints,
                origWidth = origW,
                origHeight = origH,
            })
            collectedSet[btn] = true
        end
    end

    LayoutButtons()
end

-- Re-parent collected buttons back into the drawer after Blizzard repositions them
local function ReclaimButtons()
    if not drawerFrame or inEditMode then return end
    local settings = UIThingsDB.actionBars
    if not settings or not settings.enabled then return end
    local btnSize = settings.buttonSize or 32

    -- Also pick up any buttons that didn't exist at initial collection
    for _, name in ipairs(MICRO_BUTTON_NAMES) do
        local btn = _G[name]
        if btn and btn.GetParent and not collectedSet[btn] then
            local origParent = btn:GetParent()
            local origPoints = {}
            for p = 1, btn:GetNumPoints() do
                origPoints[p] = { btn:GetPoint(p) }
            end
            local origW, origH = btn:GetSize()
            table.insert(collectedButtons, {
                button = btn,
                origParent = origParent,
                origPoints = origPoints,
                origWidth = origW,
                origHeight = origH,
            })
            collectedSet[btn] = true
        end
    end

    -- Reclaim all buttons back into the drawer
    local padding = settings.padding or 4
    local count = #collectedButtons
    if count == 0 then return end

    local _, _, numCols = CalculateFrameSize(count)
    for i, entry in ipairs(collectedButtons) do
        local btn = entry.button
        if btn:GetParent() ~= drawerFrame then
            SafeSetParent(btn, drawerFrame)
        end
        local col = (i - 1) % numCols
        local row = math.floor((i - 1) / numCols)
        local x = padding + (col * (btnSize + padding))
        local y = -(padding + (row * (btnSize + padding)))
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", drawerFrame, "TOPLEFT", x, y)
        btn:SetSize(btnSize, btnSize)
        btn:SetFrameStrata("MEDIUM")
        btn:SetFrameLevel(drawerFrame:GetFrameLevel() + 5)
        -- Use alpha instead of Hide/Show to avoid triggering Blizzard layout
        if drawerCollapsed then
            btn:SetAlpha(0)
            btn:EnableMouse(false)
        else
            btn:SetAlpha(1)
            btn:EnableMouse(true)
        end
    end

    -- Update frame size in case button count changed
    local frameW, frameH = CalculateFrameSize(count)
    if drawerCollapsed then
        drawerFrame:SetSize(1, frameH)
    else
        drawerFrame:SetSize(frameW, frameH)
    end
    UpdateToggleButton()
    if not drawerCollapsed then
        ApplyDrawerLockVisuals()
    end
end

local function ReleaseButtons()
    -- Restore all buttons to original parents/positions
    -- Do NOT call Show() — it triggers MicroMenuContainer:Layout() crash
    -- Just set alpha/mouse and re-parent; Blizzard will show them when needed
    for _, entry in ipairs(collectedButtons) do
        local btn = entry.button
        btn:SetAlpha(1)
        btn:EnableMouse(true)
        SafeSetParent(btn, entry.origParent)
        btn:ClearAllPoints()
        btn:SetSize(entry.origWidth, entry.origHeight)
        for _, pt in ipairs(entry.origPoints) do
            btn:SetPoint(unpack(pt))
        end
    end
    wipe(collectedButtons)
    wipe(collectedSet)
end

-- == Setup / Destroy ==

function ActionBars.SetupDrawer()
    if HasConflictAddon() then return end
    local settings = UIThingsDB.actionBars
    if not settings.enabled then return end

    -- Patch MicroMenuContainer before touching any buttons
    PatchMicroMenuLayout()

    if not drawerFrame then
        drawerFrame = CreateFrame("Frame", "LunaMicroMenuDrawer", UIParent, "BackdropTemplate")
        drawerFrame:SetClampedToScreen(true)
        drawerFrame:SetMovable(true)

        local pos = settings.pos
        drawerFrame:ClearAllPoints()
        drawerFrame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)

        ApplyDrawerLockVisuals()

        -- Drag overlay
        local dragOverlay = CreateFrame("Frame", nil, drawerFrame)
        dragOverlay:SetAllPoints(drawerFrame)
        dragOverlay:SetFrameStrata("TOOLTIP")
        dragOverlay:EnableMouse(true)
        dragOverlay:RegisterForDrag("LeftButton")
        dragOverlay:SetScript("OnDragStart", function()
            drawerFrame:StartMoving()
        end)
        dragOverlay:SetScript("OnDragStop", function()
            drawerFrame:StopMovingOrSizing()
            local point, _, relPoint, x, y = drawerFrame:GetPoint()
            UIThingsDB.actionBars.pos = { point = point, relPoint = relPoint, x = x, y = y }
            UpdateToggleButton()
        end)
        drawerFrame.dragOverlay = dragOverlay

        -- Toggle button
        drawerToggleBtn = CreateFrame("Button", nil, drawerFrame, "BackdropTemplate")
        drawerToggleBtn:SetSize(TOGGLE_BTN_WIDTH, 40)

        local toggleText = drawerToggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        toggleText:SetPoint("CENTER")
        toggleText:SetText(">")
        drawerToggleBtn.text = toggleText

        drawerToggleBtn:SetScript("OnClick", function()
            SetDrawerCollapsed(not drawerCollapsed)
        end)

        -- Apply lock state
        if settings.locked then
            dragOverlay:Hide()
        else
            dragOverlay:Show()
        end
    end

    SuppressMicroLayout(CollectMicroButtons)

    -- Hook UpdateMicroButtons to reclaim buttons after Blizzard repositions them (e.g. on click)
    if not drawerHooked then
        if type(UpdateMicroButtons) == "function" then
            hooksecurefunc("UpdateMicroButtons", function()
                if drawerFrame and not inEditMode and UIThingsDB.actionBars and UIThingsDB.actionBars.enabled then
                    C_Timer.After(0, function() SuppressMicroLayout(ReclaimButtons) end)
                end
            end)
        end
        -- Release buttons when edit mode opens, reclaim when it closes
        if EditModeManagerFrame then
            hooksecurefunc(EditModeManagerFrame, "Show", function()
                inEditMode = true
                -- Undo all our layout overrides so edit mode sees Blizzard's layout
                if UIThingsDB.actionBars and UIThingsDB.actionBars.skinEnabled then
                    RestoreBarPositions()
                    RestoreButtonSpacing(false)
                    -- Hide skin overlays
                    if skinnedBars then
                        for barFrame in pairs(skinnedBars) do
                            if barFrame.lunaSkinOverlay then
                                barFrame.lunaSkinOverlay:Hide()
                            end
                        end
                    end
                    if skinnedButtons then
                        for button in pairs(skinnedButtons) do
                            if button.lunaSkinOverlay then
                                button.lunaSkinOverlay:Hide()
                            end
                        end
                    end
                end
                -- Release micro buttons back to Blizzard
                ReleaseButtons()
                if drawerFrame then drawerFrame:Hide() end
                if drawerToggleBtn then drawerToggleBtn:Hide() end
            end)
            hooksecurefunc(EditModeManagerFrame, "Hide", function()
                if UIThingsDB.actionBars and UIThingsDB.actionBars.enabled then
                    C_Timer.After(0.5, function()
                        if drawerFrame then drawerFrame:Show() end
                        if drawerToggleBtn then drawerToggleBtn:Show() end
                        SuppressMicroLayout(CollectMicroButtons)
                    end)
                end
                -- Wipe Blizzard defaults and button positions so they get recaptured
                -- fresh (user may have moved bars in edit mode)
                wipe(blizzardDefaultPositions)
                wipe(originalButtonPositions)
                if UIThingsDB.actionBars and UIThingsDB.actionBars.skinEnabled then
                    -- Keep inEditMode true until Blizzard finishes repositioning
                    C_Timer.After(1, function()
                        inEditMode = false
                        if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
                            return -- Re-opened edit mode during delay
                        end
                        ActionBars.ApplySkin()
                    end)
                else
                    inEditMode = false
                end
            end)
        end
        drawerHooked = true
    end
end

function ActionBars.DestroyDrawer()
    if HasConflictAddon() then return end
    SuppressMicroLayout(ReleaseButtons)

    if drawerToggleBtn then
        drawerToggleBtn:Hide()
    end
    if drawerFrame then
        drawerFrame:Hide()
    end
end

function ActionBars.SetDrawerLocked(locked)
    UIThingsDB.actionBars.locked = locked
    if drawerFrame and drawerFrame.dragOverlay then
        if locked then
            drawerFrame.dragOverlay:Hide()
        else
            drawerFrame.dragOverlay:Show()
        end
    end
end

function ActionBars.UpdateDrawerBorder()
    if not drawerFrame then return end
    ApplyDrawerLockVisuals()
end

function ActionBars.UpdateSettings()
    if HasConflictAddon() then return end
    if not UIThingsDB.actionBars.enabled then
        ActionBars.DestroyDrawer()
        return
    end

    if drawerFrame and #collectedButtons > 0 then
        SuppressMicroLayout(LayoutButtons)
        ApplyDrawerLockVisuals()
    end
end

-- =============================================
-- == ACTION BAR SKINNING ==
-- =============================================

local ACTION_BARS = {
    { bar = "MainActionBar",       prefix = "ActionButton",              count = 12 },
    { bar = "MainMenuBar",         prefix = "ActionButton",              count = 12 },
    { bar = "MultiBarBottomLeft",  prefix = "MultiBarBottomLeftButton",  count = 12 },
    { bar = "MultiBarBottomRight", prefix = "MultiBarBottomRightButton", count = 12 },
    { bar = "MultiBarRight",       prefix = "MultiBarRightButton",       count = 12 },
    { bar = "MultiBarLeft",        prefix = "MultiBarLeftButton",        count = 12 },
    { bar = "MultiBar5",           prefix = "MultiBar5Button",           count = 12 },
    { bar = "MultiBar6",           prefix = "MultiBar6Button",           count = 12 },
    { bar = "MultiBar7",           prefix = "MultiBar7Button",           count = 12 },
}

local skinHooked = false
local skinnedButtons = {}
local skinnedBars = {}

local function SkinButton(button)
    if not button then return end
    local settings = UIThingsDB.actionBars
    if not settings or not settings.skinEnabled then return end

    local borderSize = settings.skinButtonBorderSize or 1
    local bc = settings.skinButtonBorderColor or { r = 0.3, g = 0.3, b = 0.3, a = 1 }

    -- Apply custom button size — SetSize is protected in combat
    local btnSize = settings.skinButtonSize or 0
    if btnSize > 0 and not InCombatLockdown() then
        button:SetSize(btnSize, btnSize)
    end

    -- Create or reuse overlay
    if not button.lunaSkinOverlay then
        button.lunaSkinOverlay = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.lunaSkinOverlay:SetAllPoints()
        skinnedButtons[button] = true
    end

    local overlay = button.lunaSkinOverlay
    overlay:SetFrameLevel(button:GetFrameLevel() + 2)

    -- Hide border on empty slots
    local hasAction = button.HasAction and button:HasAction()
    if hasAction == nil then
        -- Fallback: check if icon texture is visible
        hasAction = button.icon and button.icon:IsShown()
    end

    if borderSize > 0 and hasAction then
        overlay:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = borderSize,
        })
        overlay:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a or 1)
    else
        overlay:SetBackdrop(nil)
    end
    overlay:SetBackdropColor(0, 0, 0, 0)
    overlay:Show()

    -- Square buttons: hide all Blizzard border textures
    if button.NormalTexture then
        button.NormalTexture:SetAlpha(0)
    end
    if button.SetNormalTexture then
        button:SetNormalTexture(0)
    end
    if button.SetHighlightTexture then
        button:SetHighlightTexture(0)
    end
    if button.SetPushedTexture then
        button:SetPushedTexture(0)
    end
    -- Hide additional border regions WoW 12.0 adds
    for _, regionName in ipairs({ "Border", "IconBorder", "SlotArt", "SlotBackground", "IconMask" }) do
        local region = button[regionName]
        if region and region.SetAlpha then
            region:SetAlpha(0)
        end
    end
    -- Remove icon mask for square look
    if button.icon then
        if button.icon.SetTexCoord then
            button.icon:SetTexCoord(0, 1, 0, 1)
        end
        -- Remove all mask textures from the icon
        if button.icon.GetMaskTextures then
            for _, mask in ipairs(button.icon:GetMaskTextures()) do
                button.icon:RemoveMaskTexture(mask)
            end
        end
    end
    -- Also remove masks from Cooldown frame
    if button.cooldown and button.cooldown.GetSwipeTexture then
        if button.cooldown.SetSwipeTexture then
            button.cooldown:SetSwipeTexture("")
        end
    end
    -- Hide CircleMask or any mask children by name/type
    for _, region in ipairs({ button:GetRegions() }) do
        local rname = region:GetName() or ""
        if rname:find("Mask") or rname:find("CircleMask") then
            region:Hide()
        end
        -- Also catch unnamed mask textures that create the round look
        if region:GetObjectType() == "MaskTexture" then
            region:Hide()
        end
    end
    -- Check named mask children
    for _, childName in ipairs({ "CircleMask", "IconMask", "Mask" }) do
        local child = button[childName]
        if child and child.Hide then
            child:Hide()
        end
    end

    -- Keybind text
    if button.HotKey then
        button.HotKey:SetAlpha(settings.hideKeybindText and 0 or 1)
    end

    -- Macro text
    if button.Name then
        button.Name:SetAlpha(settings.hideMacroText and 0 or 1)
    end
end

local function SkinBar(barFrame)
    if not barFrame then return end
    local settings = UIThingsDB.actionBars
    if not settings or not settings.skinEnabled then return end

    local borderSize = settings.skinBarBorderSize or 2
    local bc = settings.skinBarBorderColor or { r = 0.2, g = 0.2, b = 0.2, a = 1 }
    local bg = settings.skinBarBgColor or { r = 0, g = 0, b = 0, a = 0.5 }

    if not barFrame.lunaSkinOverlay then
        barFrame.lunaSkinOverlay = CreateFrame("Frame", nil, barFrame, "BackdropTemplate")
        skinnedBars[barFrame] = true
    end

    local overlay = barFrame.lunaSkinOverlay
    local pad = borderSize + 2
    overlay:ClearAllPoints()
    overlay:SetPoint("TOPLEFT", barFrame, "TOPLEFT", -pad, pad)
    overlay:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", pad, -pad)
    overlay:SetFrameLevel(math.max(barFrame:GetFrameLevel() - 1, 0))

    if borderSize > 0 then
        overlay:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = borderSize,
        })
        overlay:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a or 1)
        overlay:SetBackdropColor(bg.r, bg.g, bg.b, bg.a or 0.5)
    else
        overlay:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
        })
        overlay:SetBackdropColor(bg.r, bg.g, bg.b, bg.a or 0.5)
    end
    overlay:Show()
end

-- blizzardDefaultPositions and originalButtonPositions are forward-declared near the top of the file

local function ApplyButtonSpacing(barInfo)
    local settings = UIThingsDB.actionBars
    if not settings or not settings.skinEnabled then return end
    local spacing = settings.skinButtonSpacing or 2
    local btnSize = settings.skinButtonSize or 0

    -- Collect all visible buttons for this bar
    local buttons = {}
    for i = 1, barInfo.count do
        local btn = _G[barInfo.prefix .. i]
        if btn then
            -- Save original position once (before we modify anything)
            if not originalButtonPositions[btn] then
                local points = {}
                for p = 1, btn:GetNumPoints() do
                    points[p] = { btn:GetPoint(p) }
                end
                originalButtonPositions[btn] = points
            end
            buttons[#buttons + 1] = btn
        end
    end

    if #buttons == 0 then return end

    -- Detect the bar's layout using actual screen coordinates.
    -- Anchor offset data is unreliable because buttons may be anchored to the bar
    -- frame or to each other with different anchor points. Screen positions tell us
    -- exactly where Blizzard placed them.

    local isVertical = false
    local buttonsPerRow = #buttons -- default: all in one row
    local buttonsPerCol = #buttons

    if #buttons >= 2 then
        -- Use GetCenter() for reliable screen coordinates
        local cx1, cy1 = buttons[1]:GetCenter()
        local cx2, cy2 = buttons[2]:GetCenter()

        if cx1 and cy1 and cx2 and cy2 then
            local dx = math.abs(cx2 - cx1)
            local dy = math.abs(cy2 - cy1)

            -- If button 2 is directly below button 1 (same X, different Y), it's vertical
            if dx < 5 and dy > 5 then
                isVertical = true
            end
        end
    end

    -- Detect row/column breaks using screen coordinates
    if #buttons >= 2 then
        local _, baseCoord
        if isVertical then
            -- Vertical bar: detect column breaks by X changing
            _, baseCoord = buttons[1]:GetCenter()
            baseCoord = select(1, buttons[1]:GetCenter())
            for i = 2, #buttons do
                local cx = select(1, buttons[i]:GetCenter())
                if cx and baseCoord and math.abs(cx - baseCoord) > 5 then
                    buttonsPerCol = i - 1
                    break
                end
            end
        else
            -- Horizontal bar: detect row breaks by Y changing
            _, baseCoord = buttons[1]:GetCenter()
            for i = 2, #buttons do
                local _, cy = buttons[i]:GetCenter()
                if cy and baseCoord and math.abs(cy - baseCoord) > 5 then
                    buttonsPerRow = i - 1
                    break
                end
            end
        end
    end

    -- Reposition buttons with our spacing, preserving row/column breaks.
    -- Button 1 keeps its original position.
    for i = 2, #buttons do
        local btn = buttons[i]
        local clearPts = btn.ClearAllPointsBase or btn.ClearAllPoints
        local setPt = btn.SetPointBase or btn.SetPoint
        clearPts(btn)

        if isVertical then
            -- Vertical bar: stack downward, break into columns
            if ((i - 1) % buttonsPerCol) == 0 then
                local colStart = buttons[i - buttonsPerCol]
                setPt(btn, "LEFT", colStart, "RIGHT", spacing, 0)
            else
                setPt(btn, "TOP", buttons[i - 1], "BOTTOM", 0, -spacing)
            end
        else
            -- Horizontal bar: go left-to-right, break into rows
            if ((i - 1) % buttonsPerRow) == 0 then
                local rowStart = buttons[i - buttonsPerRow]
                setPt(btn, "TOP", rowStart, "BOTTOM", 0, -spacing)
            else
                setPt(btn, "LEFT", buttons[i - 1], "RIGHT", spacing, 0)
            end
        end
    end
end

-- == Secure Handler Bar Positioning (Absolute) ==
-- Uses SecureHandlerStateTemplate so that bar repositioning works even in combat.
-- Stores absolute positions anchored to UIParent — no need to track Blizzard's "originals".

local secureAnchors = {}   -- [barName] = secure handler frame
local hookedBars = {}      -- [barName] = true, tracks which bars have SetPoint hooks
local suppressHook = false -- prevents recursive hook firing

-- Convert a frame's current screen position to UIParent-relative CENTER coordinates
local function FrameToUIParentPosition(frame)
    local cx, cy = frame:GetCenter()
    if not cx or not cy then return nil end
    local scale = frame:GetEffectiveScale()
    local uiScale = UIParent:GetEffectiveScale()
    -- Convert to UIParent coordinate space
    cx = cx * scale / uiScale
    cy = cy * scale / uiScale
    -- Make relative to UIParent center
    local uiCx, uiCy = UIParent:GetCenter()
    return { point = "CENTER", x = math.floor(cx - uiCx + 0.5), y = math.floor(cy - uiCy + 0.5) }
end
ActionBars.FrameToUIParentPosition = FrameToUIParentPosition

-- Migrate old barOffsets format to new barPositions format
local barOffsetsMigrated = false
local function MigrateBarOffsets()
    if barOffsetsMigrated then return end
    barOffsetsMigrated = true
    local settings = UIThingsDB.actionBars
    if not settings or not settings.barOffsets then return end

    local hasOffsets = false
    for barName, offsets in pairs(settings.barOffsets) do
        if offsets.x ~= 0 or offsets.y ~= 0 then
            hasOffsets = true
            break
        end
    end
    if not hasOffsets then return end

    if not settings.barPositions then settings.barPositions = {} end

    for barName, offsets in pairs(settings.barOffsets) do
        if (offsets.x ~= 0 or offsets.y ~= 0) and not settings.barPositions[barName] then
            -- The bar is currently at its offset position, capture it as absolute
            local barFrame = _G[barName]
            if barFrame then
                local absPos = FrameToUIParentPosition(barFrame)
                if absPos then
                    settings.barPositions[barName] = absPos
                end
            end
        end
    end
    -- Clear old offsets
    settings.barOffsets = {}
end

-- The restricted Lua snippet that repositions a bar using absolute coordinates.
-- Reads absPoint, absX, absY attributes and the "uiparent" frame ref.
local REPOSITION_SNIPPET = [=[
    local bar = self:GetFrameRef("bar")
    local uip = self:GetFrameRef("uiparent")
    local pt = self:GetAttribute("absPoint")
    local ax = self:GetAttribute("absX") or 0
    local ay = self:GetAttribute("absY") or 0
    if bar and pt and uip then
        bar:ClearAllPoints()
        bar:SetPoint(pt, uip, pt, ax, ay)
    end
]=]

-- Set up a secure anchor for a bar (must be called out of combat)
local function SetupSecureAnchor(barName, barFrame, absPos)
    if secureAnchors[barName] then return secureAnchors[barName] end
    if InCombatLockdown() then return nil end

    local anchor = CreateFrame("Frame", "LunaBarAnchor_" .. barName, UIParent, "SecureHandlerStateTemplate")
    anchor:SetSize(1, 1)
    anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    -- Give the snippet handles to the bar and UIParent
    anchor:SetFrameRef("bar", barFrame)
    anchor:SetFrameRef("uiparent", UIParent)

    -- Store absolute position as attributes
    anchor:SetAttribute("absPoint", absPos.point)
    anchor:SetAttribute("absX", absPos.x)
    anchor:SetAttribute("absY", absPos.y)

    -- When "applypos" attribute changes, run the reposition snippet
    anchor:SetAttribute("_onattributechanged", [=[
        if name == "applypos" then
            ]=] .. REPOSITION_SNIPPET .. [=[
        end
    ]=])

    -- State driver: re-apply position on combat state transitions
    RegisterStateDriver(anchor, "reposition", "[combat] combat; nocombat")
    anchor:SetAttribute("_onstate-reposition", REPOSITION_SNIPPET)

    secureAnchors[barName] = anchor
    return anchor
end

-- Apply an absolute position to a bar
local function ApplyBarPosition(barName, barFrame)
    local settings = UIThingsDB.actionBars
    if not settings or not settings.skinEnabled then return end
    local absPos = settings.barPositions and settings.barPositions[barName]
    if not absPos then return end -- no stored position, let Blizzard handle it

    -- Create or update secure anchor for combat-safe repositioning
    local anchor = secureAnchors[barName]
    if not anchor then
        anchor = SetupSecureAnchor(barName, barFrame, absPos)
    elseif not InCombatLockdown() then
        anchor:SetAttribute("absPoint", absPos.point)
        anchor:SetAttribute("absX", absPos.x)
        anchor:SetAttribute("absY", absPos.y)
    end

    -- Out of combat: directly reposition the bar using absolute coordinates
    if not InCombatLockdown() then
        local clearPoints = barFrame.ClearAllPointsBase or barFrame.ClearAllPoints
        local setPoint = barFrame.SetPointBase or barFrame.SetPoint
        suppressHook = true
        clearPoints(barFrame)
        setPoint(barFrame, absPos.point, UIParent, absPos.point, absPos.x, absPos.y)
        suppressHook = false
    end

    -- Hook SetPointBase so when Blizzard re-layouts, we re-apply our absolute position
    if not hookedBars[barName] then
        hookedBars[barName] = true
        local hasBase = barFrame.SetPointBase ~= nil
        local hookTarget = hasBase and "SetPointBase" or "SetPoint"
        hooksecurefunc(barFrame, hookTarget, function()
            if suppressHook then return end
            if InCombatLockdown() then return end
            if inEditMode then return end
            local s = UIThingsDB.actionBars
            if not s or not s.skinEnabled then return end
            local pos = s.barPositions and s.barPositions[barName]
            if not pos then return end
            -- Re-apply our absolute position
            local clr = barFrame.ClearAllPointsBase or barFrame.ClearAllPoints
            local sp = barFrame.SetPointBase or barFrame.SetPoint
            suppressHook = true
            clr(barFrame)
            sp(barFrame, pos.point, UIParent, pos.point, pos.x, pos.y)
            suppressHook = false
        end)
    end
end

local function RemoveSecureAnchors()
    if InCombatLockdown() then return end
    for barName, anchor in pairs(secureAnchors) do
        UnregisterStateDriver(anchor, "reposition")
        anchor:Hide()
    end
    wipe(secureAnchors)
end

-- Restore bars to Blizzard default positions (for edit mode)
RestoreBarPositions = function()
    if InCombatLockdown() then return end
    RemoveSecureAnchors()
    suppressHook = true
    for barName, defPos in pairs(blizzardDefaultPositions) do
        local barFrame = _G[barName]
        if barFrame then
            local clearPoints = barFrame.ClearAllPointsBase or barFrame.ClearAllPoints
            local setPoint = barFrame.SetPointBase or barFrame.SetPoint
            clearPoints(barFrame)
            -- relTo may be nil for some bars, use UIParent as fallback
            local relTo = defPos.relTo or UIParent
            setPoint(barFrame, defPos.point, relTo, defPos.relPoint, defPos.x, defPos.y)
        end
    end
    suppressHook = false
end

RestoreButtonSpacing = function(andWipe)
    if InCombatLockdown() then return end
    for btn, points in pairs(originalButtonPositions) do
        local clearPts = btn.ClearAllPointsBase or btn.ClearAllPoints
        local setPt = btn.SetPointBase or btn.SetPoint
        clearPts(btn)
        for _, pt in ipairs(points) do
            setPt(btn, unpack(pt))
        end
    end
    if andWipe ~= false then
        wipe(originalButtonPositions)
    end
end

function ActionBars.ApplySkin()
    if HasConflictAddon() then return end
    local settings = UIThingsDB.actionBars
    if not settings or not settings.skinEnabled then return end

    local inCombat = InCombatLockdown()

    -- If in combat, defer protected operations but still do what we can
    if inCombat then
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        f:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            ActionBars.ApplySkin()
        end)
    end

    -- If in combat, skip everything — the deferred call will handle it all
    if inCombat then return end

    -- Migrate old barOffsets to barPositions on first run
    MigrateBarOffsets()

    -- Capture Blizzard's default positions BEFORE we apply our overrides
    -- (only for bars we haven't captured yet or after edit mode wipe)
    suppressHook = true
    for _, barInfo in ipairs(ACTION_BARS) do
        local barFrame = _G[barInfo.bar]
        if barFrame and not blizzardDefaultPositions[barInfo.bar] then
            local numPoints = barFrame:GetNumPoints()
            if numPoints > 0 then
                local point, relTo, relPoint, x, y = barFrame:GetPoint(1)
                blizzardDefaultPositions[barInfo.bar] = {
                    point = point,
                    relTo = relTo,
                    relPoint = relPoint,
                    x = x,
                    y = y
                }
            end
        end
    end
    suppressHook = false

    -- Skin each bar and its buttons, apply spacing and absolute positions
    for _, barInfo in ipairs(ACTION_BARS) do
        local barFrame = _G[barInfo.bar]
        if barFrame then
            SkinBar(barFrame)
            for i = 1, barInfo.count do
                local btn = _G[barInfo.prefix .. i]
                if btn then
                    SkinButton(btn)
                end
            end
            ApplyButtonSpacing(barInfo)
            ApplyBarPosition(barInfo.bar, barFrame)
        end
    end

    -- Page scroll and bags bar use protected APIs — only safe out of combat
    if not inCombat then
        local pageNumber = MainActionBar and MainActionBar.ActionBarPageNumber
        if pageNumber then
            if settings.hideBarScroll then
                pageNumber:SetAlpha(0)
                pageNumber:EnableMouse(false)
            else
                pageNumber:SetAlpha(1)
                pageNumber:EnableMouse(true)
            end
        end

        local bagsBar = _G["BagsBar"]
        if bagsBar then
            if settings.hideBagsBar then
                RegisterStateDriver(bagsBar, "visibility", "hide")
            else
                UnregisterStateDriver(bagsBar, "visibility")
                bagsBar:Show()
            end
        end
    end

    -- Hook individual button methods to re-apply skin after Blizzard updates (once only)
    if not skinHooked then
        local hookedButtons = {}
        for _, barInfo in ipairs(ACTION_BARS) do
            for i = 1, barInfo.count do
                local btn = _G[barInfo.prefix .. i]
                if btn and not hookedButtons[btn] then
                    hookedButtons[btn] = true
                    if btn.UpdateHotkeys then
                        hooksecurefunc(btn, "UpdateHotkeys", function(self)
                            if UIThingsDB.actionBars and UIThingsDB.actionBars.skinEnabled then
                                if self.HotKey then
                                    self.HotKey:SetAlpha(UIThingsDB.actionBars.hideKeybindText and 0 or 1)
                                end
                            end
                        end)
                    end
                    if btn.Update then
                        hooksecurefunc(btn, "Update", function(self)
                            if UIThingsDB.actionBars and UIThingsDB.actionBars.skinEnabled then
                                SkinButton(self)
                            end
                        end)
                    end
                    -- Re-hide NormalTexture whenever Blizzard resets it
                    hooksecurefunc(btn, "SetNormalTexture", function(self)
                        if UIThingsDB.actionBars and UIThingsDB.actionBars.skinEnabled then
                            if self.NormalTexture then
                                self.NormalTexture:SetAlpha(0)
                            end
                        end
                    end)
                end
            end
        end
        skinHooked = true
    end
end

function ActionBars.RemoveSkin()
    if HasConflictAddon() then return end

    -- Defer entirely if in combat — SetParent/SetPoint on protected frames is blocked
    if InCombatLockdown() then
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        f:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            ActionBars.RemoveSkin()
        end)
        return
    end

    -- Restore button spacing and bar positions
    RestoreButtonSpacing()
    RestoreBarPositions()

    -- Restore buttons
    for button in pairs(skinnedButtons) do
        if button.lunaSkinOverlay then
            button.lunaSkinOverlay:Hide()
        end
        if button.NormalTexture then
            button.NormalTexture:SetAlpha(1)
        end
        -- Restore border regions
        for _, regionName in ipairs({ "Border", "IconBorder", "SlotArt", "SlotBackground", "IconMask" }) do
            local region = button[regionName]
            if region and region.SetAlpha then
                region:SetAlpha(1)
            end
        end
        if button.HotKey then
            button.HotKey:SetAlpha(1)
        end
        if button.Name then
            button.Name:SetAlpha(1)
        end
    end

    -- Restore bars
    for barFrame in pairs(skinnedBars) do
        if barFrame.lunaSkinOverlay then
            barFrame.lunaSkinOverlay:Hide()
        end
    end

    -- Show page scroll
    local pageNumber = MainActionBar and MainActionBar.ActionBarPageNumber
    if pageNumber then
        pageNumber:SetAlpha(1)
        pageNumber:EnableMouse(true)
    end

    -- Show bags bar
    local bagsBar = _G["BagsBar"]
    if bagsBar then
        UnregisterStateDriver(bagsBar, "visibility")
        bagsBar:Show()
    end
end

function ActionBars.UpdateSkin()
    if HasConflictAddon() then return end
    local settings = UIThingsDB.actionBars
    if settings and settings.skinEnabled then
        ActionBars.ApplySkin()
    else
        ActionBars.RemoveSkin()
    end
end

-- == Bar Highlight (for config panel identification) ==

local highlightFrame = nil

function ActionBars.HighlightBar(barName)
    local barFrame = _G[barName]
    if not barFrame then return end

    if not highlightFrame then
        highlightFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        highlightFrame:SetFrameStrata("TOOLTIP")
        highlightFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
        })
        highlightFrame:SetBackdropColor(1, 1, 0, 0.15)
        highlightFrame:SetBackdropBorderColor(1, 1, 0, 0.9)

        local label = highlightFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        label:SetPoint("BOTTOM", highlightFrame, "TOP", 0, 4)
        label:SetTextColor(1, 1, 0)
        highlightFrame.label = label
    end

    highlightFrame:ClearAllPoints()
    highlightFrame:SetPoint("TOPLEFT", barFrame, "TOPLEFT", -4, 4)
    highlightFrame:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", 4, -4)
    highlightFrame.label:SetText(BAR_DISPLAY_NAMES[barName] or barName)
    highlightFrame:Show()
end

function ActionBars.UnhighlightBar()
    if highlightFrame then
        highlightFrame:Hide()
    end
end

-- == Bar Drag-to-Position ==

local activeDragBar = nil -- barName currently being dragged
local dragOverlays = {}   -- [barName] = overlay frame

-- Callback set by config panel to update sliders when drag finishes
ActionBars.onBarDragUpdate = nil

function ActionBars.StartBarDrag(barName)
    local barFrame = _G[barName]
    if not barFrame then return end

    -- Stop any previous drag
    if activeDragBar and activeDragBar ~= barName then
        ActionBars.StopBarDrag(activeDragBar)
    end

    activeDragBar = barName

    -- Create a drag overlay so we can drag without interfering with secure buttons
    if not dragOverlays[barName] then
        local overlay = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        overlay:SetFrameStrata("TOOLTIP")
        overlay:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
        })
        overlay:SetBackdropColor(0, 1, 0, 0.1)
        overlay:SetBackdropBorderColor(0, 1, 0, 0.8)

        local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        label:SetPoint("CENTER")
        label:SetTextColor(0, 1, 0)
        label:SetText("Drag to position")

        overlay:EnableMouse(true)
        overlay:SetMovable(true)
        overlay:RegisterForDrag("LeftButton")

        overlay:SetScript("OnDragStart", function(self)
            -- Save screen position before drag starts
            self.startCX, self.startCY = self:GetCenter()
            self:StartMoving()
        end)

        overlay:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            -- Calculate how far the overlay moved on screen
            local endCX, endCY = self:GetCenter()
            local deltaX = math.floor((endCX - (self.startCX or endCX)) + 0.5)
            local deltaY = math.floor((endCY - (self.startCY or endCY)) + 0.5)

            -- Get current absolute position and add delta
            if not UIThingsDB.actionBars.barPositions then
                UIThingsDB.actionBars.barPositions = {}
            end
            local curPos = UIThingsDB.actionBars.barPositions[barName]
            if not curPos then
                curPos = FrameToUIParentPosition(barFrame)
                if not curPos then curPos = { point = "CENTER", x = 0, y = 0 } end
            end
            local newPos = { point = "CENTER", x = curPos.x + deltaX, y = curPos.y + deltaY }
            UIThingsDB.actionBars.barPositions[barName] = newPos

            -- Apply the new absolute position
            ApplyBarPosition(barName, barFrame)

            -- Snap overlay back on top of bar's new position
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", barFrame, "TOPLEFT", -4, 4)
            self:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", 4, -4)

            -- Notify config panel to update sliders
            if ActionBars.onBarDragUpdate then
                ActionBars.onBarDragUpdate(barName, newPos)
            end
        end)

        dragOverlays[barName] = overlay
    end

    -- Position overlay on top of the bar
    local overlay = dragOverlays[barName]
    overlay:ClearAllPoints()
    overlay:SetPoint("TOPLEFT", barFrame, "TOPLEFT", -4, 4)
    overlay:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", 4, -4)
    overlay:Show()

    -- Highlight the bar
    ActionBars.HighlightBar(barName)
end

function ActionBars.StopBarDrag(barName)
    if dragOverlays[barName] then
        dragOverlays[barName]:Hide()
    end
    if activeDragBar == barName then
        activeDragBar = nil
    end
    ActionBars.UnhighlightBar()
end

function ActionBars.IsBarDragging(barName)
    return activeDragBar == barName
end

-- == Initialization ==

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        if HasConflictAddon() then return end
        -- Patch MicroMenuContainer early so it never crashes, even if drawer is disabled
        PatchMicroMenuLayout()
        local settings = UIThingsDB.actionBars
        if settings then
            if settings.enabled then
                C_Timer.After(1, function()
                    ActionBars.SetupDrawer()
                end)
            end
            if settings.skinEnabled then
                if InCombatLockdown() then
                    -- Reloaded in combat — apply skin the instant combat ends
                    local f = CreateFrame("Frame")
                    f:RegisterEvent("PLAYER_REGEN_ENABLED")
                    f:SetScript("OnEvent", function(self)
                        self:UnregisterAllEvents()
                        wipe(blizzardDefaultPositions)
                        wipe(originalButtonPositions)
                        ActionBars.ApplySkin()
                    end)
                else
                    -- Run immediately — SetPointBase hooks will keep
                    -- positions correct if Blizzard re-layouts later
                    ActionBars.ApplySkin()
                end
            end
        end
    end
end)
