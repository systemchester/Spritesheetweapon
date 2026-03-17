extends Node2D
## =============================================================================
## OCCHA 脚底阴影 (OcchaShadow)
## =============================================================================
## 为 32x64 OCCHA 角色提供的脚底阴影，支持调节位置和大小。
## 用法：作为子节点挂到 OcchaPlayer/OcchaFollower 下。
## 与 Shadow 相比，offset_y 和 shadow_scale 可导出调整，适配更高精灵。
## =============================================================================

const _ShadowTex := preload("res://shadow_texture.gd")

@export var offset_y := 13.0  ## 相对脚底的 Y 偏移，往下为正（32x64 精灵通常需更大值）
@export var shadow_scale := 1.0  ## 阴影缩放，小于 1 可减弱存在感

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	var gen := _ShadowTex.new()
	sprite.texture = gen.build_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = -1
	sprite.position.y = offset_y
	sprite.scale = Vector2(shadow_scale, shadow_scale)
	sprite.centered = true
