local addonName, addonTable = ...
addonTable.Cards = {}

-- ============================================================
-- Constants
-- ============================================================
local CARD_W     = 50
local CARD_H     = 70
local PADDING    = 10
local STACK_Y    = 20   -- Y offset for stacked cards in tableau

local CARD_FONT = "Interface\\AddOns\\LunaUITweaks\\fonts\\NotoSans-Regular.ttf"
local SUIT_FONT = "Interface\\AddOns\\LunaUITweaks\\fonts\\NotoSansSymbols2-Regular.ttf"

-- Colors for suits
local COLOR_RED   = "|cFFDD2222"
local COLOR_BLACK = "|cFF222222"

local SUITS = {
    { icon = "\226\153\165", color = COLOR_RED },   -- ♥
    { icon = "\226\153\166", color = COLOR_RED },   -- ♦
    { icon = "\226\153\163", color = COLOR_BLACK }, -- ♣
    { icon = "\226\153\160", color = COLOR_BLACK }, -- ♠
}
local VALUES = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }

-- ============================================================
-- State
-- ============================================================
local gameFrame
local boardFrame
local cards = {}          -- pool of card frame objects

local deck = {}           -- unplayed cards (face down)
local waste = {}          -- drawn cards (face up)
local foundations = {{}, {}, {}, {}}  -- 4 piles (A -> K)
local tableau = {{}, {}, {}, {}, {}, {}, {}} -- 7 columns

local selLoc = nil
local moves = 0
local movesText

-- Drag state
local dragFrame       -- single floating frame stack shown while dragging
local dragCards = {}  -- card data being dragged (1..n)
local dragLoc  = nil  -- source clickZone
local dragOffX, dragOffY = 0, 0
local isDragging = false

-- ============================================================
-- Forward Declarations
-- ============================================================
local BuildUI, LayoutCards, StartGame, HandleClick, MoveCards
local IsValidMove

-- ============================================================
-- Core Logic
-- ============================================================
local function CreateDeck()
    local temp = {}
    local id = 1
    for s = 1, 4 do
        for v = 1, 13 do
            temp[id] = { id = id, suit = s, val = v, faceUp = false }
            id = id + 1
        end
    end
    for i = 52, 2, -1 do
        local j = math.random(i)
        temp[i], temp[j] = temp[j], temp[i]
    end
    return temp
end

local function Deal()
    deck = CreateDeck()
    waste = {}
    foundations = {{}, {}, {}, {}}
    tableau = {{}, {}, {}, {}, {}, {}, {}}
    for col = 1, 7 do
        for row = 1, col do
            local card = table.remove(deck)
            if row == col then card.faceUp = true end
            table.insert(tableau[col], card)
        end
    end
end

-- ============================================================
-- Rendering helpers
-- ============================================================
local function SetCardAppearance(frame, cardData)
    if cardData.id and cardData.faceUp then
        frame.bg:SetColorTexture(0.9, 0.9, 0.9, 1)
        local suit = SUITS[cardData.suit]
        local valText  = suit.color .. VALUES[cardData.val] .. "|r"
        local suitText = suit.color .. suit.icon .. "|r"
        frame.label:SetText(valText)
        frame.suitLabel:SetText(suitText)
        frame.suitLabel:Show()
        if frame.labelBR then
            frame.labelBR:SetText(valText)
            frame.labelBR:Show()
            frame.suitLabelBR:SetText(suitText)
            frame.suitLabelBR:Show()
        end
    elseif cardData.id then
        frame.bg:SetColorTexture(0.2, 0.3, 0.6, 1)
        frame.label:SetText("")
        frame.suitLabel:Hide()
        if frame.labelBR then frame.labelBR:SetText(""); frame.labelBR:Hide() end
        if frame.suitLabelBR then frame.suitLabelBR:Hide() end
    else
        frame.bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)
        frame.label:SetText("")
        frame.suitLabel:Hide()
        if frame.labelBR then frame.labelBR:SetText(""); frame.labelBR:Hide() end
        if frame.suitLabelBR then frame.suitLabelBR:Hide() end
    end
end

local function UpdateCardFrame(frame, cardData)
    if not cardData then
        frame:Hide()
        return
    end
    frame.cardData = cardData
    frame:Show()
    SetCardAppearance(frame, cardData)

    local isSelected = selLoc and selLoc.cardData == cardData
    if isSelected then
        frame.highlight:Show()
    else
        frame.highlight:Hide()
    end
end

-- Refresh only the selection highlight on all visible card frames.
-- Used when only selLoc changes (no structural board change).
local function RefreshHighlights()
    for i = 1, #cards do
        local f = cards[i]
        if f:IsShown() and f.cardData and f.cardData.id then
            local isSelected = selLoc and selLoc.cardData == f.cardData
            if isSelected then
                f.highlight:Show()
            else
                f.highlight:Hide()
            end
        end
    end
    if movesText then movesText:SetText("Moves: " .. moves) end
end

-- ============================================================
-- Drag ghost frames
-- ============================================================
local function BuildMiniCardFrame(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(CARD_W, CARD_H)
    f.border = f:CreateTexture(nil, "BACKGROUND")
    f.border:SetAllPoints()
    f.border:SetColorTexture(0, 0, 0, 1)
    f.bg = f:CreateTexture(nil, "ARTWORK")
    f.bg:SetPoint("TOPLEFT", 1, -1)
    f.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    f.label = f:CreateFontString(nil, "OVERLAY")
    f.label:SetFont(CARD_FONT, 13)
    f.label:SetPoint("TOPLEFT", 4, -4)
    f.label:SetJustifyH("LEFT")
    f.suitLabel = f:CreateFontString(nil, "OVERLAY")
    f.suitLabel:SetFont(SUIT_FONT, 14)
    f.suitLabel:SetPoint("TOPLEFT", 4, -18)
    f.suitLabel:SetJustifyH("LEFT")
    f.labelBR = f:CreateFontString(nil, "OVERLAY")
    f.labelBR:SetFont(CARD_FONT, 13)
    f.labelBR:SetPoint("BOTTOMRIGHT", -4, 4)
    f.labelBR:SetJustifyH("RIGHT")
    f.suitLabelBR = f:CreateFontString(nil, "OVERLAY")
    f.suitLabelBR:SetFont(SUIT_FONT, 14)
    f.suitLabelBR:SetPoint("BOTTOMRIGHT", -4, 18)
    f.suitLabelBR:SetJustifyH("RIGHT")
    return f
end

local dragGhosts = {}  -- reusable ghost frames inside dragFrame

local function EnsureDragGhosts(n)
    for i = #dragGhosts + 1, n do
        dragGhosts[i] = BuildMiniCardFrame(dragFrame)
    end
    for i = 1, #dragGhosts do
        if i <= n then
            dragGhosts[i]:Show()
        else
            dragGhosts[i]:Hide()
        end
    end
end

local function ShowDragFrame(cardDataList, screenX, screenY)
    local n = #cardDataList
    local totalH = CARD_H + (n - 1) * STACK_Y
    dragFrame:SetSize(CARD_W, totalH)
    dragFrame:ClearAllPoints()
    dragFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", screenX, screenY)
    dragFrame:SetFrameStrata("TOOLTIP")
    dragFrame:Show()

    EnsureDragGhosts(n)
    for i, cd in ipairs(cardDataList) do
        local g = dragGhosts[i]
        g:ClearAllPoints()
        g:SetPoint("TOPLEFT", dragFrame, "TOPLEFT", 0, -((i - 1) * STACK_Y))
        SetCardAppearance(g, cd)
    end
end

local function HideDragFrame()
    dragFrame:Hide()
    for _, g in ipairs(dragGhosts) do g:Hide() end
end

-- ============================================================
-- Drop zone hit-testing
-- ============================================================
-- Returns a clickZone table for whichever zone is under screen coords (x, y),
-- or nil if nothing valid.
local function HitTestZones(x, y)
    -- foundations
    for col = 1, 4 do
        local fx = boardFrame:GetLeft() + PADDING + (col + 2) * (CARD_W + PADDING)
        local fy = boardFrame:GetTop() - PADDING
        if x >= fx and x <= fx + CARD_W and y <= fy and y >= fy - CARD_H then
            local stack = foundations[col]
            if #stack > 0 then
                return { zone = "foundation", col = col, cardData = stack[#stack] }
            else
                return { zone = "foundation", col = col }
            end
        end
    end
    -- tableau columns
    for col = 1, 7 do
        local startX = boardFrame:GetLeft() + PADDING + (col - 1) * (CARD_W + PADDING)
        local stack = tableau[col]
        local startY = boardFrame:GetTop() - (PADDING + CARD_H + PADDING * 2)
        if x >= startX and x <= startX + CARD_W then
            if #stack == 0 then
                if y <= startY and y >= startY - CARD_H then
                    return { zone = "tableau", col = col }
                end
            else
                -- Find the bottom of the entire column's visual area
                local lastRow = #stack
                local topOfColumn = startY
                local bottomOfColumn = startY - ((lastRow - 1) * STACK_Y) - CARD_H

                if y <= topOfColumn and y >= bottomOfColumn then
                    -- Walk from bottom of stack upward; return the topmost face-up card hit
                    for row = lastRow, 1, -1 do
                        local cardY = startY - ((row - 1) * STACK_Y)
                        local cardBottom = (row < lastRow) and (startY - (row * STACK_Y)) or (cardY - CARD_H)
                        if y <= cardY and y >= cardBottom then
                            if stack[row].faceUp then
                                return { zone = "tableau", col = col, row = row, cardData = stack[row] }
                            else
                                -- Cursor is over a face-down card; target the last face-up card instead
                                for r = lastRow, 1, -1 do
                                    if stack[r].faceUp then
                                        return { zone = "tableau", col = col, row = r, cardData = stack[r] }
                                    end
                                end
                                -- All face-down — not a valid drop target
                                return nil
                            end
                        end
                    end
                    -- Cursor is within the column bounds but between cards; use last face-up card
                    for r = lastRow, 1, -1 do
                        if stack[r].faceUp then
                            return { zone = "tableau", col = col, row = r, cardData = stack[r] }
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- ============================================================
-- Layout
-- ============================================================
LayoutCards = function()
    for i = 1, #cards do cards[i]:Hide() end

    local fIdx = 1
    local baseLevel = boardFrame:GetFrameLevel() + 1
    local function GetFrame()
        local f = cards[fIdx]
        fIdx = fIdx + 1
        f:SetFrameLevel(baseLevel + fIdx)
        return f
    end

    -- 1. Deck
    do
        local f = GetFrame()
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", boardFrame, "TOPLEFT", PADDING, -PADDING)
        if #deck > 0 then
            UpdateCardFrame(f, { id = true, faceUp = false })
        else
            UpdateCardFrame(f, {})
        end
        f.clickZone = { zone = "deck" }
    end

    -- 2. Waste
    if #waste > 0 then
        local minW = math.max(1, #waste - 2)
        local offset = 0
        for i = minW, #waste do
            local f = GetFrame()
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", boardFrame, "TOPLEFT", PADDING + CARD_W + PADDING + (offset * 15), -PADDING)
            UpdateCardFrame(f, waste[i])
            if i == #waste then
                f.clickZone = { zone = "waste", cardData = waste[i] }
            else
                f.clickZone = nil
            end
            offset = offset + 1
        end
    end

    -- 3. Foundations
    for col = 1, 4 do
        local stack = foundations[col]
        local f = GetFrame()
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", boardFrame, "TOPLEFT", PADDING + (col + 2) * (CARD_W + PADDING), -PADDING)
        if #stack > 0 then
            UpdateCardFrame(f, stack[#stack])
            f.clickZone = { zone = "foundation", col = col, cardData = stack[#stack] }
        else
            UpdateCardFrame(f, {})
            f.clickZone = { zone = "foundation", col = col }
        end
    end

    -- 4. Tableau
    for col = 1, 7 do
        local stack = tableau[col]
        local startX = PADDING + (col - 1) * (CARD_W + PADDING)
        local startY = -(PADDING + CARD_H + PADDING * 2)
        if #stack == 0 then
            local f = GetFrame()
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", boardFrame, "TOPLEFT", startX, startY)
            UpdateCardFrame(f, {})
            f.clickZone = { zone = "tableau", col = col }
        else
            for row = 1, #stack do
                local f = GetFrame()
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", boardFrame, "TOPLEFT", startX, startY - ((row - 1) * STACK_Y))
                UpdateCardFrame(f, stack[row])
                if stack[row].faceUp then
                    f.clickZone = { zone = "tableau", col = col, row = row, cardData = stack[row] }
                else
                    f.clickZone = nil
                end
            end
        end
    end

    if movesText then movesText:SetText("Moves: " .. moves) end
end

-- ============================================================
-- Game logic
-- ============================================================
local function DrawCard()
    if #deck > 0 then
        local card = table.remove(deck)
        card.faceUp = true
        table.insert(waste, card)
        moves = moves + 1
    else
        while #waste > 0 do
            local card = table.remove(waste)
            card.faceUp = false
            table.insert(deck, card)
        end
        moves = moves + 1
    end
    selLoc = nil
    LayoutCards()
end

IsValidMove = function(srcZone, srcCol, srcRow, destZone, destCol)
    local srcCards = {}
    if srcZone == "waste" then
        srcCards[1] = waste[#waste]
    elseif srcZone == "foundation" then
        srcCards[1] = foundations[srcCol][#foundations[srcCol]]
    elseif srcZone == "tableau" then
        local stack = tableau[srcCol]
        for i = srcRow, #stack do
            table.insert(srcCards, stack[i])
        end
    end
    if #srcCards == 0 then return false end
    local bottomCard = srcCards[1]

    if destZone == "foundation" then
        if #srcCards > 1 then return false end
        local stack = foundations[destCol]
        if #stack == 0 then
            return bottomCard.val == 1
        else
            local top = stack[#stack]
            return bottomCard.suit == top.suit and bottomCard.val == top.val + 1
        end
    elseif destZone == "tableau" then
        local stack = tableau[destCol]
        if #stack == 0 then
            return bottomCard.val == 13
        else
            local top = stack[#stack]
            local srcColor = (bottomCard.suit <= 2) and "red" or "black"
            local topColor = (top.suit <= 2) and "red" or "black"
            return srcColor ~= topColor and bottomCard.val == top.val - 1
        end
    end
    return false
end

MoveCards = function(destZone, destCol)
    if not selLoc then return end
    local srcCards = {}

    if selLoc.zone == "waste" then
        table.insert(srcCards, table.remove(waste))
    elseif selLoc.zone == "foundation" then
        table.insert(srcCards, table.remove(foundations[selLoc.col]))
    elseif selLoc.zone == "tableau" then
        local stack = tableau[selLoc.col]
        local numCards = #stack - selLoc.row + 1
        for i = 1, numCards do
            table.insert(srcCards, table.remove(stack, selLoc.row))
        end
        if #stack > 0 and not stack[#stack].faceUp then
            stack[#stack].faceUp = true
        end
    end

    if destZone == "foundation" then
        table.insert(foundations[destCol], srcCards[1])
    elseif destZone == "tableau" then
        local stack = tableau[destCol]
        for i = 1, #srcCards do
            table.insert(stack, srcCards[i])
        end
    end

    moves = moves + 1
    selLoc = nil

    local won = true
    for i = 1, 4 do
        if #foundations[i] < 13 then won = false; break end
    end

    LayoutCards()
    if won then addonTable.Core.Log("Cards", "Solitaire Cleared in " .. moves .. " moves!", addonTable.Core.LogLevel.INFO) end
end

HandleClick = function(zoneClick)
    if not zoneClick then
        selLoc = nil
        RefreshHighlights()
        return
    end

    if zoneClick.zone == "deck" then
        DrawCard()
        return
    end

    if not selLoc then
        if zoneClick.cardData and zoneClick.cardData.faceUp then
            selLoc = zoneClick
            RefreshHighlights()  -- only highlight changed
        end
    else
        if selLoc.zone == zoneClick.zone and selLoc.cardData == zoneClick.cardData then
            for fCol = 1, 4 do
                if IsValidMove(selLoc.zone, selLoc.col, selLoc.row, "foundation", fCol) then
                    MoveCards("foundation", fCol)
                    return
                end
            end
            selLoc = nil
            RefreshHighlights()  -- only highlight changed
            return
        end

        if zoneClick.zone == "tableau" or zoneClick.zone == "foundation" then
            if IsValidMove(selLoc.zone, selLoc.col, selLoc.row, zoneClick.zone, zoneClick.col) then
                MoveCards(zoneClick.zone, zoneClick.col)
            else
                if zoneClick.cardData and zoneClick.cardData.faceUp then
                    selLoc = zoneClick
                else
                    selLoc = nil
                end
                RefreshHighlights()  -- only highlight changed
            end
        else
            selLoc = nil
            RefreshHighlights()  -- only highlight changed
        end
    end
end

-- ============================================================
-- Drag logic
-- ============================================================
local function GetDragCards(zone)
    if not zone then return {} end
    if zone.zone == "waste" then
        if #waste > 0 then return { waste[#waste] } end
    elseif zone.zone == "foundation" then
        local col = zone.col
        if foundations[col] and #foundations[col] > 0 then
            return { foundations[col][#foundations[col]] }
        end
    elseif zone.zone == "tableau" then
        local col, row = zone.col, zone.row
        if col and row and tableau[col] then
            local result = {}
            local stack = tableau[col]
            for i = row, #stack do
                table.insert(result, stack[i])
            end
            return result
        end
    end
    return {}
end

local function StartDrag(zone, screenX, screenY, cardFrame)
    if not zone or zone.zone == "deck" then return false end
    if not zone.cardData or not zone.cardData.faceUp then return false end

    local cds = GetDragCards(zone)
    if #cds == 0 then return false end

    dragCards = cds
    dragLoc = zone
    isDragging = true
    selLoc = nil

    -- offset so the ghost is picked up exactly where the mouse clicked
    if cardFrame then
        local scale = UIParent:GetEffectiveScale()
        local frameLeft = cardFrame:GetLeft()
        local frameTop  = cardFrame:GetTop()
        dragOffX = frameLeft - screenX
        dragOffY = frameTop  - screenY
    else
        dragOffX = 0
        dragOffY = 0
    end

    ShowDragFrame(dragCards, screenX, screenY)

    dragFrame:SetScript("OnUpdate", function(self)
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (x / scale) + dragOffX, (y / scale) + dragOffY)
    end)

    LayoutCards()
    return true
end

local function CommitDrag(screenX, screenY)
    if not isDragging then return end
    isDragging = false
    dragFrame:SetScript("OnUpdate", nil)
    HideDragFrame()

    -- Use the visual centre of the dragged card's top card for hit-testing
    local ghostX = screenX + dragOffX + CARD_W / 2
    local ghostY = screenY + dragOffY - CARD_H / 2
    local dropZone = HitTestZones(ghostX, ghostY)
    if dropZone and (dropZone.zone == "tableau" or dropZone.zone == "foundation") then
        selLoc = dragLoc
        if IsValidMove(dragLoc.zone, dragLoc.col, dragLoc.row, dropZone.zone, dropZone.col) then
            MoveCards(dropZone.zone, dropZone.col)
            return
        end
    end

    -- snap back — just redraw
    selLoc = nil
    dragLoc = nil
    dragCards = {}
    LayoutCards()
end

local function CancelDrag()
    if not isDragging then return end
    isDragging = false
    dragFrame:SetScript("OnUpdate", nil)
    HideDragFrame()
    selLoc = nil
    dragLoc = nil
    dragCards = {}
    LayoutCards()
end

-- ============================================================
-- Frame Construction
-- ============================================================
local function BuildCardFrame(parent)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(CARD_W, CARD_H)

    f.border = f:CreateTexture(nil, "BACKGROUND")
    f.border:SetAllPoints()
    f.border:SetColorTexture(0, 0, 0, 1)

    f.bg = f:CreateTexture(nil, "ARTWORK")
    f.bg:SetPoint("TOPLEFT", 1, -1)
    f.bg:SetPoint("BOTTOMRIGHT", -1, 1)

    f.label = f:CreateFontString(nil, "OVERLAY")
    f.label:SetFont(CARD_FONT, 13)
    f.label:SetPoint("TOPLEFT", 4, -4)
    f.label:SetJustifyH("LEFT")

    f.suitLabel = f:CreateFontString(nil, "OVERLAY")
    f.suitLabel:SetFont(SUIT_FONT, 14)
    f.suitLabel:SetPoint("TOPLEFT", 4, -18)
    f.suitLabel:SetJustifyH("LEFT")

    f.labelBR = f:CreateFontString(nil, "OVERLAY")
    f.labelBR:SetFont(CARD_FONT, 13)
    f.labelBR:SetPoint("BOTTOMRIGHT", -4, 4)
    f.labelBR:SetJustifyH("RIGHT")

    f.suitLabelBR = f:CreateFontString(nil, "OVERLAY")
    f.suitLabelBR:SetFont(SUIT_FONT, 14)
    f.suitLabelBR:SetPoint("BOTTOMRIGHT", -4, 18)
    f.suitLabelBR:SetJustifyH("RIGHT")

    f.highlight = f:CreateTexture(nil, "OVERLAY")
    f.highlight:SetAllPoints()
    f.highlight:SetColorTexture(1, 1, 0, 0.3)
    f.highlight:Hide()

    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f:RegisterForDrag("LeftButton")

    -- Track mouse-down position to distinguish click vs drag
    local mouseDownX, mouseDownY = 0, 0
    local DRAG_THRESHOLD = 5

    f:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            mouseDownX, mouseDownY = GetCursorPosition()
        end
    end)

    f:SetScript("OnDragStart", function(self)
        if not self.clickZone then return end
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        StartDrag(self.clickZone, x / scale, y / scale, self)
    end)

    f:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if isDragging then
                CancelDrag()
            else
                HandleClick(nil)
            end
            return
        end
        if isDragging then
            -- Released over a card frame — commit using cursor position
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            CommitDrag(x / scale, y / scale)
        else
            if self.clickZone then
                HandleClick(self.clickZone)
            else
                HandleClick(nil)
            end
        end
    end)

    return f
end

BuildUI = function()
    local cols = 7
    local boardW = (cols * CARD_W) + ((cols + 1) * PADDING)
    local boardH = CARD_H * 4 + PADDING * 3
    local sideW = 100
    local totalW = boardW + PADDING * 3 + sideW
    local totalH = boardH + PADDING * 2 + 30

    gameFrame = CreateFrame("Frame", "LunaUITweaks_CardsGame", UIParent)
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

    local title = titleBar:CreateFontString(nil, "OVERLAY")
    title:SetFont(CARD_FONT, 13)
    title:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    title:SetText("|cFF00FF00Solitaire|r  |cFF888888drag title to move|r")

    local closeBtn = CreateFrame("Button", nil, gameFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", gameFrame, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() gameFrame:Hide() end)

    -- Board frame
    boardFrame = CreateFrame("Button", nil, gameFrame)
    boardFrame:SetSize(boardW, boardH)
    boardFrame:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", PADDING, -(PADDING + 30))
    boardFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    boardFrame:SetScript("OnClick", function()
        if isDragging then
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            CommitDrag(x / scale, y / scale)
        else
            HandleClick(nil)
        end
    end)

    local boardBg = boardFrame:CreateTexture(nil, "BACKGROUND")
    boardBg:SetAllPoints()
    boardBg:SetColorTexture(0.1, 0.3, 0.15, 1)

    -- Card pool
    local POOL_SIZE = 70
    for i = 1, POOL_SIZE do
        cards[i] = BuildCardFrame(boardFrame)
    end

    -- Drag frame — parented to UIParent so it floats above everything
    dragFrame = CreateFrame("Frame", nil, UIParent)
    dragFrame:SetFrameStrata("TOOLTIP")
    dragFrame:SetSize(CARD_W, CARD_H)
    dragFrame:Hide()

    -- Follow cursor while dragging (registered/unregistered dynamically)

    -- Drop on mouse-up anywhere
    dragFrame:EnableMouse(true)
    dragFrame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and isDragging then
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            CommitDrag(x / scale, y / scale)
        elseif button == "RightButton" then
            CancelDrag()
        end
    end)

    -- Side panel
    local sideX = boardW + PADDING * 2

    movesText = gameFrame:CreateFontString(nil, "OVERLAY")
    movesText:SetFont(CARD_FONT, 13)
    movesText:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", sideX, -(PADDING + 30))
    movesText:SetJustifyH("LEFT")
    movesText:SetText("Moves: 0")

    local newGameBtn = CreateFrame("Button", nil, gameFrame, "UIPanelButtonTemplate")
    newGameBtn:SetSize(sideW - 4, 26)
    newGameBtn:SetPoint("BOTTOMLEFT", gameFrame, "BOTTOMLEFT", sideX, PADDING)
    newGameBtn:SetText("New Game")
    newGameBtn:SetScript("OnClick", StartGame)

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

-- ============================================================
-- Start / API
-- ============================================================
StartGame = function()
    if InCombatLockdown() then return end
    selLoc = nil
    isDragging = false
    if dragFrame then dragFrame:Hide() end
    moves = 0
    Deal()
    LayoutCards()
end

-- Combat handling
addonTable.EventBus.Register("PLAYER_REGEN_DISABLED", function()
    if not (gameFrame and gameFrame:IsShown()) then return end
    if UIThingsDB.games.closeInCombat then
        gameFrame:Hide()
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

function addonTable.Cards.ShowGame()
    if not gameFrame then BuildUI() end
    if gameFrame:IsShown() then
        gameFrame:Hide()
    else
        boardFrame:EnableMouse(true)
        if gameFrame.pauseOverlay then gameFrame.pauseOverlay:Hide() end
        gameFrame:Show()
        if #deck == 0 and #waste == 0 then
            StartGame()
        end
    end
end
