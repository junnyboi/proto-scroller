extends SceneTree

const MAX_FRAMES: int = 180
const SHOT_PATH: String = "res://artifacts/match_debrief/match-debrief.png"
const REPORT_PATH: String = "res://artifacts/match_debrief/report.json"

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
		_finish(false, "frame watchdog")


func _run() -> void:
	L10n.set_locale("en")
	var target_size: Vector2i = _target_size()
	root.get_window().content_scale_size = target_size
	root.size = target_size
	var scene: PackedScene = load("res://scenes/gameplay/city_slice.tscn") as PackedScene
	if scene == null:
		_finish(false, "city scene missing")
		return
	var city: CitySlice = scene.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	city.gameplay_hud.first_run_tutorial._finish_tutorial(true)
	city.encounter_runtime.release_all()
	city.encounter_director.process_mode = Node.PROCESS_MODE_DISABLED
	city.gameplay_hud._set_campaign_summary(25, 2)
	var summary: RunSummarySnapshot = RunSummarySnapshot.new(
		874_200,
		5,
		24,
		6,
		4,
		{&"SKYBREAKER": 3},
		{
			"completed": true,
			"grade": &"S",
			"mastery_points": 982,
			"objective": "summary.retry.reach_next_act",
			"cycle_count": 2,
			"highest_combo_tier": 12,
			"total_enemies_defeated": 78,
			"unique_enemy_types": 14,
			"enemy_kills": {
				&"covenant_warden": 12,
				&"choir_siren": 10,
				&"pale_engine": 8,
				&"tank": 7,
				&"needle": 6,
			},
			"weapon_kills": {
				&"GROUND_SMASH": 42,
				&"MISSILE": 18,
				&"JAB_CROSS": 11,
				&"LASER": 7,
			},
			"preferred_weapon": &"GROUND_SMASH",
			"preferred_weapon_kills": 42,
		}
	).with_career_result({
		"new_combo_record": true,
		"new_score_record": true,
		"career_snapshot": {
			"best_score": 874_200,
			"highest_combo_tier": 12,
			"total_enemy_kills": 784,
			"total_runs": 34,
			"victories": 27,
		},
	})
	city.gameplay_hud.show_district_complete(summary)
	for _frame: int in range(4):
		await process_frame
	var panel: MatchDebriefPanel = city.gameplay_hud.match_debrief
	var snapshot: Dictionary = panel.debug_snapshot()
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(target_size))
	var valid: bool = (
		panel.is_visible_in_tree()
		and String(snapshot.result) == "DISTRICT CLEARED"
		and String(snapshot.combo).contains("EXTINCTION EVENT")
		and bool(snapshot.personal_best)
		and (snapshot.weapon_rows as PackedStringArray).size() == 3
		and (snapshot.enemy_rows as PackedStringArray).size() == 4
		and viewport_rect.encloses(snapshot.panel_rect as Rect2)
		and viewport_rect.encloses(snapshot.retry_rect as Rect2)
		and viewport_rect.encloses(snapshot.title_rect as Rect2)
	)
	if not valid:
		_finish(false, JSON.stringify(snapshot))
		return
	if DisplayServer.get_name() == "headless":
		_finish(true, "headless geometry pass")
		panel.hide_panel()
		city.queue_free()
		await process_frame
		await process_frame
		quit(0)
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/match_debrief")
	)
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
	if save_error != OK or image.get_size() != target_size:
		_finish(false, "shot error=%s size=%s" % [save_error, image.get_size()])
		return
	var report: Dictionary = {
		"result": "PASS",
		"viewport": {"width": target_size.x, "height": target_size.y},
		"summary": {
			"score": summary.score,
			"highest_combo_tier": summary.highest_combo_tier,
			"total_enemy_kills": summary.total_enemies_defeated,
			"unique_enemy_types": summary.unique_enemy_types,
			"preferred_weapon": String(summary.preferred_weapon),
		},
		"layout": _json_safe_snapshot(snapshot),
		"shot": SHOT_PATH,
	}
	var report_file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if report_file == null:
		_finish(false, "report open failed")
		return
	report_file.store_string(JSON.stringify(report, "  "))
	report_file.close()
	_finish(true, SHOT_PATH)
	panel.hide_panel()
	city.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _finish(success: bool, detail: String) -> void:
	if completed:
		return
	completed = true
	print("[MATCH-DEBRIEF-VISUAL-%s] %s" % ["PASS" if success else "FAIL", detail])
	if not success:
		quit(1)


func _target_size() -> Vector2i:
	if OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1":
		return Vector2i(720, 1280)
	return Vector2i(1280, 720)


func _json_safe_snapshot(snapshot: Dictionary) -> Dictionary:
	return {
		"visible": bool(snapshot.visible),
		"result": String(snapshot.result),
		"combo": String(snapshot.combo),
		"personal_best": bool(snapshot.personal_best),
		"weapon_rows": Array(snapshot.weapon_rows as PackedStringArray),
		"enemy_rows": Array(snapshot.enemy_rows as PackedStringArray),
		"panel_rect": _rect_dictionary(snapshot.panel_rect as Rect2),
		"retry_rect": _rect_dictionary(snapshot.retry_rect as Rect2),
		"title_rect": _rect_dictionary(snapshot.title_rect as Rect2),
	}


func _rect_dictionary(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x,
		"height": rect.size.y,
	}
