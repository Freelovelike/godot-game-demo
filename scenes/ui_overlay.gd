extends Control

## UI overlay — draws HUD / toolbar / toast in screen space, unaffected by Camera2D.

var farm_ref: Node = null
var _cn_font: Font = null

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

func _on_top_button_pressed(index: int):
	if farm_ref == null or not is_instance_valid(farm_ref):
		return
	if farm_ref.has_method("_open_top_toolbar_overlay"):
		farm_ref._open_top_toolbar_overlay(index)

func _draw():
	if farm_ref == null or not is_instance_valid(farm_ref):
		return
	if farm_ref.has_method("_draw_ui"):
		farm_ref._draw_ui(self)
