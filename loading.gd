extends Control

const DESIGN_SIZE := Vector2(1280.0, 720.0)
const NEXT_SCENE := "res://Login.tscn"
const MIN_DISPLAY_TIME := 1.2
const RESOURCE_PATHS := [
	NEXT_SCENE,
	"res://assets/background/farm_background.png",
	"res://assets/land/land_yellow_dry.png",
	"res://assets/land/land_yellow_wet.png",
	"res://assets/land/land_red-dry.png",
	"res://assets/land/land_red_wet.png",
	"res://assets/land/land_black_dry.png",
	"res://assets/land/land_black_wet.png",
	"res://assets/plants/user/crop_sheet_clean.png",
]

@onready var design_stage: Control = $DesignStage
@onready var progress_bar: TextureProgressBar = $DesignStage/LoadingPanel/ProgressBar
@onready var percent_label: Label = $DesignStage/LoadingPanel/PercentLabel

var _started_at := 0
var _finished := false
var _loaded_resources: Dictionary = {}

func _ready() -> void:
	_started_at = Time.get_ticks_msec()
	resized.connect(_layout_stage)
	_layout_stage()
	for path in RESOURCE_PATHS:
		var error := ResourceLoader.load_threaded_request(path)
		if error != OK:
			push_error("Unable to queue resource for loading: " + path)

func _process(_delta: float) -> void:
	if _finished:
		return

	var total_progress := 0.0
	var loaded_count := 0
	for path in RESOURCE_PATHS:
		var progress := []
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				total_progress += 1.0
				loaded_count += 1
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				total_progress += progress[0] if not progress.is_empty() else 0.0
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("Failed to initialize resource: " + path)
				total_progress += 1.0
				loaded_count += 1

	var ratio := total_progress / float(RESOURCE_PATHS.size())
	_set_progress(ratio)
	if loaded_count == RESOURCE_PATHS.size():
		_finish_loading()

func _finish_loading() -> void:
	_finished = true
	var resource_cache := get_node_or_null("/root/GameResources")
	for path in RESOURCE_PATHS:
		var resource := ResourceLoader.load_threaded_get(path)
		if resource != null:
			_loaded_resources[path] = resource
			if resource_cache != null:
				resource_cache.call("store", path, resource)
	_set_progress(1.0)

	var elapsed := (Time.get_ticks_msec() - _started_at) / 1000.0
	if elapsed < MIN_DISPLAY_TIME:
		await get_tree().create_timer(MIN_DISPLAY_TIME - elapsed).timeout

	var login_scene := _loaded_resources.get(NEXT_SCENE) as PackedScene
	if login_scene != null:
		get_tree().change_scene_to_packed(login_scene)
	else:
		get_tree().change_scene_to_file(NEXT_SCENE)

func _set_progress(ratio: float) -> void:
	var normalized := clampf(ratio, 0.0, 1.0)
	progress_bar.value = normalized * 100.0
	percent_label.text = "%d%%" % roundi(normalized * 100.0)

func _layout_stage() -> void:
	var stage_scale := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	design_stage.scale = Vector2.ONE * stage_scale
	design_stage.position = (size - DESIGN_SIZE * stage_scale) * 0.5
