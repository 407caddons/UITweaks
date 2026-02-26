local addonName, addonTable = ...
local Widgets = addonTable.Widgets
local EventBus = addonTable.EventBus

table.insert(Widgets.moduleInits, function()
    local mailFrame = Widgets.CreateWidgetFrame("Mail", "mail")

    local cachedText = "No Mail"
    local cachedCount = 0
    local cachedWithGold = 0
    local cachedWithItems = 0
    local cachedLettersOnly = 0
    local mailboxOpen = false

    local function ScanInbox()
        local count = GetInboxNumItems()
        cachedCount = count
        cachedWithGold = 0
        cachedWithItems = 0
        cachedLettersOnly = 0
        for i = 1, count do
            local _, _, _, _, money, _, _, itemCount = GetInboxHeaderInfo(i)
            if money and money > 0 then
                cachedWithGold = cachedWithGold + 1
            elseif itemCount and itemCount > 0 then
                cachedWithItems = cachedWithItems + 1
            else
                cachedLettersOnly = cachedLettersOnly + 1
            end
        end
    end

    local function RefreshMailCache()
        if mailboxOpen then
            ScanInbox()
            if cachedCount > 0 then
                if cachedWithGold > 0 or cachedWithItems > 0 then
                    cachedText = "|cFF00FF00Mail: " .. cachedCount .. "|r"
                else
                    cachedText = "Mail: " .. cachedCount
                end
            else
                cachedText = "|cFF888888No Mail|r"
            end
        else
            -- No mailbox access — use cached count if available, else HasNewMail
            if cachedCount > 0 then
                if cachedWithGold > 0 or cachedWithItems > 0 then
                    cachedText = "|cFF00FF00Mail: " .. cachedCount .. "|r"
                else
                    cachedText = "Mail: " .. cachedCount
                end
            elseif HasNewMail() then
                cachedText = "|cFF00FF00Mail|r"
            else
                cachedText = "|cFF888888No Mail|r"
            end
        end
    end

    local function OnMailUpdate()
        if not UIThingsDB.widgets.mail.enabled then return end
        RefreshMailCache()
    end

    local function OnMailShow()
        if not UIThingsDB.widgets.mail.enabled then return end
        mailboxOpen = true
        RefreshMailCache()
    end

    local function OnMailClosed()
        if not UIThingsDB.widgets.mail.enabled then return end
        mailboxOpen = false
        -- Keep cachedCount from the session for display between visits
        RefreshMailCache()
    end

    mailFrame.ApplyEvents = function(enabled)
        if enabled then
            EventBus.Register("UPDATE_PENDING_MAIL", OnMailUpdate, "W:Mail")
            EventBus.Register("MAIL_INBOX_UPDATE", OnMailUpdate, "W:Mail")
            EventBus.Register("PLAYER_ENTERING_WORLD", OnMailUpdate, "W:Mail")
            EventBus.Register("MAIL_SHOW", OnMailShow, "W:Mail")
            EventBus.Register("MAIL_CLOSED", OnMailClosed, "W:Mail")
            RefreshMailCache()
        else
            EventBus.Unregister("UPDATE_PENDING_MAIL", OnMailUpdate)
            EventBus.Unregister("MAIL_INBOX_UPDATE", OnMailUpdate)
            EventBus.Unregister("PLAYER_ENTERING_WORLD", OnMailUpdate)
            EventBus.Unregister("MAIL_SHOW", OnMailShow)
            EventBus.Unregister("MAIL_CLOSED", OnMailClosed)
        end
    end

    mailFrame:SetScript("OnEnter", function(self)
        if not UIThingsDB.widgets.locked then return end
        Widgets.SmartAnchorTooltip(self)
        GameTooltip:SetText("Mail")
        if cachedCount > 0 then
            GameTooltip:AddLine("Total messages: " .. cachedCount, 1, 1, 1)
            if cachedWithGold > 0 then
                GameTooltip:AddLine("  With gold: " .. cachedWithGold, 1, 0.82, 0)
            end
            if cachedWithItems > 0 then
                GameTooltip:AddLine("  With items: " .. cachedWithItems, 0.4, 0.8, 1)
            end
            if cachedLettersOnly > 0 then
                GameTooltip:AddLine("  Letters: " .. cachedLettersOnly, 0.8, 0.8, 0.8)
            end
            if not mailboxOpen then
                GameTooltip:AddLine("(From last mailbox visit)", 0.5, 0.5, 0.5)
            end
        elseif HasNewMail() then
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
