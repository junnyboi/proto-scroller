extends SceneTree

const SHOT_PATH: String = "res://artifacts/wreck_player_ejection/ejection.png"

var _checks: Array[bool] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_window().content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var scene: PackedScene = load("res://scenes/gameplay/city_slice.tscn") as PackedScene
	_check("city_scene_loads", scene != null)
	if scene == null:
		quit(1)
		return
	var city: CitySlice = scene.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	city.urban_siege.stop_run()
	city.encounter_runtime.release_all()
	city.enemy_remains_factory.release_all()
	city.gameplay_hud.visible = false
	city.robot.set_physics_process(false)
	city.robot.global_position.x = 1300.0
	city.camera_rig.global_position.x = 1300.0
	var enemy: EnemyActor2D = city.encounter_runtime.acquire(
		&"tank",
		city.robot.global_position
	)
	var event: DamageEvent = DamageEvent.new(
		91_001,
		city.robot,
		enemy.current_health,
		&"impact",
		enemy.global_position,
		Vector2.RIGHT,
		240.0
	)
	var wreck: EnemyWreck2D = city.enemy_remains_factory.spawn_wreck(enemy, event)
	city.encounter_runtime.release(enemy)
	_check("wreck_spawns", wreck != null)
	if wreck == null:
		city.queue_free()
		await process_frame
		quit(1)
		return
	var spawn_position: Vector2 = wreck.global_position
	_check("ejection_activates", wreck.is_player_overlap_ejecting())
	_check(
		"launches_upward",
		wreck.linear_velocity.y <= -EnemyWreck2D.PLAYER_OVERLAP_EJECTION_UPWARD_SPEED
	)
	_check(
		"launches_outward",
		wreck.linear_velocity.x >= EnemyWreck2D.PLAYER_OVERLAP_EJECTION_OUTWARD_SPEED
	)
	_check("robot_collision_suppressed", wreck.collision_mask & EnemyWreck2D.ROBOT_LAYER == 0)
	for frame: int in range(24):
		await physics_frame
	_check("wreck_rises_clear", wreck.global_position.y < spawn_position.y - 120.0)
	_check("wreck_moves_away", wreck.global_position.x > spawn_position.x + 120.0)
	_check("player_remains_stable", city.robot.global_position.x == 1300.0)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://artifacts/wreck_player_ejection")
		)
		var image: Image = root.get_texture().get_image()
		var error: Error = image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
		_check("shot_saved", error == OK)
	for frame: int in range(180):
		await physics_frame
		if not wreck.is_settling_to_road():
			break
	_check("ejection_completes", not wreck.is_player_overlap_ejecting())
	_check("robot_collision_restored", wreck.collision_mask & EnemyWreck2D.ROBOT_LAYER != 0)
	_check("wreck_lands", not wreck.is_settling_to_road())
	_check(
		"wreck_lands_elsewhere",
		absf(wreck.global_position.x - city.robot.global_position.x)
			> wreck.collision_size.x * 0.5 + 46.0
	)
	city.queue_free()
	await process_frame
	var passed: bool = not _checks.has(false)
	print("[WRECK-PLAYER-EJECTION-DONE] result=%s" % ["PASS" if passed else "FAIL"])
	quit(0 if passed else 1)


func _check(check_name: String, passed: bool) -> void:
	_checks.append(passed)
	print("[CHECK] %s %s" % ["PASS" if passed else "FAIL", check_name])
