extends RefCounted

## World renderer for Farm.gd. It owns the isometric world draw pass while
## Farm.gd keeps server state, input intent dispatch, and low-level draw helpers.

static func draw_world(farm_ref) -> void:
	var farm: Array = farm_ref.farm
	var ROWS: int = farm_ref.ROWS
	var COLS: int = farm_ref.COLS
	var TW: float = farm_ref.TW
	var TH: float = farm_ref.TH
	var LAND_LEVEL_MAX: int = farm_ref.LAND_LEVEL_MAX
	var LAND_UPGRADE_WORK_REQUIRED: int = farm_ref.LAND_UPGRADE_WORK_REQUIRED
	var CROPS: Array = farm_ref.CROPS
	var CROP_COLORS: Array = farm_ref.CROP_COLORS
	var hover_col: int = farm_ref.hover_col
	var hover_row: int = farm_ref.hover_row
	var ctx_menu_open: bool = farm_ref.ctx_menu_open
	var ctx_col: int = farm_ref.ctx_col
	var ctx_row: int = farm_ref.ctx_row
	var selected_seed: int = farm_ref.selected_seed
	var selected_fertilizer: int = farm_ref.selected_fertilizer
	var tool_mode: int = farm_ref.tool_mode
	var level: int = farm_ref.level
	var gold: int = farm_ref.gold
	var sign_texture: Texture2D = farm_ref._sign_texture
	var cn_font: Font = farm_ref._cn_font

	var vp: Vector2 = farm_ref.get_viewport().get_visible_rect().size
	var ctrans: Transform2D = farm_ref.get_viewport().get_canvas_transform()
	var w_min: Vector2 = ctrans.affine_inverse() * Vector2.ZERO
	var w_max: Vector2 = ctrans.affine_inverse() * vp
	farm_ref._d_rect(Rect2(100, 40, 440, 40), Color(0.1, 0.06, 0.02, 0.85))
	farm_ref._draw_text(200, 46, "QQ 农场 2.5D", 24, Color(1, 0.9, 0.2))

	if farm.size() < ROWS:
		return
	for row in range(ROWS):
		if farm[row].size() < COLS:
			return
		for col in range(COLS):
			var sp: Vector2 = farm_ref._get_plot_position(col, row)
			var cx: float = sp.x
			var cy: float = sp.y
			var vcorners: PackedVector2Array = farm_ref.iso_visual_corners(cx, cy)
			var cell: Dictionary = farm[row][col]
			farm_ref._draw_land_tile(vcorners, cell)

			if (col == hover_col and row == hover_row) or (ctx_menu_open and col == ctx_col and row == ctx_row):
				if not farm_ref._is_cell_unlocked(cell):
					farm_ref._d_colored_polygon(vcorners, Color(0.75, 0.75, 0.75, 0.22))
				elif cell["crop_id"] == -1 and selected_seed >= 0:
					farm_ref._d_colored_polygon(vcorners, Color(0.3, 0.9, 0.3, 0.25))
				elif cell["crop_id"] != -1 and cell["progress"] >= 1.0:
					farm_ref._d_colored_polygon(vcorners, Color(1.0, 0.85, 0.15, 0.35))
				else:
					farm_ref._d_colored_polygon(vcorners, Color(1, 1, 1, 0.1))

			if (col == hover_col and row == hover_row) or (ctx_menu_open and col == ctx_col and row == ctx_row):
				var bcol := Color(1, 0.9, 0.2, 0.9)
				for i in range(4):
					farm_ref._d_line(vcorners[i], vcorners[(i + 1) % 4], bcol, 2.0)

			if farm_ref._is_cell_unlocked(cell) and cell["crop_id"] == -1 and col == hover_col and row == hover_row and selected_seed >= 0:
				var seed_texture: Texture2D = farm_ref._get_crop_seed_texture(selected_seed)
				if seed_texture != null:
					farm_ref._draw_seed_preview_texture(cx, cy, seed_texture)
				else:
					farm_ref._d_circle(Vector2(cx, cy), 10, Color(CROP_COLORS[selected_seed][1].r, CROP_COLORS[selected_seed][1].g, CROP_COLORS[selected_seed][1].b, 0.7))
					farm_ref._d_circle(Vector2(cx, cy), 6, CROP_COLORS[selected_seed][1])

	for row in range(ROWS):
		if farm[row].size() < COLS:
			return
		for col in range(COLS):
			var sp: Vector2 = farm_ref._get_plot_position(col, row)
			var cx: float = sp.x
			var cy: float = sp.y
			var cell: Dictionary = farm[row][col]

			if not farm_ref._is_cell_unlocked(cell):
				var req_level: int = farm_ref._get_reclaim_level(col, row)
				var req_cost: int = farm_ref._get_reclaim_cost(col, row)
				var next_locked: Vector2i = farm_ref._get_next_locked_plot()
				var is_next: bool = next_locked.x == col and next_locked.y == row
				if is_next and sign_texture != null:
					var can: bool = level >= req_level and gold >= req_cost
					var sign_color := Color(0.2, 0.8, 0.25) if can else Color(0.85, 0.25, 0.2)
					var sign_label := "可解锁" if can else "Lv." + str(req_level) + "解锁"
					farm_ref._draw_sign(cx, cy, sign_color, sign_label, can)
				else:
					var lock_text := "Lv" + str(req_level)
					var f_lock: Font = cn_font if cn_font != null else ThemeDB.fallback_font
					var lock_w: float = f_lock.get_string_size(lock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
					farm_ref._d_rect(Rect2(cx - lock_w * 0.5 - 6, cy - 10, lock_w + 12, 18), Color(0.02, 0.02, 0.02, 0.68))
					farm_ref._draw_text(cx - lock_w * 0.5, cy - 8, lock_text, 12, Color(0.92, 0.9, 0.78, 0.95))
					if col == hover_col and row == hover_row:
						var cost_text := str(req_cost) + " 金币开垦"
						var cost_w: float = f_lock.get_string_size(cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
						farm_ref._d_rect(Rect2(cx - cost_w * 0.5 - 6, cy + 12, cost_w + 12, 17), Color(0.02, 0.02, 0.02, 0.72))
						farm_ref._draw_text(cx - cost_w * 0.5, cy + 13, cost_text, 11, Color(1.0, 0.82, 0.26, 0.95))
				continue

			if cell["crop_id"] != -1:
				var cid: int = int(cell["crop_id"])
				var prog: float = float(cell.get("visual_progress", cell.get("progress", 0.0)))
				var server_prog := clampf(float(cell.get("progress", 0.0)), 0.0, 1.0)
				var fruit_col: Color = CROP_COLORS[cid][1]
				var leaf_col: Color = CROP_COLORS[cid][0]
				var stage: int = farm_ref._get_growth_stage(prog)
				var atlas_texture: Texture2D = farm_ref._get_crop_stage_texture(cid, prog)

				if stage < 0:
					farm_ref._draw_plant_seed(cx, cy, prog)
				elif atlas_texture != null:
					farm_ref._draw_crop_atlas_texture(cx, cy, atlas_texture, prog, cid, stage)
				elif prog > 0.3:
					farm_ref._draw_plant_growing(cx, cy, leaf_col, prog)
				else:
					farm_ref._draw_plant_seed(cx, cy, prog)

				if server_prog >= 1.0:
					if atlas_texture == null:
						farm_ref._draw_plant_full(cx, cy, leaf_col, fruit_col)
					var f: Font = cn_font if cn_font != null else ThemeDB.fallback_font
					var lbl := "收获"
					var lw: float = f.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
					farm_ref._d_rect(Rect2(cx - lw * 0.5 - 4, cy - TH * 0.5 - 22, lw + 8, 16), Color(0.8, 0.6, 0, 0.85))
					farm_ref._draw_text(cx - lw * 0.5, cy - TH * 0.5 - 19, lbl, 11, Color(1, 1, 1))

				if prog < 1.0:
					var bw: float = TW * 0.5
					var bx: float = cx - bw * 0.5
					var by: float = cy + TH * 0.35
					farm_ref._d_rect(Rect2(bx, by, bw, 5), Color(0, 0, 0, 0.5))
					var bc := Color(0.2, 0.8, 0.3) if prog < 0.6 else Color(0.95, 0.75, 0.1)
					farm_ref._d_rect(Rect2(bx, by, bw * prog, 5), bc)
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
					farm_ref._draw_text(cx - 20, cy + TH * 0.5 + 14, stage_name + " " + str(remaining) + "秒", 9, Color(1, 1, 1, 0.75))
				else:
					var yield_hint := "产量 " + str(int(CROPS[cid][5])) + "~" + str(int(CROPS[cid][8]))
					farm_ref._draw_text(cx - 20, cy + TH * 0.5 + 14, yield_hint, 9, Color(1, 0.9, 0.3, 0.8))

				if prog < 1.0:
					var icon_y := cy - TH * 0.5 - 8
					var icon_x := cx + 12
					var ws: int = int(cell.get("water_state", 0))
					var bug_count: int = int(cell.get("bug_count", 0))
					var weed_count: int = int(cell.get("weed_count", 0))
					if ws == 1:
						farm_ref._d_circle(Vector2(icon_x, icon_y), 6, Color(0.2, 0.5, 0.9, 0.8))
						farm_ref._draw_text(icon_x - 3, icon_y + 3, "渴", 8, Color(1, 1, 1))
						icon_x -= 16
					if bug_count > 0:
						farm_ref._d_circle(Vector2(icon_x, icon_y), 6, Color(0.9, 0.2, 0.2, 0.8))
						farm_ref._draw_text(icon_x - 3, icon_y + 3, str(bug_count), 8, Color(1, 1, 1))
						icon_x -= 16
					if weed_count > 0:
						farm_ref._d_circle(Vector2(icon_x, icon_y), 6, Color(0.2, 0.7, 0.2, 0.8))
						farm_ref._draw_text(icon_x - 3, icon_y + 3, str(weed_count), 8, Color(1, 1, 1))

	if (not farm_ref.shop_open and not farm_ref.inventory_open and not farm_ref.settings_open
			and not farm_ref.reclaim_confirm_open and not farm_ref.reset_confirm_open
			and not farm_ref.warehouse_open and not farm_ref.shovel_all_confirm_open
			and hover_col >= 0 and hover_col < COLS and hover_row >= 0 and hover_row < ROWS):
		var hcell: Dictionary = farm[hover_row][hover_col]
		if not farm_ref._is_cell_unlocked(hcell):
			_draw_locked_tooltip(farm_ref, hover_col, hover_row, w_min, w_max, TH, level, gold)
		elif hcell["crop_id"] != -1:
			_draw_crop_tooltip(farm_ref, hcell, hover_col, hover_row, w_min, w_max, TH, CROPS, CROP_COLORS, LAND_LEVEL_MAX, LAND_UPGRADE_WORK_REQUIRED, tool_mode, selected_fertilizer)
		else:
			farm_ref._draw_land_tooltip(hover_col, hover_row)

static func _draw_locked_tooltip(farm_ref, hover_col: int, hover_row: int, w_min: Vector2, w_max: Vector2, TH: float, level: int, gold: int) -> void:
	var hsp_locked: Vector2 = farm_ref._get_plot_position(hover_col, hover_row)
	var ltw: float = 190.0
	var lth: float = 82.0
	var ltx: float = clampf(hsp_locked.x - ltw * 0.5, w_min.x + 5, w_max.x - ltw - 5)
	var lty: float = clampf(hsp_locked.y - TH * 0.5 - lth - 18, w_min.y + 5, w_max.y - lth - 5)
	var required_level: int = farm_ref._get_reclaim_level(hover_col, hover_row)
	var required_cost: int = farm_ref._get_reclaim_cost(hover_col, hover_row)
	var next_locked: Vector2i = farm_ref._get_next_locked_plot()
	farm_ref._d_rect(Rect2(ltx, lty, ltw, lth), Color(0.08, 0.06, 0.03, 0.94))
	farm_ref._d_rect(Rect2(ltx, lty, ltw, lth), Color(0.55, 0.42, 0.2), false, 2)
	farm_ref._d_rect(Rect2(ltx, lty, ltw, 22), Color(0.34, 0.25, 0.12))
	farm_ref._draw_text(ltx + 8, lty + 3, "未开垦土地", 13, Color(1.0, 0.92, 0.72))
	farm_ref._draw_text(ltx + 10, lty + 31, "需要等级: " + str(required_level), 12, Color(0.86, 0.92, 1.0))
	farm_ref._draw_text(ltx + 10, lty + 49, "开垦费用: " + str(required_cost) + " 金币", 12, Color(1.0, 0.84, 0.25))
	var locked_hint := "点击开垦" if next_locked.x == hover_col and next_locked.y == hover_row and level >= required_level and gold >= required_cost else ("需先开垦前一块" if next_locked.x != hover_col or next_locked.y != hover_row else "等级或金币不足")
	var locked_hint_color := Color(0.45, 0.95, 0.45) if next_locked.x == hover_col and next_locked.y == hover_row and level >= required_level and gold >= required_cost else (Color(0.95, 0.8, 0.35) if next_locked.x != hover_col or next_locked.y != hover_row else Color(0.95, 0.45, 0.35))
	farm_ref._draw_text(ltx + 10, lty + 66, locked_hint, 10, locked_hint_color)

static func _draw_crop_tooltip(farm_ref, hcell: Dictionary, hover_col: int, hover_row: int, w_min: Vector2, w_max: Vector2, TH: float, CROPS: Array, CROP_COLORS: Array, LAND_LEVEL_MAX: int, LAND_UPGRADE_WORK_REQUIRED: int, tool_mode: int, selected_fertilizer: int) -> void:
	var hsp: Vector2 = farm_ref._get_plot_position(hover_col, hover_row)
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
	farm_ref._d_rect(Rect2(tx, ty, tw, th), Color(0.08, 0.05, 0.02, 0.92))
	farm_ref._d_rect(Rect2(tx, ty, tw, th), Color(0.55, 0.42, 0.2), false, 2)
	farm_ref._d_rect(Rect2(tx, ty, tw, 22), Color(0.4, 0.28, 0.1))
	farm_ref._draw_text(tx + 6, ty + 3, str(CROPS[hid][0]), 13, Color(1, 0.95, 0.8))
	farm_ref._d_circle(Vector2(tx + 14, ty + 36), 6, CROP_COLORS[hid][1])
	farm_ref._draw_text(tx + 26, ty + 30, stage, 11, stage_color)
	farm_ref._draw_text(tx + 26, ty + 46, str(int(hprog * 100)) + "% 已成长", 11, Color(0.8, 0.8, 0.8))
	var land_info: String = farm_ref._get_land_level_name(int(hcell.get("land_level", 1)))
	if int(hcell.get("land_level", 1)) < LAND_LEVEL_MAX:
		land_info += " " + str(int(hcell.get("land_work", 0))) + "/" + str(LAND_UPGRADE_WORK_REQUIRED)
	farm_ref._draw_text(tx + 92, ty + 30, land_info, 10, Color(0.95, 0.82, 0.42))

	var action_hint: String
	if server_hprog >= 1.0:
		farm_ref._draw_text(tx + 26, ty + 62, "售价: " + str(int(CROPS[hid][6])) + " 金/个", 11, Color(1, 0.88, 0.15))
		action_hint = "点击收获!" if tool_mode == 3 else ("点击铲除作物" if tool_mode == 4 else "切换到收获模式")
	else:
		var time_left: int = int((1.0 - server_hprog) * float(CROPS[hid][3]))
		farm_ref._draw_text(tx + 26, ty + 62, "剩余时间: " + str(time_left) + "秒", 11, Color(0.7, 0.8, 1.0))
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
	farm_ref._draw_text(tx + 26, ty + 76, action_hint, 10, hint_color)
	var arrow_x: float = clampf(hsp.x, tx + 10, tx + tw - 10)
	var arrow_pts: PackedVector2Array = PackedVector2Array([
		Vector2(arrow_x - 6, ty + th),
		Vector2(arrow_x, ty + th + 8),
		Vector2(arrow_x + 6, ty + th),
	])
	farm_ref._d_colored_polygon(arrow_pts, Color(0.08, 0.05, 0.02, 0.92))
