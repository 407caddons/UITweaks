local addon = _G.LunaUITweaks
local Game, Model = {}, addon.BarrelsModel
addon.Barrels = Game
local frame, board, state, layout, size
local barrels = {}
local WIDTH, HEIGHT = 720, 400
local Render, SyncDriver

local function DB()
    UIThingsDB.games = UIThingsDB.games or {}
    local db = UIThingsDB.games.barrels
    if type(db) ~= "table" then
        db = {}
        UIThingsDB.games.barrels = db
    end
    if type(db.bestRound) ~= "number" or db.bestRound ~= db.bestRound or db.bestRound == math.huge or db.bestRound < 0 then db.bestRound = 0 end
    db.bestRound = math.floor(db.bestRound)
    return db
end
local function Text(parent, text, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetText(text)
    return label
end
local function Button(parent, text, width, click)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 26)
    button:SetText(text)
    button:SetScript("OnClick", click)
    return button
end
local function Place(id)
    local x, y = Model.Position(state, id, layout)
    -- One permanent anchor: SetPoint replaces its offsets without clearing
    -- anchors, hiding frames, or rebuilding textures during animation.
    barrels[id]:SetPoint("CENTER", board, "BOTTOMLEFT", x, y)
end
local function MakeBarrel(id)
    local barrel = CreateFrame("Button", nil, board)
    barrel:RegisterForClicks("LeftButtonUp")
    -- Persistent scanlines form a circular iron rim and wooden lid viewed
    -- from above. Geometry is built once, never recreated while moving.
    barrel.rim = {}
    barrel.wood = {}
    for row = 1, 32 do
        local rim = barrel:CreateTexture(nil, "ARTWORK")
        rim:SetColorTexture(.19, .20, .21, 1)
        barrel.rim[row] = rim
        local wood = barrel:CreateTexture(nil, "OVERLAY")
        local shade = math.floor((row - 1) / 5) % 2 == 0 and 1 or .84
        wood:SetColorTexture(.55 * shade, .33 * shade, .13 * shade, 1)
        barrel.wood[row] = wood
    end
    barrel.marker = CreateFrame("Frame", nil, barrel, "BackdropTemplate")
    barrel.marker:SetPoint("TOPLEFT", -5, 5)
    barrel.marker:SetPoint("BOTTOMRIGHT", 5, -5)
    barrel.marker:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 3})
    barrel.marker:EnableMouse(false)
    barrel.star = Text(barrel, "*", "GameFontNormalHuge")
    barrel.star:SetPoint("BOTTOM", barrel, "TOP", 0, 5)
    barrel:SetScript("OnClick", function()
        local correct = Model.Guess(state, id)
        if correct == nil then return end
        if correct then DB().bestRound = math.max(DB().bestRound, state.round) end
        Render(true)
        SyncDriver()
    end)
    barrels[id] = barrel
    return barrel
end
local function ResizeBarrel(barrel)
    barrel:SetSize(size, size)
    for row = 1, 32 do
        local y = (row - .5) / 32 * 2 - 1
        local width = math.sqrt(math.max(0, 1 - y * y))
        local rim, wood = barrel.rim[row], barrel.wood[row]
        rim:SetSize(size * width, size / 32 + .25)
        rim:SetPoint("CENTER", barrel, "CENTER", 0, -y * size / 2)
        wood:SetSize(size * .83 * width, size * .83 / 32 + .25)
        wood:SetPoint("CENTER", barrel, "CENTER", 0, -y * size * .83 / 2)
    end
end
local function NewGame()
    Model.StartRound(state, 1)
    Render(true)
    SyncDriver()
end
local function Pause()
    if state.phase == "ready" or state.phase == "wrong" then return end
    state.paused = not state.paused
    Render(false)
    SyncDriver()
end
Render = function(reposition)
    if not frame then return end
    if frame.layoutCount ~= state.count then
        frame.layoutCount = state.count
        layout, size = Model.Layout(state.count, WIDTH, HEIGHT)
        for id = 1, state.count do ResizeBarrel(barrels[id] or MakeBarrel(id)) end
        reposition = true
    end
    local messages = {
        ready = "Press New Game to begin.",
        mark = "Remember the marked barrel.",
        cover = "Keep your eyes on it...",
        shuffle = "Follow the barrel.",
        guess = "Click the barrel that was marked.",
        correct = "Correct! Adding another barrel...",
        wrong = "Wrong barrel. The green outline shows the original.",
    }
    frame.status:SetText(state.paused and "Paused" or messages[state.phase])
    frame.score:SetFormattedText("Round %d   |   %d barrels   |   Best round: %d", state.round, state.count, DB().bestRound)
    frame.pause:SetText(state.paused and "Resume" or "Pause")
    frame.pause:SetEnabled(state.phase ~= "ready" and state.phase ~= "wrong")
    frame.cover:SetShown(state.paused)
    for id, barrel in ipairs(barrels) do
        barrel:SetShown(id <= state.count)
        if id <= state.count then
            if reposition then Place(id) end
            barrel:EnableMouse(not state.paused and state.phase == "guess")
            local target = id == state.target and (state.phase == "mark" or state.phase == "correct" or state.phase == "wrong")
            local wrong = state.phase == "wrong" and id == state.choice and not target
            barrel.marker:SetShown(target or wrong)
            barrel.marker:SetBackdropBorderColor(target and .35 or .9, target and .95 or .15, .2, 1)
            barrel.star:SetShown(target and state.phase == "mark")
        end
    end
end
local function OnUpdate(_, elapsed)
    local changed = Model.Step(state, elapsed)
    if changed then
        Render(true)
        SyncDriver()
    elseif state.phase == "shuffle" and state.move then
        for _, id in ipairs(state.move.ids) do Place(id) end
    end
end
SyncDriver = function()
    local running = frame:IsShown() and not state.paused and (state.phase == "mark" or state.phase == "cover" or state.phase == "shuffle" or state.phase == "correct")
    frame:SetScript("OnUpdate", running and OnUpdate or nil)
end

local function BuildUI()
    state = Model.New()
    layout = {}
    frame = CreateFrame("Frame", "LunaUITweaks_Barrels", UIParent, "BackdropTemplate")
    frame:SetSize(760, 550)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    frame:SetBackdropColor(.035, .045, .06, 1)
    frame:SetBackdropBorderColor(.3, .35, .4, 1)
    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(true)
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    local title = Text(frame, "Barrels  |cff888888— follow the marked barrel|r", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -14)
    local close = Button(frame, "X", 26, Game.CloseGame)
    close:SetPoint("TOPRIGHT", -8, -8)
    frame.score = Text(frame, "")
    frame.score:SetPoint("TOPLEFT", 18, -44)
    board = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    board:SetSize(WIDTH, HEIGHT)
    board:SetPoint("TOPLEFT", 20, -72)
    board:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
    board:SetBackdropColor(.07, .085, .10, 1)
    frame.cover = CreateFrame("Frame", nil, board, "BackdropTemplate")
    frame.cover:SetAllPoints()
    frame.cover:SetFrameLevel(board:GetFrameLevel() + 20)
    frame.cover:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
    frame.cover:SetBackdropColor(.035, .045, .06, 1)
    frame.cover:EnableMouse(true)
    local paused = Text(frame.cover, "PAUSED", "GameFontNormalHuge")
    paused:SetPoint("CENTER")
    frame.status = Text(frame, "")
    frame.status:SetPoint("BOTTOMLEFT", 20, 48)
    frame.pause = Button(frame, "Pause", 100, Pause)
    frame.pause:SetPoint("BOTTOMLEFT", 20, 12)
    local restart = Button(frame, "New Game", 110, NewGame)
    restart:SetPoint("LEFT", frame.pause, "RIGHT", 10, 0)
    local help = Text(frame, "3 barrels to start. One more each correct round.", "GameFontHighlightSmall")
    help:SetPoint("BOTTOMRIGHT", -20, 20)
    frame:SetScript("OnHide", function()
        state.paused = true
        frame:SetScript("OnUpdate", nil)
    end)
    table.insert(UISpecialFrames, "LunaUITweaks_Barrels")
    frame:Hide()
end
function Game.CloseGame()
    if frame then frame:Hide() end
end
function Game.ShowGame()
    if addon.Config and addon.Config.CloseWindow then addon.Config.CloseWindow() end
    if frame and frame:IsShown() then
        Game.CloseGame()
        return
    end
    for _, key in ipairs({"Snek", "Bombs", "Gems", "Cards", "Game2048", "Boxes", "Slide", "Lights", "Blocks"}) do
        local other = addon[key]
        if other and other.CloseGame then other.CloseGame() end
    end
    if not frame then BuildUI() end
    frame:SetScale(math.max(.1, math.min(1, (UIParent:GetWidth() - 30) / 760, (UIParent:GetHeight() - 30) / 550)))
    frame:Show()
    if state.phase == "ready" then NewGame()
    else
        state.paused = false
        Render(true)
        SyncDriver()
    end
end
addon.EventBus.Register("PLAYER_REGEN_DISABLED", function()
    if not frame or not frame:IsShown() then return end
    if UIThingsDB.games.closeInCombat then Game.CloseGame()
    else
        state.paused = true
        Render(false)
        SyncDriver()
    end
end, "Game:Barrels")
