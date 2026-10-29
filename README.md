# Putik

A 4x4 trail-running game set in the red-clay foothills of Morong, Rizal.
Convoy culture, laterite mud that turns to soup, creek crossings, winches on
every bumper, everybody out pushing. Personal project, not for release.

## Run it

1. Install [Godot 4.7+](https://godotengine.org/download) (standard build, not .NET).
2. Open `project.godot`, press **F5**.

| Key | Action |
| --- | --- |
| W / S | Throttle / brake (S from a stop reverses) |
| A / D | Steer |
| Space | Handbrake |
| L | Diff lock |
| G | Low range (4L) |
| F | Winch to the nearest tree ahead (F again releases) |
| C | Chase cam / hood cam |
| Backspace | Reset to the road |

Gamepad works too (left stick, triggers, face buttons).

## Milestones

- **M1 — mud playground** (`m1-mud-playground`): one trail, one rig, the mud sim,
  winch, mud caking. Making getting stuck and getting out feel right.
- M2 — a second rig (Patrol), an AI buddy in convoy, snatch strap.
- M3 — trail runs as missions: checkpoints, fuel, damage, a basecamp.

See `docs/to-check.md` for what needs a human look before merging.
