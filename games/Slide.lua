local addonName, addonTable = ...
addonTable.Slide = {}

-- ============================================================
-- Slide — 15-puzzle (4x4 sliding tile puzzle)
-- Tiles numbered 1-15, one empty space. Click a highlighted
-- tile adjacent to the gap to slide it into the empty space.
-- Arrange them in order 1-15 left-to-right, top-to-bottom.
-- ============================================================

-- ============================================================
-- Constants
-- ============================================================
local GRID    = 4
local CELL    = 90      -- px per tile
local GAP     = 4       -- px gap between tiles
local PADDING = 10
local SIDE_W  = 140

local BOARD_PX = GRID * CELL + (GRID + 1) * GAP

-- Dark theme colors matching other Luna games
local C_BG        = {0.06, 0.06, 0.08}
local C_TITLE_BAR = {0.12, 0.12, 0.16}
local C_BOARD_BG  = {0.10, 0.10, 0.13}
local C_TILE      = {0.15, 0.28, 0.50}   -- blue tile
local C_TILE_NEAR = {0.10, 0.45, 0.30}   -- green — tile adjacent to gap (can move)
local C_EMPTY     = {0.07, 0.07, 0.09}   -- empty slot
local C_BORDER    = {0.08, 0.08, 0.10}
local C_TEXT      = {0.90, 0.95, 1.00}
local C_WIN_TILE  = {0.15, 0.55, 0.20}   -- green when solved

-- ============================================================
-- State
-- ============================================================
local gameFrame
local boardFrame
local tileFrames   -- tileFrames[r][c] — one frame per cell (static positions)

local board        -- board[r][c] = 1-15 or 0 (empty)
local emptyR, emptyC
local moves        = 0
local bestMoves    = 0
local solved       = false

local moveText, bestText
local winFrame

-- ============================================================
-- Forward declarations
-- ============================================================
local BuildUI, NewGame, RenderBoard

-- ============================================================
-- Goal state check
-- ============================================================
local function IsSolved()
    local expected = 1
    for r = 1, GRID do
        for c = 1, GRID do
            local v = board[r][c]
            if r == GRID and c == GRID then
                if v ~= 0 then return false end
            else
                if v ~= expected then return false end
                expected = expected + 1
            end
        end
    end
    return true
end

-- ============================================================
-- Solvability check
-- Count inversions + blank row from bottom to verify puzzle
-- is solvable (standard 15-puzzle rule).
-- ============================================================
local function IsSolvable(flat)
    local inv = 0
    local blankRow = 0
    for i = 1, #flat do
        if flat[i] == 0 then
            blankRow = math.ceil(i / GRID)
        else
            for j = i + 1, #flat do
                if flat[j] ~= 0 and flat[i] > flat[j] then
                    inv = inv + 1
                end
            end
        end
    end
    -- For 4x4: solvable if
    --   blank on even row from bottom + odd inversions, or
    --   blank on odd  row from bottom + even inversions
    local blankFromBottom = GRID - blankRow + 1
    if blankFromBottom % 2 == 0 then
        return inv % 2 == 1
    else
        return inv % 2 == 0
    end
end

-- ============================================================
-- Shuffle
-- ============================================================
local function Shuffle()
    -- Build flat array 1-15 + 0
    local flat = {}
    for i = 1, GRID * GRID - 1 do flat[i] = i end
    flat[GRID * GRID] = 0

    -- Fisher-Yates, repeat until solvable
    repeat
        for i = #flat, 2, -1 do
            local j = math.random(i)
            flat[i], flat[j] = flat[j], flat[i]
        end
    until IsSolvable(flat)

    -- Fill board
    board = {}
    local idx = 1
    for r = 1, GRID do
        board[r] = {}
        for c = 1, GRID do
            board[r][c] = flat[idx]
            if flat[idx] == 0 then emptyR, emptyC = r, c end
            idx = idx + 1
        end
    end
end

-- ============================================================
-- Rendering
-- ============================================================
local function IsAdjacentToEmpty(r, c)
    return (r == emptyR and math.abs(c - emptyC) == 1) or
           (c == emptyC and math.abs(r - emptyR) == 1)
end

local function UpdateTile(r, c)
    if not tileFrames or not tileFrames[r] or not tileFrames[r][c] then return end
    local f   = tileFrames[r][c]
    local val = board[r][c]
    local adjacent = IsAdjacentToEmpty(r, c)

    if val == 0 then
        -- Empty slot — not clickable
        f.bg:SetColorTexture(C_EMPTY[1], C_EMPTY[2], C_EMPTY[3], 1)
        f.label:SetText("")
        f.label:SetShown(false)
        f:EnableMouse(false)
    elseif solved then
        f.bg:SetColorTexture(C_WIN_TILE[1], C_WIN_TILE[2], C_WIN_TILE[3], 1)
        f.label:SetText(tostring(val))
        f.label:SetShown(true)
        f.label:SetTextColor(C_TEXT[1], C_TEXT[2], C_TEXT[3])
        f:EnableMouse(false)
    elseif adjacent then
        f.bg:SetColorTexture(C_TILE_NEAR[1], C_TILE_NEAR[2], C_TILE_NEAR[3], 1)
        f.label:SetText(tostring(val))
        f.label:SetShown(true)
        f.label:SetTextColor(C_TEXT[1], C_TEXT[2], C_TEXT[3])
        f:EnableMouse(true)
    else
        f.bg:SetColorTexture(C_TILE[1], C_TILE[2], C_TILE[3], 1)
        f.label:SetText(tostring(val))
        f.label:SetShown(true)
        f.label:SetTextColor(C_TEXT[1], C_TEXT[2], C_TEXT[3])
        f:EnableMouse(false)
    end
end

RenderBoard = function()
    for r = 1, GRID do
        for c = 1, GRID do
            UpdateTile(r, c)
        end
    end
    if moveText then moveText:SetText("Moves\n" .. moves) end
    if bestText then
        bestText:SetText("Best\n" .. (bestMoves > 0 and bestMoves or "-"))
    end
end

-- ============================================================
-- Move logic — slide the tile at (tr, tc) into the empty space
-- ============================================================
local function TrySlideCell(tr, tc)
    if solved then return end
    if not IsAdjacentToEmpty(tr, tc) then return end

    board[emptyR][emptyC] = board[tr][tc]
    board[tr][tc] = 0
    emptyR, emptyC = tr, tc
    moves = moves + 1

    RenderBoard()

    if IsSolved() then
        solved = true
        if bestMoves == 0 or moves < bestMoves then
            bestMoves = moves
            if UIThingsDB.games and UIThingsDB.games.slide then
                UIThingsDB.games.slide.best = bestMoves
            end
        end
        RenderBoard()  -- re-render with win colors
        C_Timer.After(0.4, function()
            if winFrame then
                winFrame.movesText:SetText(
                    string.format("Moves: %d%s", moves,
                        bestMoves > 0 and ("\nBest: " .. bestMoves) or ""))
                winFrame:Show()
            end
        end)
    end
end

-- ============================================================
-- New game
-- ============================================================
NewGame = function()
    moves  = 0
    solved = false
    if UIThingsDB.games and UIThingsDB.games.slide then
        bestMoves = UIThingsDB.games.slide.best or 0
    end
    Shuffle()
    if winFrame then winFrame:Hide() end
    RenderBoard()
end

-- ============================================================
-- UI construction
-- ============================================================
local function TileX(c) return GAP + (c - 1) * (CELL + GAP) end
local function TileY(r) return -(GAP + (r - 1) * (CELL + GAP)) end

local function BuildTiles(parent)
    tileFrames = {}
    for r = 1, GRID do
        tileFrames[r] = {}
        for c = 1, GRID do
            local f = CreateFrame("Button", nil, parent)
            f:SetSize(CELL, CELL)
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", TileX(c), TileY(r))

            -- Background
            f.bg = f:CreateTexture(nil, "BACKGROUND")
            f.bg:SetPoint("TOPLEFT",     f, "TOPLEFT",     1, -1)
            f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
            f.bg:SetColorTexture(C_TILE[1], C_TILE[2], C_TILE[3], 1)

            -- Border
            local bdr = f:CreateTexture(nil, "BORDER")
            bdr:SetAllPoints()
            bdr:SetColorTexture(C_BORDER[1], C_BORDER[2], C_BORDER[3], 1)

            -- Highlight texture (shown on hover for movable tiles)
            local hl = f:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.12)
            f:SetHighlightTexture(hl)

            -- Number label
            f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
            f.label:SetAllPoints()
            f.label:SetJustifyH("CENTER")
            f.label:SetJustifyV("MIDDLE")
            f.label:SetTextColor(C_TEXT[1], C_TEXT[2], C_TEXT[3])
            f.label:SetText("")

            -- Click handler — capture r and c as upvalues
            local tr, tc = r, c
            f:SetScript("OnClick", function() TrySlideCell(tr, tc) end)
            f:EnableMouse(false)  -- enabled only when adjacent to empty

            tileFrames[r][c] = f
        end
    end
end

BuildUI = function()
    local totalW = BOARD_PX + PADDING * 3 + SIDE_W
    local totalH = BOARD_PX + PADDING * 2 + 30

    gameFrame = CreateFrame("Frame", "LunaUITweaks_SlideGame", UIParent)
    gameFrame:SetSize(totalW, totalH)
    gameFrame:SetPoint("CENTER")
    gameFrame:SetFrameStrata("DIALOG")
    gameFrame:SetMovable(true)
    gameFrame:SetClampedToScreen(true)
    gameFrame:RegisterForDrag("LeftButton")
    gameFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    gameFrame:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)
    gameFrame:Hide()

    -- Background
    local bgTex = gameFrame:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints()
    bgTex:SetColorTexture(C_BG[1], C_BG[2], C_BG[3], 0.97)

    local borderTex = gameFrame:CreateTexture(nil, "BORDER")
    borderTex:SetAllPoints()
    borderTex:SetColorTexture(0.25, 0.25, 0.30, 1)

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, gameFrame)
    titleBar:SetPoint("TOPLEFT",  gameFrame, "TOPLEFT",  1, -1)
    titleBar:SetPoint("TOPRIGHT", gameFrame, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(28)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() gameFrame:StartMoving() end)
    titleBar:SetScript("OnDragStop",  function() gameFrame:StopMovingOrSizing() end)

    local titleBarBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBarBg:SetAllPoints()
    titleBarBg:SetColorTexture(C_TITLE_BAR[1], C_TITLE_BAR[2], C_TITLE_BAR[3], 1)

    local titleLabel = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleLabel:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    titleLabel:SetText("|cFF60A0FFSlide|r  |cFF888888drag to move · click highlighted tiles to play|r")

    local closeBtn = CreateFrame("Button", nil, gameFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", gameFrame, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() gameFrame:Hide() end)

    -- Board frame
    boardFrame = CreateFrame("Frame", nil, gameFrame)
    boardFrame:SetSize(BOARD_PX, BOARD_PX)
    boardFrame:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", PADDING, -(PADDING + 30))

    local boardBg = boardFrame:CreateTexture(nil, "BACKGROUND")
    boardBg:SetAllPoints()
    boardBg:SetColorTexture(C_BOARD_BG[1], C_BOARD_BG[2], C_BOARD_BG[3], 1)

    BuildTiles(boardFrame)

    -- ── Side panel ───────────────────────────────────────────
    local sideAnchor = CreateFrame("Frame", nil, gameFrame)
    sideAnchor:SetPoint("TOPLEFT", boardFrame, "TOPRIGHT", PADDING, 0)
    sideAnchor:SetSize(SIDE_W, BOARD_PX)

    local gameTitle = sideAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    gameTitle:SetPoint("TOPLEFT", sideAnchor, "TOPLEFT", 0, -4)
    gameTitle:SetText("|cFF60A0FFSlide Puzzle|r")

    local desc = sideAnchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", gameTitle, "BOTTOMLEFT", 0, -4)
    desc:SetWidth(SIDE_W)
    desc:SetText("|cFF888888Arrange 1-15 in order.|r")

    moveText = sideAnchor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    moveText:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
    moveText:SetJustifyH("LEFT")
    moveText:SetText("Moves\n0")

    bestText = sideAnchor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bestText:SetPoint("TOPLEFT", moveText, "BOTTOMLEFT", 0, -8)
    bestText:SetJustifyH("LEFT")
    bestText:SetText("Best\n-")

    -- Color key
    local keyLabel = sideAnchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    keyLabel:SetPoint("TOPLEFT", sideAnchor, "TOPLEFT", 0, -130)
    keyLabel:SetWidth(SIDE_W)
    keyLabel:SetTextColor(0.6, 0.6, 0.6)
    keyLabel:SetText("Green = click to move")

    -- Buttons
    local BTN_W = SIDE_W - 4
    local BTN_H = 24

    local newBtn = CreateFrame("Button", nil, gameFrame, "UIPanelButtonTemplate")
    newBtn:SetSize(BTN_W, BTN_H)
    newBtn:SetPoint("BOTTOMLEFT", sideAnchor, "BOTTOMLEFT", 0, 4)
    newBtn:SetText("New Game")
    newBtn:SetScript("OnClick", NewGame)

    -- ── Win overlay ──────────────────────────────────────────
    winFrame = CreateFrame("Frame", nil, boardFrame)
    winFrame:SetAllPoints()
    winFrame:SetFrameLevel(boardFrame:GetFrameLevel() + 20)

    local winBg = winFrame:CreateTexture(nil, "ARTWORK")
    winBg:SetAllPoints()
    winBg:SetColorTexture(0, 0, 0, 0.72)

    local winTitle = winFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    winTitle:SetPoint("CENTER", winFrame, "CENTER", 0, 50)
    winTitle:SetText("|cFFFFD100Solved!|r")

    winFrame.movesText = winFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    winFrame.movesText:SetPoint("CENTER", winFrame, "CENTER", 0, 15)
    winFrame.movesText:SetJustifyH("CENTER")

    local winNewBtn = CreateFrame("Button", nil, winFrame, "UIPanelButtonTemplate")
    winNewBtn:SetSize(110, 26)
    winNewBtn:SetPoint("CENTER", winFrame, "CENTER", 0, -25)
    winNewBtn:SetText("New Game")
    winNewBtn:SetScript("OnClick", NewGame)

    winFrame:Hide()
end

-- ============================================================
-- Combat handling
-- ============================================================
addonTable.EventBus.Register("PLAYER_REGEN_DISABLED", function()
    if not (gameFrame and gameFrame:IsShown()) then return end
    if UIThingsDB.games and UIThingsDB.games.closeInCombat then
        gameFrame:Hide()
    end
end)

-- ============================================================
-- Public API
-- ============================================================
function addonTable.Slide.CloseGame()
    if gameFrame and gameFrame:IsShown() then
        gameFrame:Hide()
    end
end

function addonTable.Slide.ShowGame()
    if not gameFrame then
        BuildUI()
        if UIThingsDB.games and UIThingsDB.games.slide then
            bestMoves = UIThingsDB.games.slide.best or 0
        end
        NewGame()
    end
    if gameFrame:IsShown() then
        addonTable.Slide.CloseGame()
    else
        if addonTable.Snek     then addonTable.Snek.CloseGame() end
        if addonTable.Game2048 then addonTable.Game2048.CloseGame() end
        if addonTable.Boxes    then addonTable.Boxes.CloseGame() end
        gameFrame:Show()
    end
end
