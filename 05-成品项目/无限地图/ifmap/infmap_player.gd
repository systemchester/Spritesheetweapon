extends CharacterBody2D
## 俯视移动 + 与 InfiniteMapScene 一致的状态机：W/S/A/D 优先级、Shift 跑、idleL/idledown、walkL + flip。

const _TinaData := preload("res://ifmap/infmap_tina_data.gd")

## 与 infmap 世界格 24×24 匹配的大致移速（原 16 格下约 60）
@export var walk_speed: float = 90.0
@export var run_speed_multiplier: float = 2.0

var _root: Node2D
## 水平朝向：A 为 -1，D 为 +1（与网页 facingRef）；walkL/runL 时 D 侧 flip_h
var _facing: int = 1
var _anim_name: String = "idledown"
var _frame_idx: int = 0
var _anim_accum: float = 0.0
var _anim_defs: Dictionary = {}

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_root = get_parent() as Node2D
	if _root == null:
		_root = self
	_anim_defs = _TinaData.anim_by_name()
	if _sprite.texture == null:
		_sprite.texture = load("res://ifmap/map/TINA.png") as Texture2D
	_sprite.region_enabled = true
	_sprite.centered = true
	_apply_tina_frame()


func _process(delta: float) -> void:
	var def: Variant = _anim_defs.get(_anim_name)
	if def == null:
		return
	var speed: float = float(def.get("speed", _TinaData.DEFAULT_ANIM_SPEED))
	var frames: Array = def.get("frames", [])
	if frames.is_empty():
		return
	_anim_accum += speed * delta
	while _anim_accum >= 1.0:
		_anim_accum -= 1.0
		_frame_idx += 1
		if not bool(def.get("loop", true)) and _frame_idx >= frames.size():
			_frame_idx = frames.size() - 1
			_anim_accum = 0.0
			break
		_frame_idx %= frames.size()
	_apply_tina_frame()


func _physics_process(_delta: float) -> void:
	var w := Input.is_key_pressed(KEY_W) or Input.is_action_pressed(&"ui_up")
	var s := Input.is_key_pressed(KEY_S) or Input.is_action_pressed(&"ui_down")
	var a := Input.is_key_pressed(KEY_A) or Input.is_action_pressed(&"ui_left")
	var d := Input.is_key_pressed(KEY_D) or Input.is_action_pressed(&"ui_right")
	var shift := Input.is_key_pressed(KEY_SHIFT)

	var walk_prefix := "run" if shift else "walk"
	var next_anim := _anim_name
	# 与网页相同分支顺序：先纯纵向再横向
	if w and not s:
		next_anim = "%sup" % walk_prefix
	elif s and not w:
		next_anim = "%sdown" % walk_prefix
	elif a and not d:
		next_anim = "%sL" % walk_prefix
		_facing = -1
	elif d and not a:
		next_anim = "%sL" % walk_prefix
		_facing = 1
	else:
		next_anim = "idleL" if _facing == -1 else "idledown"

	if next_anim != _anim_name:
		_anim_name = next_anim
		_frame_idx = 0
		_anim_accum = 0.0

	var sp := walk_speed * (run_speed_multiplier if shift else 1.0)
	var ax := 0.0
	var ay := 0.0
	if w and not s:
		ay -= 1.0
	elif s and not w:
		ay += 1.0
	elif a and not d:
		ax -= 1.0
	elif d and not a:
		ax += 1.0

	var dir := Vector2(ax, ay)
	if dir == Vector2.ZERO:
		return
	dir = dir.normalized()
	var motion := dir * sp * _delta
	if not _root.has_method(&"is_pos_walkable"):
		position += motion
		return
	var next_pos := position + motion
	if _root.call(&"is_pos_walkable", next_pos):
		position = next_pos
	elif _root.call(&"is_pos_walkable", Vector2(next_pos.x, position.y)):
		position.x = next_pos.x
	elif _root.call(&"is_pos_walkable", Vector2(position.x, next_pos.y)):
		position.y = next_pos.y


func _apply_tina_frame() -> void:
	var def: Variant = _anim_defs.get(_anim_name)
	if def == null:
		return
	var frames: Array = def.get("frames", [])
	if frames.is_empty():
		return
	var key: String = str(frames[_frame_idx % frames.size()])
	var r: Variant = _TinaData.REGIONS.get(key)
	if r == null or not r is Rect2:
		return
	var rr: Rect2 = r as Rect2
	_sprite.region_rect = rr
	# 网页：ctx.scale(-facing * sc, sc)；facing=+1（D）时水平翻转 walkL/runL
	var is_side := _anim_name.ends_with("L")
	_sprite.flip_h = is_side and _facing == 1
	# 脚底在节点原点：精灵中心在脚底上方半高
	_sprite.offset = Vector2(0.0, -rr.size.y * 0.5)
