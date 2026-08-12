local addonName, addonTable = ...

-- Runtime-safe helpers shared by feature modules and the load-on-demand
-- configuration addon. UI-only helper factories remain in ConfigHelpers.
addonTable.ConfigHelpers = addonTable.ConfigHelpers or {}
local Helpers = addonTable.ConfigHelpers
LunaUITweaksAPI.Helpers = Helpers

Helpers.RAID_DIFFICULTIES = { [17] = "LFR", [14] = "Normal", [15] = "Heroic", [16] = "Mythic" }
Helpers.DUNGEON_DIFFICULTIES = { [1] = "Normal", [2] = "Heroic", [23] = "Mythic", [8] = "Mythic Keystone" }
Helpers.RAID_DIFF_ORDER = { 17, 14, 15, 16 }
Helpers.DUNGEON_DIFF_ORDER = { 1, 2, 23, 8 }

function Helpers.IsRaidDifficulty(diffID)
    return Helpers.RAID_DIFFICULTIES[tonumber(diffID)] ~= nil
end

function Helpers.IsDungeonDifficulty(diffID)
    return Helpers.DUNGEON_DIFFICULTIES[tonumber(diffID)] ~= nil
end

function Helpers.DeepCopy(value, seen)
    if type(value) ~= "table" then return value end

    seen = seen or {}
    if seen[value] then return seen[value] end

    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do
        copy[Helpers.DeepCopy(key, seen)] = Helpers.DeepCopy(child, seen)
    end
    return copy
end

function Helpers.ApplyFrameBackdrop(frame, showBorder, borderColor, showBackground, backgroundColor)
    if showBorder or showBackground then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            tileSize = 0,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })

        local bg = backgroundColor or { r = 0, g = 0, b = 0, a = 0.8 }
        if showBackground then
            frame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
        else
            frame:SetBackdropColor(0, 0, 0, 0)
        end

        local border = borderColor or { r = 1, g = 1, b = 1, a = 1 }
        if showBorder then
            frame:SetBackdropBorderColor(border.r, border.g, border.b, border.a)
        else
            frame:SetBackdropBorderColor(0, 0, 0, 0)
        end
    else
        frame:SetBackdrop(nil)
    end
end
