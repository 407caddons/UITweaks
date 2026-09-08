-- CompactGroupFinder.lua
-- A visual-only, single-line layout for Blizzard's premade-group search rows.

local addonName, addonTable = ...

addonTable.CompactGroupFinder = addonTable.CompactGroupFinder or {}
local CompactGroupFinder = addonTable.CompactGroupFinder

local FALLBACK_ROW_HEIGHT = 54
local MIN_ROW_HEIGHT = 24
local MAX_ROW_HEIGHT = 54
local TEXT_AREA_WIDTH = 176
local hooksInstalled = false
local defaultRowHeight
local supplementalDisplays = setmetatable({}, { __mode = "k" })
local originalRows = setmetatable({}, { __mode = "k" })
local originalExtent
local ownedView

local function CaptureEntry(entry)
    if originalRows[entry] then return end
    local state = { height = entry:GetHeight(), regions = {} }
    for _, key in ipairs({ "Name", "ActivityName", "Playstyle", "VoiceChat", "DataDisplay" }) do
        local region = entry[key]
        if region then
            local saved = { width = region:GetWidth(), shown = region:IsShown(), points = {} }
            for i = 1, region:GetNumPoints() do saved.points[i] = { region:GetPoint(i) } end
            state.regions[key] = saved
        end
    end
    originalRows[entry] = state
end

local function DefaultRowHeight()
    if defaultRowHeight then return defaultRowHeight end

    local info = C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo("LFGListSearchEntryTemplate")
    defaultRowHeight = info and tonumber(info.height) or FALLBACK_ROW_HEIGHT
    return defaultRowHeight
end

local function Settings()
    return UIThingsDB and UIThingsDB.compactGroupFinder
end

local function SupplementalDisplay(entry)
    local display = supplementalDisplays[entry]
    if display then return display end

    display = CreateFrame("Frame", nil, entry)
    display:SetAllPoints(entry)

    display.Rating = display:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    display.Rating:SetSize(45, 14)
    display.Rating:SetJustifyH("RIGHT")

    display.Members = display:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    display.Members:SetSize(28, 14)
    display.Members:SetJustifyH("RIGHT")

    supplementalDisplays[entry] = display
    return display
end

local function HideSupplementalDisplay(entry)
    local display = supplementalDisplays[entry]
    if display then display:Hide() end
end

local function RestoreEntry(entry)
    local state = originalRows[entry]
    if not state then return end
    entry:SetHeight(state.height)
    for key, saved in pairs(state.regions) do
        local region = entry[key]
        region:ClearAllPoints()
        for _, point in ipairs(saved.points) do region:SetPoint(unpack(point)) end
        region:SetWidth(saved.width)
        region:SetShown(saved.shown)
    end
    if state.pgfRating then state.pgfRating:SetShown(state.pgfShown) end
    originalRows[entry] = nil
    HideSupplementalDisplay(entry)
end

local function CompactEntry(entry)
    local db = Settings()
    if not db or not db.enabled then
        RestoreEntry(entry)
        return
    end

    CaptureEntry(entry)

    local height = math.max(MIN_ROW_HEIGHT, math.min(MAX_ROW_HEIGHT, tonumber(db.rowHeight) or 30))
    entry:SetHeight(height)

    local showActivity = db.showActivity ~= false
    local showPlaystyle = db.showPlaystyle == true
    local showVoice = db.showVoiceChat ~= false
    local showRating = db.showRating ~= false
    local showMemberCount = db.showMemberCount ~= false
    local showRoleData = db.showRoleData ~= false
    local statsWidth = (showRating and 48 or 0) + (showMemberCount and 31 or 0)
    local visibleTextFields = 1 + (showActivity and 1 or 0) + (showPlaystyle and 1 or 0)
    local availableWidth = TEXT_AREA_WIDTH - statsWidth - (showVoice and 20 or 0)
    local fieldWidth = math.max(20, math.floor((availableWidth - ((visibleTextFields - 1) * 5)) / visibleTextFields))

    entry.Name:ClearAllPoints()
    entry.Name:SetPoint("LEFT", entry, "LEFT", 10, 0)
    entry.Name:SetWidth(fieldWidth)

    local previous = entry.Name
    if showVoice and entry.VoiceChat and entry.VoiceChat:IsShown() then
        entry.VoiceChat:ClearAllPoints()
        entry.VoiceChat:SetPoint("LEFT", previous, "RIGHT", 3, 0)
        previous = entry.VoiceChat
    elseif entry.VoiceChat then
        entry.VoiceChat:Hide()
    end

    entry.ActivityName:SetShown(showActivity)
    if showActivity then
        entry.ActivityName:ClearAllPoints()
        entry.ActivityName:SetPoint("LEFT", previous, "RIGHT", 5, 0)
        entry.ActivityName:SetWidth(fieldWidth)
        previous = entry.ActivityName
    end

    entry.Playstyle:SetShown(showPlaystyle)
    if showPlaystyle then
        entry.Playstyle:ClearAllPoints()
        entry.Playstyle:SetPoint("LEFT", previous, "RIGHT", 5, 0)
        entry.Playstyle:SetWidth(fieldWidth)
    end

    if entry.DataDisplay and not showRoleData then
        entry.DataDisplay:Hide()
    end

    local display = SupplementalDisplay(entry)
    display:Show()
    display.Rating:ClearAllPoints()
    display.Members:ClearAllPoints()

    local rightOffset = showRoleData and -125 or -8
    local searchResultInfo = entry.resultID and C_LFGList.GetSearchResultInfo(entry.resultID)
    local showStats = searchResultInfo and not entry.isApplication

    -- PGF adds its rating in a separate frame. Hide that copy while Luna's
    -- rating is selected so the two addons do not draw the same value twice.
    local pgf = PremadeGroupsFilter and PremadeGroupsFilter.Debug
    local pgfRating = pgf and pgf.ratingInfoFrames and pgf.ratingInfoFrames[entry]
    if pgfRating and showRating then
        local state = originalRows[entry]
        if not state.pgfRating then state.pgfRating, state.pgfShown = pgfRating, pgfRating:IsShown() end
        pgfRating:Hide()
    end

    display.Rating:SetShown(showStats and showRating)
    if showStats and showRating then
        local rating = searchResultInfo.leaderOverallDungeonScore or 0
        display.Rating:SetPoint("RIGHT", entry, "RIGHT", rightOffset, 0)
        display.Rating:SetText(rating > 0 and rating or "-")
        local color = rating > 0 and C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor(rating)
        display.Rating:SetTextColor(color and color.r or 0.7, color and color.g or 0.7, color and color.b or 0.7)
        rightOffset = rightOffset - 48
    end

    display.Members:SetShown(showStats and showMemberCount)
    if showStats and showMemberCount then
        display.Members:SetPoint("RIGHT", entry, "RIGHT", rightOffset, 0)
        display.Members:SetText(searchResultInfo.numMembers or "-")
    end
end

local function GetScrollBox()
    return LFGListFrame and LFGListFrame.SearchPanel and LFGListFrame.SearchPanel.ScrollBox
end

local function DesiredRowHeight()
    local db = Settings()
    if not db or not db.enabled then return DefaultRowHeight() end
    return math.max(MIN_ROW_HEIGHT, math.min(MAX_ROW_HEIGHT, tonumber(db.rowHeight) or 30))
end

local function RefreshVisibleEntries()
    local db = Settings()
    local enabled = db and db.enabled
    if not enabled and not ownedView and not next(originalRows) then return end
    local scrollBox = GetScrollBox()
    if not scrollBox then return end

    if not enabled then
        for entry in pairs(originalRows) do RestoreEntry(entry) end
    end

    if scrollBox.ForEachFrame then
        scrollBox:ForEachFrame(function(entry)
            -- Let Blizzard restore dynamic visibility before applying our choices.
            if entry.resultID and LFGListSearchEntry_Update then
                LFGListSearchEntry_Update(entry)
            end
        end)
    end

    local view = scrollBox.GetView and scrollBox:GetView()
    if view and view.SetElementExtent then
        if enabled then
            if not ownedView then
                ownedView, originalExtent = view, view.elementExtent or DefaultRowHeight()
            end
            view:SetElementExtent(DesiredRowHeight())
        elseif ownedView then
            ownedView:SetElementExtent(originalExtent)
            ownedView, originalExtent = nil, nil
        end
        scrollBox:FullUpdate()
    end
end

local function InstallHooks()
    if hooksInstalled or type(LFGListSearchEntry_Update) ~= "function" then return false end
    hooksInstalled = true

    hooksecurefunc("LFGListSearchEntry_Update", CompactEntry)
    if PVEFrame then
        PVEFrame:HookScript("OnShow", RefreshVisibleEntries)
    end
    RefreshVisibleEntries()
    return true
end

function CompactGroupFinder.UpdateSettings()
    InstallHooks()
    RefreshVisibleEntries()
end

addonTable.EventBus.Register("PLAYER_LOGIN", function()
    InstallHooks()
end, "CompactGroupFinder")

addonTable.EventBus.Register("ADDON_LOADED", function(_, loadedAddon)
    if loadedAddon == "Blizzard_GroupFinder" then
        InstallHooks()
    end
end, "CompactGroupFinder")
