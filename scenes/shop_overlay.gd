extends Control

## 商店弹窗。TabContainer(种子/肥料) + ScrollContainer 列表，全部内置节点。

var CROPS: Array = []
var CROP_COLORS: Array = []
var FERTILIZERS: Array = []
var crop_catalog: CropCatalog = null
var fertilizer_catalog: FertilizerCatalog = null
var inventory: Dictionary = {}:
	set(v):
		inventory = v
		_refresh_dynamic()
var fertilizer_inventory: Dictionary = {}:
	set(v):
		fertilizer_inventory = v
		_refresh_dynamic()
var selected_seed: int = -1:
	set(v):
		selected_seed = v
		_refresh_dynamic()
var selected_fertilizer: int = -1:
	set(v):
		selected_fertilizer = v
		_refresh_dynamic()

signal seed_selected(index: int)
signal fertilizer_selected(index: int)
signal crop_sell_requested(crop_id: int, amount: int)
signal fertilizer_buy_requested(fert_id: int)
signal closed

const FERT_DESC := ["生长-8%", "生长-12%", "生长-18%", "2h不缺水", "2h不生虫", "2h不长草", "产量+10%"]

var _seed_grid: GridContainer = null
var _seed_chip_box: HBoxContainer = null # 复用 GridContainer 放选择 chip
var _fert_list: VBoxContainer = null
var _seed_chips: Array = [] # PanelContainer per crop
var _fert_rows: Array = []  # Label(已有/已选) per fert

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visibility_changed.connect(func():
		# 数据(CROPS/FERTILIZERS)由父节点在子节点 _ready 之后才填充，
		# 故在每次打开时重建，确保列表完整。
		if visible:
			_build()
	)
	_build()

func _build():
	for c in get_children():
		c.queue_free()
	_seed_grid = null
	_seed_chip_box = null
	_fert_list = null
	_seed_chips.clear()
	_fert_rows.clear()

	var modal := UIKit.build_modal(self, Vector2(900, 640), "商店",
		Color(0.48, 0.32, 0.12), Color(0.94, 0.9, 0.78), Color(0.48, 0.32, 0.12),
		func(): closed.emit())
	var vbox: VBoxContainer = modal[1]

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 18)
	vbox.add_child(tabs)

	var seed_tab := _build_seed_tab()
	seed_tab.name = "种子"
	tabs.add_child(seed_tab)

	var fert_tab := _build_fert_tab()
	fert_tab.name = "肥料"
	tabs.add_child(fert_tab)

	_refresh_dynamic()

func _build_seed_tab() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)

	# 列表区
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	_seed_grid = grid

	# 表头
	for h in ["名称", "种子价", "产量x单价", "生长", "利润", "操作"]:
		grid.add_child(UIKit.make_label(h, 14, Color(0.3, 0.22, 0.1)))

	for i in range(CROPS.size()):
		_add_seed_row(grid, i)

	# 底部：选择种植种子
	root.add_child(HSeparator.new())
	root.add_child(UIKit.make_label("选择种植种子:", 14, Color(0.3, 0.22, 0.1)))
	var chip_grid := GridContainer.new()
	chip_grid.columns = 5
	chip_grid.add_theme_constant_override("h_separation", 8)
	chip_grid.add_theme_constant_override("v_separation", 8)
	root.add_child(chip_grid)
	for i in range(CROPS.size()):
		var chip := _make_seed_chip(i)
		chip_grid.add_child(chip)
		_seed_chips.append(chip)

	return root

func _add_seed_row(grid: GridContainer, i: int):
	# 名称 + 色点
	var name_box := HBoxContainer.new()
	name_box.add_theme_constant_override("separation", 6)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(16, 16)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.color = _crop_color(i, 1)
	name_box.add_child(dot)
	name_box.add_child(UIKit.make_label(_crop_name(i), 15, Color(0.08, 0.08, 0.08)))
	grid.add_child(name_box)

	grid.add_child(UIKit.make_label(str(_crop_seed_cost(i)) + " 金", 13, Color(0.75, 0.25, 0.08)))
	grid.add_child(UIKit.make_label(str(_crop_base_yield(i)) + "x" + str(_crop_unit_sell(i)), 13, Color(0.08, 0.55, 0.08)))
	grid.add_child(UIKit.make_label(str(int(_crop_grow_time(i))) + "秒", 13, Color(0.18, 0.18, 0.5)))
	var profit: int = _crop_base_yield(i) * _crop_unit_sell(i) - _crop_seed_cost(i)
	grid.add_child(UIKit.make_label("+" + str(profit), 14, Color(0, 0.55, 0)))

	# 操作按钮
	var ops := HBoxContainer.new()
	ops.add_theme_constant_override("separation", 4)
	var buy := UIKit.make_button("购买", Color(0.22, 0.62, 0.28), Color(0.14, 0.42, 0.18), 13)
	buy.pressed.connect(func(): seed_selected.emit(i))
	ops.add_child(buy)
	var sell := UIKit.make_button("卖出", Color(0.76, 0.5, 0.12), Color(0.5, 0.32, 0.06), 13)
	sell.pressed.connect(func(): crop_sell_requested.emit(i, 1))
	ops.add_child(sell)
	var sellall := UIKit.make_button("全卖", Color(0.62, 0.24, 0.18), Color(0.42, 0.14, 0.1), 13)
	sellall.pressed.connect(func(): crop_sell_requested.emit(i, int(inventory.get(i, 0))))
	ops.add_child(sellall)
	grid.add_child(ops)

func _make_seed_chip(i: int) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(160, 44)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.gui_input.connect(func(e: InputEvent):
		var mb := e as InputEventMouseButton
		if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			seed_selected.emit(i)
	)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 6)
	m.add_theme_constant_override("margin_right", 6)
	chip.add_child(m)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	m.add_child(hb)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(18, 18)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.color = _crop_color(i, 1)
	hb.add_child(dot)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	hb.add_child(vb)
	vb.add_child(UIKit.make_label(_crop_name(i), 15, Color(0.1, 0.1, 0.1)))
	vb.add_child(UIKit.make_label(str(_crop_seed_cost(i)) + "金", 11, Color(0.4, 0.35, 0.2)))
	return chip

func _build_fert_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_fert_list = list
	for i in range(FERTILIZERS.size()):
		list.add_child(_make_fert_row(i))
	return scroll

func _make_fert_row(i: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UIKit.card_box(
		Color(0.85, 0.92, 0.81) if i % 2 == 0 else Color(0.9, 0.95, 0.86),
		Color(0.5, 0.62, 0.4)))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	row.add_child(m)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	m.add_child(hb)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	hb.add_child(info)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	info.add_child(top)
	top.add_child(UIKit.make_label(_fertilizer_name(i), 15, Color(0.08, 0.08, 0.08)))
	top.add_child(UIKit.make_label(str(_fertilizer_cost(i)) + "金", 13, Color(0.75, 0.25, 0.08)))
	top.add_child(UIKit.make_label(FERT_DESC[i] if i < FERT_DESC.size() else "", 12, Color(0.25, 0.3, 0.2)))
	var have_lbl := UIKit.make_label("", 11, Color(0.4, 0.5, 0.35))
	info.add_child(have_lbl)
	_fert_rows.append(have_lbl)

	var buy := UIKit.make_button("购买", Color(0.22, 0.58, 0.28), Color(0.14, 0.4, 0.18), 14)
	buy.pressed.connect(func(): fertilizer_buy_requested.emit(i))
	hb.add_child(buy)
	var sel := UIKit.make_button("选择", Color(0.3, 0.55, 0.78), Color(0.18, 0.38, 0.56), 14)
	sel.pressed.connect(func(): fertilizer_selected.emit(i))
	hb.add_child(sel)
	return row

## 根据当前数据刷新高亮 / 数量等动态部分（不重建整个树）。
func _refresh_dynamic():
	# 种子选择高亮
	for i in range(_seed_chips.size()):
		var chip: PanelContainer = _seed_chips[i]
		if i == selected_seed:
			chip.add_theme_stylebox_override("panel", UIKit.card_box(Color(0.78, 0.95, 0.78), Color(0.15, 0.6, 0.15)))
		else:
			chip.add_theme_stylebox_override("panel", UIKit.card_box(Color(0.82, 0.78, 0.65), Color(0.6, 0.55, 0.4)))
	# 肥料已有 / 已选
	for i in range(_fert_rows.size()):
		var lbl: Label = _fert_rows[i]
		var h := int(fertilizer_inventory.get(i, 0))
		var hint := "  [已选中]" if selected_fertilizer == i else ""
		lbl.text = "已有: " + str(h) + " 个" + hint

func _crop_name(i: int) -> String:
	return crop_catalog.get_name(i) if crop_catalog != null else (str(CROPS[i][0]) if i >= 0 and CROPS.size() > i else "作物" + str(i))

func _crop_seed_cost(i: int) -> int:
	return crop_catalog.get_seed_cost(i) if crop_catalog != null else (int(CROPS[i][1]) if i >= 0 and CROPS.size() > i else 0)

func _crop_base_yield(i: int) -> int:
	return crop_catalog.get_base_yield(i) if crop_catalog != null else (int(CROPS[i][5]) if i >= 0 and CROPS.size() > i else 0)

func _crop_unit_sell(i: int) -> int:
	return crop_catalog.get_unit_sell(i) if crop_catalog != null else (int(CROPS[i][6]) if i >= 0 and CROPS.size() > i else 0)

func _crop_grow_time(i: int) -> float:
	return crop_catalog.get_grow_time(i) if crop_catalog != null else (float(CROPS[i][3]) if i >= 0 and CROPS.size() > i else 0.0)

func _crop_color(i: int, color_index: int) -> Color:
	if i >= 0 and i < CROP_COLORS.size():
		var colors = CROP_COLORS[i]
		if colors is Array and color_index >= 0 and color_index < colors.size():
			return colors[color_index]
	return Color(0.42, 0.76, 0.34) if color_index == 0 else Color(0.72, 0.96, 0.46)

func _fertilizer_name(i: int) -> String:
	return fertilizer_catalog.get_name(i) if fertilizer_catalog != null else (str(FERTILIZERS[i][0]) if i >= 0 and FERTILIZERS.size() > i else "肥料" + str(i))

func _fertilizer_cost(i: int) -> int:
	return fertilizer_catalog.get_cost(i) if fertilizer_catalog != null else (int(FERTILIZERS[i][1]) if i >= 0 and FERTILIZERS.size() > i else 0)
