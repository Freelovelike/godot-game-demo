@tool
extends Node2D

const LINE_COLOR := Color(0.1, 0.9, 0.95, 0.95)
const POINT_COLOR := Color(1.0, 0.48, 0.08, 0.95)


func _ready() -> void:
	set_process(Engine.is_editor_hint())
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	var points := PackedVector2Array()
	for child in get_children():
		var marker := child as Marker2D
		if marker != null:
			points.append(marker.position)

	if points.size() >= 2:
		var closed_points := points.duplicate()
		closed_points.append(points[0])
		draw_polyline(closed_points, LINE_COLOR, 3.0)

	var font := ThemeDB.fallback_font
	for point_index in points.size():
		var point := points[point_index]
		draw_circle(point, 7.0, POINT_COLOR)
		draw_string(
			font,
			point + Vector2(10.0, -8.0),
			str(point_index + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color.WHITE
		)
