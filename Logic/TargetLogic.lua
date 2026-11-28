-- TARGETLOGIC
-- THE single authority for choosing, selecting and managing targets.
-- Owns: target discovery/filtering, party-claim priority, pet/Luopan
-- exclusion, combat lock, engage/retry, origin + pathing, follow,
-- ranged pulls, Target_Monitor/Targeting/Follow_Monitor, incoming
-- damage tracking, the aggro queue, and Engagement_Sync().
-- Domo.lua only schedules the coroutines and reads last_damage_* for
-- Death_Monitor. All debug logic lives in Debug.lua (loaded by Domo.lua
-- before this file); nothing debug-related is defined here.
--
-- COMBAT: Once engaged (status == 1), keep the target lock until
-- combat ends. Never retarget during an active fight.
--
-- PRE-ENGAGE: Follow committed targets until in range.
--
-- TRUSTS: Finish the current fight, then pause new targeting until
-- TrustLogic.lua confirms all tracked trusts are alive.
--
-- This file is now only the loader. The code lives in Logic/Targeting/:
--   State.lua          Shared target, combat-lock and damage-tracking state
--   Core.lua           Small shared helpers
--   Origin.lua         The hunting origin
--   Selection.lua      Choosing and selecting a target
--   Engage.lua         Starting a fight
--   Follow.lua         Movement and facing
--   CombatLock.lua     The combat lock and what feeds it
--   Combat.lua         Combat()
--   TargetMonitor.lua  Target_Monitor()
--   Targeting.lua      Targeting()
-- Everything is global (as before), so load order does not matter except
-- that State.lua comes first.

dofile(windower.addon_path .. 'Logic/Targeting/State.lua')
dofile(windower.addon_path .. 'Logic/Targeting/Core.lua')
dofile(windower.addon_path .. 'Logic/Targeting/Origin.lua')
dofile(windower.addon_path .. 'Logic/Targeting/Selection.lua')
dofile(windower.addon_path .. 'Logic/Targeting/Engage.lua')
dofile(windower.addon_path .. 'Logic/Targeting/Follow.lua')
dofile(windower.addon_path .. 'Logic/Targeting/CombatLock.lua')
dofile(windower.addon_path .. 'Logic/Targeting/Combat.lua')
dofile(windower.addon_path .. 'Logic/Targeting/TargetMonitor.lua')
dofile(windower.addon_path .. 'Logic/Targeting/Targeting.lua')
