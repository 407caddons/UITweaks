local addonName, addonTable = ...
addonTable.Lights = {}

-- ============================================================
-- Lights — Lights Out puzzle
-- 5x5 grid of lights. Clicking a light toggles it and its
-- orthogonal neighbors. Goal: turn all lights off.
-- ============================================================

-- ============================================================
-- Constants
-- ============================================================
local GRID    = 5
local CELL    = 60      -- px per cell
local GAP     = 4       -- px gap between cells
local PADDING = 10
local SIDE_W  = 140

local BOARD_PX = GRID * CELL + (GRID + 1) * GAP

-- Dark theme colors matching other Luna games
local C_BG        = {0.06, 0.06, 0.08}
local C_TITLE_BAR = {0.12, 0.12, 0.16}
local C_BOARD_BG  = {0.10, 0.10, 0.13}
local C_ON        = {0.85, 0.75, 0.15}   -- bright yellow — light is ON
local C_OFF       = {0.13, 0.13, 0.17}   -- dark — light is OFF
local C_BORDER    = {0.25, 0.25, 0.30}
local C_TEXT      = {0.90, 0.95, 1.00}
local C_WIN_ON    = {0.15, 0.55, 0.20}   -- green when solved (all off)

-- ============================================================
-- State
-- ============================================================
local gameFrame
local boardFrame
local cellFrames   -- cellFrames[r][c]

local board        -- board[r][c] = true (on) / false (off)
local moves        = 0
local bestMoves    = 0
local solved       = false
local currentLevel = 1

local moveText, bestText, levelText
local winFrame

-- ============================================================
-- Forward declarations
-- ============================================================
local BuildUI, NewGame, RenderBoard

-- ============================================================
-- Check if all lights are off
-- ============================================================
local function IsSolved()
    for r = 1, GRID do
        for c = 1, GRID do
            if board[r][c] then return false end
        end
    end
    return true
end

-- ============================================================
-- Toggle a single cell (no neighbors)
-- ============================================================
local function ToggleCell(r, c)
    if r >= 1 and r <= GRID and c >= 1 and c <= GRID then
        board[r][c] = not board[r][c]
    end
end

-- ============================================================
-- Click handler — toggle cell + orthogonal neighbors
-- ============================================================
local function OnCellClick(r, c)
    if solved then return end

    ToggleCell(r, c)
    ToggleCell(r - 1, c)
    ToggleCell(r + 1, c)
    ToggleCell(r, c - 1)
    ToggleCell(r, c + 1)

    moves = moves + 1
    RenderBoard()

    if IsSolved() then
        solved = true
        if bestMoves == 0 or moves < bestMoves then
            bestMoves = moves
            if UIThingsDB.games and UIThingsDB.games.lights then
                UIThingsDB.games.lights.best = bestMoves
            end
        end
        RenderBoard()
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
-- Generate a solvable random puzzle
-- Start from solved (all off) and apply random clicks to
-- guarantee solvability. More clicks = harder puzzle.
-- ============================================================
local function GenerateBoard(numClicks)
    board = {}
    for r = 1, GRID do
        board[r] = {}
        for c = 1, GRID do
            board[r][c] = false
        end
    end

    -- Apply random clicks from solved state (guarantees solvability)
    local clickCount = numClicks or math.random(6, 12)
    for _ = 1, clickCount do
        local r = math.random(1, GRID)
        local c = math.random(1, GRID)
        ToggleCell(r, c)
        ToggleCell(r - 1, c)
        ToggleCell(r + 1, c)
        ToggleCell(r, c - 1)
        ToggleCell(r, c + 1)
    end

    -- Make sure at least one light is on
    local anyOn = false
    for r = 1, GRID do
        for c = 1, GRID do
            if board[r][c] then anyOn = true; break end
        end
        if anyOn then break end
    end
    if not anyOn then
        -- Force a single click in center
        local cr, cc = 3, 3
        ToggleCell(cr, cc)
        ToggleCell(cr - 1, cc)
        ToggleCell(cr + 1, cc)
        ToggleCell(cr, cc - 1)
        ToggleCell(cr, cc + 1)
    end
end

-- ============================================================
-- Rendering
-- ============================================================
local function UpdateCell(r, c)
    if not cellFrames or not cellFrames[r] or not cellFrames[r][c] then return end
    local f  = cellFrames[r][c]
    local on = board[r][c]

    if solved then
        f.bg:SetColorTexture(C_WIN_ON[1], C_WIN_ON[2], C_WIN_ON[3], 1)
    elseif on then
        f.bg:SetColorTexture(C_ON[1], C_ON[2], C_ON[3], 1)
    else
        f.bg:SetColorTexture(C_OFF[1], C_OFF[2], C_OFF[3], 1)
    end
end

RenderBoard = function()
    for r = 1, GRID do
        for c = 1, GRID do
            UpdateCell(r, c)
        end
    end
    if moveText  then moveText:SetText("Moves\n" .. moves) end
    if bestText  then bestText:SetText("Best\n" .. (bestMoves > 0 and bestMoves or "-")) end
    if levelText then levelText:SetText("Level\n" .. currentLevel) end
end

-- ============================================================
-- New game
-- ============================================================
NewGame = function()
    moves  = 0
    solved = false
    if UIThingsDB.games and UIThingsDB.games.lights then
        bestMoves = UIThingsDB.games.lights.best or 0
    end
    -- Scale difficulty with level: more random clicks = harder
    local numClicks = math.min(5 + currentLevel * 2, 25)
    GenerateBoard(numClicks)
    if winFrame then winFrame:Hide() end
    RenderBoard()
end

-- ============================================================
-- UI construction
-- ============================================================
local function CellX(c) return GAP + (c - 1) * (CELL + GAP) end
local function CellY(r) return -(GAP + (r - 1) * (CELL + GAP)) end

local function BuildCells(parent)
    cellFrames = {}
    for r = 1, GRID do
        cellFrames[r] = {}
        for c = 1, GRID do
            local f = CreateFrame("Button", nil, parent)
            f:SetSize(CELL, CELL)
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", CellX(c), CellY(r))
            f:EnableMouse(true)
            f:RegisterForClicks("LeftButtonUp")

            -- Border background (outermost, darkest)
            local bdr = f:CreateTexture(nil, "BACKGROUND", nil, 0)
            bdr:SetAllPoints()
            bdr:SetColorTexture(C_BORDER[1], C_BORDER[2], C_BORDER[3], 1)

            -- Light color (inset 1px to reveal border)
            f.bg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
            f.bg:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
            f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
            f.bg:SetColorTexture(C_OFF[1], C_OFF[2], C_OFF[3], 1)

            -- Hover highlight
            f:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight", "ADD")

            -- Click handler
            local tr, tc = r, c
            f:SetScript("OnClick", function() OnCellClick(tr, tc) end)

            cellFrames[r][c] = f
        end
    end
end

BuildUI = function()
    local totalW = BOARD_PX + PADDING * 3 + SIDE_W
    local totalH = BOARD_PX + PADDING * 2 + 30

    gameFrame = CreateFrame("Frame", "LunaUITweaks_LightsGame", UIParent)
    gameFrame:SetSize(totalW, totalH)
    gameFrame:SetPoint("CENTER")
    gameFrame:SetFrameStrata("DIALOG")
    gameFrame:EnableMouse(true)
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
    titleLabel:SetText("|cFFFFCC00Lights|r  |cFF888888click to toggle · turn all lights off|r")

    local closeBtn = CreateFrame("Button", nil, gameFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", gameFrame, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() gameFrame:Hide() end)

    -- Board frame
    boardFrame = CreateFrame("Frame", nil, gameFrame)
    boardFrame:SetSize(BOARD_PX, BOARD_PX)
    boardFrame:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", PADDING, -(PADDING + 30))
    boardFrame:EnableMouse(false)

    local boardBg = boardFrame:CreateTexture(nil, "BACKGROUND")
    boardBg:SetAllPoints()
    boardBg:SetColorTexture(C_BOARD_BG[1], C_BOARD_BG[2], C_BOARD_BG[3], 1)

    BuildCells(boardFrame)

    -- ── Side panel ───────────────────────────────────────────
    local sideAnchor = CreateFrame("Frame", nil, gameFrame)
    sideAnchor:SetPoint("TOPLEFT", boardFrame, "TOPRIGHT", PADDING, 0)
    sideAnchor:SetSize(SIDE_W, BOARD_PX)

    local gameTitle = sideAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    gameTitle:SetPoint("TOPLEFT", sideAnchor, "TOPLEFT", 0, -4)
    gameTitle:SetText("|cFFFFCC00Lights Out|r")

    local desc = sideAnchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", gameTitle, "BOTTOMLEFT", 0, -4)
    desc:SetWidth(SIDE_W)
    desc:SetText("|cFF888888Turn all lights off.\nClicking toggles a cell\nand its 4 neighbors.|r")

    levelText = sideAnchor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    levelText:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
    levelText:SetJustifyH("LEFT")
    levelText:SetText("Level\n1")

    moveText = sideAnchor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    moveText:SetPoint("TOPLEFT", levelText, "BOTTOMLEFT", 0, -8)
    moveText:SetJustifyH("LEFT")
    moveText:SetText("Moves\n0")

    bestText = sideAnchor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bestText:SetPoint("TOPLEFT", moveText, "BOTTOMLEFT", 0, -8)
    bestText:SetJustifyH("LEFT")
    bestText:SetText("Best\n-")

    -- Buttons
    local BTN_W = SIDE_W - 4
    local BTN_H = 24

    local newBtn = CreateFrame("Button", nil, gameFrame, "UIPanelButtonTemplate")
    newBtn:SetSize(BTN_W, BTN_H)
    newBtn:SetPoint("BOTTOMLEFT", sideAnchor, "BOTTOMLEFT", 0, BTN_H + 8)
    newBtn:SetText("New Game")
    newBtn:SetScript("OnClick", function()
        currentLevel = 1
        NewGame()
    end)

    local nextBtn = CreateFrame("Button", nil, gameFrame, "UIPanelButtonTemplate")
    nextBtn:SetSize(BTN_W, BTN_H)
    nextBtn:SetPoint("BOTTOMLEFT", sideAnchor, "BOTTOMLEFT", 0, 4)
    nextBtn:SetText("Next Level")
    nextBtn:SetScript("OnClick", function()
        currentLevel = currentLevel + 1
        NewGame()
    end)

    -- ── Win overlay ──────────────────────────────────────────
    winFrame = CreateFrame("Frame", nil, boardFrame)
    winFrame:SetAllPoints()
    winFrame:SetFrameLevel(boardFrame:GetFrameLevel() + 20)

    local winBg = winFrame:CreateTexture(nil, "ARTWORK")
    winBg:SetAllPoints()
    winBg:SetColorTexture(0, 0, 0, 0.72)

    local winTitle = winFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    winTitle:SetPoint("CENTER", winFrame, "CENTER", 0, 50)
    winTitle:SetText("|cFFFFD100Lights Out!|r")

    winFrame.movesText = winFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    winFrame.movesText:SetPoint("CENTER", winFrame, "CENTER", 0, 15)
    winFrame.movesText:SetJustifyH("CENTER")

    local winNextBtn = CreateFrame("Button", nil, winFrame, "UIPanelButtonTemplate")
    winNextBtn:SetSize(110, 26)
    winNextBtn:SetPoint("CENTER", winFrame, "CENTER", 0, -25)
    winNextBtn:SetText("Next Level")
    winNextBtn:SetScript("OnClick", function()
        currentLevel = currentLevel + 1
        NewGame()
    end)

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
function addonTable.Lights.CloseGame()
    if gameFrame and gameFrame:IsShown() then
        gameFrame:Hide()
    end
end

function addonTable.Lights.ShowGame()
    if not gameFrame then
        BuildUI()
        if UIThingsDB.games and UIThingsDB.games.lights then
            bestMoves = UIThingsDB.games.lights.best or 0
        end
        NewGame()
    end
    if gameFrame:IsShown() then
        addonTable.Lights.CloseGame()
    else
        if addonTable.Snek     and addonTable.Snek.CloseGame     then addonTable.Snek.CloseGame() end
        if addonTable.Game2048 and addonTable.Game2048.CloseGame then addonTable.Game2048.CloseGame() end
        if addonTable.Boxes    and addonTable.Boxes.CloseGame    then addonTable.Boxes.CloseGame() end
        if addonTable.Slide    and addonTable.Slide.CloseGame    then addonTable.Slide.CloseGame() end
        if addonTable.Bombs    and addonTable.Bombs.CloseGame    then addonTable.Bombs.CloseGame() end
        if addonTable.Gems     and addonTable.Gems.CloseGame     then addonTable.Gems.CloseGame() end
        if addonTable.Cards    and addonTable.Cards.CloseGame    then addonTable.Cards.CloseGame() end
        if winFrame then winFrame:Hide() end
        gameFrame:Show()
    end
end
