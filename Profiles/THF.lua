-- THF JOB PROFILE
JOB_PROFILES.THF = {
	auto_engage = true,
	use_weaponskills = true,
	haste_active = false,
	self_buffs = {},
needed_buffs = {
	'Conspirator',
	'Sneak Attack',
	'Trick Attack',
	'Box Step',
	'Reverse Flourish',
	'Haste Samba',
	'Bully',
	'Feint',
},
	ws_sc_starter = {
		"Rudra's Storm",
		1000,
	},
	ws_sc_closers = {
		"Rudra's Storm",
	},

	ws_sc_chain = {
		{ "Rudra's Storm", 1000 },
		{ 'Evisceration', 1000 },
		{ "Rudra's Storm", 1000 },
	},
	-- Per-ability rules for needed_buffs (all optional):
	--   interval             = minimum seconds between attempts (default 15)
	--   min_finishing_moves  = only try when you hold at least this many
	needed_buff_rules = {
		['Box Step'] = { interval = 40 },
		['Reverse Flourish'] = { min_finishing_moves = 3 },
	},
	food = 'Soy Ramen',
}
