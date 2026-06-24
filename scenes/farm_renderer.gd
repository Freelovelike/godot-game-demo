extends RefCounted

const CropAtlas = preload("res://scripts/crop_atlas.gd")

## World renderer for Farm.gd. It owns the isometric world draw pass while
## Farm.gd keeps server state, input intent dispatch, and low-level draw helpers.

static func draw_world(render_ctx: Dictionary) -> void:
	var draw_api = render_ctx["draw_api"]
	var state: FarmState = render_ctx["state"]
	var farm: Array = state.farm
	var ROWS: int = int(render_ctx["rows"])
	var COLS: int = int(render_ctx["cols"])
	var TW: float = float(render_ctx["tile_width"])
	var TH: float = float(render_ctx["tile_height"])
	var tile_gap: float = float(render_ctx["tile_gap"])
	var LAND_LEVEL_MAX: int = int(render_ctx["land_level_max"])
	var LAND_UPGRADE_WORK_REQUIRED: int = int(render_ctx["land_upgrade_work_required"])
	var crop_catalog: CropCatalog = render_ctx["crop_catalog"]
	var CROP_COLORS: Array = render_ctx["crop_colors"]
	var render_stage_thresholds: Array = render_ctx["render_stage_thresholds"]
	var land_textures: Dictionary = render_ctx["land_textures"]
	var land_texture_source_rects: Dictionary = render_ctx["land_texture_source_rects"]
	var land_texture_avg_colors: Dictionary = render_ctx["land_texture_avg_colors"]
	var plot_positions: Array = render_ctx["plot_positions"]
	var hover: Vector2i = render_ctx["hover"]
	var context_tile: Vector2i = render_ctx["context_tile"]
	var hover_col: int = hover.x
	var hover_row: int = hover.y
	var ctx_menu_open: bool = bool(render_ctx["context_menu_open"])
	var ctx_col: int = context_tile.x
	var ctx_row: int = context_tile.y
	var selected_seed: int = int(render_ctx["selected_seed"])
	var selected_fertilizer: int = int(render_ctx["selected_fertilizer"])
	var tool_mode: int = int(render_ctx["tool_mode"])
	var level: int = int(render_ctx["level"])
	var gold: int = int(render_ctx["gold"])
	var server_time: float = float(render_ctx["server_time"])
	var sign_texture: Texture2D = render_ctx["sign_texture"]
	var cn_font: Font = render_ctx["font"]
	var vp: Vector2 = render_ctx["viewport_size"]
	var ctrans: Transform2D = render_ctx["canvas_transform"]
	var can_show_tooltip: bool = bool(render_ctx["can_show_tooltip"])
	var w_min: Vector2 = ctrans.affine_inverse() * Vector2.ZERO
	var w_max: Vector2 = ctrans.affine_inverse() * vp
	draw_api._d_rect(Rect2(100, 40, 440, 40), Color(0.1, 0.06, 0.02, 0.85))
	draw_api._draw_text(200, 46, "QQ 农场 2.5D", 24, Color(1, 0.9, 0.2))

	if farm.size() < ROWS:
		return
	for row in range(ROWS):
		if farm[row].size() < COLS:
			return
		for col in range(COLS):
			var sp: Vector2 = _get_plot_position(plot_positions, col, row)
			var cx: float = sp.x
			var cy: float = sp.y
			var vcorners: PackedVector2Array = _iso_visual_corners(cx, cy, TW, TH, tile_gap)
			var cell: Dictionary = farm[row][col]
			_draw_land_tile(draw_api, state, TW, TH, tile_gap, vcorners, cell, land_textures, land_texture_source_rects, land_texture_avg_colors)

			if (col == hover_col and row == hover_row) or (ctx_menu_open and col == ctx_col and row == ctx_row):
				if not state.is_cell_unlocked(cell):
					draw_api._d_colored_polygon(vcorners, Color(0.75, 0.75, 0.75, 0.22))
				elif cell["crop_id"] == -1 and selected_seed >= 0:
					draw_api._d_colored_polygon(vcorners, Color(0.3, 0.9, 0.3, 0.25))
				elif cell["crop_id"] != -1 and cell["progress"] >= 1.0:
					draw_api._d_colored_polygon(vcorners, Color(1.0, 0.85, 0.15, 0.35))
				else:
					draw_api._d_colored_polygon(vcorners, Color(1, 1, 1, 0.1))

			if (col == hover_col and row == hover_row) or (ctx_menu_open and col == ctx_col and row == ctx_row):
				var bcol := Color(1, 0.9, 0.2, 0.9)
				for i in range(4):
					draw_api._d_line(vcorners[i], vcorners[(i + 1) % 4], bcol, 2.0)

			if state.is_cell_unlocked(cell) and cell["crop_id"] == -1 and col == hover_col and row == hover_row and selected_seed >= 0:
				var seed_texture: Texture2D = _get_crop_seed_texture(crop_catalog, selected_seed)
				if seed_texture != null:
					_draw_seed_preview_texture(draw_api, cx, cy, seed_texture)
				else:
					var seed_color := _crop_color(CROP_COLORS, selected_seed, 1)
					draw_api._d_circle(Vector2(cx, cy), 10, Color(seed_color.r, seed_color.g, seed_color.b, 0.7))
					draw_api._d_circle(Vector2(cx, cy), 6, seed_color)

	for row in range(ROWS):
		if farm[row].size() < COLS:
			return
		for col in range(COLS):
			var sp: Vector2 = _get_plot_position(plot_positions, col, row)
			var cx: float = sp.x
			var cy: float = sp.y
			var cell: Dictionary = farm[row][col]

			if not state.is_cell_unlocked(cell):
				var req_level: int = state.get_reclaim_level(col, row)
				var req_cost: int = state.get_reclaim_cost(col, row)
				var next_locked: Vector2i = state.get_next_locked_plot()
				var is_next: bool = next_locked.x == col and next_locked.y == row
				if is_next and sign_texture != null:
					var can: bool = level >= req_level and gold >= req_cost
					var sign_color := Color(0.2, 0.8, 0.25) if can else Color(0.85, 0.25, 0.2)
					var sign_label := "可解锁" if can else "Lv." + str(req_level) + "解锁"
					_draw_sign(draw_api, sign_texture, cn_font, TW, cx, cy, sign_color, sign_label, can)
				else:
					var lock_text := "Lv" + str(req_level)
					var f_lock: Font = cn_font if cn_font != null else ThemeDB.fallback_font
					var lock_w: float = f_lock.get_string_size(lock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
					draw_api._d_rect(Rect2(cx - lock_w * 0.5 - 6, cy - 10, lock_w + 12, 18), Color(0.02, 0.02, 0.02, 0.68))
					draw_api._draw_text(cx - lock_w * 0.5, cy - 8, lock_text, 12, Color(0.92, 0.9, 0.78, 0.95))
					if col == hover_col and row == hover_row:
						var cost_text := str(req_cost) + " 金币开垦"
						var cost_w: float = f_lock.get_string_size(cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
						draw_api._d_rect(Rect2(cx - cost_w * 0.5 - 6, cy + 12, cost_w + 12, 17), Color(0.02, 0.02, 0.02, 0.72))
						draw_api._draw_text(cx - cost_w * 0.5, cy + 13, cost_text, 11, Color(1.0, 0.82, 0.26, 0.95))
				continue

			if cell["crop_id"] != -1:
				var cid: int = int(cell["crop_id"])
				var prog: float = float(cell.get("visual_progress", cell.get("progress", 0.0)))
				var server_prog := clampf(float(cell.get("progress", 0.0)), 0.0, 1.0)
				var fruit_col: Color = _crop_color(CROP_COLORS, cid, 1)
				var leaf_col: Color = _crop_color(CROP_COLORS, cid, 0)
				var stage: int = _get_growth_stage(prog, render_stage_thresholds)
				var atlas_texture: Texture2D = _get_crop_stage_texture(crop_catalog, cid, stage)

				if stage < 0:
					_draw_plant_seed(draw_api, cx, cy, prog)
				elif atlas_texture != null:
					_draw_crop_atlas_texture(draw_api, crop_catalog, TW, cx, cy, atlas_texture, cid, stage)
				elif prog > 0.3:
					_draw_plant_growing(draw_api, cx, cy, leaf_col, prog)
				else:
					_draw_plant_seed(draw_api, cx, cy, prog)

				if server_prog >= 1.0:
					if atlas_texture == null:
						_draw_plant_full(draw_api, cx, cy, leaf_col, fruit_col)
					var f: Font = cn_font if cn_font != null else ThemeDB.fallback_font
					var lbl := "收获"
					var lw: float = f.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
					draw_api._d_rect(Rect2(cx - lw * 0.5 - 4, cy - TH * 0.5 - 22, lw + 8, 16), Color(0.8, 0.6, 0, 0.85))
					draw_api._draw_text(cx - lw * 0.5, cy - TH * 0.5 - 19, lbl, 11, Color(1, 1, 1))

				if prog < 1.0:
					var bw: float = TW * 0.5
					var bx: float = cx - bw * 0.5
					var by: float = cy + TH * 0.35
					draw_api._d_rect(Rect2(bx, by, bw, 5), Color(0, 0, 0, 0.5))
					var bc := Color(0.2, 0.8, 0.3) if prog < 0.6 else Color(0.95, 0.75, 0.1)
					draw_api._d_rect(Rect2(bx, by, bw * prog, 5), bc)
					var stage_name: String
					var remaining: int = _remaining_seconds(cell, server_time, prog, crop_catalog.get_grow_time(cid))
					if prog < 0.15:
						stage_name = "种子"
					elif prog < 0.4:
						stage_name = "发芽"
					elif prog < 0.7:
						stage_name = "生长"
					else:
						stage_name = "快熟"
					draw_api._draw_text(cx - 20, cy + TH * 0.5 + 14, stage_name + " " + str(remaining) + "秒", 9, Color(1, 1, 1, 0.75))
				else:
					var yield_hint := "产量 " + str(crop_catalog.get_base_yield(cid)) + "~" + str(crop_catalog.get_max_yield(cid))
					draw_api._draw_text(cx - 20, cy + TH * 0.5 + 14, yield_hint, 9, Color(1, 0.9, 0.3, 0.8))

				if prog < 1.0:
					var icon_y := cy - TH * 0.5 - 8
					var icon_x := cx + 12
					var ws: int = int(cell.get("water_state", 0))
					var bug_count: int = int(cell.get("bug_count", 0))
					var weed_count: int = int(cell.get("weed_count", 0))
					if ws == 1:
						draw_api._d_circle(Vector2(icon_x, icon_y), 6, Color(0.2, 0.5, 0.9, 0.8))
						draw_api._draw_text(icon_x - 3, icon_y + 3, "渴", 8, Color(1, 1, 1))
						icon_x -= 16
					if bug_count > 0:
						draw_api._d_circle(Vector2(icon_x, icon_y), 6, Color(0.9, 0.2, 0.2, 0.8))
						draw_api._draw_text(icon_x - 3, icon_y + 3, str(bug_count), 8, Color(1, 1, 1))
						icon_x -= 16
					if weed_count > 0:
						draw_api._d_circle(Vector2(icon_x, icon_y), 6, Color(0.2, 0.7, 0.2, 0.8))
						draw_api._draw_text(icon_x - 3, icon_y + 3, str(weed_count), 8, Color(1, 1, 1))

	if can_show_tooltip and hover_col >= 0 and hover_col < COLS and hover_row >= 0 and hover_row < ROWS:
		var hcell: Dictionary = farm[hover_row][hover_col]
		if not state.is_cell_unlocked(hcell):
			_draw_locked_tooltip(draw_api, state, plot_positions, hover_col, hover_row, w_min, w_max, TH, level, gold)
		elif hcell["crop_id"] != -1:
			_draw_crop_tooltip(draw_api, plot_positions, hcell, hover_col, hover_row, w_min, w_max, TH, crop_catalog, CROP_COLORS, LAND_LEVEL_MAX, LAND_UPGRADE_WORK_REQUIRED, tool_mode, selected_fertilizer)
		else:
			_draw_land_tooltip(draw_api, plot_positions, hcell, hover_col, hover_row, w_min, w_max, TH, LAND_LEVEL_MAX, LAND_UPGRADE_WORK_REQUIRED)

static func _draw_locked_tooltip(draw_api, state: FarmState, plot_positions: Array, hover_col: int, hover_row: int, w_min: Vector2, w_max: Vector2, TH: float, level: int, gold: int) -> void:
	var hsp_locked: Vector2 = _get_plot_position(plot_positions, hover_col, hover_row)
	var ltw: float = 190.0
	var lth: float = 82.0
	var ltx: float = clampf(hsp_locked.x - ltw * 0.5, w_min.x + 5, w_max.x - ltw - 5)
	var lty: float = clampf(hsp_locked.y - TH * 0.5 - lth - 18, w_min.y + 5, w_max.y - lth - 5)
	var required_level: int = state.get_reclaim_level(hover_col, hover_row)
	var required_cost: int = state.get_reclaim_cost(hover_col, hover_row)
	var next_locked: Vector2i = state.get_next_locked_plot()
	draw_api._d_rect(Rect2(ltx, lty, ltw, lth), Color(0.08, 0.06, 0.03, 0.94))
	draw_api._d_rect(Rect2(ltx, lty, ltw, lth), Color(0.55, 0.42, 0.2), false, 2)
	draw_api._d_rect(Rect2(ltx, lty, ltw, 22), Color(0.34, 0.25, 0.12))
	draw_api._draw_text(ltx + 8, lty + 3, "未开垦土地", 13, Color(1.0, 0.92, 0.72))
	draw_api._draw_text(ltx + 10, lty + 31, "需要等级: " + str(required_level), 12, Color(0.86, 0.92, 1.0))
	draw_api._draw_text(ltx + 10, lty + 49, "开垦费用: " + str(required_cost) + " 金币", 12, Color(1.0, 0.84, 0.25))
	var locked_hint := "点击开垦" if next_locked.x == hover_col and next_locked.y == hover_row and level >= required_level and gold >= required_cost else ("需先开垦前一块" if next_locked.x != hover_col or next_locked.y != hover_row else "等级或金币不足")
	var locked_hint_color := Color(0.45, 0.95, 0.45) if next_locked.x == hover_col and next_locked.y == hover_row and level >= required_level and gold >= required_cost else (Color(0.95, 0.8, 0.35) if next_locked.x != hover_col or next_locked.y != hover_row else Color(0.95, 0.45, 0.35))
	draw_api._draw_text(ltx + 10, lty + 66, locked_hint, 10, locked_hint_color)

static func _draw_crop_tooltip(draw_api, plot_positions: Array, hcell: Dictionary, hover_col: int, hover_row: int, w_min: Vector2, w_max: Vector2, TH: float, crop_catalog: CropCatalog, CROP_COLORS: Array, LAND_LEVEL_MAX: int, LAND_UPGRADE_WORK_REQUIRED: int, tool_mode: int, selected_fertilizer: int) -> void:
	var hsp: Vector2 = _get_plot_position(plot_positions, hover_col, hover_row)
	var hid: int = int(hcell["crop_id"])
	var hprog: float = float(hcell.get("visual_progress", hcell.get("progress", 0.0)))
	var server_hprog := clampf(float(hcell.get("progress", 0.0)), 0.0, 1.0)
	var stage: String
	var stage_color: Color
	if server_hprog >= 1.0:
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

	var tw: float = 170.0
	var th: float = 95.0
	var tx: float = clampf(hsp.x - tw * 0.5, w_min.x + 5, w_max.x - tw - 5)
	var ty: float = clampf(hsp.y - TH * 0.5 - th - 18, w_min.y + 5, w_max.y - th - 5)
	draw_api._d_rect(Rect2(tx, ty, tw, th), Color(0.08, 0.05, 0.02, 0.92))
	draw_api._d_rect(Rect2(tx, ty, tw, th), Color(0.55, 0.42, 0.2), false, 2)
	draw_api._d_rect(Rect2(tx, ty, tw, 22), Color(0.4, 0.28, 0.1))
	draw_api._draw_text(tx + 6, ty + 3, crop_catalog.get_name(hid), 13, Color(1, 0.95, 0.8))
	draw_api._d_circle(Vector2(tx + 14, ty + 36), 6, _crop_color(CROP_COLORS, hid, 1))
	draw_api._draw_text(tx + 26, ty + 30, stage, 11, stage_color)
	draw_api._draw_text(tx + 26, ty + 46, str(int(hprog * 100)) + "% 已成长", 11, Color(0.8, 0.8, 0.8))
	var land_info: String = _get_land_level_name(int(hcell.get("land_level", 1)))
	if int(hcell.get("land_level", 1)) < LAND_LEVEL_MAX:
		land_info += " " + str(int(hcell.get("land_work", 0))) + "/" + str(LAND_UPGRADE_WORK_REQUIRED)
	draw_api._draw_text(tx + 92, ty + 30, land_info, 10, Color(0.95, 0.82, 0.42))

	var action_hint: String
	if server_hprog >= 1.0:
		draw_api._draw_text(tx + 26, ty + 62, "售价: " + str(crop_catalog.get_unit_sell(hid)) + " 金/个", 11, Color(1, 0.88, 0.15))
		action_hint = "点击收获!" if tool_mode == 3 else ("点击铲除作物" if tool_mode == 4 else "切换到收获模式")
	else:
		var time_left: int = _remaining_seconds(hcell, float(hcell.get("client_server_time", Time.get_unix_time_from_system())), hprog, crop_catalog.get_grow_time(hid))
		draw_api._draw_text(tx + 26, ty + 62, "剩余时间: " + str(time_left) + "秒", 11, Color(0.7, 0.8, 1.0))
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
	var hint_color := Color(0.4, 0.9, 0.4) if server_hprog >= 1.0 else Color(0.4, 0.7, 0.9)
	draw_api._draw_text(tx + 26, ty + 76, action_hint, 10, hint_color)
	var arrow_x: float = clampf(hsp.x, tx + 10, tx + tw - 10)
	var arrow_pts: PackedVector2Array = PackedVector2Array([
		Vector2(arrow_x - 6, ty + th),
		Vector2(arrow_x, ty + th + 8),
		Vector2(arrow_x + 6, ty + th),
	])
	draw_api._d_colored_polygon(arrow_pts, Color(0.08, 0.05, 0.02, 0.92))

static func _draw_land_tooltip(draw_api, plot_positions: Array, cell: Dictionary, hover_col: int, hover_row: int, w_min: Vector2, w_max: Vector2, TH: float, LAND_LEVEL_MAX: int, LAND_UPGRADE_WORK_REQUIRED: int) -> void:
	var sp: Vector2 = _get_plot_position(plot_positions, hover_col, hover_row)
	var tw := 176.0
	var th := 78.0
	var tx := clampf(sp.x - tw * 0.5, w_min.x + 5.0, w_max.x - tw - 5.0)
	var ty := clampf(sp.y - TH * 0.5 - th - 18.0, w_min.y + 5.0, w_max.y - th - 5.0)
	var land_level := int(cell.get("land_level", 1))
	var work := int(cell.get("land_work", 0))
	draw_api._d_rect(Rect2(tx, ty, tw, th), Color(0.08, 0.05, 0.02, 0.92))
	draw_api._d_rect(Rect2(tx, ty, tw, th), Color(0.55, 0.42, 0.2), false, 2)
	draw_api._d_rect(Rect2(tx, ty, tw, 22), Color(0.38, 0.28, 0.12))
	draw_api._draw_text(tx + 8, ty + 3, _get_land_level_name(land_level), 13, Color(1.0, 0.92, 0.72))
	if land_level >= LAND_LEVEL_MAX:
		draw_api._draw_text(tx + 10, ty + 32, "已是最高等级", 12, Color(0.95, 0.82, 0.42))
	else:
		draw_api._draw_text(tx + 10, ty + 32, "土地经验: " + str(work) + "/" + str(LAND_UPGRADE_WORK_REQUIRED), 12, Color(0.95, 0.82, 0.42))
		draw_api._draw_text(tx + 10, ty + 50, "收获后增加 1 点", 11, Color(0.7, 0.85, 1.0))
	var arrow_x: float = clampf(sp.x, tx + 10.0, tx + tw - 10.0)
	var arrow_pts: PackedVector2Array = PackedVector2Array([
		Vector2(arrow_x - 6.0, ty + th),
		Vector2(arrow_x, ty + th + 8.0),
		Vector2(arrow_x + 6.0, ty + th),
	])
	draw_api._d_colored_polygon(arrow_pts, Color(0.08, 0.05, 0.02, 0.92))

static func _get_plot_position(plot_positions: Array, col: int, row: int) -> Vector2:
	if row >= 0 and row < plot_positions.size():
		var row_positions = plot_positions[row]
		if row_positions is Array and col >= 0 and col < row_positions.size():
			var pos = row_positions[col]
			if pos is Vector2:
				return pos
	return Vector2.ZERO

static func _iso_visual_corners(cx: float, cy: float, tile_width: float, tile_height: float, tile_gap: float) -> PackedVector2Array:
	var hw: float = (tile_width - tile_gap) * 0.5
	var hh: float = (tile_height - tile_gap) * 0.5
	return PackedVector2Array([
		Vector2(cx, cy - hh),
		Vector2(cx + hw, cy),
		Vector2(cx, cy + hh),
		Vector2(cx - hw, cy),
	])

static func _get_land_level_name(land_level: int) -> String:
	if land_level <= FarmState.LAND_LEVEL_LOCKED:
		return "未开垦"
	if land_level == 1:
		return "黄土地Lv1"
	if land_level == 2:
		return "黄土地Lv2"
	if land_level == 3:
		return "红土地"
	return "黑土地"

static func _draw_sign(draw_api, sign_texture: Texture2D, font: Font, tile_width: float, cx: float, cy: float, sign_color: Color, label: String, can_open: bool) -> void:
	var board_w: float = tile_width * 0.70
	var board_h: float = board_w
	var board_top: float = cy - board_w
	var board_cx: float = cx
	var sign_size := sign_texture.get_size()
	var scale: float = minf(board_w / sign_size.x, board_h / sign_size.y)
	var draw_size := sign_size * scale
	var draw_pos := Vector2(board_cx - draw_size.x * 0.5, board_top + (board_h - draw_size.y) * 0.5)
	draw_api._d_texture_rect(sign_texture, Rect2(draw_pos, draw_size), false)
	var text_font: Font = font if font != null else ThemeDB.fallback_font
	var text_color: Color = Color(0.12, 0.32, 0.12) if can_open else Color(0.78, 0.12, 0.1)
	var text_size := 14
	var text_width: float = text_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	draw_api._draw_text(board_cx - text_width * 0.5, board_top + board_h * 0.24, label, text_size, text_color)

static func _draw_plant_full(draw_api, cx: float, cy: float, leaf: Color, fruit: Color) -> void:
	var by: float = cy
	var sh: float = 28.0
	draw_api._d_line(Vector2(cx, by), Vector2(cx, by - sh), Color(0.2, 0.5, 0.12), 3.0)
	draw_api._d_circle(Vector2(cx - 10, by - sh * 0.6), 8, leaf)
	draw_api._d_circle(Vector2(cx + 10, by - sh * 0.55), 7, leaf)
	draw_api._d_circle(Vector2(cx, by - sh - 4), 10, fruit)
	draw_api._d_circle(Vector2(cx - 3, by - sh - 7), 3, Color(1, 1, 1, 0.35))

static func _draw_plant_growing(draw_api, cx: float, cy: float, leaf: Color, prog: float) -> void:
	var by: float = cy
	var sh: float = 10.0 + prog * 18.0
	draw_api._d_line(Vector2(cx, by), Vector2(cx, by - sh), Color(0.2, 0.5, 0.12), 2.5)
	draw_api._d_circle(Vector2(cx, by - sh), 5 + int(prog * 4), leaf)
	draw_api._d_circle(Vector2(cx - 6, by - sh * 0.5), 4, leaf)
	draw_api._d_circle(Vector2(cx + 6, by - sh * 0.45), 3.5, leaf)

static func _draw_plant_seed(draw_api, cx: float, cy: float, prog: float) -> void:
	var by: float = cy
	var h: float = 3.0 + prog * 10.0
	draw_api._d_line(Vector2(cx, by), Vector2(cx, by - h), Color(0.25, 0.6, 0.15), 2.0)
	if prog > 0.05:
		draw_api._d_circle(Vector2(cx - 2, by - h), 3, Color(0.3, 0.75, 0.2))
		draw_api._d_circle(Vector2(cx + 2, by - h + 1), 2.5, Color(0.3, 0.75, 0.2))
	draw_api._d_circle(Vector2(cx, by + 2), 3.5, Color(0.6, 0.45, 0.25))

static func _draw_seed_preview_texture(draw_api, cx: float, cy: float, texture: Texture2D) -> void:
	var size := texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var target := 26.0
	var scale_factor := minf(target / size.x, target / size.y)
	var draw_size := size * scale_factor
	var draw_pos := Vector2(cx - draw_size.x * 0.5, cy - draw_size.y * 0.5)
	draw_api._d_texture_rect(texture, Rect2(draw_pos, draw_size), false)

static func _draw_land_tile(draw_api, state: FarmState, tile_width: float, tile_height: float, tile_gap: float, corners: PackedVector2Array, cell: Dictionary, land_textures: Dictionary, land_texture_source_rects: Dictionary, land_texture_avg_colors: Dictionary) -> void:
	var texture := _get_land_texture(state, cell, land_textures)
	var bg_color: Color
	if texture != null:
		var key := _get_land_texture_key(state, cell)
		bg_color = land_texture_avg_colors.get(key, Color(0.5, 0.4, 0.25))
	else:
		bg_color = Color(0.52, 0.36, 0.20)
	bg_color.a = 0.78
	draw_api._d_colored_polygon(corners, bg_color)
	if texture == null:
		return
	var size := texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var center := Vector2.ZERO
	for point in corners:
		center += point
	center /= maxf(float(corners.size()), 1.0)
	var source := _get_land_texture_source_rect(state, cell, size, land_texture_source_rects)
	var vw: float = tile_width - tile_gap
	var vh: float = tile_height - tile_gap
	var dest := Rect2(center.x - vw * 0.5, center.y - vh * 0.5, vw, vh)
	draw_api.draw_texture_rect_region(texture, dest, source)

static func _get_land_texture(state: FarmState, cell: Dictionary, land_textures: Dictionary) -> Texture2D:
	return land_textures.get(_get_land_texture_key(state, cell), null) as Texture2D

static func _get_land_texture_source_rect(state: FarmState, cell: Dictionary, size: Vector2, land_texture_source_rects: Dictionary) -> Rect2:
	var key := _get_land_texture_key(state, cell)
	if land_texture_source_rects.has(key):
		return land_texture_source_rects[key]
	return Rect2(Vector2.ZERO, size)

static func _get_land_texture_key(state: FarmState, cell: Dictionary) -> String:
	if not state.is_cell_unlocked(cell):
		return "locked"
	var level := _get_land_level_key(int(cell.get("land_level", 1)))
	var suffix := "wet" if float(cell.get("wet_timer", 0.0)) > 0.0 else "dry"
	return level + "_" + suffix

static func _get_land_level_key(land_level: int) -> String:
	if land_level <= 2:
		return "yellow"
	if land_level == 3:
		return "red"
	return "black"

static func _get_crop_stage_texture(crop_catalog: CropCatalog, crop_id: int, stage: int) -> Texture2D:
	if stage < 0:
		return null
	return CropAtlas.get_stage_texture(crop_catalog.get_texture_key(crop_id), stage + 1)

static func _get_crop_seed_texture(crop_catalog: CropCatalog, crop_id: int) -> Texture2D:
	return CropAtlas.get_stage_texture(crop_catalog.get_texture_key(crop_id), 0)

static func _get_growth_stage(progress: float, render_stage_thresholds: Array) -> int:
	if render_stage_thresholds.size() < 4:
		return 2 if progress >= 0.9 else -1
	if progress < float(render_stage_thresholds[0]):
		return -1
	if progress < float(render_stage_thresholds[1]):
		return 0
	if progress < float(render_stage_thresholds[2]):
		return 1
	if progress < float(render_stage_thresholds[3]):
		return 2
	return 2

static func _remaining_seconds(cell: Dictionary, server_time: float, progress: float, grow_time: float) -> int:
	var fallback := maxf((1.0 - progress) * grow_time, 0.0)
	var mature_at := float(cell.get("estimated_mature_at", 0.0))
	var remaining := mature_at - server_time if mature_at > 0.0 else fallback
	remaining = minf(maxf(remaining, 0.0), fallback)
	return maxi(0, int(ceil(remaining)))

static func _crop_color(crop_colors: Array, crop_id: int, color_index: int) -> Color:
	if crop_id >= 0 and crop_id < crop_colors.size():
		var colors = crop_colors[crop_id]
		if colors is Array and color_index >= 0 and color_index < colors.size():
			return colors[color_index]
	return Color(0.42, 0.76, 0.34) if color_index == 0 else Color(0.72, 0.96, 0.46)

static func _draw_crop_atlas_texture(draw_api, crop_catalog: CropCatalog, tile_width: float, cx: float, tile_center_y: float, texture: Texture2D, crop_id: int, stage: int) -> void:
	var size := texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var scale_factor := _get_crop_scale(crop_catalog, tile_width, crop_id, size, stage)
	var draw_size := size * scale_factor
	var anchor := _get_crop_ground_anchor(texture)
	var draw_pos := Vector2(cx, tile_center_y) - anchor * scale_factor
	draw_api._d_texture_rect(texture, Rect2(draw_pos, draw_size), false)

static func _get_crop_scale(crop_catalog: CropCatalog, tile_width: float, crop_id: int, size: Vector2, stage: int) -> float:
	var target_size := 110.0
	var crop_key := crop_catalog.get_texture_key(crop_id)
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
	var width_limit_scale := (tile_width * 0.8) / maxf(size.x, 1.0)
	return minf(base_scale, width_limit_scale)

static func _get_crop_ground_anchor(texture: Texture2D) -> Vector2:
	var bounds := _get_texture_alpha_bounds(texture)
	return Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.position.y + bounds.size.y)

static func _get_texture_alpha_bounds(texture: Texture2D) -> Rect2:
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
