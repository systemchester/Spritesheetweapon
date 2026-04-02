extends Node2D
## 地形加载：每帧 preloadTileAABB（包络 = 可见区 + TILE_WORLD*6*边距%）或兜底 preloadAroundTile（半径同比放大）。
## 流式卡顿常见原因：① 擦除预算远小于铺砖（场景里勿把 tiles_erase 设得过低）；② Camera2D smoothing 与流式中心不同步；
## ③ Blob chunk FIFO 误删视野内块导致反复 build_chunk。本脚本用玩家中心+缩放算包络、BlobWorld 命中块 LRU 提升。

const _BlobWorldScript := preload("res://ifmap/blob_world.gd")
const _TerrainPerspectiveShader := preload("res://ifmap/infmap_terrain_perspective.gdshader")

const TILE_WORLD_F := 24.0
const BLOB_COLS := 3
const BLOB_ROWS := 24

## 与 map.html / InfiniteMapScene 一致：滑条值 / 100 → seaLevel / mtnTh
const TERRAIN_SEA_MIN := 0
const TERRAIN_SEA_MAX := 58
const TERRAIN_MTN_MIN := 25
const TERRAIN_MTN_MAX := 75
const DEFAULT_SEA_PCT := 25
const DEFAULT_MTN_PCT := 56
const TEX_WATER := "res://ifmap/map/blob/frame_007.png"
const TEX_NORM := "res://ifmap/map/blob/frame_004.png"
const TEX_MTN := "res://ifmap/map/blob/frame_001.png"

@export var spawn_search_cheb_radius: int = 96
@export var tiles_paint_per_frame: int = 4000
@export var tiles_erase_per_frame: int = 8000
## 视窗包络相对上一帧平移超过此值（格）时整层重铺，避免异常大队列
@export var terrain_full_resync_tile_threshold: int = 96

@export_group("相机 Camera2D")
## 关闭：不每帧改相机，请在场景里选 Player/Camera2D 调 zoom、offset（人物默认在中心）。
## 开启：用下面参数覆盖相机，适合要在根节点 Inspector 里实时拖参。
@export var camera_apply_from_root: bool = false
@export var camera_zoom: Vector2 = Vector2(3.0, 3.0)
## 仅当「从根节点驱动相机」开启时生效。负 Y 会让角色在画面略偏下；想居中请用 (0,0)。
@export var camera_offset: Vector2 = Vector2.ZERO
@export_range(-18.0, 18.0, 0.1) var camera_rotation_degrees: float = 0.0
@export var camera_smoothing_enabled: bool = false

@export_group("流式加载范围（格数，以角色为中心）")
## 向北（远处，Y 更小）额外加载多少格。透视越强越要加大
@export_range(10, 200, 5) var terrain_load_north: int = 60
## 向南（近处，Y 更大）
@export_range(10, 200, 5) var terrain_load_south: int = 30
## 向左
@export_range(10, 200, 5) var terrain_load_left: int = 30
## 向右
@export_range(10, 200, 5) var terrain_load_right: int = 30

@export_group("地形透视")
## 关闭则清空 Terrain 材质（完全正交）
@export var terrain_perspective_enabled: bool = true
## 虚拟相机高度：越大整体透视越弱（像镜头拉远）
@export_range(100.0, 3000.0, 10.0) var terrain_persp_cam_height: float = 100.0
## 相机在玩家南方多远（世界单位）；保证近处可见 tile 也在相机「前方」
@export_range(50.0, 1500.0, 10.0) var terrain_persp_cam_dist: float = 200.0
## 深度乘数：越大远近反差越明显
@export_range(0.0, 3.0, 0.05) var terrain_persp_strength: float = 0.95
## 地图基础缩放：透视会整体缩小地图，拖大补回来让人物和地图匹配
@export_range(0.5, 5.0, 0.05) var terrain_persp_base_scale: float = 2.9
## 远景最小缩放
@export_range(0.02, 0.5, 0.01) var terrain_persp_s_min: float = 0.08
## 横向偏航
@export_range(-0.15, 0.15, 0.005) var terrain_persp_ground_skew: float = 0.0

var map_seed: String = "godot-infmap"
var sea_level: float = 0.25
var mtn_th: float = 0.56

var _world: RefCounted
var _tile_layer: TileMapLayer
var _player: CharacterBody2D
## 上一帧已铺好的世界格包络（含边距），与网页每帧 terrain AABB 一致；无效为 (1,0,1,0)
var _last_stream_bounds: Vector4i = Vector4i(1, 0, 1, 0)
var _terrain_force_full_resync: bool = true

var _placed_tiles: Dictionary = {}
var _pending_paint: Array[String] = []
var _pending_erase: Array[String] = []

var _src_water: int = -1
var _src_norm: int = -1
var _src_mtn: int = -1
var _terrain_perspective_mat: ShaderMaterial

@onready var _sea_slider: HSlider = get_node_or_null("UI/Panel/VBox/SeaSlider") as HSlider
@onready var _sea_value_label: Label = get_node_or_null("UI/Panel/VBox/SeaValueLabel") as Label
@onready var _mtn_slider: HSlider = get_node_or_null("UI/Panel/VBox/MtnSlider") as HSlider
@onready var _mtn_value_label: Label = get_node_or_null("UI/Panel/VBox/MtnValueLabel") as Label


func _ready() -> void:
	_world = _BlobWorldScript.new(map_seed)
	_sync_params_from_percent(DEFAULT_SEA_PCT, DEFAULT_MTN_PCT)
	_world.set_params(sea_level, mtn_th)
	_tile_layer = get_node_or_null("Terrain") as TileMapLayer
	if _tile_layer == null:
		_tile_layer = TileMapLayer.new()
		_tile_layer.name = "Terrain"
		_tile_layer.z_index = -10
		add_child(_tile_layer)
		move_child(_tile_layer, 0)
	_tile_layer.tile_set = _build_blob_tileset()
	_tile_layer.rendering_quadrant_size = 512
	_setup_terrain_perspective_material()
	_player = get_node_or_null("Player") as CharacterBody2D
	_setup_ui()
	var btn: Button = get_node_or_null("UI/Panel/VBox/ReSeedButton") as Button
	if btn:
		btn.pressed.connect(_reseed_random)
	if _player:
		_place_player_spawn()
	_sync_camera_from_exports()
	_terrain_force_full_resync = true
	_last_stream_bounds = Vector4i(1, 0, 1, 0)


func _sync_params_from_percent(sea_pct: int, mtn_pct: int) -> void:
	var sp: int = clampi(sea_pct, TERRAIN_SEA_MIN, TERRAIN_SEA_MAX)
	var mp: int = clampi(mtn_pct, TERRAIN_MTN_MIN, TERRAIN_MTN_MAX)
	sea_level = sp / 100.0
	mtn_th = mp / 100.0


func _setup_ui() -> void:
	if _sea_slider:
		_sea_slider.min_value = TERRAIN_SEA_MIN
		_sea_slider.max_value = TERRAIN_SEA_MAX
		_sea_slider.step = 1
		_sea_slider.value = DEFAULT_SEA_PCT
		_sea_slider.value_changed.connect(_on_sea_slider_changed)
		_update_sea_label(int(_sea_slider.value))
	if _mtn_slider:
		_mtn_slider.min_value = TERRAIN_MTN_MIN
		_mtn_slider.max_value = TERRAIN_MTN_MAX
		_mtn_slider.step = 1
		_mtn_slider.value = DEFAULT_MTN_PCT
		_mtn_slider.value_changed.connect(_on_mtn_slider_changed)
		_update_mtn_label(int(_mtn_slider.value))


func _update_sea_label(pct: int) -> void:
	if _sea_value_label:
		_sea_value_label.text = "海平面（水域比例） %.2f" % (pct / 100.0)


func _update_mtn_label(pct: int) -> void:
	if _mtn_value_label:
		_mtn_value_label.text = "山地阈值 %.2f" % (pct / 100.0)


func _on_sea_slider_changed(v: float) -> void:
	var pct := int(round(v))
	_update_sea_label(pct)
	_apply_terrain_params_soft()


func _on_mtn_slider_changed(v: float) -> void:
	var pct := int(round(v))
	_update_mtn_label(pct)
	_apply_terrain_params_soft()




func _apply_terrain_params_soft() -> void:
	if _world == null:
		return
	var sp: int = int(_sea_slider.value) if _sea_slider else DEFAULT_SEA_PCT
	var mp: int = int(_mtn_slider.value) if _mtn_slider else DEFAULT_MTN_PCT
	_sync_params_from_percent(sp, mp)
	_world.set_params(sea_level, mtn_th)
	_world.clear_cache()
	_soft_redraw_visible_window()


func get_blob_world() -> RefCounted:
	return _world


func get_tile_world() -> float:
	return TILE_WORLD_F


func is_pos_walkable(p: Vector2) -> bool:
	var tx := int(floor(p.x / TILE_WORLD_F))
	var ty := int(floor(p.y / TILE_WORLD_F))
	return _BlobWorldScript.is_blob_tile_walkable(_world, tx, ty)


func _build_blob_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(int(TILE_WORLD_F), int(TILE_WORLD_F))
	_src_water = _add_blob_atlas_source(ts, load(TEX_WATER) as Texture2D)
	_src_norm = _add_blob_atlas_source(ts, load(TEX_NORM) as Texture2D)
	_src_mtn = _add_blob_atlas_source(ts, load(TEX_MTN) as Texture2D)
	return ts


func _add_blob_atlas_source(ts: TileSet, tex: Texture2D) -> int:
	if tex == null:
		push_error("infmap: missing blob texture")
		return -1
	var iw: int = tex.get_width()
	var ih: int = tex.get_height()
	var cw: int = int(floor(float(iw) / float(BLOB_COLS)))
	var ch: int = int(floor(float(ih) / float(BLOB_ROWS)))
	if cw < 1 or ch < 1:
		push_error("infmap: invalid blob atlas size")
		return -1
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(cw, ch)
	for row in BLOB_ROWS:
		for col in BLOB_COLS:
			src.create_tile(Vector2i(col, row))
	return ts.add_source(src)


func _place_player_spawn() -> void:
	var w: Variant = _BlobWorldScript.find_walkable_tile_center(
		_world, 0, 0, spawn_search_cheb_radius, TILE_WORLD_F
	)
	if w is Vector2:
		_player.position = w
	else:
		_player.position = Vector2(TILE_WORLD_F * 2.0, TILE_WORLD_F * 2.0)


func _clear_terrain_visual() -> void:
	if _tile_layer:
		_tile_layer.clear()
	_placed_tiles.clear()
	_pending_paint.clear()
	_pending_erase.clear()


func _soft_redraw_visible_window() -> void:
	if _tile_layer == null or _player == null:
		return
	_clear_terrain_visual()
	_last_stream_bounds = Vector4i(1, 0, 1, 0)
	_terrain_force_full_resync = true


## 透视缩放：复刻 shader 的 s(wy) = bs * ch / (ch + max(cd + py - wy, 0) * st)
func _persp_scale_at(wy: float, py: float) -> float:
	var z: float = terrain_persp_cam_dist + (py - wy)
	return terrain_persp_base_scale * terrain_persp_cam_height / (terrain_persp_cam_height + maxf(z, 0.0) * terrain_persp_strength)


## 反算屏幕边缘对应的世界坐标，考虑透视变形。
## 屏幕 top 对应的世界 y 满足 (py - wy) * s(wy) = half_h，迭代求解。
func _visible_ground_tile_bounds_web() -> Vector4i:
	if _player == null:
		return Vector4i(1, 0, 1, 0)
	var vp := get_viewport()
	if vp == null:
		return Vector4i(1, 0, 1, 0)
	var vs: Vector2 = vp.get_visible_rect().size
	var zoom: Vector2 = Vector2(1.0, 1.0)
	var cam: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		zoom = cam.zoom
	var half_w: float = (vs.x / zoom.x) * 0.5
	var half_h: float = (vs.y / zoom.y) * 0.5
	var px: float = _player.global_position.x
	var py: float = _player.global_position.y

	var pad_n: float = float(terrain_load_north) * TILE_WORLD_F
	var pad_s: float = float(terrain_load_south) * TILE_WORLD_F
	var pad_l: float = float(terrain_load_left) * TILE_WORLD_F
	var pad_r: float = float(terrain_load_right) * TILE_WORLD_F

	if not terrain_perspective_enabled or _terrain_perspective_mat == null:
		return Vector4i(
			int(floor((px - half_w - pad_l) / TILE_WORLD_F)),
			int(floor((px + half_w + pad_r) / TILE_WORLD_F)),
			int(floor((py - half_h - pad_n) / TILE_WORLD_F)),
			int(floor((py + half_h + pad_s) / TILE_WORLD_F)))

	# --- 透视感知 ---
	var s0: float = _persp_scale_at(py, py)

	# 北边（屏幕顶）：(py - wy) * s(wy) = half_h → wy = py - half_h / s(wy)
	var wy_n: float = py - half_h / maxf(s0, 0.01)
	for _i in 6:
		wy_n = py - half_h / maxf(_persp_scale_at(wy_n, py), 0.01)

	# 南边（屏幕底）：(wy - py) * s(wy) = half_h → wy = py + half_h / s(wy)
	var wy_s: float = py + half_h / maxf(s0, 0.01)
	for _i in 6:
		wy_s = py + half_h / maxf(_persp_scale_at(wy_s, py), 0.01)

	# 水平：用北边的 s（最小）算最宽需求
	var s_north: float = maxf(_persp_scale_at(wy_n, py), 0.01)
	var wx_half: float = half_w / s_north

	# 加 padding，clamp 每方向最多 250 格防止极端参数导致巨量 tile
	var ptx: int = int(floor(px / TILE_WORLD_F))
	var pty: int = int(floor(py / TILE_WORLD_F))
	var tix0: int = maxi(int(floor((px - wx_half - pad_l) / TILE_WORLD_F)), ptx - 250)
	var tix1: int = mini(int(floor((px + wx_half + pad_r) / TILE_WORLD_F)), ptx + 250)
	var tiy0: int = maxi(int(floor((wy_n - pad_n) / TILE_WORLD_F)), pty - 250)
	var tiy1: int = mini(int(floor((wy_s + pad_s) / TILE_WORLD_F)), pty + 250)
	return Vector4i(tix0, tix1, tiy0, tiy1)


func _setup_terrain_perspective_material() -> void:
	if _tile_layer == null:
		return
	if not terrain_perspective_enabled:
		_tile_layer.material = null
		_terrain_perspective_mat = null
		return
	## 若场景里已为 Terrain 指定了本 Shader 的 ShaderMaterial，则沿用（方便编辑器里手动挂材质）
	var existing: ShaderMaterial = _tile_layer.material as ShaderMaterial
	if existing != null and existing.shader != null:
		var pth: String = existing.shader.resource_path
		if pth == "res://ifmap/infmap_terrain_perspective.gdshader" or existing.shader == _TerrainPerspectiveShader:
			_terrain_perspective_mat = existing
			return
	_terrain_perspective_mat = ShaderMaterial.new()
	_terrain_perspective_mat.shader = _TerrainPerspectiveShader
	_tile_layer.material = _terrain_perspective_mat


func _sync_camera_from_exports() -> void:
	if not camera_apply_from_root or _player == null:
		return
	var cam: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.zoom = camera_zoom
	cam.offset = camera_offset
	cam.rotation_degrees = camera_rotation_degrees
	cam.position_smoothing_enabled = camera_smoothing_enabled


func _update_terrain_perspective_uniforms() -> void:
	if _terrain_perspective_mat == null or _player == null:
		return
	var p: Vector2 = _player.global_position
	var m: ShaderMaterial = _terrain_perspective_mat
	m.set_shader_parameter("pivot_world", p)
	m.set_shader_parameter("cam_height", terrain_persp_cam_height)
	m.set_shader_parameter("cam_dist", terrain_persp_cam_dist)
	m.set_shader_parameter("strength", terrain_persp_strength)
	m.set_shader_parameter("base_scale", terrain_persp_base_scale)
	m.set_shader_parameter("s_min", terrain_persp_s_min)
	m.set_shader_parameter("ground_skew", terrain_persp_ground_skew)


func _tile_rect_nonempty(r: Vector4i) -> bool:
	return r.x <= r.y and r.z <= r.w


## 对齐 gameLoop 中 preloadAroundTile 兜底用的范围（用于包络无效时铺砖）
func _fallback_tile_bounds() -> Vector4i:
	var tcx := int(floor(_player.position.x / TILE_WORLD_F))
	var tcy := int(floor(_player.position.y / TILE_WORLD_F))
	return Vector4i(tcx - terrain_load_left, tcx + terrain_load_right, tcy - terrain_load_north, tcy + terrain_load_south)


func _terrain_bounds_for_frame() -> Vector4i:
	var vb: Vector4i = _visible_ground_tile_bounds_web()
	if _tile_rect_nonempty(vb):
		return vb
	return _fallback_tile_bounds()


func _process(_delta: float) -> void:
	if _player == null or _world == null:
		return
	_sync_camera_from_exports()
	_update_terrain_perspective_uniforms()
	var b: Vector4i = _terrain_bounds_for_frame()
	var vb_ok: bool = _tile_rect_nonempty(_visible_ground_tile_bounds_web())
	if vb_ok:
		_world.preload_tile_aabb(b.x, b.y, b.z, b.w)
	else:
		var tcx := int(floor(_player.position.x / TILE_WORLD_F))
		var tcy := int(floor(_player.position.y / TILE_WORLD_F))
		var rad: int = maxi(maxi(terrain_load_north, terrain_load_south), maxi(terrain_load_left, terrain_load_right))
		_world.preload_around_tile(tcx, tcy, rad)

	if _terrain_force_full_resync:
		_full_terrain_resync_to_bounds(b)
		_terrain_force_full_resync = false
	else:
		_incremental_terrain_sync(b)

	_drain_erase_queue()
	_drain_paint_queue_budgeted()


func _full_terrain_resync_to_bounds(b: Vector4i) -> void:
	if not _tile_rect_nonempty(b) or _tile_layer == null:
		return
	_tile_layer.clear()
	_placed_tiles.clear()
	_pending_erase.clear()
	_pending_paint.clear()
	_last_stream_bounds = b
	_enqueue_paint_rect(b.x, b.y, b.z, b.w)
	_sort_paint_queue_by_distance()
	_drain_paint_queue_all()


func _incremental_terrain_sync(b: Vector4i) -> void:
	if not _tile_rect_nonempty(b) or _tile_layer == null:
		return
	if not _tile_rect_nonempty(_last_stream_bounds):
		_full_terrain_resync_to_bounds(b)
		return
	var o: Vector4i = _last_stream_bounds
	if o.x == b.x and o.y == b.y and o.z == b.z and o.w == b.w:
		return
	var max_edge_delta: int = maxi(
		maxi(absi(b.x - o.x), absi(b.y - o.y)),
		maxi(absi(b.z - o.z), absi(b.w - o.w)),
	)
	if max_edge_delta > maxi(8, terrain_full_resync_tile_threshold):
		_full_terrain_resync_to_bounds(b)
		return
	_strip_pending_paint_outside(b)
	for ty in range(o.z, o.w + 1):
		for tx in range(o.x, o.y + 1):
			if tx >= b.x and tx <= b.y and ty >= b.z and ty <= b.w:
				continue
			var ks: String = "%d,%d" % [tx, ty]
			if _placed_tiles.has(ks):
				_pending_erase.append(ks)
	for ty in range(b.z, b.w + 1):
		for tx in range(b.x, b.y + 1):
			if tx >= o.x and tx <= o.y and ty >= o.z and ty <= o.w:
				continue
			var ks2: String = "%d,%d" % [tx, ty]
			if not _placed_tiles.has(ks2):
				_pending_paint.append(ks2)
	_last_stream_bounds = b
	_sort_paint_queue_by_distance()


func _strip_pending_paint_outside(b: Vector4i) -> void:
	if not _tile_rect_nonempty(b):
		return
	var kept: Array[String] = []
	for k in _pending_paint:
		var parts: PackedStringArray = String(k).split(",")
		var tx: int = parts[0].to_int()
		var ty: int = parts[1].to_int()
		if tx >= b.x and tx <= b.y and ty >= b.z and ty <= b.w:
			kept.append(str(k))
	_pending_paint = kept


func _enqueue_paint_rect(tx0: int, tx1: int, ty0: int, ty1: int) -> void:
	for ty in range(ty0, ty1 + 1):
		for tx in range(tx0, tx1 + 1):
			_pending_paint.append("%d,%d" % [tx, ty])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_reseed_random()


func _random_seed_string() -> String:
	var part_a := ""
	const alphabet := "abcdefghijklmnopqrstuvwxyz0123456789"
	for _i in 9:
		part_a += alphabet[randi() % alphabet.length()]
	return "w%s%d" % [part_a, Time.get_ticks_msec()]


func _reseed_random() -> void:
	if _world == null or _player == null:
		return
	map_seed = _random_seed_string()
	_world.reseed(map_seed)
	var sp: int = int(_sea_slider.value) if _sea_slider else DEFAULT_SEA_PCT
	var mp: int = int(_mtn_slider.value) if _mtn_slider else DEFAULT_MTN_PCT
	_sync_params_from_percent(sp, mp)
	_world.set_params(sea_level, mtn_th)
	_clear_terrain_visual()
	_last_stream_bounds = Vector4i(1, 0, 1, 0)
	_terrain_force_full_resync = true
	var ox := int(floor(_player.position.x / TILE_WORLD_F))
	var oz := int(floor(_player.position.y / TILE_WORLD_F))
	var w: Variant = _BlobWorldScript.find_walkable_tile_center(_world, ox, oz, 260, TILE_WORLD_F)
	if w == null:
		w = _BlobWorldScript.find_walkable_tile_center(_world, 0, 0, 400, TILE_WORLD_F)
	if w is Vector2:
		_player.position = w


func _drain_erase_queue() -> void:
	if _tile_layer == null:
		return
	var budget: int = maxi(1, tiles_erase_per_frame)
	while budget > 0 and not _pending_erase.is_empty():
		var k: String = _pending_erase.pop_front()
		if not _placed_tiles.has(k):
			budget -= 1
			continue
		var parts: PackedStringArray = k.split(",")
		_tile_layer.erase_cell(Vector2i(parts[0].to_int(), parts[1].to_int()))
		_placed_tiles.erase(k)
		budget -= 1


func _drain_paint_queue_budgeted() -> void:
	_drain_paint_queue_inner(maxi(1, tiles_paint_per_frame))


func _drain_paint_queue_all() -> void:
	_drain_paint_queue_inner(1 << 28)


func _sort_paint_queue_by_distance() -> void:
	if _player == null or _pending_paint.size() < 2:
		return
	var pcx: float = _player.global_position.x / TILE_WORLD_F
	var pcy: float = _player.global_position.y / TILE_WORLD_F
	_pending_paint.sort_custom(func(a: String, b: String) -> bool:
		var pa: PackedStringArray = a.split(",")
		var pb: PackedStringArray = b.split(",")
		var da: float = absf(pa[0].to_float() - pcx) + absf(pa[1].to_float() - pcy)
		var db: float = absf(pb[0].to_float() - pcx) + absf(pb[1].to_float() - pcy)
		return da < db
	)


func _drain_paint_queue_inner(budget: int) -> void:
	if _tile_layer == null or _pending_paint.is_empty():
		return
	while budget > 0 and not _pending_paint.is_empty():
		var k: String = _pending_paint.pop_front()
		if _placed_tiles.has(k):
			budget -= 1
			continue
		var parts: PackedStringArray = k.split(",")
		var tx: int = parts[0].to_int()
		var ty: int = parts[1].to_int()
		_paint_tile(tx, ty)
		_placed_tiles[k] = true
		budget -= 1


func _paint_tile(tx: int, ty: int) -> void:
	var samp: Dictionary = _world.sample_tile_index(tx, ty)
	var kind: String = str(samp.get("kind", "norm"))
	var idx: int = int(samp.get("sheet_index", 4))
	var sid: int = _src_norm
	match kind:
		"water":
			sid = _src_water
		"mtn":
			sid = _src_mtn
		_:
			sid = _src_norm
	if sid < 0:
		return
	var col: int = idx % BLOB_COLS
	var row: int = int(floor(float(idx) / float(BLOB_COLS)))
	_tile_layer.set_cell(Vector2i(tx, ty), sid, Vector2i(col, row))
