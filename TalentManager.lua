local addonName, addonTable = ...
addonTable.TalentManager = {}

local TalentManager = addonTable.TalentManager
local Log = addonTable.Core.Log
local LogLevel = addonTable.Core.LogLevel

local Helpers = addonTable.ConfigHelpers

local mainPanel      -- The side panel anchored to PlayerSpellsFrame
local scrollContent  -- Scroll child for build list
local buildRows = {} -- Reusable row frames
local hooked = false -- Whether we've hooked PlayerSpellsFrame

-- Shared difficulty references
local RAID_DIFFICULTIES = Helpers.RAID_DIFFICULTIES
local DUNGEON_DIFFICULTIES = Helpers.DUNGEON_DIFFICULTIES
local RAID_DIFF_ORDER = Helpers.RAID_DIFF_ORDER
local DUNGEON_DIFF_ORDER = Helpers.DUNGEON_DIFF_ORDER
local IsRaidDifficulty = Helpers.IsRaidDifficulty
local IsDungeonDifficulty = Helpers.IsDungeonDifficulty

-- ============================================================
-- Encounter Journal Instance Cache
-- ============================================================

local ejCache = nil -- in-memory reference

local function EnsureEJCache()
    if ejCache and ejCache.tiers then return ejCache end

    local settings = UIThingsDB.talentManager
    local addonVersion = C_AddOns.GetAddOnMetadata(addonName, "Version") or "unknown"
    local _, gameBuild = GetBuildInfo()

    -- Check if saved cache is still valid
    if settings.ejCache
        and settings.ejCache.addonVersion == addonVersion
        and settings.ejCache.gameBuild == gameBuild
        and settings.ejCache.tiers then
        ejCache = settings.ejCache
        Log("TalentManager", "Using cached EJ instance data", LogLevel.DEBUG)
        return ejCache
    end

    -- Rebuild cache from EJ API
    if not EJ_GetNumTiers then
        Log("TalentManager", "EJ API not available", LogLevel.WARN)
        return nil
    end

    Log("TalentManager", "Building EJ instance cache...", LogLevel.DEBUG)

    -- Save current tier to restore later
    local savedTier = EJ_GetCurrentTier and EJ_GetCurrentTier()

    local numTiers = EJ_GetNumTiers()
    local tiers = {}

    for tierIdx = 1, numTiers do
        EJ_SelectTier(tierIdx)
        local tierName = EJ_GetTierInfo(tierIdx)

        local dungeons = {}
        local idx = 1
        while true do
            local journalInstID, instName, _, _, _, _, _, _, _, _, instID = EJ_GetInstanceByIndex(idx, false)
            if not journalInstID then break end
            dungeons[#dungeons + 1] = { id = instID, name = instName }
            idx = idx + 1
        end

        local raids = {}
        idx = 1
        while true do
            local journalInstID, instName, _, _, _, _, _, _, _, _, instID = EJ_GetInstanceByIndex(idx, true)
            if not journalInstID then break end
            raids[#raids + 1] = { id = instID, name = instName }
            idx = idx + 1
        end

        table.sort(dungeons, function(a, b) return a.name < b.name end)
        table.sort(raids, function(a, b) return a.name < b.name end)

        tiers[tierIdx] = {
            name = tierName,
            dungeons = dungeons,
            raids = raids,
        }
    end

    -- Restore original tier
    if savedTier then
        EJ_SelectTier(savedTier)
    end

    ejCache = {
        addonVersion = addonVersion,
        gameBuild = gameBuild,
        tiers = tiers,
    }
    settings.ejCache = ejCache

    Log("TalentManager", string.format("Cached %d EJ tiers", numTiers), LogLevel.DEBUG)
    return ejCache
end

-- Lookup an instance name from the EJ cache by ID
local function FindInstanceInCache(instanceID, contentType)
    if not ejCache or not ejCache.tiers then return nil end
    local numID = tonumber(instanceID)
    for _, tier in pairs(ejCache.tiers) do
        local list = (contentType == "raid") and tier.raids or tier.dungeons
        if list then
            for _, inst in ipairs(list) do
                if inst.id == numID then return inst.name end
            end
        end
    end
    -- Search both if not found in the specified type
    for _, tier in pairs(ejCache.tiers) do
        local otherList = (contentType == "raid") and tier.dungeons or tier.raids
        if otherList then
            for _, inst in ipairs(otherList) do
                if inst.id == numID then return inst.name end
            end
        end
    end
    return nil
end
TalentManager.FindInstanceInCache = FindInstanceInCache

-- ============================================================
-- Panel Creation
-- ============================================================

local function CreateMainPanel()
    if mainPanel then return end

    local settings = UIThingsDB.talentManager
    local panelWidth = settings.panelWidth or 280

    mainPanel = CreateFrame("Frame", "LunaTalentManagerPanel", UIParent, "BackdropTemplate")
    mainPanel:SetSize(panelWidth, 600)
    mainPanel:SetFrameStrata("HIGH")
    mainPanel:SetClampedToScreen(true)
    mainPanel:Hide()

    TalentManager.ApplyVisuals()

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, mainPanel)
    titleBar:SetHeight(28)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", 10, 0)
    titleText:SetText("Talent Builds")
    titleText:SetTextColor(1, 0.82, 0)

    -- Toolbar (Import / Export / Add)
    local toolbar = CreateFrame("Frame", nil, mainPanel)
    toolbar:SetHeight(30)
    toolbar:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -2)
    toolbar:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, -2)

    local btnWidth = (panelWidth - 20) / 3

    local importBtn = CreateFrame("Button", nil, toolbar, "UIPanelButtonTemplate")
    importBtn:SetSize(btnWidth, 22)
    importBtn:SetPoint("TOPLEFT", 5, -4)
    importBtn:SetText("Import")
    importBtn:SetNormalFontObject("GameFontNormalSmall")
    importBtn:SetScript("OnClick", function() TalentManager.ShowImportDialog() end)

    local exportBtn = CreateFrame("Button", nil, toolbar, "UIPanelButtonTemplate")
    exportBtn:SetSize(btnWidth, 22)
    exportBtn:SetPoint("LEFT", importBtn, "RIGHT", 2, 0)
    exportBtn:SetText("Export")
    exportBtn:SetNormalFontObject("GameFontNormalSmall")
    exportBtn:SetScript("OnClick", function() TalentManager.ShowExportDialog() end)

    local addBtn = CreateFrame("Button", nil, toolbar, "UIPanelButtonTemplate")
    addBtn:SetSize(btnWidth, 22)
    addBtn:SetPoint("LEFT", exportBtn, "RIGHT", 2, 0)
    addBtn:SetText("Add")
    addBtn:SetNormalFontObject("GameFontNormalSmall")
    addBtn:SetScript("OnClick", function() TalentManager.ShowAddDialog() end)

    -- Scroll frame for build list
    local scrollFrame = CreateFrame("ScrollFrame", "LunaTalentManagerScroll", mainPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 5, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", mainPanel, "BOTTOMRIGHT", -28, 8)

    scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetWidth(panelWidth - 40)
    scrollContent:SetHeight(1)
    scrollFrame:SetScrollChild(scrollContent)

    mainPanel.scrollFrame = scrollFrame
    mainPanel.scrollContent = scrollContent
end

-- ============================================================
-- Visual Styling
-- ============================================================

function TalentManager.ApplyVisuals()
    if not mainPanel then return end
    local settings = UIThingsDB.talentManager
    Helpers.ApplyFrameBackdrop(mainPanel, settings.showBorder, settings.borderColor,
        settings.showBackground, settings.backgroundColor)
end

-- ============================================================
-- Anchor to PlayerSpellsFrame
-- ============================================================

local function AnchorToTalentFrame()
    if not mainPanel or not PlayerSpellsFrame then return end
    mainPanel:ClearAllPoints()
    mainPanel:SetPoint("TOPLEFT", PlayerSpellsFrame, "TOPRIGHT", 2, 0)
    mainPanel:SetPoint("BOTTOMLEFT", PlayerSpellsFrame, "BOTTOMRIGHT", 2, 0)

    local settings = UIThingsDB.talentManager
    mainPanel:SetWidth(settings.panelWidth or 280)
end

local function OnTalentFrameShow()
    if not UIThingsDB.talentManager or not UIThingsDB.talentManager.enabled then return end
    if not mainPanel then
        CreateMainPanel()
    end
    AnchorToTalentFrame()
    TalentManager.RefreshBuildList()
    mainPanel:Show()
end

local function OnTalentFrameHide()
    if mainPanel and mainPanel:IsShown() then
        mainPanel:Hide()
    end
end

local function HookTalentFrame()
    if hooked then return end
    if not PlayerSpellsFrame then return end

    PlayerSpellsFrame:HookScript("OnShow", OnTalentFrameShow)
    PlayerSpellsFrame:HookScript("OnHide", OnTalentFrameHide)
    hooked = true

    Log("TalentManager", "Hooked PlayerSpellsFrame", LogLevel.DEBUG)

    -- If talent frame is already shown when we hook, show our panel
    if PlayerSpellsFrame:IsShown() then
        OnTalentFrameShow()
    end
end

-- ============================================================
-- Build List Rendering
-- ============================================================

local function GetOrCreateRow(index)
    if buildRows[index] then return buildRows[index] end

    local contentWidth = scrollContent:GetWidth()
    local row = CreateFrame("Frame", nil, scrollContent)
    row:SetSize(contentWidth, 24)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.text:SetPoint("LEFT", 0, 0)
    row.text:SetWidth(contentWidth - 110)
    row.text:SetJustifyH("LEFT")

    -- Helper to add tooltip to a button
    local function AddButtonTooltip(btn, text)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(text, 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- Edit button
    row.editBtn = CreateFrame("Button", nil, row)
    row.editBtn:SetSize(16, 16)
    row.editBtn:SetPoint("RIGHT", row, "RIGHT", -80, 0)
    row.editBtn:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    row.editBtn:SetHighlightTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    row.editBtn:GetHighlightTexture():SetAlpha(0.5)
    row.editBtn:Hide()
    AddButtonTooltip(row.editBtn, "Edit")

    -- Copy button
    row.copyBtn = CreateFrame("Button", nil, row)
    row.copyBtn:SetSize(16, 16)
    row.copyBtn:SetPoint("RIGHT", row, "RIGHT", -60, 0)
    row.copyBtn:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Disabled")
    row.copyBtn:SetHighlightTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Disabled")
    row.copyBtn:GetHighlightTexture():SetAlpha(0.5)
    row.copyBtn:Hide()
    AddButtonTooltip(row.copyBtn, "Copy")

    -- Update button (sync current talents to this saved build)
    row.updateBtn = CreateFrame("Button", nil, row)
    row.updateBtn:SetSize(16, 16)
    row.updateBtn:SetPoint("RIGHT", row, "RIGHT", -40, 0)
    row.updateBtn:SetNormalTexture("Interface\\Buttons\\UI-RefreshButton")
    row.updateBtn:SetHighlightTexture("Interface\\Buttons\\UI-RefreshButton")
    row.updateBtn:GetHighlightTexture():SetAlpha(0.5)
    row.updateBtn:Hide()
    AddButtonTooltip(row.updateBtn, "Update with current talents")

    -- Delete button
    row.deleteBtn = CreateFrame("Button", nil, row)
    row.deleteBtn:SetSize(16, 16)
    row.deleteBtn:SetPoint("RIGHT", row, "RIGHT", -20, 0)
    row.deleteBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    row.deleteBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
    row.deleteBtn:GetHighlightTexture():SetAlpha(0.5)
    row.deleteBtn:Hide()
    AddButtonTooltip(row.deleteBtn, "Delete")

    -- Load button
    row.loadBtn = CreateFrame("Button", nil, row)
    row.loadBtn:SetSize(16, 16)
    row.loadBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.loadBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    row.loadBtn:SetHighlightTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    row.loadBtn:GetHighlightTexture():SetAlpha(0.5)
    row.loadBtn:Hide()
    AddButtonTooltip(row.loadBtn, "Load build")

    -- Match tick icon
    row.tickIcon = row:CreateTexture(nil, "OVERLAY")
    row.tickIcon:SetSize(14, 14)
    row.tickIcon:SetPoint("LEFT", 0, 0)
    row.tickIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    row.tickIcon:Hide()

    -- Background highlight
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0, 0, 0, 0)

    buildRows[index] = row
    return row
end

local function SetRowAsHeader(row, text, indent, isCollapsed, onClick)
    local settings = UIThingsDB.talentManager
    local font = settings.font or "Fonts\\FRIZQT__.TTF"
    local fontSize = (settings.fontSize or 11) + 1

    row.text:SetFont(font, fontSize, "OUTLINE")
    local arrow = isCollapsed and "|cFFAAAAAA+ |r" or "|cFFAAAAAA- |r"
    row.text:SetText(string.rep("  ", indent) .. arrow .. text)
    row.text:SetTextColor(1, 0.82, 0)
    row.text:SetPoint("LEFT", indent * 8, 0)
    row.editBtn:Hide()
    row.copyBtn:Hide()
    row.updateBtn:Hide()
    row.deleteBtn:Hide()
    row.loadBtn:Hide()
    row.tickIcon:Hide()
    row.bg:SetColorTexture(0.15, 0.15, 0.15, 0.3)
    row:SetHeight(24)

    row:EnableMouse(true)
    row:SetScript("OnMouseDown", onClick)
    row:SetScript("OnEnter", nil)
    row:SetScript("OnLeave", nil)
end

local function SetRowAsBuild(row, reminder, instanceID, diffID, zoneKey, buildIndex, indent, isMatch)
    local settings = UIThingsDB.talentManager
    local font = settings.font or "Fonts\\FRIZQT__.TTF"
    local fontSize = settings.fontSize or 11

    -- Show/hide tick based on match
    local textIndent = indent * 8
    if isMatch then
        row.tickIcon:ClearAllPoints()
        row.tickIcon:SetPoint("LEFT", textIndent, 0)
        row.tickIcon:Show()
        textIndent = textIndent + 16
    else
        row.tickIcon:Hide()
    end

    row.text:SetFont(font, fontSize, "")
    row.text:SetText((reminder.name or "Unnamed Build"))
    if isMatch then
        row.text:SetTextColor(0.4, 1, 0.4)
    else
        row.text:SetTextColor(0.9, 0.9, 0.9)
    end
    row.text:SetPoint("LEFT", textIndent, 0)
    row.bg:SetColorTexture(0, 0, 0, 0)
    row:SetHeight(24)
    row:EnableMouse(false)
    row:SetScript("OnMouseDown", nil)

    -- Show action buttons
    row.editBtn:Show()
    row.editBtn:SetScript("OnClick", function()
        TalentManager.ShowEditDialog(instanceID, diffID, zoneKey, buildIndex, reminder)
    end)

    row.copyBtn:Show()
    row.copyBtn:SetScript("OnClick", function()
        TalentManager.CopyBuild(instanceID, diffID, zoneKey, buildIndex, reminder)
    end)

    row.updateBtn:Show()
    row.updateBtn:SetScript("OnClick", function()
        StaticPopup_Show("LUNA_TALENTMGR_UPDATE_CONFIRM", reminder.name or "this build", nil, {
            instanceID = instanceID,
            diffID = diffID,
            zoneKey = zoneKey,
            buildIndex = buildIndex,
            reminder = reminder,
        })
    end)

    row.deleteBtn:Show()
    row.deleteBtn:SetScript("OnClick", function()
        StaticPopup_Show("LUNA_TALENTMGR_DELETE_CONFIRM", reminder.name or "this build", nil, {
            instanceID = instanceID,
            diffID = diffID,
            zoneKey = zoneKey,
            buildIndex = buildIndex,
        })
    end)

    row.loadBtn:Show()
    row.loadBtn:SetScript("OnClick", function()
        TalentManager.LoadBuild(reminder)
    end)

    -- Tooltip showing class/spec and zone info
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(reminder.name or "Unnamed Build", 1, 0.82, 0)
        if reminder.className and reminder.specName then
            GameTooltip:AddLine(reminder.specName .. " " .. reminder.className, 0.7, 0.7, 0.7)
        end
        if type(zoneKey) == "string" and zoneKey ~= "" then
            GameTooltip:AddLine("Zone: " .. zoneKey, 0.6, 0.8, 1)
        else
            local numZone = tonumber(zoneKey) or 0
            if numZone ~= 0 and numZone < 900000 then
                local mapInfo = C_Map.GetMapInfo(numZone)
                local zoneName = mapInfo and mapInfo.name or ("Map " .. tostring(numZone))
                GameTooltip:AddLine("Zone: " .. zoneName, 0.6, 0.8, 1)
            else
                GameTooltip:AddLine("Instance-wide", 0.6, 0.6, 0.6)
            end
        end
        if reminder.createdDate then
            GameTooltip:AddLine("Created: " .. reminder.createdDate, 0.5, 0.5, 0.5)
        end
        if reminder.note and reminder.note ~= "" then
            GameTooltip:AddLine(reminder.note, 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function TalentManager.RefreshBuildList()
    if not scrollContent then return end

    -- Get current class/spec for filtering
    local _, _, playerClassID = UnitClass("player")
    local specIndex = GetSpecialization()
    local playerSpecID = specIndex and select(1, GetSpecializationInfo(specIndex))

    -- Hide all existing rows
    for _, row in ipairs(buildRows) do
        row:Hide()
    end

    local settings = UIThingsDB.talentManager
    local collapsed = settings.collapsedSections or {}

    -- Get current instance info for name resolution fallback
    local currentInstName, _, _, _, _, _, _, currentInstID = GetInstanceInfo()
    if currentInstID == 0 or currentInstName == "" then
        currentInstName = nil
        currentInstID = nil
    end

    -- Organize builds into tree: category -> instance -> difficulty -> builds
    local raidBuilds = {}          -- [instanceName] = { [diffName] = { builds... } }
    local dungeonBuilds = {}
    local uncategorizedBuilds = {} -- flat list of builds with instanceID=0

    if LunaUITweaks_TalentReminders and LunaUITweaks_TalentReminders.reminders then
        for instanceID, diffs in pairs(LunaUITweaks_TalentReminders.reminders) do
            for diffID, zones in pairs(diffs) do
                for zoneKey, builds in pairs(zones) do
                    if type(builds) ~= "table" then
                        -- skip non-array entries
                    else
                        for buildIndex, reminder in ipairs(builds) do
                            -- Filter by class/spec
                            if reminder.classID and reminder.classID ~= playerClassID then
                                -- skip
                            elseif reminder.specID and reminder.specID ~= playerSpecID then
                                -- skip
                            else
                                -- Check if this build matches current talents
                                local isMatch = false
                                if reminder.talents and addonTable.TalentReminder and addonTable.TalentReminder.CompareTalents then
                                    local mismatches = addonTable.TalentReminder.CompareTalents(reminder.talents)
                                    isMatch = (#mismatches == 0)
                                end

                                if tonumber(instanceID) == 0 then
                                    table.insert(uncategorizedBuilds, {
                                        reminder = reminder,
                                        instanceID = instanceID,
                                        diffID = diffID,
                                        zoneKey = zoneKey,
                                        buildIndex = buildIndex,
                                        isMatch = isMatch,
                                    })
                                else
                                    local diffNum = tonumber(diffID)
                                    local isRaid = IsRaidDifficulty(diffNum)
                                    local target = isRaid and raidBuilds or dungeonBuilds
                                    local cachedName = FindInstanceInCache(instanceID, isRaid and "raid" or "dungeon")
                                        or (currentInstID and tonumber(instanceID) == currentInstID and currentInstName)
                                    local instName = reminder.instanceName or cachedName or
                                        ("Instance " .. tostring(instanceID))
                                    local diffName = reminder.difficulty or GetDifficultyInfo(diffNum) or "Unknown"

                                    if not reminder.instanceName and cachedName then
                                        reminder.instanceName = cachedName
                                    end
                                    if not reminder.difficulty and diffName ~= "Unknown" then
                                        reminder.difficulty = diffName
                                    end

                                    target[instName] = target[instName] or {}
                                    target[instName][diffName] = target[instName][diffName] or {}
                                    table.insert(target[instName][diffName], {
                                        reminder = reminder,
                                        instanceID = instanceID,
                                        diffID = diffID,
                                        zoneKey = zoneKey,
                                        buildIndex = buildIndex,
                                        isMatch = isMatch,
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local rowIndex = 0
    local yOffset = 0

    local function AddRow()
        rowIndex = rowIndex + 1
        local row = GetOrCreateRow(rowIndex)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, -yOffset)
        row:SetWidth(scrollContent:GetWidth())
        row:Show()
        return row
    end

    local function RenderCategory(categoryName, categoryBuilds, indent)
        if not next(categoryBuilds) then return end

        local catKey = categoryName
        local catCollapsed = collapsed[catKey]

        local row = AddRow()
        SetRowAsHeader(row, categoryName, indent, catCollapsed, function()
            collapsed[catKey] = not collapsed[catKey]
            TalentManager.RefreshBuildList()
        end)
        yOffset = yOffset + row:GetHeight() + 4

        if catCollapsed then return end

        -- Sort instance names
        local instanceNames = {}
        for name in pairs(categoryBuilds) do
            table.insert(instanceNames, name)
        end
        table.sort(instanceNames)

        for _, instName in ipairs(instanceNames) do
            local instKey = catKey .. ":" .. instName
            local instCollapsed = collapsed[instKey]

            local iRow = AddRow()
            SetRowAsHeader(iRow, instName, indent + 1, instCollapsed, function()
                collapsed[instKey] = not collapsed[instKey]
                TalentManager.RefreshBuildList()
            end)
            yOffset = yOffset + iRow:GetHeight() + 4

            if not instCollapsed then
                -- Sort difficulties
                local diffNames = {}
                for dName in pairs(categoryBuilds[instName]) do
                    table.insert(diffNames, dName)
                end
                table.sort(diffNames)

                for _, diffName in ipairs(diffNames) do
                    local diffKey = instKey .. ":" .. diffName
                    local diffCollapsed = collapsed[diffKey]

                    local dRow = AddRow()
                    SetRowAsHeader(dRow, diffName, indent + 2, diffCollapsed, function()
                        collapsed[diffKey] = not collapsed[diffKey]
                        TalentManager.RefreshBuildList()
                    end)
                    yOffset = yOffset + dRow:GetHeight() + 4

                    if not diffCollapsed then
                        local builds = categoryBuilds[instName][diffName]
                        table.sort(builds, function(a, b)
                            return (a.reminder.name or "") < (b.reminder.name or "")
                        end)
                        for _, build in ipairs(builds) do
                            local bRow = AddRow()
                            SetRowAsBuild(bRow, build.reminder, build.instanceID, build.diffID, build.zoneKey,
                                build.buildIndex, indent + 3, build.isMatch)
                            yOffset = yOffset + bRow:GetHeight() + 4
                        end
                    end
                end
            end
        end
    end

    -- Render uncategorized builds at the top (no nesting)
    if #uncategorizedBuilds > 0 then
        table.sort(uncategorizedBuilds, function(a, b)
            return (a.reminder.name or "") < (b.reminder.name or "")
        end)
        for _, build in ipairs(uncategorizedBuilds) do
            local bRow = AddRow()
            SetRowAsBuild(bRow, build.reminder, build.instanceID, build.diffID, build.zoneKey, build.buildIndex, 0,
                build.isMatch)
            yOffset = yOffset + bRow:GetHeight() + 4
        end
    end

    RenderCategory("Raids", raidBuilds, 0)
    RenderCategory("Dungeons", dungeonBuilds, 0)

    -- Show empty message if no builds
    if rowIndex == 0 then
        local row = AddRow()
        row.text:SetFont(UIThingsDB.talentManager.font or "Fonts\\FRIZQT__.TTF", 11, "")
        row.text:SetText(
            "|cFFAAAAAAAANo talent builds saved for your\ncurrent class/spec.\n\nUse Add to snapshot your\ncurrent talents.|r")
        row.text:SetTextColor(0.7, 0.7, 0.7)
        row.text:SetPoint("LEFT", 5, 0)
        row.editBtn:Hide()
        row.copyBtn:Hide()
        row.updateBtn:Hide()
        row.deleteBtn:Hide()
        row.loadBtn:Hide()
        row.tickIcon:Hide()
        row.bg:SetColorTexture(0, 0, 0, 0)
        row:SetHeight(80)
        row:EnableMouse(false)
        row:SetScript("OnMouseDown", nil)
        row:SetScript("OnEnter", nil)
        row:SetScript("OnLeave", nil)
        yOffset = yOffset + 80
    end

    scrollContent:SetHeight(math.max(1, yOffset))
end

-- ============================================================
-- Import / Export Dialogs
-- ============================================================

local importExportFrame

local function GetOrCreateImportExportFrame()
    if importExportFrame then return importExportFrame end

    local f = CreateFrame("Frame", "LunaTalentManagerImportExport", UIParent, "BackdropTemplate")
    f:SetSize(450, 250)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", 0, -10)

    local editBox = CreateFrame("EditBox", nil, f, "BackdropTemplate")
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetMaxLetters(0)
    editBox:SetPoint("TOPLEFT", 10, -35)
    editBox:SetPoint("BOTTOMRIGHT", -10, 40)
    editBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    editBox:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    editBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    editBox:SetTextInsets(6, 6, 4, 4)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    editBox:SetScript("OnMouseDown", function(self) self:SetFocus() end)
    f.editBox = editBox

    -- OK button
    f.okBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.okBtn:SetSize(80, 22)
    f.okBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    f.okBtn:SetText("Close")

    -- Cancel button
    f.cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.cancelBtn:SetSize(80, 22)
    f.cancelBtn:SetPoint("RIGHT", f.okBtn, "LEFT", -5, 0)
    f.cancelBtn:SetText("Cancel")
    f.cancelBtn:SetScript("OnClick", function() f:Hide() end)

    importExportFrame = f
    return f
end

function TalentManager.ShowExportDialog()
    if not C_Traits or not C_ClassTalents then
        Log("TalentManager", "Talent APIs not available", LogLevel.WARN)
        return
    end

    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then
        Log("TalentManager", "No active talent config", LogLevel.WARN)
        return
    end

    local exportString = C_Traits.GenerateImportString(configID)
    if not exportString or exportString == "" then
        Log("TalentManager", "Failed to generate export string", LogLevel.WARN)
        return
    end

    local f = GetOrCreateImportExportFrame()
    f.title:SetText("Export Talent Build")
    f.editBox:SetText(exportString)
    f.editBox:HighlightText()
    f.editBox:SetFocus()
    f.cancelBtn:Hide()
    f.okBtn:SetText("Close")
    f.okBtn:SetScript("OnClick", function() f:Hide() end)
    f:Show()
end

function TalentManager.ShowImportDialog()
    local f = GetOrCreateImportExportFrame()
    f.title:SetText("Import Talent Build")
    f.editBox:SetText("")
    f.editBox:SetFocus()
    f.cancelBtn:Show()
    f.okBtn:SetText("Import")
    f.okBtn:SetScript("OnClick", function()
        local importString = f.editBox:GetText()
        if not importString or importString == "" then return end

        -- Strip whitespace and any URL prefix (wowhead URLs contain the string after the last /)
        importString = importString:match("([A-Za-z0-9+/=_-]+)%s*$") or importString:gsub("%s+", "")

        f:Hide()

        -- Store the import string — the Add dialog's save handler checks for this
        TalentManager._pendingImportString = importString

        -- Prompt to save with the Add dialog
        TalentManager.ShowAddDialog(importString)
    end)
    f:Show()
end

-- ============================================================
-- Add / Edit Dialog
-- ============================================================

local addEditFrame

local function GetOrCreateAddEditFrame()
    if addEditFrame then return addEditFrame end

    local f = CreateFrame("Frame", "LunaTalentManagerAddEdit", UIParent, "BackdropTemplate")
    f:SetSize(350, 290)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -12)

    -- Name field
    local nameLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", 15, -45)
    nameLabel:SetText("Name:")

    f.nameBox = CreateFrame("EditBox", "LunaTalentMgrNameBox", f, "InputBoxTemplate")
    f.nameBox:SetSize(220, 22)
    f.nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
    f.nameBox:SetAutoFocus(false)
    f.nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Type dropdown (Uncategorized / Dungeon / Raid)
    local typeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    typeLabel:SetPoint("TOPLEFT", 15, -80)
    typeLabel:SetText("Type:")

    f.typeDropdown = CreateFrame("Frame", "LunaTalentMgrTypeDropdown", f, "UIDropDownMenuTemplate")
    f.typeDropdown:SetPoint("LEFT", typeLabel, "RIGHT", -8, -2)
    UIDropDownMenu_SetWidth(f.typeDropdown, 180)

    -- Instance dropdown
    local instLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instLabel:SetPoint("TOPLEFT", 15, -115)
    instLabel:SetText("Instance:")

    f.instanceDropdown = CreateFrame("Frame", "LunaTalentMgrInstanceDropdown", f, "UIDropDownMenuTemplate")
    f.instanceDropdown:SetPoint("LEFT", instLabel, "RIGHT", -8, -2)
    UIDropDownMenu_SetWidth(f.instanceDropdown, 180)

    -- Difficulty dropdown
    local diffLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    diffLabel:SetPoint("TOPLEFT", 15, -150)
    diffLabel:SetText("Difficulty:")

    f.diffDropdown = CreateFrame("Frame", "LunaTalentMgrDiffDropdown", f, "UIDropDownMenuTemplate")
    f.diffDropdown:SetPoint("LEFT", diffLabel, "RIGHT", -8, -2)
    UIDropDownMenu_SetWidth(f.diffDropdown, 180)

    -- Zone-specific checkbox
    f.zoneCheck = CreateFrame("CheckButton", "LunaTalentMgrZoneCheck", f, "InterfaceOptionsCheckButtonTemplate")
    f.zoneCheck:SetPoint("TOPLEFT", 15, -185)
    f.zoneCheck.Text:SetText("Zone-specific (current subzone only)")
    f.zoneCheck.Text:SetFontObject("GameFontHighlight")

    f.zoneLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.zoneLabel:SetPoint("TOPLEFT", 40, -205)
    f.zoneLabel:SetText("")
    f.zoneLabel:SetTextColor(0.6, 0.6, 0.6)

    -- Save / Cancel buttons
    f.saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.saveBtn:SetSize(100, 25)
    f.saveBtn:SetPoint("BOTTOMRIGHT", -15, 12)
    f.saveBtn:SetText("Save")

    f.cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.cancelBtn:SetSize(100, 25)
    f.cancelBtn:SetPoint("RIGHT", f.saveBtn, "LEFT", -10, 0)
    f.cancelBtn:SetText("Cancel")
    f.cancelBtn:SetScript("OnClick", function() f:Hide() end)

    addEditFrame = f
    return f
end

-- ============================================================
-- Shared Dialog Helpers (Type/Instance/Difficulty cascade)
-- ============================================================

local function InitializeInstanceDropdown(f, contentType, selectedInstanceRef, selectedInstanceNameRef, cache)
    UIDropDownMenu_Initialize(f.instanceDropdown, function(self, level)
        if not cache or not cache.tiers then return end
        local numTiers = #cache.tiers

        -- Collect saved instance IDs not in cache for this type
        local savedExtras = {}
        if LunaUITweaks_TalentReminders and LunaUITweaks_TalentReminders.reminders then
            for instID, diffs in pairs(LunaUITweaks_TalentReminders.reminders) do
                local numInstID = tonumber(instID)
                if numInstID and numInstID ~= 0 then
                    local foundInCache = (FindInstanceInCache(numInstID, contentType) ~= nil)
                    if not foundInCache then
                        -- Check if this instance belongs to the selected content type
                        local belongsToType = false
                        for diffIDKey in pairs(diffs) do
                            local dNum = tonumber(diffIDKey)
                            if contentType == "raid" and IsRaidDifficulty(dNum) then
                                belongsToType = true; break
                            elseif contentType == "dungeon" and IsDungeonDifficulty(dNum) then
                                belongsToType = true; break
                            end
                        end
                        if belongsToType then
                            -- Get name from any reminder (array format)
                            local instName
                            for _, zones in pairs(diffs) do
                                for _, builds in pairs(zones) do
                                    if type(builds) == "table" then
                                        for _, rem in ipairs(builds) do
                                            instName = rem.instanceName; break
                                        end
                                    end
                                    if instName then break end
                                end
                                if instName then break end
                            end
                            savedExtras[#savedExtras + 1] = { id = numInstID, name = instName or ("Instance " .. instID) }
                        end
                    end
                end
            end
        end

        -- Show saved extras at the top if any
        if #savedExtras > 0 then
            table.sort(savedExtras, function(a, b) return a.name < b.name end)
            local headerInfo = UIDropDownMenu_CreateInfo()
            headerInfo.text = "Saved"
            headerInfo.isTitle = true
            headerInfo.notCheckable = true
            UIDropDownMenu_AddButton(headerInfo)

            for _, inst in ipairs(savedExtras) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = "  " .. inst.name
                info.value = inst.id
                info.notCheckable = true
                info.func = function(btn)
                    selectedInstanceRef.value = inst.id
                    selectedInstanceNameRef.value = inst.name
                    UIDropDownMenu_SetText(f.instanceDropdown, inst.name)
                    CloseDropDownMenus()
                end
                UIDropDownMenu_AddButton(info)
            end
        end

        -- Show only the current (latest) tier
        local currentTier = cache.tiers[numTiers]
        if currentTier then
            local instances = (contentType == "raid") and currentTier.raids or currentTier.dungeons
            if instances then
                for _, inst in ipairs(instances) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = inst.name
                    info.value = inst.id
                    info.notCheckable = true
                    info.func = function(btn)
                        selectedInstanceRef.value = inst.id
                        selectedInstanceNameRef.value = inst.name
                        UIDropDownMenu_SetText(f.instanceDropdown, inst.name)
                        CloseDropDownMenus()
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end
        end
    end)
end

local function InitializeDiffDropdown(f, contentType, selectedDiffRef)
    local diffs
    if contentType == "dungeon" then
        diffs = {}
        for _, id in ipairs(DUNGEON_DIFF_ORDER) do
            diffs[#diffs + 1] = { id = id, name = DUNGEON_DIFFICULTIES[id] }
        end
    else
        diffs = {}
        for _, id in ipairs(RAID_DIFF_ORDER) do
            diffs[#diffs + 1] = { id = id, name = RAID_DIFFICULTIES[id] }
        end
    end

    UIDropDownMenu_Initialize(f.diffDropdown, function(self, level)
        for _, diff in ipairs(diffs) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = diff.name
            info.value = diff.id
            info.notCheckable = true
            info.func = function(btn)
                selectedDiffRef.value = btn.value
                UIDropDownMenu_SetText(f.diffDropdown, btn:GetText())
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
end

local function SetupTypeDropdown(f, selectedTypeRef, selectedInstanceRef, selectedInstanceNameRef, selectedDiffRef, cache)
    local function OnTypeChanged(newType)
        selectedTypeRef.value = newType
        if newType == "uncategorized" then
            selectedInstanceRef.value = 0
            selectedInstanceNameRef.value = "Uncategorized"
            selectedDiffRef.value = 0
            UIDropDownMenu_SetText(f.instanceDropdown, "N/A")
            UIDropDownMenu_SetText(f.diffDropdown, "None")
            UIDropDownMenu_DisableDropDown(f.instanceDropdown)
            UIDropDownMenu_DisableDropDown(f.diffDropdown)
        else
            selectedInstanceRef.value = nil
            selectedInstanceNameRef.value = nil
            selectedDiffRef.value = nil
            UIDropDownMenu_SetText(f.instanceDropdown, "Select Instance...")
            UIDropDownMenu_SetText(f.diffDropdown, "Select Difficulty...")
            UIDropDownMenu_EnableDropDown(f.instanceDropdown)
            UIDropDownMenu_EnableDropDown(f.diffDropdown)
            InitializeInstanceDropdown(f, newType, selectedInstanceRef, selectedInstanceNameRef, cache)
            InitializeDiffDropdown(f, newType, selectedDiffRef)
        end
    end

    UIDropDownMenu_Initialize(f.typeDropdown, function(self, level)
        local types = {
            { text = "|cFFAAAAAAAAUncategorized|r", value = "uncategorized", display = "Uncategorized" },
            { text = "Dungeon",                     value = "dungeon",       display = "Dungeon" },
            { text = "Raid",                        value = "raid",          display = "Raid" },
        }
        for _, t in ipairs(types) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = t.text
            info.value = t.value
            info.notCheckable = true
            info.func = function()
                UIDropDownMenu_SetText(f.typeDropdown, t.display)
                OnTypeChanged(t.value)
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    return OnTypeChanged
end

local function SaveBuild(f, selectedTypeRef, selectedInstanceRef, selectedInstanceNameRef, selectedDiffRef, onSuccess)
    local buildName = f.nameBox:GetText()
    if not buildName or buildName == "" then
        Log("TalentManager", "Please enter a build name", LogLevel.WARN)
        return false
    end
    if not selectedTypeRef.value then
        Log("TalentManager", "Please select a type", LogLevel.WARN)
        return false
    end
    if selectedTypeRef.value ~= "uncategorized" and not selectedInstanceRef.value then
        Log("TalentManager", "Please select an instance", LogLevel.WARN)
        return false
    end
    if selectedTypeRef.value ~= "uncategorized" and not selectedDiffRef.value then
        Log("TalentManager", "Please select a difficulty", LogLevel.WARN)
        return false
    end

    -- Zone key: checkbox checked = current subzone text (boss-area granularity), unchecked = 0 (instance-wide)
    local zoneKey = 0
    if f.zoneCheck:GetChecked() then
        local subZone = GetSubZoneText() or ""
        zoneKey = (subZone ~= "") and subZone or 0
    end

    local saveInstID = (selectedTypeRef.value == "uncategorized") and 0 or selectedInstanceRef.value
    local saveDiffID = (selectedTypeRef.value == "uncategorized") and 0 or selectedDiffRef.value
    local instName = (selectedTypeRef.value == "uncategorized") and "Uncategorized" or
        (selectedInstanceNameRef.value or "Unknown")
    local diffName = (selectedTypeRef.value == "uncategorized") and "None"
        or (RAID_DIFFICULTIES[saveDiffID] or DUNGEON_DIFFICULTIES[saveDiffID] or GetDifficultyInfo(saveDiffID) or "Unknown")

    return onSuccess(buildName, saveInstID, saveDiffID, instName, diffName, zoneKey)
end

-- ============================================================
-- Show Add Dialog
-- ============================================================

function TalentManager.ShowAddDialog(importString)
    -- Clear any stale pending import if this isn't an import flow
    if not importString then
        TalentManager._pendingImportString = nil
    end

    local f = GetOrCreateAddEditFrame()
    f.title:SetText("Add Talent Build")
    local cache = EnsureEJCache()

    -- State refs (tables so closures share the same value)
    local selectedTypeRef = { value = nil }
    local selectedInstanceRef = { value = nil }
    local selectedInstanceNameRef = { value = nil }
    local selectedDiffRef = { value = nil }

    -- Pre-populate name
    local location = addonTable.TalentReminder and addonTable.TalentReminder.GetCurrentLocation()
    local defaultName = ""
    if location and location.instanceName and location.instanceType ~= "none" then
        defaultName = location.instanceName
    end
    f.nameBox:SetText(defaultName)

    -- Auto-detect type from current location
    local _, instanceType, difficultyID, _, _, _, _, currentInstID = GetInstanceInfo()

    -- Zone checkbox: default to checked for raids (zone-specific per boss area),
    -- unchecked for dungeons (instance-wide)
    local defaultZoneSpecific = (instanceType == "raid")
    f.zoneCheck:SetChecked(defaultZoneSpecific)
    -- Show current subzone name
    local subZone = GetSubZoneText() or ""
    if subZone ~= "" then
        f.zoneLabel:SetText(subZone)
    else
        f.zoneLabel:SetText("")
    end

    -- Setup type dropdown with cascade
    local OnTypeChanged = SetupTypeDropdown(f, selectedTypeRef, selectedInstanceRef, selectedInstanceNameRef,
        selectedDiffRef, cache)
    if instanceType == "party" then
        UIDropDownMenu_SetText(f.typeDropdown, "Dungeon")
        OnTypeChanged("dungeon")
        -- Pre-select current instance
        if currentInstID and currentInstID ~= 0 then
            selectedInstanceRef.value = currentInstID
            local instName = FindInstanceInCache(currentInstID, "dungeon")
            if instName then
                selectedInstanceNameRef.value = instName
                UIDropDownMenu_SetText(f.instanceDropdown, instName)
            end
        end
        -- Pre-select current difficulty
        if difficultyID and IsDungeonDifficulty(difficultyID) then
            selectedDiffRef.value = difficultyID
            UIDropDownMenu_SetText(f.diffDropdown,
                DUNGEON_DIFFICULTIES[difficultyID] or GetDifficultyInfo(difficultyID) or "Unknown")
        end
    elseif instanceType == "raid" then
        UIDropDownMenu_SetText(f.typeDropdown, "Raid")
        OnTypeChanged("raid")
        -- Pre-select current instance
        if currentInstID and currentInstID ~= 0 then
            selectedInstanceRef.value = currentInstID
            local instName = FindInstanceInCache(currentInstID, "raid")
            if instName then
                selectedInstanceNameRef.value = instName
                UIDropDownMenu_SetText(f.instanceDropdown, instName)
            end
        end
        -- Pre-select current difficulty
        if difficultyID and IsRaidDifficulty(difficultyID) then
            selectedDiffRef.value = difficultyID
            UIDropDownMenu_SetText(f.diffDropdown,
                RAID_DIFFICULTIES[difficultyID] or GetDifficultyInfo(difficultyID) or "Unknown")
        end
    else
        UIDropDownMenu_SetText(f.typeDropdown, "Uncategorized")
        OnTypeChanged("uncategorized")
    end

    -- Save handler
    f.saveBtn:SetScript("OnClick", function()
        SaveBuild(f, selectedTypeRef, selectedInstanceRef, selectedInstanceNameRef, selectedDiffRef,
            function(buildName, saveInstID, saveDiffID, instName, diffName, zoneKey)
                -- Check if this is an import (has a pending import string)
                local pendingImport = TalentManager._pendingImportString
                if pendingImport then
                    TalentManager._pendingImportString = nil

                    local _, className, classID = UnitClass("player")
                    local specIndex = GetSpecialization()
                    local specID, specName = nil, nil
                    if specIndex then
                        specID, specName = GetSpecializationInfo(specIndex)
                    end

                    LunaUITweaks_TalentReminders.reminders[saveInstID] = LunaUITweaks_TalentReminders.reminders[saveInstID] or {}
                    LunaUITweaks_TalentReminders.reminders[saveInstID][saveDiffID] = LunaUITweaks_TalentReminders.reminders[saveInstID][saveDiffID] or {}
                    LunaUITweaks_TalentReminders.reminders[saveInstID][saveDiffID][zoneKey] = LunaUITweaks_TalentReminders.reminders[saveInstID][saveDiffID][zoneKey] or {}

                    table.insert(LunaUITweaks_TalentReminders.reminders[saveInstID][saveDiffID][zoneKey], {
                        name = buildName,
                        instanceName = instName,
                        difficulty = diffName,
                        difficultyID = saveDiffID,
                        createdDate = date("%Y-%m-%d"),
                        note = "",
                        importString = pendingImport,
                        classID = classID,
                        className = className,
                        specID = specID,
                        specName = specName,
                    })

                    Log("TalentManager", "Saved imported build: " .. buildName, LogLevel.INFO)
                    f:Hide()
                    TalentManager.RefreshBuildList()
                    if addonTable.Config and addonTable.Config.RefreshTalentReminderList then
                        addonTable.Config.RefreshTalentReminderList()
                    end
                    return true
                end

                -- Normal save: snapshot current talents
                local success, err, count
                if addonTable.TalentReminder and addonTable.TalentReminder.SaveReminder then
                    success, err, count = addonTable.TalentReminder.SaveReminder(
                        saveInstID, saveDiffID, zoneKey, buildName, instName, diffName, ""
                    )
                end
                if success then
                    Log("TalentManager", "Saved build: " .. buildName, LogLevel.INFO)
                    f:Hide()
                    TalentManager.RefreshBuildList()
                    if addonTable.Config and addonTable.Config.RefreshTalentReminderList then
                        addonTable.Config.RefreshTalentReminderList()
                    end
                else
                    Log("TalentManager", "Failed to save build: " .. (err or "unknown error"), LogLevel.ERROR)
                end
                return success
            end)
    end)

    -- Clear pending import if dialog is cancelled
    f.cancelBtn:SetScript("OnClick", function()
        TalentManager._pendingImportString = nil
        f:Hide()
    end)

    f:Show()
end

-- ============================================================
-- Show Edit Dialog
-- ============================================================

function TalentManager.ShowEditDialog(instanceID, diffID, zoneKey, buildIndex, reminder)
    local f = GetOrCreateAddEditFrame()
    f.title:SetText("Edit Talent Build")
    local cache = EnsureEJCache()

    -- State refs
    local selectedTypeRef = { value = nil }
    local selectedInstanceRef = { value = nil }
    local selectedInstanceNameRef = { value = nil }
    local selectedDiffRef = { value = nil }

    -- Pre-populate fields
    f.nameBox:SetText(reminder.name or "")

    -- Zone checkbox: checked if zoneKey is non-zero/non-empty (zone-specific)
    local isZoneSpecific = (type(zoneKey) == "string" and zoneKey ~= "") or
        (type(zoneKey) == "number" and zoneKey ~= 0)
    f.zoneCheck:SetChecked(isZoneSpecific)
    if type(zoneKey) == "string" and zoneKey ~= "" then
        f.zoneLabel:SetText(zoneKey)
    elseif type(zoneKey) == "number" and zoneKey ~= 0 and zoneKey < 900000 then
        local mapInfo = C_Map.GetMapInfo(zoneKey)
        f.zoneLabel:SetText(mapInfo and mapInfo.name or ("Map " .. tostring(zoneKey)))
    else
        f.zoneLabel:SetText("")
    end

    -- Setup type dropdown with cascade
    local OnTypeChanged = SetupTypeDropdown(f, selectedTypeRef, selectedInstanceRef, selectedInstanceNameRef,
        selectedDiffRef, cache)

    -- Infer type from existing build
    local numInstID = tonumber(instanceID)
    local numDiffID = tonumber(diffID)

    if numInstID == 0 then
        -- Uncategorized
        UIDropDownMenu_SetText(f.typeDropdown, "Uncategorized")
        OnTypeChanged("uncategorized")
    elseif IsRaidDifficulty(numDiffID) then
        -- Raid
        UIDropDownMenu_SetText(f.typeDropdown, "Raid")
        OnTypeChanged("raid")
        -- Pre-select instance
        selectedInstanceRef.value = numInstID
        local instName = FindInstanceInCache(numInstID, "raid") or reminder.instanceName or
            ("Instance " .. tostring(instanceID))
        selectedInstanceNameRef.value = instName
        UIDropDownMenu_SetText(f.instanceDropdown, instName)
        -- Pre-select difficulty
        selectedDiffRef.value = numDiffID
        local diffName = RAID_DIFFICULTIES[numDiffID] or reminder.difficulty or GetDifficultyInfo(numDiffID) or "Unknown"
        UIDropDownMenu_SetText(f.diffDropdown, diffName)
    else
        -- Dungeon
        UIDropDownMenu_SetText(f.typeDropdown, "Dungeon")
        OnTypeChanged("dungeon")
        -- Pre-select instance
        selectedInstanceRef.value = numInstID
        local instName = FindInstanceInCache(numInstID, "dungeon") or reminder.instanceName or
            ("Instance " .. tostring(instanceID))
        selectedInstanceNameRef.value = instName
        UIDropDownMenu_SetText(f.instanceDropdown, instName)
        -- Pre-select difficulty
        selectedDiffRef.value = numDiffID
        local diffName = DUNGEON_DIFFICULTIES[numDiffID] or reminder.difficulty or GetDifficultyInfo(numDiffID) or
            "Unknown"
        UIDropDownMenu_SetText(f.diffDropdown, diffName)
    end

    -- Save handler (delete old, create new)
    f.saveBtn:SetScript("OnClick", function()
        SaveBuild(f, selectedTypeRef, selectedInstanceRef, selectedInstanceNameRef, selectedDiffRef,
            function(newName, saveInstID, saveDiffID, instName, diffName, newZoneKey)
                -- Determine the final zone key
                local finalZoneKey = newZoneKey
                local zoneCheckChecked = f.zoneCheck:GetChecked()

                if not zoneCheckChecked then
                    finalZoneKey = 0
                end

                -- Delete old entry by index
                if addonTable.TalentReminder and addonTable.TalentReminder.DeleteReminder then
                    addonTable.TalentReminder.DeleteReminder(instanceID, diffID, zoneKey, buildIndex)
                end

                -- Append new entry to the target array
                LunaUITweaks_TalentReminders.reminders[saveInstID] = LunaUITweaks_TalentReminders.reminders[saveInstID] or
                    {}
                LunaUITweaks_TalentReminders.reminders[saveInstID][saveDiffID] = LunaUITweaks_TalentReminders.reminders
                    [saveInstID][saveDiffID] or {}
                LunaUITweaks_TalentReminders.reminders[saveInstID][saveDiffID][finalZoneKey] =
                    LunaUITweaks_TalentReminders.reminders[saveInstID][saveDiffID][finalZoneKey] or {}

                table.insert(LunaUITweaks_TalentReminders.reminders[saveInstID][saveDiffID][finalZoneKey], {
                    name = newName,
                    instanceName = instName,
                    difficulty = diffName,
                    difficultyID = saveDiffID,
                    createdDate = reminder.createdDate or date("%Y-%m-%d"),
                    note = reminder.note or "",
                    talents = reminder.talents,
                    importString = reminder.importString,
                    classID = reminder.classID,
                    className = reminder.className,
                    specID = reminder.specID,
                    specName = reminder.specName,
                })

                Log("TalentManager", "Updated build: " .. newName, LogLevel.INFO)
                f:Hide()
                TalentManager.RefreshBuildList()
                if addonTable.Config and addonTable.Config.RefreshTalentReminderList then
                    addonTable.Config.RefreshTalentReminderList()
                end
                return true
            end)
    end)

    f:Show()
end

-- ============================================================
-- Copy Build
-- ============================================================

function TalentManager.CopyBuild(instanceID, diffID, zoneKey, buildIndex, reminder)
    if not reminder then return end

    local newReminder = {
        name = (reminder.name or "Unnamed") .. " (Copy)",
        instanceName = reminder.instanceName,
        difficulty = reminder.difficulty,
        difficultyID = reminder.difficultyID,
        createdDate = date("%Y-%m-%d"),
        note = reminder.note or "",
        talents = reminder.talents and Helpers.DeepCopy(reminder.talents),
        importString = reminder.importString,
        classID = reminder.classID,
        className = reminder.className,
        specID = reminder.specID,
        specName = reminder.specName,
    }

    -- Append to same zone key array
    LunaUITweaks_TalentReminders.reminders[instanceID] = LunaUITweaks_TalentReminders.reminders[instanceID] or {}
    LunaUITweaks_TalentReminders.reminders[instanceID][diffID] = LunaUITweaks_TalentReminders.reminders[instanceID]
        [diffID] or {}
    LunaUITweaks_TalentReminders.reminders[instanceID][diffID][zoneKey] =
        LunaUITweaks_TalentReminders.reminders[instanceID][diffID][zoneKey] or {}
    table.insert(LunaUITweaks_TalentReminders.reminders[instanceID][diffID][zoneKey], newReminder)

    Log("TalentManager", "Copied build: " .. newReminder.name, LogLevel.INFO)
    TalentManager.RefreshBuildList()
    if addonTable.Config and addonTable.Config.RefreshTalentReminderList then
        addonTable.Config.RefreshTalentReminderList()
    end
end

-- ============================================================
-- Import String Decoding Helpers
-- ============================================================

-- Get TalentsFrame from the Blizzard talent UI (must be loaded)
local function GetTalentsFrame()
    if not PlayerSpellsFrame then return nil end
    return PlayerSpellsFrame.TalentsTab or PlayerSpellsFrame.TalentsFrame
end

-- Decode an import string into sorted loadoutEntryInfo using Blizzard's APIs
-- Returns: loadoutEntryInfo table or nil, errorMessage
local function DecodeImportString(importString)
    local talentsFrame = GetTalentsFrame()
    if not talentsFrame then
        return nil, "Talent UI not loaded - open your talent window first"
    end

    local specID = PlayerUtil.GetCurrentSpecID()
    local treeID = C_ClassTalents.GetTraitTreeForSpec(specID)
    if not treeID then
        return nil, "Could not get talent tree for current spec"
    end

    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then
        return nil, "No active talent config"
    end

    -- Decode base64 into a data stream
    local importStream = ExportUtil.MakeImportDataStream(importString)
    if not importStream or not importStream.currentRemainingValue then
        return nil, "Invalid import string format"
    end

    -- Validate header (spec, version, tree hash)
    local version = C_Traits.GetLoadoutSerializationVersion and C_Traits.GetLoadoutSerializationVersion() or 1
    local headerValid, serializationVersion, headerSpecID, treeHash = talentsFrame:ReadLoadoutHeader(importStream)
    if not headerValid then
        return nil, "Bad import string - invalid header"
    end
    if serializationVersion ~= version then
        return nil, "Import string version mismatch - string may be outdated"
    end
    if headerSpecID ~= specID then
        return nil, "Import string is for a different spec"
    end
    if not talentsFrame:IsHashEmpty(treeHash) then
        if not talentsFrame:HashEquals(treeHash, C_Traits.GetTreeHash(treeID)) then
            return nil, "Talent tree has changed since this build was exported"
        end
    end

    -- Parse loadout content
    local ok, loadoutContent = pcall(talentsFrame.ReadLoadoutContent, talentsFrame, importStream, treeID)
    if not ok then
        return nil, "Failed to parse import string content"
    end

    -- Convert to structured entry info
    local loadoutEntryInfo = talentsFrame:ConvertToImportLoadoutEntryInfo(configID, treeID, loadoutContent)
    if not loadoutEntryInfo or #loadoutEntryInfo == 0 then
        return nil, "Import string produced no talent entries"
    end

    -- Build node position order (Y then X) for sorted application
    local nodeOrder = {}
    for _, nodeID in pairs(C_Traits.GetTreeNodes(treeID)) do
        local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
        if nodeInfo.isVisible then
            nodeOrder[nodeID] = { posY = nodeInfo.posY, posX = nodeInfo.posX }
        end
    end

    -- Validate all nodes exist in the tree and assign order
    local orderIndex = {}
    do
        local sorted = {}
        for nodeID, pos in pairs(nodeOrder) do
            sorted[#sorted + 1] = { nodeID = nodeID, posY = pos.posY, posX = pos.posX }
        end
        table.sort(sorted, function(a, b)
            if a.posY ~= b.posY then return a.posY < b.posY end
            return a.posX < b.posX
        end)
        for i, entry in ipairs(sorted) do
            orderIndex[entry.nodeID] = i
        end
    end

    for _, entry in pairs(loadoutEntryInfo) do
        if not orderIndex[entry.nodeID] then
            return nil, "Import string contains unknown talent nodes"
        end
    end

    -- Sort entries by position (top-to-bottom, left-to-right)
    table.sort(loadoutEntryInfo, function(a, b)
        return orderIndex[a.nodeID] < orderIndex[b.nodeID]
    end)

    return loadoutEntryInfo, nil
end

-- ============================================================
-- Load Build
-- ============================================================

function TalentManager.LoadBuild(reminder)
    if not reminder then
        Log("TalentManager", "No build data", LogLevel.WARN)
        return
    end

    -- Imported builds have an importString instead of a talents snapshot
    if reminder.importString then
        if InCombatLockdown() then
            Log("TalentManager", "Cannot change talents while in combat", LogLevel.WARN)
            return
        end

        local configID = C_ClassTalents.GetActiveConfigID()
        if not configID then
            Log("TalentManager", "No active talent config", LogLevel.WARN)
            return
        end

        -- Decode the import string into sorted entry info
        local loadoutEntryInfo, errMsg = DecodeImportString(reminder.importString)
        if not loadoutEntryInfo then
            Log("TalentManager", "Failed to load build: " .. (errMsg or "unknown error"), LogLevel.WARN)
            return
        end

        -- Deactivate starter build if active
        if C_ClassTalents.GetStarterBuildActive() then
            C_ClassTalents.SetStarterBuildActive(false)
        end

        -- Reset the talent tree
        local specID = PlayerUtil.GetCurrentSpecID()
        local treeID = C_ClassTalents.GetTraitTreeForSpec(specID)
        if not treeID then
            Log("TalentManager", "Could not get talent tree", LogLevel.WARN)
            return
        end
        C_Traits.ResetTree(configID, treeID)

        -- Apply each talent in sorted order
        local errorCount = 0
        for _, entry in ipairs(loadoutEntryInfo) do
            local nodeInfo = C_Traits.GetNodeInfo(configID, entry.nodeID)
            local result = true

            if nodeInfo.type == Enum.TraitNodeType.Single or nodeInfo.type == Enum.TraitNodeType.Tiered then
                for rank = 1, entry.ranksPurchased do
                    result = C_Traits.PurchaseRank(configID, entry.nodeID)
                    if not result then break end
                end
            else
                -- Selection or SubTreeSelection
                result = C_Traits.SetSelection(configID, entry.nodeID, entry.selectionEntryID)
            end

            if not result then
                errorCount = errorCount + 1
            end
        end

        -- Commit the changes
        C_Traits.CommitConfig(configID)

        if errorCount > 0 then
            Log("TalentManager", string.format("Applied build with %d node errors: %s", errorCount, reminder.name or "Unknown"), LogLevel.WARN)
        else
            Log("TalentManager", "Applied imported build: " .. (reminder.name or "Unknown"), LogLevel.INFO)
        end
        return
    end

    -- Normal builds with a talents snapshot
    if not reminder.talents then
        Log("TalentManager", "No talent data in this build", LogLevel.WARN)
        return
    end

    if addonTable.TalentReminder and addonTable.TalentReminder.ApplyTalents then
        local success = addonTable.TalentReminder.ApplyTalents(reminder)
        if success then
            Log("TalentManager", "Applied build: " .. (reminder.name or "Unknown"), LogLevel.INFO)
        else
            Log("TalentManager", "Failed to apply build - may need to be out of combat", LogLevel.WARN)
        end
    else
        Log("TalentManager", "TalentReminder module not available", LogLevel.ERROR)
    end
end

-- ============================================================
-- Delete Confirmation
-- ============================================================

StaticPopupDialogs["LUNA_TALENTMGR_DELETE_CONFIRM"] = {
    text = "Delete talent build:\n\n%s",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self, data)
        if addonTable.TalentReminder and addonTable.TalentReminder.DeleteReminder then
            addonTable.TalentReminder.DeleteReminder(data.instanceID, data.diffID, data.zoneKey, data.buildIndex)
        end
        if addonTable.TalentManager then
            addonTable.TalentManager.RefreshBuildList()
        end
        if addonTable.Config and addonTable.Config.RefreshTalentReminderList then
            addonTable.Config.RefreshTalentReminderList()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["LUNA_TALENTMGR_UPDATE_CONFIRM"] = {
    text = "Update talent build with your current talents?\n\n%s",
    button1 = "Update",
    button2 = "Cancel",
    OnAccept = function(self, data)
        if not addonTable.TalentReminder or not addonTable.TalentReminder.CreateSnapshot then
            Log("TalentManager", "TalentReminder module not available", LogLevel.ERROR)
            return
        end
        local snapshot = addonTable.TalentReminder.CreateSnapshot()
        if not snapshot then
            Log("TalentManager", "Failed to snapshot current talents", LogLevel.WARN)
            return
        end
        -- Update the talent data in-place (array-based: access by buildIndex)
        local reminders = LunaUITweaks_TalentReminders and LunaUITweaks_TalentReminders.reminders
        if reminders and reminders[data.instanceID] and reminders[data.instanceID][data.diffID]
            and reminders[data.instanceID][data.diffID][data.zoneKey]
            and reminders[data.instanceID][data.diffID][data.zoneKey][data.buildIndex] then
            local build = reminders[data.instanceID][data.diffID][data.zoneKey][data.buildIndex]
            build.talents = snapshot
            build.importString = nil  -- Convert from import-string build to snapshot build
            Log("TalentManager", "Updated build: " .. (data.reminder.name or "Unknown"), LogLevel.INFO)
        end
        if addonTable.TalentManager then
            addonTable.TalentManager.RefreshBuildList()
        end
        if addonTable.Config and addonTable.Config.RefreshTalentReminderList then
            addonTable.Config.RefreshTalentReminderList()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- ============================================================
-- Settings Update
-- ============================================================

function TalentManager.UpdateSettings()
    if mainPanel then
        local settings = UIThingsDB.talentManager
        mainPanel:SetWidth(settings.panelWidth or 280)
        if scrollContent then
            scrollContent:SetWidth((settings.panelWidth or 280) - 40)
        end
        TalentManager.ApplyVisuals()
        TalentManager.RefreshBuildList()
    end
end

-- ============================================================
-- Event Handling & Initialization
-- ============================================================

-- One-time cleanup of leftover temp loadout entries from old import approach
local function CleanupTempLoadouts()
    local specIndex = GetSpecialization()
    local specID = specIndex and select(1, GetSpecializationInfo(specIndex))
    if not specID then return end

    local configIDs = C_ClassTalents.GetConfigIDsBySpecID(specID)
    if not configIDs then return end

    for _, cid in ipairs(configIDs) do
        local info = C_Traits.GetConfigInfo(cid)
        if info and (info.name == "LunaLoad" or info.name == "LunaTemp" or info.name == "LunaValidate") then
            pcall(C_ClassTalents.DeleteConfig, cid)
        end
    end
end

local function OnTalentManagerAddonLoaded(event, arg1)
    if arg1 == addonName then
        -- Our addon loaded, try to hook if talent frame already exists
        if PlayerSpellsFrame then
            HookTalentFrame()
        end
    elseif arg1 == "Blizzard_PlayerSpells" then
        -- Blizzard talent UI just loaded
        addonTable.Core.SafeAfter(0.1, function()
            HookTalentFrame()
        end)
    end
end

local tempLoadoutsCleaned = false
local function OnTalentManagerEnteringWorld()
    -- Try hooking on world entry in case talent frame loaded before us
    if PlayerSpellsFrame then
        HookTalentFrame()
    end
    -- One-time cleanup of leftover temp loadouts from old import approach
    if not tempLoadoutsCleaned then
        tempLoadoutsCleaned = true
        addonTable.Core.SafeAfter(2, CleanupTempLoadouts)
    end
end

local function OnTalentConfigUpdated()
    -- Refresh check marks when talents change
    if mainPanel and mainPanel:IsShown() then
        TalentManager.RefreshBuildList()
    end
end

addonTable.EventBus.Register("ADDON_LOADED", OnTalentManagerAddonLoaded)
addonTable.EventBus.Register("PLAYER_ENTERING_WORLD", OnTalentManagerEnteringWorld)
addonTable.EventBus.Register("TRAIT_CONFIG_UPDATED", OnTalentConfigUpdated)
addonTable.EventBus.Register("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", OnTalentConfigUpdated)
