-- TARGETORIGIN
-- The hunting origin: Set_Origin and Path_To_Origin (walking back to it).
-- Part of the TargetLogic split (see ../TargetLogic.lua). Code below is moved unchanged.

function Set_Origin()
local player = windower.ffxi.get_player()
if not player then
return false
end
local mob = windower.ffxi.get_mob_by_id(player.id)
if not mob
or type(mob.x) ~= 'number'
or type(mob.y) ~= 'number'
or type(mob.z) ~= 'number'
then
Debug.Log('SET ORIGIN FAILED - PLAYER POSITION UNAVAILABLE')
return false
end
origin_x = mob.x
origin_y = mob.y
origin_z = mob.z
path_last_distance = nil
path_last_progress_time = nil
path_stuck_alerted = false
origin_unreachable_since = nil
windower.add_to_chat(
2,
'Origin set: (' ..
math.floor(origin_x) ..
', ' ..
math.floor(origin_y) ..
') radius: ' ..
tostring(origin_radius)
)
return true
end
function Path_To_Origin()
if Mode_May_Move and not Mode_May_Move() then
-- Semi-Auto, not engaged: never walk the player anywhere.
return
end
if party_follow_override then
-- Regroup / rez walking owns movement; do not path home over it.
return
end
if type(origin_x) ~= 'number'
or type(origin_y) ~= 'number'
then
return
end
local player = windower.ffxi.get_player()
if not player then
return
end
local mob = windower.ffxi.get_mob_by_id(player.id)
if not mob
or type(mob.x) ~= 'number'
or type(mob.y) ~= 'number'
or type(mob.z) ~= 'number'
then
windower.ffxi.run(false)
pathing_to_origin = false
path_tick = 0
return
end
local distance = Origin_Distance(mob.x, mob.y, mob.z)
if distance == math.huge then
windower.ffxi.run(false)
local now = os.clock()
if not origin_unreachable_since then
origin_unreachable_since = now
end
if (now - origin_unreachable_since) >= ORIGIN_UNREACHABLE_TIMEOUT then
if Camp_Block_Origin_Reanchor and Camp_Block_Origin_Reanchor() then
windower.add_to_chat(
167,
'[Domo] Origin unreachable, but Camp Mode is active -- not re-anchoring camp.'
)
origin_unreachable_since = nil
pathing_to_origin = false
path_tick = 0
return
end
windower.add_to_chat(
2,
'[Domo] Origin unreachable for ' ..
ORIGIN_UNREACHABLE_TIMEOUT ..
' sec -- re-anchoring origin and retargeting.'
)
Set_Origin()
return
end
if not path_stuck_alerted then
windower.add_to_chat(
167,
'[Domo] Origin unreachable at current elevation -- stopping autopath. Will re-anchor here after ' ..
ORIGIN_UNREACHABLE_TIMEOUT ..
' sec if still stuck.'
)
path_stuck_alerted = true
end
pathing_to_origin = false
path_tick = 0
return
end
origin_unreachable_since = nil
windower.ffxi.follow()
if distance > 3 then
local now = os.clock()
if not path_last_distance
or distance < path_last_distance - PATH_STUCK_EPSILON
then
path_last_distance = distance
path_last_progress_time = now
path_stuck_alerted = false
elseif path_last_progress_time
and (now - path_last_progress_time) >= PATH_STUCK_TIMEOUT
then
windower.ffxi.run(false)
if not path_stuck_alerted then
windower.add_to_chat(
167,
'[Domo] Stuck pathing to origin (no progress in ' ..
PATH_STUCK_TIMEOUT ..
's) -- stopping autopath.'
)
path_stuck_alerted = true
end
pathing_to_origin = false
path_tick = 0
return
end
path_tick = (path_tick or 0) + 1
if path_tick % 4 == 1 then
windower.ffxi.run(false)
elseif path_tick % 4 == 2 then
windower.ffxi.turn(HeadingTo(origin_x, origin_y))
else
windower.ffxi.run(true)
end
else
windower.ffxi.run(false)
pathing_to_origin = false
path_tick = 0
path_last_distance = nil
path_last_progress_time = nil
path_stuck_alerted = false
end
end
