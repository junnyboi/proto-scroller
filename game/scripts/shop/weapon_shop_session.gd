class_name WeaponShopSession
extends Node

signal shop_opened(
	district: CityDistrictProfile,
	products: Array[WeaponShopProduct],
	score: int
)
signal purchase_completed(product: WeaponShopProduct, remaining_score: int)
signal purchase_rejected(product: WeaponShopProduct, reason: StringName)
signal shop_closed(district: CityDistrictProfile, logical_chunk: int)

var pause: RunPauseCoordinator
var run_score: RunScore
var effects: WeaponShopUpgradeRuntime
var robot: GiantRobotController
var telegraphs: TelegraphPresenter2D
var active_district: CityDistrictProfile
var active_products: Array[WeaponShopProduct] = []
var active_chunk: int = 0
var pause_token: int = 0
var purchased: Dictionary[StringName, bool] = {}
var visited_boundaries: Dictionary[int, bool] = {}
var pending_district: CityDistrictProfile
var pending_chunk: int = 0
var active: bool = false


func setup(
	p_pause: RunPauseCoordinator,
	p_run_score: RunScore,
	p_effects: WeaponShopUpgradeRuntime,
	p_robot: GiantRobotController,
	p_telegraphs: TelegraphPresenter2D
) -> PackedStringArray:
	pause = p_pause
	run_score = p_run_score
	effects = p_effects
	robot = p_robot
	telegraphs = p_telegraphs
	return WeaponShopCatalog.validation_errors()


func _process(_delta: float) -> void:
	if pending_district != null and not active and pause != null and not pause.is_paused():
		_open_pending()


func queue_transition(
	previous_district_id: StringName,
	district: CityDistrictProfile,
	logical_chunk: int
) -> bool:
	if (
		district == null
		or district.district_index <= _district_index(previous_district_id)
		or logical_chunk <= 0
		or visited_boundaries.has(logical_chunk)
	):
		return false
	visited_boundaries[logical_chunk] = true
	pending_district = district
	pending_chunk = logical_chunk
	_open_pending()
	return true


func purchase(product_id: StringName) -> bool:
	if not active or run_score == null or effects == null:
		return false
	var product: WeaponShopProduct = _active_product(product_id)
	if product == null:
		return false
	var status: StringName = product_status(product)
	if status != &"available":
		purchase_rejected.emit(product, status)
		return false
	var deducted: int = run_score.deduct(product.price)
	if deducted != product.price or not effects.apply_product(product):
		return false
	purchased[product_id] = true
	purchase_completed.emit(product, run_score.score)
	return true


func close_shop() -> bool:
	if not active or active_district == null:
		return false
	var closed_district: CityDistrictProfile = active_district
	var closed_chunk: int = active_chunk
	active = false
	active_products.clear()
	active_district = null
	if pause != null and pause_token != 0:
		pause.release(pause_token)
	pause_token = 0
	shop_closed.emit(closed_district, closed_chunk)
	return true


func product_status(product: WeaponShopProduct) -> StringName:
	if product == null:
		return &"missing"
	if purchased.has(product.product_id):
		return &"sold"
	if product.is_repair() and robot != null and robot.current_health >= robot.max_health:
		return &"healthy"
	if run_score == null or run_score.score < product.price:
		return &"funds"
	return &"available"


func reset_run() -> void:
	if active:
		close_shop()
	purchased.clear()
	visited_boundaries.clear()
	pending_district = null
	pending_chunk = 0


func _open_pending() -> void:
	if pending_district == null or active or pause == null or pause.is_paused():
		return
	if telegraphs != null and telegraphs.active_count() > 0:
		return
	active_district = pending_district
	active_chunk = pending_chunk
	pending_district = null
	pending_chunk = 0
	active_products = WeaponShopCatalog.products_for(active_district.district_id)
	if run_score != null:
		run_score.bank_all()
	pause_token = pause.acquire(&"weapon_shop")
	active = true
	shop_opened.emit(active_district, active_products, run_score.score)


func _active_product(product_id: StringName) -> WeaponShopProduct:
	for product: WeaponShopProduct in active_products:
		if product.product_id == product_id:
			return product
	return null


func _district_index(district_id: StringName) -> int:
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		if district.district_id == district_id:
			return district.district_index
	return -1
