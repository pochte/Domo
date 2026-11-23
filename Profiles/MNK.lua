
-- MNK JOB PROFILE
-- Monk weaponskill, buff and support-job settings.

JOB_PROFILES.MNK = {
    auto_engage = true,
    debuffs_engaged_only = true,
    debuff_hold_hpp = 50,

    use_weaponskills = true,

    -- WEAPON-SPECIFIC SKILLCHAIN ROTATIONS
    weaponskills = {
        min_tp = 1000,

        rotations = {
            {
                name = 'Hand-to-Hand',
                weapon_type = 'Hand-to-Hand',
                required_ws = {
                    'Shijin Spiral',
                    'Victory Smite',
                },
                sequence = {
                    { name = 'Shijin Spiral', min_tp = 1000 },
                    { name = 'Victory Smite', min_tp = 1000 },
                    { name = 'Victory Smite', min_tp = 1000 },
                },
                priority = 1,
            },
        },
    },

    -- BUFFS
    needed_buffs = {
        'Boost',
        'Focus',
        'Dodge',
        'Counterstance',
        'Footwork',
        'Impetus',
        'Mantra',
    },

    -- SELF BUFFS
    self_buffs = {},

    -- DEBUFFS
    debuffs = {},

    -- PARTY BUFFS
    party_buffs = {},

    -- JOB ABILITIES
    self_abilities = {
        -- Native MNK abilities and support-job abilities
        -- to be configured by the expanded buff logic.
    },

    dispel = nil,

    magic_burst = false,
    burst_spells = {},

    emergency_cure = false,
    emergency_cure_threshold = 25,
    cure_tiers = {},

    food = 'Soy Ramen',
}
