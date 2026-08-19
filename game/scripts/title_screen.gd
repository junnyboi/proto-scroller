class_name TitleScreen
extends Control

signal start_requested

const LANDSCAPE_ART: Texture2D = preload(
	"res://art/ui/title_screen/command_deck_landscape.jpg"
)
const PORTRAIT_ART: Texture2D = preload(
	"res://art/ui/title_screen/command_deck_portrait.jpg"
)
const LANDSCAPE_BRIEFING_ART: Texture2D = preload(
	"res://art/ui/title_screen/command_deck_briefing_landscape.jpg"
)
const PORTRAIT_BRIEFING_ART: Texture2D = preload(
	"res://art/ui/title_screen/command_deck_briefing_portrait.jpg"
)
const LANDSCAPE_BRIEFING_ART_ZH_CN: Texture2D = preload(
	"res://art/ui/title_screen/command_deck_briefing_landscape_zh_cn.jpg"
)
const PORTRAIT_BRIEFING_ART_ZH_CN: Texture2D = preload(
	"res://art/ui/title_screen/command_deck_briefing_portrait_zh_cn.jpg"
)

var initialized: bool = false
var briefing_open: bool = false
var locale_preference_path: String = L10n.PREFERENCE_PATH

@onready var background_art: TextureRect = %BackgroundArt
@onready var briefing_art: TextureRect = %BriefingArt
@onready var briefing_layer: Control = %BriefingLayer
@onready var briefing_backdrop: Button = %BriefingBackdrop
@onready var briefing_toggle: Button = %BriefingToggle
@onready var initialize_button: Button = %InitializeButton
@onready var language_selector: HBoxContainer = %LanguageSelector
@onready var language_label: Label = %LanguageLabel
@onready var automatic_button: Button = %AutomaticButton
@onready var english_button: Button = %EnglishButton
@onready var chinese_button: Button = %ChineseButton
@onready var status_label: Label = %StatusLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var system_value: Label = %SystemValue


func _ready() -> void:
	initialize_button.pressed.connect(_on_initialize_pressed)
	briefing_toggle.pressed.connect(toggle_briefing)
	briefing_backdrop.pressed.connect(close_briefing)
	automatic_button.pressed.connect(_on_automatic_pressed)
	english_button.pressed.connect(_on_english_pressed)
	chinese_button.pressed.connect(_on_chinese_pressed)
	initialize_button.call_deferred("grab_focus")
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_localized_text()
	L10n.apply_locale_font(self)
	L10n.apply_cjk_font(chinese_button)
	_apply_responsive_layout()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_TAB:
			toggle_briefing()
			get_viewport().set_input_as_handled()
			return
	if briefing_open and event.is_action_pressed(&"ui_cancel"):
		close_briefing()
		get_viewport().set_input_as_handled()


func initialize_game() -> bool:
	if initialized:
		return false
	initialized = true
	close_briefing(false)
	status_label.text = L10n.t("title.expedition_active")
	status_label.modulate = Color("72ffd6")
	instruction_label.text = L10n.t("title.deployment_authorized")
	system_value.text = L10n.t("title.deploying")
	system_value.modulate = Color("72ffd6")
	initialize_button.text = L10n.t("title.deploying")
	initialize_button.disabled = true
	briefing_toggle.disabled = true
	automatic_button.disabled = true
	english_button.disabled = true
	chinese_button.disabled = true
	return true


func open_briefing() -> bool:
	if initialized or briefing_open:
		return false
	briefing_open = true
	briefing_layer.visible = true
	briefing_toggle.text = L10n.t("title.briefing_close")
	return true


func close_briefing(restore_focus: bool = true) -> bool:
	if not briefing_open:
		return false
	briefing_open = false
	briefing_layer.visible = false
	briefing_toggle.text = L10n.t("title.briefing_available")
	if restore_focus and not initialized:
		initialize_button.call_deferred("grab_focus")
	return true


func toggle_briefing() -> void:
	if briefing_open:
		close_briefing()
	else:
		open_briefing()


func select_language(locale: String) -> bool:
	if initialized or not L10n.set_locale(locale, true, locale_preference_path):
		_sync_language_selector()
		return false
	_apply_localized_text()
	L10n.apply_locale_font(self)
	L10n.apply_cjk_font(chinese_button)
	_apply_responsive_layout()
	return true


func select_automatic_language() -> bool:
	if initialized or not L10n.use_automatic_locale(locale_preference_path):
		_sync_language_selector()
		return false
	_apply_localized_text()
	L10n.apply_locale_font(self)
	L10n.apply_cjk_font(chinese_button)
	_apply_responsive_layout()
	return true


func _on_initialize_pressed() -> void:
	if initialize_game():
		start_requested.emit()


func _on_automatic_pressed() -> void:
	select_automatic_language()


func _on_english_pressed() -> void:
	select_language("en")


func _on_chinese_pressed() -> void:
	select_language("zh-CN")


func is_portrait_layout() -> bool:
	var viewport_size: Vector2 = get_viewport_rect().size
	return viewport_size.y > viewport_size.x


func _apply_localized_text() -> void:
	($ProtocolLabel as Label).text = L10n.t("title.protocol")
	(%TitleLabel as Label).text = L10n.t("title.command_heading")
	instruction_label.text = L10n.t(
		"title.deployment_authorized" if initialized else "title.command_hook"
	)
	($StatusRail/StatusItems/Objective/Key as Label).text = L10n.t(
		"title.status_objective"
	)
	($StatusRail/StatusItems/Objective/Value as Label).text = L10n.t(
		"title.status_survive"
	)
	($StatusRail/StatusItems/Threat/Key as Label).text = L10n.t("title.status_threat")
	($StatusRail/StatusItems/Threat/Value as Label).text = L10n.t(
		"title.status_ground_air"
	)
	($StatusRail/StatusItems/Upgrades/Key as Label).text = L10n.t(
		"title.status_upgrades"
	)
	($StatusRail/StatusItems/Upgrades/Value as Label).text = L10n.t(
		"title.status_during_run"
	)
	initialize_button.text = (
		L10n.t("title.deploying")
		if initialized
		else ">  %s" % L10n.t("title.begin")
	)
	($HintLabel as Label).text = L10n.t("title.input_hint")
	($MoveChip/Label as Label).text = L10n.t("title.move_chip")
	($SmashChip/Label as Label).text = L10n.t("title.smash_chip")
	briefing_toggle.text = L10n.t(
		"title.briefing_close" if briefing_open else "title.briefing_available"
	)
	language_label.text = L10n.t("title.language")
	automatic_button.text = L10n.t(
		"title.language_auto_resolved",
		{
			"automatic": L10n.t("title.language_auto"),
			"resolved": _resolved_language_label(L10n.automatic_locale()),
		}
	)
	english_button.text = L10n.t("title.language_en")
	chinese_button.text = L10n.t("title.language_zh_cn")
	_sync_language_selector()
	status_label.text = L10n.t(
		"title.expedition_active" if initialized else "title.mission_briefing"
	)
	(%ControlsLabel as Label).text = L10n.t("title.controls_body")
	($SemanticContract/FieldNote as Label).text = L10n.t("title.field_note")
	(%EnemyIntel as Label).text = L10n.t("title.enemy_intel")
	(%RunRule as Label).text = L10n.t("title.run_protocol")
	system_value.text = L10n.t("title.deploying" if initialized else "title.awaiting_pilot")
	($SemanticContract/PrimaryObjective as Label).text = L10n.t(
		"title.primary_objective"
	)
	($SemanticContract/ObjectiveOne as Label).text = L10n.t("title.objective_one")
	($SemanticContract/ObjectiveTwo as Label).text = L10n.t("title.objective_two")
	($SemanticContract/ObjectiveThree as Label).text = L10n.t("title.objective_three")


func _apply_responsive_layout() -> void:
	if is_portrait_layout():
		_apply_portrait_layout()
	else:
		_apply_landscape_layout()


func _apply_landscape_layout() -> void:
	background_art.texture = LANDSCAPE_ART
	briefing_art.texture = _briefing_texture(false)
	_set_rect($ProtocolLabel, Rect2(52.0, 250.0, 390.0, 38.0))
	_set_rect(%TitleLabel, Rect2(52.0, 290.0, 650.0, 78.0))
	_set_rect(%InstructionLabel, Rect2(52.0, 380.0, 610.0, 46.0))
	_set_rect($StatusRail, Rect2(744.0, 36.0, 504.0, 68.0))
	_set_rect(initialize_button, Rect2(52.0, 450.0, 360.0, 72.0))
	_set_rect(language_selector, Rect2(52.0, 530.0, 500.0, 48.0))
	_set_rect($HintLabel, Rect2(430.0, 464.0, 160.0, 46.0))
	_set_rect($MoveChip, Rect2(52.0, 590.0, 164.0, 48.0))
	_set_rect($SmashChip, Rect2(236.0, 590.0, 178.0, 48.0))
	_set_rect(briefing_toggle, Rect2(850.0, 648.0, 398.0, 58.0))
	_set_font_sizes(24, 56, 24)


func _apply_portrait_layout() -> void:
	background_art.texture = PORTRAIT_ART
	briefing_art.texture = _briefing_texture(true)
	_set_rect($ProtocolLabel, Rect2(56.0, 72.0, 608.0, 42.0))
	_set_rect(%TitleLabel, Rect2(56.0, 122.0, 608.0, 82.0))
	_set_rect(%InstructionLabel, Rect2(56.0, 206.0, 608.0, 50.0))
	_set_rect($StatusRail, Rect2(54.0, 268.0, 612.0, 92.0))
	_set_rect(initialize_button, Rect2(104.0, 900.0, 512.0, 92.0))
	_set_rect(language_selector, Rect2(104.0, 1004.0, 512.0, 52.0))
	_set_rect($HintLabel, Rect2(260.0, 1062.0, 200.0, 46.0))
	_set_rect($MoveChip, Rect2(120.0, 1114.0, 214.0, 58.0))
	_set_rect($SmashChip, Rect2(372.0, 1114.0, 228.0, 58.0))
	_set_rect(briefing_toggle, Rect2(174.0, 1180.0, 372.0, 70.0))
	_set_font_sizes(24, 48, 24)


func _briefing_texture(portrait: bool) -> Texture2D:
	if L10n.current_locale() == "zh-CN":
		return PORTRAIT_BRIEFING_ART_ZH_CN if portrait else LANDSCAPE_BRIEFING_ART_ZH_CN
	return PORTRAIT_BRIEFING_ART if portrait else LANDSCAPE_BRIEFING_ART


func _set_font_sizes(body_size: int, title_size: int, button_size: int) -> void:
	for label_node: Node in find_children("*", "Label", true, false):
		var label: Label = label_node as Label
		label.add_theme_font_size_override(&"font_size", body_size)
	(%TitleLabel as Label).add_theme_font_size_override(&"font_size", title_size)
	initialize_button.add_theme_font_size_override(&"font_size", button_size)
	briefing_toggle.add_theme_font_size_override(&"font_size", body_size)
	language_label.add_theme_font_size_override(&"font_size", body_size)
	automatic_button.add_theme_font_size_override(&"font_size", body_size)
	english_button.add_theme_font_size_override(&"font_size", body_size)
	chinese_button.add_theme_font_size_override(&"font_size", body_size)


func _sync_language_selector() -> void:
	var automatic_selected: bool = L10n.uses_automatic_locale(locale_preference_path)
	var chinese_selected: bool = L10n.current_locale() == "zh-CN"
	automatic_button.set_pressed_no_signal(automatic_selected)
	english_button.set_pressed_no_signal(not automatic_selected and not chinese_selected)
	chinese_button.set_pressed_no_signal(not automatic_selected and chinese_selected)


func _resolved_language_label(locale: String) -> String:
	return L10n.t(
		"title.language_resolved_zh_cn"
		if locale == "zh-CN"
		else "title.language_resolved_en"
	)


func _set_rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
	control.set_deferred(&"position", rect.position)
	control.set_deferred(&"size", rect.size)
