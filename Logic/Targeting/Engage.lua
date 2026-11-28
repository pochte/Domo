-- TARGETENGAGE
-- Starting a fight: ranged pulls, Engage_Target (/attack), and keeping a
-- debuff target selected.
-- Part of the TargetLogic split (see ../TargetLogic.lua). Code below is moved unchanged.

-- RANGED PULL
-- Returns true while a ranged pull is still in progress (caller should wait).
-- Returns false when ranged pull is not applicable or has given up -- caller
-- must fall through to melee Select_Target / Engage_Target.
-- After max tries (or when the pull action is unavailable), we do NOT bench
-- the mob as unattackable; we simply engage in melee instead.
pull_attempts = {}
function Try_Ranged_Pull(mob, distance)
local rp = active_profile and active_profile.ranged_pull
if not rp or not mob or not mob.id then
return false
end
-- Ranged pulls are only for unclaimed enemies.
if mob.claim_id ~= 0 then
return false
end
-- Never attempt to pull invalid, dead, or player-owned targets.
if not mob.valid_target
or not mob.hpp
or mob.hpp <= 0
then
return false
end
if Is_Player_Pet and Is_Player_Pet(mob) then
return false
end
if Is_Unattackable(mob.id) then
return false
end
if not distance or distance > (rp.range or 20) then
return false
end
windower.ffxi.follow(0)
local current = windower.ffxi.get_mob_by_target('t')
if not current or current.id ~= mob.id then
Debug.Target('RANGED PULL SELECT', mob)
Select_Target(mob)
return true
end
if (isBusy or 0) > 0
or isCasting
or (Is_Moving and Is_Moving())
then
return true
end
local now = os.clock()
local info = pull_attempts[mob.id] or {
count = 0,
last = 0
}
local retry = rp.retry or 6
if now - info.last < retry then
return true
end
-- Out of attempts, or pull ability/weapon unavailable: fall through to melee.
-- Do not mark the mob unattackable -- that caused the "stare into space" hang.
if info.count >= (rp.max_tries or 3) then
Debug.Target('RANGED PULL GAVE UP - MELEE ENGAGE', mob)
pull_attempts[mob.id] = nil
return false
end
Debug.Target('RANGED PULL', mob)
windower.send_command('input /ra <t>')
info.count = info.count + 1
info.last = now
pull_attempts[mob.id] = info
isBusy = Action_Delay
return true
end

-- NORMAL FFXI ENGAGE
function Engage_Target(mob)
if Debug.enabled then
local current = windower.ffxi.get_mob_by_target('t')
local player = windower.ffxi.get_player()
Debug.Log(string.format(
'>>> Engage_Target CALLED <<< requested=%s id=%s <t>=%s status=%s managed=%s locked=%s engage_sent=%s combat_started=%s',
tostring(mob and mob.name),
tostring(mob and mob.id),
tostring(current and current.id),
tostring(player and player.status),
tostring(managed_target_id),
tostring(combat_locked_target_id),
tostring(engage_sent_target_id),
tostring(combat_started)
))
end
-- INVALID
if not mob or not mob.id then
Debug.Log('ENGAGE FAILED - INVALID TARGET')
return false
end

-- FOLLOWER HP GATE
-- Followers must never engage a target until the leader has damaged it.
if settings and settings.assist ~= ''
    and (
        type(mob.hpp) ~= 'number'
        or mob.hpp <= 0
        or mob.hpp > 99
    )
then
    Debug.Target('FOLLOWER ENGAGE BLOCKED - TARGET ABOVE 99%', mob)
    return false
end

-- SEMI-AUTO: the player engages by hand.
if Mode_May_Engage and not Mode_May_Engage() then
Debug.Log('ENGAGE SKIPPED - SEMI-AUTO')
return false
end
-- NEVER engage a player-owned pet or Luopan.
if Is_Player_Pet(mob) then
Debug.Target('ENGAGE BLOCKED - PLAYER PET/LUPON', mob)
return false
end
local target_player = windower.ffxi.get_player()
if (target_player and mob.id == target_player.id) or Is_Party_Member(mob.id) then
Debug.Target('ENGAGE BLOCKED - PLAYER/PARTY MEMBER', mob)
return false
end
-- COMBAT ALREADY LOCKED
if combat_locked_target_id then
if combat_locked_target_id == mob.id then
Debug.State('ENGAGE IGNORED - ALREADY LOCKED')
return true
end
Debug.Target('ENGAGE BLOCKED - DIFFERENT COMBAT LOCK', mob)
return false
end
-- Trust recovery blocks new engagements but must not affect
-- an already established combat lock.
if Targeting_Paused() then
Debug.Target('ENGAGE BLOCKED - TRUST RECOVERY', mob)
return false
end
local player = windower.ffxi.get_player()
if not player then
return false
end
-- PLAYER ALREADY ENGAGED
if player.status == 1 then
Debug.State('ENGAGE BLOCKED - PLAYER ALREADY ENGAGED')
return false
end
-- EXACT <t> CHECK
local target = windower.ffxi.get_mob_by_target('t')
if not target or target.id ~= mob.id then
Debug.Log(string.format(
'TARGET MISMATCH requested=%s actual=%s -- RESELECTING',
tostring(mob.id),
tostring(target and target.id)
))
Select_Target(mob)
-- Selection must be confirmed before attempting engagement.
-- The caller must retry after the target actually changes.
return false
end
-- AUTO ENGAGE DISABLED
if active_profile and active_profile.auto_engage == false then
pending_target_id = nil
pending_target_time = 0
windower.ffxi.follow(0)
Debug.State('AUTO ENGAGE DISABLED')
return true
end
-- UNATTACKABLE
if Is_Unattackable(mob.id) then
Debug.Target('BLOCKED - MARKED UNATTACKABLE', mob)
return false
end
-- CLAIMED BY SOMEONE ELSE
local claim_id = mob.claim_id
local party_ids = Get_Party_Claim_Ids()
if claim_id == nil
or (
claim_id ~= 0
and claim_id ~= player.id
and not (party_ids and party_ids[claim_id])
)
then
Debug.Target('ENGAGE BLOCKED - CLAIMED BY SOMEONE ELSE OR UNKNOWN CLAIM', mob)
return false
end
-- CAMP MODE ENGAGEMENT GATE
-- Never blocks an already-locked fight; only denies NEW engagement.
if Camp_Can_Engage and not Camp_Can_Engage() then
Debug.Target('CAMP MODE - ENGAGE DENIED (leader outside camp radius)', mob)
return false
end
-- COMMIT COMBAT
combat_locked_target_id = mob.id
managed_target_id = mob.id
engage_sent_target_id = mob.id
combat_lock_time = os.clock()
combat_started = false
pending_target_id = nil
pending_target_time = 0
windower.ffxi.follow(0)
-- FINAL TARGET SNAPSHOT
local final_target = windower.ffxi.get_mob_by_target('t')
Debug.Target('FINAL MANAGED MOB', mob)
Debug.Target('FINAL <t> BEFORE ATTACK', final_target)
-- SEND /ATTACK ON EXACTLY ONCE
Debug.Log(string.format(
'>>> SENDING /attack on <<< name=%s id=%s index=%s hpp=%s claim=%s dist=%s status=%s managed=%s locked=%s engage_sent=%s <t>=%s',
tostring(mob.name),
tostring(mob.id),
tostring(mob.index),
tostring(mob.hpp),
tostring(mob.claim_id),
type(mob.distance) == 'number'
and string.format('%.2f', math.sqrt(mob.distance))
or 'nil',
tostring(player.status),
tostring(managed_target_id),
tostring(combat_locked_target_id),
tostring(engage_sent_target_id),
tostring(final_target and final_target.id)
))
windower.send_command('input /attack on')
-- LOCK CAMERA ONCE
if not lockon_done then
windower.send_command('input /lockon')
lockon_done = true
end
return true
end

-- DEBUFF-CASTER TARGET FALLBACK (moved from Domo.lua; called by Buff_Tick)
function Ensure_Debuff_Target()
local player = windower.ffxi.get_player()
if not player or not active_profile then
return
end
if not ((active_profile.debuffs or active_profile.magic_burst)
and active_profile.auto_engage == false) then
return
end
-- Never steal the target during a support cast. Buff_Tick calls this only
-- after its busy/casting/pending-cast guards, but keep the guard here too.
if isCasting or (isBusy or 0) > 0 or pending_cast then
return
end
local current = windower.ffxi.get_mob_by_target('t')
local wanted_id = support_return_target_id or combat_locked_target_id or managed_target_id
local wanted = wanted_id and windower.ffxi.get_mob_by_id(wanted_id)
if not wanted or not wanted.valid_target or type(wanted.hpp) ~= 'number' or wanted.hpp <= 0 or Is_Player_Pet(wanted) or Is_Party_Member(wanted.id) or wanted.id == player.id then
wanted_id = combat_locked_target_id or managed_target_id or last_enemy_target_id
wanted = wanted_id and windower.ffxi.get_mob_by_id(wanted_id)
end
if wanted
and wanted.valid_target
and type(wanted.hpp) == 'number'
and wanted.hpp > 0
and not Is_Player_Pet(wanted)
and not Is_Party_Member(wanted.id)
and wanted.id ~= player.id
then
if not current or current.id ~= wanted.id then
Debug.Target('DEBUFF TARGET RESTORE MANAGED ENEMY', wanted)
Select_Target(wanted)
elseif support_return_target_id == wanted.id then
support_return_target_id = nil
end
return
end
-- Fallback for cases where target discovery has not established a managed
-- enemy yet. The battle target is preferable to leaving a player selected.
if not current then
windower.send_command('input /target <bt>')
end
end
