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

func _on_shade_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button and mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		closed.emit()
