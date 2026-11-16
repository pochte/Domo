-- SMN JOB PROFILE
-- All the real work (avatar rotation, wards, rage, Favor, Siphon) is in
-- Logic/smn_logic.lua. This file only turns off melee and sets up emergency cure.
JOB_PROFILES.SMN = {
    auto_engage = false,
    use_weaponskills = false,
    haste_active = false,
    self_buffs = {},

    -- Emergency cure only (same failsafe as RDM). Needs a cure-capable sub job;
    -- spells SMN can't cast are skipped automatically.
    emergency_cure = true,
    emergency_cure_threshold = 25,
    cure_tiers = {
        { max_missing = 600, spells = { 'Cure III', 'Cure II', 'Cure' } },
        { max_missing = math.huge, spells = { 'Cure IV', 'Cure III', 'Cure II' } },
    },
}
