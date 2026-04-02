## 与 infiniteMapSpriteData.ts 一致：TINA.png 区域与动画表（速度用于 accum 逻辑）。
extends RefCounted

## 与网页 anim.accum += speed * dt；每累计 1 进一帧。
const DEFAULT_ANIM_SPEED := 5.0

const REGIONS: Dictionary = {
	"72hcl": Rect2(210, 126, 21, 42),
	"rydce": Rect2(189, 126, 21, 42),
	"1et3y": Rect2(231, 126, 21, 42),
	"bbcvv": Rect2(0, 126, 28, 42),
	"foxtp": Rect2(28, 126, 28, 42),
	"aw8dg": Rect2(56, 126, 28, 42),
	"evrtr": Rect2(84, 126, 28, 42),
	"pyoh8": Rect2(112, 126, 28, 42),
	"t4rff": Rect2(140, 126, 28, 42),
	"koy62": Rect2(0, 0, 21, 42),
	"3ygc0": Rect2(21, 0, 21, 42),
	"yfrrb": Rect2(42, 0, 21, 42),
	"2enbr": Rect2(63, 0, 21, 42),
	"s2yql": Rect2(84, 0, 21, 42),
	"idc64": Rect2(105, 0, 21, 42),
	"8mwul": Rect2(0, 42, 21, 42),
	"snwwj": Rect2(21, 42, 21, 42),
	"ynglr": Rect2(42, 42, 21, 42),
	"p3oo0": Rect2(63, 42, 21, 42),
	"pfwvy": Rect2(84, 42, 21, 42),
	"tvkvf": Rect2(105, 42, 21, 42),
	"3c66l": Rect2(0, 84, 21, 42),
	"wq5ia": Rect2(21, 84, 21, 42),
	"11gwb": Rect2(42, 84, 21, 42),
	"iitav": Rect2(63, 84, 21, 42),
	"360a7": Rect2(84, 84, 21, 42),
	"ffd0g": Rect2(105, 84, 21, 42),
	"ahlcx": Rect2(126, 0, 21, 42),
	"4i3vm": Rect2(147, 0, 21, 42),
	"0qwcd": Rect2(168, 0, 21, 42),
	"y1030": Rect2(189, 0, 21, 42),
	"3sl87": Rect2(210, 0, 21, 42),
	"8kwsb": Rect2(231, 0, 21, 42),
	"umveo": Rect2(126, 42, 21, 42),
	"v6ado": Rect2(147, 42, 21, 42),
	"syfy0": Rect2(168, 42, 21, 42),
	"us0w8": Rect2(189, 42, 21, 42),
	"pf2m2": Rect2(210, 42, 21, 42),
	"876dv": Rect2(231, 42, 21, 42),
}

const ANIMS: Array = [
	{"name": "idleL", "frames": ["72hcl"], "loop": true, "speed": 5.0},
	{"name": "idledown", "frames": ["rydce"], "loop": true, "speed": 5.0},
	{"name": "idleup", "frames": ["1et3y"], "loop": true, "speed": 5.0},
	{"name": "runL", "frames": ["bbcvv", "foxtp", "aw8dg", "evrtr", "pyoh8", "t4rff"], "loop": true, "speed": 5.0},
	{"name": "rundown", "frames": ["koy62", "3ygc0", "yfrrb", "2enbr", "s2yql", "idc64"], "loop": true, "speed": 5.0},
	{"name": "runup", "frames": ["8mwul", "snwwj", "ynglr", "p3oo0", "pfwvy", "tvkvf"], "loop": true, "speed": 5.0},
	{"name": "walkL", "frames": ["3c66l", "wq5ia", "11gwb", "iitav", "360a7", "ffd0g"], "loop": true, "speed": 5.0},
	{"name": "walkdown", "frames": ["ahlcx", "4i3vm", "0qwcd", "y1030", "3sl87", "8kwsb"], "loop": true, "speed": 5.0},
	{"name": "walkup", "frames": ["umveo", "v6ado", "syfy0", "us0w8", "pf2m2", "876dv"], "loop": true, "speed": 5.0},
]


static func anim_by_name() -> Dictionary:
	var m: Dictionary = {}
	for a in ANIMS:
		m[a["name"]] = a
	return m
