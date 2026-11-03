local addonName, addonTable = ...
local Widgets = addonTable.Widgets

-- Dead group members: count on the widget, names in the tooltip. Unit state
-- can be secret in restricted content; unreadable members are not counted.
table.insert(Widgets.moduleInits, function()
    local deadFrame = Widgets.CreateWidgetFrame("DeadGroup", "deadGroup")
    local Public, SafeUnitName = addonTable.Secret.IsPublic, addonTable.Secret.SafeUnitName

    local function GroupUnits()
        if IsInRaid() then
            local units = {}
            for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
            return units
        end
        local units = { "player" }
        for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
        return units
    end

    -- Returns dead (true/false/nil when unreadable) and a short status.
    local function DeadState(unit)
        local exists = UnitExists(unit)
        if not Public(exists) or not exists then return nil end
        local dead = UnitIsDeadOrGhost(unit)
        if not Public(dead) then return nil end
        if not dead then return false end
        local ghost, incoming = UnitIsGhost(unit), UnitHasIncomingResurrection and UnitHasIncomingResurrection(unit)
        if Public(incoming) and incoming then return true, "res incoming" end
        if Public(ghost) and ghost then return true, "released" end
        return true
    end

    local function CountDead()
        local count = 0
        for _, unit in ipairs(GroupUnits()) do
            if DeadState(unit) then count = count + 1 end
        end
        return count
    end

    deadFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        if not Widgets.SmartAnchorTooltip(self) then return end
        GameTooltip:SetText("Dead Group Members")
        local any = false
        for _, unit in ipairs(GroupUnits()) do
            local dead, status = DeadState(unit)
            if dead then
                any = true
                GameTooltip:AddDoubleLine(SafeUnitName(unit, "Unknown"), status or "dead", 1, 1, 1, 1, 0.4, 0.4)
            end
        end
        if not any then GameTooltip:AddLine("Nobody is dead.", 0.5, 1, 0.5) end
        GameTooltip:Show()
    end)
    deadFrame:SetScript("OnLeave", GameTooltip_Hide)

    deadFrame.UpdateContent = function(self)
        local count = CountDead()
        if count > 0 then
            self.text:SetFormattedText("|cFFFF4040Dead: %d|r", count)
        else
            self.text:SetText("|cFF888888Dead: 0|r")
        end
    end
end)
