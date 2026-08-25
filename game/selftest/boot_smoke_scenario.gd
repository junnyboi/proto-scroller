extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	if main == null:
		push_error("Boot smoke could not instantiate the main scene")
		quit(1)
		return
	root.add_child(main)
	await process_frame
	await process_frame
	var title_ready: bool = main.title_screen != null and is_instance_valid(main.title_screen)
	var music_ready: bool = (
		main.background_music_player != null
		and main.background_music_player.stream != null
		and (
			main.background_music_player.playing
			== main.background_music_output_available()
		)
	)
	print("[CHECK] %s main_scene_boots" % ["PASS" if title_ready else "FAIL"])
	print("[CHECK] %s background_music_lifecycle_ready" % ["PASS" if music_ready else "FAIL"])
	root.remove_child(main)
	main.queue_free()
	await process_frame
	OS.delay_msec(100)
	await process_frame
	var passed: bool = title_ready and music_ready
	print("[BOOT-SMOKE-DONE] result=%s" % ["PASS" if passed else "FAIL"])
	quit(0 if passed else 1)
