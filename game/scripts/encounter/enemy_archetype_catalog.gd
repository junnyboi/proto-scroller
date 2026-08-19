class_name EnemyArchetypeCatalog
extends RefCounted

const BASE_KINDS: Array[StringName] = [&"soldier", &"tank", &"helicopter"]
const PROCEDURAL_IDS: Array[StringName] = [
	&"needle", &"bulwark", &"jackal", &"lobber", &"sapper",
	&"hound", &"mule", &"basilisk", &"lancer", &"static",
	&"kestrel", &"rainmaker", &"shrike", &"cinder", &"aegis",
	&"longbow", &"hive", &"goliath", &"nemesis", &"leviathan",
]

const PROFILES: Dictionary = {
	&"needle": {
		"display_name": "NEEDLE SPOTTER DRONE", "family": &"air", "airborne": true,
		"texture": "res://art/city/enemies/archetypes/01-needle-spotter-drone.png",
		"display": Vector2(120.0, 86.0), "collision": Vector2(98.0, 54.0),
		"spawn_y": 155.0, "health": 35.0, "speed": 205.0, "acceleration": 390.0,
		"preferred_range": 560.0, "minimum_range": 390.0, "attack_interval": 2.3,
		"projectile_kind": &"bullet", "projectile_speed": 760.0, "damage": 5.0,
		"anticipation": 0.68, "behavior": &"air_standoff", "movement_style": &"drone_hover",
		"attack_style": &"scan", "xp": 350, "threat": 1, "remains": &"air",
	},
	&"bulwark": {
		"display_name": "BULWARK RIOT TROOPER", "family": &"infantry", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/02-bulwark-riot-trooper.png",
		"display": Vector2(78.0, 118.0), "collision": Vector2(48.0, 100.0),
		"spawn_y": 540.0, "health": 110.0, "speed": 64.0, "acceleration": 430.0,
		"preferred_range": 230.0, "minimum_range": 120.0, "attack_interval": 1.45,
		"projectile_kind": &"bullet", "projectile_speed": 690.0, "damage": 7.0,
		"anticipation": 0.48, "behavior": &"ground_standoff", "movement_style": &"shield_march",
		"attack_style": &"shield_burst", "xp": 650, "threat": 1, "remains": &"infantry",
	},
	&"jackal": {
		"display_name": "JACKAL RECON BUGGY", "family": &"light", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/03-jackal-recon-buggy.png",
		"display": Vector2(210.0, 100.0), "collision": Vector2(190.0, 72.0),
		"spawn_y": 554.0, "health": 90.0, "speed": 290.0, "acceleration": 780.0,
		"preferred_range": 340.0, "minimum_range": 170.0, "attack_interval": 1.1,
		"projectile_kind": &"bullet", "projectile_speed": 820.0, "damage": 6.0,
		"anticipation": 0.40, "behavior": &"ground_pass", "movement_style": &"wheel_sprint",
		"attack_style": &"turret_burst", "xp": 900, "threat": 2, "remains": &"vehicle",
	},
	&"lobber": {
		"display_name": "LOBBER GRENADIER", "family": &"infantry", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/04-lobber-grenadier.png",
		"display": Vector2(72.0, 112.0), "collision": Vector2(44.0, 96.0),
		"spawn_y": 542.0, "health": 105.0, "speed": 82.0, "acceleration": 500.0,
		"preferred_range": 500.0, "minimum_range": 300.0, "attack_interval": 1.9,
		"projectile_kind": &"shell", "projectile_speed": 410.0, "damage": 14.0,
		"anticipation": 0.75, "behavior": &"ground_standoff", "movement_style": &"heavy_march",
		"attack_style": &"lob", "xp": 900, "threat": 2, "remains": &"infantry",
	},
	&"sapper": {
		"display_name": "SAPPER COMBAT ENGINEER", "family": &"infantry", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/05-sapper-combat-engineer.png",
		"display": Vector2(74.0, 114.0), "collision": Vector2(46.0, 98.0),
		"spawn_y": 541.0, "health": 130.0, "speed": 76.0, "acceleration": 470.0,
		"preferred_range": 420.0, "minimum_range": 240.0, "attack_interval": 2.1,
		"projectile_kind": &"bullet", "projectile_speed": 670.0, "damage": 5.0,
		"anticipation": 0.60, "behavior": &"support", "movement_style": &"utility_march",
		"attack_style": &"repair", "xp": 1050, "threat": 2, "remains": &"infantry",
	},
	&"hound": {
		"display_name": "HOUND HUNTER DRONE", "family": &"air", "airborne": true,
		"texture": "res://art/city/enemies/archetypes/06-hound-hunter-drone.png",
		"display": Vector2(180.0, 150.0), "collision": Vector2(150.0, 104.0),
		"spawn_y": 230.0, "health": 170.0, "speed": 235.0, "acceleration": 520.0,
		"preferred_range": 250.0, "minimum_range": 110.0, "attack_interval": 1.2,
		"projectile_kind": &"bullet", "projectile_speed": 850.0, "damage": 9.0,
		"anticipation": 0.40, "behavior": &"air_close", "movement_style": &"hunter_lunge",
		"attack_style": &"autocannon", "xp": 1300, "threat": 3, "remains": &"air",
	},
	&"mule": {
		"display_name": "MULE ARMORED PERSONNEL CARRIER", "family": &"heavy", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/07-mule-apc.png",
		"display": Vector2(245.0, 115.0), "collision": Vector2(225.0, 85.0),
		"spawn_y": 547.5, "health": 220.0, "speed": 72.0, "acceleration": 300.0,
		"preferred_range": 450.0, "minimum_range": 280.0, "attack_interval": 2.2,
		"projectile_kind": &"bullet", "projectile_speed": 720.0, "damage": 8.0,
		"anticipation": 0.62, "behavior": &"carrier", "movement_style": &"apc_roll",
		"attack_style": &"deploy", "spawn_kind": &"soldier", "spawn_limit": 2,
		"xp": 1700, "threat": 3, "remains": &"vehicle",
	},
	&"basilisk": {
		"display_name": "BASILISK MORTAR CARRIER", "family": &"heavy", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/08-basilisk-mortar-platform.png",
		"display": Vector2(230.0, 150.0), "collision": Vector2(215.0, 90.0),
		"spawn_y": 545.0, "health": 210.0, "speed": 54.0, "acceleration": 240.0,
		"preferred_range": 690.0, "minimum_range": 430.0, "attack_interval": 2.6,
		"projectile_kind": &"shell", "projectile_speed": 470.0, "damage": 20.0,
		"anticipation": 0.95, "behavior": &"ground_standoff", "movement_style": &"tracked_heavy",
		"attack_style": &"mortar_recoil", "xp": 1900, "threat": 3, "remains": &"vehicle",
	},
	&"lancer": {
		"display_name": "LANCER MISSILE TEAM", "family": &"infantry", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/09-lancer-missile-team.png",
		"display": Vector2(135.0, 105.0), "collision": Vector2(120.0, 85.0),
		"spawn_y": 547.5, "health": 160.0, "speed": 58.0, "acceleration": 350.0,
		"preferred_range": 650.0, "minimum_range": 390.0, "attack_interval": 2.45,
		"projectile_kind": &"rocket", "projectile_speed": 520.0, "damage": 26.0,
		"anticipation": 0.90, "behavior": &"ground_standoff", "movement_style": &"team_shuffle",
		"attack_style": &"missile_launch", "xp": 1800, "threat": 3, "remains": &"infantry",
	},
	&"static": {
		"display_name": "STATIC EW TRUCK", "family": &"light", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/10-static-ew-truck.png",
		"display": Vector2(230.0, 150.0), "collision": Vector2(205.0, 86.0),
		"spawn_y": 547.0, "health": 190.0, "speed": 52.0, "acceleration": 220.0,
		"preferred_range": 570.0, "minimum_range": 370.0, "attack_interval": 2.05,
		"projectile_kind": &"bullet", "projectile_speed": 700.0, "damage": 4.0,
		"anticipation": 0.55, "behavior": &"support", "movement_style": &"antenna_sway",
		"attack_style": &"jammer_pulse", "xp": 2200, "threat": 4, "remains": &"vehicle",
	},
	&"kestrel": {
		"display_name": "KESTREL BOMBER DRONE", "family": &"air", "airborne": true,
		"texture": "res://art/city/enemies/archetypes/11-kestrel-bomber-drone.png",
		"display": Vector2(235.0, 120.0), "collision": Vector2(210.0, 72.0),
		"spawn_y": 145.0, "health": 170.0, "speed": 285.0, "acceleration": 580.0,
		"preferred_range": 360.0, "minimum_range": 160.0, "attack_interval": 2.1,
		"projectile_kind": &"rocket", "projectile_speed": 430.0, "damage": 18.0,
		"anticipation": 0.60, "behavior": &"air_pass", "movement_style": &"bomber_bank",
		"attack_style": &"bomb_drop", "xp": 2300, "threat": 4, "remains": &"air",
	},
	&"rainmaker": {
		"display_name": "RAINMAKER MLRS", "family": &"heavy", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/12-rainmaker-mlrs.png",
		"display": Vector2(260.0, 165.0), "collision": Vector2(230.0, 92.0),
		"spawn_y": 544.0, "health": 280.0, "speed": 48.0, "acceleration": 210.0,
		"preferred_range": 720.0, "minimum_range": 450.0, "attack_interval": 2.85,
		"projectile_kind": &"rocket", "projectile_speed": 500.0, "damage": 24.0,
		"anticipation": 1.05, "behavior": &"ground_standoff", "movement_style": &"tracked_heavy",
		"attack_style": &"pod_salvo", "xp": 2900, "threat": 4, "remains": &"vehicle",
	},
	&"shrike": {
		"display_name": "SHRIKE ASSAULT VTOL", "family": &"air", "airborne": true,
		"texture": "res://art/city/enemies/archetypes/13-shrike-assault-vtol.png",
		"display": Vector2(260.0, 130.0), "collision": Vector2(225.0, 78.0),
		"spawn_y": 195.0, "health": 220.0, "speed": 260.0, "acceleration": 550.0,
		"preferred_range": 390.0, "minimum_range": 180.0, "attack_interval": 1.55,
		"projectile_kind": &"rocket", "projectile_speed": 560.0, "damage": 18.0,
		"anticipation": 0.52, "behavior": &"air_pass", "movement_style": &"vtol_strafe",
		"attack_style": &"wing_launch", "xp": 3000, "threat": 4, "remains": &"air",
	},
	&"cinder": {
		"display_name": "CINDER FLAME TANK", "family": &"heavy", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/14-cinder-flame-tank.png",
		"display": Vector2(240.0, 130.0), "collision": Vector2(220.0, 86.0),
		"spawn_y": 547.0, "health": 340.0, "speed": 68.0, "acceleration": 290.0,
		"preferred_range": 220.0, "minimum_range": 90.0, "attack_interval": 1.05,
		"projectile_kind": &"shell", "projectile_speed": 330.0, "damage": 18.0,
		"anticipation": 0.60, "behavior": &"ground_close", "movement_style": &"flame_lurch",
		"attack_style": &"flame_blast", "xp": 3600, "threat": 5, "remains": &"vehicle",
	},
	&"aegis": {
		"display_name": "AEGIS SHIELD PROJECTOR", "family": &"heavy", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/15-aegis-shield-projector.png",
		"display": Vector2(240.0, 165.0), "collision": Vector2(215.0, 92.0),
		"spawn_y": 544.0, "health": 260.0, "speed": 46.0, "acceleration": 200.0,
		"preferred_range": 500.0, "minimum_range": 320.0, "attack_interval": 2.35,
		"projectile_kind": &"bullet", "projectile_speed": 680.0, "damage": 5.0,
		"anticipation": 0.68, "behavior": &"support", "movement_style": &"dish_pulse",
		"attack_style": &"shield_pulse", "xp": 4000, "threat": 5, "remains": &"vehicle",
	},
	&"longbow": {
		"display_name": "LONGBOW RAILGUN TANK", "family": &"heavy", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/16-longbow-railgun-tank.png",
		"display": Vector2(290.0, 150.0), "collision": Vector2(255.0, 92.0),
		"spawn_y": 544.0, "health": 420.0, "speed": 42.0, "acceleration": 190.0,
		"preferred_range": 760.0, "minimum_range": 500.0, "attack_interval": 3.3,
		"projectile_kind": &"shell", "projectile_speed": 980.0, "damage": 38.0,
		"anticipation": 1.20, "behavior": &"ground_standoff", "movement_style": &"capacitor_roll",
		"attack_style": &"rail_recoil", "xp": 5100, "threat": 6, "remains": &"vehicle",
	},
	&"hive": {
		"display_name": "HIVE DRONE CARRIER", "family": &"air", "airborne": true,
		"texture": "res://art/city/enemies/archetypes/17-hive-drone-mothership.png",
		"display": Vector2(300.0, 190.0), "collision": Vector2(265.0, 135.0),
		"spawn_y": 185.0, "health": 400.0, "speed": 118.0, "acceleration": 270.0,
		"preferred_range": 600.0, "minimum_range": 400.0, "attack_interval": 2.45,
		"projectile_kind": &"rocket", "projectile_speed": 500.0, "damage": 12.0,
		"anticipation": 0.75, "behavior": &"carrier", "movement_style": &"carrier_hover",
		"attack_style": &"drone_launch", "spawn_kind": &"hound", "spawn_limit": 2,
		"xp": 5600, "threat": 6, "remains": &"air",
	},
	&"goliath": {
		"display_name": "GOLIATH SIEGE WALKER", "family": &"siege", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/18-goliath-siege-walker.png",
		"display": Vector2(260.0, 240.0), "collision": Vector2(210.0, 210.0),
		"spawn_y": 485.0, "health": 650.0, "speed": 52.0, "acceleration": 210.0,
		"preferred_range": 550.0, "minimum_range": 300.0, "attack_interval": 2.75,
		"projectile_kind": &"shell", "projectile_speed": 600.0, "damage": 32.0,
		"anticipation": 1.0, "behavior": &"ground_standoff", "movement_style": &"walker_stride",
		"attack_style": &"siege_brace", "xp": 7200, "threat": 7, "remains": &"vehicle",
	},
	&"nemesis": {
		"display_name": "NEMESIS TITAN-HUNTER MECH", "family": &"siege", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/19-nemesis-titan-hunter-mech.png",
		"display": Vector2(170.0, 240.0), "collision": Vector2(82.0, 215.0),
		"spawn_y": 482.5, "health": 850.0, "speed": 135.0, "acceleration": 520.0,
		"preferred_range": 180.0, "minimum_range": 70.0, "attack_interval": 1.1,
		"projectile_kind": &"shell", "projectile_speed": 760.0, "damage": 30.0,
		"anticipation": 0.48, "behavior": &"ground_close", "movement_style": &"mech_stride",
		"attack_style": &"lance_thrust", "xp": 10000, "threat": 9, "remains": &"vehicle",
	},
	&"leviathan": {
		"display_name": "LEVIATHAN COMMAND LANDSHIP", "family": &"siege", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/20-leviathan-command-landship.png",
		"display": Vector2(360.0, 220.0), "collision": Vector2(330.0, 170.0),
		"spawn_y": 505.0, "health": 1800.0, "speed": 34.0, "acceleration": 150.0,
		"preferred_range": 660.0, "minimum_range": 380.0, "attack_interval": 2.3,
		"projectile_kind": &"rocket", "projectile_speed": 560.0, "damage": 32.0,
		"anticipation": 1.0, "behavior": &"ground_standoff", "movement_style": &"landship_rumble",
		"attack_style": &"fortress_barrage", "xp": 20000, "threat": 12, "remains": &"vehicle",
	},
}


static func has(archetype_id: StringName) -> bool:
	return PROFILES.has(archetype_id)


static func profile(archetype_id: StringName) -> Dictionary:
	return (PROFILES.get(archetype_id, {}) as Dictionary).duplicate(true)


static func family_for(kind: StringName) -> StringName:
	if kind == &"soldier":
		return &"infantry"
	if kind == &"tank":
		return &"heavy"
	if kind == &"helicopter":
		return &"air"
	return StringName((PROFILES.get(kind, {}) as Dictionary).get("family", &""))


static func reservation_key(kind: StringName) -> StringName:
	if kind in BASE_KINDS:
		return kind
	var family: StringName = family_for(kind)
	return StringName("procedural_%s" % family) if not family.is_empty() else &""


static func threat_cost(kind: StringName) -> int:
	if kind == &"tank":
		return 3
	if kind == &"helicopter":
		return 2
	if kind == &"soldier":
		return 1
	return int((PROFILES.get(kind, {}) as Dictionary).get("threat", 0))


static func xp_value(kind: StringName) -> int:
	if kind == &"tank":
		return 1500
	if kind == &"helicopter":
		return 1200
	if kind == &"soldier":
		return 500
	return int((PROFILES.get(kind, {}) as Dictionary).get("xp", 500))


static func is_valid_kind(kind: StringName) -> bool:
	return kind in BASE_KINDS or has(kind)
