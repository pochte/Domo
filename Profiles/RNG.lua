
-- RNG JOB PROFILE
-- Ranger weaponskill and buff settings.

JOB_PROFILES.RNG = {
    auto_engage = true,
    use_weaponskills = true,

    haste_active = false,
    self_buffs = {},

    -- WEAPON-SPECIFIC SKILLCHAIN ROTATIONS
    weaponskills = {
        min_tp = 1000,

        rotations = {
            -- ARCHERY
            {
                name = 'Archery - Light (3-Step)',
                weapon_type = 'Bow',
                required_ws = {
                    'Refulgent Arrow',
                    'Empyreal Arrow',
                    "Jishnu's Radiance",
                },
                sequence = {
                    { name = 'Refulgent Arrow', min_tp = 1000 },
                    { name = 'Empyreal Arrow', min_tp = 1000 },
                    { name = "Jishnu's Radiance", min_tp = 1000 },
                },
                priority = 2,
            },

            -- MARKSMANSHIP
            {
                name = 'Marksmanship - Light (2-Step)',
                weapon_type = 'Crossbow',
                required_ws = {
                    'Last Stand',
                },
                sequence = {
                    { name = 'Last Stand', min_tp = 1000 },
                    { name = 'Last Stand', min_tp = 1000 },
                },
                priority = 1,
            },
        },
    },

    -- BUFFS
    -- Available buffs depend on the selected subjob.
    needed_buffs = {
        -- /WAR
        'Berserk',
        'Warcry',
        'Aggressor',

        -- /SAM
        'Hasso',
        'Meditate',
        'Sekkanoki',
        'Third Eye',

        -- /DNC
        'Haste Samba',
        'Drain Samba',

        -- /NIN
        'Innin',
        'Yonin',

        -- /DRK
        'Last Resort',
        'Souleater',
    },

    -- LEGACY SKILLCHAIN SETTINGS
    -- Retained for compatibility until the new rotation system replaces them.
    ws_sc_starter = { 'Refulgent Arrow', 1000 },
    ws_sc_closers = { 'Empyreal Arrow', "Jishnu's Radiance" },

    ws_sc_chain = {
        { 'Refulgent Arrow', 1000 },
        { 'Empyreal Arrow', 1000 },
        { "Jishnu's Radiance", 1000 },
    },

    food = 'Sublime Sushi',

    -- STUCK RECOVERY
    provoke_if_stuck = false,
    stuck_threshold = 10,
}
