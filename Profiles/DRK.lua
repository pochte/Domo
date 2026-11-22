
JOB_PROFILES.DRK = {
    auto_engage = true,
    debuffs_engaged_only = true,
    debuff_hold_hpp = 50,

    use_weaponskills = true,
    weaponskills = {
        min_tp = 1000,

        rotations = {
            {
                name = 'Prime Great Sword',
                weapon_type = 'Great Sword',
                required_ws = { 'Origin', 'Caladbolg' },
                sequence = {
                    'Origin',
                    'Origin',
                    'Origin',
                    'Caladbolg',
                },
                priority = 3,
            },
            {
                name = 'Great Sword',
                weapon_type = 'Great Sword',
                required_ws = { 'Torcleaver' },
                sequence = {
                    'Torcleaver',
                    'Torcleaver',
                },
                priority = 2,
            },
            {
                name = 'Mythic Scythe',
                weapon_type = 'Scythe',
                required_ws = {
                    'Insurgency',
                    'Entropy',
                    'Cross Reaper',
                    'Quietus',
                },
                sequence = {
                    'Insurgency',
                    'Entropy',
                    'Cross Reaper',
                    'Quietus',
                },
                priority = 1,
            },
        },
    },

    self_buffs = {},

    debuffs = {},

    party_buffs = {},

    self_abilities = {
        { name = 'Last Resort', interval = 5 },
        { name = 'Hasso', interval = 5 },
        { name = 'Meditate', interval = 5 },
    },

    dispel = nil,

    magic_burst = false,
    burst_spells = {},

    emergency_cure = false,
    emergency_cure_threshold = 25,
    cure_tiers = {},
}
