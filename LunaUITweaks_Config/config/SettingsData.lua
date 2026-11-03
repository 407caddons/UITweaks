local addon = _G.LunaUITweaks
local Data = {}
addon.SettingsData = Data
Data.MAX_DEPTH = 20
Data.MAX_NODES = 200000

local function Finite(value)
    return value == value and value ~= math.huge and value ~= -math.huge
end

-- Read the table-literal subset used by LUIT1 exports. No Lua is compiled or
-- executed, including for string escapes, so functions and expressions cannot run.
function Data.Parse(text)
    local pos, nodes, length = 1, 0, #text
    local function Fail(message) error(message .. " at byte " .. pos, 0) end
    local function Space()
        local _, last = text:find("^%s*", pos)
        pos = (last or pos - 1) + 1
    end
    local function String()
        local quote = text:sub(pos, pos)
        pos = pos + 1
        local parts, start = {}, pos
        while pos <= length do
            local char = text:sub(pos, pos)
            if char == quote then
                parts[#parts + 1] = text:sub(start, pos - 1)
                pos = pos + 1
                return table.concat(parts)
            elseif char == "\\" then
                parts[#parts + 1] = text:sub(start, pos - 1)
                pos = pos + 1
                char = text:sub(pos, pos)
                local escapes = {a = "\a", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t", v = "\v",
                    ["\\"] = "\\", ['"'] = '"', ["'"] = "'", ["\n"] = "\n"}
                if escapes[char] then
                    parts[#parts + 1] = escapes[char]
                    pos = pos + 1
                elseif char:match("%d") then
                    local digits = text:match("^(%d%d?%d?)", pos)
                    local value = tonumber(digits)
                    if value > 255 then Fail("Invalid string escape") end
                    parts[#parts + 1] = string.char(value)
                    pos = pos + #digits
                else Fail("Invalid string escape") end
                start = pos
            elseif char == "\n" or char == "\r" then Fail("Unescaped newline in string")
            else pos = pos + 1 end
        end
        Fail("Unterminated string")
    end
    local Value
    Value = function(depth)
        if depth > Data.MAX_DEPTH then Fail("Settings are nested too deeply") end
        nodes = nodes + 1
        if nodes > Data.MAX_NODES then Fail("Too many settings values") end
        Space()
        local char = text:sub(pos, pos)
        if char == '"' or char == "'" then return String() end
        if char == "{" then
            pos = pos + 1
            Space()
            local result, seen, index = {}, {}, 1
            while text:sub(pos, pos) ~= "}" do
                if pos > length then Fail("Unterminated table") end
                local key, value
                if text:sub(pos, pos) == "[" then
                    pos = pos + 1
                    key = Value(depth + 1)
                    Space()
                    if text:sub(pos, pos) ~= "]" then Fail("Expected ]") end
                    pos = pos + 1
                    Space()
                    if text:sub(pos, pos) ~= "=" then Fail("Expected =") end
                    pos = pos + 1
                    value = Value(depth + 1)
                else
                    local identifier = text:match("^([%a_][%w_]*)%s*=", pos)
                    if identifier then
                        key = identifier
                        local _, last = text:find("^[%a_][%w_]*%s*=", pos)
                        pos = last + 1
                        value = Value(depth + 1)
                    else
                        key = index
                        index = index + 1
                        value = Value(depth + 1)
                    end
                end
                local kind = type(key)
                if kind ~= "string" and kind ~= "number" and kind ~= "boolean" then Fail("Invalid table key") end
                if seen[key] then Fail("Duplicate table key") end
                seen[key] = true
                result[key] = value
                Space()
                char = text:sub(pos, pos)
                if char == "," or char == ";" then
                    pos = pos + 1
                    Space()
                elseif char ~= "}" then Fail("Expected , or }") end
            end
            pos = pos + 1
            return result
        end
        local literal = text:match("^([%a_][%w_]*)", pos)
        if literal then
            pos = pos + #literal
            if literal == "true" then return true end
            if literal == "false" then return false end
            if literal == "nil" then return nil end
            Fail("Only data literals are allowed")
        end
        local number = text:match("^[+-]?%d+%.?%d*[eE][+-]?%d+", pos)
            or text:match("^[+-]?%.%d+[eE][+-]?%d+", pos)
            or text:match("^[+-]?%d+%.?%d*", pos) or text:match("^[+-]?%.%d+", pos)
        if number then
            pos = pos + #number
            local value = tonumber(number)
            if not value or not Finite(value) then Fail("Invalid number") end
            return value
        end
        Fail("Expected a data value")
    end
    local ok, result = pcall(function()
        local value = Value(0)
        Space()
        if pos <= length then Fail("Unexpected trailing data") end
        if type(value) ~= "table" then Fail("Expected a table") end
        return value
    end)
    if not ok then return nil, "Parse error: " .. tostring(result) end
    return result
end

-- Also validate programmatic imports/exports. Reject cycles, functions, invalid
-- keys and non-finite values before serialization or mutation of saved variables.
function Data.Validate(value, schema, path)
    local seen, nodes = {}, 0
    local function Walk(item, expected, location, depth)
        nodes = nodes + 1
        if nodes > Data.MAX_NODES or depth > Data.MAX_DEPTH then return nil, "Settings exceed complexity limits: " .. location end
        local kind = type(item)
        if kind ~= "table" and kind ~= "string" and kind ~= "number" and kind ~= "boolean" then return nil, "Unsupported value: " .. location end
        if expected ~= nil and kind ~= type(expected) then return nil, "Invalid type: " .. location .. " (expected " .. type(expected) .. ")" end
        if kind == "number" and not Finite(item) then return nil, "Invalid number: " .. location end
        if kind ~= "table" then return true end
        if getmetatable(item) then return nil, "Metatables are not settings: " .. location end
        if seen[item] then return nil, "Cyclic settings: " .. location end
        seen[item] = true
        for key, child in pairs(item) do
            nodes = nodes + 1 -- keys count towards the same bound as the parser
            if nodes > Data.MAX_NODES then return nil, "Too many settings values: " .. location end
            local keyType = type(key)
            if keyType ~= "string" and keyType ~= "number" and keyType ~= "boolean" then return nil, "Invalid key: " .. location end
            if keyType == "number" and not Finite(key) then return nil, "Invalid key: " .. location end
            local childPath = location .. "." .. tostring(key)
            local expectedChild
            if type(expected) == "table" then expectedChild = expected[key] end
            -- Lists of records share their first record's schema.
            if expectedChild == nil and keyType == "number" and type(expected) == "table" then expectedChild = expected[1] end
            local ok, err = Walk(child, expectedChild, childPath, depth + 1)
            if not ok then return nil, err end
            if (key == "enabled" or key == "hidden" or key == "locked") and type(child) ~= "boolean" then return nil, "Invalid boolean: " .. childPath end
            local fontSize = keyType == "string" and key:lower():match("fontsize$") ~= nil
            if fontSize and type(child) ~= "number" then return nil, "Invalid font size: " .. childPath end
            if key == "point" or key == "relativePoint" or key == "relPoint" then
                local anchors = {TOP = true, BOTTOM = true, LEFT = true, RIGHT = true, CENTER = true, TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true}
                if not anchors[child] then return nil, "Invalid anchor: " .. childPath end
            end
            if type(child) == "number" then
                if fontSize and (child < 1 or child > 256) then return nil, "Font size out of range: " .. childPath end
                if key == "numMeters" and (child < 1 or child > 2 or child % 1 ~= 0) then return nil, "Invalid meter count: " .. childPath end
            end
        end
        if item.r ~= nil or item.g ~= nil or item.b ~= nil then
            for _, key in ipairs({"r", "g", "b", "a"}) do
                local channel = item[key]
                if channel ~= nil and (type(channel) ~= "number" or channel < 0 or channel > 1) then return nil, "Invalid colour: " .. location end
            end
        end
        local directions = {LEFT = true, RIGHT = true, UP = true, DOWN = true}
        if item.growthDirection ~= nil and not directions[item.growthDirection] then return nil, "Invalid growth direction: " .. location end
        seen[item] = nil
        return true
    end
    return Walk(value, schema, path or "settings", 0)
end

function Data.ValidateActionBars(settings)
    if settings.bars == nil then return true end
    if type(settings.bars) ~= "table" then return nil, "Invalid Action Bars list" end
    for name, bar in pairs(settings.bars) do
        if type(bar) ~= "table" then return nil, "Invalid action bar: " .. tostring(name) end
        local count = name == "PetActionBar" and 10 or (name == "MicroMenu" or name == "BagsBar") and 1 or 12
        for key, range in pairs({size = {16, 80}, spacing = {0, 24}, columns = {1, count}, rows = {1, count}, x = {-10000, 10000}, y = {-10000, 10000}}) do
            local value = bar[key]
            if value ~= nil and (type(value) ~= "number" or value < range[1] or value > range[2]
                or ((key == "columns" or key == "rows") and value % 1 ~= 0)) then
                return nil, "Invalid Action Bars " .. tostring(name) .. "." .. key
            end
        end
    end
    return true
end


function Data.ValidateMainSettings(settings)
    local cooldown = settings and settings.cooldownManager
    if cooldown then
        if type(cooldown) ~= "table" then return nil, "Invalid cooldown settings" end
        for _, key in ipairs({"essential", "utility", "buffs", "buffBars"}) do
            local group = cooldown[key]
            if group then
                if type(group) ~= "table" then return nil, "Invalid cooldown group: " .. key end
                local ranges = {columns = {1, 20}, spacing = {0, 20}}
                if key == "buffBars" then
                    ranges.barWidth = {100, 600}
                    ranges.barHeight = {16, 80}
                else ranges.iconSize = {16, 80} end
                for field, range in pairs(ranges) do
                    local value = group[field]
                    if value ~= nil and (type(value) ~= "number" or value < range[1] or value > range[2]
                        or (field == "columns" and value % 1 ~= 0)) then return nil, "Invalid cooldown setting: " .. key .. "." .. field end
                end
            end
        end
    end
    return true
end
