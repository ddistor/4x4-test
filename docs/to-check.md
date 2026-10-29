# To check in Claude Code / by hand

## M1 mud playground (branch `m1-mud-playground`)

Built blind in a headless session — the physics runs and the headless drive test
gets from the paddies through the creek, but nobody has *seen* it yet. In order:

0. **Snapshot mode works on Windows.** Run `Godot.exe --path . -- --snap` from the
   repo folder; it should open a window for ~10 s and leave 7 PNGs in `snaps/`.
   Untested on a real GPU (written headless). If `snaps/` is empty, check the
   console for the `saved ...` lines.
1. **Open in Godot 4.7+ and press F5.** Seen once: it runs. First screenshot showed
   fog far too thick (reduced), paddies reading as a void (dikes + darker water
   added, unverified), the rig as a tall box with the wheels hidden under the body
   shell, and lollipop trees. Graphics pass is the next job — use `--snap`.
2. **Drive the road** (W). Should reach ~35 km/h on the gravel. Steering (A/D)
   should feel heavy but not sloppy. Chase cam (C toggles hood cam).
3. **Hit the first clay at z≈50 in 4H / open diff.** Intended: it bogs within a
   few metres and one wheel per axle spins. Press **G** (4L) and **L** (diff lock)
   and it should crawl out at 5–7 km/h. If it crawls out too easily in 4H, raise
   `wetness` on the lower climb in `terrain.gd::_author_mud`.
4. **Creek crossing at z≈112.** Sinks ~0.4 m, splashes, engine chokes if the front
   wheels go past ~0.75 m of water. Should be passable in 4L.
5. **Upper switchbacks past z≈139.** The headless test rig jams here on firm ground
   at zero speed with wheels spinning — likely the chassis catching the cut bank or
   the test's line-follower turning into it. Needs a human look. If the banks are
   the problem, soften `smoothstep(2.8, 7.0, dx)` in `terrain.gd::_base_height`.
6. **Winch (F).** Point the nose roughly at a trunk within 18 m and press F. A line
   should draw and the rig should get pulled at ~0.9 m/s. F again releases.
   Trees right at the bank edge (12% of them) are the intended anchors.
7. **Mud caking.** Paint should go from red to clay from the bottom up as you churn.
   Rate was set so it takes a minute or two of slop to look fully caked; adjust
   `0.03` in `rig.gd` (`cake = ...`) by feel.
8. **Ruts.** Drive the same stretch twice; the second pass should sit lower and the
   terrain should show the wheel lines. If ruts look blocky, the mud grid is 0.5 m
   (`Terrain.CELL`).

Known guesses to validate: spring/damper numbers in `wheel.gd`, mud drag
coefficient (`1500.0` in `wheel.gd`), low-range force (`26000` N).

## Not done in M1

No audio, no AI buddy rig, no missions, one vehicle, primitive-box art.
