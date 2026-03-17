extends RefCounted
## =============================================================================
## 阴影贴图生成器 (ShadowTexture)
## =============================================================================
## 程序生成一张椭圆形的半透明阴影贴图，供 Shadow/OcchaShadow 使用。
## 原理：遍历每个像素，根据到椭圆中心的归一化距离计算透明度，
## 中心较亮、边缘渐隐，形成柔和脚底阴影效果。
## =============================================================================

const SHADOW_W := 20  ## 阴影贴图宽度
const SHADOW_H := 8   ## 阴影贴图高度（椭圆形，高较窄）

func build_texture() -> ImageTexture:
	var img := Image.create(SHADOW_W, SHADOW_H, false, Image.FORMAT_RGBA8)
	var cx := SHADOW_W / 2.0
	var cy := SHADOW_H / 2.0
	var rx := maxf(cx - 0.5, 0.1)  ## 椭圆 x 半径
	var ry := maxf(cy - 0.5, 0.1)  ## 椭圆 y 半径

	## 椭圆方程： (x-cx)²/rx² + (y-cy)²/ry² <= 1 时在椭圆内
	for y in SHADOW_H:
		for x in SHADOW_W:
			var dx := (x - cx) / rx
			var dy := (y - cy) / ry
			var d := dx * dx + dy * dy  ## 归一化距离平方
			var a := 0.0
			if d <= 1.0:
				a = 0.65 * (1.0 - d * 0.4)  ## 中心不透明，边缘渐隐
			img.set_pixel(x, y, Color(0, 0, 0, a))

	return ImageTexture.create_from_image(img)
