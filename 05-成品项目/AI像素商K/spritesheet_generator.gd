extends RefCounted
## =============================================================================
## 精灵图生成器 (SpritesheetGenerator)
## =============================================================================
## 从一张精灵图自动生成 SpriteFrames，供 AnimatedSprite2D 使用。
## 布局约定：
##   - 帧尺寸：32x32
##   - Row0 = down，Row1 = right，Row2 = up
##   - 每行 4 帧
## offset_x/offset_y 用于从大图指定起始裁剪位置（支持多角色在一张图内）
## =============================================================================

const FRAME_W := 32  ## 每帧宽度（像素）
const FRAME_H := 32  ## 每帧高度（像素）
const FRAMES_PER_ROW := 4  ## 每行帧数
const ANIM_SPEED := 6.0  ## 动画播放速度（帧/秒）

## 根据精灵图生成 SpriteFrames，包含 down/right/up 三个动画
func build_sprite_frames(texture: Texture2D, offset_x: int = 32, offset_y: int = 0) -> SpriteFrames:
	var sf := SpriteFrames.new()
	var anims := [{"name": "down", "row": 0}, {"name": "right", "row": 1}, {"name": "up", "row": 2}]

	for anim in anims:
		var frames: Array[Dictionary] = []
		for col in FRAMES_PER_ROW:
			var x := offset_x + col * FRAME_W
			var y: int = offset_y + anim.row * FRAME_H
			## 用 AtlasTexture 从大图中裁出一帧
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2i(x, y, FRAME_W, FRAME_H)
			frames.append({"texture": atlas, "duration": 1.0})
		sf.add_animation(anim.name)
		for f in frames:
			sf.add_frame(anim.name, f.texture, f.duration)
		sf.set_animation_loop(anim.name, true)
		sf.set_animation_speed(anim.name, ANIM_SPEED)

	return sf
