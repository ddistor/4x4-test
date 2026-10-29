# To check in Claude Code / by hand

## Rollover, jumps, mud that moved

- **On its side or roof** it now lies still instead of thrashing and sinking:
  wheel springs let go as the rig tips (`upright` in `wheel.gd`), each tire
  has a small solid core to rest on, and the wheel rays start inside the
  body so a mount pushed into the dirt still finds the ground. Backspace
  recovers. Flat-slab test: on its side, spin 10 -> 0.16 rad/s, no hopping.
- **Jumps**: wheels hang at the end of their travel in the air instead of
  following the ground down (that was the "stretch"), and droop is now
  ~0.28 m below ride height (`max_travel` 0.30 -> 0.15). Kanal ruts got a
  little harder for the test bot (3 -> 6 recoveries on seed 31337): less
  droop lifts wheels out of the V-ruts. Judge by driving.
- **Mud on the body** is anchored to the body now; it used to slide with each
  wheel's suspension.

## Winch: pick your anchor

F starts aiming: every tree, palm or big boulder the cable reaches (18 m,
ahead of or up to 80 deg beside the bumper) gets a white ring where the strap
would go; the best one (close and ahead) starts picked in yellow with a dashed
line showing the cable run. Hover the mouse over another ring or Tab through
them, F to hook up, Esc to cancel. F while pulling releases. Every tree
within 22 m of the trail is now an anchor (was: only bank-edge trees) and is
solid, so you can't drive through trunks off the trail any more. Lahar
washes have few anchors on purpose: boulders only. To check: the rings show
through terrain so you can find them; too cluttered?

## Tires no longer hit the body

The bodies had flat floors and boxy inner tubs running right over the wheels
(the tire poked through the floor even at ride height on some rigs), arch cuts
lower than a tire at the bump stop, and collision boxes filling the space the
tires move through. Now (`bodies/body_kit.gd`, shared by every body): each
rig has an up-travel `bump` in its RigSpec (0.2 m, the old bump stop), the
tire mesh never shows past it, real wheel wells clear a tire there, floors
stay inboard of the tires, arch cuts are the well's size, and collision boxes
are split so nothing solid sits where a tire can go. The garage has a
*Suspension* button to show the rig flexed (two wheels at the bump stop, two
at full droop); checked all four with `--snap-garage --flex --rig ID`. Drive
test positions on seed 7 match before. To check by driving: no more
clunking on ledges and ruts where the tire used to meet the body.

## Ronda (big four-door wagon, the Patrol)

Fourth rig: `bodies/ronda_body.gd`, spec `rig_spec.gd::_ronda`. Long hood with a
raised centre, flat sides, four doors and rear quarter windows, big black
flares, rectangular lamps and a barred grille, snorkel up the right A-pillar,
roof rack, side steps, spare on the back door, winch bumper. Heaviest rig
(2650 kg), longest (2.97 m wheelbase), on 35s, coils with the most droop
(0.2 m), the most low-range pull. Headless bot: quickest through the paddies
and lahar of the four. To check by driving: wide turning circle, sinks deep in
the bog, walks up the rock steps; the snorkel and rack read from the chase cam.

## Feroz (boxy 90s two-door, the Feroza)

Third rig: `bodies/feroz_body.gd`, spec `rig_spec.gd::_feroz`. Paint over black
lower cladding, a pale pinstripe, square-cut black flares round big arches,
rectangular lamps in a slatted grille, raked windshield, the stepped-up rear
roof over big quarter windows, spare on the back door, winch bumper. Light
(1350 kg), short (2.18 m wheelbase), narrow, on 31s, softer springs, less
power, more steering lock. Headless bot gets it through the paddies and into
the lahar (spins more in 4H, then crawls in 4L). To check by driving: tight
turns, floats on soft clay, high-centres sooner on the rock steps and kanal crown.

## Garage page

*Pick your rig and drive* on the start menu now opens the garage
(`scripts/ui/garage.gd`): your rig with the driver in it on a clay pad, turning
slowly (drag to spin it), with Rig / Paint / Shirt / Jorts / Print beside it;
every click rebuilds the rig so you see exactly what you'll drive. *Drive stage
N* starts it, *Back* returns to the menu. The rig runs in a preview mode there
(frozen body, wheels at ride height, no terrain). `--snap-garage` saves
`snaps/95_garage.png`, `--snap-menu` the start menu. To check: dragging, and the
rig/driver look right from all round.

## Shirt print selector

Start menu *Shirt print* button: Tropang Saligawsaw, Saligawsaw 4x4, or None
(`Game.LOGOS`; add a print by dropping a square transparent PNG in
`assets/driver/` and listing it). The Saligawsaw 4x4 art was cut off its white
paper (`assets/driver/saligawsaw_4x4.png`); its black shadow lettering
disappears on the club black shirt and shows on light ones. Rendered here on the
black tee. `--logo N` picks one for a run.

## Kuwarenta (forty-series-style hardtop)

Second rig in the *Rig* picker: `bodies/kuwarenta_body.gd`, spec in
`rig_spec.gd::_kuwarenta`. Two-tone (menu paint + white top), round headlights in
the fender fronts, slotted grille, upright windshield, side and rear-door
windows, arches cut round 33s, spare on a rear carrier, winch bumper. Heavier
(2050 kg), longer wheelbase (2.29 m), stiffer leaf-spring rate and less droop
than the Gera. Rendered from outside with `--snap --snap-rig --rig
kuwarenta`; the headless bot drives it through the paddies and lahar fine. To
check by driving: feels heavier and flatter than the Gera, lifts a wheel
sooner on the kanal ruts; seat camera (C) sits right behind the windshield;
the winch line leaves the bumper.

## Rig picker

`rig.gd` is now the shared machine; each vehicle is a `RigSpec` kind
(`rig_spec.gd`) plus a body builder in `scripts/vehicle/bodies/`. The start menu
has a *Rig* button (only one rig at first), saved with the colours. Drive
test on seed 7 matches the old behaviour. To check: the Gera (was Flatfender) drives as
before; the menu button is there.

## Colours: rig paint, shirt, jorts

Start menu has *Rig paint*, *Shirt* and *Jorts* buttons that cycle presets
(swatch beside each); the choice is saved to `user://look.cfg` and used when the
stage is built. Lists live in `game.gd` (`PAINTS`, `SHIRTS`, `SHORTS`); add more
there. `--look P,S,J` picks by index for one run (snapshots). Rendered here:
red rig + club black shirt + khaki jorts. To check: the buttons look right in the
menu (not screenshotted yet), and the colours you'd actually want are in the lists.

## Driver, sculpted instead of blocky

Rendered and checked here with `--snap --snap-driver` (OpenGL, no Vulkan in the
cloud box, so the Forward+ look on your PC will be a touch richer). The torso is
now one smooth body from cross-sections (`TORSO_ROWS` in `driver.gd`): chest,
a bit of belly, traps into a thick neck, the tee painted on with cut-off
armholes, a frayed edge and a crew collar. Arms are shaped (deltoid, biceps,
forearm, flat wrist: `UPPER_ARM_PROFILE` / `FOREARM_PROFILE`), the hands are
one palm loft into four fingers curled round the rim plus a thumb over the top
(`_hand_mesh`; a faint shading seam at the wrist up close), and the legs have knees, calves and
baggier jorts. Skin and cloth shade differently (`driver.gdshader`). To check by
driving: hands stay on the rim through full lock, elbows don't poke through
the body when he's thrown about, and nothing looks off from the chase cam.

## Club logo on the driver's tee

The Tropang Saligawsaw logo (cut out of the shirt photo, 512 px,
`assets/driver/tropang_saligawsaw.png`) is printed on the front of his maroon
tee, 24 cm across, and gets muddy with the rest of him. It's on the front
because the seat back covers his back. Not run in the engine yet: check it
reads the right way round (TROPANG on top, not mirrored), sits flat on the
chest, and isn't too big for him. Size and height: `PRINT_SIZE` and the
`0.37` in `_build_torso` (`driver.gd`). `--snap` now also saves close-ups
of him, `snaps/98_driver*.png`; `--snap --snap-driver` saves only those. Still looks blurry? It came from a
phone screenshot; a cleaner copy of the artwork can replace the PNG.

## The driver (first sketch)

In the seat: white full-face helmet with a black visor (his face hidden),
red/blue stripes and a blue chin, a maroon tee with the sleeves cut off, jorts with frayed cuffs, blue
tsinelas. The steering wheel now turns with the steering and his hands stay on it.
His torso (40 kg) and head (5 kg) are physics bodies on joints (hips with a
few cm of seat cushion, neck); the engine throws them about with the rig and
his "muscles" are damped torques holding him upright (damping ratio ~0.7, so
he leans and settles, never rocks on his own). Swerve test: torso 5-8 deg,
head a beat later; rolled to 79 deg he stays in the seat. Too stiff or too
floppy: `TORSO_K` / `HEAD_K` in `driver.gd` (keep the `_C` damping in step). The seat camera (C) moved
up to his eye height and hides his helmet. He gets muddy with the rig
(open tub): flecks first, then splatters, capped at about 40% so he never
turns into a clay statue (`shaders/driver.gdshader`, `reach`).

## Hard trails, steep climbs, body roll fix

- **Difficulty** (menu: Trail Moderate / Hard / Extreme, Hard by default)
  scales how much each section climbs, pitch steepness, kanal and bog depth,
  river depth, boulder size and how many pits hide in the cogon. The preview
  shows total climbing and the steepest pitch. Headless bot (no winch, no line
  choice) needs 3-7 recoveries per Hard stage, none on Moderate. Expect to need
  lockers, low range, airing down and the winch on Hard.
- **Steep climbs**: each section packs most of its height into one or two short
  pitches (*ahon*), 35-65% on Hard, with a churned mud wallow at the foot.
  Rock steps have real 0.5 m ledges. Tune in `stage_plan.gd::KINDS` (`rise`, `pitch`).
- **Slick clay is slick**: wet clay grip down to ~0.3 (`wheel.gd`, `mu`).
- **River current** pushes the rig downstream in deep water (`current_at`, 700 N per m of depth).
- **Body roll / "stretching" in curves**: the solid axles now hand load across
  (`axle_roll_stiffness`), side force goes in at axle height, and the shocks damp
  rebound 2.6x harder than bump. Swerve test on the paddy road: worst roll 38 -> 17 deg,
  inside-wheel hang 1.0 -> 0.66 m. Tilt table now slides at ~39 deg before it
  rolls (was: rolled at 36), so rollovers come from catching ruts and drops
  sideways, not from cornering.
- The finish clearing no longer pads the stage with a long empty road; the slack
  is shared across the middle sections. The farm road is rutted with puddles.

## Procedural stage, start and pause menus

Built and run headless: three seeds (7, 4242, 31337) drive from the paddies to
the finish with no recoveries using the crawling line-follower; the rainy seed
(99) gets through the bog, river and creek, just slowly. Visuals checked with
`--snap` screenshots of every section. Not yet driven by a human. In order:

0. **Start menu (F5).** Painted backdrop, stage preview on the right (season,
   sections, places, lengths). *Reroll* draws a new stage, typing a seed previews
   it, *Weather* cycles random / dry season / rainy season. *Drive this stage*
   shows "Building the stage…" for ~4 s, then drops you on the barangay road.
1. **Pause (Esc).** Resume, restart the same stage, new stage, back to the start
   menu, quit. Sound should stop while paused.
2. **HUD.** Top centre: section number, name and place, metres along the trail.
   No timer on purpose. Under the bamboo FINISH arch: "You made it…" for 8 s.
3. **Each section, by feel** (`scripts/world/terrain.gd`, `_kind_height` /
   `_kind_soil`; lengths and climbs in `stage_plan.gd::KINDS`):
   - *Barangay road*: gravel road between flooded paddies, as before.
   - *Laterite climb*: cut two-track in red clay, 60% of the time with a brown
     creek in a level bottom. The creek exit was the one hang-up in testing
     (fixed by levelling the trail round fords); if it's still a wall, `bank` /
     `drop` of the creek in `_plan_features`.
   - *Kanal ruts*: two deep V-ruts (0.3–0.6 m) that wander and pull the wheels
     off line; the crown between them can high-centre you.
   - *Boulder river*: wide, shallow (0.4–0.55 m) clear water over cobbles, boulders
     either side (small, crawlable ones on the line), foam where it's thin, the
     current streaking across. Wet stone is slicker.
   - *Lahar wash*: wide grey ash floor between gullied ash cliffs; loose (grip
     0.8), with a milky braided channel across it.
   - *Rock steps*: bedrock ledges and small boulders up an open hillside. Crawl it
     in 4L; at speed the rig launches off the ledges.
   - *Logging-road bog*: sunken forest road with a chain of water-filled holes;
     slow and deep (sink ~0.3–0.4 m) but passable in 4L with lockers.
   - *Cogon hills*: open grassland, head-high talahib over a faint two-track,
     hidden holes in and beside the wheel lines.
   - *Niyogan farm road*: dry dirt road through coconut rows and saging, the odd puddle.
4. **Wet and dry.** The season is rolled per stage (or picked in the menu): dry
   season is pale, cracked and firm; rainy season is darker, deeper and slicker,
   and the hollows hold water. Sections vary a little around the stage's season.
5. **Lumpy trail floor.** Humps, wallows and potholes everywhere (`LUMPS` in
   `terrain.gd`), with more, wetter mud sitting in the hollows. Too rough or too
   tame: tune `LUMPS` per kind.
6. **Backspace recovers** onto the trail where you are (2 m back), not the start.
   Rolling over or falling off does the same.
7. **Performance.** A stage is ~1 km of terrain, trees and grass; trees, rocks
   and plants are chunked with visibility ranges. Watch FPS in the forest
   sections; `TREE_RANGE` in `vegetation.gd` and `TREES` density in `terrain.gd`.

Known rough edges: the bank above the bog water can pick up a bluish sheen;
dry river cobbles on the banks read a little pale in full sun.

## Earlier milestone (rig, mud, sound), still to drive by hand

- **Winch (F)**: see "Winch: pick your anchor" above.
- **Mud caking**: wheelspin throws clay round the arches, a long bog buries the
  corner; fresh mud is dark and glossy, bakes pale and cracked, rivers rinse it.
- **Ruts**: drive the same stretch twice; the second pass sits lower.
- **Sound**: V8 idle and revs, squelch, gravel, swash, winch, clunk on L / G / F;
  sparse frogs and birds that follow open country vs forest.
- **Tread packing**, **airing down** (`-` / `=`, stopped), **rollover** gauges.

Known guesses to validate: spring/damper numbers in `wheel.gd`, mud drag
coefficient (`1500.0` in `wheel.gd`), low-range force (`26000` N).

## Queued (asked for, not started)

- **More rigs** (ideas, not started; the user picks which come first). Modelled in
  code with local nicknames, no brand names or badges on them. Needs: a rig picker in
  the start menu, `rig.gd` split into shared drivetrain + per-rig specs and body; the
  real gearbox first so gearing can differ.
  From the user:
  1. Land Cruiser 40-series style: short, upright, leaf springs, a classic. **Built: Kuwarenta.**
  2. Feroza style: small boxy 90s 4x4, light, short wheelbase. **Built: Feroz.**
  3. Vitara style: small 90s SUV, nimble, modest clearance.
  4. Patrol style: big heavy wagon, solid axles, long travel, sinks in bogs. **Built: Ronda.**
  5. Defender style (Land Rover): boxy, flat panels, coil-sprung solid axles.
  6. Rubicon style (modern Wrangler): lockers, disconnecting sway bar, big tires.
  7. FJ Cruiser style: retro body, independent front suspension, wide and stable.
  Claude's earlier ideas:
  8. Jimny/Samurai-style mini: light, narrow, floats, small tires.
  9. Land Cruiser 70-style heavy wagon: lockers, snorkel, heavy.
  10. Hilux/Strada-style pickup with independent front suspension: stable, poor flex, long overhangs.
  11. Owner-type jeep: the Filipino-built kind.
  12. Pajero-style 90s coil-sprung SUV.
- **River ford** (proposed, waiting on a yes): the river is equally deep all the
  way across, right at the engine-choke depth on Hard, so there's no better line
  to find. Make it a ford: shallow riffle (~0.35-0.5 m on Hard) where the trail
  crosses, deep pools up and downstream. In `terrain.gd::_height_at` (crossing bed).
- **After that, the realism plan:**
  1. Real gearbox: torque curve, gears, engine braking on descents, stalling in
     low range.
  2. Recovery kit: shovel (dig out a high-centred rig), traction boards,
     high-lift jack; snatch strap if a buddy rig arrives.
  3. Damage: mud-caked radiator overheats, axle/CV snaps when shock-loaded with
     lockers in, tie rod bends on rocks, hydrolock in deep water (snorkel fix).
  4. Weather that changes during a run: rain starting, puddles growing.
- Ilocos / Zambales beach sand as its own section (lahar covers loose sand for now).
