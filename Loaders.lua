local addonName, addonTable = ...

local Core = addonTable.Core

local function IsLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
    end
    return IsAddOnLoaded and IsAddOnLoaded(name)
end

function Core.LoadOptionalAddon(name)
    if IsLoaded(name) then return true end

    local loaded, reason
    if C_AddOns and C_AddOns.LoadAddOn then
        loaded, reason = C_AddOns.LoadAddOn(name)
    elseif LoadAddOn then
        loaded, reason = LoadAddOn(name)
    end

    if loaded or IsLoaded(name) then
        if name == "LunaUITweaks_Config" then
            Core.Log("Config", "Configuration UI loaded", Core.LogLevel.INFO)
        end
        return true
    end

    Core.Log("Loader", ("Unable to load %s: %s"):format(name, tostring(reason or "not installed")),
        Core.LogLevel.ERROR)
    return false
end

local configProxy = {}
addonTable.Config = configProxy

function configProxy.ToggleWindow()
    if not Core.LoadOptionalAddon("LunaUITweaks_Config") then return end
    local config = addonTable.Config
    if config ~= configProxy and config.ToggleWindow then
        config.ToggleWindow()
    end
end

function LunaUITweaks_OpenConfig()
    configProxy.ToggleWindow()
end

local gameModules = {
    "Snek", "Bombs", "Gems", "Cards", "Game2048",
    "Boxes", "Slide", "Lights", "Blocks",
}

for _, moduleName in ipairs(gameModules) do
    local key = moduleName
    local proxy = {}
    addonTable[key] = proxy
    proxy.ShowGame = function()
        if not Core.LoadOptionalAddon("LunaUITweaks_Games") then return end
        local module = addonTable[key]
        if module ~= proxy and module.ShowGame then
            module.ShowGame()
        end
    end
end

function LunaUITweaks_Game_Left() end
function LunaUITweaks_Game_Right() end
function LunaUITweaks_Game_RotateCW() end
function LunaUITweaks_Game_RotateCCW() end
function LunaUITweaks_Game_SoftDrop() end
function LunaUITweaks_Game_HardDrop() end
function LunaUITweaks_Game_Pause() end
