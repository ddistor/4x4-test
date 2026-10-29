# To check in Claude Code / by hand

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

## The driver (first sketch)

In the seat: white full-face helmet with a black visor (his face hidden),
red/blue stripes and a blue chin, a maroon tee with the sleeves cut off, jorts with frayed cuffs, blue
tsinelas. The steering wheel now turns with the steering and his hands stay on it.
He moves from what the rig does: thrown to the outside in corners, folds
forward under braking, sinks and floats over bumps, head lagging and trying to
keep level. Things to judge by eye while driving: too floppy or too stiff
(`_spring(...)` frequencies and the gains on `f.x` / `f.z` in
`driver.gd::_physics_process`), proportions, colours. The seat camera (C) moved
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

- **After that, the realism plan:**
  1. Real gearbox: torque curve, gears, engine braking on descents, stalling in
     low range.
  2. Recovery kit: shovel (dig out a high-centred rig), traction boards,
     high-lift jack; snatch strap if a buddy rig arrives.
  3. Damage: mud-caked radiator overheats, axle/CV snaps when shock-loaded with
     lockers in, tie rod bends on rocks, hydrolock in deep water (snorkel fix).
  4. Weather that changes during a run: rain starting, puddles growing.
- Ilocos / Zambales beach sand as its own section (lahar covers loose sand for now).
