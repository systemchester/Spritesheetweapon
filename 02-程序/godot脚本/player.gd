extends CharacterBody2D
## =============================================================================
## 主控角色 (Player)
## =============================================================================
## 俯视角 RPG 的主控角色控制器。
## 功能：
##   1. 方向键移动，使用 CharacterBody2D 的 move_and_slide
##   2. 仅在移动时记录路径点，供 Follower 按距离严格排队跟随
##   3. 提供 get_point_at_path_distance() 供跟随者获取目标位置
##   4. 支持鼠标滚轮缩放相机
## =============================================================================

@export var speed := 70.0  ## 移动速度（像素/秒）
@export var show_path_debug := false  ## 是否在场景中绘制路径线（调试用）
@export var zoom_min := 1.0  ## 相机最小缩放
@export var zoom_max := 6.0  ## 相机最大缩放
@export var zoom_step := 0.3  ## 每次滚轮缩放的步长

const PATH_RECORD_MIN_DISTANCE := 3.0  ## 移动超过此距离才记录新路径点，避免重复点堆积
const PATH_MAX_POINTS := 300  ## 路径最大点数，约 5 秒数据，超出时删除最早的

var _path_positions: Array[Vector2] = []  ## 历史位置数组，从旧到新
var _path_facings: Array[Vector2] = []   ## 与位置对应的朝向
var _path_line: Line2D  ## 调试用线段，仅在 show_path_debug 时创建

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D  ## 子节点：精灵动画
@onready var camera: Camera2D = $Camera2D  ## 子节点：2D 相机

## 处理输入事件：鼠标滚轮控制相机缩放
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = (camera.zoom + Vector2(zoom_step, zoom_step)).clamp(Vector2(zoom_min, zoom_min), Vector2(zoom_max, zoom_max))
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = (camera.zoom - Vector2(zoom_step, zoom_step)).clamp(Vector2(zoom_min, zoom_min), Vector2(zoom_max, zoom_max))

func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING  ## 俯视角必须用 FLOATING
	## 可选：创建 Line2D 用于调试显示路径
	if show_path_debug:
		_path_line = Line2D.new()
		_path_line.z_index = -10  ## 放在底层，不遮挡角色
		_path_line.default_color = Color(1, 1, 0, 0.5)
		_path_line.width = 2.0
		get_parent().add_child(_path_line)

func _physics_process(_delta: float) -> void:
	## 获取方向输入（支持手柄和键盘）
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	## 路径记录逻辑：仅在移动时且移动距离足够时才追加点，静止时不追加
	## 这样跟随者不会全部挤到同一位置
	var should_record := false
	if _path_positions.is_empty():
		should_record = true
	elif input_dir != Vector2.ZERO:
		should_record = global_position.distance_to(_path_positions[_path_positions.size() - 1]) >= PATH_RECORD_MIN_DISTANCE
	if should_record:
		_path_positions.append(global_position)
		## 静止时沿用上一个朝向
		_path_facings.append(input_dir if input_dir != Vector2.ZERO else (Vector2.DOWN if _path_facings.is_empty() else _path_facings[_path_facings.size() - 1]))
		while _path_positions.size() > PATH_MAX_POINTS:
			_path_positions.pop_front()
			_path_facings.pop_front()

	velocity = input_dir * speed
	move_and_slide()

	_update_animation(input_dir)
	_update_path_line()

## 根据输入方向切换动画（down/up/right）和水平翻转
func _update_animation(input_dir: Vector2) -> void:
	if input_dir == Vector2.ZERO:
		if not animated_sprite.animation.is_empty():
			animated_sprite.pause()
		return

	animated_sprite.play()

	if input_dir.y > 0:
		animated_sprite.animation = &"down"
		animated_sprite.flip_h = false
	elif input_dir.y < 0:
		animated_sprite.animation = &"up"
		animated_sprite.flip_h = false
	elif input_dir.x > 0:
		animated_sprite.animation = &"right"
		animated_sprite.flip_h = false
	elif input_dir.x < 0:
		animated_sprite.animation = &"right"
		animated_sprite.flip_h = true

## 调试用：把路径点连成线段显示
func _update_path_line() -> void:
	if _path_line and _path_positions.size() > 1:
		var pts: PackedVector2Array = PackedVector2Array()
		pts.resize(_path_positions.size())
		for i in _path_positions.size():
			pts[i] = _path_positions[i]
		_path_line.points = pts

## 获取路径上距末端 distance_back 像素处的点（位置 + 朝向）
## 跟随者调用此函数获取自己的目标位置，实现严格按路径排队
func get_point_at_path_distance(distance_back: float) -> Dictionary:
	if _path_positions.is_empty():
		return {"position": global_position, "facing": Vector2.DOWN}
	if _path_positions.size() == 1:
		return {"position": _path_positions[0], "facing": _path_facings[0] if _path_facings.size() > 0 else Vector2.DOWN}

	## 从路径末端往前累加距离，找到对应的线段
	var remaining := distance_back
	var i := _path_positions.size() - 1
	while i > 0:
		var seg_len: float = _path_positions[i].distance_to(_path_positions[i - 1])
		if remaining <= seg_len and seg_len > 0.001:
			## 在当前线段上线性插值得到精确位置
			var t := 1.0 - remaining / seg_len
			var pos: Vector2 = _path_positions[i - 1].lerp(_path_positions[i], t)
			var face: Vector2 = _path_facings[i - 1] if i - 1 < _path_facings.size() else Vector2.DOWN
			return {"position": pos, "facing": face}
		remaining -= seg_len
		i -= 1

	return {"position": _path_positions[0], "facing": _path_facings[0] if _path_facings.size() > 0 else Vector2.DOWN}
