extends SceneTree

const MAX_FRAMES: int = 240
const RANK_ONE_PATH: String = "res://artifacts/weapon_drones/weapon-drones-rank-one.png"
const MAX_RANK_PATH: String = "res://artifacts/weapon_drones/weapon-drones-max-rank.png"
const WEAPON_KEYS: Array[StringName] = [
	&"MACHINE_GUN",
	&"MISSILE",
	&"LASER",
	&"FLAMETHROWER",
]

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
		push_error("Weapon drone visual scenario exceeded frame watchdog")
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
	city.robot.set_physics_process(false)
	city.encounter_runtime.release_all()
	var orbit: WeaponDroneOrbit2D = city.upgrade_assembler.drone_orbit
	orbit.set_process(false)
	orbit.orbit_angle = -PI * 0.5
	for weapon_key: StringName in WEAPON_KEYS:
		var runtime: UpgradeRuntime = city.upgrade_assembler.runtimes[weapon_key]
		runtime.apply_rank(1)
	orbit.refresh_layout()
	await physics_frame
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
		quit(0)
		return
	if not _capture(RANK_ONE_PATH, target_size):
		quit(1)
		return
	for weapon_key: StringName in WEAPON_KEYS:
		var runtime: UpgradeRuntime = city.upgrade_assembler.runtimes[weapon_key]
		runtime.apply_rank(runtime.runtime_max_rank)
	orbit.orbit_angle = -PI * 0.5
	orbit.refresh_layout()
	await physics_frame
	await RenderingServer.frame_post_draw
	if not _capture(MAX_RANK_PATH, target_size):
		quit(1)
		return
	completed = true
	print("[WEAPON-DRONE-VISUAL-DONE] rank_one=%s max_rank=%s" % [
		RANK_ONE_PATH,
		MAX_RANK_PATH,
	])
	quit(0)


func _capture(path: String, expected_size: Vector2i) -> bool:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/weapon_drones")
	)
	var image: Image = root.get_texture().get_image()
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(path))
	return save_error == OK and image.get_size() == expected_size


func _target_size() -> Vector2i:
	if OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1":
		return Vector2i(720, 1280)
	return Vector2i(1280, 720)
