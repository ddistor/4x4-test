class_name RigSpec
extends RefCounted
## What makes one rig different from another: size, weight, tires, gearing,
## where the driver sits, and the function that models its body. The rig
## (rig.gd) is the same machine underneath for all of them. Picked in the
## start menu (Game.rig_kind); add a rig by adding a kind to `KINDS`.
##
## Local nicknames, no brand names: these are the kinds of rigs you meet at
## a trailhead in Rizal.

var id := ""
var name := ""
var blurb := ""
# body and balance
var mass := 1950.0                          # kg
var center_of_mass := Vector3(0, 0.5, -0.1)
# wheels: half-track, axle positions (forward is -Z), mount height, tire size
var track := 0.8
var front_z := -1.3
var rear_z := 1.05
var wheel_mount_y := 0.35
var tire_radius := 0.445
var tire_width := 0.32
var wheel_color := Color(0.03, 0.03, 0.032)  # black beadlocks; silver for steelies
var spring_stiffness := 38000.0             # N/m per corner (see wheel.gd)
var droop := 0.15                           # extra travel below rest, m
var bump := 0.2                             # up-travel from ride height to the bump stop, m
var tread := 1                              # 0 all-terrain, 1 mud-terrain
## A suspension lift (career parts): the hubs ride this much further below
## the body, m. The body and its wheel wells stay where they were built.
var lift := 0.0
## Contact patch against the stock tires (career parts): >1 floats more.
var footprint := 1.0
## Set by Parts.apply: the tire top at the bump stop the body was built for,
## so wells keep their stock size whatever is fitted under them (0 = follow
## the tires).
var fender_top := 0.0
# armor and protection (career parts; what the body is built with is stock)
var cage := 0                 # 0 none, 1 roll bar, 2 full cage
var cage_built := 0           # what the body models itself (stock)
var sliders := false          # rock sliders along the sills
var sliders_built := false
var skid := false             # steel skid plates under the oil pan and transfer case
var intake_depth := 0.9       # water depth at the front tires that drowns the intake, m
var chromoly := false         # chromoly axle shafts: take a shock load far better
var hd_steering := false      # heavy-duty tie rod: bends far less
## Lockers: "open" diffs both ends, "rear_auto" an automatic rear locker
## (always locked), "rear" a selectable rear, "both" selectable front and
## rear. Free play gives every rig "both" (L locks both, as it always has);
## a career starts from what the rig came with, `stock_lockers`.
var lockers := "both"
var stock_lockers := "open"
## Kit (career parts; free play has the lot): beadlock wheels hold the bead
## down to 8 psi; an on-board compressor airs back up on the trail; traction
## boards and a high-lift jack in the back (the shovel is always there).
## Wheel bolt pattern: tires and wheels move between rigs that share it.
var bolt := "5x5.5"
var beadlocks := false
var compressor := true
var boards := true
var jack := true

## Where the hubs ride (rig space y) on level ground on stock suspension;
## the bodies build their wheel wells round this.
const RIDE_HUB_Y := 0.13


## Where the hubs ride with any lift fitted.
func ride_hub_y() -> float:
	return RIDE_HUB_Y - lift


## Highest the top of a tire reaches, at the bump stop: wheel wells clear this.
func max_tire_top() -> float:
	if fender_top > 0.0:
		return fender_top
	return ride_hub_y() + bump + tire_radius


## Inner face of the tires, with a little room: floors and tubs stay inboard of it.
func tire_inner() -> float:
	return track - tire_width * 0.5 - 0.04
# engine and gearing (gearbox.gd): the default is the Gera's small-block V8
# behind a 4-speed, 4.56 axles for the 35s and a 2.72 low range
var engine := "V8 petrol"
var torque_nm := 350.0
var peak_rpm := 2800.0
var idle_rpm := 750.0
var redline := 4800.0
var gears: Array[float] = [4.02, 2.41, 1.41, 1.0]
var reverse_ratio := 4.0
var final_drive := 4.56
var low_ratio := 2.72
var drag_area := 2.3                        # m², drag coefficient x frontal area
var max_steer := deg_to_rad(32.0)
var axle_roll_stiffness := 18000.0
# where the winch cable leaves the bumper, the seat and the steering wheel
var fairlead := Vector3(0, 0.75, -1.86)
var seat := Vector3(-0.33, 0.8, 0.65)       # the driver's hips
var wheel_at := Vector3(-0.33, 1.27, 0.2)   # steering wheel hub
var build_body: Callable
## A closed cab (glass all round): the box inside it, rig space, that mud
## doesn't reach: just inside the body skin, so the outside of a panel takes
## mud and its inside face doesn't (zero = no box).
## The driver in it stays clean too.
var cabin_lo := Vector3.ZERO
var cabin_hi := Vector3.ZERO
## An open tub: the box is its tub, and only flecks land in it.
var cabin_open := false


func closed() -> bool:
	return cabin_hi.x > 0.0 and not cabin_open


static func kinds() -> Array[RigSpec]:
	var out: Array[RigSpec] = []
	out.append(_gera())
	out.append(_kuwarenta())
	out.append(_feroz())
	out.append(_ronda())
	out.append(_owner())
	out.append(_rubikon())
	out.append(_gerilya())   # at the end so saved picks keep their rig
	return out


static func get_kind(i: int) -> RigSpec:
	var all := kinds()
	return all[clampi(i, 0, all.size() - 1)]


## Gera ("war"): the original, a lifted Willys-style flatfender on 35s,
## for the army jeep it comes from.
static func _gera() -> RigSpec:
	var s := RigSpec.new()
	s.id = "gera"
	s.name = "Gera"
	s.blurb = "Lifted army-jeep-style tub on 35s, roll cage, winch. Light and nimble."
	# engine up front, and high: lifted on 35s puts it ~0.8 m off the ground,
	# so it rolls on an off-camber before it slides (tilt-table ~40 deg)
	s.center_of_mass = Vector3(0, 0.5, -0.1)
	s.cabin_lo = Vector3(0, 0.55, -0.32)   # open tub: only flecks land in it
	s.cabin_hi = Vector3(0.695, 2.2, 1.57)
	s.cabin_open = true
	s.cage = 2
	s.cage_built = 2
	s.build_body = GeraBody.build
	return s


## Gerilya ("guerrilla"): the Gera built harder for the trail, the kind you
## see lined up at a Rizal trailhead: full cage with a steel plate for a
## roof, windshield folded down, army-green winch bumper, rock sliders, on
## 37s. A bit heavier and taller than the Gera; the bigger tires climb
## ledges better but it sits higher, so it tips sooner on an off-camber.
static func _gerilya() -> RigSpec:
	var s := RigSpec.new()
	s.id = "gerilya"
	s.name = "Gerilya"
	s.blurb = "The Gera built for the trail: full cage, roof plate, windshield down, sliders. On 37s."
	s.mass = 2000.0
	s.center_of_mass = Vector3(0, 0.55, -0.1)
	s.tire_radius = 0.47
	s.tire_width = 0.33
	s.wheel_color = Color(0.6, 0.61, 0.6)   # silver steelies
	s.droop = 0.18
	s.final_drive = 4.88   # regeared for the 37s
	s.cabin_lo = Vector3(0, 0.55, -0.32)   # open tub: only flecks land in it
	s.cabin_hi = Vector3(0.695, 2.2, 1.57)
	s.cabin_open = true
	s.cage = 2
	s.cage_built = 2
	s.sliders = true
	s.sliders_built = true
	s.build_body = GeraBody.build_trail
	return s


## A 40-series-style rig, top off with a roll bar: short, upright, round
## flared fenders, leaf springs front and rear. Heavier than the Gera and
## longer between the axles, on 33s; the stiff leaves keep it flat but lift
## a wheel sooner.
static func _kuwarenta() -> RigSpec:
	var s := RigSpec.new()
	s.id = "kuwarenta"
	s.name = "Kuwarenta"
	s.blurb = "Forty-series-style on 33s, top off, roll bar: leaf springs, short and tough, a classic."
	s.mass = 2050.0
	s.center_of_mass = Vector3(0, 0.56, -0.05)
	s.track = 0.74
	s.front_z = -1.2
	s.rear_z = 1.09
	s.tire_radius = 0.42
	s.tire_width = 0.3
	s.spring_stiffness = 46000.0
	s.droop = 0.12
	# the old 4.2 straight-six: torque low down, done by 3800
	s.engine = "inline-6 petrol"
	s.torque_nm = 300.0
	s.peak_rpm = 1800.0
	s.idle_rpm = 650.0
	s.redline = 3800.0
	s.gears = [4.92, 2.64, 1.53, 1.0]
	s.reverse_ratio = 5.0
	s.final_drive = 4.11
	s.low_ratio = 2.31
	s.drag_area = 2.4
	s.max_steer = deg_to_rad(30.0)
	s.axle_roll_stiffness = 21000.0
	s.fairlead = Vector3(0, 0.72, -1.98)
	s.seat = Vector3(-0.36, 0.82, 0.5)
	s.wheel_at = Vector3(-0.36, 1.29, 0.05)
	s.cabin_lo = Vector3(0, 0.49, -0.455)   # open tub: only flecks land in it
	s.cabin_hi = Vector3(0.79, 2.0, 1.735)
	s.cabin_open = true
	s.cage = 1
	s.cage_built = 1
	s.build_body = KuwarentaBody.build
	s.bolt = "6x5.5"
	return s


## Feroz ("fierce"): a boxy little 90s two-door with the stepped roof and big plastic flares:
## light, short and narrow on 31s, less power but it goes where the big rigs
## can't turn. Floats a bit over soft clay, runs out of clearance on rocks.
static func _feroz() -> RigSpec:
	var s := RigSpec.new()
	s.id = "feroz"
	s.name = "Feroz"
	s.blurb = "Boxy little 90s two-door on 31s: stepped roof, big flares. Light, short, nimble."
	s.mass = 1350.0
	s.center_of_mass = Vector3(0, 0.5, -0.08)
	s.track = 0.68
	s.front_z = -1.08
	s.rear_z = 1.095
	s.tire_radius = 0.395
	s.tire_width = 0.27
	s.spring_stiffness = 30000.0
	s.droop = 0.14
	# a small 16-valve four that wants revs, five speeds, short gearing
	s.engine = "1.6 four petrol"
	s.torque_nm = 140.0
	s.peak_rpm = 4500.0
	s.idle_rpm = 850.0
	s.redline = 6500.0
	s.gears = [3.93, 2.19, 1.33, 1.0, 0.81]
	s.reverse_ratio = 3.9
	s.final_drive = 5.57
	s.low_ratio = 2.6
	s.drag_area = 1.9
	s.max_steer = deg_to_rad(34.0)
	s.axle_roll_stiffness = 14000.0
	s.fairlead = Vector3(0, 0.66, -1.88)
	s.seat = Vector3(-0.34, 0.78, 0.46)
	s.wheel_at = Vector3(-0.34, 1.23, 0.01)
	s.cabin_lo = Vector3(0, 0.49, -0.495)   # closed cab: glass all round
	s.cabin_hi = Vector3(0.73, 1.69, 1.615)
	s.build_body = FerozBody.build
	return s


## Ronda ("on patrol"): a big four-door wagon from the 90s-2000s, lifted on
## 35s, coil springs and long travel, a diesel that pulls from nothing.
## The heaviest rig: it walks up ledges and rides the ruts, but it sinks
## in the bog where the light ones float.
static func _ronda() -> RigSpec:
	var s := RigSpec.new()
	s.id = "ronda"
	s.name = "Ronda"
	s.blurb = "Big four-door wagon on 35s: coils, long travel, diesel torque. Heavy, sinks in the bog."
	s.mass = 2650.0
	s.center_of_mass = Vector3(0, 0.6, -0.12)
	s.track = 0.82
	s.front_z = -1.5
	s.rear_z = 1.47
	s.tire_radius = 0.445
	s.tire_width = 0.32
	s.spring_stiffness = 52000.0
	s.droop = 0.2
	# the big 4.2 diesel: pulls from idle, out of breath by 4000
	s.engine = "4.2 diesel"
	s.torque_nm = 400.0
	s.peak_rpm = 2000.0
	s.idle_rpm = 700.0
	s.redline = 4000.0
	s.gears = [4.56, 2.6, 1.5, 1.0, 0.79]
	s.reverse_ratio = 4.4
	s.final_drive = 4.625
	s.low_ratio = 2.02
	s.drag_area = 2.8
	s.max_steer = deg_to_rad(30.0)
	s.axle_roll_stiffness = 26000.0
	s.fairlead = Vector3(0, 0.74, -2.56)
	s.seat = Vector3(-0.42, 0.88, 0.18)
	s.wheel_at = Vector3(-0.42, 1.35, -0.27)
	s.cabin_lo = Vector3(0, 0.54, -0.775)   # closed cab: glass all round
	s.cabin_hi = Vector3(0.91, 1.97, 2.235)
	s.build_body = RondaBody.build
	s.bolt = "6x5.5"
	return s


## Owner: the owner-type jeep, built in a Philippine shop from surplus parts:
## a low doorless tub, flat fenders, chrome grille, a flat deck with side
## benches, usually polished stainless. This one's trail-built on 31s with
## a Japanese diesel and axles under it. Light and simple, a long-ish deck.
static func _owner() -> RigSpec:
	var s := RigSpec.new()
	s.id = "owner"
	s.name = "Owner"
	s.blurb = "Owner-type jeep, shop-built from surplus: doorless tub, flat deck, chrome grille. On 31s."
	s.mass = 1450.0
	s.center_of_mass = Vector3(0, 0.48, -0.1)
	s.track = 0.72
	s.front_z = -1.18
	s.rear_z = 1.17
	s.tire_radius = 0.395
	s.tire_width = 0.27
	s.spring_stiffness = 33000.0
	s.droop = 0.15
	# a surplus Japanese truck diesel, five speeds
	s.engine = "2.8 diesel"
	s.torque_nm = 196.0
	s.peak_rpm = 2000.0
	s.idle_rpm = 700.0
	s.redline = 4200.0
	s.gears = [3.97, 2.34, 1.43, 1.0, 0.86]
	s.reverse_ratio = 4.0
	s.final_drive = 4.3
	s.low_ratio = 2.48
	s.drag_area = 2.0
	s.max_steer = deg_to_rad(33.0)
	s.axle_roll_stiffness = 16000.0
	s.fairlead = Vector3(0, 0.66, -1.98)
	s.seat = Vector3(-0.34, 0.74, 0.5)
	s.wheel_at = Vector3(-0.34, 1.2, 0.05)
	s.cabin_lo = Vector3(0, 0.49, -0.495)   # open tub: only flecks land in it
	s.cabin_hi = Vector3(0.75, 1.9, 1.715)
	s.cabin_open = true
	s.build_body = OwnerBody.build
	return s


## Rubikon: the modern four-door trail rig from the factory, lockers front
## and back and a sway bar that unhooks: on 35s it flexes more than anything
## else here and the soft roll bar keeps all four tires down, but it's long
## and heavy, and leans in the turns.
static func _rubikon() -> RigSpec:
	var s := RigSpec.new()
	s.id = "rubikon"
	s.name = "Rubikon"
	s.blurb = "Modern four-door on 35s: lockers, the sway bar unhooked. Flexes the most, a long wheelbase."
	s.stock_lockers = "both"
	s.bolt = "5x5"
	s.mass = 2300.0
	s.center_of_mass = Vector3(0, 0.58, -0.1)
	s.track = 0.82
	s.front_z = -1.5
	s.rear_z = 1.5
	s.tire_radius = 0.445
	s.tire_width = 0.32
	s.spring_stiffness = 42000.0
	s.droop = 0.22
	# modern 3.6 V6, six speeds, and the 4:1 transfer case it's known for
	s.engine = "3.6 V6 petrol"
	s.torque_nm = 353.0
	s.peak_rpm = 4400.0
	s.idle_rpm = 700.0
	s.redline = 6400.0
	s.gears = [4.71, 2.84, 1.84, 1.29, 1.0, 0.8]
	s.reverse_ratio = 4.5
	s.final_drive = 4.1
	s.low_ratio = 4.0
	s.drag_area = 2.5
	s.max_steer = deg_to_rad(33.0)
	s.axle_roll_stiffness = 12000.0
	s.fairlead = Vector3(0, 0.74, -2.48)
	s.seat = Vector3(-0.4, 0.88, 0.2)
	s.wheel_at = Vector3(-0.4, 1.35, -0.25)
	s.cabin_lo = Vector3(0, 0.54, -0.755)   # closed cab: glass all round
	s.cabin_hi = Vector3(0.87, 1.95, 2.195)
	s.build_body = RubikonBody.build
	return s
