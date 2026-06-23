extends RefCounted
class_name FarmRules

const INTENT_NONE := "none"
const INTENT_TOAST := "toast"
const INTENT_RECLAIM_CONFIRM := "reclaim_confirm"
const INTENT_SERVER_ACTION := "server_action"
const INTENT_OPEN_WAREHOUSE := "open_warehouse"
const INTENT_SHOVEL_ALL_CONFIRM := "shovel_all_confirm"

static func tile_action_intent(state: FarmState, col: int, row: int, tool_mode: int, selected_seed: int, selected_fertilizer: int) -> Dictionary:
	if row < 0 or col < 0 or state.farm.is_empty() or row >= state.farm.size() or col >= state.farm[row].size():
		return {"type": INTENT_NONE}
	var cell: Dictionary = state.farm[row][col]
	if not state.is_cell_unlocked(cell):
		var next_locked := state.get_next_locked_plot()
		if next_locked.x != col or next_locked.y != row:
			return _toast("请按顺序先开垦下一块土地", 1.8)
		return {"type": INTENT_RECLAIM_CONFIRM, "col": col, "row": row}

	var plot_index: int = state.get_plot_index(col, row)
	if int(cell.get("crop_id", -1)) == -1:
		return _empty_cell_intent(plot_index, tool_mode, selected_seed)
	return _crop_cell_intent(plot_index, tool_mode, selected_fertilizer)

static func context_menu_item_specs(state: FarmState, col: int, row: int, crop_count: int) -> Array:
	if row < 0 or col < 0 or state.farm.is_empty() or row >= state.farm.size() or col >= state.farm[row].size():
		return []
	var cell: Dictionary = state.farm[row][col]
	if int(cell.get("crop_id", -1)) == -1:
		var seed_items: Array = []
		for crop_id in range(crop_count):
			seed_items.append({"type": "plant", "crop_id": crop_id})
		return seed_items

	var items: Array = []
	if float(cell.get("progress", 0.0)) >= 1.0:
		items.append({"type": "harvest"})
	else:
		if int(cell.get("weed_count", 0)) > 0:
			items.append({"type": "weed"})
		if int(cell.get("bug_count", 0)) > 0:
			items.append({"type": "pest"})
		if int(cell.get("water_state", 0)) == 0:
			items.append({"type": "water"})
		items.append({"type": "fertilize"})
	items.append({"type": "shovel"})
	return items

static func _empty_cell_intent(plot_index: int, tool_mode: int, selected_seed: int) -> Dictionary:
	if tool_mode == 4 or tool_mode == 5:
		return _toast("这里没有作物可以铲除", 1.2)
	if tool_mode == 8:
		return _server_action("harvest_all")
	if tool_mode == 9:
		return {"type": INTENT_OPEN_WAREHOUSE}
	if selected_seed >= 0:
		return _server_action("plant", {"plot_index": plot_index, "crop_id": selected_seed})
	return _toast("请先选择种子!", 1.5)

static func _crop_cell_intent(plot_index: int, tool_mode: int, selected_fertilizer: int) -> Dictionary:
	match tool_mode:
		0:
			return _toast("当前是普通模式，切换工具操作作物", 1.0)
		1:
			return _server_action("water", {"plot_index": plot_index})
		2:
			if selected_fertilizer >= 0:
				return _server_action("fertilize", {"plot_index": plot_index, "fert_id": selected_fertilizer})
			return _toast("请先在商店购买并选择肥料", 1.5)
		3:
			return _server_action("harvest", {"plot_index": plot_index})
		4:
			return _server_action("shovel", {"plot_index": plot_index})
		5:
			return {"type": INTENT_SHOVEL_ALL_CONFIRM}
		6:
			return _server_action("remove_bug", {"plot_index": plot_index})
		7:
			return _server_action("remove_weed", {"plot_index": plot_index})
		8:
			return _server_action("harvest_all")
		9:
			return {"type": INTENT_OPEN_WAREHOUSE}
	return {"type": INTENT_NONE}

static func _toast(message: String, duration: float) -> Dictionary:
	return {"type": INTENT_TOAST, "message": message, "duration": duration}

static func _server_action(action: String, params: Dictionary = {}) -> Dictionary:
	return {"type": INTENT_SERVER_ACTION, "action": action, "params": params}
