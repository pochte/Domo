-- TARGETCOMBATLOCK
-- The combat lock and what feeds it: Clear_Combat_Target, damage taken and
-- the aggro queue, Combat_Stall_Monitor, Engagement_Sync and the lock
-- hand-off / recovery helpers (file-local functions).
-- Part of the TargetLogic split (see ../TargetLogic.lua). Code below is moved unchanged.

-- CLEAR COMBAT STATE
function Clear_Combat_Target()
Debug.State('CLEARING COMBAT STATE')
combat_locked_target_id = nil
managed_target_id = nil
pending_target_id = nil
pending_target_time = 0
engage_sent_target_id = nil
combat_lock_time = nil
combat_started = false
if Camp_Fight_Complete then
Camp_Fight_Complete()
end
end

local function Resolve_Attack_Name(param)
if not param or param == 0 then
return nil
end
local hit =
res.monster_abilities[param]
or res.spells[param]
or res.weapon_skills[param]
or res.job_abilities[param]
return hit and hit.en or nil
end
function Reset_Damage_Tracking()
last_damage_source = nil
last_damage_source_id = nil
last_damage_kind = nil
last_damage_taken_time = nil
aggro_queue = {}
last_party_damage_to_target = nil
damage_watch_target_id = nil
last_self_hit_on_current_target = nil
party_activity = {}
end
local function Track_Damage_Taken(action, player, current_id)
local target_count = action['Target Count'] or 1
for t = 1, target_count do
if action['Target ' .. t .. ' ID'] == player.id then
local actor_id = action.Actor
-- Reaction 0 can represent a heal/buff landing as well as
-- an attack, so party members and trusts are excluded.
if action['Target ' .. t .. ' Action 1 Reaction'] == 0
and actor_id
and not Is_Party_Member(actor_id)
then
local actor = windower.ffxi.get_mob_by_id(actor_id)
last_damage_source =
actor and actor.name
or last_damage_source
or 'something unseen'
last_damage_source_id = actor_id
last_damage_kind = Resolve_Attack_Name(action.Param)
last_damage_taken_time = os.clock()
if actor_id ~= current_id then
local already_queued = false
for _, qid in ipairs(aggro_queue) do
if qid == actor_id then
already_queued = true
break
end
end
if not already_queued then
aggro_queue[#aggro_queue + 1] = actor_id
if #aggro_queue > AGGRO_QUEUE_CAP then
table.remove(aggro_queue, 1)
end
end
end
end
break
end
end
end
-- Single 0x028 handler for everything targeting cares about.
windower.register_event('incoming chunk', function(id, data)
if id ~= 0x028 then
return
end
local action = packets.parse('incoming', data)
if not action then
return
end
local player = windower.ffxi.get_player()
if not player then
return
end
local current = windower.ffxi.get_mob_by_target('t')
local current_id = current and current.id
-- Damage taken by us (death cause + aggro queue)
Track_Damage_Taken(action, player, current_id)
-- Party activity on the current target
if damage_watch_target_id ~= current_id then
damage_watch_target_id = current_id
last_party_damage_to_target = current_id and os.clock() or nil
last_self_hit_on_current_target = current_id and os.clock() or nil
end
local is_self = action.Actor == player.id
local is_party = is_self or Is_Party_Member(action.Actor)
if not is_party then
return
end
local target_count = action['Target Count'] or 1
for t = 1, target_count do
local tid = action['Target ' .. t .. ' ID']
if tid and action['Target ' .. t .. ' Action 1 Reaction'] == 0 then
if tid == current_id then
last_party_damage_to_target = os.clock()
if is_self then
last_self_hit_on_current_target = os.clock()
end
end
if not is_self then
party_activity[action.Actor] = {
last_hit = os.clock(),
target_id = tid,
}
end
break
end
end
end)
-- COMBAT STALL MONITOR
function Combat_Stall_Monitor()
while Start_Engine do
coroutine.sleep(5)
end
end
-- ENGAGEMENT SYNC
-- Keeps the combat target valid while engaged, working through the aggro
-- queue (oldest first) and then the last attacker once the current
-- target is genuinely finished.
--
-- COMBAT LOCK RULES:
--   * A live locked target is never touched, regardless of distance,
--     other incoming aggro, or whether a trust died.
--   * A locked target missing from the mob table is only treated as lost
--     after LOCK_LOST_GRACE seconds of continuously missing.
--   * The lock is only handed to a new target. It is never simply cleared
--     here; Target_Monitor releases it when combat actually ends.
local ENGAGEMENT_SYNC_INTERVAL = 2
local LOCK_LOST_GRACE = 4
local function Is_Live_Enemy(mob)
return mob
and mob.id
and mob.valid_target
and type(mob.hpp) == 'number'
and mob.hpp > 0
end
local function Can_Switch_To(mob, player)
if not mob
or not player
or not Is_Live_Enemy(mob)
or Is_Player_Pet(mob)
or Is_Party_Member(mob.id)
or Is_Unattackable(mob.id)
then
return false
end
-- Allow unclaimed mobs, mobs claimed by us, and mobs claimed
-- by our party or alliance.
local party_ids = Get_Party_Claim_Ids() or {}
return mob.claim_id == 0
or mob.claim_id == player.id
or party_ids[mob.claim_id] == true
end
local function Prune_Aggro_Queue(player)
local party_ids = Get_Party_Claim_Ids() or {}
for i = #aggro_queue, 1, -1 do
local candidate =
windower.ffxi.get_mob_by_id(aggro_queue[i])
if not Is_Live_Enemy(candidate)
or Is_Player_Pet(candidate)
or Is_Party_Member(candidate.id)
or Is_Unattackable(candidate.id)
or (
candidate.claim_id ~= 0
and candidate.claim_id ~= player.id
and not party_ids[candidate.claim_id]
)
then
table.remove(aggro_queue, i)
end
end
end
-- Hand the combat lock to `mob` and select it. Player is already
-- engaged (status == 1), so this is a continuation of the same fight.
local function Handoff_Combat_Lock(mob, message)
local player = windower.ffxi.get_player()
if not player or not mob or not mob.id or not mob.index then
return false
end
-- Validate claim ownership as well as target validity. A handoff
-- must not move the lock to another player's unshared target.
if not Can_Switch_To(mob, player) then
Debug.Target('COMBAT HANDOFF REJECTED', mob)
return false
end
-- Select before committing the new lock. A failed selection must
-- not leave the combat state locked to a target we did not select.
if not Select_Target_By_Id(mob) then
Debug.Target('COMBAT HANDOFF EXACT SELECT FAILED', mob)
return false
end
combat_locked_target_id = mob.id
managed_target_id = mob.id
engage_sent_target_id = mob.id
combat_lock_time = nil
combat_started = true
pending_target_id = nil
pending_target_time = 0
windower.add_to_chat(2, message .. mob.name)
return true
end
-- Pick the next target once the locked one is truly finished: the aggro
-- queue first (oldest first), then the last thing that hit us. Handoff
-- moves the lock to the new target; it never just clears it.
-- (This definition went missing in the Oct 15 "fixes" commit while
-- Engagement_Sync still called it, which killed that loop on the first
-- lost target.)
local function Recover_Combat_Target(player, current_id)
while #aggro_queue > 0 do
local candidate = windower.ffxi.get_mob_by_id(table.remove(aggro_queue, 1))
if Can_Switch_To(candidate, player) then
if Handoff_Combat_Lock(candidate, '[Domo] Finishing that off, now dealing with: ') then
return true
end
end
end
if last_damage_source_id and last_damage_source_id ~= current_id then
local attacker = windower.ffxi.get_mob_by_id(last_damage_source_id)
if Can_Switch_To(attacker, player) then
if Handoff_Combat_Lock(attacker, '[Domo] Engaged target mismatch -- retargeting to ') then
return true
end
end
end
return false
end
function Engagement_Sync()
local lock_missing_since = nil
while Start_Engine do
local player = windower.ffxi.get_player()
if player then
Prune_Aggro_Queue(player)
end
if player and player.status == 1
and not (Follower_Idle and Follower_Idle())
then
local target_ok = false
local current_id = nil
if combat_locked_target_id then
current_id = combat_locked_target_id
local locked =
windower.ffxi.get_mob_by_id(combat_locked_target_id)
if locked and Is_Party_Member(locked.id) then
Debug.Target('COMBAT LOCK IS PARTY MEMBER - CLEARING INVALID LOCK', locked)
Clear_Combat_Target()
lock_missing_since = nil
elseif Is_Live_Enemy(locked) and not Is_Player_Pet(locked) and not Is_Party_Member(locked.id) then
target_ok = true
lock_missing_since = nil
elseif locked
and type(locked.hpp) == 'number'
and locked.hpp <= 0
then
-- Confirmed dead.
lock_missing_since = nil
else
-- Missing / not targetable right now. This could be
-- a brief mob-table blip, so hold the lock temporarily.
local now = os.clock()
lock_missing_since = lock_missing_since or now
if now - lock_missing_since < LOCK_LOST_GRACE then
target_ok = true
end
end
else
lock_missing_since = nil
local current = windower.ffxi.get_mob_by_target('t')
current_id = current and current.id
target_ok =
Is_Live_Enemy(current)
and not Is_Player_Pet(current)
end
if not target_ok then
if Recover_Combat_Target(player, current_id) then
lock_missing_since = nil
end
end
else
lock_missing_since = nil
end
coroutine.sleep(ENGAGEMENT_SYNC_INTERVAL)
end
end
