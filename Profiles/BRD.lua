JOB_PROFILES.BRD = {
    auto_engage = true,

    song_capacity = 5,

    -- How often Domo refreshes songs.
    song_refresh_seconds = 240,
    party_song_refresh_seconds = 180,
    debuff_refresh_seconds = 60,

    dummy_songs = {
        "Knight's Minne V",
        "Knight's Minne IV",
        "Army's Paeon VI",
        "Army's Paeon V",
        "Archer's Prelude",
    },

    songs = {
        'Honor March',
        'Valor Minuet V',
        'Valor Minuet V',
        'Blade Madrigal',
        'Aria of Passion',
    },

    party_songs = {
        {
            spell = 'Mage\'s Ballad III',
            targets = {
                players_only = true,
                jobs = { 'WHM', 'RDM', 'BLM', 'GEO', 'SCH', 'SMN' },
            },
        },
    },

    debuffs = {
        'Carnage Elegy',
        'Wind Threnody',
    },

    abilities = {
        clarion_call = true,
        troubadour = true,
        marcato = true,
        pianissimo = true,
    },
}