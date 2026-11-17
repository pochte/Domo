-- JOBLOGIC
local last_tick_error = {}
function Safe_Tick(name, fn)
    local ok, err = pcall(fn)
    if not ok and last_tick_error[name] ~= err then
        last_tick_error[name] = err
        windower.add_to_chat(167, '[Lazy] ' .. name .. ' error: ' .. tostring(err))
    end
end
-- PROFILE HELPERS
-- WEAPONSKILL MODE (//lazy chainmode, //lazy openmode, //lazy partychain)
--   chain: fire the ordered ws_sc_chain (up to 5 steps) when one exists.
--   open:  opener + closers only: ws_sc_starter / ws_sc_closers, where the
--          closer is whichever one continues the open skillchain.
--   party: opener, then continue whatever skillchain is open with the best
--          weaponskill you can use right now, whoever started it.
ws_mode = ws_mode or 'chain'
-- Ordered skillchain, up to 5 weaponskills: ws_sc_chain = { 'WS1', 'WS2',
-- 'WS3', 'WS4', 'WS5' }. An entry is a name, or { name, min_tp } (default
-- 1000). Entry 1 opens the chain.
MAX_WS_CHAIN = 5
local function Raw_WS_Chain()
    local raw = (active_profile and active_profile.ws_sc_chain) or ws_sc_chain
    if type(raw) ~= 'table' or #raw == 0 then
        return nil
    end
    local chain = {}
    for i = 1, math.min(#raw, MAX_WS_CHAIN) do
        local entry = raw[i]
        local name, tp
        if type(entry) == 'table' then
            name, tp = entry[1], entry[2]
        else
            name = entry
        end
        if name then
            chain[#chain + 1] = { name, tp or 1000 }
        end
    end
    return #chain > 0 and chain or nil
end
-- { {name, min_tp}, ... } while in chain mode and a chain exists, else nil.
function Get_WS_Chain()
    if ws_mode ~= 'chain' then
        return nil
    end
    return Raw_WS_Chain()
end
-- { [weaponskill name] = position } from partychain_prefer, a list of names
-- in the order to favour when two weaponskills would make the same level of
-- skillchain. Profile first, then settings.lua.
function Get_Party_Prefer()
    local list = (active_profile and active_profile.partychain_prefer) or partychain_prefer
    if type(list) ~= 'table' then
        return nil
    end
    local map = {}
    for i, name in ipairs(list) do
        map[name] = i
    end
    return map
end
-- A profile that only defines a chain (no ws_sc_starter / ws_sc_closers of
-- its own) still has to do something in open mode: use the chain's first
-- two entries as the opener and closer.
local function Open_Pair_From_Chain()
    local p = active_profile
    if p and p.ws_sc_chain and not p.ws_sc_starter and not p.ws_sc_closers then
        return Raw_WS_Chain()
    end
    return nil
end
-- { name, min_tp } for the opening weaponskill.
function Get_WS_Starter()
    local chain = Get_WS_Chain() or Open_Pair_From_Chain()
    if chain then
        return chain[1]
    end
    local starter = active_profile and active_profile.ws_sc_starter or ws_sc_starter
    if starter and starter[1] and starter[2] == nil then
        return { starter[1], 1000 }
    end
    return starter
end
function Get_WS_Closers()
    local pair = Open_Pair_From_Chain()
    if pair then
        return { (pair[2] or pair[1])[1] }
    end
    return active_profile and active_profile.ws_sc_closers or ws_sc_closers
end
local function WS_Names(list)
    local names = {}
    for _, e in ipairs(list or {}) do
        names[#names + 1] = type(e) == 'table' and e[1] or tostring(e)
    end
    return table.concat(names, ' > ')
end
function Set_WS_Mode(mode)
    if mode == 'chain' then
        local chain = Raw_WS_Chain()
        if not chain then
            windower.add_to_chat(
                167,
                '[Lazy] No ws_sc_chain for this profile, staying in open mode. ' ..
                'Add one to the profile (or settings.lua) first.'
            )
            return
        end
        ws_mode = 'chain'
        windower.add_to_chat(
            2,
            '[Lazy] WS mode: CHAIN, ' .. #chain .. ' steps: ' .. WS_Names(chain)
        )
        return
    end
    if mode == 'party' then
        ws_mode = 'party'
        local starter = Get_WS_Starter()
        windower.add_to_chat(
            2,
            '[Lazy] WS mode: PARTYCHAIN. Opens with ' ..
            tostring(starter and starter[1]) ..
            ', then continues any open skillchain with the best weaponskill ' ..
            'you have: highest skillchain level first.'
        )
        return
    end
    ws_mode = 'open'
    local starter = Get_WS_Starter()
    windower.add_to_chat(
        2,
        '[Lazy] WS mode: OPEN, opener: ' .. tostring(starter and starter[1]) ..
        ', closers: ' .. WS_Names(Get_WS_Closers())
    )
end
function Get_WS_Mode_Text()
    local chain = Get_WS_Chain()
    if chain then
        return 'chain (' .. #chain .. ' steps: ' .. WS_Names(chain) .. ')'
    end
    local starter = Get_WS_Starter()
    if ws_mode == 'party' then
        return 'partychain (opener ' .. tostring(starter and starter[1]) ..
            ', then the best weaponskill that continues the chain)'
    end
    return 'open (opener ' .. tostring(starter and starter[1]) ..
        ', closers ' .. WS_Names(Get_WS_Closers()) .. ')' ..
        ((ws_mode == 'chain') and ' [no chain defined]' or '')
end
function Get_Needed_Buffs()
    return active_profile and active_profile.needed_buffs or needed_buffs
end
-- PARTY HELPER
function Party_Member_In_Range(m, range)
    if not m or not m.mob or not m.mob.distance then return false end
    if m.zone ~= windower.ffxi.get_info().zone then return false end
    return math.sqrt(m.mob.distance) <= (range or 20)
end
-- WEAPONSKILLS
-- SPELL / ABILITY HELPERS
function Is_Blacklisted(name)
    if not name then return false end
    for _, blocked in ipairs(spell_blacklist or {}) do
        if string.lower(name) == string.lower(blocked) then
            return true
        end
    end
    return false
end
function Is_Haste_Blacklisted(name)
    if not name then return false end
    for _, blocked in ipairs(haste_blacklist or {}) do
        if string.lower(name) == string.lower(blocked) then
            return true
        end
    end
    return false
end
function Is_Dispel_Whitelisted(name)
    if not name then return false end
    local lname = string.lower(name)
    for _, entry in ipairs(dispel_whitelist or {}) do
        if string.find(lname, string.lower(entry), 1, true) then
            return true
        end
    end
    return false
end
-- Not learned spells logic
local function Spell_Known(spell)
    if spell.type == 'Trust' then return true end
    local known = windower.ffxi.get_spells()
    return known and known[spell.id] and true or false
end
function Can_Cast_Spell(spell_name)
    if not spell_name or spell_name == '' then return false end
    local spell = res.spells:with('name', spell_name)
    if not spell then return false end
    if not Spell_Known(spell) then return false end
    local player = windower.ffxi.get_player()
    if not player then return false end
    local recasts = windower.ffxi.get_spell_recasts()
    return recasts[spell.id] == 0
        and not isCasting
        and isBusy == 0
        and player.vitals.mp >= spell.mp_cost
        and not Is_Moving()
end
function Can_Cast_Ability(ability_name)
    local ability = res.job_abilities:with('name', ability_name)
    if not ability then return false end
    local recasts = windower.ffxi.get_ability_recasts()
    return recasts[ability.recast_id] == 0
        and not isCasting
        and isBusy == 0
end
function Cast_Spell(spell_name)
    local spell = res.spells:with('name', spell_name)
    if not spell then return false end
    if not Spell_Known(spell) then return false end
    local recasts = windower.ffxi.get_spell_recasts()
    if recasts[spell.id] ~= 0 or isCasting or isBusy > 0 then
        return false
    end
    windower.send_command(
        'input /ma "' .. spell_name .. '" <t>'
    )
    isBusy = Action_Delay
    return true
end
function Cast_Spell_On(spell_name, target)
    local spell = res.spells:with('name', spell_name)
    if not spell then return false end
    if not Spell_Known(spell) then return false end
    if Is_Moving() then return false end
    local player = windower.ffxi.get_player()
    if not player then return false end
    local recasts = windower.ffxi.get_spell_recasts()
    if recasts[spell.id] ~= 0
        or isCasting
        or isBusy > 0
        or player.vitals.mp < spell.mp_cost
    then
        return false
    end
    windower.send_command(
        'input /ma "' .. spell_name .. '" ' .. target
    )
    isBusy = Action_Delay
    return true
end
-- Job ability on its natural target. Self-capable abilities go on <me>;
-- enemy-only ones (Provoke, Steal, Box Step...) go on <t>. Sending an
-- enemy-only JA at <me> gets "You cannot attack that target."
-- targets bitmask: 1 self, 2 player, 4 party, 8 ally, 16 npc, 32 enemy.
-- Finishing Move stacks (DNC main or /DNC). The buffs are 'Finishing Move 1'
-- .. 'Finishing Move 5' and 'Finishing Move (6+)'; there is no plain
-- 'Finishing Move' buff.
function Finishing_Move_Count()
    if not buffactive then return 0 end
    if buffactive['Finishing Move (6+)'] then return 6 end
    for n = 5, 1, -1 do
        if buffactive['Finishing Move ' .. n] then return n end
    end
    return 0
end
-- Gates for self abilities (Lazy.lua / HealBuffLogic.lua self-ability loops).
-- Sambas cost TP and need you engaged, and a rejected JA never starts its recast,
-- so without these checks Lazy sent Haste Samba out of combat, got rejected, and
-- then waited the whole interval. Optional per-entry fields override the defaults:
--   require_engaged, min_tp, skip_if_buff
local self_ability_note_last = {}
local function Self_Ability_Note(name, text)
    local now = os.clock()
    if now - (self_ability_note_last[name] or -99) >= 10 then
        self_ability_note_last[name] = now
        windower.add_to_chat(207, '[Lazy] ' .. name .. ': ' .. text)
    end
end
function Self_Ability_Gates_Ok(ab, player)
    local def = res.job_abilities:with('name', ab.name)
    local is_samba = def and def.type == 'Samba'
    local tp = (player.vitals and player.vitals.tp) or 0
    local need_tp = ab.min_tp or (is_samba and def.tp_cost) or 0
    -- Out of combat: stay quiet (sambas need you engaged anyway).
    if (ab.require_engaged or is_samba) and player.status ~= 1 then return false end
    local skip = ab.skip_if_buff or (is_samba and ab.name)
    if skip and buffactive and buffactive[skip] then return false end
    if need_tp > 0 and tp < need_tp then
        Self_Ability_Note(ab.name, 'waiting for TP (' .. tp .. '/' .. need_tp .. ')')
        return false
    end
    Self_Ability_Note(ab.name, 'sending (TP ' .. tp .. ')')
    return true
end
-- Samba from a sub job (e.g. THF/DNC Haste Samba). Called by Combat() BEFORE a
-- weaponskill chain is opened, so the samba goes up first; the chain just waits
-- for TP to build back up. Never interrupts a chain that is already running.
function Try_Haste_Samba(target)
    if not haste_samba_active or not subjob_abilities then return false end
    if isBusy > 0 or isCasting then return false end
    local player = windower.ffxi.get_player()
    if not player then return false end
    if target and sc_active and sc_active(target.id) then return false end
    local list = subjob_abilities[player.sub_job]
    if not list then return false end
    for _, ab in ipairs(list) do
        local def = res.job_abilities:with('name', ab.name)
        if def and def.type == 'Samba'
            and Can_Cast_Ability(ab.name)
            and Self_Ability_Gates_Ok(ab, player)
        then
            Cast_Ability(ab.name)
            return true
        end
    end
    return false
end
function Cast_Ability(ability_name)
    if not Can_Cast_Ability(ability_name) then return false end
    local ability = res.job_abilities:with('name', ability_name)
    local tgt = '<me>'
    local t = ability and ability.targets
    if type(t) == 'table' then
        -- Windower's resources library turns the bitmask into a set such as
        -- S{'Self'} or S{'Enemy'}. (Doing arithmetic on it is what threw
        -- "attempt to perform arithmetic on local 'mask'" and killed every
        -- Cast_Ability call, including Haste Samba and the THF buffs.)
        local function has(name)
            if t[name] then return true end
            for _, v in pairs(t) do
                if v == name then return true end
            end
            return false
        end
        if has('Enemy') and not has('Self') then
            tgt = '<t>'
        end
    elseif type(t) == 'number' then
        if t % 2 < 1 and t >= 32 then
            tgt = '<t>'
        end
    end
    windower.send_command(
        'input /ja "' .. ability_name .. '" ' .. tgt
    )
    isBusy = Action_Delay
    return true
end
-- Targeted job ability.
function Cast_Ability_On(ability_name, target)
    if not Can_Cast_Ability(ability_name) then return false end
    windower.send_command(
        'input /ja "' .. ability_name .. '" ' .. target
    )
    isBusy = Action_Delay
    return true
end
-- Follow-up job ability after a debuff SPELL
-- (e.g. Geo-Poison -> Radial Arcana).
function Schedule_Follow_Up(ability_name, wait_for_pet)
    coroutine.schedule(function()
        local deadline = os.clock() + 15
        coroutine.sleep(2.5)
        while os.clock() < deadline do
            local pet_ok = (not wait_for_pet)
                or windower.ffxi.get_mob_by_target('pet')
            if pet_ok and not isCasting and Can_Cast_Ability(ability_name) then
                Cast_Ability(ability_name)
                return
            end
            coroutine.sleep(0.5)
        end
    end, 0)
end