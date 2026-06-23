extends Node

signal tap(position: Vector2)

var camera: Camera2D
var background: Sprite2D
var min_zoom := 1.0
var max_zoom := 3.0

var _dragging := false
var _drag_start := Vector2.ZERO
var _start_pos := Vector2.ZERO
var _touch_positions := {}
var _touch_pan_start := Vector2.ZERO
var _touch_cam_start := Vector2.ZERO
var _pinch_start_dist := 0.0
var _pinch_start_zoom := 1.0

func setup(target_camera: Camera2D, initial_min_zoom: float):
	camera = target_camera
	min_zoom = initial_min_zoom

func set_background(target_background: Sprite2D) -> void:
	background = target_background

func handle_input(event: InputEvent) -> bool:
	if camera == null:
		return false
	if event is InputEventScreenTouch:
		return _handle_screen_touch(event)
	if event is InputEventScreenDrag:
		return _handle_screen_drag(event)
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT):
		_dragging = event.pressed
		if _dragging:
			_drag_start = event.position
			_start_pos = camera.position
		return true
	if event is InputEventMouseMotion and _dragging:
		var delta_screen: Vector2 = _drag_start - event.position
		camera.position = _start_pos + delta_screen / camera.zoom
		_clamp_camera()
		return true
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, 1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1)
			return true
	return false

func fit_to_background(background: Sprite2D):
	if camera == null or background == null or background.texture == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var scene_size: Vector2 = background.texture.get_size()
	var vp_ratio: float = vp.x / vp.y
	var scene_ratio: float = scene_size.x / scene_size.y
	if vp_ratio >= scene_ratio:
		min_zoom = vp.x / scene_size.x * 1.1
	else:
		min_zoom = vp.y / scene_size.y * 1.1
	camera.zoom = Vector2.ONE * min_zoom
	camera.position = scene_size * 0.5
	_clamp_camera()

func _handle_screen_touch(event: InputEventScreenTouch) -> bool:
	if event.pressed:
		_touch_positions[event.index] = event.position
		if _touch_positions.size() == 1:
			_touch_pan_start = event.position
			_touch_cam_start = camera.position
		elif _touch_positions.size() == 2:
			var keys := _touch_positions.keys()
			var p0: Vector2 = _touch_positions[keys[0]]
			var p1: Vector2 = _touch_positions[keys[1]]
			_pinch_start_dist = p0.distance_to(p1)
			_pinch_start_zoom = camera.zoom.x
	else:
		if _touch_positions.size() == 1 and event.index in _touch_positions:
			var moved: float = _touch_positions[event.index].distance_to(event.position)
			if moved < 15.0:
				tap.emit(event.position)
		_touch_positions.erase(event.index)
	return true

func _handle_screen_drag(event: InputEventScreenDrag) -> bool:
	_touch_positions[event.index] = event.position
	if _touch_positions.size() == 1:
		var delta_screen: Vector2 = _touch_pan_start - event.position
		camera.position = _touch_cam_start + delta_screen / camera.zoom
		_clamp_camera()
	elif _touch_positions.size() == 2:
		var keys := _touch_positions.keys()
		var p0: Vector2 = _touch_positions[keys[0]]
		var p1: Vector2 = _touch_positions[keys[1]]
		var dist: float = p0.distance_to(p1)
		if _pinch_start_dist > 0:
			var ratio: float = dist / _pinch_start_dist
			camera.zoom = Vector2.ONE * clampf(_pinch_start_zoom * ratio, min_zoom, max_zoom)
			_clamp_camera()
	return true

func _zoom_at(viewport_pos: Vector2, factor: float):
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var old_zoom := camera.zoom.x
	camera.zoom = (camera.zoom * factor).clampf(min_zoom, max_zoom)
	var new_zoom := camera.zoom.x
	if new_zoom != old_zoom:
		var mouse_offset: Vector2 = viewport_pos - vp * 0.5
		var world_offset: Vector2 = mouse_offset / old_zoom
		camera.position += world_offset * (1.0 - old_zoom / new_zoom)
	_clamp_camera()

func _clamp_camera():
	if camera == null:
		return
	var bg := background
	if bg == null or bg.texture == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var scene_size: Vector2 = bg.texture.get_size()
	var scene_center: Vector2 = scene_size * 0.5
	var visible_w: float = vp.x / camera.zoom.x
	var visible_h: float = vp.y / camera.zoom.y
	if scene_size.x >= visible_w:
		var half_w: float = visible_w * 0.5
		camera.position.x = clampf(camera.position.x, half_w, scene_size.x - half_w)
	else:
		camera.position.x = scene_center.x
	if scene_size.y >= visible_h:
		var half_h: float = visible_h * 0.5
		camera.position.y = clampf(camera.position.y, half_h, scene_size.y - half_h)
	else:
		camera.position.y = scene_center.y
