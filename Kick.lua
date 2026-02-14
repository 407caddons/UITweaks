local addonName, addonTable = ...
local Kick = {}
addonTable.Kick = Kick

-- == INTERRUPT SPELL DATABASE ==

local INTERRUPT_SPELLS = {
    -- Death Knight
    [47528] = { name = "Mind Freeze", cd = 15, class = "DEATHKNIGHT" },

    -- Demon Hunter
    [183752] = { name = "Disrupt", cd = 15, class = "DEMONHUNTER" },
    [202137] = { name = "Sigil of Silence", cd = 90, class = "DEMONHUNTER", specID = 2 }, -- Vengeance

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

    -- Warlock (pet abilities — different pets per spec)
    [19647] = { name = "Spell Lock", cd = 24, class = "WARLOCK", specID = 1, isPet = true },  -- Affliction (Felhunter)
    [89766] = { name = "Axe Toss", cd = 30, class = "WARLOCK", specID = 2, isPet = true },    -- Demonology (Felguard)
    [132409] = { name = "Spell Lock", cd = 24, class = "WARLOCK", specID = 3, isPet = true }, -- Destruction (Command Demon)

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

-- Check if a spell is known by the player (or their pet for pet abilities)
local function IsInterruptKnown(spellID)
    local data = INTERRUPT_SPELLS[spellID]
    if not data then return false end
    if data.isPet then
        -- Pet spells: IsPlayerSpell doesn't work, check the pet spellbook
        if C_SpellBook and C_SpellBook.IsSpellKnown then
            return C_SpellBook.IsSpellKnown(spellID, Enum.SpellBookSpellBank.Pet)
        end
        -- Legacy fallback
        if IsSpellKnownOrOverridesKnown then
            return IsSpellKnownOrOverridesKnown(spellID, true)
        end
        return false
    end
    return IsPlayerSpell(spellID)
end

-- == PARTY TRACKER STATE ==

local partyFrames = {}        -- GUID -> frame
local interruptCooldowns = {} -- GUID -> { [spellID] = { spellID, endTime } }
local interruptCounts = {}    -- GUID -> { total = N }
local framePool = {}          -- Recycled party frames
-- Forward declarations
local StartUpdateLoop

-- Received spell lists from addon comms: GUID -> { spellID1, spellID2, ... }
local knownSpells = {}

-- == KICK COUNT HELPERS ==

local function IncrementTotal(guid)
    if not interruptCounts[guid] then
        interruptCounts[guid] = { total = 0 }
    end
    interruptCounts[guid].total = interruptCounts[guid].total + 1
    local frame = partyFrames[guid]
    if frame then
        local counts = interruptCounts[guid]
        -- Only show total kicks used (successful tracking removed due to API limitations)
        -- Check if this is a regular frame (has kickCount) or attached frame (has count)
        if frame.kickCount then
            frame.kickCount:SetText(string.format("(%d)", counts.total))
        elseif frame.count then
            frame.count:SetText(tostring(counts.total))
        end
    end
end

-- == UTILITY FUNCTIONS ==

local function GetPlayerKickSpell()
    local _, class = UnitClass("player")
    if CLASS_INTERRUPTS[class] then
        for _, spellID in ipairs(CLASS_INTERRUPTS[class]) do
            if IsInterruptKnown(spellID) then
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

-- Returns all interrupt spells applicable to a unit
local function GetUnitKickSpells(unit)
    local _, class = UnitClass(unit)
    if not CLASS_INTERRUPTS[class] then return {} end

    -- For the player, check which interrupt spells are actually known
    if UnitIsUnit(unit, "player") then
        local spells = {}
        for _, spellID in ipairs(CLASS_INTERRUPTS[class]) do
            if IsInterruptKnown(spellID) then
                table.insert(spells, spellID)
            end
        end
        return spells
    end

    -- For other players, check if we received their spell list via addon comms
    local guid = UnitGUID(unit)
    if guid and knownSpells[guid] ~= nil then
        -- We've received data from this player (even if empty = no interrupt spells)
        local spells = {}
        for _, spellID in ipairs(knownSpells[guid]) do
            if INTERRUPT_SPELLS[spellID] then
                table.insert(spells, spellID)
            end
        end
        return spells -- May be empty — means they have no interrupt spells
    end

    -- Fallback for players without the addon: guess from class/role
    local spells = {}
    local spec = nil

    local role = UnitGroupRolesAssigned(unit)
    if class == "DEMONHUNTER" then
        spec = (role == "TANK") and 2 or 1
    end

    local allSpecific = true
    for _, spellID in ipairs(CLASS_INTERRUPTS[class]) do
        if not INTERRUPT_SPELLS[spellID].specID then
            allSpecific = false
            break
        end
    end

    for _, spellID in ipairs(CLASS_INTERRUPTS[class]) do
        local data = INTERRUPT_SPELLS[spellID]
        if data.specID then
            if spec and data.specID == spec then
                table.insert(spells, spellID)
            elseif not spec and allSpecific then
                if #spells == 0 then
                    table.insert(spells, spellID)
                end
            end
        else
            table.insert(spells, spellID)
        end
    end

    return spells
end

local function GetUnitByGUID(guid)
    if UnitGUID("player") == guid then return "player" end
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) and UnitGUID(unit) == guid then
            return unit
        end
    end
    return nil
end

-- == ADDON COMMUNICATION ==

-- Helper to find a sender's GUID from their short name
local function FindSenderGUID(senderShort)
    -- Check party members
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) and UnitName(unit) == senderShort then
            return UnitGUID(unit)
        end
    end
    -- Check raid members
    if IsInRaid() then
        for i = 1, 40 do
            local unit = "raid" .. i
            if UnitExists(unit) and UnitName(unit) == senderShort then
                return UnitGUID(unit)
            end
        end
    end
    return nil
end

local function SendKickMessage(spellID, cooldown)
    if not UIThingsDB.kick.enabled then return end
    local payload = string.format("%d:%d:%.1f", spellID, GetTime(), cooldown)
    addonTable.Comm.Send("KICK", "CD", payload, "LunaKick", payload)
end

-- Broadcast the player's interrupt spells to the group
function Kick.BroadcastSpells()
    if not UIThingsDB.kick.enabled then
        addonTable.Core.Log("Kick", "BroadcastSpells: kick not enabled", 0)
        return
    end
    local _, class = UnitClass("player")
    if not CLASS_INTERRUPTS[class] then
        addonTable.Core.Log("Kick", "BroadcastSpells: no interrupts for class " .. (class or "?"), 0)
        return
    end

    local spells = {}
    for _, spellID in ipairs(CLASS_INTERRUPTS[class]) do
        local known = IsInterruptKnown(spellID)
        addonTable.Core.Log("Kick", string.format("BroadcastSpells: checking %d (%s) = %s",
            spellID, INTERRUPT_SPELLS[spellID].name, tostring(known)), 0)
        if known then
            table.insert(spells, tostring(spellID))
        end
    end

    local payload = table.concat(spells, ",")
    addonTable.Core.Log("Kick", "BroadcastSpells: sending " .. (payload ~= "" and payload or "NONE"), 0)
    -- Send even if empty — tells others to remove us from tracking
    addonTable.Comm.Send("KICK", "SPELLS", payload)
end

-- Register handler for interrupt cooldown messages
addonTable.Comm.Register("KICK", "CD", function(senderShort, payload, senderFull)
    if not UIThingsDB.kick.enabled then return end

    -- Skip self (already handled locally)
    if UnitName("player") == senderShort then return end

    -- Parse payload: "spellID:timestamp:cooldown" (cooldown is optional for backwards compat)
    local spellID, timestamp, msgCooldown = payload:match("(%d+):([%d%.]+):?([%d%.]*)")
    spellID = tonumber(spellID)
    timestamp = tonumber(timestamp)
    msgCooldown = tonumber(msgCooldown)

    if not spellID or not INTERRUPT_SPELLS[spellID] then return end

    local senderGUID = FindSenderGUID(senderShort)
    if not senderGUID then return end

    -- Update knownSpells: if they used this spell, they have it
    if not knownSpells[senderGUID] then
        knownSpells[senderGUID] = {}
    end
    local found = false
    for _, id in ipairs(knownSpells[senderGUID]) do
        if id == spellID then
            found = true; break
        end
    end
    if not found then
        table.insert(knownSpells[senderGUID], spellID)
        -- Rebuild frames to show the new spell row
        Kick.RebuildPartyFrames()
    end

    -- If we don't have a frame for this sender yet, rebuild
    if not partyFrames[senderGUID] then
        Kick.RebuildPartyFrames()
    end

    -- Store cooldown info
    local cooldown = msgCooldown or INTERRUPT_SPELLS[spellID].cd
    if not interruptCooldowns[senderGUID] then
        interruptCooldowns[senderGUID] = {}
    end
    interruptCooldowns[senderGUID][spellID] = {
        spellID = spellID,
        endTime = GetTime() + cooldown,
        totalCD = cooldown
    }

    IncrementTotal(senderGUID)
    Kick.UpdatePartyFrame(senderGUID)
    StartUpdateLoop()
end)

-- Register handler for spell list broadcasts
addonTable.Comm.Register("KICK", "SPELLS", function(senderShort, payload, senderFull)
    if not UIThingsDB.kick.enabled then return end

    -- Skip self
    if UnitName("player") == senderShort then return end

    local senderGUID = FindSenderGUID(senderShort)
    if not senderGUID then return end

    -- Parse comma-separated spell IDs
    local spells = {}
    for idStr in payload:gmatch("(%d+)") do
        local id = tonumber(idStr)
        if id and INTERRUPT_SPELLS[id] then
            table.insert(spells, id)
        end
    end

    -- Only rebuild if the spell list actually changed
    local existing = knownSpells[senderGUID]
    local changed = false
    if not existing or #existing ~= #spells then
        changed = true
    else
        for i, id in ipairs(spells) do
            if existing[i] ~= id then
                changed = true
                break
            end
        end
    end

    knownSpells[senderGUID] = spells

    if changed then
        Kick.RebuildPartyFrames()
    end
end)

-- Register handler for spell list requests (e.g. after someone reloads)
addonTable.Comm.Register("KICK", "REQ", function(senderShort, payload, senderFull)
    if not UIThingsDB.kick.enabled then return end
    if UnitName("player") == senderShort then return end

    -- Respond with our spells after a short throttled delay
    addonTable.Comm.ScheduleThrottled("KICK_SPELLS", 2, function()
        Kick.BroadcastSpells()
    end)
end)

-- == PARTY FRAMES ==

local partyContainer = nil
local attachedFrames = {} -- Stores attached icon frames by unit token (party1, party2, etc.)

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
    local bg = UIThingsDB.kick.bgColor
    local border = UIThingsDB.kick.borderColor
    partyContainer:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
    partyContainer:SetBackdropBorderColor(border.r, border.g, border.b, border.a)

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

-- Helper to find the actual unit frame for a unit token
local function FindUnitFrame(unit)
    -- Method 1: Grid2 support
    if Grid2 then
        -- Try Grid2Frame.registeredFrames (most direct method)
        local Grid2Frame = Grid2:GetModule("Grid2Frame", true)
        if Grid2Frame and Grid2Frame.registeredFrames then
            for name, frame in pairs(Grid2Frame.registeredFrames) do
                if frame and frame.unit == unit then
                    return frame
                end
            end
        end

        -- Try Grid2Layout headers
        local Grid2Layout = Grid2:GetModule("Grid2Layout", true)
        if Grid2Layout and Grid2Layout.headers then
            for _, header in pairs(Grid2Layout.headers) do
                if header and header.GetNumChildren then
                    for i = 1, header:GetNumChildren() do
                        local child = select(i, header:GetChildren())
                        if child and child.unit == unit then
                            return child
                        end
                    end
                end
            end
        end
    end

    -- Method 2: Check EditMode party frames
    if PartyFrame then
        local frames = {
            PartyFrame.MemberFrame1,
            PartyFrame.MemberFrame2,
            PartyFrame.MemberFrame3,
            PartyFrame.MemberFrame4,
        }
        for i, frame in ipairs(frames) do
            if frame and frame.unit == unit then
                return frame
            end
        end
    end

    -- Method 3: Iterate CompactPartyFrame children
    if CompactPartyFrame then
        for i = 1, CompactPartyFrame:GetNumChildren() do
            local child = select(i, CompactPartyFrame:GetChildren())
            if child and child.unit == unit then
                return child
            end
        end
    end

    -- Method 4: Check CompactRaidFrame container
    if CompactRaidFrameContainer then
        for i = 1, CompactRaidFrameContainer:GetNumChildren() do
            local child = select(i, CompactRaidFrameContainer:GetChildren())
            if child and child.unit == unit then
                return child
            end
        end
    end

    return nil
end

-- Create a simple attached frame that shows on party/raid frames
local ICON_SIZE = 28
local ICON_SPACING = 2

local function CreateAttachedIcon(parent, index)
    local icon = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    icon:SetSize(ICON_SIZE, ICON_SIZE)

    icon:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    icon:SetBackdropBorderColor(0, 0, 0, 0.8)

    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()

    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints()
    icon.cooldown:SetDrawEdge(true)
    icon.cooldown:SetHideCountdownNumbers(false)

    return icon
end

local function CreateAttachedFrame(guid, unit)
    -- Find the actual Blizzard unit frame
    local blizzFrame = FindUnitFrame(unit)

    if not blizzFrame then
        return nil
    end

    -- Create or reuse container frame
    local frame = attachedFrames[unit]

    if not frame then
        frame = CreateFrame("Frame", "LunaKickAttached_" .. unit, UIParent)
        frame:SetFrameStrata("MEDIUM")
        frame.icons = {}

        -- Set up OnUpdate to dynamically position based on the blizz frame
        frame:SetScript("OnUpdate", function(self, elapsed)
            if self.blizzFrame and self.blizzFrame:IsShown() then
                local anchorPoint = UIThingsDB.kick.attachAnchorPoint or "BOTTOM"
                self:ClearAllPoints()

                if anchorPoint == "BOTTOM" then
                    self:SetPoint("TOP", self.blizzFrame, "BOTTOM", 0, -2)
                elseif anchorPoint == "TOP" then
                    self:SetPoint("BOTTOM", self.blizzFrame, "TOP", 0, 2)
                elseif anchorPoint == "LEFT" then
                    self:SetPoint("RIGHT", self.blizzFrame, "LEFT", -2, 0)
                elseif anchorPoint == "RIGHT" then
                    self:SetPoint("LEFT", self.blizzFrame, "RIGHT", 2, 0)
                end

                self:Show()
            else
                self:Hide()
            end
        end)

        -- Count text (total kick count)
        frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.count:SetTextColor(1, 1, 1)

        attachedFrames[unit] = frame
    end

    -- Get all spells for this unit
    local unitSpells = GetUnitKickSpells(unit)
    if #unitSpells == 0 and not UnitIsUnit(unit, "player") and not (guid and knownSpells[guid] ~= nil) then
        local fallback = GetUnitKickSpell(unit)
        if fallback then unitSpells = { fallback } end
    end

    local numSpells = math.max(#unitSpells, 1)

    -- Determine layout direction based on anchor point
    local anchorPoint = UIThingsDB.kick.attachAnchorPoint or "BOTTOM"
    local horizontal = (anchorPoint == "BOTTOM" or anchorPoint == "TOP")

    -- Size the container to fit all icons
    if horizontal then
        frame:SetSize(numSpells * ICON_SIZE + (numSpells - 1) * ICON_SPACING, ICON_SIZE)
    else
        frame:SetSize(ICON_SIZE, numSpells * ICON_SIZE + (numSpells - 1) * ICON_SPACING)
    end

    -- Create/reuse icon sub-frames and position them
    for i, spellID in ipairs(unitSpells) do
        if not frame.icons[i] then
            frame.icons[i] = CreateAttachedIcon(frame, i)
        end
        local iconFrame = frame.icons[i]
        iconFrame:ClearAllPoints()

        if horizontal then
            iconFrame:SetPoint("LEFT", (i - 1) * (ICON_SIZE + ICON_SPACING), 0)
        else
            iconFrame:SetPoint("TOP", 0, -((i - 1) * (ICON_SIZE + ICON_SPACING)))
        end

        local spellTexture = C_Spell.GetSpellTexture(spellID)
        iconFrame.texture:SetTexture(spellTexture)
        iconFrame.cooldown:Clear()
        iconFrame.spellID = spellID
        iconFrame:Show()
    end

    -- Hide unused icons
    for i = #unitSpells + 1, #frame.icons do
        frame.icons[i]:Hide()
        frame.icons[i].spellID = nil
    end

    -- Store spell order for UpdatePartyFrame
    frame.spellOrder = unitSpells

    -- Position count text
    frame.count:ClearAllPoints()
    frame.count:SetPoint("BOTTOMRIGHT", frame.icons[1] or frame, "BOTTOMRIGHT", 2, 2)

    -- Update count
    local counts = interruptCounts[guid]
    if counts and counts.total > 0 then
        frame.count:SetText(counts.total)
    else
        frame.count:SetText("")
    end

    frame.guid = guid
    frame.unit = unit
    frame.blizzFrame = blizzFrame
    -- Keep .cooldown as nil so UpdatePartyFrame uses the multi-icon path
    frame.cooldown = nil

    frame:Show()

    partyFrames[guid] = frame
    return frame
end

local ROW_HEIGHT = 22
local ROW_ICON_SIZE = 20
local ROW_BAR_HEIGHT = 16
local NAME_HEIGHT = 20

local function CreateSpellRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(170, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 5, -(NAME_HEIGHT + (index - 1) * ROW_HEIGHT))

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_ICON_SIZE, ROW_ICON_SIZE)
    row.icon:SetPoint("LEFT", 0, 0)

    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetSize(120, ROW_BAR_HEIGHT)
    row.bar:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    row.bar:SetStatusBarColor(0.2, 0.8, 0.2, 1)
    row.bar:SetMinMaxValues(0, 1)
    row.bar:SetValue(1)

    row.bar.bg = row.bar:CreateTexture(nil, "BACKGROUND")
    row.bar.bg:SetAllPoints()
    row.bar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    row.bar.bg:SetVertexColor(0.2, 0.2, 0.2, 0.5)

    row.cdText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.cdText:SetPoint("RIGHT", row.bar, "RIGHT", -4, 0)
    row.cdText:SetText("")

    return row
end

local function CreatePartyFrame(guid, unit)
    local container = CreatePartyContainer()

    -- Reuse a pooled frame if available, otherwise create a new one
    local frame = table.remove(framePool)
    if frame then
        frame:SetParent(container)
        frame:ClearAllPoints()
        -- Hide existing rows
        if frame.rows then
            for _, row in ipairs(frame.rows) do
                row:Hide()
            end
        end
    else
        frame = CreateFrame("Frame", nil, container, "BackdropTemplate")
        frame:SetSize(180, 40)
        frame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            tileSize = 0,
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })

        -- Player name
        frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.name:SetPoint("TOPLEFT", 5, -4)

        -- Kick count (successful/total) after name
        frame.kickCount = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.kickCount:SetPoint("LEFT", frame.name, "RIGHT", 4, 0)
        frame.kickCount:SetTextColor(0.7, 0.7, 0.7)

        frame.rows = {}
    end

    -- Apply current colors
    local barBg = UIThingsDB.kick.barBgColor
    local barBorder = UIThingsDB.kick.barBorderColor
    frame:SetBackdropColor(barBg.r, barBg.g, barBg.b, barBg.a)
    frame:SetBackdropBorderColor(barBorder.r, barBorder.g, barBorder.b, barBorder.a)

    -- Set name and initial count
    local unitName = UnitName(unit) or "Unknown"
    frame.name:SetText(unitName)
    local counts = interruptCounts[guid]
    if counts and counts.total > 0 then
        frame.kickCount:SetText(string.format("(%d)", counts.total))
    else
        frame.kickCount:SetText("")
    end

    -- Get all interrupt spells for this unit
    local unitSpells = GetUnitKickSpells(unit)
    local guid = UnitGUID(unit)
    if #unitSpells == 0 and not UnitIsUnit(unit, "player") and not (guid and knownSpells[guid] ~= nil) then
        -- Only use fallback for other players without explicit data (not for self)
        local fallback = GetUnitKickSpell(unit)
        if fallback then unitSpells = { fallback } end
    end

    -- Create/reuse rows for each spell
    frame.spellOrder = {}
    for i, spellID in ipairs(unitSpells) do
        -- Create row if it doesn't exist yet
        if not frame.rows[i] then
            frame.rows[i] = CreateSpellRow(frame, i)
        end

        local row = frame.rows[i]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 5, -(NAME_HEIGHT + (i - 1) * ROW_HEIGHT))

        -- Set icon
        local spellTexture = C_Spell.GetSpellTexture(spellID)
        row.icon:SetTexture(spellTexture)
        row.icon:SetDesaturated(false)

        -- Reset bar
        row.bar:SetValue(1)
        row.cdText:SetText("")
        row.spellID = spellID
        row:Show()

        frame.spellOrder[i] = spellID
    end

    -- Hide unused rows
    for i = #unitSpells + 1, #frame.rows do
        frame.rows[i]:Hide()
    end

    frame.numSpells = #unitSpells
    -- Resize frame based on number of spell rows
    frame:SetHeight(NAME_HEIGHT + #unitSpells * ROW_HEIGHT + 4)

    -- If there are active cooldowns for this player, apply them immediately
    if interruptCooldowns[guid] then
        Kick.UpdatePartyFrame(guid)
    end

    frame.guid = guid
    frame.unit = unit

    partyFrames[guid] = frame
    Kick.UpdatePartyLayout()

    return frame
end

function Kick.UpdatePartyFrame(guid)
    local frame = partyFrames[guid]
    if not frame then return end

    local cooldowns = interruptCooldowns[guid] or {}

    -- Collect active cooldowns and sort by remaining time
    local activeCDs = {}
    local now = GetTime()
    for spellID, cdInfo in pairs(cooldowns) do
        local remaining = cdInfo.endTime - now
        if remaining > 0 then
            table.insert(activeCDs, {
                spellID = spellID,
                remaining = remaining,
                endTime = cdInfo.endTime,
                totalCD = cdInfo.totalCD
            })
        else
            -- Remove expired cooldowns
            cooldowns[spellID] = nil
        end
    end

    -- Sort by remaining time (longest first)
    table.sort(activeCDs, function(a, b) return a.remaining > b.remaining end)

    -- Attached frame mode (multi-icon)
    if frame.icons then
        for _, iconFrame in ipairs(frame.icons) do
            if iconFrame:IsShown() and iconFrame.spellID then
                local cdInfo = cooldowns[iconFrame.spellID]

                -- Check variant spells (same class + same specID)
                if not cdInfo then
                    local iconData = INTERRUPT_SPELLS[iconFrame.spellID]
                    if iconData and iconData.specID then
                        for cdSpellID, cd in pairs(cooldowns) do
                            local cdData = INTERRUPT_SPELLS[cdSpellID]
                            if cdData and cdData.class == iconData.class and cdData.specID == iconData.specID and cdSpellID ~= iconFrame.spellID then
                                cdInfo = cd
                                break
                            end
                        end
                    end
                end

                if cdInfo then
                    local remaining = cdInfo.endTime - now
                    if remaining > 0 then
                        local totalCD = cdInfo.totalCD or INTERRUPT_SPELLS[iconFrame.spellID].cd
                        iconFrame.cooldown:SetCooldown(cdInfo.endTime - totalCD, totalCD)
                    else
                        iconFrame.cooldown:Clear()
                    end
                else
                    iconFrame.cooldown:Clear()
                end
            end
        end

        -- Update count
        local counts = interruptCounts[guid]
        if counts and counts.total > 0 then
            frame.count:SetText(counts.total)
        else
            frame.count:SetText("")
        end
        return
    end

    if frame.rows then
        -- Row-based frame mode: each row has its own icon + bar for a specific spell
        for i, row in ipairs(frame.rows) do
            if not row:IsShown() then break end

            local spellID = row.spellID
            local cdInfo = cooldowns[spellID]

            -- If no direct match, check variant spells from the same class AND same specID
            -- (e.g., if we're showing Spell Lock row but they used Command Demon 132409)
            -- Only matches spells that occupy the same spec slot — prevents Sigil of Silence
            -- from also triggering the Disrupt bar on Demon Hunters
            if not cdInfo then
                local rowData = INTERRUPT_SPELLS[spellID]
                if rowData and rowData.specID then
                    for cdSpellID, cd in pairs(cooldowns) do
                        local cdData = INTERRUPT_SPELLS[cdSpellID]
                        if cdData and cdData.class == rowData.class and cdData.specID == rowData.specID and cdSpellID ~= spellID then
                            cdInfo = cd
                            spellID = cdSpellID
                            break
                        end
                    end
                end
            end

            if cdInfo then
                local remaining = cdInfo.endTime - now
                if remaining > 0 then
                    local totalCD = cdInfo.totalCD or INTERRUPT_SPELLS[spellID].cd
                    local progress = remaining / totalCD

                    row.bar:SetValue(1 - progress)
                    row.cdText:SetText(string.format("%.1f", remaining))
                    row.icon:SetDesaturated(true)
                else
                    cooldowns[spellID] = nil
                    row.bar:SetValue(1)
                    row.cdText:SetText("")
                    row.icon:SetDesaturated(false)
                end
            else
                row.bar:SetValue(1)
                row.cdText:SetText("")
                row.icon:SetDesaturated(false)
            end
        end
    end

    -- Clean up empty cooldown table
    if not next(cooldowns) then
        interruptCooldowns[guid] = nil
    end
end

function Kick.UpdatePartyLayout()
    local container = CreatePartyContainer()

    local yOffset = -30
    local index = 0

    local function PlaceFrame(guid)
        local f = partyFrames[guid]
        if not f then return end
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", container, "TOPLEFT", 5, yOffset)
        f:SetPoint("RIGHT", container, "RIGHT", -5, 0)
        f:Show()
        index = index + 1
        yOffset = yOffset - (f:GetHeight() + 4)
    end

    -- Always show player first
    local playerGUID = UnitGUID("player")
    PlaceFrame(playerGUID)

    -- Then party/raid members
    if IsInRaid() then
        for i = 1, 40 do
            local unit = "raid" .. i
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                local guid = UnitGUID(unit)
                if guid then PlaceFrame(guid) end
            end
        end
    else
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                local guid = UnitGUID(unit)
                if guid then PlaceFrame(guid) end
            end
        end
    end

    -- Resize container based on actual content
    container:SetHeight(math.abs(yOffset) + 10)

    if index > 0 and UIThingsDB.kick.enabled then
        container:Show()
    else
        container:Hide()
    end
end

-- == UPDATE LOOP ==

local updateFrame = CreateFrame("Frame")
local elapsed = 0

local updateLoopRunning = false

local function OnUpdateHandler(self, delta)
    elapsed = elapsed + delta
    if elapsed >= 0.1 then
        elapsed = 0
        local anyActive = false
        for guid, _ in pairs(partyFrames) do
            if interruptCooldowns[guid] then
                anyActive = true
            end
            Kick.UpdatePartyFrame(guid)
        end
        if not anyActive then
            updateLoopRunning = false
            updateFrame:SetScript("OnUpdate", nil)
        end
    end
end

StartUpdateLoop = function()
    if updateLoopRunning then return end
    updateLoopRunning = true
    elapsed = 0
    updateFrame:SetScript("OnUpdate", OnUpdateHandler)
end

local function StopUpdateLoop()
    updateLoopRunning = false
    updateFrame:SetScript("OnUpdate", nil)
end

function Kick.RebuildPartyFrames()
    -- Debug: log what triggered the rebuild and current cooldown state
    local cdCount = 0
    for guid, cds in pairs(interruptCooldowns) do
        for _ in pairs(cds) do cdCount = cdCount + 1 end
    end
    addonTable.Core.Log("Kick", string.format("RebuildPartyFrames called — %d active cooldowns", cdCount), 0)

    -- Hide and clean up attached frames
    for unit, frame in pairs(attachedFrames) do
        frame:Hide()
    end

    -- Pool existing frames for reuse
    for guid, frame in pairs(partyFrames) do
        -- Don't pool attached frames, just hide them
        if not frame.icons then
            frame:Hide()
            table.insert(framePool, frame)
        end
    end
    wipe(partyFrames)

    -- Clean up knownSpells and interruptCooldowns for GUIDs no longer in the group
    local validGUIDs = {}
    local playerGUID = UnitGUID("player")
    if playerGUID then validGUIDs[playerGUID] = true end
    if IsInGroup() then
        if IsInRaid() then
            for i = 1, 40 do
                local unit = "raid" .. i
                if UnitExists(unit) then
                    local guid = UnitGUID(unit)
                    if guid then validGUIDs[guid] = true end
                end
            end
        else
            for i = 1, 4 do
                local unit = "party" .. i
                if UnitExists(unit) then
                    local guid = UnitGUID(unit)
                    if guid then validGUIDs[guid] = true end
                end
            end
        end
    end
    for guid in pairs(knownSpells) do
        if not validGUIDs[guid] then
            knownSpells[guid] = nil
        end
    end
    for guid in pairs(interruptCooldowns) do
        if not validGUIDs[guid] then
            interruptCooldowns[guid] = nil
        end
    end

    if not UIThingsDB.kick.enabled then
        StopUpdateLoop()
        if partyContainer then
            partyContainer:Hide()
        end
        return
    end

    local useAttached = UIThingsDB.kick.attachToPartyFrames

    -- Create frame for player
    local playerGUID = UnitGUID("player")
    if playerGUID then
        if useAttached then
            CreateAttachedFrame(playerGUID, "player")
        else
            CreatePartyFrame(playerGUID, "player")
        end
    end

    -- Create frames for party/raid members
    if IsInGroup() then
        if IsInRaid() then
            -- In raid, create frames for raid members
            for i = 1, 40 do
                local unit = "raid" .. i
                if UnitExists(unit) and not UnitIsUnit(unit, "player") and UnitIsConnected(unit) then
                    local guid = UnitGUID(unit)
                    if guid then
                        if useAttached then
                            CreateAttachedFrame(guid, unit)
                        else
                            CreatePartyFrame(guid, unit)
                        end
                    end
                end
            end
        else
            -- In party, create frames for party members
            for i = 1, 4 do
                local unit = "party" .. i
                if UnitExists(unit) and UnitIsConnected(unit) then
                    local guid = UnitGUID(unit)
                    if guid then
                        if useAttached then
                            CreateAttachedFrame(guid, unit)
                        else
                            CreatePartyFrame(guid, unit)
                        end
                    end
                end
            end
        end
    end

    if useAttached then
        -- Hide the container when using attached mode
        if partyContainer then
            partyContainer:Hide()
        end
    else
        Kick.UpdatePartyLayout()
    end

    StopUpdateLoop()
end

function Kick.UpdateSettings()
    if Kick.ApplyEvents then Kick.ApplyEvents() end

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

        -- Apply colors
        local bg = UIThingsDB.kick.bgColor
        local border = UIThingsDB.kick.borderColor
        partyContainer:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
        partyContainer:SetBackdropBorderColor(border.r, border.g, border.b, border.a)
    end

    Kick.RebuildPartyFrames()
end

-- == EVENT HANDLING ==

local function OnEvent(self, event, ...)
    if not UIThingsDB.kick then return end

    if event == "PLAYER_ENTERING_WORLD" then
        wipe(interruptCounts)
        Kick.ApplyEvents()
        if UIThingsDB.kick.enabled then
            Kick.RebuildPartyFrames()
            -- Broadcast our spells after entering world (throttled)
            addonTable.Comm.ScheduleThrottled("KICK_SPELLS", 3, function()
                Kick.BroadcastSpells()
            end)
            -- Request spells from others after our broadcast (they may have loaded before us)
            addonTable.Comm.ScheduleThrottled("KICK_REQ", 5, function()
                addonTable.Comm.Send("KICK", "REQ", "")
            end)
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if UIThingsDB.kick.enabled then
            Kick.RebuildPartyFrames()
            -- Delayed rebuild so unit frames are available for attached mode
            addonTable.Core.SafeAfter(0.5, function()
                if UIThingsDB.kick.enabled then
                    Kick.RebuildPartyFrames()
                end
            end)
            -- Broadcast our spells when group changes (throttled)
            addonTable.Comm.ScheduleThrottled("KICK_SPELLS", 3, function()
                Kick.BroadcastSpells()
            end)
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if UIThingsDB.kick.enabled then
            Kick.RebuildPartyFrames()
            addonTable.Core.SafeAfter(0.5, function()
                if UIThingsDB.kick.enabled then
                    Kick.RebuildPartyFrames()
                end
            end)
            -- Re-broadcast spells after spec change (throttled)
            addonTable.Comm.ScheduleThrottled("KICK_SPELLS", 2, function()
                Kick.BroadcastSpells()
            end)
        end
    elseif event == "SPELLS_CHANGED" then
        if UIThingsDB.kick.enabled then
            -- Throttle heavily — SPELLS_CHANGED fires many times during login
            addonTable.Comm.ScheduleThrottled("KICK_SPELLS", 5, function()
                Kick.BroadcastSpells()
                Kick.RebuildPartyFrames()
            end)
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_SENT" then
        if not UIThingsDB.kick.enabled then return end

        -- UNIT_SPELLCAST_SENT args: (unit, target, castGUID, spellID)
        -- UNIT_SPELLCAST_SUCCEEDED args: (unit, castGUID, spellID)
        local unit, spellID
        if event == "UNIT_SPELLCAST_SENT" then
            local u, _, _, sid = ...
            unit, spellID = u, sid
        else
            local u, _, sid = ...
            unit, spellID = u, sid
        end

        if issecretvalue(spellID) then return end
        -- Check if it's an interrupt spell
        if INTERRUPT_SPELLS[spellID] then
            -- Only track the player's own casts; party members are tracked via addon comms
            if unit == "player" then
                -- Prevent double-tracking if both SENT and SUCCEEDED fire
                local guid = UnitGUID("player")
                local now = GetTime()
                if not interruptCooldowns[guid] then
                    interruptCooldowns[guid] = {}
                end
                local existing = interruptCooldowns[guid][spellID]
                if existing and (existing.endTime - now) > 2 then
                    -- Already tracking this spell with significant time remaining, skip
                    -- (prevents double-tracking from SENT + SUCCEEDED both firing)
                    return
                end

                -- Get actual cooldown from the game (respects talent modifiers)
                -- Note: duration is a secret value during combat, so check before comparing
                -- Also ignore GCD-length cooldowns (< 2s) which can happen for ground-targeted
                -- spells when queried before the real cooldown starts
                local cooldown = INTERRUPT_SPELLS[spellID].cd
                local cdInfo = C_Spell.GetSpellCooldown(spellID)
                if cdInfo and cdInfo.duration and not issecretvalue(cdInfo.duration) and cdInfo.duration > 2 then
                    cooldown = cdInfo.duration
                end

                interruptCooldowns[guid][spellID] = {
                    spellID = spellID,
                    endTime = now + cooldown,
                    totalCD = cooldown
                }

                IncrementTotal(guid)
                Kick.UpdatePartyFrame(guid)
                SendKickMessage(spellID, cooldown)
                StartUpdateLoop()
            end
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        -- NOTE: The interruptedBy parameter in UNIT_SPELLCAST_INTERRUPTED is a secret value
        -- during combat (issecretvalue() returns true), making it impossible for addons to
        -- reliably identify WHO interrupted a cast. We previously attempted to guess by
        -- checking if anyone used their kick within 1 second, but this is unreliable:
        -- - Multiple interrupts within 1 second cause false attribution
        -- - Someone interrupting a different cast gets false credit
        -- - Network latency can throw off the 1-second window
        --
        -- DECISION: Remove successful interrupt tracking entirely. Only track total kicks used.
        -- This is more honest and prevents misleading statistics.
        --
        -- If you need accurate interrupt tracking, consider using WeakAuras or a boss mod
        -- that has access to more combat log data.
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD") -- Always needed for initialization
frame:SetScript("OnEvent", OnEvent)

function Kick.ApplyEvents()
    if UIThingsDB.kick and UIThingsDB.kick.enabled then
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:RegisterEvent("GROUP_ROSTER_UPDATE")
        frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        frame:RegisterEvent("SPELLS_CHANGED")
        frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        frame:RegisterEvent("UNIT_SPELLCAST_SENT")
    else
        frame:UnregisterEvent("GROUP_ROSTER_UPDATE")
        frame:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        frame:UnregisterEvent("SPELLS_CHANGED")
        frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        frame:UnregisterEvent("UNIT_SPELLCAST_SENT")
        StopUpdateLoop()
        if partyContainer then
            partyContainer:Hide()
        end
        for unit, af in pairs(attachedFrames) do
            af:Hide()
        end
    end
end
