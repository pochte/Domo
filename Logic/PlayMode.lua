-- PLAY MODE
-- How much of the hunt Domo runs by itself:
--   Leader     picks targets, walks to them and engages.
--   Follower   assists someone else's target (settings.assist = their name).
--   Semi-Auto  YOU pick targets, walk and engage by hand. Once you are
--              engaged Domo runs the same combat logic as the other modes and
--              may move to keep the fight going. Buffs, cures and the rest of
--              the support logic always run.
-- Job combat logic is shared by all three modes. Only three things differ,
-- and they are gated here: moving, selecting targets, and engaging.
--   Mode_May_Move()           false in Semi-Auto until you are engaged
--   Mode_May_Select_Target()  false in Semi-Auto
--   Mode_May_Engage()         false in Semi-Auto
-- The role is stored per character in settings.semi_auto (Semi-Auto) and
-- settings.assist (Follower: the name to assist, '' for Leader).
Semi_Auto_Available = true

function Semi_Auto_Active()
    return settings and settings.semi_auto and true or false
end

-- 'leader', 'follower' or 'semi'
function Get_Play_Mode()
    if Semi_Auto_Active() then
        return 'semi'
    end

    if settings and (settings.assist or '') ~= '' then
        return 'follower'
    end

    return 'leader'
end

function Is_Engaged()
    local player = windower.ffxi.get_player()

    return player and player.status == 1 and true or false
end

function Mode_May_Select_Target()
    return not Semi_Auto_Active()
end

function Mode_May_Engage()
    return not Semi_Auto_Active()
end

function Mode_May_Move()
    return (not Semi_Auto_Active()) or Is_Engaged()
end

-- A real enemy: a live monster that is not a party member or a player's pet.
function Is_Enemy_Target(target)
    if not target or not target.id then
        return false
    end

    if type(target.hpp) ~= 'number' or target.hpp <= 0 then
        return false
    end

    -- Only monsters; <t> can be a party member or NPC during support casts.
    if target.spawn_type and target.spawn_type ~= 16 then
        return false
    end

    if Is_Party_Member(target.id) or Is_Player_Pet(target) then
        return false
    end

    return true
end

-- Semi-Auto: the player starts every fight. Offensive logic only runs on a
-- mob that is engaged or already claimed by you or your party, so a mob you
-- merely have targeted is never opened on.
function Semi_Auto_Hold_Fire(target)
    if not Semi_Auto_Active() then
        return false
    end

    if not Is_Enemy_Target(target) then
        return false
    end

    if Is_Engaged() then
        return false
    end

    local player = windower.ffxi.get_player()
    local claim = target.claim_id

    if claim and claim ~= 0 and player and (claim == player.id or Is_Party_Member(claim)) then
        return false
    end

    return true
end
