extends SceneTree

const ARTIFACT_DIR: String = "res://artifacts/boss_attack_matrix"

var _checks: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	var pool: BossUtilityPool = BossUtilityPool.new()
	root.add_child(pool)
	var facade_rows: int = 0
	for definition: BossEncounterDefinition in BossCampaignCatalog.definitions():
		for mask: int in range(BossStructuralAdapter.MASK_COUNT):
			var binding: Dictionary = pool.arena_adapter.binding_for_mask(
				mask,
				definition.arena_cell_indices
			)
			_check(
				"%s_mask_%02d" % [definition.boss_id, mask],
				bool(binding.lower_passage)
				and bool(binding.visible_weak_point)
				and bool(binding.direct_damage_route)
				and bool(binding.valid_finisher_receiver)
			)
			facade_rows += 1
	_check("facade_matrix_rows", facade_rows == 320)
	_check(
		"safe_gap_exact",
		BossPhaseRuntime.has_safe_gap(
			[Vector2(0.0, 120.0), Vector2(300.0, 500.0), Vector2(700.0, 1000.0)],
			Vector2(0.0, 1000.0),
			200.0
		)
	)
	var wreck: EnemyWreck2D = EnemyWreck2D.new()
	root.add_child(wreck)
	await process_frame
	var fatal: DamageEvent = DamageEvent.new(
		8001,
		null,
		999.0,
		&"impact",
		Vector2.ZERO,
		Vector2.RIGHT,
		0.0,
		8000
	)
	wreck.activate(
		&"tank",
		null,
		Vector2(235.0, 100.0),
		Vector2(220.0, 78.0),
		65.0,
		110.0,
		Vector2.ZERO,
		fatal,
		false,
		true
	)
	_check("fatal_attack_rejected", not wreck.receive_damage(DamageEvent.new(
		8001, null, 999.0, &"ground_smash", Vector2.ZERO, Vector2.RIGHT, 0.0, 9001
	)))
	_check("fatal_root_rejected", not wreck.receive_damage(DamageEvent.new(
		8002, null, 999.0, &"ground_smash", Vector2.ZERO, Vector2.RIGHT, 0.0, 8000
	)))
	_check("non_smash_rejected", not wreck.receive_damage(DamageEvent.new(
		8003, null, 999.0, &"jab_cross", Vector2.ZERO, Vector2.RIGHT, 0.0, 9003
	)))
	_check("fresh_root_smash_accepted", wreck.receive_damage(DamageEvent.new(
		8004, null, 999.0, &"ground_smash", Vector2.ZERO, Vector2.RIGHT, 0.0, 9004
	)))
	var report: Dictionary = {
		"done": true,
		"result": "PASS" if _all_passed() else "FAIL",
		"facade_rows": facade_rows,
		"checks": _checks,
	}
	var file: FileAccess = FileAccess.open(
		ProjectSettings.globalize_path("%s/report.json" % ARTIFACT_DIR),
		FileAccess.WRITE
	)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
	quit(0 if _all_passed() else 1)


func _check(name: String, passed: bool) -> void:
	_checks.append({"name": name, "passed": passed})
	print("[CHECK] %s %s" % ["PASS" if passed else "FAIL", name])


func _all_passed() -> bool:
	for check: Dictionary in _checks:
		if not bool(check.passed):
			return false
	return true
