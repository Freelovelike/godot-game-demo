extends Resource
class_name CropDef

@export var crop_name := ""
@export var seed_cost := 0
@export var grow_time := 0.0
@export var texture_key := ""
@export var base_yield := 0
@export var unit_sell := 0
@export var min_yield := 0
@export var max_yield := 0
@export var dry_rate := 0.0
@export var bug_rate := 0.0
@export var weed_rate := 0.0
@export var max_bug := 0
@export var max_weed := 0

func to_catalog_row() -> Array:
	return [
		crop_name,
		seed_cost,
		base_yield * unit_sell,
		grow_time,
		texture_key,
		base_yield,
		unit_sell,
		min_yield,
		max_yield,
		dry_rate,
		bug_rate,
		weed_rate,
		max_bug,
		max_weed,
	]
