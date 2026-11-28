-- TARGETING
-- Targeting(): the main loop that decides, every tick, whether to follow,
-- assist, pull or choose a new target (Leader, Follower and Semi-Auto).
-- Part of the TargetLogic split (see ../TargetLogic.lua). Code below is moved unchanged.

-- MAIN TARGETING LOOP
function Targeting()
while Start_Engine do
local player = windower.ffxi.get_player()
if player then
-- FOLLOWER SAFETY: a follower selects, engages and fights nothing until
-- the leader has started (FollowerGate.lua).
if Follower_Idle and Follower_Idle() then
-- idle
-- COMBAT LOCK
-- Always let the current fight continue, even when a trust
-- dies. Follow_Monitor owns movement for the locked target.
elseif combat_locked_target_id then
pending_target_id = nil
pending_target_time = 0
-- RESTING
elseif is_resting then
windower.ffxi.follow(0)
-- PLAYER ALREADY ENGAGED
-- Do not interrupt an active fight merely because recovery
-- is pending. Adopt the current target so its lock is kept.
elseif player.status == 1 then
local target = windower.ffxi.get_mob_by_target('t')
if target and (
    Is_Player_Pet(target)
    or Is_Party_Member(target.id)
    or target.id == player.id
) then
Debug.Target('CURRENT <t> IS PLAYER/PARTY MEMBER/PET - STOPPING ATTACK', target)
windower.send_command('input /attack off')
Clear_Combat_Target()
windower.ffxi.follow(0)
elseif target and target.id then
managed_target_id = target.id
combat_locked_target_id = target.id
engage_sent_target_id = target.id
combat_lock_time = nil
combat_started = true
pending_target_id = nil
pending_target_time = 0
Debug.Target('PLAYER ALREADY ENGAGED - LOCKING', target)
Debug.State('EXISTING COMBAT LOCK')
end
windower.ffxi.follow(0)
-- SEMI-AUTO
-- The player picks targets, walks and engages by hand. Until they engage
-- there is nothing to do here, and nothing may select, move or engage.
-- (Once engaged, the branch above adopts the target.)
elseif Semi_Auto_Active and Semi_Auto_Active() then
pending_target_id = nil
pending_target_time = 0
managed_target_id = nil
engage_sent_target_id = nil
-- TRUST RECOVERY
-- No active combat lock and not engaged: wait for TrustLogic.
-- This check must precede pending targets, managed targets,
-- assist mode, and autotarget.
elseif Targeting_Paused() then
pending_target_id = nil
pending_target_time = 0
windower.ffxi.follow(0)
-- WAITING FOR TARGET SELECTION
-- ASSIST MODE
-- Follower mode always gets priority over stale managed targets
-- and pending leader-mode selections.
elseif settings.assist ~= '' then
    local target

    -- Already committed: stay with this enemy.
    if managed_target_id then
        target = windower.ffxi.get_mob_by_id(managed_target_id)

        if not target
            or not target.valid_target
            or type(target.hpp) ~= 'number'
            or target.hpp <= 0
            or Is_Player_Pet(target)
            or Is_Party_Member(target.id)
            or target.id == player.id
        then
            Debug.Target('FOLLOWER TARGET LOST - RELEASING', target)

            managed_target_id = nil
            engage_sent_target_id = nil
            pending_target_id = nil
            pending_target_time = 0
            windower.ffxi.follow(0)
            target = nil
        end
    else
        -- No committed target: inspect the leader's current target.
        windower.send_command('input /assist ' .. settings.assist)

        target = windower.ffxi.get_mob_by_target('t')
        Debug.Target('ASSIST TARGET', target)

        local valid =
            target
            and target.id ~= player.id
            and not Is_Player_Pet(target)
            and not Is_Party_Member(target.id)
            and target.valid_target
            and type(target.hpp) == 'number'
            and target.hpp > 0

        if valid and target.hpp <= 99 then
            managed_target_id = target.id
            engage_sent_target_id = nil

            Debug.Target('FOLLOWER COMMITTED TO LEADER TARGET', target)
        else
            -- Untouched target: wait without approaching or attacking.
            windower.ffxi.follow(0)
            target = nil
        end
    end

    -- Only approach or engage the committed enemy.
    if target and managed_target_id == target.id then
        local distance = type(target.distance) == 'number'
            and math.sqrt(target.distance)
            or nil

        if distance and distance <= Stop_Range(target) then
            Engage_Target(target)
        else
            windower.ffxi.follow(target.index)
        end
    end

    if not lockon_done
        and active_profile
        and active_profile.auto_engage ~= false
    then
        windower.send_command('input /lockon')
        lockon_done = true
    end

elseif pending_target_id then
    local expected_id = pending_target_id
    local confirmed = Confirm_Target({ id = expected_id })

    if confirmed then
        local mob = windower.ffxi.get_mob_by_id(expected_id)

        if not mob
            or not mob.valid_target
            or type(mob.hpp) ~= 'number'
            or mob.hpp <= 0
            or Is_Player_Pet(mob)
        then
            Debug.State('CONFIRMED TARGET NO LONGER VALID')
            pending_target_id = nil
            pending_target_time = 0
        else
            local distance = type(mob.distance) == 'number'
                and math.sqrt(mob.distance)
                or nil

            local stop_range = Stop_Range(mob)

            Debug.Target('CONFIRMED TARGET WAITING FOR RANGE', mob)

            if distance and distance > stop_range then
                Debug.Target('CONFIRMED TARGET OUT OF RANGE - FOLLOWING', mob)
                windower.ffxi.follow(mob.index)
            else
                windower.ffxi.follow(0)
                Debug.Target('CONFIRMED TARGET READY TO ENGAGE', mob)
                Engage_Target(mob)
            end
        end
    end

-- EXISTING MANAGED TARGET
elseif managed_target_id then
local target = windower.ffxi.get_mob_by_target('t')
local managed_mob =
windower.ffxi.get_mob_by_id(managed_target_id)
if managed_mob and (Is_Player_Pet(managed_mob) or Is_Party_Member(managed_mob.id) or managed_mob.id == player.id) then
Debug.Target(
'MANAGED TARGET IS PLAYER/PARTY MEMBER/PET - DROPPING',
managed_mob
)
managed_target_id = nil
pending_target_id = nil
pending_target_time = 0
engage_sent_target_id = nil
combat_lock_time = nil
combat_started = false
windower.ffxi.follow(0)
elseif not managed_mob or not managed_mob.valid_target then
Debug.State('MANAGED TARGET DEAD/GONE')
managed_target_id = nil
pending_target_id = nil
pending_target_time = 0
engage_sent_target_id = nil
combat_lock_time = nil
combat_started = false
windower.ffxi.follow(0)
elseif not target or target.id ~= managed_target_id then
Debug.Target('MAIN LOOP RESELECT', managed_mob)
Select_Target(managed_mob)
else
local party_ids = Get_Party_Claim_Ids() or {}
if target.claim_id ~= 0
and target.claim_id ~= player.id
and not party_ids[target.claim_id]
then
-- Someone else claimed it. Drop it and allow a new
-- target to be selected on a later tick.
Debug.Target(
'MANAGED TARGET CLAIMED BY SOMEONE ELSE',
target
)
managed_target_id = nil
pending_target_id = nil
pending_target_time = 0
engage_sent_target_id = nil
combat_lock_time = nil
combat_started = false
windower.ffxi.follow(0)
elseif Is_Unattackable(target.id) then
Debug.Target('MANAGED TARGET BENCHED - DROPPING', target)
managed_target_id = nil
pending_target_id = nil
pending_target_time = 0
engage_sent_target_id = nil
combat_lock_time = nil
combat_started = false
windower.ffxi.follow(0)
else
local distance = type(target.distance) == 'number'
and math.sqrt(target.distance)
or nil
local stop_range = Stop_Range(target)
if distance and distance > stop_range then
if Camp_Can_Approach and not Camp_Can_Approach() then
Debug.Target(
'CAMP MODE - NOT APPROACHING MANAGED TARGET OUTSIDE CAMP',
target
)
windower.ffxi.follow(0)
else
Debug.Target(
'MANAGED TARGET OUT OF RANGE - FOLLOWING',
target
)
windower.ffxi.follow(target.index)
end
else
windower.ffxi.follow(0)
Engage_Target(target)
end
end
end
-- AUTOTARGET
elseif settings.autotarget then
local target_id
local expected_name =
(settings.target and settings.target ~= '')
and settings.target
or nil
local party_ids = Get_Party_Claim_Ids() or {}
if expected_name then
target_id = Find_Named_Target(settings.target)
else
target_id = Choose_Target(party_ids)
end
if type(target_id) ~= 'number' or target_id <= 0 then
Path_To_Origin()
else
local mob = windower.ffxi.get_mob_by_index(target_id)
if mob
and Is_Legitimate_Target(
mob,
expected_name,
party_ids,
false
)
then
pathing_to_origin = false
path_tick = 0
managed_target_id = mob.id
pending_target_id = nil
pending_target_time = 0
engage_sent_target_id = nil
combat_lock_time = nil
combat_started = false
Debug.Target('AUTOTARGET CHOSE', mob)
Debug.State('AFTER AUTOTARGET')
local distance = type(mob.distance) == 'number'
and math.sqrt(mob.distance)
or nil
if not Try_Ranged_Pull(mob, distance) then
-- Record the requested target so the target
-- confirmation logic can track the selection.
pending_target_id = mob.id
pending_target_time = os.clock()
Select_Target(mob)
end
else
Path_To_Origin()
end
end
end
end
coroutine.sleep(0.5)
end
end
