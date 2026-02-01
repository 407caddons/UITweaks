local addonName, addonTable = ...
addonTable.Frames = {}

function addonTable.Frames.Initialize()
    if not UIThingsDB.frames.enabled then return end
    
    addonTable.Frames.UpdateFrames()
end

local framePool = {}

function addonTable.Frames.UpdateFrames()
    -- Hide all existing frames first (simple pooling)
    for _, f in pairs(framePool) do
        f:Hide()
        f:EnableMouse(false)
        f:SetScript("OnDragStart", nil)
        f:SetScript("OnDragStop", nil)
    end
    
    if not UIThingsDB.frames.enabled then return end

    local list = UIThingsDB.frames.list or {}
    
    for i, data in ipairs(list) do
        local f = framePool[i]
        if not f then
            f = CreateFrame("Frame", "UIThingsCustomFrame"..i, UIParent, "BackdropTemplate")
            framePool[i] = f
        end
        
        f:Show()
        f:SetSize(data.width, data.height)
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", data.x, data.y)
        f:SetFrameStrata(data.strata or "LOW")
        
        -- Backdrop (Background Only)
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = nil,
            tile = false, tileSize = 0, edgeSize = 0,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        
        local c = data.color
        f:SetBackdropColor(c.r, c.g, c.b, c.a)
        
        -- Borders (Manual Textures)
        if not f.borders then
             f.borders = {}
             f.borders.top = f:CreateTexture(nil, "BORDER")
             f.borders.bottom = f:CreateTexture(nil, "BORDER")
             f.borders.left = f:CreateTexture(nil, "BORDER")
             f.borders.right = f:CreateTexture(nil, "BORDER")
        end
        
        local bSize = data.borderSize
        local bc = data.borderColor or {r=1, g=1, b=1, a=1}
        
        -- Helper helpers for borders
        local function SetBorder(tex, r, g, b, a)
             tex:SetColorTexture(r, g, b, a)
        end
        
        -- Defaults if nil (for backward compatibility, show all)
        local showTop = (data.showTop == nil) and true or data.showTop
        local showBottom = (data.showBottom == nil) and true or data.showBottom
        local showLeft = (data.showLeft == nil) and true or data.showLeft
        local showRight = (data.showRight == nil) and true or data.showRight
        
        if bSize > 0 then
            -- Top
            if showTop then
                f.borders.top:Show()
                f.borders.top:ClearAllPoints()
                f.borders.top:SetPoint("TOPLEFT", 0, 0)
                f.borders.top:SetPoint("TOPRIGHT", 0, 0)
                f.borders.top:SetHeight(bSize)
                SetBorder(f.borders.top, bc.r, bc.g, bc.b, bc.a)
            else
                f.borders.top:Hide()
            end
            
            -- Bottom
            if showBottom then
                f.borders.bottom:Show()
                f.borders.bottom:ClearAllPoints()
                f.borders.bottom:SetPoint("BOTTOMLEFT", 0, 0)
                f.borders.bottom:SetPoint("BOTTOMRIGHT", 0, 0)
                f.borders.bottom:SetHeight(bSize)
                SetBorder(f.borders.bottom, bc.r, bc.g, bc.b, bc.a)
            else
                f.borders.bottom:Hide()
            end
            
            -- Left
            if showLeft then
                f.borders.left:Show()
                f.borders.left:ClearAllPoints()
                f.borders.left:SetPoint("TOPLEFT", 0, 0)
                f.borders.left:SetPoint("BOTTOMLEFT", 0, 0)
                f.borders.left:SetWidth(bSize)
                SetBorder(f.borders.left, bc.r, bc.g, bc.b, bc.a)
            else
                f.borders.left:Hide()
            end
            
            -- Right
            if showRight then
                f.borders.right:Show()
                f.borders.right:ClearAllPoints()
                f.borders.right:SetPoint("TOPRIGHT", 0, 0)
                f.borders.right:SetPoint("BOTTOMRIGHT", 0, 0)
                f.borders.right:SetWidth(bSize)
                SetBorder(f.borders.right, bc.r, bc.g, bc.b, bc.a)
            else
                f.borders.right:Hide()
            end
        else
            f.borders.top:Hide()
            f.borders.bottom:Hide()
            f.borders.left:Hide()
            f.borders.right:Hide()
        end
        
        -- Name Overlay
        if not f.nameText then
            f.nameText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
            f.nameText:SetPoint("CENTER")
        end
        
        -- Interaction
        if not data.locked then
            f:EnableMouse(true)
            f:SetMovable(true)
            f:RegisterForDrag("LeftButton")
            f.nameText:SetText(data.name or ("Frame " .. i))
            f.nameText:Show()
            
            f:SetScript("OnDragStart", f.StartMoving)
            f:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
                -- Save position
                -- Calculate center relative to UIParent center
                local centerX, centerY = self:GetCenter()
                local parentX, parentY = UIParent:GetCenter()
                
                -- Guard against nil (though unlikely for UIParent)
                if not centerX or not parentX then return end
                
                local x = centerX - parentX
                local y = centerY - parentY
                
                -- Force integers
                x = math.floor(x + 0.5)
                y = math.floor(y + 0.5)
                
                data.x = x
                data.y = y
                
                -- Update Config UI if open? Global update might be heavy.
                -- We rely on user reopening frame settings or manual refresh.
                -- We could call addonTable.Config.RefreshFrameControls if exposed.
                -- Update Config UI if open
                if addonTable.Config and addonTable.Config.RefreshFrameControls then
                     addonTable.Config.RefreshFrameControls() 
                end
            end)
            
            -- Optional: Show a "Drag Me" overlay or highlight?
            -- For now, the block itself is draggable.
        else
            f:EnableMouse(false)
            f.nameText:Hide()
        end
    end
end
