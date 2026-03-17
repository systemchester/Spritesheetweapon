extends RefCounted
## =============================================================================
## Ocad 精灵图生成器 (OcadSpritesheetGenerator)
## =============================================================================
## 从与主角相同布局的贴图生成 SpriteFrames，动画结构与 ocad 主角完全一致。
## 贴图需与 res://18n/Gemini_Generated_Image_1ysr8x1ysr8x1ysr.png 相同布局。
## =============================================================================

## 区域定义：Rect2i(x, y, w, h)，与 ocad 主角 SpriteFrames 一致
const _REGIONS := {
	"uk1xb": Rect2i(0, 168, 42, 42), "m5je3": Rect2i(42, 168, 42, 42), "2ij6o": Rect2i(84, 168, 42, 42),
	"kmxfq": Rect2i(126, 168, 42, 42), "cpoga": Rect2i(168, 168, 42, 42), "02845": Rect2i(210, 168, 42, 42),
	"hg6s0": Rect2i(0, 210, 42, 42), "kwjof": Rect2i(42, 210, 42, 42),
	"5u6fn": Rect2i(126, 84, 21, 42), "t2na7": Rect2i(147, 84, 21, 42), "3kx8u": Rect2i(168, 84, 21, 42),
	"y5pas": Rect2i(189, 84, 21, 42), "8pc1g": Rect2i(210, 84, 21, 42), "3cyhk": Rect2i(231, 84, 21, 42),
	"w25ly": Rect2i(168, 126, 21, 42), "rdd8s": Rect2i(189, 210, 63, 42), "72hcl": Rect2i(210, 126, 21, 42),
	"rydce": Rect2i(189, 126, 21, 42), "1et3y": Rect2i(231, 126, 21, 42), "uwgfa": Rect2i(147, 210, 21, 42),
	"y65iy": Rect2i(168, 210, 21, 42), "8al5y": Rect2i(105, 210, 21, 42), "3js2j": Rect2i(126, 210, 21, 42),
	"bbcvv": Rect2i(0, 126, 28, 42), "foxtp": Rect2i(28, 126, 28, 42), "aw8dg": Rect2i(56, 126, 28, 42),
	"evrtr": Rect2i(84, 126, 28, 42), "pyoh8": Rect2i(112, 126, 28, 42), "t4rff": Rect2i(140, 126, 28, 42),
	"koy62": Rect2i(0, 0, 21, 42), "3ygc0": Rect2i(21, 0, 21, 42), "yfrrb": Rect2i(42, 0, 21, 42),
	"2enbr": Rect2i(63, 0, 21, 42), "s2yql": Rect2i(84, 0, 21, 42), "idc64": Rect2i(105, 0, 21, 42),
	"8mwul": Rect2i(0, 42, 21, 42), "snwwj": Rect2i(21, 42, 21, 42), "ynglr": Rect2i(42, 42, 21, 42),
	"p3oo0": Rect2i(63, 42, 21, 42), "pfwvy": Rect2i(84, 42, 21, 42), "tvkvf": Rect2i(105, 42, 21, 42),
	"20ynl": Rect2i(84, 210, 21, 42), "3c66l": Rect2i(0, 84, 21, 42), "wq5ia": Rect2i(21, 84, 21, 42),
	"11gwb": Rect2i(42, 84, 21, 42), "iitav": Rect2i(63, 84, 21, 42), "360a7": Rect2i(84, 84, 21, 42),
	"ffd0g": Rect2i(105, 84, 21, 42), "ahlcx": Rect2i(126, 0, 21, 42), "4i3vm": Rect2i(147, 0, 21, 42),
	"0qwcd": Rect2i(168, 0, 21, 42), "y1030": Rect2i(189, 0, 21, 42), "3sl87": Rect2i(210, 0, 21, 42),
	"8kwsb": Rect2i(231, 0, 21, 42), "umveo": Rect2i(126, 42, 21, 42), "v6ado": Rect2i(147, 42, 21, 42),
	"syfy0": Rect2i(168, 42, 21, 42), "us0w8": Rect2i(189, 42, 21, 42), "pf2m2": Rect2i(210, 42, 21, 42),
	"876dv": Rect2i(231, 42, 21, 42),
}

## 动画定义：名 -> [帧key数组], loop, speed
const _ANIMS := [
	{"name": "attractL", "frames": ["uk1xb","m5je3","2ij6o","kmxfq","cpoga","02845","hg6s0","kwjof"], "loop": false, "speed": 10.0},
	{"name": "climb", "frames": ["5u6fn","t2na7","3kx8u","y5pas","8pc1g","3cyhk"], "loop": true, "speed": 7.0},
	{"name": "defence", "frames": ["w25ly"], "loop": true, "speed": 5.0},
	{"name": "die", "frames": ["rdd8s"], "loop": true, "speed": 5.0},
	{"name": "idleL", "frames": ["72hcl"], "loop": true, "speed": 5.0},
	{"name": "idledown", "frames": ["rydce"], "loop": true, "speed": 5.0},
	{"name": "idleup", "frames": ["1et3y"], "loop": true, "speed": 5.0},
	{"name": "item", "frames": ["uwgfa","y65iy"], "loop": false, "speed": 5.0},
	{"name": "jump", "frames": ["8al5y","3js2j"], "loop": true, "speed": 1.0},
	{"name": "runL", "frames": ["bbcvv","foxtp","aw8dg","evrtr","pyoh8","t4rff"], "loop": true, "speed": 10.0},
	{"name": "rundown", "frames": ["koy62","3ygc0","yfrrb","2enbr","s2yql","idc64"], "loop": true, "speed": 10.0},
	{"name": "runup", "frames": ["8mwul","snwwj","ynglr","p3oo0","pfwvy","tvkvf"], "loop": true, "speed": 10.0},
	{"name": "sitdown", "frames": ["20ynl"], "loop": false, "speed": 5.0},
	{"name": "walkL", "frames": ["3c66l","wq5ia","11gwb","iitav","360a7","ffd0g"], "loop": true, "speed": 5.0},
	{"name": "walkdown", "frames": ["ahlcx","4i3vm","0qwcd","y1030","3sl87","8kwsb"], "loop": true, "speed": 5.0},
	{"name": "walkup", "frames": ["umveo","v6ado","syfy0","us0w8","pf2m2","876dv"], "loop": true, "speed": 5.0},
]

func build_sprite_frames(texture: Texture2D) -> SpriteFrames:
	var sf := SpriteFrames.new()
	var atlas_cache: Dictionary = {}  ## region_key -> AtlasTexture

	for anim in _ANIMS:
		sf.add_animation(anim.name)
		sf.set_animation_loop(anim.name, anim.loop)
		sf.set_animation_speed(anim.name, anim.speed)
		for key in anim.frames:
			if not atlas_cache.has(key):
				var r: Rect2i = _REGIONS.get(key, Rect2i(0, 0, 21, 42))
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = r
				atlas_cache[key] = atlas
			sf.add_frame(anim.name, atlas_cache[key], 1.0)
	return sf
