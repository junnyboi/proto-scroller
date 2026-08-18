class_name Catalyst2D
extends DestructibleProp2D

signal triggered(catalyst: Catalyst2D, event: DamageEvent)
signal resolved(catalyst: Catalyst2D, affected_count: int)

const INTACT_TEXTURE: Texture2D = preload(
	"res://art/city/catalysts/transformer_intact.png"
)
const SPENT_TEXTURE: Texture2D = preload(
	"res://art/city/catalysts/transformer_spent.png"
)

var profile: CatalystProfile
var armed: bool = false
var spent: bool = false
var trigger_count: int = 0
var last_event: DamageEvent
var _catalyst_seen_attacks: Dictionary[int, bool] = {}


func _ready() -> void:
	intact_texture = INTACT_TEXTURE
	destroyed_texture = SPENT_TEXTURE
	intact_display_size = Vector2(128.0, 128.0)
	destroyed_display_size = Vector2(112.0, 128.0)
	visual_ground_offset = 35.0
	super._ready()
	freeze = true
	queue_redraw()


func arm(p_profile: CatalystProfile, world_position: Vector2) -> void:
	profile = p_profile
	global_position = world_position
	max_health = profile.max_health
	current_health = max_health
	armed = true
	spent = false
	visible = true
	collision_layer = 1 << 7
	collision_mask = (1 << 0) | (1 << 1)
	freeze = true
	_catalyst_seen_attacks.clear()
	visual.texture = intact_texture
	visual.modulate = Color("7de3d7") if profile.catalyst_id == &"GAS_MAIN" else Color.WHITE
	_fit_visual(intact_display_size)
	queue_redraw()


func reset_catalyst() -> void:
	armed = false
	spent = false
	visible = false
	collision_layer = 0
	collision_mask = 0
	current_health = 0.0
	last_event = null
	_catalyst_seen_attacks.clear()
	global_position = Vector2(-4096.0, -4096.0)
	queue_redraw()


func receive_damage(event: DamageEvent) -> bool:
	if not armed or spent or event == null or event.amount <= 0.0:
		return false
	if event.attack_id != 0 and _catalyst_seen_attacks.has(event.attack_id):
		return false
	if event.attack_id != 0:
		_catalyst_seen_attacks[event.attack_id] = true
	current_health = maxf(current_health - event.amount, 0.0)
	last_event = event
	if current_health <= 0.0:
		trigger(event)
	queue_redraw()
	return true


func trigger(event: DamageEvent) -> bool:
	if not armed or spent or event == null:
		return false
	spent = true
	visual.texture = destroyed_texture
	_fit_visual(destroyed_display_size)
	trigger_count += 1
	last_event = event
	triggered.emit(self, event)
	queue_redraw()
	return true


func mark_resolved(affected_count: int) -> void:
	resolved.emit(self, affected_count)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	if armed and not spent:
		var coil_color: Color = Color("f4a64d")
		draw_arc(Vector2(0.0, -30.0), 72.0, 0.0, TAU, 40, Color("f4a64d80"), 3.0)
		var ratio: float = clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)
		draw_rect(Rect2(-52.0, 37.0, 104.0, 5.0), Color("1a2227"), true)
		draw_rect(Rect2(-52.0, 37.0, 104.0 * ratio, 5.0), coil_color, true)
