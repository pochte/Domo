
-- RUN JOB PROFILE
-- Rune Fencer weaponskill, buff and support-job settings.

JOB_PROFILES.RUN = {
    auto_engage = true,
    debuffs_engaged_only = true,
    debuff_hold_hpp = 50,

    use_weaponskills = true,

    -- WEAPON-SPECIFIC SKILLCHAIN ROTATIONS
    weaponskills = {
        min_tp = 1000,

        rotations = {
            {
                name = 'Great Sword',
                weapon_type = 'Great Sword',
                required_ws = {
                    'Resolution',
                    'Dimidiation',
                },
                sequence = {
                    'Resolution',
                    'Resolution',
                    'Dimidiation',
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
                    'Savage Blade',
                    'Savage Blade',
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
        { name = 'Rune Enchantment', interval = 5 },
        { name = 'Swordplay', interval = 5 },
        { name = 'Valiance', interval = 5 },
        { name = 'Pflug', interval = 5 },
        { name = 'Battuta', interval = 5 },
        { name = 'Liement', interval = 5 },
        { name = 'Embolden', interval = 5 },
        { name = 'One for All', interval = 5 },
        { name = 'Gambit', interval = 5 },
        { name = 'Rayke', interval = 5 },
    },

    dispel = nil,

    magic_burst = false,
    burst_spells = {},

    emergency_cure = false,
    emergency_cure_threshold = 25,
    cure_tiers = {},
}
