local _, addon = ...
local Focus = {}
addon.FocusCastBar = Focus
local frame, bar, icon, nameText, timeText, borders
local duration, pending
local events = CreateFrame("Frame")
local function Settings() return UIThingsDB.castBar.focusBar end
local function Public(value) return not (issecretvalue and issecretvalue(value)) end
local function Present(value) return not Public(value) or value ~= nil end

local function Paint(notInterruptible)
    local s, common = Settings(), UIThingsDB.castBar
    local yes, no = s.barColor, common.nonInterruptibleColor
    -- The native evaluator accepts secret interruptibility; Lua never branches on it.
    if C_CurveUtil and C_CurveUtil.EvaluateColorFromBoolean and Present(notInterruptible) then
        local color = C_CurveUtil.EvaluateColorFromBoolean(notInterruptible,
            CreateColor(no.r, no.g, no.b, no.a or 1), CreateColor(yes.r, yes.g, yes.b, yes.a or 1))
        bar:SetStatusBarColor(color:GetRGBA())
    else
        bar:SetStatusBarColor(yes.r, yes.g, yes.b, yes.a or 1)
    end
end

local function Refresh()
    if not frame then return end
    frame:SetScript("OnUpdate", nil)
    duration = nil
    if not Settings().enabled then frame:Hide(); return end
    local name, _, texture, _, _, _, _, blocked = UnitCastingInfo("focus")
    local channel = false
    if Present(name) then
        duration = UnitCastingDuration("focus")
    else
        name, _, texture, _, _, _, blocked = UnitChannelInfo("focus")
        if Present(name) then channel = true; duration = UnitChannelDuration("focus") end
    end
    if duration then
        nameText:SetText(name); icon:SetTexture(texture)
        Paint(blocked)
        bar:SetTimerDuration(duration, Enum.StatusBarInterpolation.None, channel and 1 or 0)
        frame:Show()
        if UIThingsDB.castBar.showCastTime then
            local elapsedText = 0
            timeText:SetFormattedText("%.1fs", duration:GetRemainingDuration())
            frame:SetScript("OnUpdate", function(_, elapsed)
                elapsedText = elapsedText + elapsed
                if elapsedText < 0.05 then return end
                elapsedText = 0
                timeText:SetFormattedText("%.1fs", duration:GetRemainingDuration())
            end)
        end
    elseif not Settings().locked and not InCombatLockdown() then
        bar:SetMinMaxValues(0, 1); bar:SetValue(0.5)
        Paint(false); nameText:SetText("Focus Cast Bar"); timeText:SetText("1.5s")
        icon:SetTexture("Interface\\Icons\\Spell_Holy_MagicalSentry"); frame:Show()
    else
        timeText:SetText(""); frame:Hide()
    end
end

local function Create()
    frame = CreateFrame("Frame", "LunaFocusCastBar", UIParent)
    frame:SetMovable(true); frame:SetClampedToScreen(true); frame:SetFrameStrata("MEDIUM")
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not Settings().locked and not InCombatLockdown() then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        Settings().pos = {point=point, relPoint=relPoint, x=x, y=y}
        for _, axis in ipairs({"X", "Y"}) do
            local box = _G["UIThingsFocusCastBarPos" .. axis]
            if box then box:SetText(tostring(math.floor((axis == "X" and x or y)*10+.5)/10)) end
        end
    end)
    icon = frame:CreateTexture(nil, "ARTWORK")
    bar = CreateFrame("StatusBar", nil, frame)
    bar:SetMinMaxValues(0, 1)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND"); bar.bg:SetAllPoints()
    nameText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameText:SetPoint("LEFT", 4, 0); nameText:SetJustifyH("LEFT")
    timeText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    timeText:SetPoint("RIGHT", -4, 0)
    borders = {}
    for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        borders[side] = frame:CreateTexture(nil, "BORDER")
    end
end

function Focus.UpdateSettings()
    if not UIThingsDB or not UIThingsDB.castBar or not Settings() then return end
    if InCombatLockdown() then pending = true; return end
    pending = false
    events:UnregisterAllEvents(); events:RegisterEvent("PLAYER_REGEN_ENABLED")
    if not Settings().enabled then
        if frame then frame:SetScript("OnUpdate", nil); frame:Hide() end
        duration = nil; return
    end
    if not frame then Create() end
    local s, common = Settings(), UIThingsDB.castBar
    local width, height = s.width, s.height
    frame:SetSize(width + (common.showIcon and height+2 or 0), height)
    frame:ClearAllPoints(); frame:SetPoint(s.pos.point, UIParent, s.pos.relPoint or s.pos.point, s.pos.x, s.pos.y)
    frame:EnableMouse(not s.locked)
    icon:ClearAllPoints(); icon:SetPoint("LEFT", frame, "LEFT"); icon:SetSize(height, height); icon:SetShown(common.showIcon)
    bar:ClearAllPoints(); bar:SetPoint("TOPLEFT", frame, "TOPLEFT", common.showIcon and height+2 or 0, 0)
    bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    bar:SetStatusBarTexture(common.barTexture); bar.bg:SetColorTexture(common.bgColor.r, common.bgColor.g, common.bgColor.b, common.bgColor.a)
    nameText:SetFont(common.font, common.fontSize, "OUTLINE"); timeText:SetFont(common.font, common.fontSize, "OUTLINE")
    nameText:SetWidth(math.max(10,width-65)); nameText:SetWordWrap(false)
    nameText:SetShown(common.showSpellName); timeText:SetShown(common.showCastTime)
    local c, size = common.borderColor, common.borderSize
    for side, tex in pairs(borders) do
        tex:ClearAllPoints(); tex:SetColorTexture(c.r,c.g,c.b,c.a or 1)
        if side == "TOP" or side == "BOTTOM" then
            tex:SetPoint(side.."LEFT", frame, side.."LEFT"); tex:SetPoint(side.."RIGHT", frame, side.."RIGHT"); tex:SetHeight(size)
        else
            tex:SetPoint("TOP"..side, frame, "TOP"..side); tex:SetPoint("BOTTOM"..side, frame, "BOTTOM"..side); tex:SetWidth(size)
        end
        tex:SetShown(size > 0)
    end
    events:RegisterEvent("PLAYER_FOCUS_CHANGED"); events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    for _, suffix in ipairs({"START","STOP","FAILED","INTERRUPTED","DELAYED","CHANNEL_START","CHANNEL_STOP",
        "CHANNEL_UPDATE","INTERRUPTIBLE","NOT_INTERRUPTIBLE","EMPOWER_START","EMPOWER_STOP","EMPOWER_UPDATE"}) do
        events:RegisterUnitEvent("UNIT_SPELLCAST_"..suffix, "focus")
    end
    Refresh()
end

events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or (event == "PLAYER_REGEN_ENABLED" and pending) then Focus.UpdateSettings()
    else Refresh() end
end)
events:RegisterEvent("PLAYER_LOGIN")
addon.LayoutMode.RegisterTarget("Focus cast bar", function() return frame end,
    function() return Settings() and Settings().enabled end)
