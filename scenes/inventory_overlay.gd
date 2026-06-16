extends Control

var _cn_font: Font = null
var CROPS: Array = []
var CROP_COLORS: Array = []
var inventory: Dictionary = {}

signal sell_requested(crop_id: int, amount: int)
signal sell_all_requested
signal closed

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
	var pw := 980.0; var ph := 620.0
	var px := (size.x - pw) * 0.5; var py := (size.y - ph) * 0.5
	var mx: float = mb.position.x; var my: float = mb.position.y
	if mx < px or mx > px + pw or my < py or my > py + ph:
		closed.emit(); return
	if mx >= px + 765 and mx <= px + 925 and my >= py + 50 and my <= py + 80:
		sell_all_requested.emit(); return
	var keys = inventory.keys(); var ic := 0
	for cid in keys:
		if inventory.has(cid) and inventory[cid] > 0:
			var col = ic % 5; var row = ic / 5
			var sx = px + 50 + col * 150; var sy = py + 70 + row * 190
			if mx >= sx + 18 and mx <= sx + 67 and my >= sy + 123 and my <= sy + 148:
				sell_requested.emit(int(cid), 1); return
			if mx >= sx + 73 and mx <= sx + 122 and my >= sy + 123 and my <= sy + 148:
				sell_requested.emit(int(cid), int(inventory.get(cid, 0))); return
		ic += 1

func _draw():
	var pw := 980.0; var ph := 620.0
	var px := (size.x - pw) * 0.5; var py := (size.y - ph) * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(px, py, pw, ph), Color(0.9, 0.86, 0.94))
	draw_rect(Rect2(px, py, pw, ph), Color(0.4, 0.18, 0.45), false, 4)
	draw_rect(Rect2(px, py, pw, 45), Color(0.35, 0.15, 0.4))
	_draw_text(px + 330, py + 7, "我的背包 (售出换金币)", 24, Color(1, 0.9, 0.95))
	_draw_text(px + pw - 80, py + 12, "点击外部关闭", 13, Color(0.85, 0.75, 0.9))
	draw_rect(Rect2(px + 765, py + 50, 160, 30), Color(0.65, 0.28, 0.18))
	_draw_text(px + 802, py + 55, "全部卖出", 15, Color(1, 1, 1))
	var keys = inventory.keys(); var is_empty = true; var ic := 0
	for cid in keys:
		if inventory[cid] > 0:
			is_empty = false
			var col = ic % 5; var row = ic / 5
			var sx = px + 50 + col * 150; var sy = py + 70 + row * 190
			draw_rect(Rect2(sx, sy, 140, 172), Color(0.85, 0.8, 0.9))
			draw_rect(Rect2(sx, sy, 140, 172), Color(0.5, 0.3, 0.55), false, 2)
			if CROP_COLORS.size() > int(cid):
				draw_circle(Vector2(sx + 70, sy + 40), 20, CROP_COLORS[int(cid)][1])
				draw_circle(Vector2(sx + 63, sy + 35), 6, Color(1,1,1,0.3))
			if CROPS.size() > int(cid):
				var nm := str(CROPS[int(cid)][0])
				var nw = (_cn_font if _cn_font != null else ThemeDB.fallback_font).get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
				_draw_text(sx + 70 - nw * 0.5, sy + 70, nm, 16, Color(0.1, 0.1, 0.2))
				var at := "数量: " + str(inventory[cid])
				var aw = (_cn_font if _cn_font != null else ThemeDB.fallback_font).get_string_size(at, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
				_draw_text(sx + 70 - aw * 0.5, sy + 95, at, 14, Color(0.3, 0.2, 0.4))
				draw_rect(Rect2(sx + 18, sy + 123, 49, 25), Color(0.8, 0.6, 0.1))
				_draw_text(sx + 26, sy + 127, "卖出", 13, Color(1,1,1))
				draw_rect(Rect2(sx + 73, sy + 123, 49, 25), Color(0.65, 0.28, 0.18))
				_draw_text(sx + 81, sy + 127, "全卖", 13, Color(1,1,1))
				var pt := "(x" + str(int(CROPS[int(cid)][6])) + "金/个)"
				var pw2 = (_cn_font if _cn_font != null else ThemeDB.fallback_font).get_string_size(pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
				_draw_text(sx + 70 - pw2 * 0.5, sy + 152, pt, 10, Color(0.5, 0.4, 0.1))
		ic += 1
	if is_empty:
		_draw_text(px + pw * 0.5 - 60, py + ph * 0.5, "背包是空的", 20, Color(0.5, 0.4, 0.6))

func _draw_text(x: float, y: float, text: String, sz: int, color: Color):
	var font: Font = (_cn_font if _cn_font != null else ThemeDB.fallback_font)
	draw_string(font, Vector2(x, y + float(sz) * 0.8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, color)
