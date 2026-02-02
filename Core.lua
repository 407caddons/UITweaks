local addonName, addonTable = ...
_G[addonName] = addonTable

addonTable.Core = {}

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        UIThingsDB = UIThingsDB or {}
        UIThingsDB.tracker = UIThingsDB.tracker or {}
        
        -- Safe Default Defaults
        if UIThingsDB.tracker.locked == nil then UIThingsDB.tracker.locked = true end
        if UIThingsDB.tracker.enabled == nil then UIThingsDB.tracker.enabled = false end
        if not UIThingsDB.tracker.width then UIThingsDB.tracker.width = 300 end
        if not UIThingsDB.tracker.height then UIThingsDB.tracker.height = 500 end
        if not UIThingsDB.tracker.font then UIThingsDB.tracker.font = "Fonts\\FRIZQT__.TTF" end
        if not UIThingsDB.tracker.fontSize then UIThingsDB.tracker.fontSize = 12 end
        -- Specific Fonts
        if not UIThingsDB.tracker.headerFont then UIThingsDB.tracker.headerFont = "Fonts\\FRIZQT__.TTF" end
        if not UIThingsDB.tracker.headerFontSize then UIThingsDB.tracker.headerFontSize = 14 end
        if not UIThingsDB.tracker.detailFont then UIThingsDB.tracker.detailFont = "Fonts\\FRIZQT__.TTF" end
        if not UIThingsDB.tracker.detailFontSize then UIThingsDB.tracker.detailFontSize = 12 end
        if not UIThingsDB.tracker.questPadding then UIThingsDB.tracker.questPadding = 2 end
        if not UIThingsDB.tracker.sectionOrder then UIThingsDB.tracker.sectionOrder = 1 end -- Default: WQ, Quests, Ach
        if not UIThingsDB.tracker.onlyActiveWorldQuests then UIThingsDB.tracker.onlyActiveWorldQuests = false end
        if not UIThingsDB.tracker.activeQuestColor then UIThingsDB.tracker.activeQuestColor = {r=0, g=1, b=0, a=1} end
        if not UIThingsDB.tracker.x then UIThingsDB.tracker.x = -20 end
        if not UIThingsDB.tracker.y then UIThingsDB.tracker.y = -250 end
        if not UIThingsDB.tracker.point then UIThingsDB.tracker.point = "TOPRIGHT" end
        if UIThingsDB.tracker.showBorder == nil then UIThingsDB.tracker.showBorder = false end
        if UIThingsDB.tracker.hideInCombat == nil then UIThingsDB.tracker.hideInCombat = false end
        if UIThingsDB.tracker.hideInMPlus == nil then UIThingsDB.tracker.hideInMPlus = false end
        if not UIThingsDB.tracker.backgroundColor then UIThingsDB.tracker.backgroundColor = {r=0, g=0, b=0, a=0} end
        if not UIThingsDB.tracker.strata then UIThingsDB.tracker.strata = "LOW" end

        UIThingsDB.minimap = UIThingsDB.minimap or { angle = 45 }

        UIThingsDB.vendor = UIThingsDB.vendor or {}
        if UIThingsDB.vendor.enabled == nil then UIThingsDB.vendor.enabled = false end
        if UIThingsDB.vendor.autoRepair == nil then UIThingsDB.vendor.autoRepair = true end
        if UIThingsDB.vendor.useGuildRepair == nil then UIThingsDB.vendor.useGuildRepair = false end
        if not UIThingsDB.vendor.sellGreys then UIThingsDB.vendor.sellGreys = true end
        if not UIThingsDB.vendor.repairThreshold then UIThingsDB.vendor.repairThreshold = 20 end
        if not UIThingsDB.vendor.font then UIThingsDB.vendor.font = "Fonts\\FRIZQT__.TTF" end
        if not UIThingsDB.vendor.fontSize then UIThingsDB.vendor.fontSize = 24 end
        if UIThingsDB.vendor.warningLocked == nil then UIThingsDB.vendor.warningLocked = true end
        if not UIThingsDB.vendor.warningPos then UIThingsDB.vendor.warningPos = {point="TOP", x=0, y=-150} end

        -- Loot Defaults
        UIThingsDB.loot = UIThingsDB.loot or {}
        if UIThingsDB.loot.enabled == nil then UIThingsDB.loot.enabled = false end
        if UIThingsDB.loot.growUp == nil then UIThingsDB.loot.growUp = true end
        if UIThingsDB.loot.fasterLoot == nil then UIThingsDB.loot.fasterLoot = false end
        if not UIThingsDB.loot.fasterLootDelay then UIThingsDB.loot.fasterLootDelay = 0.3 end
        if not UIThingsDB.loot.duration then UIThingsDB.loot.duration = 3 end
        if not UIThingsDB.loot.minQuality then UIThingsDB.loot.minQuality = 1 end -- 0=Grey, 1=White...
        if not UIThingsDB.loot.font then UIThingsDB.loot.font = "Fonts\\FRIZQT__.TTF" end
        if not UIThingsDB.loot.fontSize then UIThingsDB.loot.fontSize = 14 end
        if not UIThingsDB.loot.iconSize then UIThingsDB.loot.iconSize = 32 end
        -- NOTE: Anchor default can be nil initially, handled in Loot.lua or Config
        if not UIThingsDB.loot.anchor then UIThingsDB.loot.anchor = {point="CENTER", x=0, y=200} end

        UIThingsDB.combat = UIThingsDB.combat or {}
        if UIThingsDB.combat.enabled == nil then UIThingsDB.combat.enabled = false end
        if UIThingsDB.combat.locked == nil then UIThingsDB.combat.locked = true end
        if not UIThingsDB.combat.font then UIThingsDB.combat.font = "Fonts\\FRIZQT__.TTF" end
        if not UIThingsDB.combat.fontSize then UIThingsDB.combat.fontSize = 18 end
        if not UIThingsDB.combat.colorInCombat then UIThingsDB.combat.colorInCombat = {r=1, g=1, b=1} end
        if not UIThingsDB.combat.colorOutCombat then UIThingsDB.combat.colorOutCombat = {r=0.5, g=0.5, b=0.5} end
        if not UIThingsDB.combat.pos then UIThingsDB.combat.pos = {point="CENTER", x=0, y=0} end
        
        -- Frames Defaults
        UIThingsDB.frames = UIThingsDB.frames or {}
        if UIThingsDB.frames.enabled == nil then UIThingsDB.frames.enabled = false end
        if not UIThingsDB.frames.list then UIThingsDB.frames.list = {} end
        
        print("|cFF00FF00Luna's UI Tweaks Loaded!|r")
        self:UnregisterEvent("ADDON_LOADED")
        -- Misc Defaults
        UIThingsDB.misc = UIThingsDB.misc or {}
        if UIThingsDB.misc.enabled == nil then UIThingsDB.misc.enabled = false end
        if UIThingsDB.misc.ahFilter == nil then UIThingsDB.misc.ahFilter = false end
        if UIThingsDB.misc.personalOrders == nil then UIThingsDB.misc.personalOrders = false end
        if not UIThingsDB.misc.ttsMessage then UIThingsDB.misc.ttsMessage = "Personal order arrived" end
        if not UIThingsDB.misc.alertDuration then UIThingsDB.misc.alertDuration = 5 end
        if not UIThingsDB.misc.alertColor then UIThingsDB.misc.alertColor = {r=1, g=0, b=0, a=1} end
        
        -- Initialize Modules
        if addonTable.Config and addonTable.Config.Initialize then
            addonTable.Config.Initialize()
        end
        
        if addonTable.Minimap and addonTable.Minimap.Initialize then
            addonTable.Minimap.Initialize()
        end

        if addonTable.Frames and addonTable.Frames.Initialize then
            addonTable.Frames.Initialize()
        end
        
        -- Slash Commands
        SLASH_UITHINGS1 = "/luit"
        SLASH_UITHINGS2 = "/luithings"
        
        -- Global function for Addon Compartment
        function LunaUITweaks_OpenConfig()
            if addonTable.Config and addonTable.Config.ToggleWindow then
                addonTable.Config.ToggleWindow()
            end
        end
        
        SlashCmdList["UITHINGS"] = function(msg)
            LunaUITweaks_OpenConfig()
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", OnEvent)
