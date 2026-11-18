# Race for Valhalla

A roguelike rhythm game. Viking warriors act on the beat of their own heart, chasing a glorious death and a seat in Valhalla. The shared Godot rules in `../../CLAUDE.md` and the global rules in `~/.claude/CLAUDE.md` apply here too.

## Project facts
- Targets: PC and mobile (not web). The Mobile renderer is intentional. Every input needs a touch equivalent.
- Design docs live outside the repo in `../Documents/` (`mechanics.txt`, `thematics.txt`). They are untracked on purpose. Read them for intent. Edit them only with explicit approval.
- Remote: `origin` on GitHub. Branches: `feature/*` -> `dev` -> `staging` -> `main`.

## Layout
- `scenes/`, `scripts/` (one script per scene, plus `class_name` helper classes), `test/unit/`.
- `scenes/rhythm_lab.tscn` is a test bench for tuning the heartbeat feel. It is the main scene for now.

## Core rhythm model
- `BeatClock` (`scripts/beat_clock.gd`) is the master clock. It is locked to audio playback of a looping, synthesized heartbeat (`HeartbeatAudio`), not to frame time. The buh of beat `n` is at `n * period`.
- `BeatJudge` grades inputs. The window is ±`dum_delay` around each buh (the dum is the cut-off). Inputs within `perfect_window` count as Perfect. Each beat takes one rune; a second input on the same beat is a Miss. A Miss breaks the combo but never cancels anything already queued.
- `ComboTracker` keeps the combo and the counts.
- Input actions: `rune_1`..`rune_4` (keys D F J K, gamepad face buttons, and on-screen buttons).

## Tests
The default commands from `../../CLAUDE.md` apply as written, with no overrides:
- Narrow: `"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gexit -gtest=res://test/unit/test_<name>.gd`
- Full suite (promotions only): `"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd`
- Smoke: `"$GODOT" --headless --path . --quit-after 300`
