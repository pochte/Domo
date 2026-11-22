
JOB_PROFILES.DRG = {
    auto_engage = true,
    debuffs_engaged_only = true,
    debuff_hold_hpp = 50,

    use_weaponskills = true,
    weaponskills = {
        min_tp = 1000,

        rotations = {
            {
                name = 'Prime Polearm',
                weapon_type = 'Polearm',
                required_ws = { 'Diarmuid' },
                sequence = {
                    'Diarmuid',
                    'Diarmuid',
                    'Diarmuid',
                },
                priority = 3,
            },
            {
                name = 'Relic Polearm',
                weapon_type = 'Polearm',
                required_ws = { 'Geirskogul' },
                sequence = {
                    'Geirskogul',
                    'Drakesbane',
                    "Camlann's Torment",
                    "Camlann's Torment",
                },
                priority = 2,
            },
            {
                name = 'Standard Polearm',
                weapon_type = 'Polearm',
                required_ws = {
                    'Drakesbane',
                    "Camlann's Torment",
                },
                sequence = {
                    'Drakesbane',
                    "Camlann's Torment",
                    "Camlann's Torment",
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
