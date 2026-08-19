extends GutTest

const MANIFEST_PATH: String = "res://art/upgrades_art_manifest.json"
const UPGRADE_CONFIRM: AudioStream = preload(
	"res://audio/sfx/upgrades/upgrade_confirm.wav"
)


func test_art_manifest_covers_all_required_assets_with_bounded_bytes() -> void:
	var manifest_text: String = FileAccess.get_file_as_string(MANIFEST_PATH)
	var manifest: Dictionary = JSON.parse_string(manifest_text) as Dictionary
	var assets: Array = manifest.assets as Array
	assert_eq(assets.size(), 24)
	var total_bytes: int = 0
	for record_variant: Variant in assets:
		var record: Dictionary = record_variant as Dictionary
		var relative_path: String = String(record.shipping_path).trim_prefix("res://")
		assert_true(FileAccess.file_exists("res://%s" % relative_path))
		assert_eq(String(record.model), "gpt-image-2")
		assert_ne(String(record.shipping_sha256), "")
		total_bytes += int(record.encoded_bytes)
	assert_lt(total_bytes, 1024 * 1024)


func test_every_upgrade_profile_has_a_generated_icon() -> void:
	var catalog: UpgradeCatalog = load(
		"res://resources/upgrades/upgrade_catalog.tres"
	) as UpgradeCatalog
	assert_eq(catalog.profiles.size(), 9)
	for profile: UpgradeProfile in catalog.profiles:
		assert_not_null(profile.icon, "%s icon" % profile.upgrade_id)
		assert_gte(profile.icon.get_width(), 256)
		assert_gte(profile.icon.get_height(), 256)


func test_atlas_boundaries_have_transparent_gutters() -> void:
	_assert_gutters(
		"res://art/destruction/destruction_debris_atlas.png",
		4,
		4
	)
	_assert_gutters(
		"res://art/player/weapons/player_missile_explosion_atlas.png",
		4,
		2
	)
	_assert_gutters("res://art/presentation/flame_plume_atlas.png", 4, 2)
	_assert_gutters("res://art/presentation/flame_ignition_atlas.png", 3, 2)
	_assert_gutters("res://art/presentation/flame_contact_atlas.png", 4, 1)
	_assert_gutters("res://art/presentation/scorch_decals.png", 2, 2)


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
	var player: AudioStreamPlayer2D = pool.play_semantic(
		&"upgrade",
		Vector2.ZERO,
		6
	)
	assert_not_null(player)
	if player != null:
		assert_same(player.stream, UPGRADE_CONFIRM)
	assert_eq(pool.audio_child_count(), RuntimeBudget.AUDIO_VOICES)
	assert_eq(pool.last_semantic_audio, &"upgrade")


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
