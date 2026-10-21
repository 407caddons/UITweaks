local addon=_G.LunaUITweaks
if not addon.Client or not addon.Client.isForever then return end
-- Keep stable navigation IDs, but never construct a panel which invokes an
-- excluded module. Explain the limitation instead of presenting working toggles.
local unavailable={
    MplusTimer="Mythic+ and seasonal keystones are Retail features.",
    TalentManager="Forever talent build comparison/import/application needs a separate implementation. Use Blizzard's talent UI for now.",
    Talent="Automatic talent reminders and build application are disabled while Forever's talent rules are validated.",
    Warehousing="Automatic bank transfers are disabled until Forever bank layouts and item eligibility have been validated.",
    QueueTimer="Automatic dungeon queue handling has not been validated for Forever.",
    CompactGroupFinder="The Retail group-finder row layout is not enabled in this first pass.",
}
for key,reason in pairs(unavailable) do
    local text=reason
    addon.ConfigSetup[key]=function(panel)
        local title=panel:CreateFontString(nil,"OVERLAY","GameFontNormalHuge")
        title:SetPoint("TOPLEFT",20,-20);title:SetText("Forever compatibility")
        local note=panel:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        note:SetPoint("TOPLEFT",20,-65);note:SetWidth(580);note:SetJustifyH("LEFT");note:SetText(text)
    end
end
