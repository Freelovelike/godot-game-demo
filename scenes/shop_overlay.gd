extends Control

var _cn_font: Font = null
var CROPS: Array = []
var CROP_COLORS: Array = []
var FERTILIZERS: Array = []
var inventory: Dictionary = {}
var fertilizer_inventory: Dictionary = {}
var selected_seed: int = -1
var selected_fertilizer: int = -1

signal seed_selected(index: int)
signal fertilizer_selected(index: int)
signal crop_sell_requested(crop_id: int, amount: int)
signal fertilizer_buy_requested(fert_id: int)
signal closed

var _tab: int = 0

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

func _draw():
	var pw := 980.0; var ph := 720.0
	var px := (size.x - pw) * 0.5
	var py := (size.y - ph) * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var panel := Rect2(px, py, pw, ph)
	draw_rect(panel, Color(0.94, 0.9, 0.78))
	draw_rect(panel, Color(0.48, 0.32, 0.12), false, 4)
	var tab_names := ["种子", "肥料"]
	for ti in range(2):
		var tx := px + 30.0 + ti * 120.0
		var tc := Color(0.58, 0.42, 0.15) if _tab == ti else Color(0.38, 0.26, 0.10)
		draw_rect(Rect2(tx, py + 4, 108, 36), tc)
		_draw_text(tx + 28, py + 12, tab_names[ti], 18, Color(1, 0.92, 0.7) if _tab == ti else Color(0.7, 0.6, 0.45))
	_draw_text(px + pw - 80, py + 12, "点击外部关闭", 13, Color(0.75, 0.68, 0.55))
	if _tab == 0:
		_draw_seed_tab(px, py)
	else:
		_draw_fert_tab(px, py)

func _draw_seed_tab(px: float, py: float):
	draw_rect(Rect2(px + 20, py + 60, 940, 30), Color(0.58, 0.48, 0.28))
	_draw_text(px + 70, py + 65, "名称", 14, Color(1, 1, 1))
	_draw_text(px + 250, py + 65, "种子价", 14, Color(1, 1, 1))
	_draw_text(px + 390, py + 65, "产量x单价", 14, Color(1, 1, 1))
	_draw_text(px + 530, py + 65, "生长时间", 14, Color(1, 1, 1))
	_draw_text(px + 680, py + 65, "利润", 14, Color(1, 1, 1))
	_draw_text(px + 768, py + 65, "操作", 14, Color(1, 1, 1))
	for i in range(CROPS.size()):
		var iy: float = py + 100.0 + float(i) * 48.0
		var bg := Color(0.88, 0.83, 0.68) if i % 2 == 0 else Color(0.91, 0.86, 0.73)
		draw_rect(Rect2(px + 20, iy, 940, 42), bg)
		if CROP_COLORS.size() > i:
			draw_circle(Vector2(px + 60, iy + 22), 9, CROP_COLORS[i][1])
		_draw_text(px + 80, iy + 6, str(CROPS[i][0]), 15, Color(0.08, 0.08, 0.08))
		_draw_text(px + 250, iy + 10, str(int(CROPS[i][1])) + " 金币", 13, Color(0.75, 0.25, 0.08))
		var yld := str(int(CROPS[i][5])) + "x" + str(int(CROPS[i][6]))
		_draw_text(px + 390, iy + 10, yld + " 金币", 13, Color(0.08, 0.55, 0.08))
		_draw_text(px + 530, iy + 10, str(int(CROPS[i][3])) + " 秒", 13, Color(0.18, 0.18, 0.5))
		var profit: int = int(CROPS[i][5]) * int(CROPS[i][6]) - int(CROPS[i][1])
		_draw_text(px + 680, iy + 10, "+" + str(profit), 14, Color(0, 0.55, 0))
		draw_rect(Rect2(px + 750, iy + 7, 58, 26), Color(0.22, 0.62, 0.28))
		_draw_text(px + 762, iy + 11, "购买", 13, Color(1, 1, 1))
		draw_rect(Rect2(px + 814, iy + 7, 58, 26), Color(0.76, 0.50, 0.12))
		_draw_text(px + 826, iy + 11, "卖出", 13, Color(1, 1, 1))
		draw_rect(Rect2(px + 878, iy + 7, 70, 26), Color(0.62, 0.24, 0.18))
		_draw_text(px + 886, iy + 11, "全卖", 13, Color(1, 1, 1))
	var sy0 := py + 540.0
	draw_rect(Rect2(px + 20, sy0 - 6, 940, 2), Color(0.6, 0.5, 0.3))
	_draw_text(px + 30, sy0 + 4, "选择种植种子:", 14, Color(0.3, 0.22, 0.1))
	var sgy := sy0 + 30
	for i in range(CROPS.size()):
		var ci := i % 5; var ri := i / 5
		var sx := px + 30.0 + ci * 185.0
		var sy := sgy + ri * 58.0
		if selected_seed == i:
			draw_rect(Rect2(sx - 3, sy - 3, 180, 52), Color(0.2, 0.7, 0.2, 0.3))
			draw_rect(Rect2(sx - 3, sy - 3, 180, 52), Color(0.15, 0.6, 0.15), false, 2)
		else:
			draw_rect(Rect2(sx, sy, 174, 46), Color(0.82, 0.78, 0.65))
		if CROP_COLORS.size() > i:
			draw_circle(Vector2(sx + 22, sy + 22), 10, CROP_COLORS[i][1])
		_draw_text(sx + 46, sy + 4, str(CROPS[i][0]), 15, Color(0.1, 0.1, 0.1))
		_draw_text(sx + 46, sy + 24, str(int(CROPS[i][1])) + "金", 11, Color(0.4, 0.35, 0.2))

func _draw_fert_tab(px: float, py: float):
	draw_rect(Rect2(px + 20, py + 60, 940, 30), Color(0.28, 0.42, 0.18))
	_draw_text(px + 70, py + 65, "名称", 14, Color(1, 1, 1))
	_draw_text(px + 250, py + 65, "价格", 14, Color(1, 1, 1))
	_draw_text(px + 370, py + 65, "说明", 14, Color(1, 1, 1))
	_draw_text(px + 768, py + 65, "操作", 14, Color(1, 1, 1))
	var desc := ["生长-8%", "生长-12%", "生长-18%", "2h不缺水", "2h不生虫", "2h不长草", "产量+10%"]
	for i in range(FERTILIZERS.size()):
		var fy := py + 100.0 + float(i) * 56.0
		var fb := Color(0.82, 0.90, 0.78) if i % 2 == 0 else Color(0.88, 0.94, 0.84)
		draw_rect(Rect2(px + 20, fy, 940, 50), fb)
		_draw_text(px + 70, fy + 6, str(FERTILIZERS[i][0]), 15, Color(0.08, 0.08, 0.08))
		_draw_text(px + 250, fy + 6, str(int(FERTILIZERS[i][1])) + "金", 13, Color(0.75, 0.25, 0.08))
		_draw_text(px + 370, fy + 6, desc[i] if i < desc.size() else "", 12, Color(0.25, 0.3, 0.2))
		var h := int(fertilizer_inventory.get(i, 0))
		var hint := "  [已选中]" if selected_fertilizer == i else ""
		_draw_text(px + 370, fy + 28, "已有:" + str(h) + "个" + hint, 11, Color(0.4, 0.5, 0.35))
		draw_rect(Rect2(px + 750, fy + 10, 70, 28), Color(0.22, 0.58, 0.28))
		_draw_text(px + 758, fy + 16, "购买", 14, Color(1, 1, 1))
		draw_rect(Rect2(px + 828, fy + 10, 70, 28), Color(0.3, 0.55, 0.78))
		_draw_text(px + 836, fy + 16, "选择", 14, Color(1, 1, 1))

func _input(event: InputEvent):
	if not visible: return
	if _skip_input:
		_skip_input = false
		return
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT: return
	if not mb.pressed: return
	get_viewport().set_input_as_handled()
	var pw := 980.0; var ph := 720.0
	var px := (size.x - pw) * 0.5; var py := (size.y - ph) * 0.5
	var mx: float = mb.position.x; var my: float = mb.position.y
	if mx < px or mx > px + pw or my < py or my > py + ph:
		closed.emit(); return
	if my >= py + 4 and my <= py + 40:
		if mx >= px + 30 and mx <= px + 138: _tab = 0; queue_redraw(); return
		elif mx >= px + 150 and mx <= px + 258: _tab = 1; queue_redraw(); return
	if _tab == 0: _handle_seed(mx, my, px, py)
	else: _handle_fert(mx, my, px, py)

func _handle_seed(mx: float, my: float, px: float, py: float):
	var si := int((my - py - 100) / 48)
	if my >= py + 100 and my < py + 100 + CROPS.size() * 48 and si >= 0 and si < CROPS.size():
		if mx >= px + 750 and mx <= px + 808: seed_selected.emit(si)
		elif mx >= px + 814 and mx <= px + 872: crop_sell_requested.emit(si, 1)
		elif mx >= px + 878 and mx <= px + 948: crop_sell_requested.emit(si, int(inventory.get(si, 0)))
	var sy0 := py + 570.0
	if my >= sy0:
		for i in range(CROPS.size()):
			var ci := i % 5; var ri := i / 5
			var sx := px + 30.0 + ci * 185.0; var sy := sy0 + ri * 58.0
			if mx >= sx and mx <= sx + 180 and my >= sy and my <= sy + 52:
				seed_selected.emit(i); break

func _handle_fert(mx: float, my: float, px: float, py: float):
	if my < py + 100: return
	var fi := int((my - py - 100) / 56)
	if fi < 0 or fi >= FERTILIZERS.size(): return
	if mx >= px + 750 and mx <= px + 820: fertilizer_buy_requested.emit(fi)
	elif mx >= px + 828 and mx <= px + 898: fertilizer_selected.emit(fi)

func _draw_text(x: float, y: float, text: String, sz: int, color: Color):
	var font: Font = _cn_font if _cn_font != null else ThemeDB.fallback_font
	draw_string(font, Vector2(x, y + float(sz) * 0.8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, color)
