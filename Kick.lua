local addonName, addonTable = ...
local Kick = {}
addonTable.Kick = Kick

-- == INTERRUPT SPELL DATABASE ==

local INTERRUPT_SPELLS = {
    -- Death Knight
    [47528] = { name = "Mind Freeze", cd = 15, class = "DEATHKNIGHT" },

    -- Demon Hunter
    [183752] = { name = "Disrupt", cd = 15, class = "DEMONHUNTER" },

    -- Druid
    [106839] = { name = "Skull Bash", cd = 15, class = "DRUID" },
    [78675] = { name = "Solar Beam", cd = 60, class = "DRUID" }, -- Balance

    -- Evoker
    [351338] = { name = "Quell", cd = 40, class = "EVOKER" },

    -- Hunter
    [147362] = { name = "Counter Shot", cd = 24, class = "HUNTER" },
    [187650] = { name = "Freezing Trap", cd = 30, class = "HUNTER" }, -- CC but used as interrupt

    -- Mage
    [2139] = { name = "Counterspell", cd = 24, class = "MAGE" },

    -- Monk
    [116705] = { name = "Spear Hand Strike", cd = 15, class = "MONK" },

    -- Paladin
    [96231] = { name = "Rebuke", cd = 15, class = "PALADIN" },

    -- Priest
    [15487] = { name = "Silence", cd = 45, class = "PRIEST" }, -- Shadow

    -- Rogue
    [1766] = { name = "Kick", cd = 15, class = "ROGUE" },

    -- Shaman
    [57994] = { name = "Wind Shear", cd = 12, class = "SHAMAN" },

    -- Warlock
    [19647] = { name = "Spell Lock", cd = 24, class = "WARLOCK" },  -- Felhunter
    [89766] = { name = "Axe Toss", cd = 30, class = "WARLOCK" },    -- Felguard
    [132409] = { name = "Spell Lock", cd = 24, class = "WARLOCK" }, -- Command Demon version

    -- Warrior
    [6552] = { name = "Pummel", cd = 15, class = "WARRIOR" },
}

-- Reverse lookup: class -> list of interrupt spells
local CLASS_INTERRUPTS = {}
for spellID, data in pairs(INTERRUPT_SPELLS) do
    local class = data.class
    CLASS_INTERRUPTS[class] = CLASS_INTERRUPTS[class] or {}
    table.insert(CLASS_INTERRUPTS[class], spellID)
end

-- == PARTY TRACKER STATE ==

local partyFrames = {}        -- GUID -> frame
local interruptCooldowns = {} -- GUID -> { spellID, endTime }
local ADDON_PREFIX = "LunaKick"

-- == UTILITY FUNCTIONS ==

local function GetPlayerKickSpell()
    local _, class = UnitClass("player")
    if CLASS_INTERRUPTS[class] then
        for _, spellID in ipairs(CLASS_INTERRUPTS[class]) do
            if IsPlayerSpell(spellID) then
                return spellID
            end
        end
        -- Return first one as default if none are learned
        return CLASS_INTERRUPTS[class][1]
    end
    return nil
end

local function GetUnitKickSpell(unit)
    local _, class = UnitClass(unit)
    if CLASS_INTERRUPTS[class] then
        -- For party members, we can't check IsPlayerSpell, so return first interrupt
        return CLASS_INTERRUPTS[class][1]
    end
    return nil
end

-- == ADDON COMMUNICATION ==

local function SendKickMessage(spellID)
    if not UIThingsDB.kick.enabled then return end

    local message = string.format("%d:%d", spellID, GetTime())
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, message, "PARTY")
end

local function OnAddonMessage(prefix, message, channel, sender)
    if not UIThingsDB.kick.enabled then return end
    if prefix ~= ADDON_PREFIX then return end

    -- Parse message: "spellID:timestamp"
    local spellID, timestamp = message:match("(%d+):([%d%.]+)")
    spellID = tonumber(spellID)
    timestamp = tonumber(timestamp)

    if not spellID or not INTERRUPT_SPELLS[spellID] then return end

    -- Find the sender's GUID
    local senderGUID = nil
    if UnitName("player") == sender then
        senderGUID = UnitGUID("player")
    else
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) and UnitName(unit) == sender then
                senderGUID = UnitGUID(unit)
                break
            end
        end
    end

    if not senderGUID then return end

    -- Store cooldown info
    local cooldown = INTERRUPT_SPELLS[spellID].cd
    interruptCooldowns[senderGUID] = {
        spellID = spellID,
        endTime = GetTime() + cooldown
    }

    -- Update the frame
    Kick.UpdatePartyFrame(senderGUID)
end

-- == PARTY FRAMES ==

local partyContainer = nil

local function CreatePartyContainer()
    if partyContainer then return partyContainer end

    partyContainer = CreateFrame("Frame", "LunaKickTracker", UIParent, "BackdropTemplate")
    partyContainer:SetSize(200, 300)

    -- Apply saved position or default to center
    if UIThingsDB.kick.pos then
        partyContainer:SetPoint(
            UIThingsDB.kick.pos.point or "CENTER",
            UIParent,
            UIThingsDB.kick.pos.relPoint or "CENTER",
            UIThingsDB.kick.pos.x or 0,
            UIThingsDB.kick.pos.y or 0
        )
    else
        partyContainer:SetPoint("CENTER", 0, 0)
    end

    partyContainer:SetFrameStrata("MEDIUM")
    partyContainer:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 2,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    partyContainer:SetBackdropColor(0, 0, 0, 0.8)
    partyContainer:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Title
    partyContainer.title = partyContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    partyContainer.title:SetPoint("TOP", 0, -10)
    partyContainer.title:SetText("Interrupt Tracker")

    -- Make draggable when unlocked
    partyContainer:SetMovable(true)
    partyContainer:EnableMouse(false)
    partyContainer:RegisterForDrag("LeftButton")
    partyContainer:SetScript("OnDragStart", function(self)
        if not UIThingsDB.kick.locked then
            self:StartMoving()
        end
    end)
    partyContainer:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        UIThingsDB.kick.pos = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    partyContainer:Hide()
    return partyContainer
end

local function CreatePartyFrame(guid, unit)
    local container = CreatePartyContainer()

    local frame = CreateFrame("Frame", nil, container, "BackdropTemplate")
    frame:SetSize(180, 40)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    -- Player name
    frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.name:SetPoint("TOPLEFT", 45, -5)
    frame.name:SetText(UnitName(unit) or "Unknown")

    -- Interrupt icon
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(32, 32)
    frame.icon:SetPoint("LEFT", 5, 0)

    local spellID = GetUnitKickSpell(unit)
    if spellID then
        local spellTexture = C_Spell.GetSpellTexture(spellID)
        frame.icon:SetTexture(spellTexture)
    end

    -- Cooldown bar
    frame.bar = CreateFrame("StatusBar", nil, frame)
    frame.bar:SetSize(120, 16)
    frame.bar:SetPoint("BOTTOMRIGHT", -5, 5)
    frame.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    frame.bar:SetStatusBarColor(0.2, 0.8, 0.2, 1)
    frame.bar:SetMinMaxValues(0, 1)
    frame.bar:SetValue(1)

    -- Bar background
    frame.bar.bg = frame.bar:CreateTexture(nil, "BACKGROUND")
    frame.bar.bg:SetAllPoints()
    frame.bar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    frame.bar.bg:SetVertexColor(0.2, 0.2, 0.2, 0.5)

    -- Cooldown text
    frame.cdText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.cdText:SetPoint("CENTER", frame.bar, "CENTER", 0, 0)
    frame.cdText:SetText("Ready")

    frame.guid = guid
    frame.unit = unit

    partyFrames[guid] = frame
    Kick.UpdatePartyLayout()

    return frame
end

function Kick.UpdatePartyFrame(guid)
    local frame = partyFrames[guid]
    if not frame then return end

    local cdInfo = interruptCooldowns[guid]

    if cdInfo then
        local remaining = cdInfo.endTime - GetTime()
        if remaining > 0 then
            local spellData = INTERRUPT_SPELLS[cdInfo.spellID]
            local totalCD = spellData.cd
            local progress = remaining / totalCD

            frame.bar:SetValue(1 - progress)
            frame.cdText:SetText(string.format("%.1f", remaining))

            -- Desaturate icon
            frame.icon:SetDesaturated(true)
        else
            -- Cooldown finished
            frame.bar:SetValue(1)
            frame.cdText:SetText("Ready")
            frame.icon:SetDesaturated(false)
            interruptCooldowns[guid] = nil
        end
    else
        -- No cooldown active
        frame.bar:SetValue(1)
        frame.cdText:SetText("Ready")
        frame.icon:SetDesaturated(false)
    end
end

function Kick.UpdatePartyLayout()
    local container = CreatePartyContainer()

    local yOffset = -40
    local index = 0

    -- Always show player first
    local playerGUID = UnitGUID("player")
    if partyFrames[playerGUID] then
        partyFrames[playerGUID]:SetPoint("TOP", container, "TOP", 0, yOffset)
        partyFrames[playerGUID]:Show()
        index = index + 1
        yOffset = yOffset - 45
    end

    -- Then party members
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
            local guid = UnitGUID(unit)
            if guid and partyFrames[guid] then
                partyFrames[guid]:SetPoint("TOP", container, "TOP", 0, yOffset)
                partyFrames[guid]:Show()
                index = index + 1
                yOffset = yOffset - 45
            end
        end
    end

    -- Resize container based on number of frames
    local height = 40 + (index * 45)
    container:SetHeight(height)

    if index > 0 and UIThingsDB.kick.enabled then
        container:Show()
    else
        container:Hide()
    end
end

-- == UPDATE LOOP ==

local updateFrame = CreateFrame("Frame")
local elapsed = 0

local function OnUpdateHandler(self, delta)
    elapsed = elapsed + delta
    if elapsed >= 0.1 then
        elapsed = 0
        for guid, _ in pairs(partyFrames) do
            Kick.UpdatePartyFrame(guid)
        end
    end
end

local function StartUpdateLoop()
    elapsed = 0
    updateFrame:SetScript("OnUpdate", OnUpdateHandler)
end

local function StopUpdateLoop()
    updateFrame:SetScript("OnUpdate", nil)
end

function Kick.RebuildPartyFrames()
    -- Clear existing frames
    for guid, frame in pairs(partyFrames) do
        frame:Hide()
        frame:SetParent(nil)
    end
    wipe(partyFrames)
    wipe(interruptCooldowns)

    if not UIThingsDB.kick.enabled then
        StopUpdateLoop()
        if partyContainer then
            partyContainer:Hide()
        end
        return
    end

    -- Create frame for player
    local playerGUID = UnitGUID("player")
    if playerGUID then
        CreatePartyFrame(playerGUID, "player")
    end

    -- Create frames for party members
    if IsInGroup() then
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                local guid = UnitGUID(unit)
                if guid then
                    CreatePartyFrame(guid, unit)
                end
            end
        end
    end

    Kick.UpdatePartyLayout()

    -- Only run the update loop when there are frames to update
    if next(partyFrames) then
        StartUpdateLoop()
    else
        StopUpdateLoop()
    end
end

function Kick.UpdateSettings()
    if partyContainer then
        partyContainer:EnableMouse(not UIThingsDB.kick.locked)

        -- Apply saved position
        if UIThingsDB.kick.pos then
            partyContainer:ClearAllPoints()
            partyContainer:SetPoint(
                UIThingsDB.kick.pos.point or "CENTER",
                UIParent,
                UIThingsDB.kick.pos.relPoint or "CENTER",
                UIThingsDB.kick.pos.x or 0,
                UIThingsDB.kick.pos.y or 0
            )
        end
    end

    Kick.RebuildPartyFrames()
end

-- == EVENT HANDLING ==

local function OnEvent(self, event, ...)
    if not UIThingsDB.kick then return end

    if event == "PLAYER_ENTERING_WORLD" then
        if UIThingsDB.kick.enabled then
            Kick.RebuildPartyFrames()
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if UIThingsDB.kick.enabled then
            Kick.RebuildPartyFrames()
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if not UIThingsDB.kick.enabled then return end

        local unit, _, spellID = ...
        if issecretvalue(spellID) then return end
        -- Check if it's an interrupt spell
        if INTERRUPT_SPELLS[spellID] then
            -- Check if it's the player
            if unit == "player" then
                local guid = UnitGUID("player")
                local cooldown = INTERRUPT_SPELLS[spellID].cd

                interruptCooldowns[guid] = {
                    spellID = spellID,
                    endTime = GetTime() + cooldown
                }

                Kick.UpdatePartyFrame(guid)
                SendKickMessage(spellID)
            end
        end
    elseif event == "CHAT_MSG_ADDON" then
        OnAddonMessage(...)
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", OnEvent)

-- Register addon message prefix on load
C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
