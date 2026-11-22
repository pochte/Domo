
-- WHM JOB PROFILE
-- White Mage primary healing and support.
JOB_PROFILES.WHM = {
	-- ENGAGE
	auto_engage = false,
	use_weaponskills = false,

	-- BUFFS
	haste_active = false,
	self_buffs = {
		{ name = 'Protectra V', interval = 30 },
		{ name = 'Shellra V', interval = 30 },
		{ name = 'Auspice', interval = 5 },
		-- Party bar-spell (AoE). Change to 'Baraero' if you prefer single-target.
		{ name = 'Baraera', interval = 5 },
		{ name = 'Boost-STR', interval = 3 },
		{ name = 'Reraise IV', fallback = 'Reraise III', interval = 60 },
		{ name = 'Aurorastorm II', fallback = 'Aurorastorm', interval = 3.2 },
	},

	-- Soft top-up: cast Regen when someone is missing HP but not enough for a cure.
	-- min_hpp / max_hpp are inclusive. interval is minutes between regens on the same person.
	regen = {
		spell = 'Regen IV',
		fallback = 'Regen III',
		min_hpp = 75,
		max_hpp = 99,
		interval = 1.5,
		range = 20,
		self = true,
	},

	-- CURE BOT
	cure_bot_active = true,
	cure_tiers = {
		{ max_missing = 250,  spells = { 'Cure II', 'Cure' } },
		{ max_missing = 600,  spells = { 'Cure III', 'Cure II' } },
		{ max_missing = 1100, spells = { 'Cure IV', 'Cure III' } },
		{ max_missing = 1700, spells = { 'Cure V', 'Cure IV' } },
		{ max_missing = math.huge, spells = { 'Cure VI', 'Cure V' } },
	},

	job_abilities = {},

	-- MAGIC BURST
	-- Holy and Holy II burst Light, Radiance, Fusion and Transfixion.
	magic_burst = true,
	burst_spells = {
		Light = { 'Holy II', 'Holy' },
	},
}
