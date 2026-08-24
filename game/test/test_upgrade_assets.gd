extends GutTest

const MANIFEST_PATH: String = "res://art/upgrades_art_manifest.json"
const UPGRADE_CONFIRM: AudioStream = preload(
	"res://audio/sfx/upgrades/upgrade_confirm.wav"
)


func test_art_manifest_covers_all_required_assets_with_bounded_bytes() -> void:
	var manifest_text: String = FileAccess.get_file_as_string(MANIFEST_PATH)
	var manifest: Dictionary = JSON.parse_string(manifest_text) as Dictionary
	var assets: Array = manifest.assets as Array
	assert_eq(assets.size(), 32)
	var total_bytes: int = 0
	for record_variant: Variant in assets:
		var record: Dictionary = record_variant as Dictionary
		var relative_path: String = String(record.shipping_path).trim_prefix("res://")
		assert_true(FileAccess.file_exists("res://%s" % relative_path))
		assert_eq(String(record.model), "gpt-image-2")
		assert_ne(String(record.shipping_sha256), "")
		var encoded_size: int = (
			FileAccess.get_file_as_bytes("res://%s" % relative_path).size()
		)
		assert_eq(encoded_size, int(record.encoded_bytes))
		total_bytes += int(record.encoded_bytes)
	assert_lt(total_bytes, 1024 * 1024)


func test_every_upgrade_profile_has_a_generated_icon() -> void:
	var catalog: UpgradeCatalog = load(
		"res://resources/upgrades/upgrade_catalog.tres"
	) as UpgradeCatalog
	var english_keys: PackedStringArray = L10n.keys_for_locale("en")
	var chinese_keys: PackedStringArray = L10n.keys_for_locale("zh-CN")
	assert_eq(catalog.profiles.size(), 11)
	for profile: UpgradeProfile in catalog.profiles:
		assert_has(english_keys, profile.display_name, "%s English name" % profile.upgrade_id)
		assert_has(chinese_keys, profile.display_name, "%s Chinese name" % profile.upgrade_id)
		assert_has(english_keys, profile.description, "%s English copy" % profile.upgrade_id)
		assert_has(chinese_keys, profile.description, "%s Chinese copy" % profile.upgrade_id)
		assert_not_null(profile.icon, "%s icon" % profile.upgrade_id)
		assert_gte(profile.icon.get_width(), 256)
		assert_gte(profile.icon.get_height(), 256)


func test_atlas_boundaries_have_transparent_gutters() -> void:
	_assert_gutters(
		"res://art/destruction/destruction_debris_atlas.png",
		4,
		4
	)
	var standalone_paths: PackedStringArray = PackedStringArray([
		"res://art/player/weapons/machine_gun_mount.png",
		"res://art/player/weapons/machine_gun_round.png",
		"res://art/player/weapons/machine_gun_muzzle_flash.png",
		"res://art/player/weapons/machine_gun_impact.png",
		"res://art/player/weapons/missile_pod_mount.png",
		"res://art/player/weapons/player_missile_body.png",
		"res://art/player/weapons/missile_exhaust.png",
		"res://art/player/weapons/missile_explosion_flash.png",
		"res://art/player/weapons/missile_explosion_fire.png",
		"res://art/player/weapons/missile_explosion_smoke.png",
		"res://art/player/weapons/anti_air_emitter.png",
		"res://art/player/weapons/anti_air_beam_core.png",
		"res://art/player/weapons/anti_air_impact.png",
		"res://art/player/weapons/flamethrower_nozzle.png",
		"res://art/presentation/flame_plume.png",
		"res://art/presentation/flame_ignition.png",
		"res://art/presentation/flame_contact.png",
		"res://art/presentation/scorch_decal.png",
	])
	for path: String in standalone_paths:
		_assert_transparent_border(path)


func test_directional_icon_drone_and_fist_projectile_have_clear_borders() -> void:
	_assert_clear_border("res://art/ui/upgrades/directional_shockwave_icon.png")
	_assert_clear_border("res://art/player/drones/weapon_drone_chassis_east.png")
	_assert_clear_border("res://art/player/weapons/directional_punch_fist.png")


func test_upgrade_audio_is_original_48khz_pcm16_and_uses_fixed_pool() -> void:
	var stream: AudioStreamWAV = UPGRADE_CONFIRM as AudioStreamWAV
	assert_not_null(stream)
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(stream.mix_rate, 48000)
	assert_false(stream.stereo)
	var particle_root: Node2D = Node2D.new()
	var audio_root: Node2D = Node2D.new()
	add_child_autofree(particle_root)
	add_child_autofree(audio_root)
	var pool: ImpactFeedbackPool = ImpactFeedbackPool.new()
	pool.setup(particle_root, audio_root)
	add_child_autofree(pool)
	await get_tree().process_frame
	var player: AudioStreamPlayer2D = pool.play_cue(
		AudioCueRegistry.Cue.UPGRADE_CONFIRM,
		Vector2.ZERO
	)
	assert_not_null(player)
	if player != null:
		assert_same(player.stream, UPGRADE_CONFIRM)
		assert_eq(player.bus, GameAudioBus.UI)
		assert_eq(
			AudioVoicePriority.priority_of(player),
			AudioVoicePriority.MAJOR
		)
	assert_eq(pool.audio_child_count(), RuntimeBudget.AUDIO_VOICES)
	assert_eq(pool.last_cue, AudioCueRegistry.Cue.UPGRADE_CONFIRM)


func _assert_gutters(path: String, columns: int, rows: int) -> void:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	assert_false(image.is_empty(), path)
	for column: int in range(1, columns):
		var x: int = roundi(float(image.get_width() * column) / float(columns))
		for y: int in range(image.get_height()):
			assert_eq(image.get_pixel(x, y).a, 0.0, "%s x=%d y=%d" % [path, x, y])
	for row: int in range(1, rows):
		var y: int = roundi(float(image.get_height() * row) / float(rows))
		for x: int in range(image.get_width()):
			assert_eq(image.get_pixel(x, y).a, 0.0, "%s x=%d y=%d" % [path, x, y])


func _assert_clear_border(path: String) -> void:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	assert_false(image.is_empty(), path)
	for x: int in range(image.get_width()):
		assert_eq(image.get_pixel(x, 0).a, 0.0, "%s top x=%d" % [path, x])
		assert_eq(
			image.get_pixel(x, image.get_height() - 1).a,
			0.0,
			"%s bottom x=%d" % [path, x]
		)
	for y: int in range(image.get_height()):
		assert_eq(image.get_pixel(0, y).a, 0.0, "%s left y=%d" % [path, y])
		assert_eq(
			image.get_pixel(image.get_width() - 1, y).a,
			0.0,
			"%s right y=%d" % [path, y]
		)


func _assert_transparent_border(path: String) -> void:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	assert_false(image.is_empty(), path)
	assert_lte(image.get_width(), 256, path)
	assert_lte(image.get_height(), 160, path)
	for x: int in range(image.get_width()):
		assert_eq(image.get_pixel(x, 0).a, 0.0, "%s top x=%d" % [path, x])
		assert_eq(
			image.get_pixel(x, image.get_height() - 1).a,
			0.0,
			"%s bottom x=%d" % [path, x]
		)
	for y: int in range(image.get_height()):
		assert_eq(image.get_pixel(0, y).a, 0.0, "%s left y=%d" % [path, y])
		assert_eq(
			image.get_pixel(image.get_width() - 1, y).a,
			0.0,
			"%s right y=%d" % [path, y]
		)
