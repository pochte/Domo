# Domo

A Windower addon for automating FFXI farming while you're away from the keyboard.

**Domo arigato, Mr. Roboto.**

Domo hunts mobs, fights, manages job abilities and spells, maintains buffs, heals the party, and handles Trust recovery. Multiple characters can coordinate through party chat. A clickable Domo face icon opens and closes the UI.

---

## Features

- **Play modes:** Leader (auto-hunt), Follower (assist someone), Semi-Auto (you engage; Domo fights after that).
- **Camp / Free Roam:** Stay near a camp origin, or roam freely within radius.
- **Combat and targeting:** Origin-based hunting, pull fallbacks, needed-buff gates that never stall forever.
- **Weaponskills:** Full chain, opener-only, or party skillchain continuation.
- **Magic:** Bursts, BLM/SCH free nuking, weather failsafe.
- **Job profiles:** Per-job buffs, debuffs, cures, abilities, food, weaponskills, and magic.
- **Healing:** Automatic curing, emergency cures, mage resting, party debuff cleansing.
- **Trust management:** Tracks Trusts seen while running, resummons fallen ones, leader can summon/dismiss via party chat.
- **Party coordination:** Start / Stop / Hold / Go Home, auto-follow when a Leader starts, raises, Doom handling.
- **Session stats:** Kills, EXP, limit points, exemplar points, capacity points, and per-hour rates.
- **UI:** Tabbed panel (Controls, Party Trusts, Settings) plus a always-on launcher icon.

---

## Installation

1. Open your Windower `addons` folder.
2. Create a folder named `Domo` (or replace an existing one).
3. Copy the addon files in, preserving the structure.

```text
Domo/
├── Domo.lua
├── settings.lua
├── skills.lua
├── ReadMe.md
├── Profiles/          (job profiles: WAR, WHM, BLM, …)
├── Logic/
│   ├── Targeting/     (split target/combat modules)
│   ├── CampLogic.lua
│   ├── PartyCommands.lua
│   ├── TrustLogic.lua
│   ├── PlayMode.lua
│   └── …
├── ui/
│   ├── UI.lua
│   └── assets/
│       ├── domologo.png   ← launcher icon
│       ├── Bar.png, BarBG.png, Hover.png
│       ├── ffxi/          (panel skin)
│       └── ffxiv/
├── debug/
│   └── Debug.lua
└── data/              (created at runtime; keep private)
    ├── settings.xml
    ├── trusted_players.txt
    ├── known_trusts.txt
    └── ui_pos.txt
```

**Private data:** anything under `data/` is character/install specific. Keep it out of shared repos (`.gitignore` already covers the usual files).

Load in game:

```text
//lua load Domo
```

Or add `lua load Domo` to your Windower init script.

---

## Launcher icon and UI

On load, a **Domo face icon** appears on screen (default near the left side).

| Action | Result |
|--------|--------|
| **Click** the icon | Show or hide the Domo panel |
| **Drag** the icon | Reposition it (saved) |
| Panel **X** | Hide the panel (icon stays) |
| Mouse wheel over the panel | Scale the panel |
| Drag the panel | Move it |

Commands:

```text
//domo ui          Toggle the panel
//domo ui show
//domo ui hide
//domo ui reset    Reset panel position/scale/tab
//domo ui skin ffxi|ffxiv
```

### Tabs

1. **Controls** — party Start/Stop/Hold/Stats/Go Home, character toggles, modes, targeting.
2. **Party Trusts** — dismiss trusts in the party; summon from the list of trusts Domo has *actually seen* while running (`data/known_trusts.txt`).
3. **Settings** — skin, radius, save, reload, trusted players, invite phrase.

### Modes (Controls → THIS CHARACTER: modes)

| Control | Options |
|---------|---------|
| **Mode** | Semi → Leader → Follow (Follow is skipped when you are alone / the only real party member) |
| **Nukes** | Free Nuke / Burst Only / Off |
| **Skillchain** | Full Chain / Party Chain / Opener Only |
| **Camp** | Free Roam / Camp Mode |

---

## Play modes

| Mode | Behavior |
|------|----------|
| **Leader** | Autotarget and engage. On **Start**, says `I'm the Leader` in party chat so other Domo clients switch to Follower and assist you. |
| **Follower** | Assists a named player (or the party leader). Stays idle until the leader has started. |
| **Semi-Auto** | You choose targets, move, and engage. Domo only runs combat *after* you are engaged. Unaffected by `I'm the Leader`. |

```text
//domo leader
//domo follower [name|<t>]
//domo semiauto
```

---

## Commands

All commands use `//domo`.

| Command | Description |
|---------|-------------|
| `start` / `stop` | Start or stop Domo (Start also does a group reset) |
| `reload` | Reload the addon; restarts if it was running |
| `save` | Save this character's settings |
| `show` | Print current settings and modes |
| `debug on\|off` | Toggle debug logging |
| `leader` / `follower` / `semiauto` | Play mode |
| `autotarget on\|off` | Toggle automatic hunting (Leader) |
| `target "Monster"` / `fight` | Lock onto a monster name / current target |
| `range <yalms>` | Hunting radius |
| `buffs` / `cure` / `rest` `on\|off` | Support toggles |
| `burstmode` / `freenuke` / `nukeoff` | Nuke modes |
| `chainmode` / `openmode` / `partychain` | Skillchain modes |
| `camp` / `free` | Camp Mode or Free Roam (`//domo camp`, `//domo free` if wired) |
| `stuck` | Emergency regroup toward the leader / new camp after the fight |
| `retrust` | Refresh Trust snapshot |
| `addtrust "Name"` | Add a trust name to the known list |
| `join <name>` / `join cancel` | Party-join flow |
| `sync <name>` / `sync off` | Level sync |
| `trust add\|remove\|list\|clear` | Trusted players for party commands |
| `tnl` | Session statistics |
| `setphrase …` | Change the tell-join phrase |
| `party <phrase>` | Run a party phrase on this character only |
| `ui …` | Panel show/hide/reset/skin |

### Startup

`//domo start` (or the **Start** button / party `start`):

1. Records origin, clears combat locks, resets buff timers and session depletes.
2. Loads the main-job profile and snapshots Trusts.
3. Starts combat and support monitors.
4. If this character is in **Leader** mode: `/p I'm the Leader`.
5. If announcing to the party: `/p start` so other Domo clients restart together.

Followers walk toward the leader when they receive a group start, then resume.

Domo will not start while dead. On death it can request a raise and wait for Weakness.

---

## Party commands

Say the phrase as the **whole party line**. Only trusted senders are accepted (empty trust list = everyone).

| Phrase | Action |
|--------|--------|
| `start` | Group start: clear hold, reset buff timers, followers regroup on leader, resume combat |
| `stop` | Stop Domo; print what ran out + final session stats |
| `hold` | Pause new pulls until the next `start` |
| `tnl` | Print session statistics |
| `go home` | Warp out, stop, print stats |
| `trust dismiss <name>` | Leader dismisses that Trust (party holds) |
| `trust summon <name>` | Leader summons that Trust if known; otherwise says `Sorry, don't have <name>.` |

Legacy phrases `reset`, `rebuff`, `regroup`, and `resume` still work: they all map to **start**.

Phrases can be renamed in `settings.lua` under `party_commands.phrases`.

### Join by tell

Default phrase (change with `//domo setphrase`):

```text
chicken nuggets
```

A tell containing that phrase invites the player, makes Trust room if needed, level-syncs when appropriate, and resumes.

### Raises, Doom, cleansing

Automatic while Domo is running: coordinated raises, Holy Water / Cursna for Doom, WHM/SCH status cleansing. Cleansing needs cure enabled.

### Go home

Uses the first usable warp item (Warp Ring, Instant Warp, Dimensional Rings, Tavnazian Ring, etc.). Order is configurable in `settings.lua`. `//domo warpcheck` lists what you can use without consuming anything.

---

## Session statistics

`//domo tnl`, **Session Stats**, or the end of a **stop** / **go home**:

- Run duration and kills (per hour)
- EXP, limit points, exemplar points, **capacity points** — each with **per-hour** rates
- EXP to next level and ETA at the current rate (when known)

Stats reset on each Start.

---

## Job profiles

Main job loads `Profiles/<JOB>.lua`. Jobs without a file use `DEFAULT` (no engage / no WS).

| Job | Notes |
|-----|--------|
| RDM, WHM, BLM, SCH, GEO, BRD, COR, DNC, NIN, THF, WAR, SMN, … | See each profile for buffs, WS chains, food, and magic |
| Extra logic | e.g. `dnc_logic.lua`, `rolls.lua`, `smn_logic.lua` |

---

## Configuration

| File | Purpose |
|------|---------|
| `settings.lua` | Shared defaults: targeting, WS, buffs, party phrases, Trust sacrifice order, go-home items |
| `data/settings.xml` | Per-character save (`//domo save`) |
| `data/trusted_players.txt` | Who may use party commands / join |
| `data/known_trusts.txt` | Trust names Domo has seen summoned (UI summon list) |
| `data/ui_pos.txt` | Panel and launcher icon position |

---

## Debugging

```text
//domo debug on
//domo debug off
```

Include `[Domo]` chat lines and any debug log when reporting issues.

---

## Notes

- **Needed buffs / food / pull abilities** never freeze the bot forever: a failed or unavailable check is skipped or retried later; combat continues.
- **Trust list** is not a catalogue of every Trust in the game — only ones Domo has seen in your party while running (plus anything you add with `//domo addtrust`).
- The launcher icon asset is small on disk; if an old huge `domologo.png` is left in place, replace it with the one shipped in `ui/assets/`.
