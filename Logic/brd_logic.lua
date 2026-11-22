--[[
    DOMO - BARD LOGIC
    ----------------
    Standalone Bard song management.
    Domo owns:
      * Dummy song rotation and extra song slot setup
      * Real song rotation and maintenance
      * Individual party Ballads
      * Enemy Elegy and Threnody
      * Clarion Call, Troubadour, Marcato and Pianissimo
      * Recovery after death, interruption and failed casts
    GearSwap is OPTIONAL.
    Domo never sends GearSwap commands or requires GearSwap-specific modes.
    Required Domo helpers:
      * Can_Cast_Spell(spell_name)
      * Cast_Spell_On(spell_name, target_name)
      * Can_Cast_Ability(ability_name)
      * Cast_Ability(ability_name)
      * Party_Member_In_Range(member, range)
      * Get_Party_Member_Job(member)
    Called independently through:
      BRD_Tick()
    Configuration:
      JOB_PROFILES.BRD
]]
-- CONFIGURATION
local function BRD_Get_Config()
    return active_profile or {}
end
-- STATE
BRD = BRD or {}
BRD.initialized = false
BRD.config = nil
BRD.stage = 'dummy'
BRD.dummy_index = 1
BRD.song_index = 1
BRD.debuff_index = 1
BRD.applied = {}
BRD.party_applied = {}
BRD.waiting = nil
BRD.last_action = 0
BRD.last_ability = {}
BRD.last_enemy = nil
BRD.song_count = 0
BRD.dummy_songs = {}
BRD.songs = {}
BRD.party_songs = {}
BRD.debuffs = {}
BRD.dead = false
BRD.recovery_pending = false
BRD.clarion_done = false
BRD.troubadour_done = false
BRD.marcato_done = false
BRD.pianissimo_ready = false
-- GENERAL HELPERS
local function BRD_Now()
    return os.clock()
end
local function BRD_Lower(value)
    return tostring(value or ''):lower()
end
local function BRD_Is_Busy()
    return isBusy or isCasting or pending_cast ~= nil
end
local function BRD_Get_Player()
    if windower and windower.ffxi and windower.ffxi.get_player then
        return windower.ffxi.get_player()
    end
    return nil
end
local function BRD_Get_Player_Name()
    local player = BRD_Get_Player()
    return player and player.name or nil
end
local function BRD_Get_Spell(name)
    if not name or not res or not res.spells then
        return nil
    end
    return res.spells:with('en', name)
end
local function BRD_Spell_Known(name)
    local spell = BRD_Get_Spell(name)
    if not spell then
        return false
    end
    if windower and windower.ffxi and windower.ffxi.get_spells then
        local known = windower.ffxi.get_spells()
        if known and known[spell.id] ~= nil then
            return known[spell.id] == true
        end
    end
    return true
end
local function BRD_Spell_Ready(name)
    if not name or not BRD_Spell_Known(name) then
        return false
    end
    if type(Can_Cast_Spell) == 'function' then
        return Can_Cast_Spell(name)
    end
    return false
end
local function BRD_Ability_Ready(name)
    if not name then
        return false
    end
    if type(Can_Cast_Ability) == 'function' then
        return Can_Cast_Ability(name)
    end
    return false
end
local function BRD_Get_Ability_Config(name)
    local config = BRD.config or {}
    local abilities = config.abilities or {}
    return abilities[name] == true
end
-- CONFIGURATION VALIDATION
local function BRD_Filter_Known_Songs(list)
    local result = {}
    if type(list) ~= 'table' then
        return result
    end
    for _, name in ipairs(list) do
        if type(name) == 'string' and BRD_Spell_Known(name) then
            result[#result + 1] = name
        end
    end
    return result
end
local function BRD_Validate_Config()
    local config = BRD_Get_Config()
    BRD.config = config
    BRD.dummy_songs = BRD_Filter_Known_Songs(config.dummy_songs)
    BRD.songs = BRD_Filter_Known_Songs(config.songs)
    BRD.party_songs = type(config.party_songs) == 'table'
        and config.party_songs or {}
    BRD.debuffs = BRD_Filter_Known_Songs(config.debuffs)
    local capacity = tonumber(config.song_capacity) or 5
    capacity = math.floor(capacity)
    capacity = math.max(1, math.min(5, capacity))
    BRD.song_count = math.min(
        capacity,
        #BRD.dummy_songs,
        #BRD.songs
    )
    if BRD.song_count < 1 then
        BRD.stage = 'idle'
    end
end
-- INITIALIZATION
function BRD_Initialize()
    BRD.applied = {}
    BRD.party_applied = {}
    BRD.waiting = nil
    BRD.dummy_index = 1
    BRD.song_index = 1
    BRD.debuff_index = 1
    BRD.last_action = 0
    BRD.last_ability = {}
    BRD.last_enemy = nil
    BRD.dead = false
    BRD.recovery_pending = false
    BRD.clarion_done = false
    BRD.troubadour_done = false
    BRD.marcato_done = false
    BRD.pianissimo_ready = false
    BRD_Validate_Config()
    if BRD.song_count > 0 then
        BRD.stage = 'dummy'
    else
        BRD.stage = 'idle'
    end
    BRD.initialized = true
    print('[Domo BRD] Initialized. Song capacity: ' ..
        tostring(BRD.song_count))
end
function BRD_Reset()
    BRD.initialized = false
    BRD_Initialize()
end
-- REFRESH TIMERS
local function BRD_Get_Refresh_Time()
    return tonumber(BRD.config.song_refresh_seconds) or 240
end
local function BRD_Get_Party_Refresh_Time()
    return tonumber(BRD.config.party_song_refresh_seconds) or 180
end
local function BRD_Get_Debuff_Refresh_Time()
    return tonumber(BRD.config.debuff_refresh_seconds) or 60
end
local function BRD_Was_Applied(key, refresh_time)
    local timestamp = BRD.applied[key]
    if not timestamp then
        return false
    end
    return (BRD_Now() - timestamp) < refresh_time
end
local function BRD_Get_Song_Key(stage, index, name)
    return stage .. ':' .. tostring(index) .. ':' .. tostring(name)
end
-- CAST CONFIRMATION
local function BRD_Cast_Confirmed()
    if not BRD.waiting then
        return false
    end
    local waiting = BRD.waiting
    if waiting.store and waiting.key and waiting.store[waiting.key] then
        BRD.waiting = nil
        return true
    end
    if BRD_Is_Busy() then
        return false
    end
    if BRD_Now() - waiting.sent_at < 3 then
        return false
    end
    BRD.waiting = nil
    if waiting.key then
        waiting.store[waiting.key] = nil
    end
    return false
end
local function BRD_Start_Spell(name, target, key)
    if BRD_Is_Busy() then
        return false
    end
    if not BRD_Spell_Ready(name) then
        return false
    end
    if type(Cast_Spell_On) ~= 'function' then
        return false
    end
    local spell = BRD_Get_Spell(name)
    if not spell then
        return false
    end
    pending_cast = {
        store = BRD.applied,
        key = key,
        spell_id = spell.id,
        sent_at = BRD_Now(),
    }
    BRD.waiting = {
        store = BRD.applied,
        key = key,
        sent_at = BRD_Now(),
        spell = name,
        target = target,
    }
    Cast_Spell_On(name, target)
    BRD.last_action = BRD_Now()
    return true
end
-- ABILITIES
local function BRD_Use_Ability(name)
    if not BRD_Ability_Ready(name) then
        return false
    end
    if BRD_Is_Busy() then
        return false
    end
    if type(Cast_Ability) ~= 'function' then
        return false
    end
    Cast_Ability(name)
    BRD.last_ability[name] = BRD_Now()
    BRD.last_action = BRD_Now()
    return true
end
local function BRD_Use_Clarion_Call()
    if BRD.clarion_done then
        return false
    end
    if not BRD_Get_Ability_Config('clarion_call') then
        BRD.clarion_done = true
        return false
    end
    if BRD_Use_Ability('Clarion Call') then
        BRD.clarion_done = true
        return true
    end
    return false
end
local function BRD_Use_Troubadour()
    if BRD.troubadour_done then
        return false
    end
    if not BRD_Get_Ability_Config('troubadour') then
        BRD.troubadour_done = true
        return false
    end
    if BRD_Use_Ability('Troubadour') then
        BRD.troubadour_done = true
        return true
    end
    return false
end
local function BRD_Use_Marcato()
    if BRD.marcato_done then
        return false
    end
    if not BRD_Get_Ability_Config('marcato') then
        BRD.marcato_done = true
        return false
    end
    if BRD_Use_Ability('Marcato') then
        BRD.marcato_done = true
        return true
    end
    return false
end
-- DUMMY SONGS
local function BRD_Cast_Next_Dummy()
    if BRD.dummy_index > BRD.song_count then
        BRD.stage = 'real'
        BRD.song_index = 1
        return false
    end
    local name = BRD.dummy_songs[BRD.dummy_index]
    if not name then
        BRD.stage = 'real'
        return false
    end
    local key = BRD_Get_Song_Key('dummy', BRD.dummy_index, name)
    if BRD_Start_Spell(name, BRD_Get_Player_Name(), key) then
        BRD.dummy_index = BRD.dummy_index + 1
        return true
    end
    return false
end
-- REAL SONGS
local function BRD_Cast_Next_Real_Song()
    if BRD.song_index > BRD.song_count then
        BRD.stage = 'maintenance'
        BRD.song_index = 1
        return false
    end
    local name = BRD.songs[BRD.song_index]
    if not name then
        BRD.stage = 'maintenance'
        return false
    end
    local key = BRD_Get_Song_Key('real', BRD.song_index, name)
    if BRD_Was_Applied(key, BRD_Get_Refresh_Time()) then
        BRD.song_index = BRD.song_index + 1
        return false
    end
    if BRD.song_index == 1 and not BRD.marcato_done then
        if BRD_Use_Marcato() then
            return true
        end
    end
    if BRD_Start_Spell(name, BRD_Get_Player_Name(), key) then
        BRD.song_index = BRD.song_index + 1
        return true
    end
    return false
end
-- SONG MAINTENANCE
local function BRD_Maintain_Songs()
    for index = 1, BRD.song_count do
        local name = BRD.songs[index]
        local key = BRD_Get_Song_Key('real', index, name)
        if not BRD_Was_Applied(key, BRD_Get_Refresh_Time()) then
            BRD.song_index = index
            return BRD_Start_Spell(
                name,
                BRD_Get_Player_Name(),
                key
            )
        end
    end
    return false
end
-- PARTY HELPERS
local BRD_PARTY_KEYS = {
    'p0', 'p1', 'p2', 'p3', 'p4', 'p5',
    'a10', 'a11', 'a12', 'a13', 'a14',
    'a20', 'a21', 'a22', 'a23', 'a24',
}
local function BRD_Get_Party()
    if windower and windower.ffxi and windower.ffxi.get_party then
        return windower.ffxi.get_party()
    end
    return nil
end
local function BRD_Get_Member_Job(member)
    if type(Get_Party_Member_Job) == 'function' then
        return Get_Party_Member_Job(member)
    end
    return member and (member.main_job or member.main_job_name) or nil
end
local function BRD_Is_Player_Member(member)
    if not member or not member.name then
        return false
    end
    if member.is_npc or (member.mob and member.mob.is_npc) then
        return false
    end
    return true
end
local function BRD_Get_Party_Members()
    local party = BRD_Get_Party()
    local members = {}
    if not party then
        return members
    end
    for _, key in ipairs(BRD_PARTY_KEYS) do
        local member = party[key]
        if member and member.name then
            members[#members + 1] = member
        end
    end
    return members
end
local function BRD_Member_In_Range(member)
    if type(Party_Member_In_Range) == 'function' then
        return Party_Member_In_Range(member, 20)
    end
    return false
end
local function BRD_Job_Matches(job, jobs)
    if not job or type(jobs) ~= 'table' then
        return false
    end
    local normalized = BRD_Lower(job)
    for _, allowed in ipairs(jobs) do
        if normalized == BRD_Lower(allowed) then
            return true
        end
    end
    return false
end
-- INDIVIDUAL PARTY SONGS
local function BRD_Cast_Party_Song()
    local members = BRD_Get_Party_Members()
    for _, song_config in ipairs(BRD.party_songs) do
        if song_config.spell and BRD_Spell_Known(song_config.spell) then
            for _, member in ipairs(members) do
                local is_self = member.name == BRD_Get_Player_Name()
                local eligible = true
                if song_config.players_only and not is_self then
                    eligible = BRD_Is_Player_Member(member)
                end
                if song_config.jobs then
                    local job = BRD_Get_Member_Job(member)
                    if not BRD_Job_Matches(job, song_config.jobs) then
                        eligible = false
                    end
                end
                if eligible and BRD_Member_In_Range(member) then
                    local key = 'party:' .. member.name .. ':' .. song_config.spell
                    local refresh = tonumber(song_config.refresh_seconds)
                        or BRD_Get_Party_Refresh_Time()
                    if not BRD_Was_Applied(key, refresh) then
                        if not is_self and BRD_Get_Ability_Config('pianissimo')
                            and not BRD.pianissimo_ready then
                            if BRD_Use_Ability('Pianissimo') then
                                BRD.pianissimo_ready = true
                                return true
                            end
                            return false
                        end
                        if BRD_Start_Spell(
                            song_config.spell,
                            member.name,
                            key
                        ) then
                            BRD.pianissimo_ready = false
                            return true
                        end
                        return false
                    end
                end
            end
        end
    end
    return false
end
-- ENEMY DEBUFFS
local function BRD_Get_Target()
    if windower and windower.ffxi and windower.ffxi.get_mob_by_target then
        return windower.ffxi.get_mob_by_target('t')
    end
    return nil
end
local function BRD_Target_Is_Valid(target)
    if not target or not target.id or not target.name then
        return false
    end
    if target.is_npc == false then
        return false
    end
    if target.hpp and target.hpp <= 0 then
        return false
    end
    return true
end
local function BRD_Cast_Enemy_Debuff()
    if #BRD.debuffs == 0 then
        return false
    end
    local target = BRD_Get_Target()
    if not BRD_Target_Is_Valid(target) then
        return false
    end
    if BRD.last_enemy ~= target.id then
        BRD.last_enemy = target.id
    end
    for _, name in ipairs(BRD.debuffs) do
        local key = 'enemy:' .. tostring(target.id) .. ':' .. name
        if not BRD_Was_Applied(key, BRD_Get_Debuff_Refresh_Time()) then
            return BRD_Start_Spell(name, target.name, key)
        end
    end
    return false
end
-- DEBUFF REFRESH TIMER
function BRD_Get_Debuff_Refresh_Time()
    return tonumber(BRD.config.debuff_refresh_seconds) or 60
end
-- DEATH AND RECOVERY
local function BRD_Check_Death()
    local player = BRD_Get_Player()
    if not player then
        return
    end
    local is_dead = player.status == 2
    if is_dead and not BRD.dead then
        BRD.dead = true
        BRD.applied = {}
        BRD.party_applied = {}
        BRD.waiting = nil
        BRD.recovery_pending = true
        BRD.dummy_index = 1
        BRD.song_index = 1
        BRD.stage = 'dummy'
    elseif not is_dead and BRD.dead then
        BRD.dead = false
        BRD.recovery_pending = true
        BRD.dummy_index = 1
        BRD.song_index = 1
        BRD.stage = 'dummy'
        BRD.troubadour_done = false
        BRD.marcato_done = false
        BRD.clarion_done = false
    end
end
-- MAIN ROTATION
local function BRD_Run_Rotation()
    if BRD_Is_Busy() then
        return
    end
    if BRD.waiting then
        BRD_Cast_Confirmed()
        if BRD.waiting then
            return
        end
    end
    if BRD.stage == 'dummy' then
        if not BRD.clarion_done then
            if BRD_Use_Clarion_Call() then
                return
            end
        end
        if not BRD.troubadour_done then
            if BRD_Use_Troubadour() then
                return
            end
        end
        BRD_Cast_Next_Dummy()
        return
    end
    if BRD.stage == 'real' then
        BRD_Cast_Next_Real_Song()
        return
    end
    if BRD.stage == 'maintenance' then
        if BRD_Maintain_Songs() then
            return
        end
        if BRD_Cast_Party_Song() then
            return
        end
        BRD_Cast_Enemy_Debuff()
        return
    end
end
-- PUBLIC TICK
function BRD_Tick()
    if current_job ~= 'BRD' then
        return
    end
    if not BRD.initialized then
        BRD_Initialize()
    end
    if BRD.config ~= active_profile then
        BRD_Reset()
    end
    if settings and settings.buffs_active == false then
        return
    end
    BRD_Check_Death()
    if BRD.dead then
        return
    end
    if BRD_Is_Busy() then
        return
    end
    BRD_Run_Rotation()
end