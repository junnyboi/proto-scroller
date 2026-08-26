class_name WeaponShopOverlay
extends Control

signal purchase_requested(product_id: StringName)
signal continue_requested

var shade: ColorRect
var frame: PanelContainer
var title_label: Label
var tagline_label: Label
var score_caption: Label
var score_label: Label
var warning_label: Label
var feedback_label: Label
var continue_button: Button
var cards: Array[WeaponShopCard] = []
var district: CityDistrictProfile
var active: bool = false
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
	var accent: Color = district.accent_color.lightened(0.24)
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
	feedback_label.text = ""
	active = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_responsive_layout()
	_input_armed_frame = Engine.get_process_frames() + 2
	_focus_first_available()


func hide_shop() -> void:
	active = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	release_focus()


func set_score(value: int) -> void:
	score_label.text = "%08d" % maxi(value, 0)


func update_status(product_id: StringName, status: StringName) -> void:
	for card: WeaponShopCard in cards:
		if card.product != null and card.product.product_id == product_id:
			card.set_status(status)
			break
	_focus_first_available()


func show_feedback(key: String) -> void:
	feedback_label.text = L10n.t(key)


func apply_responsive_layout() -> void:
	if shade == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	shade.size = viewport_size
	frame.position = Vector2(18.0, 18.0)
	frame.size = viewport_size - Vector2(36.0, 36.0)
	if viewport_size.y > viewport_size.x:
		_apply_portrait(viewport_size)
	else:
		_apply_landscape(viewport_size)


func _build_controls() -> void:
	shade = ColorRect.new()
	shade.color = Color(0.004, 0.01, 0.016, 0.94)
	add_child(shade)
	frame = PanelContainer.new()
	var frame_style: StyleBoxFlat = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.015, 0.025, 0.032, 0.97)
	frame_style.border_width_left = 2
	frame_style.border_width_top = 2
	frame_style.border_width_right = 2
	frame_style.border_width_bottom = 2
	frame_style.border_color = Color("50636c")
	frame.add_theme_stylebox_override(&"panel", frame_style)
	add_child(frame)
	title_label = _label(38, Color("e8f3ef"))
	title_label.name = "ShopTitle"
	add_child(title_label)
	tagline_label = _label(17, Color("9fb0b8"))
	add_child(tagline_label)
	score_caption = _label(16, Color("f1b36f"))
	score_caption.text = L10n.t("shop.credit")
	score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(score_caption)
	score_label = _label(28, Color("f1b36f"))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(score_label)
	for index: int in range(WeaponShopCatalog.PRODUCTS_PER_DISTRICT):
		var card: WeaponShopCard = WeaponShopCard.new()
		card.name = "WeaponShopCard%d" % index
		card.purchase_requested.connect(purchase_requested.emit)
		add_child(card)
		cards.append(card)
	cards[0].focus_neighbor_right = cards[1].get_path()
	cards[1].focus_neighbor_left = cards[0].get_path()
	cards[1].focus_neighbor_right = cards[2].get_path()
	cards[2].focus_neighbor_left = cards[1].get_path()
	warning_label = _label(17, Color("d98262"))
	warning_label.text = L10n.t("shop.score_warning")
	add_child(warning_label)
	feedback_label = _label(17, Color("7ae4ff"))
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(feedback_label)
	continue_button = Button.new()
	continue_button.text = L10n.t("shop.continue")
	continue_button.add_theme_font_size_override(&"font_size", 22)
	continue_button.pressed.connect(continue_requested.emit)
	add_child(continue_button)


func _apply_landscape(viewport_size: Vector2) -> void:
	title_label.add_theme_font_size_override(&"font_size", 38)
	title_label.position = Vector2(54.0, 48.0)
	title_label.size = Vector2(viewport_size.x * 0.63, 52.0)
	tagline_label.position = Vector2(58.0, 98.0)
	tagline_label.size = Vector2(viewport_size.x * 0.68, 28.0)
	score_caption.position = Vector2(viewport_size.x - 350.0, 48.0)
	score_caption.size = Vector2(290.0, 24.0)
	score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.position = Vector2(viewport_size.x - 350.0, 72.0)
	score_label.size = Vector2(290.0, 38.0)
	var gap: float = 22.0
	var card_width: float = minf(350.0, (viewport_size.x - 140.0 - gap * 2.0) / 3.0)
	var card_height: float = minf(360.0, viewport_size.y - 276.0)
	var left: float = (viewport_size.x - card_width * 3.0 - gap * 2.0) * 0.5
	for index: int in range(cards.size()):
		cards[index].position = Vector2(left + float(index) * (card_width + gap), 158.0)
		cards[index].size = Vector2(card_width, card_height)
	warning_label.position = Vector2(58.0, viewport_size.y - 76.0)
	warning_label.size = Vector2(viewport_size.x - 420.0, 32.0)
	feedback_label.position = Vector2(viewport_size.x * 0.34, viewport_size.y - 76.0)
	feedback_label.size = Vector2(viewport_size.x * 0.34, 32.0)
	continue_button.position = Vector2(viewport_size.x - 280.0, viewport_size.y - 90.0)
	continue_button.size = Vector2(220.0, 52.0)
	for card: WeaponShopCard in cards:
		card.focus_neighbor_top = NodePath()
		card.focus_neighbor_bottom = continue_button.get_path()


func _apply_portrait(viewport_size: Vector2) -> void:
	title_label.position = Vector2(42.0, 52.0)
	title_label.size = Vector2(viewport_size.x - 84.0, 56.0)
	title_label.add_theme_font_size_override(&"font_size", 31)
	tagline_label.position = Vector2(44.0, 108.0)
	tagline_label.size = Vector2(viewport_size.x - 88.0, 48.0)
	score_caption.position = Vector2(44.0, 164.0)
	score_caption.size = Vector2(220.0, 24.0)
	score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	score_label.position = Vector2(viewport_size.x - 302.0, 158.0)
	score_label.size = Vector2(258.0, 38.0)
	var card_width: float = viewport_size.x - 88.0
	var card_height: float = minf(230.0, (viewport_size.y - 430.0) / 3.0)
	for index: int in range(cards.size()):
		cards[index].position = Vector2(44.0, 222.0 + float(index) * (card_height + 18.0))
		cards[index].size = Vector2(card_width, card_height)
	warning_label.position = Vector2(44.0, viewport_size.y - 170.0)
	warning_label.size = Vector2(viewport_size.x - 88.0, 42.0)
	feedback_label.position = Vector2(44.0, viewport_size.y - 128.0)
	feedback_label.size = Vector2(viewport_size.x - 88.0, 28.0)
	continue_button.position = Vector2(viewport_size.x - 264.0, viewport_size.y - 92.0)
	continue_button.size = Vector2(220.0, 52.0)
	cards[0].focus_neighbor_bottom = cards[1].get_path()
	cards[1].focus_neighbor_top = cards[0].get_path()
	cards[1].focus_neighbor_bottom = cards[2].get_path()
	cards[2].focus_neighbor_top = cards[1].get_path()
	cards[2].focus_neighbor_bottom = continue_button.get_path()


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
		if not card.disabled:
			card.grab_focus()
			return
	continue_button.grab_focus()
