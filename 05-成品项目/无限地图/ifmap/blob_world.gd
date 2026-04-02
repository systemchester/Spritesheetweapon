class_name BlobWorld
extends RefCounted
## 与 infiniteMap/blobTerrain.ts 对齐：Perlin/FBM、32×32 Chunk、掩码→图集下标、可走判定。

const BLOB_TILE_COLS := 3
const BLOB_TILE_ROWS := 24
const BLOB_CHUNK_SIZE := 32
const MAX_CACHED_CHUNKS := 1024

const IMG_MTN := 0
const IMG_NORM := 1

const LAND_SCALE := 26.0
const LAND_OCTAVES := 3
const MOUNTAIN_SCALE := 42.0
const MOUNTAIN_OCTAVES := 3
const RIVER_SCALE := 12.5
const RIVER_OCTAVES := 2
const RIVER_ABS_THRESH := 0.1
const RIVER_HEIGHT_BAND := 0.16

const FORBIDDEN_TILE_INDEX := 71
const FALLBACK_TILE_INDEX := 4

const MASK_TO_INDEX: Dictionary = {
	0: 13, 208: 0, 248: 1, 104: 2, 214: 3, 255: 4, 107: 5, 22: 6, 31: 7, 11: 8,
	80: 9, 24: 10, 72: 11, 66: 12, 18: 15, 10: 17, 64: 19, 16: 21, 90: 22, 8: 23,
	2: 25, 88: 28, 82: 30, 74: 32, 26: 34, 95: 37, 123: 39, 222: 41, 250: 43,
	127: 45, 223: 46, 251: 48, 254: 49, 86: 51, 75: 52, 210: 54, 106: 55, 120: 57,
	216: 58, 27: 60, 30: 61, 218: 63, 122: 64, 94: 66, 91: 67, 126: 69, 219: 70,
}

static var _mask_keys: Array = []


static func _ensure_mask_keys() -> void:
	if not _mask_keys.is_empty():
		return
	_mask_keys = MASK_TO_INDEX.keys()
	_mask_keys.sort()


var sea_level: float = 0.42
var mtn_th: float = 0.48

var _perm_h: PackedByteArray
var _perm_s4: PackedByteArray
var _perm_river: PackedByteArray

var _chunk_cache: Dictionary = {} # key -> ChunkData
var _chunk_queue: Array[String] = []


class ChunkData:
	var land: PackedByteArray
	var biome: PackedByteArray


func _init(seed_str: String) -> void:
	var base := string_seed_to_u32(seed_str.strip_edges() if seed_str else "default")
	_perm_h = _build_perm(base)
	_perm_s4 = _build_perm(base ^ 0x414004)
	_perm_river = _build_perm(base ^ 0x927b51c1)


func clear_cache() -> void:
	_chunk_cache.clear()
	_chunk_queue.clear()


func set_params(p_sea: float, p_mtn: float) -> void:
	sea_level = p_sea
	mtn_th = p_mtn


func reseed(seed_str: String) -> void:
	var base := string_seed_to_u32(seed_str.strip_edges() if seed_str else "default")
	_perm_h = _build_perm(base)
	_perm_s4 = _build_perm(base ^ 0x414004)
	_perm_river = _build_perm(base ^ 0x927b51c1)
	clear_cache()


static func string_seed_to_u32(s: String) -> int:
	var h: int = 2166136261
	for i in s.length():
		h = h ^ s.unicode_at(i)
		h = (h * 16777619) & 0xffffffff
	return h & 0xffffffff


static func _u32(n: int) -> int:
	return n & 0xffffffff


static func _imul32(a: int, b: int) -> int:
	var p: int = (_u32(a) * _u32(b)) & 0xffffffff
	if p >= 0x80000000:
		return p - 0x100000000
	return p


static func _build_perm(perm_seed: int) -> PackedByteArray:
	var a: int = _u32(perm_seed ^ 0x9e3779b9)
	var p_init: Array[int] = []
	p_init.resize(256)
	for i in 256:
		p_init[i] = i
	for i in range(255, 0, -1):
		a = _u32(a + 0x6d2b79f5)
		var t: int = _imul32(a ^ (a >> 15), a | 1)
		t = t ^ _u32(t + _imul32(t ^ (t >> 7), t | 61))
		var rf: float = float(_u32(t ^ (t >> 14))) / 4294967296.0
		var j: int = int(floor(rf * float(i + 1)))
		var tmp: int = p_init[i]
		p_init[i] = p_init[j]
		p_init[j] = tmp
	var perm := PackedByteArray()
	perm.resize(512)
	for i in 256:
		var v: int = p_init[i]
		perm[i] = v
		perm[i + 256] = v
	return perm


static func _fade(t: float) -> float:
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


static func _lerp(a: float, b: float, t: float) -> float:
	return a + t * (b - a)


static func _grad2(h: int, x: float, y: float) -> float:
	var hh: int = h & 3
	var u: float = x if hh < 2 else y
	var v: float = y if hh < 2 else x
	var sgn_u: float = -1.0 if (hh & 1) != 0 else 1.0
	var sgn_v: float = -1.0 if (hh & 2) != 0 else 1.0
	return sgn_u * u + sgn_v * v


func _noise2d(perm: PackedByteArray, x: float, y: float) -> float:
	var X: int = int(floor(x)) & 255
	var Y: int = int(floor(y)) & 255
	var xf: float = x - floor(x)
	var yf: float = y - floor(y)
	var u: float = _fade(xf)
	var v: float = _fade(yf)
	var aa: int = perm[X + perm[Y]]
	var ab: int = perm[X + perm[Y + 1]]
	var ba: int = perm[X + 1 + perm[Y]]
	var bb: int = perm[X + 1 + perm[Y + 1]]
	var x1: float = _lerp(_grad2(aa, xf, yf), _grad2(ba, xf - 1.0, yf), u)
	var x2: float = _lerp(_grad2(ab, xf, yf - 1.0), _grad2(bb, xf - 1.0, yf - 1.0), u)
	return _lerp(x1, x2, v)


func _fbm2d(perm: PackedByteArray, x: float, y: float, octaves: int, persistence: float, lacunarity: float) -> float:
	var sum: float = 0.0
	var amp: float = 1.0
	var freq: float = 1.0
	var norm: float = 0.0
	for _i in octaves:
		sum += amp * _noise2d(perm, x * freq, y * freq)
		norm += amp
		amp *= persistence
		freq *= lacunarity
	return sum / norm


static func _clamp01(v: float) -> float:
	return clampf(v, 0.0, 1.0)


static func _pop8(n: int) -> int:
	n &= 255
	var c: int = 0
	while n != 0:
		c += n & 1
		n = (n >> 1) & 0xff
	return c


static func nearest_blob_tile_index(mask: int) -> int:
	_ensure_mask_keys()
	mask &= 255
	if MASK_TO_INDEX.has(mask):
		var d0: Variant = MASK_TO_INDEX[mask]
		if d0 != FORBIDDEN_TILE_INDEX:
			return int(d0)
	var best_key: int = int(_mask_keys[0])
	var best_d: int = 99
	for k in _mask_keys:
		var kk: int = int(k)
		var v: Variant = MASK_TO_INDEX[kk]
		if v == FORBIDDEN_TILE_INDEX:
			continue
		var d: int = _pop8(mask ^ kk)
		if d < best_d:
			best_d = d
			best_key = kk
	var out: Variant = MASK_TO_INDEX.get(best_key)
	if out == null or out == FORBIDDEN_TILE_INDEX:
		return FALLBACK_TILE_INDEX
	return int(out)


static func compute_blob_mask(tx: int, ty: int, pred: Callable) -> int:
	var has := func(dx: int, dy: int) -> bool:
		return pred.call(tx + dx, ty + dy)
	var n: bool = has.call(0, -1)
	var s: bool = has.call(0, 1)
	var w: bool = has.call(-1, 0)
	var e: bool = has.call(1, 0)
	var mask: int = 0
	if n:
		mask += 2
	if s:
		mask += 64
	if w:
		mask += 8
	if e:
		mask += 16
	if n and w and has.call(-1, -1):
		mask += 1
	if n and e and has.call(1, -1):
		mask += 4
	if s and w and has.call(-1, 1):
		mask += 32
	if s and e and has.call(1, 1):
		mask += 128
	return mask


func _build_chunk(cx: int, cy: int) -> ChunkData:
	var land := PackedByteArray()
	var biome := PackedByteArray()
	land.resize(BLOB_CHUNK_SIZE * BLOB_CHUNK_SIZE)
	biome.resize(BLOB_CHUNK_SIZE * BLOB_CHUNK_SIZE)
	for ly in BLOB_CHUNK_SIZE:
		for lx in BLOB_CHUNK_SIZE:
			var wx: int = cx * BLOB_CHUNK_SIZE + lx
			var wy: int = cy * BLOB_CHUNK_SIZE + ly
			var i: int = ly * BLOB_CHUNK_SIZE + lx
			var raw: float = _fbm2d(_perm_h, wx / LAND_SCALE, wy / LAND_SCALE, LAND_OCTAVES, 0.52, 2.05)
			var h01: float = _clamp01((raw + 1.0) * 0.5)
			var rv: float = _fbm2d(
				_perm_river,
				wx / RIVER_SCALE + 31.4,
				wy / RIVER_SCALE + 12.8,
				RIVER_OCTAVES,
				0.48,
				2.02,
			)
			var river_corridor: bool = absf(rv) < RIVER_ABS_THRESH
			var low_enough_for_river: bool = h01 < sea_level + RIVER_HEIGHT_BAND
			var is_lake_or_sea: bool = h01 <= sea_level
			var is_river: bool = river_corridor and low_enough_for_river and not is_lake_or_sea
			var is_water: bool = is_lake_or_sea or is_river
			land[i] = 0 if is_water else 1
			if is_water:
				biome[i] = 0
				continue
			var u: float = (_fbm2d(_perm_s4, wx / MOUNTAIN_SCALE + 2.7, wy / MOUNTAIN_SCALE + 1.1, MOUNTAIN_OCTAVES, 0.5, 2.02) + 1.0) * 0.5
			biome[i] = IMG_MTN if u > mtn_th else IMG_NORM
	var ch := ChunkData.new()
	ch.land = land
	ch.biome = biome
	return ch


func ensure_chunk(cx: int, cy: int) -> ChunkData:
	var key := "%d,%d" % [cx, cy]
	if _chunk_cache.has(key):
		## LRU：命中则移到队尾，避免仍落在 preload 矩形内的块被 FIFO 误删后整块重建卡顿
		var qi: int = _chunk_queue.find(key)
		if qi >= 0:
			_chunk_queue.remove_at(qi)
			_chunk_queue.append(key)
		return _chunk_cache[key]
	var ch: ChunkData = _build_chunk(cx, cy)
	_chunk_cache[key] = ch
	_chunk_queue.append(key)
	while _chunk_queue.size() > MAX_CACHED_CHUNKS:
		var old: String = _chunk_queue.pop_front()
		_chunk_cache.erase(old)
	return ch


## 仅当该 Blob 块尚未缓存时创建；用于分帧预载。
func ensure_chunk_if_absent(cx: int, cy: int) -> bool:
	var key := "%d,%d" % [cx, cy]
	if _chunk_cache.has(key):
		return false
	ensure_chunk(cx, cy)
	return true


## 与 blobTerrain.preloadTileAABB 一致：仅预加载视野内地块包络（世界格索引），chunk 侧再加 2 格边距。
func preload_tile_aabb(tix0: int, tix1: int, tiy0: int, tiy1: int) -> void:
	var lo_x: int = mini(tix0, tix1)
	var hi_x: int = maxi(tix0, tix1)
	var lo_y: int = mini(tiy0, tiy1)
	var hi_y: int = maxi(tiy0, tiy1)
	var pad: int = BLOB_CHUNK_SIZE * 2
	var cx0: int = int(floor(float(lo_x - pad) / float(BLOB_CHUNK_SIZE)))
	var cx1: int = int(floor(float(hi_x + pad) / float(BLOB_CHUNK_SIZE)))
	var cy0: int = int(floor(float(lo_y - pad) / float(BLOB_CHUNK_SIZE)))
	var cy1: int = int(floor(float(hi_y + pad) / float(BLOB_CHUNK_SIZE)))
	for ccy in range(cy0, cy1 + 1):
		for ccx in range(cx0, cx1 + 1):
			ensure_chunk(ccx, ccy)


## 与 blobTerrain.preloadAroundTile 一致。
func preload_around_tile(tx: int, ty: int, radius_tiles: int) -> void:
	var pad: int = BLOB_CHUNK_SIZE * 2
	var x0: int = tx - radius_tiles - pad
	var x1: int = tx + radius_tiles + pad
	var y0: int = ty - radius_tiles - pad
	var y1: int = ty + radius_tiles + pad
	var cx0: int = int(floor(float(x0) / float(BLOB_CHUNK_SIZE)))
	var cx1: int = int(floor(float(x1) / float(BLOB_CHUNK_SIZE)))
	var cy0: int = int(floor(float(y0) / float(BLOB_CHUNK_SIZE)))
	var cy1: int = int(floor(float(y1) / float(BLOB_CHUNK_SIZE)))
	for ccy in range(cy0, cy1 + 1):
		for ccx in range(cx0, cx1 + 1):
			ensure_chunk(ccx, ccy)


func land_world(wx: int, wy: int) -> int:
	var cx: int = int(floor(float(wx) / float(BLOB_CHUNK_SIZE)))
	var cy: int = int(floor(float(wy) / float(BLOB_CHUNK_SIZE)))
	var ch: ChunkData = ensure_chunk(cx, cy)
	var lx: int = ((wx % BLOB_CHUNK_SIZE) + BLOB_CHUNK_SIZE) % BLOB_CHUNK_SIZE
	var ly: int = ((wy % BLOB_CHUNK_SIZE) + BLOB_CHUNK_SIZE) % BLOB_CHUNK_SIZE
	return ch.land[ly * BLOB_CHUNK_SIZE + lx]


func biome_world(wx: int, wy: int) -> int:
	var cx: int = int(floor(float(wx) / float(BLOB_CHUNK_SIZE)))
	var cy: int = int(floor(float(wy) / float(BLOB_CHUNK_SIZE)))
	var ch: ChunkData = ensure_chunk(cx, cy)
	var lx: int = ((wx % BLOB_CHUNK_SIZE) + BLOB_CHUNK_SIZE) % BLOB_CHUNK_SIZE
	var ly: int = ((wy % BLOB_CHUNK_SIZE) + BLOB_CHUNK_SIZE) % BLOB_CHUNK_SIZE
	return ch.biome[ly * BLOB_CHUNK_SIZE + lx]


func get_mask_water(tx: int, ty: int) -> int:
	return compute_blob_mask(tx, ty, func(nx: int, ny: int) -> bool:
		return land_world(nx, ny) == 0
	)


func get_mask_land_biome(tx: int, ty: int, b: int) -> int:
	return compute_blob_mask(tx, ty, func(nx: int, ny: int) -> bool:
		return land_world(nx, ny) == 1 and biome_world(nx, ny) == b
	)


func sample_tile_index(tx: int, ty: int) -> Dictionary:
	if land_world(tx, ty) == 0:
		return {"kind": "water", "sheet_index": nearest_blob_tile_index(get_mask_water(tx, ty))}
	var b: int = biome_world(tx, ty)
	var mask: int = get_mask_land_biome(tx, ty, b)
	if b == IMG_MTN:
		return {"kind": "mtn", "sheet_index": nearest_blob_tile_index(mask)}
	return {"kind": "norm", "sheet_index": nearest_blob_tile_index(mask)}


static func is_blob_tile_walkable(world: BlobWorld, tx: int, ty: int) -> bool:
	if world.land_world(tx, ty) != 1:
		return false
	return world.biome_world(tx, ty) == IMG_NORM


static func find_walkable_tile_center(world: BlobWorld, origin_tx: int, origin_tz: int, max_cheb_radius: int, tile_world: float) -> Variant:
	for r in max_cheb_radius + 1:
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var ttx: int = origin_tx + dx
				var ttz: int = origin_tz + dz
				if is_blob_tile_walkable(world, ttx, ttz):
					return Vector2((float(ttx) + 0.5) * tile_world, (float(ttz) + 0.5) * tile_world)
	return null
