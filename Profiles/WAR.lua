
-- WAR JOB PROFILE
-- Warrior weaponskill and buff settings.

JOB_PROFILES.WAR = {
    -- ENGAGE
    auto_engage = true,
    use_weaponskills = true,

    haste_active = false,
    self_buffs = {},

    -- WEAPON-SPECIFIC SKILLCHAIN ROTATIONS
    weaponskills = {
        min_tp = 1000,

        rotations = {
            {
                name = 'Great Axe',
                weapon_type = 'Great Axe',
                required_ws = {
                    'Upheaval',
                    "Ukko's Fury",
                },
                sequence = {
                    { name = 'Upheaval', min_tp = 2000 },
                    { name = "Ukko's Fury", min_tp = 1000 },
                    { name = 'Upheaval', min_tp = 1000 },
                },
                priority = 2,
            },
            {
                name = 'Sword',
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
        'Hasso',
        'Berserk',
        'Blood Rage',
        'Aggressor',
        'food',
    },

    -- LEGACY SKILLCHAIN SETTINGS
    -- Retained for compatibility until the new rotation system replaces them.
    ws_sc_starter = { 'Upheaval', 2000 },
    ws_sc_closers = { "Ukko's Fury" },

    ws_sc_chain = {
        { 'Upheaval', 2000 },
        { "Ukko's Fury", 1000 },
        { 'Upheaval', 1000 },
    },

    -- FOOD
    food = 'S. Salis. Steak',

    -- STUCK RECOVERY
    provoke_if_stuck = false,
    stuck_threshold = 10,
}
