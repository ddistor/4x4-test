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
	out.append(_flatfender())
	out.append(_kuwarenta())
	return out


static func get_kind(i: int) -> RigSpec:
	var all := kinds()
	return all[clampi(i, 0, all.size() - 1)]


## The original: a lifted Willys-style flatfender on 35s.
static func _flatfender() -> RigSpec:
	var s := RigSpec.new()
	s.id = "flatfender"
	s.name = "Flatfender"
	s.blurb = "Lifted Willys-style tub on 35s, roll cage, winch. Light and nimble."
	# engine up front, and high: lifted on 35s puts it ~0.8 m off the ground,
	# so it rolls on an off-camber before it slides (tilt-table ~40 deg)
	s.center_of_mass = Vector3(0, 0.5, -0.1)
	s.build_body = FlatfenderBody.build
	return s


## A 40-series-style hardtop: short, upright, leaf springs front and rear,
## two-tone with the white top. Heavier than the flatfender and longer between
## the axles, on 33s; the stiff leaves keep it flat but lift a wheel sooner.
static func _kuwarenta() -> RigSpec:
	var s := RigSpec.new()
	s.id = "kuwarenta"
	s.name = "Kuwarenta"
	s.blurb = "Forty-series-style hardtop on 33s: leaf springs, short and tough, a classic."
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
