local addonName, addonTable = ...
local ChatSkin = {}
addonTable.ChatSkin = ChatSkin

local containerFrame = nil
local resizeGrip = nil
local skinnedFrames = {}
local skinnedTabs = {}
local hiddenButtons = {}
local isTabUnlocked = false
local isSetup = false
local hooksInstalled = false
local suppressSetPoint = false
local copyButton = nil
local copyEditBox = nil
local copyFrame = nil
local isCopyBoxVisible = false
local socialButton = nil
local channelsButton = nil
local languageButton = nil

local urlCopyFrame = nil
local urlCopyEditBox = nil
local savedTimestampCVar = nil
local filtersInstalled = false

local EDITBOX_HEIGHT = 28
local INNER_PAD = 4
local BTNFRAME_WIDTH = 29
local MIN_CHAT_W = 200
local MIN_CHAT_H = 100
local COPY_BUTTON_SIZE = 20
local COPY_FRAME_WIDTH = 250
local COPY_FRAME_SPACING = 4

-- Timestamp format options for the showTimestamps CVar
local TIMESTAMP_FORMATS = {
    { label = "Off",            value = "none" },
    { label = "HH:MM (24h)",    value = "%H:%M " },
    { label = "HH:MM:SS (24h)", value = "%H:%M:%S " },
    { label = "HH:MM AM/PM",    value = "%I:%M %p " },
    { label = "HH:MM:SS AM/PM", value = "%I:%M:%S %p " },
}

-- Apply the timestamp CVar based on current settings
local function ApplyTimestampSetting()
    local format = UIThingsDB.chatSkin.timestamps or "none"
    SetCVar("showTimestamps", format)
    CHAT_TIMESTAMP_FORMAT = (format ~= "none") and format or nil
end

-- URL Detection Patterns
-- Order matters: more specific patterns first
local URL_PATTERNS = {
    -- Full URLs with protocol
    "(https?://[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]+)",
    -- www. prefixed URLs
    "(www%.[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]+)",
}

-- Wrap detected URLs in custom hyperlink format
-- Shared table to reduce garbage checks
local placeholders = {}

-- Wrap detected URLs in custom hyperlink format
local function FormatURLs(msg)
    if not msg then return msg end

    -- Fast check: if no "http" or "www", skip heavy processing
    -- This covers the two patterns in URL_PATTERNS
    if not (string.find(msg, "http") or string.find(msg, "www")) then
        return msg
    end

    -- Don't process messages that already contain our custom links
    if string.find(msg, "|Hlunaurl:") then return msg end

    -- Reuse table
    wipe(placeholders)

    -- Extract existing hyperlinks and replace with placeholders to avoid matching URLs inside them
    local placeholderIdx = 0
    local safeMsg = msg:gsub("(|H.-|h.-|h)", function(link)
        placeholderIdx = placeholderIdx + 1
        local key = "\001LINK" .. placeholderIdx .. "\001"
        placeholders[key] = link
        return key
    end)

    -- Also protect color codes that might interfere
    safeMsg = safeMsg:gsub("(|c%x%x%x%x%x%x%x%x)", function(code)
        placeholderIdx = placeholderIdx + 1
        local key = "\001LINK" .. placeholderIdx .. "\001"
        placeholders[key] = code
        return key
    end)

    for _, pattern in ipairs(URL_PATTERNS) do
        safeMsg = safeMsg:gsub(pattern, function(url)
            local displayURL = url
            -- Truncate display if very long
            if #displayURL > 50 then
                displayURL = displayURL:sub(1, 47) .. "..."
            end
            return "|cff33bbff|Hlunaurl:" .. url .. "|h[" .. displayURL .. "]|h|r"
        end)
    end

    -- Restore placeholders (use plain string find/replace to avoid pattern interpretation)
    for key, original in pairs(placeholders) do
        local start, stop = safeMsg:find(key, 1, true)
        if start then
            safeMsg = safeMsg:sub(1, start - 1) .. original .. safeMsg:sub(stop + 1)
        end
    end

    return safeMsg
end

-- Chat message filter to detect and linkify URLs
local function URLMessageFilter(self, event, msg, ...)
    if not UIThingsDB.chatSkin.enabled then return false end
    local newMsg = FormatURLs(msg)
    if newMsg ~= msg then
        return false, newMsg, ...
    end
    return false
end

-- Keyword highlight filter
local function HighlightKeywords(msg)
    local keywords = UIThingsDB.chatSkin.highlightKeywords
    if not keywords or #keywords == 0 then return msg end

    local color = UIThingsDB.chatSkin.highlightColor or { r = 1, g = 1, b = 0 }
    local colorCode = string.format("|cFF%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)

    -- Protect existing hyperlinks and color codes from modification
    local placeholders = {}
    local placeholderIdx = 0
    local safeMsg = msg:gsub("(|H.-|h.-|h)", function(link)
        placeholderIdx = placeholderIdx + 1
        local key = "\001KW" .. placeholderIdx .. "\001"
        placeholders[key] = link
        return key
    end)
    safeMsg = safeMsg:gsub("(|c%x%x%x%x%x%x%x%x)", function(code)
        placeholderIdx = placeholderIdx + 1
        local key = "\001KW" .. placeholderIdx .. "\001"
        placeholders[key] = code
        return key
    end)
    safeMsg = safeMsg:gsub("(|r)", function(code)
        placeholderIdx = placeholderIdx + 1
        local key = "\001KW" .. placeholderIdx .. "\001"
        placeholders[key] = code
        return key
    end)

    -- Apply keyword highlights (case-insensitive)
    for _, keyword in ipairs(keywords) do
        if keyword ~= "" then
            -- Escape Lua pattern special characters in keyword
            local escaped = keyword:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
            safeMsg = safeMsg:gsub("(" .. escaped .. ")", colorCode .. "%1|r")
        end
    end

    -- Restore placeholders
    for key, original in pairs(placeholders) do
        local start, stop = safeMsg:find(key, 1, true)
        while start do
            safeMsg = safeMsg:sub(1, start - 1) .. original .. safeMsg:sub(stop + 1)
            start, stop = safeMsg:find(key, 1, true)
        end
    end

    return safeMsg
end

local function KeywordMessageFilter(self, event, msg, ...)
    if not UIThingsDB.chatSkin.enabled then return false end
    local keywords = UIThingsDB.chatSkin.highlightKeywords
    if not keywords or #keywords == 0 then return false end

    local newMsg = HighlightKeywords(msg)
    if newMsg ~= msg then
        if UIThingsDB.chatSkin.highlightSound then
            PlaySound(3081) -- RAID_WARNING sound
        end
        return false, newMsg, ...
    end
    return false
end

-- Border helper
local function EnsureBorders(frame)
    if not frame.lunaBorders then
        frame.lunaBorders = {
            top = frame:CreateTexture(nil, "OVERLAY"),
            bottom = frame:CreateTexture(nil, "OVERLAY"),
            left = frame:CreateTexture(nil, "OVERLAY"),
            right = frame:CreateTexture(nil, "OVERLAY"),
        }
    end
    return frame.lunaBorders
end

local function UpdateBorders(frame, borderSize, bc)
    local borders = EnsureBorders(frame)
    if borderSize <= 0 then
        for _, tex in pairs(borders) do tex:Hide() end
        return
    end
    borders.top:ClearAllPoints()
    borders.top:SetPoint("TOPLEFT", 0, 0)
    borders.top:SetPoint("TOPRIGHT", 0, 0)
    borders.top:SetHeight(borderSize)
    borders.top:SetColorTexture(bc.r, bc.g, bc.b, bc.a or 1)
    borders.top:Show()

    borders.bottom:ClearAllPoints()
    borders.bottom:SetPoint("BOTTOMLEFT", 0, 0)
    borders.bottom:SetPoint("BOTTOMRIGHT", 0, 0)
    borders.bottom:SetHeight(borderSize)
    borders.bottom:SetColorTexture(bc.r, bc.g, bc.b, bc.a or 1)
    borders.bottom:Show()

    borders.left:ClearAllPoints()
    borders.left:SetPoint("TOPLEFT", 0, 0)
    borders.left:SetPoint("BOTTOMLEFT", 0, 0)
    borders.left:SetWidth(borderSize)
    borders.left:SetColorTexture(bc.r, bc.g, bc.b, bc.a or 1)
    borders.left:Show()

    borders.right:ClearAllPoints()
    borders.right:SetPoint("TOPRIGHT", 0, 0)
    borders.right:SetPoint("BOTTOMRIGHT", 0, 0)
    borders.right:SetWidth(borderSize)
    borders.right:SetColorTexture(bc.r, bc.g, bc.b, bc.a or 1)
    borders.right:Show()
end

-- Tab texture names to strip
local TAB_TEXTURE_SUFFIXES = {
    "Left", "Middle", "Right",
    "SelectedLeft", "SelectedMiddle", "SelectedRight",
    "HighlightLeft", "HighlightMiddle", "HighlightRight",
    "ActiveLeft", "ActiveMiddle", "ActiveRight",
}

local function SkinTab(tab)
    if not tab or skinnedTabs[tab] then return end
    local settings = UIThingsDB.chatSkin
    local tabName = tab:GetName()

    local originalTextures = {}
    for _, suffix in ipairs(TAB_TEXTURE_SUFFIXES) do
        local tex = tab[suffix] or (tabName and _G[tabName .. suffix])
        if tex and tex.SetTexture then
            originalTextures[suffix] = tex:GetTexture()
            tex:SetTexture(nil)
            if tex.SetAtlas then tex:SetAtlas(nil) end
            tex:SetAlpha(0)
        end
    end

    local highlight = tab:GetHighlightTexture()
    if highlight then highlight:SetAlpha(0) end
    if tab.Glow then tab.Glow:SetAlpha(0) end

    -- Active indicator line
    if not tab.lunaIndicator then
        tab.lunaIndicator = tab:CreateTexture(nil, "OVERLAY")
        tab.lunaIndicator:SetPoint("BOTTOMLEFT", 0, 0)
        tab.lunaIndicator:SetPoint("BOTTOMRIGHT", 0, 0)
        tab.lunaIndicator:SetHeight(2)
    end

    local isSelected = false
    if tabName then
        local idx = tabName:match("ChatFrame(%d+)Tab")
        if idx then
            local cf = _G["ChatFrame" .. idx]
            if cf and FCFDock_GetSelectedWindow and FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) == cf then
                isSelected = true
            end
        end
    end
    local c = isSelected and settings.activeTabColor or settings.inactiveTabColor
    tab.lunaIndicator:SetColorTexture(c.r, c.g, c.b, c.a or 1)
    tab.lunaIndicator:Show()

    local text = tab.Text or (tabName and _G[tabName .. "Text"])
    if text then text:SetAlpha(1) end

    skinnedTabs[tab] = { originalTextures = originalTextures }
end

local function UpdateTabColors(tab)
    if not tab or not skinnedTabs[tab] then return end
    local settings = UIThingsDB.chatSkin
    local tabName = tab:GetName()

    if tab.lunaIndicator then
        local isSelected = false
        if tabName then
            local idx = tabName:match("ChatFrame(%d+)Tab")
            if idx then
                local cf = _G["ChatFrame" .. idx]
                if cf and FCFDock_GetSelectedWindow and FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) == cf then
                    isSelected = true
                end
            end
        end
        local c = isSelected and settings.activeTabColor or settings.inactiveTabColor
        tab.lunaIndicator:SetColorTexture(c.r, c.g, c.b, c.a or 1)
    end
end

local function SkinEditBox(editBox)
    if not editBox then return end
    local regions = { editBox:GetRegions() }
    for _, region in ipairs(regions) do
        if region:IsObjectType("Texture") then
            local layer = region:GetDrawLayer()
            if layer == "BACKGROUND" or layer == "BORDER" then
                region:SetAlpha(0)
            end
        end
    end
    if editBox.SetBackdrop then editBox:SetBackdrop(nil) end

    if not editBox.lunaSeparator then
        editBox.lunaSeparator = editBox:CreateTexture(nil, "OVERLAY")
        editBox.lunaSeparator:SetPoint("TOPLEFT", 0, 0)
        editBox.lunaSeparator:SetPoint("TOPRIGHT", 0, 0)
        editBox.lunaSeparator:SetHeight(1)
        editBox.lunaSeparator:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    end
end

local function SkinChatFrame(chatFrame)
    if not chatFrame or skinnedFrames[chatFrame] then return end
    local name = chatFrame:GetName()
    if not name then return end

    -- Hide all background and border textures on the chat frame
    local bg = _G[name .. "Background"]
    if bg then
        bg:SetAlpha(0)
        bg:Hide()
        bg:SetScript("OnShow", function(self)
            if UIThingsDB.chatSkin.enabled then self:Hide() end
        end)
        if not bg.lunaHooked then
            local suppressBgAlpha = false
            hooksecurefunc(bg, "SetAlpha", function(self)
                if suppressBgAlpha then return end
                if UIThingsDB.chatSkin.enabled then
                    suppressBgAlpha = true
                    self:SetAlpha(0)
                    suppressBgAlpha = false
                end
            end)
            bg.lunaHooked = true
        end
    end

    -- Hide all border/clamp textures with OnShow + SetAlpha suppression
    local borderNames = {
        "TopLeftTexture", "TopRightTexture", "BottomLeftTexture", "BottomRightTexture",
        "TopTexture", "BottomTexture", "LeftTexture", "RightTexture",
        "Border", "BorderFrame",
    }
    for _, suffix in ipairs(borderNames) do
        local tex = chatFrame[suffix] or _G[name .. suffix]
        if tex then
            tex:SetAlpha(0)
            tex:Hide()
            if not tex.lunaHooked then
                tex:HookScript("OnShow", function(self)
                    if UIThingsDB.chatSkin.enabled then self:Hide() end
                end)
                local suppressAlpha = false
                hooksecurefunc(tex, "SetAlpha", function(self)
                    if suppressAlpha then return end
                    if UIThingsDB.chatSkin.enabled then
                        suppressAlpha = true
                        self:SetAlpha(0)
                        suppressAlpha = false
                    end
                end)
                tex.lunaHooked = true
            end
        end
    end

    -- Also iterate all regions to catch any remaining border textures
    for _, region in pairs({ chatFrame:GetRegions() }) do
        if region:IsObjectType("Texture") then
            local layer = region:GetDrawLayer()
            if layer == "BORDER" and not region.lunaHooked then
                region:SetAlpha(0)
                region:HookScript("OnShow", function(self)
                    if UIThingsDB.chatSkin.enabled then self:Hide() end
                end)
                local suppressAlpha = false
                hooksecurefunc(region, "SetAlpha", function(self)
                    if suppressAlpha then return end
                    if UIThingsDB.chatSkin.enabled then
                        suppressAlpha = true
                        self:SetAlpha(0)
                        suppressAlpha = false
                    end
                end)
                region.lunaHooked = true
            end
        end
    end

    local resize = chatFrame.ResizeButton or _G[name .. "ResizeButton"]
    if resize then resize:SetAlpha(0) end

    local editBox = _G[name .. "EditBox"]
    if editBox then SkinEditBox(editBox) end

    local tab = _G[name .. "Tab"]
    if tab then SkinTab(tab) end

    skinnedFrames[chatFrame] = true
end

local function HideButtons()
    local toHide = {
        ChatFrameMenuButton,
        ChatFrameChannelButton,
        QuickJoinToastButton,
        ChatFrameToggleVoiceDeafenButton,
        ChatFrameToggleVoiceMuteButton,
    }
    for _, btn in ipairs(toHide) do
        if btn and not tContains(hiddenButtons, btn) then
            btn:Hide()
            btn:SetScript("OnShow", function(self)
                if UIThingsDB.chatSkin.enabled then
                    self:Hide()
                end
            end)
            table.insert(hiddenButtons, btn)
        end
    end

    -- Hide the button frame background
    if ChatFrame1ButtonFrame then
        ChatFrame1ButtonFrame:SetAlpha(0)
        ChatFrame1ButtonFrame:Hide()
        if not ChatFrame1ButtonFrame.lunaHooked then
            ChatFrame1ButtonFrame:SetScript("OnShow", function(self)
                if UIThingsDB.chatSkin.enabled then
                    self:Hide()
                end
            end)
            ChatFrame1ButtonFrame.lunaHooked = true
        end
    end
end

local function RestoreButtons()
    for _, btn in ipairs(hiddenButtons) do
        if btn then
            btn:SetScript("OnShow", nil)
            btn:Show()
        end
    end
    wipe(hiddenButtons)

    -- Restore the button frame background
    if ChatFrame1ButtonFrame then
        ChatFrame1ButtonFrame:SetScript("OnShow", nil)
        ChatFrame1ButtonFrame:SetAlpha(1)
        ChatFrame1ButtonFrame:Show()
    end
end

local function SkinAllChatFrames()
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf then SkinChatFrame(cf) end
    end
end

-- Get the actual tab bar height by measuring the first visible tab
local function GetTabHeight()
    local tab1 = ChatFrame1Tab
    if tab1 and tab1:IsShown() then
        return tab1:GetHeight() or 24
    end
    return 24
end

-- Get all chat content from the current visible chat frame
local function GetChatContent()
    local selectedFrame = FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) or ChatFrame1
    if not selectedFrame then
        addonTable.Core.Log("ChatSkin", "GetChatContent: no selected frame", 2)
        return ""
    end

    local lines = {}
    local numMessages = selectedFrame:GetNumMessages()
    addonTable.Core.Log("ChatSkin", string.format("GetChatContent: frame=%s numMessages=%d hasGetMessageInfo=%s",
        selectedFrame:GetName() or "?", numMessages, tostring(selectedFrame.GetMessageInfo ~= nil)), 0)

    for i = 1, numMessages do
        if selectedFrame.GetMessageInfo then
            local ok, msg = pcall(selectedFrame.GetMessageInfo, selectedFrame, i)
            if ok and msg and not issecretvalue(msg) and msg ~= "" then
                -- Strip all WoW UI escape sequences for clean copyable text
                local clean = msg
                clean = clean:gsub("|T.-|t", "")
                clean = clean:gsub("|A.-|a", "")
                clean = clean:gsub("|H.-|h(.-)|h", "%1")
                clean = clean:gsub("|c%x%x%x%x%x%x%x%x", "")
                clean = clean:gsub("|r", "")
                clean = clean:gsub("|n", "\n")
                clean = clean:gsub("|", "")
                table.insert(lines, clean)
            elseif not ok then
                addonTable.Core.Log("ChatSkin", string.format("GetMessageInfo error at %d: %s", i, tostring(msg)), 2)
                break
            end
        end
    end

    addonTable.Core.Log("ChatSkin", string.format("GetChatContent: got %d lines", #lines), 0)

    -- If GetMessageInfo didn't work, try the visible message regions
    if #lines == 0 then
        local regions = { selectedFrame:GetRegions() }
        addonTable.Core.Log("ChatSkin", string.format("Fallback: checking %d regions", #regions), 0)
        for _, region in ipairs(regions) do
            if region:IsObjectType("FontString") then
                local text = region:GetText()
                if text and text ~= "" then
                    local clean = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub(
                        "|T.-|t", "")
                    table.insert(lines, clean)
                end
            end
        end
    end

    return table.concat(lines, "\n")
end

-- Toggle the copy frame visibility
local function ToggleCopyBox()
    if not copyFrame or not copyEditBox then return end

    isCopyBoxVisible = not isCopyBoxVisible

    if isCopyBoxVisible then
        local content = GetChatContent()
        addonTable.Core.Log("ChatSkin", string.format("ToggleCopyBox: content length=%d, first 100 chars=[%s]",
            #content, content:sub(1, 100)), 0)
        copyFrame:Show()
        copyEditBox:Show()
        copyEditBox:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
        copyEditBox:SetTextColor(1, 1, 1, 1)
        copyEditBox:SetText("")
        copyEditBox:SetFocus()
        copyEditBox:SetText(content)
        copyEditBox:SetCursorPosition(0)
        -- Update height after frame is shown so geometry is valid
        C_Timer.After(0.05, function()
            if copyEditBox.UpdateHeight then
                copyEditBox:UpdateHeight()
            end
            copyEditBox:HighlightText()
            local textLen = #(copyEditBox:GetText() or "")
            addonTable.Core.Log("ChatSkin", string.format("After SetText: editbox text length=%d", textLen), 0)
        end)
    else
        copyFrame:Hide()
        copyEditBox:ClearFocus()
    end
end

-- Layout: size the container to fit around ChatFrame1 + tabs + editbox + ButtonFrame
local function LayoutContainer()
    if not containerFrame or not isSetup then return end

    local settings = UIThingsDB.chatSkin
    local border = settings.borderSize or 2
    local chatW = settings.chatWidth or 430
    local chatH = settings.chatHeight or 200
    local tabH = GetTabHeight()

    -- Container size = border + pad + chat + ButtonFrame + pad + border
    local totalW = chatW + BTNFRAME_WIDTH + (border * 2) + (INNER_PAD * 2)
    local totalH = tabH + chatH + EDITBOX_HEIGHT + (border * 2) + INNER_PAD
    containerFrame:SetSize(totalW, totalH)

    -- ChatFrame1: anchor directly below tab area, tight to top border
    suppressSetPoint = true
    ChatFrame1:ClearAllPoints()
    ChatFrame1:SetPoint("TOPLEFT", containerFrame, "TOPLEFT", border + INNER_PAD, -(tabH + border))
    ChatFrame1:SetSize(chatW, chatH)
    suppressSetPoint = false

    -- EditBox: anchor at bottom of container, inset to match chat area width
    local editBox = ChatFrame1EditBox
    if editBox then
        editBox:ClearAllPoints()
        editBox:SetPoint("BOTTOMLEFT", containerFrame, "BOTTOMLEFT", border + INNER_PAD + 2, border + INNER_PAD)
        editBox:SetPoint("BOTTOMRIGHT", containerFrame, "BOTTOMLEFT", border + INNER_PAD + chatW - 2, border + INNER_PAD)
        editBox:SetHeight(EDITBOX_HEIGHT)
    end

    -- Reposition the dock manager (tab bar) to sit inside the container top area
    if GeneralDockManager then
        GeneralDockManager:ClearAllPoints()
        GeneralDockManager:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, 0)
        GeneralDockManager:SetPoint("BOTTOMRIGHT", ChatFrame1, "TOPRIGHT", 0, 0)
        GeneralDockManager:SetHeight(tabH)
    end
end

local function SetupChatSkin()
    if isSetup then return end

    local settings = UIThingsDB.chatSkin

    -- Only capture current chat dimensions on first-ever setup (no saved values yet)
    if not settings.chatWidth or not settings.chatHeight then
        local curW = ChatFrame1:GetWidth()
        local curH = ChatFrame1:GetHeight()
        if curW > 100 and curW < 1200 then settings.chatWidth = curW end
        if curH > 50 and curH < 800 then settings.chatHeight = curH end
    end

    -- Create container
    containerFrame = CreateFrame("Frame", "LunaChatSkinContainer", UIParent, "BackdropTemplate")
    containerFrame:SetFrameStrata("LOW")
    containerFrame:SetFrameLevel(0)
    containerFrame:SetMovable(true)
    containerFrame:SetResizable(true)
    containerFrame:SetClampedToScreen(true)
    if containerFrame.SetResizeBounds then
        containerFrame:SetResizeBounds(MIN_CHAT_W + 20, MIN_CHAT_H + 80)
    end

    -- Background
    containerFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    local bg = settings.bgColor
    containerFrame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a or 0.7)

    -- Borders
    UpdateBorders(containerFrame, settings.borderSize or 2, settings.borderColor)

    -- Position
    local pos = settings.pos
    containerFrame:ClearAllPoints()
    containerFrame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x, pos.y)

    -- Reparent ChatFrame1, edit box, and dock manager
    ChatFrame1:SetParent(containerFrame)
    ChatFrame1:SetClampedToScreen(false)

    local editBox = ChatFrame1EditBox
    if editBox then
        editBox:SetParent(containerFrame)
    end

    if GeneralDockManager then
        GeneralDockManager:SetParent(containerFrame)
    end

    -- Save original timestamp CVar and apply our setting
    savedTimestampCVar = GetCVar("showTimestamps")
    ApplyTimestampSetting()

    -- Mark setup before layout
    isSetup = true

    -- Layout
    LayoutContainer()

    -- Skin visuals
    SkinAllChatFrames()

    -- Hide buttons (always hide when chat skin is enabled)
    HideButtons()

    -- Suppress Blizzard repositioning ChatFrame1 (only hook once)
    if not hooksInstalled then
        hooksecurefunc(ChatFrame1, "SetPoint", function()
            if suppressSetPoint or not isSetup then return end
            suppressSetPoint = true
            C_Timer.After(0, function()
                if isSetup and containerFrame then
                    local s = UIThingsDB.chatSkin
                    local border = s.borderSize or 2
                    local tabH = GetTabHeight()
                    ChatFrame1:ClearAllPoints()
                    ChatFrame1:SetPoint("TOPLEFT", containerFrame, "TOPLEFT", border + INNER_PAD,
                        -(tabH + border))
                    ChatFrame1:SetSize(s.chatWidth or 430, s.chatHeight or 200)
                end
                suppressSetPoint = false
            end)
        end)
    end -- hooksInstalled guard (SetPoint)

    -- Resize grip (bottom-right corner)
    resizeGrip = CreateFrame("Button", nil, containerFrame)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", containerFrame, "BOTTOMRIGHT", -2, 2)
    resizeGrip:SetFrameStrata("MEDIUM")
    resizeGrip:SetFrameLevel(10)
    resizeGrip:EnableMouse(true)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    resizeGrip:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            containerFrame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeGrip:SetScript("OnMouseUp", function(self, button)
        containerFrame:StopMovingOrSizing()
        -- Calculate new chat dimensions from the container size
        local s = UIThingsDB.chatSkin
        local border = s.borderSize or 2
        local tabH = GetTabHeight()
        local cW = containerFrame:GetWidth()
        local cH = containerFrame:GetHeight()
        local newChatW = cW - BTNFRAME_WIDTH - (border * 2) - (INNER_PAD * 2)
        local newChatH = cH - tabH - EDITBOX_HEIGHT - (border * 2) - (INNER_PAD * 2)
        if newChatW >= MIN_CHAT_W then s.chatWidth = newChatW end
        if newChatH >= MIN_CHAT_H then s.chatHeight = newChatH end
        LayoutContainer()
        -- Save position too since anchor may shift
        local point, _, relPoint, x, y = containerFrame:GetPoint()
        s.pos.point = point
        s.pos.relPoint = relPoint
        s.pos.x = x
        s.pos.y = y
    end)

    -- Start hidden if locked
    if settings.locked then
        resizeGrip:Hide()
    end

    -- Drag overlay for unified movement
    local dragOverlay = CreateFrame("Frame", nil, containerFrame)
    dragOverlay:SetAllPoints()
    dragOverlay:SetFrameStrata("MEDIUM")
    dragOverlay:EnableMouse(true)
    dragOverlay:RegisterForDrag("LeftButton")

    dragOverlay:SetScript("OnDragStart", function()
        containerFrame:StartMoving()
    end)
    dragOverlay:SetScript("OnDragStop", function()
        containerFrame:StopMovingOrSizing()
        local point, _, relPoint, x, y = containerFrame:GetPoint()
        settings.pos.point = point
        settings.pos.relPoint = relPoint
        settings.pos.x = x
        settings.pos.y = y
    end)

    -- Right-click to toggle tab unlock
    dragOverlay:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            isTabUnlocked = not isTabUnlocked
            ChatSkin.UpdateTabDraggability()
            if isTabUnlocked then
                addonTable.Core.Log("ChatSkin", "Tabs unlocked - drag tabs to reposition", addonTable.Core.LogLevel.INFO)
            else
                addonTable.Core.Log("ChatSkin", "Tabs locked", addonTable.Core.LogLevel.INFO)
            end
        end
    end)

    containerFrame.dragOverlay = dragOverlay

    -- Lock state
    if settings.locked then
        dragOverlay:Hide()
    end

    -- Create copy button (top-right corner)
    copyButton = CreateFrame("Button", nil, containerFrame, "UIPanelButtonTemplate")
    copyButton:SetSize(COPY_BUTTON_SIZE, COPY_BUTTON_SIZE)
    copyButton:SetPoint("TOPRIGHT", containerFrame, "TOPRIGHT", -4, -4)
    copyButton:SetText("C")
    copyButton:SetFrameStrata("MEDIUM")
    copyButton:SetFrameLevel(20)

    local btnFont = copyButton:GetFontString()
    if btnFont then
        btnFont:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    end

    copyButton:SetScript("OnClick", function()
        ToggleCopyBox()
    end)

    copyButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Copy Chat Content", 1, 1, 1)
        GameTooltip:AddLine("Click to toggle the copy/paste box", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)

    copyButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Create social button (below copy button)
    socialButton = CreateFrame("Button", nil, containerFrame, "UIPanelButtonTemplate")
    socialButton:SetSize(COPY_BUTTON_SIZE, COPY_BUTTON_SIZE)
    socialButton:SetPoint("TOP", copyButton, "BOTTOM", 0, -2)
    socialButton:SetText("S")
    socialButton:SetFrameStrata("MEDIUM")
    socialButton:SetFrameLevel(20)

    local socialFont = socialButton:GetFontString()
    if socialFont then
        socialFont:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    end

    socialButton:SetScript("OnClick", function()
        ToggleFriendsFrame()
    end)

    socialButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Social", 1, 1, 1)
        GameTooltip:AddLine("Click to open the Social/Friends window", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)

    socialButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Create channels button (below social button)
    channelsButton = CreateFrame("Button", nil, containerFrame, "UIPanelButtonTemplate")
    channelsButton:SetSize(COPY_BUTTON_SIZE, COPY_BUTTON_SIZE)
    channelsButton:SetPoint("TOP", socialButton, "BOTTOM", 0, -2)
    channelsButton:SetText("H")
    channelsButton:SetFrameStrata("MEDIUM")
    channelsButton:SetFrameLevel(20)

    local channelsFont = channelsButton:GetFontString()
    if channelsFont then
        channelsFont:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    end

    channelsButton:SetScript("OnClick", function()
        if ChannelFrame and ChannelFrame:IsShown() then
            ChannelFrame:Hide()
        else
            ToggleChannelFrame()
        end
    end)

    channelsButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Chat Channels", 1, 1, 1)
        GameTooltip:AddLine("Click to open the chat channel menu", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)

    channelsButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Create language button (below channels button)
    languageButton = CreateFrame("Button", nil, containerFrame, "UIPanelButtonTemplate")
    languageButton:SetSize(COPY_BUTTON_SIZE, COPY_BUTTON_SIZE)
    languageButton:SetPoint("TOP", channelsButton, "BOTTOM", 0, -2)
    languageButton:SetText("L")
    languageButton:SetFrameStrata("MEDIUM")
    languageButton:SetFrameLevel(20)

    local langFont = languageButton:GetFontString()
    if langFont then
        langFont:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    end

    languageButton:SetScript("OnClick", function(self)
        local menu = MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
            rootDescription:CreateTitle("Languages")
            local numLangs = GetNumLanguages()
            for i = 1, numLangs do
                local lang, langID = GetLanguageByIndex(i)
                rootDescription:CreateButton(lang, function()
                    ChatFrame1EditBox:SetAttribute("chatType", "SAY")
                    ChatFrame1EditBox.languageID = langID
                    addonTable.Core.Log("ChatSkin", "Language set to: " .. lang, addonTable.Core.LogLevel.INFO)
                end)
            end
        end)
    end)

    languageButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Language Menu", 1, 1, 1)
        GameTooltip:AddLine("Click to open the language/chat menu", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)

    languageButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Create copy frame (to the right of the main container, initially hidden)
    copyFrame = CreateFrame("Frame", "LunaChatSkinCopyFrame", UIParent, "BackdropTemplate")
    copyFrame:SetFrameStrata("MEDIUM")
    copyFrame:SetFrameLevel(5)
    copyFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    copyFrame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a or 0.7)

    -- Match container height and position to the right
    local totalH = containerFrame:GetHeight()
    copyFrame:SetSize(COPY_FRAME_WIDTH, totalH)
    copyFrame:SetPoint("LEFT", containerFrame, "RIGHT", COPY_FRAME_SPACING, 0)

    -- Add borders to copy frame
    UpdateBorders(copyFrame, settings.borderSize or 2, settings.borderColor)

    copyFrame:Hide()

    -- Create scrollable edit box inside copy frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, copyFrame, "UIPanelScrollFrameTemplate")
    local border = settings.borderSize or 2
    scrollFrame:SetPoint("TOPLEFT", copyFrame, "TOPLEFT", border + INNER_PAD, -(border + INNER_PAD))
    scrollFrame:SetPoint("BOTTOMRIGHT", copyFrame, "BOTTOMRIGHT", -(border + INNER_PAD + 20), border + INNER_PAD)

    copyEditBox = CreateFrame("EditBox", nil, scrollFrame)
    copyEditBox:SetMultiLine(true)
    copyEditBox:SetAutoFocus(false)
    copyEditBox:SetFontObject(ChatFontNormal)
    copyEditBox:SetTextColor(1, 1, 1, 1)
    local editBoxWidth = COPY_FRAME_WIDTH - (border + INNER_PAD) * 2 - 20
    copyEditBox:SetWidth(editBoxWidth)
    copyEditBox:SetHeight(totalH) -- Initial height, updated when content is set
    copyEditBox:SetMaxLetters(0)

    scrollFrame:SetScrollChild(copyEditBox)

    -- Helper FontString to measure text height (EditBox doesn't have GetStringHeight)
    local measureString = copyFrame:CreateFontString(nil, "BACKGROUND")
    measureString:SetFontObject(ChatFontNormal)
    measureString:SetWidth(editBoxWidth)
    measureString:Hide()

    local function UpdateEditBoxHeight()
        measureString:SetWidth(editBoxWidth)
        measureString:SetText(copyEditBox:GetText())
        local textHeight = measureString:GetStringHeight() or 100
        copyEditBox:SetHeight(math.max(textHeight + 20, scrollFrame:GetHeight()))
    end

    -- Update height when text changes so ScrollFrame knows the content size
    copyEditBox:SetScript("OnTextChanged", function(self)
        UpdateEditBoxHeight()
    end)

    copyEditBox.UpdateHeight = UpdateEditBoxHeight

    copyEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        ToggleCopyBox()
    end)

    copyEditBox:SetScript("OnEditFocusLost", function(self)
        if isCopyBoxVisible then
            C_Timer.After(0.1, function()
                if isCopyBoxVisible and not self:HasFocus() then
                    ToggleCopyBox()
                end
            end)
        end
    end)

    -- URL Copy Popup Frame (small floating editbox for copying a single URL)
    urlCopyFrame = CreateFrame("Frame", "LunaChatSkinURLCopy", UIParent, "BackdropTemplate")
    urlCopyFrame:SetFrameStrata("DIALOG")
    urlCopyFrame:SetFrameLevel(100)
    urlCopyFrame:SetSize(350, 50)
    urlCopyFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    urlCopyFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    urlCopyFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    urlCopyFrame:SetClampedToScreen(true)
    urlCopyFrame:Hide()

    local urlLabel = urlCopyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    urlLabel:SetPoint("TOPLEFT", 8, -4)
    urlLabel:SetText("Press Ctrl+C to copy, Escape to close")
    urlLabel:SetTextColor(0.7, 0.7, 0.7)

    urlCopyEditBox = CreateFrame("EditBox", nil, urlCopyFrame)
    urlCopyEditBox:SetPoint("TOPLEFT", 6, -18)
    urlCopyEditBox:SetPoint("BOTTOMRIGHT", -6, 6)
    urlCopyEditBox:SetFontObject(ChatFontNormal)
    urlCopyEditBox:SetAutoFocus(false)
    urlCopyEditBox:SetMaxLetters(0)

    urlCopyEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        urlCopyFrame:Hide()
    end)

    urlCopyEditBox:SetScript("OnEditFocusLost", function(self)
        C_Timer.After(0.1, function()
            if urlCopyFrame:IsShown() and not self:HasFocus() then
                urlCopyFrame:Hide()
            end
        end)
    end)

    -- All hooks below are permanent and must only be installed once
    if not hooksInstalled then
        -- Hook SetItemRef to handle our custom lunaurl hyperlinks
        local origSetItemRef = SetItemRef
        SetItemRef = function(link, text, button, chatFrame)
            local url = link:match("^lunaurl:(.+)$")
            if url then
                urlCopyEditBox:SetText(url)
                urlCopyFrame:ClearAllPoints()
                -- Position near the mouse cursor
                local x, y = GetCursorPosition()
                local scale = UIParent:GetEffectiveScale()
                urlCopyFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale + 10)
                urlCopyFrame:Show()
                urlCopyEditBox:HighlightText()
                urlCopyEditBox:SetFocus()
                return
            end
            return origSetItemRef(link, text, button, chatFrame)
        end

        -- Register URL detection filter on common chat events
        ChatSkin.InstallMessageFilters()

        -- Hook tab selection changes
        hooksecurefunc("FCFTab_UpdateColors", function(tab, selected)
            if not skinnedTabs[tab] or not UIThingsDB.chatSkin.enabled then return end
            local s = UIThingsDB.chatSkin
            local tabName = tab:GetName()

            for _, suffix in ipairs(TAB_TEXTURE_SUFFIXES) do
                local tex = tab[suffix] or (tabName and _G[tabName .. suffix])
                if tex and tex.SetTexture then
                    tex:SetTexture(nil)
                    if tex.SetAtlas then tex:SetAtlas(nil) end
                    tex:SetAlpha(0)
                end
            end

            if tab.lunaIndicator then
                local c = selected and s.activeTabColor or s.inactiveTabColor
                tab.lunaIndicator:SetColorTexture(c.r, c.g, c.b, c.a or 1)
            end
            local text = tab.Text or (tabName and _G[tabName .. "Text"])
            if text then text:SetAlpha(1) end
        end)

        -- Prevent tab fading
        hooksecurefunc("FCFTab_UpdateAlpha", function(chatFrame)
            if not UIThingsDB.chatSkin.enabled then return end
            local cfName = chatFrame:GetName()
            if not cfName then return end
            local tab = _G[cfName .. "Tab"]
            if tab and skinnedTabs[tab] then
                tab:SetAlpha(1)
                local text = tab.Text or _G[tab:GetName() .. "Text"]
                if text then text:SetAlpha(1) end
            end
        end)

        -- Auto-skin new windows
        hooksecurefunc("FCF_OpenNewWindow", function()
            C_Timer.After(0.1, function()
                if UIThingsDB.chatSkin.enabled then SkinAllChatFrames() end
            end)
        end)

        -- Event-based reskin
        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("UPDATE_CHAT_WINDOWS")
        eventFrame:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
        eventFrame:SetScript("OnEvent", function()
            if not UIThingsDB.chatSkin.enabled then return end
            C_Timer.After(0.1, function()
                SkinAllChatFrames()
                for tab in pairs(skinnedTabs) do UpdateTabColors(tab) end
            end)
        end)

        hooksInstalled = true
    end -- hooksInstalled guard
end

-- Chat events for URL message filters
local URL_FILTER_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_CHANNEL", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_BN_INLINE_TOAST_ALERT",
    "CHAT_MSG_COMMUNITIES_CHANNEL",
}

function ChatSkin.InstallMessageFilters()
    if filtersInstalled then return end
    for _, event in ipairs(URL_FILTER_EVENTS) do
        ChatFrame_AddMessageEventFilter(event, URLMessageFilter)
        ChatFrame_AddMessageEventFilter(event, KeywordMessageFilter)
    end
    filtersInstalled = true
end

function ChatSkin.RemoveMessageFilters()
    if not filtersInstalled then return end
    for _, event in ipairs(URL_FILTER_EVENTS) do
        ChatFrame_RemoveMessageEventFilter(event, URLMessageFilter)
        ChatFrame_RemoveMessageEventFilter(event, KeywordMessageFilter)
    end
    filtersInstalled = false
end

function ChatSkin.UpdateTabDraggability()
    for tab in pairs(skinnedTabs) do
        if isTabUnlocked then
            tab:SetMovable(true)
            tab:RegisterForDrag("LeftButton")
        else
            tab:RegisterForDrag()
        end
    end
end

function ChatSkin.Initialize()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function()
        if not UIThingsDB.chatSkin.enabled then return end
        C_Timer.After(0.5, function()
            if not isSetup then SetupChatSkin() end
        end)
    end)
end

function ChatSkin.UpdateSettings()
    local settings = UIThingsDB.chatSkin

    if not settings.enabled then
        ChatSkin.Disable()
        return
    end

    if not isSetup then
        SetupChatSkin()
        return
    end

    if containerFrame then
        local bg = settings.bgColor
        containerFrame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a or 0.7)
        UpdateBorders(containerFrame, settings.borderSize or 2, settings.borderColor)
        LayoutContainer()
    end

    if copyFrame then
        local bg = settings.bgColor
        copyFrame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a or 0.7)
        UpdateBorders(copyFrame, settings.borderSize or 2, settings.borderColor)
        -- Update height to match container
        if containerFrame then
            copyFrame:SetHeight(containerFrame:GetHeight())
        end
    end

    -- Re-install URL message filters if they were removed on disable
    ChatSkin.InstallMessageFilters()

    for tab in pairs(skinnedTabs) do UpdateTabColors(tab) end

    -- Reapply timestamp setting
    ApplyTimestampSetting()

    if containerFrame and containerFrame.dragOverlay then
        if settings.locked then
            containerFrame.dragOverlay:Hide()
            if resizeGrip then resizeGrip:Hide() end
            isTabUnlocked = false
            ChatSkin.UpdateTabDraggability()
        else
            containerFrame.dragOverlay:Show()
            if resizeGrip then resizeGrip:Show() end
        end
    end
end

function ChatSkin.Disable()
    if not isSetup then return end

    isSetup = false
    isTabUnlocked = false
    suppressSetPoint = true

    -- Remove URL message filters
    ChatSkin.RemoveMessageFilters()

    -- Restore original timestamp CVar
    if savedTimestampCVar then
        SetCVar("showTimestamps", savedTimestampCVar)
        CHAT_TIMESTAMP_FORMAT = (savedTimestampCVar ~= "none") and savedTimestampCVar or nil
        savedTimestampCVar = nil
    end

    RestoreButtons()

    for tab in pairs(skinnedTabs) do
        if tab.lunaIndicator then tab.lunaIndicator:Hide() end

        local tabName = tab:GetName()
        for _, suffix in ipairs(TAB_TEXTURE_SUFFIXES) do
            local tex = tab[suffix] or (tabName and _G[tabName .. suffix])
            if tex then tex:SetAlpha(1) end
        end

        local hl = tab:GetHighlightTexture()
        if hl then hl:SetAlpha(1) end
        if tab.Glow then tab.Glow:SetAlpha(1) end
        tab:SetAlpha(1)
    end
    wipe(skinnedTabs)

    for chatFrame in pairs(skinnedFrames) do
        local n = chatFrame:GetName()

        local bg = _G[n .. "Background"]
        if bg then
            bg:SetScript("OnShow", nil)
            bg:SetAlpha(1)
            bg:Show()
        end

        -- Restore border textures
        local borderNames = {
            "TopLeftTexture", "TopRightTexture", "BottomLeftTexture", "BottomRightTexture",
            "TopTexture", "BottomTexture", "LeftTexture", "RightTexture",
            "Border", "BorderFrame",
        }
        for _, suffix in ipairs(borderNames) do
            local tex = chatFrame[suffix] or _G[n .. suffix]
            if tex then
                if tex.SetAlpha then tex:SetAlpha(1) end
                if tex.Show then tex:Show() end
            end
        end
        for _, region in pairs({ chatFrame:GetRegions() }) do
            if region:IsObjectType("Texture") then
                local layer = region:GetDrawLayer()
                if layer == "BORDER" then
                    region:SetAlpha(1)
                end
            end
        end

        local resize = chatFrame.ResizeButton or _G[n .. "ResizeButton"]
        if resize then resize:SetAlpha(1) end

        local eb = _G[n .. "EditBox"]
        if eb then
            local regions = { eb:GetRegions() }
            for _, region in ipairs(regions) do
                if region:IsObjectType("Texture") then region:SetAlpha(1) end
            end
            if eb.lunaSeparator then eb.lunaSeparator:Hide() end
        end
    end
    wipe(skinnedFrames)

    -- Reparent back
    ChatFrame1:SetParent(UIParent)
    ChatFrame1:SetClampedToScreen(true)
    local editBox = ChatFrame1EditBox
    if editBox then editBox:SetParent(UIParent) end
    if GeneralDockManager then GeneralDockManager:SetParent(UIParent) end

    -- Let Blizzard restore layout
    if FCF_RestorePositionAndDimensions then
        FCF_RestorePositionAndDimensions(ChatFrame1)
    end

    if containerFrame then containerFrame:Hide() end
    if resizeGrip then resizeGrip:Hide() end
    if copyButton then copyButton:Hide() end
    if socialButton then socialButton:Hide() end
    if channelsButton then channelsButton:Hide() end
    if languageButton then languageButton:Hide() end
    if copyFrame then
        copyFrame:Hide()
        isCopyBoxVisible = false
    end
    if urlCopyFrame then
        urlCopyFrame:Hide()
    end

    suppressSetPoint = false
end
