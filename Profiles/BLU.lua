
JOB_PROFILES.BLU = {
    auto_engage = true,
    debuffs_engaged_only = true,
    debuff_hold_hpp = 50,

    use_weaponskills = true,
    weaponskills = {
        min_tp = 1000,

        rotations = {},

        skillchain_options = {
            {
                name = 'Chant du Cygne',
                weapon_skill = 'Chant du Cygne',
                properties = { 'Distortion', 'Light' },
                requires_chain_affinity = true,
            },
            {
                name = 'Expiacion',
                weapon_skill = 'Expiacion',
                properties = { 'Distortion' },
                requires_chain_affinity = true,
                property_confirmation_needed = true,
            },
            {
                name = 'Savage Blade',
                weapon_skill = 'Savage Blade',
                properties = { 'Fragmentation', 'Scission' },
                requires_chain_affinity = false,
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
