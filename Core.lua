local addonName, addonTable = ...
_G[addonName] = addonTable

addonTable.Core = {}

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        UIThingsDB = UIThingsDB or {}
        UIThingsDB.tracker = UIThingsDB.tracker or {}
        
        -- Safe Default Defaults
        if UIThingsDB.tracker.locked == nil then UIThingsDB.tracker.locked = true end
        if UIThingsDB.tracker.enabled == nil then UIThingsDB.tracker.enabled = true end
        if not UIThingsDB.tracker.width then UIThingsDB.tracker.width = 300 end
        if not UIThingsDB.tracker.height then UIThingsDB.tracker.height = 500 end
        if not UIThingsDB.tracker.font then UIThingsDB.tracker.font = "Fonts\\FRIZQT__.TTF" end
        if not UIThingsDB.tracker.fontSize then UIThingsDB.tracker.fontSize = 12 end
        if not UIThingsDB.tracker.x then UIThingsDB.tracker.x = -20 end
        if not UIThingsDB.tracker.y then UIThingsDB.tracker.y = -250 end
        if not UIThingsDB.tracker.point then UIThingsDB.tracker.point = "TOPRIGHT" end
        if UIThingsDB.tracker.showBorder == nil then UIThingsDB.tracker.showBorder = false end
        if not UIThingsDB.tracker.backgroundColor then UIThingsDB.tracker.backgroundColor = {r=0, g=0, b=0, a=0} end

        UIThingsDB.vendor = UIThingsDB.vendor or {}
        if UIThingsDB.vendor.enabled == nil then UIThingsDB.vendor.enabled = true end
        if UIThingsDB.vendor.autoRepair == nil then UIThingsDB.vendor.autoRepair = true end
        if UIThingsDB.vendor.useGuildRepair == nil then UIThingsDB.vendor.useGuildRepair = false end
        if not UIThingsDB.vendor.sellGreys then UIThingsDB.vendor.sellGreys = true end
        if not UIThingsDB.vendor.repairThreshold then UIThingsDB.vendor.repairThreshold = 20 end
        if not UIThingsDB.vendor.font then UIThingsDB.vendor.font = "Fonts\\FRIZQT__.TTF" end
        if not UIThingsDB.vendor.fontSize then UIThingsDB.vendor.fontSize = 24 end
        if UIThingsDB.vendor.warningLocked == nil then UIThingsDB.vendor.warningLocked = true end
        if not UIThingsDB.vendor.warningPos then UIThingsDB.vendor.warningPos = {point="TOP", x=0, y=-150} end

        UIThingsDB.combat = UIThingsDB.combat or {}
        if UIThingsDB.combat.enabled == nil then UIThingsDB.combat.enabled = true end
        if UIThingsDB.combat.locked == nil then UIThingsDB.combat.locked = true end
        if not UIThingsDB.combat.font then UIThingsDB.combat.font = "Fonts\\FRIZQT__.TTF" end
        if not UIThingsDB.combat.fontSize then UIThingsDB.combat.fontSize = 18 end
        if not UIThingsDB.combat.colorInCombat then UIThingsDB.combat.colorInCombat = {r=1, g=1, b=1} end
        if not UIThingsDB.combat.colorOutCombat then UIThingsDB.combat.colorOutCombat = {r=0.5, g=0.5, b=0.5} end
        if not UIThingsDB.combat.pos then UIThingsDB.combat.pos = {point="CENTER", x=0, y=0} end
        
        print("|cFF00FF00Luna's UI Tweaks Loaded!|r")
        self:UnregisterEvent("ADDON_LOADED")
        
        if addonTable.Config and addonTable.Config.Initialize then
            addonTable.Config.Initialize()
        end
        
        if addonTable.Minimap and addonTable.Minimap.Initialize then
            addonTable.Minimap.Initialize()
        end
        
        -- Slash Commands
        SLASH_UITHINGS1 = "/luit"
        SLASH_UITHINGS2 = "/luithings"
        SlashCmdList["UITHINGS"] = function(msg)
            if addonTable.Config and addonTable.Config.ToggleWindow then
                addonTable.Config.ToggleWindow()
            end
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", OnEvent)
