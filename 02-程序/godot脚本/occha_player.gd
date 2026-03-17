extends CharacterBody2D
## =============================================================================
## OCCHA 场景主控角色 (OcchaPlayer)
## =============================================================================
## OCCHA 格式的主控角色，精灵为 32x64，动画为 UP/DOWN/LEFT/STAND。
## 与普通 Player 类似，但使用不同的精灵布局和动画名，适配 OCCHA.tscn 场景。
## 同样记录路径并提供 get_point_at_path_distance() 供 OcchaFollower 跟随。
## =============================================================================

const _SpritesheetGen := preload("res://occha_spritesheet_generator.gd")

@export var spritesheet: Texture2D  ## 精灵图，自动生成 UP/DOWN/LEFT/STAND 动画
@export var sprite_offset_y := -9.0  ## 精灵原点 Y 偏移，负值使脚底对齐地面
@export var speed := 70.0  ## 移动速度（像素/秒）

const PATH_RECORD_MIN_DISTANCE := 3.0  ## 记录路径点的最小移动距离
const PATH_MAX_POINTS := 300  ## 路径最大点数

var _path_positions: Array[Vector2] = []
var _path_facings: Array[Vector2] = []

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	animated_sprite.offset = Vector2(0, sprite_offset_y)
	if spritesheet:
		var gen := _SpritesheetGen.new()
		animated_sprite.sprite_frames = gen.build_sprite_frames(spritesheet)
		animated_sprite.animation = &"STAND"

func _physics_process(_delta: float) -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	var should_record := false
	if _path_positions.is_empty():
		should_record = true
	elif input_dir != Vector2.ZERO:
		should_record = global_position.distance_to(_path_positions[_path_positions.size() - 1]) >= PATH_RECORD_MIN_DISTANCE
	if should_record:
		_path_positions.append(global_position)
		_path_facings.append(input_dir if input_dir != Vector2.ZERO else (Vector2.DOWN if _path_facings.is_empty() else _path_facings[_path_facings.size() - 1]))
		while _path_positions.size() > PATH_MAX_POINTS:
			_path_positions.pop_front()
			_path_facings.pop_front()

	velocity = input_dir * speed
	move_and_slide()

	_update_animation(input_dir)

## 根据输入方向切换动画，LEFT 用 flip_h 区分左右
func _update_animation(input_dir: Vector2) -> void:
	if input_dir == Vector2.ZERO:
		animated_sprite.pause()
		return

	animated_sprite.play()
	if input_dir.y > 0:
		animated_sprite.animation = &"DOWN"
		animated_sprite.flip_h = false
	elif input_dir.y < 0:
		animated_sprite.animation = &"UP"
		animated_sprite.flip_h = false
	elif input_dir.x > 0:
		animated_sprite.animation = &"LEFT"
		animated_sprite.flip_h = true
	elif input_dir.x < 0:
		animated_sprite.animation = &"LEFT"
		animated_sprite.flip_h = false

## 供 OcchaFollower 调用：返回路径上距末端 distance_back 处的点
func get_point_at_path_distance(distance_back: float) -> Dictionary:
	if _path_positions.is_empty():
		return {"position": global_position, "facing": Vector2.DOWN}
	if _path_positions.size() == 1:
		return {"position": _path_positions[0], "facing": _path_facings[0] if _path_facings.size() > 0 else Vector2.DOWN}

	var remaining := distance_back
	var i := _path_positions.size() - 1
	while i > 0:
		var seg_len: float = _path_positions[i].distance_to(_path_positions[i - 1])
		if remaining <= seg_len and seg_len > 0.001:
			var t := 1.0 - remaining / seg_len
			var pos: Vector2 = _path_positions[i - 1].lerp(_path_positions[i], t)
			var face: Vector2 = _path_facings[i - 1] if i - 1 < _path_facings.size() else Vector2.DOWN
			return {"position": pos, "facing": face}
		remaining -= seg_len
		i -= 1

	return {"position": _path_positions[0], "facing": _path_facings[0] if _path_facings.size() > 0 else Vector2.DOWN}
