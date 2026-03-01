local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

local DMF_WHEE_SPELL_ID = 46668  -- Darkmoon Faire Carousel buff (+10% XP/rep, 1hr)

-- Returns true if the Darkmoon Faire is currently active (first full week of each month)
local function IsDMFActive()
    local now = time()
    local today = date("*t", now)
    local firstOfMonth = time({ year = today.year, month = today.month, day = 1, hour = 0, min = 0, sec = 0 })
    local firstDow = date("*t", firstOfMonth).wday  -- 1 = Sunday
    local firstSunday = 1 + (8 - firstDow) % 7
    if firstSunday > 7 then firstSunday = firstSunday - 7 end
    local dmfStart = time({ year = today.year, month = today.month, day = firstSunday, hour = 0, min = 0, sec = 0 })
    local dmfEnd = dmfStart + (7 * 86400) - 1
    return now >= dmfStart and now <= dmfEnd
end

table.insert(Widgets.moduleInits, function()
    local wheeFrame = Widgets.CreateWidgetFrame("WheeCheck", "wheeCheck")

    local function Refresh()
        if not UIThingsDB.widgets.wheeCheck.enabled then return end
        if InCombatLockdown() then return end

        if not IsDMFActive() then
            wheeFrame.text:SetText("")
            return
        end

        local aura = C_UnitAuras.GetPlayerAuraBySpellID(DMF_WHEE_SPELL_ID)
        if aura then
            local remaining = aura.expirationTime - GetTime()
            local m = math.floor(remaining / 60)
            local s = math.floor(remaining % 60)
            wheeFrame.text:SetText(string.format("|cFF00FF00WHEE! %d:%02d|r", m, s))
        else
            wheeFrame.text:SetText("|cFFFF6666WHEE! \226\156\152|r")
        end
    end

    local function OnAura(event, unitTarget)
        if unitTarget ~= "player" then return end
        Refresh()
    end

    local function OnCombatStart()
        EventBus.Unregister("UNIT_AURA", OnAura)
        wheeFrame.text:SetText("")
    end

    local function OnCombatEnd()
        EventBus.Register("UNIT_AURA", OnAura, "W:WheeCheck")
        Refresh()
    end

    wheeFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("UNIT_AURA", OnAura, "W:WheeCheck")
            EventBus.Register("PLAYER_REGEN_DISABLED", OnCombatStart, "W:WheeCheck")
            EventBus.Register("PLAYER_REGEN_ENABLED", OnCombatEnd, "W:WheeCheck")
            Refresh()
        else
            EventBus.Unregister("UNIT_AURA", OnAura)
            EventBus.Unregister("PLAYER_REGEN_DISABLED", OnCombatStart)
            EventBus.Unregister("PLAYER_REGEN_ENABLED", OnCombatEnd)
            wheeFrame.text:SetText("")
        end
    end

    wheeFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("DMF WHEE! Buff", 1, 1, 1)

        if not IsDMFActive() then
            GameTooltip:AddLine("Darkmoon Faire is not active.", 0.7, 0.7, 0.7)
            GameTooltip:Show()
            return
        end

        local aura = C_UnitAuras.GetPlayerAuraBySpellID(DMF_WHEE_SPELL_ID)
        if aura then
            local remaining = aura.expirationTime - GetTime()
            local m = math.floor(remaining / 60)
            local s = math.floor(remaining % 60)
            GameTooltip:AddDoubleLine("Status:", "|cFF00FF00Active|r", 1, 1, 1, 1, 1, 1)
            GameTooltip:AddDoubleLine("Remaining:", string.format("%d:%02d", m, s), 1, 1, 1, 1, 0.82, 0)
            GameTooltip:AddLine("+10% XP and reputation", 0.7, 0.7, 0.7)
        else
            GameTooltip:AddDoubleLine("Status:", "|cFFFF6666Not active|r", 1, 1, 1, 1, 1, 1)
            GameTooltip:AddLine("Ride the Darkmoon Carousel to get it.", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    wheeFrame:SetScript("OnLeave", GameTooltip_Hide)

    wheeFrame.UpdateContent = function(self)
        Refresh()
    end
end)
