-- TARGETCORE
-- Small shared helpers: Targeting_Paused, Origin_Distance, party/pet/enemy
-- predicates, claim checks, the unattackable list. No decisions are made
-- here.
-- Part of the TargetLogic split (see ../TargetLogic.lua). Code below is moved unchanged.

-- TARGETING PAUSE
-- True while TrustLogic.lua is recovering dead trusts, or while a player
-- is being brought into the party (party_join_active). Blocks new target
-- acquisition, new engagements and approaching; never touches an
-- established combat lock.
function Targeting_Paused()
-- Party_Paused() (PartyCommands.lua) covers hold, regroup, go home and rez waits.
local party_paused = Party_Paused and Party_Paused()
return (trust_recovery_paused or party_join_active or party_paused) and true or false
end
-- ORIGIN / PATHING
function Origin_Distance(x, y, z)
if type(origin_x) ~= 'number'
or type(origin_y) ~= 'number'
or type(x) ~= 'number'
or type(y) ~= 'number'
then
return math.huge
end
if type(origin_z) == 'number'
and type(z) == 'number'
and type(origin_z_tolerance) == 'number'
and math.abs(z - origin_z) > origin_z_tolerance
then
return math.huge
end
return math.sqrt(
(x - origin_x)^2 +
(y - origin_y)^2
)
end

-- UNATTACKABLE TRACKING
unattackable_until = {}
function Is_Unattackable(id)
local until_time = id and unattackable_until[id]
if not until_time then
return false
end
if os.clock() >= until_time then
unattackable_until[id] = nil
return false
end
return true
end
windower.register_event('incoming text', function(original)
if not Start_Engine or not original then
return
end
if string.find(original, '[Domo DEBUG]', 1, true) then
return
end
if not string.find(
original,
'You cannot attack that target',
1,
true
) then
return
end
local target = windower.ffxi.get_mob_by_target('t')
if Debug and Debug.enabled then
local player = windower.ffxi.get_player()
Debug.Log('!!! FFXI REJECTED ATTACK !!!')
Debug.Log('Message: ' .. tostring(original))
Debug.Target('TARGET WHEN ATTACK WAS REJECTED', target)
Debug.State('STATE WHEN ATTACK WAS REJECTED')
Debug.Log(string.format(
'REJECTION STATE | player_status=%s managed=%s locked=%s engage_sent=%s combat_started=%s',
tostring(player and player.status),
tostring(managed_target_id),
tostring(combat_locked_target_id),
tostring(engage_sent_target_id),
tostring(combat_started)
))
end
if not target or not target.id then
return
end
-- A rejected attack against the player or a party member is always
-- invalid, even if a transient status update made combat_started true.
-- Clear that bad lock so Target_Monitor cannot keep retrying /attack on it.
local player = windower.ffxi.get_player()
local is_player_or_party = (player and target.id == player.id)
    or Is_Party_Member(target.id)
    or Is_Player_Pet(target)
if target.id == combat_locked_target_id then
    if is_player_or_party or not combat_started then
        Debug.Target(
            is_player_or_party
                and 'ATTACK REJECTED - INVALID PLAYER/PARTY/PET LOCK - CLEARING'
                or 'ATTACK REJECTED BEFORE COMBAT - CLEARING LOCK',
            target
        )
        unattackable_until[target.id] = os.clock() + 20
        Clear_Combat_Target()
    end
else
    -- A rejection for a different target must not affect the
    -- existing combat lock.
    unattackable_until[target.id] = os.clock() + 20
end
end)

function Is_Targetable_Monster(name)
if not name then
return false
end
local config = targeting or {}
local monsters = config.monsters or {}
local wanted_name = string.lower(name)
for _, monster in ipairs(monsters) do
if type(monster) == 'string'
and wanted_name == string.lower(monster)
then
return true
end
end
return false
end

-- PARTY / TRUST HELPERS
function Is_Party_Member(actor_id)
if not actor_id then
return false
end
local party = windower.ffxi.get_party()
if not party then
return false
end
for _, key in ipairs({'p0', 'p1', 'p2', 'p3', 'p4', 'p5'}) do
local m = party[key]
local id = m and ((m.mob and m.mob.id) or m.id)
if id == actor_id then
return true
end
end
return false
end
function Is_Solo_Leader()
if not settings or settings.assist ~= '' then
return false
end
local party = windower.ffxi.get_party()
if not party then
return true
end
for _, key in ipairs({'p1', 'p2', 'p3', 'p4', 'p5'}) do
local m = party[key]
if m and (not m.mob or not m.mob.is_npc) then
return false
end
end
return true
end
function Get_Party_Claim_Ids()
local ids = {}
local party = windower.ffxi.get_party()
if not party then
return ids
end
local player = windower.ffxi.get_player()
for _, key in ipairs({'p0', 'p1', 'p2', 'p3', 'p4', 'p5'}) do
local m = party[key]
local id = m and ((m.mob and m.mob.id) or m.id)
if id and (not player or id ~= player.id) then
ids[id] = true
end
end
return ids
end

-- PLAYER PET / LUOPAN FILTER
--
-- Windower exposes a player's active pet through pet_index on that
-- player's mob entry. Compare pet_index to the candidate mob's INDEX,
-- not its server ID. This is ownership-based, not name/job-based, so
-- it covers Luopans, wyverns, avatars/spirits, BST pets, automatons,
-- and other active pets when Windower exposes their owner relationship.
--
-- Scan the main party and both alliance parties. Alliance members matter
-- because their pets can appear in the same mob array and must not become
-- autotarget candidates either.
function Is_Player_Pet(mob)
if not mob or not mob.index then
return false
end
local party = windower.ffxi.get_party()
if not party then
return false
end
local owner_slots = {
'p0', 'p1', 'p2', 'p3', 'p4', 'p5',
'a10', 'a11', 'a12', 'a13', 'a14', 'a15',
'a20', 'a21', 'a22', 'a23', 'a24', 'a25',
}
for _, key in ipairs(owner_slots) do
local member = party[key]
if member then
-- member.mob is normally populated for visible members.
-- Fall back to the live mob table when only the member ID
-- is available (for example, after party data refreshes).
local owner_mob = member.mob
if not owner_mob or not owner_mob.pet_index then
local owner_id = (owner_mob and owner_mob.id) or member.id
if owner_id then
local live_owner_mob = windower.ffxi.get_mob_by_id(owner_id)
if live_owner_mob and live_owner_mob.pet_index then
owner_mob = live_owner_mob
end
end
end
local pet_index = owner_mob and owner_mob.pet_index
if pet_index and pet_index > 0 and pet_index == mob.index then
return true
end
end
end
return false
end
-- TARGET LEGITIMACY
function Is_Legitimate_Target(mob, expected_name, party_ids, already_engaged)
if not mob
or Is_Player_Pet(mob)
or not mob.valid_target
or type(mob.hpp) ~= 'number'
or mob.hpp <= 0
then
return false
end
-- Enforce the origin boundary when an origin is configured.
-- Camp Mode leaders may discover targets outside camp (pull range).
if origin_x and not (Camp_Skip_Origin_For_Discovery and Camp_Skip_Origin_For_Discovery()) then
if type(mob.x) ~= 'number'
or type(mob.y) ~= 'number'
or type(mob.z) ~= 'number'
or type(origin_radius) ~= 'number'
then
return false
end
if Origin_Distance(mob.x, mob.y, mob.z) > origin_radius then
return false
end
end
local player = windower.ffxi.get_player()
if (player and mob.id == player.id)
or Is_Party_Member(mob.id)
or Is_Unattackable(mob.id)
then
return false
end
-- Legitimate ownership:
--   * Unclaimed target
--   * Claimed by the player
--   * Claimed by a party member
local ours =
mob.claim_id == 0
or (player and mob.claim_id == player.id)
or (party_ids and mob.claim_id and party_ids[mob.claim_id])
if expected_name then
return string.lower(mob.name or '') ==
string.lower(expected_name) and not not ours
end
if ours then
return true
end
-- Preserve an existing target while the player is engaged.
-- This does not make unrelated targets valid for fresh selection.
if already_engaged
and player
and player.status == 1
then
return true
end
-- Being on the autotarget whitelist does not override claim rules.
return false
end
