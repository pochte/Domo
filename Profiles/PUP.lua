
JOB_PROFILES.PUP = {
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
                required_ws = { 'Shijin Spiral', 'Victory Smite' },
                sequence = {
                    'Shijin Spiral',
                    'Victory Smite',
                    'Victory Smite',
                },
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
