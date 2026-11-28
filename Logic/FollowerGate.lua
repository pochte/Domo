-- FOLLOWER GATE
-- HARD SAFETY RULE: a follower does nothing until its leader has started.
--
-- While Domo is in Follower Mode (settings.assist names the leader) and that
-- leader has not started, this character stays completely idle: no targeting,
-- engaging, moving, casting, buffs, cures, resting or weaponskills. It is not
-- a delay or a timer. It lasts exactly until the leader's start state is seen.
--
-- How the leader's start state is detected
--   1. A leader running Domo announces it in party chat:
--        "[Domo] Leader started."   when it starts running as a leader
--        "[Domo] Leader stopped."   when it stops, or becomes a follower
--      A follower that starts without having heard from its leader asks once
--        "[Domo] Waiting for the leader."
--      and a Domo that is not a follower answers with its current state.
--      Only messages sent by the leader (the name in settings.assist) count.
--   2. A leader that is not running Domo never answers. Until a Domo leader
--      has spoken, the leader counts as started the first time it is seen
--      engaged in combat (party member status 1). That is remembered, so the
--      follower keeps working between fights; it is forgotten when this
--      character stops, the leader changes, or the leader leaves the party.
--   3. A leader who is not in your party, or is out of sight, has not started.
--
-- Every follower tick checks Follower_Idle(): the targeting, movement,
-- combat, buff, cure, rest, trust, party, burst and skillchain loops. As a
-- second line of defence, action commands and movement are also refused at
-- the command layer (see Install_Action_Net) while idle.
local PROTO_STARTED = '[Domo] Leader started.'
local PROTO_STOPPED = '[Domo] Leader stopped.'
local PROTO_ASK     = '[Domo] Waiting for the leader.'

local PARTY_KEYS = { 'p0', 'p1', 'p2', 'p3', 'p4', 'p5' }

local leader_state = nil         -- 'started', 'stopped', or nil (no Domo leader has spoken)
local observed_latch = false     -- a leader without Domo has been seen engaged
local state_leader = nil         -- lowercase leader name leader_state belongs to
local bypass_depth = 0
local cache_until, cache_value = 0, false

local function Lower(s)
    return string.lower(tostring(s or ''))
end

local function Follower_Leader_Name()
    local assist = settings and settings.assist or ''

    if assist == '' then
        return nil
    end

    return assist
end

local function Find_Party_Member(name)
    local party = windower.ffxi.get_party()

    if not party then
        return nil, nil
    end

    for _, key in ipairs(PARTY_KEYS) do
        local m = party[key]

        if m and m.name and Lower(m.name) == Lower(name) then
            return m, party
        end
    end

    return nil, party
end

-- The state belongs to one leader; a different leader name starts from nothing.
local function Sync_State_Owner(name)
    local key = Lower(name)

    if state_leader ~= key then
        state_leader = key
        leader_state = nil
        observed_latch = false
        cache_until = 0
    end
end

-- A leader that does not run Domo never announces; seeing it engaged counts
-- as started. Out of sight or not in the party: not started.
local function Leader_Observed_Engaged(name)
    local m = Find_Party_Member(name)

    if not m then
        return false
    end

    local mob = m.mob or (m.id and windower.ffxi.get_mob_by_id(m.id))

    return mob ~= nil and mob.status == 1
end

function Leader_Started()
    local name = Follower_Leader_Name()

    if not name then
        return true
    end

    Sync_State_Owner(name)

    if leader_state == 'started' then
        return true
    elseif leader_state == 'stopped' then
        return false
    end

    -- No Domo leader has spoken. The leader must be in the party, and must
    -- have been seen engaged at least once.
    if not Find_Party_Member(name) then
        observed_latch = false
        return false
    end

    if observed_latch then
        return true
    end

    if Leader_Observed_Engaged(name) then
        observed_latch = true
        return true
    end

    return false
end

-- True while this character is a follower and its leader has not started.
function Follower_Idle()
    if bypass_depth > 0 then
        return false
    end

    if not Follower_Leader_Name() then
        return false
    end

    local now = os.clock()

    if now < cache_until then
        return cache_value
    end

    cache_value = not Leader_Started()
    cache_until = now + 0.2

    return cache_value
end

-- Lets one explicit job (Go Home) use items while a follower is idle.
function Follower_Gate_Bypass(on)
    if on then
        bypass_depth = bypass_depth + 1
    else
        bypass_depth = math.max(0, bypass_depth - 1)
    end
end

-- //domo leaderstate
function Follower_Gate_Report()
    local name = Follower_Leader_Name()

    if not name then
        windower.add_to_chat(2, '[Domo] Not a follower, so there is no leader gate.')
        return
    end

    Sync_State_Owner(name)

    local how = leader_state and ('announced ' .. leader_state)
        or (observed_latch and 'seen engaged (no announcement heard)' or 'no announcement, not seen engaged')

    windower.add_to_chat(2, '[Domo] Leader ' .. name .. ': ' .. how .. '. This character is '
        .. (Follower_Idle() and 'idle.' or 'free to act.'))
end

-- CHAT PROTOCOL
local function In_Party()
    local party = windower.ffxi.get_party()

    return party and (party.party1_count or 1) > 1
end

local function Announce(text)
    if In_Party() then
        windower.send_command('input /p ' .. text)
    end
end

local function Leader_Running()
    return (Start_Engine and not Follower_Leader_Name()) and true or false
end

windower.register_event('chat message', function(message, sender, mode)
    if mode ~= 4 or not message or not sender then
        return
    end

    local text = tostring(message)

    -- Follower side: only the leader's own announcements count.
    local name = Follower_Leader_Name()

    if name and Lower(sender) == Lower(name) then
        Sync_State_Owner(name)

        if text:find(PROTO_STARTED, 1, true) then
            leader_state = 'started'
            cache_until = 0
        elseif text:find(PROTO_STOPPED, 1, true) then
            leader_state = 'stopped'
            cache_until = 0
        end
    end

    -- Leader side: answer a follower that asks.
    if not name and text:find(PROTO_ASK, 1, true) then
        Announce(Leader_Running() and PROTO_STARTED or PROTO_STOPPED)
    end
end)

-- Watches this character's own state: announces start/stop as a leader and
-- asks for the leader's state as a follower. Runs from addon load.
local last_leader_running = false
local last_follower_running = false
local asked_for = nil
local last_idle = nil

local function Gate_Tick()
    -- Leader side: announce transitions only.
    local running = Leader_Running()

    if running ~= last_leader_running then
        last_leader_running = running
        Announce(running and PROTO_STARTED or PROTO_STOPPED)
    end

    -- Follower side.
    local name = Follower_Leader_Name()
    local follower_running = (name and Start_Engine) and true or false

    if follower_running and not last_follower_running then
        asked_for = nil
    end

    last_follower_running = follower_running

    if follower_running then
        Sync_State_Owner(name)

        if leader_state == nil and asked_for ~= Lower(name) then
            asked_for = Lower(name)
            Announce(PROTO_ASK)
        end

        local idle = Follower_Idle()

        if idle ~= last_idle then
            last_idle = idle

            if idle then
                -- Stop anything already in motion, then wait.
                windower.ffxi.follow(0)
                windower.ffxi.run(false)
                windower.add_to_chat(2, '[Domo] Waiting for ' .. name .. ' to start.')
            else
                windower.add_to_chat(2, '[Domo] ' .. name .. ' has started. Following along.')
            end
        end
    else
        last_idle = nil
        observed_latch = false
    end
end

coroutine.schedule(function()
    while true do
        pcall(Gate_Tick)
        coroutine.sleep(0.5)
    end
end, 1)

-- SECOND LINE OF DEFENCE
-- Every action in Domo is a chat command (/ma, /ja, /ws, /attack, /item,
-- /target, ...) or a movement call. While a follower is idle none of those
-- may go out, whatever code asked for them. Chat (/p, /t, /echo) and stop
-- commands are never blocked.
local BLOCKED_VERBS = {
    ma = true, magic = true, ja = true, jobability = true, ws = true,
    weaponskill = true, ra = true, range = true, attack = true, item = true,
    target = true, assist = true, lockon = true, follow = true, pet = true,
    heal = true, shoot = true,
}

local function Blocks_Command(command)
    local text = Lower(command):gsub('^%s+', ''):gsub('^input%s+', '')
    local verb = text:match('^/(%a+)')

    return verb ~= nil and BLOCKED_VERBS[verb] == true
end

local function Install_Action_Net()
    if Follower_Gate_Net_Installed then
        return
    end

    local raw_send = windower.send_command

    windower.send_command = function(command, ...)
        if Blocks_Command(tostring(command or '')) and Follower_Idle() then
            return
        end

        return raw_send(command, ...)
    end

    if windower.chat and windower.chat.input then
        local raw_input = windower.chat.input

        windower.chat.input = function(command, ...)
            if Blocks_Command(tostring(command or '')) and Follower_Idle() then
                return
            end

            return raw_input(command, ...)
        end
    end

    local ffxi = windower.ffxi

    if ffxi.follow then
        local raw_follow = ffxi.follow

        ffxi.follow = function(index, ...)
            if index and index ~= 0 and index ~= -1 and Follower_Idle() then
                return
            end

            return raw_follow(index, ...)
        end
    end

    if ffxi.run then
        local raw_run = ffxi.run

        ffxi.run = function(a, ...)
            if a and Follower_Idle() then
                return
            end

            return raw_run(a, ...)
        end
    end

    Follower_Gate_Net_Installed = true
end

Install_Action_Net()
