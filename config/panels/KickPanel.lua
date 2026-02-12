local addonName, addonTable = ...

-- Create setup table if it doesn't exist
addonTable.ConfigSetup = addonTable.ConfigSetup or {}

-- Get helpers
local Helpers = addonTable.ConfigHelpers

-- Define the setup function for Kick panel
function addonTable.ConfigSetup.Kick(panel, tab, configWindow)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Interrupt Tracker")

    -- Description
    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    description:SetPoint("TOPLEFT", 20, -50)
    description:SetWidth(650)
    description:SetJustifyH("LEFT")
    description:SetText(
    "Track interrupt cooldowns for your party. Shows each member's interrupt ability with a cooldown bar. Syncs via addon messages so all party members with this addon can see each other's interrupts.")

    -- Enable Checkbox
    local enableCheckbox = CreateFrame("CheckButton", "UIThingsKickEnable", panel,
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

    -- Lock/Unlock Button
    local lockBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
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

    -- Features section
    local featuresTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    featuresTitle:SetPoint("TOPLEFT", 20, -165)
    featuresTitle:SetText("Features:")

    local feature1 = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    feature1:SetPoint("TOPLEFT", 40, -190)
    feature1:SetText("• Automatically detects your class interrupt ability")

    local feature2 = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    feature2:SetPoint("TOPLEFT", 40, -210)
    feature2:SetText("• Shows interrupt icon and cooldown progress bar for each party member")

    local feature3 = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    feature3:SetPoint("TOPLEFT", 40, -230)
    feature3:SetText("• Syncs interrupt usage across party members using addon messages")

    local feature4 = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    feature4:SetPoint("TOPLEFT", 40, -250)
    feature4:SetText("• Desaturates icon when on cooldown, shows time remaining")

    -- Supported interrupts section
    local interruptsTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    interruptsTitle:SetPoint("TOPLEFT", 20, -285)
    interruptsTitle:SetText("Supported Interrupts:")

    local yOffset = -310
    local interrupts = {
        { class = "Death Knight", spell = "Mind Freeze",       cd = "15s" },
        { class = "Demon Hunter", spell = "Disrupt",           cd = "15s" },
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

        local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("TOPLEFT", 40 + (col * 300), yOffset - (row * 20))
        text:SetText(string.format("%s: %s (%s)", interrupt.class, interrupt.spell, interrupt.cd))
    end

    -- Usage instructions
    local usageTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    usageTitle:SetPoint("TOPLEFT", 20, -460)
    usageTitle:SetText("Usage:")

    local usage1 = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    usage1:SetPoint("TOPLEFT", 40, -485)
    usage1:SetWidth(650)
    usage1:SetJustifyH("LEFT")
    usage1:SetText("1. Enable the tracker and join a party")

    local usage2 = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    usage2:SetPoint("TOPLEFT", 40, -505)
    usage2:SetWidth(650)
    usage2:SetJustifyH("LEFT")
    usage2:SetText("2. Unlock the tracker to move it to your preferred position")

    local usage3 = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    usage3:SetPoint("TOPLEFT", 40, -525)
    usage3:SetWidth(650)
    usage3:SetJustifyH("LEFT")
    usage3:SetText("3. When you or party members use an interrupt, it will show on cooldown")

    local usage4 = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    usage4:SetPoint("TOPLEFT", 40, -545)
    usage4:SetWidth(650)
    usage4:SetJustifyH("LEFT")
    usage4:SetText("4. Note: Party members must also have this addon installed to sync their interrupts")
end
