extends Node2D

const CropAtlas = preload("res://scripts/crop_atlas.gd")
const CropCatalogScript = preload("res://scripts/farm/crop_catalog.gd")
const FertilizerCatalogScript = preload("res://scripts/farm/fertilizer_catalog.gd")
const FarmRules = preload("res://scripts/farm/farm_rules.gd")
const FarmStateScript = preload("res://scripts/farm/farm_state.gd")
const FarmApiClientScript = preload("res://scenes/farm_api.gd")
const CameraController = preload("res://scenes/camera_controller.gd")
const FarmRenderer = preload("res://scenes/farm_renderer.gd")
const DEFAULT_CATALOG_PATH := "res://resources/farm/default_catalog.tres"
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
const WORLD_ROOT_PATH := "WorldRoot"
const SYSTEMS_PATH := "Systems"
const PLOT_ANCHORS_PATH := "WorldRoot/PlotAnchors"
const INITIAL_UNLOCKED_PLOTS := 1
const BASE_RECLAIM_COST := 60
const RECLAIM_COST_STEP := 35
const LAND_LEVEL_LOCKED := 0
const LAND_LEVEL_MAX := 4
const LAND_UPGRADE_WORK_REQUIRED := 30

var CROPS: Array = []
var CROP_COLORS: Array = []
var RENDER_STAGE_THRESHOLDS: Array = [0.18, 0.45, 0.72, 0.90]
var crop_catalog: CropCatalog = CropCatalogScript.new()
var fertilizer_catalog: FertilizerCatalog = FertilizerCatalogScript.new()
var state: FarmState = FarmStateScript.new(COLS, ROWS)

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
var farm_api: FarmApiClient
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

	farm_api = FarmApiClientScript.new()
	farm_api.name = "FarmApiClient"
	farm_api.auth_token = auth_token
	farm_api.config_completed.connect(_on_config_response)
	farm_api.load_completed.connect(_on_load_response)
	farm_api.save_completed.connect(_on_save_response)
	farm_api.action_completed.connect(_on_action_response)
	farm_api.sell_completed.connect(_on_sell_response)
	_get_systems_node().add_child(farm_api)

	# Camera for pan/zoom
	cam = Camera2D.new()
	cam.name = "Camera2D"
	_get_systems_node().add_child(cam)
	cam.make_current()
	camera_controller = CameraController.new()
	camera_controller.name = "CameraController"
	camera_controller.setup(cam, _cam_min_zoom)
	camera_controller.set_background(_get_background())
	camera_controller.tap.connect(_handle_click)
	_get_systems_node().add_child(camera_controller)
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
		_ui_overlay.top_button_requested.connect(_open_top_toolbar_overlay)
		_ui_overlay.tool_mode_requested.connect(_on_ui_tool_mode_requested)
		_ui_overlay.reclaim_cancel_requested.connect(_close_reclaim_confirm)
		_ui_overlay.reclaim_confirm_requested.connect(_on_ui_reclaim_confirm_requested)
		_ui_overlay.reset_cancel_requested.connect(_on_ui_reset_cancel_requested)
		_ui_overlay.reset_confirm_requested.connect(_on_ui_reset_confirm_requested)
		_ui_overlay.shovel_all_cancel_requested.connect(_on_ui_shovel_all_cancel_requested)
		_ui_overlay.shovel_all_confirm_requested.connect(_on_ui_shovel_all_confirm_requested)
		_ui_overlay.overlay_draw_requested.connect(_draw_modal_ui)
		_sync_ui_overlay_view_model()
	_load_remote_config()

func _get_systems_node() -> Node:
	var systems := get_node_or_null(SYSTEMS_PATH)
	if systems != null:
		return systems
	return self

func _get_background() -> Sprite2D:
	return get_node_or_null(WORLD_ROOT_PATH + "/Background") as Sprite2D

func _setup_camera():
	cam.position = Vector2(500.0, 530.0)
	cam.position_smoothing_enabled = false
	_fit_camera_to_screen()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	get_viewport().size_changed.connect(_fit_camera_to_screen)

func _setup_default_config():
	var fallback := _load_catalog_fallback()
	if fallback != null:
		var crop_rows := fallback.to_crop_rows()
		var fertilizer_rows := fallback.to_fertilizer_rows()
		CROPS = crop_rows if not crop_rows.is_empty() else DEFAULT_CROPS.duplicate(true)
		FERTILIZERS = fertilizer_rows if not fertilizer_rows.is_empty() else DEFAULT_FERTILIZERS.duplicate(true)
	else:
		CROPS = DEFAULT_CROPS.duplicate(true)
		FERTILIZERS = DEFAULT_FERTILIZERS.duplicate(true)
	_sync_catalogs()
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

func _load_catalog_fallback() -> FarmCatalogFallback:
	if not ResourceLoader.exists(DEFAULT_CATALOG_PATH):
		return null
	var resource := load(DEFAULT_CATALOG_PATH)
	return resource as FarmCatalogFallback

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
			_sync_catalogs()
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
			_sync_catalogs()
	if data.has("render_stage_thresholds") and data["render_stage_thresholds"] is Array:
		var thresholds: Array = []
		for value in data["render_stage_thresholds"]:
			thresholds.append(float(value))
		if thresholds.size() >= 4:
			RENDER_STAGE_THRESHOLDS = thresholds
	_sync_all_overlays()

func _sync_catalogs():
	crop_catalog.set_crops(CROPS)
	fertilizer_catalog.set_fertilizers(FERTILIZERS)

# 等比缩放：viewport 宽高比 >= 场景宽高比 时以宽为准，否则以高为准
func _fit_camera_to_screen():
	var bg := _get_background()
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
	shop.crop_catalog = crop_catalog
	shop.fertilizer_catalog = fertilizer_catalog
	shop.seed_selected.connect(func(i: int):
		selected_seed = i
		state.selected_seed = i
		toast_text = "已选择种子: " + crop_catalog.get_name(i)
		toast_timer = 1.5
		shop.selected_seed = i
		shop.queue_redraw()
	)
	shop.crop_sell_requested.connect(func(cid: int, amount: int):
		_send_sell(cid, amount)
		_sync_shop_data(shop)
		shop.queue_redraw()
	)
	shop.fertilizer_buy_requested.connect(func(fi: int):
		_send_action("buy_fertilizer", {"fert_id": fi})
		_sync_shop_data(shop)
		shop.queue_redraw()
	)
	shop.fertilizer_selected.connect(func(fi: int):
		selected_fertilizer = fi
		state.selected_fertilizer = fi
		toast_text = "已选中: " + fertilizer_catalog.get_name(fi)
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
		inv.crop_catalog = crop_catalog
		inv.sell_requested.connect(func(cid: int, amount: int):
			_send_sell(cid, amount)
			inv.inventory = inventory
			inv.queue_redraw()
		)
		inv.sell_all_requested.connect(func():
			_send_action("sell_all")
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
	shop.crop_catalog = crop_catalog
	shop.fertilizer_catalog = fertilizer_catalog

func _sync_all_overlays():
	# Refresh any open overlay with latest state
	var shop := get_node_or_null("UILayer/ShopOverlay")
	if shop:
		shop.CROPS = CROPS
		shop.CROP_COLORS = CROP_COLORS
		shop.FERTILIZERS = FERTILIZERS
		shop.crop_catalog = crop_catalog
		shop.fertilizer_catalog = fertilizer_catalog
		if shop_open:
			_sync_shop_data(shop)
			shop.queue_redraw()
	var inv := get_node_or_null("UILayer/InventoryOverlay")
	if inv:
		inv.CROPS = CROPS
		inv.CROP_COLORS = CROP_COLORS
		inv.crop_catalog = crop_catalog
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
			var next_gold := int(d.get("gold", gold))
			var sold: int = int(d.get("sold_count", 0))
			var earned: int = int(d.get("gold_earned", 0))
			var crop_id := _pending_sell_crop_id
			_pending_sell_crop_id = -1
			if crop_id >= 0:
				state.apply_sell_result(crop_id, sold, next_gold)
				_copy_state_from_model()
				toast_text = "售出 " + crop_catalog.get_name(crop_id) + " x" + str(sold) + "，获得 " + str(earned) + " 金币"
				toast_timer = 1.5
			_cloud_load()

func _initialize_default_state():
	state.reset()
	_copy_state_from_model()
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
	shop_tab = 0

func _copy_state_from_model():
	gold = state.gold
	level = state.level
	exp_val = state.exp_val
	exp_to_level = state.exp_to_level
	farm = state.farm
	inventory = state.inventory
	fertilizer_inventory = state.fertilizer_inventory
	_game_time = state.game_time
	selected_seed = state.selected_seed
	tool_mode = state.tool_mode
	selected_fertilizer = state.selected_fertilizer

func _copy_client_state_to_model():
	state.selected_seed = selected_seed
	state.tool_mode = tool_mode
	state.selected_fertilizer = selected_fertilizer

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
	var base := get_node_or_null(PLOT_ANCHORS_PATH + "/SandyBase") as Polygon2D
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
			return (plot as Node2D).global_position
	return iso2screen(c, r)

func _create_empty_cell(col: int, row: int) -> Dictionary:
	return state.create_empty_cell(col, row)

func _get_plot_index(col: int, row: int) -> int:
	return state.get_plot_index(col, row)

func _get_reclaim_level(col: int, row: int) -> int:
	return state.get_reclaim_level(col, row)

func _get_reclaim_cost(col: int, row: int) -> int:
	return state.get_reclaim_cost(col, row)

func _is_cell_unlocked(cell: Dictionary) -> bool:
	return state.is_cell_unlocked(cell)

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
	_sync_ui_overlay_view_model()
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
			var grow_time := maxf(crop_catalog.get_grow_time(cid), 0.001)
			var visual_progress := maxf(float(cell.get("visual_progress", server_progress)), server_progress)
			cell["visual_progress"] = minf(visual_progress + delta / grow_time, 0.999)

func _notification(what: int):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game(false)

func _exit_tree():
	Input.set_custom_mouse_cursor(null)

func _set_tool_mode(mode: int):
	tool_mode = clampi(mode, 0, TOOL_ICON_TEXTURES.size() - 1)
	state.tool_mode = tool_mode
	_apply_tool_cursor()

func _on_ui_tool_mode_requested(index: int):
	_set_tool_mode(index)
	var mode_names := ["普通", "浇水", "施肥", "收获", "铲除", "全铲", "除虫", "除草", "全收", "仓库"]
	toast_text = "切换到: " + mode_names[tool_mode] + "模式"
	toast_timer = 1.0
	_sync_ui_overlay_view_model()

func _on_ui_reclaim_confirm_requested():
	_try_reclaim_plot(reclaim_confirm_col, reclaim_confirm_row)
	_close_reclaim_confirm()

func _on_ui_reset_cancel_requested():
	reset_confirm_open = false
	queue_redraw()

func _on_ui_reset_confirm_requested():
	reset_confirm_open = false
	_reset_save_data()

func _on_ui_shovel_all_cancel_requested():
	shovel_all_confirm_open = false
	queue_redraw()

func _on_ui_shovel_all_confirm_requested():
	shovel_all_confirm_open = false
	_send_action("shovel_all")

func _build_ui_overlay_view_model() -> Dictionary:
	var reclaim_plot_no := 0
	var reclaim_level := 0
	var reclaim_cost := 0
	if reclaim_confirm_open:
		reclaim_plot_no = _get_plot_index(reclaim_confirm_col, reclaim_confirm_row) + 1
		reclaim_level = _get_reclaim_level(reclaim_confirm_col, reclaim_confirm_row)
		reclaim_cost = _get_reclaim_cost(reclaim_confirm_col, reclaim_confirm_row)
	return {
		"gold": gold,
		"level": level,
		"exp_val": exp_val,
		"exp_to_level": exp_to_level,
		"unlocked_plot_count": _get_unlocked_plot_count(),
		"plot_count": ROWS * COLS,
		"tool_mode": tool_mode,
		"toast_text": toast_text,
		"toast_timer": toast_timer,
		"top_buttons_blocked": reclaim_confirm_open \
				or shovel_all_confirm_open \
				or reset_confirm_open \
				or warehouse_open \
				or shop_open \
				or inventory_open \
				or settings_open,
		"reclaim_confirm_open": reclaim_confirm_open,
		"reset_confirm_open": reset_confirm_open,
		"shovel_all_confirm_open": shovel_all_confirm_open,
		"reclaim_plot_no": reclaim_plot_no,
		"reclaim_level": reclaim_level,
		"reclaim_cost": reclaim_cost,
	}

func _sync_ui_overlay_view_model():
	if _ui_overlay and is_instance_valid(_ui_overlay) and _ui_overlay.has_method("update_view_model"):
		_ui_overlay.update_view_model(_build_ui_overlay_view_model())

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
	var intent := FarmRules.tile_action_intent(state, col, row, tool_mode, selected_seed, selected_fertilizer)
	_execute_tile_intent(intent)

func _execute_tile_intent(intent: Dictionary):
	match str(intent.get("type", FarmRules.INTENT_NONE)):
		FarmRules.INTENT_TOAST:
			toast_text = str(intent.get("message", ""))
			toast_timer = float(intent.get("duration", 1.5))
		FarmRules.INTENT_RECLAIM_CONFIRM:
			_open_reclaim_confirm(int(intent.get("col", -1)), int(intent.get("row", -1)))
		FarmRules.INTENT_SERVER_ACTION:
			var params = intent.get("params", {})
			_send_action(str(intent.get("action", "")), params if params is Dictionary else {})
		FarmRules.INTENT_OPEN_WAREHOUSE:
			warehouse_open = true
			queue_redraw()
		FarmRules.INTENT_SHOVEL_ALL_CONFIRM:
			shovel_all_confirm_open = true
			queue_redraw()

func _ctx_menu_rect(vp_pos: Vector2) -> Rect2:
	# 菜单放在地块（作物）正下方，箭头朝上指向作物。
	# vp_pos 为地块中心屏幕坐标；TH*0.5 为地块半高，乘以缩放再留一点间距。
	var menu_w := ctx_menu_items.size() * 50 + 10
	var menu_h := 60.0
	var below_y := vp_pos.y + (TH * 0.5) * cam.zoom.y + 14.0
	return Rect2(vp_pos.x - menu_w * 0.5, below_y, menu_w, menu_h)

func _open_context_menu(col: int, row: int):
	if row < 0 or col < 0 or farm.is_empty() or row >= farm.size() or col >= farm[row].size():
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
	for spec in FarmRules.context_menu_item_specs(state, col, row, CROPS.size()):
		ctx_menu_items.append(_context_menu_item_with_icon(spec))
		
	ctx_menu_open = true
	queue_redraw()

func _context_menu_item_with_icon(spec: Dictionary) -> Dictionary:
	var item := spec.duplicate(true)
	match str(item.get("type", "")):
		"plant":
			item["icon"] = _get_crop_seed_texture(int(item.get("crop_id", -1)))
		"harvest":
			item["icon"] = TOOL_ICON_TEXTURES[3]
		"weed":
			item["icon"] = TOOL_ICON_TEXTURES[7]
		"pest":
			item["icon"] = TOOL_ICON_TEXTURES[6]
		"water":
			item["icon"] = TOOL_ICON_TEXTURES[1]
		"fertilize":
			item["icon"] = TOOL_ICON_TEXTURES[2]
		"shovel":
			item["icon"] = TOOL_ICON_TEXTURES[4]
	return item

func _execute_context_action(col: int, row: int, item: Dictionary):
	if row < 0 or col < 0 or row >= ROWS or col >= COLS or not item.has("type"):
		return
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
	_copy_client_state_to_model()
	state.apply_server_state(data)
	_copy_state_from_model()
	_sync_all_overlays()
	queue_redraw()

func _try_reclaim_plot(col: int, row: int):
	# 服务端权威：开垦校验与扣费全部由后端处理
	var pi: int = _get_plot_index(col, row)
	_send_action("reclaim", {"plot_index": pi})

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


func _get_unlocked_plot_count() -> int:
	return state.get_unlocked_plot_count()

func _get_next_locked_plot() -> Vector2i:
	return state.get_next_locked_plot()

func _save_game(show_toast := true):
	# 服务端权威：游戏状态由 /farm/action 改动，这里只回传客户端偏好（选中种子/工具）。
	if not is_instance_valid(farm_api) or _save_pending:
		return
	_save_pending = true
	farm_api.request_save(_build_save_payload())
	if show_toast:
		toast_text = "农场已保存"
		toast_timer = 1.2

func _cloud_save():
	_save_game(false)

func _on_save_response(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
	_save_pending = false

func _build_save_payload() -> Dictionary:
	_copy_client_state_to_model()
	return state.build_save_payload()

func _load_game():
	if not _config_loaded:
		return
	# 服务端权威：始终从云端加载
	_cloud_load()

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

# ===================== DRAW =====================
func _draw():
	if farm.is_empty():
		return
	FarmRenderer.draw_world(_build_render_context())

func _build_render_context() -> Dictionary:
	return {
		"draw_api": self,
		"state": state,
		"rows": ROWS,
		"cols": COLS,
		"tile_width": TW,
		"tile_height": TH,
		"tile_gap": TILE_GAP,
		"land_level_max": LAND_LEVEL_MAX,
		"land_upgrade_work_required": LAND_UPGRADE_WORK_REQUIRED,
		"crop_catalog": crop_catalog,
		"crop_colors": CROP_COLORS,
		"render_stage_thresholds": RENDER_STAGE_THRESHOLDS,
		"land_textures": land_textures,
		"land_texture_source_rects": land_texture_source_rects,
		"land_texture_avg_colors": land_texture_avg_colors,
		"plot_positions": _build_plot_positions(),
		"hover": Vector2i(hover_col, hover_row),
		"context_menu_open": ctx_menu_open,
		"context_tile": Vector2i(ctx_col, ctx_row),
		"selected_seed": selected_seed,
		"selected_fertilizer": selected_fertilizer,
		"tool_mode": tool_mode,
		"level": level,
		"gold": gold,
		"sign_texture": _sign_texture,
		"font": _cn_font,
		"viewport_size": get_viewport().get_visible_rect().size,
		"canvas_transform": get_viewport().get_canvas_transform(),
		"can_show_tooltip": not shop_open \
				and not inventory_open \
				and not settings_open \
				and not reclaim_confirm_open \
				and not reset_confirm_open \
				and not warehouse_open \
				and not shovel_all_confirm_open,
	}

func _build_plot_positions() -> Array:
	var positions: Array = []
	for row in range(ROWS):
		var row_positions: Array = []
		for col in range(COLS):
			row_positions.append(_get_plot_position(col, row))
		positions.append(row_positions)
	return positions

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

func _get_crop_stage_texture(cid: int, prog: float) -> Texture2D:
	var stage := _get_growth_stage(prog)
	if stage < 0:
		return null
	return CropAtlas.get_stage_texture(crop_catalog.get_texture_key(cid), stage + 1)

func _get_crop_seed_texture(cid: int) -> Texture2D:
	return CropAtlas.get_stage_texture(crop_catalog.get_texture_key(cid), 0)

func _get_crop_mature_texture(cid: int) -> Texture2D:
	return CropAtlas.get_stage_texture(crop_catalog.get_texture_key(cid), 3)

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
