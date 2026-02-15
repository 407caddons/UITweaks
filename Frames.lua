local addonName, addonTable = ...
addonTable.Frames = {}

function addonTable.Frames.Initialize()
    if not UIThingsDB.frames.enabled then return end

    addonTable.Frames.UpdateFrames()
end

local framePool = {}

-- Save all visible frame positions back to saved variables
-- Called on PLAYER_LOGOUT to ensure dragged positions are never lost
local function SaveAllFramePositions()
    if not UIThingsDB or not UIThingsDB.frames or not UIThingsDB.frames.enabled then return end
    local list = UIThingsDB.frames.list or {}
    local parentX, parentY = UIParent:GetCenter()
    if not parentX then return end

    for i, data in ipairs(list) do
        local f = framePool[i]
        if f and f:IsShown() then
            local centerX, centerY = f:GetCenter()
            if centerX then
                local x = math.floor(centerX - parentX + 0.5)
                local y = math.floor(centerY - parentY + 0.5)
                data.x = x
                data.y = y
            end
        end
    end
end

local logoutFrame = CreateFrame("Frame")
logoutFrame:RegisterEvent("PLAYER_LOGOUT")
logoutFrame:SetScript("OnEvent", SaveAllFramePositions)

function addonTable.Frames.UpdateFrames()
    -- Invalidate widget anchor cache since frames may have changed
    if addonTable.Widgets and addonTable.Widgets.InvalidateAnchorCache then
        addonTable.Widgets.InvalidateAnchorCache()
    end

    -- Hide all existing frames first (simple pooling)
    for _, f in pairs(framePool) do
        f:Hide()
        f:EnableMouse(false)
        f:SetScript("OnDragStart", nil)
        f:SetScript("OnDragStop", nil)
        if f.nudgeButtons then
            for _, btn in pairs(f.nudgeButtons) do btn:Hide() end
        end
    end

    if not UIThingsDB.frames.enabled then return end

    local list = UIThingsDB.frames.list or {}

    for i, data in ipairs(list) do
        local f = framePool[i]
        if not f then
            f = CreateFrame("Frame", "UIThingsCustomFrame" .. i, UIParent, "BackdropTemplate")
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
            tile = false,
            tileSize = 0,
            edgeSize = 0,
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
        local bc = data.borderColor or { r = 1, g = 1, b = 1, a = 1 }

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

        -- Nudge Buttons Logic
        if not f.nudgeButtons then
            f.nudgeButtons = {}

            local function UpdateButtonLayout(frame)
                local right = frame:GetRight()
                local bottom = frame:GetBottom()
                local screenRight = UIParent:GetRight()
                local screenBottom = UIParent:GetBottom() or 0

                -- Guard against nil
                if not right or not screenRight or not bottom then return end

                local bufferX = 40
                local bufferY = 90 -- 4 buttons * ~22px each
                local onLeft = right > (screenRight - bufferX)
                local onTop = bottom < (screenBottom + bufferY)

                local L = f.nudgeButtons.L
                local R = f.nudgeButtons.R
                local U = f.nudgeButtons.U
                local D = f.nudgeButtons.D

                L:ClearAllPoints()
                R:ClearAllPoints()
                U:ClearAllPoints()
                D:ClearAllPoints()

                if onTop then
                    -- Stack horizontally above the frame
                    if onLeft then
                        L:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 2)
                    else
                        L:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 2)
                    end
                    R:SetPoint("LEFT", L, "RIGHT", 2, 0)
                    U:SetPoint("LEFT", R, "RIGHT", 2, 0)
                    D:SetPoint("LEFT", U, "RIGHT", 2, 0)
                else
                    -- Stack vertically beside the frame
                    if onLeft then
                        L:SetPoint("TOPRIGHT", f, "TOPLEFT", -2, 0)
                    else
                        L:SetPoint("TOPLEFT", f, "TOPRIGHT", 2, 0)
                    end
                    R:SetPoint("TOP", L, "BOTTOM", 0, -2)
                    U:SetPoint("TOP", R, "BOTTOM", 0, -2)
                    D:SetPoint("TOP", U, "BOTTOM", 0, -2)
                end
            end

            local function UpdatePosition()
                f:ClearAllPoints()
                f:SetPoint("CENTER", UIParent, "CENTER", data.x, data.y)
                -- Update Config UI if open
                if addonTable.Config and addonTable.Config.RefreshFrameControls then
                    addonTable.Config.RefreshFrameControls()
                end

                -- Update button layout after move (in case it crossed the threshold)
                UpdateButtonLayout(f)
            end

            local function CreateBtn(text, relativeTo, point, rPoint, x, y, onClick)
                local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
                btn:SetSize(20, 20)
                btn:SetPoint(point, relativeTo, rPoint, x, y)
                btn:SetText(text)
                btn:SetScript("OnClick", onClick)
                return btn
            end

            -- L (Anchor for others)
            f.nudgeButtons.L = CreateBtn("L", f, "TOPLEFT", "TOPRIGHT", 2, 0, function()
                data.x = data.x - 1
                UpdatePosition()
            end)

            -- R
            f.nudgeButtons.R = CreateBtn("R", f.nudgeButtons.L, "TOP", "BOTTOM", 0, -2, function()
                data.x = data.x + 1
                UpdatePosition()
            end)

            -- U
            f.nudgeButtons.U = CreateBtn("U", f.nudgeButtons.R, "TOP", "BOTTOM", 0, -2, function()
                data.y = data.y + 1
                UpdatePosition()
            end)

            -- D
            f.nudgeButtons.D = CreateBtn("D", f.nudgeButtons.U, "TOP", "BOTTOM", 0, -2, function()
                data.y = data.y - 1
                UpdatePosition()
            end)

            -- Expose UpdateLayout for Initial/Drag calls
            f.UpdateButtonLayout = UpdateButtonLayout
        end

        -- Interaction
        if not data.locked then
            f:EnableMouse(true)
            f:SetMovable(true)
            f:RegisterForDrag("LeftButton")
            f.nameText:SetText(data.name or ("Frame " .. i))
            f.nameText:Show()

            f:SetScript("OnMouseDown", function()
                if addonTable.Config and addonTable.Config.SelectFrame then
                    addonTable.Config.SelectFrame(i)
                end
            end)

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

                -- Update Config UI if open
                if addonTable.Config and addonTable.Config.RefreshFrameControls then
                    addonTable.Config.RefreshFrameControls()
                end

                -- Update Button Layout
                if self.UpdateButtonLayout then self.UpdateButtonLayout(self) end
            end)

            -- Show Nudge Buttons
            for _, btn in pairs(f.nudgeButtons) do btn:Show() end

            -- Initial Layout Check
            if f.UpdateButtonLayout then f.UpdateButtonLayout(f) end
        else
            f:EnableMouse(false)
            f.nameText:Hide()

            -- Hide Nudge Buttons
            for _, btn in pairs(f.nudgeButtons) do btn:Hide() end
        end
    end
end
