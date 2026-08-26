class_name CampaignProgressPanel
extends Control

signal codex_requested

const PANEL_COLOR: Color = Color(0.01, 0.035, 0.055, 0.94)
const ACCENT_COLOR: Color = Color("72e5ec")
const MUTED_COLOR: Color = Color("a8bbc2")

var panel: ColorRect
var heading_label: Label
var progress_label: Label
var continuity_label: Label
var codex_button: Button
var _snapshot: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	refresh_locale()


func setup(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	refresh_locale()


func refresh_locale() -> void:
	if heading_label == null:
		return
	heading_label.text = L10n.t("narrative.campaign.heading")
	progress_label.text = L10n.t("narrative.campaign.progress", {
		"dossiers": int(_snapshot.get("dossier_count", 0)),
		"total": CityDistrictCatalog.BUILDING_VARIANT_COUNT,
	})
	continuity_label.text = L10n.t("narrative.campaign.continuity", {
		"generation": int(_snapshot.get("continuity_generation", 0)),
	})
	codex_button.text = L10n.t("narrative.campaign.open_codex")


func apply_responsive_layout(viewport_size: Vector2) -> void:
	if viewport_size.y > viewport_size.x:
		position = Vector2(28.0, 790.0)
		size = Vector2(viewport_size.x - 56.0, 310.0)
	else:
		position = Vector2(viewport_size.x - 482.0, 310.0)
		size = Vector2(430.0, 290.0)
	panel.size = size
	heading_label.position = Vector2(22.0, 18.0)
	heading_label.size = Vector2(size.x - 44.0, 60.0)
	progress_label.position = Vector2(22.0, 82.0)
	progress_label.size = Vector2(size.x - 44.0, 34.0)
	continuity_label.position = Vector2(22.0, 120.0)
	continuity_label.size = Vector2(size.x - 44.0, 70.0)
	codex_button.position = Vector2(22.0, size.y - 78.0)
	codex_button.size = Vector2(size.x - 44.0, 56.0)


func _build() -> void:
	panel = ColorRect.new()
	panel.color = PANEL_COLOR
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	heading_label = Label.new()
	heading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading_label.add_theme_font_size_override(&"font_size", 24)
	heading_label.modulate = ACCENT_COLOR
	add_child(heading_label)
	progress_label = Label.new()
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_label.add_theme_font_size_override(&"font_size", 20)
	add_child(progress_label)
	continuity_label = Label.new()
	continuity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	continuity_label.add_theme_font_size_override(&"font_size", 18)
	continuity_label.modulate = MUTED_COLOR
	add_child(continuity_label)
	codex_button = Button.new()
	codex_button.focus_mode = Control.FOCUS_ALL
	codex_button.pressed.connect(codex_requested.emit)
	add_child(codex_button)
