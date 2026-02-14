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
        configWindow:SetSize(850, 670) -- Increased width for sidebar
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

            -- Auto-lock Widgets
            if UIThingsDB.widgets then
                UIThingsDB.widgets.locked = true
                if addonTable.Widgets and addonTable.Widgets.UpdateVisuals then
                    addonTable.Widgets.UpdateVisuals()
                end
            end
        end)
        configWindow:Hide()

        configWindow.TitleText:SetText("Luna's UI Tweaks Config")

        ----------------------------------------------------
        -- Sidebar & Navigation
        ----------------------------------------------------
        local SIDEBAR_WIDTH = 180

        -- Vertical Divider Line
        local divider = configWindow:CreateTexture(nil, "ARTWORK")
        divider:SetPoint("TOPLEFT", configWindow, "TOPLEFT", SIDEBAR_WIDTH, -25)
        divider:SetPoint("BOTTOMLEFT", configWindow, "BOTTOMLEFT", SIDEBAR_WIDTH, 5)
        divider:SetWidth(1)
        divider:SetColorTexture(0.3, 0.3, 0.3, 1)

        -- ScrollFrame for Navigation List
        local navScrollFrame = CreateFrame("ScrollFrame", "UIThingsConfigNavScroll", configWindow,
            "UIPanelScrollFrameTemplate")
        navScrollFrame:SetPoint("TOPLEFT", configWindow, "TOPLEFT", 10, -30)
        navScrollFrame:SetPoint("BOTTOMRIGHT", configWindow, "BOTTOMLEFT", SIDEBAR_WIDTH - 25, 10)

        local navScrollChild = CreateFrame("Frame", nil, navScrollFrame)
        navScrollChild:SetSize(SIDEBAR_WIDTH - 25, 500) -- Height will auto-expand if needed
        navScrollFrame:SetScrollChild(navScrollChild)

        -- List of Modules
        local modules = {
            { id = 1,  name = "Tracker",        key = "tracker",       icon = "Interface\\Icons\\Inv_Misc_Book_09" },
            { id = 2,  name = "Vendor",         key = "vendor",        icon = "Interface\\Icons\\Inv_Misc_Coin_02" },
            { id = 3,  name = "Combat",         key = "combat",        icon = "Interface\\Icons\\Ability_Warrior_OffensiveStance" },
            { id = 4,  name = "Frames",         key = "frames",        icon = "Interface\\Icons\\Inv_Box_01" },
            { id = 5,  name = "Loot",           key = "loot",          icon = "Interface\\Icons\\Inv_Box_02" },
            { id = 6,  name = "Misc",           key = "misc",          icon = "Interface\\Icons\\Inv_Misc_Gear_01" },
            { id = 7,  name = "Minimap",        key = "minimap",       icon = "Interface\\Icons\\Inv_Misc_Map02" },
            { id = 8,  name = "Talents",        key = "talent",        icon = "Interface\\Icons\\Ability_Marksmanship" },
            { id = 9,  name = "Widgets",        key = "widgets",       icon = "Interface\\Icons\\Inv_Misc_PocketWatch_01" },
            { id = 10, name = "Chat",           key = "chatSkin",      icon = "Interface\\Icons\\INV_Misc_Note_06" },
            { id = 11, name = "Kick CDs",       key = "kick",          icon = "Interface\\Icons\\Ability_Kick" },
            { id = 12, name = "Addon Versions", key = "addonVersions", icon = "Interface\\Icons\\Inv_Misc_GroupNeedMore" },
        }

        local navButtons = {}
        local currentPanel = nil

        -- Content Container (Right Side)
        local contentContainer = CreateFrame("Frame", nil, configWindow)
        contentContainer:SetPoint("TOPLEFT", configWindow, "TOPLEFT", SIDEBAR_WIDTH + 10, -30)
        contentContainer:SetPoint("BOTTOMRIGHT", configWindow, "BOTTOMRIGHT", -10, 10)

        ----------------------------------------------------
        -- Create Sub-Panels (parented to contentContainer)
        ----------------------------------------------------
        local trackerPanel = CreateFrame("Frame", nil, contentContainer)
        trackerPanel:SetAllPoints()

        local vendorPanel = CreateFrame("Frame", nil, contentContainer)
        vendorPanel:SetAllPoints()
        vendorPanel:Hide()

        local combatPanel = CreateFrame("Frame", nil, contentContainer)
        combatPanel:SetAllPoints()
        combatPanel:Hide()

        local framesPanel = CreateFrame("Frame", nil, contentContainer)
        framesPanel:SetAllPoints()
        framesPanel:Hide()

        local lootPanel = CreateFrame("Frame", nil, contentContainer)
        lootPanel:SetAllPoints()
        lootPanel:Hide()

        local miscPanel = CreateFrame("Frame", nil, contentContainer)
        miscPanel:SetAllPoints()
        miscPanel:Hide()

        local minimapPanel = CreateFrame("Frame", nil, contentContainer)
        minimapPanel:SetAllPoints()
        minimapPanel:Hide()

        local talentPanel = CreateFrame("Frame", nil, contentContainer)
        talentPanel:SetAllPoints()
        talentPanel:Hide()

        local widgetsPanel = CreateFrame("Frame", nil, contentContainer)
        widgetsPanel:SetAllPoints()
        widgetsPanel:Hide()

        local kickPanel = CreateFrame("Frame", nil, contentContainer)
        kickPanel:SetAllPoints()
        kickPanel:Hide()

        local chatSkinPanel = CreateFrame("Frame", nil, contentContainer)
        chatSkinPanel:SetAllPoints()
        chatSkinPanel:Hide()

        local addonVersionsPanel = CreateFrame("Frame", nil, contentContainer)
        addonVersionsPanel:SetAllPoints()
        addonVersionsPanel:Hide()

        -- Store panels
        addonTable.ConfigPanels.tracker = trackerPanel
        addonTable.ConfigPanels.vendor = vendorPanel
        addonTable.ConfigPanels.combat = combatPanel
        addonTable.ConfigPanels.frames = framesPanel
        addonTable.ConfigPanels.loot = lootPanel
        addonTable.ConfigPanels.misc = miscPanel
        addonTable.ConfigPanels.minimap = minimapPanel
        addonTable.ConfigPanels.talent = talentPanel
        addonTable.ConfigPanels.widgets = widgetsPanel
        addonTable.ConfigPanels.kick = kickPanel
        addonTable.ConfigPanels.chatSkin = chatSkinPanel
        addonTable.ConfigPanels.addonVersions = addonVersionsPanel

        -- Map IDs to Panels
        local idToPanel = {
            [1] = trackerPanel,
            [2] = vendorPanel,
            [3] = combatPanel,
            [4] = framesPanel,
            [5] = lootPanel,
            [6] = miscPanel,
            [7] = minimapPanel,
            [8] = talentPanel,
            [9] = widgetsPanel,
            [10] = chatSkinPanel,
            [11] = kickPanel,
            [12] = addonVersionsPanel,
        }

        ----------------------------------------------------
        -- Navigation Logic
        ----------------------------------------------------
        local function SelectModule(id)
            -- Hide all panels
            for _, p in pairs(idToPanel) do p:Hide() end

            -- Show selected panel
            if idToPanel[id] then
                idToPanel[id]:Show()
            end

            -- Update button visuals
            for i, btn in ipairs(navButtons) do
                if i == id then
                    btn:LockHighlight()
                    if btn.isDisabled then
                        btn.text:SetTextColor(1, 0.5, 0.5) -- Light Red if selected but disabled
                    else
                        btn.text:SetTextColor(1, 1, 1)     -- White
                    end
                else
                    btn:UnlockHighlight()
                    if btn.isDisabled then
                        btn.text:SetTextColor(1, 0.2, 0.2) -- Red if disabled
                    else
                        btn.text:SetTextColor(1, 0.82, 0)  -- Gold
                    end
                end
            end

            -- Special OnShow logic (e.g., refreshing lists)
            if id == 8 and addonTable.Config.RefreshTalentReminderList then
                addonTable.Config.RefreshTalentReminderList()
            end
        end

        ----------------------------------------------------
        -- Create Sidebar Buttons
        ----------------------------------------------------
        local BUTTON_HEIGHT = 30
        for i, mod in ipairs(modules) do
            local btn = CreateFrame("Button", nil, navScrollChild)
            btn:SetSize(SIDEBAR_WIDTH - 25, BUTTON_HEIGHT)
            btn:SetPoint("TOPLEFT", 0, -((i - 1) * BUTTON_HEIGHT))

            -- Visuals
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            btn.Text = btn.text -- Compatibility with Helpers.UpdateModuleVisuals
            btn.text:SetPoint("LEFT", 6, 0)
            btn.text:SetText(mod.name)

            -- Highlight texture
            btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

            btn:SetScript("OnClick", function()
                SelectModule(i)
            end)

            navButtons[i] = btn

            -- Store as tab-like object for compatibility with Helpers.UpdateModuleVisuals
            -- because existing panel setups expect a "tab" to tint red if disabled
            -- so we add a dummy "tab" object or just use the button itself?
            -- Helpers.UpdateModuleVisuals looks for tab.Text or tab:GetFontString()
            -- Button has btn.text, so it should work if we pass btn as 'tab'
        end

        -- Store buttons as "Tabs" for compatibility with setup functions
        -- ConfigMain.lua was setting addonTable.ConfigTabs = configWindow.Tabs
        addonTable.ConfigTabs = navButtons

        -- Select first module by default
        SelectModule(1)

        ----------------------------------------------------
        -- Init Setup Functions
        ----------------------------------------------------
        if addonTable.ConfigSetup then
            -- Setup all panels
            -- Pass 'navButtons[i]' as the 'tab' argument for visual compatibility
            if addonTable.ConfigSetup.Tracker then
                addonTable.ConfigSetup.Tracker(trackerPanel, navButtons[1], configWindow)
            end
            if addonTable.ConfigSetup.Vendor then
                addonTable.ConfigSetup.Vendor(vendorPanel, navButtons[2], configWindow)
            end
            if addonTable.ConfigSetup.Combat then
                addonTable.ConfigSetup.Combat(combatPanel, navButtons[3], configWindow)
            end
            if addonTable.ConfigSetup.Frames then
                addonTable.ConfigSetup.Frames(framesPanel, navButtons[4], configWindow)
            end
            if addonTable.ConfigSetup.Loot then
                addonTable.ConfigSetup.Loot(lootPanel, navButtons[5], configWindow)
            end
            if addonTable.ConfigSetup.Misc then
                addonTable.ConfigSetup.Misc(miscPanel, navButtons[6], configWindow)
            end
            if addonTable.ConfigSetup.Minimap then
                addonTable.ConfigSetup.Minimap(minimapPanel, navButtons[7], configWindow)
            end
            if addonTable.ConfigSetup.Talent then
                addonTable.ConfigSetup.Talent(talentPanel, navButtons[8], configWindow)
            end
            if addonTable.ConfigSetup.Widgets then
                addonTable.ConfigSetup.Widgets(widgetsPanel, navButtons[9], configWindow)
            end
            if addonTable.ConfigSetup.ChatSkin then
                addonTable.ConfigSetup.ChatSkin(chatSkinPanel, navButtons[10], configWindow)
            end
            if addonTable.ConfigSetup.Kick then
                addonTable.ConfigSetup.Kick(kickPanel, navButtons[11], configWindow)
            end
            if addonTable.ConfigSetup.AddonVersions then
                addonTable.ConfigSetup.AddonVersions(addonVersionsPanel, navButtons[12], configWindow)
            end
        end
        ----------------------------------------------------
        -- Register with Blizzard Settings (AddOns list)
        -- Clicking the entry opens the standalone config window
        ----------------------------------------------------
        if Settings and Settings.RegisterCanvasLayoutCategory then
            local settingsFrame = CreateFrame("Frame")
            settingsFrame:SetScript("OnShow", function(self)
                self:Hide()
                HideUIPanel(SettingsPanel)
                addonTable.Config.ToggleWindow()
            end)
            local category = Settings.RegisterCanvasLayoutCategory(settingsFrame, "Luna's UI Tweaks")
            category.ID = addonName
            Settings.RegisterAddOnCategory(category)
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
