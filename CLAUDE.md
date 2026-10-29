# Putik — 4x4 trail running in Morong, Rizal

Godot 4.7 (Jolt physics). Everything is text: scripts build the scene procedurally,
so there is almost nothing in `.tscn` files. Open `project.godot` in Godot and press F5.

## Workflow rules

- Work outside Claude Code goes on its own branch, never pushed to `main`. The user
  merges to `main` from Claude Code and asks for a branch check there.
- A new feature requested outside Claude Code branches off the *current* branch, not `main`.
  Milestones in Claude Code branch off `main`.
- Anything the user needs to verify by hand (in the editor, by driving it) goes in
  `docs/to-check.md`. Keep it current; tidy entries that are done.

## Layout

- `scripts/main.gd` — builds environment, terrain, rig, camera, HUD.
- `scripts/world/terrain.gd` — procedural Morong trail: paddies → first clay climb →
  creek → upper switchbacks. Heightmap mesh + `HeightMapShape3D` collider of the
  *firm floor* (heights minus mud thickness). Trees (MultiMesh) double as winch anchors.
- `scripts/world/mud_field.gd` — per-cell soft-ground data: thickness, wetness, rut.
  Baked into an RGB float texture the terrain shader reads (ruts displace vertices).
- `scripts/vehicle/rig.gd` — the FJ-style rig (RigidBody3D): drivetrain, open/locked
  diff model, low range, winch, mud caking, HUD text.
- `scripts/vehicle/wheel.gd` — one corner: raycast suspension, brush tire, sink/drag/
  rut carving against the mud field, spray/splash particles.
- `shaders/` — terrain (rut displacement, laterite colouring, pooling), muddy water,
  body paint that cakes with clay.
- `tests/drive_test.tscn` — headless smoke test that drives the trail with a simple
  line-follower and prints position/sink/slip each second:
  `godot --headless --path . res://tests/drive_test.tscn --quit-after 20000`

## Conventions

- Forward is -Z (Godot). The rig spawns facing world +Z, so its left is world +X.
- Units are metres, newtons, seconds. Tune in the `@export` vars at the top of
  `rig.gd` and `wheel.gd` before touching the formulas.
- Setting: Morong, Rizal. Red laterite clay, secondary forest, rice paddies by
  Laguna de Bay. Keep names and vibe local; avoid making it generic "jungle".
