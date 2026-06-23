extends RefCounted
class_name FarmState

const INITIAL_UNLOCKED_PLOTS := 1
const LAND_LEVEL_LOCKED := 0
const BASE_RECLAIM_COST := 60
const RECLAIM_COST_STEP := 35

var cols: int
var rows: int

var gold := 200
var level := 1
var exp_val := 0
var exp_to_level := 100
var farm: Array = []
var inventory: Dictionary = {}
var fertilizer_inventory: Dictionary = {}
var game_time := 0.0
var selected_seed := -1
var tool_mode := 0
var selected_fertilizer := -1

func _init(grid_cols: int, grid_rows: int):
	cols = grid_cols
	rows = grid_rows
	reset()

func reset() -> void:
	gold = 200
	level = 1
	exp_val = 0
	exp_to_level = 100
	game_time = 0.0
	inventory = {}
	fertilizer_inventory = {}
	selected_seed = -1
	tool_mode = 0
	selected_fertilizer = -1
	farm = []
	for row in range(rows):
		var cells: Array = []
		for col in range(cols):
			cells.append(create_empty_cell(col, row))
		farm.append(cells)

func create_empty_cell(col: int, row: int) -> Dictionary:
	var initial_land_level := 1 if get_plot_index(col, row) < INITIAL_UNLOCKED_PLOTS else LAND_LEVEL_LOCKED
	return {
		"crop_id": -1,
		"progress": 0.0,
		"visual_progress": 0.0,
		"wet_timer": 0.0,
		"unlocked": initial_land_level > LAND_LEVEL_LOCKED,
		"land_level": initial_land_level,
		"land_work": 0,
		"water_state": 0,
		"dry_timer": 0.0,
		"water_protect_until": 0.0,
		"bug_count": 0,
		"bug_since": 0.0,
		"bug_protect_until": 0.0,
		"weed_count": 0,
		"weed_since": 0.0,
		"weed_protect_until": 0.0,
		"fert_used": 0,
		"fert_stage_used": {},
		"fert_ids_used": [],
		"yield_bonus_rate": 0.0,
		"yield_loss_rate": 0.0,
	}

func get_plot_index(col: int, row: int) -> int:
	return row * cols + col

func get_reclaim_level(col: int, row: int) -> int:
	return get_plot_index(col, row) + 1

func get_reclaim_cost(col: int, row: int) -> int:
	return BASE_RECLAIM_COST + get_plot_index(col, row) * RECLAIM_COST_STEP

func is_cell_unlocked(cell: Dictionary) -> bool:
	return int(cell.get("land_level", LAND_LEVEL_LOCKED)) > LAND_LEVEL_LOCKED

func get_unlocked_plot_count() -> int:
	var count := 0
	for row in range(rows):
		for col in range(cols):
			if is_cell_unlocked(farm[row][col]):
				count += 1
	return count

func get_next_locked_plot() -> Vector2i:
	for row in range(rows):
		for col in range(cols):
			if not is_cell_unlocked(farm[row][col]):
				return Vector2i(col, row)
	return Vector2i(-1, -1)

func apply_server_state(data: Dictionary) -> void:
	gold = int(data.get("gold", gold))
	level = int(data.get("level", level))
	exp_val = int(data.get("exp_val", exp_val))
	exp_to_level = int(data.get("exp_to_level", exp_to_level))
	game_time = float(data.get("game_time", game_time))
	if data.has("inventory") and (data["inventory"] is Dictionary):
		inventory = _normalize_inventory_keys(data["inventory"])
	if data.has("fertilizer_inventory") and (data["fertilizer_inventory"] is Dictionary):
		fertilizer_inventory = {}
		for key in data["fertilizer_inventory"].keys():
			fertilizer_inventory[int(key)] = int(data["fertilizer_inventory"][key])
	if data.has("plots") and (data["plots"] is Array):
		_apply_plots(data["plots"])

func _apply_plots(plots: Array) -> void:
	for plot in plots:
		if not (plot is Dictionary):
			continue
		var plot_index: int = int(plot.get("plot_index", -1))
		if plot_index < 0 or plot_index >= rows * cols:
			continue
		var row: int = int(plot_index / cols)
		var col: int = plot_index % cols
		var cell: Dictionary = farm[row][col]
		cell["unlocked"] = bool(plot.get("unlocked", false))
		cell["land_level"] = int(plot.get("land_level", 0))
		cell["land_work"] = int(plot.get("land_work", 0))
		var crop_id_raw = plot.get("crop_id", null)
		cell["crop_id"] = int(crop_id_raw) if crop_id_raw != null else -1
		var progress := clampf(float(plot.get("progress", 0.0)), 0.0, 1.0)
		cell["progress"] = progress
		cell["visual_progress"] = progress
		cell["wet_timer"] = maxf(float(plot.get("wet_timer", 0.0)), 0.0)
		cell["water_state"] = int(plot.get("water_state", 0))
		cell["dry_timer"] = maxf(float(plot.get("dry_timer", 0.0)), 0.0)
		cell["water_protect_until"] = float(plot.get("water_protect_until", 0.0))
		cell["bug_count"] = clampi(int(plot.get("bug_count", 0)), 0, 3)
		cell["bug_since"] = float(plot.get("bug_since", 0.0))
		cell["bug_protect_until"] = float(plot.get("bug_protect_until", 0.0))
		cell["weed_count"] = clampi(int(plot.get("weed_count", 0)), 0, 3)
		cell["weed_since"] = float(plot.get("weed_since", 0.0))
		cell["weed_protect_until"] = float(plot.get("weed_protect_until", 0.0))
		cell["fert_used"] = clampi(int(plot.get("fert_used", 0)), 0, 3)
		cell["fert_stage_used"] = _parse_dictish_json(plot.get("fert_stage_used", {}))
		cell["fert_ids_used"] = _parse_arrayish_json(plot.get("fert_ids_used", []))
		cell["yield_bonus_rate"] = maxf(float(plot.get("yield_bonus_rate", 0.0)), 0.0)
		cell["yield_loss_rate"] = clampf(float(plot.get("yield_loss_rate", 0.0)), 0.0, 0.30)

func apply_sell_result(crop_id: int, sold: int, new_gold: int) -> void:
	gold = new_gold
	if crop_id >= 0:
		inventory[crop_id] = max(0, int(inventory.get(crop_id, 0)) - sold)

func build_save_payload() -> Dictionary:
	return {
		"selected_seed": selected_seed,
		"tool_mode": tool_mode,
	}

func _normalize_inventory_keys(raw_inventory: Dictionary) -> Dictionary:
	var fixed := {}
	for key in raw_inventory.keys():
		var crop_id := int(key)
		fixed[crop_id] = int(raw_inventory[key])
	return fixed

func _parse_dictish_json(value) -> Dictionary:
	if value is Dictionary:
		return value
	if value is String:
		var parsed = JSON.parse_string(value)
		if parsed is Dictionary:
			return parsed
	return {}

func _parse_arrayish_json(value) -> Array:
	if value is Array:
		return value
	if value is String:
		var parsed = JSON.parse_string(value)
		if parsed is Array:
			return parsed
	return []
