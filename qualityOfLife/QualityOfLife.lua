local _, addon = ...
local QoL = { modules = {} }
addon.QualityOfLife = QoL
function QoL.Public(value) return not (issecretvalue and issecretvalue(value)) end
function QoL.Settings()
    local db=UIThingsDB and UIThingsDB.qualityOfLife
    -- The removed page's master switch has no replacement. Preserve its disabled
    -- behavior by turning off the individual features before releasing the gate.
    if db and db.enabled==false then
        for _,key in ipairs({"cursor","autoOpen","unwrapCollections","movement","timeSpiral","gateway","battleRes","skipCinematics","hideTutorials","hideTalkingHead"}) do db[key]=false end
        db.enabled=true
    end
    return db
end
function QoL.Enabled(key)
    local db=QoL.Settings()
    return db and db.enabled and db[key] == true and (not addon.Client or addon.Client.SupportsQoL(key))
end
function QoL.UpdateSettings()
    for _, module in ipairs(QoL.modules) do module.UpdateSettings() end
end
function QoL.AddModule(module) QoL.modules[#QoL.modules+1]=module end
addon.EventBus.Register("PLAYER_LOGIN",QoL.UpdateSettings,"QualityOfLife")
