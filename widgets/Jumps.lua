local addonName, addonTable = ...
local Widgets = addonTable.Widgets

-- Jump counter: session and per-character lifetime jumps, plus a per-encounter
-- "jumping champions" board shared with other Luna users after each encounter
-- (one message per player per encounter, never per jump; addon chat is locked
-- during encounters, so nothing is sent until ENCOUNTER_END).
table.insert(Widgets.moduleInits, function()
    local jumpFrame = Widgets.CreateWidgetFrame("Jumps", "jumps")
    local Comm = addonTable.Comm
    local session, encounterJumps, inEncounter = 0, 0, false
    local board, boardName, collecting = {}, nil, nil

    local function DB() return UIThingsDB.widgets.jumps end
    local function Lifetime()
        local key = addonTable.Core.GetCharacterKey()
        local db = DB()
        db.lifetime = db.lifetime or {}
        return db.lifetime[key] or 0, key
    end
    local function MyName()
        return addonTable.Secret.SafeUnitName("player", "You")
    end

    -- A real jump starts on the ground. Ascending while flying or swimming
    -- also calls JumpOrAscendStart and is not counted.
    local function OnJump()
        if not DB().enabled then return end
        if IsFlying() or IsSwimming() or IsFalling() then return end
        session = session + 1
        local total, key = Lifetime()
        DB().lifetime[key] = total + 1
        if inEncounter then encounterJumps = encounterJumps + 1 end
        if jumpFrame:IsShown() then jumpFrame:UpdateContent() end
    end
    -- Post-hook only: never replaces or calls the protected movement function.
    if type(JumpOrAscendStart) == "function" then hooksecurefunc("JumpOrAscendStart", OnJump) end

    local function Sorted()
        local list = {}
        for name, count in pairs(board) do list[#list + 1] = { name = name, count = count } end
        table.sort(list, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return a.name < b.name
        end)
        return list
    end

    -- Only the winner posts, as the original WeakAura did, so a group of Luna
    -- users produces one announcement.
    local function FinishBoard()
        collecting = nil
        local list = Sorted()
        if not DB().postChampions or #list < 2 or list[1].name ~= MyName() or list[1].count == 0 then return end
        if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return end
        local channel = Comm.GetChannel()
        if not channel then return end
        local parts = {}
        for i = 1, math.min(5, #list) do parts[#parts + 1] = list[i].name .. " " .. list[i].count end
        pcall(SendChatMessage, "Jumping champions: " .. table.concat(parts, ", "), channel)
    end

    local function StartBoard(name)
        wipe(board)
        boardName = name
        board[MyName()] = encounterJumps
        collecting = true
        Comm.Send("JUMP", "ENC", tostring(encounterJumps))
        addonTable.Core.SafeAfter(4, FinishBoard)
    end
    Comm.Register("JUMP", "ENC", function(sender, payload)
        local count = tonumber(payload)
        if collecting and count and sender then board[sender] = count end
    end)

    addonTable.EventBus.Register("ENCOUNTER_START", function()
        inEncounter, encounterJumps = true, 0
    end, "W:Jumps")
    addonTable.EventBus.Register("ENCOUNTER_END", function(_, _, name)
        if not inEncounter then return end
        inEncounter = false
        if not DB().enabled then return end
        local label = addonTable.Secret.IsPublic(name) and name or "Last encounter"
        -- Give the client a moment to lift the encounter chat lockdown.
        addonTable.Core.SafeAfter(1, function() StartBoard(label) end)
    end, "W:Jumps")

    jumpFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        if not Widgets.SmartAnchorTooltip(self) then return end
        GameTooltip:SetText("Jump Counter")
        GameTooltip:AddDoubleLine("This session:", session, 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("This character:", (Lifetime()), 1, 1, 1, 1, 1, 1)
        if inEncounter then GameTooltip:AddDoubleLine("This encounter:", encounterJumps, 1, 1, 1, 1, 0.82, 0) end
        local list = Sorted()
        if #list > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Jumping champions: " .. (boardName or "last encounter"), 1, 0.82, 0)
            for i = 1, math.min(10, #list) do
                GameTooltip:AddDoubleLine(i .. ". " .. list[i].name, list[i].count, 1, 1, 1, 1, 1, 1)
            end
            GameTooltip:AddLine("Only group members running LunaUITweaks are listed.", 0.5, 0.5, 0.5)
        end
        GameTooltip:Show()
    end)
    jumpFrame:SetScript("OnLeave", GameTooltip_Hide)

    jumpFrame.UpdateContent = function(self)
        self.text:SetFormattedText("Jumps: %d", session)
    end
end)
