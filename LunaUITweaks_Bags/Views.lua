local _, Bags = ...
local SIZE, STEP, COLUMNS = 36, 40, 12
local function Text(parent, text, x, y, template)
    local label=parent:CreateFontString(nil,"OVERLAY",template or "GameFontNormal")
    label:SetPoint("TOPLEFT",x,y); label:SetText(text); return label
end
local function Button(parent,text,x,y,width,callback)
    local button=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT",x,y); button:SetSize(width,24); button:SetText(text)
    button:SetScript("OnClick",callback); return button
end
local function SavePosition(view)
    local point,_,relativePoint,x,y=view:GetPoint()
    LunaUITweaksBagsDB.position={point=point,relativePoint=relativePoint,x=x,y=y}
end
function Bags.RestorePosition()
    local view=Bags.inventory
    if not view or InCombatLockdown() then return end
    local pos=LunaUITweaksBagsDB.position
    local valid={TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,CENTER=true,TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
    view:ClearAllPoints()
    if type(pos)=="table" and valid[pos.point] and valid[pos.relativePoint] and type(pos.x)=="number" and type(pos.y)=="number" then
        view:SetPoint(pos.point,UIParent,pos.relativePoint,pos.x,pos.y)
    else view:SetPoint("BOTTOMRIGHT",UIParent,"BOTTOMRIGHT",-30,100) end
end
function Bags.UpdateEscapeRegistration()
    local name="LunaUITweaks_BagsInventory"
    for i=#UISpecialFrames,1,-1 do if UISpecialFrames[i]==name then table.remove(UISpecialFrames,i) end end
    if not InCombatLockdown() then UISpecialFrames[#UISpecialFrames+1]=name end
end
local function NewView(name,parent,isBank)
    local view=CreateFrame("Frame",name,parent,"BackdropTemplate")
    view:SetSize(540,math.min(620,UIParent:GetHeight()-100)); view:SetFrameStrata("HIGH")
    view:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    view:SetBackdropColor(.035,.045,.06,1); view:SetBackdropBorderColor(.25,.3,.35,1)
    view:EnableMouse(true); view:SetClampedToScreen(true); view:Hide()
    view.title=Text(view,isBank and "Luna Bags — Bank" or "Luna Bags",14,-12,"GameFontNormalLarge")
    local close=CreateFrame("Button",nil,view,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",-2,-2)
    close:SetScript("OnClick",function()
        if isBank then HideUIPanel(BankFrame) else Bags.SetInventoryShown(false) end
    end)
    view.status=Text(view,"",14,isBank and -73 or -40,"GameFontHighlightSmall")
    view.scroll=CreateFrame("ScrollFrame",nil,view,"UIPanelScrollFrameTemplate")
    view.scroll:SetPoint("TOPLEFT",14,isBank and -96 or -63); view.scroll:SetPoint("BOTTOMRIGHT",-32,40)
    view.content=CreateFrame("Frame",nil,view.scroll)
    view.content:SetSize(COLUMNS*STEP,1); view.scroll:SetScrollChild(view.content)
    view.content.IsCombinedBagContainer=function() return true end
    view.buttons={}; view.headings={}
    view.footer=Text(view,"",14,0,"GameFontHighlightSmall")
    view.footer:ClearAllPoints(); view.footer:SetPoint("BOTTOMLEFT",14,14)
    if not isBank then
        view:SetMovable(true); view:RegisterForDrag("LeftButton")
        view:SetScript("OnDragStart",function(self) if not InCombatLockdown() then self:StartMoving() end end)
        view.finishDrag=function(self)
            if InCombatLockdown() then self.pendingDragStop=true; return end
            self.pendingDragStop=nil; self:StopMovingOrSizing(); SavePosition(self)
        end
        view:SetScript("OnDragStop",view.finishDrag)
        Bags.UpdateEscapeRegistration()
    else
        view.bankTab=Enum.BankType.Account
        view.accountTab=Button(view,"Warband Bank",14,-40,135,function() Bags.SelectBank(Enum.BankType.Account) end)
        view.characterTab=Button(view,"Bank",159,-40,100,function() Bags.SelectBank(Enum.BankType.Character) end)
        view.deposit=Button(view,"Deposit Warbound",269,-40,160,function() Bags.DepositWarbound() end)
    end
    view:SetScript("OnShow",function(self)
        Bags.QueueRefresh()
    end)
    return view
end
function Bags.CreateInventory()
    if not Bags.inventory then
        Bags.inventory=NewView("LunaUITweaks_BagsInventory",UIParent,false)
        Bags.RestorePosition()
    end
    return Bags.inventory
end
function Bags.CreateBank()
    if not Bags.bank then
        Bags.bank=NewView("LunaUITweaks_BagsBank",BankFrame,true)
        Bags.bank:SetClampedToScreen(false)
        -- Opaque cover retains Blizzard's bank interaction, tab state and close handling.
        Bags.bank:SetFrameLevel(BankFrame:GetFrameLevel()+100)
        Bags.bank:SetPoint("TOPLEFT",BankFrame,"TOPLEFT",-4,4)
    end
    local view=Bags.bank
    view:SetSize(math.max(540,BankFrame:GetWidth()+90),math.max(580,BankFrame:GetHeight()+40))
    return view
end
local function RetargetEmpty(button)
    if InCombatLockdown() then return false end
    local kind,itemID=GetCursorInfo()
    if kind~="item" then return false end
    local entry=Bags.FindEmptySlot(button.freeSpaceIDs,itemID)
    if not entry then return false end
    button:SetBagID(entry.bag); button:SetID(entry.slot)
    return true
end
local function HasItemInteraction()
    for _,name in ipairs({"MerchantFrame","BankFrame","GuildBankFrame","MailFrame","TradeFrame",
        "AuctionHouseFrame","AuctionFrame","ItemUpgradeFrame","ChallengesKeystoneFrame","RuneforgeFrame",
        "AzeriteRespecFrame","ObliterumForgeFrame"}) do
        local frame=_G[name]
        if frame and frame:IsShown() then return true end
    end
    return false
end
local function SlotButton(view,index)
    local button=view.buttons[index]
    if not button then
        local inventory=view==Bags.inventory
        local template="ContainerFrameItemButtonTemplate"..(inventory and ",SecureActionButtonTemplate" or "")
        button=CreateFrame("ItemButton",nil,view.content,template)
        button.secureInventory=inventory
        if not inventory then
            -- Bank contents are withdrawal targets, not candidates for the active deposit context.
            button.GetItemContextMatchResult=function()
                return ItemButtonUtil.ItemContextMatchResult.DoesNotApply
            end
        end
        if inventory then
            button:RegisterForClicks("LeftButtonUp","RightButtonUp")
            button:SetAttribute("useOnKeyDown",false)
            -- Modified clicks belong to the native link/preview/stack-splitting handler.
            for _,prefix in ipairs({"shift-","ctrl-","alt-","ctrl-shift-","alt-shift-","alt-ctrl-","alt-ctrl-shift-"}) do
                button:SetAttribute(prefix.."type2","")
            end
        end
        button:SetSize(SIZE,SIZE)
        button:SetFrameLevel(view.content:GetFrameLevel()+1)
        -- The Blizzard template owns click, split-stack, drag, refund and tooltip behavior.
        button:HookScript("OnHide",function(self)
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
        local click,receive,drag=button:GetScript("OnClick"),button:GetScript("OnReceiveDrag"),button:GetScript("OnDragStart")
        local function NativeClick(self,mouse,...)
            if self.freeSpaceIDs and (mouse~="LeftButton" or not RetargetEmpty(self)) then return end
            if inventory then
                -- Never invoke the secure OnClick from addon Lua; it must run as a hardware click.
                if IsModifiedClick() then self:OnModifiedClick(mouse)
                else self:OnClick(mouse) end
            elseif click then click(self,mouse,...) end
        end
        if inventory then
            -- Retain the template's secure OnClick. Only adjust actions outside lockdown.
            button:SetScript("PreClick",function(self,mouse)
                self.nativeRightClick=IsModifiedClick()
                self.targetingItem=mouse=="LeftButton" and (SpellCanTargetItem() or SpellCanTargetItemID())
                if not InCombatLockdown() then
                    local action=self.secureItem and not self.freeSpaceIDs and not IsModifiedClick()
                        and not GetCursorInfo() and not HasItemInteraction()
                    self:SetAttribute("type2",action and "item" or nil)
                    self.nativeRightClick=not action
                end
            end)
            button:SetScript("PostClick",function(self,mouse,...)
                if not self.targetingItem and (mouse~="RightButton" or self.nativeRightClick) then NativeClick(self,mouse,...) end
                -- Restore the preconfigured action for a subsequent click during combat.
                if not InCombatLockdown() then self:SetAttribute("type2",self.secureItem and "item" or nil) end
            end)
        else button:SetScript("OnClick",NativeClick) end
        button:SetScript("OnReceiveDrag",function(self,...)
            if self.freeSpaceIDs and not RetargetEmpty(self) then return end
            if receive then receive(self,...) end
        end)
        button:SetScript("OnDragStart",function(self,...)
            if not self.freeSpaceIDs and drag then drag(self,...) end
        end)
        view.buttons[index]=button
    end
    return button
end
local function SuppressItemGlow(button)
    for _,name in ipairs({"newitemglowAnim","flashAnim"}) do
        local animation=button[name]
        if animation then animation:Stop() end
    end
    for _,name in ipairs({"NewItemTexture","BattlepayItemTexture","flash","BagIndicator"}) do
        local texture=button[name]
        if texture then texture:Hide() end
    end
end
local function UpdateSlotCooldown(button)
    if button.secureInventory then
        button:UpdateCooldown(button:HasItem())
    else
        -- Bank storage availability is independent of whether this character can use the item.
        button.Cooldown:Hide()
        SetItemButtonTextureVertexColor(button,1,1,1)
    end
end
local function Populate(button,entry)
    button.freeSpaceIDs=nil
    if button.freeCount then button.freeCount:Hide() end
    button:SetBagID(entry.bag); button:SetID(entry.slot)
    local info=entry.info
    if button.secureInventory then
        button.secureItem=info~=nil
        button:SetAttribute("item2",info and (entry.bag.." "..entry.slot) or nil)
        button:SetAttribute("type2",info and "item" or nil)
        button:SetAttribute("target-bag1",entry.bag)
        button:SetAttribute("target-slot1",entry.slot)
    end
    SetItemButtonTexture(button,info and info.iconFileID)
    SetItemButtonCount(button,info and info.stackCount or 0)
    SetItemButtonDesaturated(button,info and info.isLocked or false)
    button:SetHasItem(info~=nil); button:SetReadable(info and info.isReadable)
    SetItemButtonTextureVertexColor(button,1,1,1)
    UpdateSlotCooldown(button)
    local quest=C_Container.GetContainerItemQuestInfo(entry.bag,entry.slot)
    button:UpdateQuestItem(quest and quest.isQuestItem,quest and quest.questID,quest and quest.isActive)
    button:UpdateJunkItem(info and info.quality,info and info.hasNoValue)
    SetItemButtonQuality(button,info and info.quality,info and info.hyperlink)
    if not button.ItemSlotBackground then
        button.ItemSlotBackground=button:CreateTexture(nil,"BACKGROUND","ItemSlotBackgroundCombinedBagsTemplate",-6)
        button.ItemSlotBackground:SetAllPoints()
    end
    if not button.secureInventory then
        button:SetMatchesSearch(true)
        button:UpdateItemContextMatching()
    end
    SuppressItemGlow(button)
    button.ItemSlotBackground:Show(); button:Show()
end
function Bags.Render(view,ids,available)
    if not view or not view:IsShown() then return end
    if InCombatLockdown() then
        view.status:SetText("Layout updates resume after combat."); return
    end
    if StackSplitFrame and StackSplitFrame:IsShown() then
        view.status:SetText("Finish splitting this stack to refresh the layout."); return
    end
    local scan=Bags.Scan(ids,view==Bags.inventory)
    local index,heading,y=0,0,0
    local function Section(name,items)
        if #items==0 then return end
        heading=heading+1
        local label=view.headings[heading]
        if not label then label=Text(view.content,"",0,0); view.headings[heading]=label end
        label:ClearAllPoints(); label:SetPoint("TOPLEFT",0,-y); label:SetText(name.." ("..#items..")"); label:Show()
        y=y+24
        for i,entry in ipairs(items) do
            index=index+1
            local button=SlotButton(view,index)
            button:ClearAllPoints(); button:SetPoint("TOPLEFT",((i-1)%COLUMNS)*STEP,-y-math.floor((i-1)/COLUMNS)*STEP)
            Populate(button,entry)
        end
        y=y+math.ceil(#items/COLUMNS)*STEP+12
    end
    for _,category in ipairs(Bags.categories) do Section(category.name,scan[category.key]) end
    if #scan.empty>0 then
        Section("Free Space",{scan.empty[1]})
        -- One tile represents every free slot, with a visible count even when only one remains.
        local button=view.buttons[index]
        button.freeSpaceIDs=ids
        if not button.freeCount then
            button.freeCount=Text(button,"",0,0,"GameFontHighlightSmall")
            button.freeCount:ClearAllPoints(); button.freeCount:SetPoint("BOTTOMRIGHT",-2,2)
        end
        button.freeCount:SetText(tostring(#scan.empty)); button.freeCount:Show()
        view.headings[heading]:SetText("Free Space ("..#scan.empty..")")
    end
    for i=index+1,#view.buttons do view.buttons[i]:Hide() end
    for i=heading+1,#view.headings do view.headings[i]:Hide() end
    view.content:SetHeight(math.max(y,1))
    view.scroll:SetVerticalScroll(math.min(view.scroll:GetVerticalScroll(),math.max(0,y-view.scroll:GetHeight())))
    view.status:SetText(view.depositMessage or (not available and "This bank is unavailable here." or (scan.capacity==0 and "No purchased bank tabs." or "")))
    view.footer:SetText(("%d / %d slots used   •   %d free"):format(scan.occupied,scan.capacity,#scan.empty))
end
function Bags.UpdateCooldowns()
    for _,view in ipairs({Bags.inventory,Bags.bank}) do
        if view:IsShown() then
            for _,button in ipairs(view.buttons) do if button:IsShown() then UpdateSlotCooldown(button) end end
        end
    end
end
