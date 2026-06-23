extends Control

## 背包弹窗。GridContainer + ScrollContainer + 物品卡片，全部用内置节点。

var CROPS: Array = []
var CROP_COLORS: Array = []
var crop_catalog: CropCatalog = null
var inventory: Dictionary = {}:
	set(value):
		inventory = value
		if is_inside_tree():
			_rebuild_items()

signal sell_requested(crop_id: int, amount: int)
signal sell_all_requested
signal closed

var _grid: GridContainer = null
var _empty_lbl: Label = null

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()

func _build():
	for c in get_children():
		c.queue_free()
	_grid = null
	_empty_lbl = null

	var modal := UIKit.build_modal(self, Vector2(820, 560), "我的背包 (售出换金币)",
		Color(0.35, 0.15, 0.4), Color(0.93, 0.89, 0.96), Color(0.4, 0.18, 0.45),
		func(): closed.emit())
	var vbox: VBoxContainer = modal[1]

	# 顶部操作栏：全部卖出
	var topbar := HBoxContainer.new()
	topbar.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(topbar)
	var sell_all := UIKit.make_button("全部卖出", Color(0.65, 0.28, 0.18), Color(0.45, 0.18, 0.1), 15)
	sell_all.pressed.connect(func(): sell_all_requested.emit())
	topbar.add_child(sell_all)

	# 滚动区 + 网格
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	_empty_lbl = UIKit.make_label("背包是空的", 20, Color(0.5, 0.4, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	_empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_empty_lbl)

	_rebuild_items()

func _rebuild_items():
	if _grid == null:
		return
	for c in _grid.get_children():
		c.queue_free()

	var has_any := false
	for cid in inventory.keys():
		var cnt := int(inventory.get(cid, 0))
		if cnt <= 0:
			continue
		has_any = true
		_grid.add_child(_make_card(int(cid), cnt))

	if _empty_lbl:
		_empty_lbl.visible = not has_any

func _make_card(cid: int, cnt: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(150, 0)
	card.add_theme_stylebox_override("panel", UIKit.card_box(Color(0.86, 0.81, 0.91), Color(0.5, 0.3, 0.55)))

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	card.add_child(m)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	m.add_child(box)

	# 色块图标
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(0, 40)
	icon.color = _crop_color(cid, 1)
	box.add_child(icon)

	box.add_child(UIKit.make_label(_crop_name(cid), 16, Color(0.1, 0.1, 0.2), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.make_label("数量: " + str(cnt), 14, Color(0.3, 0.2, 0.4), HORIZONTAL_ALIGNMENT_CENTER))

	# 卖出按钮行
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var sell1 := UIKit.make_button("卖出", Color(0.8, 0.6, 0.1), Color(0.55, 0.4, 0.05), 13)
	sell1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell1.pressed.connect(func(): sell_requested.emit(cid, 1))
	row.add_child(sell1)
	var sellall := UIKit.make_button("全卖", Color(0.65, 0.28, 0.18), Color(0.45, 0.18, 0.1), 13)
	sellall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sellall.pressed.connect(func(): sell_requested.emit(cid, cnt))
	row.add_child(sellall)

	if _crop_is_valid(cid):
		var price := "x" + str(_crop_unit_sell(cid)) + " 金/个"
		box.add_child(UIKit.make_label(price, 11, Color(0.5, 0.4, 0.1), HORIZONTAL_ALIGNMENT_CENTER))

	return card

func _crop_is_valid(cid: int) -> bool:
	return crop_catalog.is_valid_id(cid) if crop_catalog != null else cid >= 0 and CROPS.size() > cid

func _crop_name(cid: int) -> String:
	return crop_catalog.get_name(cid) if crop_catalog != null else (str(CROPS[cid][0]) if cid >= 0 and CROPS.size() > cid else "作物" + str(cid))

func _crop_unit_sell(cid: int) -> int:
	return crop_catalog.get_unit_sell(cid) if crop_catalog != null else (int(CROPS[cid][6]) if cid >= 0 and CROPS.size() > cid else 0)

func _crop_color(cid: int, color_index: int) -> Color:
	if cid >= 0 and cid < CROP_COLORS.size():
		var colors = CROP_COLORS[cid]
		if colors is Array and color_index >= 0 and color_index < colors.size():
			return colors[color_index]
	return Color(0.42, 0.76, 0.34) if color_index == 0 else Color(0.72, 0.96, 0.46)
