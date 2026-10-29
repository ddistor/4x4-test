# To check in Claude Code / by hand

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

- **Winch (F)**: point the nose at a trunk or a big boulder within 18 m; F again releases.
- **Mud caking**: wheelspin throws clay round the arches, a long bog buries the
  corner; fresh mud is dark and glossy, bakes pale and cracked, rivers rinse it.
- **Ruts**: drive the same stretch twice; the second pass sits lower.
- **Sound**: V8 idle and revs, squelch, gravel, swash, winch, clunk on L / G / F;
  sparse frogs and birds that follow open country vs forest.
- **Tread packing**, **airing down** (`-` / `=`, stopped), **rollover** gauges.

Known guesses to validate: spring/damper numbers in `wheel.gd`, mud drag
coefficient (`1500.0` in `wheel.gd`), low-range force (`26000` N).

## Queued (asked for, not started)

- **The driver**: a typical Filipino trail driver in the seat: motocross helmet,
  t-shirt cut sleeveless, jorts, tsinelas. Must move realistically: body sways
  and bounces with the rig, head bobs, arms work the wheel.
- **After that, the realism plan:**
  1. Real gearbox: torque curve, gears, engine braking on descents, stalling in
     low range.
  2. Recovery kit: shovel (dig out a high-centred rig), traction boards,
     high-lift jack; snatch strap if a buddy rig arrives.
  3. Damage: mud-caked radiator overheats, axle/CV snaps when shock-loaded with
     lockers in, tie rod bends on rocks, hydrolock in deep water (snorkel fix).
  4. Weather that changes during a run: rain starting, puddles growing.
- Ilocos / Zambales beach sand as its own section (lahar covers loose sand for now).
