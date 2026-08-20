extends GutTest

const TEST_PREFERENCE_PATH: String = "user://test-music-volume-settings.cfg"


func before_each() -> void:
	MusicVolumeSettings.clear_preference(TEST_PREFERENCE_PATH)
	MusicVolumeSettings.apply_percent(MusicVolumeSettings.DEFAULT_PERCENT)


func after_each() -> void:
	MusicVolumeSettings.clear_preference(TEST_PREFERENCE_PATH)
	MusicVolumeSettings.apply_percent(MusicVolumeSettings.DEFAULT_PERCENT)


func test_volume_conversion_and_persistence_are_bounded() -> void:
	assert_almost_eq(MusicVolumeSettings.percent_to_db(100.0), 0.0, 0.001)
	assert_almost_eq(
		MusicVolumeSettings.percent_to_db(0.0),
		MusicVolumeSettings.SILENCE_FLOOR_DB,
		0.001
	)
	assert_eq(MusicVolumeSettings.set_and_save(135.0, TEST_PREFERENCE_PATH), OK)
	assert_almost_eq(MusicVolumeSettings.load_percent(TEST_PREFERENCE_PATH), 100.0, 0.001)
	assert_eq(MusicVolumeSettings.set_and_save(-20.0, TEST_PREFERENCE_PATH), OK)
	assert_almost_eq(MusicVolumeSettings.load_percent(TEST_PREFERENCE_PATH), 0.0, 0.001)


func test_duck_controller_uses_player_volume_as_its_restoration_baseline() -> void:
	assert_eq(MusicVolumeSettings.set_and_save(35.0, TEST_PREFERENCE_PATH), OK)
	MusicVolumeSettings.apply_saved(TEST_PREFERENCE_PATH)
	var duck: MusicDuckController = MusicDuckController.new()
	add_child_autofree(duck)
	await get_tree().process_frame
	var expected_base_db: float = MusicVolumeSettings.percent_to_db(35.0)
	assert_almost_eq(duck.base_volume_db(), expected_base_db, 0.01)
	duck.set_ducked(true, true)
	assert_almost_eq(duck.current_volume_db(), expected_base_db + duck.duck_db, 0.01)
	duck.set_ducked(false, true)
	assert_almost_eq(duck.current_volume_db(), expected_base_db, 0.01)
