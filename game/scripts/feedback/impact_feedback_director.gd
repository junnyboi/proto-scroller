class_name ImpactFeedbackDirector
extends Node

const PLAYER_FLASH_SECONDS: float = 0.14
const PLAYER_JAB_IMPULSE: float = 22.0
const PLAYER_SLAM_IMPULSE: float = 26.0

var hit_stop: HitStopLease
var camera_rig: CameraRig
var haptics: HapticsAdapter
var robot: GiantRobotController
var flush_count: int = 0
var coalesced_count: int = 0
var last_priority: int = 0
var player_strike_feedback_count: int = 0
var last_player_attack_id: int = 0
var last_player_strike_frame: int = -1
var flash_layer: CanvasLayer
var flash_rect: ColorRect
var _pending: Dictionary[int, Dictionary] = {}
var _flush_queued: bool = false
var _flash_end_msec: int = 0


func _ready() -> void:
	_build_player_flash()


func _process(_delta: float) -> void:
	if flash_rect == null or _flash_end_msec <= 0:
		return
	var remaining_msec: int = maxi(_flash_end_msec - Time.get_ticks_msec(), 0)
	var alpha: float = 0.46 * (
		float(remaining_msec) / (PLAYER_FLASH_SECONDS * 1000.0)
	)
	flash_rect.color.a = alpha
	flash_rect.visible = alpha > 0.001
	if remaining_msec == 0:
		_flash_end_msec = 0


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


func bind_player_attacks(attacks: ContextualAttackController) -> void:
	if attacks != null and not attacks.attack_active.is_connected(_on_player_attack_active):
		attacks.attack_active.connect(_on_player_attack_active)


func cancel_all() -> void:
	_pending.clear()
	_flush_queued = false
	if hit_stop != null:
		hit_stop.cancel_and_restore()
	if camera_rig != null:
		camera_rig.reset_presentation()
	if haptics != null:
		haptics.cancel()
	_flash_end_msec = 0
	if flash_rect != null:
		flash_rect.visible = false


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


func _on_player_attack_active(spec: AttackSpec) -> void:
	if spec == null:
		return
	last_player_attack_id = spec.attack_id
	last_player_strike_frame = -1
	if robot != null:
		var sprite: AnimatedSprite2D = (
			robot.get_node_or_null(^"VisualRoot/RobotAnimatedSprite") as AnimatedSprite2D
		)
		if sprite != null:
			last_player_strike_frame = sprite.frame
	if camera_rig != null:
		var strength: float = (
			PLAYER_SLAM_IMPULSE if spec.is_ground_smash() else PLAYER_JAB_IMPULSE
		)
		camera_rig.add_impact_impulse(
			Vector2(-float(spec.facing), -0.32).normalized() * strength
		)
	if flash_rect != null:
		flash_rect.color = (
			Color(1.0, 0.72, 0.38, 0.46)
			if spec.is_ground_smash()
			else Color(0.76, 0.96, 1.0, 0.46)
		)
		flash_rect.visible = true
		_flash_end_msec = Time.get_ticks_msec() + int(PLAYER_FLASH_SECONDS * 1000.0)
	player_strike_feedback_count += 1


func _build_player_flash() -> void:
	flash_layer = CanvasLayer.new()
	flash_layer.name = "PlayerStrikeFlashLayer"
	flash_layer.layer = 90
	add_child(flash_layer)
	flash_rect = ColorRect.new()
	flash_rect.name = "PlayerStrikeFlash"
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.visible = false
	flash_layer.add_child(flash_rect)
