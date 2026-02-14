local addonName, addonTable = ...

-- Create setup table if it doesn't exist
addonTable.ConfigSetup = addonTable.ConfigSetup or {}

-- Get helpers
local Helpers = addonTable.ConfigHelpers

-- Define the setup function for Kick panel
function addonTable.ConfigSetup.Kick(panel, tab, configWindow)
    -- Create ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "UIThingsKickScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 0)

    local child = CreateFrame("Frame", nil, scrollFrame)
    child:SetSize(650, 750)
    scrollFrame:SetScrollChild(child)

    scrollFrame:SetScript("OnShow", function()
        child:SetWidth(scrollFrame:GetWidth())
    end)

    local title = child:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Interrupt Tracker")

    -- Description
    local description = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    description:SetPoint("TOPLEFT", 20, -50)
    description:SetWidth(620)
    description:SetJustifyH("LEFT")
    description:SetText(
        "Track interrupt cooldowns for your party. Shows each member's interrupt ability with a cooldown bar or icon. Syncs via addon messages so all party members with this addon can see each other's interrupts. Enable 'Attach to Party Frames' to show icons on Blizzard party frames instead of a separate window.")

    -- Enable Checkbox
    local enableCheckbox = CreateFrame("CheckButton", "UIThingsKickEnable", child,
        "ChatConfigCheckButtonTemplate")
    enableCheckbox:SetPoint("TOPLEFT", 20, -95)
    _G[enableCheckbox:GetName() .. "Text"]:SetText("Enable Interrupt Tracker")
    enableCheckbox:SetChecked(UIThingsDB.kick.enabled)
    enableCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.kick.enabled = self:GetChecked()
        Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.kick.enabled)
        if addonTable.Kick and addonTable.Kick.UpdateSettings then
            addonTable.Kick.UpdateSettings()
        end
    end)
    Helpers.UpdateModuleVisuals(panel, tab, UIThingsDB.kick.enabled)

    -- Attach to Party Frames Checkbox
    local attachCheckbox = CreateFrame("CheckButton", "UIThingsKickAttach", child,
        "ChatConfigCheckButtonTemplate")
    attachCheckbox:SetPoint("TOPLEFT", 260, -95)
    _G[attachCheckbox:GetName() .. "Text"]:SetText("Attach to Party Frames")
    attachCheckbox:SetChecked(UIThingsDB.kick.attachToPartyFrames)
    attachCheckbox:SetScript("OnClick", function(self)
        UIThingsDB.kick.attachToPartyFrames = self:GetChecked()
        if addonTable.Kick and addonTable.Kick.UpdateSettings then
            addonTable.Kick.UpdateSettings()
        end
    end)

    -- Anchor Point Dropdown
    local anchorLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    anchorLabel:SetPoint("TOPLEFT", 260, -125)
    anchorLabel:SetText("Icon Anchor Point:")

    local anchorDropdown = CreateFrame("Frame", "UIThingsKickAnchorDropdown", child, "UIDropDownMenuTemplate")
    anchorDropdown:SetPoint("LEFT", anchorLabel, "RIGHT", -15, -3)

    local anchorOptions = {
        { text = "Bottom", value = "BOTTOM" },
        { text = "Top",    value = "TOP" },
        { text = "Left",   value = "LEFT" },
        { text = "Right",  value = "RIGHT" }
    }

    UIDropDownMenu_SetWidth(anchorDropdown, 100)
    UIDropDownMenu_Initialize(anchorDropdown, function(self, level)
        for _, option in ipairs(anchorOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function()
                UIThingsDB.kick.attachAnchorPoint = option.value
                UIDropDownMenu_SetText(anchorDropdown, option.text)
                if addonTable.Kick and addonTable.Kick.UpdateSettings then
                    addonTable.Kick.UpdateSettings()
                end
            end
            info.checked = (UIThingsDB.kick.attachAnchorPoint == option.value)
            UIDropDownMenu_AddButton(info)
        end
    end)

    -- Set initial dropdown text
    for _, option in ipairs(anchorOptions) do
        if UIThingsDB.kick.attachAnchorPoint == option.value then
            UIDropDownMenu_SetText(anchorDropdown, option.text)
            break
        end
    end

    -- Lock/Unlock Button
    local lockBtn = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    lockBtn:SetSize(120, 24)
    lockBtn:SetPoint("TOPLEFT", 20, -125)
    lockBtn:SetScript("OnShow", function(self)
        if UIThingsDB.kick.locked then
            self:SetText("Unlock Tracker")
        else
            self:SetText("Lock Tracker")
        end
    end)
    lockBtn:SetScript("OnClick", function(self)
        UIThingsDB.kick.locked = not UIThingsDB.kick.locked
        if UIThingsDB.kick.locked then
            self:SetText("Unlock Tracker")
        else
            self:SetText("Lock Tracker")
        end
        if addonTable.Kick and addonTable.Kick.UpdateSettings then
            addonTable.Kick.UpdateSettings()
        end
    end)

    -- Appearance section
    Helpers.CreateSectionHeader(child, "Appearance", -155)

    local function updateKick()
        if addonTable.Kick and addonTable.Kick.UpdateSettings then
            addonTable.Kick.UpdateSettings()
        end
    end

    Helpers.CreateColorSwatch(child, "Background Color", UIThingsDB.kick.bgColor, updateKick, 20, -180)
    Helpers.CreateColorSwatch(child, "Border Color", UIThingsDB.kick.borderColor, updateKick, 220, -180)
    Helpers.CreateColorSwatch(child, "Bar Background", UIThingsDB.kick.barBgColor, updateKick, 20, -210)
    Helpers.CreateColorSwatch(child, "Bar Border", UIThingsDB.kick.barBorderColor, updateKick, 220, -210)

    -- Features section
    local featuresTitle = child:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    featuresTitle:SetPoint("TOPLEFT", 20, -250)
    featuresTitle:SetText("Features:")

    local feature1 = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    feature1:SetPoint("TOPLEFT", 40, -275)
    feature1:SetText("• Automatically detects your class interrupt ability")

    local feature2 = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    feature2:SetPoint("TOPLEFT", 40, -295)
    feature2:SetText("• Shows interrupt icon and cooldown progress bar for each party member")

    local feature3 = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    feature3:SetPoint("TOPLEFT", 40, -315)
    feature3:SetText("• Syncs interrupt usage across party members using addon messages")

    local feature4 = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    feature4:SetPoint("TOPLEFT", 40, -335)
    feature4:SetText("• Desaturates icon when on cooldown, shows time remaining")

    local feature5 = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    feature5:SetPoint("TOPLEFT", 40, -355)
    feature5:SetText("• Syncs actual cooldown durations (talent-modified) between party members")

    local feature6 = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    feature6:SetPoint("TOPLEFT", 40, -375)
    feature6:SetText("• Vengeance Demon Hunters show both Disrupt and Sigil of Silence")

    -- Supported interrupts section
    local interruptsTitle = child:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    interruptsTitle:SetPoint("TOPLEFT", 20, -410)
    interruptsTitle:SetText("Supported Interrupts:")

    local yOffset = -435
    local interrupts = {
        { class = "Death Knight", spell = "Mind Freeze",       cd = "15s" },
        { class = "Demon Hunter", spell = "Disrupt",           cd = "15s" },
        { class = "Demon Hunter", spell = "Sigil of Silence",  cd = "90s (Vengeance)" },
        { class = "Druid",        spell = "Skull Bash",        cd = "15s" },
        { class = "Evoker",       spell = "Quell",             cd = "40s" },
        { class = "Hunter",       spell = "Counter Shot",      cd = "24s" },
        { class = "Mage",         spell = "Counterspell",      cd = "24s" },
        { class = "Monk",         spell = "Spear Hand Strike", cd = "15s" },
        { class = "Paladin",      spell = "Rebuke",            cd = "15s" },
        { class = "Priest",       spell = "Silence",           cd = "45s" },
        { class = "Rogue",        spell = "Kick",              cd = "15s" },
        { class = "Shaman",       spell = "Wind Shear",        cd = "12s" },
        { class = "Warlock",      spell = "Spell Lock",        cd = "24s" },
        { class = "Warrior",      spell = "Pummel",            cd = "15s" },
    }

    for i, interrupt in ipairs(interrupts) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)

        local text = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("TOPLEFT", 40 + (col * 300), yOffset - (row * 20))
        text:SetText(string.format("%s: %s (%s)", interrupt.class, interrupt.spell, interrupt.cd))
    end

    -- Usage instructions
    local usageTitle = child:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    usageTitle:SetPoint("TOPLEFT", 20, -605)
    usageTitle:SetText("Usage:")

    local usage1 = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    usage1:SetPoint("TOPLEFT", 40, -630)
    usage1:SetWidth(620)
    usage1:SetJustifyH("LEFT")
    usage1:SetText("1. Enable the tracker and join a party")

    local usage2 = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    usage2:SetPoint("TOPLEFT", 40, -650)
    usage2:SetWidth(620)
    usage2:SetJustifyH("LEFT")
    usage2:SetText("2. Unlock the tracker to move it to your preferred position")

    local usage3 = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    usage3:SetPoint("TOPLEFT", 40, -670)
    usage3:SetWidth(620)
    usage3:SetJustifyH("LEFT")
    usage3:SetText("3. When you or party members use an interrupt, it will show on cooldown")

    local usage4 = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    usage4:SetPoint("TOPLEFT", 40, -690)
    usage4:SetWidth(620)
    usage4:SetJustifyH("LEFT")
    usage4:SetText("4. Actual cooldown durations are synced, accounting for talent reductions")
end
