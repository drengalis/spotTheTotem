local _, ns = ...

local button
local ICON_TEXTURE = "Interface\\Icons\\Spell_Shaman_DropAll_01"

local function UpdatePosition()
    local angle = math.rad(ns.db.minimapAngle or 225)
    local radius = (Minimap:GetWidth() / 2) + 10
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    ns.db.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
    UpdatePosition()
end

function ns.InitMinimap()
    if button then return end

    button = CreateFrame("Button", "SpotTheTotemMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON_TEXTURE)
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    button:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then
            ns.db.enabled = not ns.db.enabled
            ns.Print("totem icons " .. (ns.db.enabled and "|cff00ff00on|r" or "|cffff4444off|r"))
            ns.RefreshAll()
            ns.UpdateOptions()
            ns.UpdateMinimap()
        else
            ns.ToggleOptions()
        end
    end)

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", OnDragUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Spot the Totem", 1, 1, 1)
        GameTooltip:AddLine("Status: " .. (ns.db.enabled and "|cff00ff00on|r" or "|cffff4444off|r"))
        GameTooltip:AddLine("Left-click: settings", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: turn on/off", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag: move button", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    UpdatePosition()
    ns.UpdateMinimap()
end

function ns.UpdateMinimap()
    if not button then return end
    button:SetShown(ns.db.showMinimap)
    -- Grey the icon out when the addon is turned off.
    button.icon:SetDesaturated(not ns.db.enabled)
end
