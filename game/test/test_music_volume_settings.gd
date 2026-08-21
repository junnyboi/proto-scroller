extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const TEST_PREFERENCE_PATH: String = "user://test-music-volume-settings.cfg"


func before_each() -> void:
	MusicVolumeSettings.clear_preference(TEST_PREFERENCE_PATH)
	_reset_bus_volumes()


func after_each() -> void:
	MusicVolumeSettings.clear_preference(TEST_PREFERENCE_PATH)
	_reset_bus_volumes()


func test_volume_conversion_and_all_bus_preferences_are_bounded() -> void:
	assert_almost_eq(MusicVolumeSettings.percent_to_db(100.0), 0.0, 0.001)
	assert_almost_eq(
		MusicVolumeSettings.percent_to_db(0.0),
		MusicVolumeSettings.SILENCE_FLOOR_DB,
		0.001
	)
	assert_eq(MusicVolumeSettings.set_and_save(135.0, TEST_PREFERENCE_PATH), OK)
	assert_eq(MusicVolumeSettings.set_sfx_and_save(-20.0, TEST_PREFERENCE_PATH), OK)
	assert_eq(MusicVolumeSettings.set_voice_and_save(42.0, TEST_PREFERENCE_PATH), OK)
	assert_almost_eq(MusicVolumeSettings.load_percent(TEST_PREFERENCE_PATH), 100.0, 0.001)
	assert_almost_eq(MusicVolumeSettings.load_sfx_percent(TEST_PREFERENCE_PATH), 0.0, 0.001)
	assert_almost_eq(MusicVolumeSettings.load_voice_percent(TEST_PREFERENCE_PATH), 42.0, 0.001)
	var restored: Dictionary[StringName, float] = MusicVolumeSettings.apply_all_saved(
		TEST_PREFERENCE_PATH
	)
	assert_almost_eq(restored[MusicVolumeSettings.MUSIC_BUS], 100.0, 0.001)
	assert_almost_eq(restored[MusicVolumeSettings.SFX_BUS], 0.0, 0.001)
	assert_almost_eq(restored[MusicVolumeSettings.VOICE_BUS], 42.0, 0.001)
	_assert_bus_percent(MusicVolumeSettings.MUSIC_BUS, 100.0)
	_assert_bus_percent(MusicVolumeSettings.SFX_BUS, 0.0)
	_assert_bus_percent(MusicVolumeSettings.VOICE_BUS, 42.0)


func test_duck_controller_uses_player_music_volume_without_touching_other_buses() -> void:
	assert_eq(MusicVolumeSettings.set_and_save(35.0, TEST_PREFERENCE_PATH), OK)
	assert_eq(MusicVolumeSettings.set_sfx_and_save(55.0, TEST_PREFERENCE_PATH), OK)
	assert_eq(MusicVolumeSettings.set_voice_and_save(65.0, TEST_PREFERENCE_PATH), OK)
	MusicVolumeSettings.apply_all_saved(TEST_PREFERENCE_PATH)
	var duck: MusicDuckController = MusicDuckController.new()
	add_child_autofree(duck)
	await get_tree().process_frame
	var expected_base_db: float = MusicVolumeSettings.percent_to_db(35.0)
	var expected_sfx_db: float = MusicVolumeSettings.percent_to_db(55.0)
	var expected_voice_db: float = MusicVolumeSettings.percent_to_db(65.0)
	assert_almost_eq(duck.base_volume_db(), expected_base_db, 0.01)
	duck.set_ducked(true, true)
	assert_almost_eq(duck.current_volume_db(), expected_base_db + duck.duck_db, 0.01)
	assert_almost_eq(_bus_volume(MusicVolumeSettings.SFX_BUS), expected_sfx_db, 0.01)
	assert_almost_eq(_bus_volume(MusicVolumeSettings.VOICE_BUS), expected_voice_db, 0.01)
	duck.set_ducked(false, true)
	assert_almost_eq(duck.current_volume_db(), expected_base_db, 0.01)


func test_runtime_players_route_to_their_separate_mix_buses() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	await get_tree().physics_frame
	for player: AudioStreamPlayer2D in city.impact_feedback_pool._audio_players:
		assert_eq(player.bus, MusicVolumeSettings.SFX_BUS)
	for player: AudioStreamPlayer2D in city.urban_siege.hazards.audio_pool._voices:
		assert_eq(player.bus, MusicVolumeSettings.SFX_BUS)
	var presenter: RobotAnimationPresenter = (
		city.robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	for player: AudioStreamPlayer2D in presenter._audio_players:
		assert_eq(player.bus, MusicVolumeSettings.SFX_BUS)
	assert_eq(presenter._status_voice_player.bus, MusicVolumeSettings.VOICE_BUS)
	assert_eq(
		city.air_target_lock_runtime._voice_player.bus,
		MusicVolumeSettings.VOICE_BUS
	)
	var flame: FlamethrowerRuntime = (
		city.upgrade_assembler.runtimes[&"FLAMETHROWER"] as FlamethrowerRuntime
	)
	assert_eq(flame.loop_audio.bus, MusicVolumeSettings.SFX_BUS)


func _reset_bus_volumes() -> void:
	MusicVolumeSettings.apply_percent(MusicVolumeSettings.DEFAULT_MUSIC_PERCENT)
	MusicVolumeSettings.apply_sfx_percent(MusicVolumeSettings.DEFAULT_SFX_PERCENT)
	MusicVolumeSettings.apply_voice_percent(MusicVolumeSettings.DEFAULT_VOICE_PERCENT)


func _assert_bus_percent(bus_name: StringName, percent: float) -> void:
	assert_almost_eq(
		_bus_volume(bus_name),
		MusicVolumeSettings.percent_to_db(percent),
		0.01
	)


func _bus_volume(bus_name: StringName) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus_name))
