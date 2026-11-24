local _, ns = ...

local frame
local controls = {}      -- everything with a :Refresh()
-- Per side ("enemy" / "friendly"): totem list container and its All/None buttons
local totemLists, allButtons, noneButtons = {}, {}, {}

local function Changed()
    ns.RefreshAll()
    ns.UpdateOptions()
end

local function AddTooltip(widget, title, text)
    if not text then return end
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(text, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", GameTooltip_Hide)
end

local function CreateCheckbox(parent, label, tooltip, get, set, size)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    size = size or 26
    cb:SetSize(size, size)

    -- Hide the template's own label (name differs between clients) and use ours.
    local tmplText = cb.text or cb.Text
    if tmplText then tmplText:SetText("") end

    cb.label = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    cb.label:SetText(label)

    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        Changed()
    end)
    cb.Refresh = function(self) self:SetChecked(get() and true or false) end
    AddTooltip(cb, label, tooltip)

    table.insert(controls, cb)
    return cb
end

-- Slider bound to ns.db[key]. The current value is shown in the label.
local function CreateSlider(parent, title, key, minV, maxV, tooltip)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")

    local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetSize(190, 17)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(1)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:SetHitRectInsets(0, 0, -6, -6)
    s:SetBackdrop({
        bgFile   = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

    label:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 4)

    local low = s:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    low:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 2, -1)
    low:SetText(minV)
    local high = s:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    high:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", -2, -1)
    high:SetText(maxV)

    local function SetLabel(v)
        label:SetText(("%s: |cffffffff%d px|r"):format(title, v))
    end

    s:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v + 0.5)
        SetLabel(v)
        if ns.db[key] ~= v then
            ns.db[key] = v
            ns.RefreshAll()
        end
    end)
    s.Refresh = function(self)
        self:SetValue(ns.db[key])
        SetLabel(ns.db[key])
    end
    AddTooltip(s, title, tooltip)

    table.insert(controls, s)
    return s
end

local function CreateTotemList(parent, side)
    local list = CreateFrame("Frame", nil, parent)
    list:SetSize(440, 340)

    -- Groups are laid out in pairs, side by side:
    --   Fire  | Earth
    --   Water | Air
    local ROW = 20
    local colX = { 0, 225 }
    local colY = { 0, 0 }
    local rowTop = 0

    for i, group in ipairs(ns.TOTEM_GROUPS) do
        local col = ((i - 1) % 2) + 1
        if col == 1 and i > 1 then
            -- Start a new row below the taller group of the previous pair.
            rowTop = math.min(colY[1], colY[2])
        end
        if col == 1 or i == 1 then colY[1] = rowTop end
        if col == 2 then colY[2] = rowTop end
        local x = colX[col]

        local header = list:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        header:SetPoint("TOPLEFT", x, colY[col])
        header:SetText(group.element)
        header:SetTextColor(group.color[1], group.color[2], group.color[3])
        colY[col] = colY[col] - ROW

        for _, t in ipairs(group.totems) do
            local name, spellID = t[1], t[2]
            local cb = CreateCheckbox(list, name, nil,
                function() return ns.IsTotemSelected(side, name) end,
                function(v) ns.SetTotemSelected(side, name, v) end,
                22)
            cb:SetPoint("TOPLEFT", x, colY[col] + 2)

            local icon = cb:CreateTexture(nil, "ARTWORK")
            icon:SetSize(16, 16)
            icon:SetPoint("LEFT", cb, "RIGHT", 2, 0)
            icon:SetTexture(ns.GetSpellIcon(spellID))
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            cb.label:ClearAllPoints()
            cb.label:SetPoint("LEFT", icon, "RIGHT", 4, 0)
            cb.label:SetFontObject("GameFontHighlightSmall")

            -- Show the spell tooltip on hover.
            cb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(spellID)
                GameTooltip:Show()
            end)
            cb:SetScript("OnLeave", GameTooltip_Hide)

            colY[col] = colY[col] - ROW
        end
        colY[col] = colY[col] - 8 -- gap between elements
    end

    list:SetHeight(-math.min(colY[1], colY[2]))
    return list
end

local function CreateButton(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function SetAllTotems(side, selected)
    for _, group in ipairs(ns.TOTEM_GROUPS) do
        for _, t in ipairs(group.totems) do
            ns.SetTotemSelected(side, t[1], selected)
        end
    end
    Changed()
end

-- Checkbox bound to a game CVar (not saved by the addon).
-- Turning it on also turns on parentCvar, since minion plates need the main plates on.
-- CVar names are from the WoW Forever client (Blizzard_SettingsDefinitions_Frame/Nameplates.lua).
local GetCVarAPI = (C_CVar and C_CVar.GetCVar) or GetCVar
local SetCVarAPI = (C_CVar and C_CVar.SetCVar) or SetCVar

local function CreateCvarCheckbox(parent, label, tooltip, cvar, parentCvar)
    local cb = CreateCheckbox(parent, label, tooltip,
        function() return GetCVarAPI(cvar) == "1" end,
        function(v)
            if InCombatLockdown() then
                ns.Print("can't change nameplate settings in combat.")
                return
            end
            SetCVarAPI(cvar, v and "1" or "0")
            if v and parentCvar then SetCVarAPI(parentCvar, "1") end
        end)

    -- Grey it out if this client doesn't have the setting.
    local baseRefresh = cb.Refresh
    cb.Refresh = function(self)
        if GetCVarAPI(cvar) == nil then
            self:SetChecked(false)
            self:Disable()
            self.label:SetTextColor(0.5, 0.5, 0.5)
        else
            baseRefresh(self)
        end
    end
    return cb
end

local FRAME_WIDTH = 960
local HALF = FRAME_WIDTH / 2

local function BuildFrame()
    local f = CreateFrame("Frame", "SpotTheTotemSettings", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_WIDTH, 600)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:Hide()
    table.insert(UISpecialFrames, "SpotTheTotemSettings") -- Escape closes it

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText("Spot the Totem")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    -- Layout helpers
    local function Header(text, x, y, r, g, b)
        local h = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        h:SetPoint("TOPLEFT", x, y)
        h:SetText(text)
        if r then h:SetTextColor(r, g, b) end
        return h
    end
    local function Divider(y)
        local line = f:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(1, 1, 1, 0.15)
        line:SetSize(FRAME_WIDTH - 44, 1)
        line:SetPoint("TOPLEFT", 22, y)
        return line
    end

    -- General (full width) ------------------------------------------------
    Header("General", 24, -46)

    local enable = CreateCheckbox(f, "Enable Spot the Totem",
        "Turn totem icons on or off without disabling the addon.",
        function() return ns.db.enabled end,
        function(v) ns.db.enabled = v; ns.UpdateMinimap() end)
    enable:SetPoint("TOPLEFT", 20, -62)

    local minimap = CreateCheckbox(f, "Minimap button",
        "Show the minimap button. You can always open settings with /stt.",
        function() return ns.db.showMinimap end,
        function(v) ns.db.showMinimap = v; ns.UpdateMinimap() end)
    minimap:SetPoint("TOPLEFT", 250, -62)

    local hideBar = CreateCheckbox(f, "Hide totem health bar",
        "Hide the totem's health bar and name so only the icon shows.",
        function() return ns.db.hideBar end,
        function(v) ns.db.hideBar = v end)
    hideBar:SetPoint("TOPLEFT", HALF + 20, -62)

    local timer = CreateCheckbox(f, "Show countdown timer",
        "Show how long each totem has left. White normally, yellow under 10 seconds, red under 5. " ..
        "Exact for your own totems; other players' totems use the standard duration.",
        function() return ns.db.showTimer end,
        function(v) ns.db.showTimer = v end)
    timer:SetPoint("TOPLEFT", HALF + 250, -62)

    local offset = CreateSlider(f, "Vertical offset", "offsetY", -50, 100,
        "Move the icon up (positive) or down (negative) from its normal spot.")
    offset:SetPoint("TOPLEFT", 26, -118)

    Divider(-156)

    -- Enemy (left) | Friendly (right) ------------------------------------
    local SECTION_TOP = 166
    local LIST_TOP = 362

    local function Section(side, x)
        local isFriendly = side == "friendly"

        if isFriendly then
            Header("Friendly totems", x + 4, -SECTION_TOP, 0.35, 1, 0.45)
        else
            Header("Enemy totems", x + 4, -SECTION_TOP, 1, 0.35, 0.35)
        end

        local spot = CreateCheckbox(f, isFriendly and "Spot friendly totems" or "Spot enemy totems",
            isFriendly and "Show icons on your own and your allies' totems. Usually blocked inside dungeons."
                or "Show icons on enemy totems.",
            function()
                if isFriendly then return ns.db.showFriendly end
                return ns.db.showEnemy
            end,
            function(v) if isFriendly then ns.db.showFriendly = v else ns.db.showEnemy = v end end)
        spot:SetPoint("TOPLEFT", x, -(SECTION_TOP + 16))

        local plates
        if isFriendly then
            plates = CreateCvarCheckbox(f, "Friendly minion nameplates",
                "Turns on the game's Friendly Minions nameplates, which totem icons need. " ..
                "Also turns on friendly nameplates if they're off.",
                "nameplateShowFriendlyPlayerMinions", "nameplateShowFriendlyPlayers")
        else
            plates = CreateCvarCheckbox(f, "Enemy minion nameplates",
                "Turns on the game's Enemy Minions nameplates, which totem icons need. " ..
                "Also turns on enemy nameplates if they're off.",
                "nameplateShowEnemyMinions", "nameplateShowEnemies")
        end
        plates:SetPoint("TOPLEFT", x + 230, -(SECTION_TOP + 16))

        local size = CreateSlider(f, "Icon size", isFriendly and "friendlySize" or "enemySize", 16, 128,
            "How big " .. side .. " totem icons are, in pixels.")
        size:SetPoint("TOPLEFT", x + 6, -(SECTION_TOP + 72))

        local filter = CreateCheckbox(f, "Only spot selected totems",
            "When on, only the " .. side .. " totems checked below get an icon. " ..
            "When off, every " .. side .. " totem does.",
            function() return ns.IsFiltered(side) end,
            function(v)
                if isFriendly then ns.db.filterFriendly = v else ns.db.filterEnemy = v end
                -- Turning the filter off re-selects every totem on this side.
                if not v then wipe(ns.GetSelection(side)) end
            end)
        filter:SetPoint("TOPLEFT", x, -(LIST_TOP - 36))

        local none = CreateButton(f, "None", 60, function() SetAllTotems(side, false) end)
        none:SetPoint("TOPRIGHT", f, "TOPLEFT", x + HALF - 44, -(LIST_TOP - 34))
        local all = CreateButton(f, "All", 60, function() SetAllTotems(side, true) end)
        all:SetPoint("RIGHT", none, "LEFT", -6, 0)
        allButtons[side], noneButtons[side] = all, none

        local list = CreateTotemList(f, side)
        list:SetPoint("TOPLEFT", x + 6, -LIST_TOP)
        totemLists[side] = list
        return list
    end

    local enemyList = Section("enemy", 20)
    local friendlyList = Section("friendly", HALF + 20)

    local listBottom = LIST_TOP + math.max(enemyList:GetHeight(), friendlyList:GetHeight())

    -- Vertical separator between the two sides.
    local vline = f:CreateTexture(nil, "ARTWORK")
    vline:SetColorTexture(1, 1, 1, 0.15)
    vline:SetPoint("TOPLEFT", HALF, -(SECTION_TOP - 2))
    vline:SetSize(1, listBottom - SECTION_TOP + 2)

    -- Footer: separator and nameplate reminder.
    Divider(-(listBottom + 4))

    local note = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 26, -(listBottom + 14))
    note:SetWidth(FRAME_WIDTH - 52)
    note:SetJustifyH("LEFT")
    note:SetText("Minion nameplates must be turned on for totem icons to display. " ..
        "Use the |cffffd100minion nameplates|r checkboxes above, or the game's nameplate options.")

    -- Fit the window to the lists and footer.
    f:SetHeight(listBottom + 14 + note:GetStringHeight() + 22)

    return f
end

function ns.UpdateOptions()
    if not frame then return end
    for _, c in ipairs(controls) do c:Refresh() end
    for _, side in ipairs({ "enemy", "friendly" }) do
        local filtered = ns.IsFiltered(side) and true or false
        -- Dim a list when its filter is off, so it's clear it isn't in use.
        totemLists[side]:SetAlpha(filtered and 1 or 0.45)
        -- All / None only make sense while the filter is on.
        allButtons[side]:SetEnabled(filtered)
        noneButtons[side]:SetEnabled(filtered)
    end
end

function ns.ToggleOptions()
    if not ns.db then return end
    if not frame then frame = BuildFrame() end
    if frame:IsShown() then
        frame:Hide()
    else
        ns.UpdateOptions()
        frame:Show()
    end
end
