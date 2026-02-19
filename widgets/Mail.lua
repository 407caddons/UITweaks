local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

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

    local function OnMailUpdate()
        if not UIThingsDB.widgets.mail.enabled then return end
        RefreshMailCache()
    end

    mailFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("UPDATE_PENDING_MAIL", OnMailUpdate)
            EventBus.Register("MAIL_INBOX_UPDATE", OnMailUpdate)
            EventBus.Register("PLAYER_ENTERING_WORLD", OnMailUpdate)
            RefreshMailCache()
        else
            EventBus.Unregister("UPDATE_PENDING_MAIL", OnMailUpdate)
            EventBus.Unregister("MAIL_INBOX_UPDATE", OnMailUpdate)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnMailUpdate)
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
