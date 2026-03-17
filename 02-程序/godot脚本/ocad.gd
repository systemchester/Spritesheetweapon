extends CharacterBody2D
## =============================================================================
## Ocad 角色控制器（俯视角 Top-Down，参考 acha）
## =============================================================================
##
## 【核心设计】
##   - 无重力、无地面：纯四向移动，Y 轴与 X 轴等效
##   - 跳跃使用「伪 Z 轴」：offset.y 改变视觉高度，碰撞体位置不变
##   - 状态机：NORMAL / JUMPING / ATTACKING / USING / DEFENDING / DEAD
##
## 【操作键位】
##   WASD       - 四向移动（默认走路，Shift 跑步）
##   空格       - 跳跃（视觉 hop）
##   鼠标滚轮   - 缩放视图
##   V          - 切换相机模式（跟随/固定）
##   J          - 攻击（attractL，按朝向翻转）
##   I          - 使用道具（item）
##   K          - 防御（defence，持续约 0.5 秒）
##   X          - 坐下/起立（sitdown，切换）
##   M          - 死亡（die）
##
## 【动画映射】
##   行走/跑步：walkdown/rundown、walkup/runup、walkL/runL（右向用 flip_h）
##   待机：idledown、idleup、idleL
##
## 【跟随支持】提供 get_point_at_path_distance() 供 OcchaFollower 跟随
## =============================================================================

const PATH_RECORD_MIN_DISTANCE := 3.0
const PATH_MAX_POINTS := 300

var _path_positions: Array[Vector2] = []
var _path_facings: Array[Vector2] = []

@export var walk_speed := 30.0
@export var run_speed := 70.0

@export var jump_height := 40.0
@export var jump_ascent_duration := 0.3
@export var jump_fall_duration := 0.45
@export var jump_cooldown := 0.5

@export var attack_cooldown := 0.4
@export var defence_duration := 0.5

@export var zoom_min := 1.0
@export var zoom_max := 6.0
@export var zoom_step := 0.3

enum CameraMode { FOLLOW, FIXED }
@export var camera_mode := CameraMode.FOLLOW
@export var camera_fixed_position := Vector2.ZERO  ## 固定模式时的世界坐标（V 切换时自动记录当前位）

var _camera_fixed_pos: Vector2  ## 实际使用的固定位置

enum State {
	NORMAL,
	JUMPING,
	ATTACKING,
	USING,
	DEFENDING,
	SITTING,
	DEAD
}

var _state := State.NORMAL
var _facing := Vector2.DOWN
var _attack_cooldown_timer := 0.0
var _current_attack_anim := ""
var _jump_elapsed := 0.0
var _jump_phase := 0
var _jump_cooldown_timer := 0.0
var _space_was_pressed := false
var _space_released_after_jump := false
var _normal_frames := 0
var _defence_timer := 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D2
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	animated_sprite.animation_finished.connect(_on_animation_finished)
	_camera_fixed_pos = global_position if camera_fixed_position == Vector2.ZERO else camera_fixed_position
	_apply_camera_mode()

func _physics_process(delta: float) -> void:
	_attack_cooldown_timer = maxf(0.0, _attack_cooldown_timer - delta)
	_jump_cooldown_timer = maxf(0.0, _jump_cooldown_timer - delta)

	if _state == State.NORMAL:
		_normal_frames += 1
	else:
		_normal_frames = 0

	if _state == State.DEFENDING:
		_defence_timer -= delta
		if _defence_timer <= 0:
			_state = State.NORMAL
		velocity.x = move_toward(velocity.x, 0, run_speed * delta * 3)
		velocity.y = move_toward(velocity.y, 0, run_speed * delta * 3)
		move_and_slide()
		return

	if _state == State.SITTING:
		velocity = Vector2.ZERO
		_handle_sit_input()
		move_and_slide()
		return

	var space_now := Input.is_key_pressed(KEY_SPACE)
	if not space_now:
		_space_released_after_jump = true
	if _state == State.NORMAL and _normal_frames >= 1 and space_now and not _space_was_pressed and _space_released_after_jump and _jump_cooldown_timer <= 0:
		_try_jump()
	_space_was_pressed = space_now

	## 相机模式在切换时已处理，此处无需每帧更新

	match _state:
		State.DEAD:
			return
		State.JUMPING:
			_process_jump(delta)
			return
		State.ATTACKING, State.USING:
			velocity.x = move_toward(velocity.x, 0, run_speed * delta * 3)
			velocity.y = move_toward(velocity.y, 0, run_speed * delta * 3)
			move_and_slide()
			return
		State.NORMAL:
			_handle_movement(delta)

func _handle_movement(delta: float) -> void:
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
		velocity = Vector2.ZERO  ## 松键立即停止，无滑动

	_record_path_if_needed(input_dir)
	move_and_slide()
	if _state == State.NORMAL:
		_update_animation(input_dir, is_running)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = (camera.zoom + Vector2(zoom_step, zoom_step)).clamp(Vector2(zoom_min, zoom_min), Vector2(zoom_max, zoom_max))
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = (camera.zoom - Vector2(zoom_step, zoom_step)).clamp(Vector2(zoom_min, zoom_min), Vector2(zoom_max, zoom_max))
		return

	if _state == State.DEAD:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_V:
				_toggle_camera_mode()
			KEY_J:
				_try_attack()
			KEY_I:
				_try_use_item()
			KEY_K:
				_try_defence()
			KEY_X:
				_try_toggle_sit()
			KEY_M:
				_try_death()

func _toggle_camera_mode() -> void:
	if camera_mode == CameraMode.FOLLOW:
		camera_mode = CameraMode.FIXED
		_camera_fixed_pos = global_position
	else:
		camera_mode = CameraMode.FOLLOW
	_apply_camera_mode()

func _apply_camera_mode() -> void:
	if camera_mode == CameraMode.FIXED:
		camera.reparent(get_parent())  ## 脱离角色，挂到场景根，彻底避免晃动
		camera.global_position = _camera_fixed_pos
	else:
		camera.reparent(self)
		camera.position = Vector2.ZERO

func _try_attack() -> void:
	if _state != State.NORMAL or _attack_cooldown_timer > 0:
		return
	_state = State.ATTACKING
	_current_attack_anim = "attractL"
	animated_sprite.flip_h = _facing.x > 0
	animated_sprite.play("attractL")
	_attack_cooldown_timer = attack_cooldown

func _try_use_item() -> void:
	if _state != State.NORMAL or _attack_cooldown_timer > 0:
		return
	_state = State.USING
	animated_sprite.flip_h = _facing.x > 0
	animated_sprite.play("item")
	_attack_cooldown_timer = attack_cooldown

func _try_defence() -> void:
	if _state != State.NORMAL or _attack_cooldown_timer > 0:
		return
	_state = State.DEFENDING
	_defence_timer = defence_duration
	animated_sprite.flip_h = _facing.x > 0
	animated_sprite.play("defence")
	_attack_cooldown_timer = attack_cooldown

func _try_toggle_sit() -> void:
	if _state == State.SITTING:
		_state = State.NORMAL
		return
	if _state != State.NORMAL or _attack_cooldown_timer > 0:
		return
	_state = State.SITTING
	velocity = Vector2.ZERO
	animated_sprite.flip_h = _facing.x > 0
	animated_sprite.play("sitdown")
	_attack_cooldown_timer = attack_cooldown

func _handle_sit_input() -> void:
	## 坐下时：X 起立在 _input 中处理（需释放后重按，避免误触）；移动键可起立
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_D):
		_state = State.NORMAL
		_attack_cooldown_timer = attack_cooldown

func _try_jump() -> void:
	_state = State.JUMPING
	_jump_elapsed = 0.0
	_jump_phase = 0
	_jump_cooldown_timer = jump_cooldown
	_space_released_after_jump = false
	animated_sprite.play("jump")
	animated_sprite.flip_h = _facing.x > 0

func _process_jump(delta: float) -> void:
	_handle_movement(delta)
	if _jump_phase == 2:
		return

	_jump_elapsed += delta
	if _jump_phase == 0:
		var t := clampf(_jump_elapsed / jump_ascent_duration, 0.0, 1.0)
		animated_sprite.offset.y = -jump_height * sin(t * PI / 2.0)
		if _jump_elapsed >= jump_ascent_duration:
			_jump_phase = 1
			_jump_elapsed = 0.0
	elif _jump_phase == 1:
		var t := clampf(_jump_elapsed / jump_fall_duration, 0.0, 1.0)
		animated_sprite.offset.y = -jump_height * (1.0 - t)
		if _jump_elapsed >= jump_fall_duration:
			_jump_phase = 2
			animated_sprite.offset.y = 0
			_state = State.NORMAL

func _try_death() -> void:
	if _state == State.DEAD:
		return
	_state = State.DEAD
	velocity = Vector2.ZERO
	animated_sprite.play("die")

func _on_animation_finished() -> void:
	var anim_name := animated_sprite.animation
	if anim_name == _current_attack_anim:
		_state = State.NORMAL
		_current_attack_anim = ""
	elif anim_name == "item":
		_state = State.NORMAL
	elif anim_name == "sitdown":
		animated_sprite.pause()  ## 保持最后一帧不动，直到按 X 起立

func _record_path_if_needed(input_dir: Vector2) -> void:
	var should_record := false
	if _path_positions.is_empty():
		should_record = true
	elif input_dir != Vector2.ZERO:
		should_record = global_position.distance_to(_path_positions[_path_positions.size() - 1]) >= PATH_RECORD_MIN_DISTANCE
	if should_record:
		_path_positions.append(global_position)
		_path_facings.append(input_dir if input_dir != Vector2.ZERO else (_path_facings.back() if _path_facings.size() > 0 else Vector2.DOWN))
		while _path_positions.size() > PATH_MAX_POINTS:
			_path_positions.pop_front()
			_path_facings.pop_front()

func get_point_at_path_distance(distance_back: float) -> Dictionary:
	if _path_positions.is_empty():
		return {"position": global_position, "facing": _facing}
	if _path_positions.size() == 1:
		return {"position": _path_positions[0], "facing": _path_facings[0] if _path_facings.size() > 0 else _facing}
	var remaining := distance_back
	var i := _path_positions.size() - 1
	while i > 0:
		var seg_len: float = _path_positions[i].distance_to(_path_positions[i - 1])
		if remaining <= seg_len and seg_len > 0.001:
			var t := 1.0 - remaining / seg_len
			var pos: Vector2 = _path_positions[i - 1].lerp(_path_positions[i], t)
			var face: Vector2 = _path_facings[i - 1] if i - 1 < _path_facings.size() else _facing
			return {"position": pos, "facing": face}
		remaining -= seg_len
		i -= 1
	return {"position": _path_positions[0], "facing": _path_facings[0] if _path_facings.size() > 0 else _facing}

func _update_animation(input_dir: Vector2, is_running: bool) -> void:
	if input_dir == Vector2.ZERO:
		var fax := absf(_facing.x)
		var fay := absf(_facing.y)
		if fay >= fax:
			animated_sprite.animation = "walkdown" if _facing.y > 0 else "walkup"
			animated_sprite.flip_h = false
		else:
			animated_sprite.animation = "idleL"
			animated_sprite.flip_h = _facing.x > 0
		animated_sprite.frame = 0
		animated_sprite.pause()
		return

	animated_sprite.play()
	var ax := absf(input_dir.x)
	var ay := absf(input_dir.y)
	if ay >= ax:
		if input_dir.y > 0:
			animated_sprite.animation = "rundown" if is_running else "walkdown"
			animated_sprite.flip_h = false
		else:
			animated_sprite.animation = "runup" if is_running else "walkup"
			animated_sprite.flip_h = false
	elif input_dir.x > 0:
		animated_sprite.animation = "runL" if is_running else "walkL"
		animated_sprite.flip_h = true
	else:
		animated_sprite.animation = "runL" if is_running else "walkL"
		animated_sprite.flip_h = false
