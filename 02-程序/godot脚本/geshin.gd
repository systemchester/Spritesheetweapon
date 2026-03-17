extends CharacterBody2D
## =============================================================================
## Geshin 角色控制器（俯视角 8 方向）
## =============================================================================
##
## 无重力四向移动，8 方向动画：up / down / left / right / leftup / leftdown /
## leftup+flip(up-right) / leftdown+flip(down-right)。
##
## 操作：WASD 移动，Shift 跑步，鼠标滚轮缩放。
## 动画：down, left, leftdown, leftup, up；右向用 left/leftdown/leftup + flip_h
## =============================================================================

@export var walk_speed := 70.0
@export var run_speed := 120.0

@export var zoom_min := 1.0
@export var zoom_max := 6.0
@export var zoom_step := 0.3

var _facing := Vector2.DOWN

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	input_dir = input_dir.normalized()

	var is_running := Input.is_key_pressed(KEY_SHIFT)
	var move_speed := run_speed if is_running else walk_speed

	if input_dir != Vector2.ZERO:
		_facing = input_dir
		velocity.x = input_dir.x * move_speed
		velocity.y = input_dir.y * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * delta * 4)
		velocity.y = move_toward(velocity.y, 0, move_speed * delta * 4)

	move_and_slide()
	_update_animation(input_dir, is_running)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = (camera.zoom + Vector2(zoom_step, zoom_step)).clamp(Vector2(zoom_min, zoom_min), Vector2(zoom_max, zoom_max))
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = (camera.zoom - Vector2(zoom_step, zoom_step)).clamp(Vector2(zoom_min, zoom_min), Vector2(zoom_max, zoom_max))

## 8 方向动画：按输入角度选 up/down/left/leftup/leftdown，右向加 flip_h
func _update_animation(input_dir: Vector2, _is_running: bool) -> void:
	if input_dir == Vector2.ZERO:
		## idle：按 _facing 显示站立帧
		_set_8dir_animation(_facing)
		animated_sprite.frame = 0
		animated_sprite.pause()
		return

	animated_sprite.play()
	_set_8dir_animation(input_dir)

func _set_8dir_animation(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	var angle := dir.angle()  ## -PI..PI，0=右
	var sector := int(round((angle + PI) / (TAU / 8))) % 8  ## 0..7
	match sector:
		0:  ## 左
			animated_sprite.animation = "left"
			animated_sprite.flip_h = false
		1:  ## 左上
			animated_sprite.animation = "leftup"
			animated_sprite.flip_h = false
		2:  ## 上
			animated_sprite.animation = "up"
			animated_sprite.flip_h = false
		3:  ## 右上
			animated_sprite.animation = "leftup"
			animated_sprite.flip_h = true
		4:  ## 右
			animated_sprite.animation = "left"
			animated_sprite.flip_h = true
		5:  ## 右下
			animated_sprite.animation = "leftdown"
			animated_sprite.flip_h = true
		6:  ## 下
			animated_sprite.animation = "down"
			animated_sprite.flip_h = false
		7:  ## 左下
			animated_sprite.animation = "leftdown"
			animated_sprite.flip_h = false
