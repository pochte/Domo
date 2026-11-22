
JOB_PROFILES.PLD = {
    auto_engage = true,
    debuffs_engaged_only = true,
    debuff_hold_hpp = 50,

    use_weaponskills = true,
    weaponskills = {
        min_tp = 1000,

        rotations = {
            {
                name = 'Sword',
                weapon_type = 'Sword',
                required_ws = {
                    'Atonement',
                    'Savage Blade',
                    'Chant du Cygne',
                },
                sequence = {
                    'Atonement',
                    'Savage Blade',
                    'Chant du Cygne',
                },
                priority = 1,
            },
        },
    },

    self_buffs = {},
    debuffs = {},
    party_buffs = {},
    self_abilities = {},

    dispel = nil,

    magic_burst = false,
    burst_spells = {},

    emergency_cure = false,
    emergency_cure_threshold = 25,
    cure_tiers = {},
}
