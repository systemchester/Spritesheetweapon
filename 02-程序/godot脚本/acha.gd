extends CharacterBody2D
## =============================================================================
## Acha 角色控制器（俯视角 Top-Down）
## =============================================================================
##
## 【核心设计】
##   - 无重力、无地面：纯四向移动，Y 轴与 X 轴等效，适合俯视角 RPG
##   - 跳跃使用「伪 Z 轴」：仅通过 AnimatedSprite2D.offset.y 改变视觉高度，
##     碰撞体与 CharacterBody2D 位置不变，无需 Floor/StaticBody2D
##   - 状态机：NORMAL / JUMPING / ATTACKING / USING / DEAD，互斥切换
##   - 跳跃分三段：上升(jump_ascent) → 下落(jump_fall) → 落地(jump_land)
##
## 【操作键位】
##   WASD       - 四向移动（默认走路，按住 Shift 跑步）
##   空格       - 跳跃（视觉 hop）
##   鼠标滚轮   - 缩放视图
##   J          - 剑攻击（swdattrack，单次，按朝向偏移）
##   K          - 矛攻击（sprattract，单次，按朝向偏移）
##   I          - 使用道具（useitem，单次，按朝向翻转）
##   M          - 死亡（die）
##
## 【依赖节点】
##   $AnimatedSprite2D - 必须，含 walkdown/up/left、jump_ascent/fall/land、
##   $Camera2D         - 必须，子节点相机，滚轮缩放
##                       swdattrack、sprattract、useitem、die
## =============================================================================

## -----------------------------------------------------------------------------
## 导出参数（可在编辑器中调节）
## -----------------------------------------------------------------------------
@export var walk_speed := 30.0  ## 走路速度（像素/秒），无输入时按此速度减速
@export var run_speed := 70.0   ## 跑步速度，按住 Shift 时生效

@export var jump_height := 40.0  ## 伪 Z 轴：精灵上浮的最大像素数（offset.y 负值）
@export var jump_ascent_duration := 0.3  ## 上升时长（秒），对应 jump_ascent 帧 1-4
@export var jump_fall_duration := 0.45  ## 下落时长（秒），对应 jump_fall 帧 5
@export var jump_cooldown := 0.5  ## 跳跃冷却（秒），起跳后在此时间内无法再跳

@export var attack_cooldown := 0.4  ## 攻击/道具冷却（秒），防止连按
const ATTACK_OFFSET_X := -10.0  ## 攻击时精灵 X 偏移基准（朝左 -10，朝右 +10）

@export var zoom_min := 1.0  ## 相机最小缩放
@export var zoom_max := 6.0  ## 相机最大缩放
@export var zoom_step := 0.3  ## 每次滚轮缩放的步长

## -----------------------------------------------------------------------------
## 状态枚举与内部变量
## -----------------------------------------------------------------------------
## 状态转换：NORMAL ←→ JUMPING/ATTACKING/USING，DEAD 为终态
enum State {
	NORMAL,   ## 可移动、跳跃、攻击、使用道具
	JUMPING,  ## 播放跳跃三段动画，可移动，落地后回 NORMAL
	ATTACKING,## 播放攻击动画，减速至停，动画结束回 NORMAL
	USING,    ## 播放 useitem，减速至停，动画结束回 NORMAL
	DEAD      ## 停止输入与移动，播放 die
}

var _state := State.NORMAL
var _facing := Vector2.DOWN  ## 上次移动方向，用于 idle/攻击/道具的动画朝向
var _attack_cooldown_timer := 0.0  ## 攻击冷却剩余秒数
var _current_attack_anim := ""  ## 当前攻击动画名，animation_finished 时判断是否结束
var _jump_elapsed := 0.0  ## 当前跳跃阶段已过时间
var _jump_phase := 0  ## 0=上升 1=下落 2=落地
var _jump_cooldown_timer := 0.0  ## 跳跃冷却剩余秒数
var _space_was_pressed := false  ## 上一帧空格是否按下，用于「刚按下」检测
var _space_released_after_jump := false  ## 起跳后必须先释放空格，再按才可再跳
var _normal_frames := 0  ## 连续处于 NORMAL 的帧数，落地后需 ≥1 才允许跳

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING  ## 俯视角必须用 FLOATING

## -----------------------------------------------------------------------------
## 主循环 _physics_process
## -----------------------------------------------------------------------------
## 每物理帧调用，负责：冷却递减、跳跃输入检测、按状态分发到移动/跳跃/攻击逻辑
func _physics_process(delta: float) -> void:
	## 冷却计时器逐帧递减
	_attack_cooldown_timer = maxf(0.0, _attack_cooldown_timer - delta)
	_jump_cooldown_timer = maxf(0.0, _jump_cooldown_timer - delta)

	## _normal_frames：落地瞬间可能仍有输入残留，需至少 1 帧 NORMAL 才接受跳跃
	if _state == State.NORMAL:
		_normal_frames += 1
	else:
		_normal_frames = 0

	## 跳跃检测：在 _physics_process 中做「刚按下」判断，避免 _input 重复触发
	## 条件：NORMAL、至少 1 帧、空格刚按下、上次跳跃后已释放、冷却已过
	var space_now := Input.is_key_pressed(KEY_SPACE)
	if not space_now:
		_space_released_after_jump = true
	if _state == State.NORMAL and _normal_frames >= 1 and space_now and not _space_was_pressed and _space_released_after_jump and _jump_cooldown_timer <= 0:
		_try_jump()
	_space_was_pressed = space_now

	match _state:
		State.DEAD:
			return
		State.JUMPING:
			_process_jump(delta)
			return
		State.ATTACKING, State.USING:
			## 攻击/道具：velocity 向 0 靠拢，无重力，减速系数 run_speed*3
			velocity.x = move_toward(velocity.x, 0, run_speed * delta * 3)
			velocity.y = move_toward(velocity.y, 0, run_speed * delta * 3)
			move_and_slide()
			return
		State.NORMAL:
			_handle_movement(delta)

## -----------------------------------------------------------------------------
## 移动逻辑 _handle_movement
## -----------------------------------------------------------------------------
## 收集 WASD 输入，按 Shift 选择走路/跑步速度，有输入时设置 velocity，无输入时减速至 0
func _handle_movement(delta: float) -> void:
	## 收集四向输入，normalized 后用于方向和速度
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
		## 无输入时向 0 减速，系数 move_speed*4 使停顿较快
		velocity.x = move_toward(velocity.x, 0, move_speed * delta * 4)
		velocity.y = move_toward(velocity.y, 0, move_speed * delta * 4)

	move_and_slide()
	if _state == State.NORMAL:
		_update_animation(input_dir, is_running)

## -----------------------------------------------------------------------------
## 输入 _input
## -----------------------------------------------------------------------------
## 处理鼠标滚轮缩放、J/K/I/M。跳跃在 _physics_process 中检测。
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
			KEY_J:
				_try_sword_attack()
			KEY_K:
				_try_spear_attack()
			KEY_I:
				_try_use_item()
			KEY_M:
				_try_death()

## -----------------------------------------------------------------------------
## 攻击与道具
## -----------------------------------------------------------------------------
## 剑攻击：仅 NORMAL 且冷却已过时触发，播放 swdattrack，精灵按朝向偏移
func _try_sword_attack() -> void:
	if _state != State.NORMAL or _attack_cooldown_timer > 0:
		return
	_state = State.ATTACKING
	_current_attack_anim = "swdattrack"
	_apply_attack_offset()
	animated_sprite.play("swdattrack")
	_attack_cooldown_timer = attack_cooldown

## 矛攻击：逻辑同剑攻击，动画为 sprattract
func _try_spear_attack() -> void:
	if _state != State.NORMAL or _attack_cooldown_timer > 0:
		return
	_state = State.ATTACKING
	_current_attack_anim = "sprattract"
	_apply_attack_offset()
	animated_sprite.play("sprattract")
	_attack_cooldown_timer = attack_cooldown

## 攻击精灵偏移：朝左 flip_h=false、offset.x=-10；朝右 flip_h=true、offset.x=+10
## 因攻击贴图朝向与行走不同，需按 _facing 同时设置翻转与偏移
func _apply_attack_offset() -> void:
	animated_sprite.flip_h = _facing.x > 0
	animated_sprite.offset.x = ATTACK_OFFSET_X if _facing.x < 0 else -ATTACK_OFFSET_X

## 使用道具：播放 useitem，flip_h 与 walk/攻击相反（useitem 贴图绘制方向不同）
func _try_use_item() -> void:
	if _state != State.NORMAL or _attack_cooldown_timer > 0:
		return
	_state = State.USING
	animated_sprite.flip_h = _facing.x < 0  ## useitem 贴图方向与 walk 不同
	animated_sprite.play("useitem")
	_attack_cooldown_timer = attack_cooldown

## -----------------------------------------------------------------------------
## 跳跃逻辑
## -----------------------------------------------------------------------------
## 开始跳跃：切到 JUMPING，重置阶段与计时，播放 jump_ascent，锁定「须释放后才能再跳」
func _try_jump() -> void:
	_state = State.JUMPING
	_jump_elapsed = 0.0
	_jump_phase = 0
	_jump_cooldown_timer = jump_cooldown
	_space_released_after_jump = false
	animated_sprite.play("jump_ascent")
	animated_sprite.flip_h = _facing.x > 0  ## 与 walkleft 一致：朝右时翻转

## 跳跃每帧更新：仍调用 _handle_movement 以支持空中移动。三段 phase：
## 0=上升：offset.y 用 sin(t*PI/2) 从 0 到 -jump_height
## 1=下落：offset.y 用 (1-t) 从 -jump_height 线性回 0
## 2=落地：播 jump_land，由 animation_finished 切回 NORMAL
func _process_jump(delta: float) -> void:
	_handle_movement(delta)
	if _jump_phase == 2:
		return

	_jump_elapsed += delta
	if _jump_phase == 0:
		## 上升：t∈[0,1]，sin(t*PI/2) 从 0 单调增到 1，offset 从 0 到 -jump_height
		var t := clampf(_jump_elapsed / jump_ascent_duration, 0.0, 1.0)
		animated_sprite.offset.y = -jump_height * sin(t * PI / 2.0)
		if _jump_elapsed >= jump_ascent_duration:
			_jump_phase = 1
			_jump_elapsed = 0.0
			animated_sprite.play("jump_fall")
	elif _jump_phase == 1:
		## 下落：t 从 0 到 1，(1-t) 从 1 到 0，offset 从 -jump_height 到 0
		var t := clampf(_jump_elapsed / jump_fall_duration, 0.0, 1.0)
		animated_sprite.offset.y = -jump_height * (1.0 - t)
		if _jump_elapsed >= jump_fall_duration:
			_jump_phase = 2
			animated_sprite.offset.y = 0
			animated_sprite.play("jump_land")

## 死亡：切到 DEAD，速度置零，播 die
func _try_death() -> void:
	if _state == State.DEAD:
		return
	_state = State.DEAD
	velocity = Vector2.ZERO
	animated_sprite.play("die")

## -----------------------------------------------------------------------------
## 动画结束回调
## -----------------------------------------------------------------------------
## 攻击/道具/跳跃落地动画播完时，切回 NORMAL；攻击结束需重置 offset.x 避免残留
func _on_animated_sprite_2d_animation_finished() -> void:
	var anim_name := animated_sprite.animation
	if anim_name == _current_attack_anim:
		_state = State.NORMAL
		_current_attack_anim = ""
		animated_sprite.offset.x = 0.0
	elif anim_name == "useitem":
		_state = State.NORMAL
	elif anim_name == "jump_land" and _state == State.JUMPING:
		_state = State.NORMAL

## -----------------------------------------------------------------------------
## 动画更新 _update_animation
## -----------------------------------------------------------------------------
## 无输入：idle，按 _facing 选 walkdown/up/left 第一帧并 pause
## 有输入：按主方向选 walk/run 动画。右向无单独动画，复用 walkleft + flip_h。
## 主方向判定：|y|>=|x| 取上下，否则取左右，避免斜向时误判。
func _update_animation(input_dir: Vector2, is_running: bool) -> void:
	if input_dir == Vector2.ZERO:
		## 待机：用 _facing 的绝对值比较决定上下还是左右
		var fax := absf(_facing.x)
		var fay := absf(_facing.y)
		if fay >= fax:
			animated_sprite.animation = "walkdown" if _facing.y > 0 else "walkup"
			animated_sprite.flip_h = false
		else:
			animated_sprite.animation = "walkleft"
			animated_sprite.flip_h = _facing.x > 0  ## 朝右时翻转
		animated_sprite.frame = 0
		animated_sprite.pause()
		return

	animated_sprite.play()
	var ax := absf(input_dir.x)
	var ay := absf(input_dir.y)
	## 移动中：按主方向选动画，|y|>=|x| 判上下，否则判左右
	if ay >= ax:
		if input_dir.y > 0:
			animated_sprite.animation = "down" if is_running else "walkdown"
			animated_sprite.flip_h = false
		else:
			animated_sprite.animation = "up" if is_running else "walkup"
			animated_sprite.flip_h = false
	elif input_dir.x > 0:
		animated_sprite.animation = "left" if is_running else "walkleft"
		animated_sprite.flip_h = true
	else:
		animated_sprite.animation = "left" if is_running else "walkleft"
		animated_sprite.flip_h = false
