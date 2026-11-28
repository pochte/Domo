-- TARGETSELECTION
-- Choosing and selecting a target: the Find_* searches, Choose_Target,
-- Select_Target, Select_Target_By_Id, Confirm_Target.
-- Part of the TargetLogic split (see ../TargetLogic.lua). Code below is moved unchanged.

-- TARGETING HELPERS
function Find_Named_Target(target_name)
if not target_name then
return -1
end
local mob_array = windower.ffxi.get_mob_array()
if not mob_array then
return -1
end
local candidates = {}
for key, mob in pairs(mob_array) do
if mob
and type(mob.distance) == 'number'
and mob.distance >= 0
and not Is_Player_Pet(mob)
then
candidates[#candidates + 1] = {
key = key,
mob = mob,
dist = math.sqrt(mob.distance),
}
end
end
table.sort(candidates, function(a, b)
return a.dist < b.dist
end)
local wanted_name = string.lower(target_name)
for _, entry in ipairs(candidates) do
local mob = entry.mob
local in_range = true
if origin_x and not (Camp_Skip_Origin_For_Discovery and Camp_Skip_Origin_For_Discovery()) then
if type(mob.x) == 'number'
and type(mob.y) == 'number'
and type(mob.z) == 'number'
and type(origin_radius) == 'number'
then
in_range =
Origin_Distance(mob.x, mob.y, mob.z) <= origin_radius
else
in_range = false
end
end
if string.lower(mob.name or '') == wanted_name
and mob.valid_target
and type(mob.hpp) == 'number'
and mob.hpp > 0
and in_range
and mob.claim_id == 0
and not Is_Unattackable(mob.id)
then
return entry.key
end
end
return -1
end

function Find_Nearest_Target()
local mob_array = windower.ffxi.get_mob_array()
if not mob_array then
return -1
end
local config = targeting or {}
local candidates = {}
for key, mob in pairs(mob_array) do
if mob
and type(mob.distance) == 'number'
and mob.distance >= 0
and not Is_Player_Pet(mob)
then
candidates[#candidates + 1] = {
key = key,
mob = mob,
dist = math.sqrt(mob.distance),
}
end
end
table.sort(candidates, function(a, b)
return a.dist < b.dist
end)
for _, entry in ipairs(candidates) do
local mob = entry.mob
local valid =
Is_Targetable_Monster(mob.name)
and mob.valid_target
and (
not config.only_alive
or (
type(mob.hpp) == 'number'
and mob.hpp > 0
)
)
and (
not config.within_origin
or not origin_x
or (Camp_Skip_Origin_For_Discovery and Camp_Skip_Origin_For_Discovery())
or type(mob.x) ~= 'number'
or type(mob.y) ~= 'number'
or type(mob.z) ~= 'number'
or (
type(origin_radius) == 'number'
and Origin_Distance(mob.x, mob.y, mob.z) <= origin_radius
)
)
and (
not config.only_unclaimed
or mob.claim_id == 0
)
and not Is_Unattackable(mob.id)
if valid then
return entry.key
end
end
return -1
end

function Find_Party_Target(party_ids)
if not party_ids or next(party_ids) == nil then
return nil
end
local mob_array = windower.ffxi.get_mob_array()
if not mob_array then
return nil
end
local player = windower.ffxi.get_player()
for index, mob in pairs(mob_array) do
if mob
and not Is_Player_Pet(mob)
and not Is_Party_Member(mob.id)
and not (player and mob.id == player.id)
and mob.valid_target
and mob.hpp and mob.hpp > 0
and not Is_Unattackable(mob.id)
and mob.claim_id and party_ids[mob.claim_id]
and (
not (origin_x and mob.x)
or (Camp_Skip_Origin_For_Discovery and Camp_Skip_Origin_For_Discovery())
or Origin_Distance(mob.x, mob.y, mob.z) <= origin_radius
)
then
return index
end
end
return nil
end
function Find_Nearest_Party_Claimed_Target(party_ids)
if not party_ids or next(party_ids) == nil then
return nil
end
local mob_array = windower.ffxi.get_mob_array()
if not mob_array then
return nil
end
local player = windower.ffxi.get_player()
local candidates = {}
for _, mob in pairs(mob_array) do
if mob
and not Is_Player_Pet(mob)
and not Is_Party_Member(mob.id)
and not (player and mob.id == player.id)
and mob.valid_target
and mob.hpp and mob.hpp > 0
and not Is_Unattackable(mob.id)
and mob.claim_id and party_ids[mob.claim_id]
and mob.distance
and (
not (origin_x and mob.x)
or (Camp_Skip_Origin_For_Discovery and Camp_Skip_Origin_For_Discovery())
or Origin_Distance(mob.x, mob.y, mob.z) <= origin_radius
)
then
candidates[#candidates + 1] = {
mob = mob,
dist = math.sqrt(mob.distance)
}
end
end
table.sort(candidates, function(a, b)
return a.dist < b.dist
end)
return candidates[1] and candidates[1].mob
end

function Choose_Target(party_ids)
if not windower.ffxi.get_player() then
return -1
end
-- Keep the current target if it remains legitimate.
-- This prevents unnecessary target switching during combat.
local current = windower.ffxi.get_mob_by_target('t')
if Is_Legitimate_Target(current, nil, party_ids, true) then
return current.index
end
-- Otherwise, select the nearest configured target.
local nearest = Find_Nearest_Target()
if type(nearest) == 'number' and nearest > 0 then
return nearest
end
-- Solo leaders do not fall back to party-claimed targets.
if Is_Solo_Leader() then
return -1
end
return Find_Party_Target(party_ids) or -1
end

-- EXACT TARGET SELECTION
-- Select a specific mob by ID, avoiding name-based ambiguity.
function Select_Target_By_Id(mob)
if not mob or not mob.id or not mob.index then
Debug.Log('EXACT SELECT FAILED - INVALID MOB')
return false
end
local player = windower.ffxi.get_player()
if Is_Player_Pet(mob) then
Debug.Target('EXACT SELECT BLOCKED - PLAYER PET/LUPON', mob)
return false
end
-- Hard safety guard: no target-selection caller may select the player
-- or a party member as a combat target. Support spells target names directly
-- and do not need Select_Target().
if (player and mob.id == player.id) or Is_Party_Member(mob.id) then
Debug.Target('EXACT SELECT BLOCKED - PLAYER/PARTY MEMBER', mob)
return false
end
if not player or not player.id then
Debug.Log('EXACT SELECT FAILED - PLAYER UNAVAILABLE')
return false
end
local player_mob = windower.ffxi.get_mob_by_id(player.id)
if not player_mob or not player_mob.index then
Debug.Log('EXACT SELECT FAILED - PLAYER MOB INDEX UNAVAILABLE')
return false
end
-- Re-fetch the mob to avoid acting on a stale mob-table entry.
local current_mob = windower.ffxi.get_mob_by_id(mob.id)
if not current_mob
or not current_mob.valid_target
or type(current_mob.hpp) ~= 'number'
or current_mob.hpp <= 0
or current_mob.index ~= mob.index
then
Debug.Log(
'EXACT SELECT FAILED - MOB NO LONGER VALID: ' ..
tostring(mob.id)
)
return false
end
local ok, err = pcall(function()
packets.inject(packets.new('incoming', 0x058, {
['Player'] = player.id,
['Target'] = current_mob.id,
['Player Index'] = player_mob.index,
}))
end)
if not ok then
Debug.Log('EXACT SELECT PACKET FAILED: ' .. tostring(err))
return false
end
Debug.Target('EXACT TARGET SELECT SENT', current_mob)
return true
end
-- General selection entry point.
-- Always uses exact-ID selection rather than mob names.
function Select_Target(mob)
if not mob then
Debug.Log('SELECT TARGET FAILED - NO MOB')
return false
end
return Select_Target_By_Id(mob)
end
-- Confirm whether the current target matches the requested mob.
-- If no mob is supplied, check the current combat lock.
function Confirm_Target(mob)
local expected_id
if mob then
expected_id = mob.id
else
expected_id = combat_locked_target_id
end
if not expected_id then
Debug.Log('CONFIRM TARGET FAILED - NO EXPECTED TARGET')
return false
end
local target = windower.ffxi.get_mob_by_target('t')
if not target or target.id ~= expected_id then
Debug.Log(
'TARGET CONFIRM FAILED - EXPECTED ' ..
tostring(expected_id) ..
', ACTUAL ' ..
tostring(target and target.id or 'NONE')
)
return false
end
return true
end
