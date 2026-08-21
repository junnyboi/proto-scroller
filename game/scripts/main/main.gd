class_name Main
extends Node

const TITLE_SCENE: PackedScene = preload("res://scenes/title_screen.tscn")
const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const RESPONSIVE_VIEWPORT_SCRIPT: Script = preload(
	"res://scripts/main/responsive_viewport.gd"
)

var title_screen: TitleScreen
var city_slice: CitySlice
var responsive_viewport: ResponsiveViewport
@onready var background_music_player: AudioStreamPlayer = %BackgroundMusicPlayer


func _ready() -> void:
	AudioVolumeSettings.apply_saved()
	responsive_viewport = RESPONSIVE_VIEWPORT_SCRIPT.new() as ResponsiveViewport
	responsive_viewport.name = "ResponsiveViewport"
	add_child(responsive_viewport)
	responsive_viewport.setup()
	_show_title()


func start_game() -> void:
	if city_slice != null:
		return
	if title_screen != null:
		title_screen.queue_free()
		title_screen = null
	_spawn_city_slice()


func retry_game() -> void:
	if city_slice != null:
		var previous_city: CitySlice = city_slice
		city_slice = null
		remove_child(previous_city)
		previous_city.queue_free()
	_spawn_city_slice()


func _spawn_city_slice() -> void:
	city_slice = CITY_SCENE.instantiate() as CitySlice
	city_slice.name = "CitySlice"
	city_slice.retry_requested.connect(retry_game)
	add_child(city_slice)


func _show_title() -> void:
	title_screen = TITLE_SCENE.instantiate() as TitleScreen
	title_screen.start_requested.connect(start_game)
	add_child(title_screen)
