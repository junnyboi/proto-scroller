class_name Main
extends Node

const TITLE_SCENE: PackedScene = preload("res://scenes/title_screen.tscn")
const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const RESPONSIVE_VIEWPORT_SCRIPT: Script = preload(
	"res://scripts/main/responsive_viewport.gd"
)
const DUMMY_AUDIO_DRIVER_NAME: String = "Dummy"
const FADE_TO_BLACK_SECONDS: float = 0.45
const FADE_FROM_BLACK_SECONDS: float = 0.35

var title_screen: TitleScreen
var city_slice: CitySlice
var responsive_viewport: ResponsiveViewport
var title_transition_active: bool = false
var title_transition_duration_scale: float = 1.0
var _title_transition_started_msec: int = 0
@onready var background_music_player: AudioStreamPlayer = %BackgroundMusicPlayer
@onready var transition_overlay: ColorRect = %TransitionOverlay


func _ready() -> void:
	InputBindingSettings.apply_saved()
	AudioVolumeSettings.apply_saved()
	responsive_viewport = RESPONSIVE_VIEWPORT_SCRIPT.new() as ResponsiveViewport
	responsive_viewport.name = "ResponsiveViewport"
	add_child(responsive_viewport)
	responsive_viewport.setup()
	_show_title()
	_publish_title_transition_phase("idle")
	_start_background_music()
	if not background_music_player.tree_exiting.is_connected(_release_background_music):
		background_music_player.tree_exiting.connect(_release_background_music)


func _exit_tree() -> void:
	_release_background_music()


func _release_background_music() -> void:
	if not is_instance_valid(background_music_player):
		return
	background_music_player.stop()
	background_music_player.stream = null


func background_music_output_available() -> bool:
	return _background_music_output_available_for_environment(
		AudioServer.get_driver_name(),
		OS.has_feature("web")
	)


func _background_music_output_available_for_environment(
	driver_name: String,
	is_web: bool
) -> bool:
	return is_web or driver_name != DUMMY_AUDIO_DRIVER_NAME


func _start_background_music() -> void:
	if not background_music_output_available():
		return
	if background_music_player.stream != null and not background_music_player.playing:
		background_music_player.play()


func start_game() -> void:
	_start_background_music()
	if city_slice != null:
		return
	if title_screen != null:
		title_screen.queue_free()
		title_screen = null
	_spawn_city_slice()


func start_game_with_transition() -> void:
	if city_slice != null or title_transition_active:
		return
	title_transition_active = true
	_title_transition_started_msec = Time.get_ticks_msec()
	transition_overlay.visible = true
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_overlay.modulate.a = 0.0
	_publish_title_transition_phase("fade_out")
	await _fade_transition_overlay(1.0, FADE_TO_BLACK_SECONDS)
	_publish_title_transition_phase("black")
	start_game()
	await get_tree().process_frame
	_publish_title_transition_phase("black_ready")
	await _await_web_transition_capture_release()
	_publish_title_transition_phase("fade_in")
	await _fade_transition_overlay(0.0, FADE_FROM_BLACK_SECONDS)
	transition_overlay.visible = false
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_transition_active = false
	_publish_title_transition_phase("complete")


func retry_game() -> void:
	if city_slice != null:
		var previous_city: CitySlice = city_slice
		city_slice = null
		remove_child(previous_city)
		previous_city.queue_free()
	_spawn_city_slice()


func _spawn_city_slice() -> void:
	city_slice = CITY_SCENE.instantiate() as CitySlice
	city_slice.name = "CitySlice"
	city_slice.retry_requested.connect(retry_game)
	add_child(city_slice)


func _show_title() -> void:
	title_screen = TITLE_SCENE.instantiate() as TitleScreen
	title_screen.start_requested.connect(start_game_with_transition)
	add_child(title_screen)


func _fade_transition_overlay(target_alpha: float, duration_seconds: float) -> void:
	var scaled_duration: float = maxf(
		duration_seconds * title_transition_duration_scale,
		0.001
	)
	var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(transition_overlay, "modulate:a", target_alpha, scaled_duration)
	await tween.finished


func _await_web_transition_capture_release() -> void:
	if not OS.has_feature("web"):
		return
	while bool(JavaScriptBridge.eval("Boolean(window.__PROTO_SCROLLER_HOLD_TITLE_TRANSITION__)")):
		await get_tree().process_frame


func _publish_title_transition_phase(phase: String) -> void:
	if not OS.has_feature("web"):
		return
	var elapsed_msec: int = (
		0
		if _title_transition_started_msec == 0
		else Time.get_ticks_msec() - _title_transition_started_msec
	)
	var payload: String = JSON.stringify({"phase": phase, "elapsedMs": elapsed_msec})
	JavaScriptBridge.eval(
		"window.__PROTO_SCROLLER_TITLE_TRANSITION__ ??= {phases: []};"
		+ "window.__PROTO_SCROLLER_TITLE_TRANSITION__.phase = %s.phase;" % payload
		+ "window.__PROTO_SCROLLER_TITLE_TRANSITION__.elapsedMs = %s.elapsedMs;" % payload
		+ "window.__PROTO_SCROLLER_TITLE_TRANSITION__.phases.push(%s);" % payload
	)
