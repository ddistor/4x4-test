class_name Yard
extends RefCounted
## Bakuran trail park: the club's practice ground outside Morong. Several
## tracks, each its own layout on the same 160 x 320 m ground (two terrain
## tiles), picked from a list after the garage (ParkSelect). A clay two-track
## loops anticlockwise round each one with every obstacle on the trail itself
## and, mostly, an easy bypass beside it.
##
##   0 Bakuran Loop     the all-rounder: a bit of everything, round a wooded hill
##   1 Putikan          the mud farm: ruts, wallows, a bog, ditches, the winch
##   2 Batuhan          the rock garden: rubble, ledges, boulders, a slab, a stair climb
##   3 Ahon at Lusong   the hills: built climbs from 20 to 45 deg, a steep descent
##   4 Kanal            ruts and ditches: twin ruts, a washout, cross-axle ditches, dips
##   5 Ilog             the river run: three creeks crossed six times, a timber bridge
##   6 Lahar            the ash wash: soft sand, braided streams, dunes, a slot canyon
##   7 Sukal            the jungle trail: tree squeezes, logs, a winch wall, switchbacks
##
## The terrain asks this file what's where (heights, soil, rock, woods,
## stones, trees) for the track in use (`use`); every layout is fixed, so
## each is a repeatable test bed. Lookups work in a track's own (along,
## across) coordinates: the loop is one path, each bypass another.

const SIZE := 160.0          # across (x)
const LENGTH := 320.0        # along (z)
const REACH := 14.0          # how far from a path its lookup grid reaches
const HALF := 2.1            # the tread's half width
const BANK := 3.2            # its cut and fill banks, out to the natural ground

## Each track:
##   name, place, grade, teaches: for the list
##   rain: the season (0 dry .. 1 rainy); clay: how thick and wet the tread
##     is (1 the usual); woods: how much of the land is trees (0..1)
##   loop: control points (x, z), anticlockwise from the trailhead
##   hills: Vector4(x, z, radius, height); noise: how rolling the land is (m)
##   creeks: Terrain's crossings (mid z = zc + amp sin(x freq + phase)); each
##     crossing of the loop wants a ford, rockford, deep or bridge obstacle
##   stones: loose boulders off the trail; rock: bare rock showing off it (0..1)
##   meadow: an open patch kept clear of trees; lot: the trailhead
##   optional: ash (a lahar wash: grey ash and sand), edge (the bank round
##     the park, m), clear (how close trees come to the trail), overgrown
##   obstacles: [name, what it tests, near (x, z), length along the trail,
##     lane half width, bypass side (+1 inside the loop, -1 out, 0 none),
##     bypass offset, kind, {kind's own numbers}]
const TRACKS := [
	{
		"name": "Bakuran Loop", "place": "Morong, Rizal", "grade": "Easy to hard",
		"teaches": "A bit of everything round a wooded hill: bumps, ledges, two creek crossings, a chute, flex, a sidehill, mud and rocks.",
		"rain": 0.45, "clay": 1.0, "woods": 1.0, "noise": 1.2, "stones": 40, "rock": 0.0,
		"loop": [Vector2(80, 16), Vector2(108, 22), Vector2(128, 38), Vector2(136, 62), Vector2(134, 92),
			Vector2(126, 120), Vector2(122, 146), Vector2(126, 172), Vector2(136, 200), Vector2(130, 232),
			Vector2(112, 258), Vector2(90, 272), Vector2(64, 266), Vector2(44, 248), Vector2(32, 220),
			Vector2(30, 192), Vector2(36, 168), Vector2(40, 148), Vector2(36, 124), Vector2(28, 98),
			Vector2(28, 70), Vector2(40, 44), Vector2(58, 24)],
		"hills": [Vector4(88, 262, 80, 13)],
		"creeks": [{"zc": 152.0, "amp": 9.0, "freq": 0.05, "phase": 0.0, "half_w": 4.0, "bank": 5.0,
			"drop": 1.6, "depth": 1.2, "pool": 1.4}],
		"meadow": Vector2(84, 76), "lot": Vector2(80, 16),
		"obstacles": [
			["Bump strip", "humps of 5 to 30 cm: clay on the left, rock on the right", Vector2(134, 50), 24.0, 3.5, 1, 10.0, "bumps", {}],
			["Ledges", "steps of 20, 40 and 60 cm onto bare rock, then a ramp down", Vector2(135, 80), 26.0, 3.5, 1, 10.0, "ledges", {}],
			["Creek ford", "the creek at its riffle: knee-deep over stones, a current", Vector2(123, 146), 18.0, 3.0, 0, 0.0, "ford", {}],
			["Hill climb", "a washed-out chute up the hill, steepening to rock: the bypass winds round", Vector2(132, 222), 38.0, 3.2, 1, 12.0, "climb", {}],
			["Flex humps", "humps under one wheel then the other: flex and lockers", Vector2(84, 271), 24.0, 3.5, 1, 10.0, "flex", {}],
			["Side slope", "a sidehill that leans from 5 to 35 deg: where does it tip?", Vector2(38, 236), 28.0, 4.5, -1, 11.0, "tilt", {}],
			["Mud hole", "soup in a hollow under the trees: air down, tread, the winch rock past it", Vector2(30, 194), 26.0, 4.0, 1, 10.0, "mud", {"anchor": true}],
			["Deep crossing", "the creek's deep run, to 1.4 m: the posts mark 0.3 m steps; the ford's beside", Vector2(39, 152), 18.0, 3.0, 1, 11.0, "deep", {}],
			["Rock squeeze", "an off-camber with boulders on the low side: sills and tie rods", Vector2(29, 104), 26.0, 4.0, 1, 10.0, "squeeze", {}],
			["Straddle line", "rocks 0.45, 0.6 and 0.75 m tall on the centre line: belly and skids", Vector2(30, 74), 22.0, 3.0, 1, 9.0, "straddle", {}]],
	},
	{
		"name": "Putikan", "place": "a rice farmer's back field, Morong", "grade": "Medium to hard",
		"teaches": "Mud, the rainy season's: air down, pick the tread, keep the wheels turning, and get yourself out (shovel, boards, winch).",
		"rain": 0.9, "clay": 1.5, "woods": 0.35, "noise": 0.5, "stones": 6, "rock": 0.0,
		"loop": [Vector2(80, 16), Vector2(118, 24), Vector2(138, 50), Vector2(140, 92), Vector2(130, 130),
			Vector2(136, 170), Vector2(140, 212), Vector2(130, 254), Vector2(104, 288), Vector2(70, 296),
			Vector2(38, 280), Vector2(22, 240), Vector2(28, 200), Vector2(24, 160), Vector2(28, 120),
			Vector2(24, 80), Vector2(32, 44), Vector2(52, 22)],
		"hills": [Vector4(80, 160, 40, 1.5)],
		"creeks": [],
		"meadow": Vector2(80, 160), "lot": Vector2(80, 16),
		"obstacles": [
			["Wheel ruts", "two ruts 45 cm deep, wandering: stay in them, or climb out and ride the crown", Vector2(140, 72), 40.0, 3.0, 1, 9.0, "ruts", {"depth": 0.45}],
			["Wallow", "a churned hollow, knee-deep soup: momentum and tread", Vector2(131, 128), 22.0, 4.0, 1, 10.0, "mud", {"depth": 0.5, "soup": 0.7}],
			["Clay bank", "a short wet clay climb, 22 deg: greasy, pick a line and keep the wheels turning", Vector2(139, 192), 26.0, 3.5, 1, 10.0, "mound", {"h": 2.2, "up": 22.0, "down": 15.0}],
			["Long bog", "fifty metres of soup on a soft bottom: air down, don't stop", Vector2(104, 288), 50.0, 4.0, 1, 11.0, "mud", {"depth": 0.3, "soup": 0.6}],
			["Mud hole", "soup in a hollow by the trees: the winch rock is past it", Vector2(22, 240), 26.0, 4.0, 1, 10.0, "mud", {"depth": 0.45, "soup": 0.75, "anchor": true}],
			["V-ditches", "ditches across the trail at an angle: one wheel drops, the other lifts", Vector2(25, 168), 30.0, 3.5, 1, 10.0, "ditches", {"depth": 0.55}],
			["Kanal ruts", "ruts 65 cm deep: lockers, and a winch if you belly out", Vector2(25, 100), 30.0, 3.0, 1, 9.0, "ruts", {"depth": 0.65, "anchor": true}]],
	},
	{
		"name": "Batuhan", "place": "a quarry hillside, Teresa", "grade": "Medium to extreme",
		"teaches": "Rock: pick the line, place each tire, lockers, and what skid plates and sliders are for.",
		"rain": 0.15, "clay": 0.7, "woods": 0.45, "noise": 1.6, "stones": 120, "rock": 0.2,
		"loop": [Vector2(80, 16), Vector2(112, 22), Vector2(134, 42), Vector2(140, 76), Vector2(138, 116),
			Vector2(132, 156), Vector2(138, 196), Vector2(128, 238), Vector2(106, 276), Vector2(74, 290),
			Vector2(44, 274), Vector2(26, 236), Vector2(24, 196), Vector2(30, 156), Vector2(24, 116),
			Vector2(28, 76), Vector2(38, 42), Vector2(56, 22)],
		"hills": [Vector4(80, 175, 95, 10)],
		"creeks": [],
		"meadow": Vector2(80, 60), "lot": Vector2(80, 16),
		"obstacles": [
			["Rubble", "loose broken rock on bare stone: it rolls under the tires", Vector2(140, 66), 30.0, 3.2, 1, 9.0, "boulders", {"n": 45, "r0": 0.14, "r1": 0.32}],
			["Ledges", "steps of 25, 45 and 65 cm onto bare rock", Vector2(139, 112), 26.0, 3.5, 1, 10.0, "ledges", {"steps": [0.25, 0.45, 0.65]}],
			["Boulder garden", "rocks to half a metre all across: find a line and crawl it", Vector2(133, 166), 34.0, 3.5, 1, 10.0, "boulders", {"n": 26, "r0": 0.3, "r1": 0.6}],
			["Slab", "a bare rock slab at 28 deg: dry, it grips; feel it", Vector2(122, 252), 30.0, 3.5, 1, 11.0, "mound", {"h": 4.0, "up": 28.0, "down": 18.0, "rock": true}],
			["Stair climb", "ledges of 50, 80 cm and a metre: lockers, a spotter and the winch rock above", Vector2(46, 276), 26.0, 3.5, 1, 11.0, "ledges", {"steps": [0.5, 0.8, 1.0], "anchor": true}],
			["Rock squeeze", "an off-camber with boulders on the low side: sills and tie rods", Vector2(24, 200), 26.0, 4.0, 1, 10.0, "squeeze", {}],
			["Straddle line", "rocks 0.45, 0.6 and 0.75 m tall on the centre line: belly and skids", Vector2(27, 132), 22.0, 3.0, 1, 9.0, "straddle", {}]],
	},
	{
		"name": "Ahon at Lusong", "place": "a laterite borrow pit, Baras", "grade": "Easy to extreme",
		"teaches": "Slopes: low range, momentum up, engine braking down, and where the inclinometers say you'll tip.",
		"rain": 0.3, "clay": 0.7, "woods": 0.5, "noise": 1.0, "stones": 20, "rock": 0.0,
		"loop": [Vector2(80, 16), Vector2(114, 22), Vector2(136, 46), Vector2(142, 86), Vector2(140, 126),
			Vector2(132, 166), Vector2(136, 206), Vector2(124, 246), Vector2(100, 280), Vector2(70, 292),
			Vector2(42, 278), Vector2(26, 240), Vector2(22, 196), Vector2(26, 156), Vector2(22, 116),
			Vector2(26, 76), Vector2(36, 42), Vector2(56, 22)],
		"hills": [Vector4(82, 180, 75, 16)],
		"creeks": [],
		"meadow": Vector2(80, 60), "lot": Vector2(80, 16),
		"obstacles": [
			["20 deg climb", "a built mound, 20 deg up: the easy one", Vector2(141, 70), 26.0, 3.5, 1, 11.0, "mound", {"h": 2.5, "up": 20.0, "down": 14.0}],
			["30 deg climb", "30 deg up: low range, steady throttle", Vector2(141, 118), 26.0, 3.5, 1, 11.0, "mound", {"h": 3.5, "up": 30.0, "down": 18.0}],
			["40 deg climb", "40 deg up: tread, pressure, momentum, and the pitch gauge", Vector2(133, 176), 28.0, 3.5, 1, 12.0, "mound", {"h": 4.5, "up": 40.0, "down": 20.0}],
			["Whoops", "rolling humps 70 cm high, one after another: pitch, and a gentle throttle", Vector2(116, 262), 34.0, 3.5, 1, 10.0, "whoops", {"h": 0.7, "gap": 6.0}],
			["Steep descent", "a gentle way up and 35 deg down: first gear low range, off the brakes", Vector2(44, 279), 30.0, 3.5, 1, 12.0, "mound", {"h": 5.0, "up": 14.0, "down": 35.0}],
			["Side slope", "a sidehill that leans from 5 to 35 deg: where does it tip?", Vector2(23, 208), 28.0, 4.5, -1, 11.0, "tilt", {}],
			["45 deg wall", "a short wall at 45 deg: most rigs need the winch", Vector2(24, 120), 22.0, 3.5, 1, 11.0, "mound", {"h": 3.0, "up": 45.0, "down": 25.0, "anchor": true}]],
	},
	{
		"name": "Kanal", "place": "an old logging road, Tanay", "grade": "Medium to hard",
		"teaches": "Ruts and ditches: flex, lockers, when to ride the ruts and when to climb out of them.",
		"rain": 0.6, "clay": 1.2, "woods": 0.8, "noise": 1.0, "stones": 15, "rock": 0.0,
		"loop": [Vector2(80, 16), Vector2(112, 22), Vector2(134, 42), Vector2(140, 76), Vector2(138, 116),
			Vector2(132, 156), Vector2(138, 196), Vector2(128, 238), Vector2(106, 276), Vector2(74, 290),
			Vector2(44, 274), Vector2(26, 236), Vector2(24, 196), Vector2(30, 156), Vector2(24, 116),
			Vector2(28, 76), Vector2(38, 42), Vector2(56, 22)],
		"hills": [Vector4(80, 200, 70, 6)],
		"creeks": [],
		"meadow": Vector2(80, 60), "lot": Vector2(80, 16),
		"obstacles": [
			["Twin ruts", "two ruts 40 cm deep for fifty metres: ride them, or straddle the crown", Vector2(140, 70), 44.0, 3.0, 1, 9.0, "ruts", {"depth": 0.4}],
			["Washout", "a gully a metre deep cut across the trail: nose in, climb out", Vector2(139, 116), 16.0, 3.5, 1, 10.0, "trench", {"depth": 1.0, "width": 4.6}],
			["Cross-axle ditches", "ditches at 45 deg, 65 cm: two wheels in the air at once", Vector2(133, 166), 34.0, 3.5, 1, 10.0, "ditches", {"depth": 0.65}],
			["Rain dips", "dips across the trail where the water runs off, 80 cm, one after another", Vector2(118, 258), 36.0, 3.5, 1, 10.0, "whoops", {"h": 0.8, "gap": 8.0, "dip": true}],
			["Flex humps", "humps under one wheel then the other: flex and lockers", Vector2(46, 276), 24.0, 3.5, 1, 10.0, "flex", {}],
			["Off-camber ruts", "ruts across a sidehill: the low wheels drop in and the rig leans", Vector2(24, 200), 30.0, 4.0, -1, 11.0, "ruts", {"depth": 0.45, "camber": 12.0}],
			["Kanal", "ruts 70 cm deep: lockers, and the winch if you belly out", Vector2(27, 132), 34.0, 3.0, 1, 9.0, "ruts", {"depth": 0.7, "anchor": true}]],
	},
	{
		"name": "Ilog", "place": "a river valley, Daraitan, Tanay", "grade": "Easy to hard",
		"teaches": "Water: read the creek, find the riffle, know your wading depth, and a narrow bridge if you'd rather stay dry.",
		"rain": 0.5, "clay": 0.9, "woods": 0.8, "noise": 1.0, "stones": 30, "rock": 0.0,
		"loop": [Vector2(80, 16), Vector2(112, 22), Vector2(134, 42), Vector2(140, 76), Vector2(138, 116),
			Vector2(136, 160), Vector2(138, 200), Vector2(136, 244), Vector2(122, 276), Vector2(96, 292),
			Vector2(64, 292), Vector2(38, 278), Vector2(26, 244), Vector2(24, 200), Vector2(26, 160),
			Vector2(24, 118), Vector2(26, 74), Vector2(38, 42), Vector2(56, 22)],
		"hills": [],
		"creeks": [
			{"zc": 70.0, "amp": 4.0, "freq": 0.04, "phase": 0.5, "half_w": 3.5, "bank": 4.0, "drop": 1.4, "depth": 1.0, "pool": 1.0},
			{"zc": 160.0, "amp": 5.0, "freq": 0.035, "phase": 2.0, "half_w": 5.0, "bank": 5.0, "drop": 1.8, "depth": 1.3, "pool": 1.5, "flow": 0.9},
			{"zc": 248.0, "amp": 4.0, "freq": 0.045, "phase": 4.0, "half_w": 3.0, "bank": 4.0, "drop": 1.3, "depth": 0.9, "pool": 0.9}],
		"meadow": Vector2(80, 115), "lot": Vector2(80, 16),
		"obstacles": [
			["Riffle", "the first creek at its riffle: shin-deep over stones", Vector2(138, 69), 16.0, 3.0, 0, 0.0, "ford", {"shallow": 0.3}],
			["Tulay", "a timber bridge a hand wider than the tires, the river under it: or ford beside it", Vector2(136, 162), 20.0, 3.0, 1, 13.0, "bridge", {}],
			["Boulder ford", "a ford over river boulders: pick a line, the current pushing", Vector2(137, 245), 16.0, 3.0, 0, 0.0, "rockford", {"shallow": 0.4}],
			["Deep pool", "the third creek's pool, a metre deep: snorkel, or the riffle beside", Vector2(26, 244), 16.0, 3.0, 1, 11.0, "deep", {}],
			["Wide ford", "the river ten metres across, knee-deep, a current on the bonnet", Vector2(25, 161), 20.0, 3.0, 0, 0.0, "ford", {"shallow": 0.5}],
			["Ford", "the first creek again, shallow", Vector2(25, 74), 16.0, 3.0, 0, 0.0, "ford", {"shallow": 0.35}],
			["Exit bank", "a muddy climb out of the creek bed: wet tires on wet clay", Vector2(27, 52), 16.0, 3.5, 1, 9.0, "mound", {"h": 1.8, "up": 24.0, "down": 12.0}]],
	},
	{
		"name": "Lahar", "place": "a lahar wash, Porac, Pampanga", "grade": "Medium to hard",
		"teaches": "Ash and sand: flotation, air down to 15 or below, keep it rolling, and never stop in the soft stuff.",
		"rain": 0.4, "clay": 0.6, "woods": 0.25, "noise": 1.4, "stones": 50, "rock": 0.0, "ash": 1.0, "edge": 9.0,
		"loop": [Vector2(80, 16), Vector2(112, 22), Vector2(134, 42), Vector2(140, 76), Vector2(138, 116),
			Vector2(132, 156), Vector2(138, 196), Vector2(128, 238), Vector2(106, 276), Vector2(74, 290),
			Vector2(44, 274), Vector2(26, 236), Vector2(24, 196), Vector2(30, 156), Vector2(24, 116),
			Vector2(28, 76), Vector2(38, 42), Vector2(56, 22)],
		"hills": [],
		"creeks": [
			{"zc": 110.0, "amp": 10.0, "freq": 0.03, "phase": 1.0, "half_w": 6.0, "bank": 6.0, "drop": 0.8, "depth": 0.35, "pool": 0.35,
				"braided": true, "tint": Color(0.52, 0.5, 0.45, 0.8), "clarity": 0.35, "flow": 0.7},
			{"zc": 220.0, "amp": 10.0, "freq": 0.03, "phase": 3.0, "half_w": 6.0, "bank": 6.0, "drop": 0.8, "depth": 0.35, "pool": 0.35,
				"braided": true, "tint": Color(0.52, 0.5, 0.45, 0.8), "clarity": 0.35, "flow": 0.7}],
		"meadow": Vector2(80, 165), "lot": Vector2(80, 16),
		"obstacles": [
			["Soft sand", "loose ash half a metre deep: air down to 15, keep it rolling", Vector2(140, 66), 40.0, 4.0, 1, 10.0, "sand", {"depth": 0.5}],
			["Braided stream", "shallow grey water threading between sand bars", Vector2(139, 101), 20.0, 3.0, 0, 0.0, "ford", {}],
			["Ash dunes", "wind-heaped ash, humps a metre high: momentum, not speed", Vector2(133, 166), 36.0, 4.0, 1, 11.0, "whoops", {"h": 1.0, "gap": 9.0, "sand": true}],
			["Boulder cascade", "a dry fall of stones where the wash steps down", Vector2(118, 258), 26.0, 3.5, 1, 11.0, "boulders", {"n": 30, "r0": 0.25, "r1": 0.55}],
			["Slot canyon", "the ash walls close in to a slot barely wider than the rig", Vector2(46, 276), 40.0, 2.6, 0, 0.0, "slot", {"h": 5.0}],
			["Second stream", "the other stream, braided wide", Vector2(25, 214), 20.0, 3.0, 0, 0.0, "ford", {}],
			["Ash bog", "ash soaked by the stream: it sets round a stuck tire like wet cement", Vector2(27, 150), 26.0, 4.0, 1, 10.0, "mud", {"depth": 0.35, "soup": 0.7, "anchor": true}]],
	},
	{
		"name": "Sukal", "place": "an overgrown logging trail, Real, Quezon", "grade": "Medium to hard",
		"teaches": "Tight trail under the trees: precision, three-point turns, logs, and the winch when the bank's too steep.",
		"rain": 0.6, "clay": 0.9, "woods": 1.0, "noise": 1.3, "stones": 20, "rock": 0.0, "clear": 2.6, "overgrown": true,
		"loop": [Vector2(80, 16), Vector2(112, 22), Vector2(134, 42), Vector2(140, 80), Vector2(136, 120),
			Vector2(140, 160), Vector2(134, 200), Vector2(138, 240), Vector2(122, 276), Vector2(96, 292),
			Vector2(66, 292), Vector2(42, 280), Vector2(30, 258), Vector2(54, 242), Vector2(30, 226),
			Vector2(54, 210), Vector2(30, 194), Vector2(30, 150), Vector2(24, 110), Vector2(28, 74),
			Vector2(38, 42), Vector2(56, 22)],
		"hills": [Vector4(80, 170, 80, 8)],
		"creeks": [],
		"meadow": Vector2(80, 60), "lot": Vector2(80, 16),
		"obstacles": [
			["Tree squeeze", "trunks either side, a hand's width past the mirrors", Vector2(140, 72), 24.0, 3.0, 1, 9.0, "trees", {"gap": 2.5}],
			["Logs", "trunks fallen across the trail, 30 to 45 cm: take them square and slow", Vector2(137, 128), 26.0, 3.0, 1, 9.0, "logs", {}],
			["Winch wall", "a clay bank too steep to drive: winch to the tree at the top", Vector2(135, 200), 20.0, 3.5, 1, 11.0, "mound", {"h": 2.5, "up": 55.0, "down": 20.0, "anchor": true}],
			["Overgrown", "the trail narrows under tall grass, a rut or two hidden in it", Vector2(118, 280), 40.0, 3.0, 0, 0.0, "ruts", {"depth": 0.3}],
			["Switchbacks", "hairpins down the hillside: turn tight, or three-point it", Vector2(42, 226), 80.0, 3.0, 0, 0.0, "none", {}],
			["Mud hole", "soup under the trees, the winch rock past it", Vector2(28, 150), 24.0, 4.0, 1, 10.0, "mud", {"depth": 0.45, "soup": 0.7, "anchor": true}],
			["Narrow gap", "two trees closer still: fold the mirrors", Vector2(26, 95), 18.0, 3.0, 1, 9.0, "trees", {"gap": 2.3}]],
	},
]

## obstacles that are a crossing of a creek (they sit where the loop crosses it)
const WATER_KINDS := ["ford", "rockford", "deep", "bridge"]

static var _track := 0
static var _built := false
static var _noise: FastNoiseLite
## paths: {pts, h (smoothed floor), loop, box, grid, gx0, gz0, gw, gh}
static var _tracks: Array[Dictionary] = []
## obstacles: {name, what, kind, p (its numbers), sc (centre, along the loop),
## len, w, side, off, up, h0, h1, track}
static var _obs: Array[Dictionary] = []
static var _stations: Array[Dictionary] = []


## Lay out track `i` (an index into TRACKS) for everything that asks after this.
static func use(i: int) -> void:
	i = clampi(i, 0, TRACKS.size() - 1)
	if _built and i == _track:
		return
	_track = i
	_built = false
	_tracks.clear()
	_obs.clear()
	_stations.clear()


static func current() -> int:
	return _track


static func info() -> Dictionary:
	return TRACKS[_track]


static func creeks() -> Array:
	return TRACKS[_track]["creeks"]


## How the track's ground looks: 1 grey lahar ash and sand, 0 red clay and grass.
static func ash(x: float, z: float) -> float:
	var a := float(TRACKS[_track].get("ash", 0.0))
	if a <= 0.0:
		return 0.0
	return a * (1.0 - forest(x, z))


static func meadow() -> Vector2:
	return TRACKS[_track]["meadow"]


# --- building the layout ------------------------------------------------------------

static func _setup() -> void:
	if _built:
		return
	_built = true
	_noise = FastNoiseLite.new()
	_noise.seed = 4242 + _track * 101
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.02
	_noise.fractal_octaves = 3
	var t: Dictionary = TRACKS[_track]
	_tracks.append(_make_track(_spline(t["loop"]), true))
	var main: Dictionary = _tracks[0]
	for o: Array in t["obstacles"]:
		var near: Vector2 = o[2]
		var sc := _local(main, near.x, near.y).x
		var ci := -1
		if o[7] in WATER_KINDS:
			# centred on where the loop actually crosses the nearest creek
			ci = _nearest_creek(near.x, near.y)
			if ci >= 0:
				sc = _crossing_s(main, ci, sc - 20.0, sc + 20.0)
		var half := float(o[3]) * 0.5
		var ob := {"name": o[0], "what": o[1], "sc": sc, "len": float(o[3]), "w": float(o[4]),
			"side": int(o[5]), "off": float(o[6]), "kind": o[7], "p": o[8], "track": -1, "creek": ci,
			"h0": _prof(main, sc - half), "h1": _prof(main, sc + half)}
		# which way the natural ground rises across the trail here (+1: to the left)
		var p := _at(main, sc)
		var nrm := _normal(main, sc)
		ob["up"] = 1.0 if _land(p.x + nrm.x * 6.0, p.y + nrm.y * 6.0) >= _land(p.x - nrm.x * 6.0, p.y - nrm.y * 6.0) else -1.0
		if int(o[5]) != 0:
			# the bypass: leaves the trail 16 m before, runs alongside, rejoins after
			var pts := PackedVector2Array()
			var s := sc - half - 16.0
			while s <= sc + half + 16.0:
				var u := s - (sc - half)
				var k := smoothstep(-16.0, -4.0, u) * (1.0 - smoothstep(float(o[3]) + 4.0, float(o[3]) + 16.0, u))
				pts.append(_at(main, s) + _normal(main, s) * float(o[5]) * float(o[6]) * k)
				s += 1.0
			_tracks.append(_make_track(pts, false))
			ob["track"] = _tracks.size() - 1
		_obs.append(ob)


## A closed Catmull-Rom spline through `ctrl`, resampled every metre.
static func _spline(ctrl: Array) -> PackedVector2Array:
	var dense := PackedVector2Array()
	var m := ctrl.size()
	for i in range(m):
		var p0: Vector2 = ctrl[(i - 1 + m) % m]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[(i + 1) % m]
		var p3: Vector2 = ctrl[(i + 2) % m]
		for k in range(40):
			var t := k / 40.0
			dense.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	dense.append(dense[0])
	var out := PackedVector2Array([dense[0]])
	var carry := 0.0
	for i in range(1, dense.size()):
		var a := dense[i - 1]
		var seg := a.distance_to(dense[i])
		var at := 1.0 - carry
		while at <= seg:
			out.append(a.lerp(dense[i], at / seg))
			at += 1.0
		carry = seg - (at - 1.0)
	if out[out.size() - 1].distance_to(out[0]) < 0.5:
		out.remove_at(out.size() - 1)
	return out


static func _make_track(pts: PackedVector2Array, loop: bool) -> Dictionary:
	var n := pts.size()
	# the tread follows the land, smoothed along it: benched into side slopes,
	# a gentle grade where the ground is lumpy
	var h := PackedFloat32Array()
	h.resize(n)
	for i in range(n):
		h[i] = _land(pts[i].x, pts[i].y)
	for pass_i in range(3):
		var sm := PackedFloat32Array()
		sm.resize(n)
		for i in range(n):
			var sum := 0.0
			var c := 0
			for j in range(i - 6, i + 7):
				var jj := posmod(j, n) if loop else clampi(j, 0, n - 1)
				sum += h[jj]
				c += 1
			sm[i] = sum / c
		h = sm
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	var gx0 := int(floor(lo.x - REACH))
	var gz0 := int(floor(lo.y - REACH))
	var gw := int(ceil(hi.x + REACH)) - gx0 + 1
	var gh := int(ceil(hi.y + REACH)) - gz0 + 1
	var grid := PackedInt32Array()
	grid.resize(gw * gh)
	grid.fill(-1)
	var best := PackedFloat32Array()
	best.resize(gw * gh)
	best.fill(REACH * REACH)
	var r := int(REACH)
	for i in range(n):
		var cx := int(floor(pts[i].x)) - gx0
		var cz := int(floor(pts[i].y)) - gz0
		for dz in range(-r, r + 1):
			var z := cz + dz
			if z < 0 or z >= gh:
				continue
			for dx in range(-r, r + 1):
				var x := cx + dx
				if x < 0 or x >= gw:
					continue
				var d2 := Vector2(x + gx0 + 0.5, z + gz0 + 0.5).distance_squared_to(pts[i])
				var k := z * gw + x
				if d2 < best[k]:
					best[k] = d2
					grid[k] = i
	return {"pts": pts, "h": h, "loop": loop, "grid": grid, "gx0": gx0, "gz0": gz0, "gw": gw, "gh": gh,
		"box": Rect2(lo, hi - lo).grow(REACH)}


# --- path lookups --------------------------------------------------------------------

## (along in metres, across: + to the left, distance) of (x, z) from path
## `t`; distance INF when it's out of the path's reach.
static func _local(t: Dictionary, x: float, z: float) -> Vector3:
	var gx := int(floor(x)) - int(t["gx0"])
	var gz := int(floor(z)) - int(t["gz0"])
	var gw: int = t["gw"]
	if gx < 0 or gz < 0 or gx >= gw or gz >= int(t["gh"]):
		return Vector3(0.0, 0.0, INF)
	var i: int = (t["grid"] as PackedInt32Array)[gz * gw + gx]
	if i < 0:
		return Vector3(0.0, 0.0, INF)
	var pts: PackedVector2Array = t["pts"]
	var n := pts.size()
	var loop: bool = t["loop"]
	var p := Vector2(x, z)
	var best := Vector3(0.0, 0.0, INF)
	for j in [i - 1, i]:
		var ia: int = j
		var ib: int = j + 1
		if loop:
			ia = posmod(ia, n)
			ib = posmod(ib, n)
		elif ia < 0 or ib >= n:
			continue
		var a := pts[ia]
		var ab := pts[ib] - a
		var tt := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var q := a + ab * tt
		var d := p.distance_to(q)
		if d < best.z:
			var tn := ab.normalized()
			best = Vector3(float(j) + tt, (p - q).dot(Vector2(-tn.y, tn.x)), d)
	return best


static func _wrap_s(t: Dictionary, s: float) -> float:
	var n := float((t["pts"] as PackedVector2Array).size())
	return fposmod(s, n) if t["loop"] else clampf(s, 0.0, n - 1.001)


static func _at(t: Dictionary, s: float) -> Vector2:
	var pts: PackedVector2Array = t["pts"]
	var n := pts.size()
	s = _wrap_s(t, s)
	var i := int(s)
	return pts[i].lerp(pts[(i + 1) % n], s - i)


static func _tangent(t: Dictionary, s: float) -> Vector2:
	return (_at(t, s + 1.0) - _at(t, s - 1.0)).normalized()


## The left-hand normal: inside the loop.
static func _normal(t: Dictionary, s: float) -> Vector2:
	var tn := _tangent(t, s)
	return Vector2(-tn.y, tn.x)


static func _prof(t: Dictionary, s: float) -> float:
	var h: PackedFloat32Array = t["h"]
	var n := h.size()
	s = _wrap_s(t, s)
	var i := int(s)
	return lerpf(h[i], h[(i + 1) % n], s - i)


## Metres into obstacle `o`'s lane from its start, for a point `s` along the loop.
static func _along(o: Dictionary, s: float) -> float:
	var n := float((_tracks[0]["pts"] as PackedVector2Array).size())
	return wrapf(s - float(o["sc"]), -n * 0.5, n * 0.5) + float(o["len"]) * 0.5


## Distance to the nearest path (loop or bypass), and which.
static func _nearest(x: float, z: float) -> Vector2:
	var best := Vector2(INF, -1)
	for ti in _tracks.size():
		var t: Dictionary = _tracks[ti]
		if not (t["box"] as Rect2).has_point(Vector2(x, z)):
			continue
		var d := _local(t, x, z).z
		if d < best.x:
			best = Vector2(d, ti)
	return best


## A smooth minimum: like minf, the corner rounded over about `k`.
static func _smin(a: float, b: float, k: float) -> float:
	var hh := clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, hh) - k * hh * (1.0 - hh)


static func _num(o: Dictionary, key: String, def: float) -> float:
	return float((o["p"] as Dictionary).get(key, def))


# --- the land -----------------------------------------------------------------------

## Where creek `ci` runs at `x` (its middle, in z).
static func creek_mid(ci: int, x: float) -> float:
	var c: Dictionary = creeks()[ci]
	return float(c["zc"]) + float(c["amp"]) * sin(x * float(c["freq"]) + float(c["phase"]))


## How far (x, z) is from the middle of the nearest creek (INF with none).
static func _creek_d(x: float, z: float) -> float:
	var d := INF
	for ci in creeks().size():
		d = minf(d, absf(z - creek_mid(ci, x)))
	return d


static func _nearest_creek(x: float, z: float) -> int:
	var best := -1
	var bd := INF
	for ci in creeks().size():
		var d := absf(z - creek_mid(ci, x))
		if d < bd:
			bd = d
			best = ci
	return best


## The natural ground, before the trail is cut into it.
static func _land(x: float, z: float) -> float:
	var t: Dictionary = TRACKS[_track]
	var near_creek := smoothstep(8.0, 30.0, _creek_d(x, z))
	var h := float(t["noise"]) * _noise.get_noise_2d(x, z) * near_creek
	for hl: Vector4 in t["hills"]:
		var d := Vector2(x, z).distance_to(Vector2(hl.x, hl.y)) / hl.z
		if d < 1.0:
			h += hl.w * (1.0 - smoothstep(0.0, 1.0, d))
	# a bank all round, so the park is a park, not the edge of the world (a
	# lahar wash's are its grey cliffs)
	var edge := minf(minf(x, SIZE - x), minf(z, LENGTH - z))
	h += float(t.get("edge", 4.0)) * (1.0 - smoothstep(0.0, 10.0, edge))
	return h


## The ground height anywhere in the park (before soft ground goes on top;
## Terrain cuts the creek in after).
static func height(x: float, z: float, _n: FastNoiseLite = null) -> float:
	_setup()
	var land := _land(x, z)
	var wsum := 0.0
	var hsum := 0.0
	var wmax := 0.0
	var lm := Vector3(0.0, 0.0, INF)
	for ti in _tracks.size():
		var t: Dictionary = _tracks[ti]
		if not (t["box"] as Rect2).has_point(Vector2(x, z)):
			continue
		var l := _local(t, x, z)
		if ti == 0:
			lm = l
		if l.z > HALF + BANK:
			continue
		var w := 1.0 - smoothstep(HALF, HALF + BANK, l.z)
		wsum += w
		hsum += w * _prof(t, l.x)
		wmax = maxf(wmax, w)
	var h := land
	if wsum > 0.0:
		h = lerpf(land, hsum / wsum, wmax)
		# nothing on a real trail is flat: humps and wallows in the tread
		h += 0.06 * _noise.get_noise_2d(x * 9.0, z * 9.0) * wmax
	if lm.z < 12.0:
		h += _obstacle_height(lm)
	return h


static func _obstacle_height(l: Vector3) -> float:
	var h := 0.0
	for o in _obs:
		var u := _along(o, l.x)
		var L: float = o["len"]
		if u < -6.0 or u > L + 6.0:
			continue
		var w: float = o["w"]
		var lat := l.y
		var lane := 1.0 - smoothstep(w - 1.5, w, absf(lat))
		match o["kind"]:
			"bumps":
				# rounded humps across the lane
				for b: Vector2 in [Vector2(3, 0.05), Vector2(7, 0.1), Vector2(11, 0.15), Vector2(15, 0.2), Vector2(20, 0.3)]:
					var d := absf(u - b.x)
					if d < 0.6:
						h += b.y * 0.5 * (1.0 + cos(PI * d / 0.6)) * lane
			"ledges":
				# steps up (each its own height), benches between, then a ramp back down
				# (each step its own height: 20, 40, 60 cm is 1.2 m up in all)
				var steps: Array = (o["p"] as Dictionary).get("steps", [0.2, 0.4, 0.6])
				var gap := (L - 12.0) / steps.size()
				var rise := 0.0
				for k in steps.size():
					rise += float(steps[k]) * smoothstep(5.0 + gap * k - 0.06, 5.0 + gap * k + 0.06, u)
				rise *= 1.0 - smoothstep(L - 6.0, L, u)
				h += rise * lane
			"climb":
				# a chute washed into the hill: it holds low, then takes the whole
				# rise at once (the bypass beside it climbs the hill's own grade)
				var f := smoothstep(0.68, 1.0, clampf(u / L, 0.0, 1.0))
				var chute := lerpf(float(o["h0"]), float(o["h1"]), f)
				var fade := smoothstep(-6.0, 0.0, u) * (1.0 - smoothstep(L, L + 6.0, u))
				h += (chute - _prof(_tracks[0], l.x)) * fade * (1.0 - smoothstep(w - 0.5, w + 2.5, absf(lat)))
			"mound":
				# a built mound of laterite fill: up one face, over a short top,
				# down the other; steep-sided, the bypass goes round
				var top := _num(o, "h", 3.0)
				var up := tan(deg_to_rad(_num(o, "up", 25.0)))
				var down := tan(deg_to_rad(_num(o, "down", 20.0)))
				# (the crest rounded over a metre or so, as fill settles: a knife
				# edge would launch or high-centre every rig)
				var m := _smin(top, _smin(up * (u - 1.0), down * (L - 1.0 - u), 1.2), 0.8)
				if m > 0.0:
					h += m * (1.0 - smoothstep(w - 0.3, w + maxf(1.5, top * 0.7), absf(lat)))
			"whoops":
				# rolling humps one after another: they pitch the rig fore and aft
				var hh := _num(o, "h", 0.6)
				var gap := _num(o, "gap", 6.0)
				if u > 2.0 and u < L - 2.0:
					var bump := hh * 0.5 * (1.0 - cos(TAU * (u - 2.0) / gap)) * lane
					# (or dips: where the water runs off across the trail)
					h += -bump if (o["p"] as Dictionary).get("dip", false) else bump
			"trench":
				# a gully cut across the trail: steep sides, a rounded bottom
				var d := absf(u - L * 0.5) / (_num(o, "width", 3.5) * 0.5)
				if d < 1.0:
					h -= _num(o, "depth", 1.0) * (1.0 - pow(d, 3.0)) * (1.0 - smoothstep(w, w + 3.0, absf(lat)))
			"slot":
				# the wash's walls closing in to a slot just wider than a rig
				var fade := smoothstep(-6.0, 4.0, u) * (1.0 - smoothstep(L - 4.0, L + 6.0, u))
				var wall := smoothstep(w - 0.2, w + 0.9, absf(lat)) * (1.0 - smoothstep(8.0, 11.5, absf(lat)))
				h += _num(o, "h", 5.0) * wall * fade
			"flex":
				var k := 0
				var zk := 3.0
				while zk < L - 3.0:
					var side := 0.85 if k % 2 == 0 else -0.85
					var d := Vector2(u - zk, lat - side).length() / 1.5
					if d < 1.0:
						h += 0.5 * (0.5 + 0.5 * cos(PI * d))
					zk += 2.6
					k += 1
			"tilt":
				# a sidehill that leans more and more, the high side the hill's
				var a := deg_to_rad(lerpf(5.0, 35.0, clampf((u - 2.0) / (L - 8.0), 0.0, 1.0)))
				var fade := smoothstep(-4.0, 0.0, u) * (1.0 - smoothstep(L, L + 5.0, u))
				h += tan(a) * lat * float(o["up"]) * fade * (1.0 - smoothstep(w - 1.0, w + 2.0, absf(lat)))
			"squeeze":
				var fade := smoothstep(-3.0, 1.0, u) * (1.0 - smoothstep(L - 1.0, L + 3.0, u))
				h += tan(deg_to_rad(14.0)) * lat * float(o["up"]) * fade * (1.0 - smoothstep(w - 1.0, w + 2.0, absf(lat)))
			"mud":
				# a dished hollow where every rig has dug
				var e := pow((u - L * 0.5) / (L * 0.5), 2.0) + pow(lat / w, 2.0)
				if e < 1.0:
					h -= _num(o, "depth", 0.4) * (1.0 - e)
			"ruts":
				# two trenches where every rig's wheels have gone, wandering a
				# little so they pull you off line; churned clay between
				var off := 0.3 * sin(u * 0.18 + float(o["sc"]))
				var d := minf(absf(lat - off - 0.82), absf(lat - off + 0.82))
				var fade := smoothstep(-2.0, 2.0, u) * (1.0 - smoothstep(L - 2.0, L + 2.0, u))
				var deep := _num(o, "depth", 0.45) * (0.8 + 0.2 * sin(u * 0.4))
				h -= deep * 0.5 * (1.0 + cos(PI * minf(d / 0.55, 1.0))) * fade
				# ruts across a sidehill: the trail leans, high side the hill's
				var camber := _num(o, "camber", 0.0)
				if camber > 0.0:
					h += tan(deg_to_rad(camber)) * lat * float(o["up"]) * fade * (1.0 - smoothstep(w - 1.0, w + 2.0, absf(lat)))
			"ditches":
				# ditches dug across the trail at 45 deg, alternating: one front
				# wheel drops while the other's still up, then the rear, then the
				# other way round
				var k := 0
				var at := 4.0
				while at < L - 4.0:
					var dir := 1.0 if k % 2 == 0 else -1.0
					var d := absf((u - at) - dir * lat)
					if d < 1.1 and absf(lat) < w:
						h -= _num(o, "depth", 0.5) * 0.5 * (1.0 + cos(PI * d / 1.1)) * lane
					at += 6.5
					k += 1
	return h


## Soft ground: Vector4(mud thickness, wetness, rut, grip), as Terrain wants it.
static func soil(x: float, z: float, patchy: float) -> Vector4:
	_setup()
	var t: Dictionary = TRACKS[_track]
	var clay_k: float = t["clay"]
	var f := forest(x, z)
	# the meadow: short grass on firm, thin soil; leaf litter and loam in the woods
	var m := Vector4(0.02, 0.2, 0.0, 1.0).lerp(Vector4(0.02, 0.38, 0.0, 1.0), f)
	var near := _nearest(x, z)
	if near.y >= 0.0 and near.x < HALF + 0.6:
		var pt: Dictionary = _tracks[int(near.y)]
		var l := _local(pt, x, z)
		var on := 1.0 - smoothstep(HALF - 0.5, HALF + 0.6, l.z)
		# the two-track's clay, churned in the wheel lines; on a climb the water
		# runs off and it's firmer, grittier clay
		var grade := absf(_prof(pt, l.x + 1.5) - _prof(pt, l.x - 1.5)) / 3.0
		var steep := smoothstep(0.08, 0.25, grade)
		var lines := exp(-pow((absf(l.y) - 0.8) / 0.3, 2.0))
		var thick := (0.08 + 0.14 * patchy + 0.06 * lines) * (1.0 - 0.6 * steep) * clay_k
		thick = maxf(thick, 0.07)   # (worn to dirt whatever: a track, not a lawn)
		var clay := Vector4(thick, minf(1.0, (0.35 + 0.2 * patchy + 0.15 * lines) * (1.0 - 0.4 * steep) * lerpf(1.0, 1.3, clay_k - 1.0)),
			minf(thick, 0.06 * lines * clay_k), 1.0 + 0.2 * steep)
		m = m.lerp(clay, on)
	# a lahar wash: loose grey ash and sand all across the floor, packed
	# thinner where the trail runs (Terrain's lahar numbers)
	var a := ash(x, z)
	if a > 0.0:
		var packed := 1.0 - smoothstep(1.5, 3.0, near.x)
		var sand := Vector4((0.22 + 0.3 * patchy) * (1.0 - 0.5 * packed), 0.1 + 0.15 * patchy, 0.0, 0.8)
		m = m.lerp(sand, a)
	# the trailhead: packed dirt and gravel
	var lot := 1.0 - smoothstep(10.0, 14.0, Vector2(x, z).distance_to(t["lot"]))
	m = m.lerp(Vector4(0.04, 0.15, 0.0, 1.0), lot)
	var lm := _local(_tracks[0], x, z)
	if lm.z < 12.0:
		for o in _obs:
			var u := _along(o, lm.x)
			var L: float = o["len"]
			if u < -8.0 or u > L + 8.0:
				continue
			var w: float = o["w"]
			match o["kind"]:
				"mud":
					var e := pow((u - L * 0.5) / (L * 0.5 + 3.0), 2.0) + pow(lm.y / (w + 1.0), 2.0)
					if e < 1.0:
						# soup in the middle whatever the season, firmer at the rim
						var k := 1.0 - e
						var soup := _num(o, "soup", 0.62)
						m = Vector4(maxf(m.x, 0.05 + soup * k * (0.85 + 0.3 * patchy)), maxf(m.y, minf(1.0, 0.55 + 0.8 * k)), 0.0, 1.0)
				"ruts", "ditches", "trench":
					# churned and wet in the bottoms, where the water sits
					if u > -2.0 and u < L + 2.0 and absf(lm.y) < w:
						m = Vector4(maxf(m.x, 0.22 + 0.15 * patchy), maxf(m.y, 0.8), minf(maxf(m.x, 0.22), 0.05), 1.0)
				"sand":
					# deep loose ash: it floats an aired-down tire, swallows a hard one
					var e := pow((u - L * 0.5) / (L * 0.5 + 2.0), 2.0) + pow(lm.y / (w + 1.5), 2.0)
					if e < 1.0:
						m = Vector4(maxf(m.x, _num(o, "depth", 0.5) * (0.8 + 0.4 * patchy) * (1.0 - e * e)), 0.12, 0.0, 0.75)
				"mound":
					if (o["p"] as Dictionary).get("rock", false) and u > 0.0 and u < L and absf(lm.y) < w:
						m = Vector4(0.0, 0.1, 0.0, 1.1)
	if bedrock(x, z) > 0.5:
		m = Vector4(0.0, 0.1, 0.0, 1.1)     # bare rock: counts as rock for grip and damage
	return m


## Where the ground is bare rock (the shader's bedrock, and grip).
static func bedrock(x: float, z: float) -> float:
	_setup()
	var t: Dictionary = TRACKS[_track]
	var l := _local(_tracks[0], x, z)
	if l.z < 8.0:
		for o in _obs:
			var u := _along(o, l.x)
			var L: float = o["len"]
			var w: float = o["w"]
			if u < -2.0 or u > L + 2.0 or absf(l.y) > w:
				continue
			match o["kind"]:
				"bumps":
					if l.y < -0.2 and u > 0.0 and u < L:
						return 1.0   # the rock half
				"ledges":
					if u > 3.0 and u < L - 5.0:
						return 1.0
				"climb":
					if u > L * 0.72 and u < L + 0.5:
						return 0.9   # the chute's washed down to rock where it's steepest
				"squeeze", "boulders":
					return 0.8
				"mound":
					if (o["p"] as Dictionary).get("rock", false) and u > 0.0 and u < L:
						return 1.0
	# bare rock showing through the thin soil off the trail (the quarry hillside)
	var rock: float = t["rock"]
	if rock > 0.0 and l.z > 4.0:
		return smoothstep(0.55 - 0.35 * rock, 0.75 - 0.35 * rock, _noise.get_noise_2d(x * 2.2 + 90.0, z * 2.2) * 0.5 + 0.5)
	return 0.0


## 0 open meadow .. 1 under the trees.
static func forest(x: float, z: float) -> float:
	_setup()
	var t: Dictionary = TRACKS[_track]
	var woods: float = t["woods"]
	var lo := lerpf(0.5, -0.15, woods)
	var f := smoothstep(lo, lo + 0.4, _noise.get_noise_2d(x * 1.3 + 400.0, z * 1.3))
	# woods on a hill's flanks, an open top
	for hl: Vector4 in t["hills"]:
		if hl.w < 6.0:
			continue
		var hd := Vector2(x, z).distance_to(Vector2(hl.x, hl.y)) / hl.z
		f = maxf(f, woods * smoothstep(0.3, 0.45, hd) * (1.0 - smoothstep(0.9, 1.05, hd)))
		f *= smoothstep(0.22, 0.32, hd)
	# trees along the creek
	if not creeks().is_empty() and float(t.get("ash", 0.0)) <= 0.0:
		f = maxf(f, 1.0 - smoothstep(7.0, 16.0, _creek_d(x, z)))
	# the meadow and the trailhead stay open
	f *= smoothstep(22.0, 34.0, Vector2(x, z).distance_to(t["meadow"]))
	f *= smoothstep(14.0, 22.0, Vector2(x, z).distance_to(t["lot"]))
	f *= smoothstep(3.5, 7.0, _nearest(x, z).x)
	return f


## Distance to the nearest trail (REACH or more when far).
static func trail_dist(x: float, z: float) -> float:
	_setup()
	return minf(_nearest(x, z).x, REACH)


# --- what stands on it ----------------------------------------------------------------

static func _obs_point(o: Dictionary, u: float, lat: float) -> Vector2:
	var main: Dictionary = _tracks[0]
	var s := float(o["sc"]) - float(o["len"]) * 0.5 + u
	return _at(main, s) + _normal(main, s) * lat


static func _find(kind: String) -> Dictionary:
	_setup()
	for o in _obs:
		if o["kind"] == kind:
			return o
	return {}


## Boulders: Vector4(x, centre y offset from the ground, z, radius); the
## terrain sets them on its own ground. The rock mesh stands two thirds of
## its radius over its centre.
static func rocks() -> Array[Vector4]:
	_setup()
	var t: Dictionary = TRACKS[_track]
	var out: Array[Vector4] = []
	var top := 0.67
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + 9 + _track * 31
	for o in _obs:
		var L: float = o["len"]
		match o["kind"]:
			"straddle":
				# (u, height over the ground)
				for r: Vector2 in [Vector2(5, 0.45), Vector2(11, 0.6), Vector2(17, 0.75)]:
					var rad := r.y * 1.05
					var p := _obs_point(o, r.x, 0.0)
					out.append(Vector4(p.x, r.y - top * rad, p.y, rad))
			"squeeze":
				# boulders on the low side of the camber, a couple up the high side
				for b: Vector3 in [Vector3(6, -1, 1.0), Vector3(12, 1, 0.9), Vector3(18, -1, 1.1), Vector3(23, 1, 0.85)]:
					var p := _obs_point(o, b.x, b.y * float(o["up"]) * (1.2 + b.z))
					out.append(Vector4(p.x, 0.05, p.y, b.z))
			"boulders":
				# stones half-sunk all across the lane, gaps between to find
				var r0 := _num(o, "r0", 0.2)
				var r1 := _num(o, "r1", 0.5)
				for k in int(_num(o, "n", 30.0)):
					var p := _obs_point(o, rng.randf_range(2.0, L - 2.0), rng.randf_range(-float(o["w"]) + 0.4, float(o["w"]) - 0.4))
					var r := rng.randf_range(r0, r1)
					out.append(Vector4(p.x, -0.3 * r, p.y, r))
			"rockford":
				# river boulders in the ford itself, across the line
				for k in 22:
					var p := _obs_point(o, rng.randf_range(2.0, L - 2.0), rng.randf_range(-float(o["w"]) + 0.3, float(o["w"]) - 0.3))
					var r := rng.randf_range(0.22, 0.48)
					out.append(Vector4(p.x, -0.3 * r, p.y, r))
		if (o["p"] as Dictionary).get("anchor", false):
			# the winch rock past it, on the far side from its bypass, and a
			# second to try a redirect off
			var away := -float(o["side"]) if int(o["side"]) != 0 else 1.0
			var w1 := _obs_point(o, L + 4.0, away * 5.0)
			out.append(Vector4(w1.x, 0.1, w1.y, 1.5))
			var w2 := _obs_point(o, L * 0.5, away * 7.5)
			out.append(Vector4(w2.x, 0.1, w2.y, 1.1))
	# stones along the creeks and loose boulders about, off the trail
	for ci in creeks().size():
		if (creeks()[ci] as Dictionary).get("braided", false):
			continue   # (a lahar stream's bed is sand bars, its stones come below)
		var placed := 0
		var tries := 0
		while placed < 70 and tries < 2000:
			tries += 1
			var x := rng.randf_range(12.0, SIZE - 12.0)
			var z := creek_mid(ci, x) + rng.randf_range(-9.0, 9.0)
			if _nearest(x, z).x < 6.0:
				continue
			var r := 0.25 + pow(rng.randf(), 2.0) * 0.8
			out.append(Vector4(x, -0.35 * r, z, r))
			placed += 1
	var want: int = t["stones"]
	var placed := 0
	var tries := 0
	var rocky: float = t["rock"]
	while placed < want and tries < 4000:
		tries += 1
		var x := rng.randf_range(12.0, SIZE - 12.0)
		var z := rng.randf_range(12.0, LENGTH - 12.0)
		if _nearest(x, z).x < 6.0 or (rocky <= 0.0 and ash(x, z) <= 0.0 and forest(x, z) < 0.6):
			continue
		var r := rng.randf_range(0.5, 1.3)
		out.append(Vector4(x, -0.35 * r, z, r))
		placed += 1
	return out


## Where trees stand: in the woods, some right at the trail's edge (winch
## anchors), a few lone ones out in the open.
static func tree_spots() -> Array[Vector3]:
	_setup()
	var out: Array[Vector3] = []   # x, z, scale
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + 3 + _track * 17
	var t: Dictionary = TRACKS[_track]
	# how close the trees come to the trail (a jungle trail: right to its edge)
	var clear := float(t.get("clear", 3.4))
	var step := 5.0 if clear >= 3.0 else 3.6
	var z := 8.0
	while z < LENGTH - 6.0:
		var x := 8.0
		while x < SIZE - 6.0:
			var px := x + rng.randf_range(-step * 0.44, step * 0.44)
			var pz := z + rng.randf_range(-step * 0.44, step * 0.44)
			var f := forest(px, pz)
			if clear < 3.0:
				f = maxf(f, (1.0 - smoothstep(4.0, 9.0, _nearest(px, pz).x)) * float(t["woods"]))
			var lone := rng.randf() < 0.012
			if (rng.randf() < 0.6 * f or lone) and _nearest(px, pz).x > clear and bedrock(px, pz) < 0.5:
				out.append(Vector3(px, pz, rng.randf_range(0.75, 1.2)))
			x += step
		z += step
	# tree squeezes: a pair of trunks every few metres, the gap between them
	# (trunk to trunk) what the obstacle says
	for o in _obs:
		if o["kind"] != "trees":
			continue
		var gap := _num(o, "gap", 2.5)
		var u := 4.0
		while u < float(o["len"]) - 3.0:
			for side: float in [-1.0, 1.0]:
				var p := _obs_point(o, u + side * 0.6, side * (gap * 0.5 + 0.3))
				out.append(Vector3(p.x, p.y, 1.0))
			u += 6.5
	# where there's a winch rock, trees close on the same side too
	for o in _obs:
		if not (o["p"] as Dictionary).get("anchor", false):
			continue
		var away := -float(o["side"]) if int(o["side"]) != 0 else 1.0
		for u: float in [4.0, float(o["len"]) * 0.5, float(o["len"]) - 4.0]:
			var p := _obs_point(o, u, away * 6.5)
			out.append(Vector3(p.x, p.y, 1.0))
	return out


## Creek `ci`'s riffles: Vector3(x, width, water depth there). One where the
## loop fords it (a ford or a rocky ford), one where a deep crossing's or a
## bridge's bypass does; the rest of the creek is its deep runs.
static func fords(ci: int) -> Array[Vector3]:
	_setup()
	var out: Array[Vector3] = []
	for o in _obs:
		if int(o["creek"]) != ci:
			continue
		match o["kind"]:
			"ford", "rockford":
				out.append(Vector3(_at(_tracks[0], float(o["sc"])).x, 4.0, _num(o, "shallow", 0.35)))
			"deep", "bridge":
				if int(o["track"]) >= 0:
					var bt: Dictionary = _tracks[int(o["track"])]
					var s := _crossing_s(bt, ci, 0.0, float((bt["pts"] as PackedVector2Array).size() - 1))
					out.append(Vector3(_at(bt, s).x, 3.5, 0.45))
	return out


## Where along path `t` (between s0 and s1) it crosses creek `ci`'s middle.
static func _crossing_s(t: Dictionary, ci: int, s0: float, s1: float) -> float:
	var s := s0
	var prev := 0.0
	while s <= s1:
		var p := _at(t, s)
		var side := p.y - creek_mid(ci, p.x)
		if s > s0 and signf(side) != signf(prev):
			return s
		prev = side
		s += 0.25
	return (s0 + s1) * 0.5


## Things built on the trail, for Terrain to make solid: a timber bridge
## ({type "bridge", from, to (Vector3, the deck's ends), width}) and fallen
## logs ({type "log", from, to, radius}). Heights are the trail's own.
static func structures() -> Array[Dictionary]:
	_setup()
	var out: Array[Dictionary] = []
	var main: Dictionary = _tracks[0]
	for o in _obs:
		var L: float = o["len"]
		match o["kind"]:
			"bridge":
				# a deck from bank to bank, a little proud of the banks
				var a := _obs_point(o, 0.0, 0.0)
				var b := _obs_point(o, L, 0.0)
				var s0 := float(o["sc"]) - L * 0.5
				var y := maxf(_prof(main, s0), _prof(main, s0 + L)) + 0.22
				out.append({"type": "bridge", "from": Vector3(a.x, y, a.y), "to": Vector3(b.x, y, b.y), "width": 2.9})
			"logs":
				# trunks across the trail, a little skew, each bigger than the last
				var k := 0
				for r: float in [0.15, 0.2, 0.23]:
					var u := 5.0 + 7.0 * k
					var skew := 0.5 if k % 2 == 0 else -0.5
					var a := _obs_point(o, u - skew, -3.2)
					var b := _obs_point(o, u + skew, 3.2)
					var s := float(o["sc"]) - L * 0.5 + u
					var y := _prof(main, s) + r * 0.8   # bedded in a little
					out.append({"type": "log", "from": Vector3(a.x, y, a.y), "to": Vector3(b.x, y, b.y), "radius": r})
					k += 1
	return out


## Along the deep crossing's centre line: [point, the left normal] every 0.25 m
## (Terrain puts the depth posts where the water reaches each 0.3 m).
static func deep_line() -> Array:
	var o := _find("deep")
	var out := []
	if o.is_empty():
		return out
	var u := -6.0
	while u < float(o["len"]) * 0.5 + 1.0:
		var s := float(o["sc"]) - float(o["len"]) * 0.5 + u
		out.append([_at(_tracks[0], s), _normal(_tracks[0], s)])
		u += 0.25
	return out


## Which side of the deep crossing the posts go (away from its bypass).
static func post_side() -> float:
	var o := _find("deep")
	return -float(o["side"]) if not o.is_empty() else 1.0


# --- stations, spawn, recovery ------------------------------------------------------

## The obstacles as stations: name, what it tests, where to start (10 m
## before it, on the loop), the heading there, and a sign post.
static func stations() -> Array[Dictionary]:
	_setup()
	if not _stations.is_empty():
		return _stations
	var out: Array[Dictionary] = _stations
	for o in _obs:
		var s := float(o["sc"]) - float(o["len"]) * 0.5 - 10.0
		var tn := _tangent(_tracks[0], s)
		var side := -float(o["side"]) if int(o["side"]) != 0 else 1.0
		out.append({"name": o["name"], "what": o["what"], "at": _at(_tracks[0], s), "heading": Vector3(tn.x, 0.0, tn.y),
			"sign": _at(_tracks[0], s + 4.0) + _normal(_tracks[0], s + 4.0) * side * 3.8,
			"centre": _at(_tracks[0], float(o["sc"]))})
	return out


## Where the rig starts: the trailhead, heading off round the loop.
static func spawn() -> Dictionary:
	_setup()
	var tn := _tangent(_tracks[0], 0.0)
	return {"at": _at(_tracks[0], 0.0), "heading": Vector3(tn.x, 0.0, tn.y)}


## Which station (x, z) is at or coming up to, -1 out on the loop between them.
static func station_at(x: float, z: float) -> int:
	_setup()
	var near := _nearest(x, z)
	for i in _obs.size():
		if int(_obs[i]["track"]) == int(near.y) and near.x < 6.0:
			return i   # on its bypass
	var l := _local(_tracks[0], x, z)
	if l.z > 15.0:
		return -1
	for i in _obs.size():
		var u := _along(_obs[i], l.x)
		if u > -12.0 and u < float(_obs[i]["len"]) + 4.0:
			return i
	return -1


## The marshal's recovery: back on whichever path is nearest, `back` metres
## behind, facing along it.
static func recover_point(x: float, z: float, back: float) -> Dictionary:
	_setup()
	var near := _nearest(x, z)
	var t: Dictionary = _tracks[maxi(int(near.y), 0)]
	var s := _local(t, x, z).x - back
	if near.y < 0.0:
		s = _local(_tracks[0], x, z).x
	var tn := _tangent(t, s)
	return {"at": _at(t, s), "heading": Vector3(tn.x, 0.0, tn.y)}


## A point on the loop `ahead` metres on from where (x, z) is: for a bot
## (or a camera) to follow the trail.
static func ahead_on_loop(x: float, z: float, ahead: float) -> Vector2:
	_setup()
	var l := _local(_tracks[0], x, z)
	return _at(_tracks[0], l.x + ahead)


## How far round the loop (x, z) is, in metres from the trailhead; the loop's length.
static func loop_s(x: float, z: float) -> float:
	_setup()
	return _local(_tracks[0], x, z).x


static func loop_length() -> float:
	_setup()
	return float((_tracks[0]["pts"] as PackedVector2Array).size())


# --- the preview map ------------------------------------------------------------------

## For the track list: a picture of track `i` from above (2 m a pixel:
## shaded relief, woods, bare rock, the creek) and its paths and obstacles
## in map pixels. Builds the layout to draw it, so `use` the one you drive
## again after.
static func preview(i: int) -> Dictionary:
	use(i)
	_setup()
	var nx := int(SIZE / 2.0)
	var nz := int(LENGTH / 2.0)
	var hts := PackedFloat32Array()
	hts.resize(nx * nz)
	for zi in nz:
		for xi in nx:
			hts[zi * nx + xi] = height(xi * 2.0 + 1.0, zi * 2.0 + 1.0)
	var img := Image.create(nx, nz, false, Image.FORMAT_RGB8)
	var cs := creeks()
	for zi in nz:
		for xi in nx:
			var x := xi * 2.0 + 1.0
			var z := zi * 2.0 + 1.0
			var h := hts[zi * nx + xi]
			var hx := hts[zi * nx + mini(xi + 1, nx - 1)] - hts[zi * nx + maxi(xi - 1, 0)]
			var hz := hts[mini(zi + 1, nz - 1) * nx + xi] - hts[maxi(zi - 1, 0) * nx + xi]
			# light from the north-west
			var shade := clampf(1.0 + (-hx + hz) * 0.35, 0.55, 1.35)
			var col := Color(0.42, 0.55, 0.24).lerp(Color(0.2, 0.33, 0.14), forest(x, z))
			col = col.lerp(Color(0.62, 0.6, 0.55), ash(x, z))
			col = col.lerp(Color(0.52, 0.5, 0.46), bedrock(x, z))
			col = col.lightened(clampf(h * 0.015, 0.0, 0.25))
			for ci in cs.size():
				if absf(z - creek_mid(ci, x)) < float(cs[ci]["half_w"]):
					col = Color(0.25, 0.38, 0.42)
					shade = 1.0
			img.set_pixel(xi, zi, col * shade)
	var paths := []
	for t in _tracks:
		var pts := PackedVector2Array()
		for p in (t["pts"] as PackedVector2Array):
			pts.append(p / 2.0)
		if t["loop"]:
			pts.append(pts[0])
		paths.append(pts)
	var marks := []
	for st in stations():
		marks.append({"name": st["name"], "at": (st["centre"] as Vector2) / 2.0})
	return {"image": img, "paths": paths, "marks": marks, "spawn": (spawn()["at"] as Vector2) / 2.0,
		"length": loop_length(), "size": Vector2(nx, nz)}
