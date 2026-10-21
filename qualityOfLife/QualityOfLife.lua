local _, addon = ...
local QoL = { modules = {} }
addon.QualityOfLife = QoL
function QoL.Public(value) return not (issecretvalue and issecretvalue(value)) end
function QoL.Settings() return UIThingsDB and UIThingsDB.qualityOfLife end
function QoL.Enabled(key)
    local db=QoL.Settings()
    return db and db.enabled and db[key] == true
end
function QoL.UpdateSettings()
    for _, module in ipairs(QoL.modules) do module.UpdateSettings() end
end
function QoL.AddModule(module) QoL.modules[#QoL.modules+1]=module end
-- Existing panel API keeps this module independent of fixed navigation indexes.
LunaUITweaksAPI.RegisterConfigPanel("qualityOfLife","Quality of Life","Interface\\Icons\\INV_Misc_Gear_01",function(...)
    addon.ConfigSetup.QualityOfLife(...)
end)
addon.EventBus.Register("PLAYER_LOGIN",QoL.UpdateSettings,"QualityOfLife")
