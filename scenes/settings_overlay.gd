extends Control

var _cn_font: Font = null
signal logout_requested
signal reset_requested
signal closed

var auth_token: String = ""
var user_info: Dictionary = {}

var _skip_input := false

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	if ResourceLoader.exists("res://assets/fonts/simhei.ttf"):
		_cn_font = load("res://assets/fonts/simhei.ttf") as Font

func _input(event: InputEvent):
	if not visible: return
	if _skip_input:
		_skip_input = false
		return
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT: return
	get_viewport().set_input_as_handled()
	var sw := 360.0; var sh := 280.0
	var sx := (size.x - sw) * 0.5; var sy := (size.y - sh) * 0.5
	var mx: float = mb.position.x; var my: float = mb.position.y
	if mx < sx or mx > sx + sw or my < sy or my > sy + sh:
		closed.emit(); return
	var bw := 260.0; var bh := 38.0; var bx := sx + (sw - bw) * 0.5
	if mx >= bx and mx <= bx + bw and my >= sy + 80 and my <= sy + 80 + bh:
		logout_requested.emit(); return
	if mx >= bx and mx <= bx + bw and my >= sy + 140 and my <= sy + 140 + bh:
		reset_requested.emit(); return

func _draw():
	var sw := 360.0; var sh := 280.0
	var sx := (size.x - sw) * 0.5; var sy := (size.y - sh) * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(sx, sy, sw, sh), Color(0.16, 0.14, 0.11))
	draw_rect(Rect2(sx, sy, sw, sh), Color(0.45, 0.38, 0.22), false, 3)
	draw_rect(Rect2(sx, sy, sw, 36), Color(0.3, 0.26, 0.16))
	_draw_text(sx + 140, sy + 8, "设置", 20, Color(1, 0.92, 0.75))
	_draw_text(sx + sw - 80, sy + 10, "点外部关闭", 12, Color(0.6, 0.55, 0.4))
	var bw := 260.0; var bh := 38.0; var bx := sx + (sw - bw) * 0.5
	draw_rect(Rect2(bx, sy + 80, bw, bh), Color(0.3, 0.45, 0.65))
	_draw_text(bx + 80, sy + 88, "退出登录", 18, Color(1, 1, 1))
	draw_rect(Rect2(bx, sy + 140, bw, bh), Color(0.72, 0.24, 0.2))
	_draw_text(bx + 68, sy + 148, "重置农场/新开档", 18, Color(1, 1, 1))
	_draw_text(bx + 8, sy + 200, "重置会清空所有游戏数据", 12, Color(0.65, 0.4, 0.35))
	if not auth_token.is_empty():
		var un: String = user_info.get("username", "???")
		_draw_text(bx + 8, sy + 240, "当前账号: " + un, 13, Color(0.55, 0.55, 0.5))

func _draw_text(x: float, y: float, text: String, sz: int, color: Color):
	var font: Font = (_cn_font if _cn_font != null else ThemeDB.fallback_font)
	draw_string(font, Vector2(x, y + float(sz) * 0.8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, color)
