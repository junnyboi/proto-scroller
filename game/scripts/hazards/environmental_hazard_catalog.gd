class_name EnvironmentalHazardCatalog
extends RefCounted

const IDS: Array[StringName] = [
	&"traffic_signal", &"steam_main", &"powerline", &"road_plate",
	&"crane_drop", &"gas_fireline", &"facade_shear", &"metro_vent",
	&"metro_car", &"flooded_lane", &"skybridge", &"ammo_convoy",
]
const MVP_IDS: Array[StringName] = [
	&"traffic_signal", &"steam_main", &"powerline", &"road_plate",
]
const PROFILES: Dictionary = {
	&"traffic_signal": {
		"display_name": "TRAFFIC SIGNAL KILLZONE", "cost": 1,
		"texture": "res://art/city/hazards/traffic_signal_gantry.png",
		"display": Vector2(360.0, 245.0), "collision": Vector2(340.0, 190.0),
		"telegraph": 0.80, "active": 0.25, "aftermath": 2.75,
		"radius": 250.0, "enemy_damage": 120.0, "player_scale": 0.58,
		"impulse": 760.0, "behavior": &"collapse", "damage_type": &"hazard_crush",
		"warning": Color("ffb24a"), "impact": Color("ff6b32"),
		"particles": 30, "particle_lifetime": 1.10, "spread": 42.0,
		"gravity": Vector2(0.0, 720.0), "particle_speed": Vector2(170.0, 520.0),
		"particle_scale": Vector2(0.34, 0.82), "shake": Vector2(0.62, -0.88),
		"shake_pulses": 2,
	},
	&"steam_main": {
		"display_name": "STEAM MAIN BURST", "cost": 1,
		"texture": "res://art/city/hazards/steam_main_valve.png",
		"display": Vector2(150.0, 133.0), "collision": Vector2(132.0, 108.0),
		"telegraph": 0.75, "active": 1.50, "aftermath": 0.75,
		"radius": 205.0, "enemy_damage": 32.0, "player_scale": 0.55,
		"impulse": 560.0, "behavior": &"steam", "damage_type": &"hazard_steam",
		"warning": Color("f6bd62"), "impact": Color("dff8ff"),
		"particles": 38, "particle_lifetime": 1.35, "spread": 22.0,
		"gravity": Vector2(0.0, -180.0), "particle_speed": Vector2(210.0, 430.0),
		"particle_scale": Vector2(0.48, 1.18), "shake": Vector2(0.28, -0.42),
		"shake_pulses": 3,
	},
	&"powerline": {
		"display_name": "POWERLINE SNAP", "cost": 2,
		"texture": "res://art/city/hazards/powerline_pole.png",
		"display": Vector2(83.0, 320.0), "collision": Vector2(70.0, 300.0),
		"telegraph": 0.95, "active": 3.00, "aftermath": 0.60,
		"radius": 235.0, "enemy_damage": 44.0, "player_scale": 0.48,
		"impulse": 220.0, "behavior": &"electric", "damage_type": &"hazard_electric",
		"warning": Color("65cfff"), "impact": Color("79efff"),
		"particles": 26, "particle_lifetime": 0.72, "spread": 165.0,
		"gravity": Vector2.ZERO, "particle_speed": Vector2(90.0, 250.0),
		"particle_scale": Vector2(0.22, 0.62), "shake": Vector2(0.34, -0.30),
		"shake_pulses": 4,
	},
	&"road_plate": {
		"display_name": "BUCKLED ROAD PLATE", "cost": 2,
		"texture": "res://art/city/hazards/buckled_road_plate.png",
		"display": Vector2(280.0, 55.0), "collision": Vector2(265.0, 46.0),
		"telegraph": 0.70, "active": 0.30, "aftermath": 3.00,
		"radius": 220.0, "enemy_damage": 90.0, "player_scale": 0.50,
		"impulse": 920.0, "behavior": &"ramp", "damage_type": &"hazard_launch",
		"warning": Color("ffd15a"), "impact": Color("ef9c45"),
		"particles": 34, "particle_lifetime": 0.92, "spread": 58.0,
		"gravity": Vector2(0.0, 860.0), "particle_speed": Vector2(190.0, 590.0),
		"particle_scale": Vector2(0.28, 0.76), "shake": Vector2(0.52, -0.72),
		"shake_pulses": 2,
	},
	&"crane_drop": {
		"display_name": "CRANE COUNTERWEIGHT DROP", "cost": 3,
		"telegraph": 1.25, "active": 0.24, "aftermath": 3.20,
		"impact": Color("f4a64d"), "particles": 42, "particle_lifetime": 1.30,
		"spread": 48.0, "gravity": Vector2(0.0, 920.0),
		"particle_speed": Vector2(260.0, 690.0), "particle_scale": Vector2(0.44, 1.10),
		"shake": Vector2(0.82, -1.00), "shake_pulses": 3,
	},
	&"gas_fireline": {
		"display_name": "GAS MAIN FIRELINE", "cost": 3,
		"telegraph": 0.45, "active": 3.50, "aftermath": 1.00,
		"impact": Color("ff7a35"), "particles": 46, "particle_lifetime": 1.10,
		"spread": 72.0, "gravity": Vector2(0.0, -260.0),
		"particle_speed": Vector2(170.0, 480.0), "particle_scale": Vector2(0.36, 1.26),
		"shake": Vector2(0.42, -0.54), "shake_pulses": 5,
	},
	&"facade_shear": {
		"display_name": "FACADE SHEAR", "cost": 3,
		"telegraph": 1.40, "active": 0.55, "aftermath": 3.50,
		"impact": Color("c6aa87"), "particles": 54, "particle_lifetime": 1.45,
		"spread": 38.0, "gravity": Vector2(0.0, 980.0),
		"particle_speed": Vector2(240.0, 740.0), "particle_scale": Vector2(0.40, 1.24),
		"shake": Vector2(0.76, -0.92), "shake_pulses": 4,
	},
	&"metro_vent": {
		"display_name": "METRO VENT SURGE", "cost": 2,
		"telegraph": 0.70, "active": 1.00, "aftermath": 0.60,
		"impact": Color("f2d1a2"), "particles": 40, "particle_lifetime": 1.25,
		"spread": 18.0, "gravity": Vector2(0.0, -420.0),
		"particle_speed": Vector2(260.0, 620.0), "particle_scale": Vector2(0.30, 0.84),
		"shake": Vector2(0.22, -0.58), "shake_pulses": 3,
	},
	&"metro_car": {
		"display_name": "DERAILED METRO CAR", "cost": 4,
		"telegraph": 2.00, "active": 0.70, "aftermath": 4.00,
		"impact": Color("e3b26d"), "particles": 64, "particle_lifetime": 1.70,
		"spread": 46.0, "gravity": Vector2(0.0, 1040.0),
		"particle_speed": Vector2(320.0, 860.0), "particle_scale": Vector2(0.54, 1.46),
		"shake": Vector2(1.00, -0.94), "shake_pulses": 6,
	},
	&"flooded_lane": {
		"display_name": "FLOODED ELECTRIFIED LANE", "cost": 4,
		"telegraph": 1.00, "active": 2.00, "aftermath": 2.00,
		"impact": Color("67dfff"), "particles": 36, "particle_lifetime": 0.82,
		"spread": 175.0, "gravity": Vector2.ZERO,
		"particle_speed": Vector2(130.0, 330.0), "particle_scale": Vector2(0.24, 0.72),
		"shake": Vector2(0.38, -0.34), "shake_pulses": 6,
	},
	&"skybridge": {
		"display_name": "COLLAPSING SKYBRIDGE", "cost": 5,
		"telegraph": 1.80, "active": 0.65, "aftermath": 4.50,
		"impact": Color("d5b487"), "particles": 70, "particle_lifetime": 1.85,
		"spread": 42.0, "gravity": Vector2(0.0, 1120.0),
		"particle_speed": Vector2(340.0, 930.0), "particle_scale": Vector2(0.60, 1.62),
		"shake": Vector2(1.00, -1.00), "shake_pulses": 7,
	},
	&"ammo_convoy": {
		"display_name": "AMMUNITION CONVOY CHAIN", "cost": 5,
		"telegraph": 0.35, "active": 2.10, "aftermath": 3.50,
		"impact": Color("ff7138"), "particles": 72, "particle_lifetime": 1.55,
		"spread": 88.0, "gravity": Vector2(0.0, 820.0),
		"particle_speed": Vector2(290.0, 880.0), "particle_scale": Vector2(0.52, 1.55),
		"shake": Vector2(0.88, -0.82), "shake_pulses": 8,
	},
}


static func has(hazard_id: StringName) -> bool:
	return PROFILES.has(hazard_id)


static func profile(hazard_id: StringName) -> Dictionary:
	return PROFILES.get(hazard_id, {})


static func pressure_cost(hazard_id: StringName) -> int:
	return int(profile(hazard_id).get("cost", 0))


static func mvp_profiles_valid() -> bool:
	for hazard_id: StringName in MVP_IDS:
		var item: Dictionary = profile(hazard_id)
		if item.is_empty() or not item.has("texture") or not item.has("behavior"):
			return false
	return true
