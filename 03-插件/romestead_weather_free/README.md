# Romestead Weather Free

这是一个独立的 Godot 2D/3D 天气与日夜系统分享包。它从 NPC 插件里的天气功能拆分而来，不依赖 NPC 插件；复制整个 `romestead_weather_free` 文件夹到任意 Godot 4 项目的 `res://` 下即可使用。

## 包内文件

```text
romestead_weather_free/
  weather_system.tscn
  romestead_environment_system.gd
  romestead_environment_overlay.gd
  assets/weather/
    water_drop.png
    water_splash.png
  README.md
  LICENSE.txt
```

雪花为程序化绘制，不需要额外贴图；雨滴和水花使用 `assets/weather` 下的小贴图。

## 快速使用

1. 把整个 `romestead_weather_free` 文件夹复制到项目 `res://` 根目录。
2. 在 2D 或 3D 场景里实例化 `res://romestead_weather_free/weather_system.tscn`。
3. 也可以手动新建一个 `Node`，挂载 `res://romestead_weather_free/romestead_environment_system.gd`。
4. 如果有相机，把 `camera_path` 指向当前 `Camera2D` 或 `Camera3D`。
5. 需要立刻看到效果时，打开 `seed_initial_weather` 并把 `initial_weather_id` 设为 `rainy`、`thunder` 或 `snow`。

## 预览热键

- `Shift+1`：清除天气。
- `Shift+2`：切到雨天。
- `Shift+3`：切到雷暴。
- `Shift+4`：切到下雪。
- `Shift+5`：跳到 `05:30`。
- `Shift+6`：跳到 `12:00`。
- `Shift+7`：跳到 `21:30`。
- `Shift+8`：跳到 `23:30`。
- `Shift+9`：跳到下一天 `06:00`。

如需禁用热键，把 `enable_preview_hotkeys` 设为 `false`。

## Inspector 参数

- `camera_path`：当前 `Camera2D` 或 `Camera3D`。
- `biome_provider_path`：可选。指向提供 `_biome_at(x, y)`、`biome_at(x, y)` 或 `global_3d_to_world_2d(position)` 的节点。
- `show_screen_overlay`：是否显示屏幕天气覆盖层。
- `anchor_precipitation_to_world`：雨雪锚定到世界坐标，角色/镜头移动时不会贴屏跟随。
- `rain_fall_direction`：雨滴下落方向。
- `rain_streak_length`：雨线长度。
- `snow_fall_direction`：雪花下落方向。
- `snowflake_size`：雪花大小。
- `snow_density`：雪花密度。
- `snow_depth_feel`：雪的前后景层次感。
- `snow_foreground_glow`：前景雪花柔光强度。
- `snow_drift_strength`：雪花横向飘动强度。
- `snow_fall_speed`：雪花下落速度。

## 常用 API

```gdscript
@onready var environment: Node = $Environment

func _ready() -> void:
	environment.set_hour(21.5)
	environment.spawn_weather_at_focus("snow", 1600.0, 240.0, Vector2.ZERO, true)
	environment.dominant_weather_changed.connect(_on_weather_changed)

func _on_weather_changed(weather_id: String, strength: float) -> void:
	print("Weather: ", weather_id, " strength=", strength)
```

常用天气 id：

- `rainy`
- `thunder`
- `snow`

常用方法：

- `set_hour(hour)`：设置当前小时。
- `skip_to_next_day(hour)`：跳到下一天指定小时。
- `spawn_weather_at_focus(weather_id, radius, duration, velocity, replace_existing)`：在镜头中心生成天气。
- `clear_weather()`：清除所有天气实例。
- `get_weather_strength(weather_id)`：读取某种天气的当前镜头强度。
- `get_weather_summary()`：读取时间、夜晚状态、主天气、风力、湿度等汇总信息。

## 分享提示

这个文件夹可以单独打包分享。使用者不需要复制 NPC 插件，也不需要复制 `AI资源库`。
