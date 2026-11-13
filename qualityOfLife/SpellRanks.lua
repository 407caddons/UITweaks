-- WoW Forever only (spell ranks): outline action-bar spells that are not the
-- highest rank you know, and list them in chat after login or /reload.
-- Read-only: never changes bars. Overlays are Luna's own frames on top of the
-- action buttons; Blizzard's buttons are only read (action slot) and anchored to.
local _, addon = ...
if not (addon.Client and addon.Client.isForever) then return end
local QoL = addon.QualityOfLife
local Ranks = {}
QoL.SpellRanks = Ranks
QoL.AddModule(Ranks)

local BAR_BUTTONS = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }
local overlays = {}
local pending, announce, refreshQueued = false, false, false

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return (GetSpellInfo(id))
end
local function RankOf(id)
    local text = C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id)
    if not text and GetSpellSubtext then text = GetSpellSubtext(id) end
    return type(text) == "string" and tonumber(text:match("(%d+)")) or nil
end

-- Highest known rank per spell name, from the spellbook. Covers both the
-- modern C_SpellBook API and the classic tab/index API.
local function KnownRanks()
    local best = {}
    local function Consider(id)
        if not id then return end
        local name, rank = SpellName(id), RankOf(id)
        if name and rank and (not best[name] or rank > best[name].rank) then best[name] = { rank = rank, id = id } end
    end
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo then
        local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if info then
                for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
                    if item and not item.isPassive and not item.isOffSpec then Consider(item.spellID or item.actionID) end
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, count = GetSpellTabInfo(tab)
            for i = offset + 1, offset + count do
                local kind, id = GetSpellBookItemInfo(i, BOOKTYPE_SPELL or "spell")
                if kind == "SPELL" then Consider(id) end
            end
        end
    end
    return best
end

local function ActionSlot(button)
    local slot = button.action
    if type(slot) ~= "number" and button.GetAttribute then slot = tonumber(button:GetAttribute("action")) end
    if type(slot) ~= "number" and ActionButton_GetPagedID then slot = ActionButton_GetPagedID(button) end
    return type(slot) == "number" and slot > 0 and slot or nil
end

-- Spell ID on an action slot: spells directly, or a macro's resolved spell.
local function SlotSpell(slot)
    local kind, id = GetActionInfo(slot)
    if kind == "spell" then return id end
    if kind == "macro" and GetMacroSpell then return (GetMacroSpell(id)) end
end

local function Overlay(button)
    local overlay = overlays[button]
    if overlay then return overlay end
    overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints(button)
    overlay:SetFrameLevel(button:GetFrameLevel() + 5)
    overlay:EnableMouse(false)
    overlay.edges = {}
    for i, points in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = overlay:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(1, 0.45, 0, 0.95)
        edge:SetPoint(points[1]); edge:SetPoint(points[2])
        if i <= 2 then edge:SetHeight(2) else edge:SetWidth(2) end
        overlay.edges[i] = edge
    end
    overlay.text = overlay:CreateFontString(nil, "OVERLAY", "LunaFontNumberSmall")
    overlay.text:SetPoint("TOPLEFT", 2, -2)
    overlay.text:SetTextColor(1, 0.55, 0.1)
    overlay:Hide()
    overlays[button] = overlay
    return overlay
end

-- Returns the list of outdated spells ({name, rank, best}) and updates overlays.
function Ranks.Scan()
    local enabled = QoL.Enabled("spellRanks")
    -- Spellbook APIs differ between client builds; never let a lookup break the scan.
    local ok, best = pcall(KnownRanks)
    if not enabled or not ok then best = {} end
    local outdated, listed = {}, {}
    for _, prefix in ipairs(BAR_BUTTONS) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            if button then
                local slot = enabled and ActionSlot(button)
                local id = slot and SlotSpell(slot)
                local name, rank = id and SpellName(id), id and RankOf(id)
                local top = name and best[name]
                local low = rank and top and rank < top.rank
                if low then
                    local overlay = Overlay(button)
                    overlay.text:SetText("R" .. rank)
                    overlay:Show()
                    if not listed[name .. rank] then
                        listed[name .. rank] = true
                        outdated[#outdated + 1] = { name = name, rank = rank, best = top.rank }
                    end
                elseif overlays[button] then
                    overlays[button]:Hide()
                end
            end
        end
    end
    return outdated
end

local function Report(outdated)
    if #outdated == 0 then return end
    table.sort(outdated, function(a, b) return a.name < b.name end)
    local parts = {}
    for _, entry in ipairs(outdated) do
        parts[#parts + 1] = string.format("%s (Rank %d, you know %d)", entry.name, entry.rank, entry.best)
    end
    print("|cff00ccffLuna:|r Spells on your bars below your highest rank (outlined in orange): " .. table.concat(parts, ", "))
end

-- Overlays are children of protected buttons: create/update only out of combat.
local function Refresh()
    refreshQueued = false
    if InCombatLockdown() then pending = true; return end
    pending = false
    local outdated = Ranks.Scan()
    if announce then
        announce = false
        Report(outdated)
    end
end
local function QueueRefresh()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0.5, Refresh)
end

-- SPELLS_CHANGED also covers newly learned ranks. Events missing from this
-- client build are skipped (registering an unknown event is an error).
local watched = {}
for _, event in ipairs({ "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "SPELLS_CHANGED", "UPDATE_MACROS" }) do
    if not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event) then watched[#watched + 1] = event end
end
local function OnEvent() QueueRefresh() end
function Ranks.UpdateSettings()
    local enabled = QoL.Enabled("spellRanks")
    for _, event in ipairs(watched) do
        if enabled then addon.EventBus.Register(event, OnEvent, "SpellRanks") else addon.EventBus.Unregister(event, OnEvent) end
    end
    QueueRefresh()
end
-- Chat list only after login or /reload, not on every loading screen.
addon.EventBus.Register("PLAYER_ENTERING_WORLD", function(_, isLogin, isReload)
    if not QoL.Enabled("spellRanks") or not (isLogin or isReload) then return end
    announce = true
    -- The spellbook and bars settle a moment after entering the world.
    C_Timer.After(2, QueueRefresh)
end, "SpellRanks")
addon.EventBus.Register("PLAYER_REGEN_ENABLED", function() if pending then QueueRefresh() end end, "SpellRanks")
