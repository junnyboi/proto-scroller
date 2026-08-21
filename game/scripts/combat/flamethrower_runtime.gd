class_name FlamethrowerRuntime
extends UpgradeRuntime

const FLAME_CAPACITY: int = 6
const SCORCH_CAPACITY: int = 8
const LOOP_AUDIO_VOICES: int = 1
const DAMAGE_PER_TICK: Array[float] = [0.0, 12.0, 14.0, 15.0, 15.0, 18.0]
const MAXIMUM_TARGETS: Array[int] = [0, 4, 5, 5, 6, 6]

var arsenal: PlayerArsenalRuntime
var emitter: Node2D
var resolver: FlamethrowerConeResolver = FlamethrowerConeResolver.new()
var flames: Array[FlameVisualSlot2D] = []
var scorches: Array[ScorchVisualSlot2D] = []
var loop_audio: AudioStreamPlayer2D
var cooldown_remaining: float = 0.0
var burst_active: bool = false
var burst_direction: Vector2 = Vector2.RIGHT
var burst_root_attack_id: int = 0
var ticks_remaining: int = 0
var tick_remaining: float = 0.0
var bursts_started: int = 0
var ticks_delivered: int = 0
var loop_audio_active: bool = false
var _flame_cursor: int = 0
var _scorch_cursor: int = 0


func _init() -> void:
	setup(&"FLAMETHROWER", 5)
	for index: int in range(FLAME_CAPACITY):
		var flame: FlameVisualSlot2D = FlameVisualSlot2D.new()
		flame.name = "FlameVisual%02d" % index
		add_child(flame)
		flames.append(flame)
	for index: int in range(SCORCH_CAPACITY):
		var scorch: ScorchVisualSlot2D = ScorchVisualSlot2D.new()
		scorch.name = "ScorchVisual%02d" % index
		add_child(scorch)
		scorches.append(scorch)
	loop_audio = AudioStreamPlayer2D.new()
	loop_audio.name = "FlamethrowerLoopAudio"
	loop_audio.bus = MusicVolumeSettings.SFX_BUS
	add_child(loop_audio)


func setup_arsenal(p_arsenal: PlayerArsenalRuntime, p_emitter: Node2D) -> void:
	arsenal = p_arsenal
	emitter = p_emitter


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if stopped or paused or current_rank <= 0 or arsenal == null or emitter == null:
		return
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	if burst_active:
		_advance_burst(delta)
		return
	if cooldown_remaining > 0.0:
		return
	var direction: Vector2 = Vector2(float(arsenal.robot.facing), 0.0)
	if not resolver.has_actor_target(
		arsenal,
		emitter.global_position,
		direction,
		flame_range(),
		half_angle()
	):
		return
	_start_burst(direction)
	_advance_burst(0.0)


func apply_rank(total_rank: int, _context: Dictionary = {}) -> bool:
	var next_rank: int = clampi(total_rank, 0, runtime_max_rank)
	if current_rank == next_rank:
		return false
	current_rank = next_rank
	return true


func set_paused(value: bool) -> void:
	super.set_paused(value)
	for flame: FlameVisualSlot2D in flames:
		flame.paused = value
	for scorch: ScorchVisualSlot2D in scorches:
		scorch.paused = value
	if value:
		_stop_loop_audio()
	elif burst_active:
		_start_loop_audio()


func stop_and_release() -> void:
	super.stop_and_release()
	burst_active = false
	_stop_loop_audio()
	for flame: FlameVisualSlot2D in flames:
		flame.deactivate()
	for scorch: ScorchVisualSlot2D in scorches:
		scorch.deactivate()


func reset_run() -> void:
	super.reset_run()
	cooldown_remaining = 0.0
	burst_active = false
	burst_direction = Vector2.RIGHT
	burst_root_attack_id = 0
	ticks_remaining = 0
	tick_remaining = 0.0
	bursts_started = 0
	ticks_delivered = 0
	_flame_cursor = 0
	_scorch_cursor = 0
	_stop_loop_audio()


func flame_range() -> float:
	if current_rank >= 5:
		return 255.0
	return 235.0 if current_rank >= 3 else 220.0


func half_angle() -> float:
	if current_rank >= 5:
		return deg_to_rad(40.0)
	return deg_to_rad(38.0) if current_rank >= 3 else deg_to_rad(32.0)


func damage_per_tick() -> float:
	return DAMAGE_PER_TICK[current_rank]


func tick_count() -> int:
	return 5 if current_rank >= 4 else 4


func tick_interval() -> float:
	return 0.18 if current_rank >= 5 else 0.20


func maximum_targets() -> int:
	return MAXIMUM_TARGETS[current_rank]


func cooldown_duration() -> float:
	return 1.0 if current_rank >= 5 else 1.20


func active_flame_count() -> int:
	var total: int = 0
	for flame: FlameVisualSlot2D in flames:
		if flame.active:
			total += 1
	return total


func active_scorch_count() -> int:
	var total: int = 0
	for scorch: ScorchVisualSlot2D in scorches:
		if scorch.active:
			total += 1
	return total


func _start_burst(direction: Vector2) -> void:
	burst_active = true
	burst_direction = direction
	burst_root_attack_id = arsenal.reserve_attack_id()
	ticks_remaining = tick_count()
	tick_remaining = 0.0
	bursts_started += 1
	_start_loop_audio()


func _advance_burst(delta: float) -> void:
	tick_remaining -= delta
	while burst_active and tick_remaining <= 0.0:
		_deliver_tick()
		ticks_remaining -= 1
		if ticks_remaining <= 0:
			burst_active = false
			cooldown_remaining = cooldown_duration()
			_stop_loop_audio()
			return
		tick_remaining += tick_interval()


func _deliver_tick() -> void:
	var origin: Vector2 = emitter.global_position
	var attack_id: int = arsenal.reserve_attack_id()
	resolver.resolve_tick(
		arsenal.robot,
		origin,
		burst_direction,
		flame_range(),
		half_angle(),
		damage_per_tick(),
		maximum_targets(),
		attack_id,
		burst_root_attack_id
	)
	flames[_flame_cursor].activate(origin, burst_direction, flame_range(), half_angle())
	_flame_cursor = (_flame_cursor + 1) % flames.size()
	for hit_position: Vector2 in resolver.accepted_positions:
		scorches[_scorch_cursor].activate(hit_position)
		_scorch_cursor = (_scorch_cursor + 1) % scorches.size()
	ticks_delivered += 1


func _start_loop_audio() -> void:
	loop_audio_active = true
	if loop_audio.stream != null and not loop_audio.playing:
		loop_audio.play()


func _stop_loop_audio() -> void:
	loop_audio_active = false
	loop_audio.stop()
