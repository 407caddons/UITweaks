local addonName, addonTable = ...
addonTable.Gems = {}

-- ============================================================
-- Constants
-- ============================================================
local ROWS       = 8
local COLS       = 8
local CELL       = 32    -- px per cell
local PADDING    = 8
local BOARD_W    = COLS * CELL
local BOARD_H    = ROWS * CELL

-- Gem Types — jewel-toned base colours + lighter shine tint
local GEMS = {
    { r=0.85, g=0.15, b=0.15,  sr=1.0,  sg=0.55, sb=0.55 },  -- Ruby
    { r=0.10, g=0.75, b=0.25,  sr=0.55, sg=1.0,  sb=0.60 },  -- Emerald
    { r=0.15, g=0.45, b=0.95,  sr=0.55, sg=0.75, sb=1.0  },  -- Sapphire
    { r=0.90, g=0.75, b=0.05,  sr=1.0,  sg=0.95, sb=0.55 },  -- Topaz
    { r=0.65, g=0.15, b=0.90,  sr=0.88, sg=0.55, sb=1.0  },  -- Amethyst
    { r=0.95, g=0.45, b=0.05,  sr=1.0,  sg=0.78, sb=0.45 },  -- Amber
    { r=0.30, g=0.85, b=0.85,  sr=0.65, sg=1.0,  sb=1.0  },  -- Aquamarine
}
local NUM_TYPES = #GEMS

-- ============================================================
-- State
-- ============================================================
local gameFrame
local boardFrame
local cells         -- cells[r][c] = frame with .tex
local board         -- board[r][c] = gem type index (1 to NUM_TYPES), or nil if empty

local scoreText
local score
local gameActive

-- Selection mechanics
local selR, selC    -- currently selected cell

-- Animation/Tick State
local animTicker
local isAnimating = false

-- ============================================================
-- Forward Declarations
-- ============================================================
local StartGame, GameOver, BuildUI, TickGravity, CheckMatches, HandleClick, SwapGems

-- ============================================================
-- Rendering
-- ============================================================
local function UpdateCell(r, c)
    local cell = cells[r][c]
    local gemType = board[r][c]
    
    if gemType then
        local color = GEMS[gemType]
        cell.tex:SetColorTexture(color.r, color.g, color.b, 1)
        cell.tex:Show()
        cell.shine:SetColorTexture(color.sr, color.sg, color.sb, 0.45)
        cell.shine:Show()
        cell.shadow:Show()
    else
        cell.tex:Hide()
        cell.shine:Hide()
        cell.shadow:Hide()
    end
    
    -- Selection highlight
    if r == selR and c == selC then
        cell.highlight:Show()
    else
        cell.highlight:Hide()
    end
end

local function RenderBoard()
    for r = 1, ROWS do
        for c = 1, COLS do
            UpdateCell(r, c)
        end
    end
end

local function UpdateScore()
    if scoreText then
        scoreText:SetText("Score\n" .. score)
    end
end

-- ============================================================
-- Game Logic
-- ============================================================
local function GetMatches()
    local matched = {}
    for r = 1, ROWS do
        matched[r] = {}
        for c = 1, COLS do
            matched[r][c] = false
        end
    end

    local foundMatch = false

    -- Check horizontal matches
    for r = 1, ROWS do
        for c = 1, COLS - 2 do
            local gem = board[r][c]
            if gem then
                if board[r][c+1] == gem and board[r][c+2] == gem then
                    matched[r][c] = true
                    matched[r][c+1] = true
                    matched[r][c+2] = true
                    foundMatch = true
                    -- Continue extending the match
                    local nextC = c + 3
                    while nextC <= COLS and board[r][nextC] == gem do
                        matched[r][nextC] = true
                        nextC = nextC + 1
                    end
                end
            end
        end
    end

    -- Check vertical matches
    for c = 1, COLS do
        for r = 1, ROWS - 2 do
            local gem = board[r][c]
            if gem then
                if board[r+1][c] == gem and board[r+2][c] == gem then
                    matched[r][c] = true
                    matched[r+1][c] = true
                    matched[r+2][c] = true
                    foundMatch = true
                    -- Continue extending the match
                    local nextR = r + 3
                    while nextR <= ROWS and board[nextR][c] == gem do
                        matched[nextR][c] = true
                        nextR = nextR + 1
                    end
                end
            end
        end
    end

    return foundMatch, matched
end

local function ProcessMatches()
    local foundMatch, matched = GetMatches()
    if not foundMatch then
        isAnimating = false
        if animTicker then animTicker:Cancel(); animTicker = nil end
        -- Check if game over (no valid moves) could be added here later
        return
    end
    
    -- Clear matched gems and add score
    local count = 0
    for r = 1, ROWS do
        for c = 1, COLS do
            if matched[r][c] then
                board[r][c] = nil
                count = count + 1
                UpdateCell(r, c)
            end
        end
    end
    
    score = score + (count * 10)
    UpdateScore()

    -- Start gravity delay
    if animTicker then animTicker:Cancel() end
    animTicker = C_Timer.NewTimer(0.3, function()
        TickGravity()
    end)
end

TickGravity = function()
    local moved = false
    
    -- Process columns from bottom up
    for c = 1, COLS do
        -- Find empty spots and pull gems down
        for r = ROWS, 2, -1 do
            if board[r][c] == nil then
                -- Find the nearest gem above
                local aboveR = r - 1
                while aboveR >= 1 and board[aboveR][c] == nil do
                    aboveR = aboveR - 1
                end
                
                if aboveR >= 1 then
                    board[r][c] = board[aboveR][c]
                    board[aboveR][c] = nil
                    UpdateCell(r, c)
                    UpdateCell(aboveR, c)
                    moved = true
                end
            end
        end
        
        -- Fill remaining empty spots at the top with new random gems
        for r = 1, ROWS do
            if board[r][c] == nil then
                board[r][c] = math.random(1, NUM_TYPES)
                UpdateCell(r, c)
                moved = true
            end
        end
    end
    
    if moved then
        if animTicker then animTicker:Cancel() end
        animTicker = C_Timer.NewTimer(0.3, function()
            ProcessMatches()
        end)
    else
        ProcessMatches()
    end
end

local function FillBoard()
    for r = 1, ROWS do
        board[r] = {}
        for c = 1, COLS do
            -- Keep placing random gems until we place one that doesn't immediately match
            local gem
            repeat
                gem = math.random(1, NUM_TYPES)
                board[r][c] = gem
                local hasMatch = false
                if r >= 3 and board[r-1][c] == gem and board[r-2][c] == gem then hasMatch = true end
                if c >= 3 and board[r][c-1] == gem and board[r][c-2] == gem then hasMatch = true end
                if not hasMatch then break end
            until false
        end
    end
end

SwapGems = function(r1, c1, r2, c2)
    local temp = board[r1][c1]
    board[r1][c1] = board[r2][c2]
    board[r2][c2] = temp
    
    UpdateCell(r1, c1)
    UpdateCell(r2, c2)
    
    local foundMatch = GetMatches()
    
    if foundMatch then
        isAnimating = true
        selR, selC = nil, nil
        RenderBoard()
        ProcessMatches()
    else
        -- Invalid move, swap back after brief delay
        isAnimating = true
        if animTicker then animTicker:Cancel() end
        animTicker = C_Timer.NewTimer(0.3, function()
            local temp2 = board[r1][c1]
            board[r1][c1] = board[r2][c2]
            board[r2][c2] = temp2
            UpdateCell(r1, c1)
            UpdateCell(r2, c2)
            isAnimating = false
        end)
    end
end

HandleClick = function(r, c)
    if not gameActive or isAnimating then return end
    
    if not selR then
        -- First selection
        selR, selC = r, c
        UpdateCell(r, c)
    else
        -- Second selection
        local isAdjacent = (math.abs(selR - r) == 1 and selC == c) or (math.abs(selC - c) == 1 and selR == r)
        
        if isAdjacent then
            SwapGems(selR, selC, r, c)
        else
            -- Deselect or select new cell
            local oldR, oldC = selR, selC
            if selR == r and selC == c then
                selR, selC = nil, nil
            else
                selR, selC = r, c
            end
            UpdateCell(oldR, oldC)
            if selR then UpdateCell(selR, selC) end
        end
    end
end

-- ============================================================
-- Board cell builder
-- ============================================================
local function BuildCellButton(parent, r, c)
    local size = CELL
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(size - 2, size - 2) -- Minor inset
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", (c - 1) * size + 1, -(r - 1) * size - 1)

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0.12, 0.12, 0.15, 1)

    -- Gem base colour
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    f.tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)

    -- Bottom-right shadow for depth
    f.shadow = f:CreateTexture(nil, "ARTWORK")
    f.shadow:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 4, 4)
    f.shadow:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    f.shadow:SetColorTexture(0, 0, 0, 0.35)
    f.shadow:Hide()

    -- Top-left shine highlight
    f.shine = f:CreateTexture(nil, "OVERLAY")
    f.shine:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -5)
    f.shine:SetSize(math.floor((CELL - 8) * 0.55), math.floor((CELL - 8) * 0.45))
    f.shine:Hide()

    -- Selection highlight
    f.highlight = f:CreateTexture(nil, "OVERLAY")
    f.highlight:SetAllPoints()
    f.highlight:SetColorTexture(1, 1, 1, 0.3)
    f.highlight:Hide()

    f:RegisterForClicks("LeftButtonUp")
    f:SetScript("OnClick", function(self)
        HandleClick(r, c)
    end)

    return f
end

-- ============================================================
-- Start / UI
-- ============================================================
StartGame = function()
    if InCombatLockdown() then return end
    score = 0
    selR, selC = nil, nil
    isAnimating = false

    board = {}
    FillBoard()
    
    gameActive = true
    UpdateScore()
    RenderBoard()
end

BuildUI = function()
    local SIDE_W = 100
    local totalW = BOARD_W + PADDING * 3 + SIDE_W
    local totalH = BOARD_H + PADDING * 2 + 30

    gameFrame = CreateFrame("Frame", "LunaUITweaks_GemsGame", UIParent)
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
    title:SetText("|cFF00FFFFGems|r  |cFF888888drag title to move|r")

    local closeBtn = CreateFrame("Button", nil, gameFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", gameFrame, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function()
        gameFrame:Hide()
        gameActive = false
        if animTicker then animTicker:Cancel(); animTicker = nil end
    end)

    -- Board frame
    boardFrame = CreateFrame("Frame", nil, gameFrame)
    boardFrame:SetSize(BOARD_W, BOARD_H)
    boardFrame:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", PADDING, -(PADDING + 30))

    local boardBg = boardFrame:CreateTexture(nil, "BACKGROUND")
    boardBg:SetAllPoints()
    boardBg:SetColorTexture(0.05, 0.05, 0.07, 1)

    cells = {}
    for r = 1, ROWS do
        cells[r] = {}
        for c = 1, COLS do
            cells[r][c] = BuildCellButton(boardFrame, r, c)
        end
    end

    -- Side panel
    local sideX = BOARD_W + PADDING * 2
    local sideTopY = PADDING + 30

    scoreText = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scoreText:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", sideX, -sideTopY)
    scoreText:SetJustifyH("LEFT")
    scoreText:SetText("Score\n0")

    local newGameBtn = CreateFrame("Button", nil, gameFrame, "UIPanelButtonTemplate")
    newGameBtn:SetSize(SIDE_W - 4, 26)
    newGameBtn:SetPoint("BOTTOMLEFT", gameFrame, "BOTTOMLEFT", sideX, PADDING)
    newGameBtn:SetText("New Game")
    newGameBtn:SetScript("OnClick", StartGame)
end

addonTable.EventBus.Register("PLAYER_REGEN_DISABLED", function()
    if gameFrame and gameFrame:IsShown() then
        gameFrame:Hide()
        gameActive = false
        isAnimating = false
        if animTicker then animTicker:Cancel(); animTicker = nil end
    end
end)

function addonTable.Gems.ShowGame()
    if not gameFrame then BuildUI() end
    if gameFrame:IsShown() then
        gameFrame:Hide()
        gameActive = false
        isAnimating = false
        if animTicker then animTicker:Cancel(); animTicker = nil end
    else
        gameFrame:Show()
        if not gameActive then
            StartGame()
        end
    end
end
