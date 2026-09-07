local addonName, addonTable = ...

addonTable.BuffAlerts = addonTable.BuffAlerts or {}
local BuffAlerts = addonTable.BuffAlerts
local EventBus = addonTable.EventBus

local registrations = {}
local pendingRefresh = false
local auraScanPending = false
local journalIndexed = false
local journalSearchQuery
local journalSearchComplete
local searchUpdateCallback
local lastError

BuffAlerts.SOUND_PRESETS = {
    { value = "none",       label = "None" },
    { value = "raid",       label = "Raid Warning",       fileID = 567397 },
    { value = "low",        label = "Encounter Warning: Low",    fileID = 7670699 },
    { value = "medium",     label = "Encounter Warning: Medium", fileID = 7670701 },
    { value = "high",       label = "Encounter Warning: High",   fileID = 7670697 },
    { value = "flag",       label = "Flag Taken",          fileID = 569200 },
    { value = "beware",     label = "Beware",              fileID = 543587 },
    { value = "runaway",    label = "Run Away",            fileID = 552035 },
}

local presetByValue = {}
for _, preset in ipairs(BuffAlerts.SOUND_PRESETS) do
    presetByValue[preset.value] = preset
end

local function GetRestrictionType()
    -- Never rebuild registrations during combat. Existing registrations remain
    -- active and continue to play through Blizzard's engine.
    if InCombatLockdown and InCombatLockdown() then return -1 end

    local restricted = C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive
    if not restricted then return nil end

    -- Numeric fallbacks match Enum.AddOnRestrictionType on 12.1.
    if restricted(1) then -- Encounter
        return 1
    end
    if restricted(2) and restricted(0) then -- ChallengeMode + Combat
        return 0
    end
    return nil
end

local function CanScanPlayerAuras()
    -- Aura enumeration is used only to improve the config search catalogue.
    -- In 12.1 the player aura slots may remain secret after combat has ended
    -- (notably for the rest of an encounter or challenge-mode instance). Do
    -- not probe the slots unless we are unambiguously in unrestricted world
    -- content; the registered aura sounds do not depend on this scan.
    if InCombatLockdown and InCombatLockdown() then return false end

    local encounterActive = C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress
        or IsEncounterInProgress
    if encounterActive and encounterActive() then return false end

    local restricted = C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive
    if restricted then
        for restrictionType = 0, 2 do
            local ok, active = pcall(restricted, restrictionType)
            if not ok or active then return false end
        end
    end

    -- Aura data in instanced content can be protected even in the short gap
    -- between combat lockdown and restriction-state updates.
    local inInstance = IsInInstance and IsInInstance()
    return not inInstance
end

local function NormalizeCustomSound(value)
    if type(value) == "number" and value > 0 then
        return value
    end
    if type(value) ~= "string" then return nil end

    value = value:match("^%s*(.-)%s*$")
    if value == "" then return nil end

    local fileID = tonumber(value)
    if fileID and fileID > 0 and fileID % 1 == 0 then
        return fileID
    end

    value = value:gsub("/", "\\")
    if not value:lower():match("%.ogg$") and not value:lower():match("%.mp3$") then
        return nil
    end
    if value:lower():match("^interface\\") then
        return value
    end
    value = value:gsub("^\\+", "")
    return "Interface\\AddOns\\" .. addonName .. "\\" .. value
end

local function GetDB()
    local db = UIThingsDB and UIThingsDB.buffAlerts
    if not db then return nil end
    db.customSounds = db.customSounds or {}
    db.nextSoundID = db.nextSoundID or 1
    db.knownAuras = db.knownAuras or {}
    db.categories = db.categories or {}
    db.nextCategoryID = db.nextCategoryID or 1
    return db
end

local function RememberAura(spellID)
    if type(spellID) ~= "number" or (issecretvalue and issecretvalue(spellID)) or spellID <= 0 then return end
    local db = GetDB()
    if db then db.knownAuras[tostring(spellID)] = true end
end

function BuffAlerts.ScanPlayerAuras()
    if not CanScanPlayerAuras() then return end
    if not AuraUtil or not AuraUtil.ForEachAura then return end
    local function Store(auraData)
        if auraData then RememberAura(auraData.spellId) end
    end
    AuraUtil.ForEachAura("player", "HELPFUL", nil, Store, true)
    AuraUtil.ForEachAura("player", "HARMFUL", nil, Store, true)
end

local function IndexJournalEncounter(rootSectionID)
    local stack, seen = { rootSectionID }, {}
    while #stack > 0 do
        local sectionID = table.remove(stack)
        if sectionID and not seen[sectionID] then
            seen[sectionID] = true
            local info = C_EncounterJournal.GetSectionInfo(sectionID)
            if info then
                RememberAura(info.spellID)
                if info.siblingSectionID then stack[#stack + 1] = info.siblingSectionID end
                if info.firstChildSectionID then stack[#stack + 1] = info.firstChildSectionID end
            end
        end
    end
end

local function IndexJournalTier(tier)
    EJ_SelectTier(tier)
    for _, isRaid in ipairs({ true, false }) do
        local instanceIndex = 1
        while true do
            local instanceID = EJ_GetInstanceByIndex(instanceIndex, isRaid)
            if not instanceID then break end
            local encounterIndex = 1
            while true do
                local _, _, encounterID, rootSectionID = EJ_GetEncounterInfoByIndex(encounterIndex, instanceID)
                if not encounterID then break end
                if rootSectionID then IndexJournalEncounter(rootSectionID) end
                encounterIndex = encounterIndex + 1
            end
            instanceIndex = instanceIndex + 1
        end
    end
end

function BuffAlerts.IndexEncounterJournal()
    if journalIndexed or GetRestrictionType() ~= nil then return end
    if not EJ_GetNumTiers or not EJ_GetCurrentTier or not EJ_SelectTier
        or not EJ_GetInstanceByIndex or not EJ_GetEncounterInfoByIndex
        or not C_EncounterJournal or not C_EncounterJournal.GetSectionInfo then
        return
    end

    local tierCount = EJ_GetNumTiers()
    if not tierCount or tierCount < 1 then return end
    local savedTier = EJ_GetCurrentTier()
    local ok = pcall(function()
        -- The latest tier contains current raid and dungeon mechanics. Also
        -- index the selected tier when different for older content searches.
        IndexJournalTier(tierCount)
        if savedTier and savedTier ~= tierCount then IndexJournalTier(savedTier) end
    end)
    if savedTier then EJ_SelectTier(savedTier) end
    journalIndexed = ok
end

local function CollectJournalSearchResults()
    if not journalSearchQuery or not EJ_GetNumSearchResults or not EJ_GetSearchResult then return end
    local count = EJ_GetNumSearchResults() or 0
    for index = 1, count do
        local resultID, resultType = EJ_GetSearchResult(index)
        -- Result type 3 is an Encounter Journal ability/section.
        if resultType == 3 and resultID then
            local info = C_EncounterJournal.GetSectionInfo(resultID)
            if info then RememberAura(info.spellID) end
        end
    end
    journalSearchComplete = journalSearchQuery
    if EJ_EndSearch then pcall(EJ_EndSearch) end
    if searchUpdateCallback then searchUpdateCallback(journalSearchComplete) end
end

local function PollJournalSearch(query, attempt)
    if journalSearchQuery ~= query then return end
    if not EJ_IsSearchFinished or EJ_IsSearchFinished() then
        CollectJournalSearchResults()
    elseif attempt < 50 then
        C_Timer.After(0.1, function() PollJournalSearch(query, attempt + 1) end)
    else
        if EJ_EndSearch then pcall(EJ_EndSearch) end
        journalSearchQuery = nil
    end
end

function BuffAlerts.SearchEncounterJournal(query)
    query = type(query) == "string" and query:match("^%s*(.-)%s*$") or ""
    if #query < 3 or query == journalSearchQuery or query == journalSearchComplete then return end
    if GetRestrictionType() ~= nil or not EJ_SetSearch or not EJ_GetNumSearchResults
        or not EJ_GetSearchResult or not C_EncounterJournal or not C_EncounterJournal.GetSectionInfo then
        return
    end
    journalSearchQuery = query
    journalSearchComplete = nil
    local ok = pcall(EJ_SetSearch, query)
    if not ok then journalSearchQuery = nil return end
    PollJournalSearch(query, 1)
end

function BuffAlerts.SetSearchUpdateCallback(callback)
    searchUpdateCallback = callback
end

function BuffAlerts.FindSpellMatches(query, limit)
    query = type(query) == "string" and query:match("^%s*(.-)%s*$") or ""
    if query == "" then return {} end
    limit = limit or 8

    local matches, seen = {}, {}
    local function Add(spellID, exact)
        spellID = tonumber(spellID)
        if not spellID or spellID <= 0 or seen[spellID] then return end
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
        if not info or not info.name or (issecretvalue and issecretvalue(info.name)) then return end
        seen[spellID] = true
        matches[#matches + 1] = {
            spellID = spellID,
            name = info.name,
            iconID = info.iconID,
            exact = exact,
        }
    end

    local numericID = tonumber(query)
    if numericID and numericID % 1 == 0 then Add(numericID, true) end

    if C_Spell and C_Spell.GetSpellIDForSpellIdentifier then
        local ok, exactID = pcall(C_Spell.GetSpellIDForSpellIdentifier, query)
        if ok then Add(exactID, true) end
    end

    local db = GetDB()
    local candidates = {}
    local function AddCandidate(spellID)
        spellID = tonumber(spellID)
        if spellID then candidates[spellID] = true end
    end
    for spellID in pairs(db and db.knownAuras or {}) do AddCandidate(spellID) end
    for _, rule in ipairs(db and db.rules or {}) do AddCandidate(rule.spellID) end
    local needle = query:lower()
    for spellID in pairs(candidates) do
        if spellID and not seen[spellID] then
            local info = C_Spell.GetSpellInfo(spellID)
            if info and info.name and not (issecretvalue and issecretvalue(info.name))
                and info.name:lower():find(needle, 1, true) then
                Add(spellID, false)
            end
        end
    end

    table.sort(matches, function(a, b)
        if a.exact ~= b.exact then return a.exact end
        local aName, bName = a.name:lower(), b.name:lower()
        if aName ~= bName then return aName < bName end
        return a.spellID < b.spellID
    end)
    while #matches > limit do table.remove(matches) end
    return matches
end

local function FindCustomSound(value)
    local id = type(value) == "string" and value:match("^custom:(.+)$")
    if not id then return nil end
    local db = GetDB()
    for _, entry in ipairs(db and db.customSounds or {}) do
        if tostring(entry.id) == id then return entry end
    end
end

function BuffAlerts.GetSoundOptions()
    local options = {}
    for _, preset in ipairs(BuffAlerts.SOUND_PRESETS) do options[#options + 1] = preset end
    local db = GetDB()
    for _, entry in ipairs(db and db.customSounds or {}) do
        options[#options + 1] = { value = "custom:" .. tostring(entry.id), label = entry.name }
    end
    return options
end

function BuffAlerts.AddCustomSound(name, file)
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    file = type(file) == "string" and file:match("^%s*(.-)%s*$") or file
    if name == "" then return false, "Enter a name for the sound." end
    if not NormalizeCustomSound(file) then return false, "Enter a valid file-data ID, .ogg file, or .mp3 file." end
    local db = GetDB()
    for _, entry in ipairs(db.customSounds) do
        if entry.name:lower() == name:lower() then return false, "A registered sound already uses that name." end
    end
    local id = db.nextSoundID
    db.nextSoundID = id + 1
    db.customSounds[#db.customSounds + 1] = { id = id, name = name, file = file }
    return true
end

function BuffAlerts.RemoveCustomSound(id)
    local db = GetDB()
    local value = "custom:" .. tostring(id)
    for index, entry in ipairs(db.customSounds) do
        if tostring(entry.id) == tostring(id) then
            table.remove(db.customSounds, index)
            for _, rule in ipairs(db.rules or {}) do
                for _, key in ipairs({ "applied", "stacks", "removed" }) do
                    if type(rule[key]) == "table" and rule[key].preset == value then rule[key].preset = "none" end
                end
            end
            return true
        end
    end
    return false
end

function BuffAlerts.MigrateLegacySounds()
    local db = GetDB()
    if not db then return end
    for _, rule in ipairs(db.rules or {}) do
        for _, key in ipairs({ "applied", "stacks", "removed" }) do
            local setting = rule[key]
            if type(setting) == "table" and setting.preset == "custom" and NormalizeCustomSound(setting.custom) then
                local found
                for _, entry in ipairs(db.customSounds) do
                    if entry.file == setting.custom then found = entry break end
                end
                if not found then
                    local id = db.nextSoundID
                    db.nextSoundID = id + 1
                    found = { id = id, name = "Imported sound " .. id, file = setting.custom }
                    db.customSounds[#db.customSounds + 1] = found
                end
                setting.preset = "custom:" .. tostring(found.id)
                setting.custom = nil
            end
        end
    end
end

function BuffAlerts.ResolveSound(sound)
    if type(sound) ~= "table" then return nil end
    local preset = presetByValue[sound.preset or "none"]
    if preset and preset.fileID then
        return preset.fileID
    end
    local custom = FindCustomSound(sound.preset)
    if custom then return NormalizeCustomSound(custom.file) end
    return nil
end

function BuffAlerts.GetSoundLabel(sound)
    if type(sound) ~= "table" then return "None" end
    local preset = presetByValue[sound.preset or "none"]
    if preset then return preset.label end
    local custom = FindCustomSound(sound.preset)
    return custom and custom.name or "None"
end

local function RemoveRegistrations()
    if not C_UnitAuras or not C_UnitAuras.RemoveAuraSound then
        wipe(registrations)
        return
    end

    for i = #registrations, 1, -1 do
        local ok, err = pcall(C_UnitAuras.RemoveAuraSound, registrations[i])
        if not ok then lastError = tostring(err) end
        registrations[i] = nil
    end
end

local function RegisterSound(trigger, spellID, sound, outputChannel)
    local resolved = BuffAlerts.ResolveSound(sound)
    if not resolved then
        if type(sound) == "table" and sound.preset and sound.preset ~= "none" then
            lastError = string.format("Spell %d has an invalid custom sound.", spellID)
        end
        return
    end

    local info = {
        unitToken = "player",
        spellID = spellID,
        outputChannel = outputChannel,
    }
    if type(resolved) == "number" then
        info.soundFileID = resolved
    else
        info.soundFileName = resolved
    end

    local ok, registrationID = pcall(C_UnitAuras.AddAuraSound, trigger, info)
    if ok and registrationID then
        registrations[#registrations + 1] = registrationID
    elseif not ok then
        lastError = tostring(registrationID)
    else
        lastError = string.format("Blizzard rejected a sound registration for spell %d.", spellID)
    end
end

function BuffAlerts.Refresh()
    BuffAlerts.MigrateLegacySounds()
    if GetRestrictionType() ~= nil then
        pendingRefresh = true
        return false, "Changes queued until combat and encounter restrictions end."
    end

    pendingRefresh = false
    lastError = nil
    RemoveRegistrations()

    local db = UIThingsDB and UIThingsDB.buffAlerts
    if not db or not db.enabled then return true end
    if not C_UnitAuras or not C_UnitAuras.AddAuraSound then
        lastError = "C_UnitAuras.AddAuraSound is unavailable on this client."
        return false, lastError
    end

    local triggers = Enum and Enum.UnitAuraSoundTrigger
    local added = triggers and triggers.Added or 0
    local increased = triggers and triggers.ApplicationsIncreased or 1
    local removed = triggers and triggers.Removed or 2
    local outputChannel = db.outputChannel or "master"

    for _, rule in ipairs(db.rules or {}) do
        local spellID = tonumber(rule.spellID)
        if rule.enabled ~= false and spellID and spellID > 0 then
            RegisterSound(added, spellID, rule.applied, outputChannel)
            RegisterSound(increased, spellID, rule.stacks, outputChannel)
            RegisterSound(removed, spellID, rule.removed, outputChannel)
        end
    end

    return lastError == nil, lastError
end

function BuffAlerts.GetStatus()
    if pendingRefresh or GetRestrictionType() ~= nil then
        return "pending", "Saved; registrations will update when restrictions end."
    end
    if lastError then return "error", lastError end
    return "active", string.format("%d sound registration%s active.", #registrations, #registrations == 1 and "" or "s")
end

function BuffAlerts.TestSound(sound)
    local resolved = BuffAlerts.ResolveSound(sound)
    if not resolved then return false, "Choose a valid sound first." end
    local ok, played = pcall(PlaySoundFile, resolved, "Master")
    if not ok or not played then
        return false, "The sound could not be played. Custom files require a full client restart after being added."
    end
    return true
end

local function OnRestrictionChanged(_, _, state)
    if state == 0 and pendingRefresh and GetRestrictionType() == nil then
        BuffAlerts.Refresh()
    end
end

local function OnPlayerLogin()
    BuffAlerts.ScanPlayerAuras()
    BuffAlerts.Refresh()
end

local function OnPlayerRegenEnabled()
    BuffAlerts.ScanPlayerAuras()
    if pendingRefresh and GetRestrictionType() == nil then
        BuffAlerts.Refresh()
    end
end

local function OnUnitAura(_, unit)
    if unit ~= "player" or auraScanPending or (InCombatLockdown and InCombatLockdown()) then return end
    auraScanPending = true
    C_Timer.After(0.25, function()
        auraScanPending = false
        BuffAlerts.ScanPlayerAuras()
    end)
end

EventBus.Register("PLAYER_LOGIN", OnPlayerLogin, "BuffAlerts")
EventBus.Register("ADDON_RESTRICTION_STATE_CHANGED", OnRestrictionChanged, "BuffAlerts")
EventBus.Register("PLAYER_REGEN_ENABLED", OnPlayerRegenEnabled, "BuffAlerts")
EventBus.Register("UNIT_AURA", OnUnitAura, "BuffAlerts")
