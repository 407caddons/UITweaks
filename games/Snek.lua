local addonName, addonTable = ...
addonTable.Snek = {}

-- ============================================================
-- Constants
-- ============================================================
local COLS      = 20
local ROWS      = 20
local CELL      = 22   -- px per cell (includes 1px gap)
local BOARD_W   = COLS * CELL
local BOARD_H   = ROWS * CELL
local PADDING   = 8

-- Tick speeds (seconds per move)
local BASE_TICK = 0.18
local MIN_TICK  = 0.07

-- Score per food eaten (multiplied by current length)
local FOOD_SCORE = 10

-- ============================================================
-- State
-- ============================================================
local gameFrame
local boardFrame
local cells        -- cells[row][col] = frame with .tex

local scoreText
local highScoreText
local lengthText
local gameOverFrame
local pauseText

-- Snake body: map of index to {r, c} with headIdx and tailIdx limits
local snake
local headIdx, tailIdx
local snakeLen
local occupied = {}
for r = 1, ROWS do occupied[r] = {} end

-- Direction of next move
local dirR, dirC
-- Queued directions (set by input, applied on next ticks)
local inputQueue = {}
-- Food position
local foodR, foodC
-- Game state
local score, highScore
local gameActive, gamePaused
local tickTimer

-- Colors
local EMPTY_COLOR  = {0.10, 0.10, 0.12}
local BORDER_COLOR = {0.25, 0.25, 0.28}
local SNAKE_HEAD   = {0.20, 1.00, 0.30}
local SNAKE_BODY   = {0.10, 0.65, 0.20}
local FOOD_COLOR   = {1.00, 0.20, 0.20}
local GRID_COLOR   = {0.13, 0.13, 0.15}

-- ============================================================
-- Forward declarations
-- ============================================================
local StartGame, GameOver, Tick, BuildUI

-- ============================================================
-- Cell frame builder
-- ============================================================
local function BuildCellFrame(parent, size, x, y)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size - 1, size - 1)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    f.border = f:CreateTexture(nil, "BACKGROUND")
    f.border:SetAllPoints()
    f.border:SetColorTexture(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3])
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    f.tex:SetColorTexture(EMPTY_COLOR[1], EMPTY_COLOR[2], EMPTY_COLOR[3])
    return f
end

-- ============================================================
-- Rendering
-- ============================================================
local function SetCell(row, col, r, g, b)
    if row >= 1 and row <= ROWS and col >= 1 and col <= COLS then
        local cell = cells[row][col]
        local colStr = r..","..g..","..b
        if cell.currentColor ~= colStr then
            cell.currentColor = colStr
            cell.tex:SetColorTexture(r, g, b)
        end
    end
end

local function RenderBoard() -- Used for full redraws (e.g. game start)
    -- Clear board
    for row = 1, ROWS do
        for col = 1, COLS do
            SetCell(row, col, GRID_COLOR[1], GRID_COLOR[2], GRID_COLOR[3])
        end
    end

    -- Draw food
    if foodR then
        SetCell(foodR, foodC, FOOD_COLOR[1], FOOD_COLOR[2], FOOD_COLOR[3])
    end

    -- Draw snake body
    if snake then
        for i = tailIdx, headIdx - 1 do
            local seg = snake[i]
            SetCell(seg.r, seg.c, SNAKE_BODY[1], SNAKE_BODY[2], SNAKE_BODY[3])
        end

        -- Draw head
        if snake[headIdx] then
            SetCell(snake[headIdx].r, snake[headIdx].c, SNAKE_HEAD[1], SNAKE_HEAD[2], SNAKE_HEAD[3])
        end
    end
end

local function UpdateHUD()
    if scoreText     then scoreText:SetText("Score\n" .. score) end
    if highScoreText then highScoreText:SetText("Best\n" .. highScore) end
    if lengthText    then lengthText:SetText("Length\n" .. (snakeLen or 0)) end
end

-- ============================================================
-- Food spawning
-- ============================================================
local function SpawnFood()
    -- Build a list of empty cells
    local empty = {}
    for r = 1, ROWS do
        for c = 1, COLS do
            if not occupied[r][c] then
                empty[#empty + 1] = {r = r, c = c}
            end
        end
    end

    if #empty == 0 then
        -- Board is full — player wins (treat as game over with win message)
        GameOver(true)
        return
    end

    local pick = empty[math.random(#empty)]
    foodR, foodC = pick.r, pick.c
    SetCell(foodR, foodC, FOOD_COLOR[1], FOOD_COLOR[2], FOOD_COLOR[3])
end

-- ============================================================
-- Tick speed
-- ============================================================
local function TickInterval()
    -- Speed increases with snake length: every 5 segments faster
    local speedTier = math.floor((snakeLen - 3) / 5)
    local interval  = BASE_TICK - speedTier * 0.01
    return math.max(interval, MIN_TICK)
end

local function RestartTick()
    if not gameActive then return end
    if tickTimer then tickTimer:Cancel() end
    tickTimer = C_Timer.NewTicker(TickInterval(), Tick)
end

-- ============================================================
-- Game tick
-- ============================================================
Tick = function()
    if not gameActive or gamePaused then return end

    -- Apply queued direction
    if #inputQueue > 0 then
        local nextDir = table.remove(inputQueue, 1)
        dirR, dirC = nextDir.r, nextDir.c
    end

    local head = snake[headIdx]
    local newR  = head.r + dirR
    local newC  = head.c + dirC

    -- Wall collision
    if newR < 1 or newR > ROWS or newC < 1 or newC > COLS then
        GameOver(false)
        return
    end

    local eating = (newR == foodR and newC == foodC)

    -- Self collision 
    if occupied[newR][newC] then
        local tail = snake[tailIdx]
        if eating or not (newR == tail.r and newC == tail.c) then
            GameOver(false)
            return
        end
    end

    local oldTail = nil
    if not eating then
        oldTail = snake[tailIdx]
        occupied[oldTail.r][oldTail.c] = false
        snake[tailIdx] = nil
        tailIdx = tailIdx + 1
    end

    local prevHead = snake[headIdx]
    headIdx = headIdx + 1
    local newHead = {r = newR, c = newC}
    snake[headIdx] = newHead
    occupied[newR][newC] = true

    -- Draw state delta for performance
    if oldTail then
        SetCell(oldTail.r, oldTail.c, GRID_COLOR[1], GRID_COLOR[2], GRID_COLOR[3])
    end
    if prevHead then
        SetCell(prevHead.r, prevHead.c, SNAKE_BODY[1], SNAKE_BODY[2], SNAKE_BODY[3])
    end
    SetCell(newHead.r, newHead.c, SNAKE_HEAD[1], SNAKE_HEAD[2], SNAKE_HEAD[3])

    if eating then
        snakeLen = snakeLen + 1
        score = score + FOOD_SCORE * snakeLen
        if score > highScore then
            highScore = score
            UIThingsDB.games.snek.highScore = highScore
        end
        SpawnFood()
        RestartTick()
    end

    UpdateHUD()
end

-- ============================================================
-- Game over
-- ============================================================
GameOver = function(win)
    if tickTimer then tickTimer:Cancel(); tickTimer = nil end
    UIThingsDB.games.snek.highScore = highScore
    gameActive = false

    if gameOverFrame then
        gameOverFrame:Show()
        if gameOverFrame.titleText then
            if win then
                gameOverFrame.titleText:SetText("|cFFFFD100YOU WIN!|r")
            else
                gameOverFrame.titleText:SetText("|cFFFF2020GAME OVER|r")
            end
        end
        gameOverFrame.scoreText:SetText(
            string.format("Score: %d\nBest: %d", score, highScore))
    end
end

-- ============================================================
-- Start / Restart
-- ============================================================
StartGame = function()
    if InCombatLockdown() then return end
    score    = 0
    highScore = UIThingsDB.games and UIThingsDB.games.snek and UIThingsDB.games.snek.highScore or 0
    foodR, foodC = nil, nil

    for r = 1, ROWS do
        for c = 1, COLS do occupied[r][c] = false end
    end

    -- Start snake in the middle, 3 segments long, moving right
    local midR = math.floor(ROWS / 2) + 1
    local midC = math.floor(COLS / 2)
    snake = {
        [1] = {r = midR, c = midC - 2},
        [2] = {r = midR, c = midC - 1},
        [3] = {r = midR, c = midC},
    }
    headIdx = 3
    tailIdx = 1
    snakeLen = 3
    occupied[midR][midC] = true
    occupied[midR][midC - 1] = true
    occupied[midR][midC - 2] = true

    dirR, dirC = 0, 1   -- moving right
    wipe(inputQueue)
    table.insert(inputQueue, {r = 0, c = 1})

    gameActive = true
    gamePaused = false

    if gameOverFrame then gameOverFrame:Hide() end
    if pauseText     then pauseText:Hide() end

    RenderBoard()
    SpawnFood()
    UpdateHUD()

    if tickTimer then tickTimer:Cancel() end
    tickTimer = C_Timer.NewTicker(TickInterval(), Tick)
end

-- ============================================================
-- Input actions
-- ============================================================
local function QueueDir(r, c)
    if not gameActive or gamePaused then return end
    
    local lastDirR = dirR
    local lastDirC = dirC
    if #inputQueue > 0 then
        local last = inputQueue[#inputQueue]
        lastDirR, lastDirC = last.r, last.c
    end
    
    -- Prevent reversing or duplicates
    if lastDirR == -r and r ~= 0 then return end
    if lastDirC == -c and c ~= 0 then return end
    if lastDirR == r and lastDirC == c then return end
    
    if #inputQueue < 3 then
        table.insert(inputQueue, {r = r, c = c})
    end
end

local function MoveUp()
    QueueDir(-1, 0)
end

local function MoveDown()
    QueueDir(1, 0)
end

local function MoveLeft()
    QueueDir(0, -1)
end

local function MoveRight()
    QueueDir(0, 1)
end

local function TogglePause()
    if not gameActive then return end
    gamePaused = not gamePaused
    if pauseText then
        pauseText:SetShown(gamePaused)
    end
end

-- ============================================================
-- Frame construction
-- ============================================================
local SIDE_W = 120
local totalW  = BOARD_W + PADDING * 3 + SIDE_W
local totalH  = BOARD_H + PADDING * 2 + 30

BuildUI = function()
    gameFrame = CreateFrame("Frame", "LunaUITweaks_SnekGame", UIParent, "BackdropTemplate")
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
    title:SetText("|cFF20FF40Snek|r  |cFF888888drag title to move|r")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, gameFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", gameFrame, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function()
        gameFrame:Hide()
        if tickTimer then tickTimer:Cancel(); tickTimer = nil end
        gameActive = false
    end)

    -- ── Board frame ──────────────────────────────────────────
    boardFrame = CreateFrame("Frame", nil, gameFrame)
    boardFrame:SetSize(BOARD_W, BOARD_H)
    boardFrame:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", PADDING, -(PADDING + 30))

    local boardBg = boardFrame:CreateTexture(nil, "BACKGROUND")
    boardBg:SetAllPoints()
    boardBg:SetColorTexture(0.05, 0.05, 0.07, 1)

    -- Board cells
    cells = {}
    for row = 1, ROWS do
        cells[row] = {}
        for col = 1, COLS do
            cells[row][col] = BuildCellFrame(
                boardFrame, CELL,
                (col - 1) * CELL,
                (row - 1) * CELL
            )
        end
    end

    -- ── Side panel ───────────────────────────────────────────
    local sideX    = BOARD_W + PADDING * 2
    local sideTopY = PADDING + 30

    scoreText = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scoreText:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", sideX, -sideTopY)
    scoreText:SetJustifyH("LEFT")
    scoreText:SetText("Score\n0")

    highScoreText = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    highScoreText:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", sideX, -(sideTopY + 40))
    highScoreText:SetJustifyH("LEFT")
    highScoreText:SetText("Best\n0")

    lengthText = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lengthText:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", sideX, -(sideTopY + 80))
    lengthText:SetJustifyH("LEFT")
    lengthText:SetText("Length\n0")

    -- ── Control buttons ──────────────────────────────────────
    local BTN_W  = SIDE_W - 4
    local BTN_H  = 26
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

    local bindHint = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bindHint:SetPoint("BOTTOMLEFT", gameFrame, "BOTTOMLEFT", sideX, BOTTOM_PAD + 2 * (BTN_H + BTN_GAP) + 6)
    bindHint:SetTextColor(0.5, 0.5, 0.5)
    bindHint:SetWidth(BTN_W)
    bindHint:SetWordWrap(true)
    bindHint:SetText("Bindable in\nKey Bindings")

    MakeBtn("Pause",    1, TogglePause)
    MakeBtn("New Game", 2, StartGame)

    -- Pause overlay
    pauseText = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    pauseText:SetPoint("CENTER", boardFrame, "CENTER", 0, 0)
    pauseText:SetText("|cFFFFD100PAUSED|r")
    pauseText:Hide()

    -- ── Game Over overlay ────────────────────────────────────
    gameOverFrame = CreateFrame("Frame", nil, boardFrame)
    gameOverFrame:SetAllPoints()

    local goBg = gameOverFrame:CreateTexture(nil, "OVERLAY")
    goBg:SetAllPoints()
    goBg:SetColorTexture(0, 0, 0, 0.7)

    gameOverFrame.titleText = gameOverFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    gameOverFrame.titleText:SetPoint("CENTER", gameOverFrame, "CENTER", 0, 30)
    gameOverFrame.titleText:SetText("|cFFFF2020GAME OVER|r")

    gameOverFrame.scoreText = gameOverFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    gameOverFrame.scoreText:SetPoint("CENTER", gameOverFrame, "CENTER", 0, -5)
    gameOverFrame.scoreText:SetJustifyH("CENTER")

    local goBtn = CreateFrame("Button", nil, gameOverFrame, "UIPanelButtonTemplate")
    goBtn:SetSize(100, 26)
    goBtn:SetPoint("CENTER", gameOverFrame, "CENTER", 0, -40)
    goBtn:SetText("Play Again")
    goBtn:SetScript("OnClick", StartGame)

    gameOverFrame:Hide()
end

-- Close the game when combat starts
addonTable.EventBus.Register("PLAYER_REGEN_DISABLED", function()
    if gameFrame and gameFrame:IsShown() then
        gameFrame:Hide()
        if tickTimer then tickTimer:Cancel(); tickTimer = nil end
        gameActive = false
    end
end)

-- ============================================================
-- Public API
-- ============================================================
function addonTable.Snek.ShowGame()
    if not gameFrame then
        BuildUI()
    end
    if gameFrame:IsShown() then
        gameFrame:Hide()
        if tickTimer then tickTimer:Cancel(); tickTimer = nil end
        gameActive = false
    else
        gameFrame:Show()
        if not gameActive then
            StartGame()
        end
    end
end

-- Global keybinding handlers — shared with Block Game bindings
-- Only act when the Snek window is open (and Block Game is not, to avoid conflicts)
local function SnekIsOpen()
    return gameFrame and gameFrame:IsShown()
end

-- These wrap the existing LunaUITweaks_Game_* globals, extending them so that
-- the same key works for whichever game is open.
local _origLeft     = LunaUITweaks_Game_Left
local _origRight    = LunaUITweaks_Game_Right
local _origRotateCW = LunaUITweaks_Game_RotateCW
local _origRotateCCW= LunaUITweaks_Game_RotateCCW
local _origPause    = LunaUITweaks_Game_Pause

function LunaUITweaks_Game_Left()
    if SnekIsOpen() then MoveLeft()
    elseif _origLeft then _origLeft() end
end

function LunaUITweaks_Game_Right()
    if SnekIsOpen() then MoveRight()
    elseif _origRight then _origRight() end
end

function LunaUITweaks_Game_RotateCW()
    if SnekIsOpen() then MoveUp()
    elseif _origRotateCW then _origRotateCW() end
end

function LunaUITweaks_Game_RotateCCW()
    if SnekIsOpen() then MoveDown()
    elseif _origRotateCCW then _origRotateCCW() end
end

function LunaUITweaks_Game_Pause()
    if SnekIsOpen() then TogglePause()
    elseif _origPause then _origPause() end
end
