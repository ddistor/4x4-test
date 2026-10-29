# To check in Claude Code / by hand

## M1 mud playground (branch `m1-mud-playground`)

The physics runs and the headless drive test gets from the paddies through the
creek. Visuals are checked with `--snap` screenshots, not yet by a human
driving it. In order:

0. **Snapshot mode works on Windows.** Run `Godot.exe --path . -- --snap` from the
   repo folder; it should open a window for ~10 s and leave 7 PNGs in `snaps/`.
   Each `saved ...` line prints where the rig was (placement used to stick at
   the first spot; fixed by setting the transform on the physics server too).
1. **Look around (F5, mouse drag).** Realism pass: cloud sky, AgX tonemap, soft
   shadows, light haze, far hills and Laguna de Bay past the map edge; ground is
   layered per pixel (grass, leaf litter under the trees, laterite on cut banks,
   gravel road, glossy wet clay with puddles in the ruts); vegetation is modelled
   in code (broadleaf trees, bamboo, saging, niyog, grass, ferns, rice in rows).
   Things to judge by eye: forest trunks may read too grey/pole-like; puddles
   may be too few or too many (`pool` in `terrain.gdshader`); performance with
   grass density (`step` in `vegetation.gd::_place_ground_cover`) on your GPU.
2. **Drive the road** (W). Should reach ~35 km/h on the gravel. Steering (A/D)
   should feel heavy but not sloppy. The rig is a lifted black flatfender on
   35s with a 2.35 m wheelbase and 1950 kg, so it may pitch and wander. Drag
   with either mouse button to orbit, scroll to zoom; C is a driver's-seat cam.
3. **Hit the first clay at z≈50 in 4H / open diff.** Intended: it bogs within a
   few metres and one wheel per axle spins. Press **G** (4L) and **L** (diff lock)
   and it should crawl out at 5–7 km/h. If it crawls out too easily in 4H, raise
   `wetness` on the lower climb in `terrain.gd::_author_mud`.
4. **Creek crossing at z≈112.** Sinks ~0.4 m, splashes (droplets + mist), engine
   chokes if the front wheels go past ~0.75 m of water. Passable in 4L.
5. **Upper switchbacks past z≈139.** Marginal: one headless run with the new rig
   reached the top, the latest one jammed at z≈142 against the bank, and the
   `--snap` drop at z=150 can tip it over. Needs a human drive. If the banks
   are the problem, soften `smoothstep(2.8, 7.0, dx)` in `terrain.gd::_base_height`.
6. **Winch (F).** Point the nose roughly at a trunk within 18 m and press F. A line
   should draw and the rig should get pulled at ~0.9 m/s. F again releases.
   Trees right at the bank edge (12% of them) are the intended anchors.
7. **Mud caking.** Each tire throws clay onto the body around and behind it: a
   second or two of wheelspin should show round the arch, a long bog buries the
   corner. Fresh mud is dark and glossy, bakes pale and cracked over ~a minute,
   the tread packs first, and the creek rinses it off. Tune by feel: throw rate
   `0.35` (`corner_mud[i] = ...` in `rig.gd`), reach ellipses in
   `mud_cake.gdshader::coverage`, threshold `0.38` in its `fragment()`.
8. **Ruts.** Drive the same stretch twice; the second pass should sit lower and the
   terrain should show the wheel lines. If ruts look blocky, the mud grid is 0.5 m
   (`Terrain.CELL`).

Known guesses to validate: spring/damper numbers in `wheel.gd`, mud drag
coefficient (`1500.0` in `wheel.gd`), low-range force (`26000` N).

## Queued (asked for, not started)

- **River crossing** like the reference photos: wide, shallow, clear water over
  river stones, white water piling against the bumper, rooster-tail spray, a
  glassy pool with reflections.
- **Flung mud lands**: clay thrown by the tires piles into berms beside and
  behind the ruts instead of vanishing.

## Not done in M1

No audio, no AI buddy rig, no missions, one vehicle.
