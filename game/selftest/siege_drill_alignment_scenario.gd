extends SceneTree

const SHOT_PATH: String = "res://artifacts/siege_drill_alignment/alignment.png"

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
	city.projectile_root.release_all()
	city.gameplay_hud.visible = false
	city.robot.set_physics_process(false)
	city.robot.global_position.x = 1300.0
	city.camera_rig.global_position.x = 1300.0
	var runtime: SiegeDrillRuntime = (
		city.upgrade_assembler.runtimes[&"SIEGE_DRILL"] as SiegeDrillRuntime
	)
	_check("rank_applies", runtime.apply_rank(1))
	_check("dash_starts", city.robot._start_dodge(1))
	runtime.set_physics_process(false)
	runtime.hitbox.advance()
	var robot_visual: AnimatedSprite2D = city.robot.get_node(
		SiegeDrillHitbox.ROBOT_VISUAL_PATH
	) as AnimatedSprite2D
	var drill_visual: Sprite2D = runtime.hitbox._visual
	_check(
		"drill_is_player_centered",
		is_equal_approx(runtime.hitbox.global_position.y, robot_visual.global_position.y)
	)
	_check(
		"drill_is_one_hundred_fifty_percent",
		drill_visual.scale.abs().is_equal_approx(Vector2.ONE * 1.5)
	)
	_check(
		"drill_display_size_is_scaled",
		(drill_visual.texture.get_size() * drill_visual.scale.abs()).is_equal_approx(
			Vector2(240.0, 168.0)
		)
	)
	await process_frame
	await physics_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://artifacts/siege_drill_alignment")
		)
		var image: Image = root.get_texture().get_image()
		var error: Error = image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
		_check("shot_saved", error == OK)
	city.queue_free()
	await process_frame
	var passed: bool = not _checks.has(false)
	print("[SIEGE-DRILL-ALIGNMENT-DONE] result=%s" % ["PASS" if passed else "FAIL"])
	quit(0 if passed else 1)


func _check(check_name: String, passed: bool) -> void:
	_checks.append(passed)
	print("[CHECK] %s %s" % ["PASS" if passed else "FAIL", check_name])
