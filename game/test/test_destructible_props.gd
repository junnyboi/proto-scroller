extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_cars_and_streetlamps_require_multiple_hits_then_fragment() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var debris_before: int = city.debris_pool.active_count()
	var debris_nodes_before: int = city.debris_pool.get_child_count()
	assert_eq(city.car.get_meta(&"street_destructible_kind"), &"car")
	assert_eq(city.streetlamp.get_meta(&"street_destructible_kind"), &"streetlamp")
	assert_eq(city.car.max_health, 260.0)
	assert_eq(city.streetlamp.max_health, 160.0)
	assert_true(city.car.receive_damage(_prop_hit(city, city.car, 6110, 130.0)))
	assert_false(city.car.is_broken)
	assert_eq(city.car.current_health, 130.0)
	assert_true(city.car.receive_damage(_prop_hit(city, city.car, 6111, 150.0)))
	assert_true(city.car.is_broken)
	assert_false(city.car.is_fully_destroyed)
	assert_eq(city.car.current_health, 165.0)
	assert_eq(city.debris_pool.active_count(), debris_before)
	assert_true(city.car.receive_damage(_prop_hit(city, city.car, 6112, 80.0)))
	assert_true(city.car.is_fully_destroyed)
	assert_false(city.car.visual.visible)
	assert_eq(city.debris_pool.active_count(), debris_before + 5)
	assert_true(city.streetlamp.receive_damage(
		_prop_hit(city, city.streetlamp, 6120, 80.0)
	))
	assert_false(city.streetlamp.is_broken)
	assert_true(city.streetlamp.receive_damage(
		_prop_hit(city, city.streetlamp, 6121, 90.0)
	))
	assert_true(city.streetlamp.is_broken)
	assert_false(city.streetlamp.is_fully_destroyed)
	assert_true(city.streetlamp.receive_damage(
		_prop_hit(city, city.streetlamp, 6122, 45.0)
	))
	await get_tree().physics_frame
	assert_true(city.streetlamp.is_fully_destroyed)
	assert_true(city.streetlamp.collision_shape.disabled)
	assert_eq(city.debris_pool.active_count(), debris_before + 8)
	assert_eq(city.debris_pool.get_child_count(), debris_nodes_before)
	for debris: DebrisBody2D in city.debris_pool.active_bodies():
		assert_eq(debris.material_id(), &"steel")


func test_ground_smash_blackens_props_then_next_hit_reduces_them_to_rubble() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var debris_before: int = city.debris_pool.active_count()
	assert_true(city.car.ground_smash_breaks_immediately)
	assert_true(city.streetlamp.ground_smash_breaks_immediately)
	assert_true(city.car.wreck_next_hit_fully_destroys)
	assert_true(city.streetlamp.wreck_next_hit_fully_destroys)
	assert_true(city.car.receive_damage(_ground_smash(city, city.car, 6130)))
	assert_true(city.car.is_broken)
	assert_false(city.car.is_fully_destroyed)
	assert_true(city.car.visual.visible)
	assert_same(city.car.visual.texture, city.car.destroyed_texture)
	assert_true(city.streetlamp.receive_damage(
		_ground_smash(city, city.streetlamp, 6131)
	))
	await get_tree().physics_frame
	assert_true(city.streetlamp.is_broken)
	assert_false(city.streetlamp.is_fully_destroyed)
	assert_true(city.streetlamp.visual.visible)
	assert_same(city.streetlamp.visual.texture, city.streetlamp.destroyed_texture)
	assert_eq(city.debris_pool.active_count(), debris_before)
	assert_true(city.car.receive_damage(_prop_hit(city, city.car, 6132, 1.0)))
	assert_true(city.streetlamp.receive_damage(
		_ground_smash(city, city.streetlamp, 6133)
	))
	await get_tree().physics_frame
	assert_true(city.car.is_fully_destroyed)
	assert_true(city.streetlamp.is_fully_destroyed)
	assert_false(city.car.visual.visible)
	assert_true(city.streetlamp.collision_shape.disabled)
	assert_eq(city.debris_pool.active_count(), debris_before + 8)


func _prop_hit(
	city: CitySlice,
	prop: DestructibleProp2D,
	attack_id: int,
	damage: float
) -> DamageEvent:
	return DamageEvent.new(
		attack_id,
		city.robot,
		damage,
		&"jab_cross",
		prop.global_position,
		Vector2.RIGHT,
		320.0
	)


func _ground_smash(
	city: CitySlice,
	prop: DestructibleProp2D,
	attack_id: int
) -> DamageEvent:
	return DamageEvent.new(
		attack_id,
		city.robot,
		1.0,
		&"ground_smash",
		prop.global_position,
		Vector2.UP,
		640.0
	)
