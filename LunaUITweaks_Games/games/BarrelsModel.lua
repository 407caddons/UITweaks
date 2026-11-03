local addon = _G.LunaUITweaks
local Model = {}
addon.BarrelsModel = Model

function Model.New(random)
    return {phase = "ready", round = 0, count = 0, time = 0, slots = {}, random = random or math.random}
end

function Model.Layout(count, width, height)
    -- Refine a stable lattice when more cells are needed. Existing cell
    -- indices and coordinates stay fixed even when the board gains cells.
    local slots = {}
    local spacingX, spacingY = width / 5, height / 3
    local level = 0
    repeat
        local columns, rows = 4 * 2 ^ level + 1, 2 * 2 ^ level + 1
        for row = 0, rows - 1 do
            for column = 0, columns - 1 do
                -- Earlier levels already contain the even/even points.
                if level == 0 or row % 2 ~= 0 or column % 2 ~= 0 then
                    slots[#slots + 1] = {x = width / 10 + column * spacingX, y = height / 6 + row * spacingY}
                end
            end
        end
        if #slots >= math.max(15, count * 2) then break end
        level = level + 1
        spacingX = spacingX / 2
        spacingY = spacingY / 2
    until false
    -- Round ten has twelve barrels and uses the first refined grid.
    -- Start at that size; shrink further only when later grids need it.
    local size = math.min(width / 10 * .65, height / 6 * .65, spacingX * .65, spacingY * .65)
    return slots, size
end

local function Shuffle(state, values)
    for i = #values, 2, -1 do
        local j = state.random(i)
        values[i], values[j] = values[j], values[i]
    end
end

-- Require an interior intersection; merely sharing an endpoint does not count.
function Model.PathsCross(a, b, c, d)
    local function Side(p, q, r)
        return (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x)
    end
    return Side(a, b, c) * Side(a, b, d) < 0 and Side(c, d, a) * Side(c, d, b) < 0
end

function Model.StartRound(state, round)
    local continuing = round == state.round + 1 and state.phase == "correct"
    local previousCount = continuing and state.count or 0
    state.round = round
    state.count = round + 2
    if not continuing then state.slots = {} end
    state.grid, state.size = Model.Layout(state.count, 720, 400)
    local occupied = {}
    for id = 1, previousCount do occupied[state.slots[id]] = true end
    local cells = {}
    for i = 1, #state.grid do
        if not occupied[i] then cells[#cells + 1] = i end
    end
    Shuffle(state, cells)
    for id = previousCount + 1, state.count do state.slots[id] = cells[id - previousCount] end
    state.target = state.random(state.count)
    state.phase = "mark"
    state.time = 0
    state.move = nil
    state.choice = nil
    state.moves = 0
    state.targetMoves = 0
    state.moveCount = math.min(20, round + 4)
    state.moveDuration = math.max(.32, .72 - (round - 1) * .025)
    state.paused = false
end

local function BeginMove(state)
    -- All barrels move to independently chosen cells, including at least
    -- one previously empty cell. Reject layouts without crossing paths.
    local move = {ids = {}, from = {}, to = {}}
    local occupied = {}
    for id = 1, state.count do
        move.ids[id] = id
        move.from[id] = state.slots[id]
        occupied[state.slots[id]] = true
    end
    local cells = {}
    for i = 1, #state.grid do cells[i] = i end
    local accepted = false
    for attempt = 1, 80 do
        Shuffle(state, cells)
        local valid, empty = true, false
        for id = 1, state.count do
            move.to[id] = cells[id]
            if cells[id] == move.from[id] then valid = false end
            if not occupied[cells[id]] then empty = true end
        end
        if valid and empty then
            for a = 1, state.count - 1 do
                for b = a + 1, state.count do
                    if Model.PathsCross(state.grid[move.from[a]], state.grid[move.to[a]],
                        state.grid[move.from[b]], state.grid[move.to[b]]) then
                        accepted = true
                        break
                    end
                end
                if accepted then break end
            end
        end
        if accepted then break end
    end
    if not accepted then
        -- Bounded fallback: opposite paths meet halfway, while a third barrel
        -- moves into an empty cell. No retry loop can stall the UI.
        for id = 1, state.count do move.to[id] = move.from[id % state.count + 1] end
        move.to[1], move.to[2] = move.from[2], move.from[1]
        local used = {[move.to[1]] = true, [move.to[2]] = true}
        for id = 3, state.count do
            for _, cell in ipairs(cells) do
                if not used[cell] and cell ~= move.from[id] and (id ~= 3 or not occupied[cell]) then
                    move.to[id] = cell
                    used[cell] = true
                    break
                end
            end
        end
    end
    state.move = move
    state.time = 0
end

function Model.Step(state, elapsed)
    if state.paused or state.phase == "ready" or state.phase == "guess" or state.phase == "wrong" then return false end
    -- Slow down through a hitch rather than jumping through unseen swaps.
    state.time = state.time + math.min(.05, math.max(0, elapsed))
    if state.phase == "mark" and state.time >= 1.6 then
        state.phase = "cover"
        state.time = 0
        return true
    elseif state.phase == "cover" and state.time >= .35 then
        state.phase = "shuffle"
        BeginMove(state)
        return true
    elseif state.phase == "shuffle" and state.time >= state.moveDuration then
        local move = state.move
        for _, id in ipairs(move.ids) do state.slots[id] = move.to[id] end
        if move.from[state.target] then state.targetMoves = state.targetMoves + 1 end
        state.moves = state.moves + 1
        if state.moves >= state.moveCount then
            state.phase = "guess"
            state.time = 0
            state.move = nil
        else BeginMove(state) end
        return true
    elseif state.phase == "correct" and state.time >= 1.1 then
        Model.StartRound(state, state.round + 1)
        return true
    end
    return false
end

function Model.Position(state, id, layout)
    local origin = layout[state.slots[id]]
    local move = state.move
    if state.phase ~= "shuffle" or not move or not move.from[id] then return origin.x, origin.y end
    local first = layout[move.from[id]]
    local last = layout[move.to[id]]
    local t = math.min(1, state.time / state.moveDuration)
    -- Smooth acceleration/deceleration while following an exact straight line.
    t = t * t * (3 - 2 * t)
    return first.x + (last.x - first.x) * t, first.y + (last.y - first.y) * t
end

function Model.Guess(state, id)
    if state.paused or state.phase ~= "guess" or type(id) ~= "number" or id % 1 ~= 0 or id < 1 or id > state.count then return nil end
    state.choice = id
    state.time = 0
    local correct = id == state.target
    state.phase = correct and "correct" or "wrong"
    return correct
end
