extends RefCounted
class_name FertilizerCatalog

const NAME := 0
const COST := 1
const TYPE := 2
const EFFECT_VALUE := 3
const ALLOWED_STAGES := 4
const PER_CROP_LIMIT := 5
const MAX_MINUTES_LIMIT := 6

var fertilizers: Array = []

func set_fertilizers(value: Array) -> void:
	fertilizers = value

func is_valid_id(fertilizer_id: int) -> bool:
	return fertilizer_id >= 0 and fertilizer_id < fertilizers.size()

func get_name(fertilizer_id: int) -> String:
	return str(_field(fertilizer_id, NAME, "肥料" + str(fertilizer_id)))

func get_cost(fertilizer_id: int) -> int:
	return int(_field(fertilizer_id, COST, 0))

func get_type(fertilizer_id: int) -> String:
	return str(_field(fertilizer_id, TYPE, ""))

func get_effect_value(fertilizer_id: int) -> float:
	return float(_field(fertilizer_id, EFFECT_VALUE, 0.0))

func get_allowed_stages(fertilizer_id: int) -> Array:
	var value = _field(fertilizer_id, ALLOWED_STAGES, [])
	return value if value is Array else []

func _field(fertilizer_id: int, index: int, fallback):
	if not is_valid_id(fertilizer_id):
		return fallback
	var fertilizer = fertilizers[fertilizer_id]
	if not (fertilizer is Array) or fertilizer.size() <= index:
		return fallback
	return fertilizer[index]
