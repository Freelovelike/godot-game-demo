@tool
class_name PopupBase
extends Control

## 所有业务弹窗的基础场景：遮罩、公共背景、标题、关闭按钮和内容区。

signal closed

const POPUP_DESIGN_SIZE := Vector2(940.0, 620.0)
const VIEWPORT_MARGIN := Vector2(24.0, 24.0)
const MIN_POPUP_SCALE := 0.55
const MAX_POPUP_SCALE := 1.15

@export var title_texture: Texture2D:
	set(value):
		title_texture = value
		if is_instance_valid(title):
			title.texture = value

@onready var shade: ColorRect = $Shade
@onready var center: Control = $Center
@onready var popup_root: Control = $Center/Root
@onready var title: TextureRect = $Center/Root/Title
@onready var close_button: TextureButton = $Center/Root/CloseButton

func _ready() -> void:
	shade.gui_input.connect(_on_shade_input)
	close_button.pressed.connect(func(): closed.emit())
	title.texture = title_texture
	resized.connect(_layout_popup)
	_layout_popup()
	call_deferred("_style_scrollbars")

func _layout_popup() -> void:
	if not is_instance_valid(popup_root):
		return
	var available_size := (size - VIEWPORT_MARGIN * 2.0).max(Vector2.ONE)
	var popup_scale := minf(
		available_size.x / POPUP_DESIGN_SIZE.x,
		available_size.y / POPUP_DESIGN_SIZE.y
	)
	popup_scale = clampf(popup_scale, MIN_POPUP_SCALE, MAX_POPUP_SCALE)
	popup_root.scale = Vector2.ONE * popup_scale
	popup_root.position = (size - POPUP_DESIGN_SIZE * popup_scale) * 0.5

func _style_scrollbars() -> void:
	for node in find_children("*", "ScrollContainer", true, false):
		var scroll := node as ScrollContainer
		if scroll == null:
			continue
		var bar := scroll.get_v_scroll_bar()
		bar.custom_minimum_size.x = 8.0
		bar.add_theme_stylebox_override("scroll", _scrollbar_style(Color(0.20, 0.11, 0.035, 0.22), 4.0))
		bar.add_theme_stylebox_override("scroll_focus", _scrollbar_style(Color(0.20, 0.11, 0.035, 0.28), 4.0))
		bar.add_theme_stylebox_override("grabber", _scrollbar_style(Color(0.48, 0.27, 0.08, 0.72), 4.0))
		bar.add_theme_stylebox_override("grabber_highlight", _scrollbar_style(Color(0.58, 0.34, 0.10, 0.88), 4.0))
		bar.add_theme_stylebox_override("grabber_pressed", _scrollbar_style(Color(0.38, 0.20, 0.055, 0.95), 4.0))

func _scrollbar_style(color: Color, radius: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	style.content_margin_left = 2.0
	style.content_margin_right = 2.0
	return style

func _on_shade_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button and mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		closed.emit()
