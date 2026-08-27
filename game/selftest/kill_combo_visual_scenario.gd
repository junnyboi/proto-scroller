extends SceneTree

const MAX_FRAMES: int = 180
const SHOT_PATH: String = "res://artifacts/kill_combo/kill-combo.png"

var elapsed_frames: int = 0
var completed: bool = false


func _initialize() -> void:
	process_frame.connect(_on_process_frame)
	call_deferred(&"_run")


func _on_process_frame() -> void:
	if completed:
		return
	elapsed_frames += 1
	if elapsed_frames > MAX_FRAMES:
		push_error("Kill combo visual scenario exceeded frame watchdog")
		quit(1)


func _run() -> void:
	var target_size: Vector2i = _target_size()
	root.get_window().content_scale_size = target_size
	root.size = target_size
	var scene: PackedScene = load("res://scenes/gameplay/city_slice.tscn") as PackedScene
	if scene == null:
		quit(1)
		return
	var city: CitySlice = scene.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	city.gameplay_hud.first_run_tutorial._finish_tutorial(true)
	city.encounter_runtime.release_all()
	city.encounter_director.process_mode = Node.PROCESS_MODE_DISABLED
	for index: int in range(10):
		if not city.rampage_session.publish(GameplayEvent.new(
			StringName("visual_herald_%02d" % index),
			91_000 + index,
			GameplayEvent.Kind.ENEMY_DEFEATED,
			GameplayEvent.ENEMY_KILL,
			100,
			0.0,
			true
		)):
			quit(1)
			return
	for _frame: int in range(9):
		await process_frame
	await RenderingServer.frame_post_draw
	var herald: ComboHerald = city.gameplay_hud.combo_herald
	if (
		city.rampage_session.current_multiplier() != 5
		or city.score != 4000
		or city.gameplay_hud.combo_label.text != "x5 KILL COMBO"
		or not city.gameplay_hud.combo_label.visible
		or herald.last_tier != 10
		or herald.title_label.text != "EXTINCTION EVENT"
		or herald.presentation_count != 6
		or herald.audio_play_count != 6
		or herald.supersession_count != 5
		or not herald.is_presenting()
	):
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
		quit(0)
		return
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/kill_combo")
	)
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
	if save_error != OK or image.get_size() != target_size:
		quit(1)
		return
	completed = true
	print("[KILL-COMBO-VISUAL-DONE] shot=%s" % SHOT_PATH)
	herald.dismiss()
	city.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _target_size() -> Vector2i:
	if OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1":
		return Vector2i(720, 1280)
	return Vector2i(1280, 720)
