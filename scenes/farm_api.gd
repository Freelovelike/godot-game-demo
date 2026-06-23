extends Node
class_name FarmApiClient

## HTTP client for farm backend endpoints.
## This node owns HTTPRequest instances and emits raw responses. Farm.gd remains
## responsible for parsing response bodies, updating state, and showing UI text.

signal config_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)
signal load_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)
signal save_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)
signal action_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)
signal sell_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)

const REQUEST_TIMEOUT := 120.0
const CONFIG_PATH := "/farm/config"
const LOAD_PATH := "/farm/load"
const SAVE_PATH := "/farm/save"
const ACTION_PATH := "/farm/action"
const SELL_PATH := "/farm/sell"

var auth_token := ""

var _config_http: HTTPRequest
var _load_http: HTTPRequest
var _save_http: HTTPRequest
var _action_http: HTTPRequest
var _sell_http: HTTPRequest

func _ready():
	_ensure_ready()

func _ensure_ready() -> void:
	if _config_http != null:
		return
	_config_http = _make_http(config_completed)
	_load_http = _make_http(load_completed)
	_save_http = _make_http(save_completed)
	_action_http = _make_http(action_completed)
	_sell_http = _make_http(sell_completed)

func _make_http(done_signal: Signal) -> HTTPRequest:
	var req := HTTPRequest.new()
	req.use_threads = true
	req.timeout = REQUEST_TIMEOUT
	req.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		done_signal.emit(result, response_code, headers, body)
	)
	add_child(req)
	return req

func request_config():
	_ensure_ready()
	_request_get(_config_http, CONFIG_PATH)

func request_load():
	_ensure_ready()
	_request_get(_load_http, LOAD_PATH)

func request_save(payload: Dictionary):
	_ensure_ready()
	_request_json(_save_http, SAVE_PATH, payload)

func request_action(action: String, params: Dictionary = {}):
	_ensure_ready()
	var payload := params.duplicate(true)
	payload["action"] = action
	_request_json(_action_http, ACTION_PATH, payload)

func request_sell(crop_id: int, count: int):
	_ensure_ready()
	var payload := {"crop_id": crop_id, "count": count}
	_request_json(_sell_http, SELL_PATH, payload)

func _request_get(req: HTTPRequest, path: String):
	req.request(ApiConfig.API_BASE + path, _auth_headers(), HTTPClient.METHOD_GET)

func _request_json(req: HTTPRequest, path: String, payload: Dictionary):
	req.request(ApiConfig.API_BASE + path, _json_headers(), HTTPClient.METHOD_POST, JSON.stringify(payload))

func _auth_headers() -> PackedStringArray:
	return PackedStringArray(["Authorization: Bearer " + auth_token])

func _json_headers() -> PackedStringArray:
	return PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + auth_token])
