local _, addonTable = ...

-- Centralised helpers for handling secret/tainted values returned by Blizzard
-- secure code paths in TWW 12.0+. Reading a secret value is fine; using it as
-- a table key, in ordered comparison (<, >), or concatenating it triggers Lua
-- errors. These helpers validate via the 12.0 globals (canaccessvalue /
-- canaccesssecrets) and silently fall back when the value is poisoned.
--
-- Style: plain functions on addonTable.Secret (matching addonTable.Core.*),
-- no globals, no self-passing.
--
-- Also exposed via LunaUITweaksAPI.Secret so companion addons can reuse the
-- same implementation without copying the file.

local Secret = {}
addonTable.Secret = Secret

function Secret.CanAccessValue(value)
    if canaccessvalue then
        return canaccessvalue(value)
    end
    if issecretvalue then
        return not issecretvalue(value)
    end
    return true
end

function Secret.CanAccessSecrets()
    if canaccesssecrets then
        return canaccesssecrets()
    end
    return true
end

function Secret.SafeUnitName(unit, fallback)
    -- UnitName rejects secret values as the unit argument (not just returns them).
    if not Secret.CanAccessValue(unit) then
        return fallback, nil
    end
    local name, realm = UnitName(unit)
    if not Secret.CanAccessValue(name) then
        return fallback, nil
    end
    if not Secret.CanAccessValue(realm) then
        return name, nil
    end
    return name, realm
end

function Secret.SafeUnitNameUnmodified(unit, fallback)
    if not Secret.CanAccessValue(unit) then
        return fallback, nil
    end
    local name, realm = UnitNameUnmodified(unit)
    if not Secret.CanAccessValue(name) then
        return fallback, nil
    end
    if not Secret.CanAccessValue(realm) then
        return name, nil
    end
    return name, realm
end

function Secret.SafeUnitClass(unit)
    if not Secret.CanAccessValue(unit) then
        return nil, nil, nil
    end
    local classLocal, classEn, classId = UnitClass(unit)
    if not Secret.CanAccessValue(classLocal)
        or not Secret.CanAccessValue(classEn)
        or not Secret.CanAccessValue(classId) then
        return nil, nil, nil
    end
    return classLocal, classEn, classId
end

function Secret.SafeUnitGUID(unit, fallback)
    if not Secret.CanAccessValue(unit) then
        return fallback
    end
    local guid = UnitGUID(unit)
    if not Secret.CanAccessValue(guid) then
        return fallback
    end
    return guid
end

function Secret.SafeConcat(fallback, ...)
    local count = select("#", ...)
    local parts = {}
    for i = 1, count do
        local part = select(i, ...)
        if part == nil or not Secret.CanAccessValue(part) then
            return fallback
        end
        parts[i] = tostring(part)
    end
    return table.concat(parts)
end

-- Expose on the public companion-addon API so sibling addons can share
-- one implementation (populated as soon as this file loads; no ordering
-- dependency between this file and consumer addons that check for it).
if LunaUITweaksAPI then
    LunaUITweaksAPI.Secret = Secret
end
