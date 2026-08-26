extends SceneTree
# gdlint: disable=max-returns

const MAX_FRAMES: int = 240
const ACTIVE_SHOT_PATH: String = "res://artifacts/directives/directive-active.png"
const FAILED_SHOT_PATH: String = "res://artifacts/directives/directive-failed.png"
const BREACH: DirectiveProfile = preload(
	"res://resources/directives/demolition_breach.tres"
)

var elapsed_frames: int = 0
var completed: bool = false


func _initialize() -> void:
	process_frame.connect(_on_process_frame)
	call_deferred(&"_run")


func _on_process_frame() -> void:
	if completed:
		return
	elapsed_frames += 1
	if elapsed_frames > MAX_FRAMES:
		push_error("Directive card visual scenario exceeded frame watchdog")
		quit(1)


func _run() -> void:
	var target_size: Vector2i = _target_size()
	root.get_window().content_scale_size = target_size
	root.size = target_size
	var scene: PackedScene = load("res://scenes/gameplay/city_slice.tscn") as PackedScene
	if scene == null:
		quit(1)
		return
	var city: CitySlice = scene.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	city.urban_siege.stop_run()
	var session: DirectiveSession = city.urban_siege.directives
	if not session.select(BREACH):
		quit(1)
		return
	session._process(BREACH.duration_seconds * 0.5)
	session._on_event_published(GameplayEvent.new(
		&"directive_visual_progress",
		81_001,
		GameplayEvent.Kind.CELL_DESTROYED,
		GameplayEvent.CELL_BREACH,
		100,
		4.0,
		true
	))
	var card: DirectiveCard = city.gameplay_hud.directive_card
	card._process(0.0)
	if not _active_card_is_valid(card):
		quit(1)
		return
	if DisplayServer.get_name() != "headless":
		if not await _capture(ACTIVE_SHOT_PATH, target_size):
			quit(1)
			return
	city.gameplay_hud.show_directive_result(
		L10n.t("directive.failed", {
			"name": L10n.t(BREACH.display_name),
		}),
		false,
		100
	)
	if not _result_card_is_valid(card):
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		card._process(DirectiveCard.RESULT_DISPLAY_SECONDS + 0.01)
		if card.visible:
			quit(1)
			return
		completed = true
		print("[SHOT-SKIPPED] headless lane cannot render")
		quit(0)
		return
	if not await _capture(FAILED_SHOT_PATH, target_size):
		quit(1)
		return
	card._process(DirectiveCard.RESULT_DISPLAY_SECONDS + 0.01)
	if card.visible:
		quit(1)
		return
	completed = true
	print(
		"[DIRECTIVE-CARD-VISUAL-DONE] active=%s failed=%s"
		% [ACTIVE_SHOT_PATH, FAILED_SHOT_PATH]
	)
	quit(0)


func _capture(path: String, target_size: Vector2i) -> bool:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/directives")
	)
	return (
		image.save_png(ProjectSettings.globalize_path(path)) == OK
		and image.get_size() == target_size
	)


func _active_card_is_valid(card: DirectiveCard) -> bool:
	if card == null or not card.visible:
		return false
	if card.timer_label.text != "7s" or card.progress_label.text != "OBJECTIVE 1/3":
		return false
	if not is_equal_approx(card._timer_ratio, 0.5):
		return false
	if not is_equal_approx(card._progress_ratio, 1.0 / 3.0):
		return false
	return _children_are_in_bounds(card)


func _result_card_is_valid(card: DirectiveCard) -> bool:
	return (
		card != null
		and card.visible
		and card.bank_label.text == "SCORE -100"
		and not card.timer_label.visible
		and not card.progress_track.visible
		and _children_are_in_bounds(card)
	)


func _children_are_in_bounds(card: DirectiveCard) -> bool:
	var bounds: Rect2 = Rect2(Vector2.ZERO, card.size)
	for control: Control in [
		card.title_label,
		card.timer_label,
		card.detail_label,
		card.progress_label,
		card.bank_label,
		card.progress_track,
		card.timer_track,
	]:
		if control.visible and not bounds.encloses(control.get_rect()):
			return false
	return true


func _target_size() -> Vector2i:
	if OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1":
		return Vector2i(720, 1280)
	return Vector2i(1280, 720)
