local addonName, addonTable = ...
addonTable.Minimap = {}

local button
local minimapShapes = {
    ["ROUND"] = { true, true, true, true },
    ["SQUARE"] = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true },
    ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
    ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true },
    ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true },
    ["SIDE-BOTTOM"] = { true, true, false, false },
    ["TRICORNER-TOPLEFT"] = { false, true, true, true },
    ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
    ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

local function UpdatePosition()
    local angle = math.rad(UIThingsDB.minimap.angle or 45)
    local x, y, q = math.cos(angle), math.sin(angle), 1
    if x < 0 then q = q + 1 end
    if y > 0 then q = q + 2 end

    local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local quadTable = minimapShapes[minimapShape]
    if quadTable and quadTable[q] then
        x, y = x * 80, y * 80
    else
        x, y = x * 103, y * 103 -- Square minimap diagonal
        x = math.max(-80, math.min(x, 80))
        y = math.max(-80, math.min(y, 80))
    end

    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function addonTable.Minimap.Initialize()
    UIThingsDB.minimap = UIThingsDB.minimap or { angle = 45 }

    button = CreateFrame("Button", "LunaMinimapButton", Minimap)
    button:SetFrameLevel(8)
    button:SetFrameStrata("MEDIUM") -- Ensure it's above the map
    button:SetSize(32, 32)
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture([[Interface\Minimap\UI-Minimap-ZoomButton-Highlight]])

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture([[Interface\Minimap\MiniMap-TrackingBorder]])
    overlay:SetPoint("TOPLEFT")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetTexture([[Interface\AddOns\LunaUITweaks\Icon.tga]]) -- Use Custom Icon
    icon:SetPoint("CENTER", 0, 1)

    button:SetScript("OnClick", function(self, btn)
        if addonTable.Config and addonTable.Config.ToggleWindow then
            addonTable.Config.ToggleWindow()
        end
    end)

    button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale

            local angle = math.deg(math.atan2(cy - my, cx - mx))
            if angle < 0 then angle = angle + 360 end

            UIThingsDB.minimap.angle = angle
            UpdatePosition()
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:UnlockHighlight()
        self:SetScript("OnUpdate", nil)
    end)


    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Luna's UI Tweaks")
        GameTooltip:AddLine("Click to open config", 1, 1, 1)
        GameTooltip:AddLine("Drag to move button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UpdatePosition()
end
