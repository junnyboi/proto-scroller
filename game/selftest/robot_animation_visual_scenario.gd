extends SceneTree

const OUTPUT_DIR: String = "res://artifacts/robot"
const VALID_POSES: Array[StringName] = [
	&"attack_e",
	&"attack_w",
	&"attack_se",
	&"attack_sw",
	&"idle_s",
	&"idle_n",
	&"walk_e",
	&"walk_w",
]


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var pose: StringName = StringName(OS.get_environment("PROTO_SCROLLER_ROBOT_POSE"))
	if pose not in VALID_POSES:
		push_error("Invalid robot pose: %s" % pose)
		quit(1)
		return
	var scene: PackedScene = load("res://scenes/gameplay/city_slice.tscn") as PackedScene
	var city: CitySlice = scene.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	city.robot.set_physics_process(false)
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	var sprite: AnimatedSprite2D = (
		city.robot.get_node(^"VisualRoot/RobotAnimatedSprite") as AnimatedSprite2D
	)
	city.robot.facing = -1 if pose.ends_with("w") or pose.ends_with("n") else 1
	city.robot.facing_changed.emit(city.robot.facing)
	sprite.play(pose)
	sprite.pause()
	var sample_frame: int = (
		0 if pose.begins_with("idle") else (12 if pose.begins_with("walk") else 11)
	)
	sprite.set_frame_and_progress(sample_frame, 0.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var output_path: String = "%s/%s.png" % [OUTPUT_DIR, pose]
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		push_error("Robot pose screenshot failed: %s" % save_error)
		quit(1)
		return
	print("[ROBOT-POSE-PASS] pose=%s size=%s" % [pose, image.get_size()])
	quit(0)
