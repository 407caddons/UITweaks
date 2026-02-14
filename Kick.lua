local addonName, addonTable = ...
local Kick = {}
addonTable.Kick = Kick

-- == INTERRUPT SPELL DATABASE ==

local INTERRUPT_SPELLS = {
    -- Death Knight
    [47528] = { name = "Mind Freeze", cd = 15, class = "DEATHKNIGHT" },

    -- Demon Hunter
    [183752] = { name = "Disrupt", cd = 15, class = "DEMONHUNTER" },
    [202137] = { name = "Sigil of Silence", cd = 60, class = "DEMONHUNTER" },

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
local interruptCooldowns = {} -- GUID -> { [spellID] = { spellID, endTime } }
local interruptCounts = {}    -- GUID -> { total = N }
local framePool = {}          -- Recycled party frames
local ADDON_PREFIX = "LunaKick"

-- Forward declarations
local StartUpdateLoop
local lastInterruptHandledAt = 0

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

local function SendKickMessage(spellID)
    if not UIThingsDB.kick.enabled then return end
    -- Check if in a group
    if not IsInGroup() then return end
    -- Respect hideFromWorld setting
    if UIThingsDB.addonComm and UIThingsDB.addonComm.hideFromWorld then return end

    local message = string.format("%d:%d", spellID, GetTime())
    -- Use RAID channel if in raid, otherwise PARTY
    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, message, channel)
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
        -- Check party members (party1-4)
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) and UnitName(unit) == sender then
                senderGUID = UnitGUID(unit)
                break
            end
        end

        -- If not found and in raid, check raid members (raid1-40)
        if not senderGUID and IsInRaid() then
            for i = 1, 40 do
                local unit = "raid" .. i
                if UnitExists(unit) and UnitName(unit) == sender then
                    senderGUID = UnitGUID(unit)
                    break
                end
            end
        end
    end

    if not senderGUID then return end

    -- If we don't have a frame for this sender yet, rebuild so they get one
    if not partyFrames[senderGUID] then
        Kick.RebuildPartyFrames()
    end

    -- Store cooldown info (support multiple cooldowns per player)
    local cooldown = INTERRUPT_SPELLS[spellID].cd
    if not interruptCooldowns[senderGUID] then
        interruptCooldowns[senderGUID] = {}
    end
    interruptCooldowns[senderGUID][spellID] = {
        spellID = spellID,
        endTime = GetTime() + cooldown
    }

    IncrementTotal(senderGUID)
    Kick.UpdatePartyFrame(senderGUID)
    StartUpdateLoop()
end

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
local function CreateAttachedFrame(guid, unit)
    -- Find the actual Blizzard unit frame
    local blizzFrame = FindUnitFrame(unit)

    if not blizzFrame then
        return nil
    end

    -- Create or reuse frame
    local frame = attachedFrames[unit]

    if not frame then
        -- Attach to UIParent instead of the party frame (which may be hidden)
        frame = CreateFrame("Frame", "LunaKickAttached_" .. unit, UIParent, "BackdropTemplate")
        frame:SetSize(28, 28) -- Small icon size
        frame:SetFrameStrata("MEDIUM")

        -- Store reference to the blizz frame for positioning
        frame.blizzFrame = blizzFrame

        -- Set up OnUpdate to dynamically position based on the blizz frame
        frame:SetScript("OnUpdate", function(self, elapsed)
            if self.blizzFrame and self.blizzFrame:IsShown() then
                -- Position relative to the blizz frame based on anchor point setting
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

        -- Subtle border
        frame:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            tileSize = 0,
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        frame:SetBackdropBorderColor(0, 0, 0, 0.8)

        -- Icon
        frame.icon = frame:CreateTexture(nil, "ARTWORK")
        frame.icon:SetAllPoints()
        frame.icon:SetTexture(nil)

        -- Cooldown spiral
        frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
        frame.cooldown:SetAllPoints()
        frame.cooldown:SetDrawEdge(true)
        frame.cooldown:SetHideCountdownNumbers(false)

        -- Count text (kick count)
        frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.count:SetPoint("BOTTOMRIGHT", 2, 2)
        frame.count:SetTextColor(1, 1, 1)

        attachedFrames[unit] = frame
    end

    -- Update icon texture
    local spellID = GetUnitKickSpell(unit)
    if spellID then
        local spellTexture = C_Spell.GetSpellTexture(spellID)
        frame.icon:SetTexture(spellTexture)
    end

    -- Update count
    local counts = interruptCounts[guid]
    if counts and counts.total > 0 then
        frame.count:SetText(counts.total)
    else
        frame.count:SetText("")
    end

    -- Reset cooldown
    frame.cooldown:Clear()

    frame.guid = guid
    frame.unit = unit

    -- Update the blizzFrame reference in case it changed
    frame.blizzFrame = blizzFrame

    -- Force show (OnUpdate will handle positioning)
    frame:Show()

    partyFrames[guid] = frame
    return frame
end

local function CreatePartyFrame(guid, unit)
    local container = CreatePartyContainer()

    -- Reuse a pooled frame if available, otherwise create a new one
    local frame = table.remove(framePool)
    if frame then
        frame:SetParent(container)
        frame:ClearAllPoints()
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
        frame.name:SetPoint("TOPLEFT", 45, -5)

        -- Kick count (successful/total) after name
        frame.kickCount = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.kickCount:SetPoint("LEFT", frame.name, "RIGHT", 4, 0)
        frame.kickCount:SetTextColor(0.7, 0.7, 0.7)

        -- Interrupt icon
        frame.icon = frame:CreateTexture(nil, "ARTWORK")
        frame.icon:SetSize(32, 32)
        frame.icon:SetPoint("LEFT", 5, 0)

        -- Cooldown bars (support up to 2 for classes with multiple interrupts)
        frame.bars = {}

        -- Primary bar (bar1)
        frame.bars[1] = CreateFrame("StatusBar", nil, frame)
        frame.bars[1]:SetSize(120, 16)
        frame.bars[1]:SetPoint("BOTTOMRIGHT", -5, 5)
        frame.bars[1]:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        frame.bars[1]:SetStatusBarColor(0.2, 0.8, 0.2, 1)
        frame.bars[1]:SetMinMaxValues(0, 1)
        frame.bars[1]:SetValue(1)

        frame.bars[1].bg = frame.bars[1]:CreateTexture(nil, "BACKGROUND")
        frame.bars[1].bg:SetAllPoints()
        frame.bars[1].bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        frame.bars[1].bg:SetVertexColor(0.2, 0.2, 0.2, 0.5)

        frame.bars[1].cdText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.bars[1].cdText:SetPoint("CENTER", frame.bars[1], "CENTER", 0, 0)
        frame.bars[1].cdText:SetText("Ready")

        -- Secondary bar (bar2) - initially hidden
        frame.bars[2] = CreateFrame("StatusBar", nil, frame)
        frame.bars[2]:SetSize(120, 16)
        frame.bars[2]:SetPoint("BOTTOMRIGHT", -5, 23)
        frame.bars[2]:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        frame.bars[2]:SetStatusBarColor(0.8, 0.6, 0.2, 1)
        frame.bars[2]:SetMinMaxValues(0, 1)
        frame.bars[2]:SetValue(1)
        frame.bars[2]:Hide()

        frame.bars[2].bg = frame.bars[2]:CreateTexture(nil, "BACKGROUND")
        frame.bars[2].bg:SetAllPoints()
        frame.bars[2].bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        frame.bars[2].bg:SetVertexColor(0.2, 0.2, 0.2, 0.5)

        frame.bars[2].cdText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.bars[2].cdText:SetPoint("CENTER", frame.bars[2], "CENTER", 0, 0)
        frame.bars[2].cdText:SetText("Ready")

        -- Legacy compatibility (frame.bar points to bars[1])
        frame.bar = frame.bars[1]
        frame.cdText = frame.bars[1].cdText
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
        -- Only show total kicks used (successful tracking removed due to API limitations)
        frame.kickCount:SetText(string.format("(%d)", counts.total))
    else
        frame.kickCount:SetText("")
    end

    -- Set interrupt icon
    local spellID = GetUnitKickSpell(unit)
    if spellID then
        local spellTexture = C_Spell.GetSpellTexture(spellID)
        frame.icon:SetTexture(spellTexture)
    end

    -- Reset bar states
    for i = 1, 2 do
        if frame.bars[i] then
            frame.bars[i]:SetValue(1)
            frame.bars[i].cdText:SetText("Ready")
            if i == 2 then
                frame.bars[i]:Hide()
            else
                frame.bars[i]:Show()
            end
        end
    end
    frame.icon:SetDesaturated(false)

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
                endTime = cdInfo.endTime
            })
        else
            -- Remove expired cooldowns
            cooldowns[spellID] = nil
        end
    end

    -- Sort by remaining time (longest first)
    table.sort(activeCDs, function(a, b) return a.remaining > b.remaining end)

    -- If this is an attached frame (has cooldown property), update it differently
    if frame.cooldown then
        -- Attached frame mode
        local cdData = activeCDs[1] -- Show only the first cooldown
        if cdData then
            local spellData = INTERRUPT_SPELLS[cdData.spellID]
            local totalCD = spellData.cd
            frame.cooldown:SetCooldown(cdData.endTime - totalCD, totalCD)
        else
            frame.cooldown:Clear()
        end

        -- Update count
        local counts = interruptCounts[guid]
        if counts and counts.total > 0 then
            frame.count:SetText(counts.total)
        else
            frame.count:SetText("")
        end
    else
        -- Regular frame mode
        local hasAnyCooldown = false
        for i = 1, 2 do
            local bar = frame.bars[i]
            if not bar then break end

            local cdData = activeCDs[i]
            if cdData then
                hasAnyCooldown = true
                local spellData = INTERRUPT_SPELLS[cdData.spellID]
                local totalCD = spellData.cd
                local progress = cdData.remaining / totalCD

                bar:SetValue(1 - progress)
                bar.cdText:SetText(string.format("%.1f", cdData.remaining))
                bar:Show()

                -- Show spell name as tooltip on bar hover
                if not bar.spellName then
                    bar.spellName = spellData.name
                end
            else
                -- No cooldown for this bar slot
                bar:SetValue(1)
                bar.cdText:SetText("Ready")
                if i == 2 then
                    bar:Hide() -- Hide second bar if not needed
                else
                    bar:Show()
                end
            end
        end

        -- Desaturate icon if any cooldown is active
        frame.icon:SetDesaturated(hasAnyCooldown)
    end

    -- Clean up empty cooldown table
    if not next(cooldowns) then
        interruptCooldowns[guid] = nil
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

    -- Then party/raid members
    if IsInRaid() then
        -- In raid, iterate raid members
        for i = 1, 40 do
            local unit = "raid" .. i
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                local guid = UnitGUID(unit)
                if guid and partyFrames[guid] then
                    partyFrames[guid]:SetPoint("TOP", container, "TOP", 0, yOffset)
                    partyFrames[guid]:Show()
                    index = index + 1
                    yOffset = yOffset - 45
                end
            end
        end
    else
        -- In party, iterate party members
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
    -- Hide and clean up attached frames
    for unit, frame in pairs(attachedFrames) do
        frame:Hide()
    end

    -- Pool existing frames for reuse
    for guid, frame in pairs(partyFrames) do
        -- Don't pool attached frames, just hide them
        if not frame.cooldown then
            frame:Hide()
            table.insert(framePool, frame)
        end
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
                if UnitExists(unit) and not UnitIsUnit(unit, "player") then
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
                if UnitExists(unit) then
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
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if not UIThingsDB.kick.enabled then return end

        local unit, _, spellID = ...
        if issecretvalue(spellID) then return end
        -- Check if it's an interrupt spell
        if INTERRUPT_SPELLS[spellID] then
            -- Only track the player's own casts; party members are tracked via addon comms
            if unit == "player" then
                local guid = UnitGUID("player")
                local cooldown = INTERRUPT_SPELLS[spellID].cd

                -- Store cooldown info (support multiple cooldowns per player)
                if not interruptCooldowns[guid] then
                    interruptCooldowns[guid] = {}
                end
                interruptCooldowns[guid][spellID] = {
                    spellID = spellID,
                    endTime = GetTime() + cooldown
                }

                IncrementTotal(guid)
                Kick.UpdatePartyFrame(guid)
                SendKickMessage(spellID)
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
    elseif event == "CHAT_MSG_ADDON" then
        OnAddonMessage(...)
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD") -- Always needed for initialization
frame:SetScript("OnEvent", OnEvent)

-- Register addon message prefix on load
C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)

function Kick.ApplyEvents()
    if UIThingsDB.kick and UIThingsDB.kick.enabled then
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:RegisterEvent("GROUP_ROSTER_UPDATE")
        frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        frame:RegisterEvent("CHAT_MSG_ADDON")
    else
        frame:UnregisterEvent("GROUP_ROSTER_UPDATE")
        frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        frame:UnregisterEvent("CHAT_MSG_ADDON")
        StopUpdateLoop()
        if partyContainer then
            partyContainer:Hide()
        end
        for unit, af in pairs(attachedFrames) do
            af:Hide()
        end
    end
end
