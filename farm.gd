extends Node2D

const CropAtlas = preload("res://scripts/crop_atlas.gd")
const FarmApi = preload("res://scenes/farm_api.gd")
const CameraController = preload("res://scenes/camera_controller.gd")
const FarmRenderer = preload("res://scenes/farm_renderer.gd")
const TOOL_ICON_TEXTURES: Array[Texture2D] = [
	null,
	preload("res://assets/ui/icons/tool_water.png"),
	preload("res://assets/ui/icons/tool_fertilizer.png"),
	preload("res://assets/ui/icons/tool_harvest.png"),
	preload("res://assets/ui/icons/tool_shovel.png"),
	preload("res://assets/ui/icons/tool_shovel_all.png"),
	preload("res://assets/ui/icons/tool_pest.png"),
	preload("res://assets/ui/icons/tool_weed.png"),
	preload("res://assets/ui/icons/btn_harvest_all.png"),
	preload("res://assets/ui/icons/btn_warehouse.png"),
]
const TOOL_CURSOR_MAX_SIZE := 48
const LAND_TEXTURE_PATHS := {
	"locked": "res://assets/land/land_grass_locked.png",
	"yellow_dry": "res://assets/land/land_yellow_dry.png",
	"yellow_wet": "res://assets/land/land_yellow_wet.png",
	"red_dry": "res://assets/land/land_red_dry.png",
	"red_wet": "res://assets/land/land_red_wet.png",
	"black_dry": "res://assets/land/land_black_dry.png",
	"black_wet": "res://assets/land/land_black_wet.png",
}
var land_textures: Dictionary = {}
var land_texture_source_rects: Dictionary = {}
var land_texture_avg_colors: Dictionary = {}
var _cursor_cache: Array[ImageTexture] = []
var _sign_texture: Texture2D = null

var ctx_menu_open: bool = false
var ctx_col: int = -1
var ctx_row: int = -1
var ctx_menu_items: Array = []
var ctx_batch_action: Dictionary = {}

# ===================== Iso Farm 2.5D =====================
const VIEW_W := 1448.0
const VIEW_H := 1086.0
const TW := 168
const TH := 84
const TILE_GAP := 8
const COLS := 6
const ROWS := 5
const OX := 500.0
const OY := 320.0
const SAVE_PATH := "user://qq_farm_save.json"
const PLOT_ANCHORS_PATH := "PlotAnchors"
const INITIAL_UNLOCKED_PLOTS := 1
const BASE_RECLAIM_COST := 60
const RECLAIM_COST_STEP := 35
const LAND_LEVEL_LOCKED := 0
const LAND_LEVEL_MAX := 4
const LAND_UPGRADE_WORK_REQUIRED := 30

var CROPS: Array = []
var CROP_COLORS: Array = []
var RENDER_STAGE_THRESHOLDS: Array = [0.18, 0.45, 0.72, 0.90]

var gold := 200
var level := 1
var exp_val := 0
var exp_to_level := 100

var farm: Array = []
var selected_seed := -1
var shop_open := false
var hover_col := -1
var hover_row := -1
var mouse_held := false
var last_action_col := -1
var last_action_row := -1
# 工具模式: 0=普通 1=浇水 2=施肥 3=收获 4=铲除
var tool_mode := 0

# 背包系统
var inventory = {}
var inventory_open := false
var reclaim_confirm_open := false
var reclaim_confirm_col := -1
var reclaim_confirm_row := -1
var reset_confirm_open := false
var settings_open := false
var warehouse_open := false
var shovel_all_confirm_open := false

var toast_text := ""
var toast_timer := 0.0
var save_timer := 0.0
var event_check_timer := 0.0
var _game_time := 0.0 # 游戏内累计秒数，用于保护期判断

# Auth state (set from Login scene)
var auth_token := ""
var user_info := {}
var farm_api: Node
var camera_controller: Node
var _save_pending := false # 云端保存中
var _config_loaded := false
var _pending_sell_crop_id := -1

# Camera 拖拽缩放
var cam: Camera2D
var _cam_min_zoom := 1.0 # 由 _fit_camera_to_screen 动态更新
# UI 绘制目标（CanvasLayer 子节点，画在屏幕坐标系）
var _ui_draw_target: CanvasItem = null
var _ui_overlay: Control = null
# 中文字体
var _cn_font: Font = null

# 肥料系统
# [名称, 金币价, 类型, 效果值, 可用阶段列表, 每株上限, max_minutes_limit]
# 类型: speed=减生长时间, water_protect/bug_protect/weed_protect=保护期, yield_bonus=增产
var FERTILIZERS: Array = [
	["初级速生肥", 15, "speed", 0.08, [0, 1], 1, 10],
	["中级速生肥", 40, "speed", 0.12, [1, 2], 1, 30],
	["高级速生肥", 80, "speed", 0.18, [2], 1, 60],
	["保湿肥", 30, "water_protect", 7200.0, [0, 1, 2], 1, 0],
	["防虫肥", 35, "bug_protect", 7200.0, [1, 2], 1, 0],
	["除草剂", 25, "weed_protect", 7200.0, [-1, 0, 1, 2], 1, 0],
	["丰收肥", 60, "yield_bonus", 0.10, [2], 1, 0],
]
var fertilizer_inventory = {} # {fert_index: count}
var selected_fertilizer = -1 # FERTILIZERS数组下标，-1=未选择
var shop_tab := 0 # 0=种子, 1=肥料

const DEFAULT_CROPS := [
	["生菜", 12, 32, 12, "lettuce", 4, 8, 3, 5, 0.06, 0, 0.04, 0, 1],
	["辣椒", 20, 58, 20, "pepper", 6, 10, 4, 7, 0.10, 0.05, 0.05, 1, 1],
	["茄子", 35, 95, 32, "eggplant", 5, 19, 3, 6, 0.10, 0.08, 0.08, 2, 2],
	["西红柿", 55, 150, 48, "tomato", 8, 19, 6, 10, 0.14, 0.09, 0.07, 2, 2],
	["草莓", 80, 220, 70, "strawberry", 12, 18, 9, 14, 0.16, 0.12, 0.10, 2, 2],
	["玉米", 120, 340, 100, "corn", 6, 57, 4, 7, 0.18, 0.07, 0.12, 2, 3],
	["向日葵", 170, 500, 135, "sunflower", 4, 125, 3, 5, 0.13, 0.04, 0.09, 1, 2],
	["南瓜", 240, 720, 180, "pumpkin", 3, 240, 2, 4, 0.12, 0.11, 0.15, 3, 3],
	["西瓜", 320, 980, 230, "watermelon", 5, 196, 3, 7, 0.20, 0.12, 0.14, 3, 3],
]

const DEFAULT_FERTILIZERS: Array = [
	["初级速生肥", 15, "speed", 0.08, [0, 1], 1, 10],
	["中级速生肥", 40, "speed", 0.12, [1, 2], 1, 30],
	["高级速生肥", 80, "speed", 0.18, [2], 1, 60],
	["保湿肥", 30, "water_protect", 7200.0, [0, 1, 2], 1, 0],
	["防虫肥", 35, "bug_protect", 7200.0, [1, 2], 1, 0],
	["除草剂", 25, "weed_protect", 7200.0, [-1, 0, 1, 2], 1, 0],
	["丰收肥", 60, "yield_bonus", 0.10, [2], 1, 0],
]

func _ready():
	# 加载中文字体
	var font_path := "res://assets/fonts/simhei.ttf"
	if ResourceLoader.exists(font_path):
		_cn_font = load(font_path) as Font
	# Read auth data from login scene
	if get_tree().has_meta("auth_token"):
		auth_token = str(get_tree().get_meta("auth_token"))
		user_info = get_tree().get_meta("user_info") if get_tree().has_meta("user_info") else {}

	farm_api = FarmApi.new()
	farm_api.auth_token = auth_token
	farm_api.config_completed.connect(_on_config_response)
	farm_api.load_completed.connect(_on_load_response)
	farm_api.save_completed.connect(_on_save_response)
	farm_api.action_completed.connect(_on_action_response)
	farm_api.sell_completed.connect(_on_sell_response)
	add_child(farm_api)

	# Camera for pan/zoom
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	camera_controller = CameraController.new()
	camera_controller.setup(cam, _cam_min_zoom)
	camera_controller.tap.connect(_handle_click)
	add_child(camera_controller)
	_setup_default_config()
	_initialize_default_state()
	_load_land_textures()
	_init_sandy_base()
	_build_cursor_cache()
	_sign_texture = load("res://assets/land/sign.png") as Texture2D
	_apply_tool_cursor()
	_init_overlays()
	_setup_camera()
	# 设置 UIOverlay 引用，让 UI 在 CanvasLayer 上独立绘制
	_ui_overlay = get_node_or_null("UILayer/UIOverlay")
	if _ui_overlay:
		_ui_overlay.farm_ref = self
	if auth_token.is_empty():
		_config_loaded = true
		_load_game()
	else:
		_load_remote_config()

func _setup_camera():
	cam.position = Vector2(500.0, 530.0)
	cam.position_smoothing_enabled = false
	_fit_camera_to_screen()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	get_viewport().size_changed.connect(_fit_camera_to_screen)

func _setup_default_config():
	CROPS = DEFAULT_CROPS.duplicate(true)
	FERTILIZERS = DEFAULT_FERTILIZERS.duplicate(true)
	CROP_COLORS = [
		[Color(0.42, 0.76, 0.34), Color(0.72, 0.96, 0.46)],
		[Color(0.24, 0.68, 0.22), Color(0.92, 0.24, 0.18)],
		[Color(0.30, 0.72, 0.26), Color(0.48, 0.22, 0.62)],
		[Color(0.28, 0.76, 0.28), Color(0.96, 0.24, 0.18)],
		[Color(0.28, 0.76, 0.34), Color(0.98, 0.18, 0.26)],
		[Color(0.36, 0.76, 0.22), Color(0.98, 0.86, 0.20)],
		[Color(0.28, 0.64, 0.24), Color(0.98, 0.74, 0.16)],
		[Color(0.30, 0.70, 0.24), Color(0.96, 0.52, 0.12)],
		[Color(0.26, 0.66, 0.22), Color(0.34, 0.86, 0.28)],
	]

func _load_remote_config():
	if not is_instance_valid(farm_api):
		_config_loaded = true
		_load_game()
		return
	farm_api.request_config()

func _on_config_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary and int(parsed.get("code", -1)) == 0:
			var data: Dictionary = parsed.get("data", {})
			_apply_remote_config(data)
	_config_loaded = true
	_load_game()

func _apply_remote_config(data: Dictionary):
	if data.has("crops") and data["crops"] is Array:
		var crops: Array = []
		for item in data["crops"]:
			if not (item is Dictionary):
				continue
			var crop: Dictionary = item
			crops.append([
				str(crop.get("name", "")),
				int(crop.get("seed_cost", 0)),
				int(crop.get("base_yield", 0)) * int(crop.get("unit_sell", 0)),
				float(crop.get("grow_time", 0.0)),
				str(crop.get("texture_key", "")),
				int(crop.get("base_yield", 0)),
				int(crop.get("unit_sell", 0)),
				int(crop.get("min_yield", 0)),
				int(crop.get("max_yield", 0)),
				float(crop.get("dry_rate", 0.0)),
				float(crop.get("bug_rate", 0.0)),
				float(crop.get("weed_rate", 0.0)),
				int(crop.get("max_bug", 0)),
				int(crop.get("max_weed", 0)),
			])
		if not crops.is_empty():
			CROPS = crops
	if data.has("fertilizers") and data["fertilizers"] is Array:
		var fertilizers: Array = []
		for item in data["fertilizers"]:
			if not (item is Dictionary):
				continue
			var fert: Dictionary = item
			var allowed_stages: Array = []
			var raw_stages = fert.get("allowed_stages", [])
			if raw_stages is Array:
				for stage in raw_stages:
					allowed_stages.append(int(stage))
			fertilizers.append([
				str(fert.get("name", "")),
				int(fert.get("cost", 0)),
				str(fert.get("type", "")),
				float(fert.get("effect_value", 0.0)),
				allowed_stages,
				int(fert.get("per_crop_limit", 0)),
				int(fert.get("max_minutes_limit", 0)),
			])
		if not fertilizers.is_empty():
			FERTILIZERS = fertilizers
	if data.has("render_stage_thresholds") and data["render_stage_thresholds"] is Array:
		var thresholds: Array = []
		for value in data["render_stage_thresholds"]:
			thresholds.append(float(value))
		if thresholds.size() >= 4:
			RENDER_STAGE_THRESHOLDS = thresholds
	_sync_all_overlays()

# 等比缩放：viewport 宽高比 >= 场景宽高比 时以宽为准，否则以高为准
func _fit_camera_to_screen():
	var bg := get_node_or_null("Background")
	if camera_controller != null and bg is Sprite2D:
		camera_controller.fit_to_background(bg)
		_cam_min_zoom = camera_controller.min_zoom

func _init_overlays():
	# ---- ShopOverlay ----
	var shop := get_node_or_null("UILayer/ShopOverlay")
	if shop == null:
		return
	shop.CROPS = CROPS
	shop.CROP_COLORS = CROP_COLORS
	shop.FERTILIZERS = FERTILIZERS
	shop.seed_selected.connect(func(i: int):
		selected_seed = i
		toast_text = "已选择种子: " + str(CROPS[i][0])
		toast_timer = 1.5
		shop.selected_seed = i
		shop.queue_redraw()
	)
	shop.crop_sell_requested.connect(func(cid: int, amount: int):
		if not auth_token.is_empty():
			_send_sell(cid, amount)
		else:
			_sell_inventory_crop(cid, amount)
		_sync_shop_data(shop)
		shop.queue_redraw()
	)
	shop.fertilizer_buy_requested.connect(func(fi: int):
		if not auth_token.is_empty():
			_send_action("buy_fertilizer", {"fert_id": fi})
		else:
			# 离线模式：本地扣金币
			var fert: Array = FERTILIZERS[fi]
			var cost: int = int(fert[1])
			if gold >= cost:
				gold -= cost
				if not fertilizer_inventory.has(fi):
					fertilizer_inventory[fi] = 0
				fertilizer_inventory[fi] = fertilizer_inventory[fi] + 1
				selected_fertilizer = fi
				toast_text = "购买 " + str(fert[0]) + " 成功!"
				toast_timer = 1.5
			else:
				toast_text = "金币不足!"
				toast_timer = 1.5
		_sync_shop_data(shop)
		shop.queue_redraw()
	)
	shop.fertilizer_selected.connect(func(fi: int):
		selected_fertilizer = fi
		toast_text = "已选中: " + str(FERTILIZERS[fi][0])
		toast_timer = 1.5
		_sync_shop_data(shop)
		shop.queue_redraw()
	)
	shop.closed.connect(func():
		shop.visible = false
		shop_open = false
		queue_redraw()
	)

	# ---- InventoryOverlay ----
	var inv := get_node_or_null("UILayer/InventoryOverlay")
	if inv:
		inv.CROPS = CROPS
		inv.CROP_COLORS = CROP_COLORS
		inv.sell_requested.connect(func(cid: int, amount: int):
			if not auth_token.is_empty():
				_send_sell(cid, amount)
			else:
				_sell_inventory_crop(cid, amount)
			inv.inventory = inventory
			inv.queue_redraw()
		)
		inv.sell_all_requested.connect(func():
			if not auth_token.is_empty():
				_send_action("sell_all")
			else:
				_sell_all_inventory()
			inv.inventory = inventory
			inv.queue_redraw()
		)
		inv.closed.connect(func():
			inv.visible = false
			inventory_open = false
			queue_redraw()
		)

	# ---- SettingsOverlay ----
	var setn := get_node_or_null("UILayer/SettingsOverlay")
	if setn:
		setn.logout_requested.connect(func():
			setn.visible = false
			settings_open = false
			_logout()
		)
		setn.reset_requested.connect(func():
			setn.visible = false
			settings_open = false
			reset_confirm_open = true
			queue_redraw()
		)
		setn.closed.connect(func():
			setn.visible = false
			settings_open = false
			queue_redraw()
		)

func _sync_shop_data(shop):
	shop.inventory = inventory
	shop.fertilizer_inventory = fertilizer_inventory
	shop.selected_seed = selected_seed
	shop.selected_fertilizer = selected_fertilizer

func _sync_all_overlays():
	# Refresh any open overlay with latest state
	var shop := get_node_or_null("UILayer/ShopOverlay")
	if shop:
		shop.CROPS = CROPS
		shop.CROP_COLORS = CROP_COLORS
		shop.FERTILIZERS = FERTILIZERS
		if shop_open:
			_sync_shop_data(shop)
			shop.queue_redraw()
	var inv := get_node_or_null("UILayer/InventoryOverlay")
	if inv:
		inv.CROPS = CROPS
		inv.CROP_COLORS = CROP_COLORS
		if inventory_open:
			inv.inventory = inventory
			inv.queue_redraw()

func _send_sell(crop_id: int, count: int):
	if count <= 0 or not is_instance_valid(farm_api):
		return
	_pending_sell_crop_id = crop_id
	farm_api.request_sell(crop_id, count)

func _on_sell_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary and int(parsed.get("code", -1)) == 0:
			var d: Dictionary = parsed.get("data", {})
			gold = int(d.get("gold", gold))
			var sold: int = int(d.get("sold_count", 0))
			var earned: int = int(d.get("gold_earned", 0))
			var crop_id := _pending_sell_crop_id
			_pending_sell_crop_id = -1
			if crop_id >= 0:
				inventory[crop_id] = max(0, int(inventory.get(crop_id, 0)) - sold)
				toast_text = "售出 " + str(CROPS[crop_id][0]) + " x" + str(sold) + "，获得 " + str(earned) + " 金币"
				toast_timer = 1.5
			_cloud_load()

func _initialize_default_state():
	gold = 200
	level = 1
	exp_val = 0
	exp_to_level = 100
	farm = []
	for _r in range(ROWS):
		var row: Array = []
		for _c in range(COLS):
			row.append(_create_empty_cell(_c, _r))
		farm.append(row)
	inventory = {}
	selected_seed = -1
	tool_mode = 0
	hover_col = -1
	hover_row = -1
	mouse_held = false
	last_action_col = -1
	last_action_row = -1
	shop_open = false
	inventory_open = false
	reclaim_confirm_open = false
	warehouse_open = false
	shovel_all_confirm_open = false
	reclaim_confirm_col = -1
	reclaim_confirm_row = -1
	reset_confirm_open = false
	settings_open = false
	toast_text = ""
	toast_timer = 0.0
	save_timer = 0.0
	event_check_timer = 0.0
	_game_time = 0.0
	fertilizer_inventory = {}
	selected_fertilizer = -1
	shop_tab = 0

func _load_land_textures():
	land_textures.clear()
	land_texture_source_rects.clear()
	land_texture_avg_colors.clear()
	for key in LAND_TEXTURE_PATHS.keys():
		var texture := load(str(LAND_TEXTURE_PATHS[key])) as Texture2D
		land_textures[key] = texture
		if texture != null:
			land_texture_source_rects[key] = _get_texture_alpha_bounds(texture)
			land_texture_avg_colors[key] = _get_texture_avg_color(texture)

const SANDY_BASE_PAD := 50.0

func _init_sandy_base():
	var base := get_node_or_null("PlotAnchors/SandyBase") as Polygon2D
	if base == null:
		return
	var anchors := get_node(PLOT_ANCHORS_PATH)
	var corners: Array[Vector2] = [
		anchors.get_node("Plot_0_0").position,
		anchors.get_node("Plot_0_5").position,
		anchors.get_node("Plot_4_5").position,
		anchors.get_node("Plot_4_0").position,
	]
	var e0 := (corners[1] - corners[0]).normalized()
	var e1 := (corners[3] - corners[0]).normalized()
	var n0 := Vector2(-e0.y, e0.x)
	var n1 := Vector2(e1.y, -e1.x)
	var pad_vecs: Array[Vector2] = [
		n0 * SANDY_BASE_PAD + n1 * SANDY_BASE_PAD,
		- n0 * SANDY_BASE_PAD + n1 * SANDY_BASE_PAD,
		- n0 * SANDY_BASE_PAD - n1 * SANDY_BASE_PAD,
		n0 * SANDY_BASE_PAD - n1 * SANDY_BASE_PAD,
	]
	var expanded: PackedVector2Array
	for i in range(4):
		expanded.append(corners[i] + pad_vecs[i])
	var center := Vector2.ZERO
	for p in expanded:
		center += p
	center /= 4.0
	var poly: PackedVector2Array
	for p in expanded:
		poly.append(p - center)
	base.position = center
	base.texture = load("res://assets/land/sandy_gravel_02_diff_1k.png") as Texture2D
	base.polygon = poly
	var max_dist := 0.0
	for p in poly:
		max_dist = maxf(max_dist, maxf(absf(p.x), absf(p.y)))
	var uv_scale: float = 0.5 / max_dist if max_dist > 0.0 else 1.0
	var uvs: PackedVector2Array
	for p in poly:
		uvs.append(Vector2(0.5 + p.x * uv_scale, 0.5 + p.y * uv_scale))
	base.uv = uvs

func iso2screen(c: int, r: int) -> Vector2:
	return Vector2(OX + (c - r) * TW * 0.5, OY + (c + r) * TH * 0.5)

func _window_to_viewport_pos(window_pos: Vector2) -> Vector2:
	return window_pos

func _viewport_to_world(viewport_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * viewport_pos

# 窗口输入坐标 → 世界坐标（用于地块点击检测）
func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return _viewport_to_world(_window_to_viewport_pos(screen_pos))

func _get_plot_position(c: int, r: int) -> Vector2:
	var anchors := get_node_or_null(PLOT_ANCHORS_PATH)
	if anchors != null:
		var plot := anchors.get_node_or_null("Plot_%d_%d" % [r, c])
		if plot is Node2D:
			return anchors.position + (plot as Node2D).position
	return iso2screen(c, r)

func _create_empty_cell(col: int, row: int) -> Dictionary:
	var initial_land_level := 1 if _get_plot_index(col, row) < INITIAL_UNLOCKED_PLOTS else LAND_LEVEL_LOCKED
	return {
		"crop_id": - 1,
		"progress": 0.0,
		"visual_progress": 0.0,
		"wet_timer": 0.0,
		"unlocked": initial_land_level > LAND_LEVEL_LOCKED,
		"land_level": initial_land_level,
		"land_work": 0,
		# 打理状态
		"water_state": 0, # 0=Normal, 1=Dry, 2=Watered
		"dry_timer": 0.0, # 缺水累计秒数（产量惩罚用）
		"water_protect_until": 0.0,
		"bug_count": 0,
		"bug_since": 0.0,
		"bug_protect_until": 0.0,
		"weed_count": 0,
		"weed_since": 0.0,
		"weed_protect_until": 0.0,
		# 肥料状态
		"fert_used": 0,
		"fert_stage_used": {},
		"fert_ids_used": [],
		"yield_bonus_rate": 0.0,
		"yield_loss_rate": 0.0,
	}

func _get_plot_index(col: int, row: int) -> int:
	return row * COLS + col

func _get_reclaim_level(col: int, row: int) -> int:
	return _get_plot_index(col, row) + 1

func _get_reclaim_cost(col: int, row: int) -> int:
	return BASE_RECLAIM_COST + _get_plot_index(col, row) * RECLAIM_COST_STEP

func _is_cell_unlocked(cell: Dictionary) -> bool:
	return int(cell.get("land_level", LAND_LEVEL_LOCKED)) > LAND_LEVEL_LOCKED

func _get_land_level_name(land_level: int) -> String:
	if land_level <= LAND_LEVEL_LOCKED:
		return "未开垦"
	if land_level == 1:
		return "黄土地Lv1"
	if land_level == 2:
		return "黄土地Lv2"
	if land_level == 3:
		return "红土地"
	return "黑土地"

func screen2iso(pos: Vector2) -> Vector2i:
	var dx := (pos.x - OX) / (TW * 0.5)
	var dy := (pos.y - OY) / (TH * 0.5)
	return Vector2i(int((dx + dy) * 0.5), int((dy - dx) * 0.5))

func iso_corners(cx: float, cy: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(cx, cy - TH * 0.5),
		Vector2(cx + TW * 0.5, cy),
		Vector2(cx, cy + TH * 0.5),
		Vector2(cx - TW * 0.5, cy),
	])

func iso_visual_corners(cx: float, cy: float) -> PackedVector2Array:
	var hw: float = (TW - TILE_GAP) * 0.5
	var hh: float = (TH - TILE_GAP) * 0.5
	return PackedVector2Array([
		Vector2(cx, cy - hh),
		Vector2(cx + hw, cy),
		Vector2(cx, cy + hh),
		Vector2(cx - hw, cy),
	])

func in_diamond(px: float, py: float, cx: float, cy: float) -> bool:
	return absf(px - cx) / (TW * 0.5) + absf(py - cy) / (TH * 0.5) <= 1.0

func _process(delta: float):
	if farm.is_empty() or farm.size() < ROWS:
		return
	_update_visual_progress(delta)

	save_timer += delta
	if save_timer >= 30.0:
		save_timer = 0.0
		if not auth_token.is_empty():
			_cloud_load() # 定期从服务端同步最新状态
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			toast_text = ""
	queue_redraw()
	if _ui_overlay and is_instance_valid(_ui_overlay):
		_ui_overlay.queue_redraw()

func _update_visual_progress(delta: float):
	if auth_token.is_empty():
		return
	for r in range(ROWS):
		if farm[r].size() < COLS:
			return
		for c in range(COLS):
			var cell: Dictionary = farm[r][c]
			var cid: int = int(cell.get("crop_id", -1))
			var server_progress := clampf(float(cell.get("progress", 0.0)), 0.0, 1.0)
			if cid < 0 or cid >= CROPS.size() or server_progress >= 1.0:
				cell["visual_progress"] = server_progress
				continue
			var grow_time := maxf(float(CROPS[cid][3]), 0.001)
			var visual_progress := maxf(float(cell.get("visual_progress", server_progress)), server_progress)
			cell["visual_progress"] = minf(visual_progress + delta / grow_time, 0.999)

func _notification(what: int):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game(false)

func _exit_tree():
	Input.set_custom_mouse_cursor(null)

func _set_tool_mode(mode: int):
	tool_mode = clampi(mode, 0, TOOL_ICON_TEXTURES.size() - 1)
	_apply_tool_cursor()

func _build_cursor_cache():
	_cursor_cache.clear()
	for i in range(TOOL_ICON_TEXTURES.size()):
		var texture := TOOL_ICON_TEXTURES[i]
		if texture == null:
			_cursor_cache.append(null)
			continue
		var image := texture.get_image()
		if image == null:
			_cursor_cache.append(null)
			continue
		var size := image.get_size()
		var longest_side := maxf(size.x, size.y)
		if longest_side > TOOL_CURSOR_MAX_SIZE and longest_side > 0.0:
			var s := TOOL_CURSOR_MAX_SIZE / longest_side
			image.resize(int(round(size.x * s)), int(round(size.y * s)), Image.INTERPOLATE_LANCZOS)
		_cursor_cache.append(ImageTexture.create_from_image(image))

func _apply_tool_cursor():
	if tool_mode < 0 or tool_mode >= _cursor_cache.size():
		Input.set_custom_mouse_cursor(null)
		return
	var cached := _cursor_cache[tool_mode]
	if cached == null:
		Input.set_custom_mouse_cursor(null)
		return
	var hotspot := cached.get_size() * 0.5
	Input.set_custom_mouse_cursor(cached, Input.CURSOR_ARROW, hotspot)

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_S:
			_save_game()
			queue_redraw()
			return

	if camera_controller != null and camera_controller.handle_input(event):
		queue_redraw()
		return

	var vp: Vector2 = get_viewport().get_visible_rect().size

	# --- Mouse button up ---
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_held = false
		last_action_col = -1
		last_action_row = -1
		ctx_batch_action.clear()
		return

	# --- Mouse motion ---
	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = event.position
		# 地块 hover 用世界坐标
		var wp := _viewport_to_world(mouse_pos)
		var wx: float = wp.x
		var wy: float = wp.y
		hover_col = -1
		hover_row = -1
		var best_dist_h := INF
		for row in range(ROWS):
			for col in range(COLS):
				if farm.is_empty() or row >= farm.size() or col >= farm[row].size():
					continue
				var sp := _get_plot_position(col, row)
				if in_diamond(wx, wy, sp.x, sp.y):
					var d: float = (Vector2(wx, wy) - sp).length_squared()
					if d < best_dist_h:
						best_dist_h = d
						hover_col = col
						hover_row = row
		# Drag action: if mouse held and moved to a NEW tile, do action
		if mouse_held and hover_col >= 0 and not shop_open and not inventory_open and not reclaim_confirm_open and not reset_confirm_open and not settings_open and not warehouse_open and not shovel_all_confirm_open:
			if hover_col != last_action_col or hover_row != last_action_row:
				if not ctx_batch_action.is_empty():
					_execute_context_action(hover_col, hover_row, ctx_batch_action)
				last_action_col = hover_col
				last_action_row = hover_row
		queue_redraw()
		return

	# --- Mouse button down ---
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# overlay 打开时，不处理任何点击（overlay 有自己的 _input 处理）
		if shop_open or inventory_open or settings_open:
			return
		var mouse_pos: Vector2 = event.position
		var mx: float = mouse_pos.x
		var my: float = mouse_pos.y
		# 地块点击用世界坐标
		var wp := _viewport_to_world(mouse_pos)
		var wx: float = wp.x
		var wy: float = wp.y
		mouse_held = false # only set true if click is on the grid

		if reclaim_confirm_open or shovel_all_confirm_open or reset_confirm_open:
			return

		# Check warehouse overlay (屏幕坐标)
		if warehouse_open:
			var ww := 360.0; var wh := 300.0
			var wox := (vp.x - ww) / 2; var woy := (vp.y - wh) / 2
			if mx < wox or mx > wox + ww or my < woy or my > woy + wh:
				warehouse_open = false; queue_redraw(); return
			return

		# Check context menu
		if ctx_menu_open:
			var ctx_wp := _get_plot_position(ctx_col, ctx_row)
			var vp_pos = (ctx_wp - cam.position) * cam.zoom + vp * 0.5
			var menu_w = ctx_menu_items.size() * 50 + 10
			var menu_rect = _ctx_menu_rect(vp_pos)
			if _point_in_rect(Vector2(mx, my), menu_rect):
				var clicked_idx = int((mx - (menu_rect.position.x + 5)) / 50.0)
				if clicked_idx >= 0 and clicked_idx < ctx_menu_items.size():
					ctx_batch_action = ctx_menu_items[clicked_idx].duplicate()
					mouse_held = true
					last_action_col = ctx_col
					last_action_row = ctx_row
					_execute_context_action(ctx_col, ctx_row, ctx_batch_action)
				return
			else:
				ctx_menu_open = false
				queue_redraw()

		# Check grid tiles (世界坐标) — 找最近的匹配地块
		var best_col := -1
		var best_row := -1
		var best_dist := INF
		for row in range(ROWS):
			for col in range(COLS):
				if farm.is_empty() or row >= farm.size() or col >= farm[row].size():
					continue
				var sp := _get_plot_position(col, row)
				if in_diamond(wx, wy, sp.x, sp.y):
					var d: float = (Vector2(wx, wy) - sp).length_squared()
					if d < best_dist:
						best_dist = d
						best_col = col
						best_row = row
		if best_col >= 0:
			mouse_held = true
			_open_context_menu(best_col, best_row)
			last_action_col = best_col
			last_action_row = best_row
			queue_redraw()
			return

func _do_tile_action(col: int, row: int):
	if farm.is_empty() or row >= farm.size() or col >= farm[row].size():
		return
	var cell: Dictionary = farm[row][col]
	if not _is_cell_unlocked(cell):
		var next_locked := _get_next_locked_plot()
		if next_locked.x != col or next_locked.y != row:
			toast_text = "请按顺序先开垦下一块土地"
			toast_timer = 1.8
			return
		_open_reclaim_confirm(col, row)
		return

	var pi: int = row * COLS + col

	# 空地 → 种植
	if cell["crop_id"] == -1:
		if tool_mode == 4 or tool_mode == 5:
			toast_text = "这里没有作物可以铲除"
			toast_timer = 1.2
		elif tool_mode == 8:
			_send_action("harvest_all")
		elif tool_mode == 9:
			warehouse_open = true
			queue_redraw()
		elif selected_seed >= 0:
			_send_action("plant", {"plot_index": pi, "crop_id": selected_seed})
		else:
			toast_text = "请先选择种子!"
			toast_timer = 1.5
		return

	# 有作物 → 发送到服务端执行
	match tool_mode:
		0:
			toast_text = "当前是普通模式，切换工具操作作物"
			toast_timer = 1.0
		1: _send_action("water", {"plot_index": pi})
		2:
			if selected_fertilizer >= 0:
				_send_action("fertilize", {"plot_index": pi, "fert_id": selected_fertilizer})
			else:
				toast_text = "请先在商店购买并选择肥料"
				toast_timer = 1.5
		3: _send_action("harvest", {"plot_index": pi})
		4: _send_action("shovel", {"plot_index": pi})
		5:
			shovel_all_confirm_open = true
			queue_redraw()
		6: _send_action("remove_bug", {"plot_index": pi})
		7: _send_action("remove_weed", {"plot_index": pi})
		8: _send_action("harvest_all")
		9:
			warehouse_open = true
			queue_redraw()

func _ctx_menu_rect(vp_pos: Vector2) -> Rect2:
	# 菜单放在地块（作物）正下方，箭头朝上指向作物。
	# vp_pos 为地块中心屏幕坐标；TH*0.5 为地块半高，乘以缩放再留一点间距。
	var menu_w := ctx_menu_items.size() * 50 + 10
	var menu_h := 60.0
	var below_y := vp_pos.y + (TH * 0.5) * cam.zoom.y + 14.0
	return Rect2(vp_pos.x - menu_w * 0.5, below_y, menu_w, menu_h)

func _open_context_menu(col: int, row: int):
	if farm.is_empty() or row >= farm.size() or col >= farm[row].size():
		return
	var cell: Dictionary = farm[row][col]
	if not _is_cell_unlocked(cell):
		var next_locked := _get_next_locked_plot()
		if next_locked.x != col or next_locked.y != row:
			toast_text = "请按顺序先开垦下一块土地"
			toast_timer = 1.8
			return
		_open_reclaim_confirm(col, row)
		return
		
	ctx_col = col
	ctx_row = row
	ctx_menu_items.clear()
	
	if cell["crop_id"] == -1:
		for i in range(CROPS.size()):
			ctx_menu_items.append({
				"type": "plant",
				"crop_id": i,
				"icon": _get_crop_seed_texture(i)
			})
	else:
		# 成熟以进度为准（与作物上的"收获"标签一致），_get_growth_stage 最高只到 2，
		# 不能用来判断成熟，否则成熟作物永远显示不出收获按钮。
		if float(cell.get("progress", 0.0)) >= 1.0:
			ctx_menu_items.append({"type": "harvest", "icon": TOOL_ICON_TEXTURES[3]})
		else:
			if int(cell.get("weed_count", 0)) > 0:
				ctx_menu_items.append({"type": "weed", "icon": TOOL_ICON_TEXTURES[7]})
			if int(cell.get("bug_count", 0)) > 0:
				ctx_menu_items.append({"type": "pest", "icon": TOOL_ICON_TEXTURES[6]})
			if int(cell.get("water_state", 0)) == 0:
				ctx_menu_items.append({"type": "water", "icon": TOOL_ICON_TEXTURES[1]})
			ctx_menu_items.append({"type": "fertilize", "icon": TOOL_ICON_TEXTURES[2]})
			
		ctx_menu_items.append({"type": "shovel", "icon": TOOL_ICON_TEXTURES[4]})
		
	ctx_menu_open = true
	queue_redraw()

func _execute_context_action(col: int, row: int, item: Dictionary):
	var pi = row * COLS + col
	var t = item["type"]
	if t == "plant":
		_send_action("plant", {"plot_index": pi, "crop_id": item["crop_id"]})
	elif t == "harvest":
		_send_action("harvest", {"plot_index": pi})
	elif t == "water":
		_send_action("water", {"plot_index": pi})
	elif t == "fertilize":
		if selected_fertilizer >= 0:
			_send_action("fertilize", {"plot_index": pi, "fert_id": selected_fertilizer})
		else:
			toast_text = "请先在商店购买并选择肥料"
			toast_timer = 1.5
	elif t == "weed":
		_send_action("remove_weed", {"plot_index": pi})
	elif t == "pest":
		_send_action("remove_bug", {"plot_index": pi})
	elif t == "shovel":
		_send_action("shovel", {"plot_index": pi})
		
	ctx_menu_open = false
	queue_redraw()

func _open_top_toolbar_overlay(index: int):
	mouse_held = false
	match index:
		0:
			var shop := get_node_or_null("UILayer/ShopOverlay")
			if shop:
				_sync_shop_data(shop)
				shop.visible = true
				shop_open = true
		1:
			var inv := get_node_or_null("UILayer/InventoryOverlay")
			if inv:
				inv.inventory = inventory
				inv.visible = true
				inventory_open = true
		2:
			var setn := get_node_or_null("UILayer/SettingsOverlay")
			if setn:
				setn.auth_token = auth_token
				setn.user_info = user_info
				setn.visible = true
				settings_open = true
	queue_redraw()

# 触屏点击 → 模拟地块/UI 交互
func _handle_click(screen_pos: Vector2):
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var viewport_pos := _window_to_viewport_pos(screen_pos)
	var mx: float = viewport_pos.x
	var my: float = viewport_pos.y
	# overlay 打开时，不处理触屏点击（overlay 有自己的 _input 处理）
	if shop_open or inventory_open or settings_open:
		return
	# 确认框（复用鼠标逻辑）
	if reclaim_confirm_open or shovel_all_confirm_open or warehouse_open or reset_confirm_open:
		# 模拟左键点击，让已有逻辑处理
		var fake := InputEventMouseButton.new()
		fake.button_index = MOUSE_BUTTON_LEFT
		fake.pressed = true
		fake.position = screen_pos
		fake.global_position = screen_pos
		_input(fake)
		return
	var wp := _viewport_to_world(viewport_pos)
	# 地块点击（世界坐标）— 找最近的匹配地块
	var best_col := -1
	var best_row := -1
	var best_dist := INF
	for row in range(ROWS):
		for col in range(COLS):
			if farm.is_empty() or row >= farm.size() or col >= farm[row].size():
				continue
			var sp := _get_plot_position(col, row)
			if in_diamond(wp.x, wp.y, sp.x, sp.y):
				var d: float = (Vector2(wp.x, wp.y) - sp).length_squared()
				if d < best_dist:
					best_dist = d
					best_col = col
					best_row = row
	if best_col >= 0:
		_do_tile_action(best_col, best_row)
		queue_redraw()
		return
# ---- Server action API ----
func _send_action(action: String, params: Dictionary = {}):
	if auth_token.is_empty():
		toast_text = "未登录，无法执行操作"
		toast_timer = 1.5
		return
	if not is_instance_valid(farm_api):
		return
	farm_api.request_action(action, params)

func _on_action_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS:
		var error_names := {
			HTTPRequest.RESULT_CANT_CONNECT: "无法连接",
			HTTPRequest.RESULT_CANT_RESOLVE: "DNS失败",
			HTTPRequest.RESULT_CONNECTION_ERROR: "连接错误",
			HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: "证书错误",
			HTTPRequest.RESULT_NO_RESPONSE: "无响应",
			HTTPRequest.RESULT_TIMEOUT: "超时",
		}
		toast_text = "网络错误: " + error_names.get(result, str(result))
		print("[HTTP ERROR] result=", result, " url=", ApiConfig.API_BASE)
		toast_timer = 2.0
		return
	if response_code != 200:
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary:
			toast_text = str(parsed.get("message", "操作失败"))
		else:
			toast_text = "操作失败 (" + str(response_code) + ")"
		toast_timer = 1.5
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var resp: Dictionary = parsed
	if int(resp.get("code", -1)) != 0:
		toast_text = str(resp.get("message", "操作失败"))
		toast_timer = 1.5
		return
	var data: Dictionary = resp.get("data", {})
	var msg: String = str(data.get("message", ""))
	if not msg.is_empty():
		toast_text = msg
		toast_timer = 2.0
	_apply_state(data)

func _apply_state(data: Dictionary):
	# Update user fields
	gold = int(data.get("gold", gold))
	level = int(data.get("level", level))
	exp_val = int(data.get("exp_val", exp_val))
	exp_to_level = int(data.get("exp_to_level", exp_to_level))
	_game_time = float(data.get("game_time", _game_time))
	# Update inventory
	if data.has("inventory") and (data["inventory"] is Dictionary):
		inventory = data["inventory"]
		_normalize_inventory_keys()
	# Update fertilizer inventory
	if data.has("fertilizer_inventory") and (data["fertilizer_inventory"] is Dictionary):
		fertilizer_inventory = {}
		for k in data["fertilizer_inventory"].keys():
			fertilizer_inventory[int(k)] = int(data["fertilizer_inventory"][k])
	# Update plots
	if data.has("plots") and (data["plots"] is Array):
		for p in data["plots"]:
			if not (p is Dictionary):
				continue
			var pi: int = int(p.get("plot_index", -1))
			if pi < 0 or pi >= ROWS * COLS:
				continue
			var r: int = pi / COLS
			var c: int = pi % COLS
			var cell: Dictionary = farm[r][c]
			cell["unlocked"] = bool(p.get("unlocked", false))
			cell["land_level"] = int(p.get("land_level", 0))
			cell["land_work"] = int(p.get("land_work", 0))
			var cid_raw = p.get("crop_id", null)
			cell["crop_id"] = int(cid_raw) if cid_raw != null else -1
			var progress := clampf(float(p.get("progress", 0.0)), 0.0, 1.0)
			cell["progress"] = progress
			cell["visual_progress"] = progress
			cell["wet_timer"] = maxf(float(p.get("wet_timer", 0.0)), 0.0)
			cell["water_state"] = int(p.get("water_state", 0))
			cell["dry_timer"] = maxf(float(p.get("dry_timer", 0.0)), 0.0)
			cell["water_protect_until"] = float(p.get("water_protect_until", 0.0))
			cell["bug_count"] = clampi(int(p.get("bug_count", 0)), 0, 3)
			cell["bug_since"] = float(p.get("bug_since", 0.0))
			cell["bug_protect_until"] = float(p.get("bug_protect_until", 0.0))
			cell["weed_count"] = clampi(int(p.get("weed_count", 0)), 0, 3)
			cell["weed_since"] = float(p.get("weed_since", 0.0))
			cell["weed_protect_until"] = float(p.get("weed_protect_until", 0.0))
			cell["fert_used"] = clampi(int(p.get("fert_used", 0)), 0, 3)
			cell["fert_stage_used"] = _parse_dictish_json(p.get("fert_stage_used", {}))
			cell["fert_ids_used"] = _parse_arrayish_json(p.get("fert_ids_used", []))
			cell["yield_bonus_rate"] = maxf(float(p.get("yield_bonus_rate", 0.0)), 0.0)
			cell["yield_loss_rate"] = clampf(float(p.get("yield_loss_rate", 0.0)), 0.0, 0.30)
	_sync_all_overlays()
	queue_redraw()

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

func _try_reclaim_plot(col: int, row: int):
	var pi: int = _get_plot_index(col, row)
	if not auth_token.is_empty():
		# 服务端权威：开垦校验与扣费全部由后端处理
		_send_action("reclaim", {"plot_index": pi})
		return
	# 离线模式：本地校验扣费
	var next_locked := _get_next_locked_plot()
	if next_locked.x != col or next_locked.y != row:
		toast_text = "请按顺序先开垦下一块土地"
		toast_timer = 1.8
		return
	var required_level := _get_reclaim_level(col, row)
	var cost := _get_reclaim_cost(col, row)
	if level < required_level:
		toast_text = "等级不足! 这块地需要等级 " + str(required_level)
		toast_timer = 1.8
		return
	if gold < cost:
		toast_text = "金币不足! 开垦需要 " + str(cost) + " 金币"
		toast_timer = 1.8
		return
	gold -= cost
	farm[row][col]["unlocked"] = true
	farm[row][col]["land_level"] = 1
	farm[row][col]["land_work"] = 0
	farm[row][col]["crop_id"] = -1
	farm[row][col]["progress"] = 0.0
	farm[row][col]["wet_timer"] = 0.0
	toast_text = "开垦成功! 解锁第 " + str(pi + 1) + " 块地"
	toast_timer = 2.0
	_save_game(false)

func _open_reclaim_confirm(col: int, row: int):
	reclaim_confirm_col = col
	reclaim_confirm_row = row
	reclaim_confirm_open = true
	mouse_held = false
	last_action_col = -1
	last_action_row = -1
	queue_redraw()

func _close_reclaim_confirm():
	reclaim_confirm_open = false
	reclaim_confirm_col = -1
	reclaim_confirm_row = -1
	queue_redraw()

func _logout():
	_save_game(false)
	var auth_file := "user://auth.json"
	if FileAccess.file_exists(auth_file):
		DirAccess.remove_absolute(auth_file)
	auth_token = ""
	user_info = {}
	get_tree().change_scene_to_file("res://Login.tscn")

func _reset_save_data():
	_initialize_default_state()
	_apply_tool_cursor()
	_save_game(false)
	toast_text = "已重置农场存档"
	toast_timer = 2.0
	queue_redraw()

func _point_in_rect(point: Vector2, rect: Rect2) -> bool:
	return point.x >= rect.position.x and point.x <= rect.position.x + rect.size.x and point.y >= rect.position.y and point.y <= rect.position.y + rect.size.y


func _add_land_work(row: int, col: int, amount: int):
	var cell: Dictionary = farm[row][col]
	var land_level := int(cell.get("land_level", 1))
	if land_level >= LAND_LEVEL_MAX:
		return
	var work := int(cell.get("land_work", 0)) + amount
	if work >= LAND_UPGRADE_WORK_REQUIRED:
		cell["land_level"] = clampi(land_level + 1, 1, LAND_LEVEL_MAX)
		cell["land_work"] = 0
		toast_text = "土地升级! " + _get_land_level_name(land_level) + " -> " + _get_land_level_name(cell["land_level"])
		toast_timer = 2.0
	else:
		cell["land_work"] = work

func _add_to_inventory(cid: int, amount: int):
	var key_str = str(cid)
	if not inventory.has(cid):
		inventory[cid] = 0
	inventory[cid] += amount
	toast_text = "获得 " + str(CROPS[cid][0]) + " x" + str(amount) + "，已放入背包"
	toast_timer = 1.5

func _sell_inventory_crop(cid: int, amount: int) -> int:
	var have := int(inventory.get(cid, 0))
	var sell_amount := mini(maxi(amount, 0), have)
	if sell_amount <= 0:
		toast_text = "背包里没有 " + str(CROPS[cid][0])
		toast_timer = 1.5
		return 0
	gold += int(CROPS[cid][6]) * sell_amount
	inventory[cid] = have - sell_amount
	toast_text = "售出 " + str(CROPS[cid][0]) + " x" + str(sell_amount) + "，获得 " + str(int(CROPS[cid][6]) * sell_amount) + " 金币"
	toast_timer = 1.5
	return sell_amount

func _sell_all_inventory():
	var total_count := 0
	var total_gold := 0
	for cid in inventory.keys():
		var count := int(inventory[cid])
		if count <= 0:
			continue
		total_count += count
		total_gold += int(CROPS[int(cid)][6]) * count
		inventory[cid] = 0
	if total_count <= 0:
		toast_text = "背包是空的"
	else:
		gold += total_gold
		toast_text = "全部卖出 " + str(total_count) + " 个作物，获得 " + str(total_gold) + " 金币"
	toast_timer = 1.8

func _handle_inventory_click(mx: float, my: float):
	var keys = inventory.keys()
	var item_count = 0
	for cid in keys:
			if inventory.has(cid) and inventory[cid] > 0:
				var col = item_count % 5
				var row = item_count / 5
				var slot_x = 200 + col * 150
				var slot_y = 120 + row * 190
				
				# Sell button rect
				if mx >= slot_x + 18 and mx <= slot_x + 67 and my >= slot_y + 123 and my <= slot_y + 148:
					_sell_inventory_crop(int(cid), 1)
					queue_redraw()
					return
				if mx >= slot_x + 73 and mx <= slot_x + 122 and my >= slot_y + 123 and my <= slot_y + 148:
					_sell_inventory_crop(int(cid), int(inventory.get(cid, 0)))
					queue_redraw()
					return
			item_count += 1

func _get_unlocked_plot_count() -> int:
	var count := 0
	for r in range(ROWS):
		for c in range(COLS):
			if _is_cell_unlocked(farm[r][c]):
				count += 1
	return count

func _get_next_locked_plot() -> Vector2i:
	for r in range(ROWS):
		for c in range(COLS):
			if not _is_cell_unlocked(farm[r][c]):
				return Vector2i(c, r)
	return Vector2i(-1, -1)

func _save_game(show_toast := true):
	var payload := _build_save_payload()
	var data := {
		"gold": payload["gold"],
		"level": payload["level"],
		"exp_val": payload["exp_val"],
		"exp_to_level": payload["exp_to_level"],
		"plots": payload["plots"],
		"inventory": payload["inventory"],
		"selected_seed": payload["selected_seed"],
		"tool_mode": payload["tool_mode"],
		"fertilizer_inventory": payload["fertilizer_inventory"],
		"selected_fertilizer": payload["selected_fertilizer"],
		"game_time": payload["game_time"],
		"saved_at": int(Time.get_unix_time_from_system()),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		if show_toast:
			toast_text = "保存失败"
			toast_timer = 1.5
		return
	file.store_string(JSON.stringify(data))
	if show_toast:
		toast_text = "农场已保存"
		toast_timer = 1.2
	# 云端同步（异步，不阻塞）
	if not auth_token.is_empty() and not _save_pending:
		_cloud_save()

func _cloud_save():
	if not is_instance_valid(farm_api):
		return
	_save_pending = true
	var payload := _build_save_payload()
	farm_api.request_save(payload)

func _on_save_response(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
	_save_pending = false

func _build_save_payload() -> Dictionary:
	var plots: Array = []
	for r in range(ROWS):
		for c in range(COLS):
			var cell: Dictionary = farm[r][c]
			var plot := {
				"plot_index": r * COLS + c,
				"unlocked": cell.get("unlocked", false),
				"land_level": cell.get("land_level", 0),
				"land_work": cell.get("land_work", 0),
				"crop_id": cell["crop_id"] if cell["crop_id"] != -1 else null,
				"progress": cell.get("progress", 0.0),
				"wet_timer": cell.get("wet_timer", 0.0),
				"water_state": cell.get("water_state", 0),
				"dry_timer": cell.get("dry_timer", 0.0),
				"water_protect_until": cell.get("water_protect_until", 0.0),
				"bug_count": cell.get("bug_count", 0),
				"bug_since": cell.get("bug_since", 0.0),
				"bug_protect_until": cell.get("bug_protect_until", 0.0),
				"weed_count": cell.get("weed_count", 0),
				"weed_since": cell.get("weed_since", 0.0),
				"weed_protect_until": cell.get("weed_protect_until", 0.0),
				"fert_used": cell.get("fert_used", 0),
				"fert_stage_used": cell.get("fert_stage_used", {}),
				"fert_ids_used": cell.get("fert_ids_used", []),
				"yield_bonus_rate": cell.get("yield_bonus_rate", 0.0),
				"yield_loss_rate": cell.get("yield_loss_rate", 0.0),
			}
			plots.append(plot)
	return {
		"gold": gold,
		"level": level,
		"exp_val": exp_val,
		"exp_to_level": exp_to_level,
		"game_time": _game_time,
		"selected_seed": selected_seed,
		"tool_mode": tool_mode,
		"saved_at": int(Time.get_unix_time_from_system()),
		"plots": plots,
		"inventory": _stringify_int_keys(inventory),
		"fertilizer_inventory": _stringify_int_keys(fertilizer_inventory),
		"selected_fertilizer": selected_fertilizer,
	}

func _stringify_int_keys(dict: Dictionary) -> Dictionary:
	var out := {}
	for k in dict.keys():
		out[str(k)] = dict[k]
	return out

func _legacy_farm_to_plots(saved_farm: Array) -> Array:
	var plots: Array = []
	for r in range(mini(ROWS, saved_farm.size())):
		if not (saved_farm[r] is Array):
			continue
		var saved_row: Array = saved_farm[r]
		for c in range(mini(COLS, saved_row.size())):
			if not (saved_row[c] is Dictionary):
				continue
			var saved_cell: Dictionary = saved_row[c]
			var cid := int(saved_cell.get("crop_id", -1))
			var was_unlocked := bool(saved_cell.get("unlocked", cid != -1 or _get_plot_index(c, r) < INITIAL_UNLOCKED_PLOTS))
			var land_level := int(saved_cell.get("land_level", 1 if was_unlocked else LAND_LEVEL_LOCKED))
			land_level = clampi(land_level, LAND_LEVEL_LOCKED, LAND_LEVEL_MAX)
			plots.append({
				"plot_index": _get_plot_index(c, r),
				"unlocked": land_level > LAND_LEVEL_LOCKED,
				"land_level": land_level,
				"land_work": clampi(int(saved_cell.get("land_work", 0)), 0, LAND_UPGRADE_WORK_REQUIRED - 1),
				"crop_id": cid if cid >= 0 else null,
				"progress": clampf(float(saved_cell.get("progress", 0.0)), 0.0, 1.0),
				"wet_timer": maxf(float(saved_cell.get("wet_timer", 0.0)), 0.0),
				"water_state": int(saved_cell.get("water_state", 0)),
				"dry_timer": maxf(float(saved_cell.get("dry_timer", 0.0)), 0.0),
				"water_protect_until": float(saved_cell.get("water_protect_until", 0.0)),
				"bug_count": clampi(int(saved_cell.get("bug_count", 0)), 0, 3),
				"bug_since": float(saved_cell.get("bug_since", 0.0)),
				"bug_protect_until": float(saved_cell.get("bug_protect_until", 0.0)),
				"weed_count": clampi(int(saved_cell.get("weed_count", 0)), 0, 3),
				"weed_since": float(saved_cell.get("weed_since", 0.0)),
				"weed_protect_until": float(saved_cell.get("weed_protect_until", 0.0)),
				"fert_used": clampi(int(saved_cell.get("fert_used", 0)), 0, 3),
				"fert_stage_used": saved_cell.get("fert_stage_used", {}),
				"fert_ids_used": saved_cell.get("fert_ids_used", []),
				"yield_bonus_rate": maxf(float(saved_cell.get("yield_bonus_rate", 0.0)), 0.0),
				"yield_loss_rate": clampf(float(saved_cell.get("yield_loss_rate", 0.0)), 0.0, 0.30),
			})
	return plots

func _load_game():
	if not _config_loaded:
		return
	# 服务端权威：登录状态从云端加载，否则本地
	if not auth_token.is_empty():
		_cloud_load()
		return
	# 纯离线模式：从本地加载
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	if data.has("farm") and not data.has("plots"):
		data["plots"] = _legacy_farm_to_plots(data["farm"])
	if data.has("farm") and (data["farm"] is Array):
		data.erase("farm")
	_apply_state(data)

func _cloud_load():
	if not is_instance_valid(farm_api):
		return
	farm_api.request_load()

func _on_load_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return # 云端失败，保留本地数据
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var resp: Dictionary = parsed
	if int(resp.get("code", -1)) != 0:
		return
	var d: Dictionary = resp.get("data", {})
	if d.is_empty():
		return
	_apply_cloud_data(d)
	toast_text = "云端存档已同步"
	toast_timer = 2.0

func _apply_cloud_data(data: Dictionary):
	_apply_state(data)

func _normalize_inventory_keys():
	var fixed := {}
	for key in inventory.keys():
		var cid := int(key)
		fixed[cid] = int(inventory[key])
	inventory = fixed

# ===================== DRAW =====================
func _draw():
	if farm.is_empty():
		return
	FarmRenderer.draw_world(self)

# ---- 以下 UI 固定在屏幕上，不受 Camera 影响 ----
# 被 UIOverlay._draw() 调用，caller 是 UIOverlay 节点（CanvasLayer 子节点）
func _draw_modal_ui(caller: CanvasItem):
	_ui_draw_target = caller
	var vp: Vector2 = get_viewport().get_visible_rect().size

	_draw_context_menu_overlay(vp)

	_ui_draw_target = null

func _draw_context_menu_overlay(vp: Vector2):
	if not ctx_menu_open: return

	var wp := _get_plot_position(ctx_col, ctx_row)
	var vp_pos = (wp - cam.position) * cam.zoom + vp * 0.5
	var menu_w = ctx_menu_items.size() * 50 + 10
	var menu_rect = _ctx_menu_rect(vp_pos)

	# 画胶囊形状的半透明黑底
	var r = 30.0
	_d_circle(Vector2(menu_rect.position.x + r, menu_rect.position.y + r), r, Color(0, 0, 0, 0.65))
	_d_circle(Vector2(menu_rect.position.x + menu_w - r, menu_rect.position.y + r), r, Color(0, 0, 0, 0.65))
	_d_rect(Rect2(menu_rect.position.x + r, menu_rect.position.y, menu_w - 2 * r, 60), Color(0, 0, 0, 0.65))

	# 画小箭头朝上指向地块（菜单在作物下方）
	var arrow_pts: PackedVector2Array = PackedVector2Array([
		Vector2(vp_pos.x - 8, menu_rect.position.y),
		Vector2(vp_pos.x, menu_rect.position.y - 8),
		Vector2(vp_pos.x + 8, menu_rect.position.y),
	])
	_d_colored_polygon(arrow_pts, Color(0, 0, 0, 0.65))
	
	for i in range(ctx_menu_items.size()):
		var item = ctx_menu_items[i]
		var ix = menu_rect.position.x + 5 + i * 50
		var iy = menu_rect.position.y + 5
		
		if item["icon"] != null:
			var isz = item["icon"].get_size()
			var iscale = minf(36.0 / maxf(isz.x, 1.0), 36.0 / maxf(isz.y, 1.0))
			var idraw_sz = isz * iscale
			var idraw_pos = Vector2(ix + 25 - idraw_sz.x * 0.5, iy + 25 - idraw_sz.y * 0.5)
			_d_texture_rect(item["icon"], Rect2(idraw_pos, idraw_sz), false)

# ---- SIGN DRAWING ----
func _draw_sign(cx: float, cy: float, sign_color: Color, label: String, can_open: bool):
	var board_w: float = TW * 0.70
	var board_h: float = board_w
	var board_top: float = cy - board_w
	var board_cx: float = cx
	# 木牌主体（图已含杆子，无需再画）
	var sign_size := _sign_texture.get_size()
	var scale: float = minf(board_w / sign_size.x, board_h / sign_size.y)
	var draw_size := sign_size * scale
	var draw_pos := Vector2(board_cx - draw_size.x * 0.5, board_top + (board_h - draw_size.y) * 0.5)
	_d_texture_rect(_sign_texture, Rect2(draw_pos, draw_size), false)
	# 文字在牌子内部
	var f: Font = _cn_font if _cn_font != null else ThemeDB.fallback_font
	var text_color: Color = Color(0.12, 0.32, 0.12) if can_open else Color(0.78, 0.12, 0.1)
	var text_size: int = 14
	var lw: float = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	_draw_text(board_cx - lw * 0.5, board_top + board_h * 0.24, label, text_size, text_color)

# ---- PLANT DRAWING ----
func _draw_plant_full(cx: float, cy: float, leaf: Color, fruit: Color):
	var by: float = cy
	var sh: float = 28.0
	# Stem
	_d_line(Vector2(cx, by), Vector2(cx, by - sh), Color(0.2, 0.5, 0.12), 3.0)
	# Leaves
	_d_circle(Vector2(cx - 10, by - sh * 0.6), 8, leaf)
	_d_circle(Vector2(cx + 10, by - sh * 0.55), 7, leaf)
	# Fruit
	_d_circle(Vector2(cx, by - sh - 4), 10, fruit)
	_d_circle(Vector2(cx - 3, by - sh - 7), 3, Color(1, 1, 1, 0.35))

func _draw_plant_growing(cx: float, cy: float, leaf: Color, prog: float):
	var by: float = cy
	var sh: float = 10.0 + prog * 18.0
	_d_line(Vector2(cx, by), Vector2(cx, by - sh), Color(0.2, 0.5, 0.12), 2.5)
	_d_circle(Vector2(cx, by - sh), 5 + int(prog * 4), leaf)
	_d_circle(Vector2(cx - 6, by - sh * 0.5), 4, leaf)
	_d_circle(Vector2(cx + 6, by - sh * 0.45), 3.5, leaf)

func _draw_plant_seed(cx: float, cy: float, prog: float):
	var by: float = cy
	# Small sprout
	var h: float = 3.0 + prog * 10.0
	_d_line(Vector2(cx, by), Vector2(cx, by - h), Color(0.25, 0.6, 0.15), 2.0)
	if prog > 0.05:
		_d_circle(Vector2(cx - 2, by - h), 3, Color(0.3, 0.75, 0.2))
		_d_circle(Vector2(cx + 2, by - h + 1), 2.5, Color(0.3, 0.75, 0.2))
	# Seed
	_d_circle(Vector2(cx, by + 2), 3.5, Color(0.6, 0.45, 0.25))

func _draw_land_tile(corners: PackedVector2Array, cell: Dictionary):
	var texture := _get_land_texture(cell)
	var bg_color: Color
	if texture != null:
		var key := _get_land_texture_key(cell)
		bg_color = land_texture_avg_colors.get(key, Color(0.5, 0.4, 0.25))
	else:
		bg_color = Color(0.52, 0.36, 0.20)
	# 半透明底色，让 SandyBase 从缝隙和边缘透出来
	bg_color.a = 0.78
	_d_colored_polygon(corners, bg_color)
	if texture != null:
		var size := texture.get_size()
		if size.x <= 0.0 or size.y <= 0.0:
			return
		var center := Vector2.ZERO
		for point in corners:
			center += point
		center /= maxf(float(corners.size()), 1.0)
		var source := _get_land_texture_source_rect(cell, size)
		var vw: float = TW - TILE_GAP
		var vh: float = TH - TILE_GAP
		var dest := Rect2(center.x - vw * 0.5, center.y - vh * 0.5, vw, vh)
		draw_texture_rect_region(texture, dest, source)

func _get_texture_avg_color(texture: Texture2D) -> Color:
	var image := texture.get_image()
	if image == null or image.is_empty():
		return Color(0.5, 0.4, 0.25)
	var sum_r := 0.0; var sum_g := 0.0; var sum_b := 0.0; var count := 0
	var step := maxi(1, mini(image.get_width(), image.get_height()) / 16)
	for y in range(0, image.get_height(), step):
		for x in range(0, image.get_width(), step):
			var c := image.get_pixel(x, y)
			if c.a > 0.5:
				sum_r += c.r; sum_g += c.g; sum_b += c.b
				count += 1
	if count == 0:
		return Color(0.5, 0.4, 0.25)
	return Color(sum_r / count, sum_g / count, sum_b / count)

func _draw_land_tooltip(col: int, row: int):
	var cell: Dictionary = farm[row][col]
	var sp := _get_plot_position(col, row)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var ctrans := get_viewport().get_canvas_transform()
	var w_min := ctrans.affine_inverse() * Vector2.ZERO
	var w_max := ctrans.affine_inverse() * vp
	var tw := 176.0
	var th := 78.0
	var tx := clampf(sp.x - tw * 0.5, w_min.x + 5.0, w_max.x - tw - 5.0)
	var ty := clampf(sp.y - TH * 0.5 - th - 18.0, w_min.y + 5.0, w_max.y - th - 5.0)
	var land_level := int(cell.get("land_level", 1))
	var work := int(cell.get("land_work", 0))
	_d_rect(Rect2(tx, ty, tw, th), Color(0.08, 0.05, 0.02, 0.92))
	_d_rect(Rect2(tx, ty, tw, th), Color(0.55, 0.42, 0.2), false, 2)
	_d_rect(Rect2(tx, ty, tw, 22), Color(0.38, 0.28, 0.12))
	_draw_text(tx + 8, ty + 3, _get_land_level_name(land_level), 13, Color(1.0, 0.92, 0.72))
	if land_level >= LAND_LEVEL_MAX:
		_draw_text(tx + 10, ty + 32, "已是最高等级", 12, Color(0.95, 0.82, 0.42))
	else:
		_draw_text(tx + 10, ty + 32, "土地经验: " + str(work) + "/" + str(LAND_UPGRADE_WORK_REQUIRED), 12, Color(0.95, 0.82, 0.42))
		_draw_text(tx + 10, ty + 50, "收获后增加 1 点", 11, Color(0.7, 0.85, 1.0))
	var arrow_x: float = clampf(sp.x, tx + 10.0, tx + tw - 10.0)
	var arrow_pts: PackedVector2Array = PackedVector2Array([
		Vector2(arrow_x - 6.0, ty + th),
		Vector2(arrow_x, ty + th + 8.0),
		Vector2(arrow_x + 6.0, ty + th),
	])
	_d_colored_polygon(arrow_pts, Color(0.08, 0.05, 0.02, 0.92))

func _get_land_texture_source_rect(cell: Dictionary, size: Vector2) -> Rect2:
	var key := _get_land_texture_key(cell)
	if land_texture_source_rects.has(key):
		return land_texture_source_rects[key]
	return Rect2(Vector2.ZERO, size)

func _get_texture_alpha_bounds(texture: Texture2D) -> Rect2:
	var image := texture.get_image()
	if image == null or image.is_empty():
		return Rect2(Vector2.ZERO, texture.get_size())
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.01:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2(Vector2.ZERO, image.get_size())
	return Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _inset_polygon(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var center := Vector2.ZERO
	for point in points:
		center += point
	center /= maxf(float(points.size()), 1.0)
	var result := PackedVector2Array()
	for point in points:
		result.append(center + (point - center) * (1.0 - amount))
	return result

func _get_land_texture(cell: Dictionary) -> Texture2D:
	return land_textures.get(_get_land_texture_key(cell), null) as Texture2D

func _get_land_texture_key(cell: Dictionary) -> String:
	if not _is_cell_unlocked(cell):
		return "locked"
	var level := _get_land_level_key(int(cell.get("land_level", 1)))
	var suffix := "wet" if float(cell.get("wet_timer", 0.0)) > 0.0 else "dry"
	return level + "_" + suffix

func _get_land_level_key(land_level: int) -> String:
	if land_level <= 2:
		return "yellow"
	if land_level == 3:
		return "red"
	return "black"

func _get_crop_stage_texture(cid: int, prog: float) -> Texture2D:
	var stage := _get_growth_stage(prog)
	if stage < 0:
		return null
	return CropAtlas.get_stage_texture(str(CROPS[cid][4]), stage + 1)

func _get_crop_seed_texture(cid: int) -> Texture2D:
	return CropAtlas.get_stage_texture(str(CROPS[cid][4]), 0)

func _get_crop_mature_texture(cid: int) -> Texture2D:
	return CropAtlas.get_stage_texture(str(CROPS[cid][4]), 3)

func _get_growth_stage(prog: float) -> int:
	if RENDER_STAGE_THRESHOLDS.size() < 4:
		return 2 if prog >= 0.9 else -1
	if prog < float(RENDER_STAGE_THRESHOLDS[0]):
		return -1
	if prog < float(RENDER_STAGE_THRESHOLDS[1]):
		return 0
	if prog < float(RENDER_STAGE_THRESHOLDS[2]):
		return 1
	if prog < float(RENDER_STAGE_THRESHOLDS[3]):
		return 2
	return 2

func _draw_crop_atlas_texture(cx: float, tile_center_y: float, texture: Texture2D, prog: float, cid: int, stage: int):
	var size := texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var scale_factor := _get_crop_scale(cid, size, stage)
	var draw_size := size * scale_factor
	var anchor := _get_crop_ground_anchor(texture)
	var draw_pos := Vector2(cx, tile_center_y) - anchor * scale_factor
	_d_texture_rect(texture, Rect2(draw_pos, draw_size), false)

func _get_crop_scale(cid: int, size: Vector2, stage: int) -> float:
	var target_size := 110.0
	var crop_key := str(CROPS[cid][4])
	match crop_key:
		"lettuce":
			target_size = 92.0
		"pepper":
			target_size = 100.0
		"eggplant":
			target_size = 102.0
		"tomato":
			target_size = 104.0
		"strawberry":
			target_size = 96.0
		"corn":
			target_size = 118.0
		"sunflower":
			target_size = 126.0
		"pumpkin":
			target_size = 112.0
		"watermelon":
			target_size = 114.0
	var stage_multiplier := 1.0
	match stage:
		0:
			stage_multiplier = 0.62
		1:
			stage_multiplier = 0.82
		2:
			stage_multiplier = 1.0
	var base_scale := minf(1.0, target_size / maxf(size.x, size.y)) * stage_multiplier
	var width_limit_scale := (TW * 0.8) / maxf(size.x, 1.0)
	return minf(base_scale, width_limit_scale)

func _get_crop_ground_anchor(texture: Texture2D) -> Vector2:
	var bounds := _get_texture_alpha_bounds(texture)
	return Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.position.y + bounds.size.y)

func _draw_crop_preview(x: float, y: float, texture: Texture2D, label: String):
	var bg_rect := Rect2(x, y, 120, 92)
	_d_rect(bg_rect, Color(0.14, 0.10, 0.06, 0.75))
	_d_rect(bg_rect, Color(0.40, 0.30, 0.16), false, 2)
	if texture != null:
		var size := texture.get_size()
		if size.x > 0.0 and size.y > 0.0:
			var scale_factor := minf(0.42, 62.0 / maxf(size.x, size.y))
			var draw_size := size * scale_factor
			var draw_pos := Vector2(x + 60 - draw_size.x * 0.5, y + 60 - draw_size.y)
			_d_texture_rect(texture, Rect2(draw_pos, draw_size), false)
	else:
		_d_circle(Vector2(x + 60, y + 42), 16, Color(0.35, 0.42, 0.26))
	_draw_text(x + 34, y + 68, label, 12, Color(1, 0.95, 0.85))

func _draw_ui_seed_thumbnail(rect: Rect2, texture: Texture2D):
	_d_rect(rect, Color(1, 1, 1, 0.22))
	_d_rect(rect, Color(0.42, 0.30, 0.16, 0.55), false, 1.0)
	if texture == null:
		return
	var size := texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var scale_factor := minf(rect.size.x / size.x, rect.size.y / size.y)
	var draw_size := size * scale_factor
	var draw_pos := rect.position + (rect.size - draw_size) * 0.5
	_d_texture_rect(texture, Rect2(draw_pos, draw_size), false)

func _draw_inventory_crop_icon(rect: Rect2, texture: Texture2D):
	if texture == null:
		return
	var size := texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var scale_factor := minf(rect.size.x / size.x, rect.size.y / size.y)
	var draw_size := size * scale_factor
	var draw_pos := rect.position + Vector2((rect.size.x - draw_size.x) * 0.5, rect.size.y - draw_size.y)
	_d_texture_rect(texture, Rect2(draw_pos, draw_size), false)

func _draw_seed_preview_texture(cx: float, cy: float, texture: Texture2D):
	var size := texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var target := 26.0
	var scale_factor := minf(target / size.x, target / size.y)
	var draw_size := size * scale_factor
	var draw_pos := Vector2(cx - draw_size.x * 0.5, cy - draw_size.y * 0.5)
	_d_texture_rect(texture, Rect2(draw_pos, draw_size), false)

# ---- Text helper ----
func _draw_text(x: float, y: float, text: String, size: int, color: Color):
	var font: Font = _cn_font if _cn_font != null else ThemeDB.fallback_font
	var t: CanvasItem = _ui_draw_target if _ui_draw_target != null else self
	t.draw_string(font, Vector2(x, y + float(size) * 0.8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

# UI draw helpers — route to _ui_draw_target when set
func _d_rect(rect: Rect2, color: Color, filled: bool = true, width: float = -1.0, antialiased: bool = false):
	var t: CanvasItem = _ui_draw_target if _ui_draw_target != null else self
	if filled:
		t.draw_rect(rect, color)
	else:
		t.draw_rect(rect, color, false, width, antialiased)

func _d_circle(position: Vector2, radius: float, color: Color):
	var t: CanvasItem = _ui_draw_target if _ui_draw_target != null else self
	t.draw_circle(position, radius, color)

func _d_line(from: Vector2, to: Vector2, color: Color, width: float = -1.0, antialiased: bool = false):
	var t: CanvasItem = _ui_draw_target if _ui_draw_target != null else self
	t.draw_line(from, to, color, width, antialiased)

func _d_colored_polygon(points: PackedVector2Array, color: Color):
	var t: CanvasItem = _ui_draw_target if _ui_draw_target != null else self
	t.draw_colored_polygon(points, color)

func _d_texture_rect(texture: Texture2D, rect: Rect2, tile: bool = false, modulate: Color = Color(1, 1, 1, 1), transpose: bool = false):
	var t: CanvasItem = _ui_draw_target if _ui_draw_target != null else self
	t.draw_texture_rect(texture, rect, tile, modulate, transpose)

func _d_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, point_count: int, color: Color, width: float = -1.0, antialiased: bool = false):
	var t: CanvasItem = _ui_draw_target if _ui_draw_target != null else self
	t.draw_arc(center, radius, start_angle, end_angle, point_count, color, width, antialiased)
