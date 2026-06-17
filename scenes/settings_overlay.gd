extends Control

## 设置弹窗。使用 Godot 内置容器节点构建，不再手写 _draw。

signal logout_requested
signal reset_requested
signal closed

var auth_token: String = ""
var user_info: Dictionary = {}

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visibility_changed.connect(_on_visibility_changed)
	_build()

func _on_visibility_changed():
	# 每次打开刷新账号信息
	if visible:
		_build()

func _build():
	for c in get_children():
		c.queue_free()

	var modal := UIKit.build_modal(self, Vector2(380, 0), "设置",
		Color(0.3, 0.26, 0.16), Color(0.16, 0.14, 0.11), Color(0.45, 0.38, 0.22),
		func(): closed.emit())
	var vbox: VBoxContainer = modal[1]

	var logout_btn := UIKit.make_button("退出登录", Color(0.3, 0.45, 0.65), Color(0.18, 0.3, 0.46), 18)
	logout_btn.custom_minimum_size = Vector2(0, 44)
	logout_btn.pressed.connect(func(): logout_requested.emit())
	vbox.add_child(logout_btn)

	var reset_btn := UIKit.make_button("重置农场 / 新开档", Color(0.72, 0.24, 0.2), Color(0.5, 0.14, 0.12), 18)
	reset_btn.custom_minimum_size = Vector2(0, 44)
	reset_btn.pressed.connect(func(): reset_requested.emit())
	vbox.add_child(reset_btn)

	vbox.add_child(UIKit.make_label("重置会清空所有游戏数据", 13, Color(0.7, 0.45, 0.4)))

	if not auth_token.is_empty():
		var un: String = user_info.get("username", "???")
		vbox.add_child(UIKit.make_label("当前账号: " + un, 13, Color(0.6, 0.6, 0.55)))
