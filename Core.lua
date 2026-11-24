local ADDON, ns = ...

local DEFAULTS = {
    enabled      = true,
    enemySize    = 40,
    friendlySize = 40,
    offsetY      = 0,      -- vertical offset of the icon, in pixels
    showTimer    = true,   -- countdown timer on the icon
    hideBar      = true,
    showEnemy    = true,
    showFriendly = true,
    filterEnemy    = false, -- when true, only enemy totems checked in the list are shown
    filterFriendly = false, -- same for friendly totems
    showMinimap  = true,
    minimapAngle = 225,
}

ns.FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local ENEMY_COLOR    = { 0.9, 0.15, 0.15 }
local FRIENDLY_COLOR = { 0.2, 0.85, 0.3 }

-- Timer colours: white normally, yellow when low, red when about to expire.
local TIMER_YELLOW_AT = 10
local TIMER_RED_AT    = 5

local GetSpellTextureAPI = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
local iconCache = {}

function ns.GetSpellIcon(spellID)
    local icon = iconCache[spellID]
    if not icon then
        icon = GetSpellTextureAPI(spellID) or ns.FALLBACK_ICON
        iconCache[spellID] = icon
    end
    return icon
end

function ns.Print(msg)
    print("|cff33ccffSpot the Totem|r: " .. msg)
end

-- Per-totem selection, kept separately for "enemy" and "friendly".
-- Missing entry = selected.
function ns.GetSelection(side)
    return side == "friendly" and ns.db.totemsFriendly or ns.db.totemsEnemy
end

function ns.IsTotemSelected(side, name)
    return ns.GetSelection(side)[name] ~= false
end

function ns.SetTotemSelected(side, name, selected)
    ns.GetSelection(side)[name] = selected and true or false
end

function ns.IsFiltered(side)
    if side == "friendly" then return ns.db.filterFriendly end
    return ns.db.filterEnemy
end

-- plate -> overlay frame
local overlays = {}

---------------------------------------------------------------------------
-- Totem identification
---------------------------------------------------------------------------

local ROMAN = { I = 1, II = 2, III = 3, IV = 4, V = 5, VI = 6, VII = 7, VIII = 8, IX = 9, X = 10 }

-- "Searing Totem III" -> "Searing Totem", 3
local function ParseName(name)
    local base, numeral = name:match("^(.-)%s+([IVX]+)$")
    if base and ROMAN[numeral] then
        return base, ROMAN[numeral]
    end
    return name, 1
end

-- Returns icon, baseName, rank, isKnown  (nil if the unit isn't a totem)
local function GetTotemInfoForUnit(unit)
    local name = UnitName(unit)
    if not name then return nil end
    local base, rank = ParseName(name)
    local spellID = ns.TOTEM_SPELLS[base]

    if spellID then
        return ns.GetSpellIcon(spellID), base, rank, true
    end
    if UnitCreatureType(unit) == "Totem" then
        return ns.FALLBACK_ICON, base, rank, false
    end
    return nil
end

---------------------------------------------------------------------------
-- Countdown timer
---------------------------------------------------------------------------

-- First time we saw a totem, used when its spawn time can't be read.
local firstSeen = {}

-- Creature GUIDs carry the low 23 bits of the server time the unit spawned.
-- Returns how many seconds ago the totem was summoned, or nil.
local function GetSecondsSinceSpawn(guid)
    local unitType, _, _, _, _, _, spawnUID = strsplit("-", guid)
    if unitType ~= "Creature" or not spawnUID or #spawnUID < 6 then return nil end
    local low = tonumber(spawnUID:sub(5), 16)
    if not low then return nil end
    low = low % 0x800000

    local now = GetServerTime()
    local elapsed = (now - low) % 0x800000
    if elapsed > 900 then return nil end -- nonsense; no totem lasts that long
    return elapsed
end

local function GetDuration(base, rank, unitName)
    -- Your own totems: the game tells us the exact duration (includes talents).
    for slot = 1, 4 do
        local have, name, _, duration = GetTotemInfo(slot)
        if have and name == unitName and duration and duration > 0 then
            return duration
        end
    end
    if base == "Searing Totem" then
        return ns.SEARING_DURATION[rank] or ns.TOTEM_DURATION[base]
    end
    return ns.TOTEM_DURATION[base]
end

-- Returns the GetTime() value at which the totem expires, or nil.
local function GetExpiration(unit, base, rank)
    local duration = GetDuration(base, rank, UnitName(unit))
    if not duration then return nil end

    local guid = UnitGUID(unit)
    if not guid then return nil end

    local elapsed = GetSecondsSinceSpawn(guid)
    if elapsed then
        return GetTime() - elapsed + duration
    end

    if not firstSeen[guid] then firstSeen[guid] = GetTime() end
    return firstSeen[guid] + duration
end

local function FormatTime(remaining)
    if remaining >= 60 then
        return ("%d:%02d"):format(math.floor(remaining / 60), math.floor(remaining % 60))
    end
    return ("%d"):format(math.ceil(remaining))
end

local function TimerOnUpdate(f, elapsed)
    f.sinceUpdate = (f.sinceUpdate or 0) + elapsed
    if f.sinceUpdate < 0.1 then return end
    f.sinceUpdate = 0

    local remaining = f.expires - GetTime()
    if remaining <= 0 then
        f.timer:SetText("")
        return
    end
    f.timer:SetText(FormatTime(remaining))
    if remaining <= TIMER_RED_AT then
        f.timer:SetTextColor(1, 0.2, 0.2)
    elseif remaining <= TIMER_YELLOW_AT then
        f.timer:SetTextColor(1, 0.9, 0.2)
    else
        f.timer:SetTextColor(1, 1, 1)
    end
end

---------------------------------------------------------------------------
-- Nameplate overlays
---------------------------------------------------------------------------

local function GetOverlay(plate)
    local f = overlays[plate]
    if f then return f end

    f = CreateFrame("Frame", nil, plate)
    f:SetFrameLevel(plate:GetFrameLevel() + 20)

    f.border = f:CreateTexture(nil, "BACKGROUND")
    f.border:SetAllPoints()
    f.border:SetColorTexture(1, 1, 1, 1)

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("TOPLEFT", 2, -2)
    f.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the default icon edge

    f.timer = f:CreateFontString(nil, "OVERLAY")
    f.timer:SetPoint("CENTER", 0, 0)

    overlays[plate] = f
    return f
end

local function SetBarHidden(plate, hidden)
    local uf = plate.UnitFrame
    if uf then uf:SetAlpha(hidden and 0 or 1) end
end

local function ClearPlate(plate)
    local f = overlays[plate]
    if f then
        f:Hide()
        f:SetScript("OnUpdate", nil)
    end
    if plate.sttBarHidden then
        SetBarHidden(plate, false)
        plate.sttBarHidden = nil
    end
end

local function ShouldShow(unit, base, known)
    local db = ns.db
    if not db.enabled then return false end

    local friendly = UnitIsFriend("player", unit)
    if friendly and not db.showFriendly then return false end
    if not friendly and not db.showEnemy then return false end

    local side = friendly and "friendly" or "enemy"
    if ns.IsFiltered(side) then
        if not known then return false end
        if not ns.IsTotemSelected(side, base) then return false end
    end
    return true, friendly
end

local function UpdateUnit(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end -- forbidden plate (e.g. friendly in instances)

    local icon, base, rank, known = GetTotemInfoForUnit(unit)
    local show, friendly
    if icon then show, friendly = ShouldShow(unit, base, known) end
    if not show then
        ClearPlate(plate)
        return
    end

    local db = ns.db
    local f = GetOverlay(plate)
    local size = friendly and db.friendlySize or db.enemySize
    f:SetSize(size, size)
    f:ClearAllPoints()
    if db.hideBar then
        f:SetPoint("CENTER", plate, "CENTER", 0, db.offsetY)
    else
        f:SetPoint("BOTTOM", plate, "TOP", 0, 2 + db.offsetY)
    end
    f.icon:SetTexture(icon)
    local c = friendly and FRIENDLY_COLOR or ENEMY_COLOR
    f.border:SetColorTexture(c[1], c[2], c[3], 1)

    -- Timer
    f.expires = db.showTimer and known and GetExpiration(unit, base, rank) or nil
    if f.expires then
        f.timer:SetFont(STANDARD_TEXT_FONT, math.max(10, math.floor(size * 0.42)), "OUTLINE")
        f.timer:Show()
        f.sinceUpdate = 1 -- update right away
        f:SetScript("OnUpdate", TimerOnUpdate)
    else
        f.timer:Hide()
        f:SetScript("OnUpdate", nil)
    end

    f:Show()

    SetBarHidden(plate, db.hideBar)
    plate.sttBarHidden = db.hideBar or nil
end

function ns.RefreshAll()
    if not ns.db then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit then
            UpdateUnit(unit)
        else
            ClearPlate(plate)
        end
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")

events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        SpotTheTotemDB = SpotTheTotemDB or {}
        local db = SpotTheTotemDB
        -- Older versions had one shared icon size.
        if db.iconSize then
            db.enemySize = db.enemySize or db.iconSize
            db.friendlySize = db.friendlySize or db.iconSize
            db.iconSize = nil
        end
        -- Older versions had one shared totem filter.
        if db.filterTotems ~= nil then
            db.filterEnemy, db.filterFriendly = db.filterTotems, db.filterTotems
            db.filterTotems = nil
        end
        if db.totems then
            db.totemsEnemy, db.totemsFriendly = {}, {}
            for k, v in pairs(db.totems) do
                db.totemsEnemy[k], db.totemsFriendly[k] = v, v
            end
            db.totems = nil
        end
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then db[k] = v end
        end
        db.totemsEnemy = db.totemsEnemy or {}
        db.totemsFriendly = db.totemsFriendly or {}
        ns.db = db
        ns.PruneTotems()
        events:UnregisterEvent("ADDON_LOADED")
        if ns.InitMinimap then ns.InitMinimap() end
    elseif not ns.db then
        return
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        UpdateUnit(arg1)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local plate = C_NamePlate.GetNamePlateForUnit(arg1)
        if plate then ClearPlate(plate) end
    elseif event == "PLAYER_ENTERING_WORLD" then
        wipe(firstSeen)
        ns.RefreshAll()
    end
end)

---------------------------------------------------------------------------
-- Duration check: compares our table with the game's own spell tooltips
---------------------------------------------------------------------------

local GetSpellDescriptionAPI = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription

-- Last "<number> sec/min" in the tooltip is the duration ("... Lasts 5 min.").
local function DurationFromDescription(desc)
    local found
    for num, unit in (desc or ""):gmatch("(%d+)%s+(%a+)") do
        unit = unit:lower()
        if unit:find("^min") then
            found = tonumber(num) * 60
        elseif unit:find("^sec") then
            found = tonumber(num)
        end
    end
    return found
end

function ns.CheckDurations()
    local missing = 0
    for _, group in ipairs(ns.TOTEM_GROUPS) do
        for _, t in ipairs(group.totems) do
            local name, spellID, ours = t[1], t[2], t[3]
            if C_Spell and C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(spellID) end
            local game = DurationFromDescription(GetSpellDescriptionAPI(spellID))
            local line
            if not game then
                missing = missing + 1
                line = ("|cffaaaaaa%s: table %ds, game ?|r"):format(name, ours)
            elseif game == ours then
                line = ("|cff00ff00%s: %ds (matches)|r"):format(name, ours)
            else
                line = ("|cffff4444%s: table %ds, game %ds|r"):format(name, ours, game)
            end
            print(line)
        end
    end
    if missing > 0 then
        ns.Print(missing .. " tooltip(s) not loaded yet. Run /stt durations again in a few seconds.")
    end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function OnOff(v) return v and "|cff00ff00on|r" or "|cffff4444off|r" end

SLASH_SPOTTHETOTEM1 = "/stt"
SLASH_SPOTTHETOTEM2 = "/spotthetotem"
SlashCmdList.SPOTTHETOTEM = function(msg)
    local db = ns.db
    if not db then return end
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")

    if cmd == "" or cmd == "config" or cmd == "options" then
        ns.ToggleOptions()
        return
    elseif cmd == "toggle" then
        db.enabled = not db.enabled
        ns.Print("addon " .. OnOff(db.enabled))
        if ns.UpdateMinimap then ns.UpdateMinimap() end
    elseif cmd == "friendly" then
        db.showFriendly = not db.showFriendly
        ns.Print("friendly totems " .. OnOff(db.showFriendly))
    elseif cmd == "enemy" then
        db.showEnemy = not db.showEnemy
        ns.Print("enemy totems " .. OnOff(db.showEnemy))
    elseif cmd == "timer" then
        db.showTimer = not db.showTimer
        ns.Print("countdown timer " .. OnOff(db.showTimer))
    elseif cmd == "size" then
        -- /stt size <n> | /stt size enemy <n> | /stt size friendly <n>
        local which, num = arg:match("^(%a*)%s*(%-?%d*)$")
        local n = tonumber(num)
        if not n or n < 16 or n > 128 or (which ~= "" and which ~= "enemy" and which ~= "friendly") then
            ns.Print("usage: /stt size [enemy|friendly] <16-128>")
            return
        end
        n = math.floor(n)
        if which ~= "friendly" then db.enemySize = n end
        if which ~= "enemy" then db.friendlySize = n end
        ns.Print(("icon size: enemy %d, friendly %d"):format(db.enemySize, db.friendlySize))
    elseif cmd == "offset" then
        local n = tonumber(arg)
        if n and n >= -50 and n <= 100 then
            db.offsetY = math.floor(n)
            ns.Print("vertical offset " .. db.offsetY)
        else
            ns.Print("usage: /stt offset <-50 to 100>")
            return
        end
    elseif cmd == "durations" then
        ns.CheckDurations()
        return
    elseif cmd == "minimap" then
        db.showMinimap = not db.showMinimap
        ns.Print("minimap button " .. OnOff(db.showMinimap))
        if ns.UpdateMinimap then ns.UpdateMinimap() end
    elseif cmd == "reset" then
        for k, v in pairs(DEFAULTS) do db[k] = v end
        db.totemsEnemy, db.totemsFriendly = {}, {}
        ns.Print("settings reset")
        if ns.UpdateMinimap then ns.UpdateMinimap() end
    else
        ns.Print("/stt  - open settings")
        ns.Print("/stt toggle | friendly | enemy | timer | size [enemy|friendly] <16-128> | offset <-50 to 100> | durations | minimap | reset")
        return
    end
    ns.RefreshAll()
    if ns.UpdateOptions then ns.UpdateOptions() end
end
