extends RefCounted
## =============================================================================
## OCCHA 精灵图生成器 (OcchaSpritesheetGenerator)
## =============================================================================
## OCCHA 场景专用，从精灵图生成 SpriteFrames。
## 布局约定：
##   - 帧尺寸：32x64（比普通 32x32 更高）
##   - Row0 = DOWN，Row1 = LEFT，Row2 = UP
##   - 每行 6 帧
##   - STAND 站立动画使用 DOWN 的第一帧
## =============================================================================

const FRAME_W := 32
const FRAME_H := 64
const FRAMES_PER_ROW := 6
const ANIM_SPEED := 7.0

func build_sprite_frames(texture: Texture2D, offset_x: int = 0, offset_y: int = 0) -> SpriteFrames:
	var sf := SpriteFrames.new()
	var anims := [
		{"name": "DOWN", "row": 0},
		{"name": "LEFT", "row": 1},
		{"name": "UP", "row": 2},
	]

	var stand_texture: Texture2D  ## 保存 DOWN 第一帧，用于 STAND
	for anim in anims:
		var frames: Array[Dictionary] = []
		for col in FRAMES_PER_ROW:
			var x: int = offset_x + col * FRAME_W
			var y: int = offset_y + anim.row * FRAME_H
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2i(x, y, FRAME_W, FRAME_H)
			frames.append({"texture": atlas, "duration": 1.0})
		if anim.name == "DOWN":
			stand_texture = frames[0].texture
		sf.add_animation(anim.name)
		for f in frames:
			sf.add_frame(anim.name, f.texture, f.duration)
		sf.set_animation_loop(anim.name, true)
		sf.set_animation_speed(anim.name, ANIM_SPEED)

	## STAND 站立：复用 DOWN 第一帧，无需单独绘制
	sf.add_animation("STAND")
	sf.add_frame("STAND", stand_texture, 1.0)
	sf.set_animation_loop("STAND", true)
	sf.set_animation_speed("STAND", ANIM_SPEED)

	return sf
