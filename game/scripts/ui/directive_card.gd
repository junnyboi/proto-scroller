class_name DirectiveCard
extends Control

const PANEL_COLOR: Color = Color(0.03, 0.05, 0.08, 0.90)
const ACCENT_COLOR: Color = Color("f1b36f")
const COMPLETE_COLOR: Color = Color("5dc9c2")
const FAILURE_COLOR: Color = Color("ff815c")
const RESULT_DISPLAY_SECONDS: float = 2.4

var icon: TextureRect
var title_label: Label
var detail_label: Label
var bank_label: Label
var result_remaining: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel: ColorRect = ColorRect.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.color = PANEL_COLOR
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	icon = TextureRect.new()
	icon.position = Vector2(8.0, 10.0)
	icon.size = Vector2(58.0, 58.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	title_label = Label.new()
	title_label.position = Vector2(72.0, 8.0)
	title_label.size = Vector2(size.x - 80.0, 26.0)
	title_label.add_theme_font_size_override(&"font_size", 18)
	title_label.clip_text = true
	title_label.modulate = ACCENT_COLOR
	add_child(title_label)
	detail_label = Label.new()
	detail_label.position = Vector2(72.0, 35.0)
	detail_label.size = Vector2(size.x - 80.0, 40.0)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override(&"font_size", 14)
	add_child(detail_label)
	bank_label = Label.new()
	bank_label.position = Vector2(8.0, 76.0)
	bank_label.size = Vector2(size.x - 16.0, 22.0)
	bank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bank_label.add_theme_font_size_override(&"font_size", 14)
	bank_label.modulate = ACCENT_COLOR
	add_child(bank_label)
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	result_remaining = maxf(result_remaining - delta, 0.0)
	if is_zero_approx(result_remaining):
		visible = false
		set_process(false)


func show_directive(profile: DirectiveProfile, current: int, target: int, bank: int) -> void:
	if profile == null:
		visible = false
		set_process(false)
		return
	result_remaining = 0.0
	set_process(false)
	visible = true
	icon.texture = profile.icon
	title_label.text = L10n.t(profile.display_name)
	detail_label.text = L10n.t("directive.progress", {
		"instruction": L10n.t(profile.instruction),
		"current": current,
		"target": target,
	})
	bank_label.text = L10n.t("directive.pending", {"value": bank})
	title_label.modulate = ACCENT_COLOR


func set_progress(profile: DirectiveProfile, current: int, target: int) -> void:
	if profile != null:
		detail_label.text = L10n.t("directive.progress", {
			"instruction": L10n.t(profile.instruction),
			"current": current,
			"target": target,
		})


func set_bank(value: int) -> void:
	if result_remaining > 0.0:
		return
	bank_label.text = L10n.t("directive.pending", {"value": maxi(value, 0)})


func show_result(text: String, success: bool, score_delta: int = 0) -> void:
	visible = true
	title_label.text = text
	title_label.modulate = COMPLETE_COLOR if success else FAILURE_COLOR
	detail_label.text = L10n.t(
		"directive.score_secured" if success else "directive.score_penalty"
	)
	bank_label.text = L10n.t(
		"directive.secured_value" if success else "directive.penalty_value",
		{"value": maxi(score_delta, 0)}
	)
	bank_label.modulate = COMPLETE_COLOR if success else FAILURE_COLOR
	result_remaining = RESULT_DISPLAY_SECONDS
	set_process(true)
