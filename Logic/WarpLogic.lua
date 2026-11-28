-- WARP LOGIC
-- Domo's own warp-item handling for Go Home. It is self-contained: it uses
-- only Windower's API and resources. It does not need GearSwap, and it does
-- not use any other framework's aliases, commands or files. Any equipment
-- management a GearSwap setup does stays GearSwap's business; Domo simply
-- equips what it needs through the game's own /equip command, and if
-- something swaps the item away while it waits, it equips it again.
--
-- Supported items
--   Warp Ring                  warps to your home point          (ring)
--   Scroll of Instant Warp     warps to your home point          (scroll)
--   Dimensional Ring (Holla)   teleports to the Crag of Holla    (ring)
--   Dimensional Ring (Dem)     teleports to the Crag of Dem      (ring)
--   Dimensional Ring (Mea)     teleports to the Crag of Mea      (ring)
--   Tavnazian Ring             teleports to Tavnazian Safehold   (ring)
-- (In game data the rings are named "Dim. Ring (Holla)" and so on.)
-- Items set in party_commands.go_home_items (settings.lua) are tried first in
-- the order given; any supported item missing from that list is added after
-- it, home-point items before the others.
--
-- For each item, in order, Warp_Home():
--   1. looks for it in inventory, wardrobes, satchel, sack and case
--   2. checks it can work: charges left, recharge timer, game restrictions
--   3. moves it to inventory if it is in a satchel/sack/case
--   4. equips rings (and other equipment) and waits out the equip delay
--   5. uses it and waits for the zone change
-- If one fails, the next is tried. When none work it says exactly why for
-- each item.
local extdata_ok, extdata = pcall(require, 'extdata')

local WARP_BAGS = {
    'inventory', 'wardrobe', 'wardrobe2', 'wardrobe3', 'wardrobe4',
    'wardrobe5', 'wardrobe6', 'wardrobe7', 'wardrobe8', 'satchel', 'sack', 'case',
}

local BAG_ID = { satchel = 5, sack = 6, case = 7 }

-- The six supported items. delay/use/recharge are the game's own values
-- (equip delay, use time, recharge in seconds); they are replaced by the
-- values in Windower's item data when those are available.
local BUILT_IN = {
    { name = 'Warp Ring',         label = 'Warp Ring',                  slot = 'ring2', home = true,
      where = 'your home point', delay = 8, use = 8, recharge = 600 },
    { name = 'Instant Warp',      label = 'Scroll of Instant Warp',     home = true,
      where = 'your home point', use = 10 },
    { name = 'Dim. Ring (Holla)', label = 'Dimensional Ring (Holla)',   slot = 'ring2', home = false,
      where = 'the Crag of Holla (La Theine Plateau)', delay = 8, use = 8, recharge = 600 },
    { name = 'Dim. Ring (Dem)',   label = 'Dimensional Ring (Dem)',     slot = 'ring2', home = false,
      where = 'the Crag of Dem (Konschtat Highlands)', delay = 8, use = 8, recharge = 600 },
    { name = 'Dim. Ring (Mea)',   label = 'Dimensional Ring (Mea)',     slot = 'ring2', home = false,
      where = 'the Crag of Mea (Tahrongi Canyon)', delay = 8, use = 8, recharge = 600 },
    { name = 'Tavnazian Ring',    label = 'Tavnazian Ring',             slot = 'ring2', home = false,
      where = 'Tavnazian Safehold', delay = 30, use = 8, recharge = 86400 },
}

-- Debuffs that stop item use. Waited out for a short while before giving up.
local BLOCKING_BUFFS = { 'sleep', 'petrification', 'terror', 'stun', 'charm', 'lullaby' }
local DEAD_STATUS = { [2] = true, [3] = true }
local BUSY_STATUS = { [4] = 'in a cutscene', [44] = 'crafting', [85] = 'mounted' }

local warp_zone_seen = false

windower.register_event('zone change', function()
    warp_zone_seen = true
end)

local function Say(msg)
    windower.add_to_chat(2, '[Domo] ' .. msg)
end

local function Item_Id_By_Name(name)
    local it = res.items:with('en', name)

    return it and it.id or nil
end

-- The ordered list of items to try (see the header).
function Warp_Item_List()
    local list, seen = {}, {}

    local function add(spec)
        local key = string.lower(spec.name)

        if seen[key] then
            return
        end

        seen[key] = true

        -- Fill in what a configured entry leaves out from the built-in one.
        for _, b in ipairs(BUILT_IN) do
            if string.lower(b.name) == key then
                for k, v in pairs(b) do
                    if spec[k] == nil then
                        spec[k] = v
                    end
                end
            end
        end

        spec.label = spec.label or spec.name
        list[#list + 1] = spec
    end

    local configured = (party_commands or {}).go_home_items

    if type(configured) == 'table' then
        for _, c in ipairs(configured) do
            if type(c) == 'table' and c.name then
                local copy = {}

                for k, v in pairs(c) do
                    copy[k] = v
                end

                if copy.home == nil then
                    copy.home = true
                end

                add(copy)
            end
        end
    end

    for _, home in ipairs({ true, false }) do
        for _, b in ipairs(BUILT_IN) do
            if b.home == home then
                local copy = {}

                for k, v in pairs(b) do
                    copy[k] = v
                end

                add(copy)
            end
        end
    end

    return list
end

-- Timings from the game's own item data, falling back to the table above.
local function Timings(spec, id)
    local it = id and res.items[id]

    return {
        delay = (it and it.cast_delay) or spec.delay or 0,
        use = (it and it.cast_time) or spec.use or 10,
        recharge = (it and it.recast_delay) or spec.recharge,
    }
end

local function Find_Item(item_id)
    local items = windower.ffxi.get_items()

    if not items then
        return nil
    end

    for _, bag in ipairs(WARP_BAGS) do
        local t = items[bag]

        if type(t) == 'table' then
            for i = 1, (t.max or 80) do
                local e = t[i]

                if e and e.id == item_id then
                    return bag, i, e
                end
            end
        end
    end

    return nil
end

local function Decode(entry)
    if not extdata_ok or not entry then
        return nil
    end

    local ok, ed = pcall(extdata.decode, entry)

    if ok and type(ed) == 'table' then
        return ed
    end

    return nil
end

-- Seconds until an enchanted item can be used again, or nil when unknown.
-- Windower's extdata reports the time as a timestamp; which clock it is
-- based on differs between versions, so both are tried and only a result
-- that makes sense (0 to 24 hours ahead) is believed.
local VANA_EPOCH_OFFSET = 1009810800

local function Recharge_Remaining(ed)
    local stamp = ed and tonumber(ed.next_use_time)

    if not stamp or stamp <= 0 then
        return 0
    end

    local now = os.time()

    for _, remaining in ipairs({ stamp - now, stamp - (now - VANA_EPOCH_OFFSET) }) do
        if remaining > 0 and remaining <= 90000 then
            return remaining
        end

        if remaining <= 0 and remaining > -90000 then
            return 0
        end
    end

    return nil
end

local function Minutes(seconds)
    if seconds >= 3600 then
        return string.format('%.1f hours', seconds / 3600)
    end

    return string.format('%d min', math.ceil(seconds / 60))
end

-- Where the item is and whether it can work, without touching anything.
-- state: 'ready' | 'unknown' (not in game data) | 'missing' | 'empty' | 'recharging'
local function Probe(spec)
    local result = { spec = spec, state = 'unknown', note = 'not found in the game data' }
    local id = Item_Id_By_Name(spec.name)

    if not id then
        return result
    end

    result.id = id
    result.timing = Timings(spec, id)

    local bag, index, entry = Find_Item(id)

    if not bag then
        result.state, result.note = 'missing', 'not in your inventory, wardrobes, satchel, sack or case'
        return result
    end

    result.bag, result.index, result.entry = bag, index, entry
    result.equipped = entry and entry.status == 5

    local ed = Decode(entry)

    if spec.slot and ed then
        if ed.charges_remaining ~= nil and ed.charges_remaining <= 0 then
            result.state, result.note = 'empty', 'no charges left'
            return result
        end

        local remaining = Recharge_Remaining(ed)

        if remaining and remaining > 0 then
            result.state = 'recharging'
            result.note = 'recharging, ready in about ' .. Minutes(remaining)
            return result
        end
    end

    result.state = 'ready'
    result.note = 'in ' .. bag .. (result.equipped and ' (equipped)' or '')

    return result
end

-- What would stop any item being used right now, or nil.
local function Blocked_Reason()
    local player = windower.ffxi.get_player()

    if not player then
        return 'not logged in'
    end

    if (player.vitals and player.vitals.hp and player.vitals.hp <= 0) or DEAD_STATUS[player.status] then
        return 'you are dead'
    end

    if BUSY_STATUS[player.status] then
        return 'you are ' .. BUSY_STATUS[player.status]
    end

    for _, buff_id in ipairs(player.buffs or {}) do
        local b = res.buffs[buff_id]
        local name = b and string.lower(b.en or '')

        for _, blocked in ipairs(BLOCKING_BUFFS) do
            if name == blocked or (name and name:find(blocked, 1, true) == 1) then
                return 'you are affected by ' .. b.en
            end
        end
    end

    return nil
end

-- A temporary debuff may wear off: wait a little before calling it a failure.
local function Wait_Until_Unblocked(cancelled)
    local deadline = os.clock() + 20
    local reason = Blocked_Reason()

    while reason and os.clock() < deadline and not cancelled() do
        if reason == 'you are dead' then
            return reason
        end

        coroutine.sleep(0.5)
        reason = Blocked_Reason()
    end

    return reason
end

local function Wait_For_Zone(seconds, cancelled)
    local deadline = os.clock() + seconds

    while os.clock() < deadline and not cancelled() do
        if warp_zone_seen then
            return true
        end

        coroutine.sleep(0.5)
    end

    return warp_zone_seen
end

-- Moves an item out of a satchel, sack or case into inventory.
local function Move_To_Inventory(probe, cancelled)
    local id, bag, index = probe.id, probe.bag, probe.index

    pcall(function()
        packets.inject(packets.new('outgoing', 0x029, {
            ['Count'] = 1,
            ['Bag'] = BAG_ID[bag],
            ['Target Bag'] = 0,
            ['Current Index'] = index,
            ['Target Index'] = 0x52,
        }))
    end)

    for _ = 1, 6 do
        if cancelled() then
            return false
        end

        coroutine.sleep(1)

        local now_bag, now_index, entry = Find_Item(id)

        if now_bag and not BAG_ID[now_bag] then
            probe.bag, probe.index, probe.entry = now_bag, now_index, entry
            return true
        end
    end

    return false
end

-- Tries one item. Returns 'zoned', 'cancelled', or a short reason it failed.
local function Try_Item(spec, cancelled, say)
    local probe = Probe(spec)

    if probe.state ~= 'ready' then
        return probe.note
    end

    local timing = probe.timing

    -- Scrolls and equipment must be in inventory (equipment may also be worn
    -- from a wardrobe).
    if BAG_ID[probe.bag] then
        say('Moving ' .. spec.label .. ' to your inventory...')

        if not Move_To_Inventory(probe, cancelled) then
            return cancelled() and 'cancelled' or 'could not move it into your inventory (is it full?)'
        end
    elseif not spec.slot and probe.bag ~= 'inventory' then
        return 'it has to be in your inventory'
    end

    if spec.slot then
        local equipped = probe.entry and probe.entry.status == 5

        if not equipped then
            windower.send_command('input /equip ' .. spec.slot .. ' "' .. spec.name .. '"')
            coroutine.sleep(2)
        end

        local started = os.clock()
        local limit = (timing.delay or 0) + 14
        local re_equips = 0
        local ready = false
        local last_note = 'it never became usable'

        while not cancelled() and os.clock() - started < limit do
            local bag, _, entry = Find_Item(probe.id)

            -- Something (another addon, GearSwap, a macro) swapped it away:
            -- put it back, a few times at most.
            if bag and entry and entry.status ~= 5 and re_equips < 3 then
                re_equips = re_equips + 1
                windower.send_command('input /equip ' .. spec.slot .. ' "' .. spec.name .. '"')
                coroutine.sleep(2)
            else
                local ed = Decode(entry)

                if ed and ed.charges_remaining ~= nil and ed.charges_remaining <= 0 then
                    return 'no charges left'
                end

                if ed and ed.usable == true then
                    ready = true
                    break
                end

                if ed and ed.usable == false then
                    local remaining = Recharge_Remaining(ed)

                    if remaining and remaining > 0 then
                        last_note = 'recharging, ready in about ' .. Minutes(remaining)
                    end
                end

                -- No extdata to ask: trust the game's equip delay.
                if not ed and os.clock() - started >= (timing.delay or 0) + 2 then
                    ready = true
                    break
                end

                coroutine.sleep(1)
            end
        end

        if cancelled() then
            return 'cancelled'
        end

        if not ready then
            return last_note
        end
    end

    if not spec.home then
        say(spec.label .. ' takes you to ' .. spec.where .. ', not to your home point.')
    end

    say('Using ' .. spec.label .. '...')
    warp_zone_seen = false
    windower.send_command('input /item "' .. spec.name .. '" <me>')

    if Wait_For_Zone((timing.use or 10) + 15, cancelled) then
        return 'zoned'
    end

    if cancelled() then
        return 'cancelled'
    end

    return 'no zone change after using it (not usable here, interrupted, or still recharging)'
end

-- Runs the whole sequence. opts:
--   cancelled()  true to stop (Go Home was cancelled)
--   say(msg)     where messages go (defaults to chat)
-- Returns true when the player zoned, or false and a list of
-- { label, reason } for everything that was tried.
function Warp_Home(opts)
    opts = opts or {}

    local cancelled = opts.cancelled or function() return false end
    local say = opts.say or Say
    local report = {}

    -- Go Home is an explicit order: it works even while a follower waits for
    -- its leader (see FollowerGate.lua).
    if Follower_Gate_Bypass then
        Follower_Gate_Bypass(true)
    end

    local ok, outcome = pcall(function()
        local blocked = Wait_Until_Unblocked(cancelled)

        if blocked then
            report[#report + 1] = { label = 'Any item', reason = 'cannot use items right now: ' .. blocked }
            say('Cannot use any warp item right now: ' .. blocked .. '.')
            return false
        end

        local player = windower.ffxi.get_player()

        -- Stand up if resting; items cannot be used from the rest position.
        if player and player.status == 33 then
            windower.send_command('input /heal off')
            coroutine.sleep(2)
        end

        for _, spec in ipairs(Warp_Item_List()) do
            if cancelled() then
                return false
            end

            local result = Try_Item(spec, cancelled, say)

            if result == 'zoned' then
                return true
            elseif result == 'cancelled' then
                return false
            end

            report[#report + 1] = { label = spec.label, reason = result }
            say(spec.label .. ': ' .. result .. '.')
        end

        return false
    end)

    if Follower_Gate_Bypass then
        Follower_Gate_Bypass(false)
    end

    if not ok then
        report[#report + 1] = { label = 'Warp', reason = 'error: ' .. tostring(outcome) }
        return false, report
    end

    return outcome, report
end

-- //domo warpcheck: shows what Go Home would find, without using anything.
function Warp_Report()
    Say('Go Home items, in the order they are tried:')

    local any = false

    for _, spec in ipairs(Warp_Item_List()) do
        local probe = Probe(spec)
        local dest = spec.home and 'home point' or ('NOT home: ' .. tostring(spec.where))

        Say(string.format('  %s [%s]: %s', spec.label, dest,
            probe.state == 'ready' and ('ready, ' .. probe.note) or probe.note))

        if probe.state == 'ready' then
            any = true
        end
    end

    local blocked = Blocked_Reason()

    if blocked then
        Say('Right now nothing can be used: ' .. blocked .. '.')
    elseif not any then
        Say('No usable warp item was found.')
    end
end
