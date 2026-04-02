shader_type canvas_item;
// 地面透视 — 单公式零分支，不存在接缝/扭曲带。
//
// 把「相机」放在玩家南方 cam_dist 处。整个可见区域对相机而言都是「前方」。
// 深度 z = cam_dist + (pivot.y - world.y)，对最南端可见 tile 也 > 0。
// 缩放 s = cam_height / (cam_height + z * strength)，全程 C∞ 平滑。
// s 在相机处最大（近处），随 z 增大单调递减（远处变小）。

uniform vec2 pivot_world = vec2(0.0);

// 虚拟相机高度：越大整体压缩越弱（类似拉远镜头）
uniform float cam_height : hint_range(100.0, 3000.0) = 100.0;
// 相机在玩家南方多远（世界单位）；越大近处放大越弱、远近差越小
uniform float cam_dist : hint_range(50.0, 1500.0) = 200.0;
// 深度乘数：越大远近反差越明显
uniform float strength : hint_range(0.0, 3.0) = 0.95;
// 地图基础缩放：透视会整体缩小地图，用这个补回来。1.0=不补偿，>1 放大地图
uniform float base_scale : hint_range(0.5, 5.0) = 2.9;

// 远景最小缩放（防止极远处退化为 0）
uniform float s_min : hint_range(0.02, 0.5) = 0.08;
// 横向偏航
uniform float ground_skew : hint_range(-0.15, 0.15) = 0.0;

varying vec4 v_uvq;
varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;

	// z：该点到虚拟相机的「地面前向距离」；cam_dist 保证即使最南端 tile 也 > 0
	float z = cam_dist + (pivot_world.y - world.y);
	float s = base_scale * cam_height / (cam_height + max(z, 0.0) * strength);
	s = max(s, s_min);

	// 齐次 UV 透视校正
	float q = 1.0 / max(s, 1e-4);
	v_uvq = vec4(UV * q, 0.0, q);

	// 缩放中心 = pivot（玩家位置）
	vec2 new_world;
	new_world.x = pivot_world.x + (world.x - pivot_world.x) * s + (pivot_world.y - world.y) * ground_skew;
	new_world.y = pivot_world.y + (world.y - pivot_world.y) * s;
	VERTEX += new_world - world;
}

void fragment() {
	vec2 uv_p = v_uvq.xy / max(v_uvq.w, 1e-5);
	COLOR = texture(TEXTURE, uv_p) * v_modulate;
}
