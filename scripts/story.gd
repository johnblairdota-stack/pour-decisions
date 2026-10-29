extends RefCounted
## The tower's story: eleven named days, one per floor, from the client's
## first slab to the roof. Each day sets its weather from the systems that
## already exist (heat, traffic, a shower, wind, the engineer's hold point)
## and its light: the hour and the sky match what's happening that day.
## The site page lists the names, so the tower reads as a story from the menu.

## [name, one line for the toolbox talk, light, overrides for _level_cfg]
## Overrides left out keep the usual roll; rain, traffic and wind are always
## set here, so a day's weather never fights its light.
const DAYS := [
	["First slab", "The client's up on the deck in a hard hat and good shoes. Make it look easy.",
		"morning", {"temp": 24, "rain": false, "traffic": 1.0, "gusty": false, "defect": false}],
	["Hold point", "The engineer walks the steel before a drop goes in. Fix what they find.",
		"midmorning", {"rain": false, "traffic": 1.0, "gusty": false, "defect": true}],
	["Friday arvo", "Last pour of the week. Kingsford Smith Drive's backed up and everyone wants to knock off.",
		"arvo", {"rain": false, "traffic": 1.5, "gusty": false}],
	["Up a floor", "The boom tower climbs before the pour. Clear sky, hardly a breath of wind.",
		"midmorning", {"rain": false, "traffic": 1.0, "gusty": false}],
	["School holidays", "CityCats packed on the river, not a cloud about. Bright and clear.",
		"noon", {"rain": false, "traffic": 1.0, "gusty": false}],
	["Hot one", "36 degrees by lunch, the sun straight overhead. The edge goes off fast.",
		"hot", {"temp": 36, "rain": false, "traffic": 1.0, "gusty": false}],
	["Storm's coming", "Climb, then pour before the storm rolls in off the bay. It'll hit mid-pour.",
		"overcast", {"rain": true, "rain_at": 40.0, "rain_len": 20.0, "traffic": 1.0, "gusty": false, "temp": 27}],
	["Dawn pour", "Big pour, so it starts in the dark under the floodlights. Sunrise over Bulimba is the clock.",
		"morning", {"dawn": true, "rain": false, "gusty": false}],
	["Engineer's back", "Grey and still. The engineer wants a second look at the steel before we pour.",
		"grey", {"rain": false, "traffic": 1.0, "gusty": false, "defect": true}],
	["Last climb", "The boom tower's final climb, late in the day. A northerly's picking up.",
		"golden", {"rain": false, "traffic": 1.0, "gusty": true}],
	["Top-out", "The roof slab. The sun's going down over the city and the whole street's watching.",
		"sunset", {"rain": false, "traffic": 1.0, "gusty": false, "temp": 25}],
]

## The light presets: [sky top, horizon, sun colour, sun energy, ambient,
## sun elevation (deg), where the sun is (a flat direction in the game's
## frame: x is west, z is north; late October, so it rises and sets a little
## south of east and west), haze density, cloud cover]
const LIGHTS := {
	"morning": [Color("3a78c9"), Color("cfdfe8"), Color("fff2df"), 1.2, 0.6, 42.0, Vector2(-0.4, 0.92), 0.00015, 0.42],
	"midmorning": [Color("3574c6"), Color("d4e2ea"), Color("fff5e6"), 1.3, 0.62, 55.0, Vector2(-0.25, 0.97), 0.00015, 0.35],
	"noon": [Color("3c7fd0"), Color("d9e5ec"), Color("fffaf2"), 1.4, 0.66, 70.0, Vector2(0.0, 1.0), 0.00014, 0.25],
	"hot": [Color("5a8fcf"), Color("ebe6d6"), Color("fff8ea"), 1.55, 0.72, 74.0, Vector2(0.1, 1.0), 0.00032, 0.08],
	"arvo": [Color("3a6fb8"), Color("e8dcc4"), Color("ffe6c0"), 1.1, 0.56, 30.0, Vector2(0.75, 0.65), 0.00018, 0.38],
	"overcast": [Color("7b8796"), Color("b7c0c8"), Color("e9ecef"), 0.6, 0.85, 50.0, Vector2(0.4, 0.9), 0.00030, 0.92],
	"storm": [Color("434c58"), Color("858e97"), Color("c5cbd1"), 0.28, 0.62, 50.0, Vector2(0.4, 0.9), 0.00055, 1.0],
	"grey": [Color("8794a2"), Color("c3cad0"), Color("eef0f2"), 0.7, 0.82, 45.0, Vector2(-0.5, 0.85), 0.00026, 0.85],
	"golden": [Color("3a66ad"), Color("f0cf9c"), Color("ffcf94"), 1.0, 0.5, 16.0, Vector2(0.95, -0.1), 0.00020, 0.3],
	"sunset": [Color("2c4b8a"), Color("f2a670"), Color("ff9f62"), 0.85, 0.42, 7.0, Vector2(0.95, -0.3), 0.00022, 0.35],
}

static func day(level: int) -> Array:
	return DAYS[clampi(level, 0, DAYS.size() - 1)]

static func title(level: int) -> String:
	return day(level)[0]

static func line(level: int) -> String:
	return day(level)[1]

static func light(level: int) -> Array:
	return LIGHTS[day(level)[2]]

## A light part way from preset a to b.
static func mix(a: Array, b: Array, w: float) -> Array:
	var out := []
	for i in a.size():
		var x = a[i]
		var y = b[i]
		if x is Color:
			out.append((x as Color).lerp(y, w))
		elif x is Vector2:
			out.append((x as Vector2).lerp(y, w))
		else:
			out.append(lerpf(x, y, w))
	return out
