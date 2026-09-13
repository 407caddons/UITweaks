-- Independent of bag addons. Item level is a review hint, not an upgrade score.
local _, addon = ...
local Review = {}
addon.GearReview = Review
local slots = {
    INVTYPE_HEAD={1}, INVTYPE_NECK={2}, INVTYPE_SHOULDER={3},
    INVTYPE_CHEST={5}, INVTYPE_ROBE={5}, INVTYPE_WAIST={6}, INVTYPE_LEGS={7},
    INVTYPE_FEET={8}, INVTYPE_WRIST={9}, INVTYPE_HAND={10},
    INVTYPE_FINGER={11,12}, INVTYPE_TRINKET={13,14}, INVTYPE_CLOAK={15},
    INVTYPE_WEAPON={16}, INVTYPE_2HWEAPON={16}, INVTYPE_WEAPONMAINHAND={16},
    INVTYPE_WEAPONOFFHAND={17}, INVTYPE_SHIELD={17}, INVTYPE_HOLDABLE={17},
    INVTYPE_RANGED={16}, INVTYPE_RANGEDRIGHT={16},
}
local window, notice, content, status
local rows, entries, seen = {}, {}, {}
local scheduled, showIgnored = false, false
local requested = {}
local function DB() return UIThingsDB and UIThingsDB.gearReview end
local function Public(v) return not (issecretvalue and issecretvalue(v)) end
local function Ignored()
    local db = DB()
    local character = UnitGUID("player")
    db.ignored[character] = db.ignored[character] or {}
    return db.ignored[character]
end

-- Unknown equipped levels defer comparison instead of manufacturing an upgrade.
function Review.Compare(level, candidates, equipped)
    local target, baseline
    for _, slot in ipairs(candidates) do
        local value = equipped(slot)
        if value == nil then return end
        if baseline == nil or value < baseline then target, baseline = slot, value end
    end
    if baseline and level >= baseline then return target, baseline end
end
local function Equipped(slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then return 0 end
    local level = C_Item.GetDetailedItemLevelInfo(link)
    if Public(level) then return level end
end
local function Candidate(bag, slot, equipped)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info or not Public(info.hyperlink) or not info.hyperlink then return end
    local link = info.hyperlink
    local id, _, _, loc = C_Item.GetItemInfoInstant(link)
    if not Public(id) or not id or not slots[loc] then return end
    local name, _, _, _, required = C_Item.GetItemInfo(link)
    if not name then
        if not requested[id] then requested[id]=true; C_Item.RequestLoadItemDataByID(id) end
        return
    end
    if not Public(name) or not Public(required) or (required and required > UnitLevel("player")) then return end
    local usable = C_PlayerInfo.CanUseItem(id)
    if not Public(usable) or not usable or C_Item.IsCosmeticItem(link) then return end
    local level = C_Item.GetDetailedItemLevelInfo(link)
    if not Public(level) or not level then return end
    local target, baseline = Review.Compare(level, slots[loc], equipped or Equipped)
    if not target then return end
    local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
    local guid = C_Item.GetItemGUID(location)
    if not Public(guid) or not guid then return end
    return {bag=bag, slot=slot, link=link, key=guid, name=name, icon=info.iconFileID,
        level=level, baseline=baseline, target=target, loc=loc, weapon=target>=16,
        locked=info.isLocked, ignored=Ignored()[guid] == true}
end
local function Label(parent, text, x, y, width)
    local f = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f:SetPoint("TOPLEFT", x, y); f:SetWidth(width); f:SetJustifyH("LEFT"); f:SetText(text)
    return f
end
local function Button(parent, text, width, fn)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24); b:SetText(text); b:SetScript("OnClick", fn)
    return b
end
local function Backdrop(frame)
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
    frame:SetBackdropColor(.055,.075,.085,.97); frame:SetBackdropBorderColor(.2,.32,.35,1)
end
function Review.Equip(entry)
    if InCombatLockdown() or not DB().enabled or GetCursorInfo() then return end
    -- Revalidate the physical item AND comparison immediately before the click action.
    local current = Candidate(entry.bag, entry.slot)
    if not current or current.key ~= entry.key or current.ignored or current.locked or current.weapon then
        Review.Refresh(); return
    end
    C_Container.PickupContainerItem(current.bag, current.slot)
    if CursorHasItem() then EquipCursorItem(current.target) end
    -- Never accept Blizzard's binding / uniqueness confirmations automatically.
end
local function Render()
    if not window then return end
    for _, row in ipairs(rows) do row:Hide() end
    local count = 0
    for _, entry in ipairs(entries) do
        if (DB().showEqual or entry.level > entry.baseline) and (showIgnored or not entry.ignored) then
            count = count + 1
            local row = rows[count]
            if not row then
                row = CreateFrame("Button", nil, content)
                row:SetSize(620, 52); row:SetPoint("TOPLEFT", 0, -(count-1)*56)
                row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(36,36); row.icon:SetPoint("LEFT",4,0)
                row.name = Label(row,"",48,-5,350); row.detail = Label(row,"",48,-27,350)
                row.equip = Button(row,"Equip",72,function() Review.Equip(row.entry) end)
                row.equip:SetPoint("RIGHT",-90,0)
                row.ignore = Button(row,"Ignore",80,function()
                    local key = row.entry.key
                    Ignored()[key] = not Ignored()[key] or nil
                    Review.Refresh()
                end)
                row.ignore:SetPoint("RIGHT",-4,0)
                row:SetScript("OnEnter",function(self)
                    if InCombatLockdown() then return end
                    GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                    GameTooltip:SetBagItem(self.entry.bag,self.entry.slot); GameTooltip:Show()
                end)
                row:SetScript("OnLeave",function() GameTooltip:Hide() end)
                rows[count] = row
            end
            row.entry = entry; row.icon:SetTexture(entry.icon); row.name:SetText(entry.name)
            local delta = entry.level-entry.baseline
            row.name:SetTextColor(entry.ignored and .45 or (delta>0 and .35 or 1), entry.ignored and .45 or .9, entry.ignored and .45 or .65)
            row.detail:SetText(string.format("%s  •  ilvl %d (%+d)%s", _G[entry.loc] or entry.loc, entry.level, delta,
                entry.weapon and " — weapon: review manually" or ""))
            row.ignore:SetText(entry.ignored and "Restore" or "Ignore")
            row.equip:SetEnabled(not InCombatLockdown() and not entry.ignored and not entry.locked and not entry.weapon)
            row:Show()
        end
    end
    content:SetHeight(math.max(1,count*56))
    status:SetText(InCombatLockdown() and "Combat: updates and equipping paused." or
        (count==0 and "No matching gear in your bags." or count.." candidates — check stats, tier bonuses and unique-equipped restrictions."))
end
local function CreateWindow()
    if window then return end
    window = CreateFrame("Frame","LunaGearReviewWindow",UIParent,"BackdropTemplate")
    window:SetSize(670,490); window:SetPoint("CENTER"); window:SetFrameStrata("DIALOG")
    Backdrop(window); window:EnableMouse(true); window:SetMovable(true); window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart",function(self) self:StartMoving() end)
    window:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing()
        local point,_,_,x,y = self:GetPoint(); DB().pos={point=point,x=x,y=y}
    end)
    local pos=DB().pos
    if pos then window:ClearAllPoints(); window:SetPoint(pos.point,UIParent,pos.point,pos.x,pos.y) end
    tinsert(UISpecialFrames,"LunaGearReviewWindow")
    Label(window,"Gear Review",18,-16,550):SetTextColor(.35,.9,.78)
    local close=Button(window,"Close",65,function() window:Hide() end); close:SetPoint("TOPRIGHT",-12,-12)
    local function Check(text,x,checked,fn)
        local b=CreateFrame("CheckButton",nil,window,"ChatConfigCheckButtonTemplate")
        b:SetPoint("TOPLEFT",x,-50); b.Text:SetText(text); b:SetChecked(checked)
        b:SetScript("OnClick",function(self) fn(not not self:GetChecked()); Review.Refresh() end)
    end
    Check("Include equal ilvl",18,DB().showEqual,function(v) DB().showEqual=v end)
    Check("Show ignored",220,false,function(v) showIgnored=v end)
    status=Label(window,"",18,-86,630)
    local scroll=CreateFrame("ScrollFrame",nil,window,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",16,-122); scroll:SetPoint("BOTTOMRIGHT",-32,16)
    content=CreateFrame("Frame",nil,scroll); content:SetSize(620,1); scroll:SetScrollChild(content)
    window:Hide()
end
function Review.ToggleWindow()
    if not DB() or not DB().enabled then print("LunaUITweaks: enable Gear Review in config first."); return end
    if InCombatLockdown() then print("LunaUITweaks: Gear Review is available out of combat."); return end
    CreateWindow()
    if window:IsShown() then window:Hide() else window:Show(); Review.Refresh() end
    if notice then notice:Hide() end
end
function Review.Refresh()
    if not DB() then return end
    if not DB().enabled then
        if window then window:Hide() end
        if notice then notice:Hide() end
        return
    end
    if InCombatLockdown() then Render(); return end
    entries = {}
    local fresh, available = 0, 0
    local reviewing = window and window:IsShown()
    local canNotify = DB().notify and IsResting()
    local levels = {}
    local function CachedEquipped(slot)
        if levels[slot] == nil then levels[slot] = Equipped(slot) or false end
        if levels[slot] ~= false then return levels[slot] end
    end
    for bag=0,NUM_BAG_SLOTS do
        for slot=1,C_Container.GetContainerNumSlots(bag) do
            local entry=Candidate(bag,slot,CachedEquipped)
            if entry then
                entries[#entries+1]=entry
                if not entry.ignored and (DB().showEqual or entry.level>entry.baseline) then
                    available=available+1
                    if not seen[entry.key] then
                        fresh=fresh+1
                        -- Keep outdoor loot pending until it is actually presented.
                        if canNotify or reviewing then seen[entry.key]=true end
                    end
                end
            end
        end
    end
    table.sort(entries,function(a,b)
        if a.level~=b.level then return a.level>b.level end
        if a.name~=b.name then return a.name<b.name end
        return a.key<b.key
    end)
    Render()
    if not canNotify or available==0 or reviewing then
        if notice then notice:Hide() end
    elseif fresh>0 then
        if not notice then
            notice=CreateFrame("Button",nil,UIParent,"BackdropTemplate")
            notice:SetSize(370,34); notice:SetPoint("TOP",0,-160); Backdrop(notice)
            notice.text=Label(notice,"",12,-10,345)
            notice:RegisterForClicks("LeftButtonUp","RightButtonUp")
            notice:SetScript("OnClick",function(self,button)
                self:Hide(); if button=="LeftButton" then Review.ToggleWindow() end
            end)
        end
        notice.text:SetText("Gear to review — click to open (right: dismiss)"); notice:Show()
    end
end
local function Schedule()
    if scheduled or not DB() or not DB().enabled then return end
    scheduled=true
    C_Timer.After(.3,function() scheduled=false; Review.Refresh() end)
end
Review.UpdateSettings=Review.Refresh
for _,event in ipairs({"PLAYER_ENTERING_WORLD","BAG_UPDATE_DELAYED","PLAYER_EQUIPMENT_CHANGED",
    "GET_ITEM_INFO_RECEIVED","PLAYER_REGEN_ENABLED","PLAYER_LEVEL_UP","PLAYER_UPDATE_RESTING"}) do
    addon.EventBus.Register(event,Schedule,"GearReview")
end
addon.EventBus.Register("PLAYER_REGEN_DISABLED",function()
    if notice then notice:Hide() end
    if window then GameTooltip:Hide(); Render() end
end,"GearReview")
SLASH_LUNAGEARREVIEW1="/lunagear"
SlashCmdList.LUNAGEARREVIEW=Review.ToggleWindow
