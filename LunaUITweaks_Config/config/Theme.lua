local _, ns = ...
local addon = _G.LunaUITweaks
local Theme = {}
addon.ConfigTheme = Theme
local styled = setmetatable({}, { __mode = "k" })

local function Surface(parent, r, g, b)
    local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bg:SetAllPoints()
    bg:SetFrameLevel(math.max(0, parent:GetFrameLevel() - 1))
    bg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    bg:SetBackdropColor(r, g, b, 1)
    bg:SetBackdropBorderColor(.19, .25, .29, 1)
    styled[bg] = true
    return bg
end

function Theme.Card(panel, title, x, y, width, height)
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", x, y)
    bg:SetSize(width, height)
    bg:SetColorTexture(.09, .115, .14, 1)
    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetPoint("TOPLEFT", x + 12, y - 12)
    heading:SetText(title)
    heading:SetTextColor(.35, .9, .76)
end

function Theme.Navigation(button)
    button.text:SetTextColor(.78, .83, .87)
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    button:GetHighlightTexture():SetVertexColor(.25, .8, .65, .14)
    local mark = button:CreateTexture(nil, "OVERLAY")
    mark:SetSize(3, 22)
    mark:SetPoint("LEFT")
    mark:SetColorTexture(.35, .9, .76)
    button.selectionMark = mark
    mark:Hide()
    button.RefreshTheme = function(self)
        self.selectionMark:SetShown(self.selected == true)
        if self.selected then self.text:SetTextColor(.55, 1, .85)
        elseif self.isDisabled then self.text:SetTextColor(.48, .53, .59)
        else self.text:SetTextColor(.8, .85, .9) end
    end
end

function Theme.SkinTree(root)
    if styled[root] then
        for _, child in ipairs({root:GetChildren()}) do Theme.SkinTree(child) end
        return
    end
    styled[root] = true
    local kind = root:GetObjectType()
    if kind == "CheckButton" then
        root:SetNormalTexture("Interface\\Buttons\\WHITE8X8")
        root:GetNormalTexture():SetVertexColor(.15, .2, .24)
        root:SetPushedTexture("Interface\\Buttons\\WHITE8X8")
        root:GetPushedTexture():SetVertexColor(.25, .5, .44)
        root:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        root:GetCheckedTexture():SetVertexColor(.35, 1, .76)
        -- Templates reserve transparent padding around their artwork. Keep
        -- the visible square inside a 16px box so legacy 20px rows stay clear.
        for _, getter in ipairs({"GetNormalTexture", "GetPushedTexture", "GetCheckedTexture", "GetHighlightTexture", "GetDisabledCheckedTexture"}) do
            local texture = root[getter](root)
            if texture then
                texture:ClearAllPoints()
                texture:SetPoint("CENTER", root, "CENTER")
                texture:SetSize(16, 16)
            end
        end
    elseif kind == "EditBox" then
        for _, key in ipairs({"Left", "Middle", "Right", "LeftTex", "MidTex", "RightTex"}) do
            if root[key] and root[key].SetAlpha then root[key]:SetAlpha(0) end
        end
        Surface(root, .045, .065, .085)
        root:SetTextColor(.9, .94, .97)
    elseif kind == "Button" and root:GetNormalFontObject() and not root.selectionMark then
        -- Only text buttons: preserve icon buttons, color swatches and list rows.
        for _, getter in ipairs({"GetNormalTexture", "GetPushedTexture", "GetDisabledTexture"}) do
            local texture = root[getter](root)
            if texture then texture:SetAlpha(0) end
        end
        for _, key in ipairs({"Left", "Middle", "Right"}) do
            if root[key] and root[key].SetAlpha then root[key]:SetAlpha(0) end
        end
        Surface(root, .11, .16, .19)
        root:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
        root:GetHighlightTexture():SetVertexColor(.35, .9, .76, .17)
    elseif kind == "Slider" then
        local thumb = root:GetThumbTexture()
        if thumb then
            thumb:SetColorTexture(.35, .9, .76, 1)
            -- Blizzard's artwork has transparent padding. A solid replacement
            -- fills that entire canvas unless we also resize the texture.
            if root:GetOrientation() == "HORIZONTAL" then
                thumb:SetSize(8, 14)
            else
                -- Keep the scroll range's height while slimming the handle.
                thumb:SetWidth(8)
            end
        end
    end
    for _, child in ipairs({root:GetChildren()}) do Theme.SkinTree(child) end
    -- Revisit descendants when panels build additional controls on demand.
    root:HookScript("OnShow", function(self)
        for _, child in ipairs({self:GetChildren()}) do
            Theme.SkinTree(child)
        end
    end)
end

function Theme.Window(window)
    Surface(window, .055, .075, .095)
    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -17)
    title:SetText("LUNA  /  SETTINGS")
    title:SetTextColor(.45, .95, .8)
    window.TitleText = title
    local close = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    close:SetSize(28, 24)
    close:SetPoint("TOPRIGHT", -12, -10)
    close:SetText("×")
    close:SetScript("OnClick", function() window:Hide() end)
end
