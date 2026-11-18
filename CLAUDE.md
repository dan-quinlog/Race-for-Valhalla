# Race for Valhalla

A roguelike rhythm game. Viking warriors act on the beat of their own heart, chasing a glorious death and a seat in Valhalla. The shared Godot rules in `../../CLAUDE.md` and the global rules in `~/.claude/CLAUDE.md` apply here too.

## Project facts
- Targets: PC and mobile (not web). The Mobile renderer is intentional. Every input needs a touch equivalent.
- Design docs live outside the repo in `../Documents/` (`mechanics.txt`, `thematics.txt`). They are untracked on purpose. Read them for intent. Edit them only with explicit approval.
- Remote: `origin` on GitHub. Branches: `feature/*` -> `dev` -> `staging` -> `main`.

## Layout
- `scenes/`, `scripts/` (one script per scene, plus `class_name` helper classes), `test/unit/`.
- `scenes/fight.tscn` is the main scene: the first fight (one or two heroes against a Draugr on a 3-room strip), drawn by `ArenaView`. It has a button to the Rhythm Lab.
- `scenes/rhythm_lab.tscn` is the test bench for the heartbeat and rune commands, with tunable BPM, windows and latency. Both scenes hold one or two `player_panel.tscn` (each with a `rune_pad.tscn`).

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
- Skipping a beat (no input) clears a pending rune but keeps the combo. Only a mistimed or duplicate press breaks combo. Skipping is how a player shifts their own 2-beat flow by one beat to get back in time with an off-beat enemy. Tripping the enemy is the other way.
- `PlayerRhythm` gives each player their own judge, combo and reader. All players share one `BeatClock`.
- Input actions are `p1_up/down/left/right` (WASD, gamepad 0) and `p2_*` (arrow keys, gamepad 1). Each direction maps to both the d-pad and the matching face button. In solo mode, every input set drives P1. Mobile is solo with on-screen `RunePad` touch buttons.

## Fights
- `FightRules` is pure logic on beat indices: `Hero`s and one `Enemy` (both `Combatant`) on a strip of `ROOM_COUNT` rooms. Hero actions resolve as they complete (`act`). Enemy steps resolve in `close_beat`, which the scene calls on `beat_closed`, so a brace or dodge entered on the hit beat counts. `act` closes earlier beats first.
- The enemy loops through `EnemyMove`s. Each move locks its target rooms when the wind-up starts, then lands `windup` beats later and rests for `rest` beats.
- The enemy keeps a 2-beat rhythm (`Enemy.CADENCE`). Each wind-up starts in step with where its last hit landed (`Enemy.phase`). Regular moves wind up an even number of beats, so they keep the rhythm. A super (`EnemyMove.is_super`) winds up an odd count, so it lands off the beat. The enemy then stays off the beat, breaking the players' 2-beat flow, until a Trip shifts a move by one beat (or the next super shifts it back). Bracing can outlast one off-beat hit, but the timing conflict remains. The arena tints super targets purple and marks off-beat targets OFF-BEAT.
- Attacks need the same room. Standard 10. Heavy 20, but the hero is exposed (takes +50%) until their next command. Trip 4 and staggers (the wind-up slips 1 beat). Defensive 6 and halves the next hit. Perfect and blessed each add +50%.
- A brace covers the beat it completes on and the next one. A blessed brace strikes back for 10. A warded (blessed) move ignores room damage for the same two beats. Brace direction doesn't matter yet; it will once attacks come from adjacent rooms.
- Numbers are placeholders in `FightRules` constants.

## Tests
The default commands from `../../CLAUDE.md` apply as written, with no overrides:
- Narrow: `"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gexit -gtest=res://test/unit/test_<name>.gd`
- Full suite (promotions only): `"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd`
- Smoke: `"$GODOT" --headless --path . --quit-after 300`
