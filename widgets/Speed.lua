local addonName, addonTable = ...
local Widgets = addonTable.Widgets

table.insert(Widgets.moduleInits, function()
    local speedFrame = Widgets.CreateWidgetFrame("Speed", "speed")
    local BASE_SPEED = 7 -- base run speed in yards/sec

    local function GetCurrentSpeed()
        local isGliding, _, forwardSpeed = C_PlayerInfo.GetGlidingInfo()
        if isGliding and forwardSpeed and forwardSpeed > 0 then
            return forwardSpeed
        end
        local currentSpeed = GetUnitSpeed("player")
        return currentSpeed
    end

    speedFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Movement Speed")

        local isGliding, _, forwardSpeed = C_PlayerInfo.GetGlidingInfo()
        local currentSpeed, runSpeed, flightSpeed, swimSpeed = GetUnitSpeed("player")

        if isGliding and forwardSpeed and forwardSpeed > 0 then
            GameTooltip:AddDoubleLine("Skyriding:", string.format("%.0f%%", (forwardSpeed / BASE_SPEED) * 100), 1, 1, 1,
                0, 0.8, 1)
        else
            GameTooltip:AddDoubleLine("Current:", string.format("%.0f%%", (currentSpeed / BASE_SPEED) * 100), 1, 1, 1, 1,
                1, 1)
        end

        GameTooltip:AddDoubleLine("Run:", string.format("%.0f%%", (runSpeed / BASE_SPEED) * 100), 1, 1, 1, 0.8, 0.8, 0.8)
        GameTooltip:AddDoubleLine("Flight:", string.format("%.0f%%", (flightSpeed / BASE_SPEED) * 100), 1, 1, 1, 0.8, 0.8,
            0.8)
        GameTooltip:AddDoubleLine("Swim:", string.format("%.0f%%", (swimSpeed / BASE_SPEED) * 100), 1, 1, 1, 0.8, 0.8,
            0.8)

        GameTooltip:Show()
    end)
    speedFrame:SetScript("OnLeave", GameTooltip_Hide)

    local function RefreshSpeed(self)
        local speed = GetCurrentSpeed()
        local percent = (speed / BASE_SPEED) * 100
        self.text:SetFormattedText("Speed: %.0f%%", percent)
    end

    -- Use OnUpdate at 0.2s for real-time speed display (skyriding changes rapidly)
    local elapsed = 0
    speedFrame:HookScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.5 then
            elapsed = 0
            if UIThingsDB.widgets.speed.enabled and self:IsShown() then
                RefreshSpeed(self)
            end
        end
    end)

    speedFrame.UpdateContent = function(self)
        RefreshSpeed(self)
    end
end)
