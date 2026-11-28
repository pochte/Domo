-- TARGETCOMBAT
-- Combat(): what to do to the locked target each second (provoke, debuffs,
-- nukes, bursts, weaponskills, melee support).
-- Part of the TargetLogic split (see ../TargetLogic.lua). Code below is moved unchanged.

-- FACING + COMBAT ROTATION
-- Moved here from Domo.lua / JobLogic.lua so there is exactly one copy.
-- engaged_since is global (Combat's stuck-target Provoke timer).
engaged_since = nil
provoke_last_try = 0

-- Per-tick combat rotation (called by Domo.lua's Engine via pcall).
function Combat()
local player = windower.ffxi.get_player()
if not player then return end
local target = windower.ffxi.get_mob_by_target('t')
local starter = Get_WS_Starter()
if player.status == 1 then
if not engaged_since then
engaged_since = os.clock()
end
else
engaged_since = nil
end
if active_profile
and active_profile.provoke_if_stuck
and player.status == 1
and target
and engaged_since
and (os.clock() - engaged_since) >= (active_profile.stuck_threshold or 10)
then
-- Provoke is an enemy-only ability. Never route it through the generic
-- Cast_Ability helper (it resolved to a party member / the mob's claimer,
-- giving 'You cannot attack that target.' every tick). Send it at <t>
-- only when <t> is a real hostile, and throttle retries: a rejected JA
-- never starts its recast, so Can_Cast_Ability stays true forever.
local now = os.clock()
if (now - (provoke_last_try or 0)) >= 30
and target
and target.valid_target
and type(target.hpp) == 'number'
and target.hpp > 0
and target.id ~= player.id
and not Is_Party_Member(target.id)
and not Is_Player_Pet(target)
and Can_Cast_Ability('Provoke')
then
provoke_last_try = now
windower.send_command('input /ja "Provoke" <t>')
end
TurnToTarget()
end

-- FOLLOWER HP GATE
-- This must run before EVERY offensive action, including finishers.
if Follower_Hold_Fire and Follower_Hold_Fire(target) then return end

-- Nearly dead target: just kill it.
if Try_Finisher and Try_Finisher() then return end

-- SEMI-AUTO (Semi_Auto_Hold_Fire in PlayMode.lua): the player starts every
-- fight. Nothing offensive is opened on a mob that is not engaged and not
-- already claimed by the party.
if Semi_Auto_Hold_Fire and Semi_Auto_Hold_Fire(target) then return end
local magic_burst_ok = active_profile and active_profile.magic_burst
if magic_burst_ok and active_profile.magic_burst_requires_buff then
magic_burst_ok = buffactive[active_profile.magic_burst_requires_buff]
and true
or false
end
if magic_burst_ok then
-- A valid magic burst gets first priority.
if Try_Magic_Burst and Try_Magic_Burst() then return end
end
-- RDM's required debuffs outrank ordinary nukes and everything below,
-- whether or not magic-burst mode is currently eligible.
if (current_job == 'RDM' or current_job == 'GEO') and Debuff_Pending and Debuff_Pending() then
return
end
-- Free nuking is independent of the magic-burst gate. In particular, GEO
-- must still free-nuke when a burst-only prerequisite buff is absent.
if Try_Free_Nuke and Try_Free_Nuke() then return end
-- Jobs that never melee (auto_engage = false: BLM, GEO, SCH) stop here.
-- Melee jobs with magic burst (e.g. NIN) continue to their WS logic.
if active_profile and active_profile.auto_engage == false then
return
end
-- A melee job must not open a new chain on top of a window it is about to
-- burst; the opener would replace the skillchain mid-cast.
if magic_burst_ok
and Burst_Window_Open
and Get_Burst_Spell
and Burst_Window_Open(target)
and Get_Burst_Spell(target)
then
return
end
-- Haste Samba (DNC or /DNC): every 90s, before the DNC rotation or any chain.
if Try_Haste_Samba and Try_Haste_Samba(target) then
return
end
if active_profile
and active_profile.dnc_rotation
and current_job == 'DNC'
then
if Try_DNC_Actions() then return end
end
if target
and target.distance
and math.sqrt(target.distance) <= 3
and player.vitals.tp >= 3000
and isBusy == 0
and not isCasting
-- With an ordered chain, a window that is open belongs to
-- SC_Monitor; do not smash the opener on top of it.
and not (Get_WS_Chain() and sc_active and sc_active(target.id))
and starter
and starter[1]
and active_profile
and active_profile.use_weaponskills ~= false
then
if current_job == 'DNC' and Try_DNC_Pre_WS_Flourish() then
return
end
windower.send_command(
'input /ws "' .. starter[1] .. '" <t>'
)
isBusy = Action_Delay
dnc_flourish_pending = true
return
end
if player.status ~= 1
and (not active_profile or active_profile.auto_engage ~= false)
then
return
end
lockon_done = false
if player.vitals.tp >= 400
and target
and target.distance
and math.sqrt(target.distance) <= 3
then
local recasts = windower.ffxi.get_ability_recasts()
-- Each needed buff gets ONE attempt per interval. A rejected JA never starts
-- its recast (and some entries, like Box Step / Reverse Flourish, never show
-- up as a buff on you), so without this throttle the loop re-sent them every
-- tick and the opener below was starved until 3000 TP.
--
-- CRITICAL: a missing or on-cooldown needed buff must NEVER stall the fight.
-- One try, then skip until the interval elapses. No food in inventory = keep
-- fighting hungry. Ability on cooldown = skip it and continue the rotation.
needed_buff_try = needed_buff_try or {}
local buff_rules = (active_profile and active_profile.needed_buff_rules) or {}
for _, ability_name in ipairs(Get_Needed_Buffs() or {}) do
local rule = buff_rules[ability_name] or {}
local interval = rule.interval or 15
local fm_ok = (not rule.min_finishing_moves)
or (Finishing_Move_Count() >= rule.min_finishing_moves)
local last_try = needed_buff_try[ability_name] or 0
if not buffactive[ability_name]
and fm_ok
and (os.clock() - last_try) >= interval then
if ability_name == 'Food' then
local food_item = Get_Food and Get_Food()
if food_item and Has_Food_Available and Has_Food_Available(food_item) then
needed_buff_try[ability_name] = os.clock()
windower.send_command(
'input /item "' .. food_item .. '" <me>'
)
isBusy = Action_Delay
return
end
-- No food configured, or none left in bags: mark tried and continue.
-- Never freeze the bot waiting for food that does not exist.
needed_buff_try[ability_name] = os.clock()
if food_item and not (food_exhausted_notified) then
food_exhausted_notified = true
session_depleted = session_depleted or {}
session_depleted[#session_depleted + 1] = 'Food (' .. tostring(food_item) .. ')'
windower.add_to_chat(207, '[Domo] No food left (' .. tostring(food_item) .. ') -- continuing without it.')
end
else
local ability = res.job_abilities:with('name', ability_name)
if ability and recasts[ability.recast_id] == 0 and Can_Cast_Ability and Can_Cast_Ability(ability_name) then
needed_buff_try[ability_name] = os.clock()
if Cast_Ability(ability_name) then
return
end
-- Cast was rejected (wrong state, TP, target, etc.). Timer is set so
-- we do not spam; fight continues without this buff.
else
-- On cooldown or unknown ability: mark the try so we skip it until
-- the interval passes instead of re-checking every tick.
needed_buff_try[ability_name] = os.clock()
end
end
end
end
end
TurnToTarget()
if target and target.distance and math.sqrt(target.distance) <= 3 then
local tp = player.vitals.tp
if sc_active
and not sc_active(target.id)
and starter
and tp >= starter[2]
and active_profile
and active_profile.use_weaponskills ~= false
then
if current_job == 'DNC'
and Try_DNC_Pre_WS_Flourish()
then
return
end
windower.send_command(
'input /ws "' .. starter[1] .. '" <t>'
)
isBusy = Action_Delay
dnc_flourish_pending = true
return
end
if settings.spell_active
and Can_Cast_Spell(settings.spell)
and not Is_Blacklisted(target.name)
then
Cast_Spell(settings.spell)
end
elseif target
and settings.spell_active
and Can_Cast_Spell(settings.spell)
and not Is_Blacklisted(target.name)
then
Cast_Spell(settings.spell)
end
end
