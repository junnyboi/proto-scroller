extends SceneTree

const MAX_FRAMES: int = 180
const TARGET_SIZE: Vector2i = Vector2i(720, 1280)
const SHOT_PATH: String = "res://artifacts/mobile_controls/mobile-controls-portrait.png"

var elapsed_frames: int = 0
var completed: bool = false


func _initialize() -> void:
	process_frame.connect(_on_process_frame)
	call_deferred("_run")


func _on_process_frame() -> void:
	if completed:
		return
	elapsed_frames += 1
	if elapsed_frames > MAX_FRAMES:
		push_error("Mobile controls visual scenario exceeded frame watchdog")
		quit(1)


func _run() -> void:
	root.get_window().content_scale_size = TARGET_SIZE
	root.size = TARGET_SIZE
	var scene: PackedScene = load("res://scenes/gameplay/city_slice.tscn") as PackedScene
	if scene == null:
		quit(1)
		return
	var city: CitySlice = scene.instantiate() as CitySlice
	city.mobile_detection_override = 1
	root.add_child(city)
	await process_frame
	await physics_frame
	city.robot.set_physics_process(false)
	city.robot.collision_mask = 0
	city.robot.gravity = 0.0
	var controls: MobileControls = city.mobile_controls
	var dash_rect: Rect2 = controls.dash_bounds()
	var smash_rect: Rect2 = controls.smash_bounds()
	if (
		not controls.visible
		or controls.dash_button.text != L10n.t("mobile.dash")
		or dash_rect.intersects(smash_rect)
		or dash_rect.end.y >= smash_rect.position.y
	):
		push_error("Mobile DASH button failed portrait layout contract")
		await _finish_city(city, 1)
		return
	if not city.robot._start_dodge():
		push_error("Mobile DASH button could not start cooldown")
		await _finish_city(city, 1)
		return
	city.robot.physics_step(0.0, city.robot.dodge_cooldown_seconds + 0.01)
	controls.process_controls(0.15)
	if (
		not controls.dash_ready_feedback_active()
		or controls.dash_ready_pulse_count() != 1
		or controls.dash_button.scale.x <= 1.08
	):
		push_error("Mobile DASH button failed ready-pulse contract")
		await _finish_city(city, 1)
		return
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
		await _finish_city(city, 0)
		return
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/mobile_controls")
	)
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
	if save_error != OK or image.get_size() != TARGET_SIZE:
		await _finish_city(city, 1)
		return
	print("[MOBILE-CONTROLS-VISUAL-DONE] path=%s" % SHOT_PATH)
	await _finish_city(city, 0)


func _finish_city(city: CitySlice, exit_code: int) -> void:
	completed = true
	_stop_audio(city)
	city.queue_free()
	await process_frame
	await process_frame
	quit(exit_code)


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		var player: AudioStreamPlayer = node as AudioStreamPlayer
		player.stop()
		player.stream = null
	elif node is AudioStreamPlayer2D:
		var player_2d: AudioStreamPlayer2D = node as AudioStreamPlayer2D
		player_2d.stop()
		player_2d.stream = null
	for child: Node in node.get_children():
		_stop_audio(child)
