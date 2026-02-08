local addonName, addonTable = ...

-- This file will be loaded and will set up the main config window
-- Individual panel setup files will be loaded afterward

addonTable.Config = {}

local configWindow
local Helpers = addonTable.ConfigHelpers

-- Store panel and tab references for panel setup files to access
addonTable.ConfigPanels = {}
addonTable.ConfigTabs = {}

function addonTable.Config.Initialize()
    -- Initialize the window if it doesn't exist
    if not configWindow then
        configWindow = CreateFrame("Frame", "UIThingsConfigWindow", UIParent, "BasicFrameTemplateWithInset")
        configWindow:SetSize(600, 670)
        configWindow:SetPoint("CENTER")
        configWindow:SetMovable(true)
        configWindow:EnableMouse(true)
        configWindow:SetFrameStrata("DIALOG")
        tinsert(UISpecialFrames, "UIThingsConfigWindow")
        configWindow:RegisterForDrag("LeftButton")
        configWindow:SetScript("OnDragStart", configWindow.StartMoving)
        configWindow:SetScript("OnDragStop", configWindow.StopMovingOrSizing)

        configWindow:SetScript("OnHide", function()
            -- Auto-lock frames on close
            if UIThingsDB.frames and UIThingsDB.frames.list then
                for _, f in ipairs(UIThingsDB.frames.list) do
                    f.locked = true
                end
                if addonTable.Frames and addonTable.Frames.UpdateFrames then
                    addonTable.Frames.UpdateFrames()
                end
            end

            -- Auto-lock Loot Anchor
            if addonTable.Loot and addonTable.Loot.LockAnchor then
                addonTable.Loot.LockAnchor()
            end
        end)
        configWindow:Hide()

        configWindow.TitleText:SetText("Luna's UI Tweaks Config")

        -- Create Sub-Panels
        local trackerPanel = CreateFrame("Frame", nil, configWindow)
        trackerPanel:SetAllPoints()

        local vendorPanel = CreateFrame("Frame", nil, configWindow)
        vendorPanel:SetAllPoints()
        vendorPanel:Hide()

        local combatPanel = CreateFrame("Frame", nil, configWindow)
        combatPanel:SetAllPoints()
        combatPanel:Hide()

        local framesPanel = CreateFrame("Frame", nil, configWindow)
        framesPanel:SetAllPoints()
        framesPanel:Hide()

        local lootPanel = CreateFrame("Frame", nil, configWindow)
        lootPanel:SetAllPoints()
        lootPanel:Hide()

        local miscPanel = CreateFrame("Frame", nil, configWindow)
        miscPanel:SetAllPoints()
        miscPanel:Hide()

        local talentPanel = CreateFrame("Frame", nil, configWindow)
        talentPanel:SetAllPoints()
        talentPanel:Hide()

        -- Store panels for access by setup functions
        addonTable.ConfigPanels.tracker = trackerPanel
        addonTable.ConfigPanels.vendor = vendorPanel
        addonTable.ConfigPanels.combat = combatPanel
        addonTable.ConfigPanels.frames = framesPanel
        addonTable.ConfigPanels.loot = lootPanel
        addonTable.ConfigPanels.misc = miscPanel
        addonTable.ConfigPanels.talent = talentPanel

        -- Tab Buttons
        local tab1 = CreateFrame("Button", nil, configWindow, "PanelTabButtonTemplate")
        tab1:SetPoint("BOTTOMLEFT", configWindow, "BOTTOMLEFT", 10, -30)
        tab1:SetText("Tracker")
        tab1:SetID(1)

        local tab2 = CreateFrame("Button", nil, configWindow, "PanelTabButtonTemplate")
        tab2:SetPoint("LEFT", tab1, "RIGHT", 5, 0)
        tab2:SetText("Vendor")
        tab2:SetID(2)

        local tab3 = CreateFrame("Button", nil, configWindow, "PanelTabButtonTemplate")
        tab3:SetPoint("LEFT", tab2, "RIGHT", 5, 0)
        tab3:SetText("Combat")
        tab3:SetID(3)

        local tab4 = CreateFrame("Button", nil, configWindow, "PanelTabButtonTemplate")
        tab4:SetPoint("LEFT", tab3, "RIGHT", 5, 0)
        tab4:SetText("Frames")
        tab4:SetID(4)

        local tab5 = CreateFrame("Button", nil, configWindow, "PanelTabButtonTemplate")
        tab5:SetPoint("LEFT", tab4, "RIGHT", 5, 0)
        tab5:SetText("Loot")
        tab5:SetID(5)

        local tab6 = CreateFrame("Button", nil, configWindow, "PanelTabButtonTemplate")
        tab6:SetPoint("LEFT", tab5, "RIGHT", 5, 0)
        tab6:SetText("Misc")
        tab6:SetID(6)

        local tab7 = CreateFrame("Button", nil, configWindow, "PanelTabButtonTemplate")
        tab7:SetPoint("LEFT", tab6, "RIGHT", 5, 0)
        tab7:SetText("Talents")
        tab7:SetID(7)

        -- Store tabs
        configWindow.Tabs = { tab1, tab2, tab3, tab4, tab5, tab6, tab7 }
        addonTable.ConfigTabs = configWindow.Tabs

        PanelTemplates_SetNumTabs(configWindow, 7)
        PanelTemplates_SetTab(configWindow, 1)

        -- Tab click handler
        local function TabOnClick(self)
            PanelTemplates_SetTab(configWindow, self:GetID())
            trackerPanel:Hide()
            vendorPanel:Hide()
            combatPanel:Hide()
            framesPanel:Hide()
            lootPanel:Hide()
            miscPanel:Hide()
            talentPanel:Hide()

            local id = self:GetID()
            if id == 1 then
                trackerPanel:Show()
            elseif id == 2 then
                vendorPanel:Show()
            elseif id == 3 then
                combatPanel:Show()
            elseif id == 4 then
                framesPanel:Show()
            elseif id == 5 then
                lootPanel:Show()
            elseif id == 6 then
                miscPanel:Show()
            elseif id == 7 then
                talentPanel:Show()
                -- Refresh talent reminder list when showing
                if addonTable.Config.RefreshTalentReminderList then
                    addonTable.Config.RefreshTalentReminderList()
                end
            end
        end

        tab1:SetScript("OnClick", TabOnClick)
        tab2:SetScript("OnClick", TabOnClick)
        tab3:SetScript("OnClick", TabOnClick)
        tab4:SetScript("OnClick", TabOnClick)
        tab5:SetScript("OnClick", TabOnClick)
        tab6:SetScript("OnClick", TabOnClick)
        tab7:SetScript("OnClick", TabOnClick)

        -- Now that the window and panels are created, call setup functions from panel files
        -- Panel files are loaded by the TOC file before ConfigMain
        if addonTable.ConfigSetup then
            -- Setup all panels
            if addonTable.ConfigSetup.Tracker then
                addonTable.ConfigSetup.Tracker(trackerPanel, tab1, configWindow)
            end
            if addonTable.ConfigSetup.Vendor then
                addonTable.ConfigSetup.Vendor(vendorPanel, tab2, configWindow)
            end
            if addonTable.ConfigSetup.Combat then
                addonTable.ConfigSetup.Combat(combatPanel, tab3, configWindow)
            end
            if addonTable.ConfigSetup.Frames then
                addonTable.ConfigSetup.Frames(framesPanel, tab4, configWindow)
            end
            if addonTable.ConfigSetup.Loot then
                addonTable.ConfigSetup.Loot(lootPanel, tab5, configWindow)
            end
            if addonTable.ConfigSetup.Misc then
                addonTable.ConfigSetup.Misc(miscPanel, tab6, configWindow)
            end
            if addonTable.ConfigSetup.Talent then
                addonTable.ConfigSetup.Talent(talentPanel, tab7, configWindow)
            end
        end
    end
end

function addonTable.Config.ToggleWindow()
    if not configWindow then
        addonTable.Config.Initialize()
    end

    if configWindow:IsShown() then
        configWindow:Hide()
    else
        configWindow:Show()
    end
end

-- Global function for Addon Compartment
function LunaUITweaks_OpenConfig()
    if addonTable.Config and addonTable.Config.ToggleWindow then
        addonTable.Config.ToggleWindow()
    end
end
