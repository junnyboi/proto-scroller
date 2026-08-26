extends SceneTree

const MAX_FRAMES: int = 240
const SHOT_PATH: String = "res://artifacts/weapon_shop/weapon-shop.png"
const INTRO_PATH: String = "res://artifacts/weapon_shop/weapon-shop-intro.png"
const WARNING_PATH: String = "res://artifacts/weapon_shop/weapon-shop-warning.png"
const CONFIRM_PATH: String = "res://artifacts/weapon_shop/weapon-shop-confirm.png"

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
		push_error("Weapon shop visual scenario exceeded frame watchdog")
		quit(1)


func _run() -> void:
	var target_size: Vector2i = _target_size()
	root.get_window().content_scale_size = target_size
	root.size = target_size
	var scene: PackedScene = load("res://scenes/gameplay/city_slice.tscn") as PackedScene
	assert(scene != null, "CitySlice scene must load for shop visual verification")
	var city: CitySlice = scene.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	city.rampage_session.run_score.safe_score = 14_000
	city._on_score_changed(14_000, 0)
	city.robot.current_health = 58.0
	city.robot.health_changed.emit(city.robot.current_health, city.robot.max_health)
	city.urban_siege.act_completed.emit(0, &"CONTACT", "encounter.contact")
	await process_frame
	await RenderingServer.frame_post_draw
	var overlay: WeaponShopOverlay = city.weapon_shop_assembler.overlay
	if not overlay.visible or not overlay.dialogue_panel.active:
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
		quit(0)
		return
	if not _save_frame(INTRO_PATH, target_size):
		quit(1)
		return
	overlay.dialogue_panel._dismiss()
	overlay.cards[1]._on_pressed()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	if (
		overlay.insufficient_warning_count != 1
		or not overlay.insufficient_flash.visible
		or not _save_frame(WARNING_PATH, target_size)
	):
		quit(1)
		return
	overlay.cards[2]._request_preview()
	await process_frame
	await RenderingServer.frame_post_draw
	if not overlay.preview_panel.visible or not _save_frame(SHOT_PATH, target_size):
		quit(1)
		return
	overlay.cards[2]._on_pressed()
	await process_frame
	await RenderingServer.frame_post_draw
	if not overlay.confirmation_panel.active or not _save_frame(CONFIRM_PATH, target_size):
		quit(1)
		return
	completed = true
	print("[WEAPON-SHOP-VISUAL-DONE] shop=%s intro=%s warning=%s confirm=%s" % [
		SHOT_PATH,
		INTRO_PATH,
		WARNING_PATH,
		CONFIRM_PATH,
	])
	quit(0)


func _save_frame(path: String, target_size: Vector2i) -> bool:
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/weapon_shop")
	)
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(path))
	return save_error == OK and image.get_size() == target_size


func _target_size() -> Vector2i:
	if OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1":
		return Vector2i(720, 1280)
	return Vector2i(1280, 720)
