local addonName, addonTable = ...
_G[addonName] = addonTable

addonTable.Core = {}

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        UIThingsDB = UIThingsDB or {}
        UIThingsDB.tracker = UIThingsDB.tracker or {}
        
        -- Safe Default Defaults
        if UIThingsDB.tracker.locked == nil then UIThingsDB.tracker.locked = true end
        if not UIThingsDB.tracker.width then UIThingsDB.tracker.width = 300 end
        if not UIThingsDB.tracker.height then UIThingsDB.tracker.height = 500 end
        if not UIThingsDB.tracker.x then UIThingsDB.tracker.x = -20 end
        if not UIThingsDB.tracker.y then UIThingsDB.tracker.y = -250 end
        if not UIThingsDB.tracker.point then UIThingsDB.tracker.point = "TOPRIGHT" end
        
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
