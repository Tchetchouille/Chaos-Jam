extends Control

signal shop_opened

const BUILDING_SCENE: PackedScene = preload("res://Shopifina/ShopBuilding.tscn")

@onready var buildings_container: VBoxContainer = $BuildingsContainer
@onready var currency_label: Label = $CurrencyPanel/VBoxContainer/CurrencyCount


func _ready() -> void:
	ShopState.on_shop_opened()
	currency_label.text = str(ShopState.flowers)
	_build_rows()
	ShopState.economy_changed.connect(_on_economy_changed)
	ShopState.building_unlocked.connect(_on_building_unlocked)


func _exit_tree() -> void:
	ShopState.economy_changed.disconnect(_on_economy_changed)
	ShopState.building_unlocked.disconnect(_on_building_unlocked)


func _build_rows() -> void:
	for child in buildings_container.get_children():
		child.queue_free()
	for id in range(ShopState.unlocked_count):
		_add_row(id)


func _add_row(building_id: int) -> void:
	var row = BUILDING_SCENE.instantiate()
	row.building_id = building_id
	buildings_container.add_child(row)
	row.purchase_requested.connect(_on_purchase_requested)
	_refresh_row(row)


func _refresh_row(row) -> void:
	row.set_building_name(ShopState.get_building_name(row.building_id))
	row.set_building_count(ShopState.get_owned(row.building_id))
	row.set_price(ShopState.get_price(row.building_id))


func _refresh_all_rows() -> void:
	for row in buildings_container.get_children():
		_refresh_row(row)

func _on_purchase_requested(building_id: int) -> void:
	ShopState.try_purchase(building_id)


func _on_economy_changed() -> void:
	currency_label.text = str(ShopState.flowers)
	_refresh_all_rows()


func _on_building_unlocked(building_id: int) -> void:
	_add_row(building_id)


func _on_go_button_pressed() -> void:
	ShopState.on_shop_exited()
	get_tree().change_scene_to_file("res://platformer/main(mei).tscn")
