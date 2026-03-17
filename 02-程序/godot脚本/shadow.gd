extends Node2D
## =============================================================================
## 脚底阴影 (Shadow)
## =============================================================================
## 为 32x32 角色提供的脚底椭圆形阴影。
## 用法：作为子节点挂到角色（Player/Follower）下，会自动生成并显示阴影。
## 阴影位置、大小已针对 32x32 精灵预设，无需额外配置。
## =============================================================================

const _ShadowTex := preload("res://shadow_texture.gd")

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	var gen := _ShadowTex.new()
	sprite.texture = gen.build_texture()  ## 程序生成的椭圆阴影贴图
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  ## 保持像素风
	sprite.z_index = -1  ## 在角色下方绘制
	sprite.position.y = 12  ## 相对脚底向下偏移
	sprite.scale = Vector2(0.8, 0.8)
	sprite.centered = true
