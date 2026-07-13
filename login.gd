extends Control

## Login / Register scene — talks to the Go backend and transitions to Farm on success.

const AUTH_FILE := "user://auth.json"
const LOGIN_DESIGN_SIZE := Vector2(1280.0, 720.0)

var http: HTTPRequest
var design_stage: Control
var username_input: LineEdit
var password_input: LineEdit
var status_label: Label
var action_button: TextureButton
var mode_toggle: Button
var _cn_font: Font = null
var is_register_mode := false
var pending_action := ""

func _ready() -> void:
	_load_cn_font()
	design_stage = get_node_or_null("DesignStage") as Control
	resized.connect(_layout_login_scene)
	_layout_login_scene()

	var login_panel := get_node_or_null("DesignStage/LoginPanel")
	if login_panel == null:
		login_panel = get_node_or_null("LoginPanel")
	if login_panel == null:
		push_error("LoginPanel node is missing from Login.tscn")
		return

	username_input = login_panel.get_node_or_null("UsernameInput") as LineEdit
	password_input = login_panel.get_node_or_null("PasswordInput") as LineEdit
	status_label   = login_panel.get_node_or_null("StatusLabel") as Label
	action_button  = login_panel.get_node_or_null("LoginBtn") as TextureButton
	mode_toggle    = login_panel.get_node_or_null("ModeToggle") as Button

	_apply_cn_font(username_input)
	_apply_cn_font(password_input)
	_apply_cn_font(status_label)
	_apply_cn_font(mode_toggle)

	action_button.pressed.connect(_on_action_pressed)
	mode_toggle.pressed.connect(_on_mode_toggle)
	username_input.text_submitted.connect(func(_t): password_input.grab_focus())
	password_input.text_submitted.connect(func(_t): _on_action_pressed())

	if _try_auto_login():
		return

	if http == null:
		http = HTTPRequest.new()
		http.use_threads = true
		http.timeout = 120.0
		http.request_completed.connect(_on_request_completed)
		add_child(http)

func _layout_login_scene() -> void:
	if design_stage == null:
		return
	var stage_scale := minf(size.x / LOGIN_DESIGN_SIZE.x, size.y / LOGIN_DESIGN_SIZE.y)
	design_stage.scale = Vector2.ONE * stage_scale
	design_stage.position = (size - LOGIN_DESIGN_SIZE * stage_scale) * 0.5

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

	http = HTTPRequest.new()
	http.use_threads = true
	http.request_completed.connect(_on_validate_completed.bind(token, user_info))
	add_child(http)
	status_label.text = "正在验证登录..."
	var hdrs := ["Authorization: Bearer " + token]
	http.request(ApiConfig.API_BASE + "/profile", hdrs, HTTPClient.METHOD_GET)
	return true

func _load_cn_font() -> void:
	var font_path := "res://assets/fonts/simhei.ttf"
	if ResourceLoader.exists(font_path):
		_cn_font = load(font_path) as Font

func _apply_cn_font(control: Control) -> void:
	if control != null and _cn_font != null:
		control.add_theme_font_override("font", _cn_font)

func _on_validate_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, token: String, user_info: Dictionary) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var resp: Dictionary = json.data
			if resp.get("code", -1) == 0:
				var fresh_user: Dictionary = resp.get("data", user_info)
				get_tree().set_meta("auth_token", token)
				get_tree().set_meta("user_info", fresh_user)
				_save_auth(token, fresh_user)
				get_tree().change_scene_to_file("res://Farm.tscn")
				return
	_clear_auth()
	http.queue_free()
	http = null
	status_label.text = ""
	http = HTTPRequest.new()
	http.use_threads = true
	http.timeout = 120.0
	http.request_completed.connect(_on_request_completed)
	add_child(http)

func _on_mode_toggle() -> void:
	is_register_mode = !is_register_mode
	if is_register_mode:
		mode_toggle.text = "已有账号？点此登录"
		status_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
	else:
		mode_toggle.text = "没有账号？点此注册"
		status_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
	status_label.text = ""

func _on_action_pressed() -> void:
	var username := username_input.text.strip_edges()
	var password := password_input.text
	if username.length() < 3:
		_set_status("用户名至少3个字符", Color(1.0, 0.5, 0.4))
		return
	if password.length() < 6:
		_set_status("密码至少6个字符", Color(1.0, 0.5, 0.4))
		return
	_set_status("请求中...", Color(0.7, 0.7, 0.7))
	action_button.disabled = true
	var endpoint := "/auth/register" if is_register_mode else "/auth/login"
	var body := JSON.stringify({"username": username, "password": password})
	pending_action = "register" if is_register_mode else "login"
	var err := http.request(ApiConfig.API_BASE + endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		_set_status("请求发送失败: " + str(err), Color(1.0, 0.5, 0.4))
		action_button.disabled = false

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	action_button.disabled = false
	if result != HTTPRequest.RESULT_SUCCESS:
		_set_status("网络错误: " + str(result), Color(1.0, 0.5, 0.4))
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_set_status("服务器响应解析失败", Color(1.0, 0.5, 0.4))
		return
	var data: Dictionary = json.data
	if data.get("code", -1) != 0:
		_set_status(data.get("message", "未知错误"), Color(1.0, 0.5, 0.4))
		return
	var resp_data: Dictionary = data.get("data", {})
	var token: String = resp_data.get("token", "")
	var user_info: Dictionary = resp_data.get("user", {})
	if token.is_empty():
		_set_status("登录成功但未获取到token", Color(1.0, 0.8, 0.4))
		return
	_set_status("登录成功，正在进入农场...", Color(0.4, 1.0, 0.5))
	_save_auth(token, user_info)
	await get_tree().create_timer(0.8).timeout
	get_tree().set_meta("auth_token", token)
	get_tree().set_meta("user_info", user_info)
	get_tree().change_scene_to_file("res://Farm.tscn")

func _set_status(msg: String, color: Color) -> void:
	status_label.text = msg
	status_label.add_theme_color_override("font_color", color)

func _save_auth(token: String, user_info: Dictionary) -> void:
	var f := FileAccess.open(AUTH_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"token": token, "user": user_info}))
		f.close()

func _clear_auth() -> void:
	if FileAccess.file_exists(AUTH_FILE):
		DirAccess.remove_absolute(AUTH_FILE)
