extends SceneTree

const MAX_FRAMES: int = 180
const SHOT_PATH: String = (
	"res://artifacts/destruction_details/building-damage-details.png"
)

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
		push_error("Destruction detail visual scenario exceeded frame watchdog")
		quit(1)


func _run() -> void:
	var target_size: Vector2i = Vector2i(1280, 720)
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
	city.gameplay_hud.visible = false
	city.gameplay_hud.first_run_tutorial.visible = false
	city.camera_rig.set_physics_process(false)
	city.camera_rig.global_position.x = city.building.global_position.x
	var left_cell: Destructible2D = city.building.get_cell(0, 1)
	var top_cell: Destructible2D = city.building.get_cell(1, 0)
	var right_cell: Destructible2D = city.building.get_cell(2, 1)
	var center_cell: Destructible2D = city.building.get_cell(1, 1)
	_apply_damage(city, left_cell, 81_001, 16.0)
	_apply_damage(city, top_cell, 81_002, 60.0)
	_apply_damage(city, right_cell, 81_003, 60.0)
	_apply_damage(city, center_cell, 81_004, 10_000.0)
	await create_timer(1.0, false).timeout
	_apply_damage(city, left_cell, 81_005, 5.0)
	_apply_damage(city, top_cell, 81_006, 10.0)
	_apply_damage(city, right_cell, 81_007, 10.0)
	await create_timer(0.10, false).timeout
	await physics_frame
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
		quit(0)
		return
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/destruction_details")
	)
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
	if save_error != OK or image.get_size() != target_size:
		quit(1)
		return
	completed = true
	print("[DESTRUCTION-DETAIL-VISUAL-DONE] path=%s" % SHOT_PATH)
	quit(0)


func _apply_damage(
	city: CitySlice,
	cell: Destructible2D,
	attack_id: int,
	damage: float
) -> void:
	var event: DamageEvent = DamageEvent.new(
		attack_id,
		city.robot,
		damage,
		&"jab_cross",
		cell.global_position,
		Vector2.RIGHT,
		900.0
	)
	cell.receive_damage(event)
