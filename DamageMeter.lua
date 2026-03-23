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

local SESSION_LABELS = {
    segment = "Seg",
    current = "Cur",
    overall = "All",
    fight   = "Seg",   -- legacy alias
}

local SESSION_FULL = {
    segment = "Segment",
    current = "Current",
    overall = "All",
    fight   = "Segment",
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
local CACHE_TTL  = 0.5

-- DPS computation: track fight durations using combat events.
-- "fight" DPS uses lastFightDuration; "overall" DPS sums sessionDurations.
local fightStartTime   = nil
local lastFightDuration = 0
local sessionDurations    = {}  -- durations (seconds) of all fights after last ResetData()
local sessionDurationByID = {}  -- [sessionID] = duration in seconds
local sessionNameByID     = {}  -- [sessionID] = encounter/combat name (if readable)

local DPS_TYPES   = { damage = true, healing = true, damageTaken = true }
local COUNT_TYPES = { interrupts = true, deaths = true, dispels = true }

local function GetOverallDuration()
    local total = 0
    for _, d in ipairs(sessionDurations) do total = total + d end
    return total
end

local function SafeVal(v)
    -- Secret values are allowed in arithmetic/display — only table keys are restricted.
    -- Don't gate on issecretvalue here; just ensure we have a number.
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
            -- guid/name may be secret during live combat but are safe as table keys/display values.
            -- Only totalAmount needs SafeVal (arithmetic on secret numbers returns garbage).
            if guid and name then
                local amt      = SafeVal(src.totalAmount)
                -- Count-based types (interrupts/dispels/deaths) may store count in casts, not totalAmount
                if amt == 0 and COUNT_TYPES[mtype] then amt = SafeVal(src.casts) end
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

    local liveMode = false
    if sessKey == "current" then
        if InCombatLockdown() then
            -- Live combat: sourceGUID/name/totalAmount/maxAmount are all secret values.
            -- Store in byGuid with integer keys; liveMode=true tells the render path to
            -- skip Lua sorting/arithmetic and use only C-level calls on the secret values.
            local ok, sessData = pcall(C_DamageMeter.GetCombatSessionFromType, 1, enumType)
            if ok and sessData and sessData.combatSources then
                liveMode = true
                for i, src in ipairs(sessData.combatSources) do
                    -- All live combat fields are secret — never compare, copy to table only for
                    -- C-level calls (SetValue/SetMinMaxValues/SetText/string.format).
                    -- type() is safe on secrets; comparison operators are NOT.
                    if type(src.totalAmount) == "number" or (COUNT_TYPES[mtype] and type(src.casts) == "number") then
                        local displayName
                        if src.isLocalPlayer then
                            displayName = UnitName("player")
                        else
                            displayName = UnitName(src.name) or src.classFilename or "Unknown"
                        end
                        -- For count-based types, prefer casts over totalAmount.
                        -- We store the source ref directly so the render path can read the
                        -- original secret fields without any Lua-level comparison.
                        byGuid[i] = {
                            guid     = src.sourceGUID,
                            name     = displayName,
                            class    = src.classFilename,
                            src      = src,          -- original API source (secret fields)
                            sessMax  = sessData.maxAmount, -- secret, for SetMinMaxValues
                            isCount  = COUNT_TYPES[mtype] or false,
                        }
                    end
                end
            end
        else
            -- Post-combat: use the last finalized session by ID — always clean, non-tainted.
            -- GetCombatSessionFromType can still return tainted values briefly after combat
            -- ends (before restrictions lift), so GetCombatSessionFromID is the safe path.
            local sessions = GetSessions()
            if #sessions > 0 then
                local sid = sessions[#sessions].sessionID
                local ok, sessData = pcall(C_DamageMeter.GetCombatSessionFromID, sid, enumType)
                if ok and sessData then
                    AccumulateSources(sessData.combatSources)
                end
            end
        end
    elseif sessKey == "overall" then
        local sessions = GetSessions()
        for i = overallBaseIdx + 1, #sessions do
            local ok, sessData = pcall(C_DamageMeter.GetCombatSessionFromID, sessions[i].sessionID, enumType)
            if ok and sessData then
                if not (sessData.totalAmount ~= nil and issecretvalue and issecretvalue(sessData.totalAmount)) then
                    AccumulateSources(sessData.combatSources)
                end
            end
        end
    else
        -- Specific sessionID (number) or legacy "segment"/"fight" aliases
        local sid
        if type(sessKey) == "number" then
            sid = sessKey
        elseif sessKey == "segment" or sessKey == "fight" then
            local sessions = GetSessions()
            if #sessions > 0 then sid = sessions[#sessions].sessionID end
        end
        if sid then
            local ok, sessData = pcall(C_DamageMeter.GetCombatSessionFromID, sid, enumType)
            if ok and sessData then
                if not (sessData.totalAmount ~= nil and issecretvalue and issecretvalue(sessData.totalAmount)) then
                    AccumulateSources(sessData.combatSources)
                end
            end
        end
    end

    local list = {}
    if liveMode then
        -- byGuid has sequential integer keys; ipairs preserves API sort order.
        -- Secret values can't be compared so we skip re-sorting.
        for i = 1, #byGuid do
            local d = byGuid[i]
            if d then list[#list + 1] = d end
        end
    else
        for _, d in pairs(byGuid) do
            if d.total > 0 then list[#list + 1] = d end
        end
        table.sort(list, function(a, b) return a.total > b.total end)
    end

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
                        -- C_Spell.GetSpellName uses async data; returns "" if not yet cached.
                        -- Fall back to legacy synchronous GetSpellInfo which always resolves.
                        local ok2, n = pcall(C_Spell.GetSpellName, sp.spellID)
                        if ok2 and n and n ~= "" then
                            spellName = n
                        else
                            spellName = GetSpellInfo(sp.spellID) or ("Spell " .. sp.spellID)
                        end
                    end
                    bySpell[sp.spellID] = { spellId = sp.spellID, name = spellName, total = amt }
                end
            end
        end
    end

    if sessKey == "current" then
        local ok, srcData = pcall(C_DamageMeter.GetCombatSessionSourceFromType, 1, enumType, guid)
        if ok and srcData then
            AccumulateSpells(srcData.combatSpells)
        end
    elseif sessKey == "overall" then
        local sessions = GetSessions()
        for i = overallBaseIdx + 1, #sessions do
            local ok, srcData = pcall(C_DamageMeter.GetCombatSessionSourceFromID, sessions[i].sessionID, enumType, guid)
            if ok and srcData then AccumulateSpells(srcData.combatSpells) end
        end
    else
        local sid
        if type(sessKey) == "number" then
            sid = sessKey
        elseif sessKey == "segment" or sessKey == "fight" then
            local sessions = GetSessions()
            if #sessions > 0 then sid = sessions[#sessions].sessionID end
        end
        if sid then
            local ok, srcData = pcall(C_DamageMeter.GetCombatSessionSourceFromID, sid, enumType, guid)
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
    -- StatusBar lets us use SetMinMaxValues/SetValue with secret numbers (no Lua arithmetic needed)
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetStatusBarTexture("Interface/Buttons/WHITE8x8")
    row.bar:SetPoint("TOPLEFT")
    row.bar:SetPoint("BOTTOMRIGHT")
    row.nameFS = row.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.nameFS:SetPoint("LEFT", row.bar, "LEFT", 4, 0)
    row.nameFS:SetPoint("RIGHT", row.bar, "RIGHT", -50, 0)
    row.nameFS:SetJustifyH("LEFT")
    row.nameFS:SetWordWrap(false)
    row.valFS = row.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.valFS:SetPoint("RIGHT", row.bar, "RIGHT", -4, 0)
    row.valFS:SetJustifyH("RIGHT")
    row.dpsFS = row.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.dpsFS:SetPoint("BOTTOMRIGHT", row.bar, "BOTTOMRIGHT", -4, 2)
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
        local sessLabel
        if type(sess) == "number" then
            local dur = sessionDurationByID[sess]
            local durStr = dur and string.format(" [%02d:%02d]", math.floor(dur / 60), dur % 60) or ""
            sessLabel = (sessionNameByID[sess] or "Segment") .. durStr
        elseif sess == "current" then
            sessLabel = "Current"
        elseif sess == "overall" then
            sessLabel = "All"
        else
            sessLabel = SESSION_FULL[sess] or "Segment"
        end
        tstr = (TYPE_LABEL[mtype] or mtype) .. "  [" .. sessLabel .. "]"
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

    -- ── Live combat path ────────────────────────────────────────────────────
    -- For sess=="current" during combat: render directly from sessData so that
    -- secret values (totalAmount, maxAmount) stay as Blizzard-tainted locals
    -- and are NEVER copied into our own Lua table.  Blizzard-tainted values
    -- allow arithmetic and can be passed to WoW API calls (SetValue, Abbrev/
    -- string.format); LunaUITweaks-tainted copies (from our table) do not.
    -- ─────────────────────────────────────────────────────────────────────────
    if sess == "current" and not dd and InCombatLockdown() then
        local enumType = GetEnumType(mtype)
        local yOff = 0
        local hasRows = false
        if enumType then
            local ok, sessData = pcall(C_DamageMeter.GetCombatSessionFromType, 1, enumType)
            if ok and sessData and sessData.combatSources then
                for i, src in ipairs(sessData.combatSources) do
                    local row = AcquireRow(pane.rowPool, pane.scrollContent)
                    row:SetPoint("TOPLEFT", pane.scrollContent, "TOPLEFT", 0, -yOff)
                    row:SetSize(paneW, barH)
                    row.bg:SetColorTexture(barBgCol.r, barBgCol.g, barBgCol.b, barBgCol.a or 1)

                    -- All live combat values are secret — use C-level calls only (no Lua comparisons).
                    -- For count-based types, prefer casts; for DPS types, use totalAmount.
                    local srcAmt, srcMax
                    if COUNT_TYPES[mtype] and type(src.casts) == "number" then
                        srcAmt = src.casts
                    else
                        srcAmt = src.totalAmount
                    end
                    srcMax = sessData.maxAmount

                    -- Bar: SetMinMaxValues/SetValue accept secret values (C-level calls).
                    -- This taints StatusBar geometry but we never call UpdateScrollChildRect.
                    row.bar:SetMinMaxValues(0, srcMax)
                    row.bar:SetValue(srcAmt)
                    if useClass and src.classFilename then
                        local r, g, b = GetClassColor(src.classFilename)
                        row.bar:SetStatusBarColor(r, g, b, 0.65)
                    else
                        row.bar:SetStatusBarColor(barCol.r, barCol.g, barCol.b, barCol.a or 1)
                    end

                    -- Name: resolve via UnitName (accepts secret strings)
                    local displayName
                    if src.isLocalPlayer then
                        displayName = UnitName("player")
                    else
                        displayName = UnitName(src.name) or src.classFilename or "?"
                    end
                    row.nameFS:SetText(displayName or "?")
                    row.nameFS:SetTextColor(txtCol.r, txtCol.g, txtCol.b, txtCol.a or 1)

                    -- Values: AbbreviateNumbers is a C-level WoW function — no Lua comparison,
                    -- handles secret/tainted values. string.format("%d") also safe for counts.
                    -- Concatenate into valFS (same as post-combat path) to avoid overlap with dpsFS.
                    local valText
                    if COUNT_TYPES[mtype] then
                        valText = string.format("%d", srcAmt)
                    else
                        valText = AbbreviateNumbers(src.totalAmount)
                        if DPS_TYPES[mtype] then
                            valText = valText .. "  |cffaaaaaa" .. AbbreviateNumbers(src.amountPerSecond) .. "/s|r"
                        end
                    end
                    row.valFS:SetText(valText)
                    row.valFS:SetTextColor(txtCol.r, txtCol.g, txtCol.b, txtCol.a or 1)
                    if row.dpsFS then row.dpsFS:Hide() end

                    -- Drilldown: store src reference so guid stays as a table value
                    local captSrc = src
                    local captName = displayName
                    local captIdx = idx
                    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                    row:SetScript("OnClick", function(_, btn)
                        if btn == "RightButton" then
                            drilldown[captIdx] = nil
                            RenderPane(captIdx)
                        elseif btn == "LeftButton" then
                            drilldown[captIdx] = { guid = captSrc.sourceGUID, name = captName }
                            RenderPane(captIdx)
                        end
                    end)

                    yOff = yOff + barH + 1
                    hasRows = true
                end
            end
        end
        if not hasRows then
            local row = AcquireRow(pane.rowPool, pane.scrollContent)
            row:SetPoint("TOPLEFT", pane.scrollContent, "TOPLEFT", 0, 0)
            row:SetSize(paneW, barH)
            row.bg:SetColorTexture(0, 0, 0, 0)
            row.bar:SetMinMaxValues(0, 1) row.bar:SetValue(0)
            row.bar:SetStatusBarColor(0, 0, 0, 0)
            row.nameFS:SetText("|cff555555No data|r")
            row.valFS:SetText("")
            if row.dpsFS then row.dpsFS:Hide() end
            yOff = barH
        end
        -- Do NOT call scrollContent:SetSize() here — it triggers OnSizeChanged on the
        -- UIPanelScrollFrameTemplate, which calls UpdateScrollChildRect, which reads
        -- StatusBar geometry tainted by SetValue(secretValue) and throws
        -- "numeric conversion on secret number value". Rows are already visible via
        -- SetPoint. ADDON_RESTRICTION_STATE_CHANGED re-renders cleanly after combat ends.
        return
    end

    -- ── Post-combat / historical path ────────────────────────────────────────
    -- Non-secret values; arithmetic and comparison work normally.
    local maxVal = (#entries > 0 and entries[1].total) or 1

    local yOff = 0
    for _, entry in ipairs(entries) do
        local row = AcquireRow(pane.rowPool, pane.scrollContent)
        row:SetPoint("TOPLEFT", pane.scrollContent, "TOPLEFT", 0, -yOff)
        row:SetSize(paneW, barH)

        row.bg:SetColorTexture(barBgCol.r, barBgCol.g, barBgCol.b, barBgCol.a or 1)

        row.bar:SetMinMaxValues(0, maxVal)
        row.bar:SetValue(entry.total)
        if useClass and entry.class and not dd then
            local r, g, b = GetClassColor(entry.class)
            row.bar:SetStatusBarColor(r, g, b, 0.65)
        else
            row.bar:SetStatusBarColor(barCol.r, barCol.g, barCol.b, barCol.a or 1)
        end

        row.nameFS:SetText(entry.name or "?")
        row.nameFS:SetTextColor(txtCol.r, txtCol.g, txtCol.b, txtCol.a or 1)

        local valText = FormatVal(entry.total, mtype)
        if DPS_TYPES[mtype] and not dd then
            local dur
            if sess == "overall" then
                dur = GetOverallDuration()
            elseif type(sess) == "number" then
                dur = sessionDurationByID[sess] or lastFightDuration
            else
                dur = lastFightDuration
            end
            if dur > 0 then
                valText = valText .. "  |cffaaaaaa" .. Abbrev(entry.total / dur) .. "/s|r"
            end
        end
        row.valFS:SetText(valText)
        row.valFS:SetTextColor(txtCol.r, txtCol.g, txtCol.b, txtCol.a or 1)
        if row.dpsFS then row.dpsFS:Hide() end

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
        row.bar:SetMinMaxValues(0, 1) row.bar:SetValue(0)
        row.bar:SetStatusBarColor(0, 0, 0, 0)
        row.nameFS:SetText("|cff555555No data|r")
        row.valFS:SetText("")
        if row.dpsFS then row.dpsFS:Hide() end
        yOff = barH
    end

    pane.scrollContent:SetSize(paneW, math.max(yOff + 4, 20))
    -- Do NOT call UpdateScrollChildRect — StatusBar geometry is tainted during live combat
    -- renders (SetValue with secret values), and that taint persists on the frame objects.
    -- UpdateScrollChildRect reads child geometry and fails with "numeric conversion on
    -- secret number value" even in the post-combat path.  scrollContent:SetSize() triggers
    -- OnSizeChanged which updates the scroll range automatically via UIPanelScrollFrame.
end

local function RenderAllPanes()
    local n = UIThingsDB.damageMeter.numMeters or 1
    for i = 1, n do RenderPane(i) end
end

-- ============================================================
-- Session Context Menu
-- ============================================================

local sessMenuFrame   = nil
local sessMenuBtnPool = {}

local RADIO_ON  = "*"
local RADIO_OFF = "-"

local function AcquireSessMenuBtn()
    for _, btn in ipairs(sessMenuBtnPool) do
        if not btn:IsShown() then
            btn:Show()
            return btn
        end
    end
    local btn = CreateFrame("Button", nil, sessMenuFrame)
    btn:SetHeight(22)
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    local dot = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dot:SetPoint("LEFT", 4, 0)
    dot:SetWidth(14)
    dot:SetJustifyH("LEFT")
    btn.dot = dot
    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", dot, "RIGHT", 2, 0)
    fs:SetPoint("RIGHT", -4, 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    btn.fs = fs
    sessMenuBtnPool[#sessMenuBtnPool + 1] = btn
    return btn
end

local function SetupSessBtn(btn, sessionVal, label, isSelected, menuW)
    btn:SetWidth(menuW)
    btn.dot:SetText(isSelected and RADIO_ON or RADIO_OFF)
    btn.dot:SetTextColor(isSelected and 1 or 0.45, isSelected and 0.8 or 0.45, isSelected and 0 or 0.45)
    btn.fs:SetText(label)
    btn.fs:SetTextColor(isSelected and 1 or 0.85, isSelected and 0.85 or 0.85, isSelected and 0.85 or 0.85)
    btn:SetScript("OnClick", function()
        local pidx = sessMenuFrame.paneIdx
        local cfg = (pidx == 1) and UIThingsDB.damageMeter.meter1 or UIThingsDB.damageMeter.meter2
        cfg.session = sessionVal
        drilldown[pidx] = nil
        entryCache = {}
        RenderPane(pidx)
        if panes[pidx] and panes[pidx].RefreshBtnLabels then
            panes[pidx].RefreshBtnLabels()
        end
        sessMenuFrame:Hide()
    end)
end

local function RebuildSessionMenu(paneIdx)
    for _, btn in ipairs(sessMenuBtnPool) do btn:Hide() end

    local cfg         = (paneIdx == 1) and UIThingsDB.damageMeter.meter1 or UIThingsDB.damageMeter.meter2
    local currentSess = cfg.session
    local menuW       = sessMenuFrame:GetWidth() - 6
    local sessions    = GetSessions()
    local yOff        = 3
    local count       = 0

    -- Past sessions, newest first
    for i = #sessions, overallBaseIdx + 1, -1 do
        local sess = sessions[i]
        local sid  = sess.sessionID
        -- Try reading a name from the session object itself
        local rawName = sess.name
        if rawName and issecretvalue and issecretvalue(rawName) then rawName = nil end
        local dur    = sessionDurationByID[sid]
        local durStr = dur and string.format(" [%02d:%02d]", math.floor(dur / 60), dur % 60) or " [--:--]"
        local name   = (rawName and rawName ~= "") and rawName
                       or sessionNameByID[sid]
                       or ("Combat " .. count + 1)
        local btn = AcquireSessMenuBtn()
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", 3, -yOff)
        SetupSessBtn(btn, sid, name .. durStr, currentSess == sid, menuW)
        yOff  = yOff + 23
        count = count + 1
    end

    -- Divider
    if count > 0 then
        sessMenuFrame.divider:ClearAllPoints()
        sessMenuFrame.divider:SetPoint("TOPLEFT",  4, -(yOff + 2))
        sessMenuFrame.divider:SetPoint("TOPRIGHT", -4, -(yOff + 2))
        sessMenuFrame.divider:Show()
        yOff = yOff + 7
    else
        sessMenuFrame.divider:Hide()
    end

    -- "Current Segment"
    local curBtn = AcquireSessMenuBtn()
    curBtn:ClearAllPoints()
    curBtn:SetPoint("TOPLEFT", 3, -yOff)
    SetupSessBtn(curBtn, "current", "Current Segment", currentSess == "current", menuW)
    yOff = yOff + 23

    -- "Overall"
    local allBtn = AcquireSessMenuBtn()
    allBtn:ClearAllPoints()
    allBtn:SetPoint("TOPLEFT", 3, -yOff)
    SetupSessBtn(allBtn, "overall", "Overall", currentSess == "overall", menuW)
    yOff = yOff + 23

    sessMenuFrame:SetHeight(yOff + 3)
end

local function ShowSessionMenu(paneIdx, anchorBtn)
    if not sessMenuFrame then
        local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        menu:SetWidth(190)
        menu:SetHeight(74)
        menu:SetFrameStrata("TOOLTIP")
        menu:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        menu:SetBackdropColor(0.08, 0.08, 0.08, 0.96)
        menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        menu:SetClampedToScreen(true)
        menu:EnableMouse(true)
        local div = menu:CreateTexture(nil, "OVERLAY")
        div:SetHeight(1)
        div:SetColorTexture(0.35, 0.35, 0.35, 0.8)
        div:Hide()
        menu.divider = div
        menu:Hide()
        sessMenuFrame = menu
    end

    -- Toggle: hide if already showing for this pane
    if sessMenuFrame:IsShown() and sessMenuFrame.paneIdx == paneIdx then
        sessMenuFrame:Hide()
        return
    end

    sessMenuFrame.paneIdx = paneIdx
    RebuildSessionMenu(paneIdx)
    sessMenuFrame:ClearAllPoints()
    sessMenuFrame:SetPoint("TOPRIGHT", anchorBtn, "BOTTOMRIGHT", 0, -2)
    sessMenuFrame:Show()
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
    sessBtn:SetScript("OnClick", function(self)
        ShowSessionMenu(ci3, self)
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
        local sl
        if type(cfg.session) == "number" then
            sl = "Seg"
        elseif cfg.session == "current" then
            sl = "Cur"
        else
            sl = "All"
        end
        sessBtn:SetText(sl)
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

local RegisterEvents, UnregisterEvents  -- forward declarations (defined in Events section below)

function addonTable.DamageMeter.Initialize()
    if not UIThingsDB.damageMeter.enabled then
        if mainFrame then mainFrame:Hide() end
        StopDockTicker()
        UnregisterEvents()
        return
    end
    RegisterEvents()
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
        UnregisterEvents()
        return
    end
    RegisterEvents()
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
    entryCache          = {}
    lastFightDuration   = 0
    sessionDurations    = {}
    sessionDurationByID = {}
    sessionNameByID     = {}
    fightStartTime      = nil
    for i = 1, 2 do drilldown[i] = nil end
    if mainFrame and mainFrame:IsShown() then RenderAllPanes() end
end

function addonTable.DamageMeter.GetFrame() return mainFrame end
function addonTable.DamageMeter.GetMeterTypes() return METER_TYPES end
function addonTable.DamageMeter.GetTypeLabel(t) return TYPE_LABEL[t] or t end

-- ============================================================
-- Events
-- ============================================================

local eventsRegistered = false

local function OnRegenEnabled()
    entryCache = {}
    if fightStartTime then
        lastFightDuration = math.max(1, GetTime() - fightStartTime)
        table.insert(sessionDurations, lastFightDuration)
        local dur = lastFightDuration
        SafeAfter(0.1, function()
            local sessions = GetSessions()
            if #sessions > 0 then
                local last = sessions[#sessions]
                local sid  = last.sessionID
                sessionDurationByID[sid] = dur
                local rawName = last.name
                if rawName and not (issecretvalue and issecretvalue(rawName)) and rawName ~= "" then
                    sessionNameByID[sid] = rawName
                end
            end
        end)
        fightStartTime = nil
    end
    for i = 1, 2 do
        local cfg = (i == 1) and UIThingsDB.damageMeter.meter1 or UIThingsDB.damageMeter.meter2
        if cfg and cfg.session ~= "overall" then drilldown[i] = nil end
    end
end

local function OnRegenDisabled()
    fightStartTime = GetTime()
end

local function OnSessionUpdated()
    entryCache = {}
    if mainFrame and mainFrame:IsShown() then RenderAllPanes() end
end

local function OnRestrictionChanged()
    local restrState = C_RestrictedActions and Enum.AddOnRestrictionType and
        C_RestrictedActions.GetAddOnRestrictionState(Enum.AddOnRestrictionType.Combat)
    if not restrState or restrState == 0 then
        entryCache = {}
        if mainFrame and mainFrame:IsShown() then RenderAllPanes() end
    end
end

local function OnEnteringWorld()
    entryCache = {}
    if InCombatLockdown() then
        fightStartTime = GetTime()
    end
    SafeAfter(1, addonTable.DamageMeter.Initialize)
end

local function OnZoneChanged()
    if UIThingsDB.damageMeter.clearOnInstance then
        local inInst = IsInInstance()
        if inInst then addonTable.DamageMeter.ResetData() end
    end
end

RegisterEvents = function()
    if eventsRegistered then return end
    eventsRegistered = true
    EventBus.Register("PLAYER_REGEN_ENABLED",               OnRegenEnabled,       "DamageMeter")
    EventBus.Register("PLAYER_REGEN_DISABLED",              OnRegenDisabled,      "DamageMeter")
    EventBus.Register("DAMAGE_METER_COMBAT_SESSION_UPDATED", OnSessionUpdated,    "DamageMeter")
    EventBus.Register("ADDON_RESTRICTION_STATE_CHANGED",    OnRestrictionChanged, "DamageMeter")
    EventBus.Register("PLAYER_ENTERING_WORLD",              OnEnteringWorld,      "DamageMeter")
    EventBus.Register("ZONE_CHANGED_NEW_AREA",              OnZoneChanged,        "DamageMeter")
end

UnregisterEvents = function()
    if not eventsRegistered then return end
    eventsRegistered = false
    EventBus.Unregister("PLAYER_REGEN_ENABLED",               OnRegenEnabled)
    EventBus.Unregister("PLAYER_REGEN_DISABLED",              OnRegenDisabled)
    EventBus.Unregister("DAMAGE_METER_COMBAT_SESSION_UPDATED", OnSessionUpdated)
    EventBus.Unregister("ADDON_RESTRICTION_STATE_CHANGED",    OnRestrictionChanged)
    EventBus.Unregister("PLAYER_ENTERING_WORLD",              OnEnteringWorld)
    EventBus.Unregister("ZONE_CHANGED_NEW_AREA",              OnZoneChanged)
end
