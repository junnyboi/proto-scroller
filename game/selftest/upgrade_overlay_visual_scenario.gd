extends SceneTree

const MAX_FRAMES: int = 180
const SHOT_PATH: String = "res://artifacts/upgrades/upgrade-choice.png"

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
		push_error("Upgrade overlay visual scenario exceeded frame watchdog")
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
	var reward: GameplayEvent = GameplayEvent.new(
		&"upgrade-overlay-visual",
		1,
		GameplayEvent.Kind.ENEMY_DEFEATED,
		GameplayEvent.SOLDIER_LAUNCH,
		1500
	)
	if not city.rampage_session.publish(reward):
		quit(1)
		return
	await process_frame
	await RenderingServer.frame_post_draw
	if not city.gameplay_hud.upgrade_choice_overlay.visible:
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
		quit(0)
		return
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/upgrades")
	)
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
	if save_error != OK or image.get_size() != target_size:
		quit(1)
		return
	completed = true
	print("[UPGRADE-VISUAL-DONE] path=%s" % SHOT_PATH)
	quit(0)


func _target_size() -> Vector2i:
	if OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1":
		return Vector2i(720, 1280)
	return Vector2i(1280, 720)
