extends Node

signal config_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)
signal load_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)
signal save_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)
signal action_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)
signal sell_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)

var auth_token := ""

var _config_http: HTTPRequest
var _load_http: HTTPRequest
var _save_http: HTTPRequest
var _action_http: HTTPRequest
var _sell_http: HTTPRequest

func _ready():
	_config_http = _make_http(config_completed)
	_load_http = _make_http(load_completed)
	_save_http = _make_http(save_completed)
	_action_http = _make_http(action_completed)
	_sell_http = _make_http(sell_completed)

func _make_http(done_signal: Signal) -> HTTPRequest:
	var req := HTTPRequest.new()
	req.use_threads = true
	req.timeout = 120.0
	req.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		done_signal.emit(result, response_code, headers, body)
	)
	add_child(req)
	return req

func request_config():
	_config_http.request(ApiConfig.API_BASE + "/farm/config", _auth_headers(), HTTPClient.METHOD_GET)

func request_load():
	_load_http.request(ApiConfig.API_BASE + "/farm/load", _auth_headers(), HTTPClient.METHOD_GET)

func request_save(payload: Dictionary):
	_save_http.request(ApiConfig.API_BASE + "/farm/save", _json_headers(), HTTPClient.METHOD_POST, JSON.stringify(payload))

func request_action(action: String, params: Dictionary = {}):
	var payload := params.duplicate(true)
	payload["action"] = action
	_action_http.request(ApiConfig.API_BASE + "/farm/action", _json_headers(), HTTPClient.METHOD_POST, JSON.stringify(payload))

func request_sell(crop_id: int, count: int):
	var payload := {"crop_id": crop_id, "count": count}
	_sell_http.request(ApiConfig.API_BASE + "/farm/sell", _json_headers(), HTTPClient.METHOD_POST, JSON.stringify(payload))

func _auth_headers() -> PackedStringArray:
	return PackedStringArray(["Authorization: Bearer " + auth_token])

func _json_headers() -> PackedStringArray:
	return PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + auth_token])
