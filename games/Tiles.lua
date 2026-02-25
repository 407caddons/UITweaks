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

-- Tile colors by value (power-of-two index)
local TILE_COLORS = {
    [2]    = { bg = {0.93, 0.89, 0.85}, fg = {0.47, 0.43, 0.40} },
    [4]    = { bg = {0.93, 0.88, 0.78}, fg = {0.47, 0.43, 0.40} },
    [8]    = { bg = {0.95, 0.69, 0.47}, fg = {1.00, 1.00, 1.00} },
    [16]   = { bg = {0.96, 0.58, 0.39}, fg = {1.00, 1.00, 1.00} },
    [32]   = { bg = {0.96, 0.49, 0.37}, fg = {1.00, 1.00, 1.00} },
    [64]   = { bg = {0.96, 0.37, 0.23}, fg = {1.00, 1.00, 1.00} },
    [128]  = { bg = {0.93, 0.81, 0.45}, fg = {1.00, 1.00, 1.00} },
    [256]  = { bg = {0.93, 0.80, 0.38}, fg = {1.00, 1.00, 1.00} },
    [512]  = { bg = {0.93, 0.78, 0.31}, fg = {1.00, 1.00, 1.00} },
    [1024] = { bg = {0.93, 0.77, 0.25}, fg = {1.00, 1.00, 1.00} },
    [2048] = { bg = {0.93, 0.76, 0.18}, fg = {1.00, 1.00, 1.00} },
}
local DEFAULT_TILE = { bg = {0.80, 0.75, 0.70}, fg = {1, 1, 1} }

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
local function NewBoard()
    board = {}
    for r = 1, GRID do
        board[r] = {}
        for c = 1, GRID do
            board[r][c] = 0
        end
    end
end

SpawnTile = function()
    local empty = {}
    for r = 1, GRID do
        for c = 1, GRID do
            if board[r][c] == 0 then
                empty[#empty + 1] = { r = r, c = c }
            end
        end
    end
    if #empty == 0 then return end
    local pick = empty[math.random(#empty)]
    -- 90% chance of 2, 10% chance of 4
    board[pick.r][pick.c] = (math.random() < 0.9) and 2 or 4
    newTileR, newTileC = pick.r, pick.c
end

-- Slide a single row/column (given as array) left; returns new array + points scored
local function SlideLeft(line)
    local out   = {}
    local pts   = 0
    local merged = {}

    -- Remove zeros
    for _, v in ipairs(line) do
        if v ~= 0 then out[#out + 1] = v end
    end

    -- Merge adjacent equal tiles
    local i = 1
    while i <= #out do
        if i < #out and out[i] == out[i + 1] and not merged[i] then
            local val = out[i] * 2
            pts = pts + val
            out[i] = val
            table.remove(out, i + 1)
            merged[i] = true
        end
        i = i + 1
    end

    -- Pad to GRID length
    while #out < GRID do out[#out + 1] = 0 end
    return out, pts
end

-- Extract row r as array
local function GetRow(r)
    local line = {}
    for c = 1, GRID do line[c] = board[r][c] end
    return line
end

-- Extract column c as array
local function GetCol(c)
    local line = {}
    for r = 1, GRID do line[r] = board[r][c] end
    return line
end

-- Write array back as row r
local function SetRow(r, line)
    for c = 1, GRID do board[r][c] = line[c] end
end

-- Write array back as column c
local function SetCol(c, line)
    for r = 1, GRID do board[r][c] = line[r] end
end

-- Reverse an array in-place
local function Reverse(line)
    local n = #line
    for i = 1, math.floor(n / 2) do
        line[i], line[n - i + 1] = line[n - i + 1], line[i]
    end
    return line
end

-- Move in direction: "left","right","up","down"
-- Returns true if any tile moved
local function Move(dir)
    local moved = false
    local pts   = 0

    if dir == "left" then
        for r = 1, GRID do
            local orig = GetRow(r)
            local new, p = SlideLeft(orig)
            pts = pts + p
            for c = 1, GRID do
                if new[c] ~= orig[c] then moved = true end
            end
            SetRow(r, new)
        end

    elseif dir == "right" then
        for r = 1, GRID do
            local orig = GetRow(r)
            local rev  = Reverse({unpack(orig)})
            local new, p = SlideLeft(rev)
            pts = pts + p
            Reverse(new)
            for c = 1, GRID do
                if new[c] ~= orig[c] then moved = true end
            end
            SetRow(r, new)
        end

    elseif dir == "up" then
        for c = 1, GRID do
            local orig = GetCol(c)
            local new, p = SlideLeft(orig)
            pts = pts + p
            for r = 1, GRID do
                if new[r] ~= orig[r] then moved = true end
            end
            SetCol(c, new)
        end

    elseif dir == "down" then
        for c = 1, GRID do
            local orig = GetCol(c)
            local rev  = Reverse({unpack(orig)})
            local new, p = SlideLeft(rev)
            pts = pts + p
            Reverse(new)
            for r = 1, GRID do
                if new[r] ~= orig[r] then moved = true end
            end
            SetCol(c, new)
        end
    end

    if moved then
        score = score + pts
        if score > bestScore then
            bestScore = score
            UIThingsDB.games.game2048.highScore = bestScore
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
    bestScore   = UIThingsDB.games.game2048.highScore or 0

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
            f.bg:SetColorTexture(0.80, 0.75, 0.70, 1)

            -- Permanent dark-brown border (1 px, all tiles)
            local B = 2  -- border thickness
            local br, bg2, bb = 0.25, 0.25, 0.25
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

            -- New-tile highlight: 4 white edge strips (shown for one move only)
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

    gameFrame = CreateFrame("Frame", "LunaUITweaks_2048Game", UIParent)
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
    bg:SetColorTexture(0.73, 0.68, 0.63, 1)

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
    titleBarBg:SetColorTexture(0.47, 0.43, 0.39, 1)

    local titleLabel = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleLabel:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    titleLabel:SetText("|cFFFFD100Tiles|r  |cFFBBAA99drag title to move · arrow keys to play|r")

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
        boxBg:SetColorTexture(0.47, 0.43, 0.39, 1)

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
    boardBg:SetColorTexture(0.47, 0.43, 0.39, 1)

    BuildTiles(boardFrame)

    -- Keyboard input: capture arrow keys while window is shown
    gameFrame:SetScript("OnKeyDown", function(self, key)
        if     key == "UP"    then OnKey("up")    ; self:SetPropagateKeyboardInput(false)
        elseif key == "DOWN"  then OnKey("down")  ; self:SetPropagateKeyboardInput(false)
        elseif key == "LEFT"  then OnKey("left")  ; self:SetPropagateKeyboardInput(false)
        elseif key == "RIGHT" then OnKey("right") ; self:SetPropagateKeyboardInput(false)
        else                                         self:SetPropagateKeyboardInput(true)
        end
    end)

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
end

-- Close on combat start
addonTable.EventBus.Register("PLAYER_REGEN_DISABLED", function()
    if gameFrame and gameFrame:IsShown() then
        gameFrame:Hide()
    end
end)

-- ============================================================
-- Public API
-- ============================================================
function addonTable.Game2048.ShowGame()
    if not gameFrame then
        BuildUI()
    end
    if gameFrame:IsShown() then
        gameFrame:Hide()
    else
        bestScore = UIThingsDB.games.game2048.highScore or 0
        gameFrame:Show()
        gameFrame:EnableKeyboard(true)
        if not board then
            StartGame()
        else
            RenderBoard()
        end
    end
end
