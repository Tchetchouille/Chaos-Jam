extends Panel

## Dumb display row. No ShopState dependency.
## The Shop sets values on it and listens to its signal.

signal purchase_requested(building_id: int)

@export var building_id: int = 0

@onready var name_text: RichTextLabel = $HBoxContainer/Name
@onready var price_text: Label = $HBoxContainer/InfoBox/Price
@onready var count_text: Label = $HBoxContainer/InfoBox/Count


func _ready() -> void:
	for node: Control in $HBoxContainer.get_children():
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			purchase_requested.emit(building_id)
			accept_event()


func set_building_name(new_name: String) -> void:
	name_text.text = new_name


func set_building_count(new_count: int) -> void:
	count_text.text = "%d" % new_count


func set_price(cost: int) -> void:
	price_text.text = "Cost: %d" % cost
