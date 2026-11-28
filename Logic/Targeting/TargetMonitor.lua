-- TARGETMONITOR
-- Target_Monitor(): keeps the committed target valid, releases the lock when
-- combat ends, re-engages when it is safe.
-- Part of the TargetLogic split (see ../TargetLogic.lua). Code below is moved unchanged.

-- TARGET MONITOR
function Target_Monitor()
while Start_Engine do
local player = windower.ffxi.get_player()
local target = windower.ffxi.get_mob_by_target('t')
local target_id = target and target.id
Debug.Target_Changed(target)
-- Remember an actual enemy while it is selected. If a support action then
-- switches <t> to a party member (or clears it), keep the enemy ID so it can
-- be restored even when managed_target_id was never set by autotargeting.
local target_is_enemy = target
and target.id ~= (player and player.id)
and target.valid_target ~= false
and type(target.hpp) == 'number'
and target.hpp > 0
and (not target.spawn_type or target.spawn_type == 16)
and not Is_Party_Member(target.id)
and not Is_Player_Pet(target)
if target_is_enemy then
if not isCasting and (isBusy or 0) <= 0 and not pending_cast then
last_enemy_target_id = target.id
if support_return_target_id == target.id then
support_return_target_id = nil
end
end
elseif (isCasting or (isBusy or 0) > 0 or pending_cast)
and last_enemy_target_id
and not support_return_target_id
then
support_return_target_id = last_enemy_target_id
end
-- SEMI-AUTO: the player may switch to another enemy mid-fight; follow
-- their choice instead of dragging them back to the old target.
if Semi_Auto_Active and Semi_Auto_Active()
and player and player.status == 1
and combat_locked_target_id
and target_is_enemy
and target.id ~= combat_locked_target_id
and not isCasting and (isBusy or 0) <= 0 and not pending_cast
then
Clear_Combat_Target()
end
-- COMBAT LOCK OWNS EVERYTHING
-- FOLLOWER SAFETY: while the leader has not started, never re-engage or
-- retarget; the lock is simply left alone.
if Follower_Idle and Follower_Idle() then
-- idle
elseif combat_locked_target_id then
pending_target_id = nil
pending_target_time = 0
-- FFXI has actually entered combat.
if player and player.status == 1 then
if not combat_started then
Debug.Log(
'>>> COMBAT STARTED <<< target=' ..
tostring(combat_locked_target_id)
)
end
combat_started = true
-- Combat was previously active and has now ended.
-- This is the ONLY normal path that releases the combat lock.
elseif combat_started then
Debug.Log(
'>>> COMBAT ENDED <<< target=' ..
tostring(combat_locked_target_id)
)
Clear_Combat_Target()
else
-- Pre-engage lock that never actually reached combat.
local locked =
windower.ffxi.get_mob_by_id(combat_locked_target_id)
if locked and (Is_Player_Pet(locked) or Is_Party_Member(locked.id)) then
Debug.Target(
'PRE-ENGAGE LOCK IS PLAYER PET/LUPON OR PARTY MEMBER - CLEARING',
locked
)
Clear_Combat_Target()
elseif not locked
or not locked.valid_target
or not locked.hpp
or locked.hpp <= 0
then
Debug.Log(
'>>> PRE-ENGAGE TARGET LOST <<< target=' ..
tostring(combat_locked_target_id)
)
Clear_Combat_Target()
else
-- Retry an engage that may have been ignored while
-- casting. Restore the locked target if necessary;
-- never attack whichever mob happens to be <t>.
local now = os.clock()
local lock_age = combat_lock_time
and (now - combat_lock_time)
or 0
if lock_age > 10 then
Debug.Log(
'>>> ENGAGE NEVER STARTED - GIVING UP <<< target=' ..
tostring(combat_locked_target_id)
)
unattackable_until[combat_locked_target_id] =
now + 15
Clear_Combat_Target()
elseif lock_age >= 2
and not isCasting
and now - (engage_retry_time or 0) >= 2
then
engage_retry_time = now
local cur =
windower.ffxi.get_mob_by_target('t')
if not cur or cur.id ~= locked.id then
Debug.Log(
'>>> RESTORING LOCKED TARGET <<< target=' ..
tostring(locked.id)
)
Select_Target_By_Id(locked)
else
local dist = locked.distance
and math.sqrt(locked.distance)
if dist
and dist <= Stop_Range(locked) + 1
then
Debug.Log(
'>>> RESENDING /attack on <<< target=' ..
tostring(locked.id)
)
windower.send_command('input /attack on')
end
end
end
end
end
coroutine.sleep(0.1)
-- ALREADY ENGAGED WITHOUT OUR LOCK
-- Preserve an active fight even if recovery started before this
-- monitor adopted the target.
elseif player and player.status == 1 then
if target
and target.id
and not Is_Player_Pet(target)
and not Is_Party_Member(target.id)
and target.id ~= player.id
then
managed_target_id = target.id
combat_locked_target_id = target.id
engage_sent_target_id = target.id
combat_lock_time = nil
combat_started = true
pending_target_id = nil
pending_target_time = 0
Debug.Target('ADOPTING EXISTING COMBAT TARGET', target)
end
-- TRUST RECOVERY
-- Combat has ended and there is no active lock. Do not adopt
-- a pre-engage target or select a replacement while recovering.
elseif Targeting_Paused() then
pending_target_id = nil
pending_target_time = 0
-- MANAGED TARGET OUTSIDE COMBAT
-- Support spells temporarily select a party member. Do not fight that
-- temporary target while a cast/action is underway; restore our managed
-- enemy as soon as the action has actually finished.
elseif settings.assist == ''
    and (support_return_target_id or managed_target_id)
then
if not isCasting and (isBusy or 0) <= 0 and not pending_cast then
local wanted_id = support_return_target_id or managed_target_id
if not target or target.id ~= wanted_id then
local mob = windower.ffxi.get_mob_by_id(wanted_id)
if mob
and mob.valid_target
and type(mob.hpp) == 'number'
and mob.hpp > 0
and not Is_Player_Pet(mob)
and not Is_Party_Member(mob.id)
and (not player or mob.id ~= player.id)
then
Debug.Target('TARGET MONITOR RESTORE ENEMY TARGET', mob)
Select_Target(mob)
else
support_return_target_id = nil
end
elseif support_return_target_id and target and target.id == support_return_target_id then
support_return_target_id = nil
end
end
end
coroutine.sleep(0.1)
end
end
