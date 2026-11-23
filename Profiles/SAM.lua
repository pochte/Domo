-- WEAPON-SPECIFIC SKILLCHAIN ROTATIONS
JOB_PROFILES = JOB_PROFILES or {}

JOB_PROFILES.SAM = {
weaponskills = {
    min_tp = 1000,

    rotations = {
        {
            name = 'Light (2-Step) - Kasha > Fudo',
            weapon_type = 'Great Katana',
            required_ws = {
                'Tachi: Kasha',
                'Tachi: Fudo',
            },
            sequence = {
                { name = 'Tachi: Kasha', min_tp = 1000 },
                { name = 'Tachi: Fudo', min_tp = 1000 },
            },
            priority = 2,
        },
        {
            name = 'Light (2-Step) - Shoha > Kasha',
            weapon_type = 'Great Katana',
            required_ws = {
                'Tachi: Shoha',
                'Tachi: Kasha',
            },
            sequence = {
                { name = 'Tachi: Shoha', min_tp = 1000 },
                { name = 'Tachi: Kasha', min_tp = 1000 },
            },
            priority = 1,
        },
        {
            name = 'Light (4-Step)',
            weapon_type = 'Great Katana',
            required_ws = {
                'Tachi: Ageha',
                'Tachi: Yukikaze',
                'Tachi: Kasha',
                'Tachi: Fudo',
            },
            sequence = {
                { name = 'Tachi: Ageha', min_tp = 1000 },
                { name = 'Tachi: Yukikaze', min_tp = 1000 },
                { name = 'Tachi: Kasha', min_tp = 1000 },
                { name = 'Tachi: Fudo', min_tp = 1000 },
            },
            priority = 4,
        },
        {
            name = 'Darkness (3-Step)',
            weapon_type = 'Great Katana',
            required_ws = {
                'Tachi: Rana',
                'Tachi: Fudo',
            },
            sequence = {
                { name = 'Tachi: Rana', min_tp = 1000 },
                { name = 'Tachi: Fudo', min_tp = 1000 },
                { name = 'Tachi: Fudo', min_tp = 1000 },
            },
            priority = 3,
        },
        {
            name = 'Darkness (4-Step)',
            weapon_type = 'Great Katana',
            required_ws = {
                'Tachi: Jinpu',
                'Tachi: Kasha',
                'Tachi: Rana',
                'Tachi: Fudo',
            },
            sequence = {
                { name = 'Tachi: Jinpu', min_tp = 1000 },
                { name = 'Tachi: Kasha', min_tp = 1000 },
                { name = 'Tachi: Rana', min_tp = 1000 },
                { name = 'Tachi: Fudo', min_tp = 1000 },
            },
            priority = 5,
        },
    },
},
}