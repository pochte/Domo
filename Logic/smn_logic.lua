-- SMN LOGIC (loaded on SMN only, see Load_Profile_Logic in Lazy.lua)
-- Everything SMN-specific lives here: avatar rotation, wards, rage pacts,
-- Avatar's Favor, Elemental Siphon. Gear is GearSwap's job, not ours.
--
-- Called once per Buff_Tick via SMN_Tick(); returns true if it did something
-- (so Buff_Tick stops for this tick). Emergency cure is NOT here: it runs from
-- Cure_Bot_Tick using emergency_cure in Profiles/SMN.lua, same as RDM.

local HOME_AVATAR = 'Ifrit'      -- Favor (DA) lives here; we only summon when a ward is due

-- Wards, in priority order. refresh_at = seconds after cast before we redo it.
-- Timers, not buff icons: Haste (RDM/GEO) and Warcry (WAR) share icons with these.
local WARDS = {
    { name = 'Hastega II',        avatar = 'Garuda', refresh_at = 165 },
    { name = 'Crystal Blessing',  avatar = 'Shiva',  refresh_at = 165 },  -- TP bonus
    { name = 'Crimson Howl',      avatar = 'Ifrit',  refresh_at = 50  },  -- Warcry (60s)
}
local WARD_SWAP_MAX_RECAST = 8   -- don't swap avatars for a ward that's still cooling down

-- Rage pacts per avatar, highest level first. First one we know + can afford wins.
-- (Two-hour pacts like Inferno / Earthen Fury are deliberately left out.)
local RAGE = {
    Ifrit      = { 'Conflag Strike', 'Meteor Strike', 'Flaming Crush', 'Fire IV', 'Double Punch', 'Burning Strike', 'Fire II', 'Punch' },
    Garuda     = { 'Wind Blade', 'Predator Claws', 'Aero IV', 'Aero II', 'Claw' },
    Shiva      = { 'Heavenly Strike', 'Rush', 'Blizzard IV', 'Double Slap', 'Blizzard II', 'Axe Kick' },
    Titan      = { 'Crag Throw', 'Geocrush', 'Mountain Buster', 'Stone IV', 'Megalith Throw', 'Rock Buster', 'Stone II', 'Rock Throw' },
    Ramuh      = { 'Volt Strike', 'Thunderstorm', 'Chaotic Strike', 'Thunder IV', 'Thunderspark', 'Thunder II', 'Shock Strike' },
    Leviathan  = { 'Grand Fall', 'Spinning Dive', 'Water IV', 'Tail Whip', 'Water II', 'Barracuda Dive' },
    Fenrir     = { 'Lunar Bay', 'Impact', 'Eclipse Bite', 'Crescent Fang', 'Moonlit Charge' },
    Diabolos   = { 'Blindside', 'Night Terror', 'Nether Blast', 'Camisado' },
    ['Cait Sith'] = { 'Regal Gash', 'Level ? Holy', 'Regal Scratch' },
    Carbuncle  = { 'Holy Mist', 'Meteorite', 'Poison Nails' },
    Siren      = { 'Hysteric Assault', 'Tornado II', 'Sonic Buffet', 'Roundhouse', 'Welt' },
}

-- Elemental Siphon only works on an ELEMENTAL SPIRIT (not an avatar), so the
-- siphon routine swaps to the spirit that matches the day, siphons, then the
-- normal logic resummons the home avatar.
local SIPHON_MP_PERCENT = 70
local SIPHON_TIMEOUT    = 30
local DAY_SPIRIT = {
    [0] = 'Fire Spirit',    [1] = 'Earth Spirit',  [2] = 'Water Spirit',  [3] = 'Air Spirit',
    [4] = 'Ice Spirit',     [5] = 'Thunder Spirit', [6] = 'Light Spirit',  [7] = 'Dark Spirit',
}

local ward_last      = {}
local favor_last     = 0
local siphon_retry_at = 0
local siphon_started = nil     -- os.clock() when a siphon routine began
local spirit_seen_at = nil

-- HELPERS
local function Pet()
    local pet = windower.ffxi.get_mob_by_target('pet')
    if pet and pet.name and (pet.hpp or 0) > 0 then return pet end
    return nil
end

local function Is_Spirit(pet)
    return pet and string.find(pet.name, ' Spirit', 1, true) ~= nil
end

-- Blood pacts are /pet commands; Cast_Ability sends /ja, so we send our own.
local function Pet_Command(name, target)
    windower.send_command('input /pet "' .. name .. '" ' .. target)
    isBusy = Action_Delay
    return true
end

local function Ward_Recast() -- shared Blood Pact: Ward timer
    return windower.ffxi.get_ability_recasts()[174] or 0
end

local function Pact_Usable(name, mp)
    local ab = res.job_abilities:with('name', name)
    if not ab then return false, nil end
    if mp < ab.mp_cost then return false, ab end
    -- Only trust the learned-abilities list if it actually lists blood pacts.
    local abilities = windower.ffxi.get_abilities()
    local list = abilities and abilities.job_abilities
    if list then
        local has_any_bp, has_this = false, false
        for _, id in ipairs(list) do
            if id >= 512 and id <= 970 then has_any_bp = true end
            if id == ab.id then has_this = true end
        end
        if has_any_bp and not has_this then return false, ab end
    end
    return true, ab
end

local function Valid_Target()
    local t = windower.ffxi.get_mob_by_target('t')
    if t and t.is_npc and t.hpp and t.hpp > 0 and t.valid_target
        and not Is_Party_Member(t.id) and not Is_Blacklisted(t.name)
        and t.distance and math.sqrt(t.distance) <= 20 then
        return t
    end
    return nil
end

-- ELEMENTAL SIPHON
local function Siphon_Wanted(player)
    if not Can_Cast_Ability('Elemental Siphon') then return false end
    return os.clock() >= siphon_retry_at and player.vitals.mpp < SIPHON_MP_PERCENT
end

local function Run_Siphon(player)
    local now = os.clock()
    if siphon_started and now - siphon_started > SIPHON_TIMEOUT then
        windower.add_to_chat(207, '[Lazy][SMN] Elemental Siphon timed out, carrying on.')
        siphon_started, spirit_seen_at = nil, nil
        siphon_retry_at = now + 60   -- don't instantly retry
        return false
    end
    local pet = Pet()
    if Is_Spirit(pet) then
        spirit_seen_at = spirit_seen_at or now
        if now - spirit_seen_at >= 3 and Can_Cast_Ability('Elemental Siphon') then
            windower.add_to_chat(207, '[Lazy][SMN] Elemental Siphon (' .. string.format('%d', player.vitals.mpp) .. '% MP).')
            windower.send_command('input /ja "Elemental Siphon" <me>')
            isBusy = Action_Delay
            siphon_started, spirit_seen_at = nil, nil
            return true
        end
        return true -- spirit is out, wait for the 3s settle / action delay
    end
    spirit_seen_at = nil
    local info = windower.ffxi.get_info()
    local spirit = DAY_SPIRIT[info and info.day or 0] or 'Light Spirit'
    if Cast_Spell_On(spirit, '<me>') then return true end
    return false
end

-- RESTING (SMN owns its own rest while idle; RestLogic.lua defers to us)
local function Rest_Blocked(now)
    -- Same "something needs us" conditions RestLogic uses to stand you up.
    if last_damage_taken_time and now - last_damage_taken_time <= 10 then return true end
    local party = windower.ffxi.get_party()
    if party then
        for _, key in ipairs({'p1','p2','p3','p4','p5'}) do
            local m = party[key]
            if m and m.hp and m.hp > 0 and m.hpp and m.hpp < 60
                and Party_Member_In_Range(m, 30) then
                return true
            end
        end
    end
    return false
end

local function Stand_Up()
    windower.send_command('input /heal off')
    is_resting = false
    isBusy = Action_Delay
    return true
end

-- First ward that is due and affordable (nil if none).
local function Next_Due_Ward(now, mp)
    for _, w in ipairs(WARDS) do
        local last = ward_last[w.name]
        if not last or now - last >= w.refresh_at then
            local ab = res.job_abilities:with('name', w.name)
            if ab and mp >= ab.mp_cost then return w end
        end
    end
    return nil
end

-- MAIN TICK
function SMN_Tick()
    local player = windower.ffxi.get_player()
    if not player or not player.vitals or player.vitals.hp <= 0 then return false end
    if isBusy > 0 or isCasting then return false end
    local now = os.clock()
    local mp  = player.vitals.mp
    local pet = Pet()

    -- Does anything need us to act right now? If so, stand up first.
    local due = Next_Due_Ward(now, mp)
    local ward_actionable = due and ((pet and pet.name == due.avatar) or Ward_Recast() <= WARD_SWAP_MAX_RECAST)
    local wants_siphon = siphon_started or Siphon_Wanted(player)
    if is_resting and (ward_actionable or wants_siphon) then
        return Stand_Up()
    end
    if is_resting then return false end   -- still recovering, stay seated

    -- 1. ELEMENTAL SIPHON (under 70% MP, only when the JA is actually ready)
    if wants_siphon then
        siphon_started = siphon_started or now
        if Run_Siphon(player) then return true end
    end

    -- 2. WARDS: first due one wins; swap avatar only if its ward is about ready
    if ward_actionable then
        if pet and pet.name == due.avatar then
            if Ward_Recast() == 0 then
                ward_last[due.name] = now
                return Pet_Command(due.name, '<me>')
            end
        elseif Cast_Spell_On(due.avatar, '<me>') then
            return true
        end
    end

    -- 3. NO AVATAR (or a spirit left over from Siphon) and nothing due:
    --    do NOT resummon. Release the spirit, then sit and recover MP until
    --    the buff cycle needs to start again.
    if not pet or Is_Spirit(pet) then
        if Is_Spirit(pet) and Can_Cast_Ability('Release') then
            return Pet_Command('Release', '<me>')
        end
        if not Is_Spirit(pet)
            and player.status == 0
            and player.vitals.mpp < 100
            and not Rest_Blocked(now)
            and settings.rest_active
        then
            windower.send_command('input /heal on')
            is_resting = true
            isBusy = Action_Delay
            return true
        end
        return false
    end
    if not RAGE[pet.name] then return false end

    -- 4. AVATAR'S FAVOR (Ifrit's Favor = Double Attack). Buff check + 60s guard.
    if pet.name == HOME_AVATAR
        and not Has_Buff_Named(HOME_AVATAR .. "'s Favor")
        and now - favor_last > 60
        and Can_Cast_Ability("Avatar's Favor")
    then
        favor_last = now
        return Pet_Command("Avatar's Favor", '<me>')
    end

    -- 5. COMBAT: Assault + highest-level rage pact the avatar can use
    local target = Valid_Target()
    if target then
        if pet.status ~= 1 and Can_Cast_Ability('Assault') then
            return Pet_Command('Assault', '<t>')
        end
        local list = RAGE[pet.name]
        if (windower.ffxi.get_ability_recasts()[173] or 0) == 0 then
            for _, name in ipairs(list) do
                if Pact_Usable(name, mp) then return Pet_Command(name, '<t>') end
            end
        end
    end
    return false
end
