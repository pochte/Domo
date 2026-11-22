-- SETTINGS.LUA
-- Public shared configuration and fallback values.
--
-- Job-specific rotations, buffs, food, and combat behaviour
-- belong in profiles/*.lua and are handled by JobLogic.lua.
--
-- Reload in-game with: //domo reload


-- WEAPON SKILL FALLBACKS

ws_sc_starter = { 'Savage Blade' }

ws_sc_closers = {
    'Savage Blade',
}


-- MAGIC BURST TIMING

burst_when = 'final'
burst_quiet = 2
burst_min_left = 0.8
burst_gap = 0.7


-- FREE NUKE WEAKNESSES

nuke_weakness = {
    { 'Worm',   'Fire' },
    { 'Bat',    'Aero' },
    { 'Beetle', 'Blizzard' },
    { 'Eft',    'Blizzard' },
    { 'Crab',   'Blizzard' },
}


-- FINISHER

-- //domo finisher on/off
-- //domo finisher <hp%>

finisher_enabled = true
finisher_hp = 10
finisher_hp_low = 5
finisher_tp = 1000


-- SPELL BLACKLIST

spell_blacklist = {
    'Locus Colibri',
}


-- DISPEL WHITELIST

dispel_whitelist = {
    'Beetle',
    'Crab',
}


-- HASTE BLACKLIST

haste_blacklist = {
    'Ulmia',
    'Joachim',
    'Yoran-Oran',
    'Sylvie',
    'Koru-Moru',
}


-- PARTY JOIN

-- A trusted player can send a tell containing the configured phrase.
-- Domo pauses new pulls, invites them, level-syncs, and rebalances Trusts.
--
-- Real players who join your party are automatically added to
-- data/trusted_players.txt. Leaving the party does not remove them.
--
-- The same trusted list controls party-chat commands and party-join requests.
-- An empty list permits everyone until players are added automatically
-- or manually with //domo trust add.

party_join = {
    enabled = true,
    phrase = 'chicken nuggets',
    invite_timeout = 60,
    fight_timeout = 120,
    level_sync = true,
}


-- PARTY COMMANDS

-- Commands are sent in PARTY chat as the entire line.
--
-- Permissions use the private list in data/trusted_players.txt.
-- Manage it with:
--   //domo trust add <name>
--   //domo trust remove <name>
--   //domo trust list
--   //domo trust clear
--
-- An empty list permits everyone. Real party members are automatically added.
--
-- Commands:
--   reset     Re-anchor the origin where each character stands.
--   go home   Warp using the configured items, stop Domo, and print stats.
--   stop      Stop Domo on everyone.
--   start     Start Domo on everyone.
--   hold      Stop new pulls until resume.
--   resume    Continue and set a new origin.
--   regroup   Run to the party leader and hold.
--   rebuff    Reset buff timers so buffs are recast.
--   tnl       Print session stats.
--
-- Automatic party support:
--   rez       Coordinate raises and wait for Weakness to wear off.
--   Doom      Announce Doom and use Holy Water / Cursna.
--   Cleansing Remove supported debuffs with WHM/SCH.

party_commands = {
    rez_enabled = true,
    rez_timeout = 180,
    rez_step = 4,
    rez_last_ditch_wait = 10,
    rez_give_up = 90,
    rez_pause_max = 900,

    wait_for_weakness = true,
    raise_accept_param = 0,

    doom_holy_water = true,
    holy_water_tries = 8,

    cleanse_step = 2,
    cleanse_ignore = { 'Evasion Down' },

    regroup_timeout = 45,

    go_home_items = {
        { name = 'Warp Ring',   slot = 'ring2' },
        { name = 'Treat Staff', slot = 'main' },
        { name = 'Warp Cudgel', slot = 'main' },
        { name = 'Instant Warp' },
    },
}


-- TRUST JOBS AND SACRIFICE ORDER

trust_jobs = {
    ['Ulmia'] = 'BRD',
    ['Joachim'] = 'BRD',
    ['Koru-Moru'] = 'RDM',
    ['Yoran-Oran'] = 'WHM',
    ['Sylvie'] = 'GEO',
    ['Qultada'] = 'COR',
}

trust_sacrifice_order = {
    { 'Ulmia', 'Joachim' },
    { 'Qultada' },
}


-- TARGETING

-- Player-owned pets and GEO Luopans are excluded by ownership checks
-- in TargetLogic.lua. Do not exclude pets as a general category:
-- DRG and SMN behaviour must remain unaffected.

targeting = {
    monsters = {
        'Colibri',
        'Bat',
        'Apex Eft',
        'Locus Dire Bat',
    },

    only_unclaimed = true,
    only_alive = true,
    within_origin = true,
}


-- DEFAULT BUFF / FOOD FALLBACKS

needed_buffs = {}
food = 'Red Curry Bun'


-- SUBJOB ABILITIES

-- Abilities granted by a specific subjob, independent of the main-job profile.
-- Intervals are measured in minutes.

haste_samba_active = true

subjob_abilities = {
    DNC = {
        {
            name = 'Haste Samba',
            interval = 0.1,
        },
    },
}
