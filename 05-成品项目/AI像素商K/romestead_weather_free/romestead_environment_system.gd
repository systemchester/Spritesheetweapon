extends Node

signal hour_changed(hour: float, day: int)
signal day_started(day: int)
signal night_started(day: int)
signal dominant_weather_changed(weather_id: String, strength: float)
signal weather_spawned(instance: Dictionary)
signal weather_removed(instance_id: int)

const REAL_SECONDS_PER_FULL_DAY := 20.0 * 60.0
const GAME_SECONDS_PER_REAL_SECOND := 24.0 * 60.0 * 60.0 / REAL_SECONDS_PER_FULL_DAY
const NIGHT_START := 22.0
const NIGHT_END := 5.0
const WEATHER_CHECK_TICK := 0.033
const WEATHER_FADE_SECONDS := 10.0
const WEATHER_OVERLAP_SCALE := 0.8
const DEFAULT_TILE_SIZE := 16.0

const WEATHER_DATABASE := {
	"normal": {
		"name": "Clear skies",
		"spawn_frequency": 75.0,
		"compatible_weather_ids": ["snow"],
		"duration": [200.0, 800.0],
		"radius_scale": [0.8, 1.0],
		"velocity_scale": 0.0,
		"ambient_rgb": [1.0, 1.0, 1.0],
		"sun_multiplier": 1.0,
		"moon_multiplier": 1.0,
		"light_curve": 0.0,
		"wind": 1.0,
		"wetness": 0.0
	},
	"rainy": {
		"name": "Rain",
		"spawn_frequency": 15.0,
		"incompatible_biome_ids": ["desert", "desert_edge", "volcanic", "volcanic_center", "volcanic_edge", "volcanic_tendril", "volcanic_tendril_volcano", "volcanic_tendril_desert"],
		"compatible_weather_ids": [],
		"duration": [220.0, 600.0],
		"radius_scale": [0.9, 1.0],
		"velocity_scale": 31.0,
		"ambient_rgb": [0.9, 0.9, 1.0],
		"sun_multiplier": 0.6,
		"moon_multiplier": 0.6,
		"light_curve": 0.2,
		"wind": 2.0,
		"wetness": 0.45,
		"rain_amount": 4.0
	},
	"thunder": {
		"name": "Thunderstorm",
		"spawn_frequency": 5.0,
		"incompatible_biome_ids": ["desert", "desert_edge", "volcanic", "volcanic_center", "volcanic_edge", "volcanic_tendril", "volcanic_tendril_volcano", "volcanic_tendril_desert"],
		"compatible_weather_ids": [],
		"duration": [170.0, 300.0],
		"radius_scale": [0.9, 1.0],
		"velocity_scale": 37.0,
		"ambient_rgb": [0.6, 0.6, 0.8],
		"sun_multiplier": 0.5,
		"moon_multiplier": 0.5,
		"light_curve": 0.35,
		"wind": 3.0,
		"wetness": 0.48,
		"rain_amount": 16.0
	},
	"snow": {
		"name": "Snow",
		"spawn_frequency": 8.0,
		"incompatible_biome_ids": ["desert", "desert_edge", "volcanic", "volcanic_center", "volcanic_edge", "volcanic_tendril", "volcanic_tendril_volcano", "volcanic_tendril_desert", "ghosttown", "ghosttown_center"],
		"compatible_weather_ids": ["normal"],
		"duration": [180.0, 420.0],
		"radius_scale": [0.9, 1.0],
		"velocity_scale": 12.0,
		"ambient_rgb": [0.94, 0.97, 1.0],
		"sun_multiplier": 0.78,
		"moon_multiplier": 0.84,
		"light_curve": 0.08,
		"wind": 0.8,
		"wetness": 0.18,
		"snow_amount": 1.0
	},
	"owl_shadow": {
		"name": "Owl shadow",
		"spawn_frequency": 0.0,
		"incompatible_biome_ids": ["desert", "desert_edge", "volcanic", "volcanic_center", "volcanic_edge", "volcanic_tendril", "volcanic_tendril_volcano", "volcanic_tendril_desert", "ghosttown", "ghosttown_center"],
		"compatible_weather_ids": ["rainy", "thunder", "snow", "normal"],
		"duration": [0.0, 0.0],
		"radius_scale": [0.0, 0.0],
		"velocity_scale": 0.0,
		"ambient_rgb": [1.0, 1.0, 1.0],
		"sun_multiplier": 1.0,
		"moon_multiplier": 1.0,
		"light_curve": 0.0,
		"wind": 1.0,
		"wetness": 0.0
	}
}

@export var enabled := true
@export var time_running := true
@export_range(0.0, 4.0, 0.05) var day_night_cycle_speed_multiplier := 1.0
@export_range(0.0, 23.999, 0.01) var start_hour := 8.0
@export var start_day := 0
@export var enable_weather_spawning := true
@export var pause_weather_system := false
@export var seed_initial_weather := false
@export var initial_weather_id := ""
@export var initial_weather_radius := 1800.0
@export var initial_weather_duration := 1200.0
@export var initial_weather_timer := WEATHER_FADE_SECONDS
@export var enable_preview_hotkeys := true
@export var weather_spawn_interval := Vector2(12.0, 20.0)
@export var weather_spawn_radius := 2048.0
@export var weather_spawn_offset := 256.0
@export var weather_seed := 78123
@export var camera_path: NodePath
@export var biome_provider_path: NodePath
@export var overlay_layer := 20
@export var show_screen_overlay := true
@export var draw_weather_debug_world := false
@export var use_original_weather_assets := true
@export var anchor_precipitation_to_world := true
@export var rain_fall_direction := Vector2(-0.28, 1.0)
@export_range(8.0, 96.0, 1.0) var rain_streak_length := 38.0
@export var snow_fall_direction := Vector2(-0.12, 1.0)
@export_range(0.4, 3.5, 0.1) var snowflake_size := 1.8
@export_range(0.2, 3.0, 0.05) var snow_density := 1.0
@export_range(0.0, 1.0, 0.05) var snow_depth_feel := 0.85
@export_range(0.0, 1.0, 0.05) var snow_foreground_glow := 0.55
@export_range(0.0, 80.0, 1.0) var snow_drift_strength := 22.0
@export_range(20.0, 260.0, 1.0) var snow_fall_speed := 95.0

var game_seconds := 0.0
var current_day := 0
var current_hour := 0.0
var is_night := false
var wind := 1.0
var wetness := 0.0
var time_based_light_curve := 0.0
var weather_light_curve := 0.0
var ambient_color := Color.WHITE
var sun_color := Color.WHITE
var moon_color := Color.WHITE
var sun_direction := Vector3.ZERO
var moon_direction := Vector3.ZERO
var current_dominant_weather_id := ""
var current_dominant_weather_strength := 0.0
var lightning_flash := 0.0
var effect_time := 0.0
var weather_instances := {}
var weather_strengths := {}

var _rng := RandomNumberGenerator.new()
var _spawn_check_timer := 0.0
var _weather_check_timer := 0.0
var _last_day_started := -1
var _has_become_night := false
var _last_hour_signal_tick := -1
var _next_instance_id := 1
var _lightning_timer := 4.0
var _camera_2d: Camera2D
var _camera_3d: Camera3D
var _biome_provider: Node
var _overlay_layer_node: CanvasLayer
var _overlay_control: Control
var _overlay_script: Script
var _package_base_path := ""


func _ready() -> void:
	_rng.seed = weather_seed
	game_seconds = max(0.0, float(start_day) * 86400.0 + start_hour * 3600.0)
	_update_time_fields(true)
	_setup_overlay()
	_schedule_next_spawn_check(0.25)
	call_deferred("_resolve_context")
	if seed_initial_weather and initial_weather_id != "":
		call_deferred("_spawn_initial_weather")


func _process(delta: float) -> void:
	if not enabled:
		return
	effect_time += delta
	_resolve_context()
	if time_running:
		advance_time(delta)
	if not pause_weather_system:
		_update_weather_instances(delta)
		_update_weather_check(delta)
		_update_weather_spawn_system(delta)
	_update_environment_mix(delta)
	if _overlay_control != null:
		_overlay_control.visible = show_screen_overlay
		_overlay_control.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not enable_preview_hotkeys:
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var hotkey_number := _preview_hotkey_number(key_event)
	if hotkey_number < 1:
		return
	match hotkey_number:
		1:
			clear_weather()
			get_viewport().set_input_as_handled()
		2:
			set_preview_weather("rainy")
			get_viewport().set_input_as_handled()
		3:
			set_preview_weather("thunder")
			get_viewport().set_input_as_handled()
		4:
			set_preview_weather("snow")
			get_viewport().set_input_as_handled()
		5:
			set_hour(5.5)
			get_viewport().set_input_as_handled()
		6:
			set_hour(12.0)
			get_viewport().set_input_as_handled()
		7:
			set_hour(21.5)
			get_viewport().set_input_as_handled()
		8:
			set_hour(23.5)
			get_viewport().set_input_as_handled()
		9:
			skip_to_next_day(6.0)
			get_viewport().set_input_as_handled()


func _preview_hotkey_number(key_event: InputEventKey) -> int:
	if not key_event.shift_pressed or key_event.ctrl_pressed or key_event.alt_pressed or key_event.meta_pressed:
		return -1
	var number := _digit_from_keycode(key_event.keycode)
	if number >= 1:
		return number
	return _digit_from_keycode(key_event.physical_keycode)


func _digit_from_keycode(keycode: int) -> int:
	match keycode:
		KEY_1:
			return 1
		KEY_2:
			return 2
		KEY_3:
			return 3
		KEY_4:
			return 4
		KEY_5:
			return 5
		KEY_6:
			return 6
		KEY_7:
			return 7
		KEY_8:
			return 8
		KEY_9:
			return 9
		_:
			return -1


func advance_time(real_delta_seconds: float) -> void:
	game_seconds += real_delta_seconds * GAME_SECONDS_PER_REAL_SECOND * day_night_cycle_speed_multiplier
	_update_time_fields(false)


func set_hour(hour: float) -> void:
	hour = clamp(hour, 0.0, 23.999)
	game_seconds = float(current_day) * 86400.0 + hour * 3600.0
	_update_time_fields(true)


func set_day_and_hour(day: int, hour: float) -> void:
	current_day = max(0, day)
	game_seconds = float(current_day) * 86400.0 + clamp(hour, 0.0, 23.999) * 3600.0
	_update_time_fields(true)


func skip_to_next_day(hour: float = 6.0) -> void:
	set_day_and_hour(current_day + 1, hour)


func get_day_cycle_length_in_seconds() -> float:
	var speed: float = max(0.0001, day_night_cycle_speed_multiplier)
	return REAL_SECONDS_PER_FULL_DAY / speed


func get_day_only_length_in_seconds() -> float:
	return get_day_cycle_length_in_seconds() * (17.0 / 24.0)


func get_night_length_in_seconds() -> float:
	return get_day_cycle_length_in_seconds() * (7.0 / 24.0)


func get_time_to_night_in_seconds() -> float:
	if hour_is_night(current_hour):
		return 0.0
	return ((NIGHT_START - current_hour) / 24.0) * get_day_cycle_length_in_seconds()


func get_time_to_day_in_seconds() -> float:
	if not hour_is_night(current_hour):
		return 0.0
	return (fposmod(NIGHT_END - current_hour, 24.0) / 24.0) * get_day_cycle_length_in_seconds()


func hour_is_night(hour: float) -> bool:
	return hour > NIGHT_START or hour < NIGHT_END


func spawn_weather_at_focus(weather_id: String, radius: float = 1600.0, duration: float = 1200.0, velocity: Vector2 = Vector2.ZERO, clear_other_weather := false) -> Dictionary:
	return spawn_weather(weather_id, _focus_position(), radius, radius, duration, velocity, clear_other_weather, true)


func set_preview_weather(weather_id: String, radius: float = 1800.0, duration: float = 1200.0) -> Dictionary:
	return spawn_weather(weather_id, _focus_position(), radius, radius, duration, Vector2.ZERO, true, true, WEATHER_FADE_SECONDS)


func spawn_weather(weather_id: String, position: Vector2, radius_x: float, radius_y: float, duration: float, velocity: Vector2, clear_other_weather := false, do_not_auto_remove := false, timer: float = 0.0) -> Dictionary:
	if not WEATHER_DATABASE.has(weather_id):
		push_warning("Unknown weather id: %s" % weather_id)
		return {}
	if clear_other_weather:
		for instance in weather_instances.values():
			if instance["position"].distance_to(position) <= max(radius_x, radius_y):
				remove_weather(int(instance["id"]), false)
	var instance := {
		"id": _next_instance_id,
		"weather_id": weather_id,
		"timer": max(0.0, timer),
		"life_length": max(0.01, duration),
		"do_not_auto_remove": do_not_auto_remove,
		"position": position,
		"velocity": velocity,
		"size": Vector2(max(1.0, radius_x), max(1.0, radius_y)),
		"angle": 0.0
	}
	_next_instance_id += 1
	weather_instances[int(instance["id"])] = instance
	emit_signal("weather_spawned", instance.duplicate(true))
	return instance


func remove_weather(instance_id: int, fade_out := true) -> void:
	if not weather_instances.has(instance_id):
		return
	if fade_out:
		var instance: Dictionary = weather_instances[instance_id]
		var fade_time: float = min(WEATHER_FADE_SECONDS, float(instance["timer"]))
		instance["timer"] = max(float(instance["timer"]), float(instance["life_length"]) - fade_time)
		weather_instances[instance_id] = instance
		return
	weather_instances.erase(instance_id)
	emit_signal("weather_removed", instance_id)


func clear_weather() -> void:
	for instance_id in weather_instances.keys():
		emit_signal("weather_removed", int(instance_id))
	weather_instances.clear()
	weather_strengths.clear()
	_set_dominant_weather("", 0.0)


func get_weather_strength(weather_id: String) -> float:
	return float(weather_strengths.get(weather_id, 0.0))


func get_weather_instance_strength(instance_id: int) -> float:
	if not weather_instances.has(instance_id):
		return 0.0
	var rect := _camera_world_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return 0.0
	return _weather_instance_strength(weather_instances[instance_id], rect)


func get_camera_world_rect() -> Rect2:
	return _camera_world_rect()


func get_weather_summary() -> Dictionary:
	return {
		"day": current_day,
		"hour": current_hour,
		"is_night": is_night,
		"dominant_weather_id": current_dominant_weather_id,
		"dominant_weather_strength": current_dominant_weather_strength,
		"weather_strengths": weather_strengths.duplicate(),
		"ambient_color": ambient_color,
		"time_based_light_curve": time_based_light_curve,
		"wind": wind,
		"wetness": wetness
	}


func get_package_base_dir() -> String:
	if _package_base_path.is_empty():
		var script := get_script() as Script
		if script != null:
			_package_base_path = script.resource_path.get_base_dir()
		else:
			_package_base_path = "res://romestead_weather_free"
	return _package_base_path


func get_weather_asset_path(file_name: String) -> String:
	return "%s/assets/weather/%s" % [get_package_base_dir(), file_name]


func _setup_overlay() -> void:
	if _overlay_layer_node != null:
		return
	if _overlay_script == null:
		_overlay_script = load("%s/romestead_environment_overlay.gd" % get_package_base_dir()) as Script
	if _overlay_script == null:
		push_warning("Romestead environment overlay script could not be loaded from %s." % get_package_base_dir())
		return
	_overlay_layer_node = CanvasLayer.new()
	_overlay_layer_node.name = "EnvironmentOverlayLayer"
	_overlay_layer_node.layer = overlay_layer
	add_child(_overlay_layer_node)

	_overlay_control = Control.new()
	_overlay_control.name = "EnvironmentOverlay"
	_overlay_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_control.set_script(_overlay_script)
	_overlay_control.environment = self
	_overlay_layer_node.add_child(_overlay_control)


func _spawn_initial_weather() -> void:
	_resolve_context()
	spawn_weather(
		initial_weather_id,
		_focus_position(),
		max(1.0, initial_weather_radius),
		max(1.0, initial_weather_radius),
		max(0.01, initial_weather_duration),
		Vector2.ZERO,
		true,
		true,
		clamp(initial_weather_timer, 0.0, max(0.01, initial_weather_duration))
	)


func _resolve_context() -> void:
	if _biome_provider == null:
		if biome_provider_path != NodePath("") and has_node(biome_provider_path):
			_biome_provider = get_node(biome_provider_path)
		elif get_parent() != null:
			_biome_provider = get_parent()
	if _camera_2d == null and _camera_3d == null:
		if camera_path != NodePath("") and has_node(camera_path):
			var configured_camera := get_node(camera_path)
			if configured_camera is Camera2D:
				_camera_2d = configured_camera as Camera2D
			elif configured_camera is Camera3D:
				_camera_3d = configured_camera as Camera3D
		elif _biome_provider != null and _biome_provider.has_node("Camera2D"):
			_camera_2d = _biome_provider.get_node("Camera2D") as Camera2D
		else:
			_camera_2d = get_viewport().get_camera_2d()
		if _camera_2d == null and _camera_3d == null:
			_camera_3d = get_viewport().get_camera_3d()


func _update_time_fields(force_emit: bool) -> void:
	current_day = int(floor(game_seconds / 86400.0))
	current_hour = fposmod(game_seconds, 86400.0) / 3600.0
	var new_is_night := hour_is_night(current_hour)
	if force_emit:
		is_night = new_is_night
		_has_become_night = is_night
		_last_day_started = current_day if not is_night else current_day - 1
	else:
		is_night = new_is_night
		if current_day != _last_day_started and not is_night:
			_last_day_started = current_day
			_has_become_night = false
			emit_signal("day_started", current_day)
		elif is_night and not _has_become_night:
			_has_become_night = true
			emit_signal("night_started", current_day)

	var hour_signal_tick := int(floor(current_hour * 4.0))
	if force_emit or hour_signal_tick != _last_hour_signal_tick:
		_last_hour_signal_tick = hour_signal_tick
		emit_signal("hour_changed", current_hour, current_day)


func _update_weather_instances(delta: float) -> void:
	for instance_id in weather_instances.keys():
		var instance: Dictionary = weather_instances[instance_id]
		instance["timer"] = float(instance["timer"]) + delta
		if float(instance["timer"]) >= float(instance["life_length"]):
			remove_weather(int(instance_id), false)
			continue
		instance["position"] = instance["position"] + instance["velocity"] * delta
		weather_instances[instance_id] = instance
		if not _weather_position_in_bounds(instance["position"]):
			remove_weather(int(instance_id), true)


func _update_weather_check(delta: float) -> void:
	_weather_check_timer += delta
	if _weather_check_timer < WEATHER_CHECK_TICK:
		return
	_weather_check_timer = 0.0

	var rect := _camera_world_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return

	var next_strengths := {}
	for instance in weather_instances.values():
		var strength := _weather_instance_strength(instance, rect)
		if strength <= 0.001:
			continue
		var weather_id := str(instance["weather_id"])
		next_strengths[weather_id] = min(1.0, float(next_strengths.get(weather_id, 0.0)) + strength)

	weather_strengths = next_strengths
	_update_dominant_weather()


func _update_weather_spawn_system(delta: float) -> void:
	if not enable_weather_spawning:
		return
	_spawn_check_timer -= delta
	if _spawn_check_timer > 0.0:
		return
	_schedule_next_spawn_check()
	if _camera_2d == null and _camera_3d == null and _biome_provider == null:
		return

	var focus := _focus_position()
	var position := focus + _random_point_in_circle() * (weather_spawn_offset + weather_spawn_radius)
	var surroundings := _gather_weather_surroundings(position, weather_spawn_radius)
	var valid_weather := []
	var total_weight := 0.0
	for weather_id in WEATHER_DATABASE.keys():
		var data: Dictionary = WEATHER_DATABASE[weather_id]
		var frequency := _weather_spawn_frequency(weather_id, data, surroundings["biomes"])
		if frequency <= 0.0:
			continue
		if not _check_weather_conditions(data, surroundings):
			continue
		valid_weather.append([weather_id, frequency])
		total_weight += frequency

	if valid_weather.is_empty():
		return
	if total_weight < 100.0:
		valid_weather.append(["", 100.0 - total_weight])
		total_weight = 100.0

	var roll := _rng.randf_range(0.0, total_weight)
	var chosen_id := ""
	for item in valid_weather:
		roll -= float(item[1])
		if roll <= 0.0:
			chosen_id = str(item[0])
			break
	if chosen_id == "":
		return

	var chosen: Dictionary = WEATHER_DATABASE[chosen_id]
	var duration_span: Array = chosen["duration"]
	var radius_span: Array = chosen["radius_scale"]
	var duration := _rng.randf_range(float(duration_span[0]), float(duration_span[1]))
	var radius := _rng.randf_range(float(radius_span[0]), float(radius_span[1])) * weather_spawn_radius
	var velocity := _random_unit_vector() * float(chosen.get("velocity_scale", 0.0)) * _rng.randf_range(0.9, 1.1)
	spawn_weather(chosen_id, position, radius, radius, duration, velocity)


func _update_environment_mix(delta: float) -> void:
	var hour := fposmod(current_hour, 24.0)
	var base_ambient := _standard_ambient_color(hour)
	var weather_ambient := _mix_weather_color("ambient_rgb", Color.WHITE)
	ambient_color = Color(
		clamp(base_ambient.r * weather_ambient.r, 0.0, 1.0),
		clamp(base_ambient.g * weather_ambient.g, 0.0, 1.0),
		clamp(base_ambient.b * weather_ambient.b, 0.0, 1.0),
		1.0
	)
	weather_light_curve = _mix_weather_float("light_curve", 0.0)
	time_based_light_curve = 1.0 - (1.0 - _standard_time_based_light_curve(hour)) * (1.0 - weather_light_curve)
	wind = _mix_weather_float("wind", 1.0)
	wetness = clamp(_mix_weather_float("wetness", 0.0), 0.0, 1.0)

	var sun := _standard_sun_color_and_direction(hour)
	var moon := _standard_moon_color_and_direction(hour)
	var sun_multiplier := _mix_weather_float("sun_multiplier", 1.0)
	var moon_multiplier := _mix_weather_float("moon_multiplier", 1.0)
	sun_color = sun["color"] * sun_multiplier
	moon_color = moon["color"] * moon_multiplier
	sun_direction = sun["direction"]
	moon_direction = moon["direction"]

	_update_lightning(delta)


func _update_dominant_weather() -> void:
	var candidate_id := ""
	var candidate_strength := 0.0
	for weather_id in weather_strengths.keys():
		var strength := float(weather_strengths[weather_id])
		if weather_id != current_dominant_weather_id and strength > candidate_strength:
			candidate_id = str(weather_id)
			candidate_strength = strength

	var retained_strength := float(weather_strengths.get(current_dominant_weather_id, 0.0))
	if retained_strength < 0.26:
		retained_strength = 0.0

	var next_id := ""
	var next_strength := 0.0
	if current_dominant_weather_id != "" and retained_strength > 0.0:
		next_id = current_dominant_weather_id
		next_strength = retained_strength
	if (current_dominant_weather_id != "" and candidate_strength > retained_strength * 2.5) or candidate_strength > 0.61:
		next_id = candidate_id
		next_strength = candidate_strength

	_set_dominant_weather(next_id, next_strength)


func _set_dominant_weather(weather_id: String, strength: float) -> void:
	if current_dominant_weather_id == weather_id and abs(current_dominant_weather_strength - strength) < 0.001:
		return
	current_dominant_weather_id = weather_id
	current_dominant_weather_strength = strength
	emit_signal("dominant_weather_changed", current_dominant_weather_id, current_dominant_weather_strength)


func _weather_instance_strength(instance: Dictionary, rect: Rect2) -> float:
	var radius: float = float(instance["size"].x)
	var timer: float = float(instance["timer"])
	var life_length: float = float(instance["life_length"])
	var fade := _smoothstep(0.0, WEATHER_FADE_SECONDS, timer) * _smoothstep(0.0, WEATHER_FADE_SECONDS, life_length - timer)
	if fade <= 0.0:
		return 0.0

	var samples_x := 5
	var samples_y := 5
	var hits := 0
	var total := samples_x * samples_y
	for y in range(samples_y):
		for x in range(samples_x):
			var sample := rect.position + Vector2(
				(float(x) + 0.5) / float(samples_x) * rect.size.x,
				(float(y) + 0.5) / float(samples_y) * rect.size.y
			)
			if sample.distance_to(instance["position"]) <= radius:
				hits += 1

	var sampled_strength := float(hits) / float(total)
	var diagonal := rect.size.length()
	var center_distance := rect.get_center().distance_to(instance["position"])
	var center_strength := 1.0 - _smoothstep(radius * 0.65, radius * 1.2 + diagonal * 0.5, center_distance)
	return clamp(max(sampled_strength, center_strength * 0.85) * fade, 0.0, 1.0)


func _gather_weather_surroundings(position: Vector2, radius: float, ignore_instance_id := -1, ignore_weather_id := "") -> Dictionary:
	var biomes := {}
	var tile_size := _provider_tile_size()
	var center_tile := position / tile_size
	var tile_radius := radius / tile_size
	var step := 15
	var start_x := int(floor(center_tile.x - tile_radius))
	var start_y := int(floor(center_tile.y - tile_radius))
	var end_x := int(ceil(center_tile.x + tile_radius))
	var end_y := int(ceil(center_tile.y + tile_radius))
	for y in range(start_y, end_y + 1, step):
		for x in range(start_x, end_x + 1, step):
			var tile_pos := Vector2(float(x) + 0.5, float(y) + 0.5)
			if tile_pos.distance_to(center_tile) <= tile_radius:
				biomes[_normalize_biome_id(_biome_at_tile(x, y))] = true

	var overlapping_weather := {}
	for instance in weather_instances.values():
		if int(instance["id"]) == ignore_instance_id:
			continue
		if ignore_weather_id != "" and str(instance["weather_id"]) == ignore_weather_id:
			continue
		var overlap_distance := (radius + float(instance["size"].x)) * WEATHER_OVERLAP_SCALE
		if position.distance_to(instance["position"]) < overlap_distance:
			overlapping_weather[str(instance["weather_id"])] = true
	return {"biomes": biomes, "weather_ids": overlapping_weather}


func _check_weather_conditions(data: Dictionary, surroundings: Dictionary) -> bool:
	var biomes: Dictionary = surroundings["biomes"]
	for biome_id in data.get("incompatible_biome_ids", []):
		if biomes.has(_normalize_biome_id(str(biome_id))):
			return false

	var compatible_biomes: Array = data.get("compatible_biome_ids", [])
	if not compatible_biomes.is_empty():
		var found_biome := false
		for biome_id in compatible_biomes:
			if biomes.has(_normalize_biome_id(str(biome_id))):
				found_biome = true
				break
		if not found_biome:
			return false

	var overlapping_weather: Dictionary = surroundings["weather_ids"]
	var compatible_weather: Array = data.get("compatible_weather_ids", [])
	if compatible_weather.is_empty():
		return overlapping_weather.is_empty()
	for weather_id in overlapping_weather.keys():
		if not compatible_weather.has(str(weather_id)):
			return false
	return true


func _weather_spawn_frequency(weather_id: String, data: Dictionary, biomes: Dictionary) -> float:
	if weather_id != "snow":
		return float(data.get("spawn_frequency", 0.0))
	var frequency := float(data.get("spawn_frequency", 0.0))
	if is_night:
		frequency *= 1.2
	if biomes.has("forest") or biomes.has("forest_light"):
		frequency *= 1.15
	return frequency


func _schedule_next_spawn_check(initial_delay := -1.0) -> void:
	if initial_delay >= 0.0:
		_spawn_check_timer = initial_delay
		return
	var min_interval: float = min(weather_spawn_interval.x, weather_spawn_interval.y)
	var max_interval: float = max(weather_spawn_interval.x, weather_spawn_interval.y)
	_spawn_check_timer = _rng.randf_range(max(0.1, min_interval), max(0.1, max_interval))


func _focus_position() -> Vector2:
	if _biome_provider != null and _biome_provider.has_method("_focus_world_2d") and _provider_ready_for_world_queries():
		var provider_focus: Variant = _biome_provider.call("_focus_world_2d")
		if provider_focus is Vector2:
			return provider_focus as Vector2
	if _camera_2d != null:
		return _camera_2d.global_position
	if _biome_provider != null and _biome_provider.get("camera") != null:
		var provider_camera = _biome_provider.get("camera")
		if provider_camera is Camera2D:
			return provider_camera.global_position
		if provider_camera is Camera3D:
			return _global_3d_to_weather_2d((provider_camera as Camera3D).global_position)
	if _camera_3d != null:
		return _global_3d_to_weather_2d(_camera_3d.global_position)
	return _node_weather_position_2d(self)


func _camera_world_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2()
	var viewport_size := viewport.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	if _camera_2d == null and _camera_3d == null:
		return Rect2(_focus_position() - viewport_size * 0.5, viewport_size)
	if _camera_3d != null and _camera_2d == null:
		var world_size_3d := _camera_3d_weather_view_size(viewport_size)
		return Rect2(_focus_position() - world_size_3d * 0.5, world_size_3d)
	var zoom := Vector2(max(0.001, _camera_2d.zoom.x), max(0.001, _camera_2d.zoom.y))
	var world_size := Vector2(viewport_size.x / zoom.x, viewport_size.y / zoom.y)
	return Rect2(_camera_2d.global_position - world_size * 0.5, world_size)


func _global_3d_to_weather_2d(position: Vector3) -> Vector2:
	if _biome_provider != null and _biome_provider.has_method("global_3d_to_world_2d"):
		var converted: Variant = _biome_provider.call("global_3d_to_world_2d", position)
		if converted is Vector2:
			return converted as Vector2
	return Vector2(position.x, position.z)


func _provider_ready_for_world_queries() -> bool:
	if _biome_provider == null:
		return false
	var generated_value: Variant = _biome_provider.get("world_generated")
	if typeof(generated_value) == TYPE_BOOL:
		return bool(generated_value)
	return true


func _node_weather_position_2d(node: Node) -> Vector2:
	if node is Node2D:
		return (node as Node2D).global_position
	if node is Node3D:
		return _global_3d_to_weather_2d((node as Node3D).global_position)
	return Vector2.ZERO


func _camera_3d_weather_view_size(viewport_size: Vector2) -> Vector2:
	if _biome_provider != null:
		var terrain_view_tiles_value: Variant = _biome_provider.get("terrain_view_tiles")
		if typeof(terrain_view_tiles_value) == TYPE_INT or typeof(terrain_view_tiles_value) == TYPE_FLOAT:
			var view_tiles := maxf(8.0, float(terrain_view_tiles_value))
			var tile_size := _provider_tile_size()
			var square_size := view_tiles * tile_size
			return Vector2(square_size, square_size)
	var pixels_per_unit := _provider_pixels_per_3d_unit()
	var height_scale := 1.0
	if _camera_3d != null:
		height_scale = maxf(1.0, absf(_camera_3d.global_position.y))
	return Vector2(
		maxf(viewport_size.x, height_scale * pixels_per_unit),
		maxf(viewport_size.y, height_scale * pixels_per_unit)
	)


func _provider_pixels_per_3d_unit() -> float:
	if _biome_provider != null:
		var value: Variant = _biome_provider.get("pixels_per_3d_unit")
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			return maxf(1.0, float(value))
	return 16.0


func _weather_position_in_bounds(position: Vector2) -> bool:
	if _biome_provider == null:
		return true
	if not _provider_ready_for_world_queries():
		return true
	var infinite_value = _biome_provider.get("enable_infinite_runtime_tiles")
	if typeof(infinite_value) == TYPE_BOOL and infinite_value:
		return true
	var world_size_value = _biome_provider.get("world_size")
	if typeof(world_size_value) != TYPE_VECTOR2I:
		return true
	var tile_size := _provider_tile_size()
	var margin := weather_spawn_radius * 1.5
	var bounds := Rect2(Vector2.ZERO, Vector2(world_size_value) * tile_size).grow(margin)
	return bounds.has_point(position)


func _provider_tile_size() -> float:
	if _biome_provider != null:
		var value: Variant = _biome_provider.get("tile_size")
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			return max(1.0, float(value))
		var world_value: Variant = _biome_provider.get("world")
		if world_value is Node:
			var world_tile_size: Variant = (world_value as Node).get("tile_size")
			if typeof(world_tile_size) == TYPE_INT or typeof(world_tile_size) == TYPE_FLOAT:
				return max(1.0, float(world_tile_size))
	return DEFAULT_TILE_SIZE


func _biome_at_tile(x: int, y: int) -> String:
	if _biome_provider != null and not _provider_ready_for_world_queries():
		return "plains"
	if _biome_provider != null and _biome_provider.has_method("_biome_at"):
		return str(_biome_provider.call("_biome_at", x, y))
	if _biome_provider != null and _biome_provider.has_method("biome_at"):
		return str(_biome_provider.call("biome_at", x, y))
	if _biome_provider != null:
		var world_value: Variant = _biome_provider.get("world")
		if world_value is Node:
			var world_node := world_value as Node
			if world_node.has_method("_biome_at"):
				return str(world_node.call("_biome_at", x, y))
			if world_node.has_method("biome_at"):
				return str(world_node.call("biome_at", x, y))
	return "plains"


func _normalize_biome_id(id: String) -> String:
	if id.begins_with("biome:"):
		return id.substr(6)
	return id


func _mix_weather_color(key: String, fallback: Color) -> Color:
	var weighted := Vector3.ZERO
	var total_weight := 0.0
	for weather_id in weather_strengths.keys():
		if not WEATHER_DATABASE.has(weather_id):
			continue
		var data: Dictionary = WEATHER_DATABASE[weather_id]
		if not data.has(key):
			continue
		var strength := _quint_in_out(float(weather_strengths[weather_id]))
		var rgb: Array = data[key]
		weighted += Vector3(float(rgb[0]), float(rgb[1]), float(rgb[2])) * strength
		total_weight += strength
	if total_weight < 1.0:
		weighted += Vector3(fallback.r, fallback.g, fallback.b) * (1.0 - total_weight)
		total_weight = 1.0
	weighted /= max(0.0001, total_weight)
	return Color(weighted.x, weighted.y, weighted.z, 1.0)


func _mix_weather_float(key: String, fallback: float) -> float:
	var weighted := 0.0
	var total_weight := 0.0
	for weather_id in weather_strengths.keys():
		if not WEATHER_DATABASE.has(weather_id):
			continue
		var data: Dictionary = WEATHER_DATABASE[weather_id]
		if not data.has(key):
			continue
		var strength := _quint_in_out(float(weather_strengths[weather_id]))
		weighted += float(data[key]) * strength
		total_weight += strength
	if total_weight < 1.0:
		weighted += fallback * (1.0 - total_weight)
		total_weight = 1.0
	return weighted / max(0.0001, total_weight)


func _update_lightning(delta: float) -> void:
	lightning_flash = max(0.0, lightning_flash - delta * 3.5)
	var thunder_strength := get_weather_strength("thunder")
	if thunder_strength <= 0.15:
		_lightning_timer = min(_lightning_timer, 2.0)
		return
	_lightning_timer -= delta
	if _lightning_timer > 0.0:
		return
	lightning_flash = max(lightning_flash, _rng.randf_range(0.72, 1.0) * thunder_strength)
	_lightning_timer = _rng.randf_range(2.6, 7.5) / max(0.35, thunder_strength)


func _standard_ambient_color(hour: float) -> Color:
	var night := Vector3(23.0 / 36.0, 0.679, 0.405)
	var day := Vector3(11.0 / 72.0, 0.3, 0.698)
	var dusk := Vector3(13.0 / 180.0, 0.746, 0.659)
	var colors := []
	for i in range(48):
		if i <= 8:
			colors.append(night)
		elif i == 9:
			colors.append(Vector3(0.0016666667, 0.23, 0.58))
		elif i == 10:
			colors.append(Vector3(71.0 / (360.0 * PI), 0.53, 0.58))
		elif i == 11:
			colors.append(_hsl_lerp(Vector3(0.07388889, 0.73, 0.58), day, 0.5))
		elif i >= 12 and i <= 41:
			colors.append(day)
		elif i == 42:
			colors.append(_hsl_lerp(day, dusk, 0.5))
		elif i == 43:
			colors.append(dusk)
		elif i == 44:
			colors.append(Vector3(0.0, 0.22, 0.58))
		else:
			colors.append(night)

	var h := hour * 2.0
	var index := int(floor(h)) % colors.size()
	var next_index := (index + 1) % colors.size()
	var t: float = h - floor(h)
	var hsl: Vector3 = _hsl_lerp(colors[index], colors[next_index], t)
	return _hsl_to_rgb(hsl.x, hsl.y, hsl.z)


func _standard_sun_color_and_direction(hour: float) -> Dictionary:
	var start := Vector3(-0.16, 1.0, 1.75).normalized()
	var mid := Vector3(-0.24, 1.35, 1.24).normalized()
	var end := Vector3(-1.32, 0.6, 0.8).normalized()
	var t := (hour - 4.0) / 18.5
	if t <= 0.0 or t >= 1.0:
		return {"color": Color.BLACK, "direction": end}
	var intensity := 1.0
	if hour < 6.0:
		intensity *= _sine_in_out((hour - 4.0) / 2.0)
	elif hour > 21.0:
		intensity *= _quart_out(1.0 - ((hour - 21.0) / 1.5))
	var direction := _quadratic_bezier(start, mid * 2.0, end, t).normalized()
	return {"color": Color(intensity, intensity, intensity, 1.0), "direction": direction}


func _standard_moon_color_and_direction(hour: float) -> Dictionary:
	hour = fposmod(hour + 12.0, 24.0)
	var start := 9.0
	var fade_in_end := 10.5
	var fade_out_start := 16.5
	var end := 18.0
	var t := (hour - start) / (end - start)
	var direction := Vector3(-0.24, 1.35, 1.24).normalized()
	if t <= 0.0 or t >= 1.0:
		return {"color": Color.BLACK, "direction": direction}
	var color_vec := Vector3(0.195, 0.3325, 1.02) * 1.3
	if hour < fade_in_end:
		color_vec *= _sine_in((hour - start) / (fade_in_end - start))
	elif hour > fade_out_start:
		color_vec *= _quart_in(1.0 - ((hour - fade_out_start) / (end - fade_out_start)))
	return {"color": Color(color_vec.x, color_vec.y, color_vec.z, 1.0), "direction": direction}


func _standard_time_based_light_curve(hour: float) -> float:
	if hour <= 21.0 and hour >= 5.15:
		return 0.0
	if hour > 21.0 and hour < 23.0:
		return _smoothstep(1.0, 0.0, (23.0 - hour) / 2.0)
	if hour > 4.0 and hour < 5.15:
		return _smoothstep(0.0, 1.0, (5.15 - hour) / 1.1500001)
	return 1.0


func _hsl_to_rgb(h: float, s: float, l: float) -> Color:
	h = fposmod(h, 1.0)
	s = clamp(s, 0.0, 1.0)
	l = clamp(l, 0.0, 1.0)
	if s <= 0.0001:
		return Color(l, l, l, 1.0)
	var q := l * (1.0 + s) if l < 0.5 else l + s - l * s
	var p := 2.0 * l - q
	var r := _hue_to_rgb(p, q, h + 1.0 / 3.0)
	var g := _hue_to_rgb(p, q, h)
	var b := _hue_to_rgb(p, q, h - 1.0 / 3.0)
	return Color(r, g, b, 1.0)


func _hue_to_rgb(p: float, q: float, t: float) -> float:
	t = fposmod(t, 1.0)
	if t < 1.0 / 6.0:
		return p + (q - p) * 6.0 * t
	if t < 1.0 / 2.0:
		return q
	if t < 2.0 / 3.0:
		return p + (q - p) * (2.0 / 3.0 - t) * 6.0
	return p


func _hsl_lerp(a: Vector3, b: Vector3, t: float) -> Vector3:
	var hue_delta := fposmod(b.x - a.x + 0.5, 1.0) - 0.5
	return Vector3(fposmod(a.x + hue_delta * t, 1.0), lerp(a.y, b.y, t), lerp(a.z, b.z, t))


func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	if abs(edge1 - edge0) < 0.00001:
		return 1.0 if value >= edge1 else 0.0
	var t: float = clamp((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _quint_in_out(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	if t < 0.5:
		return 16.0 * t * t * t * t * t
	var f := -2.0 * t + 2.0
	return 1.0 - (f * f * f * f * f) / 2.0


func _sine_in(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return 1.0 - cos((t * PI) / 2.0)


func _sine_in_out(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return -(cos(PI * t) - 1.0) / 2.0


func _quart_in(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return t * t * t * t


func _quart_out(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	var f := 1.0 - t
	return 1.0 - f * f * f * f


func _quadratic_bezier(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	var inv: float = 1.0 - clamp(t, 0.0, 1.0)
	return inv * inv * a + 2.0 * inv * t * b + t * t * c


func _circular_difference(value: float, target: float, length: float) -> float:
	var delta: float = abs(fposmod(value - target + length * 0.5, length) - length * 0.5)
	return delta


func _random_point_in_circle() -> Vector2:
	var angle := _rng.randf_range(0.0, TAU)
	var distance := sqrt(_rng.randf())
	return Vector2(cos(angle), sin(angle)) * distance


func _random_unit_vector() -> Vector2:
	var angle := _rng.randf_range(0.0, TAU)
	return Vector2(cos(angle), sin(angle))
