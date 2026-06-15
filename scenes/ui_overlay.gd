extends Control

## UI overlay — draws HUD / toolbar / toast in screen space, unaffected by Camera2D.

var farm_ref: Node = null

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# farm_ref 由 Farm 脚本在 _ready() 末尾设置

func _draw():
	if farm_ref == null or not is_instance_valid(farm_ref):
		return
	if farm_ref.has_method("_draw_ui"):
		farm_ref._draw_ui(self)
