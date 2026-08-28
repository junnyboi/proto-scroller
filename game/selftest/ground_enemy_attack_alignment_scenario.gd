extends SceneTree

const REPORT_PATH: String = "res://artifacts/ground_enemy_attack_alignment/report.json"
const SHOT_PATH: String = "res://artifacts/ground_enemy_attack_alignment/alignment.png"

var checks: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_window().content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var scene: PackedScene = load("res://scenes/gameplay/city_slice.tscn") as PackedScene
	_check("city_scene_loads", scene != null, "loaded=%s" % [scene != null])
	if scene == null:
		_finish("SKIP", "")
		return
	var city: CitySlice = scene.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	city.urban_siege.stop_run()
	city.encounter_runtime.release_all()
	city.projectile_root.release_all()
	city.robot.global_position.x = 1300.0
	city.camera_rig.global_position.x = 1300.0
	city.gameplay_hud.visible = false
	var attack_cases: Array[Dictionary] = [
		{"id": &"covenant_warden", "x": 800.0, "authored": true},
		{
			"id": &"goliath",
			"support": &"reclaimed_breacher",
			"x": 1040.0,
			"authored": false,
		},
		{"id": &"soldier", "x": 1280.0, "authored": false},
		{"id": &"lobber", "x": 1510.0, "authored": false},
		{"id": &"tank", "x": 1810.0, "authored": false},
	]
	for attack_case: Dictionary in attack_cases:
		var archetype_id: StringName = StringName(attack_case.id)
		var support_id: StringName = StringName(attack_case.get("support", &""))
		var check_id: StringName = support_id if not support_id.is_empty() else archetype_id
		var enemy: EnemyActor2D = city.encounter_runtime.acquire(
			archetype_id,
			Vector2(float(attack_case.x), 540.0)
		)
		_check("%s_acquires" % check_id, enemy != null, "id=%s" % archetype_id)
		if enemy == null:
			continue
		if not support_id.is_empty():
			_check(
				"%s_reskins" % check_id,
				enemy is ProceduralEnemy
				and (enemy as ProceduralEnemy).configure_boss_support(support_id),
				"shell=%s support=%s" % [archetype_id, support_id]
			)
		enemy.set_physics_process(false)
		_begin_attack(enemy)
		_check(
			"%s_telegraphs" % check_id,
			enemy.is_telegraphing(),
			"origin=%s" % enemy.telegraph_origin()
		)
		var procedural_visible: bool = city.telegraph_presenter.uses_procedural_rendering(
			enemy._telegraph_id
		)
		_check(
			"%s_presentation_route" % check_id,
			procedural_visible != bool(attack_case.authored),
			"authored=%s procedural=%s" % [attack_case.authored, procedural_visible]
		)
		if bool(attack_case.authored) and enemy is ProceduralEnemy:
			var procedural: ProceduralEnemy = enemy as ProceduralEnemy
			_check(
				"%s_sprite_matches_origin" % check_id,
				procedural._presentation_sprites[0].global_position == enemy.telegraph_origin(),
				"sprite=%s origin=%s" % [
					procedural._presentation_sprites[0].global_position,
					enemy.telegraph_origin(),
				]
			)
	await process_frame
	await physics_frame
	var shot_status: String = "SKIP"
	var shot_path: String = ""
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://artifacts/ground_enemy_attack_alignment")
		)
		var image: Image = root.get_texture().get_image()
		var error: Error = image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
		_check("shot_saved", error == OK, "error=%s" % error)
		_check("shot_geometry", image.get_size() == Vector2i(1280, 720), "size=%s" % image.get_size())
		shot_status = "PASS" if error == OK else "FAIL"
		shot_path = SHOT_PATH
	city.queue_free()
	await process_frame
	OS.delay_msec(100)
	_finish(shot_status, shot_path)


func _begin_attack(enemy: EnemyActor2D) -> void:
	if enemy is SoldierEnemy:
		(enemy as SoldierEnemy)._begin_fire()
	elif enemy is TankEnemy:
		(enemy as TankEnemy)._begin_shell()
	elif enemy is ProceduralEnemy:
		(enemy as ProceduralEnemy)._begin_attack()


func _check(check_name: String, passed: bool, detail: String) -> void:
	checks.append({"name": check_name, "passed": passed, "detail": detail})
	print("[CHECK] %s %s — %s" % ["PASS" if passed else "FAIL", check_name, detail])


func _finish(shot_status: String, shot_path: String) -> void:
	var all_passed: bool = true
	for item: Dictionary in checks:
		if not bool(item.passed):
			all_passed = false
	var report: Dictionary = {
		"scenario": "ground_enemy_attack_alignment",
		"result": "PASS" if all_passed else "FAIL",
		"checks": checks,
		"shot": {"status": shot_status, "path": shot_path},
	}
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/ground_enemy_attack_alignment")
	)
	var report_file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(report, "\t"))
		report_file.close()
	print("[GROUND-ATTACK-ALIGNMENT-DONE] result=%s" % report.result)
	quit(0 if all_passed else 1)
