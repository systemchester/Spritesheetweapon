extends Control

var environment: Node

var _drop_texture: Texture2D
var _splash_texture: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_weather_assets()


func _draw() -> void:
	if environment == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var rect := Rect2(Vector2.ZERO, viewport_size)
	_draw_time_tint(rect)
	_draw_snow(rect, _weather_strength("snow"))
	_draw_rain(rect, _weather_strength("rainy"), _weather_strength("thunder"))
	_draw_lightning(rect)


func _load_weather_assets() -> void:
	if environment != null and environment.get("use_original_weather_assets") == false:
		return
	_drop_texture = _load_weather_texture("water_drop.png")
	_splash_texture = _load_weather_texture("water_splash.png")


func _draw_time_tint(rect: Rect2) -> void:
	var night_curve: float = float(environment.get("time_based_light_curve"))
	var weather_curve: float = float(environment.get("weather_light_curve"))
	var ambient: Color = environment.get("ambient_color")
	var darkness: float = clamp(1.0 - ((ambient.r + ambient.g + ambient.b) / 3.0), 0.0, 1.0)
	var blue_alpha: float = clamp(night_curve * 0.48 + weather_curve * 0.18 + darkness * 0.12, 0.0, 0.68)
	if blue_alpha > 0.001:
		draw_rect(rect, Color(0.025, 0.045, 0.105, blue_alpha), true)

	var hour: float = float(environment.get("current_hour"))
	var dawn: float = 1.0 - _smoothstep(5.0, 6.8, abs(hour - 5.75))
	var dusk: float = 1.0 - _smoothstep(21.0, 22.6, abs(hour - 21.8))
	var warm: float = max(dawn, dusk)
	if warm > 0.0:
		draw_rect(rect, Color(1.0, 0.48, 0.22, warm * 0.08), true)


func _draw_snow(rect: Rect2, strength: float) -> void:
	strength = clamp(strength, 0.0, 1.0)
	if strength <= 0.01:
		return
	var alpha: float = clamp(strength * 0.28, 0.0, 0.36)
	draw_rect(rect, Color(0.72, 0.84, 1.0, alpha * 0.18), true)
	var time: float = float(environment.get("effect_time"))
	var density: float = clamp(_env_float("snow_density", 1.0), 0.2, 3.0)
	var flake_size: float = clamp(_env_float("snowflake_size", 1.8), 0.4, 3.5)
	var drift: float = clamp(_env_float("snow_drift_strength", 22.0), 0.0, 80.0)
	var fall_speed: float = clamp(_env_float("snow_fall_speed", 95.0), 20.0, 260.0)
	var depth_feel: float = clamp(_env_float("snow_depth_feel", 0.85), 0.0, 1.0)
	var direction: Vector2 = _env_vector2("snow_fall_direction", Vector2(-0.12, 1.0))
	if direction.length_squared() < 0.0001:
		direction = Vector2.DOWN
	direction = direction.normalized()
	var base_count: int = int(lerp(34.0, 150.0, strength) * density)
	var scroll_offset: Vector2 = _precipitation_scroll_offset(rect)
	_draw_snow_layer(rect, strength, base_count, time, direction, scroll_offset, flake_size, drift, fall_speed, depth_feel, 0)
	_draw_snow_layer(rect, strength, base_count, time, direction, scroll_offset, flake_size, drift, fall_speed, depth_feel, 1)
	_draw_snow_layer(rect, strength, base_count, time, direction, scroll_offset, flake_size, drift, fall_speed, depth_feel, 2)


func _draw_snow_layer(rect: Rect2, strength: float, base_count: int, time: float, direction: Vector2, scroll_offset: Vector2, flake_size: float, drift: float, fall_speed: float, depth_feel: float, layer_index: int) -> void:
	var layer_count_factor: float = 0.9
	var size_factor: float = 0.55
	var speed_factor: float = 0.45
	var drift_factor: float = 0.35
	var alpha_factor: float = 0.34
	var parallax: float = lerp(0.55, 0.24, depth_feel)
	var glow: float = 0.0
	var seed_offset: float = 0.0
	if layer_index == 1:
		layer_count_factor = 0.78
		size_factor = 1.0
		speed_factor = 0.82
		drift_factor = 0.75
		alpha_factor = 0.62
		parallax = 1.0
		seed_offset = 371.0
	elif layer_index == 2:
		layer_count_factor = 0.32
		size_factor = lerp(1.35, 2.15, depth_feel)
		speed_factor = lerp(0.96, 1.42, depth_feel)
		drift_factor = lerp(0.82, 1.35, depth_feel)
		alpha_factor = lerp(0.54, 0.82, depth_feel)
		parallax = lerp(1.05, 1.32, depth_feel)
		glow = clamp(_env_float("snow_foreground_glow", 0.55), 0.0, 1.0) * depth_feel
		seed_offset = 913.0
	var count: int = max(1, int(float(base_count) * layer_count_factor))
	var margin: float = 56.0 + flake_size * size_factor * 22.0
	var travel_w: float = rect.size.x + margin * 2.0
	var travel_h: float = rect.size.y + margin * 2.0
	for i in range(count):
		var seed: float = seed_offset + float(i) * 19.371
		var local: float = _hash_float(seed)
		var speed_scale: float = lerp(0.55, 1.28, _hash_float(seed + 8.1))
		var sway_phase: float = time * lerp(0.35, 1.05, local) + seed
		var sway: float = sin(sway_phase) * drift * drift_factor * lerp(0.25, 1.0, _hash_float(seed + 2.0))
		var travel: float = time * fall_speed * speed_factor * speed_scale
		var x: float = fposmod(_hash_float(seed + 4.7) * travel_w + direction.x * travel + sway - scroll_offset.x * parallax, travel_w) - margin
		var y: float = fposmod(_hash_float(seed + 81.2) * travel_h + direction.y * travel - scroll_offset.y * parallax, travel_h) - margin
		var radius: float = flake_size * size_factor * lerp(0.62, 1.45, _hash_float(seed + 3.0))
		var flake_alpha: float = clamp(lerp(0.24, 0.78, strength) * alpha_factor * lerp(0.58, 1.0, local), 0.0, 0.88)
		var pos := Vector2(x, y)
		if glow > 0.01 and radius > 1.4:
			draw_circle(pos, radius * lerp(2.0, 3.4, glow), Color(0.82, 0.92, 1.0, flake_alpha * 0.18 * glow))
		draw_circle(pos, radius, Color(0.9, 0.96, 1.0, flake_alpha))
		if radius > 1.2:
			draw_circle(pos, radius * 0.42, Color(1.0, 1.0, 1.0, flake_alpha * 0.78))
		if layer_index == 2 and radius > 2.2:
			var sparkle_alpha: float = flake_alpha * 0.32 * glow
			draw_line(pos + Vector2(-radius * 0.9, 0.0), pos + Vector2(radius * 0.9, 0.0), Color(1.0, 1.0, 1.0, sparkle_alpha), 1.0)
			draw_line(pos + Vector2(0.0, -radius * 0.9), pos + Vector2(0.0, radius * 0.9), Color(1.0, 1.0, 1.0, sparkle_alpha), 1.0)


func _draw_rain(rect: Rect2, rain_strength: float, thunder_strength: float) -> void:
	var strength: float = clamp(rain_strength + thunder_strength, 0.0, 1.0)
	if strength <= 0.01:
		return
	var time: float = float(environment.get("effect_time"))
	var heavy: float = clamp(thunder_strength * 1.35, 0.0, 1.0)
	var drop_count: int = int(lerp(36.0, 230.0, strength) + heavy * 70.0)
	var fall_speed: float = lerp(620.0, 1080.0, heavy)
	var direction: Vector2 = _env_vector2("rain_fall_direction", Vector2(-0.28, 1.0))
	if direction.length_squared() < 0.0001:
		direction = Vector2.DOWN
	direction = direction.normalized()
	var streak_length: float = maxf(1.0, _env_float("rain_streak_length", 38.0) + heavy * 18.0)
	var streak: Vector2 = direction * streak_length
	var margin: float = maxf(96.0, streak_length * 3.0)
	var travel_w: float = rect.size.x + margin * 2.0
	var travel_h: float = rect.size.y + margin * 2.0
	var scroll_offset: Vector2 = _precipitation_scroll_offset(rect)
	for i in range(drop_count):
		var seed: float = float(i) * 13.371
		var rx: float = _hash_float(seed + 4.7)
		var ry: float = _hash_float(seed + 81.2)
		var speed_scale: float = lerp(0.75, 1.35, _hash_float(seed + 8.1))
		var travel: float = time * fall_speed * speed_scale
		var x: float = fposmod(rx * travel_w + direction.x * travel - scroll_offset.x, travel_w) - margin
		var y: float = fposmod(ry * travel_h + direction.y * travel - scroll_offset.y, travel_h) - margin
		var alpha: float = lerp(0.16, 0.45, strength) + heavy * 0.12
		var pos := Vector2(x, y)
		draw_line(pos - streak * 0.45, pos + streak * 0.55, Color(0.52, 0.64, 0.86, alpha), 1.0)

	var splash_count: int = int(lerp(0.0, 34.0, strength))
	for i in range(splash_count):
		var seed: float = float(i) * 27.91
		var phase: float = fposmod(time * lerp(4.0, 8.0, _hash_float(seed)) + _hash_float(seed + 5.0), 1.0)
		if phase > 0.34:
			continue
		var pos := Vector2(_hash_float(seed + 2.0) * rect.size.x, lerp(rect.size.y * 0.55, rect.size.y, _hash_float(seed + 3.0)))
		var splash_alpha: float = (1.0 - phase / 0.34) * strength * 0.28
		if _splash_texture != null:
			draw_texture_rect(_splash_texture, Rect2(pos, Vector2(10.0, 10.0)), false, Color(0.55, 0.65, 0.85, splash_alpha))
		else:
			draw_circle(pos, 1.5, Color(0.55, 0.65, 0.85, splash_alpha))


func _draw_lightning(rect: Rect2) -> void:
	var flash: float = float(environment.get("lightning_flash"))
	if flash <= 0.001:
		return
	var alpha: float = pow(flash, 1.7) * 0.74
	draw_rect(rect, Color(1.0, 1.0, 1.0, alpha), true)


func _weather_strength(weather_id: String) -> float:
	if environment != null and environment.has_method("get_weather_strength"):
		return float(environment.call("get_weather_strength", weather_id))
	return 0.0


func _env_float(property_name: String, fallback: float) -> float:
	if environment == null:
		return fallback
	var value: Variant = environment.get(property_name)
	if value == null:
		return fallback
	return float(value)


func _env_vector2(property_name: String, fallback: Vector2) -> Vector2:
	if environment == null:
		return fallback
	var value: Variant = environment.get(property_name)
	if value is Vector2:
		return value as Vector2
	return fallback


func _env_bool(property_name: String, fallback: bool) -> bool:
	if environment == null:
		return fallback
	var value: Variant = environment.get(property_name)
	if typeof(value) == TYPE_BOOL:
		return bool(value)
	return fallback


func _precipitation_scroll_offset(rect: Rect2) -> Vector2:
	if not _env_bool("anchor_precipitation_to_world", true):
		return Vector2.ZERO
	if environment == null or not environment.has_method("get_camera_world_rect"):
		return Vector2.ZERO
	var world_rect_value: Variant = environment.call("get_camera_world_rect")
	if not (world_rect_value is Rect2):
		return Vector2.ZERO
	var world_rect: Rect2 = world_rect_value as Rect2
	if world_rect.size.x <= 0.001 or world_rect.size.y <= 0.001:
		return Vector2.ZERO
	var scale := Vector2(rect.size.x / world_rect.size.x, rect.size.y / world_rect.size.y)
	return Vector2(world_rect.position.x * scale.x, world_rect.position.y * scale.y)


func _hash_float(value: float) -> float:
	var raw: float = sin(value * 12.9898 + 78.233) * 43758.5453
	return raw - floor(raw)


func _load_weather_texture(file_name: String) -> Texture2D:
	if environment != null and environment.has_method("get_weather_asset_path"):
		return _load_texture_from_file(str(environment.call("get_weather_asset_path", file_name)))
	var script := get_script() as Script
	if script != null:
		return _load_texture_from_file("%s/assets/weather/%s" % [script.resource_path.get_base_dir(), file_name])
	return null


func _load_texture_from_file(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var imported := load(path)
		if imported is Texture2D:
			return imported
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null:
			return ImageTexture.create_from_image(image)
	var absolute_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return null
	var image := Image.load_from_file(absolute_path)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)


func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	if abs(edge1 - edge0) < 0.00001:
		return 1.0 if value >= edge1 else 0.0
	var t: float = clamp((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
