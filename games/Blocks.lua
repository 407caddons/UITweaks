local addonName, addonTable = ...
addonTable.Blocks = {}

-- ============================================================
-- Constants
-- ============================================================
local COLS      = 10
local ROWS      = 20
local CELL      = 24   -- px per cell (includes 1px gap)
local PREVIEW_CELL = 18
local BOARD_W   = COLS * CELL
local BOARD_H   = ROWS * CELL
local PADDING   = 8

local math_min = math.min
local math_max = math.max
local math_floor = math.floor

-- Opponent board constants (same cell size as player board)
local OPP_CELL  = CELL
local OPP_W     = COLS * OPP_CELL
local OPP_H     = ROWS * OPP_CELL
local OPP_LABEL = 18   -- height of name/score label above each opponent board

-- Gravity intervals by level (seconds per drop)
local GRAVITY = {
    [0]=0.85, [1]=0.72, [2]=0.60, [3]=0.50, [4]=0.42,
    [5]=0.34, [6]=0.27, [7]=0.21, [8]=0.16, [9]=0.12,
}
local function GravityForLevel(lvl)
    return GRAVITY[math_min(lvl, 9)] or 0.10
end

-- Lines needed per level
local LINES_PER_LEVEL = 10

-- Score table (single / double / triple / quad)
local LINE_SCORE = { 40, 100, 300, 1200 }

-- ============================================================
-- Tetromino definitions (rotations as {col,row} offsets from pivot)
-- ============================================================
local PIECES = {
    -- I  (cyan)
    { color = {0, 1, 1}, rotations = {
        {{-1,0},{0,0},{1,0},{2,0}},
        {{1,-1},{1,0},{1,1},{1,2}},
        {{-1,1},{0,1},{1,1},{2,1}},
        {{0,-1},{0,0},{0,1},{0,2}},
    }},
    -- O  (yellow)
    { color = {1, 1, 0}, rotations = {
        {{0,0},{1,0},{0,1},{1,1}},
        {{0,0},{1,0},{0,1},{1,1}},
        {{0,0},{1,0},{0,1},{1,1}},
        {{0,0},{1,0},{0,1},{1,1}},
    }},
    -- T  (magenta)
    { color = {0.8, 0, 0.8}, rotations = {
        {{-1,0},{0,0},{1,0},{0,1}},
        {{0,-1},{0,0},{1,0},{0,1}},
        {{-1,0},{0,0},{1,0},{0,-1}},
        {{0,-1},{0,0},{-1,0},{0,1}},
    }},
    -- S  (green)
    { color = {0, 0.85, 0}, rotations = {
        {{0,0},{1,0},{-1,1},{0,1}},
        {{0,-1},{0,0},{1,0},{1,1}},
        {{0,0},{1,0},{-1,1},{0,1}},
        {{0,-1},{0,0},{1,0},{1,1}},
    }},
    -- Z  (red)
    { color = {1, 0.15, 0.15}, rotations = {
        {{-1,0},{0,0},{0,1},{1,1}},
        {{1,-1},{0,0},{1,0},{0,1}},
        {{-1,0},{0,0},{0,1},{1,1}},
        {{1,-1},{0,0},{1,0},{0,1}},
    }},
    -- J  (blue)
    { color = {0.2, 0.3, 1}, rotations = {
        {{-1,0},{0,0},{1,0},{-1,1}},
        {{0,-1},{0,0},{0,1},{1,-1}},
        {{-1,0},{0,0},{1,0},{1,-1}},
        {{0,-1},{0,0},{0,1},{-1,1}},
    }},
    -- L  (orange)
    { color = {1, 0.55, 0}, rotations = {
        {{-1,0},{0,0},{1,0},{1,1}},
        {{0,-1},{0,0},{0,1},{1,1}},
        {{-1,0},{0,0},{1,0},{-1,-1}},
        {{0,-1},{0,0},{0,1},{-1,-1}},
    }},
}

-- Piece index -> single char for RLE encoding (1-7 maps to A-G, 0 = empty)
local PIECE_CHAR = { "A","B","C","D","E","F","G" }
local CHAR_PIECE = { A=1, B=2, C=3, D=4, E=5, F=6, G=7 }

-- ============================================================
-- State — single player
-- ============================================================
local gameFrame        -- root window
local boardFrame       -- the play area
local cells            -- cells[row][col] = frame with .tex
local previewCells     -- 4x4 preview grid
local scoreText, levelText, linesText, highScoreText
local gameOverFrame
local pauseText
local multiBtn         -- "Multiplayer" button (shown only when party has addon)

local board            -- board[row][col] = color table or nil
local curPiece, curRot, curX, curY
local nextPiece
local score, level, linesCleared, highScore
local gameActive, gamePaused
local gravityTicker
local flashTicker
local flashRows        -- rows currently flashing before removal
local flashStep

-- Cached ghost states
local cachedGhostY = nil
local cachedGhostX = nil
local cachedGhostRot = nil
local cachedGhostPiece = nil
local cachedGhostBoard = nil -- not exactly the full board, just a dirty flag could be better, we will clear on board change

-- ============================================================
-- Multiplayer state
-- ============================================================
local MP = {
    active        = false,   -- currently in a multiplayer session
    invitePending = false,   -- we sent an invite, waiting for responses
    inviteTimer   = nil,     -- C_Timer handle for 5s timeout
    invited       = {},      -- set of names we invited
    accepted      = {},      -- set of names that accepted
    declined      = {},      -- set of names that declined/timed-out
    opponents     = {},      -- [name] = { board=..., score=0, alive=true, lastUpdate=..., frames=... }
    promptFrame   = nil,     -- our accept/decline popup
    promptTimer   = nil,     -- 5s auto-decline timer
    statusText    = nil,     -- status label in main window
    watchdogTicker= nil,     -- periodic ticker that eliminates silent opponents
}

-- Seconds without a BOARD message before an alive opponent is considered disconnected.
-- Must be longer than the slowest gravity tick (0.85s at level 0) plus network slack.
local OPPONENT_TIMEOUT = 4.0
-- How often the watchdog checks for timed-out opponents (seconds)
local WATCHDOG_INTERVAL = 1.0

-- Pool of opponent panel frame bundles — reused across MP sessions to avoid
-- accumulating orphaned frames as children of gameFrame.
local oppFramePool = {}

-- Cached player name — set on PLAYER_LOGIN, valid for the entire session.
local myName = ""
addonTable.EventBus.Register("PLAYER_LOGIN", function()
    myName = UnitName("player") or ""
end)

-- ============================================================
-- Board helpers
-- ============================================================
local function NewBoard()
    local b = {}
    for r = 1, ROWS do
        b[r] = {}
        for c = 1, COLS do b[r][c] = nil end
    end
    return b
end

-- Reusable block buffer — avoids per-call table allocation in hot paths.
-- PieceBlocks writes into this table and returns it; callers must use the
-- result immediately and not store it across subsequent PieceBlocks calls.
local _pieceBlocksBuf = {
    { c=0, r=0 }, { c=0, r=0 }, { c=0, r=0 }, { c=0, r=0 },
}

local function PieceBlocks(pieceIdx, rot, px, py)
    local offsets = PIECES[pieceIdx].rotations[rot]
    for i = 1, 4 do
        local o = offsets[i]
        _pieceBlocksBuf[i].c = px + o[1]
        _pieceBlocksBuf[i].r = py + o[2]
    end
    return _pieceBlocksBuf
end

local function IsValid(blocks)
    for _, b in ipairs(blocks) do
        if b.c < 1 or b.c > COLS or b.r > ROWS then return false end
        if b.r >= 1 and board[b.r][b.c] then return false end
    end
    return true
end

-- ============================================================
-- Rendering — single player board
-- ============================================================
local EMPTY_COLOR   = {0.10, 0.10, 0.12}
local GHOST_ALPHA   = 0.25
local BORDER_COLOR  = {0.25, 0.25, 0.28}

local function SetCellColor(frame, r, g, b, a)
    local colStr = r..","..g..","..b..","..(a or 1)
    if frame.currentColor == colStr then return end
    frame.currentColor = colStr
    frame.tex:SetColorTexture(r, g, b, a or 1)
    -- We don't really need to set the border color if it never changes,
    -- but if we do, we could cache that too.
    if not frame.borderSet then
        frame.border:SetColorTexture(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], 1)
        frame.borderSet = true
    end
end

local function RenderBoard()
    for row = 1, ROWS do
        for col = 1, COLS do
            local c = board[row][col]
            if c then
                SetCellColor(cells[row][col], c[1], c[2], c[3])
            else
                SetCellColor(cells[row][col], EMPTY_COLOR[1], EMPTY_COLOR[2], EMPTY_COLOR[3])
            end
        end
    end
end

local function RenderPiece(blocks, color, alpha)
    alpha = alpha or 1
    for _, b in ipairs(blocks) do
        if b.r >= 1 and b.r <= ROWS and b.c >= 1 and b.c <= COLS then
            SetCellColor(cells[b.r][b.c], color[1], color[2], color[3], alpha)
        end
    end
end

local function InvalidateGhost()
    cachedGhostPiece = nil
end

local function GhostY()
    if cachedGhostPiece == curPiece and cachedGhostRot == curRot and cachedGhostX == curX then
        if cachedGhostY then return cachedGhostY end
    end
    
    local gy = curY
    while true do
        local nb = PieceBlocks(curPiece, curRot, curX, gy + 1)
        if IsValid(nb) then
            gy = gy + 1
        else
            break
        end
    end
    
    cachedGhostPiece = curPiece
    cachedGhostRot = curRot
    cachedGhostX = curX
    cachedGhostY = gy
    return gy
end

local function RenderAll()
    RenderBoard()
    -- Ghost
    local gy = GhostY()
    if gy ~= curY then
        local ghostBlocks = PieceBlocks(curPiece, curRot, curX, gy)
        local col = PIECES[curPiece].color
        RenderPiece(ghostBlocks, col, GHOST_ALPHA)
    end
    -- Active piece
    local blocks = PieceBlocks(curPiece, curRot, curX, curY)
    RenderPiece(blocks, PIECES[curPiece].color)
end

local function RenderPreview()
    -- Clear preview
    for r = 1, 4 do
        for c = 1, 4 do
            SetCellColor(previewCells[r][c], EMPTY_COLOR[1], EMPTY_COLOR[2], EMPTY_COLOR[3])
        end
    end
    if not nextPiece then return end
    local col = PIECES[nextPiece].color
    local offsets = PIECES[nextPiece].rotations[1]
    -- Centre in 4x4 preview
    local minC, minR, maxC, maxR = 99, 99, -99, -99
    for _, o in ipairs(offsets) do
        minC = math_min(minC, o[1]); maxC = math_max(maxC, o[1])
        minR = math_min(minR, o[2]); maxR = math_max(maxR, o[2])
    end
    local wBlocks = maxC - minC + 1
    local hBlocks = maxR - minR + 1
    local startC = math_floor((4 - wBlocks) / 2) + 1 - minC
    local startR = math_floor((4 - hBlocks) / 2) + 1 - minR
    for _, o in ipairs(offsets) do
        local pr = startR + o[2]
        local pc = startC + o[1]
        if pr >= 1 and pr <= 4 and pc >= 1 and pc <= 4 then
            SetCellColor(previewCells[pr][pc], col[1], col[2], col[3])
        end
    end
end

local function UpdateHUD()
    if scoreText    then scoreText:SetText("Score\n" .. score) end
    if levelText    then levelText:SetText("Level\n" .. level) end
    if linesText    then linesText:SetText("Lines\n" .. linesCleared) end
    if highScoreText then highScoreText:SetText("Best\n" .. highScore) end
end

-- ============================================================
-- Board serialization for network sync
-- ============================================================
-- Each cell encodes as one character: "0" = empty, "A"-"G" = piece 1-7.
-- 200 characters total, no compression needed (fits in 255-byte limit with score prefix).
local function EncodeBoard(b)
    local t = {}
    for r = 1, ROWS do
        for c = 1, COLS do
            local cell = b[r][c]
            if cell then
                local ch = "A"  -- fallback
                for pi, p in ipairs(PIECES) do
                    if p.color == cell then
                        ch = PIECE_CHAR[pi]
                        break
                    end
                end
                t[#t + 1] = ch
            else
                t[#t + 1] = "0"
            end
        end
    end
    return table.concat(t)
end

-- Decode a board RLE string into an existing board table (in-place).
-- Pass opp.board as the destination to avoid allocating 21 new tables per update.
local function DecodeBoard(s, dest)
    if not dest then dest = NewBoard() end
    local pos = 1
    for r = 1, ROWS do
        for c = 1, COLS do
            local ch = s:sub(pos, pos)
            pos = pos + 1
            if ch ~= "" and ch ~= "0" then
                local pi = CHAR_PIECE[ch]
                dest[r][c] = pi and PIECES[pi].color or nil
            else
                dest[r][c] = nil
            end
        end
    end
    return dest
end

-- ============================================================
-- Cell frame builder (shared by player board and opponent boards)
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
-- Opponent board rendering (full-size)
-- ============================================================
local function BuildOppBoard(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(OPP_W, OPP_H)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.07, 1)

    local oppCells = {}
    for r = 1, ROWS do
        oppCells[r] = {}
        for c = 1, COLS do
            oppCells[r][c] = BuildCellFrame(f, OPP_CELL, (c-1)*OPP_CELL, (r-1)*OPP_CELL)
        end
    end
    f.oppCells = oppCells
    return f
end

local function RenderOppBoard(opp)
    if not opp.frames or not opp.frames.oppBoard then return end
    local oppCells = opp.frames.oppBoard.oppCells
    local b = opp.board
    for r = 1, ROWS do
        for c = 1, COLS do
            local col = b and b[r][c]
            if col then
                SetCellColor(oppCells[r][c], col[1], col[2], col[3])
            else
                SetCellColor(oppCells[r][c], EMPTY_COLOR[1], EMPTY_COLOR[2], EMPTY_COLOR[3])
            end
        end
    end
    if opp.frames.scoreLabel then
        opp.frames.scoreLabel:SetText(opp.name .. "  " .. (opp.score or 0))
    end
    if opp.frames.deadOverlay then
        opp.frames.deadOverlay:SetShown(not opp.alive)
    end
end

-- Lay out opponent boards to the right of gameFrame, side by side
local function LayoutOpponentPanels()
    if not gameFrame then return end

    local PANEL_W = OPP_W + PADDING          -- board width + gap between panels
    local PANEL_H = OPP_H + OPP_LABEL + PADDING
    local idx     = 0

    for _, opp in pairs(MP.opponents) do
        if opp.name ~= myName then  -- never show our own board
            -- Acquire frames: reuse a pooled bundle or build a new one
            if not (opp.frames and opp.frames.container) then
                if #oppFramePool > 0 then
                    opp.frames = table.remove(oppFramePool)
                else
                    local container = CreateFrame("Frame", nil, gameFrame)
                    container:SetSize(OPP_W, PANEL_H)

                    local contBg = container:CreateTexture(nil, "BACKGROUND")
                    contBg:SetAllPoints()
                    contBg:SetColorTexture(0.06, 0.06, 0.08, 0.97)

                    local nameLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    nameLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -2)
                    nameLabel:SetWidth(OPP_W)
                    nameLabel:SetJustifyH("LEFT")

                    local oppBoard = BuildOppBoard(container)
                    oppBoard:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -OPP_LABEL)

                    local deadOverlay = oppBoard:CreateTexture(nil, "OVERLAY")
                    deadOverlay:SetAllPoints()
                    deadOverlay:SetColorTexture(0.8, 0, 0, 0.5)
                    deadOverlay:Hide()

                    opp.frames = {
                        container   = container,
                        scoreLabel  = nameLabel,
                        oppBoard    = oppBoard,
                        deadOverlay = deadOverlay,
                    }
                end
                -- (Re)initialise the label and overlay for this opponent
                opp.frames.scoreLabel:SetText(opp.name .. "  0")
                opp.frames.deadOverlay:Hide()
            end

            -- Position panels side-by-side to the right of gameFrame
            local container = opp.frames.container
            container:ClearAllPoints()
            container:SetPoint("TOPLEFT", gameFrame, "TOPRIGHT",
                PADDING + idx * PANEL_W,
                -(PADDING + 30))   -- align with board top (title bar offset)
            container:Show()
            idx = idx + 1
        end
    end
end

-- ============================================================
-- Multiplayer helpers
-- ============================================================
local function MPStatusMsg(msg)
    if MP.statusText then
        MP.statusText:SetText(msg)
        MP.statusText:Show()
    end
end

local function GetPartyMembersWithAddon()
    local names = {}
    local playerData = addonTable.AddonVersions and addonTable.AddonVersions.GetPlayerData() or {}
    for name, data in pairs(playerData) do
        if name ~= myName and data and data.version ~= nil then
            table.insert(names, name)
        end
    end
    return names
end

-- Check if we should show the multiplayer button
local function UpdateMultiBtn()
    if not multiBtn then return end
    if not MP.active and IsInGroup() then
        local peers = GetPartyMembersWithAddon()
        multiBtn:SetShown(#peers > 0)
    else
        multiBtn:Hide()
    end
end

-- Cancel any pending invite and clean up
local function CancelInvite()
    if MP.inviteTimer then
        MP.inviteTimer:Cancel()
        MP.inviteTimer = nil
    end
    MP.invitePending = false
    wipe(MP.invited)
    wipe(MP.accepted)
    wipe(MP.declined)
    MPStatusMsg("")
    UpdateMultiBtn()
end

local function NewOpponent(name)
    return { name=name, board=NewBoard(), score=0, alive=true, lastUpdate=GetTime() }
end

-- Forward declarations
local StartFlash, GameOver, StartMPGame, EndMPGame, StartGame, AddScore, RestartGravity, BuildUI, CheckMPWinner

local function AnnounceGameStart()
    local channel = IsInRaid() and "RAID" or "PARTY"
    local names = {}
    for name in pairs(MP.accepted) do table.insert(names, name) end
    local playerList = #names > 0 and (" with " .. table.concat(names, ", ")) or ""
    SendChatMessage("Starting a game of Block Game" .. playerList .. "!", channel)
end

-- Build the START payload: comma-separated list of acceptees only (not the inviter).
-- Recipients already know the inviter from senderShort; this tells them about co-acceptees.
local function BuildStartPayload()
    local participants = {}
    for name in pairs(MP.accepted) do table.insert(participants, name) end
    return table.concat(participants, ",")
end

-- Start multiplayer game session for everyone
StartMPGame = function()
    MP.active = true
    MP.invitePending = false
    if MP.inviteTimer then MP.inviteTimer:Cancel(); MP.inviteTimer = nil end

    MPStatusMsg("|cFF00FF00Multiplayer - Last board standing wins!|r")
    if multiBtn then multiBtn:Hide() end
    if gameFrame then gameFrame:Show() end
    -- LayoutOpponentPanels is called by StartGame after BuildUI ensures gameFrame exists

    -- Watchdog: periodically eliminate opponents who stop sending board updates
    if MP.watchdogTicker then MP.watchdogTicker:Cancel() end
    MP.watchdogTicker = C_Timer.NewTicker(WATCHDOG_INTERVAL, function()
        if not MP.active then return end
        local now = GetTime()
        for name, opp in pairs(MP.opponents) do
            if opp.alive and opp.lastUpdate and (now - opp.lastUpdate) > OPPONENT_TIMEOUT then
                opp.alive = false
                RenderOppBoard(opp)
                MPStatusMsg("|cFFFF4444" .. name .. " disconnected.|r")
                CheckMPWinner()
            end
        end
    end)
end

EndMPGame = function(winnerName)
    if not MP.active then return end
    MP.active = false

    -- Stop the game loop and watchdog
    gameActive = false
    if gravityTicker       then gravityTicker:Cancel();       gravityTicker = nil end
    if flashTicker         then flashTicker:Cancel();         flashTicker = nil end
    if MP.watchdogTicker   then MP.watchdogTicker:Cancel();   MP.watchdogTicker = nil end

    -- Return opponent frames to the pool for reuse in the next MP session
    for _, opp in pairs(MP.opponents) do
        if opp.frames and opp.frames.container then
            opp.frames.container:Hide()
            table.insert(oppFramePool, opp.frames)
        end
    end
    wipe(MP.opponents)

    local msg
    if winnerName == myName then
        msg = "You won!"
        MPStatusMsg("|cFFFFD100You won the multiplayer game!|r")
    elseif winnerName then
        msg = winnerName .. " wins!"
        MPStatusMsg("|cFFAAAAAA" .. winnerName .. " wins!|r")
    else
        msg = "Draw!"
        MPStatusMsg("|cFFAAAAAA" .. "Draw!|r")
    end

    -- Show result on the game over overlay
    if gameOverFrame then
        gameOverFrame:Show()
        if gameOverFrame.titleText then
            if winnerName == myName then
                gameOverFrame.titleText:SetText("|cFFFFD100YOU WIN!|r")
            else
                gameOverFrame.titleText:SetText("|cFFFF2020GAME OVER|r")
            end
        end
        gameOverFrame.scoreText:SetText(
            string.format("%s\nScore: %d", msg, score))
    end

    UpdateMultiBtn()
end

-- Check if only one participant remains alive and end the game
CheckMPWinner = function()
    if not MP.active then return end

    local aliveOpponents = 0
    local lastAliveOpponent = nil
    for name, opp in pairs(MP.opponents) do
        if opp.alive then
            aliveOpponents = aliveOpponents + 1
            lastAliveOpponent = name
        end
    end

    local totalAlive = aliveOpponents + (gameActive and 1 or 0)

    if totalAlive <= 1 then
        local winner
        if gameActive then
            winner = myName
            addonTable.Comm.Send("GAME", "WIN", myName)
        else
            winner = lastAliveOpponent  -- nil if everyone is dead (draw)
        end
        EndMPGame(winner)
    end
end

-- ============================================================
-- Network message handlers
-- ============================================================
local function OnGameInvite(senderShort, payload, senderFull)
    if MP.active then return end
    -- Show accept/decline prompt, cancelling any previous one first
    if MP.promptTimer then MP.promptTimer:Cancel(); MP.promptTimer = nil end
    if MP.promptFrame then MP.promptFrame:Hide(); MP.promptFrame = nil end

    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(280, 100)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left=1, right=1, top=1, bottom=1 },
    })
    f:SetBackdropColor(0.1, 0.1, 0.12, 0.97)
    f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    MP.promptFrame = f

    local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOP", 0, -12)
    label:SetText(senderShort .. " invites you to play Block Game!\nAuto-declines in 5s.")

    local timerLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timerLabel:SetPoint("TOP", 0, -38)
    timerLabel:SetTextColor(0.7, 0.7, 0.7)
    timerLabel:SetText("")

    local remaining = 5
    local function UpdateTimer()
        timerLabel:SetText("(" .. remaining .. "s)")
    end
    UpdateTimer()

    local function DeclineInvite()
        addonTable.Comm.Send("GAME", "DECLINE", senderShort)
        if MP.promptTimer then MP.promptTimer:Cancel(); MP.promptTimer = nil end
        f:Hide()
        MP.promptFrame = nil
    end

    local function AcceptInvite()
        addonTable.Comm.Send("GAME", "ACCEPT", senderShort)
        if MP.promptTimer then MP.promptTimer:Cancel(); MP.promptTimer = nil end
        f:Hide()
        MP.promptFrame = nil
        -- Add the inviter as an opponent
        if not MP.opponents[senderShort] then
            MP.opponents[senderShort] = NewOpponent(senderShort)
        end
    end

    local acceptBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    acceptBtn:SetSize(100, 22)
    acceptBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 15, 10)
    acceptBtn:SetText("Accept")
    acceptBtn:SetScript("OnClick", AcceptInvite)

    local declineBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    declineBtn:SetSize(100, 22)
    declineBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -15, 10)
    declineBtn:SetText("Decline")
    declineBtn:SetScript("OnClick", DeclineInvite)

    f:Show()

    -- 5s countdown ticker
    MP.promptTimer = C_Timer.NewTicker(1, function()
        remaining = remaining - 1
        UpdateTimer()
        if remaining <= 0 then
            MP.promptTimer:Cancel()
            MP.promptTimer = nil
            DeclineInvite()
        end
    end)
end

local function OnGameAccept(senderShort, payload, senderFull)
    if not MP.invitePending then return end
    -- payload = name of the inviter they're confirming (should be us)
    if payload ~= myName then return end

    MP.accepted[senderShort] = true

    -- Add as opponent
    if not MP.opponents[senderShort] then
        MP.opponents[senderShort] = NewOpponent(senderShort)
    end

    -- Check if everyone has responded
    local allResponded = true
    for name in pairs(MP.invited) do
        if not MP.accepted[name] and not MP.declined[name] then
            allResponded = false
            break
        end
    end

    local acceptCount = 0
    for _ in pairs(MP.accepted) do acceptCount = acceptCount + 1 end

    if allResponded then
        if acceptCount > 0 then
            -- Broadcast START to all accepted players
            AnnounceGameStart()
            addonTable.Comm.Send("GAME", "START", BuildStartPayload())
            StartMPGame()
            -- Start singleplayer loop for self
            if gameFrame then
                gameFrame:Show()
            end
            StartGame()
        else
            CancelInvite()
            MPStatusMsg("|cFFFF4444All players declined.|r")
        end
    else
        local invitedCount = 0
        for _ in pairs(MP.invited) do invitedCount = invitedCount + 1 end
        MPStatusMsg(string.format("Waiting for responses... (%d/%d accepted)",
            acceptCount, invitedCount))
    end
end

local function OnGameDecline(senderShort, payload, senderFull)
    if not MP.invitePending then return end
    if payload ~= myName then return end

    MP.declined[senderShort] = true
    -- Remove from opponents if we added them early
    MP.opponents[senderShort] = nil

    -- Check if everyone responded
    local allResponded = true
    for name in pairs(MP.invited) do
        if not MP.accepted[name] and not MP.declined[name] then
            allResponded = false; break
        end
    end

    if allResponded then
        local acceptCount = 0
        for _ in pairs(MP.accepted) do acceptCount = acceptCount + 1 end
        if acceptCount > 0 then
            AnnounceGameStart()
            addonTable.Comm.Send("GAME", "START", BuildStartPayload())
            StartMPGame()
            if gameFrame then gameFrame:Show() end
            StartGame()
        else
            CancelInvite()
            MPStatusMsg("|cFFFF4444All players declined.|r")
        end
    end
end

local function OnGameStart(senderShort, payload, senderFull)
    -- We received a START from the inviter — begin our game
    if MP.active then return end
    -- payload is a comma-separated participant list (inviter + all acceptees)
    -- Add everyone except ourselves as opponents
    for name in payload:gmatch("[^,]+") do
        if name ~= myName and not MP.opponents[name] then
            MP.opponents[name] = NewOpponent(name)
        end
    end
    -- Fallback: ensure the sender is added even if payload is malformed
    if not MP.opponents[senderShort] then
        MP.opponents[senderShort] = NewOpponent(senderShort)
    end
    if not gameFrame then
        BuildUI()  -- ensure frame exists before StartMPGame/StartGame
    end
    StartMPGame()
    gameFrame:Show()
    StartGame()
end

local function OnGameBoard(senderShort, payload, senderFull)
    if not MP.active then return end
    if senderShort == myName then return end
    -- payload: "SCORE:BOARDRLE"
    local scoreStr, boardRLE = payload:match("^(%d+):(.+)$")
    if not scoreStr then return end

    local opp = MP.opponents[senderShort]
    if not opp then
        MP.opponents[senderShort] = NewOpponent(senderShort)
        opp = MP.opponents[senderShort]
        -- We got a new opponent mid-session (late joiner), refresh layout
        LayoutOpponentPanels()
    end

    opp.score      = tonumber(scoreStr) or 0
    opp.lastUpdate = GetTime()
    DecodeBoard(boardRLE, opp.board)  -- decode in-place, no new allocation
    RenderOppBoard(opp)
end

local function OnGameOver(senderShort, payload, senderFull)
    if not MP.active then return end
    if senderShort == myName then return end
    local opp = MP.opponents[senderShort]
    if opp then
        opp.alive = false
        RenderOppBoard(opp)
        MPStatusMsg("|cFFFF4444" .. senderShort .. " was eliminated!|r")
    end
    CheckMPWinner()
end

local function OnGameWin(senderShort, payload, senderFull)
    if not MP.active then return end
    -- payload = winner name
    EndMPGame(payload)
end

-- Register all GAME handlers
addonTable.Comm.Register("GAME", "INVITE",  OnGameInvite)
addonTable.Comm.Register("GAME", "ACCEPT",  OnGameAccept)
addonTable.Comm.Register("GAME", "DECLINE", OnGameDecline)
addonTable.Comm.Register("GAME", "START",   OnGameStart)
addonTable.Comm.Register("GAME", "BOARD",   OnGameBoard)
addonTable.Comm.Register("GAME", "GAMEOVER",OnGameOver)
addonTable.Comm.Register("GAME", "WIN",     OnGameWin)

-- ============================================================
-- Game logic
-- ============================================================
local function RandomPiece()
    return math.random(#PIECES)
end

local function SpawnPiece()
    curPiece = nextPiece or RandomPiece()
    nextPiece = RandomPiece()
    curRot = 1
    curX = math_floor(COLS / 2)
    curY = 0
    InvalidateGhost()
    RenderPreview()
    -- Check game over
    local blocks = PieceBlocks(curPiece, curRot, curX, curY)
    if not IsValid(blocks) then
        return false
    end
    return true
end

local function LockPiece()
    local blocks = PieceBlocks(curPiece, curRot, curX, curY)
    local col = PIECES[curPiece].color
    for _, b in ipairs(blocks) do
        if b.r >= 1 then
            board[b.r][b.c] = col
        end
    end
    
    InvalidateGhost()
    -- Sync board to group in multiplayer
    if MP.active then
        local encoded = EncodeBoard(board)
        local payload = tostring(score) .. ":" .. encoded
        addonTable.Comm.Send("GAME", "BOARD", payload)
    end
end

local completeBuffer = {}
local function FindCompleteRows()
    wipe(completeBuffer)
    for r = 1, ROWS do
        local full = true
        for c = 1, COLS do
            if not board[r][c] then full = false; break end
        end
        if full then table.insert(completeBuffer, r) end
    end
    return completeBuffer
end

local function RemoveRows(rows)
    -- Sort descending so we can splice safely
    table.sort(rows, function(a, b) return a > b end)
    for _, r in ipairs(rows) do
        table.remove(board, r)
        table.insert(board, 1, {})
        for c = 1, COLS do board[1][c] = nil end
    end
    InvalidateGhost()
end

local function GravityTick()
    if not gameActive or gamePaused or flashRows then return end
    local blocks = PieceBlocks(curPiece, curRot, curX, curY + 1)
    if IsValid(blocks) then
        curY = curY + 1
        RenderAll()
    else
        LockPiece()
        local complete = FindCompleteRows()
        if #complete > 0 then
            StartFlash(complete)
        else
            AddScore(0)
            UpdateHUD()
            if not SpawnPiece() then GameOver() end
            RenderAll()
        end
    end
end

RestartGravity = function()
    if not gameActive then return end
    if gravityTicker then gravityTicker:Cancel() end
    gravityTicker = C_Timer.NewTicker(GravityForLevel(level), GravityTick)
end

AddScore = function(numLines)
    local base = LINE_SCORE[numLines] or (numLines * 100)
    score = score + base * (level + 1)
    linesCleared = linesCleared + numLines
    if score > highScore then
        highScore = score
        UIThingsDB.games.blocks.highScore = highScore
    end
    -- Level up
    local newLevel = math_floor(linesCleared / LINES_PER_LEVEL)
    if newLevel ~= level then
        level = newLevel
        RestartGravity()
    end
    UpdateHUD()
end

-- ============================================================
-- Line-clear flash animation
-- ============================================================
local FLASH_COLORS = {
    {1,1,1}, {0.8,0.8,0.8}, {1,1,1}, {0.5,0.5,0.5},
}

StartFlash = function(rows)
    flashRows = rows
    flashStep = 0
    if flashTicker then flashTicker:Cancel() end
    flashTicker = C_Timer.NewTicker(0.07, function()
        flashStep = flashStep + 1
        local fc = FLASH_COLORS[((flashStep - 1) % #FLASH_COLORS) + 1]
        for _, r in ipairs(flashRows) do
            for c = 1, COLS do
                cells[r][c].tex:SetColorTexture(fc[1], fc[2], fc[3])
            end
        end
        if flashStep >= 6 then
            flashTicker:Cancel()
            flashTicker = nil
            local n = #flashRows
            RemoveRows(flashRows)
            flashRows = nil
            if not gameActive then return end  -- game ended while flash was playing
            AddScore(n)
            UpdateHUD()
            if not SpawnPiece() then
                GameOver()
            else
                RenderAll()
            end
        end
    end)
end

GameOver = function()
    if gravityTicker then gravityTicker:Cancel(); gravityTicker = nil end
    UIThingsDB.games.blocks.highScore = highScore

    if MP.active then
        -- Broadcast before setting gameActive=false so CheckMPWinner counts correctly
        addonTable.Comm.Send("GAME", "GAMEOVER", "")
        gameActive = false
        CheckMPWinner()
        -- EndMPGame (called by CheckMPWinner) handles the overlay in multiplayer
    else
        gameActive = false
        if gameOverFrame then
            gameOverFrame:Show()
            if gameOverFrame.titleText then
                gameOverFrame.titleText:SetText("|cFFFF2020GAME OVER|r")
            end
            gameOverFrame.scoreText:SetText(
                string.format("Score: %d\nBest: %d", score, highScore))
        end
    end
end

-- ============================================================
-- Input actions
-- ============================================================
local function MoveLeft()
    if not gameActive or gamePaused or flashRows then return end
    local blocks = PieceBlocks(curPiece, curRot, curX - 1, curY)
    if IsValid(blocks) then curX = curX - 1; RenderAll() end
end

local function MoveRight()
    if not gameActive or gamePaused or flashRows then return end
    local blocks = PieceBlocks(curPiece, curRot, curX + 1, curY)
    if IsValid(blocks) then curX = curX + 1; RenderAll() end
end

local function SoftDrop()
    if not gameActive or gamePaused or flashRows then return end
    local blocks = PieceBlocks(curPiece, curRot, curX, curY + 1)
    if IsValid(blocks) then
        curY = curY + 1
        score = score + 1
        UpdateHUD()
        RenderAll()
    end
end

local function HardDrop()
    if not gameActive or gamePaused or flashRows then return end
    local gy = GhostY()
    score = score + 2 * (gy - curY)
    curY = gy
    UpdateHUD()
    LockPiece()
    local complete = FindCompleteRows()
    if #complete > 0 then
        StartFlash(complete)
    else
        if not SpawnPiece() then GameOver() end
        RenderAll()
    end
end

local function RotateCW()
    if not gameActive or gamePaused or flashRows then return end
    local numRots = #PIECES[curPiece].rotations
    local newRot = (curRot % numRots) + 1
    local blocks = PieceBlocks(curPiece, newRot, curX, curY)
    if IsValid(blocks) then curRot = newRot; RenderAll(); return end
    for _, kick in ipairs({1, -1, 2, -2}) do
        blocks = PieceBlocks(curPiece, newRot, curX + kick, curY)
        if IsValid(blocks) then curX = curX + kick; curRot = newRot; RenderAll(); return end
    end
end

local function RotateCCW()
    if not gameActive or gamePaused or flashRows then return end
    local numRots = #PIECES[curPiece].rotations
    local newRot = ((curRot - 2) % numRots) + 1
    local blocks = PieceBlocks(curPiece, newRot, curX, curY)
    if IsValid(blocks) then curRot = newRot; RenderAll(); return end
    for _, kick in ipairs({1, -1, 2, -2}) do
        blocks = PieceBlocks(curPiece, newRot, curX + kick, curY)
        if IsValid(blocks) then curX = curX + kick; curRot = newRot; RenderAll(); return end
    end
end

local function TogglePause()
    if not gameActive then return end
    gamePaused = not gamePaused
    if pauseText then
        pauseText:SetShown(gamePaused)
    end
end

-- ============================================================
-- Start / Restart
-- ============================================================
StartGame = function()
    if InCombatLockdown() then return end
    board         = NewBoard()
    score         = 0
    level         = 0
    linesCleared  = 0
    highScore     = UIThingsDB.games and (UIThingsDB.games.blocks and UIThingsDB.games.blocks.highScore or UIThingsDB.games.tetris and UIThingsDB.games.tetris.highScore) or 0
    flashRows     = nil
    gamePaused    = false
    gameActive    = true

    if gameOverFrame then gameOverFrame:Hide() end
    if pauseText then pauseText:Hide() end

    -- Layout opponent boards now that gameFrame is guaranteed to exist
    if MP.active then LayoutOpponentPanels() end

    nextPiece = RandomPiece()
    SpawnPiece()
    RenderAll()
    RenderPreview()
    UpdateHUD()

    RestartGravity()
end

-- ============================================================
-- Multiplayer invite flow
-- ============================================================
local function SendMultiplayerInvite()
    local peers = GetPartyMembersWithAddon()
    if #peers == 0 then
        MPStatusMsg("|cFFFF4444No party members with the addon.|r")
        return
    end

    wipe(MP.invited)
    wipe(MP.accepted)
    wipe(MP.declined)
    wipe(MP.opponents)
    MP.invitePending = true

    for _, name in ipairs(peers) do
        MP.invited[name] = true
    end

    addonTable.Comm.Send("GAME", "INVITE", "")
    MPStatusMsg(string.format("Invite sent to %d player(s)... (5s timeout)", #peers))
    if multiBtn then multiBtn:Hide() end

    -- 5s timeout: auto-decline non-responders
    MP.inviteTimer = C_Timer.NewTimer(5, function()
        MP.inviteTimer = nil
        if not MP.invitePending then return end

        -- Mark non-responders as declined
        for name in pairs(MP.invited) do
            if not MP.accepted[name] and not MP.declined[name] then
                MP.declined[name] = true
            end
        end

        local acceptCount = 0
        for _ in pairs(MP.accepted) do acceptCount = acceptCount + 1 end

        if acceptCount > 0 then
            AnnounceGameStart()
            addonTable.Comm.Send("GAME", "START", BuildStartPayload())
            StartMPGame()
            if gameFrame then gameFrame:Show() end
            StartGame()
        else
            CancelInvite()
            MPStatusMsg("|cFFFF4444No one accepted in time.|r")
        end
    end)
end

-- ============================================================
-- Frame construction
-- ============================================================
BuildUI = function()
    -- ── Root window ──────────────────────────────────────────
    local SIDE_W = 200   -- wide enough for two 90px buttons + gap
    local totalW = BOARD_W + PADDING * 3 + SIDE_W
    local totalH = BOARD_H + PADDING * 2 + 30  -- board drives height (526px)

    gameFrame = CreateFrame("Frame", "LunaUITweaks_BlockGame", UIParent, "BackdropTemplate")
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
    border:SetPoint("TOPLEFT",     gameFrame, "TOPLEFT",      0,  0)
    border:SetPoint("BOTTOMRIGHT", gameFrame, "BOTTOMRIGHT",  0,  0)
    border:SetColorTexture(0.3, 0.3, 0.35, 1)

    -- Title bar (a real frame so it receives mouse events for dragging)
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
    title:SetText("|cFFFFD100Block Game|r  |cFF888888drag title to move|r")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, gameFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", gameFrame, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function()
        gameFrame:Hide()
        if gravityTicker then gravityTicker:Cancel(); gravityTicker = nil end
        if flashTicker then flashTicker:Cancel(); flashTicker = nil end
        gameActive = false
        if MP.active then
            addonTable.Comm.Send("GAME", "GAMEOVER", "")
            EndMPGame(nil)
        end
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
    local sideX   = BOARD_W + PADDING * 2
    local sideTopY = PADDING + 30

    -- Preview label
    local previewLabel = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    previewLabel:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", sideX, -sideTopY)
    previewLabel:SetText("Next")

    -- Preview grid (4×4)
    local previewFrame = CreateFrame("Frame", nil, gameFrame)
    previewFrame:SetSize(PREVIEW_CELL * 4, PREVIEW_CELL * 4)
    previewFrame:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", sideX, -(sideTopY + 16))

    local prevBg = previewFrame:CreateTexture(nil, "BACKGROUND")
    prevBg:SetAllPoints()
    prevBg:SetColorTexture(0.05, 0.05, 0.07, 1)

    previewCells = {}
    for r = 1, 4 do
        previewCells[r] = {}
        for c = 1, 4 do
            previewCells[r][c] = BuildCellFrame(
                previewFrame, PREVIEW_CELL,
                (c - 1) * PREVIEW_CELL,
                (r - 1) * PREVIEW_CELL
            )
        end
    end

    -- HUD text
    local hudY = sideTopY + 16 + PREVIEW_CELL * 4 + 12

    scoreText = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scoreText:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", sideX, -hudY)
    scoreText:SetJustifyH("LEFT")
    scoreText:SetText("Score\n0")

    levelText = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    levelText:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", sideX, -(hudY + 40))
    levelText:SetJustifyH("LEFT")
    levelText:SetText("Level\n0")

    linesText = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    linesText:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", sideX, -(hudY + 80))
    linesText:SetJustifyH("LEFT")
    linesText:SetText("Lines\n0")

    highScoreText = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    highScoreText:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", sideX, -(hudY + 120))
    highScoreText:SetJustifyH("LEFT")
    highScoreText:SetText("Best\n0")

    -- Status text (multiplayer messages)
    MP.statusText = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    MP.statusText:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", sideX, -(hudY + 165))
    MP.statusText:SetWidth(SIDE_W - 4)
    MP.statusText:SetJustifyH("LEFT")
    MP.statusText:SetWordWrap(true)
    MP.statusText:Hide()

    -- Multiplayer button (shown only when party members have addon)
    multiBtn = CreateFrame("Button", nil, gameFrame, "UIPanelButtonTemplate")
    multiBtn:SetSize(SIDE_W - 4, 24)
    multiBtn:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", sideX, -(hudY + 200))
    multiBtn:SetText("Multiplayer")
    multiBtn:SetScript("OnClick", SendMultiplayerInvite)
    multiBtn:Hide()

    -- ── Control buttons (anchored to bottom of frame) ────────
    local BTN_W = 90
    local BTN_H = 26
    local BTN_GAP = 4
    local BOTTOM_PAD = 8

    -- Keybind display above buttons — one row per action, label left / key right
    local BIND_W = SIDE_W - 4
    local BIND_ROW_H = 13
    local bindBaseY = BOTTOM_PAD + 4 * (BTN_H + BTN_GAP) + 6

    local BINDS = {
        { label = "Move Left",  binding = "LUNAUITWEAKS_GAME_LEFT" },
        { label = "Move Right", binding = "LUNAUITWEAKS_GAME_RIGHT" },
        { label = "Rotate CW",  binding = "LUNAUITWEAKS_GAME_ROTATECW" },
        { label = "Rotate CCW", binding = "LUNAUITWEAKS_GAME_ROTATECCW" },
        { label = "Soft Drop",  binding = "LUNAUITWEAKS_GAME_SOFTDROP" },
        { label = "Hard Drop",  binding = "LUNAUITWEAKS_GAME_HARDDROP" },
        { label = "Pause",      binding = "LUNAUITWEAKS_GAME_PAUSE" },
    }

    local bindKeyLabels = {}
    for i, entry in ipairs(BINDS) do
        local rowY = bindBaseY + (#BINDS - i) * BIND_ROW_H

        local lbl = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("BOTTOMLEFT", gameFrame, "BOTTOMLEFT", sideX, rowY)
        lbl:SetWidth(BIND_W)
        lbl:SetJustifyH("LEFT")
        lbl:SetTextColor(0.6, 0.6, 0.6)
        lbl:SetText(entry.label)

        local key = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        key:SetPoint("BOTTOMRIGHT", gameFrame, "BOTTOMLEFT", sideX + BIND_W, rowY)
        key:SetWidth(BIND_W)
        key:SetJustifyH("RIGHT")
        bindKeyLabels[i] = { fs = key, binding = entry.binding }
    end

    local function RefreshBindings()
        for _, row in ipairs(bindKeyLabels) do
            local k = GetBindingKey(row.binding)
            if k then
                row.fs:SetText(k)
                row.fs:SetTextColor(1, 0.82, 0)
            else
                row.fs:SetText("unbound")
                row.fs:SetTextColor(0.5, 0.5, 0.5)
            end
        end
    end
    RefreshBindings()
    gameFrame:HookScript("OnShow", RefreshBindings)

    local function MakeBtn(label, col, row, onClick)
        local btn = CreateFrame("Button", nil, gameFrame, "UIPanelButtonTemplate")
        btn:SetSize(BTN_W, BTN_H)
        -- row 1 = bottom row, row 4 = top row (building upward from bottom)
        local bx = sideX + (col - 1) * (BTN_W + BTN_GAP)
        local by = BOTTOM_PAD + (row - 1) * (BTN_H + BTN_GAP)
        btn:SetPoint("BOTTOMLEFT", gameFrame, "BOTTOMLEFT", bx, by)
        btn:SetText(label)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    -- Row 1 (bottom): Pause / New Game
    MakeBtn("Pause",     1, 1, TogglePause)
    MakeBtn("New Game",  2, 1, StartGame)
    -- Row 2: Soft Drop / Hard Drop
    MakeBtn("Soft Drop", 1, 2, SoftDrop)
    MakeBtn("Hard Drop", 2, 2, HardDrop)
    -- Row 3: Rot CCW / Rot CW
    MakeBtn("Rot CCW",   1, 3, RotateCCW)
    MakeBtn("Rot CW",    2, 3, RotateCW)
    -- Row 4 (top): Left / Right
    MakeBtn("< Left",    1, 4, MoveLeft)
    MakeBtn("Right >",   2, 4, MoveRight)

    -- Pause overlay text
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
    goBtn:SetScript("OnClick", function()
        if MP.active then return end  -- don't restart mid-MP session
        StartGame()
    end)

    gameOverFrame:Hide()

    -- Hook GROUP_ROSTER_UPDATE to refresh multiBtn visibility
    addonTable.EventBus.Register("GROUP_ROSTER_UPDATE", function()
        UpdateMultiBtn()
    end)
    -- Also hook AddonVersions callback
    if addonTable.AddonVersions then
        local origCb = addonTable.AddonVersions.onVersionsUpdated
        addonTable.AddonVersions.onVersionsUpdated = function()
            if origCb then origCb() end
            UpdateMultiBtn()
        end
    end
end

-- Close the game when combat starts
addonTable.EventBus.Register("PLAYER_REGEN_DISABLED", function()
    if gameFrame and gameFrame:IsShown() then
        gameFrame:Hide()
        if gravityTicker then gravityTicker:Cancel(); gravityTicker = nil end
        if flashTicker   then flashTicker:Cancel();   flashTicker = nil end
        gameActive = false
        if MP.active then
            addonTable.Comm.Send("GAME", "GAMEOVER", "")
            EndMPGame(nil)
        end
    end
end)

-- ============================================================
-- Public API
-- ============================================================
function addonTable.Blocks.ShowGame()
    if not gameFrame then
        BuildUI()  -- BuildUI is forward-declared so this is always valid
    end
    if gameFrame:IsShown() then
        gameFrame:Hide()
        if gravityTicker then gravityTicker:Cancel(); gravityTicker = nil end
        if flashTicker   then flashTicker:Cancel();   flashTicker = nil end
        gameActive = false
        if MP.active then
            addonTable.Comm.Send("GAME", "GAMEOVER", "")
            EndMPGame(nil)
        end
    else
        gameFrame:Show()
        UpdateMultiBtn()
        if not gameActive then
            StartGame()
        end
    end
end

-- Global keybinding handlers — only act when game is open
local function GameIsOpen() return gameFrame and gameFrame:IsShown() end
function LunaUITweaks_Game_Left()      if GameIsOpen() then MoveLeft()    end end
function LunaUITweaks_Game_Right()     if GameIsOpen() then MoveRight()   end end
function LunaUITweaks_Game_RotateCW()  if GameIsOpen() then RotateCW()    end end
function LunaUITweaks_Game_RotateCCW() if GameIsOpen() then RotateCCW()   end end
function LunaUITweaks_Game_SoftDrop()  if GameIsOpen() then SoftDrop()    end end
function LunaUITweaks_Game_HardDrop()  if GameIsOpen() then HardDrop()    end end
function LunaUITweaks_Game_Pause()     if GameIsOpen() then TogglePause() end end
