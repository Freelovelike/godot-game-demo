class_name UIKit
extends RefCounted

## 弹窗用的通用 UI 构件工厂。统一使用 Godot 内置 Control 节点 + StyleBoxFlat，
## 避免在各个 overlay 里手写 _draw / 透明按钮。中文字体由 project.godot 的
## theme/default_font 全局提供，无需在节点上单独设置。

static func panel_box(bg: Color, border: Color, border_w: int = 3, radius: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 6
	return s

static func card_box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	return s

static func button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 4
	s.set_corner_radius_all(5)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 4
	s.content_margin_bottom = 5
	return s

static func make_button(text: String, bg: Color, border: Color, font_size: int = 16) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.8))
	b.add_theme_stylebox_override("normal", button_box(bg, border))
	b.add_theme_stylebox_override("hover", button_box(bg.lightened(0.1), border))
	b.add_theme_stylebox_override("pressed", button_box(border, border.darkened(0.12)))
	return b

static func make_label(text: String, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

## 半透明遮罩 + 居中面板的通用骨架。
## 返回 [root_dim, panel]：root_dim 是铺满全屏的遮罩(ColorRect)，panel 是居中的 PanelContainer。
## 调用方把内容塞进 panel 即可；点击遮罩空白处会发出回调。
static func build_modal(parent: Control, panel_min: Vector2, title: String, title_bg: Color, \
		panel_bg: Color, panel_border: Color, on_close: Callable) -> Array:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e: InputEvent):
		var mb := e as InputEventMouseButton
		if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			on_close.call()
	)
	parent.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = panel_min
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# panel 用 MOUSE_FILTER_STOP 吃掉落在面板上的点击，不会穿透到遮罩
	panel.add_theme_stylebox_override("panel", panel_box(panel_bg, panel_border))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# 标题栏：彩色背景条 + 标题 + 关闭按钮
	var header_panel := PanelContainer.new()
	var header_box := StyleBoxFlat.new()
	header_box.bg_color = title_bg
	header_box.set_corner_radius_all(6)
	header_box.content_margin_left = 10
	header_box.content_margin_right = 6
	header_box.content_margin_top = 4
	header_box.content_margin_bottom = 4
	header_panel.add_theme_stylebox_override("panel", header_box)
	vbox.add_child(header_panel)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header_panel.add_child(header)

	var title_lbl := make_label(title, 22, Color(1, 0.96, 0.88))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)

	var close_btn := make_button("✕", Color(0.6, 0.28, 0.24), Color(0.4, 0.16, 0.14), 18)
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.pressed.connect(func(): on_close.call())
	header.add_child(close_btn)

	return [dim, vbox]

