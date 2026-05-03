extends Area2D

@onready var game_manager = %game_manager



func _on_body_entered(_body: Node2D) -> void:
	ShopState.collect_flower()
	queue_free()
	
	game_manager.add_point()
	
