--[[
    Mythic+ Interrupt Tracker v10.0 - Midnight 12.0.x

    - Addon-to-addon sync (SendAddonMessage)
    - ShimmerTracker pattern for player CD (taint-safe)
    - ElvUI auto-detection (font, texture)
    - Simplified config (/mit)
    - Corner drag-to-resize
    - SavedVariables

    Main chunk: ONLY plain CreateFrame("Frame") + RegisterEvent.
]]

local ADDON_NAME = "MythicInterruptTracker"
local MSG_PREFIX = "MIT"
local MIT_VERSION = "12.1"

------------------------------------------------------------
-- Spell data (multiple possible interrupts per class/spec)
------------------------------------------------------------
local ALL_INTERRUPTS = {
    [6552]    = { name = "Pummel", cd = 15, icon = 132938 },
    [1766]    = { name = "Kick", cd = 15, icon = 132219 },
    [2139]    = { name = "Counterspell", cd = 24, icon = 135856 },
    [57994]   = { name = "Wind Shear", cd = 12, icon = 136018 },
    [106839]  = { name = "Skull Bash", cd = 15, icon = 236946 },
    [78675]   = { name = "Solar Beam", cd = 60, icon = 236748 },
    [47528]   = { name = "Mind Freeze", cd = 15, icon = 237527 },
    [96231]   = { name = "Rebuke", cd = 15, icon = 523893 },
    [183752]  = { name = "Disrupt", cd = 15, icon = 1305153 },
    [116705]  = { name = "Spear Hand Strike", cd = 15, icon = 608940 },
    [15487]   = { name = "Silence", cd = 45, icon = 458230 },
    [147362]  = { name = "Counter Shot", cd = 24, icon = 249170 },
    [187707]  = { name = "Muzzle", cd = 15, icon = 1376045 },
    [19647]   = { name = "Spell Lock", cd = 24, icon = 136174 },
    [132409]  = { name = "Spell Lock", cd = 24, icon = 136174 },
    [119914]  = { name = "Axe Toss", cd = 30, icon = "Interface\\Icons\\ability_warrior_titansgrip" },
    [1276467] = { name = "Fel Ravager", cd = 25, icon = "Interface\\Icons\\spell_shadow_summonfelhunter" },
    [351338]  = { name = "Quell", cd = 40, icon = 4622468 },
}

-- Which spells to check per class (order matters: first found wins)
local CLASS_INTERRUPT_LIST = {
    WARRIOR     = { 6552 },
    ROGUE       = { 1766 },
    MAGE        = { 2139 },
    SHAMAN      = { 57994 },
    DRUID       = { 106839, 78675 }, -- Skull Bash (feral/guardian), Solar Beam (balance)
    DEATHKNIGHT = { 47528 },
    PALADIN     = { 96231 },
    DEMONHUNTER = { 183752 },
    MONK        = { 116705 },
    PRIEST      = { 15487 },          -- Silence (shadow only)
    HUNTER      = { 147362, 187707 }, -- Counter Shot (BM/MM), Muzzle (survival)
    WARLOCK     = { 19647, 132409, 119914 },
    EVOKER      = { 351338 },
}

local CLASS_COLORS = {
    WARRIOR     = { 0.78, 0.61, 0.43 },
    ROGUE       = { 1.00, 0.96, 0.41 },
    MAGE        = { 0.41, 0.80, 0.94 },
    SHAMAN      = { 0.00, 0.44, 0.87 },
    DRUID       = { 1.00, 0.49, 0.04 },
    DEATHKNIGHT = { 0.77, 0.12, 0.23 },
    PALADIN     = { 0.96, 0.55, 0.73 },
    DEMONHUNTER = { 0.64, 0.19, 0.79 },
    MONK        = { 0.00, 1.00, 0.59 },
    PRIEST      = { 1.00, 1.00, 1.00 },
    HUNTER      = { 0.67, 0.83, 0.45 },
    WARLOCK     = { 0.58, 0.51, 0.79 },
    EVOKER      = { 0.20, 0.58, 0.50 },
}

------------------------------------------------------------
-- Defaults
------------------------------------------------------------
local DEFAULTS = {
    frameWidth      = 220,
    barHeight       = 28,
    locked          = false,
    showTitle       = true,
    growUp          = false,
    alpha           = 0.9,
    showInDungeon   = true,
    showInRaid      = false,
    showInOpenWorld = true,
    showInArena     = false,
    showInBG        = false,
}

------------------------------------------------------------
-- State
------------------------------------------------------------
local db
local myClass, myName, mySpellID
local myCachedCD
local myBaseCd             -- real base CD from spellbook (with talents)
local myKickCdEnd = 0      -- clean tracking of our own kick CD
local myIsPetSpell = false -- is our primary kick a pet spell?
local myExtraKicks = {}    -- extra kicks for own player {spellID → {baseCd, cdEnd}}
local partyAddonUsers = {}
local bars = {}
local mainFrame, titleText, configFrame, resizeHandle
local updateTicker
local ready = false
local isResizing = false
local lastAnnounce = 0
local testMode = false
local testTicker = nil
local spyMode = false

-- String-keyed version for laundered (still-tainted) spellID lookups
local ALL_INTERRUPTS_STR = {}
for id, data in pairs(ALL_INTERRUPTS) do
    ALL_INTERRUPTS_STR[tostring(id)] = data
end

-- Class → primary interrupt mapping (for auto-detection when mob gets interrupted)
local CLASS_INTERRUPTS = {
    WARRIOR     = { id = 6552, cd = 15, name = "Pummel" },
    ROGUE       = { id = 1766, cd = 15, name = "Kick" },
    MAGE        = { id = 2139, cd = 24, name = "Counterspell" },
    SHAMAN      = { id = 57994, cd = 12, name = "Wind Shear" },
    DRUID       = { id = 106839, cd = 15, name = "Skull Bash" },
    DEATHKNIGHT = { id = 47528, cd = 15, name = "Mind Freeze" },
    PALADIN     = { id = 96231, cd = 15, name = "Rebuke" },
    DEMONHUNTER = { id = 183752, cd = 15, name = "Disrupt" },
    HUNTER      = { id = 147362, cd = 24, name = "Counter Shot" },
    MONK        = { id = 116705, cd = 15, name = "Spear Hand Strike" },
    WARLOCK     = { id = 19647, cd = 24, name = "Spell Lock" },
    PRIEST      = { id = 15487, cd = 45, name = "Silence" },
    EVOKER      = { id = 351338, cd = 40, name = "Quell" },
}

-- SpecID → interrupt override (when spec changes the interrupt or CD)
local SPEC_INTERRUPT_OVERRIDES = {
    [255] = { id = 187707, cd = 15, name = "Muzzle" },                   -- Survival Hunter
    [264] = { id = 57994, cd = 30, name = "Wind Shear" },                -- Restoration Shaman (30s vs 12s for Ele/Enh)
    [266] = { id = 119914, cd = 30, name = "Axe Toss", isPet = true },   -- Demonology Warlock (Felguard)
}

-- Specs that have NO interrupt (remove from tracker after inspect)
-- Be conservative: only list specs we're SURE have no interrupt
local SPEC_NO_INTERRUPT = {
    [256] = true,  -- Discipline Priest (no Silence)
    [257] = true,  -- Holy Priest (no Silence)
    [105] = true,  -- Restoration Druid (Skull Bash removed in 12.0)
    [65]  = true,  -- Holy Paladin (no Rebuke)
    -- [1468] = true, -- Preservation Evoker - verify if Quell removed
    -- [270]  = true, -- Mistweaver Monk - verify if Spear Hand Strike removed
}

-- Talents that PERMANENTLY reduce interrupt cooldowns (scanned via inspect)
local CD_REDUCTION_TALENTS = {
    -- Hunter: Lone Survivor - "Counter Shot and Muzzle CD reduced by 2 sec" (passive)
    [388039] = { affects = 147362, reduction = 2, name = "Lone Survivor" },
    -- Evoker: Imposing Presence - "Quell CD reduced by 20 sec" (passive)
    [371016] = { affects = 351338, reduction = 20, name = "Imposing Presence" },
}

-- Talents that reduce CD only on SUCCESSFUL interrupt (applied per-kick, not on baseCd)
local CD_ON_KICK_TALENTS = {
    -- DK: Coldthirst - "Mind Freeze CD reduced by 3 sec on successful interrupt"
    [378848] = { reduction = 3, name = "Coldthirst" },
}

-- Talents that grant an EXTRA interrupt ability (second bar)
local EXTRA_KICK_TALENTS = {
    -- (auto-detected dynamically when a different kick is used)
}

-- Specs that always have extra kicks
local SPEC_EXTRA_KICKS = {
    [266] = {
        {
            id = 132409,
            cd = 25,
            name = "Fel Ravager / Spell Lock",
            icon = "Interface\\Icons\\spell_shadow_summonfelhunter",
            talentCheck = 1276467
        },                         -- Check if Grimoire: Fel Ravager talent is known
    },
}

-- No longer needed
local PLAYER_CAST_EXTRA_KICK = {}

-- Spell aliases: some spells fire different IDs on party vs own client
-- e.g., Fel Ravager summon fires as 1276467 on party but 132409 on own
local SPELL_ALIASES = {
    [1276467] = 132409, -- Fel Ravager summon → Spell Lock extra kick bar
}

-- Inspect queue
local inspectQueue = {}
local inspectBusy = false
local inspectUnit = nil
local inspectedPlayers = {}   -- name → true
local noInterruptPlayers = {} -- name → true (healers etc. with no kick)

-- These MUST be created here, NOT inside event handlers
local launderBar = CreateFrame("StatusBar")
launderBar:SetMinMaxValues(0, 9999999)

-- Slider for OnValueChanged laundering
local launderSlider = CreateFrame("Slider", nil, UIParent)
launderSlider:SetMinMaxValues(0, 9999999)
launderSlider:SetSize(1, 1)
launderSlider:Hide()

-- OnValueChanged result storage (written by callback, read by handler)
local onValueChangedResult = nil

-- The key insight: when a widget fires OnValueChanged, the C++ engine
-- re-reads the value from internal storage and passes it as a callback arg.
-- This MIGHT strip taint since it's a new value from C++ land.
launderBar:SetScript("OnValueChanged", function(self, value)
    onValueChangedResult = value
end)

-- Also try Slider's OnValueChanged
local onSliderChangedResult = nil
launderSlider:SetScript("OnValueChanged", function(self, value)
    onSliderChangedResult = value
end)

local spyCastCount = 0
local partyFrames = {}
local partyPetFrames = {}
-- Pre-create party watcher frames at load time (clean untainted context)
for i = 1, 4 do
    partyFrames[i] = CreateFrame("Frame")
    partyPetFrames[i] = CreateFrame("Frame")
end
local RegisterPartyWatchers
local sniffMode    = false

-- Use the game's default font (supports all locales: Latin, Cyrillic, Korean, Chinese)
local FONT_FACE    = GameFontNormal and GameFontNormal:GetFont() or "Fonts\\FRIZQT__.TTF"
local FONT_FLAGS   = "OUTLINE"
local BAR_TEXTURE  = "Interface\\BUTTONS\\WHITE8X8"
local FLAT_TEX     = "Interface\\BUTTONS\\WHITE8X8"

-- Locale-specific font fallbacks (if GameFontNormal not available at load time)
local LOCALE_FONTS = {
    ["koKR"] = "Fonts\\2002.TTF",
    ["zhCN"] = "Fonts\\ARKai_T.TTF",
    ["zhTW"] = "Fonts\\blei00d.TTF",
    ["ruRU"] = "Fonts\\FRIZQT___CYR.TTF",
}

------------------------------------------------------------
-- ElvUI detection
------------------------------------------------------------
local function DetectElvUI()
    -- Apply locale font fallback if needed
    local locale = GetLocale()
    if LOCALE_FONTS[locale] and FONT_FACE == "Fonts\\FRIZQT__.TTF" then
        FONT_FACE = LOCALE_FONTS[locale]
    end
    -- Re-read from GameFontNormal in case it's ready now
    if GameFontNormal then
        local gf = GameFontNormal:GetFont()
        if gf then FONT_FACE = gf end
    end

    if ElvUI then
        local E = unpack(ElvUI)
        if E and E.media then
            if E.media.normFont then FONT_FACE = E.media.normFont end
            if E.media.normTex then BAR_TEXTURE = E.media.normTex end
        end
    end
end

------------------------------------------------------------
-- Communication
------------------------------------------------------------
local function SendMIT(msg)
    -- Try PARTY first (works outside instances)
    if IsInGroup(LE_PARTY_CATEGORY_HOME) then
        local ok, ret = pcall(C_ChatInfo.SendAddonMessage, MSG_PREFIX, msg, "PARTY")
        if ok and ret == 0 then return end
    end

    -- PARTY failed (instance) -> WHISPER each party member
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
            local ok, name, realm = pcall(UnitFullName, unit)
            if ok and name then
                local target = (realm and realm ~= "") and (name .. "-" .. realm) or name
                pcall(C_ChatInfo.SendAddonMessage, MSG_PREFIX, msg, "WHISPER", target)
            end
        end
    end
end

local function ReadMyBaseCd()
    if not mySpellID then return end
    local ok, ms = pcall(GetSpellBaseCooldown, mySpellID)
    if ok and ms then
        local clean = tonumber(string.format("%.0f", ms))
        if clean and clean > 0 then
            myBaseCd = clean / 1000
        end
    end
    -- TryCacheCD gives actual observed CD (after all modifiers)
    if myCachedCD and myCachedCD > 1.5 then
        myBaseCd = myCachedCD
    end
end

local function AnnounceJoin()
    if not myClass or not mySpellID then return end
    local now = GetTime()
    if now - lastAnnounce < 3 then return end
    lastAnnounce = now
    ReadMyBaseCd()
    local cd = myBaseCd or ALL_INTERRUPTS[mySpellID].cd
    SendMIT("JOIN:" .. myClass .. ":" .. mySpellID .. ":" .. cd)
end

local function OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= MSG_PREFIX then return end
    local shortName = Ambiguate(sender, "short")
    local parts = { strsplit(":", message) }
    local command = parts[1]

    -- PING: don't filter self (for diagnostics)
    if command == "PING" then
        local via = parts[2] or "unknown"
        local self_tag = (shortName == myName) and " |cFFFFFF00(SELF)|r" or ""
        print("|cFF00DDDD[MIT]|r Received PING from |cFF00FF00" ..
        shortName .. "|r channel=" .. tostring(channel) .. " tag=" .. via .. self_tag)
        return
    end

    -- All other messages: filter self
    if shortName == myName then return end

    if command == "JOIN" then
        local cls = parts[2]
        local spellID = tonumber(parts[3])
        local baseCd = tonumber(parts[4])
        if cls and CLASS_COLORS[cls] and spellID and ALL_INTERRUPTS[spellID] then
            partyAddonUsers[shortName] = partyAddonUsers[shortName] or {}
            partyAddonUsers[shortName].class = cls
            partyAddonUsers[shortName].spellID = spellID
            partyAddonUsers[shortName].cdEnd = partyAddonUsers[shortName].cdEnd or 0
            if baseCd and baseCd > 0 then
                partyAddonUsers[shortName].baseCd = baseCd
            end
            AnnounceJoin()
        end
    elseif command == "CAST" then
        local cd = tonumber(parts[2])
        if cd and cd > 0 and partyAddonUsers[shortName] then
            partyAddonUsers[shortName].cdEnd = GetTime() + cd
            partyAddonUsers[shortName].baseCd = cd
        end
    elseif command == "PING" then
        local via = parts[2] or "unknown"
        print("|cFF00DDDD[MIT]|r Received PING from |cFF00FF00" ..
        shortName .. "|r via channel=" .. tostring(channel) .. " tag=" .. via)
    end
end

local function OnSpellCastSucceeded(unit, castGUID, spellID, isParty, cleanName)
    if isParty and cleanName and spellID then
        local now = GetTime()
        -- Resolve alias (e.g., 1276467 Fel Ravager summon → 132409 Spell Lock)
        local resolvedID = SPELL_ALIASES[spellID] or spellID
        if partyAddonUsers[cleanName] then
            local info = partyAddonUsers[cleanName]
            -- Check if it's an extra kick first (check both original and resolved ID)
            local isExtra = false
            if info.extraKicks then
                for _, ek in ipairs(info.extraKicks) do
                    if resolvedID == ek.spellID or spellID == ek.spellID then
                        ek.cdEnd = now + ek.baseCd
                        isExtra = true
                        if spyMode then
                            print("|cFF00DDDD[SPY]|r " ..
                            cleanName ..
                            " used extra kick " ..
                            ek.name ..
                            " → CD=" .. ek.baseCd .. "s (spellID=" .. spellID .. " resolved=" .. resolvedID .. ")")
                        end
                        break
                    end
                end
            end
            if not isExtra then
                -- If this is a different interrupt than primary, auto-add as extra
                if info.spellID and resolvedID ~= info.spellID and ALL_INTERRUPTS[resolvedID] then
                    if not info.extraKicks then info.extraKicks = {} end
                    -- Check it's not already there
                    local found = false
                    for _, ek in ipairs(info.extraKicks) do
                        if ek.spellID == resolvedID then
                            found = true; break
                        end
                    end
                    if not found then
                        local ekData = ALL_INTERRUPTS[resolvedID]
                        table.insert(info.extraKicks, {
                            spellID = resolvedID,
                            baseCd = ekData.cd,
                            cdEnd = now + ekData.cd,
                            name = ekData.name,
                        })
                        if spyMode then
                            print("|cFF00DDDD[SPY]|r Auto-added extra kick for " ..
                            cleanName .. ": " .. ekData.name .. " CD=" .. ekData.cd .. "s")
                        end
                    else
                        -- Update existing extra kick
                        for _, ek in ipairs(info.extraKicks) do
                            if ek.spellID == resolvedID then
                                ek.cdEnd = now + ek.baseCd
                                break
                            end
                        end
                    end
                else
                    -- Primary kick
                    local baseCd = info.baseCd or (ALL_INTERRUPTS[resolvedID] and ALL_INTERRUPTS[resolvedID].cd) or 15
                    info.cdEnd = now + baseCd
                    info.lastKickTime = now
                    if spyMode then
                        print("|cFF00DDDD[SPY]|r " .. cleanName .. " used kick → CD=" .. baseCd .. "s (pending confirm)")
                    end
                end
            end
        else
            -- Don't auto-register players known to have no interrupt
            if noInterruptPlayers[cleanName] then return end
            local ok, _, cls = pcall(UnitClass, unit)
            if ok and cls and CLASS_COLORS[cls] then
                -- Also check role: skip healers (except shaman)
                local role = UnitGroupRolesAssigned(unit)
                if role == "HEALER" and cls ~= "SHAMAN" then
                    noInterruptPlayers[cleanName] = true
                    return
                end
                partyAddonUsers[cleanName] = {
                    class = cls,
                    spellID = spellID,
                    baseCd = ALL_INTERRUPTS[spellID] and ALL_INTERRUPTS[spellID].cd or 15,
                    cdEnd = now + (ALL_INTERRUPTS[spellID] and ALL_INTERRUPTS[spellID].cd or 15),
                    lastKickTime = now,
                }
            end
        end
        return
    end

    -- Own kicks (player or pet for warlock)
    if unit ~= "player" and unit ~= "pet" then return end
    if not ALL_INTERRUPTS[spellID] then return end

    -- Check if it's an extra kick
    if myExtraKicks[spellID] then
        myExtraKicks[spellID].cdEnd = GetTime() + myExtraKicks[spellID].baseCd
        if spyMode then
            print("|cFF00DDDD[SPY]|r Own extra kick: " ..
            (myExtraKicks[spellID].name or "?") .. " CD=" .. myExtraKicks[spellID].baseCd)
        end
        return
    end

    -- If this is a DIFFERENT interrupt than our primary, auto-add as extra
    if mySpellID and spellID ~= mySpellID then
        local data = ALL_INTERRUPTS[spellID]
        myExtraKicks[spellID] = { baseCd = data.cd, cdEnd = GetTime() + data.cd }
        if spyMode then
            print("|cFF00DDDD[SPY]|r Auto-added extra kick: " .. data.name .. " CD=" .. data.cd)
        end
        return
    end

    local cd = myCachedCD or myBaseCd or ALL_INTERRUPTS[spellID].cd
    myKickCdEnd = GetTime() + cd
    SendMIT("CAST:" .. cd)
end

local function TryCacheCD()
    if not mySpellID or InCombatLockdown() then return end
    -- Skip for pet spells (C_Spell doesn't work on them)
    if myIsPetSpell or not IsSpellKnown(mySpellID) then return end
    local ok, cdInfo = pcall(C_Spell.GetSpellCooldown, mySpellID)
    if not ok or not cdInfo then return end
    local ok2, dur = pcall(function() return cdInfo.duration end)
    if not ok2 or not dur then return end
    local clean = tonumber(string.format("%.1f", dur))
    if clean and clean > 1.5 then
        myCachedCD = clean
        myBaseCd = clean
    end
end

local function CleanPartyList()
    if testMode then return end
    local currentNames = {}
    for i = 1, 4 do
        local u = "party" .. i
        if UnitExists(u) then currentNames[UnitName(u)] = true end
    end
    for name in pairs(partyAddonUsers) do
        if not currentNames[name] then partyAddonUsers[name] = nil end
    end
    -- Clean inspect caches for people who left
    for name in pairs(noInterruptPlayers) do
        if not currentNames[name] then
            noInterruptPlayers[name] = nil
            inspectedPlayers[name] = nil
        end
    end
    for name in pairs(inspectedPlayers) do
        if not currentNames[name] then inspectedPlayers[name] = nil end
    end
    AnnounceJoin()
end

-- Auto-register party members by class (no addon comms needed!)
-- This is the key to working in M+ where SendAddonMessage is blocked
local HEALER_KEEPS_KICK = {
    SHAMAN = true,  -- Resto Shaman keeps Wind Shear
}

local function AutoRegisterPartyByClass()
    for i = 1, 4 do
        local u = "party" .. i
        if UnitExists(u) then
            local name = UnitName(u)
            local _, cls = UnitClass(u)
            if name and cls and CLASS_INTERRUPTS[cls] then
                if not partyAddonUsers[name] and not noInterruptPlayers[name] then
                    -- Skip healers from classes that lose their kick as healer
                    local role = UnitGroupRolesAssigned(u)
                    if role == "HEALER" and not HEALER_KEEPS_KICK[cls] then
                        if spyMode then
                            print("|cFF00DDDD[SPY]|r Skipping " .. name .. " (" .. cls .. " HEALER) - no kick expected")
                        end
                    else
                        local kickInfo = CLASS_INTERRUPTS[cls]
                        partyAddonUsers[name] = {
                            class = cls,
                            spellID = kickInfo.id,
                            baseCd = kickInfo.cd,
                            cdEnd = 0,
                        }
                        if spyMode then
                            print("|cFF00DDDD[SPY]|r Auto-registered " ..
                            name .. " (" .. cls .. ") " .. kickInfo.name .. " CD=" .. kickInfo.cd)
                        end
                    end
                end
            end
        end
    end
end

------------------------------------------------------------
-- Inspect party members for spec + talents (before M+ key)
------------------------------------------------------------
local function ScanInspectTalents(unit)
    local name = UnitName(unit)
    if not name then return end
    local info = partyAddonUsers[name]
    if not info then return end

    -- 1) Get spec → override interrupt if needed, or remove if no interrupt
    local specID = GetInspectSpecialization(unit)
    if specID and specID > 0 then
        -- Remove talent-checked extra kicks (will be re-added if talent found)
        if info.extraKicks and SPEC_EXTRA_KICKS[specID] then
            for _, extraSpec in ipairs(SPEC_EXTRA_KICKS[specID]) do
                if extraSpec.talentCheck then
                    for j = #info.extraKicks, 1, -1 do
                        if info.extraKicks[j].spellID == extraSpec.id then
                            table.remove(info.extraKicks, j)
                            if spyMode then
                                print("|cFF00DDDD[SPY]|r Removed " ..
                                extraSpec.name .. " from " .. name .. " (re-inspecting)")
                            end
                        end
                    end
                end
            end
        end
        -- Check if this spec has NO interrupt
        if SPEC_NO_INTERRUPT[specID] then
            partyAddonUsers[name] = nil
            inspectedPlayers[name] = true
            noInterruptPlayers[name] = true
            if spyMode then
                print("|cFF00DDDD[SPY]|r " .. name .. " has no interrupt (specID=" .. specID .. ") → removed")
            end
            return
        end
        local override = SPEC_INTERRUPT_OVERRIDES[specID]
        if override then
            local applyOverride = true
            -- For pet-based overrides, check if the correct pet is active
            if override.isPet then
                -- Find the pet unit for this party member
                local petUnit = nil
                if unit == "player" then
                    petUnit = "pet"
                else
                    local idx = unit:match("party(%d)")
                    if idx then petUnit = "partypet" .. idx end
                end
                if petUnit and UnitExists(petUnit) then
                    local family = UnitCreatureFamily(petUnit)
                    -- Axe Toss = Felguard only. If Felhunter/Imp/etc, skip override
                    if override.id == 119914 and family and family ~= "Felguard" then
                        applyOverride = false
                        if spyMode then
                            print("|cFF00DDDD[SPY]|r Spec override " ..
                            override.name .. " SKIPPED for " .. name .. " (pet=" .. tostring(family) .. ", not Felguard)")
                        end
                    end
                elseif petUnit and not UnitExists(petUnit) then
                    -- No pet out → skip pet override
                    applyOverride = false
                    if spyMode then
                        print("|cFF00DDDD[SPY]|r Spec override " ..
                        override.name .. " SKIPPED for " .. name .. " (no pet)")
                    end
                end
            end
            if applyOverride then
                info.spellID = override.id
                info.baseCd = override.cd
                if spyMode then
                    print("|cFF00DDDD[SPY]|r Spec override for " ..
                    name .. ": " .. override.name .. " CD=" .. override.cd .. " (specID=" .. specID .. ")")
                end
            else
                -- Fall back to default warlock kick (Spell Lock)
                local fallbackID = 19647
                if ALL_INTERRUPTS[fallbackID] then
                    info.spellID = fallbackID
                    info.baseCd = ALL_INTERRUPTS[fallbackID].cd
                    if spyMode then
                        print("|cFF00DDDD[SPY]|r Fallback for " .. name .. ": Spell Lock CD=" .. info.baseCd)
                    end
                end
            end
        end
        -- Add extra kicks for this spec
        local extraSpecs = SPEC_EXTRA_KICKS[specID]
        if extraSpecs then
            if not info.extraKicks then info.extraKicks = {} end
            for _, extraSpec in ipairs(extraSpecs) do
                -- If talentCheck is set, skip here — will be added during talent tree scan
                if not extraSpec.talentCheck then
                    local found = false
                    for _, ek in ipairs(info.extraKicks) do
                        if ek.spellID == extraSpec.id then
                            found = true; break
                        end
                    end
                    if not found then
                        table.insert(info.extraKicks, {
                            spellID = extraSpec.id,
                            baseCd = extraSpec.cd,
                            cdEnd = 0,
                            name = extraSpec.name,
                            icon = extraSpec.icon,
                        })
                        if spyMode then
                            print("|cFF00FF00[SPY]|r " ..
                            name .. " spec extra kick: " .. extraSpec.name .. " CD=" .. extraSpec.cd .. "s")
                        end
                    end
                elseif spyMode then
                    print("|cFF00DDDD[SPY]|r " ..
                    name ..
                    " extra kick " ..
                    extraSpec.name .. " deferred to talent scan (check " .. extraSpec.talentCheck .. ")")
                end
            end
        end
    end

    -- 2) Scan talent tree for CD-reduction talents
    local configID = -1 -- Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID
    local ok, configInfo = pcall(C_Traits.GetConfigInfo, configID)
    if not ok or not configInfo or not configInfo.treeIDs or #configInfo.treeIDs == 0 then
        if spyMode then print("|cFF00DDDD[SPY]|r No trait config for " .. name) end
        return
    end

    local treeID = configInfo.treeIDs[1]
    local ok2, nodeIDs = pcall(C_Traits.GetTreeNodes, treeID)
    if not ok2 or not nodeIDs then
        if spyMode then print("|cFF00DDDD[SPY]|r No tree nodes for " .. name) end
        return
    end

    if spyMode then
        print("|cFF00DDDD[SPY]|r Scanning " .. #nodeIDs .. " talent nodes for " .. name)
    end

    for _, nodeID in ipairs(nodeIDs) do
        local ok3, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
        if ok3 and nodeInfo and nodeInfo.activeEntry and nodeInfo.activeRank and nodeInfo.activeRank > 0 then
            local entryID = nodeInfo.activeEntry.entryID
            if entryID then
                local ok4, entryInfo = pcall(C_Traits.GetEntryInfo, configID, entryID)
                if ok4 and entryInfo and entryInfo.definitionID then
                    local ok5, defInfo = pcall(C_Traits.GetDefinitionInfo, entryInfo.definitionID)
                    if ok5 and defInfo and defInfo.spellID then
                        -- Check passive CD reductions
                        local talent = CD_REDUCTION_TALENTS[defInfo.spellID]
                        if talent then
                            local newCd = info.baseCd - talent.reduction
                            if newCd < 1 then newCd = 1 end
                            info.baseCd = newCd
                            if spyMode then
                                print("|cFF00FF00[SPY]|r " ..
                                name .. " has |cFFFFFF00" .. talent.name .. "|r → CD adjusted to " .. newCd .. "s")
                            end
                        end
                        -- Check conditional CD reductions (on successful kick)
                        local onKick = CD_ON_KICK_TALENTS[defInfo.spellID]
                        if onKick then
                            info.onKickReduction = onKick.reduction
                            if spyMode then
                                print("|cFF00FF00[SPY]|r " ..
                                name ..
                                " has |cFFFFFF00" ..
                                onKick.name .. "|r → -" .. onKick.reduction .. "s on successful kick")
                            end
                        end
                        -- Check extra kick talents (second interrupt ability)
                        local extra = EXTRA_KICK_TALENTS[defInfo.spellID]
                        if extra then
                            if not info.extraKicks then info.extraKicks = {} end
                            table.insert(info.extraKicks, {
                                spellID = extra.id,
                                baseCd = extra.cd,
                                cdEnd = 0,
                                name = extra.name,
                            })
                            if spyMode then
                                print("|cFF00FF00[SPY]|r " ..
                                name .. " has |cFFFFFF00" .. extra.name .. "|r → extra kick CD=" .. extra.cd .. "s")
                            end
                        end
                        -- Check SPEC_EXTRA_KICKS with talentCheck (e.g., Grimoire: Fel Ravager)
                        if specID and SPEC_EXTRA_KICKS[specID] then
                            for _, extraSpec in ipairs(SPEC_EXTRA_KICKS[specID]) do
                                if extraSpec.talentCheck and extraSpec.talentCheck == defInfo.spellID then
                                    if not info.extraKicks then info.extraKicks = {} end
                                    local found = false
                                    for _, ek in ipairs(info.extraKicks) do
                                        if ek.spellID == extraSpec.id then
                                            found = true; break
                                        end
                                    end
                                    if not found then
                                        table.insert(info.extraKicks, {
                                            spellID = extraSpec.id,
                                            baseCd = extraSpec.cd,
                                            cdEnd = 0,
                                            name = extraSpec.name,
                                            icon = extraSpec.icon,
                                        })
                                        if spyMode then
                                            print("|cFF00FF00[SPY]|r " ..
                                            name ..
                                            " has talent " ..
                                            defInfo.spellID ..
                                            " → extra kick " .. extraSpec.name .. " CD=" .. extraSpec.cd .. "s")
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    inspectedPlayers[name] = true
    if spyMode then
        print("|cFF00DDDD[SPY]|r Inspect done for " ..
        name ..
        " → " .. (ALL_INTERRUPTS[info.spellID] and ALL_INTERRUPTS[info.spellID].name or "?") .. " CD=" .. info.baseCd)
    end
end

local function ProcessInspectQueue()
    if inspectBusy then return end
    while #inspectQueue > 0 do
        local unit = table.remove(inspectQueue, 1)
        if UnitExists(unit) and UnitIsConnected(unit) then
            local name = UnitName(unit)
            if name and not inspectedPlayers[name] then
                inspectBusy = true
                inspectUnit = unit
                NotifyInspect(unit)
                if spyMode then
                    print("|cFF00DDDD[SPY]|r NotifyInspect(" .. unit .. ") → " .. name)
                end
                return
            end
        end
    end
end

local function QueuePartyInspect()
    inspectQueue = {}
    for i = 1, 4 do
        local u = "party" .. i
        if UnitExists(u) then
            local name = UnitName(u)
            if name and not inspectedPlayers[name] then
                table.insert(inspectQueue, u)
            end
        end
    end
    ProcessInspectQueue()
end
------------------------------------------------------------
-- Compute bar layout from frame size
------------------------------------------------------------
local function GetBarLayout()
    local fw = db.frameWidth
    local titleH = db.showTitle and 20 or 0
    local barH = math.max(12, db.barHeight)
    local iconS = barH
    local barW = fw - iconS
    barW = math.max(60, barW)
    local fontSize = math.max(9, math.floor(barH * 0.45))
    local cdFontSize = math.max(10, math.floor(barH * 0.55))
    return barW, barH, iconS, fontSize, cdFontSize, titleH
end

------------------------------------------------------------
-- Rebuild bars
------------------------------------------------------------
local function RebuildBars()
    for i = 1, 7 do
        if bars[i] then
            bars[i]:Hide()
            bars[i]:SetParent(nil)
            bars[i] = nil
        end
    end

    local barW, barH, iconS, fontSize, cdFontSize, titleH = GetBarLayout()

    mainFrame:SetWidth(db.frameWidth)
    mainFrame:SetAlpha(db.alpha)

    if titleText then
        if db.showTitle then titleText:Show() else titleText:Hide() end
    end

    for i = 1, 7 do
        local yOff
        if db.growUp then
            yOff = (i - 1) * (barH + 1)
        else
            yOff = -(titleH + (i - 1) * (barH + 1))
        end

        local f = CreateFrame("Frame", nil, mainFrame)
        f:SetSize(iconS + barW, barH)
        if db.growUp then
            f:SetPoint("BOTTOMLEFT", 0, yOff)
        else
            f:SetPoint("TOPLEFT", 0, yOff)
        end

        -- Icon
        local ico = f:CreateTexture(nil, "ARTWORK")
        ico:SetSize(iconS, barH)
        ico:SetPoint("LEFT", 0, 0)
        ico:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        f.icon = ico

        -- Bar background
        local barBg = f:CreateTexture(nil, "BACKGROUND")
        barBg:SetPoint("TOPLEFT", iconS, 0)
        barBg:SetPoint("BOTTOMRIGHT", 0, 0)
        barBg:SetTexture(BAR_TEXTURE)
        barBg:SetVertexColor(0.15, 0.15, 0.15, 0.9)
        f.barBg = barBg

        -- StatusBar
        local sb = CreateFrame("StatusBar", nil, f)
        sb:SetPoint("TOPLEFT", iconS, 0)
        sb:SetPoint("BOTTOMRIGHT", 0, 0)
        sb:SetStatusBarTexture(BAR_TEXTURE)
        sb:SetStatusBarColor(1, 1, 1, 0.85)
        sb:SetMinMaxValues(0, 1)
        sb:SetValue(0)
        sb:SetFrameLevel(f:GetFrameLevel() + 1)
        f.cdBar = sb

        -- Content layer
        local content = CreateFrame("Frame", nil, f)
        content:SetPoint("TOPLEFT", iconS, 0)
        content:SetPoint("BOTTOMRIGHT", 0, 0)
        content:SetFrameLevel(sb:GetFrameLevel() + 1)

        -- Name text
        local nm = content:CreateFontString(nil, "OVERLAY")
        nm:SetFont(FONT_FACE, fontSize, FONT_FLAGS)
        nm:SetPoint("LEFT", 6, 0)
        nm:SetJustifyH("LEFT")
        nm:SetWidth(barW - 50)
        nm:SetWordWrap(false)
        nm:SetShadowOffset(1, -1)
        nm:SetShadowColor(0, 0, 0, 1)
        f.nameText = nm

        -- Party CD text
        local pcd = content:CreateFontString(nil, "OVERLAY")
        pcd:SetFont(FONT_FACE, cdFontSize, FONT_FLAGS)
        pcd:SetPoint("RIGHT", -6, 0)
        pcd:SetShadowOffset(1, -1)
        pcd:SetShadowColor(0, 0, 0, 1)
        f.partyCdText = pcd

        -- Player CD wrapper + text (taint-safe via SetAlphaFromBoolean)
        local wrap = CreateFrame("Frame", nil, content)
        wrap:SetAllPoints()
        wrap:SetFrameLevel(content:GetFrameLevel() + 1)
        local mycd = wrap:CreateFontString(nil, "OVERLAY")
        mycd:SetFont(FONT_FACE, cdFontSize, FONT_FLAGS)
        mycd:SetPoint("RIGHT", -6, 0)
        mycd:SetShadowOffset(1, -1)
        mycd:SetShadowColor(0, 0, 0, 1)
        f.playerCdWrapper = wrap
        f.playerCdText = mycd

        f:Hide()
        bars[i] = f
    end

    if resizeHandle then resizeHandle:Raise() end
end

------------------------------------------------------------
-- Display update
------------------------------------------------------------
local shouldShowByZone = true -- cached visibility state

local function CheckZoneVisibility()
    local _, instanceType = IsInInstance()
    if instanceType == "party" then
        shouldShowByZone = db.showInDungeon
    elseif instanceType == "raid" then
        shouldShowByZone = db.showInRaid
    elseif instanceType == "arena" then
        shouldShowByZone = db.showInArena
    elseif instanceType == "pvp" then
        shouldShowByZone = db.showInBG
    else
        shouldShowByZone = db.showInOpenWorld
    end
    if mainFrame then
        if shouldShowByZone then
            mainFrame:Show()
        else
            mainFrame:Hide()
        end
    end
end

local function UpdateDisplay()
    if not ready or not shouldShowByZone then return end

    local _, barH, _, _, _, titleH = GetBarLayout()
    local now = GetTime()
    local barIdx = 1

    -- Player bar (only if we have a kick)
    local mySpellData = mySpellID and ALL_INTERRUPTS[mySpellID]
    local isPetSpell = myIsPetSpell or (mySpellID and not IsSpellKnown(mySpellID) and IsSpellKnown(mySpellID, true))
    if mySpellData then
        local bar = bars[barIdx]
        bar:Show()
        -- Always use hardcoded icon (C_Spell.GetSpellTexture can return wrong icon for Command Demon variants)
        bar.icon:SetTexture(mySpellData.icon)
        local col = CLASS_COLORS[myClass] or { 1, 1, 1 }
        bar.nameText:SetText("|cFFFFFFFF" .. (myName or "?") .. "|r")

        if myKickCdEnd > now then
            bar.partyCdText:Hide()
            bar.playerCdText:Show()
            local cdRemaining = myKickCdEnd - now

            -- For player spells, try precise API
            if not isPetSpell then
                local ok1, result = pcall(function()
                    local cdInfo = C_Spell.GetSpellCooldown(mySpellID)
                    if cdInfo and cdInfo.startTime and cdInfo.duration and cdInfo.duration > 0 then
                        return (cdInfo.startTime + cdInfo.duration) - GetTime()
                    end
                    return nil
                end)
                if ok1 and result and result > 0 then
                    cdRemaining = result
                end
            end

            bar.playerCdText:SetText(string.format("%.0f", cdRemaining))
            bar.playerCdText:SetTextColor(1, 1, 1)
            bar.cdBar:SetMinMaxValues(0, myBaseCd or mySpellData.cd)
            bar.cdBar:SetValue(cdRemaining)
            bar.cdBar:SetStatusBarColor(col[1], col[2], col[3], 0.85)
            bar.barBg:SetVertexColor(col[1] * 0.25, col[2] * 0.25, col[3] * 0.25, 0.9)
            bar.playerCdWrapper:SetAlpha(1)
        else
            bar.playerCdText:Hide()
            bar.playerCdWrapper:SetAlpha(1)
            bar.partyCdText:Show()
            bar.partyCdText:SetText("READY")
            bar.partyCdText:SetTextColor(0.2, 1.0, 0.2)
            bar.cdBar:SetMinMaxValues(0, 1)
            bar.cdBar:SetValue(0)
            bar.barBg:SetVertexColor(col[1], col[2], col[3], 0.85)
        end
        barIdx = barIdx + 1
    end

    -- Own extra kick bars (e.g., Demo warlock Spell Lock + Fel Ravager)
    for ekKey, ekInfo in pairs(myExtraKicks) do
        if barIdx > 7 then break end
        local ekData = ALL_INTERRUPTS[ekKey] -- works for number keys
        local ekIcon = ekInfo.icon or (ekData and ekData.icon)
        local ekName = ekInfo.name or (ekData and ekData.name) or "?"
        if ekIcon or ekData then
            local bar = bars[barIdx]
            bar:Show()
            -- Always use hardcoded icon
            bar.icon:SetTexture(ekIcon or (ekData and ekData.icon))
            local col = CLASS_COLORS[myClass] or { 1, 1, 1 }
            bar.nameText:SetText("|cFFFFFFFF" .. (myName or "?") .. "|r")

            if ekInfo.cdEnd > now then
                local ekRem = ekInfo.cdEnd - now
                bar.partyCdText:Hide()
                bar.playerCdText:Show()
                bar.playerCdText:SetText(string.format("%.0f", ekRem))
                bar.playerCdText:SetTextColor(1, 1, 1)
                bar.cdBar:SetMinMaxValues(0, ekInfo.baseCd)
                bar.cdBar:SetValue(ekRem)
                bar.cdBar:SetStatusBarColor(col[1], col[2], col[3], 0.85)
                bar.barBg:SetVertexColor(col[1] * 0.25, col[2] * 0.25, col[3] * 0.25, 0.9)
                bar.playerCdWrapper:SetAlpha(1)
            else
                bar.playerCdText:Hide()
                bar.playerCdWrapper:SetAlpha(1)
                bar.partyCdText:Show()
                bar.partyCdText:SetText("READY")
                bar.partyCdText:SetTextColor(0.2, 1.0, 0.2)
                bar.cdBar:SetMinMaxValues(0, 1)
                bar.cdBar:SetValue(0)
                bar.barBg:SetVertexColor(col[1], col[2], col[3], 0.85)
            end
            barIdx = barIdx + 1
        end
    end

    -- Party bars (clean values)
    for name, info in pairs(partyAddonUsers) do
        if barIdx > 7 then break end
        local data = ALL_INTERRUPTS[info.spellID]
        if data then
            local bar = bars[barIdx]
            bar:Show()
            -- Always use hardcoded icon
            bar.icon:SetTexture(data.icon)
            local col = CLASS_COLORS[info.class] or { 1, 1, 1 }

            bar.playerCdText:Hide()
            bar.playerCdWrapper:SetAlpha(1)
            bar.partyCdText:Show()
            bar.nameText:SetText("|cFFFFFFFF" .. name .. "|r")

            local rem = 0
            if info.cdEnd > now then rem = info.cdEnd - now end

            bar.cdBar:SetMinMaxValues(0, info.baseCd or data.cd)

            if rem > 0.5 then
                bar.cdBar:SetValue(rem)
                bar.cdBar:SetStatusBarColor(col[1], col[2], col[3], 0.85)
                bar.barBg:SetVertexColor(col[1] * 0.25, col[2] * 0.25, col[3] * 0.25, 0.9)
                bar.partyCdText:SetText(string.format("%.0f", rem))
                bar.partyCdText:SetTextColor(1, 1, 1)
            else
                bar.cdBar:SetValue(0)
                bar.barBg:SetVertexColor(col[1], col[2], col[3], 0.85)
                bar.partyCdText:SetText("READY")
                bar.partyCdText:SetTextColor(0.2, 1.0, 0.2)
            end

            barIdx = barIdx + 1
        end

        -- Extra kick bars for this player (e.g., Demo warlock Grimoire: Fel Ravager)
        if info.extraKicks then
            local col = CLASS_COLORS[info.class] or { 1, 1, 1 }
            for _, ek in ipairs(info.extraKicks) do
                if barIdx > 7 then break end
                local ekData = ek.spellID and ALL_INTERRUPTS[ek.spellID]
                local ekIcon = ek.icon or (ekData and ekData.icon)
                if ekIcon or ekData then
                    local bar = bars[barIdx]
                    bar:Show()
                    bar.icon:SetTexture(ekIcon or ekData.icon)
                    bar.playerCdText:Hide()
                    bar.playerCdWrapper:SetAlpha(1)
                    bar.partyCdText:Show()
                    bar.nameText:SetText("|cFFFFFFFF" .. name .. "|r")

                    local ekRem = 0
                    if ek.cdEnd > now then ekRem = ek.cdEnd - now end
                    bar.cdBar:SetMinMaxValues(0, ek.baseCd)

                    if ekRem > 0.5 then
                        bar.cdBar:SetValue(ekRem)
                        bar.cdBar:SetStatusBarColor(col[1], col[2], col[3], 0.85)
                        bar.barBg:SetVertexColor(col[1] * 0.25, col[2] * 0.25, col[3] * 0.25, 0.9)
                        bar.partyCdText:SetText(string.format("%.0f", ekRem))
                        bar.partyCdText:SetTextColor(1, 1, 1)
                    else
                        bar.cdBar:SetValue(0)
                        bar.barBg:SetVertexColor(col[1], col[2], col[3], 0.85)
                        bar.partyCdText:SetText("READY")
                        bar.partyCdText:SetTextColor(0.2, 1.0, 0.2)
                    end
                    barIdx = barIdx + 1
                end
            end
        end
    end

    for i = barIdx, 7 do bars[i]:Hide() end

    -- Auto-fit height to visible bars (skip during resize)
    if not isResizing then
        local numVisible = barIdx - 1
        if numVisible > 0 then
            mainFrame:SetHeight(titleH + numVisible * (barH + 1) + 2)
        end
    end
end

------------------------------------------------------------
-- Find my interrupt spell (check all possible for class/spec)
------------------------------------------------------------
local function FindMyInterrupt()
    local oldSpellID = mySpellID
    mySpellID = nil
    myIsPetSpell = false
    -- Preserve existing cdEnd values
    local oldExtraKicks = myExtraKicks
    myExtraKicks = {}

    -- Check if my spec has no interrupt (e.g., Resto Druid, Holy Priest)
    local specIndex = GetSpecialization()
    local specID = nil
    if specIndex then
        specID = GetSpecializationInfo(specIndex)
        if specID and SPEC_NO_INTERRUPT[specID] then
            if spyMode then
                print("|cFF00DDDD[SPY]|r My spec " .. specID .. " has no interrupt")
            end
            mySpellID = nil
            if oldSpellID then
                myCachedCD = nil; myBaseCd = nil
            end
            return
        end
    end

    -- Spec override for primary kick (e.g., Demo warlock → Axe Toss)
    if specID and SPEC_INTERRUPT_OVERRIDES[specID] then
        local override = SPEC_INTERRUPT_OVERRIDES[specID]
        -- For pet spells, verify the pet actually has this spell
        if override.isPet then
            local petKnown = IsSpellKnown(override.id, true)
            if petKnown then
                mySpellID = override.id
                myBaseCd = override.cd
                myIsPetSpell = true
                if spyMode then
                    print("|cFF00DDDD[SPY]|r My spec override: " ..
                    override.name .. " CD=" .. override.cd .. " (pet has spell)")
                end
            else
                if spyMode then
                    print("|cFF00DDDD[SPY]|r Spec override " ..
                    override.name .. " SKIPPED (pet doesn't have it - wrong pet type?)")
                end
            end
        else
            mySpellID = override.id
            myBaseCd = override.cd
            myIsPetSpell = false
            if spyMode then
                print("|cFF00DDDD[SPY]|r My spec override: " .. override.name .. " CD=" .. override.cd)
            end
        end
    end

    -- Pre-add extra kicks by spec (only if the talent is actually known)
    if specID and SPEC_EXTRA_KICKS[specID] then
        for _, extra in ipairs(SPEC_EXTRA_KICKS[specID]) do
            -- If talentCheck is set, check that spell instead (e.g., check Grimoire: Fel Ravager talent, not Spell Lock)
            local checkID = extra.talentCheck or extra.id
            local known = IsSpellKnown(checkID) or IsSpellKnown(checkID, true)
            if not known then
                local ok, result = pcall(IsPlayerSpell, checkID)
                if ok and result then known = true end
            end
            if known then
                local oldCdEnd = oldExtraKicks[extra.id] and oldExtraKicks[extra.id].cdEnd or 0
                myExtraKicks[extra.id] = {
                    baseCd = extra.cd,
                    cdEnd = oldCdEnd,
                    name = extra.name,
                    icon = extra.icon,
                    talentCheck = extra.talentCheck,
                }
                if spyMode then
                    print("|cFF00DDDD[SPY]|r My spec extra kick: " ..
                    extra.name .. " CD=" .. extra.cd .. " (talent " .. checkID .. " known)")
                end
            elseif spyMode then
                print("|cFF00DDDD[SPY]|r Spec extra kick " ..
                extra.name .. " NOT known (talent " .. checkID .. " missing)")
            end
        end
    end

    -- Build set of spell IDs managed by SPEC_EXTRA_KICKS (skip them in auto-detect)
    local specManagedSpells = {}
    if specID and SPEC_EXTRA_KICKS[specID] then
        for _, extra in ipairs(SPEC_EXTRA_KICKS[specID]) do
            specManagedSpells[extra.id] = true
        end
    end

    local spellList = CLASS_INTERRUPT_LIST[myClass]
    if not spellList then return end

    -- Find primary kick (if not set by spec override) and extra kicks
    for _, sid in ipairs(spellList) do
        local known = IsSpellKnown(sid) or IsSpellKnown(sid, true)
        -- Also try IsPlayerSpell for talent-granted abilities
        if not known then
            local ok, result = pcall(IsPlayerSpell, sid)
            if ok and result then known = true end
        end
        if known then
            if not mySpellID then
                mySpellID = sid
            elseif sid ~= mySpellID and not myExtraKicks[sid] and not specManagedSpells[sid] then
                -- Don't add spells managed by SPEC_EXTRA_KICKS (talent check handles those)
                local data = ALL_INTERRUPTS[sid]
                if data then
                    local oldCdEnd = oldExtraKicks[sid] and oldExtraKicks[sid].cdEnd or 0
                    myExtraKicks[sid] = { baseCd = data.cd, cdEnd = oldCdEnd }
                    if spyMode then
                        print("|cFF00DDDD[SPY]|r Found extra kick: " .. data.name .. " CD=" .. data.cd)
                    end
                end
            end
        end
    end

    -- Cache correct icon for pet spells using C_Spell on the actual pet version
    -- 119914 = Command Demon wrapper, 89766 = actual Axe Toss pet spell
    local PET_SPELL_ICONS = {
        [119914] = 89766, -- Axe Toss: use pet version for correct icon
    }
    if mySpellID and PET_SPELL_ICONS[mySpellID] and ALL_INTERRUPTS[mySpellID] then
        local petSpellID = PET_SPELL_ICONS[mySpellID]
        local ok, tex = pcall(C_Spell.GetSpellTexture, petSpellID)
        if ok and tex then
            ALL_INTERRUPTS[mySpellID].icon = tex
            if spyMode then
                print("|cFF00DDDD[SPY]|r Cached icon for " ..
                mySpellID .. " from pet spell " .. petSpellID .. " → " .. tostring(tex))
            end
        end
    end

    -- Only reset cached CD if spell changed
    if mySpellID ~= oldSpellID then
        myCachedCD = nil
        if not myBaseCd and mySpellID then ReadMyBaseCd() end
    end
end

------------------------------------------------------------
-- Config panel
------------------------------------------------------------
local function CreateCheckbox(parent, label, x, y, key)
    local cb = CreateFrame("CheckButton", "MIT_Check_" .. key, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb.Text:SetText(label)
    cb:SetChecked(db[key])
    cb:SetScript("OnClick", function(self)
        db[key] = self:GetChecked() and true or false
        RebuildBars()
    end)
    return cb
end

local function CreateConfigPanel()
    if configFrame then
        if configFrame:IsShown() then configFrame:Hide() else configFrame:Show() end
        return
    end

    configFrame = CreateFrame("Frame", "MITConfigFrame", UIParent)
    configFrame:SetSize(280, 340)
    configFrame:SetPoint("CENTER")
    configFrame:SetFrameStrata("DIALOG")
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
    configFrame:SetClampedToScreen(true)

    -- Background
    local bg = configFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(FLAT_TEX)
    bg:SetVertexColor(0.08, 0.08, 0.08, 0.95)

    -- Borders
    local function Border(p1, r1, p2, r2, w, h)
        local b = configFrame:CreateTexture(nil, "BORDER")
        b:SetTexture(FLAT_TEX)
        b:SetVertexColor(0.3, 0.8, 0.9, 0.8)
        b:SetPoint(p1, configFrame, r1)
        b:SetPoint(p2, configFrame, r2)
        if w then b:SetWidth(w) end
        if h then b:SetHeight(h) end
    end
    Border("TOPLEFT", "TOPLEFT", "TOPRIGHT", "TOPRIGHT", nil, 1)
    Border("BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT", nil, 1)
    Border("TOPLEFT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMLEFT", 1, nil)
    Border("TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMRIGHT", 1, nil)

    -- Title
    local title = configFrame:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT_FACE, 16, FONT_FLAGS)
    title:SetPoint("TOP", 0, -12)
    title:SetText("|cFF00DDDDM+ Interrupt Tracker|r |cFF888888Settings|r")

    -- Close
    local closeBtn = CreateFrame("Button", nil, configFrame)
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY")
    closeTxt:SetFont(FONT_FACE, 14, FONT_FLAGS)
    closeTxt:SetAllPoints()
    closeTxt:SetText("|cFFFF4444X|r")
    closeBtn:SetScript("OnClick", function() configFrame:Hide() end)

    -- Separator
    local sep = configFrame:CreateTexture(nil, "ARTWORK")
    sep:SetTexture(FLAT_TEX)
    sep:SetVertexColor(0.3, 0.3, 0.3, 0.5)
    sep:SetPoint("TOPLEFT", 10, -36)
    sep:SetPoint("TOPRIGHT", -10, -36)
    sep:SetHeight(1)

    -- Opacity slider
    local alphaSlider = CreateFrame("Slider", "MIT_Slider_alpha", configFrame, "OptionsSliderTemplate")
    alphaSlider:SetPoint("TOPLEFT", 40, -55)
    alphaSlider:SetSize(200, 18)
    alphaSlider:SetMinMaxValues(0.3, 1.0)
    alphaSlider:SetValueStep(0.05)
    alphaSlider:SetObeyStepOnDrag(true)
    alphaSlider:SetValue(db.alpha)
    alphaSlider.Text:SetText("Opacity: " .. string.format("%.0f%%", db.alpha * 100))
    alphaSlider.Low:SetText("30%")
    alphaSlider.High:SetText("100%")
    alphaSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 20 + 0.5) / 20
        db.alpha = value
        self.Text:SetText("Opacity: " .. string.format("%.0f%%", value * 100))
        if mainFrame then mainFrame:SetAlpha(value) end
    end)

    -- Scale slider
    -- (removed - auto-scales based on resolution)

    -- Checkboxes - Display
    CreateCheckbox(configFrame, "Show Title", 20, -95, "showTitle")
    CreateCheckbox(configFrame, "Grow Upward", 20, -125, "growUp")
    CreateCheckbox(configFrame, "Lock Position", 20, -155, "locked")

    -- Separator
    local sep2 = configFrame:CreateTexture(nil, "ARTWORK")
    sep2:SetTexture(FLAT_TEX)
    sep2:SetVertexColor(0.3, 0.3, 0.3, 0.5)
    sep2:SetPoint("TOPLEFT", 10, -182)
    sep2:SetPoint("TOPRIGHT", -10, -182)
    sep2:SetHeight(1)

    -- Visibility header
    local visLabel = configFrame:CreateFontString(nil, "OVERLAY")
    visLabel:SetFont(FONT_FACE, 11, FONT_FLAGS)
    visLabel:SetPoint("TOPLEFT", 20, -190)
    visLabel:SetText("|cFFFFFF00Show In:|r")

    -- Visibility checkboxes (use a special version that calls CheckZoneVisibility)
    local function VisCheck(parent, label, x, y, key)
        local cb = CreateFrame("CheckButton", "MIT_cb_" .. key, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", x, y)
        cb.text:SetFont(FONT_FACE, 11, FONT_FLAGS)
        cb.text:SetText("|cFFCCCCCC" .. label .. "|r")
        cb:SetChecked(db[key])
        cb:SetScript("OnClick", function(self)
            db[key] = self:GetChecked() and true or false
            CheckZoneVisibility()
        end)
        return cb
    end

    VisCheck(configFrame, "Dungeons", 20, -210, "showInDungeon")
    VisCheck(configFrame, "Raids", 140, -210, "showInRaid")
    VisCheck(configFrame, "Open World", 20, -238, "showInOpenWorld")
    VisCheck(configFrame, "Arena", 140, -238, "showInArena")
    VisCheck(configFrame, "Battlegrounds", 20, -266, "showInBG")

    -- Info
    local info = configFrame:CreateFontString(nil, "OVERLAY")
    info:SetFont(FONT_FACE, 10, FONT_FLAGS)
    info:SetPoint("BOTTOMLEFT", 10, 36)
    info:SetText("|cFFAAAADDDrag bottom-right corner to resize tracker|r")

    -- ElvUI
    local elv = configFrame:CreateFontString(nil, "OVERLAY")
    elv:SetFont(FONT_FACE, 10, FONT_FLAGS)
    elv:SetPoint("BOTTOMLEFT", 10, 22)
    if ElvUI then
        elv:SetText("|cFF00FF00ElvUI detected|r")
    else
        elv:SetText("|cFF888888ElvUI not detected|r")
    end

    -- Reset
    local resetBtn = CreateFrame("Button", nil, configFrame)
    resetBtn:SetSize(100, 22)
    resetBtn:SetPoint("BOTTOM", 0, 6)
    local resetBg = resetBtn:CreateTexture(nil, "BACKGROUND")
    resetBg:SetAllPoints()
    resetBg:SetTexture(FLAT_TEX)
    resetBg:SetVertexColor(0.3, 0.1, 0.1, 0.9)
    local resetTxt = resetBtn:CreateFontString(nil, "OVERLAY")
    resetTxt:SetFont(FONT_FACE, 11, FONT_FLAGS)
    resetTxt:SetAllPoints()
    resetTxt:SetText("|cFFFF8888Reset|r")
    resetBtn:SetScript("OnClick", function()
        for k, v in pairs(DEFAULTS) do db[k] = v end
        ApplyAutoScale()
        CheckZoneVisibility()
        configFrame:Hide()
        configFrame = nil
        RebuildBars()
        CreateConfigPanel()
    end)

    configFrame:Show()
end

------------------------------------------------------------
-- Create main frame + resize handle (from ADDON_LOADED)
------------------------------------------------------------
local function CreateUI()
    mainFrame = CreateFrame("Frame", "MITMainFrame", UIParent)
    mainFrame:SetSize(db.frameWidth, 200)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(self)
        if not db.locked then self:StartMoving() end
    end)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    mainFrame:SetAlpha(db.alpha)
    mainFrame:SetResizable(true)
    mainFrame:SetResizeBounds(80, 40, 600, 600)

    -- Background
    local bg = mainFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(FLAT_TEX)
    bg:SetVertexColor(0.05, 0.05, 0.05, 0.85)

    -- Title
    titleText = mainFrame:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(FONT_FACE, 12, FONT_FLAGS)
    titleText:SetPoint("TOP", 0, -3)
    titleText:SetText("|cFF00DDDDInterrupts|r")
    if not db.showTitle then titleText:Hide() end

    -- Resize handle (bottom-right corner)
    resizeHandle = CreateFrame("Button", nil, mainFrame)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", 0, 0)
    resizeHandle:SetFrameLevel(mainFrame:GetFrameLevel() + 10)
    resizeHandle:EnableMouse(true)

    -- Grip lines
    for j = 0, 2 do
        local line = resizeHandle:CreateTexture(nil, "OVERLAY", nil, 1)
        line:SetTexture(FLAT_TEX)
        line:SetVertexColor(0.6, 0.8, 0.9, 0.7)
        line:SetSize(1, (3 - j) * 4)
        line:SetPoint("BOTTOMRIGHT", -(j * 4 + 2), 2)
    end

    resizeHandle:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not db.locked then
            isResizing = true
            mainFrame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeHandle:SetScript("OnMouseUp", function()
        mainFrame:StopMovingOrSizing()
        isResizing = false
        db.frameWidth = math.floor(mainFrame:GetWidth())
        -- Count visible bars
        local numVisible = 0
        for i = 1, 7 do
            if bars[i] and bars[i]:IsShown() then numVisible = numVisible + 1 end
        end
        if numVisible < 1 then numVisible = 1 end
        -- Derive bar height from dragged height / actual visible bars
        local titleH = db.showTitle and 20 or 0
        local dragH = mainFrame:GetHeight() - titleH - 2
        local newBarH = math.floor(dragH / numVisible) - 1
        db.barHeight = math.max(12, newBarH)
        RebuildBars()
    end)

    mainFrame:Show()
    RebuildBars()
end

------------------------------------------------------------
-- Slash commands
------------------------------------------------------------
local function SetupSlash()
    SLASH_MIT1 = "/mit"
    SlashCmdList["MIT"] = function(msg)
        local cmd = (msg or ""):lower():trim()
        if cmd == "show" then
            if mainFrame then mainFrame:Show() end
        elseif cmd == "hide" then
            if mainFrame then mainFrame:Hide() end
        elseif cmd == "config" or cmd == "options" or cmd == "settings" then
            CreateConfigPanel()
        elseif cmd == "lock" then
            db.locked = true
            print("|cFF00DDDD[MIT]|r Locked")
        elseif cmd == "unlock" then
            db.locked = false
            print("|cFF00DDDD[MIT]|r Unlocked")
        elseif cmd == "test" then
            if testMode then
                -- Stop test
                testMode = false
                if testTicker then
                    testTicker:Cancel()
                    testTicker = nil
                end
                partyAddonUsers = {}
                print("|cFF00DDDD[MIT]|r Test mode |cFFFF4444OFF|r")
            else
                -- Start test with fake players
                testMode = true
                partyAddonUsers = {
                    ["Thralldk"] = { class = "DEATHKNIGHT", spellID = 47528, baseCd = 15, cdEnd = 0 },
                    ["Jainalee"] = { class = "MAGE", spellID = 2139, baseCd = 20, cdEnd = 0 },
                    ["Sylvanash"] = { class = "ROGUE", spellID = 1766, baseCd = 15, cdEnd = 0 },
                }
                -- Simulate random kicks
                testTicker = C_Timer.NewTicker(2, function()
                    if not testMode then return end
                    for name, info in pairs(partyAddonUsers) do
                        local now = GetTime()
                        if info.cdEnd < now and math.random() < 0.3 then
                            info.cdEnd = now + info.baseCd
                        end
                    end
                end)
                print("|cFF00DDDD[MIT]|r Test mode |cFF00FF00ON|r - 3 fake players. /mit test to stop.")
            end
        elseif cmd == "ping" then
            print("|cFF00DDDD[MIT]|r === PING ===")
            print("  IsInInstance: " .. tostring(IsInInstance()))
            C_ChatInfo.RegisterAddonMessagePrefix(MSG_PREFIX)
            -- Test PARTY
            local ok1, ret1 = pcall(C_ChatInfo.SendAddonMessage, MSG_PREFIX, "PING:PARTY", "PARTY")
            print("  PARTY -> ok=" .. tostring(ok1) .. " ret=" .. tostring(ret1))
            -- Test WHISPER to each party member
            for i = 1, 4 do
                local unit = "party" .. i
                if UnitExists(unit) then
                    local ok, name, realm = pcall(UnitFullName, unit)
                    if ok and name then
                        local target = (realm and realm ~= "") and (name .. "-" .. realm) or name
                        local ok2, ret2 = pcall(C_ChatInfo.SendAddonMessage, MSG_PREFIX, "PING:WHISPER", "WHISPER",
                            target)
                        print("  WHISPER " .. target .. " -> ok=" .. tostring(ok2) .. " ret=" .. tostring(ret2))
                    end
                end
            end
            print("  Waiting for echo...")
        elseif cmd == "spy" then
            if spyMode then
                spyMode = false
                print("|cFF00DDDD[MIT]|r Spy mode |cFFFF4444OFF|r")
            else
                spyMode = true
                spyCastCount = 0
                print("|cFF00DDDD[MIT]|r Spy mode |cFF00FF00ON|r")
                -- Check watcher status
                for i = 1, 4 do
                    local unit = "party" .. i
                    local exists = UnitExists(unit)
                    local name = exists and UnitName(unit) or "?"
                    local hasFrame = partyFrames[i] ~= nil
                    local isReg = hasFrame and partyFrames[i]:IsEventRegistered("UNIT_SPELLCAST_SUCCEEDED")
                    print("  " ..
                    unit ..
                    ": exists=" ..
                    tostring(exists) ..
                    " name=" .. tostring(name) .. " frame=" .. tostring(hasFrame) .. " registered=" .. tostring(isReg))
                end
                print("  Ask your mate to cast ANY spell")
                -- Force re-register watchers
                RegisterPartyWatchers()
                AutoRegisterPartyByClass()
                inspectedPlayers = {} -- reset to re-inspect
                noInterruptPlayers = {}
                QueuePartyInspect()
                print("  Watchers re-registered! Inspecting talents...")
            end
        elseif cmd == "debug" then
            print("|cFF00DDDD[MIT]|r v" ..
            MIT_VERSION .. " | " .. tostring(myClass) .. " | CD cached: " .. tostring(myCachedCD))
            for name, info in pairs(partyAddonUsers) do
                local rem = info.cdEnd - GetTime()
                if rem < 0 then rem = 0 end
                local spellName = ALL_INTERRUPTS[info.spellID] and ALL_INTERRUPTS[info.spellID].name or "?"
                local inspected = inspectedPlayers[name] and "inspected" or "not inspected"
                print(string.format("  %s (%s) %s CD=%.0f rem=%.1f [%s]", name, info.class, spellName, info.baseCd, rem,
                    inspected))
            end
        elseif cmd == "help" then
            print("|cFF00DDDD[MIT]|r /mit (options) | show | hide | lock | unlock | test | spy | debug")
        else
            -- Default: open config
            CreateConfigPanel()
        end
    end
end

------------------------------------------------------------
-- Initialize
------------------------------------------------------------
local function RegisterBlizzardOptions()
    local panel = CreateFrame("Frame")
    panel.name = "Mythic+ Interrupt Tracker"

    local yOff = -16

    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, yOff)
    title:SetText("|cFF00DDDDMythic+ Interrupt Tracker|r")
    yOff = yOff - 30

    -- Helper: create a checkbox
    local function MakeCheck(label, dbKey, y)
        local cb = CreateFrame("CheckButton", "MIT_Blizz_" .. dbKey, panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 16, y)
        cb.Text:SetText(label)
        cb:SetChecked(db[dbKey])
        cb:SetScript("OnClick", function(self)
            db[dbKey] = self:GetChecked()
            if dbKey == "showTitle" or dbKey == "growUp" then
                RebuildBars()
            end
            if dbKey:find("^show") then
                CheckZoneVisibility()
            end
        end)
        return cb
    end

    -- Display section
    local displayHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    displayHeader:SetPoint("TOPLEFT", 16, yOff)
    displayHeader:SetText("|cFFFFFF00Display|r")
    yOff = yOff - 25

    MakeCheck("Show Title Bar", "showTitle", yOff)
    yOff = yOff - 28
    MakeCheck("Grow Upward", "growUp", yOff)
    yOff = yOff - 28
    MakeCheck("Lock Position", "locked", yOff)
    yOff = yOff - 40

    -- Visibility section
    local visHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    visHeader:SetPoint("TOPLEFT", 16, yOff)
    visHeader:SetText("|cFFFFFF00Show In|r")
    yOff = yOff - 25

    MakeCheck("Dungeons (M+ & Heroic)", "showInDungeon", yOff)
    yOff = yOff - 28
    MakeCheck("Raids", "showInRaid", yOff)
    yOff = yOff - 28
    MakeCheck("Open World", "showInOpenWorld", yOff)
    yOff = yOff - 28
    MakeCheck("Arena", "showInArena", yOff)
    yOff = yOff - 28
    MakeCheck("Battlegrounds", "showInBG", yOff)
    yOff = yOff - 40

    -- Opacity slider
    local opacityLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    opacityLabel:SetPoint("TOPLEFT", 16, yOff)
    opacityLabel:SetText("|cFFFFFF00Opacity|r")
    yOff = yOff - 25

    local alphaSlider = CreateFrame("Slider", "MIT_Blizz_Alpha", panel, "OptionsSliderTemplate")
    alphaSlider:SetPoint("TOPLEFT", 20, yOff)
    alphaSlider:SetSize(250, 18)
    alphaSlider:SetMinMaxValues(0.3, 1.0)
    alphaSlider:SetValueStep(0.05)
    alphaSlider:SetObeyStepOnDrag(true)
    alphaSlider:SetValue(db.alpha)
    alphaSlider.Text:SetText(string.format("%.0f%%", db.alpha * 100))
    alphaSlider.Low:SetText("30%")
    alphaSlider.High:SetText("100%")
    alphaSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 20 + 0.5) / 20
        db.alpha = value
        self.Text:SetText(string.format("%.0f%%", value * 100))
        if mainFrame then mainFrame:SetAlpha(value) end
    end)

    -- Register with Settings API (TWW 12.0+)
    if Settings and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        category.ID = "MythicInterruptTracker"
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

local function ApplyAutoScale()
    if not mainFrame then return end
    -- Auto-scale based on screen resolution
    -- Reference: 1080p = scale 1.0
    local _, screenHeight = GetPhysicalScreenSize()
    local scale = 1.0
    if screenHeight and screenHeight > 0 then
        scale = screenHeight / 1080
        -- Clamp between 0.6 and 2.0
        if scale < 0.6 then scale = 0.6 end
        if scale > 2.0 then scale = 2.0 end
    end
    mainFrame:SetScale(scale)
end

local function Initialize()
    MITSavedVars = MITSavedVars or {}
    db = MITSavedVars
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end

    C_ChatInfo.RegisterAddonMessagePrefix(MSG_PREFIX)

    local _, cls = UnitClass("player")
    myClass = cls
    myName = UnitName("player")

    DetectElvUI()
    CreateUI()
    ApplyAutoScale()
    RegisterBlizzardOptions()
    SetupSlash()
    FindMyInterrupt()

    ready = true

    if updateTicker then updateTicker:Cancel() end
    updateTicker = C_Timer.NewTicker(0.1, UpdateDisplay)

    -- Periodic re-inspect to detect talent changes on party members (every 30s)
    C_Timer.NewTicker(30, function()
        if not IsInGroup() then return end
        -- Reset inspected flags so next QueuePartyInspect re-checks talents
        for name in pairs(inspectedPlayers) do
            inspectedPlayers[name] = nil
        end
        QueuePartyInspect()
    end)

    C_Timer.After(2, AnnounceJoin)
    print("|cFF00DDDD[M+ Interrupt Tracker]|r v" .. MIT_VERSION .. " | /mit")
end

------------------------------------------------------------
-- MAIN CHUNK (DO NOT TOUCH)
------------------------------------------------------------
local ef = CreateFrame("Frame")
ef:RegisterEvent("ADDON_LOADED")
ef:RegisterEvent("GROUP_ROSTER_UPDATE")
ef:RegisterEvent("PLAYER_ENTERING_WORLD")
ef:RegisterEvent("CHAT_MSG_ADDON")
ef:RegisterEvent("CHAT_MSG_ADDON_LOGGED")
ef:RegisterEvent("SPELL_UPDATE_COOLDOWN")
ef:RegisterEvent("SPELLS_CHANGED")
ef:RegisterEvent("PLAYER_REGEN_ENABLED")
ef:RegisterEvent("INSPECT_READY")
ef:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ef:RegisterEvent("UNIT_PET")
ef:RegisterEvent("ROLE_CHANGED_INFORM")

-- Player's own casts: separate frame with unit filter
local playerCastFrame = CreateFrame("Frame")
playerCastFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
playerCastFrame:SetScript("OnEvent", function(_, _, unit, castGUID, spellID)
    -- Debug: log all player/pet casts in spy mode
    if spyMode and unit == "player" then
        local isInterrupt = ALL_INTERRUPTS[spellID] and "YES" or "no"
        local isExtra = myExtraKicks[spellID] and "YES" or "no"
        print("|cFF00DDDD[SPY]|r PLAYER cast spellID=" ..
        tostring(spellID) .. " interrupt=" .. isInterrupt .. " extra=" .. isExtra)
    end

    if unit == "pet" then
        if spyMode then
            print("|cFF00DDDD[SPY]|r PET cast detected on unit=pet")
        end

        -- Launder spellID to see what it is
        onValueChangedResult = nil
        launderBar:SetValue(0)
        pcall(launderBar.SetValue, launderBar, spellID)
        local cleanID = onValueChangedResult

        if spyMode then
            local idStr = "nil"
            if cleanID then
                local ok, s = pcall(tostring, cleanID)
                idStr = ok and s or "tainted"
            end
            print("|cFF00DDDD[SPY]|r   pet bar_cb=" .. idStr .. " mySpellID=" .. tostring(mySpellID))
        end

        -- Try direct access first
        local directOk, directData = pcall(function() return ALL_INTERRUPTS[spellID] end)
        local matchedDirect = directOk and directData

        -- If direct fails, try laundered
        local data = nil
        local usedID = nil
        if matchedDirect then
            data = directData
            usedID = spellID
        elseif cleanID then
            local ok2, d = pcall(function() return ALL_INTERRUPTS[cleanID] end)
            if ok2 and d then
                data = d
                usedID = cleanID
            end
        end

        if data then
            -- Check if it's an extra kick
            local isExtra = false
            for ekID, ekInfo in pairs(myExtraKicks) do
                if usedID == ekID then
                    ekInfo.cdEnd = GetTime() + ekInfo.baseCd
                    isExtra = true
                    if spyMode then
                        print("|cFF00DDDD[SPY]|r   → EXTRA kick: " .. data.name .. " CD=" .. ekInfo.baseCd)
                    end
                    break
                end
            end
            if not isExtra then
                -- Auto-add as extra if different from primary
                if mySpellID and usedID ~= mySpellID then
                    myExtraKicks[usedID] = { baseCd = data.cd, cdEnd = GetTime() + data.cd }
                    if spyMode then
                        print("|cFF00DDDD[SPY]|r   → AUTO-ADDED extra kick: " .. data.name .. " CD=" .. data.cd)
                    end
                else
                    local cd = myCachedCD or myBaseCd or data.cd
                    myKickCdEnd = GetTime() + cd
                    if spyMode then
                        print("|cFF00DDDD[SPY]|r   → PRIMARY kick: " .. data.name .. " CD=" .. cd)
                    end
                end
            end
        elseif spyMode then
            print("|cFF00DDDD[SPY]|r   → not a known interrupt")
        end
    else
        OnSpellCastSucceeded(unit, castGUID, spellID, false)
    end
end)


-- Track recent party casts for correlation (timestamp per player name)
local recentPartyCasts = {}

-- Handler for mob interrupt detection
local function OnMobInterrupted(unit)
    if spyMode then
        print("|cFF00DDDD[SPY-MOB]|r INTERRUPTED on " .. tostring(unit))
    end

    -- A mob was interrupted! Find who kicked via time correlation
    local now = GetTime()
    local bestName = nil
    local bestDelta = 999

    for name, ts in pairs(recentPartyCasts) do
        local delta = now - ts
        if delta > 1.0 then
            recentPartyCasts[name] = nil
        elseif delta < bestDelta then
            bestDelta = delta
            bestName = name
        end
    end

    if bestName and bestDelta < 0.5 then
        if spyMode then
            print("  |cFF00FF00>>> " ..
            bestName .. " kicked successfully! (delta=" .. string.format("%.3f", bestDelta) .. "s)|r")
        end

        if partyAddonUsers[bestName] then
            local info = partyAddonUsers[bestName]
            -- Apply conditional CD reduction (e.g., Coldthirst: -3s on successful kick)
            if info.onKickReduction then
                local newCdEnd = info.cdEnd - info.onKickReduction
                if newCdEnd < now then newCdEnd = now end
                info.cdEnd = newCdEnd
                if spyMode then
                    local rem = newCdEnd - now
                    print("  |cFFFFFF00Coldthirst! CD reduced by " ..
                    info.onKickReduction .. "s → " .. string.format("%.0f", rem) .. "s remaining|r")
                end
            end
        else
            -- Auto-register via class
            if not noInterruptPlayers[bestName] then
                for idx = 1, 4 do
                    local u = "party" .. idx
                    if UnitExists(u) and UnitName(u) == bestName then
                        local _, cls = UnitClass(u)
                        local role = UnitGroupRolesAssigned(u)
                        if cls and CLASS_INTERRUPTS[cls] and not (role == "HEALER" and cls ~= "SHAMAN") then
                            local kickInfo = CLASS_INTERRUPTS[cls]
                            partyAddonUsers[bestName] = {
                                class = cls,
                                spellID = kickInfo.id,
                                baseCd = kickInfo.cd,
                                cdEnd = now + kickInfo.cd,
                            }
                            if spyMode then
                                print("  Registered " .. bestName .. " (" .. cls .. ") CD=" .. kickInfo.cd)
                            end
                        end
                        break
                    end
                end
            end
        end
    elseif spyMode then
        print("  No matching party cast (best=" ..
        tostring(bestName) .. " delta=" .. string.format("%.3f", bestDelta) .. ")")
    end
end

-- Mob interrupt detection on ALL visible enemies (nameplates + target + focus)
local mobInterruptFrame = CreateFrame("Frame")
-- Always track target and focus
mobInterruptFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "target", "focus")
mobInterruptFrame:SetScript("OnEvent", function(self, event, unit)
    OnMobInterrupted(unit)
end)

-- Nameplate interrupt tracking: one frame per nameplate
local nameplateCastFrames = {}
local nameplateFrame = CreateFrame("Frame")
nameplateFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
nameplateFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
nameplateFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        if not nameplateCastFrames[unit] then
            nameplateCastFrames[unit] = CreateFrame("Frame")
        end
        local f = nameplateCastFrames[unit]
        f:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)
        f:SetScript("OnEvent", function(_, _, eUnit)
            OnMobInterrupted(eUnit)
        end)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if nameplateCastFrames[unit] then
            nameplateCastFrames[unit]:UnregisterAllEvents()
        end
    end
end)

-- Party event frames: OnValueChanged spell detection + time correlation
RegisterPartyWatchers = function()
    for i = 1, 4 do
        local unit = "party" .. i
        partyFrames[i]:UnregisterAllEvents()
        if UnitExists(unit) then
            partyFrames[i]:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", unit)
            partyFrames[i]:SetScript("OnEvent", function(self, event, eUnit, eCastGUID, eSpellID, eCastBarID)
                local cleanUnit = "party" .. i
                local cleanName = UnitName(cleanUnit)

                -- Store timestamp for correlation backup
                if cleanName then
                    recentPartyCasts[cleanName] = GetTime()
                end

                -- Try OnValueChanged laundering (StatusBar)
                -- MUST reset to 0 first so OnValueChanged always fires
                onValueChangedResult = nil
                launderBar:SetValue(0) -- reset
                pcall(launderBar.SetValue, launderBar, eSpellID)
                local barResult = onValueChangedResult

                -- Try OnValueChanged laundering (Slider)
                onSliderChangedResult = nil
                launderSlider:SetValue(0) -- reset
                pcall(launderSlider.SetValue, launderSlider, eSpellID)
                local sliderResult = onSliderChangedResult

                -- Try to use results as table keys
                local kickData = nil
                local cleanID = nil
                local method = nil

                -- Test barResult
                if barResult then
                    local ok, data = pcall(function() return ALL_INTERRUPTS[barResult] end)
                    if ok and data then
                        kickData = data
                        cleanID = barResult
                        method = "bar_cb"
                    end
                end

                -- Test sliderResult
                if not kickData and sliderResult then
                    local ok, data = pcall(function() return ALL_INTERRUPTS[sliderResult] end)
                    if ok and data then
                        kickData = data
                        cleanID = sliderResult
                        method = "slider_cb"
                    end
                end

                if spyMode then
                    print("|cFF00DDDD[SPY]|r SUCCEEDED " .. cleanUnit .. " (" .. tostring(cleanName) .. ")")
                    local barStr = "nil"
                    if barResult then
                        local ok, s = pcall(tostring, barResult)
                        barStr = ok and s or "tainted"
                    end
                    local sliderStr = "nil"
                    if sliderResult then
                        local ok, s = pcall(tostring, sliderResult)
                        sliderStr = ok and s or "tainted"
                    end
                    print("  bar_cb=" .. barStr .. " slider_cb=" .. sliderStr)

                    if kickData then
                        print("  |cFF00FF00>>> KICK: " .. kickData.name .. " via " .. method .. "|r")
                    else
                        -- Test if values are tainted (can't use as table key)
                        if barResult then
                            local ok = pcall(function() local _ = ALL_INTERRUPTS[barResult] end)
                            print("  bar key_test=" .. (ok and "CLEAN" or "TAINTED"))
                        end
                        if sliderResult then
                            local ok = pcall(function() local _ = ALL_INTERRUPTS[sliderResult] end)
                            print("  slider key_test=" .. (ok and "CLEAN" or "TAINTED"))
                        end
                    end
                end

                -- If we identified the kick spell, start CD
                if kickData and cleanName then
                    OnSpellCastSucceeded(cleanUnit, nil, cleanID, true, cleanName)
                end
            end)
        end
    end
    if spyMode then
        local reg = {}
        for i = 1, 4 do
            local u = "party" .. i
            if UnitExists(u) then table.insert(reg, u .. "=" .. (UnitName(u) or "?")) end
        end
        print("|cFF00DDDD[SPY]|r Watchers: " .. (#reg > 0 and table.concat(reg, ", ") or "none"))
    end

    -- Pet watchers (Warlock Felhunter Spell Lock, Hunter pet, etc.)
    for i = 1, 4 do
        local petUnit = "partypet" .. i
        local ownerUnit = "party" .. i
        partyPetFrames[i]:UnregisterAllEvents()
        if UnitExists(petUnit) then
            partyPetFrames[i]:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", petUnit)
            partyPetFrames[i]:SetScript("OnEvent", function(self, event, eUnit, eCastGUID, eSpellID, eCastBarID)
                local cleanOwner = "party" .. i
                local cleanName = UnitName(cleanOwner)

                -- Store timestamp for correlation
                if cleanName then
                    recentPartyCasts[cleanName] = GetTime()
                end

                -- Launder spellID
                onValueChangedResult = nil
                launderBar:SetValue(0)
                pcall(launderBar.SetValue, launderBar, eSpellID)
                local barResult = onValueChangedResult

                local kickData = nil
                local cleanID = nil

                if barResult then
                    local ok, data = pcall(function() return ALL_INTERRUPTS[barResult] end)
                    if ok and data then
                        kickData = data
                        cleanID = barResult
                    end
                end

                if spyMode then
                    local barStr = "nil"
                    if barResult then
                        local ok, s = pcall(tostring, barResult)
                        barStr = ok and s or "tainted"
                    end
                    print("|cFF00DDDD[SPY]|r PET SUCCEEDED partypet" ..
                    i .. " (owner=" .. tostring(cleanName) .. ") bar_cb=" .. barStr)
                    if kickData then
                        print("  |cFF00FF00>>> PET KICK: " .. kickData.name .. "|r")
                    end
                end

                if kickData and cleanName then
                    OnSpellCastSucceeded(cleanOwner, nil, cleanID, true, cleanName)
                end
            end)
        end
    end
end

ef:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        Initialize()
    elseif event == "CHAT_MSG_ADDON" or event == "CHAT_MSG_ADDON_LOGGED" then
        OnAddonMessage(arg1, arg2, arg3, arg4)
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        TryCacheCD()
        UpdateDisplay()
    elseif event == "SPELLS_CHANGED" then
        FindMyInterrupt()
        AnnounceJoin()
    elseif event == "PLAYER_REGEN_ENABLED" then
        TryCacheCD()
    elseif event == "INSPECT_READY" then
        if inspectBusy and inspectUnit then
            local ok, err = pcall(ScanInspectTalents, inspectUnit)
            if not ok and spyMode then
                print("|cFFFF0000[SPY]|r Inspect scan error: " .. tostring(err))
            end
            ClearInspectPlayer()
            inspectBusy = false
            inspectUnit = nil
            C_Timer.After(0.5, ProcessInspectQueue)
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        local changedUnit = arg1
        if changedUnit and changedUnit ~= "player" then
            local name = UnitName(changedUnit)
            if name then
                inspectedPlayers[name] = nil
                noInterruptPlayers[name] = nil
                -- Re-register with class default
                local _, cls = UnitClass(changedUnit)
                if cls and CLASS_INTERRUPTS[cls] then
                    local kickInfo = CLASS_INTERRUPTS[cls]
                    partyAddonUsers[name] = {
                        class = cls,
                        spellID = kickInfo.id,
                        baseCd = kickInfo.cd,
                        cdEnd = 0,
                        onKickReduction = nil,
                    }
                end
                if spyMode then
                    print("|cFF00DDDD[SPY]|r " .. name .. " changed spec → re-inspecting")
                end
                C_Timer.After(1, QueuePartyInspect)
            end
        end
    elseif event == "UNIT_PET" then
        local unit = arg1
        -- Own pet changed → re-detect our kicks (multiple retries as pet spellbook loads slowly)
        if unit == "player" then
            C_Timer.After(0.5, FindMyInterrupt)
            C_Timer.After(1.5, FindMyInterrupt)
            C_Timer.After(3.0, FindMyInterrupt)
            if spyMode then
                C_Timer.After(3.0, function()
                    print("|cFF00DDDD[SPY]|r Pet changed → primary kick: " .. tostring(mySpellID))
                end)
            end
        end
        -- Party pet changed → re-inspect and re-register watchers
        RegisterPartyWatchers()
        if unit and unit:find("^party") then
            local name = UnitName(unit)
            if name then
                inspectedPlayers[name] = nil
                C_Timer.After(1, QueuePartyInspect)
                if spyMode then
                    print("|cFF00DDDD[SPY]|r " .. name .. " pet changed → re-inspecting")
                end
            end
        end
    elseif event == "ROLE_CHANGED_INFORM" then
        -- Roles changed → remove healers without kick
        for i = 1, 4 do
            local u = "party" .. i
            if UnitExists(u) then
                local name = UnitName(u)
                local _, cls = UnitClass(u)
                local role = UnitGroupRolesAssigned(u)
                if name and role == "HEALER" and cls ~= "SHAMAN" and partyAddonUsers[name] then
                    partyAddonUsers[name] = nil
                    noInterruptPlayers[name] = true
                    if spyMode then
                        print("|cFF00DDDD[SPY]|r Role changed: " .. name .. " is HEALER (" .. cls .. ") → removed")
                    end
                end
            end
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        CleanPartyList()
        RegisterPartyWatchers()
        AutoRegisterPartyByClass()
        -- Queue inspect for new members (1s delay for units to be ready)
        C_Timer.After(1, QueuePartyInspect)
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_ChatInfo.RegisterAddonMessagePrefix(MSG_PREFIX)
        CheckZoneVisibility()
        RegisterPartyWatchers()
        AutoRegisterPartyByClass()
        C_Timer.After(1, AutoRegisterPartyByClass)
        C_Timer.After(2, QueuePartyInspect) -- inspect any not-yet-inspected members
        C_Timer.After(3, function()
            FindMyInterrupt()
            AnnounceJoin()
            AutoRegisterPartyByClass()
        end)
    end
end)
