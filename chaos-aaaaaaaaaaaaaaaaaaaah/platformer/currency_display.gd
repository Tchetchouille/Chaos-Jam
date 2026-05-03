extends RichTextLabel


func _ready() -> void:
	ShopState.economy_changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	if ShopState.economy_changed.is_connected(_refresh):
		ShopState.economy_changed.disconnect(_refresh)


func _refresh() -> void:
	text = "Fleurs : %d" % ShopState.flowers
