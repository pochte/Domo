-- TARGETSTATE
-- Shared target, combat-lock and damage-tracking state. Everything here is a
-- global on purpose: the other targeting modules, Domo.lua (Death_Monitor
-- reads last_damage_*), RestLogic.lua and the Camp/Follower modules all read
-- it.
-- Part of the TargetLogic split (see ../TargetLogic.lua). Code below is moved unchanged.

-- TARGET STATE
managed_target_id = managed_target_id or nil
pending_target_id = pending_target_id or nil
pending_target_time = pending_target_time or 0
-- Preserve the last real enemy target across temporary party-member casts.
-- managed_target_id may be nil when the user manually selected the mob.
last_enemy_target_id = last_enemy_target_id or nil
support_return_target_id = support_return_target_id or nil
local TARGET_SELECT_TIMEOUT = 3
combat_locked_target_id = combat_locked_target_id or nil
engage_sent_target_id = engage_sent_target_id or nil
combat_lock_time = combat_lock_time or nil
-- True only after FFXI has actually reported status == 1
-- for the currently committed combat target.
combat_started = combat_started or false

-- COMBAT DAMAGE WATCH
last_party_damage_to_target = nil
damage_watch_target_id = nil
party_activity = {}
last_self_hit_on_current_target = nil
-- DAMAGE TAKEN / AGGRO QUEUE
-- Globals (not local): Domo.lua's Death_Monitor reads last_damage_source
-- and last_damage_kind, and //domo start calls Reset_Damage_Tracking().
last_damage_source = nil
last_damage_source_id = nil
last_damage_kind = nil
-- os.clock() of the last genuine hit on us; RestLogic.lua reads this.
last_damage_taken_time = nil
aggro_queue = {}
AGGRO_QUEUE_CAP = 10
