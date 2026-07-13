@tool
extends PopupBase

const CropAtlas = preload("res://scripts/crop_atlas.gd")

var CROPS: Array = []
var CROP_COLORS: Array = []
var FERTILIZERS: Array = []
var crop_catalog: CropCatalog = null
var fertilizer_catalog: FertilizerCatalog = null
var inventory: Dictionary = {}:
	set(v):
		inventory = v
		_refresh()
var fertilizer_inventory: Dictionary = {}:
	set(v):
		fertilizer_inventory = v
		_refresh()
var selected_fertilizer: int = -1:
	set(v):
		selected_fertilizer = v
		_refresh()

signal fertilizer_selected(index: int)
signal fertilizer_buy_requested(fert_id: int)
signal seed_buy_requested(crop_id: int)

const FERT_DESC := ["生长-8%", "生长-12%", "生长-18%", "2h不缺水", "2h不生虫", "2h不长草", "产量+10%"]
const SEED_COLUMN_RATIOS := [1.55, 1.0, 1.5, 1.0, 1.0, 1.0]
const FERT_COLUMN_RATIOS := [1.5, 0.8, 1.2, 1.1, 1.25]

@onready var seed_button: BaseButton = $Center/Root/Content/TabBar/SeedTabClip/SeedTab
@onready var fert_button: BaseButton = $Center/Root/Content/TabBar/FertTabClip/FertTab
@onready var seed_scroll: ScrollContainer = $Center/Root/Content/TabContent/ShopContent/SeedScroll
@onready var fert_scroll: ScrollContainer = $Center/Root/Content/TabContent/ShopContent/FertScroll
@onready var seed_table: GridContainer = $Center/Root/Content/TabContent/ShopContent/SeedScroll/SeedTable
@onready var fert_table: GridContainer = $Center/Root/Content/TabContent/ShopContent/FertScroll/FertTable

var _current_tab := 0
var _ready_done := false

func _ready() -> void:
	super._ready()
	_ready_done = true

	seed_button.pressed.connect(func(): _set_tab(0))
	fert_button.pressed.connect(func(): _set_tab(1))
	seed_scroll.resized.connect(_sync_table_widths)
	fert_scroll.resized.connect(_sync_table_widths)

	_refresh()
	call_deferred("_sync_table_widths")

func _set_tab(index: int) -> void:
	_current_tab = index
	if seed_scroll:
		seed_scroll.visible = index == 0
	if fert_scroll:
		fert_scroll.visible = index == 1
	if seed_button:
		seed_button.disabled = index == 0
	if fert_button:
		fert_button.disabled = index == 1
	call_deferred("_sync_table_widths")

func _sync_table_widths() -> void:
	_sync_table_width(seed_scroll, seed_table)
	_sync_table_width(fert_scroll, fert_table)

func _sync_table_width(scroll: ScrollContainer, table: GridContainer) -> void:
	if scroll == null or table == null:
		return
	var scrollbar := scroll.get_v_scroll_bar()
	var scrollbar_width := scrollbar.size.x if scrollbar.visible else 0.0
	table.custom_minimum_size.x = maxf(scroll.size.x - scrollbar_width, 1.0)
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _refresh() -> void:
	if not _ready_done:
		return
	_build_seed_table()
	_build_fert_table()
	_set_tab(_current_tab)

func _build_seed_table() -> void:
	if seed_table == null:
		return
	_clear_children(seed_table)
	seed_table.columns = 6
	seed_table.add_theme_constant_override("h_separation", 4)
	var headers := ["名称", "种子价", "产量 x 单价", "生长", "利润", "购买"]
	for column in range(headers.size()):
		_add_grid_cell(seed_table, _make_label(headers[column], 22, Color(0.25, 0.14, 0.04), HORIZONTAL_ALIGNMENT_CENTER, Vector2(0, 36)), SEED_COLUMN_RATIOS[column])
	for i in range(CROPS.size()):
		_add_grid_cell(seed_table, _make_crop_name_cell(i), SEED_COLUMN_RATIOS[0])
		_add_grid_cell(seed_table, _make_label(str(_crop_seed_cost(i)) + "金", 22, Color(0.78, 0.30, 0.03), HORIZONTAL_ALIGNMENT_CENTER, Vector2(0, 42)), SEED_COLUMN_RATIOS[1])
		_add_grid_cell(seed_table, _make_label(str(_crop_base_yield(i)) + "x" + str(_crop_unit_sell(i)), 22, Color(0.04, 0.52, 0.08), HORIZONTAL_ALIGNMENT_CENTER, Vector2(0, 42)), SEED_COLUMN_RATIOS[2])
		_add_grid_cell(seed_table, _make_label(str(int(_crop_grow_time(i))) + "秒", 22, Color(0.04, 0.28, 0.86), HORIZONTAL_ALIGNMENT_CENTER, Vector2(0, 42)), SEED_COLUMN_RATIOS[3])
		var profit := _crop_base_yield(i) * _crop_unit_sell(i) - _crop_seed_cost(i)
		_add_grid_cell(seed_table, _make_label("+" + str(profit), 22, Color(0.05, 0.52, 0.06), HORIZONTAL_ALIGNMENT_CENTER, Vector2(0, 42)), SEED_COLUMN_RATIOS[4])
		_add_grid_cell(seed_table, _make_seed_buy_button(i), SEED_COLUMN_RATIOS[5])

func _build_fert_table() -> void:
	if fert_table == null:
		return
	_clear_children(fert_table)
	fert_table.columns = 5
	fert_table.add_theme_constant_override("h_separation", 4)
	var headers := ["名称", "价格", "效果", "状态", "操作"]
	for column in range(headers.size()):
		_add_grid_cell(fert_table, _make_label(headers[column], 22, Color(0.25, 0.14, 0.04), HORIZONTAL_ALIGNMENT_CENTER, Vector2(0, 36)), FERT_COLUMN_RATIOS[column])
	for i in range(FERTILIZERS.size()):
		_add_grid_cell(fert_table, _make_label(_fertilizer_name(i), 20, Color(0.12, 0.07, 0.02), HORIZONTAL_ALIGNMENT_LEFT, Vector2(0, 42)), FERT_COLUMN_RATIOS[0])
		_add_grid_cell(fert_table, _make_label(str(_fertilizer_cost(i)) + "金", 20, Color(0.78, 0.30, 0.03), HORIZONTAL_ALIGNMENT_CENTER, Vector2(0, 42)), FERT_COLUMN_RATIOS[1])
		_add_grid_cell(fert_table, _make_label(FERT_DESC[i] if i < FERT_DESC.size() else "", 19, Color(0.05, 0.42, 0.08), HORIZONTAL_ALIGNMENT_CENTER, Vector2(0, 42)), FERT_COLUMN_RATIOS[2])
		var status := "已有 " + str(int(fertilizer_inventory.get(i, 0)))
		if selected_fertilizer == i:
			status += " 已选"
		_add_grid_cell(fert_table, _make_label(status, 18, Color(0.26, 0.19, 0.08), HORIZONTAL_ALIGNMENT_CENTER, Vector2(0, 42)), FERT_COLUMN_RATIOS[3])
		_add_grid_cell(fert_table, _make_fert_actions(i), FERT_COLUMN_RATIOS[4])

func _add_grid_cell(grid: GridContainer, control: Control, stretch_ratio: float) -> void:
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_stretch_ratio = stretch_ratio
	grid.add_child(control)

func _make_crop_name_cell(crop_id: int) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.custom_minimum_size = Vector2(0, 42)
	box.add_theme_constant_override("separation", 6)

	var tex := CropAtlas.get_stage_texture(crop_catalog.get_texture_key(crop_id), 3) if crop_catalog != null else null
	if tex:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(34, 42)
		icon.texture = tex
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(icon)

	box.add_child(_make_label(_crop_name(crop_id), 22, Color(0.13, 0.07, 0.02), HORIZONTAL_ALIGNMENT_LEFT, Vector2(92, 42)))
	return box

func _make_seed_buy_button(crop_id: int) -> Button:
	var buy := _make_action_button("购买", Color(0.25, 0.60, 0.20))
	buy.custom_minimum_size = Vector2(58, 30)
	buy.pressed.connect(func(): seed_buy_requested.emit(crop_id))
	return buy

func _make_fert_actions(fert_id: int) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.custom_minimum_size = Vector2(0, 42)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)

	var buy := _make_action_button("购买", Color(0.25, 0.60, 0.20))
	buy.pressed.connect(func(): fertilizer_buy_requested.emit(fert_id))
	box.add_child(buy)

	var choose := _make_action_button("选择", Color(0.20, 0.42, 0.74))
	choose.pressed.connect(func(): fertilizer_selected.emit(fert_id))
	box.add_child(choose)
	return box

func _make_action_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(60, 32)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", _button_box(color))
	button.add_theme_stylebox_override("hover", _button_box(color.lightened(0.08)))
	button.add_theme_stylebox_override("pressed", _button_box(color.darkened(0.12)))
	return button

func _make_label(text: String, font_size: int, color: Color, align: HorizontalAlignment, min_size: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = min_size
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = color.darkened(0.28)
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.corner_radius_top_left = 6
	box.corner_radius_top_right = 6
	box.corner_radius_bottom_left = 6
	box.corner_radius_bottom_right = 6
	return box

func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()

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
