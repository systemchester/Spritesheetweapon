extends AudioStreamPlayer

func _ready():
	# 停止自动播放（如果在编辑器里勾选了 Autoplay，建议取消）
	stop()
	
	# 创建一个 10 秒的倒计时，并等待它结束
	await get_tree().create_timer(10.0).timeout
	
	# 倒计时结束后播放音乐
	play()
