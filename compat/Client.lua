local _,addon=...
local _,build,_,interface=GetBuildInfo()
local Client={isForever=type(interface)=="number" and interface>=16000 and interface<17000,interface=interface,build=build}
addon.Client=Client
Client.flavor=Client.isForever and "forever" or "retail"
local disabled={mplusTimer=true,talentManager=true,talentReminders=true,warehousing=true,gearReview=true,
    queueTimer=true,compactGroupFinder=true,tankDebuffs=true,consumableReminders=true,autoLogging=true}
local disabledWidgets={spec=true,keystone=true,mythicRating=true,vault=true,teleports=true,battleRes=true,
    mastery=true,vers=true,pvp=true,wheeCheck=true}
local disabledQoL={movement=true,movementTts=true,timeSpiral=true,gateway=true,battleRes=true}
function Client.Supports(feature) return not Client.isForever or not disabled[feature] end
function Client.SupportsWidget(key) return not Client.isForever or not disabledWidgets[key] end
function Client.SupportsQoL(key) return not Client.isForever or not disabledQoL[key] end
function Client.ApplySettings(db)
    if not Client.isForever or type(db)~="table" then return end
    for key in pairs(disabled) do if type(db[key])=="table" then db[key].enabled=false end end
    if db.widgets then for key in pairs(disabledWidgets) do if db.widgets[key] then db.widgets[key].enabled=false end end end
    if db.qualityOfLife then for key in pairs(disabledQoL) do db.qualityOfLife[key]=false end end
    if db.combat then
        if db.combat.combatLog then for key in pairs(db.combat.combatLog) do db.combat.combatLog[key]=false end end
        if db.combat.reminders then
            db.combat.reminders.enabled=false
            for _,key in ipairs({"flask","food","weaponBuff","pet","classBuff"}) do db.combat.reminders[key]=false end
        end
    end
    if db.encounterBars then db.encounterBars.timeline=false;db.encounterBars.hideTimeline=false end
end
-- Never treat the first bank bag as a reagent bag on clients without that slot.
function Client.GetBagIDs()
    local ids={}
    for bag=0,(NUM_BAG_SLOTS or 4) do ids[#ids+1]=bag end
    local reagent=Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
    if type(reagent)=="number" and reagent>(NUM_BAG_SLOTS or 4) then ids[#ids+1]=reagent end
    return ids
end
function Client.GetBankIDs(bankType)
    if not C_Bank or not C_Bank.FetchPurchasedBankTabData or bankType==nil then return end
    if C_Bank.CanViewBank and not C_Bank.CanViewBank(bankType) then return end
    local ok,data=pcall(C_Bank.FetchPurchasedBankTabData,bankType)
    if not ok or type(data)~="table" then return end
    local ids={}
    for _,entry in ipairs(data) do
        if type(entry)~="table" then return end
        local id=entry.ID
        if (issecretvalue and issecretvalue(id)) or type(id)~="number" then return end
        ids[#ids+1]=id
    end
    return ids
end
function Client.PrintStatus()
    print(("LunaUITweaks: %s test build; interface %s, build %s"):format(Client.flavor,tostring(Client.interface),tostring(Client.build)))
    if Client.isForever then
        print("Forever first pass: Retail talents, M+/Vault, automated banking, gear review and Retail class alerts are disabled.")
        print("Damage meter: "..tostring(C_DamageMeter and type(C_DamageMeter.GetCombatSessionFromType)=="function").."; cooldown viewer: "..tostring(C_CooldownViewer~=nil))
    end
end
function Client.GetMaxLevel()
    if GetMaxPlayerLevel then return GetMaxPlayerLevel() end
    if GetMaxLevelForPlayerExpansion then return GetMaxLevelForPlayerExpansion() end
    return Client.isForever and 60 or UnitLevel("player")
end
