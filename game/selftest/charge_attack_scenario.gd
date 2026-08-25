extends SceneTree

const REPORT_PATH: String = "res://artifacts/charge_attack/report.json"
const SHOT_PATH: String = "res://artifacts/charge_attack/charge-attack.png"
const MAX_FRAMES: int = 600

var checks: Array[Dictionary] = []
var completed: bool = false
var elapsed_frames: int = 0


func _initialize() -> void:
	process_frame.connect(_on_process_frame)
	call_deferred("_run")


func _on_process_frame() -> void:
	if completed:
		return
	elapsed_frames += 1
	if elapsed_frames > MAX_FRAMES:
		_check("frame_watchdog", false, "frames=%d" % elapsed_frames)
		_finish("SKIP", "")


func _run() -> void:
	var target_size: Vector2i = _target_size()
	root.get_window().content_scale_size = target_size
	root.size = target_size
	var scene: PackedScene = load("res://scenes/gameplay/city_slice.tscn") as PackedScene
	_check("city_scene_loads", scene != null, "loaded=%s" % [scene != null])
	if scene == null:
		_finish("SKIP", "")
		return
	var city: CitySlice = scene.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	await physics_frame
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	city.robot.set_physics_process(false)
	city.contextual_attacks.set_process(false)
	city.robot.global_position = Vector2(760.0, 460.0)
	city.robot.velocity.x = city.robot.max_speed
	var presenter: RobotAnimationPresenter = city.robot.get_node(
		^"RobotAnimationPresenter"
	) as RobotAnimationPresenter
	var sprite: AnimatedSprite2D = city.robot.get_node(
		^"VisualRoot/RobotAnimatedSprite"
	) as AnimatedSprite2D
	var particles: CPUParticles2D = city.robot.get_node(
		^"VisualRoot/MeleeChargeParticles"
	) as CPUParticles2D
	var baseline_nodes: int = int(RuntimeBudget.snapshot(city).node_count)
	var attack_id: int = city.contextual_attacks.begin_charge()
	city.contextual_attacks._process(1.5)
	for settle_frame: int in range(12):
		await process_frame
	_check("charge_started", attack_id > 0, "attack_id=%d" % attack_id)
	_check(
		"jab_cross_selected",
		city.contextual_attacks.current_spec != null
		and city.contextual_attacks.current_spec.is_jab_cross(),
		"spec=%s" % city.contextual_attacks.current_spec
	)
	_check(
		"first_frame_frozen",
		sprite.animation == &"attack_e" and sprite.frame == 0 and not sprite.is_playing(),
		"animation=%s frame=%d playing=%s" % [sprite.animation, sprite.frame, sprite.is_playing()]
	)
	_check(
		"charge_progress",
		is_equal_approx(city.contextual_attacks.charge_progress(), 0.75),
		"progress=%.3f" % city.contextual_attacks.charge_progress()
	)
	_check(
		"golden_particles_converge",
		presenter.charge_particles_emitting()
		and particles.color == RobotAnimationPresenter.CHARGE_PARTICLE_COLOR
		and particles.radial_accel_max < 0.0,
		"emitting=%s color=%s radial=%.1f"
		% [particles.emitting, particles.color, particles.radial_accel_max]
	)
	_check(
		"fixed_node_budget",
		int(RuntimeBudget.snapshot(city).node_count) == baseline_nodes,
		"baseline=%d current=%d"
		% [baseline_nodes, int(RuntimeBudget.snapshot(city).node_count)]
	)
	var shot_status: String = "SKIP"
	var shot_path: String = ""
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
	else:
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://artifacts/charge_attack")
		)
		var save_error: Error = image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
		_check("shot_saved", save_error == OK, "error=%s" % save_error)
		_check(
			"shot_geometry",
			image.get_size() == target_size,
			"size=%s expected=%s" % [image.get_size(), target_size]
		)
		shot_status = "PASS" if save_error == OK else "FAIL"
		shot_path = SHOT_PATH
	var released: bool = city.contextual_attacks.release_charge()
	_check("charge_released", released, "released=%s" % released)
	_check(
		"damage_scaled",
		city.contextual_attacks.current_spec != null
		and is_equal_approx(city.contextual_attacks.current_spec.actor_damage, 253.75),
		"damage=%.2f"
		% (
			city.contextual_attacks.current_spec.actor_damage
			if city.contextual_attacks.current_spec != null
			else 0.0
		)
	)
	_check(
		"animation_resumed",
		sprite.is_playing() and not presenter.charge_particles_emitting(),
		"playing=%s particles=%s" % [sprite.is_playing(), particles.emitting]
	)
	_check("frame_budget", elapsed_frames <= MAX_FRAMES, "frames=%d" % elapsed_frames)
	city.queue_free()
	await process_frame
	# Work around godotengine/godot#76745 in fixed-FPS command-line runs.
	OS.delay_msec(100)
	_finish(shot_status, shot_path)


func _target_size() -> Vector2i:
	return (
		Vector2i(720, 1280)
		if OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1"
		else Vector2i(1280, 720)
	)


func _check(check_name: String, passed: bool, detail: String) -> void:
	checks.append({"name": check_name, "passed": passed, "detail": detail})
	print("[CHECK] %s %s — %s" % ["PASS" if passed else "FAIL", check_name, detail])


func _finish(shot_status: String, shot_path: String) -> void:
	if completed:
		return
	completed = true
	var all_passed: bool = true
	for check: Dictionary in checks:
		all_passed = all_passed and bool(check.passed)
	var report: Dictionary = {
		"done": true,
		"result": "PASS" if all_passed else "FAIL",
		"checks": checks,
		"shot": {"status": shot_status, "path": shot_path},
		"frames": elapsed_frames,
	}
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/charge_attack")
	)
	var report_file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "\t"))
	print("[CHARGE-SCENARIO-DONE] result=%s" % report.result)
	quit(0 if all_passed else 1)
