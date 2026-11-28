-- TARGETFOLLOW
-- Movement and facing: Stop_Range, Follow_Monitor (walking to the committed
-- target), HeadingTo, TurnToTarget.
-- Part of the TargetLogic split (see ../TargetLogic.lua). Code below is moved unchanged.

-- RANGE
local MELEE_ENGAGE_RANGE = 3
local FOLLOW_CAST_RANGE = 20
function Stop_Range(mob)
local rp = active_profile and active_profile.ranged_pull
if rp and mob and mob.claim_id == 0 then
return rp.range or 20
end
if rp and mob and mob.claim_id ~= 0 then
return rp.engage_distance or MELEE_ENGAGE_RANGE
end
if active_profile and active_profile.engage_distance then
return active_profile.engage_distance
end
if active_profile and active_profile.auto_engage == false then
return FOLLOW_CAST_RANGE
end
return MELEE_ENGAGE_RANGE
end
function Follow_Monitor()
while Start_Engine do
if Follower_Idle and Follower_Idle() then
-- FOLLOWER SAFETY: never move before the leader has started. (Anything
-- already in motion is stopped by FollowerGate.lua when the wait begins.)
elseif Mode_May_Move and not Mode_May_Move() then
-- SEMI-AUTO, not engaged: the player walks by hand. Do not touch follow.
elseif party_follow_override then
-- PartyCommands.lua (regroup / rez) owns movement right now. Do not
-- stop or redirect its follow every tick.
elseif combat_locked_target_id then
-- Preserve the combat lock. Never switch targets here.
local target = windower.ffxi.get_mob_by_id(combat_locked_target_id)
if target and target.valid_target then
-- Follow the locked target during combat, including
-- when hate switches to a ranged party member.
local distance = type(target.distance) == 'number'
and math.sqrt(target.distance)
or nil
local stop_range = Stop_Range(target)
if distance and distance > stop_range then
windower.ffxi.follow(target.index)
else
windower.ffxi.follow(0)
end
else
windower.ffxi.follow(0)
end
elseif settings.assist ~= '' and not managed_target_id then
    -- Follower has not committed to a damaged target yet.
    -- Do not follow the leader's untouched target.
    windower.ffxi.follow(0)
elseif Targeting_Paused() then
-- Do not follow or approach a new target while recovering.
windower.ffxi.follow(0)
elseif is_resting then
windower.ffxi.follow(0)
elseif isCasting or isBusy > 0 then
windower.ffxi.follow(0)
else
local target = windower.ffxi.get_mob_by_target('t')
if not target then
windower.ffxi.follow(0)
elseif managed_target_id and target.id ~= managed_target_id then
Debug.Target('FOLLOW MONITOR DIFFERENT <t>', target)
local mob = windower.ffxi.get_mob_by_id(managed_target_id)
if mob and mob.valid_target then
Select_Target(mob)
end
windower.ffxi.follow(0)
elseif Camp_Can_Approach and not Camp_Can_Approach() then
-- Camp Mode followers: do not chase the leader's target outside camp.
windower.ffxi.follow(0)
else
local distance = type(target.distance) == 'number'
and math.sqrt(target.distance)
or nil
local stop_range = Stop_Range(target)
if distance and distance <= stop_range then
windower.ffxi.follow(0)
else
windower.ffxi.follow(target.index)
end
end
end
coroutine.sleep(0.2)
end
end

-- Heading (radians) from the player to a world position.
function HeadingTo(x, y)
local player = windower.ffxi.get_mob_by_id(windower.ffxi.get_player().id)
if not player then return 0 end
local dx = x - player.x
local dy = y - player.y
return math.atan2(dx, dy) - 1.5708
end
-- Turns the player to face <t> if more than 10 degrees off.
function TurnToTarget()
local target = windower.ffxi.get_mob_by_target('t')
local p = windower.ffxi.get_player()
if not target or not p then return end
local me = windower.ffxi.get_mob_by_id(p.id)
if not me or not me.heading then return end
local desired = HeadingTo(target.x, target.y)
local d = desired - me.heading
d = math.atan2(math.sin(d), math.cos(d))
if math.abs(d) > math.rad(10) then
windower.ffxi.turn(desired)
end
end
