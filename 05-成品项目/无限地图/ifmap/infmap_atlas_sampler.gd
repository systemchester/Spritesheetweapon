class_name InfmapAtlasSampler
extends RefCounted
## 对应 blobTerrain.sampleBlobAtlas：按世界坐标在 Blob 图集子块内取色。

const COLS := 3
const ROWS := 24

var _img_water: Image
var _img_norm: Image
var _img_mtn: Image


func _init() -> void:
	_img_water = _load_rgba("res://ifmap/map/blob/frame_007.png")
	_img_norm = _load_rgba("res://ifmap/map/blob/frame_004.png")
	_img_mtn = _load_rgba("res://ifmap/map/blob/frame_001.png")


static func _load_rgba(path: String) -> Image:
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		push_error("InfmapAtlasSampler: missing texture %s" % path)
		var im := Image.create(3, 24, false, Image.FORMAT_RGBA8)
		im.fill(Color.MAGENTA)
		return im
	var im2: Image = tex.get_image()
	if im2 == null:
		var im3 := Image.create(3, 24, false, Image.FORMAT_RGBA8)
		im3.fill(Color.MAGENTA)
		return im3
	if im2.get_format() != Image.FORMAT_RGBA8:
		im2.convert(Image.FORMAT_RGBA8)
	return im2


static func _world_frac_in_tile(world: float, tile_world: float) -> float:
	return fposmod(world, tile_world) / tile_world


func sample(kind: String, sheet_index: int, wx: float, wz: float, tile_world: float) -> Color:
	var img: Image = _img_norm
	match kind:
		"water":
			img = _img_water
		"mtn":
			img = _img_mtn
		_:
			img = _img_norm
	var iw: int = img.get_width()
	var ih: int = img.get_height()
	var cell_w: int = iw / COLS
	var cell_h: int = ih / ROWS
	if cell_w < 1 or cell_h < 1:
		return Color.MAGENTA
	var col: int = sheet_index % COLS
	var row: int = sheet_index / COLS
	var u: int = mini(cell_w - 1, int(floor(_world_frac_in_tile(wx, tile_world) * float(cell_w))))
	var v: int = mini(cell_h - 1, int(floor(_world_frac_in_tile(wz, tile_world) * float(cell_h))))
	var px: int = col * cell_w + u
	var py: int = row * cell_h + v
	return img.get_pixel(px, py)
