# gdlint: disable=max-returns
class_name CommandBossSession
extends Node

signal state_changed(state: StringName)
signal armor_changed(current: float, maximum: float)
signal body_changed(current: float, maximum: float)
signal completed(elapsed_seconds: float)

const STATE_IDLE: StringName = &"IDLE"
const STATE_SCREEN: StringName = &"SCREEN"
const STATE_BARRAGE: StringName = &"BARRAGE"
const STATE_EXPOSED: StringName = &"EXPOSED"
const STATE_WRECK: StringName = &"WRECK_FINISHER"
const STATE_COMPLETE: StringName = &"COMPLETE"
const ARMOR: float = 330.0
const HEALTH: float = 320.0
const SCREEN_DURATION: float = 4.0
const TARGET_DURATION: float = 60.0
const CHOIR_PRIME_TEXTURE: Texture2D = preload("res://art/finale/choir-prime-core.png")
var dependencies: UrbanSiegeDependencies
var state: StringName = STATE_IDLE
var boss: TankEnemy
var boss_wreck: EnemyWreck2D
var utility_pool: BossUtilityPool
var royal_finale: BossRoyalFinaleController
var active_definition: BossEncounterDefinition
var elapsed_seconds: float = 0.0
var generation_token: int = 0
var _state_elapsed: float = 0.0
var _pending_attempt_restore: Dictionary = {}
var _completion_payload: Dictionary = {}


func setup(p_dependencies: UrbanSiegeDependencies) -> void:
	dependencies = p_dependencies
	dependencies.encounter_runtime.enemy_died.connect(_on_enemy_died)
	dependencies.remains_factory.wreck_spawned.connect(_on_wreck_spawned)
	dependencies.remains_factory.wreck_scrapped.connect(_on_wreck_scrapped)
	utility_pool = BossUtilityPool.new()
	utility_pool.name = "BossUtilityPool"
	add_child(utility_pool)
	utility_pool.configure_runtime(
		dependencies.encounter_runtime,
		dependencies.projectile_pool
	)
	royal_finale = BossRoyalFinaleController.new()
	royal_finale.name = "BossRoyalFinaleController"
	royal_finale.setup(utility_pool, dependencies.encounter_runtime)
	royal_finale.severance_receiver_moved.connect(_on_severance_receiver_moved)
	add_child(royal_finale)


func start() -> bool:
	return _start_encounter(null)


func start_definition(definition: BossEncounterDefinition) -> bool:
	if definition == null or not definition.validation_errors().is_empty():
		return false
	return _start_encounter(definition)


func _start_encounter(definition: BossEncounterDefinition) -> bool:
	if state != STATE_IDLE and state != STATE_COMPLETE:
		return false
	generation_token = utility_pool.begin_generation()
	active_definition = definition
	dependencies.encounter_runtime.release_all()
	boss = dependencies.encounter_runtime.acquire(
		&"tank",
		dependencies.encounter_runtime.resolve_spawn_position(
			Vector2(0.0, 551.0),
			&"AHEAD"
		),
		&"ANCHOR_TANK",
		&"COMMAND"
	) as TankEnemy
	if boss == null:
		utility_pool.cleanup_generation(generation_token)
		active_definition = null
		return false
	if active_definition == null:
		boss.configure_boss(ARMOR, HEALTH)
	else:
		boss.configure_boss(
			active_definition.armor,
			active_definition.health,
			active_definition.armor_policy,
			active_definition.armor_fixed_step
		)
		_configure_campaign_runtime()
	if _is_choir_prime():
		_present_choir_prime()
	if not boss.boss_armor_changed.is_connected(_on_boss_armor_changed):
		boss.boss_armor_changed.connect(_on_boss_armor_changed)
	if not boss.boss_armor_broken.is_connected(_on_boss_armor_broken):
		boss.boss_armor_broken.connect(_on_boss_armor_broken)
	if not boss.health_changed.is_connected(_on_boss_health_changed):
		boss.health_changed.connect(_on_boss_health_changed)
	elapsed_seconds = 0.0
	_state_elapsed = 0.0
	_completion_payload.clear()
	_apply_pending_attempt_restore()
	_set_state(STATE_SCREEN)
	dependencies.encounter_runtime.set_attack_gate(false)
	armor_changed.emit(boss.boss_armor, boss.boss_max_armor)
	return true


func advance(delta: float) -> void:
	if state == STATE_IDLE or state == STATE_COMPLETE:
		return
	elapsed_seconds += delta
	_state_elapsed += delta
	if utility_pool != null:
		utility_pool.vertical_slice.advance(delta)
		utility_pool.escalation.advance(delta)
		royal_finale.advance(delta)
	var screen_duration: float = (
		SCREEN_DURATION if active_definition == null else active_definition.screen_seconds
	)
	if state == STATE_SCREEN and _state_elapsed >= screen_duration:
		dependencies.encounter_runtime.set_attack_gate(true)
		_set_state(STATE_BARRAGE)


func stop() -> void:
	_next_generation()
	if _is_choir_prime():
		dependencies.encounter_runtime.release_all()
	elif boss != null and boss.active:
		dependencies.encounter_runtime.release(boss)
	if boss_wreck != null:
		dependencies.remains_factory.release_wreck(boss_wreck)
	boss = null
	boss_wreck = null
	active_definition = null
	if state != STATE_COMPLETE:
		_set_state(STATE_IDLE)


func reset_state() -> void:
	stop()
	_set_state(STATE_IDLE)


func active() -> bool:
	return state != STATE_IDLE and state != STATE_COMPLETE


func capture_attempt_state() -> Dictionary:
	return {
		"state": STATE_SCREEN,
		"elapsed_seconds": elapsed_seconds,
		"state_elapsed": _state_elapsed,
		"definition_id": (
			active_definition.boss_id if active_definition != null else &""
		),
		"armor": boss.boss_armor if boss != null else ARMOR,
		"health": boss.current_health if boss != null else HEALTH,
		"vertical_slice": (
			utility_pool.vertical_slice.capture_state()
			if utility_pool.vertical_slice.active()
			else {}
		),
		"escalation": (
			utility_pool.escalation.capture_state()
			if utility_pool.escalation.active()
			else {}
		),
		"royal_finale": (
			royal_finale.capture_state() if royal_finale.active() else {}
		),
	}


func restore_attempt_state(snapshot: Dictionary) -> void:
	stop()
	_pending_attempt_restore = snapshot.duplicate(true)


func completion_payload() -> Dictionary:
	return _completion_payload.duplicate(true)


func live_boss_feedback() -> Dictionary:
	if utility_pool == null:
		return {}
	if utility_pool.vertical_slice.active():
		return utility_pool.vertical_slice.hud_feedback()
	if utility_pool.escalation.active():
		return utility_pool.escalation.hud_feedback()
	if royal_finale.active():
		return royal_finale.hud_feedback()
	return {}


func _apply_pending_attempt_restore() -> void:
	if _pending_attempt_restore.is_empty() or boss == null:
		return
	var definition_id: StringName = StringName(_pending_attempt_restore.get("definition_id", &""))
	if active_definition == null or definition_id != active_definition.boss_id:
		_pending_attempt_restore.clear()
		return
	elapsed_seconds = float(_pending_attempt_restore.get("elapsed_seconds", 0.0))
	_state_elapsed = 0.0
	boss.boss_armor = clampf(
		float(_pending_attempt_restore.get("armor", active_definition.armor)),
		0.0,
		boss.boss_max_armor
	)
	boss.current_health = clampf(
		float(_pending_attempt_restore.get("health", active_definition.health)),
		0.0,
		boss.max_health
	)
	var slice_state: Dictionary = _pending_attempt_restore.get("vertical_slice", {})
	if not slice_state.is_empty() and utility_pool.vertical_slice.active():
		utility_pool.vertical_slice.restore_state(slice_state)
	var escalation_state: Dictionary = _pending_attempt_restore.get("escalation", {})
	if not escalation_state.is_empty() and utility_pool.escalation.active():
		utility_pool.escalation.restore_state(escalation_state)
	var royal_state: Dictionary = _pending_attempt_restore.get("royal_finale", {})
	if not royal_state.is_empty() and royal_finale.active():
		royal_finale.restore_state(royal_state)
	_pending_attempt_restore.clear()


func _on_boss_health_changed(current: float, maximum: float) -> void:
	body_changed.emit(current, maximum)


func _on_boss_armor_changed(current: float, maximum: float) -> void:
	if _is_choir_prime():
		var connection_count: int = roundi(
			(maximum - current) / maxf(active_definition.armor_fixed_step, 1.0)
		)
		while royal_finale.armor_connections < connection_count:
			royal_finale.register_armor_connection()
		if connection_count >= BossRoyalFinaleController.CONNECTION_COUNT:
			_commit_crown_pylon_transaction()
	elif utility_pool.vertical_slice.active():
		var connection_count: int = roundi(
			(maximum - current) / maxf(active_definition.armor_fixed_step, 1.0)
		)
		while utility_pool.vertical_slice.armor_connections < connection_count:
			utility_pool.vertical_slice.register_armor_connection()
	elif utility_pool.escalation.active():
		var connection_count: int = roundi(
			(maximum - current) / maxf(active_definition.armor_fixed_step, 1.0)
		)
		while utility_pool.escalation.armor_connections < connection_count:
			utility_pool.escalation.register_armor_connection()
	armor_changed.emit(current, maximum)


func _on_boss_armor_broken() -> void:
	var slice_state: Dictionary = (
		utility_pool.vertical_slice.capture_state()
		if utility_pool.vertical_slice.active()
		else {}
	)
	var escalation_state: Dictionary = (
		utility_pool.escalation.capture_state()
		if utility_pool.escalation.active()
		else {}
	)
	var royal_state: Dictionary = (
		royal_finale.capture_state() if royal_finale.active() else {}
	)
	_next_generation()
	if active_definition != null:
		_configure_campaign_runtime()
		if not slice_state.is_empty() and utility_pool.vertical_slice.active():
			utility_pool.vertical_slice.restore_state(slice_state)
		if not escalation_state.is_empty() and utility_pool.escalation.active():
			utility_pool.escalation.restore_state(escalation_state)
		if not royal_state.is_empty() and royal_finale.active():
			royal_finale.restore_state(royal_state)
		if active_definition.phases.size() > 1:
			utility_pool.controller.begin_phase(
				active_definition.phases[1],
				generation_token
			)
	_set_state(STATE_EXPOSED)


func _present_choir_prime() -> void:
	if boss.visual != null:
		boss.visual.texture = CHOIR_PRIME_TEXTURE
		boss.visual.scale = Vector2(0.42, 0.42)
		boss.visual.position = Vector2(0.0, -88.0)


func _configure_campaign_runtime() -> void:
	var portrait: bool = (
		dependencies.city != null
		and dependencies.city.get_viewport_rect().size.y
		> dependencies.city.get_viewport_rect().size.x
	)
	utility_pool.rig.configure(active_definition, boss, portrait)
	boss.set_hidden_authority(true)
	var campaign: BossCampaignDirector = (
		dependencies.city.urban_siege.boss_campaign
		if dependencies.city != null and dependencies.city.urban_siege != null
		else null
	)
	if campaign != null and campaign.arena_lease.active:
		utility_pool.arena_adapter.bind(
			campaign.arena_lease.arena_building,
			active_definition
		)
	if not active_definition.phases.is_empty():
		utility_pool.controller.begin_phase(
			active_definition.phases[0],
			generation_token
		)
	if active_definition.boss_id in [
		&"SETTLEMENT_ENGINE_S04", &"SAMARITAN_15",
	]:
		utility_pool.vertical_slice.start(
			active_definition,
			generation_token,
			boss.global_position,
			portrait
		)
	elif active_definition.boss_id in [
		&"MIMESIS_04", &"CANTOR_31_PALE_ENGINE",
	]:
		utility_pool.escalation.start(
			active_definition,
			generation_token,
			boss.global_position,
			portrait
		)
	elif active_definition.boss_id == &"CHOIR_PRIME":
		royal_finale.start(
			active_definition,
			generation_token,
			boss.global_position,
			portrait
		)


func _is_choir_prime() -> bool:
	return active_definition != null and active_definition.boss_id == &"CHOIR_PRIME"


func _on_enemy_died(enemy: EnemyActor2D, _event: DamageEvent, _points: int) -> void:
	if enemy == boss:
		if utility_pool.vertical_slice.active():
			utility_pool.vertical_slice.reveal_archive()
			utility_pool.vertical_slice.rescue_remaining_pods()
			_completion_payload = utility_pool.vertical_slice.completion_payload()
			utility_pool.vertical_slice.preserve_completion_state()
		elif utility_pool.escalation.active():
			if active_definition.boss_id == &"MIMESIS_04":
				utility_pool.escalation.play_continuity_record()
			else:
				utility_pool.escalation.export_record_visible = true
			_completion_payload = utility_pool.escalation.completion_payload()
			utility_pool.escalation.preserve_completion_state()
		dependencies.encounter_runtime.set_attack_gate(false)


func _on_wreck_spawned(enemy: EnemyActor2D, wreck: EnemyWreck2D) -> void:
	if enemy != boss:
		return
	var royal_state: Dictionary = (
		royal_finale.capture_state() if royal_finale.active() else {}
	)
	_next_generation()
	boss_wreck = wreck
	if active_definition == null:
		boss_wreck.configure_finisher_policy(true, wreck.fatal_event)
	else:
		if _is_choir_prime():
			_configure_campaign_runtime()
			if not royal_state.is_empty():
				royal_finale.restore_state(royal_state)
			var snapshot: FinaleEligibilitySnapshot = _snapshot_royal_eligibility()
			royal_finale.begin_wreck(snapshot)
		utility_pool.configure_wreck_receivers(
			boss_wreck, active_definition, _on_wreck_receiver_damage
		)
	_set_state(STATE_WRECK)


func _on_wreck_scrapped(wreck: EnemyWreck2D, _event: DamageEvent, _points: int) -> void:
	if wreck != boss_wreck:
		return
	_next_generation()
	boss_wreck = null
	_set_state(STATE_COMPLETE)
	completed.emit(elapsed_seconds)


func _commit_crown_pylon_transaction() -> bool:
	if not _is_choir_prime() or dependencies.city == null:
		return false
	var choir: ProjectChoirRuntime = dependencies.city.project_choir_runtime
	return choir != null and choir.commit_crown_pylon_transaction()


func _snapshot_royal_eligibility() -> FinaleEligibilitySnapshot:
	var choir: ProjectChoirRuntime = dependencies.city.project_choir_runtime
	if choir == null:
		return FinaleEligibilitySnapshot.new()
	return choir.snapshot_finale_eligibility()


func _on_wreck_receiver_damage(
	receiver: BossWreckReceiver2D,
	event: DamageEvent
) -> bool:
	if (
		receiver == null
		or event == null
		or boss_wreck == null
		or boss_wreck.scrapped_state
		or event.damage_type != &"ground_smash"
	):
		return false
	if receiver.outcome_id == BossOutcome.PURGE:
		royal_finale.cancel_pressure()
		_completion_payload = royal_finale.completion_payload(BossOutcome.PURGE)
		return boss_wreck.receive_damage(event)
	var snapshot: FinaleEligibilitySnapshot = royal_finale.finale_snapshot
	if snapshot == null or not snapshot.disentangle_eligible:
		royal_finale.cancel_pressure()
		_completion_payload = royal_finale.completion_payload(
			BossOutcome.ASCENSION_FAILURE
		)
		return boss_wreck.receive_damage(event)
	if not royal_finale.severance_active:
		return royal_finale.begin_severance()
	if not royal_finale.complete_severance_window():
		return false
	if royal_finale.severance_completed < BossRoyalFinaleController.SEVERANCE_WINDOW_COUNT:
		return true
	_completion_payload = royal_finale.completion_payload(BossOutcome.DISENTANGLE)
	return boss_wreck.receive_damage(event)


func _on_severance_receiver_moved(offset: Vector2) -> void:
	if boss_wreck == null or utility_pool.royal_outcome_receiver == null:
		return
	utility_pool.royal_outcome_receiver.global_position = boss_wreck.global_position + offset


func _set_state(next_state: StringName) -> void:
	state = next_state
	_state_elapsed = 0.0
	state_changed.emit(state)


func _next_generation() -> void:
	if utility_pool != null:
		generation_token = utility_pool.begin_generation()
