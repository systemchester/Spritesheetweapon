extends Node2D
## =============================================================================
## 自动路径移动器 (AutoPathMover)
## =============================================================================
## 沿 Path2D 曲线自动移动的节点，可作巡逻 NPC 或跟随目标。
## 提供 get_point_at_path_distance()，因此可被 Follower/OcchaFollower 跟随。
## 用法：
##   1. 在场景中添加 Path2D，用编辑器绘制路径
##   2. 将 AutoPathMover 作为 Path2D 的子节点，或设置 path_node 指向 Path2D
##   3. 可选：让 Follower 的 follow_target_path 指向本节点
## =============================================================================

@export var path_node: NodePath  ## 指向 Path2D，为空则使用父节点（要求父节点是 Path2D）
@export var speed := 70.0  ## 沿路径移动的速度（像素/秒）
@export var loop := true  ## 到达终点后是否从头循环

const PATH_RECORD_INTERVAL := 0.033
const PATH_MAX_POINTS := 300  ## 记录的路径点上限

var _path_positions: Array[Vector2] = []  ## 移动过的位置历史，供跟随者查询
var _path_facings: Array[Vector2] = []
var _progress := 0.0  ## 当前在路径上的进度（像素距离）
var _path: Path2D

@onready var _path_ref: Path2D = _get_path()

## 获取 Path2D 引用：优先 path_node，否则使用父节点
func _get_path() -> Path2D:
	if path_node.is_empty():
		var parent := get_parent()
		return parent as Path2D if parent is Path2D else null
	return get_node_or_null(path_node) as Path2D

func _ready() -> void:
	_path = _get_path()
	if not _path:
		push_error("AutoPathMover: 未找到 Path2D，请设置 path_node 或将本节点挂到 Path2D 下")
		return
	var curve: Curve2D = _path.curve
	if curve.get_point_count() < 2:
		push_error("AutoPathMover: Path2D 曲线至少需要 2 个点")
		return
	_position_at_progress(0.0)
	_path_positions.append(global_position)
	_path_facings.append(Vector2.DOWN)

func _physics_process(delta: float) -> void:
	if not _path:
		return

	var curve: Curve2D = _path.curve
	var length: float = curve.get_baked_length()
	if length <= 0.0:
		return

	_progress += speed * delta
	if loop and _progress >= length:
		_progress = fmod(_progress, length)
	elif not loop and _progress >= length:
		_progress = length

	var offset: float = clampf(_progress, 0.0, length)
	_position_at_progress(offset)

	## 记录路径供跟随者使用，逻辑与 Player 类似
	var cur_pos: Vector2 = global_position
	var prev_pos: Vector2 = _path_positions[-1] if _path_positions.size() > 0 else cur_pos
	var facing: Vector2 = (cur_pos - prev_pos).normalized() if cur_pos.distance_to(prev_pos) > 0.1 else (_path_facings[-1] if _path_facings.size() > 0 else Vector2.DOWN)

	if _path_positions.is_empty() or cur_pos.distance_to(_path_positions[_path_positions.size() - 1]) >= 3.0:
		_path_positions.append(cur_pos)
		_path_facings.append(facing)
		while _path_positions.size() > PATH_MAX_POINTS:
			_path_positions.pop_front()
			_path_facings.pop_front()

## 根据路径进度（像素距离）设置全局位置
func _position_at_progress(offset: float) -> void:
	var curve: Curve2D = _path.curve
	var local_pos: Vector2 = curve.sample_baked(offset)
	global_position = _path.to_global(local_pos)

## 供 Follower 调用：返回路径上距末端 distance_back 处的点
func get_point_at_path_distance(distance_back: float) -> Dictionary:
	if _path_positions.is_empty():
		return {"position": global_position, "facing": Vector2.DOWN}
	if _path_positions.size() == 1:
		return {"position": _path_positions[0], "facing": _path_facings[0] if _path_facings.size() > 0 else Vector2.DOWN}

	## 从末端往前累加距离，找到对应线段并插值
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
