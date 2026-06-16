extends Node2D

const CropAtlas = preload("res://scripts/crop_atlas.gd")
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
const TOOLBAR_BG_TEXTURE: Texture2D = preload("res://assets/ui/toolbar_bg.png")
var _toolbar_bg_style: StyleBoxTexture = null
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
var http: HTTPRequest
var _save_pending := false # 云端保存中
var _http_cb: Callable = Callable() # 当前HTTP回调

# Camera 拖拽缩放
var cam: Camera2D
var _cam_dragging := false
var _cam_drag_start := Vector2.ZERO
var _cam_start_pos := Vector2.ZERO
var _cam_min_zoom := 1.0 # 由 _fit_camera_to_screen 动态更新
# 触屏状态
var _touch_count := 0
var _touch_positions := {} # {finger_index: Vector2}
var _pinch_start_dist := 0.0
var _pinch_start_zoom := 1.0
var _touch_pan_start := Vector2.ZERO
var _touch_cam_start := Vector2.ZERO
# UI 绘制目标（CanvasLayer 子节点，画在屏幕坐标系）
var _ui_draw_target: CanvasItem = null
var _ui_overlay: Control = null
var _debug_last_input_raw := Vector2.ZERO
var _debug_last_input_viewport := Vector2.ZERO
var _debug_last_input_world := Vector2.ZERO
var _debug_last_toolbar_hit := -1
var _debug_last_tile_hit := Vector2i(-1, -1)
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

func _ready():
	# 加载中文字体
	var font_path := "res://assets/fonts/simhei.ttf"
	if ResourceLoader.exists(font_path):
		_cn_font = load(font_path) as Font
	# Read auth data from login scene
	if get_tree().has_meta("auth_token"):
		auth_token = str(get_tree().get_meta("auth_token"))
		user_info = get_tree().get_meta("user_info") if get_tree().has_meta("user_info") else {}

	# HTTP client for cloud sync
	http = HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)

	# Camera for pan/zoom
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()

	CROPS = [
		# [0]名称,[1]种子价,[2]旧售价,[3]成熟秒,[4]key,
		# [5]base_yield,[6]unit_sell,[7]min_yield,[8]max_yield,
		# [9]dry/h,[10]bug/h,[11]weed/h,[12]max_bug,[13]max_weed
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
	_initialize_default_state()
	_load_land_textures()
	_init_sandy_base()
	_build_cursor_cache()
	_sign_texture = load("res://assets/land/sign.png") as Texture2D
	_load_game()
	_apply_tool_cursor()
	_init_overlays()
	_setup_camera()
	# 设置 UIOverlay 引用，让 UI 在 CanvasLayer 上独立绘制
	_ui_overlay = get_node_or_null("UILayer/UIOverlay")
	if _ui_overlay:
		_ui_overlay.farm_ref = self

func _setup_camera():
	cam.position = Vector2(500.0, 530.0)
	cam.position_smoothing_enabled = false
	_fit_camera_to_screen()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	get_viewport().size_changed.connect(_fit_camera_to_screen)

# 等比缩放：viewport 宽高比 >= 场景宽高比 时以宽为准，否则以高为准
func _fit_camera_to_screen():
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var bg := get_node_or_null("Background")
	if bg == null or not (bg is Sprite2D) or bg.texture == null:
		return
	var scene_size: Vector2 = bg.texture.get_size()
	# viewport 宽高比 vs 场景宽高比
	var vp_ratio: float = vp.x / vp.y
	var scene_ratio: float = scene_size.x / scene_size.y
	if vp_ratio >= scene_ratio:
		_cam_min_zoom = vp.x / scene_size.x * 1.1
	else:
		_cam_min_zoom = vp.y / scene_size.y * 1.1
	cam.zoom = Vector2.ONE * _cam_min_zoom
	cam.position = scene_size * 0.5
	_clamp_camera()

# 未填满的轴居中，填满的轴超出时允许平移
func _clamp_camera():
	if cam == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var bg := get_node_or_null("Background")
	if bg == null or not (bg is Sprite2D) or bg.texture == null:
		return
	var scene_size: Vector2 = bg.texture.get_size()
	var scene_center: Vector2 = scene_size * 0.5
	var visible_w: float = vp.x / cam.zoom.x
	var visible_h: float = vp.y / cam.zoom.y
	# X轴：场景宽 >= 可见宽时允许平移，否则居中
	if scene_size.x >= visible_w:
		var half: float = visible_w * 0.5
		cam.position.x = clampf(cam.position.x, half, scene_size.x - half)
	else:
		cam.position.x = scene_center.x
	# Y轴：场景高 >= 可见高时允许平移，否则居中
	if scene_size.y >= visible_h:
		var half: float = visible_h * 0.5
		cam.position.y = clampf(cam.position.y, half, scene_size.y - half)
	else:
		cam.position.y = scene_center.y

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
	if shop and shop_open:
		_sync_shop_data(shop)
		shop.queue_redraw()
	var inv := get_node_or_null("UILayer/InventoryOverlay")
	if inv and inventory_open:
		inv.inventory = inventory
		inv.queue_redraw()

func _send_sell(crop_id: int, count: int):
	if count <= 0 or not is_instance_valid(http):
		return
	var url := ApiConfig.API_BASE + "/farm/sell"
	var headers := ["Content-Type: application/json", "Authorization: Bearer " + auth_token]
	var body := JSON.stringify({"crop_id": crop_id, "count": count})
	var cb := func(result: int, response_code: int, _h: PackedStringArray, b: PackedByteArray):
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			var parsed = JSON.parse_string(b.get_string_from_utf8())
			if parsed is Dictionary and int(parsed.get("code", -1)) == 0:
				var d: Dictionary = parsed.get("data", {})
				gold = int(d.get("gold", gold))
				var sold: int = int(d.get("sold_count", 0))
				var earned: int = int(d.get("gold_earned", 0))
				inventory[crop_id] = max(0, int(inventory.get(crop_id, 0)) - sold)
				toast_text = "售出 " + str(CROPS[crop_id][0]) + " x" + str(sold) + "，获得 " + str(earned) + " 金币"
				toast_timer = 1.5
	if _http_cb.is_valid() and http.request_completed.is_connected(_http_cb):
		http.request_completed.disconnect(_http_cb)
	_http_cb = cb
	http.request_completed.connect(_http_cb)
	http.request(url, headers, HTTPClient.METHOD_POST, body)

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
	_game_time += delta

	for r in range(ROWS):
		if farm[r].size() < COLS:
			return
		for c in range(COLS):
			var cell: Dictionary = farm[r][c]
			if not _is_cell_unlocked(cell):
				continue
			var cid: int = int(cell["crop_id"])
			var has_crop: bool = cid != -1 and cell["progress"] < 1.0

			# 客户端视觉生长预测（服务端权威覆盖）
			if has_crop:
				var gt: float = float(CROPS[cid][3])
				var speed_mult := 1.0
				if int(cell.get("water_state", 0)) == 1:
					speed_mult *= 0.7
				var bugs: int = int(cell.get("bug_count", 0))
				if bugs > 0:
					speed_mult *= maxf(1.0 - bugs * 0.10, 0.3)
				var weeds: int = int(cell.get("weed_count", 0))
				if weeds > 0:
					speed_mult *= maxf(1.0 - weeds * 0.05, 0.5)
				cell["progress"] = minf(cell["progress"] + delta * speed_mult / gt, 1.0)

			cell["wet_timer"] = maxf(float(cell.get("wet_timer", 0.0)) - delta, 0.0)

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

func _get_crop_stage_enum(prog: float) -> int:
	if prog < 0.18:
		return 0 # 种子期
	if prog < 0.45:
		return 1 # 发芽期
	if prog < 0.90:
		return 2 # 生长期
	return 3 # 成熟期

func _check_events():
	var stage_mult := [0.5, 1.0, 1.2, 0.0]
	var check_hours := 10.0 / 3600.0
	for r in range(ROWS):
		for c in range(COLS):
			var cell: Dictionary = farm[r][c]
			if not _is_cell_unlocked(cell):
				continue
			var cid: int = int(cell["crop_id"])
			if cid == -1 or cell["progress"] >= 1.0:
				continue
			var stage: int = _get_crop_stage_enum(cell["progress"])
			if stage == 3:
				continue
			var sm: float = stage_mult[stage]

			# 缺水事件
			if int(cell.get("water_state", 0)) == 0:
				if _game_time >= float(cell.get("water_protect_until", 0.0)):
					var dry_rate: float = float(CROPS[cid][9])
					if randf() < dry_rate * check_hours * sm:
						cell["water_state"] = 1 # DRY

			# 虫害事件
			var max_bugs: int = int(CROPS[cid][12])
			if int(cell.get("bug_count", 0)) < max_bugs:
				if _game_time >= float(cell.get("bug_protect_until", 0.0)):
					var bug_rate: float = float(CROPS[cid][10])
					if randf() < bug_rate * check_hours * sm:
						cell["bug_count"] = int(cell.get("bug_count", 0)) + 1
						if cell.get("bug_since", 0.0) == 0.0:
							cell["bug_since"] = _game_time

			# 杂草事件
			var max_weeds: int = int(CROPS[cid][13])
			if int(cell.get("weed_count", 0)) < max_weeds:
				if _game_time >= float(cell.get("weed_protect_until", 0.0)):
					var weed_rate: float = float(CROPS[cid][11])
					if randf() < weed_rate * check_hours * sm:
						cell["weed_count"] = int(cell.get("weed_count", 0)) + 1
						if cell.get("weed_since", 0.0) == 0.0:
							cell["weed_since"] = _game_time

func _check_protection_expiry():
	for r in range(ROWS):
		for c in range(COLS):
			var cell: Dictionary = farm[r][c]
			if not _is_cell_unlocked(cell):
				continue
			# 浇水保护期过期，Watered → Normal（如果没缺水）
			if int(cell.get("water_state", 0)) == 2:
				if _game_time >= float(cell.get("water_protect_until", 0.0)):
					cell["water_state"] = 0

func _notification(what: int):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game(false)

func _exit_tree():
	Input.set_custom_mouse_cursor(null)
	# 在节点释放前断开 HTTP 回调，防止回调访问已释放的节点
	if is_instance_valid(http) and _http_cb.is_valid() and http.request_completed.is_connected(_http_cb):
		http.request_completed.disconnect(_http_cb)
	_http_cb = Callable()

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

	# ---- 触屏：手指按下/抬起 ----
	if event is InputEventScreenTouch:
		if event.pressed:
			var touch_pos := _window_to_viewport_pos(event.position)
			_touch_positions[event.index] = touch_pos
			_touch_count += 1
			if _touch_count == 1:
				# 单指按下：准备拖拽
				_touch_pan_start = touch_pos
				_touch_cam_start = cam.position
			elif _touch_count == 2:
				# 双指按下：准备缩放
				var keys := _touch_positions.keys()
				var p0: Vector2 = _touch_positions[keys[0]]
				var p1: Vector2 = _touch_positions[keys[1]]
				_pinch_start_dist = p0.distance_to(p1)
				_pinch_start_zoom = cam.zoom.x
		else:
			if _touch_count == 1 and event.index in _touch_positions:
				# 单指抬起：如果没有明显移动，当作点击
				var touch_pos := _window_to_viewport_pos(event.position)
				var moved: float = _touch_positions[event.index].distance_to(touch_pos)
				if moved < 15.0:
					_handle_click(event.position)
			_touch_positions.erase(event.index)
			_touch_count = _touch_positions.size()
		return

	# ---- 触屏：手指移动 ----
	if event is InputEventScreenDrag:
		var touch_pos := _window_to_viewport_pos(event.position)
		_touch_positions[event.index] = touch_pos
		if _touch_count == 1:
			# 单指拖拽：平移相机
			var delta_screen: Vector2 = _touch_pan_start - touch_pos
			var delta_world: Vector2 = delta_screen / cam.zoom
			cam.position = _touch_cam_start + delta_world
			_clamp_camera()
			queue_redraw()
		elif _touch_count == 2:
			# 双指缩放
			var keys := _touch_positions.keys()
			var p0: Vector2 = _touch_positions[keys[0]]
			var p1: Vector2 = _touch_positions[keys[1]]
			var dist: float = p0.distance_to(p1)
			if _pinch_start_dist > 0:
				var ratio: float = dist / _pinch_start_dist
				cam.zoom = Vector2.ONE * clampf(_pinch_start_zoom * ratio, _cam_min_zoom, 3.0)
				_clamp_camera()
				queue_redraw()
		return

	# ---- Camera: 中键/右键拖拽平移 ----
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT):
		_cam_dragging = event.pressed
		if _cam_dragging:
			_cam_drag_start = event.position
			_cam_start_pos = cam.position
		return

	if event is InputEventMouseMotion and _cam_dragging:
		var mouse_pos: Vector2 = event.position
		var delta_screen: Vector2 = _cam_drag_start - mouse_pos
		var delta_world: Vector2 = delta_screen / cam.zoom
		cam.position = _cam_start_pos + delta_world
		# 限制平移范围，保持地块在视野内
		_clamp_camera()
		queue_redraw()
		return

	# ---- Camera: 滚轮缩放（以鼠标位置为中心） ----
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var vp: Vector2 = get_viewport().get_visible_rect().size
			var mouse_pos: Vector2 = event.position
			var old_zoom := cam.zoom.x
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				cam.zoom *= 1.1
			else:
				cam.zoom /= 1.1
			cam.zoom = cam.zoom.clampf(_cam_min_zoom, 3.0)
			var new_zoom := cam.zoom.x
			if new_zoom != old_zoom:
				# 以鼠标位置为中心缩放：计算鼠标在世界坐标中的位置，缩放后保持不变
				var vp_center: Vector2 = vp * 0.5
				var mouse_offset: Vector2 = mouse_pos - vp_center
				var world_offset: Vector2 = mouse_offset / old_zoom
				cam.position += world_offset * (1.0 - old_zoom / new_zoom)
			_clamp_camera()
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
		_debug_last_input_raw = event.position
		_debug_last_input_viewport = mouse_pos
		# 地块 hover 用世界坐标
		var wp := _viewport_to_world(mouse_pos)
		_debug_last_input_world = wp
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
		var mouse_pos: Vector2 = event.position
		var mx: float = mouse_pos.x
		var my: float = mouse_pos.y
		# 地块点击用世界坐标
		var wp := _viewport_to_world(mouse_pos)
		var wx: float = wp.x
		var wy: float = wp.y
		_debug_last_input_raw = event.position
		_debug_last_input_viewport = mouse_pos
		_debug_last_input_world = wp
		_debug_last_toolbar_hit = -1
		_debug_last_tile_hit = Vector2i(-1, -1)
		mouse_held = false # only set true if click is on the grid

		# Check reclaim confirmation overlay (屏幕坐标)
		if reclaim_confirm_open:
			var reclaim_rect := _get_reclaim_confirm_rect()
			var cancel_rect := Rect2(reclaim_rect.position.x + 40, reclaim_rect.position.y + 145, 130, 34)
			var confirm_rect := Rect2(reclaim_rect.position.x + reclaim_rect.size.x - 170, reclaim_rect.position.y + 145, 130, 34)
			if not _point_in_rect(Vector2(mx, my), reclaim_rect):
				_close_reclaim_confirm()
				return
			if _point_in_rect(Vector2(mx, my), cancel_rect):
				_close_reclaim_confirm()
				return
			if _point_in_rect(Vector2(mx, my), confirm_rect):
				_try_reclaim_plot(reclaim_confirm_col, reclaim_confirm_row)
				_close_reclaim_confirm()
				return
			return

		# Check shovel-all confirmation overlay (屏幕坐标)
		if shovel_all_confirm_open:
			var sa_rect := Rect2(vp.x * 0.5 - 200, vp.y * 0.5 - 80, 400, 160)
			var sa_cancel := Rect2(sa_rect.position.x + 40, sa_rect.position.y + 120, 130, 30)
			var sa_confirm := Rect2(sa_rect.position.x + sa_rect.size.x - 170, sa_rect.position.y + 120, 130, 30)
			if not _point_in_rect(Vector2(mx, my), sa_rect):
				shovel_all_confirm_open = false; queue_redraw(); return
			if _point_in_rect(Vector2(mx, my), sa_cancel):
				shovel_all_confirm_open = false; queue_redraw(); return
			if _point_in_rect(Vector2(mx, my), sa_confirm):
				shovel_all_confirm_open = false
				_send_action("shovel_all")
				return
			return

		# Check warehouse overlay (屏幕坐标)
		if warehouse_open:
			var ww := 360.0; var wh := 300.0
			var wox := (vp.x - ww) / 2; var woy := (vp.y - wh) / 2
			if mx < wox or mx > wox + ww or my < woy or my > woy + wh:
				warehouse_open = false; queue_redraw(); return
			return

		# Check reset confirmation overlay (屏幕坐标)
		if reset_confirm_open:
			var reset_rect := _get_reset_confirm_rect()
			var reset_cancel_rect := Rect2(reset_rect.position.x + 50, reset_rect.position.y + 165, 150, 36)
			var reset_confirm_rect := Rect2(reset_rect.position.x + reset_rect.size.x - 200, reset_rect.position.y + 165, 150, 36)
			if not _point_in_rect(Vector2(mx, my), reset_rect):
				reset_confirm_open = false
				queue_redraw()
				return
			if _point_in_rect(Vector2(mx, my), reset_cancel_rect):
				reset_confirm_open = false
				queue_redraw()
				return
			if _point_in_rect(Vector2(mx, my), reset_confirm_rect):
				reset_confirm_open = false
				_reset_save_data()
				return
			return

		# Check context menu
		if ctx_menu_open:
			var ctx_wp := _get_plot_position(ctx_col, ctx_row)
			var vp_pos = (ctx_wp - cam.position) * cam.zoom + vp * 0.5
			var menu_w = ctx_menu_items.size() * 50 + 10
			var menu_rect = Rect2(vp_pos.x - menu_w * 0.5, vp_pos.y - 80, menu_w, 60)
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
			_debug_last_tile_hit = Vector2i(best_col, best_row)
			mouse_held = true
			_open_context_menu(best_col, best_row)
			last_action_col = best_col
			last_action_row = best_row
			queue_redraw()
			return

		# Tool mode buttons (屏幕坐标)
		var tb_btn_s: float = 58.0
		var tb_btn_g: float = 8.0
		var tb_total2: float = 10.0 * tb_btn_s + 9.0 * tb_btn_g
		var tb_sx: float = vp.x * 0.5 - tb_total2 * 0.5
		var tb_y2: float = vp.y * 0.8
		if my >= tb_y2 and my <= tb_y2 + 78:
			for ti in range(10):
				var bx2: float = tb_sx + ti * (tb_btn_s + tb_btn_g)
				if mx >= bx2 and mx <= bx2 + tb_btn_s:
					_debug_last_toolbar_hit = ti
					_set_tool_mode(ti)
					var mode_names2 := ["普通", "浇水", "施肥", "收获", "铲除", "全铲", "除虫", "除草", "全收", "仓库"]
					toast_text = "切换到: " + mode_names2[ti] + "模式"
					toast_timer = 1.0
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
		var stage = _get_growth_stage(cell.get("progress", 0.0))
		if stage >= 3:
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
	_debug_last_input_raw = screen_pos
	_debug_last_input_viewport = viewport_pos
	_debug_last_input_world = _viewport_to_world(viewport_pos)
	_debug_last_toolbar_hit = -1
	_debug_last_tile_hit = Vector2i(-1, -1)
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
		_debug_last_tile_hit = Vector2i(best_col, best_row)
		_do_tile_action(best_col, best_row)
		queue_redraw()
		return
	# 工具栏按钮（屏幕坐标）
	var tb_btn_s: float = 58.0
	var tb_btn_g: float = 8.0
	var tb_total: float = 10.0 * tb_btn_s + 9.0 * tb_btn_g
	var tb_sx: float = vp.x * 0.5 - tb_total * 0.5
	var tb_y: float = vp.y * 0.8
	if my >= tb_y and my <= tb_y + 78:
		for ti in range(10):
			var bx: float = tb_sx + ti * (tb_btn_s + tb_btn_g)
			if mx >= bx and mx <= bx + tb_btn_s:
				_debug_last_toolbar_hit = ti
				_set_tool_mode(ti)
				queue_redraw()
				return
# ---- Server action API ----
func _send_action(action: String, params: Dictionary = {}):
	if auth_token.is_empty():
		toast_text = "未登录，无法执行操作"
		toast_timer = 1.5
		return
	if not is_instance_valid(http):
		return
	params["action"] = action
	var url := ApiConfig.API_BASE + "/farm/action"
	var headers := ["Content-Type: application/json", "Authorization: Bearer " + auth_token]
	if _http_cb.is_valid() and http.request_completed.is_connected(_http_cb):
		http.request_completed.disconnect(_http_cb)
	_http_cb = _on_action_response
	http.request_completed.connect(_http_cb)
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(params))

func _on_action_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS:
		toast_text = "网络错误"
		toast_timer = 1.5
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
			cell["progress"] = clampf(float(p.get("progress", 0.0)), 0.0, 1.0)
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
			cell["yield_bonus_rate"] = maxf(float(p.get("yield_bonus_rate", 0.0)), 0.0)
			cell["yield_loss_rate"] = clampf(float(p.get("yield_loss_rate", 0.0)), 0.0, 0.30)
	_sync_all_overlays()
	queue_redraw()

func _try_reclaim_plot(col: int, row: int):
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
	toast_text = "开垦成功! 解锁第 " + str(_get_plot_index(col, row) + 1) + " 块地"
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

func _get_reclaim_confirm_rect() -> Rect2:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	return Rect2(vp.x * 0.5 - 210.0, vp.y * 0.5 - 100.0, 420.0, 200.0)

func _get_reset_confirm_rect() -> Rect2:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	return Rect2(vp.x * 0.5 - 240.0, vp.y * 0.5 - 110.0, 480.0, 220.0)

func _point_in_rect(point: Vector2, rect: Rect2) -> bool:
	return point.x >= rect.position.x and point.x <= rect.position.x + rect.size.x and point.y >= rect.position.y and point.y <= rect.position.y + rect.size.y


func _harvest_all():
	var count := 0
	for r in range(ROWS):
		for c in range(COLS):
			var cell: Dictionary = farm[r][c]
			if not _is_cell_unlocked(cell):
				continue
			if cell["crop_id"] != -1 and cell["progress"] >= 1.0:
				var cid: int = int(cell["crop_id"])
				var yield_count := _calc_harvest_yield(cell, cid)
				exp_val += int(CROPS[cid][2]) / 5
				_add_to_inventory(cid, yield_count)
				_add_land_work(r, c, 1)
				cell["crop_id"] = -1
				cell["progress"] = 0.0
				cell["wet_timer"] = 0.0
				cell["water_state"] = 0; cell["dry_timer"] = 0.0
				cell["bug_count"] = 0; cell["bug_since"] = 0.0
				cell["weed_count"] = 0; cell["weed_since"] = 0.0
				cell["fert_used"] = 0; cell["fert_stage_used"] = {}; cell["fert_ids_used"] = []
				cell["yield_bonus_rate"] = 0.0; cell["yield_loss_rate"] = 0.0
				count += 1
	if count > 0:
		_check_lv()
		toast_text = "一键收获了 " + str(count) + " 个作物，已放入背包"
		toast_timer = 2.0
	else:
		toast_text = "没有成熟的作物!"
		toast_timer = 2.0

func _shovel_all_crops():
	var count := 0
	for r in range(ROWS):
		for c in range(COLS):
			var cell: Dictionary = farm[r][c]
			if _is_cell_unlocked(cell) and cell["crop_id"] != -1:
				cell["crop_id"] = -1
				cell["progress"] = 0.0
				cell["wet_timer"] = 0.0
				count += 1
	if count > 0:
		toast_text = "铲除了全部 " + str(count) + " 个作物"
		toast_timer = 2.0
	else:
		toast_text = "没有作物可以铲除"
		toast_timer = 2.0

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

func _calc_harvest_yield(cell: Dictionary, cid: int) -> int:
	var base: int = int(CROPS[cid][5])
	var bonus := int(base * float(cell.get("yield_bonus_rate", 0.0)))
	# 产量损失计算
	var loss := 0.0
	var dt: float = float(cell.get("dry_timer", 0.0))
	if dt >= 5400.0:
		loss += 0.10
	elif dt >= 1800.0:
		loss += 0.05
	var bc: int = int(cell.get("bug_count", 0))
	if bc >= 3:
		loss += 0.10
	elif bc >= 2:
		loss += 0.05
	var wc: int = int(cell.get("weed_count", 0))
	if wc >= 3:
		loss += 0.10
	elif wc >= 2:
		loss += 0.05
	loss = minf(loss, 0.30)
	var result := base + bonus - int(base * loss)
	# 丰收肥保底至少+1
	if float(cell.get("yield_bonus_rate", 0.0)) > 0.0 and bonus == 0:
		result += 1
	return clampi(result, int(CROPS[cid][7]), int(CROPS[cid][8]))

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

func _check_lv():
	while exp_val >= exp_to_level:
		exp_val -= exp_to_level
		level += 1
		exp_to_level = int(exp_to_level * 1.5)

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
	var data := {
		"gold": gold,
		"level": level,
		"exp_val": exp_val,
		"exp_to_level": exp_to_level,
		"farm": farm,
		"inventory": inventory,
		"selected_seed": selected_seed,
		"tool_mode": tool_mode,
		"fertilizer_inventory": fertilizer_inventory,
		"selected_fertilizer": selected_fertilizer,
		"game_time": _game_time,
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
	if not is_instance_valid(http):
		return
	_save_pending = true
	var payload := _build_save_payload()
	var url := ApiConfig.API_BASE + "/farm/save"
	var headers := ["Content-Type: application/json", "Authorization: Bearer " + auth_token]
	var cb := func(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
		_save_pending = false
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			pass # 静默成功
	if _http_cb.is_valid() and http.request_completed.is_connected(_http_cb):
		http.request_completed.disconnect(_http_cb)
	_http_cb = cb
	http.request_completed.connect(_http_cb)
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))

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
				"fert_stage_used": JSON.stringify(cell.get("fert_stage_used", {})),
				"fert_ids_used": JSON.stringify(cell.get("fert_ids_used", [])),
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

func _load_game():
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
	gold = int(data.get("gold", gold))
	level = int(data.get("level", level))
	exp_val = int(data.get("exp_val", exp_val))
	exp_to_level = int(data.get("exp_to_level", exp_to_level))
	selected_seed = int(data.get("selected_seed", selected_seed))
	_set_tool_mode(int(data.get("tool_mode", tool_mode)))
	if data.has("inventory") and (data["inventory"] is Dictionary):
		inventory = data["inventory"]
		_normalize_inventory_keys()
	if data.has("farm") and (data["farm"] is Array):
		_restore_farm(data["farm"])

func _cloud_load():
	if not is_instance_valid(http):
		return
	var url := ApiConfig.API_BASE + "/farm/load"
	var headers := ["Authorization: Bearer " + auth_token]
	var cb := func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
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
	if _http_cb.is_valid() and http.request_completed.is_connected(_http_cb):
		http.request_completed.disconnect(_http_cb)
	_http_cb = cb
	http.request_completed.connect(_http_cb)
	http.request(url, headers, HTTPClient.METHOD_GET)

func _apply_cloud_data(data: Dictionary):
	gold = int(data.get("gold", gold))
	level = int(data.get("level", level))
	exp_val = int(data.get("exp_val", exp_val))
	exp_to_level = int(data.get("exp_to_level", exp_to_level))
	_game_time = float(data.get("game_time", _game_time))
	selected_seed = int(data.get("selected_seed", selected_seed))
	_set_tool_mode(int(data.get("tool_mode", tool_mode)))
	if data.has("inventory") and (data["inventory"] is Dictionary):
		inventory = data["inventory"]
		_normalize_inventory_keys()
	# Sync fertilizer inventory
	if data.has("fertilizer_inventory") and (data["fertilizer_inventory"] is Dictionary):
		fertilizer_inventory = {}
		for k in data["fertilizer_inventory"].keys():
			fertilizer_inventory[int(k)] = int(data["fertilizer_inventory"][k])
	# plots 数组 → farm 二维数组
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
			cell["progress"] = clampf(float(p.get("progress", 0.0)), 0.0, 1.0)
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
			var fsu_raw = p.get("fert_stage_used", "{}")
			if fsu_raw is String:
				var parsed_fsu = JSON.parse_string(fsu_raw)
				cell["fert_stage_used"] = parsed_fsu if parsed_fsu is Dictionary else {}
			else:
				cell["fert_stage_used"] = fsu_raw if fsu_raw is Dictionary else {}
			var fiu_raw = p.get("fert_ids_used", "[]")
			if fiu_raw is String:
				var parsed_fiu = JSON.parse_string(fiu_raw)
				cell["fert_ids_used"] = parsed_fiu if parsed_fiu is Array else []
			else:
				cell["fert_ids_used"] = fiu_raw if fiu_raw is Array else []
			cell["yield_bonus_rate"] = maxf(float(p.get("yield_bonus_rate", 0.0)), 0.0)
			cell["yield_loss_rate"] = clampf(float(p.get("yield_loss_rate", 0.0)), 0.0, 0.30)
	_sync_all_overlays()
	queue_redraw()

func _normalize_inventory_keys():
	var fixed := {}
	for key in inventory.keys():
		var cid := int(key)
		fixed[cid] = int(inventory[key])
	inventory = fixed

func _restore_farm(saved_farm: Array):
	for r in range(mini(ROWS, saved_farm.size())):
		if not (saved_farm[r] is Array):
			continue
		var saved_row: Array = saved_farm[r]
		for c in range(mini(COLS, saved_row.size())):
			if saved_row[c] is Dictionary:
				var saved_cell: Dictionary = saved_row[c]
				var cid := int(saved_cell.get("crop_id", -1))
				if cid >= -1 and cid < CROPS.size():
					farm[r][c]["crop_id"] = cid
					farm[r][c]["progress"] = clampf(float(saved_cell.get("progress", 0.0)), 0.0, 1.0)
					farm[r][c]["wet_timer"] = maxf(float(saved_cell.get("wet_timer", 0.0)), 0.0)
					var was_unlocked := bool(saved_cell.get("unlocked", cid != -1 or _get_plot_index(c, r) < INITIAL_UNLOCKED_PLOTS))
					var land_level := int(saved_cell.get("land_level", 1 if was_unlocked else LAND_LEVEL_LOCKED))
					land_level = clampi(land_level, LAND_LEVEL_LOCKED, LAND_LEVEL_MAX)
					farm[r][c]["land_level"] = land_level
					farm[r][c]["land_work"] = clampi(int(saved_cell.get("land_work", 0)), 0, LAND_UPGRADE_WORK_REQUIRED - 1)
					farm[r][c]["unlocked"] = land_level > LAND_LEVEL_LOCKED
					# 新打理字段（向后兼容，旧存档缺失时用默认值）
					farm[r][c]["water_state"] = int(saved_cell.get("water_state", 0))
					farm[r][c]["dry_timer"] = maxf(float(saved_cell.get("dry_timer", 0.0)), 0.0)
					farm[r][c]["water_protect_until"] = float(saved_cell.get("water_protect_until", 0.0))
					farm[r][c]["bug_count"] = clampi(int(saved_cell.get("bug_count", 0)), 0, 3)
					farm[r][c]["bug_since"] = float(saved_cell.get("bug_since", 0.0))
					farm[r][c]["bug_protect_until"] = float(saved_cell.get("bug_protect_until", 0.0))
					farm[r][c]["weed_count"] = clampi(int(saved_cell.get("weed_count", 0)), 0, 3)
					farm[r][c]["weed_since"] = float(saved_cell.get("weed_since", 0.0))
					farm[r][c]["weed_protect_until"] = float(saved_cell.get("weed_protect_until", 0.0))
					farm[r][c]["fert_used"] = clampi(int(saved_cell.get("fert_used", 0)), 0, 3)
					farm[r][c]["fert_stage_used"] = saved_cell.get("fert_stage_used", {})
					farm[r][c]["fert_ids_used"] = saved_cell.get("fert_ids_used", [])
					farm[r][c]["yield_bonus_rate"] = maxf(float(saved_cell.get("yield_bonus_rate", 0.0)), 0.0)
					farm[r][c]["yield_loss_rate"] = clampf(float(saved_cell.get("yield_loss_rate", 0.0)), 0.0, 0.30)

func _apply_offline_growth(saved_at: int):
	var elapsed: int = maxi(0, int(Time.get_unix_time_from_system()) - saved_at)
	if elapsed <= 0:
		return
	_game_time += float(elapsed)
	var grew_count := 0
	var event_count := 0
	var elapsed_hours: float = float(elapsed) / 3600.0
	var stage_mult := [0.5, 1.0, 1.2, 0.0]
	for r in range(ROWS):
		for c in range(COLS):
			var cell: Dictionary = farm[r][c]
			if not _is_cell_unlocked(cell):
				continue
			if cell["crop_id"] != -1 and cell["progress"] < 1.0:
				var cid := int(cell["crop_id"])
				var before := float(cell["progress"])
				var gt := float(CROPS[cid][3])
				var stage: int = _get_crop_stage_enum(before)
				var sm: float = stage_mult[stage] if stage < 3 else 0.0
				# 离线生长（含减速：按当前状态估算平均减速）
				var speed_mult := 1.0
				if int(cell.get("water_state", 0)) == 1:
					speed_mult *= 0.85 # 离线用平均减速
				var bc := int(cell.get("bug_count", 0))
				if bc > 0:
					speed_mult *= maxf(1.0 - bc * 0.10, 0.5)
				var wc := int(cell.get("weed_count", 0))
				if wc > 0:
					speed_mult *= maxf(1.0 - wc * 0.05, 0.6)
				cell["progress"] = minf(before + float(elapsed) * speed_mult / gt, 1.0)
				if before < 1.0 and cell["progress"] >= 1.0:
					grew_count += 1
				# 离线事件补算
				if cell["progress"] < 1.0 and stage < 3:
					# 缺水
					if int(cell.get("water_state", 0)) == 0 and _game_time >= float(cell.get("water_protect_until", 0.0)):
						var dry_rate: float = float(CROPS[cid][9])
						if randf() < dry_rate * elapsed_hours * sm:
							cell["water_state"] = 1
							event_count += 1
					# 虫害（可多只）
					var max_bugs: int = int(CROPS[cid][12])
					if int(cell.get("bug_count", 0)) < max_bugs and _game_time >= float(cell.get("bug_protect_until", 0.0)):
						var bug_rate: float = float(CROPS[cid][10])
						var new_bugs := int(bug_rate * elapsed_hours * sm * 10.0) # 期望虫数
						if new_bugs > 0:
							cell["bug_count"] = clampi(int(cell.get("bug_count", 0)) + new_bugs, 0, max_bugs)
							if cell.get("bug_since", 0.0) == 0.0:
								cell["bug_since"] = _game_time
							event_count += 1
					# 杂草（可多棵）
					var max_weeds: int = int(CROPS[cid][13])
					if int(cell.get("weed_count", 0)) < max_weeds and _game_time >= float(cell.get("weed_protect_until", 0.0)):
						var weed_rate: float = float(CROPS[cid][11])
						var new_weeds := int(weed_rate * elapsed_hours * sm * 10.0)
						if new_weeds > 0:
							cell["weed_count"] = clampi(int(cell.get("weed_count", 0)) + new_weeds, 0, max_weeds)
							if cell.get("weed_since", 0.0) == 0.0:
								cell["weed_since"] = _game_time
							event_count += 1
				# 缺水持续时间累加
				if int(cell.get("water_state", 0)) == 1:
					cell["dry_timer"] = float(cell.get("dry_timer", 0.0)) + float(elapsed)
	if grew_count > 0:
		toast_text = "离线期间成熟了 " + str(grew_count) + " 个作物"
		toast_timer = 3.0
	elif event_count > 0:
		toast_text = "离线期间出现了 " + str(event_count) + " 个打理事件，快去看看吧!"
		toast_timer = 3.0

# ===================== DRAW =====================
func _draw():
	if farm.is_empty():
		return
	_draw_world()

func _draw_world():
	# 计算当前可见的世界坐标范围（用于 tooltip 裁剪）
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var ctrans := get_viewport().get_canvas_transform()
	var w_min := ctrans.affine_inverse() * Vector2.ZERO
	var w_max := ctrans.affine_inverse() * vp
	# Title bar
	_d_rect(Rect2(100, 40, 440, 40), Color(0.1, 0.06, 0.02, 0.85))
	_draw_text(200, 46, "QQ 农场 2.5D", 24, Color(1, 0.9, 0.2))

	# ---- ISOMETRIC TILES: PASS 1 - Soil + borders (back to front) ----
	if farm.size() < ROWS:
		return
	for row in range(ROWS):
		if farm[row].size() < COLS:
			return
		for col in range(COLS):
			var sp := _get_plot_position(col, row)
			var cx: float = sp.x
			var cy: float = sp.y
			var vcorners := iso_visual_corners(cx, cy)
			var cell: Dictionary = farm[row][col]
			_draw_land_tile(vcorners, cell)

			# Hover glow (on soil layer)
			if (col == hover_col and row == hover_row) or (ctx_menu_open and col == ctx_col and row == ctx_row):
				if not _is_cell_unlocked(cell):
					_d_colored_polygon(vcorners, Color(0.75, 0.75, 0.75, 0.22))
				elif cell["crop_id"] == -1 and selected_seed >= 0:
					_d_colored_polygon(vcorners, Color(0.3, 0.9, 0.3, 0.25))
				elif cell["crop_id"] != -1 and cell["progress"] >= 1.0:
					_d_colored_polygon(vcorners, Color(1.0, 0.85, 0.15, 0.35))
				else:
					_d_colored_polygon(vcorners, Color(1, 1, 1, 0.1))

			# Border
			if (col == hover_col and row == hover_row) or (ctx_menu_open and col == ctx_col and row == ctx_row):
				var bcol := Color(1, 0.9, 0.2, 0.9)
				for i in range(4):
					_d_line(vcorners[i], vcorners[(i + 1) % 4], bcol, 2.0)

			# Seed preview on empty tile
			if _is_cell_unlocked(cell) and cell["crop_id"] == -1 and col == hover_col and row == hover_row and selected_seed >= 0:
				var seed_texture := _get_crop_seed_texture(selected_seed)
				if seed_texture != null:
					_draw_seed_preview_texture(cx, cy, seed_texture)
				else:
					_d_circle(Vector2(cx, cy), 10, Color(CROP_COLORS[selected_seed][1].r, CROP_COLORS[selected_seed][1].g, CROP_COLORS[selected_seed][1].b, 0.7))
					_d_circle(Vector2(cx, cy), 6, CROP_COLORS[selected_seed][1])

	# ---- ISOMETRIC TILES: PASS 2 - Crops + progress bars (back to front) ----
	for row in range(ROWS):
		if farm[row].size() < COLS:
			return
		for col in range(COLS):
			var sp := _get_plot_position(col, row)
			var cx: float = sp.x
			var cy: float = sp.y
			var cell: Dictionary = farm[row][col]

			if not _is_cell_unlocked(cell):
				var req_level := _get_reclaim_level(col, row)
				var req_cost := _get_reclaim_cost(col, row)
				var is_next := _get_next_locked_plot().x == col and _get_next_locked_plot().y == row
				if is_next and _sign_texture != null:
					var can := level >= req_level and gold >= req_cost
					var sign_color := Color(0.2, 0.8, 0.25) if can else Color(0.85, 0.25, 0.2)
					var sign_label := "可解锁" if can else "Lv." + str(req_level) + "解锁"
					_draw_sign(cx, cy, sign_color, sign_label, can)
				else:
					var lock_text := "Lv" + str(req_level)
					var f_lock: Font = _cn_font if _cn_font != null else ThemeDB.fallback_font
					var lock_w: float = f_lock.get_string_size(lock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
					_d_rect(Rect2(cx - lock_w * 0.5 - 6, cy - 10, lock_w + 12, 18), Color(0.02, 0.02, 0.02, 0.68))
					_draw_text(cx - lock_w * 0.5, cy - 8, lock_text, 12, Color(0.92, 0.9, 0.78, 0.95))
					if col == hover_col and row == hover_row:
						var cost_text := str(req_cost) + " 金币开垦"
						var cost_w: float = f_lock.get_string_size(cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
						_d_rect(Rect2(cx - cost_w * 0.5 - 6, cy + 12, cost_w + 12, 17), Color(0.02, 0.02, 0.02, 0.72))
						_draw_text(cx - cost_w * 0.5, cy + 13, cost_text, 11, Color(1.0, 0.82, 0.26, 0.95))
				continue

			if cell["crop_id"] != -1:
				var cid: int = int(cell["crop_id"])
				var prog: float = cell["progress"]
				var fruit_col: Color = CROP_COLORS[cid][1]
				var leaf_col: Color = CROP_COLORS[cid][0]
				var stage: int = _get_growth_stage(prog)
				var atlas_texture: Texture2D = _get_crop_stage_texture(cid, prog)

				if stage < 0:
					_draw_plant_seed(cx, cy, prog)
				elif atlas_texture != null:
					_draw_crop_atlas_texture(cx, cy, atlas_texture, prog, cid, stage)
				elif prog > 0.3:
					_draw_plant_growing(cx, cy, leaf_col, prog)
				else:
					_draw_plant_seed(cx, cy, prog)

				if prog >= 1.0:
					if atlas_texture == null:
						_draw_plant_full(cx, cy, leaf_col, fruit_col)
					# Harvest label
					var f: Font = _cn_font if _cn_font != null else ThemeDB.fallback_font
					var lbl := "收获"
					var lw: float = f.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
					_d_rect(Rect2(cx - lw * 0.5 - 4, cy - TH * 0.5 - 22, lw + 8, 16), Color(0.8, 0.6, 0, 0.85))
					_draw_text(cx - lw * 0.5, cy - TH * 0.5 - 19, lbl, 11, Color(1, 1, 1))

				# Progress bar
				if prog < 1.0:
					var bw: float = TW * 0.5
					var bx: float = cx - bw * 0.5
					var by: float = cy + TH * 0.35
					_d_rect(Rect2(bx, by, bw, 5), Color(0, 0, 0, 0.5))
					var bc := Color(0.2, 0.8, 0.3) if prog < 0.6 else Color(0.95, 0.75, 0.1)
					_d_rect(Rect2(bx, by, bw * prog, 5), bc)
					# Stage name + time remaining (always visible)
					var stage_name: String
					var remaining: int = int((1.0 - prog) * float(CROPS[cid][3]))
					if prog < 0.15:
						stage_name = "种子"
					elif prog < 0.4:
						stage_name = "发芽"
					elif prog < 0.7:
						stage_name = "生长"
					else:
						stage_name = "快熟"
					var info: String = stage_name + " " + str(remaining) + "秒"
					_draw_text(cx - 20, cy + TH * 0.5 + 14, info, 9, Color(1, 1, 1, 0.75))
				else:
					# Mature: show yield hint
					var yield_hint := "产量 " + str(int(CROPS[cid][5])) + "~" + str(int(CROPS[cid][8]))
					_draw_text(cx - 20, cy + TH * 0.5 + 14, yield_hint, 9, Color(1, 0.9, 0.3, 0.8))

				# 状态图标（缺水/虫/草）
				if prog < 1.0:
					var icon_y := cy - TH * 0.5 - 8
					var icon_x := cx + 12
					var ws: int = int(cell.get("water_state", 0))
					var bc: int = int(cell.get("bug_count", 0))
					var wc: int = int(cell.get("weed_count", 0))
					if ws == 1: # DRY
						_d_circle(Vector2(icon_x, icon_y), 6, Color(0.2, 0.5, 0.9, 0.8))
						_draw_text(icon_x - 3, icon_y + 3, "渴", 8, Color(1, 1, 1))
						icon_x -= 16
					if bc > 0:
						_d_circle(Vector2(icon_x, icon_y), 6, Color(0.9, 0.2, 0.2, 0.8))
						_draw_text(icon_x - 3, icon_y + 3, str(bc), 8, Color(1, 1, 1))
						icon_x -= 16
					if wc > 0:
						_d_circle(Vector2(icon_x, icon_y), 6, Color(0.2, 0.7, 0.2, 0.8))
						_draw_text(icon_x - 3, icon_y + 3, str(wc), 8, Color(1, 1, 1))

	# ---- HOVER TOOLTIP (QQ Farm style detail card) ----
	if hover_col >= 0 and hover_col < COLS and hover_row >= 0 and hover_row < ROWS:
		var hcell: Dictionary = farm[hover_row][hover_col]
		if not _is_cell_unlocked(hcell):
			var hsp_locked := _get_plot_position(hover_col, hover_row)
			var lx: float = hsp_locked.x
			var ly: float = hsp_locked.y
			var ltw: float = 190.0
			var lth: float = 82.0
			var ltx: float = clampf(lx - ltw * 0.5, w_min.x + 5, w_max.x - ltw - 5)
			var lty: float = clampf(ly - TH * 0.5 - lth - 18, w_min.y + 5, w_max.y - lth - 5)
			var required_level := _get_reclaim_level(hover_col, hover_row)
			var required_cost := _get_reclaim_cost(hover_col, hover_row)
			var next_locked := _get_next_locked_plot()
			_d_rect(Rect2(ltx, lty, ltw, lth), Color(0.08, 0.06, 0.03, 0.94))
			_d_rect(Rect2(ltx, lty, ltw, lth), Color(0.55, 0.42, 0.2), false, 2)
			_d_rect(Rect2(ltx, lty, ltw, 22), Color(0.34, 0.25, 0.12))
			_draw_text(ltx + 8, lty + 3, "未开垦土地", 13, Color(1.0, 0.92, 0.72))
			_draw_text(ltx + 10, lty + 31, "需要等级: " + str(required_level), 12, Color(0.86, 0.92, 1.0))
			_draw_text(ltx + 10, lty + 49, "开垦费用: " + str(required_cost) + " 金币", 12, Color(1.0, 0.84, 0.25))
			var locked_hint := "点击开垦" if next_locked.x == hover_col and next_locked.y == hover_row and level >= required_level and gold >= required_cost else ("需先开垦前一块" if next_locked.x != hover_col or next_locked.y != hover_row else "等级或金币不足")
			var locked_hint_color := Color(0.45, 0.95, 0.45) if next_locked.x == hover_col and next_locked.y == hover_row and level >= required_level and gold >= required_cost else (Color(0.95, 0.8, 0.35) if next_locked.x != hover_col or next_locked.y != hover_row else Color(0.95, 0.45, 0.35))
			_draw_text(ltx + 10, lty + 66, locked_hint, 10, locked_hint_color)
		elif hcell["crop_id"] != -1:
			var hsp := _get_plot_position(hover_col, hover_row)
			var hx: float = hsp.x
			var hy: float = hsp.y
			var hid: int = int(hcell["crop_id"])
			var hprog: float = hcell["progress"]

			# Stage info
			var stage: String
			var stage_color: Color
			if hprog >= 1.0:
				stage = "可以收获"
				stage_color = Color(1, 0.85, 0.1)
			elif hprog >= 0.7:
				stage = "即将成熟"
				stage_color = Color(0.9, 0.8, 0.2)
			elif hprog >= 0.4:
				stage = "生长中"
				stage_color = Color(0.3, 0.8, 0.3)
			elif hprog >= 0.15:
				stage = "发芽中"
				stage_color = Color(0.4, 0.75, 0.3)
			else:
				stage = "刚种下"
				stage_color = Color(0.6, 0.6, 0.6)

			var time_left: int = int((1.0 - hprog) * float(CROPS[hid][3]))
			var pct: int = int(hprog * 100)

			# Tooltip position (above the tile, clamp to screen)
			var tw: float = 170.0
			var th: float = 95.0
			var tx: float = hx - tw * 0.5
			var ty: float = hy - TH * 0.5 - th - 18
			# Clamp to visible world area
			tx = clampf(tx, w_min.x + 5, w_max.x - tw - 5)
			ty = clampf(ty, w_min.y + 5, w_max.y - th - 5)

			# Card background
			_d_rect(Rect2(tx, ty, tw, th), Color(0.08, 0.05, 0.02, 0.92))
			_d_rect(Rect2(tx, ty, tw, th), Color(0.55, 0.42, 0.2), false, 2)

			# Title bar
			_d_rect(Rect2(tx, ty, tw, 22), Color(0.4, 0.28, 0.1))
			_draw_text(tx + 6, ty + 3, str(CROPS[hid][0]), 13, Color(1, 0.95, 0.8))

			# Crop color dot
			_d_circle(Vector2(tx + 14, ty + 36), 6, CROP_COLORS[hid][1])

			# Stage
			_draw_text(tx + 26, ty + 30, stage, 11, stage_color)

			# Progress percentage
			_draw_text(tx + 26, ty + 46, str(pct) + "% 已成长", 11, Color(0.8, 0.8, 0.8))
			var land_info := _get_land_level_name(int(hcell.get("land_level", 1)))
			if int(hcell.get("land_level", 1)) < LAND_LEVEL_MAX:
				land_info += " " + str(int(hcell.get("land_work", 0))) + "/" + str(LAND_UPGRADE_WORK_REQUIRED)
			_draw_text(tx + 92, ty + 30, land_info, 10, Color(0.95, 0.82, 0.42))

			# Time / Price + action hint
			var action_hint: String
			if hprog >= 1.0:
				var harvest_y := _calc_harvest_yield(hcell, hid)
				_draw_text(tx + 26, ty + 62, "可收获: " + str(harvest_y) + "个 × " + str(int(CROPS[hid][6])) + "金", 11, Color(1, 0.88, 0.15))
				if tool_mode == 3:
					action_hint = "点击收获!"
				elif tool_mode == 4:
					action_hint = "点击铲除作物"
				else:
					action_hint = "切换到收获模式"
			else:
				_draw_text(tx + 26, ty + 62, "剩余时间: " + str(time_left) + "秒", 11, Color(0.7, 0.8, 1.0))
				var hws: int = int(hcell.get("water_state", 0))
				var hbc: int = int(hcell.get("bug_count", 0))
				var hwc: int = int(hcell.get("weed_count", 0))
				if tool_mode == 1:
					action_hint = "点击浇水" if hws == 1 else "当前不需要浇水"
				elif tool_mode == 2:
					action_hint = "点击施肥" if selected_fertilizer >= 0 else "请先购买肥料"
				elif tool_mode == 6:
					action_hint = "点击除虫 (剩余" + str(hbc) + "只)" if hbc > 0 else "这里没有虫害"
				elif tool_mode == 7:
					action_hint = "点击除草 (剩余" + str(hwc) + "棵)" if hwc > 0 else "这里没有杂草"
				elif tool_mode == 4:
					action_hint = "点击铲除作物"
				else:
					action_hint = "切换到打理工具"
			var hint_color := Color(0.4, 0.9, 0.4) if hprog >= 1.0 else Color(0.4, 0.7, 0.9)
			_draw_text(tx + 26, ty + 76, action_hint, 10, hint_color)

			# Small arrow pointing down to tile
			var arrow_x: float = clampf(hx, tx + 10, tx + tw - 10)
			var arrow_pts: PackedVector2Array = PackedVector2Array([
				Vector2(arrow_x - 6, ty + th),
				Vector2(arrow_x, ty + th + 8),
				Vector2(arrow_x + 6, ty + th),
			])
			_d_colored_polygon(arrow_pts, Color(0.08, 0.05, 0.02, 0.92))
		else:
			_draw_land_tooltip(hover_col, hover_row)

# ---- 以下 UI 固定在屏幕上，不受 Camera 影响 ----
# 被 UIOverlay._draw() 调用，caller 是 UIOverlay 节点（CanvasLayer 子节点）
func _draw_ui(caller: CanvasItem):
	_ui_draw_target = caller
	var vp: Vector2 = get_viewport().get_visible_rect().size
	# ---- TOOL BAR (地块下方图标按钮) ----
	var tb_names := ["普通", "浇水", "施肥", "收获", "铲除", "全铲", "除虫", "除草", "全收", "仓库"]
	var tb_colors := [
		Color(0.5, 0.47, 0.42), Color(0.22, 0.52, 0.88), Color(0.78, 0.58, 0.12),
		Color(0.22, 0.72, 0.32), Color(0.64, 0.38, 0.22), Color(0.64, 0.38, 0.22),
		Color(0.75, 0.22, 0.22), Color(0.22, 0.72, 0.32), Color(0.78, 0.58, 0.12),
		Color(0.4, 0.42, 0.5),
	]
	var tb_dark := [
		Color(0.35, 0.32, 0.28), Color(0.14, 0.38, 0.68), Color(0.58, 0.4, 0.06),
		Color(0.14, 0.52, 0.2), Color(0.42, 0.24, 0.14), Color(0.42, 0.24, 0.14),
		Color(0.52, 0.14, 0.14), Color(0.14, 0.52, 0.2), Color(0.58, 0.4, 0.06),
		Color(0.28, 0.3, 0.36),
	]
	var btn_size: float = 58.0
	var btn_gap: float = 8.0
	var tb_total: float = 10.0 * btn_size + 9.0 * btn_gap
	var tb_start_x: float = vp.x * 0.5 - tb_total * 0.5
	var tb_y: float = vp.y * 0.8

	if TOOLBAR_BG_TEXTURE != null:
		var bg_w: float = tb_total + 140.0
		var bg_h: float = btn_size + 80.0
		var bg_rect := Rect2(tb_start_x - 70.0, tb_y - 30.0, bg_w, bg_h)
		
		var tex_size := TOOLBAR_BG_TEXTURE.get_size()
		var left_m := 80.0
		var right_m := 80.0
		var scale_y := bg_h / maxf(tex_size.y, 1.0)
		var draw_l := left_m * scale_y
		var draw_r := right_m * scale_y
		
		_ui_draw_target.draw_texture_rect_region(TOOLBAR_BG_TEXTURE, Rect2(bg_rect.position.x, bg_rect.position.y, draw_l, bg_h), Rect2(0, 0, left_m, tex_size.y))
		_ui_draw_target.draw_texture_rect_region(TOOLBAR_BG_TEXTURE, Rect2(bg_rect.position.x + draw_l, bg_rect.position.y, bg_rect.size.x - draw_l - draw_r, bg_h), Rect2(left_m, 0, tex_size.x - left_m - right_m, tex_size.y))
		_ui_draw_target.draw_texture_rect_region(TOOLBAR_BG_TEXTURE, Rect2(bg_rect.position.x + bg_rect.size.x - draw_r, bg_rect.position.y, draw_r, bg_h), Rect2(tex_size.x - right_m, 0, right_m, tex_size.y))

	for ti in range(10):
		var bx: float = tb_start_x + ti * (btn_size + btn_gap)
		var by: float = tb_y

		var is_active: bool = (tool_mode == ti)

		# ---- Draw icon in each button ----
		var icon_cx: float = bx + btn_size * 0.5
		var icon_cy: float = by + btn_size * 0.35
		var icon_texture: Texture2D = TOOL_ICON_TEXTURES[ti]
		if icon_texture != null:
			var icon_grow := 4.0 if is_active else 0.0
			var icon_rect := Rect2(bx - icon_grow * 0.5, by - icon_grow * 0.5, btn_size + icon_grow, btn_size + icon_grow)
			if is_active:
				_d_circle(Vector2(icon_cx, by + btn_size * 0.48), 38.0, Color(1.0, 0.86, 0.22, 0.18))
				_d_circle(Vector2(icon_cx, by + btn_size * 0.48), 30.0, Color(1.0, 0.96, 0.42, 0.10))
			_d_texture_rect(icon_texture, icon_rect, false)
			var txt_col: Color = Color(1.0, 0.92, 0.34, 0.98) if is_active else Color(0.78, 0.78, 0.78)
			var label_w: float = (_cn_font if _cn_font != null else ThemeDB.fallback_font).get_string_size(tb_names[ti], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			_draw_text(icon_cx - label_w * 0.5, by + btn_size + 1.0, tb_names[ti], 12, txt_col)
			if is_active:
				_d_line(Vector2(icon_cx - 15.0, by + btn_size + 17.0), Vector2(icon_cx + 15.0, by + btn_size + 17.0), Color(1.0, 0.86, 0.22, 0.95), 3.0)
			continue

		if ti == 0:
			# 普通 - 鼠标箭头
			var arrow: PackedVector2Array = PackedVector2Array([
				Vector2(icon_cx - 6, icon_cy - 10),
				Vector2(icon_cx - 6, icon_cy + 8),
				Vector2(icon_cx - 1, icon_cy + 4),
				Vector2(icon_cx + 4, icon_cy + 10),
				Vector2(icon_cx + 7, icon_cy + 8),
				Vector2(icon_cx + 2, icon_cy + 2),
				Vector2(icon_cx + 8, icon_cy - 2),
			])
			_d_colored_polygon(arrow, Color(1, 1, 1, 0.9))

		elif ti == 1:
			# 浇水 - 水壶
			_d_rect(Rect2(icon_cx - 8, icon_cy - 4, 16, 10), Color(0.6, 0.75, 0.9))
			_d_rect(Rect2(icon_cx - 8, icon_cy - 4, 16, 10), Color(0.3, 0.5, 0.8), false, 1.5)
			# 壶嘴
			_d_line(Vector2(icon_cx + 8, icon_cy - 4), Vector2(icon_cx + 14, icon_cy - 10), Color(0.3, 0.5, 0.8), 2.0)
			# 水滴
			_d_circle(Vector2(icon_cx + 10, icon_cy - 14), 2.5, Color(0.3, 0.6, 1.0))
			_d_circle(Vector2(icon_cx + 5, icon_cy - 16), 2.0, Color(0.3, 0.6, 1.0))
			# 把手
			_d_arc(Vector2(icon_cx - 2, icon_cy - 8), 6, 0, PI, 12, Color(0.3, 0.5, 0.8), 2.0)

		elif ti == 2:
			# 施肥 - 袋子
			var bag_body: PackedVector2Array = PackedVector2Array([
				Vector2(icon_cx - 11, icon_cy - 7),
				Vector2(icon_cx + 11, icon_cy - 7),
				Vector2(icon_cx + 9, icon_cy + 12),
				Vector2(icon_cx - 9, icon_cy + 12),
			])
			_d_colored_polygon(bag_body, Color(0.68, 0.52, 0.23))
			for bi in range(4):
				_d_line(bag_body[bi], bag_body[(bi + 1) % 4], Color(0.42, 0.28, 0.08), 1.5)
			_d_line(Vector2(icon_cx - 6, icon_cy - 8), Vector2(icon_cx + 6, icon_cy - 8), Color(0.32, 0.22, 0.08), 2.0)
			_draw_text(icon_cx - 6, icon_cy - 2, "肥", 11, Color(1, 0.92, 0.55))
			_d_circle(Vector2(icon_cx - 15, icon_cy + 12), 2.0, Color(0.9, 0.75, 0.25))
			_d_circle(Vector2(icon_cx + 14, icon_cy + 10), 1.8, Color(0.9, 0.75, 0.25))

		elif ti == 3:
			# 收获 - 篮子
			# 篮身 (梯形)
			var basket: PackedVector2Array = PackedVector2Array([
				Vector2(icon_cx - 10, icon_cy - 4),
				Vector2(icon_cx + 10, icon_cy - 4),
				Vector2(icon_cx + 8, icon_cy + 8),
				Vector2(icon_cx - 8, icon_cy + 8),
			])
			_d_colored_polygon(basket, Color(0.7, 0.55, 0.25))
			# 提手
			_d_arc(Vector2(icon_cx, icon_cy - 10), 8, PI, TAU, 12, Color(0.45, 0.32, 0.1), 2.0)
			# 里面的小果子
			_d_circle(Vector2(icon_cx - 3, icon_cy), 2.5, Color(0.9, 0.2, 0.15))
			_d_circle(Vector2(icon_cx + 3, icon_cy - 1), 2.5, Color(1.0, 0.6, 0.1))
			_d_circle(Vector2(icon_cx, icon_cy - 5), 2.4, Color(0.95, 0.92, 0.2))

		elif ti == 4:
			# 铲除 - 铲子
			_d_line(Vector2(icon_cx + 8, icon_cy - 16), Vector2(icon_cx - 8, icon_cy + 7), Color(0.92, 0.74, 0.42), 4.0)
			_d_line(Vector2(icon_cx + 8, icon_cy - 16), Vector2(icon_cx - 8, icon_cy + 7), Color(0.42, 0.24, 0.12), 1.2)
			var blade: PackedVector2Array = PackedVector2Array([
				Vector2(icon_cx - 14, icon_cy + 7),
				Vector2(icon_cx - 3, icon_cy + 2),
				Vector2(icon_cx + 3, icon_cy + 12),
				Vector2(icon_cx - 5, icon_cy + 19),
			])
			_d_colored_polygon(blade, Color(0.78, 0.84, 0.86))
			for si in range(4):
				_d_line(blade[si], blade[(si + 1) % 4], Color(0.38, 0.42, 0.44), 1.4)
			_d_line(Vector2(icon_cx + 5, icon_cy - 19), Vector2(icon_cx + 16, icon_cy - 13), Color(0.42, 0.24, 0.12), 3.0)

		# Tool name below icon
		var txt_col: Color = Color(1, 1, 1, 0.95) if is_active else Color(0.7, 0.7, 0.7)
		_draw_text(bx + 14, by + btn_size - 6, tb_names[ti], 12, txt_col)

	# ---- TOP HUD (left) ----
	_d_rect(Rect2(8, 6, 280, 48), Color(0.08, 0.06, 0.02, 0.82))
	_d_rect(Rect2(8, 6, 280, 48), Color(0.45, 0.35, 0.15), false, 2)
	_draw_text(18, 10, "金币: " + str(gold), 18, Color(1, 0.88, 0.15))
	_draw_text(150, 12, "Lv." + str(level), 16, Color(0.8, 0.9, 1.0))
	# Exp bar
	_d_rect(Rect2(18, 34, 180, 10), Color(0.1, 0.1, 0.15))
	var ep: float = float(exp_val) / float(exp_to_level) if exp_to_level > 0 else 0.0
	_d_rect(Rect2(18, 34, 180.0 * ep, 10), Color(0.25, 0.5, 1.0))
	_draw_text(202, 32, str(exp_val) + "/" + str(exp_to_level), 10, Color(0.65, 0.75, 1))
	# Land count
	var unlocked_count := _get_unlocked_plot_count()
	_draw_text(150, 32, "地:" + str(unlocked_count) + "/30", 10, Color(0.7, 0.65, 0.5))

	if reclaim_confirm_open:
		_draw_reclaim_confirm()

	if shovel_all_confirm_open:
		_draw_shovel_all_confirm()

	if reset_confirm_open:
		_draw_reset_confirm()

	if toast_text != "":
		var alpha := minf(toast_timer, 1.0)
		var f: Font = _cn_font if _cn_font != null else ThemeDB.fallback_font
		var tw: float = f.get_string_size(toast_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 50
		var tx: float = (vp.x - tw) * 0.5
		_d_rect(Rect2(tx, vp.y - 50, tw, 38), Color(0, 0, 0, 0.8 * alpha))
		_draw_text(tx + 25, vp.y - 43, toast_text, 18, Color(1, 1, 1, alpha))

	_draw_context_menu_overlay(vp)
	_draw_input_debug_overlay(vp)

	_ui_draw_target = null

func _draw_context_menu_overlay(vp: Vector2):
	if not ctx_menu_open: return
	
	var wp := _get_plot_position(ctx_col, ctx_row)
	var vp_pos = (wp - cam.position) * cam.zoom + vp * 0.5
	var menu_w = ctx_menu_items.size() * 50 + 10
	var menu_rect = Rect2(vp_pos.x - menu_w * 0.5, vp_pos.y - 80, menu_w, 60)
	
	# 画胶囊形状的半透明黑底
	var r = 30.0
	_d_circle(Vector2(menu_rect.position.x + r, menu_rect.position.y + r), r, Color(0, 0, 0, 0.65))
	_d_circle(Vector2(menu_rect.position.x + menu_w - r, menu_rect.position.y + r), r, Color(0, 0, 0, 0.65))
	_d_rect(Rect2(menu_rect.position.x + r, menu_rect.position.y, menu_w - 2 * r, 60), Color(0, 0, 0, 0.65))
	
	# 画小箭头指引到地块
	var arrow_pts: PackedVector2Array = PackedVector2Array([
		Vector2(vp_pos.x - 8, menu_rect.position.y + 60),
		Vector2(vp_pos.x, menu_rect.position.y + 68),
		Vector2(vp_pos.x + 8, menu_rect.position.y + 60),
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

func _draw_input_debug_overlay(vp: Vector2):
	var marker := _debug_last_input_viewport
	if marker == Vector2.ZERO and _debug_last_input_raw == Vector2.ZERO:
		return

	var debug_x := 18.0
	var debug_y := vp.y - 78.0
	_d_rect(Rect2(debug_x, debug_y, 200, 64), Color(0.04, 0.04, 0.04, 0.7))
	_draw_text(debug_x + 6, debug_y + 6, "vp=" + str(_debug_last_input_viewport), 9, Color(1, 1, 1))
	_draw_text(debug_x + 6, debug_y + 20, "world=" + str(_debug_last_input_world), 9, Color(1, 1, 1))
	_draw_text(debug_x + 6, debug_y + 34, "tool=" + str(_debug_last_toolbar_hit), 9, Color(1, 0.9, 0.3))
	_draw_text(debug_x + 6, debug_y + 48, "tile=" + str(_debug_last_tile_hit), 9, Color(0.5, 1.0, 0.5))

	if _debug_last_toolbar_hit >= 0:
		var btn_size: float = 58.0
		var btn_gap: float = 8.0
		var tb_total: float = 10.0 * btn_size + 9.0 * btn_gap
		var tb_start_x: float = vp.x * 0.5 - tb_total * 0.5
		var tb_y: float = vp.y * 0.8
		var bx: float = tb_start_x + _debug_last_toolbar_hit * (btn_size + btn_gap)
		_d_rect(Rect2(bx, tb_y, btn_size, btn_size), Color(1.0, 0.25, 0.25, 0.0), false, 3.0)

	if _debug_last_tile_hit.x >= 0 and _debug_last_tile_hit.y >= 0:
		var sp := _get_plot_position(_debug_last_tile_hit.x, _debug_last_tile_hit.y)
		var corners := iso_visual_corners(sp.x, sp.y)
		# 世界坐标 → 屏幕坐标（CanvasLayer 绘制在屏幕坐标系）
		var ct := get_viewport().get_canvas_transform()
		for i in range(corners.size()):
			var a: Vector2 = ct * corners[i]
			var b: Vector2 = ct * corners[(i + 1) % corners.size()]
			_d_line(a, b, Color(0.2, 1.0, 0.2, 0.95), 3.0)

func _draw_reclaim_confirm():
	var rect := _get_reclaim_confirm_rect()
	var col := reclaim_confirm_col
	var row := reclaim_confirm_row
	if col < 0 or row < 0:
		return
	var required_level := _get_reclaim_level(col, row)
	var required_cost := _get_reclaim_cost(col, row)
	var plot_no := _get_plot_index(col, row) + 1
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_d_rect(Rect2(0, 0, vp.x, vp.y), Color(0, 0, 0, 0.62))
	_d_rect(rect, Color(0.94, 0.9, 0.78))
	_d_rect(rect, Color(0.48, 0.32, 0.12), false, 4)
	_d_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 30), Color(0.42, 0.28, 0.08))
	_draw_text(rect.position.x + 116, rect.position.y + 5, "确认开垦土地", 18, Color(1, 0.95, 0.82))
	_draw_text(rect.position.x + 30, rect.position.y + 50, "第 " + str(plot_no) + " 块地", 16, Color(0.18, 0.14, 0.1))
	_draw_text(rect.position.x + 30, rect.position.y + 76, "需要等级: " + str(required_level), 14, Color(0.2, 0.24, 0.42))
	_draw_text(rect.position.x + 30, rect.position.y + 102, "开垦费用: " + str(required_cost) + " 金币", 14, Color(0.75, 0.3, 0.05))
	_draw_text(rect.position.x + 30, rect.position.y + 128, "确认花费金币开垦这块土地吗？", 14, Color(0.28, 0.22, 0.18))
	var cancel_rect := Rect2(rect.position.x + 40, rect.position.y + 145, 130, 34)
	var confirm_rect := Rect2(rect.position.x + rect.size.x - 170, rect.position.y + 145, 130, 34)
	_d_rect(cancel_rect, Color(0.55, 0.42, 0.28))
	_d_rect(confirm_rect, Color(0.22, 0.62, 0.28))
	_draw_text(cancel_rect.position.x + 44, cancel_rect.position.y + 7, "取消", 16, Color(1, 1, 1))
	_draw_text(confirm_rect.position.x + 44, confirm_rect.position.y + 7, "确认", 16, Color(1, 1, 1))

func _draw_reset_confirm():
	var rect := _get_reset_confirm_rect()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_d_rect(Rect2(0, 0, vp.x, vp.y), Color(0, 0, 0, 0.68))
	_d_rect(rect, Color(0.9, 0.86, 0.94))
	_d_rect(rect, Color(0.4, 0.18, 0.45), false, 4)
	_d_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 30), Color(0.35, 0.15, 0.4))
	_draw_text(rect.position.x + 142, rect.position.y + 5, "确认重置农场", 18, Color(1, 0.92, 0.98))
	_draw_text(rect.position.x + 28, rect.position.y + 52, "这会清空当前存档中的金币、等级、土地、作物和背包数据。", 14, Color(0.22, 0.12, 0.3))
	_draw_text(rect.position.x + 28, rect.position.y + 80, "重置后会立即覆盖旧存档，重新进入游戏也不会恢复。", 14, Color(0.45, 0.2, 0.3))
	_draw_text(rect.position.x + 28, rect.position.y + 112, "确认要新开档吗？", 15, Color(0.55, 0.18, 0.18))
	var cancel_rect := Rect2(rect.position.x + 50, rect.position.y + 165, 150, 36)
	var confirm_rect := Rect2(rect.position.x + rect.size.x - 200, rect.position.y + 165, 150, 36)
	_d_rect(cancel_rect, Color(0.55, 0.42, 0.55))
	_d_rect(confirm_rect, Color(0.75, 0.22, 0.18))
	_draw_text(cancel_rect.position.x + 52, cancel_rect.position.y + 8, "取消", 16, Color(1, 1, 1))
	_draw_text(confirm_rect.position.x + 34, confirm_rect.position.y + 8, "确认重置", 16, Color(1, 1, 1))


func _draw_shovel_all_confirm():
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var rect := Rect2(vp.x * 0.5 - 200, vp.y * 0.5 - 80, 400, 160)
	_d_rect(Rect2(0, 0, vp.x, vp.y), Color(0, 0, 0, 0.62))
	_d_rect(rect, Color(0.94, 0.9, 0.78))
	_d_rect(rect, Color(0.48, 0.32, 0.12), false, 4)
	_d_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 30), Color(0.55, 0.24, 0.14))
	_draw_text(rect.position.x + 120, rect.position.y + 5, "确认铲除全部作物?", 18, Color(1, 0.95, 0.82))
	_draw_text(rect.position.x + 30, rect.position.y + 50, "这将铲除所有地块上的作物，且不可恢复。", 14, Color(0.28, 0.22, 0.18))
	var cancel_rect := Rect2(rect.position.x + 40, rect.position.y + 110, 130, 30)
	var confirm_rect := Rect2(rect.position.x + rect.size.x - 170, rect.position.y + 110, 130, 30)
	_d_rect(cancel_rect, Color(0.55, 0.42, 0.28))
	_d_rect(confirm_rect, Color(0.75, 0.22, 0.18))
	_draw_text(cancel_rect.position.x + 44, cancel_rect.position.y + 4, "取消", 16, Color(1, 1, 1))
	_draw_text(confirm_rect.position.x + 44, confirm_rect.position.y + 4, "确认铲除", 16, Color(1, 1, 1))

func _draw_warehouse_overlay():
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var ww := 360.0; var wh := 300.0
	var wx := (vp.x - ww) / 2; var wy := (vp.y - wh) / 2
	_d_rect(Rect2(0, 0, vp.x, vp.y), Color(0, 0, 0, 0.55))
	_d_rect(Rect2(wx, wy, ww, wh), Color(0.16, 0.14, 0.11))
	_d_rect(Rect2(wx, wy, ww, wh), Color(0.45, 0.38, 0.22), false, 3)
	_d_rect(Rect2(wx, wy, ww, 36), Color(0.3, 0.26, 0.16))
	_draw_text(wx + 140, wy + 8, "仓库", 20, Color(1, 0.92, 0.75))
	_draw_text(wx + ww - 80, wy + 10, "点外部关闭", 12, Color(0.6, 0.55, 0.4))
	var keys = inventory.keys()
	var item_count := 0
	var iy := wy + 48
	for cid in keys:
		if inventory.has(cid) and inventory[cid] > 0:
			_draw_text(wx + 20, iy, str(CROPS[int(cid)][0]) + " x" + str(inventory[cid]), 14, Color(0.8, 0.75, 0.6))
			iy += 24
			item_count += 1
	if item_count == 0:
		_draw_text(wx + 120, wy + 120, "仓库是空的", 18, Color(0.5, 0.45, 0.35))
func _draw_settings_overlay():
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var sw := 360.0; var sh := 280.0
	var sx := (vp.x - sw) / 2; var sy := (vp.y - sh) / 2
	_d_rect(Rect2(0, 0, vp.x, vp.y), Color(0, 0, 0, 0.55))
	_d_rect(Rect2(sx, sy, sw, sh), Color(0.16, 0.14, 0.11))
	_d_rect(Rect2(sx, sy, sw, sh), Color(0.45, 0.38, 0.22), false, 3)
	# Title bar
	_d_rect(Rect2(sx, sy, sw, 36), Color(0.3, 0.26, 0.16))
	_draw_text(sx + 140, sy + 8, "设置", 20, Color(1, 0.92, 0.75))
	# Close hint
	_draw_text(sx + sw - 80, sy + 10, "点外部关闭", 12, Color(0.6, 0.55, 0.4))
	# 退出登录 button
	var btn_w := 260.0; var btn_h := 38.0
	var bx := sx + (sw - btn_w) / 2
	_d_rect(Rect2(bx, sy + 80, btn_w, btn_h), Color(0.3, 0.45, 0.65))
	_draw_text(bx + 80, sy + 88, "退出登录", 18, Color(1, 1, 1))
	# 重置农场 button
	_d_rect(Rect2(bx, sy + 140, btn_w, btn_h), Color(0.72, 0.24, 0.2))
	_draw_text(bx + 68, sy + 148, "重置农场/新开档", 18, Color(1, 1, 1))
	# Warning text
	_draw_text(bx + 8, sy + 200, "重置会清空所有游戏数据，不可恢复", 12, Color(0.65, 0.4, 0.35))
	# Token info
	if not auth_token.is_empty():
		var uname: String = user_info.get("username", "???")
		_draw_text(bx + 8, sy + 240, "当前账号: " + uname, 13, Color(0.55, 0.55, 0.5))

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
	if prog < 0.18:
		return -1
	if prog < 0.45:
		return 0
	if prog < 0.72:
		return 1
	if prog < 0.9:
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
