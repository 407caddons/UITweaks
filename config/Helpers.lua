local addonName, addonTable = ...
addonTable.ConfigHelpers = {}

local Helpers = addonTable.ConfigHelpers

-- ============================================================
-- Shared Difficulty Constants
-- ============================================================
Helpers.RAID_DIFFICULTIES = { [17] = "LFR", [14] = "Normal", [15] = "Heroic", [16] = "Mythic" }
Helpers.DUNGEON_DIFFICULTIES = { [1] = "Normal", [2] = "Heroic", [23] = "Mythic", [8] = "Mythic Keystone" }
Helpers.RAID_DIFF_ORDER = { 17, 14, 15, 16 }
Helpers.DUNGEON_DIFF_ORDER = { 1, 2, 23, 8 }

function Helpers.IsRaidDifficulty(diffID)
    return Helpers.RAID_DIFFICULTIES[tonumber(diffID)] ~= nil
end

function Helpers.IsDungeonDifficulty(diffID)
    return Helpers.DUNGEON_DIFFICULTIES[tonumber(diffID)] ~= nil
end

-- ============================================================
-- Shared Utilities
-- ============================================================

function Helpers.DeepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = Helpers.DeepCopy(v)
    end
    return copy
end

function Helpers.ApplyFrameBackdrop(frame, showBorder, borderColor, showBackground, backgroundColor)
    if showBorder or showBackground then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            tileSize = 0,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        if showBackground then
            local c = backgroundColor or { r = 0, g = 0, b = 0, a = 0.8 }
            frame:SetBackdropColor(c.r, c.g, c.b, c.a)
        else
            frame:SetBackdropColor(0, 0, 0, 0)
        end
        if showBorder then
            local bc = borderColor or { r = 1, g = 1, b = 1, a = 1 }
            frame:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
        else
            frame:SetBackdropBorderColor(0, 0, 0, 0)
        end
    else
        frame:SetBackdrop(nil)
    end
end

--- Build comprehensive font list
-- Combines known default fonts with dynamically discovered fonts from GetFonts()
-- @return table Array of {name, path} tables
local function BuildFontList()
    local fonts = {}

    -- Known WoW fonts with friendly names
    local knownFonts = {
        { name = "Friz Quadrata",            path = "Fonts\\FRIZQT__.TTF" },
        { name = "Arial Narrow",             path = "Fonts\\ARIALN.TTF" },
        { name = "Skurri",                   path = "Fonts\\skurri.ttf" },
        { name = "Morpheus",                 path = "Fonts\\MORPHEUS.TTF" },
        { name = "Friz Quadrata (Cyrillic)", path = "Fonts\\FRIZQT___CYR.TTF" },
        { name = "Morpheus (Cyrillic)",      path = "Fonts\\MORPHEUS_CYR.TTF" },
        { name = "Skurri (Cyrillic)",        path = "Fonts\\SKURRI_CYR.TTF" },
        { name = "K Damage",                 path = "Fonts\\K_Damage.TTF" },
        { name = "K Pagetext",               path = "Fonts\\K_Pagetext.TTF" },
        { name = "2002",                     path = "Fonts\\2002.ttf" },
        { name = "2002 Bold",                path = "Fonts\\2002B.ttf" },
        { name = "AR Hei",                   path = "Fonts\\ARHei.ttf" },
        { name = "AR Kai (Complex)",         path = "Fonts\\ARKai_C.ttf" },
        { name = "AR Kai (Traditional)",     path = "Fonts\\ARKai_T.ttf" },
        { name = "bHEI 00M",                 path = "Fonts\\bHEI00M.ttf" },
        { name = "bHEI 01B",                 path = "Fonts\\bHEI01B.ttf" },
        { name = "bKAI 00M",                 path = "Fonts\\bKAI00M.ttf" },
        { name = "bLEI 00D",                 path = "Fonts\\bLEI00D.ttf" },
        { name = "NIM",                      path = "Fonts\\NIM_____.ttf" },
        { name = "Noto Sans",                path = "Interface\\AddOns\\LunaUITweaks\\fonts\\NotoSans-Regular.ttf" },
    }

    -- Add all known fonts
    for _, font in ipairs(knownFonts) do
        table.insert(fonts, font)
    end

    -- Try to get additional fonts using GetFonts() API
    -- This returns font object names, not file paths
    local success, dynamicFonts = pcall(GetFonts)
    if success and dynamicFonts then
        local knownPaths = {}
        -- Build lookup of already-added paths
        for _, font in ipairs(fonts) do
            knownPaths[font.path:upper()] = true
        end

        -- GetFonts() returns font object names - try to extract their file paths
        for _, fontObjectName in ipairs(dynamicFonts) do
            -- Try to get the global font object by name
            local fontObj = _G[fontObjectName]
            if fontObj and type(fontObj) == "table" and fontObj.GetFont then
                -- Extract the font file path using FontInstance:GetFont()
                local successGet, fontPath, height, flags = pcall(fontObj.GetFont, fontObj)
                if successGet and fontPath and type(fontPath) == "string" and fontPath ~= "" then
                    -- Check if we already have this font path
                    if not knownPaths[fontPath:upper()] then
                        -- Add this newly discovered font
                        table.insert(fonts, {
                            name = fontObjectName, -- Use the object name as the display name
                            path = fontPath
                        })
                        knownPaths[fontPath:upper()] = true
                    end
                end
            end
        end
    end

    -- Sort alphabetically by name
    table.sort(fonts, function(a, b) return a.name < b.name end)

    return fonts
end

-- Shared font list (built once on load)
Helpers.fonts = BuildFontList()

-- Cached font objects for dropdown preview (keyed by font path)
local fontObjectCache = {}

--- Helper: Update Visuals based on enabled state
-- @param panel frame The panel frame
-- @param tab frame The tab button
-- @param enabled boolean Whether module is enabled
function Helpers.UpdateModuleVisuals(panel, tab, enabled)
    tab.isDisabled = not enabled

    if not enabled then
        -- Tint Tab Text Red
        if tab.Text then
            tab.Text:SetTextColor(1, 0.2, 0.2)
        elseif tab:GetFontString() then
            tab:GetFontString():SetTextColor(1, 0.2, 0.2)
        end
    else
        -- Reset Tab Text (Normal Color / White if selected handled by ConfigMain)
        if tab.Text then
            tab.Text:SetTextColor(1, 0.82, 0) -- GameFontNormal Color approx
        elseif tab:GetFontString() then
            tab:GetFontString():SetTextColor(1, 0.82, 0)
        end
    end
end

--- Helper: Create a "Reset to Defaults" button anchored to the top-right of a panel.
-- Clicking it shows a confirmation popup, then wipes and re-applies the module's
-- defaults from addonTable.Core.DEFAULTS, and reloads the UI.
-- @param panel frame The panel frame (button is anchored to its TOPRIGHT)
-- @param dbKey string The key in UIThingsDB (and DEFAULTS) to reset, e.g. "combat"
-- @param label string Optional button label (defaults to "Reset Defaults")
-- @return button The created button
function Helpers.CreateResetButton(panel, dbKey, label)
    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(120, 22)
    btn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)
    btn:SetText(label or "Reset Defaults")

    btn:SetScript("OnClick", function()
        StaticPopup_Show("LUNA_RESET_MODULE_CONFIRM", dbKey, nil, dbKey)
    end)

    return btn
end

-- Static popup for per-module reset confirmation (registered once)
if not StaticPopupDialogs["LUNA_RESET_MODULE_CONFIRM"] then
    StaticPopupDialogs["LUNA_RESET_MODULE_CONFIRM"] = {
        text = "Reset '%s' settings to defaults?\n\nThis will reload the UI.",
        button1 = "Reset & Reload",
        button2 = "Cancel",
        OnAccept = function(self, data)
            local key = data
            local defaults = addonTable and addonTable.Core and addonTable.Core.DEFAULTS
            if defaults and defaults[key] and UIThingsDB and UIThingsDB[key] then
                wipe(UIThingsDB[key])
                -- Deep copy defaults for this key back into UIThingsDB
                local function DeepCopyInto(target, source)
                    for k, v in pairs(source) do
                        if type(v) == "table" then
                            target[k] = {}
                            DeepCopyInto(target[k], v)
                        else
                            target[k] = v
                        end
                    end
                end
                DeepCopyInto(UIThingsDB[key], defaults[key])
            end
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

--- Helper: Create a "Reset All" button (for AddonVersions panel).
-- Resets the entire UIThingsDB to defaults and reloads.
-- @param panel frame The parent frame
-- @return button The created button
function Helpers.CreateResetAllButton(panel)
    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(100, 22)
    btn:SetText("Reset All")

    btn:SetScript("OnClick", function()
        StaticPopup_Show("LUNA_RESET_ALL_CONFIRM")
    end)

    return btn
end

-- Static popup for full reset (registered once)
if not StaticPopupDialogs["LUNA_RESET_ALL_CONFIRM"] then
    StaticPopupDialogs["LUNA_RESET_ALL_CONFIRM"] = {
        text = "Reset ALL LunaUITweaks settings to defaults?\n\nThis will reload the UI.",
        button1 = "Reset All & Reload",
        button2 = "Cancel",
        OnAccept = function(self, data)
            UIThingsDB = nil
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

--- Helper: Create Section Header
-- @param parent frame Parent frame
-- @param text string Header text
-- @param yOffset number Y offset from TOPLEFT
-- @return fontstring The created header
function Helpers.CreateSectionHeader(parent, text, yOffset)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 16, yOffset)
    header:SetText(text)
    header:SetTextColor(1, 0.82, 0) -- Gold

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    line:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    line:SetHeight(1)
    line:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    return header
end

--- Helper: Create Color Picker
-- @param parent frame Parent frame
-- @param name string Unique name for the button
-- @param label string Label text
-- @param getFunc function Function that returns r, g, b
-- @param setFunc function Function that sets r, g, b
-- @param yOffset number Y offset from TOPLEFT
-- @return frame The color picker button
function Helpers.CreateColorPicker(parent, name, label, getFunc, setFunc, yOffset)
    local button = CreateFrame("Button", name, parent)
    button:SetSize(200, 24)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    button:EnableMouse(true)
    button:RegisterForClicks("AnyUp")

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetSize(24, 24)
    button.bg:SetPoint("LEFT")
    button.bg:SetColorTexture(1, 1, 1)

    button.color = button:CreateTexture(nil, "OVERLAY")
    button.color:SetPoint("LEFT", button.bg, "LEFT", 2, 0)
    button.color:SetSize(20, 20)

    local r, g, b = getFunc()
    button.color:SetColorTexture(r, g, b)

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.text:SetPoint("LEFT", button.bg, "RIGHT", 10, 0)
    button.text:SetText(label)

    button:SetScript("OnClick", function(self)
        local r, g, b = getFunc()

        local function SwatchFunc()
            local newR, newG, newB = ColorPickerFrame:GetColorRGB()
            setFunc(newR, newG, newB)
            button.color:SetColorTexture(newR, newG, newB)
        end

        local function CancelFunc(previousValues)
            local newR, newG, newB
            if previousValues then
                newR, newG, newB = previousValues.r, previousValues.g, previousValues.b
            else
                newR, newG, newB = r, g, b
            end
            setFunc(newR, newG, newB)
            button.color:SetColorTexture(newR, newG, newB)
        end

        if ColorPickerFrame.SetupColorPickerAndShow then
            local info = {
                swatchFunc = SwatchFunc,
                cancelFunc = CancelFunc,
                r = r,
                g = g,
                b = b,
                hasOpacity = false,
            }
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            ColorPickerFrame.func = SwatchFunc
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame.cancelFunc = CancelFunc
            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame:Show()
        end
    end)

    return button
end

--- Helper: Create Color Swatch with Opacity support
-- Creates a color picker button that works with color tables {r, g, b, a}
-- @param parent frame Parent frame
-- @param labelText string Label text
-- @param colorTable table Color table with r, g, b, a fields
-- @param onChangeFunc function Callback when color changes (optional)
-- @param xOffset number X offset from TOPLEFT
-- @param yOffset number Y offset from TOPLEFT
-- @param hasOpacity boolean Whether to show opacity slider (default true)
-- @return button, label The color swatch button and label
function Helpers.CreateColorSwatch(parent, labelText, colorTable, onChangeFunc, xOffset, yOffset, hasOpacity)
    if hasOpacity == nil then hasOpacity = true end

    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", xOffset, yOffset)
    label:SetText(labelText)

    local swatch = CreateFrame("Button", nil, parent)
    swatch:SetSize(20, 20)
    swatch:SetPoint("LEFT", label, "RIGHT", 5, 0)

    swatch.tex = swatch:CreateTexture(nil, "OVERLAY")
    swatch.tex:SetAllPoints()
    swatch.tex:SetColorTexture(colorTable.r, colorTable.g, colorTable.b, colorTable.a or 1)

    Mixin(swatch, BackdropTemplateMixin)
    swatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    swatch:SetBackdropBorderColor(1, 1, 1)

    swatch:SetScript("OnClick", function(self)
        local prevR, prevG, prevB, prevA = colorTable.r, colorTable.g, colorTable.b, colorTable.a or 1

        local info = {}
        info.r, info.g, info.b, info.opacity = prevR, prevG, prevB, prevA
        info.hasOpacity = hasOpacity

        info.opacityFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = hasOpacity and ColorPickerFrame:GetColorAlpha() or 1
            colorTable.r, colorTable.g, colorTable.b, colorTable.a = r, g, b, a
            swatch.tex:SetColorTexture(r, g, b, a)
            if onChangeFunc then onChangeFunc() end
        end

        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = hasOpacity and ColorPickerFrame:GetColorAlpha() or 1
            colorTable.r, colorTable.g, colorTable.b, colorTable.a = r, g, b, a
            swatch.tex:SetColorTexture(r, g, b, a)
            if onChangeFunc then onChangeFunc() end
        end

        info.cancelFunc = function()
            colorTable.r, colorTable.g, colorTable.b, colorTable.a = prevR, prevG, prevB, prevA
            swatch.tex:SetColorTexture(prevR, prevG, prevB, prevA)
            if onChangeFunc then onChangeFunc() end
        end

        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    return swatch, label
end

--- Helper: Create Font Dropdown with visual font preview
-- @param parent frame Parent frame
-- @param name string Unique name for the dropdown
-- @param labelText string Label text above dropdown
-- @param currentFontPath string Currently selected font path
-- @param onSelectFunc function Callback when font is selected, receives (fontPath, fontName)
-- @param xOffset number X offset from TOPLEFT (default 20)
-- @param yOffset number Y offset from TOPLEFT
-- @return frame The dropdown frame
function Helpers.CreateFontDropdown(parent, name, labelText, currentFontPath, onSelectFunc, xOffset, yOffset)
    xOffset = xOffset or 20

    -- Label
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", xOffset, yOffset)
    label:SetText(labelText)

    -- Dropdown
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -15, -10)

    local function OnClick(self)
        UIDropDownMenu_SetSelectedID(dropdown, self:GetID())
        if onSelectFunc then
            onSelectFunc(self.value, self.fontName)
        end
    end

    local function Initialize(self, level)
        for i, fontData in ipairs(Helpers.fonts) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = fontData.name
            info.value = fontData.path
            info.fontName = fontData.name
            info.func = OnClick

            -- Reuse cached font objects for dropdown preview
            local fontObj = fontObjectCache[fontData.path]
            if not fontObj then
                fontObj = CreateFont("LunaFontPreview_" .. i)
                local success = pcall(fontObj.SetFont, fontObj, fontData.path, 12, "")
                if success then
                    fontObjectCache[fontData.path] = fontObj
                else
                    fontObj = nil
                end
            end
            if fontObj then
                info.fontObject = fontObj
            end

            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(dropdown, Initialize)

    -- Set initial selected font
    local selectedName = "Select Font"
    for i, f in ipairs(Helpers.fonts) do
        if f.path == currentFontPath then
            selectedName = f.name
            break
        end
    end
    UIDropDownMenu_SetText(dropdown, selectedName)

    return dropdown
end

--- Build status bar texture list
-- Uses known working texture paths and dynamically discovered fileIDs from existing StatusBar frames
-- @return table Array of {name, path} tables where path is a string path or numeric fileID
local function BuildTextureList()
    local textures = {}
    local seen = {}

    local function AddTexture(name, path)
        -- Normalise key: uppercase for strings, tostring for numbers
        local key = type(path) == "string" and path:upper() or tostring(path)
        if not seen[key] then
            seen[key] = true
            table.insert(textures, { name = name, path = path })
        end
    end

    -- Known working WoW status bar textures
    AddTexture("Blizzard", "Interface\\TargetingFrame\\UI-StatusBar")
    AddTexture("Blizzard Character", "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar")
    AddTexture("Blizzard Raid", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
    AddTexture("Blizzard Party", "Interface\\RaidFrame\\Raid-Bar-Resource-Fill")
    AddTexture("Solid", "Interface\\Buttons\\WHITE8X8")
    AddTexture("NamePlate", "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")

    -- Dynamically discover textures from existing StatusBar frames
    -- Modern WoW often returns numeric fileIDs from GetTexture(), which are valid for SetStatusBarTexture
    local statusBarNames = {
        "PlayerCastingBarFrame",
        "MirrorTimer1StatusBar",
    }

    for _, frameName in ipairs(statusBarNames) do
        local frame = _G[frameName]
        if frame and frame.GetStatusBarTexture then
            pcall(function()
                local tex = frame:GetStatusBarTexture()
                if tex and tex.GetTexture then
                    local texVal = tex:GetTexture()
                    if texVal and texVal ~= "" then
                        if type(texVal) == "string" then
                            local friendlyName = texVal:match("([^\\]+)$") or texVal
                            friendlyName = friendlyName:gsub("%.%w+$", ""):gsub("UI%-", ""):gsub("%-", " ")
                            AddTexture(frameName .. " (" .. friendlyName .. ")", texVal)
                        elseif type(texVal) == "number" then
                            AddTexture(frameName .. " (ID " .. texVal .. ")", texVal)
                        end
                    end
                end
            end)
        end
    end

    -- Sort alphabetically by name
    table.sort(textures, function(a, b) return a.name < b.name end)

    return textures
end

-- Shared texture list (built once on load)
Helpers.textures = BuildTextureList()

--- Helper: Create Texture Dropdown with visual texture preview
-- @param parent frame Parent frame
-- @param name string Unique name for the dropdown
-- @param labelText string Label text above dropdown
-- @param currentTexturePath string Currently selected texture path
-- @param onSelectFunc function Callback when texture is selected, receives (texturePath, textureName)
-- @param xOffset number X offset from TOPLEFT (default 20)
-- @param yOffset number Y offset from TOPLEFT
-- @return frame The dropdown frame, and a preview texture
function Helpers.CreateTextureDropdown(parent, name, labelText, currentTexturePath, onSelectFunc, xOffset, yOffset)
    xOffset = xOffset or 20

    -- Label
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", xOffset, yOffset)
    label:SetText(labelText)

    -- Preview bar showing current texture
    local previewFrame = CreateFrame("Frame", nil, parent)
    previewFrame:SetSize(200, 16)
    previewFrame:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)

    local previewBg = previewFrame:CreateTexture(nil, "BACKGROUND")
    previewBg:SetAllPoints()
    previewBg:SetColorTexture(0, 0, 0, 0.8)

    local previewTex = previewFrame:CreateTexture(nil, "ARTWORK")
    previewTex:SetPoint("TOPLEFT", 1, -1)
    previewTex:SetPoint("BOTTOMRIGHT", -1, 1)
    previewTex:SetTexture(currentTexturePath)
    previewTex:SetVertexColor(0.4, 0.8, 1, 1)

    -- Dropdown
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", previewFrame, "BOTTOMLEFT", -15, -2)

    local selectedPath = currentTexturePath

    local function OnClick(self)
        selectedPath = self.value
        UIDropDownMenu_SetSelectedID(dropdown, self:GetID())
        UIDropDownMenu_SetText(dropdown, self.textureName)
        previewTex:SetTexture(self.value)
        if onSelectFunc then
            onSelectFunc(self.value, self.textureName)
        end
    end

    local function Initialize(self, level)
        for i, texData in ipairs(Helpers.textures) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = texData.name
            info.value = texData.path
            info.textureName = texData.name
            info.func = OnClick

            -- Add a colored texture icon to the left of each entry
            info.icon = texData.path
            info.tCoordLeft = 0
            info.tCoordRight = 1
            info.tCoordTop = 0
            info.tCoordBottom = 1

            info.checked = (texData.path == selectedPath)
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(dropdown, Initialize)
    UIDropDownMenu_SetWidth(dropdown, 180)

    -- Set initial selected texture name
    local selectedName = "Select Texture"
    for _, t in ipairs(Helpers.textures) do
        if t.path == currentTexturePath then
            selectedName = t.name
            break
        end
    end
    UIDropDownMenu_SetText(dropdown, selectedName)

    return dropdown, previewTex
end
