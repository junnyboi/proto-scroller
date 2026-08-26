class_name WeaponShopOverlay
extends Control

signal purchase_requested(product_id: StringName)
signal preview_requested(product_id: StringName)
signal continue_requested

var shade: ColorRect
var backplate: TextureRect
var frame: PanelContainer
var title_label: Label
var tagline_label: Label
var credit_icon: TextureRect
var score_caption: Label
var score_label: Label
var warning_label: Label
var continue_button: Button
var preview_panel: WeaponShopStatPreviewPanel
var dialogue_panel: WeaponShopDialoguePanel
var confirmation_panel: WeaponShopConfirmationPanel
var upgrade_particles: CPUParticles2D
var repair_particles: CPUParticles2D
var cards: Array[WeaponShopCard] = []
var district: CityDistrictProfile
var active: bool = false
var current_score: int = 0
var transaction_burst_count: int = 0
var _statuses: Dictionary[StringName, StringName] = {}
var _previews: Dictionary[StringName, Array] = {}
var _input_armed_frame: int = 0


func _ready() -> void:
	name = "WeaponShopOverlay"
	z_index = 120
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_controls()
	visible = false
	get_viewport().size_changed.connect(apply_responsive_layout)
	apply_responsive_layout()


func _unhandled_input(event: InputEvent) -> void:
	if not active or Engine.get_process_frames() < _input_armed_frame:
		return
	if event.is_action_pressed(&"ui_cancel"):
		if dialogue_panel.active or confirmation_panel.active:
			return
		continue_requested.emit()
		get_viewport().set_input_as_handled()


func show_shop(
	p_district: CityDistrictProfile,
	products: Array[WeaponShopProduct],
	score: int,
	statuses: Dictionary[StringName, StringName]
) -> void:
	if p_district == null or products.size() != WeaponShopCatalog.PRODUCTS_PER_DISTRICT:
		return
	district = p_district
	_statuses = statuses.duplicate()
	_previews.clear()
	var accent: Color = district.accent_color.lightened(0.24)
	backplate.texture = WeaponShopVisualCatalog.backplate(district.district_id)
	title_label.text = L10n.t(WeaponShopCatalog.shop_title_key(district.district_id))
	tagline_label.text = L10n.t(WeaponShopCatalog.shop_tagline_key(district.district_id))
	for index: int in range(cards.size()):
		var product: WeaponShopProduct = products[index]
		cards[index].configure(
			product,
			statuses.get(product.product_id, &"available"),
			accent
		)
	_set_accent(accent)
	set_score(score)
	preview_panel.visible = false
	active = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_responsive_layout()
	_input_armed_frame = Engine.get_process_frames() + 2
	dialogue_panel.show_dialogue(district.district_id)


func hide_shop() -> void:
	active = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_panel.hide_dialogue()
	confirmation_panel.hide_confirmation()
	release_focus()


func set_score(value: int) -> void:
	current_score = maxi(value, 0)
	score_label.text = "%08d" % current_score


func set_preview(
	product: WeaponShopProduct,
	rows: Array[Dictionary],
	status: StringName
) -> void:
	if product == null:
		return
	_previews[product.product_id] = rows
	preview_panel.show_preview(product, rows, status)


func update_status(product_id: StringName, status: StringName) -> void:
	_statuses[product_id] = status
	for card: WeaponShopCard in cards:
		if card.product != null and card.product.product_id == product_id:
			card.set_status(status)
			break
	preview_panel.update_status(product_id, status)
	_focus_first_available()


func play_transaction_success(product: WeaponShopProduct) -> void:
	if product == null:
		return
	var particles: CPUParticles2D = repair_particles if product.is_repair() else upgrade_particles
	var card: WeaponShopCard = _card_for(product.product_id)
	particles.position = get_viewport_rect().size * 0.5
	if card != null:
		particles.position = card.position + card.size * 0.5
	particles.restart()
	transaction_burst_count += 1


func apply_responsive_layout() -> void:
	if shade == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	backplate.size = viewport_size
	shade.size = viewport_size
	frame.position = Vector2(18.0, 18.0)
	frame.size = viewport_size - Vector2(36.0, 36.0)
	if viewport_size.y > viewport_size.x:
		_apply_portrait(viewport_size)
	else:
		_apply_landscape(viewport_size)


func _build_controls() -> void:
	backplate = TextureRect.new()
	backplate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backplate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backplate)
	shade = ColorRect.new()
	shade.color = Color(0.004, 0.01, 0.016, 0.60)
	add_child(shade)
	frame = PanelContainer.new()
	var frame_style: StyleBoxFlat = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.015, 0.025, 0.032, 0.88)
	frame_style.set_border_width_all(2)
	frame_style.border_color = Color("50636c")
	frame.add_theme_stylebox_override(&"panel", frame_style)
	add_child(frame)
	title_label = _label(38, Color("e8f3ef"))
	title_label.name = "ShopTitle"
	add_child(title_label)
	tagline_label = _label(17, Color("9fb0b8"))
	add_child(tagline_label)
	credit_icon = TextureRect.new()
	credit_icon.texture = WeaponShopVisualCatalog.RAMPAGE_CREDIT
	credit_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	credit_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	credit_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(credit_icon)
	score_caption = _label(16, Color("f1b36f"))
	score_caption.text = L10n.t("shop.credit")
	add_child(score_caption)
	score_label = _label(28, Color("f1b36f"))
	add_child(score_label)
	for index: int in range(WeaponShopCatalog.PRODUCTS_PER_DISTRICT):
		var card: WeaponShopCard = WeaponShopCard.new()
		card.name = "WeaponShopCard%d" % index
		card.preview_requested.connect(_on_card_preview_requested)
		card.purchase_requested.connect(_on_card_purchase_requested)
		add_child(card)
		cards.append(card)
	cards[0].focus_neighbor_right = cards[1].get_path()
	cards[1].focus_neighbor_left = cards[0].get_path()
	cards[1].focus_neighbor_right = cards[2].get_path()
	cards[2].focus_neighbor_left = cards[1].get_path()
	preview_panel = WeaponShopStatPreviewPanel.new()
	add_child(preview_panel)
	warning_label = _label(17, Color("d98262"))
	warning_label.text = L10n.t("shop.score_warning")
	add_child(warning_label)
	continue_button = Button.new()
	continue_button.text = L10n.t("shop.continue")
	continue_button.add_theme_font_size_override(&"font_size", 22)
	continue_button.pressed.connect(continue_requested.emit)
	add_child(continue_button)
	upgrade_particles = _transaction_particles(WeaponShopVisualCatalog.UPGRADE_BURST)
	repair_particles = _transaction_particles(WeaponShopVisualCatalog.REPAIR_BURST)
	add_child(upgrade_particles)
	add_child(repair_particles)
	dialogue_panel = WeaponShopDialoguePanel.new()
	dialogue_panel.dismissed.connect(_on_dialogue_dismissed)
	add_child(dialogue_panel)
	confirmation_panel = WeaponShopConfirmationPanel.new()
	confirmation_panel.confirmed.connect(purchase_requested.emit)
	confirmation_panel.canceled.connect(_focus_first_available)
	add_child(confirmation_panel)


func _apply_landscape(viewport_size: Vector2) -> void:
	title_label.add_theme_font_size_override(&"font_size", 38)
	title_label.position = Vector2(54.0, 48.0)
	title_label.size = Vector2(viewport_size.x * 0.62, 52.0)
	tagline_label.position = Vector2(58.0, 98.0)
	tagline_label.size = Vector2(viewport_size.x * 0.67, 28.0)
	credit_icon.position = Vector2(viewport_size.x - 394.0, 50.0)
	credit_icon.size = Vector2(42.0, 42.0)
	score_caption.position = Vector2(viewport_size.x - 350.0, 48.0)
	score_caption.size = Vector2(290.0, 24.0)
	score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.position = Vector2(viewport_size.x - 350.0, 72.0)
	score_label.size = Vector2(290.0, 38.0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var preview_width: float = 280.0
	var gap: float = 16.0
	var cards_left: float = 44.0
	var cards_right: float = viewport_size.x - preview_width - 70.0
	var card_width: float = (cards_right - cards_left - gap * 2.0) / 3.0
	var card_height: float = minf(390.0, viewport_size.y - 266.0)
	for index: int in range(cards.size()):
		cards[index].position = Vector2(
			cards_left + float(index) * (card_width + gap),
			150.0
		)
		cards[index].size = Vector2(card_width, card_height)
	preview_panel.position = Vector2(viewport_size.x - preview_width - 42.0, 150.0)
	preview_panel.size = Vector2(preview_width, card_height)
	warning_label.position = Vector2(52.0, viewport_size.y - 76.0)
	warning_label.size = Vector2(viewport_size.x - 420.0, 32.0)
	continue_button.position = Vector2(viewport_size.x - 280.0, viewport_size.y - 90.0)
	continue_button.size = Vector2(220.0, 52.0)
	for card: WeaponShopCard in cards:
		card.focus_neighbor_top = NodePath()
		card.focus_neighbor_bottom = continue_button.get_path()


func _apply_portrait(viewport_size: Vector2) -> void:
	title_label.position = Vector2(42.0, 44.0)
	title_label.size = Vector2(viewport_size.x - 84.0, 56.0)
	title_label.add_theme_font_size_override(&"font_size", 31)
	tagline_label.position = Vector2(44.0, 100.0)
	tagline_label.size = Vector2(viewport_size.x - 88.0, 48.0)
	credit_icon.position = Vector2(44.0, 146.0)
	credit_icon.size = Vector2(44.0, 44.0)
	score_caption.position = Vector2(94.0, 156.0)
	score_caption.size = Vector2(220.0, 24.0)
	score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	score_label.position = Vector2(viewport_size.x - 302.0, 150.0)
	score_label.size = Vector2(258.0, 38.0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	preview_panel.position = Vector2(44.0, 198.0)
	preview_panel.size = Vector2(viewport_size.x - 88.0, 134.0)
	var card_width: float = viewport_size.x - 88.0
	var card_height: float = minf(220.0, (viewport_size.y - 530.0) / 3.0)
	for index: int in range(cards.size()):
		cards[index].position = Vector2(44.0, 346.0 + float(index) * (card_height + 14.0))
		cards[index].size = Vector2(card_width, card_height)
	warning_label.position = Vector2(44.0, viewport_size.y - 170.0)
	warning_label.size = Vector2(viewport_size.x - 308.0, 58.0)
	continue_button.position = Vector2(viewport_size.x - 264.0, viewport_size.y - 92.0)
	continue_button.size = Vector2(220.0, 52.0)
	cards[0].focus_neighbor_bottom = cards[1].get_path()
	cards[1].focus_neighbor_top = cards[0].get_path()
	cards[1].focus_neighbor_bottom = cards[2].get_path()
	cards[2].focus_neighbor_top = cards[1].get_path()
	cards[2].focus_neighbor_bottom = continue_button.get_path()


func _transaction_particles(texture: Texture2D) -> CPUParticles2D:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.texture = texture
	particles.amount = 14
	particles.lifetime = 0.72
	particles.one_shot = true
	particles.explosiveness = 0.94
	particles.direction = Vector2.UP
	particles.spread = 145.0
	particles.gravity = Vector2(0.0, 150.0)
	particles.initial_velocity_min = 70.0
	particles.initial_velocity_max = 220.0
	particles.scale_amount_min = 0.035
	particles.scale_amount_max = 0.095
	particles.angular_velocity_min = -160.0
	particles.angular_velocity_max = 160.0
	particles.z_index = 35
	particles.emitting = false
	return particles


func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override(&"font_size", font_size)
	label.modulate = color
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _set_accent(accent: Color) -> void:
	var style: StyleBoxFlat = frame.get_theme_stylebox(&"panel") as StyleBoxFlat
	if style != null:
		style.border_color = accent.darkened(0.30)
	title_label.modulate = accent.lightened(0.38)


func _focus_first_available() -> void:
	for card: WeaponShopCard in cards:
		if card.available():
			card.grab_focus()
			return
	continue_button.grab_focus()


func _card_for(product_id: StringName) -> WeaponShopCard:
	for card: WeaponShopCard in cards:
		if card.product != null and card.product.product_id == product_id:
			return card
	return null


func _on_dialogue_dismissed() -> void:
	_focus_first_available()


func _on_card_preview_requested(product_id: StringName) -> void:
	preview_requested.emit(product_id)


func _on_card_purchase_requested(product_id: StringName) -> void:
	var card: WeaponShopCard = _card_for(product_id)
	if card == null or not card.available():
		return
	var rows_variant: Variant = _previews.get(product_id, [])
	var rows: Array[Dictionary] = []
	for row: Variant in rows_variant:
		rows.append(row as Dictionary)
	confirmation_panel.show_confirmation(card.product, rows, current_score)
