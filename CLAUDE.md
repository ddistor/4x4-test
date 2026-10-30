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

- `scripts/game.gd` — autoload `Game`: the stage seed and weather, and switching
  between the start menu (`scenes/menu.tscn`, the main scene) and a stage
  (`scenes/main.tscn`). `-- --seed N --weather dry|rain` on the command line.
- `scripts/ui/start_menu.gd` — start menu (painted backdrop, stage preview, seed,
  weather, trail); `garage.gd` — rig, paint, shirt, jorts and print, with the rig
  and driver shown turning on a pad (the Rig in preview mode) before you drive; `pause_menu.gd` — Esc; `settings_menu.gd` — the graphics screen over either
  (values, presets, saving and applying live in `scripts/graphics_settings.gd`,
  `Game.gfx`); `hud.gd` — rig status, inclinometers, section
  and distance (no clock on purpose: it's a drive, not a race); `ui_kit.gd` — shared look.
- `scripts/career.gd` — career mode (`Game.career`): the rigs you own, each with its
  parts and damage, pesos, club events and their pay; `user://career.cfg`. Free play
  never uses it. Parts are in `scripts/vehicle/parts.gd` (`Parts`: tires, lift, axle
  gears, low range, and armor; prices, what fits, `Parts.apply` on a RigSpec);
  bolted-on armor is modelled by `armor.gd`; what breaks and why in `damage.gd`
  (on in a career, `--damage` in free play).
- `scripts/main.gd` — builds environment, terrain, rig, camera, HUD, pause menu.
- `scripts/world/stage_plan.gd` — the seeded chain of sections: paddy road first,
  then six of laterite climb, kanal ruts, boulder river, lahar wash, rock steps, rock gully,
  logging-road bog, cogon hills, niyogan farm road, pasture two-track, talahib ridge,
  overgrown trail (always a river and kanal), then
  the finish clearing. Trail profile per section; the season (dry .. rainy).
- `scripts/world/terrain.gd` — builds the stage as a 160 m wide strip along +Z:
  each section kind shapes heights, soft ground and grip its own way and blends
  into the next; rivers/creeks cross the trail, pits hide in the cogon, the trail
  floor is lumpy. Heightmap mesh in chunks + `HeightMapShape3D` tiles of the
  *firm floor* (heights minus mud thickness). 1 m cover/soil maps feed the shader
  (forest, paddy, ash, bedrock, cobbles, water level and where water may stand).
  Trees, palms and boulders double as winch anchors.
- `scripts/world/rocks.gd` — boulders and river stones, convex colliders; wheels
  treat group "rock" as firm ground.
- `scripts/world/vegetation.gd` — everything green, modelled in code: broadleaf
  trees (sweep trunks + procedural leaf-card canopies), bamboo, saging, niyog,
  grass/talahib/ferns, rice in rows, placed per section. Chunked with visibility ranges.
- `scripts/world/backdrop.gd` — far hills in rings round the strip, Laguna de Bay.
- `scripts/world/mud_field.gd` — per-cell soft-ground data: thickness, wetness, rut.
  Baked into an RGB float texture the terrain shader reads (ruts displace vertices).
- `scripts/vehicle/rig.gd` — the rig (RigidBody3D) every vehicle shares:
  open/locked diff model, air drag and rolling resistance, winch, per-tire mud throw onto
  the body, HUD text. What differs per vehicle lives in `rig_spec.gd` (`RigSpec`:
  mass, wheel layout, tire size, gearing, seat, fairlead, body builder; picked in
  the start menu, `--rig ID` on the command line). Bodies are modelled in code
  with `mesh_kit.gd`, one file each in `scripts/vehicle/bodies/`
  (`gera_body.gd`: the Gera, the lifted black Willys-style flatfender, and its
  trail-built variant the Gerilya via `build_trail`).
- `scripts/vehicle/gearbox.gd` — engine (torque curve, idle, redline), gears,
  final drive, low range, engine braking, auto/manual (E/Q, T), stalling; the
  numbers per rig are in `RigSpec`. Its rpm drives the engine sound.
- `scripts/vehicle/recovery_kit.gd` — shovel (1), traction boards (2), high-lift
  jack that packs stones under hanging tires (3); stopped only.
- `scripts/audio/sound_synth.gd` — every sound, synthesised at startup (~0.4 s):
  V8 engine loops at two rpms, mud/gravel/water/winch loops, quiet paddy and
  forest beds plus a bank of separate animal calls (kept sparse on purpose),
  clunk and splash one-shots. No audio files.
- `scripts/audio/rig_audio.gd` — pitches and mixes those from the rig's state.
- `scripts/vehicle/winch_aim.gd` — choosing a winch anchor: rings on everything in
  reach, mouse hover or Tab to pick, F to hook.
- `scripts/vehicle/driver.gd` — the driver (motocross helmet, sleeveless tee with the
  club logo, jorts, tsinelas) and the turning steering wheel. Body is lofted from
  cross-sections (`MeshKit.grid`), hands wrap the rim. Torso and head are physics bodies
  on joints, held up by damped muscle torques; arms reach the wheel by two-bone IK.
  Helmet is on render layer 2, hidden from the seat camera.
- `scripts/vehicle/mesh_kit.gd` — procedural modelling helpers (rounded boxes,
  lathes, tubes, tori) appended into a SurfaceTool.
- `scripts/vehicle/wheel.gd` — one corner: raycast suspension, brush tire, sink/drag/
  rut carving against the mud field, spray/splash particles.
- `shaders/` — terrain (rut displacement, laterite, ash, bedrock, river cobbles,
  dry-season cracks, pooling), water (muddy, or clear with depth colour and foam),
  `rock` for boulders,
  body paint that cakes with clay where the tires throw it, tire/wheel mud;
  shared clay look in `mud_common.gdshaderinc`; `foliage`/`bark` for plants,
  `sky` (procedural clouds), `backdrop` for the far hills. Vertex colours are
  authored as sRGB and linearised in the shader (clamp before `pow`: MSAA on
  thin blades otherwise makes NaNs that glow turns into white blobs).
- `tests/mud_test.tscn` — mud on the rig: build-up, drying to crust, flaking on
  knocks, washing in a river (`--pictures --close` with a window renders the stages).
- `tests/parts_test.tscn` — career parts, rigs and money, and the ride height on a stage;
  `tests/damage_test.tscn` — each way a rig breaks, with and without the part that saves it.
- `tests/drive_test.tscn` — headless smoke test that drives a whole stage with a
  line-follower (crawling in 4L), recovers when stuck >10 s and prints where:
  `godot --headless --path . res://tests/drive_test.tscn --quit-after 36000 -- --seed 7`

## Seeing the game without a hand on the keyboard

`Godot.exe --path . -- --snap --seed N` (needs a window, not `--headless`) skips the
menu, drops the rig mid-way through every section and at each crossing, plus one
driving shot, and saves PNGs to `snaps/`. Read them to check visuals and tune.
Add `--snap-driver` for just the driver close-ups (`snaps/98_driver*.png`),
`--snap-only KIND` for just one kind of section (chase, ahead and above views).

## Conventions

- Forward is -Z (Godot). The stage runs along world +Z; the rig spawns facing up it.
- Units are metres, newtons, seconds. Tune a vehicle in its `RigSpec` kind
  (`rig_spec.gd`) and the `@export` vars in `wheel.gd` before touching the formulas.
- Setting: Morong, Rizal. Red laterite clay, secondary forest, rice paddies by
  Laguna de Bay, and the stage sections named after real Philippine trail country.
  Keep names and vibe local; avoid making it generic "jungle".
