local addonName, addonTable = ...
addonTable.Game2048 = {}

-- ============================================================
-- Constants
-- ============================================================
local GRID      = 4        -- 4x4 board
local CELL      = 80       -- px per cell
local GAP       = 6        -- px between cells
local PADDING   = 12
local BOARD_PX  = GRID * CELL + (GRID + 1) * GAP  -- total board pixel size

-- Tile colors by value — dark theme matching other Luna games
local TILE_COLORS = {
    [2]    = { bg = {0.15, 0.28, 0.38}, fg = {0.80, 0.90, 1.00} },
    [4]    = { bg = {0.10, 0.38, 0.45}, fg = {0.85, 1.00, 1.00} },
    [8]    = { bg = {0.10, 0.50, 0.35}, fg = {1.00, 1.00, 1.00} },
    [16]   = { bg = {0.15, 0.60, 0.25}, fg = {1.00, 1.00, 1.00} },
    [32]   = { bg = {0.50, 0.60, 0.10}, fg = {1.00, 1.00, 1.00} },
    [64]   = { bg = {0.70, 0.50, 0.08}, fg = {1.00, 1.00, 1.00} },
    [128]  = { bg = {0.75, 0.35, 0.08}, fg = {1.00, 1.00, 1.00} },
    [256]  = { bg = {0.75, 0.20, 0.10}, fg = {1.00, 1.00, 1.00} },
    [512]  = { bg = {0.70, 0.10, 0.30}, fg = {1.00, 1.00, 1.00} },
    [1024] = { bg = {0.55, 0.10, 0.55}, fg = {1.00, 1.00, 1.00} },
    [2048] = { bg = {0.85, 0.75, 0.10}, fg = {0.10, 0.08, 0.05} },
}
local DEFAULT_TILE = { bg = {0.18, 0.18, 0.22}, fg = {1, 1, 1} }

-- ============================================================
-- State
-- ============================================================
local gameFrame
local boardFrame
local tileFrames   -- tileFrames[r][c] — pre-built tile frames
local board        -- board[r][c] = value (0 = empty)
local score        = 0
local bestScore    = 0
local gameOver     = false
local gameWon      = false
local wonContinue  = false  -- true if player chose to keep going past 2048
local combatPaused = false  -- true when paused due to combat (not closeInCombat)
local scoreText, bestText
local gameOverFrame
local newTileR, newTileC  -- position of the most recently spawned tile

-- ============================================================
-- Forward declarations
-- ============================================================
local StartGame, RenderBoard, SpawnTile, CheckGameOver

-- ============================================================
-- Board logic
-- ============================================================
local function GetHighScore()
    UIThingsDB = UIThingsDB or {}
    UIThingsDB.games = UIThingsDB.games or {}
    UIThingsDB.games.game2048 = UIThingsDB.games.game2048 or {}
    return UIThingsDB.games.game2048.highScore or 0
end

local function SaveHighScore(score)
    UIThingsDB = UIThingsDB or {}
    UIThingsDB.games = UIThingsDB.games or {}
    UIThingsDB.games.game2048 = UIThingsDB.games.game2048 or {}
    UIThingsDB.games.game2048.highScore = score
end

local function NewBoard()
    if not board then
        board = {}
        for r = 1, GRID do
            board[r] = {}
            for c = 1, GRID do
                board[r][c] = 0
            end
        end
    else
        for r = 1, GRID do
            for c = 1, GRID do
                board[r][c] = 0
            end
        end
    end
end

local emptyBuffer = {}
SpawnTile = function()
    local emptyCount = 0
    for r = 1, GRID do
        for c = 1, GRID do
            if board[r][c] == 0 then
                emptyCount = emptyCount + 1
                emptyBuffer[emptyCount] = (r - 1) * GRID + c
            end
        end
    end
    if emptyCount == 0 then return end
    local pick = emptyBuffer[math.random(emptyCount)]
    local pr = math.floor((pick - 1) / GRID) + 1
    local pc = (pick - 1) % GRID + 1
    -- 90% chance of 2, 10% chance of 4
    board[pr][pc] = (math.random() < 0.9) and 2 or 4
    newTileR, newTileC = pr, pc
end

local lineBuffer = {0, 0, 0, 0}
local outBuffer = {0, 0, 0, 0}
local mergedBuffer = {false, false, false, false}

local function SlideLeft()
    local pts = 0
    for i = 1, GRID do 
        outBuffer[i] = 0
        mergedBuffer[i] = false 
    end

    -- Remove zeros
    local idx = 1
    for i = 1, GRID do
        if lineBuffer[i] ~= 0 then 
            outBuffer[idx] = lineBuffer[i]
            idx = idx + 1
        end
    end

    -- Merge adjacent equal tiles
    local i = 1
    while i < GRID do
        if outBuffer[i] ~= 0 and outBuffer[i] == outBuffer[i + 1] and not mergedBuffer[i] then
            local val = outBuffer[i] * 2
            pts = pts + val
            outBuffer[i] = val
            for j = i + 1, GRID - 1 do
                outBuffer[j] = outBuffer[j + 1]
            end
            outBuffer[GRID] = 0
            mergedBuffer[i] = true
        end
        i = i + 1
    end

    return pts
end

-- Move in direction: "left","right","up","down"
-- Returns true if any tile moved
local function Move(dir)
    local moved = false
    local pts   = 0

    if dir == "left" then
        for r = 1, GRID do
            for c = 1, GRID do lineBuffer[c] = board[r][c] end
            local p = SlideLeft()
            pts = pts + p
            for c = 1, GRID do
                if board[r][c] ~= outBuffer[c] then moved = true end
                board[r][c] = outBuffer[c]
            end
        end

    elseif dir == "right" then
        for r = 1, GRID do
            for c = 1, GRID do lineBuffer[c] = board[r][GRID - c + 1] end
            local p = SlideLeft()
            pts = pts + p
            for c = 1, GRID do
                if board[r][GRID - c + 1] ~= outBuffer[c] then moved = true end
                board[r][GRID - c + 1] = outBuffer[c]
            end
        end

    elseif dir == "up" then
        for c = 1, GRID do
            for r = 1, GRID do lineBuffer[r] = board[r][c] end
            local p = SlideLeft()
            pts = pts + p
            for r = 1, GRID do
                if board[r][c] ~= outBuffer[r] then moved = true end
                board[r][c] = outBuffer[r]
            end
        end

    elseif dir == "down" then
        for c = 1, GRID do
            for r = 1, GRID do lineBuffer[r] = board[GRID - r + 1][c] end
            local p = SlideLeft()
            pts = pts + p
            for r = 1, GRID do
                if board[GRID - r + 1][c] ~= outBuffer[r] then moved = true end
                board[GRID - r + 1][c] = outBuffer[r]
            end
        end
    end

    if moved then
        score = score + pts
        if score > bestScore then
            bestScore = score
            SaveHighScore(bestScore)
        end
    end

    return moved
end

CheckGameOver = function()
    -- Check for 2048 tile (win condition, only once)
    if not wonContinue then
        for r = 1, GRID do
            for c = 1, GRID do
                if board[r][c] == 2048 then
                    gameWon = true
                    return
                end
            end
        end
    end

    -- Check for any empty cell
    for r = 1, GRID do
        for c = 1, GRID do
            if board[r][c] == 0 then return end
        end
    end

    -- Check for any valid merge
    for r = 1, GRID do
        for c = 1, GRID do
            local v = board[r][c]
            if c < GRID and board[r][c + 1] == v then return end
            if r < GRID and board[r + 1][c] == v then return end
        end
    end

    gameOver = true
end

-- ============================================================
-- Rendering
-- ============================================================
RenderBoard = function()
    for r = 1, GRID do
        for c = 1, GRID do
            local f   = tileFrames[r][c]
            local val = board[r][c]
            local col = TILE_COLORS[val] or DEFAULT_TILE

            f.bg:SetColorTexture(col.bg[1], col.bg[2], col.bg[3], 1)

            if val == 0 then
                f.label:SetText("")
            else
                f.label:SetTextColor(col.fg[1], col.fg[2], col.fg[3])
                local font = val >= 1000 and "GameFontNormalLarge" or "GameFontNormalHuge"
                f.label:SetFontObject(font)
                f.label:SetText(tostring(val))
            end

            local showHL = (newTileR == r and newTileC == c and val ~= 0)
            f.hl.top:SetShown(showHL)
            f.hl.bot:SetShown(showHL)
            f.hl.lft:SetShown(showHL)
            f.hl.rgt:SetShown(showHL)
        end
    end

    if scoreText then scoreText:SetText("Score\n" .. score) end
    if bestText  then bestText:SetText("Best\n"  .. bestScore) end

    -- Show overlay if game ended
    if gameOverFrame then
        if gameWon and not wonContinue then
            gameOverFrame:Show()
            gameOverFrame.titleText:SetText("|cFFFFD100You Win!|r")
            gameOverFrame.scoreText:SetText("Score: " .. score)
            gameOverFrame.continueBtn:Show()
            gameOverFrame.newBtn:SetText("New Game")
        elseif gameOver then
            gameOverFrame:Show()
            gameOverFrame.titleText:SetText("|cFFFF2020Game Over|r")
            gameOverFrame.scoreText:SetText("Score: " .. score)
            gameOverFrame.continueBtn:Hide()
            gameOverFrame.newBtn:SetText("Try Again")
        else
            gameOverFrame:Hide()
        end
    end
end

-- ============================================================
-- Input handling
-- ============================================================
local function OnKey(dir)
    if combatPaused then return end
    if gameOver then return end
    if gameWon and not wonContinue then return end

    local moved = Move(dir)
    if moved then
        SpawnTile()
        CheckGameOver()
        RenderBoard()
    end
end

-- ============================================================
-- Start game
-- ============================================================
StartGame = function()
    score       = 0
    gameOver    = false
    gameWon     = false
    wonContinue = false
    combatPaused = false
    bestScore   = GetHighScore()
    if gameFrame and gameFrame.pauseOverlay then gameFrame.pauseOverlay:Hide() end

    newTileR, newTileC = nil, nil
    NewBoard()
    SpawnTile()
    SpawnTile()
    newTileR, newTileC = nil, nil  -- don't highlight on initial board
    CheckGameOver()
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
            local f = CreateFrame("Frame", nil, parent)
            f:SetSize(CELL, CELL)
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", TileX(c), TileY(r))

            f.bg = f:CreateTexture(nil, "BACKGROUND")
            f.bg:SetAllPoints()
            f.bg:SetColorTexture(0.18, 0.18, 0.22, 1)

            -- Border
            local B = 2  -- border thickness
            local br, bg2, bb = 0.08, 0.08, 0.10
            local top = f:CreateTexture(nil, "BORDER")
            top:SetColorTexture(br, bg2, bb, 1)
            top:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
            top:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
            top:SetHeight(B)

            local bot = f:CreateTexture(nil, "BORDER")
            bot:SetColorTexture(br, bg2, bb, 1)
            bot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
            bot:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
            bot:SetHeight(B)

            local lft = f:CreateTexture(nil, "BORDER")
            lft:SetColorTexture(br, bg2, bb, 1)
            lft:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
            lft:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
            lft:SetWidth(B)

            local rgt = f:CreateTexture(nil, "BORDER")
            rgt:SetColorTexture(br, bg2, bb, 1)
            rgt:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
            rgt:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
            rgt:SetWidth(B)

            -- New-tile highlight: 4 black edge strips (shown for one move only)
            local function MakeEdge(layer)
                local t = f:CreateTexture(nil, layer)
                t:SetColorTexture(0, 0, 0, 1)
                t:Hide()
                return t
            end
            local HB = 3  -- highlight thickness
            f.hl = {}
            f.hl.top = MakeEdge("OVERLAY")
            f.hl.top:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
            f.hl.top:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
            f.hl.top:SetHeight(HB)

            f.hl.bot = MakeEdge("OVERLAY")
            f.hl.bot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
            f.hl.bot:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
            f.hl.bot:SetHeight(HB)

            f.hl.lft = MakeEdge("OVERLAY")
            f.hl.lft:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
            f.hl.lft:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
            f.hl.lft:SetWidth(HB)

            f.hl.rgt = MakeEdge("OVERLAY")
            f.hl.rgt:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
            f.hl.rgt:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
            f.hl.rgt:SetWidth(HB)

            f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
            f.label:SetAllPoints()
            f.label:SetJustifyH("CENTER")
            f.label:SetJustifyV("MIDDLE")
            f.label:SetText("")

            tileFrames[r][c] = f
        end
    end
end

local function BuildUI()
    local HUD_H  = 60
    local BTN_W  = 90
    local BTN_H  = 26
    local totalW = BOARD_PX + PADDING * 2
    local totalH = BOARD_PX + PADDING * 2 + 30 + HUD_H

    gameFrame = CreateFrame("Frame", "LunaUITweaks_TilesGame", UIParent)
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
    titleBarBg:SetColorTexture(0.12, 0.12, 0.16, 1)

    local titleLabel = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleLabel:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    titleLabel:SetText("|cFFFFD100Tiles|r  |cFF888888drag title to move · arrow keys to play|r")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, gameFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", gameFrame, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() gameFrame:Hide() end)

    -- HUD: score + best + new game button
    local hudFrame = CreateFrame("Frame", nil, gameFrame)
    hudFrame:SetPoint("TOPLEFT",  gameFrame, "TOPLEFT",  PADDING, -30)
    hudFrame:SetPoint("TOPRIGHT", gameFrame, "TOPRIGHT", -PADDING, -30)
    hudFrame:SetHeight(HUD_H)

    local function MakeScoreBox(label, xOff)
        local box = CreateFrame("Frame", nil, hudFrame)
        box:SetSize(80, HUD_H - 8)
        box:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", xOff, -4)

        local boxBg = box:CreateTexture(nil, "BACKGROUND")
        boxBg:SetAllPoints()
        boxBg:SetColorTexture(0.12, 0.12, 0.18, 1)

        local boxBorder = box:CreateTexture(nil, "BORDER")
        boxBorder:SetAllPoints()
        boxBorder:SetColorTexture(0.25, 0.25, 0.32, 1)

        local fs = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetAllPoints()
        fs:SetJustifyH("CENTER")
        fs:SetJustifyV("MIDDLE")
        fs:SetText(label .. "\n0")
        return fs
    end

    scoreText = MakeScoreBox("Score", 0)
    bestText  = MakeScoreBox("Best",  88)

    local newBtn = CreateFrame("Button", nil, hudFrame, "UIPanelButtonTemplate")
    newBtn:SetSize(BTN_W, BTN_H)
    newBtn:SetPoint("RIGHT", hudFrame, "RIGHT", 0, 0)
    newBtn:SetText("New Game")
    newBtn:SetScript("OnClick", StartGame)

    -- Board frame
    boardFrame = CreateFrame("Frame", nil, gameFrame)
    boardFrame:SetSize(BOARD_PX, BOARD_PX)
    boardFrame:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", PADDING, -(30 + HUD_H + PADDING))

    local boardBg = boardFrame:CreateTexture(nil, "BACKGROUND")
    boardBg:SetAllPoints()
    boardBg:SetColorTexture(0.10, 0.10, 0.13, 1)

    BuildTiles(boardFrame)


    -- Game over / win overlay
    gameOverFrame = CreateFrame("Frame", nil, boardFrame)
    gameOverFrame:SetAllPoints()
    gameOverFrame:SetFrameLevel(boardFrame:GetFrameLevel() + 10)

    local goBg = gameOverFrame:CreateTexture(nil, "ARTWORK")
    goBg:SetAllPoints()
    goBg:SetColorTexture(0, 0, 0, 0.65)

    gameOverFrame.titleText = gameOverFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    gameOverFrame.titleText:SetPoint("CENTER", gameOverFrame, "CENTER", 0, 40)

    gameOverFrame.scoreText = gameOverFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    gameOverFrame.scoreText:SetPoint("CENTER", gameOverFrame, "CENTER", 0, 10)
    gameOverFrame.scoreText:SetJustifyH("CENTER")

    -- Continue button (only shown on win)
    gameOverFrame.continueBtn = CreateFrame("Button", nil, gameOverFrame, "UIPanelButtonTemplate")
    gameOverFrame.continueBtn:SetSize(110, 26)
    gameOverFrame.continueBtn:SetPoint("CENTER", gameOverFrame, "CENTER", -60, -30)
    gameOverFrame.continueBtn:SetText("Keep Going")
    gameOverFrame.continueBtn:SetScript("OnClick", function()
        wonContinue = true
        gameOverFrame:Hide()
        RenderBoard()
    end)

    gameOverFrame.newBtn = CreateFrame("Button", nil, gameOverFrame, "UIPanelButtonTemplate")
    gameOverFrame.newBtn:SetSize(90, 26)
    gameOverFrame.newBtn:SetPoint("CENTER", gameOverFrame, "CENTER", 60, -30)
    gameOverFrame.newBtn:SetText("New Game")
    gameOverFrame.newBtn:SetScript("OnClick", StartGame)

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

    -- Store reference for combat handlers
    gameFrame.pauseOverlay = pauseOverlay
end

-- Combat handling
addonTable.EventBus.Register("PLAYER_REGEN_DISABLED", function()
    if not (gameFrame and gameFrame:IsShown()) then return end
    if UIThingsDB.games.closeInCombat then
        gameFrame:Hide()
    else
        combatPaused = true
        if gameFrame.pauseOverlay then gameFrame.pauseOverlay:Show() end
    end
end)

addonTable.EventBus.Register("PLAYER_REGEN_ENABLED", function()
    if not (gameFrame and gameFrame:IsShown()) then return end
    combatPaused = false
    if gameFrame.pauseOverlay then gameFrame.pauseOverlay:Hide() end
end)

-- ============================================================
-- Public API
-- ============================================================
function addonTable.Game2048.CloseGame()
    if gameFrame and gameFrame:IsShown() then
        gameFrame:Hide()
    end
end

function addonTable.Game2048.ShowGame()
    if not gameFrame then
        BuildUI()
    end
    if gameFrame:IsShown() then
        addonTable.Game2048.CloseGame()
    else
        -- Close other keybind-sharing games first
        if addonTable.Snek then addonTable.Snek.CloseGame() end
        bestScore = GetHighScore()
        gameFrame:Show()
        if not board then
            StartGame()
        else
            RenderBoard()
        end
    end
end

-- Global keybinding handlers — extend existing globals so Tiles shares game binds
local function TilesIsOpen()
    return gameFrame and gameFrame:IsShown()
end

local _origLeft     = LunaUITweaks_Game_Left
local _origRight    = LunaUITweaks_Game_Right
local _origRotateCW = LunaUITweaks_Game_RotateCW
local _origRotateCCW= LunaUITweaks_Game_RotateCCW

function LunaUITweaks_Game_Left()
    if TilesIsOpen() then OnKey("left")
    elseif _origLeft then _origLeft() end
end

function LunaUITweaks_Game_Right()
    if TilesIsOpen() then OnKey("right")
    elseif _origRight then _origRight() end
end

function LunaUITweaks_Game_RotateCW()
    if TilesIsOpen() then OnKey("up")
    elseif _origRotateCW then _origRotateCW() end
end

function LunaUITweaks_Game_RotateCCW()
    if TilesIsOpen() then OnKey("down")
    elseif _origRotateCCW then _origRotateCCW() end
end
