
-- COR JOB PROFILE
-- Corsair -- Rolls, Quick Draw, ranged weaponskills.
-- Loaded by Domo.lua into JOB_PROFILES.COR

JOB_PROFILES.COR = {
    auto_engage = true,
    use_weaponskills = true,

    haste_active = false,
    haste_samba_active = true,
    self_buffs = {},

    -- WEAPON-SPECIFIC SKILLCHAIN ROTATIONS
    weaponskills = {
        min_tp = 1000,

        rotations = {
            {
                name = 'Marksmanship - Leaden Salute',
                weapon_type = 'Gun',
                required_ws = {
                    'Leaden Salute',
                },
                sequence = {
                    { name = 'Leaden Salute', min_tp = 1000 },
                },
                priority = 2,
            },
            {
                name = 'Sword - Savage Blade',
                weapon_type = 'Sword',
                required_ws = {
                    'Savage Blade',
                },
                sequence = {
                    { name = 'Savage Blade', min_tp = 1000 },
                },
                priority = 1,
            },
        },
    },

    -- BUFFS
    needed_buffs = {
        'Fighter\'s Roll',
        'Chaos Roll',
        'Box Step',
        'Reverse Flourish',
    },

    -- LEGACY SKILLCHAIN SETTINGS
    -- Retained for compatibility until the new rotation system replaces them.
    ws_sc_starter = {
        'Leaden Salute',
        1000,
    },

    ws_sc_closers = {
        'Leaden Salute',
    },

    ws_sc_chain = {
        { 'Leaden Salute', 1000 },
    },

    box_step = true,
    reverse_flourish = true,
    saber_dance = true,
    haste_samba = true,

    food = 'Red Curry Bun',
}
