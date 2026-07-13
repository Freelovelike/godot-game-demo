@tool
class_name PopupBase
extends Control

## 所有业务弹窗的基础场景：遮罩、公共背景、标题、关闭按钮和内容区。

signal closed

@export var title_texture: Texture2D:
	set(value):
		title_texture = value
		if is_instance_valid(title):
			title.texture = value

@onready var shade: ColorRect = $Shade
@onready var title: TextureRect = $Center/Root/Title
@onready var close_button: TextureButton = $Center/Root/CloseButton

func _ready() -> void:
	shade.gui_input.connect(_on_shade_input)
	close_button.pressed.connect(func(): closed.emit())
	title.texture = title_texture

func _on_shade_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button and mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		closed.emit()
