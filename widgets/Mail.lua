local addonName, addonTable = ...
local Widgets = addonTable.Widgets

table.insert(Widgets.moduleInits, function()
    local mailFrame = Widgets.CreateWidgetFrame("Mail", "mail")

    local cachedText = "No Mail"

    local function RefreshMailCache()
        if HasNewMail() then
            cachedText = "|cFF00FF00Mail|r"
        else
            cachedText = "|cFF888888No Mail|r"
        end
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UPDATE_PENDING_MAIL")
    eventFrame:RegisterEvent("MAIL_INBOX_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function()
        if not UIThingsDB.widgets.mail.enabled then return end
        RefreshMailCache()
    end)

    mailFrame.eventFrame = eventFrame
    mailFrame.ApplyEvents = function(enabled)
        if enabled then
            eventFrame:RegisterEvent("UPDATE_PENDING_MAIL")
            eventFrame:RegisterEvent("MAIL_INBOX_UPDATE")
            eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
            RefreshMailCache()
        else
            eventFrame:UnregisterAllEvents()
        end
    end

    mailFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Mail")
        if HasNewMail() then
            GameTooltip:AddLine("You have new mail!", 0, 1, 0)
        else
            GameTooltip:AddLine("No new mail", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    mailFrame:SetScript("OnLeave", GameTooltip_Hide)

    mailFrame.UpdateContent = function(self)
        self.text:SetText(cachedText)
    end
end)
