-- Shared look for Luna's own UI (both clients): one global font and flat buttons.
-- Font: UIThingsDB.general.font (picker on the General UI page). Luna's labels use
-- the LunaFont* objects below (copies of Blizzard's GameFont* objects with the
-- global face), so changing the font updates them live. SetFont call sites keep
-- their own size/flags and take the face from Style.Font().
-- Buttons: Style.Button(button) flattens a UIPanelButtonTemplate-style text button
-- (1px border, flat fill, mint hover). Blizzard frames are never touched.
local _, addonTable = ...
local Style = {}
addonTable.Style = Style
LunaUITweaksAPI.Style = Style

local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local WHITE = "Interface\\Buttons\\WHITE8X8"

function Style.Font()
    local db = UIThingsDB and UIThingsDB.general
    return db and db.font or DEFAULT_FONT
end

-- Luna font object -> Blizzard object it copies (size, colour, shadow, flags).
local FONT_OBJECTS = {
    LunaFontNormal = "GameFontNormal",
    LunaFontNormalSmall = "GameFontNormalSmall",
    LunaFontNormalLarge = "GameFontNormalLarge",
    LunaFontNormalHuge = "GameFontNormalHuge",
    LunaFontHighlight = "GameFontHighlight",
    LunaFontHighlightSmall = "GameFontHighlightSmall",
    LunaFontHighlightLarge = "GameFontHighlightLarge",
    LunaFontHighlightHuge = "GameFontHighlightHuge",
    LunaFontDisable = "GameFontDisable",
    LunaFontDisableSmall = "GameFontDisableSmall",
    LunaFontChat = "ChatFontNormal",
    LunaFontNumberSmall = "NumberFontNormalSmall",
}
local LUNA_FOR = {}
for name, base in pairs(FONT_OBJECTS) do LUNA_FOR[base] = name end
local baseFonts = {}
for name, base in pairs(FONT_OBJECTS) do
    local source = _G[base] or GameFontNormal
    local object = CreateFont(name)
    object:CopyFontObject(source)
    local _, size, flags = source:GetFont()
    baseFonts[name] = { size = size or 12, flags = flags or "" }
end

-- Re-applies the global face to every Luna font object (labels update live).
function Style.ApplyFonts()
    local face = Style.Font()
    for name, base in pairs(baseFonts) do
        local object = _G[name]
        -- A font file missing on this client must not leave text blank.
        local ok = pcall(object.SetFont, object, face, base.size, base.flags)
        if not ok or not object:GetFont() then object:SetFont(DEFAULT_FONT, base.size, base.flags) end
    end
end

-- Sets the global font and refreshes modules that size their own text.
function Style.SetFont(path)
    UIThingsDB.general = UIThingsDB.general or {}
    UIThingsDB.general.font = path
    Style.ApplyFonts()
    if InCombatLockdown() then return end
    for _, module in pairs(addonTable) do
        if type(module) == "table" and module ~= Style and type(module.UpdateSettings) == "function" then
            pcall(module.UpdateSettings)
        end
    end
end

-- Flat text button: hides the template artwork, draws a fill + 1px border.
-- Icon buttons and close buttons (no text) are left alone. Safe on secure
-- buttons: only textures and font objects change, never scripts or attributes.
function Style.Button(button)
    if not button or button.lunaFlat or not (button.GetFontString and button:GetFontString()) then return button end
    button.lunaFlat = true
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
        local texture = button[getter] and button[getter](button)
        if texture then texture:SetAlpha(0) end
    end
    for _, key in ipairs({ "Left", "Middle", "Right", "LeftTex", "MidTex", "RightTex" }) do
        if button[key] and button[key].SetAlpha then button[key]:SetAlpha(0) end
    end
    local fill = button:CreateTexture(nil, "BACKGROUND", nil, -7)
    fill:SetAllPoints()
    fill:SetColorTexture(.11, .16, .19, 1)
    for _, edge in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
        { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local line = button:CreateTexture(nil, "BORDER")
        line:SetColorTexture(.19, .25, .29, 1)
        line:SetPoint(edge[1])
        line:SetPoint(edge[2])
        if edge[3] then line:SetHeight(1) else line:SetWidth(1) end
    end
    button:SetHighlightTexture(WHITE)
    local highlight = button:GetHighlightTexture()
    if highlight then
        highlight:SetAllPoints()
        highlight:SetTexCoord(0, 1, 0, 1)
        highlight:SetBlendMode("BLEND")
        highlight:SetVertexColor(.35, .9, .76, .17)
    end
    -- Swap each Blizzard font object for its Luna copy (same size), keeping
    -- any smaller/larger object a caller already chose.
    for _, kind in ipairs({ "Normal", "Highlight", "Disabled" }) do
        local object = button["Get" .. kind .. "FontObject"](button)
        local name = object and object.GetName and object:GetName()
        local luna = name and LUNA_FOR[name]
        if luna and _G[luna] then button["Set" .. kind .. "FontObject"](button, _G[luna]) end
    end
    return button
end
