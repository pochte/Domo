# Domo — Patch Notes

**Build focus:** combat reliability, group coordination, UI polish, and cleanup after the stalled Claude merge.  
**Baseline:** Claude’s `Domo-current` working copy (TargetLogic split + CampLogic).

---

## Highlights

- **No more staring into space** — needed buffs, food, and pull abilities no longer freeze engage forever.
- **Start means Start** — one party command resets hold, buffs, regroup, and combat for the whole group.
- **Leader announces** — Leader mode Start says `I'm the Leader`; other Domo clients auto-follow (Semi-Auto left alone).
- **Launcher icon** — clickable Domo face opens/closes the panel (TrustSupport-style).
- **Session stats** — EXP, LP, EP, **CP**, and per-hour rates.

---

## Bug fixes

### Combat / engage
- Needed buffs (e.g. Haste Samba) on cooldown or unavailable no longer block engage indefinitely; one try then skip/reset.
- No food in inventory: continue without food instead of pausing.
- Pull ability on cooldown (Provoke, ninja spells, etc.): fall back to melee engage instead of waiting forever.
- Leader mode forces `semi_auto = false`, `autotarget = true`, and clears stale assist targeting so hunting works again.

### Party / crash
- Restored missing **`Roster()`** in `PartyCommands.lua` (fixed `attempt to call global 'roster' (a nil value)` on Party_Tick).
- Invite / rejoin paths hardened with safer sequencing so a join doesn’t leave pulls paused forever without a clear timeout path.

### UI
- Panel no longer **jumps/rescales** when switching tabs (height locked to tallest tab).
- Mode button label shortened (`Mode: Semi` / `Leader` / `Follow`) and font sized so text is not clipped.
- Mode cycle order: **Semi → Leader → Follow**; Follow is skipped when solo or you are the only real party member.
- Launcher icon asset resized so it no longer briefly fills the screen on first load.

---

## Party commands (simplified)

| Phrase / button | Behavior |
|-----------------|----------|
| **Start** | Clear hold · reset buff timers · followers walk to leader · re-anchor origin · resume combat |
| **Stop** | Stop Domo · report depleted items · print final session stats |
| **Hold** | Pause new pulls until the next Start |
| **Session Stats** (`tnl`) | EXP / LP / EP / **CP** + per-hour rates + ETA when known |
| **Go Home** | Warp out, stop, print stats |

Legacy phrases still work and all map to **Start**: `reset`, `rebuff`, `regroup`, `resume`.

UI party row is five actions only (no separate Reset / Rebuff / Regroup / Resume buttons).

---

## Group leadership

- Character in **Leader** mode who starts announces in party chat: **`I'm the Leader`**.
- Other Domo clients (except **Semi-Auto**) switch to Follower and `/assist` that player.
- Semi-Auto keeps doing Semi-Auto.

---

## Trusts

- Known-trust list is **only** trusts Domo has seen summoned while running (`data/known_trusts.txt`), not a full game catalogue.
- `//domo addtrust "Name"` adds a name manually.
- Leader who cannot cast a requested trust replies in party: **`Sorry, don't have <name>.`**
- Trust dismiss/summon controls live on the **Party Trusts** tab.

---

## Modes & camping

| Control | Options |
|---------|---------|
| **Mode** | Semi-Auto · Leader · Follower |
| **Camp** | Free Roam · Camp Mode |

Camp/Free cycle is on **Controls → THIS CHARACTER: modes** (uses `CampLogic.lua`).

---

## UI / launcher

- Always-on **domologo** icon: click = show/hide panel, drag = move (position saved in `data/ui_pos.txt`).
- Tabs: **Controls** · **Party Trusts** · **Settings**.
- Skins: FFXI / FFXIV.
- Quiet start: no long WS/nuke/mode spam in chat; party chat reserved for real commands.

---

## Session statistics

On `tnl`, Session Stats, Stop, or Go Home:

- Duration and kills/hr  
- EXP, limit points, exemplar points, **capacity points** — each with **/hr**  
- EXP to next level and approximate time at current rate (when known)

---

## Internal / structure (from Claude baseline, kept)

- TargetLogic split into modules under `Logic/Targeting/` with a thin loader.
- CampLogic, FollowerGate, WarpLogic integrated.
- Stop notification captures depleted tools/items and final EXP before stat reset (no duplicate spam).

---

## Docs

- **ReadMe.md** rewritten for current commands, UI, party flow, and file layout.

---

## Suggested test checklist

1. Load Domo → small Domo icon appears (not fullscreen); click toggles panel.  
2. Mode cycles Semi ↔ Leader when solo; Follow only with another real player.  
3. Leader + **Start** → party sees `I'm the Leader`; other Domo chars follow.  
4. Semi-Auto ignores that announce.  
5. Engage with a needed buff down / no food / pull on CD → still engages.  
6. **Hold** then **Start** → group resumes (followers regroup).  
7. **Session Stats** shows CP and /hr lines.  
8. No `Roster` nil error in console.  
9. Party Trusts list only previously seen trusts (or empty until first summon).  

---

## Package history (this branch of work)

| Zip | Contents |
|-----|----------|
| `Domo-full-noui.zip` | Non-UI feature/bugfix pass |
| `Domo-bugfix.zip` | Roster, trusts tab, mode cycle, chat quieting |
| `Domo-bugfix2.zip` | Seen-only trusts, party command slimdown, CP stats, leader targeting |
| `Domo-bugfix3.zip` | Leader announce, Camp cycle, launcher icon |
| `ReadMe.md` / `PATCH_NOTES.md` | Docs only |

Replace `addons/Domo` with the latest full zip you are testing, or drop individual files on top of a known-good install.
