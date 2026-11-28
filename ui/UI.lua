-- UI
-- A clickable button panel drawn with the same assets as XivBar (the dark
-- pill, the hover glow, the frame pieces), kept in ui/assets.
--
-- Three tabs:
--   Controls      what you use while playing: party commands, your trusts,
--                 toggles, modes and targeting.
--   Party Trusts  Party Trust Control: ask the party leader to summon or
--                 dismiss any trust (anyone in the party may ask).
--   Settings      Domo itself: skin, radius, show, debug, save, reload and
--                 who may use party-chat commands.
-- The "-" in the corner minimizes the panel to its title and status; the x
-- hides it. Click the status ("STOPPED" / "RUNNING") to start or stop this
-- character. Section headers collapse when clicked.
--
-- Buttons that cycle (Role, Nukes, Skillchain, Skin) move to the next option
-- on every left click; right-click does nothing.
-- Buttons that only the real party leader can use are dimmed and greyed when
-- you are not the leader; hover them to see why.
-- Hover any button or tab for a description (a floating tooltip).
--
--   //domo ui                      show / hide the panel
--   //domo ui reset                default spot, size and skin
--   //domo ui skin ffxi|ffxiv      pick a skin from chat
-- Drag it by grabbing it anywhere. Mouse wheel over it resizes it.
-- Position, size, skin, tab, collapsed sections and shown/hidden are
-- remembered in data/ui_pos.txt.
local texts = require('texts')
local images = require('images')

-- LAYOUT (all numbers are at scale 1.0)
-- Wider panel + taller rows so title/status/tabs/buttons do not overlap.
local BASE_W = 320
local TITLE_X, TITLE_Y, TITLE_H = 12, 8, 26
local STRIP_Y, STRIP_W, STRIP_H = 36, 296, 8
local HEADER_H, HEADER_GAP, SECTION_GAP = 18, 6, 6
local TAB_H, TAB_W, TAB_GAP = 22, 72, 4   -- four short-name tabs fit BASE_W
local MIN_H = 58                  -- height when minimized
local BTN_W, BTN_H = 142, 22
local COL_X = { 12, 166 }
local ROW_Y0, ROW_STEP = 58, 28
local COLS = 2
-- Title-row hit targets (from right edge of panel, scale 1.0)
local CLOSE_X, MIN_X, STATUS_RIGHT = 22, 42, 52
-- Party slots: dismiss (up to 5) + names Domo has seen summoned.
local PERSONAL_TRUST_SLOTS, PARTY_TRUST_SLOTS = 5, 16
local FOOD_SLOTS = 20               -- inventory food buttons on the Food tab
local CONFIRM_SECONDS = 4         -- Go Home needs a second click inside this time
local DEFAULT_POS = { x = 40, y = 300 }
local DEFAULT_ICON_POS = { x = 10, y = 200 }
local ICON_SIZE = 48                  -- on-screen size of the Domo launcher icon
local DRAG_THRESHOLD = 4
local TIP_DELAY, TIP_WRAP, TIP_SIZE = 0.35, 38, 11

-- Short tab labels so four tabs fit without stacking on each other.
local TABS = { 'Controls', 'Trusts', 'Food', 'Settings' }
local TAB_TIPS = {
    'Everyday controls for this character and the party.',
    'Party Trust Control: ask the party leader to summon or dismiss trusts.',
    'Pick a food from inventory; Domo keeps eating it until you change or turn food off.',
    'Domo settings: skin, UI scale, hunting radius, debug, save, reload and permissions.',
}

-- Frame pieces. FFXIV's pieces have soft edges, so they hang slightly
-- outside the panel; FFXI's sit exactly on it.
local SKINS = {
    { name = 'FFXI',  dir = 'ffxi',  top_h = 10, bottom_h = 8,  top_y = 0,  overhang = 0 },
    { name = 'FFXIV', dir = 'ffxiv', top_h = 21, bottom_h = 21, top_y = -7, overhang = 7 },
}

-- Where the visible part sits inside each texture (pixels), so a pill can
-- be sized by what you see rather than by the file's transparent padding.
local PILL = { visw = 208, vish = 16, imgw = 256, imgh = 128 }   -- BarBG.png
local FILL = { visw = 204, vish = 16, imgw = 204, imgh = 128 }   -- Bar.png

local FALLBACK_PHRASES = {
    start = 'start', stop = 'stop', hold = 'hold', resume = 'resume',
    regroup = 'regroup', reset = 'reset', rebuff = 'rebuff', tnl = 'tnl',
    go_home = 'go home',
}

-- HELPERS
local function Run(cmdline)
    windower.send_command('Domo ' .. cmdline)
end

-- Reads a game/Domo global without ever throwing.
local function Safe(fn)
    local ok, value = pcall(fn)

    return ok and value or nil
end

-- True when you can do leader-only things: you lead the party, or are solo.
-- (Is_Party_Leader lives in LeaderLogic.lua.)
local function Is_Leader()
    if not Is_Party_Leader then
        return true
    end

    local ok, value = pcall(Is_Party_Leader)

    if ok then
        return value and true or false
    end

    return true
end

local function On_Off(command, get)
    return {
        toggle = command,
        active = function() return Safe(get) and true or false end,
    }
end

local function Target_Player_Name()
    local t = windower.ffxi.get_mob_by_target('t')

    if t and t.name and not t.is_npc then
        return t.name
    end

    return nil
end

-- Runs fn(name) with the targeted player's name, or says what to do.
local function With_Target(what, fn)
    return function()
        local name = Target_Player_Name()

        if name then
            fn(name)
        else
            windower.add_to_chat(167, '[Domo] Target a player first, then ' .. what .. '.')
        end
    end
end

local function Radius()
    return tonumber(Safe(function() return origin_radius end)) or 10
end

local function Bump_Radius(delta)
    return function()
        Run('range ' .. math.max(1, Radius() + delta))
    end
end

local function Radius_Tip(delta)
    return function()
        return 'Radius ' .. Radius() .. ' yalms. Click: hunt ' .. math.abs(delta)
            .. (delta > 0 and ' farther.' or ' closer.')
    end
end

-- Bump_UI_Scale is defined after Layout/Save_Pos (see bottom of file).

local function Trust_Phrase(kind)
    return (Party_Phrase_Text and Party_Phrase_Text('trust_' .. kind)) or ('trust ' .. kind)
end

-- Trusts currently standing in your party (NPC members, not you).
local function Trusts_In_Party()
    local out = {}
    local party = windower.ffxi.get_party()

    if party then
        for _, key in ipairs({ 'p1', 'p2', 'p3', 'p4', 'p5' }) do
            local m = party[key]

            if m and m.name and m.mob and m.mob.is_npc then
                out[#out + 1] = m.name
            end
        end
    end

    return out
end

-- STATE (declared up here because buttons read and change it)
local pos = { x = DEFAULT_POS.x, y = DEFAULT_POS.y }
local scale = 1.20                  -- default ~20% larger so labels do not overlap
local shown = true
local current_tab = 1
local minimized = false
local skin_index = 1
local collapsed = {}
local Apply_Skin                  -- defined further down

-- CYCLE BUTTONS
-- One button, several options: every left click moves to the next option
-- that is available. Options are { key, label, run, available }.
local function Cycle_Label(c)
    local current = Safe(c.get)

    for _, o in ipairs(c.options) do
        if o.key == current then
            return o.label
        end
    end

    return tostring(current or '?')
end

local function Cycle_Button(prefix, tip, options, get)
    local c = { options = options, get = get }

    return {
        cycle = c,
        tip = tip,
        label = function() return prefix .. ': ' .. Cycle_Label(c) end,
    }
end

local function Advance_Cycle(c)
    local current = Safe(c.get)
    local n, start = #c.options, 0

    for i, o in ipairs(c.options) do
        if o.key == current then
            start = i
        end
    end

    for step = 1, n do
        local o = c.options[(start - 1 + step) % n + 1]

        if o.key == current then
            break
        end

        if (not o.available) or Safe(o.available) then
            o.run()
            return
        end
    end

    windower.add_to_chat(167, '[Domo] No other option is available for that right now.')
end

-- Order: Semi-Auto -> Leader -> Follower (Follower skipped when solo / no one to follow).
-- Short labels so "Mode: Leader" fits the button without clipping.
local ROLE_CYCLE = Cycle_Button('Mode', 'Click to change: Semi-Auto, Leader, or Follower.', {
    { key = 'semi',     label = 'Semi', run = function() Run('semiauto') end,
      available = function() return Semi_Auto_Available ~= false end },
    { key = 'leader',   label = 'Leader', run = function() Run('leader') end },
    { key = 'follower', label = 'Follow', run = function() Run('follower') end,
      available = function()
          -- Solo or already the party leader: follower is not a useful option.
          if Is_Party_Leader and Is_Party_Leader() then
              local party = windower.ffxi.get_party()
              local others = 0
              if party then
                  for _, key in ipairs({ 'p0', 'p1', 'p2', 'p3', 'p4', 'p5' }) do
                      local m = party[key]
                      if m and m.name and m.mob and not m.mob.is_npc then
                          local me = windower.ffxi.get_player()
                          if me and m.name ~= me.name then
                              others = others + 1
                          end
                      end
                  end
              end
              return others > 0
          end
          return true
      end },
}, function()
    if Get_Play_Mode then
        return Get_Play_Mode()
    end
    if settings and settings.semi_auto then
        return 'semi'
    end
    return (settings.assist or '') ~= '' and 'follower' or 'leader'
end)

local NUKE_CYCLE = Cycle_Button('Nukes', 'Click to change: Free Nuke, Burst Only, or Off.', {
    { key = 'free',  label = 'Free Nuke', run = function() Set_Nuke_Mode('free') end,
      available = function() return active_profile and active_profile.free_nuke end },
    { key = 'burst', label = 'Burst Only', run = function() Set_Nuke_Mode('burst') end },
    { key = 'off',   label = 'Off', run = function() Set_Nuke_Mode('off') end },
}, function() return nuke_mode end)

local WS_CYCLE = Cycle_Button('Skillchain', 'Click to change: Full Chain, Party Chain, or Opener Only.', {
    { key = 'chain', label = 'Full Chain', run = function() Run('chainmode') end,
      available = function() return Raw_WS_Chain and Raw_WS_Chain() end },
    { key = 'party', label = 'Party Chain', run = function() Run('partychain') end },
    { key = 'open',  label = 'Opener Only', run = function() Run('openmode') end },
}, function() return ws_mode end)

local SKIN_CYCLE = Cycle_Button('Skin', 'Click to change the panel look: FFXI or FFXIV.', {
    { key = 1, label = 'FFXI',  run = function() Apply_Skin(1) end },
    { key = 2, label = 'FFXIV', run = function() Apply_Skin(2) end },
}, function() return skin_index end)

-- BUTTONS
-- party       = phrase key (PartyCommands.lua, so renamed phrases work)
-- cmd         = //domo command run on this character
-- toggle/active = on/off command and how to read its state
-- cycle       = see Cycle_Button
-- run         = custom function
-- confirm     = needs a second click
-- leader_only = dimmed and refused unless you are the party leader
-- tip         = tooltip text (a string, or a function returning one)
-- slot        = filled in on the fly (the trust buttons)
local function Trust_Slots(count, leader_only)
    local slots = {}

    for _ = 1, count do
        slots[#slots + 1] = { label = '', slot = true, hidden = true, leader_only = leader_only, trust = true }
    end

    return slots
end

local SECTIONS = {
    {
        tab = 1,
        title = 'PARTY: you and the party',
        buttons = {
            { label = 'Start',   party = 'start',   tip = 'Group start: clear hold, regroup on leader, reset buffs, resume combat.' },
            { label = 'Stop',    party = 'stop',    tip = 'You and the party stop Domo.' },
            { label = 'Hold',    party = 'hold',    tip = 'Pause new pulls for the whole party until Start.' },
            { label = 'Session Stats', party = 'tnl', tip = 'Print session EXP / CP / rates to chat.' },
            { label = 'Go Home', party = 'go_home', confirm = true,
              tip = 'Warp out, stop Domo and print stats. Click twice to confirm.' },
        },
    },
    {
        tab = 1,
        title = 'THIS CHARACTER: toggles',
        buttons = {
            { label = 'Buffs',      On_Off('buffs',      function() return settings.buffs_active end), tip = 'Turn buff maintenance on or off.' },
            { label = 'Cure',       On_Off('cure',       function() return settings.cure_active end),  tip = 'Turn automatic curing on or off.' },
            { label = 'Rest',       On_Off('rest',       function() return settings.rest_active end),  tip = 'Turn mage resting on or off.' },
            { label = 'Autotarget', On_Off('autotarget', function() return settings.autotarget end),   tip = 'Turn automatic hunting on or off.' },
        },
    },
    {
        tab = 1,
        title = 'THIS CHARACTER: modes',
        buttons = {
            ROLE_CYCLE,
            NUKE_CYCLE,
            WS_CYCLE,
            -- Camp / Free Roam (location behaviour from CampLogic.lua).
            Cycle_Button('Camp', 'Click to change: Free Roam or Camp Mode.', {
                { key = 'free', label = 'Free', run = function()
                    if Set_Location_Mode then Set_Location_Mode('free') end
                end },
                { key = 'camp', label = 'Camp', run = function()
                    if Set_Location_Mode then Set_Location_Mode('camp') end
                end },
            }, function()
                if Is_Camp_Mode and Is_Camp_Mode() then
                    return 'camp'
                end
                return 'free'
            end),
        },
    },
    {
        tab = 1,
        title = 'THIS CHARACTER: targeting',
        buttons = {
            { label = 'Fight Target',  cmd = 'fight',  tip = 'Hunt only the monster you have targeted.' },
            { label = 'Clear Target',  cmd = 'target', tip = 'Clear the locked hunting target.' },
            { label = 'Level Sync Target', tip = 'Request level sync to your targeted party member.',
              run = With_Target('Level Sync Target', function(name) Run('sync ' .. name) end) },
            { label = 'Level Sync Off', cmd = 'sync off', tip = 'Turn level sync off.' },
            { label = 'Invite Target', leader_only = true, tip = 'Invite your target using the party-join flow.',
              run = With_Target('Invite Target', function(name) Run('join ' .. name) end) },
            { label = 'Cancel Invite', cmd = 'join cancel', tip = 'Cancel a party join in progress.' },
        },
    },
    {
        tab = 2,
        title = 'TRUSTS: your party',
        trusts = 'personal',
        buttons = {
            { label = 'Refresh Trusts', cmd = 'retrust', tip = 'Re-read which trusts are in your party.' },
        },
    },
    {
        tab = 2,
        title = 'PARTY TRUST CONTROL: dismiss / summon',
        trusts = 'party',
        buttons = {},
    },
    {
        tab = 3,
        title = 'FOOD: auto-eat',
        buttons = {
            { label = 'Food', On_Off('food', function()
                return settings and settings.food_active ~= false
            end), tip = 'Turn automatic food use on or off. Selection is kept.' },
            { label = 'Refresh List', cmd = 'food list', tip = 'Re-scan inventory for food items.' },
            { label = 'Use Profile Default', cmd = 'food clear',
              tip = 'Clear your pick and fall back to the job profile food.' },
        },
    },
    {
        tab = 3,
        title = 'FOOD: in inventory (click to select)',
        foods = true,
        buttons = {},
    },
    {
        tab = 4,
        title = 'SETTINGS: Domo',
        buttons = {
            -- 2-col rows: Skin | Reload, Scale-/+, Radius-/+, Show | Save
            SKIN_CYCLE,
            { label = 'Reload Domo',   cmd = 'reload', tip = 'Reload the addon; restarts if it was running.' },
            { label = 'UI Scale -1%', tip = 'Shrink the panel by 1%.',
              run = function() if Bump_UI_Scale then Bump_UI_Scale(-0.01) end end },
            { label = 'UI Scale +1%', tip = 'Enlarge the panel by 1%.',
              run = function() if Bump_UI_Scale then Bump_UI_Scale(0.01) end end },
            { label = 'Radius -5', run = Bump_Radius(-5), tip = Radius_Tip(-5) },
            { label = 'Radius +5', run = Bump_Radius(5),  tip = Radius_Tip(5) },
            { label = 'Show Settings', cmd = 'show', tip = 'Print current settings and modes to chat.' },
            { label = 'Save Settings', cmd = 'save', tip = "Save this character's settings." },
        },
    },
    {
        tab = 4,
        title = 'SETTINGS: Debug',
        buttons = {
            { label = 'Debug Log', On_Off('debug', function() return Debug and Debug.enabled end),
              tip = 'Turn debug logging on or off.' },
        },
    },
    {
        tab = 4,
        title = 'SETTINGS: party-chat permissions',
        buttons = {
            { label = 'Allowed Players', cmd = 'trust list', tip = 'Show who may use party-chat commands.' },
            { label = 'Allow Target',  tip = 'Let your target use party-chat commands.',
              run = With_Target('Allow Target', function(name) Run('trust add ' .. name) end) },
            { label = 'Disallow Target', tip = 'Remove them; an empty list allows everyone.',
              run = With_Target('Disallow Target', function(name) Run('trust remove ' .. name) end) },
        },
    },
    {
        tab = 4,
        title = 'PHRASE SETTING: invite command',
        buttons = {
            { label = 'Current Phrase', tip = 'Show the secret join phrase and how to change it.',
              run = function()
                  local p = (Get_Join_Phrase and Get_Join_Phrase()) or 'chicken nuggets'
                  windower.add_to_chat(2, '[Domo] Current phrase: "' .. p .. '"')
                  windower.add_to_chat(2, '[Domo] To change it, type: //domo setphrase New Phrase')
              end },
        },
    },
}

-- The trust sections get their dismiss/summon slots after any fixed buttons.
for _, sec in ipairs(SECTIONS) do
    if sec.trusts == 'personal' then
        for _, slot in ipairs(Trust_Slots(PERSONAL_TRUST_SLOTS, true)) do
            sec.buttons[#sec.buttons + 1] = slot
        end
    elseif sec.trusts == 'party' then
        for _, slot in ipairs(Trust_Slots(PARTY_TRUST_SLOTS, false)) do
            sec.buttons[#sec.buttons + 1] = slot
        end
    elseif sec.foods then
        for _ = 1, FOOD_SLOTS do
            sec.buttons[#sec.buttons + 1] = {
                label = '',
                slot = true,
                food_slot = true,
                hidden = true,
                tip = 'Click to select this food. Domo will keep eating it.',
            }
        end
    end
end

-- Flat numbering so every button has one index, whatever section it is in.
local ALL = {}
for si, sec in ipairs(SECTIONS) do
    for _, b in ipairs(sec.buttons) do
        -- Entries written as { label = ..., On_Off(...) } carry their fields in [1].
        if type(b[1]) == 'table' then
            b.toggle, b.active = b[1].toggle, b[1].active
        end
        b.section = si
        ALL[#ALL + 1] = b
        b.i = #ALL
    end
end

local confirm_index = nil
for _, b in ipairs(ALL) do
    if b.confirm then
        confirm_index = b.i
    end
end

local ASSETS = windower.addon_path .. 'ui\\assets\\'
local POS_FILE = windower.addon_path .. 'data/ui_pos.txt'

local built = false
local O = {}                      -- images
local T = {}                      -- texts
local layout = { buttons = {}, headers = {}, tabs = {}, height = 100 }
local hover = nil                 -- button index under the mouse
local hover_tab = nil             -- tab index under the mouse
local pressed = nil               -- what the left button went down on
local drag = nil                  -- { dx, dy } while dragging
local icon_pos = { x = DEFAULT_ICON_POS.x, y = DEFAULT_ICON_POS.y }
local icon_drag = nil             -- { dx, dy } while dragging the launcher icon
local icon_pressed = false
local confirm_until = 0
local mouse_x, mouse_y = 0, 0
local tip_key, tip_text, tip_since = nil, nil, 0

for si = 1, #SECTIONS do
    collapsed[si] = false
end

-- SAVED POSITION
local function Load_Pos()
    local ok, f = pcall(io.open, POS_FILE, 'r')
    if not ok or not f then
        return
    end
    local line = f:read('*l')
    f:close()
    local x, y, vis, sc, mask, tab, mini, skin, ix, iy = tostring(line or ''):match(
        '^(-?%d+),(-?%d+),?(%a*),?([%d%.]*),?(%d*),?(%d*),?(%d*),?(%d*),?(-?%d*),?(-?%d*)')
    if x and y then
        pos.x, pos.y = tonumber(x), tonumber(y)
        shown = (vis ~= 'hidden')
        scale = tonumber(sc) or 1.0
        current_tab = math.max(1, math.min(#TABS, tonumber(tab) or 1))
        minimized = (mini == '1')
        skin_index = math.max(1, math.min(#SKINS, tonumber(skin) or 1))
        if ix and iy and ix ~= '' and iy ~= '' then
            icon_pos.x, icon_pos.y = tonumber(ix), tonumber(iy)
        end
        -- A saved mask only applies if it was saved with this many sections.
        if #(mask or '') == #SECTIONS then
            for si = 1, #SECTIONS do
                collapsed[si] = mask:sub(si, si) == '1'
            end
        end
    end
end

local function Save_Pos()
    pcall(function()
        local f = io.open(POS_FILE, 'w')
        if f then
            local mask = ''
            for si = 1, #SECTIONS do
                mask = mask .. (collapsed[si] and '1' or '0')
            end
            f:write(string.format('%d,%d,%s,%.2f,%s,%d,%d,%d,%d,%d\n', pos.x, pos.y,
                shown and 'shown' or 'hidden', scale, mask, current_tab, minimized and 1 or 0, skin_index,
                icon_pos.x or DEFAULT_ICON_POS.x, icon_pos.y or DEFAULT_ICON_POS.y))
            f:close()
        end
    end)
end

local function In_Icon(x, y)
    return x >= icon_pos.x and x <= icon_pos.x + ICON_SIZE
        and y >= icon_pos.y and y <= icon_pos.y + ICON_SIZE
end

local function Place_Icon()
    if O.icon then
        O.icon:pos(icon_pos.x, icon_pos.y)
        O.icon:size(ICON_SIZE, ICON_SIZE)
        O.icon:visible(true)
    end
end

-- STATUS
local function Status()
    if not Start_Engine then
        return 'STOPPED', { 255, 110, 110 }
    end
    if go_home_active then
        return 'HOME', { 255, 170, 80 }
    end
    if rez_pause_active then
        return 'REZ WAIT', { 255, 170, 80 }
    end
    if regroup_active then
        return 'REGROUP', { 255, 220, 100 }
    end
    if party_hold then
        return 'HOLD', { 255, 220, 100 }
    end
    return 'RUNNING', { 120, 230, 140 }
end

-- BUTTON STATE
local function Is_Active(b)
    return b.active and b.active() and true or false
end

local function Is_Gated(b)
    return b.leader_only and not Is_Leader()
end

local function Current_Label(b)
    local label = b.label

    if type(label) == 'function' then
        return Safe(label) or ''
    end

    return label or ''
end

-- Shrinks the font for long labels so they stay inside the button.
local function Label_Base(text)
    local n = #tostring(text or '')

    if n <= 10 then
        return 10
    elseif n <= 14 then
        return 9
    elseif n <= 18 then
        return 8
    end

    return 7
end

-- GEOMETRY
-- Positions are worked out at scale 1.0, top to bottom, for the current tab
-- only; collapsed sections keep just their header.
-- Panel HEIGHT is locked to the tallest tab so switching tabs does not
-- rescale / jump the window frame (width is always BASE_W).
local fixed_panel_height = nil

local function Measure_Tab_Height(tab_index)
    local y = ROW_Y0 + TAB_H + 8
    for si, sec in ipairs(SECTIONS) do
        if sec.tab == tab_index then
            y = y + HEADER_H + HEADER_GAP
            if not collapsed[si] then
                local k = 0
                for _, b in ipairs(sec.buttons) do
                    if not b.hidden then
                        k = k + 1
                    end
                end
                y = y + math.ceil(math.max(k, 1) / COLS) * ROW_STEP
            end
            y = y + SECTION_GAP
        end
    end
    return y + 6
end

local function Recompute_Fixed_Height()
    local max_h = MIN_H
    for ti = 1, #TABS do
        local h = Measure_Tab_Height(ti)
        if h > max_h then
            max_h = h
        end
    end
    -- Floor so short tabs still feel roomy; avoid huge jumps from empty slots.
    fixed_panel_height = math.max(max_h, 220)
end

local function Compute()
    layout.buttons, layout.headers, layout.tabs = {}, {}, {}

    if minimized then
        layout.height = MIN_H
        return
    end

    for ti = 1, #TABS do
        layout.tabs[ti] = { x = 12 + (ti - 1) * (TAB_W + TAB_GAP), y = ROW_Y0, w = TAB_W, h = TAB_H }
    end

    local y = ROW_Y0 + TAB_H + 8

    for si, sec in ipairs(SECTIONS) do
        if sec.tab == current_tab then
            layout.headers[si] = { x = 12, y = y, w = BASE_W - 24, h = HEADER_H }
            y = y + HEADER_H + HEADER_GAP

            if not collapsed[si] then
                local k = 0

                for _, b in ipairs(sec.buttons) do
                    if not b.hidden then
                        local row = math.floor(k / COLS)
                        local col = k % COLS + 1

                        layout.buttons[b.i] = { x = COL_X[col], y = y + row * ROW_STEP, w = BTN_W, h = BTN_H }
                        k = k + 1
                    end
                end

                y = y + math.ceil(math.max(k, 1) / COLS) * ROW_STEP
            end

            y = y + SECTION_GAP
        end
    end

    if not fixed_panel_height then
        Recompute_Fixed_Height()
    end
    -- Content may be shorter than the fixed frame; never shrink on tab change.
    layout.height = math.max(y + 6, fixed_panel_height or y + 6)
end

local function Short_Name(name)
    if #name > 11 then
        return name:sub(1, 10) .. '..'
    end

    return name
end

-- Fills the trust slots. Personal section: a DIS button for each trust in
-- your party. Party section: DIS for each of those, then SMN for each known
-- trust (data/known_trusts.txt + popular defaults + past summons).
local function Resolve_Trust_Slots()
    for _, sec in ipairs(SECTIONS) do
        if sec.trusts then
            local present, present_set, entries = Trusts_In_Party(), {}, {}
            local leader_note = sec.trusts == 'personal'

            for _, name in ipairs(present) do
                present_set[name:lower()] = true
                entries[#entries + 1] = {
                    label = 'DIS ' .. Short_Name(name),
                    text = Trust_Phrase('dismiss') .. ' ' .. name,
                    tip = leader_note and ('Everyone holds, then you dismiss ' .. name .. '.')
                        or ('Asks the leader to dismiss ' .. name .. '. Everyone holds.'),
                }
            end

            if sec.trusts == 'party' then
                local names = {}
                local seen = {}
                local function add_name(name)
                    name = tostring(name or '')
                    if name == '' then return end
                    local key = name:lower()
                    if present_set[key] or seen[key] then return end
                    seen[key] = true
                    names[#names + 1] = name
                end
                -- Only trusts Domo has seen summoned (known_trusts.txt).
                if Get_Known_Trusts then
                    for _, name in ipairs(Get_Known_Trusts() or {}) do
                        add_name(name)
                    end
                end
                table.sort(names, function(a, b) return a:lower() < b:lower() end)

                for _, name in ipairs(names) do
                    entries[#entries + 1] = {
                        label = 'SMN ' .. Short_Name(name),
                        text = Trust_Phrase('summon') .. ' ' .. name,
                        tip = 'Asks the leader to summon ' .. name .. ' (needs a free slot).',
                    }
                end
            end

            local k = 0

            for _, b in ipairs(sec.buttons) do
                if b.slot and not b.food_slot then
                    k = k + 1

                    local e = entries[k]

                    if e then
                        b.hidden, b.label, b.partytext, b.tip = false, e.label, e.text, e.tip
                    else
                        b.hidden, b.label, b.partytext, b.tip = true, '', nil, nil
                    end
                end
            end
        end
    end
    -- Slot visibility changed: re-measure tallest tab so frame stays stable.
    fixed_panel_height = nil
end

-- Fill Food-tab slots from inventory scan. Click selects that food.
local function Resolve_Food_Slots()
    local list = (Scan_Inventory_Foods and Scan_Inventory_Foods()) or {}
    local selected = (Get_Selected_Food and Get_Selected_Food()) or ''
    local sel_key = string.lower(selected)

    for _, sec in ipairs(SECTIONS) do
        if sec.foods then
            local k = 0
            for _, b in ipairs(sec.buttons) do
                if b.food_slot then
                    k = k + 1
                    local e = list[k]
                    if e then
                        local is_sel = (sel_key ~= '' and string.lower(e.name) == sel_key)
                        b.hidden = false
                        b.label = (is_sel and '* ' or '') .. Short_Name(e.name)
                            .. ' x' .. tostring(e.count)
                        b.tip = is_sel
                            and ('Selected: ' .. e.name .. '. Domo will keep eating this.')
                            or ('Select ' .. e.name .. ' as your food.')
                        b.partytext = nil
                        local food_name = e.name
                        b.run = function()
                            if Set_Selected_Food then
                                Set_Selected_Food(food_name)
                            end
                            if settings then
                                settings.food_active = true
                            end
                            windower.add_to_chat(3, '[Domo] Will eat: ' .. food_name)
                        end
                    else
                        b.hidden = true
                        b.label = ''
                        b.tip = nil
                        b.run = nil
                    end
                end
            end
        end
    end
    fixed_panel_height = nil
end

local function Screen_Rect(r)
    return pos.x + r.x * scale, pos.y + r.y * scale, r.w * scale, r.h * scale
end

local function In_Panel(x, y)
    return x >= pos.x and x <= pos.x + BASE_W * scale
        and y >= pos.y and y <= pos.y + layout.height * scale
end

local function Inside(r, bx, by)
    return bx >= r.x and bx <= r.x + r.w and by >= r.y and by <= r.y + r.h
end

-- What is under the mouse: 'close', 'minimize', 'status', 'tab', 'header',
-- 'button' (with an index), or nil.
local function Target_At(x, y)
    if not In_Panel(x, y) then
        return nil
    end

    local bx, by = (x - pos.x) / scale, (y - pos.y) / scale

    if by <= TITLE_H then
        if bx >= BASE_W - CLOSE_X - 8 then
            return 'close'
        elseif bx >= BASE_W - MIN_X - 8 then
            return 'minimize'
        elseif bx >= BASE_W - STATUS_RIGHT - 90 then
            return 'status'
        end

        return nil
    end

    if minimized then
        return nil
    end

    for ti, r in pairs(layout.tabs) do
        if Inside(r, bx, by) then
            return 'tab', ti
        end
    end

    for i, r in pairs(layout.buttons) do
        if Inside(r, bx, by) then
            return 'button', i
        end
    end

    for si, r in pairs(layout.headers) do
        if Inside(r, bx, by) then
            return 'header', si
        end
    end

    return nil
end

-- Size and place a texture so that its VISIBLE part is vw x vh, centred on cx, cy.
local function Band(obj, cx, cy, vw, vh, part)
    local iw = vw * part.imgw / part.visw
    local ih = vh * part.imgh / part.vish

    obj:size(iw, ih)
    obj:pos(cx - iw / 2, cy - ih / 2)
end

-- DRAWING
local function Make_Image(path, w, h, color)
    return images.new {
        pos = { x = 0, y = 0 },
        visible = false,
        color = color or { alpha = 255, red = 255, green = 255, blue = 255 },
        size = { width = w, height = h },
        texture = { path = path, fit = true },
        draggable = false,
    }
end

local function Make_Text(str, size, right)
    return texts.new(str, {
        pos = { x = 0, y = 0 },
        bg = { visible = false },
        flags = { right = right or false, draggable = false },
        text = {
            font = 'Arial', size = size, alpha = 240, red = 255, green = 255, blue = 255,
            stroke = { width = 2, alpha = 200, red = 6, green = 45, blue = 84 },
        },
    })
end

local function Font_Size(base)
    return math.max(1, math.floor(base * scale + 0.5))
end

local function Center_Text(t, cx, cy)
    local w, h = t:extents()

    -- Extents are 0 until the game has drawn the text once; Render() runs
    -- again every half second, so it settles by itself.
    t:pos(cx - (w or 0) / 2, cy - (h or 0) / 2)
end

local cur_label = {}

local function Layout()
    if not built then
        return
    end

    Place_Icon()
    Compute()

    local s = scale
    local H = layout.height
    local full = shown and not minimized
    local sk = SKINS[skin_index]

    -- frame
    local mid_y = sk.top_y + sk.top_h
    local bottom_y = H - sk.bottom_h + sk.overhang

    O.top:pos(pos.x, pos.y + sk.top_y * s)
    O.top:size(BASE_W * s, sk.top_h * s)
    O.mid:pos(pos.x, pos.y + mid_y * s)
    O.mid:size(BASE_W * s, math.max(1, bottom_y - mid_y) * s)
    O.bottom:pos(pos.x, pos.y + bottom_y * s)
    O.bottom:size(BASE_W * s, sk.bottom_h * s)

    -- status strip
    local cx, cy = pos.x + BASE_W / 2 * s, pos.y + STRIP_Y * s
    Band(O.track, cx, cy, STRIP_W * s, STRIP_H * s, PILL)
    Band(O.fill, cx, cy, (STRIP_W - 2) * s, (STRIP_H - 4) * s, FILL)

    -- title row: Domo (left) | status (right-aligned before min) | - | x
    T.title:size(Font_Size(11))
    T.title:pos(pos.x + TITLE_X * s, pos.y + TITLE_Y * s)
    T.status:size(Font_Size(9))
    T.status:pos(pos.x + (BASE_W - STATUS_RIGHT) * s, pos.y + (TITLE_Y + 2) * s)
    T.minimize:size(Font_Size(11))
    T.minimize:pos(pos.x + (BASE_W - MIN_X) * s, pos.y + TITLE_Y * s)
    T.close:size(Font_Size(11))
    T.close:pos(pos.x + (BASE_W - CLOSE_X) * s, pos.y + TITLE_Y * s)

    -- tabs
    for ti = 1, #TABS do
        local r = layout.tabs[ti]

        if r then
            local tx, ty, tw, th = Screen_Rect(r)

            Band(O.tab_pills[ti], tx + tw / 2, ty + th / 2, tw, th, PILL)
            Band(O.tab_marks[ti], tx + tw / 2, ty + th / 2, tw - 2 * s, th - 2 * s, FILL)
            O.tab_marks[ti]:color(120, 230, 140)
            O.tab_marks[ti]:alpha(80)
            T.tab_labels[ti]:size(Font_Size(10))
            Center_Text(T.tab_labels[ti], tx + tw / 2, ty + th / 2)
        end

        O.tab_pills[ti]:visible(full and r ~= nil)
        O.tab_marks[ti]:visible(full and r ~= nil and ti == current_tab)
        T.tab_labels[ti]:visible(full and r ~= nil)
    end

    -- section headers (only the current tab's)
    for si = 1, #SECTIONS do
        local r = layout.headers[si]

        if r then
            local hx, hy, hw, hh = Screen_Rect(r)

            Band(O.headers[si], hx + hw / 2, hy + hh / 2, hw, hh, PILL)
            T.headers[si]:size(Font_Size(10))
            T.headers[si]:pos(hx + 8 * s, hy + 1 * s)
        end

        O.headers[si]:visible(full and r ~= nil)
        T.headers[si]:visible(full and r ~= nil)
    end

    -- buttons
    local armed = os.clock() < confirm_until

    for _, b in ipairs(ALL) do
        local r = layout.buttons[b.i]
        local visible = full and r ~= nil

        O.pills[b.i]:visible(visible)
        T.labels[b.i]:visible(visible)

        if r then
            local bx, by, bw, bh = Screen_Rect(r)
            local gated = Is_Gated(b)

            Band(O.pills[b.i], bx + bw / 2, by + bh / 2, bw, bh, PILL)
            T.labels[b.i]:size(Font_Size(Label_Base(cur_label[b.i] or '')))
            Center_Text(T.labels[b.i], bx + bw / 2, by + bh / 2)

            -- grey text when the leader is needed; red overlay while waiting
            -- for the second click; green overlay while on
            if gated then
                T.labels[b.i]:color(140, 140, 150)
            else
                T.labels[b.i]:color(255, 255, 255)
            end

            local mark = O.marks[b.i]
            local waiting = (b.i == confirm_index) and armed

            if gated then
                mark:color(0, 0, 0)
                mark:alpha(150)
            elseif waiting then
                mark:color(255, 70, 70)
                mark:alpha(115)
            else
                mark:color(120, 230, 140)
                mark:alpha(80)
            end

            Band(mark, bx + bw / 2, by + bh / 2, bw - 2 * s, bh - 2 * s, FILL)
            mark:visible(visible and (gated or waiting or Is_Active(b)))
        else
            O.marks[b.i]:visible(false)
        end
    end

    -- hover glow
    local hover_rect = hover and layout.buttons[hover]

    if hover_rect then
        local bx, by, bw, bh = Screen_Rect(hover_rect)

        O.hover:pos(bx - 8 * s, by - 6 * s)
        O.hover:size(bw + 16 * s, bh + 12 * s)
    end

    O.hover:visible(full and hover_rect ~= nil)

    for _, key in ipairs({ 'top', 'mid', 'bottom', 'track', 'fill' }) do
        O[key]:visible(shown)
    end

    T.title:visible(shown)
    T.status:visible(shown)
    T.minimize:visible(shown)
    T.close:visible(shown)
end

-- Panel scale ±1% (saved with position). Mouse wheel still steps by 5%.
function Bump_UI_Scale(delta)
    scale = math.max(0.5, math.min(2.5, (scale or 1.0) + (delta or 0)))
    Layout()
    Save_Pos()
    windower.add_to_chat(2, string.format('[Domo] UI scale: %.0f%%', scale * 100))
end

local text_cache = {}

local function Set_Text(key, obj, value)
    if text_cache[key] ~= value then
        text_cache[key] = value
        obj:text(value)
    end
end

local function Render()
    if not built then
        return
    end

    Resolve_Trust_Slots()
    Resolve_Food_Slots()

    local status, color = Status()

    Set_Text('status', T.status, status)
    T.status:color(color[1], color[2], color[3])
    O.fill:color(color[1], color[2], color[3])

    local armed = os.clock() < confirm_until

    for _, b in ipairs(ALL) do
        local label = (b.confirm and armed) and 'Sure?' or Current_Label(b)

        cur_label[b.i] = label
        Set_Text(b.i, T.labels[b.i], label)
    end

    for si, sec in ipairs(SECTIONS) do
        Set_Text('h' .. si, T.headers[si], (collapsed[si] and '[+]  ' or '[-]  ') .. sec.title)
    end

    Set_Text('min', T.minimize, minimized and '+' or '-')

    for ti = 1, #TABS do
        Set_Text('tab' .. ti, T.tab_labels[ti], TABS[ti])
    end

    Layout()
end

-- TOOLTIP
-- A floating box next to the cursor. It is the last text created, so it
-- draws on top of everything else.
local function Wrap(text, width)
    local lines, line = {}, ''

    for word in text:gmatch('%S+') do
        if line ~= '' and #line + #word + 1 > width then
            lines[#lines + 1] = line
            line = word
        else
            line = (line == '') and word or (line .. ' ' .. word)
        end
    end

    if line ~= '' then
        lines[#lines + 1] = line
    end

    return table.concat(lines, '\n')
end

local function Tip_For_Hover()
    if hover then
        local b = ALL[hover]

        if not b then
            return nil
        end

        local tip = b.tip
        local text = type(tip) == 'function' and (Safe(tip) or '') or (tip or '')

        if Is_Gated(b) then
            text = 'LEADER ONLY: you are not the party leader. ' .. text
        end

        return 'b' .. hover, text
    elseif hover_tab then
        return 't' .. hover_tab, TAB_TIPS[hover_tab]
    end

    return nil
end

local function Update_Tooltip()
    if not built then
        return
    end

    local key, text

    if shown and not minimized and not drag then
        key, text = Tip_For_Hover()
    end

    if not key or not text or text == '' then
        tip_key = nil
        T.tip:visible(false)
        return
    end

    local wrapped = Wrap(text, TIP_WRAP)

    if wrapped ~= tip_text then
        tip_text = wrapped
        T.tip:text(wrapped)
    end

    if key ~= tip_key then
        -- New target: measure the text off-screen, show it after a short delay.
        tip_key, tip_since = key, os.clock()
        T.tip:size(TIP_SIZE)
        T.tip:pos(-3000, -3000)
        T.tip:visible(true)
        return
    end

    if os.clock() - tip_since < TIP_DELAY then
        return
    end

    local w, h = T.tip:extents()
    local settings_ui = Safe(function() return windower.get_windower_settings() end) or {}
    local sx, sy = settings_ui.ui_x_res or 1920, settings_ui.ui_y_res or 1080
    local tx, ty = mouse_x + 18, mouse_y + 22

    w, h = (w or 0) + 14, (h or 0) + 14

    if tx + w > sx then
        tx = mouse_x - w - 8
    end

    if ty + h > sy then
        ty = mouse_y - h - 8
    end

    T.tip:pos(math.max(0, tx), math.max(0, ty))
    T.tip:visible(true)
end

-- SKIN
Apply_Skin = function(index)
    skin_index = math.max(1, math.min(#SKINS, index))

    if built then
        local dir = ASSETS .. SKINS[skin_index].dir .. '\\'

        O.top:path(dir .. 'BgTop.png')
        O.mid:path(dir .. 'BgMid.png')
        O.bottom:path(dir .. 'BgBottom.png')
        Layout()
    end

    Save_Pos()
end

-- ACTIONS
-- Runs the party command on this character, then tells the rest of the
-- party. Your own party chat is not echoed back to you, so without the
-- first step the character you click on would never act.
local function Send_Party(text)
    Run('party ' .. text)

    local party = windower.ffxi.get_party()

    if party and (party.party1_count or 1) > 1 then
        windower.send_command('input /p ' .. text)
    end
end

local function Send_Phrase(key)
    local phrase = (Party_Phrase_Text and Party_Phrase_Text(key)) or FALLBACK_PHRASES[key]

    if phrase then
        Send_Party(phrase)
    end
end

local function Hide_Panel()
    shown = false
    hover, hover_tab = nil, nil
    Layout()
    Update_Tooltip()
    Save_Pos()
    windower.add_to_chat(2, '[Domo] Panel hidden. //domo ui brings it back.')
end

local function Press_Button(idx)
    local b = ALL[idx]

    if not b then
        return
    end

    if Is_Gated(b) then
        windower.add_to_chat(167, '[Domo] That needs the party leader, and you are not the leader.'
            .. (b.trust and ' Use the Party Trusts tab to ask the leader.' or ''))
        return
    end

    if b.confirm and os.clock() >= confirm_until then
        confirm_until = os.clock() + CONFIRM_SECONDS
        Render()
        return
    end

    confirm_until = 0

    if b.party then
        Send_Phrase(b.party)
    elseif b.partytext then
        Send_Party(b.partytext)
    elseif b.cycle then
        Advance_Cycle(b.cycle)
    elseif b.toggle then
        Run(b.toggle .. (Is_Active(b) and ' off' or ' on'))
    elseif b.cmd then
        Run(b.cmd)
    elseif b.run then
        b.run()
    end

    Render()
    -- the command has run by then; pick up the new state quickly
    coroutine.schedule(Render, 0.4)
end

local function Activate(kind, idx)
    if kind == 'button' then
        Press_Button(idx)
    elseif kind == 'tab' then
        current_tab = idx
        hover, hover_tab = nil, nil
        Render()
        Save_Pos()
    elseif kind == 'header' then
        collapsed[idx] = not collapsed[idx]
        Render()
        Save_Pos()
    elseif kind == 'minimize' then
        minimized = not minimized
        hover, hover_tab = nil, nil
        Render()
        Save_Pos()
    elseif kind == 'status' then
        Run(Start_Engine and 'stop' or 'start')
        coroutine.schedule(Render, 0.4)
    elseif kind == 'close' then
        Hide_Panel()
    end
end

-- MOUSE
-- kind: 0 move, 1 left down, 2 left up, 10 wheel. Only the left button is
-- used; right-click is left alone for the game. Returning true keeps the
-- click from also reaching the game underneath the panel.
-- The launcher icon is always interactive (even when the panel is hidden).
windower.register_event('mouse', function(kind, x, y, delta, blocked)
    mouse_x, mouse_y = x, y

    if blocked or not built then
        return
    end

    -- ---- launcher icon (always on) ----
    if icon_drag then
        if kind == 0 then
            icon_pos.x = math.max(0, x - icon_drag.dx)
            icon_pos.y = math.max(0, y - icon_drag.dy)
            Place_Icon()
            return true
        elseif kind == 2 then
            icon_drag = nil
            icon_pressed = false
            Save_Pos()
            return true
        end
        return true
    end

    if icon_pressed and kind == 0
        and (math.abs(x - icon_pressed.x) > DRAG_THRESHOLD
            or math.abs(y - icon_pressed.y) > DRAG_THRESHOLD)
    then
        icon_drag = { dx = icon_pressed.x - icon_pos.x, dy = icon_pressed.y - icon_pos.y }
        icon_pressed = false
        Place_Icon()
        return true
    end

    if kind == 1 and In_Icon(x, y) then
        icon_pressed = { x = x, y = y }
        return true
    end

    if kind == 2 and icon_pressed then
        icon_pressed = false
        if In_Icon(x, y) then
            shown = not shown
            hover, hover_tab = nil, nil
            Layout()
            Save_Pos()
        end
        return true
    end

    -- Panel is hidden: only the icon is interactive.
    if not shown then
        return
    end

    -- Pressing something and then moving the mouse turns into a drag, so the
    -- panel can be grabbed anywhere; a press that stays put is still a click.
    if pressed and kind == 0
        and (math.abs(x - pressed.x) > DRAG_THRESHOLD or math.abs(y - pressed.y) > DRAG_THRESHOLD)
    then
        drag = { dx = pressed.x - pos.x, dy = pressed.y - pos.y }
        pressed = nil
        hover, hover_tab = nil, nil
    end

    if drag then
        if kind == 0 then
            pos.x = math.max(0, x - drag.dx)
            pos.y = math.max(0, y - drag.dy)
            Layout()
            return true
        elseif kind == 2 then
            drag = nil
            Save_Pos()
            return true
        end

        return
    end

    local target, idx = Target_At(x, y)
    local inside = In_Panel(x, y)

    if kind == 0 then
        local hb = (target == 'button') and idx or nil
        local ht = (target == 'tab') and idx or nil

        if hb ~= hover or ht ~= hover_tab then
            hover, hover_tab = hb, ht
            Layout()
        end

        return
    end

    if kind == 1 and inside then
        if target then
            pressed = { kind = target, idx = idx, x = x, y = y }
        else
            drag = { dx = x - pos.x, dy = y - pos.y }
        end

        return true
    end

    if kind == 2 and pressed then
        local p = pressed
        pressed = nil

        if target == p.kind and idx == p.idx then
            Activate(p.kind, p.idx)
        end

        return true
    end

    if kind == 10 and inside then
        scale = math.max(0.5, math.min(2.5, scale + ((delta or 0) > 0 and 0.05 or -0.05)))
        Layout()
        Save_Pos()
        return true
    end
end)

-- SET UP
local function Create()
    if not windower.file_exists(ASSETS .. 'BarBG.png') then
        windower.add_to_chat(167, '[Domo] Button panel assets missing: expected ' .. ASSETS .. 'BarBG.png')
        return
    end

    Load_Pos()

    local skin = ASSETS .. SKINS[skin_index].dir .. '\\'

    -- Launcher icon (TrustSupport-style): always visible, click toggles panel.
    if windower.file_exists(ASSETS .. 'domologo.png') then
        O.icon = Make_Image(ASSETS .. 'domologo.png', ICON_SIZE, ICON_SIZE)
        Place_Icon()
    end

    -- Creation order is draw order: frame, glow, headers, tabs, pills, marks, strip.
    O.top = Make_Image(skin .. 'BgTop.png', BASE_W, 21)
    O.mid = Make_Image(skin .. 'BgMid.png', BASE_W, 100)
    O.bottom = Make_Image(skin .. 'BgBottom.png', BASE_W, 21)
    O.hover = Make_Image(ASSETS .. 'Hover.png', BTN_W, BTN_H,
        { alpha = 200, red = 110, green = 215, blue = 255 })
    O.headers = {}

    for si = 1, #SECTIONS do
        O.headers[si] = Make_Image(ASSETS .. 'BarBG.png', 128, 64)
    end

    O.tab_pills, O.tab_marks = {}, {}

    for ti = 1, #TABS do
        O.tab_pills[ti] = Make_Image(ASSETS .. 'BarBG.png', 128, 64)
        O.tab_marks[ti] = Make_Image(ASSETS .. 'Bar.png', 102, 64,
            { alpha = 80, red = 120, green = 230, blue = 140 })
    end

    O.pills, O.marks = {}, {}

    for _, b in ipairs(ALL) do
        O.pills[b.i] = Make_Image(ASSETS .. 'BarBG.png', 128, 64)
        O.marks[b.i] = Make_Image(ASSETS .. 'Bar.png', 102, 64,
            { alpha = 80, red = 120, green = 230, blue = 140 })
    end

    O.track = Make_Image(ASSETS .. 'BarBG.png', 128, 64)
    O.fill = Make_Image(ASSETS .. 'Bar.png', 102, 64)

    T.title = Make_Text('Domo', 12)
    T.status = Make_Text('', 11, true)
    T.close = Make_Text('x', 12)
    T.close:color(190, 190, 200)
    T.minimize = Make_Text('-', 12)
    T.minimize:color(190, 190, 200)
    T.tab_labels = {}

    for ti = 1, #TABS do
        T.tab_labels[ti] = Make_Text(TABS[ti], 10)
    end

    T.headers, T.labels = {}, {}

    for si = 1, #SECTIONS do
        T.headers[si] = Make_Text('', 10)
        T.headers[si]:color(200, 200, 215)
    end

    for _, b in ipairs(ALL) do
        T.labels[b.i] = Make_Text(Current_Label(b), 11)
    end

    -- Last, so it draws above everything.
    T.tip = texts.new('', {
        pos = { x = -3000, y = -3000 },
        bg = { alpha = 245, red = 18, green = 18, blue = 36, visible = true },
        padding = 6,
        flags = { draggable = false },
        text = {
            font = 'Arial', size = TIP_SIZE, alpha = 255, red = 255, green = 255, blue = 255,
            stroke = { width = 1, alpha = 200, red = 0, green = 0, blue = 0 },
        },
    })
    T.tip:visible(false)

    built = true
    Render()
end

-- Keeps the status and toggle lights current, re-centres labels once the
-- game has measured them, and puts Go Home back after its confirm window.
coroutine.schedule(function()
    while true do
        pcall(Render)
        coroutine.sleep(0.5)
    end
end, 1)

-- The tooltip follows the cursor, so it is refreshed more often.
coroutine.schedule(function()
    while true do
        pcall(Update_Tooltip)
        coroutine.sleep(0.1)
    end
end, 1)

windower.register_event('logout', function()
    local was = shown
    shown = false
    pcall(Layout)
    pcall(Update_Tooltip)
    shown = was
end)

windower.register_event('login', function()
    pcall(Render)
end)

windower.register_event('unload', function()
    if not built then
        return
    end

    built = false

    local function Kill(obj)
        if type(obj) == 'table' and obj.destroy then
            obj:destroy()
        elseif type(obj) == 'table' then
            for _, o in pairs(obj) do
                Kill(o)
            end
        end
    end

    Kill(O)
    Kill(T)
end)

function UI_Command(command, args)
    if command ~= 'ui' then
        return false
    end

    local sub = args and args[2]

    if sub == 'skin' then
        local want = tostring(args[3] or ''):lower()

        for i, sk in ipairs(SKINS) do
            if sk.dir == want then
                Apply_Skin(i)
                windower.add_to_chat(2, '[Domo] Panel skin: ' .. sk.name .. '.')
                return true
            end
        end

        windower.add_to_chat(167, '[Domo] //domo ui skin ffxi  or  //domo ui skin ffxiv')
        return true
    end

    if sub == 'reset' then
        pos.x, pos.y = DEFAULT_POS.x, DEFAULT_POS.y
        scale = 1.20
        shown = true
        minimized = false
        current_tab = 1
        collapsed = {}

        for si = 1, #SECTIONS do
            collapsed[si] = false
        end

        Apply_Skin(1)
    elseif sub == 'show' then
        shown = true
    elseif sub == 'hide' then
        shown = false
    else
        shown = not shown
    end

    hover, hover_tab = nil, nil
    Layout()
    Save_Pos()
    windower.add_to_chat(2, '[Domo] Panel ' .. (shown and 'shown.' or 'hidden.'))

    return true
end

Create()
