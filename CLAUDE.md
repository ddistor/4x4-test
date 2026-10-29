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
- `scripts/world/vegetation.gd` — everything green, modelled in code: broadleaf
  trees (sweep trunks + procedural leaf-card canopies), bamboo, saging, niyog,
  grass/ferns, rice in rows. Small stuff is chunked with a visibility range.
- `scripts/world/backdrop.gd` — far hills past the map edge and Laguna de Bay.
- `scripts/world/mud_field.gd` — per-cell soft-ground data: thickness, wetness, rut.
  Baked into an RGB float texture the terrain shader reads (ruts displace vertices).
- `scripts/vehicle/rig.gd` — the rig (RigidBody3D), a lifted black Willys-style
  flatfender: drivetrain, open/locked diff model, low range, winch, per-tire mud
  throw onto the body, HUD text. Body is modelled in code with `mesh_kit.gd`.
- `scripts/audio/sound_synth.gd` — every sound, synthesised at startup (~0.4 s):
  V8 engine loops at two rpms, mud/gravel/water/winch loops, paddy and forest
  ambience, clunk and splash one-shots. No audio files.
- `scripts/audio/rig_audio.gd` — pitches and mixes those from the rig's state.
- `scripts/vehicle/mesh_kit.gd` — procedural modelling helpers (rounded boxes,
  lathes, tubes, tori) appended into a SurfaceTool.
- `scripts/vehicle/wheel.gd` — one corner: raycast suspension, brush tire, sink/drag/
  rut carving against the mud field, spray/splash particles.
- `shaders/` — terrain (rut displacement, laterite colouring, pooling), muddy water,
  body paint that cakes with clay where the tires throw it, tire/wheel mud;
  shared clay look in `mud_common.gdshaderinc`; `foliage`/`bark` for plants,
  `sky` (procedural clouds), `backdrop` for the far hills. Vertex colours are
  authored as sRGB and linearised in the shader (clamp before `pow`: MSAA on
  thin blades otherwise makes NaNs that glow turns into white blobs).
- `tests/drive_test.tscn` — headless smoke test that drives the trail with a simple
  line-follower and prints position/sink/slip each second:
  `godot --headless --path . res://tests/drive_test.tscn --quit-after 20000`

## Seeing the game without a hand on the keyboard

`Godot.exe --path . -- --snap` (needs a window, not `--headless`) drops the rig at
six spots along the trail plus one driving shot and saves PNGs to `snaps/`. Read
them to check visuals and tune. Spots are listed in `scripts/snapshot.gd`.

## Conventions

- Forward is -Z (Godot). The rig spawns facing world +Z, so its left is world +X.
- Units are metres, newtons, seconds. Tune in the `@export` vars at the top of
  `rig.gd` and `wheel.gd` before touching the formulas.
- Setting: Morong, Rizal. Red laterite clay, secondary forest, rice paddies by
  Laguna de Bay. Keep names and vibe local; avoid making it generic "jungle".
