extends CharacterBody2D
## =============================================================================
## 传统 RPG 队列跟随者 (Follower)
## =============================================================================
## 跟随主控角色或任意实现 get_point_at_path_distance() 的节点，严格按路径排队。
## 用法：
##   1. 在场景中放置 Follower 节点
##   2. 设置 follow_target_path 指向 Player 或 AutoPathMover
##   3. 设置 spritesheet 指定精灵图，会自动生成 down/right/up 动画
## 布局要求：32x32 帧，Row0=down, Row1=right, Row2=up，每行 4 帧
## =============================================================================

const _SpritesheetGen := preload("res://spritesheet_generator.gd")

@export_group("外观")
@export var spritesheet: Texture2D  ## 精灵图，自动生成 down/right/up 三方向动画

@export_group("跟随")
@export var follow_target_path: NodePath  ## 跟随目标的节点路径（如 Player）
@export var follow_distance := 24.0  ## 与路径末端的距离，不同跟随者设不同值实现排队
@export var follow_stop_distance := 6.0  ## 与目标距离小于此值时停止移动，避免抖动
@export var speed := 70.0  ## 移动速度（像素/秒）

var _leader: Node2D  ## 缓存跟随目标节点引用

@onready var sprite: Node = _get_visual_node()

## 获取显示精灵的节点（优先 AnimatedSprite2D，否则 Sprite2D）
func _get_visual_node() -> Node:
	var anim := get_node_or_null("AnimatedSprite2D")
	return anim if anim else get_node_or_null("Sprite2D")

func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING  ## 俯视角
	## 自动从 spritesheet 生成 SpriteFrames 并赋值给 AnimatedSprite2D
	if spritesheet:
		var anim_sprite := _get_visual_node()
		if anim_sprite is AnimatedSprite2D:
			var gen := _SpritesheetGen.new()
			var frames := gen.build_sprite_frames(spritesheet)
			(anim_sprite as AnimatedSprite2D).sprite_frames = frames
			(anim_sprite as AnimatedSprite2D).animation = &"down"

	collision_layer = 2  ## 放在第 2 层，可与主控区分
	collision_mask = 0   ## 不检测碰撞，纯视觉跟随

	if follow_target_path.is_empty():
		push_error("Follower: follow_target_path 未设置")
		return
	_leader = get_node_or_null(follow_target_path)
	if not _leader:
		push_error("Follower: 找不到跟随目标 %s" % follow_target_path)

func _physics_process(_delta: float) -> void:
	if not _leader or not _leader.has_method("get_point_at_path_distance"):
		return

	## 从领导者获取本跟随者的目标位置（按 follow_distance 沿路径回溯）
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

## 根据路径朝向和是否移动更新动画
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

	if path_facing == Vector2.ZERO:
		return
	## 按主方向选择动画：若 |y| >= |x| 则判上下，否则判左右
	## 避免斜向移动时因微小 y 分量误判为上下
	var ax := absf(path_facing.x)
	var ay := absf(path_facing.y)
	if ay >= ax:
		if path_facing.y > 0:
			anim.animation = &"down"
			anim.flip_h = false
		else:
			anim.animation = &"up"
			anim.flip_h = false
	elif path_facing.x > 0:
		anim.animation = &"right"
		anim.flip_h = false
	else:
		anim.animation = &"right"
		anim.flip_h = true
