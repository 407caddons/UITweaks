local _, Bars = ...
_G.LunaUITweaksActionBars = Bars
Bars.definitions = {
    {"MainActionBar", "Action Bar 1"}, {"MultiBarBottomLeft", "Action Bar 2"},
    {"MultiBarBottomRight", "Action Bar 3"}, {"MultiBarRight", "Action Bar 4"},
    {"MultiBarLeft", "Action Bar 5"}, {"MultiBar5", "Action Bar 6"},
    {"MultiBar6", "Action Bar 7"}, {"MultiBar7", "Action Bar 8"},
    {"PetActionBar", "Pet Bar", count=10, y=-140, size=30},
    {"MicroMenu", "Micro Menu", kind="group", count=1, y=-310, size=30},
    {"BagsBar", "Bag Bar", kind="group", count=1, y=-355, size=36},
}
local function Number(value, default, lo, hi)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return default end
    return math.max(lo, math.min(hi, value))
end
function Bars.Settings()
    if type(LunaUITweaksActionBarsDB) ~= "table" then LunaUITweaksActionBarsDB = {} end
    local db = LunaUITweaksActionBarsDB
    db.enabled = db.enabled ~= false
    if type(db.bars) ~= "table" then db.bars = {} end
    for i, definition in ipairs(Bars.definitions) do
        local key = definition[1]
        if type(db.bars[key]) ~= "table" then db.bars[key] = {} end
        local s = db.bars[key]
        s.enabled = s.enabled ~= false
        s.hidden = s.hidden == true
        s.size = Number(s.size, definition.size or 36, 16, 80)
        s.spacing = Number(s.spacing, 2, 0, 24)
        s.columns = math.floor(Number(s.columns, definition.count or 12, 1, definition.count or 12))
        s.rows = math.ceil((definition.count or 12)/s.columns)
        s.x = Number(s.x, 0, -10000, 10000)
        s.y = Number(s.y, definition.y or (-220 + (i-1)*44), -10000, 10000)
        s.hideBindings = s.hideBindings ~= false
        s.hideMacros = s.hideMacros ~= false
        s.square = s.square ~= false
        s.border = s.border ~= false
    end
    return db
end
function Bars.Conflict()
    for _, name in ipairs({"Dominos", "Bartender4", "ElvUI", "EllesmereUIActionBars"}) do
        if C_AddOns and C_AddOns.IsAddOnLoaded(name) then return name end
    end
end
function Bars.EditModeActive()
    return EditModeManagerFrame and EditModeManagerFrame:IsShown() or false
end
-- A bounded log is persisted so combat-reload failures can be reported afterwards.
function Bars.Log(message)
    local db = Bars.Settings()
    if type(db.log) ~= "table" then db.log = {} end
    db.log[#db.log+1] = date("%H:%M:%S") .. " " .. message
    while #db.log > 100 do table.remove(db.log, 1) end
    if db.debug then print("Luna Action Bars: " .. message) end
end
function Bars.Geometry(s, count)
    local columns = math.min(s.columns, math.max(count, 1))
    local rows = math.ceil(count / columns)
    if count==0 then return 0,0,columns end
    return columns*s.size + (columns-1)*s.spacing, rows*s.size + math.max(0, rows-1)*s.spacing, columns
end

-- Keep internal empty slots in place, but do not border hidden trailing slots.
function Bars.VisibleCount(buttons)
    for i=#buttons,1,-1 do if buttons[i]:IsShown() then return i end end
    return 0
end

function Bars.SetGrid(settings, axis, value, count)
    count=count or 12
    value=math.floor(Number(value,1,1,count))
    if axis=="rows" then settings.columns=math.ceil(count/value)
    else settings.columns=value end
    settings.rows=math.ceil(count/settings.columns)
end

function Bars.Definition(key)
    for _,definition in ipairs(Bars.definitions) do if definition[1]==key then return definition end end
end
function Bars.StateGeometry(settings,state)
    if state.kind=="group" then
        local height=state.bar:GetHeight()
        if height<=0 then return 0,0 end
        return state.bar:GetWidth()*settings.size/height,settings.size
    end
    return Bars.Geometry(settings,Bars.VisibleCount(state.buttons))
end
