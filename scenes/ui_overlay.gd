extends Control

## UI overlay — draws HUD / toolbar / toast in screen space, unaffected by Camera2D.

signal top_button_requested(index: int)
signal tool_mode_requested(index: int)
signal reclaim_cancel_requested
signal reclaim_confirm_requested
signal reset_cancel_requested
signal reset_confirm_requested
signal shovel_all_cancel_requested
signal shovel_all_confirm_requested
signal overlay_draw_requested(caller: CanvasItem)

var _cn_font: Font = null
var _hud_gold: Label
var _hud_level: Label
var _hud_exp: Label
var _hud_land: Label
var _toast: Label
var _tool_buttons: Array[Button] = []
var _reclaim_modal: Control
var _reclaim_title: Label
var _reclaim_level: Label
var _reclaim_cost: Label
var _reset_modal: Control
var _shovel_modal: Control
var _view_model: Dictionary = {}

const TOOL_ICON_TEXTURES: Array[Texture2D] = [
	null,
	preload("res://assets/ui/icons/tool_water.png"),
	preload("res://assets/ui/icons/tool_fertilizer.png"),
	preload("res://assets/ui/icons/tool_harvest.png"),
	preload("res://assets/ui/icons/tool_shovel.png"),
	preload("res://assets/ui/icons/tool_shovel_all.png"),
	preload("res://assets/ui/icons/tool_pest.png"),
	preload("res://assets/ui/icons/tool_weed.png"),
	preload("res://assets/ui/icons/btn_harvest_all.png"),
	preload("res://assets/ui/icons/btn_warehouse.png"),
]

const TOP_BUTTONS := ["商店", "背包", "设置"]
const TOP_BUTTON_COLORS := [
	Color(0.22, 0.65, 0.28),
	Color(0.55, 0.28, 0.68),
	Color(0.4, 0.42, 0.5),
]
const TOP_BUTTON_DARK_COLORS := [
	Color(0.14, 0.45, 0.18),
	Color(0.38, 0.18, 0.48),
	Color(0.28, 0.3, 0.36),
]

func _ready():
	mouse_filter = Control.MOUSE_FILTER_PASS
	if ResourceLoader.exists("res://assets/fonts/simhei.ttf"):
		_cn_font = load("res://assets/fonts/simhei.ttf") as Font
	_build_top_toolbar()
	_build_hud()
	_build_tool_toolbar()
	_build_toast()
	_build_confirm_modals()

func _build_top_toolbar():
	var toolbar := HBoxContainer.new()
	toolbar.name = "TopToolbar"
	toolbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toolbar.anchor_left = 1.0
	toolbar.anchor_right = 1.0
	toolbar.anchor_top = 0.0
	toolbar.anchor_bottom = 0.0
	toolbar.offset_left = -286.0
	toolbar.offset_top = 8.0
	toolbar.offset_right = -14.0
	toolbar.offset_bottom = 58.0
	toolbar.add_theme_constant_override("separation", 10)
	add_child(toolbar)

	for i in range(TOP_BUTTONS.size()):
		var button := Button.new()
		button.text = TOP_BUTTONS[i]
		button.custom_minimum_size = Vector2(84, 50)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.add_theme_font_size_override("font_size", 18)
		if _cn_font != null:
			button.add_theme_font_override("font", _cn_font)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color(1, 0.92, 0.75))
		button.add_theme_stylebox_override("normal", _make_button_style(TOP_BUTTON_COLORS[i], TOP_BUTTON_DARK_COLORS[i]))
		button.add_theme_stylebox_override("hover", _make_button_style(TOP_BUTTON_COLORS[i].lightened(0.08), TOP_BUTTON_DARK_COLORS[i]))
		button.add_theme_stylebox_override("pressed", _make_button_style(TOP_BUTTON_DARK_COLORS[i], TOP_BUTTON_DARK_COLORS[i].darkened(0.12)))
		button.pressed.connect(_on_top_button_pressed.bind(i))
		toolbar.add_child(button)

func _build_hud():
	var panel := PanelContainer.new()
	panel.name = "HUD"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.offset_left = 8.0
	panel.offset_top = 6.0
	panel.offset_right = 288.0
	panel.offset_bottom = 54.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.06, 0.02, 0.82), Color(0.45, 0.35, 0.15)))
	add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 2)
	panel.add_child(grid)
	_hud_gold = _make_label(18, Color(1, 0.88, 0.15))
	_hud_level = _make_label(16, Color(0.8, 0.9, 1.0))
	_hud_exp = _make_label(10, Color(0.65, 0.75, 1.0))
	_hud_land = _make_label(10, Color(0.7, 0.65, 0.5))
	grid.add_child(_hud_gold)
	grid.add_child(_hud_level)
	grid.add_child(_hud_exp)
	grid.add_child(_hud_land)

func _build_tool_toolbar():
	var toolbar := HBoxContainer.new()
	toolbar.name = "ToolToolbar"
	toolbar.anchor_left = 0.5
	toolbar.anchor_right = 0.5
	toolbar.anchor_top = 0.8
	toolbar.anchor_bottom = 0.8
	toolbar.offset_left = -326.0
	toolbar.offset_top = 0.0
	toolbar.offset_right = 326.0
	toolbar.offset_bottom = 78.0
	toolbar.add_theme_constant_override("separation", 8)
	add_child(toolbar)
	var names := ["普通", "浇水", "施肥", "收获", "铲除", "全铲", "除虫", "除草", "全收", "仓库"]
	for i in range(names.size()):
		var button := Button.new()
		button.custom_minimum_size = Vector2(58, 68)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.tooltip_text = names[i]
		button.text = names[i]
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.expand_icon = true
		button.add_theme_font_size_override("font_size", 12)
		if _cn_font != null:
			button.add_theme_font_override("font", _cn_font)
		button.pressed.connect(_on_tool_button_pressed.bind(i))
		toolbar.add_child(button)
		_tool_buttons.append(button)

func _build_toast():
	_toast = _make_label(18, Color.WHITE)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.anchor_top = 1.0
	_toast.anchor_bottom = 1.0
	_toast.offset_left = -260.0
	_toast.offset_right = 260.0
	_toast.offset_top = -54.0
	_toast.offset_bottom = -14.0
	_toast.visible = false
	_toast.add_theme_stylebox_override("normal", _make_panel_style(Color(0, 0, 0, 0.8), Color(0, 0, 0, 0)))
	add_child(_toast)

func _build_confirm_modals():
	_reclaim_modal = _make_modal("确认开垦土地", Vector2(420, 200))
	var reclaim_box := _reclaim_modal.get_node("Panel/Margin/VBox") as VBoxContainer
	_reclaim_title = _make_label(16, Color(0.18, 0.14, 0.1))
	_reclaim_level = _make_label(14, Color(0.2, 0.24, 0.42))
	_reclaim_cost = _make_label(14, Color(0.75, 0.3, 0.05))
	reclaim_box.add_child(_reclaim_title)
	reclaim_box.add_child(_reclaim_level)
	reclaim_box.add_child(_reclaim_cost)
	reclaim_box.add_child(_make_label_with_text("确认花费金币开垦这块土地吗？", 14, Color(0.28, 0.22, 0.18)))
	reclaim_box.add_child(_make_button_row("取消", "确认", func():
		reclaim_cancel_requested.emit()
	, func():
		reclaim_confirm_requested.emit()
	))
	add_child(_reclaim_modal)

	_reset_modal = _make_modal("确认重置农场", Vector2(480, 220))
	var reset_box := _reset_modal.get_node("Panel/Margin/VBox") as VBoxContainer
	reset_box.add_child(_make_label_with_text("这会清空当前存档中的金币、等级、土地、作物和背包数据。", 14, Color(0.22, 0.12, 0.3)))
	reset_box.add_child(_make_label_with_text("重置后会立即覆盖旧存档，重新进入游戏也不会恢复。", 14, Color(0.45, 0.2, 0.3)))
	reset_box.add_child(_make_label_with_text("确认要新开档吗？", 15, Color(0.55, 0.18, 0.18)))
	reset_box.add_child(_make_button_row("取消", "确认重置", func():
		reset_cancel_requested.emit()
	, func():
		reset_confirm_requested.emit()
	))
	add_child(_reset_modal)

	_shovel_modal = _make_modal("确认铲除全部作物?", Vector2(400, 160))
	var shovel_box := _shovel_modal.get_node("Panel/Margin/VBox") as VBoxContainer
	shovel_box.add_child(_make_label_with_text("这将铲除所有地块上的作物，且不可恢复。", 14, Color(0.28, 0.22, 0.18)))
	shovel_box.add_child(_make_button_row("取消", "确认铲除", func():
		shovel_all_cancel_requested.emit()
	, func():
		shovel_all_confirm_requested.emit()
	))
	add_child(_shovel_modal)

func _make_modal(title: String, size: Vector2) -> Control:
	var root := Control.new()
	root.visible = false
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = size
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -size.x * 0.5
	panel.offset_top = -size.y * 0.5
	panel.offset_right = size.x * 0.5
	panel.offset_bottom = size.y * 0.5
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.94, 0.9, 0.78), Color(0.48, 0.32, 0.12)))
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "VBox"
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title_label := _make_label_with_text(title, 18, Color(0.18, 0.14, 0.1))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)
	return root

func _make_button_row(cancel_text: String, confirm_text: String, cancel_cb: Callable, confirm_cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	var cancel := Button.new()
	cancel.text = cancel_text
	cancel.custom_minimum_size = Vector2(130, 34)
	cancel.pressed.connect(cancel_cb)
	row.add_child(cancel)
	var confirm := Button.new()
	confirm.text = confirm_text
	confirm.custom_minimum_size = Vector2(130, 34)
	confirm.pressed.connect(confirm_cb)
	row.add_child(confirm)
	return row

func _make_label_with_text(text: String, font_size: int, color: Color) -> Label:
	var label := _make_label(font_size, color)
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _make_button_style(color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 5
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 3
	style.content_margin_top = 2
	style.content_margin_bottom = 5
	return style

func _make_panel_style(color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if _cn_font != null:
		label.add_theme_font_override("font", _cn_font)
	return label

func _on_top_button_pressed(index: int):
	# 有弹窗/确认框开着时，顶部按钮不响应（否则 Button 节点会穿透弹窗）
	if bool(_view_model.get("top_buttons_blocked", false)):
		return
	top_button_requested.emit(index)

func _on_tool_button_pressed(index: int):
	tool_mode_requested.emit(index)

func update_view_model(view_model: Dictionary):
	_view_model = view_model
	queue_redraw()

func _draw():
	_update_hud()
	_update_toolbar()
	_update_toast()
	_update_confirm_modals()
	overlay_draw_requested.emit(self)

func _update_hud():
	_hud_gold.text = "金币: " + str(_view_model.get("gold", 0))
	_hud_level.text = "Lv." + str(_view_model.get("level", 1))
	_hud_exp.text = str(_view_model.get("exp_val", 0)) + "/" + str(_view_model.get("exp_to_level", 100))
	_hud_land.text = "地:" + str(_view_model.get("unlocked_plot_count", 0)) + "/" + str(_view_model.get("plot_count", 30))

func _update_toolbar():
	var tool_mode: int = int(_view_model.get("tool_mode", 0))
	for i in range(_tool_buttons.size()):
		var button := _tool_buttons[i]
		button.button_pressed = tool_mode == i
		if i < TOOL_ICON_TEXTURES.size():
			button.icon = TOOL_ICON_TEXTURES[i]

func _update_toast():
	var toast_text := str(_view_model.get("toast_text", ""))
	_toast.visible = toast_text != ""
	_toast.text = toast_text
	_toast.modulate.a = minf(float(_view_model.get("toast_timer", 0.0)), 1.0)

func _update_confirm_modals():
	_reclaim_modal.visible = bool(_view_model.get("reclaim_confirm_open", false))
	_reset_modal.visible = bool(_view_model.get("reset_confirm_open", false))
	_shovel_modal.visible = bool(_view_model.get("shovel_all_confirm_open", false))
	if _reclaim_modal.visible:
		_reclaim_title.text = "第 " + str(int(_view_model.get("reclaim_plot_no", 0))) + " 块地"
		_reclaim_level.text = "需要等级: " + str(int(_view_model.get("reclaim_level", 0)))
		_reclaim_cost.text = "开垦费用: " + str(int(_view_model.get("reclaim_cost", 0))) + " 金币"
