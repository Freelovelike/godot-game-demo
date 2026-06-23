extends RefCounted
class_name CropCatalog

const NAME := 0
const SEED_COST := 1
const TOTAL_SELL_VALUE := 2
const GROW_TIME := 3
const TEXTURE_KEY := 4
const BASE_YIELD := 5
const UNIT_SELL := 6
const MIN_YIELD := 7
const MAX_YIELD := 8
const DRY_RATE := 9
const BUG_RATE := 10
const WEED_RATE := 11
const MAX_BUG := 12
const MAX_WEED := 13

var crops: Array = []

func set_crops(value: Array) -> void:
	crops = value

func is_valid_id(crop_id: int) -> bool:
	return crop_id >= 0 and crop_id < crops.size()

func get_name(crop_id: int) -> String:
	return str(_field(crop_id, NAME, "作物" + str(crop_id)))

func get_seed_cost(crop_id: int) -> int:
	return int(_field(crop_id, SEED_COST, 0))

func get_grow_time(crop_id: int) -> float:
	return float(_field(crop_id, GROW_TIME, 0.0))

func get_texture_key(crop_id: int) -> String:
	return str(_field(crop_id, TEXTURE_KEY, ""))

func get_base_yield(crop_id: int) -> int:
	return int(_field(crop_id, BASE_YIELD, 0))

func get_unit_sell(crop_id: int) -> int:
	return int(_field(crop_id, UNIT_SELL, 0))

func get_min_yield(crop_id: int) -> int:
	return int(_field(crop_id, MIN_YIELD, 0))

func get_max_yield(crop_id: int) -> int:
	return int(_field(crop_id, MAX_YIELD, 0))

func _field(crop_id: int, index: int, fallback):
	if not is_valid_id(crop_id):
		return fallback
	var crop = crops[crop_id]
	if not (crop is Array) or crop.size() <= index:
		return fallback
	return crop[index]
