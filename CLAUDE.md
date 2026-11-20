# Race for Valhalla

A roguelike rhythm game. Viking warriors act on the beat of their own heart, chasing a glorious death and a seat in Valhalla. The shared Godot rules in `../../CLAUDE.md` and the global rules in `~/.claude/CLAUDE.md` apply here too.

## Project facts
- Targets: PC and mobile (not web). The Mobile renderer is intentional. Every input needs a touch equivalent.
- Design docs live outside the repo in `../Documents/` (`mechanics.txt`, `thematics.txt`). They are untracked on purpose. Read them for intent. Edit them only with explicit approval.
- Remote: `origin` on GitHub. Branches: `feature/*` -> `dev` -> `staging` -> `main`.

## Layout
- `scenes/`, `scripts/` (one script per scene, plus `class_name` helper classes), `test/unit/`.
- `scenes/hall.tscn` is the main scene, the lineage hall. With no save it shows the Founder screen (name the line, swear an oath). With a save it lists the line's heroes and glory and sends the next hero out on the Dreng arc. It also offers a quick run (no lineage, nothing saved) and the Rhythm Lab.
- `scenes/stage.tscn` plays a `DrengRun` (one or two heroes) drawn by `StageView`. The hall passes the run through the static `DrengRun.current`, which the stage takes once in `_ready` (a quick run if none). Quick runs keep the Restart and Boss buttons for testing; lineage runs hide them. When a run ends, a lineage run is recorded and saved, and "Return to the hall" appears.
- `scenes/rhythm_lab.tscn` is the test bench for the heartbeat and rune commands, with tunable BPM, windows and latency. Both scenes hold one or two `player_panel.tscn` (each with a `rune_pad.tscn`).
- `stages/chunks/*.tres` are `StageChunk` resources: three lane strings (`.` open, `#` wall, `F` fire, `D` door, `1`/`2` starts, `B` brute, `R` ranger, `V` Varg, `S` Shield-thrall, `J` Jötunn boss at its top-left zone) plus an `encounter` flag and a difficulty `tier` (1–3, 0 for non-encounters). `StageMap.build` stitches chunks left to right. `StageGenerator` builds each stage as start | encounter | corridor | encounter | exit, drawing encounters from tiers n-1..n for stage n, seeded so a run's stages are stable.

## Core rhythm model
- `BeatClock` (`scripts/beat_clock.gd`) is the master clock. It is locked to audio playback of a looping, synthesized heartbeat (`HeartbeatAudio`), not to frame time. The buh of beat `n` is at `n * period`.
- `beat(n)` fires on the buh and `beat_closed(n)` fires at the dum, once beat `n`'s input window has shut.
- All players always share one heartbeat. A tempo change applies to everyone at once.
- `BeatJudge` grades inputs. The window is ±`dum_delay` around each buh (the dum is the cut-off). Inputs within `perfect_window` count as Perfect. Each beat takes one rune; a second input on the same beat is a Miss. A Miss breaks the combo but never cancels anything already queued.
- `ComboTracker` keeps the combo and the counts.
- Tempo will eventually change mid-play (speed up, slow down, skip beats). Keep gameplay logic on beat indices, not seconds.

## Runes and commands
- Four runes sit on a diamond (`Rune.Dir`): up Prayer, down Movement, left Attack, right Defense.
- Every command takes two beats (`CommandReader` -> `RuneAction`). The first rune picks the kind and the second picks the detail. The second rune must land on the next beat, or the first expires.
  - Movement + dir: move. Attack + down/left/up/right: Trip/Standard/Heavy/Defensive. Defense + dir: brace that way.
  - Prayer + rune: bless that rune's next action. Movement ignores room damage, Attack deals extra damage, Defense retaliates. Prayer + Prayer grants glory.
- Skipping a beat (no input) clears the queue (a pending rune) the moment that beat's window closes, and keeps the combo. Only a mistimed or duplicate press breaks combo. Skipping is how a player shifts their own 2-beat flow by one beat to get back in time with an off-beat enemy. Tripping the enemy is the other way.
- Feedback: rune buttons are color-coded (`Rune.COLORS`: Prayer gold, Movement green, Attack red, Defense blue). A pending first rune lights its button and gives the hero an aura in that color until the command completes or is cleared. A fallen hero glows white.
- `PlayerRhythm` gives each player their own judge, combo and reader. All players share one `BeatClock`.
- Input actions are `p1_up/down/left/right` (WASD, gamepad 0) and `p2_*` (arrow keys, gamepad 1). Each direction maps to both the d-pad and the matching face button. In solo mode, every input set drives P1. Mobile is solo with on-screen `RunePad` touch buttons.

## Stages and fights
- `StageRules` is pure logic on beat indices: `Hero`s and `Enemy`s (both `Combatant`) on a grid of 3 lanes by `map.width` columns. Cells are `Vector2i(column, lane)`, and lane 0 is the back (top) lane. Movement: up/down change lanes, left/right change columns.
- Hero actions resolve as they complete (`act`). Enemies and fire resolve in `close_beat`, which the scene calls on `beat_closed`, so a brace or dodge entered on the hit beat counts. `act` closes earlier beats first.
- **Camera:** shows `VIEW_COLS` (4) columns and only scrolls right. It follows the lead hero once they pass `LEAD_COLS` into view, but never past the trailing living hero. It stops at the next uncleared encounter (an encounter chunk filling the screen) until that area's enemies are dead, then catches up and scrolling resumes. Heroes can't leave the screen. Only on-screen enemies act.
- **Exit:** once every encounter is cleared, the door opens, and the stage is won when every living hero stands on it. Later the door will lead to another stage or the boss.
- **One enemy per zone.** Heroes can share zones with anything. Melee attacks hit the enemy in your zone.
- **Enemy base:** `Enemy` takes 2-beat steps (`CADENCE`). Each step, `decide()` either repositions (returns null) or returns an `EnemyMove` to wind up. The move's target zones lock in at the wind-up start, and it lands `windup` beats later. Each step starts in step with where the last hit landed (`phase`). Regular moves wind up an even number of beats. A super (`is_super`) winds up an odd count, lands off the beat, and leaves the enemy off the beat until a Trip shifts a move by one beat (or the next super shifts it back). Trip always shifts the move, even when that knocks an on-beat enemy off the players' beat (confirmed by the user).
  - `RangerEnemy` (Archer) holds its column. If a hero is in its lane to the left, it nocks an arrow (2 beats) that hits the first hero in line. Otherwise it shifts one lane toward the nearest hero.
  - `BruteEnemy` (Draugr) alternates moving one zone toward the nearest hero and smashing its own zone (2-beat wind-up).
  - `VargEnemy` (wolf, 18 HP) pounces (2 beats, 10) on a hero within 2 steps, then leaps into the zone it hit. Otherwise it lopes 2 zones toward the nearest hero per step.
  - `ShieldThrallEnemy` (35 HP) takes half damage while its shield is up. A Trip or Heavy knocks the shield down for 4 beats, and that blow lands in full. It alternates closing in (to stand just right of a hero) and a Spear Thrust into its own zone and the one to its left.
  - `PatternEnemy` loops a fixed move list. `PatternEnemy.draugr()` is the first fight's Draugr with the off-beat Grave Wrath super, kept for bosses.
- **Braces face a direction:** they stop hits in the zone (`from_dir` none) and hits coming from the braced side (an arrow needs a brace facing right). A brace covers its beat and the next. A blessed brace strikes back for 10. A warded (blessed) move ignores enemy hits and fire for the same two beats.
- **Fire** (`FireTrap`) burns a column on a 4-off / 2-on beat cycle. A ward stops it, but a brace does not.
- **Attacks:** Standard 10. Heavy 20, but the hero is exposed (takes +50%) until their next command. Trip 4 and staggers. Defensive 6 and halves the next hit. Perfect and blessed each add +50%. Numbers are placeholders in `StageRules` and enemy constants.
- **Bosses** (`BossEnemy`) cover several zones (`footprint`) with one health pool. Every hit damages the pool, and a hit on an intact part's zone also wears that `BossPart` down. Hits on bare zones (body, or a broken part) deal +50%, so the body is the safer, lower-glory route. A broken part gives its breaker +10 glory, bleeds the boss 1 HP per beat, and turns its attack slot enraged. A boss that bleeds out earns no one the kill glory.
  - The Jötunn covers 2x3 zones: Club Arm (front top), Head (back top), Legs (back bottom), and three body zones. It cycles Club Slam / Frost Breath / Stomp. Broken parts turn these into Wild Flail / the off-beat Jötunn's Roar super / Quake.
- **Glory** (`Hero.glory`) comes from prayers (Prayer + Prayer), killing blows (`Enemy.glory_value`; 3 for regular foes, 25 for the boss), part breaks, and final-strike kills (+25 extra).
- **Dreng arc** (`DrengRun`): 3 generated stages, then the Jötunn, who guards the ancestors' relic. Between stages the heroes rest by the fire (+30 HP, up to max; the fallen stay fallen). Beating the boss completes the arc.
- **Lineage** (`Lineage`, saved as JSON at `user://lineage.json`): its name, the Founder's oath, and a record per hero (name, arc, glory, fate, stage reached). Each run's heroes get names from the line. Abandoning the line in the hall deletes the save (two presses).
- **Oaths** (`Oath`, placeholders, applied to every hero of the line via `Hero.oath`):
  - Odin: start each stage with a Prayer blessing (the next Prayer + Prayer gives double glory), but -10 max HP.
  - Thor: Heavy +10 damage, but it leaves you exposed for two commands.
  - Tyr: every block heals 3, but Prayer + Prayer gives no glory.
- **Final strike:** a hero who falls as beat `n` closes stays silent on `n+1` and `n+2`, and strikes once on `n+3` (`Hero.final_beat`). Fallen runes are ignored except an accepted one on that beat (`PlayerRhythm.begin_final`). With no input, it's a Strike. The stage isn't lost until every pending final strike resolves, so a dead party can still win. Perfect and an unspent Attack blessing each add +50%.
  - Up, Throw (30): the top lane of the nearest boss column (your own column if you stand in the boss), or the nearest foe if there's no boss. Bare-zone bonus applies.
  - Right, Charge (20 per zone): every foe zone ahead in your lane, not your start zone. Bare-zone bonus applies. The body ends at the right edge.
  - Left, Flurry (10 per zone, +15 if bare): the whole next column.
  - Down, Strike (25, +25 per broken part): your own zone.
  - During the silent beats the rune pad shows each strike with its damage (`StageRules.final_preview`) and highlights the best one. The EKG marks the final beat with a white heart numbered by player. The EKG itself keeps running, since the heartbeat is shared.

## Tests
The default commands from `../../CLAUDE.md` apply as written, with no overrides:
- Narrow: `"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gexit -gtest=res://test/unit/test_<name>.gd`
- Full suite (promotions only): `"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd`
- Smoke: `"$GODOT" --headless --path . --quit-after 300`
