# gdlint: disable=max-public-methods
class_name BossVerticalSliceController
extends Node

signal attack_changed(attack_id: StringName, stage: StringName)
signal archive_revealed(boss_id: StringName)
signal rescue_tally_changed(rescued: int, lost: int)

const BUSINESS_ID: StringName = &"SETTLEMENT_ENGINE_S04"
const RESIDENTIAL_ID: StringName = &"SAMARITAN_15"
const BUSINESS_ATTACKS: Array[StringName] = [
	&"SETTLEMENT_SWEEP",
	&"DOUBLE_ENTRY_BARRAGE",
	&"FORECLOSURE_STAMP",
	&"AUDIT_BEAM",
	&"FOUNDATION_CASCADE",
]
const RESIDENTIAL_ATTACKS: Array[StringName] = [
	&"TRIAGE_SWEEP",
	&"PRESSURE_SENTENCE",
	&"EXTRACTION_CLAMP",
	&"BLACKOUT_HARVEST",
]
const PIN_COUNT: int = 3
const POD_COUNT: int = 4
const LANE_COUNT: int = 3
const DIRECT_CLEAR_SECONDS: float = 60.0
const TELEGRAPH_SECONDS: float = 0.85
const ACTIVE_SECONDS: float = 0.55
const RECOVERY_SECONDS: float = 0.75
const EXTRACTION_SECONDS: float = 2.6
const ARENA_INTERVAL: Vector2 = Vector2(-576.0, 576.0)
const LANE_CENTERS: Array[float] = [-360.0, 0.0, 360.0]
const POD_OFFSETS: Array[Vector2] = [
	Vector2(-228.0, -178.0),
	Vector2(-126.0, -204.0),
	Vector2(126.0, -204.0),
	Vector2(228.0, -178.0),
]
const PIN_OFFSETS: Array[Vector2] = [
	Vector2(-164.0, -152.0), Vector2(0.0, -198.0), Vector2(164.0, -152.0),
]

var utility_pool: BossUtilityPool
var encounter_runtime: EncounterRuntime
var active_definition: BossEncounterDefinition
var generation_token: int = 0
var center: Vector2 = Vector2.ZERO
var orientation_portrait: bool = false
var elapsed_seconds: float = 0.0
var attack_elapsed: float = 0.0
var attack_index: int = -1
var attack_stage: StringName = &"IDLE"
var active_attack: StringName = &""
var armor_connections: int = 0
var treasury_slab_available: bool = true
var treasury_slab_used: bool = false
var foundation_cascade_used: bool = false
var archive_preserved: bool = true
var archive_visible: bool = false
var breacher_deployed: bool = false
var runners_deployed: int = 0
var active_runner_slot: EnemyActor2D
var extraction_pod: int = -1
var extraction_remaining: float = 0.0
var dry_lane_index: int = 0
var rescue_tally: int = POD_COUNT
var pod_loss_count: int = 0
var central_cradle_preserved: bool = true
var direct_clear_seconds: float = DIRECT_CLEAR_SECONDS
var _business_support_deployed: bool = false
var _active_breacher: EnemyActor2D
var _preserve_state_on_cleanup: bool = false


func setup(
	pool: BossUtilityPool,
	runtime: EncounterRuntime
) -> void:
	utility_pool = pool
	encounter_runtime = runtime


func start(
	definition: BossEncounterDefinition,
	token: int,
	world_center: Vector2,
	portrait: bool
) -> bool:
	deactivate()
	_preserve_state_on_cleanup = false
	if (
		definition == null
		or not definition.boss_id in [BUSINESS_ID, RESIDENTIAL_ID]
		or utility_pool == null
		or not utility_pool.is_current_generation(token)
	):
		return false
	active_definition = definition
	generation_token = token
	center = world_center
	orientation_portrait = portrait
	direct_clear_seconds = DIRECT_CLEAR_SECONDS
	_configure_common_targets()
	if definition.boss_id == BUSINESS_ID:
		_configure_business()
	else:
		_configure_residential()
	utility_pool.register_generation_cleanup(_cleanup_generation.bind(token), token)
	_begin_next_attack()
	return true


func deactivate() -> void:
	_release_support(_active_breacher)
	_release_support(active_runner_slot)
	_active_breacher = null
	active_runner_slot = null
	active_definition = null
	generation_token = 0
	elapsed_seconds = 0.0
	attack_elapsed = 0.0
	attack_index = -1
	attack_stage = &"IDLE"
	active_attack = &""
	armor_connections = 0
	treasury_slab_available = true
	treasury_slab_used = false
	foundation_cascade_used = false
	archive_preserved = true
	archive_visible = false
	breacher_deployed = false
	runners_deployed = 0
	extraction_pod = -1
	extraction_remaining = 0.0
	dry_lane_index = 0
	rescue_tally = POD_COUNT
	pod_loss_count = 0
	central_cradle_preserved = true
	_business_support_deployed = false
	if utility_pool != null:
		for marker: Marker2D in utility_pool.markers:
			marker.visible = false
		for area: BossAttackArea2D in utility_pool.lane_damage_areas:
			area.deactivate()
		for area: BossAttackArea2D in utility_pool.line_areas:
			area.deactivate()
		for pod: BossPodVisual2D in utility_pool.pod_visuals:
			pod.visible = false
		for record: Node2D in utility_pool.reclamation_anchor_records:
			record.visible = false


func advance(delta: float) -> void:
	if not active() or delta <= 0.0:
		return
	elapsed_seconds += delta
	attack_elapsed += delta
	if extraction_pod >= 0:
		extraction_remaining = maxf(extraction_remaining - delta, 0.0)
		if is_zero_approx(extraction_remaining):
			lose_targeted_pod()
	if attack_stage == &"TELEGRAPH" and attack_elapsed >= TELEGRAPH_SECONDS:
		attack_elapsed -= TELEGRAPH_SECONDS
		attack_stage = &"ACTIVE"
		_set_attack_visual_state(BossAttackArea2D.VisualState.ARMED)
		attack_changed.emit(active_attack, attack_stage)
	elif attack_stage == &"ACTIVE" and attack_elapsed >= ACTIVE_SECONDS:
		attack_elapsed -= ACTIVE_SECONDS
		attack_stage = &"RECOVERY"
		_set_attack_visual_state(BossAttackArea2D.VisualState.HIDDEN)
		attack_changed.emit(active_attack, attack_stage)
		_on_recovery_started()
	elif attack_stage == &"RECOVERY" and attack_elapsed >= RECOVERY_SECONDS:
		_begin_next_attack()


func active() -> bool:
	return (
		active_definition != null
		and utility_pool != null
		and utility_pool.is_current_generation(generation_token)
	)


func active_attack_choices() -> Array[StringName]:
	if active_definition == null:
		return []
	return BUSINESS_ATTACKS.duplicate() if active_definition.boss_id == BUSINESS_ID else (
		RESIDENTIAL_ATTACKS.duplicate()
	)


func register_armor_connection() -> bool:
	if not active() or armor_connections >= PIN_COUNT:
		return false
	utility_pool.markers[armor_connections].visible = false
	armor_connections += 1
	if armor_connections == PIN_COUNT:
		reveal_archive()
		if active_definition.boss_id == RESIDENTIAL_ID:
			for pod: BossPodVisual2D in utility_pool.pod_visuals:
				if pod.state == BossPodVisual2D.PodState.SEALED:
					pod.set_state(BossPodVisual2D.PodState.OCCUPIED)
	return true


func set_treasury_slab_available(available: bool) -> void:
	treasury_slab_available = available
	var bracket: Node2D = utility_pool.reclamation_anchor_records[0]
	bracket.visible = not available and active_definition != null and (
		active_definition.boss_id == BUSINESS_ID
	)


func trigger_treasury_slab() -> float:
	if (
		not active()
		or active_definition.boss_id != BUSINESS_ID
		or treasury_slab_used
		or not active_attack in [&"FORECLOSURE_STAMP", &"AUDIT_BEAM"]
	):
		return 0.0
	treasury_slab_used = true
	return 80.0


func trigger_foundation_cascade() -> float:
	if not active() or active_definition.boss_id != BUSINESS_ID or foundation_cascade_used:
		return 0.0
	foundation_cascade_used = true
	return 60.0


func destroy_archive() -> bool:
	if not active() or not archive_preserved:
		return false
	archive_preserved = false
	return true


func reveal_archive() -> bool:
	if not active() or archive_visible:
		return false
	archive_visible = true
	archive_revealed.emit(active_definition.boss_id)
	return true


func begin_extraction(pod_index: int) -> bool:
	if (
		not active()
		or active_definition.boss_id != RESIDENTIAL_ID
		or extraction_pod >= 0
		or pod_index < 0
		or pod_index >= POD_COUNT
	):
		return false
	var pod: BossPodVisual2D = utility_pool.pod_visuals[pod_index]
	if pod.state in [BossPodVisual2D.PodState.LOST, BossPodVisual2D.PodState.RESCUED]:
		return false
	extraction_pod = pod_index
	extraction_remaining = EXTRACTION_SECONDS
	pod.set_state(BossPodVisual2D.PodState.TARGETED)
	_configure_extraction_clamp(pod_index)
	return true


func interrupt_extraction() -> bool:
	if extraction_pod < 0:
		return false
	var pod: BossPodVisual2D = utility_pool.pod_visuals[extraction_pod]
	pod.set_state(BossPodVisual2D.PodState.OCCUPIED)
	extraction_pod = -1
	extraction_remaining = 0.0
	utility_pool.reclamation_anchor_records[1].visible = false
	return true


func lose_targeted_pod() -> bool:
	if extraction_pod < 0:
		return false
	var pod: BossPodVisual2D = utility_pool.pod_visuals[extraction_pod]
	pod.set_state(BossPodVisual2D.PodState.LOST)
	extraction_pod = -1
	extraction_remaining = 0.0
	pod_loss_count += 1
	rescue_tally = maxi(POD_COUNT - pod_loss_count, 0)
	central_cradle_preserved = true
	utility_pool.reclamation_anchor_records[1].visible = false
	rescue_tally_changed.emit(rescue_tally, pod_loss_count)
	return true


func rescue_remaining_pods() -> void:
	if active_definition == null or active_definition.boss_id != RESIDENTIAL_ID:
		return
	for pod: BossPodVisual2D in utility_pool.pod_visuals:
		if pod.state != BossPodVisual2D.PodState.LOST:
			pod.set_state(BossPodVisual2D.PodState.RESCUED)
	central_cradle_preserved = true


func deploy_business_support() -> Array[EnemyActor2D]:
	var result: Array[EnemyActor2D] = []
	if (
		not active()
		or active_definition.boss_id != BUSINESS_ID
		or _business_support_deployed
		or encounter_runtime == null
	):
		return result
	_business_support_deployed = true
	var bulwark: EnemyActor2D = encounter_runtime.acquire(
		&"bulwark", center + Vector2(-410.0, 0.0), &"SUPPRESSOR"
	)
	var sapper: EnemyActor2D = encounter_runtime.acquire(
		&"sapper", center + Vector2(410.0, 0.0), &"ANCHOR"
	)
	if bulwark != null:
		utility_pool.controller.track_support(bulwark)
		result.append(bulwark)
	if sapper != null:
		utility_pool.controller.track_support(sapper)
		result.append(sapper)
	return result


func deploy_breacher() -> EnemyActor2D:
	if (
		not active()
		or active_definition.boss_id != RESIDENTIAL_ID
		or breacher_deployed
		or _active_breacher != null
		or extraction_pod >= 0
		or encounter_runtime == null
	):
		return null
	_active_breacher = encounter_runtime.acquire(
		&"goliath", center + Vector2(-470.0, 0.0), &"BREAKER"
	)
	if _active_breacher != null:
		(_active_breacher as ProceduralEnemy).configure_boss_support(&"reclaimed_breacher")
		utility_pool.controller.track_support(_active_breacher)
		breacher_deployed = true
	return _active_breacher


func deploy_next_runner() -> EnemyActor2D:
	if (
		not active()
		or active_definition.boss_id != RESIDENTIAL_ID
		or runners_deployed >= 2
		or extraction_pod >= 0
		or blackout_discharge_active()
		or (active_runner_slot != null and active_runner_slot.active)
		or encounter_runtime == null
	):
		return null
	active_runner_slot = encounter_runtime.acquire(
		&"jackal", center + Vector2(470.0, 0.0), &"ADVANCING"
	)
	if active_runner_slot != null:
		(active_runner_slot as ProceduralEnemy).configure_boss_support(&"graft_runner")
		utility_pool.controller.track_support(active_runner_slot)
		runners_deployed += 1
	return active_runner_slot


func release_active_runner() -> void:
	_release_support(active_runner_slot)
	active_runner_slot = null


func blackout_discharge_active() -> bool:
	return active_attack == &"BLACKOUT_HARVEST" and attack_stage == &"ACTIVE"


func dry_lane_exists() -> bool:
	if active_definition == null or active_definition.boss_id != RESIDENTIAL_ID:
		return true
	return dry_lane_index >= 0 and dry_lane_index < LANE_COUNT and (
		utility_pool.lane_damage_areas[dry_lane_index].visual_state
		== BossAttackArea2D.VisualState.DRY
	)


func mechanical_targets_clear_of_glass() -> bool:
	if active_definition == null or active_definition.boss_id != RESIDENTIAL_ID:
		return true
	for marker_index: int in range(3):
		var point: Vector2 = utility_pool.markers[marker_index].global_position
		for pod: BossPodVisual2D in utility_pool.pod_visuals:
			if pod.glass_rect().has_point(point):
				return false
	return true


func mechanical_signature() -> Dictionary:
	var lanes: Array[Dictionary] = []
	for area: BossAttackArea2D in utility_pool.lane_damage_areas:
		lanes.append({
			"position": area.position,
			"size": area.footprint_size,
		})
	var pins: Array[Vector2] = []
	for index: int in range(PIN_COUNT):
		pins.append(utility_pool.markers[index].position)
	return {
		"boss_id": active_definition.boss_id if active_definition != null else &"",
		"pins": pins,
		"lanes": lanes,
		"direct_clear_seconds": direct_clear_seconds,
		"central_cradle_preserved": central_cradle_preserved,
	}


func completion_payload() -> Dictionary:
	if active_definition == null:
		return {}
	return {
		"boss_id": active_definition.boss_id,
		"archive_preserved": archive_preserved,
		"archive_visible": archive_visible,
		"rescue_tally": rescue_tally,
		"pod_loss_count": pod_loss_count,
		"central_cradle_preserved": central_cradle_preserved,
		"direct_clear_seconds": direct_clear_seconds,
	}


func hud_feedback() -> Dictionary:
	if active_definition == null:
		return {}
	var objective_key: String = (
		"boss.objective.business.connect"
		if active_definition.boss_id == BUSINESS_ID and armor_connections < PIN_COUNT
		else "boss.objective.business.finish"
		if active_definition.boss_id == BUSINESS_ID
		else "boss.objective.residential.connect"
		if armor_connections < PIN_COUNT
		else "boss.objective.residential.rescue"
	)
	var consequence_key: String = "boss.rescue.tally"
	if active_definition.boss_id == BUSINESS_ID:
		consequence_key = (
			"boss.archive.preserved" if archive_preserved else "boss.archive.lost"
		)
	var consequence: String = L10n.t(consequence_key, {
		"rescued": rescue_tally,
		"total": POD_COUNT,
	})
	var attack_key: String = "boss.attack.%s" % String(active_attack).to_lower()
	return {
		"objective": L10n.t(objective_key, {
			"current": armor_connections,
			"total": PIN_COUNT,
		}),
		"attack": L10n.t(attack_key),
		"consequence": consequence,
	}


func preserve_completion_state() -> void:
	_preserve_state_on_cleanup = active_definition != null


func capture_state() -> Dictionary:
	var pod_states: PackedInt32Array = PackedInt32Array()
	for pod: BossPodVisual2D in utility_pool.pod_visuals:
		pod_states.append(pod.state)
	return {
		"boss_id": active_definition.boss_id if active_definition != null else &"",
		"elapsed": elapsed_seconds,
		"attack_elapsed": attack_elapsed,
		"attack_index": attack_index,
		"attack_stage": attack_stage,
		"active_attack": active_attack,
		"armor_connections": armor_connections,
		"treasury_slab_available": treasury_slab_available,
		"treasury_slab_used": treasury_slab_used,
		"foundation_cascade_used": foundation_cascade_used,
		"archive_preserved": archive_preserved,
		"archive_visible": archive_visible,
		"breacher_deployed": breacher_deployed,
		"runners_deployed": runners_deployed,
		"extraction_pod": extraction_pod,
		"extraction_remaining": extraction_remaining,
		"dry_lane_index": dry_lane_index,
		"rescue_tally": rescue_tally,
		"pod_loss_count": pod_loss_count,
		"central_cradle_preserved": central_cradle_preserved,
		"business_support_deployed": _business_support_deployed,
		"breacher_active": _active_breacher != null and _active_breacher.active,
		"runner_active": active_runner_slot != null and active_runner_slot.active,
		"pod_states": pod_states,
	}


func restore_state(state: Dictionary) -> void:
	if not active() or StringName(state.get("boss_id", &"")) != active_definition.boss_id:
		return
	elapsed_seconds = float(state.get("elapsed", 0.0))
	attack_elapsed = float(state.get("attack_elapsed", 0.0))
	attack_index = int(state.get("attack_index", -1))
	attack_stage = StringName(state.get("attack_stage", &"TELEGRAPH"))
	active_attack = StringName(state.get("active_attack", &""))
	armor_connections = int(state.get("armor_connections", 0))
	treasury_slab_available = bool(state.get("treasury_slab_available", true))
	treasury_slab_used = bool(state.get("treasury_slab_used", false))
	foundation_cascade_used = bool(state.get("foundation_cascade_used", false))
	archive_preserved = bool(state.get("archive_preserved", true))
	archive_visible = bool(state.get("archive_visible", false))
	breacher_deployed = bool(state.get("breacher_deployed", false))
	runners_deployed = int(state.get("runners_deployed", 0))
	extraction_pod = int(state.get("extraction_pod", -1))
	extraction_remaining = float(state.get("extraction_remaining", 0.0))
	dry_lane_index = int(state.get("dry_lane_index", 0))
	rescue_tally = int(state.get("rescue_tally", POD_COUNT))
	pod_loss_count = int(state.get("pod_loss_count", 0))
	central_cradle_preserved = bool(state.get("central_cradle_preserved", true))
	_business_support_deployed = bool(state.get("business_support_deployed", false))
	var breacher_active: bool = bool(state.get("breacher_active", false))
	var runner_active: bool = bool(state.get("runner_active", false))
	var pod_states: PackedInt32Array = state.get("pod_states", PackedInt32Array())
	for index: int in range(mini(pod_states.size(), utility_pool.pod_visuals.size())):
		utility_pool.pod_visuals[index].set_state(pod_states[index])
	_configure_attack(active_attack)
	_set_attack_visual_state(
		BossAttackArea2D.VisualState.ARMED
		if attack_stage == &"ACTIVE"
		else BossAttackArea2D.VisualState.TELEGRAPH
	)
	if extraction_pod >= 0:
		_configure_extraction_clamp(extraction_pod)
	_restore_support_actors(breacher_active, runner_active)


func _configure_common_targets() -> void:
	for index: int in range(PIN_COUNT):
		var marker: Marker2D = utility_pool.markers[index]
		marker.global_position = center + PIN_OFFSETS[index]
		marker.visible = true
	for index: int in range(PIN_COUNT, utility_pool.markers.size()):
		utility_pool.markers[index].visible = false


func _configure_business() -> void:
	var archive: Node2D = utility_pool.reclamation_anchor_records[0]
	archive.global_position = center + Vector2(294.0, -244.0)
	archive.visible = true
	for pod: BossPodVisual2D in utility_pool.pod_visuals:
		pod.visible = false


func _configure_residential() -> void:
	for index: int in range(POD_COUNT):
		utility_pool.pod_visuals[index].configure(
			index,
			BossPodVisual2D.PodState.SEALED,
			POD_OFFSETS[index]
		)
	var cradle: Node2D = utility_pool.reclamation_anchor_records[0]
	cradle.global_position = center + Vector2(0.0, -126.0)
	cradle.visible = true
	for lane_index: int in range(LANE_COUNT):
		var area: BossAttackArea2D = utility_pool.lane_damage_areas[lane_index]
		area.configure_footprint(
			center + Vector2(LANE_CENTERS[lane_index], 4.0),
			Vector2(272.0, 112.0),
			BossAttackArea2D.VisualState.DRY,
			&"BLACKOUT_HARVEST"
		)


func _begin_next_attack() -> void:
	attack_elapsed = 0.0
	attack_stage = &"TELEGRAPH"
	var choices: Array[StringName] = active_attack_choices()
	attack_index = posmod(attack_index + 1, choices.size())
	active_attack = choices[attack_index]
	_configure_attack(active_attack)
	_set_attack_visual_state(BossAttackArea2D.VisualState.TELEGRAPH)
	attack_changed.emit(active_attack, attack_stage)


func _configure_attack(attack: StringName) -> void:
	for area: BossAttackArea2D in utility_pool.lane_damage_areas:
		area.deactivate()
	for area: BossAttackArea2D in utility_pool.line_areas:
		area.deactivate()
	if active_definition.boss_id == BUSINESS_ID:
		_configure_business_attack(attack)
	else:
		_configure_residential_attack(attack)


func _configure_business_attack(attack: StringName) -> void:
	match attack:
		&"SETTLEMENT_SWEEP":
			utility_pool.lane_damage_areas[0].configure_footprint(
				center + Vector2(-280.0, 0.0), Vector2(360.0, 112.0),
				BossAttackArea2D.VisualState.TELEGRAPH, attack
			)
			utility_pool.lane_damage_areas[1].configure_footprint(
				center + Vector2(300.0, 0.0), Vector2(260.0, 112.0),
				BossAttackArea2D.VisualState.TELEGRAPH, attack
			)
		&"DOUBLE_ENTRY_BARRAGE":
			utility_pool.lane_damage_areas[0].configure_footprint(
				center + Vector2(-386.0, 0.0), Vector2(210.0, 112.0),
				BossAttackArea2D.VisualState.TELEGRAPH, attack
			)
			utility_pool.lane_damage_areas[1].configure_footprint(
				center + Vector2(386.0, 0.0), Vector2(210.0, 112.0),
				BossAttackArea2D.VisualState.TELEGRAPH, attack
			)
		&"FORECLOSURE_STAMP":
			utility_pool.lane_damage_areas[0].configure_footprint(
				center + Vector2(0.0, 0.0), Vector2(330.0, 120.0),
				BossAttackArea2D.VisualState.TELEGRAPH, attack
			)
		&"AUDIT_BEAM":
			utility_pool.line_areas[0].configure_footprint(
				center + Vector2(0.0, -88.0), Vector2(720.0, 44.0),
				BossAttackArea2D.VisualState.TELEGRAPH, attack
			)
		&"FOUNDATION_CASCADE":
			utility_pool.lane_damage_areas[0].configure_footprint(
				center + Vector2(-250.0, 0.0), Vector2(260.0, 112.0),
				BossAttackArea2D.VisualState.TELEGRAPH, attack
			)


func _configure_residential_attack(attack: StringName) -> void:
	match attack:
		&"TRIAGE_SWEEP":
			utility_pool.lane_damage_areas[0].configure_footprint(
				center + Vector2(-310.0, 0.0), Vector2(280.0, 112.0),
				BossAttackArea2D.VisualState.TELEGRAPH, attack
			)
			utility_pool.lane_damage_areas[2].configure_footprint(
				center + Vector2(310.0, 0.0), Vector2(280.0, 112.0),
				BossAttackArea2D.VisualState.TELEGRAPH, attack
			)
		&"PRESSURE_SENTENCE":
			utility_pool.line_areas[0].configure_footprint(
				center + Vector2(0.0, -70.0), Vector2(760.0, 48.0),
				BossAttackArea2D.VisualState.TELEGRAPH, attack
			)
		&"EXTRACTION_CLAMP":
			if extraction_pod < 0:
				begin_extraction((attack_index + pod_loss_count) % POD_COUNT)
		&"BLACKOUT_HARVEST":
			dry_lane_index = posmod(attack_index + pod_loss_count, LANE_COUNT)
			for lane_index: int in range(LANE_COUNT):
				utility_pool.lane_damage_areas[lane_index].configure_footprint(
					center + Vector2(LANE_CENTERS[lane_index], 4.0),
					Vector2(272.0, 112.0),
					BossAttackArea2D.VisualState.DRY
					if lane_index == dry_lane_index
					else BossAttackArea2D.VisualState.TELEGRAPH,
					attack
				)


func _configure_extraction_clamp(pod_index: int) -> void:
	var pod: BossPodVisual2D = utility_pool.pod_visuals[pod_index]
	var clamp_record: Node2D = utility_pool.reclamation_anchor_records[1]
	clamp_record.global_position = Vector2(pod.global_position.x, center.y + 6.0)
	clamp_record.visible = true


func _set_attack_visual_state(state_value: BossAttackArea2D.VisualState) -> void:
	for area: BossAttackArea2D in utility_pool.lane_damage_areas + utility_pool.line_areas:
		if area.visible:
			if area.visual_state == BossAttackArea2D.VisualState.DRY:
				continue
			area.configure_footprint(
				area.global_position, area.footprint_size, state_value, active_attack
			)


func _on_recovery_started() -> void:
	if active_definition.boss_id == BUSINESS_ID and active_attack == &"DOUBLE_ENTRY_BARRAGE":
		deploy_business_support()
	elif active_definition.boss_id == RESIDENTIAL_ID:
		if active_attack == &"PRESSURE_SENTENCE":
			deploy_breacher()
		elif active_attack == &"BLACKOUT_HARVEST":
			deploy_next_runner()


func _restore_support_actors(breacher_active: bool, runner_active: bool) -> void:
	if active_definition == null or encounter_runtime == null:
		return
	if active_definition.boss_id == BUSINESS_ID and _business_support_deployed:
		_business_support_deployed = false
		deploy_business_support()
	elif active_definition.boss_id == RESIDENTIAL_ID:
		if breacher_active:
			breacher_deployed = false
			deploy_breacher()
		if runner_active:
			var deployed_count: int = runners_deployed
			runners_deployed = maxi(deployed_count - 1, 0)
			deploy_next_runner()
			runners_deployed = deployed_count


func _release_support(support: EnemyActor2D) -> void:
	if encounter_runtime != null and support != null and is_instance_valid(support):
		encounter_runtime.release(support)


func _cleanup_generation(token: int) -> void:
	if generation_token != token:
		return
	if _preserve_state_on_cleanup:
		_release_support(_active_breacher)
		_release_support(active_runner_slot)
		_active_breacher = null
		active_runner_slot = null
		generation_token = 0
		_preserve_state_on_cleanup = false
		return
	deactivate()
