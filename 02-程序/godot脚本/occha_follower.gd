extends CharacterBody2D
## =============================================================================
## OCCHA 场景专用跟随者 (OcchaFollower)
## =============================================================================
## 跟随 OcchaPlayer 或任意实现 get_point_at_path_distance() 的节点。
## 动画为 UP/DOWN/LEFT/STAND，精灵 32x64，需 sprite_offset_y 使脚底贴地。
## 用法与 Follower 相同，但适配 OCCHA 的精灵布局和动画命名。
## =============================================================================

const _SpritesheetGen := preload("res://occha_spritesheet_generator.gd")

@export_group("外观")
@export var spritesheet: Texture2D
@export var sprite_offset_y := -9.0  ## 精灵原点 Y 偏移，使脚底对齐地面

@export_group("跟随")
@export var follow_target_path: NodePath
@export var follow_distance := 24.0
@export var follow_stop_distance := 6.0
@export var speed := 70.0

var _leader: Node2D

@onready var sprite: Node = _get_visual_node()

func _get_visual_node() -> Node:
	var anim := get_node_or_null("AnimatedSprite2D")
	return anim if anim else get_node_or_null("Sprite2D")

func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING  ## 俯视角
	var anim_sprite := _get_visual_node()
	if anim_sprite is AnimatedSprite2D:
		(anim_sprite as AnimatedSprite2D).offset = Vector2(0, sprite_offset_y)
	if spritesheet:
		if anim_sprite is AnimatedSprite2D:
			var gen := _SpritesheetGen.new()
			var frames := gen.build_sprite_frames(spritesheet)
			(anim_sprite as AnimatedSprite2D).sprite_frames = frames
			(anim_sprite as AnimatedSprite2D).animation = &"STAND"

	collision_layer = 2
	collision_mask = 0

	if follow_target_path.is_empty():
		push_error("OcchaFollower: follow_target_path 未设置")
		return
	_leader = get_node_or_null(follow_target_path)
	if not _leader:
		push_error("OcchaFollower: 找不到跟随目标 %s" % follow_target_path)

func _physics_process(_delta: float) -> void:
	if not _leader or not _leader.has_method("get_point_at_path_distance"):
		return

	var point: Dictionary = _leader.get_point_at_path_distance(follow_distance)
	var target_pos: Vector2 = point.position
	var path_facing: Vector2 = point.facing

	var dist := global_position.distance_to(target_pos)

	if dist > follow_stop_distance:
		var dir: Vector2 = (target_pos - global_position).normalized()
		velocity = dir * speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO

	_update_animation(path_facing, dist > follow_stop_distance)

func _update_animation(path_facing: Vector2, is_moving: bool) -> void:
	if not sprite or not sprite is AnimatedSprite2D:
		return
	var anim := sprite as AnimatedSprite2D
	if anim.sprite_frames == null or anim.sprite_frames.get_animation_names().is_empty():
		return

	if is_moving:
		anim.play()
	else:
		anim.pause()
		return

	if path_facing == Vector2.ZERO:
		return
	## 按主方向选择动画，|y|>=|x| 判上下，否则判左右
	var ax := absf(path_facing.x)
	var ay := absf(path_facing.y)
	if ay >= ax:
		if path_facing.y > 0:
			anim.animation = &"DOWN"
			anim.flip_h = false
		else:
			anim.animation = &"UP"
			anim.flip_h = false
	elif path_facing.x > 0:
		anim.animation = &"LEFT"
		anim.flip_h = true
	else:
		anim.animation = &"LEFT"
		anim.flip_h = false
