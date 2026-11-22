-- LEADER LOGIC
-- Works out who to follow for //domo follower (and the Follower button).
-- No name given, it tries these in order:
--   1. the party leader, as the game reports it
--   2. the player who invited you (remembered when the invite arrives, so
--      Domo has to be loaded by then)
--   3. the player you currently have targeted
--   4. otherwise it gives up with an error
-- //domo follower <t> (or "t") skips straight to the target.
local PARTY_KEYS = { 'p0', 'p1', 'p2', 'p3', 'p4', 'p5' }
local last_inviter = nil

local function Lower(s)
    return string.lower(tostring(s or ''))
end

-- INVITES
-- The chat line ("Name invites you to join a party.") is the main source;
-- the invite packet is a second source in case the text is ever filtered.
windower.register_event('incoming text', function(original)
    local text = tostring(original or '')
    local name = text:match('(%a+)%s+invites you to join')

    if name and not text:find('alliance', 1, true) then
        last_inviter = name
    end
end)

windower.register_event('incoming chunk', function(id, data)
    if id ~= 0x0DC then
        return
    end

    local ok, p = pcall(packets.parse, 'incoming', data)

    if not ok or type(p) ~= 'table' then
        return
    end

    for _, field in ipairs({ 'Inviter Name', 'Inviter', 'Name' }) do
        local value = p[field]

        if type(value) == 'string' then
            local name = value:match('^%a+')

            if name then
                last_inviter = name
                return
            end
        end
    end
end)

-- True when you lead the party, or are not in one. Only the real party
-- leader can summon trusts or invite players, so the UI and the trust swap
-- commands both use this.
function Is_Party_Leader()
    local party = windower.ffxi.get_party()
    local me = windower.ffxi.get_player()

    if not party or not me then
        return false
    end

    return party.party1_leader == nil or party.party1_leader == me.id
end

-- DETECTION
local function In_Party(name)
    local party = windower.ffxi.get_party()

    if not party then
        return false
    end

    for _, key in ipairs(PARTY_KEYS) do
        local m = party[key]

        if m and m.name and Lower(m.name) == Lower(name) then
            return true
        end
    end

    return false
end

-- The leader's name, or nil. Second return is 'self' when you are the leader.
local function Party_Leader_Name()
    local party = windower.ffxi.get_party()
    local me = windower.ffxi.get_player()

    if not party then
        return nil
    end

    local leader_id = party.party1_leader

    if leader_id and me and leader_id == me.id then
        return nil, 'self'
    end

    for _, key in ipairs(PARTY_KEYS) do
        local m = party[key]

        if m and m.name then
            -- m.mob is nil for members who are out of range, so match on
            -- the member's own id as well.
            if leader_id and ((m.mob and m.mob.id == leader_id) or m.id == leader_id) then
                return m.name
            end

            if m.is_leader or m.leader then
                return m.name
            end
        end
    end

    -- Last resort: the leader may still be a known entity even though the
    -- party list will not link it.
    if leader_id then
        local mob = windower.ffxi.get_mob_by_id(leader_id)

        if mob and mob.name and not mob.is_npc then
            return mob.name
        end
    end

    return nil
end

local function Target_Player_Name()
    local me = windower.ffxi.get_player()
    local t = windower.ffxi.get_mob_by_target('t')

    if t and t.name and not t.is_npc and not (me and t.id == me.id) then
        return t.name
    end

    return nil
end

-- Returns name, how. With no name: nil, 'self' (you are the leader) or nil.
function Resolve_Follow_Name(target_only)
    if not target_only then
        local leader, why = Party_Leader_Name()

        if leader then
            return leader, 'party leader'
        end

        if why == 'self' then
            return nil, 'self'
        end

        local me = windower.ffxi.get_player()

        if last_inviter
            and not (me and Lower(me.name) == Lower(last_inviter))
            and In_Party(last_inviter)
        then
            return last_inviter, 'invited you'
        end
    end

    local target = Target_Player_Name()

    if target then
        return target, 'your target'
    end

    return nil
end
