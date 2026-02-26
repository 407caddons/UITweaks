local addonName, addonTable = ...
addonTable.Bombs = {}

-- ============================================================
-- Constants
-- ============================================================
local CELL       = 24    -- px per cell
local PADDING    = 8

-- Difficulty presets: {cols, rows, mines}
local DIFFICULTY = {
    Easy   = { cols = 9,  rows = 9,  mines = 10 },
    Medium = { cols = 16, rows = 16, mines = 40 },
    Hard   = { cols = 20, rows = 16, mines = 60 },
}
local DIFF_ORDER = { "Easy", "Medium", "Hard" }

-- Cell states
local HIDDEN   = 0
local REVEALED = 1
local FLAGGED  = 2

-- ============================================================
-- State
-- ============================================================
local gameFrame
local boardFrame
local cells         -- cells[r][c] = button frame
local cellState     -- cellState[r][c] = HIDDEN | REVEALED | FLAGGED
local cellMine      -- cellMine[r][c] = true/false
local cellCount     -- cellCount[r][c] = adjacent mine count (0-8)

-- Frame pooling to prevent memory leaks on difficulty change
local cellPool = {}
local poolCount = 0

local COLS, ROWS, MINES
local minesText, timerText, diffText
local gameOverFrame
local newGameBtn, diffBtn
local gameActive
local firstClick     -- true until first cell is revealed
local flagCount
local revealedCount
local startTime
local timerTicker

local currentDiff = "Easy"

-- Colors for numbers 1-8
local NUMBER_COLORS = {
    "|cFF0000FF",  -- 1 blue
    "|cFF008000",  -- 2 green
    "|cFFFF0000",  -- 3 red
    "|cFF000080",  -- 4 dark blue
    "|cFF800000",  -- 5 maroon
    "|cFF008080",  -- 6 teal
    "|cFF000000",  -- 7 black
    "|cFF808080",  -- 8 gray
}

local math_floor = math.floor
local math_max   = math.max
local math_min   = math.min

-- ============================================================
-- Forward declarations
-- ============================================================
local StartGame, GameOver, GameWin, RevealCell, BuildUI, ResizeBoard

-- ============================================================
-- Board logic
-- ============================================================
local revealQueue = {} -- Reusable table for flood fill

local function PlaceMines(safeR, safeC)
    -- Clear
    for r = 1, ROWS do
        for c = 1, COLS do
            cellMine[r][c] = false
            cellCount[r][c] = 0
        end
    end

    -- Build list of valid cells (exclude safe zone around first click)
    local valid = {}
    for r = 1, ROWS do
        for c = 1, COLS do
            local safe = false
            if math.abs(r - safeR) <= 1 and math.abs(c - safeC) <= 1 then
                safe = true
            end
            if not safe then
                valid[#valid + 1] = { r = r, c = c }
            end
        end
    end

    -- Shuffle and pick first MINES entries
    local count = math_min(MINES, #valid)
    for i = 1, count do
        local j = math.random(i, #valid)
        valid[i], valid[j] = valid[j], valid[i]
        local mr, mc = valid[i].r, valid[i].c
        cellMine[mr][mc] = true
    end

    -- Compute neighbor counts
    for r = 1, ROWS do
        for c = 1, COLS do
            if cellMine[r][c] then
                for dr = -1, 1 do
                    for dc = -1, 1 do
                        if dr ~= 0 or dc ~= 0 then
                            local nr, nc = r + dr, c + dc
                            if nr >= 1 and nr <= ROWS and nc >= 1 and nc <= COLS then
                                cellCount[nr][nc] = cellCount[nr][nc] + 1
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================
-- Rendering
-- ============================================================
local function UpdateCell(r, c)
    local cell = cells[r][c]
    if not cell then return end

    local state = cellState[r][c]
    if state == HIDDEN then
        cell.tex:SetColorTexture(0.25, 0.25, 0.30, 1)
        cell.label:SetText("")
    elseif state == FLAGGED then
        cell.tex:SetColorTexture(0.25, 0.25, 0.30, 1)
        cell.label:SetText("|cFFFF4444F|r")
    elseif state == REVEALED then
        if cellMine[r][c] then
            cell.tex:SetColorTexture(0.8, 0.1, 0.1, 1)
            cell.label:SetText("|cFFFFFFFFX|r")
        else
            cell.tex:SetColorTexture(0.12, 0.12, 0.15, 1)
            local n = cellCount[r][c]
            if n > 0 then
                local col = NUMBER_COLORS[n] or "|cFFFFFFFF"
                cell.label:SetText(col .. n .. "|r")
            else
                cell.label:SetText("")
            end
        end
    end
end

local function UpdateHUD()
    if minesText then minesText:SetText("Mines\n" .. (MINES - flagCount)) end
    if timerText and startTime then
        local elapsed = math_floor(GetTime() - startTime)
        timerText:SetText("Time\n" .. elapsed)
    elseif timerText then
        timerText:SetText("Time\n0")
    end
    if diffText then diffText:SetText(currentDiff) end
end

-- ============================================================
-- Reveal logic (flood fill for zeros)
-- ============================================================
RevealCell = function(r, c)
    if not gameActive then return end
    if cellState[r][c] ~= HIDDEN then return end

    -- First click: place mines avoiding this cell
    if firstClick then
        firstClick = false
        PlaceMines(r, c)
        startTime = GetTime()
        if timerTicker then timerTicker:Cancel() end
        timerTicker = C_Timer.NewTicker(1, function()
            if gameActive then UpdateHUD() end
        end)
    end

    cellState[r][c] = REVEALED
    revealedCount = revealedCount + 1
    UpdateCell(r, c)

    if cellMine[r][c] then
        GameOver()
        return
    end

    -- Flood fill if count is 0 (Iterative to prevent stack overflow)
    -- Queue stores pairs: revealQueue[2k-1]=row, revealQueue[2k]=col (no per-cell tables)
    if cellCount[r][c] == 0 then
        wipe(revealQueue)
        revealQueue[1] = r
        revealQueue[2] = c
        local head = 1
        local tail = 2

        while head <= tail do
            local cr = revealQueue[head]
            local cc = revealQueue[head + 1]
            head = head + 2

            for dr = -1, 1 do
                for dc = -1, 1 do
                    if dr ~= 0 or dc ~= 0 then
                        local nr, nc = cr + dr, cc + dc
                        if nr >= 1 and nr <= ROWS and nc >= 1 and nc <= COLS then
                            if cellState[nr][nc] == HIDDEN then
                                cellState[nr][nc] = REVEALED
                                revealedCount = revealedCount + 1
                                UpdateCell(nr, nc)

                                if cellCount[nr][nc] == 0 then
                                    tail = tail + 2
                                    revealQueue[tail - 1] = nr
                                    revealQueue[tail]     = nc
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Check win
    if revealedCount == (ROWS * COLS - MINES) then
        GameWin()
    end
end

local function ChordReveal(r, c)
    if not gameActive then return end
    if cellState[r][c] ~= REVEALED then return end
    local n = cellCount[r][c]
    if n == 0 then return end

    -- Count adjacent flags
    local adjFlags = 0
    for dr = -1, 1 do
        for dc = -1, 1 do
            if dr ~= 0 or dc ~= 0 then
                local nr, nc = r + dr, c + dc
                if nr >= 1 and nr <= ROWS and nc >= 1 and nc <= COLS then
                    if cellState[nr][nc] == FLAGGED then 
                        adjFlags = adjFlags + 1 
                    end
                end
            end
        end
    end

    if adjFlags == n then
        for dr = -1, 1 do
            for dc = -1, 1 do
                if dr ~= 0 or dc ~= 0 then
                    local nr, nc = r + dr, c + dc
                    if nr >= 1 and nr <= ROWS and nc >= 1 and nc <= COLS then
                        if cellState[nr][nc] == HIDDEN then
                            RevealCell(nr, nc)
                        end
                    end
                end
            end
        end
    end
end

local function ToggleFlag(r, c)
    if not gameActive then return end
    if cellState[r][c] == REVEALED then return end

    if cellState[r][c] == FLAGGED then
        cellState[r][c] = HIDDEN
        flagCount = flagCount - 1
    elseif cellState[r][c] == HIDDEN then
        cellState[r][c] = FLAGGED
        flagCount = flagCount + 1
    end
    UpdateCell(r, c)
    UpdateHUD()
end

-- ============================================================
-- Game over / win
-- ============================================================
GameOver = function()
    gameActive = false
    if timerTicker then timerTicker:Cancel(); timerTicker = nil end

    -- Reveal all mines
    for r = 1, ROWS do
        for c = 1, COLS do
            if cellMine[r][c] then
                cellState[r][c] = REVEALED
                UpdateCell(r, c)
            end
        end
    end

    if gameOverFrame then
        gameOverFrame:Show()
        gameOverFrame.titleText:SetText("|cFFFF2020BOOM!|r")
        local elapsed = startTime and math_floor(GetTime() - startTime) or 0
        gameOverFrame.scoreText:SetText(
            string.format("Time: %ds", elapsed))
    end
end

GameWin = function()
    gameActive = false
    if timerTicker then timerTicker:Cancel(); timerTicker = nil end

    local elapsed = startTime and math_floor(GetTime() - startTime) or 0

    -- Save best time
    local key = "bestTime_" .. currentDiff
    local db = UIThingsDB.games.bombs
    if not db[key] or elapsed < db[key] then
        db[key] = elapsed
    end

    -- Flag remaining mines
    for r = 1, ROWS do
        for c = 1, COLS do
            if cellMine[r][c] and cellState[r][c] ~= FLAGGED then
                cellState[r][c] = FLAGGED
                UpdateCell(r, c)
            end
        end
    end
    flagCount = MINES
    UpdateHUD()

    if gameOverFrame then
        gameOverFrame:Show()
        gameOverFrame.titleText:SetText("|cFFFFD100CLEARED!|r")
        local bestStr = db[key] and ("\nBest: " .. db[key] .. "s") or ""
        gameOverFrame.scoreText:SetText(
            string.format("Time: %ds%s", elapsed, bestStr))
    end
end

-- ============================================================
-- Start game
-- ============================================================
StartGame = function()
    if InCombatLockdown() then return end

    local diff = DIFFICULTY[currentDiff]
    COLS  = diff.cols
    ROWS  = diff.rows
    MINES = diff.mines

    cellState = {}
    cellMine  = {}
    cellCount = {}
    for r = 1, ROWS do
        cellState[r] = {}
        cellMine[r]  = {}
        cellCount[r] = {}
        for c = 1, COLS do
            cellState[r][c] = HIDDEN
            cellMine[r][c]  = false
            cellCount[r][c] = 0
        end
    end

    flagCount     = 0
    revealedCount = 0
    firstClick    = true
    startTime     = nil
    gameActive    = true

    if timerText then timerText:SetText("Time\n0") end
    if gameOverFrame then gameOverFrame:Hide() end
    if timerTicker then timerTicker:Cancel(); timerTicker = nil end

    ResizeBoard()
    UpdateHUD()
end

-- ============================================================
-- Board cell builder / pooler
-- ============================================================
local function GetCellButton(parent, r, c)
    local index = (r - 1) * COLS + c
    local f
    
    if index <= poolCount then
        f = cellPool[index]
    else
        local size = CELL
        f = CreateFrame("Button", nil, parent)
        
        f.border = f:CreateTexture(nil, "BACKGROUND")
        f.border:SetAllPoints()
        f.border:SetColorTexture(0.18, 0.18, 0.22, 1)

        f.tex = f:CreateTexture(nil, "ARTWORK")
        f.tex:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        f.tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
        f.tex:SetColorTexture(0.25, 0.25, 0.30, 1)

        f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        f.label:SetPoint("CENTER")
        f.label:SetText("")

        f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        f:SetScript("OnClick", function(self, button)
            local myRow = self.row
            local myCol = self.col
            if button == "LeftButton" then
                if cellState[myRow][myCol] == REVEALED then
                    ChordReveal(myRow, myCol)
                else
                    RevealCell(myRow, myCol)
                end
            elseif button == "RightButton" then
                ToggleFlag(myRow, myCol)
            end
        end)
        
        poolCount = poolCount + 1
        cellPool[poolCount] = f
    end

    f:SetSize(CELL - 1, CELL - 1)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", (c - 1) * CELL, -(r - 1) * CELL)
    f.row = r
    f.col = c
    f:Show()
    return f
end

-- ============================================================
-- Resize / rebuild board for current difficulty
-- ============================================================
ResizeBoard = function()
    if not gameFrame then return end

    -- Hide all pooled cells
    for i = 1, poolCount do
        cellPool[i]:Hide()
    end

    local SIDE_W = 100
    local BTN_H  = 26
    local BTN_GAP = 4
    local boardW = COLS * CELL
    local boardH = ROWS * CELL
    local totalW = boardW + PADDING * 3 + SIDE_W
    -- Height must fit both the board and the side panel (info labels + buttons)
    local sideNeeded = 30 + PADDING + 80 + 20 + 2 * (BTN_H + BTN_GAP) + PADDING  -- title bar + info + buttons
    local totalH = math_max(boardH + PADDING * 2 + 30, sideNeeded)

    gameFrame:SetSize(totalW, totalH)

    boardFrame:SetSize(boardW, boardH)

    -- Build/Retrieve cells
    cells = {}
    for r = 1, ROWS do
        cells[r] = {}
        for c = 1, COLS do
            cells[r][c] = GetCellButton(boardFrame, r, c)
            UpdateCell(r, c)
        end
    end

    -- Reposition side elements
    local sideX = boardW + PADDING * 2
    local sideTopY = PADDING + 30

    if minesText then
        minesText:ClearAllPoints()
        minesText:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", sideX, -sideTopY)
    end
    if timerText then
        timerText:ClearAllPoints()
        timerText:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", sideX, -(sideTopY + 40))
    end
    if diffText then
        diffText:ClearAllPoints()
        diffText:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", sideX, -(sideTopY + 80))
    end

    -- Reposition buttons
    if newGameBtn then
        newGameBtn:ClearAllPoints()
        newGameBtn:SetPoint("BOTTOMLEFT", gameFrame, "BOTTOMLEFT", sideX, PADDING + BTN_H + BTN_GAP)
    end
    if diffBtn then
        diffBtn:ClearAllPoints()
        diffBtn:SetPoint("BOTTOMLEFT", gameFrame, "BOTTOMLEFT", sideX, PADDING)
    end

    -- Reposition game over overlay
    if gameOverFrame then
        gameOverFrame:ClearAllPoints()
        gameOverFrame:SetAllPoints(boardFrame)
    end
end

-- ============================================================
-- Frame construction
-- ============================================================
BuildUI = function()
    local diff = DIFFICULTY[currentDiff]
    local boardW = diff.cols * CELL
    local boardH = diff.rows * CELL
    local SIDE_W = 100
    local totalW = boardW + PADDING * 3 + SIDE_W
    local totalH = boardH + PADDING * 2 + 30

    gameFrame = CreateFrame("Frame", "LunaUITweaks_BombsGame", UIParent)
    gameFrame:SetSize(totalW, totalH)
    gameFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    gameFrame:SetFrameStrata("DIALOG")
    gameFrame:SetMovable(true)
    gameFrame:SetClampedToScreen(true)
    gameFrame:RegisterForDrag("LeftButton")
    gameFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    gameFrame:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)
    gameFrame:Hide()

    -- Background
    local bg = gameFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.06, 0.08, 0.97)

    -- Border
    local border = gameFrame:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT",     gameFrame, "TOPLEFT",     0, 0)
    border:SetPoint("BOTTOMRIGHT", gameFrame, "BOTTOMRIGHT", 0, 0)
    border:SetColorTexture(0.3, 0.3, 0.35, 1)

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
    titleBarBg:SetColorTexture(0.12, 0.12, 0.16, 1)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    title:SetText("|cFFFF4444Bombs|r  |cFF888888drag title to move|r")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, gameFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", gameFrame, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function()
        gameFrame:Hide()
        gameActive = false
        if timerTicker then timerTicker:Cancel(); timerTicker = nil end
    end)

    -- ── Board frame ──────────────────────────────────────────
    boardFrame = CreateFrame("Frame", nil, gameFrame)
    boardFrame:SetSize(boardW, boardH)
    boardFrame:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", PADDING, -(PADDING + 30))

    local boardBg = boardFrame:CreateTexture(nil, "BACKGROUND")
    boardBg:SetAllPoints()
    boardBg:SetColorTexture(0.05, 0.05, 0.07, 1)

    -- ── Side panel ───────────────────────────────────────────
    local sideX    = boardW + PADDING * 2
    local sideTopY = PADDING + 30

    minesText = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    minesText:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", sideX, -sideTopY)
    minesText:SetJustifyH("LEFT")
    minesText:SetText("Mines\n0")

    timerText = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    timerText:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", sideX, -(sideTopY + 40))
    timerText:SetJustifyH("LEFT")
    timerText:SetText("Time\n0")

    diffText = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    diffText:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", sideX, -(sideTopY + 80))
    diffText:SetJustifyH("LEFT")
    diffText:SetText(currentDiff)

    -- ── Control buttons ──────────────────────────────────────
    local BTN_W   = SIDE_W - 4
    local BTN_H   = 26
    local BTN_GAP = 4
    local BOTTOM_PAD = 8

    local function MakeBtn(label, row, onClick)
        local btn = CreateFrame("Button", nil, gameFrame, "UIPanelButtonTemplate")
        btn:SetSize(BTN_W, BTN_H)
        local by = BOTTOM_PAD + (row - 1) * (BTN_H + BTN_GAP)
        btn:SetPoint("BOTTOMLEFT", gameFrame, "BOTTOMLEFT", sideX, by)
        btn:SetText(label)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    newGameBtn = MakeBtn("New Game", 1, StartGame)

    -- Difficulty button with context menu
    diffBtn = MakeBtn(currentDiff, 2, nil)
    diffBtn:SetScript("OnClick", function(self)
        MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
            for _, name in ipairs(DIFF_ORDER) do
                local d = DIFFICULTY[name]
                local label = string.format("%s (%dx%d, %d mines)", name, d.cols, d.rows, d.mines)
                rootDescription:CreateButton(label, function()
                    currentDiff = name
                    diffBtn:SetText(name)
                    StartGame()
                end)
            end
        end)
    end)

    -- ── Game Over overlay ────────────────────────────────────
    gameOverFrame = CreateFrame("Frame", nil, boardFrame)
    gameOverFrame:SetAllPoints()
    gameOverFrame:SetFrameLevel(boardFrame:GetFrameLevel() + 10)

    local goBg = gameOverFrame:CreateTexture(nil, "ARTWORK")
    goBg:SetAllPoints()
    goBg:SetColorTexture(0, 0, 0, 0.7)

    gameOverFrame.titleText = gameOverFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    gameOverFrame.titleText:SetPoint("CENTER", gameOverFrame, "CENTER", 0, 30)

    gameOverFrame.scoreText = gameOverFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    gameOverFrame.scoreText:SetPoint("CENTER", gameOverFrame, "CENTER", 0, -5)
    gameOverFrame.scoreText:SetJustifyH("CENTER")

    local goBtn = CreateFrame("Button", nil, gameOverFrame, "UIPanelButtonTemplate")
    goBtn:SetSize(100, 26)
    goBtn:SetPoint("CENTER", gameOverFrame, "CENTER", 0, -40)
    goBtn:SetText("Play Again")
    goBtn:SetScript("OnClick", StartGame)

    gameOverFrame:Hide()

    -- Pause overlay (shown when paused due to combat)
    local pauseOverlay = CreateFrame("Frame", nil, boardFrame)
    pauseOverlay:SetAllPoints()
    pauseOverlay:SetFrameLevel(boardFrame:GetFrameLevel() + 20)
    local pauseOvBg = pauseOverlay:CreateTexture(nil, "ARTWORK")
    pauseOvBg:SetAllPoints()
    pauseOvBg:SetColorTexture(0, 0, 0, 0.7)
    local pauseOvText = pauseOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    pauseOvText:SetPoint("CENTER", pauseOverlay, "CENTER", 0, 0)
    pauseOvText:SetText("|cFFFFD100PAUSED|r")
    pauseOverlay:Hide()
    gameFrame.pauseOverlay = pauseOverlay
end

-- Combat handling
addonTable.EventBus.Register("PLAYER_REGEN_DISABLED", function()
    if not (gameFrame and gameFrame:IsShown()) then return end
    if UIThingsDB.games.closeInCombat then
        gameFrame:Hide()
        gameActive = false
        if timerTicker then timerTicker:Cancel(); timerTicker = nil end
    else
        boardFrame:EnableMouse(false)
        if gameFrame.pauseOverlay then gameFrame.pauseOverlay:Show() end
    end
end)

addonTable.EventBus.Register("PLAYER_REGEN_ENABLED", function()
    if not (gameFrame and gameFrame:IsShown()) then return end
    boardFrame:EnableMouse(true)
    if gameFrame.pauseOverlay then gameFrame.pauseOverlay:Hide() end
end)

-- ============================================================
-- Public API
-- ============================================================
function addonTable.Bombs.CloseGame()
    if gameFrame and gameFrame:IsShown() then
        gameFrame:Hide()
        gameActive = false
        if timerTicker then timerTicker:Cancel(); timerTicker = nil end
    end
end

function addonTable.Bombs.ShowGame()
    if not gameFrame then
        BuildUI()
    end
    if gameFrame:IsShown() then
        gameFrame:Hide()
        gameActive = false
        if timerTicker then timerTicker:Cancel(); timerTicker = nil end
    else
        boardFrame:EnableMouse(true)
        if gameFrame.pauseOverlay then gameFrame.pauseOverlay:Hide() end
        gameFrame:Show()
        if not gameActive then
            StartGame()
        end
    end
end
