
-- BLM JOB PROFILE
-- Black Mage dedicated nuker and magic burster.

JOB_PROFILES.BLM = {
	-- MELEE
	auto_engage = false,
	use_weaponskills = false,

	-- SUPPORT
	haste_active = false,
	self_buffs = {
		{ name = 'Klimaform', interval = 3.2 },
		{ name = 'Windstorm', interval = 3.2 },
	},

	-- DEFENSIVE ABILITIES
	-- Manaward when being attacked.
	-- Manawall before highest-tier nukes when available.
	defensive_abilities = {
		{
			name = 'Manaward',
			trigger = 'being_attacked',
		},
		{
			name = 'Manawall',
			trigger = 'highest_tier_nuke',
		},
	},

	-- NUKING ABILITIES
	-- Elemental Seal when available before nuking.
	nuke_abilities = {
		{
			name = 'Elemental Seal',
			trigger = 'nuke',
		},
	},

	-- POST MAGIC BURST
	-- Use immediately after a successful magic burst.
	post_burst_abilities = {
		'Enmity Douse',
	},

	-- FREE NUKE (//domo freenuke).
	-- Tier IV and lower are cast on the target between bursts.
	-- V and VI are saved for magic burst.
	free_nuke = true,
	free_nuke_max_tier = 4,
	free_nuke_weather = true,

	-- MAGIC BURST
	magic_burst = true,
	burst_spells = {
		Fire      = { 'Fire VI', 'Fire V', 'Fire IV' },
		Blizzard  = { 'Blizzard VI', 'Blizzard V', 'Blizzard IV' },
		Aero      = { 'Aero VI', 'Aero V', 'Aero IV' },
		Stone     = { 'Stone VI', 'Stone V', 'Stone IV' },
		Thunder   = { 'Thunder VI', 'Thunder V', 'Thunder IV' },
		Water     = { 'Water VI', 'Water V', 'Water IV' },
		Darkness  = { 'Comet', 'Impact' },
	},
}
