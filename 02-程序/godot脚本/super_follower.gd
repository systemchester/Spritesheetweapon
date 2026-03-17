extends Node2D
## =============================================================================
## 超级跟随者 (SuperFollower)
## =============================================================================
## 批量生成多个跟随者的便捷节点。
## 只需设置 follow_target_path 和 sprites（贴图数组），
## 每个贴图自动生成一个 Follower/OcchaFollower，距离按 start_distance、distance_step 递增。
## 例如：sprites=[A,B,C]，start_distance=0，distance_step=24，则生成 3 个跟随者，距离分别为 0、24、48。
## 场景中需开启 y_sort_enabled 以正确显示图层前后。
## =============================================================================

@export var follow_target_path: NodePath  ## 跟随目标（如 Player）的节点路径
@export var start_distance := 0.0  ## 第一个跟随者与路径末端的距离
@export var distance_step := 24.0  ## 每个跟随者递增的距离
@export var use_occha_format := false  ## true 使用 32x64 OcchaFollower，false 使用 32x32 Follower
@export var sprites: Array[Texture2D] = []  ## 贴图数组，每个对应一个跟随者

const FOLLOWER_SCENE := preload("res://follower.tscn")
const OCCHA_FOLLOWER_SCENE := preload("res://occha_follower.tscn")

func _ready() -> void:
	if follow_target_path.is_empty():
		push_error("SuperFollower: follow_target_path 未设置")
		return

	## 遍历贴图，为每个生成一个跟随者实例
	for i in sprites.size():
		var tex: Texture2D = sprites[i]
		if not tex:
			continue

		var scene: PackedScene = OCCHA_FOLLOWER_SCENE if use_occha_format else FOLLOWER_SCENE
		var follower: Node = scene.instantiate()
		follower.name = "Follower%d" % (i + 1)

		## 重要：必须在 add_child 之前设置属性，否则子节点 _ready 时属性仍为空会报错
		var dist: float = start_distance + i * distance_step
		follower.set("follow_target_path", _path_for_child())  ## 子节点多一层，路径需加 ../
		follower.set("follow_distance", dist)
		follower.set("spritesheet", tex)

		add_child(follower)

## 子节点比 SuperFollower 多一层父级，因此到目标的路径需加 ../ 前缀
func _path_for_child() -> NodePath:
	var p := str(follow_target_path)
	if p.is_empty():
		return follow_target_path
	return NodePath("../" + p)
