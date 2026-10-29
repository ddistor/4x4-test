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
var spring_stiffness := 38000.0             # N/m per corner (see wheel.gd)
var droop := 0.15                           # extra travel below rest, m
var bump := 0.2                             # up-travel from ride height to the bump stop, m

## Where the hubs ride (rig space y) when the rig sits on level ground.
const RIDE_HUB_Y := 0.13


## Highest the top of a tire reaches, at the bump stop: wheel wells clear this.
func max_tire_top() -> float:
	return RIDE_HUB_Y + bump + tire_radius


## Inner face of the tires, with a little room: floors and tubs stay inboard of it.
func tire_inner() -> float:
	return track - tire_width * 0.5 - 0.04
# drivetrain (see the @export defaults at the top of rig.gd)
var drive_force_high := 13000.0
var speed_high := 26.0
var drive_force_low := 26000.0
var speed_low := 11.0
var max_steer := deg_to_rad(32.0)
var axle_roll_stiffness := 18000.0
# where the winch cable leaves the bumper, the seat and the steering wheel
var fairlead := Vector3(0, 0.75, -1.86)
var seat := Vector3(-0.33, 0.8, 0.27)       # the driver's hips
var wheel_at := Vector3(-0.33, 1.2, -0.1)   # steering wheel hub
var build_body: Callable


static func kinds() -> Array[RigSpec]:
	var out: Array[RigSpec] = []
	out.append(_gera())
	out.append(_kuwarenta())
	out.append(_feroz())
	out.append(_ronda())
	out.append(_owner())
	out.append(_rubikon())
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
	s.build_body = GeraBody.build
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
	s.drive_force_high = 12500.0
	s.speed_high = 25.0
	s.drive_force_low = 27000.0
	s.speed_low = 10.0
	s.max_steer = deg_to_rad(30.0)
	s.axle_roll_stiffness = 21000.0
	s.fairlead = Vector3(0, 0.72, -1.98)
	s.seat = Vector3(-0.36, 0.82, 0.3)
	s.wheel_at = Vector3(-0.36, 1.22, -0.07)
	s.build_body = KuwarentaBody.build
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
	s.drive_force_high = 9500.0
	s.speed_high = 27.0
	s.drive_force_low = 19000.0
	s.speed_low = 11.0
	s.max_steer = deg_to_rad(34.0)
	s.axle_roll_stiffness = 14000.0
	s.fairlead = Vector3(0, 0.66, -1.88)
	s.seat = Vector3(-0.34, 0.78, 0.2)
	s.wheel_at = Vector3(-0.34, 1.16, -0.17)
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
	s.drive_force_high = 16000.0
	s.speed_high = 28.0
	s.drive_force_low = 34000.0
	s.speed_low = 10.0
	s.max_steer = deg_to_rad(30.0)
	s.axle_roll_stiffness = 26000.0
	s.fairlead = Vector3(0, 0.74, -2.56)
	s.seat = Vector3(-0.42, 0.88, 0.02)
	s.wheel_at = Vector3(-0.42, 1.28, -0.38)
	s.build_body = RondaBody.build
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
	s.drive_force_high = 10500.0
	s.speed_high = 25.0
	s.drive_force_low = 21000.0
	s.speed_low = 10.0
	s.max_steer = deg_to_rad(33.0)
	s.axle_roll_stiffness = 16000.0
	s.fairlead = Vector3(0, 0.66, -1.98)
	s.seat = Vector3(-0.34, 0.74, 0.12)
	s.wheel_at = Vector3(-0.34, 1.13, -0.23)
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
	s.mass = 2300.0
	s.center_of_mass = Vector3(0, 0.58, -0.1)
	s.track = 0.82
	s.front_z = -1.5
	s.rear_z = 1.5
	s.tire_radius = 0.445
	s.tire_width = 0.32
	s.spring_stiffness = 42000.0
	s.droop = 0.22
	s.drive_force_high = 15000.0
	s.speed_high = 30.0
	s.drive_force_low = 32000.0
	s.speed_low = 11.0
	s.max_steer = deg_to_rad(33.0)
	s.axle_roll_stiffness = 12000.0
	s.fairlead = Vector3(0, 0.74, -2.48)
	s.seat = Vector3(-0.4, 0.88, 0.0)
	s.wheel_at = Vector3(-0.4, 1.28, -0.4)
	s.build_body = RubikonBody.build
	return s
