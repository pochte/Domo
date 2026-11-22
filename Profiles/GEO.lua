-- GEO JOB PROFILE
JOB_PROFILES.GEO = {
    -- MELEE / ENGAGE SETTINGS
    auto_engage = false,
    use_weaponskills = false,
    engage_distance = 5,

    -- GEO Luopan lifecycle management is handled by HealBuffLogic.lua.
    -- Blaze-enhanced Luopans are preserved from Concentric Pulse,
    -- Radial Arcana, and Mending Halation.
    geo_luopan_management = true,

    -- SELF BUFFS & ABILITIES
    -- Indi-Fury is the normal self-centered GEO bubble.
    self_buffs = {
        { name = 'Indi-Fury', interval = 3 },
    },

    -- FREE NUKE (//domo freenuke).
    -- Tier IV and lower are cast on the target between bursts;
    -- V and VI are saved for magic burst.
    free_nuke = true,
    free_nuke_max_tier = 3,
    free_nuke_weather = true,

    self_abilities = {
        -- Restores MP using an unbuffed Luopan when player MP is low.
        -- HealBuffLogic suppresses this on a Blaze-enhanced Luopan.
        {
            name = 'Radial Arcana',
            interval = 1,
            require_pet = true,
            max_mp_percent = 50,
            min_pet_hpp = 20
        },

        -- Grants Luopan temporary invulnerability when HP drops below 30%.
        -- Allowed on both normal and Blaze-enhanced Luopans.
        {
            name = 'Dematerialize',
            interval = 1,
            require_pet = true,
            max_pet_hpp = 30
        },

        -- Restores Luopan HP when it drops below 40%.
        -- Allowed on both normal and Blaze-enhanced Luopans.
        {
            name = 'Life Cycle',
            interval = 1,
            require_pet = true,
            max_pet_hpp = 40
        },
    },

    -- ENTRUST BUFFS
    entrust_buffs = {
        {
            ability = 'Entrust',
            spell = 'Indi-Refresh',
            targets = {
                jobs = { 'RDM', 'WHM', 'SCH', 'BLM', 'SMN', }
            },
            interval = 1,
        },
        {
            ability = 'Entrust',
            spell = 'Indi-Haste',
            targets = {
                lone_leader_unknown_job = true
            },
            interval = 1,
        },
        {
            ability = 'Entrust',
            spell = 'Indi-Frailty',
            targets = {
                players_only = true
            },
            fallback = true,
            interval = 1,
        },
    },

    -- TARGET DEBUFFS
    -- Blaze is optional; Geo-Frailty is still cast when Blaze is unavailable.
    -- A successful Geo-Frailty cast is tracked separately for each enemy.
    debuffs = {
        {
            name = 'Geo-Frailty',
            target = '<bt>',
            interval = 1,
            use_ability_before = 'Blaze of Glory',
            use_ability_after = 'Ecliptic Attrition',
        },
    },

    -- MAGIC BURST
    magic_burst = true,
    burst_spells = {
        Fire     = { 'Fire V', 'Fire IV', 'Fire III' },
        Blizzard = { 'Blizzard V', 'Blizzard IV', 'Blizzard III' },
        Aero     = { 'Aero V', 'Aero IV', 'Aero III' },
        Stone    = { 'Stone V', 'Stone IV', 'Stone III' },
        Thunder  = { 'Thunder V', 'Thunder IV', 'Thunder III' },
        Water    = { 'Water V', 'Water IV', 'Water III' },
        Darkness = { 'Impact' },
    },

    -- CURE BOT
    cure_bot_active = true,
    cure_tiers = {
        {
            min_missing = 100,
            max_missing = 350,
            spells = { 'Cure II', 'Cure' },
        },
        {
            min_missing = 351,
            max_missing = 800,
            spells = { 'Cure III', 'Cure II' },
        },
        {
            min_missing = 801,
            max_missing = 999999,
            spells = { 'Cure IV', 'Cure III' },
        },
    },
}
