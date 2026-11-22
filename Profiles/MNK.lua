
-- MNK JOB PROFILE
-- Monk weaponskill, buff and support-job settings.

JOB_PROFILES.MNK = {
    auto_engage = true,
    debuffs_engaged_only = true,
    debuff_hold_hpp = 50,

    use_weaponskills = true,
    weaponskills = {
        min_tp = 1000,

        rotations = {
            {
                name = 'Farming',
                weapon_type = 'Hand-to-Hand',
                required_ws = {
                    'Shijin Spiral',
                    'Victory Smite',
                },
                sequence = {
                    'Shijin Spiral',
                    'Victory Smite',
                    'Victory Smite',
                },
                priority = 1,
            },
        },
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
}
