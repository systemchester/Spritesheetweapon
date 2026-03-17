extends Node2D
## =============================================================================
## Ocad NPC (OcadNpc)
## =============================================================================
## 基于 ocad 场景的静态 NPC，动画与主角完全一致。
## 只需设置 spritesheet 贴图即可生成，贴图布局需与主角相同。
## 待机时 random_idle 切换下/左/右，random_item 切换使用道具第二帧
## =============================================================================

@export var spritesheet: Texture2D  ## 精灵贴图（布局需与 ocad 主角一致）
@export var random_idle := true  ## 随机切换待机朝向（下/左/右，不含上）
@export var random_item := true  ## 随机切换到使用道具第二帧
@export var idle_switch_min := 2.0  ## 切换间隔最小秒数
@export var idle_switch_max := 5.0  ## 切换间隔最大秒数

const _Generator := preload("res://ocad/ocad_spritesheet_generator.gd")

## 待机状态：(动画名, flip_h, 暂停帧 -1=正常播放)
const _IDLE_STATES := [
	[&"idledown", false, -1],
	[&"idleL", false, -1],   ## 朝左
	[&"idleL", true, -1],    ## 朝右
]
const _ITEM_STATES := [
	[&"item", false, 1],     ## 使用道具第二帧
	[&"item", true, 1],      ## 使用道具第二帧（朝右）
]

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var _idle_timer := 0.0

func _ready() -> void:
	if not spritesheet:
		push_error("OcadNpc: 请设置 spritesheet 贴图")
		return

	var gen: RefCounted = _Generator.new()
	var frames: SpriteFrames = gen.build_sprite_frames(spritesheet)
	animated_sprite.sprite_frames = frames
	if random_idle or random_item:
		_apply_random_state()
		_idle_timer = randf_range(idle_switch_min, idle_switch_max)
	else:
		animated_sprite.animation = &"idledown"
		animated_sprite.flip_h = false
		animated_sprite.play()

func _process(delta: float) -> void:
	if (not random_idle and not random_item) or not spritesheet:
		return
	_idle_timer -= delta
	if _idle_timer <= 0:
		_idle_timer = randf_range(idle_switch_min, idle_switch_max)
		_apply_random_state()

func _get_state_pool() -> Array:
	var pool: Array = []
	if random_idle:
		pool.append_array(_IDLE_STATES)
	if random_item:
		pool.append_array(_ITEM_STATES)
	return pool

func _apply_random_state() -> void:
	var pool := _get_state_pool()
	if pool.is_empty():
		animated_sprite.animation = &"idledown"
		animated_sprite.flip_h = false
		animated_sprite.play()
		return
	var s: Array = pool.pick_random()
	animated_sprite.animation = s[0]
	animated_sprite.flip_h = s[1]
	var pause_frame: int = s[2] if s.size() > 2 else -1
	if pause_frame >= 0:
		animated_sprite.frame = pause_frame
		animated_sprite.pause()
	else:
		animated_sprite.play()
