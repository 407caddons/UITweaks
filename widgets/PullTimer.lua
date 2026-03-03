local addonName, addonTable = ...
local Widgets = addonTable.Widgets

local PULL_DURATION = 10  -- seconds

table.insert(Widgets.moduleInits, function()
    local pullFrame = Widgets.CreateWidgetFrame("PullTimer", "pullTimer")
    pullFrame:RegisterForClicks("AnyUp")

    local pullActive = false
    local pullStartTime = nil
    local pullCancelled = false   -- guards the fallback chat countdown
    local cachedText = "|cFF888888Pull|r"

    -- --------------------------------------------------------
    -- Backend Detection
    -- --------------------------------------------------------
    local function GetBackend()
        if C_AddOns.IsAddOnLoaded("BigWigs") or C_AddOns.IsAddOnLoaded("BigWigs_Core") then
            return "bigwigs"
        elseif C_AddOns.IsAddOnLoaded("DBM-Core") then
            return "dbm"
        end
        return "none"
    end

    local function GetBackendLabel(backend)
        if backend == "bigwigs" then return "BigWigs"
        elseif backend == "dbm" then return "DBM"
        else return "Chat Countdown"
        end
    end

    -- --------------------------------------------------------
    -- Fallback chat countdown (used when no raid timer addon)
    -- --------------------------------------------------------
    local function DoChatCountdown()
        pullCancelled = false
        local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or nil)

        local count = PULL_DURATION
        local function Tick()
            if pullCancelled then return end
            if count <= 0 then
                if channel then SendChatMessage("PULL!", channel) end
                return
            end
            -- Announce at start (full duration) then 5 down to 1
            if channel and (count == PULL_DURATION or count <= 5) then
                SendChatMessage(tostring(count), channel)
            end
            count = count - 1
            C_Timer.After(1, Tick)
        end
        C_Timer.After(0, Tick)
    end

    local function CancelChatCountdown()
        pullCancelled = true
        local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or nil)
        if channel then
            SendChatMessage("Pull cancelled.", channel)
        end
    end

    -- --------------------------------------------------------
    -- Start / Cancel
    -- --------------------------------------------------------
    local function StartPull()
        pullActive = true
        pullStartTime = GetTime()
        cachedText = string.format("|cFF00FF00Pull: %d|r", PULL_DURATION)

        local backend = GetBackend()
        if backend == "bigwigs" then
            -- BigWigs registers SLASH_BigWigsPull1 = "/pull"
            if SlashCmdList["BigWigsPull"] then
                SlashCmdList["BigWigsPull"](tostring(PULL_DURATION))
            elseif BigWigs and BigWigs.SendMessage then
                BigWigs:SendMessage("BigWigs_SetPull", BigWigs, PULL_DURATION)
            end
        elseif backend == "dbm" then
            if DBM and DBM.StartPull then
                DBM:StartPull(PULL_DURATION)
            elseif SlashCmdList["DBMPull"] then
                SlashCmdList["DBMPull"](tostring(PULL_DURATION))
            end
        else
            DoChatCountdown()
        end
    end

    local function CancelPull()
        pullCancelled = true
        pullActive = false
        pullStartTime = nil

        local backend = GetBackend()
        if backend == "bigwigs" then
            if SlashCmdList["BigWigsPull"] then
                SlashCmdList["BigWigsPull"]("cancel")
            end
        elseif backend == "dbm" then
            if DBM and DBM.StopPull then
                DBM:StopPull()
            end
        else
            CancelChatCountdown()
        end

        cachedText = "|cFF888888Pull|r"
    end

    -- --------------------------------------------------------
    -- Tooltip
    -- --------------------------------------------------------
    pullFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Pull Timer", 1, 0.82, 0)
        GameTooltip:AddDoubleLine("Timer backend:", GetBackendLabel(GetBackend()),
            1, 1, 1, 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        if pullActive then
            GameTooltip:AddLine("Click to cancel pull", 1, 0.4, 0.4)
        else
            GameTooltip:AddLine(string.format("Click to start %ds pull timer", PULL_DURATION),
                0.5, 0.5, 1)
        end
        GameTooltip:Show()
    end)

    pullFrame:SetScript("OnLeave", GameTooltip_Hide)

    -- --------------------------------------------------------
    -- Click handler
    -- --------------------------------------------------------
    pullFrame:SetScript("OnClick", function(self, button)
        if button ~= "LeftButton" or not UIThingsDB.widgets.locked then return end
        if pullActive then
            CancelPull()
        else
            StartPull()
        end
        self.text:SetText(cachedText)
        GameTooltip:Hide()
    end)

    -- --------------------------------------------------------
    -- Update (called every 1s by widget ticker)
    -- --------------------------------------------------------
    pullFrame.UpdateContent = function(self)
        if pullActive and pullStartTime then
            local remaining = PULL_DURATION - (GetTime() - pullStartTime)

            if remaining <= 0 then
                -- Natural expiry
                pullActive = false
                pullStartTime = nil
                cachedText = "|cFFFF0000PULL!|r"
                self.text:SetText(cachedText)
                -- Reset label after 3 seconds
                C_Timer.After(3, function()
                    if not pullActive then
                        cachedText = "|cFF888888Pull|r"
                        if self:IsShown() then
                            self.text:SetText(cachedText)
                        end
                    end
                end)
                return
            end

            local secs = math.ceil(remaining)
            local color = secs <= 3 and "|cFFFF4444" or secs <= 5 and "|cFFFFAA00" or "|cFF00FF00"
            cachedText = string.format("%sPull: %d|r", color, secs)
        end
        self.text:SetText(cachedText)
    end
end)
