-- CAMPLOGIC
-- Location behaviours for Domo: Free Roam (unchanged) and Camp Mode.
--
-- TargetLogic.lua remains the single authority for targeting, combat locks,
-- engagement, following, pathing and combat monitoring. This module only
-- supplies extra rules and gates that TargetLogic / Domo call.
--
-- Camp position reuses the existing origin_x/y/z + origin_radius +
-- origin_z_tolerance. No competing pathing system is introduced.
--
-- Free Roam must retain existing behaviour. Camp Mode must never block an
-- already-established combat lock.

location_mode = location_mode or 'free'   -- 'free' | 'camp'
emergency_regroup = emergency_regroup or false
local emergency_had_combat = false
local camp_monitor_started = false

local function Say(msg)
    windower.add_to_chat(2, '[Domo] ' .. tostring(msg))
end

local function Is_Leader_Client()
    -- Leader mode: no assist target configured.
    if not settings or settings.assist == nil or settings.assist == '' then
        return true
    end
    return false
end

local function Get_Party_Leader_Mob()
    local party = windower.ffxi.get_party()
    if not party or not party.party1_leader then
        return nil
    end
    return windower.ffxi.get_mob_by_id(party.party1_leader)
end

local function Player_At_Camp(radius_mult)
    radius_mult = radius_mult or 1
    local player = windower.ffxi.get_player()
    if not player then
        return false
    end
    local mob = windower.ffxi.get_mob_by_id(player.id)
    if not mob or type(mob.x) ~= 'number' then
        return false
    end
    if type(origin_x) ~= 'number' or type(origin_radius) ~= 'number' then
        return true
    end
    local dist = Origin_Distance(mob.x, mob.y, mob.z)
    return dist ~= math.huge and dist <= (origin_radius * radius_mult)
end

local function Leader_Within_Camp()
    if Is_Leader_Client() then
        return Player_At_Camp(1)
    end
    local leader = Get_Party_Leader_Mob()
    if not leader or type(leader.x) ~= 'number' then
        -- Cannot see the leader. In normal camp, be conservative and deny
        -- new engagement. In emergency regroup, allow so the group can
        -- fight once they have converged.
        return emergency_regroup and true or false
    end
    if type(origin_x) ~= 'number' or type(origin_radius) ~= 'number' then
        return true
    end
    local dist = Origin_Distance(leader.x, leader.y, leader.z)
    return dist ~= math.huge and dist <= origin_radius
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

function Is_Camp_Mode()
    return location_mode == 'camp'
end

function Is_Emergency_Regroup()
    return emergency_regroup and true or false
end

-- Leader in camp may discover / select targets outside the camp radius so
-- they can pull. Followers and Free Roam keep the normal origin filter.
function Camp_Skip_Origin_For_Discovery()
    if location_mode ~= 'camp' then
        return false
    end
    if emergency_regroup then
        -- During emergency, discovery stays near the temporary camp.
        return false
    end
    return Is_Leader_Client()
end

-- Gate for NEW engagement. Never blocks an existing combat lock.
-- Existing fights must be allowed to finish.
function Camp_Can_Engage()
    if location_mode ~= 'camp' then
        return true
    end
    -- Established combat is never blocked by Camp Mode.
    if combat_locked_target_id and combat_started then
        return true
    end
    if emergency_regroup then
        -- Allow engagement once the leader is within the temporary camp
        -- fight radius (or this client is the leader).
        return Leader_Within_Camp()
    end
    if Is_Leader_Client() then
        -- Leader may engage anywhere; they pull then return.
        return true
    end
    -- Followers: only when the leader is back inside the camp fight radius.
    return Leader_Within_Camp()
end

-- Gate for approaching / following a target that is not yet a locked fight.
-- Does not interrupt movement on an established combat lock.
function Camp_Can_Approach()
    if location_mode ~= 'camp' then
        return true
    end
    if combat_locked_target_id and combat_started then
        return true
    end
    if emergency_regroup then
        return true
    end
    if Is_Leader_Client() then
        return true
    end
    return Leader_Within_Camp()
end

function Set_Location_Mode(mode)
    mode = string.lower(tostring(mode or ''))
    if mode ~= 'free' and mode ~= 'camp' then
        Say('Location mode must be free or camp.')
        return false
    end
    location_mode = mode
    emergency_regroup = false
    emergency_had_combat = false
    if mode == 'camp' then
        if type(origin_x) ~= 'number' then
            Set_Camp()
        else
            Say('Camp Mode ON. Camp at (' ..
                math.floor(origin_x) .. ', ' .. math.floor(origin_y) ..
                ') radius ' .. tostring(origin_radius))
        end
    else
        Say('Free Roam ON.')
    end
    return true
end

function Set_Camp()
    if not Set_Origin then
        Say('Set_Origin unavailable.')
        return false
    end
    local ok = Set_Origin()
    if ok then
        location_mode = 'camp'
        emergency_regroup = false
        emergency_had_combat = false
        Say('Camp saved. Camp Mode ON.')
    end
    return ok
end

-- //domo stuck — emergency recovery when the leader cannot return to camp.
function Camp_Regroup()
    if not Start_Engine then
        Say('Domo is not running.')
        return
    end
    emergency_regroup = true
    emergency_had_combat = (combat_started and combat_locked_target_id) and true or false
    Say('Emergency regroup — converging on leader. New camp will be set when this fight ends.')

    -- Stop pathing to the old camp.
    pathing_to_origin = false
    if windower.ffxi then
        windower.ffxi.run(false)
    end

    if Is_Leader_Client() then
        -- Leader stays put; origin will be updated when the fight ends.
        return
    end

    -- Followers: walk to the party leader (same pattern as party regroup).
    if Mode_May_Move and not Mode_May_Move() then
        Say('Semi-Auto: walk to the leader; Domo will fight once you are there.')
        return
    end
    if party_follow_override then
        return
    end

    local party = windower.ffxi.get_party()
    local me = windower.ffxi.get_player()
    local leader_id = party and party.party1_leader
    if not leader_id or not me or leader_id == me.id then
        return
    end

    coroutine.schedule(function()
        local deadline = os.clock() + 45
        while emergency_regroup and Start_Engine and os.clock() < deadline do
            if combat_locked_target_id and combat_started then
                -- Already fighting; let Follow_Monitor handle range.
                break
            end
            local leader = windower.ffxi.get_mob_by_id(leader_id)
            if leader and type(leader.distance) == 'number' then
                if math.sqrt(leader.distance) > 4 then
                    windower.ffxi.follow(leader.index)
                else
                    windower.ffxi.follow(0)
                    break
                end
            end
            coroutine.sleep(0.5)
        end
    end, 0)
end

-- Called when TargetLogic releases an established combat lock.
-- In emergency regroup, adopt the current position as the new camp.
function Camp_Fight_Complete()
    if not emergency_regroup then
        return
    end
    -- Only complete after genuine combat has been seen and finished.
    if not emergency_had_combat then
        -- No fight was in progress when stuck was issued; still adopt
        -- position if the group has converged and is idle.
        if combat_locked_target_id or combat_started then
            return
        end
    end
    if combat_locked_target_id or combat_started then
        return
    end
    if Set_Origin then
        Set_Origin()
    end
    emergency_regroup = false
    emergency_had_combat = false
    location_mode = 'camp'
    Say('Emergency regroup complete — new camp set. Resuming Camp Mode.')
end

function Camp_Monitor()
    while Start_Engine do
        if location_mode == 'camp' then
            -- Track that combat occurred during emergency so completion is real.
            if emergency_regroup and combat_started and combat_locked_target_id then
                emergency_had_combat = true
            end
            -- Leader return assist: when idle and outside camp, path home.
            -- (Does not fight Path_To_Origin; only nudges when no target.)
            if Is_Leader_Client()
                and not emergency_regroup
                and not combat_locked_target_id
                and not managed_target_id
                and not Targeting_Paused()
                and not party_follow_override
                and Mode_May_Move and Mode_May_Move()
            then
                if not Player_At_Camp(1) and Path_To_Origin then
                    Path_To_Origin()
                end
            end
        end
        coroutine.sleep(1)
    end
    camp_monitor_started = false
end

function Start_Camp_Monitor()
    if camp_monitor_started then
        return
    end
    camp_monitor_started = true
    coroutine.schedule(Camp_Monitor, 0)
end

-- Guard used by Path_To_Origin so the unreachable auto-reanchor does not
-- silently overwrite a Camp Mode camp.
function Camp_Block_Origin_Reanchor()
    return location_mode == 'camp' and not emergency_regroup
end
