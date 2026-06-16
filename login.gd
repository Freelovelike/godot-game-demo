extends Control

## Login / Register scene — talks to the Go backend and transitions to Farm on success.

const AUTH_FILE := "user://auth.json"

var http: HTTPRequest
var status_label: Label
var username_input: LineEdit
var password_input: LineEdit
var action_button: Button
var mode_toggle: Button
var _cn_font: Font = null
var is_register_mode := false
var pending_action := ""

func _ready() -> void:
	_load_cn_font()

	# Try auto-login from saved token
	if _try_auto_login():
		return

	_build_ui()

func _try_auto_login() -> bool:
	if not FileAccess.file_exists(AUTH_FILE):
		return false
	var f := FileAccess.open(AUTH_FILE, FileAccess.READ)
	if f == null:
		return false
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	f.close()
	if err != OK:
		return false
	var data: Dictionary = json.data
	var token: String = data.get("token", "")
	var user_info: Dictionary = data.get("user", {})
	if token.is_empty():
		return false
	# Validate token with server
	http = HTTPRequest.new()
	http.request_completed.connect(_on_validate_completed.bind(token, user_info))
	add_child(http)
	var validate_url := ApiConfig.API_BASE + "/profile"
	var hdrs := ["Authorization: Bearer " + token]
	http.request(validate_url, hdrs, HTTPClient.METHOD_GET)
	# Show a loading state while validating
	var vp := get_viewport_rect().size
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.12, 0.08)
	bg.position = Vector2.ZERO; bg.size = vp
	add_child(bg)
	status_label = Label.new()
	status_label.text = "正在验证登录..."
	status_label.position = Vector2(vp.x / 2 - 80, vp.y / 2)
	_apply_cn_font(status_label)
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	status_label.add_theme_font_size_override("font_size", 18)
	add_child(status_label)
	return true

func _load_cn_font() -> void:
	var font_path := "res://assets/fonts/simhei.ttf"
	if ResourceLoader.exists(font_path):
		_cn_font = load(font_path) as Font

func _apply_cn_font(control: Control) -> void:
	if _cn_font != null:
		control.add_theme_font_override("font", _cn_font)

func _on_validate_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, token: String, user_info: Dictionary) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var resp: Dictionary = json.data
			if resp.get("code", -1) == 0:
				# Token valid — update user info and go to farm
				var fresh_user: Dictionary = resp.get("data", user_info)
				get_tree().set_meta("auth_token", token)
				get_tree().set_meta("user_info", fresh_user)
				_save_auth(token, fresh_user)
				get_tree().change_scene_to_file("res://Farm.tscn")
				return
	# Token invalid — clear saved auth, show login
	_clear_auth()
	http.queue_free()
	_build_ui()

func _build_ui() -> void:
	var vp := get_viewport_rect().size

	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.12, 0.08)
	bg.position = Vector2.ZERO; bg.size = vp
	add_child(bg)

	var pw := 400.0; var ph := 440.0
	var panel := PanelContainer.new()
	panel.position = Vector2((vp.x - pw) / 2, (vp.y - ph) / 2)
	panel.size = Vector2(pw, ph)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.18, 0.12)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0; vbox.anchor_bottom = 1.0
	vbox.offset_right = 0; vbox.offset_bottom = 0
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "QQ 农场"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_cn_font(title)
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "登录"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_cn_font(subtitle)
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
	vbox.add_child(subtitle)

	var user_label := Label.new()
	user_label.text = "用户名"
	_apply_cn_font(user_label)
	vbox.add_child(user_label)

	username_input = LineEdit.new()
	username_input.placeholder_text = "输入用户名 (3-32字符)"
	username_input.max_length = 32
	_apply_cn_font(username_input)
	vbox.add_child(username_input)

	var pass_label := Label.new()
	pass_label.text = "密码"
	_apply_cn_font(pass_label)
	vbox.add_child(pass_label)

	password_input = LineEdit.new()
	password_input.placeholder_text = "输入密码 (至少6位)"
	password_input.secret = true
	password_input.max_length = 64
	_apply_cn_font(password_input)
	vbox.add_child(password_input)

	action_button = Button.new()
	action_button.text = "登 录"
	action_button.custom_minimum_size = Vector2(0, 40)
	_apply_cn_font(action_button)
	action_button.pressed.connect(_on_action_pressed)
	vbox.add_child(action_button)

	mode_toggle = Button.new()
	mode_toggle.text = "没有账号？点此注册"
	mode_toggle.flat = true
	_apply_cn_font(mode_toggle)
	mode_toggle.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	mode_toggle.add_theme_color_override("font_hover_color", Color(0.7, 0.85, 1.0))
	mode_toggle.pressed.connect(_on_mode_toggle)
	vbox.add_child(mode_toggle)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_cn_font(status_label)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	status_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(status_label)

	if http == null:
		http = HTTPRequest.new()
		http.request_completed.connect(_on_request_completed)
		add_child(http)

	password_input.text_submitted.connect(func(_t): _on_action_pressed())
	username_input.text_submitted.connect(func(_t): password_input.grab_focus())


func _on_mode_toggle() -> void:
	is_register_mode = !is_register_mode
	if is_register_mode:
		action_button.text = "注 册"
		mode_toggle.text = "已有账号？点此登录"
		var subtitle := find_child("Subtitle", true, false)
		if subtitle: subtitle.text = "注册新账号"
	else:
		action_button.text = "登 录"
		mode_toggle.text = "没有账号？点此注册"
		var subtitle := find_child("Subtitle", true, false)
		if subtitle: subtitle.text = "登录"
	status_label.text = ""


func _on_action_pressed() -> void:
	var username := username_input.text.strip_edges()
	var password := password_input.text

	if username.length() < 3:
		status_label.text = "用户名至少3个字符"
		return
	if password.length() < 6:
		status_label.text = "密码至少6个字符"
		return

	status_label.text = "请求中..."
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	action_button.disabled = true

	var endpoint := "/auth/register" if is_register_mode else "/auth/login"
	var url := ApiConfig.API_BASE + endpoint
	var body := JSON.stringify({"username": username, "password": password})
	var headers := ["Content-Type: application/json"]

	pending_action = "register" if is_register_mode else "login"
	var err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		status_label.text = "请求发送失败"
		action_button.disabled = false


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	action_button.disabled = false

	if result != HTTPRequest.RESULT_SUCCESS:
		status_label.text = "网络错误，请检查后端是否运行"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
		return

	var json := JSON.new()
	var parse_err := json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		status_label.text = "服务器响应解析失败"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
		return

	var data: Dictionary = json.data
	var code: int = data.get("code", -1)

	if code != 0:
		status_label.text = data.get("message", "未知错误")
		status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
		return

	var resp_data: Dictionary = data.get("data", {})
	var token: String = resp_data.get("token", "")
	var user_info: Dictionary = resp_data.get("user", {})

	if token.is_empty():
		status_label.text = "登录成功但未获取到token"
		return

	status_label.text = "登录成功，正在进入农场..."
	status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))

	# Save auth for next launch
	_save_auth(token, user_info)

	await get_tree().create_timer(0.8).timeout

	get_tree().set_meta("auth_token", token)
	get_tree().set_meta("user_info", user_info)
	get_tree().change_scene_to_file("res://Farm.tscn")


func _save_auth(token: String, user_info: Dictionary) -> void:
	var data := {"token": token, "user": user_info}
	var f := FileAccess.open(AUTH_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func _clear_auth() -> void:
	if FileAccess.file_exists(AUTH_FILE):
		DirAccess.remove_absolute(AUTH_FILE)
