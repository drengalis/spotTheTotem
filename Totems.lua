local _, ns = ...

-- WoW Forever totems grouped by element, in display order.
-- Not in Forever: Fire Nova Totem (now the Fire Nova spell), Tranquil Air Totem,
-- and all Burning Crusade totems.
-- { unit name without rank, rank 1 spell ID (all ranks share the icon), duration in seconds }
-- Durations are WoW Forever values (most buff totems last 5 min in Forever).
-- Searing Totem varies by rank (see below). Check against the game with /stt durations.
ns.TOTEM_GROUPS = {
    {
        element = "Fire", color = { 1.0, 0.45, 0.1 },
        totems = {
            { "Searing Totem",           3599, 30 },
            { "Magma Totem",             8190, 20 },
            { "Flametongue Totem",       8227, 300 },
            { "Frost Resistance Totem",  8181, 300 },
        },
    },
    {
        element = "Earth", color = { 0.75, 0.55, 0.25 },
        totems = {
            { "Stoneclaw Totem",         5730, 15 },
            { "Stoneskin Totem",         8071, 300 },
            { "Earthbind Totem",         2484, 45 },
            { "Strength of Earth Totem", 8075, 300 },
            { "Tremor Totem",            8143, 300 },
        },
    },
    {
        element = "Water", color = { 0.3, 0.6, 1.0 },
        totems = {
            { "Healing Stream Totem",    5394, 300 },
            { "Mana Spring Totem",       5675, 300 },
            { "Mana Tide Totem",         16190, 12 },
            { "Poison Cleansing Totem",  8166, 300 },
            { "Disease Cleansing Totem", 8170, 300 },
            { "Fire Resistance Totem",   8184, 300 },
        },
    },
    {
        element = "Air", color = { 0.7, 0.85, 1.0 },
        totems = {
            { "Grounding Totem",         8177, 45 },
            { "Windfury Totem",          8512, 300 },
            { "Grace of Air Totem",      8835, 300 },
            { "Nature Resistance Totem", 10595, 300 },
            { "Windwall Totem",          15107, 300 },
            { "Sentry Totem",            6495, 300 },
        },
    },
}

-- Searing Totem duration by rank (I..VI).
ns.SEARING_DURATION = { 30, 35, 40, 45, 50, 55 }

-- name -> duration, filled in PruneTotems
ns.TOTEM_DURATION = {}

-- Does this client know the spell? (Drops totems WoW Forever doesn't have.)
local function SpellExists(spellID)
    if C_Spell and C_Spell.DoesSpellExist then
        return C_Spell.DoesSpellExist(spellID)
    end
    if C_Spell and C_Spell.GetSpellInfo then
        return C_Spell.GetSpellInfo(spellID) ~= nil
    end
    return GetSpellInfo(spellID) ~= nil
end

-- Flat lookup: name -> spell ID. Built once at load, after removing
-- totems the client doesn't have, so the settings list only shows real ones.
ns.TOTEM_SPELLS = {}

function ns.PruneTotems()
    wipe(ns.TOTEM_SPELLS)
    wipe(ns.TOTEM_DURATION)
    for gi = #ns.TOTEM_GROUPS, 1, -1 do
        local group = ns.TOTEM_GROUPS[gi]
        for ti = #group.totems, 1, -1 do
            local t = group.totems[ti]
            if SpellExists(t[2]) then
                ns.TOTEM_SPELLS[t[1]] = t[2]
                ns.TOTEM_DURATION[t[1]] = t[3]
            else
                table.remove(group.totems, ti)
            end
        end
        if #group.totems == 0 then
            table.remove(ns.TOTEM_GROUPS, gi)
        end
    end
end
