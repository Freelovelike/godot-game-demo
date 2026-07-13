@tool
extends PopupBase

## 静态弹窗结构在 inventory_overlay.tscn 中，脚本只维护动态物品卡片。

const CropAtlas = preload("res://scripts/crop_atlas.gd")

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

@onready var sell_all_button: Button = $Center/Root/Content/InventoryContent/SellAllButton
@onready var grid: GridContainer = $Center/Root/Content/InventoryContent/ItemsScroll/ItemsGrid
@onready var empty_label: Label = $Center/Root/Content/InventoryContent/EmptyLabel

func _ready() -> void:
	super._ready()
	sell_all_button.pressed.connect(func(): sell_all_requested.emit())
	_style_sell_all_button()
	_rebuild_items()

func _style_sell_all_button() -> void:
	sell_all_button.add_theme_stylebox_override("normal", UIKit.button_box(Color(0.72, 0.32, 0.12), Color(0.48, 0.18, 0.06)))
	sell_all_button.add_theme_stylebox_override("hover", UIKit.button_box(Color(0.82, 0.4, 0.15), Color(0.48, 0.18, 0.06)))
	sell_all_button.add_theme_stylebox_override("pressed", UIKit.button_box(Color(0.55, 0.22, 0.08), Color(0.4, 0.14, 0.04)))

func _rebuild_items() -> void:
	if grid == null:
		return
	for child in grid.get_children():
		child.queue_free()

	var has_any := false
	for cid in inventory.keys():
		var count := int(inventory.get(cid, 0))
		if count <= 0:
			continue
		has_any = true
		grid.add_child(_make_card(int(cid), count))

	empty_label.visible = not has_any

func _make_card(crop_id: int, count: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(140, 0)
	card.add_theme_stylebox_override("panel", UIKit.card_box(Color(1.0, 0.87, 0.6), Color(0.55, 0.28, 0.08)))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(0, 54)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if crop_catalog != null and crop_catalog.is_valid_id(crop_id):
		icon.texture = CropAtlas.get_stage_texture(crop_catalog.get_texture_key(crop_id), 3)
	box.add_child(icon)

	box.add_child(UIKit.make_label(_crop_name(crop_id), 16, Color(0.18, 0.08, 0.02), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.make_label("数量: " + str(count), 14, Color(0.34, 0.18, 0.06), HORIZONTAL_ALIGNMENT_CENTER))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var sell_one := UIKit.make_button("卖出", Color(0.8, 0.58, 0.08), Color(0.55, 0.36, 0.03), 13)
	sell_one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_one.pressed.connect(func(): sell_requested.emit(crop_id, 1))
	row.add_child(sell_one)
	var sell_all := UIKit.make_button("全卖", Color(0.68, 0.28, 0.12), Color(0.45, 0.16, 0.06), 13)
	sell_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_all.pressed.connect(func(): sell_requested.emit(crop_id, count))
	row.add_child(sell_all)

	if _crop_is_valid(crop_id):
		box.add_child(UIKit.make_label("x" + str(_crop_unit_sell(crop_id)) + " 金/个", 11, Color(0.48, 0.32, 0.04), HORIZONTAL_ALIGNMENT_CENTER))

	return card

func _crop_is_valid(crop_id: int) -> bool:
	return crop_catalog.is_valid_id(crop_id) if crop_catalog != null else crop_id >= 0 and CROPS.size() > crop_id

func _crop_name(crop_id: int) -> String:
	return crop_catalog.get_name(crop_id) if crop_catalog != null else (str(CROPS[crop_id][0]) if crop_id >= 0 and CROPS.size() > crop_id else "作物" + str(crop_id))

func _crop_unit_sell(crop_id: int) -> int:
	return crop_catalog.get_unit_sell(crop_id) if crop_catalog != null else (int(CROPS[crop_id][6]) if crop_id >= 0 and CROPS.size() > crop_id else 0)
