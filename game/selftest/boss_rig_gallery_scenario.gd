extends SceneTree

const ARTIFACT_DIR: String = "res://artifacts/boss_rig_gallery"

var _checks: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var portrait: bool = OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1"
	var target_size: Vector2i = Vector2i(720, 1280) if portrait else Vector2i(1280, 720)
	root.content_scale_size = target_size
	root.size = target_size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	var gallery: Node2D = Node2D.new()
	gallery.name = "BossRigGallery"
	root.add_child(gallery)
	var background: ColorRect = ColorRect.new()
	background.size = Vector2(target_size)
	background.color = Color("07111d")
	gallery.add_child(background)
	var host: EnemyActor2D = EnemyActor2D.new()
	host.name = "GalleryAuthority"
	gallery.add_child(host)
	await process_frame
	var definition_ids: Array[String] = []
	var mechanical_signatures: Array[Dictionary] = []
	for index: int in range(BossCampaignCatalog.DEFINITION_COUNT):
		var definition: BossEncounterDefinition = BossCampaignCatalog.definitions()[index]
		var rig: BossRig2D = BossRig2D.new()
		rig.name = String(definition.boss_id)
		gallery.add_child(rig)
		rig.configure(definition, host, portrait)
		rig.position = _gallery_position(index, portrait)
		var scale_value: float = 0.54 if portrait else 0.46
		rig.scale = Vector2.ONE * scale_value
		definition_ids.append(String(definition.boss_id))
		mechanical_signatures.append(rig.mechanical_signature())
		_check("%s_texture" % definition.boss_id, rig.parts[0].texture != null)
		_check("%s_weak_point" % definition.boss_id, rig.socket(&"WEAK_POINT") != null)
		_check(
			"%s_hurt_regions" % definition.boss_id,
			rig.active_hurt_region_count == BossRig2D.HURT_REGION_CAPACITY
		)
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var orientation: String = "portrait" if portrait else "landscape"
	var shot: String = ""
	if DisplayServer.get_name() != "headless":
		shot = "%s/boss-rig-gallery-%s.png" % [ARTIFACT_DIR, orientation]
		var image: Image = root.get_texture().get_image()
		_check(
			"shot_saved",
			image.save_png(ProjectSettings.globalize_path(shot)) == OK
		)
	var report: Dictionary = {
		"done": true,
		"result": "PASS" if _all_passed() else "FAIL",
		"orientation": orientation,
		"boss_ids": definition_ids,
		"mechanical_signatures": mechanical_signatures,
		"checks": _checks,
		"shot": shot,
	}
	var report_path: String = "%s/report-%s.json" % [ARTIFACT_DIR, orientation]
	var file: FileAccess = FileAccess.open(
		ProjectSettings.globalize_path(report_path),
		FileAccess.WRITE
	)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
	quit(0 if _all_passed() else 1)


func _gallery_position(index: int, portrait: bool) -> Vector2:
	if portrait:
		return Vector2(360.0, 190.0 + float(index) * 230.0)
	return Vector2(145.0 + float(index) * 250.0, 570.0)


func _check(name: String, passed: bool) -> void:
	_checks.append({"name": name, "passed": passed})
	print("[CHECK] %s %s" % ["PASS" if passed else "FAIL", name])


func _all_passed() -> bool:
	for check: Dictionary in _checks:
		if not bool(check.passed):
			return false
	return true
