extends SceneTree

const MAX_FRAMES: int = 180
const SHOT_PATH: String = "res://artifacts/directives/directive-failed.png"
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
	city.gameplay_hud.show_directive(BREACH, 0, BREACH.target_count, 0)
	city.gameplay_hud.show_directive_result(
		L10n.t("directive.failed", {
			"name": L10n.t(BREACH.display_name),
		}),
		false,
		100
	)
	var card: DirectiveCard = city.gameplay_hud.directive_card
	if not _card_bounds_are_valid(card):
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
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/directives")
	)
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
	if save_error != OK or image.get_size() != target_size:
		quit(1)
		return
	card._process(DirectiveCard.RESULT_DISPLAY_SECONDS + 0.01)
	if card.visible:
		quit(1)
		return
	completed = true
	print("[DIRECTIVE-CARD-VISUAL-DONE] path=%s" % SHOT_PATH)
	quit(0)


func _card_bounds_are_valid(card: DirectiveCard) -> bool:
	if card == null or not card.visible or card.bank_label.text != "SCORE -100":
		return false
	for label: Label in [card.title_label, card.detail_label, card.bank_label]:
		if label.position.x + label.size.x > card.size.x:
			return false
	return true


func _target_size() -> Vector2i:
	if OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1":
		return Vector2i(720, 1280)
	return Vector2i(1280, 720)
