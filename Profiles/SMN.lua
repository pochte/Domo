
-- SMN JOB PROFILE
-- Avatar rotation, wards, rage, Favor and Siphon are handled by
-- Logic/smn_logic.lua.

JOB_PROFILES.SMN = {
	auto_engage = false,
	use_weaponskills = false,
	haste_active = false,
	self_buffs = {},

	-- AUTOMATIC CURING
	-- Provide party healing when no WHM is present.
	cure_bot_if_no_whm = true,

	cure_tiers = {
		{ max_missing = 250,  spells = { 'Cure II', 'Cure' } },
		{ max_missing = 600,  spells = { 'Cure III', 'Cure II' } },
		{ max_missing = 1100, spells = { 'Cure IV', 'Cure III' } },
		{ max_missing = math.huge, spells = { 'Cure IV', 'Cure III' } },
	},

	-- EMERGENCY SELF-CURE
	-- Needs a cure-capable sub job.
	emergency_cure = true,
	emergency_cure_threshold = 25,
}
