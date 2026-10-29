# To check in Claude Code / by hand

## M1 mud playground (branch `m1-mud-playground`)

Built blind in a headless session — the physics runs and the headless drive test
gets from the paddies through the creek, but nobody has *seen* it yet. In order:

0. **Snapshot mode works on Windows.** Run `Godot.exe --path . -- --snap` from the
   repo folder; it should open a window for ~10 s and leave 7 PNGs in `snaps/`.
   If `snaps/` is empty, check the console for the `saved ...` lines.
1. **Open in Godot 4.7+ and press F5.** First run showed white ground: terrain
   triangles were wound backwards and culled. Fixed, along with washed-out
   colours (`source_color`), clay smeared over the whole lower map (creek check
   had no z limit), paddy water covering the road, heavy fog, and the paint
   looking muddy at 0%. Paddies now have pilapil dikes and darker water.
   Re-check by eye: gravel road → red clay into the trees, green hills, brown
   creek at z≈112. Trees are still lollipops; graphics pass is the next job.
2. **Drive the road** (W). Should reach ~35 km/h on the gravel. Steering (A/D)
   should feel heavy but not sloppy. The rig is now a lifted black flatfender on
   35s with a shorter wheelbase (2.35 m) and less mass (1950 kg), so it may pitch
   and wander more than the old one. Drag with either mouse button to orbit,
   scroll to zoom; C is a driver's-seat cam you can look around in.
3. **Hit the first clay at z≈50 in 4H / open diff.** Intended: it bogs within a
   few metres and one wheel per axle spins. Press **G** (4L) and **L** (diff lock)
   and it should crawl out at 5–7 km/h. If it crawls out too easily in 4H, raise
   `wetness` on the lower climb in `terrain.gd::_author_mud`.
4. **Creek crossing at z≈112.** Sinks ~0.4 m, splashes, engine chokes if the front
   wheels go past ~0.75 m of water. Should be passable in 4L.
5. **Upper switchbacks past z≈139.** The old rig jammed here; the new one (more
   clearance, shorter overhangs) gets the headless test to the top at z≈249.
   Worth a drive to confirm it isn't just luck.
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

## Not done in M1

No audio, no AI buddy rig, no missions, one vehicle. Terrain and forest are still
flat-shaded primitives (next up: making the surroundings and ground mud look real).
