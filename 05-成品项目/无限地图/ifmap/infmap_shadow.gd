extends Node2D
## 脚底阴影：程序生成椭圆半透明贴图，自包含于 ifmap 场景。

const SHADOW_W := 20
const SHADOW_H := 8

func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _build_shadow_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = -1
	sprite.position.y = 12
	sprite.scale = Vector2(0.8, 0.8)
	sprite.centered = true
	add_child(sprite)


func _build_shadow_texture() -> ImageTexture:
	var img := Image.create(SHADOW_W, SHADOW_H, false, Image.FORMAT_RGBA8)
	var cx := SHADOW_W / 2.0
	var cy := SHADOW_H / 2.0
	var rx := maxf(cx - 0.5, 0.1)
	var ry := maxf(cy - 0.5, 0.1)
	for y in SHADOW_H:
		for x in SHADOW_W:
			var dx := (x - cx) / rx
			var dy := (y - cy) / ry
			var d := dx * dx + dy * dy
			var a := 0.0
			if d <= 1.0:
				a = 0.65 * (1.0 - d * 0.4)
			img.set_pixel(x, y, Color(0, 0, 0, a))
	return ImageTexture.create_from_image(img)
