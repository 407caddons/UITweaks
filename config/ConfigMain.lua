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
            -- Auto-lock all movable/unlockable elements on config close

            -- Frames (each frame has its own locked flag)
            if UIThingsDB.frames and UIThingsDB.frames.list then
                for _, f in ipairs(UIThingsDB.frames.list) do
                    f.locked = true
                end
                if addonTable.Frames and addonTable.Frames.UpdateFrames then
                    C_Timer.After(0, addonTable.Frames.UpdateFrames)
                end
            end

            -- Loot Anchor
            if addonTable.Loot and addonTable.Loot.LockAnchor then
                addonTable.Loot.LockAnchor()
            end

            -- Widgets
            if UIThingsDB.widgets then
                UIThingsDB.widgets.locked = true
                if addonTable.Widgets and addonTable.Widgets.UpdateVisuals then
                    C_Timer.After(0, addonTable.Widgets.UpdateVisuals)
                end
            end

            -- Tracker
            if UIThingsDB.tracker then
                UIThingsDB.tracker.locked = true
                if addonTable.ObjectiveTracker and addonTable.ObjectiveTracker.UpdateSettings then
                    addonTable.ObjectiveTracker.UpdateSettings()
                end
            end

            -- Combat Timer
            if UIThingsDB.combat then
                UIThingsDB.combat.locked = true
                if UIThingsDB.combat.reminders then
                    UIThingsDB.combat.reminders.locked = true
                end
                if addonTable.Combat and addonTable.Combat.UpdateSettings then
                    addonTable.Combat.UpdateSettings()
                end
            end

            -- Cast Bar
            if UIThingsDB.castBar then
                UIThingsDB.castBar.locked = true
                if addonTable.CastBar and addonTable.CastBar.UpdateSettings then
                    addonTable.CastBar.UpdateSettings()
                end
            end

            -- Kick CDs
            if UIThingsDB.kick then
                UIThingsDB.kick.locked = true
                if addonTable.Kick and addonTable.Kick.UpdateSettings then
                    addonTable.Kick.UpdateSettings()
                end
            end

            -- Damage Meter
            if UIThingsDB.damageMeter then
                UIThingsDB.damageMeter.locked = true
                if addonTable.DamageMeter and addonTable.DamageMeter.SetLocked then
                    addonTable.DamageMeter.SetLocked(true)
                end
            end

            -- M+ Timer
            if UIThingsDB.mplusTimer then
                UIThingsDB.mplusTimer.locked = true
                if addonTable.MplusTimer and addonTable.MplusTimer.UpdateSettings then
                    addonTable.MplusTimer.UpdateSettings()
                end
            end

            -- Coordinates / Waypoints
            if UIThingsDB.coordinates then
                UIThingsDB.coordinates.locked = true
                if addonTable.Coordinates and addonTable.Coordinates.UpdateSettings then
                    addonTable.Coordinates.UpdateSettings()
                end
            end

            -- Warehousing
            if UIThingsDB.warehousing then
                UIThingsDB.warehousing.locked = true
                if addonTable.Warehousing and addonTable.Warehousing.UpdateSettings then
                    addonTable.Warehousing.UpdateSettings()
                end
            end

            -- XP Bar
            if UIThingsDB.xpBar then
                UIThingsDB.xpBar.locked = true
                if addonTable.XpBar and addonTable.XpBar.UpdateSettings then
                    addonTable.XpBar.UpdateSettings()
                end
            end

            -- Minimap (position, zone, clock, drawer)
            if addonTable.MinimapCustom then
                if addonTable.MinimapCustom.SetMinimapLocked then
                    addonTable.MinimapCustom.SetMinimapLocked(true)
                end
                if addonTable.MinimapCustom.SetZoneLocked then
                    addonTable.MinimapCustom.SetZoneLocked(true)
                end
                if addonTable.MinimapCustom.SetClockLocked then
                    addonTable.MinimapCustom.SetClockLocked(true)
                end
                if addonTable.MinimapCustom.SetCoordsLocked then
                    addonTable.MinimapCustom.SetCoordsLocked(true)
                end
                if addonTable.MinimapCustom.SetDrawerLocked then
                    addonTable.MinimapCustom.SetDrawerLocked(true)
                end
            end

            -- Close M+ Timer demo if running
            if addonTable.MplusTimer and addonTable.MplusTimer.CloseDemo then
                addonTable.MplusTimer.CloseDemo()
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
            { id = 1,  name = "Tracker",          key = "tracker",       icon = "Interface\\Icons\\Inv_Misc_Book_09" },
            { id = 2,  name = "Quest Reminders",  key = "questReminder", icon = "Interface\\Icons\\Inv_Misc_Book_08" },
            { id = 3,  name = "Quest Auto",       key = "questAuto",     icon = "Interface\\Icons\\Inv_Misc_Book_08" },
            { id = 4,  name = "XP Bar",           key = "xpBar",         icon = "Interface\\Icons\\XP_Icon" },
            { id = 5,  name = "Combat",           key = "combat",        icon = "Interface\\Icons\\Ability_Warrior_OffensiveStance" },
            { id = 6,  name = "Cast Bar",         key = "castBar",       icon = "Interface\\Icons\\Spell_Holy_MagicalSentry" },
            { id = 7,  name = "Kick CDs",         key = "kick",          icon = "Interface\\Icons\\Ability_Kick" },
            { id = 8,  name = "M+ Timer",         key = "mplusTimer",    icon = "Interface\\Icons\\Inv_Relics_Hourglass" },
            { id = 9,  name = "Minimap",          key = "minimap",       icon = "Interface\\Icons\\Inv_Misc_Map02" },
            { id = 10, name = "Coordinates",      key = "coordinates",   icon = "Interface\\Icons\\Inv_Misc_Map_01" },
            { id = 11, name = "Frames",           key = "frames",        icon = "Interface\\Icons\\Inv_Box_01" },
            { id = 12, name = "Damage Meter",     key = "damageMeter",   icon = "Interface\\Icons\\Ability_Warrior_BattleShout" },
            { id = 13, name = "Vendor",           key = "vendor",        icon = "Interface\\Icons\\Inv_Misc_Coin_02" },
            { id = 14, name = "Loot",             key = "loot",          icon = "Interface\\Icons\\Inv_Box_02" },
            { id = 15, name = "Notifications",    key = "notifications", icon = "Interface\\Icons\\Inv_Misc_Bell_01" },
            { id = 16, name = "Reagents",         key = "reagents",      icon = "Interface\\Icons\\Inv_Misc_Herb_01" },
            { id = 17, name = "Talent Builds",    key = "talentManager", icon = "Interface\\Icons\\Ability_Marksmanship" },
            { id = 18, name = "Talent Reminders", key = "talent",        icon = "Interface\\Icons\\Ability_Marksmanship" },
            { id = 19, name = "General UI",       key = "misc",          icon = "Interface\\Icons\\Inv_Misc_Gear_01" },
            { id = 20, name = "Widgets",          key = "widgets",       icon = "Interface\\Icons\\Inv_Misc_PocketWatch_01" },
            { id = 21, name = "Warehousing",      key = "warehousing",   icon = "Interface\\Icons\\Inv_Misc_Package" },
            { id = 22, name = "Queue Timer",      key = "queueTimer",    icon = "Interface\\Icons\\Inv_Relics_Hourglass" },
            { id = 23, name = "Addon Versions",   key = "addonVersions", icon = "Interface\\Icons\\Inv_Misc_GroupNeedMore" },
        }

        -- Insert companion addon panels before AddonVersions (always last)
        local companionPanels = LunaUITweaksAPI and LunaUITweaksAPI._pendingPanels or {}
        if #companionPanels > 0 then
            local lastMod = table.remove(modules)
            for _, entry in ipairs(companionPanels) do
                table.insert(modules, {
                    id   = #modules + 1,
                    name = entry.name,
                    key  = entry.key,
                    icon = entry.icon,
                })
            end
            lastMod.id = #modules + 1
            table.insert(modules, lastMod)
        end

        -- Expand scroll child to fit all nav buttons (30px each)
        navScrollChild:SetHeight(math.max(500, #modules * 30 + 10))

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

        local damageMeterPanel = CreateFrame("Frame", nil, contentContainer)
        damageMeterPanel:SetAllPoints()
        damageMeterPanel:Hide()

        local addonVersionsPanel = CreateFrame("Frame", nil, contentContainer)
        addonVersionsPanel:SetAllPoints()
        addonVersionsPanel:Hide()

        local notificationsPanel = CreateFrame("Frame", nil, contentContainer)
        notificationsPanel:SetAllPoints()
        notificationsPanel:Hide()

        local castBarPanel = CreateFrame("Frame", nil, contentContainer)
        castBarPanel:SetAllPoints()
        castBarPanel:Hide()

        local reagentsPanel = CreateFrame("Frame", nil, contentContainer)
        reagentsPanel:SetAllPoints()
        reagentsPanel:Hide()

        local questAutoPanel = CreateFrame("Frame", nil, contentContainer)
        questAutoPanel:SetAllPoints()
        questAutoPanel:Hide()

        local questReminderPanel = CreateFrame("Frame", nil, contentContainer)
        questReminderPanel:SetAllPoints()
        questReminderPanel:Hide()

        local mplusTimerPanel = CreateFrame("Frame", nil, contentContainer)
        mplusTimerPanel:SetAllPoints()
        mplusTimerPanel:Hide()

        local talentManagerPanel = CreateFrame("Frame", nil, contentContainer)
        talentManagerPanel:SetAllPoints()
        talentManagerPanel:Hide()

        local coordinatesPanel = CreateFrame("Frame", nil, contentContainer)
        coordinatesPanel:SetAllPoints()
        coordinatesPanel:Hide()

        local warehousingPanel = CreateFrame("Frame", nil, contentContainer)
        warehousingPanel:SetAllPoints()
        warehousingPanel:Hide()

        local xpBarPanel = CreateFrame("Frame", nil, contentContainer)
        xpBarPanel:SetAllPoints()
        xpBarPanel:Hide()

        local queueTimerPanel = CreateFrame("Frame", nil, contentContainer)
        queueTimerPanel:SetAllPoints()
        queueTimerPanel:Hide()

        -- Store panels
        addonTable.ConfigPanels.tracker       = trackerPanel
        addonTable.ConfigPanels.vendor        = vendorPanel
        addonTable.ConfigPanels.combat        = combatPanel
        addonTable.ConfigPanels.frames        = framesPanel
        addonTable.ConfigPanels.loot          = lootPanel
        addonTable.ConfigPanels.misc          = miscPanel
        addonTable.ConfigPanels.minimap       = minimapPanel
        addonTable.ConfigPanels.talent        = talentPanel
        addonTable.ConfigPanels.widgets       = widgetsPanel
        addonTable.ConfigPanels.kick          = kickPanel
        addonTable.ConfigPanels.damageMeter   = damageMeterPanel
        addonTable.ConfigPanels.addonVersions = addonVersionsPanel
        addonTable.ConfigPanels.notifications = notificationsPanel
        addonTable.ConfigPanels.castBar       = castBarPanel
        addonTable.ConfigPanels.reagents      = reagentsPanel
        addonTable.ConfigPanels.questAuto     = questAutoPanel
        addonTable.ConfigPanels.questReminder = questReminderPanel
        addonTable.ConfigPanels.mplusTimer    = mplusTimerPanel
        addonTable.ConfigPanels.talentManager = talentManagerPanel
        addonTable.ConfigPanels.coordinates   = coordinatesPanel
        addonTable.ConfigPanels.warehousing   = warehousingPanel
        addonTable.ConfigPanels.xpBar         = xpBarPanel
        addonTable.ConfigPanels.queueTimer    = queueTimerPanel

        -- Map IDs to Panels
        local idToPanel                       = {
            [1]  = trackerPanel,
            [2]  = questReminderPanel,
            [3]  = questAutoPanel,
            [4]  = xpBarPanel,
            [5]  = combatPanel,
            [6]  = castBarPanel,
            [7]  = kickPanel,
            [8]  = mplusTimerPanel,
            [9]  = minimapPanel,
            [10] = coordinatesPanel,
            [11] = framesPanel,
            [12] = damageMeterPanel,
            [13] = vendorPanel,
            [14] = lootPanel,
            [15] = notificationsPanel,
            [16] = reagentsPanel,
            [17] = talentManagerPanel,
            [18] = talentPanel,
            [19] = miscPanel,
            [20] = widgetsPanel,
            [21] = warehousingPanel,
            [22] = queueTimerPanel,
            [23] = addonVersionsPanel,
        }

        -- Create companion panels and shift AddonVersions to its new slot
        if #companionPanels > 0 then
            local numCompanions = #companionPanels
            idToPanel[23 + numCompanions] = idToPanel[23]
            idToPanel[23] = nil
            for i, entry in ipairs(companionPanels) do
                local panel = CreateFrame("Frame", nil, contentContainer)
                panel:SetAllPoints()
                panel:Hide()
                idToPanel[22 + i] = panel
                addonTable.ConfigPanels[entry.key] = panel
                entry._panelFrame = panel
            end
        end

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
            if id == 2 and addonTable.Config.RefreshQuestReminderList then
                addonTable.Config.RefreshQuestReminderList()
            end
            if id == 18 and addonTable.Config.RefreshTalentReminderList then
                addonTable.Config.RefreshTalentReminderList()
            end
            if id == 16 and addonTable.Config.RefreshReagentsList then
                addonTable.Config.RefreshReagentsList()
            end
            if id == 21 and addonTable.Config.RefreshWarehousingList then
                addonTable.Config.RefreshWarehousingList()
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
            if addonTable.ConfigSetup.QuestReminder then
                addonTable.ConfigSetup.QuestReminder(questReminderPanel, navButtons[2], configWindow)
            end
            if addonTable.ConfigSetup.QuestAuto then
                addonTable.ConfigSetup.QuestAuto(questAutoPanel, navButtons[3], configWindow)
            end
            if addonTable.ConfigSetup.XpBar then
                addonTable.ConfigSetup.XpBar(xpBarPanel, navButtons[4], configWindow)
            end
            if addonTable.ConfigSetup.Combat then
                addonTable.ConfigSetup.Combat(combatPanel, navButtons[5], configWindow)
            end
            if addonTable.ConfigSetup.CastBar then
                addonTable.ConfigSetup.CastBar(castBarPanel, navButtons[6], configWindow)
            end
            if addonTable.ConfigSetup.Kick then
                addonTable.ConfigSetup.Kick(kickPanel, navButtons[7], configWindow)
            end
            if addonTable.ConfigSetup.MplusTimer then
                addonTable.ConfigSetup.MplusTimer(mplusTimerPanel, navButtons[8], configWindow)
            end
            if addonTable.ConfigSetup.Minimap then
                addonTable.ConfigSetup.Minimap(minimapPanel, navButtons[9], configWindow)
            end
            if addonTable.ConfigSetup.Coordinates then
                addonTable.ConfigSetup.Coordinates(coordinatesPanel, navButtons[10], configWindow)
            end
            if addonTable.ConfigSetup.Frames then
                addonTable.ConfigSetup.Frames(framesPanel, navButtons[11], configWindow)
            end
            if addonTable.ConfigSetup.DamageMeter then
                addonTable.ConfigSetup.DamageMeter(damageMeterPanel, navButtons[12], configWindow)
            end
            if addonTable.ConfigSetup.Vendor then
                addonTable.ConfigSetup.Vendor(vendorPanel, navButtons[13], configWindow)
            end
            if addonTable.ConfigSetup.Loot then
                addonTable.ConfigSetup.Loot(lootPanel, navButtons[14], configWindow)
            end
            if addonTable.ConfigSetup.Notifications then
                addonTable.ConfigSetup.Notifications(notificationsPanel, navButtons[15], configWindow)
            end
            if addonTable.ConfigSetup.Reagents then
                addonTable.ConfigSetup.Reagents(reagentsPanel, navButtons[16], configWindow)
            end
            if addonTable.ConfigSetup.TalentManager then
                addonTable.ConfigSetup.TalentManager(talentManagerPanel, navButtons[17], configWindow)
            end
            if addonTable.ConfigSetup.Talent then
                addonTable.ConfigSetup.Talent(talentPanel, navButtons[18], configWindow)
            end
            if addonTable.ConfigSetup.Misc then
                addonTable.ConfigSetup.Misc(miscPanel, navButtons[19], configWindow)
            end
            if addonTable.ConfigSetup.Widgets then
                addonTable.ConfigSetup.Widgets(widgetsPanel, navButtons[20], configWindow)
            end
            if addonTable.ConfigSetup.Warehousing then
                addonTable.ConfigSetup.Warehousing(warehousingPanel, navButtons[21], configWindow)
            end
            if addonTable.ConfigSetup.QueueTimer then
                addonTable.ConfigSetup.QueueTimer(queueTimerPanel, navButtons[22], configWindow)
            end
            if addonTable.ConfigSetup.AddonVersions then
                local avIdx = 23 + #companionPanels
                addonTable.ConfigSetup.AddonVersions(addonVersionsPanel, navButtons[avIdx], configWindow)
            end
        end

        -- Call companion addon panel setup functions
        for i, entry in ipairs(companionPanels) do
            if entry._panelFrame and entry.setup then
                entry.setup(entry._panelFrame, navButtons[22 + i], configWindow)
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
