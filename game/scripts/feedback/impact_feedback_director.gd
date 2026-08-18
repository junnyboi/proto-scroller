class_name ImpactFeedbackDirector
extends Node

var hit_stop: HitStopLease
var camera_rig: CameraRig
var haptics: HapticsAdapter
var robot: GiantRobotController
var flush_count: int = 0
var coalesced_count: int = 0
var last_priority: int = 0
var _pending: Dictionary[int, Dictionary] = {}
var _flush_queued: bool = false


func setup(
	p_event_hub: GameplayEventHub,
	p_hit_stop: HitStopLease,
	p_camera_rig: CameraRig,
	p_haptics: HapticsAdapter,
	p_robot: GiantRobotController
) -> void:
	hit_stop = p_hit_stop
	camera_rig = p_camera_rig
	haptics = p_haptics
	robot = p_robot
	p_event_hub.event_published.connect(_on_event_published)


func cancel_all() -> void:
	_pending.clear()
	_flush_queued = false
	if hit_stop != null:
		hit_stop.cancel_and_restore()
	if camera_rig != null:
		camera_rig.reset_presentation()
	if haptics != null:
		haptics.cancel()


func _on_event_published(event: GameplayEvent) -> void:
	var profile: ImpactFeedbackProfile = _profile_for_event(event)
	if profile == null:
		return
	var request_id: int = event.attack_id if event.attack_id != 0 else -event.event_id
	var direction: Vector2 = Vector2.RIGHT
	if robot != null:
		direction = robot.global_position.direction_to(event.world_position)
		if direction.is_zero_approx():
			direction = Vector2(float(robot.facing), 0.0)
	var current: Dictionary = _pending.get(request_id, {})
	if not current.is_empty():
		coalesced_count += 1
		var current_profile: ImpactFeedbackProfile = current.profile
		if current_profile.priority >= profile.priority:
			return
	_pending[request_id] = {
		"profile": profile,
		"direction": direction,
	}
	if not _flush_queued:
		_flush_queued = true
		call_deferred("_flush_pending")


func _flush_pending() -> void:
	_flush_queued = false
	var request_ids: Array[int] = []
	request_ids.assign(_pending.keys())
	request_ids.sort()
	for request_id: int in request_ids:
		var request: Dictionary = _pending[request_id]
		var profile: ImpactFeedbackProfile = request.profile
		var direction: Vector2 = request.direction
		last_priority = profile.priority
		if hit_stop != null:
			hit_stop.request(profile.hit_stop_ms, request_id)
		if camera_rig != null:
			camera_rig.add_impact_impulse(-direction * profile.camera_impulse)
		if haptics != null:
			haptics.pulse(profile.haptic_ms)
		flush_count += 1
	_pending.clear()


func _profile_for_event(event: GameplayEvent) -> ImpactFeedbackProfile:
	var profile: ImpactFeedbackProfile
	match event.kind:
		GameplayEvent.Kind.CHAIN_COLLAPSE:
			profile = ImpactFeedbackProfile.new(5, 95, 18.0, 72)
		GameplayEvent.Kind.WRECK_SCRAPPED:
			profile = ImpactFeedbackProfile.new(4, 95, 18.0, 64)
		GameplayEvent.Kind.CELL_DESTROYED:
			profile = ImpactFeedbackProfile.new(4, 70, 12.0, 52)
		GameplayEvent.Kind.PLAYER_HEAVY_HIT:
			profile = ImpactFeedbackProfile.new(4, 65, 14.0, 56)
		GameplayEvent.Kind.ENEMY_DEFEATED:
			profile = ImpactFeedbackProfile.new(3, 45, 7.0, 38)
		GameplayEvent.Kind.PROP_DESTROYED:
			profile = ImpactFeedbackProfile.new(3, 45, 7.0, 36)
		GameplayEvent.Kind.AIRBORNE_DEBRIS_HIT:
			profile = ImpactFeedbackProfile.new(3, 45, 7.0, 34)
	return profile
