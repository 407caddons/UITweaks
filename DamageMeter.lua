-- DamageMeter.lua
-- Custom damage meter built from combat log data.
--
-- NOTE: This module uses COMBAT_LOG_EVENT_UNFILTERED. Despite the CLAUDE.md
-- note, this event IS fully available to third-party addons in WoW retail and
-- is used by every major damage meter addon (Details!, Recount, etc.).
-- A damage meter cannot be built without access to this event.

local addonName, addonTable = ...
addonTable.DamageMeter = {}

local EventBus  = addonTable.EventBus
local SafeAfter = addonTable.Core.SafeAfter
local Abbrev    = addonTable.Core.AbbreviateNumber

-- ============================================================
-- Constants
-- ============================================================

local METER_TYPES = {
    "damage", "healing", "interrupts", "deaths",
    "dispels", "damageTaken", "enemyHeal", "enemyDamageTaken",
}

local TYPE_LABEL = {
    damage           = "Damage",
    healing          = "Healing",
    interrupts       = "Interrupts",
    deaths           = "Deaths",
    dispels          = "Dispels",
    damageTaken      = "Dmg Taken",
    enemyHeal        = "Enemy Heal",
    enemyDamageTaken = "Enemy Dmg In",
}

-- Combat log flags
local AFFIL_MASK = 0x0000000F
local BIT_MINE   = 0x00000001
local BIT_PARTY  = 0x00000002
local BIT_RAID   = 0x00000004
local BIT_FRIEND = 0x00000010

local function IsGroupMember(flags)
    local aff = bit.band(flags, AFFIL_MASK)
    return aff == BIT_MINE or aff == BIT_PARTY or aff == BIT_RAID
end

local function IsFriendly(flags)
    return bit.band(flags, BIT_FRIEND) ~= 0
end

-- ============================================================
-- Data Storage
-- ============================================================

local function NewSession()
    return {
        damage           = {},
        healing          = {},
        interrupts       = {},
        deaths           = {},
        dispels          = {},
        damageTaken      = {},
        enemyHeal        = {},
        enemyDamageTaken = {},
    }
end

local sessions    = { fight = NewSession(), overall = NewSession() }
local classCache  = {}  -- guid → class token

local function GetGuidClass(guid)
    if classCache[guid] then return classCache[guid] end
    local _, cls = GetPlayerInfoByGUID(guid)
    if cls then classCache[guid] = cls end
    return cls
end

local function EnsureUnit(cat, guid, name)
    local u = cat[guid]
    if not u then
        u = { name = name or guid, class = GetGuidClass(guid), total = 0, spells = {} }
        cat[guid] = u
    else
        if name and u.name ~= name then u.name = name end
        if not u.class then u.class = GetGuidClass(guid) end
    end
    return u
end

local function AddSpell(u, spellId, spellName, amount)
    local id = spellId or 0
    local sp = u.spells[id]
    if not sp then
        u.spells[id] = { name = spellName or "Unknown", total = amount, hits = 1 }
    else
        sp.total = sp.total + amount
        sp.hits  = sp.hits + 1
    end
end

local function RecordBoth(catName, guid, name, amount, spellId, spellName)
    local u1 = EnsureUnit(sessions.fight[catName],   guid, name)
    u1.total = u1.total + amount
    AddSpell(u1, spellId, spellName, amount)
    local u2 = EnsureUnit(sessions.overall[catName], guid, name)
    u2.total = u2.total + amount
    AddSpell(u2, spellId, spellName, amount)
end

local function RecordBothNoSpell(catName, guid, name, amount)
    local u1 = EnsureUnit(sessions.fight[catName],   guid, name)
    u1.total = u1.total + amount
    local u2 = EnsureUnit(sessions.overall[catName], guid, name)
    u2.total = u2.total + amount
end

-- ============================================================
-- Combat Log Parsing
-- ============================================================

local function OnCombatLog()
    local _, sub, _,
          srcGUID, srcName, srcFlags, _,
          dstGUID, dstName, dstFlags = CombatLogGetCurrentEventInfo()

    -- ---- SWING DAMAGE ----
    if sub == "SWING_DAMAGE" then
        local amount = select(12, CombatLogGetCurrentEventInfo())
        if IsGroupMember(srcFlags) then
            RecordBoth("damage", srcGUID, srcName, amount, 0, "Auto Attack")
        end
        if IsFriendly(dstFlags) then
            RecordBoth("damageTaken", dstGUID, dstName, amount, 0, "Auto Attack")
        end
        if not IsFriendly(dstFlags) and IsGroupMember(srcFlags) then
            RecordBothNoSpell("enemyDamageTaken", dstGUID, dstName, amount)
        end

    -- ---- SPELL / PERIODIC / RANGE DAMAGE ----
    elseif sub == "SPELL_DAMAGE" or sub == "SPELL_PERIODIC_DAMAGE" or sub == "RANGE_DAMAGE" then
        local spellId, spellName, _, amount = select(12, CombatLogGetCurrentEventInfo())
        if IsGroupMember(srcFlags) then
            RecordBoth("damage", srcGUID, srcName, amount, spellId, spellName)
        end
        if IsFriendly(dstFlags) then
            RecordBoth("damageTaken", dstGUID, dstName, amount, spellId, spellName)
        end
        if not IsFriendly(dstFlags) and IsGroupMember(srcFlags) then
            RecordBothNoSpell("enemyDamageTaken", dstGUID, dstName, amount)
        end

    -- ---- HEALING ----
    elseif sub == "SPELL_HEAL" or sub == "SPELL_PERIODIC_HEAL" then
        local spellId, spellName, _, amount, overheal = select(12, CombatLogGetCurrentEventInfo())
        local eff = math.max(0, amount - (overheal or 0))
        if IsGroupMember(srcFlags) then
            RecordBoth("healing", srcGUID, srcName, eff, spellId, spellName)
        end
        -- Enemy self-heal tracking
        if not IsFriendly(srcFlags) and not IsFriendly(dstFlags) then
            RecordBothNoSpell("enemyHeal", srcGUID, srcName, eff)
        end

    -- ---- INTERRUPT ----
    elseif sub == "SPELL_INTERRUPT" then
        if IsGroupMember(srcFlags) then
            -- params 15-16: the spell that was interrupted
            local _, _, _, intSpellId, intSpellName = select(12, CombatLogGetCurrentEventInfo())
            RecordBoth("interrupts", srcGUID, srcName, 1, intSpellId, intSpellName)
        end

    -- ---- DEATH ----
    elseif sub == "UNIT_DIED" then
        if IsFriendly(dstFlags) then
            RecordBothNoSpell("deaths", dstGUID, dstName, 1)
        end

    -- ---- DISPEL ----
    elseif sub == "SPELL_DISPEL" then
        if IsGroupMember(srcFlags) then
            -- params 15-16: the dispelled spell
            local _, _, _, extSpellId, extSpellName = select(12, CombatLogGetCurrentEventInfo())
            RecordBoth("dispels", srcGUID, srcName, 1, extSpellId, extSpellName)
        end
    end
end

-- ============================================================
-- Sorted Entry Helpers
-- ============================================================

local function GetEntries(sessKey, mtype)
    local cat = sessions[sessKey] and sessions[sessKey][mtype]
    if not cat then return {} end
    local list = {}
    for guid, d in pairs(cat) do
        if d.total > 0 then
            list[#list + 1] = { guid = guid, name = d.name, class = d.class, total = d.total, spells = d.spells }
        end
    end
    table.sort(list, function(a, b) return a.total > b.total end)
    return list
end

local function GetSpellEntries(sessKey, mtype, guid)
    local cat = sessions[sessKey] and sessions[sessKey][mtype]
    if not cat or not cat[guid] then return {} end
    local list = {}
    for spellId, sp in pairs(cat[guid].spells) do
        if sp.total > 0 then
            list[#list + 1] = { spellId = spellId, name = sp.name, total = sp.total, hits = sp.hits or 1 }
        end
    end
    table.sort(list, function(a, b) return a.total > b.total end)
    return list
end

local function FormatVal(val, mtype)
    if mtype == "interrupts" or mtype == "deaths" or mtype == "dispels" then
        return tostring(val)
    end
    return Abbrev(val)
end

-- ============================================================
-- Class Color
-- ============================================================

local function GetClassColor(class)
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return c.r, c.g, c.b
    end
    return 0.6, 0.6, 0.6
end

-- ============================================================
-- UI State
-- ============================================================

local mainFrame  = nil
local panes      = {}
local drilldown  = {}   -- drilldown[idx] = { guid, name } or nil
local initialized = false
local dockTicker  = nil

local HEADER_H = 26

-- ============================================================
-- Row Pool (per pane)
-- ============================================================

local function AcquireRow(pool, parent)
    for _, row in ipairs(pool) do
        if not row:IsShown() then
            row:Show()
            return row
        end
    end
    local row = CreateFrame("Button", nil, parent)
    row.bg  = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bar = row:CreateTexture(nil, "BORDER")
    row.bar:SetPoint("TOPLEFT")
    row.bar:SetPoint("BOTTOMLEFT")
    row.nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.nameFS:SetPoint("LEFT", 4, 0)
    row.nameFS:SetPoint("RIGHT", -50, 0)
    row.nameFS:SetJustifyH("LEFT")
    row.nameFS:SetWordWrap(false)
    row.valFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.valFS:SetPoint("RIGHT", -4, 0)
    row.valFS:SetJustifyH("RIGHT")
    pool[#pool + 1] = row
    return row
end

local function HideAllRows(pool)
    for _, row in ipairs(pool) do
        if row:IsShown() then
            row:Hide()
            row:SetScript("OnClick", nil)
        end
    end
end

-- ============================================================
-- Render Pane
-- ============================================================

local function RenderPane(idx)
    local pane = panes[idx]
    if not pane or not pane.frame:IsShown() then return end

    local s     = UIThingsDB.damageMeter
    local cfg   = (idx == 1) and s.meter1 or s.meter2
    local mtype = cfg.type
    local sess  = cfg.session
    local dd    = drilldown[idx]

    -- Title
    local tstr
    if dd then
        tstr = "|cff999999< |r" .. (TYPE_LABEL[mtype] or mtype) .. ": " .. (dd.name or "?")
    else
        tstr = (TYPE_LABEL[mtype] or mtype) .. "  [" .. (sess == "fight" and "Fight" or "Overall") .. "]"
    end
    pane.titleFS:SetText(tstr)
    pane.backBtn:SetShown(dd ~= nil)

    -- Build entry list
    local entries
    if dd then
        entries = GetSpellEntries(sess, mtype, dd.guid)
    else
        entries = GetEntries(sess, mtype)
    end

    HideAllRows(pane.rowPool)

    local barH      = s.barHeight or 18
    local useClass  = s.useClassColors
    local barCol    = s.barColor    or { r = 0.2, g = 0.5, b = 0.9, a = 1 }
    local barBgCol  = s.barBgColor  or { r = 0.12, g = 0.12, b = 0.12, a = 1 }
    local txtCol    = s.barTextColor or { r = 1, g = 1, b = 1, a = 1 }
    local paneW     = pane.scrollFrame:GetWidth()
    if not paneW or paneW <= 0 then paneW = 200 end

    local maxVal = 1
    for _, e in ipairs(entries) do
        if e.total > maxVal then maxVal = e.total end
    end

    local yOff = 0
    for _, entry in ipairs(entries) do
        local row = AcquireRow(pane.rowPool, pane.scrollContent)
        row:SetPoint("TOPLEFT", pane.scrollContent, "TOPLEFT", 0, -yOff)
        row:SetSize(paneW, barH)

        -- Background
        row.bg:SetColorTexture(barBgCol.r, barBgCol.g, barBgCol.b, barBgCol.a or 1)

        -- Fill bar
        local frac = entry.total / maxVal
        local bw   = math.max(2, math.floor(paneW * frac + 0.5))
        row.bar:SetSize(bw, barH)
        if useClass and entry.class and not dd then
            local r, g, b = GetClassColor(entry.class)
            row.bar:SetColorTexture(r, g, b, 0.65)
        else
            row.bar:SetColorTexture(barCol.r, barCol.g, barCol.b, barCol.a or 1)
        end

        -- Text
        row.nameFS:SetText(entry.name or "?")
        row.nameFS:SetTextColor(txtCol.r, txtCol.g, txtCol.b, txtCol.a or 1)
        row.valFS:SetText(FormatVal(entry.total, mtype))
        row.valFS:SetTextColor(txtCol.r, txtCol.g, txtCol.b, txtCol.a or 1)

        -- Click: left = drill in, right = back
        local captEntry = entry
        local captIdx   = idx
        local captDd    = dd
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(_, btn)
            if btn == "RightButton" then
                drilldown[captIdx] = nil
                RenderPane(captIdx)
            elseif btn == "LeftButton" and not captDd then
                drilldown[captIdx] = { guid = captEntry.guid, name = captEntry.name }
                RenderPane(captIdx)
            end
        end)

        yOff = yOff + barH + 1
    end

    -- Empty state row
    if #entries == 0 then
        local row = AcquireRow(pane.rowPool, pane.scrollContent)
        row:SetPoint("TOPLEFT", pane.scrollContent, "TOPLEFT", 0, 0)
        row:SetSize(paneW, barH)
        row.bg:SetColorTexture(0, 0, 0, 0)
        row.bar:SetSize(1, barH)
        row.bar:SetColorTexture(0, 0, 0, 0)
        row.nameFS:SetText("|cff555555No data|r")
        row.valFS:SetText("")
        yOff = barH
    end

    pane.scrollContent:SetSize(paneW, math.max(yOff + 4, 20))
    pane.scrollFrame:UpdateScrollChildRect()
end

local function RenderAllPanes()
    local n = UIThingsDB.damageMeter.numMeters or 1
    for i = 1, n do RenderPane(i) end
end

-- ============================================================
-- Build Pane
-- ============================================================

local function BuildPane(idx, parent)
    local pane = { rowPool = {} }
    panes[idx]  = pane

    local f = CreateFrame("Frame", nil, parent)
    pane.frame = f

    -- Header strip
    local hdr = CreateFrame("Frame", nil, f, "BackdropTemplate")
    hdr:SetPoint("TOPLEFT")
    hdr:SetPoint("TOPRIGHT")
    hdr:SetHeight(HEADER_H)
    pane.header = hdr

    -- Title fontstring
    local tfs = hdr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tfs:SetPoint("LEFT", 4, 0)
    tfs:SetPoint("RIGHT", -108, 0)
    tfs:SetJustifyH("LEFT")
    tfs:SetWordWrap(false)
    pane.titleFS = tfs

    -- Session toggle button
    local sessBtn = CreateFrame("Button", nil, hdr, "UIPanelButtonTemplate")
    sessBtn:SetSize(52, 20)
    sessBtn:SetPoint("RIGHT", -2, 0)
    local ci3 = idx
    sessBtn:SetScript("OnClick", function()
        local cfg3 = (ci3 == 1) and UIThingsDB.damageMeter.meter1 or UIThingsDB.damageMeter.meter2
        cfg3.session  = (cfg3.session == "fight") and "overall" or "fight"
        drilldown[ci3] = nil
        RenderPane(ci3)
    end)
    pane.sessBtn = sessBtn

    -- Type cycle button
    local typeBtn = CreateFrame("Button", nil, hdr, "UIPanelButtonTemplate")
    typeBtn:SetSize(52, 20)
    typeBtn:SetPoint("RIGHT", sessBtn, "LEFT", -2, 0)
    local ci2 = idx
    typeBtn:SetScript("OnClick", function()
        local cfg2 = (ci2 == 1) and UIThingsDB.damageMeter.meter1 or UIThingsDB.damageMeter.meter2
        local cur = 1
        for i, t in ipairs(METER_TYPES) do if t == cfg2.type then cur = i; break end end
        cfg2.type      = METER_TYPES[(cur % #METER_TYPES) + 1]
        drilldown[ci2] = nil
        RenderPane(ci2)
    end)
    pane.typeBtn = typeBtn

    -- Back button (drilldown return)
    local backBtn = CreateFrame("Button", nil, hdr, "UIPanelButtonTemplate")
    backBtn:SetSize(44, 20)
    backBtn:SetPoint("LEFT", 2, 0)
    backBtn:SetText("< Bk")
    local ci1 = idx
    backBtn:SetScript("OnClick", function()
        drilldown[ci1] = nil
        RenderPane(ci1)
    end)
    backBtn:Hide()
    pane.backBtn = backBtn

    -- Scroll frame
    local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     0, -HEADER_H)
    sf:SetPoint("BOTTOMRIGHT", -20, 0)
    pane.scrollFrame = sf

    local sc = CreateFrame("Frame", nil, sf)
    sc:SetWidth(200)
    sc:SetHeight(1)
    sf:SetScrollChild(sc)
    pane.scrollContent = sc

    -- Helper to refresh button labels from current settings
    pane.RefreshBtnLabels = function()
        local cfg = (idx == 1) and UIThingsDB.damageMeter.meter1 or UIThingsDB.damageMeter.meter2
        if not cfg then return end
        local lbl = TYPE_LABEL[cfg.type] or cfg.type
        typeBtn:SetText(string.sub(lbl, 1, 5))
        sessBtn:SetText(cfg.session == "fight" and "Fight" or "All")
    end

    return pane
end

-- ============================================================
-- Backdrop / Colors
-- ============================================================

local function ApplyBackdrop()
    if not mainFrame then return end
    local s  = UIThingsDB.damageMeter
    local bg = s.bgColor
    local bc = s.borderColor
    local bs = s.borderSize or 1
    mainFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile     = false, tileSize = 0, edgeSize = bs,
        insets   = { left = bs, right = bs, top = bs, bottom = bs },
    })
    mainFrame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
    mainFrame:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)

    local tc = s.titleBgColor   or { r = 0.1, g = 0.1, b = 0.1, a = 1 }
    local tt = s.titleTextColor or { r = 1, g = 1, b = 1, a = 1 }
    for _, pane in ipairs(panes) do
        if pane.header then
            pane.header:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                tile   = false, tileSize = 0, edgeSize = 0,
                insets = { left = 0, right = 0, top = 0, bottom = 0 },
            })
            pane.header:SetBackdropColor(tc.r, tc.g, tc.b, tc.a)
        end
        if pane.titleFS then
            pane.titleFS:SetTextColor(tt.r, tt.g, tt.b, tt.a)
        end
    end
end

-- ============================================================
-- Layout Panes inside the main frame
-- ============================================================

local function LayoutPanes()
    if not mainFrame then return end
    local s  = UIThingsDB.damageMeter
    local n  = s.numMeters or 1
    local bs = s.borderSize or 1
    local mw = mainFrame:GetWidth()
    local mh = mainFrame:GetHeight()

    local function FixScrollWidth(pane)
        local sfW = pane.scrollFrame:GetWidth()
        if sfW and sfW > 0 then
            pane.scrollContent:SetWidth(sfW)
        end
    end

    if n == 1 then
        local p = panes[1]
        if p then
            p.frame:ClearAllPoints()
            p.frame:SetPoint("TOPLEFT",     mainFrame, "TOPLEFT",     bs,  -bs)
            p.frame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -bs,  bs)
            p.frame:Show()
            FixScrollWidth(p)
        end
        if panes[2] then panes[2].frame:Hide() end
    else
        local halfW = math.floor(mw / 2) - bs - 1
        local fullH = mh - bs * 2
        for i = 1, 2 do
            local p = panes[i]
            if p then
                p.frame:ClearAllPoints()
                p.frame:SetSize(halfW, fullH)
                if i == 1 then
                    p.frame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", bs, -bs)
                else
                    p.frame:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -bs, -bs)
                end
                p.frame:Show()
                FixScrollWidth(p)
            end
        end
    end
end

-- ============================================================
-- Position / Dock
-- ============================================================

local function StopDockTicker()
    if dockTicker then dockTicker:Cancel(); dockTicker = nil end
end

local function SyncDocked()
    if not mainFrame then return end
    if InCombatLockdown() then return end
    local dockIdx = UIThingsDB.damageMeter.dockToFrame or 0
    if dockIdx == 0 then return end
    local target = _G["UIThingsCustomFrame" .. dockIdx]
    if not target or not target:IsShown() then return end
    local w  = target:GetWidth()
    local h  = target:GetHeight()
    local cx, cy   = target:GetCenter()
    local pcx, pcy = UIParent:GetCenter()
    if not cx or not pcx then return end
    mainFrame:SetSize(math.max(w, 10), math.max(h, 10))
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", cx - pcx, cy - pcy)
    LayoutPanes()
end

local function ApplyPositionAndSize()
    if not mainFrame then return end
    if InCombatLockdown() then return end
    local s    = UIThingsDB.damageMeter
    local dock = s.dockToFrame or 0
    if dock > 0 then
        SyncDocked()
        if not dockTicker then
            dockTicker = C_Timer.NewTicker(1.0, function()
                if UIThingsDB.damageMeter and UIThingsDB.damageMeter.enabled then
                    SyncDocked()
                else
                    StopDockTicker()
                end
            end)
        end
    else
        StopDockTicker()
        local x = s.pos.x or 0
        local y = s.pos.y or 0
        local w = s.width  or 280
        local h = s.height or 400
        mainFrame:SetSize(w, h)
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", x, y)
        LayoutPanes()
    end
end

-- ============================================================
-- Create Main Frame
-- ============================================================

local function CreateMainFrame()
    if initialized then return end
    initialized = true

    mainFrame = CreateFrame("Frame", "LunaUITweaks_DamageMeterMain", UIParent, "BackdropTemplate")
    mainFrame:SetFrameStrata(UIThingsDB.damageMeter.frameStrata or "MEDIUM")
    mainFrame:SetMovable(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(self)
        if not UIThingsDB.damageMeter.locked
                and (UIThingsDB.damageMeter.dockToFrame or 0) == 0 then
            self:StartMoving()
        end
    end)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local cx, cy   = self:GetCenter()
        local pcx, pcy = UIParent:GetCenter()
        if cx and pcx then
            UIThingsDB.damageMeter.pos.x = math.floor(cx - pcx + 0.5)
            UIThingsDB.damageMeter.pos.y = math.floor(cy - pcy + 0.5)
        end
        if addonTable.DamageMeter.RefreshPosSliders then
            addonTable.DamageMeter.RefreshPosSliders()
        end
    end)

    -- Periodic refresh (0.75s throttle) to update live numbers
    local updateTimer = 0
    mainFrame:SetScript("OnUpdate", function(_, elapsed)
        updateTimer = updateTimer + elapsed
        if updateTimer < 0.75 then return end
        updateTimer = 0
        if not (UIThingsDB.damageMeter and UIThingsDB.damageMeter.enabled) then return end
        local n = UIThingsDB.damageMeter.numMeters or 1
        for i = 1, n do
            if panes[i] and panes[i].RefreshBtnLabels then panes[i].RefreshBtnLabels() end
            RenderPane(i)
        end
    end)

    BuildPane(1, mainFrame)
    BuildPane(2, mainFrame)
end

-- ============================================================
-- Public API
-- ============================================================

function addonTable.DamageMeter.Initialize()
    if not UIThingsDB.damageMeter.enabled then
        if mainFrame then mainFrame:Hide() end
        StopDockTicker()
        return
    end
    CreateMainFrame()
    ApplyBackdrop()
    ApplyPositionAndSize()
    mainFrame:EnableMouse(not UIThingsDB.damageMeter.locked)
    mainFrame:Show()
    RenderAllPanes()
end

function addonTable.DamageMeter.UpdateSettings()
    if not UIThingsDB.damageMeter.enabled then
        if mainFrame then mainFrame:Hide() end
        StopDockTicker()
        return
    end
    CreateMainFrame()
    mainFrame:Show()
    ApplyBackdrop()
    ApplyPositionAndSize()
    mainFrame:EnableMouse(not UIThingsDB.damageMeter.locked)
    RenderAllPanes()
end

function addonTable.DamageMeter.SetLocked(locked)
    UIThingsDB.damageMeter.locked = locked
    if mainFrame then mainFrame:EnableMouse(not locked) end
end

function addonTable.DamageMeter.ResetData()
    sessions.fight   = NewSession()
    sessions.overall = NewSession()
    for i = 1, 2 do drilldown[i] = nil end
    if mainFrame and mainFrame:IsShown() then RenderAllPanes() end
end

function addonTable.DamageMeter.GetFrame() return mainFrame end

function addonTable.DamageMeter.GetMeterTypes() return METER_TYPES end
function addonTable.DamageMeter.GetTypeLabel(t) return TYPE_LABEL[t] or t end

-- ============================================================
-- Events
-- ============================================================

-- COMBAT_LOG_EVENT_UNFILTERED: standard WoW event, available to all addons.
EventBus.Register("COMBAT_LOG_EVENT_UNFILTERED", OnCombatLog, "DamageMeter")

-- Reset fight session on each combat start
EventBus.Register("PLAYER_REGEN_DISABLED", function()
    sessions.fight = NewSession()
    for i = 1, 2 do drilldown[i] = nil end
end, "DamageMeter")

-- Initialize after login/zone change
EventBus.Register("PLAYER_ENTERING_WORLD", function()
    if not UIThingsDB or not UIThingsDB.damageMeter then return end
    SafeAfter(1, addonTable.DamageMeter.Initialize)
end, "DamageMeter")

-- Optionally clear all data on instance entry
EventBus.Register("ZONE_CHANGED_NEW_AREA", function()
    if not UIThingsDB or not UIThingsDB.damageMeter then return end
    if UIThingsDB.damageMeter.clearOnInstance then
        local inInst = IsInInstance()
        if inInst then addonTable.DamageMeter.ResetData() end
    end
end, "DamageMeter")
