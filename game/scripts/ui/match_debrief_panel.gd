class_name MatchDebriefPanel
extends Control

signal retry_pressed
signal title_pressed

const CREST: Texture2D = preload("res://art/ui/match_debrief/dossier_crest.png")
const BACKGROUND: Color = Color(0.012, 0.025, 0.034, 0.985)
const CARD: Color = Color(0.022, 0.052, 0.064, 0.96)
const CARD_ALT: Color = Color(0.025, 0.042, 0.055, 0.96)
const CYAN: Color = Color("7ae4ff")
const MUTED: Color = Color("a9bdc4")
const AMBER: Color = Color("f1b36f")
const RED: Color = Color("ff695c")
const LANDSCAPE_SIZE: Vector2 = Vector2(1160.0, 636.0)
const PORTRAIT_SIZE: Vector2 = Vector2(672.0, 1018.0)
const WEAPON_ROW_COUNT: int = 3
const ENEMY_ROW_COUNT: int = 4

var content_root: Control
var scrim: ColorRect
var main_panel: ColorRect
var combo_panel: ColorRect
var career_panel: ColorRect
var weapon_panel: ColorRect
var enemy_panel: ColorRect
var result_label: Label
var grade_label: Label
var score_label: Label
var run_meta_label: Label
var crest: TextureRect
var combo_header_label: Label
var combo_value_label: Label
var combo_detail_label: Label
var personal_best_label: Label
var career_header_label: Label
var career_value_label: Label
var weapon_header_label: Label
var weapon_preferred_label: Label
var weapon_rows: Array[Label] = []
var enemy_header_label: Label
var enemy_total_label: Label
var enemy_rows: Array[Label] = []
var recommendation_label: Label
var retry_button: Button
var title_button: Button
var presented_summary: RunSummarySnapshot


func _ready() -> void:
	name = "MatchDebriefPanel"
	z_index = 30
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_controls()


func present(
	summary: RunSummarySnapshot,
	result_text: String,
	dossier_count: int,
	continuity_generation: int
) -> void:
	if summary == null:
		hide_panel()
		return
	presented_summary = summary
	result_label.text = result_text
	grade_label.text = L10n.t("debrief.grade", {"grade": summary.grade})
	score_label.text = L10n.t("debrief.score", {"score": "%08d" % summary.score})
	run_meta_label.text = L10n.t("debrief.run_meta", {
		"acts": summary.waves_cleared,
		"cycle": summary.cycle_count,
		"dossiers": dossier_count,
		"total": CityDistrictCatalog.BUILDING_VARIANT_COUNT,
		"generation": continuity_generation,
	})
	var combo_title: String = _combo_title(summary.highest_combo_tier)
	combo_value_label.text = "%s\n%s" % [
		combo_title,
		L10n.t("debrief.combo.tier", {"tier": summary.highest_combo_tier}),
	]
	combo_detail_label.text = L10n.t("debrief.combo.detail", {
		"chain": summary.best_chain,
		"multiplier": summary.peak_combo,
	})
	personal_best_label.visible = summary.new_combo_record or summary.new_score_record
	personal_best_label.text = L10n.t(
		"debrief.personal_best.both"
		if summary.new_combo_record and summary.new_score_record
		else (
			"debrief.personal_best.combo"
			if summary.new_combo_record
			else "debrief.personal_best.score"
		)
	)
	_update_career(summary.career_snapshot)
	_update_weapons(summary)
	_update_enemies(summary)
	recommendation_label.text = L10n.t("debrief.recommendation", {
		"objective": L10n.t(summary.retry_objective),
	})
	visible = true
	apply_responsive_layout(get_viewport_rect().size)
	retry_button.grab_focus()


func hide_panel() -> void:
	presented_summary = null
	visible = false


func apply_responsive_layout(viewport_size: Vector2) -> void:
	if content_root == null:
		return
	if viewport_size.y > viewport_size.x:
		_apply_portrait_layout(viewport_size)
	else:
		_apply_landscape_layout(viewport_size)


func debug_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"result": result_label.text if result_label != null else "",
		"combo": combo_value_label.text if combo_value_label != null else "",
		"personal_best": personal_best_label.visible if personal_best_label != null else false,
		"weapon_rows": _visible_row_text(weapon_rows),
		"enemy_rows": _visible_row_text(enemy_rows),
		"panel_rect": Rect2(
			content_root.position,
			main_panel.size * content_root.scale
		) if content_root != null and main_panel != null else Rect2(),
		"retry_rect": _scaled_rect(retry_button),
		"title_rect": _scaled_rect(title_button),
	}


func _build_controls() -> void:
	scrim = ColorRect.new()
	scrim.name = "DebriefScrim"
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.004, 0.009, 0.015, 0.985)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	content_root = Control.new()
	content_root.name = "Content"
	add_child(content_root)
	main_panel = _panel("DossierBackground", BACKGROUND)
	combo_panel = _panel("ComboCard", CARD)
	career_panel = _panel("CareerCard", CARD_ALT)
	weapon_panel = _panel("WeaponCard", CARD_ALT)
	enemy_panel = _panel("EnemyCard", CARD)
	result_label = _label("Result", 42, MUTED)
	grade_label = _label("Grade", 34, AMBER, HORIZONTAL_ALIGNMENT_CENTER)
	score_label = _label("Score", 34, AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	run_meta_label = _label("RunMeta", 16, MUTED)
	combo_header_label = _section_label("ComboHeader", "debrief.highest_combo")
	combo_value_label = _label("ComboValue", 28, AMBER)
	combo_detail_label = _label("ComboDetail", 16, MUTED)
	personal_best_label = _label("PersonalBest", 16, RED)
	crest = TextureRect.new()
	crest.name = "DossierCrest"
	crest.texture = CREST
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_root.add_child(crest)
	career_header_label = _section_label("CareerHeader", "debrief.career_record")
	career_value_label = _label("CareerValues", 17, MUTED)
	weapon_header_label = _section_label("WeaponHeader", "debrief.weapon_affinity")
	weapon_preferred_label = _label("PreferredWeapon", 20, AMBER)
	for index: int in range(WEAPON_ROW_COUNT):
		var row: Label = _label("WeaponRow%d" % index, 16, MUTED)
		row.clip_text = true
		weapon_rows.append(row)
	enemy_header_label = _section_label("EnemyHeader", "debrief.enemy_matrix")
	enemy_total_label = _label("EnemyTotals", 16, AMBER)
	for index: int in range(ENEMY_ROW_COUNT):
		var row: Label = _label("EnemyRow%d" % index, 16, MUTED)
		row.clip_text = true
		enemy_rows.append(row)
	recommendation_label = _label("Recommendation", 14, MUTED)
	recommendation_label.clip_text = true
	retry_button = _button("DebriefRetryButton", "hud.retry")
	retry_button.pressed.connect(retry_pressed.emit)
	title_button = _button("DebriefTitleButton", "hud.title_screen")
	title_button.pressed.connect(title_pressed.emit)


func _panel(panel_name: String, color: Color) -> ColorRect:
	var panel: ColorRect = ColorRect.new()
	panel.name = panel_name
	panel.color = color
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_root.add_child(panel)
	return panel


func _section_label(label_name: String, key: String) -> Label:
	var label: Label = _label(label_name, 17, CYAN)
	label.text = L10n.t(key)
	return label


func _label(
	label_name: String,
	font_size: int,
	color: Color,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var label: Label = Label.new()
	label.name = label_name
	label.add_theme_font_size_override(&"font_size", font_size)
	label.modulate = color
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_root.add_child(label)
	return label


func _button(button_name: String, key: String) -> Button:
	var button: Button = Button.new()
	button.name = button_name
	button.text = L10n.t(key)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override(&"font_size", 22)
	content_root.add_child(button)
	return button


func _update_career(career: Dictionary) -> void:
	if career.is_empty():
		career_value_label.text = L10n.t("debrief.career.local_record_unavailable")
		return
	career_value_label.text = L10n.t("debrief.career.values", {
		"score": "%08d" % int(career.get("best_score", 0)),
		"tier": int(career.get("highest_combo_tier", 0)),
		"kills": int(career.get("total_enemy_kills", 0)),
		"runs": int(career.get("total_runs", 0)),
		"victories": int(career.get("victories", 0)),
	})


func _update_weapons(summary: RunSummarySnapshot) -> void:
	var ranked: Array[Dictionary] = CombatRunTelemetry.ranked_entries(
		summary.weapon_kills,
		WEAPON_ROW_COUNT
	)
	weapon_preferred_label.text = L10n.t("debrief.preferred_weapon", {
		"weapon": _weapon_name(summary.preferred_weapon),
	})
	for index: int in range(weapon_rows.size()):
		var row: Label = weapon_rows[index]
		row.visible = index < ranked.size()
		if not row.visible:
			row.text = ""
			continue
		var entry: Dictionary = ranked[index]
		var count: int = int(entry.count)
		var percent: int = roundi(
			float(count) * 100.0 / float(maxi(summary.total_enemies_defeated, 1))
		)
		row.text = L10n.t("debrief.weapon_row", {
			"weapon": _weapon_name(entry.id as StringName),
			"kills": count,
			"percent": percent,
		})
	if ranked.is_empty():
		weapon_rows[0].visible = true
		weapon_rows[0].text = L10n.t("debrief.no_weapon_data")


func _update_enemies(summary: RunSummarySnapshot) -> void:
	enemy_total_label.text = L10n.t("debrief.enemy_totals", {
		"kills": summary.total_enemies_defeated,
		"types": summary.unique_enemy_types,
	})
	var ranked: Array[Dictionary] = CombatRunTelemetry.ranked_entries(
		summary.enemy_kills,
		ENEMY_ROW_COUNT
	)
	for index: int in range(enemy_rows.size()):
		var row: Label = enemy_rows[index]
		row.visible = index < ranked.size()
		if not row.visible:
			row.text = ""
			continue
		var entry: Dictionary = ranked[index]
		row.text = L10n.t("debrief.enemy_row", {
			"enemy": _enemy_name(entry.id as StringName),
			"kills": int(entry.count),
		})
	if ranked.is_empty():
		enemy_rows[0].visible = true
		enemy_rows[0].text = L10n.t("debrief.no_enemy_data")


func _combo_title(tier: int) -> String:
	if tier <= 0:
		return L10n.t("debrief.combo.none")
	var selected_tier: int = 0
	for milestone: int in ComboHeraldCatalog.milestone_counts():
		if milestone <= tier:
			selected_tier = milestone
	var profile: Dictionary = ComboHeraldCatalog.profile_for(selected_tier)
	if profile.is_empty():
		return L10n.t("debrief.combo.single")
	return L10n.t(String(profile.get(&"title_key", "debrief.combo.single")))


func _weapon_name(weapon_id: StringName) -> String:
	var key: String = "debrief.weapon.%s" % String(weapon_id).to_lower()
	var translated: String = L10n.t(key)
	return _prettify_identifier(weapon_id) if translated == key else translated


func _enemy_name(enemy_id: StringName) -> String:
	var raw: String = String(enemy_id)
	if raw.begins_with("boss:"):
		var boss_id: String = raw.trim_prefix("boss:")
		var boss_key: String = "boss.%s.name" % boss_id
		var boss_name: String = L10n.t(boss_key)
		return _prettify_identifier(StringName(boss_id)) if boss_name == boss_key else boss_name
	if enemy_id in [&"soldier", &"tank", &"helicopter"]:
		return L10n.t("debrief.enemy.%s" % raw)
	var profile: Dictionary = EnemyArchetypeCatalog.profile(enemy_id)
	if not profile.is_empty():
		return String(profile.get("display_name", _prettify_identifier(enemy_id)))
	return _prettify_identifier(enemy_id)


func _prettify_identifier(identifier: StringName) -> String:
	return String(identifier).replace("_", " ").replace(":", " ").to_upper()


func _apply_landscape_layout(viewport_size: Vector2) -> void:
	_place_content(viewport_size, LANDSCAPE_SIZE, 40.0)
	main_panel.position = Vector2.ZERO
	main_panel.size = LANDSCAPE_SIZE
	result_label.position = Vector2(30.0, 14.0)
	result_label.size = Vector2(590.0, 56.0)
	result_label.add_theme_font_size_override(&"font_size", 42)
	grade_label.position = Vector2(655.0, 12.0)
	grade_label.size = Vector2(180.0, 60.0)
	grade_label.add_theme_font_size_override(&"font_size", 34)
	score_label.position = Vector2(845.0, 12.0)
	score_label.size = Vector2(285.0, 60.0)
	score_label.add_theme_font_size_override(&"font_size", 34)
	run_meta_label.position = Vector2(30.0, 70.0)
	run_meta_label.size = Vector2(1100.0, 28.0)
	run_meta_label.add_theme_font_size_override(&"font_size", 16)
	combo_panel.position = Vector2(20.0, 106.0)
	combo_panel.size = Vector2(535.0, 224.0)
	crest.position = Vector2(36.0, 146.0)
	crest.size = Vector2(152.0, 152.0)
	combo_header_label.position = Vector2(206.0, 118.0)
	combo_header_label.size = Vector2(325.0, 26.0)
	combo_value_label.position = Vector2(206.0, 148.0)
	combo_value_label.size = Vector2(315.0, 84.0)
	combo_value_label.add_theme_font_size_override(&"font_size", 27)
	combo_detail_label.position = Vector2(206.0, 234.0)
	combo_detail_label.size = Vector2(315.0, 28.0)
	personal_best_label.position = Vector2(206.0, 270.0)
	personal_best_label.size = Vector2(315.0, 35.0)
	career_panel.position = Vector2(20.0, 340.0)
	career_panel.size = Vector2(535.0, 176.0)
	career_header_label.position = Vector2(40.0, 350.0)
	career_header_label.size = Vector2(495.0, 30.0)
	career_value_label.position = Vector2(40.0, 384.0)
	career_value_label.size = Vector2(495.0, 116.0)
	career_value_label.add_theme_font_size_override(&"font_size", 17)
	weapon_panel.position = Vector2(565.0, 106.0)
	weapon_panel.size = Vector2(575.0, 190.0)
	weapon_header_label.position = Vector2(585.0, 116.0)
	weapon_header_label.size = Vector2(535.0, 26.0)
	weapon_preferred_label.position = Vector2(585.0, 144.0)
	weapon_preferred_label.size = Vector2(535.0, 30.0)
	for index: int in range(weapon_rows.size()):
		weapon_rows[index].position = Vector2(585.0, 177.0 + float(index) * 33.0)
		weapon_rows[index].size = Vector2(535.0, 30.0)
		weapon_rows[index].add_theme_font_size_override(&"font_size", 16)
	enemy_panel.position = Vector2(565.0, 306.0)
	enemy_panel.size = Vector2(575.0, 210.0)
	enemy_header_label.position = Vector2(585.0, 316.0)
	enemy_header_label.size = Vector2(310.0, 26.0)
	enemy_total_label.position = Vector2(895.0, 316.0)
	enemy_total_label.size = Vector2(225.0, 26.0)
	enemy_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for index: int in range(enemy_rows.size()):
		enemy_rows[index].position = Vector2(585.0, 348.0 + float(index) * 37.0)
		enemy_rows[index].size = Vector2(535.0, 32.0)
		enemy_rows[index].add_theme_font_size_override(&"font_size", 16)
	recommendation_label.position = Vector2(30.0, 520.0)
	recommendation_label.size = Vector2(1100.0, 28.0)
	retry_button.position = Vector2(190.0, 558.0)
	retry_button.size = Vector2(350.0, 60.0)
	title_button.position = Vector2(620.0, 558.0)
	title_button.size = Vector2(350.0, 60.0)


func _apply_portrait_layout(viewport_size: Vector2) -> void:
	_place_content(viewport_size, PORTRAIT_SIZE, 24.0)
	main_panel.position = Vector2.ZERO
	main_panel.size = PORTRAIT_SIZE
	result_label.position = Vector2(20.0, 12.0)
	result_label.size = Vector2(632.0, 48.0)
	result_label.add_theme_font_size_override(&"font_size", 34)
	grade_label.position = Vector2(20.0, 62.0)
	grade_label.size = Vector2(190.0, 48.0)
	grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	grade_label.add_theme_font_size_override(&"font_size", 28)
	score_label.position = Vector2(220.0, 62.0)
	score_label.size = Vector2(432.0, 48.0)
	score_label.add_theme_font_size_override(&"font_size", 28)
	run_meta_label.position = Vector2(20.0, 112.0)
	run_meta_label.size = Vector2(632.0, 26.0)
	run_meta_label.add_theme_font_size_override(&"font_size", 14)
	combo_panel.position = Vector2(16.0, 146.0)
	combo_panel.size = Vector2(640.0, 190.0)
	crest.position = Vector2(30.0, 176.0)
	crest.size = Vector2(132.0, 132.0)
	combo_header_label.position = Vector2(182.0, 158.0)
	combo_header_label.size = Vector2(450.0, 25.0)
	combo_value_label.position = Vector2(182.0, 188.0)
	combo_value_label.size = Vector2(450.0, 76.0)
	combo_value_label.add_theme_font_size_override(&"font_size", 24)
	combo_detail_label.position = Vector2(182.0, 263.0)
	combo_detail_label.size = Vector2(450.0, 25.0)
	personal_best_label.position = Vector2(182.0, 292.0)
	personal_best_label.size = Vector2(450.0, 28.0)
	weapon_panel.position = Vector2(16.0, 346.0)
	weapon_panel.size = Vector2(640.0, 184.0)
	weapon_header_label.position = Vector2(32.0, 356.0)
	weapon_header_label.size = Vector2(608.0, 25.0)
	weapon_preferred_label.position = Vector2(32.0, 383.0)
	weapon_preferred_label.size = Vector2(608.0, 29.0)
	for index: int in range(weapon_rows.size()):
		weapon_rows[index].position = Vector2(32.0, 414.0 + float(index) * 33.0)
		weapon_rows[index].size = Vector2(608.0, 30.0)
		weapon_rows[index].add_theme_font_size_override(&"font_size", 15)
	enemy_panel.position = Vector2(16.0, 540.0)
	enemy_panel.size = Vector2(640.0, 210.0)
	enemy_header_label.position = Vector2(32.0, 550.0)
	enemy_header_label.size = Vector2(340.0, 25.0)
	enemy_total_label.position = Vector2(372.0, 550.0)
	enemy_total_label.size = Vector2(268.0, 25.0)
	enemy_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for index: int in range(enemy_rows.size()):
		enemy_rows[index].position = Vector2(32.0, 580.0 + float(index) * 39.0)
		enemy_rows[index].size = Vector2(608.0, 34.0)
		enemy_rows[index].add_theme_font_size_override(&"font_size", 15)
	career_panel.position = Vector2(16.0, 760.0)
	career_panel.size = Vector2(640.0, 142.0)
	career_header_label.position = Vector2(32.0, 770.0)
	career_header_label.size = Vector2(608.0, 25.0)
	career_value_label.position = Vector2(32.0, 798.0)
	career_value_label.size = Vector2(608.0, 90.0)
	career_value_label.add_theme_font_size_override(&"font_size", 15)
	recommendation_label.position = Vector2(24.0, 906.0)
	recommendation_label.size = Vector2(624.0, 28.0)
	retry_button.position = Vector2(24.0, 944.0)
	retry_button.size = Vector2(296.0, 58.0)
	title_button.position = Vector2(352.0, 944.0)
	title_button.size = Vector2(296.0, 58.0)


func _place_content(viewport_size: Vector2, design_size: Vector2, margin: float) -> void:
	var scale_factor: float = minf(
		minf(
			(viewport_size.x - margin * 2.0) / design_size.x,
			(viewport_size.y - margin * 2.0) / design_size.y
		),
		1.0
	)
	scale_factor = maxf(scale_factor, 0.45)
	content_root.scale = Vector2.ONE * scale_factor
	content_root.size = design_size
	content_root.position = (viewport_size - design_size * scale_factor) * 0.5


func _visible_row_text(rows: Array[Label]) -> PackedStringArray:
	var text: PackedStringArray = []
	for row: Label in rows:
		if row.visible:
			text.append(row.text)
	return text


func _scaled_rect(control: Control) -> Rect2:
	if control == null or content_root == null:
		return Rect2()
	return Rect2(
		content_root.position + control.position * content_root.scale,
		control.size * content_root.scale
	)
