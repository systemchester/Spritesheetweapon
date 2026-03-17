extends CharacterBody2D
## =============================================================================
## H2 横版动作角色控制器
## =============================================================================
## 操作：A/D 或 左右方向键 移动，Shift 跑步，空格 跳跃，J 攻击，M 死亡
## 动画：IDLE / WALKRIGHT / RUNRIGHT / JUMP / ATTRACK / DIE
## =============================================================================

@export var walk_speed := 120.0
@export var run_speed := 200.0
@export var jump_velocity := -320.0

@export var zoom_min := 1.0
@export var zoom_max := 4.0
@export var zoom_step := 0.2

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float
var _facing_right := true
var _attack_cooldown := 0.0
var _state := "normal"  ## normal / attacking / dead

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	animated_sprite.animation_finished.connect(_on_animated_sprite_2d_animation_finished)

func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)

	if _state == "dead":
		return
	if _state == "attacking":
		velocity.x = move_toward(velocity.x, 0, run_speed * delta * 3)
		velocity.y += gravity * delta
		move_and_slide()
		return

	var move_right := Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	var move_left := Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var is_running := Input.is_key_pressed(KEY_SHIFT)
	var speed := run_speed if is_running else walk_speed

	if move_right:
		_facing_right = true
		velocity.x = speed
	elif move_left:
		_facing_right = false
		velocity.x = -speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * delta * 4)

	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = jump_velocity

	velocity.y += gravity * delta
	move_and_slide()

	_update_animation(move_right or move_left, is_running)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = (camera.zoom + Vector2(zoom_step, zoom_step)).clamp(Vector2(zoom_min, zoom_min), Vector2(zoom_max, zoom_max))
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = (camera.zoom - Vector2(zoom_step, zoom_step)).clamp(Vector2(zoom_min, zoom_min), Vector2(zoom_max, zoom_max))

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J and _state == "normal" and _attack_cooldown <= 0:
			_state = "attacking"
			_attack_cooldown = 0.5
			animated_sprite.play("ATTRACK")
			animated_sprite.flip_h = not _facing_right
		elif event.keycode == KEY_M and _state != "dead":
			_state = "dead"
			velocity = Vector2.ZERO
			animated_sprite.play("DIE")

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "ATTRACK":
		_state = "normal"

func _update_animation(is_moving: bool, is_running: bool) -> void:
	if _state != "normal":
		return

	animated_sprite.flip_h = not _facing_right

	if not is_on_floor():
		animated_sprite.play("JUMP")
		return

	if is_moving:
		animated_sprite.play("RUNRIGHT" if is_running else "WALKRIGHT")
	else:
		animated_sprite.play("IDLE")
