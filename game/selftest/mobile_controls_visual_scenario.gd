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
		quit(1)
		return
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
		quit(0)
		return
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/mobile_controls")
	)
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
	if save_error != OK or image.get_size() != TARGET_SIZE:
		quit(1)
		return
	completed = true
	print("[MOBILE-CONTROLS-VISUAL-DONE] path=%s" % SHOT_PATH)
	quit(0)
