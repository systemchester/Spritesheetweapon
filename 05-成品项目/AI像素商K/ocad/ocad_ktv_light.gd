extends Node2D
## =============================================================================
## Ocad KTV 五彩射灯 (OcadKTVLight)
## =============================================================================
## 类似 KTV 的旋转五彩射灯效果，像素风格。
## 可挂到场景中，设置 position 和 radius 调节位置与范围。
## =============================================================================

@export var radius := 400.0  ## 射灯照射半径
@export var rotation_speed := 0.5  ## 旋转速度（弧度/秒）
@export var beam_count := 6  ## 光束数量
@export var base_alpha := 0.25  ## 基础透明度
@export var pixel_scale := 8.0  ## 像素块大小，越大越像素风

const _COLORS := [
	Color(1.0, 0.2, 0.2),   ## 红
	Color(0.2, 0.4, 1.0),   ## 蓝
	Color(0.2, 1.0, 0.4),   ## 绿
	Color(1.0, 0.9, 0.2),   ## 黄
	Color(1.0, 0.3, 0.8),   ## 品红
	Color(0.2, 1.0, 0.9),   ## 青
]

var _angle := 0.0

func _process(delta: float) -> void:
	_angle += delta * rotation_speed
	queue_redraw()

func _draw() -> void:
	var beam_angle: float = TAU / beam_count
	for i in beam_count:
		var col: Color = _COLORS[i % _COLORS.size()]
		var start_angle: float = _angle + i * beam_angle
		_draw_pixel_beam(start_angle, start_angle + beam_angle, col)

func _draw_pixel_beam(start_angle: float, end_angle: float, base_color: Color) -> void:
	## 用阶梯状同心环绘制光束，像素风渐变（避免自交以保证三角化成功）
	var steps: int = maxi(4, int(radius / pixel_scale))
	var seg: int = 16  ## 扇形分段，足够平滑
	for s in steps:
		var r0: float = maxf(pixel_scale * 0.5, s * pixel_scale)
		var r1: float = minf((s + 1) * pixel_scale, radius)
		if r0 >= r1:
			continue
		var alpha: float = base_alpha * (1.0 - float(s) / float(steps))
		var c: Color = base_color
		c.a = alpha
		var pts := PackedVector2Array()
		pts.append(Vector2.ZERO)
		for i in seg + 1:
			var a: float = start_angle + (end_angle - start_angle) * float(i) / float(seg)
			pts.append(Vector2(cos(a) * r0, sin(a) * r0))
		for i in range(seg, -1, -1):
			var a: float = start_angle + (end_angle - start_angle) * float(i) / float(seg)
			pts.append(Vector2(cos(a) * r1, sin(a) * r1))
		if pts.size() >= 3:
			draw_colored_polygon(pts, c)
