# To check in Claude Code / by hand

## Career polish (branch `career-polish`, off main)

- **New career**: Look page, "Start a new career" (press twice).
- **Restart / New stage** in the pause menu now pays the entry fee again.
- **Lockers** are a part (Drivetrain page): open, auto rear (always locked,
  turns a little wider), selectable rear, selectable front and rear (the
  Rubikon comes with them). L only locks what's fitted; free play still
  locks both on every rig. A locked front steers 25% less: check by driving
  that it feels like a locked front, and that the test bot still copes.
- **Kit page**: beadlocks (air down to 8 psi, never off the bead), on-board
  compressor (without one, you can't air back up on the trail), traction
  boards and high-lift jack (a career rig starts with just the shovel).
  Free play has the lot, as before.
- **Tires move** to another of your rigs with the same bolt pattern (Gera,
  Gerilya, Owner, Feroz on 5 on 5.5; Kuwarenta and Ronda on 6 on 5.5;
  Rubikon on 5 on 5).
- **Sell a rig** (Look page): 60% of it and its parts, less the repairs.
- **Seasons**: win the Morong Trophy and the next season's purses and fees
  are a fifth bigger, each one you win; shown next to the pesos.
- **Each event has its own trail**: club run pasture and farm road,
  challenge clay climb, Tanay Cup bog and clay, Invitational rock steps and
  gully, Trophy rock steps, gully and lahar (plus the river and kanal every
  stage has). Free play stages are unchanged.
- **Edge boulders** (Hard and up): big ones just outside a tire track in the
  rock steps, gully and lahar. Lean toward one and the sills drag (rock
  sliders); slide into one and the front tire slams it (tie rods). Straddle
  rocks now really stand 0.5 to 0.72 m (the rock mesh is squashed).
- **Damage you can hear and see**: a bang when a knock does damage, a deep
  crack when something breaks, steam off the nose when it boils. Dents in
  the body aren't modelled yet.
- **First visit**: a card in the career garage explains how it works.

## Career mode: parts, armor, damage, more rigs (on main)

- **Career mode** on the start menu: pick a rig (any stock one), ₱60,000 to
  start. The ladder (each opens after finishes of the one before):
  Sunday club run (Moderate, ₱20,000) → 2 → Club challenge (Hard, ₱35,000)
  → 3 → Tanay Cup round (Hard, rainy, ₱50,000, entry ₱5,000) → 3 →
  Invitational (Extreme, ₱75,000, entry ₱15,000, roll bar required) → 3 →
  Morong Trophy (Extreme, rainy, ₱120,000, entry ₱25,000, full cage and
  snorkel). First finish of an event +50%, no marshals +25%, ₱4,000 per
  marshal recovery, never under a quarter of the purse. Repairs one part at
  a time or all (click the Repairs row to pick). `tests/career_test.tscn`
  plays whole careers by sum (careful and rough drivers reach the trophy in
  12-13 runs, never broke) and then the real scenes end to end. To check by
  playing: does it feel too quick or too slow? The pacing is the `runs`,
  `pay` and `fee` in `Career.EVENTS`. Saved in `user://career.cfg` (old
  saves move to the new ladder); free play is unchanged and never uses parts.
- **Parts page** in the career garage: tires (31 to 37 in, mud-terrain or
  all-terrain), lift (2.5 in, 4 in, 4 in long-travel), axle gears (4.10 to
  5.38), 4:1 low range. Click a part to try it on the pad, then buy/fit. The
  body keeps its stock wheel wells, so bigger tires need lift (about 1 in per
  inch of tire): the Gera takes 37s on 2.5 in, the 31-in rigs top out at 35s.
  Bought parts stay yours when swapped out.
- To check by driving: a Gera on 37s and 4 in should clear rocks and float
  better in the bog but tip sooner on the off-cambers; 5.13s and 4:1 should
  crawl the rock steps much slower and steadier. All-terrains should pack up
  in sticky clay sooner than mud-terrains.
- To check by eye: the garage panel at your screen size (`-- --career
  --snap-garage` saves `snaps/95_career.png`), the payout card at the finish.
- **Damage** (career only; `--damage` turns it on in free play): the HUD shows
  coolant and anything broken. Belly on rock cracks the oil pan (runs hot,
  then no low range); a front tire slammed sideways into rock bends the tie
  rod (pulls to one side); a spinning tire that grabs with the lockers in can
  snap an axle shaft (that axle stops driving; open diff, both wheels); sills
  and rollovers dent the body; a mud-caked nose overheats the engine when
  you work it hard (limp, then it quits; a river washes the radiator); water
  over the intake hydrolocks it (Backspace: the marshals drain it, the engine
  is worn after). Clay knocks count a third of rock. Damage carries between
  events; the garage's Repairs row shows the bill and fixes it all.
- **Armor page**: skid plates (and they slide you off a rock), rock sliders,
  roll bar / full cage (only up from what the rig came with), snorkel
  (wade to ~1.5 m), chromoly shafts, heavy-duty tie rods. Bolted-on armor is
  generic, sized off each body: check by eye that it sits right on every rig
  (`-- --career --snap-garage --flex` after fitting it).
- **The map, tuned for it**: every rig now has an underbody (oil pan,
  gearbox, transfer case) as a solid, about 0.55 m off the ground stock; a
  lift and bigger tires raise it, skid plates cover it. Rock steps, the
  gully, the lahar wash and the talahib ridge get straddle rocks on Hard and
  Extreme (none on Moderate): boulders right on the line between the tire
  tracks, 0.5 to 0.75 m tall, that high-centre a stock rig. To check by
  driving: put a tire on one and crawl over; straddle it stock and hear the
  pan crack; with 4 in and 37s most clear. Rivers were already tuned: a
  shallow ford off the line, pools that drown a stock intake on Hard and up.
- **More rigs**: the Rig row cycles every rig, yours or for sale (₱300,000
  Owner .. ₱1.6M Rubikon); each keeps its own parts and damage.
- To check by driving: does a normal run break about the right amount? The
  test bot (seed 7, 21) comes home with a few percent off the tie rod and
  body; hard driving in the gully and rock steps should cost more.
- Tests: `tests/parts_test.tscn` (fits, money, rigs, repairs, old saves, ride
  height on a stage), `tests/damage_test.tscn` (each way it breaks, with and
  without the part that saves it), `tests/well_test.tscn` also checks every
  lift with the biggest tires and all the armor.
  `--parts lift=4,tires=37_mt` drives parts in free play for tests.

## Tire pressure, water, ruts, the test bot

- **Airing down** (`-` / `=`, stopped) now matters on rock: the soft carcass
  wraps the edges (`wheel.gd`, `rocky`), and a soft tire costs a little more
  to roll on firm ground. `tests/psi_test.tscn`: Gera climbs 30 deg of dry rock
  at 35 psi, 38 at 15; in the bog it sinks 0.44 m instead of 0.62 and gets
  further. The rock steps' steepest pitches (~46 deg on Hard) are past what
  35 psi holds: air down or winch. To check by driving: the difference on the
  rock steps and in the bog.
- **Water**: the body rides up a few cm on its springs and the tires lose
  weight (a closed wagon a quarter at 0.86 m, an open tub hardly any), so grip
  drops and the current shoves harder; wheels stay down. `tests/float_test`.
- **Ruts and water**: churning no longer wets the ground; a rut holds water
  only where the ground was wet already (rain, low ground). Dry season: dry
  ruts; rainy: the dug hole fills.
- **Test bot** (`tests/drive_test`) drives like a person: stops and airs down
  to 15 psi, 4L and lockers off the road, winches to the anchor furthest up
  the trail when stuck 4 s, marshal recovery only after 15 s. It now prints
  WINCH lines; its recoveries mark where even the winch had nothing in reach.

## Three new sections, a reworked lahar wash and rock steps

- **Pastulan two-track** (Sampaloc, Tanay): open green hillside pasture, two
  muddy wheel ruts with a grassy hump between, forest at the edges. The ruts
  drain to firmer clay on the climb.
- **Talahib ridge** (Mt. Balagbag, Rodriguez): along a crest, the land falling
  away both sides, a firm stony dirt track, talahib in flower (white plumes)
  crowding both edges, a lone tree on the shoulders.
- **Overgrown trail** (Real, Quezon): a narrow shelf cut across a steep slope,
  overgrown right to the wheel lines with ferns, shrubs and tall grass you push
  through (no collision). `terrain.gd` / `vegetation.gd` / `stage_plan.gd`.
  Adding them to the pool reshuffles every seed's sections. `tests/find_seed.gd`
  finds seeds with given kinds; `tests/plan_dump.gd` prints a stage's grades.
  Headless bot: no recoveries in them on seeds 7, 9, 63 (after easing their
  climbs and drying the ruts on slopes; at first it slid back down the wet
  pasture climb and sank in a wallow before the overgrown climb).
- **Lahar wash** from Pinatubo/Porac trail accounts: a braided stream running
  down it crossing the trail again and again, cobble bed, deeper pockets,
  boulder clusters, one slot canyon where the walls close in, soft sodden sand
  on the banks; rocks and tire spray take grey ash there. **Rock steps**: bare
  bedrock (no grass on the rock), loose rubble. The chase camera stays out of
  canyon walls. To check by driving: all of these, and how the talahib and the
  overgrowth look from the seat camera.

## Gearbox and recovery kit

- **Gearbox** (`scripts/vehicle/gearbox.gd`, numbers per rig in `rig_spec.gd`):
  every rig has its own engine (torque curve, idle, redline: V8s, the old
  straight-six, a buzzy 1.6, diesels, a modern V6), real-ish gear ratios, a
  final drive and a low-range transfer case (the Rubikon's 4:1). **Engine
  braking**: off the throttle in 4L first a 58% descent holds at ~9 km/h
  (Rubikon), ~15 (Gera), ~17 (Kuwarenta, tall gearing, it over-revs). Auto by
  default, shifting on road speed (it holds its gear while spinning in mud);
  **E / Q** shift up / down and make it manual, **T** back to auto. In manual
  you can stall it: lugging at idle against something in too tall a gear;
  throttle cranks it again. Air drag and rolling resistance replace the old
  speed cap (and Godot's default damping, ~3 kN at 60 km/h, is off), so top
  speed comes from the gearing: ~100-115 km/h on the flat in 4H. Sound follows
  the gearbox's rpm and goes quiet when stalled. HUD: gear, auto/manual, rpm,
  and "ENGINE CHOKING" when water is over the intake (that one needs the winch).
  `tests/tip_test.tscn -- --rig ID --drive` (acceleration) / `--descend`.
  To check by driving: shift feel, whether auto picks sensible gears on the
  climbs, engine braking down the pitches, stalling in manual.
- **Recovery kit** (`scripts/vehicle/recovery_kit.gd`), stopped only, the
  rig won't drive while you're out: **1 shovel** (6 s) digs the soft mud out
  round and 2.5 m ahead of every tire down to firm ground; **2 traction
  boards** jammed in as ramps ahead of the front tires (behind the rear in
  reverse), grippy (`wheel.gd`, group "boards"), 2 again picks them up, left
  behind they're collected at 20 m; **3 high-lift jack** (5 s) lifts the rig,
  packs stones under the tires that were hanging (full droop or no load),
  nudges it 0.3 m on and sets it down. `tests/kit_test.tscn -- --seed N`.
  Headless: in the kanal the shovel took one stuck rig from 0.2 m to 1.5 m of
  progress, and jack-and-stack got a cross-axled one moving; the boards
  haven't been proven yet (the bogs here don't strand a rig driven in 4L
  locked). To check by driving: all three, and whether the boards earn their
  place.
- **Known**: the kanal ruts cross-axle the rigs (one diagonal pair hangs at
  full droop), which is where the test bot needs most of its recoveries.
  Worth a look at droop vs rut depth.

## River ford, ground without squares

- **Fords**: the stony river used to be equally deep all along, right at the
  engine-choke depth, so there was no line to pick. Now a gravel riffle ~4.5 m
  wide sits a couple of metres off the trail line, 0.42-0.50 m deep on Hard,
  falling away to pools of 0.75-0.90 m up and downstream (`terrain.gd`,
  `"ford"` crossings). `tests/ford_test.tscn` prints the depth along each
  river. To check by driving: can you read the riffle from the water (paler,
  rippled) and find it; the pools should choke the engine.
- **Ground squares**: the noise hash in the terrain, water and rock shaders
  ran out of float precision a few hundred metres up the stage, so the
  ground broke into blocks with dark seams. It now hashes the float's bits.

## Graphics settings

*Graphics* in the start menu and the Esc menu (`scripts/ui/settings_menu.gd`,
settings in `scripts/graphics_settings.gd`, saved to `user://graphics.cfg`).
Quality preset Low / Medium / High / Ultra (High is the look it had before),
then window (windowed / fullscreen), V-Sync, frame-rate cap, render scale (FSR
below 100%), anti-aliasing (off / FXAA / MSAA 2x / 4x / TAA), shadows, ambient
occlusion, reflections, volumetric fog, glow, grass and tree draw distance.
Click for the next option, right-click for the previous; a hand change turns
the preset Custom. Everything applies live, mid-stage too. Rendered here: the
screen (`--snap-settings`) and a stage on Low vs High (haze, AO, grass
distance and resolution all change). To check by hand: fullscreen and V-Sync
on your monitor, frame rate on Low vs Ultra, TAA's smearing on the grass.

## Rolling over, winch jolts, wheel wells, finish banner

`tests/tip_test.tscn` (new, headless): a tilt table with a lip, or `--winch`
pulling the rig over a 0.3 m curb. `-- --rig ID [--winch] [--no-lip]`.
- **Rigs roll over now.** The solid-axle load transfer (`axle_roll_stiffness`
  in `rig.gd`) could hand the low side more than the high side carried, a free
  righting force: every rig held on to 45.7 deg on the tilt table. Capped to
  the light side's load: Kuwarenta, Gerilya, Feroz, Ronda now roll at 41-42 deg
  (their geometry), the wide low Gera last at ~48. And tires **trip**: sliding
  sideways into something steep (rock, rut wall, bank, curb) they're stopped
  at ground level instead of riding over it like a ray (`wheel.gd`, `lat_at`),
  so a rig sliding off-camber into a rut can go over. On open ground the side
  force still goes in at axle height (the cornering-roll fix stays).
- **Winch jolts**: the line was an undamped spring that went slack and snapped
  tight; now it's damped (`WINCH_C`), reels in slack instead of leaving it, and
  tires are round to the ground (`wheel.gd`: rays fore and aft against the
  tire's curve) so a curb or ledge lifts them gradually, not in one step.
  Curb pull: worst bounce 1.52 -> 0.69 m/s, vertical jolt 154 -> 83 m/s2, no
  slack-snaps.
- **Wheel wells** were skinned only on the tire side, so from the seats you
  saw the tire through the humps; both faces now (`body_kit.gd`), every rig.
- **Finish banner** raised to 5.6 m (the chase camera ran into it); its poles
  stand on the ground where they are.
To check by driving: off-camber in the kanal and lahar (does it go over when
it slides into a rut, and not too easily); winching up the rock steps.

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

## Water and the barangay road look

`water.gdshader` now works out depth from the terrain (`Terrain.bed_texture`)
instead of the depth buffer, so it looks the same on every renderer: clear
rivers show the cobbles in the shallows and go green in the pools, the sky
mirrors at a glancing angle, foam lines the banks and the riffles, the bank
edge is soft. The rig rings each tire with white water, trails a V wake when it
moves, and spinning tires in a clear river stir up a brown plume that drifts off
downstream (`Rig._stir_water`; not seen rendered yet, the snapshot rig is parked).
Muddy water is opaque a hand deep with brown froth. The paddy road is packed
grey-brown dirt with paler loose stones and darker wheel lines instead of near
white. To check by driving: wakes and the plume through a river, and how the
water reads in Forward+ (only the simpler renderer was available here).

## Mud: slower, sets hard, flakes, washes realistically

`rig.gd` (mud on the rig) and `mud_cake.gdshader`. Rolling through clay only
flecks the arches now; it's wheelspin in deep wet mud that plasters a corner,
and it builds over tens of seconds, not a few (seed 3 bog: ~60% after 50 s,
was 15 s). Bog water no longer washes it. Left to dry (~3 min) it sets into a
crust; hard knocks then chip it off along its cracks (falling chips), leaving
dull clay-stained paint; fresh mud covers those spots again. A wade washes only
what's below the waterline, slowly and thin edges first; set crust barely
shifts. A lifted rig in knee-deep water only gets its wheels and axles clean.
`tests/mud_test.tscn` runs the cycle headless (`--pictures --close` with a
window for the four stages). To check by driving: the build-up rate, flakes
falling off over the rock steps, and how long a ford takes to clean the sills.

## Front corners closed up

On the Rubikon you could see into the body at the front corner: the grille
face stopped short of the fender sides, the side panels started 5 cm behind
the nose, and the hood stood proud of the fender tops. Fixed there, and the
same nose gap on the Ronda and Feroz. `--snap --snap-rig --rig ID` now also
saves `97_rig_corner_ID.png`, a close-up of the front-left corner; all six
checked. The Gera and Owner keep their open flat fenders on purpose (you see
the engine bay under them, like the real ones).

## Rock gully (new section kind)

"Rock gully · Wawa, Montalban" (`gully` in `stage_plan.gd::KINDS`, shaped in
`terrain.gd`): a sunken cut through dense forest, a grey rock wall on one side
and a steep earth bank on the other, the floor ~4.5 m wide. Wet red clay with
stones half-buried in it in rock gardens, big ones fallen at the foot of the
walls, one climb with a muddy wallow at its foot. Stones now wear the clay they
sit in (`rock.gdshader`, per-stone mud coat), dark and glossy in the gully. The
trail line wiggles much less here than elsewhere (`jitter`), or the narrow
floor zig-zags faster than a rig turns. Seed 10 has one right after the paddy
road; `--snap --snap-only gully --seed 10` shoots it. Headless bot: Moderate,
all four rigs through with no recoveries. To check by driving: picking a line
over the stones, how slick the clay feels on the climb, and that the walls
read as rock.

## Rubikon (modern four-door)

Sixth rig: `bodies/rubikon_body.gd`, spec `rig_spec.gd::_rubikon`. Body colour
with a black hardtop, round lamps in a nine-slot body-colour grille (not the
seven-slot one), long vented hood, big black trapezoid flares, exposed door
hinges, rock sliders, steel winch bumper, spare on the tailgate. 2300 kg on 35s,
3.0 m wheelbase, the most droop (0.22 m) and the softest roll bar (sway bar
unhooked), strong low-range pull. Checked flexed in the garage; headless bot
drives it fine. To check by driving: keeps all four tires down on the kanal
ruts and rock steps better than the others, leans more in fast turns.

## Owner (owner-type jeep) and stainless paint

Fifth rig: `bodies/owner_body.gd`, spec `rig_spec.gd::_owner`. A shop-built
owner-type jeep: low doorless tub (the sides dip by the front seats), flat
fenders, chrome grille of vertical bars with the round lamps on it, chrome
crease and bumpers, upright windshield, flat canopy roof on a chrome roll hoop,
a flat deck with red vinyl benches down both sides, spare on the tailgate,
winch. 1450 kg on 31s, 2.35 m wheelbase. New paint for every rig: *Stainless
steel* (polished metal instead of gloss paint; `Game.PAINTS`, `Rig.paint_mat`).
Checked flexed in the garage. To check by driving: feels like a light, simple
rig; the stainless looks right in daylight and in the forest shade.

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

## Gerilya (the Gera built for the trail)

Last rig in the *Rig* picker (appended so saved picks keep their rig):
`GeraBody.build_trail`, spec in `rig_spec.gd::_gerilya`. From trailhead photos:
a full cage with its own front hoop, a flat rust-brown steel plate for a roof
and a single-strip LED light bar under its front edge, the windshield folded
flat on the hood, US Willys tub sides with the deep curved door cutout
(`_scooped_side`; full-height flat sides read Japanese-built) and rounded back
corners, the Willys grille with round shoulders and tall slots
(`_grille_panel`), the army blackout lamp on the left fender, round cowl
mirrors, silver steel wheels (`RigSpec.wheel_color`, a `tire.gdshader` uniform;
every other rig keeps black),
an army-green bumper with D-rings and four driving lights round the winch,
wire guards over the headlights, rock sliders, tan bucket seats, a jerry can.
On 37s, 2000 kg, a bit more droop and low-range pull than the Gera. Rendered
with `--snap --snap-rig --rig gerilya --look 0,0,0`; the headless bot drives
it through the cogon fine. To check by driving: does the taller rig tip
sooner off-camber than the Gera; the seat camera with the roof plate and
light bar overhead; the folded windshield doesn't get in the way of the view.

## Kuwarenta (forty-series-style, top off)

Second rig in the *Rig* picker: `bodies/kuwarenta_body.gd`, spec in
`rig_spec.gd::_kuwarenta`. Reworked from trail photos: round-shouldered front
fenders that flare out over the tires (`_fender`), both headlights in a flat
grille panel with a dark mesh between them, signal lamps on the fender fronts,
a wide hood with a crowned middle rolled down over the grille (`_hood`), doors
off (a low step in the opening, hinge stubs on the cowl post), a broad nearly
upright windshield frame, and a roll bar over the seats instead of the glass
hardtop. Arches cut round 33s, spare on a rear carrier, winch bumper. Heavier
(2050 kg), longer wheelbase (2.29 m), stiffer leaf-spring rate and less droop
than the Gera. Rendered with `--snap --snap-rig --rig kuwarenta --look 4,0,0`
(Bay blue); the headless bot drives it through the paddies and cogon fine. The
arch-to-tire gap is set by bump clearance, so it stays. To check by driving:
feels heavier and flatter than the Gera, lifts a wheel sooner on the kanal
ruts; seat camera (C) behind the new windshield, the roll bar in view;
the winch line leaves the bumper; rolled over, the roll bar (not a roof box)
now holds it up.

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
  6. Rubicon style (modern Wrangler): lockers, disconnecting sway bar, big tires. **Built: Rubikon.**
  7. FJ Cruiser style: retro body, independent front suspension, wide and stable.
  Claude's earlier ideas:
  8. Jimny/Samurai-style mini: light, narrow, floats, small tires.
  9. Land Cruiser 70-style heavy wagon: lockers, snorkel, heavy.
  10. Hilux/Strada-style pickup with independent front suspension: stable, poor flex, long overhangs.
  11. Owner-type jeep: the Filipino-built kind. **Built: Owner.**
  12. Pajero-style 90s coil-sprung SUV.
- **Upgrades** (future, from the user; more to come): fit parts to a rig in
  the garage, kept per rig with the rest of the look (`user://look.cfg`).
  1. **Wheels and tires**: size and kind (mud-terrain, all-terrain), black
     beadlocks or silver steelies (`RigSpec.wheel_color` already exists). A
     size change moves grip, sink and floatation (`wheel.gd`), ground clearance
     and the wheel wells (`BodyKit.well_radius` follows tire size), and how
     hard the gearing pulls.
  2. **Roll cage**: none, roll bar or full cage, modelled on the body; in a
     rollover it carries the rig instead of the body and the driver (the
     collision box), and it matters more once damage exists.
  3. **Skid plate**: steel under the belly; a high-centred rig slides off a
     rock instead of hanging on it, and later it keeps the oil pan and transfer
     case from damage (realism plan, item 3).
  Needs a garage page for parts. Wants the damage model to really pay off.
  Research, full part list and a career-mode plan: `docs/upgrades.md`.
  **Started:** wheels and tires built (career parts, see the top of this file).
  (open questions at the bottom for you).
- **After that, the realism plan:**
  1. Real gearbox: torque curve, gears, engine braking on descents, stalling in
     low range. **Built.**
  2. Recovery kit: shovel (dig out a high-centred rig), traction boards,
     high-lift jack. **Built.** Still to do: snatch strap if a buddy rig arrives.
  3. Damage: mud-caked radiator overheats, axle/CV snaps when shock-loaded with
     lockers in, tie rod bends on rocks, hydrolock in deep water (snorkel fix).
  4. Weather that changes during a run: rain starting, puddles growing.
- Ilocos / Zambales beach sand as its own section (lahar covers loose sand for now).
