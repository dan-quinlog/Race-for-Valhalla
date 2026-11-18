# Race for Valhalla

A roguelike rhythm game. Viking warriors act on the beat of their own heart, chasing a glorious death and a seat in Valhalla. The shared Godot rules in `../../CLAUDE.md` and the global rules in `~/.claude/CLAUDE.md` apply here too.

## Project facts
- Targets: PC and mobile (not web). The Mobile renderer is intentional. Every input needs a touch equivalent.
- Design docs live outside the repo in `../Documents/` (`mechanics.txt`, `thematics.txt`). They are untracked on purpose. Read them for intent. Edit them only with explicit approval.
- Remote: `origin` on GitHub. Branches: `feature/*` -> `dev` -> `staging` -> `main`.

## Layout
- `scenes/`, `scripts/` (one script per scene, plus `class_name` helper classes), `test/unit/`.
- `scenes/rhythm_lab.tscn` is the test bench for the heartbeat and rune commands. It holds one or two `player_panel.tscn` (each with a `rune_pad.tscn`) and is the main scene for now.

## Core rhythm model
- `BeatClock` (`scripts/beat_clock.gd`) is the master clock. It is locked to audio playback of a looping, synthesized heartbeat (`HeartbeatAudio`), not to frame time. The buh of beat `n` is at `n * period`.
- `BeatJudge` grades inputs. The window is ±`dum_delay` around each buh (the dum is the cut-off). Inputs within `perfect_window` count as Perfect. Each beat takes one rune; a second input on the same beat is a Miss. A Miss breaks the combo but never cancels anything already queued.
- `ComboTracker` keeps the combo and the counts.
- Tempo will eventually change mid-play (speed up, slow down, skip beats). Keep gameplay logic on beat indices, not seconds.

## Runes and commands
- Four runes sit on a diamond (`Rune.Dir`): up Prayer, down Movement, left Attack, right Defense.
- Every command takes two beats (`CommandReader` -> `RuneAction`). The first rune picks the kind and the second picks the detail. The second rune must land on the next beat, or the first expires.
  - Movement + dir: move. Attack + down/left/up/right: Trip/Standard/Heavy/Defensive. Defense + dir: brace that way.
  - Prayer + rune: bless that rune's next action. Movement ignores room damage, Attack deals extra damage, Defense retaliates. Prayer + Prayer grants glory.
- `PlayerRhythm` gives each player their own judge, combo and reader. All players share one `BeatClock`.
- Input actions are `p1_up/down/left/right` (WASD, gamepad 0) and `p2_*` (arrow keys, gamepad 1). Each direction maps to both the d-pad and the matching face button. In solo mode, every input set drives P1. Mobile is solo with on-screen `RunePad` touch buttons.

## Tests
The default commands from `../../CLAUDE.md` apply as written, with no overrides:
- Narrow: `"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gexit -gtest=res://test/unit/test_<name>.gd`
- Full suite (promotions only): `"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd`
- Smoke: `"$GODOT" --headless --path . --quit-after 300`
