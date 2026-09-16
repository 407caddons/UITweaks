-- DamageMeter.lua
-- Custom damage meter using the C_DamageMeter API (WoW 12.0+).
-- Data is pulled from Blizzard's built-in combat session store — no combat log parsing.

local addonName, addonTable = ...
addonTable.DamageMeter = {}

local EventBus  = addonTable.EventBus
local SafeAfter = addonTable.Core.SafeAfter

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

-- Keep the native session's totals, rates and duration together. Never reconstruct
-- Overall from the bounded historical list or time it with PLAYER_REGEN events.
local entryCache = {}
local CACHE_TTL = 0.5
local sessionDurationByID, sessionNameByID = {}, {}
local DPS_TYPES = { damage=true, healing=true, damageTaken=true }
local COUNT_TYPES = { interrupts=true, deaths=true, dispels=true }
local function Public(value) return not (issecretvalue and issecretvalue(value)) end
local function Present(value) return not Public(value) or value ~= nil end
local function GetEnumType(mtype)
    return Enum.DamageMeterType and Enum.DamageMeterType[ENUM_NAMES[mtype]]
end
local function GetSessions()
    local ok, list = pcall(C_DamageMeter.GetAvailableCombatSessions)
    if not ok or type(list) ~= "table" then return {} end
    local result = {}
    for _, session in ipairs(list) do
        local id = session.sessionID
        if Public(id) and type(id) == "number" then
            result[#result+1] = session
            if Public(session.durationSeconds) and type(session.durationSeconds) == "number" then
                sessionDurationByID[id] = session.durationSeconds
            end
            if Public(session.name) and type(session.name) == "string" then sessionNameByID[id] = session.name end
        end
    end
    table.sort(result, function(a,b) return a.sessionID < b.sessionID end)
    return result
end
local function ResolveSession(key)
    if type(key) == "number" then return nil, key end
    if key == "segment" or key == "fight" then
        local sessions = GetSessions()
        return nil, sessions[#sessions] and sessions[#sessions].sessionID
    end
    local types = Enum.DamageMeterSessionType
    if key == "overall" then return types and types.Overall or 0 end
    return types and types.Current or 1
end
local function ReadSession(key, mtype, source)
    local meterType = GetEnumType(mtype)
    if not meterType then return end
    local sessionType, id = ResolveSession(key)
    local ok, data
    if source then
        if sessionType ~= nil then
            ok, data = pcall(C_DamageMeter.GetCombatSessionSourceFromType, sessionType, meterType, source.guid, source.creatureID)
        elseif id then
            ok, data = pcall(C_DamageMeter.GetCombatSessionSourceFromID, id, meterType, source.guid, source.creatureID)
        end
    elseif sessionType ~= nil then
        ok, data = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, meterType)
    elseif id then
        ok, data = pcall(C_DamageMeter.GetCombatSessionFromID, id, meterType)
    end
    if ok then return data end
end
local function FetchEntries(sessKey, mtype)
    local key = tostring(sessKey) .. "|" .. mtype
    local cached = entryCache[key]
    if cached and GetTime() < cached.expiry then return cached.entries, cached.max end
    local data = ReadSession(sessKey, mtype)
    local entries = {}
    if data then
        for _, src in ipairs(data.combatSources or {}) do
            -- Preserve Blizzard's order and identity, including creature-only sources.
            local death = mtype == "deaths" and src.deathRecapID and src.deathRecapID ~= 0
            entries[#entries+1] = {
                guid=src.sourceGUID, creatureID=src.sourceCreatureID, name=src.name,
                class=src.classFilename, isLocalPlayer=src.isLocalPlayer,
                total=death and 1 or src.totalAmount, rate=src.amountPerSecond,
                deathRecapID=death and src.deathRecapID or nil,
                max=death and 1 or data.maxAmount,
            }
        end
    end
    local maximum = data and data.maxAmount or 1
    entryCache[key] = {entries=entries,max=maximum,expiry=GetTime()+CACHE_TTL}
    return entries, maximum
end
local function FetchSpellEntries(sessKey, mtype, guid, creatureID)
    local data = ReadSession(sessKey, mtype, {guid=guid,creatureID=creatureID})
    local entries = {}
    if data then
        for _, spell in ipairs(data.combatSpells or {}) do
            local name
            if Present(spell.spellID) and C_Spell and C_Spell.GetSpellName then
                local ok, value = pcall(C_Spell.GetSpellName, spell.spellID)
                if ok then name=value end
            end
            if not Present(name) then name="Unknown ability" end
            entries[#entries+1] = {spellId=spell.spellID,name=name,total=spell.totalAmount,
                rate=spell.amountPerSecond,max=data.maxAmount}
        end
    end
    return entries, data and data.maxAmount or 1
end
local function FormatVal(val, mtype)
    if not Present(val) then return "—" end
    if COUNT_TYPES[mtype] then return string.format("%d", val) end
    return AbbreviateNumbers(val)
end

-- Class Color
-- ============================================================

local function GetClassColor(class)
    if Public(class) and class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return c.r, c.g, c.b
    end
    return 0.6, 0.6, 0.6
end

-- ============================================================
-- Row Icon / Tooltip Helpers
-- ============================================================

-- mode: "none", "class" (data=classFilename), "player" (self spec), "spell" (data=spellID)
-- classFilename may be secret during live combat — avoid using it as a table key in that case.
local function ApplyRowIcon(row, mode, data)
    local s        = UIThingsDB.damageMeter
    local barH     = s.barHeight or 18
    local iconSize = math.max(12, barH - 2)

    local function anchorNoIcon()
        row.icon:Hide()
        row.nameFS:ClearAllPoints()
        row.nameFS:SetPoint("LEFT",  row.bar, "LEFT",  4, 0)
        row.nameFS:SetPoint("RIGHT", row.bar, "RIGHT", -50, 0)
    end

    if not s.showIcons or mode == "none" then
        anchorNoIcon()
        return
    end

    row.icon:SetSize(iconSize, iconSize)
    local shown = false

    if mode == "player" then
        local specIdx = GetSpecialization and GetSpecialization()
        if specIdx then
            local _, _, _, ic = GetSpecializationInfo(specIdx)
            if ic then
                row.icon:SetTexture(ic)
                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                shown = true
            end
        end
    elseif mode == "class" and data and type(data) == "string"
            and not (issecretvalue and issecretvalue(data))
            and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[data] then
        row.icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        local l, r, t, b = unpack(CLASS_ICON_TCOORDS[data])
        row.icon:SetTexCoord(l, r, t, b)
        shown = true
    elseif mode == "spell" and data then
        local ic = GetSpellTexture and GetSpellTexture(data)
        if not ic and C_Spell and C_Spell.GetSpellTexture then
            ic = C_Spell.GetSpellTexture(data)
        end
        if ic then
            row.icon:SetTexture(ic)
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            shown = true
        end
    end

    if shown then
        row.icon:Show()
        row.nameFS:ClearAllPoints()
        row.nameFS:SetPoint("LEFT",  row.icon, "RIGHT", 4, 0)
        row.nameFS:SetPoint("RIGHT", row.bar,  "RIGHT", -50, 0)
    else
        anchorNoIcon()
    end
end

-- Attach a GameTooltip showing the top 5 abilities for the source at `guid`.
-- Skipped during combat to avoid secret-value arithmetic/sort failures.
local function ApplyRowTooltip(row, guid, displayName, mtype, sessKey, creatureID)
    row:SetScript("OnEnter", function(self)
        if not UIThingsDB.damageMeter.showTooltip then return end
        if InCombatLockdown() then return end
        if not Present(guid) and not Present(creatureID) then return end
        if not Public(displayName) then return end

        local spells = FetchSpellEntries(sessKey, mtype, guid, creatureID)
        if not spells or #spells == 0 then return end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine((displayName or "?") .. " — Top Abilities", 1, 1, 1)
        local n = math.min(5, #spells)
        for i = 1, n do
            local sp = spells[i]
            if not Public(sp.name) or not Public(sp.total) then GameTooltip:Hide(); return end
            local valText = COUNT_TYPES[mtype] and tostring(sp.total) or AbbreviateNumbers(sp.total)
            GameTooltip:AddDoubleLine(i .. ". " .. (sp.name or "?"), valText, 0.9, 0.9, 0.9, 1, 0.82, 0)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function ApplyDeathTooltip(row, entry)
    row:SetScript("OnEnter", function(self)
        if not UIThingsDB.damageMeter.showTooltip then return end
        if InCombatLockdown() or not Public(entry.name) then return end
        local recapID = entry.deathRecapID
        if not recapID or not C_DeathRecap.HasRecapEvents(recapID) then return end
        local events = C_DeathRecap.GetRecapEvents(recapID)
        if not events or #events == 0 then return end
        local maxHealth = C_DeathRecap.GetRecapMaxHealth(recapID)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local title = (entry.name or "?")
        if entry.total > 1 then title = title .. " (" .. entry.total .. " deaths)" end
        GameTooltip:AddLine(title, 1, 0.4, 0.4)
        local n = math.min(8, #events)
        for i = 1, n do
            local ev = events[i]
            local isHeal = ev.event and ev.event:find("HEAL")
            local spellStr = ev.spellName or ev.event or "?"
            local caster = (not ev.hideCaster and ev.sourceName and ev.sourceName ~= "") and ev.sourceName or nil
            local leftText = i == 1 and ("|cffff4444[!]|r " .. spellStr) or spellStr
            if caster then leftText = leftText .. " |cffaaaaaa(" .. caster .. ")|r" end
            local rightText = ""
            if ev.amount then
                local amt = AbbreviateNumbers(ev.amount)
                rightText = isHeal and ("|cff44ff44+" .. amt .. "|r") or ("|cffff7777-" .. amt .. "|r")
            end
            if ev.currentHP and maxHealth and maxHealth > 0 then
                local pct = math.floor(ev.currentHP / maxHealth * 100)
                rightText = rightText ~= "" and (rightText .. "  |cff888888" .. pct .. "%|r") or ("|cff888888" .. pct .. "%|r")
            end
            GameTooltip:AddDoubleLine(leftText, rightText, 0.9, 0.9, 0.9, 1, 1, 1)
        end
        if #events > n then
            GameTooltip:AddLine("|cff888888+" .. (#events - n) .. " earlier events|r")
        end
        GameTooltip:AddLine("|cff888888Click to open full death recap|r")
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
    row.icon = row.bar:CreateTexture(nil, "OVERLAY")
    row.icon:SetPoint("LEFT", row.bar, "LEFT", 2, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon:Hide()
    row.nameFS = row.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.nameFS:SetPoint("LEFT",  row.bar, "LEFT",  4, 0)
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
            row:SetScript("OnEnter", nil)
            row:SetScript("OnLeave", nil)
        end
    end
end

-- ============================================================
-- Render Pane
-- ============================================================

local function RenderPane(idx)
    local pane = panes[idx]
    if not pane or not pane.frame:IsShown() then return end
    local s = UIThingsDB.damageMeter
    local cfg = idx == 1 and s.meter1 or s.meter2
    local mtype, sess, dd = cfg.type, cfg.session, drilldown[idx]
    if dd then
        pane.titleFS:SetFormattedText("%s: %s", TYPE_LABEL[mtype] or mtype, dd.name)
    else
        local label = SESSION_FULL[sess] or "Segment"
        if type(sess) == "number" then
            GetSessions()
            label = sessionNameByID[sess] or "Segment"
            local seconds = sessionDurationByID[sess]
            if seconds then label = label .. string.format(" [%02d:%02d]", math.floor(seconds / 60), math.floor(seconds % 60)) end
        end
        pane.titleFS:SetText((TYPE_LABEL[mtype] or mtype) .. "  [" .. label .. "]")
    end
    pane.backBtn:SetShown(dd ~= nil)
    local entries, maximum
    if dd then entries, maximum = FetchSpellEntries(sess, mtype, dd.guid, dd.creatureID)
    else entries, maximum = FetchEntries(sess, mtype) end
    HideAllRows(pane.rowPool)
    local barH = s.barHeight or 18
    local barCol = s.barColor or {r=.2,g=.5,b=.9,a=1}
    local bg = s.barBgColor or {r=.12,g=.12,b=.12,a=1}
    local txt = s.barTextColor or {r=1,g=1,b=1,a=1}
    local width = pane.scrollFrame:GetWidth()
    if not width or width <= 0 then width = 200 end
    local order = {}
    if s.pinSelf and not dd then
        for i, entry in ipairs(entries) do if entry.isLocalPlayer then order[#order+1] = i end end
    end
    for i, entry in ipairs(entries) do
        if dd or not s.pinSelf or not entry.isLocalPlayer then order[#order+1] = i end
    end
    local y = 0
    for _, rank in ipairs(order) do
        local entry = entries[rank]
        local row = AcquireRow(pane.rowPool, pane.scrollContent)
        row:SetPoint("TOPLEFT", pane.scrollContent, "TOPLEFT", 0, -y)
        row:SetSize(width, barH)
        row.bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a or 1)
        row.bar:SetMinMaxValues(0, entry.max or maximum)
        row.bar:SetValue(entry.total)
        if s.useClassColors and not dd then
            local r, g, b = GetClassColor(entry.class)
            row.bar:SetStatusBarColor(r, g, b, .65)
        else row.bar:SetStatusBarColor(barCol.r, barCol.g, barCol.b, barCol.a or 1) end
        local name = entry.name
        if not Present(name) then name = "Unknown" end
        if s.showRank and not dd then row.nameFS:SetFormattedText("%d. %s", rank, name)
        else row.nameFS:SetText(name) end
        row.nameFS:SetTextColor(txt.r, txt.g, txt.b, txt.a or 1)
        local amount = FormatVal(entry.total, mtype)
        if DPS_TYPES[mtype] and not dd and Present(entry.rate) then
            row.valFS:SetFormattedText("%s  |cffaaaaaa%s/s|r", amount, AbbreviateNumbers(entry.rate))
        else row.valFS:SetText(amount) end
        row.valFS:SetTextColor(txt.r, txt.g, txt.b, txt.a or 1)
        row.dpsFS:Hide()
        if dd then ApplyRowIcon(row, "spell", entry.spellId)
        elseif entry.isLocalPlayer then ApplyRowIcon(row, "player")
        else ApplyRowIcon(row, "class", entry.class) end
        row.nameFS:SetPoint("RIGHT", row.valFS, "LEFT", -8, 0)
        if not dd then
            if entry.deathRecapID then ApplyDeathTooltip(row, entry)
            else ApplyRowTooltip(row, entry.guid, name, mtype, sess, entry.creatureID) end
        end
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(_, button)
            if button == "RightButton" then drilldown[idx] = nil
            elseif button == "LeftButton" and not dd then
                if entry.deathRecapID then OpenDeathRecapUI(entry.deathRecapID); return end
                drilldown[idx] = {guid=entry.guid, creatureID=entry.creatureID, name=name}
            else return end
            RenderPane(idx)
        end)
        y = y + barH + 1
    end
    if #entries == 0 then
        local row = AcquireRow(pane.rowPool, pane.scrollContent)
        row:SetPoint("TOPLEFT", pane.scrollContent, "TOPLEFT", 0, 0)
        row:SetSize(width, barH)
        row.bg:SetColorTexture(0, 0, 0, 0)
        row.bar:SetMinMaxValues(0, 1)
        row.bar:SetValue(0)
        row.bar:SetStatusBarColor(0, 0, 0, 0)
        row.nameFS:SetText("|cff555555No data|r")
        row.valFS:SetText("")
        row.dpsFS:Hide()
        ApplyRowIcon(row, "none")
        y = barH
    end
    -- Do not inspect secret status-bar geometry through the scroll template.
    if not InCombatLockdown() then pane.scrollContent:SetSize(width, math.max(y + 4, 20)) end
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
    for i = #sessions, 1, -1 do
        local sess = sessions[i]
        local sid  = sess.sessionID
        -- Try reading a name from the session object itself
        local rawName = sess.name
        if rawName and issecretvalue and issecretvalue(rawName) then rawName = nil end
        local dur    = sessionDurationByID[sid]
        local durStr = dur and string.format(" [%02d:%02d]", math.floor(dur / 60), math.floor(dur % 60)) or " [--:--]"
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

local function ClearSessionState()
    entryCache = {}
    sessionDurationByID, sessionNameByID = {}, {}
    for i = 1, 2 do
        drilldown[i] = nil
        local cfg = i == 1 and UIThingsDB.damageMeter.meter1 or UIThingsDB.damageMeter.meter2
        if cfg and type(cfg.session) == "number" then cfg.session = "current" end
    end
    if mainFrame and mainFrame:IsShown() then RenderAllPanes() end
end

function addonTable.DamageMeter.ResetData()
    if InCombatLockdown() then
        print("Luna damage meter: reset is unavailable during combat.")
        return false
    end
    local ok = pcall(C_DamageMeter.ResetAllCombatSessions)
    if not ok then
        print("Luna damage meter: Blizzard could not reset the session data.")
        return false
    end
    ClearSessionState()
    return true
end

function addonTable.DamageMeter.GetFrame() return mainFrame end
function addonTable.DamageMeter.GetMeterTypes() return METER_TYPES end
function addonTable.DamageMeter.GetTypeLabel(t) return TYPE_LABEL[t] or t end

-- Coalesce the paired Overall/Current notifications into one refresh.
local eventsRegistered = false
local refreshPending = false
local function OnSessionUpdated(_, meterType)
    if meterType ~= nil then
        local s = UIThingsDB.damageMeter
        if meterType ~= GetEnumType(s.meter1.type) and meterType ~= GetEnumType(s.meter2.type) then return end
    end
    entryCache = {}
    if refreshPending then return end
    refreshPending = true
    SafeAfter(0, function()
        refreshPending = false
        if eventsRegistered and mainFrame and mainFrame:IsShown() then RenderAllPanes() end
    end)
end

local function OnCurrentSessionUpdated()
    for i = 1, 2 do
        local cfg = i == 1 and UIThingsDB.damageMeter.meter1 or UIThingsDB.damageMeter.meter2
        if cfg and cfg.session ~= "overall" then drilldown[i] = nil end
    end
    OnSessionUpdated()
end

local lastInstance
local function InstanceKey()
    local inside = IsInInstance()
    if not inside then return nil end
    local _, kind, _, _, _, _, _, id = GetInstanceInfo()
    return tostring(kind) .. ":" .. tostring(id)
end
local function OnEnteringWorld()
    entryCache = {}
    lastInstance = InstanceKey()
    SafeAfter(1, addonTable.DamageMeter.Initialize)
end
local function OnZoneChanged()
    local nextInstance = InstanceKey()
    local changed = nextInstance ~= lastInstance
    lastInstance = nextInstance
    if changed and nextInstance and UIThingsDB.damageMeter.clearOnInstance then
        addonTable.DamageMeter.ResetData()
    end
end

local handlers = {
    PLAYER_REGEN_ENABLED = function() OnSessionUpdated() end,
    PLAYER_REGEN_DISABLED = function() OnSessionUpdated() end,
    DAMAGE_METER_COMBAT_SESSION_UPDATED = OnSessionUpdated,
    DAMAGE_METER_CURRENT_SESSION_UPDATED = OnCurrentSessionUpdated,
    DAMAGE_METER_RESET = ClearSessionState,
    ADDON_RESTRICTION_STATE_CHANGED = function() OnSessionUpdated() end,
    PLAYER_ENTERING_WORLD = OnEnteringWorld,
    ZONE_CHANGED_NEW_AREA = OnZoneChanged,
}
RegisterEvents = function()
    if eventsRegistered then return end
    eventsRegistered = true
    lastInstance = InstanceKey()
    for event, handler in pairs(handlers) do EventBus.Register(event, handler, "DamageMeter") end
end
UnregisterEvents = function()
    if not eventsRegistered then return end
    eventsRegistered = false
    for event, handler in pairs(handlers) do EventBus.Unregister(event, handler) end
end
