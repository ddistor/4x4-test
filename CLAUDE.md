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
  (`scenes/main.tscn`). `-- --seed N --weather dry|rain|downpour` on the command line.
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
  the underbody solid and bolted-on armor are modelled by `armor.gd`; what breaks and why in `damage.gd`
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
- `scripts/world/yard.gd` — Bakuran trail park (`StagePlan.practice_yard()`, a `yard` section,
  160 x 320 m): eight tracks (`Yard.TRACKS`: Bakuran Loop, Putikan mud, Batuhan rock, Kanal ruts, Ilog river,
  Lahar ash, Sukal jungle, Ahon at Lusong slopes), each a clay loop with its obstacles on the trail and a bypass
  beside each; `Yard.use(i)` lays one out for the terrain (heights, soil, rock, woods,
  stones, trees, creeks, a timber bridge and logs). Lookups work in a path's own (along, across) coordinates.
  `scripts/ui/park_select.gd` — the track list after the garage, a map preview drawn
  from the layout. `Game.playground`, `Game.park_track`; `-- --playground --track N`.
- `scripts/world/rocks.gd` — boulders and river stones, convex colliders; wheels
  treat group "rock" as firm ground.
- `scripts/world/vegetation.gd` — everything green, modelled in code: broadleaf
  trees (sweep trunks + procedural leaf-card canopies), bamboo, saging, niyog,
  grass/talahib/ferns, rice in rows, placed per section. Chunked with visibility ranges.
- `scripts/world/weather.gd` — rain on the day: how hard it's raining (`rain_now`) and how
  soaked things are (`rain_soak`), global shader values every surface reads (wet ground,
  puddles and rain rings, wet stone, leaves, bark, paint); the terrain's `ground_sample`
  wetness (grip and sinkage, as slick as each surface really gets); sky, sun and haze;
  streaks that stop on roofs and under the canopy, splashes; rain and thunder sound.
  Showers in the rainy season, a light one now and then between the rains, none in the
  dry season; `Game.weather` 2 is a downpour. `-- --rain X` fixes it.
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
- `scripts/vehicle/bodies/cabin_kit.gd` — what every rig has inside and under the hood, from a
  per-rig LAYOUT (floor, firewall, dash, engine bay, closed cab): its own engine (V8, V6,
  straight-six, four, diesels) with radiator, fan, battery and an exhaust to a muffler;
  pedals that swing as they're pressed (hung from under the dash, or up through the
  floor on the Willys-type tubs; `set_pedals`, `foot_on`), a dead pedal, tunnel, a gear
  lever through its H, the transfer-case lever and a handbrake that move (`grip_at`), mats;
  gauges in the dash face with live tach/speedo needles; door cards, headliner, mirror
  and visors in a closed cab. `tests/interior_snap.tscn` pictures it.
- `scripts/vehicle/gearbox.gd` — engine (torque curve, idle, redline), gears,
  final drive, low range, engine braking, auto/manual (E/Q, T), stalling; the
  numbers per rig are in `RigSpec`. Its rpm drives the engine sound.
- `scripts/vehicle/recovery_kit.gd` — shovel (1), traction boards (2), high-lift
  jack that packs stones under hanging tires (3); stopped only.
- `scripts/audio/engine_synth.gd` — each rig's own engine, from how an engine makes
  sound: blowdown pulses at the real firing order and crank angles (V8 cross-plane,
  V6, straight-six, four, the diesels), each bank down its headers into a pipe,
  muffler and tailpipe that ring at their own lengths; intake pulses and induction
  roar up front, diesel knock / valve tick from the block. Loops baked across the
  rev range on and off load (~2-3 s, in a thread, the first time) and cached in
  `user://engine_sound/`; bump `CACHE_VERSION` when changing the synthesis.
  `tests/engine_sound_test.tscn` checks the orders and writes WAVs;
  `tests/engine_listen.tscn -- --rig X` records a rev sweep through the real mix.
- `scripts/audio/sound_synth.gd` — every other sound, synthesised at startup:
  mud/gravel/water/winch loops, quiet paddy and
  forest beds plus a bank of separate animal calls (kept sparse on purpose),
  clunk and splash one-shots. No audio files.
- `scripts/audio/rig_audio.gd` — pitches and mixes those from the rig's state: the
  engine's loops crossfaded between rev points and on/off load (throttle, engine
  braking, the clutch out), exhaust at the tail and intake at the bay, heard through
  the cab from the seat (closed cabs much quieter and duller), gear whine in
  reverse, first and low range.
- `scripts/vehicle/winch_aim.gd` — choosing a winch anchor: rings on everything in
  reach, mouse hover or Tab to pick, F to hook.
- `scripts/vehicle/driver.gd` — the driver (motocross helmet, sleeveless tee with the
  club logo, jorts, tsinelas, ~1.7 m) and the turning steering wheel. Torso and head are
  physics bodies on joints, held up by damped muscle torques. Arms (shoulder to wrist) and
  legs (hip to ankle) are each one skin rebuilt every step (`_loft`) by two-bone IK; hands
  have jointed fingers curled round what they hold. He works the controls (`_work_controls`):
  right foot gas/brake, left foot clutch for a shift or a stop, right hand to the gear
  lever, transfer lever and handbrake. Helmet is on render layer 2, hidden from the seat
  camera. `tests/driver_snap.tscn -- --rig X` pictures him at it and prints how he fits
  the seat (hip to pedal, knee bend, knee under the wheel).
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
- `tests/yard_test.tscn` — checks the park and drives every obstacle (`--loop`: the whole loop).
- `tests/career_test.tscn` — the career ladder's pacing by sum, then garage → stage →
  finish → pay → garage through the real scenes.
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

- Realistic is the requirement for everything, not a polish pass, and it is
  never left for the user to ask for. That covers:
  - the world: terrain shapes and sizes, soils, water, plants, weather, light,
    all as they really are in Morong;
  - how the rig reacts to it: grip, sinkage, suspension, traction, the engine and
    gearing, damage, recovery gear, judged against how a real 4x4 behaves on that
    ground;
  - the rigs and the driver: real dimensions, proportions and ergonomics, parts
    that move as they're used;
  - sound and the UI's numbers.
  Research before implementing: look up how the real thing looks, measures,
  sounds and behaves (and how others have modelled it) before writing code, and
  say what was found. Start from those real-world figures, build to them, then
  check the result: pictures from where the player sees it (seat cam, chase
  cam, `--snap`) and tests or drives that measure the behaviour. Fix seams, gaps,
  intersections, wrong proportions and unrealistic behaviour before calling it
  done, and say plainly what wasn't verified.
- Forward is -Z (Godot). The stage runs along world +Z; the rig spawns facing up it.
- Units are metres, newtons, seconds. Tune a vehicle in its `RigSpec` kind
  (`rig_spec.gd`) and the `@export` vars in `wheel.gd` before touching the formulas.
- Setting: Morong, Rizal. Red laterite clay, secondary forest, rice paddies by
  Laguna de Bay, and the stage sections named after real Philippine trail country.
  Keep names and vibe local; avoid making it generic "jungle".
