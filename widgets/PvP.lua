local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

-- Currency IDs
local HONOR_CURRENCY_ID = 1792
local CONQUEST_CURRENCY_ID = 1602

table.insert(Widgets.moduleInits, function()
    local pvpFrame = Widgets.CreateWidgetFrame("PvP", "pvp")

    -- Cached text (updated on events)
    local cachedText = "PvP"

    local function RefreshPvPCache()
        local honorLevel = UnitHonorLevel("player")
        local honor = UnitHonor("player")
        local honorMax = UnitHonorMax("player")

        -- Get conquest from currency API
        local conquestInfo = C_CurrencyInfo.GetCurrencyInfo(CONQUEST_CURRENCY_ID)
        local conquest = conquestInfo and conquestInfo.quantity or 0

        if honorLevel and honorLevel > 0 then
            cachedText = string.format("H:%d C:%d", honor or 0, conquest)
        else
            cachedText = "PvP"
        end
    end

    local function OnPvPUpdate()
        RefreshPvPCache()
    end

    pvpFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("HONOR_LEVEL_UPDATE", OnPvPUpdate, "W:PvP")
            EventBus.Register("HONOR_XP_UPDATE", OnPvPUpdate, "W:PvP")
            EventBus.Register("CURRENCY_DISPLAY_UPDATE", OnPvPUpdate, "W:PvP")
            EventBus.Register("PLAYER_ENTERING_WORLD", OnPvPUpdate, "W:PvP")
            EventBus.Register("PVP_RATED_STATS_UPDATE", OnPvPUpdate, "W:PvP")
        else
            EventBus.Unregister("HONOR_LEVEL_UPDATE", OnPvPUpdate)
            EventBus.Unregister("HONOR_XP_UPDATE", OnPvPUpdate)
            EventBus.Unregister("CURRENCY_DISPLAY_UPDATE", OnPvPUpdate)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnPvPUpdate)
            EventBus.Unregister("PVP_RATED_STATS_UPDATE", OnPvPUpdate)
        end
    end

    pvpFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("PvP Info")

        local honorLevel = UnitHonorLevel("player")
        local honor = UnitHonor("player")
        local honorMax = UnitHonorMax("player")

        GameTooltip:AddDoubleLine("Honor Level:", tostring(honorLevel or 0), 1, 1, 1, 1, 1, 1)
        if honorMax and honorMax > 0 then
            GameTooltip:AddDoubleLine("Honor:", string.format("%d / %d", honor or 0, honorMax), 1, 1, 1, 0.8, 0.8, 0.8)
        end

        -- Conquest
        local conquestInfo = C_CurrencyInfo.GetCurrencyInfo(CONQUEST_CURRENCY_ID)
        if conquestInfo then
            local conquestText = tostring(conquestInfo.quantity)
            if conquestInfo.maxQuantity and conquestInfo.maxQuantity > 0 then
                conquestText = string.format("%d / %d", conquestInfo.quantity, conquestInfo.maxQuantity)
            end
            GameTooltip:AddDoubleLine("Conquest:", conquestText, 1, 1, 1, 1, 0.82, 0)
        end

        -- Weekly progress
        local weeklyProgress = C_WeeklyRewards.GetConquestWeeklyProgress()
        if weeklyProgress then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Weekly Conquest", 1, 0.82, 0)
            GameTooltip:AddDoubleLine("Progress:",
                string.format("%d / %d", weeklyProgress.progress or 0, weeklyProgress.maxProgress or 0), 1, 1, 1, 0.8,
                0.8, 0.8)
        end

        -- Rated info
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Rated PvP", 1, 0.82, 0)

        local brackets = {
            { bracket = 1, name = "2v2 Arena" },
            { bracket = 2, name = "3v3 Arena" },
            { bracket = 4, name = "Solo Shuffle" },
            { bracket = 6, name = "RBG Blitz" },
        }

        for _, info in ipairs(brackets) do
            local rating, seasonBest = GetPersonalRatedInfo(info.bracket)
            if rating and rating > 0 then
                local ratingText = tostring(rating)
                if seasonBest and seasonBest > rating then
                    ratingText = string.format("%d (best: %d)", rating, seasonBest)
                end
                GameTooltip:AddDoubleLine(info.name .. ":", ratingText, 1, 1, 1, 0.8, 0.8, 0.8)
            end
        end

        -- War Mode
        if C_PvP.IsWarModeDesired() then
            GameTooltip:AddLine(" ")
            local bonus = C_PvP.GetWarModeRewardBonus()
            GameTooltip:AddDoubleLine("War Mode:", string.format("+%d%% bonus", bonus or 0), 1, 1, 1, 0, 1, 0)
        end

        GameTooltip:Show()
    end)
    pvpFrame:SetScript("OnLeave", GameTooltip_Hide)

    pvpFrame.UpdateContent = function(self)
        self.text:SetText(cachedText)
    end
end)
