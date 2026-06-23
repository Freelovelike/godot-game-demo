extends Resource
class_name FertilizerDef

@export var fertilizer_name := ""
@export var cost := 0
@export var fertilizer_type := ""
@export var effect_value := 0.0
@export var allowed_stages: Array = []
@export var per_crop_limit := 0
@export var max_minutes_limit := 0

func to_catalog_row() -> Array:
	var stages: Array = []
	for stage in allowed_stages:
		stages.append(int(stage))
	return [
		fertilizer_name,
		cost,
		fertilizer_type,
		effect_value,
		stages,
		per_crop_limit,
		max_minutes_limit,
	]
