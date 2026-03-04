-- DamageMeter.lua
-- Custom damage meter using the C_DamageMeter API (WoW 12.0+).
-- Data is pulled from Blizzard's built-in combat session store — no combat log parsing.

local addonName, addonTable = ...
addonTable.DamageMeter = {}

local EventBus  = addonTable.EventBus
local SafeAfter = addonTable.Core.SafeAfter
local Abbrev    = addonTable.Core.AbbreviateNumber

-- ============================================================
-- Constants
-- ============================================================

local METER_TYPES = {
    "damage", "healing", "interrupts", "deaths", "dispels", "damageTaken",
}

local TYPE_LABEL = {
    damage      = "Damage",
    healing     = "Healing",
    interrupts  = "Interrupts",
    deaths      = "Deaths",
    dispels     = "Dispels",
    damageTaken = "Dmg Taken",
}

-- Maps our keys to Enum.DamageMeterType field names
local ENUM_NAMES = {
    damage      = "DamageDone",
    healing     = "HealingDone",
    damageTaken = "DamageTaken",
    interrupts  = "Interrupts",
    dispels     = "Dispels",
    deaths      = "Deaths",
}

-- ============================================================
-- Data Layer (C_DamageMeter API)
-- ============================================================

-- overallBaseIdx: sessions at-or-below this index are excluded from "overall" view.
-- Reset to #sessions at ResetData() time.
local overallBaseIdx = 0

-- Short-lived cache so repeated renders in the same frame don't re-query the API.
local entryCache = {}   -- [cacheKey] = { entries, expiry }
local CACHE_TTL  = 1.0

-- DPS computation: track fight durations using combat events.
-- "fight" DPS uses lastFightDuration; "overall" DPS sums sessionDurations.
local fightStartTime   = nil
local lastFightDuration = 0
local sessionDurations  = {}   -- durations (seconds) of all fights after last ResetData()

local DPS_TYPES = { damage = true, healing = true, damageTaken = true }

local function GetOverallDuration()
    local total = 0
    for _, d in ipairs(sessionDurations) do total = total + d end
    return total
end

local function SafeVal(v)
    if issecretvalue and issecretvalue(v) then return 0 end
    return type(v) == "number" and v or 0
end

local function GetEnumType(mtype)
    local name = ENUM_NAMES[mtype]
    if not name then return nil end
    return Enum.DamageMeterType and Enum.DamageMeterType[name]
end

local function GetSessions()
    local ok, list = pcall(C_DamageMeter.GetAvailableCombatSessions)
    if ok and list then return list end
    return {}
end

-- Returns a sorted array of { guid, name, class, total } for the given view.
local function FetchEntries(sessKey, mtype)
    local cacheKey = sessKey .. "|" .. mtype
    local cached   = entryCache[cacheKey]
    if cached and GetTime() < cached.expiry then
        return cached.entries
    end

    local enumType = GetEnumType(mtype)
    if not enumType then return {} end

    local byGuid = {}

    local function AccumulateSources(combatSources)
        for _, src in ipairs(combatSources or {}) do
            local guid = src.sourceGUID
            local name = src.name
            -- Both GUID and name are secret values during live combat — skip if so
            if guid and name
                    and not (issecretvalue and issecretvalue(guid))
                    and not (issecretvalue and issecretvalue(name)) then
                local amt      = SafeVal(src.totalAmount)
                local existing = byGuid[guid]
                if existing then
                    existing.total = existing.total + amt
                else
                    byGuid[guid] = {
                        guid  = guid,
                        name  = name,
                        class = src.classFilename,
                        total = amt,
                    }
                end
            end
        end
    end

    if sessKey == "fight" then
        -- During combat the live session data is fully secret — skip it and show last
        -- finalized session instead.  After combat, sessionType 1 returns readable data.
        if not InCombatLockdown() then
            local ok, sessData = pcall(C_DamageMeter.GetCombatSessionFromType, 1, enumType)
            if ok and sessData and sessData.combatSources then
                AccumulateSources(sessData.combatSources)
            end
        end
        -- Fallback: last finalized session (used during combat or when no current session)
        if next(byGuid) == nil then
            local sessions = GetSessions()
            if #sessions > 0 then
                local ok2, sessData2 = pcall(C_DamageMeter.GetCombatSessionFromID, sessions[#sessions].sessionID, enumType)
                if ok2 and sessData2 then
                    if not (sessData2.totalAmount ~= nil and issecretvalue and issecretvalue(sessData2.totalAmount)) then
                        AccumulateSources(sessData2.combatSources)
                    end
                end
            end
        end
    else
        local sessions = GetSessions()
        for i = overallBaseIdx + 1, #sessions do
            local ok, sessData = pcall(C_DamageMeter.GetCombatSessionFromID, sessions[i].sessionID, enumType)
            if ok and sessData then
                if not (sessData.totalAmount ~= nil and issecretvalue and issecretvalue(sessData.totalAmount)) then
                    AccumulateSources(sessData.combatSources)
                end
            end
        end
    end

    local list = {}
    for _, d in pairs(byGuid) do
        if d.total > 0 then list[#list + 1] = d end
    end
    table.sort(list, function(a, b) return a.total > b.total end)

    entryCache[cacheKey] = { entries = list, expiry = GetTime() + CACHE_TTL }
    return list
end

-- Returns a sorted array of { spellId, name, total } for one source's spell breakdown.
local function FetchSpellEntries(sessKey, mtype, guid)
    local enumType = GetEnumType(mtype)
    if not enumType then return {} end

    local bySpell = {}

    local function AccumulateSpells(combatSpells)
        for _, sp in ipairs(combatSpells or {}) do
            local amt = SafeVal(sp.totalAmount)
            -- Count-based types (interrupts/dispels/deaths) use casts as the value
            if amt == 0 then amt = SafeVal(sp.casts) end
            if sp.spellID and amt > 0 then
                local existing = bySpell[sp.spellID]
                if existing then
                    existing.total = existing.total + amt
                else
                    local spellName = sp.name
                    if not spellName or spellName == "" then
                        local ok2, n = pcall(C_Spell.GetSpellName, sp.spellID)
                        spellName = (ok2 and n) or ("Spell " .. sp.spellID)
                    end
                    bySpell[sp.spellID] = { spellId = sp.spellID, name = spellName, total = amt }
                end
            end
        end
    end

    if sessKey == "fight" then
        -- During combat the live session data is fully secret — use last finalized instead.
        if not InCombatLockdown() then
            local ok, srcData = pcall(C_DamageMeter.GetCombatSessionSourceFromType, 1, enumType, guid)
            if ok and srcData then
                AccumulateSpells(srcData.combatSpells)
            end
        end
        if next(bySpell) == nil then
            local sessions = GetSessions()
            if #sessions > 0 then
                local ok2, srcData2 = pcall(C_DamageMeter.GetCombatSessionSourceFromID, sessions[#sessions].sessionID, enumType, guid)
                if ok2 and srcData2 then AccumulateSpells(srcData2.combatSpells) end
            end
        end
    else
        local sessions = GetSessions()
        for i = overallBaseIdx + 1, #sessions do
            local ok, srcData = pcall(C_DamageMeter.GetCombatSessionSourceFromID, sessions[i].sessionID, enumType, guid)
            if ok and srcData then AccumulateSpells(srcData.combatSpells) end
        end
    end

    local list = {}
    for _, sp in pairs(bySpell) do
        if sp.total > 0 then list[#list + 1] = sp end
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

local mainFrame   = nil
local panes       = {}
local drilldown   = {}   -- drilldown[idx] = { guid, name } or nil
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
    row.dpsFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.dpsFS:SetPoint("BOTTOMRIGHT", -4, 2)
    row.dpsFS:SetJustifyH("RIGHT")
    row.dpsFS:Hide()
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
        entries = FetchSpellEntries(sess, mtype, dd.guid)
    else
        entries = FetchEntries(sess, mtype)
    end

    HideAllRows(pane.rowPool)

    local barH     = s.barHeight or 18
    local useClass = s.useClassColors
    local barCol   = s.barColor     or { r = 0.2, g = 0.5, b = 0.9, a = 1 }
    local barBgCol = s.barBgColor   or { r = 0.12, g = 0.12, b = 0.12, a = 1 }
    local txtCol   = s.barTextColor or { r = 1, g = 1, b = 1, a = 1 }
    local paneW    = pane.scrollFrame:GetWidth()
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

        row.bg:SetColorTexture(barBgCol.r, barBgCol.g, barBgCol.b, barBgCol.a or 1)

        local frac = entry.total / maxVal
        local bw   = math.max(2, math.floor(paneW * frac + 0.5))
        row.bar:SetSize(bw, barH)
        if useClass and entry.class and not dd then
            local r, g, b = GetClassColor(entry.class)
            row.bar:SetColorTexture(r, g, b, 0.65)
        else
            row.bar:SetColorTexture(barCol.r, barCol.g, barCol.b, barCol.a or 1)
        end

        row.nameFS:SetText(entry.name or "?")
        row.nameFS:SetTextColor(txtCol.r, txtCol.g, txtCol.b, txtCol.a or 1)
        row.valFS:SetText(FormatVal(entry.total, mtype))
        row.valFS:SetTextColor(txtCol.r, txtCol.g, txtCol.b, txtCol.a or 1)

        -- DPS sub-label (bottom-right, dimmed)
        if s.showDps and DPS_TYPES[mtype] and not dd and row.dpsFS and barH >= 28 then
            local dur = (sess == "fight") and lastFightDuration or GetOverallDuration()
            if dur > 0 then
                local dps = entry.total / dur
                row.dpsFS:SetText(Abbrev(dps) .. "/s")
                row.dpsFS:SetTextColor(txtCol.r, txtCol.g, txtCol.b, 0.6)
                row.dpsFS:Show()
            else
                row.dpsFS:Hide()
            end
        elseif row.dpsFS then
            row.dpsFS:Hide()
        end

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

    -- Empty state
    if #entries == 0 then
        local row = AcquireRow(pane.rowPool, pane.scrollContent)
        row:SetPoint("TOPLEFT", pane.scrollContent, "TOPLEFT", 0, 0)
        row:SetSize(paneW, barH)
        row.bg:SetColorTexture(0, 0, 0, 0)
        row.bar:SetSize(1, barH)
        row.bar:SetColorTexture(0, 0, 0, 0)
        row.nameFS:SetText("|cff555555No data|r")
        row.valFS:SetText("")
        if row.dpsFS then row.dpsFS:Hide() end
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
        entryCache = {}
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
        entryCache = {}
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
                    p.frame:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",  bs,  -bs)
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
    local w        = target:GetWidth()
    local h        = target:GetHeight()
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

    -- Periodic refresh (0.75s) to keep live numbers up to date
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
    local sessions = GetSessions()
    overallBaseIdx = #sessions
    entryCache = {}
    lastFightDuration = 0
    sessionDurations  = {}
    fightStartTime    = nil
    for i = 1, 2 do drilldown[i] = nil end
    if mainFrame and mainFrame:IsShown() then RenderAllPanes() end
end

function addonTable.DamageMeter.GetFrame() return mainFrame end
function addonTable.DamageMeter.GetMeterTypes() return METER_TYPES end
function addonTable.DamageMeter.GetTypeLabel(t) return TYPE_LABEL[t] or t end

-- ============================================================
-- Events
-- ============================================================

-- Invalidate cache when combat ends — session data is now finalised
EventBus.Register("PLAYER_REGEN_ENABLED", function()
    entryCache = {}
    -- Record fight duration for DPS computation
    if fightStartTime then
        lastFightDuration = math.max(1, GetTime() - fightStartTime)
        table.insert(sessionDurations, lastFightDuration)
        fightStartTime = nil
    end
    -- Clear fight drilldown: old fight is done, next click is a fresh session
    for i = 1, 2 do
        local cfg = (i == 1) and UIThingsDB.damageMeter.meter1 or UIThingsDB.damageMeter.meter2
        if cfg and cfg.session == "fight" then drilldown[i] = nil end
    end
end, "DamageMeter")

EventBus.Register("PLAYER_REGEN_DISABLED", function()
    fightStartTime = GetTime()
end, "DamageMeter")



EventBus.Register("PLAYER_ENTERING_WORLD", function()
    if not UIThingsDB or not UIThingsDB.damageMeter then return end
    entryCache = {}
    SafeAfter(1, addonTable.DamageMeter.Initialize)
end, "DamageMeter")

EventBus.Register("ZONE_CHANGED_NEW_AREA", function()
    if not UIThingsDB or not UIThingsDB.damageMeter then return end
    if UIThingsDB.damageMeter.clearOnInstance then
        local inInst = IsInInstance()
        if inInst then addonTable.DamageMeter.ResetData() end
    end
end, "DamageMeter")
