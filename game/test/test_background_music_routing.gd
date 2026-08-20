extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")


func test_background_music_player_is_persistent_and_routes_to_music_bus() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	var player: AudioStreamPlayer = main.background_music_player
	assert_not_null(player)
	assert_eq(player.bus, &"Music")
	assert_eq(player.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_gte(AudioServer.get_bus_index(player.bus), 0)
	main.start_game()
	await get_tree().process_frame
	assert_same(main.background_music_player, player)
	assert_eq(player.get_parent(), main)


func test_upgrade_duck_controller_changes_the_players_music_bus() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	main.start_game()
	await get_tree().process_frame
	var player: AudioStreamPlayer = main.background_music_player
	var duck: MusicDuckController = main.city_slice.music_duck_controller
	duck.attack_seconds = 0.0
	duck.release_seconds = 0.0
	duck.set_ducked(false, true)
	var music_bus_index: int = AudioServer.get_bus_index(player.bus)
	var baseline_db: float = AudioServer.get_bus_volume_db(music_bus_index)
	duck.set_ducked(true, true)
	assert_almost_eq(
		AudioServer.get_bus_volume_db(music_bus_index),
		baseline_db + duck.duck_db,
		0.01
	)
	duck.set_ducked(false, true)
	assert_almost_eq(AudioServer.get_bus_volume_db(music_bus_index), baseline_db, 0.01)
