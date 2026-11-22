# Lazy

A Windower addon for automating FFXI farming while you're away from the keyboard.

Lazy hunts mobs, fights, manages job abilities and spells, maintains buffs, heals the party, and handles Trust recovery. It can also coordinate multiple Lazy characters through party chat.

## Features

- **Combat and targeting:** Hunts around a starting position, follows targets, faces enemies correctly, and supports leader and follower modes.
- **Weaponskills:** Uses weaponskills when TP is available, with configurable skillchains of up to five steps and partychain support.
- **Magic:** Spell casting, magic bursts, and BLM/SCH free nuking with elemental weaknesses and a weather failsafe.
- **Job profiles:** Main-job-aware behavior for buffs, debuffs, cures, abilities, food, weaponskills, and magic.
- **Healing:** Cure bot, emergency cures, mage resting, and party debuff cleansing.
- **Trust management:** Tracks Trusts, resummons fallen Trusts, and can rebalance the party when players join.
- **Party coordination:** Remote party commands, automatic raises, Doom handling, regrouping, and warping home.
- **Session statistics:** Tracks kills, EXP, limit points, and EXP per hour.

---

## Installation

1. Open your Windower `Addons` folder.
2. Create a folder named `Lazy`.
3. Copy the addon files into it, preserving the folder structure.

```text
Lazy/
├── Lazy.lua
├── settings.lua
├── skills.lua
├── profiles/
│   ├── RDM.lua
│   ├── WHM.lua
│   └── ...
├── Logic/
│   ├── TargetLogic.lua
│   ├── TrustLogic.lua
│   ├── PartyCommands.lua
│   ├── JobLogic.lua
│   ├── HealBuffLogic.lua
│   ├── RestLogic.lua
│   ├── dnc_logic.lua
│   ├── rolls.lua
│   ├── smn_logic.lua
│   ├── skillchain.lua
│   └── magicburst.lua
├── debug/
│   └── Debug.lua
└── data/
    ├── settings.xml
    └── trusted_players.txt
```

**Private data:** `data/settings.xml` and `data/trusted_players.txt` are character-specific files. Keep them out of the repository and add both to `.gitignore`.

---

## Commands

All commands use `//lazy`.

| Command | Description |
|---|---|
| `start` / `stop` | Start or stop Lazy |
| `reload` | Reload the addon and restart if it was running |
| `save` | Save the current character's settings |
| `show` | Display current settings and modes |
| `debug on\|off` | Toggle debug logging |
| `leader` | Enable leader mode and automatic targeting |
| `follower [name]` | Assist a player, or the party leader if omitted |
| `semiauto` | Semi-Auto mode: you pick targets, walk and engage; Lazy fights once you are engaged |
| `autotarget on\|off` | Toggle automatic hunting |
| `target "Monster"` | Hunt a specific monster name |
| `fight` | Set the current target as the hunting target |
| `range <yalms>` | Set or display the hunting radius |
| `buffs on\|off` | Toggle buff maintenance |
| `cure on\|off` | Toggle the cure bot |
| `rest on\|off` | Toggle mage resting |
| `burstmode` | Magic bursts only |
| `freenuke` | Enable BLM/SCH free nuking |
| `nukeoff` | Disable automatic nuking |
| `chainmode` | Use the configured full skillchain |
| `openmode` | Use opener and closer weaponskills |
| `partychain` | Continue party skillchains |
| `retrust` | Refresh the Trust lineup snapshot |
| `join <name>` | Invite a player using the party-join flow |
| `join cancel` | Cancel a party join in progress |
| `sync <name>` | Request level sync to a party member |
| `sync off` | Turn level sync off |
| `trust add <name>` | Add a trusted player |
| `trust remove <name>` | Remove a trusted player |
| `trust list` | Show trusted players |
| `trust clear` | Clear the list (allow everyone again) |
| `tnl` | Display session statistics |
| `party <phrase>` | Run a party command on this character only |

### Startup behavior

`//lazy start` records your current position as the hunting origin, loads your main-job profile, snapshots your Trusts, and starts the combat and monitoring loops.

If neither follower mode nor a custom targeting mode is selected, Lazy defaults to leader mode with autotarget enabled.

Lazy will not start while your character is dead. If you die while running, it can request a raise through party chat and accept the raise automatically. The party waits for Weakness to wear off before resuming.

`//lazy reload` saves current settings, reloads the addon and its profiles, and restarts Lazy if it was running.

---

## Targeting and combat

Lazy can run in two main modes:

- **Leader:** Automatically finds eligible monsters around the starting position.
- **Follower:** Assists a specified player or the party leader. Autotarget is disabled.
- **Semi-Auto:** You pick targets, walk and engage by hand. Once you are engaged Lazy runs the same combat logic as the other modes and may move to keep the fight going; buffs, cures and other support logic always run. Lazy never selects a target, walks you anywhere or engages before you do, and it only acts offensively on a mob that is engaged or already claimed by your party. `regroup` just prints "go join everyone else".

The hunting radius is controlled by `//lazy range` (default 10 yalms). Targeting rules, including eligible monsters and whether claimed or defeated mobs are ignored, are configured in `settings.lua`.

`//lazy fight` sets the currently selected monster as the hunting target. `//lazy target "Monster"` sets a specific monster name instead.

Job profiles control whether a character engages in melee, uses weaponskills, casts spells, or stays out of combat.

## Weaponskills and skillchains

Lazy supports three weaponskill approaches:

- **Chain mode:** Uses an ordered `ws_sc_chain` of up to five weaponskills.
- **Open mode:** Uses `ws_sc_starter` to open and `ws_sc_closers` to continue a skillchain.
- **Partychain:** Opens a chain, then chooses a weaponskill that continues the currently open chain, even if another player started it.

A weaponskill entry can be a name or a name with a minimum TP requirement:

```lua
ws_sc_chain = {
    { 'Savage Blade', 2000 },
    'Aeolian Edge',
    'Evisceration',
    "Rudra's Storm",
    'Exenterator',
}
```

These settings can be defined in a job profile or in `settings.lua`. Profile values take priority.

## Magic and nuking

Magic bursts happen at the end of a skillchain rather than immediately when a window opens. Lazy waits for the chain to close or remain untouched for the configured quiet period.

Supported bursting jobs include BLM, SCH, GEO, RDM, WHM, and profiles with appropriate magic-burst support.

BLM and SCH also support free nuking:

- **Burst mode:** Nukes only during magic-burst windows.
- **Free nuke:** Uses tier IV and lower spells between bursts, based on the target's elemental weakness. Higher-tier spells are reserved for bursts.

The free-nuke system can use a configured default element and has a SCH weather failsafe that casts the matching Storm when needed.

Relevant settings include `burst_when`, `burst_quiet`, `burst_elements`, `nuke_weakness`, and `nuke_default`.

---

## Party join: "chicken nuggets"

A player can join a running Lazy party by sending a tell containing the configured phrase. The default phrase is:

```text
chicken nuggets
```

The phrase can appear alongside other words, and capitalization or punctuation does not matter.

Lazy must be running to respond. The join process:

1. Pauses new pulls and lets an active fight finish.
2. Makes room by dismissing Trusts if necessary.
3. Invites the player and waits for them to accept.
4. Reads their job and master level, then requests level sync when appropriate.
5. Rebalances the Trust lineup to fit the new party member.
6. Resumes normal operation.

Trusts matching the new player's job are prioritized for removal; otherwise, Lazy uses `trust_sacrifice_order`.

Only players with master level 1 or higher are considered for automatic level-sync selection.

You can also initiate the same process manually:

```text
//lazy join PlayerName
//lazy join cancel
```

### Trusted players

Party-chat commands and party-join requests use the same trusted-player list, stored in:

```text
data/trusted_players.txt
```

The list is private to your installation and persists between sessions.

- An empty list allows everyone.
- Once the list contains names, only those players can issue party commands or request a join.
- Real players are automatically added when they join your party.
- Previously trusted players remain trusted after leaving.
- A player already in your party can use the join phrase to be added to the trusted list.

Manage the list in game:

```text
//lazy trust add PlayerName
//lazy trust remove PlayerName
//lazy trust list
//lazy trust clear
```

If an older trusted-player setting exists, Lazy imports it when the trusted-player file is first created.

---

## Party commands

Every running Lazy character listens for configured phrases in party chat. Each character checks the sender against its own trusted-player list.

Say the phrase as the **entire party-chat line**. For example:

```text
/p reset
/p hold
/p regroup
/p resume
/p go home
```

| Phrase | Action |
|---|---|
| `reset` | Re-anchor the hunting origin and clear abandoned-target tracking |
| `go home` | Warp out, stop Lazy, and print session statistics |
| `stop` / `start` | Stop or start Lazy |
| `hold` | Stop new pulls and allow current fights to finish |
| `resume` | Resume operation with a new origin |
| `regroup` | Move everyone to the party leader and hold (Semi-Auto characters only get a message) |
| `rebuff` | Reset buff timers so buffs are recast |
| `tnl` | Print session statistics |
| `trust dismiss <name>` | Everyone holds. The party leader dismisses that trust and stops tracking it so it is not resummoned. Say `resume` when done |
| `trust summon <name>` | The party leader summons that trust (needs a free slot) and tracks it for resummon |

Phrases can be renamed in `settings.lua` under `party_commands.phrases`.

`//lazy party <phrase>` runs a party command on the current character only.

### Raises, Doom and debuff cleansing

These systems work automatically while Lazy is running:

- **Raises:** Party members coordinate raises, prioritizing WHM, SCH, RDM, PLD, then jobs with a raising subjob. The raised character accepts the raise and the party waits for Weakness to wear off.
- **Doom:** A doomed character uses Holy Water when available and requests Cursna from party members who can cast it.
- **Debuff cleansing:** WHM and SCH (main or sub) remove supported status effects from nearby party members. `cleanse_ignore` can exclude specific effects; Evasion Down is ignored by default.

Cleansing requires the cure system to be enabled.

### Go home

`go home` attempts to use a warp item in this order:

1. Warp Ring
2. Treat Staff
3. Warp Cudgel
4. Instant Warp

The item list can be changed with `party_commands.go_home_items`. If no warp method is available, Lazy logs out.

---

## Job profiles

Lazy detects the main job and loads the corresponding file from `profiles/`. Profiles define combat behavior, buffs, debuffs, weaponskills, cures, magic bursts, abilities, and food.

Current profiles:

| Job | Main behavior |
|---|---|
| RDM | Melee, buffs, debuffs, Dispel, magic bursts and emergency cures |
| WHM | Healing, party buffs and Light magic bursts; no melee |
| BLM | Magic bursts and optional free nuking; no melee |
| SCH | Magic bursts, free nuking and conditional healing |
| GEO | Indi/Geo buffs, Frailty, Luopan maintenance, Entrust and magic bursts |
| BRD | Party songs |
| COR | Rolls and Wildfire opener |
| DNC | Dancer rotation and Haste Samba |
| NIN | Buffs and magic bursts with configured weaponskills |
| THF | Sneak Attack, Trick Attack, Box Step and weaponskills |
| WAR | Buffs, provoke and weaponskills |
| SMN | Avatar wards, rage pacts, Favor, Elemental Siphon and emergency cures |

Jobs without a profile use `DEFAULT`, which does not engage or use weaponskills.

To add a job, create `profiles/<JOB>.lua` and add it to the profile list in `Lazy.lua`.

Job-specific logic is loaded from `Logic/` when required. For example, DNC uses `dnc_logic.lua`, COR uses `rolls.lua`, and SMN uses `smn_logic.lua`.

---

## Configuration and data

### `settings.lua`

Shared configuration edited by hand. It contains defaults and rules used across characters, including:

- Targeting and hunting rules
- Weaponskill and skillchain defaults
- Buffs, food and abilities
- Magic-burst and free-nuke settings
- Party join and Trust configuration
- Party commands, raise behavior and cleansing rules

Reload changes with `//lazy reload`.

### `data/settings.xml`

Per-character settings saved by `//lazy save` and loaded when the addon starts.

Settings can have a `<global>` section and character-specific sections. Character settings override global values.

This file stores individual character preferences such as the current target, assist target, spell settings, and whether buffs, curing and resting are enabled.

### `data/trusted_players.txt`

Private persistent list of players allowed to use party commands and request party joins. Managed in game with `//lazy trust`.

Both data files should be excluded from version control.

---

## Session statistics

`//lazy tnl` displays:

- Session duration
- Kills
- EXP and EXP per hour
- Limit points
- EXP remaining to the next level
- Estimated time to level

Statistics begin when `//lazy start` runs. A kill is counted when it awards EXP or limit points.

The same statistics are printed when using `go home`.

---

## Debugging

Use:

```text
//lazy debug on
//lazy debug off
```

Debug output includes target changes, `/attack` safety-gate traces, and relevant party permission packets. Additional logs are written to `TargetLogic_Debug.txt`.

The `/attack` safety gate is always active, even when debug logging is disabled.

For issues, include the relevant `[Lazy]` chat output and debug log when reporting a problem.