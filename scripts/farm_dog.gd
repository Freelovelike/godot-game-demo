@tool
extends AnimatedSprite2D

enum PreviewAction {
	IDLE,
	MOVE,
	BARK,
	LIE,
}

const FRAME_TEXTURES := {
	&"idle": [
		preload("res://assets/帧动画/待机动画/sprite-02-idle-tail_1.png"),
		preload("res://assets/帧动画/待机动画/sprite-02-idle-tail_2.png"),
		preload("res://assets/帧动画/待机动画/sprite-02-idle-tail_3.png"),
		preload("res://assets/帧动画/待机动画/sprite-02-idle-tail_4.png"),
		preload("res://assets/帧动画/待机动画/sprite-02-idle-tail_5.png"),
		preload("res://assets/帧动画/待机动画/sprite-02-idle-tail_6.png"),
	],
	&"move": [
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_01.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_02.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_03.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_04.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_05.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_06.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_07.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_08.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_09.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_10.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_11.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_12.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_13.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_14.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_15.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_16.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_17.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_18.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_19.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_20.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_21.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_22.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_23.png"),
		preload("res://assets/帧动画/奔跑动画24帧/dog_run_24.png"),
	],
	&"bark": [
		preload("res://assets/帧动画/哄叫动画/sprite-01-barking_1.png"),
		preload("res://assets/帧动画/哄叫动画/sprite-01-barking_2.png"),
		preload("res://assets/帧动画/哄叫动画/sprite-01-barking_3.png"),
		preload("res://assets/帧动画/哄叫动画/sprite-01-barking_4.png"),
		preload("res://assets/帧动画/哄叫动画/sprite-01-barking_5.png"),
		preload("res://assets/帧动画/哄叫动画/sprite-01-barking_6.png"),
	],
	&"lie": [
		preload("res://assets/帧动画/趴地动画/sprite-04-lying_1.png"),
		preload("res://assets/帧动画/趴地动画/sprite-04-lying_2.png"),
		preload("res://assets/帧动画/趴地动画/sprite-04-lying_3.png"),
		preload("res://assets/帧动画/趴地动画/sprite-04-lying_4.png"),
		preload("res://assets/帧动画/趴地动画/sprite-04-lying_5.png"),
		preload("res://assets/帧动画/趴地动画/sprite-04-lying_6.png"),
	],
}
var _walk_points := PackedVector2Array([
	Vector2(1120.0, 700.0),
	Vector2(1240.0, 760.0),
	Vector2(1160.0, 830.0),
	Vector2(1040.0, 790.0),
])
const WALK_SPEED := 62.0
const LIE_HOLD_SECONDS := 3.0

@export_category("编辑器预览")
@export_enum("待机 / 摇尾", "移动", "叫", "趴下") var preview_action: int = PreviewAction.IDLE:
	set(value):
		preview_action = value
		if Engine.is_editor_hint() and is_node_ready():
			_apply_editor_preview()

var _rng := RandomNumberGenerator.new()
var _target_index := 0
var _wait_time := 0.0
var _walking := false


func _ready() -> void:
	sprite_frames = _build_sprite_frames()
	animation_finished.connect(_on_animation_finished)
	if Engine.is_editor_hint():
		_apply_editor_preview()
		return
	_rng.randomize()
	_start_idle()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _walking:
		_walk_toward_target(delta)
		return

	_wait_time -= delta
	if _wait_time <= 0.0:
		_choose_next_action()


func _build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_frame_animation(frames, &"idle", FRAME_TEXTURES[&"idle"], 4.0, true)
	_add_frame_animation(frames, &"move", FRAME_TEXTURES[&"move"], 8.0, true)
	_add_frame_animation(frames, &"bark", FRAME_TEXTURES[&"bark"], 5.0, false)
	_add_frame_animation(frames, &"lie", FRAME_TEXTURES[&"lie"], 3.5, false, 2, LIE_HOLD_SECONDS)
	return frames


func _add_frame_animation(
		frames: SpriteFrames,
		animation_name: StringName,
		textures: Array,
		fps: float,
		loops: bool,
		hold_frame_index: int = -1,
		hold_seconds: float = 0.0
) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loops)
	for frame_index in textures.size():
		var texture: Texture2D = textures[frame_index]
		var relative_duration := fps * hold_seconds if frame_index == hold_frame_index else 1.0
		frames.add_frame(animation_name, texture, relative_duration)


func _apply_editor_preview() -> void:
	if sprite_frames == null:
		return
	var preview_names: Array[StringName] = [&"idle", &"move", &"bark", &"lie"]
	var preview_name := preview_names[clampi(preview_action, 0, preview_names.size() - 1)]
	sprite_frames.set_animation_loop(preview_name, preview_name != &"lie")
	play(preview_name)


func _walk_toward_target(delta: float) -> void:
	var target := _walk_points[_target_index]
	flip_h = target.x < position.x
	position = position.move_toward(target, WALK_SPEED * delta)
	if position.distance_squared_to(target) < 1.0:
		position = target
		_walking = false
		_start_idle()


func _choose_next_action() -> void:
	var choice := _rng.randf()
	if choice < 0.5:
		_start_walking()
	elif choice < 0.72:
		_wait_time = INF
		play(&"bark")
	elif choice < 0.9:
		_wait_time = INF
		play(&"lie")
	else:
		_start_idle()


func _start_walking() -> void:
	var next_index := _rng.randi_range(0, _walk_points.size() - 2)
	if next_index >= _target_index:
		next_index += 1
	_target_index = next_index
	_walking = true
	play(&"move")


func _start_idle() -> void:
	_walking = false
	_wait_time = _rng.randf_range(2.2, 5.0)
	play(&"idle")


func _on_animation_finished() -> void:
	if animation == &"bark" or animation == &"lie":
		_start_idle()
